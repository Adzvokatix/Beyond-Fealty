--  Routes without a window: made-up worlds where the right answer is known
--  (a wall with a door, a pit, a ledge that can be dropped down but not
--  climbed, a river with a bridge and a ford, a footpath worth a detour, a
--  tunnel under a hill, too little headroom, a closed room, an edit across
--  a route), then seed 1's own ground for timing.
--  ./bin/debug/path_check [--real N]   (exits 1 on any failure)

with Ada.Text_IO;      use Ada.Text_IO;
with Ada.Command_Line;
with Ada.Real_Time;
with Ada.Numerics.Elementary_Functions; use Ada.Numerics.Elementary_Functions;
with Castle.Blocks;    use Castle.Blocks;
with Castle.Math;      use Castle.Math;
with Castle.Water;
with Castle.Nav;       use Castle.Nav;
with Castle.Text;      use Castle.Text;
with Castle.Hash;
with Castle.Maps;      use Castle.Maps;
with Castle.Chunks;    use Castle.Chunks;
with Castle.Worldgen;
with Castle.Edits;
with Castle.World_Blocks;
with Test_World;  use Test_World;

procedure Path_Check is

   pragma Warnings (Off, "formal parameter * is not referenced");   --  spot tests take all three

   Fails : Natural := 0;

   procedure Check (Ok : Boolean; What : String) is
   begin
      Put_Line ((if Ok then "  ok    " else "  FAIL  ") & What);
      if not Ok then
         Fails := Fails + 1;
      end if;
   end Check;

   ------------------------------------------------------------ a made-up world

   function B (M : Float) return Integer is (Integer (Float'Floor (M * 4.0)));

   function P (X, Y : Float; Z : Float := Ground_M) return Vec3 is ((X, Y, Z));

   ------------------------------------------------------------ looking at routes

   function Straight (A, B : Vec3) return Float is
     (Sqrt ((B.X - A.X) ** 2 + (B.Y - A.Y) ** 2));

   --  Every 5 cm along the route, ask Test whether that spot (and its height
   --  there) is acceptable; True if every spot is.
   generic
      with function Test (X, Y, Z : Float) return Boolean;
   function Every_Spot (R : Route) return Boolean;
   function Every_Spot (R : Route) return Boolean is
   begin
      for K in 1 .. R.N - 1 loop
         declare
            A : constant Vec3 := R.Pts (K).P;
            C : constant Vec3 := R.Pts (K + 1).P;
            L : constant Float := Straight (A, C);
            N : constant Positive := Positive'Max (1, Integer (L / 0.05));
         begin
            for I in 0 .. N loop
               declare
                  T : constant Float := Float (I) / Float (N);
               begin
                  --  the height changes at the far point: the spot takes A's
                  --  height up to it
                  if not Test (A.X + (C.X - A.X) * T, A.Y + (C.Y - A.Y) * T, (if I = N then C.Z else A.Z)) then
                     return False;
                  end if;
               end;
            end loop;
         end;
      end loop;
      return True;
   end Every_Spot;

   generic
      with function Test (X, Y, Z : Float) return Boolean;
   function Some_Spot (R : Route) return Boolean;
   function Some_Spot (R : Route) return Boolean is
      function Not_Test (X, Y, Z : Float) return Boolean is (not Test (X, Y, Z));
      function All_Not is new Every_Spot (Not_Test);
   begin
      return not All_Not (R);
   end Some_Spot;

   function Describe (R : Route) return String is
     (Outcome'Image (R.Result) & ", " & Img (Length (R), 1) & " m in " & Img (Total_Time (R), 1) & " s,"
      & R.N'Image & " points; looked at" & Last_Stats.Looked_At'Image & " floors in "
      & Img (Last_Stats.Seconds * 1000.0, 2) & " ms");

   function Plan_Show (A, B : Vec3; Label : String) return Route is
      R : constant Route := Plan (A, B);
   begin
      Put_Line ("    " & Label & ": " & Describe (R));
      return R;
   end Plan_Show;

begin
   Test_World.Attach;

   ------------------------------------------------------------ 1. open ground
   Put_Line ("open ground:");
   Meadow;
   declare
      A : constant Vec3 := P (5.2, 5.3);
      Z : constant Vec3 := P (55.1, 45.4);
      R : constant Route := Plan_Show (A, Z, "corner to corner");
      D : constant Float := Straight (A, Z);
   begin
      Check (R.Result = Found and then abs (Length (R) - D) < 0.01 * D,
             "the route is the straight line: " & Img (Length (R), 2) & " m (" & Img (D, 2) & ")");
      Check (abs (Total_Time (R) - D / Walk_Speed) < 0.02 * D / Walk_Speed,
             "and takes as long as walking it on grass: " & Img (Total_Time (R), 1) & " s ("
             & Img (D / Walk_Speed, 1) & ")");
      Check (R.N = 2, "pulled straight into one line (" & R.N'Image & " points)");
      Check (Still_Good (R, 1), "every step of it can be walked");
      declare
         R2 : constant Route := Plan (A, Z);
         Same : Boolean := R2.N = R.N;
      begin
         for K in 1 .. Integer'Min (R.N, R2.N) loop
            Same := Same and then R.Pts (K).P = R2.Pts (K).P;
         end loop;
         Check (Same, "the same question gets the same route");
      end;
      Check (Changed (R) = False, "and nothing has changed under it");
   end;

   ------------------------------------------------------------ 2. a wall with a door
   Put_Line ("a wall with a door:");
   Meadow;
   Fill (30.0, 0.0, 30.25, 64.0, Ground_Row, Ground_Row + 11, Plank);     --  3 m high, one block thick
   Fill (30.0, 40.0, 30.25, 41.0, Ground_Row, Ground_Row + 7, Air);       --  door 1 m wide, 2 m high
   declare
      A : constant Vec3 := P (10.0, 10.0);
      Z : constant Vec3 := P (50.0, 10.0);
      R : constant Route := Plan_Show (A, Z, "through the wall");
      Via : constant Float := Straight (A, P (30.1, 40.5)) + Straight (P (30.1, 40.5), Z);
      function In_Door (X, Y, Zm : Float) return Boolean is
        (X in 29.9 .. 30.35 and then Y in 40.0 .. 41.0);
      function Through_Door is new Some_Spot (In_Door);
      function Off_Wall (X, Y, Zm : Float) return Boolean is
        (X not in 29.8 .. 30.45 or else Y in 40.0 .. 41.0);
      function Never_Through_Wall is new Every_Spot (Off_Wall);
   begin
      Check (R.Result = Found and then Through_Door (R), "goes through the door");
      Check (Never_Through_Wall (R), "and nowhere else through the wall (keeping a hand's width off it)");
      Check (Length (R) < 1.04 * Via, "the short way round: " & Img (Length (R), 1) & " m (via the door's middle "
             & Img (Via, 1) & ")");
      Check (Still_Good (R, 1), "every step of it can be walked");
   end;
   Fill (30.0, 40.0, 30.25, 41.0, Ground_Row, Ground_Row + 7, Plank);     --  shut it
   Fill (30.0, 40.0, 30.25, 40.25, Ground_Row, Ground_Row + 7, Air);      --  a slit a block wide
   declare
      R : constant Route := Plan_Show (P (10.0, 10.0), P (50.0, 10.0), "past a 25 cm slit");
   begin
      Check (R.Result = Partial, "a 25 cm slit is no way through: the route stops short at the wall");
      Check (R.N > 0 and then R.Pts (R.N).P.X < 30.0, "on this side of it (x " & Img (R.Pts (R.N).P.X, 2) & ")");
   end;
   Fill (30.0, 40.0, 30.25, 40.5, Ground_Row, Ground_Row + 7, Air);       --  half a metre, on the cell grid
   declare
      R : constant Route := Plan_Show (P (10.0, 10.0), P (50.0, 10.0), "through a 50 cm gap");
   begin
      Check (R.Result = Found, "a 50 cm gap lets a body through, sideways");
   end;

   ------------------------------------------------------------ 3. a pit
   Put_Line ("a pit (2 m deep) in the way:");
   Meadow;
   Fill (28.0, 18.0, 32.0, 22.0, Ground_Row - 8, Ground_Row - 1, Air);
   declare
      A : constant Vec3 := P (10.0, 20.0);
      Z : constant Vec3 := P (50.0, 20.0);
      R : constant Route := Plan_Show (A, Z, "across");
      function Outside (X, Y, Zm : Float) return Boolean is (X not in 28.0 .. 32.0 or else Y not in 18.0 .. 22.0);
      function Around is new Every_Spot (Outside);
   begin
      Check (R.Result = Found and then Around (R), "walks round the pit, not through it or over it");
      Check (Length (R) < Straight (A, Z) + 1.5, "and not far round: " & Img (Length (R), 1) & " m ("
             & Img (Straight (A, Z), 1) & " straight)");
   end;

   ------------------------------------------------------------ 4. ledges
   Put_Line ("a ledge 1 m high, a ramp at one end:");
   Meadow;
   Fill (0.0, 30.0, 64.0, 64.0, Ground_Row, Ground_Row + 3, Dirt);         --  the shelf: feet at 5 m
   for Y in B (26.0) .. B (30.0) - 1 loop                                  --  a ramp at x 50-52, 1 m in 4
      for X in B (50.0) .. B (52.0) - 1 loop
         for Z in Ground_Row .. Ground_Row + (Y - B (26.0)) / 4 loop
            Test_World.Set (X, Y, Z, Dirt);
         end loop;
      end loop;
   end loop;
   Changed_World;
   declare
      Up_Top : constant Vec3 := P (20.0, 40.0, 5.0);
      Down   : constant Vec3 := P (20.0, 20.0);
      R1 : constant Route := Plan_Show (Up_Top, Down, "down from the shelf");
      R2 : constant Route := Plan_Show (Down, Up_Top, "up onto it");
      function On_Ramp (X, Y, Zm : Float) return Boolean is (X in 49.5 .. 52.5 and then Y in 26.0 .. 30.0);
      function Uses_Ramp is new Some_Spot (On_Ramp);
   begin
      Check (R1.Result = Found and then Length (R1) < Straight (Up_Top, Down) + 0.5,
             "a 1 m drop is stepped down where it is: " & Img (Length (R1), 1) & " m");
      Check (R2.Result = Found and then Uses_Ramp (R2),
             "but not climbed: the way up goes by the ramp, " & Img (Length (R2), 1) & " m");
   end;
   Fill (0.0, 30.0, 64.0, 64.0, Ground_Row + 2, Ground_Row + 3, Air);      --  the shelf 0.5 m high
   declare
      R : constant Route := Plan_Show (P (20.0, 20.0), P (20.0, 40.0, 4.5), "up a 0.5 m step");
   begin
      Check (R.Result = Found and then Length (R) < 20.5, "a 0.5 m step is climbed where it is");
   end;
   Fill (0.0, 30.0, 64.0, 64.0, Ground_Row + 2, Ground_Row + 2, Dirt);     --  0.75 m
   declare
      R : constant Route := Plan_Show (P (20.0, 20.0), P (20.0, 40.0, 4.75), "up a 0.75 m step");
      function On_Ramp (X, Y, Zm : Float) return Boolean is (X in 49.5 .. 52.5 and then Y in 26.0 .. 30.0);
      function Uses_Ramp is new Some_Spot (On_Ramp);
   begin
      Check (R.Result = Found and then Uses_Ramp (R), "a 0.75 m step is not: by the ramp again");
   end;

   ------------------------------------------------------------ 5. stairs
   Put_Line ("a stair, a block up every block (45 degrees):");
   Meadow;
   for X in B (30.0) .. W_B - 1 loop
      for Y in 0 .. W_B - 1 loop
         for Z in Ground_Row .. Integer'Min (Ground_Row + 7, Ground_Row + (X - B (30.0))) loop
            Test_World.Set (X, Y, Z, Dirt);
         end loop;
      end loop;
   end loop;
   Changed_World;
   declare
      A : constant Vec3 := P (20.0, 20.0);
      Z : constant Vec3 := P (40.0, 20.0, 6.0);
      R : constant Route := Plan_Show (A, Z, "up the stair");
      Flat_T : constant Float := 20.0 / Walk_Speed;
   begin
      Check (R.Result = Found and then abs (Length (R) - 20.0) < 0.3, "goes straight up it");
      Check (Total_Time (R) > Flat_T + 2.0 * Climb_S * 0.9,
             "the 2 m climb costs time: " & Img (Total_Time (R), 1) & " s against " & Img (Flat_T, 1) & " on the flat");
      Check (R.Pts (R.N).P.Z = 6.0, "and ends up there (" & Img (R.Pts (R.N).P.Z, 2) & " m)");
   end;

   ------------------------------------------------------------ 6. a river
   Put_Line ("a river 6 m wide and 1.75 m deep, a bridge and a ford:");
   Meadow;
   Fill (0.0, 30.0, 64.0, 36.0, Ground_Row - 8, Ground_Row - 1, Air);
   Fill (0.0, 30.0, 64.0, 36.0, Ground_Row - 8, Ground_Row - 2, Castle.Blocks.Water);
   Fill (20.0, 29.5, 21.5, 36.5, Ground_Row - 1, Ground_Row - 1, Plank);   --  the deck, level with the banks
   declare
      A : constant Vec3 := P (30.0, 10.0);
      Z : constant Vec3 := P (30.0, 50.0);
      R : constant Route := Plan_Show (A, Z, "across the river");
      function Dry_Over (X, Y, Zm : Float) return Boolean is
        (Y not in 30.0 .. 36.0 or else (X in 20.0 .. 21.5 and then Zm = Ground_M));
      function Bridge_Only is new Every_Spot (Dry_Over);
      N  : Natural;
      Fl : Floor_List;
   begin
      Check (R.Result = Found and then Bridge_Only (R), "crosses on the bridge, on its deck (4 m), nowhere else");
      Floors_At (41, 66, N, Fl);   --  a cell of the bridge over the middle of the river
      Check (N = 2 and then Fl (1).Z = Ground_Row and then Fl (1).Speed > 1.1
             and then Fl (2).Z = Ground_Row - 8 and then Fl (2).Speed = 0.0 and then Fl (2).Water = 7,
             "a bridge cell has two floors: the deck (planks, quick) and the riverbed under 1.75 m of water ("
             & N'Image & " floors)");
   end;
   --  a ford: the bed raised to a hand's depth of water at x 50-52
   Fill (50.0, 30.0, 52.0, 36.0, Ground_Row - 8, Ground_Row - 3, Gravel);
   Fill (50.0, 30.0, 52.0, 36.0, Ground_Row - 2, Ground_Row - 2, Castle.Blocks.Water);
   declare
      A : constant Vec3 := P (51.0, 10.0);
      Z : constant Vec3 := P (51.0, 50.0);
      R : constant Route := Plan_Show (A, Z, "across, near the ford");
      function At_Ford (X, Y, Zm : Float) return Boolean is
        (X in 50.0 .. 52.0 and then Y in 31.0 .. 35.0 and then Zm = Ground_M - 0.5);
      function Wades is new Some_Spot (At_Ford);
      Dry_T : constant Float := 40.0 / Walk_Speed;
   begin
      Check (R.Result = Found and then Wades (R), "wades the ford rather than walk 30 m round by the bridge");
      Check (Total_Time (R) > Dry_T + 2.0,
             "slower than dry ground: " & Img (Total_Time (R), 1) & " s for " & Img (Length (R), 1) & " m");
   end;

   ------------------------------------------------------------ 7. a footpath
   Put_Line ("a footpath round two sides of a square of sand:");
   Meadow (Top => Sand);
   Fill (4.0, 4.0, 60.0, 5.0, Ground_Row - 1, Ground_Row - 1, Footpath);
   Fill (59.0, 4.0, 60.0, 60.0, Ground_Row - 1, Ground_Row - 1, Footpath);
   declare
      A : constant Vec3 := P (4.5, 4.5);
      Z : constant Vec3 := P (59.5, 59.5);
      R : constant Route := Plan_Show (A, Z, "corner to corner over sand");
      function On_Path (X, Y, Zm : Float) return Boolean is
        (Y in 4.0 .. 5.0 or else X in 59.0 .. 60.0
         or else (X >= 57.5 and then Y <= 6.5));     --  a corner may be cut where that is quicker
      function Keeps_To_Path is new Every_Spot (On_Path);
   begin
      Check (R.Result = Found and then Keeps_To_Path (R),
             "keeps to the path (cutting its corner), 110 m, sooner than 78 m of sand: " & Img (Total_Time (R), 1) & " s against "
             & Img (77.8 / (Walk_Speed * 0.75), 1));
   end;
   for X in 0 .. W_B - 1 loop                   --  now grass instead of sand
      for Y in 0 .. W_B - 1 loop
         if Test_World.Get (X, Y, Ground_Row - 1) = Sand then
            Test_World.Set (X, Y, Ground_Row - 1, Grass);
         end if;
      end loop;
   end loop;
   Changed_World;
   declare
      A : constant Vec3 := P (4.5, 4.5);
      Z : constant Vec3 := P (59.5, 59.5);
      R : constant Route := Plan_Show (A, Z, "the same over grass");
   begin
      Check (R.Result = Found and then Length (R) < 80.0,
             "over grass the straight way is quicker, and taken: " & Img (Length (R), 1) & " m");
   end;

   ------------------------------------------------------------ 8. a tunnel
   Put_Line ("a hill 4 m high across the map, a tunnel through it:");
   Meadow;
   Fill (0.0, 25.0, 64.0, 35.0, Ground_Row, Ground_Row + 15, Granite);
   Fill (30.0, 25.0, 31.0, 35.0, Ground_Row, Ground_Row + 7, Air);          --  1 m wide, 2 m high
   declare
      A : constant Vec3 := P (30.5, 10.0);
      Z : constant Vec3 := P (30.5, 50.0);
      R : constant Route := Plan_Show (A, Z, "through the hill");
      function Low (X, Y, Zm : Float) return Boolean is (Y not in 25.0 .. 35.0 or else Zm = Ground_M);
      function In_Tunnel is new Every_Spot (Low);
      N  : Natural;
      Fl : Floor_List;
   begin
      Check (R.Result = Found and then In_Tunnel (R), "goes through the tunnel, at its floor");
      Floors_At (61, 60, N, Fl);
      Check (N = 2 and then Fl (1).Z = Ground_Row + 16 and then Fl (2).Z = Ground_Row,
             "a tunnel cell has two floors: the hilltop at 8 m and the tunnel at 4 m");
   end;
   Fill (30.0, 25.0, 31.0, 35.0, Ground_Row + 6, Ground_Row + 7, Granite);  --  1.5 m high
   declare
      R : constant Route := Plan_Show (P (30.5, 10.0), P (30.5, 50.0), "a 1.5 m tunnel");
   begin
      Check (R.Result /= Found, "too low to walk through");
   end;
   Fill (30.0, 25.0, 31.0, 35.0, Ground_Row + 6, Ground_Row + 6, Air);      --  1.75 m
   declare
      R : constant Route := Plan_Show (P (30.5, 10.0), P (30.5, 50.0), "a 1.75 m tunnel");
   begin
      Check (R.Result = Found, "1.75 m is room enough");
   end;

   ------------------------------------------------------------ 9. a closed room
   Put_Line ("a room with no door:");
   Meadow;
   Fill (40.0, 40.0, 46.0, 40.25, Ground_Row, Ground_Row + 11, Plank);
   Fill (40.0, 45.75, 46.0, 46.0, Ground_Row, Ground_Row + 11, Plank);
   Fill (40.0, 40.0, 40.25, 46.0, Ground_Row, Ground_Row + 11, Plank);
   Fill (45.75, 40.0, 46.0, 46.0, Ground_Row, Ground_Row + 11, Plank);
   declare
      R : constant Route := Plan_Show (P (10.0, 10.0), P (43.0, 43.0), "into it");
   begin
      Check (R.Result = Partial and then Straight (R.Pts (R.N).P, P (43.0, 43.0)) < 3.5,
             "can't be got into: the route ends at the wall, nearest the goal");
      Check (Last_Stats.Seconds < 1.0, "and finding that out takes " & Img (Last_Stats.Seconds * 1000.0, 1)
             & " ms over the whole 64 m map");
      Check (Last_Stats.Out_Of_Reach and then Last_Stats.Looked_At < 4_000,
             "the pieces of ground show it out of reach at once, so the search goes straight to the wall ("
             & Last_Stats.Looked_At'Image & " floors looked at)");
   end;

   Put_Line ("a room with a door, shut and opened:");
   Meadow;
   Fill (40.0, 40.0, 46.0, 40.25, Ground_Row, Ground_Row + 11, Plank);
   Fill (40.0, 45.75, 46.0, 46.0, Ground_Row, Ground_Row + 11, Plank);
   Fill (40.0, 40.0, 40.25, 46.0, Ground_Row, Ground_Row + 11, Plank);
   Fill (45.75, 40.0, 46.0, 46.0, Ground_Row, Ground_Row + 11, Plank);
   Fill (42.5, 40.0, 43.5, 40.25, Ground_Row, Ground_Row + 7, Air);          --  a door 1 m wide
   declare
      R : constant Route := Plan_Show (P (10.0, 10.0), P (43.0, 43.0), "open");
   begin
      Check (R.Result = Found and then not Last_Stats.Out_Of_Reach, "through the door");
   end;
   Fill (42.5, 40.0, 43.5, 40.25, Ground_Row, Ground_Row + 11, Plank);       --  shut it
   declare
      R : constant Route := Plan_Show (P (10.0, 10.0), P (43.0, 43.0), "shut");
   begin
      Check (R.Result = Partial and then Last_Stats.Out_Of_Reach and then Straight (R.Pts (R.N).P, P (43.0, 43.0)) < 3.5,
             "shut, the pieces show the room out of reach: the route ends at the wall");
   end;
   Fill (42.5, 40.0, 43.5, 40.25, Ground_Row, Ground_Row + 7, Air);          --  open again
   declare
      R : constant Route := Plan_Show (P (10.0, 10.0), P (43.0, 43.0), "opened again");
   begin
      Check (R.Result = Found, "opened again, it is found: the pieces follow the edits");
   end;
   declare
      R : constant Route := Plan_Show (P (43.0, 43.0), P (10.0, 10.0), "and out again");
   begin
      Check (R.Result = Found, "and the way out too");
   end;

   ------------------------------------------------------------ 10. an edit
   Put_Line ("a wall built across a route:");
   Meadow;
   declare
      A : constant Vec3 := P (10.0, 10.0);
      Z : constant Vec3 := P (50.0, 10.0);
      R : constant Route := Plan_Show (A, Z, "before");
   begin
      Fill (30.0, 0.0, 30.25, 64.0, Ground_Row, Ground_Row + 11, Plank);
      Fill (30.0, 40.0, 30.25, 41.0, Ground_Row, Ground_Row + 7, Air);
      Check (Changed (R), "the route knows its ground changed");
      Check (not Still_Good (R, 1), "and that it can't be walked any more");
      declare
         R2 : constant Route := Plan_Show (A, Z, "after");
      begin
         Check (R2.Result = Found and then Length (R2) > 70.0, "planned again, it goes by the door");
      end;
   end;
   Meadow;
   declare
      R : constant Route := Plan_Show (P (10.0, 10.0), P (50.0, 10.0), "before a wall off to the side");
   begin
      Fill (10.0, 40.0, 20.0, 40.25, Ground_Row, Ground_Row + 11, Plank);
      Check (Changed (R) and then Still_Good (R, 1), "an edit off the route: changed ground, the route still good");
   end;

   ------------------------------------------------------------ 11. seed 1
   declare
      use Ada.Real_Time;
      N_Routes : Natural := 40;
   begin
      for A in 1 .. Ada.Command_Line.Argument_Count - 1 loop
         if Ada.Command_Line.Argument (A) = "--real" then
            N_Routes := Natural'Value (Ada.Command_Line.Argument (A + 1));
         end if;
      end loop;
      if N_Routes > 0 then
         Put_Line ("seed 1, 128 m square round the default view:");
         declare
            W    : World;
            Work : constant Stack_Work_Access := new Stack_Work;
            T0   : Time := Clock;
            CX0  : constant := 140;
            CY0  : constant := 128;
            Side : constant := 16;
         begin
            Castle.Worldgen.Create (Castle.Hash.U64 (1), W, Report => False);
            Put_Line ("    world made in " & Img (Float (To_Duration (Clock - T0)), 1) & " s");
            T0 := Clock;
            for CX in CX0 .. CX0 + Side - 1 loop
               for CY in CY0 .. CY0 + Side - 1 loop
                  declare
                     S   : Chunk_Stack_Access := new Chunk_Stack;
                     Sum : Castle.Water.Summary_Access := new Castle.Water.Ground_Summary;
                     Gen : Natural;
                     Rim : Castle.Edits.Rim_Access;
                  begin
                     Generate (W, CX, CY, Work.all);
                     declare
                        Old_Skin : constant Skin_Grid := Work.Skin;
                     begin
                        Castle.Edits.Apply (CX, CY, Work, Gen, Rim);
                        Deepen (W, CX, CY, Work.all, Old_Skin);
                     end;
                     Castle.Edits.Free (Rim);
                     Pack (Work.all, S.all);
                     Castle.Water.Summarize (Work.all, Sum.all);
                     Castle.World_Blocks.Keep (CX, CY, S, Gen, Sum);
                  end;
               end loop;
            end loop;
            Put_Line ("    " & Integer'Image (Side * Side) & " stacks built in "
                      & Img (Float (To_Duration (Clock - T0)), 1) & " s");
         end;
         declare
            function Real_Block (Bx, By, Bz : Integer) return Material is
              (Castle.World_Blocks.Block_At (Bx, By, Bz).Mat);
            Lo_X : constant Float := 140.0 * 8.0 + 4.0;
            Lo_Y : constant Float := 128.0 * 8.0 + 4.0;
            Span : constant Float := 120.0;
            Seed : Castle.Hash.U64 := 7;
            Found_N, Partial_N, None_N : Natural := 0;
            Total_Ms, Max_Ms, Detour_Sum : Float := 0.0;
            Time_W, Time_Best, Worst_Ratio : Float := 0.0;
            Same_Answer : Boolean := True;
            Cut_Again_N, Cut_Proven_N : Natural := 0;
            Cut_Again_Ms : Float := 0.0;
            type Pair is record
               A, Z : Vec3;
            end record;
            Cut_Off : array (1 .. 64) of Pair;
            Cut_N : Natural := 0;
            Looked_Sum : Natural := 0;
            Built_First : Natural := 0;
            function Rnd return Float is
            begin
               Seed := Castle.Hash.Derive (Seed, 1);
               return Castle.Hash.Unit (Seed);
            end Rnd;
         begin
            Set_Source (Castle.World_Blocks.Ground'Access, Real_Block'Unrestricted_Access,
                        Castle.World_Blocks.Ground_Version'Access);
            for K in 1 .. N_Routes loop
               declare
                  A : Vec3 := (Lo_X + Span * Rnd, Lo_Y + Span * Rnd, 0.0);
                  Z : Vec3 := (Lo_X + Span * Rnd, Lo_Y + Span * Rnd, 0.0);
               begin
                  A.Z := Surface_Z (A.X, A.Y);
                  Z.Z := Surface_Z (Z.X, Z.Y);
                  if A.Z >= 0.0 and then Z.Z >= 0.0 then
                     declare
                        R  : constant Route := Plan (A, Z);
                        Ms : constant Float := Last_Stats.Seconds * 1000.0;
                     begin
                        if K = 1 then
                           Built_First := Last_Stats.Stacks;
                        end if;
                        case R.Result is
                           when Found =>
                              Found_N := Found_N + 1;
                              Detour_Sum := Detour_Sum + Length (R) / Float'Max (1.0, Straight (A, Z));
                              if not Still_Good (R, 1) then
                                 Check (False, "route" & K'Image & " can be walked step by step");
                              end if;
                           when Partial => Partial_N := Partial_N + 1;
                           when None => None_N := None_N + 1;
                        end case;
                        Total_Ms := Total_Ms + Ms;
                        Max_Ms := Float'Max (Max_Ms, Ms);
                        Looked_Sum := Looked_Sum + Last_Stats.Looked_At;
                        if R.Result = Partial and then Cut_N < Cut_Off'Last then
                           Cut_N := Cut_N + 1;
                           Cut_Off (Cut_N) := (A, Z);
                        end if;
                        --  against a search of everything for the quickest route
                        Use_Labels (False);
                        declare
                           Q : constant Route := Plan (A, Z, Weight => 1.0);
                        begin
                           Same_Answer := Same_Answer and then Q.Result = R.Result;
                           if R.Result = Found and then Q.Result = Found and then Total_Time (Q) > 0.0 then
                              Time_W := Time_W + Total_Time (R);
                              Time_Best := Time_Best + Total_Time (Q);
                              Worst_Ratio := Float'Max (Worst_Ratio, Total_Time (R) / Total_Time (Q));
                           end if;
                        end;
                        Use_Labels (True);
                     end;
                  end if;
               end;
            end loop;
            declare
               Planned : constant Natural := Found_N + Partial_N + None_N;
            begin
               Put_Line ("    " & Planned'Image & " routes between random points up to 170 m apart:"
                         & Found_N'Image & " found," & Partial_N'Image & " cut off (water, cliffs),"
                         & None_N'Image & " none");
               Put_Line ("    the first built the floors of" & Built_First'Image & " stacks on the way");
               Put_Line ("    time:" & " mean " & Img (Total_Ms / Float (Integer'Max (1, Planned)), 2)
                         & " ms, longest " & Img (Max_Ms, 2) & " ms; mean floors looked at"
                         & Integer'Image (Looked_Sum / Integer'Max (1, Planned)));
               for K in 1 .. Cut_N loop
                  declare
                     R : constant Route := Plan (Cut_Off (K).A, Cut_Off (K).Z);
                  begin
                     Cut_Again_N := Cut_Again_N + 1;
                     Cut_Again_Ms := Cut_Again_Ms + Last_Stats.Seconds * 1000.0;
                     if Last_Stats.Out_Of_Reach and then R.Result = Partial then
                        Cut_Proven_N := Cut_Proven_N + 1;
                     end if;
                  end;
               end loop;
               Check (Same_Answer, "the pieces of ground never call a goal out of reach that a full search finds");
               Check (Time_Best = 0.0 or else (Worst_Ratio <= Heuristic_Weight + 0.02 and then Time_W / Time_Best < 1.01),
                      "the routes are " & Img ((Time_W / Float'Max (1.0, Time_Best) - 1.0) * 100.0, 2)
                      & " % slower than the quickest on the whole (the worst " & Img ((Worst_Ratio - 1.0) * 100.0, 1)
                      & " %, at most " & Img ((Heuristic_Weight - 1.0) * 100.0, 0) & ")");
               Check (Cut_Proven_N = Cut_Again_N,
                      "a goal cut off, asked for again, is shown out of reach at once:" & Cut_Proven_N'Image & " of"
                      & Cut_Again_N'Image & ", " & Img (Cut_Again_Ms / Float (Integer'Max (1, Cut_Again_N)), 2)
                      & " ms each (the first time " & Img (Max_Ms, 2) & " ms at worst)");
               Check (Found_N > Planned / 2, "most routes are found");
               Check (Found_N = 0 or else Detour_Sum / Float (Found_N) < 1.5,
                      "and go not far out of the way: " & Img (Detour_Sum / Float (Integer'Max (1, Found_N)), 3)
                      & " times the straight distance on average");
            end;
         end;
      end if;
   end;

   New_Line;
   if Fails = 0 then
      Put_Line ("all checks passed");
   else
      Put_Line (Fails'Image & " checks FAILED");
      Ada.Command_Line.Set_Exit_Status (1);
   end if;
end Path_Check;
