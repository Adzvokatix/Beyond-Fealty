--  Pointing at things, without a window: on the made-up meadow a ray finds
--  the person in front of the zone in front of the block; never a person
--  behind a wall; a zone by its ground or by the goods heaped on it; a deer;
--  someone asleep where the body lies, not where it stood; nothing beyond
--  reach; and with slack, a figure the ray only passes near.
--  ./bin/debug/pick_check   (exits 1 on any failure)

with Ada.Text_IO;      use Ada.Text_IO;
with Ada.Command_Line;
with Ada.Numerics.Elementary_Functions; use Ada.Numerics.Elementary_Functions;
with Castle.Blocks;    use Castle.Blocks;
with Castle.Colony;    use Castle.Colony;
with Castle.Herds;
with Castle.Math;      use Castle.Math;
with Castle.Pick;      use Castle.Pick;
with Castle.Text;      use Castle.Text;
with Test_World;       use Test_World;

procedure Pick_Check is

   Fails : Natural := 0;

   procedure Check (Ok : Boolean; What : String) is
   begin
      Put_Line ((if Ok then "  ok    " else "  FAIL  ") & What);
      if not Ok then
         Fails := Fails + 1;
      end if;
   end Check;

   Hours : Long_Float := 16.0 * 24.0 + 9.0;

   procedure Run (Seconds : Natural) is
   begin
      for S in 1 .. Seconds loop
         Hours := Hours + 1.0 / 60.0;
         Advance (1.0, Hours);
      end loop;
   end Run;

   --  A look from Eye toward At_P, as the game looks along the cursor's ray:
   --  walked into the blocks first, then asked what it points at.
   function See (Eye, At_P : Vec3; Reach : Float := No_Limit; Slack : Float := 0.0) return Thing is
      Dir : constant Vec3 := Normalize (At_P - Eye);
   begin
      return Look (Eye, Dir, Cast (Eye, Dir, 200.0), Reach, Slack);
   end See;

   function Said (T : Thing) return String is
     (T.Kind'Image & (if T.Index > 0 then T.Index'Image else "") & " at " & Img (T.Dist, 1) & " m");

   Laid, Cells : Natural;
   Ok : Boolean;
   Above : constant Vec3 := (-6.0, -6.0, 9.0);    --  where the eye is, from what it looks at
