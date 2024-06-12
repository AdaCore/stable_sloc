package Pkg is

   type Integer_Access is access all Integer;

   function Foo (X : Integer_Access) return Integer;

   function Foo (X : Integer_Access) return Boolean;

   procedure Bar (X : Integer_Access; Res : out Integer);

end Pkg;
pragma Preelaborate(Pkg);