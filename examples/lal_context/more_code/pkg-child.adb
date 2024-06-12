package body Pkg.Child is

   procedure More_Content (X : Integer) is
   begin
      null;
   end More_Content;

   procedure Bar (X : Integer_Access; Res : out Integer) is
   begin
      if X = null then
         raise Constraint_Error;
      end if;
      if X.all < 0 then
         Res := -X.all;
      else
         Res := X.all;
      end if;
   end Bar;

end Pkg.Child;
