--
--  Copyright (C) 2024, AdaCore
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
--

--  Simple backend representing an absolute source location range

with GNAT.SHA256;

package Stable_Sloc.Matchers.Absolute is

   type Absolute_Matcher is new Sloc_Matcher_T with private;
   --  Matcher using a regular expression to match a stable sloc.

   overriding function Match
     (Self : Absolute_Matcher;
      File : Virtual_File) return Sloc_Match_Vec;

   overriding function Dump_Spec
     (Self : Absolute_Matcher) return TOML.TOML_Value;
   --  Return the text that can be used to re-create Self.

   overriding function Image (Self : Absolute_Matcher) return Unbounded_String;
   --  Return a synthetic image f the matcher. For debug purposes.

   function Create
     (Spec : TOML.TOML_Value) return Sloc_Matcher_T'Class;
   --  Create a matcher from the given Spec. Raise a Parse_Error in case
   --  parsing the spec was unsuccessful.

   function Create
     (File : Virtual_File; Span : Sloc_Span) return Sloc_Matcher_T'Class;
   --  Create a matcher that will match on File for the given Span.

private

   type Absolute_Matcher is new Sloc_Matcher_T with
   record
      Span   : Sloc_Span;

      SHA256 : GNAT.SHA256.Message_Digest := [others => ASCII.NUL];
      --  Optional SHA256 digest of the file to be matched. The default value
      --  is interpreted as no check required.
   end record;

end Stable_Sloc.Matchers.Absolute;
