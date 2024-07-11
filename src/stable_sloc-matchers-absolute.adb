--
--  Copyright (C) 2024, AdaCore
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
--

with Ada.Exceptions;

with GNAT.Strings;

with GNATCOLL.Utils;

with Stable_Sloc.TOML_Utils;
with Stable_Sloc_Strings; use Stable_Sloc_Strings;

package body Stable_Sloc.Matchers.Absolute is

   -----------
   -- Match --
   -----------

   overriding function Match
     (Self : Absolute_Matcher;
      File : Virtual_File) return Sloc_Match_Vec
   is
      use GNATCOLL.Utils;
      use type GNAT.Strings.String_Access;
      Buffer_Acc : GNAT.Strings.String_Access :=
        GNATCOLL.VFS.Read_File (File);

      Res : Sloc_Match := (Success => True, Span => Self.Span);
   begin
      if Buffer_Acc = null then
         return [Sloc_Match'
                   (Success => False,
                    Reason  => +"Could not read " & File.Display_Full_Name)];
      end if;

      declare
         Buffer : String renames Buffer_Acc.all;
         Index  : Natural := Buffer'First;
         Actual : Natural;
         --  Various indices in the file

      begin
         --  Move to the first line and check if we actually have enough lines
         --  in the file.

         Skip_Lines (Buffer, Self.Span.Start_Sloc.Line - 1, Index, Actual);

         if Actual /= Self.Span.Start_Sloc.Line - 1 then
            return [Sloc_Match'
                      (False,
                       Reason =>
                         +"Not enough lines in " & File.Display_Full_Name
                         & " to contain the sloc range " & Image (Self.Span))];
         end if;
         --  Check the number of characters in the file: move one character
         --  forward and count the number of chars until we reach the
         --  designated sloc a new line or the end of the file.

         Actual := 1;
         while Actual < Self.Span.Start_Sloc.Column
              and then Index < Buffer'Last
              and then Buffer (Index) /= ASCII.LF
         loop
            Actual := Actual + 1;
            Index := Forward_UTF8_Char (Buffer, Index);
         end loop;

         if Actual < Self.Span.Start_Sloc.Column then
            Res := (False,
                    Reason => +"Line" & Self.Span.Start_Sloc.Line'Image
                              & " of " & File.Display_Full_Name
                              & " is not long enough. Required"
                              & Self.Span.Start_Sloc.Column'Image
                              & " characters but got"
                              & Natural'Image (Actual) & ".");
         end if;

         --  Do the same for the end Sloc. Note that this does not prevent the
         --  designation of an empty range.

         if Res.Success then
            Index := Buffer'First;

            Skip_Lines (Buffer, Self.Span.End_Sloc.Line - 1, Index, Actual);

            if Actual /= Self.Span.End_Sloc.Line - 1 then
               return [Sloc_Match'
                         (False,
                          Reason =>
                            +"Not enough lines in " & File.Display_Full_Name
                            & " to contain the sloc range "
                            & Image (Self.Span))];
            end if;

            Actual := 1;
            while Actual < Self.Span.End_Sloc.Column
                 and then Index < Buffer'Last
                 and then Buffer (Index) /= ASCII.LF
            loop
               Actual := Actual + 1;
               Index := Forward_UTF8_Char (Buffer, Index);
            end loop;
            if Actual < Self.Span.End_Sloc.Column then
               Res := (False,
                       Reason => +"Line" & Self.Span.End_Sloc.Line'Image
                                 & " of " & File.Display_Full_Name
                                 & " is not long enough. Required"
                                 & Self.Span.End_Sloc.Column'Image
                                 & " characters but got"
                                 & Natural'Image (Actual) & ".");
            end if;
         end if;
      end;

      GNAT.Strings.Free (Buffer_Acc);
      return [Res];

   exception
      when Exc : others =>
         if Buffer_Acc /= null then
            GNAT.Strings.Free (Buffer_Acc);
         end if;
         return
           [Sloc_Match'
              (Success => False,
               Reason  => +"Error while reading "
                          & File.Display_Full_Name
                          & ": " & Ada.Exceptions.Exception_Message (Exc))];
   end Match;

   ---------------
   -- Dump_Spec --
   ---------------

   overriding function Dump_Spec
     (Self : Absolute_Matcher) return TOML.TOML_Value is
     (Stable_Sloc.TOML_Utils.Write_Span (Self.Span));

   -----------
   -- Image --
   -----------

   overriding function Image (Self : Absolute_Matcher) return Unbounded_String
   is
   begin
      return +"absolute matcher for " & Image (Self.Span);
   end Image;

   ------------
   -- Create --
   ------------

   function Create
     (Spec : TOML.TOML_Value) return Sloc_Matcher_T'Class is
     (Absolute_Matcher'(Span => Stable_Sloc.TOML_Utils.Read_Span (Spec)));

   ------------
   -- Create --
   ------------

   function Create
     (File : Virtual_File; Span : Sloc_Span) return Sloc_Matcher_T'Class is
     (Absolute_Matcher'(Span => Span));

end Stable_Sloc.Matchers.Absolute;
