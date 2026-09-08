--
--  Copyright (C) 2025, AdaCore
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
--

pragma Ada_2022;

with Clang.CX_Diagnostic;
with Clang.CX_File;
with Clang.CX_String;
with Clang.CX_Source_Location;
with Clang.Index;

with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;
with Ada.Strings.Unbounded.Hash;
with Ada.Unchecked_Conversion;

with Interfaces.C; use Interfaces.C;
with Interfaces.C.Strings;
with stddef_h;
with System;

with GNATCOLL.Traces;

with Stable_Sloc.TOML_Utils;

package body Stable_Sloc.Matchers.Clang_Ctx is

   Me : constant GNATCOLL.Traces.Logger :=
     GNATCOLL.Traces.Create (Unit_Name => "SS.Matchers.Clang_Ctx");

   function Ptr_To_Addr is new
     Ada.Unchecked_Conversion (Interfaces.C.Strings.chars_ptr, System.Address);

   ---------------------------------
   --  CLANG HELPERS DECLARATIONS --
   ---------------------------------

   function Get_CX_Location
     (TU : Clang.Index.Translation_Unit_T; Loc : Sloc)
      return Clang.CX_Source_Location.Source_Location_T;
   --  Create a Source_Location_T for the main source of TU at location Loc

   procedure Get_File_And_Sloc
     (S    : Clang.CX_Source_Location.Source_Location_T;
      File : out Virtual_File;
      Loc  : out Sloc);
   --  Convert a Clang source location to a native Stable_Sloc one and a
   --  Virtual_File.

   function "=" (L, R : Clang.Index.Cursor_T) return Boolean
   is (Clang.Index.Equal_Cursors (L, R) /= 0);

   package Cursor_Vectors is new
     Ada.Containers.Vectors
       (Index_Type   => Positive,
        Element_Type => Clang.Index.Cursor_T);
   subtype Cursor_Vec is Cursor_Vectors.Vector;

   function Parents (Cur : Clang.Index.Cursor_T) return Cursor_Vec;
   --  Return the vector of semantic parents for Cur, nearer first, until we
   --  reach the translation unit. This list does include Cur, and is empty
   --  if Cur is a null cursor.

   function Closest_Common_Parent
     (Cur1, Cur2 : Clang.Index.Cursor_T) return Clang.Index.Cursor_T;
   --  Return the inner most cursor that is both a parent of Cur1 and Cur2.
   --  This may be Cur1 or Cur2 themselves. If no such cursor can be found,
   --  a null cursor is returned.

   function Get_Cursor_Text
     (Cur : Clang.Index.Cursor_T) return Unbounded_String;
   --  Return a copy of the text of Cur

   function Get_File_Contents
     (TU   : Clang.Index.Translation_Unit_T;
      File : Clang.CX_File.File_T;
      Size : access stddef_h.size_t) return Interfaces.C.Strings.chars_ptr
   with
     Import        => True,
     Convention    => C,
     External_Name => "clang_getFileContents";
   --  This is not exposed in Clang.Index which instead only exposes a wrapper
   --  returning a plain Ada string. As this contains the contents of a whole
   --  file, it implies a huge copy on the secondary stack, when we might only
   --  want to access part of the buffer. We can do this by actually using the
   --  chars_ptr this function returns instead.

   function Get_Cursor_Range (Cur : Clang.Index.Cursor_T) return Sloc_Span;
   --  Return the span of this cursor. If for some reason we can't get either
   --  the start or end location, or if the source files for the start and end
   --  location do not match, No_Sloc_Span is returned.

   function Cursor_Image (Cur : Clang.Index.Cursor_T) return String;
   --  Return a synthetic image of Cur including its kind and source location
   --  range.

   function Qualified_Name (Cur : Clang.Index.Cursor_T) return US_Vector;
   --  Given a cursor that denotes a declaration, return its qualified name as
   --  a vector

   ----------------------------
   -- MATCHER IMPLEMENTATION --
   ----------------------------

   -----------
   -- Match --
   -----------

   overriding
   function Match
     (Self : Clang_Ctx_Matcher; File : Virtual_File) return Sloc_Match_Vec
   is
      use Clang.Index;
      CIndex : constant Index_T :=
        Create_Index
          (Exclude_Declarations_From_PCH => 1, Display_Diagnostics => 0);
      TU     : constant Translation_Unit_T :=
        Parse_Translation_Unit
          (C_Idx                 => CIndex,
           Source_Filename       => File.Display_Full_Name,
           Command_Line_Args     => System.Null_Address,
           Num_Command_Line_Args => 0,
           Num_Unsaved_Files     => 0,
           Unsaved_Files         => null,
           Options               => 0);
      --  Translation unit for File.
      --
      --  TODO??? No specific options or command line switches are passed to
      --  clang, this might prove problematic if some macro definitions are
      --  required to properly parse some entities, or if the language cannot
      --  be properly inferred from the filename.

      Res : Sloc_Match := (Success => False, others => <>);

      Decl_Same_Name : Boolean := False;
      --  Whether we have already found a declaration with the same name

      Decl_Same_FQN : Boolean := False;
      --  Whether we have already found a declaration with the same qualified
      --  name.

      function Visit_Callback
        (Cur : Cursor_T; Parent : Cursor_T; Dummy_Data : Client_Data_T)
         return Child_Visit_Result_T
      with Convention => C;
      --  Check if cur is a declaration for which the qualified name matches
      --  that in Self, and if so, if the hash of its text (hash of all the
      --  tokens in its extent) matches that of Self. If a matching cursor is
      --  found, populate Res with a successful match result and the
      --  corresponding sloc span, otherwise store a diagnostic message in Res
      --  if we found a closest matching candidate according to the state of
      --  the Decl_* variables above.

      --------------------
      -- Visit_Callback --
      --------------------

      function Visit_Callback
        (Cur : Cursor_T; Parent : Cursor_T; Dummy_Data : Client_Data_T)
         return Child_Visit_Result_T
      is
         pragma Unreferenced (Parent);
      begin
         if Cursor_Is_Null (Cur) then
            return Child_Visit_Continue;
         end if;

         --  Recurse into non-declarations

         if not Is_Declaration (Get_Cursor_Kind (Cur)) then
            return Child_Visit_Recurse;
         end if;

         --  Recurse into declarations that do not have the right name (it
         --  could be nested, e.g. we are looking for a method in a class).

         if Get_Cursor_Spelling (Cur) /= (+Self.Sem_Parent_Names.Last_Element)
         then
            return Child_Visit_Recurse;
         end if;

         --  Recurse into declarations that have the right name but not the
         --  right qualified names. Log a potential error message if it is the
         --  first time we encounter this error.

         declare
            Decl_FQN : constant US_Vector := Qualified_Name (Cur);
         begin
            if not Decl_FQN."=" (Self.Sem_Parent_Names) then
               if not Decl_Same_Name then
                  Res.Reason :=
                    "Could not find declaration with the a matching"
                    & " qualified name. Expected "
                    & To_CPP (Self.Sem_Parent_Names)
                    & " but only found "
                    & To_CPP (Decl_FQN);
                  Decl_Same_Name := True;
               end if;
               return Child_Visit_Recurse;
            end if;
         end;

         --  If the FQN matches, and so does the content hash, we have found
         --  our declaration. Otherwise log an error message and keep
         --  searching.

         declare
            use type Ada.Containers.Hash_Type;
            Cur_Hash  : constant Ada.Containers.Hash_Type :=
              Ada.Strings.Unbounded.Hash (Get_Cursor_Text (Cur));
            Cur_Range : constant Sloc_Span := Get_Cursor_Range (Cur);
         begin
            if Cur_Hash = Self.Content_Hash then
               Res :=
                 (Success => True,
                  Span    => Cur_Range.Start_Sloc + Self.Relative_Span);
               return Child_Visit_Break;
            elsif not Decl_Same_FQN then
               Res.Reason :=
                 "Content of declaration "
                 & To_CPP (Self.Sem_Parent_Names)
                 & " has changed";
               Decl_Same_FQN := True;
            end if;
            return Child_Visit_Continue;
         end;
      end Visit_Callback;

      Dummy_Client_Data : Client_Data_T := Client_Data_T (System.Null_Address);
      Visit_Result      : unsigned;

   begin
      if not Cursor_Is_Null (Get_Translation_Unit_Cursor (TU)) then
         Visit_Result :=
           Visit_Children
             (Parent      => Get_Translation_Unit_Cursor (TU),
              Visitor     => Visit_Callback'Unrestricted_Access,
              Client_Data => Dummy_Client_Data);
      elsif Get_Num_Diagnostics (TU) /= 0 then
         declare
            use Clang.CX_Diagnostic;
            Num_Diags    : constant unsigned := Get_Num_Diagnostics (TU);
            Current_Diag : Diagnostic_T;
            Diags        : Unbounded_String;
         begin
            for Diag_Idx in 0 .. Num_Diags - 1 loop
               Current_Diag := Clang.Index.Get_Diagnostic (TU, Diag_Idx);
               if Get_Diagnostic_Severity (Current_Diag)
                  in Diagnostic_Fatal | Diagnostic_Error
               then
                  Diags :=
                    Diags
                    & (ASCII.LF
                       & Format_Diagnostic
                           (Current_Diag, Diagnostic_Display_Source_Location));
               end if;
            end loop;
            Res.Reason := Diags;
         end;
      elsif not File.Is_Regular_File then
         --  Files not existing on disk do not get reported in the TU
         --  diagnostics, so check manually to have somewhat less confusing
         --  diagnostics.
         Res.Reason := +("Could not read " & File.Display_Full_Name);
      else
         Res.Reason := +"Could not get a parse tree";
      end if;

      --  If we got to the end of the traversal uninterrupted, and we haven't
      --  got a diagnostic set, this means no declaration with the correct name
      --  was found.

      if Visit_Result = 0
        and then not Res.Success
        and then Length (Res.Reason) = 0
      then
         Res.Reason :=
           "Could not find declaration named "
           & Self.Sem_Parent_Names.Last_Element;
      end if;
      Dispose_Translation_Unit (TU);
      Dispose_Index (CIndex);
      return Sloc_Match_Vectors.To_Vector (Res, 1);
   end Match;

   ---------------
   -- Dump_Spec --
   ---------------

   overriding
   function Dump_Spec (Self : Clang_Ctx_Matcher) return TOML.TOML_Value is
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
   function Image (Self : Clang_Ctx_Matcher) return Unbounded_String
   is (Unbounded_String'
         ("Clang context based matcher, matching "
          & To_CPP (Self.Sem_Parent_Names)
          & " + "
          & (+Image (Self.Relative_Span))));

   ------------
   -- Create --
   ------------

   function Create (Spec : TOML.TOML_Value) return Sloc_Matcher_T'Class is
      use TOML;
      use Stable_Sloc.TOML_Utils;
      Res        : Clang_Ctx_Matcher;
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
      use Clang.Index;
      use Clang.CX_Source_Location;
      CIndex : constant Index_T :=
        Create_Index
          (Exclude_Declarations_From_PCH => 1, Display_Diagnostics => 0);
      TU     : constant Translation_Unit_T :=
        Parse_Translation_Unit
          (C_Idx                 => CIndex,
           Source_Filename       => File.Display_Full_Name,
           Command_Line_Args     => System.Null_Address,
           Num_Command_Line_Args => 0,
           Num_Unsaved_Files     => 0,
           Unsaved_Files         => null,
           Options               =>
             Translation_Unit_Keep_Going
             or Translation_Unit_Single_File_Parse);
      --  Translation unit for File.
      --
      --  TODO??? No command line switches are passed to
      --  clang, this might prove problematic if some macro definitions are
      --  required to properly parse some entities, or if the language cannot
      --  be properly inferred from the filename.

      Start_Loc, End_Loc : Source_Location_T;

      Start_Sloc_Cur : Cursor_T;
      End_Sloc_Cur   : Cursor_T;
      Common_Decl    : Cursor_T;

      Decl_Span : Sloc_Span;
      --  source location range for the common enclosing declaration

      Res : Clang_Ctx_Matcher;

      Filename : constant String := File.Display_Full_Name;

   begin
      --  Diagnostics not emitted here, might need to be revisited if we find
      --  issues with this.

      if TU = null then
         raise Parse_Error with "could not load Clang AST for " & Filename;
      end if;

      --  Lookup the start and end cursors

      Start_Loc := Get_CX_Location (TU, Span.Start_Sloc);
      if Equal_Locations (Start_Loc, Get_Null_Location) /= 0 then
         raise Parse_Error
           with
             "Could not look up location "
             & Image (Span.Start_Sloc)
             & " in "
             & Filename;
      end if;
      Start_Sloc_Cur := Get_Cursor (TU, Start_Loc);
      if Cursor_Is_Null (Start_Sloc_Cur) then
         raise Parse_Error
           with
             "Could not look up location "
             & Image (Span.Start_Sloc)
             & " in "
             & Filename;
      end if;

      End_Loc := Get_CX_Location (TU, Span.End_Sloc);

      if Equal_Locations (End_Loc, Get_Null_Location) /= 0 then
         raise Parse_Error
           with
             "Could not look up location "
             & Image (Span.End_Sloc)
             & " in "
             & Filename;
      end if;
      End_Sloc_Cur := Get_Cursor (TU, End_Loc);
      if Cursor_Is_Null (End_Sloc_Cur) then
         raise Parse_Error
           with
             "Could not look up location "
             & Image (Span.End_Sloc)
             & " in "
             & Filename;
      end if;

      --  Find the inner most declaration for the source location of the range

      Me.Trace
        ("Initial Start location cur : " & Cursor_Image (Start_Sloc_Cur));
      while not Cursor_Is_Null (Start_Sloc_Cur)
        and then not Is_Declaration (Get_Cursor_Kind (Start_Sloc_Cur))
      loop
         Start_Sloc_Cur := Get_Cursor_Semantic_Parent (Start_Sloc_Cur);
      end loop;

      Me.Trace ("Final start cur: " & Cursor_Image (Start_Sloc_Cur));
      if Cursor_Is_Null (Start_Sloc_Cur) then
         raise Parse_Error
           with
             "Did not find enclosing declaration for "
             & Image (Span.Start_Sloc)
             & " in "
             & Filename;
      end if;

      Me.Trace ("Initial End location cur :" & Cursor_Image (End_Sloc_Cur));
      while not Cursor_Is_Null (End_Sloc_Cur)
        and then not Is_Declaration (Get_Cursor_Kind (End_Sloc_Cur))
      loop
         End_Sloc_Cur := Get_Cursor_Semantic_Parent (End_Sloc_Cur);
      end loop;

      Me.Trace ("Final end cur: " & Cursor_Image (End_Sloc_Cur));
      if Cursor_Is_Null (End_Sloc_Cur) then
         raise Parse_Error
           with
             "Did not find enclosing declaration for "
             & Image (Span.End_Sloc)
             & " in "
             & Filename;
      end if;

      --  Locate the common enclosing declaration

      Common_Decl := Closest_Common_Parent (Start_Sloc_Cur, End_Sloc_Cur);
      Me.Trace ("Initial Common parent : " & Cursor_Image (Common_Decl));
      while not Cursor_Is_Null (Common_Decl)
        and then not Is_Declaration (Get_Cursor_Kind (Common_Decl))
      loop
         Common_Decl := Get_Cursor_Semantic_Parent (Common_Decl);
      end loop;

      Me.Trace ("Refined common parent: " & Cursor_Image (Common_Decl));
      if Cursor_Is_Null (Common_Decl) then
         raise Parse_Error
           with
             "Could not locate common enclosing declaration for "
             & Image (Span)
             & " in "
             & Filename;
      end if;

      --  Build the matcher

      Decl_Span := Get_Cursor_Range (Common_Decl);
      if Decl_Span = No_Sloc_Span or else Decl_Span.Start_Sloc = No_Sloc then
         raise Parse_Error
           with
             "Could not get source location for common enclosing declaration"
             & " in "
             & Filename;
      end if;

      Res.Relative_Span := Span - Decl_Span.Start_Sloc;
      declare
         Cur_Text : constant Unbounded_String := Get_Cursor_Text (Common_Decl);
      begin
         Me.Trace ("Common decl text: " & ASCII.LF & (+Cur_Text));
         Res.Content_Hash := Ada.Strings.Unbounded.Hash (Cur_Text);
      end;

      Res.Sem_Parent_Names := Qualified_Name (Common_Decl);

      Dispose_Translation_Unit (TU);
      Dispose_Index (CIndex);
      return Res;
   end Create;

   ----------------------------------
   -- CLANG HELPERS IMPLEMENTATION --
   ----------------------------------

   ---------------------
   -- Get_CX_Location --
   ---------------------

   function Get_CX_Location
     (TU : Clang.Index.Translation_Unit_T; Loc : Sloc)
      return Clang.CX_Source_Location.Source_Location_T
   is
      C_File : constant Clang.CX_File.File_T :=
        Clang.Index.Get_File
          (TU, Clang.Index.Get_Translation_Unit_Spelling (TU));
   begin
      return
        Clang.Index.Get_Location
          (TU, C_File, unsigned (Loc.Line), unsigned (Loc.Column));
   end Get_CX_Location;

   -----------------------
   -- Get_File_And_Sloc --
   -----------------------

   procedure Get_File_And_Sloc
     (S    : Clang.CX_Source_Location.Source_Location_T;
      File : out Virtual_File;
      Loc  : out Sloc)
   is
      C_Line, C_Col : aliased unsigned;
      C_Filename    : aliased Clang.CX_String.String_T;
   begin
      Clang.CX_Source_Location.Get_Presumed_Location
        (S, C_Filename'Access, C_Line'Access, C_Col'Access);
      File := Create (+Clang.CX_String.Get_C_String (C_Filename));
      Loc := (Line => Natural (C_Line), Column => Natural (C_Col));
      Clang.CX_String.Dispose_String (C_Filename);
   end Get_File_And_Sloc;

   -------------
   -- Parents --
   -------------

   function Parents (Cur : Clang.Index.Cursor_T) return Cursor_Vec is
      use Clang.Index;
      Res : Cursor_Vec;
      It  : Cursor_T := Cur;
   begin
      if Cursor_Is_Null (It) then
         return Cursor_Vectors.Empty_Vector;
      end if;
      while not Cursor_Is_Null (It) loop
         Res.Append (It);
         It := Get_Cursor_Lexical_Parent (It);
      end loop;
      return Res;
   end Parents;

   ---------------------------
   -- Closest_Common_Parent --
   ---------------------------

   function Closest_Common_Parent
     (Cur1, Cur2 : Clang.Index.Cursor_T) return Clang.Index.Cursor_T
   is
      use Clang.Index;
      use Cursor_Vectors;
      Parents_1, Parents_2 : Cursor_Vec;
      --  List of parents for Cur1 and Cur 2

   begin
      --  If both cursors don't belong to the same TU there is no common parent

      if Cursor_Get_Translation_Unit (Cur1)
        /= Cursor_Get_Translation_Unit (Cur2)
      then
         return Get_Null_Cursor;
      end if;

      --  Get the list of parent nodes and find the first diverging node,
      --  starting from the TU going down.

      Parents_1 := Parents (Cur1);
      Parents_2 := Parents (Cur2);
      if Parents_1.Is_Empty or else Parents_2.Is_Empty then
         return Get_Null_Cursor;
      end if;

      return Result : Cursor_T := Get_Null_Cursor do
         for I in
           0 .. Natural'Min (Parents_1.Last_Index, Parents_2.Last_Index) - 1
         loop
            declare
               Par_1 : constant Constant_Reference_Type :=
                 Parents_1.Constant_Reference (Parents_1.Last_Index - I);
               Par_2 : constant Constant_Reference_Type :=
                 Parents_2.Constant_Reference (Parents_2.Last_Index - I);
            begin
               exit when Par_1 /= Par_2;
               Result := Par_1.Element.all;
            end;
         end loop;
      end return;
   end Closest_Common_Parent;

   ---------------------
   -- Get_Cursor_Text --
   ---------------------

   function Get_Cursor_Text
     (Cur : Clang.Index.Cursor_T) return Unbounded_String
   is
      use Clang.Index;
      use Clang.CX_Source_Location;

      TU                       : Translation_Unit_T;
      Cur_Range                : Source_Range_T;
      Start_File, End_File     : aliased Clang.CX_File.File_T;
      Dummy_Line, Dummy_Col    : aliased unsigned;
      Start_Offset, End_Offset : aliased unsigned;

   begin
      if Cursor_Is_Null (Cur) then
         return Null_Unbounded_String;
      end if;
      TU := Cursor_Get_Translation_Unit (Cur);
      Cur_Range := Get_Cursor_Extent (Cur);
      Get_File_Location
        (Get_Range_Start (Cur_Range),
         File   => Start_File'Address,
         Line   => Dummy_Line'Access,
         Column => Dummy_Col'Access,
         Offset => Start_Offset'Access);
      Get_File_Location
        (Get_Range_End (Cur_Range),
         File   => End_File'Address,
         Line   => Dummy_Line'Access,
         Column => Dummy_Col'Access,
         Offset => End_Offset'Access);

      --  If the start and end files are not the same, we can't produce a text
      --  excerpt.

      if not Clang.CX_File.File_Is_Equal (Start_File, End_File) then
         return Null_Unbounded_String;
      end if;

      declare
         Buf_Size : aliased stddef_h.size_t;
         Buffer   : constant Interfaces.C.Strings.chars_ptr :=
           Get_File_Contents (TU, Start_File, Buf_Size'Access);
         --  C char pointer

         Buf_Str : String (1 .. Positive (Buf_Size))
         with Import, Convention => Ada;
         --  Overlay over the whole buffer
         for Buf_Str'Address use Ptr_To_Addr (Buffer);

         Cursor_Buf : String (1 .. Positive (End_Offset - Start_Offset + 1))
         with Import, Convention => Ada;
         --  Overlay over only the offset range for the cursor
         for Cursor_Buf'Address use
           Buf_Str (Positive (Start_Offset + 1))'Address;

      begin
         return To_Unbounded_String (Cursor_Buf);
      end;
   end Get_Cursor_Text;

   ----------------------
   -- Get_Cursor_Range --
   ----------------------

   function Get_Cursor_Range (Cur : Clang.Index.Cursor_T) return Sloc_Span is
      use Clang.CX_Source_Location;
      File_Start, File_End : Virtual_File;
      Sloc_Start, Sloc_End : Sloc;

      C_Range : constant Source_Range_T := Clang.Index.Get_Cursor_Extent (Cur);
   begin
      if Equal_Ranges (C_Range, Get_Null_Range) /= 0 then
         return No_Sloc_Span;
      end if;
      Get_File_And_Sloc (Get_Range_Start (C_Range), File_Start, Sloc_Start);
      Get_File_And_Sloc (Get_Range_End (C_Range), File_End, Sloc_End);
      if File_Start = File_End then
         return Sloc_Span'(Sloc_Start, Sloc_End);
      else
         return No_Sloc_Span;
      end if;
   end Get_Cursor_Range;

   ------------------
   -- Cursor_Image --
   ------------------

   function Cursor_Image (Cur : Clang.Index.Cursor_T) return String is
      use Clang.Index;
   begin
      if Cursor_Is_Null (Cur) then
         return "<null cursor>";
      else
         return
           "<"
           & Get_Cursor_Kind_Spelling (Get_Cursor_Kind (Cur))
           & "> at "
           & Image (Get_Cursor_Range (Cur));
      end if;
   end Cursor_Image;

   --------------------
   -- Qualified_Name --
   --------------------

   function Qualified_Name (Cur : Clang.Index.Cursor_T) return US_Vector is
      use Clang.Index;
      Res : US_Vector;
      It  : Cursor_T := Cur;
   begin
      while not Cursor_Is_Null (It)
        and then Is_Declaration (Get_Cursor_Kind (It))
      loop
         Res.Append (+Get_Cursor_Spelling (It));
         It := Get_Cursor_Semantic_Parent (It);
      end loop;
      Res.Reverse_Elements;
      return Res;
   end Qualified_Name;

end Stable_Sloc.Matchers.Clang_Ctx;
