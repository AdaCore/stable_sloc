with Ada.Containers.Hashed_Maps;
with Ada.Containers.Vectors;
with Ada.Finalization;

with GNAT.Regexp;

with GNATCOLL.VFS;

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

   type Load_Diagnostic_Arr is array (Positive range <>) of Load_Diagnostic;

   type Match_Result (Success : Boolean := True) is record
      Identifier : Unbounded_String;
      Purpose    : Unbounded_String;
      Annotation : Unbounded_String;
      File       : GNATCOLL.VFS.Virtual_File;
      case Success is
         when True =>
            Location   : Sloc_Span;
         when False =>
            Diagnostic : Unbounded_String;
      end case;
   end record;

   package Match_Result_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Match_Result);
   subtype Match_Result_Vec is Match_Result_Vectors.Vector;

   type Entry_DB is limited private;

   function Create_DB return Entry_DB;
   --  Create an empty DB.

   procedure Import_DB (Into : in out Entry_DB; From : Entry_DB);
   --  Copy the entries from From into Into. If there is clash in entry
   --  identifiers, the one from From is discarded.

   function Load_Entries
     (Spec_File : GNATCOLL.VFS.Virtual_File;
      DB        : in out Entry_DB;
      Strict    : Boolean := False) return Load_Diagnostic_Arr;
   --  Load the entries from Spec_File, initializing the relevant matchers in
   --  the process. If Strict is True, only compute diagnostics but do not
   --  modify DB.

   function Match_Entries
     (Files          : GNATCOLL.VFS.File_Array;
      DB             : Entry_DB;
      Purpose_Prefix : String := "") return Match_Result_Vec;
   --  Run the loaded entries on the specified Files. Only run the matchers
   --  with and Purpose beginning with Purpose_Prefix.

   procedure Dump_Entries (DB : Entry_DB);
   --  Dump the currently loaded entries to standard output.

   type Sloc_Matcher_Acc is access all
     Stable_Sloc.Matchers.Sloc_Matcher_T'Class;

private

   type SS_Entry is new Ada.Finalization.Controlled with record
      Purpose      : Unbounded_String;
      Annotation   : Unbounded_String;
      File_Pattern : Unbounded_String;
      File_Regexp  : GNAT.Regexp.Regexp;
      Sloc_Matcher : Sloc_Matcher_Acc;
   end record;

   overriding procedure Adjust (Self : in out SS_Entry);

   overriding procedure Finalize (Self : in out SS_Entry);

   package Entry_Maps is new Ada.Containers.Hashed_Maps
     (Key_Type        => Unbounded_Strings.Unbounded_String,
      Element_Type    => SS_Entry,
      Hash            => Hash,
      Equivalent_Keys => Unbounded_Strings."=");
   subtype Entry_Map is Entry_Maps.Map;

   type Entry_DB is record
      Map             : Entry_Map;
   end record;

end Stable_Sloc;
