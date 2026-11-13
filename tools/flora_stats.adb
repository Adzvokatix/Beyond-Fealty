with Ada.Command_Line;  use Ada.Command_Line;
with Ada.Text_IO;       use Ada.Text_IO;
with Castle.Dims;       use Castle.Dims;
with Castle.Hash;       use type Castle.Hash.U64;
with Castle.Maps;
with Castle.Worldgen;
with Castle.Flora;      use Castle.Flora;
with Castle.Blocks;      use type Castle.Blocks.Material;
with Castle.Geology;

--  What the generator plants, counted over the whole map, for tuning
--  Castle.Flora: trees by species, berry bushes, how much of the land is
--  forest and how thick it stands there, lone trees out in the open, and
--  what grows within 60 m of a spot (by default 1178 1078 on seed 1, the
--  homestake the reference run uses), wild vegetables too (as the
--  ground cover has them, before trees and bushes stand on some).
--    flora_stats [SEED [X Y]]
procedure Flora_Stats is
   W    : Castle.Maps.World;
   Seed : Castle.Hash.U64 := 1;
   Sx   : Float := 1178.0;
   Sy   : Float := 1078.0;

   Forest_Line : constant Float := 0.5;    --  a cell whose forest density is at least this is "in forest"
   Open_Line   : constant Float := 0.05;   --  below this, open land; between the two, a forest's edge

   type Per_Species is array (Species) of Natural;
   In_Forest, In_Edge, In_Open, Near : Per_Species := [others => 0];
   Forest_Cells, Edge_Cells, Open_Cells : Natural := 0;
   Bushes, Bushes_Near : Natural := 0;
   Nearest : array (Species) of Tree;           --  the nearest of each kind to the spot
   Nearest_D : array (Species) of Float := [others => Float'Last];
   Sampled   : array (Species) of Natural := [others => 0];   --  trees drawn alone, for their reach
   Reach_Out, Reach_Up : array (Species) of Integer := [others => 0];
   Blocks_Of : array (Species) of Natural := [others => 0];
   Through   : array (Species) of Natural := [others => 0];   --  branch blocks inside a neighbour's trunk
   Low_Wood  : array (Species) of Natural := [others => 0];   --  bark off the trunk within a serf's height of the ground
   Shape_Sum : Castle.Hash.U64 := 0;                          --  every block of every tree drawn alone, hashed
   Too_Far   : Boolean := False;
   Cur       : Tree;

   --  How far a tree drawn alone (Tree_Blocks, as felling draws it) reaches
   --  out from its trunk and up above its top: crowns must stay inside the
   --  generator's reach (20 blocks) or felling and stack edges cut them.
   procedure Measure (Bx, By, Bz : Integer; M : Castle.Blocks.Material) is
   begin
      Reach_Out (Cur.Kind) := Integer'Max (Reach_Out (Cur.Kind),
                                           Integer'Max (Integer'Max (Cur.Bx - Bx, Bx - (Cur.Bx + Cur.Trunk_W - 1)),
                                                        Integer'Max (Cur.By - By, By - (Cur.By + Cur.Trunk_W - 1))));
      Reach_Up (Cur.Kind) := Integer'Max (Reach_Up (Cur.Kind), Bz - (Cur.Bz + Cur.Trunk_H));
      Blocks_Of (Cur.Kind) := Blocks_Of (Cur.Kind) + 1;
      Shape_Sum := Castle.Hash.Mix (Shape_Sum xor Castle.Hash.Hash_2 (Castle.Hash.U64 (Castle.Blocks.Material'Pos (M) + 1),
                                                                      Bx * 4096 + By, Bz));
      if M in Castle.Blocks.Trunk and then Bz >= Cur.Bz and then Bz < Cur.Bz + 7
        and then not (Bx in Cur.Bx .. Cur.Bx + Cur.Trunk_W - 1 and then By in Cur.By .. Cur.By + Cur.Trunk_W - 1)
      then
         Low_Wood (Cur.Kind) := Low_Wood (Cur.Kind) + 1;
      end if;
      --  A branch of this tree through a neighbour's trunk of the same bark:
      --  felling this tree (which takes every block of its own shape the
      --  world still holds as that material) would cut that trunk.
      if M in Castle.Blocks.Trunk
        and then not (Bx in Cur.Bx .. Cur.Bx + Cur.Trunk_W - 1 and then By in Cur.By .. Cur.By + Cur.Trunk_W - 1)
        and then Bx >= 0 and then By >= 0
      then
         declare
            N : constant Tree := Tree_At (W, Bx / Tree_Cell, By / Tree_Cell);
         begin
            if N.Valid and then N.Bark = M
              and then Bx in N.Bx .. N.Bx + N.Trunk_W - 1 and then By in N.By .. N.By + N.Trunk_W - 1
              and then Bz in N.Bz - 2 .. N.Bz + N.Trunk_H
            then
               Through (Cur.Kind) := Through (Cur.Kind) + 1;
            end if;
         end;
      end if;
   end Measure;

   function Img (N : Natural) return String is
      S : constant String := N'Image;
   begin
      return S (S'First + 1 .. S'Last);
   end Img;

   function Img (F : Float) return String is
      V : constant Natural := Natural (abs F * 10.0);
   begin
      return Img (V / 10) & "." & Img (V mod 10);
   end Img;

   function Sum (P : Per_Species) return Natural is
      N : Natural := 0;
   begin
      for V of P loop
         N := N + V;
      end loop;
      return N;
   end Sum;

   procedure Show (Label : String; P : Per_Species) is
   begin
      Put (Label & Img (Sum (P)));
      for S in Species loop
         Put ("  " & S'Image & " " & Img (P (S)));
      end loop;
      New_Line;
   end Show;

   function Near_Spot (Bx, By : Integer) return Boolean is
      Dx : constant Float := Center_M (Bx) - Sx;
      Dy : constant Float := Center_M (By) - Sy;
   begin
      return Dx * Dx + Dy * Dy <= 60.0 * 60.0;
   end Near_Spot;
begin
   if Argument_Count >= 1 then
      Seed := Castle.Hash.U64'Value (Argument (1));
   end if;
   if Argument_Count >= 3 then
      Sx := Float'Value (Argument (2));
      Sy := Float'Value (Argument (3));
   end if;
   Castle.Worldgen.Create (Seed, W, Report => False);

   for J in 0 .. Size_B / Tree_Cell - 1 loop
      for I in 0 .. Size_B / Tree_Cell - 1 loop
         declare
            Cx : constant Integer := I * Tree_Cell + Tree_Cell / 2;
            Cy : constant Integer := J * Tree_Cell + Tree_Cell / 2;
            F  : constant Float := Forest_Density (W, Center_M (Cx), Center_M (Cy));
            T  : constant Tree := Tree_At (W, I, J);
         begin
            if F >= Forest_Line then
               Forest_Cells := Forest_Cells + 1;
            elsif F >= Open_Line then
               Edge_Cells := Edge_Cells + 1;
            else
               Open_Cells := Open_Cells + 1;
            end if;
            if T.Valid then
               if F >= Forest_Line then
                  In_Forest (T.Kind) := In_Forest (T.Kind) + 1;
               elsif F >= Open_Line then
                  In_Edge (T.Kind) := In_Edge (T.Kind) + 1;
               else
                  In_Open (T.Kind) := In_Open (T.Kind) + 1;
               end if;
               if Near_Spot (T.Bx, T.By) then
                  Near (T.Kind) := Near (T.Kind) + 1;
               end if;
               if Sampled (T.Kind) < 3_000 and then (I + J) mod 7 = 0 then
                  Sampled (T.Kind) := Sampled (T.Kind) + 1;
                  Cur := T;
                  Tree_Blocks (T, Measure'Access);
               end if;
               declare
                  Dx : constant Float := Center_M (T.Bx) - Sx;
                  Dy : constant Float := Center_M (T.By) - Sy;
               begin
                  if Dx * Dx + Dy * Dy < Nearest_D (T.Kind) then
                     Nearest_D (T.Kind) := Dx * Dx + Dy * Dy;
                     Nearest (T.Kind) := T;
                  end if;
               end;
            end if;
         end;
      end loop;
   end loop;

   for J in 0 .. Size_B / Bush_Cell - 1 loop
      for I in 0 .. Size_B / Bush_Cell - 1 loop
         declare
            L : constant Lump := Bush_At (W, I, J);
         begin
            if L.Valid then
               Bushes := Bushes + 1;
               if Near_Spot (L.Cx, L.Cy) then
                  Bushes_Near := Bushes_Near + 1;
               end if;
            end if;
         end;
      end loop;
   end loop;

   declare
      Cell_Ha : constant Float := Float (Tree_Cell * Tree_Cell) / 16.0 / 10_000.0;   --  hectares a cell
      Forest_Ha : constant Float := Float (Forest_Cells) * Cell_Ha;
      Edge_Ha   : constant Float := Float (Edge_Cells) * Cell_Ha;
      Open_Ha   : constant Float := Float (Open_Cells) * Cell_Ha;
   begin
      Put_Line ("seed" & Seed'Image & ", tree cell" & Tree_Cell'Image & " blocks, bush cell" & Bush_Cell'Image
                & " blocks");
      Put_Line ("forest (density >= 0.5): " & Img (Integer (Forest_Ha)) & " ha of "
                & Img (Integer (Forest_Ha + Edge_Ha + Open_Ha)) & " ha, "
                & Img (100.0 * Forest_Ha / (Forest_Ha + Edge_Ha + Open_Ha)) & " %; edges (0.05 to 0.5) "
                & Img (Integer (Edge_Ha)) & " ha; open (under 0.05) " & Img (Integer (Open_Ha)) & " ha");
      Show ("trees in forest: ", In_Forest);
      Put_Line ("  per hectare of forest: " & Img (Float (Sum (In_Forest)) / Float'Max (1.0, Forest_Ha)));
      Show ("trees on forest edges: ", In_Edge);
      Put_Line ("  per hectare of edge: " & Img (Float (Sum (In_Edge)) / Float'Max (1.0, Edge_Ha)));
      Show ("trees in the open: ", In_Open);
      Put_Line ("  per hectare of open land: " & Img (Float (Sum (In_Open)) / Float'Max (1.0, Open_Ha)));
      Put_Line ("berry bushes: " & Img (Bushes));
      Show ("within 60 m of" & Integer (Sx)'Image & Integer (Sy)'Image & ": trees ", Near);
      Put_Line ("  berry bushes " & Img (Bushes_Near));
      --  wild vegetables: every column within 60 m, and one column in 16 x 16 over the map
      declare
         Veg_Near, Veg_Map, Grass_Map : Natural := 0;
         type Patch_Grid is array (-15 .. 15, -15 .. 15) of Natural;   --  4 m cells round the spot
         Patch : Patch_Grid := [others => [others => 0]];
         Best_I, Best_J : Integer := 0;
      begin
         for Bx in Integer (Sx * 4.0) - 240 .. Integer (Sx * 4.0) + 240 loop
            for By in Integer (Sy * 4.0) - 240 .. Integer (Sy * 4.0) + 240 loop
               if Near_Spot (Bx, By) and then Bx in 0 .. Size_B - 1 and then By in 0 .. Size_B - 1
                 and then Castle.Geology.Prepare_Column (W, Bx, By).Plant = Castle.Blocks.Wild_Vegetables
               then
                  Veg_Near := Veg_Near + 1;
                  declare
                     I : constant Integer := Integer'Max (-15, Integer'Min (15, (Bx - Integer (Sx * 4.0)) / 16));
                     J : constant Integer := Integer'Max (-15, Integer'Min (15, (By - Integer (Sy * 4.0)) / 16));
                  begin
                     Patch (I, J) := Patch (I, J) + 1;
                     if Patch (I, J) > Patch (Best_I, Best_J) then
                        Best_I := I;
                        Best_J := J;
                     end if;
                  end;
               end if;
            end loop;
         end loop;
         for Bx in 0 .. Size_B / 16 - 1 loop
            for By in 0 .. Size_B / 16 - 1 loop
               declare
                  C : constant Castle.Geology.Column := Castle.Geology.Prepare_Column (W, Bx * 16 + 7, By * 16 + 7);
               begin
                  if C.Top = Castle.Blocks.Grass then
                     Grass_Map := Grass_Map + 1;
                  end if;
                  if C.Plant = Castle.Blocks.Wild_Vegetables then
                     Veg_Map := Veg_Map + 1;
                  end if;
               end;
            end loop;
         end loop;
         Put_Line ("  wild vegetables " & Img (Veg_Near) & " (" & Img (Float (Veg_Near) / 113.1)
                   & " to 100 m2); the thickest 4 m square near" & Integer (Sx + 4.0 * Float (Best_I) + 2.0)'Image
                   & Integer (Sy + 4.0 * Float (Best_J) + 2.0)'Image & " (" & Img (Patch (Best_I, Best_J)) & ")");
         Put_Line ("wild vegetables over the map: about " & Img (Integer (160_000.0 * Float (Veg_Map)
                                                                        / Float'Max (1.0, Float (Grass_Map))))
                   & " to a hectare of grassland");
      end;
      for S in Species loop
         if Sampled (S) > 0 then
            Put_Line ("  " & S'Image & ": " & Img (Sampled (S)) & " drawn alone, " & Img (Blocks_Of (S) / Sampled (S))
                      & " blocks each; reach" & Reach_Out (S)'Image & " blocks out from the trunk,"
                      & Reach_Up (S)'Image & " above its top (generator reach" & Tree_Reach'Image
                      & "); branch blocks in a neighbour's trunk:" & Through (S)'Image
                      & "; bark off the trunk under 1.75 m:" & Low_Wood (S)'Image);
            if Reach_Out (S) > Tree_Reach or else Reach_Up (S) > Tree_Reach then
               Too_Far := True;
            end if;
         end if;
      end loop;
      Put_Line ("  shapes drawn alone, hashed:" & Shape_Sum'Image);
      --  tall grass: one column in 4 x 4 over the map
      declare
         Turf, Tufts, Long : Natural := 0;
      begin
         for Bx in 0 .. Size_B / 4 - 1 loop
            for By in 0 .. Size_B / 4 - 1 loop
               declare
                  C : constant Castle.Geology.Column := Castle.Geology.Prepare_Column (W, Bx * 4 + 1, By * 4 + 2);
               begin
                  if C.Top = Castle.Blocks.Grass then
                     Turf := Turf + 1;
                     if C.Plant = Castle.Blocks.Tall_Grass then
                        Tufts := Tufts + 1;
                        if C.Plant_H > 1 then
                           Long := Long + 1;
                        end if;
                     end if;
                  end if;
               end;
            end loop;
         end loop;
         Put_Line ("tall grass over the map: a tuft on " & Img (100.0 * Float (Tufts) / Float'Max (1.0, Float (Turf)))
                   & " % of the turf's columns, " & Img (100.0 * Float (Long) / Float'Max (1.0, Float (Tufts)))
                   & " % of them two blocks high");
      end;
      for S in Species loop
         if Nearest (S).Valid then
            Put_Line ("  nearest " & S'Image & " at" & Integer (Center_M (Nearest (S).Bx))'Image
                      & Integer (Center_M (Nearest (S).By))'Image);
         end if;
      end loop;
   end;
   if Too_Far then
      Put_Line ("FAIL: a tree reaches further than the generator looks");
      Set_Exit_Status (Failure);
   end if;
end Flora_Stats;
