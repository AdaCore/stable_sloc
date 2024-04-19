with Stable_Sloc.Matchers;

package body Stable_Sloc.TOML_Utils is

   ---------
   -- Get --
   ---------

   function Get (Val : TOML.TOML_Value; Key : String) return Boolean is
   begin
      if Val.Kind /= TOML_Table then
         raise Stable_Sloc.Matchers.Parse_Error with
           "Can't get " & Key & " from a " & Val.Kind'Image;
      end if;
      if not Val.Has (Key) then
         raise Stable_Sloc.Matchers.Parse_Error with
           "Missing " & Key & " field";
      end if;
      if Val.Get (Key).Kind /= TOML_Boolean then
         raise Stable_Sloc.Matchers.Parse_Error with
            "Unexpected type for """ & Key & """: expected "
            & TOML_Boolean'Image & " but got " & Val.Get (Key).Kind'Image;
      end if;
      return Val.Get (Key).As_Boolean;
   end Get;

   function Get (Val : TOML.TOML_Value; Key : String) return Integer is
   begin
      if Val.Kind /= TOML_Table then
         raise Stable_Sloc.Matchers.Parse_Error with
           "Can't get " & Key & " from a " & Val.Kind'Image;
      end if;
      if not Val.Has (Key) then
         raise Stable_Sloc.Matchers.Parse_Error with
           "Missing " & Key & " field";
      end if;
      if Val.Get (Key).Kind /= TOML_Integer then
         raise Stable_Sloc.Matchers.Parse_Error with
            "Unexpected type for """ & Key & """: expected "
            & TOML_Integer'Image & " but got " & Val.Get (Key).Kind'Image;
      end if;
      return Integer (Val.Get (Key).As_Integer);
   end Get;

   function Get (Val : TOML.TOML_Value; Key : String) return String is
   begin
      if Val.Kind /= TOML_Table then
         raise Stable_Sloc.Matchers.Parse_Error with
           "Can't get " & Key & " from a " & Val.Kind'Image;
      end if;
      if not Val.Has (Key) then
         raise Stable_Sloc.Matchers.Parse_Error with
           "Missing " & Key & " field";
      end if;
      if Val.Get (Key).Kind /= TOML_String then
         raise Stable_Sloc.Matchers.Parse_Error with
            "Unexpected type for """ & Key & """: expected "
            & TOML_String'Image & " but got " & Val.Get (Key).Kind'Image;
      end if;
      return Val.Get (Key).As_String;
   end Get;

   function Get
     (Val : TOML.TOML_Value; Key : String) return Unbounded_UTF8_String is
   begin
      if Val.Kind /= TOML_Table then
         raise Stable_Sloc.Matchers.Parse_Error with
           "Can't get " & Key & " from a " & Val.Kind'Image;
      end if;
      if not Val.Has (Key) then
         raise Stable_Sloc.Matchers.Parse_Error with
           "Missing " & Key & " field";
      end if;
      if Val.Get (Key).Kind /= TOML_String then
         raise Stable_Sloc.Matchers.Parse_Error with
            "Unexpected type for """ & Key & """: expected "
            & TOML_String'Image & " but got " & Val.Get (Key).Kind'Image;
      end if;
      return Val.Get (Key).As_Unbounded_String;
   end Get;

end Stable_Sloc.TOML_Utils;
