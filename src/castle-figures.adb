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
   end Begin_Frame;

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
