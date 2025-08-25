--
--  Copyright (C) 2025, AdaCore
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
--

--  Stable_Sloc backend leveraging a simple libclang context to identify C/C++
--  code regions

package Stable_Sloc.Matchers.Clang_Ctx is

   type Clang_Ctx_Matcher is new Sloc_Matcher_T with private;
   --  Matcher using a regular expression to match a stable sloc.

   Clang_Support_Enabled : constant Boolean := True;
   --  Used to indicate to the rest of Stable_Sloc whether Clang constructs
   --  should be used. In particular, this is used to not register the clang
   --  based matcher in case clang support is disabled.

   overriding
   function Match
     (Self : Clang_Ctx_Matcher; File : Virtual_File) return Sloc_Match_Vec;

   overriding
   function Dump_Spec (Self : Clang_Ctx_Matcher) return TOML.TOML_Value;
   --  Return the text that can be used to re-create Self.

   overriding
   function Image (Self : Clang_Ctx_Matcher) return Unbounded_String;
   --  Return a synthetic image f the matcher. For debug purposes.

   function Create (Spec : TOML.TOML_Value) return Sloc_Matcher_T'Class;
   --  Create a matcher from the given Spec. Raise a Parse_Error in case
   --  parsing the spec was unsuccessful.

   function Create
     (File : Virtual_File; Span : Sloc_Span) return Sloc_Matcher_T'Class;
   --  Create a matcher that will match on File for the given Span.

private

   type Clang_Ctx_Matcher is new Sloc_Matcher_T with record
      Sem_Parent_Names : US_Vector;
      --  Simple names of the semantic parents, up to the compilation unit name

      Content_Hash : Ada.Containers.Hash_Type;
      --  Hash of the text of the node being used as context.

      Relative_Span : Relative_Sloc_Span;
      --  Span relative to the starting source location of the context node.
      --  The lines refer to the number of lines from the node's starting line;
      --  The columns are the absolute column of the span, minus the column
      --  number of the starting location of the node
      --  (relative to indentation).
   end record;

end Stable_Sloc.Matchers.Clang_Ctx;
