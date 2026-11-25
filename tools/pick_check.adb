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
with Castle.Cutaway;
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
   Set_Stockpile_Least (0.0);      --  (its stockpiles are small: any size, as before 2026-11-17,
   Set_Overflow (False);           --  with no overflow round them)
   Set_Storehouse (False);
   Set_Last_Places (0);            --  (and none of their places kept, as before 2026-11-18)
   Set_Path_Level (False);         --  (and a path laid on the ground as it lies, as before 2026-11-19)
   Set_Roof_Timbers (False);       --  (and a house without its roof's timbers or its windows' timber)
   Set_Window_Timber (False);
   Set_One_Stockpile (True);       --  (and the stockpile placed once, the stores moved into the stockyard, as before 2026-11-19)
   Set_Stores_Move (True);
   Set_Box_Place (False);          --  (and no stockpile put down whole with its path, as before 2026-11-20)
   Set_Yard_Box (False);           --  (nor the stockyard: zoned corner to corner, as before 2026-11-21)
   Set_Store_Size (40, 20, 18);    --  (and its storehouse as it was)
   Set_Store_Stacks (False);       --  (a place in it its own, one barrel to a place)
   Set_Wood_Reach (False);         --  (and a forester's trees no further than the work radius)
   Set_House_Turn (False);         --  (and no house turned)
   Set_Bush_Sharing (False);
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
            T := See ((50.0, 37.0, 14.0), (50.0, 41.0, Ground_M));
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

            --  its roof cleared on the camera's ray (Castle.Cutaway: drawing and pointing only)
            declare
               use Castle.Cutaway;
               B    : constant House_View := House_At (1);
               R    : constant Roof := Of_Corners (1, B.Corner (1), B.Corner (2), B.Corner (3), B.Corner (4), B.Top_Z);
               Eye  : constant Vec3 := Mid + (-6.0, -6.0, 14.0);
               Eave : constant Vec3 :=                --  over the middle of its front wall, a little out from it
                 (B.Corner (1) + B.Corner (2)) * 0.5 + Normalize (B.Corner (1) - B.Corner (4)) * 0.15;
               Roof_Z : Float;
               Took   : Natural := 0;
            begin
               Follow (Eye, Mid, [R], 0.05);
               Check (Castle.Cutaway.Count = 1 and then abs (Shown (1).Amount - 0.2) < 1.0e-4,
                      "the eye looks at its floor: its roof begins to clear (a fifth in a twentieth of a second)");
               while Castle.Cutaway.Count = 1 and then Shown (1).Amount < 1.0 and then Took < 20 loop
                  Follow (Eye, Mid, [R], 0.05);
                  Took := Took + 1;
               end loop;
               Check (Castle.Cutaway.Count = 1 and then Shown (1).Amount = 1.0 and then Took = 4,
                      "cleared in a quarter of a second (" & Img (Took + 1) & " steps)");
               Check (abs (Cover_At (Eave.X, Eave.Y, B.Top_Z - 1.0) - Edge_Cover) < 1.0e-4
                      and then Cover_At (Mid.X, Mid.Y, B.Top_Z) < 1.0e-4
                      and then Cover_At (Mid.X + 40.0, Mid.Y, B.Top_Z) = 1.0,
                      "drawn at half over its eaves, not at all in its middle, whole elsewhere");
               T := See (Eye, Mid + (0.0, 0.0, 2.0));
               Check (T.Kind = A_House and then T.Index = 1 and then T.Point.Z < Ground_M + 1.0,
                      "pointing at its middle through the cleared roof: the house, at its floor (" & Said (T) & ")");
               T := See (Eave + (0.0, 0.0, 12.0), Eave);
               Roof_Z := T.Point.Z;
               Check (T.Kind = A_House and then Roof_Z > Ground_M + 2.0,
                      "down on its eave, drawn at half: the thatch (" & Said (T) & ")");
               Took := 0;
               while Castle.Cutaway.Count > 0 and then Took < 20 loop
                  Follow (Eye, Mid + (30.0, 0.0, 0.0), [R], 0.05);
                  Took := Took + 1;
               end loop;
               T := See (Eye, Mid + (0.0, 0.0, 2.0));
               Check (Castle.Cutaway.Count = 0 and then Took = 5 and then T.Point.Z > Ground_M + 2.0,
                      "the eye looks past it: its roof comes back in a quarter of a second, and the ray meets the thatch ("
                      & Said (T) & ")");
               Set_View (None);
               for K in 1 .. 10 loop
                  Follow (Eye, Mid, [R], 0.05);
               end loop;
               Check (Castle.Cutaway.Count = 0, "--no-cutaway: nothing clears");
               Set_View (Dynamic);

               --  the pointer's ray, a ray that only passes over, and every roof at once
               declare
                  Far   : constant Vec3 := Mid + (30.0, 0.0, 0.0);      --  where the eye looks: not at the house
                  Aim   : constant Vec3 := Mid + (0.0, 0.0, 2.0);       --  where the pointer is: on its roof
                  Dir   : constant Vec3 := Normalize (Aim - Eye);
                  Ridge : constant Vec3 :=
                    (if R.Half_A >= R.Half_B then R.Along else (-R.Along.Y, R.Along.X, 0.0));
                  Aside : constant Vec3 := (-Ridge.Y, Ridge.X, 0.0) * (Float'Min (R.Half_A, R.Half_B) / 2.0);
                  Stays : Boolean := True;
                  Many  : Roof_List (1 .. 12);
                  All_Clear : Boolean := True;
               begin
                  --  (as the game does: where the ray landed a frame ago, and a little on)
                  for K in 1 .. 30 loop
                     T := See (Eye, Aim);
                     Follow (Eye, Far, [R], 0.05, Pointing => T.Ground.Found,
                             Pointed => Eye + Dir * (T.Ground.Dist + 0.3));
                     if K > 6 and then (Castle.Cutaway.Count /= 1 or else Shown (1).Amount < 1.0) then
                        Stays := False;
                     end if;
                  end loop;
                  T := See (Eye, Aim);
                  Check (Stays and then T.Point.Z < Ground_M + 1.0,
                         "the pointer on its roof, the eye elsewhere: it clears, and stays cleared with the ray gone on to "
                         & "its floor (" & Said (T) & ")");
                  for K in 1 .. 10 loop
                     T := See (Eye, Far);
                     Follow (Eye, Far, [R], 0.05, Pointing => T.Ground.Found,
                             Pointed => Eye + Normalize (Far - Eye) * (T.Ground.Dist + 0.3));
                  end loop;
                  Check (Castle.Cutaway.Count = 0, "the pointer on the ground beyond it: its roof comes back");
                  Check (Crosses (R.Centre - Ridge * 10.0 + (0.0, 0.0, R.Top_Z - R.Centre.Z + 0.3),
                                  R.Centre + Ridge * 10.0 + (0.0, 0.0, R.Top_Z - R.Centre.Z + 0.3), R)
                         and then not Crosses (R.Centre - Ridge * 10.0 + (0.0, 0.0, R.Top_Z - R.Centre.Z + 1.0),
                                               R.Centre + Ridge * 10.0 + (0.0, 0.0, R.Top_Z - R.Centre.Z + 1.0), R)
                         and then not Crosses (R.Centre + Aside - Ridge * 10.0 + (0.0, 0.0, R.Top_Z - R.Centre.Z - 0.2),
                                               R.Centre + Aside + Ridge * 10.0 + (0.0, 0.0, R.Top_Z - R.Centre.Z - 0.2), R),
                         "a ray along its ridge crosses it; one a metre over, or beside the ridge over a slope, does not");
                  for K in Many'Range loop
                     Many (K) := Of_Corners (K, (100.0 + 20.0 * Float (K), 300.0, Ground_M),
                                             (106.0 + 20.0 * Float (K), 300.0, Ground_M),
                                             (106.0 + 20.0 * Float (K), 305.0, Ground_M),
                                             (100.0 + 20.0 * Float (K), 305.0, Ground_M), Ground_M + 5.0);
                  end loop;
                  for K in 1 .. 6 loop
                     Follow (Eye, Far, Many, 0.05);
                  end loop;
                  Check (Castle.Cutaway.Count = 0, "a dozen houses the eye and the pointer are not on: none cleared");
                  Set_View (Full);
                  for K in 1 .. 6 loop
                     Follow (Eye, Far, Many, 0.05);
                  end loop;
                  for K in 1 .. Castle.Cutaway.Count loop
                     All_Clear := All_Clear and then Shown (K).Amount = 1.0;
                  end loop;
                  Check (Castle.Cutaway.Count = 12 and then All_Clear, "every roof asked for: all twelve cleared at once");
                  Set_View (Dynamic);
                  for K in 1 .. 6 loop
                     Follow (Eye, Far, Many, 0.05);
                  end loop;
                  Check (Castle.Cutaway.Count = 0, "and no longer asked for, all back");
                  Castle.Cutaway.Clear;

                  --  the walls on the eye's side of a cleared house (John, 2026-11-13: "cut down the walls
                  --  in-line with the camera too")
                  declare
                     Out_V : constant Vec3 := Normalize (B.Corner (1) - B.Corner (4));   --  out of its front wall
                     Front : constant Vec3 := (B.Corner (1) + B.Corner (2)) * 0.5;       --  the middle of its front wall,
                     Back  : constant Vec3 := (B.Corner (3) + B.Corner (4)) * 0.5;       --  and of its back
                     Side  : constant Vec3 := (B.Corner (2) + B.Corner (3)) * 0.5;       --  and of one side
                     Low   : constant Vec3 := Front + Out_V * 12.0 + (0.0, 0.0, 5.0);    --  an eye before its front, low
                     In_W  : constant Float := 0.125;                                    --  (a wall block's middle)
                     --  a ray through its front wall well clear of its door and under its windows
                     Along_W : constant Vec3 := Normalize (B.Corner (2) - B.Corner (1));
                     Wide    : constant Float := Sqrt (Dot (B.Corner (2) - B.Corner (1), B.Corner (2) - B.Corner (1)));
                     Door_U  : constant Float := Dot (B.Door - B.Corner (1), Along_W);
                     At_W    : constant Vec3 :=
                       B.Corner (1) + Along_W * (if Door_U > Wide / 2.0 then Wide * 0.2 else Wide * 0.8);
                     From_W  : constant Vec3 := At_W + Out_V * 12.0 + (0.0, 0.0, 3.0);
                     To_W    : constant Vec3 := At_W - Out_V * 2.0 + (0.0, 0.0, 0.2);
                     Wall_D  : constant Float := Sqrt (Dot (At_W - From_W, At_W - From_W));
                  begin
                     for K in 1 .. 8 loop
                        Follow (Low, Mid, [R], 0.05);
                     end loop;
                     Check (Castle.Cutaway.Count = 1 and then Shown (1).Amount = 1.0
                            and then Wall_Cover_At (Front.X - Out_V.X * In_W, Front.Y - Out_V.Y * In_W, Ground_M + 1.0) < 1.0e-4
                            and then Wall_Cover_At (Back.X + Out_V.X * In_W, Back.Y + Out_V.Y * In_W, Ground_M + 1.0) = 1.0
                            and then Wall_Cover_At (Mid.X, Mid.Y, Ground_M + 1.0) = 1.0
                            and then Wall_Cover_At (Front.X - Out_V.X * In_W, Front.Y - Out_V.Y * In_W, Ground_M + 0.01) = 1.0,
                            "an eye before its front: its front wall is cleared, its back wall, its middle and its floor whole");
                     Check (Wall_Cover_At (Side.X - (Side.X - Mid.X) / 20.0, Side.Y - (Side.Y - Mid.Y) / 20.0, Ground_M + 1.0) = 1.0,
                            "and a side wall the eye sees edge-on stands whole");
                     T := See (From_W, To_W);
                     Check (T.Kind = A_House and then T.Dist > Wall_D + 1.0,
                            "pointing through its cleared front wall, clear of its door: the ray goes on inside ("
                            & Said (T) & ")");
                     Set_View (None);
                     for K in 1 .. 8 loop
                        Follow (Low, Mid, [R], 0.05);
                     end loop;
                     T := See (From_W, To_W);
                     Check (Castle.Cutaway.Count = 0 and then T.Dist < Wall_D + 0.5,
                            "the third view, none: nothing clears and the ray meets the wall (" & Said (T) & ")");
                     Check (View'Succ (Dynamic) = Full and then View'Succ (Full) = None and then View'First = Dynamic
                            and then View'Last = None,
                            "the three views in his order: dynamic, full, none");
                     Set_View (Dynamic);
                     Castle.Cutaway.Clear;
                  end;
               end;
            end;
         end;
      end if;
   end;

   Put_Line ("the lord's cart:");
   declare
      C : constant Cart_View := Cart;
      T : Thing;
   begin
      T := See (C.At_P + (-3.0, -4.0, 9.0), C.At_P + (0.0, 0.0, 0.75));
      Check (C.Here and then T.Kind = A_Cart and then T.Point.Z > C.At_P.Z + 0.5,
             "pointing at its bed from above: the cart, where the ray meets the bed (" & Said (T) & ")");
      T := See (C.At_P + (2.5, 0.0, 9.0), C.At_P + (2.5, 0.0, 0.0));
      Check (T.Kind /= A_Cart, "at the ground a metre and a half past its end: not the cart (" & Said (T) & ")");
      T := See (C.At_P + (-3.0, -4.0, 9.0), C.At_P + (0.0, 0.0, 0.75), Reach => 6.0);
      Check (T.Kind = Nothing, "out of reach, nothing");
   end;

   --  A house drawn turned is pointed at where it is drawn (the fourth step of the turned building).
   Put_Line ("a house drawn turned:");
   Reset;
   Set_House_Turn (True);
   Set_Needs (False);
   Set_Demand_Chain (False);
   Meadow;
   Place_Stake ((6.0, 6.0, Ground_M), 6, 42);
   declare
      Lots : Natural;
      function See_T (Eye, At_P : Vec3) return Thing is
         Dir : constant Vec3 := Normalize (At_P - Eye);
      begin
         return Look (Eye, Dir, Cast (Eye, Dir, 200.0), Cast => Cast'Access);
      end See_T;
   begin
      Lay_Path ((22.0, 26.0, Ground_M), (42.0, 46.0, Ground_M), Laid);
      Build_Paths_Now;
      Zone_Housing (22.0 - 0.7, 26.0 + 0.7, 42.0, 46.0, Lots);
      Run (2);
      if House_Count >= 1 and then House_At (1).Turn /= 0.0 then
         declare
            V    : constant House_View := House_At (1);
            Mid  : constant Vec3 := (V.Corner (1) + V.Corner (3)) * 0.5;
            Dm   : constant Vec3 := (V.Drawn (1) + V.Drawn (3)) * 0.5;
            Off  : Vec3 := V.Drawn (1);      --  a point it is drawn on, off where it stands
            Bare : Vec3 := V.Corner (1);     --  and one where it stands, off where it is drawn
            T    : Thing;
            function Flat (A, C : Vec3) return Float is (Sqrt ((A.X - C.X) ** 2 + (A.Y - C.Y) ** 2));
         begin
            for C of V.Drawn loop
               if Flat (C, Mid) > Flat (Off, Mid) then
                  Off := C;
               end if;
            end loop;
            for C of V.Corner loop
               if Flat (C, Dm) > Flat (Bare, Dm) then
                  Bare := C;
               end if;
            end loop;
            Off := Off + (Dm - Off) * (1.0 / Flat (Dm, Off));
            Bare := Bare + (Mid - Bare) * (1.0 / Flat (Mid, Bare));
            T := See_T (Off + (0.3, 0.2, 12.0), Off);
            Check (T.Kind = A_House and then T.Index = 1,
                   "begun: pointing at the ground it is drawn on, off where it stands: the house (" & Said (T) & ")");
            T := See_T (Bare + (0.3, 0.2, 12.0), Bare);
            Check (T.Kind = A_Zone, "and at the ground it stands on, off where it is drawn: the zone (" & Said (T) & ")");
            Build_Homes_Now;
            T := See_T (Off + (0.3, 0.2, 14.0), Off + (0.0, 0.0, 1.0));
            Check (T.Kind = A_House and then T.Index = 1 and then T.Point.Z > Ground_M + 1.5,
                   "built: pointing down at it where it is drawn, off where it stands: the house, on its thatch ("
                   & Said (T) & ", " & Img (T.Point.Z - Ground_M, 2) & " m up)");
            T := See_T (Bare + (0.3, 0.2, 14.0), Bare + (0.0, 0.0, 1.0));
            Check (T.Kind = A_Zone and then abs (T.Point.Z - Ground_M) < 0.3,
                   "and down at where it stands, off where it is drawn: the zone's ground, not the house and not a"
                   & " block of it (" & Said (T) & ")");
            T := See (Bare + (0.3, 0.2, 14.0), Bare + (0.0, 0.0, 1.0));
            Check (T.Kind = A_House and then T.Index = 1,
                   "(asked without the caster, a house is pointed at where it stands, as before: " & Said (T) & ")");
            --  its roof is cleared by where it is drawn (Castle.Cutaway, given its turn)
            declare
               use Castle.Cutaway;
               R : constant Roof := Of_Corners (1, V.Corner (1), V.Corner (2), V.Corner (3), V.Corner (4), V.Top_Z,
                                                Pivot => V.Pivot, Radians => V.Turn);
               N_On, N_Off : Natural;
            begin
               Set_View (Dynamic);
               Clear;
               Follow (Off + (0.3, 0.2, 14.0), Off, [R], 1.0);
               N_On := Castle.Cutaway.Count;
               Clear;
               Follow (Bare + (0.3, 0.2, 14.0), Bare, [R], 1.0);
               N_Off := Castle.Cutaway.Count;
               Check (N_On = 1 and then N_Off = 0,
                      "the eye's line down through it where it is drawn clears its roof; down through where it stands,"
                      & " off where it is drawn, clears none (" & Img (N_On) & ", " & Img (N_Off) & ")");
               Clear;
               Follow (Off + (0.3, 0.2, 14.0), Off, [R], 1.0);
               T := See_T (Off + (0.3, 0.2, 14.0), Off + (0.0, 0.0, 1.0));
               Check (T.Kind = A_House and then T.Index = 1 and then T.Point.Z < Ground_M + 0.5,
                      "and with its roof cleared the pointer goes through to its floor as drawn: still the house ("
                      & Said (T) & ", " & Img (T.Point.Z - Ground_M, 2) & " m up)");
               Clear;
            end;
            --  never a person behind its walls as drawn: from past the house, level, at somebody
            --  who stands on its other side
            declare
               Wm  : constant Vec3 := Where (1);
               Dir : constant Vec3 := (Dm - Wm) * (1.0 / Flat (Dm, Wm));
               Eye : constant Vec3 := (Dm.X + Dir.X * 5.5, Dm.Y + Dir.Y * 5.5, Ground_M + 1.4);
            begin
               T := See_T (Eye, Wm + (0.0, 0.0, 1.2));
               Check (T.Kind = A_House,
                      "from past it, level, at somebody who stands on its other side (" & Img (Flat (Eye, Wm), 1)
                      & " m off): a house as it is drawn, not the person behind it (" & Said (T) & ")");
               T := See_T (Wm + (-3.0, -4.0, 9.0), Wm + (0.0, 0.0, 1.0));
               Check (T.Kind = A_Person and then T.Index = 1, "(and that one, looked at with nothing between: " & Said (T) & ")");
            end;
            --  from the path at its front as drawn
            declare
               Out_V : constant Vec3 := (V.Drawn_Door - Dm) * (1.0 / Flat (V.Drawn_Door, Dm));
            begin
               T := See_T (V.Drawn_Door + Out_V * 4.0 + (0.0, 0.0, 1.5), Dm + (0.0, 0.0, 1.2));
               Check (T.Kind = A_House and then T.Index = 1,
                      "and from the path at its front wall as drawn: the house (" & Said (T) & ")");
            end;
         end;
      else
         Check (False, "a hovel is begun turned beside a path at 45 degrees");
      end if;
   end;

   --  A storehouse drawn turned on a stockyard laid out along its path (John, 2026-11-20: "go on with
   --  the second way for the stockyard"): pointed at where it is drawn; and, the feet going by it as it
   --  is drawn, whoever is in it is pointed at where they are.
   Put_Line ("a storehouse drawn turned, walked where it is drawn:");
   Reset;
   Set_Storehouse (True);
   Set_Needs (False);
   Set_Demand_Chain (False);
   Meadow;
   Hours := 16.0 * 24.0;
   Place_Stake ((4.0, 4.0, Ground_M), 6, 42);
   declare
      C45 : constant Float := 0.707_106_78;
      function See_T (Eye, At_P : Vec3) return Thing is
         Dir : constant Vec3 := Normalize (At_P - Eye);
      begin
         return Look (Eye, Dir, Cast (Eye, Dir, 200.0), Cast => Cast'Access);
      end See_T;
      function Flat (A, C : Vec3) return Float is (Sqrt ((A.X - C.X) ** 2 + (A.Y - C.Y) ** 2));
      --  (a path north-east through (32, 30), and a lot of 16 m by 16 m along it on its north-west side)
      A_P   : constant Float := (32.0 + 30.0) * C45;
      B_P   : constant Float := (30.0 - 32.0) * C45;
      Front : constant Float := Float'Ceiling (B_P + 0.5 - 0.001);
      From  : constant Float := Float'Rounding (A_P) - 8.0;
      A0    : constant Float := From + 0.3;
      A1    : constant Float := From + 15.7;
      B0    : constant Float := Front + 0.3;
      B1    : constant Float := Front + 15.7;
      Zoned : Natural;
   begin
      Lay_Path ((32.0 - 18.0 * C45, 30.0 - 18.0 * C45, Ground_M), (32.0 + 18.0 * C45, 30.0 + 18.0 * C45, Ground_M), Laid);
      Build_Paths_Now;
      Run (1);
      Hours := 17.0 * 24.0 + 8.0;
      Run (1);
      Zone_Stockyard ((A0 - B0) * C45, (A0 + B0) * C45, (A1 - B1) * C45, (A1 + B1) * C45, Zoned);
      if Zoned = 256 and then Storehouse > 0 and then House_At (Storehouse).Yard_Turned then
         Build_Homes_Now;
         Run (2);
         declare
            S    : constant Positive := Storehouse;
            V    : constant House_View := House_At (S);
            Mid  : constant Vec3 := (V.Corner (1) + V.Corner (3)) * 0.5;
            Dm   : constant Vec3 := (V.Drawn (1) + V.Drawn (3)) * 0.5;
            Off  : Vec3 := V.Drawn (1);      --  a point it is drawn on, off where it stands
            Bare : Vec3 := V.Corner (1);     --  and one where it stands, off where it is drawn
            Inside : Vec3 := (0.0, 0.0, -1.0);
            T    : Thing;
         begin
            for C of V.Drawn loop
               if Flat (C, Mid) > Flat (Off, Mid) then
                  Off := C;
               end if;
            end loop;
            --  (it is turned about its middle: a corner of it as it stands that is well off it as drawn)
            for C of V.Corner loop
               declare
                  P : constant Vec3 := C + (Mid - C) * (0.8 / Flat (Mid, C));
               begin
                  if not House_Drawn_On (S, P.X, P.Y, 0.8) and then House_Walls_On (S, P.X, P.Y) then
                     Bare := P;
                  end if;
               end;
            end loop;
            Off := Off + (Dm - Off) * (1.2 / Flat (Dm, Off));
            for K in 1 .. Cell_Count loop
               if Zone_Of_Cell (K) = Stockyard and then Cell_At (K).Fit = Floor and then Inside.Z < 0.0 then
                  Inside := Cell_At (K).Centre;
               end if;
            end loop;
            Check (V.Walked_Drawn and then not V.People_Turned and then Inside.Z >= 0.0
                   and then House_Place (S, Inside.X, Inside.Y) = Within_It
                   and then House_Place (S, Bare.X, Bare.Y) = Where_Its_Blocks_Stand
                   and then House_Place (S, Off.X, Off.Y) = Within_It and then not House_Walls_On (S, Off.X, Off.Y),
                   "built on a stockyard along a path at 45 degrees: the feet go by it as it is drawn, and its places"
                   & " inside are within it as drawn");
            T := See_T (Off + (0.3, 0.2, 14.0), Off + (0.0, 0.0, 1.0));
            Check (T.Kind = A_House and then T.Index = S and then T.Point.Z > Ground_M + 1.5,
                   "pointing down at it where it is drawn, off where it stands: the storehouse, on its thatch ("
                   & Said (T) & ", " & Img (T.Point.Z - Ground_M, 2) & " m up)");
            T := See_T (Bare + (0.3, 0.2, 14.0), Bare + (0.0, 0.0, 1.0));
            Check (T.Kind = A_Zone and then abs (T.Point.Z - Ground_M) < 0.3,
                   "and down at where its blocks stand, off where it is drawn: the yard's ground, not the storehouse and"
                   & " not a block of it (" & Said (T) & ")");
            --  in at a doorway of it as it stands (nothing is seen there: the yard), to the ground within
            --  its walls as they stand: not the cursor's to dig or build on, the feet going by it as drawn
            declare
               Dw  : constant Doorway_View := Doorway_At (S, 1);
               Md  : constant Vec3 := Dw.Foot + Dw.Along * (Dw.Width / 2.0);
               Eye : constant Vec3 := Md - Dw.Inward * 3.0 + (0.0, 0.0, 1.5);
            begin
               --  (half a metre in from its doorway as it stands: off it as it is drawn)
               T := See_T (Eye, Md + Dw.Inward * 0.5);
               Check (not House_Drawn_On (S, Md.X + Dw.Inward.X * 0.5, Md.Y + Dw.Inward.Y * 0.5, 0.25)
                      and then T.Turned and then T.Kind /= A_House and then abs (T.Point.Z - Ground_M) < 0.3,
                      "in at a doorway of it as it stands, to the ground within its walls as they stand: the yard's"
                      & " ground, and not the cursor's to dig (" & Said (T) & ")");
            end;
            --  somebody standing where its blocks stand, off where it is drawn, is in the open: pointed at
            Hold_Still (3, (Bare.X, Bare.Y, Ground_M), 600.0);
            T := See_T (Bare + (0.3, 0.2, 10.0), Bare + (0.0, 0.0, 1.0));
            Check (T.Kind = A_Person and then T.Index = 3,
                   "somebody standing where its blocks stand, off where it is drawn, is pointed at: nothing is seen"
                   & " between (" & Said (T) & ")");
            Hold_Still (3, (2.0, 2.0, Ground_M), 600.0);
            --  somebody inside it as drawn: not through its roof; with its roof cleared, pointed at where they stand
            Hold_Still (1, Inside, 600.0);
            T := See_T (Inside + (0.3, 0.2, 14.0), Inside + (0.0, 0.0, 1.0));
            Check (T.Kind = A_House and then T.Index = S,
                   "somebody inside it: pointing down at them through its roof says the storehouse (" & Said (T) & ")");
            declare
               use Castle.Cutaway;
               R : constant Roof := Of_Corners (S, V.Corner (1), V.Corner (2), V.Corner (3), V.Corner (4), V.Top_Z,
                                                Pivot => V.Pivot, Radians => V.Turn);
               N_On : Natural;
            begin
               Set_View (Dynamic);
               Clear;
               Follow (Inside + (0.3, 0.2, 14.0), Inside, [R], 1.0);
               N_On := Castle.Cutaway.Count;
               T := See_T (Inside + (0.3, 0.2, 14.0), Inside + (0.0, 0.0, 1.0));
               Check (N_On = 1 and then T.Kind = A_Person and then T.Index = 1,
                      "with its roof cleared by the eye's line down through it as drawn, the one inside is pointed at where"
                      & " they stand (" & Said (T) & ")");
               Clear;
            end;
            --  never a person behind it as drawn: from the yard behind it, level, at somebody before its front
            declare
               Out_V : constant Vec3 := (V.Drawn_Door - Dm) * (1.0 / Flat (V.Drawn_Door, Dm));
               Wm    : constant Vec3 := (Dm.X + Out_V.X * 5.0, Dm.Y + Out_V.Y * 5.0, Ground_M);
               Eye   : constant Vec3 := (Dm.X - Out_V.X * 5.5, Dm.Y - Out_V.Y * 5.5, Ground_M + 1.4);
            begin
               Hold_Still (2, Wm, 600.0);
               T := See_T (Eye, Wm + (0.0, 0.0, 1.2));
               Check (T.Kind = A_House and then T.Index = S,
                      "from the yard behind it, level, at somebody who stands before its front (" & Img (Flat (Eye, Wm), 1)
                      & " m off): the storehouse as it is drawn, not the person behind it (" & Said (T) & ")");
               T := See_T (Wm + (Out_V.X * 4.0, Out_V.Y * 4.0, 7.0), Wm + (0.0, 0.0, 1.0));
               Check (T.Kind = A_Person and then T.Index = 2, "(and that one, looked at with nothing between: " & Said (T) & ")");
            end;
         end;
      else
         Check (False, "a stockyard along a path at 45 degrees takes its storehouse (" & Img (Zoned) & " places)");
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
