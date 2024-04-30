with GNATCOLL.Opt_Parse; use GNATCOLL.Opt_Parse;
with GNATCOLL.VFS;

with Stable_Sloc_Strings; use Stable_Sloc_Strings;

package Stable_Sloc.Cmd_Parser is

   function Str_To_File (Filename : String) return GNATCOLL.VFS.Virtual_File is
     (GNATCOLL.VFS.Create (GNATCOLL.VFS."+" (Filename)));

   type Update_Request is record
      Kind       : Unbounded_String;
      Identifier : Unbounded_String;
      Purpose    : Unbounded_String;
      Annotation : Unbounded_String;
      File       : GNATCOLL.VFS.Virtual_File;
      Span       : Sloc_Span;
   end record;

   function Parse_Update_Request (Arg : String) return Update_Request;

   Parser : Argument_Parser := Create_Argument_Parser
     (Help => "Stable_Sloc CLI interface");

   package Specs is new Parse_Option_List
     (Parser,
      Short      => "-s",
      Long       => "--spec",
      Accumulate => True,
      Help       => "Entry specification files",
      Arg_Type   => GNATCOLL.VFS.Virtual_File,
      Convert    => Str_To_File);

   package Filter is new Parse_Option
     (Parser,
      Short       => "-f",
      Long        => "--filter",
      Help        => "Entry identifier filter. An entry's identifier must"
                     & " start with FILTER to be enabled",
      Arg_Type    => US,
      Convert     => GNATCOLL.Opt_Parse.Convert,
      Default_Val => Unbounded_Strings.Null_Unbounded_String);

   package Prefix is new Parse_Option
     (Parser,
      Long        => "--prefix",
      Help        => "Prefix to be removed from the filenames when creating"
                     & " entries' file matchers",
      Arg_Type    => US,
      Convert     => GNATCOLL.Opt_Parse.Convert,
      Default_Val => Unbounded_Strings.Null_Unbounded_String);

   package Output is new Parse_Option
     (Parser,
      Short       => "-o",
      Long        => "--output",
      Help        => "File to which the loaded entries will be written at"
                     & " termination of the program",
      Arg_Type    => GNATCOLL.VFS.Virtual_File,
      Convert     => Str_To_File,
      Name        => "Files",
      Default_Val => GNATCOLL.VFS.No_File);

   package Update_Requests is new Parse_Option_List
     (Parser,
      Short      => "-u",
      Long       => "--update",
      Usage_Text => "[--update|-u IDENTIFIER:PURPOSE:KIND:FILENAME:START_LINE"
                    & ":START_COL:END_LINE:END_COL[:ANNOTATION]]",
      Help       =>
        "Create or update the entry with the given IDENTIFIER, for the given"
        & " PURPOSE and optional ANNOTATION." & ASCII.LF
        & " The entry will use a matcher of specified KIND, which shall match"
        & " the given location in file FILENAME.",
      Accumulate => True,
      Arg_Type   => Update_Request,
      Convert    => Parse_Update_Request);

   package Files is new Parse_Positional_Arg_List
     (Parser,
      Name        => "files",
      Help        => "files on which the entries will search",
      Allow_Empty => True,
      Arg_Type    => GNATCOLL.VFS.Virtual_File,
      Convert     => Str_To_File);

   package Quiet is new Parse_Flag
     (Parser,
      Short => "-q",
      Long  => "--quiet",
      Help  => "Suppress non-critical messages");

   package Verbose is new Parse_Flag
     (Parser,
      Short => "-v",
      Long  => "--verbose",
      Help  => "Output more details to standard output");

   package Strict is new Parse_Flag
     (Parser,
      Long => "--strict",
      Help => "Stop processing at the first parse or match error.");

end Stable_Sloc.Cmd_Parser;