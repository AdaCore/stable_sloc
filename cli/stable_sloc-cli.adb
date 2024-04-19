with Ada.Command_Line;
with Ada.Text_IO; use Ada.Text_IO;

with Stable_Sloc.Cmd_Parser;
with Stable_Sloc_Strings;    use Stable_Sloc_Strings;

procedure Stable_Sloc.CLI is
   package Cmd renames Cmd_Parser;
begin
   if not Cmd.Parser.Parse then
      Ada.Command_Line.Set_Exit_Status (1);
      return;
   end if;

   declare
      Specs : constant Cmd.Specs.Result_Array := Cmd.Specs.Get;
      Files : constant Cmd.Files.Result_Array := Cmd.Files.Get;
      DB    : Entry_DB := Create_DB;
   begin
      if Specs'Length = 0 and then not Cmd.Quiet.Get then
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
              Load_Entries (Spec, DB, Cmd.Strict.Get);
         begin
            for Err of Parse_Errors loop
               Put_Line
                 (Standard_Error,
                   Err.File.Display_Base_Name & ":" & Image (Err.Location)
                  & " " & (+Err.Diagnostic));
            end loop;
            if Parse_Errors'Length > 0 and then Cmd.Strict.Get then
               Ada.Command_Line.Set_Exit_Status (1);
               return;
            end if;
         end;
      end loop;
      if Cmd.Verbose.Get then
         Dump_Entries (DB);
      end if;
      if Files'Length = 0 and then not Cmd.Quiet.Get then
         Put_Line ("Not files to process, nothing to do.");
         return;
      end if;
      declare
         VF_Arr : constant GNATCOLL.VFS.File_Array :=
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
   end;

end Stable_Sloc.CLI;
