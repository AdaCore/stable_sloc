--
--  Copyright (C) 2024, AdaCore
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
--

--  Various utilities to manipulate and convert TOML values

with GNATCOLL.JSON; use GNATCOLL.JSON;

with TOML; use TOML;

package Stable_Sloc.TOML_Utils is

   function Get (Val : TOML.TOML_Value; Key : String) return Boolean;
   function Get (Val : TOML.TOML_Value; Key : String) return Integer;
   function Get (Val : TOML.TOML_Value; Key : String) return String;
   function Get
     (Val : TOML.TOML_Value; Key : String) return Unbounded_UTF8_String;
   --  Various shortcuts for Val.Get (Key).As_<type>. Raise Parse_Error if
   --  Val is not a table, if it doesn't have a Key filed and if the type of
   --  the Key field is not what's expected.

   function Get
     (Val : TOML.TOML_Value; Key : String; Kind : Any_Value_Kind)
      return TOML_Value;
   --  Same as above, but instead of .As_<type>ing the Get result, simply check
   --  that the result is indeed of kind Kind.

   function Get_Or_Null
     (Val : TOML.TOML_Value; Key : String) return Unbounded_String;
   --  Return the string field at Key in Val. If anything prevents the
   --  operation from succeeding, (Val is not a table, Key is not a string or
   --  absent, etc), return Null_Unbounded_String.

   function Get_Or_Default
     (Val : TOML.TOML_Value; Key : String; Default : Boolean) return Boolean;
   --  Get the boolean value of the Key field, in the TOML_Value Val, or return
   --  Default if Val does not have Key field. If there is a Key field in val
   --  but it is of the wrong type, raise Parse_Error.

   function Read_Span (Val : TOML_Value) return Sloc_Span with
     Pre => Val.Kind = TOML_Table;
   --  Read a sloc Span from Val. The various locations are expected to be laid
   --  out flat in the table as the following field:
   --
   --  start_line
   --  start_col
   --  end_line
   --  end_col

   function Read_Span (Val : TOML_Value) return Relative_Sloc_Span with
      Pre => Val.Kind = TOML_Table;
   --  Same as above, but with relative spans

   function Write_Span (Span : Sloc_Span) return TOML_Value;
   --  Reverse of the Read_Span function

   function Write_Span (Span : Relative_Sloc_Span) return TOML_Value;
   --  Reverse of the Read_Span function

   function To_String (Val : TOML_Value) return Unbounded_String;
   --  Return the inline representation of Val

   function To_JSON (Val : TOML_Value) return JSON_Value;
   --  Convert Val to a GNATCOLL.JSON value. This does not preserve location
   --  information.
   --  Date-time fields are represented as strings, NaNs and infinities are
   --  represented as null JSON values.

   function To_TOML (Val : JSON_Value) return TOML_Value;
   --  Convert Val to a TOML.TOML_Value. This does not create any location
   --  information, and will not attempt to parse any date that may be present
   --  in a string field.
   --
   --  Null JSON values are returned as No_TOML_Value, so the end result may
   --  not be a valid TOML (partial) document.

end Stable_Sloc.TOML_Utils;
