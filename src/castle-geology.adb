with Castle.Noise;  use Castle.Noise;
with Castle.Fields; use Castle.Fields;
with Castle.Hash;   use Castle.Hash;
with Castle.Dims;   use Castle.Dims;
with Castle.Deposits;
with Castle.Channels;
with Castle.Jobs;
with Interfaces;
use type Interfaces.Unsigned_64;

package body Castle.Geology is

   package Ch renames Castle.Channels;

   type Stratum is record
      Top       : Float;      --  upper bound, stratigraphic metres
      Mat       : Material;
      Permeable : Boolean;    --  water-bearing below the water table
   end record;

   type Strata_Table is array (Positive range <>) of Stratum;

   --  Stratigraphic metres = height + fold offset.  Data, not code.
   Strata : constant Strata_Table :=
     ((5.5,   Limestone, False),
      (9.5,   Sandstone, True),
      (13.0,  Limestone, False),
      (17.5,  Sandstone, True),
      (1.0E9, Limestone, False));

   function Round_Block (M : Float) return Integer is
     (Floor_I (M * Float (Blocks_Per_Meter) + 0.5));

   function To_Grade (F : Float) return Interfaces.Unsigned_8 is
     (Interfaces.Unsigned_8 (Clamp (F, 0.0, 1.0) * 255.0));

   function Gold_District (W : World; Xm, Ym : Float) return Float is
   begin
      return Smoothstep (0.35, 0.70, Sample (W.Mountain.all, Xm, Ym))
        * Smoothstep (-0.10, 0.30,
                      FBM_2 (W.Ch (Ch.Vein_District), Xm / 260.0, Ym / 260.0, 3));
   end Gold_District;

   ---------------------
   -- Generate_Coarse --
   ---------------------

   procedure Generate_Coarse (W : in out World) is

      procedure Row (J : Integer) is
         Ym : constant Float := (Float (J) + 0.5) * Float (Coarse_M);
      begin
         for I in 0 .. NC - 1 loop
            declare
               Xm : constant Float   := (Float (I) + 0.5) * Float (Coarse_M);
               K  : constant Natural := J * NC + I;
               H  : constant Float   := Sample (W.Height.all, Xm, Ym);
               Mt : constant Float   := Sample (W.Mountain.all, Xm, Ym);
               G0 : constant Float   :=
                 3.0 + 2.5 * FBM_2 (W.Ch (Ch.Granite), Xm / 200.0, Ym / 200.0, 3);
            begin
               W.Fold (K) :=
                 3.0 * FBM_2 (W.Ch (Ch.Fold), Xm / 300.0, Ym / 300.0, 3)
                 + 0.0015 * (Xm - 1024.0);
               W.Granite_Top (K) := G0 + Smoothstep (0.15, 0.75, Mt) * Float'Max (0.0, H - G0 + 1.0);
            end;
         end loop;
      end Row;

      procedure Rows is new Castle.Jobs.Parallel_For (Row);
   begin
      Rows (0, NC - 1, Grain => 4);
   end Generate_Coarse;

   -------------
   -- Aquifer --
   -------------

   function Permeability (Fold, Z, Granite_M : Float) return Float is
   begin
      if Z < Granite_M then
         return 0.15;   --  fractured crystalline rock: a poor aquifer
      end if;
      for K in Strata'Range loop
         if Z + Fold < Strata (K).Top then
            return (if Strata (K).Permeable then 1.0 else 0.1);
         end if;
      end loop;
      return 0.1;
   end Permeability;

   procedure Generate_Aquifer (W : in out World) is

      procedure Row (Y : Integer) is
      begin
         for X in 0 .. N - 1 loop
            declare
               K  : constant Cell_Range := Idx (X, Y);
               Xm : constant Float := Float (X) + 0.5;
               Ym : constant Float := Float (Y) + 0.5;
               H  : constant Float := W.Height (K);
               WT : constant Float := W.Water_Table (K);
            begin
               if W.Water (K) > H then
                  W.Aquifer (K) := 1.0;
               else
                  declare
                     Fd : constant Float := Sample (W.Fold.all, Xm, Ym);
                     Gt : constant Float := Sample (W.Granite_Top.all, Xm, Ym);
                     P  : Float := 0.0;
                  begin
                     for Kz in 0 .. 5 loop   --  the 6 m below the water table
                        declare
                           Z : constant Float := WT - 0.5 - Float (Kz);
                        begin
                           if Z > 1.0 then
                              P := P + Permeability (Fd, Z, Gt);
                           end if;
                        end;
                     end loop;
                     W.Aquifer (K) := Clamp (0.10 + 0.60 * P / 6.0 + 0.30 * W.Moisture (K)
                                             - 0.012 * (H - WT), 0.0, 1.0);
                  end;
               end if;
            end;
         end loop;
      end Row;

      procedure Rows is new Castle.Jobs.Parallel_For (Row);
   begin
      Rows (0, N - 1, 16);
   end Generate_Aquifer;

   procedure Well_Info (W : World; Xm, Ym : Float; Depth_M, Yield : out Float) is
   begin
      Depth_M := Float'Max (0.0, Sample (W.Height.all, Xm, Ym) - Sample (W.Water_Table.all, Xm, Ym));
      Yield   := Sample (W.Aquifer.all, Xm, Ym);
   end Well_Info;

   ---------------
   -- Surface_B --
   ---------------

   function Surface_H (W : World; Xm, Ym : Float) return Float is
     (Sample (W.Height.all, Xm, Ym)
      + 0.12 * Perlin_2 (W.Ch (Ch.Detail), Xm / 2.3, Ym / 2.3));

   function Surface_B (W : World; Bx, By : Integer) return Integer is
   begin
      return Integer'Max
        (2, Integer'Min (Height_B - 2, Round_Block (Surface_H (W, Center_M (Bx), Center_M (By)))));
   end Surface_B;

   -----------------
   -- Water_Level --
   -----------------

   function Water_Level (W : World; Bx, By, Floor, Rows : Integer) return Float is
      Xm  : constant Float := (Float (Bx) + 0.5) / 4.0 - 0.5;
      Ym  : constant Float := (Float (By) + 0.5) / 4.0 - 0.5;
      X0  : constant Integer := Integer (Float'Floor (Xm));
      Y0  : constant Integer := Integer (Float'Floor (Ym));
      Fx  : constant Float := Xm - Float (X0);
      Fy  : constant Float := Ym - Float (Y0);
      Top : constant Float := Float (Floor + Rows);
      Sum, Wt : Float := 0.0;
   begin
      for J in 0 .. 1 loop
         for I in 0 .. 1 loop
            if X0 + I in 0 .. Size_M - 1 and then Y0 + J in 0 .. Size_M - 1 then
               declare
                  K  : constant Cell_Range := Idx (X0 + I, Y0 + J);
                  Wg : constant Float := (if I = 1 then Fx else 1.0 - Fx) * (if J = 1 then Fy else 1.0 - Fy);
               begin
                  if W.Water (K) > W.Height (K) then
                     Sum := Sum + W.Water (K) * Wg;
                     Wt := Wt + Wg;
                  end if;
               end;
            end if;
         end loop;
      end loop;
      if Wt <= 0.0 then
         return Top;
      end if;
      declare
         L : constant Float := Sum / Wt * 4.0;
      begin
         return (if L > Float (Floor) + 0.05 and then L > Top - 1.0 then Float'Min (L, Top) else Top);
      end;
   end Water_Level;

   --------------------
   -- Prepare_Column --
   --------------------

   --  The part of a column that open water decides: its ground top, its
   --  water surface, whether a waterfall raised it, and whether water is near.
   --  The containment rule in Prepare_Column needs only this of a neighbour.
   procedure Water_Part
     (W : World; Xm, Ym, H : Float; C : in out Column; WK : out Water_Kind; Shore_Near : out Boolean)
   is
      WL : Float := 0.0;
   begin
      WK := Dry;
      Shore_Near := False;
      C.Solid := Integer'Max (2, Integer'Min (Height_B - 2, Round_Block (H)));

      --  Open water: the bilinear blend of the levels of whichever of the
      --  four neighbour cells are wet, so shorelines follow the interpolated
      --  terrain and a creek's level steps down smoothly between cells.
      --  (The highest neighbour level used to win, which on a slope floods
      --  every block column with the level of the cell uphill of it.)
      declare
         I0   : constant Integer := Floor_I (Xm - 0.5);
         J0   : constant Integer := Floor_I (Ym - 0.5);
         Fx   : constant Float   := Xm - 0.5 - Float (I0);
         Fy   : constant Float   := Ym - 0.5 - Float (J0);
         Sum  : Float := 0.0;
         Wsum : Float := 0.0;
         Best : Float := 0.0;
      begin
         for DJ in 0 .. 1 loop
            for DI in 0 .. 1 loop
               declare
                  K  : constant Natural := Idx (Clamp_Cell (I0 + DI), Clamp_Cell (J0 + DJ));
                  Wt : constant Float :=
                    (if DI = 0 then 1.0 - Fx else Fx) * (if DJ = 0 then 1.0 - Fy else Fy) + 1.0E-4;
               begin
                  if W.Kind (K) = Shore then
                     Shore_Near := True;
                  end if;
                  if W.Water (K) > 0.0 then
                     Sum  := Sum + Wt * W.Water (K);
                     Wsum := Wsum + Wt;
                     if Wt > Best then
                        Best := Wt;
                        WK   := W.Kind (K);
                     end if;
                  end if;
               end;
            end loop;
         end loop;
         if Wsum > 0.0 then
            WL := Sum / Wsum;
         end if;
      end;

      C.Water_Top := (if WL > 0.0 then Round_Block (WL) else 0);

      --  Fast water.  A creek running down steep ground keeps a film of
      --  water one block deep over its bed instead of breaking into pools.
      --  (Where the bed dropped more than a metre, the columns at the foot
      --  used to be filled up to the level above as a falling curtain; seen
      --  per 0.25 m column they stood as loose pillars of water.  A fall is
      --  now the water surface itself, drawn as one sheet from the level
      --  above to the level below: see the surface pass in Castle.Render.)
      declare
         I  : constant Integer := Clamp_Cell (Floor_I (Xm));
         J  : constant Integer := Clamp_Cell (Floor_I (Ym));
         Kc : constant Natural := Idx (I, J);
      begin
         for DJ in -1 .. 1 loop
            for DI in -1 .. 1 loop
               if W.Water (Idx (Clamp_Cell (I + DI), Clamp_Cell (J + DJ))) > 0.0 then
                  C.Near_Water := True;
               end if;
            end loop;
         end loop;
         if W.Kind (Kc) in Stream | River and then W.Water (Kc) > 0.0 then
            --  The film lies over the bed only: where the column is below the
            --  water of its own cell or of a channel cell draining into it.
            --  Bank columns stand above both and stay dry.  (The film used to
            --  cover every column of a steep cell, banks included, which left
            --  single water blocks standing on them: 97% of all water that
            --  stood above the ground beside it.)
            declare
               Feed : Float := W.Water (Kc);
            begin
               for DJ in -1 .. 1 loop
                  for DI in -1 .. 1 loop
                     if DI /= 0 or else DJ /= 0 then
                        declare
                           Ku : constant Natural := Idx (Clamp_Cell (I + DI), Clamp_Cell (J + DJ));
                           D  : constant Flow_Dir := W.Down (Ku);
                        begin
                           if D >= 0 and then Dir_DX (D) = -DI and then Dir_DY (D) = -DJ
                             and then W.Kind (Ku) in Stream | River
                           then
                              Feed := Float'Max (Feed, W.Water (Ku));
                           end if;
                        end;
                     end if;
                  end loop;
               end loop;
               if W.Slope (Kc) > 0.25 and then C.Solid < Round_Block (Feed) then
                  C.Water_Top := Integer'Max (C.Water_Top, C.Solid + 1);
                  WK := W.Kind (Kc);
               end if;
            end;
         end if;
      end;
   end Water_Part;

   function Water_Of (W : World; Bx, By : Integer) return Column is
      Xm    : constant Float := Center_M (Bx);
      Ym    : constant Float := Center_M (By);
      C     : Column;
      WK    : Water_Kind;
      Shore : Boolean;
   begin
      Water_Part (W, Xm, Ym, Surface_H (W, Xm, Ym), C, WK, Shore);
      return C;
   end Water_Of;

   function Raw_Column (W : World; Bx, By : Integer) return Column is
      Xm         : constant Float := Center_M (Bx);
      Ym         : constant Float := Center_M (By);
      H          : constant Float := Surface_H (W, Xm, Ym);
      C          : Column;
      WK         : Water_Kind;
      Shore_Near : Boolean;
   begin
      Water_Part (W, Xm, Ym, H, C, WK, Shore_Near);
      C.Moisture  := Sample (W.Moisture.all, Xm, Ym);
      C.Slope     := Sample (W.Slope.all, Xm, Ym);
      C.Soil      := Round_Block (Clamp (1.7 - 1.1 * C.Slope
                                         - 0.06 * Float'Max (0.0, H - 30.0), 0.0, 2.5));

      if C.Water_Top > C.Solid then
         C.Kind := WK;
         case WK is
            when Stream | River =>
               C.Top := Gravel;
               C.Sub := Gravel;
            when others =>
               if C.Water_Top - C.Solid >= 6 then
                  C.Top := Clay;
                  C.Sub := Clay;
               else
                  C.Top := Sand;
                  C.Sub := Sand;
               end if;
         end case;
         C.Soil := Integer'Max (C.Soil, 3);
      elsif C.Soil = 0 then
         C.Top := Air;   --  bare rock: the rock itself is the surface
      elsif Shore_Near then
         C.Kind := Shore;
         C.Top  := Sand;
         C.Sub  := Sand;
      elsif C.Moisture < 0.04 then
         C.Top := Dirt;   --  only the very driest ground is bare; dry grassland stays grass
         C.Sub := Dirt;
      else
         C.Top := Grass;
         C.Sub := Dirt;
      end if;

      --  Ground cover: wild vegetables in patches (roots and greens, a
      --  plant here and there, thickest in the middle of a patch), wild
      --  grain in fertile meadows, grass tufts elsewhere.
      if C.Top = Grass then
         declare
            G      : constant Float := Unit_2 (W.Ch (Ch.Plants), Bx, By);
            Meadow : constant Float :=
              Smoothstep (0.10, 0.40, FBM_2 (W.Ch (Ch.Meadow), Xm / 70.0, Ym / 70.0, 3))
              * Smoothstep (0.25, 0.45, C.Moisture)
              * (1.0 - Smoothstep (0.15, 0.40, C.Slope))
              * (1.0 - Smoothstep (20.0, 26.0, H));
            Veg    : constant Float :=
              Smoothstep (Veg_Edge, Veg_Edge + 0.3, FBM_2 (W.Ch (Ch.Veg_Patch), Xm / 24.0, Ym / 24.0, 2))
              * Smoothstep (0.15, 0.35, C.Moisture)
              * (1.0 - Smoothstep (0.25, 0.50, C.Slope))
              * (1.0 - Smoothstep (24.0, 30.0, H));
         begin
            if Unit_2 (W.Ch (Ch.Veg_Patch) + 1, Bx, By) < Veg_Chance * Veg then
               C.Plant   := Wild_Vegetables;
               C.Plant_H := 1;
            elsif G < 0.6 * Meadow then
               C.Plant   := Wild_Grain;
               C.Plant_H := (if Unit_2 (W.Ch (Ch.Plant_Height), Bx, By) < 0.5 then 2 else 3);
            else
               declare
                  Drift : constant Float :=
                    FBM_2 (W.Ch (Ch.Grass_Drift), Xm / Grass_Drift_M, Ym / Grass_Drift_M, 2);
                  Thick : constant Float := Smoothstep (Grass_Drift_Lo, Grass_Drift_Hi, Drift);
               begin
                  if G < (Grass_Thin + (Grass_Thick - Grass_Thin) * Thick) * (0.55 + 0.9 * C.Moisture) then
                     C.Plant   := Tall_Grass;
                     C.Plant_H :=
                       (if Thick > 0.8 and then Unit_2 (W.Ch (Ch.Plant_Height), Bx, By) < Grass_Long then 2 else 1);
                  end if;
               end;
            end if;
         end;
      end if;

      --  Deposits: loose ore round vein outcrops, and bog iron.
      if W.Index /= null then
         declare
            E : Index_Entry renames W.Index (Index_Of (Xm), Index_Of (Ym));
         begin
            for K in 1 .. E.Count loop
               declare
                  D : Deposit renames W.Deposits (E.Items (K));
               begin
                  case D.Kind is
                     when Coal_Vein | Iron_Vein | Salt_Vein =>
                        if C.Water_Top <= C.Solid then
                           declare
                              F : constant Float := Castle.Deposits.Float_Share (D, Xm, Ym);
                           begin
                              if F > C.Speckle then
                                 C.Speckle     := F;
                                 C.Speckle_Mat := Castle.Deposits.Ore_Of (D.Kind);
                              end if;
                           end;
                        end if;

                     when Bog_Iron_Patch =>
                        if C.Water_Top <= C.Solid then
                           declare
                              T : constant Float := Castle.Deposits.Patch_Thickness (D, Xm, Ym);
                           begin
                              if T >= 0.25 then
                                 C.Bog_Hi := C.Solid - Round_Block (D.Depth);
                                 C.Bog_Lo := C.Bog_Hi - Round_Block (T);
                                 if 0.45 * T / D.Thick > C.Speckle then
                                    C.Speckle     := 0.45 * T / D.Thick;
                                    C.Speckle_Mat := Bog_Iron;
                                 end if;
                              end if;
                           end;
                        end if;
                  end case;
               end;
            end loop;
         end;
      end if;

      --  Where a vein comes up into the skin (its outcrop, or a cliff it
      --  runs behind): the topmost run of vein blocks in the column's top
      --  3 m, at block resolution so the outcrop has a clean edge.
      declare
         Near : Near_Tubes;
      begin
         Castle.Deposits.Gather (W, Xm, Ym, 0.25, Near);
         if Near.Count > 0 then
            declare
               Hi  : Integer  := -1;
               Lo  : Integer  := -1;
               Mat : Material := Air;
            begin
               for Bz in reverse Integer'Max (1, C.Solid - 12) .. C.Solid - 1 loop
                  declare
                     Z   : constant Float := Center_M (Bz);
                     Hit : Natural := 0;
                  begin
                     for T in 1 .. Near.Count loop
                        if Castle.Deposits.Inside (W.Tubes (Near.Ids (T)), Xm, Ym, Z) > 0.0 then
                           Hit := Near.Ids (T);
                           exit;
                        end if;
                     end loop;
                     if Hit > 0 then
                        if Hi < 0 then
                           Hi  := Bz + 1;
                           Mat := Castle.Deposits.Ore_Of (W.Deposits (W.Tubes (Hit).Owner).Kind);
                        end if;
                        Lo := Bz;
                     elsif Hi >= 0 then
                        exit;
                     end if;
                  end;
               end loop;
               if Hi >= 0 then
                  C.Vein_Mat := Mat;
                  C.Vein_Lo  := Lo;
                  C.Vein_Hi  := Hi;
               end if;
            end;
         end if;
      end;

      if C.Vein_Hi >= C.Solid then
         C.Plant   := Air;   --  nothing grows on a bare vein
         C.Plant_H := 0;
      end if;

      return C;
   end Raw_Column;

   --  Water never stands above the ground beside it.  A dry column next to
   --  water held at a surface above its ground is raised to that surface:
   --  it becomes the bank at the water line, so the water's side meets
   --  ground, not air.  The raise stops
   --  at 1 m, inside the rock the stack generator has worked out.  Each
   --  column decides from its own raw neighbours, so every caller (stack
   --  generation, the mesher's edges, rebuilds after edits) sees the same.
   function Prepare_Column (W : World; Bx, By : Integer) return Column is
      C : Column := Raw_Column (W, Bx, By);
   begin
      if C.Near_Water and then C.Water_Top <= C.Solid then
         declare
            Lift : Integer := C.Solid;
         begin
            for D in 0 .. 3 loop
               declare
                  Nx : constant Integer := Bx + (case D is when 0 => 1, when 1 => -1, when others => 0);
                  Ny : constant Integer := By + (case D is when 2 => 1, when 3 => -1, when others => 0);
               begin
                  if Nx in 0 .. Size_B - 1 and then Ny in 0 .. Size_B - 1 then
                     declare
                        N : constant Column := Water_Of (W, Nx, Ny);
                     begin
                        if N.Water_Top > N.Solid then
                           Lift := Integer'Max (Lift, N.Water_Top);
                        end if;
                     end;
                  end if;
               end;
            end loop;
            C.Solid := Integer'Min (Lift, C.Solid + Blocks_Per_Meter);
         end;
      end if;
      return C;
   end Prepare_Column;

   -------------------
   -- Skin_Material --
   -------------------

   function Skin_Material
     (W : World; C : Column; Rock : Brick; Bx, By, Bz : Integer) return Material is
   begin
      if Bz <= 0 then
         return Bedrock;
      elsif Bz >= C.Solid then
         if Bz < C.Water_Top then
            return Water;
         elsif Bz < C.Solid + C.Plant_H then
            return C.Plant;
         else
            return Air;
         end if;
      elsif Bz >= C.Vein_Lo and then Bz < C.Vein_Hi then
         return C.Vein_Mat;    --  a vein cuts through soil and rock alike
      end if;

      declare
         Depth : constant Integer := C.Solid - 1 - Bz;   --  0 = surface block
      begin
         --  Loose ore round a vein's mouth lies on bare rock as well as turf.
         if Depth = 0 and then C.Speckle > 0.0 and then C.Speckle_Mat /= Bog_Iron
           and then Unit_2 (W.Ch (Ch.Bog), Bx, By) < C.Speckle
         then
            return C.Speckle_Mat;
         end if;
         if Depth < C.Soil then
            if Bz >= C.Bog_Lo and then Bz < C.Bog_Hi then
               return Bog_Iron;
            elsif Depth = 0 and then C.Speckle > 0.0
              and then Unit_2 (W.Ch (Ch.Bog), Bx, By) < C.Speckle
            then
               return C.Speckle_Mat;
            elsif Depth = 0 then
               return C.Top;
            else
               return C.Sub;
            end if;
         end if;
      end;

      if Rock.Mat /= Rock.Host then
         return (if Unit_3 (W.Seed, Bx, By, Bz) * 255.0 < Float (Rock.Grade)
                 then Rock.Mat else Rock.Host);
      end if;
      return Rock.Mat;
   end Skin_Material;

   function Top_Material (W : World; C : Column; Bx, By : Integer) return Material is
      Z : constant Integer := C.Solid - 1;
   begin
      if C.Soil > 0 or else (Z >= C.Vein_Lo and then Z < C.Vein_Hi) or else C.Speckle > 0.0 then
         return Skin_Material (W, C, Air_Brick, Bx, By, Z);
      end if;
      return Skin_Material
        (W, C,
         Rock_At (W, Prepare_Brick_Column (W, Bx / Blocks_Per_Meter, By / Blocks_Per_Meter),
                  Z / Blocks_Per_Meter),
         Bx, By, Z);
   end Top_Material;

   --------------------------
   -- Prepare_Brick_Column --
   --------------------------

   function Prepare_Brick_Column (W : World; Mx, My : Integer) return Brick_Column is
      BC : Brick_Column;
      C  : constant Column :=
        Prepare_Column (W, Mx * Blocks_Per_Meter + 2, My * Blocks_Per_Meter + 2);
   begin
      BC.Xm        := Float (Mx) + 0.5;
      BC.Ym        := Float (My) + 0.5;
      BC.Surface_M := Float (C.Solid) / Float (Blocks_Per_Meter);
      BC.Soil_M    := Float (C.Soil) / Float (Blocks_Per_Meter);
      BC.Sub       := C.Sub;
      BC.Fold      := Sample (W.Fold.all, BC.Xm, BC.Ym);
      BC.Granite_M := Sample (W.Granite_Top.all, BC.Xm, BC.Ym);
      BC.WT_M      := Sample (W.Water_Table.all, BC.Xm, BC.Ym);
      Castle.Deposits.Gather (W, BC.Xm, BC.Ym, 1.2, BC.Tubes);
      return BC;
   end Prepare_Brick_Column;

   -------------
   -- Rock_At --
   -------------

   function Water_Bearing (BC : Brick_Column; Mz : Integer) return Boolean is
      Zc : constant Float := Float (Mz) + 0.5;
   begin
      if Mz <= 0 or else Zc < BC.Granite_M then
         return False;
      end if;
      for K in Strata'Range loop
         if Zc + BC.Fold < Strata (K).Top then
            return Strata (K).Permeable and then Zc < BC.WT_M;
         end if;
      end loop;
      return False;
   end Water_Bearing;

   function Rock_At (W : World; BC : Brick_Column; Mz : Integer) return Brick is
      Z0    : constant Float := Float (Mz);
      Zc    : constant Float := Z0 + 0.5;
      Host  : Material := Limestone;
      Best  : Float    := 0.0;
      Ore   : Material := Air;
      Owner : Natural  := 0;
   begin
      if Mz <= 0 then
         return Plain (Bedrock);
      end if;

      if Zc < BC.Granite_M then
         Host := Granite;
      else
         for K in Strata'Range loop
            if Zc + BC.Fold < Strata (K).Top then
               Host := Strata (K).Mat;   --  wet or dry the rock looks the same: the
                                         --  aquifer is a field (Well_Info), not blocks
               exit;
            end if;
         end loop;
      end if;

      --  Veins: how far the brick centre lies inside the nearest tube, with
      --  a little jitter per brick so the walls are ragged, as a share of
      --  the brick.  In a rich tube some bricks are silver or gold instead.
      declare
         Mx : constant Integer := Floor_I (BC.Xm);
         My : constant Integer := Floor_I (BC.Ym);
      begin
         for K in 1 .. BC.Tubes.Count loop
            declare
               T  : Vein_Tube renames W.Tubes (BC.Tubes.Ids (K));
               D  : Deposit renames W.Deposits (T.Owner);
               In_M : constant Float :=
                 Castle.Deposits.Inside (T, BC.Xm, BC.Ym, Zc)
                 + 0.35 * (Unit_3 (D.Seed, Mx, My, Mz) - 0.5);
               F  : constant Float := Float'Max (0.0, Float'Min (1.0, In_M + 0.5));
            begin
               if F > Best then
                  Best  := F;
                  Owner := T.Owner;
                  Ore   := Castle.Deposits.Ore_Of (D.Kind);
                  if T.Silver + T.Gold > 0.0 then
                     declare
                        U : constant Float := Unit_3 (D.Seed + 1, Mx, My, Mz);
                     begin
                        if U < T.Gold then
                           Ore := Gold_Ore;
                        elsif U < T.Gold + T.Silver then
                           Ore := Silver_Ore;
                        end if;
                     end;
                  end if;
               end if;
            end;
         end loop;
      end;

      if Best >= 0.04 then
         return (Mat => Ore, Host => Host, Grade => To_Grade (Best),
                 Deposit => Interfaces.Unsigned_8 (Owner));
      end if;
      return Plain (Host);
   end Rock_At;

   function Brick_At (BC : Brick_Column; Mz : Integer; Rock : Brick) return Brick is
      Zc : constant Float := Float (Mz) + 0.5;
   begin
      if Mz <= 0 then
         return Plain (Bedrock);
      elsif Zc >= BC.Surface_M then
         return Air_Brick;
      elsif BC.Surface_M - Zc < BC.Soil_M then
         return Plain (BC.Sub);
      else
         return Rock;
      end if;
   end Brick_At;

   function Deep_Brick (W : World; Mx, My, Mz : Integer) return Brick is
      BC : constant Brick_Column := Prepare_Brick_Column (W, Mx, My);
   begin
      return Brick_At (BC, Mz, Rock_At (W, BC, Mz));
   end Deep_Brick;

end Castle.Geology;
