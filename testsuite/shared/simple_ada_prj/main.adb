with Pkg;
with Pkg.Child;

procedure Main is
   Y : aliased Integer := -5;
   X : Pkg.Integer_Access := Y'Unrestricted_Access;
begin
   pragma Assert (Pkg.Foo (X) = -5);
   pragma Assert (not Pkg.Foo (X));
   Pkg.Child.Bar (X, Y);
   pragma Assert (Y = 5);
end Main;
