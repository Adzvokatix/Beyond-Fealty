with Ada.Numerics.Elementary_Functions; use Ada.Numerics.Elementary_Functions;
with Ada.Unchecked_Deallocation;
with Interfaces;     use Interfaces;
with Castle.Noise;   use Castle.Noise;
with Castle.Fields;  use Castle.Fields;
with Castle.Geology; use Castle.Geology;
with Castle.Dims;   use Castle.Dims;
with Castle.Channels;

package body Castle.Flora is

   package Ch renames Castle.Channels;

   Bush_Reach : constant := 4;
   Rock_Reach : constant := 8;

   type Put_Mode is (Foliage, Wood, Stone);

   function Replaceable (Cur : Material; Mode : Put_Mode) return Boolean is
     (case Mode is
         when Foliage => Cur in Air | Tall_Grass | Wild_Grain | Wild_Vegetables,
         when Wood    => Cur in Air | Tall_Grass | Wild_Grain | Wild_Vegetables | Crown | Berry_Bush | Grass | Dirt,
         when Stone   => Cur in Air | Tall_Grass | Wild_Grain | Wild_Vegetables | Grass | Dirt | Sand | Gravel);

   procedure Put
     (G : in out Stack_Grid; X0, Y0, Bx, By, Bz : Integer; M : Material; Mode : Put_Mode;
      Hi : in out Integer)
   is
      Lx : constant Integer := Bx - X0;
      Ly : constant Integer := By - Y0;
   begin
      if Lx in 0 .. Chunk_B - 1 and then Ly in 0 .. Chunk_B - 1
        and then Bz in 1 .. Height_B - 1
        and then Replaceable (G (Lx, Ly, Bz).Mat, Mode)
      then
         G (Lx, Ly, Bz) := (Mat => M, State => 0);
         Hi := Integer'Max (Hi, Bz);
      end if;
   end Put;

   --------------------
   -- Forest_Density --
   --------------------

   function Forest_Density (W : World; Xm, Ym : Float) return Float is
      --  Patches about 190 m across with fairly sharp edges, so a forest is
      --  a forest and the open land between is open.
      Patch : constant Float :=
        Smoothstep (-0.12, 0.08, FBM_2 (W.Ch (Ch.Forest), Xm / 190.0, Ym / 190.0, 4));
      Moist : constant Float := Sample (W.Moisture.all, Xm, Ym);
      Slope : constant Float := Sample (W.Slope.all, Xm, Ym);
      H     : constant Float := Sample (W.Height.all, Xm, Ym);
   begin
      return 0.97 * Patch * Smoothstep (0.15, 0.40, Moist)
        * (1.0 - Smoothstep (0.6, 1.1, Slope)) * (1.0 - Smoothstep (50.0, 60.0, H));
   end Forest_Density;

   function Dry_Ground (C : Column) return Boolean is
     (C.Water_Top <= C.Solid and then (C.Top = Grass or else C.Top = Dirt)
      and then C.Vein_Hi < C.Solid);
   --  Nothing takes root on open water or a bare vein.

   -------------
   -- Tree_At --
   -------------

   function Tree_At (W : World; I, J : Integer) return Tree is
      T  : Tree;
      H  : constant U64 := Hash_2 (W.Ch (Ch.Trees), I, J);
      Bx : constant Integer := I * Tree_Cell + 2 + Integer (H mod (Tree_Cell - 4));
      By : constant Integer := J * Tree_Cell + 2 + Integer (Shift_Right (H, 8) mod (Tree_Cell - 4));
   begin
      if Bx < 0 or else By < 0 or else Bx >= Size_B - 2 or else By >= Size_B - 2 then
         return T;
      end if;
      declare
         Xm : constant Float := Center_M (Bx);
         Ym : constant Float := Center_M (By);
         F  : constant Float := Forest_Density (W, Xm, Ym);
         U  : constant Float := Unit (Mix (H xor 16#5151#));
         Lone : constant Boolean := U >= F;   --  no forest tree here: perhaps one on its own
      begin
         if Lone and then (F >= 0.35 or else U >= F + Lone_Chance * (1.0 - F)) then   --  not in a forest's edge
            return T;
         end if;
         declare
            C    : constant Column := Prepare_Column (W, Bx, By);
            Size : constant Float  := Unit (Mix (H + 7));
            Pick : constant Float  := Unit (Mix (H + 11));
            Conifers : constant Float :=     --  the conifers' share: all of it up high
              Smoothstep (24.0, 34.0, Float (C.Solid) / Float (Blocks_Per_Meter))
              + 0.25 * FBM_2 (W.Ch (Ch.Pine_Mix), Xm / 150.0, Ym / 150.0, 2);
            Grove : constant Float :=        --  aspens stand together
              Smoothstep (0.18, 0.30, FBM_2 (W.Ch (Ch.Aspen_Grove), Xm / 80.0, Ym / 80.0, 2));
            Kind : Species;
         begin
            if not Dry_Ground (C) then
               return T;
            end if;
            if Lone then
               Kind := (if Conifers > 0.5 then Spruce else Apple);
            elsif Pick < Conifers then
               Kind := (if Unit (Mix (H + 17)) < 0.35 then Pine else Spruce);
            elsif Unit (Mix (H + 19)) < 0.05 + 0.85 * Grove then
               Kind := Aspen;
            else
               Kind := Broadleaf;
            end if;
            T.Valid := True;
            T.Kind  := Kind;
            T.Bx    := Bx;
            T.By    := By;
            T.Bz    := C.Solid;
            T.Seed  := Mix (H + 13);
            case Kind is
               when Spruce =>
                  T.Trunk_H := 26 + Integer (Size * 18.0);
                  T.Trunk_W := (if Size > 0.7 then 2 else 1);
                  T.Crown_R := 6 + Integer (Size * 3.0);
                  T.Bark    := Log;
                  T.Leaf    := Pine_Needles;
               when Pine =>
                  T.Trunk_H := 30 + Integer (Size * 16.0);
                  T.Trunk_W := (if Size > 0.6 then 2 else 1);
                  T.Crown_R := 6 + Integer (Size * 3.0);
                  T.Bark    := Pine_Log;
                  T.Leaf    := Pine_Needles;
               when Aspen =>
                  T.Trunk_H := 22 + Integer (Size * 12.0);
                  T.Trunk_W := 1;
                  T.Crown_R := 3 + Integer (Size * 1.5);
                  T.Bark    := Aspen_Log;
                  T.Leaf    := Aspen_Leaves;
               when Apple =>
                  T.Trunk_H := 7 + Integer (Size * 4.0);
                  T.Trunk_W := 1;
                  T.Crown_R := 5 + Integer (Size * 2.0);
                  T.Bark    := Log;
                  T.Leaf    := Apple_Leaves;
               when Broadleaf =>
                  T.Trunk_H := 14 + Integer (Size * 10.0);
                  T.Trunk_W := (if Size > 0.55 then 2 else 1);
                  T.Crown_R := 8 + Integer (Size * 5.0);
                  T.Bark    := Log;
                  T.Leaf    := (if Unit (Mix (H + 23)) < 0.4 then Dark_Leaves else Leaves);
            end case;
         end;
      end;
      return T;
   end Tree_At;

   -------------
   -- Bush_At --
   -------------

   function Bush_At (W : World; I, J : Integer) return Lump is
      L  : Lump;
      H  : constant U64 := Hash_2 (W.Ch (Ch.Bushes), I, J);
      Cx : constant Integer := I * Bush_Cell + 2 + Integer (H mod (Bush_Cell - 4));
      Cy : constant Integer := J * Bush_Cell + 2 + Integer (Shift_Right (H, 8) mod (Bush_Cell - 4));
   begin
      if Cx < 0 or else Cy < 0 or else Cx >= Size_B or else Cy >= Size_B then
         return L;
      end if;
      declare
         Xm : constant Float := Center_M (Cx);
         Ym : constant Float := Center_M (Cy);
         F  : constant Float := Forest_Density (W, Xm, Ym);
         P  : constant Float :=
           Bush_Share * (0.02 + 1.2 * F * (1.0 - F) * Smoothstep (0.25, 0.50, Sample (W.Moisture.all, Xm, Ym)));
      begin
         if Unit (Mix (H xor 16#B0B0#)) >= P then
            return L;
         end if;
         declare
            C : constant Column := Prepare_Column (W, Cx, Cy);
         begin
            if not Dry_Ground (C) or else C.Top /= Grass then
               return L;
            end if;
            L.Valid := True;
            L.Kind  := Bush;
            L.Cx    := Cx;
            L.Cy    := Cy;
            L.Rh    := 2 + Integer (Shift_Right (H, 20) mod 2);
            L.Rv    := 2;
            L.Cz    := C.Solid + 1;
            L.Seed  := Mix (H + 3);
         end;
      end;
      return L;
   end Bush_At;

   ----------------
   -- Boulder_At --
   ----------------

   function Boulder_At (W : World; I, J : Integer) return Lump is
      L  : Lump;
      H  : constant U64 := Hash_2 (W.Ch (Ch.Boulders), I, J);
      Cx : constant Integer := I * Rock_Cell + 3 + Integer (H mod (Rock_Cell - 6));
      Cy : constant Integer := J * Rock_Cell + 3 + Integer (Shift_Right (H, 8) mod (Rock_Cell - 6));
   begin
      if Cx < 0 or else Cy < 0 or else Cx >= Size_B or else Cy >= Size_B then
         return L;
      end if;
      declare
         Xm    : constant Float := Center_M (Cx);
         Ym    : constant Float := Center_M (Cy);
         Rocky : constant Float :=
           0.02 + 0.45 * Smoothstep (0.35, 0.90, Sample (W.Slope.all, Xm, Ym))
           + 0.30 * Sample (W.Mountain.all, Xm, Ym)
           + 0.35 * Smoothstep (0.45, 0.75, FBM_2 (W.Ch (Ch.Rocky), Xm / 90.0, Ym / 90.0, 2));
      begin
         if Unit (Mix (H xor 16#C0C0#)) >= Rocky then
            return L;
         end if;
         declare
            C : constant Column := Prepare_Column (W, Cx, Cy);
            S : constant Float  := Unit (Mix (H + 5));
         begin
            if C.Water_Top > C.Solid then
               return L;
            end if;
            L.Valid := True;
            L.Kind  := Rock;
            L.Cx    := Cx;
            L.Cy    := Cy;
            L.Rh    := 2 + Integer (S * 4.0);
            L.Rv    := Integer'Max (2, (L.Rh * 3) / 4);
            L.Cz    := C.Solid + L.Rv / 3 - 1;
            L.Seed  := Mix (H + 9);
         end;
      end;
      return L;
   end Boulder_At;

   ----------
   -- Line --
   ----------

   procedure Line
     (G : in out Stack_Grid; X0, Y0 : Integer; Ax, Ay, Az, Bx, By, Bz : Float; M : Material;
      Hi : in out Integer)
   is
      Steps : constant Integer :=
        Integer'Max (1, Integer (Float'Ceiling
          (Float'Max (abs (Bx - Ax), Float'Max (abs (By - Ay), abs (Bz - Az))))));
   begin
      for S in 0 .. Steps loop
         declare
            T : constant Float := Float (S) / Float (Steps);
         begin
            Put (G, X0, Y0, Floor_I (Ax + (Bx - Ax) * T), Floor_I (Ay + (By - Ay) * T),
                 Floor_I (Az + (Bz - Az) * T), M, Wood, Hi);
         end;
      end loop;
   end Line;

   ---------------
   -- Draw_Tree --
   ---------------

   --  A crown is puffs of leaves: domes, each an ellipsoid cut off flat a
   --  little under its middle, its surface lumpy on a smooth noise a few
   --  blocks wide.  The noise goes by the tree's seed and the block's place
   --  in the world, and every other number by the seed and an index, so
   --  each stack that draws a part of the tree draws the same tree, and
   --  the order expressions are evaluated in cannot change it.
   type Puff is record
      X, Y, Z    : Float := 0.0;
      Rx, Ry, Rz : Float := 1.0;
      Under      : Float := 0.4;     --  it reaches this share of Rz below its middle
   end record;
   Max_Puffs : constant := 16;
   type Puff_List is array (1 .. Max_Puffs) of Puff;

   type Tree_Part is (Trunk_Part, Crown_Part);
   --  A stack draws the trunk of every tree that reaches into it before the
   --  boughs and the leaves of any, so a bough that crosses where another
   --  tree stands never lies in that tree's trunk (felling either would
   --  leave it hanging).

   procedure Draw_Tree
     (T : Tree; X0, Y0 : Integer; G : in out Stack_Grid; Hi : in out Integer; Part : Tree_Part)
   is
      R    : constant Integer := T.Crown_R;
      Fr   : constant Float   := Float (R);
      Fh   : constant Float   := Float (T.Trunk_H);
      Fz   : constant Float   := Float (T.Bz);
      Tx   : constant Float   := Float (T.Bx) + Float (T.Trunk_W) * 0.5;
      Ty   : constant Float   := Float (T.By) + Float (T.Trunk_W) * 0.5;
      Top  : constant Integer := T.Bz + T.Trunk_H;
      Ft   : constant Float   := Float (Top);
      Xa   : constant Integer := Integer'Max (X0, T.Bx - Tree_Reach);
      Xb   : constant Integer := Integer'Min (X0 + Chunk_B - 1, T.Bx + T.Trunk_W + Tree_Reach);
      Ya   : constant Integer := Integer'Max (Y0, T.By - Tree_Reach);
      Yb   : constant Integer := Integer'Min (Y0 + Chunk_B - 1, T.By + T.Trunk_W + Tree_Reach);
      Tau  : constant Float   := 6.2832;

      function U (I : Integer) return Float is (Unit (Hash_2 (T.Seed + 31, I, 0)));

      P : Puff_List;
      N : Natural := 0;

      procedure Add (X, Y, Z, Rx, Ry, Rz, Under : Float) is
      begin
         if N < Max_Puffs then
            N := N + 1;
            P (N) := (X, Y, Z, Float'Max (Rx, 0.9), Float'Max (Ry, 0.9), Float'Max (Rz, 0.9), Under);
         end if;
      end Add;

      --  A bough: out from the trunk and then up to where it ends, a curve
      --  of bark one block thick.
      procedure Bough (Ax, Ay, Az, Bx, By, Bz : Float) is
         Cx : constant Float := Ax + (Bx - Ax) * Bough_Out;
         Cy : constant Float := Ay + (By - Ay) * Bough_Out;
         Cz : constant Float := Az + (Bz - Az) * Bough_Rise;
         D  : constant Float := abs (Bx - Ax) + abs (By - Ay) + abs (Bz - Az);
         Steps : constant Integer := Integer'Max (2, Integer (Float'Ceiling (D / 3.0)));
         Px : Float := Ax;
         Py : Float := Ay;
         Pz : Float := Az;
      begin
         for S in 1 .. Steps loop
            declare
               V  : constant Float := Float (S) / Float (Steps);
               W0 : constant Float := (1.0 - V) * (1.0 - V);
               W1 : constant Float := 2.0 * V * (1.0 - V);
               W2 : constant Float := V * V;
               Qx : constant Float := W0 * Ax + W1 * Cx + W2 * Bx;
               Qy : constant Float := W0 * Ay + W1 * Cy + W2 * By;
               Qz : constant Float := W0 * Az + W1 * Cz + W2 * Bz;
            begin
               Line (G, X0, Y0, Px, Py, Pz, Qx, Qy, Qz, T.Bark, Hi);
               Px := Qx;
               Py := Qy;
               Pz := Qz;
            end;
         end loop;
      end Bough;

      --  The twigs a puff's leaves hang on (they show when the leaves fall):
      --  a few short ones up and out from where its bough ends.
      procedure Twigs (K : Positive; Count : Positive; Index : Integer) is
      begin
         for I in 1 .. Count loop
            declare
               A : constant Float := Tau * (Float (I) / Float (Count) + U (Index + I));
            begin
               Line (G, X0, Y0, P (K).X, P (K).Y, P (K).Z - 0.15 * P (K).Rz,
                     P (K).X + Cos (A) * P (K).Rx * Twig_Out, P (K).Y + Sin (A) * P (K).Ry * Twig_Out,
                     P (K).Z + P (K).Rz * (0.25 + 0.3 * U (Index + 10 + I)), T.Bark, Hi);
            end;
         end loop;
      end Twigs;

      --  The leaves: every block whose middle lies in a puff.
      procedure Fill (Lump, Wave : Float) is
         Lo_X, Lo_Y, Lo_Z : Float := Float'Last;
         Hi_X, Hi_Y, Hi_Z : Float := Float'First;
         Grow : constant Float := Sqrt (1.0 + Lump);
         Inv  : Puff_List;              --  reciprocal radii
      begin
         for K in 1 .. N loop
            Inv (K) := (0.0, 0.0, 0.0, 1.0 / P (K).Rx, 1.0 / P (K).Ry, 1.0 / P (K).Rz, 0.0);
            Lo_X := Float'Min (Lo_X, P (K).X - Grow * P (K).Rx);
            Hi_X := Float'Max (Hi_X, P (K).X + Grow * P (K).Rx);
            Lo_Y := Float'Min (Lo_Y, P (K).Y - Grow * P (K).Ry);
            Hi_Y := Float'Max (Hi_Y, P (K).Y + Grow * P (K).Ry);
            Lo_Z := Float'Min (Lo_Z, P (K).Z - P (K).Under * P (K).Rz);
            Hi_Z := Float'Max (Hi_Z, P (K).Z + Grow * P (K).Rz);
         end loop;
         for Z in Integer'Max (1, Floor_I (Lo_Z)) .. Integer'Min (Height_B - 1, Floor_I (Hi_Z)) loop
            for X in Integer'Max (Xa, Floor_I (Lo_X)) .. Integer'Min (Xb, Floor_I (Hi_X)) loop
               for Y in Integer'Max (Ya, Floor_I (Lo_Y)) .. Integer'Min (Yb, Floor_I (Hi_Y)) loop
                  declare
                     Px : constant Float := Float (X) + 0.5;
                     Py : constant Float := Float (Y) + 0.5;
                     Pz : constant Float := Float (Z) + 0.5;
                     Nz : Float := 0.0;
                     Known : Boolean := False;
                  begin
                     for K in 1 .. N loop
                        if Pz >= P (K).Z - P (K).Under * P (K).Rz then
                           declare
                              Ax : constant Float := (Px - P (K).X) * Inv (K).Rx;
                              Ay : constant Float := (Py - P (K).Y) * Inv (K).Ry;
                              Az : constant Float := (Pz - P (K).Z) * Inv (K).Rz;
                              D  : constant Float := Ax * Ax + Ay * Ay + Az * Az;
                           begin
                              if D < 1.0 + Lump then
                                 if D >= 1.0 - Lump and then not Known then
                                    Nz := Perlin_3 (T.Seed, Float (X) / Wave, Float (Y) / Wave, Float (Z) / Wave);
                                    Known := True;
                                 end if;
                                 if D < 1.0 - Lump or else D < 1.0 + Lump * Nz then
                                    Put (G, X0, Y0, X, Y, Z, T.Leaf, Foliage, Hi);
                                    exit;
                                 end if;
                              end if;
                           end;
                        end if;
                     end loop;
                  end;
               end loop;
            end loop;
         end loop;
      end Fill;

   begin
      if Xa > Xb or else Ya > Yb then
         return;
      end if;

      --  Trunk, rooted two blocks into the ground.
      if Part = Trunk_Part then
         for Z in T.Bz - 2 .. Top loop
            for X in T.Bx .. T.Bx + T.Trunk_W - 1 loop
               for Y in T.By .. T.By + T.Trunk_W - 1 loop
                  Put (G, X0, Y0, X, Y, Z, T.Bark, Wood, Hi);
               end loop;
            end loop;
         end loop;
         return;
      end if;

      case T.Kind is
         when Spruce =>
            --  A cone of whorls: each widest at its foot and drawn in above,
            --  hanging lower the further out it reaches, its boughs in five
            --  lobes that turn from whorl to whorl; a spire on top.
            declare
               Z_Base : constant Integer := T.Bz + T.Trunk_H / 4;
               Z_Tip  : constant Integer := Top + 3;
               Span   : constant Float   := Float (Z_Tip - Z_Base);
               Whorls : constant Float   := Float'Max (4.0, Float'Rounding (Span / Spruce_Whorl_B));
               Turn_C, Turn_S : array (0 .. 31) of Float;
               Rmax   : constant Integer := Integer (Float (R) * (Spruce_Girth * (1.0 + Spruce_Lobe))) + 3;
            begin
               for I in Turn_C'Range loop
                  Turn_C (I) := Cos (Tau * U (40 + I));
                  Turn_S (I) := Sin (Tau * U (40 + I));
               end loop;
               for Z in Integer'Max (1, Z_Base) .. Integer'Min (Height_B - 1, Z_Tip) loop
                  for X in Integer'Max (Xa, T.Bx - Rmax) .. Integer'Min (Xb, T.Bx + T.Trunk_W + Rmax) loop
                     for Y in Integer'Max (Ya, T.By - Rmax) .. Integer'Min (Yb, T.By + T.Trunk_W + Rmax) loop
                        declare
                           Dx : constant Float := Float (X) + 0.5 - Tx;
                           Dy : constant Float := Float (Y) + 0.5 - Ty;
                           Rr : constant Float := Sqrt (Dx * Dx + Dy * Dy);
                           Zf : constant Float := Float (Z) + 0.5 + Spruce_Droop * Rr;   --  the profile, read higher further out
                           Tz : constant Float := (Zf - Float (Z_Base)) / Span;
                        begin
                           if Rr < 0.8 then
                              Put (G, X0, Y0, X, Y, Z, T.Leaf, Foliage, Hi);       --  round the trunk, and the spire
                           elsif Tz < 1.0 then
                              declare
                                 Tt   : constant Float := Tz * Whorls + 0.3;
                                 Wi   : constant Integer := Integer'Min (31, Integer (Float'Floor (Tt)));
                                 Tier : constant Float := Tt - Float'Floor (Tt);
                                 C0   : constant Float := Dx / Rr;
                                 S0   : constant Float := Dy / Rr;
                                 C    : constant Float := C0 * Turn_C (Wi) - S0 * Turn_S (Wi);
                                 C5   : constant Float := ((16.0 * C * C - 20.0) * C * C + 5.0) * C;   --  cos of five times the angle
                                 Rad  : constant Float :=
                                   Spruce_Girth * Fr * (1.0 - Tz) * (1.0 - Spruce_Tier * Tier) * (1.0 + Spruce_Lobe * C5) + 0.8;
                              begin
                                 if Rr < Rad then
                                    Put (G, X0, Y0, X, Y, Z, T.Leaf, Foliage, Hi);
                                 end if;
                              end;
                           end if;
                        end;
                     end loop;
                  end loop;
               end loop;
            end;

         when Aspen =>
            --  Slim: small puffs up the top half of the trunk, each a little
            --  to one side of it and the next to another, so the pale trunk
            --  shows between them; one on top.
            declare
               Z_Lo : constant Float := Fz + 0.48 * Fh;
               Z_Hi : constant Float := Ft + 1.0;
               Np   : constant Positive := 5 + Integer (Float'Floor (2.99 * U (2)));
               A0   : constant Float := Tau * U (5);
            begin
               for K in 1 .. Np loop
                  declare
                     B   : constant Integer := 10 * K;
                     Tz  : constant Float := (Float (K) - 0.5) / Float (Np);
                     Mid : constant Float := 1.0 - 0.45 * abs (2.0 * Tz - 1.0);   --  fullest half way up
                     A   : constant Float := A0 + 2.4 * Float (K);
                     Off : constant Float := Fr * (0.22 + 0.30 * U (B)) * (0.6 + 0.4 * Mid);
                     Z   : constant Float := Z_Lo + (Z_Hi - Z_Lo) * Tz;
                  begin
                     Add (Tx + Off * Cos (A), Ty + Off * Sin (A), Z,
                          Fr * (0.74 + 0.30 * Mid) * (0.9 + 0.2 * U (B + 2)),
                          Fr * (0.74 + 0.30 * Mid) * (0.9 + 0.2 * U (B + 3)),
                          (Z_Hi - Z_Lo) / Float (Np) * (0.78 + 0.2 * U (B + 4)), 0.8);
                     Line (G, X0, Y0, Tx, Ty, Z - 1.0, P (N).X, P (N).Y, Z, T.Bark, Hi);
                  end;
               end loop;
               Add (Tx, Ty, Ft + 1.5, Fr * 0.62, Fr * 0.62, 2.6, 0.9);
               Fill (Lump => 0.22, Wave => 2.5);
            end;

         when Pine =>
            --  A bare bole with a dead stub or two, and high up a few flat
            --  plates of needles on boughs that bend up to them.
            declare
               Np : constant Positive := 3 + Integer (Float'Floor (2.99 * U (2)));
               A0 : constant Float := Tau * U (5);
            begin
               Add (Tx + Fr * 0.2 * (U (6) - 0.5), Ty + Fr * 0.2 * (U (7) - 0.5), Ft + 0.8,
                    Fr * (0.66 + 0.16 * U (11)), Fr * (0.66 + 0.16 * U (12)), Fr * (0.26 + 0.06 * U (13)), 0.40);
               for K in 2 .. Np loop
                  declare
                     B  : constant Integer := 10 * K;
                     A  : constant Float := A0 + Tau * (Float (K - 2) / Float (Np - 1) + 0.25 * U (B));
                     Sp : constant Float := Fr * (0.50 + 0.35 * U (B + 1));
                  begin
                     Add (Tx + Sp * Cos (A), Ty + Sp * Sin (A), Ft - Fr * (0.10 + 0.50 * U (B + 2)),
                          Fr * (0.44 + 0.18 * U (B + 3)), Fr * (0.44 + 0.18 * U (B + 4)),
                          Float'Max (1.5, Fr * (0.18 + 0.06 * U (B + 5))), 0.40);
                     Bough (Tx, Ty, Ft - Fr * (0.55 + 0.40 * U (B + 6)), P (N).X, P (N).Y, P (N).Z - 0.2 * P (N).Rz);
                  end;
               end loop;
               for K in 1 .. 2 + Integer (Float'Floor (1.99 * U (60))) loop      --  dead stubs on the bole
                  declare
                     A : constant Float := Tau * U (60 + K);
                     Z : constant Float := Fz + Fh * (0.42 + 0.30 * U (64 + K));
                     L : constant Float := 2.0 + 1.6 * U (68 + K);
                  begin
                     Line (G, X0, Y0, Tx, Ty, Z, Tx + L * Cos (A), Ty + L * Sin (A), Z + 1.0, T.Bark, Hi);
                  end;
               end loop;
               Fill (Lump => 0.22, Wave => 3.0);
            end;

         when Broadleaf | Apple =>
            --  A dome over the trunk and a ring of puffs round it, each on a
            --  bough.  Three habits: wide and low (an oak; every apple),
            --  tall (domes stacked up the leader), ragged (fewer, of every
            --  size, the whole of it leaning one way).
            declare
               Shape  : constant Float := (if T.Kind = Apple then 0.0 else U (1));
               Wide   : constant Boolean := Shape < 0.4;
               Tall   : constant Boolean := Shape >= 0.4 and then Shape < 0.7;
               Ring   : constant Positive :=
                 (if T.Kind = Apple then 3 + Integer (Float'Floor (1.99 * U (2)))
                  elsif Wide then 4 + Integer (Float'Floor (2.99 * U (2)))
                  elsif Tall then 3 + Integer (Float'Floor (1.99 * U (2)))
                  else 3 + Integer (Float'Floor (2.99 * U (2))));
               A0     : constant Float := Tau * U (5);
               Lean_A : constant Float := Tau * U (3);
               Lean   : constant Float := (if Wide or else Tall then 0.0 else Fr * (0.18 + 0.17 * U (4)));
               Lx     : constant Float := Lean * Cos (Lean_A);
               Ly     : constant Float := Lean * Sin (Lean_A);
               --  the lowest bough leaves here (an apple's from the top of its
               --  short trunk, so that there is room to stand under it and pick)
               Fork_Z : constant Float := (if T.Kind = Apple then Ft - 1.0 else Fz + Fh * 0.62);
            begin
               if Wide then
                  Add (Tx, Ty, Ft + 0.05 * Fr, Fr * (0.62 + 0.12 * U (11)), Fr * (0.62 + 0.12 * U (12)),
                       Fr * (0.52 + 0.08 * U (13)), 0.50);
                  for K in 1 .. 2 loop                       --  and two smaller ones on its shoulders
                     declare
                        A : constant Float := Tau * (U (16) + 0.5 * Float (K) + 0.15 * U (16 + K));
                     begin
                        Add (Tx + Fr * 0.32 * Cos (A), Ty + Fr * 0.32 * Sin (A), Ft + Fr * (0.34 + 0.14 * U (18 + K)),
                             Fr * (0.28 + 0.08 * U (20 + K)), Fr * (0.28 + 0.08 * U (22 + K)), Fr * 0.26, 0.50);
                     end;
                  end loop;
               elsif Tall then
                  Add (Tx, Ty, Ft + 0.15 * Fr, Fr * (0.54 + 0.08 * U (11)), Fr * (0.54 + 0.08 * U (12)), Fr * 0.58, 0.55);
                  Add (Tx + Fr * 0.12 * (U (14) - 0.5), Ty + Fr * 0.12 * (U (15) - 0.5), Ft + 0.62 * Fr,
                       Fr * 0.44, Fr * 0.44, Fr * 0.48, 0.55);
                  Add (Tx, Ty, Ft + 0.98 * Fr, Fr * 0.28, Fr * 0.28, Fr * 0.32, 0.60);
               else
                  Add (Tx + Lx, Ty + Ly, Ft + 0.20 * Fr, Fr * (0.50 + 0.10 * U (11)), Fr * (0.50 + 0.10 * U (12)),
                       Fr * 0.46, 0.45);
                  Bough (Tx, Ty, Ft - 0.2 * Fr, Tx + Lx, Ty + Ly, Ft + 0.10 * Fr);
               end if;
               Twigs (1, 3, 100);
               for K in 1 .. Ring loop
                  declare
                     B  : constant Integer := 10 * (K + 1);
                     A  : constant Float := A0 + Tau * (Float (K - 1) + 0.5 * (U (B) - 0.5)) / Float (Ring);
                     Sp : constant Float :=
                       Fr * (if Wide then 0.55 + 0.17 * U (B + 1)
                             elsif Tall then 0.34 + 0.14 * U (B + 1)
                             else 0.34 + 0.26 * U (B + 1));
                     Dz : constant Float :=
                       Fr * (if T.Kind = Apple then -0.10 + 0.25 * U (B + 2)
                             elsif Wide then -0.45 + 0.30 * U (B + 2)
                             elsif Tall then -0.55 + 0.50 * U (B + 2)
                             else -0.45 + 0.80 * U (B + 2));
                     Rr : constant Float :=
                       Fr * (if Wide then 0.40 + 0.10 * U (B + 3)
                             elsif Tall then 0.36 + 0.09 * U (B + 3)
                             else 0.28 + 0.18 * U (B + 3));
                     Rz : constant Float := Rr * (if T.Kind = Apple then 1.10 elsif Tall then 0.95 else 0.85);
                  begin
                     --  (an apple's hang low round its short trunk, on boughs that do not)
                     Add (Tx + 0.6 * Lx + Sp * Cos (A), Ty + 0.6 * Ly + Sp * Sin (A), Ft + Dz,
                          Rr * (0.9 + 0.2 * U (B + 4)), Rr * (0.9 + 0.2 * U (B + 5)), Rz,
                          (if T.Kind = Apple then 0.90 else 0.60));
                     Bough (Tx, Ty, Float'Min (Fork_Z + Fh * 0.06 * Float (K - 1), Ft - 1.0),
                            P (N).X, P (N).Y, P (N).Z - 0.15 * P (N).Rz);
                     Twigs (N, 2, 100 + 20 * K);
                  end;
               end loop;
               Fill (Lump => Crown_Lump, Wave => Crown_Wave);
            end;
      end case;
   end Draw_Tree;

   ---------------
   -- Draw_Lump --
   ---------------

   procedure Draw_Lump (L : Lump; X0, Y0 : Integer; G : in out Stack_Grid; Hi : in out Integer) is
      Xa : constant Integer := Integer'Max (X0, L.Cx - L.Rh - 1);
      Xb : constant Integer := Integer'Min (X0 + Chunk_B - 1, L.Cx + L.Rh + 1);
      Ya : constant Integer := Integer'Max (Y0, L.Cy - L.Rh - 1);
      Yb : constant Integer := Integer'Min (Y0 + Chunk_B - 1, L.Cy + L.Rh + 1);
      Rh : constant Float   := Float (L.Rh) + 0.5;
      Rv : constant Float   := Float (L.Rv) + 0.5;
   begin
      if Xa > Xb or else Ya > Yb then
         return;
      end if;
      for Z in Integer'Max (1, L.Cz - L.Rv - 1) .. Integer'Min (Height_B - 1, L.Cz + L.Rv + 1) loop
         for X in Xa .. Xb loop
            for Y in Ya .. Yb loop
               declare
                  Dx : constant Float := Float (X - L.Cx) / Rh;
                  Dy : constant Float := Float (Y - L.Cy) / Rh;
                  Dz : constant Float := Float (Z - L.Cz) / Rv;
                  J  : constant Float :=
                    (if L.Kind = Rock
                     then 1.0 + 0.45 * Perlin_3 (L.Seed, Float (X) / 2.5, Float (Y) / 2.5, Float (Z) / 2.5)
                     else 1.0 + 0.4 * (Unit_3 (L.Seed, X, Y, Z) - 0.5));
               begin
                  if Dx * Dx + Dy * Dy + Dz * Dz < J then
                     if L.Kind = Rock then
                        Put (G, X0, Y0, X, Y, Z, Boulder, Stone, Hi);
                     else
                        Put (G, X0, Y0, X, Y, Z, Berry_Bush, Foliage, Hi);
                     end if;
                  end if;
               end;
            end loop;
         end loop;
      end loop;
   end Draw_Lump;

   -----------------
   -- Tree_Blocks --
   -----------------

   procedure Tree_Blocks
     (T     : Tree;
      Visit : not null access procedure (Bx, By, Bz : Integer; M : Material))
   is
      procedure Free is new Ada.Unchecked_Deallocation (Stack_Grid, Stack_Grid_Access);
      Margin : constant Integer := Tree_Reach;   --  no crown reaches further (Decorate relies on it too)
      Z_Lo   : constant Integer := Integer'Max (1, T.Bz - 2);
      Z_Hi   : constant Integer := Integer'Min (Height_B - 1, T.Bz + T.Trunk_H + Tree_Reach);
      G      : Stack_Grid_Access;
   begin
      if not T.Valid then
         return;
      end if;
      G := new Stack_Grid;
      for CX in Floor_Div (T.Bx - Margin, Chunk_B) .. Floor_Div (T.Bx + T.Trunk_W + Margin, Chunk_B) loop
         for CY in Floor_Div (T.By - Margin, Chunk_B) .. Floor_Div (T.By + T.Trunk_W + Margin, Chunk_B) loop
            declare
               X0 : constant Integer := CX * Chunk_B;
               Y0 : constant Integer := CY * Chunk_B;
               Hi : Integer := 0;
            begin
               for X in 0 .. Chunk_B - 1 loop
                  for Y in 0 .. Chunk_B - 1 loop
                     for Z in Z_Lo .. Z_Hi loop
                        G (X, Y, Z) := Air_Block;
                     end loop;
                  end loop;
               end loop;
               Draw_Tree (T, X0, Y0, G.all, Hi, Trunk_Part);
               Draw_Tree (T, X0, Y0, G.all, Hi, Crown_Part);
               for X in 0 .. Chunk_B - 1 loop
                  for Y in 0 .. Chunk_B - 1 loop
                     for Z in Z_Lo .. Integer'Min (Hi, Z_Hi) loop
                        if G (X, Y, Z).Mat /= Air then
                           Visit (X0 + X, Y0 + Y, Z, G (X, Y, Z).Mat);
                        end if;
                     end loop;
                  end loop;
               end loop;
            end;
         end loop;
      end loop;
      Free (G);
   end Tree_Blocks;

   --------------
   -- Decorate --
   --------------

   procedure Decorate
     (W      : World;
      X0, Y0 : Integer;
      G      : in out Stack_Grid;
      Top    : in out Integer;
      Clear  : access function (Bx, By : Integer) return Boolean := null)
   is
      X1 : constant Integer := X0 + Chunk_B - 1;
      Y1 : constant Integer := Y0 + Chunk_B - 1;
   begin
      for J in Floor_Div (Y0 - Rock_Reach, Rock_Cell) .. Floor_Div (Y1 + Rock_Reach, Rock_Cell) loop
         for I in Floor_Div (X0 - Rock_Reach, Rock_Cell) .. Floor_Div (X1 + Rock_Reach, Rock_Cell) loop
            declare
               L : constant Lump := Boulder_At (W, I, J);
            begin
               if L.Valid and then (Clear = null or else not Clear (L.Cx, L.Cy)) then
                  Draw_Lump (L, X0, Y0, G, Top);
               end if;
            end;
         end loop;
      end loop;

      declare
         I0 : constant Integer := Floor_Div (X0 - Tree_Reach, Tree_Cell);
         I1 : constant Integer := Floor_Div (X1 + Tree_Reach, Tree_Cell);
         J0 : constant Integer := Floor_Div (Y0 - Tree_Reach, Tree_Cell);
         J1 : constant Integer := Floor_Div (Y1 + Tree_Reach, Tree_Cell);
         Near : array (I0 .. I1, J0 .. J1) of Tree;
      begin
         for J in J0 .. J1 loop
            for I in I0 .. I1 loop
               Near (I, J) := Tree_At (W, I, J);
               if Near (I, J).Valid and then Clear /= null and then Clear (Near (I, J).Bx, Near (I, J).By) then
                  Near (I, J).Valid := False;
               end if;
            end loop;
         end loop;
         for Part in Tree_Part loop          --  every trunk, then every crown (see Tree_Part)
            for J in J0 .. J1 loop
               for I in I0 .. I1 loop
                  if Near (I, J).Valid then
                     Draw_Tree (Near (I, J), X0, Y0, G, Top, Part);
                  end if;
               end loop;
            end loop;
         end loop;
      end;

      for J in Floor_Div (Y0 - Bush_Reach, Bush_Cell) .. Floor_Div (Y1 + Bush_Reach, Bush_Cell) loop
         for I in Floor_Div (X0 - Bush_Reach, Bush_Cell) .. Floor_Div (X1 + Bush_Reach, Bush_Cell) loop
            declare
               L : constant Lump := Bush_At (W, I, J);
            begin
               if L.Valid and then (Clear = null or else not Clear (L.Cx, L.Cy)) then
                  Draw_Lump (L, X0, Y0, G, Top);
               end if;
            end;
         end loop;
      end loop;
   end Decorate;

end Castle.Flora;
