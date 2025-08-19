--
--  Copyright (C) 2024, AdaCore
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
--

--  Reporter output JSON diagnostics and results to standard output

with GNATCOLL.JSON;

package Stable_Sloc.Reporters.JSON is

   type JSON_Reporter is new Reporter with record
      Do_Report : Boolean := False;
      --  Finalization can happen multiple times as the reporter object is
      --  first initialized. Only emit a report once a call to Report_* has
      --  actually taken place.

      Load_Diagnostics : GNATCOLL.JSON.JSON_Value;
      Match_Results    : GNATCOLL.JSON.JSON_Value;
   end record;

   overriding
   procedure Finalize (Self : in out JSON_Reporter);
   --  Write and format self on the standard output, if the JSON output is
   --  enabled.

   overriding
   function New_Reporter return JSON_Reporter;
   --  Create a new reporter

   overriding
   procedure Report_Load_Diagnostics
     (Self : in out JSON_Reporter; Diags : Load_Diagnostic_Arr);
   --  Add the load diagnostics into Self

   overriding
   procedure Report_Match_Results
     (Self : in out JSON_Reporter; Matches : Match_Result_Vec);
   --  Add the match results into Self

end Stable_Sloc.Reporters.JSON;
