--
--  Copyright (C) 2024, AdaCore
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
--

with Stable_Sloc.TOML_Utils;

with Libadalang.Common;     use Libadalang.Common;
with Langkit_Support.Text;
with Langkit_Support.Slocs; use Langkit_Support.Slocs;

package body Stable_Sloc.Matchers.LAL_Ctx is

   function Get_From_File (File : Virtual_File) return LAL.Analysis_Unit;
   --  Wrapper around LAL.Get_From_File that takes care of initializing the
   --  context if need be, and doing the context-reset book-keeping.

   function Get_Basic_Decl_Parent_Names (N : LAL.Basic_Decl) return US_Vector;
   --  Return all the canonical names of the parent basic decls of N in
   --  increasing depth order. N will be the last element of the list.

   function Get_Canonical_Name (N : LAL.Basic_Decl) return Unbounded_String
   is (+(Langkit_Support.Text.Image
           (Langkit_Support.Text.To_Text
              (N.P_Defining_Name.P_Canonical_Text))));

   -----------
   -- Match --
   -----------

   overriding
   function Match
     (Self : LAL_Ctx_Matcher; File : Virtual_File) return Sloc_Match_Vec
   is
      use LAL;
      Unit  : constant Analysis_Unit := Get_From_File (File);
      Diags : Unbounded_String;

      Res         : Sloc_Match :=
        (Success => False, Reason => Null_Unbounded_String);
      Target_Decl : Basic_Decl := No_Basic_Decl;
      Target_Sloc : Sloc;

      function Filter_Nodes (N : Ada_Node'Class) return Visit_Status;
      --  Visit the tree and try to locate a node whose basic decl parent stack
      --  matches the one described in Self, and whose Content hash matches
      --  as well.

      function Filter_Nodes (N : Ada_Node'Class) return Visit_Status is
         use type Ada.Containers.Hash_Type;
         use type Ada.Containers.Count_Type;
         use type US_Vector;

         Names     : US_Vector;
         Node_Name : Unbounded_String;
      begin
         if N.Kind not in Ada_Basic_Decl then
            return Into;
         end if;

         --  If the basic decl is not a named entity, do not consider it

         if N.As_Basic_Decl.P_Defining_Name = No_Defining_Name then
            return Into;
         end if;

         --  First, check that the basic decl has the same name as the one we
         --  are ultimately looking for.

         Node_Name := Get_Canonical_Name (N.As_Basic_Decl);
         if Node_Name /= Self.Sem_Parent_Names.Last_Element then
            return Into;
         end if;

         --  Then check the basic decl chain. If it is longer than the one we
         --  expect no need to dive further into the tree, skip the nested
         --  nodes.

         Names := Get_Basic_Decl_Parent_Names (N.As_Basic_Decl);
         if Names /= Self.Sem_Parent_Names then
            Res.Reason :=
              Unbounded_String'
                (+("Mismatched parent basic decl names:" & ASCII.LF))
              & "expected: "
              & To_Ada (Self.Sem_Parent_Names)
              & (ASCII.LF & "but got: ")
              & To_Ada (Names);
            if Names.Length >= Self.Sem_Parent_Names.Length then
               return Over;
            else
               return Into;
            end if;
         end if;

         --  Finally check wether the contents have moved, no need to explore
         --  the rest of the tree if it doesn't.

         if Langkit_Support.Text.Hash (N.Text) /= Self.Content_Hash then
            Res.Reason := +"Contents of " & N.Image & " changed";
            return Over;
         end if;

         Res := (Success => True, others => <>);
         Target_Decl := N.As_Basic_Decl;
         return Stop;
      end Filter_Nodes;

      --  Start of processing for Match
   begin
      if Unit.Has_Diagnostics then
         for Diag of Unit.Diagnostics loop
            Diags := (Unit.Format_GNU_Diagnostic (Diag) & ASCII.LF) & Diags;
         end loop;
      end if;
      if Unit.Root.Is_Null then
         Res.Reason := Diags;
         return [Res];
      end if;
      Unit.Root.Traverse (Filter_Nodes'Access);
      if not Res.Success then
         if Res.Reason = Null_Unbounded_String then
            return [];
         else
            return [Res];
         end if;
      end if;
      Target_Sloc :=
        (Line   => Natural (Target_Decl.Sloc_Range.Start_Line),
         Column => Natural (Target_Decl.Sloc_Range.Start_Column));
      Res.Span := Target_Sloc + Self.Relative_Span;
      return [Res];
   end Match;

   ---------------
   -- Dump_Spec --
   ---------------

   overriding
   function Dump_Spec (Self : LAL_Ctx_Matcher) return TOML.TOML_Value is
      use TOML;
      use Stable_Sloc.TOML_Utils;
      Sem_Parents_Arr : constant TOML_Value := Create_Array;
      Hash_Image      : String (1 .. 12);
   begin
      for Name of Self.Sem_Parent_Names loop
         Sem_Parents_Arr.Append (Create_String (Name));
      end loop;
      Hash_IO.Put (Hash_Image, Self.Content_Hash, 16);

      return Res : constant TOML_Value := Write_Span (Self.Relative_Span) do
         Res.Set ("sem_parents", Sem_Parents_Arr);
         Res.Set ("context_hash", Create_String (Hash_Image));
      end return;
   end Dump_Spec;

   -----------
   -- Image --
   -----------

   overriding
   function Image (Self : LAL_Ctx_Matcher) return Unbounded_String
   is (Unbounded_String'
         ("LAL context based matcher, matching "
          & To_Ada (Self.Sem_Parent_Names)
          & " + "
          & (+Image (Self.Relative_Span))));

   ------------
   -- Create --
   ------------

   function Create (Spec : TOML.TOML_Value) return Sloc_Matcher_T'Class is
      use TOML;
      use Stable_Sloc.TOML_Utils;
      Res        : LAL_Ctx_Matcher;
      Name_Arr   : constant TOML_Value :=
        Get (Spec, "sem_parents", TOML_Array);
      Hash_Image : constant String := Get (Spec, "context_hash");
      Hash_Value : Ada.Containers.Hash_Type;
      Dummy_Last : Positive;
   begin
      for I in 1 .. Name_Arr.Length loop
         declare
            Name : constant TOML_Value := Name_Arr.Item (I);
         begin
            if Name.Kind /= TOML_String then
               raise Parse_Error
                 with
                   Format_Location (Name.Location)
                   & ":Expected a "
                   & TOML_String'Image
                   & " for a sem_parent, but"
                   & " got a "
                   & Name.Kind'Image;
            end if;
            Res.Sem_Parent_Names.Append (Name.As_Unbounded_String);
         end;
      end loop;
      Hash_IO.Get (Hash_Image, Hash_Value, Dummy_Last);
      Res.Content_Hash := Hash_Value;
      Res.Relative_Span := Read_Span (Spec);
      return Res;
   end Create;

   ------------
   -- Create --
   ------------

   function Create
     (File : Virtual_File; Span : Sloc_Span) return Sloc_Matcher_T'Class
   is
      use LAL;
      Unit            : constant Analysis_Unit := Get_From_File (File);
      Start_Sloc_Node : Ada_Node;
      End_Sloc_Node   : Ada_Node;
      Ctx_Basic_Decl  : Basic_Decl;

      Res       : LAL_Ctx_Matcher;
      Base_Line : Natural;
      Base_Col  : Natural;

      Filename : constant String := File.Display_Full_Name;
   begin
      --  Do not check diagnostics. ??? This might need to be revisited.
      if Unit.Root.Is_Null then
         raise Parse_Error with "Could not get LAL tree for " & Filename;
      end if;

      --  Lookup the given locations

      Start_Sloc_Node :=
        Unit.Root.Lookup
          ((Line   => Line_Number (Span.Start_Sloc.Line),
            Column => Column_Number (Span.Start_Sloc.Column)));
      if Start_Sloc_Node.Is_Null then
         raise Parse_Error
           with
             "Did not find a node containing "
             & Image (Span.Start_Sloc)
             & " in "
             & Filename;
      end if;
      End_Sloc_Node :=
        Unit.Root.Lookup
          ((Line   => Line_Number (Span.End_Sloc.Line),
            Column => Column_Number (Span.End_Sloc.Column)));
      if End_Sloc_Node.Is_Null then
         raise Parse_Error
           with
             "Did not find a node containing "
             & Image (Span.End_Sloc)
             & " in "
             & Filename;
      end if;

      --  Find the inner-most basic decl containing each of them

      if Start_Sloc_Node.Kind not in Ada_Basic_Decl then
         Start_Sloc_Node := Start_Sloc_Node.P_Parent_Basic_Decl.As_Ada_Node;
      end if;
      if Start_Sloc_Node.Is_Null or else Start_Sloc_Node.Unit /= Unit then
         raise Parse_Error
           with
             "Did not find enclosing basic decl for "
             & Image (Span.Start_Sloc)
             & " in "
             & Filename;
      end if;

      if End_Sloc_Node.Kind not in Ada_Basic_Decl then
         End_Sloc_Node := End_Sloc_Node.P_Parent_Basic_Decl.As_Ada_Node;
      end if;
      if End_Sloc_Node.Is_Null or else End_Sloc_Node.Unit /= Unit then
         raise Parse_Error
           with
             "Did not find enclosing basic decl for "
             & Image (Span.End_Sloc)
             & " in "
             & Filename;
      end if;

      --  Find common named enclosing basic decl

      Start_Sloc_Node := Start_Sloc_Node.Closest_Common_Parent (End_Sloc_Node);
      if Start_Sloc_Node.Kind not in Ada_Basic_Decl
        or else Start_Sloc_Node.As_Basic_Decl.P_Defining_Name.Is_Null
      then
         Start_Sloc_Node := Start_Sloc_Node.P_Parent_Basic_Decl.As_Ada_Node;
      end if;
      if Start_Sloc_Node.Is_Null or else Start_Sloc_Node.Unit /= Unit then
         raise Parse_Error
           with
             "Did not find enclosing basic decl for "
             & Image (Span)
             & " in "
             & Filename;
      end if;

      --  Construct the matcher

      Ctx_Basic_Decl := Start_Sloc_Node.As_Basic_Decl;
      Base_Line := Natural (Ctx_Basic_Decl.Sloc_Range.Start_Line);
      Base_Col := Natural (Ctx_Basic_Decl.Sloc_Range.Start_Column);

      Res.Relative_Span := Span - Sloc'(Base_Line, Base_Col);

      Res.Content_Hash := Langkit_Support.Text.Hash (Ctx_Basic_Decl.Text);

      --  Compute basic decl name chain
      --  TODO: Investigate is using the canonical fully qualified name is
      --        equivalent.

      Res.Sem_Parent_Names := Get_Basic_Decl_Parent_Names (Ctx_Basic_Decl);

      return Res;
   end Create;

   -------------------
   -- Get_From_File --
   -------------------

   function Get_From_File (File : Virtual_File) return LAL.Analysis_Unit is
   begin
      if Get_From_File_Count > GET_FROM_FILE_LIMIT then
         Ctx := LAL.Create_Context;
         Get_From_File_Count := 0;
      end if;
      return Ctx.Get_From_File (+File.Full_Name);
   end Get_From_File;

   ---------------------------------
   -- Get_Basic_Decl_Parent_Names --
   ---------------------------------

   function Get_Basic_Decl_Parent_Names (N : LAL.Basic_Decl) return US_Vector
   is
      use LAL;
      Cur : Basic_Decl := N;
      Top : constant Basic_Decl := N.P_Top_Level_Decl (N.Unit);
      Res : US_Vector;
   begin
      loop
         --  Skip basic decls that do not have a defining name

         if not Cur.P_Defining_Name.Is_Null then
            Res.Append (Unbounded_String'(Get_Canonical_Name (Cur)));
         end if;
         exit when Cur = Top;
         Cur := Cur.P_Parent_Basic_Decl;
      end loop;
      Res.Reverse_Elements;
      return Res;
   end Get_Basic_Decl_Parent_Names;

end Stable_Sloc.Matchers.LAL_Ctx;
