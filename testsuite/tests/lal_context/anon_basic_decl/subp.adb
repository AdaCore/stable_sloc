with Ada.Text_IO; use Ada.Text_IO;

procedure Subp is
begin
   Put_Line ("Attempting dangerous Math...");
   Put_Line (Integer'(1/0)'Image);
exception
   when others =>
      Put_Line ("Something went wrong..");
end Subp;
