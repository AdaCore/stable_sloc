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

private

   type Absolute_Matcher is new Sloc_Matcher_T with
   record
      Span : Sloc_Span;
   end record;

end Stable_Sloc.Matchers.Absolute;