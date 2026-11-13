with Ada.Command_Line;                  use Ada.Command_Line;
with Ada.Text_IO;                       use Ada.Text_IO;
with Ada.Directories;
with Ada.Numerics.Elementary_Functions; use Ada.Numerics.Elementary_Functions;
with Castle.Blocks;                     use Castle.Blocks;
with Castle.Buildings;                  use Castle.Buildings;
with Castle.Buildings.Layout;           use Castle.Buildings.Layout;
with Castle.Chunks;                     use Castle.Chunks;
with Castle.Dims;                       use Castle.Dims;
with Castle.Fields;                     use Castle.Fields;
with Castle.Flora;                      use Castle.Flora;
with Castle.Geology;                    use Castle.Geology;
with Castle.Hash;
with Castle.Iso;
with Castle.Maps;                       use Castle.Maps;
with Castle.PNG;                        use Castle.PNG;
with Castle.Text;                       use Castle.Text;
with Castle.Worldgen;

--  village_preview [residents] : finds a dry hillside near water, lays a
--  small branching pathway network from the stake (standing in for the
--  player's designation), zones habitation around it, builds one house per
--  resident attached to the pathways and renders preview/village.png.
procedure Village_Preview is
   Residents : Positive := 10;
   W         : World;
   P         : Plan;
   Net       : Network;
   Best      : Float   := -1.0E9;
   Cx, Cy    : Integer := N / 2;   --  site centre (m)
   Up_X      : Float   := 0.0;     --  uphill, axis-aligned
   Up_Y      : Float   := 1.0;

   function Pt (X, Y : Float) return Point is (Point'(X, Y));
   function Dist (A, B : Point) return Float is (Sqrt ((A.X - B.X) ** 2 + (A.Y - B.Y) ** 2));
   function Jit (K : Integer) return Float is
     (2.0 * Castle.Hash.Unit (Castle.Hash.Hash_2 (W.Seed, 901, K)) - 1.0);
begin
   if Argument_Count >= 1 then
      Residents := Positive'Value (Argument (1));
   end if;
   Castle.Worldgen.Create (1, W, Report => False);

   --  1. A dry hillside near water, away from the mountains.
   for Gy in 8 .. N / 16 - 9 loop
      for Gx in 8 .. N / 16 - 9 loop
         declare
            X     : constant Integer := Gx * 16;
            Y     : constant Integer := Gy * 16;
            Sum_S : Float   := 0.0;
            Lo    : Float   := 1.0E9;
            Hi    : Float   := -1.0E9;
            Wet   : Boolean := False;
            Cnt   : Natural := 0;
         begin
            for Dy in -10 .. 10 loop
               for Dx in -10 .. 10 loop
                  declare
                     K : constant Cell_Range := Idx (X + 2 * Dx, Y + 2 * Dy);
                  begin
                     Wet   := Wet or else W.Water (K) > 0.0 or else W.Kind (K) /= Dry;
                     Sum_S := Sum_S + W.Slope (K);
                     Lo    := Float'Min (Lo, W.Height (K));
                     Hi    := Float'Max (Hi, W.Height (K));
                     Cnt   := Cnt + 1;
                  end;
               end loop;
            end loop;
            if not Wet then
               declare
                  Mean_S : constant Float := Sum_S / Float (Cnt);
                  Dw     : constant Float := W.Dist_Water (Idx (X, Y));
               begin
                  if Mean_S in 0.06 .. 0.16 and then Hi - Lo <= 5.0
                    and then W.Mountain (Idx (X, Y)) < 0.3 and then Dw in 20.0 .. 120.0
                  then
                     declare
                        Score : constant Float :=
                          -20.0 * abs (Mean_S - 0.10)
                          - Sqrt (Float ((X - N / 2) ** 2 + (Y - N / 2) ** 2)) / 1000.0;
                     begin
                        if Score > Best then
                           Best := Score;
                           Cx   := X;
                           Cy   := Y;
                        end if;
                     end;
                  end if;
               end;
            end if;
         end;
      end loop;
   end loop;

   declare
      Gx : constant Float := At_Cell (W.Height.all, Cx + 4, Cy) - At_Cell (W.Height.all, Cx - 4, Cy);
      Gy : constant Float := At_Cell (W.Height.all, Cx, Cy + 4) - At_Cell (W.Height.all, Cx, Cy - 4);
   begin
      if abs Gx >= abs Gy then
         Up_X := (if Gx > 0.0 then 1.0 else -1.0);
         Up_Y := 0.0;
      else
         Up_X := 0.0;
         Up_Y := (if Gy > 0.0 then 1.0 else -1.0);
      end if;
   end;

   --  2. The pathways: a main way up the slope from the stake and two
   --     branches along it.  Stand-ins for what the player will draw.
   declare
      Sd_X : constant Float := -Up_Y;
      Sd_Y : constant Float := Up_X;
      S0   : constant Point := Pt (Float (Cx) - Up_X * 17.0, Float (Cy) - Up_Y * 17.0);
      function Step (From : Point; Up_M, Side_M : Float) return Point is
        (Pt (From.X + Up_X * Up_M + Sd_X * Side_M, From.Y + Up_Y * Up_M + Sd_Y * Side_M));
      M1 : constant Point := Step (S0, 11.0, 3.0 * Jit (1));
      M2 : constant Point := Step (M1, 11.0, 3.0 * Jit (2));
      M3 : constant Point := Step (M2, 11.0, 3.0 * Jit (3));
      A1 : constant Point := Step (M1, 2.0 * Jit (4), 9.0);
      A2 : constant Point := Step (A1, 3.0 * Jit (5), 8.0);
      B1 : constant Point := Step (M2, 2.0 * Jit (6), -9.0);
      B2 : constant Point := Step (B1, 3.0 * Jit (7), -8.0);
   begin
      Net.Count := 3;
      Net.Ways (1).Count := 4;
      Net.Ways (1).Pts (1 .. 4) := (S0, M1, M2, M3);
      Net.Ways (1).Width := 2.0;
      Net.Ways (2).Count := 3;
      Net.Ways (2).Pts (1 .. 3) := (M1, A1, A2);
      Net.Ways (2).Width := 1.5;
      Net.Ways (2).Start_Dist := Dist (S0, M1);
      Net.Ways (3).Count := 3;
      Net.Ways (3).Pts (1 .. 3) := (M2, B1, B2);
      Net.Ways (3).Width := 1.5;
      Net.Ways (3).Start_Dist := Dist (S0, M1) + Dist (M1, M2);
   end;

   --  3. Zone the network, build, render.
   declare
      Lo_X : Float := 1.0E9;
      Lo_Y : Float := 1.0E9;
      Hi_X : Float := -1.0E9;
      Hi_Y : Float := -1.0E9;
   begin
      for K in 1 .. Net.Count loop
         for I in 1 .. Net.Ways (K).Count loop
            Lo_X := Float'Min (Lo_X, Net.Ways (K).Pts (I).X);
            Lo_Y := Float'Min (Lo_Y, Net.Ways (K).Pts (I).Y);
            Hi_X := Float'Max (Hi_X, Net.Ways (K).Pts (I).X);
            Hi_Y := Float'Max (Hi_Y, Net.Ways (K).Pts (I).Y);
         end loop;
      end loop;
      declare
         Mid_X : constant Integer := Integer ((Lo_X + Hi_X) * 2.0);   --  centre, blocks
         Mid_Y : constant Integer := Integer ((Lo_Y + Hi_Y) * 2.0);
         R0x   : constant Integer := ((Mid_X - 112) / Chunk_B) * Chunk_B;
         R0y   : constant Integer := ((Mid_Y - 112) / Chunk_B) * Chunk_B;
         Zx0   : constant Integer := Integer'Max (R0x + 8, Integer ((Lo_X - 9.0) * 4.0));
         Zy0   : constant Integer := Integer'Max (R0y + 8, Integer ((Lo_Y - 9.0) * 4.0));
         Zx1   : constant Integer := Integer'Min (R0x + 216, Integer ((Hi_X + 9.0) * 4.0));
         Zy1   : constant Integer := Integer'Min (R0y + 216, Integer ((Hi_Y + 9.0) * 4.0));
         Vox   : constant Castle.Iso.Grid_Access :=
           new Castle.Iso.Grid (R0x .. R0x + 223, R0y .. R0y + 223, 0 .. Height_B - 1);
         Work  : Stack_Work_Access := new Stack_Work;
         Trees, Logs : Natural := 0;
         Blocks      : Natural := 0;
         Trim_Blocks : Natural := 0;
         Cut_T, Fill_T : Natural := 0;
         Doors : array (1 .. 3) of Natural := (others => 0);   --  middle, left, right
         Windows, Woodpiles : Natural := 0;
         Min_A : Integer := Integer'Last;
         Max_A : Integer := 0;
         Path_Cells : Natural := 0;

         --  Felled for the village: anything rooted within 2.5 m of a house
         --  or on a pathway.
         function Felled (Bx, By : Integer) return Boolean is
         begin
            for Dy in -10 .. 10 loop
               for Dx in -10 .. 10 loop
                  if Bx + Dx in P.Occ'Range (1) and then By + Dy in P.Occ'Range (2) then
                     declare
                        O : constant Integer := P.Occ (Bx + Dx, By + Dy);
                     begin
                        if O > 0 or else (abs Dx <= 2 and then abs Dy <= 2 and then O < 0) then
                           return True;
                        end if;
                     end;
                  end if;
               end loop;
            end loop;
            return False;
         end Felled;

         procedure Set (Bx, By, Bz : Integer; M : Material) is
         begin
            if Bx in Vox'Range (1) and then By in Vox'Range (2) and then Bz in 1 .. Height_B - 1 then
               Vox (Bx, By, Bz) := M;
            end if;
         end Set;

         procedure Earth (Bx, By, Old_Top, New_Top : Integer) is
         begin
            for Z in Integer'Min (Old_Top, New_Top) .. Integer'Max (Old_Top, New_Top) + 3 loop
               Set (Bx, By, Z, (if Z < New_Top then Dirt else Air));
            end loop;
            Set (Bx, By, New_Top - 1, Dirt);
         end Earth;

         procedure Place (Bx, By, Bz : Integer; M : Material; S : Stage) is
         begin
            if M /= Air then
               Blocks := Blocks + 1;
               if S = Trim then
                  Trim_Blocks := Trim_Blocks + 1;
               end if;
            end if;
            Set (Bx, By, Bz, M);
         end Place;

         procedure Prepare is new Level (Earth);
         procedure Build is new Blueprint (Place);
      begin
         Lay_Out (W, Net, Zx0, Zy0, Zx1, Zy1, Residents, P);

         for J in Floor_Div (Zy0 - 24, Tree_Cell) .. Floor_Div (Zy1 + 24, Tree_Cell) loop
            for I in Floor_Div (Zx0 - 24, Tree_Cell) .. Floor_Div (Zx1 + 24, Tree_Cell) loop
               declare
                  T : constant Tree := Tree_At (W, I, J);
               begin
                  if T.Valid and then Felled (T.Bx, T.By) then
                     Trees := Trees + 1;
                     Logs  := Logs + (T.Trunk_H + 3) * T.Trunk_W * T.Trunk_W;
                  end if;
               end;
            end loop;
         end loop;

         for CX in R0x / Chunk_B .. R0x / Chunk_B + 6 loop
            for CY in R0y / Chunk_B .. R0y / Chunk_B + 6 loop
               Generate (W, CX, CY, Work.all, Felled'Access);
               for LX in 0 .. Chunk_B - 1 loop
                  for LY in 0 .. Chunk_B - 1 loop
                     for Z in 0 .. Height_B - 1 loop
                        Vox (CX * Chunk_B + LX, CY * Chunk_B + LY, Z) := Work.G (LX, LY, Z).Mat;
                     end loop;
                  end loop;
               end loop;
            end loop;
         end loop;
         Free (Work);

         for K in 1 .. P.Count loop
            Prepare (W, P.Houses (K), K, P.Occ.all);
         end loop;

         --  Pathways and door paths: trodden earth on whatever ground is there now.
         for X in P.Occ'Range (1) loop
            for Y in P.Occ'Range (2) loop
               if P.Occ (X, Y) = Path_Cell or else P.Occ (X, Y) = Door_Cell then
                  Path_Cells := Path_Cells + 1;
                  for Z in reverse 1 .. Height_B - 1 loop
                     if Class_Of (Vox (X, Y, Z)) = Solid then
                        Vox (X, Y, Z) := Footpath;
                        for Za in Z + 1 .. Integer'Min (Height_B - 1, Z + 4) loop
                           Vox (X, Y, Za) := Air;
                        end loop;
                        exit;
                     end if;
                  end loop;
               end if;
            end loop;
         end loop;

         for K in 1 .. P.Count loop
            declare
               H : House renames P.Houses (K);
            begin
               Build (H);
               Cut_T  := Cut_T + H.Cut;
               Fill_T := Fill_T + H.Fill;
               Windows := Windows + H.Open_N - 1;
               if H.Woodpile /= 0 then
                  Woodpiles := Woodpiles + 1;
               end if;
               Doors ((if H.Openings (1).Offset = H.W / 2 - Door_W_B / 2 then 1
                       elsif H.Openings (1).Offset = 2 then 2 else 3)) :=
                 Doors ((if H.Openings (1).Offset = H.W / 2 - Door_W_B / 2 then 1
                         elsif H.Openings (1).Offset = 2 then 2 else 3)) + 1;
               Min_A := Integer'Min (Min_A, (H.W - 2) * (H.D - 2));
               Max_A := Integer'Max (Max_A, (H.W - 2) * (H.D - 2));
            end;
         end loop;

         declare   --  the stake, beside the start of the main way
            Sx : constant Integer := Integer (Net.Ways (1).Pts (1).X * 4.0) + Integer (-Up_Y * 8.0);
            Sy : constant Integer := Integer (Net.Ways (1).Pts (1).Y * 4.0) + Integer (Up_X * 8.0);
         begin
            for Z in Surface_B (W, Sx, Sy) .. Surface_B (W, Sx, Sy) + 11 loop
               Set (Sx, Sy, Z, Log);
            end loop;
         end;

         declare
            Z_Lo : Integer := Height_B - 1;
            Z_Hi : Integer := 0;
         begin
            for X in Vox'Range (1) loop
               for Y in Vox'Range (2) loop
                  Z_Lo := Integer'Min (Z_Lo, Surface_B (W, X, Y));
                  for Z in reverse 0 .. Height_B - 1 loop
                     if Vox (X, Y, Z) /= Air then
                        Z_Hi := Integer'Max (Z_Hi, Z);
                        exit;
                     end if;
                  end loop;
               end loop;
            end loop;
            declare
               Flip : constant Boolean := Up_X > 0.0 or else Up_Y > 0.0;   --  look up the slope
               Pic  : Image_Access :=
                 Castle.Iso.Render (Vox.all, Natural (Integer'Max (1, Z_Lo - 6)), Natural (Z_Hi),
                                    W.Seed, Flip_X => Flip, Flip_Y => Flip);
            begin
               if not Ada.Directories.Exists ("preview") then
                  Ada.Directories.Create_Path ("preview");
               end if;
               Write ("preview/village.png", Pic.all);
               Free (Pic);
            end;

            --  Close-up of the first houses built, 24 m across at 8 px per block.
            declare
               K_N : constant Positive := Positive'Max (1, Integer'Min (3, P.Count));
               Sx  : Integer := 0;
               Sy  : Integer := 0;
            begin
               for K in 1 .. K_N loop
                  declare
                     H : House renames P.Houses (K);
                  begin
                     Sx := Sx + H.Fx + (H.W / 2) * H.Ux + (H.D / 2) * H.Vx;
                     Sy := Sy + H.Fy + (H.W / 2) * H.Uy + (H.D / 2) * H.Vy;
                  end;
               end loop;
               Sx := Sx / K_N;
               Sy := Sy / K_N;
               declare
                  Cx0  : constant Integer :=
                    Integer'Max (Vox'First (1), Integer'Min (Vox'Last (1) - 95, Sx - 48));
                  Cy0  : constant Integer :=
                    Integer'Max (Vox'First (2), Integer'Min (Vox'Last (2) - 95, Sy - 48));
                  Sub  : constant Castle.Iso.Grid_Access :=
                    new Castle.Iso.Grid (Cx0 .. Cx0 + 95, Cy0 .. Cy0 + 95, 0 .. Height_B - 1);
                  S_Lo : Integer := Height_B - 1;
                  S_Hi : Integer := 0;
               begin
                  for X in Sub'Range (1) loop
                     for Y in Sub'Range (2) loop
                        S_Lo := Integer'Min (S_Lo, Surface_B (W, X, Y));
                        for Z in Sub'Range (3) loop
                           Sub (X, Y, Z) := Vox (X, Y, Z);
                           if Vox (X, Y, Z) /= Air then
                              S_Hi := Integer'Max (S_Hi, Z);
                           end if;
                        end loop;
                     end loop;
                  end loop;
                  declare
                     Flip : constant Boolean := Up_X > 0.0 or else Up_Y > 0.0;
                     Pic  : Image_Access :=
                       Castle.Iso.Render (Sub.all, Natural (Integer'Max (1, S_Lo - 4)), Natural (S_Hi),
                                          W.Seed, Flip_X => Flip, Flip_Y => Flip, Scale => 8);
                  begin
                     Write ("preview/village_close.png", Pic.all);
                     Free (Pic);
                  end;
               end;
            end;
         end;

         Put_Line ("site (" & Img (Cx) & "," & Img (Cy) & "), zone "
                   & Img (Float (Zx1 - Zx0) / 4.0, 1) & " x " & Img (Float (Zy1 - Zy0) / 4.0, 1)
                   & " m; pathways: main " & Img (Net.Ways (1).Width, 1) & " m wide, two branches "
                   & Img (Net.Ways (2).Width, 1) & " m; " & Img (Float (Path_Cells) / 16.0, 0)
                   & " m^2 of path incl. door paths");
         Put_Line ("houses: " & Img (P.Count) & " of " & Img (Residents) & ", shared walls "
                   & Img (P.Shared) & ", floor " & Img (Float (Min_A) / 16.0, 1) & " .. "
                   & Img (Float (Max_A) / 16.0, 1) & " m^2");
         Put_Line ("doors: middle " & Img (Doors (1)) & ", near left corner " & Img (Doors (2))
                   & ", near right corner " & Img (Doors (3)) & "; windows " & Img (Windows)
                   & "; woodpiles " & Img (Woodpiles));
         Put_Line ("felled for the village: " & Img (Trees) & " trees (" & Img (Logs) & " log blocks)");
         Put_Line ("all houses: " & Img (Blocks) & " blocks, " & Img (Trim_Blocks) & " of them log trim, = "
                   & Img (Float (Blocks) * Wood_Per_Block, 0) & " wood; site work cut "
                   & Img (Float (Cut_T) / 64.0, 1) & " m^3, fill " & Img (Float (Fill_T) / 64.0, 1) & " m^3");
         Put_Line ("build order (walking distance from the stake):");
         for K in 1 .. P.Count loop
            declare
               H : House renames P.Houses (K);
            begin
               Put_Line ("  " & Img (K) & ": " & Img (H.Dist, 1) & " m, "
                         & Img (Float (H.W) / 4.0, 2) & " x " & Img (Float (H.D) / 4.0, 2) & " m"
                         & (if H.Ridge_Along_U then ", eave" else ", gable") & " to the path"
                         & (if H.Shared_Left or else H.Shared_Right then ", shares a wall" else "")
                         & ", " & Img (H.Open_N - 1) & " window(s)");
            end;
         end loop;
      end;
   end;
end Village_Preview;
