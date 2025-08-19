--
--  Copyright (C) 2024, AdaCore
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
--

--  Standard output / Standard error based text reporter

package Stable_Sloc.Reporters.Text is

   type Text_Reporter is new Reporter with null record;

   overriding
   function New_Reporter return Text_Reporter;
   --  Create a new reporter

   overriding
   procedure Report_Load_Diagnostics
     (Self : in out Text_Reporter; Diags : Load_Diagnostic_Arr);
   --  Add the load diagnostics into Self

   overriding
   procedure Report_Match_Results
     (Self : in out Text_Reporter; Matches : Match_Result_Vec);
   --  Add the match results into Self

end Stable_Sloc.Reporters.Text;
