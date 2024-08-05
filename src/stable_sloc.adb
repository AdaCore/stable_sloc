--
--  Copyright (C) 2024, AdaCore
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
--

with Ada.Exceptions;
with Ada.Text_IO;

with TOML;
with TOML.File_IO;

with Stable_Sloc.Matchers;   use Stable_Sloc.Matchers;
with Stable_Sloc.TOML_Utils; use Stable_Sloc.TOML_Utils;

package body Stable_Sloc is
   use Unbounded_Strings;

   function "+" (Loc : TOML.Source_Location) return Sloc is
     ((Loc.Line, Loc.Column));

   function To_JSON (Loc : Sloc_Span) return GNATCOLL.JSON.JSON_Value;
   --  Return an object JSON_Value representing the location range.

   function Is_Prefix
     (Prefix : String; Text : Unbounded_String) return Boolean;
   --  Check wether Prefix is a prefix of Text. An empty string prefix is a
   --  prefix of anything.

   function Pad_And_Compile
     (Pattern : Unbounded_String) return GNAT.Regexp.Regexp;
   --  Append '*' at the beginning and the end of Pattern if there isn't
   --  already a wildcard, and compile that string as a globbing pattern.

   -----------------------
   -- Format_Diagnostic --
   -----------------------

   function Format_Diagnostic (D : Load_Diagnostic) return String is
     (D.File.Display_Full_Name & ":" & Image (D.Location)
      & (if D.Location = No_Sloc then " " else ": ")
      & (+D.Diagnostic));

   ------------
   -- Adjust --
   ------------

   overriding procedure Adjust (Self : in out SS_Entry) is
   begin
      Self.Sloc_Matcher := new Sloc_Matcher_T'Class'(Self.Sloc_Matcher.all);
   end Adjust;

   --------------
   -- Finalize --
   --------------

   overriding procedure Finalize (Self : in out SS_Entry) is
   begin
      Free_Matcher (Self.Sloc_Matcher);
   end Finalize;

   package Entry_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => SS_Entry);
   subtype Entry_Vector is Entry_Vectors.Vector;

   Loaded_Entries : Entry_Map;

   package Diag_Vecs is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Load_Diagnostic);
   subtype Diag_Vector is Diag_Vecs.Vector;

   -------------
   -- To_JSON --
   -------------

   function To_JSON (Loc : Sloc_Span) return GNATCOLL.JSON.JSON_Value is
      use GNATCOLL.JSON;
   begin
      return Res : constant JSON_Value := Create_Object do
         Res.Set_Field ("start_line", Loc.Start_Sloc.Line);
         Res.Set_Field ("start_column", Loc.Start_Sloc.Column);
         Res.Set_Field ("end_line", Loc.End_Sloc.Line);
         Res.Set_Field ("end_column", Loc.End_Sloc.Column);
      end return;
   end To_JSON;

   -------------
   -- To_JSON --
   -------------

   function To_JSON
     (Diags : Load_Diagnostic_Arr) return GNATCOLL.JSON.JSON_Value
   is
      use GNATCOLL.JSON;
      Arr          : JSON_Array := Empty_Array;
   begin
      for Diag of Diags loop
         declare
            New_Diag : constant JSON_Value := Create_Object;
            Loc      : constant JSON_Value := Create_Object;
         begin
            New_Diag.Set_Field ("file", Create(Diag.File.Display_Full_Name));
            Loc.Set_Field ("line", Diag.Location.Line);
            Loc.Set_Field ("column", Diag.Location.Column);
            New_Diag.Set_Field ("location", Loc);
            New_Diag.Set_Field ("diagnostic", Create (Diag.Diagnostic));
            Append (Arr, New_Diag);
         end;
      end loop;
      return Create (Arr);
   end To_JSON;

   -------------
   -- To_JSON --
   -------------

   function To_JSON
     (Results : Match_Result_Vec) return GNATCOLL.JSON.JSON_Value
   is
      use GNATCOLL.JSON;
      Arr : JSON_Array := Empty_Array;
      Local_Res : JSON_Value;
   begin
      for Match_Res of Results loop
         Local_Res := Create_Object;
         Local_Res.Set_Field ("annotation", To_JSON (Match_Res.Annotation));
         Local_Res.Set_Field ("identifier", Match_Res.Identifier);
         Local_Res.Set_Field ("file", Match_Res.File.Display_Full_Name);
         Local_Res.Set_Field ("success", Match_Res.Success);
         case Match_Res.Success is
            when True =>
               Local_Res.Set_Field ("location", To_JSON (Match_Res.Location));
            when False =>
               Local_Res.Set_Field ("diagnostic", Match_Res.Diagnostic);
         end case;
         Append (Arr, Local_Res);
      end loop;
      return Create (Arr);
   end To_JSON;

   ---------------
   -- Create_DB --
   ---------------

   function Create_DB return Entry_DB is (Map => Entry_Maps.Empty_Map);

   ---------------
   -- Import_DB --
   ---------------

   procedure Import_DB (Into : in out Entry_DB; From : Entry_DB) is
      use Entry_Maps;
      Src_Cur : Cursor := From.Map.First;
      Dst_Cur : Cursor;
      Dummy   : Boolean;
   begin
      while Src_Cur /= No_Element loop
         Into.Map.Insert (Key (Src_Cur), Element (Src_Cur), Dst_Cur, Dummy);
         Next (Src_Cur);
      end loop;
   end Import_DB;

   --------------
   -- Is_Empty --
   --------------

   function Is_Empty (DB : Entry_DB) return Boolean is (DB.Map.Is_Empty);

   ------------------
   -- Load_Entries --
   ------------------

   function Load_Entries
     (Spec_File      : GNATCOLL.VFS.Virtual_File;
      DB             : in out Entry_DB;
      Ignore_Unknown : Boolean := True;
      Strict         : Boolean := False) return Load_Diagnostic_Arr
   is
      use Entry_Maps;
      Spec_Load_Res : constant TOML.Read_Result :=
        TOML.File_IO.Load_File (GNATCOLL.VFS."+" (Spec_File.Full_Name));
      Root          : TOML.TOML_Value;
      Diags         : Diag_Vector;
      Local_Entries : Entry_DB := Create_DB;
      Cur           : Cursor;
   begin
      if not Spec_Load_Res.Success then
         return
           [(File       => Spec_File,
             Location   => +Spec_Load_Res.Location,
             Diagnostic => Spec_Load_Res.Message)];
      end if;
      Root := Spec_Load_Res.Value;

      for Entr of Root.Iterate_On_Table loop
         exit when not Diags.Is_Empty and then Strict;
         declare
            Spec         : TOML.TOML_Value renames Entr.Value;
            Parsed_Entry : SS_Entry;
            File_Matcher : constant TOML.TOML_Value :=
              Spec.Get_Or_Null ("file");
            Purpose      : constant TOML.TOML_Value :=
              Spec.Get_Or_Null ("purpose");
            File_Pat     : US;
         begin
            Parsed_Entry.Annotations :=
              Get (Spec, "annotations", TOML.TOML_Array);
            if Parsed_Entry.Annotations.Length = 0 then
               raise Parse_Error with
               TOML.Format_Location (Parsed_Entry.Annotations.Location)
               & ":Empty annotations array";
            end if;

            for J in 1 .. Parsed_Entry.Annotations.Length loop
               declare Annot : constant TOML.TOML_Value :=
                 Parsed_Entry.Annotations.Item (J);
               begin
                  if Annot.Kind not in TOML.TOML_Table
                  then
                     raise Parse_Error with
                       TOML.Format_Location (Annot.Location)
                       & ":Wrong type for an annotation: expected "
                       & TOML.TOML_Table'Image & " but got "
                       & Annot.Kind'Image;
                  end if;
                  if Annot.Has ("purpose")
                    and then Annot.Get ("purpose").Kind not in TOML.TOML_String
                  then
                     raise Parse_Error with
                       TOML.Format_Location (Annot.Get ("purpose").Location)
                       & ":Wrong type for ""purpose"": expected "
                       & TOML.TOML_String'Image & "but got "
                       & Annot.Get ("purpose").Kind'Image;
                  end if;
               end;
            end loop;

            Parsed_Entry.Kind := Get (Spec, "kind");
            Parsed_Entry.Sloc_Matcher :=
              new Sloc_Matcher_T'Class'
                (Instantiate_Matcher (Get (Spec, "matcher", TOML.TOML_Table),
                                      Kind => +Parsed_Entry.Kind));
            Parsed_Entry.File_Pattern :=
              (if not File_Matcher.Is_Null
                 and then (File_Matcher.Kind in TOML.TOML_String
                           or else raise Parse_Error with
                             TOML.Format_Location (File_Matcher.Location)
                             & ":unexpected type for ""files"": expected "
                             & TOML.TOML_String'Image & " but got "
                             & File_Matcher.Kind'Image)
               then File_Matcher.As_Unbounded_String
               else Null_Unbounded_String);
            Parsed_Entry.File_Regexp :=
              Pad_And_Compile (Parsed_Entry.File_Pattern);
            Parsed_Entry.At_Most_Once :=
              Get_Or_Default (Spec, "at_most_once", False);
            Local_Entries.Map.Insert (Entr.Key, Parsed_Entry);

         exception
            when Exc : GNAT.Regexp.Error_In_Regexp =>
               Diags.Append
                 (Load_Diagnostic'
                    (File       => Spec_File,
                     Location   =>
                       (Entr.Value.Location.Line, Entr.Value.Location.Column),
                     Diagnostic =>
                       +"Error while parsing entry """ & Entr.Key & """: "
                       & "Could not compile file pattern. "
                       & Ada.Exceptions.Exception_Message (Exc)));

            when Exc : Unknown_Matcher_Error =>
               if not Ignore_Unknown then
                  Diags.Append
                    (Load_Diagnostic'
                       (File       => Spec_File,
                        Location   =>
                          (Entr.Value.Location.Line,
                           Entr.Value.Location.Column),
                        Diagnostic =>
                        +"Error while parsing entry """ & Entr.Key & """: "
                        & Ada.Exceptions.Exception_Message (Exc)));
               end if;

            when Exc : Parse_Error =>
               declare
                  Loc : Sloc;
                  Msg : constant String :=
                     Split_Sloc_Prefix
                        (Ada.Exceptions.Exception_Message (Exc), Loc);
               begin
                  Diags.Append
                  (Load_Diagnostic'
                     (File       => Spec_File,
                      Location   => Loc,
                      Diagnostic =>
                        +"Error while parsing entry """ & Entr.Key & """: "
                        & Msg));
               end;
         end;
      end loop;

      if not Diags.Is_Empty and then Strict then
         Local_Entries.Map.Clear;
      else
         --  Merge the entries in two phases. First generate the duplicate
         --  entries diagnostics, then if we are not in Strict mode or there
         --  are none then proceed to merge.

         Cur := Local_Entries.Map.First;
         while Cur /= No_Element loop
            if DB.Map.Contains (Key (Cur)) then
               Diags.Append (Load_Diagnostic'
                 (File       => Spec_File,
                  Location   =>  No_Sloc,
                  Diagnostic =>
                    Key (Cur) & ": an entry with the same identifier was"
                    & " already loaded, it will not be loaded."));
            end if;
            Cur := Next (Cur);
         end loop;

         if Diags.Is_Empty or else not Strict then
            Import_DB (DB, Local_Entries);
         end if;
      end if;

      return [for Diag of Diags => Diag];
   end Load_Entries;

   -------------------
   -- Match_Entries --
   -------------------

   function Match_Entries
     (Files          : GNATCOLL.VFS.File_Array;
      DB             : in out Entry_DB;
      Purpose_Prefix : String := "") return Match_Result_Vec
   is
      use Entry_Maps;
      use GNATCOLL.VFS;
      Res : Match_Result_Vec;
      Cur : Cursor;
   begin
   --  TODO??? This currently iterates over each file, then over each entry,
   --  which may not be the most efficient way of doing things. Namely, we
   --  could imagine in the future to batch process all entries for the same
   --  backend for the same file to avoid reading the same file multiple times.
   --  This would require some API modification in the Stable_Sloc.Matchers
   --  interface.

      for File of Files loop
         Cur := DB.Map.First;
         while Cur /= No_Element loop
            declare
               Entr                 : constant Reference_Type :=
                 DB.Map.Reference (Cur);
               Local_Res            : Sloc_Match_Vec;
               Relevant_Annotations : TOML.TOML_Value := TOML.Create_Array;
            begin
               for J in 1 .. Entr.Annotations.Length loop
                  declare
                     use TOML;
                     Annot   : constant TOML_Value :=
                       Entr.Annotations.Item (J);
                     Purpose : constant Unbounded_String :=
                       Get_Or_Null (Annot, "purpose");
                  begin
                     if Purpose = Null_Unbounded_String
                       or else Is_Prefix (Purpose_Prefix, Purpose)
                     then
                        Relevant_Annotations.Append (Annot);
                     end if;
                  end;
               end loop;
               if Relevant_Annotations.Length = 0 then
                  goto Continue;
               end if;
               if not GNAT.Regexp.Match
                        (GNATCOLL.VFS."+" (File.Full_Name), Entr.File_Regexp)
               then
                  goto Continue;
               end if;
               Local_Res := Entr.Sloc_Matcher.Match (File);
               for Match of Local_Res loop
                  for J in 1 .. Relevant_Annotations.Length loop
                  declare
                     Annot : constant TOML.TOML_Value :=
                       Relevant_Annotations.Item (J);
                  begin
                     if Match.Success then
                        if Entr.At_Most_Once
                          and then Entr.Last_File /= No_File
                          and then Entr.Last_Range /= No_Sloc_Span
                          and then
                            (Entr.Last_File /= File
                             or else Entr.Last_Range /= Match.Span)
                        then
                           Res.Append (Match_Result'
                             (Success    => False,
                              Identifier => Key (Cur),
                              Annotation => Annot,
                              File       => File,
                              Diagnostic =>
                                +"Annotation has already matched at a"
                                 & " different location"));
                        else
                           Res.Append (Match_Result'
                             (Success    => True,
                              Identifier => Key (Cur),
                              Annotation => Annot,
                              File       => File,
                              Location   => Match.Span));
                           if Entr.At_Most_Once then
                              Entr.Last_File := File;
                              Entr.Last_Range := Match.Span;
                           end if;
                        end if;
                     else
                        Res.Append (Match_Result'
                          (Success    => False,
                           Identifier => Key (Cur),
                           Annotation => Annot,
                           File       => File,
                           Diagnostic => Match.Reason));
                     end if;
                  end;
                     <<Skip_Annotation>>
                  end loop;
               end loop;
            end;
            <<Continue>>
            Next (Cur);
         end loop;
      end loop;
      return Res;
   end Match_Entries;

   -------------------------
   -- Add_Or_Update_Entry --
   -------------------------

   function Add_Or_Update_Entry
     (DB          : in out Entry_DB;
      Identifier  : Unbounded_String;
      Annotation  : TOML.TOML_Value;
      Kind        : Unbounded_String;
      File        : GNATCOLL.VFS.Virtual_File;
      Span        : Sloc_Span;
      File_Prefix : Unbounded_String := Null_Unbounded_String;
      Replace     : Boolean := True) return Load_Diagnostic_Arr
   is
      use Entry_Maps;
      Cur        : constant Cursor := DB.Map.Find (Identifier);
      New_Entry  : SS_Entry;
      Filename   : constant Unbounded_String :=
        +(GNATCOLL.VFS."+" (File.Full_Name));
      Actual_Pat : constant Unbounded_String :=
        (if File_Prefix /= Null_Unbounded_String
           and then Is_Prefix (File_Prefix, Filename)
         then Unbounded_Slice
                (Source => Filename,
                 Low    => Length (File_Prefix) + 1,
                 High   => Length (Filename))
         else Filename);
   begin
      if not Replace and then Cur /= No_Element then
         return
           [Load_Diagnostic'
              (File       => File,
               Location   => No_Sloc,
               Diagnostic =>
                 "Identifier """ & Identifier
                  & """ already in entry database")];
      end if;
      New_Entry.Sloc_Matcher := new Sloc_Matcher_T'Class'
        (Instantiate_Matcher (File, Span, +Kind));
      New_Entry.Annotations := TOML.Create_Array;
      New_Entry.Annotations.Append (Annotation);
      New_Entry.Kind := Kind;
      New_Entry.File_Pattern := Actual_Pat;
      New_Entry.File_Regexp := Pad_And_Compile (New_Entry.File_Pattern);
      New_Entry.At_Most_Once := True;
      DB.Map.Include (Identifier, New_Entry);
      return [];
      exception
         when Exc : Unknown_Matcher_Error =>
            return
               [Load_Diagnostic'
                  (File       => File,
                   Location   => No_Sloc,
                   Diagnostic => +"No such matcher kind: " & Kind)];
         when Exc : Parse_Error =>
            declare
               Loc : Sloc;
               Msg : constant String :=
                 Split_Sloc_Prefix
                   (Ada.Exceptions.Exception_Message (Exc), Loc);
            begin
               return
                 [Load_Diagnostic'
                    (File       => File,
                     Location   => Loc,
                     Diagnostic =>
                       +"Error while creating entry """ & Identifier & """: "
                       & Msg)];
            end;
   end Add_Or_Update_Entry;

   -----------------------
   -- Reset_Match_Count --
   -----------------------

   procedure Reset_Match_Count (DB : in out Entry_DB) is
   begin
      for Cur in DB.Map.Iterate loop
         DB.Map.Reference (Cur).Last_File := GNATCOLL.VFS.No_File;
         DB.Map.Reference (Cur).Last_Range := No_Sloc_Span;
      end loop;
   end Reset_Match_Count;

   ------------------
   -- Dump_Entries --
   ------------------

   procedure Dump_Entries (DB : Entry_DB) is
      use Ada.Text_IO;
      use Entry_Maps;
      Cur : Cursor;
   begin
      if DB.Map.Is_Empty then
         Put_Line ("No loaded entries");
      end if;
      Cur := DB.Map.First;
      while Cur /= No_Element loop
         declare
            Entr : Constant_Reference_Type := DB.Map.Constant_Reference (Cur);
         begin
            Put_Line (+("Entry " & Key (Cur) & ":"));
            Put_Line
            ("   Annotations : "
               & To_JSON (Entr.Annotations).Write (Compact => True));
            Put_Line ("   File matcher: " & (+Entr.File_Pattern));
            Put_Line ("   At_Most_Once: " & Entr.At_Most_Once'Image);
            Put_Line ("   Matcher kind: " & (+Entr.Kind));
            Put_Line ("   Sloc matcher: " & (+Entr.Sloc_Matcher.Image));
            Next (Cur);
         end;
      end loop;
   end Dump_Entries;

   -------------------
   -- Write_Entries --
   -------------------

   procedure Write_Entries
     (DB : Entry_DB; File : GNATCOLL.VFS.Virtual_File)
   is
      use Ada.Text_IO;
      use Entry_Maps;
      use TOML;
      Res    : TOML_Value := Create_Table;
      Cur    : Cursor := DB.Map.First;
      File_T : File_Type;
   begin
      Create (File_T, Out_File, Name => GNATCOLL.VFS."+" (File.Full_Name));
      while Cur /= No_Element loop
         declare
            Entr : constant Constant_Reference_Type :=
              DB.Map.Constant_Reference (Cur);
            Entry_Value   : TOML_Value := Create_Table;
         begin
            Entry_Value.Set ("file", Create_String (Entr.File_Pattern));
            Entry_Value.Set ("annotations", Entr.Annotations);
            Entry_Value.Set ("kind", Create_String (Entr.Kind));
            Entry_Value.Set
              ("at_most_once", Create_Boolean (Entr.At_Most_Once));
            Entry_Value.Set ("matcher", Entr.Sloc_Matcher.Dump_Spec);
            Res.Set (Key (Cur), Entry_Value);
         end;
         Next (Cur);
      end loop;
      TOML.File_IO.Dump_To_File (Res, File_T);
      Close (File_T);
      exception
         when Exc : others =>
            Put_Line
              (Standard_Error,
               "Error while writing entries to file:"
               & Ada.Exceptions.Exception_Information (Exc));
            if Is_Open (File_T) then
               Close (File_T);
            end if;
   end Write_Entries;

   -----------------
   -- Query_Entry --
   -----------------

   function Query_Entry
     (DB : Entry_DB; Identifier : Unbounded_String) return Entry_View
   is
      use Entry_Maps;
      Cur : constant Cursor := DB.Map.Find (Identifier);
   begin
      if not Has_Element (Cur) then
         return No_Entry_View;
      end if;
      return Res : Entry_View do
         Res.Kind := Element (Cur).Kind;
         Res.File_Pattern := Element (Cur).File_Pattern;
         Res.Annotations  := Element (Cur).Annotations;
         Res.At_Most_Once := Element (Cur).At_Most_Once;
      end return;
   end Query_Entry;

   -------------------
   -- Replace_Entry --
   -------------------

   procedure Replace_Entry
     (Target_DB  : in out Entry_DB;
      Source_DB  : Entry_DB;
      Target_Id  : Unbounded_String;
      Source_Id  : Unbounded_String)
   is
      use Entry_Maps;
      Source_Cur : constant Cursor := Source_DB.Map.Find (Source_Id);
   begin
      if Source_Cur = No_Element then
         raise Constraint_Error with
           "No entry with identifier " & (+Source_Id);
      end if;
      Target_DB.Map.Include (Target_Id, Element (Source_Cur));
   end Replace_Entry;

   ------------------
   -- Delete_Entry --
   ------------------

   procedure Delete_Entry
     (DB : in out Entry_DB; Identifier : Unbounded_String)
   is
      use Entry_Maps;
      Cur : Cursor := DB.Map.Find (Identifier);
   begin
      if Has_Element (Cur) then
         DB.Map.Delete (Cur);
      end if;
   end Delete_Entry;

   ---------
   -- "<" --
   ---------

   function "<" (L, R : Sloc) return Boolean is
     (if L.Line = R.Line then L.Column < R.Column else L.Line < R.Line);

   -----------
   -- Image --
   -----------

   function Image (Self : Sloc) return String is
     (if Self = No_Sloc
      then ""
      else Img (Self.Line) & ":" & Img (Self.Column));

   -----------
   -- Image --
   -----------

   function Image (Self : Sloc_Span) return String is
     (if Self = No_Sloc_Span
      then ""
      else Image (Self.Start_Sloc) & " - " & Image (Self.End_Sloc));

   ---------------
   -- Is_Prefix --
   ---------------

   function Is_Prefix (Prefix : String; Text : Unbounded_String) return Boolean
   is
   begin
      if Prefix'Length = 0 then
         return True;
      end if;
      return Is_Prefix (+Prefix, Text);
   end Is_Prefix;

   ---------------------
   -- Pad_And_Compile --
   ---------------------

   function Pad_And_Compile
     (Pattern : Unbounded_String) return GNAT.Regexp.Regexp
   is
      File_Pat : Unbounded_String := Pattern;
   begin
      -- Pad the pattern with a * on each side as a GNAT.Regexp needs to
      -- match the whole string.

      if Length (File_Pat) = 0 or else Element (File_Pat, 1) /= '*' then
         File_Pat := "*" & File_Pat;
      end if;
      if Element (File_Pat, Length (File_Pat)) /= '*' then
         Append (File_Pat, '*');
      end if;
      return GNAT.Regexp.Compile (Pattern => +File_Pat, Glob => True);
   end Pad_And_Compile;

end Stable_Sloc;
