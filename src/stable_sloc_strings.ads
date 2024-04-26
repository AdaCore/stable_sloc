with Ada.Containers.Vectors;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded.Hash;
with Ada.Strings.Unbounded;

package Stable_Sloc_Strings is

   package Unbounded_Strings renames Ada.Strings.Unbounded;
   use Unbounded_Strings;
   subtype US is Unbounded_String;

   package US_Vectors is new Ada.Containers.Vectors
     (Index_Type => Natural, Element_Type => US);
   subtype US_Vector is US_Vectors.Vector;

   function "+" (S : Unbounded_String) return String
     renames Unbounded_Strings.To_String;

   function "+" (S : String) return Unbounded_String
     renames Unbounded_Strings.To_Unbounded_String;

   function Img (X : Natural) return String is
     (declare Str : constant String := X'Image;
      begin Str (Str'First + 1 .. Str'Last));
   --  Returns X'Image without the leading space

   function Hash (S : Unbounded_String) return Ada.Containers.Hash_Type renames
     Ada.Strings.Unbounded.Hash;

end Stable_Sloc_Strings;
