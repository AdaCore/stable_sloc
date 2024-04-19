with Ada.Exceptions;
with Ada.Unchecked_Deallocation;

with GNAT.OS_Lib; use GNAT.OS_Lib;

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
                    (+"Could not read from file")
                     & GNATCOLL.VFS."+" (File.Full_Name))];
      end if;
      From := Content.all'First;
      loop
         Match (Self.Regexp.all, Content.all, Match_Arr, From);
         exit when Match_Arr (0) = No_Match;
         declare
            Start_Line : constant Natural :=
              Count_LF (Content, From, Match_Arr (0).First) + 1;
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
      --  TODO??? Add proper validation of the spec prior to loading

      return Res : Regexp_Matcher do
         Res.Orig_Spec := Spec.Get ("regexp").As_Unbounded_String;
         Res.Flags := No_Flags;
         if Spec.Has ("case_insensitive") then
            Res.Flags := Res.Flags
              + (if Spec.Get ("case_insensitive").As_Boolean
                 then Case_Insensitive
                 else No_Flags);
         end if;
         if Spec.Has ("multi_line") then
            Res.Flags := Res.Flags
              + (if Spec.Get ("multi_line").As_Boolean
                 then Multiple_Lines
                 else No_Flags);
         end if;
         if Spec.Has ("single_line") then
            Res.Flags := Res.Flags
              + (if Spec.Get ("single_line").As_Boolean
                 then Single_Line
                 else No_Flags);
         end if;
         Res.Regexp := new Pattern_Matcher'
           (Compile (To_String (Res.Orig_Spec), Res.Flags));
      end return;
   exception
      when Exc : Expression_Error =>
         raise Parse_Error with
            "Failed to compile regular expression:" & ASCII.LF
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
   begin
      --  TODO??? Implement
      raise Program_Error with "TODO: Implement Dump_Spec for Regexp_Matcher";
      return TOML.No_TOML_Value;
   end Dump_Spec;

   -----------
   -- Image --
   -----------

   overriding function Image (Self : Regexp_Matcher) return Unbounded_String
   is
   begin
      return "Regexp matcher searching: " & Self.Orig_Spec;
   end Image;

   ----------
   -- Free --
   ----------

   procedure Free is new Ada.Unchecked_Deallocation
     (GNAT.Regpat.Pattern_Matcher, Regpat_Acc);

   --------------
   -- Finalize --
   --------------

   overriding procedure Finalize (Self : in out Regexp_Matcher) is
   begin
      Free (Self.Regexp);
   end Finalize;

   ------------
   -- Adjust --
   ------------

   overriding procedure Adjust (Self : in out Regexp_Matcher) is
   begin
      Self.Regexp := new GNAT.Regpat.Pattern_Matcher'(Self.Regexp.all);
   end Adjust;

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
