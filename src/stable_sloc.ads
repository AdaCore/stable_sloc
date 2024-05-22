with Ada.Containers.Hashed_Maps;
with Ada.Containers.Vectors;
with Ada.Finalization;
with Ada.Strings.Unbounded.Hash;

with GNAT.Regexp;

with GNATCOLL.VFS;

with TOML;

limited with Stable_Sloc.Matchers;
with Stable_Sloc_Strings;  use Stable_Sloc_Strings;

package Stable_Sloc is
   use Unbounded_Strings;

   type Sloc is record
      Line, Column : Natural;
   end record;
   No_Sloc : constant Sloc := (0, 0);

   function Image (Self : Sloc) return String;
   --  Return "<Line>:<Column>" if Self is not No_Sloc, return the empty string
   --  otherwise.

   type Sloc_Span is record
      Start_Sloc, End_Sloc : Sloc;
   end record;
   No_Sloc_Span : constant Sloc_Span := ((0, 0), (0, 0));

   function Image (Self : Sloc_Span) return String;
   --  Return "<Start.Line>:<Start.Column> - <End.Line>:<End.Column>" if
   --  Self is not No_Sloc_Span, return the empty string otherwise.

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

   type Match_Result (Success : Boolean := True) is record
      Identifier : Unbounded_String;
      --  Identifier of the entry that matched

      Annotation : TOML.TOML_Value;
      --  Annotation attached to the entry

      File       : GNATCOLL.VFS.Virtual_File;
      --  File on which the entry matched

      case Success is
         when True =>
            Location   : Sloc_Span;
            --  Location span that the entry matched

         when False =>
            Diagnostic : Unbounded_String;
            --  Reason why the entry did not match
      end case;
   end record;
   --  Match result, if Success is False, this means that the entry was
   --  supposed to produce a successful match, but some context element renders
   --  the match invalid. Otherwise, there is no match result produced.

   package Match_Result_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Match_Result);
   subtype Match_Result_Vec is Match_Result_Vectors.Vector;

   type Entry_DB is limited private;

   function Create_DB return Entry_DB;
   --  Create an empty DB.

   function Is_Empty (DB : Entry_DB) return Boolean;
   --  Return whether there are any entries in DB or not

   procedure Import_DB (Into : in out Entry_DB; From : Entry_DB);
   --  Copy the entries from From into Into. If there is clash in entry
   --  identifiers, the one from From is discarded.

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
      DB             : Entry_DB;
      Purpose_Prefix : String := "") return Match_Result_Vec;
   --  Run the loaded entries on the specified Files. Only run the matchers
   --  with and Purpose beginning with Purpose_Prefix.

   procedure Dump_Entries (DB : Entry_DB);
   --  Dump the entries in DB to standard output.

   procedure Write_Entries
     (DB : Entry_DB; File : GNATCOLL.VFS.Virtual_File);
   --  Write the DB entry database to File

   type Sloc_Matcher_Acc is access all
     Stable_Sloc.Matchers.Sloc_Matcher_T'Class;

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

private

   type SS_Entry is new Ada.Finalization.Controlled with record
      Annotations  : TOML.TOML_Value;
      File_Pattern : Unbounded_String;
      File_Regexp  : GNAT.Regexp.Regexp;
      Kind         : Unbounded_String;
      Sloc_Matcher : Sloc_Matcher_Acc;
   end record;

   overriding procedure Adjust (Self : in out SS_Entry);

   overriding procedure Finalize (Self : in out SS_Entry);

   package Entry_Maps is new Ada.Containers.Hashed_Maps
     (Key_Type        => Unbounded_Strings.Unbounded_String,
      Element_Type    => SS_Entry,
      Hash            => Ada.Strings.Unbounded.Hash,
      Equivalent_Keys => Unbounded_Strings."=");
   subtype Entry_Map is Entry_Maps.Map;

   type Entry_DB is record
      Map             : Entry_Map;
   end record;

end Stable_Sloc;
