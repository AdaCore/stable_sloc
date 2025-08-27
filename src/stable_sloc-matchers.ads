--
--  Copyright (C) 2024, AdaCore
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
--

--  Interface definition for the Stable_Sloc backends

with Ada.Containers.Vectors;
with Ada.Unchecked_Deallocation;

with GNATCOLL.VFS; use GNATCOLL.VFS;

with TOML;

package Stable_Sloc.Matchers is

   type Sloc_Matcher_T is interface;

   Parse_Error : exception;
   --  Raised when an error occurs while creating a matcher from a TOML spec

   type Sloc_Match (Success : Boolean := False) is record
      case Success is
         when True =>
            Span : Sloc_Span;

         when False =>
            Reason : Unbounded_String;
      end case;
   end record;
   --  Match result to be produced by the matchers. Success should be set to
   --  True in case of a successful match. Success should be set to False in
   --  case a matcher would have produced a match, but some context element
   --  renders this match invalid. Otherwise if there is no match at all, do
   --  not produce a Sloc_Match.

   package Sloc_Match_Vectors is new
     Ada.Containers.Vectors
       (Index_Type   => Positive,
        Element_Type => Sloc_Match);
   subtype Sloc_Match_Vec is Sloc_Match_Vectors.Vector;

   function Match
     (Self : Sloc_Matcher_T; File : Virtual_File) return Sloc_Match_Vec
   is abstract;
   --  Try to match Self on the contents of File. Return a match array for each
   --  instance that matched.

   function Dump_Spec (Self : Sloc_Matcher_T) return TOML.TOML_Value
   is abstract;
   --  Return the TOML that can be used to re-create Self.

   function Image (Self : Sloc_Matcher_T) return Unbounded_String is abstract;
   --  Return a synthetic image f the matcher. For debug purposes.

   type Sloc_Matcher_Factory is
     access function (Spec : TOML.TOML_Value) return Sloc_Matcher_T'Class;
   --  Callback to create a matcher from a TOML matcher description

   procedure Register_Matcher
     (Matcher_Kind : String; Matcher_Factory : Sloc_Matcher_Factory);
   --  Register the Sloc_Matcher to be used for entries with the specified
   --  Matcher_Kind.

   type Source_Sloc_Matcher_Factory is
     access function
       (File : Virtual_File; Span : Sloc_Span) return Sloc_Matcher_T'Class;
   --  Callback to create a matcher that will match on File for the given Span

   procedure Register_Source_Matcher
     (Matcher_Kind : String; Matcher_Factory : Source_Sloc_Matcher_Factory);
   --  Register the factory to be used to instantiate a matcher from a source +
   --  span description, for the specified Matcher_Kind.

   Unknown_Matcher_Error : exception;

   function Instantiate_Matcher
     (Entry_Spec : TOML.TOML_Value; Kind : String) return Sloc_Matcher_T'Class
   with
     Pre => not Entry_Spec.Is_Null and then Entry_Spec.Kind in TOML.TOML_Table;
   --  Create a matcher of the appropriate kind as defined in Entry_Spec.
   --  If an error occurs during loading of the Entry_Spec, a Parse_Error is
   --  raised.
   --
   --  If the is no matcher for the specified kind in Entry_Spec, raise
   --  Unknown_Matcher_Error.

   function Instantiate_Matcher
     (File : Virtual_File; Span : Sloc_Span; Kind : String)
      return Sloc_Matcher_T'Class;

   procedure Free_Matcher is new
     Ada.Unchecked_Deallocation (Sloc_Matcher_T'Class, Sloc_Matcher_Acc);

end Stable_Sloc.Matchers;
