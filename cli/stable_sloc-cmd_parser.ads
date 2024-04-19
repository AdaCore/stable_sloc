with GNATCOLL.Opt_Parse; use GNATCOLL.Opt_Parse;
with GNATCOLL.VFS;

with Stable_Sloc_Strings; use Stable_Sloc_Strings;

package Stable_Sloc.Cmd_Parser is

   function Str_To_File (Filename : String) return GNATCOLL.VFS.Virtual_File is
     (GNATCOLL.VFS.Create (GNATCOLL.VFS."+" (Filename)));

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