with Ada.Text_IO;                       use Ada.Text_IO;
with Ada.Unchecked_Deallocation;
with Ada.Real_Time;                     use Ada.Real_Time;
with Ada.Numerics.Elementary_Functions; use Ada.Numerics.Elementary_Functions;
with Interfaces;                        use Interfaces;
with Castle.Blocks;                     use Castle.Blocks;
with Castle.Chunks;                     use Castle.Chunks;
with Castle.Colors;
with Castle.Deposits;
with Castle.Dims;                       use Castle.Dims;
with Castle.Fields;                     use Castle.Fields;
with Castle.Flora;                      use Castle.Flora;
with Castle.Geology;                    use Castle.Geology;
with Castle.Hash;                       use Castle.Hash;
with Castle.Jobs;
with Castle.Maps;                       use Castle.Maps;
with Castle.Noise;                      use Castle.Noise;
with Castle.PNG;                        use Castle.PNG;
with Castle.Text;                       use Castle.Text;

package body Castle.Preview is

   type Col is record
      R, G, B : Float;
   end record;

   function To_Col (C : Castle.Colors.RGB) return Col is
     (Col'(Float (C.R), Float (C.G), Float (C.B)));

   function To_RGB (C : Col) return RGB is
     (RGB'(R => Unsigned_8 (Clamp (C.R, 0.0, 255.0)),
           G => Unsigned_8 (Clamp (C.G, 0.0, 255.0)),
           B => Unsigned_8 (Clamp (C.B, 0.0, 255.0))));

   function Scale (C : Col; S : Float) return Col is (Col'(C.R * S, C.G * S, C.B * S));

   function Blend (A, B : Col; T : Float) return Col is
     (Col'(A.R + (B.R - A.R) * T, A.G + (B.G - A.G) * T, A.B + (B.B - A.B) * T));

   function Color_Of (M : Material) return Col is (To_Col (Base_Color (M)));

   function Jitter (Seed : U64; X, Y, Z : Integer) return Float is
     (0.92 + 0.16 * Unit_3 (Seed, X, Y, Z));

   function Shade (W : World; X, Y : Integer) return Float is
      Gx  : constant Float := At_Cell (W.Height.all, X + 1, Y) - At_Cell (W.Height.all, X - 1, Y);
      Gy  : constant Float := At_Cell (W.Height.all, X, Y + 1) - At_Cell (W.Height.all, X, Y - 1);
      Len : constant Float := Sqrt (Gx * Gx + Gy * Gy + 1.0);
   begin
      --  Light from the north-west, 45 degrees up; slopes exaggerated 2x.
      return 0.30 + Float'Max (0.0, (0.5 * Gx - 0.5 * Gy + 0.7071) / Len);
   end Shade;

   procedure Fill (Pic : in out Image; C : Col) is
   begin
      for R in Pic'Range (1) loop
         for K in Pic'Range (2) loop
            Pic (R, K) := To_RGB (C);
         end loop;
      end loop;
   end Fill;

   procedure Disc
     (Pic : in out Image; Cx, Cy, R : Float; Base : Col;
      Lo_X : Integer := 0; Hi_X : Integer := Integer'Last)
   is
      Rr : constant Float   := Float'Max (R, 0.7);
      H  : constant Integer := Pic'Length (1);
   begin
      for Py in Floor_I (Cy - Rr) .. Floor_I (Cy + Rr) loop
         for Px in Floor_I (Cx - Rr) .. Floor_I (Cx + Rr) loop
            if Px in Pic'Range (2) and then Px >= Lo_X and then Px <= Hi_X
              and then (H - 1 - Py) in Pic'Range (1)
            then
               declare
                  Dx : constant Float := (Float (Px) + 0.5 - Cx) / Rr;
                  Dy : constant Float := (Float (Py) + 0.5 - Cy) / Rr;
                  D2 : constant Float := Dx * Dx + Dy * Dy;
               begin
                  if D2 <= 1.0 then
                     Pic (H - 1 - Py, Px) :=
                       To_RGB (Scale (Base, 0.55 + 0.6 * Float'Max
                         (0.0, -0.5 * Dx + 0.5 * Dy + 0.7071 * Sqrt (1.0 - D2))));
                  end if;
               end;
            end if;
         end loop;
      end loop;
   end Disc;

   --  Trees, bushes and boulders of the block window X0 .. X0 + Span - 1,
   --  drawn Scale_P pixels per block, Off pixels from the left.
   procedure Draw_Features
     (W : World; Pic : in out Image; X0, Y0, Span : Integer; Scale_P : Float; Off : Integer)
   is
      Hi_X : constant Integer := Off + Integer (Float (Span) * Scale_P) - 1;

      function Px (B : Float) return Float is (Float (Off) + (B - Float (X0)) * Scale_P);
      function Py (B : Float) return Float is ((B - Float (Y0)) * Scale_P);
   begin
      for J in Floor_Div (Y0 - 8, Rock_Cell) .. Floor_Div (Y0 + Span + 8, Rock_Cell) loop
         for I in Floor_Div (X0 - 8, Rock_Cell) .. Floor_Div (X0 + Span + 8, Rock_Cell) loop
            declare
               L : constant Lump := Boulder_At (W, I, J);
            begin
               if L.Valid then
                  Disc (Pic, Px (Float (L.Cx) + 0.5), Py (Float (L.Cy) + 0.5),
                        (Float (L.Rh) + 1.0) * Scale_P, (124.0, 122.0, 120.0), Off, Hi_X);
               end if;
            end;
         end loop;
      end loop;
      for J in Floor_Div (Y0 - 24, Tree_Cell) .. Floor_Div (Y0 + Span + 24, Tree_Cell) loop
         for I in Floor_Div (X0 - 24, Tree_Cell) .. Floor_Div (X0 + Span + 24, Tree_Cell) loop
            declare
               T : constant Tree := Tree_At (W, I, J);
            begin
               if T.Valid then
                  Disc (Pic,
                        Px (Float (T.Bx) + 0.5 * Float (T.Trunk_W)),
                        Py (Float (T.By) + 0.5 * Float (T.Trunk_W)),
                        Float (T.Crown_R) * Scale_P * (if T.Kind = Spruce then 0.8 else 1.0),
                        (if T.Kind = Apple then To_Col (Castle.Colors.Of_Hex (Castle.Colors.Brightened_Crimson))
                         else To_Col (Base_Color (T.Leaf))),
                        Off, Hi_X);
               end if;
            end;
         end loop;
      end loop;
      for J in Floor_Div (Y0 - 6, Bush_Cell) .. Floor_Div (Y0 + Span + 6, Bush_Cell) loop
         for I in Floor_Div (X0 - 6, Bush_Cell) .. Floor_Div (X0 + Span + 6, Bush_Cell) loop
            declare
               L : constant Lump := Bush_At (W, I, J);
            begin
               if L.Valid then
                  Disc (Pic, Px (Float (L.Cx) + 0.5), Py (Float (L.Cy) + 0.5),
                        (Float (L.Rh) + 0.5) * Scale_P, (150.0, 50.0, 70.0), Off, Hi_X);
               end if;
            end;
         end loop;
      end loop;
   end Draw_Features;

   function Vein_Color (D : Deposit) return Col is
     (case D.Kind is
         when Coal_Vein      => (18.0, 18.0, 22.0),
         when Iron_Vein      => (205.0, 70.0, 45.0),
         when Salt_Vein      => (252.0, 244.0, 248.0),
         when Bog_Iron_Patch => (235.0, 135.0, 25.0));

   Gold_C   : constant Col := (255.0, 210.0, 30.0);
   Silver_C : constant Col := (150.0, 210.0, 255.0);

   --  The coal and iron veins to show: gold first, then silver, then size.
   procedure Pick_Veins (W : World; Coal_I, Iron_I : out Natural) is
      Best_C, Best_I : Float := -1.0;
   begin
      Coal_I := 0;
      Iron_I := 0;
      for K in W.Deposits'Range loop
         declare
            D     : Deposit renames W.Deposits (K);
            Score : constant Float :=
              (if D.Gold_Vol > 0.0 then 2.0E6 elsif D.Silver_Vol > 0.0 then 1.0E6 else 0.0)
              + D.Reserves;
         begin
            if D.Kind = Coal_Vein and then Score > Best_C then
               Best_C := Score;
               Coal_I := K;
            elsif D.Kind = Iron_Vein and then Score > Best_I then
               Best_I := Score;
               Iron_I := K;
            end if;
         end;
      end loop;
   end Pick_Veins;

   -----------------
   -- Terrain_Map --
   -----------------

   procedure Terrain_Map (W : World; Path : String) is
      Pic : Image_Access := new Image (0 .. N - 1, 0 .. N - 1);

      procedure Row (Y : Integer) is
      begin
         for X in 0 .. N - 1 loop
            declare
               Bx : constant Integer := X * Blocks_Per_Meter + 2;
               By : constant Integer := Y * Blocks_Per_Meter + 2;
               C  : constant Column  := Prepare_Column (W, Bx, By);
               Cl : Col;
            begin
               if C.Water_Top > C.Solid then
                  Cl := Scale (Blend ((90.0, 150.0, 198.0), (20.0, 50.0, 102.0),
                                      Clamp (Float (C.Water_Top - C.Solid) / 10.0, 0.0, 1.0)),
                               0.85 + 0.15 * Shade (W, X, Y));
               else
                  declare
                     M : Material := Top_Material (W, C, Bx, By);
                  begin
                     if C.Plant = Wild_Grain and then M = Grass then
                        M := Wild_Grain;
                     end if;
                     Cl := Scale (Color_Of (M), Shade (W, X, Y));
                  end;
               end if;
               Pic (N - 1 - Y, X) := To_RGB (Cl);
            end;
         end loop;
      end Row;

      procedure Rows is new Castle.Jobs.Parallel_For (Row);
   begin
      Rows (0, N - 1, 8);
      Draw_Features (W, Pic.all, 0, 0, Size_B, 0.25, 0);
      Write (Path, Pic.all);
      Free (Pic);
   end Terrain_Map;

   --------------
   -- Zoom_Map --
   --------------

   procedure Zoom_Map (W : World; Path : String) is
      Win    : constant := 1_024;   --  blocks per window (256 m)
      Gap    : constant := 8;
      Pic    : Image_Access := new Image (0 .. Win - 1, 0 .. 2 * Win + Gap - 1);
      Coal_I : Natural;
      Iron_I : Natural;

      procedure Window (Panel : Natural; Cx_M, Cy_M : Float) is
         X0  : constant Integer :=
           Integer'Max (0, Integer'Min (Size_B - Win, Floor_I (Cx_M * 4.0) - Win / 2));
         Y0  : constant Integer :=
           Integer'Max (0, Integer'Min (Size_B - Win, Floor_I (Cy_M * 4.0) - Win / 2));
         Off : constant Integer := Panel * (Win + Gap);

         procedure Row (Ly : Integer) is
            By : constant Integer := Y0 + Ly;
         begin
            for Lx in 0 .. Win - 1 loop
               declare
                  Bx : constant Integer := X0 + Lx;
                  C  : constant Column  := Prepare_Column (W, Bx, By);
                  Cl : Col;
               begin
                  if C.Water_Top > C.Solid then
                     Cl := Blend (Color_Of (Skin_Material (W, C, Air_Brick, Bx, By, C.Solid - 1)),
                                  (40.0, 80.0, 150.0),
                                  Clamp (0.45 + Float (C.Water_Top - C.Solid) / 12.0, 0.0, 0.92));
                  else
                     declare
                        M : Material := Top_Material (W, C, Bx, By);
                     begin
                        if C.Plant_H > 0 then
                           M := C.Plant;
                        end if;
                        Cl := Color_Of (M);
                     end;
                  end if;
                  Cl := Scale (Cl, Shade (W, Bx / 4, By / 4) * Jitter (W.Seed, Bx, By, 7));
                  Pic (Win - 1 - Ly, Off + Lx) := To_RGB (Cl);
               end;
            end loop;
         end Row;

         procedure Rows is new Castle.Jobs.Parallel_For (Row);
      begin
         Rows (0, Win - 1, 16);
         Draw_Features (W, Pic.all, X0, Y0, Win, 1.0, Off);
      end Window;
   begin
      Fill (Pic.all, (255.0, 255.0, 255.0));
      Pick_Veins (W, Coal_I, Iron_I);
      if Coal_I > 0 then
         Window (0, W.Deposits (Coal_I).Cx, W.Deposits (Coal_I).Cy);
      end if;
      if Iron_I > 0 then
         Window (1, W.Deposits (Iron_I).Cx, W.Deposits (Iron_I).Cy);
         declare
            D : Deposit renames W.Deposits (Iron_I);
         begin
            Put_Line ("    zoom: iron vein at (" & Img (Floor_I (D.Cx)) & "," & Img (Floor_I (D.Cy))
                      & "), " & Img (D.Last_Tube - D.First_Tube + 1) & " tubes reaching "
                      & Img (D.Reach, 0) & " m, " & Img (D.Deepest, 0) & " m deep at most"
                      & (if D.Silver_Vol + D.Gold_Vol > 0.0
                         then "; silver " & Img (D.Silver_Vol, 0) & " m^3, gold " & Img (D.Gold_Vol, 0)
                              & " m^3 from " & Img (D.Precious_Cover, 1) & " m below ground"
                         else ""));
         end;
      end if;
      Write (Path, Pic.all);
      Free (Pic);
   end Zoom_Map;

   ------------------
   -- Resource_Map --
   ------------------

   procedure Resource_Map (W : World; Path : String) is
      R   : constant := N / 2;
      Pic : Image_Access := new Image (0 .. R - 1, 0 .. R - 1);

      procedure Row (Y : Integer) is
      begin
         for X in 0 .. R - 1 loop
            declare
               Xm  : constant Float      := Float (X) * 2.0 + 1.0;
               Ym  : constant Float      := Float (Y) * 2.0 + 1.0;
               K   : constant Cell_Range := Idx (2 * X, 2 * Y);
               Gnd : constant Float      := W.Height (K);
               E   : Index_Entry renames W.Index (Index_Of (Xm), Index_Of (Ym));
               Cl  : Col := Scale ((150.0, 150.0, 150.0), 0.55 * Shade (W, 2 * X, 2 * Y));
            begin
               if W.Water (K) > Gnd then
                  Cl := (30.0, 55.0, 95.0);
               end if;
               for I in 1 .. E.Count loop
                  declare
                     D : Deposit renames W.Deposits (E.Items (I));
                  begin
                     if D.Kind = Bog_Iron_Patch then
                        if Castle.Deposits.Patch_Thickness (D, Xm, Ym) > 0.0 then
                           Cl := Blend (Cl, Vein_Color (D), 0.8);
                        end if;
                     elsif (Xm - D.Cx) ** 2 + (Ym - D.Cy) ** 2 < 36.0 then
                        Cl := Vein_Color (D);                  --  the outcrop and its loose ore
                     end if;
                  end;
               end loop;
               --  Veins seen from above, through the ground.
               declare
                  Near : Near_Tubes;
               begin
                  Castle.Deposits.Gather (W, Xm, Ym, 0.0, Near);
                  for I in 1 .. Near.Count loop
                     declare
                        T : Vein_Tube renames W.Tubes (Near.Ids (I));
                        D : Deposit renames W.Deposits (T.Owner);
                     begin
                        if (Xm - D.Cx) ** 2 + (Ym - D.Cy) ** 2 >= 36.0 then
                           Cl := Blend (Cl, Vein_Color (D), 0.45);
                           if T.Gold > 0.0 then
                              Cl := Blend (Cl, Gold_C, 0.8);
                           elsif T.Silver > 0.0 then
                              Cl := Blend (Cl, Silver_C, 0.7);
                           end if;
                        end if;
                     end;
                  end loop;
               end;
               Pic (R - 1 - Y, X) := To_RGB (Cl);
            end;
         end loop;
      end Row;

      procedure Rows is new Castle.Jobs.Parallel_For (Row);
   begin
      Rows (0, R - 1, 8);
      Write (Path, Pic.all);
      Free (Pic);
   end Resource_Map;

   -----------------
   -- Aquifer_Map --
   -----------------

   procedure Aquifer_Map (W : World; Path : String) is
      R    : constant := N / 2;
      Pic  : Image_Access := new Image (0 .. R - 1, 0 .. R - 1);
      Good : Natural := 0;
      Dry  : Natural := 0;

      protected Tally is
         procedure Add (G, D : Natural);
      end Tally;

      protected body Tally is
         procedure Add (G, D : Natural) is
         begin
            Good := Good + G;
            Dry  := Dry + D;
         end Add;
      end Tally;

      procedure Row (Y : Integer) is
         G, D : Natural := 0;
      begin
         for X in 0 .. R - 1 loop
            declare
               Xm           : constant Float      := Float (X) * 2.0 + 1.0;
               Ym           : constant Float      := Float (Y) * 2.0 + 1.0;
               K            : constant Cell_Range := Idx (2 * X, 2 * Y);
               Depth, Yield : Float;
               Cl           : Col;
            begin
               Well_Info (W, Xm, Ym, Depth, Yield);
               if W.Water (K) > W.Height (K) then
                  Cl := (25.0, 45.0, 80.0);
               else
                  Cl := (if Yield < 0.5
                         then Blend ((150.0, 70.0, 45.0), (225.0, 205.0, 90.0), Yield * 2.0)
                         else Blend ((225.0, 205.0, 90.0), (40.0, 140.0, 235.0), (Yield - 0.5) * 2.0));
                  Cl := Scale (Cl, (1.0 - 0.6 * Clamp (Depth / 15.0, 0.0, 1.0))
                                   * (0.75 + 0.25 * Shade (W, 2 * X, 2 * Y)));
                  if Yield >= 0.6 and then Depth <= 4.0 then
                     G := G + 1;
                  elsif Yield < 0.3 then
                     D := D + 1;
                  end if;
               end if;
               Pic (R - 1 - Y, X) := To_RGB (Cl);
            end;
         end loop;
         Tally.Add (G, D);
      end Row;

      procedure Rows is new Castle.Jobs.Parallel_For (Row);
   begin
      Rows (0, R - 1, 8);
      Put_Line ("    wells: good (yield >= 0.6, water within 4 m) on "
                & Img (100.0 * Float (Good) / Float (R * R), 1) & " % of the map, poor on "
                & Img (100.0 * Float (Dry) / Float (R * R), 1) & " %");
      Write (Path, Pic.all);
      Free (Pic);
   end Aquifer_Map;

   --------------
   -- Sections --
   --------------

   procedure Sections (W : World; Path : String) is
      Span   : constant := 1_024;          --  blocks along each cut (256 m)
      Px_B   : constant := 2;              --  pixels per block
      Gap    : constant := 10;
      Cuts_N : constant := 4;
      Pic    : Image_Access;
      Tops   : array (1 .. Cuts_N) of Integer := (others => Height_B);   --  rows shown per cut
      Offs   : array (1 .. Cuts_N) of Integer := (others => 0);          --  first picture row
      Work   : Stack_Work_Access := new Stack_Work;

      type Cut is record
         Along_X : Boolean := True;
         Fixed   : Integer := 0;   --  block coordinate across the cut
         Start   : Integer := 0;   --  first block along it
      end record;
      Cuts : array (1 .. Cuts_N) of Cut;

      function Start_At (Center_B : Integer) return Integer is
        (Integer'Max (0, Integer'Min (Size_B - Span, ((Center_B - Span / 2) / Chunk_B) * Chunk_B)));

      function Down_Dip_Cut (D : Deposit) return Cut is
        (if abs D.Ca >= abs D.Sa
         then (True, Floor_I (D.Cy * 4.0) + 2, Start_At (Floor_I ((D.Cx + 0.5 * D.Reach * D.Ca) * 4.0)))
         else (False, Floor_I (D.Cx * 4.0) + 2, Start_At (Floor_I ((D.Cy + 0.5 * D.Reach * D.Sa) * 4.0))));

      Sky_Lo : constant Col := (205.0, 222.0, 236.0);
      Sky_Hi : constant Col := (128.0, 168.0, 214.0);
      Deep_C : constant Col := (100.0, 100.0, 110.0);
      Coal_I, Iron_I : Natural;

      function Round_Top (Max_M : Float) return Integer is
        (Integer'Min (Height_B,
                      ((Integer (Max_M) + 20) * Blocks_Per_Meter + Chunk_B - 1) / Chunk_B * Chunk_B));
      --  Highest ground along a cut, 20 m of headroom, whole chunks.

      function Clamp_M (V : Float) return Float is
        (Float'Max (0.0, Float'Min (Float (Size_M) - 0.01, V)));

      function Line_Top (Ct : Cut) return Integer is
         Hi : Float := 0.0;
         F  : constant Float := Float (Ct.Fixed) / Float (Blocks_Per_Meter);
      begin
         for I in 0 .. Span / Blocks_Per_Meter - 1 loop
            declare
               A : constant Float := Clamp_M (Float (Ct.Start) / Float (Blocks_Per_Meter) + Float (I) + 0.5);
            begin
               Hi := Float'Max (Hi, (if Ct.Along_X then Sample (W.Height.all, A, F)
                                     else Sample (W.Height.all, F, A)));
            end;
         end loop;
         return Round_Top (Hi);
      end Line_Top;

      function Dip_Top (D : Deposit) return Integer is
         Hi : Float := 0.0;
      begin
         for I in 0 .. Span / Blocks_Per_Meter - 1 loop
            declare
               S : constant Float := -30.0 + Float (I);
            begin
               Hi := Float'Max (Hi, Sample (W.Height.all, Clamp_M (D.Cx + S * D.Ca), Clamp_M (D.Cy + S * D.Sa)));
            end;
         end loop;
         return Round_Top (Hi);
      end Dip_Top;

      --  A cut along the heading of vein D, from 30 m before its outcrop,
      --  built from the on-demand functions (skin and deep), no stacks.
      procedure Dip_Section (Slot : Positive; D : Deposit) is
         Top_Px  : constant Integer := Offs (Slot);
         Top_B   : constant Integer := Tops (Slot);
         Last_Mx : Integer := -1;
         Last_My : Integer := -1;
         BC      : Brick_Column;
         Rocks   : array (0 .. Height_M - 1) of Brick;
         --  The whole vein, projected onto the cut (an x-ray): 1 ore,
         --  2 silver, 3 gold.  A vein snakes, so the cut alone would only
         --  catch pieces of it.
         type Shadow is array (0 .. Span - 1, 0 .. Height_B - 1) of Interfaces.Unsigned_8;
         type Shadow_Access is access Shadow;
         procedure Free_Shadow is new Ada.Unchecked_Deallocation (Shadow, Shadow_Access);
         Xray : Shadow_Access := new Shadow'(others => (others => 0));
      begin
         for K in D.First_Tube .. D.Last_Tube loop
            declare
               T     : Vein_Tube renames W.Tubes (K);
               Steps : constant Integer := Integer'Max (1, Integer (Castle.Deposits.Tube_Length (T) * 4.0));
               Level : constant Interfaces.Unsigned_8 :=
                 (if T.Gold > 0.0 then 3 elsif T.Silver > 0.0 then 2 else 1);
            begin
               for St in 0 .. Steps loop
                  declare
                     F  : constant Float := Float (St) / Float (Steps);
                     Px : constant Float := T.Ax + F * (T.Bx - T.Ax);
                     Py : constant Float := T.Ay + F * (T.By - T.Ay);
                     Pz : constant Float := T.Az + F * (T.Bz - T.Az);
                     Rb : constant Float := (T.Ra + F * (T.Rb - T.Ra)) * 4.0;
                     Ic : constant Float := ((Px - D.Cx) * D.Ca + (Py - D.Cy) * D.Sa + 30.0) * 4.0;
                     Zc : constant Float := Pz * 4.0;
                  begin
                     for Zi in Floor_I (Zc - Rb) .. Floor_I (Zc + Rb) loop
                        for Ii in Floor_I (Ic - Rb) .. Floor_I (Ic + Rb) loop
                           if Ii in Shadow'Range (1) and then Zi in Shadow'Range (2)
                             and then (Float (Ii) + 0.5 - Ic) ** 2 + (Float (Zi) + 0.5 - Zc) ** 2 <= Rb * Rb
                             and then Xray (Ii, Zi) < Level
                           then
                              Xray (Ii, Zi) := Level;
                           end if;
                        end loop;
                     end loop;
                  end;
               end loop;
            end;
         end loop;

         for I in 0 .. Span - 1 loop
            declare
               S  : constant Float   := -30.0 + Float (I) / Float (Blocks_Per_Meter);
               Bx : constant Integer :=
                 Integer'Max (0, Integer'Min (Size_B - 1, Floor_I ((D.Cx + S * D.Ca) * 4.0)));
               By : constant Integer :=
                 Integer'Max (0, Integer'Min (Size_B - 1, Floor_I ((D.Cy + S * D.Sa) * 4.0)));
               Mx : constant Integer := Bx / Blocks_Per_Meter;
               My : constant Integer := By / Blocks_Per_Meter;
               C  : constant Column  := Prepare_Column (W, Bx, By);
            begin
               if Mx /= Last_Mx or else My /= Last_My then
                  BC := Prepare_Brick_Column (W, Mx, My);
                  for Mz in Rocks'Range loop
                     Rocks (Mz) := Rock_At (W, BC, Mz);
                  end loop;
                  Last_Mx := Mx;
                  Last_My := My;
               end if;
               for Z in 0 .. Top_B - 1 loop
                  declare
                     In_Deep : constant Boolean := Z < C.Solid - Skin_Depth_M * Blocks_Per_Meter;
                     Cl      : Col;
                  begin
                     if In_Deep then
                        declare
                           Br : constant Brick :=
                             Brick_At (BC, Z / Blocks_Per_Meter, Rocks (Z / Blocks_Per_Meter));
                        begin
                           if Br.Mat = Gold_Ore then
                              Cl := (255.0, 210.0, 30.0);    --  undimmed, so the tails show
                           elsif Br.Mat = Silver_Ore then
                              Cl := (150.0, 210.0, 255.0);
                           else
                              if Br.Mat /= Br.Host then
                                 Cl := Blend (Color_Of (Br.Host), Color_Of (Br.Mat),
                                              Float (Br.Grade) / 255.0);
                              else
                                 Cl := Color_Of (Br.Mat);
                              end if;
                              Cl := Scale (Blend (Cl, Deep_C, 0.45), Jitter (W.Seed, Mx, My, Z / 4));
                           end if;
                        end;
                     else
                        declare
                           M : constant Material :=
                             Skin_Material (W, C, Rocks (Z / Blocks_Per_Meter), Bx, By, Z);
                        begin
                           if M = Air then
                              Cl := Blend (Sky_Lo, Sky_Hi, Float (Z) / Float (Top_B));
                           elsif M = Water then
                              Cl := Color_Of (Water);
                           else
                              Cl := Scale (Color_Of (M), Jitter (W.Seed, Bx, By, Z));
                           end if;
                        end;
                     end if;
                     if Z < C.Solid and then Xray (I, Z) > 0 then
                        Cl := Blend (Cl, (case Xray (I, Z) is
                                             when 3      => Gold_C,
                                             when 2      => Silver_C,
                                             when others => Vein_Color (D)), 0.85);
                     end if;
                     for Dy in 0 .. Px_B - 1 loop
                        for Dx in 0 .. Px_B - 1 loop
                           declare
                              Edge : constant Boolean :=
                                In_Deep and then ((Z mod 4 = 0 and then Dy = Px_B - 1)
                                                  or else (I mod 4 = 0 and then Dx = 0));
                           begin
                              Pic (Top_Px + (Top_B - 1 - Z) * Px_B + Dy, I * Px_B + Dx) :=
                                To_RGB ((if Edge then Scale (Cl, 0.8) else Cl));
                           end;
                        end loop;
                     end loop;
                  end;
               end loop;
            end;
         end loop;
         Free_Shadow (Xray);
      end Dip_Section;
   begin
      Pick_Veins (W, Coal_I, Iron_I);
      Cuts (1) := (if Coal_I > 0 then Down_Dip_Cut (W.Deposits (Coal_I))
                   else (True, Size_B / 2 + 2, Start_At (Size_B / 2)));
      Cuts (2) := (if Iron_I > 0 then Down_Dip_Cut (W.Deposits (Iron_I))
                   else (True, Size_B / 3 + 2, Start_At (Size_B / 3)));
      declare
         Best_H : Float   := -1.0;
         Best_F : Float   := 0.0;
         Hx, Hy : Integer := N / 2;
         Fx, Fy : Integer := 3 * N / 4;
      begin
         for Y in 0 .. N - 1 loop
            for X in 0 .. N - 1 loop
               declare
                  K : constant Cell_Range := Idx (X, Y);
               begin
                  if W.Height (K) > Best_H then
                     Best_H := W.Height (K);
                     Hx := X;
                     Hy := Y;
                  end if;
                  if W.Kind (K) = River and then X in 256 .. N - 257 and then Y in 256 .. N - 257
                    and then W.Flow (K) > Best_F
                  then
                     Best_F := W.Flow (K);
                     Fx := X;
                     Fy := Y;
                  end if;
               end;
            end loop;
         end loop;
         Cuts (3) := (True, Hy * 4 + 2, Start_At (Hx * 4));
         declare
            Row_Hits, Col_Hits : Natural := 0;
         begin
            for D in -12 .. 12 loop
               if W.Kind (Idx (Clamp_Cell (Fx + D), Fy)) in Stream | River then
                  Row_Hits := Row_Hits + 1;
               end if;
               if W.Kind (Idx (Fx, Clamp_Cell (Fy + D))) in Stream | River then
                  Col_Hits := Col_Hits + 1;
               end if;
            end loop;
            Cuts (4) := (if Row_Hits <= Col_Hits
                         then (True, Fy * 4 + 2, Start_At (Fx * 4))
                         else (False, Fx * 4 + 2, Start_At (Fy * 4)));
         end;
      end;

      --  Crop every cut to the ground it crosses, plus room for trees.
      Tops (1) := (if Coal_I > 0 then Dip_Top (W.Deposits (Coal_I)) else Line_Top (Cuts (1)));
      Tops (2) := (if Iron_I > 0 then Dip_Top (W.Deposits (Iron_I)) else Line_Top (Cuts (2)));
      for S in 3 .. Cuts_N loop
         Tops (S) := Line_Top (Cuts (S));
      end loop;
      for S in 2 .. Cuts_N loop
         Offs (S) := Offs (S - 1) + Tops (S - 1) * Px_B + Gap;
      end loop;
      Pic := new Image (0 .. Offs (Cuts_N) + Tops (Cuts_N) * Px_B - 1, 0 .. Span * Px_B - 1);
      Fill (Pic.all, (255.0, 255.0, 255.0));

      if Coal_I > 0 then
         Dip_Section (1, W.Deposits (Coal_I));
      end if;
      if Iron_I > 0 then
         Dip_Section (2, W.Deposits (Iron_I));
      end if;
      for S in 3 .. Cuts_N loop
         declare
            Ct     : constant Cut     := Cuts (S);
            Top_Px : constant Integer := Offs (S);
            Top_B  : constant Integer := Tops (S);
            Lane   : constant Integer := Ct.Fixed mod Chunk_B;
         begin
            for Stk in 0 .. Span / Chunk_B - 1 loop
               declare
                  A  : constant Integer := Ct.Start + Stk * Chunk_B;
                  CX : constant Integer := (if Ct.Along_X then A / Chunk_B else Ct.Fixed / Chunk_B);
                  CY : constant Integer := (if Ct.Along_X then Ct.Fixed / Chunk_B else A / Chunk_B);
                  Deep_Col : array (Brick_Index, 0 .. Height_M - 1) of Brick;
               begin
                  Generate (W, CX, CY, Work.all);

                  --  The deep under this lane, generated on demand.
                  for B in Brick_Index loop
                     declare
                        Mx : constant Integer := (if Ct.Along_X then A / 4 + B else Ct.Fixed / 4);
                        My : constant Integer := (if Ct.Along_X then Ct.Fixed / 4 else A / 4 + B);
                        BC : constant Brick_Column := Prepare_Brick_Column (W, Mx, My);
                     begin
                        for Mz in 0 .. Height_M - 1 loop
                           Deep_Col (B, Mz) := Brick_At (BC, Mz, Rock_At (W, BC, Mz));
                        end loop;
                     end;
                  end loop;

                  for L in 0 .. Chunk_B - 1 loop
                     declare
                        Lx     : constant Integer     := (if Ct.Along_X then L else Lane);
                        Ly     : constant Integer     := (if Ct.Along_X then Lane else L);
                        Bi     : constant Brick_Index := Lx / Blocks_Per_Meter;
                        Bj     : constant Brick_Index := Ly / Blocks_Per_Meter;
                        Skin_Z : constant Integer     := Work.Skin (Bi, Bj) * Blocks_Per_Meter;
                     begin
                        for Z in 0 .. Top_B - 1 loop
                           declare
                              In_Deep : constant Boolean := Z < Skin_Z;
                              Cl      : Col;
                           begin
                              if In_Deep then
                                 declare
                                    Br : constant Brick := Deep_Col (L / 4, Z / 4);
                                 begin
                                    if Br.Mat /= Br.Host then
                                       Cl := Blend (Color_Of (Br.Host), Color_Of (Br.Mat),
                                                    Float (Br.Grade) / 255.0);
                                    else
                                       Cl := Color_Of (Br.Mat);
                                    end if;
                                    if Br.Mat = Gold_Ore or else Br.Mat = Silver_Ore then
                                       Cl := Color_Of (Br.Mat);   --  undimmed, so the tails show
                                    else
                                       Cl := Scale (Blend (Cl, Deep_C, 0.45),
                                                    Jitter (W.Seed, (A + L) / 4, Ct.Fixed / 4, Z / 4));
                                    end if;
                                 end;
                              else
                                 declare
                                    M : constant Material := Work.G (Lx, Ly, Z).Mat;
                                 begin
                                    if M = Air then
                                       Cl := Blend (Sky_Lo, Sky_Hi, Float (Z) / Float (Top_B));
                                    elsif M = Water then
                                       Cl := Color_Of (Water);
                                    else
                                       Cl := Scale (Color_Of (M), Jitter (W.Seed, A + L, Ct.Fixed, Z));
                                    end if;
                                 end;
                              end if;
                              for Dy in 0 .. Px_B - 1 loop
                                 for Dx in 0 .. Px_B - 1 loop
                                    declare
                                       Edge : constant Boolean :=
                                         In_Deep and then ((Z mod 4 = 0 and then Dy = Px_B - 1)
                                                           or else ((A + L) mod 4 = 0 and then Dx = 0));
                                    begin
                                       Pic (Top_Px + (Top_B - 1 - Z) * Px_B + Dy,
                                            (Stk * Chunk_B + L) * Px_B + Dx) :=
                                         To_RGB ((if Edge then Scale (Cl, 0.8) else Cl));
                                    end;
                                 end loop;
                              end loop;
                           end;
                        end loop;
                     end;
                  end loop;
               end;
            end loop;
         end;
      end loop;
      Write (Path, Pic.all);
      Free (Pic);
      Free (Work);
   end Sections;

   ------------
   -- Survey --
   ------------

   procedure Survey (W : World; Samples : Positive) is

      protected Acc is
         procedure Add (T : Duration; U, A, Dp, F : Natural; B, B_Dense : Long_Long_Integer);
         procedure Get (T, T_Max : out Duration; U, A, Dp, F : out Natural;
                        B, B_Dense : out Long_Long_Integer);
         procedure Add_Check (H : U64);
         function Checksum return U64;
      private
         Sum_T, Max_T  : Duration := 0.0;
         Uni, Air_C    : Natural  := 0;
         Deep_C, Fine_C : Natural := 0;
         Bytes_T, Dense_T : Long_Long_Integer := 0;
         Check         : U64 := 0;
      end Acc;

      protected body Acc is
         procedure Add (T : Duration; U, A, Dp, F : Natural; B, B_Dense : Long_Long_Integer) is
         begin
            Sum_T   := Sum_T + T;
            Max_T   := Duration'Max (Max_T, T);
            Uni     := Uni + U;
            Air_C   := Air_C + A;
            Deep_C  := Deep_C + Dp;
            Fine_C  := Fine_C + F;
            Bytes_T := Bytes_T + B;
            Dense_T := Dense_T + B_Dense;
         end Add;

         procedure Get (T, T_Max : out Duration; U, A, Dp, F : out Natural;
                        B, B_Dense : out Long_Long_Integer) is
         begin
            T       := Sum_T;
            T_Max   := Max_T;
            U       := Uni;
            A       := Air_C;
            Dp      := Deep_C;
            F       := Fine_C;
            B       := Bytes_T;
            B_Dense := Dense_T;
         end Get;

         procedure Add_Check (H : U64) is
         begin
            Check := Check xor Mix (H);   --  order-independent across workers
         end Add_Check;

         function Checksum return U64 is (Check);
      end Acc;

      Sample_Seed : constant U64 := Derive (W.Seed, 777);

      procedure One (K : Integer) is
         H    : constant U64     := Hash_2 (Sample_Seed, K, 0);
         CX   : constant Integer := Integer (H mod Chunks_XY);
         CY   : constant Integer := Integer (Shift_Right (H, 20) mod Chunks_XY);
         Work : Stack_Work_Access := new Stack_Work;
         S    : Chunk_Stack;
         T0   : constant Time := Clock;
         U, A, Dp, F : Natural := 0;
         B, B_Dense  : Long_Long_Integer := 0;
      begin
         Generate (W, CX, CY, Work.all);
         Pack (Work.all, S);
         declare
            Dt : constant Duration := To_Duration (Clock - T0);
         begin
            for C of S loop
               if C.Uniform then
                  U := U + 1;
                  if C.Fill.Mat = Air then
                     A := A + 1;
                  elsif C.Fill.Mat = Deep then
                     Dp := Dp + 1;
                  end if;
               end if;
               F := F + Fine_Count (C);
               B := B + Long_Long_Integer (Bytes (C));
            end loop;
            --  The same stored chunks as plain 16-bit blocks (uniform ones collapsed).
            for CZ in 0 .. Chunks_Z - 1 loop
               B_Dense := B_Dense + (if S (CZ).Uniform then 2 else Long_Long_Integer (Chunk_B ** 3 * 2));
            end loop;
            Acc.Add (Dt, U, A, Dp, F, B, B_Dense);
         end;
         declare
            Sum : U64 := U64 (K);
         begin
            for X in 0 .. Chunk_B - 1 loop
               for Y in 0 .. Chunk_B - 1 loop
                  for Z in 0 .. Height_B - 1 loop
                     Sum := (Sum xor U64 (Material'Pos (Work.G (X, Y, Z).Mat))) * 16#100_0000_01B3#;
                  end loop;
               end loop;
            end loop;
            Acc.Add_Check (Sum);
         end;
         Free (S);
         Free (Work);
      end One;

      procedure All_Samples is new Castle.Jobs.Parallel_For (One);

      T_Wall       : constant Time := Clock;
      Sum_T, Max_T : Duration;
      U, A, Dp, F  : Natural;
      B, B_Dense   : Long_Long_Integer;
      Stacks_World : constant Float := Float (Chunks_XY) ** 2;
      Chunks_S     : constant Float := Float (Samples * Chunks_Z);
      GiB          : constant Float := 1024.0 ** 3;
   begin
      All_Samples (1, Samples);
      declare
         Wall : constant Duration := To_Duration (Clock - T_Wall);
      begin
         Acc.Get (Sum_T, Max_T, U, A, Dp, F, B, B_Dense);
         declare
            Per_Ms      : constant Float := Float (Sum_T) * 1000.0 / Float (Samples);
            Bytes_Stack : constant Float := Float (B) / Float (Samples);
            Dense_Stack : constant Float := Float (B_Dense) / Float (Samples);
         begin
            Put_Line ("  chunk survey: " & Img (Samples) & " random stacks ("
                      & Img (Samples * Chunks_Z) & " chunks), "
                      & Img (Castle.Jobs.Worker_Count) & " worker(s), wall "
                      & Img (Float (Wall), 2) & " s");
            Put_Line ("    generate + pack: " & Img (Per_Ms, 2) & " ms per stack per thread (worst "
                      & Img (Float (Max_T) * 1000.0, 1) & " ms)");
            Put_Line ("    chunks: deep (not generated, not stored) " & Img (100.0 * Float (Dp) / Chunks_S, 1)
                      & " %, all air " & Img (100.0 * Float (A) / Chunks_S, 1)
                      & " %, skin " & Img (100.0 * (Chunks_S - Float (U)) / Chunks_S, 1)
                      & " %; fine bricks " & Img (Float (F) / Float (Samples), 0) & " per stack");
            Put_Line ("    stored: " & Img (Bytes_Stack / 1024.0, 1) & " KiB per stack -> "
                      & Img (Bytes_Stack * Stacks_World / GiB, 2) & " GiB for all "
                      & Img (Integer (Stacks_World)) & " stacks (the skin as plain blocks: "
                      & Img (Dense_Stack * Stacks_World / GiB, 2) & " GiB)");
            Put_Line ("    whole world: " & Img (Per_Ms * Stacks_World / 1000.0, 0)
                      & " s on one thread; ideal on 15 workers: "
                      & Img (Per_Ms * Stacks_World / 1000.0 / 15.0, 0) & " s");
            Put_Line ("    content checksum:" & U64'Image (Acc.Checksum)
                      & "  (must not change with --workers)");
         end;
      end;
   end Survey;

end Castle.Preview;
