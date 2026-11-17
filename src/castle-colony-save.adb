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
   declare
      Result : constant Bytes := Buf (0 .. Size - 1);
   begin
      Free (Buf);
      return Result;
   end;
end Save;
