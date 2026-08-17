--
--  Copyright (C) 2024, AdaCore
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
--

--  Main entry point to the library. Includes utility to load, dump, and match
--  Stable_Sloc specification files and entries.

with Ada.Containers.Hashed_Maps;
with Ada.Containers.Vectors;
with Ada.Finalization;
with Ada.Strings.Unbounded.Hash;

with GNAT.Regexp;

with GNATCOLL.JSON;
with GNATCOLL.VFS;

with TOML;

limited with Stable_Sloc.Matchers;
with Stable_Sloc_Strings; use Stable_Sloc_Strings;

package Stable_Sloc is
   use Stable_Sloc_Strings.Unbounded_Strings;

   type Sloc is record
      Line, Column : Natural;
   end record;
   No_Sloc : constant Sloc := (0, 0);

   type Relative_Sloc is record
      Line, Column : Integer;
   end record;
   --  Same as Sloc, but allows negative line and column numbers. The main
   --  purpose is to be able to describe a location span relative to a
   --  reference Sloc.

   function "+" (Origin : Sloc; Offset : Relative_Sloc) return Sloc
   is ((Line   => Origin.Line + Offset.Line,
        Column => Origin.Column + Offset.Column));
   --  Return the Sloc obtained by adding the line of Offset to the line of
   --  Origin, and likewise for the column. This will raise Constraint_Error if
   --  the resulting line or column isn't a Natural.

   function "-" (L, R : Sloc) return Relative_Sloc
   is ((Line => L.Line - R.Line, Column => L.Column - R.Column));
   --  Create a relative Sloc by subtracting the line (resp column) of R to
   --  the one of L.

   function Image (Self : Sloc) return String;
   --  Return "<Line>:<Column>" if Self is not No_Sloc, return the empty string
   --  otherwise.

   function Image (Self : Relative_Sloc) return String;
   --  Return "<Line>:<Column>"

   function "<" (L, R : Sloc) return Boolean;
   --  Returns whether L precedes R. This is a lexicographical order on
   --  Line, Column.

   type Sloc_Span is record
      Start_Sloc, End_Sloc : Sloc;
   end record;
   No_Sloc_Span : constant Sloc_Span := ((0, 0), (0, 0));

   type Relative_Sloc_Span is record
      Start_Sloc, End_Sloc : Relative_Sloc;
   end record;
   --  Sloc_Span that allows negative line and column numbers, which can be
   --  used to designate a span relative to a reference Sloc.

   function "+" (Origin : Sloc; Offset : Relative_Sloc_Span) return Sloc_Span
   is ((Start_Sloc => Origin + Offset.Start_Sloc,
        End_Sloc   => Origin + Offset.End_Sloc));
   --  Return the sloc span obtained by offsetting Origin by Offset.Start_Sloc
   --  (resp. Origin.End_Sloc) for the Start_Sloc (resp End_Sloc).

   function "-" (Span : Sloc_Span; Reference : Sloc) return Relative_Sloc_Span
   is ((Start_Sloc => Span.Start_Sloc - Reference,
        End_Sloc   => Span.End_Sloc - Reference));
   --  Create the relative span of Span, compared to Reference.

   function Image (Self : Sloc_Span) return String;
   --  Return "<Start.Line>:<Start.Column> - <End.Line>:<End.Column>" if
   --  Self is not No_Sloc_Span, return the empty string otherwise.

   function Image (Self : Relative_Sloc_Span) return String;
   --  Return "<Start.Line>:<Start.Column> - <End.Line>:<End.Column>"

   function "<" (L, R : Sloc_Span) return Boolean
   is (if L.Start_Sloc = R.Start_Sloc
       then L.End_Sloc < R.End_Sloc
       else L.Start_Sloc < R.Start_Sloc);
   --  Compare L and R by lexicographical order

   type Load_Diagnostic is record
      File       : GNATCOLL.VFS.Virtual_File;
      Location   : Sloc;
      Diagnostic : Unbounded_String;
   end record;
   --  Represents a diagnostic as to why a specification file or entry was not
   --  able to be loaded.

   function Format_Diagnostic (D : Load_Diagnostic) return String;
   --  Format D as FILENAME:[SLOC:]DIAGNOSTIC

   type Load_Diagnostic_Arr is array (Positive range <>) of Load_Diagnostic;

   function To_JSON
     (Diags : Load_Diagnostic_Arr) return GNATCOLL.JSON.JSON_Value;
   --  Convert the load diagnostic array into a JSON array. This can be used to
   --  expose the diagnostics in a structured format to external tools.

   type Match_Result (Success : Boolean := True) is record
      Identifier : Unbounded_String;
      --  Identifier of the entry that matched

      Annotation : TOML.TOML_Value;
      --  Annotation attached to the entry

      File : GNATCOLL.VFS.Virtual_File;
      --  File on which the entry matched

      case Success is
         when True =>
            Location : Sloc_Span;
            --  Location span that the entry matched

         when False =>
            Diagnostic : Unbounded_String;
            --  Reason why the entry did not match
      end case;
   end record;
   --  Match result, if Success is False, this means that the entry was
   --  supposed to produce a successful match, but some context element renders
   --  the match invalid. Otherwise, there is no match result produced.

   function "<" (L, R : Match_Result) return Boolean;
   --  Compare L and R by lexicographical order on:
   --  - Filename
   --  - Success (failed matches compare lower)
   --    -Diagnostic (if L & R .Success is false)
   --  - Location
   --  - Identifier

   package Match_Result_Vectors is new
     Ada.Containers.Vectors
       (Index_Type   => Positive,
        Element_Type => Match_Result);
   subtype Match_Result_Vec is Match_Result_Vectors.Vector;

   package Match_Res_Sorting is new Match_Result_Vectors.Generic_Sorting ("<");
   procedure Sort (Results : in out Match_Result_Vec)
   renames Match_Res_Sorting.Sort;

   function To_JSON
     (Results : Match_Result_Vec) return GNATCOLL.JSON.JSON_Value;
   --  Convert the match result vector into a JSON value. This can be used to
   --  export match results to external consumers.

   type Entry_DB is limited private;

   function Create_DB return Entry_DB;
   --  Create an empty DB.

   function Is_Empty (DB : Entry_DB) return Boolean;
   --  Return whether there are any entries in DB or not

   procedure Import_DB (Into : in out Entry_DB; From : Entry_DB);
   --  Copy the entries from From into Into. If there is clash in entry
   --  identifiers, the one from From is discarded.

   procedure Clear_DB (DB : in out Entry_DB);
   --  Delete all entries from DB

   function Load_Entries
     (Spec_File      : GNATCOLL.VFS.Virtual_File;
      DB             : in out Entry_DB;
      Ignore_Unknown : Boolean := True;
      Strict         : Boolean := False) return Load_Diagnostic_Arr;
   --  Load the entries from Spec_File, initializing the relevant matchers in
   --  the process.
   --
   --  If Ignore_Unknown is True, entries that have a matcher kind
   --  not matching any of the registered matchers will be silently ignored.
   --
   --  If Strict is True, do not modify DB in case of load errors, but only
   --  return the diagnostics.

   function Match_Entries
     (Files          : GNATCOLL.VFS.File_Array;
      DB             : in out Entry_DB;
      Purpose_Prefix : String := "") return Match_Result_Vec;
   --  Run the loaded entries on the specified Files. Only run the matchers
   --  with a Purpose beginning with Purpose_Prefix. An empty prefix matches
   --  everything, and an entry with a non-specified purpose is considered as
   --  always active.

   procedure Reset_Match_Count (DB : in out Entry_DB);
   --  Reset the match count for all entries. All entries meant to match only
   --  once will successfully match again once.

   procedure Dump_Entries (DB : Entry_DB);
   --  Dump the entries in DB to standard output.

   procedure Write_Entries
     (DB     : Entry_DB;
      File   : GNATCOLL.VFS.Virtual_File;
      Origin : GNATCOLL.VFS.Virtual_File := GNATCOLL.VFS.No_File);
   --  Write the DB entry database to File.
   --
   --  When Origin is set, write only the entries that were loaded from it,
   --  together with those not loaded from any file. A database built from
   --  several files can then be written back one file at a time, instead of
   --  collapsing all of them into File: pass the file being rewritten as both
   --  File and Origin, and entries belonging to the others are left alone.
   --
   --  Entries created since loading have no origin, so they are written
   --  whatever Origin is: they belong to whichever file is being written.

   type Sloc_Matcher_Acc is
     access all Stable_Sloc.Matchers.Sloc_Matcher_T'Class;

   function Add_Or_Update_Entry
     (DB          : in out Entry_DB;
      Identifier  : Unbounded_String;
      Annotation  : TOML.TOML_Value;
      Kind        : Unbounded_String;
      File        : GNATCOLL.VFS.Virtual_File;
      Span        : Sloc_Span;
      File_Prefix : Unbounded_String := Null_Unbounded_String;
      Replace     : Boolean := True) return Load_Diagnostic_Arr;
   --  Add or update the entry designated by Identifier for the given Purpose,
   --  and Annotation. The new entry shall use the specified matcher Kind, and
   --  return a positive match on File for the given location Span.
   --
   --  If File_Prefix is not null, it is removed from the filename when
   --  creating the file matcher to be used in the entry.
   --
   --  If Replace is False and there already is an entry with the same
   --  Identifier in DB, then the new entry is not added to DB.
   --
   --  Return whether the new entry was successfully added to DB or not.

   type Entry_View is record
      Kind : Unbounded_String;
      --  Name of the matcher kind used for this entry

      Annotations : TOML.TOML_Value;
      --  Array of annotations attached to this entry

      File_Pattern : Unbounded_String;
      --  Globbing pattern of the files to which this entry applies

      At_Most_Once : Boolean;
      --  Whether this entry is supposed to match more than once.

      Origin : GNATCOLL.VFS.Virtual_File;
      --  File this entry was loaded from, or No_File when it was created in
      --  memory rather than loaded. See Write_Entries.

   end record;
   --  Representation of a Stable_Sloc entry for viewing purposes

   No_Entry_View : constant Entry_View :=
     (Kind         => Null_Unbounded_String,
      Annotations  => TOML.No_TOML_Value,
      File_Pattern => Null_Unbounded_String,
      At_Most_Once => False,
      Origin       => GNATCOLL.VFS.No_File);

   function Query_Entry
     (DB : Entry_DB; Identifier : Unbounded_String) return Entry_View;
   --  Return the entry vew corresponding to the entry for Identifier in DB, if
   --  any. Return No_Entry_View if there is no entry associated to Identifier.

   procedure Replace_Entry
     (Target_DB : in out Entry_DB;
      Source_DB : Entry_DB;
      Target_Id : Unbounded_String;
      Source_Id : Unbounded_String);
   --  Replace or insert, in Target_DB the entry associated with Target_Id,
   --  using the entry in Source_DB at Source_Id. Raises Constraint_Error if
   --  there is not entry associated with Source_Id in Source_DB.

   procedure Delete_Entry
     (DB : in out Entry_DB; Identifier : Unbounded_String);
   --  Remove the entry at Identifier from DB

   type Entry_View_CB is
     access procedure (Identifier : Unbounded_String; Entr : Entry_View);

   procedure Iterate_Entries (DB : Entry_DB; CB : not null Entry_View_CB);
   --  Call CB over all the entries in DB

