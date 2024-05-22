with Ada.Exceptions;
with Ada.Strings.Fixed;
with Ada.Strings.Maps;

package body Stable_Sloc.Cmd_Parser is

   --------------------------
   -- Parse_Update_Request --
   --------------------------

   function Parse_Update_Request (Arg : String) return Update_Request
   is
      function Get_Field (From : in out Positive; What : String) return String;
      --  Parse one field from Arg, reading from From and advancing it upon
      --  successful read. Use What as the missing field name in diagnostics.

      use Ada.Strings.Fixed;
      use Ada.Strings.Maps;
      Col        : constant Character_Set := To_Set (':');
      Low        : Natural := Arg'First;
      Res        : Update_Request;
      Annotation : TOML.Read_Result;

      ---------------
      -- Get_Field --
      ---------------

      function Get_Field (From : in out Positive; What : String) return String
      is
         To : Natural;
         Old_From : constant Positive := From;
      begin
         if From not in Arg'Range then
            raise Opt_Parse_Error with "Missing " & What & " value";
         end if;
         To := Index (Arg, Col, From);
         if To = 0 then
            To := Arg'Last + 1;
            From := Arg'Last + 1;
         else
            From := To + 1;
         end if;
         return Arg (Old_From .. To - 1);
      end Get_Field;

   begin
      --  The argument should formatted as
      --
      --  IDENTIFIER:KIND:FILENAME:START_LINE:START_COL:
      --  END_LINE:END_COL:ANNOTATION
      --
      --  with no ':' in either of the fields.

      Res.Identifier := +Get_Field (Low, "IDENTIFIER");
      Res.Kind := +Get_Field (Low, "KIND");
      Res.File := Str_To_File (Get_Field (Low, "FILENAME"));
      declare
         Line : constant String := Get_Field (Low, "START_LINE");
      begin
         Res.Span.Start_Sloc.Line := Natural'Value (Line);
      exception
         when Exc : Constraint_Error =>
            raise Opt_Parse_Error with "START_LINE must be a positive integer";
      end;
      declare
         Col : constant String := Get_Field (Low, "START_COL");
      begin
         Res.Span.Start_Sloc.Column := Natural'Value (Col);
      exception
         when Exc : Constraint_Error =>
            raise Opt_Parse_Error with "START_COL must be a positive integer";
      end;
      declare
         Line : constant String := Get_Field (Low, "END_LINE");
      begin
         Res.Span.End_Sloc.Line := Natural'Value (Line);
      exception
         when Exc : Constraint_Error =>
            raise Opt_Parse_Error with "END_LINE must be a positive integer";
      end;
      declare
         Col : constant String := Get_Field (Low, "END_COL");
      begin
         Res.Span.End_Sloc.Column := Natural'Value (Col);
      exception
         when Exc : Constraint_Error =>
            raise Opt_Parse_Error with "END_COL must be a positive integer";
      end;
      Annotation := TOML.Load_String ("a=" & Get_Field (Low, "ANNOTATION"));
      if not Annotation.Success then
         raise Opt_Parse_Error with TOML.Format_Error (Annotation);
      end if;
      Res.Annotation := Annotation.Value.Get ("a");
      return Res;
   exception
      when Exc : Constraint_Error =>
         raise Opt_Parse_Error with Ada.Exceptions.Exception_Message (Exc);
   end Parse_Update_Request;

end Stable_Sloc.Cmd_Parser;
