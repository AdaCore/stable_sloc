with TOML; use TOML;

package Stable_Sloc.TOML_Utils is

   function Get (Val : TOML.TOML_Value; Key : String) return Boolean;
   function Get (Val : TOML.TOML_Value; Key : String) return Integer;
   function Get (Val : TOML.TOML_Value; Key : String) return String;
   function Get
     (Val : TOML.TOML_Value; Key : String) return Unbounded_UTF8_String;
   --  Various shortcuts for Val.Get (Key).As_<type>. Raise Parse_Error if
   --  Val is not a table, if it doesn't have a Key filed and if the type of
   --  the Key filed is not what's expected.

end Stable_Sloc.TOML_Utils;
