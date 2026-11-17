--  The colony without a window, on a made-up meadow: the stake raises its
--  post and the band arrives round it; a path is laid; a stockpile is
--  refused away from the path and taken beside it; bushes are found; two
--  gatherers pick and carry while the rest keep to the stake; nothing is
--  made or lost on the way; no bush is picked by two at once; bushes grow
--  back in summer and not in winter; a bush walled in is given up on, not
--  tried for ever; berries wait for a stockpile when there is none; and a
--  save taken mid-trip carries on exactly as if it had never stopped.
--  Then trees: foresters fell them (stump left, trunk and crown gone, the
--  logs left lying) and carry every log of one tree home before felling the
--  next, and no one else carries wood; every log is accounted for; apple
--  trees are spared while that order stands; the wood reserve stops the
--  felling; and a save taken mid-felling carries on as if it had never
--  stopped.  Then porters: straw cut first, up to its reserve, then stone
--  prised off a half-buried boulder (never below the grass) as much as is
--  wanted, every bit accounted for, and no water fetched; straw walled in
--  is given up on for the stone; a porter works beside a forester without
--  touching its logs; and a save taken mid-fetch carries on as if it had
--  never stopped.  Then herds: placed round the stake on walkable ground,
--  calm deer keep round their node as it drifts and they graze; someone
--  walking near panics them, a hunter stalking only when nearer; an arrow
--  scatters them, the node fleeing away from the bow, and they settle
--  round it again; fawns are born in spring and grow up; and a save taken
--  mid-panic carries on exactly.  Then hunters: they stalk, shoot and
--  kill; every deer brought down comes home and is butchered into meat and
--  a hide; no herd is hunted below Spare_Last; sparing the deer or meeting
--  the meat reserve stops the hunting; a herd behind a wall is never shot
--  at; and a save taken mid-hunt carries on exactly.
--  ./bin/debug/colony_check   (exits 1 on any failure)

with Ada.Text_IO;      use Ada.Text_IO;
with Ada.Command_Line;
with Ada.Real_Time;    use Ada.Real_Time;
with Ada.Numerics.Elementary_Functions; use Ada.Numerics.Elementary_Functions;
with Castle.Blocks;    use Castle.Blocks;
with Castle.Math;      use Castle.Math;
with Castle.Colony;    use Castle.Colony;
with Castle.Actions;
with Castle.Views;
with Castle.Text;      use Castle.Text;
with Test_World;       use Test_World;
with Castle.Herds;
with Castle.Nav;
with Castle.Buildings;
with Castle.Hash;
with Castle.Animals;
with Castle.Deer;
with Ada.Streams.Stream_IO;
with Ada.Strings.Fixed;
with Interfaces;

procedure Colony_Check is

   Fails : Natural := 0;

   procedure Check (Ok : Boolean; What : String) is
   begin
      Put_Line ((if Ok then "  ok    " else "  FAIL  ") & What);
      if not Ok then
         Fails := Fails + 1;
      end if;
   end Check;

   --  Every section starts at the pace the band worked and walked at until
   --  2026-11-12 (the sections are tuned at it: how long a trip takes, what
   --  is done by when), unless the pace is what it checks.
   --  And with the stores as they were until the same day, when the cook
   --  began to keep a pot's fill of greens from being eaten raw (the needs
   --  sections count what is eaten raw and when), unless that is what it
   --  checks.
   --  And with no cart, no salt and meat in joints, as it was until that
   --  day too (the hunting and cooking sections count joints), unless the
   --  lord's cart is what it checks.  And with every roof thatched from the
   --  ground, as it was (the housing sections are timed so), unless a
   --  section says a ladder is to be used.
   procedure Reset is
   begin
      Castle.Colony.Reset;
      Set_Pace (1.0);
      Set_Cook_Hold (False);
      Set_Curing (False);
      Set_Ladders (False);
      Set_Path_Holes (False);
      Set_Cart_Pull (False);
   end Reset;

   --  Every ladder made is stored, in somebody's arms, standing at a house, or
   --  lost with whoever carried it.
   function Ladders_Add_Up return Boolean is
      N : Natural := Stored (Ladder) + Ladders_Standing + Ladders_Lost;
   begin
      for I in 1 .. Members loop
         if Carrying (I) = Ladder then
            N := N + Carried (I);
         end if;
      end loop;
      return N = Ladders_Made;
   end Ladders_Add_Up;

   function B (M : Float) return Integer is (Integer (Float'Floor (M * 4.0)));
   function Hour_Now (H : Long_Float) return Float is (Float (H - 24.0 * Long_Float'Floor (H / 24.0)));
   function Flat (A, C : Vec3) return Float is (Sqrt ((A.X - C.X) ** 2 + (A.Y - C.Y) ** 2));

   Hours : Long_Float := 16.0 * 24.0;     --  day 16: summer

   --  A bush: a lump of berry bush blocks on the meadow round (X, Y).
   procedure Put_Bush (X, Y : Float) is
      Cx : constant Integer := B (X);
      Cy : constant Integer := B (Y);
   begin
      for Dx in -2 .. 2 loop
         for Dy in -2 .. 2 loop
            for Dz in 0 .. 2 loop
               if Float (Dx * Dx + Dy * Dy) / 6.25 + Float (Dz * Dz) / 4.0 < 1.0 then
                  Set (Cx + Dx, Cy + Dy, Ground_Row + Dz, Berry_Bush);
               end if;
            end loop;
         end loop;
      end loop;
   end Put_Bush;

   Stake_P : constant Vec3 := (20.0, 20.0, Ground_M);
   Spots   : constant array (1 .. 6) of Vec3 :=
     [(12.0, 26.0, 0.0), (28.0, 30.0, 0.0), (35.0, 14.0, 0.0), (8.0, 10.0, 0.0), (44.0, 40.0, 0.0),
      (24.0, 44.0, 0.0)];

   --  Four trees, each in the cell (of Tree_Cell_B columns square) its
   --  trunk stands in: broadleaves, a thick conifer and an apple tree, each
   --  a trunk under a cube of leaves.
   type Test_Tree is record
      I, J : Integer;
      Info : Tree_Info;
   end record;
   function In_Cell (K : Tree_Kind; Bx, By, W, H : Integer) return Test_Tree is
     ((Bx / Tree_Cell_B, By / Tree_Cell_B, (True, K, Bx, By, Ground_Row, W, H)));
   type Tree_List is array (Positive range <>) of Test_Tree;
   The_Trees : constant Tree_List :=
     [In_Cell (Broadleaf, 100, 100, 1, 16),
      In_Cell (Conifer, 62, 124, 2, 24),
      In_Cell (Apple, 122, 62, 1, 12),
      In_Cell (Broadleaf, 42, 66, 1, 18)];

   --  Two broadleaves 3 m apart, each with a branch reaching through the
   --  other's trunk (as in a thick forest, where a crown drawn on its own
   --  crosses a neighbour): felling one must leave the other's trunk whole.
   The_Pair : constant Tree_List :=
     [In_Cell (Broadleaf, 100, 100, 1, 16),
      In_Cell (Broadleaf, 112, 100, 1, 16)];
   Use_Pair : Boolean := False;

   --  A bough of every tree at one place, as a tree's shape may say it has
   --  one where a house has been built since: a column of log, rows
   --  Bough_Z0 .. Bough_Z1.
   Bough_On : Boolean := False;
   Bough_X, Bough_Y, Bough_Z0, Bough_Z1 : Integer := 0;

   function Active return Tree_List is (if Use_Pair then The_Pair else The_Trees);

   function Find (I, J : Integer) return Tree_Info is
   begin
      for T of Active loop
         if T.I = I and then T.J = J then
            return T.Info;
         end if;
      end loop;
      return (others => <>);
   end Find;

   procedure Shape (I, J : Integer; Visit : not null access procedure (Bx, By, Bz : Integer; M : Material)) is
      T : constant Tree_Info := Find (I, J);
      Top : constant Integer := T.Bz + T.Trunk_H;
   begin
      if not T.Valid then
         return;
      end if;
      for Z in T.Bz - 2 .. Top loop
         for X in T.Bx .. T.Bx + T.Trunk_W - 1 loop
            for Y in T.By .. T.By + T.Trunk_W - 1 loop
               Visit (X, Y, Z, Log);
            end loop;
         end loop;
      end loop;
      for X in T.Bx - 3 .. T.Bx + T.Trunk_W + 2 loop
         for Y in T.By - 3 .. T.By + T.Trunk_W + 2 loop
            for Z in Top - 2 .. Top + 3 loop
               if not (X in T.Bx .. T.Bx + T.Trunk_W - 1 and then Y in T.By .. T.By + T.Trunk_W - 1
                       and then Z <= Top)
               then
                  Visit (X, Y, Z, (if T.Kind = Apple then Apple_Leaves else Leaves));
               end if;
            end loop;
         end loop;
      end loop;
      if Bough_On then
         for Z in Bough_Z0 .. Bough_Z1 loop
            Visit (Bough_X, Bough_Y, Z, Log);
         end loop;
      end if;
      if Use_Pair then   --  the branch through the other tree's trunk
         declare
            Other : constant Tree_Info :=
              (if T.Bx = The_Pair (1).Info.Bx then The_Pair (2).Info else The_Pair (1).Info);
            Step  : constant Integer := (if Other.Bx > T.Bx then 1 else -1);
         begin
            for X in 1 .. abs (Other.Bx - T.Bx) loop
               Visit (T.Bx + Step * X, T.By, Top - 3, Log);
            end loop;
         end;
      end if;
   end Shape;

   procedure Grow (Bx, By, Bz : Integer; M : Material) is
   begin
      Set (Bx, By, Bz, M);
   end Grow;

   --  For the porters: a patch of tall grass, a boulder half buried in the
   --  meadow and a shallow pond (one block of water where the grass was).
   Grass_X0 : constant := 14.0;  Grass_Y0 : constant := 30.0;  Grass_X1 : constant := 17.0;  Grass_Y1 : constant := 33.0;
   Rock_X   : constant := 120;   Rock_Y   : constant := 104;   --  blocks: (30, 26) m
   Pond_X0  : constant := 36.0;  Pond_Y0  : constant := 24.0;  Pond_X1  : constant := 39.0;  Pond_Y1  : constant := 27.0;

   procedure Porter_Ground is
   begin
      Fill (Grass_X0, Grass_Y0, Grass_X1, Grass_Y1, Ground_Row, Ground_Row, Tall_Grass);
      for Dx in -3 .. 3 loop
         for Dy in -3 .. 3 loop
            for Dz in -3 .. 3 loop
               if Dx * Dx + Dy * Dy + Dz * Dz < 10 then
                  Set (Rock_X + Dx, Rock_Y + Dy, Ground_Row + Dz, Boulder);
               end if;
            end loop;
         end loop;
      end loop;
      Fill (Pond_X0, Pond_Y0, Pond_X1, Pond_Y1, Ground_Row - 1, Ground_Row - 1, Water);
      Changed_World;
   end Porter_Ground;

   function Count_In (X0, Y0, X1, Y1 : Integer; Z0, Z1 : Integer; M : Material) return Natural is
      N : Natural := 0;
   begin
      for X in X0 .. X1 loop
         for Y in Y0 .. Y1 loop
            for Z in Z0 .. Z1 loop
               if Get (X, Y, Z) = M then
                  N := N + 1;
               end if;
            end loop;
         end loop;
      end loop;
      return N;
   end Count_In;

   function Grass_Left return Natural is
     (Count_In (B (Grass_X0), B (Grass_Y0), B (Grass_X1) - 1, B (Grass_Y1) - 1, Ground_Row, Ground_Row, Tall_Grass));
   function Rock_Left return Natural is
     (Count_In (Rock_X - 3, Rock_Y - 3, Rock_X + 3, Rock_Y + 3, Ground_Row - 3, Ground_Row + 3, Boulder));
   function Water_Left return Natural is
     (Count_In (B (Pond_X0) - 1, B (Pond_Y0) - 1, B (Pond_X1), B (Pond_Y1), Ground_Row - 2, Ground_Row, Water));

   --  The meadow, six bushes, the stake, a path east and a stockpile on it.
   --  Wild vegetables: a plant every metre and a half over the south-east
   --  of the meadow, clear of the bush there.
   Veg_X0 : constant := 40.0;
   Veg_X1 : constant := 62.0;
   Veg_Y0 : constant := 2.0;
   Veg_Y1 : constant := 12.0;
   procedure Put_Vegetables is
      X : Float := Veg_X0;
      Y : Float;
   begin
      while X <= Veg_X1 loop
         Y := Veg_Y0;
         while Y <= Veg_Y1 loop
            if Get (B (X), B (Y), Ground_Row) = Air then
               Set (B (X), B (Y), Ground_Row, Wild_Vegetables);
            end if;
            Y := Y + 1.5;
         end loop;
         X := X + 1.5;
      end loop;
   end Put_Vegetables;

   --  The top of the ground at a block column (earth, a path, a wall of
   --  stones: nothing of a house), from the top of the world down.
   function Ground_Top (Bx, By : Integer) return Integer is
   begin
      for Z in reverse 1 .. H_B - 2 loop
         if Get (Bx, By, Z) in Grass | Dirt | Footpath | Fieldstone then
            return Z;
         end if;
      end loop;
      return 0;
   end Ground_Top;

   --  Round house H (its walls' box and 3 m about it, less where its walls
   --  stand): wherever the ground steps more than a block from one column
   --  to the next, the higher column is stone from a block over the lower
   --  one's top up to its own (no more than a block of earth is left to
   --  stand by itself).  Steps: how many such there are.  Bare: how many of
   --  them are not stone so.
   procedure Count_Steps (H : Positive; Steps, Bare : out Natural) is
      V  : constant House_View := House_At (H);
      X0 : constant Integer := B (Float'Min (V.Corner (1).X, V.Corner (3).X) + 0.01);
      X1 : constant Integer := B (Float'Max (V.Corner (1).X, V.Corner (3).X) - 0.01);
      Y0 : constant Integer := B (Float'Min (V.Corner (1).Y, V.Corner (3).Y) + 0.01);
      Y1 : constant Integer := B (Float'Max (V.Corner (1).Y, V.Corner (3).Y) - 0.01);
      function Walls (X, Y : Integer) return Boolean is (X in X0 .. X1 and then Y in Y0 .. Y1);
      Far : constant Natural := Natural'Max (V.Reach_L, V.Reach_R);
   begin
      Steps := 0;
      Bare := 0;
      --  (3 m about its walls, and as far again as its ground reaches over to a neighbour's)
      for X in X0 - 12 - Far .. X1 + 12 + Far loop
         for Y in Y0 - 12 - Far .. Y1 + 12 + Far loop
            if (abs (V.Corner (1).X - V.Corner (2).X) > abs (V.Corner (1).Y - V.Corner (2).Y)
                and then Y in Y0 - 12 .. Y1 + 12
                and then X in X0 - 12 - (if V.Corner (1).X < V.Corner (2).X then V.Reach_L else V.Reach_R)
                              .. X1 + 12 + (if V.Corner (1).X < V.Corner (2).X then V.Reach_R else V.Reach_L))
              or else
               (abs (V.Corner (1).X - V.Corner (2).X) <= abs (V.Corner (1).Y - V.Corner (2).Y)
                and then X in X0 - 12 .. X1 + 12
                and then Y in Y0 - 12 - (if V.Corner (1).Y < V.Corner (2).Y then V.Reach_L else V.Reach_R)
                              .. Y1 + 12 + (if V.Corner (1).Y < V.Corner (2).Y then V.Reach_R else V.Reach_L))
            then
            if not Walls (X, Y) and then House_On ((Float (X) + 0.5) * 0.25, (Float (Y) + 0.5) * 0.25) in 0 | H then
               for D in 1 .. 4 loop
                  declare
                     Nx : constant Integer := X + (case D is when 1 => 1, when 2 => -1, when others => 0);
                     Ny : constant Integer := Y + (case D is when 3 => 1, when 4 => -1, when others => 0);
                     T  : constant Integer := Ground_Top (X, Y);
                     Tn : constant Integer := (if Walls (Nx, Ny) then T else Ground_Top (Nx, Ny));
                  begin
                     if T - Tn > 1 and then Tn > 0 then
                        Steps := Steps + 1;
                        if (for some Z in Tn + 2 .. T => Get (X, Y, Z) /= Fieldstone) then
                           Bare := Bare + 1;
                        end if;
                     end if;
                  end;
               end loop;
            end if;
            end if;
         end loop;
      end loop;
   end Count_Steps;

   --  Where house H's ground reaches over to a neighbour's (Sides is added
   --  to: how many of its sides do), the columns between its wall and the
   --  neighbour's, beside its walls: those of its own yard and reach that
   --  are neither at its yard's level nor a wall of stone (Raw: ground left
   --  as it lay between two houses); and those, where the neighbour's walls
   --  stand beside its own, whose top is over both their yards (Proud: a
   --  wall, or earth, left standing between two yards with nothing to hold).
   procedure Count_Joins (H : Positive; Sides, Raw, Proud : in out Natural) is
      V   : constant House_View := House_At (H);
      function Yard_Of (K : Positive) return Integer is (B (House_At (K).Bed.Z + 0.01) - 1);   --  the row of a yard's top
      Yard : constant Integer := Yard_Of (H);
      function Unit (A, C : Vec3) return Vec3 is
        ((if abs (C.X - A.X) > abs (C.Y - A.Y) then (if C.X > A.X then 1.0 else -1.0) else 0.0),
         (if abs (C.X - A.X) > abs (C.Y - A.Y) then 0.0 elsif C.Y > A.Y then 1.0 else -1.0), 0.0);
      Along : constant Vec3 := Unit (V.Corner (1), V.Corner (2));   --  along its front wall, left to right
      Back  : constant Vec3 := Unit (V.Corner (1), V.Corner (4));   --  from its front wall into it
      Deep  : constant Natural := Natural (Flat (V.Corner (1), V.Corner (4)) / 0.25 + 0.5);
      procedure Side (From : Vec3; Out_Way : Vec3; Reach : Natural) is
         function At_Col (K : Positive; D : Natural) return Vec3 is
           (From + Out_Way * (0.25 * Float (K) - 0.125) + Back * (0.25 * Float (D) + 0.125));
      begin
         if Reach = 0 then
            return;
         end if;
         Sides := Sides + 1;
         for D in 0 .. Deep - 1 loop
            declare
               Beside : Natural := 0;        --  the neighbour whose walls stand beside it at this depth
            begin
               for K in 1 .. Reach + 6 loop
                  declare
                     Hn : constant Natural := House_On (At_Col (K, D).X, At_Col (K, D).Y);
                  begin
                     if Hn not in 0 | H then
                        Beside := Hn;
                        exit;
                     end if;
                  end;
               end loop;
               for K in 1 .. Reach + 6 loop
                  declare
                     P : constant Vec3 := At_Col (K, D);
                     X : constant Integer := B (P.X);
                     Y : constant Integer := B (P.Y);
                     T : constant Integer := Ground_Top (X, Y);
                  begin
                     exit when House_On (P.X, P.Y) not in 0 | H;
                     --  (what is not housing ground, a tree's foot or a boulder's, is left as it lies)
                     if K <= Reach + 1 and then T /= Yard and then Get (X, Y, T) /= Fieldstone
                       and then Zone_On (P.X, P.Y) /= 0
                     then
                        Raw := Raw + 1;
                     end if;
                     if Beside > 0 and then T > Integer'Max (Yard, Yard_Of (Beside)) then
                        Proud := Proud + 1;
                     end if;
                  end;
               end loop;
            end;
         end loop;
      end Side;
   begin
      Side (V.Corner (1), Along * (-1.0), V.Reach_L);
      Side (V.Corner (2), Along, V.Reach_R);
   end Count_Joins;

   --  In and round house H, half a metre apart: the spots a serf can get to
   --  from the stake (Spots is added to), and those of them it cannot get
   --  back to the stake from (Pits).
   procedure Count_Pits (H : Positive; Spots, Pits : in out Natural) is
      V  : constant House_View := House_At (H);
      X0 : constant Float := Float'Min (V.Corner (1).X, V.Corner (3).X) - 3.0;
      X1 : constant Float := Float'Max (V.Corner (1).X, V.Corner (3).X) + 3.0;
      Y0 : constant Float := Float'Min (V.Corner (1).Y, V.Corner (3).Y) - 3.0;
      Y1 : constant Float := Float'Max (V.Corner (1).Y, V.Corner (3).Y) + 3.0;
      X, Y : Float;
   begin
      X := X0;
      while X <= X1 loop
         Y := Y0;
         while Y <= Y1 loop
            declare
               Z : constant Float := Castle.Nav.Surface_Z (X, Y);
            begin
               --  (one that can be got to: a ledge nobody can reach is no pit)
               if Z >= 0.0 and then Castle.Nav."=" (Castle.Nav.Plan (Stake, (X, Y, Z)).Result, Castle.Nav.Found) then
                  Spots := Spots + 1;
                  if not Castle.Nav."=" (Castle.Nav.Plan ((X, Y, Z), Stake).Result, Castle.Nav.Found) then
                     Pits := Pits + 1;
                  end if;
               end if;
            end;
            Y := Y + 0.5;
         end loop;
         X := X + 0.5;
      end loop;
   end Count_Pits;

   procedure Set_Up (With_Stockpile : Boolean := True; With_Trees : Boolean := False;
                     With_Porter_Ground : Boolean := False; With_Needs : Boolean := False;
                     With_Field : Boolean := False; With_Bushes : Boolean := True;
                     With_Vegetables : Boolean := False; With_Grain : Boolean := False;
                     With_Skills : Boolean := False; With_Demand : Boolean := False;
                     With_Labour : Boolean := False; With_Flight : Boolean := False;
                     With_Beds : Boolean := False; With_Curing : Boolean := False;
                     Bush_X, Bush_Y : Float := -1.0) is      --  (one more bush, there, before the stake)
      Laid, Cells : Natural;
   begin
      Reset;
      Set_Beds (With_Beds);       --  nobody makes itself a bed, unless beds are what is checked
      Set_Curing (With_Curing);   --  no cart and meat in joints, unless the lord's cart is
      Castle.Herds.Set_Scatter (not With_Flight);   --  the herds as they were, unless their flight together is
      Set_Labour (With_Labour);   --  the camp as it was (it stands at once, its fire feeds itself), unless its labour is
      Set_Needs (With_Needs);   --  the work alone, unless the needs are what is checked
      Set_Skills (With_Skills); --  and at the one pace, unless the skills are
      Set_Demand_Chain (With_Demand);   --  and whether or not it is asked for, unless the demand chain is
      Meadow;
      if With_Bushes then
         for S of Spots loop
            Put_Bush (S.X, S.Y);
         end loop;
      end if;
      if Bush_X >= 0.0 then
         Put_Bush (Bush_X, Bush_Y);
      end if;
      if With_Vegetables then
         Put_Vegetables;
      end if;
      if With_Grain then        --  twelve plants of wild grain, two blocks tall
         for X in 0 .. 3 loop
            for Y in 0 .. 2 loop
               Set (B (30.0) + 3 * X, B (26.0) + 3 * Y, Ground_Row, Wild_Grain);
               Set (B (30.0) + 3 * X, B (26.0) + 3 * Y, Ground_Row + 1, Wild_Grain);
            end loop;
         end loop;
      end if;
      if With_Field then        --  a field of bushes north of the path, to feed a band for days
         for X in 0 .. 10 loop
            for Y in 0 .. 5 loop
               Put_Bush (6.0 + 5.0 * Float (X), 30.0 + 5.0 * Float (Y));
            end loop;
         end loop;
      end if;
      if With_Trees then
         for T of Active loop
            Shape (T.I, T.J, Grow'Access);
         end loop;
      end if;
      if With_Porter_Ground then
         Porter_Ground;
      end if;
      Hours := 16.0 * 24.0;
      Place_Stake (Stake_P, 6, 42);
      Lay_Path ((20.5, 17.5, Ground_M), (40.0, 17.5, Ground_M), Laid);
      if With_Stockpile then
         Zone_Stockpile (21.0, 15.0, 25.0, 17.0, Cells);
      end if;
      Index_All;
   end Set_Up;

   --  At an extra task (the camp's building, a path's laying), by what it
   --  says it is doing.
   function Extra_Now (I : Positive) return Boolean is
      S : constant String := Status (I);
      function Says (Part : String) return Boolean is (Ada.Strings.Fixed.Index (S, Part) > 0);
   begin
      return Says ("camp's ground") or else Says ("the path") or else Says ("the hearth") or else Says ("a seat")
        or else Says (" earth") or else Says ("picking up deadwood")
        or else (Says ("gathering stone") and then Job_Of (I) /= Porter);     --  (prising it off for the hearth)
   end Extra_Now;

   function Carried_All return Natural is
      N : Natural := 0;
   begin
      for I in 1 .. Members loop
         N := N + Carried (I);
      end loop;
      return N;
   end Carried_All;

   --  Zones as they must always be: every stockpile cell in one stockpile
   --  zone, each zone holding as many cells as say they are its own (the
   --  camp's none), and a camp zone exactly when there is a camp.
   function Zones_Sound return Boolean is
      Owned : array (1 .. Max_Zones) of Natural := [others => 0];
      Camps : Natural := 0;
   begin
      for K in 1 .. Cell_Count loop
         if Zone_Of_Cell (K) not in 1 .. Zone_Count or else Zone_At (Zone_Of_Cell (K)).Kind /= Stockpile_Zone
           or else Zone_On (Cell_At (K).Centre.X, Cell_At (K).Centre.Y) /= Zone_Of_Cell (K)
         then
            return False;
         end if;
         Owned (Zone_Of_Cell (K)) := Owned (Zone_Of_Cell (K)) + 1;
      end loop;
      for Z in 1 .. Zone_Count loop
         if Zone_At (Z).Cells /= Owned (Z) then
            return False;
         end if;
         if Zone_At (Z).Kind = Camp_Zone then
            Camps := Camps + 1;
            if Camp_Zone /= Z then
               return False;
            end if;
         elsif Owned (Z) = 0 then
            return False;
         end if;
      end loop;
      return Camps = (if Has_Camp then 1 else 0) and then (Camp_Zone > 0) = Has_Camp;
   end Zones_Sound;

   Two_On_One : Boolean := False;   --  ever two picking one bush at once
   Strays     : Boolean := False;   --  an unassigned serf away from the stake
   Saw_Pick, Saw_Carry : Boolean := False;
   Step_Time  : Duration := 0.0;
   Steps      : Natural := 0;

   --  Seconds of colony time, a second at a go (20 steps), the game clock
   --  moving a minute a second, watching as it goes.
   procedure Run (Seconds : Natural) is
   begin
      for S in 1 .. Seconds loop
         declare
            T0 : constant Time := Clock;
         begin
            Hours := Hours + 1.0 / 60.0;
            Advance (1.0, Hours);
            Step_Time := Step_Time + To_Duration (Clock - T0);
            Steps := Steps + Tick_Hz;
         end;
         for K in 1 .. Bush_Slots loop
            if Bush_Alive (K) then
               declare
                  N : Natural := 0;
               begin
                  for I in 1 .. Members loop
                     if Doing (I) = Picking and then Flat (Where (I), Bush_Centre (K)) < Bush_Radius (K) + 0.6 then
                        N := N + 1;
                     end if;
                  end loop;
                  if N > 1 then
                     Two_On_One := True;
                  end if;
               end;
            end if;
         end loop;
         for I in 1 .. Members loop
            if Job_Of (I) = Unassigned and then Flat (Where (I), Stake) > 8.0 then
               Strays := True;
            end if;
            if Doing (I) = Picking then
               Saw_Pick := True;
            end if;
            if Status (I)'Length > 6 and then Status (I) (1 .. 6) = "taking" then
               Saw_Carry := True;
            end if;
         end loop;
      end loop;
   end Run;

   Initial : Natural;
   Raw_Confidence : Float := 0.0;   --  the band's at the end of two days on raw berries
   Ok_All : Boolean := True;

begin
   Attach;

   ------------------------------------------------------------------ 1. the start
   Put_Line ("the homestake, a path, a stockpile:");
   Reset;
   Set_Beds (False);
   Set_Labour (False);
   Set_Needs (False);
   Set_Skills (False);
   Set_Demand_Chain (False);
   Meadow;
   for S of Spots loop
      Put_Bush (S.X, S.Y);
   end loop;
   Place_Stake (Stake_P, 6, 42);
   declare
      Post : Boolean := True;
      Near : Boolean := True;
   begin
      for Z in Ground_Row .. Ground_Row + 6 loop
         Post := Post and then Get (B (20.0), B (20.0), Z) = Log;
      end loop;
      Check (Has_Stake and then Post, "the stake raises a post 1.75 m tall where it is put");
      for I in 1 .. Members loop
         Near := Near and then Flat (Where (I), Stake) in 1.5 .. 4.0 and then Where (I).Z = Ground_M
                 and then Job_Of (I) = Unassigned;
      end loop;
      Check (Members = 6 and then Near, "the band of 6 stands round it, on the ground, none of them assigned yet");
      declare
         Names : Boolean := True;
      begin
         for I in 2 .. Members loop
            for J in 1 .. I - 1 loop
               Names := Names and then Name_Of (I) /= Name_Of (J);
            end loop;
         end loop;
         Put ("    the band:");
         for I in 1 .. Members loop
            Put (" " & Name_Of (I));
         end loop;
         New_Line;
         Check (Names, "each has a name of their own");
      end;
   end;
   declare
      Laid, Cells : Natural;
   begin
      Lay_Path ((20.5, 17.5, Ground_M), (40.0, 17.5, Ground_M), Laid);
      Check (Laid > 200 and then Get (B (30.0), B (17.5), Ground_Row - 1) = Footpath
             and then Near_Path (30.0, 17.5, 0.0) and then not Near_Path (30.0, 25.0, 1.0),
             "a path is laid on the ground, 1 m wide:" & Laid'Image & " blocks of footpath");
      Zone_Stockpile (2.0, 50.0, 6.0, 54.0, Cells);
      Check (Cells = 0, "a stockpile away from any path is refused");
      Zone_Stockpile (21.0, 15.0, 25.0, 17.0, Cells);
      Check (Cells = 8, "beside the path it is zoned: 8 cells of 1 m (" & Cells'Image & ")");
   end;
   Index_All;
   Initial := Berries_Left;
   Check (Bush_Count = 6 and then Ripe_Bushes = 6, "the six bushes are found (" & Bush_Count'Image & "), all ripe,"
          & Initial'Image & " handfuls on them");

   ------------------------------------------------------------------ 2. gathering
   Put_Line ("two gatherers, four waiting:");
   Set_Job (1, Gatherer);
   Set_Job (2, Gatherer);
   Run (600);
   Put_Line ("    after 10 minutes: stored" & Stored (Berries)'Image & ", carried" & Carried_All'Image
             & ", left on the bushes" & Berries_Left'Image);
   for I in 1 .. 2 loop
      Put_Line ("    " & Name_Of (I) & ": " & Status (I));
   end loop;
   Check (Stored (Berries) >= 60, "berries come into the stockpile");
   Check (Initial = Berries_Left + Stored (Berries) + Carried_All,
          "none made or lost: on the bushes + stored + carried =" & Initial'Image);
   Check (Saw_Pick and then Saw_Carry, "they pick, and carry full baskets home");
   Check (not Two_On_One, "never two at one bush");
   Check (not Strays, "the unassigned keep to the stake");
   Run (3_000);
   Check (Ripe_Bushes = 0 and then Initial = Stored (Berries) + Carried_All,
          "in an hour every bush is picked bare and all of it stored (" & Stored (Berries)'Image & ")");
   Check (Status (1) = "nothing to gather in reach" or else Status (2) = "nothing to gather in reach",
          "and then there is nothing to gather in reach: " & Status (1));
   Check (Get (B (12.0), B (26.0), Ground_Row) = Bare_Bush, "a picked bush is bare to look at");
   Put_Line ("    " & Img (Float (Step_Time) * 1000.0 / Float (Steps), 3)
             & " ms a step for 6 serfs (this build)");

   ------------------------------------------------------------------ 3. growing back
   Put_Line ("growing back:");
   Hours := Hours + Long_Float (Regrow_Days) * 24.0 + 1.0;
   Run (2);
   Check (Ripe_Bushes = 6 and then Get (B (12.0), B (26.0), Ground_Row) = Berry_Bush,
          "six days on, in summer, every bush bears again");
   Run (300);                                         --  pick a while
   declare
      Picked : constant Natural := 6 - Ripe_Bushes + (if Berries_Left < Initial then 1 else 0);
   begin
      Check (Picked > 0, "they pick again");
   end;
   Set_Job (1, Unassigned);
   Set_Job (2, Unassigned);
   Run (60);
   declare
      Before : constant Natural := Berries_Left;
   begin
      Hours := 46.0 * 24.0;                           --  winter
      Run (2);
      Hours := Hours + 10.0 * 24.0;                   --  deep in it
      Run (2);
      Check (Berries_Left = Before, "in winter nothing grows back (" & Before'Image & " handfuls stay)");
      Hours := 61.0 * 24.0;                           --  spring of the next year
      Run (2);
      Check (Berries_Left = Initial, "in spring it does (" & Berries_Left'Image & ")");
   end;

   ------------------------------------------------------------------ 4. a bush walled in
   Put_Line ("a bush walled in:");
   Set_Up;
   Fill (10.5, 24.5, 13.75, 24.75, Ground_Row, Ground_Row + 11, Plank);   --  round the bush at (12, 26)
   Fill (10.5, 27.25, 13.75, 27.5, Ground_Row, Ground_Row + 11, Plank);
   Fill (10.5, 24.5, 10.75, 27.5, Ground_Row, Ground_Row + 11, Plank);
   Fill (13.5, 24.5, 13.75, 27.5, Ground_Row, Ground_Row + 11, Plank);
   Set_Job (1, Gatherer);
   Set_Job (2, Gatherer);
   Run (3_000);
   declare
      Walled : Natural := 0;
   begin
      for K in 1 .. Bush_Slots loop
         if Bush_Alive (K) and then Flat (Bush_Centre (K), (12.0, 26.0, 0.0)) < 1.0 then
            Walled := K;
         end if;
      end loop;
      Check (Walled > 0 and then Bush_Ripe (Walled) > 0 and then Ripe_Bushes = 1,
             "the walled-in bush is left (the other five are picked bare)");
      Check (Status (1) = "nothing to gather in reach" and then Status (2) = "nothing to gather in reach",
             "and they don't keep trying it: " & Status (1));
   end;

   ------------------------------------------------------------------ 5. nowhere to put it
   Put_Line ("no stockpile yet:");
   Set_Up (With_Stockpile => False);
   Set_Job (1, Gatherer);
   Run (200);
   Check (Carried (1) = Carry_Limit (Berries) and then Status (1) = "nowhere to put berries",
          "a full basket and nowhere to put it: '" & Status (1) & "'");
   declare
      Cells : Natural;
   begin
      Zone_Stockpile (21.0, 15.0, 25.0, 17.0, Cells);
      Run (120);
      Check (Stored (Berries) >= Carry_Limit (Berries), "zone a stockpile and in it goes (" & Stored (Berries)'Image & ")");
   end;

   ------------------------------------------------------------------ 5b. long grass
   Put_Line ("a stockpile zoned on long grass:");
   declare
      Cells : Natural;
      Cut, Kept : Boolean := True;
   begin
      Fill (30.0, 18.0, 34.0, 20.0, Ground_Row, Ground_Row, Tall_Grass);
      Set (B (31.5), B (19.5), Ground_Row, Log);         --  a log lying on one cell
      Zone_Stockpile (30.0, 18.0, 34.0, 20.0, Cells);
      Check (Cells = 7, "the cell with a log on it is left out:" & Cells'Image & " of 8 zoned");
      for X in B (30.0) .. B (34.0) - 1 loop
         for Y in B (18.0) .. B (20.0) - 1 loop
            if X / 4 = 31 and then Y / 4 = 19 then
               Kept := Kept and then Get (X, Y, Ground_Row) in Tall_Grass | Log;
            else
               Cut := Cut and then Get (X, Y, Ground_Row) = Air;
            end if;
         end loop;
      end loop;
      Check (Cut, "the grass on the zoned cells is cut, so what is put there can be seen");
      Check (Kept, "the grass round the log is left standing");
      Check (Zone_On (31.9, 19.9) = Zone_Count and then Zone_On (31.6, 19.6) = 0,
             "the ground round the log is the zone's all the same, the log's own block is not");
   end;

   ------------------------------------------------------------------ 6. a save mid-trip
   Put_Line ("a save taken mid-trip:");
   Set_Up;
   Set_Job (1, Gatherer);
   Set_Job (2, Gatherer);
   Set_Job (3, Gatherer);
   Run (75);
   declare
      Snap   : Snapshot;
      Saved_Hours : constant Long_Float := Hours;
      Data   : constant Bytes := Save;
      type Spot_List is array (1 .. 6) of Vec3;
      A_Pos, B_Pos : Spot_List;
      A_Stored, B_Stored, A_Left, B_Left : Natural;
      Walking_At_Save : Boolean := False;
      Ok : Boolean;
   begin
      for I in 1 .. 3 loop
         Walking_At_Save := Walking_At_Save or else Doing (I) = Walking;
      end loop;
      Take (Snap);
      Run (400);
      A_Stored := Stored (Berries);
      A_Left := Berries_Left;
      for I in 1 .. 6 loop
         A_Pos (I) := Where (I);
      end loop;
      Give_Back (Snap);
      Hours := Saved_Hours;
      Load (Data, Ok);
      declare
         Again : constant Bytes := Save;
      begin
         Check (Ok and then Again = Data, "it loads, and saved again is the same" & Data'Length'Image & " bytes");
      end;
      Run (400);
      B_Stored := Stored (Berries);
      B_Left := Berries_Left;
      for I in 1 .. 6 loop
         B_Pos (I) := Where (I);
      end loop;
      Check (Walking_At_Save, "someone was on the way when it was saved");
      Check (A_Stored = B_Stored and then A_Left = B_Left and then A_Pos = B_Pos,
             "and 400 s later the colony is just as it would have been:" & A_Stored'Image & " stored either way");
   end;

   ------------------------------------------------------------------ 7. trees
   Put_Line ("two foresters, a porter, three idle hands:");
   Set_Trees (Find'Unrestricted_Access, Shape'Unrestricted_Access);
   Set_Up (With_Trees => True);
   declare
      Standing_Trees : Natural := 0;
      Logs_Due : Natural := 0;
      Saw_Log, Saw_Chop : Boolean := False;
      Others_Carry, Chop_With_Logs : Boolean := False;
   begin
      for K in 1 .. Tree_Count loop
         if not Tree_Down (K) then
            Standing_Trees := Standing_Trees + 1;
         end if;
         if Tree_At (K).Kind /= Apple then
            Logs_Due := Logs_Due + Logs_Of (Tree_At (K));
         end if;
      end loop;
      Check (Tree_Count = 4 and then Standing_Trees = 4, "the four trees are found, all standing (" & Tree_Count'Image & ")");
      Set_Job (1, Forester);
      Set_Job (2, Forester);
      Set_Job (3, Porter);
      for S in 1 .. 1_200 loop
         Run (1);
         for I in 1 .. Members loop
            Saw_Chop := Saw_Chop or else Doing (I) = Chopping;
            Saw_Log := Saw_Log or else Status (I) = "carrying a log to the stockpile";
            if Carrying (I) = Wood and then Job_Of (I) /= Forester then
               Others_Carry := True;
            end if;
            if Doing (I) = Chopping then
               for K in 1 .. Pile_Count loop
                  if Pile_At (K).Owner = I and then Pile_At (K).Count > 0 then
                     Chop_With_Logs := True;
                  end if;
               end loop;
            end if;
         end loop;
      end loop;
      Put_Line ("    after 20 minutes: felled" & Trees_Felled'Image & ", stored" & Stored (Wood)'Image
                & ", lying" & Logs_Lying'Image);
      for I in 1 .. 3 loop
         Put_Line ("    " & Name_Of (I) & ": " & Status (I));
      end loop;
      Check (Saw_Chop and then Trees_Felled = 3, "they chop, and fell every tree but the apple (" & Trees_Felled'Image & ")");
      declare
         Felled_Clean, Apple_Up : Boolean := True;
      begin
         for T of The_Trees loop
            declare
               I : Tree_Info renames T.Info;
               Top : constant Integer := I.Bz + I.Trunk_H;
            begin
               if I.Kind = Apple then
                  Apple_Up := Get (I.Bx, I.By, Top) = Log and then Get (I.Bx - 2, I.By, Top) = Apple_Leaves;
               else
                  Felled_Clean := Felled_Clean and then Get (I.Bx, I.By, I.Bz) = Log
                    and then Get (I.Bx, I.By, I.Bz + 1) = Air and then Get (I.Bx, I.By, Top) = Air
                    and then Get (I.Bx - 2, I.By, Top) = Air and then Get (I.Bx, I.By, I.Bz - 2) = Log;
               end if;
            end;
         end loop;
         Check (Felled_Clean, "a felled tree leaves its stump (and roots); trunk and crown are gone");
         Check (Apple_Up, "the apple tree is spared while that order stands");
      end;
      declare
         On_Shoulders : Natural := 0;
      begin
         for I in 1 .. Members loop
            if Carrying (I) = Wood then
               On_Shoulders := On_Shoulders + Carried (I);
            end if;
         end loop;
         Check (Stored (Wood) + Logs_Lying + On_Shoulders = Logs_Due,
                "every log is stored, lying or carried:" & Logs_Due'Image & " from the three");
      end;
      Check (Saw_Log and then Stored (Wood) = Logs_Due, "and carried to the stockpile, a log at a time ("
             & Stored (Wood)'Image & ")");
      Check (not Others_Carry, "only the foresters carry wood: the porter and the idle hands never do");
      Check (not Chop_With_Logs, "and a forester fells no tree while logs of its last one still lie");
      Check (Status (1) = "no trees to fell in reach" or else Status (2) = "no trees to fell in reach",
             "then there is nothing left to fell: " & Status (1));
      Set_Protect_Apples (False);
      Run (300);
      Check (Trees_Felled = 4, "lift the order and the apple tree comes down too");
   end;

   Put_Line ("the wood reserve:");
   Set_Up (With_Trees => True);
   Set_Wood_Reserve (3);
   Set_Job (1, Forester);
   Run (900);
   Check (Trees_Felled = 2 and then Wood_Total >= 3 and then Status (1) = "enough wood (the reserve is met)",
          "one forester stops once the colony has 3 logs: felled" & Trees_Felled'Image & ", wood"
          & Wood_Total'Image & ", '" & Status (1) & "'");

   Put_Line ("a branch through a neighbour's trunk:");
   Use_Pair := True;
   Set_Up (With_Trees => True);
   Set_Job (1, Forester);
   for S in 1 .. 600 loop
      Run (1);
      exit when Trees_Felled > 0;
   end loop;
   declare
      Whole : Boolean := True;
      Left  : Natural := 0;
   begin
      for P of The_Pair loop
         if Get (P.Info.Bx, P.Info.By, P.Info.Bz + 1) = Log then   --  the one still standing
            Left := Left + 1;
            for Z in P.Info.Bz + 1 .. P.Info.Bz + P.Info.Trunk_H loop
               Whole := Whole and then Get (P.Info.Bx, P.Info.By, Z) = Log;
            end loop;
         end if;
      end loop;
      Check (Trees_Felled = 1 and then Left = 1 and then Whole,
             "one felled, and the other's trunk is whole where the felled tree's branch ran through it");
   end;
   Use_Pair := False;

   Put_Line ("a save taken mid-felling:");
   Set_Up (With_Trees => True);
   Set_Job (1, Forester);
   Set_Job (2, Forester);
   Set_Job (3, Porter);
   Run (30);
   declare
      Snap   : Snapshot;
      Saved_Hours : constant Long_Float := Hours;
      Data   : constant Bytes := Save;
      type Spot_List is array (1 .. 6) of Vec3;
      A_Pos, B_Pos : Spot_List;
      A_Stored, B_Stored, A_Lying, B_Lying, A_Felled, B_Felled : Natural;
      Busy : Boolean := False;
      Ok : Boolean;
   begin
      for I in 1 .. 3 loop
         Busy := Busy or else Doing (I) /= Standing;
         Put_Line ("    at the save, " & Name_Of (I) & ": " & Status (I) & " (" & Doing (I)'Image & ")");
      end loop;
      Take (Snap);
      Run (400);
      A_Stored := Stored (Wood);
      A_Lying := Logs_Lying;
      A_Felled := Trees_Felled;
      for I in 1 .. 6 loop
         A_Pos (I) := Where (I);
      end loop;
      Give_Back (Snap);
      Hours := Saved_Hours;
      Load (Data, Ok);
      declare
         Again : constant Bytes := Save;
      begin
         Check (Ok and then Again = Data, "it loads, and saved again is the same" & Data'Length'Image & " bytes");
      end;
      Run (400);
      B_Stored := Stored (Wood);
      B_Lying := Logs_Lying;
      B_Felled := Trees_Felled;
      for I in 1 .. 6 loop
         B_Pos (I) := Where (I);
      end loop;
      Check (Busy, "someone was at work or on the way when it was saved");
      Check (A_Stored = B_Stored and then A_Lying = B_Lying and then A_Felled = B_Felled and then A_Pos = B_Pos,
             "and 400 s later it is just as it would have been:" & A_Felled'Image & " felled," & A_Stored'Image
             & " stored either way");
   end;

   ------------------------------------------------------------------ 8. porters
   Put_Line ("a porter, nothing lying about:");
   Set_Up (With_Porter_Ground => True);
   declare
      Grass0 : constant Natural := Grass_Left;
      Rock0  : constant Natural := Rock_Left;
      Water0 : constant Natural := Water_Left;
      Saw_Straw, Saw_Stone, Saw_Water : Boolean := False;
      Straw_At_First_Stone : Natural := 0;
      Below_Kept : Boolean := True;
   begin
      Check (Wanted_Of (Stone) = Stone_Quota and then Reserve_Of (Straw) = 20,
             "a colony starts wanting" & Wanted_Of (Stone)'Image & " stone, and keeps a reserve of"
             & Reserve_Of (Straw)'Image & " straw");
      Set_Job (1, Porter);
      for S in 1 .. 1_200 loop
         Run (1);
         declare
            St : constant String := Status (1);
         begin
            Saw_Straw := Saw_Straw or else (St'Length >= 13 and then St (1 .. 13) = "cutting straw");
            if not Saw_Stone and then St'Length >= 15 and then St (1 .. 15) = "gathering stone" then
               Saw_Stone := True;
               Straw_At_First_Stone := Have (Straw);
            end if;
            Saw_Water := Saw_Water or else (St'Length >= 13 and then St (1 .. 13) = "drawing water")
              or else Carrying (1) = Water;
         end;
      end loop;
      Put_Line ("    after 20 minutes: straw" & Have (Straw)'Image & ", stone" & Have (Stone)'Image
                & ", water" & Have (Water)'Image & " (stored and carried); " & Name_Of (1) & ": " & Status (1));
      Check (Saw_Straw and then Saw_Stone, "the porter cuts straw and gathers stone");
      Check (Straw_At_First_Stone >= Reserve_Of (Straw),
             "straw first: no stone until the straw is in (" & Straw_At_First_Stone'Image & " of"
             & Reserve_Of (Straw)'Image & ")");
      Check (Stored (Straw) >= Reserve_Of (Straw) and then Stored (Stone) >= Wanted_Of (Stone),
             "then stone, as much as is wanted:" & Stored (Straw)'Image & " straw," & Stored (Stone)'Image
             & " stone stored");
      Check (not Saw_Water and then Have (Water) = 0 and then Water_Left = Water0,
             "no water is fetched yet; the pond is as it was");
      Check (Grass0 - Grass_Left = Have (Straw), "every tuft cut is stored or carried (" & Natural'Image (Grass0 - Grass_Left) & ")");
      Check (Rock0 - Rock_Left = Have (Stone), "every stone prised off is stored or carried ("
             & Natural'Image (Rock0 - Rock_Left) & ")");
      for X in Rock_X - 3 .. Rock_X + 3 loop
         for Y in Rock_Y - 3 .. Rock_Y + 3 loop
            for Z in Ground_Row - 3 .. Ground_Row - 1 loop
               Below_Kept := Below_Kept and then Class_Of (Get (X, Y, Z)) = Solid;
            end loop;
         end loop;
      end loop;
      Check (Below_Kept, "what of the boulder lies under the grass is left: no pit");
      Check (Status (1) = "the stocks are full", "then the stocks are full: '" & Status (1) & "'");
      Want (Stone, 8);
      Run (240);
      Check (Stored (Stone) >= Stone_Quota + 8, "want more stone and more comes in (" & Stored (Stone)'Image & ")");
      Set_Reserve (Straw, 40);
      Run (300);
      Check (Stored (Straw) >= 40, "raise the straw reserve and more comes in (" & Stored (Straw)'Image & ")");
   end;

   Put_Line ("the straw walled in:");
   Set_Up (With_Porter_Ground => True);
   Fill (Grass_X0 - 0.5, Grass_Y0 - 0.5, Grass_X1 + 0.5, Grass_Y0 - 0.25, Ground_Row, Ground_Row + 11, Plank);
   Fill (Grass_X0 - 0.5, Grass_Y1 + 0.25, Grass_X1 + 0.5, Grass_Y1 + 0.5, Ground_Row, Ground_Row + 11, Plank);
   Fill (Grass_X0 - 0.5, Grass_Y0 - 0.5, Grass_X0 - 0.25, Grass_Y1 + 0.5, Ground_Row, Ground_Row + 11, Plank);
   Fill (Grass_X1 + 0.25, Grass_Y0 - 0.5, Grass_X1 + 0.5, Grass_Y1 + 0.5, Ground_Row, Ground_Row + 11, Plank);
   Set_Job (1, Porter);
   Run (600);
   Check (Stored (Straw) = 0 and then Stored (Stone) >= Wanted_Of (Stone),
          "the porter leaves the walled-in straw and brings in the stone:" & Stored (Stone)'Image & " stone");
   Check (Status (1) = "no straw in reach", "and says why: '" & Status (1) & "'");

   Put_Line ("a forester felling, a porter fetching, three idle hands:");
   Set_Up (With_Trees => True, With_Porter_Ground => True);
   Set_Job (1, Forester);
   Set_Job (2, Porter);
   declare
      Porter_Wood : Boolean := False;
   begin
      for S in 1 .. 1_200 loop
         Run (1);
         Porter_Wood := Porter_Wood or else Carrying (2) = Wood;
      end loop;
      Put_Line ("    after 20 minutes: felled" & Trees_Felled'Image & ", logs stored" & Stored (Wood)'Image
                & ", straw" & Stored (Straw)'Image & ", stone" & Stored (Stone)'Image);
      Check (Stored (Straw) >= Reserve_Of (Straw) and then Stored (Stone) >= Wanted_Of (Stone)
             and then Trees_Felled = 3 and then Logs_Lying = 0 and then not Porter_Wood,
             "the porter brings in straw and stone and never a log; the forester brings in all of its own");
   end;

   Put_Line ("a save taken mid-fetch:");
   Set_Up (With_Porter_Ground => True);
   Set_Job (1, Porter);
   Set_Job (2, Porter);
   Run (40);
   declare
      Snap   : Snapshot;
      Saved_Hours : constant Long_Float := Hours;
      Data   : constant Bytes := Save;
      type Spot_List is array (1 .. 6) of Vec3;
      A_Pos, B_Pos : Spot_List;
      type Two is array (1 .. 2) of Natural;
      A_Have, B_Have : Two;
      Busy : Boolean := False;
      Ok : Boolean;
   begin
      for I in 1 .. 2 loop
         Busy := Busy or else Doing (I) /= Standing;
         Put_Line ("    at the save, " & Name_Of (I) & ": " & Status (I));
      end loop;
      Take (Snap);
      Run (300);
      A_Have := [Stored (Straw), Stored (Stone)];
      for I in 1 .. 6 loop
         A_Pos (I) := Where (I);
      end loop;
      Give_Back (Snap);
      Hours := Saved_Hours;
      Load (Data, Ok);
      declare
         Again : constant Bytes := Save;
      begin
         Check (Ok and then Again = Data, "it loads, and saved again is the same" & Data'Length'Image & " bytes");
      end;
      Run (300);
      B_Have := [Stored (Straw), Stored (Stone)];
      for I in 1 .. 6 loop
         B_Pos (I) := Where (I);
      end loop;
      Check (Busy, "someone was at work or on the way when it was saved");
      Check (A_Have = B_Have and then A_Pos = B_Pos,
             "and 300 s later it is just as it would have been:" & A_Have (1)'Image & " straw," & A_Have (2)'Image
             & " stone either way");
   end;

   ------------------------------------------------------------------ 9. herds
   Put_Line ("herds:");
   Set_Up;
   declare
      use Castle.Herds;
      use type Castle.Animals.Mode;
      use type Castle.Deer.Class;
      type Spot_Array is array (1 .. Max_Deer) of Vec3;
      None : constant People (1 .. 0) := [others => <>];
      function Spread (H : Positive) return Float is
         M : Float := 0.0;
      begin
         for K in 1 .. Deer_Slots loop
            if Alive (K) and then Herd_Of (K) = H then
               M := Float'Max (M, Flat (Castle.Herds.Where (K), Node (H)));
            end if;
         end loop;
         return M;
      end Spread;
      function Live return Natural is
         N : Natural := 0;
      begin
         for K in 1 .. Deer_Slots loop
            if Alive (K) then
               N := N + 1;
            end if;
         end loop;
         return N;
      end Live;
      procedure Go (Seconds : Float; Near : People := None) is
      begin
         for S in 1 .. Natural (Seconds * Float (Tick_Hz)) loop
            Hours := Hours + Long_Float (Tick_S) / 3600.0 * 60.0;   --  a game minute a second
            Castle.Herds.Step (Tick_S, Hours, Near);
         end loop;
      end Go;
      Placed_Ok : Boolean := True;
      Start_Node : Vec3;
      Max_Spread : Float := 0.0;
      Grazed : Boolean := False;
   begin
      Go (0.05);
      for K in 1 .. Deer_Slots loop
         Placed_Ok := Placed_Ok and then Alive (K)
           and then Flat (Castle.Herds.Where (K), Stake) <= Range_M
           and then Flat (Castle.Herds.Where (K), Stake) >= Near_Stake_M - 8.0
           and then Get (B (Castle.Herds.Where (K).X), B (Castle.Herds.Where (K).Y), B (Castle.Herds.Where (K).Z) - 1) in Grass | Dirt;
      end loop;
      Check (Herd_Count >= 1 and then Live >= 5 and then Placed_Ok,
             "herds are placed round the stake on walkable ground:" & Herd_Count'Image & " herds," & Live'Image
             & " deer");
      Start_Node := Node (1);
      for S in 1 .. 600 loop
         Go (1.0);
         for H in 1 .. Herd_Count loop
            Max_Spread := Float'Max (Max_Spread, Spread (H));
         end loop;
         for K in 1 .. Deer_Slots loop
            Grazed := Grazed or else (Alive (K) and then Castle.Herds.Doing (K) = Castle.Deer.Graze);
         end loop;
      end loop;
      Put_Line ("    after 10 minutes the first herd has moved " & Img (Flat (Node (1), Start_Node), 1)
                & " m; its deer never more than " & Img (Max_Spread, 1) & " m from the node");
      Check (Max_Spread < 12.0, "calm, the deer keep round their herd's node");
      Check (Flat (Node (1), Start_Node) > 5.0 and then Flat (Node (1), Stake) <= Range_M,
             "the herd drifts on to new grazing, within reach of the stake");
      Check (Grazed, "and they graze");

      --  fear
      declare
         K1 : Positive := 1;
      begin
         while not (Alive (K1) and then Herd_Of (K1) = 1) loop
            K1 := K1 + 1;
         end loop;
         declare
            D  : constant Vec3 := Castle.Herds.Where (K1);
            Far_Stalker  : constant People := [1 => (P => D + (10.0, 0.0, 0.0), Stalking => True, Still => False)];
            Near_Stalker : constant People := [1 => (P => D + (5.0, 0.0, 0.0), Stalking => True, Still => False)];
            Walker       : constant People := [1 => (P => D + (12.0, 0.0, 0.0), Stalking => False, Still => False)];
         begin
            Go (0.1, Far_Stalker);
            Check (not Panicked (1), "a hunter stalking 10 m off goes unnoticed");
            Go (0.1, Walker);
            Check (Panicked (1), "someone walking 12 m off panics the herd");
            Go (40.0);
            Check (not Panicked (1), "and the panic wears off");
            declare
               D2 : constant Vec3 := Castle.Herds.Where (K1);
               Near_Stalker2 : constant People := [1 => (P => D2 + (5.0, 0.0, 0.0), Stalking => True, Still => False)];
            begin
               Go (0.1, Near_Stalker2);
               Check (Panicked (1), "a hunter stalking 5 m off is seen");
            end;
            pragma Unreferenced (Near_Stalker);
         end;
      end;
      Go (40.0);

      --  an arrow
      declare
         K1 : Positive := 1;
      begin
         while not (Alive (K1) and then Herd_Of (K1) = 1) loop
            K1 := K1 + 1;
         end loop;
         declare
            Bow     : constant Vec3 := Castle.Herds.Where (K1) - (14.0, 0.0, 0.0);
            Before  : constant Float := Flat (Node (1), Bow);
            Calm_Spread : constant Float := Spread (1);
            Wide    : Float := 0.0;
         begin
            Scare (Castle.Herds.Where (K1), Bow);
            for S in 1 .. 50 loop
               Go (0.1);
               Wide := Float'Max (Wide, Spread (1));
            end loop;
            Put_Line ("    the node fled from " & Img (Before, 1) & " m to " & Img (Flat (Node (1), Bow), 1)
                      & " m from the bow; the deer spread to " & Img (Wide, 1) & " m (calm " & Img (Calm_Spread, 1) & ")");
            Check (Flat (Node (1), Bow) > Before + 8.0, "an arrow: the node flees away from the bow");
            Check (Wide > Calm_Spread + 4.0, "the deer scatter");
            Go (45.0);
            Check (not Panicked (1) and then Spread (1) < 10.0,
                   "then they settle round the node again (" & Img (Spread (1), 1) & " m)");
         end;
      end;

      --  spring and growing up
      declare
         Before : constant Natural := Live;
         Fawns_Grew : Boolean := True;
         Born_Ones : array (1 .. Max_Deer) of Boolean := [others => False];
      begin
         Hours := Long_Float (Natural (Hours / (24.0 * 60.0)) + 1) * 24.0 * 60.0 + 24.0 * 2.0;   --  early in next year's spring
         Go (0.1);
         Put_Line ("    spring:" & Before'Image & " deer," & Live'Image & " after");
         Check (Live > Before, "in spring fawns are born");
         for K in 1 .. Deer_Slots loop
            Born_Ones (K) := Alive (K) and then Castle.Herds.Class_Of (K) = Castle.Deer.Fawn;
         end loop;
         declare
            After_Spring : constant Natural := Live;
         begin
            Go (5.0);
            Check (Live = After_Spring, "once a year: no more come later that spring");
         end;
         Hours := Hours + 24.0 * 60.0 * 1.1;                          --  a year on
         Go (0.1);
         for K in 1 .. Deer_Slots loop
            if Born_Ones (K) and then Alive (K) then
               Fawns_Grew := Fawns_Grew and then Castle.Herds.Class_Of (K) in Castle.Deer.Doe | Castle.Deer.Young_Stag;
            end if;
         end loop;
         Check (Fawns_Grew, "a year later the fawns are does and young stags");
      end;

      --  a save mid-panic
      declare
         K1 : Positive := 1;
         A_Pos, B_Pos : Spot_Array := [others => (0.0, 0.0, 0.0)];
         Ok : Boolean;
      begin
         while not Alive (K1) loop
            K1 := K1 + 1;
         end loop;
         Scare (Castle.Herds.Where (K1), Castle.Herds.Where (K1) - (10.0, 0.0, 0.0));
         Go (1.0);
         declare
            Data : constant Castle.Herds.Bytes := Castle.Herds.Save;
            Saved_Hours : constant Long_Float := Hours;
         begin
            Go (30.0);
            for K in 1 .. Deer_Slots loop
               A_Pos (K) := Castle.Herds.Where (K);
            end loop;
            Castle.Herds.Load (Data, Ok);
            Hours := Saved_Hours;
            declare
               Again : constant Castle.Herds.Bytes := Castle.Herds.Save;
            begin
               Check (Ok and then Again = Data, "a save taken mid-panic loads, and saved again is the same"
                      & Data'Length'Image & " bytes");
            end;
            Go (30.0);
            for K in 1 .. Deer_Slots loop
               B_Pos (K) := Castle.Herds.Where (K);
            end loop;
            Check (A_Pos = B_Pos, "and 30 s later every deer is just where it would have been");
         end;
      end;
   end;

   ------------------------------------------------------------------ 10. hunters
   Put_Line ("a hunter:");
   Set_Up;
   Set_Job (1, Hunter);
   declare
      use type Castle.Deer.Class;
      Stalked : Boolean := False;
      Smallest : Natural := Natural'Last;
      function Meat_Due return Natural is
         N : Natural := 0;
      begin
         for K in 1 .. Carcass_Count loop
            if Carcass_Used (K) then
               N := N + Meat_Of (Carcass_At (K).Class);
            end if;
         end loop;
         return N;
      end Meat_Due;
      function Lying_Or_Carried return Natural is
         N : Natural := 0;
      begin
         for K in 1 .. Carcass_Count loop
            if Carcass_Used (K) then
               N := N + 1;
            end if;
         end loop;
         return N;
      end Lying_Or_Carried;
   begin
      for S in 1 .. 1_800 loop
         Run (1);
         Stalked := Stalked or else Doing (1) = Sneaking;
         for H in 1 .. Castle.Herds.Herd_Count loop
            Smallest := Natural'Min (Smallest, Castle.Herds.In_Herd (H));
         end loop;
         exit when Stored (Meat) >= Reserve_Of (Meat) and then Lying_Or_Carried = 0;
      end loop;
      Run (10);                                   --  a moment to think again
      Put_Line ("    after up to 30 minutes:" & Kills'Image & " killed with" & Shots'Image & " arrows;"
                & Stored (Meat)'Image & " meat," & Stored (Hide)'Image & " hides stored; " & Name_Of (1) & ": "
                & Status (1));
      Check (Stalked and then Kills >= 1, "the hunter stalks (crouched, slow) and brings deer down");
      Check (Stored (Hide) + Lying_Or_Carried = Kills,
             "every deer brought down is butchered into a hide or still on its way:" & Kills'Image);
      Check (Stored (Meat) >= Reserve_Of (Meat) and then Status (1) = "enough meat (the reserve is met)",
             "it hunts until the meat reserve is met, then stops: '" & Status (1) & "'");
      Check (Smallest >= Spare_Last, "no herd was hunted below" & Spare_Last'Image & " (the smallest kept"
             & Smallest'Image & ")");
      pragma Unreferenced (Meat_Due);
      Set_Reserve (Meat, 200);
      Set_Spare_Deer (True);
      declare
         Before : constant Natural := Shots;
      begin
         Run (600);
         Check (Shots = Before and then Status (1) = "the deer are spared",
                "with the deer spared, no arrow is loosed: '" & Status (1) & "'");
      end;
   end;

   Put_Line ("a herd penned behind walls:");
   Set_Up;
   declare
      use Castle.Herds;
      None : constant People (1 .. 0) := [others => <>];
   begin
      Castle.Herds.Step (Tick_S, Hours, None);                 --  the herds placed
      declare
         N1 : constant Vec3 := Node (1);
         R  : constant Float := 6.0;
         In_Pen_Before : constant Natural := In_Herd (1);
         Shot_Into_Pen : Boolean := False;
      begin
         --  a plank wall 3 m tall round the first herd, the deer gathered inside
         Fill (N1.X - R, N1.Y - R, N1.X + R, N1.Y - R + 0.25, Ground_Row, Ground_Row + 11, Plank);
         Fill (N1.X - R, N1.Y + R - 0.25, N1.X + R, N1.Y + R, Ground_Row, Ground_Row + 11, Plank);
         Fill (N1.X - R, N1.Y - R, N1.X - R + 0.25, N1.Y + R, Ground_Row, Ground_Row + 11, Plank);
         Fill (N1.X + R - 0.25, N1.Y - R, N1.X + R, N1.Y + R, Ground_Row, Ground_Row + 11, Plank);
         Set_Job (1, Hunter);
         for S in 1 .. 1_200 loop
            Run (1);
            for A in 1 .. Arrow_Count loop
               declare
                  T : constant Vec3 := Arrow_At (A).To;
               begin
                  if abs (T.X - N1.X) < R - 0.5 and then abs (T.Y - N1.Y) < R - 0.5 then
                     Shot_Into_Pen := True;
                  end if;
               end;
            end loop;
         end loop;
         Put_Line ("    in 20 minutes:" & Kills'Image & " killed with" & Shots'Image & " arrows; the penned herd"
                   & In_Herd (1)'Image & " of" & In_Pen_Before'Image);
         Check (not Shot_Into_Pen and then In_Herd (1) >= In_Pen_Before,
                "no arrow is loosed into the pen: the walls block every shot");
         Check (Kills >= 1, "and the hunter takes the free herd's deer instead");
      end;
   end;

   Put_Line ("a save taken mid-hunt:");
   Set_Up;
   Set_Job (1, Hunter);
   Set_Job (2, Hunter);
   Run (120);
   declare
      Snap   : Snapshot;
      Saved_Hours : constant Long_Float := Hours;
      Data   : constant Bytes := Save;
      type Spot_List is array (1 .. 6) of Vec3;
      A_Pos, B_Pos : Spot_List;
      type Four is array (1 .. 4) of Natural;
      A_N, B_N : Four;
      Ok : Boolean;
   begin
      for I in 1 .. 2 loop
         Put_Line ("    at the save, " & Name_Of (I) & ": " & Status (I));
      end loop;
      Take (Snap);
      Run (300);
      A_N := [Kills, Shots, Stored (Meat), Stored (Hide)];
      for I in 1 .. 6 loop
         A_Pos (I) := Where (I);
      end loop;
      Give_Back (Snap);
      Hours := Saved_Hours;
      Load (Data, Ok);
      declare
         Again : constant Bytes := Save;
      begin
         Check (Ok and then Again = Data, "it loads, and saved again is the same" & Data'Length'Image & " bytes");
      end;
      Run (300);
      B_N := [Kills, Shots, Stored (Meat), Stored (Hide)];
      for I in 1 .. 6 loop
         B_Pos (I) := Where (I);
      end loop;
      Check (A_N = B_N and then A_Pos = B_Pos,
             "and 300 s later it is just as it would have been:" & A_N (1)'Image & " killed," & A_N (2)'Image
             & " arrows," & A_N (3)'Image & " meat either way");
   end;

   ------------------------------------------------------------------ 11. needs
   Put_Line ("eating and sleeping: a band of six by a field of bushes, three gatherers, no cook:");
   Set_Up (With_Needs => True, With_Field => True);
   Hours := 16.0 * 24.0 + 7.0;               --  seven in the morning, in summer
   declare
      Field     : constant Natural := Berries_Left;
      Ate, Slept_All, Near_Stake, Starved, Saw_Eat_Store, Saw_Fend : Boolean := False;
      Lowest    : Float := 1.0;
      Snap      : Snapshot;
   begin
      Set_Job (1, Gatherer);
      Set_Job (2, Gatherer);
      Set_Job (3, Gatherer);
      for S in 1 .. 2 * 1_440 loop             --  two days
         Run (1);
         for I in 1 .. Members loop
            Ate := Ate or else Doing (I) = Eating;
            Saw_Eat_Store := Saw_Eat_Store or else (Doing (I) = Eating and then Job_Of (I) /= Gatherer);
            Lowest := Float'Min (Lowest, Fed_Of (I));
            Starved := Starved or else Fed_Of (I) <= 0.0;
            Saw_Fend := Saw_Fend or else Fending (I);
         end loop;
         if S = 990 then                         --  half past midnight
            declare
               N : Natural := 0;
               Far : Boolean := False;
            begin
               for I in 1 .. Members loop
                  if Asleep (I) then
                     N := N + 1;
                  end if;
                  Far := Far or else Flat (Where (I), Stake) > 6.0;
               end loop;
               Slept_All := N = Members;
               Near_Stake := not Far;
               Put_Line ("    at half past midnight:" & N'Image & " asleep; " & Name_Of (1) & ": " & Status (1));
            end;
         end if;
      end loop;
      Put_Line ("    after two days: eaten" & Eaten'Image & ", stored" & Stored (Berries)'Image & ", carried"
                & Carried_All'Image & ", on the bushes" & Berries_Left'Image & " of" & Field'Image
                & "; the hungriest at " & Img (100.0 * Lowest, 0) & " %, food for " & Img (Food_Days, 1) & " days");
      for I in 1 .. Members loop
         Put_Line ("    " & Name_Of (I) & ": " & Img (100.0 * Fed_Of (I), 0) & " % fed, " & Status (I));
      end loop;
      Check (Ate and then Saw_Eat_Store, "they eat: gatherers from their baskets, the rest from the stockpile");
      Check (Field = Berries_Left + Stored (Berries) + Carried_All + Eaten,
             "every handful picked is stored, carried or eaten");
      Check (Slept_All and then Near_Stake, "at night all six sleep, round the stake");
      Raw_Confidence := Confidence;
      Check (Starved and then Saw_Fend,
             "on raw berries alone three gatherers can't keep six fed (raw food fills poorly): they go"
             & " hungry and fend for themselves (the hungriest at " & Img (100.0 * Lowest, 0) & " %, confidence "
             & Img (100.0 * Confidence, 0) & " %)");
      Check ((for all I in 1 .. Members => not Asleep (I)), "and in the morning they are up");

      --  a save mid-meal: wait for someone at the stockpile eating
      for S in 1 .. 2_000 loop
         Run (1);
         exit when (for some I in 1 .. Members => Doing (I) = Eating and then Job_Of (I) /= Gatherer);
      end loop;
      declare
         Saved_Hours : constant Long_Float := Hours;
         Data : constant Bytes := Save;
         type Fed_List is array (1 .. 6) of Float;
         type Pos_List is array (1 .. 6) of Vec3;
         A_Fed, B_Fed : Fed_List;
         A_Pos, B_Pos : Pos_List;
         A_Eaten, B_Eaten : Natural;
         Ok : Boolean;
      begin
         Take (Snap);
         Run (600);
         A_Eaten := Eaten;
         for I in 1 .. 6 loop
            A_Fed (I) := Fed_Of (I);
            A_Pos (I) := Where (I);
         end loop;
         Give_Back (Snap);
         Hours := Saved_Hours;
         Load (Data, Ok);
         declare
            Again : constant Bytes := Save;
         begin
            Check (Ok and then Again = Data, "a save taken mid-meal loads, and saved again is the same"
                   & Data'Length'Image & " bytes");
         end;
         Run (600);
         B_Eaten := Eaten;
         for I in 1 .. 6 loop
            B_Fed (I) := Fed_Of (I);
            B_Pos (I) := Where (I);
         end loop;
         Check (A_Eaten = B_Eaten and then A_Fed = B_Fed and then A_Pos = B_Pos,
                "and 600 s later it is just as it would have been (" & A_Eaten'Image & " eaten)");
      end;

      --  a save mid-sleep
      loop
         Run (60);
         exit when Asleep (1) and then Asleep (6);
      end loop;
      declare
         Saved_Hours : constant Long_Float := Hours;
         Data : constant Bytes := Save;
         type Fed_List is array (1 .. 6) of Float;
         A_Fed, B_Fed : Fed_List;
         A_Asleep, B_Asleep : Natural := 0;
         Ok : Boolean;
      begin
         Take (Snap);
         Run (300);
         for I in 1 .. 6 loop
            A_Fed (I) := Fed_Of (I);
            A_Asleep := A_Asleep + (if Asleep (I) then 1 else 0);
         end loop;
         Give_Back (Snap);
         Hours := Saved_Hours;
         Load (Data, Ok);
         declare
            Again : constant Bytes := Save;
         begin
            Check (Ok and then Again = Data, "a save taken at night loads, and saved again is the same"
                   & Data'Length'Image & " bytes");
         end;
         Run (300);
         for I in 1 .. 6 loop
            B_Fed (I) := Fed_Of (I);
            B_Asleep := B_Asleep + (if Asleep (I) then 1 else 0);
         end loop;
         Check (A_Fed = B_Fed and then A_Asleep = B_Asleep, "and they sleep on just the same");
      end;
   end;

   Put_Line ("a cook, two hunters and two gatherers, with a camp, vegetables, bushes and deer:");
   Set_Up (With_Needs => True, With_Field => True, With_Trees => True, With_Vegetables => True);
   Hours := 16.0 * 24.0 + 7.0;
   declare
      Ok : Boolean;
      Lowest : Float := 1.0;
      Empty, Fended : Boolean := False;
   begin
      Zone_Camp ((30.0, 24.0, Ground_M), Ok);
      Set_Job (1, Gatherer);
      Set_Job (2, Gatherer);
      Set_Job (3, Hunter);
      Set_Job (4, Hunter);
      Set_Job (6, Cook);
      for S in 1 .. 2 * 1_440 loop
         Run (1);
         for I in 1 .. Members loop
            Lowest := Float'Min (Lowest, Fed_Of (I));
            Empty := Empty or else Fed_Of (I) <= 0.0;
            Fended := Fended or else Fending (I);
         end loop;
      end loop;
      Put_Line ("    after two days: eaten" & Eaten'Image & ", stew cooked" & Cooked'Image & " from" & Put_In_Pot (Meat)'Image
                & " meat," & Put_In_Pot (Vegetables)'Image & " vegetables," & Put_In_Pot (Berries)'Image
                & " berries; the hungriest at " & Img (100.0 * Lowest, 0) & " %; food for " & Img (Food_Days, 1)
                & " days; confidence " & Img (100.0 * Confidence, 0) & " %");
      Check (not Empty and then not Fended and then Lowest > 0.1,
             "they keep six fed for two days: no empty belly, nobody fending for itself");
      Check (Food_Days > 0.3, "with food to spare");
      Check (Confidence > Raw_Confidence + 0.15, "and the band is happier on stew than on raw berries ("
             & Img (100.0 * Confidence, 0) & " % against " & Img (100.0 * Raw_Confidence, 0) & " %)");
   end;

   ------------------------------------------------------------------ 12. the camp and the cook
   Put_Line ("the camp and the cook: zoning it");
   Set_Up (With_Needs => True, With_Trees => True);
   Hours := 16.0 * 24.0 + 7.0;
   declare
      Ok : Boolean;
      Cells_N : Natural;
      Camp_P : constant Vec3 := (30.0, 24.0, Ground_M);
   begin
      Set (B (31.0), B (25.0), Ground_Row, Tall_Grass);
      Zone_Camp ((Spots (1).X, Spots (1).Y, Ground_M), Ok);
      Check (not Ok, "a camp over a bush is refused");
      Zone_Camp (Stake, Ok);
      Check (not Ok, "and one over the stake");
      Zone_Camp ((23.0, 16.0, Ground_M), Ok);
      Check (not Ok, "and one over the stockpile");
      Zone_Camp (Camp_P, Ok);
      Check (Ok and then Has_Camp and then Flat (Camp, Camp_P) < 0.2, "on the open meadow it is zoned");
      Check (Get (B (31.0), B (25.0), Ground_Row) = Air, "and the grass on it is cut");
      Zone_Camp ((40.0, 40.0, Ground_M), Ok);
      Check (not Ok, "a second camp is refused");
      Zone_Stockpile (27.0, 17.0, 29.0, 22.0, Cells_N);
      Check (Cells_N > 0 and then (for all K in 1 .. Cell_Count =>
                                     abs (Cell_At (K).Centre.X - Camp.X) >= Camp_Size_M / 2.0
                                     or else abs (Cell_At (K).Centre.Y - Camp.Y) >= Camp_Size_M / 2.0),
             "a stockpile zoned across it leaves out the camp's ground (" & Img (Cells_N) & " cells taken)");
   end;

   Put_Line ("the cook: no wood stored, so sticks; meat and berries into the pot; stew");
   Set_Up (With_Needs => True, With_Trees => True);
   Hours := 16.0 * 24.0 + 7.0;
   declare
      Ok : Boolean;
      Placed : Natural;
      Saw_Sticks, Saw_Burning, Raw_With_Stew, Saw_Stew_Meal, Saw_Seated : Boolean := False;
      Raw_Before : Natural;
      Meat_In, Berries_In : Natural := 0;
      On_Bushes : constant Natural := Berries_Left;   --  the hungry with no stew may pick these for themselves
      Expect : Natural;
      function Carried_Of (K : Item_Kind) return Natural is
         N : Natural := 0;
      begin
         for I in 1 .. Members loop
            if Carrying (I) = K then
               N := N + Carried (I);
            end if;
         end loop;
         return N;
      end Carried_Of;
   begin
      Zone_Camp ((30.0, 24.0, Ground_M), Ok);
      Supply (Meat, 12, Placed);
      Supply (Berries, 60, Placed);
      Set_Job (1, Cook);
      for S in 1 .. 900 loop
         Run (1);
         Saw_Sticks := Saw_Sticks or else Status (1) = "picking up sticks (0)";
         Saw_Burning := Saw_Burning or else Camp_State.Burning;
         exit when Camp_State.Stew > 0;
      end loop;
      Meat_In := Put_In_Pot (Meat);
      Berries_In := Put_In_Pot (Berries);
      Expect := Natural (Float'Floor (Float (Meat_In * Stew_Food (Meat) + Berries_In * Stew_Food (Berries))
                                      * Balanced_Bonus * (0.9 + 0.2 * Cooking_Of (1)) + 0.5));
      Put_Line ("    " & Img (Meat_In) & " meat and " & Img (Berries_In) & " berries in the pot, stew"
                & Img (Camp_State.Stew) & " (cook " & Img (Cooking_Of (1), 2) & "); " & Name_Of (1) & ": " & Status (1));
      Check (Saw_Sticks and then Saw_Burning, "with no logs the cook picks up sticks under a tree and lights the fire");
      Check (Meat_In = 12 and then Berries_In = 60, "everything goes in: the meat and then the berries");
      Check (Camp_State.Stew = Expect and then Cooked = Expect,
             "the pot makes Stew_Food a thing, a quarter more for meat and greens, by the cook's hand (" & Img (Expect)
             & ")");
      Check (Stored (Meat) + Carried_Of (Meat) + Put_In_Pot (Meat) = 12, "every joint of meat is stored, carried or in the pot");
      --  the band eats: stew while there is any
      for S in 1 .. 8 * 60 loop
         Raw_Before := Eaten_Raw (Berries);
         declare
            Stew_Now : constant Natural := Camp_State.Stew;
         begin
            Run (1);
            if Eaten_Raw (Berries) > Raw_Before and then Stew_Now >= 80 then
               Raw_With_Stew := True;
            end if;
         end;
         for I in 1 .. Members loop
            if Doing (I) = Eating and then Status (I) = "eating stew" then
               Saw_Stew_Meal := True;
            end if;
         end loop;
      end loop;
      Put_Line ("    eight hours on: stew" & Img (Camp_State.Stew) & ", eaten" & Img (Eaten) & ", raw "
                & Img (Eaten_Raw (Berries)) & "; " & Name_Of (2) & ": " & Img (100.0 * Fed_Of (2), 0) & " % fed");
      Check (Saw_Stew_Meal, "the hungry go to the pot for stew");
      Check (not Raw_With_Stew, "and nobody eats raw berries while there is stew");
      Check (Stored (Berries) + Carried_Of (Berries) + Put_In_Pot (Berries) + Eaten_Raw (Berries)
               = 60 + On_Bushes - Berries_Left,
             "every handful of berries (the 60 stored, and any picked) is stored, carried, in the pot or eaten raw");
      --  logs come in: firewood, the seats, a full stack; they eat sitting at the fire
      Supply (Wood, 10, Placed);
      Supply (Meat, 8, Placed);
      Supply (Berries, 60, Placed);
      for S in 1 .. 24 * 60 loop
         Run (1);
         for I in 1 .. Members loop
            Saw_Seated := Saw_Seated or else Doing (I) = Eating_Seated;
         end loop;
         exit when Camp_State.Seats = Seat_Logs and then Saw_Seated;
      end loop;
      Put_Line ("    " & Img (Camp_State.Seats) & " seats, " & Img (Camp_State.Logs) & " logs stacked, "
                & Img (Camp_State.Burnt) & " burnt, " & Img (Stored (Wood)) & " stored; at "
                & Img (Hour_Now (Hours), 1) & " h");
      Check (Camp_State.Seats = Seat_Logs, "the cook stacks firewood and lays the four seat logs");
      Check (Saw_Seated, "and they eat their stew sitting at the fire");
      --  night, round the fire
      for S in 1 .. 24 * 60 loop
         Run (1);
         exit when Hour_Now (Hours) >= 1.0 and then Hour_Now (Hours) < 1.1;
      end loop;
      declare
         N : Natural := 0;
         Far : Boolean := False;
      begin
         for I in 1 .. Members loop
            if Asleep (I) then
               N := N + 1;
            end if;
            Far := Far or else Flat (Where (I), Camp) > 5.0;
         end loop;
         Put_Line ("    at one in the morning:" & N'Image & " asleep; the fire " & (if Camp_State.Burning then "burning"
                                                                                  else "out") & ", "
                   & Img (Camp_State.Logs) & " logs stacked");
         Check (N = Members and then not Far, "at night they all sleep round the fire");
      end;
      Check (Stored (Wood) + Carried_Of (Wood) + Camp_State.Seats + Camp_State.Logs + Camp_State.Burnt = 10,
             "every log is stored, carried, a seat, stacked by the fire or burnt");
   end;

   Put_Line ("the first cook chooses itself:");
   Set_Up (With_Needs => True, With_Trees => True);
   Hours := 16.0 * 24.0 + 7.0;
   declare
      Ok : Boolean;
      Placed : Natural;
      Best : Positive := 1;
      Cooks_N : Natural := 0;
   begin
      for I in 2 .. Members loop
         if Cooking_Of (I) > Cooking_Of (Best) then
            Best := I;
         end if;
      end loop;
      Zone_Camp ((30.0, 24.0, Ground_M), Ok);
      Run (5);
      Check ((for all I in 1 .. Members => Job_Of (I) /= Cook), "with nothing to cook, nobody takes it up");
      Supply (Meat, 4, Placed);
      Run (5);
      Check (Job_Of (Best) = Cook, "with meat stored, the best cook (" & Name_Of (Best) & ", "
             & Img (Cooking_Of (Best), 2) & ") takes it up");
      Check (Director_Of (Best) = No_One, "of its own choice: nobody directs it");
      Set_Job (Best, Gatherer);
      Check (Director_Of (Best) = The_Player, "given other work by the player, it is the player's to direct");
      Run (30);
      for I in 1 .. Members loop
         if Job_Of (I) = Cook then
            Cooks_N := Cooks_N + 1;
         end if;
      end loop;
      Check (Cooks_N = 0, "once only: the player's choice stands after that");
   end;

   Put_Line ("a save mid-cook:");
   Set_Up (With_Needs => True, With_Trees => True);
   Hours := 16.0 * 24.0 + 7.0;
   declare
      Ok : Boolean;
      Placed : Natural;
      Snap : Snapshot;
   begin
      Zone_Camp ((30.0, 24.0, Ground_M), Ok);
      Supply (Meat, 8, Placed);
      Supply (Berries, 60, Placed);
      Supply (Wood, 3, Placed);
      Set_Job (1, Cook);
      for S in 1 .. 900 loop
         Run (1);
         exit when Camp_State.Stirring;
      end loop;
      Run (20);
      declare
         Saved_Hours : constant Long_Float := Hours;
         Data : constant Bytes := Save;
         type Fed_List is array (1 .. 6) of Float;
         type Pos_List is array (1 .. 6) of Vec3;
         A_Fed, B_Fed : Fed_List;
         A_Pos, B_Pos : Pos_List;
         A_Stew, B_Stew, A_Logs, B_Logs : Natural;
         A_Fuel, B_Fuel : Float;
      begin
         Check (Camp_State.Stirring, "the cook is stirring the pot");
         Take (Snap);
         Run (400);
         A_Stew := Camp_State.Stew;
         A_Logs := Camp_State.Logs;
         A_Fuel := Camp_State.Fuel_H;
         for I in 1 .. 6 loop
            A_Fed (I) := Fed_Of (I);
            A_Pos (I) := Where (I);
         end loop;
         Give_Back (Snap);
         Hours := Saved_Hours;
         Load (Data, Ok);
         declare
            Again : constant Bytes := Save;
         begin
            Check (Ok and then Again = Data, "a save taken mid-cook loads, and saved again is the same"
                   & Data'Length'Image & " bytes");
         end;
         Run (400);
         B_Stew := Camp_State.Stew;
         B_Logs := Camp_State.Logs;
         B_Fuel := Camp_State.Fuel_H;
         for I in 1 .. 6 loop
            B_Fed (I) := Fed_Of (I);
            B_Pos (I) := Where (I);
         end loop;
         Check (A_Stew = B_Stew and then A_Logs = B_Logs and then A_Fuel = B_Fuel and then A_Fed = B_Fed
                and then A_Pos = B_Pos,
                "and 400 s later it is just as it would have been (stew" & A_Stew'Image & ")");
      end;
   end;

   Put_Line ("a save from before the camp (version 7):");
   Set_Up (With_Needs => True, With_Field => True);
   declare
      package SIO renames Ada.Streams.Stream_IO;
      F  : SIO.File_Type;
      Ok : Boolean;
   begin
      SIO.Open (F, SIO.In_File, "tools/colony_v7.bin");
      declare
         Data : Bytes (0 .. Natural (SIO.Size (F)) - 1);
      begin
         Bytes'Read (SIO.Stream (F), Data);
         SIO.Close (F);
         Load (Data, Ok);
         Check (Ok and then Members = 6 and then not Has_Camp and then Needs,
                "it loads: six in the band, needs on, no camp");
         Hours := 16.0 * 24.0 + 7.0 + 432.4 / 60.0;
         Run (120);
         declare
            Again : constant Bytes := Save;
            Ok2 : Boolean;
         begin
            Load (Again, Ok2);
            Check (Ok2 and then Save = Again, "two minutes on it saves as version 8 and loads back the same");
         end;
      end;
   end;

   --  what the cook keeps for the pot (John, 2026-11-12: "can the cook reserve food in the stockpile and only
   --  suprlus is availible to eat raw if no stew is present"): a camp with its hearth and a cook, berries stored,
   --  no wood and no trees (so nothing is cooked all day), no bushes (so nothing to fend with)
   Put_Line ("what the cook keeps for the pot: nobody eats it raw, but what is over it they do:");
   for Keeps in Boolean loop
      for Plenty in Boolean loop
         Set_Up (With_Needs => True, With_Bushes => False);
         Set_Cook_Hold (Keeps);
         Hours := 16.0 * 24.0 + 7.0;
         declare
            Ok     : Boolean;
            Placed : Natural;
            Stock  : constant Natural := (if Plenty then 500 else 200);   --  1,500 points as stew, or 600: a pot is 900
            Kept   : constant Natural := Natural'Min (Stock, Cook_Keeps / Stew_Food (Berries));
            Raw_Calm : Natural := 0;              --  berries eaten raw while nobody was yet down to its last
            Least    : Natural := Natural'Last;   --  and the fewest there were in store meanwhile
            Held_Then : Natural := 0;             --  what the cook kept, with everyone hungry
            Hungry_N  : Natural := 0;
            Lowest   : Float;
            Calm     : Boolean := True;           --  nobody has yet been down to its last
         begin
            Zone_Camp ((30.0, 24.0, Ground_M), Ok);
            Supply (Berries, Stock, Placed);
            Set_Job (1, Cook);
            for S in 1 .. 11 * 60 loop
               Run (1);
               Lowest := 1.0;
               for I in 1 .. Members loop
                  Lowest := Float'Min (Lowest, Fed_Of (I));
               end loop;
               Calm := Calm and then Lowest >= Very_Hungry;
               if Calm then
                  Raw_Calm := Eaten_Raw (Berries);
                  Least := Natural'Min (Least, Stored (Berries));
                  if Lowest < 0.3 then
                     Held_Then := Cook_Held (Berries);
                     Hungry_N := 0;
                     for I in 1 .. Members loop
                        if Ada.Strings.Fixed.Index (Status (I), "hungry") = 1 then
                           Hungry_N := Hungry_N + 1;
                        end if;
                     end loop;
                  end if;
               end if;
            end loop;
            Put_Line ("    " & (if Keeps then "kept" else "not kept") & "," & Stock'Image & " berries stored: eaten raw"
                      & Raw_Calm'Image & " before anyone was at its last, the fewest in store then" & Least'Image
                      & ";" & Held_Then'Image & " kept;" & Hungry_N'Image & " hungry; eaten raw in the end"
                      & Natural'Image (Eaten_Raw (Berries)) & "; cooked" & Cooked'Image);
            if Keeps and then not Plenty then
               Check (Ok and then Placed = Stock and then Cooked = 0 and then Raw_Calm = 0 and then Least = Stock
                      and then Held_Then = Stock and then Hungry_N = Members,
                      "less than a pot's fill stored, the hearth standing and nothing cooked: all of it is the cook's, and"
                      & " the six go hungry beside it rather than eat it raw");
               Check (Eaten_Raw (Berries) > 0 and then Deaths = 0,
                      "until one is at its last with nothing to gather: the starving break into it ("
                      & Img (Eaten_Raw (Berries)) & " berries eaten raw by the eleventh hour)");
            elsif Keeps then
               Check (Ok and then Placed = Stock and then Cooked = 0 and then Raw_Calm = Stock - Kept and then Least = Kept
                      and then Held_Then = Kept,
                      "more than a pot's fill stored: what is over it is eaten raw (" & Img (Raw_Calm) & " berries), and the"
                      & " pot's fill is left (" & Img (Kept) & ")");
            else
               Check (Ok and then Placed = Stock and then Cooked = 0 and then Raw_Calm > 0 and then Least < Kept
                      and then Held_Then = 0,
                      "(with nothing kept, as it was: " & Img (Raw_Calm) & " of" & Stock'Image
                      & " berries eaten raw as soon as they were hungry)");
            end if;
         end;
      end loop;
   end loop;

   --  a load in its arms is taken where it was going before its carrier eats (John, 2026-11-13: "people
   --  carrying items to the stockpile will stop and eat instead of completing their task and then eating, this
   --  creates an oddity where foresters carrying logs back to the stockpile have a log on their sholder while
   --  they are eating"): three days of a band with a camp, a cook, foresters and gatherers, every meal begun
   --  looked at
   Put_Line ("a load taken home before its carrier eats:");
   declare
      Placed : Natural;
      Ok     : Boolean;
      Was_Eating : array (1 .. Max_Members) of Boolean := [others => False];
      Fed_Then   : array (1 .. Max_Members) of Float := [others => 1.0];
      Meals, At_Last, No_Room, Own, Wrong : Natural := 0;
      Stew_Meals : Natural := 0;
   begin
      Set_Up (With_Needs => True, With_Trees => True, With_Field => True, With_Vegetables => True);
      Hours := 16.0 * 24.0 + 7.0;
      Zone_Camp ((30.0, 24.0, Ground_M), Ok);
      Supply (Meat, 40, Placed);
      Set_Job (1, Cook);
      Set_Job (2, Forester);
      Set_Job (3, Forester);
      Set_Job (4, Gatherer);
      Set_Job (5, Gatherer);
      Set_Job (6, Forester);
      for S in 1 .. 3 * 1_440 loop
         Run (1);
         for I in 1 .. Members loop
            declare
               E : constant Boolean := Doing (I) in Eating | Eating_Seated;
            begin
               if E and then not Was_Eating (I) then
                  Meals := Meals + 1;
                  if Doing (I) = Eating_Seated then
                     Stew_Meals := Stew_Meals + 1;
                  end if;
                  if Carried (I) > 0 then
                     --  (one at its last eats whatever it holds; one that fends eats what it gathered; what a
                     --  gatherer has gathered it eats where it is, with no stew to be had)
                     if Fed_Then (I) < Very_Hungry then
                        At_Last := At_Last + 1;
                     elsif not (for some K in 1 .. Cell_Count =>
                                  Cell_At (K).Kind = Nothing
                                  or else (Cell_At (K).Kind = Carrying (I)
                                           and then Cell_At (K).Count + Carried (I) <= Cell_Limit (Carrying (I))))
                     then
                        No_Room := No_Room + 1;
                     elsif Fending (I)
                       or else (Carrying (I) in Berries | Vegetables | Apples and then Doing (I) /= Eating_Seated)
                     then
                        Own := Own + 1;
                     else
                        Wrong := Wrong + 1;
                     end if;
                  end if;
               end if;
               if not E then
                  Fed_Then (I) := Fed_Of (I);
               end if;
               Was_Eating (I) := E;
            end;
         end loop;
      end loop;
      Check (Ok and then Meals > 30 and then Stew_Meals > 10 and then Wrong = 0 and then Deaths = 0,
             "of" & Meals'Image & " meals in three days (" & Img (Stew_Meals) & " of stew at the fire) none was begun"
             & " with a load in its eater's arms but by one down to its last (" & Img (At_Last) & "), one with nowhere"
             & " in the stockpile for it (" & Img (No_Room) & ") or eating what it had gathered where it was ("
             & Img (Own) & "; begun with a load otherwise:" & Wrong'Image & ")");
   end;

   ------------------------------------------------------------------ 13. fending, mood, and death in winter
   Put_Line ("fending for itself: nothing stored, a forester and a hunter at work, bushes about:");
   Set_Up (With_Needs => True, With_Field => True, With_Trees => True);
   Hours := 16.0 * 24.0 + 7.0;
   declare
      Forester_Fended, Hunter_Fended : Boolean := False;
      Least : Float := 1.0;
      Felled_At_Fend : Natural := 0;
      Felled_While   : Boolean := False;
   begin
      Set_Job (1, Forester);
      Set_Job (2, Hunter);
      for S in 1 .. 20 * 60 loop
         Run (1);
         if Fending (1) and then not Forester_Fended then
            Forester_Fended := True;
            Felled_At_Fend := Trees_Felled;
            Put_Line ("    " & Name_Of (1) & " at " & Img (Hour_Now (Hours), 1) & " h: " & Status (1)
                      & " (" & Img (100.0 * Fed_Of (1), 0) & " % fed)");
         end if;
         if Fending (1) and then Trees_Felled > Felled_At_Fend then
            Felled_While := True;
         end if;
         Hunter_Fended := Hunter_Fended or else Fending (2);
         Least := Float'Min (Least, Confidence);
      end loop;
      Put_Line ("    twenty hours on: eaten raw" & Eaten_Raw (Berries)'Image & " berries; confidence at its lowest "
                & Img (100.0 * Least, 0) & " %");
      Check (Forester_Fended and then Hunter_Fended,
             "starving, with nothing stored, the forester and the hunter leave their work to fend for themselves");
      Check (not Felled_While, "and the felling waits while the forester fends");
      Check (Eaten_Raw (Berries) > 0, "they pick berries and eat them");
      Check (Least < Mood_Start - 0.2, "and the band's confidence falls (" & Img (100.0 * Least, 0) & " %)");
   end;

   --  what a fender goes for is whatever is nearest (John, 2026-11-12: "serfs would go long distances
   --  to fend for themselves to eat vegetables when furit and berries were near by")
   Put_Line ("fending for itself: a field of bushes north of the stake, wild vegetables 20 m and more south-east, none of either stored:");
   Set_Up (With_Needs => True, With_Field => True, With_Vegetables => True);
   Hours := 16.0 * 24.0 + 7.0;
   Set_Reserve (Vegetables, 20);       --  (wanted and none stored: a gatherer goes for vegetables alone)
   declare
      Berries_First, Fended : Natural := 0;
      Seen : array (1 .. 6) of Boolean := [others => False];
   begin
      for I in 1 .. 6 loop
         Set_Job (I, Forester);          --  (nothing to fell: they stand about until they starve)
      end loop;
      for S in 1 .. 16 * 60 loop
         Run (1);
         for I in 1 .. 6 loop
            if Fending (I) and then not Seen (I) then
               Seen (I) := True;
               Fended := Fended + 1;
               if Ada.Strings.Fixed.Index (Status (I), "bush") > 0 or else Ada.Strings.Fixed.Index (Status (I), "berr") > 0 then
                  Berries_First := Berries_First + 1;
               else
                  Put_Line ("    " & Name_Of (I) & ", " & Img (Flat (Where (I), Stake_P), 0) & " m from the stake: " & Status (I));
               end if;
            end if;
         end loop;
         exit when Fended = 6;
      end loop;
      Check (Fended = 6 and then Berries_First = 6 and then Eaten_Raw (Vegetables) = 0,
             "starving, each goes to a bush near it and none to the vegetables (" & Img (Berries_First) & " of "
             & Img (Fended) & " for the berries first)");
   end;

   Put_Line ("no food at all, in summer:");
   Set_Up (With_Needs => True, With_Bushes => False);
   Hours := 20.0 * 24.0 + 7.0;
   Run (3 * 1_440);
   Put_Line ("    three days on:" & Living'Image & " living; " & Name_Of (1) & ": " & Status (1));
   Check (Living = 6 and then Deaths = 0, "nobody dies outside winter (weak, starving, but alive)");

   Put_Line ("no food at all, in winter:");
   Set_Up (With_Needs => True, With_Bushes => False);
   Hours := 50.0 * 24.0 + 7.0;
   declare
      First_Dead : Natural := 0;
      Conf_Before : Float := 0.0;
      Snap : Snapshot;
   begin
      for S in 1 .. 4 * 1_440 loop
         Conf_Before := Confidence;
         Run (1);
         if Deaths > 0 and then First_Dead = 0 then
            First_Dead := S;
            Put_Line ("    the first death after" & Img (Float (S) / 60.0, 1) & " game hours: confidence "
                      & Img (100.0 * Conf_Before, 0) & " % to " & Img (100.0 * Confidence, 0) & " %");
            exit;
         end if;
      end loop;
      Check (First_Dead > 0 and then Float (First_Dead) / 60.0 >= Death_Hours,
             "in winter a belly empty for two days is death");
      declare
         D : Natural := 0;
      begin
         for I in 1 .. Members loop
            if Dead (I) then
               D := I;
            end if;
         end loop;
         Check (D > 0 and then Doing (D) = Castle.Colony.Dead and then Status (D) = "dead, of hunger"
                and then Living = Members - Deaths,
                "the dead lie where they fell, and the band is one fewer");
         Check (Living = 0 or else Confidence < Conf_Before, "and the living grieve");
      end;
      declare
         Saved_Hours : constant Long_Float := Hours;
         Data : constant Bytes := Save;
         Ok : Boolean;
         A_Deaths : Natural;
      begin
         Take (Snap);
         Run (300);
         A_Deaths := Deaths;
         Give_Back (Snap);
         Hours := Saved_Hours;
         Load (Data, Ok);
         declare
            Again : constant Bytes := Save;
         begin
            Check (Ok and then Again = Data, "a save with the dead loads, and saved again is the same");
         end;
         Run (300);
         Check (Deaths = A_Deaths, "and goes on the same");
      end;
   end;

   ------------------------------------------------------------------ 14. vegetables and apples
   Put_Line ("wild vegetables: two gatherers, none in store:");
   Set_Up (With_Vegetables => True);
   Hours := 16.0 * 24.0 + 7.0;
   declare
      Plants : constant Natural :=
        Count_In (B (Veg_X0), B (Veg_Y0), B (Veg_X1), B (Veg_Y1), Ground_Row, Ground_Row, Wild_Vegetables);
      Berries_At_Start : constant Natural := Berries_Left;
      Berries_First : Boolean := False;
      function Carried_Veg return Natural is
         N : Natural := 0;
      begin
         for I in 1 .. Members loop
            if Carrying (I) = Vegetables then
               N := N + Carried (I);
            end if;
         end loop;
         return N;
      end Carried_Veg;
   begin
      Set_Job (1, Gatherer);
      Set_Job (2, Gatherer);
      for S in 1 .. 600 loop
         declare
            None_Stored : constant Boolean := Have (Vegetables) = 0;
            Before : constant Natural := Berries_Left;
         begin
            Run (1);
            if None_Stored and then Berries_Left < Before then
               Berries_First := True;
            end if;
         end;
      end loop;
      declare
         Left : constant Natural :=
           Count_In (B (Veg_X0), B (Veg_Y0), B (Veg_X1), B (Veg_Y1), Ground_Row, Ground_Row, Wild_Vegetables);
      begin
         Put_Line ("    ten hours on: " & Img (Plants - Left) & " of" & Plants'Image & " pulled, " & Img (Stored (Vegetables))
                   & " stored; " & Img (Berries_At_Start - Berries_Left) & " berries picked; " & Name_Of (1) & ": "
                   & Status (1));
         Check (Stored (Vegetables) > 0 and then not Berries_First,
                "with no vegetables in store, they pull vegetables and pick nothing else");
         Check (Vegetables_Pulled = Plants - Left and then Plants - Left = Stored (Vegetables) + Carried_Veg,
                "every vegetable pulled is gone from the ground, stored or carried");
      end;
      Set_Job (1, Unassigned);
      Set_Job (2, Unassigned);
      Run (60);
      declare
         Before : constant Natural :=
           Count_In (B (Veg_X0), B (Veg_Y0), B (Veg_X1), B (Veg_Y1), Ground_Row, Ground_Row, Wild_Vegetables);
         After_Winter, After_Spring : Natural;
      begin
         Hours := 50.0 * 24.0 + 7.0;          --  winter: nothing grows back
         Run (5);
         After_Winter :=
           Count_In (B (Veg_X0), B (Veg_Y0), B (Veg_X1), B (Veg_Y1), Ground_Row, Ground_Row, Wild_Vegetables);
         Hours := 62.0 * 24.0 + 7.0;          --  spring
         Run (5);
         After_Spring :=
           Count_In (B (Veg_X0), B (Veg_Y0), B (Veg_X1), B (Veg_Y1), Ground_Row, Ground_Row, Wild_Vegetables);
         Check (After_Winter = Before and then After_Spring = Plants,
                "they grow back after ten days, but not in winter (" & Img (Before) & ", then" & After_Winter'Image
                & ", then" & After_Spring'Image & " of" & Plants'Image & ")");
      end;
   end;

   Put_Line ("apples: a gatherer, the apple tree the only thing in reach:");
   Set_Up (With_Bushes => False, With_Trees => True);
   Hours := 30.0 * 24.0 + 7.0;               --  autumn
   declare
      On_Trees : Natural;
   begin
      Run (1);                               --  (the colony's clock comes to autumn)
      On_Trees := Apples_Left;
      Set_Job (1, Gatherer);
      Run (600);
      Put_Line ("    " & Img (On_Trees) & " on the tree; ten hours on " & Img (Stored (Apples)) & " stored, "
                & Img (Apples_Left) & " left; " & Name_Of (1) & ": " & Status (1));
      Check (On_Trees > 0 and then Stored (Apples) > 0
             and then Stored (Apples) + Carried (1) = On_Trees - Apples_Left,
             "in autumn the gatherer picks the apple tree, every apple stored or carried");
   end;
   Set_Up (With_Bushes => False, With_Trees => True);
   Hours := 16.0 * 24.0 + 7.0;               --  early summer
   Set_Job (1, Gatherer);
   Run (60);
   Check (Apples_Left = 0 and then Stored (Apples) = 0 and then Status (1) = "nothing to gather in reach",
          "before summer's tenth day there are no apples: " & Status (1));

   Put_Line ("grain with the straw: a porter by a patch of wild grain, two blocks tall:");
   Set_Up (With_Bushes => False, With_Grain => True);
   declare
      Plants : constant Natural := 12;
      Data_Ok : Boolean;
   begin
      Set_Job (1, Porter);
      Run (60);
      declare
         Data : constant Bytes := Save;
      begin
         Load (Data, Data_Ok);
         Check (Data_Ok and then Save = Data, "a save taken mid-cut loads, and saved again is the same");
      end;
      Run (600);
      Put_Line ("    " & Img (Plants) & " plants: " & Img (Stored (Straw)) & " straw and " & Img (Stored (Grain))
                & " grain stored; " & Name_Of (1) & ": " & Status (1));
      Check (Stored (Straw) = Plants and then Stored (Grain) + Grain_Carried (1) = Grain_Per_Plant * Plants
             and then Stored (Grain) > 0,
             "each plant of grain cut gives a sheaf of straw and two handfuls of grain, stored apart");
      Check (Count_In (B (29.0), B (25.0), B (34.0), B (29.0), Ground_Row, Ground_Row + 2, Wild_Grain) = 0,
             "and the whole stalk is cut");
   end;

   ------------------------------------------------------------------ 15. winter
   Put_Line ("the winter store: a day of food to be held, 480 grain and 20 meat stored, a cook:");
   Set_Up (With_Needs => True, With_Bushes => False, With_Trees => True);
   Hours := 16.0 * 24.0 + 7.0;
   declare
      Ok : Boolean;
      Placed : Natural;
   begin
      Zone_Camp ((30.0, 24.0, Ground_M), Ok);
      Supply (Grain, 480, Placed);
      Supply (Meat, 20, Placed);
      Set_Winter_Store (1);
      Set_Job (1, Cook);
      Check (Store_Held_Days > 0.7 and then Store_Held_Days < 0.9,
             "of 1.8 days of food stored, the first day stays free and the rest is held ("
             & Img (Store_Held_Days, 2) & " days)");
      declare
         Least : Integer := Integer'Last;    --  grain stored less grain held, at its lowest
      begin
         for S in 1 .. 8 * 60 loop
            Run (1);
            Least := Integer'Min (Least, 4 * Stored (Grain) - Integer (Store_Held_Days * 1_392.0));
         end loop;
         Put_Line ("    eight hours on, in summer: " & Img (Stored (Grain)) & " grain stored, " & Img (Put_In_Pot (Grain))
                   & " grain and " & Img (Put_In_Pot (Meat)) & " meat in the pot; held " & Img (Store_Held_Days, 2)
                   & " days");
         Check (Least >= -8 and then Put_In_Pot (Meat) > 0 and then Store_Held_Days > 0.3,
                "the cook cooks the meat and the free grain and never dips into the held grain");
      end;
      declare
         Data : constant Bytes := Save;
      begin
         Load (Data, Ok);
         Check (Ok and then Save = Data and then Winter_Store = 1, "the order is saved");
      end;
      declare
         Grain_Before : constant Natural := Stored (Grain);
      begin
         Hours := 50.0 * 24.0 + 7.0;
         Run (24 * 60);
         Put_Line ("    a day into winter: " & Img (Stored (Grain)) & " grain stored (" & Img (Grain_Before) & " before)");
         Check (Store_Held_Days = 0.0 and then Stored (Grain) < Grain_Before,
                "in winter the hold lifts and the store is cooked");
      end;
   end;

   Put_Line ("a winter night: no wood, then wood and a cook:");
   Set_Up (With_Needs => True, With_Field => True);
   Hours := 50.0 * 24.0 + 7.0;
   declare
      Ok : Boolean;
      Cold_N : Natural := 0;
   begin
      Zone_Camp ((30.0, 24.0, Ground_M), Ok);
      Set_Job (2, Gatherer);
      Run (60);
      Check (Status (2) = "nothing to gather in winter" and then Berries_Left > 0,
             "nothing is gathered in winter, berries on the bushes or not: " & Status (2));
      loop
         Run (10);
         exit when Hour_Now (Hours) >= 1.0 and then Hour_Now (Hours) < 2.0;
      end loop;
      for I in 1 .. Members loop
         Cold_N := Cold_N + (if Cold (I) then 1 else 0);
      end loop;
      Check (Cold_N = Members and then not Camp_State.Burning, "with no fire they all sleep cold");
   end;
   Set_Up (With_Needs => True, With_Bushes => False);
   Hours := 50.0 * 24.0 + 7.0;
   declare
      Ok : Boolean;
      Placed : Natural;
      Cold_N, Asleep_N : Natural := 0;
   begin
      Zone_Camp ((30.0, 24.0, Ground_M), Ok);
      Supply (Wood, 20, Placed);
      Supply (Meat, 20, Placed);
      Supply (Grain, 120, Placed);
      Set_Job (1, Cook);
      loop
         Run (10);
         exit when Hour_Now (Hours) >= 1.0 and then Hour_Now (Hours) < 2.0;
      end loop;
      for I in 1 .. Members loop
         Cold_N := Cold_N + (if Cold (I) then 1 else 0);
         Asleep_N := Asleep_N + (if Asleep (I) then 1 else 0);
      end loop;
      Put_Line ("    at one in the morning:" & Asleep_N'Image & " asleep," & Cold_N'Image & " cold; "
                & Img (Camp_State.Burnt) & " logs burnt since seven, " & Img (Camp_State.Logs) & " stacked");
      Check (Asleep_N = Members and then Cold_N = 0 and then Camp_State.Burning,
             "with wood and a cook the fire burns through the night and nobody is cold");
      Check (Camp_State.Burnt >= 4, "the fire is kept in all day in winter (a log every four hours)");
   end;

   Put_Line ("deer wander in:");
   Set_Up;
   Hours := 16.0 * 24.0 + 7.0;
   Run (5);
   declare
      Killed : Natural := 0;
      Before : Natural;
   begin
      for K in 1 .. Castle.Herds.Deer_Slots loop
         if Castle.Herds.Alive (K) and then Castle.Herds.Herd_Of (K) = 1 and then Killed < 3 then
            Castle.Herds.Kill (K);
            Killed := Killed + 1;
         end if;
      end loop;
      Before := Castle.Herds.In_Herd (1);
      Hours := 18.0 * 24.0 - 0.01;            --  a three-day mark goes by
      Run (5);
      Check (Before = 2 and then Castle.Herds.In_Herd (1) = 4 and then Castle.Herds.In_Herd (2) = 5,
             "every three days two deer join a herd that is short (2, then" & Castle.Herds.In_Herd (1)'Image
             & "); a full herd gets none");
   end;

   ------------------------------------------------------------------ 16. zones, and who directs whom
   Put_Line ("zones: one zoning is one zone, and the camp is another:");
   Set_Up (With_Needs => True);
   Hours := 16.0 * 24.0 + 7.0;
   declare
      Ok : Boolean;
      Cells, Placed : Natural;
   begin
      Check (Zone_Count = 1 and then Zone_At (1).Kind = Stockpile_Zone and then Zone_At (1).Cells = 8
             and then Zone_At (1).Lo.X = 21.0 and then Zone_At (1).Lo.Y = 15.0
             and then Zone_At (1).Hi.X = 25.0 and then Zone_At (1).Hi.Y = 17.0,
             "the stockpile zoned beside the path is zone 1: its 8 cells, its borders the box round them");
      Zone_Stockpile (30.0, 15.0, 33.0, 17.0, Cells);
      Zone_Stockpile (33.0, 15.0, 35.0, 17.0, Cells);
      Check (Zone_Count = 3 and then Zone_At (2).Cells = 6 and then Zone_At (3).Cells = 4
             and then Zone_At (2).Hi.X = 33.0 and then Zone_At (3).Lo.X = 33.0,
             "two zoned side by side, touching, stay two zones (6 and 4 cells)");
      Check (Zone_On (32.5, 15.5) = 2 and then Zone_On (33.5, 15.5) = 3 and then Zone_On (28.0, 15.5) = 0
             and then Zone_On (21.5, 16.5) = 1,
             "the ground knows which zone it is in, and open ground is in none");
      Zone_Stockpile (2.0, 50.0, 6.0, 54.0, Cells);
      Check (Cells = 0 and then Zone_Count = 3, "a stockpile refused makes no zone");
      Zone_Stockpile (24.0, 15.0, 27.0, 17.0, Cells);
      Check (Cells = 4 and then Zone_Count = 4 and then Zone_At (1).Cells = 8 and then Zone_At (4).Cells = 4
             and then Zone_On (24.5, 15.5) = 1 and then Zone_On (25.5, 15.5) = 4,
             "one zoned over part of another gets only the ground still free: no cell is in two zones");
      Check (Camp_Zone = 0, "no camp, no camp zone");
      Zone_Camp ((30.0, 24.0, Ground_M), Ok);
      Check (Ok and then Zone_Count = 5 and then Camp_Zone = 5 and then Zone_At (5).Kind = Camp_Zone
             and then Zone_At (5).Hi.X - Zone_At (5).Lo.X = Camp_Size_M
             and then Zone_At (5).Hi.Y - Zone_At (5).Lo.Y = Camp_Size_M
             and then Zone_On (Camp.X + 3.0, Camp.Y - 3.0) = 5 and then Zone_On (Camp.X + 4.0, Camp.Y) = 0,
             "the camp is a zone too: its 7 m square round the fire");
      Check (Zones_Sound, "every cell is in one stockpile zone, each zone counts its cells, the camp has its own");
      Supply (Berries, 150, Placed);
      Supply (Wood, 5, Placed);
      Check (Zone_At (1).Holds (Berries) = 150 and then Zone_At (1).Holds (Wood) = 5 and then Zone_At (1).In_Use = 3
             and then Zone_At (2).In_Use = 0 and then Zone_At (2).Holds (Berries) = 0,
             "a zone gathers what lies in it: 150 berries and 5 logs in three cells of the first, the others empty");
      Set_Job (2, Gatherer);
      Set_Job (3, Gatherer);
      declare
         Coming_Seen, Coming_Ok, Going_Seen, Going_Ok, Camp_Seen, Camp_Ok : Boolean := False;
      begin
         for S in 1 .. 1_500 loop
            Run (1);
            declare
               Coming, Going, On_Way, To_Pot, To_Take : Natural := 0;
            begin
               for Z in 1 .. Zone_Count loop
                  if Zone_At (Z).Kind = Stockpile_Zone then
                     Coming := Coming + Zone_At (Z).Coming (Berries);
                     Going := Going + Zone_At (Z).Going (Berries);
                  end if;
               end loop;
               for I in 1 .. Members loop
                  declare
                     St : constant String := Status (I);
                  begin
                     if St'Length > 16 and then St (St'Last - 15 .. St'Last) = "to the stockpile" then
                        On_Way := On_Way + Carried (I);
                     elsif St'Length > 10 and then St (St'Last - 9 .. St'Last) = "to the pot" then
                        To_Pot := To_Pot + Carried (I);
                     elsif St = "fetching berries for the pot" then
                        To_Take := To_Take + 1;
                     end if;
                  end;
               end loop;
               if On_Way > 0 and then not Coming_Seen then
                  Coming_Seen := True;
                  Coming_Ok := Coming = On_Way;
               end if;
               if To_Take > 0 and then not Going_Seen then
                  Going_Seen := True;
                  Going_Ok := Going > 0;
               end if;
               if To_Pot > 0 and then not Camp_Seen then
                  Camp_Seen := True;
                  Camp_Ok := Zone_At (Camp_Zone).Coming (Berries) = To_Pot;
               end if;
            end;
            exit when Coming_Seen and then Going_Seen and then Camp_Seen;
         end loop;
         Check (Coming_Seen and then Coming_Ok,
                "what is on its way to a stockpile shows as coming: a gatherer's basket");
         Check (Going_Seen and then Going_Ok,
                "what is set aside for someone on the way to take it shows as going: berries for the pot");
         Check (Camp_Seen and then Camp_Ok, "and what the cook is bringing shows as coming to the camp");
      end;
      Hours := 16.0 * 24.0 + 23.5;
      Run (1_800);
      declare
         Inside : Natural := 0;
         V : constant Zone_View := Zone_At (Camp_Zone);
      begin
         for I in 1 .. Members loop
            if Where (I).X in V.Lo.X .. V.Hi.X and then Where (I).Y in V.Lo.Y .. V.Hi.Y then
               Inside := Inside + 1;
               Ok := Ok and then Person (I).Zone = Camp_Zone;
            end if;
         end loop;
         Check (V.People = Inside and then Inside >= 4 and then Ok,
                "and who is inside its borders: at night" & V.People'Image & " of the band are in the camp");
      end;
   end;

   Put_Line ("who directs whom:");
   Set_Up (With_Needs => True);
   Hours := 16.0 * 24.0 + 7.0;
   declare
      Ok : Boolean;
   begin
      Check ((for all I in 1 .. Members => Director_Of (I) = No_One and then Person (I).Director = No_One),
             "the band arrives with nobody directing anyone");
      Set_Job (2, Gatherer);
      Set_Job (3, Forester, By => 2);
      Check (Director_Of (2) = The_Player and then Director_Of (3) = 2 and then Person (3).Director = 2
             and then Person (2).Job = Gatherer,
             "whoever gives a job is recorded as its director (the player; another member)");
      Set_Job (2, Unassigned);
      Check (Director_Of (2) = No_One, "unassigned again, nobody directs it");
      Set_Job (2, Gatherer);
      Zone_Camp ((30.0, 24.0, Ground_M), Ok);
      Run (90);
      declare
         Data : constant Bytes := Save;
         Before : constant Natural := Zone_Count;
      begin
         Load (Data, Ok);
         Check (Ok and then Save = Data and then Zone_Count = Before and then Camp_Zone = 2 and then Zones_Sound
                and then Director_Of (2) = The_Player and then Director_Of (3) = 2 and then Director_Of (1) = No_One,
                "zones and directors are saved: a load gives them back, and saved again it is the same"
                & Data'Length'Image & " bytes");
      end;
   end;

   Put_Line ("a larger band:");
   Reset;
   Set_Beds (False);
   Set_Labour (False);
   Set_Needs (False);
   Set_Skills (False);
   Set_Demand_Chain (False);
   Meadow;
   Place_Stake (Stake_P, 16, 42);
   declare
      Names : Boolean := True;
   begin
      for I in 2 .. Members loop
         for J in 1 .. I - 1 loop
            Names := Names and then Name_Of (I) /= Name_Of (J);
         end loop;
      end loop;
      Check (Members = 16 and then Names, "sixteen arrive, and each still has a name of their own");
   end;

   Put_Line ("views: a person, a zone and a deer as sheets of data:");
   Set_Up (With_Needs => True);
   Hours := 16.0 * 24.0 + 7.0;
   declare
      use Castle.Views;
      Ok : Boolean;
      Placed : Natural;
      S : Sheet;
      Chose : Natural := 0;
   begin
      Zone_Camp ((30.0, 24.0, Ground_M), Ok);
      Supply (Berries, 60, Placed);
      Set_Job (2, Gatherer);
      Run (30);
      S := Castle.Views.Person (2);
      Check (Str (S.Title) = Name_Of (2) and then Value_Of (S, "Job") = "Gatherer"
             and then Value_Of (S, "Directed by") = "you" and then Value_Of (S, "Doing") = Status (2)
             and then Row_Named (S, "Carrying") > 0,
             "a person's sheet: " & Str (S.Title) & ", " & Str (S.Note) & "; a gatherer, directed by you, "
             & Value_Of (S, "Doing"));
      Check (Row_Named (S, "Mood") > 0 and then Row_Named (S, "Fed") > 0
             and then Row_Named (Known_Only (S), "Mood") = 0 and then Row_Named (Known_Only (S), "Fed") = 0
             and then Value_Of (Known_Only (S), "Doing") = Status (2),
             "the development view has its mood and its belly; what the player's character could know has not");
      for I in 1 .. Members loop
         if Job_Of (I) = Cook then
            Chose := I;
         end if;
      end loop;
      Check (Chose > 0 and then Value_Of (Castle.Views.Person (Chose), "Directed by") = "no one: its own choice"
             and then Value_Of (Castle.Views.Person (6), "Job") = "No job"
             and then Value_Of (Castle.Views.Person (6), "Directed by") = "no one",
             "the cook who chose itself is nobody's to direct, and says so; nor is someone with no job");
      S := Castle.Views.Zone (1);
      Check (Str (S.Title) = "Stockpile" and then Str (S.Note) = "zone 1: 4 x 2 m"
             and then Value_Of (S, "Cells") = "8, 1 in use"
             and then Value_Of (S, "Berries") = Img (Stored (Berries)) and then Row_Named (S, "Wood") = 0,
             "a stockpile's sheet: " & Str (S.Note) & ", its cells, " & Value_Of (S, "Berries")
             & " berries, and no line for what it has none of");
      S := Castle.Views.Zone (Camp_Zone);
      Check (Str (S.Title) = "The camp" and then Row_Named (S, "Fire") > 0 and then Row_Named (S, "Pot") > 0
             and then Value_Of (S, "Seats") = "0 of 4 laid",
             "the camp's sheet: fire " & Value_Of (S, "Fire") & ", pot " & Value_Of (S, "Pot"));
      Ok := False;
      for K in 1 .. Castle.Herds.Deer_Slots loop
         if Castle.Herds.Alive (K) and then not Ok then
            S := Castle.Views.Deer (K);
            Ok := Value_Of (S, "Herd") = Img (Castle.Herds.In_Herd (Castle.Herds.Herd_Of (K))) & " deer"
              and then Value_Of (S, "Mood") = "calm" and then Known_Only (S).N = S.N;
            Put_Line ("    a deer's: " & Str (S.Title) & ", herd of " & Value_Of (S, "Herd") & ", "
                      & Value_Of (S, "Mood") & ", " & Value_Of (S, "Doing"));
         end if;
      end loop;
      Check (Ok, "a deer's sheet: its class, its herd's size, calm or alarmed; all of it there to be seen");
   end;

   Put_Line ("the action table:");
   Reset;
   Set_Beds (False);
   Set_Labour (False);
   Set_Needs (False);
   Set_Skills (False);
   Set_Demand_Chain (False);
   Meadow;
   for S of Spots loop
      Put_Bush (S.X, S.Y);
   end loop;
   declare
      use Castle.Actions;
      R : Result;
      M : Menu;
      Ground_T : constant Target := (Kind => The_Ground, Index => 0, Point => (30.0, 24.0, Ground_M));
   begin
      Check ((for all A in Action => May (The_Player, A) and then not May (3, A) and then not May (No_One, A)),
             "the player may do every action in the table; a serf, for now, none; nobody, none");
      Set_Arrivals (6, 42);
      M := Menu_For (The_Player, Ground_T);
      Check (M.N = 1 and then M.Items (1).Todo.What = Raise_Stake,
             "before the stake, all there is to do with the ground is raise it");
      Perform ((What => Lay_Path, By => The_Player, From => (20.5, 17.5, Ground_M), To => (40.0, 17.5, Ground_M)), R);
      Check (not R.Done and then R.Why = Not_Now, "no path before the stake: refused, not now");
      Perform ((What => Raise_Stake, By => 2, Stake_At => Stake_P), R);
      Check (not R.Done and then R.Why = Not_Permitted and then not Has_Stake,
             "a serf may not raise the stake: refused, "
             & Why_Not ((What => Raise_Stake, By => 2, Stake_At => Stake_P), R));
      Perform ((What => Raise_Stake, By => The_Player, Stake_At => Stake_P), R);
      Check (R.Done and then Has_Stake and then Members = 6, "the player raises it, and the band of six arrives");
      Perform ((What => Raise_Stake, By => The_Player, Stake_At => (30.0, 30.0, Ground_M)), R);
      Check (not R.Done and then R.Why = Not_Now and then Members = 6, "once only");
      Perform ((What => Lay_Path, By => The_Player, From => (20.5, 17.5, Ground_M), To => (40.0, 17.5, Ground_M)), R);
      Check (R.Done and then R.Count > 200, "a path laid by order:" & R.Count'Image & " blocks");
      Perform ((What => Zone_Stockpile, By => The_Player, X0 => 2.0, Y0 => 50.0, X1 => 6.0, Y1 => 54.0), R);
      Check (not R.Done and then R.Why = The_Ground_Refused and then Zone_Count = 0,
             "a stockpile away from the path is refused by the ground");
      Perform ((What => Zone_Stockpile, By => 4, X0 => 21.0, Y0 => 15.0, X1 => 25.0, Y1 => 17.0), R);
      Check (not R.Done and then R.Why = Not_Permitted and then Cell_Count = 0, "and a serf may not zone one");
      Perform ((What => Zone_Stockpile, By => The_Player, X0 => 21.0, Y0 => 15.0, X1 => 25.0, Y1 => 17.0), R);
      Check (R.Done and then R.Count = 8 and then Zone_Count = 1, "the player zones it: 8 cells, one zone");
      Perform ((What => Give_Job, By => 3, Whom => 2, Job => Gatherer), R);
      Check (not R.Done and then R.Why = Not_Permitted and then Job_Of (2) = Unassigned,
             "a serf may not give another a job (delegation waits for those who direct helpers)");
      Perform ((What => Give_Job, By => The_Player, Whom => 2, Job => Gatherer), R);
      Check (R.Done and then Job_Of (2) = Gatherer and then Director_Of (2) = The_Player,
             "the player gives one, and is its director");
      Perform ((What => Give_Job, By => The_Player, Whom => 40, Job => Gatherer), R);
      Check (not R.Done and then R.Why = No_Such_Target, "a job for nobody is refused");
      Perform ((What => Set_Reserve, By => The_Player, Kind => Berries, Amount => 50), R);
      Check (not R.Done and then R.Why = No_Such_Target, "there is no reserve of berries to set");
      Perform ((What => Set_Reserve, By => The_Player, Kind => Meat, Amount => 60), R);
      Ok_All := R.Done and then Reserve_Of (Meat) = 60;
      Perform ((What => Set_Reserve, By => The_Player, Kind => Wood, Amount => 30), R);
      Ok_All := Ok_All and then R.Done and then Wood_Reserve = 30;
      Perform ((What => Set_Winter_Store, By => The_Player, Days => 5), R);
      Ok_All := Ok_All and then R.Done and then Winter_Store = 5;
      Perform ((What => Castle.Actions.Spare_Deer, By => The_Player, On => True), R);
      Ok_All := Ok_All and then R.Done and then Castle.Colony.Spare_Deer;
      Perform ((What => Spare_Apples, By => The_Player, On => False), R);
      Ok_All := Ok_All and then R.Done and then not Protect_Apples;
      Check (Ok_All, "the reserves, the winter store and the protections are set by order");
      declare
         Before : constant Bytes := Save;
      begin
         Perform ((What => Follow, By => The_Player, Whom => 2, Job => Unassigned), R);
         Check (R.Done and then Save = Before, "following someone is permitted, and changes nothing in the colony");
         Perform ((What => Follow, By => 5, Whom => 2, Job => Unassigned), R);
         Check (not R.Done and then R.Why = Not_Permitted, "but not for a serf");
      end;
      M := Menu_For (The_Player, (Kind => A_Person, Index => 2, Point => (0.0, 0.0, 0.0)));
      Check (M.N = 7 and then Str (M.Title) = Name_Of (2)
             and then (for all K in 1 .. 6 => M.Items (K).Todo.What = Give_Job
                                              and then M.Items (K).Is_Now = (M.Items (K).Todo.Job = Gatherer))
             and then M.Items (7).Todo.What = Follow,
             "a person's menu: a job for each there is, its own marked, and follow");
      Check (Menu_For (3, (Kind => A_Person, Index => 2, Point => (0.0, 0.0, 0.0))).N = 0,
             "for a serf the same person's menu is empty");
      M := Menu_For (The_Player, Ground_T);
      Check (M.N = 5 and then M.Items (1).Todo.What = Lay_Path and then M.Items (1).Two_Point
             and then M.Items (2).Todo.What = Zone_Stockpile and then M.Items (2).Two_Point
             and then M.Items (3).Todo.What = Zone_Camp and then not M.Items (3).Two_Point
             and then M.Items (4).Todo.What = Zone_Housing and then M.Items (4).Two_Point
             and then M.Items (5).Todo.What = Fill_Housing and then not M.Items (5).Two_Point,
             "the ground's menu now: a path, a stockpile or housing from here (each wants a second point), the camp here,"
             & " housing inside these paths");
      Perform (M.Items (3).Todo, R);
      Check (R.Done and then Has_Camp and then Menu_For (The_Player, Ground_T).N = 4,
             "the camp zoned from the menu; after that the ground offers no second one");
      M := Menu_For (The_Player, (Kind => A_Stockpile, Index => 1, Point => (0.0, 0.0, 0.0)));
      Check (M.N = 10 and then (for all K in 1 .. 5 => M.Items (2 * K - 1).Step = Fewer
                                                        and then M.Items (2 * K).Step = More),
             "a stockpile's menu: a step down and up for each reserve (wood, straw, meat, vegetables) and the"
             & " winter store");
      for K in 1 .. M.N loop
         if M.Items (K).Todo.What = Set_Reserve and then M.Items (K).Todo.Kind = Meat
           and then M.Items (K).Step = More
         then
            Perform (M.Items (K).Todo, R);
         end if;
      end loop;
      Check (Reserve_Of (Meat) = 60 + Reserve_Step, "a step up from the menu raises the meat reserve by ten");
      Check (Menu_For (The_Player, (Kind => The_Camp, Index => Camp_Zone, Point => (0.0, 0.0, 0.0))).N = 0
             and then Menu_For (The_Player, (Kind => A_Deer, Index => 1, Point => (0.0, 0.0, 0.0))).N = 0,
             "nothing to do to the camp or to a deer yet");
   end;

   --  tools/colony_v10.bin: this meadow (Set_Up with needs), two more
   --  stockpiles zoned touching each other (30 15 33 17, then 33 15 35 17),
   --  the camp at 30 24, 8 meat, 60 berries and 3 logs supplied, a cook, two
   --  gatherers and a forester; saved 127 s after seven on day 16 with one
   --  gatherer carrying 30 berries to the stockpile.  Written by the
   --  version 10 code (commit 892a63a).
   Put_Line ("a save from before zones (version 10):");
   Set_Up (With_Needs => True);
   declare
      package SIO renames Ada.Streams.Stream_IO;
      F  : SIO.File_Type;
      Ok : Boolean;
   begin
      SIO.Open (F, SIO.In_File, "tools/colony_v10.bin");
      declare
         Data : Bytes (0 .. Natural (SIO.Size (F)) - 1);
      begin
         Bytes'Read (SIO.Stream (F), Data);
         SIO.Close (F);
         Load (Data, Ok);
         Check (Ok and then Members = 6 and then Has_Camp and then Cell_Count = 18,
                "it loads: six in the band, a camp, 18 stockpile cells");
         Check (Zone_Count = 3 and then Zone_At (1).Cells = 8 and then Zone_At (2).Cells = 10
                and then Zone_At (2).Lo.X = 30.0 and then Zone_At (2).Hi.X = 35.0
                and then Camp_Zone = 3 and then Zones_Sound,
                "its cells become a zone for each group that touches (8, and the two zonings side by side as"
                & " one of 10), and the camp a third");
         Check (Director_Of (1) = The_Player and then Director_Of (2) = The_Player and then Director_Of (4) = The_Player
                and then Director_Of (5) = No_One and then Director_Of (6) = No_One,
                "everyone with a job is the player's to direct, the unassigned nobody's");
         Check (Status (2) = "taking 30 berries to the stockpile"
                and then Zone_At (1).Coming (Berries) + Zone_At (2).Coming (Berries) = 30,
                "the gatherer is still on its way with its basket, and the zone it is going to expects it");
         Hours := 16.0 * 24.0 + 7.0 + 127.0 / 60.0;
         Run (120);
         declare
            Again : constant Bytes := Save;
            Ok2 : Boolean;
         begin
            Load (Again, Ok2);
            Check (Ok2 and then Save = Again and then Zone_Count = 3 and then Zones_Sound,
                   "two minutes on it saves as version 11 and loads back the same");
         end;
      end;
   end;

   ------------------------------------------------------------------ 17. skills
   Put_Line ("skills: what people arrive with:");
   Set_Up (With_Skills => True);
   declare
      type Table is array (1 .. 6, Skill_Kind) of Float;
      Lv, Ap : Table;
      In_Range, Trades, Apt_Range : Boolean := True;
      Sum : Float := 0.0;
   begin
      for I in 1 .. 6 loop
         for S in Skill_Kind loop
            Lv (I, S) := Skill_Of (I, S);
            Ap (I, S) := Aptitude_Of (I, S);
            Apt_Range := Apt_Range and then Ap (I, S) in Aptitude_Lo .. Aptitude_Hi;
            if S in Working_Skill then
               --  member 5 is the band's elder
               In_Range := In_Range and then Lv (I, S) >= Start_Lo + (if I = 5 then Elder_Start else 0.0) - 1.0E-6
                 and then Lv (I, S) <= Start_Hi + (if I = 5 then Elder_Start else 0.0) + 1.0E-6;
               Sum := Sum + Lv (I, S);
            else
               Trades := Trades and then Lv (I, S) in 0.0 .. Trade_Start;
            end if;
         end loop;
      end loop;
      Check (Skills and then In_Range and then Trades,
             "each arrives with 15 to 50 % in the five working skills (the elder 20 points more) and next to"
             & " nothing in the trades; the band's mean is " & Img (100.0 * Sum / 30.0, 0) & " %");
      Check (Apt_Range, "and an aptitude for each skill, from half to one and a half");
      Check ((for all I in 1 .. 6 => Aptitude_Of (I, Cooking) = Aptitude_Lo + Cooking_Of (I)),
             "its aptitude for cooking is the number that made a good cook before there were skills");
      Check (Job_Skill (Gatherer) = Gathering and then Job_Skill (Forester) = Forestry
             and then Job_Skill (Hunter) = Hunting and then Job_Skill (Porter) = Portering
             and then Job_Skill (Cook) = Cooking and then not Has_Skill (Unassigned),
             "every job but none has a skill of its own");
      Set_Up (With_Skills => True);
      Check ((for all I in 1 .. 6 => (for all S in Skill_Kind => Skill_Of (I, S) = Lv (I, S)
                                                                    and then Aptitude_Of (I, S) = Ap (I, S))),
             "the same band arrives the same: levels and aptitudes come from each one's seed");
   end;

   Put_Line ("skills: the pace of work:");
   Set_Up (With_Skills => True);
   declare
      Picked, Seconds : array (2 .. 3) of Natural := [others => 0];
      Before : array (2 .. 3) of Natural := [others => 0];
      Was_Picking : array (2 .. 3) of Boolean := [others => False];
   begin
      Set_Skill (2, Gathering, 0.0);
      Set_Skill (3, Gathering, 1.0);
      Set_Skill (4, Gathering, 1.0 / 3.0);
      Check (abs (Work_Rate_Of (2, Picking) - Novice_Rate) < 1.0E-6
             and then abs (Work_Rate_Of (3, Picking) - Master_Rate) < 1.0E-6
             and then abs (Work_Rate_Of (4, Picking) - 1.0) < 1.0E-6,
             "picking goes at three quarters of the old pace with no skill, half as fast again at mastery, and at"
             & " the old pace a third of the way there");
      Check (Work_Rate_Of (2, Handling) = 1.0 and then Work_Rate_Of (3, Handling) = 1.0
             and then Direction_Of (2) = 1.0 and then Direction_Of (3) = 1.0,
             "carrying and putting down have no skill in them; and nobody's work is yet the faster for being directed");
      Check (abs (Work_Rate_Of (3, Felling) - (Novice_Rate + (Master_Rate - Novice_Rate) * Skill_Of (3, Forestry)))
             < 1.0E-6,
             "each work goes by its own skill: the master gatherer fells as well as its forestry lets it");
      Set_Job (2, Gatherer);
      Set_Job (3, Gatherer);
      for S in 1 .. 240 loop
         Run (1);
         for I in 2 .. 3 loop
            if Doing (I) = Picking and then Was_Picking (I) then
               Seconds (I) := Seconds (I) + 1;
               if Carried (I) > Before (I) then
                  Picked (I) := Picked (I) + Carried (I) - Before (I);
               end if;
            end if;
            Was_Picking (I) := Doing (I) = Picking;
            Before (I) := Carried (I);
         end loop;
      end loop;
      declare
         Slow : constant Float := Float (Picked (2)) / Float (Integer'Max (1, Seconds (2)));
         Fast : constant Float := Float (Picked (3)) / Float (Integer'Max (1, Seconds (3)));
      begin
         Put_Line ("    handfuls a second of picking: the novice " & Img (Slow, 2) & ", the master " & Img (Fast, 2));
         Check (Seconds (2) > 30 and then Seconds (3) > 30 and then Fast / Slow in 1.85 .. 2.15,
                "the master picks twice as fast as the novice (" & Img (Fast / Slow, 2) & " times)");
      end;
      Set_Skills (False);
      Check (Work_Rate_Of (2, Picking) = 1.0 and then Work_Rate_Of (3, Picking) = 1.0,
             "with skills off both pick at the one pace");
   end;

   Put_Line ("skills: learning by doing:");
   Set_Up (With_Skills => True);
   declare
      G0, F0, C0, Fo0 : Float;
      Hours_On : Float := 0.0;
      type Levels is array (Skill_Kind) of Float;
      Idle_0 : Levels;
   begin
      Set_Skill (2, Gathering, 0.5);
      Set_Skill (2, Farming, 0.5);
      Set_Skill (2, Cooking, 0.5);
      G0 := Skill_Of (2, Gathering);
      F0 := Skill_Of (2, Farming);
      C0 := Skill_Of (2, Cooking);
      Fo0 := Skill_Of (2, Forestry);
      for S in Skill_Kind loop
         Idle_0 (S) := Skill_Of (5, S);
      end loop;
      Set_Job (2, Gatherer);
      for S in 1 .. 600 loop
         if Work_Of (2) = Picking then
            Hours_On := Hours_On + 1.0 / 60.0;
         end if;
         Run (1);
      end loop;
      declare
         DG : constant Float := Skill_Of (2, Gathering) - G0;
         DF : constant Float := Skill_Of (2, Farming) - F0;
         DC : constant Float := Skill_Of (2, Cooking) - C0;
         Expect : constant Float :=
           (1.0 - G0) * (1.0 - Exp (-Aptitude_Of (2, Gathering) * Hours_On / Learn_Hours));
      begin
         Put_Line ("    ten hours a gatherer, " & Img (Hours_On, 1) & " of them on the job: gathering up "
                   & Img (100.0 * DG, 2) & " points, farming " & Img (100.0 * DF, 2) & ", cooking " & Img (100.0 * DC, 2));
         Check (DG > 0.0 and then abs (DG - Expect) < 0.02 * Expect,
                "its gathering rises as the rule says: the gap to mastery closing by its aptitude over"
                & " Learn_Hours (" & Img (100.0 * Expect, 2) & " points expected)");
         Check (abs (DF / DG - 0.2 * Aptitude_Of (2, Farming) / Aptitude_Of (2, Gathering)) < 0.002
                and then abs (DC / DG - 0.1 * Aptitude_Of (2, Cooking) / Aptitude_Of (2, Gathering)) < 0.002,
                "farming and cooking rise alongside, by a fifth and a tenth, each by its own aptitude");
         Check (Skill_Of (2, Forestry) = Fo0, "what picking does not teach does not move: its forestry is what it was");
         Check ((for all S in Skill_Kind => Skill_Of (5, S) = Idle_0 (S)),
                "someone with no job, waiting at the stake, learns nothing");
      end;
   end;

   Put_Line ("skills: nothing learnt asleep; the work done, not the job held:");
   Set_Up (With_Needs => True, With_Skills => True, With_Field => True, With_Trees => True);
   declare
      Ok : Boolean;
      Asleep_At, Awake_At : Float := 0.0;
      Slept, Idle_Asleep : Boolean := False;
      DG, DC : Float := 0.0;           --  what the cook gained in the seconds it was out picking
      Said : Boolean := False;
   begin
      Zone_Camp ((30.0, 24.0, Ground_M), Ok);
      Set_Job (1, Cook);
      Set_Job (2, Gatherer);
      Hours := 16.0 * 24.0 + 9.0;
      for S in 1 .. 400 loop
         declare
            G : constant Float := Skill_Of (1, Gathering);
            C : constant Float := Skill_Of (1, Cooking);
            Was : constant Boolean := Work_Of (1) = Picking;
         begin
            Run (1);
            if Was and then Work_Of (1) = Picking then
               DG := DG + (Skill_Of (1, Gathering) - G);
               DC := DC + (Skill_Of (1, Cooking) - C);
               Said := Said or else (Status (1)'Length > 16 and then Status (1) (1 .. 16) = "nothing to cook:");
            end if;
         end;
      end loop;
      --  (each closes on mastery from where it stands: the further off, the faster)
      Check (Said and then DG > 0.0
             and then abs (DC / DG - 0.1 * Aptitude_Of (1, Cooking) * (1.0 - Skill_Of (1, Cooking))
                                     / (Aptitude_Of (1, Gathering) * (1.0 - Skill_Of (1, Gathering)))) < 0.002,
             "a cook with nothing to cook goes gathering, and it is gathering it learns then (" & Img (1.0E4 * DG, 1)
             & " against " & Img (1.0E4 * DC, 1) & " of cooking, in hundredths of a point)");
      Hours := 16.0 * 24.0 + 23.0;
      for S in 1 .. 300 loop
         Run (1);
         if Asleep (2) and then not Slept then
            Slept := True;
            Asleep_At := Skill_Of (2, Gathering);
            Idle_Asleep := Work_Of (2) = Handling;
         elsif Slept and then Asleep (2) then
            Awake_At := Skill_Of (2, Gathering);
         end if;
      end loop;
      Check (Slept and then Idle_Asleep and then Awake_At = Asleep_At,
             "a gatherer asleep learns nothing through the night");
   end;

   Put_Line ("skills: the shot and the pot:");
   Set_Up (With_Needs => True, With_Trees => True, With_Skills => True);
   Hours := 16.0 * 24.0 + 7.0;
   declare
      Ok : Boolean;
      Placed : Natural;
      Stirred : Natural := 0;
      Expect : Natural;
   begin
      Set_Skill (4, Hunting, 0.0);
      Ok := abs (Hit_Chance_Of (4, 10.0) - Novice_Aim * Hit_Chance (10.0)) < 1.0E-6;
      Set_Skill (4, Hunting, 1.0 / 3.0);
      Ok := Ok and then abs (Hit_Chance_Of (4, 10.0) - Hit_Chance (10.0)) < 1.0E-6;
      Set_Skill (4, Hunting, 1.0);
      Ok := Ok and then abs (Hit_Chance_Of (4, 16.0) - Master_Aim * Hit_Chance (16.0)) < 1.0E-6
        and then Hit_Chance_Of (4, 2.0) = Best_Aim;
      Check (Ok, "a hunter's chance to hit runs from 0.8 of the old one with no skill to 1.4 at mastery, never over"
             & " 95 %, and is the old one a third of the way");
      Set_Skill (1, Cooking, 0.0);
      Ok := abs (Pot_Yield_Of (1) - Novice_Pot) < 1.0E-6;
      Set_Skill (1, Cooking, 1.0);
      Ok := Ok and then abs (Pot_Yield_Of (1) - Master_Pot) < 1.0E-6;
      Check (Ok, "a cook's pot holds from 0.9 to 1.2 of what went into it");
      Zone_Camp ((30.0, 24.0, Ground_M), Ok);
      Supply (Meat, 12, Placed);
      Supply (Berries, 60, Placed);
      Supply (Wood, 3, Placed);
      Set_Job (1, Cook);
      for S in 1 .. 900 loop
         Run (1);
         if Camp_State.Stirring then
            Stirred := Stirred + 1;
         end if;
         exit when Camp_State.Stew > 0;
      end loop;
      Expect := Natural (Float'Floor (Float (Put_In_Pot (Meat) * Stew_Food (Meat) + Put_In_Pot (Berries) * Stew_Food (Berries))
                                      * Balanced_Bonus * Master_Pot + 0.5));
      Check (Cooked = Expect and then Cooked > 0,
             "a master cook's pot of meat and berries holds a fifth more than went in, on top of the bonus ("
             & Img (Cooked) & ")");
      Check (Stirred in 38 .. 42,
             "and is stirred in two thirds of the hour (" & Img (Stirred) & " game minutes)");
      Set_Skills (False);
      Check (Pot_Yield_Of (1) = 0.9 + 0.2 * Cooking_Of (1) and then Hit_Chance_Of (4, 10.0) = Hit_Chance (10.0),
             "with skills off the pot and the shot are exactly what they were");
   end;

   Put_Line ("skills: the first cook, by aptitude:");
   Set_Up (With_Needs => True, With_Trees => True, With_Skills => True);
   Hours := 16.0 * 24.0 + 7.0;
   declare
      Ok : Boolean;
      Placed : Natural;
      Best : Positive := 1;
   begin
      for I in 2 .. Members loop
         if Aptitude_Of (I, Cooking) > Aptitude_Of (Best, Cooking) then
            Best := I;
         end if;
      end loop;
      Zone_Camp ((30.0, 24.0, Ground_M), Ok);
      Supply (Meat, 4, Placed);
      Run (5);
      Check (Job_Of (Best) = Cook and then Director_Of (Best) = No_One,
             "whoever has the best aptitude for cooking takes it up (" & Name_Of (Best) & ", x"
             & Img (Aptitude_Of (Best, Cooking), 2) & "): the same one as before there were skills");
   end;

   Put_Line ("skills: sheets and menus:");
   Set_Up (With_Needs => True, With_Skills => True);
   declare
      use Castle.Views;
      Ok : Boolean;
      S  : Sheet;
      M  : Castle.Actions.Menu;
      Full : Natural := 0;
   begin
      Zone_Camp ((30.0, 24.0, Ground_M), Ok);
      Set_Job (3, Forester);
      S := Castle.Views.Person (3);
      Check (Row_Named (S, "Forestry") > 0
             and then S.Rows (Row_Named (S, "Forestry")).Bar = Skill_Of (3, Forestry)
             and then S.Rows (Row_Named (S, "Forestry")).Known
             and then Value_Of (S, "Forestry") = Img (Integer (100.0 * Skill_Of (3, Forestry))) & " %, "
                                                  & Learns_Text (Aptitude_Of (3, Forestry))
             and then Row_Named (S, "Apt at") > 0,
             "a forester's sheet has its forestry: " & Value_Of (S, "Forestry") & "; other skills: "
             & Value_Of (S, "Other skills") & "; apt at: " & Value_Of (S, "Apt at"));
      Check (Row_Named (Known_Only (S), "Forestry") > 0 and then Row_Named (Known_Only (S), "Apt at") > 0,
             "skills and aptitudes are for the player's character to know");
      S := Castle.Views.Person (6);
      Check (Row_Named (S, "Skills") > 0 and then Row_Named (S, "Other skills") = 0,
             "someone with no job shows its best skills: " & Value_Of (S, "Skills"));
      for I in 1 .. Members loop
         S := Castle.Views.Person (I);
         Full := Natural'Max (Full, S.N);
         Ok := Ok and then S.Lost = 0;
      end loop;
      Check (Ok and then Full < Max_Rows - 3,
             "no sheet runs out of rows (the fullest has " & Img (Full) & " of " & Img (Integer'(Max_Rows)) & ")");
      M := Castle.Actions.Menu_For (The_Player, (Kind => Castle.Actions.A_Person, Index => 3, Point => (0.0, 0.0, 0.0)));
      Check (M.N = 7 and then Str (M.Items (1).Label) = "No job"
             and then Str (M.Items (3).Label) = "Forester: " & Img (Integer (100.0 * Skill_Of (3, Forestry))) & " %, x"
                                                 & Img (Aptitude_Of (3, Forestry), 1),
             "a person's menu shows its level and aptitude beside each job: " & Str (M.Items (3).Label));
      Set_Skills (False);
      M := Castle.Actions.Menu_For (The_Player, (Kind => Castle.Actions.A_Person, Index => 3, Point => (0.0, 0.0, 0.0)));
      Check (Str (M.Items (3).Label) = "Forester" and then Row_Named (Castle.Views.Person (3), "Forestry") = 0,
             "with skills off neither the menu nor the sheet speaks of them");
   end;

   Put_Line ("skills: saves:");
   Set_Up (With_Needs => True, With_Trees => True, With_Skills => True);
   Hours := 16.0 * 24.0 + 7.0;
   declare
      Ok : Boolean;
      Placed : Natural;
      Snap : Snapshot;
   begin
      Zone_Camp ((30.0, 24.0, Ground_M), Ok);
      Supply (Meat, 8, Placed);
      Supply (Berries, 60, Placed);
      Supply (Wood, 3, Placed);
      Set_Job (1, Cook);
      Set_Job (2, Gatherer);
      Set_Job (3, Forester);
      Run (200);
      declare
         Saved_Hours : constant Long_Float := Hours;
         Data : constant Bytes := Save;
         type Levels is array (1 .. 6, Skill_Kind) of Float;
         A, B : Levels;
      begin
         Take (Snap);
         Run (400);
         for I in 1 .. 6 loop
            for S in Skill_Kind loop
               A (I, S) := Skill_Of (I, S);
            end loop;
         end loop;
         Give_Back (Snap);
         Hours := Saved_Hours;
         Load (Data, Ok);
         Check (Ok and then Save = Data and then Skills,
                "a save taken mid-work loads with its skills, and saved again is the same" & Data'Length'Image
                & " bytes");
         Run (400);
         for I in 1 .. 6 loop
            for S in Skill_Kind loop
               B (I, S) := Skill_Of (I, S);
            end loop;
         end loop;
         Check (A = B and then A (2, Gathering) > Float (Start_Lo),
                "and 400 s later everyone's levels are just what they would have been");
         --  the same blob as if written before the trade skills, and as if after one more was added
         declare
            N_Now  : constant Natural := Skill_Kind'Pos (Skill_Kind'Last) + 1;
            Tail   : constant Natural := 2 + 6 * N_Now * 8;       --  the skills' section
            function Ground_Bytes return Natural is                 --  the zones' ground: a turn, a count, its strips
               N : Natural := 0;
            begin
               for Z in 1 .. Zone_Count loop
                  N := N + 8 + 8 * Zone_Runs (Z);
               end loop;
               return N;
            end Ground_Bytes;
            --  what follows it: the demand chain's, the zones' ground, the camp's labour and its fire's
            --  dying down, what is built on each zone, each member's patch; how far the band is
            --  looking, each member's metre of path; how many hands extra tasks may take, whether
            --  paths are laid by the stretch, the metres each member has laid of its own; whether a
            --  camp's floor is levelled and this one's level, what is asked and kept of earth; the
            --  houses (a serial, a count, thirty-three bytes each), each member's house and patch of its ground
            After  : constant Natural :=
              3 + Item_Kind'Pos (Item_Kind'Last) + 1 + Ground_Bytes + 5
              + Zone_Count * (2 + 2 * (Item_Kind'Pos (Item_Kind'Last) + 1)) + 2 * 6
              + 8 + 3 * 6
              + 2 + 6
              + 9 + 4
              + 3 + 33 * House_Count + 3 * 6
              + 7 + 23 * 6                           --  (the band's pace; beds: a flag, the straw in them, each
                                                     --  member's own, where, what is in it, its place by the fire)
              + 2                                    --  (the lots laid out: a count and a flag, none here)
              + 1                                    --  (the pass's fourth round: whether the cook keeps a pot's fill;
              + 3 + 12 + 1 + 2 + 3 * 4               --  curing, the cart and whether one was looked for, where it stands,
                                                     --  the way it lies, its salt, what salting kept and lost;
              + 4 * (Item_Kind'Pos (Item_Kind'Last) - Item_Kind'Pos (Salt) + 1)    --  what is asked and kept of salt and ladders;
              + 5 + 14 * House_Count + 6             --  ladders: the switch, those made and lost, each house's, each member's)
              + 1                                    --  (the fifth round: whether a hole under a path is filled)
              + 1 + 4 + 1 + 1 + 1 + 12 + 4 + 12;     --  (the cart pulled into a stockpile: the switch, its turn, in tow,
                                                     --  by whom, a place held, where and which way, where it was lifted from)
            Skills_At : constant Natural := Data'Last - After - Tail + 1;
            Head   : constant Bytes := Data (Data'First .. Skills_At - 1);
            Flag   : constant Interfaces.Unsigned_8 := Data (Skills_At);
            function With_Count (N : Natural) return Bytes is
               Out_B : Bytes (0 .. Head'Length + 2 + 6 * N * 8 + After - 1) := [others => 0];
               At_B  : Natural := Head'Length;
            begin
               Out_B (0 .. Head'Length - 1) := Head;
               Out_B (At_B) := Flag;
               Out_B (At_B + 1) := Interfaces.Unsigned_8 (N);
               At_B := At_B + 2;
               for I in 0 .. 5 loop
                  for K in 0 .. N - 1 loop
                     if K < N_Now then
                        Out_B (At_B .. At_B + 7) :=
                          Data (Skills_At + 2 + (I * N_Now + K) * 8 .. Skills_At + 9 + (I * N_Now + K) * 8);
                     end if;                         --  (a skill this build does not know: zeroes, skipped on load)
                     At_B := At_B + 8;
                  end loop;
               end loop;
               Out_B (At_B .. At_B + After - 1) := Data (Data'Last - After + 1 .. Data'Last);
               return Out_B;
            end With_Count;
            Fewer : constant Bytes := With_Count (5);
            More  : constant Bytes := With_Count (N_Now + 1);
            G2 : constant Float := Skill_Of (2, Gathering);
         begin
            Load (Data, Ok);
            declare
               G_Saved : constant Float := Skill_Of (2, Gathering);
               B_Start : Float;
            begin
               Set_Up (With_Needs => True, With_Trees => True, With_Skills => True);
               B_Start := Skill_Of (2, Building);          --  what member 2 arrives with
               Load (Fewer, Ok);
               Check (Ok and then Skill_Of (2, Gathering) = G_Saved and then Skill_Of (2, Building) = B_Start,
                      "a blob holding only the five working skills loads: those as saved, the rest as it arrived");
               Load (More, Ok);
               Check (Ok and then Skill_Of (2, Gathering) = G_Saved,
                      "and one holding a skill this build does not know loads too, that skill let go");
            end;
            pragma Unreferenced (G2);
         end;
      end;
      Set_Up (With_Skills => True);
      Set_Skills (False);
      declare
         Data : constant Bytes := Save;
      begin
         Set_Skills (True);
         Load (Data, Ok);
         Check (Ok and then not Skills, "the switch is saved: a colony with skills off loads with them off");
      end;
   end;

   --  tools/colony_v11.bin: this meadow (Set_Up with needs and trees), the
   --  camp at 30 24, 8 meat, 60 berries and 3 logs supplied, a cook, a
   --  gatherer, a forester and a hunter; saved 61 s after seven on day 16
   --  with the forester felling its second tree.  Written by the version 11
   --  code (commit fb67a08).
   Put_Line ("a save from before skills (version 11):");
   Set_Up (With_Needs => True, With_Trees => True, With_Skills => True);
   declare
      package SIO renames Ada.Streams.Stream_IO;
      F  : SIO.File_Type;
      Ok : Boolean;
      type Levels is array (1 .. 6, Skill_Kind) of Float;
      Arrived : Levels;
   begin
      for I in 1 .. 6 loop
         for S in Skill_Kind loop
            Arrived (I, S) := Skill_Of (I, S);
         end loop;
      end loop;
      Set_Skills (False);
      SIO.Open (F, SIO.In_File, "tools/colony_v11.bin");
      declare
         Data : Bytes (0 .. Natural (SIO.Size (F)) - 1);
         Felled_0 : Natural;
         F0 : Float;
      begin
         Bytes'Read (SIO.Stream (F), Data);
         SIO.Close (F);
         Load (Data, Ok);
         Check (Ok and then Members = 6 and then Has_Camp and then Zone_Count = 2 and then Status (3) = "felling a tree",
                "it loads: six in the band, the camp and a stockpile as zones, the forester mid-chop");
         Check (Skills and then (for all I in 1 .. 6 => (for all S in Skill_Kind => Skill_Of (I, S) = Arrived (I, S))),
                "with skills on, and everyone at the levels they would have arrived with");
         Felled_0 := Trees_Felled;
         F0 := Skill_Of (3, Forestry);
         Hours := 16.0 * 24.0 + 7.0 + 61.0 / 60.0;
         for S in 1 .. 120 loop
            Run (1);
            exit when Trees_Felled > Felled_0;
         end loop;
         Check (Trees_Felled = Felled_0 + 1 and then Skill_Of (3, Forestry) > F0,
                "the forester brings its tree down, the better at it for the doing");
         declare
            Again : constant Bytes := Save;
            Ok2 : Boolean;
         begin
            Load (Again, Ok2);
            Check (Ok2 and then Save = Again and then Again'Length > Data'Length,
                   "and it saves as version 12 and loads back the same");
         end;
      end;
   end;

   ------------------------------------------------------------------ the demand chain
   Put_Line ("demand: what is asked, and by whom:");
   Set_Up (With_Needs => True, With_Trees => True, With_Demand => True);
   declare
      function Has_Row (Who : Asker; Kind : Ask_Kind; Food : Boolean; What : Item_Kind; Amount : Natural)
                        return Boolean is
        (for some K in 1 .. Demand_Rows =>
           Demand_Row_At (K).Who = Who and then Demand_Row_At (K).Kind = Kind and then Demand_Row_At (K).Food = Food
           and then (Food or else Demand_Row_At (K).What = What) and then Demand_Row_At (K).Amount = Amount);
      function Weight (R : Demand_Row) return Natural is (if R.Kind = By_The_Day then 2 * R.Amount else R.Amount);
      --  every good's high level is the sum of its rows
      function Sums_Agree return Boolean is
         Sum : Natural := 0;
      begin
         for G in Item_Kind loop
            Sum := 0;
            for K in 1 .. Demand_Rows loop
               if not Demand_Row_At (K).Food and then Demand_Row_At (K).What = G then
                  Sum := Sum + Weight (Demand_Row_At (K));
               end if;
            end loop;
            if Sum /= Demand_For (G).High then
               return False;
            end if;
         end loop;
         Sum := 0;
         for K in 1 .. Demand_Rows loop
            if Demand_Row_At (K).Food then
               Sum := Sum + Weight (Demand_Row_At (K));
            end if;
         end loop;
         return Sum = Food_Demand.High;
      end Sums_Agree;
      Ok  : Boolean;
      Day : constant Natural := Food_A_Day;
   begin
      Check (Demand_Chain and then Day > 0 and then Has_Row (The_People, By_The_Day, True, Nothing, Day),
             "the band asks for its day's food:" & Day'Image & " points");
      Check (Has_Row (An_Order, Surplus, False, Wood, 20) and then Has_Row (An_Order, Surplus, False, Straw, 20)
             and then Has_Row (An_Order, Surplus, False, Meat, 20)
             and then Has_Row (An_Order, Surplus, False, Vegetables, 40)
             and then Has_Row (The_Paths, Once, False, Stone, Stone_Quota),
             "the orders ask for their surpluses (wood 20, straw 20, meat 20, vegetables 40), the paths for their stone");
      Check (Food_Demand.Low = Day and then Food_Demand.High = 2 * Day and then Food_Demand.Surplus = 0,
             "food is asked for below a day of the band's eating, and until there are two");
      Check (Demand_For (Wood).Low = 20 and then Demand_For (Wood).High = 20 and then Demand_For (Wood).A_Day = 0,
             "with no camp nothing uses wood: it is asked for while short of its surplus, 20");
      Zone_Camp ((30.0, 24.0, Ground_M), Ok);
      Check (Ok and then Has_Row (A_Zone, By_The_Day, False, Wood, 4)
             and then Has_Row (A_Zone, Once, False, Wood, Seat_Logs)
             and then (for some K in 1 .. Demand_Rows =>
                         Demand_Row_At (K).Who = A_Zone and then Demand_Row_At (K).Zone = Camp_Zone),
             "the camp asks for its fire's logs, 4 a day, and once for its seats', 4");
      Check (Demand_For (Wood).Low = 20 + 4 + 4 and then Demand_For (Wood).High = 20 + 4 + 8,
             "so wood is asked for below 28 and until there are 32");
      Set_Winter_Store (5);
      Check (Has_Row (An_Order, Surplus, True, Nothing, 5 * Day) and then Food_Demand.High = 7 * Day
             and then Food_Demand.Low = 6 * Day, "a winter store of five days is five days more food asked for");
      Check (Sums_Agree,
             "every good's high level is the sum of its rows: surpluses, what is wanted once, two days of what is used");
      declare
         use Castle.Views;
         S : constant Sheet := Demand;
         W : constant Natural := Row_Named (S, "Wood");
         Z : constant Sheet := Zone (1);
         C : constant Sheet := Zone (Camp_Zone);
      begin
         Run (1);
         Check (Value_Of (S, "Wood") = "0 of 32, asked of nobody" and then S.Rows (W).Shade = Bad
                and then Str (S.Rows (W + 1).Name) = "  asked by"
                and then Str (S.Rows (W + 1).Value) = "the camp 4 a day, 4 once; you 20" and then S.Lost = 0,
                "the table as a sheet: wood, '" & Value_Of (S, "Wood") & "'; asked by '"
                & Str (S.Rows (W + 1).Value) & "'");
         Check (Value_Of (S, "Food") = "0.0 of 7.0 days, asked of nobody"
                and then Value_Of (S, "  asked by") = "the band by the day; you 5.0 days",
                "and food, '" & Value_Of (S, "Food") & "'; asked by '" & Value_Of (S, "  asked by") & "'");
         Check (Value_Of (Z, "The stores ask for") = "food, wood, stone, straw, meat, vegetables"
                and then Value_Of (C, "Asks for") = "4 wood a day, 4 wood once",
                "a stockpile's sheet says what the stores ask for, the camp's what it asks: '"
                & Value_Of (C, "Asks for") & "'");
         Set_Job (1, Forester);
         Check (Value_Of (Demand, "Wood") = "0 of 32, asked",
                "with a forester in the band it is asked of someone: '" & Value_Of (Demand, "Wood") & "'");
         Set_Job (1, Unassigned);
      end;
      Hours := 46.0 * 24.0 + 12.0;
      Run (1);
      Check (Has_Row (A_Zone, By_The_Day, False, Wood, 6) and then Has_Row (An_Order, Surplus, True, Nothing, 5 * Day),
             "in winter the fire is kept in all day: 6 logs; and the winter store is still asked for");
      Set_Needs (False);
      Check (Food_A_Day = 0 and then Food_Demand.High = 0
             and then not (for some K in 1 .. Demand_Rows => Demand_Row_At (K).Food),
             "with nobody eating, no food is asked for");
   end;

   Put_Line ("demand: two levels (wood, a camp nobody tends, a forester):");
   Set_Up (With_Trees => True, With_Demand => True);
   declare
      Ok     : Boolean;
      Placed : Natural;
      Quiet, Asking_It : Boolean;
   begin
      Zone_Camp ((30.0, 24.0, Ground_M), Ok);       --  wood is asked for below 28, until 32
      Run (1);
      Check (Demand_For (Wood).Asked, "with none in store, wood is asked for");
      Supply (Wood, 30, Placed);
      Run (1);
      Check (Demand_For (Wood).Have = 30 and then Demand_For (Wood).Asked,
             "at 30, between the levels, it is still asked for");
      Supply (Wood, 2, Placed);
      Run (1);
      Check (Demand_For (Wood).Have = 32 and then not Demand_For (Wood).Asked, "at 32 the asking stops");
      Set_Wood_Reserve (22);                        --  now below 30, until 34: 32 is between them
      Run (1);
      Quiet := not Demand_For (Wood).Asked;
      Set_Wood_Reserve (25);                        --  below 33
      Run (1);
      Check (Quiet and then Demand_For (Wood).Asked,
             "with the levels raised round it, it stays quiet between them, and is asked for again below the low one");
      Set_Wood_Reserve (22);                        --  between them again, as two steps ago
      Run (1);
      Asking_It := Demand_For (Wood).Asked;
      Check (Asking_It and then Demand_For (Wood).Low = 30 and then Demand_For (Wood).High = 34
             and then Demand_For (Wood).Have = 32,
             "the same stock between the same levels, and the other answer: it goes on being asked for till the high one");
      declare
         Data  : constant Bytes := Save;
         Later : Natural := 0;
         H0    : constant Long_Float := Hours;
      begin
         Run (400);                                 --  nobody has a job yet: nothing in the world changes
         declare
            Went_On : constant Bytes := Save;
         begin
            Set_Wood_Reserve (0);
            Run (1);
            Load (Data, Ok);
            Check (Ok and then Demand_For (Wood).Asked and then Wood_Reserve = 22 and then Save = Data,
                   "a save between the levels keeps what was being asked for, and saves back the same bytes");
            Hours := H0;
            Run (400);
            Check (Save = Went_On, "and 400 s later the colony is just where it would have been");
         end;
         Set_Job (1, Forester);
         Run (3);
         Check (Status (1) in "going to fell a tree" | "felling a tree",
                "a forester fells while wood is asked for: '" & Status (1) & "'");
         for S in 1 .. 1_500 loop
            Run (1);
            Later := S;
            exit when Person (1).Resting;
         end loop;
         Check (Person (1).Resting and then Status (1) = "enough wood in store" and then Demand_For (Wood).Have >= 34
                and then Logs_Lying = 0 and then not Demand_For (Wood).Asked,
                "with 34 in store it carries its last tree home and rests, after" & Later'Image & " s: '"
                & Status (1) & "', " & Img (Demand_For (Wood).Have) & " logs");
      end;
      Set_Demand_Chain (False);
      declare
         Data : constant Bytes := Save;
      begin
         Set_Demand_Chain (True);
         Load (Data, Ok);
         Check (Ok and then not Demand_Chain and then Wood_Reserve = 0,
                "the switch is saved: a colony with the chain off loads with it off");
      end;
   end;

   Put_Line ("demand: gatherers stop when food is in store, and start again a day later:");
   Set_Up (With_Needs => True, With_Field => True, With_Demand => True);
   declare
      Cells, Placed : Natural;
      Day    : constant Natural := Food_A_Day;
      Basket, Stored_0, Took, Back : Natural := 0;
      Fell_To : Natural := Natural'Last;
      Early   : Boolean := False;
   begin
      Zone_Stockpile (26.0, 15.0, 39.0, 17.0, Cells);
      Set_Reserve (Vegetables, 0);
      Set_Job (1, Gatherer);
      Set_Job (2, Gatherer);
      Hours := 16.0 * 24.0 + 7.0;
      for S in 1 .. 600 loop
         Run (1);
         exit when Status (1) (1 .. 7) = "picking" and then Carried (1) in 5 .. 20;
      end loop;
      Basket := Carried (1);
      Check (Food_Demand.Asked and then Basket in 5 .. 20,
             "with no food in store it is asked for, and the gatherers are out: '" & Status (1) & "'");
      Stored_0 := Stored (Berries);
      Supply (Vegetables, (2 * Day) / 3 + 1, Placed);       --  raw, a vegetable is three points: two days of food
      for S in 1 .. 900 loop
         Run (1);
         Took := S;
         exit when Person (1).Resting and then Person (2).Resting;
      end loop;
      Check (not Food_Demand.Asked and then Person (1).Resting and then Person (2).Resting
             and then Status (1) = "enough food in store" and then Carried (1) = 0 and then Carried (2) = 0
             and then Stored (Berries) + Eaten_Raw (Berries) >= Stored_0 + Basket,
             "two days of food supplied: each finishes its basket or its bush, takes it home and rests, in"
             & Took'Image & " s: '" & Status (1) & "'");
      for S in 1 .. 4_000 loop
         Run (1);
         Back := S;
         Early := Early or else (Food_Demand.Asked and then Food_Demand.Have >= Food_Demand.Low + 60);
         exit when Food_Demand.Asked;
         Fell_To := Food_Demand.Have;
      end loop;
      Check (Food_Demand.Asked and then not Early and then Fell_To < Food_Demand.Low + 60
             and then Fell_To < 2 * Day - Day / 2,
             "they rest while the stores go down from two days of food to one, then it is asked for again: after"
             & Img (Float (Back) / 60.0, 1) & " game hours, at " & Img (Float (Fell_To) / Float (Day), 2) & " days");
      for S in 1 .. 1_500 loop
         Run (1);
         exit when (for some I in 1 .. 2 => Carrying (I) = Berries and then Doing (I) = Picking);
      end loop;
      Check ((for some I in 1 .. 2 => Carrying (I) = Berries and then Doing (I) = Picking),
             "and the gatherers go out again: '" & Status (1) & "', '" & Status (2) & "'");
   end;

   Put_Line ("demand: one kind short of its surplus, food in store:");
   Set_Up (With_Needs => True, With_Field => True, With_Vegetables => True, With_Demand => True);
   declare
      Cells, Placed : Natural;
      Day    : constant Natural := Food_A_Day;
      Strayed : Boolean := False;
   begin
      Zone_Stockpile (26.0, 15.0, 39.0, 17.0, Cells);
      Supply (Apples, Day + 10, Placed);                    --  raw, an apple is two points: two days of food
      Set_Job (1, Gatherer);
      Hours := 16.0 * 24.0 + 7.0;
      for S in 1 .. 900 loop
         Run (1);
         Strayed := Strayed or else Carrying (1) in Berries | Apples
           or else Status (1) in "going to pick berries" | "going for apples";
         exit when Person (1).Resting;
      end loop;
      Check (not Food_Demand.Asked and then Vegetables_Pulled > 0 and then not Strayed and then Stored (Berries) = 0,
             "vegetables are below their surplus of 40 while food is not asked for: the gatherer goes for them alone ("
             & Img (Vegetables_Pulled) & " pulled, no berries)");
      Check (Person (1).Resting or else Status (1) = "no vegetables in reach" or else Have (Vegetables) < 40,
             "and rests once there are 40, or there are no more: '" & Status (1) & "', "
             & Img (Have (Vegetables)) & " vegetables");
   end;

   Put_Line ("demand: hunters answer the band's food:");
   Set_Up (With_Needs => True, With_Demand => True);
   declare
      Ok     : Boolean;
      Placed : Natural;
   begin
      Set_Job (1, Hunter);
      Supply (Meat, 25, Placed);
      Hours := 16.0 * 24.0 + 7.0;
      Run (20);
      Check (Food_Demand.Asked and then not Demand_For (Meat).Asked and then Person (1).Resting
             and then Status (1) = "enough meat in store (and no cook to make food of it)",
             "with no camp and no cook, meat is not food: its surplus met, the hunter rests: '" & Status (1) & "'");
      Zone_Camp ((30.0, 24.0, Ground_M), Ok);
      Set_Job (2, Cook);
      for S in 1 .. 120 loop
         Run (1);
         exit when not Person (1).Resting;
      end loop;
      Check (Ok and then Food_Demand.Asked and then not Demand_For (Meat).Asked and then Asked_For (Meat)
             and then Status (1) in "going after deer" | "stalking a deer" | "drawing the bow" | "letting the deer settle",
             "with a camp and a cook, its meat surplus met, it hunts because food is asked for: '" & Status (1) & "'");
      Set_Demand_Chain (False);
      Check (not Asked_For (Meat), "(with the chain off the same stores ask for no meat: only the reserve counts)");
   end;

   Put_Line ("demand: a porter, straw and stone in reach:");
   Set_Up (With_Porter_Ground => True, With_Demand => True);
   Set_Job (1, Porter);
   Run (1_200);
   Check (Have (Straw) >= 20 and then Have (Stone) >= 20 and then Person (1).Resting
          and then Status (1) = "the stocks are full" and then not Demand_For (Straw).Asked
          and then not Demand_For (Stone).Asked,
          "it fetches the straw and the stone that are asked for, then rests: straw" & Have (Straw)'Image
          & ", stone" & Have (Stone)'Image & ", '" & Status (1) & "'");

   ------------------------------------------------------------------ the camp is built
   Put_Line ("the camp is built by the band: the ground, stone, wood:");
   Set_Up (With_Trees => True, With_Porter_Ground => True, With_Demand => True, With_Labour => True);
   Hours := 16.0 * 24.0 + 7.0;
   declare
      Ok : Boolean;
      Fire : constant Vec3 := (44.0, 26.0, Ground_M);
      Rock_0 : constant Natural := Rock_Left;
      Saw_Tamp, Saw_Prise, Saw_Deadwood, Porter_Wood : Boolean := False;
      Built_At : Natural := 0;
      Most_Tamping : Natural := 0;

      --  the camp's turf: trodden to earth within reach of the fire, left as it was beyond
      procedure Count_Turf (Earth_Near, Grass_Near, Grass_Far : out Natural) is
      begin
         Earth_Near := 0;
         Grass_Near := 0;
         Grass_Far := 0;
         for X in B (Fire.X - 3.5) .. B (Fire.X + 3.5) - 1 loop
            for Y in B (Fire.Y - 3.5) .. B (Fire.Y + 3.5) - 1 loop
               declare
                  D : constant Float := Flat (((Float (X) + 0.5) * 0.25, (Float (Y) + 0.5) * 0.25, 0.0), Fire);
                  M : constant Material := Get (X, Y, Ground_Row - 1);
               begin
                  if D <= Float (Hearth_Ground_M) then
                     Earth_Near := Earth_Near + (if M = Dirt then 1 else 0);
                     Grass_Near := Grass_Near + (if M = Grass then 1 else 0);
                  elsif M = Grass then
                     Grass_Far := Grass_Far + 1;
                  end if;
               end;
            end loop;
         end loop;
      end Count_Turf;
      Earth_Near, Grass_Near, Grass_Far : Natural;
   begin
      Fill (41.0, 23.0, 43.0, 25.0, Ground_Row, Ground_Row, Tall_Grass);     --  long grass on a corner of it
      Changed_World;
      Zone_Camp (Fire, Ok);
      Count_Turf (Earth_Near, Grass_Near, Grass_Far);
      Check (Ok and then Has_Camp and then not Camp_State.Built and then not Zone_At (Camp_Zone).Built
             and then Camp_State.Ground_Left > 20 and then Earth_Near = 0
             and then Get (B (42.0), B (24.0), Ground_Row) = Tall_Grass,
             "zoning the camp marks it: nothing stands yet, its grass uncut," & Camp_State.Ground_Left'Image
             & " square metres of ground to make ready");
      declare
         use Castle.Views;
         C : constant Sheet := Zone (Camp_Zone);
      begin
         Check ((for some K in 1 .. Demand_Rows =>
                   Demand_Row_At (K).Who = A_Zone and then Demand_Row_At (K).What = Stone
                   and then Demand_Row_At (K).Kind = Once and then Demand_Row_At (K).Amount = Hearth_Stones)
                and then (for some K in 1 .. Demand_Rows =>
                            Demand_Row_At (K).Who = A_Zone and then Demand_Row_At (K).What = Wood
                            and then Demand_Row_At (K).Kind = Once
                            and then Demand_Row_At (K).Amount = Hearth_Wood + Seat_Logs)
                and then Demand_For (Stone).Once = Stone_Quota + Hearth_Stones
                and then Value_Of (C, "Hearth") = "to be built" and then Value_Of (C, "Stone") = "0 of 10"
                and then Value_Of (C, "Wood") = "0 of 3",
                "it asks the stores for what its hearth takes: 10 stone and 3 logs once, with its seats' 4 ('"
                & Value_Of (C, "Asks for") & "')");
      end;
      Set_Job (6, Porter);
      for S in 1 .. 900 loop
         Run (1);
         declare
            Tamping_N : Natural := 0;
         begin
            for I in 1 .. Members loop
               if Status (I) = "making the camp's ground ready" then
                  Saw_Tamp := True;
                  Tamping_N := Tamping_N + 1;
               end if;
               if Status (I)'Length > 15 and then Status (I) (1 .. 15) = "gathering stone" and then Job_Of (I) /= Porter
               then
                  Saw_Prise := True;
               end if;
               if Status (I) = "carrying deadwood to the hearth" then
                  Saw_Deadwood := True;
               end if;
               if Job_Of (I) = Porter and then Carrying (I) in Wood | Sticks then
                  Porter_Wood := True;
               end if;
            end loop;
            Most_Tamping := Natural'Max (Most_Tamping, Tamping_N);
         end;
         if Camp_State.Built and then Built_At = 0 then
            Built_At := S;
         end if;
         exit when Built_At > 0 and then S >= Built_At + 60 and then Paths_To_Lay = 0;   --  (and the path laid)
      end loop;
      Count_Turf (Earth_Near, Grass_Near, Grass_Far);
      Check (Saw_Tamp and then Most_Tamping >= 3 and then Camp_State.Ground_Left = 0 and then Grass_Near = 0
             and then Earth_Near > 300 and then Grass_Far > 300
             and then Get (B (42.0), B (24.0), Ground_Row) = Air and then Get (B (42.0), B (24.0), Ground_Row - 1) = Grass,
             "they make the ground ready together (" & Img (Most_Tamping) & " at once): the grass on it cut, the turf round"
             & " the fire trodden to earth (" & Img (Earth_Near) & " block columns), the rest left grass");
      Check (Saw_Prise and then Camp_State.Stones = Hearth_Stones
             and then Rock_0 - Rock_Left = Hearth_Stones + Stored (Stone) + (Have (Stone) - Stored (Stone)),
             "with no stone stored they prise it off the boulder themselves: 10 set for the ring, every one prised"
             & " accounted for (" & Img (Rock_0 - Rock_Left) & " off the boulder," & Stored (Stone)'Image & " stored)");
      Check (Saw_Deadwood and then Camp_State.Frame = Hearth_Wood and then Trees_Felled = 0 and then not Porter_Wood,
             "with no logs stored the crossbar is deadwood from under a tree; the porter carried none of it");
      Check (Built_At > 0 and then Camp_State.Built and then Zone_At (Camp_Zone).Built,
             "then the hearth stands, and the pot with it: built" & Built_At'Image & " game minutes after it was zoned");
      Check ((for all I in 1 .. Members => Carried (I) = 0 or else Job_Of (I) = Porter)
             and then (for all I in 1 .. 5 => Status (I) = "waiting at the stake")
             and then not (for some K in 1 .. Demand_Rows =>
                             Demand_Row_At (K).Who = A_Zone and then Demand_Row_At (K).What = Stone),
             "and they go back to what they were at, empty handed; the camp asks for no more stone");
   end;

   Put_Line ("the camp is built: from the stockpile when it holds what is wanted; the seats:");
   Set_Up (With_Trees => True, With_Porter_Ground => True, With_Labour => True);
   Hours := 16.0 * 24.0 + 7.0;
   declare
      Ok : Boolean;
      Placed : Natural;
      Rock_0 : constant Natural := Rock_Left;
      Built_At, Seats_At : Natural := 0;
      Porter_Wood, Others_Logs : Boolean := False;
   begin
      Supply (Stone, 32, Placed);                    --  (more than the paths' 20: nothing for the porter to fetch)
      Supply (Wood, 9, Placed);
      Zone_Camp ((44.0, 26.0, Ground_M), Ok);
      Set_Job (1, Cook);
      Set_Job (6, Porter);
      Set_Reserve (Straw, 0);
      for S in 1 .. 900 loop
         Run (1);
         for I in 1 .. Members loop
            if Job_Of (I) = Porter and then Carrying (I) in Wood | Sticks then
               Porter_Wood := True;
            end if;
            if Job_Of (I) /= Cook and then Carrying (I) = Wood then
               Others_Logs := True;
            end if;
         end loop;
         if Camp_State.Built and then Built_At = 0 then
            Built_At := S;
         end if;
         if Camp_State.Seats = Seat_Logs and then Seats_At = 0 then
            Seats_At := S;
         end if;
         exit when Built_At > 0 and then Seats_At > 0 and then S >= Natural'Max (Built_At, Seats_At) + 30;
      end loop;
      Check (Built_At > 0 and then Stored (Stone) = 22 and then Rock_Left = Rock_0 and then Trees_Felled = 0,
             "stone in the stockpile is what they build with: 10 of the 32 taken (" & Img (Stored (Stone))
             & " left), the boulder untouched (built after" & Built_At'Image & " minutes)");
      Check (Seats_At > 0 and then Camp_State.Seats = Seat_Logs
             and then Stored (Wood) + Camp_State.Logs in 9 - Hearth_Wood - Seat_Logs .. 9 - Seat_Logs
             and then not Porter_Wood and then not Others_Logs,
             "the four seat logs come from it too, and the cook lays them before anything of its own (all four"
             & Seats_At'Image & " minutes after zoning); nobody else carried a log, and the porter no wood at all");
   end;

   Put_Line ("the camp is built: saves; no stone in reach; built on the spot:");
   Set_Up (With_Trees => True, With_Porter_Ground => True, With_Needs => True, With_Labour => True);
   Hours := 16.0 * 24.0 + 7.0;
   declare
      Ok : Boolean;
      Snap : Snapshot;
   begin
      Zone_Camp ((44.0, 26.0, Ground_M), Ok);
      Set_Job (1, Cook);
      Set_Job (2, Gatherer);
      for Pass in 1 .. 2 loop
         --  first with the ground half made ready, then with stone and wood on their way
         for S in 1 .. 600 loop
            Run (1);
            exit when Camp_State.Built;
            exit when Pass = 1 and then (for some I in 1 .. Members => Status (I) = "making the camp's ground ready")
              and then (for some I in 1 .. Members => Status (I) = "going to make the camp's ground ready");
            exit when Pass = 2 and then Camp_State.Ground_Left = 0
              and then (for some I in 1 .. Members => Carrying (I) in Stone | Sticks and then Carried (I) > 0);
         end loop;
         declare
            Saved_Hours : constant Long_Float := Hours;
            Data : constant Bytes := Save;
            Left : constant Natural := Camp_State.Ground_Left;
            Mid  : constant Boolean := not Camp_State.Built;
            More : constant Natural := (if Pass = 1 then 15 else 300);
         begin
            Take (Snap);
            Run (More);
            declare
               A : constant Bytes := Save;
               Built_A : constant Boolean := Camp_State.Built;
            begin
               Give_Back (Snap);
               Hours := Saved_Hours;
               Load (Data, Ok);
               Check (Ok and then Save = Data and then Mid and then not Camp_State.Built,
                      (if Pass = 1 then "a save taken with the ground being made ready (" & Img (Left) & " square metres left)"
                       else "and one taken with stone and wood on their way (" & Img (Camp_State.Stones) & " stones, "
                            & Img (Camp_State.Frame) & " pieces of wood set)")
                      & " loads back to the same bytes");
               Run (More);
               Check (Save = A and then Camp_State.Built = Built_A and then (Pass = 1 or else Built_A),
                      "and" & More'Image & " s later the colony is just where it would have been"
                      & (if Pass = 2 then ": the hearth standing" else ""));
            end;
         end;
      end loop;
   end;
   Set_Up (With_Trees => True, With_Needs => True, With_Labour => True);     --  no boulder anywhere
   Hours := 16.0 * 24.0 + 7.0;
   declare
      use Castle.Views;
      Ok : Boolean;
      Placed : Natural;
      Waits : Boolean := False;
   begin
      Supply (Meat, 8, Placed);
      Supply (Berries, 60, Placed);
      Supply (Wood, 12, Placed);
      Zone_Camp ((44.0, 26.0, Ground_M), Ok);
      Set_Job (1, Cook);
      for S in 1 .. 400 loop
         Run (1);
         if Status (1) = "the camp is not built yet"
           or else (Status (1)'Length > 16 and then Status (1) (1 .. 16) = "nothing to cook:")
         then
            Waits := True;
         end if;
      end loop;
      Check (not Camp_State.Built and then Camp_State.Ground_Left = 0 and then Camp_State.Frame = Hearth_Wood
             and then Camp_State.Stones = 0 and then Value_Of (Zone (Camp_Zone), "Short of") = "10 stone"
             and then Camp_State.Stew = 0,
             "with no stone to be had the hearth waits, and its sheet says for what: 'Short of "
             & Value_Of (Zone (Camp_Zone), "Short of") & "'");
      Check (Waits, "the cook, with nothing to cook at, gathers meanwhile or says so");
      for S in 1 .. 600 loop                        --  (the cook lays the seats meanwhile)
         exit when Camp_State.Seats = Seat_Logs and then Carried (1) = 0;
         Run (1);
      end loop;
      declare
         Wood_0 : constant Natural := Stored (Wood);
         Hauled : Boolean := False;
      begin
         loop                                        --  through the evening and to bed
            Run (5);
            if Carrying (1) = Wood then
               Hauled := True;
            end if;
            exit when Hour_Now (Hours) >= 1.0 and then Hour_Now (Hours) < 2.0;
         end loop;
         Check (Eaten_Raw (Berries) > 0 and then Stored (Meat) = 8 and then Put_In_Pot (Meat) = 0
                and then Camp_State.Stew = 0,
                "with no hearth to cook at they eat raw what the stockpile has (" & Img (Eaten_Raw (Berries))
                & " handfuls of berries); the meat waits for a pot");
         Check (Asleep (1) and then not Hauled and then Stored (Wood) = Wood_0 and then not Camp_State.Burning
                and then Camp_State.Fuel_H = 0.0 and then Camp_State.Logs = 0 and then Camp_State.Seats = Seat_Logs,
                "at night it sleeps: no fire is seen to where no hearth stands, and the logs stay stored ("
                & Img (Wood_0) & " after the crossbar's and the seats')");
         Hours := 16.0 * 24.0 + 31.0;                --  and on to the next morning
         Run (30);
      end;
      Build_Camp_Now;
      Check (Camp_State.Built and then Camp_State.Stones = Hearth_Stones, "(built on the spot, as a scripted start can)");
      for S in 1 .. 600 loop
         Run (1);
         exit when Camp_State.Stew > 0;
      end loop;
      Check (Camp_State.Stew > 0 and then Camp_State.Burnt >= 1,
             "and with a hearth the cook lights the fire and cooks:" & Camp_State.Stew'Image & " points of stew");
   end;

   ------------------------------------------------------------------ no limit on how far they go for it
   Put_Line ("the camp is built: stone further off than their work reaches:");
   Reset;
   Set_Beds (False);
   Set_Labour (True);
   Set_Needs (False);
   Set_Skills (False);
   Set_Demand_Chain (False);
   Meadow;
   for Dx in -3 .. 3 loop                              --  the only boulder, 76 m from the stake
      for Dy in -3 .. 3 loop
         for Dz in -3 .. 3 loop
            if Dx * Dx + Dy * Dy + Dz * Dz < 10 then
               Set (232 + Dx, 232 + Dy, Ground_Row + Dz, Boulder);
            end if;
         end loop;
      end loop;
   end loop;
   Changed_World;
   Hours := 16.0 * 24.0 + 7.0;
   declare
      Ok : Boolean;
      Laid, Cells, Placed : Natural;
      Stake_Far : constant Vec3 := (4.0, 4.0, Ground_M);
      Rock_At   : constant Vec3 := (58.0, 58.0, 0.0);
      Rock_0    : Natural := 0;
      Furthest, Reach_Most : Float := 0.0;
      Saw_Row, Went : Boolean := False;
      Snap : Snapshot;
      function Rock_Now return Natural is
        (Count_In (229, 229, 235, 235, Ground_Row - 3, Ground_Row + 3, Boulder));
   begin
      Place_Stake (Stake_Far, 6, 42);
      Lay_Path ((4.5, 2.0, Ground_M), (24.0, 2.0, Ground_M), Laid);
      Zone_Stockpile (6.0, 3.0, 10.0, 5.0, Cells);
      Index_All;
      Supply (Wood, 7, Placed);                        --  (no tree anywhere: the crossbar's and the seats' logs)
      Rock_0 := Rock_Now;
      Zone_Camp ((14.0, 14.0, Ground_M), Ok);
      Set_Job (1, Cook);
      Check (Ok and then Flat (Stake, Rock_At) > Float (Work_Radius_M) and then Looking_M = 0.0
             and then Ground_Reach_M = Float (Work_Radius_M),
             "the nearest stone is " & Img (Flat (Stake, Rock_At), 0) & " m from the stake, further than their work"
             & " reaches (" & Img (Float (Work_Radius_M), 0) & " m); nobody looks further yet");
      for S in 1 .. 1_500 loop
         Run (1);
         Reach_Most := Float'Max (Reach_Most, Looking_M);
         if Looking_M > 0.0 and then Ground_Reach_M /= Looking_M then
            Ok := False;                               --  the colony's ground must reach as far as they look
         end if;
         if Castle.Views.Row_Named (Castle.Views.Zone (Camp_Zone), "Looking for it") > 0 then
            Saw_Row := True;
         end if;
         for I in 1 .. Members loop
            Furthest := Float'Max (Furthest, Flat (Where (I), Stake));
            if Status (I) = "going for stone for the hearth" and then not Went then
               --  a save taken with someone on the way there comes back the same
               Went := True;
               declare
                  Saved_Hours : constant Long_Float := Hours;
                  Data : constant Bytes := Save;
                  Ok2  : Boolean;
               begin
                  Take (Snap);
                  Run (400);
                  declare
                     A : constant Bytes := Save;
                  begin
                     Give_Back (Snap);
                     Hours := Saved_Hours;
                     Load (Data, Ok2);
                     Check (Ok2 and then Save = Data and then Looking_M > Float (Work_Radius_M),
                            "a save taken with someone on the way to it loads to the same bytes, the band still"
                            & " looking as far as " & Img (Looking_M, 0) & " m");
                     Run (400);
                     Check (Save = A, "and 400 s later the colony is just where it would have been");
                     Give_Back (Snap);
                     Hours := Saved_Hours;
                     Load (Data, Ok2);
                  end;
               end;
            end if;
         end loop;
         exit when Camp_State.Built and then Looking_M = 0.0;
      end loop;
      Check (Ok and then Reach_Most >= Flat (Stake, Rock_At) and then Reach_Most < Flat (Stake, Rock_At) + 2.0 * Float (Reach_Step_M)
             and then Saw_Row,
             "with none in reach they look further, a ring at a time, till there is some: as far as "
             & Img (Reach_Most, 0) & " m, and the camp's sheet says so");
      Check (Went and then Furthest > Float (Work_Radius_M) + 10.0 and then Rock_0 - Rock_Now >= Hearth_Stones
             and then Camp_State.Stones = Hearth_Stones and then Camp_State.Built,
             "they walk out for it, " & Img (Furthest, 0) & " m from the stake, and the hearth stands ("
             & Img (Rock_0 - Rock_Now) & " stones off that boulder)");
      Check (Looking_M = 0.0 and then Ground_Reach_M = Float (Work_Radius_M)
             and then (for all I in 1 .. Members => Flat (Where (I), Stake) <= Float (Work_Radius_M) + Float (Reach_Step_M)),
             "the camp standing and everyone back, they look no further than their work again");
   end;

   ------------------------------------------------------------------ paths: planned, then laid
   Put_Line ("paths: the player plans one, the band lays it:");
   Set_Up (With_Stockpile => False, With_Labour => True);
   declare
      Laid, Cells : Natural;
      N0   : constant Natural := Path_Count;
      Saw_Lay : Boolean := False;
      Most : Natural := 0;
      Done_At : Natural := 0;
      Layers : array (1 .. 6) of Boolean := [others => False];
      Most_Laid : Natural := 0;
      Stood_By : Boolean := True;
      function Footpath_On (X0, X1 : Float; Y : Float) return Natural is
        (Count_In (B (X0), B (Y - 0.5), B (X1) - 1, B (Y + 0.5) - 1, Ground_Row - 1, Ground_Row - 1, Footpath));
      Snap : Snapshot;
      Ok : Boolean;
   begin
      Check (N0 = 1 and then Paths_To_Lay = 20 and then Footpath_On (20.5, 40.0, 17.5) = 0
             and then Get (B (30.0), B (17.5), Ground_Row - 1) = Grass and then Near_Path (30.0, 17.5, 0.0),
             "a path marked is planned, not laid: 20 m of it to lay, the ground still grass");
      Zone_Stockpile (21.0, 15.0, 25.0, 17.0, Cells);
      Check (Cells = 8 and then On_Path (30.0, 17.5) and then Zone_On (22.0, 17.2) = 0,
             "a stockpile is zoned along it all the same, and its ground is no zone's: the plan is the path");
      Fill (26.0, 17.0, 28.0, 18.0, Ground_Row, Ground_Row, Tall_Grass);
      Changed_World;
      for S in 1 .. 600 loop
         Run (1);
         declare
            N : Natural := 0;
         begin
            for I in 1 .. Members loop
               if Status (I) = "laying the path" or else Status (I) = "going to lay the path" then
                  Saw_Lay := True;
                  N := N + 1;
                  Layers (I) := True;
                  Most_Laid := Natural'Max (Most_Laid, Laid_By (I));
                  Stood_By := Stood_By and then Stretch_Of (I) = 1;
               else
                  Stood_By := Stood_By and then Status (I) = "waiting at the stake"
                    and then (Stretch_Of (I) = 0 or else Layers (I));          --  (its own, between two metres)
               end if;
            end loop;
            Most := Natural'Max (Most, N);
         end;
         if S = 12 then
            --  a save taken with the path part laid comes back the same
            declare
               Saved_Hours : constant Long_Float := Hours;
               Data : constant Bytes := Save;
               Left : constant Natural := Paths_To_Lay;
            begin
               Take (Snap);
               Run (60);
               declare
                  A : constant Bytes := Save;
               begin
                  Give_Back (Snap);
                  Hours := Saved_Hours;
                  Load (Data, Ok);
                  Run (60);
                  Check (Ok and then Left in 1 .. 19 and then Save = A,
                         "a save taken with " & Img (Left) & " m still to lay loads, and 60 s later the colony is"
                         & " just where it would have been");
                  Give_Back (Snap);
                  Hours := Saved_Hours;
                  Load (Data, Ok);
               end;
            end;
         end if;
         if Paths_To_Lay = 0 and then Done_At = 0 then
            Done_At := S;
         end if;
         exit when Done_At > 0 and then S >= Done_At + 20;
      end loop;
      Check (Saw_Lay and then Most = 1 and then Stood_By
             and then (for some I in 1 .. 6 => Layers (I) and then (for all J in 1 .. 6 => J = I or else not Layers (J))),
             "its 20 m are one stretch, and one serf's: it is given to the first to turn to it and nobody else lays"
             & " a metre of it, though all six have nothing else to do");
      Check (Most_Laid in 19 .. 20 and then Done_At > 0 and then Footpath_On (20.5, 40.0, 17.5) > 300
             and then Get (B (27.0), B (17.5), Ground_Row) = Air
             and then (for all I in 1 .. Members => Status (I) = "waiting at the stake" and then Stretch_Of (I) = 0),
             "it lays it from end to end (" & Img (Most_Laid) & " metres counted to it when last seen at it): all"
             & " footpath after" & Done_At'Image
             & " game minutes, the grass on it cut; then it has no stretch and is back at the stake");
      Check (Zone_On (22.0, 16.9) = 1 and then Get (B (22.0), B (16.9), Ground_Row - 1) = Grass,
             "the stockpile's ground beside it is not laid");
      --  a long stretch is kept as pieces; a path through a zone is still refused
      Lay_Path ((40.0, 17.5, Ground_M), (40.0, 60.0, Ground_M), Laid);
      Check (Laid > 0 and then Path_Count = N0 + 3 and then Paths_To_Lay >= 42,
             "a path of 42 m is kept as three stretches, two of 20 m and what is left (" & Img (Paths_To_Lay)
             & " m to lay)");
      Lay_Path ((23.0, 10.0, Ground_M), (23.0, 16.5, Ground_M), Laid);
      Check (Laid = 0 and then Path_Count = N0 + 3, "and one planned through a zone is refused as before");
      Build_Paths_Now;
      Check (Paths_To_Lay = 0 and then Get (B (40.0), B (50.0), Ground_Row - 1) = Footpath,
             "(laid on the spot, as a scripted start can)");
      --  a stretch dug up is laid again
      Set (B (30.0), B (17.5), Ground_Row - 1, Dirt);
      Changed_World;
      for S in 1 .. 120 loop
         Run (1);
         exit when Get (B (30.0), B (17.5), Ground_Row - 1) = Footpath;
      end loop;
      Check (Get (B (30.0), B (17.5), Ground_Row - 1) = Footpath and then Paths_To_Lay = 0,
             "a bit of a laid path dug up is found and laid again");
      Set_Labour (False);
      Lay_Path ((10.0, 40.0, Ground_M), (16.0, 40.0, Ground_M), Laid);
      Check (Laid > 0 and then Paths_To_Lay = 0 and then Get (B (13.0), B (40.0), Ground_Row - 1) = Footpath,
             "(with the band's labour off a path is laid the moment it is marked, as it was)");
   end;

   --  holes in the ground under a path are filled as it is laid (John, 2026-11-13: "It would be nice if there
   --  was a way for serfs to fill in holes in the path when they are compacting the ground"): a hole of one
   --  column, one of two, a ditch a block wide across the path, one of two by two; and a step up across it
   Put_Line ("holes under a path:");
   for Filling in Boolean loop
      declare
         Laid : Natural;
         Top  : constant Integer := Ground_Row - 1;
         type Spot is record
            X, Y : Integer;
         end record;
         Holes : constant array (1 .. 8) of Spot :=
           [(B (12.0), B (40.0)), (B (15.0), B (40.0)), (B (15.0) + 1, B (40.0)), (B (18.0), B (39.75)),
            (B (18.0), B (40.25)), (B (21.0), B (40.0)), (B (21.0) + 1, B (40.0) + 1), (B (21.0), B (40.0) + 1)];
         Filled, Down_In, Step_Kept, Square, Inlet_Kept, No_Float : Boolean := True;
      begin
         Set_Up (With_Labour => True, With_Bushes => False);
         Set_Path_Holes (Filling);
         for H of Holes loop
            Set (H.X, H.Y, Top, Air);
         end loop;
         Set (B (21.0) + 1, B (40.0), Top, Air);                     --  (the fourth of the two by two)
         for Y in B (38.0) .. B (42.0) loop                           --  (the ditch runs on past the path's edges)
            Set (B (18.0), Y, Top, Air);
         end loop;
         for X in B (23.0) .. B (23.0) + 3 loop                       --  a hole four by four, all under the path
            for Y in B (39.5) .. B (39.5) + 3 loop
               Set (X, Y, Top, Air);
            end loop;
         end loop;
         Set (B (12.0), B (40.0), Top + 1, Tall_Grass);               --  grass left over the first hole, in the air
         Fill (13.5, 36.0, 14.5, 44.0, Top + 1, Top + 2, Dirt);        --  a hump three blocks high across the path,
         Fill (13.5, 36.0, 14.5, 44.0, Top + 3, Top + 3, Grass);
         Set (B (14.0), B (40.0), Top + 11, Log);                     --  a log lying eight rows over it
         Fill (26.0, 36.0, 32.0, 44.0, Top + 1, Top + 1, Grass);      --  a step up a block, east of 26 m,
         Fill (26.0, 36.0, 32.0, 44.0, Top, Top, Dirt);
         for X in B (26.0) .. B (26.0) + 2 loop                       --  with an inlet a block wide cut into it
            Set (X, B (40.0), Top + 1, Air);                          --  along the path from the low side
            Set (X, B (40.0), Top, Grass);
         end loop;
         Changed_World;
         Lay_Path ((10.0, 40.0, Ground_M), (30.0, 40.0, Ground_M + 0.25), Laid);
         Build_Paths_Now;
         for H of Holes loop
            Filled := Filled and then Get (H.X, H.Y, Top) = Footpath and then Get (H.X, H.Y, Top - 1) = Dirt;
            Down_In := Down_In and then Get (H.X, H.Y, Top) = Air and then Get (H.X, H.Y, Top - 1) = Footpath;
         end loop;
         for X in B (23.0) .. B (23.0) + 3 loop
            for Y in B (39.5) .. B (39.5) + 3 loop
               Square := Square and then Get (X, Y, Top) = (if Filling then Footpath else Air);
            end loop;
         end loop;
         No_Float := Get (B (12.0), B (40.0), Top + 1) = Air;
         --  the hump laid on its top, the log over it no ground of it
         Step_Kept := Get (B (14.0), B (40.0), Top + 3) = Footpath and then Get (B (14.0), B (40.0), Top + 4) = Air;
         --  the step: the foot of it laid where it lies, and the path up on the top of it; the inlet into it
         --  (lower ground with higher on three sides of its end, but open to the low side) laid where it lies
         Step_Kept := Step_Kept and then Get (B (26.0) - 1, B (40.0) + 1, Top) = Footpath
           and then Get (B (26.0) - 1, B (40.0) + 1, Top + 1) = Air
           and then Get (B (27.0), B (40.0), Top + 1) = Footpath;
         Inlet_Kept := (for all X in B (26.0) .. B (26.0) + 2 =>
                          Get (X, B (40.0), Top) = Footpath and then Get (X, B (40.0), Top + 1) = Air);
         if Filling then
            Check (Laid > 0 and then Paths_To_Lay = 0 and then Filled and then Square and then No_Float
                   and then Step_Kept and then Inlet_Kept,
                   "a hole of one column, one of two, a ditch a block wide across the path, one of two by two and one of"
                   & " four by four are filled with earth and the path laid over them, the grass left in the air over"
                   & " one of them cut; a step up across the path is no hole, nor an inlet a block wide cut into it"
                   & " from below, nor a hump with a log lying over it: they are laid as they lie");
         else
            Check (Laid > 0 and then Paths_To_Lay = 0 and then Down_In and then Square and then Step_Kept and then Inlet_Kept
                   and then No_Float,
                   "(with that off the path goes down into each of them, as it did; the grass left in the air over"
                   & " one is cut all the same)");
         end if;
      end;
   end loop;

   ------------------------------------------------------------------ the camp's floor is made level
   Put_Line ("the camp's floor is made level:");
   declare
      Fire : constant Vec3 := (50.0, 30.0, Ground_M + 0.25);
      Top0 : constant Integer := Ground_Row - 1;          --  the meadow's top row

      --  Uneven ground under the camp: the meadow west of 49 m, a block
      --  higher from there, two higher east of 51.5 m (turf on each).
      procedure Three_Steps is
      begin
         Fill (49.0, 22.0, 58.0, 38.0, Top0, Top0, Dirt);
         Fill (49.0, 22.0, 58.0, 38.0, Top0 + 1, Top0 + 1, Grass);
         Fill (51.5, 22.0, 58.0, 38.0, Top0 + 1, Top0 + 1, Dirt);
         Fill (51.5, 22.0, 58.0, 38.0, Top0 + 2, Top0 + 2, Grass);
         Changed_World;
      end Three_Steps;

      function On_Floor (X, Y : Integer) return Boolean is
        (Flat (((Float (X) + 0.5) * 0.25, (Float (Y) + 0.5) * 0.25, 0.0), Fire) <= Float (Hearth_Ground_M));

      --  the floor's block columns: how many, how many with their top at
      --  row Level and bare earth, and whether the zone has each one's top there
      procedure Look_At_Floor (Level : Integer; Columns, Level_Bare : out Natural; Zone_Knows : out Boolean) is
      begin
         Columns := 0;
         Level_Bare := 0;
         Zone_Knows := True;
         for X in B (Fire.X - 3.0) .. B (Fire.X + 3.0) loop
            for Y in B (Fire.Y - 3.0) .. B (Fire.Y + 3.0) loop
               if On_Floor (X, Y) then
                  Columns := Columns + 1;
                  if Get (X, Y, Level) = Dirt and then Get (X, Y, Level + 1) = Air then
                     Level_Bare := Level_Bare + 1;
                  end if;
                  Zone_Knows := Zone_Knows
                    and then abs (Zone_Top ((Float (X) + 0.5) * 0.25, (Float (Y) + 0.5) * 0.25)
                                  - Float (Level + 1) * 0.25) < 0.001;
               end if;
            end loop;
         end loop;
      end Look_At_Floor;

      --  solid blocks in the floor's columns, rows Top0 - 1 .. Top0 + 3
      function Floor_Blocks return Natural is
         N : Natural := 0;
      begin
         for X in B (Fire.X - 3.0) .. B (Fire.X + 3.0) loop
            for Y in B (Fire.Y - 3.0) .. B (Fire.Y + 3.0) loop
               if On_Floor (X, Y) then
                  for Z in Top0 - 1 .. Top0 + 3 loop
                     N := N + (if Get (X, Y, Z) in Dirt | Grass then 1 else 0);
                  end loop;
               end if;
            end loop;
         end loop;
         return N;
      end Floor_Blocks;

      Ok : Boolean;
      Columns, Level_Bare, Placed : Natural;
      Zone_Knows : Boolean;
      Snap : Snapshot;
   begin
      Set_Up (With_Trees => True, With_Porter_Ground => True, With_Labour => True);
      Hours := 16.0 * 24.0 + 7.0;
      Three_Steps;
      Build_Paths_Now;
      declare
         Blocks_0 : constant Natural := Floor_Blocks;
         C0 : Camp_View;
         Built_At : Natural := 0;
         Saw_Dig, Saw_Tip, Saved_Mid : Boolean := False;
         --  a second at a time, looking at what each is doing
         procedure Watch (Seconds : Natural) is
         begin
            for T in 1 .. Seconds loop
               Run (1);
               for I in 1 .. Members loop
                  Saw_Dig := Saw_Dig or else (Carrying (I) = Earth and then Carried (I) > 0);
                  Saw_Tip := Saw_Tip or else Status (I) = "filling a hollow of the camp's ground";
               end loop;
            end loop;
         end Watch;
      begin
         Zone_Camp (Fire, Ok);
         C0 := Camp_State;
         Check (Ok and then abs (C0.Floor_Z - (Ground_M + 0.25)) < 0.001 and then C0.To_Dig in 40 .. 70
                and then C0.To_Fill in 70 .. 110 and then C0.To_Fill > C0.To_Dig,
                "a camp marked across three steps of ground: its floor is to be level with the middle one,"
                & C0.To_Dig'Image & " blocks of earth to dig off the high side," & C0.To_Fill'Image
                & " to fill on the low (the turf's earth makes up the rest)");
         Check (Castle.Views.Value_Of (Castle.Views.Zone (Camp_Zone), "Floor")
                = Img (C0.To_Dig) & " blocks of earth to dig off, " & Img (C0.To_Fill) & " to fill",
                "its sheet says so ('" & Castle.Views.Value_Of (Castle.Views.Zone (Camp_Zone), "Floor") & "')");
         Set_Job (6, Cook);
         for S in 1 .. 1_500 loop
            Watch (1);
            if not Saved_Mid and then Camp_State.To_Dig in 1 .. C0.To_Dig - 8 and then Camp_State.To_Fill > 0 then
               --  a save taken with the floor half levelled comes back the same
               Saved_Mid := True;
               declare
                  Saved_Hours : constant Long_Float := Hours;
                  Data : constant Bytes := Save;
                  Dig_Then : constant Natural := Camp_State.To_Dig;
               begin
                  Take (Snap);
                  Run (60);
                  declare
                     A : constant Bytes := Save;
                  begin
                     Give_Back (Snap);
                     Hours := Saved_Hours;
                     Load (Data, Ok);
                     Check (Ok and then Save = Data and then Camp_State.To_Dig = Dig_Then,
                            "a save taken with" & Dig_Then'Image & " blocks still to dig loads to the same bytes");
                     Watch (60);
                     Check (Save = A, "and 60 s later the colony is just where it would have been");
                  end;
               end;
            end if;
            if Camp_State.Built and then Built_At = 0 then
               Built_At := S;
            end if;
            exit when Built_At > 0 and then S >= Built_At + 120;
         end loop;
         Look_At_Floor (Top0 + 1, Columns, Level_Bare, Zone_Knows);
         Check (Built_At > 0 and then Saved_Mid and then Columns > 300 and then Level_Bare = Columns,
                "the band levels it as it makes the ground ready: every one of the floor's" & Columns'Image
                & " block columns ends at the one level, bare earth (the hearth stands after" & Built_At'Image
                & " game minutes)");
         Check (Zone_Knows and then abs (Camp.Z - (Ground_M + 0.25)) < 0.001
                and then abs (Zone_Top (47.0, 27.0) - Ground_M) < 0.001
                and then abs (Zone_Top (53.0, 33.0) - (Ground_M + 0.5)) < 0.001,
                "the camp's zone knows its ground as it lies now (its floor at the level, the rest of it as it was),"
                & " and the fire's place is on the floor");
         Check (Saw_Dig and then Saw_Tip and then Have (Earth) = 0
                and then Floor_Blocks = Blocks_0 + C0.To_Fill - C0.To_Dig,
                "every block dug off the high side went into a hollow of the low (none to the stockpile, none left in"
                & " anyone's hands); the turf's earth made up the other" & Natural'Image (C0.To_Fill - C0.To_Dig));
         declare
            Again : constant Bytes := Save;
         begin
            Load (Again, Ok);
            Check (Ok and then Save = Again, "it saves and loads back the same");
         end;
         --  the camp works on its floor: the seats are laid on it
         Supply (Wood, 6, Placed);
         for S in 1 .. 600 loop
            Run (1);
            exit when Camp_State.Seats = Seat_Logs;
         end loop;
         Check (Camp_State.Seats = Seat_Logs
                and then (for all K in 1 .. 2 * Seat_Logs => abs (Seat_Place (K).Z - (Ground_M + 0.25)) < 0.001),
                "the seat logs are laid on it, every place at the floor's level");
      end;

      --  built on the spot; left as it lies with levelling off, or the band's labour off
      Set_Up (With_Trees => True, With_Porter_Ground => True, With_Labour => True);
      Three_Steps;
      Zone_Camp (Fire, Ok);
      Build_Camp_Now;
      Look_At_Floor (Top0 + 1, Columns, Level_Bare, Zone_Knows);
      Check (Ok and then Camp_State.Built and then Level_Bare = Columns and then Zone_Knows and then Stored (Earth) = 0,
             "(built on the spot, its floor is level at once, the earth from nowhere and to nowhere)");
      Set_Up (With_Trees => True, With_Porter_Ground => True, With_Labour => True);
      Three_Steps;
      Set_Levelling (False);
      Zone_Camp (Fire, Ok);
      Build_Camp_Now;
      Look_At_Floor (Top0 + 1, Columns, Level_Bare, Zone_Knows);
      Check (Ok and then Camp_State.Built and then Camp_State.Floor_Z < 0.0 and then Level_Bare < Columns - 100
             and then Get (B (47.5), B (30.0), Top0) = Dirt and then Get (B (52.3), B (30.0), Top0 + 2) = Dirt,
             "(with levelling off its floor is left as it lies, its turf trodden where it is)");
      Set_Up (With_Trees => True, With_Porter_Ground => True, With_Labour => False);
      Three_Steps;
      Zone_Camp (Fire, Ok);
      Check (Ok and then Camp_State.Built and then Camp_State.Floor_Z < 0.0
             and then Get (B (47.5), B (30.0), Top0) = Grass and then Get (B (52.3), B (30.0), Top0 + 2) = Grass,
             "(and with the band's labour off nothing of its ground is touched)");
   end;

   --  earth over goes to the stockpile; with none, it is thrown aside; rock is left standing
   for With_Pile in Boolean loop
   Set_Up (With_Stockpile => With_Pile, With_Trees => True, With_Porter_Ground => True, With_Labour => True);
   Hours := 16.0 * 24.0 + 7.0;
   declare
      Fire : constant Vec3 := (50.0, 30.0, Ground_M);
      Top0 : constant Integer := Ground_Row - 1;
      Ok : Boolean;
      Held : Natural := 0;
      Saw_Haul : Boolean := False;
   begin
      Build_Paths_Now;
      --  a hump of earth a block high east of the fire, a knob of granite standing in it
      Fill (51.0, 29.0, 52.5, 31.0, Top0, Top0, Dirt);
      Fill (51.0, 29.0, 52.5, 31.0, Top0 + 1, Top0 + 1, Grass);
      Fill (51.5, 29.5, 52.0, 30.0, Top0 + 1, Top0 + 1, Granite);
      Changed_World;
      Zone_Camp (Fire, Ok);
      if With_Pile then
         Check (Ok and then abs (Camp_State.Floor_Z - Ground_M) < 0.001 and then Camp_State.To_Dig = 44
                and then Camp_State.To_Fill = 0,
                "a hump on the floor with a knob of rock in it: the earth of it is to dig off ("
                & Img (Camp_State.To_Dig) & " blocks), the rock is not");
      end if;
      for S in 1 .. 1_500 loop
         Run (1);
         for I in 1 .. Members loop
            Saw_Haul := Saw_Haul or else Status (I) = "taking" & Carried (I)'Image & " earth to the stockpile";
         end loop;
         exit when Camp_State.Built;
      end loop;
      Run (120);
      for I in 1 .. Members loop
         Held := Held + (if Carrying (I) = Earth then Carried (I) else 0);
      end loop;
      if With_Pile then
         Check (Camp_State.Built and then Get (B (51.2), B (29.2), Top0 + 1) = Air
                and then Get (B (51.7), B (29.7), Top0 + 1) = Granite and then Saw_Haul and then Held = 0
                and then Stored (Earth) = 44,
                "the hearth stands: the hump dug off, the rock standing, and every block of the earth heaped in"
                & " the stockpile (" & Img (Stored (Earth)) & ")");
      else
         Check (Camp_State.Built and then Get (B (51.2), B (29.2), Top0 + 1) = Air and then Held = 0
                and then Have (Earth) = 0 and then not Saw_Haul,
                "with no stockpile the earth is thrown aside: the hearth stands all the same and nobody is left"
                & " holding any");
      end if;
   end;
   end loop;

   --  a hollow dug in a floor of bare earth (no turf to fill it with): from the stockpile's earth, else left
   for With_Earth in Boolean loop
      Set_Up (With_Trees => True, With_Porter_Ground => True, With_Labour => True);
      Hours := 16.0 * 24.0 + 7.0;
      declare
         Fire : constant Vec3 := (50.0, 30.0, Ground_M);
         Top0 : constant Integer := Ground_Row - 1;
         Ok : Boolean;
         Placed : Natural;
         Saw_Fetch : Boolean := False;
      begin
         Build_Paths_Now;
         Fill (46.0, 26.0, 54.0, 34.0, Top0, Top0, Dirt);           --  bare ground under the camp
         Changed_World;
         Zone_Camp (Fire, Ok);
         Fill (51.0, 30.0, 51.5, 30.5, Top0 - 1, Top0, Air);        --  and someone digs a pit in its floor: 8 blocks
         Changed_World;
         if With_Earth then
            Supply (Earth, 20, Placed);
         end if;
         for S in 1 .. 1_500 loop
            Run (1);
            for I in 1 .. Members loop
               Saw_Fetch := Saw_Fetch or else Status (I) = "fetching earth for the camp's ground";
            end loop;
            exit when Camp_State.Built;
         end loop;
         Run (60);
         if With_Earth then
            Check (Ok and then Camp_State.Built and then Saw_Fetch and then Get (B (51.2), B (30.2), Top0) = Dirt
                   and then Stored (Earth) = 12 and then Have (Earth) = 12,
                   "a pit dug in a floor of bare earth is filled from the stockpile's earth: 8 of its 20 blocks, the"
                   & " other" & Stored (Earth)'Image & " left in store");
         else
            Check (Ok and then Camp_State.Built and then not Saw_Fetch and then Get (B (51.2), B (30.2), Top0) = Air
                   and then Camp_State.To_Fill = 0,
                   "with no earth to be had anywhere the pit is left, and the hearth stands all the same");
         end if;
      end;
   end loop;

   --  the limit holds through a levelling: a job each, the three steps, looked at every twentieth of a second
   Set_Up (With_Trees => True, With_Porter_Ground => True, With_Labour => True);
   Hours := 16.0 * 24.0 + 7.0;
   declare
      Fire : constant Vec3 := (50.0, 30.0, Ground_M + 0.25);
      Top0 : constant Integer := Ground_Row - 1;
      Ok : Boolean;
      Most_Told, Most_Seen, Steps_Run : Natural := 0;
      Saw_Earth : Boolean := False;
   begin
      Build_Paths_Now;
      Fill (49.0, 22.0, 58.0, 38.0, Top0, Top0, Dirt);
      Fill (49.0, 22.0, 58.0, 38.0, Top0 + 1, Top0 + 1, Grass);
      Fill (51.5, 22.0, 58.0, 38.0, Top0 + 1, Top0 + 1, Dirt);
      Fill (51.5, 22.0, 58.0, 38.0, Top0 + 2, Top0 + 2, Grass);
      Fill (53.0, 27.0, 55.0, 28.0, Top0 + 2, Top0 + 2, Dirt);     --  (a rise beside the floor, out of it)
      Changed_World;
      for I in 1 .. 5 loop
         Set_Job (I, Gatherer);
      end loop;
      Set_Job (6, Cook);
      Zone_Camp (Fire, Ok);
      for T in 1 .. 16 * 60 * 20 loop
         Hours := Hours + 0.05 / 60.0;
         Advance (0.05, Hours);
         declare
            N : Natural := 0;
         begin
            for I in 1 .. 5 loop
               N := N + (if Extra_Now (I) then 1 else 0);
               Saw_Earth := Saw_Earth or else (Carrying (I) = Earth and then Carried (I) > 0);
            end loop;
            Most_Seen := Natural'Max (Most_Seen, N);
            Most_Told := Natural'Max (Most_Told, At_Extra);
         end;
         Steps_Run := T;
         exit when Camp_State.Built;
      end loop;
      Check (Ok and then Camp_State.Built and then Saw_Earth and then Most_Told = 2 and then Most_Seen = 2,
             "a job each and a floor to level: never more than two of the five at it beside the cook, digging,"
             & " carrying earth or waiting with it, looked at every twentieth of a second (" & Img (Steps_Run / 20)
             & " game minutes to the hearth)");
   end;

   --  hollows nobody can get to: the stockpile's earth is not carried to and fro for them
   Set_Up (With_Trees => True, With_Porter_Ground => True, With_Labour => True);
   Hours := 16.0 * 24.0 + 7.0;
   declare
      Fire : constant Vec3 := (50.0, 30.0, Ground_M);
      Top0 : constant Integer := Ground_Row - 1;
      Ok : Boolean;
      Placed : Natural;
      Fetches : Natural := 0;
      Fetching : array (1 .. 6) of Boolean := [others => False];
   begin
      Build_Paths_Now;
      Fill (44.0, 24.0, 56.0, 36.0, Top0, Top0, Dirt);              --  bare ground (no turf to fill with)
      Changed_World;
      Zone_Camp (Fire, Ok);
      --  a wall of rock round a yard of the floor, a pit in the middle of it
      Fill (49.0, 28.0, 53.0, 28.25, Top0 + 1, Top0 + 4, Granite);
      Fill (49.0, 31.75, 53.0, 32.0, Top0 + 1, Top0 + 4, Granite);
      Fill (49.0, 28.0, 49.25, 32.0, Top0 + 1, Top0 + 4, Granite);
      Fill (52.75, 28.0, 53.0, 32.0, Top0 + 1, Top0 + 4, Granite);
      Fill (50.75, 29.75, 51.25, 30.25, Top0, Top0, Air);
      Changed_World;
      Supply (Earth, 40, Placed);
      for S in 1 .. 900 loop
         Run (1);
         for I in 1 .. Members loop
            declare
               F : constant Boolean := Status (I) = "fetching earth for the camp's ground";
            begin
               if F and then not Fetching (I) then
                  Fetches := Fetches + 1;
               end if;
               Fetching (I) := F;
            end;
         end loop;
      end loop;
      Check (Ok and then Placed = 40 and then Fetches in 1 .. 12 and then Have (Earth) = 40 and then Stored (Earth) = 40
             and then Camp_State.To_Fill = 4,
             "a pit walled off where nobody can get to it, and earth in store: each tries it once in ten game hours at"
             & " most (" & Img (Fetches) & " fetched in fifteen), and the earth is back in store, not carried to and fro");
   end;

   --  a ledge a metre high through the camp: the floor is cut into it and built out from it, and can be got to
   Set_Up (With_Trees => True, With_Porter_Ground => True, With_Labour => True);
   Hours := 16.0 * 24.0 + 7.0;
   declare
      Fire : constant Vec3 := (50.0, 30.0, Ground_M);
      Top0 : constant Integer := Ground_Row - 1;
      Ok : Boolean;
      Placed : Natural;
      C0 : Camp_View;
      Sunk : Natural := 0;
   begin
      Build_Paths_Now;
      Fill (50.5, 20.0, 62.0, 40.0, Top0, Top0 + 3, Dirt);
      Fill (50.5, 20.0, 62.0, 40.0, Top0 + 4, Top0 + 4, Grass);
      Changed_World;
      Zone_Camp (Fire, Ok);
      C0 := Camp_State;
      Check (Ok and then abs (C0.Floor_Z - (Ground_M + 0.25)) < 0.001 and then C0.To_Dig > 300 and then C0.To_Fill > 150,
             "a camp marked across a ledge a metre high, most of its floor below it: the floor is to be a block up"
             & " from the low side," & C0.To_Dig'Image & " blocks to dig off the ledge," & C0.To_Fill'Image
             & " to fill below");
      Set_Job (6, Cook);
      Set_Job (5, Forester);
      Supply (Wood, 8, Placed);
      for S in 1 .. 3_000 loop
         Run (1);
         for I in 1 .. Members loop
            --  nobody is left standing in the ground as it is filled under them
            if Get (B (Where (I).X), B (Where (I).Y), Integer (Float'Floor (Where (I).Z * 4.0 + 0.01))) in Dirt | Grass
              and then Get (B (Where (I).X), B (Where (I).Y), Integer (Float'Floor (Where (I).Z * 4.0 + 0.01)) + 1)
                       in Dirt | Grass
            then
               Sunk := Sunk + 1;
            end if;
         end loop;
         exit when Camp_State.Built and then Camp_State.Seats = Seat_Logs;
      end loop;
      Check (Camp_State.Built and then Camp_State.To_Dig = 0 and then Camp_State.To_Fill = 0
             and then Get (B (48.0), B (30.0), Top0 + 1) = Dirt and then Get (B (48.0), B (30.0), Top0 + 2) = Air
             and then Get (B (52.0), B (30.0), Top0 + 1) = Dirt and then Get (B (52.0), B (30.0), Top0 + 2) = Air
             and then Stored (Earth) = C0.To_Dig - C0.To_Fill,
             "they cut it in and build it out: the floor is level, a block up on the low side and three down on"
             & " the high, and the " & Img (Stored (Earth)) & " blocks of earth over are in store");
      Check (Camp_State.Seats = Seat_Logs and then Sunk = 0,
             "it can be got to: all four seat logs are laid on it, and nobody was left standing in the ground as it"
             & " rose");
   end;

   ------------------------------------------------------------------ paths: a stretch to a serf
   Put_Line ("paths: a stretch to a serf:");
   Set_Up (With_Stockpile => False, With_Labour => True);
   declare
      Laid : Natural;
      Most : Natural := 0;
      Each_Its_Own : Boolean := True;
      Done_At : Natural := 0;
   begin
      Build_Paths_Now;                                    --  (the meadow's own path out of the way)
      Lay_Path ((3.0, 56.0, Ground_M), (61.0, 56.0, Ground_M), Laid);
      Check (Path_Count = 4 and then Paths_To_Lay = 58, "58 m of path are three stretches: 20, 20 and 18 m");
      for S in 1 .. 600 loop
         Run (1);
         declare
            N : Natural := 0;
         begin
            for I in 1 .. Members loop
               if Stretch_Of (I) > 0 then
                  N := N + 1;
                  Each_Its_Own := Each_Its_Own
                    and then (for all J in 1 .. Members => J = I or else Stretch_Of (J) /= Stretch_Of (I));
               end if;
            end loop;
            Most := Natural'Max (Most, N);
         end;
         if Paths_To_Lay = 0 then
            Done_At := S;
            exit;
         end if;
      end loop;
      Check (Most = 3 and then Each_Its_Own and then Done_At > 0,
             "six with nothing else to do: three lay it, a stretch each and no two on one; the other three stand by"
             & " (laid after" & Done_At'Image & " game minutes)");
   end;

   --  with jobs: its stretch laid, a serf goes back to its own work
   Set_Up (With_Stockpile => True, With_Labour => True, With_Field => True);
   declare
      Laid : Natural;
      Most, Most_Laid : Natural := 0;
      Back_At_Work, Was_Laying : array (1 .. 6) of Boolean := [others => False];
      Layers : Natural := 0;
      Done_At : Natural := 0;
   begin
      Build_Paths_Now;
      for I in 1 .. 6 loop
         Set_Job (I, Gatherer);
      end loop;
      Run (30);
      Lay_Path ((3.0, 60.0, Ground_M), (61.0, 60.0, Ground_M), Laid);
      for S in 1 .. 900 loop
         Run (1);
         declare
            N : Natural := 0;
         begin
            for I in 1 .. Members loop
               if Stretch_Of (I) > 0 then
                  N := N + 1;
                  Was_Laying (I) := True;
                  Most_Laid := Natural'Max (Most_Laid, Laid_By (I));
               elsif Was_Laying (I) and then Paths_To_Lay > 0 and then Carried (I) > 0 then
                  Back_At_Work (I) := True;          --  (berries in its hands while there is path still to lay)
               end if;
            end loop;
            Most := Natural'Max (Most, N);
         end;
         if Paths_To_Lay = 0 then
            Done_At := S;
            exit;
         end if;
      end loop;
      for I in 1 .. 6 loop
         Layers := Layers + (if Was_Laying (I) then 1 else 0);
      end loop;
      Check (Most = 2 and then Done_At > 0,
             "six gatherers and 58 m to lay: two at a time, a stretch each (laid after" & Done_At'Image
             & " game minutes)");
      Check (Most_Laid in 19 .. 20 and then (for some I in 1 .. 6 => Back_At_Work (I)),
             "its stretch laid, a gatherer is back at the bushes while there is path still to lay: nobody lays more"
             & " than its 20 m in one turn (" & Img (Most_Laid) & " at the most;" & Layers'Image
             & " of them laid some)");
   end;

   --  short stretches: on to the next till it has laid 20 m; what cannot be got to pins nobody
   Set_Up (With_Stockpile => False, With_Labour => True);
   declare
      Laid : Natural;
      Most_Laid, Stretches_Seen : Natural := 0;
      Last_K : Natural := 0;
      Kept_Count, Others_Laid : Boolean := False;
      Held, Stuck : Natural := 0;
   begin
      Build_Paths_Now;
      Set_Extra_Hands (1);
      for I in 2 .. 6 loop
         Set_Job (I, Hunter);                             --  (a job each, and no place for them)
      end loop;
      for K in 0 .. 7 loop                                --  eight clicks, 5 m each
         Lay_Path ((10.0 + 5.0 * Float (K), 56.0, Ground_M), (15.0 + 5.0 * Float (K), 56.0, Ground_M), Laid);
      end loop;
      for S in 1 .. 600 loop
         Run (1);
         if Stretch_Of (1) > 0 then
            if Stretch_Of (1) /= Last_K then
               Stretches_Seen := Stretches_Seen + 1;
               Kept_Count := Kept_Count or else (Last_K > 0 and then Laid_By (1) >= 5);
               Last_K := Stretch_Of (1);
            end if;
            Most_Laid := Natural'Max (Most_Laid, Laid_By (1));
         end if;
         Others_Laid := Others_Laid or else (for some I in 2 .. 6 => Stretch_Of (I) > 0);
         exit when Paths_To_Lay = 0;
      end loop;
      Check (Paths_To_Lay = 0 and then Stretches_Seen = 8 and then Kept_Count and then Most_Laid in 19 .. 20
             and then not Others_Laid,
             "eight clicks of 5 m, one serf: after a short stretch it goes on to the next, counting on, till it has"
             & " laid 20 m (" & Img (Most_Laid) & " counted to it at the most); then its turn is done");
      --  a path whose far end is up on a ledge nobody can climb
      Fill (30.0, 40.0, 40.0, 46.0, Ground_Row - 1, Ground_Row + 2, Dirt);
      Fill (30.0, 40.0, 40.0, 46.0, Ground_Row + 3, Ground_Row + 3, Grass);
      Changed_World;
      Lay_Path ((18.0, 43.0, Ground_M), (38.0, 43.0, Ground_M), Laid);
      for S in 1 .. 400 loop
         Run (1);
         if S > 200 then
            for I in 1 .. Members loop
               Held := Held + (if Stretch_Of (I) > 0 then 1 else 0);
               Stuck := Stuck + (if Extra_Now (I) then 1 else 0);
            end loop;
         end if;
      end loop;
      Check (Paths_To_Lay in 7 .. 9 and then Held = 0 and then Stuck = 0 and then At_Extra = 0
             and then Get (B (25.0), B (43.0), Ground_Row - 1) = Footpath,
             "a path that ends up on a ledge: what can be got to is laid, the " & Img (Paths_To_Lay)
             & " m that cannot stay planned, and nobody is held at them or keeps the stretch");
   end;

   --  the older way: several to a stretch, a metre at a time
   Set_Up (With_Stockpile => False, With_Labour => True);
   declare
      Most : Natural := 0;
      Ok : Boolean;
   begin
      Set_Stretches (False);
      Set_Extra_Hands (Max_Members);
      for S in 1 .. 200 loop
         Run (1);
         declare
            N : Natural := 0;
         begin
            for I in 1 .. Members loop
               N := N + (if Status (I) = "laying the path" then 1 else 0);
            end loop;
            Most := Natural'Max (Most, N);
         end;
         exit when Paths_To_Lay = 0;
      end loop;
      Check (Most >= 3 and then Paths_To_Lay = 0 and then not Stretches,
             "(with stretches off and every hand free, the band lays it a metre each and " & Img (Most)
             & " at once, as it did)");
      declare
         Data : constant Bytes := Save;
      begin
         Set_Stretches (True);
         Load (Data, Ok);
         Check (Ok and then not Stretches and then Save = Data, "(the switch is saved with the colony)");
      end;
   end;

   ------------------------------------------------------------------ extra tasks: only so many hands
   Put_Line ("extra tasks: only so many hands at once:");
   Set_Up (With_Trees => True, With_Porter_Ground => True, With_Labour => True);
   Hours := 16.0 * 24.0 + 7.0;
   declare
      Ok : Boolean;
      Most, Most_Told, Cook_Extra : Natural := 0;
      Cook_Beside_Two : Boolean := False;
      Built_At, Done_At : Natural := 0;
   begin
      Check (Extra_Hands = 2, "a third of the band may be at them at once: two of six");
      Set_Extra_Hands (4);
      Check (Extra_Hands = 4, "or the number set");
      Set_Extra_Hands (0);
      Zone_Camp ((44.0, 26.0, Ground_M), Ok);
      Set_Job (1, Gatherer);
      Set_Job (2, Gatherer);
      Set_Job (3, Forester);
      Set_Job (4, Porter);
      Set_Job (5, Gatherer);
      Set_Job (6, Cook);
      for S in 1 .. 3_000 loop
         Run (1);
         declare
            N : Natural := 0;
         begin
            for I in 1 .. 5 loop
               N := N + (if Extra_Now (I) then 1 else 0);
            end loop;
            if Extra_Now (6) and then not Camp_State.Built and then Status (6) /= "laying the path"
              and then Status (6) /= "going to lay the path"
            then
               Cook_Extra := Cook_Extra + 1;
               Cook_Beside_Two := Cook_Beside_Two or else N = 2;
            elsif Extra_Now (6) and then Ada.Strings.Fixed.Index (Status (6), "the path") > 0 then
               N := N + 1;                          --  at a path the cook is a hand like any other
            end if;
            Most := Natural'Max (Most, N);
            Most_Told := Natural'Max (Most_Told, At_Extra);
         end;
         if Camp_State.Built and then Built_At = 0 then
            Built_At := S;
         end if;
         if Built_At > 0 and then Paths_To_Lay = 0 and then Done_At = 0 then
            Done_At := S;
         end if;
         exit when Done_At > 0 and then Camp_State.Seats = Seat_Logs;
      end loop;
      Check (Most = 2 and then Most_Told = 2,
             "with a job each, never more than two of them at the camp's building or the path at once ("
             & Img (Most) & " at most, on every one of" & Done_At'Image & " game minutes)");
      Check (Cook_Extra > 0 and then Cook_Beside_Two,
             "the cook builds its own camp beside them: it neither waits for a place nor takes one");
      Check (Built_At > 0 and then Done_At > 0 and then Camp_State.Built and then Paths_To_Lay = 0,
             "the hearth stands after" & Built_At'Image & " game minutes and the path is laid after" & Done_At'Image
             & ": the rest went on with their work meanwhile (" & Img (Stored (Berries)) & " berries,"
             & Stored (Wood)'Image & " logs in store)");
   end;

   --  those with no job never wait; while they are enough, nobody leaves a job
   Set_Up (With_Trees => True, With_Porter_Ground => True, With_Labour => True);
   Hours := 16.0 * 24.0 + 7.0;
   declare
      Ok : Boolean;
      Most_Idle : Natural := 0;
      Worker_Left : Boolean := False;
   begin
      Zone_Camp ((44.0, 26.0, Ground_M), Ok);
      Set_Job (1, Gatherer);
      Set_Job (2, Gatherer);
      for S in 1 .. 1_500 loop
         Run (1);
         declare
            N : Natural := 0;
         begin
            for I in 3 .. 6 loop
               N := N + (if Extra_Now (I) then 1 else 0);
            end loop;
            Most_Idle := Natural'Max (Most_Idle, N);
            for I in 1 .. 2 loop
               if Extra_Now (I) then
                  Worker_Left := True;
               end if;
            end loop;
         end;
         exit when Camp_State.Built and then Paths_To_Lay = 0;
      end loop;
      Check (Most_Idle = 4 and then Camp_State.Built and then Paths_To_Lay = 0,
             "four with no job are all at it at once: they wait for no place");
      Check (not Worker_Left and then Stored (Berries) > 0,
             "and while they are enough the two gatherers never leave their bushes (" & Img (Stored (Berries))
             & " berries in store)");
   end;

   --  everyone, as it was
   Set_Up (With_Trees => True, With_Porter_Ground => True, With_Labour => True);
   Hours := 16.0 * 24.0 + 7.0;
   declare
      Ok : Boolean;
      Most : Natural := 0;
   begin
      Set_Extra_Hands (Max_Members);
      Zone_Camp ((44.0, 26.0, Ground_M), Ok);
      for I in 1 .. 5 loop
         Set_Job (I, Gatherer);
      end loop;
      Set_Job (6, Cook);
      for S in 1 .. 60 loop
         Run (1);
         Most := Natural'Max (Most, At_Extra);
      end loop;
      Check (Most = 5 and then Extra_Hands = Max_Members,
             "(with the limit set to everyone, all five turn to the camp before their jobs, as they did)");
      declare
         Data : constant Bytes := Save;
      begin
         Set_Extra_Hands (0);
         Load (Data, Ok);
         Check (Ok and then Extra_Hands = Max_Members and then Save = Data, "(the limit set is saved with the colony)");
      end;
   end;

   --  through a night: a place is never held by someone asleep, and never more than two at once
   Set_Up (With_Needs => True, With_Field => True, With_Labour => True);
   Hours := 16.0 * 24.0 + 17.0;
   declare
      Laid, Placed : Natural;
      Most_Told, Most_Seen, At_Two, Night_Held : Natural := 0;
      Asleep_At_Two : Boolean := False;
      Done_H : Long_Float := 0.0;
   begin
      Build_Paths_Now;
      Supply (Berries, 600, Placed);
      for I in 1 .. 6 loop
         Set_Job (I, Gatherer);
      end loop;
      for K in 0 .. 1 loop
         Lay_Path ((3.0, 58.5 + 2.0 * Float (K), Ground_M), (61.0, 58.5 + 2.0 * Float (K), Ground_M), Laid);
      end loop;
      --  a twentieth of a second at a time (a step or two of the colony's), nineteen game hours
      for T in 1 .. 19 * 60 * 20 loop
         Hours := Hours + 0.05 / 60.0;
         Advance (0.05, Hours);
         declare
            N : Natural := 0;
            H : constant Long_Float := Hours - 24.0 * Long_Float'Floor (Hours / 24.0);
         begin
            for I in 1 .. Members loop
               N := N + (if Extra_Now (I) then 1 else 0);
               if H >= 1.0 and then H < 4.0 and then Stretch_Of (I) > 0 then
                  Night_Held := Night_Held + 1;
               end if;
            end loop;
            Most_Seen := Natural'Max (Most_Seen, N);
            Most_Told := Natural'Max (Most_Told, At_Extra);
            if H >= 2.0 and then H < 2.001 then
               At_Two := At_Extra;
               Asleep_At_Two := (for all I in 1 .. Members => Status (I) = "asleep");
            end if;
         end;
         if Paths_To_Lay = 0 and then Done_H = 0.0 then
            Done_H := Hours;
         end if;
      end loop;
      Check (Most_Told = 2 and then Most_Seen = 2,
             "116 m of path planned at five in the evening, six gatherers: never more than two at it, looked at"
             & " every twentieth of a second through nineteen game hours");
      Check (Asleep_At_Two and then At_Two = 0 and then Night_Held = 0,
             "at two in the morning all are asleep and none holds a place or a stretch");
      Check (Done_H > 16.0 * 24.0 + 24.0 + 5.0 and then Paths_To_Lay = 0,
             "they take it up again in the morning: laid by "
             & Img (Float (Done_H - 17.0 * 24.0), 1) & " h the next day (" & Img (Stored (Berries))
             & " berries in store)");
   end;

   ------------------------------------------------------------------ the fire, tended by hand
   Put_Line ("the fire: eight hours of burning, three of dying down:");
   Set_Up (With_Needs => True, With_Labour => True);
   Hours := 16.0 * 24.0 + 7.0;
   declare
      Ok : Boolean;
      C  : Camp_View;
   begin
      Zone_Camp ((30.0, 24.0, Ground_M), Ok);
      Build_Camp_Now;
      Stoke (Float (Log_Hours));                    --  a log's worth on it, and nobody to tend it
      Run (420);
      C := Camp_State;
      Check (C.Burning and then not C.Dying and then abs (C.Fuel_H - 1.0) < 0.01 and then C.Heat = 1.0,
             "seven hours on it burns as well as ever, an hour of wood left on it");
      Run (30);
      C := Camp_State;
      Check (C.Burning and then C.Heat < 0.75 and then C.Heat > 0.7,
             "through its last hour its flames sink (" & Img (100.0 * C.Heat, 0) & " % with half an hour left)");
      Run (31);
      C := Camp_State;
      Check (not C.Burning and then C.Dying and then abs (C.Ember_H - 3.0) < 0.05
             and then abs (C.Heat - Float (Ember_Heat)) < 0.01,
             "after eight hours it is burnt out and dying down: three hours of embers ahead of it");
      Run (90);
      C := Camp_State;
      Check (C.Dying and then abs (C.Ember_H - 1.5) < 0.05 and then C.Heat < 0.25 and then C.Heat > 0.2,
             "an hour and a half on it is half way down (" & Img (100.0 * C.Heat, 0) & " %)");
      Run (91);
      C := Camp_State;
      Check (not C.Burning and then not C.Dying and then C.Heat = 0.0 and then C.Burnt = 0,
             "and three hours after it burnt out it is out; nothing went on it by itself");
      Stoke (0.5);
      Run (31);
      Stoke (2.0);
      C := Camp_State;
      Check (C.Burning and then not C.Dying and then abs (C.Fuel_H - 2.0) < 0.01,
             "wood on a fire that is dying down and it is away again");
      Set_Labour (False);
      Run (121);
      C := Camp_State;
      Check (not C.Burning and then not C.Dying,
             "(with the camp's labour off a fire that burns out is out: no dying down)");
   end;

   Put_Line ("the fire: the cook stokes it, for the pot and for the night:");
   Set_Up (With_Needs => True, With_Trees => True, With_Labour => True);
   Hours := 16.0 * 24.0 + 7.0;
   declare
      Ok : Boolean;
      Placed : Natural;
      Saw_Stoke : Boolean := False;
      Lit_At : Natural := 0;
      C : Camp_View;
   begin
      Zone_Camp ((30.0, 24.0, Ground_M), Ok);
      Build_Camp_Now;
      Supply (Wood, 10, Placed);
      Supply (Meat, 8, Placed);
      Supply (Berries, 60, Placed);
      Set_Job (1, Cook);
      for S in 1 .. 300 loop
         Run (1);
         if Camp_State.Burning and then Lit_At = 0 then
            Lit_At := S;
            C := Camp_State;
         end if;
      end loop;
      Check (Lit_At > 0 and then C.Burnt = 1 and then C.Fuel_H > 7.9 and then C.Fuel_H <= Float (Log_Hours),
             "with a pot to cook the cook puts a log on the fire: it burns eight hours (lit after"
             & Lit_At'Image & " s, " & Img (C.Fuel_H, 1) & " h on it)");
      Check (Camp_State.Stew > 0 and then Camp_State.Burnt = 1,
             "and the stew is cooked on that one log (" & Camp_State.Stew'Image & " points)");
      --  on to the evening: by bedtime there is enough on it to last till waking
      loop
         Run (5);
         for I in 1 .. Members loop
            if Status (I) in "stoking the fire" | "going to stoke the fire" | "putting a log on the fire" then
               Saw_Stoke := True;
            end if;
         end loop;
         exit when Hour_Now (Hours) >= 21.75;
      end loop;
      C := Camp_State;
      Check (Saw_Stoke and then C.Burning and then C.Fuel_H + Float (Die_Down_Hours) >= 24.0 - 21.75 + Float (Wake_Hour),
             "before bed the cook stokes it for the night: " & Img (C.Fuel_H, 1) & " h on it at a quarter to ten,"
             & C.Burnt'Image & " logs burnt since seven");
      loop
         Run (10);
         exit when Hour_Now (Hours) >= 5.0 and then Hour_Now (Hours) < 6.0;
      end loop;
      C := Camp_State;
      Check ((C.Burning or else C.Dying) and then C.Burnt <= 3,
             "at five in the morning it still burns, or glows to be restoked ("
             & (if C.Burning then "burning, " & Img (C.Fuel_H, 1) & " h" else "embers, " & Img (C.Ember_H, 1) & " h")
             & ";" & C.Burnt'Image & " logs in the day and night)");
      --  a save taken with the fire dying down comes back the same
      loop
         Run (10);
         exit when Camp_State.Dying or else Hour_Now (Hours) >= 20.0;
      end loop;
      declare
         Data : constant Bytes := Save;
         Ok2  : Boolean;
      begin
         Load (Data, Ok2);
         Check (Ok2 and then Save = Data and then Labour,
                "a save taken " & (if Camp_State.Dying then "with the fire dying down" else "later")
                & " loads back to the same bytes");
      end;
   end;

   Put_Line ("the fire: embers warm a winter night:");
   Set_Up (With_Needs => True, With_Bushes => False, With_Labour => True);
   Hours := 50.0 * 24.0 + 20.5;
   declare
      Ok : Boolean;
      Cold_N, Asleep_N : Natural := 0;
   begin
      Zone_Camp ((30.0, 24.0, Ground_M), Ok);
      Stoke (4.5);                                   --  burnt out at one, embers till four
      loop
         Run (10);
         exit when Hour_Now (Hours) >= 2.0 and then Hour_Now (Hours) < 3.0;
      end loop;
      for I in 1 .. Members loop
         Cold_N := Cold_N + (if Cold (I) then 1 else 0);
         Asleep_N := Asleep_N + (if Asleep (I) then 1 else 0);
      end loop;
      Check (Camp_State.Dying and then Asleep_N = Members and then Cold_N = 0,
             "at two the fire has burnt out and is dying down, and nobody asleep round it is cold");
      loop
         Run (10);
         exit when Hour_Now (Hours) >= 4.5;
      end loop;
      Cold_N := 0;
      for I in 1 .. Members loop
         Cold_N := Cold_N + (if Cold (I) then 1 else 0);
      end loop;
      Check (not Camp_State.Dying and then not Camp_State.Burning and then Cold_N = Members,
             "at half past four it is out, and they are cold");
   end;

   Put_Line ("the fire: a winter night with wood and a cook:");
   Set_Up (With_Needs => True, With_Bushes => False, With_Labour => True);
   Hours := 50.0 * 24.0 + 7.0;
   declare
      Ok : Boolean;
      Placed : Natural;
      Cold_N, Asleep_N, Cold_Ever : Natural := 0;
      Out_Ever : Boolean := False;
   begin
      Zone_Camp ((30.0, 24.0, Ground_M), Ok);
      Build_Camp_Now;
      Supply (Wood, 20, Placed);
      Supply (Meat, 20, Placed);
      Supply (Grain, 120, Placed);
      Set_Job (1, Cook);
      Run (120);                                     --  two hours to get it lit
      loop
         Run (10);
         if not (Camp_State.Burning or else Camp_State.Dying) then
            Out_Ever := True;
         end if;
         for I in 1 .. Members loop
            Cold_Ever := Cold_Ever + (if Cold (I) then 1 else 0);
         end loop;
         exit when Hour_Now (Hours) >= 1.0 and then Hour_Now (Hours) < 2.0;
      end loop;
      for I in 1 .. Members loop
         Cold_N := Cold_N + (if Cold (I) then 1 else 0);
         Asleep_N := Asleep_N + (if Asleep (I) then 1 else 0);
      end loop;
      Put_Line ("    at one in the morning:" & Asleep_N'Image & " asleep," & Cold_N'Image & " cold; "
                & Img (Camp_State.Burnt) & " logs burnt since seven, " & Img (Camp_State.Logs) & " stacked");
      Check (Asleep_N = Members and then Cold_N = 0 and then Camp_State.Burning,
             "the fire burns through the night and nobody is cold");
      loop
         Run (10);
         if not (Camp_State.Burning or else Camp_State.Dying) then
            Out_Ever := True;
         end if;
         for I in 1 .. Members loop
            Cold_Ever := Cold_Ever + (if Cold (I) then 1 else 0);
         end loop;
         exit when Hour_Now (Hours) >= 7.0 and then Hour_Now (Hours) < 8.0;
      end loop;
      Check (not Out_Ever and then Cold_Ever = 0 and then Camp_State.Burnt in 2 .. 4,
             "it is kept in a whole winter day on three logs or so (" & Img (Camp_State.Burnt)
             & "), never out, nobody cold at any hour");
   end;

   ------------------------------------------------------------------ zones: their ground
   Put_Line ("zones: their ground (fill, snap, terminate):");
   Set_Up;
   declare
      Cells, Laid : Natural;
      Ok : Boolean;
      --  the way of a path from (44, 24) to (56, 30), and how far across it a point lies from its middle
      Ex : constant Float := 12.0 / Sqrt (180.0);
      Ey : constant Float := 6.0 / Sqrt (180.0);
      function Along (X, Y : Float) return Float is (X * Ex + Y * Ey);
      function Across (X, Y : Float) return Float is ((Y - 24.0) * Ex - (X - 44.0) * Ey);

      --  no block column is a zone's and a path's (no footpath was laid on zoned ground, no ground a
      --  path lies on was zoned), and the zones' ground is what the ground says is zoned
      function Sound return Boolean is
         Zoned, Sum : Natural := 0;
      begin
         for X in 0 .. W_B - 1 loop
            for Y in 0 .. W_B - 1 loop
               declare
                  Px : constant Float := (Float (X) + 0.5) * 0.25;
                  Py : constant Float := (Float (Y) + 0.5) * 0.25;
               begin
                  if Zone_On (Px, Py) /= 0 then
                     Zoned := Zoned + 1;
                     if On_Path (Px, Py) or else Get (X, Y, Ground_Row - 1) = Footpath then
                        return False;
                     end if;
                  end if;
               end;
            end loop;
         end loop;
         for Z in 1 .. Zone_Count loop
            Sum := Sum + Zone_At (Z).Blocks;
         end loop;
         return Sum = Zoned;
      end Sound;
   begin
      Check (Zone_At (1).Blocks = 128 and then Zone_Runs (1) = 8 and then Zone_At (1).Turn = 0.0
             and then Zone_At (1).Along = 4.0 and then Zone_At (1).Across = 2.0
             and then Zone_Top (22.0, 16.0) = Ground_M and then Zone_Top (22.0, 14.0) < 0.0,
             "a zone is its ground: 8 square metres in 8 strips of block columns, lying east and north");
      Set (B (31.0), B (15.5), Ground_Row, Tall_Grass);
      declare
         P : constant Lot_Plan := Plan_Stockpile (30.0, 15.0, 33.0, 17.0);
      begin
         Check (P.Ok and then P.Cells = 6 and then P.Blocks = 96 and then Planned_Runs = 8 and then Zone_Count = 1
                and then Cell_Count = 8 and then Get (B (31.0), B (15.5), Ground_Row) = Tall_Grass,
                "a plan says what a zoning would take (6 places, 6 square metres) and changes nothing");
         Zone_Stockpile (30.0, 15.0, 33.0, 17.0, Cells);
         Check (Cells = P.Cells and then Zone_At (2).Blocks = P.Blocks and then Zone_Runs (2) = 8
                and then Get (B (31.0), B (15.5), Ground_Row) = Air,
                "and the zoning takes just that");
      end;
      --  a second path whose edge is not on a whole metre: 29.75 to 30.75
      Lay_Path ((20.0, 30.25, Ground_M), (40.0, 30.25, Ground_M), Laid);
      Zone_Stockpile (30.0, 27.0, 34.0, 29.0, Cells);
      Check (Cells = 8 and then Zone_On (32.0, 29.6) = 3 and then Zone_On (32.0, 29.8) = 0 and then On_Path (32.0, 29.8)
             and then Zone_At (3).Blocks = 176 and then Zone_At (3).Across = 2.75,
             "snap: a lot three quarters of a metre short of a path is drawn out to its edge (" & Img (Cells)
             & " places," & Zone_At (3).Blocks'Image & " columns)");
      Zone_Stockpile (36.0, 25.0, 39.0, 28.0, Cells);
      Check (Cells = 0 and then Zone_Count = 3
             and then Stockpile_Refusal = "a stockpile has to come within a metre of a path",
             "one a metre and three quarters short is refused: '" & Stockpile_Refusal & "'");
      Zone_Stockpile (36.0, 14.0, 39.0, 21.0, Cells);
      Check (Cells = 9 and then Zone_On (37.0, 16.0) = 4 and then Zone_On (37.0, 19.0) = 0
             and then Zone_On (37.0, 17.5) = 0 and then Zone_At (4).Across = 3.0,
             "terminate: a lot drawn across a path stops at it, on the side it was begun on (" & Img (Cells) & " places)");
      Zone_Stockpile (36.0, 21.0, 39.0, 14.0, Cells);
      Check (Cells = 9 and then Zone_On (37.0, 19.0) = 5 and then Zone_On (37.0, 16.0) = 4,
             "and one begun on the far side takes that side");
      --  a path at an angle, and a lot beside it
      Lay_Path ((44.0, 24.0, Ground_M), (56.0, 30.0, Ground_M), Laid);
      Zone_Stockpile (48.0, 24.5, 53.0, 23.0, Cells);
      declare
         V : constant Zone_View := Zone_At (Zone_Count);
         Filled, On_It : Boolean := True;
      begin
         for X in B (40.0) .. B (62.0) loop
            for Y in B (16.0) .. B (34.0) loop
               declare
                  Px : constant Float := (Float (X) + 0.5) * 0.25;
                  Py : constant Float := (Float (Y) + 0.5) * 0.25;
               begin
                  if Along (Px, Py) > 53.3 and then Along (Px, Py) < 57.7 and then Across (Px, Py) < -0.51
                    and then Across (Px, Py) > -5.2 and then Zone_On (Px, Py) /= 6
                  then
                     Filled := False;                --  a gap between the lot and the path's edge
                  end if;
                  if abs Across (Px, Py) < 0.49 and then Zone_On (Px, Py) /= 0 then
                     On_It := False;
                  end if;
               end;
            end loop;
         end loop;
         Check (Cells = 25 and then Zone_Count = 6 and then abs (V.Turn - 0.46365) < 0.0001
                and then Cell_At (Cell_Count).Turn = V.Turn and then V.Along in 5.0 .. 5.5 and then V.Across in 5.2 .. 5.8,
                "a lot beside a path at an angle lies along it: turned" & Integer (V.Turn * 180.0 / 3.14159)'Image
                & " degrees," & Cells'Image & " places in rows along the path, " & Img (V.Along, 1) & " x "
                & Img (V.Across, 1) & " m");
         Check (Filled and then On_It,
                "its ground is filled right up to the path's edge all along it, and none of it is on the path");
      end;
      declare
         N0 : constant Natural := Path_Count;
      begin
         Lay_Path ((23.0, 10.0, Ground_M), (23.0, 16.5, Ground_M), Laid);
         Check (Laid = 0 and then Path_Count = N0 and then Path_Refusal = "a zone is in the way: paths go round zones"
                and then Get (B (23.0), B (12.0), Ground_Row - 1) = Grass,
                "a path whose line runs through a zone is refused whole: '" & Path_Refusal & "'");
         Lay_Path ((25.3, 10.0, Ground_M), (25.3, 16.9, Ground_M), Laid);
         Check (Laid > 0 and then Path_Count = N0 + 1 and then Zone_On (24.9, 16.0) = 1
                and then Get (B (24.9), B (16.0), Ground_Row - 1) = Grass
                and then Get (B (25.1), B (16.0), Ground_Row - 1) = Footpath,
                "one that only brushes a zone is laid beside it, and the zone keeps its ground");
      end;
      Check (Sound, "no block column is in a zone and a path, and each zone's ground is its own");
      Zone_Camp ((30.0, 20.5, Ground_M), Ok);
      Check (not Ok and then Camp_Refusal = "a path runs too near the fire (keep it 3 m off)",
             "a camp with its fire two and a half metres from a path is refused: '" & Camp_Refusal & "'");
      Zone_Camp ((30.0, 22.0, Ground_M), Ok);
      Check (Ok and then Zone_On (30.0, 18.1) = Camp_Zone and then Zone_On (30.0, 17.9) = 0
             and then Zone_At (Camp_Zone).Across = 7.5 and then Camp_Turn = 0.0 and then Sound,
             "a camp whose square comes within a metre of a path is drawn out to it as well");
      declare
         Data : constant Bytes := Save;
         T6   : constant Float := Zone_At (6).Turn;
         N6   : constant Natural := Zone_Runs (6);
      begin
         Load (Data, Ok);
         Check (Ok and then Save = Data and then Zone_On (32.0, 29.6) = 3 and then Zone_At (6).Turn = T6
                and then Zone_Runs (6) = N6 and then Cell_At (Cell_Count).Turn = T6 and then Sound,
                "the zones' ground comes back from a save: the same bytes," & Data'Length'Image
                & ", the same ground, the same turn");
      end;
   end;

   Put_Line ("zones: the camp beside a path at an angle:");
   Set_Up (With_Stockpile => False, With_Bushes => False);
   declare
      Laid : Natural;
      Ok   : Boolean;
   begin
      Lay_Path ((44.0, 24.0, Ground_M), (56.0, 30.0, Ground_M), Laid);
      Zone_Camp ((51.923, 23.154, Ground_M), Ok);      --  4.3 m from the path's middle
      declare
         S1 : constant Vec3 := Seat_Log (1);
         A1 : constant Float := Arctan (S1.Y - Camp.Y, S1.X - Camp.X);
         Fw : constant Vec3 := Firewood_Place;
      begin
         Check (Ok and then abs (Camp_Turn - 0.46365) < 0.0001 and then abs (A1 - Camp_Turn) < 0.001
                and then abs (Flat (Fw, Camp) - 2.75 * Sqrt (2.0)) < 0.01
                and then Zone_On (Fw.X, Fw.Y) = Camp_Zone and then Zone_At (Camp_Zone).Turn = Camp_Turn,
                "it lies along the path: turned" & Integer (Camp_Turn * 180.0 / 3.14159)'Image
                & " degrees, its first seat and its firewood turned with it");
      end;
   end;

   --  tools/colony_v12.bin: this meadow (Set_Up with needs, trees and skills),
   --  the camp at 30 24, 8 meat, 60 berries and 3 logs supplied, a cook, two
   --  gatherers, a forester and a hunter; saved 113 s after seven on day 16:
   --  the cook fetching berries for the pot, one gatherer picking (10 in its
   --  basket), the forester felling its third tree, the hunter carrying a
   --  deer home; the wood reserve none (no limit, as it was).  Written by
   --  the version 12 code (commit ac56903).
   Put_Line ("a save from before the demand chain (version 12):");
   Set_Up (With_Needs => True, With_Trees => True, With_Skills => True);
   declare
      package SIO renames Ada.Streams.Stream_IO;
      F  : SIO.File_Type;
      Ok : Boolean;
   begin
      SIO.Open (F, SIO.In_File, "tools/colony_v12.bin");
      declare
         Data : Bytes (0 .. Natural (SIO.Size (F)) - 1);
         Felled_0 : Natural;
      begin
         Bytes'Read (SIO.Stream (F), Data);
         SIO.Close (F);
         Load (Data, Ok);
         Check (Ok and then Members = 6 and then Has_Camp and then Status (3) = "felling a tree"
                and then Status (2) = "picking berries (10)" and then Status (4) = "carrying a deer home",
                "it loads: the forester mid-chop, a gatherer picking, the hunter with its deer");
         Check (Demand_Chain and then Wood_Reserve = 20,
                "with the chain on, and the wood reserve, which was no limit, the surplus a new colony asks for");
         Felled_0 := Trees_Felled;
         Hours := 16.0 * 24.0 + 7.0 + 113.0 / 60.0;
         Run (1);
         Check (Food_Demand.Asked and then Demand_For (Wood).Asked,
                "stock is taken at its first step: food and wood are asked for");
         for S in 1 .. 120 loop
            Run (1);
            exit when Trees_Felled > Felled_0;
         end loop;
         Check (Trees_Felled = Felled_0 + 1, "and the forester brings its tree down");
         declare
            Again : constant Bytes := Save;
            Ok2 : Boolean;
         begin
            Load (Again, Ok2);
            Check (Ok2 and then Save = Again and then Natural (Again (0)) = 25,
                   "it saves as version 25 and loads back the same (" & Boolean'Image (Save = Again)
                   & Again'Length'Image & " bytes, version" & Again (0)'Image & ")");
         end;
      end;
   end;

   --  tools/colony_v13.bin: this meadow (Set_Up with needs, trees, skills
   --  and the demand chain), the camp at 30 24, 8 meat, 60 berries and 6
   --  logs supplied, a cook, two gatherers (2 and 5), a forester (3) and a
   --  hunter (4); saved 200 s after seven on day 16: the cook stirring the
   --  stew over a burning fire (1.27 h of wood on it), a gatherer picking (7
   --  in its basket), the forester carrying a log to the stockpile, the
   --  hunter butchering a deer, the other gatherer taking 30 berries to the
   --  stockpile.  Written by the version 13 code (commit bd5186a).
   Put_Line ("a save from before zones had ground of their own (version 13):");
   Set_Up (With_Needs => True, With_Trees => True, With_Skills => True, With_Demand => True);
   declare
      package SIO renames Ada.Streams.Stream_IO;
      F  : SIO.File_Type;
      Ok : Boolean;
   begin
      SIO.Open (F, SIO.In_File, "tools/colony_v13.bin");
      declare
         Data : Bytes (0 .. Natural (SIO.Size (F)) - 1);
      begin
         Bytes'Read (SIO.Stream (F), Data);
         SIO.Close (F);
         Load (Data, Ok);
         Check (Ok and then Members = 6 and then Has_Camp and then Zone_Count = 2 and then Status (1) = "stirring the stew"
                and then Status (3) = "carrying a log to the stockpile" and then Status (4) = "butchering a deer"
                and then Camp_State.Burning and then Camp_State.Built and then Labour,
                "it loads: the cook stirring over a burning fire at a camp that stands, the forester with a log,"
                & " the hunter butchering");
         Check (Zone_At (1).Blocks = 128 and then Zone_Runs (1) = 8 and then Zone_At (Camp_Zone).Blocks = 784
                and then Zone_On (30.0, 24.0) = Camp_Zone and then Zone_On (22.5, 15.5) = 1
                and then Zone_At (Camp_Zone).Along = Camp_Size_M and then Zones_Sound,
                "its zones' ground is the square metre under each cell and the camp's square");
         Hours := 16.0 * 24.0 + 7.0 + 200.0 / 60.0;
         for S in 1 .. 120 loop
            Run (1);
            exit when Camp_State.Stew > 0;
         end loop;
         Check (Camp_State.Stew > 0 and then Camp_State.In_Pot = 0, "the cook finishes its stew:" & Camp_State.Stew'Image);
         declare
            Again : constant Bytes := Save;
            Ok2 : Boolean;
         begin
            Load (Again, Ok2);
            Check (Ok2 and then Save = Again and then Natural (Again (0)) = 25 and then Again'Length > Data'Length,
                   "it saves as version 25 and loads back the same (" & Boolean'Image (Save = Again)
                   & Again'Length'Image & " bytes, version" & Again (0)'Image & ")");
         end;
      end;
   end;

   --  tools/colony_v14.bin: this meadow (Set_Up with needs, trees, the
   --  porters' ground, skills and the demand chain, the band's labour on), a
   --  second path from 44 24 to 56 30 with a stockpile beside it (48 24.5 to
   --  53 23), 60 berries and 2 logs supplied, the camp zoned at 36 36, a
   --  cook, a gatherer and a forester; saved 52 s after seven on day 16:
   --  four making the camp's ground ready (4 square metres left), two going
   --  for stone for the hearth, nothing delivered yet.  Written by the
   --  version 14 code (commit 821e38b), where a path was laid as it was
   --  marked.
   Put_Line ("a save from before paths were planned and the band looked further (version 14):");
   Set_Up (With_Needs => True, With_Trees => True, With_Porter_Ground => True, With_Skills => True,
           With_Demand => True, With_Labour => True);
   declare
      package SIO renames Ada.Streams.Stream_IO;
      F  : SIO.File_Type;
      Ok : Boolean;
      Laid : Natural;
   begin
      Build_Paths_Now;                                --  (the ground as it was then: its paths laid)
      Set_Labour (False);
      Lay_Path ((44.0, 24.0, Ground_M), (56.0, 30.0, Ground_M), Laid);
      Set_Labour (True);
      SIO.Open (F, SIO.In_File, "tools/colony_v14.bin");
      declare
         Data : Bytes (0 .. Natural (SIO.Size (F)) - 1);
         Tamping_N, Stone_N : Natural := 0;
      begin
         Bytes'Read (SIO.Stream (F), Data);
         SIO.Close (F);
         Load (Data, Ok);
         for I in 1 .. Members loop
            Tamping_N := Tamping_N + (if Status (I) = "making the camp's ground ready" then 1 else 0);
            Stone_N := Stone_N + (if Status (I) = "going for stone for the hearth" then 1 else 0);
         end loop;
         Check (Ok and then Members = 6 and then Has_Camp and then not Camp_State.Built and then Zone_Count = 3
                and then Tamping_N = 4 and then Stone_N = 2 and then abs (Zone_At (2).Turn - 0.46365) < 0.0001
                and then Labour and then Looking_M = 0.0 and then Path_Count = 2,
                "it loads: the camp being built (four at its ground, two going for stone), a stockpile turned to"
                & " its path, the band looking no further than its work");
         Hours := 16.0 * 24.0 + 7.0 + 52.0 / 60.0;
         Run (1);
         Check (Paths_To_Lay = 0, "its paths, laid when they were marked, are read from the ground as laid");
         for S in 1 .. 400 loop
            Run (1);
            exit when Camp_State.Built;
         end loop;
         Check (Camp_State.Built and then Camp_State.Stones = Hearth_Stones and then Camp_State.Ground_Left = 0,
                "and the band finishes its hearth");
         declare
            Again : constant Bytes := Save;
            Ok2 : Boolean;
         begin
            Load (Again, Ok2);
            Check (Ok2 and then Save = Again and then Natural (Again (0)) = 25 and then Again'Length > Data'Length,
                   "it saves as version 25 and loads back the same (" & Boolean'Image (Save = Again)
                   & Again'Length'Image & " bytes, version" & Again (0)'Image & ")");
         end;
      end;
   end;

   --  tools/colony_v15.bin: this meadow (Set_Up with needs, trees, the
   --  porters' ground, skills and the demand chain, the band's labour on), a
   --  second path planned from 44 24 to 56 30 with a stockpile beside it
   --  (48 24.5 to 53 23), 60 berries and 2 logs supplied, the camp zoned at
   --  36 36 and built on the spot, a cook, a gatherer and a forester; saved
   --  30 s after seven on day 16: all six laying the two paths a metre each
   --  (22 m of 34 still to lay).  Written by the version 15 code (commit
   --  694d658), where everyone turned to a path before its job and laid
   --  whichever metre was nearest.
   Put_Line ("a save from before extra tasks were limited and paths laid by the stretch (version 15):");
   Set_Up (With_Needs => True, With_Trees => True, With_Porter_Ground => True, With_Skills => True,
           With_Demand => True, With_Labour => True);
   declare
      package SIO renames Ada.Streams.Stream_IO;
      F  : SIO.File_Type;
      Ok : Boolean;
      Laid, Cells, Placed : Natural;
   begin
      --  the ground as it was then: the same start, run the older way for the same 30 s
      Set_Extra_Hands (Max_Members);
      Set_Stretches (False);
      Lay_Path ((44.0, 24.0, Ground_M), (56.0, 30.0, Ground_M), Laid);
      Zone_Stockpile (48.0, 24.5, 53.0, 23.0, Cells);
      Supply (Berries, 60, Placed);
      Supply (Wood, 2, Placed);
      Zone_Camp ((36.0, 36.0, Ground_M), Ok);
      Build_Camp_Now;
      Set_Job (1, Cook);
      Set_Job (2, Gatherer);
      Set_Job (3, Forester);
      Hours := 16.0 * 24.0 + 7.0;
      Run (30);
      SIO.Open (F, SIO.In_File, "tools/colony_v15.bin");
      declare
         Data : Bytes (0 .. Natural (SIO.Size (F)) - 1);
         Left_Was : constant Natural := Paths_To_Lay;
         At_Paths, Holding, Most_After : Natural := 0;
         One_Each : Boolean := True;
      begin
         Bytes'Read (SIO.Stream (F), Data);
         SIO.Close (F);
         Load (Data, Ok);
         for I in 1 .. Members loop
            At_Paths := At_Paths + (if Status (I) = "laying the path" or else Status (I) = "going to lay the path"
                                    then 1 else 0);
         end loop;
         Check (Ok and then Members = 6 and then Path_Count = 2 and then At_Paths = 6 and then Left_Was = 22
                and then Camp_State.Built and then Stretches and then Extra_Hands = 2 and then Looking_M = 0.0,
                "it loads: the camp standing, all six at the two planned paths, 22 m still to lay; a stretch to a"
                & " serf and two hands at most from now on");
         Run (10);
         for S in 1 .. 600 loop
            Run (1);
            Holding := 0;
            for I in 1 .. Members loop
               if Stretch_Of (I) > 0 then
                  Holding := Holding + 1;
                  One_Each := One_Each
                    and then (for all J in 1 .. Members => J = I or else Stretch_Of (J) /= Stretch_Of (I));
               end if;
            end loop;
            Most_After := Natural'Max (Most_After, Holding);
            exit when Paths_To_Lay = 0;
         end loop;
         Check (Most_After <= 2 and then One_Each and then Paths_To_Lay = 0,
                "each finishes the metre it was at; after that the two stretches are one serf's each (" & Img (Most_After)
                & " at them at most), and the paths are laid");
         declare
            Again : constant Bytes := Save;
            Ok2 : Boolean;
         begin
            Load (Again, Ok2);
            Check (Ok2 and then Save = Again and then Natural (Again (0)) = 25 and then Again'Length > Data'Length - 400,
                   "it saves as version 25 and loads back the same (" & Boolean'Image (Save = Again)
                   & Again'Length'Image & " bytes, version" & Again (0)'Image & ")");
         end;
      end;
   end;

   ------------------------------------------------------------------ the herds flee together
   Put_Line ("the herds flee together:");
   Set_Up (With_Flight => True);
   declare
      use Castle.Herds;
      type Spot_Array is array (1 .. Max_Deer) of Vec3;
      None : constant People (1 .. 0) := [others => <>];
      function Spread (H : Positive) return Float is
         M : Float := 0.0;
      begin
         for K in 1 .. Deer_Slots loop
            if Alive (K) and then Herd_Of (K) = H then
               M := Float'Max (M, Flat (Castle.Herds.Where (K), Node (H)));
            end if;
         end loop;
         return M;
      end Spread;
      --  the rows of water under deer K
      function Wet (K : Positive) return Natural is
         P  : constant Vec3 := Castle.Herds.Where (K);
         N  : Natural;
         F  : Castle.Nav.Floor_List;
         Zr : constant Integer := Integer (Float'Floor (P.Z * 4.0 + 0.5));
         Best : Integer := Integer'Last;
         W  : Natural := 0;
      begin
         Castle.Nav.Floors_At (Integer (Float'Floor (P.X / Castle.Nav.Cell_M)),
                               Integer (Float'Floor (P.Y / Castle.Nav.Cell_M)), N, F);
         for I in 1 .. N loop
            if abs (F (I).Z - Zr) < abs (Best - Zr) then
               Best := F (I).Z;
               W := F (I).Water;
            end if;
         end loop;
         return W;
      end Wet;
      --  what a run of ticks shows of the first herd's deer
      Was, Was_Dir : Spot_Array := [others => (0.0, 0.0, 0.0)];
      Moving_Was : array (1 .. Max_Deer) of Boolean := [others => False];
      Sharpest  : Float := 0.0;     --  the most a moving deer's heading turned in a tick, rad
      Toward    : Natural := 0;     --  deer-ticks spent running at the danger
      Widest    : Float := 0.0;     --  the furthest any was from the node
      Deepest   : Natural := 0;     --  the deepest water any stood in
      Walked    : array (1 .. Max_Deer) of Float := [others => 0.0];
      Ticks     : Natural := 0;     --  steps watched since it was last set to nothing,
      Set_Off   : array (1 .. Max_Deer) of Natural := [others => 0];   --  and the step each deer first ran in
      procedure Watch (Seconds : Float; Danger : Vec3; Near : People := None; Count_Walk : Boolean := False) is
      begin
         for S in 1 .. Natural (Seconds * Float (Tick_Hz)) loop
            for K in 1 .. Deer_Slots loop
               Was (K) := Castle.Herds.Where (K);
            end loop;
            Hours := Hours + Long_Float (Tick_S) / 3600.0 * 60.0;
            Castle.Herds.Step (Tick_S, Hours, Near);
            Ticks := Ticks + 1;
            for K in 1 .. Deer_Slots loop
               if Alive (K) and then Herd_Of (K) = 1 then
                  declare
                     P  : constant Vec3 := Castle.Herds.Where (K);
                     V  : constant Vec3 := (P.X - Was (K).X, P.Y - Was (K).Y, 0.0);
                     L  : constant Float := Sqrt (V.X * V.X + V.Y * V.Y);
                  begin
                     Widest := Float'Max (Widest, Flat (P, Node (1)));
                     Deepest := Natural'Max (Deepest, Wet (K));
                     if Count_Walk then
                        Walked (K) := Walked (K) + L;
                     end if;
                     if L > 0.05 then                        --  over a metre a second
                        if Set_Off (K) = 0 then
                           Set_Off (K) := Ticks;
                        end if;
                        declare
                           D : constant Vec3 := (V.X / L, V.Y / L, 0.0);
                        begin
                           if Moving_Was (K) then
                              Sharpest := Float'Max
                                (Sharpest, Arccos (Float'Max (-1.0, Float'Min (1.0, D.X * Was_Dir (K).X + D.Y * Was_Dir (K).Y))));
                           end if;
                           if Flat (P, Danger) < Flat (Was (K), Danger) - 0.1 and then Flat (P, Danger) < 20.0 then
                              Toward := Toward + 1;
                           end if;
                           Was_Dir (K) := D;
                           Moving_Was (K) := True;
                        end;
                     else
                        Moving_Was (K) := False;
                     end if;
                  end;
               end if;
            end loop;
         end loop;
      end Watch;
      K1 : Positive := 1;
   begin
      Watch (0.05, (0.0, 0.0, 0.0));
      Check (not Scatter and then Herd_Count >= 1, "the herds are placed, to flee together");
      Watch (600.0, (-99.0, -99.0, 0.0));
      Put_Line ("    calm for ten minutes: never more than " & Img (Widest, 1) & " m from the node; the sharpest turn of"
                & " a deer on the move " & Img (Sharpest / Tick_S, 1) & " rad/s");
      Check (Widest < 14.0, "calm, the deer keep round their herd's node");
      Check (Sharpest <= 1.35 + Turn_Rate * Tick_S + 0.01,
             "and none turns sharper in a step than its turn and a turn aside (" & Img (Sharpest, 2) & " rad)");
      while not (Alive (K1) and then Herd_Of (K1) = 1) loop
         K1 := K1 + 1;
      end loop;

      --  a flight
      declare
         From   : constant Vec3 := Castle.Herds.Where (K1) + (12.0, 0.0, 0.0);
         Walker : constant People := [1 => (P => From, Stalking => False, Still => False)];
         Node_0 : constant Vec3 := Node (1);
         Far_0  : array (1 .. Max_Deer) of Float := [others => 0.0];   --  each deer from the danger, as it comes
      begin
         for K in 1 .. Deer_Slots loop
            if Alive (K) and then Herd_Of (K) = 1 then
               Far_0 (K) := Flat (Castle.Herds.Where (K), From);
            end if;
         end loop;
         Sharpest := 0.0;
         Toward := 0;
         Widest := 0.0;
         Ticks := 0;
         Set_Off := [others => 0];
         Watch (0.1, From, Walker);
         Check (Panicked (1), "someone walking 12 m off startles the herd");
         Watch (12.0, From, Walker);
         --  (John, 2026-11-13: "lock them to the node and they run with the node, from the closest to
         --  the hunter in a chain reaction")
         declare
            In_Turn  : Boolean := True;     --  nearer the danger, sooner off
            Apart    : Boolean := True;     --  and each a moment after the one before
            All_Off  : Boolean := True;
            First, Last_Off : Natural := 0;
            N : Natural := 0;
         begin
            for K in 1 .. Deer_Slots loop
               if Alive (K) and then Herd_Of (K) = 1 then
                  N := N + 1;
                  All_Off := All_Off and then Set_Off (K) > 0;
                  First := (if First = 0 then Set_Off (K) else Natural'Min (First, Set_Off (K)));
                  Last_Off := Natural'Max (Last_Off, Set_Off (K));
                  for J in 1 .. Deer_Slots loop
                     if J /= K and then Alive (J) and then Herd_Of (J) = 1 and then Far_0 (J) < Far_0 (K) then
                        In_Turn := In_Turn and then Set_Off (J) < Set_Off (K);
                        Apart := Apart and then Set_Off (K) - Set_Off (J) >= 3;
                     end if;
                  end loop;
               end if;
            end loop;
            Put_Line ("    the" & N'Image & " of the herd set off in steps" & First'Image & " to" & Last_Off'Image
                      & " (a step is a twentieth of a second; a link of the chain is " & Img (Chain_S, 2) & " s)");
            Check (All_Off and then In_Turn and then Apart and then First <= 2
                   and then Last_Off - First in (N - 1) * 3 .. (N - 1) * 8,
                   "the flight goes down the herd in a chain: the deer nearest the danger at once, each next nearest"
                   & " a moment after the one before");
         end;
         Put_Line ("    the node fled " & Img (Flat (Node (1), Node_0), 1) & " m; the deer never more than "
                   & Img (Widest, 1) & " m from it, turning at most " & Img (Sharpest, 2) & " rad in a step;"
                   & Toward'Image & " deer-steps toward the danger");
         Check (Flat (Node (1), From) > Flat (Node_0, From) + 8.0, "the node flees from it");
         Check (Widest < 16.0, "and the deer run with it, not off on their own");
         Check (Toward = 0, "none of them runs back at the danger");
         Check (Sharpest <= 1.35 + Flight_Turn * Tick_S + 0.01, "and none flicks from heading to heading");
         Watch (25.0, From, Count_Walk => True);
         declare
            Most : Float := 0.0;
         begin
            for K in 1 .. Deer_Slots loop
               if Alive (K) and then Herd_Of (K) = 1 then
                  Most := Float'Max (Most, Walked (K));
               end if;
            end loop;
            Check (not Panicked (1) and then Spread (1) < 10.0 and then Most < 30.0,
                   "they settle round the node where it stopped: no trotting back to it (" & Img (Spread (1), 1)
                   & " m from it; " & Img (Most, 1) & " m the most any went in the 25 s after)");
         end;
      end;

      --  water in the way: a pool half a metre deep (a serf wades it) right
      --  across the way the herd would flee
      declare
         Nd   : constant Vec3 := Node (1);
         From : constant Vec3 := Nd + (-13.0, 0.0, 0.0);
         Walker : constant People := [1 => (P => From, Stalking => False, Still => False)];
         X0   : constant Float := Float'Min (59.0, Nd.X + 6.0);
      begin
         Fill (X0, Float'Max (1.0, Nd.Y - 14.0), X0 + 3.0, Float'Min (63.0, Nd.Y + 14.0),
               Ground_Row - 2, Ground_Row - 1, Water);
         Changed_World;
         Deepest := 0;
         Widest := 0.0;
         Watch (40.0, (-99.0, -99.0, 0.0));               --  calm beside it
         Check (Deepest = 0, "calm beside a pool, no deer sets a hoof in it");
         Watch (0.1, From, Walker);
         Watch (20.0, From, Walker);
         Check (Panicked (1) or else Flat (Node (1), Nd) > 5.0, "startled toward the pool, the herd flees");
         Watch (40.0, From);
         Put_Line ("    the pool in the way: the deepest any deer stood in" & Deepest'Image & " rows; the node is now"
                   & Natural'Image (Natural (Flat (Node (1), Nd))) & " m off");
         Check (Deepest <= Flight_Wade_B, "and none goes into it: round it, or another way");
         Check (not Panicked (1) and then Spread (1) < 12.0, "and they settle again (" & Img (Spread (1), 1) & " m)");
      end;

      --  a save mid-flight, and the switch
      declare
         A_Pos, B_Pos : Spot_Array := [others => (0.0, 0.0, 0.0)];
         Ok : Boolean;
      begin
         Scare (Castle.Herds.Where (K1), Castle.Herds.Where (K1) - (10.0, 0.0, 0.0));
         Watch (1.0, (-99.0, -99.0, 0.0));
         declare
            Data : constant Castle.Herds.Bytes := Castle.Herds.Save;
            Saved_Hours : constant Long_Float := Hours;
         begin
            Watch (30.0, (-99.0, -99.0, 0.0));
            for K in 1 .. Deer_Slots loop
               A_Pos (K) := Castle.Herds.Where (K);
            end loop;
            Set_Scatter (True);
            Castle.Herds.Load (Data, Ok);
            Hours := Saved_Hours;
            Check (Ok and then not Scatter and then Castle.Herds.Save = Data,
                   "a save taken in a flight loads, the way the herds flee with it, and saved again is the same"
                   & Data'Length'Image & " bytes");
            Watch (30.0, (-99.0, -99.0, 0.0));
            for K in 1 .. Deer_Slots loop
               B_Pos (K) := Castle.Herds.Where (K);
            end loop;
            Check (A_Pos = B_Pos, "and 30 s later every deer is just where it would have been");
         end;
      end;

      --  nowhere to go: a plank wall close round the herd, the danger inside it
      declare
         N1 : constant Vec3 := Node (1);
         R  : constant Float := 2.75;
         Stood : Spot_Array := [others => (0.0, 0.0, 0.0)];
         Most  : Float := 0.0;
      begin
         Watch (40.0, (-99.0, -99.0, 0.0));                        --  settled where they are
         Fill (N1.X - R, N1.Y - R, N1.X + R, N1.Y - R + 0.25, Ground_Row, Ground_Row + 11, Plank);
         Fill (N1.X - R, N1.Y + R - 0.25, N1.X + R, N1.Y + R, Ground_Row, Ground_Row + 11, Plank);
         Fill (N1.X - R, N1.Y - R, N1.X - R + 0.25, N1.Y + R, Ground_Row, Ground_Row + 11, Plank);
         Fill (N1.X + R - 0.25, N1.Y - R, N1.X + R, N1.Y + R, Ground_Row, Ground_Row + 11, Plank);
         Changed_World;
         for K in 1 .. Deer_Slots loop
            Stood (K) := Castle.Herds.Where (K);
         end loop;
         declare
            Walker : constant People := [1 => (P => Node (1) + (1.0, 0.0, 0.0), Stalking => False, Still => False)];
            Inside : Natural := 0;
         begin
            Ticks := 0;
            Set_Off := [others => 0];
            Watch (4.0, Node (1), Walker);
            for K in 1 .. Deer_Slots loop
               if Alive (K) and then Herd_Of (K) = 1
                 and then abs (Stood (K).X - N1.X) < R - 0.5 and then abs (Stood (K).Y - N1.Y) < R - 0.5
               then
                  Inside := Inside + 1;
                  Most := Float'Max (Most, Flat (Castle.Herds.Where (K), Stood (K)));
               end if;
            end loop;
            Put_Line ("    penned," & Inside'Image & " deer inside, someone a metre from the node for four seconds: the"
                      & " furthest any of them went " & Img (Most, 1) & " m; the herd "
                      & (if Panicked (1) then "in flight" else "not in flight"));
            Check (Inside >= 1 and then not Panicked (1) and then Most < 2.5
                   and then (for all K in 1 .. Deer_Slots =>
                               Set_Off (K) = 0 or else not Alive (K) or else Herd_Of (K) /= 1
                               or else abs (Stood (K).X - N1.X) >= R - 0.5 or else abs (Stood (K).Y - N1.Y) >= R - 0.5),
                   "with nowhere for the herd to go, it stays with its node: none bolts by itself");
         end;
      end;
   end;

   ------------------------------------------------------------------ water blocks a herd
   --  (John, 2026-11-13: "let them know that water blocks them")
   Put_Line ("the herds are told that water blocks them:");
   Set_Up (With_Flight => True);
   declare
      use Castle.Herds;
      None : constant People (1 .. 0) := [others => <>];
      Along_Y : Boolean := False;     --  the river runs north and south (else east and west)
      Lo, Hi  : Float := 0.0;         --  its two banks, metres
      Low_Side : Boolean := False;    --  the herd is on the side of lesser X (or Y)
      Have_River : Boolean := False;
      Over    : Natural := 0;         --  deer-steps on the far bank or in the river
      Wettest : Natural := 0;         --  the deepest water any deer stood in, rows
      function Across (P : Vec3) return Boolean is
         C : constant Float := (if Along_Y then P.X else P.Y);
      begin
         return (if Low_Side then C > Lo else C < Hi);
      end Across;
      function Wet (P : Vec3) return Natural is
         N  : Natural;
         F  : Castle.Nav.Floor_List;
      begin
         Castle.Nav.Floors_At (Integer (Float'Floor (P.X / Castle.Nav.Cell_M)),
                               Integer (Float'Floor (P.Y / Castle.Nav.Cell_M)), N, F);
         return (if N > 0 then F (1).Water else 0);
      end Wet;
      procedure Watch (Seconds : Float; Near : People := None) is
      begin
         for S in 1 .. Natural (Seconds * Float (Tick_Hz)) loop
            Hours := Hours + Long_Float (Tick_S) / 3600.0 * 60.0;
            Castle.Herds.Step (Tick_S, Hours, Near);
            if Have_River then
               for K in 1 .. Deer_Slots loop
                  if Alive (K) and then Herd_Of (K) = 1 then
                     Wettest := Natural'Max (Wettest, Wet (Castle.Herds.Where (K)));
                     if Across (Castle.Herds.Where (K)) then
                        Over := Over + 1;
                     end if;
                  end if;
               end loop;
            end if;
         end loop;
      end Watch;
   begin
      --  the ground a herd's ways are looked for on is ground the game keeps loaded wherever the
      --  camera is (game/castle_game.adb, Colony_R: the stacks within Integer (Ground_Reach_M / 8) + 3
      --  of the stake's, counted by stack; the reach is never less than Work_Radius_M)
      declare
         Kept_R : constant Integer := Integer (Work_Radius_M / 8.0) + 3;
         Worst  : Integer := 0;
      begin
         for Ox in 0 .. 31 loop                          --  the stake's place in its own stack, by quarter metres
            for Oy in 0 .. 31 loop
               for Dx in -14 .. 14 loop
                  for Dy in -14 .. 14 loop
                     declare
                        Sx : constant Float := Float (Ox) * 0.25 + 0.125;
                        Sy : constant Float := Float (Oy) * 0.25 + 0.125;
                        Nx : constant Float := Float'Max (0.0, Float'Max (Float (Dx) * 8.0 - Sx, Sx - Float (Dx + 1) * 8.0));
                        Ny : constant Float := Float'Max (0.0, Float'Max (Float (Dy) * 8.0 - Sy, Sy - Float (Dy + 1) * 8.0));
                     begin
                        if Nx * Nx + Ny * Ny <= Dry_Reach_M * Dry_Reach_M then
                           Worst := Integer'Max (Worst, Dx * Dx + Dy * Dy);
                        end if;
                     end;
                  end loop;
               end loop;
            end loop;
         end loop;
         Check (Worst <= Kept_R * Kept_R,
                "wherever the stake stands in its stack, every stack within " & Img (Dry_Reach_M, 0)
                & " m of it is one the game keeps loaded (the furthest" & Worst'Image & " by the squares of its steps, of"
                & Integer'Image (Kept_R * Kept_R) & " kept): a herd is answered the same looked at or not");
      end;
      Watch (0.05);
      Watch (120.0);                                     --  calm, wherever it has grazed to
      declare
         Nd : constant Vec3 := Node (1);
         --  a river half a metre deep (a serf wades it; no deer does), bank to bank across the
         --  meadow, 6 m from the node on the side with the more room; someone walks up on the other
         Mid : constant Float := (if abs (Nd.X - 32.0) >= abs (Nd.Y - 32.0) then Nd.X else Nd.Y);
         Toward : constant Float := (if Mid >= 32.0 then -1.0 else 1.0);
         From : Vec3;
         T0 : Castle.Nav.Totals_Rec;
         Node_Moved : Float;
         All_On_Bank : Boolean := True;
      begin
         Along_Y := abs (Nd.X - 32.0) >= abs (Nd.Y - 32.0);
         Low_Side := Toward > 0.0;
         Lo := (if Toward > 0.0 then Mid + 6.0 else Mid - 9.0);
         Hi := Lo + 3.0;
         if Along_Y then
            Fill (Lo, 0.0, Hi, 64.0, Ground_Row - 2, Ground_Row - 1, Water);
            From := Nd + (-13.0 * Toward, 0.0, 0.0);
         else
            Fill (0.0, Lo, 64.0, Hi, Ground_Row - 2, Ground_Row - 1, Water);
            From := Nd + (0.0, -13.0 * Toward, 0.0);
         end if;
         Changed_World;
         for K in 1 .. Deer_Slots loop
            if Alive (K) and then Herd_Of (K) = 1 and then (Across (Castle.Herds.Where (K)) or else Wet (Castle.Herds.Where (K)) > 0) then
               All_On_Bank := False;
            end if;
         end loop;
         Have_River := True;
         Check (All_On_Bank and then Castle.Nav."=" (Castle.Nav.Plan (Nd, Nd + (if Along_Y then (12.0 * Toward, 0.0, 0.0)
                                                                           else (0.0, 12.0 * Toward, 0.0))).Result,
                                                     Castle.Nav.Found),
                "a river half a metre deep right across the meadow, the herd all on one bank of it: a serf wades over");
         Castle.Nav.Prove_Dry := True;                   --  every refusal searched for whole (it raises if one can be gone)
         T0 := Castle.Nav.Totals;
         declare
            Walker : constant People := [1 => (P => From, Stalking => False, Still => False)];
         begin
            Watch (0.1, Walker);
            Watch (20.0, Walker);
         end;
         Node_Moved := Flat (Node (1), Nd);
         Watch (40.0);
         Castle.Nav.Prove_Dry := False;
         declare
            T1 : constant Castle.Nav.Totals_Rec := Castle.Nav.Totals;
         begin
            Put_Line ("    the node at " & Img (Nd.X, 1) & " " & Img (Nd.Y, 1) & ", the river "
                      & (if Along_Y then "north and south" else "east and west") & " from " & Img (Lo, 1) & " to "
                      & Img (Hi, 1) & ", someone walking up 13 m off on the other side of the herd:"
                      & Natural'Image (T1.Refused - T0.Refused) & " ways refused,"
                      & Natural'Image (T1.Proved - T0.Proved) & " of them searched for whole and not there; the node fled "
                      & Img (Node_Moved, 1) & " m");
            Check (T1.Refused > T0.Refused and then T1.Proved - T0.Proved = T1.Refused - T0.Refused
                   and then T1.Unproved = T0.Unproved,
                   "the ways over the river are refused, and each of them is truly not there dry");
            Check (T1.Spent_Plans = T0.Spent_Plans and then T1.Plan_Floors - T0.Plan_Floors < 600,
                   "and cost nothing to refuse: the herd's plans of that minute looked at"
                   & Long_Integer'Image (T1.Plan_Floors - T0.Plan_Floors) & " floors in all");
            Check (Node_Moved > 8.0 and then not Across (Node (1)),
                   "the herd flees all the same, another way: along its own bank (" & Img (Node_Moved, 1) & " m)");
            Check (Over = 0 and then Wettest = 0,
                   "and no deer of it is ever over the river, or in it");
         end;
         --  (John, 2026-11-13: "a person standing still doesn't frighten a herd")
         declare
            K1 : Positive := 1;
         begin
            while not (Alive (K1) and then Herd_Of (K1) = 1) loop
               K1 := K1 + 1;
            end loop;
            declare
               Spot : constant Vec3 :=
                 Castle.Herds.Where (K1) + (if Along_Y then (0.0, 9.0, 0.0) else (9.0, 0.0, 0.0));
               Stander : constant People := [1 => (P => Spot, Stalking => False, Still => True)];
               Walker  : constant People := [1 => (P => Spot, Stalking => False, Still => False)];
               F0 : constant Natural := Frights;
               N0 : constant Vec3 := Node (1);
            begin
               Watch (30.0, Stander);
               Check (Frights = F0 and then not Panicked (1) and then Flat (Node (1), N0) < 0.01,
                      "someone standing still 9 m from a deer for half a minute frightens nobody: the herd grazes on");
               Watch (0.1, Walker);
               Check (Frights = F0 + 1 and then Panicked (1),
                      "the moment the same one walks, the herd is off");
            end;
         end;
      end;
   end;

   ------------------------------------------------------------------ one who stands still
   --  The same through the colony's own steps: who has stood still is the
   --  colony's to say (Castle.Colony.Advance), each step, of each of the band.
   Put_Line ("one of the band who stands still frightens no herd:");
   Set_Up (With_Bushes => False, With_Flight => True);
   Run (2);
   declare
      use Castle.Herds;
      First : constant Vec3 := Node (1);                 --  where the first herd is put
      To_Stake : constant Vec3 := (Stake_P.X - First.X, Stake_P.Y - First.Y, 0.0);
      L   : constant Float := Sqrt (To_Stake.X ** 2 + To_Stake.Y ** 2);
      Bush : constant Vec3 := First + To_Stake * (9.0 / L);     --  a bush 9 m from it, on the stake's side
      R   : constant Float := 2.75;
      Near_S, Stood_S, Walked_S : Natural := 0;          --  seconds the gatherer was within Fear_M of a deer of the herd,
      Stood_F, Walked_F : Natural := 0;                  --  stood there, walked there; and the frights in each
      Was, Before : Vec3 := (0.0, 0.0, 0.0);
      function Nearest_Deer (P : Vec3) return Float is
         M : Float := Float'Last;
      begin
         for K in 1 .. Deer_Slots loop
            if Alive (K) and then Herd_Of (K) = 1 then
               M := Float'Min (M, Flat (Castle.Herds.Where (K), P));
            end if;
         end loop;
         return M;
      end Nearest_Deer;
   begin
      --  the same meadow with that bush on it, the herd penned where it stands (a herd that
      --  can flee is 30 m off by the time anyone stands by it), and a gatherer
      Set_Up (With_Bushes => False, With_Flight => True, Bush_X => Bush.X, Bush_Y => Bush.Y);
      Run (2);
      Check (Flat (Node (1), First) < 0.01 and then L > 20.0,
             "a herd " & Img (L, 0) & " m from the stake, a bush put 9 m from it");
      Fill (First.X - R, First.Y - R, First.X + R, First.Y - R + 0.25, Ground_Row, Ground_Row + 11, Plank);
      Fill (First.X - R, First.Y + R - 0.25, First.X + R, First.Y + R, Ground_Row, Ground_Row + 11, Plank);
      Fill (First.X - R, First.Y - R, First.X - R + 0.25, First.Y + R, Ground_Row, Ground_Row + 11, Plank);
      Fill (First.X + R - 0.25, First.Y - R, First.X + R, First.Y + R, Ground_Row, Ground_Row + 11, Plank);
      Changed_World;
      Set_Job (1, Gatherer);
      Was := Castle.Colony.Where (1);
      Before := Was;
      for S in 1 .. 600 loop
         declare
            F0 : constant Natural := Frights;
            Here : Vec3;
         begin
            Run (1);
            Here := Castle.Colony.Where (1);
            if Nearest_Deer (Here) <= Fear_M and then Nearest_Deer (Was) <= Fear_M then
               Near_S := Near_S + 1;
               if Flat (Here, Was) = 0.0 and then Flat (Was, Before) = 0.0 then     --  this second and the one before
                  Stood_S := Stood_S + 1;
                  Stood_F := Stood_F + Frights - F0;
               elsif Flat (Here, Was) > 0.5 then
                  Walked_S := Walked_S + 1;
                  Walked_F := Walked_F + Frights - F0;
               end if;
            end if;
            Before := Was;
            Was := Here;
         end;
         exit when Stored (Berries) > 0;
      end loop;
      Put_Line ("    the gatherer was within " & Img (Fear_M, 0) & " m of a deer of the herd for" & Near_S'Image
                & " seconds: walking for" & Walked_S'Image & " of them (the herd frightened" & Walked_F'Image
                & " times), standing at the bush for" & Stood_S'Image & " (frightened" & Stood_F'Image & " times)");
      Check (Walked_S >= 3 and then Walked_F >= 1,
             "walking up to the bush and away from it, the gatherer frightens the herd");
      Check (Stood_S >= 5 and then Stood_F = 0,
             "standing at the bush picking, it frightens nobody, second after second");
      Check (Flat (Node (1), First) < 0.01, "(the herd penned where it was the whole time)");
   end;

   ------------------------------------------------------------------ the colony's own ground
   --  The game holds the whole map (2026-11-14); the colony reads the stacks
   --  its host says are its own and nothing beyond, whatever else is loaded.
   Put_Line ("the colony's own ground:");
   declare
      function Bushes_Known return Natural is
         N : Natural := 0;
      begin
         for K in 1 .. Bush_Slots loop
            if Bush_Alive (K) then
               N := N + 1;
            end if;
         end loop;
         return N;
      end Bushes_Known;
      Near_N, Far_N : Natural;
   begin
      --  the whole meadow is loaded; a bush 45 m from the stake, five stacks off
      Set_Up (With_Bushes => False, Bush_X => 52.0, Bush_Y => 52.0);
      Set_Job (1, Gatherer);
      Run (30);
      Far_N := Bushes_Known;
      Check (Ground_Stacks = Natural'Last and then Far_N = 1,
             "told nothing of its ground, the colony reads whatever is loaded: it knows of the bush 45 m off");
      Set_Ground_Stacks (2);                             --  its own ground: the stacks within two of the stake's
      Set_Up (With_Bushes => False, Bush_X => 52.0, Bush_Y => 52.0);
      Set_Job (1, Gatherer);
      Run (30);
      Near_N := Bushes_Known;
      Check (Ground_Stacks = 2 and then Near_N = 0 and then Carrying (1) /= Berries and then Stored (Berries) = 0,
             "told its ground is the stacks within two of the stake's, it knows of no bush out there and nobody goes:"
             & " loaded ground that is not its own is no ground to it");
      Set_Ground_Stacks (6);
      Set_Up (With_Bushes => False, Bush_X => 52.0, Bush_Y => 52.0);
      Set_Job (1, Gatherer);
      Run (30);
      Check (Bushes_Known = 1, "told it reaches six stacks, it knows of it again");
      --  What the player plans is read from the ground that is held, further out than the band's own
      --  (here two stacks, for the check: a host says the reach in stacks and five more).
      Set_Ground_Stacks (2);
      Set_Up (With_Bushes => False, With_Demand => True, With_Labour => True);
      declare
         Laid, Lots, Paths_Were : Natural;
         Shown : Natural := 0;
         procedure One (X, Y, Zr : Integer) is
            pragma Unreferenced (X, Y, Zr);
         begin
            Shown := Shown + 1;
         end One;
      begin
         Build_Paths_Now;
         Paths_Were := Path_Count;
         --  bare rock where a path would go, 28 m east of the stake: nothing there to lay one on
         Fill (48.0, 30.0, 50.0, 40.0, Ground_Row - 1, Ground_Row - 1, Granite);
         Lay_Path ((49.0, 31.0, Ground_M), (49.0, 39.0, Ground_M), Laid);
         Check (Laid = 0 and then Path_Count = Paths_Were,
                "a path marked over bare rock past the band's own ground is refused as it is near the stake: what the"
                & " player plans is counted from the ground that is held");
         For_Path_Line ((44.0, 20.0, Ground_M), (44.0, 58.0, Ground_M), One'Access);
         Lay_Path ((44.0, 20.0, Ground_M), (44.0, 58.0, Ground_M), Laid);
         Check (Shown > 0 and then Laid > 0 and then Laid /= Natural (38.0 * Float (Path_Width_M) * 16.0)
                and then Paths_To_Lay > 0,
                "a path marked out there is shown (" & Img (Shown) & " columns, its stretches each) and counted by its"
                & " ground (" & Img (Laid) & " to turn; reckoned unseen it would be"
                & Natural'Image (Natural (38.0 * Float (Path_Width_M) * 16.0)) & ")");
         Build_Paths_Now;
         Lay_Path ((44.0, 58.0, Ground_M), (62.0, 58.0, Ground_M), Laid);
         Lay_Path ((62.0, 58.0, Ground_M), (62.0, 20.0, Ground_M), Laid);
         Lay_Path ((62.0, 20.0, Ground_M), (44.0, 20.0, Ground_M), Laid);
         Build_Paths_Now;
         Zone_Housing_Inside (53.0, 40.0, Lots);
         Check (Lots > 0, "and housing inside a round of paths out there is taken (room for" & Lots'Image & "): "
                & Housing_Refusal);
      end;
      --  a stockpile in the far corner, by a path: the band's ground reaches to it
      Set_Up (With_Bushes => False, With_Labour => False);
      declare
         Laid, Cells : Natural;
      begin
         Lay_Path ((40.0, 56.0, Ground_M), (62.0, 56.0, Ground_M), Laid);
         Check (Ground_Reach_M = Float (Work_Radius_M), "(the band's ground reaches its work radius)");
         Zone_Stockpile (57.0, 57.0, 62.0, 62.0, Cells);
         Check (Cells > 0 and then Ground_Reach_M > Float (Work_Radius_M) and then Ground_Reach_M < 70.0,
                "a stockpile zoned past the work radius is the band's ground from then on, as housing is ("
                & Img (Cells) & " places;" & Integer'Image (Integer (Ground_Reach_M)) & " m): " & Stockpile_Refusal);
      end;
      Set_Ground_Stacks (Natural'Last);                  --  (as the checks have it: whatever is loaded)
   end;

   --  tools/colony_v16.bin: this meadow (Set_Up with needs, trees, the
   --  porters' ground, skills, the demand chain and the band's labour), the
   --  camp zoned at 36 36 and built on the spot, a hunter and a gatherer;
   --  five seconds after seven on day 16 an arrow is loosed at the first
   --  herd from 10 m west of one of its deer, and it is saved a second
   --  later: the herd's five deer each bolting on a heading of its own, the
   --  old way.  Written by the version 16 code (commit e0667b6: the colony
   --  and the herds as on main at 2261926).
   Put_Line ("a save from before the herds fled together (version 16):");
   Set_Up (With_Needs => True, With_Trees => True, With_Porter_Ground => True, With_Skills => True,
           With_Demand => True, With_Labour => True, With_Flight => True);
   declare
      package SIO renames Ada.Streams.Stream_IO;
      F  : SIO.File_Type;
      Ok : Boolean;
   begin
      --  the ground as it was then
      Zone_Camp ((36.0, 36.0, Ground_M), Ok);
      Build_Camp_Now;
      Set_Job (1, Hunter);
      Set_Job (2, Gatherer);
      Hours := 16.0 * 24.0 + 7.0;
      Run (6);
      Castle.Herds.Set_Scatter (True);
      SIO.Open (F, SIO.In_File, "tools/colony_v16.bin");
      declare
         Data : Bytes (0 .. Natural (SIO.Size (F)) - 1);
         In_Panic_N : Natural := 0;
         Far : Float := 0.0;
      begin
         Bytes'Read (SIO.Stream (F), Data);
         SIO.Close (F);
         Load (Data, Ok);
         Set_Beds (False);        --  (a colony of before beds makes them from now on: this is about its herds,
                                  --  and whoever went off to cut its bed's straw would start them again)
         for K in 1 .. Castle.Herds.Deer_Slots loop
            if Castle.Herds.Alive (K) and then Castle.Herds.In_Panic (K) then
               In_Panic_N := In_Panic_N + 1;
            end if;
         end loop;
         Check (Ok and then Natural (Data (0)) = 16 and then Members = 6 and then Castle.Herds.Herd_Count = 2
                and then Castle.Herds.Deer_Slots = 10 and then In_Panic_N = 5 and then not Castle.Herds.Scatter,
                "it loads: two herds, ten deer, five of them bolting; the herds flee together from now on");
         Run (60);
         for K in 1 .. Castle.Herds.Deer_Slots loop
            if Castle.Herds.Alive (K) then
               Far := Float'Max (Far, Flat (Castle.Herds.Where (K), Castle.Herds.Node (Castle.Herds.Herd_Of (K))));
            end if;
         end loop;
         Check (not Castle.Herds.Panicked (1) and then Far < 12.0,
                "a minute on they have run their bolt out and are round their nodes again (" & Img (Far, 1) & " m)");
         declare
            Again : constant Bytes := Save;
            Ok2 : Boolean;
         begin
            Load (Again, Ok2);
            Check (Ok2 and then Save = Again and then Natural (Again (0)) = 25,
                   "it saves as version 25 and loads back the same (" & Again'Length'Image & " bytes)");
         end;
      end;
   end;

   ------------------------------------------------------------------ housing
   Put_Line ("housing: a zone along a path, a hovel for each, builders from the foresters:");

   Set_Up (With_Bushes => False, With_Demand => True, With_Labour => True);
   declare
      use Castle.Views;
      Laid, Lots, Placed, Would_Hold : Natural;
      Zones_Before : Natural;
      Hz : Natural;                       --  the housing zone
      function Says (I : Positive; Part : String) return Boolean is
        (Ada.Strings.Fixed.Index (Status (I), Part) > 0);
      function Has (S, Part : String) return Boolean is (Ada.Strings.Fixed.Index (S, Part) > 0);
      --  blocks of M in the box round house H: its walls, eaves and roof
      function Blocks_Of (H : Positive; M : Material) return Natural is
         V  : constant House_View := House_At (H);
         X0 : constant Float := Float'Min (Float'Min (V.Corner (1).X, V.Corner (2).X), Float'Min (V.Corner (3).X, V.Corner (4).X));
         X1 : constant Float := Float'Max (Float'Max (V.Corner (1).X, V.Corner (2).X), Float'Max (V.Corner (3).X, V.Corner (4).X));
         Y0 : constant Float := Float'Min (Float'Min (V.Corner (1).Y, V.Corner (2).Y), Float'Min (V.Corner (3).Y, V.Corner (4).Y));
         Y1 : constant Float := Float'Max (Float'Max (V.Corner (1).Y, V.Corner (2).Y), Float'Max (V.Corner (3).Y, V.Corner (4).Y));
      begin
         return Count_In (B (X0) - 2, B (Y0) - 2, B (X1) + 1, B (Y1) + 1, Ground_Row - 1, B (V.Top_Z) + 2, M);
      end Blocks_Of;
      function Carried_Of (K : Item_Kind) return Natural is
         N : Natural := 0;
      begin
         for I in 1 .. Members loop
            if Carrying (I) = K then
               N := N + Carried (I);
            end if;
         end loop;
         return N;
      end Carried_Of;
      function Row_For (Z : Positive; K : Item_Kind) return Natural is
      begin
         for R in 1 .. Demand_Rows loop
            if Demand_Row_At (R).Who = A_Zone and then Demand_Row_At (R).Zone = Z and then Demand_Row_At (R).What = K
              and then Demand_Row_At (R).Kind = Once
            then
               return Demand_Row_At (R).Amount;
            end if;
         end loop;
         return 0;
      end Row_For;
   begin
      Build_Paths_Now;                                    --  (the meadow's own path laid)
      Lay_Path ((44.0, 20.0, Ground_M), (44.0, 58.0, Ground_M), Laid);
      Build_Paths_Now;
      --  a terrace a block high across the back of the lots, and a patch of tall grass on the first
      Fill (49.0, 19.0, 60.0, 60.0, Ground_Row, Ground_Row, Dirt);
      Fill (46.0, 24.0, 47.0, 26.0, Ground_Row, Ground_Row, Tall_Grass);
      --  and a neighbouring tree's leaves hanging over where its walls and its roof will be
      Fill (46.0, 24.0, 47.0, 26.0, Ground_Row + 7, Ground_Row + 9, Leaves);
      Zones_Before := Zone_Count;
      Zone_Housing (60.0, 30.0, 62.0, 40.0, Lots);
      Check (Lots = 0 and then Zone_Count = Zones_Before and then Has (Housing_Refusal, "along a path"),
             "housing begun 16 m from any path is refused: " & Housing_Refusal);
      Zone_Housing (46.0, 70.0, 46.0, 75.0, Lots);
      Check (Lots = 0 and then Zone_Count = Zones_Before and then Housing_Refusal /= "",
             "and begun and ended past the end of its path: " & Housing_Refusal);
      declare
         P : constant Lot_Plan := Plan_Housing (44.6, 22.0, 55.0, 56.0);
      begin
         Would_Hold := P.Cells;
         Check (P.Ok and then P.Cells in 3 .. 5 and then Zone_Count = Zones_Before and then House_Count = 0
                and then Planned_Runs > 0,
                "a plan says what a zoning would hold (" & Img (P.Cells) & " hovels on 34 m of path) and changes nothing");
      end;
      Zone_Housing (44.6, 22.0, 55.0, 56.0, Lots);
      Hz := Zone_Count;
      Check (Lots = Would_Hold and then Zone_Count = Zones_Before + 1 and then Zone_At (Hz).Kind = Habitation_Zone
             and then Zone_On (50.0, 40.0) = Hz and then Zone_On (44.0, 40.0) = 0 and then On_Path (44.0, 40.0)
             and then Zone_On (44.7, 40.0) = Hz,
             "taken beside the path: one zone, room for" & Lots'Image & ", its ground up to the path's edge and no further");
      Run (3);
      declare
         V : constant House_View := House_At (1);
         Front : constant Float := Float'Min (V.Corner (1).X, V.Corner (2).X);
         Mid   : constant Vec3 := (V.Corner (1) + V.Corner (3)) * 0.5;
      begin
         Check (House_Count = 1 and then V.Owner = 0 and then V.Zone = Hz and then V.Phase = Ground and then V.Builder = 0
                and then V.Waits = For_A_Builder and then (for all I in 1 .. Members => Home_Of (I) = 0 and then not Housed (I))
                and then Homeless = 6 and then Lot_Count = Lots - 1 and then Zone_At (Hz).Lots = Lots - 1
                and then Value_Of (House (1), "For") = "whoever draws it when it stands",
                "with no forester one hovel is begun all the same, on the first of the lots laid out, nobody's until it"
                & " stands, and waits for a builder");
         Check (Front - 44.5 in 0.49 .. 1.01
                and then (for all C of V.Corner => Zone_On (C.X + 0.1 * (Mid.X - C.X), C.Y + 0.1 * (Mid.Y - C.Y)) = Hz)
                and then V.Door.Y < 30.0 and then V.Door.X < Front and then House_On (Mid.X, Mid.Y) = 1,
                "it fronts the path " & Img (Front - 44.5, 2) & " m off its edge, on the zone's ground, at the end nearest"
                & " the stake, its door toward the path");
         Check (Row_For (Hz, Wood) = V.Takes (Wood) and then Row_For (Hz, Straw) = V.Takes (Straw)
                and then V.Takes (Wood) in 3 .. 5 and then V.Takes (Straw) in 24 .. 36
                and then Zone_At (Hz).Short (Wood) = V.Takes (Wood) and then Zone_At (Hz).Homes = 1
                and then Demand_For (Wood).Once >= V.Takes (Wood),
                "what its blueprint takes is asked of the stores by its zone:" & V.Takes (Wood)'Image & " logs,"
                & V.Takes (Straw)'Image & " sheaves");
      end;
      Run (60);
      Check (House_At (1).Placed = 0 and then (for all I in 1 .. Members => not Says (I, "hovel"))
             and then Has (Value_Of (Zone (Hz), "Builders"), "none") and then Has (Value_Of (House (1), "Builder"), "none")
             and then Value_Of (House (1), "Waits for") = "a builder" and then Value_Of (Person (1), "Home") /= ""
             and then House_Count = 1,
             "a minute on nobody has touched it, no second is begun, and its sheet and its zone's say there is no builder");

      --  a forester: the builder
      Set_Job (3, Forester);
      Set_Job (4, Gatherer);
      Set_Job (5, Porter);
      declare
         Saw_Level : Boolean := False;
         V : House_View;
      begin
         for S in 1 .. 900 loop
            Run (1);
            Saw_Level := Saw_Level or else (Says (3, "ground") and then Says (3, "hovel"));
            exit when House_At (1).Phase /= Ground;
         end loop;
         V := House_At (1);
         Check (Trade_Of (3) = Builder and then Site_Of (3) = 1 and then V.Builder = 3 and then Saw_Level
                and then V.Phase /= Ground and then Trade_Of (5) = No_Trade
                and then Has (Value_Of (Person (3), "Trade"), "Builder"),
                "a forester takes it up on its own: the house's builder, and its first work is the ground");
         declare
            X0 : constant Integer := B (Float'Min (V.Corner (1).X, V.Corner (3).X) + 0.01);
            X1 : constant Integer := B (Float'Max (V.Corner (1).X, V.Corner (3).X) - 0.01);
            Y0 : constant Integer := B (Float'Min (V.Corner (1).Y, V.Corner (3).Y) + 0.01);
            Y1 : constant Integer := B (Float'Max (V.Corner (1).Y, V.Corner (3).Y) - 0.01);
         begin
            Check (X1 > B (49.0) and then Count_In (X0, Y0, X1, Y1, Ground_Row, Ground_Row + 3, Dirt) = 0
                   and then Count_In (X0, Y0, X1, Y1, Ground_Row, Ground_Row + 3, Tall_Grass) = 0
                   and then Count_In (X0 - 1, Y0 - 1, X1 + 1, Y1 + 1, Ground_Row, Ground_Row + 24, Leaves) = 0
                   and then Count_In (X0, Y0, X1, Y1, Ground_Row - 1, Ground_Row - 1, Air) = 0
                   and then Get (X1 + 1, (Y0 + Y1) / 2, Ground_Row + 1) = Air
                   and then Get (X1 + 6, (Y0 + Y1) / 2, Ground_Row) = Dirt,
                   "the pad under its walls is level: the terrace dug off it, the grass on it cut, the leaves that hung over it"
                   & " lopped, a bank left behind it");
         end;
         declare
            Saw_Beat : Boolean := False;
         begin
            for S in 1 .. 900 loop
               exit when House_At (1).Phase /= Flooring;
               Saw_Beat := Saw_Beat or else Says (3, "beating the floor of a hovel");
               Run (1);
            end loop;
            V := House_At (1);
            Check (Saw_Beat and then V.Phase = Framing and then V.Got (Wood) = 0 and then V.Got (Straw) = 0
                   and then Stored (Wood) = 0 and then V.Placed > 300
                   and then Get (B (V.Bed.X), B (V.Bed.Y), Ground_Row - 1) = Footpath,
                   "its floor is the earth inside its walls beaten hard: work alone, nothing carried (" & Img (V.Placed)
                   & " blocks)");
            Run (5);
            V := House_At (1);
            Check (V.Waits = For_Wood and then Value_Of (House (1), "Waits for") = "wood in the stores"
                   and then V.Got (Wood) = 0,
                   "then its frame: with no wood in store it waits for wood, and says so");
         end;
      end;

      --  wood: the frame
      Supply (Wood, 40, Placed);
      declare
         Counted : Boolean := Placed = 40;
         Strangers, Back, Saw_Fetch, Saw_Carry, Saved_Once : Boolean := False;
         Last : House_Phase := Ground;
         V : House_View;
         Done_At : Natural := 0;
      begin
         for S in 1 .. 9_000 loop
            Run (1);
            V := House_At (1);
            Counted := Counted and then Stored (Wood) + Carried_Of (Wood) + V.Got (Wood) = 40;
            Strangers := Strangers or else (for some I in 1 .. Members => I /= 3 and then Says (I, "hovel"));
            Back := Back or else V.Phase < Last;
            Last := V.Phase;
            Saw_Fetch := Saw_Fetch or else Says (3, "fetching wood for a hovel");
            Saw_Carry := Saw_Carry or else Says (3, "carrying a log to a hovel");
            if not Saved_Once and then V.Phase = Framing and then Says (3, "carrying a log to") then
               Saved_Once := True;
               declare
                  Snap : Snapshot;
                  Saved_Hours : constant Long_Float := Hours;
                  Data : constant Bytes := Save;
                  Ok   : Boolean;
               begin
                  Take (Snap);
                  Run (400);
                  declare
                     A : constant Bytes := Save;
                     A_Placed : constant Natural := House_At (1).Placed;
                  begin
                     Give_Back (Snap);
                     Hours := Saved_Hours;
                     Load (Data, Ok);
                     Check (Ok and then Save = Data and then Natural (Data (0)) = 25 and then House_At (1).Phase = Framing,
                            "a save taken with a log on its way to the frame loads back to the same" & Data'Length'Image
                            & " bytes");
                     declare
                        Older : Bytes := Data;
                        Ok_18, Ok_19, Ok_20, Ok_21, Ok_22, Ok_23, Ok_24 : Boolean;
                     begin
                        Older (0) := 24;       --  (and before the cart was pulled into a stockpile)
                        Load (Older, Ok_24);
                        Older (0) := 23;       --  (and before the fifth round: holes under a path filled)
                        Load (Older, Ok_23);
                        Older (0) := 22;       --  (and before the pass's fourth round: the cook's hold, the lord's cart)
                        Load (Older, Ok_22);
                        Older (0) := 21;       --  (and before each of the band chose its place by the fire)
                        Load (Older, Ok_21);
                        Older (0) := 18;       --  (housing before its ground was walled: stage 6a's two layouts)
                        Load (Older, Ok_18);
                        Older (0) := 19;
                        Load (Older, Ok_19);
                        Older (0) := 20;       --  (and before its lots were laid out beforehand)
                        Load (Older, Ok_20);
                        Load (Data, Ok);
                        Check (not Ok_18 and then not Ok_19 and then not Ok_20 and then not Ok_21 and then not Ok_22
                               and then not Ok_23 and then not Ok_24 and then Ok and then Save = Data,
                               "a blob marked version 18 to 24 is refused");
                     end;
                     Run (400);
                     Check (Save = A and then House_At (1).Placed = A_Placed and then A_Placed > V.Placed,
                            "and 400 s later the colony is just where it would have been (" & Img (A_Placed) & " of "
                            & Img (V.Blocks) & " blocks laid)");
                  end;
               end;
            end if;
            if V.Got (Wood) = V.Takes (Wood) and then Says (3, "no straw") then
               Done_At := S;
               exit;
            end if;
         end loop;
         V := House_At (1);
         Check (Saved_Once and then Saw_Fetch and then Saw_Carry and then Done_At > 0,
                "it fetches a log at a time from the stockpile and lays it (all its wood in" & Done_At'Image
                & " game minutes)");
         Check (Counted, "every log is stored, carried or built in, all the way");
         Check (not Strangers, "nobody but its builder goes to the site");
         Check (not Back and then V.Phase = Walling and then V.Got (Wood) = V.Takes (Wood) and then V.Waits = For_Straw
                and then Says (3, "no straw to build a hovel") and then V.Owner = 0,
                "the floor, then the frame; with its timber all raised its walls wait for straw, and it says so; it is"
                & " still nobody's");
         Check (Blocks_Of (1, Log) in (V.Takes (Wood) - 1) * Planks_Per_Log + 1 .. V.Takes (Wood) * Planks_Per_Log
                and then Blocks_Of (1, Plank) = 0 and then Blocks_Of (1, Thatch) = 0 and then Blocks_Of (1, Daub) = 0,
                "its frame is what its logs make:" & Natural'Image (Blocks_Of (1, Log))
                & " blocks of timber from" & V.Takes (Wood)'Image & " logs, and nothing else stands yet");
      end;

      --  straw: the daub of the walls and the gables, then the roof
      Supply (Straw, 40, Placed);
      declare
         Counted : Boolean := Placed = 40;
         Strangers  : Boolean := False;
         Saw_Daub, Saw_Thatch, Thatch_Early : Boolean := False;
         V : House_View;
         Done_At : Natural := 0;
      begin
         for S in 1 .. 8_000 loop
            Run (1);
            V := House_At (1);
            Counted := Counted and then Stored (Straw) + Carried_Of (Straw) + V.Got (Straw) = 40;
            Strangers := Strangers or else (for some I in 1 .. Members => I /= 3 and then Says (I, "hovel"));
            Saw_Daub := Saw_Daub or else Says (3, "daubing the walls of");
            Saw_Thatch := Saw_Thatch or else Says (3, "thatching ");
            Thatch_Early := Thatch_Early or else (V.Phase = Walling and then Blocks_Of (1, Thatch) > 0);
            if V.Phase = Standing then
               Done_At := S;
               exit;
            end if;
         end loop;
         Check (Done_At > 0 and then Counted and then not Strangers and then V.Got (Straw) = V.Takes (Straw)
                and then Saw_Daub and then Saw_Thatch and then not Thatch_Early
                and then Blocks_Of (1, Thatch) > 800 and then Blocks_Of (1, Daub) > 400
                and then Blocks_Of (1, Thatch) + Blocks_Of (1, Daub) in (V.Takes (Straw) - 1) * Thatch_Per_Sheaf + 1
                                                                        .. V.Takes (Straw) * Thatch_Per_Sheaf,
                "daubed and then thatched from the stockpile's straw, every sheaf accounted for:"
                & Natural'Image (Blocks_Of (1, Daub)) & " blocks of daub and" & Natural'Image (Blocks_Of (1, Thatch))
                & " of thatch from" & V.Takes (Straw)'Image & " sheaves (" & Img (Done_At) & " game minutes)");
         declare
            --  the way in, and the middle of the doorway in the front wall
            Dx : constant Float := V.Corner (4).X - V.Corner (1).X;
            Dy : constant Float := V.Corner (4).Y - V.Corner (1).Y;
            L  : constant Float := Sqrt (Dx * Dx + Dy * Dy);
            Wx : constant Integer := B (V.Door.X + 0.625 * Dx / L);
            Wy : constant Integer := B (V.Door.Y + 0.625 * Dy / L);
            Mid : constant Vec3 := (V.Corner (1) + V.Corner (3)) * 0.5;
            Posts : Boolean := True;
         begin
            for C of V.Corner loop
               for Z in Ground_Row .. Ground_Row + 8 loop
                  Posts := Posts and then Get (B (C.X + 0.02 * (Mid.X - C.X)), B (C.Y + 0.02 * (Mid.Y - C.Y)), Z) = Log;
               end loop;
            end loop;
            Check (Posts and then Get (Wx, Wy, Ground_Row) = Air and then Get (Wx, Wy, Ground_Row + 7) = Air
                   and then Get (Wx, Wy, Ground_Row + 8) = Log
                   and then Get (Wx, Wy, Ground_Row - 1) = Footpath
                   and then Get (B (V.Bed.X), B (V.Bed.Y), Ground_Row - 1) = Footpath
                   and then Get (B (V.Bed.X), B (V.Bed.Y), Ground_Row) = Air
                   and then Blocks_Of (1, Plank) = 0 and then Blocks_Of (1, Leaves) = 0
                   and then Get (B (V.Door.X), B (V.Door.Y), Ground_Row - 1) = Footpath
                   and then Get (B (Mid.X), B (Mid.Y), B (V.Top_Z) - 1) = Thatch,
                   "it stands as its blueprint has it: posts at its corners, a doorway 2 m high under a lintel, a floor of"
                   & " beaten earth and its threshold with it, thatch at the ridge, a footpath from its door");
            Check (abs (Zone_Top (V.Bed.X, V.Bed.Y) - Ground_M) < 0.01 and then Castle.Nav.Surface_Z (V.Bed.X, V.Bed.Y) = Ground_M
                   and then Castle.Nav."=" (Castle.Nav.Plan (Stake_P, V.Bed).Result, Castle.Nav.Found),
                   "the zone's ground under it is its pad, and there is a way in to where its owner will sleep");
         end;
         declare
            Won : constant Natural := House_At (1).Owner;
         begin
            Check (Won in 1 .. Members and then Housed (Won) and then Home_Of (Won) = 1 and then Homeless = 5
                   and then (for all I in 1 .. Members => I = Won or else (Home_Of (I) = 0 and then not Housed (I)))
                   and then Value_Of (Person (Won), "Home") = "a hovel of its own, drawn by lot"
                   and then Zone_At (Hz).Homes_Built = 1 and then Value_Of (House (1), "Lives here") = Name_Of (Won),
                   "the moment it stands it is drawn for by lot among the six, and is the winner's home from then on ("
                   & Name_Of (Natural'Max (1, Won)) & ", member" & Won'Image & ")");
         end;
         Run (180);                                       --  (it may be strolling when the next is begun)
         Check (House_Count = 2 and then House_At (2).Owner = 0 and then House_At (2).Phase /= Standing
                and then Site_Of (3) = 2 and then Lot_Count = Lots - 2
                and then abs ((House_At (2).Corner (1).Y + House_At (2).Corner (3).Y)
                              - (House_At (1).Corner (1).Y + House_At (1).Corner (3).Y)) / 2.0 >= 5.5,
                "and the next is begun, nobody's yet, on the lot beside it, with the same builder");
      end;
   end;

   --  the fire's logs are not building's to take
   Set_Up (With_Bushes => False, With_Demand => True, With_Labour => True);
   declare
      Laid, Lots, Placed : Natural;
      Ok : Boolean;
      Least : Natural := Natural'Last;
      Keep : Natural;
   begin
      Build_Paths_Now;
      Lay_Path ((44.0, 20.0, Ground_M), (44.0, 58.0, Ground_M), Laid);
      Build_Paths_Now;
      Zone_Camp ((30.0, 30.0, Ground_M), Ok);
      Build_Camp_Now;
      Zone_Housing (44.6, 22.0, 55.0, 56.0, Lots);
      for I in 1 .. Members loop
         Set_Job (I, (if I = 3 then Forester else Gatherer));
      end loop;
      Keep := Demand_For (Wood).A_Day;
      Supply (Wood, Seat_Logs + Keep, Placed);
      Run (900);
      Check (Ok and then Lots > 0 and then Keep > 0 and then Camp_State.Seats = Seat_Logs and then Stored (Wood) = Keep
             and then House_At (1).Got (Wood) = 0 and then House_At (1).Waits = For_Wood,
             "with only the camp's seat logs and the fire's day of wood (" & Img (Keep) & ") in store the builder lays the"
             & " seats and takes nothing for the house");
      Supply (Wood, 3, Placed);
      for S in 1 .. 600 loop
         Run (1);
         Least := Natural'Min (Least, Stored (Wood));
      end loop;
      Check (House_At (1).Got (Wood) = 3 and then Least = Keep and then Stored (Wood) = Keep,
             "three more logs and it builds with those three: the fire's are never touched");
   end;

   --  reversion: with trees and no wood stored the builder fells for its house
   Set_Up (With_Bushes => False, With_Trees => True, With_Porter_Ground => True, With_Demand => True, With_Labour => True);
   declare
      Laid, Lots : Natural;
      Felling_As_Builder, Building, Its_Still : Boolean := False;
      Porter_At_Site, Porter_Cut : Boolean := False;
      Counted : Boolean := True;
      Logs_Made, Straw_In : Natural := 0;
      function Says (I : Positive; Part : String) return Boolean is
        (Ada.Strings.Fixed.Index (Status (I), Part) > 0);
   begin
      Build_Paths_Now;
      Lay_Path ((44.0, 20.0, Ground_M), (44.0, 58.0, Ground_M), Laid);
      Build_Paths_Now;
      Zone_Housing (44.6, 22.0, 55.0, 56.0, Lots);
      Set_Job (3, Forester);
      Set_Job (5, Porter);
      for S in 1 .. 3_000 loop
         Run (1);
         Felling_As_Builder := Felling_As_Builder or else (Site_Of (3) = 1 and then Says (3, "felling a tree"));
         Building := Building or else Says (3, "raising the frame");
         Porter_At_Site := Porter_At_Site or else Says (5, "hovel");
         Porter_Cut := Porter_Cut or else Says (5, "cutting straw");
         Logs_Made := 0;
         for K in 1 .. Tree_Count loop
            if Tree_Down (K) then
               Logs_Made := Logs_Made + Logs_Of (Tree_At (K));
            end if;
         end loop;
         declare
            Built_In : Natural := 0;
         begin
            Straw_In := 0;
            for H in 1 .. House_Count loop
               Built_In := Built_In + House_At (H).Got (Wood);
               Straw_In := Straw_In + House_At (H).Got (Straw);
            end loop;
            Counted := Counted and then Wood_Total + Built_In = Logs_Made;
         end;
         --  (the house was its still when the second log it had felled for it went in)
         Its_Still := Its_Still
           or else (Trees_Felled >= 2 and then House_At (1).Got (Wood) = 2 and then Site_Of (3) = 1
                    and then House_At (1).Phase = Framing);
      end loop;
      Check (Lots > 0 and then Felling_As_Builder and then Building and then Trees_Felled >= 2
             and then House_At (1).Got (Wood) >= 2 and then Its_Still,
             "with no wood in store the builder fells, as the forester it is, and builds with what it brings home ("
             & Img (Trees_Felled) & " trees felled, " & Img (House_At (1).Got (Wood)) & " logs built in): the house is"
             & " its still");
      Check (Counted, "every log of every tree felled is lying, carried, stored or built in");
      Check (Porter_Cut and then not Porter_At_Site and then Stored (Straw) + Straw_In >= House_At (1).Takes (Straw),
             "the porter cuts the straw the house asks for (" & Img (Stored (Straw)) & " stored, " & Img (Straw_In)
             & " built in) and takes none of it there itself");
   end;

   --  a builder given other work, and another forester
   Set_Up (With_Bushes => False, With_Demand => True, With_Labour => True);
   declare
      Laid, Lots, Placed : Natural;
      Changed : Boolean := False;
      Counted : Boolean := True;
      Got_Then, Placed_Then : Natural := 0;
      function Says (I : Positive; Part : String) return Boolean is
        (Ada.Strings.Fixed.Index (Status (I), Part) > 0);
      function Wood_Carried return Natural is
         N : Natural := 0;
      begin
         for I in 1 .. Members loop
            if Carrying (I) = Wood then
               N := N + Carried (I);
            end if;
         end loop;
         return N;
      end Wood_Carried;
   begin
      Build_Paths_Now;
      Lay_Path ((44.0, 20.0, Ground_M), (44.0, 58.0, Ground_M), Laid);
      Build_Paths_Now;
      Zone_Housing (44.6, 22.0, 55.0, 56.0, Lots);
      Supply (Wood, 40, Placed);
      Set_Job (3, Forester);
      for S in 1 .. 3_000 loop
         Run (1);
         Counted := Counted and then Stored (Wood) + Wood_Carried + House_At (1).Got (Wood) = 40;
         if not Changed and then House_At (1).Phase = Framing and then Says (3, "carrying a log to") then
            Changed := True;
            Got_Then := House_At (1).Got (Wood);
            Placed_Then := House_At (1).Placed;
            Set_Job (3, Gatherer);
            Set_Job (6, Forester);
            Run (1);
            Check (Site_Of (3) = 0 and then Trade_Of (3) = No_Trade and then House_At (1).Builder /= 3
                   and then (Says (3, "to the stockpile") or else Says (3, "stacking a log"))
                   and then House_At (1).Got (Wood) = Got_Then,
                   "a builder given other work with a log in its hands takes the log back to the stockpile: the"
                   & " house is its no longer");
         end if;
         exit when Changed and then House_At (1).Placed > Placed_Then + 64 and then Site_Of (6) = 1;
      end loop;
      Check (Changed and then Site_Of (6) = 1 and then House_At (1).Builder = 6 and then House_Count = 1
             and then House_At (1).Placed > Placed_Then + 64 and then Counted
             and then (for all I in 1 .. Members => I = 6 or else not Says (I, "hovel")),
             "another forester takes the house up where it was left, and every log is still accounted for ("
             & Img (House_At (1).Placed) & " blocks laid, " & Img (House_At (1).Got (Wood)) & " logs built in)");
   end;

   --  housing far from the stake: the colony's ground reaches it
   Reset;
   Set_Beds (False);
   Castle.Herds.Set_Scatter (True);
   Set_Needs (False);
   Set_Skills (False);
   Meadow;
   Hours := 16.0 * 24.0;
   Place_Stake ((4.0, 4.0, Ground_M), 6, 42);
   declare
      Laid, Lots : Natural;
      Near : Float;
   begin
      Lay_Path ((6.0, 6.0, Ground_M), (60.0, 6.0, Ground_M), Laid);
      Lay_Path ((60.0, 6.5, Ground_M), (60.0, 60.0, Ground_M), Laid);
      Build_Paths_Now;
      Index_All;
      Run (2);
      Near := Ground_Reach_M;
      Zone_Housing (59.4, 44.0, 49.0, 60.0, Lots);
      Check (Lots >= 1 and then Near = Float (Work_Radius_M) and then Ground_Reach_M >= 78.0,
             "housing marked 78 m from the stake: the colony's ground, which reached " & Img (Near, 0)
             & " m, reaches it (" & Img (Ground_Reach_M, 0) & " m)");
      Build_Homes_Now;
      Check (House_Count = Lots and then Homeless = 6 - Lots and then Lot_Count = 0, "and houses stand there");
      declare
         Data : constant Bytes := Save;
         Ok : Boolean;
      begin
         Load (Data, Ok);
         Check (Ok and then Save = Data and then Ground_Reach_M >= 78.0, "and it still does after a load");
      end;
   end;

   --  residency
   Set_Up (With_Bushes => False, With_Needs => True, With_Labour => True);
   declare
      Laid, Lots, Placed : Natural;
      All_Home, None_Else, Housed_Cold, Others_Cold : Boolean := True;
      Housed_N : Natural := 0;
   begin
      Build_Paths_Now;
      Lay_Path ((44.0, 20.0, Ground_M), (44.0, 58.0, Ground_M), Laid);
      Build_Paths_Now;
      Zone_Housing (44.6, 22.0, 55.0, 43.0, Lots);
      Build_Homes_Now;
      Check (Lots in 2 .. 3 and then House_Count = Lots and then Homeless = 6 - Lots
             and then (for all H in 1 .. House_Count =>
                         House_At (H).Phase = Standing and then House_At (H).Owner in 1 .. Members
                         and then Home_Of (House_At (H).Owner) = H and then House_At (H).Got = House_At (H).Takes),
             "built on the spot: a hovel for as many as the zone has room for (" & Img (Lots) & " of six), each drawn by"
             & " lot (members" & House_At (1).Owner'Image & " and" & House_At (2).Owner'Image & " the first two)");
      Supply (Berries, 900, Placed);
      Hours := 16.0 * 24.0 + 20.0;
      Run (240);                                          --  to midnight
      for I in 1 .. Members loop
         if Housed (I) then
            Housed_N := Housed_N + 1;
            All_Home := All_Home and then Asleep (I) and then At_Home (I)
              and then House_On (Where (I).X, Where (I).Y) = Home_Of (I)
              and then abs (Where (I).Z - Ground_M) < 0.01;
         else
            None_Else := None_Else and then Asleep (I) and then House_On (Where (I).X, Where (I).Y) = 0
              and then Flat (Where (I), Stake) < 6.0;
         end if;
      end loop;
      Check (Housed_N = Lots and then All_Home and then None_Else,
             "at midnight those with a home are asleep in it, on its floor, and the rest round the stake");
      Hours := 50.0 * 24.0 + 20.0;                        --  winter, and no fire anywhere
      Run (240);
      for I in 1 .. Members loop
         if Housed (I) then
            Housed_Cold := Housed_Cold and then Asleep (I) and then not Cold (I);
         else
            Others_Cold := Others_Cold and then Asleep (I) and then Cold (I);
         end if;
      end loop;
      Check (Housed_Cold and then Others_Cold, "on a winter night with no fire those under a roof are not cold; the rest are");
      declare
         Data : constant Bytes := Save;
         Ok : Boolean;
      begin
         Load (Data, Ok);
         Check (Ok and then Save = Data and then House_Count = Lots and then Homeless = 6 - Lots
                and then (for all H in 1 .. House_Count => At_Home (House_At (H).Owner)),
                "houses and who lives in them come back from a save to the same bytes");
      end;
   end;

   --  the lottery among the living, and a dead owner's hovel drawn for again
   Set_Up (With_Bushes => False, With_Needs => True, With_Labour => True);
   declare
      Laid, Lots, Placed : Natural;
      Was : array (1 .. 8) of Natural := [others => 0];
      Stale, Empty : array (1 .. 8) of Natural := [others => 0];
      Redrawn, Left_Empty : Natural := 0;
      Bad, From_Living : Boolean := False;
      First_Draw : Boolean;
   begin
      Build_Paths_Now;
      Lay_Path ((44.0, 20.0, Ground_M), (44.0, 58.0, Ground_M), Laid);
      Build_Paths_Now;
      Zone_Housing (44.6, 22.0, 55.0, 43.0, Lots);
      Supply (Berries, 300, Placed);                      --  (a little, so that they do not all starve in one hour)
      Hours := 50.0 * 24.0 + 8.0;                         --  winter, and soon nothing to eat
      for S in 1 .. 8 * 1_440 loop
         Run (1);
         exit when Deaths > 0;
      end loop;
      Build_Homes_Now;
      First_Draw := Deaths = 1 and then House_Count = Lots and then Homeless = Living - Lots
        and then (for all H in 1 .. House_Count =>
                    House_At (H).Owner in 1 .. Members and then not Dead (House_At (H).Owner)
                    and then Home_Of (House_At (H).Owner) = H);
      Check (First_Draw,
             "hovels raised when one of the six is dead are drawn for among the five living: the dead draw nothing ("
             & Img (House_Count) & " hovels, " & Img (Homeless) & " of the living without)");
      for S in 1 .. 8 * 1_440 loop
         exit when Living = 0;
         for H in 1 .. House_Count loop
            Was (H) := House_At (H).Owner;
         end loop;
         Run (1);
         for H in 1 .. House_Count loop
            declare
               O : constant Natural := House_At (H).Owner;
            begin
               if O /= Was (H) and then O /= 0 then
                  Redrawn := Redrawn + 1;                 --  (it has fallen to another)
                  From_Living := From_Living or else Dead (O) or else Home_Of (O) /= H;
               end if;
               Stale (H) := (if O > 0 and then Dead (O) then Stale (H) + 1 else 0);
               Empty (H) := (if O = 0 and then Homeless > 0 then Empty (H) + 1 else 0);
               Bad := Bad or else Stale (H) > 2 or else Empty (H) > 2;
            end;
         end loop;
      end loop;
      Run (1);                                            --  (the second after the last death)
      for H in 1 .. House_Count loop
         if House_At (H).Owner = 0 then
            Left_Empty := Left_Empty + 1;
         end if;
      end loop;
      Check (Redrawn >= 1 and then not Bad and then not From_Living
             and then Left_Empty = Natural'Max (0, House_Count - Living),
             "a hovel whose owner dies is nobody's, and is drawn for again among the living without one (" & Img (Redrawn)
             & " times as the band starved; no hovel kept a dead owner, none stood empty with someone without; "
             & Img (Living) & " alive at the end and " & Img (Left_Empty) & " of the hovels nobody's)");
   end;

   --  a lot whose ground has changed since it was laid out
   Set_Up (With_Bushes => False, With_Labour => True);
   declare
      Laid, Lots, Lots_Then : Natural;
      Next : Lot_Corners;
      Mid  : Vec3;
   begin
      Build_Paths_Now;
      Lay_Path ((44.0, 20.0, Ground_M), (44.0, 58.0, Ground_M), Laid);
      Build_Paths_Now;
      Zone_Housing (44.6, 22.0, 55.0, 56.0, Lots);
      Run (3);                                            --  (the first is begun)
      Lots_Then := Lot_Count;
      Next := Lot_At (1);
      Mid := (Next (1) + Next (3)) * 0.5;
      Check (House_Count = 1 and then Lots_Then = Lots - 1 and then Zone_On (Mid.X, Mid.Y) = Zone_Count
             and then House_On (Mid.X, Mid.Y) = 0
             and then (for all K in 1 .. Lot_Count =>
                         (for all C of Lot_At (K) => Zone_On (C.X + 0.1 * (Mid.X - C.X), C.Y) = Zone_Count)),
             "the lots still to begin are laid out, in the order they will be begun in: each on the zone's ground ("
             & Img (Lots_Then) & " after the first is begun)");
      declare
         Data : constant Bytes := Save;
         Ok : Boolean;
      begin
         Reset;
         Load (Data, Ok);
         Check (Ok and then Save = Data and then Lot_Count = Lots_Then and then Lot_At (1) = Next,
                "and they come back from a save as they were laid out");
      end;
      --  a pit two and a half metres deep dug in the middle of the next lot
      Fill (Mid.X - 0.5, Mid.Y - 0.5, Mid.X + 0.5, Mid.Y + 0.5, Ground_Row - 10, Ground_Row - 1, Air);
      Changed_World;
      Build_Homes_Now;
      Check (House_Count >= 2 and then House_On (Mid.X, Mid.Y) = 0
             and then (for all H in 1 .. House_Count => House_At (H).Phase = Standing),
             "a lot whose ground no longer holds its house when its turn comes is not built on: the lots are laid out"
             & " anew round it (" & Img (House_Count) & " hovels stand, none over the pit"
             & (if Get (B (Mid.X), B (Mid.Y), Ground_Row - 1) = Air then ")"
                else "; it lay between two of them, and was filled as their ground was made one)"));
   end;

   --  a builder with a load for its house when night comes
   Set_Up (With_Bushes => False, With_Needs => True, With_Demand => True, With_Labour => True);
   declare
      Laid, Lots, Placed : Natural;
      Caught : Boolean := False;
      Got_Then : Natural := 0;
      function Says (I : Positive; Part : String) return Boolean is
        (Ada.Strings.Fixed.Index (Status (I), Part) > 0);
   begin
      Build_Paths_Now;
      Lay_Path ((44.0, 20.0, Ground_M), (44.0, 58.0, Ground_M), Laid);
      Build_Paths_Now;
      Zone_Housing (44.6, 22.0, 55.0, 56.0, Lots);
      Supply (Wood, 40, Placed);
      Supply (Berries, 900, Placed);
      Set_Job (3, Forester);
      Hours := 16.0 * 24.0 + 7.0;
      for S in 1 .. 3_000 loop
         Run (1);
         if Says (3, "carrying a log to") then
            Caught := True;
            Got_Then := House_At (1).Got (Wood);
            Hours := 16.0 * 24.0 + 22.0;       --  an hour past bedtime, the log in its arms
            exit;
         end if;
      end loop;
      Run (300);
      Check (Lots > 0 and then Caught and then Asleep (3) and then Carried (3) = 0
             and then House_At (1).Got (Wood) = Got_Then + 1 and then Stored (Wood) + House_At (1).Got (Wood) = 40
             and then Site_Of (3) = 1,
             "night coming on a builder with a log in its arms for its house: it carries the log there and goes to"
             & " bed (" & Status (3) & ")");
   end;

   --  every hovel's blueprint
   declare
      package CB renames Castle.Buildings;
      use type CB.Stage;
      type Seen_Grid is array (-2 .. 31, -2 .. 31, -2 .. 40) of Boolean;
      type Seen_Ptr is access Seen_Grid;
      Seen : constant Seen_Ptr := new Seen_Grid;
      Trimmed_P : constant Seen_Ptr := new Seen_Grid;
      Trimmed : Seen_Grid renames Trimmed_P.all;
      Trim_Right, Plain : Boolean := True;
      N_Dress, N_Columns : Natural := 0;
      In_Order, Timber_First, Never_Twice, Earth_Floor, Small_Windows : Boolean := True;
      Last_S : CB.Stage;
      Straw_Seen : Boolean;
      N_Timber, N_Straw, N_Floor : Natural;
      Logs_Lo, Sheaves_Lo : Natural := Natural'Last;
      Logs_Hi, Sheaves_Hi : Natural := 0;
      procedure Put (Bx, By, Bz : Integer; M : Material; S : CB.Stage; State : Natural) is
      begin
         In_Order := In_Order and then S >= Last_S;
         Last_S := S;
         if S = CB.Dress then
            --  a roof's trimming: thatch already laid, laid again as it is to lie, each block once
            Trim_Right := Trim_Right and then M in Thatch | Daub and then State >= Dressed
              and then Bx in Seen'Range (1) and then By in Seen'Range (2) and then Bz in Seen'Range (3)
              and then Seen (Bx, By, Bz) and then not Trimmed (Bx, By, Bz);
            if State / Under mod 2 = 1 or else M = Daub then
               --  (its underside, past a gable or on it, and the gable's top: under a block just trimmed)
               Trim_Right := Trim_Right and then Bz + 1 <= Seen'Last (3) and then Trimmed (Bx, By, Bz + 1);
            else
               N_Dress := N_Dress + 1;
               Trim_Right := Trim_Right and then (Bz + 1 > Seen'Last (3) or else not Seen (Bx, By, Bz + 1));
            end if;
            Trimmed (Bx, By, Bz) := True;
            return;
         end if;
         Plain := Plain and then State = 0;
         if M in Thatch | Daub then
            Straw_Seen := True;
            N_Straw := N_Straw + 1;
         elsif M in Log | Plank then
            Timber_First := Timber_First and then not Straw_Seen;
            N_Timber := N_Timber + 1;
         else
            Earth_Floor := Earth_Floor and then (M = Air or else (M = Footpath and then S = CB.Floor));
         end if;
         if S = CB.Floor then
            Earth_Floor := Earth_Floor and then M = Footpath;
            N_Floor := N_Floor + 1;
         end if;
         if Bx in Seen'Range (1) and then By in Seen'Range (2) and then Bz in Seen'Range (3) then
            Never_Twice := Never_Twice and then not Seen (Bx, By, Bz);
            Seen (Bx, By, Bz) := True;
         else
            Never_Twice := False;
         end if;
      end Put;
      procedure Draw is new CB.Blueprint (Put);
   begin
      for Seed in 1 .. 400 loop
         declare
            H : CB.House := CB.Design (Castle.Hash.Mix (Castle.Hash.U64 (Seed)));
         begin
            H.Ux := 1;
            H.Uy := 0;
            H.Vx := 0;
            H.Vy := 1;
            Seen.all := [others => [others => [others => False]]];
            Trimmed := [others => [others => [others => False]]];
            N_Dress := 0;
            Last_S := CB.Site;
            Straw_Seen := False;
            N_Timber := 0;
            N_Straw := 0;
            N_Floor := 0;
            Draw (H);
            N_Columns := (H.W + 2) * (H.D + 2);
            Trim_Right := Trim_Right and then N_Dress = N_Columns;
            Earth_Floor := Earth_Floor and then N_Floor = (H.W - 2) * (H.D - 2) + CB.Door_W_B
              and then N_Floor - CB.Door_W_B >= CB.Min_Floor_B;
            for K in 2 .. H.Open_N loop
               Small_Windows := Small_Windows and then H.Openings (K).Width <= 2 and then H.Openings (K).Height <= 3
                 and then H.Openings (K).Bottom >= 4;
            end loop;
            Logs_Lo := Natural'Min (Logs_Lo, (N_Timber + Planks_Per_Log - 1) / Planks_Per_Log);
            Logs_Hi := Natural'Max (Logs_Hi, (N_Timber + Planks_Per_Log - 1) / Planks_Per_Log);
            Sheaves_Lo := Natural'Min (Sheaves_Lo, (N_Straw + Thatch_Per_Sheaf - 1) / Thatch_Per_Sheaf);
            Sheaves_Hi := Natural'Max (Sheaves_Hi, (N_Straw + Thatch_Per_Sheaf - 1) / Thatch_Per_Sheaf);
         end;
      end loop;
      Check (In_Order and then Timber_First and then Never_Twice and then Plain,
             "four hundred hovels' blueprints: the floor, the frame, the walls, the gables, the roof, in that order; all"
             & " the timber before anything of straw; no block laid twice");
      Check (Trim_Right,
             "and last the roof trimmed: the top block of thatch of every column of it, each once, laid again as it is to lie");
      Check (Earth_Floor and then Small_Windows and then Logs_Lo >= 3 and then Logs_Hi <= 5 and then Sheaves_Lo >= 24
             and then Sheaves_Hi <= 36,
             "each a floor of beaten earth 25 square metres or more, its windows small and high; they take " & Img (Logs_Lo)
             & " to " & Img (Logs_Hi) & " logs and " & Img (Sheaves_Lo) & " to " & Img (Sheaves_Hi) & " sheaves");
   end;

   --  houses on a hillside, either side of a path that runs aslant across it: built from the foot of the
   --  path up (the stake below) and from its head down (the stake above), so that a lower house is
   --  walled before the higher one beside it and after
   for From_Above in Boolean loop
   Reset;
   Set_Beds (False);
   Castle.Herds.Set_Scatter (True);
   Set_Labour (True);
   Set_Needs (True);
   Set_Skills (False);
   Set_Demand_Chain (False);
   Meadow;
   declare
      --  the ground rises to the east from x = 30, a block every metre and a half
      function Step_Of (X : Float) return Natural is
        (if X < 31.5 then 0 else Natural (Float'Floor ((X - 30.0) / 1.5)));
      function Hill_Z (X : Float) return Float is (Ground_M + 0.25 * Float (Step_Of (X)));
      Laid, Lots_E, Lots_W, Placed : Natural;
      Ways, All_Home, None_Else : Boolean := True;
      Way_Lo, Housed_N : Natural := Natural'Last;
      Way_Hi : Natural := 0;
      Rise_Lo : Integer := Integer'Last;
      Rise_Hi : Integer := Integer'First;
   begin
      for K in 1 .. 22 loop
         Fill (30.0 + 1.5 * Float (K), 22.0, 64.0, 64.0, Ground_Row + K - 2, Ground_Row + K - 2, Dirt);
         Fill (30.0 + 1.5 * Float (K), 22.0, 64.0, 64.0, Ground_Row + K - 1, Ground_Row + K - 1, Grass);
      end loop;
      Changed_World;
      Hours := 16.0 * 24.0;
      Place_Stake ((if From_Above then (60.0, 52.0, Hill_Z (60.0)) else Stake_P), 12, 42);
      Lay_Path ((20.5, 17.5, Ground_M), (40.0, 17.5, Ground_M), Laid);
      Zone_Stockpile (21.0, 15.0, 25.0, 17.0, Placed);
      Lay_Path ((44.0, 27.0, Hill_Z (44.0)), (50.0, 61.0, Hill_Z (50.0)), Laid);
      Build_Paths_Now;
      Index_All;
      Zone_Housing (45.2, 29.0, 62.5, 60.0, Lots_E);      --  uphill of the path (a lot lies along its path: 11 m deep)
      Zone_Housing (43.5, 29.0, 35.0, 60.0, Lots_W);      --  downhill of it
      Build_Homes_Now;
      for H in 1 .. House_Count loop
         declare
            V : constant House_View := House_At (H);
         begin
            Ways := Ways and then V.Phase = Standing
              and then Castle.Nav."=" (Castle.Nav.Plan (Stake, V.Bed).Result, Castle.Nav.Found);
            Way_Lo := Natural'Min (Way_Lo, V.Way);
            Way_Hi := Natural'Max (Way_Hi, V.Way);
            Rise_Lo := Integer'Min (Rise_Lo, V.Rise);
            Rise_Hi := Integer'Max (Rise_Hi, V.Rise);
         end;
      end loop;
      Check (Lots_E >= 2 and then Lots_W >= 2 and then House_Count >= 6 and then Ways,
             (if From_Above then "(built from the head of the path down) " else "")
             & "on ground that falls a block every metre and a half, " & Img (House_Count) & " hovels built either side of"
             & " a path aslant across it (" & Img (Lots_E) & " lots uphill, " & Img (Lots_W) & " downhill): there is a way"
             & " from the stake to every bed");
      Check (Way_Lo >= 2 and then Way_Hi > Castle.Buildings.Door_Landing_B + 1 and then Rise_Lo < 0 and then Rise_Hi > 0
             and then (for all H in 1 .. House_Count =>
                         abs House_At (H).Rise <= Integer'Max (1, House_At (H).Way - Castle.Buildings.Door_Landing_B) + 1),
             "their doors are " & Img (Way_Lo) & " to " & Img (Way_Hi) & " block columns from the path, their floors from"
             & Rise_Lo'Image & " to" & Rise_Hi'Image & " rows off its ground: never more than a landing and a stair of"
             & " single steps can join");
      --  a stair of stone only where the path lies more than a block off the floor (John, 2026-11-12: "the
      --  stairs were added when the pathway was pretty much already leavel witht he house path")
      declare
         Near_N, Near_Stone, Far_N, Far_Bare : Natural := 0;
      begin
         for H in 1 .. House_Count loop
            declare
               V  : constant House_View := House_At (H);
               Lu : constant Float := Sqrt ((V.Corner (2).X - V.Corner (1).X) ** 2 + (V.Corner (2).Y - V.Corner (1).Y) ** 2);
               Lv : constant Float := Sqrt ((V.Corner (4).X - V.Corner (1).X) ** 2 + (V.Corner (4).Y - V.Corner (1).Y) ** 2);
               Ux : constant Float := (V.Corner (2).X - V.Corner (1).X) / Lu;
               Uy : constant Float := (V.Corner (2).Y - V.Corner (1).Y) / Lu;
               Vx : constant Float := (V.Corner (4).X - V.Corner (1).X) / Lv;
               Vy : constant Float := (V.Corner (4).Y - V.Corner (1).Y) / Lv;
               Stones : Natural := 0;
            begin
               --  (its door's way: four columns wide, from its front wall out to the path; V.Door is 2.5 blocks out)
               for K in 1 .. V.Way loop
                  for J in -2 .. 1 loop
                     declare
                        X : constant Float := V.Door.X + 0.25 * ((Float (J) + 0.5) * Ux + (2.5 - Float (K)) * Vx);
                        Y : constant Float := V.Door.Y + 0.25 * ((Float (J) + 0.5) * Uy + (2.5 - Float (K)) * Vy);
                     begin
                        Stones := Stones + Count_In (B (X), B (Y), B (X), B (Y), 1, H_B - 2, Fieldstone);
                     end;
                  end loop;
               end loop;
               if abs V.Rise = 1 and then V.Way > Castle.Buildings.Door_Landing_B then
                  Near_N := Near_N + 1;
                  Near_Stone := Near_Stone + Stones;
               elsif abs V.Rise > 1 then
                  Far_N := Far_N + 1;
                  if Stones = 0 then
                     Far_Bare := Far_Bare + 1;
                  end if;
               end if;
            end;
         end loop;
         Check (Near_N > 0 and then Near_Stone = 0 and then Far_N > 0 and then Far_Bare = 0,
                "a door's way is a stair of stone only where the path lies more than a block off the floor: " & Img (Far_N)
                & " of them are, each with its treads; " & Img (Near_N) & " whose floor is one block off have a landing"
                & " and a way of earth (" & Img (Near_Stone) & " blocks of stone in them)");
      end;
      Supply (Berries, 900, Placed);
      Hours := 16.0 * 24.0 + 20.0;
      Run (240);                                          --  to midnight
      Housed_N := 0;
      for I in 1 .. Members loop
         if Housed (I) then
            Housed_N := Housed_N + 1;
            All_Home := All_Home and then Asleep (I) and then At_Home (I)
              and then House_On (Where (I).X, Where (I).Y) = Home_Of (I)
              and then abs (Where (I).Z - House_At (Home_Of (I)).Bed.Z) < 0.01;
         else
            None_Else := None_Else and then Asleep (I) and then House_On (Where (I).X, Where (I).Y) = 0;
         end if;
      end loop;
      Check (Housed_N = House_Count and then All_Home and then None_Else,
             "at midnight all " & Img (Housed_N) & " who have one are asleep in their own, on its floor");
      declare
         Steps_All, Bare_All, Stones : Natural := 0;
         Most, Fewest : Natural := 0;
         Spots, Pits : Natural := 0;
      begin
         Fewest := Natural'Last;
         for H in 1 .. House_Count loop
            declare
               Steps, Bare : Natural;
            begin
               Count_Pits (H, Spots, Pits);
               Count_Steps (H, Steps, Bare);
               Steps_All := Steps_All + Steps;
               Bare_All := Bare_All + Bare;
               Stones := Stones + House_At (H).Got (Stone);
               Most := Natural'Max (Most, House_At (H).Got (Stone));
               Fewest := Natural'Min (Fewest, House_At (H).Got (Stone));
            end;
         end loop;
         Check (Steps_All > 200 and then Bare_All = 0 and then Fewest >= 1,
                "round them the ground steps more than a block in " & Img (Steps_All) & " places, and in every one the"
                & " higher side is a wall of stone, no more than a block of earth standing bare at its foot (" & Img (Bare_All)
                & " are not); they took "
                & Img (Fewest) & " to " & Img (Most) & " stones each, " & Img (Stones) & " in all");
         Check (Spots > 1_500 and then Pits = 0,
                "and from every spot in and round them that a serf can get to (" & Img (Spots) & ", half a metre apart)"
                & " there is a way back to the stake: no yard is a pit (" & Img (Pits) & " are)");
         declare
            Sides, Raw, Proud : Natural := 0;
         begin
            for H in 1 .. House_Count loop
               Count_Joins (H, Sides, Raw, Proud);
            end loop;
            Check (Sides >= 3 and then Raw = 0 and then Proud = 0,
                   "a hovel begun beside an earlier one makes the ground between them ready with its own (" & Img (Sides)
                   & " times here): none of it is left as it lay (" & Img (Raw) & " columns), and no wall is left standing"
                   & " between two yards with nothing to hold (" & Img (Proud) & " columns of stone stand proud)");
         end;
      end;
   end;
   end loop;

   --  the same hillside with two hovels begun at once and the later one's ground made ready first
   Reset;
   Set_Beds (False);
   Castle.Herds.Set_Scatter (True);
   Set_Labour (True);
   Set_Needs (False);
   Set_Skills (False);
   Set_Demand_Chain (False);
   Meadow;
   declare
      function Step_Of (X : Float) return Natural is
        (if X < 31.5 then 0 else Natural (Float'Floor ((X - 30.0) / 1.5)));
      function Hill_Z (X : Float) return Float is (Ground_M + 0.25 * Float (Step_Of (X)));
      Laid, Lots, Placed : Natural;
      Begun : Natural;
      Steps_All, Bare_All, Spots, Pits, Sides, Raw, Proud : Natural := 0;
   begin
      for K in 1 .. 22 loop
         Fill (30.0 + 1.5 * Float (K), 22.0, 64.0, 64.0, Ground_Row + K - 2, Ground_Row + K - 2, Dirt);
         Fill (30.0 + 1.5 * Float (K), 22.0, 64.0, 64.0, Ground_Row + K - 1, Ground_Row + K - 1, Grass);
      end loop;
      Changed_World;
      Hours := 16.0 * 24.0;
      Place_Stake (Stake_P, 12, 42);
      Lay_Path ((20.5, 17.5, Ground_M), (40.0, 17.5, Ground_M), Laid);
      Zone_Stockpile (21.0, 15.0, 25.0, 17.0, Placed);
      Lay_Path ((44.0, 27.0, Hill_Z (44.0)), (50.0, 61.0, Hill_Z (50.0)), Laid);
      Build_Paths_Now;
      Index_All;
      Zone_Housing (45.2, 29.0, 62.5, 60.0, Lots);        --  uphill of the path
      Set_Job (3, Forester);
      Set_Job (4, Forester);
      Set_Job (5, Forester);
      Run (2);
      Begun := House_Count;
      Build_Homes_Now (Last_First => True);
      for H in 1 .. House_Count loop
         declare
            Steps, Bare : Natural;
         begin
            Count_Steps (H, Steps, Bare);
            Steps_All := Steps_All + Steps;
            Bare_All := Bare_All + Bare;
            Count_Pits (H, Spots, Pits);
            Count_Joins (H, Sides, Raw, Proud);
         end;
      end loop;
      Check (Begun = 3 and then House_Count >= 3 and then Sides >= 2 and then Bare_All = 0 and then Raw = 0
             and then Proud = 0 and then Pits = 0 and then Steps_All > 100,
             "with " & Img (Begun) & " hovels begun at once and the last one's ground made ready first, it comes to the"
             & " same: every step walled (" & Img (Bare_All) & " of " & Img (Steps_All) & " bare), the ground between them"
             & " made one (" & Img (Sides) & " sides, " & Img (Raw) & " columns left raw), no wall standing proud ("
             & Img (Proud) & "), no yard a pit (" & Img (Pits) & " of " & Img (Spots) & " spots)");
   end;

   --  a tree's stump standing between two lots: the two are kept apart (the ground made one round it would shut
   --  the back of the gap off: a pit)
   declare
      At_X, At_Y : Integer := 0;           --  the column, found on a first pass with nothing in the way
      Top_Then : Integer := 0;
      Reach_Then, Houses_Then : Natural := 0;
      First_Corner : Vec3 := (0.0, 0.0, 0.0);
   begin
      for Pass in 1 .. 2 loop
         Reset;
         Set_Beds (False);
         Castle.Herds.Set_Scatter (True);
         Set_Labour (True);
         Set_Needs (False);
         Set_Skills (False);
         Set_Demand_Chain (False);
         Meadow;
         declare
            function Step_Of (X : Float) return Natural is
              (if X < 31.5 then 0 else Natural (Float'Floor ((X - 30.0) / 1.5)));
            function Hill_Z (X : Float) return Float is (Ground_M + 0.25 * Float (Step_Of (X)));
            Laid, Lots, Placed : Natural;
            Joined : Natural := 0;           --  the hovel whose ground reaches over to an earlier one's
         begin
            for K in 1 .. 22 loop
               Fill (30.0 + 1.5 * Float (K), 22.0, 64.0, 64.0, Ground_Row + K - 2, Ground_Row + K - 2, Dirt);
               Fill (30.0 + 1.5 * Float (K), 22.0, 64.0, 64.0, Ground_Row + K - 1, Ground_Row + K - 1, Grass);
            end loop;
            if Pass = 2 then
               Set (At_X, At_Y, Top_Then + 1, Log);          --  (a tree's stump: not ground a zone takes)
               Set (At_X, At_Y, Top_Then + 2, Log);
            end if;
            Changed_World;
            Hours := 16.0 * 24.0;
            Place_Stake (Stake_P, 12, 42);
            Lay_Path ((20.5, 17.5, Ground_M), (40.0, 17.5, Ground_M), Laid);
            Zone_Stockpile (21.0, 15.0, 25.0, 17.0, Placed);
            Lay_Path ((44.0, 27.0, Hill_Z (44.0)), (50.0, 61.0, Hill_Z (50.0)), Laid);
            Build_Paths_Now;
            Index_All;
            Zone_Housing (45.2, 29.0, 62.5, 60.0, Lots);     --  uphill of the path
            Build_Homes_Now;
            if Pass = 1 then
               for H in 1 .. House_Count loop
                  if Joined = 0 and then House_At (H).Reach_L >= 2 then
                     Joined := H;
                  end if;
               end loop;
            end if;
            if Pass = 1 and then Joined > 0 then
               declare
                  V : constant House_View := House_At (Joined);
                  --  a column in the middle of what it reaches over, halfway down its side wall
                  P : constant Vec3 :=
                    V.Corner (1) + (V.Corner (1) - V.Corner (2)) * (0.25 * Float (2 + V.Reach_L / 2) / Flat (V.Corner (1), V.Corner (2)))
                    + (V.Corner (4) - V.Corner (1)) * 0.5;
               begin
                  At_X := B (P.X);
                  At_Y := B (P.Y);
                  Top_Then := B (Hill_Z (P.X) + 0.01) - 1;
                  Reach_Then := V.Reach_L;
                  Houses_Then := House_Count;
                  First_Corner := V.Corner (1);
               end;
            elsif Pass = 2 then
               declare
                  Steps_All, Bare_All, Spots, Pits, Sides, Raw, Proud : Natural := 0;
               begin
                  for H in 1 .. House_Count loop
                     declare
                        Steps, Bare : Natural;
                     begin
                        Count_Steps (H, Steps, Bare);
                        Steps_All := Steps_All + Steps;
                        Bare_All := Bare_All + Bare;
                        Count_Pits (H, Spots, Pits);
                        Count_Joins (H, Sides, Raw, Proud);
                     end;
                  end loop;
                  Check (Houses_Then >= 3 and then House_Count = Houses_Then and then Reach_Then >= 2
                         and then (for some H in 1 .. House_Count =>
                                     House_At (H).Corner (1) = First_Corner and then House_At (H).Reach_L = 0)
                         and then Zone_On ((Float (At_X) + 0.5) * 0.25, (Float (At_Y) + 0.5) * 0.25) = 0
                         and then Get (At_X, At_Y, Top_Then + 1) = Log and then Get (At_X, At_Y, Top_Then) in Grass | Dirt
                         and then Bare_All = 0 and then Raw = 0 and then Proud = 0 and then Pits = 0,
                         "a stump standing between two lots keeps the two apart: the later hovel's ground, which reached "
                         & Img (Reach_Then) & " columns over to the earlier one's without it, keeps to its own, and each"
                         & " walls its own side; the stump stands on its ground as it lay; every step walled ("
                         & Img (Bare_All) & " of " & Img (Steps_All) & " bare), no yard a pit (" & Img (Pits) & " of "
                         & Img (Spots) & " spots)");
               end;
            end if;
         end;
      end loop;
   end;

   --  a hovel built by hand on the hillside, below its path and above it: its ground walled with stone
   --  from the stockpile (and its roof thatched from a ladder: the way back to the stake is planned from
   --  wherever its builder stands with one)
   for Uphill in Boolean loop
   Reset;
   Set_Ladders (True);
   Set_Beds (False);
   Castle.Herds.Set_Scatter (True);
   Set_Labour (True);
   Set_Needs (False);
   Set_Skills (False);
   Set_Demand_Chain (True);
   Meadow;
   declare
      use Castle.Views;
      function Step_Of (X : Float) return Natural is
        (if X < 31.5 then 0 else Natural (Float'Floor ((X - 30.0) / 1.5)));
      function Hill_Z (X : Float) return Float is (Ground_M + 0.25 * Float (Step_Of (X)));
      function Says (I : Positive; Part : String) return Boolean is
        (Ada.Strings.Fixed.Index (Status (I), Part) > 0);
      Laid, Lots, Placed, Cells : Natural;
      Camp_Ok : Boolean;
      Asked, Ways, Counted, Ladder_Ok : Boolean := True;
      Waited, Up_It : Boolean := False;
      Stood : array (1 .. 4) of Boolean := [others => False];   --  the eaves a ladder has stood under
      Stone_In : Natural := 0;
      Done_At : Natural := 0;
      function Stone_Row return Natural is
      begin
         for R in 1 .. Demand_Rows loop
            if Demand_Row_At (R).Who = A_Zone and then Demand_Row_At (R).What = Stone and then Demand_Row_At (R).Kind = Once
              and then Zone_At (Demand_Row_At (R).Zone).Kind = Habitation_Zone
            then
               return Demand_Row_At (R).Amount;
            end if;
         end loop;
         return 0;
      end Stone_Row;
      function Stone_Carried return Natural is
         N : Natural := 0;
      begin
         for I in 1 .. Members loop
            if Carrying (I) = Stone then
               N := N + Carried (I);
            end if;
         end loop;
         return N;
      end Stone_Carried;
   begin
      for K in 1 .. 22 loop
         Fill (30.0 + 1.5 * Float (K), 22.0, 64.0, 64.0, Ground_Row + K - 2, Ground_Row + K - 2, Dirt);
         Fill (30.0 + 1.5 * Float (K), 22.0, 64.0, 64.0, Ground_Row + K - 1, Ground_Row + K - 1, Grass);
      end loop;
      Changed_World;
      Hours := 16.0 * 24.0 + 7.0;
      Place_Stake (Stake_P, 6, 42);
      Lay_Path ((20.5, 17.5, Ground_M), (40.0, 17.5, Ground_M), Laid);
      Zone_Stockpile (21.0, 15.0, 29.0, 17.0, Cells);
      Lay_Path ((44.0, 27.0, Hill_Z (44.0)), (50.0, 61.0, Hill_Z (50.0)), Laid);
      Build_Paths_Now;
      Index_All;
      Zone_Camp ((26.0, 26.0, Ground_M), Camp_Ok);
      if Uphill then
         Zone_Housing (45.2, 29.0, 45.2, 60.0, Lots);
      else
         Zone_Housing (43.5, 29.0, 43.5, 60.0, Lots);
      end if;
      Set_Job (3, Forester);
      Supply (Wood, 30, Placed);
      Supply (Straw, 80, Placed);
      Supply (Stone, Hearth_Stones, Placed);              --  the hearth's stones, and no more
      for S in 1 .. 4_000 loop
         Run (1);
         Ways := Ways and then Castle.Nav."=" (Castle.Nav.Plan (Where (3), Stake).Result, Castle.Nav.Found);
         if House_Count >= 1 and then House_At (1).Waits = For_Stone and then Says (3, "no stone to wall") then
            Waited := True;
            exit;
         end if;
      end loop;
      Asked := Stone_Row > 0;
      Check (Camp_Ok and then Lots >= 2 and then Waited and then House_At (1).Got (Stone) = 0
             and then Stored (Stone) + Stone_Carried + Camp_State.Stones = Hearth_Stones
             and then House_At (1).Takes (Stone) >= 8 and then Asked
             and then Value_Of (House (1), "Waits for") = "stone in the stores" and then Says (3, "no stone to wall"),
             (if Uphill then "(above the path) " else "(below the path) ")
             & "with only the stones the camp's hearth still wants in store, the hovel takes none of them: its ground"
             & " waits for stone, and says so (" & Img (House_At (1).Takes (Stone)) & " stones wanted, asked of the"
             & " stores: " & Img (Stone_Row) & ")");
      Supply (Stone, 60, Placed);
      Stone_In := Stored (Stone) + Stone_Carried + House_At (1).Got (Stone) + Camp_State.Stones;
      for S in 1 .. 12_000 loop
         Run (1);
         Counted := Counted and then Stored (Stone) + Stone_Carried + House_At (1).Got (Stone)
           + (if House_Count > 1 then House_At (2).Got (Stone) else 0) + Camp_State.Stones = Stone_In;
         Ways := Ways and then Castle.Nav."=" (Castle.Nav.Plan (Where (3), Stake).Result, Castle.Nav.Found);
         Ladder_Ok := Ladder_Ok and then Ladders_Add_Up;
         Up_It := Up_It or else Aloft (3);
         if Ladder_At (1).Standing then
            Stood (Ladder_At (1).Side) := True;
         end if;
         if House_At (1).Phase = Standing then
            Done_At := S;
            exit;
         end if;
      end loop;
      Check (Ladder_Ok and then Ladders_Made = 1 and then Up_It and then (Stood (1) or else Stood (3))
             and then (Stood (2) or else Stood (4)),
             (if Uphill then "(above the path) " else "(below the path) ")
             & "its roof is thatched from a ladder made for it, stood under one eave and then carried round to the"
             & " other: the builder up it, and the one ladder stored, carried or standing at every second");
      declare
         V : constant House_View := House_At (1);
         Steps, Bare : Natural;
         X0 : constant Integer := B (Float'Min (V.Corner (1).X, V.Corner (3).X)) - 14;
         X1 : constant Integer := B (Float'Max (V.Corner (1).X, V.Corner (3).X)) + 14;
         Y0 : constant Integer := B (Float'Min (V.Corner (1).Y, V.Corner (3).Y)) - 14;
         Y1 : constant Integer := B (Float'Max (V.Corner (1).Y, V.Corner (3).Y)) + 14;
         Laid_Stone : constant Natural := Count_In (X0, Y0, X1, Y1, 1, H_B - 2, Fieldstone);
      begin
         Count_Steps (1, Steps, Bare);
         Check (Done_At > 0 and then Counted and then V.Got (Stone) >= 8 and then (V.Rise > 0) = Uphill and then V.Rise /= 0
                and then Laid_Stone > (V.Got (Stone) - 2) * Wall_Per_Stone and then Laid_Stone <= V.Got (Stone) * Wall_Per_Stone + 64,
                "with stone it is walled and built (" & Img (Done_At) & " game minutes): " & Img (V.Got (Stone))
                & " stones carried to it, every one stored, carried or built in; " & Img (Laid_Stone)
                & " blocks of wall and stair stand; its floor" & V.Rise'Image & " rows off the path's");
         Check (Ways, "and at no second of it all was its builder anywhere it could not walk back to the stake from");
         Check (Steps > 40 and then Bare = 0
                and then Castle.Nav."=" (Castle.Nav.Plan (Stake, V.Bed).Result, Castle.Nav.Found),
                "its walls hold every step of more than a block round it (" & Img (Steps) & "), and there is a way in to its bed");
      end;
      --  the next hovel, begun beside it and built by hand as well: the ground between the two made one
      Supply (Wood, 30, Placed);
      Supply (Straw, 80, Placed);
      Supply (Stone, 80, Placed);
      declare
         Ways_2 : Boolean := True;
         Done_2 : Natural := 0;
         Steps_All, Bare_All, Spots, Pits, Sides, Raw, Proud : Natural := 0;
      begin
         for S in 1 .. 16_000 loop
            Run (1);
            Ways_2 := Ways_2 and then Castle.Nav."=" (Castle.Nav.Plan (Where (3), Stake).Result, Castle.Nav.Found);
            if House_Count >= 2 and then House_At (2).Phase = Standing then
               Done_2 := S;
               exit;
            end if;
         end loop;
         for H in 1 .. Natural'Min (2, House_Count) loop
            declare
               Steps, Bare : Natural;
            begin
               Count_Steps (H, Steps, Bare);
               Steps_All := Steps_All + Steps;
               Bare_All := Bare_All + Bare;
               Count_Pits (H, Spots, Pits);
               Count_Joins (H, Sides, Raw, Proud);
            end;
         end loop;
         Check (Done_2 > 0 and then Ways_2 and then Sides = 1 and then Raw = 0 and then Proud = 0 and then Bare_All = 0
                and then Pits = 0
                and then Castle.Nav."=" (Castle.Nav.Plan (Stake, House_At (2).Bed).Result, Castle.Nav.Found),
                "the next hovel, begun beside it, is built by hand too (" & Img (Done_2) & " game minutes, "
                & Img (House_At (Natural'Min (2, House_Count)).Got (Stone)) & " stones): its ground reaches "
                & Img (House_At (Natural'Min (2, House_Count)).Reach_L + House_At (Natural'Min (2, House_Count)).Reach_R)
                & " columns over to the first one's, none of it left as it lay (" & Img (Raw) & "), no wall left"
                & " standing between the two yards (" & Img (Proud) & "), every step walled (" & Img (Bare_All) & " of "
                & Img (Steps_All) & " bare), no yard a pit (" & Img (Pits) & " of " & Img (Spots)
                & "), and its builder never anywhere it could not walk back from");
      end;
   end;
   end loop;

   --  two hovels begun at once and built by hand side by side, by two foresters, above the path and below it:
   --  the ground between them worked on by both (and each roof thatched from a ladder of its builder's own)
   for Uphill in Boolean loop
   Reset;
   Set_Ladders (True);
   Set_Beds (False);
   Castle.Herds.Set_Scatter (True);
   Set_Labour (True);
   Set_Needs (False);
   Set_Skills (False);
   Set_Demand_Chain (True);
   Meadow;
   declare
      function Step_Of (X : Float) return Natural is
        (if X < 31.5 then 0 else Natural (Float'Floor ((X - 30.0) / 1.5)));
      function Hill_Z (X : Float) return Float is (Ground_M + 0.25 * Float (Step_Of (X)));
      Laid, Lots, Placed, Cells : Natural;
      Camp_Ok : Boolean;
      Ways, Ladder_Ok : Boolean := True;
      Both_At_Ground, Both_Up : Boolean := False;
      Done_At : Natural := 0;
      Steps_All, Bare_All, Spots, Pits, Sides, Raw, Proud : Natural := 0;
   begin
      for K in 1 .. 22 loop
         Fill (30.0 + 1.5 * Float (K), 22.0, 64.0, 64.0, Ground_Row + K - 2, Ground_Row + K - 2, Dirt);
         Fill (30.0 + 1.5 * Float (K), 22.0, 64.0, 64.0, Ground_Row + K - 1, Ground_Row + K - 1, Grass);
      end loop;
      Changed_World;
      Hours := 16.0 * 24.0 + 7.0;
      Place_Stake (Stake_P, 6, 42);
      Lay_Path ((20.5, 17.5, Ground_M), (40.0, 17.5, Ground_M), Laid);
      Zone_Stockpile (21.0, 15.0, 29.0, 17.0, Cells);
      Lay_Path ((44.0, 27.0, Hill_Z (44.0)), (50.0, 61.0, Hill_Z (50.0)), Laid);
      Build_Paths_Now;
      Index_All;
      Zone_Camp ((26.0, 26.0, Ground_M), Camp_Ok);
      Build_Camp_Now;
      --  (room for the two and no third: a third, begun when the first stood, would be half dug at the end)
      if Uphill then
         Zone_Housing (45.2, 29.0, 45.2, 44.5, Lots);
      else
         Zone_Housing (43.5, 29.0, 43.5, 46.5, Lots);
      end if;
      Set_Job (3, Forester);
      Set_Job (4, Forester);
      Supply (Wood, 30, Placed);
      Supply (Straw, 80, Placed);
      Supply (Stone, 120, Placed);
      for S in 1 .. 16_000 loop
         Run (1);
         Ways := Ways and then Castle.Nav."=" (Castle.Nav.Plan (Where (3), Stake).Result, Castle.Nav.Found)
           and then Castle.Nav."=" (Castle.Nav.Plan (Where (4), Stake).Result, Castle.Nav.Found);
         Ladder_Ok := Ladder_Ok and then Ladders_Add_Up;
         Both_Up := Both_Up or else (Aloft (3) and then Aloft (4));
         Both_At_Ground := Both_At_Ground
           or else (House_Count >= 2 and then House_At (1).Phase = Ground and then House_At (2).Phase = Ground
                    and then House_At (1).Builder > 0 and then House_At (2).Builder > 0);
         if House_Count >= 2 and then House_At (1).Phase = Standing and then House_At (2).Phase = Standing then
            Done_At := S;
            exit;
         end if;
      end loop;
      for H in 1 .. Natural'Min (2, House_Count) loop
         declare
            Steps, Bare : Natural;
         begin
            Count_Steps (H, Steps, Bare);
            Steps_All := Steps_All + Steps;
            Bare_All := Bare_All + Bare;
            Count_Pits (H, Spots, Pits);
            Count_Joins (H, Sides, Raw, Proud);
         end;
      end loop;
      Check (Camp_Ok and then Lots = 2 and then House_Count = 2 and then Done_At > 0 and then Both_At_Ground and then Ways
             and then Sides = 1 and then Raw = 0
             and then Proud = 0 and then Bare_All = 0 and then Pits = 0,
             (if Uphill then "(above the path) " else "(below the path) ")
             & "two hovels begun at once and built side by side by two foresters, the ground of both in the making at"
             & " the same time (" & Img (Done_At) & " game minutes for the two): the ground between them made one ("
             & Img (Raw) & " columns left raw), no wall left standing between the two yards (" & Img (Proud)
             & "), every step walled (" & Img (Bare_All) & " of " & Img (Steps_All) & " bare), no yard a pit ("
             & Img (Pits) & " of " & Img (Spots) & "), and neither builder ever anywhere it could not walk back from");
      Check (Ladder_Ok and then Ladders_Made in 1 .. 2,
             "each roof thatched from a ladder (" & Img (Ladders_Made) & " made for the two"
             & (if Both_Up then ", both builders up theirs at once" else "") & "), every one stored, carried or"
             & " standing at every second");
   end;
   end loop;

   --  a tree felled whose shape reaches where a house has been built since
   Bough_On := False;
   Set_Up (With_Bushes => False, With_Trees => True, With_Labour => True);
   declare
      Laid, Lots : Natural;
      Logs_Then, Daub_Then, Thatch_Then : Natural;
      X0, Y0, X1, Y1 : Integer;
      Whole : Boolean := True;
   begin
      Build_Paths_Now;
      Lay_Path ((44.0, 20.0, Ground_M), (44.0, 58.0, Ground_M), Laid);
      Build_Paths_Now;
      Zone_Housing (44.6, 22.0, 55.0, 43.0, Lots);
      Build_Homes_Now;
      declare
         V   : constant House_View := House_At (1);
         Mid : constant Vec3 := (V.Corner (1) + V.Corner (3)) * 0.5;
      begin
         X0 := B (Float'Min (V.Corner (1).X, V.Corner (3).X)) - 2;
         X1 := B (Float'Max (V.Corner (1).X, V.Corner (3).X)) + 1;
         Y0 := B (Float'Min (V.Corner (1).Y, V.Corner (3).Y)) - 2;
         Y1 := B (Float'Max (V.Corner (1).Y, V.Corner (3).Y)) + 1;
         --  every tree's shape now has a bough where the house's first corner post stands
         Bough_X := B (V.Corner (1).X + 0.02 * (Mid.X - V.Corner (1).X));
         Bough_Y := B (V.Corner (1).Y + 0.02 * (Mid.Y - V.Corner (1).Y));
         Bough_Z0 := Ground_Row;
         Bough_Z1 := Ground_Row + 6;
         Bough_On := True;
      end;
      Logs_Then := Count_In (X0, Y0, X1, Y1, Ground_Row - 1, Ground_Row + 30, Log);
      Daub_Then := Count_In (X0, Y0, X1, Y1, Ground_Row - 1, Ground_Row + 30, Daub);
      Thatch_Then := Count_In (X0, Y0, X1, Y1, Ground_Row - 1, Ground_Row + 30, Thatch);
      Set_Job (3, Forester);
      Set_Job (4, Forester);
      for S in 1 .. 1_500 loop
         Run (1);
         exit when Trees_Felled >= 2;
      end loop;
      for Z in Bough_Z0 .. Bough_Z1 loop
         Whole := Whole and then Get (Bough_X, Bough_Y, Z) = Log;
      end loop;
      Check (Lots >= 1 and then Trees_Felled >= 2 and then Whole and then Logs_Then > 200
             and then Count_In (X0, Y0, X1, Y1, Ground_Row - 1, Ground_Row + 30, Log) = Logs_Then
             and then Count_In (X0, Y0, X1, Y1, Ground_Row - 1, Ground_Row + 30, Daub) = Daub_Then
             and then Count_In (X0, Y0, X1, Y1, Ground_Row - 1, Ground_Row + 30, Thatch) = Thatch_Then,
             "trees felled whose shapes have a bough where a house's corner post stands: the post stays, and every block"
             & " of the house (" & Img (Logs_Then) & " of timber)");
      Bough_On := False;
   end;

   --  a vegetable pulled where a house was built since does not grow back into it
   declare
      Open : constant Vec3 := (30.0, 44.0, Ground_M);
      Eave : Vec3 := Open;
      Corner_1 : Vec3 := (0.0, 0.0, 0.0);
      Laid, Lots : Natural;
   begin
      for Pass in 1 .. 2 loop
         Reset;
         Set_Beds (False);
         Castle.Herds.Set_Scatter (True);
         Set_Labour (True);
         Set_Needs (False);
         Set_Skills (False);
         Set_Demand_Chain (False);
         Meadow;
         if Pass = 2 then
            Set (B (Eave.X), B (Eave.Y), Ground_Row, Wild_Vegetables);
            Set (B (Open.X), B (Open.Y), Ground_Row, Wild_Vegetables);
            Changed_World;
         end if;
         Hours := 16.0 * 24.0;
         Place_Stake (Stake_P, 6, 42);
         Lay_Path ((20.5, 17.5, Ground_M), (40.0, 17.5, Ground_M), Laid);
         Zone_Stockpile (21.0, 15.0, 25.0, 17.0, Lots);
         Index_All;
         if Pass = 2 then
            Set_Job (1, Gatherer);
            for S in 1 .. 900 loop
               Run (1);
               exit when Vegetables_Pulled = 2;
            end loop;
            Set_Job (1, Unassigned);
         end if;
         Build_Paths_Now;
         Lay_Path ((44.0, 20.0, Ground_M), (44.0, 58.0, Ground_M), Laid);
         Build_Paths_Now;
         Zone_Housing (44.6, 22.0, 55.0, 43.0, Lots);
         Build_Homes_Now;
         declare
            V   : constant House_View := House_At (1);
            Ux  : constant Float := (V.Corner (2).X - V.Corner (1).X) / Flat (V.Corner (1), V.Corner (2));
            Uy  : constant Float := (V.Corner (2).Y - V.Corner (1).Y) / Flat (V.Corner (1), V.Corner (2));
            Ox  : constant Float := (V.Corner (1).X - V.Corner (4).X) / Flat (V.Corner (1), V.Corner (4));
            Oy  : constant Float := (V.Corner (1).Y - V.Corner (4).Y) / Flat (V.Corner (1), V.Corner (4));
         begin
            if Pass = 1 then
               --  under its front eave, the second block along from its corner
               Corner_1 := V.Corner (1);
               Eave := (V.Corner (1).X + 0.375 * Ux + 0.125 * Ox, V.Corner (1).Y + 0.375 * Uy + 0.125 * Oy, Ground_M);
            else
               Check (Vegetables_Pulled = 2 and then Flat (V.Corner (1), Corner_1) < 0.01
                      and then Get (B (Eave.X), B (Eave.Y), Ground_Row) = Air
                      and then Get (B (Eave.X), B (Eave.Y), Ground_Row - 1) in Grass | Dirt
                      and then House_On (Eave.X, Eave.Y) = 1,
                      "two vegetables pulled, and a house built since with the place of one under its eave");
               Hours := Hours + 11.0 * 24.0;
               Run (5);
               Check (Get (B (Eave.X), B (Eave.Y), Ground_Row) = Air
                      and then Get (B (Open.X), B (Open.Y), Ground_Row) = Wild_Vegetables,
                      "eleven days on the one pulled in the open has grown back; the one under the eave has not");
            end if;
         end;
      end loop;
   end;

   --  housing pulled along a path (John, 2026-11-12)
   Put_Line ("housing: pulled along a path, and combined where it meets housing:");
   Set_Up (With_Bushes => False, With_Labour => True);
   declare
      Laid, Lots, Lots_2, Cells : Natural;
      Z1, Blocks_1 : Natural;
      Data_Ok : Boolean;
      function Has (S, Part : String) return Boolean is (Ada.Strings.Fixed.Index (S, Part) > 0);
   begin
      Build_Paths_Now;
      --  58 m of path north (three stretches), a turn east at its end, and a path aslant off it
      Lay_Path ((44.0, 4.0, Ground_M), (44.0, 62.0, Ground_M), Laid);
      Lay_Path ((44.0, 62.0, Ground_M), (60.0, 62.0, Ground_M), Laid);
      Lay_Path ((44.0, 30.0, Ground_M), (58.0, 44.0, Ground_M), Laid);
      Build_Paths_Now;
      Check (Path_Count >= 5, "a path of 58 m is three stretches (" & Img (Path_Count) & " stretches in all)");
      --  (a zone north of the path's east leg, first, so that it has the lowest number of the housing)
      Zone_Housing (50.0, 63.0, 58.0, 63.0, Lots);
      Check (Housing_Refusal = "" and then Zone_On (54.0, 63.0) = Zone_Count and then Zone_On (54.0, 62.0) = 0,
             "housing begun north of a path's east leg and pulled 8 m along it");
      --  a strip shorter than a hovel
      Zone_Housing (43.0, 8.0, 43.0, 11.0, Lots);
      Z1 := Zone_Count;
      Blocks_1 := Zone_At (Z1).Blocks;
      Check (Housing_Refusal = "" and then Lots = 0 and then Zone_At (Z1).Kind = Habitation_Zone and then Blocks_1 > 300
             and then Zone_On (43.4, 9.0) = Z1 and then Zone_On (34.5, 9.0) = Z1 and then Zone_On (33.5, 9.0) = 0
             and then Zone_On (43.0, 7.5) = 0 and then Zone_On (43.0, 11.5) = 0 and then Housing_Joined = 0,
             "3 m pulled along a path is taken though no hovel fits on it: its ground from the path's edge "
             & Img (Float'(Housing_Deep_M), 1) & " m back (" & Img (Blocks_1) & " block columns), room for" & Lots'Image);
      --  pulled further from inside it: one zone, longer, across two joints of the path's stretches
      Zone_Housing (42.0, 10.0, 39.0, 50.0, Lots);
      Check (Housing_Refusal = "" and then Zone_Count = Z1 and then Housing_Joined = 1 and then Lots >= 5
             and then Zone_On (43.0, 9.0) = Z1 and then Zone_On (43.0, 30.0) = Z1 and then Zone_On (43.0, 49.5) = Z1
             and then Zone_On (43.0, 50.5) = 0 and then Zone_At (Z1).Blocks > 13 * Blocks_1,
             "pulled on from inside it to 42 m, over two joints of the path's stretches: the same zone, room for"
             & Lots'Image & " now");
      declare                                             --  (what a pull costs while it is shown, every frame)
         T0 : constant Time := Clock;
         P  : Lot_Plan;
      begin
         for K in 1 .. 100 loop
            P := Plan_Housing (45.0, 10.0, 46.0, 50.0 - 0.01 * Float (K), Count => False);
         end loop;
         Put ("    a pull of 40 m across the path from it, as it is shown each frame:"
              & Duration'Image (To_Duration (Clock - T0) * 10) (1 .. 6) & " ms a time (" & (if P.Ok then "taken" else "refused") & ")");
         declare
            T1 : constant Time := Clock;
         begin
            for K in 1 .. 20 loop
               P := Plan_Housing (45.0, 10.0, 46.0, 50.0 - 0.01 * Float (K));
            end loop;
            Put_Line ("; with its hovels counted, as at the click:" & Duration'Image (To_Duration (Clock - T1) * 50) (1 .. 6)
                      & " ms (" & Img (P.Cells) & ")");
         end;
      end;
      --  past the turn at the path's end: seven blocks and no further
      Zone_Housing (43.0, 55.0, 43.0, 90.0, Lots_2);
      Check (Housing_Refusal = "" and then Zone_Count = Z1 + 1 and then Housing_Joined = 0
             and then Zone_On (43.0, 61.0) = Z1 + 1 and then Zone_On (43.0, 63.5) = Z1 + 1 and then Zone_On (43.0, 64.0) = 0,
             "begun 5 m further on and pulled far past the path's turn: a zone of its own, ending "
             & Img (Natural'(Housing_Past_B)) & " blocks past the turn");
      --  the gap between the two closed by a pull that overlaps both: all one zone
      declare                                             --  (what the click costs: the zoning, and every lot laid out)
         T0 : constant Time := Clock;
      begin
         Zone_Housing (43.0, 48.0, 43.0, 57.0, Lots_2);
         Put_Line ("    the click that joins them, the lots of three housing zones laid out anew with it:"
                   & Duration'Image (To_Duration (Clock - T0) * 1000) (1 .. 6) & " ms (" & Img (Lot_Count)
                   & " lots in all)");
      end;
      Check (Housing_Refusal = "" and then Zone_Count = Z1 and then Housing_Joined = 2
             and then Zone_On (43.0, 9.0) = Z1 and then Zone_On (43.0, 53.0) = Z1 and then Zone_On (43.0, 63.0) = Z1
             and then Lots_2 >= Lots + 1,
             "a pull that overlaps both: the two are one zone, with what lay between them (room for" & Lots_2'Image & ")");
      --  a strip along the path aslant, meeting the straight one: combined
      Zone_Housing (47.0, 31.0, 56.0, 40.0, Lots);
      Check (Housing_Refusal = "" and then Housing_Joined = 0 and then Zone_Count = Z1 + 1
             and then Zone_On (51.0, 33.5) = Z1 + 1,
             "housing along a path that runs aslant, east of it (the straight zone is across the path): its own zone ("
             & Housing_Refusal & ")");
      Zone_Housing (47.0, 37.0, 56.0, 46.0, Lots);
      Check (Housing_Refusal = "" and then Housing_Joined = 0 and then Zone_Count = Z1 + 2,
             "and on the other side of the path aslant, another");
      Zone_Housing (44.8, 36.0, 44.8, 56.0, Lots);
      Check (Housing_Refusal = "" and then Housing_Joined = 1 and then Zone_Count = Z1 + 2
             and then Zone_On (46.0, 50.0) = Zone_On (52.0, 42.0) and then Zone_On (46.0, 50.0) > 0,
             "a straight strip pulled up the east side of the first path into the zone that lies aslant: combined with it");
      --  ground that is housing already
      Zone_Housing (43.0, 20.0, 43.0, 26.0, Lots);
      Check (Housing_Refusal /= "" and then Has (Housing_Refusal, "housing already") and then Zone_Count = Z1 + 2,
             "a pull over ground that is all housing already takes nothing: " & Housing_Refusal);
      --  houses, a stockpile and the camp keep their zones through a combining that does away with a zone
      declare
         Ok : Boolean;
         Zones_Then : Natural;
         Homes_West : Natural := 0;
      begin
         Zone_Stockpile (50.0, 60.0, 56.0, 61.4, Cells);
         Zone_Camp ((30.0, 40.0, Ground_M), Ok);
         Build_Homes_Now;
         Zones_Then := Zone_Count;
         for H in 1 .. House_Count loop
            if House_At (H).Zone = Z1 then
               Homes_West := Homes_West + 1;
            end if;
         end loop;
         Check (Ok and then Cells > 0 and then House_Count = 6 and then Homes_West >= 4
                and then Natural'(Castle.Colony.Camp_Zone) = Zone_Count and then Zone_Of_Cell (Cell_Count) = Zone_Count - 1
                and then Z1 = 3,
                "six hovels built (" & Img (Homes_West) & " of them on the zone west of the path, zone 3), and a stockpile"
                & " and the camp zoned after: zones " & Img (Zone_Count - 1) & " and " & Img (Zone_Count));
         --  north of the east leg again, pulled west past the turn: it overlaps the zone there (2) and
         --  touches the west zone's end past the turn (3): the three are one, zone 2, and zone 3 is gone
         Zone_Housing (52.0, 63.0, 42.0, 63.0, Lots);
         Check (Housing_Refusal = "" and then Housing_Joined = 2 and then Zone_Count = Zones_Then - 1
                and then Zone_On (54.0, 63.0) = 2 and then Zone_On (43.0, 30.0) = 2 and then Zone_On (47.0, 63.0) = 2,
                "a pull that overlaps one zone and touches another combines the three into the first: a zone fewer ("
                & Housing_Refusal & Housing_Joined'Image & ")");
         Check (Natural'(Castle.Colony.Camp_Zone) = Zone_Count and then Zone_At (Zone_Count).Kind = Zone_Kind'(Camp_Zone)
                and then Zone_Of_Cell (Cell_Count) = Zone_Count - 1 and then Zone_At (Zone_Count - 1).Kind = Stockpile_Zone
                and then (for all H in 1 .. House_Count =>
                            Zone_At (House_At (H).Zone).Kind = Habitation_Zone
                            and then Zone_On ((House_At (H).Corner (1).X + House_At (H).Corner (3).X) / 2.0,
                                              (House_At (H).Corner (1).Y + House_At (H).Corner (3).Y) / 2.0) = House_At (H).Zone),
                "the camp is still the camp's zone and the stockpile's places a stockpile's, each a number lower, and"
                & " every house stands on the zone it says it is of");
         Run (30);
         declare
            Data : constant Bytes := Save;
         begin
            Load (Data, Data_Ok);
            Check (Data_Ok and then Save = Data and then House_Count = 6
                   and then Zone_At (Natural'(Castle.Colony.Camp_Zone)).Kind = Zone_Kind'(Camp_Zone),
                   "half a minute on, it all comes back from a save to the same bytes");
         end;
      end;
   end;

   --  a strip pulled the length of a path never takes ground across the road that leads off its end
   --  (John, 2026-11-12: "a slice of the habitation zone passes over the connecting road")
   declare
      type Cols is array (0 .. W_B - 1, 0 .. W_B - 1) of Boolean;
      type Cols_Access is access Cols;
      Of_Zone : constant Cols_Access := new Cols;
      Seen    : constant Cols_Access := new Cols;
      type Spot is record
         X, Y : Integer;
      end record;
      type Spot_List is array (1 .. W_B * W_B) of Spot;
      type Spot_List_Access is access Spot_List;
      Queue : constant Spot_List_Access := new Spot_List;

      --  The block columns of zone Z, and how many pieces they lie in (a
      --  block at a time to the four sides).
      procedure Pieces_Of (Z : Positive; Blocks, Pieces : out Natural) is
         Head, Tail : Natural;
      begin
         Blocks := 0;
         Pieces := 0;
         Of_Zone.all := [others => [others => False]];
         Seen.all := [others => [others => False]];
         for K in 1 .. Zone_Runs (Z) loop
            declare
               R : constant Zone_Run := Zone_Run_At (Z, K);
            begin
               for X in R.X0 .. R.X1 loop
                  Of_Zone (X, R.Y) := True;
                  Blocks := Blocks + 1;
               end loop;
            end;
         end loop;
         for X0 in Cols'Range (1) loop
            for Y0 in Cols'Range (2) loop
               if Of_Zone (X0, Y0) and then not Seen (X0, Y0) then
                  Pieces := Pieces + 1;
                  Head := 0;
                  Tail := 1;
                  Queue (1) := (X0, Y0);
                  Seen (X0, Y0) := True;
                  while Head < Tail loop
                     Head := Head + 1;
                     for D in 1 .. 4 loop
                        declare
                           X : constant Integer := Queue (Head).X + (case D is when 1 => 1, when 2 => -1, when others => 0);
                           Y : constant Integer := Queue (Head).Y + (case D is when 3 => 1, when 4 => -1, when others => 0);
                        begin
                           if X in Cols'Range (1) and then Y in Cols'Range (2) and then Of_Zone (X, Y)
                             and then not Seen (X, Y)
                           then
                              Seen (X, Y) := True;
                              Tail := Tail + 1;
                              Queue (Tail) := (X, Y);
                           end if;
                        end;
                     end loop;
                  end loop;
               end if;
            end loop;
         end loop;
      end Pieces_Of;

      procedure Bare_Start is
      begin
         Reset;
         Set_Beds (False);
         Castle.Herds.Set_Scatter (True);
         Set_Labour (True);
         Set_Needs (False);
         Set_Skills (False);
         Set_Demand_Chain (False);
         Meadow;
         Hours := 16.0 * 24.0;
         Place_Stake ((4.0, 4.0, Ground_M), 12, 42);
      end Bare_Start;

      Ex : constant Float := 34.0;      --  where the path ends and the road leads off
      Ey : constant Float := 40.0;
      Split, Refused, Past_Lost, Past_Wanted : Natural := 0;
      Worst : Integer := 0;
      Laid, Lots, Blocks, Pieces : Natural;
   begin
      Put_Line ("housing: a strip and the road that leads off its path's end:");
      for Step in 1 .. 23 loop
         for Side in 1 .. 2 loop
            declare
               --  the road off the end: 15 degrees apart all the way round, but for straight on
               Th : constant Float := Float (Step) * 15.0 * 3.14159265 / 180.0;
               Sg : constant Float := (if Side = 1 then 1.0 else -1.0);
               --  (whether the road leads off on the strip's side of its path)
               Toward : constant Boolean := Sg * Sin (Th) > 0.01;
            begin
               Bare_Start;
               Lay_Path ((14.0, Ey, Ground_M), (Ex, Ey, Ground_M), Laid);
               Lay_Path ((Ex, Ey, Ground_M), (Ex + 18.0 * Cos (Th), Ey + 18.0 * Sin (Th), Ground_M), Laid);
               Build_Paths_Now;
               Index_All;
               --  begun at the path's far end, on one side of it, and pulled far past the end the road leads off
               Zone_Housing (15.0, Ey + Sg, 60.0, Ey + Sg, Lots);
               if Housing_Refusal /= "" then
                  Refused := Refused + 1;
               else
                  Pieces_Of (Zone_Count, Blocks, Pieces);
                  if Pieces /= 1 then
                     Split := Split + 1;
                     Worst := (if Side = 1 then 1 else -1) * 15 * Step;
                  end if;
                  --  where the road leads off the other way, the strip still runs its seven blocks past the end
                  if not Toward and then abs Sin (Th) > 0.3 then
                     Past_Wanted := Past_Wanted + 1;
                     if Zone_On (Ex + 1.0, Ey + 4.0 * Sg) /= Zone_Count then
                        Past_Lost := Past_Lost + 1;
                     end if;
                  end if;
               end if;
            end;
         end loop;
      end loop;
      Check (Refused = 0 and then Split = 0,
             "a path 20 m long with a road leading off its end at every angle, 15 degrees apart, housing pulled the"
             & " length of the path and past its end on either side: its ground is always in one piece, none of it"
             & " across the road (" & Img (Split) & " of 46 in more than one" & (if Split > 0 then ", the last with the road at"
             & Worst'Image & " degrees" else "") & ";" & Refused'Image & " refused)");
      Check (Past_Wanted > 0 and then Past_Lost = 0,
             "and where the road leads off on the other side of the path, the strip still runs past the end ("
             & Img (Past_Wanted - Past_Lost) & " of " & Img (Past_Wanted) & ")");
      --  the road square across the end, as his picture had it: nothing north of it
      Bare_Start;
      Lay_Path ((44.0, 10.0, Ground_M), (44.0, 40.0, Ground_M), Laid);
      Lay_Path ((44.0, 40.0, Ground_M), (60.0, 40.0, Ground_M), Laid);
      Build_Paths_Now;
      Index_All;
      Zone_Housing (45.0, 20.0, 45.0, 60.0, Lots);
      Check (Housing_Refusal = "" and then Zone_On (48.0, 38.0) = Zone_Count and then Zone_On (48.0, 41.0) = 0
             and then Zone_On (45.0, 41.2) = 0 and then Zone_On (52.0, 41.5) = 0,
             "a path north that turns east at its end, housing pulled up its east side and past the turn: its ground"
             & " comes up to the road east and none of it lies north of that road");
      --  a side road part way along: the strip goes on beyond it, on both sides of it
      Bare_Start;
      Lay_Path ((10.0, 30.0, Ground_M), (30.0, 30.0, Ground_M), Laid);
      Lay_Path ((30.0, 30.0, Ground_M), (50.0, 30.0, Ground_M), Laid);
      Lay_Path ((30.0, 30.0, Ground_M), (30.0, 50.0, Ground_M), Laid);
      Build_Paths_Now;
      Index_All;
      Zone_Housing (12.0, 31.0, 46.0, 31.0, Lots);
      Pieces_Of (Zone_Count, Blocks, Pieces);
      Check (Housing_Refusal = "" and then Pieces = 2 and then Zone_On (20.0, 35.0) = Zone_Count
             and then Zone_On (40.0, 35.0) = Zone_Count and then Zone_On (30.0, 35.0) = 0,
             "a side road that leaves the strip's own path part way along it: the strip goes on beyond it, its ground"
             & " on both sides of the side road (" & Img (Pieces) & " pieces) and none of it on the road");

      --  all the ground inside a round of paths (John, 2026-11-12: "it would be nice if player had a fill
      --  option for closed loop paths")
      Put_Line ("housing: all the ground inside a round of paths:");
      declare
         function Has (S, Part : String) return Boolean is (Ada.Strings.Fixed.Index (S, Part) > 0);
         --  four paths round a square, corner to corner (Sides: how many of them are laid, Short: the
         --  last stops that far from its corner)
         procedure Round (Sides : Positive := 4; Short : Float := 0.0) is
            C : constant array (1 .. 5) of Vec3 :=
              [(12.0, 12.0, Ground_M), (52.0, 12.0, Ground_M), (52.0, 52.0, Ground_M), (12.0, 52.0, Ground_M),
               (12.0, 12.0 + Short, Ground_M)];
         begin
            Bare_Start;
            for K in 1 .. Sides loop
               Lay_Path (C (K), C (K + 1), Laid);
            end loop;
            Build_Paths_Now;
            Index_All;
         end Round;
         Zones_Then, Lots_In, Cells : Natural;
         R : Castle.Actions.Result;
         M : Castle.Actions.Menu;
         Offered : Boolean := False;
         use Castle.Actions;
      begin
         Round;
         declare
            T0 : constant Time := Clock;
            P  : constant Lot_Plan := Plan_Housing_Inside (30.0, 34.0);
         begin
            Put_Line ("    39 m square inside four paths, as it would be taken:" & Duration'Image (To_Duration (Clock - T0) * 1000) (1 .. 6)
                      & " ms with its hovels counted (" & Img (P.Cells) & ")");
            Check (P.Ok and then Zone_Count = 0 and then P.Blocks = 156 * 156,
                   "what filling it would take is worked out with nothing changed: " & Img (P.Blocks)
                   & " block columns, 39 m by 39 m");
         end;
         Zone_Housing_Inside (30.0, 34.0, Lots_In);
         Pieces_Of (Zone_Count, Blocks, Pieces);
         Check (Housing_Refusal = "" and then Zone_Count = 1 and then Zone_At (1).Kind = Habitation_Zone and then Pieces = 1
                and then Blocks = 156 * 156 and then Zone_On (32.0, 32.0) = 1 and then Zone_On (12.8, 12.8) = 1
                and then Zone_On (51.2, 51.2) = 1 and then Zone_On (11.2, 32.0) = 0 and then Zone_On (53.0, 32.0) = 0
                and then Zone_On (32.0, 12.0) = 0 and then not On_Path (32.0, 32.0) and then Lots_In >= 8,
                "four paths round a square of 40 m, and the ground inside them filled from one point: one zone, all"
                & " of it inside, from path to path and its middle 19 m from any of them (" & Img (Blocks)
                & " block columns), room for" & Lots_In'Image & " hovels along the four paths");
         Build_Homes_Now;
         Check (House_Count = 12
                and then (for all H in 1 .. House_Count =>
                            House_At (H).Phase = Standing and then House_At (H).Zone = 1
                            and then Castle.Nav."=" (Castle.Nav.Plan ((4.0, 4.0, Ground_M), House_At (H).Bed).Result,
                                                     Castle.Nav.Found)),
                "the band's twelve hovels built on it, every one on the zone, its bed got to from outside");
         declare
            Data : constant Bytes := Save;
            Ok   : Boolean;
         begin
            Load (Data, Ok);
            Check (Ok and then Save = Data and then Zone_On (32.0, 32.0) = 1, "and it comes back from a save to the same bytes");
         end;
         --  not closed: three sides, and four with a gap of two metres
         Round (Sides => 3);
         Zone_Housing_Inside (30.0, 34.0, Lots_In);
         Check (Housing_Refusal /= "" and then Has (Housing_Refusal, "do not close") and then Zone_Count = 0,
                "with one side of the square open nothing is taken: " & Housing_Refusal);
         Round (Short => 2.0);
         Zone_Housing_Inside (30.0, 34.0, Lots_In);
         Check (Housing_Refusal /= "" and then Has (Housing_Refusal, "do not close") and then Zone_Count = 0,
                "nor with a gap of a metre and a half between the last path and the first");
         --  begun on a path, and on a stockpile
         Round;
         Zone_Stockpile (13.0, 13.0, 17.0, 15.0, Cells);
         Zones_Then := Zone_Count;
         Zone_Housing_Inside (32.0, 12.0, Lots_In);
         Check (Housing_Refusal /= "" and then Zone_Count = Zones_Then, "begun on a path it is refused: " & Housing_Refusal);
         Zone_Housing_Inside (15.0, 14.0, Lots_In);
         Check (Housing_Refusal /= "" and then Zone_Count = Zones_Then and then Cells > 0,
                "and begun on a stockpile: " & Housing_Refusal);
         --  a stockpile and a strip of housing inside it: the stockpile stays, the strip is combined with it
         Zone_Housing (20.0, 51.0, 40.0, 51.0, Lots);
         Check (Housing_Refusal = "" and then Zone_Count = Zones_Then + 1, "a strip of housing along the north path, inside");
         Perform ((What => Fill_Housing, By => 2, Inside => (30.0, 30.0, 0.0)), R);
         Check (not R.Done and then R.Why = Not_Permitted and then Zone_Count = Zones_Then + 1,
                "a serf may not fill it: " & Why_Not ((What => Fill_Housing, By => 2, Inside => (30.0, 30.0, 0.0)), R));
         Perform ((What => Fill_Housing, By => The_Player, Inside => (30.0, 30.0, 0.0)), R);
         Pieces_Of (Zone_Count, Blocks, Pieces);
         Check (R.Done and then Housing_Joined = 1 and then Zone_Count = Zones_Then + 1
                and then Zone_On (30.0, 48.0) = Zone_Count and then Zone_On (30.0, 30.0) = Zone_Count
                and then Zone_At (Zone_On (15.0, 14.0)).Kind = Stockpile_Zone and then Pieces = 1
                and then Blocks < 156 * 156 and then R.Count >= 8,
                "the player fills the rest through the action: the strip and the filling are one zone, the stockpile"
                & " still a stockpile, room for" & R.Count'Image & " hovels");
         M := Menu_For (The_Player, (The_Ground, 0, (30.0, 30.0, Ground_M)));
         for K in 1 .. M.N loop
            Offered := Offered or else (M.Items (K).Todo.What = Fill_Housing and then not M.Items (K).Two_Point
                                        and then Str (M.Items (K).Label) = "Housing inside these paths");
         end loop;
         Check (Offered, "the ground's menu offers it: Housing inside these paths");
      end;
   end;

   --  a strip one pull long holds hovels beside a path at any angle
   declare
      Least : Natural := Natural'Last;
      Worst : Integer := 0;
   begin
      for Step in 0 .. 24 loop
         declare
            Th : constant Float := Float (Step) * 7.5 * 3.14159265 / 180.0;
            Cx : constant Float := 32.0;
            Cy : constant Float := 36.0;
            Tx : constant Float := Cos (Th);
            Ty : constant Float := Sin (Th);
            Laid, L1 : Natural;
         begin
            for Side in 1 .. 2 loop             --  (each side by itself: the next hovels in turn, as they are)
               declare
                  Sg : constant Float := (if Side = 1 then 1.0 else -1.0);
               begin
                  Reset;
                  Set_Beds (False);
                  Castle.Herds.Set_Scatter (True);
                  Set_Labour (True);
                  Set_Needs (False);
                  Set_Skills (False);
                  Set_Demand_Chain (False);
                  Meadow;
                  Hours := 16.0 * 24.0;
                  Place_Stake ((4.0, 4.0, Ground_M), 12, 42);
                  Lay_Path ((Cx - 14.0 * Tx, Cy - 14.0 * Ty, Ground_M), (Cx + 14.0 * Tx, Cy + 14.0 * Ty, Ground_M), Laid);
                  Build_Paths_Now;
                  Index_All;
                  Zone_Housing (Cx - 14.0 * Tx - Sg * Ty, Cy - 14.0 * Ty + Sg * Tx, Cx + 14.0 * Tx, Cy + 14.0 * Ty, L1);
                  if L1 < Least then
                     Least := L1;
                     Worst := Integer (7.5 * Float (Step));
                  end if;
               end;
            end loop;
         end;
      end loop;
      Check (Least >= 2,
             "beside a path at every angle, 7.5 degrees apart all the way round, 28 m of housing on either side of it has"
             & " room for the next two hovels in turn or more (the fewest:" & Least'Image & ", at" & Worst'Image
             & " degrees)");
   end;

   --  the steepest hillside a lot may lie on (2 m in 7 m), a path across it at every angle
   declare
      Least : Natural := Natural'Last;
      Worst : Integer := 0;
      Homes, Stones, Most, Ways_Bad, Bare_All, Steps_All, One_Side, Sides, Raw, Proud : Natural := 0;
      All_Lots : Boolean := True;
      Earth_Then, Earth_Gone, Earth_Homes, Earth_Stone : Integer := 0;
      Spots, Pits : Natural := 0;
   begin
      for Step in 0 .. 23 loop
         declare
            Th : constant Float := Float (Step) * 15.0 * 3.14159265 / 180.0;
            Cx : constant Float := 32.0;
            Cy : constant Float := 36.0;
            Tx : constant Float := Cos (Th);
            Ty : constant Float := Sin (Th);
            Laid, L1, L2 : Natural;
            function Zg (X : Float) return Float is
              (Ground_M + 0.25 * Float'Max (0.0, Float'Floor ((X - 6.0) / 0.875)));
         begin
            Reset;
            Set_Beds (False);
            Castle.Herds.Set_Scatter (True);
            Set_Labour (True);
            Set_Needs (False);
            Set_Skills (False);
            Set_Demand_Chain (False);
            Meadow;
            for K in 1 .. 40 loop
               Fill (6.0 + 0.875 * Float (K), 0.0, 64.0, 64.0, Ground_Row + K - 2, Ground_Row + K - 2, Dirt);
               Fill (6.0 + 0.875 * Float (K), 0.0, 64.0, 64.0, Ground_Row + K - 1, Ground_Row + K - 1, Grass);
            end loop;
            Changed_World;
            Hours := 16.0 * 24.0;
            Place_Stake ((4.0, 4.0, Ground_M), 12, 42);
            Lay_Path ((Cx - 14.0 * Tx, Cy - 14.0 * Ty, Zg (Cx - 14.0 * Tx)), (Cx + 14.0 * Tx, Cy + 14.0 * Ty, Zg (Cx + 14.0 * Tx)), Laid);
            Build_Paths_Now;
            Index_All;
            Zone_Housing (Cx - 14.0 * Tx - 1.0 * Ty, Cy - 14.0 * Ty + 1.0 * Tx, Cx + 14.0 * Tx, Cy + 14.0 * Ty, L1);
            Zone_Housing (Cx - 14.0 * Tx + 1.0 * Ty, Cy - 14.0 * Ty - 1.0 * Tx, Cx + 14.0 * Tx, Cy + 14.0 * Ty, L2);
            if Lot_Count < Least then
               Least := Lot_Count;
               Worst := 15 * Step;
            end if;
            if L2 = 0 then
               One_Side := One_Side + 1;        --  (the hovel next in turn stands on neither side there)
            end if;
            All_Lots := All_Lots and then L1 >= 2 and then Lots_Short and then Lot_Count >= L1;
            if Step = 6 then                    --  (a path along the hillside: how much earth its hovels move)
               Earth_Then := Count_In (0, 0, W_B - 1, W_B - 1, 1, H_B - 2, Dirt) + Count_In (0, 0, W_B - 1, W_B - 1, 1, H_B - 2, Grass);
            end if;
            Build_Homes_Now;
            if Step = 6 then
               Earth_Gone := Earth_Then - Count_In (0, 0, W_B - 1, W_B - 1, 1, H_B - 2, Dirt)
                 - Count_In (0, 0, W_B - 1, W_B - 1, 1, H_B - 2, Grass);
               Earth_Homes := House_Count;
               for H in 1 .. House_Count loop
                  Earth_Stone := Earth_Stone + House_At (H).Got (Stone);
                  Count_Pits (H, Spots, Pits);
               end loop;
            end if;
            Homes := Homes + House_Count;
            for H in 1 .. House_Count loop
               declare
                  S1, B1 : Natural;
               begin
                  Count_Steps (H, S1, B1);
                  Count_Joins (H, Sides, Raw, Proud);
                  Steps_All := Steps_All + S1;
                  Bare_All := Bare_All + B1;
                  Stones := Stones + House_At (H).Got (Stone);
                  Most := Natural'Max (Most, House_At (H).Got (Stone));
                  if not Castle.Nav."=" (Castle.Nav.Plan (Stake, House_At (H).Bed).Result, Castle.Nav.Found) then
                     Ways_Bad := Ways_Bad + 1;
                  end if;
               end;
            end loop;
         end;
      end loop;
      Check (Least >= 3 and then All_Lots,
             "on ground that falls 2 m in 7, beside a path at every angle 15 degrees apart, 28 m of housing on both sides"
             & " has room for the next three hovels in turn or more (the fewest:" & Least'Image & ", at" & Worst'Image
             & " degrees); no hovel is passed over for a smaller: at " & Img (One_Side) & " of the 24 angles the one next"
             & " in turn after the first side's fits nowhere, and the second side holds none");
      Check (Homes >= 90 and then Ways_Bad = 0 and then Bare_All = 0 and then Steps_All > 10_000,
             "the " & Img (Homes) & " hovels built on it: a way from the stake to every bed (" & Img (Ways_Bad)
             & " without), and every step of more than a block round them walled (" & Img (Bare_All) & " of "
             & Img (Steps_All) & " bare); " & Img (Stones) & " stones in all, " & Img (Most) & " the most to one");
      Check (Sides >= 40 and then Raw = 0 and then Proud = 0,
             "where one was begun beside an earlier one (" & Img (Sides) & " sides) the ground between them is made one: "
             & Img (Raw) & " columns of it left as they lay, " & Img (Proud) & " columns of stone left standing proud");
      Check (Spots > 1_500 and then Pits = 0,
             "in and round the " & Img (Earth_Homes) & " along the hillside, above the path and below it, there is a way to"
             & " the stake from every spot a serf can get to (" & Img (Spots) & " half a metre apart, " & Img (Pits)
             & " with none): no yard is a pit");
      Put_Line ("    along the hillside, " & Img (Earth_Homes) & " hovels above and below the path: " & Img (Earth_Gone)
                & " blocks of earth fewer in the ground (dug off and thrown aside, or stone where earth was), "
                & Img (Earth_Stone) & " stones");
   end;

   ------------------------------------------------------------------ beds
   Put_Line ("beds: straw for one once the camp stands, and another in a house of its own:");

   --  cut by their own hands, with none in store
   Set_Up (With_Bushes => False, With_Porter_Ground => True, With_Needs => True, With_Labour => True, With_Beds => True);
   Hours := 16.0 * 24.0 + 7.0;
   declare
      use Castle.Views;
      Camp_At : constant Vec3 := (27.0, 38.0, Ground_M);
      Ok : Boolean;
      Placed : Natural;
      Grass_Then : Natural;
      function Grass_Now return Natural is
        (Count_In (B (Grass_X0) - 1, B (Grass_Y0) - 1, B (Grass_X1) + 1, B (Grass_Y1) + 1, Ground_Row, Ground_Row, Tall_Grass));
      function Says (I : Positive; Part : String) return Boolean is
        (Ada.Strings.Fixed.Index (Status (I), Part) > 0);
      function Straw_Carried return Natural is
         N : Natural := 0;
      begin
         for I in 1 .. Members loop
            if Carrying (I) = Straw then
               N := N + Carried (I);
            end if;
         end loop;
         return N;
      end Straw_Carried;
      function With_Beds return Natural is
         N : Natural := 0;
      begin
         for I in 1 .. Members loop
            if Has_Bed (I) then
               N := N + 1;
            end if;
         end loop;
         return N;
      end With_Beds;
      Early, Saw_Cut, Saw_Carry, Saw_Make, Counted, Took : Boolean := False;
      Done_At : Natural := 0;
      type Feet_List is array (1 .. 6) of Vec3;
      Feet : Feet_List;
   begin
      Supply (Berries, 600, Placed);
      Zone_Camp (Camp_At, Ok);
      Grass_Then := Grass_Now;
      Run (30);
      Early := (for some I in 1 .. Members => Says (I, "bed") or else Has_Bed (I)) or else Straw_In_Beds > 0;
      Build_Camp_Now;
      Counted := True;
      for S in 1 .. 600 loop
         Run (1);
         Saw_Cut := Saw_Cut or else (for some I in 1 .. Members => Says (I, "cutting straw for its bed"));
         Saw_Carry := Saw_Carry or else (for some I in 1 .. Members => Says (I, "carrying straw to where it sleeps"));
         Saw_Make := Saw_Make or else (for some I in 1 .. Members => Says (I, "making its bed"));
         Took := Took or else (for some I in 1 .. Members => Says (I, "fetching straw for its bed"));
         Counted := Counted and then Grass_Then - Grass_Now = Straw_Carried + Straw_In_Beds + Stored (Straw);
         if With_Beds = 6 then
            Done_At := S;
            exit;
         end if;
      end loop;
      Check (Ok and then Grass_Then > 100 and then not Early,
             "while its camp is not built nobody makes a bed");
      Check (Done_At > 0 and then Saw_Cut and then Saw_Carry and then Saw_Make and then not Took
             and then Straw_In_Beds = 6 * Bed_Straw,
             "once it stands, with no straw in store, each cuts its own and makes its bed where it sleeps (all six in "
             & Img (Done_At) & " game minutes, " & Img (Straw_In_Beds) & " sheaves)");
      Check (Counted and then Grass_Then - Grass_Now = 6 * Bed_Straw,
             "every sheaf cut is carried, in a bed or stored, at every second (" & Img (Grass_Then - Grass_Now)
             & " plants cut: a bed's worth each and no more)");
      for I in 1 .. 6 loop
         Feet (I) := Camp_Bed (I).Feet;
      end loop;
      Check ((for all I in 1 .. 6 =>
                Camp_Bed (I).Made and then Flat (Feet (I), Camp) in 3.0 .. 6.0
                and then Get (B (Feet (I).X), B (Feet (I).Y), Ground_Row) = Air
                and then (for all J in 1 .. 6 => J = I or else Flat (Feet (I), Feet (J)) > 1.0)
                and then Value_Of (Person (I), "Bed") = "of straw, by the fire"),
             "the six beds lie round the fire, each its maker's own place, and its sheet says so");
      declare
         --  how far off square to the way to the fire each lies (the cosine: 0 is square), and the
         --  nearest and the furthest middle
         Off_Most, Near, Far : Float := 0.0;
      begin
         Near := Float'Last;
         for I in 1 .. 6 loop
            declare
               V  : constant Bed_View := Camp_Bed (I);
               Ux : constant Float := V.Toward.X - V.Feet.X;
               Uy : constant Float := V.Toward.Y - V.Feet.Y;
               Mx : constant Float := V.Feet.X - Ux - Camp.X;          --  its middle, from the fire
               My : constant Float := V.Feet.Y - Uy - Camp.Y;
               R  : constant Float := Sqrt (Mx * Mx + My * My);
            begin
               Off_Most := Float'Max (Off_Most, abs (Ux * Mx + Uy * My) / Float'Max (0.01, R));
               Near := Float'Min (Near, R);
               Far := Float'Max (Far, R);
            end;
         end loop;
         Check ((for all I in 1 .. 6 => Camp_Bed (I).By_Fire and then Sleeping_Place (I).By_Fire)
                and then Off_Most < 0.02 and then Near >= Float'(Bed_Near_M) - 0.01 and then Far <= Float'(Bed_Near_M) + 0.51,
                "each lies across the way to the fire (John: ""slept perpendicular to the fire""), its middle "
                & Img (Near, 1) & " to " & Img (Far, 1) & " m from it: clear of the camp's floor, and as near as six can lie");
      end;
      Hours := 16.0 * 24.0 + 20.0;
      Run (240);                                          --  to midnight
      Check ((for all I in 1 .. 6 => Asleep (I) and then Flat (Where (I), Feet (I)) < 0.05),
             "at midnight each is asleep on its own: on it, not beside it");
      declare
         Data : constant Bytes := Save;
         Ok2 : Boolean;
      begin
         Reset;
         Load (Data, Ok2);
         Check (Ok2 and then Save = Data and then Beds and then Straw_In_Beds = 6 * Bed_Straw
                and then (for all I in 1 .. 6 => Camp_Bed (I).Made and then Camp_Bed (I).Feet = Feet (I)),
                "beds come back from a save to the same bytes");
      end;
   end;

   --  from the stockpile, when it has straw to spare; a house's bed; the old one stays
   Set_Up (With_Bushes => False, With_Porter_Ground => True, With_Needs => True, With_Labour => True, With_Beds => True);
   Hours := 16.0 * 24.0 + 7.0;
   declare
      use Castle.Views;
      Ok : Boolean;
      Placed, Laid, Lots : Natural;
      Grass_Then : Natural;
      function Grass_Now return Natural is
        (Count_In (B (Grass_X0) - 1, B (Grass_Y0) - 1, B (Grass_X1) + 1, B (Grass_Y1) + 1, Ground_Row, Ground_Row, Tall_Grass));
      function Says (I : Positive; Part : String) return Boolean is
        (Ada.Strings.Fixed.Index (Status (I), Part) > 0);
      function Straw_Carried return Natural is
         N : Natural := 0;
      begin
         for I in 1 .. Members loop
            if Carrying (I) = Straw then
               N := N + Carried (I);
            end if;
         end loop;
         return N;
      end Straw_Carried;
      function With_Beds return Natural is
         N : Natural := 0;
      begin
         for I in 1 .. Members loop
            if Has_Bed (I) then
               N := N + 1;
            end if;
         end loop;
         return N;
      end With_Beds;
      Saw_Take, Saw_Cut, Counted : Boolean := False;
      Done_At : Natural := 0;
      type Feet_List is array (1 .. 6) of Vec3;
      Feet : Feet_List;
      Saved_Once : Boolean := False;
      Same_Bytes, Same_After : Boolean := False;
   begin
      Supply (Berries, 400, Placed);
      Supply (Straw, 40, Placed);
      Build_Paths_Now;
      Lay_Path ((44.0, 20.0, Ground_M), (44.0, 58.0, Ground_M), Laid);
      Build_Paths_Now;
      Zone_Camp ((27.0, 38.0, Ground_M), Ok);
      Build_Camp_Now;
      Grass_Then := Grass_Now;
      Counted := Placed = 40;
      for S in 1 .. 600 loop
         Run (1);
         Saw_Take := Saw_Take or else (for some I in 1 .. Members => Says (I, "fetching straw for its bed"));
         Saw_Cut := Saw_Cut or else (for some I in 1 .. Members => Says (I, "cutting straw"));
         Counted := Counted and then Stored (Straw) + Straw_Carried + Straw_In_Beds = 40;
         if not Saved_Once and then (for some I in 1 .. Members => Says (I, "carrying straw to where it sleeps")) then
            Saved_Once := True;
            declare
               Snap : Snapshot;
               Saved_Hours : constant Long_Float := Hours;
               Data : constant Bytes := Save;
               Ok2 : Boolean;
            begin
               Take (Snap);
               Run (120);
               declare
                  A : constant Bytes := Save;
               begin
                  Give_Back (Snap);
                  Hours := Saved_Hours;
                  Load (Data, Ok2);
                  Same_Bytes := Ok2 and then Save = Data;
                  Run (120);
                  Same_After := Save = A;
               end;
            end;
         end if;
         if With_Beds = 6 then
            Done_At := S;
            exit;
         end if;
      end loop;
      Check (Ok and then Done_At > 0 and then Saw_Take and then not Saw_Cut and then Grass_Now = Grass_Then
             and then Straw_In_Beds = 6 * Bed_Straw and then Stored (Straw) = 40 - 6 * Bed_Straw,
             "with straw in store each fetches its bed's worth from the stockpile and cuts none (all six in "
             & Img (Done_At) & " game minutes, " & Img (Stored (Straw)) & " sheaves left of 40)");
      Check (Counted, "every sheaf is stored, carried or in a bed, at every second");
      Check (Saved_Once and then Same_Bytes and then Same_After,
             "a save taken with straw on its way to a bed loads back the same, and two hours on the colony is where it"
             & " would have been");
      for I in 1 .. 6 loop
         Feet (I) := Camp_Bed (I).Feet;
      end loop;
      --  hovels for some of them: a second bed, in the house; the first stays where it was made
      Zone_Housing (44.6, 22.0, 55.0, 43.0, Lots);
      Build_Homes_Now;
      Check (Lots in 2 .. 3 and then House_Count = Lots
             and then (for all H in 1 .. House_Count => not House_At (H).Has_Bed and then not Has_Bed (House_At (H).Owner))
             and then With_Beds = 6 - Lots
             and then (for all H in 1 .. House_Count =>
                         Value_Of (Person (House_At (H).Owner), "Bed") = "none yet: it sleeps on its floor"),
             "a hovel drawn has no bed in it: its owner has one to make again (" & Img (Lots) & " hovels)");
      Done_At := 0;
      for S in 1 .. 600 loop
         Run (1);
         Counted := Counted and then Stored (Straw) + Straw_Carried + Straw_In_Beds = 40;
         if With_Beds = 6 then
            Done_At := S;
            exit;
         end if;
      end loop;
      Check (Done_At > 0 and then Counted and then Straw_In_Beds = (6 + Lots) * Bed_Straw
             and then (for all H in 1 .. House_Count =>
                         House_At (H).Has_Bed
                         and then Value_Of (Person (House_At (H).Owner), "Bed") = "of straw, in its hovel")
             and then (for all I in 1 .. 6 => Camp_Bed (I).Made and then Camp_Bed (I).Feet = Feet (I)),
             "each makes itself a new bed in its hovel (" & Img (Done_At) & " game minutes); the one it made by the fire"
             & " lies where it was");
      Hours := 16.0 * 24.0 + 20.0;
      Run (240);                                          --  to midnight
      Check ((for all I in 1 .. 6 =>
                Asleep (I)
                and then (if Housed (I) then At_Home (I) and then Flat (Where (I), House_At (Home_Of (I)).Bed) < 0.05
                          else Flat (Where (I), Feet (I)) < 0.05)),
             "at midnight those with a hovel sleep on the bed in it, the rest on theirs by the fire");
   end;

   --  a hunter home with a kill and nowhere to butcher it puts it down when it is hungry (it stood with
   --  the deer in its arms until there was room, starving: seen in the stage 6 run at the pace of
   --  2026-11-12, when the band filled its one stockpile)
   Put_Line ("a hunter with a kill and every place of the stockpile taken:");
   Set_Up (With_Needs => True, With_Bushes => False);
   Hours := 16.0 * 24.0 + 7.0;
   Set_Job (1, Hunter);
   declare
      Placed, Cells : Natural;
      Got, Stood, Lay, Starved, Took_Again : Boolean := False;
      Put_Down_At : Natural := 0;
      Fed_Least : Float := 1.0;
      function A_Kill_Lies return Boolean is
        (for some K in 1 .. Carcass_Count => Carcass_Used (K) and then Carcass_At (K).Lying);
   begin
      for S in 1 .. 1_800 loop
         Run (1);
         exit when Status (1) = "going for the kill";
      end loop;
      Supply (Berries, 100_000, Placed);                  --  (every place taken, with berries, as it goes for its kill)
      for S in 1 .. 12 * 60 loop
         Run (1);
         Fed_Least := Float'Min (Fed_Least, Fed_Of (1));
         Starved := Starved or else Fed_Of (1) <= 0.0;
         Got := Got or else Carrying (1) = Carcass;
         Stood := Stood or else Ada.Strings.Fixed.Index (Status (1), "nowhere to put a deer") > 0;
         if Got and then Carrying (1) /= Carcass then
            Put_Down_At := S;
            Lay := A_Kill_Lies;
            exit;
         end if;
      end loop;
      Check (Got and then Placed > 0 and then Stood and then Put_Down_At > 0 and then Lay and then not Starved
             and then Stored (Meat) = 0 and then Fed_Least < Float'(Hungry_At) + 0.01,
             "it stands with its kill while it can; hungry, it puts the deer down to see to itself (" & Img (Put_Down_At)
             & " game minutes on, at " & Img (100.0 * Fed_Least, 0) & " % fed)");
      for S in 1 .. 60 loop
         Run (1);
         Fed_Least := Float'Min (Fed_Least, Fed_Of (1));
         Took_Again := Took_Again or else (Carrying (1) = Carcass and then Stored (Meat) = 0 and then Fed_Of (1) < Float'(Hungry_At));
      end loop;
      Zone_Stockpile (27.0, 15.0, 31.0, 17.0, Cells);
      for S in 1 .. 600 loop
         Run (1);
         Fed_Least := Float'Min (Fed_Least, Fed_Of (1));
         exit when Stored (Meat) > 0 and then not A_Kill_Lies;
      end loop;
      Check (Cells > 0 and then Stored (Meat) > 0 and then Stored (Hide) >= 1 and then not A_Kill_Lies
             and then not Took_Again and then Fed_Least > 0.2,
             "it eats, and with somewhere to butcher it again the kill is fetched and butchered (" & Img (Stored (Meat))
             & " meat; never under " & Img (100.0 * Fed_Least, 0) & " % fed)");
   end;

   --  a ladder for the roof (John, 2026-11-12: "serfs building spend a lot of time walking around the house
   --  thatching, can we have them construct a ladder in the stockpile, and use the ladder to thatch roofs"):
   --  one forester building two hovels on the flat with everything supplied, with ladders and without
   Put_Line ("a ladder for the roof:");
   declare
      type Outcome is record
         First, Second  : Natural := 0;        --  game minutes to the first hovel standing, and the second
         Roof_Walk, Roof_Work : Natural := 0;  --  minutes the builder was going to its work, and at it, with a roof next
         Made, Stored_After : Natural := 0;    --  ladders made; stored with the first hovel standing and its builder gone on
         Added_Up, Made_At_Pile, Carried_There, Up, Taken_Again, Felled_For_It : Boolean := False;
         Still_Up : Boolean := True;           --  aloft, it stood where the ladder's foot was
         Bytes_Same : Boolean := True;
      end record;
      --  (Bare_Wood: no more wood in the stores than the first hovel's frame takes, and that hovel alone)
      function Built (With_Ladders : Boolean; Bare_Wood : Boolean := False; Trees : Boolean := False) return Outcome is
         R : Outcome;
         Laid, Lots, Placed : Natural;
         Saved : Boolean := False;
      begin
         Set_Up (With_Bushes => False, With_Trees => Trees);
         Set_Ladders (With_Ladders);
         Lay_Path ((44.0, 20.0, Ground_M), (44.0, 58.0, Ground_M), Laid);
         Zone_Housing (44.6, 22.0, 55.0, 43.0, Lots);
         Set_Job (3, Forester);
         Supply (Straw, 120, Placed);
         if Bare_Wood then
            Run (3);                                       --  (the first hovel begun: what its frame takes is known)
            Supply (Wood, (if House_Count >= 1 then House_At (1).Takes (Wood) else 0), Placed);
         else
            Supply (Wood, 30, Placed);
         end if;
         R.Added_Up := True;
         for S in 1 .. 9_000 loop
            Run (1);
            R.Added_Up := R.Added_Up and then Ladders_Add_Up;
            if Status (3) = "making a ladder" then
               R.Made_At_Pile := R.Made_At_Pile or else (for some K in 1 .. Cell_Count => Flat (Where (3), Cell_At (K).Centre) < 1.0);
            end if;
            R.Carried_There := R.Carried_There or else Ada.Strings.Fixed.Index (Status (3), "carrying the ladder to") = 1;
            R.Felled_For_It := R.Felled_For_It
              or else (Site_Of (3) > 0 and then House_At (Site_Of (3)).Phase = Roofing and then Status (3) = "felling a tree");
            R.Taken_Again := R.Taken_Again
              or else (R.First > 0 and then Ada.Strings.Fixed.Index (Status (3), "fetching a ladder for") = 1);
            if Aloft (3) then
               R.Up := True;
               R.Still_Up := R.Still_Up and then Flat (Where (3), Ladder_At (Site_Of (3)).Foot) < 0.75
                 and then Shown_At (3).Z > Where (3).Z + 1.0;
               if not Saved then                           --  (a save taken with its builder up the ladder)
                  Saved := True;
                  declare
                     Data : constant Bytes := Save;
                     Ok   : Boolean;
                  begin
                     Load (Data, Ok);
                     R.Bytes_Same := Ok and then Save = Data and then Aloft (3) and then Ladders;
                  end;
               end if;
            end if;
            if Site_Of (3) > 0 and then House_At (Site_Of (3)).Phase in Roofing | Trimming then
               if Ada.Strings.Fixed.Index (Status (3), "going to work on") = 1 then
                  R.Roof_Walk := R.Roof_Walk + 1;
               elsif Ada.Strings.Fixed.Index (Status (3), "thatching") = 1 or else Ada.Strings.Fixed.Index (Status (3), "trimming") = 1 then
                  R.Roof_Work := R.Roof_Work + 1;
               end if;
            end if;
            if R.First = 0 and then House_Count >= 1 and then House_At (1).Phase = Standing then
               R.First := S;
            end if;
            if R.First > 0 and then S = R.First + 240 then
               R.Stored_After := Stored (Ladder);
            end if;
            if House_Count >= 2 and then House_At (2).Phase = Standing then
               R.Second := S;
               exit;
            end if;
            exit when Bare_Wood and then R.First > 0;
         end loop;
         R.Made := Ladders_Made;
         return R;
      end Built;
      With_It : constant Outcome := Built (True);
      Without : constant Outcome := Built (False);
      No_Wood : constant Outcome := Built (True, Bare_Wood => True);
      Fells   : constant Outcome := Built (True, Bare_Wood => True, Trees => True);
   begin
      Put_Line ("    with ladders: the hovels stand" & With_It.First'Image & " and" & With_It.Second'Image
                & " game minutes on; at the roofs" & With_It.Roof_Work'Image & " minutes at work," & With_It.Roof_Walk'Image
                & " walking to it;" & With_It.Made'Image & " made");
      Put_Line ("    without:      the hovels stand" & Without.First'Image & " and" & Without.Second'Image
                & " game minutes on; at the roofs" & Without.Roof_Work'Image & " minutes at work," & Without.Roof_Walk'Image
                & " walking to it;" & Without.Made'Image & " made");
      Check (With_It.Made = 1 and then With_It.Made_At_Pile and then With_It.Carried_There and then With_It.Up
             and then With_It.Still_Up and then With_It.Added_Up,
             "with a roof next its builder makes a ladder at the stockpile, of a log, carries it to the house and thatches"
             & " from it, up on its rungs; the ladder is stored, carried or standing at every second");
      Check (With_It.Second > 0 and then Without.Second > 0 and then Without.Roof_Walk > 100
             and then With_It.Roof_Walk * 10 < Without.Roof_Walk and then With_It.Second < Without.Second,
             "from the ladder it lays bout after bout without walking: " & Img (With_It.Roof_Walk)
             & " game minutes going to its work at the two roofs, where from the ground it was " & Img (Without.Roof_Walk)
             & "; the two hovels stand in " & Img (With_It.Second) & " game minutes, not " & Img (Without.Second));
      Check (With_It.Stored_After = 1 and then With_It.Taken_Again,
             "the hovel built, the ladder goes back to a stockpile, and is fetched from there for the next roof (one made"
             & " for the two)");
      Check (With_It.Bytes_Same, "a save taken with the builder up the ladder loads back to the same bytes, the builder up it still");
      Check (Without.Made = 0 and then not Without.Up and then Without.Added_Up,
             "(with ladders off none is made: every roof from the ground, as it was)");
      Check (Fells.Made = 1 and then Fells.Felled_For_It and then Fells.Made_At_Pile and then Fells.Up and then Fells.First > 0
             and then Fells.Roof_Walk < 40 and then Fells.Added_Up,
             "with no log in the stores when the roof comes, its builder fells a tree for one, and the first log it brings"
             & " home is made into the ladder there (" & Img (Fells.Roof_Walk) & " game minutes going to its work at the roof)");
      Check (No_Wood.Made = 0 and then No_Wood.First > 0 and then No_Wood.Roof_Walk > 100 and then not No_Wood.Up,
             "with no log in the stores and no tree to fell, the roof is thatched from the ground as it was: the hovel stands ("
             & Img (No_Wood.First) & " game minutes, " & Img (No_Wood.Roof_Walk) & " of them going to its work at the roof)");
   end;

   --  a hovel half built whose builder is given other work is taken up by a builder whose own hovel is not so
   --  far on (John, 2026-11-13: "I removed the cook from cooking, he started building a house, the build was
   --  asigned to him, I then sent him back to cooking mid build and it didn't free up the assignment for the
   --  build"): two foresters building two hovels on the flat, and the one further on is sent to cook; then the
   --  same with the one behind sent away, whose hovel the other leaves be
   Put_Line ("a builder given other work mid build:");
   declare
      type Outcome is record
         Ahead, Behind : Natural := 0;          --  the hovel further on and the other, when the one is sent away
         Took_Up : Natural := 0;                --  game minutes until the other forester was at the one left
         Stood, Back_To_Own, Kept_Own : Boolean := False;
      end record;
      function Sent_Away (Ahead_One : Boolean) return Outcome is
         R : Outcome;
         Laid, Lots, Placed : Natural;
         Off, Other, At_S : Natural := 0;
      begin
         Set_Up (With_Bushes => False);
         Set_Ladders (True);
         Lay_Path ((44.0, 20.0, Ground_M), (44.0, 58.0, Ground_M), Laid);
         Zone_Housing (44.6, 22.0, 55.0, 43.0, Lots);
         Set_Job (3, Forester);
         Set_Job (4, Forester);
         Supply (Straw, 200, Placed);
         Supply (Wood, 40, Placed);
         R.Kept_Own := not Ahead_One;
         for S in 1 .. 20_000 loop
            Run (1);
            if Off = 0 then
               if Site_Of (3) > 0 and then Site_Of (4) > 0 and then Site_Of (3) /= Site_Of (4)
                 and then House_At (Site_Of (3)).Placed /= House_At (Site_Of (4)).Placed
                 and then (for some J in 3 .. 4 => House_At (Site_Of (J)).Phase = Roofing)
               then
                  declare
                     Three_On : constant Boolean := House_At (Site_Of (3)).Placed > House_At (Site_Of (4)).Placed;
                  begin
                     Off := (if Three_On = Ahead_One then 3 else 4);
                     Other := 7 - Off;
                     R.Ahead := Site_Of (if Three_On then 3 else 4);
                     R.Behind := Site_Of (if Three_On then 4 else 3);
                     Set_Job (Off, Cook);
                     At_S := S;
                  end;
               end if;
            elsif Ahead_One then
               if R.Took_Up = 0 and then Site_Of (Other) = R.Ahead then
                  R.Took_Up := S - At_S;
               end if;
               if not R.Stood and then House_At (R.Ahead).Phase = Standing then
                  R.Stood := True;
               end if;
               if R.Stood and then Site_Of (Other) = R.Behind then
                  R.Back_To_Own := True;
                  exit;
               end if;
            else
               R.Kept_Own := R.Kept_Own and then Site_Of (Other) = R.Ahead;
               exit when S >= At_S + 600;
            end if;
         end loop;
         return R;
      end Sent_Away;
      Ahead_Off  : constant Outcome := Sent_Away (Ahead_One => True);
      Behind_Off : constant Outcome := Sent_Away (Ahead_One => False);
   begin
      Check (Ahead_Off.Ahead > 0 and then Ahead_Off.Took_Up in 1 .. 180 and then Ahead_Off.Stood
             and then Ahead_Off.Back_To_Own,
             "its builder sent to cook with the roof on, the other forester leaves its own hovel, not so far on, for"
             & " that one (" & Img (Ahead_Off.Took_Up) & " game minutes later), and goes back to its own when it"
             & " stands");
      Check (Behind_Off.Ahead > 0 and then Behind_Off.Kept_Own,
             "the builder of the hovel behind sent away instead, the one further on is finished first (its builder"
             & " stays at it ten hours)");
   end;

   --  a hovel's lot of level ground with a couple of holes in it: the holes are filled, the lot is not dug
   --  down to their bottoms (John, 2026-11-13: "othewise even ground was dug out entirely becuase it had a
   --  couple of holes in it, instead of just filling the holes")
   Put_Line ("a lot with a couple of holes in it:");
   declare
      Laid, Lots, Placed : Natural;
      Lot : Lot_Corners;
      Hx, Hy : array (1 .. 3) of Integer;
      Ready_At : Natural := 0;
      Filled, No_Float : Boolean := True;
   begin
      --  where the first hovel stands on the meadow as it is
      Set_Up (With_Bushes => False);
      Lay_Path ((44.0, 20.0, Ground_M), (44.0, 58.0, Ground_M), Laid);
      Zone_Housing (44.6, 22.0, 55.0, 43.0, Lots);
      Set_Job (3, Forester);
      Run (3);
      Lot := House_At (1).Corner;
      --  and the same with three holes a block deep inside its walls, one of two columns, one of one (with
      --  grass left in the air over it, as a dig leaves it) and one of four by four
      for K in 1 .. 3 loop
         Hx (K) := Integer (Float'Floor ((Lot (1).X + (Lot (3).X - Lot (1).X) * (case K is when 1 => 0.3, when 2 => 0.65,
                                                                                         when others => 0.4)) * 4.0));
         Hy (K) := Integer (Float'Floor ((Lot (1).Y + (Lot (3).Y - Lot (1).Y) * (case K is when 1 => 0.4, when 2 => 0.7,
                                                                                         when others => 0.15)) * 4.0));
      end loop;
      Set_Up (With_Bushes => False);
      Test_World.Set (Hx (1), Hy (1), Ground_Row - 1, Air);
      Test_World.Set (Hx (1) + 1, Hy (1), Ground_Row - 1, Air);
      Test_World.Set (Hx (2), Hy (2), Ground_Row - 1, Air);
      Test_World.Set (Hx (2), Hy (2), Ground_Row, Tall_Grass);
      for X in Hx (3) .. Hx (3) + 3 loop
         for Y in Hy (3) .. Hy (3) + 3 loop
            Test_World.Set (X, Y, Ground_Row - 1, Air);
         end loop;
      end loop;
      Test_World.Changed_World;
      Lay_Path ((44.0, 20.0, Ground_M), (44.0, 58.0, Ground_M), Laid);
      Zone_Housing (44.6, 22.0, 55.0, 43.0, Lots);
      Set_Job (3, Forester);
      Supply (Straw, 60, Placed);
      Supply (Wood, 10, Placed);
      for S in 1 .. 3_000 loop
         Run (1);
         if House_Count >= 1 and then House_At (1).Phase /= Ground then
            Ready_At := S;
            exit;
         end if;
      end loop;
      for K in 1 .. 2 loop
         Filled := Filled and then Test_World.Get (Hx (K), Hy (K), Ground_Row - 1) /= Air;
      end loop;
      Filled := Filled and then Test_World.Get (Hx (1) + 1, Hy (1), Ground_Row - 1) /= Air;
      for X in Hx (3) .. Hx (3) + 3 loop
         for Y in Hy (3) .. Hy (3) + 3 loop
            Filled := Filled and then Test_World.Get (X, Y, Ground_Row - 1) /= Air;
         end loop;
      end loop;
      for X in B (Lot (1).X) - 2 .. B (Lot (3).X) + 2 loop      --  nothing of a plant over air on or round the lot
         for Y in B (Lot (1).Y) - 2 .. B (Lot (3).Y) + 2 loop
            for Z in Ground_Row - 1 .. Ground_Row + 2 loop
               No_Float := No_Float and then not (Test_World.Get (X, Y, Z) in Tall_Grass | Wild_Grain | Wild_Vegetables
                                                  and then Test_World.Get (X, Y, Z - 1) = Air);
            end loop;
         end loop;
      end loop;
      Check (House_Count >= 1 and then abs (House_At (1).Corner (1).Z - Lot (1).Z) < 0.01 and then Ready_At > 0
             and then Filled and then No_Float,
             "its floor is where the ground lies (" & Img (House_At (1).Corner (1).Z, 2) & " m, as on the lot without"
             & " them) and the holes, one of them four by four, are filled with the turf cut off it, the grass over one"
             & " cut: ready in " & Img (Ready_At) & " game minutes");
   end;

   --  the lord's cart, salt, and meat by the pound (John, 2026-11-12: "60lbs of field dressed meat from a
   --  deer that should be enough to feed a camp for a couple of days when smoked or cured ... lets just add
   --  a cart with salt in it for curing")
   Put_Line ("the lord's cart:");
   Set_Up (With_Curing => True);
   Set_Job (1, Hunter);
   declare
      None_Yet : constant Boolean := not Cart.Here;
      C  : Cart_View;
      Ok, At_Cart_Seen, Counted : Boolean := True;
      Laid : Natural;
      L, W, X0, Y0 : Integer;
      Far : Vec3;
      Round_It : Castle.Nav.Route;
      Salt_Used : Natural := 0;
      Class_Lb, Meat_Before : Natural := 0;
      function Salt_Carried return Natural is
         N : Natural := 0;
      begin
         for I in 1 .. Members loop
            if Carrying (I) = Salt then
               N := N + Carried (I);
            end if;
         end loop;
         return N;
      end Salt_Carried;
   begin
      Run (1);
      C := Cart;
      L := (if C.Along_X then Cart_Long_B else Cart_Wide_B);
      W := (if C.Along_X then Cart_Wide_B else Cart_Long_B);
      X0 := B (C.At_P.X) - L / 2;
      Y0 := B (C.At_P.Y) - W / 2;
      Far := C.At_P + (C.At_P - Cart_Beside);
      Round_It := Castle.Nav.Plan (Cart_Beside, Far);
      Check (None_Yet and then C.Here and then C.Salt = Cart_Salt_Lb
             and then Flat (C.At_P, Stake) >= Float'(Cart_Near_M) - 0.3 and then Flat (C.At_P, Stake) <= Float'(Cart_Far_M)
             and then Count_In (X0, Y0, X0 + L - 1, Y0 + W - 1, Ground_Row - 1 + Cart_Up_B, Ground_Row - 1 + Cart_Up_B, Log) = L * W
             and then Castle.Nav."=" (Castle.Nav.Plan (Stake, Cart_Beside).Result, Castle.Nav.Found),
             "it comes with the band: at the first step it stands " & Img (Flat (C.At_P, Stake), 1) & " m from the stake with "
             & Img (C.Salt) & " lb of salt in it, its bed" & Natural'Image (L * W) & " blocks of timber over the ground, and there is"
             & " a way to stand beside it");
      Check (Castle.Views.Value_Of (Castle.Views.Cart, "Salt") = "240 lb"
             and then Castle.Views.Value_Of (Castle.Views.Cart, "In the stores") = "none",
             "its sheet says what is in it (Salt: " & Castle.Views.Value_Of (Castle.Views.Cart, "Salt") & ")");
      Check (Castle.Nav."=" (Round_It.Result, Castle.Nav.Found) and then Castle.Nav.Length (Round_It) > 3.0
             and then Cart_On (C.At_P.X, C.At_P.Y) and then not Cart_On (Cart_Beside.X, Cart_Beside.Y),
             "nobody walks through it: from one side of it to the other is " & Img (Castle.Nav.Length (Round_It), 1)
             & " m round, not " & Img (Flat (Cart_Beside, Far), 1) & " across");
      Zone_Camp ((C.At_P.X, C.At_P.Y, Ground_M), Ok);
      Check (not Ok and then Ada.Strings.Fixed.Index (Camp_Refusal, "cart") > 0,
             "a camp marked over it is refused: " & Camp_Refusal);
      Zone_Camp ((C.At_P.X + 3.0, C.At_P.Y + 3.0, Ground_M), Ok);       --  (its square reaches a corner of the cart)
      Check (not Ok and then Ada.Strings.Fixed.Index (Camp_Refusal, "cart") > 0, "and one whose square would take a corner of it");
      Lay_Path ((C.At_P.X - 5.0, C.At_P.Y + 0.1, Ground_M), (C.At_P.X + 5.0, C.At_P.Y + 0.1, Ground_M), Laid);
      Check (Laid = 0 and then Ada.Strings.Fixed.Index (Path_Refusal, "cart") > 0
             and then Count_In (X0, Y0, X0 + L - 1, Y0 + W - 1, Ground_Row - 1 + Cart_Up_B, Ground_Row - 1 + Cart_Up_B, Log) = L * W,
             "a path through it is refused: " & Path_Refusal);
      Lay_Path ((C.At_P.X - 5.0, C.At_P.Y + 2.5, Ground_M), (C.At_P.X + 5.0, C.At_P.Y + 2.5, Ground_M), Laid);
      Check (Laid > 0 and then Path_Refusal = "", "one two and a half metres past it is laid");
      declare
         Cells_N : Natural;
         On_It   : Natural := 0;
         Cells_0 : constant Natural := Cell_Count;
      begin
         Zone_Stockpile (C.At_P.X - 3.0, C.At_P.Y - 1.5, C.At_P.X + 3.0, C.At_P.Y + 1.7, Cells_N);
         for K in Cells_0 + 1 .. Cell_Count loop
            if Cart_On (Cell_At (K).Centre.X, Cell_At (K).Centre.Y) then
               On_It := On_It + 1;
            end if;
         end loop;
         Check (Cells_N > 4 and then On_It = 0
                and then Count_In (X0, Y0, X0 + L - 1, Y0 + W - 1, Ground_Row - 1 + Cart_Up_B, Ground_Row - 1 + Cart_Up_B, Log) = L * W,
                "a stockpile marked across it takes the ground round it and none of its own (" & Img (Cells_N)
                & " places, none under the cart)");
      end;
      --  the hunter keeps salt by: a sackful from the cart to the stockpile before it goes after deer
      for S in 1 .. 600 loop
         Run (1);
         At_Cart_Seen := At_Cart_Seen or else Status (1) = "going to the lord's cart for salt";
         Counted := Counted and then Cart.Salt + Stored (Salt) + Salt_Carried = Cart_Salt_Lb;
         exit when Stored (Salt) > 0;
      end loop;
      Check (Castle.Views.Value_Of (Castle.Views.Demand, "Salt") = "20, not asked for"
             and then not Demand_For (Salt).Asked and then not Demand_For (Ladder).Asked,
             "salt in store is on the stores' sheet as kept, never as asked for ('"
             & Castle.Views.Value_Of (Castle.Views.Demand, "Salt") & "')");
      Check (Stored (Salt) = Carry_Limit (Salt) and then Cart.Salt = Cart_Salt_Lb - Carry_Limit (Salt) and then Counted,
             "a hunter keeps salt by for its kills: a sackful (" & Img (Stored (Salt)) & " lb) from the cart to the stockpile"
             & " before it goes after deer; every pound in the cart, on a shoulder or stored");
      --  its first kill, salted as it is butchered
      for S in 1 .. 3_600 loop
         Run (1);
         for K in 1 .. Carcass_Count loop
            if Carcass_Used (K) then
               Class_Lb := Deer_Lb (Carcass_At (K).Class);
            end if;
         end loop;
         exit when Stored (Meat) > 0;
      end loop;
      Salt_Used := Cart_Salt_Lb - Cart.Salt - Stored (Salt) - Salt_Carried;
      Check (Class_Lb > 0 and then Stored (Meat) = Class_Lb and then Salt_Used = Salt_For (Class_Lb)
             and then Deer_Salted = 1 and then Deer_Unsalted = 0 and then Meat_Lost = 0 and then Stored (Hide) = 1,
             "its kill is salted as it is butchered: all" & Class_Lb'Image & " lb of it kept, for" & Salt_Used'Image
             & " lb of the salt");
      Meat_Before := Stored (Meat);
      declare
         Data : constant Bytes := Save;
         Salt_Then : constant Natural := Cart.Salt;
         At_Then   : constant Vec3 := Cart.At_P;
         Loaded : Boolean;
      begin
         Load (Data, Loaded);
         Check (Loaded and then Save = Data and then Cart.Here and then Cart.Salt = Salt_Then
                and then Flat (Cart.At_P, At_Then) < 0.01 and then Stored (Meat) = Meat_Before and then Curing
                and then Deer_Salted = 1,
                "a save with the cart in it loads back to the same" & Data'Length'Image & " bytes, the cart where it stood with"
                & Salt_Then'Image & " lb in it");
      end;
   end;
   --  what is marked before the first step is not stood on: a camp where the cart would have gone
   Set_Up (With_Curing => True);
   declare
      Ok : Boolean;
      C  : Cart_View;
      Clear : Boolean := True;
   begin
      Zone_Camp ((20.0, 25.0, Ground_M), Ok);
      Run (1);
      C := Cart;
      for Dx in -5 .. 5 loop
         for Dy in -3 .. 3 loop
            Clear := Clear and then Zone_On (C.At_P.X + 0.25 * Float (Dx), C.At_P.Y + 0.25 * Float (Dy)) = 0
              and then not On_Path (C.At_P.X + 0.25 * Float (Dx), C.At_P.Y + 0.25 * Float (Dy));
         end loop;
      end loop;
      Check (Ok and then C.Here and then Clear and then Flat (C.At_P, (20.0, 25.0, 0.0)) > 3.5 + 0.5,
             "with a camp marked north of the stake before the band's first step, the cart stands clear of it ("
             & Img (C.At_P.X, 1) & ", " & Img (C.At_P.Y, 1) & "), on no zone's ground and no path's");
   end;
   --  housing along a path that passes the cart: no hovel's lot over it, and it stands when they are built
   Set_Up (With_Curing => True, With_Stockpile => False);
   declare
      C : Cart_View;
      Laid, Lots : Natural;
      Over : Natural := 0;
      X0, Y0, L, W : Integer;
   begin
      Run (1);
      C := Cart;
      L := (if C.Along_X then Cart_Long_B else Cart_Wide_B);
      W := (if C.Along_X then Cart_Wide_B else Cart_Long_B);
      X0 := B (C.At_P.X) - L / 2;
      Y0 := B (C.At_P.Y) - W / 2;
      Lay_Path ((C.At_P.X - 14.0, C.At_P.Y + 3.0, Ground_M), (C.At_P.X + 20.0, C.At_P.Y + 3.0, Ground_M), Laid);
      Build_Paths_Now;
      Zone_Housing (C.At_P.X - 12.0, C.At_P.Y + 2.0, C.At_P.X + 18.0, C.At_P.Y + 2.0, Lots);
      for K in 1 .. Lot_Count loop
         declare
            Q : constant Lot_Corners := Lot_At (K);
            Lx : constant Float := Float'Min (Float'Min (Q (1).X, Q (2).X), Float'Min (Q (3).X, Q (4).X)) - 0.5;
            Hx : constant Float := Float'Max (Float'Max (Q (1).X, Q (2).X), Float'Max (Q (3).X, Q (4).X)) + 0.5;
            Ly : constant Float := Float'Min (Float'Min (Q (1).Y, Q (2).Y), Float'Min (Q (3).Y, Q (4).Y)) - 0.5;
            Hy : constant Float := Float'Max (Float'Max (Q (1).Y, Q (2).Y), Float'Max (Q (3).Y, Q (4).Y)) + 0.5;
         begin
            if C.At_P.X + 1.0 > Lx and then C.At_P.X - 1.0 < Hx and then C.At_P.Y + 0.5 > Ly and then C.At_P.Y - 0.5 < Hy then
               Over := Over + 1;
            end if;
         end;
      end loop;
      Build_Homes_Now;
      Check (Laid > 0 and then Lots >= 2 and then Over = 0 and then House_Count >= 2
             and then Count_In (X0, Y0, X0 + L - 1, Y0 + W - 1, Ground_Row - 1 + Cart_Up_B, Ground_Row - 1 + Cart_Up_B, Log) = L * W
             and then Castle.Nav."=" (Castle.Nav.Plan (Stake, Cart_Beside).Result, Castle.Nav.Found),
             "housing marked along a path past the cart: " & Img (Lots) & " lots laid out, none over it; with the hovels"
             & " built it stands as it did, and there is still a way to it");
   end;
   --  idle hands stroll round the stake, where the cart stands: a stroll toward the cart ends beside it
   --  (a goal under its bed has no ground, and the way to one was searched for over all the band's ground)
   Set_Up (With_Curing => True, With_Bushes => False);
   declare
      On_It : Natural := 0;
      T     : Castle.Nav.Totals_Rec;
   begin
      for I in 1 .. Members loop
         Set_Job (I, Unassigned);
      end loop;
      Run (2);
      Castle.Nav.Reset_Totals;
      for S in 1 .. 3_000 loop
         Run (1);
         for I in 1 .. Members loop           --  (under its bed itself: 2 m by 1 m)
            if abs (Where (I).X - Cart.At_P.X) < (if Cart.Along_X then 0.95 else 0.45)
              and then abs (Where (I).Y - Cart.At_P.Y) < (if Cart.Along_X then 0.45 else 0.95)
            then
               On_It := On_It + 1;
            end if;
         end loop;
      end loop;
      T := Castle.Nav.Totals;
      Check (Cart.Here and then T.Plans > 300 and then T.Short_Plans = 0 and then T.Spent_Plans = 0 and then On_It = 0,
             "fifty game hours of six idle hands strolling round the stake: " & Img (T.Plans) & " ways planned, none"
             & " toward a place under the cart (" & Img (T.Short_Plans) & " ended short of where they were to go, "
             & Img (T.Spent_Plans) & " ran out of budget), nobody ever under its bed (" & Img (On_It) & ")");
   end;
   --  what a doe is worth: sixty pounds stored, a camp and a cook
   Set_Up (With_Curing => True, With_Needs => True);
   declare
      Ok : Boolean;
      Placed : Natural;
      Days_Before : Float;
   begin
      Zone_Camp ((30.0, 24.0, Ground_M), Ok);
      Set_Job (1, Cook);
      Run (1);
      Days_Before := Food_Days;
      Supply (Meat, Deer_Lb (Castle.Deer.Doe), Placed);
      Check (Ok and then Placed = 60 and then Days_Before = 0.0 and then Food_Days > 1.9 and then Food_Days < 2.2
             and then Stew_Food (Meat) = Pound_Stew and then Carry_Limit (Meat) = Meat_Load_Lb
             and then Cell_Limit (Meat) = Meat_Cell_Lb,
             "a doe's sixty pounds are two days' food for the six (" & Img (Food_Days, 2) & " days: a pound is"
             & Natural'Image (Stew_Food (Meat)) & " points in the pot, and six eat 1,392 a day)");
   end;
   --  with no salt to be had, only what is eaten before it turns is kept
   Set_Up (With_Curing => True);
   Set_Cart_Salt (0);
   Set_Job (1, Hunter);
   declare
      Class_Lb : Natural := 0;
      Went : Boolean := False;
   begin
      for S in 1 .. 3_600 loop
         Run (1);
         Went := Went or else Ada.Strings.Fixed.Index (Status (1), "cart") > 0;
         for K in 1 .. Carcass_Count loop
            if Carcass_Used (K) then
               Class_Lb := Deer_Lb (Carcass_At (K).Class);
            end if;
         end loop;
         exit when Stored (Meat) > 0;
      end loop;
      Check (Class_Lb > 0 and then Stored (Meat) = Class_Lb / Fresh_Div and then Deer_Unsalted = 1 and then Deer_Salted = 0
             and then Meat_Lost = Class_Lb - Class_Lb / Fresh_Div and then not Went and then Cart.Here and then Cart.Salt = 0,
             "with no salt in the cart nobody goes to it, and of a kill's" & Class_Lb'Image & " lb only"
             & Natural'Image (Stored (Meat)) & " are kept: what is eaten before the rest turns");
      Check (Kept_Of (60, 6) = 60 and then Kept_Of (60, 0) = 15 and then Kept_Of (60, 3) = 37 and then Kept_Of (75, 8) = 75
             and then Salt_For (60) = 6 and then Salt_For (75) = 8 and then Salt_For (20) = 2,
             "(a pound of salt to ten of meat; with half the salt a doe wants, half of her is salted and a quarter of the rest kept)");
   end;
   --  and with curing off there is no cart: the band as it was
   Set_Up;
   Run (5);
   Check (not Cart.Here and then not Curing and then Carry_Limit (Meat) = 4 and then Cell_Limit (Meat) = 20
          and then Stew_Food (Meat) = 30,
          "with curing off there is no cart, and meat is in joints: four to a load, twenty to a place, thirty points in the pot");

   --  the lord's cart pulled into the stockpile nearest it (John, 2026-11-13: "the cart, can they pull it into
   --  the closest stockpile zone?"): by one of the band, with its labour on; its bed in the world when it
   --  stands and nowhere while it is in tow, at every second; through a save in tow, its puller given
   --  another job in tow, and with the pull off
   Put_Line ("the lord's cart pulled into the stockpile:");
   declare
      Bed_Row : constant Integer := Ground_Row - 1 + Cart_Up_B;
      --  its bed: every block of it in the world while it stands, none while it is in tow (counted over
      --  whatever of timber stood at that row before it came)
      Base : Natural := 0;
      function Bed_Blocks return Natural is (Count_In (0, 0, W_B - 1, W_B - 1, Bed_Row, Bed_Row, Log) - Base);
      function One_Place return Boolean is
        (Cart.Here and then (if Cart.Towed then Bed_Blocks = 0 else Bed_Blocks = Cart_Long_B * Cart_Wide_B));
      type Outcome is record
         Seen_Towed, In_Store, Always_One, Bytes_Same, Put_Down : Boolean := False;
         By     : Natural := 0;
         Took   : Natural := 0;        --  game minutes until it stood in the stockpile
         From   : Vec3 := (0.0, 0.0, 0.0);
      end record;
      function Pulled (Pull : Boolean; Save_In_Tow, Call_Off : Boolean := False) return Outcome is
         R : Outcome;
         Saved, Called : Boolean := False;
      begin
         Set_Up (With_Curing => True, With_Labour => True, With_Bushes => False);
         Set_Cart_Pull (Pull);
         Base := 0;
         Base := Bed_Blocks;
         Run (1);
         R.From := Cart.At_P;
         R.Always_One := One_Place;
         for S in 1 .. 240 loop
            Run (1);
            R.Always_One := R.Always_One and then One_Place;
            if Cart.Towed then
               R.Seen_Towed := True;
               R.By := Cart.By;
               if Save_In_Tow and then not Saved then
                  Saved := True;
                  declare
                     Data : constant Bytes := Save;
                     Ok   : Boolean;
                  begin
                     Load (Data, Ok);
                     R.Bytes_Same := Ok and then Save = Data and then Cart.Towed;
                  end;
               end if;
               if Call_Off and then not Called then
                  Called := True;
                  Set_Job (Cart.By, Hunter);
                  Run (1);
                  R.Put_Down := Cart.Here and then not Cart.Towed and then One_Place;
               end if;
            end if;
            if R.Took = 0 and then Cart_In_Stockpile then
               R.Took := S;
               R.In_Store := True;
            end if;
            exit when R.In_Store and then S > R.Took + 5;
         end loop;
         return R;
      end Pulled;
      Pull    : constant Outcome := Pulled (True);
   begin
      declare
         C : constant Cart_View := Cart;
         Under, Reach_Ok : Natural := 0;
         Placed : Natural;
         All_Reach : Boolean := True;
      begin
         --  the stockpile filled: nothing put under it, and every other place got to from the stake
         Supply (Berries, 5_000, Placed);
         for K in 1 .. Cell_Count loop
            if C.Here and then abs (Cell_At (K).Centre.X - C.At_P.X) < (if C.Along_X then 1.0 else 0.5)
              and then abs (Cell_At (K).Centre.Y - C.At_P.Y) < (if C.Along_X then 0.5 else 1.0)
            then
               Under := Under + (if Cell_At (K).Count = 0 then 1 else 0);
            elsif Castle.Nav."=" (Castle.Nav.Plan (Stake_P, Cell_At (K).Centre).Result, Castle.Nav.Found) then
               Reach_Ok := Reach_Ok + 1;
            else
               All_Reach := False;
            end if;
         end loop;
         Check (Pull.Seen_Towed and then Pull.In_Store and then Pull.Always_One and then Pull.By > 0
                and then Flat (Pull.From, C.At_P) > 2.0 and then not C.Towed,
                "with a stockpile zoned, one of the band takes up the cart's shafts and pulls it into it ("
                & Img (Pull.Took) & " game minutes; " & Img (Flat (Pull.From, C.At_P), 1) & " m): at every second its bed"
                & " is in the world while it stands and nowhere while it is in tow");
         Check (Under = 2 and then All_Reach and then Placed > 0
                and then Castle.Nav."=" (Castle.Nav.Plan (Stake, Cart_Beside).Result, Castle.Nav.Found),
                "it stands on two of the stockpile's places, and with the rest of it filled nothing is put under it; every"
                & " other place (" & Img (Reach_Ok) & ") and beside the cart are got to from the stake");
      end;
      declare
         Saved_In_Tow : constant Outcome := Pulled (True, Save_In_Tow => True);
         Called_Off   : constant Outcome := Pulled (True, Call_Off => True);
         Left_Be      : constant Outcome := Pulled (False);
      begin
         Check (Saved_In_Tow.Bytes_Same and then Saved_In_Tow.In_Store and then Saved_In_Tow.Always_One,
                "a save taken with the cart in tow loads back to the same bytes, in tow still, and it is pulled in");
         Check (Called_Off.Put_Down and then Called_Off.In_Store and then Called_Off.Always_One,
                "its puller given another job in tow, it is set down at once, its bed in the world; then pulled in by"
                & " another (" & Img (Called_Off.Took) & " game minutes in all)");
         Check (not Left_Be.Seen_Towed and then not Left_Be.In_Store and then Left_Be.Always_One,
                "(with the pull off it stays where it stood, as it did)");
      end;
   end;

   --  the band's pace (John, 2026-11-12: "also can we increase the work and travel speed of serfs by
   --  about 50%"): a colony is founded working and walking half as fast again; hunger, the clock and
   --  what an hour's work teaches are as they were
   Put_Line ("the band's pace:");
   declare
      type Outcome is record
         Trip_S         : Natural := 0;        --  seconds to the first berries stored
         Fed, Skill     : Float := 0.0;        --  a belly after four hours; gathering learnt in an hour's picking
         Pace           : Float := 0.0;
         Bytes_Same     : Boolean := False;
      end record;
      function Tried (At_Pace : Float) return Outcome is
         R : Outcome;
         Skill_0 : Float;
      begin
         Set_Up (With_Needs => True, With_Skills => True);
         Set_Pace (At_Pace);
         R.Pace := Pace;
         Hours := 16.0 * 24.0 + 7.0;
         Set_Job (2, Gatherer);
         Skill_0 := Skill_Of (2, Gathering);
         for S in 1 .. 600 loop
            Run (1);
            if Stored (Berries) > 0 then
               R.Trip_S := S;
               exit;
            end if;
         end loop;
         Run (240 - R.Trip_S);
         R.Fed := Fed_Of (5);
         R.Skill := Skill_Of (2, Gathering) - Skill_0;
         declare
            Data : constant Bytes := Save;
            Ok   : Boolean;
         begin
            Load (Data, Ok);
            R.Bytes_Same := Ok and then Save = Data and then Pace = R.Pace;
         end;
         return R;
      end Tried;
      Old : constant Outcome := Tried (1.0);
      Now : constant Outcome := Tried (Serf_Pace);
      Founded : Float;
   begin
      Castle.Colony.Reset;                     --  (as a colony is founded: nothing set)
      Founded := Pace;
      Check (Founded = Float'(Serf_Pace) and then Now.Pace = Founded and then Old.Pace = 1.0 and then Now.Pace > Old.Pace,
             "a colony is founded at a pace of " & Img (Founded, 1) & " (it was 1)");
      Check (Old.Trip_S > 0 and then Now.Trip_S > 0
             and then Float (Now.Trip_S) in 0.55 * Float (Old.Trip_S) .. 0.8 * Float (Old.Trip_S),
             "a gatherer's first trip, out to a bush, a basket picked and home: " & Img (Now.Trip_S) & " game minutes, "
             & Img (Old.Trip_S) & " at the old pace");
      Check (abs (Now.Fed - Old.Fed) < 0.02,
             "four hours on, one with nothing to eat is as hungry as it was at the old pace (" & Img (100.0 * Now.Fed, 0)
             & " % fed, " & Img (100.0 * Old.Fed, 0) & " %): hunger goes by the clock");
      Check (Now.Skill > 0.0 and then abs (Now.Skill - Old.Skill) < 0.15 * Old.Skill,
             "and four hours at the work teach what they taught (" & Img (1000.0 * Now.Skill, 1) & " thousandths of"
             & " gathering, " & Img (1000.0 * Old.Skill, 1) & "): an hour's practice is an hour's");
      Check (Now.Bytes_Same and then Old.Bytes_Same, "the pace is saved with the colony, and comes back with it");
   end;

   --  a camp on a hillside: each finds level ground for itself, across the way to the fire (John,
   --  2026-11-12: "it would be nice if the serfs found level ground and slept perpendicular to the fire")
   Reset;
   Set_Beds (True);
   Castle.Herds.Set_Scatter (True);
   Set_Labour (True);
   Set_Needs (True);
   Set_Skills (False);
   Set_Demand_Chain (False);
   Meadow;
   for K in 1 .. 34 loop                 --  the ground rises a block a metre, east of the stake's meadow
      Fill (28.0 + Float (K), 0.0, 64.0, 64.0, Ground_Row + K - 2, Ground_Row + K - 2, Dirt);
      Fill (28.0 + Float (K), 0.0, 64.0, 64.0, Ground_Row + K - 1, Ground_Row + K - 1, Grass);
   end loop;
   Changed_World;
   Hours := 16.0 * 24.0 + 7.0;
   Place_Stake (Stake_P, 6, 42);
   declare
      Ok : Boolean;
      Laid, Cells, Placed : Natural;
      Fire : constant Vec3 := (40.0, 38.0, Ground_M + 2.75);
      Level_N, Square_N, On_Ring, Own_N, Cold_N, On_It : Natural := 0;
      Uneven_Most : Natural := 0;
      Gap_Least, Far : Float := 0.0;
      Done_At : Natural := 0;
      --  the top of the ground at a block column of this hillside
      function Top (X, Y : Integer) return Integer is
      begin
         for Z in reverse Ground_Row - 2 .. Ground_Row + 40 loop
            if Get (X, Y, Z) in Grass | Dirt | Footpath then
               return Z;
            end if;
         end loop;
         return -1;
      end Top;
   begin
      Lay_Path ((20.5, 17.5, Ground_M), (27.0, 17.5, Ground_M), Laid);
      Build_Paths_Now;
      Zone_Stockpile (21.0, 15.0, 25.0, 17.0, Cells);
      Index_All;
      Supply (Berries, 600, Placed);
      Supply (Straw, 20, Placed);
      Zone_Camp (Fire, Ok);
      Build_Camp_Now;
      for S in 1 .. 900 loop
         Run (1);
         if (for all I in 1 .. 6 => Has_Bed (I)) then
            Done_At := S;
            exit;
         end if;
      end loop;
      Gap_Least := Float'Last;
      for I in 1 .. 6 loop
         declare
            V  : constant Bed_View := Camp_Bed (I);
            Ux : constant Float := V.Toward.X - V.Feet.X;
            Uy : constant Float := V.Toward.Y - V.Feet.Y;
            Mx : constant Float := V.Feet.X - Ux - Camp.X;
            My : constant Float := V.Feet.Y - Uy - Camp.Y;
            R  : constant Float := Sqrt (Mx * Mx + My * My);
            Lo : Integer := Integer'Last;
            Hi : Integer := Integer'First;
         begin
            if V.Made and then V.By_Fire then
               Own_N := Own_N + 1;
            end if;
            if abs (Ux * Mx + Uy * My) / Float'Max (0.01, R) < 0.02 then
               Square_N := Square_N + 1;
            end if;
            Far := Float'Max (Far, R);
            for A in -4 .. 4 loop           --  the ground under all its length, and a block to either side
               for W in -1 .. 1 loop
                  declare
                     T : constant Integer :=
                       Top (B (V.Feet.X - Ux + Ux * 0.25 * Float (A) - Uy * 0.25 * Float (W)),
                            B (V.Feet.Y - Uy + Uy * 0.25 * Float (A) + Ux * 0.25 * Float (W)));
                  begin
                     Lo := Integer'Min (Lo, T);
                     Hi := Integer'Max (Hi, T);
                  end;
               end loop;
            end loop;
            if Hi = Lo then
               Level_N := Level_N + 1;
            end if;
            Uneven_Most := Natural'Max (Uneven_Most, Hi - Lo);
            --  (the old ring: its feet 2.7 m from the fire, pointing at it)
            if Flat (V.Feet, Camp) < 2.9 then
               On_Ring := On_Ring + 1;
            end if;
            for J in 1 .. 6 loop
               if J /= I then
                  Gap_Least := Float'Min (Gap_Least, Flat ((V.Feet.X - Ux, V.Feet.Y - Uy, 0.0),
                                                           (Camp_Bed (J).Feet.X - (Camp_Bed (J).Toward.X - Camp_Bed (J).Feet.X),
                                                            Camp_Bed (J).Feet.Y - (Camp_Bed (J).Toward.Y - Camp_Bed (J).Feet.Y), 0.0)));
               end if;
            end loop;
         end;
      end loop;
      Check (Ok and then Done_At > 0 and then Own_N = 6 and then On_Ring = 0 and then Square_N = 6
             and then Uneven_Most <= Bed_Uneven_B and then Level_N >= 4 and then Far <= Float'(Bed_Far_M) + 0.01
             and then Gap_Least >= Float'(Bed_Apart_M),
             "a camp on ground that rises a block a metre: each of the six has a place of its own by the fire, across"
             & " the way to it, " & Img (Level_N) & " of them on ground level under all their length (the worst "
             & Img (Uneven_Most) & " block out), none on the old ring, the furthest " & Img (Far, 1)
             & " m off, no two middles nearer than " & Img (Gap_Least, 1) & " m (beds made in " & Img (Done_At)
             & " game minutes, " & (if Ok then "the camp taken" else Camp_Refusal) & ")");
      Hours := 16.0 * 24.0 + 20.0;
      Run (240);                                          --  to midnight
      for I in 1 .. 6 loop
         if Asleep (I) and then Flat (Where (I), Camp_Bed (I).Feet) < 0.05
           and then abs (Where (I).Z - Camp_Bed (I).Feet.Z) < 0.01
         then
            On_It := On_It + 1;
         end if;
         if Flat (Where (I), Camp) > 6.0 then
            Cold_N := Cold_N + 1;
         end if;
      end loop;
      Check (On_It = 6 and then Cold_N = 0,
             "at midnight all six are asleep there, on their beds and on that ground's own level, none further than"
             & " the fire warms (" & Img (On_It) & " of 6)");
      declare
         Data : constant Bytes := Save;
         Ok2  : Boolean;
         Feet : array (1 .. 6) of Vec3;
         To   : array (1 .. 6) of Vec3;
      begin
         for I in 1 .. 6 loop
            Feet (I) := Camp_Bed (I).Feet;
            To (I) := Camp_Bed (I).Toward;
         end loop;
         Load (Data, Ok2);
         Check (Ok2 and then Save = Data
                and then (for all I in 1 .. 6 => Camp_Bed (I).Feet = Feet (I) and then Camp_Bed (I).Toward = To (I)
                                                and then Camp_Bed (I).By_Fire),
                "and their places come back from a save to the same bytes");
      end;
      --  a path marked over the furthest of them: that bed is gone with its straw, and its maker
      --  finds another place in the morning and makes its bed again
      declare
         Who : Positive := 1;
         Old : Bed_View;
         Gone, Rest_Lie : Boolean;
         Sheaves_Then : constant Natural := Straw_In_Beds;
      begin
         for I in 2 .. 6 loop
            if Flat (Camp_Bed (I).Feet, Camp) > Flat (Camp_Bed (Who).Feet, Camp) then
               Who := I;
            end if;
         end loop;
         Old := Camp_Bed (Who);
         declare
            Ux : constant Float := Old.Toward.X - Old.Feet.X;
            Uy : constant Float := Old.Toward.Y - Old.Feet.Y;
            Mx : constant Float := Old.Feet.X - Ux;
            My : constant Float := Old.Feet.Y - Uy;
         begin
            --  (along it, across the way to the fire: clear of the camp's own ground)
            Lay_Path ((Mx - 4.0 * Ux, My - 4.0 * Uy, Old.Feet.Z), (Mx + 4.0 * Ux, My + 4.0 * Uy, Old.Feet.Z), Laid);
         end;
         Run (61);
         Gone := Laid > 0 and then not Camp_Bed (Who).Made and then not Has_Bed (Who)
           and then Straw_In_Beds = Sheaves_Then - Bed_Straw;
         Rest_Lie := (for all I in 1 .. 6 => I = Who or else Camp_Bed (I).Made);
         Run (9 * 60);                                    --  to nine in the morning
         Check (Gone and then Rest_Lie and then Has_Bed (Who) and then Straw_In_Beds = Sheaves_Then
                and then Flat (Camp_Bed (Who).Feet, Old.Feet) > 0.5
                and then not Near_Path (Camp_Bed (Who).Feet.X, Camp_Bed (Who).Feet.Y, 0.0)
                and then Camp_Bed (Who).By_Fire,
                "a path marked over the furthest bed: within the hour that bed is gone with its straw, the others"
                & " lie as they did, and in the morning " & Name_Of (Who) & " has found another place and made its bed"
                & " again (" & Img (Flat (Camp_Bed (Who).Feet, Old.Feet), 1) & " m from the old one)");
      end;
   end;

   --  the same on a hillside falling every way, 15 degrees apart, as steep as a camp may be marked on
   --  (a metre off its middle at the most within its square): where the six lie
   declare
      Level_N, One_Out, Two_Out, On_Ring, Camps, Square_N, Far_N : Natural := 0;
      Worst_Ring : Natural := 0;
      Worst_At   : Integer := 0;
      Steepest, Gentlest : Float := 0.0;
   begin
      Gentlest := Float'Last;
      for Step in 0 .. 23 loop
         declare
            Th : constant Float := Float (Step) * 15.0 * 3.14159265 / 180.0;
            Ok : Boolean := False;
            Ring_Here : Natural := 0;
            --  the row of the ground's top at a block column, on ground rising Slope along Th from the middle
            function Top_Of (X, Y : Integer; Slope : Float) return Integer is
              (Ground_Row - 1
               + Integer'Max (-12, Integer'Min (40, Integer (Float'Floor
                   ((((Float (X) + 0.5) * 0.25 - 32.0) * Cos (Th) + ((Float (Y) + 0.5) * 0.25 - 32.0) * Sin (Th))
                    * Slope * 4.0)))));
            function Top (X, Y : Integer) return Integer is
            begin
               for Z in reverse 1 .. Ground_Row + 44 loop
                  if Get (X, Y, Z) in Grass | Dirt | Footpath then
                     return Z;
                  end if;
               end loop;
               return -1;
            end Top;
         begin
            for Try in 1 .. 4 loop
               declare
                  Slope : constant Float := (case Try is when 1 => 0.28, when 2 => 0.25, when 3 => 0.22, when others => 0.2);
               begin
                  Reset;
                  Set_Beds (True);
                  Castle.Herds.Set_Scatter (True);
                  Set_Labour (True);
                  Set_Needs (True);
                  Set_Skills (False);
                  Set_Demand_Chain (False);
                  Meadow;
                  for X in 0 .. W_B - 1 loop
                     for Y in 0 .. W_B - 1 loop
                        declare
                           T : constant Integer := Top_Of (X, Y, Slope);
                        begin
                           for Z in Ground_Row - 13 .. Ground_Row + 41 loop
                              Set (X, Y, Z, (if Z < T then Dirt elsif Z = T then Grass else Air));
                           end loop;
                        end;
                     end loop;
                  end loop;
                  Changed_World;
                  Hours := 16.0 * 24.0 + 7.0;
                  Place_Stake ((24.0, 24.0, Float (Top_Of (B (24.0), B (24.0), Slope) + 1) * 0.25), 6, 42);
                  Index_All;
                  Zone_Camp ((32.0, 32.0, Ground_M), Ok);
                  if Ok then
                     Steepest := Float'Max (Steepest, Slope);
                     Gentlest := Float'Min (Gentlest, Slope);
                  end if;
               end;
               exit when Ok;
            end loop;
            if Ok then
               Camps := Camps + 1;
               Build_Camp_Now;
               Run (120);                          --  (each chooses the first time it thinks: two hours is all of them)
               for I in 1 .. 6 loop
                  declare
                     V  : constant Bed_View := Sleeping_Place (I);
                     Ux : constant Float := V.Toward.X - V.Feet.X;
                     Uy : constant Float := V.Toward.Y - V.Feet.Y;
                     Mx : constant Float := V.Feet.X - Ux - Camp.X;
                     My : constant Float := V.Feet.Y - Uy - Camp.Y;
                     R  : constant Float := Sqrt (Mx * Mx + My * My);
                     Lo : Integer := Integer'Last;
                     Hi : Integer := Integer'First;
                  begin
                     if not V.By_Fire then
                        On_Ring := On_Ring + 1;
                        Ring_Here := Ring_Here + 1;
                     else
                        for A in -4 .. 4 loop
                           for W in -1 .. 1 loop
                              declare
                                 T : constant Integer :=
                                   Top (B (V.Feet.X - Ux + Ux * 0.25 * Float (A) - Uy * 0.25 * Float (W)),
                                        B (V.Feet.Y - Uy + Uy * 0.25 * Float (A) + Ux * 0.25 * Float (W)));
                              begin
                                 Lo := Integer'Min (Lo, T);
                                 Hi := Integer'Max (Hi, T);
                              end;
                           end loop;
                        end loop;
                        case Hi - Lo is
                           when 0 => Level_N := Level_N + 1;
                           when 1 => One_Out := One_Out + 1;
                           when others => Two_Out := Two_Out + 1;
                        end case;
                        if abs (Ux * Mx + Uy * My) / Float'Max (0.01, R) < 0.02 then
                           Square_N := Square_N + 1;
                        end if;
                        if R > Float'(Bed_Far_M) + 0.01 then
                           Far_N := Far_N + 1;
                        end if;
                     end if;
                  end;
               end loop;
               if Ring_Here > Worst_Ring then
                  Worst_Ring := Ring_Here;
                  Worst_At := 15 * Step;
               end if;
            end if;
         end;
      end loop;
      Put_Line ("    a camp on ground falling every way, 15 degrees apart, as steep as a camp may be marked on (slopes of "
                & Img (Gentlest, 2) & " to " & Img (Steepest, 2) & "): " & Img (Camps) & " camps, " & Img (6 * Camps)
                & " sleepers: " & Img (Level_N) & " on level ground, " & Img (One_Out) & " a block out of level, "
                & Img (Two_Out) & " two blocks out, " & Img (On_Ring) & " on the old ring (the most at one camp "
                & Img (Worst_Ring) & ", at" & Worst_At'Image & " degrees)");
      Check (Camps = 24 and then On_Ring = 0 and then Far_N = 0 and then Square_N = Level_N + One_Out + Two_Out,
             "on every one of them each of the six has a place of its own by the fire, across the way to it and no"
             & " further than the fire warms; none lies on the old ring");
   end;

   --  none to cut and none stored, and then straw comes into the stockpile: it is taken for the beds at
   --  once (a failure to find any to cut used to keep its maker from the stockpile too, for thirty hours)
   Set_Up (With_Bushes => False, With_Needs => True, With_Labour => True, With_Beds => True);
   Hours := 16.0 * 24.0 + 7.0;
   declare
      Ok : Boolean;
      Placed : Natural;
      None_Yet : Boolean;
      Done_At : Natural := 0;
   begin
      Supply (Berries, 400, Placed);
      Build_Paths_Now;
      Zone_Camp ((27.0, 38.0, Ground_M), Ok);
      Build_Camp_Now;
      Run (120);
      None_Yet := (for all I in 1 .. 6 => not Has_Bed (I)) and then Straw_In_Beds = 0;
      Supply (Straw, 12, Placed);
      for S in 1 .. 120 loop
         Run (1);
         if (for all I in 1 .. 6 => Has_Bed (I)) then
            Done_At := S;
            exit;
         end if;
      end loop;
      Check (Ok and then None_Yet and then Placed = 12 and then Done_At > 0 and then Stored (Straw) = 0
             and then Straw_In_Beds = 12,
             "on a meadow with no grass to cut nobody has a bed after two hours; twelve sheaves brought into the"
             & " stockpile then are in six beds " & Img (Done_At) & " game minutes later");
   end;

   --  a bed comes before the band's building: nobody lays a metre of path while it has none to lie on
   Set_Up (With_Bushes => False, With_Porter_Ground => True, With_Needs => True, With_Labour => True, With_Beds => True);
   Hours := 16.0 * 24.0 + 7.0;
   declare
      Ok : Boolean;
      Placed, Laid, To_Lay : Natural;
      Bedless_At_Path : Boolean := False;
      Done_At : Natural := 0;
      function Says (I : Positive; Part : String) return Boolean is
        (Ada.Strings.Fixed.Index (Status (I), Part) > 0);
   begin
      Supply (Berries, 400, Placed);
      Build_Paths_Now;
      Zone_Camp ((27.0, 38.0, Ground_M), Ok);
      Build_Camp_Now;
      Lay_Path ((44.0, 20.0, Ground_M), (44.0, 58.0, Ground_M), Laid);
      Run (2);
      To_Lay := Paths_To_Lay;
      for S in 1 .. 900 loop
         Run (1);
         Bedless_At_Path := Bedless_At_Path
           or else (for some I in 1 .. 6 => not Has_Bed (I) and then Says (I, "path"));
         if Done_At = 0 and then (for all I in 1 .. 6 => Has_Bed (I)) then
            Done_At := S;
         end if;
         exit when Done_At > 0 and then Paths_To_Lay < To_Lay;
      end loop;
      Check (Ok and then To_Lay >= 38 and then Done_At > 0 and then not Bedless_At_Path and then Paths_To_Lay < To_Lay,
             "with 38 m of path to lay when the camp stands, each cuts its straw and makes its bed first ("
             & Img (Done_At) & " game minutes), and then the path is laid (" & Img (To_Lay - Paths_To_Lay)
             & " m of it a little later)");
   end;

   --  the stockpile's straw is a bed's first, whatever a hovel being built still wants of it (John,
   --  2026-11-12: "serfs didn't create a bed when straw was in the stockpile, might have been reserved by
   --  the housing, basic needs take priority")
   Set_Up (With_Bushes => False, With_Porter_Ground => True, With_Needs => True, With_Labour => True, With_Beds => True);
   Hours := 16.0 * 24.0 + 7.0;
   declare
      Ok : Boolean;
      Placed, Laid, Lots : Natural;
      Took : Boolean := False;
      Done_At : Natural := 0;
      function Says (I : Positive; Part : String) return Boolean is
        (Ada.Strings.Fixed.Index (Status (I), Part) > 0);
   begin
      Supply (Berries, 400, Placed);
      Supply (Straw, 10, Placed);
      Build_Paths_Now;
      Lay_Path ((44.0, 20.0, Ground_M), (44.0, 58.0, Ground_M), Laid);
      Build_Paths_Now;
      Zone_Housing (44.6, 22.0, 55.0, 43.0, Lots);
      Run (3);                                            --  (a hovel is begun: nobody builds it)
      Zone_Camp ((27.0, 38.0, Ground_M), Ok);
      Build_Camp_Now;
      for S in 1 .. 600 loop
         Run (1);
         Took := Took or else (for some I in 1 .. Members => Says (I, "fetching straw for its bed"));
         if (for all I in 1 .. Members => Has_Bed (I)) then
            Done_At := S;
            exit;
         end if;
      end loop;
      Check (Ok and then House_Count = 1 and then House_At (1).Takes (Straw) > 10 and then Done_At > 0 and then Took
             and then Stored (Straw) = 0 and then Straw_In_Beds = 6 * Bed_Straw,
             "with 10 sheaves in store and a hovel begun that wants " & Img (House_At (1).Takes (Straw))
             & ", the beds have the store's straw before the hovel: five from the stockpile, and the sixth cut by"
             & " its maker's own hand (" & Img (Stored (Straw)) & " still stored, all six in " & Img (Done_At)
             & " game minutes)");
   end;

   --  a hovel falls to someone on its way to the fire with straw for its bed: the bed is made in the hovel
   Set_Up (With_Bushes => False, With_Porter_Ground => True, With_Needs => True, With_Labour => True, With_Beds => True);
   Hours := 16.0 * 24.0 + 7.0;
   declare
      Ok : Boolean;
      Placed, Laid, Lots_E, Lots_W : Natural;
      Carrier : Natural := 0;
      Counted : Boolean := True;
      Far_Bed : Boolean := False;          --  a hovel got its bed with its owner nowhere near it
      Had : array (1 .. 8) of Boolean := [others => False];
      Done_At : Natural := 0;
      Grass_Then : Natural;
      function Grass_Now return Natural is
        (Count_In (B (Grass_X0) - 1, B (Grass_Y0) - 1, B (Grass_X1) + 1, B (Grass_Y1) + 1, Ground_Row, Ground_Row, Tall_Grass));
      function Says (I : Positive; Part : String) return Boolean is
        (Ada.Strings.Fixed.Index (Status (I), Part) > 0);
      function Straw_Carried return Natural is
         N : Natural := 0;
      begin
         for I in 1 .. Members loop
            if Carrying (I) = Straw then
               N := N + Carried (I);
            end if;
         end loop;
         return N;
      end Straw_Carried;
   begin
      Supply (Berries, 400, Placed);
      Supply (Straw, 40, Placed);
      Build_Paths_Now;
      Lay_Path ((44.0, 20.0, Ground_M), (44.0, 58.0, Ground_M), Laid);
      Build_Paths_Now;
      Zone_Housing (44.6, 22.0, 55.0, 56.0, Lots_E);
      Zone_Housing (43.4, 22.0, 35.0, 56.0, Lots_W);
      Zone_Camp ((27.0, 38.0, Ground_M), Ok);
      Build_Camp_Now;
      Grass_Then := Grass_Now;
      for S in 1 .. 200 loop
         Run (1);
         for I in 1 .. 6 loop
            if Carrier = 0 and then Says (I, "carrying straw to where it sleeps") then
               Carrier := I;
            end if;
         end loop;
         exit when Carrier > 0;
      end loop;
      Build_Homes_Now;                                    --  (a hovel for each of the six, drawn this second)
      for S in 1 .. 900 loop
         Run (1);
         Counted := Counted and then Stored (Straw) + Straw_Carried + Straw_In_Beds = 40 + Grass_Then - Grass_Now;
         for H in 1 .. House_Count loop
            if House_At (H).Has_Bed and then not Had (H) then
               Had (H) := True;
               Far_Bed := Far_Bed or else Flat (Where (House_At (H).Owner), House_At (H).Bed) > 2.0;
            end if;
         end loop;
         if (for all I in 1 .. 6 => Has_Bed (I)) then
            Done_At := S;
            exit;
         end if;
      end loop;
      Check (Ok and then Carrier > 0 and then House_Count = 6 and then Housed (Natural'Max (1, Carrier)) and then Done_At > 0
             and then not Camp_Bed (Natural'Max (1, Carrier)).Made and then not Far_Bed and then Counted
             and then (for all H in 1 .. House_Count => House_At (H).Has_Bed),
             "a hovel falls to " & Name_Of (Natural'Max (1, Carrier)) & " on its way to the fire with straw for its bed: it"
             & " lays none there, carries it on to its hovel and makes its bed in it; no hovel has a bed its owner did not"
             & " lay in it, and every sheaf, stored or cut, is stored, carried or in a bed (all six bedded in their hovels"
             & " in " & Img (Done_At) & " game minutes, " & Img (Grass_Then - Grass_Now) & " sheaves cut)");
   end;

   --  night falls in the middle of the errand: the camp stands between ten past eight and ten past nine, the
   --  grass 25 m off (begun at 120 moments half a minute apart: each of the six has its own bedtime, and a
   --  sheaf takes under a minute to cut, so night finds one or another of them at every point of it)
   declare
      Runs, Thin_Beds, Latest, Beds_Most : Natural := 0;
      Late, Awake, Lost : Boolean := False;
   begin
      for Step in 0 .. 119 loop
         Set_Up (With_Bushes => False, With_Porter_Ground => True, With_Needs => True, With_Labour => True,
                 With_Beds => True);
         Hours := 16.0 * 24.0 + 20.0 + (10.0 + 0.5 * Long_Float (Step)) / 60.0;
         declare
            Ok : Boolean;
            Placed : Natural;
            Grass_Then : Natural;
            function Grass_Now return Natural is
              (Count_In (B (Grass_X0) - 1, B (Grass_Y0) - 1, B (Grass_X1) + 1, B (Grass_Y1) + 1, Ground_Row, Ground_Row,
                         Tall_Grass));
            Asleep_At : Natural := 0;                     --  the minute by which all were asleep
            To_Midnight : constant Natural := 230 - Step / 2;
         begin
            Supply (Berries, 400, Placed);
            Zone_Camp ((40.0, 38.0, Ground_M), Ok);
            Build_Camp_Now;
            Grass_Then := Grass_Now;
            for S in 1 .. To_Midnight loop
               Run (1);
               --  (an hour and a half after the last of them is due in bed)
               Late := Late or else (S > To_Midnight - 60
                                     and then (for some I in 1 .. 6 => Carrying (I) = Straw and then Carried (I) > 0));
               if Asleep_At = 0 and then (for all I in 1 .. 6 => Asleep (I)) then
                  Asleep_At := S;
               end if;
            end loop;
            Runs := Runs + (if Ok then 1 else 0);
            Awake := Awake or else Asleep_At = 0 or else not (for all I in 1 .. 6 => Asleep (I) and then Carrying (I) /= Straw);
            Lost := Lost or else Grass_Then - Grass_Now /= Straw_In_Beds + Stored (Straw);
            Latest := Natural'Max (Latest, (if Asleep_At > 0 then To_Midnight - Asleep_At else 0));
            Beds_Most := Natural'Max (Beds_Most, Straw_In_Beds);
            if Straw_In_Beds mod Bed_Straw /= 0 then
               Thin_Beds := Thin_Beds + 1;
            end if;
         end;
      end loop;
      Check (Runs = 120 and then Beds_Most >= 4 * Bed_Straw and then Thin_Beds >= 1
             and then not Late and then not Awake and then not Lost,
             "night come in the middle of it, the camp built at 120 moments from ten past eight to ten past nine: whoever"
             & " has straw in its arms when its night comes lays it, a thin bed if it must (" & Img (Thin_Beds)
             & " of the runs had one), the rest come in with empty hands; nobody holds straw into the night, every sheaf"
             & " cut is in a bed or stored, and at midnight all are asleep (the last of them " & Img (Latest)
             & " minutes before it, at the least)");
   end;

   --  no straw to be had: nobody is kept from its sleep, and a house's owner sleeps under its roof all the same
   Set_Up (With_Bushes => False, With_Needs => True, With_Labour => True, With_Beds => True);
   Hours := 16.0 * 24.0 + 7.0;
   declare
      Ok : Boolean;
      Placed, Laid, Lots : Natural;
      Held_Long : Boolean := False;
      Holding : array (1 .. 6) of Natural := [others => 0];
   begin
      Supply (Berries, 400, Placed);
      Supply (Straw, 1, Placed);
      Build_Paths_Now;
      Lay_Path ((44.0, 20.0, Ground_M), (44.0, 58.0, Ground_M), Laid);
      Build_Paths_Now;
      Zone_Camp ((27.0, 38.0, Ground_M), Ok);
      Build_Camp_Now;
      Zone_Housing (44.6, 22.0, 55.0, 43.0, Lots);
      Build_Homes_Now;
      for S in 1 .. 1_020 loop                            --  to midnight
         Run (1);
         for I in 1 .. 6 loop
            Holding (I) := (if Carrying (I) = Straw and then Carried (I) > 0 then Holding (I) + 1 else 0);
            Held_Long := Held_Long or else Holding (I) > 120;
         end loop;
      end loop;
      Check (Ok and then Straw_In_Beds = 1 and then Stored (Straw) = 0 and then not Held_Long
             and then (for all I in 1 .. 6 => Carrying (I) /= Straw),
             "with one sheaf in store and none to cut, one thin bed is made of it and the rest wait: nobody stands"
             & " holding straw");
      Check ((for all I in 1 .. 6 => Asleep (I) and then (if Housed (I) then At_Home (I) else True))
             and then (for some I in 1 .. 6 => Housed (I) and then not Has_Bed (I)),
             "at midnight all are asleep, and whoever has a hovel and no bed in it sleeps on its floor, under its roof");
   end;

   --  wild grain cut for a bed: its grain goes to the stores
   Set_Up (With_Bushes => False, With_Grain => True, With_Needs => True, With_Labour => True, With_Beds => True);
   Hours := 16.0 * 24.0 + 7.0;
   declare
      Ok : Boolean;
      Placed : Natural;
   begin
      Supply (Berries, 600, Placed);
      Zone_Camp ((40.0, 24.0, Ground_M), Ok);
      Build_Camp_Now;
      Run (600);
      Check (Ok and then Straw_In_Beds = 12 and then Stored (Grain) = 12 * Grain_Per_Plant
             and then (for all I in 1 .. 6 => Grain_Carried (I) = 0 and then Carrying (I) /= Grain),
             "a bed cut of wild grain: its straw in the bed, the grain that came with it carried to the stores ("
             & Img (Straw_In_Beds) & " sheaves in beds, " & Img (Stored (Grain)) & " handfuls of grain stored)");
   end;

   --  the action table, and the ground's menu
   Set_Up (With_Bushes => False, With_Labour => True);
   declare
      use Castle.Actions;
      R : Result;
      Laid : Natural;
      M : Menu;
      Offered : Boolean := False;
   begin
      Build_Paths_Now;
      Lay_Path ((44.0, 20.0, Ground_M), (44.0, 58.0, Ground_M), Laid);
      Perform ((What => Zone_Housing, By => 2, X0 => 44.6, Y0 => 22.0, X1 => 55.0, Y1 => 56.0), R);
      Check (not R.Done and then R.Why = Not_Permitted and then Zone_Count = 1, "a serf may not zone housing");
      Perform ((What => Zone_Housing, By => The_Player, X0 => 60.0, Y0 => 30.0, X1 => 62.0, Y1 => 40.0), R);
      Check (not R.Done and then R.Why = The_Ground_Refused
             and then Why_Not ((What => Zone_Housing, By => The_Player, X0 => 60.0, Y0 => 30.0, X1 => 62.0, Y1 => 40.0), R)
                      = Housing_Refusal,
             "the player's order for it away from a path is refused with the ground's reason");
      Perform ((What => Zone_Housing, By => The_Player, X0 => 44.6, Y0 => 22.0, X1 => 55.0, Y1 => 56.0), R);
      Check (R.Done and then R.Count >= 3 and then Zone_At (Zone_Count).Kind = Habitation_Zone,
             "and beside one it is done: room for" & R.Count'Image & " hovels (along a path planned, not yet laid)");
      M := Menu_For (The_Player, (Kind => The_Ground, Index => 0, Point => (50.0, 10.0, Ground_M)));
      for K in 1 .. M.N loop
         Offered := Offered or else (M.Items (K).Todo.What = Zone_Housing and then M.Items (K).Two_Point);
      end loop;
      Check (Offered and then (for all K in 1 .. M.N => M.Items (K).Todo.What /= Give_Job),
             "the ground's menu offers housing from there, corner to corner");
      M := Menu_For (The_Player, (Kind => A_Person, Index => 1, Point => (0.0, 0.0, 0.0)));
      Check (M.N = 7 and then Job_Kind'Pos (Job_Kind'Last) = 5,
             "nobody can be made a builder: it is not a job to give, but a trade a forester takes up");
   end;

   New_Line;
   if Fails = 0 then
      Put_Line ("all checks passed");
   else
      Put_Line (Fails'Image & " checks FAILED");
      Ada.Command_Line.Set_Exit_Status (1);
   end if;
end Colony_Check;
