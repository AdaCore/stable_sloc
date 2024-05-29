package body Pkg is

   function Foo (X : Integer_Access) return Integer is
   begin
      if X = null then
         raise Program_Error;
      end if;
      return X.all;
   end Foo;

   function Foo (X : Integer_Access) return Boolean is
   begin
      if X = null then
         raise Constraint_Error;
      end if;
      return X.all = 3;
   end Foo;

end Pkg;