begin
   Attach;
   Reset;
   Set_Needs (False);
   Set_Demand_Chain (False);
   Meadow;
   Place_Stake ((20.0, 20.0, Ground_M), 6, 42);
   Lay_Path ((20.5, 17.5, Ground_M), (40.0, 17.5, Ground_M), Laid);
   Zone_Stockpile (21.0, 15.0, 25.0, 17.0, Cells);

   Put_Line ("the block, a zone, a person:");
   declare
      T : Thing := See ((40.0, 40.0, 16.0), (45.2, 45.3, Ground_M));
   begin
      Check (T.Kind = A_Block and then T.Ground.Found and then T.Ground.Z = Ground_Row - 1
             and then abs (T.Point.Z - Ground_M) < 0.01 and then abs (T.Point.X - 45.2) < 0.01
             and then T.Ground.Nz = 1,
             "open meadow: the block, where the ray lands on its top (" & Said (T) & ")");
      T := See ((22.5, 5.5, 14.0), (22.5, 15.5, Ground_M));
      Check (T.Kind = A_Zone and then T.Index = 1 and then Zone_At (1).Kind = Stockpile_Zone,
             "a stockpile cell with nobody on it: the zone (" & Said (T) & ")");
      T := See (Where (3) + Above, Where (3) + (0.0, 0.0, 1.0));
      Check (T.Kind = A_Person and then T.Index = 3 and then T.Dist < T.Ground.Dist,
             "someone standing on the meadow: the person, in front of the ground (" & Said (T) & ")");
      T := See (Where (3) + Above, Where (3) + (0.0, 0.0, Genome_Of (3).Height + 0.6));
      Check (T.Kind = A_Block, "over its head: the ground behind (" & Said (T) & ")");
   end;

   Put_Line ("the person in front of the zone in front of the block:");
   declare
      P  : constant Vec3 := Where (3);
      Fx : constant Float := Float'Floor (P.X);
      Fy : constant Float := Float'Floor (P.Y);
      T  : Thing;
   begin
      --  (a path along the lot's north side: one through it would stop the zone at the path)
      Lay_Path ((P.X - 3.0, Fy + 2.5, Ground_M), (P.X + 3.0, Fy + 2.5, Ground_M), Laid);
      Zone_Stockpile (Fx - 1.0, Fy - 1.0, Fx + 2.0, Fy + 2.0, Cells);
      Check (Cells >= 8 and then Zone_On (P.X, P.Y) = 2,
             "a stockpile zoned round where member 3 stands (" & Img (Cells) & " cells): it is in zone 2");
      T := See (P + Above, P + (0.0, 0.0, 1.0));
      Check (T.Kind = A_Person and then T.Index = 3, "pointing at the person: the person (" & Said (T) & ")");
      T := See (P + Above, P + (-0.32, -0.32, 0.0));
      Check (T.Kind = A_Zone and then T.Index = 2,
             "at the ground by its feet: the zone it stands in (" & Said (T) & ")");
      T := See (P + Above, P + (-4.5, -4.5, 0.0));
      Check (T.Kind = A_Block, "at the meadow outside the zone: the block (" & Said (T) & ")");
   end;

   Put_Line ("walls and reach:");
   declare
      P    : constant Vec3 := Where (3);
      Low  : constant Vec3 := P + (-8.0, 0.0, 1.5);
      Mid  : constant Vec3 := P + (0.0, 0.0, 1.0);
      T    : Thing := See (Low, Mid);
      Snap : Snapshot;
   begin
      Check (T.Kind = A_Person and then T.Index = 3, "looking level from 8 m off: the person (" & Said (T) & ")");
      Take (Snap);
      Fill (P.X - 3.0, P.Y - 2.0, P.X - 2.5, P.Y + 2.0, Ground_Row, Ground_Row + 11, Plank);
      T := See (Low, Mid);
      Check (T.Kind = A_Block and then Get (T.Ground.X, T.Ground.Y, T.Ground.Z) = Plank,
             "with a wall between: the wall, not the person behind it (" & Said (T) & ")");
      Give_Back (Snap);
      T := See (Low, Mid, Reach => Reach_M);
      Check (T.Kind = Nothing, "8 m off with the reach of someone on foot (" & Img (Float'(Reach_M), 1)
             & " m): nothing");
      T := See (P + (-4.0, 0.0, 1.5), Mid, Reach => Reach_M);
      Check (T.Kind = A_Person and then T.Index = 3, "4 m off: within reach (" & Said (T) & ")");
      T := See (P + (-4.0, 0.0, 1.5), P + (-9.0, 0.0, 0.0), Reach => Reach_M);
      Check (T.Kind = A_Block and then T.Dist <= Reach_M, "the ground at its feet is in reach (" & Said (T) & ")");
      T := See (P + (0.0, 2.0, 1.5), P + (0.0, 22.0, 0.0), Reach => Reach_M);
      Check (T.Kind = Nothing and then T.Ground.Found, "the ground 20 m off is not");
   end;

   Put_Line ("slack:");
   declare
      P   : constant Vec3 := Where (3);
      Eye : constant Vec3 := P + (-12.0, 0.0, 1.2);
      T   : Thing := See (Eye, P + (0.0, 0.7, 1.2));
   begin
      Check (T.Kind /= A_Person, "a ray passing 0.7 m beside someone does not mean them (" & Said (T) & ")");
      T := See (Eye, P + (0.0, 0.7, 1.2), Slack => 0.05);
      Check (T.Kind = A_Person and then T.Index = 3,
             "with 5 cm of slack to the metre, 12 m off, it does (" & Said (T) & ")");
      T := See (Eye, P + (0.0, 0.0, 1.2), Slack => 0.5);
      Check (T.Kind = A_Person and then T.Index = 3,
             "and whoever the ray truly passes through comes before anyone it only passes near");
   end;

   Put_Line ("in a crowd:");
   declare
      --  two of the band in one line of sight: the eye behind member 2, looking through it at member 3
      P2  : constant Vec3 := Where (2);
      P3  : constant Vec3 := Where (3);
      Way : constant Vec3 := Normalize ((P2.X - P3.X, P2.Y - P3.Y, 0.0));
      Eye : constant Vec3 := P2 + Way * 6.0 + (0.0, 0.0, 1.0);
      T   : Thing := See (Eye, P3 + (0.0, 0.0, 1.0));
      function Again (Keep : Thing) return Thing is
         Dir : constant Vec3 := Normalize (P3 + (0.0, 0.0, 1.0) - Eye);
      begin
         return Look (Eye, Dir, Cast (Eye, Dir, 200.0), Keep => Keep);
      end Again;
   begin
      Check (T.Kind = A_Person and then T.Index = 2,
             "two in one line of sight: the nearer is the one pointed at (" & Said (T) & ")");
      T := Again ((Kind => A_Person, Index => 3, others => <>));
      Check (T.Kind = A_Person and then T.Index = 3,
             "but whoever was pointed at a moment ago is kept while the ray is still on them (" & Said (T) & ")");
      T := Again ((Kind => A_Person, Index => 5, others => <>));
      Check (T.Kind = A_Person and then T.Index = 2, "someone the ray is no longer on is not kept");
   end;

   Put_Line ("goods and the camp:");
   declare
      Placed : Natural;
      C1  : constant Vec3 := Cell_At (1).Centre;
      Eye : constant Vec3 := C1 + (0.0, -12.0, 1.2);
      T   : Thing := See (Eye, C1 + (0.0, 0.0, 0.3));
   begin
      Check (T.Kind /= A_Zone or else T.Index /= 1,
             "a low look over an empty cell lands beyond it (" & Said (T) & ")");
      Supply (Wood, 5, Placed);
      T := See (Eye, C1 + (0.0, 0.0, 0.3));
      Check (Cell_At (1).Count = 5 and then T.Kind = A_Zone and then T.Index = 1,
             "with logs stacked on it the same look finds the stockpile, by its goods (" & Said (T) & ")");
      Zone_Camp ((30.0, 26.0, Ground_M), Ok);
      T := See (Camp + Above, Camp + (2.0, 2.0, 0.0));
      Check (Ok and then T.Kind = A_Zone and then T.Index = Camp_Zone,
             "the camp's ground: the camp (" & Said (T) & ")");
      T := See (Camp + (-14.0, 0.0, 1.6), Camp + (0.0, 0.0, 0.8));
      Check (not Camp_State.Built and then T.Kind /= A_Zone,
             "a camp not built yet has no hearth to point at: a low look goes over its ground (" & Said (T) & ")");
      Build_Camp_Now;
      T := See (Camp + (-14.0, 0.0, 1.6), Camp + (0.0, 0.0, 0.8));
      Check (T.Kind = A_Zone and then T.Index = Camp_Zone and then T.Dist < 14.0,
             "built, a low look at the pot: the camp, by its hearth (" & Said (T) & ")");
      T := See (Camp + Above, Camp + (4.5, 0.0, 0.0));
      Check (T.Kind = A_Block, "a metre outside its square: the block");
   end;

   Put_Line ("deer:");
   Run (5);
   declare
      Found : Natural := 0;
      T     : Thing;
   begin
      for K in 1 .. Castle.Herds.Deer_Slots loop
         if Castle.Herds.Alive (K) and then Found = 0 then
            Found := K;
         end if;
      end loop;
      Check (Found > 0, "the herds are out (" & Img (Castle.Herds.Deer_Slots) & " deer)");
      if Found > 0 then
         declare
            C : constant Capsule := Herd_Deer (Found);
            M : constant Vec3 := (C.A + C.B) * 0.5;
         begin
            T := See (M + Above, M);
            Check (T.Kind = A_Deer and then T.Index = Found, "pointing at a deer: the deer (" & Said (T) & ")");
         end;
      end if;
   end;

   Put_Line ("asleep:");
   Set_Needs (True);
   Hours := 16.0 * 24.0 + 23.0;
   Run (60);
   declare
      Who : Natural := 0;
      T   : Thing;
   begin
      for I in 1 .. Members loop
         if Doing (I) = Sleeping and then Who = 0 then
            Who := I;
         end if;
      end loop;
      Check (Who > 0, "by midnight someone is asleep");
      if Who > 0 then
         declare
            C : constant Capsule := Colony_Person (Who);
            M : constant Vec3 := (C.A + C.B) * 0.5;
            L : constant Vec3 := C.B - C.A;
            F : constant Vec3 := Where (Who);
         begin
            Check (abs L.Z < 0.01 and then abs (Sqrt (Dot (L, L)) - Genome_Of (Who).Height) < 0.01
                   and then abs (C.A.X - F.X) < 0.01 and then abs (C.A.Y - F.Y) < 0.01,
                   "a sleeper lies flat, as long as it is tall, from where its feet are");
            T := See (M + (0.0, 0.0, 9.0), M);
            Check (T.Kind = A_Person and then T.Index = Who, "pointing at the middle of it: the sleeper (" & Said (T) & ")");
            T := See (F + (L.Y, -L.X, 0.0) * 3.0 + (0.0, 0.0, 1.4), F + (0.0, 0.0, 1.4));
            Check (T.Kind /= A_Person or else T.Index /= Who,
                   "where its chest was when it stood: not the sleeper");
         end;
      end if;
   end;

   Put_Line ("a house:");
   Set_Needs (False);
   declare
      Lots : Natural;
      T    : Thing;
   begin
      Lay_Path ((44.0, 20.0, Ground_M), (44.0, 58.0, Ground_M), Laid);
      Zone_Housing (44.6, 22.0, 55.0, 43.0, Lots);
      Run (2);
      Check (Lots >= 2 and then House_Count = 1, "housing zoned beside a path: a hovel is begun on it");
      if House_Count = 1 then
         declare
            V   : constant House_View := House_At (1);
            Mid : constant Vec3 := (V.Corner (1) + V.Corner (3)) * 0.5;
         begin
            T := See (Mid + (-6.0, -6.0, 12.0), Mid);
            Check (T.Kind = A_House and then T.Index = 1,
                   "pointing at the ground its walls are to stand on: the house (" & Said (T) & ")");
            T := See ((53.0, 37.0, 14.0), (53.0, 41.0, Ground_M));
            Check (T.Kind = A_Zone and then Zone_At (T.Index).Kind = Habitation_Zone,
                   "at the zone's ground beyond its lot: the zone (" & Said (T) & ")");
            Build_Homes_Now;
            T := See (Mid + (-6.0, -6.0, 14.0), Mid + (0.0, 0.0, 2.0));
            Check (T.Kind = A_House and then T.Index = 1 and then T.Point.Z > Ground_M + 2.0,
                   "built, pointing at its roof from above: the house, where the ray meets the thatch (" & Said (T) & ")");
            T := See (V.Door + (V.Door - Mid) * 2.0 + (0.0, 0.0, 1.5), V.Door + (Mid - V.Door) * 0.3 + (0.0, 0.0, 1.2));
            Check (T.Kind = A_House and then T.Index = 1,
                   "and from the path at its front wall: the house (" & Said (T) & ")");
            T := See (Mid + (-6.0, -6.0, 14.0), Mid + (0.0, 0.0, 2.0), Reach => 6.0);
            Check (T.Kind = Nothing, "out of reach, nothing");
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
end Pick_Check;
