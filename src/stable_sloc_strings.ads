--
--  Copyright (C) 2024, AdaCore
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
--

--  Various string utilities

with Ada.Containers.Vectors;
with Ada.Text_IO;
with Ada.Strings.Unbounded;

limited with Stable_Sloc;

package Stable_Sloc_Strings is

   package Unbounded_Strings renames Ada.Strings.Unbounded;
   use Unbounded_Strings;
   subtype US is Unbounded_String;

   package US_Vectors is new
     Ada.Containers.Vectors (Index_Type => Natural, Element_Type => US);
   subtype US_Vector is US_Vectors.Vector;

   function "+" (S : Unbounded_String) return String
   renames Unbounded_Strings.To_String;

   function "+" (S : String) return Unbounded_String
   renames Unbounded_Strings.To_Unbounded_String;

   function Is_Prefix (Prefix, Content : Unbounded_String) return Boolean;
   --  Return Whether Prefix is indeed a prefix of Content.

   function Img (X : Integer) return String;
   --  Returns X'Image without the leading space (if positive)

   function To_Symbol (Vec : US_Vector; Sep : String) return Unbounded_String;
   --  Collate the various strings in Vec with Sep between each element

   function To_Ada (Vec : US_Vector) return Unbounded_String
   is (To_Symbol (Vec, "."));
   --  Collate the various strings in Vec with a '.' between each element

   function To_CPP (Vec : US_Vector) return Unbounded_String
   is (To_Symbol (Vec, "::"));
   --  Collate the various string with a "::" between each element

   package Hash_IO is new Ada.Text_IO.Modular_IO (Ada.Containers.Hash_Type);

   function Split_Sloc_Prefix
     (S : String; Loc : out Stable_Sloc.Sloc) return String;
   --  Extract the source location encoded as LINE:COLUMN:<rest_of_string> in
   --  S, or No_Location if no such location was found. The return value if the
   --  remainder of the string, it will be the full string if no source
   --  location was extracted.

end Stable_Sloc_Strings;
