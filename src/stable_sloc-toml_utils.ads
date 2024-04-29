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

   function Get
     (Val : TOML.TOML_Value; Key : String; Kind : Any_Value_Kind)
      return TOML_Value;
   --  Same as above, but instead of .As_<type>ing the Get result, simply check
   --  that the result is indeed of kind Kind.

   function Read_Span (Val : TOML_Value) return Sloc_Span with
     Pre => Val.Kind = TOML_Table;
   --  Read a sloc Span from Val. The various locations are expected to be laid
   --  out flat in the table as the following field:
   --
   --  start_line
   --  start_col
   --  end_line
   --  end_col

   function Write_Span (Span : Sloc_Span) return TOML_Value;
   --  Reverse of the above function

end Stable_Sloc.TOML_Utils;
