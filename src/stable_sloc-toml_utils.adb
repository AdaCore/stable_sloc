--
--  Copyright (C) 2024, AdaCore
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
--

with Stable_Sloc.Matchers;

package body Stable_Sloc.TOML_Utils is

   ---------
   -- Get --
   ---------

   function Get (Val : TOML.TOML_Value; Key : String) return Boolean
   is (Get (Val, Key, TOML_Boolean).As_Boolean);

   function Get (Val : TOML.TOML_Value; Key : String) return Integer
   is (Integer (Get (Val, Key, TOML_Integer).As_Integer));

   function Get (Val : TOML.TOML_Value; Key : String) return String
   is (Get (Val, Key, TOML_String).As_String);

   function Get
     (Val : TOML.TOML_Value; Key : String) return Unbounded_UTF8_String
   is (Get (Val, Key, TOML_String).As_Unbounded_String);

   function Get
     (Val : TOML.TOML_Value; Key : String; Kind : Any_Value_Kind)
      return TOML_Value is
   begin
      if Val.Kind /= TOML_Table then
         raise Stable_Sloc.Matchers.Parse_Error
           with
             Format_Location (Val.Location)
             & ":Can't get """
             & Key
             & """ from a "
             & Val.Kind'Image;
      end if;
      if not Val.Has (Key) then
         raise Stable_Sloc.Matchers.Parse_Error
           with
             Format_Location (Val.Location) & ":Missing """ & Key & """ field";
      end if;
      if Val.Get (Key).Kind /= Kind then
         raise Stable_Sloc.Matchers.Parse_Error
           with
             Format_Location (Val.Get (Key).Location)
             & ":Unexpected type for """
             & Key
             & """: expected "
             & Kind'Image
             & " but got "
             & Val.Get (Key).Kind'Image;
      end if;
      return Val.Get (Key);
   end Get;

   -----------------
   -- Get_Or_Null --
   -----------------

   function Get_Or_Null
     (Val : TOML.TOML_Value; Key : String) return Unbounded_String is
   begin
      if Val.Kind /= TOML_Table
        or else not Val.Has (Key)
        or else Val.Get (Key).Kind /= TOML_String
      then
         return Null_Unbounded_String;
      else
         return Val.Get (Key).As_Unbounded_String;
      end if;
   end Get_Or_Null;

   --------------------
   -- Get_Or_Default --
   --------------------

   function Get_Or_Default
     (Val : TOML.TOML_Value; Key : String; Default : Boolean) return Boolean
   is
      Bool : constant TOML_Value := Get_Or_Null (Val, Key);
   begin
      if Bool.Is_Null then
         return Default;
      end if;
      if Bool.Kind /= TOML_Boolean then
         raise Stable_Sloc.Matchers.Parse_Error
           with
             Format_Location (Bool.Location)
             & ":Wrong type for """
             & Key
             & """: expected "
             & TOML_Boolean'Image
             & " but got "
             & Bool.Kind'Image;
      end if;
      return Bool.As_Boolean;
   end Get_Or_Default;

   ---------------
   -- Read_Span --
   ---------------

   function Read_Span (Val : TOML_Value) return Sloc_Span
   is (No_Sloc + Read_Span (Val));

   function Read_Span (Val : TOML_Value) return Relative_Sloc_Span is
      SL : constant Integer := Get (Val, "start_line");
      SC : constant Integer := Get (Val, "start_col");
      EL : constant Integer := Get (Val, "end_line");
      EC : constant Integer := Get (Val, "end_col");
   begin
      return (Start_Sloc => (SL, SC), End_Sloc => (EL, EC));
   end Read_Span;

   ----------------
   -- Write_Span --
   ----------------

   function Write_Span (Span : Sloc_Span) return TOML_Value
   is (Write_Span (Span - No_Sloc));

   function Write_Span (Span : Relative_Sloc_Span) return TOML_Value is
   begin
      return Res : constant TOML.TOML_Value := TOML.Create_Table do
         Res.Set
           ("start_line",
            TOML.Create_Integer (TOML.Any_Integer (Span.Start_Sloc.Line)));
         Res.Set
           ("start_col",
            TOML.Create_Integer (TOML.Any_Integer (Span.Start_Sloc.Column)));
         Res.Set
           ("end_line",
            TOML.Create_Integer (TOML.Any_Integer (Span.End_Sloc.Line)));
         Res.Set
           ("end_col",
            TOML.Create_Integer (TOML.Any_Integer (Span.End_Sloc.Column)));
      end return;
   end Write_Span;

   function To_String (Val : TOML_Value) return Unbounded_String is
   begin
      return Val.Dump_As_Unbounded;
   end To_String;

   -------------
   -- To_JSON --
   -------------

   function To_JSON (Val : TOML_Value) return JSON_Value is
   begin
      case Kind (Val) is
         when TOML_String =>
            return Create (Val.As_String);

         when TOML_Integer =>
            return Create (Long_Long_Integer (Val.As_Integer));

         when TOML_Float =>
            if Val.As_Float.Kind = Regular then
               return Create (Long_Float (Val.As_Float.Value));
            else
               --  NaN is not supported in JSON, we should return a null
               --  instead.

               return JSON_Null;
            end if;

         when TOML_Boolean =>
            return Create (Val.As_Boolean);

         when TOML_Offset_Datetime .. TOML_Local_Time =>
            declare
               --  There is no way to dump a partial TOML document to string at
               --  the moment, so create a table with the value, dump it to
               --  string and strip the "key = " prefix.

               Dummy_Table : TOML_Value := Create_Table;
               Res         : Unbounded_String;
            begin
               Dummy_Table.Set ("key", Val);
               Res := Dump_As_Unbounded (Dummy_Table);
               return
                 Create
                   (Unbounded_Slice
                      (Res, String'("key = ")'Last + 1, Length (Res)));
            end;

         when TOML_Array =>
            declare
               Res : JSON_Array := Empty_Array;
            begin
               for J in 1 .. Val.Length loop
                  Append (Res, To_JSON (Val.Item (J)));
               end loop;
               return Create (Res);
            end;

         when TOML_Table =>
            return Res : constant JSON_Value := Create_Object do
               for Assoc of Val.Iterate_On_Table loop
                  Res.Set_Field (+Assoc.Key, To_JSON (Assoc.Value));
               end loop;
            end return;

      end case;
   end To_JSON;

   -------------
   -- To_TOML --
   -------------

   function To_TOML (Val : JSON_Value) return TOML_Value is
   begin
      case Val.Kind is
         when JSON_Int_Type =>
            return Create_Integer (Any_Integer (Long_Integer'(Val.Get)));

         when JSON_Float_Type =>
            return
              Create_Float
                (Any_Float'(Regular, Valid_Float (Val.Get_Long_Float)));

         when JSON_String_Type =>
            return Create_String (String'(Val.Get));

         when JSON_Boolean_Type =>
            return Create_Boolean (Val.Get);

         when JSON_Array_Type =>
            return Res : constant TOML_Value := Create_Array do
               for Item of JSON_Array'(Val.Get) loop
                  Res.Append (To_TOML (Item));
               end loop;
            end return;

         when JSON_Object_Type =>
            declare
               Res : constant TOML_Value := Create_Table;
               procedure Append_CB (Name : UTF8_String; Element : JSON_Value);
               --  Add the Name:Element association in Res

               procedure Append_CB (Name : UTF8_String; Element : JSON_Value)
               is
               begin
                  Res.Set (Name, To_TOML (Element));
               end Append_CB;
            begin
               Val.Map_JSON_Object (Append_CB'Access);
               return Res;
            end;

         when JSON_Null_Type =>
            return No_TOML_Value;

      end case;
   end To_TOML;

end Stable_Sloc.TOML_Utils;
