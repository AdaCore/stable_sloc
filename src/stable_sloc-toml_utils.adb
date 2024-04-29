with Stable_Sloc.Matchers;

package body Stable_Sloc.TOML_Utils is

   ---------
   -- Get --
   ---------

   function Get (Val : TOML.TOML_Value; Key : String) return Boolean is
     (Get (Val, Key, TOML_Boolean).As_Boolean);


   function Get (Val : TOML.TOML_Value; Key : String) return Integer is
     (Integer (Get (Val, Key, TOML_Integer).As_Integer));

   function Get (Val : TOML.TOML_Value; Key : String) return String is
     (Get (Val, Key, TOML_String).As_String);

   function Get
     (Val : TOML.TOML_Value; Key : String) return Unbounded_UTF8_String is
     (Get (Val, Key, TOML_String).As_Unbounded_String);

   function Get
     (Val : TOML.TOML_Value; Key : String; Kind : Any_Value_Kind)
     return TOML_Value
   is
   begin
      if Val.Kind /= TOML_Table then
         raise Stable_Sloc.Matchers.Parse_Error with
           Format_Location (Val.Location) & ":Can't get " & Key & " from a "
           & Val.Kind'Image;
      end if;
      if not Val.Has (Key) then
         raise Stable_Sloc.Matchers.Parse_Error with
           Format_Location (Val.Location) & ":Missing " & Key & " field";
      end if;
      if Val.Get (Key).Kind /= Kind then
         raise Stable_Sloc.Matchers.Parse_Error with
            Format_Location (Val.Get (Key).Location)
            & ":Unexpected type for """ & Key
            & """: expected " & Kind'Image & " but got "
            & Val.Get (Key).Kind'Image;
      end if;
      return Val.Get (Key);
   end Get;

   ---------------
   -- Read_Span --
   ---------------

   function Read_Span (Val : TOML_Value) return Sloc_Span is
      SL : constant Natural := Get (Val, "start_line");
      SC : constant Natural := Get (Val, "start_col");
      EL : constant Natural := Get (Val, "end_line");
      EC : constant Natural := Get (Val, "end_col");
   begin
      return (Start_Sloc => (SL, SC), End_Sloc => (EL, EC));
   end Read_Span;

   ----------------
   -- Write_Span --
   ----------------

   function Write_Span (Span : Sloc_Span) return TOML_Value is
   begin
      return Res : TOML.TOML_Value := TOML.Create_Table do
         Res.Set
           ("start_line", TOML.Create_Integer
                            (TOML.Any_Integer (Span.Start_Sloc.Line)));
         Res.Set
           ("start_col", TOML.Create_Integer
                           (TOML.Any_Integer (Span.Start_Sloc.Column)));
         Res.Set
           ("end_line", TOML.Create_Integer
                          (TOML.Any_Integer (Span.End_Sloc.Line)));
         Res.Set
           ("end_col", TOML.Create_Integer
                         (TOML.Any_Integer (Span.End_Sloc.Column)));
      end return;
   end Write_Span;

end Stable_Sloc.TOML_Utils;
