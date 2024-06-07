--
--  Copyright (C) 2024, AdaCore
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
--

with Ada.Exceptions;
with Ada.Text_IO;
with Ada.Unchecked_Deallocation;

with GNAT.OS_Lib; use GNAT.OS_Lib;

with Stable_Sloc.TOML_Utils; use Stable_Sloc.TOML_Utils;
with Stable_Sloc_Strings; use Stable_Sloc_Strings;

package body Stable_Sloc.Matchers.Regexp is

   function Count_LF
     (Text : GNAT.OS_Lib.String_Access; From, To : Natural) return Natural with
     Pre => Text not in null;
   --  Count the number of line feed characters in Text in the range
   --  From .. To (inclusive).

   function Prev_LF
     (Text : GNAT.OS_Lib.String_Access; From : Natural) return Natural with
     Pre => Text not in null;
   --  Return the number of characters between From and the previous new line
   --  in Text. Return From if there is no new line before From.

   -----------
   -- Match --
   -----------

   overriding function Match
     (Self : Regexp_Matcher;
      File : Virtual_File) return Sloc_Match_Vec
   is
      use GNAT.Regpat;

      Content   : GNAT.OS_Lib.String_Access := GNATCOLL.VFS.Read_File (File);
      Match_Arr : Match_Array (0 .. 0);
      From      : Positive;
      Res       : Sloc_Match_Vec;
   begin
      if Content = null then
         return
           [1 => (Success => False,
                  Reason  =>
                    (+"Could not read from file ")
                     & GNATCOLL.VFS."+" (File.Full_Name))];
      end if;
      From := Content.all'First;
      loop
         Match (Self.Regexp.Get, Content.all, Match_Arr, From);
         exit when Match_Arr (0) = No_Match;
         declare
            Start_Line : constant Natural :=
              Count_LF (Content, Content.all'First, Match_Arr (0).First) + 1;
            Start_Col  : constant Natural :=
              Prev_LF (Content, Match_Arr (0).First);
            End_Line   : constant Natural :=
              Start_Line + Count_LF
                (Content,
                 Match_Arr (0).First,
                 Match_Arr (0).Last);
            End_Col    : constant Natural :=
              Prev_LF (Content, Match_Arr (0).Last) + 1;
         begin
            Res.Append
              (Sloc_Match'
                 (Success => True,
                  Span    =>
                    (Start_Sloc => (Start_Line, Start_Col),
                     End_Sloc   => (End_Line, End_Col))));
            From := Match_Arr (0).Last + 1;
         end;
      end loop;
      GNAT.OS_Lib.Free (Content);
      return Res;
   end Match;

   ------------
   -- Create --
   ------------

   function Create
     (Spec : TOML.TOML_Value) return Sloc_Matcher_T'Class
   is
      use GNAT.Regpat;
   begin
      return Res : Regexp_Matcher do
         Res.Orig_Spec := Get (Spec, "regexp");
         Res.Flags := No_Flags;
         if Spec.Has ("case_insensitive") then
            Res.Flags := Res.Flags
              + (if Get (Spec, "case_insensitive")
                 then Case_Insensitive
                 else No_Flags);
         end if;
         if Spec.Has ("multi_line") then
            Res.Flags := Res.Flags
              + (if Get (Spec, "multi_line")
                 then Multiple_Lines
                 else No_Flags);
         end if;
         if Spec.Has ("single_line") then
            Res.Flags := Res.Flags
              + (if Get (Spec, "single_line") then Single_Line else No_Flags);
         end if;
         Res.Regexp.Set (Compile (To_String (Res.Orig_Spec), Res.Flags));
      end return;
   exception
      when Exc : Parse_Error =>
         raise;
      when Exc : Expression_Error =>
         raise Parse_Error with
            TOML.Format_Location (Spec.Get ("regexp").Location)
            & ":Failed to compile regular expression: "
            & Ada.Exceptions.Exception_Message (Exc);
      when Exc : others =>
         raise Parse_Error with
           "Failed to parse spec: " & ASCII.LF
           & Spec.Dump_As_String & ASCII.LF
           & Ada.Exceptions.Exception_Information (Exc);
   end Create;

   ---------------
   -- Dump_Spec --
   ---------------

   overriding function Dump_Spec
     (Self : Regexp_Matcher) return TOML.TOML_Value
   is
      use type GNAT.Regpat.Regexp_Flags;
      --  From System.Regpat:
      --    No_Flags         : constant Regexp_Flags := 0;
      --    Case_Insensitive : constant Regexp_Flags := 1;
      --    Single_Line      : constant Regexp_Flags := 2;
      --    Multiple_Lines   : constant Regexp_Flags := 4;

      Case_Insensitive : constant Boolean := Self.Flags mod 2 = 1;
      Single_Line      : constant Boolean := (Self.Flags / 2) mod 2 = 1;
      Multi_Line       : constant Boolean := (Self.Flags / 4) mod 2 = 1;
   begin
      return Res : TOML.TOML_Value := TOML.Create_Table do
         Res.Set ("regexp", TOML.Create_String (Self.Orig_Spec));
         Res.Set ("case_insensitive", TOML.Create_Boolean (Case_Insensitive));
         Res.Set ("single_line", TOML.Create_Boolean (Single_Line));
         Res.Set ("multi_line", TOML.Create_Boolean (Multi_Line));
      end return;
   end Dump_Spec;

   -----------
   -- Image --
   -----------

   overriding function Image (Self : Regexp_Matcher) return Unbounded_String
   is
   begin
      return "Regexp matcher searching: " & Self.Orig_Spec;
   end Image;

   --------------
   -- Count_LF --
   --------------

   function Count_LF
     (Text : GNAT.OS_Lib.String_Access; From, To : Natural) return Natural
   is
      Res : Natural := 0;
      Cur : Natural := From;
   begin
      if From not in Text.all'First .. Text.all'Last
        or else To not in Text.all'First .. Text.all'Last
      then
         return 0;
      end if;
      while Cur <= To and then Cur < Text.all'Last loop
         if Text (Cur) = ASCII.LF then
            Res := Res + 1;
         end if;
         Cur := Cur + 1;
      end loop;
      return Res;
   end Count_LF;

   -------------
   -- Prev_LF --
   -------------

   function Prev_LF
     (Text : GNAT.OS_Lib.String_Access; From : Natural) return Natural
   is
      Cur : Natural := From;
   begin
      if From not in Text.all'First .. Text.all'Last then
         return 0;
      end if;
      loop
         exit when Cur <= 0 or else Text (Cur) = ASCII.LF;
         Cur := Cur - 1;
      end loop;
      return From - Cur;
   end Prev_LF;

end Stable_Sloc.Matchers.Regexp;
