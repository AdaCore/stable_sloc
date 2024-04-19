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

   function Is_Prefix
     (Prefix : String; Text : Unbounded_String) return Boolean;
   --  Check wether Prefix is a prefix of Text. An empty string prefix is a
   --  prefix of anything.

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
      end loop;
   end Import_DB;

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
            Parsed_Entry.Purpose :=
              (if Purpose.Is_Null
               then Null_Unbounded_String
               else (if Purpose.Kind in TOML.TOML_String
                     then Purpose.As_Unbounded_String
                     else raise Parse_Error with
                       "unexpected type for ""purpose"": expected "
                       & TOML.TOML_String'Image & " but got "
                       & Purpose.Kind'Image));
            Parsed_Entry.Annotation := Get (Spec, "annotation");
            Parsed_Entry.Sloc_Matcher :=
              new Sloc_Matcher_T'Class'(Instantiate_Matcher (Spec));
            Parsed_Entry.File_Pattern :=
              (if not File_Matcher.Is_Null
                 and then (File_Matcher.Kind in TOML.TOML_String
                           or else raise Parse_Error with
                             "unexpected type for ""files"": expected "
                             & TOML.TOML_String'Image & " but got "
                             & File_Matcher.Kind'Image)
               then File_Matcher.As_Unbounded_String
               else Null_Unbounded_String);
            File_Pat := Parsed_Entry.File_Pattern;

            -- Pad the pattern with a * on each side as a GNAT.Regexp needs to
            -- match the whole string.

            if Length (File_Pat) = 0 or else Element (File_Pat, 1) /= '*' then
               File_Pat := "*" & File_Pat;
            end if;
            if Element (File_Pat, Length (File_Pat)) /= '*' then
               Append (File_Pat, '*');
            end if;
            Parsed_Entry.File_Regexp :=
              GNAT.Regexp.Compile (Pattern => +File_Pat, Glob => True);
            Local_Entries.Map.Insert (Entr.Key, Parsed_Entry);
         exception
            when Exc : GNAT.Regexp.Error_In_Regexp =>
               Diags.Append
                 (Load_Diagnostic'
                    (File       => Spec_File,
                     Location   => No_Sloc,
                     Diagnostic =>
                       +"Error while parsing entry" & Entr.Key & ": "
                       & "Could not compile file pattern. "
                       & Ada.Exceptions.Exception_Message (Exc)));
            when Exc : Unknown_Matcher_Error =>
               if not Ignore_Unknown then
                  Diags.Append
                    (Load_Diagnostic'
                       (File       => Spec_File,
                        Location   => No_Sloc,
                        Diagnostic =>
                        +"Error while parsing entry" & Entr.Key & ": "
                        & Ada.Exceptions.Exception_Message (Exc)));
               end if;
            when Exc : Parse_Error =>
               Diags.Append
                 (Load_Diagnostic'
                    (File       => Spec_File,
                     Location   => No_Sloc,
                     Diagnostic =>
                       +"Error while parsing entry" & Entr.Key & ": "
                       & Ada.Exceptions.Exception_Message (Exc)));
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
      DB             : Entry_DB;
      Purpose_Prefix : String := "") return Match_Result_Vec
   is
      use Entry_Maps;
      Res : Match_Result_Vec;
      Cur : Cursor;
   begin
      for File of Files loop
         Cur := DB.Map.First;
         while Cur /= No_Element loop
            if Element (Cur).Purpose /= Null_Unbounded_String
              and then not Is_Prefix (Purpose_Prefix, Element (Cur).Purpose)
            then
               goto Continue;
            end if;
            if not GNAT.Regexp.Match
                     (GNATCOLL.VFS."+" (File.Full_Name),
                      Element (Cur).File_Regexp)
            then
               goto Continue;
            end if;
            declare
               Local_Res : constant Sloc_Match_Vec :=
                 Element (Cur).Sloc_Matcher.Match (File);
            begin
               for Match of Local_Res loop
                  if Match.Success then
                     Res.Append (Match_Result'
                       (Success    => True,
                        Identifier => Key (Cur),
                        Purpose    => Element (Cur).Purpose,
                        Annotation => Element (Cur).Annotation,
                        File       => File,
                        Location   => Match.Span));
                  else
                     Res.Append (Match_Result'
                       (Success    => False,
                        Identifier => Key (Cur),
                        Purpose    => Element (Cur).Purpose,
                        Annotation => Element (Cur).Annotation,
                        File       => File,
                        Diagnostic => Match.Reason));
                  end if;
               end loop;
            end;
            <<Continue>>
            Cur := Next (Cur);
         end loop;
      end loop;
      return Res;
   end Match_Entries;

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
         Put_Line (+("Entry " & Key (Cur) & ":"));
         Put_Line ("   Purpose     : " & (+Element (Cur).Purpose));
         Put_Line ("   Annotation  : " & (+Element (Cur).Annotation));
         Put_Line ("   File Matcher: " & (+Element (Cur).File_Pattern));
         Put_Line ("   Sloc_Matcher: " & (+Element (Cur).Sloc_Matcher.Image));
         cur := Next (Cur);
      end loop;
   end Dump_Entries;

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

   function Is_Prefix (Prefix : String; Text : Unbounded_String) return Boolean
   is
   begin
      if Prefix'Length = 0 then
         return True;
      end if;
      if Prefix'Length > Length (Text) then
         return False;
      end if;
      return
        (for all I in Prefix'First .. Prefix'Last =>
         Prefix (I) = Element (Text, I));
   end Is_Prefix;

end Stable_Sloc;
