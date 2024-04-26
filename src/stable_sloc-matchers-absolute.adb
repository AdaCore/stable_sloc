with Ada.Exceptions;
with Ada.IO_Exceptions;
with Ada.Text_IO;    use Ada.Text_IO;

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
      File_T   : File_Type;
      Res      : Sloc_Match := (Success => True, Span => Self.Span);
   begin
      Open (File_T, In_File, +File.Full_Name);
      Set_Line (File_T, Positive_Count (Self.Span.Start_Sloc.Line));
      declare
         Line : String := Get_Line (File_T);
      begin
         if Self.Span.Start_Sloc.Column > Line'Length then
            Res := (False,
                    Reason =>
                      +"Line" & Self.Span.Start_Sloc.Line'Image & " of "
                      & File.Display_Full_Name
                      & " is not long enough. Required"
                      & Self.Span.Start_Sloc.Column'Image
                      & " characters but got" & Natural'Image (Line'Length)
                      & ".");
         end if;
      end;
      if Res.Success then
         Set_Line (File_T, Positive_Count (Self.Span.End_Sloc.Line));
         declare
            Line : String := Get_Line (File_T);
         begin
            if Self.Span.End_Sloc.Column > Line'Length then
               Res := (False,
                       Reason =>
                         +"Line" & Self.Span.End_Sloc.Line'Image & " of "
                         & File.Display_Full_Name
                         & " is not long enough. Required"
                         & Self.Span.End_Sloc.Column'Image
                         & " characters but got" & Natural'Image (Line'Length)
                         & ".");
            end if;
         end;
      end if;
      Close (File_T);
      return [Res];
   exception
      when Exc : Ada.IO_Exceptions.End_Error =>
         if Is_Open (File_T) then
            Close (File_T);
         end if;
         return [Sloc_Match'
                   (False,
                    Reason =>
                      +"Not enough lines in " & File.Display_Full_Name
                      & " to contain the sloc range " & Image (Self.Span))];
      when Exc : others =>
         if Is_Open (File_T) then
            Close (File_T);
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
     (Self : Absolute_Matcher) return TOML.TOML_Value
   is
   begin
      return Res : TOML.TOML_Value := TOML.Create_Table do
         Res.Set
           ("start_line", TOML.Create_Integer
                            (TOML.Any_Integer (Self.Span.Start_Sloc.Line)));
         Res.Set
           ("start_col", TOML.Create_Integer
                           (TOML.Any_Integer (Self.Span.Start_Sloc.Column)));
         Res.Set
           ("end_line", TOML.Create_Integer
                          (TOML.Any_Integer (Self.Span.End_Sloc.Line)));
         Res.Set
           ("end_col", TOML.Create_Integer
                         (TOML.Any_Integer (Self.Span.End_Sloc.Column)));
      end return;
   end Dump_Spec;

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
     (Spec : TOML.TOML_Value) return Sloc_Matcher_T'Class
   is
      use Stable_Sloc.TOML_Utils;
      SL : constant Natural := Get (Spec, "start_line");
      SC : constant Natural := Get (Spec, "start_column");
      EL : constant Natural := Get (Spec, "end_line");
      EC : constant Natural := Get (Spec, "end_column");
   begin
      return Absolute_Matcher'
        (Span => (Start_Sloc => (SL, SC), End_Sloc => (EL, EC)));
   end Create;

   ------------
   -- Create --
   ------------

   function Create
     (File : Virtual_File; Span : Sloc_Span) return Sloc_Matcher_T'Class
   is
   begin
      return Absolute_Matcher'(Span => Span);
   end Create;

end Stable_Sloc.Matchers.Absolute;