private

   type SS_Entry is new Ada.Finalization.Controlled with record
      Annotations : TOML.TOML_Value;
      --  Annotations to return in case of successful match

      File_Pattern : Unbounded_String;
      --  Textual globbing pattern used to determine relevant files

      File_Regexp : GNAT.Regexp.Regexp;
      --  Compiled globbing pattern to determine relevant files

      Kind : Unbounded_String;
      --  Name of the matcher kind to be used

      Sloc_Matcher : Sloc_Matcher_Acc;
      --  Matcher backend to be used

      At_Most_Once : Boolean;
      --  Wether this entry is only expected to match once. If True, this entry
      --  must return a failed match result upon each subsequent successful
      --  match.

      Origin : GNATCOLL.VFS.Virtual_File := GNATCOLL.VFS.No_File;
      --  File this entry was loaded from, if any

      Last_File  : GNATCOLL.VFS.Virtual_File := GNATCOLL.VFS.No_File;
      Last_Range : Sloc_Span := No_Sloc_Span;
      --  Last match location for this entry, only set if At_Most_Once is True
   end record;

   overriding
   procedure Adjust (Self : in out SS_Entry);

   overriding
   procedure Finalize (Self : in out SS_Entry);

   package Entry_Maps is new
     Ada.Containers.Hashed_Maps
       (Key_Type        => Unbounded_Strings.Unbounded_String,
        Element_Type    => SS_Entry,
        Hash            => Ada.Strings.Unbounded.Hash,
        Equivalent_Keys => Unbounded_Strings."=");
   subtype Entry_Map is Entry_Maps.Map;

   type Entry_DB is record
      Map : Entry_Map;
   end record;

end Stable_Sloc;
