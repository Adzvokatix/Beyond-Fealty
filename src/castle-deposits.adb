with Ada.Text_IO;                       use Ada.Text_IO;
with Ada.Numerics;
with Ada.Numerics.Elementary_Functions; use Ada.Numerics.Elementary_Functions;
with Ada.Unchecked_Deallocation;
with Interfaces;                        use Interfaces;
with Castle.Fields;                     use Castle.Fields;
with Castle.Hash;                       use Castle.Hash;
with Castle.Noise;                      use Castle.Noise;
with Castle.Text;                       use Castle.Text;
with Castle.Geology;

package body Castle.Deposits is

   Max_Deposits : constant := 255;     --  a brick names its deposit in 8 bits
   Max_Tubes    : constant := 20_000;
   Max_Per_Vein : constant := 150;
   Pi           : constant := Ada.Numerics.Pi;

   subtype Work_List is Deposit_Array (1 .. Max_Deposits);

   type Tube_Buffer is record
      Data  : Tube_Array (1 .. Max_Tubes);
      Count : Natural := 0;
   end record;
   type Tube_Buffer_Access is access Tube_Buffer;

   procedure Free is new Ada.Unchecked_Deallocation (Deposit_Array, Deposit_Array_Access);
   procedure Free is new Ada.Unchecked_Deallocation (Tube_Array, Tube_Array_Access);
   procedure Free is new Ada.Unchecked_Deallocation (Tube_Buffer, Tube_Buffer_Access);
   procedure Free is new Ada.Unchecked_Deallocation (Tube_Starts, Tube_Starts_Access);
   procedure Free is new Ada.Unchecked_Deallocation (Tube_Items, Tube_Items_Access);

   function Is_Vein (D : Deposit) return Boolean is (D.Kind /= Bog_Iron_Patch);

   --  Eight points round a circle, as constants: world generation sticks to
   --  plain arithmetic and square roots so every machine makes the same world.
   Ring_X : constant array (0 .. 7) of Float := (1.0, 0.7071, 0.0, -0.7071, -1.0, -0.7071, 0.0, 0.7071);
   Ring_Y : constant array (0 .. 7) of Float := (0.0, 0.7071, 1.0, 0.7071, 0.0, -0.7071, -1.0, -0.7071);

   function Ore_Of (Kind : Deposit_Kind) return Material is
     (case Kind is
         when Coal_Vein      => Coal,
         when Iron_Vein      => Iron_Ore,
         when Salt_Vein      => Rock_Salt,
         when Bog_Iron_Patch => Bog_Iron);

   function Ground (W : World; X, Y : Float) return Float is
     (Sample (W.Height.all, Float'Max (0.5, Float'Min (Float (N) - 0.5, X)),
                            Float'Max (0.5, Float'Min (Float (N) - 0.5, Y))));

   procedure Direction (H : U64; C, S : out Float) is
      U : constant Float := 2.0 * Unit (H) - 1.0;
      V : constant Float := 2.0 * Unit (Mix (H)) - 1.0;
      L : constant Float := Sqrt (U * U + V * V);
   begin
      if L < 0.05 then
         C := 1.0;
         S := 0.0;
      else
         C := U / L;
         S := V / L;
      end if;
   end Direction;

   -------------
   -- Queries --
   -------------

   function Touches (D : Deposit; Xm, Ym : Float) return Boolean is
   begin
      if Is_Vein (D) then
         return Xm >= D.X0 and then Xm <= D.X1 and then Ym >= D.Y0 and then Ym <= D.Y1;
      end if;
      return (Xm - D.Cx) ** 2 + (Ym - D.Cy) ** 2 < D.Radius ** 2;
   end Touches;

   function Float_Share (D : Deposit; Xm, Ym : Float) return Float is
      R : constant Float := Sqrt ((Xm - D.Cx) ** 2 + (Ym - D.Cy) ** 2);
   begin
      if not Is_Vein (D) or else R >= Float_Radius_M then
         return 0.0;
      end if;
      return 0.4 * (1.0 - R / Float_Radius_M) ** 2;
   end Float_Share;

   function Patch_Thickness (D : Deposit; Xm, Ym : Float) return Float is
      R : constant Float := Sqrt ((Xm - D.Cx) ** 2 + (Ym - D.Cy) ** 2) / D.Radius;
   begin
      if R >= 1.0 then
         return 0.0;
      end if;
      return D.Thick * (1.0 - R * R) * (0.75 + 0.25 * Perlin_2 (D.Seed, Xm / 8.0, Ym / 8.0));
   end Patch_Thickness;

   function Tube_Length (T : Vein_Tube) return Float is
     (Sqrt ((T.Bx - T.Ax) ** 2 + (T.By - T.Ay) ** 2 + (T.Bz - T.Az) ** 2));

   function Inside (T : Vein_Tube; X, Y, Z : Float) return Float is
      Ux : constant Float := T.Bx - T.Ax;
      Uy : constant Float := T.By - T.Ay;
      Uz : constant Float := T.Bz - T.Az;
      L2 : constant Float := Ux * Ux + Uy * Uy + Uz * Uz;
      F  : Float :=
        (if L2 > 0.0 then ((X - T.Ax) * Ux + (Y - T.Ay) * Uy + (Z - T.Az) * Uz) / L2 else 0.0);
   begin
      F := Float'Max (0.0, Float'Min (1.0, F));
      declare
         Px : constant Float := T.Ax + F * Ux - X;
         Py : constant Float := T.Ay + F * Uy - Y;
         Pz : constant Float := T.Az + F * Uz - Z;
      begin
         return T.Ra + (T.Rb - T.Ra) * F - Sqrt (Px * Px + Py * Py + Pz * Pz);
      end;
   end Inside;

   --  Distance on the map from (X, Y) to the tube's axis.
   function Map_Distance (T : Vein_Tube; X, Y : Float) return Float is
      Ux : constant Float := T.Bx - T.Ax;
      Uy : constant Float := T.By - T.Ay;
      L2 : constant Float := Ux * Ux + Uy * Uy;
      F  : Float := (if L2 > 0.0 then ((X - T.Ax) * Ux + (Y - T.Ay) * Uy) / L2 else 0.0);
   begin
      F := Float'Max (0.0, Float'Min (1.0, F));
      return Sqrt ((T.Ax + F * Ux - X) ** 2 + (T.Ay + F * Uy - Y) ** 2);
   end Map_Distance;

   function Tube_Cell (M : Float) return Integer is
     (Integer'Max (0, Integer'Min (Tube_N - 1, Floor_I (M) / Tube_Cell_M)));

   procedure Gather (W : World; Xm, Ym, Margin : Float; Near : out Near_Tubes) is
   begin
      Near.Count := 0;
      if W.Tubes = null or else W.Tube_Start = null then
         return;
      end if;
      declare
         C : constant Natural := Tube_Cell (Ym) * Tube_N + Tube_Cell (Xm);
      begin
         for K in W.Tube_Start (C) .. W.Tube_Start (C + 1) - 1 loop
            declare
               Id : constant Positive := W.Tube_Item (K);
               T  : Vein_Tube renames W.Tubes (Id);
            begin
               if Near.Count < Max_Near
                 and then Map_Distance (T, Xm, Ym) <= Float'Max (T.Ra, T.Rb) + Margin
               then
                  Near.Count := Near.Count + 1;
                  Near.Ids (Near.Count) := Id;
               end if;
            end;
         end loop;
      end;
   end Gather;

   ----------
   -- Grow --
   ----------

   --  Grow the root system of vein D (outcrop, heading and trunk radius set)
   --  into Buf, as deposit Owner.  The trunk starts just above the ground
   --  at the outcrop and dives into the hill.  Every step turns a little
   --  (a correlated random walk, so the tubes snake rather than zigzag) and
   --  steers toward a band of cover that deepens with distance from the
   --  outcrop, so a vein follows the hill down instead of sinking to the
   --  bedrock and running flat along it.  Tubes taper as they go; a
   --  thick enough tube sometimes splits off a thinner branch.  Plain
   --  arithmetic and square roots only, so every machine grows the same vein.
   procedure Grow (W : World; D : in out Deposit; Owner : Positive;
                   Buf : in out Tube_Buffer; Ok : out Boolean)
   is
      type Tip is record
         X, Y, Z    : Float := 0.0;
         Dx, Dy, Dz : Float := 0.0;   --  unit direction
         R, Path    : Float := 0.0;
         Turn       : Float := 0.0;   --  turning tendency, -1 .. 1
         Parent     : Natural := 0;   --  tube that ends at the tip
      end record;

      Stack    : array (1 .. 48) of Tip;
      Top      : Natural := 0;
      Ends     : array (1 .. 64) of Natural := (others => 0);   --  last tube of each branch
      Ends_N   : Natural := 0;
      First    : constant Positive := Buf.Count + 1;
      Step     : Natural := 0;
      Max_Path : constant Float :=
        (case D.Kind is when Coal_Vein => 110.0, when Iron_Vein => 95.0, when others => 80.0);

      function U (K : Integer) return Float is (Unit (Hash_2 (D.Seed, Step, K)));

      procedure Normalize (X, Y, Z : in out Float) is
         L : constant Float := Sqrt (X * X + Y * Y + Z * Z);
      begin
         if L > 1.0E-6 then
            X := X / L;
            Y := Y / L;
            Z := Z / L;
         else
            X := 0.0;
            Y := 0.0;
            Z := -1.0;
         end if;
      end Normalize;

   begin
      declare
         G0   : constant Float := Ground (W, D.Cx, D.Cy);
         Down : constant Float := 0.45 + 0.25 * Unit (Mix (D.Seed + 5));
         Hz   : constant Float := Sqrt (1.0 - Down * Down);
      begin
         Top := 1;
         Stack (1) := (X => D.Cx, Y => D.Cy, Z => G0 + 0.4,
                       Dx => D.Ca * Hz, Dy => D.Sa * Hz, Dz => -Down,
                       R => D.Radius, Path => 0.0, Turn => 0.0, Parent => 0);
      end;

      while Top > 0 loop
         declare
            T : Tip := Stack (Top);
         begin
            Top := Top - 1;
            Branch :
            loop
               Step := Step + 1;
               declare
                  L          : constant Float := 2.0 + 2.0 * U (1);
                  Hl         : constant Float := Sqrt (T.Dx * T.Dx + T.Dy * T.Dy);
                  Sx         : constant Float := (if Hl > 0.05 then -T.Dy / Hl else 1.0);
                  Sy         : constant Float := (if Hl > 0.05 then T.Dx / Hl else 0.0);
                  Nx, Ny, Nz : Float;
               begin
                  T.Turn := 0.65 * T.Turn + 0.35 * (2.0 * U (2) - 1.0);
                  declare
                     G     : constant Float := Ground (W, T.X, T.Y);
                     Want  : constant Float :=
                       Float'Min (Float'Min (30.0, 0.7 * G), 4.0 + 0.25 * T.Path);   --  cover sought here
                     Cover : constant Float := G - T.Z;
                     Aim   : constant Float :=                                       --  dip to steer toward
                       (if Cover < Want - 3.0 then -0.5 elsif Cover > Want + 3.0 then 0.15 else -0.1);
                  begin
                     Nx := T.Dx + 0.6 * T.Turn * Sx;
                     Ny := T.Dy + 0.6 * T.Turn * Sy;
                     Nz := T.Dz + 0.3 * (Aim - T.Dz) + 0.12 * (2.0 * U (3) - 1.0);
                  end;
                  Normalize (Nx, Ny, Nz);
                  declare
                     Ex : constant Float := T.X + Nx * L;
                     Ey : constant Float := T.Y + Ny * L;
                     Ez : constant Float := T.Z + Nz * L;
                  begin
                     if T.Path > 3.0 and then Ground (W, Ex, Ey) - Ez < 2.0 + T.R then
                        Nz := Nz - 0.5;                      --  away from the surface
                        Normalize (Nx, Ny, Nz);
                     elsif Ez < 3.5 + T.R then
                        Nz := Nz + 0.5;                      --  level out over the bedrock
                        Normalize (Nx, Ny, Nz);
                     end if;
                  end;
                  declare
                     Qx : constant Float := T.X + Nx * L;
                     Qy : constant Float := T.Y + Ny * L;
                     Qz : constant Float := T.Z + Nz * L;
                     R2 : constant Float := T.R * (0.955 + 0.03 * U (4));
                  begin
                     exit Branch when
                       Qx < 8.0 or else Qy < 8.0
                       or else Qx > Float (N) - 8.0 or else Qy > Float (N) - 8.0
                       or else Qz < 2.0 + R2
                       or else Buf.Count >= Max_Tubes
                       or else Buf.Count - First + 1 >= Max_Per_Vein
                       or else (T.Path > 3.0 and then Ground (W, Qx, Qy) - Qz < 0.75 + R2);
                     Buf.Count := Buf.Count + 1;
                     Buf.Data (Buf.Count) :=
                       (Ax => T.X, Ay => T.Y, Az => T.Z, Bx => Qx, By => Qy, Bz => Qz,
                        Ra => T.R, Rb => R2, Owner => Owner, Parent => T.Parent,
                        Path => T.Path, Silver => 0.0, Gold => 0.0);
                     T := (X => Qx, Y => Qy, Z => Qz, Dx => Nx, Dy => Ny, Dz => Nz,
                           R => R2, Path => T.Path + L, Turn => T.Turn, Parent => Buf.Count);

                     if T.R > 0.6 and then T.Path > 6.0 and then Top < Stack'Last
                       and then U (5) < 0.2
                     then
                        declare
                           Spread     : constant Float :=
                             (if U (6) < 0.5 then -1.0 else 1.0) * (0.8 + 0.8 * U (7));
                           Bx, By, Bz : Float;
                        begin
                           Bx := Nx + Spread * Sx;
                           By := Ny + Spread * Sy;
                           Bz := Nz - 0.45 + 0.9 * U (8);   --  roots spread up and down too
                           Normalize (Bx, By, Bz);
                           Top := Top + 1;
                           Stack (Top) := (X => Qx, Y => Qy, Z => Qz, Dx => Bx, Dy => By, Dz => Bz,
                                           R => T.R * (0.55 + 0.2 * U (9)), Path => T.Path,
                                           Turn => -T.Turn, Parent => Buf.Count);
                        end;
                     end if;
                     exit Branch when T.R < 0.4 or else T.Path > Max_Path;
                  end;
               end;
            end loop Branch;
            if T.Parent >= First and then Ends_N < Ends'Last then
               Ends_N := Ends_N + 1;
               Ends (Ends_N) := T.Parent;
            end if;
         end;
      end loop;

      Ok := Buf.Count - First + 1 >= 10;
      if not Ok then
         Buf.Count := First - 1;
         return;
      end if;

      D.First_Tube := First;
      D.Last_Tube  := Buf.Count;
      D.X0 := D.Cx - Float_Radius_M;
      D.X1 := D.Cx + Float_Radius_M;
      D.Y0 := D.Cy - Float_Radius_M;
      D.Y1 := D.Cy + Float_Radius_M;
      for K in First .. Buf.Count loop
         declare
            T  : Vein_Tube renames Buf.Data (K);
            Rm : constant Float := Float'Max (T.Ra, T.Rb);
         begin
            D.X0 := Float'Min (D.X0, Float'Min (T.Ax, T.Bx) - Rm);
            D.X1 := Float'Max (D.X1, Float'Max (T.Ax, T.Bx) + Rm);
            D.Y0 := Float'Min (D.Y0, Float'Min (T.Ay, T.By) - Rm);
            D.Y1 := Float'Max (D.Y1, Float'Max (T.Ay, T.By) + Rm);
            D.Reach := Float'Max (D.Reach, T.Path + Tube_Length (T));
            D.Deepest := Float'Max (D.Deepest, Ground (W, T.Bx, T.By) - T.Bz);
         end;
      end loop;

      --  Silver and gold: in branch ends deep and far enough in, and up to
      --  two tubes back along the branch, thinning out toward the outcrop.
      declare
         Odds  : constant Precious_Odds := Precious (D.Kind);
         Boost : constant Float := 1.0 + Castle.Geology.Gold_District (W, D.Cx, D.Cy);
         Has_S : constant Boolean := Unit (Mix (D.Seed + 11)) < Odds.Silver_Chance;
         Has_G : constant Boolean := Unit (Mix (D.Seed + 12)) < Odds.Gold_Chance * Boost;
         Least : Float := 1.0E9;
      begin
         if Has_S or else Has_G then
            for E in 1 .. Ends_N loop
               declare
                  Us   : constant Float := Unit (Mix (D.Seed + U64 (100 + E)));
                  Ug   : constant Float := Unit (Mix (D.Seed + U64 (300 + E)));
                  Cur  : Natural := Ends (E);
                  Ramp : Float := 1.0;
               begin
                  for Hop in 1 .. 3 loop
                     exit when Cur < First;
                     declare
                        T     : Vein_Tube renames Buf.Data (Cur);
                        Cover : constant Float :=
                          Float'Min (Ground (W, T.Ax, T.Ay) - T.Az - T.Ra,
                                     Ground (W, T.Bx, T.By) - T.Bz - T.Rb);
                     begin
                        exit when T.Path < Min_Precious_Reach_M or else Cover < Min_Precious_Cover_M;
                        if Has_S and then Us < 0.7 then
                           T.Silver := Float'Max (T.Silver, Odds.Silver_Share * Ramp);
                        end if;
                        if Has_G and then Ug < 0.6 then
                           T.Gold := Float'Max (T.Gold, Odds.Gold_Share * Ramp);
                        end if;
                        if T.Silver + T.Gold > 0.0 then
                           Least := Float'Min (Least, Cover);
                        end if;
                        Cur  := T.Parent;
                        Ramp := Ramp * 0.6;
                     end;
                  end loop;
               end;
            end loop;
         end if;
         D.Precious_Cover := (if Least < 1.0E8 then Least else 0.0);
      end;

      for K in First .. Buf.Count loop
         declare
            T : Vein_Tube renames Buf.Data (K);
            V : constant Float := Pi * ((T.Ra + T.Rb) * 0.5) ** 2 * Tube_Length (T);
         begin
            D.Reserves   := D.Reserves + V * (1.0 - T.Silver - T.Gold);
            D.Silver_Vol := D.Silver_Vol + V * T.Silver;
            D.Gold_Vol   := D.Gold_Vol + V * T.Gold;
         end;
      end loop;
   end Grow;

   -----------
   -- Place --
   -----------

   procedure Place
     (W        : World;
      List     : in out Work_List;
      Count    : in out Natural;
      Buf      : in out Tube_Buffer;
      Kind     : Deposit_Kind;
      Target   : Positive;
      Attempts : Positive)
   is
      Seed   : constant U64 := Derive (W.Seed, 1000 + Deposit_Kind'Pos (Kind));
      Placed : Natural := 0;
   begin
      for K in 1 .. Attempts loop
         exit when Placed >= Target or else Count >= Max_Deposits;
         declare
            H        : constant U64        := Hash_2 (Seed, K, 0);
            R1       : constant Float      := Unit (Mix (H + 3));
            R3       : constant Float      := Unit (Mix (H + 5));
            X        : constant Float      := 64.0 + Unit (H) * (Float (N) - 128.0);
            Y        : constant Float      := 64.0 + Unit (Mix (H + 1)) * (Float (N) - 128.0);
            Ix       : constant Integer    := Floor_I (X);
            Iy       : constant Integer    := Floor_I (Y);
            C        : constant Cell_Range := Idx (Ix, Iy);
            Gx       : constant Float :=
              At_Cell (W.Height.all, Ix + 3, Iy) - At_Cell (W.Height.all, Ix - 3, Iy);
            Gy       : constant Float :=
              At_Cell (W.Height.all, Ix, Iy + 3) - At_Cell (W.Height.all, Ix, Iy - 3);
            Gl       : constant Float      := Sqrt (Gx * Gx + Gy * Gy);
            Slope    : constant Float      := Gl / 6.0;
            Dry_Land : constant Boolean    := W.Water (C) = 0.0 and then W.Kind (C) = Dry;
            D        : Deposit;
            Ok       : Boolean := False;
         begin
            D.Kind := Kind;
            D.Cx   := X;
            D.Cy   := Y;
            D.Seed := Mix (H + 9);

            if Kind = Bog_Iron_Patch then
               Ok := Dry_Land and then W.Moisture (C) > 0.72 and then W.Height (C) < 19.0
                 and then W.Dist_Water (C) in 3.0 .. 60.0;
               D.Radius   := 8.0 + 16.0 * R1;
               D.Depth    := 0.5;
               D.Thick    := 0.3 + 0.4 * R3;
               D.Reserves := Pi * D.Radius ** 2 * D.Thick * 0.5;
               D.X0 := X - D.Radius;
               D.X1 := X + D.Radius;
               D.Y0 := Y - D.Radius;
               D.Y1 := Y + D.Radius;
            else
               Ok := Dry_Land and then
                 (case Kind is
                     when Coal_Vein =>
                        Slope in 0.04 .. 0.9 and then W.Mountain (C) < 0.4 and then W.Height (C) < 60.0,
                     when Iron_Vein =>
                        Slope in 0.04 .. 1.2 and then W.Height (C) < 150.0,
                     when others =>
                        Slope < 0.3 and then W.Mountain (C) < 0.2 and then W.Height (C) < 25.0);
               --  Into the hill: the trunk heads uphill.
               if Gl > 0.02 then
                  D.Ca := Gx / Gl;
                  D.Sa := Gy / Gl;
               else
                  Direction (Mix (H + 2), D.Ca, D.Sa);
               end if;
               D.Radius := (case Kind is
                               when Coal_Vein => 1.4 + 0.6 * R1,
                               when Iron_Vein => 1.0 + 0.5 * R1,
                               when others    => 1.6 + 0.6 * R1);

               --  The outcrop and the ground round it must be dry.
               if Ok then
                  declare
                     Wet : Natural := 0;
                  begin
                     for Q in Ring_X'Range loop
                        declare
                           Px : constant Float := X + Float_Radius_M * Ring_X (Q);
                           Py : constant Float := Y + Float_Radius_M * Ring_Y (Q);
                        begin
                           if W.Water (Idx (Clamp_Cell (Floor_I (Px)), Clamp_Cell (Floor_I (Py)))) > 0.0 then
                              Wet := Wet + 1;
                           end if;
                        end;
                     end loop;
                     Ok := Wet <= 1;
                  end;
               end if;
            end if;

            if Ok then
               for E in 1 .. Count loop
                  declare
                     O    : Deposit renames List (E);
                     Dist : constant Float := Sqrt ((O.Cx - D.Cx) ** 2 + (O.Cy - D.Cy) ** 2);
                     Need : constant Float :=
                       (if Is_Vein (O) and then Is_Vein (D)
                        then (if O.Kind = D.Kind then 80.0 else 40.0)
                        elsif O.Kind = D.Kind then O.Radius + D.Radius + 10.0
                        else 0.0);
                  begin
                     if Dist < Need then
                        Ok := False;
                        exit;
                     end if;
                  end;
               end loop;
            end if;

            if Ok and then Is_Vein (D) then
               Grow (W, D, Count + 1, Buf, Ok);
            end if;

            if Ok then
               Count        := Count + 1;
               List (Count) := D;
               Placed       := Placed + 1;
            end if;
         end;
      end loop;
   end Place;

   --------------
   -- Generate --
   --------------

   procedure Generate (W : in out World) is
      List  : Work_List;
      Count : Natural := 0;
      Buf   : Tube_Buffer_Access := new Tube_Buffer;
   begin
      Place (W, List, Count, Buf.all, Coal_Vein,      Target => 24, Attempts => 6_000);
      Place (W, List, Count, Buf.all, Iron_Vein,      Target => 16, Attempts => 6_000);
      Place (W, List, Count, Buf.all, Salt_Vein,      Target => 8,  Attempts => 6_000);
      Place (W, List, Count, Buf.all, Bog_Iron_Patch, Target => 40, Attempts => 8_000);
      if W.Deposits /= null then
         Free (W.Deposits);
      end if;
      if W.Tubes /= null then
         Free (W.Tubes);
      end if;
      W.Deposits := new Deposit_Array'(List (1 .. Count));
      W.Tubes    := new Tube_Array'(Buf.Data (1 .. Buf.Count));
      Free (Buf);
   end Generate;

   -----------------
   -- Build_Index --
   -----------------

   procedure Build_Index (W : in out World) is
      Dropped : Natural := 0;
   begin
      if W.Index = null then
         W.Index := new Deposit_Index;
      end if;
      for I in W.Index'Range (1) loop
         for J in W.Index'Range (2) loop
            W.Index (I, J).Count := 0;
         end loop;
      end loop;
      for K in W.Deposits'Range loop
         declare
            D : Deposit renames W.Deposits (K);
         begin
            for I in Index_Of (D.X0) .. Index_Of (D.X1) loop
               for J in Index_Of (D.Y0) .. Index_Of (D.Y1) loop
                  declare
                     E : Index_Entry renames W.Index (I, J);
                  begin
                     if E.Count < Max_Per_Cell then
                        E.Count           := E.Count + 1;
                        E.Items (E.Count) := K;
                     else
                        Dropped := Dropped + 1;
                     end if;
                  end;
               end loop;
            end loop;
         end;
      end loop;
      if Dropped > 0 then
         Put_Line ("    warning: deposit index full, " & Img (Dropped) & " entries dropped");
      end if;

      --  Tubes, packed per 16 m cell: count, prefix sums, fill.
      if W.Tube_Start /= null then
         Free (W.Tube_Start);
      end if;
      if W.Tube_Item /= null then
         Free (W.Tube_Item);
      end if;
      W.Tube_Start := new Tube_Starts'(others => 1);
      declare
         type Count_Array is array (0 .. Tube_N * Tube_N - 1) of Natural;
         type Count_Access is access Count_Array;
         procedure Free_Counts is new Ada.Unchecked_Deallocation (Count_Array, Count_Access);
         Counts : Count_Access := new Count_Array'(others => 0);
         Total  : Natural := 0;

         generic
            with procedure Visit (Cell : Natural; Id : Positive);
         procedure Each_Cell;
         procedure Each_Cell is
         begin
            for Id in W.Tubes'Range loop
               declare
                  T  : Vein_Tube renames W.Tubes (Id);
                  Rm : constant Float := Float'Max (T.Ra, T.Rb) + 2.0;
               begin
                  for J in Tube_Cell (Float'Min (T.Ay, T.By) - Rm) .. Tube_Cell (Float'Max (T.Ay, T.By) + Rm) loop
                     for I in Tube_Cell (Float'Min (T.Ax, T.Bx) - Rm) .. Tube_Cell (Float'Max (T.Ax, T.Bx) + Rm) loop
                        Visit (J * Tube_N + I, Id);
                     end loop;
                  end loop;
               end;
            end loop;
         end Each_Cell;

         procedure Count_One (Cell : Natural; Id : Positive) is
            pragma Unreferenced (Id);
         begin
            Counts (Cell) := Counts (Cell) + 1;
         end Count_One;

         procedure Fill_One (Cell : Natural; Id : Positive) is
         begin
            W.Tube_Item (W.Tube_Start (Cell) + Counts (Cell)) := Id;
            Counts (Cell) := Counts (Cell) + 1;
         end Fill_One;

         procedure Count_All is new Each_Cell (Count_One);
         procedure Fill_All  is new Each_Cell (Fill_One);
      begin
         Count_All;
         for C in Counts'Range loop
            W.Tube_Start (C) := Total + 1;
            Total := Total + Counts (C);
            Counts (C) := 0;
         end loop;
         W.Tube_Start (Tube_N * Tube_N) := Total + 1;
         W.Tube_Item := new Tube_Items (1 .. Integer'Max (1, Total));
         Fill_All;
         Free_Counts (Counts);
      end;
   end Build_Index;

   ------------
   -- Report --
   ------------

   procedure Report (W : World) is
      type Stat is record
         Count, Silver_N, Gold_N, Tubes : Natural := 0;
         Reserves, Silver, Gold, Reach  : Float   := 0.0;
      end record;
      Stats    : array (Deposit_Kind) of Stat;
      Name     : constant array (Deposit_Kind) of String (1 .. 10) :=
        ("coal veins", "iron veins", "salt veins", "bog iron  ");
      Rich_N   : Natural := 0;
      Shored_N : Natural := 0;
      Cover_Lo : Float   := 1.0E9;
      Cover_Hi : Float   := 0.0;
   begin
      for D of W.Deposits.all loop
         declare
            St : Stat renames Stats (D.Kind);
         begin
            St.Count    := St.Count + 1;
            St.Reserves := St.Reserves + D.Reserves;
            St.Silver   := St.Silver + D.Silver_Vol;
            St.Gold     := St.Gold + D.Gold_Vol;
            if Is_Vein (D) then
               St.Tubes := St.Tubes + D.Last_Tube - D.First_Tube + 1;
               St.Reach := St.Reach + D.Reach;
            end if;
            if D.Silver_Vol > 0.0 then
               St.Silver_N := St.Silver_N + 1;
            end if;
            if D.Gold_Vol > 0.0 then
               St.Gold_N := St.Gold_N + 1;
            end if;
         end;
         if D.Silver_Vol + D.Gold_Vol > 0.0 then
            Rich_N   := Rich_N + 1;
            Cover_Lo := Float'Min (Cover_Lo, D.Precious_Cover);
            Cover_Hi := Float'Max (Cover_Hi, D.Precious_Cover);
            --  Shoring where the shallowest rich tube lies.
            for K in D.First_Tube .. D.Last_Tube loop
               declare
                  T : Vein_Tube renames W.Tubes (K);
               begin
                  if T.Silver + T.Gold > 0.0 then
                     declare
                        BC   : constant Castle.Geology.Brick_Column :=
                          Castle.Geology.Prepare_Brick_Column
                            (W, Integer'Max (0, Integer'Min (N - 1, Floor_I (T.Ax))),
                                Integer'Max (0, Integer'Min (N - 1, Floor_I (T.Ay))));
                        Mz   : constant Integer := Integer'Max (1, Floor_I (T.Az));
                        Host : constant Material := Castle.Geology.Rock_At (W, BC, Mz).Host;
                     begin
                        if Castle.Geology.Needs_Shoring
                             (Host, D.Precious_Cover, Wet => Castle.Geology.Water_Bearing (BC, Mz))
                        then
                           Shored_N := Shored_N + 1;
                        end if;
                     end;
                     exit;
                  end if;
               end;
            end loop;
         end if;
      end loop;
      for K in Deposit_Kind loop
         declare
            St : Stat renames Stats (K);
         begin
            Put_Line ("    " & Name (K) & ": " & Img (St.Count)
                      & (if K /= Bog_Iron_Patch and then St.Count > 0
                         then " (" & Img (St.Tubes) & " tubes, reach " & Img (St.Reach / Float (St.Count), 0)
                              & " m on average)"
                         else "")
                      & ", ore " & Img (St.Reserves / 1000.0, 1) & "k m^3"
                      & (if St.Silver_N + St.Gold_N > 0
                         then "; rich tips: silver in " & Img (St.Silver_N) & " (" & Img (St.Silver, 0)
                              & " m^3), gold in " & Img (St.Gold_N) & " (" & Img (St.Gold, 0) & " m^3)"
                         else ""));
         end;
      end loop;
      if Rich_N > 0 then
         Put_Line ("    veins with silver or gold: " & Img (Rich_N) & ", from " & Img (Cover_Lo, 1)
                   & " .. " & Img (Cover_Hi, 1) & " m below ground; " & Img (Shored_N)
                   & " need shoring there");
      end if;
   end Report;

end Castle.Deposits;
