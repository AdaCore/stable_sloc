--
--  Copyright (C) 2024, AdaCore
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
--

--  Simple CLI tool exposing most of the library functionality
--  (except custom backends).

with Ada.Command_Line;
with Ada.Text_IO; use Ada.Text_IO;

with Stable_Sloc.Cmd_Parser;
with Stable_Sloc.Reporters.JSON;
with Stable_Sloc.Reporters.Text;
with Stable_Sloc_Strings; use Stable_Sloc_Strings;

procedure Stable_Sloc.CLI is
   package Cmd renames Cmd_Parser;

begin
   if not Cmd.Parser.Parse then
      Ada.Command_Line.Set_Exit_Status (1);
      return;
   end if;

   declare
      use GNATCOLL.VFS;
      Specs    : constant Cmd.Specs.Result_Array := Cmd.Specs.Get;
      Files    : constant Cmd.Files.Result_Array := Cmd.Files.Get;
      Updates  : constant Cmd.Update_Requests.Result_Array :=
        Cmd.Update_Requests.Get;
      Output   : Virtual_File := Cmd.Output.Get;
      DB       : Entry_DB := Create_DB;
      Reporter : Stable_Sloc.Reporters.Reporter'Class :=
        (if Cmd.JSON_Results.Get
         then Stable_Sloc.Reporters.JSON.New_Reporter
         else Stable_Sloc.Reporters.Text.New_Reporter);
   begin
      --  Parse Spec files. Allow to not have any spec file on the command line
      --  if we have at least one entry update request.

      if Specs'Length = 0
        and then not Cmd.Quiet.Get
        and then Updates'Length = 0
      then
         Reporter.Report_Load_Diagnostics
           ([1 =>
               Load_Diagnostic'
                 (File       => GNATCOLL.VFS.Create (""),
                  Location   => No_Sloc,
                  Diagnostic =>
                    +("No specs passed on command line (-s or"
                      & " --spec), nothing to do."))]);
         return;
      end if;
      for Spec of Specs loop
         if Cmd.Verbose.Get then
            Put_Line ("Loading entries from " & Spec.Display_Base_Name);
         end if;
         declare
            Parse_Errors : constant Load_Diagnostic_Arr :=
              Load_Entries
                (Spec,
                 DB,
                 Ignore_Unknown => not Cmd.Unknown_Matcher.Get,
                 Strict         => Cmd.Strict.Get);
         begin
            Reporter.Report_Load_Diagnostics (Parse_Errors);
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
                 Update_Req.Annotation,
                 Update_Req.Kind,
                 Update_Req.File,
                 Update_Req.Span,
                 File_Prefix => Cmd.Prefix.Get,
                 Replace     => not Cmd.Strict.Get);
         begin
            if Diags'Length /= 0 then
               Reporter.Report_Load_Diagnostics (Diags);
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

      --  Dump the entries to file

      if Output /= No_File and then not Output.Is_Absolute_Path then
         Output := Get_Current_Dir / Output;
      end if;
      if Output /= No_File then
         if Output.Get_Parent /= No_File
           and then not Output.Get_Parent.Is_Regular_File
         then
            Output.Get_Parent.Make_Dir (Recursive => True);
         end if;
         Write_Entries (DB, Output);
      end if;

      --  Match the entries on the passed files

      if Files'Length = 0 then
         if Cmd.Verbose.Get and then Output = No_File then
            Put_Line ("No files to process, nothing to do.");
         end if;
         return;
      end if;
      declare
         VF_Arr : constant File_Array := [for File of Files => File];
         Res    : Match_Result_Vec :=
           Match_Entries (VF_Arr, DB, +Cmd.Filter.Get);
      begin
         Sort (Res);
         Reporter.Report_Match_Results (Res);
      end;
   end;

end Stable_Sloc.CLI;
