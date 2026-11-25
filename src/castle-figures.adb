with Ada.Text_IO;
with Castle.Voxel_Mesh;

package body Castle.Figures is

   use Interfaces;

   type Look is record
      Used    : Boolean := False;
      Pending : Boolean := False;
      Casts   : Boolean := True;
      Thin    : Boolean := False;
      Count   : Natural := 0;
      Boxes   : Box_List;
      Skin    : Skin_Access;
   end record;

   Looks : array (Look_Id) of Look;
   Used_N : Natural := 0;

   function New_Look (R : Rig; Skin : Skin_Pixels; Casts : Boolean := True; Thin : Boolean := False)
                      return Look_Id is
   begin
      for L in Look_Id loop
         if not Looks (L).Used then
            if Looks (L).Skin = null then
               Looks (L).Skin := new Skin_Pixels;
            end if;
            Looks (L).Skin.all := Skin;
            Looks (L).Used := True;
            Looks (L).Pending := True;
            Looks (L).Casts := Casts;
            Looks (L).Thin := Thin;
            Looks (L).Count := R.Count;
            Looks (L).Boxes := R.Boxes;
            Used_N := Used_N + 1;
            return L;
         end if;
      end loop;
      raise Program_Error with "no free figure look slot";
   end New_Look;

   procedure Free_Look (L : Look_Id) is
   begin
      if Looks (L).Used then
         Looks (L).Used := False;
         Looks (L).Pending := False;
         Used_N := Used_N - 1;
      end if;
   end Free_Look;

   function Looks_Used return Natural is (Used_N);

   procedure Begin_Frame is
   begin
      Bone_Count := 0;
      Box_Count := 0;
      Blob_Count := 0;
      Figure_Count := 0;
      Vox_List_Count := 0;
   end Begin_Frame;

   ---------------------------------------------------------- voxel looks

   type Quads_Access is access Castle.Voxel_Mesh.Quad_Array;
   type Vox_Look is record
      Used    : Boolean := False;
      Pending : Boolean := False;
      Drawn_N, Bytes_N : Natural := 0;
      Quads   : Quads_Access;
      Bytes   : Bytes_Access;
      Parts   : Parts_Access;
      Pal     : Pal_Access;
   end record;
   Vox_Looks : array (Vox_Look_Id) of Vox_Look;
   Vox_Used_N : Natural := 0;
   List_Full_Said : Boolean := False;

   function New_Voxel_Look (V : Castle.Bodies.Voxels.Voxel_Look) return Vox_Look_Id is
   begin
      for L in Vox_Look_Id loop
         declare
            X : Vox_Look renames Vox_Looks (L);
         begin
            if not X.Used then
               if X.Quads = null then
                  X.Quads := new Castle.Voxel_Mesh.Quad_Array (1 .. Vox_Quads_Each);
                  X.Bytes := new Castle.Bodies.Voxels.Byte_Array (0 .. Vox_Bytes_Each - 1);
                  X.Parts := new Vox_Part_Table;
                  X.Pal := new Castle.Bodies.Voxels.Palette;
               end if;
               X.Drawn_N := V.Drawn_N;
               X.Bytes_N := V.Bytes_N;
               X.Quads (1 .. V.Drawn_N) := V.Drawn (1 .. V.Drawn_N);
               X.Bytes (0 .. V.Bytes_N - 1) := V.Bytes (0 .. V.Bytes_N - 1);
               X.Pal.all := V.Pal;
               for B in Bone loop
                  declare
                     P : Castle.Bodies.Voxels.Part_Place renames V.Parts (B);
                     K : constant Natural := 8 * Bone'Pos (B);
                  begin
                     X.Parts (K .. K + 7) :=
                       [U32 (P.Offset), U32 (P.Nx), U32 (P.Ny), U32 (P.Nz),
                        U32 (P.Ox + Vox_Bias), U32 (P.Oy + Vox_Bias), U32 (P.Oz + Vox_Bias), 0];
                  end;
               end loop;
               X.Used := True;
               X.Pending := True;
               Vox_Used_N := Vox_Used_N + 1;
               return L;
            end if;
         end;
      end loop;
      raise Program_Error with "no free voxel look slot";
   end New_Voxel_Look;

   procedure Free_Voxel_Look (L : Vox_Look_Id) is
   begin
      if Vox_Looks (L).Used then
         Vox_Looks (L).Used := False;
         Vox_Looks (L).Pending := False;
         Vox_Used_N := Vox_Used_N - 1;
      end if;
   end Free_Voxel_Look;

   function Voxel_Looks_Used return Natural is (Vox_Used_N);

   procedure Add_Voxel (L : Vox_Look_Id; F : Frames) is
      First : constant Natural := Bone_Count;
      X : Vox_Look renames Vox_Looks (L);
   begin
      if not X.Used or else Figure_Count = Max_Figures then
         return;
      end if;
      if Vox_List_Count + X.Drawn_N > Max_Vox_List then
         if not List_Full_Said then
            List_Full_Said := True;
            Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error,
                                  "figures: more than" & Max_Vox_List'Image & " voxel quads in a frame: some serfs left out");
         end if;
         return;
      end if;
      Figure_Count := Figure_Count + 1;
      for B in Bone loop
         declare
            Fr : Frame renames F (B);
         begin
            Bones (Bone_Count) :=
              (F32 (Fr.X.X), F32 (Fr.X.Y), F32 (Fr.X.Z), F32 (Fr.O.X),
               F32 (Fr.Y.X), F32 (Fr.Y.Y), F32 (Fr.Y.Z), F32 (Fr.O.Y),
               F32 (Fr.Z.X), F32 (Fr.Z.Y), F32 (Fr.Z.Z), F32 (Fr.O.Z));
            Bone_Count := Bone_Count + 1;
         end;
      end loop;
      for K in 1 .. X.Drawn_N loop
         Vox_List (Vox_List_Count) := (A => X.Quads (K).A, B => X.Quads (K).B, Bone_First => U32 (First),
                                       Look => U32 (L - 1));
         Vox_List_Count := Vox_List_Count + 1;
      end loop;
   end Add_Voxel;

   procedure Next_Vox_Upload (U : out Vox_Upload; Found : out Boolean) is
   begin
      for K in Vox_Look_Id loop
         declare
            X : Vox_Look renames Vox_Looks (K);
         begin
            if X.Used and then X.Pending then
               X.Pending := False;
               U := (Look => K, Pal => X.Pal, Parts => X.Parts, Bytes => X.Bytes, Bytes_N => X.Bytes_N);
               Found := True;
               return;
            end if;
         end;
      end loop;
      U := (others => <>);
      Found := False;
   end Next_Vox_Upload;

   procedure Add (L : Look_Id; F : Frames) is
      First : constant Natural := Bone_Count;
   begin
      if not Looks (L).Used or else Figure_Count = Max_Figures then
         return;
      end if;
      Figure_Count := Figure_Count + 1;
      for B in Bone loop
         declare
            Fr : Frame renames F (B);
         begin
            Bones (Bone_Count) :=
              (F32 (Fr.X.X), F32 (Fr.X.Y), F32 (Fr.X.Z), F32 (Fr.O.X),
               F32 (Fr.Y.X), F32 (Fr.Y.Y), F32 (Fr.Y.Z), F32 (Fr.O.Y),
               F32 (Fr.Z.X), F32 (Fr.Z.Y), F32 (Fr.Z.Z), F32 (Fr.O.Z));
            Bone_Count := Bone_Count + 1;
         end;
      end loop;
      for K in 1 .. Looks (L).Count loop
         declare
            Bx : Box renames Looks (L).Boxes (K);
         begin
            Boxes (Box_Count) :=
              (Lx => F32 (Bx.Lo.X), Ly => F32 (Bx.Lo.Y), Lz => F32 (Bx.Lo.Z), Round => F32 (Rounding (Bx)),
               Sx => F32 (Bx.Size.X), Sy => F32 (Bx.Size.Y), Sz => F32 (Bx.Size.Z), Taper => F32 (Bx.Taper),
               Bone_Index => U32 (First + Bone'Pos (Bx.On)),
               Layer => U32 (L - 1),
               Net => U32 (Bx.U) or Shift_Left (U32 (Bx.V), 16),
               Dims => U32 (Bx.W) or Shift_Left (U32 (Bx.D), 8) or Shift_Left (U32 (Bx.H), 16)
                       or (if Bx.Cutout then Shift_Left (1, 24) else 0)
                       or (if Bx.Glow then Shift_Left (1, 25) else 0)
                       or (if Looks (L).Casts then 0 else Shift_Left (1, 26))
                       or (if Looks (L).Thin then Shift_Left (1, 27) else 0));
            Box_Count := Box_Count + 1;
         end;
      end loop;
   end Add;

   procedure Add_Shadow (Ground : Vec3; Radius : Float) is
   begin
      if Blob_Count < Blobs'Length then
         Blobs (Blob_Count) := (F32 (Ground.X), F32 (Ground.Y), F32 (Ground.Z), F32 (Radius));
         Blob_Count := Blob_Count + 1;
      end if;
   end Add_Shadow;

   procedure Next_Upload (L : out Look_Id; Skin : out Skin_Access; Found : out Boolean) is
   begin
      for K in Look_Id loop
         if Looks (K).Used and then Looks (K).Pending then
            Looks (K).Pending := False;
            L := K;
            Skin := Looks (K).Skin;
            Found := True;
            return;
         end if;
      end loop;
      L := 1;
      Skin := null;
      Found := False;
   end Next_Upload;

end Castle.Figures;
