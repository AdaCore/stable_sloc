--
--  Copyright (C) 2024, AdaCore
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
--

with Ada.Text_IO; use Ada.Text_IO;

with Stable_Sloc.TOML_Utils;

package body Stable_Sloc.Reporters.Text is

   overriding
   function New_Reporter return Text_Reporter
   is (Ada.Finalization.Controlled with null record);

   -----------------------------
   -- Report_Load_Diagnostics --
   -----------------------------

   overriding
   procedure Report_Load_Diagnostics
     (Self : in out Text_Reporter; Diags : Load_Diagnostic_Arr) is
   begin
      for Diag of Diags loop
         Put_Line (Standard_Error, Format_Diagnostic (Diag));
      end loop;
   end Report_Load_Diagnostics;

   --------------------------
   -- Report_Match_Results --
   --------------------------

   overriding
   procedure Report_Match_Results
     (Self : in out Text_Reporter; Matches : Match_Result_Vec) is
   begin
      if Matches.Is_Empty then
         Put_Line ("No match.");
      else
         for Match of Matches loop
            Put (+Match.Identifier & ": ");
            if Match.Success then
               Put_Line ("match SUCCESS");
               Put_Line
                 ("   "
                  & Match.File.Display_Full_Name
                  & ":"
                  & Image (Match.Location));
            else
               Put_Line ("match FAILED");
               Put_Line ("   " & Match.File.Display_Full_Name);
               Put_Line ("   Reason: " & (+Match.Diagnostic));
            end if;
            Put_Line
              ("   Annotation:"
               & ASCII.LF
               & "      "
               & (Stable_Sloc.TOML_Utils.To_JSON (Match.Annotation).Write));
         end loop;
      end if;
   end Report_Match_Results;

end Stable_Sloc.Reporters.Text;
