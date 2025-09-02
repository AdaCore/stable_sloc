--
--  Copyright (C) 2024, AdaCore
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
--

with Ada.Strings.Fixed;

with Stable_Sloc;

package body Stable_Sloc_Strings is

   ---------------
   -- Is_Prefix --
   ---------------

   function Is_Prefix (Prefix, Content : Unbounded_String) return Boolean is
   begin
      if Length (Prefix) > Length (Content) then
         return False;
      end if;
      return
        (for all I in 1 .. Length (Prefix) =>
           Element (Prefix, I) = Element (Content, I));
   end Is_Prefix;

   ---------
   -- Img --
   ---------

   function Img (X : Integer) return String
   is (declare
         Str : constant String := X'Image;
       begin
         Str (Str'First + (if X < 0 then 0 else 1) .. Str'Last));

   ---------------
   -- To_Symbol --
   ---------------

   function To_Symbol (Vec : US_Vector; Sep : String) return Unbounded_String
   is
      use US_Vectors;
      Res : Unbounded_String := Null_Unbounded_String;
      Cur : Cursor := Vec.First;
   begin
      while Has_Element (Cur) loop
         Res := Res & Element (Cur);
         Next (Cur);
         if Has_Element (Cur) then
            Res := Res & Sep;
         end if;
      end loop;
      return Res;
   end To_Symbol;

   ---------------------
   -- Get_Sloc_Prefix --
   ---------------------

   function Split_Sloc_Prefix
     (S : String; Loc : out Stable_Sloc.Sloc) return String
   is
      use Ada.Strings.Fixed;
      Line, Col : Natural;
      Last_L    : Natural;
      Last_C    : Natural;
   begin
      Last_L := Index (S, ":");
      if Last_L /= 0 then
         Line := Integer'Value (S (S'First .. Last_L - 1));
      else
         raise Constraint_Error;
      end if;
      Last_C := Index (S, ":", Last_L + 1);
      if Last_C /= 0 then
         Col := Integer'Value (S (Last_L + 1 .. Last_C - 1));
      else
         raise Constraint_Error;
      end if;
      Loc := Stable_Sloc.Sloc'(Line, Col);
      return S (Last_C + 1 .. S'Last);
   exception
      when others =>
         Loc := Stable_Sloc.No_Sloc;
         return S;
   end Split_Sloc_Prefix;

end Stable_Sloc_Strings;
