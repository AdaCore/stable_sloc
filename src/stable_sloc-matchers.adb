with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Strings.Fixed;
with Ada.Strings.Hash;

with Stable_Sloc.Matchers.Absolute;
with Stable_Sloc.Matchers.LAL_Ctx;
with Stable_Sloc.Matchers.Regexp;
with Stable_Sloc.TOML_Utils;        use Stable_Sloc.TOML_Utils;

package body Stable_Sloc.Matchers is

   package Backend_Maps is new Ada.Containers.Indefinite_Hashed_Maps
     (Key_Type        => String,
      Element_Type    => Sloc_Matcher_Factory,
      Hash            => Ada.Strings.Hash,
      Equivalent_Keys => "=");

   package Source_Backend_Maps is new Ada.Containers.Indefinite_Hashed_Maps
     (Key_Type       => String,
     Element_Type    =>  Source_Sloc_Matcher_Factory,
     Hash            => Ada.Strings.Hash,
     Equivalent_Keys => "=");

   Backend_Map        : Backend_Maps.Map;
   Source_Backend_Map : Source_Backend_Maps.Map;

   ----------------------
   -- Register_Matcher --
   ----------------------

   procedure Register_Matcher
     (Matcher_Kind : String; Matcher_Factory : Sloc_Matcher_Factory)
   is
      use Backend_Maps;
      Cur : Cursor := Backend_Map.Find (Matcher_Kind);
   begin
      if Cur /= No_Element then
         raise Program_Error with
           "Matcher already registered with key " & Matcher_Kind;
      end if;
      Backend_Map.Insert (Matcher_Kind, Matcher_Factory);
   end Register_Matcher;

   -----------------------------
   -- Register_Source_Matcher --
   -----------------------------

   procedure Register_Source_Matcher
     (Matcher_Kind : String; Matcher_Factory : Source_Sloc_Matcher_Factory)
   is
      use Source_Backend_Maps;
      Cur : Cursor := Source_Backend_Map.Find (Matcher_Kind);
   begin
      if Cur /= No_Element then
         raise Program_Error with
           "Matcher already registered with key " & Matcher_Kind;
      end if;
      Source_Backend_Map.Insert (Matcher_Kind, Matcher_Factory);
   end Register_Source_Matcher;

   -------------------------
   -- Instantiate_Matcher --
   -------------------------

   function Instantiate_Matcher
     (Entry_Spec : TOML.TOML_Value;
      Kind       : String) return Sloc_Matcher_T'Class
   is
      use Backend_Maps;
      Cur  : constant Cursor := Backend_Map.Find (Kind);
   begin
      if Cur = No_Element then
         raise Unknown_Matcher_Error with "No such kind of matcher: " & Kind;
      end if;
      return Element (Cur) (Entry_Spec);
   end Instantiate_Matcher;

   function Instantiate_Matcher
     (File : Virtual_File;
      Span : Sloc_Span;
      Kind : String) return Sloc_Matcher_T'Class
   is
      use Source_Backend_Maps;
      Cur  : constant Cursor := Source_Backend_Map.Find (Kind);
   begin
      if Cur = No_Element then
         raise Unknown_Matcher_Error with "No such kind of matcher: " & Kind;
      end if;
      return Element (Cur) (File, Span);
   end Instantiate_Matcher;

begin
   Backend_Map.Clear;
   Source_Backend_Map.Clear;
   Register_Matcher ("absolute", Stable_Sloc.Matchers.Absolute.Create'Access);
   Register_Matcher ("regexp", Stable_Sloc.Matchers.Regexp.Create'Access);
   Register_Matcher
     ("lal_context", Stable_Sloc.Matchers.LAL_Ctx.Create'Access);
   Register_Source_Matcher
     ("absolute", Stable_Sloc.Matchers.Absolute.Create'Access);
   Register_Source_Matcher
     ("lal_context", Stable_Sloc.Matchers.LAL_Ctx.Create'Access);
end Stable_Sloc.Matchers;
