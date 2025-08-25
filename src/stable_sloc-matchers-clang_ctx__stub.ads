--
--  Copyright (C) 2025, AdaCore
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
--

--  Dummy stub for Stable_Sloc.Matchers.Clang_Ctx which allows compilation of
--  Stable_Sloc even without libclang in the loop.

pragma Ada_2022;

package Stable_Sloc.Matchers.Clang_Ctx is

   type Clang_Ctx_Matcher is new Sloc_Matcher_T with private;
   --  Matcher using a regular expression to match a stable sloc.

   Clang_Support_Enabled : constant Boolean := False;
   --  Used to indicate to the rest of Stable_Sloc whether Clang constructs
   --  should be used. In particular, this is used to not register the clang
   --  based matcher in case clang support is disabled.

   overriding
   function Match
     (Self : Clang_Ctx_Matcher; File : Virtual_File with Unreferenced)
      return Sloc_Match_Vec
   is (raise Program_Error with "clang support disabled");

   overriding
   function Dump_Spec (Self : Clang_Ctx_Matcher) return TOML.TOML_Value
   is (raise Program_Error with "clang support disabled");

   overriding
   function Image (Self : Clang_Ctx_Matcher) return Unbounded_String
   is (raise Program_Error with "clang support disabled");

   function Create
     (Spec : TOML.TOML_Value with Unreferenced) return Sloc_Matcher_T'Class
   is (raise Program_Error with "clang support disabled");

   function Create
     (File : Virtual_File with Unreferenced;
      Span : Sloc_Span with Unreferenced) return Sloc_Matcher_T'Class
   is (raise Program_Error with "clang support disabled");

private

   type Clang_Ctx_Matcher is new Sloc_Matcher_T with null record;

end Stable_Sloc.Matchers.Clang_Ctx;
