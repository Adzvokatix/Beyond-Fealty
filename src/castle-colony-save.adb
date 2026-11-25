separate (Castle.Colony)
function Save return Bytes is
   Buf  : Bytes_Access := new Bytes (0 .. 65_535);
   Size : Natural := 0;

   procedure Put (V : Unsigned_64; Count : Positive) is
   begin
      if Size + Count > Buf'Length then
         declare
            Bigger : constant Bytes_Access := new Bytes (0 .. 2 * Buf'Length - 1);
         begin
            Bigger (0 .. Size - 1) := Buf (0 .. Size - 1);
            Free (Buf);
            Buf := Bigger;
         end;
      end if;
      for K in 0 .. Count - 1 loop
         Buf (Size) := Unsigned_8 (Shift_Right (V, 8 * K) and 255);
         Size := Size + 1;
      end loop;
   end Put;
   procedure Put_F (V : Float) is
   begin
      Put (Unsigned_64 (F32_Bits (V)), 4);
   end Put_F;
   procedure Put_V (V : Vec3) is
   begin
      Put_F (V.X);
      Put_F (V.Y);
      Put_F (V.Z);
   end Put_V;
   procedure Put_B (V : Boolean) is
   begin
      Put ((if V then 1 else 0), 1);
   end Put_B;
begin
   Put (Save_Version, 2);
   Put (Unsigned_64 (Tick_N), 4);
   Put_F (Left_Over);
   Put (F64_Bits (Now_Hours), 8);
   Put_B (Stake_Set);
   Put_V (Stake_At);
   Put (Band_Seed, 8);
   Put (Unsigned_64 (N_Paths), 2);
   for K in 1 .. N_Paths loop
      Put_V (Path_List (K).A);
      Put_V (Path_List (K).B);
   end loop;
   Put (Unsigned_64 (N_Cells), 2);
   for K in 1 .. N_Cells loop
      Put_V (Cells (K).Centre);
      Put (Unsigned_64 (Item_Kind'Pos (Cells (K).Kind)), 1);
      Put (Unsigned_64 (Cells (K).Count), 4);
   end loop;
   declare
      N : Natural := 0;
   begin
      for X in Indexed'Range (1) loop
         for Y in Indexed'Range (2) loop
            if Indexed (X, Y) then
               N := N + 1;
            end if;
         end loop;
      end loop;
      Put (Unsigned_64 (N), 4);
      for X in Indexed'Range (1) loop
         for Y in Indexed'Range (2) loop
            if Indexed (X, Y) then
               Put (Unsigned_64 (X), 2);
               Put (Unsigned_64 (Y), 2);
            end if;
         end loop;
      end loop;
   end;
   Put (Unsigned_64 (N_Bushes), 4);
   for K in 1 .. N_Bushes loop
      declare
         Bu : Bush renames Bushes (K);
      begin
         Put_V (Bu.Centre);
         Put_F (Bu.Radius);
         Put (Unsigned_64 (Bu.N), 2);
         for J in 1 .. Bu.N loop
            Put (Unsigned_64 (Bu.Blocks (J).X), 2);   --  block rows and columns: never negative
            Put (Unsigned_64 (Bu.Blocks (J).Y), 2);
            Put (Unsigned_64 (Bu.Blocks (J).Z), 2);
         end loop;
         Put (Unsigned_64 (Bu.Ripe), 2);
         Put (F64_Bits (Bu.Regrow_At), 8);
      end;
   end loop;
   Put (Unsigned_64 (N_Members), 1);
   for I in 1 .. N_Members loop
      declare
         M : Member renames Band (I);
      begin
         Put (M.Seed, 8);
         Put_B (M.Child);
         Put_B (M.Elder);
         Put (Unsigned_64 (M.Name), 1);
         Put (Unsigned_64 (Job_Kind'Pos (M.Job)), 1);
         Put_V (M.Pos);
         Put (Unsigned_64 (Task_State'Pos (M.State)), 1);
         Put (Unsigned_64 (Why_Idle'Pos (M.Why)), 1);
         Put (Unsigned_64 (M.Bush), 4);
         Put (Unsigned_64 (M.Cell), 4);
         Put_V (M.Goal);
         Put (Unsigned_64 (Item_Kind'Pos (M.Carry)), 1);
         Put (Unsigned_64 (M.Carried), 2);
         Put_F (M.Work);
         Put_F (M.Wait);
         Put_F (M.Speed);
         Put_V (M.Spot);
         Put (Unsigned_64 (M.Thoughts), 4);
         Put (Unsigned_64 (M.Check_Tick), 4);
         for F of M.Fails loop
            Put (Unsigned_64 (F.Bush), 4);
            Put (Unsigned_64 (F.Until_Tick), 4);
         end loop;
         --  the way it is going, so a save resumes exactly where it was
         Put (Unsigned_64 (Castle.Nav.Outcome'Pos (M.Route.Result)), 1);
         Put (Unsigned_64 (M.Route.N), 2);
         for K in 1 .. M.Route.N loop
            Put_V (M.Route.Pts (K).P);
            Put_F (M.Route.Pts (K).T);
            Put_F (M.Route.Pts (K).D);
         end loop;
         Put (Unsigned_64 (M.Route.N_Stamps), 1);
         for K in 1 .. M.Route.N_Stamps loop
            Put (Unsigned_64 (Integer (M.Route.Stamps (K).CX)), 2);
            Put (Unsigned_64 (Integer (M.Route.Stamps (K).CY)), 2);
         end loop;
         Put_B (M.Route.Overflow);
         Put (Unsigned_64 (M.Leg), 2);
         Put_F (M.Along);
         Put_F (M.Pace);
      end;
   end loop;
   --  version 2
   for I in 1 .. N_Members loop
      Put (Unsigned_64 (Band (I).Tree), 2);
      Put (Unsigned_64 (Band (I).Pile), 2);
   end loop;
   Put_B (Apples_Safe);
   Put (Unsigned_64 (Reserves (Wood)), 4);
   Put (Unsigned_64 (N_Felled), 4);
   Put (Unsigned_64 (N_Trees), 2);
   for K in 1 .. N_Trees loop
      declare
         T : Tree_Rec renames Trees (K);
      begin
         Put (Unsigned_64 (T.I), 2);
         Put (Unsigned_64 (T.J), 2);
         Put (Unsigned_64 (Tree_Kind'Pos (T.Info.Kind)), 1);
         Put (Unsigned_64 (T.Info.Bx), 2);
         Put (Unsigned_64 (T.Info.By), 2);
         Put (Unsigned_64 (T.Info.Bz), 2);
         Put (Unsigned_64 (T.Info.Trunk_W), 1);
         Put (Unsigned_64 (T.Info.Trunk_H), 1);
         Put_B (T.Down);
      end;
   end loop;
   Put (Unsigned_64 (N_Piles), 2);
   for K in 1 .. N_Piles loop
      Put_V (Piles (K).Centre);
      Put_F (Piles (K).Turn);
      Put (Unsigned_64 (Piles (K).Count), 1);
   end loop;
   --  version 3
   for I in 1 .. N_Members loop
      Put (Unsigned_64 (Item_Kind'Pos (Band (I).Fetch)), 1);
      Put (Unsigned_64 (Band (I).Tgt.X), 2);
      Put (Unsigned_64 (Band (I).Tgt.Y), 2);
      Put (Unsigned_64 (Band (I).Tgt.Z), 2);
   end loop;
   for K of V3_Kinds loop
      Put (Unsigned_64 (Reserves (K)), 2);
   end loop;
   Put_B (Trees_Pending);
   for X in Indexed'Range (1) loop
      for Y in Indexed'Range (2) loop
         if Indexed (X, Y) then
            Put (Unsigned_64 (Sources (X, Y)), 1);
         end if;
      end loop;
   end loop;
   --  version 4
   for K in 1 .. N_Piles loop
      Put (Unsigned_64 (Piles (K).Owner), 1);
   end loop;
   for K in V4_Kinds loop
      Put (Unsigned_64 (Demand (K)), 2);
   end loop;
   --  version 5
   declare
      H : constant Castle.Herds.Bytes := Castle.Herds.Save;
   begin
      Put (Unsigned_64 (H'Length), 4);
      for K in H'Range loop
         Put (Unsigned_64 (H (K)), 1);
      end loop;
   end;
   --  version 6
   for I in 1 .. N_Members loop
      Put (Unsigned_64 (Band (I).Prey), 2);
      Put (Unsigned_64 (Band (I).Prize), 1);
      Put (Unsigned_64 (Band (I).Cell2), 2);
   end loop;
   Put (Unsigned_64 (Reserves (Meat)), 2);
   Put_B (Deer_Safe);
   Put (Unsigned_64 (N_Kills), 4);
   Put (Unsigned_64 (N_Shots), 4);
   Put (Unsigned_64 (N_Carcasses), 1);
   for K in 1 .. N_Carcasses loop
      declare
         C : Carcass_Rec renames Carcasses (K);
      begin
         Put_B (C.Used);
         Put_V (C.Centre);
         Put_F (C.Turn);
         Put (Unsigned_64 (Castle.Deer.Class'Pos (C.Class)), 1);
         Put_B (C.Lying);
         Put (Unsigned_64 (C.Holder), 1);
         Put (Unsigned_64 (C.Owner), 1);
      end;
   end loop;
   --  version 7
   Put_B (Needs_On);
   Put (Unsigned_64 (N_Eaten), 4);
   for I in 1 .. N_Members loop
      Put_F (Band (I).Fed);
      Put (Unsigned_64 (Band (I).Ration), 2);
   end loop;
   --  version 8
   for K in V8_Kinds loop
      Put (Unsigned_64 (Demand (K)), 2);
      Put (Unsigned_64 (Reserves (K)), 2);
   end loop;
   Put_B (Camp_Set);
   Put_V (Camp_At);
   Put (Unsigned_64 (Seats_Laid), 1);
   Put (Unsigned_64 (Fire_Logs), 2);
   Put_F (Fuel_H);
   Put (Unsigned_64 (Pot_Stew), 4);
   Put (Unsigned_64 (Pot_Raw), 4);
   Put (Unsigned_64 (Pot_Meat), 4);
   Put_B (Cook_Chosen);
   Put (Unsigned_64 (N_Cooked), 4);
   Put (Unsigned_64 (N_Burnt), 4);
   for K in To_V8_Kinds loop
      Put (Unsigned_64 (In_Pot_N (K)), 4);
      Put (Unsigned_64 (Raw_Eaten_N (K)), 4);
   end loop;
   Put (Unsigned_64 (N_Pulled_All), 4);
   Put (Unsigned_64 (N_Pulled), 2);
   for K in 1 .. N_Pulled loop
      Put (Unsigned_64 (Pulled (K).P.X), 2);
      Put (Unsigned_64 (Pulled (K).P.Y), 2);
      Put (Unsigned_64 (Pulled (K).P.Z), 2);
      Put (F64_Bits (Pulled (K).At_H), 8);
   end loop;
   for K in 1 .. N_Trees loop
      Put (Unsigned_64 (Trees (K).Apples), 2);
      Put (Unsigned_64 (Trees (K).Apple_Year + 1), 2);
   end loop;
   for I in 1 .. N_Members loop
      declare
         M : Member renames Band (I);
      begin
         Put_B (M.From_Pot);
         Put (Unsigned_64 (M.Seat), 1);
         Put_B (M.Had_Stew);
         Put (Unsigned_64 (M.Due), 2);
         Put (Unsigned_64 (Camp_Use'Pos (M.Use_For)), 1);
         Put_B (M.Fends);
         Put_F (M.Mood);
         Put_F (M.Empty_H);
         Put_B (M.Is_Dead);
      end;
   end loop;
   Put (Unsigned_64 (N_Deaths), 1);
   --  version 9
   for K in V9_Kinds loop
      Put (Unsigned_64 (Demand (K)), 2);
      Put (Unsigned_64 (Reserves (K)), 2);
      Put (Unsigned_64 (In_Pot_N (K)), 4);
      Put (Unsigned_64 (Raw_Eaten_N (K)), 4);
   end loop;
   for I in 1 .. N_Members loop
      Put (Unsigned_64 (Band (I).Grain), 2);
   end loop;
   Put (Unsigned_64 (Store_Days), 1);   --  version 10
   --  version 11: the zones, the zone of each stockpile cell, each member's director
   Put (Unsigned_64 (N_Zones), 2);
   for Z in 1 .. N_Zones loop
      Put (Unsigned_64 (Zone_Kind'Pos (Zones (Z).Kind)), 1);
      Put_V (Zones (Z).Lo);
      Put_V (Zones (Z).Hi);
      Put (Unsigned_64 (Zones (Z).Cells), 2);
   end loop;
   for K in 1 .. N_Cells loop
      Put (Unsigned_64 (Cells (K).Zone), 2);
   end loop;
   Put (Unsigned_64 (Camp_Zone_N), 2);
   for I in 1 .. N_Members loop
      Put (Unsigned_64 (Band (I).Director + 1), 1);   --  0: the player; 1: no one; then the members
   end loop;
   --  version 12: skills.  How many there are is stored, so a blob written
   --  before a skill was added still loads.
   Put_B (Skills_On);
   Put (Skill_Kind'Pos (Skill_Kind'Last) + 1, 1);
   for I in 1 .. N_Members loop
      for S in Skill_Kind loop
         Put (F64_Bits (Band (I).Skill (S)), 8);
      end loop;
   end loop;
   --  version 13: the demand chain: on or off, and whether each good is
   --  being asked for (food, then each kind; how many kinds is stored, so a
   --  blob written before a kind was added still loads)
   Put_B (Chain_On);
   Put_B (Food_Asking);
   Put (Item_Kind'Pos (Item_Kind'Last) + 1, 1);
   for K in Item_Kind loop
      Put_B (Asking (K));
   end loop;
   --  version 14: each zone's ground (the way its lot lies, and its strips
   --  of block columns); whether the camp takes labour, and the fire's dying down
   for Z in 1 .. N_Zones loop
      Put_F (Zones (Z).Turn);
      Put (Unsigned_64 (Zones (Z).N), 4);
      for K in Zones (Z).First + 1 .. Zones (Z).First + Zones (Z).N loop
         Put (Unsigned_64 (Unsigned_16'Mod (Integer (Runs (K).Y))), 2);
         Put (Unsigned_64 (Unsigned_16'Mod (Integer (Runs (K).X0))), 2);
         Put (Unsigned_64 (Unsigned_16'Mod (Integer (Runs (K).X1))), 2);
         Put (Unsigned_64 (Unsigned_16'Mod (Integer (Runs (K).Z))), 2);
      end loop;
   end loop;
   Put_B (Labour_On);
   Put_F (Ember_H);
   --  and what is built on each zone: whether it stands and what has been
   --  delivered for it (how many kinds is stored); the patch of the camp's
   --  ground each member is at
   for Z in 1 .. N_Zones loop
      Put_B (Zones (Z).Built);
      Put (Item_Kind'Pos (Item_Kind'Last) + 1, 1);
      for K in Item_Kind loop
         Put (Unsigned_64 (Zones (Z).Got (K)), 2);
      end loop;
   end loop;
   for I in 1 .. N_Members loop
      Put (Unsigned_64 (Band (I).Patch), 2);
   end loop;
   --  version 15: how far the band is looking for what the camp's building
   --  takes; the stretch of path, and the metre of it, each member is at
   Put_F (Far_Reach);
   Put_F (Stone_From);
   for I in 1 .. N_Members loop
      Put (Unsigned_64 (Band (I).Site_Seg), 2);
      Put (Unsigned_64 (Band (I).Site_M), 1);
   end loop;
   --  version 16: how many hands extra tasks may take, as set (0: by the
   --  rule); whether a path is laid a stretch to a serf, and the metres each
   --  member has laid since it was given one
   Put (Unsigned_64 (Hands_Set), 1);
   Put_B (Stretches_On);
   for I in 1 .. N_Members loop
      Put (Unsigned_64 (Band (I).Site_Laid), 1);
   end loop;
   --  and whether a camp's floor is levelled, and the level of this one's (-1: left as it lies)
   Put_B (Level_On);
   Put (Unsigned_64 (Unsigned_16'Mod (Camp_Level)), 2);
   Put (Unsigned_64 (Sod_Bits), 2);
   Put (Unsigned_64 (Cut_Left_N), 2);          --  (as last counted: who does what goes by them)
   Put (Unsigned_64 (Fill_Left_N), 2);
   --  and what is asked and kept of the kinds added since
   for K in V16_Kinds loop
      Put (Unsigned_64 (Demand (K)), 2);
      Put (Unsigned_64 (Reserves (K)), 2);
   end loop;
   --  version 20: housing.  The houses (each one's zone, seed, place, the
   --  way it faces, its pad's level, its door's way to the path, whose it is, how far it is built, what
   --  has been carried to it and what of that is not yet laid: its size and
   --  openings are its seed's, and what it takes is counted from its
   --  blueprint), and the house and patch of ground each builder is at
   Put (Unsigned_64 (House_Serial), 2);
   Put (Unsigned_64 (N_Houses), 1);
   for H in 1 .. N_Houses loop
      declare
         Hs : House_Rec renames Houses (H);
      begin
         Put (Unsigned_64 (Hs.Zone), 2);
         Put (Hs.Seed, 8);
         --  (26: what it is; a storehouse's yard)
         Put (Unsigned_64 (Castle.Buildings.Building_Kind'Pos (Hs.F.Kind)), 1);
         if Hs.F.Kind = Castle.Buildings.Storehouse then
            Put (Unsigned_64 (Hs.F.W), 1);          --  (44: its walls, as it was begun)
            Put (Unsigned_64 (Hs.F.D), 1);
            Put (Unsigned_64 (Unsigned_16'Mod (Hs.F.Yard_U0)), 2);
            Put (Unsigned_64 (Unsigned_16'Mod (Hs.F.Yard_U1)), 2);
            Put (Unsigned_64 (Unsigned_16'Mod (Hs.F.Yard_V0)), 2);
            Put (Unsigned_64 (Unsigned_16'Mod (Hs.F.Yard_V1)), 2);
            Put (Unsigned_64 (Unsigned_16'Mod (Hs.F.Gate_U)), 2);
            Put (Unsigned_64 (Hs.F.Covers), 1);
            for K in 1 .. Hs.F.Covers loop
               Put (Unsigned_64 (Unsigned_16'Mod (Hs.F.Cover_U (K))), 2);
            end loop;
         end if;
         Put (Unsigned_64 (Unsigned_16'Mod (Hs.F.Fx)), 2);
         Put (Unsigned_64 (Unsigned_16'Mod (Hs.F.Fy)), 2);
         Put ((if Hs.F.Vx > 0 then 0 elsif Hs.F.Vx < 0 then 1 elsif Hs.F.Vy > 0 then 2 else 3), 1);
         Put (Unsigned_64 (Unsigned_16'Mod (Hs.F.Pad)), 2);
         Put (Unsigned_64 (Hs.F.Door_Run), 1);
         Put (Unsigned_64 (Unsigned_16'Mod (Hs.F.Door_Row)), 2);
         for U in Hs.F.Front'Range loop           --  (its front yard, as it was placed)
            Put (Unsigned_64 (Hs.F.Front (U)), 1);
         end loop;
         Put (Unsigned_64 (Hs.F.Reach_L), 1);       --  (and how far its ground reaches to a neighbour's)
         Put (Unsigned_64 (Hs.F.Reach_R), 1);
         Put_B (Hs.F.Truss);                        --  (31: how it was begun)
         Put_B (Hs.F.Sill);
         Put_B (Hs.Raze);                           --  (and whether it is marked for razing)
         Put_B (Hs.F.Jambs);                        --  (32: plank beside its windows, a hovel's ridge beam)
         Put_B (Hs.F.Ridge);
         --  (36: the eighth of a turn it is drawn by, and 1; 37: and 4 if its ground is made where it is drawn)
         --  (40: and 8 if it is walked where it is drawn)
         Put (Unsigned_64 (Hs.F.Turn + 1 + (if Hs.F.Turn_Ground then 4 else 0) + (if Hs.F.Walk then 8 else 0)), 1);
         if Is_Store (Hs.F) then                    --  (39: what a storehouse drawn turned is turned about)
            Put_F (Hs.F.Piv_U);
            Put_F (Hs.F.Piv_V);
            --  (41: 1 if its coverings' roofs are smoothed, and 2 if its fence is laid in pieces)
            --  (and, with no new version: 4 if its stockyard's way in is at the low end of its front, 8 if
            --  at the high end, in a corner of the zone.  A build of before reads neither: it had no such
            --  way, and says the blob is bad.)
            Put (Unsigned_64 ((if Hs.F.Smooth_Covers then 1 else 0) + (if Hs.F.Fence_Pieces then 2 else 0)
                              + 4 * Hs.F.Way_End), 1);
         end if;
         Put (Unsigned_64 (Hs.Got (Stone)), 2);
         Put (Unsigned_64 (Hs.Lying (Stone)), 2);
         Put (Unsigned_64 (Hs.Stone_Left), 2);
         Put (Unsigned_64 (Hs.Owner), 1);
         Put_B (Hs.Bed);
         Put_B (Hs.Pad_Done);
         Put_B (Hs.Built);
         Put (Unsigned_64 (Hs.Placed), 2);
         Put (Unsigned_64 (Hs.Got (Wood)), 2);
         Put (Unsigned_64 (Hs.Got (Straw)), 2);
         Put (Unsigned_64 (Hs.Lying (Wood)), 2);
         Put (Unsigned_64 (Hs.Lying (Straw)), 2);
      end;
   end loop;
   for I in 1 .. N_Members loop
      Put (Unsigned_64 (Band (I).Site), 1);
      Put (Unsigned_64 (Band (I).Site_Patch), 2);
   end loop;
   --  beds: whether the band makes them, the straw in them all, and each
   --  member's own at the camp
   Put_F (Pace_Now);                     --  (and the band's pace)
   Put_B (Beds_On);
   Put (Unsigned_64 (Bed_Sheaves), 2);
   for I in 1 .. N_Members loop
      Put_B (Band (I).Bed);
      Put_V (Band (I).Bed_At);
      Put (Unsigned_64 (Band (I).Bed_Has), 1);
      Put_B (Band (I).Placed);
      Put_F (Band (I).Bed_Dir);
      Put (Unsigned_64 (Band (I).Bed_Lo + 1), 2);
      Put (Unsigned_64 (Band (I).Bed_Hi + 1), 2);
   end loop;
   --  the lots laid out for the houses still to begin (each one's house is
   --  the design of its serial's seed)
   Put (Unsigned_64 (N_Lots), 1);
   Put_B (Lots_Are_Short);
   for K in 1 .. N_Lots loop
      declare
         F : Castle.Buildings.House renames Lots (K).F;
      begin
         Put (Unsigned_64 (Lots (K).Zone), 2);
         Put (Unsigned_64 (Unsigned_16'Mod (F.Fx)), 2);
         Put (Unsigned_64 (Unsigned_16'Mod (F.Fy)), 2);
         Put ((if F.Vx > 0 then 0 elsif F.Vx < 0 then 1 elsif F.Vy > 0 then 2 else 3), 1);
         Put (Unsigned_64 (Unsigned_16'Mod (F.Pad)), 2);
         Put (Unsigned_64 (F.Door_Run), 1);
         Put (Unsigned_64 (Unsigned_16'Mod (F.Door_Row)), 2);
         for U in F.Front'Range loop
            Put (Unsigned_64 (F.Front (U)), 1);
         end loop;
         Put (Unsigned_64 (F.Turn + 1 + (if F.Turn_Ground then 4 else 0) + (if F.Walk then 8 else 0)), 1);      --  (37; 40)
      end;
   end loop;
   --  the pass's fourth round (23): whether the cook keeps a pot's fill;
   --  curing, the lord's cart and its salt, what salting has kept and lost;
   --  what is asked and kept of the kinds added with it
   Put_B (Hold_On);
   Put_B (Curing_On);
   Put_B (Cart_Set);
   Put_B (Cart_Tried);
   Put_V (Cart_P);
   Put_B (Cart_X);
   Put (Unsigned_64 (Cart_Salt_N), 2);
   Put (Unsigned_64 (N_Salted), 4);
   Put (Unsigned_64 (N_Unsalted), 4);
   Put (Unsigned_64 (N_Meat_Lost), 4);
   for K in V23_Kinds loop
      Put (Unsigned_64 (Demand (K)), 2);
      Put (Unsigned_64 (Reserves (K)), 2);
   end loop;
   --  ladders: whether roofs are thatched from them, those made and lost,
   --  the one standing at each house, the one each member is going for
   Put_B (Ladders_On);
   Put (Unsigned_64 (N_Ladders), 2);
   Put (Unsigned_64 (N_Ladders_Lost), 2);
   for H in 1 .. N_Houses loop
      Put (Unsigned_64 (Houses (H).Ladder), 1);
      Put_V (Houses (H).Ladder_P);
      Put (Unsigned_64 (Houses (H).Ladder_Fells), 1);
   end loop;
   for I in 1 .. N_Members loop
      Put (Unsigned_64 (Band (I).Ladder_Of), 1);
   end loop;
   --  the fifth round (24): whether a hole under a path is filled as it is laid
   Put_B (Holes_On);
   --  the lord's cart pulled into a stockpile (25): whether it is, the way it
   --  points, whether it is in tow and by whom, the place held for it, where
   --  it was lifted from
   Put_B (Pull_On);
   Put_F (Cart_Turn);
   Put_B (Cart_Towed);
   Put (Unsigned_64 (Cart_By), 1);
   Put_B (Cart_Bound);
   Put_V (Goal_P);
   Put_F (Goal_Turn);
   Put_V (Cart_From);
   --  the stockpile's first pass (26): how many may be builders at once
   Put (Unsigned_64 (Builders_Cap), 1);
   Put_F (Least_M);                     --  and how large a stockpile has to be,
   Put_B (Overflow_On);                 --  whether one gets overflow places, and which places they are
   for K in 1 .. N_Cells loop
      Put_B (Cells (K).Overflow);
   end loop;
   --  the storehouse: whether it is asked for, the stake's day, whether the
   --  request has been made, its house; the places closed for it
   Put_B (Store_On);
   Put (Unsigned_64 (Unsigned_16'Mod (Stake_Day)), 2);
   Put_B (Store_Asked);
   Put (Unsigned_64 (Store_House), 1);
   for K in 1 .. N_Cells loop
      Put_B (Cells (K).Closed);
   end loop;
   --  the storehouse used (28): each place's fitting and whether its shelf
   --  or barrel is made; whether a stockman and a carpenter are made, who,
   --  and whether water is brought in
   for K in 1 .. N_Cells loop
      Put (Unsigned_64 (Fitting'Pos (Cells (K).Fit)), 1);
      --  (2: a second barrel on the first; only of a barrel's place, as the loader reads it)
      Put ((if Cells (K).Second and then Cells (K).Fit in Meat_Barrel | Water_Barrel then 2
            elsif Cells (K).Made then 1 else 0), 1);
   end loop;
   Put_B (Keep_On);
   Put (Unsigned_64 (Keeper_N), 1);
   Put_B (Carp_On);
   Put (Unsigned_64 (Carp_N), 1);
   Put_B (Water_Is_On);
   Put (Unsigned_64 (Store_Built_By), 1);
   --  the playtest round of 2026-11-18 (29): the stores' last places kept, the
   --  one stockpile placed, long grass cut from the top, bushes shared
   Put (Unsigned_64 (Last_N), 2);
   Put_B (One_Pile_On);
   Put_B (Top_Cut_On);
   Put_B (Share_On);
   --  the stockyard (30): which zone is it, and whether its ground is levelled
   for Z in 1 .. N_Zones loop
      Put_B (Zones (Z).Yard);
   end loop;
   Put_B (Yard_Level_On);
   Put_B (Move_On);
   --  the next pass of his notes (31): whoever stands where a block goes steps aside, a path
   --  levelled as it is laid, and how a house begun from now on is made: its roof's timbers,
   --  its windows' timber (each house's own with the house, above)
   Put_B (Way_On);
   Put_B (Path_Level_On);
   Put_B (Truss_On);
   Put_B (Sill_On);
   --  his answers of 2026-11-19 (32): who is set to building, one a member
   for I in 1 .. N_Members loop
      Put_B (Band (I).Build_First);
   end loop;
   --  how far the foresters look for a tree (33), and whether they look further than the work radius
   Put_F (Wood_Reach);
   Put_B (Wood_Far_On);
   Put_F (Wood_From);                        --  (34)
   Put_F (Food_Reach);                       --  (35)
   Put_F (Haul_Reach);
   Put_B (Turn_On);                          --  (36: whether a hovel beside a path at 45 degrees is turned)
   Put_B (Turn_Ground_On);                   --  (37: and its ground made where it is drawn)
   Put_B (Keep_Off_On);                      --  (37: and that ground kept off by who walks)
   declare                                   --  (and the trees none could get to, each until when)
      N : Natural := 0;
   begin
      for K in 1 .. N_Trees loop
         if Trees (K).No_Way_Till > Tick_N then
            N := N + 1;
         end if;
      end loop;
      Put (Unsigned_64 (N), 2);
      for K in 1 .. N_Trees loop
         if Trees (K).No_Way_Till > Tick_N then
            Put (Unsigned_64 (K), 2);
            Put (Unsigned_64 (Trees (K).No_Way_Till), 4);
         end if;
      end loop;
   end;
   --  (38: whether the band is told of ways that are not there, and what it has been told)
   Put_B (Ways_Told_On);
   declare
      N : Natural := 0;
   begin
      for T of Told loop
         if T.Until_Tick > Tick_N then
            N := N + 1;
         end if;
      end loop;
      Put (Unsigned_64 (N), 2);
      for T of Told loop
         if T.Until_Tick > Tick_N then
            Put (Unsigned_64 (T.Id), 4);
            Put (Unsigned_64 (T.Until_Tick), 4);
         end if;
      end loop;
   end;
   Put_B (Yard_Turn_On);                     --  (39: whether a stockyard beside a path at 45 degrees is laid out along it)
   Put_B (Hovel_Walk_On);                    --  (40: whether a hovel placed turned is walked where it is drawn)
   Put_B (Smooth_Covers_On);                 --  (41: whether a storehouse begun from now on has its coverings'
   Put_B (Fence_Pieces_On);                  --  roofs smoothed, and its fence laid in pieces along a turned yard)
   Put_B (Box_On);                           --  (42: whether the player's stockpile is put down whole with its
   for Z in 1 .. N_Zones loop                --  path, and the frame of each zone that was)
      Put_B (Zones (Z).Placed);
      if Zones (Z).Placed then
         Put (Unsigned_64 (Unsigned_16'Mod (Zones (Z).Fx)), 2);
         Put (Unsigned_64 (Unsigned_16'Mod (Zones (Z).Fy)), 2);
         Put (Unsigned_64 (Zones (Z).Way), 1);
         --  (the square the colony was founded on, where it was founded with its walls outside its
         --  floor: that, and the rings kept outside its four sides, two bits a side, over the blocks
         --  of its frame, which are fewer than 128.  A square of before the rule, and every other
         --  zone, is saved as it always was, to the byte.)
         Put (Unsigned_64 (Zones (Z).Along_B
                           + (if Z = Camp_Zone_N and then Camp_Square and then Square_Outside
                              then 128 + 256 * (Square_Strip (1) + 4 * Square_Strip (2) + 16 * Square_Strip (3)
                                                + 64 * Square_Strip (4))
                              else 0)), 2);
      end if;
   end loop;
   Put_B (Camp_Square);                      --  (43: whether the colony was founded on a square)
   for Z in 1 .. N_Zones loop                --  (46: which stockpiles are ordered removed)
      Put_B (Zones (Z).Leaving);
   end loop;
   Put_B (Full_On);                          --  (45: whether a house begun from now on has the fuller truss,
   for H in 1 .. N_Houses loop               --  and which houses have)
      Put_B (Houses (H).F.Full);
   end loop;
   declare
      Result : constant Bytes := Buf (0 .. Size - 1);
   begin
      Free (Buf);
      return Result;
   end;
end Save;
