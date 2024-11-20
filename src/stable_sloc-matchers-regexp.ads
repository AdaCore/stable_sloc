--
--  Copyright (C) 2024, AdaCore
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
--

--  Stable_Sloc backend leveraging regular expression to define a region

with GNAT.Regpat;

with GNATCOLL.Refcount; use GNATCOLL.Refcount;

package Stable_Sloc.Matchers.Regexp is

   type Regexp_Matcher is new Sloc_Matcher_T with private;
   --  Matcher using a regular expression to match a stable sloc.

   overriding function Match
     (Self : Regexp_Matcher;
      File : Virtual_File) return Sloc_Match_Vec;
   --  Try to match Self on the contents of File. Return a match array for each
   --  instance that matched.

   overriding function Dump_Spec
     (Self : Regexp_Matcher) return TOML.TOML_Value;
   --  Return the text that can be used to re-create Self.

   overriding function Image (Self : Regexp_Matcher) return Unbounded_String;
   --  Return a synthetic image f the matcher. For debug purposes.

   function Create
     (Spec : TOML.TOML_Value) return Sloc_Matcher_T'Class;
   --  Create a matcher from the given Spec. Raise a Parse_Error in case
   --  parsing the spec was unsuccessful.

private

   package SP is new Shared_Pointers (GNAT.Regpat.Pattern_Matcher);

   type Regexp_Matcher is new Sloc_Matcher_T with record
      Orig_Spec : Unbounded_String;
      Regexp    : SP.Ref;
      Flags     : GNAT.Regpat.Regexp_Flags;
   end record;

end Stable_Sloc.Matchers.Regexp;