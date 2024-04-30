with Ada.Command_Line;
with Ada.Directories;
with Ada.Text_IO; use Ada.Text_IO;

with Stable_Sloc.Cmd_Parser;
with Stable_Sloc_Strings;    use Stable_Sloc_Strings;

procedure Stable_Sloc.CLI is
   package Cmd renames Cmd_Parser;

   procedure Put_Err (Err : Load_Diagnostic);
   --  Output Err to Standard Error

   -------------
   -- Put_Err --
   -------------

   procedure Put_Err (Err : Load_Diagnostic) is
   begin
      Put_Line
        (Standard_Error,
         Err.File.Display_Base_Name & ":" & Image (Err.Location)
         & " " & (+Err.Diagnostic));
   end Put_Err;

begin
   if not Cmd.Parser.Parse then
      Ada.Command_Line.Set_Exit_Status (1);
      return;
   end if;

   declare
      use GNATCOLL.VFS;
      Specs   : constant Cmd.Specs.Result_Array := Cmd.Specs.Get;
      Files   : constant Cmd.Files.Result_Array := Cmd.Files.Get;
      Updates : constant Cmd.Update_Requests.Result_Array :=
        Cmd.Update_Requests.Get;
      Output  : Virtual_File := Cmd.Output.Get;
      DB      : Entry_DB := Create_DB;
   begin
      --  Parse Spec files

      if Specs'Length = 0
        and then not Cmd.Quiet.Get
        and then Updates'Length = 0
      then
         Put_Line
           ("No specs passed on command line (-s or --spec), nothing to do.");
         return;
      end if;
      for Spec of Specs loop
         if Cmd.Verbose.Get then
            Put_Line ("Loading entries from " & Spec.Display_Base_Name);
         end if;
         declare
            Parse_Errors : constant Load_Diagnostic_Arr :=
              Load_Entries (Spec, DB, Strict => Cmd.Strict.Get);
         begin
            for Err of Parse_Errors loop
               Put_Err (Err);
            end loop;
            if Parse_Errors'Length > 0 and then Cmd.Strict.Get then
               Ada.Command_Line.Set_Exit_Status (1);
               return;
            end if;
         end;
      end loop;

      --  Process update requests

      for Update_Req of Updates loop
         declare
            Diags : constant Load_Diagnostic_Arr :=
              Add_Or_Update_Entry
                (DB,
                 Update_Req.Identifier,
                 Update_Req.Purpose,
                 Update_Req.Annotation,
                 Update_Req.Kind,
                 Update_Req.File,
                 Update_Req.Span,
                 File_Prefix           => Cmd.Prefix.Get,
                 Replace               => not Cmd.Strict.Get);
         begin
            if Diags'Length /= 0 then
               Put_Err (Diags (Diags'First));
               if Cmd.Strict.Get then
                  Ada.Command_Line.Set_Exit_Status (1);
                  return;
               end if;
            end if;
         end;
      end loop;

      if Cmd.Verbose.Get then
         Dump_Entries (DB);
      end if;

      --  Match the entries on the passed files

      if Files'Length = 0
        and then not Cmd.Quiet.Get
        and then Output = No_File
      then
         Put_Line ("Not files to process, nothing to do.");
         return;
      end if;
      declare
         VF_Arr : constant File_Array :=
           [for File of Files => File];
         Res    : constant Match_Result_Vec :=
           Match_Entries (VF_Arr, DB, +Cmd.Filter.Get);
      begin
         if Res.Is_Empty then
            Put_Line ("No match.");
         end if;
         for Match of Res loop
            Put (+Match.Identifier & ": ");
            if Match.Success then
               Put_Line ("match SUCCESS");
               Put_Line
                 ("   " & Match.File.Display_Full_Name & ":"
                  & Image (Match.Location));
            else
               Put_Line ("match FAILED");
               Put_Line ("   " & Match.File.Display_Full_Name);
               Put_Line ("   Reason: " & (+Match.Diagnostic));
            end if;
            Put_Line
               ("   Purpose: " & (+Match.Purpose));
            Put_Line
               ("   Annotation: " & (+Match.Annotation));
         end loop;
      end;

      --  Dump the entries to file

      if Output /= No_File and then not Output.Is_Absolute_Path
      then
         Output := Get_Current_Dir / Output;
      end if;
      if Output /= No_File then
         if Output.Get_Parent /= No_File and then
           not Output.Get_Parent.Is_Regular_File
         then
            Output.Get_Parent.Make_Dir (Recursive => True);
         end if;
         Write_Entries (DB, Output);
      end if;
   end;

end Stable_Sloc.CLI;
