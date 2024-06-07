--
--  Copyright (C) 2024, AdaCore
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
--

--  Simple reporter interface

with Ada.Finalization;

package Stable_Sloc.Reporters is

   type Reporter is abstract new Ada.Finalization.Controlled with
     null record;

   function New_Reporter return Reporter is abstract;
   --  Create a new reporter

   procedure Report_Load_Diagnostics
     (Self  : in out Reporter;
      Diags : Stable_Sloc.Load_Diagnostic_Arr) is abstract;
   --  Report on the diagnostics in Diags

   procedure Report_Match_Results
     (Self    : in out Reporter;
      Matches : Stable_Sloc.Match_Result_Vec) is abstract;
   --  Report on the match results in Matches

end Stable_Sloc.Reporters;
