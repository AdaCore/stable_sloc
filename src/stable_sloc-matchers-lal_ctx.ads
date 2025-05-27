--
--  Copyright (C) 2024, AdaCore
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
--

--  Stable_Sloc backend leveraging a simple LAL context to identify code
--  regions.

with Libadalang.Analysis;

package Stable_Sloc.Matchers.LAL_Ctx is

   package LAL renames Libadalang.Analysis;

   type LAL_Ctx_Matcher is new Sloc_Matcher_T with private;
   --  Matcher using a regular expression to match a stable sloc.

   overriding function Match
     (Self : LAL_Ctx_Matcher;
      File : Virtual_File) return Sloc_Match_Vec;

   overriding function Dump_Spec
     (Self : LAL_Ctx_Matcher) return TOML.TOML_Value;
   --  Return the text that can be used to re-create Self.

   overriding function Image (Self : LAL_Ctx_Matcher) return Unbounded_String;
   --  Return a synthetic image f the matcher. For debug purposes.

   function Create
     (Spec : TOML.TOML_Value) return Sloc_Matcher_T'Class;
   --  Create a matcher from the given Spec. Raise a Parse_Error in case
   --  parsing the spec was unsuccessful.

   function Create
     (File : Virtual_File; Span : Sloc_Span) return Sloc_Matcher_T'Class;
   --  Create a matcher that will match on File for the given Span.

private

   Ctx : LAL.Analysis_Context;
   --  Common context for all matchers. This means that running matchers in
   --  parallel is currently not possible.

   GET_FROM_FILE_LIMIT : constant := 50;
   --  Limit of times we'll request a unit from the LAL context before
   --  resetting it, to contain memory usage growth.

   Get_From_File_Count : Natural := GET_FROM_FILE_LIMIT + 1;
   --  Number of times the context has been queried for a file. Initialize over
   --  the limit to ensure a context gets created the first time.

   type LAL_Ctx_Matcher is new Sloc_Matcher_T with record
      Sem_Parent_Names : US_Vector;
      --  Simple names of the semantic parents, up to the compilation unit name

      Content_Hash     : Ada.Containers.Hash_Type;
      --  Hash of the text of the node being used as context.

      Relative_Span    : Relative_Sloc_Span;
      --  Span relative to the starting source location of the context node.
      --  The lines refer to the number of lines from the node's starting line;
      --  The columns are the absolute column of the span, minus the column
      --  number of the starting location of the node
      --  (relative to indentation).
   end record;

end Stable_Sloc.Matchers.LAL_Ctx;
