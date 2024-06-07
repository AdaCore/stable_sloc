--
--  Copyright (C) 2024, AdaCore
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
--

with Ada.Text_IO;

with GNATCOLL.JSON; use GNATCOLL.JSON;

package body Stable_Sloc.Reporters.JSON is

   procedure Append_Array (Dest : JSON_Value; Src : JSON_Value) with
     Pre => Dest.Kind = JSON_Array_Type and then Src.Kind = JSON_Array_Type;
   --  Append Src to Dest

   --------------
   -- Finalize --
   --------------

   overriding procedure Finalize (Self : in out JSON_Reporter) is
      Res : constant JSON_Value := Create_Object;
   begin
      if Self.Do_Report then
         Res.Set_Field ("load_diagnostics",Self.Load_Diagnostics);
         Res.Set_Field ("match_results", Self.Match_Results);
         Ada.Text_IO.Put_Line (Res.Write (Compact => False));
      end if;
   end Finalize;

   overriding function New_Reporter return JSON_Reporter is
     (Ada.Finalization.Controlled with
      Load_Diagnostics => Create (Empty_Array),
      Match_Results    => Create (Empty_Array),
      Do_Report        => False);

   -----------------------------
   -- Report_Load_Diagnostics --
   -----------------------------

   procedure Report_Load_Diagnostics
     (Self : in out JSON_Reporter; Diags : Load_Diagnostic_Arr)
   is
   begin
      Self.Do_Report := True;
      Append_Array (Self.Load_Diagnostics, To_JSON (Diags));
   end Report_Load_Diagnostics;

   --------------------------
   -- Report_Match_Results --
   --------------------------

   procedure Report_Match_Results
     (Self : in out JSON_Reporter; Matches : Match_Result_Vec)
   is
   begin
      Self.Do_Report := True;
      Append_Array (Self.Match_Results, To_JSON (Matches));
   end Report_Match_Results;

   ------------------
   -- Append_Array --
   ------------------

   procedure Append_Array (Dest : JSON_Value; Src : JSON_Value) is
   begin
      for Item of JSON_Array'(Src.Get) loop
         Dest.Append (Item);
      end loop;
   end Append_Array;

end Stable_Sloc.Reporters.JSON;
