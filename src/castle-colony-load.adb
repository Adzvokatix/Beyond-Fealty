separate (Castle.Colony)
procedure Load (B : Bytes; Ok : out Boolean) is
   Pos : Natural := B'First;

   function Get (Count : Positive) return Unsigned_64 is
      V : Unsigned_64 := 0;
   begin
      if Pos + Count - 1 > B'Last then
         raise Bad_Save;
      end if;
      for K in 0 .. Count - 1 loop
         V := V or Shift_Left (Unsigned_64 (B (Pos + K)), 8 * K);
      end loop;
      Pos := Pos + Count;
      return V;
   end Get;
   function Get_F return Float is (Bits_F32 (Unsigned_32 (Get (4))));
   function Get_V return Vec3 is
      X : constant Float := Get_F;
      Y : constant Float := Get_F;
      Z : constant Float := Get_F;
   begin
      return (X, Y, Z);
   end Get_V;
   function Get_B return Boolean is (Get (1) /= 0);
   Version : Natural;
begin
   Reset;
   Ok := False;
   Version := Natural (Get (2));
   if Version not in 1 .. Save_Version or else Version in 18 .. 24 then
      return;                       --  (18, 19: housing before its ground was walled: not read)
   end if;
   Tick_N := Natural (Get (4));
   Left_Over := Get_F;
   Now_Hours := Bits_F64 (Get (8));
   Stake_Set := Get_B;
   Stake_At := Get_V;
   Band_Seed := Get (8);
   N_Paths := Natural (Get (2));
   for K in 1 .. N_Paths loop
      Path_List (K).A := Get_V;
      Path_List (K).B := Get_V;
   end loop;
   N_Cells := Natural (Get (2));
   for K in 1 .. N_Cells loop
      Cells (K).Centre := Get_V;
      Cells (K).Kind := Item_Kind'Val (Get (1));
      Cells (K).Count := Natural (Get (4));
      Cells (K).Incoming := 0;
      Cells (K).Outgoing := 0;
   end loop;
   for K in 1 .. Natural (Get (4)) loop
      declare
         X : constant Integer := Integer (Get (2));
         Y : constant Integer := Integer (Get (2));
      begin
         Indexed (X, Y) := True;
      end;
   end loop;
   N_Bushes := Natural (Get (4));
   for K in 1 .. N_Bushes loop
      declare
         Bu : Bush renames Bushes (K);
      begin
         Bu.Centre := Get_V;
         Bu.Radius := Get_F;
         Bu.N := Natural (Get (2));
         for J in 1 .. Bu.N loop
            Bu.Blocks (J).X := Integer_16 (Get (2));
            Bu.Blocks (J).Y := Integer_16 (Get (2));
            Bu.Blocks (J).Z := Integer_16 (Get (2));
         end loop;
         Bu.Ripe := Natural (Get (2));
         Bu.Regrow_At := Bits_F64 (Get (8));
         Bu.Reserved_By := 0;
         for J in 1 .. Bu.N loop
            Bush_Of.Include (Key_Of (Integer (Bu.Blocks (J).X), Integer (Bu.Blocks (J).Y),
                                     Integer (Bu.Blocks (J).Z)), K);
         end loop;
      end;
   end loop;
   N_Members := Natural (Get (1));
   for I in 1 .. N_Members loop
      declare
         M : Member renames Band (I);
      begin
         M := (others => <>);
         M.Seed := Get (8);
         M.Child := Get_B;
         M.Elder := Get_B;
         M.G := Castle.Bodies.Random_Genome (M.Seed, Child => M.Child, Elder => M.Elder);
         M.Name := Natural (Get (1));
         M.Job := Job_Kind'Val (Get (1));
         M.Pos := Get_V;
         M.Prev := M.Pos;
         M.State := Task_State'Val (Get (1));
         M.Why := Why_Idle'Val (Get (1));
         M.Bush := Natural (Get (4));
         M.Cell := Natural (Get (4));
         M.Goal := Get_V;
         M.Carry := Item_Kind'Val (Get (1));
         M.Carried := Natural (Get (2));
         M.Work := Get_F;
         M.Wait := Get_F;
         M.Speed := Get_F;
         M.Spot := Get_V;
         M.Thoughts := Natural (Get (4));
         M.Check_Tick := Natural (Get (4));
         for F of M.Fails loop
            F.Bush := Natural (Get (4));
            F.Until_Tick := Natural (Get (4));
         end loop;
         M.Route.Result := Castle.Nav.Outcome'Val (Get (1));
         M.Route.N := Natural (Get (2));
         for K in 1 .. M.Route.N loop
            M.Route.Pts (K).P := Get_V;
            M.Route.Pts (K).T := Get_F;
            M.Route.Pts (K).D := Get_F;
         end loop;
         M.Route.N_Stamps := Natural (Get (1));
         for K in 1 .. M.Route.N_Stamps loop
            --  the ground the route was planned on is not known after a load:
            --  version 0 makes the next look check it step by step
            M.Route.Stamps (K) := (CX => Integer_16 (Get (2)), CY => Integer_16 (Get (2)), Version => 0);
         end loop;
         M.Route.Overflow := Get_B;
         M.Leg := Positive (Get (2));
         M.Along := Get_F;
         M.Pace := Get_F;
         M.Replan := False;
      end;
   end loop;
   Trees_Pending := Version < 2;   --  from before trees: the stacks looked through hold some
   if Version >= 2 then
      for I in 1 .. N_Members loop
         Band (I).Tree := Natural (Get (2));
         Band (I).Pile := Natural (Get (2));
      end loop;
      Apples_Safe := Get_B;
      Reserves (Wood) := Natural (Get (4));
      N_Felled := Natural (Get (4));
      N_Trees := Natural (Get (2));
      for K in 1 .. N_Trees loop
         declare
            T : Tree_Rec renames Trees (K);
         begin
            T := (others => <>);
            T.I := Integer (Get (2));
            T.J := Integer (Get (2));
            T.Info.Valid := True;
            T.Info.Kind := Tree_Kind'Val (Get (1));
            T.Info.Bx := Integer (Get (2));
            T.Info.By := Integer (Get (2));
            T.Info.Bz := Integer (Get (2));
            T.Info.Trunk_W := Integer (Get (1));
            T.Info.Trunk_H := Integer (Get (1));
            T.Down := Get_B;
            Tree_Of.Include (Key_Of (T.I, T.J, 0), K);
         end;
      end loop;
      N_Piles := Natural (Get (2));
      for K in 1 .. N_Piles loop
         Piles (K).Centre := Get_V;
         Piles (K).Turn := Get_F;
         Piles (K).Count := Natural (Get (1));
         Piles (K).Claimed := 0;
      end loop;
   end if;
   if Version >= 3 then
      for I in 1 .. N_Members loop
         Band (I).Fetch := Item_Kind'Val (Get (1));
         Band (I).Tgt.X := Integer_16 (Get (2));
         Band (I).Tgt.Y := Integer_16 (Get (2));
         Band (I).Tgt.Z := Integer_16 (Get (2));
      end loop;
      for K of V3_Kinds loop
         Reserves (K) := Natural (Get (2));
      end loop;
      Trees_Pending := Get_B;
      for X in Indexed'Range (1) loop
         for Y in Indexed'Range (2) loop
            if Indexed (X, Y) then
               Sources (X, Y) := Unsigned_8 (Get (1));
            end if;
         end loop;
      end loop;
   else
      --  older saves never flagged sources: look again in every stack looked through
      for X in Indexed'Range (1) loop
         for Y in Indexed'Range (2) loop
            if Indexed (X, Y) then
               Sources (X, Y) := 7;
            end if;
         end loop;
      end loop;
   end if;
   if Version >= 4 then
      for K in 1 .. N_Piles loop
         Piles (K).Owner := Natural (Get (1));
      end loop;
      for K in V4_Kinds loop
         Demand (K) := Natural (Get (2));
      end loop;
   else
      --  before: piles were anyone's (a forester takes them over), stone
      --  was a reserve (now what is wanted), water was fetched (no more)
      Demand (Stone) := (if Version >= 3 then Reserves (Stone) elsif Stake_Set then Stone_Quota else 0);
      Reserves (Stone) := 0;
      Reserves (Water) := 0;
   end if;
   if Version >= 5 then
      declare
         Len : constant Natural := Natural (Get (4));
         H   : Castle.Herds.Bytes (0 .. Len - 1);
         Ok_H : Boolean;
      begin
         for K in H'Range loop
            H (K) := Unsigned_8 (Get (1));
         end loop;
         Castle.Herds.Load (H, Ok_H);
         if not Ok_H then
            raise Bad_Save;
         end if;
      end;
   elsif Stake_Set then
      Castle.Herds.Found (Stake_At, Castle.Hash.Derive (Band_Seed, 9));   --  from before the herds: placed once the ground is in
   end if;
   if Version >= 6 then
      for I in 1 .. N_Members loop
         Band (I).Prey := Natural (Get (2));
         Band (I).Prize := Natural (Get (1));
         Band (I).Cell2 := Natural (Get (2));
      end loop;
      Reserves (Meat) := Natural (Get (2));
      Deer_Safe := Get_B;
      N_Kills := Natural (Get (4));
      N_Shots := Natural (Get (4));
      N_Carcasses := Natural (Get (1));
      for K in 1 .. N_Carcasses loop
         declare
            C : Carcass_Rec renames Carcasses (K);
         begin
            C.Used := Get_B;
            C.Centre := Get_V;
            C.Turn := Get_F;
            C.Class := Castle.Deer.Class'Val (Get (1));
            C.Lying := Get_B;
            C.Holder := Natural (Get (1));
            C.Owner := Natural (Get (1));
         end;
      end loop;
   end if;
   if Version >= 7 then
      Needs_On := Get_B;
      N_Eaten := Natural (Get (4));
      for I in 1 .. N_Members loop
         Band (I).Fed := Get_F;
         Band (I).Ration := Natural (Get (2));
      end loop;
   else                                  --  from before needs: everyone fed and awake
      Needs_On := True;
      N_Eaten := 0;
      for I in 1 .. N_Members loop
         Band (I).Fed := 1.0;
         Band (I).Ration := 0;
      end loop;
   end if;
   if Version >= 8 then
      for K in V8_Kinds loop
         Demand (K) := Natural (Get (2));
         Reserves (K) := Natural (Get (2));
      end loop;
      Camp_Set := Get_B;
      Camp_At := Get_V;
      Seats_Laid := Natural (Get (1));
      Fire_Logs := Natural (Get (2));
      Fuel_H := Get_F;
      Pot_Stew := Natural (Get (4));
      Pot_Raw := Natural (Get (4));
      Pot_Meat := Natural (Get (4));
      Cook_Chosen := Get_B;
      N_Cooked := Natural (Get (4));
      N_Burnt := Natural (Get (4));
      for K in To_V8_Kinds loop
         In_Pot_N (K) := Natural (Get (4));
         Raw_Eaten_N (K) := Natural (Get (4));
      end loop;
      N_Pulled_All := Natural (Get (4));
      N_Pulled := Natural (Get (2));
      for K in 1 .. N_Pulled loop
         Pulled (K).P.X := Integer_16 (Get (2));
         Pulled (K).P.Y := Integer_16 (Get (2));
         Pulled (K).P.Z := Integer_16 (Get (2));
         Pulled (K).At_H := Bits_F64 (Get (8));
      end loop;
      for K in 1 .. N_Trees loop
         Trees (K).Apples := Natural (Get (2));
         Trees (K).Apple_Year := Integer (Get (2)) - 1;
      end loop;
      for I in 1 .. N_Members loop
         declare
            M : Member renames Band (I);
         begin
            M.From_Pot := Get_B;
            M.Seat := Natural (Get (1));
            M.Had_Stew := Get_B;
            M.Due := Natural (Get (2));
            M.Use_For := Camp_Use'Val (Get (1));
            M.Fends := Get_B;
            M.Mood := Get_F;
            M.Empty_H := Get_F;
            M.Is_Dead := Get_B;
         end;
      end loop;
      N_Deaths := Natural (Get (1));
   else                                  --  from before the camp: none, and nobody has cooked
      for K in V8_Kinds loop
         Demand (K) := 0;
         Reserves (K) := Default_Reserve (K);
      end loop;
      --  the rest as Reset left it
   end if;
   if Version >= 9 then
      for K in V9_Kinds loop
         Demand (K) := Natural (Get (2));
         Reserves (K) := Natural (Get (2));
         In_Pot_N (K) := Natural (Get (4));
         Raw_Eaten_N (K) := Natural (Get (4));
      end loop;
      for I in 1 .. N_Members loop
         Band (I).Grain := Natural (Get (2));
      end loop;
   end if;
   if Version >= 10 then
      Store_Days := Natural (Get (1));
   end if;
   if Version >= 11 then
      N_Zones := Natural (Get (2));
      if N_Zones > Max_Zones then
         raise Bad_Save;
      end if;
      for Z in 1 .. N_Zones loop
         Zones (Z) := (others => <>);
         Zones (Z).Kind := Zone_Kind'Val (Get (1));
         Zones (Z).Lo := Get_V;
         Zones (Z).Hi := Get_V;
         Zones (Z).Cells := Natural (Get (2));
      end loop;
      for K in 1 .. N_Cells loop
         Cells (K).Zone := Natural (Get (2));
         if Cells (K).Zone not in 1 .. N_Zones or else Zones (Cells (K).Zone).Kind /= Stockpile_Zone then
            raise Bad_Save;
         end if;
      end loop;
      Camp_Zone_N := Natural (Get (2));
      if (Camp_Zone_N = 0) = Camp_Set
        or else (Camp_Set and then (Camp_Zone_N > N_Zones or else Zones (Camp_Zone_N).Kind /= Camp_Zone))
      then
         raise Bad_Save;
      end if;
      for I in 1 .. N_Members loop
         declare
            D : constant Integer := Integer (Get (1)) - 1;
         begin
            if D > N_Members then
               raise Bad_Save;
            end if;
            Band (I).Director := D;
         end;
      end loop;
   else
      --  from before zones: one for each group of cells that touch, and the
      --  camp's; from before directors: the player gave every job there is
      Zones_From_Cells;
      for I in 1 .. N_Members loop
         Band (I).Director := (if Band (I).Job = Unassigned then No_One else The_Player);
      end loop;
   end if;
   --  skills: each one's aptitudes and the levels it arrived with come from
   --  its seed; a version 12 blob then gives the levels as they had grown
   for I in 1 .. N_Members loop
      Give_Skills (Band (I));
   end loop;
   if Version >= 12 then
      Skills_On := Get_B;
      declare
         Stored : constant Natural := Natural (Get (1));
      begin
         for I in 1 .. N_Members loop
            for K in 0 .. Stored - 1 loop
               declare
                  L : constant Long_Float := Bits_F64 (Get (8));
               begin
                  if K <= Skill_Kind'Pos (Skill_Kind'Last) then
                     if not (L >= 0.0 and then L <= 1.0) then
                        raise Bad_Save;
                     end if;
                     Band (I).Skill (Skill_Kind'Val (K)) := L;
                  end if;
               end;
            end loop;
         end loop;
      end;
   else
      Skills_On := True;                  --  from before skills: on, as a colony founded now has them
   end if;
   Asking := [others => False];
   Food_Asking := False;
   if Version >= 13 then
      Chain_On := Get_B;
      Food_Asking := Get_B;
      declare
         Stored_N : constant Natural := Natural (Get (1));
      begin
         for K in 0 .. Stored_N - 1 loop
            declare
               A : constant Boolean := Get_B;
            begin
               if K <= Item_Kind'Pos (Item_Kind'Last) then
                  Asking (Item_Kind'Val (K)) := A;
               end if;
            end;
         end loop;
      end;
      Stock_Stale := False;
   else
      --  from before the chain: on, as a colony founded now has it; a wood
      --  reserve of none, which was no limit, becomes the surplus a new
      --  colony asks for; and stock is taken at the first step
      Chain_On := True;
      if Reserves (Wood) = 0 then
         Reserves (Wood) := Default_Reserve (Wood);
      end if;
      Stock_Stale := True;
   end if;
   if Version >= 14 then
      declare
         function Get_I16 return Integer_16 is
            V : constant Unsigned_16 := Unsigned_16 (Get (2));
         begin
            return (if V >= 32_768 then Integer_16 (Integer (V) - 65_536) else Integer_16 (V));
         end Get_I16;
      begin
         N_Runs := 0;
         for Z in 1 .. N_Zones loop
            Zones (Z).Turn := Get_F;
            Zones (Z).First := N_Runs;
            Zones (Z).N := Natural (Get (4));
            if N_Runs + Zones (Z).N > Max_Zone_Runs then
               raise Bad_Save;
            end if;
            for K in N_Runs + 1 .. N_Runs + Zones (Z).N loop
               Runs (K).Y := Get_I16;
               Runs (K).X0 := Get_I16;
               Runs (K).X1 := Get_I16;
               Runs (K).Z := Get_I16;
               if Runs (K).X1 < Runs (K).X0 then
                  raise Bad_Save;
               end if;
            end loop;
            N_Runs := N_Runs + Zones (Z).N;
            Measure_Zone (Z);
         end loop;
         for K in 1 .. N_Cells loop
            Cells (K).Turn := Zones (Cells (K).Zone).Turn;
         end loop;
         Zones_Ver := Zones_Ver + 1;
      end;
      Labour_On := Get_B;
      Ember_H := Get_F;
      if not (Ember_H >= 0.0 and then Ember_H <= Die_Down_Hours) then
         raise Bad_Save;
      end if;
      for Z in 1 .. N_Zones loop
         Zones (Z).Built := Get_B;
         declare
            Stored_N : constant Natural := Natural (Get (1));
         begin
            Zones (Z).Got := [others => 0];
            for K in 0 .. Stored_N - 1 loop
               declare
                  N : constant Natural := Natural (Get (2));
               begin
                  if K <= Item_Kind'Pos (Item_Kind'Last) then
                     Zones (Z).Got (Item_Kind'Val (K)) := N;
                  end if;
               end;
            end loop;
         end;
      end loop;
      for I in 1 .. N_Members loop
         Band (I).Patch := Natural (Get (2));
         if Band (I).Patch > Max_Patch then
            raise Bad_Save;
         end if;
      end loop;
   else
      --  from before zones had ground of their own: the square metre under
      --  each cell, and the camp's square; from before the camp took labour:
      --  it does now, as a colony founded now, and what is on its fire burns on
      --  (a camp of then stands, as it stood; nobody was building)
      Ground_From_Cells;
      Labour_On := True;
      Ember_H := 0.0;
      for Z in 1 .. N_Zones loop
         Zones (Z).Built := True;
         Zones (Z).Got := Build_Takes (Zones (Z).Kind);
      end loop;
      for I in 1 .. N_Members loop
         Band (I).Patch := 0;
      end loop;
   end if;
   Ground_Left_N := 0;                    --  (counted again at the next step, once the ground is in)
   if Version >= 15 then
      Far_Reach := Get_F;
      Stone_From := Get_F;
      if not (Far_Reach >= 0.0 and then Far_Reach <= Far_Reach_Max_M) or else not (Stone_From >= 0.0) then
         raise Bad_Save;
      end if;
      for I in 1 .. N_Members loop
         Band (I).Site_Seg := Natural (Get (2));
         Band (I).Site_M := Natural (Get (1));
         if Band (I).Site_Seg > N_Paths then
            raise Bad_Save;
         end if;
      end loop;
   else
      Far_Reach := 0.0;
      Stone_From := 0.0;
   end if;
   if Version >= 16 then
      Hands_Set := Natural (Get (1));
      if Hands_Set > Max_Members then
         raise Bad_Save;
      end if;
      Stretches_On := Get_B;
      for I in 1 .. N_Members loop
         Band (I).Site_Laid := Natural (Get (1));
      end loop;
      Level_On := Get_B;
      declare
         V : constant Natural := Natural (Get (2));
      begin
         Camp_Level := (if V >= 32_768 then V - 65_536 else V);
         if Camp_Level < -1 then
            raise Bad_Save;
         end if;
      end;
      Sod_Bits := Natural (Get (2));
      Cut_Left_N := Natural (Get (2));
      Fill_Left_N := Natural (Get (2));
      for K in V16_Kinds loop
         Demand (K) := Natural (Get (2));
         Reserves (K) := Natural (Get (2));
      end loop;
   else
      --  (a camp of before stands as it lies; one still being built has
      --  its floor levelled from now on: its level is chosen at the next step)
      Level_On := True;
      Camp_Level := -1;
      Sod_Bits := 0;
      Cut_Left_N := 0;
      Fill_Left_N := 0;
      for K in V16_Kinds loop
         Demand (K) := 0;
         Reserves (K) := Default_Reserve (K);
      end loop;
      Hands_Set := 0;                     --  (by the rule, and a stretch to a serf, as a colony founded now)
      Stretches_On := True;
      for I in 1 .. N_Members loop
         Band (I).Site_Laid := 0;
      end loop;
   end if;
   --  version 21: housing (a blob of before has no houses)
   if Version >= 22 then
      House_Serial := Natural (Get (2));
      N_Houses := Natural (Get (1));
      if N_Houses > Max_Houses then
         raise Bad_Save;
      end if;
      for H in 1 .. N_Houses loop
         declare
            Hs : House_Rec renames Houses (H);
            function Get_I16 return Integer is
               V : constant Natural := Natural (Get (2));
            begin
               return (if V >= 32_768 then V - 65_536 else V);
            end Get_I16;
         begin
            Hs := (others => <>);
            Hs.Zone := Natural (Get (2));
            Hs.Seed := Get (8);
            Hs.F := Castle.Buildings.Design (Hs.Seed);
            Hs.F.Fx := Get_I16;
            Hs.F.Fy := Get_I16;
            case Get (1) is
               when 0 => Hs.F.Vx := 1;  Hs.F.Vy := 0;  Hs.F.Ux := 0; Hs.F.Uy := 1;
               when 1 => Hs.F.Vx := -1; Hs.F.Vy := 0;  Hs.F.Ux := 0; Hs.F.Uy := 1;
               when 2 => Hs.F.Vx := 0;  Hs.F.Vy := 1;  Hs.F.Ux := 1; Hs.F.Uy := 0;
               when 3 => Hs.F.Vx := 0;  Hs.F.Vy := -1; Hs.F.Ux := 1; Hs.F.Uy := 0;
               when others => raise Bad_Save;
            end case;
            Hs.F.Pad := Get_I16;
            Hs.F.Door_Run := Natural (Get (1));
            Hs.F.Door_Row := Get_I16;
            for U in Hs.F.Front'Range loop
               Hs.F.Front (U) := Natural (Get (1));
            end loop;
            Hs.F.Reach_L := Natural (Get (1));
            Hs.F.Reach_R := Natural (Get (1));
            if Hs.F.Reach_L > Castle.Buildings.Max_Reach_B or else Hs.F.Reach_R > Castle.Buildings.Max_Reach_B then
               raise Bad_Save;
            end if;
            Hs.Got (Stone) := Natural (Get (2));
            Hs.Lying (Stone) := Natural (Get (2));
            Hs.Stone_Left := Natural (Get (2));
            Hs.Owner := Natural (Get (1));
            Hs.Bed := Get_B;
            Hs.Pad_Done := Get_B;
            Hs.Built := Get_B;
            Hs.Placed := Natural (Get (2));
            Hs.Got (Wood) := Natural (Get (2));
            Hs.Got (Straw) := Natural (Get (2));
            Hs.Lying (Wood) := Natural (Get (2));
            Hs.Lying (Straw) := Natural (Get (2));
            if Hs.Zone not in 1 .. N_Zones or else Hs.Owner > N_Members then
               raise Bad_Save;
            end if;
            Measure_House (H);
            if Hs.Placed > Hs.Total then
               raise Bad_Save;
            end if;
         end;
      end loop;
      for I in 1 .. N_Members loop
         Band (I).Site := Natural (Get (1));
         Band (I).Site_Patch := Natural (Get (2));
         if Band (I).Site > N_Houses or else Band (I).Site_Patch > Max_Site_Patches then
            raise Bad_Save;
         end if;
      end loop;
      Pace_Now := Get_F;
      if Pace_Now not in 0.1 .. 10.0 then
         raise Bad_Save;
      end if;
      Beds_On := Get_B;
      Bed_Sheaves := Natural (Get (2));
      for I in 1 .. N_Members loop
         Band (I).Bed := Get_B;
         Band (I).Bed_At := Get_V;
         Band (I).Bed_Has := Natural (Get (1));
         Band (I).Placed := Get_B;
         Band (I).Bed_Dir := Get_F;
         Band (I).Bed_Lo := Integer (Get (2)) - 1;
         Band (I).Bed_Hi := Integer (Get (2)) - 1;
      end loop;
      N_Lots := Natural (Get (1));
      Lots_Are_Short := Get_B;
      if N_Houses + N_Lots > Max_Houses then
         raise Bad_Save;
      end if;
      for K in 1 .. N_Lots loop
         declare
            L : Lot_Rec renames Lots (K);
            function Get_I16 return Integer is
               V : constant Natural := Natural (Get (2));
            begin
               return (if V >= 32_768 then V - 65_536 else V);
            end Get_I16;
         begin
            L.Zone := Natural (Get (2));
            L.F := Castle.Buildings.Design (House_Seed (House_Serial + K));
            L.F.Fx := Get_I16;
            L.F.Fy := Get_I16;
            case Get (1) is
               when 0 => L.F.Vx := 1;  L.F.Vy := 0;  L.F.Ux := 0; L.F.Uy := 1;
               when 1 => L.F.Vx := -1; L.F.Vy := 0;  L.F.Ux := 0; L.F.Uy := 1;
               when 2 => L.F.Vx := 0;  L.F.Vy := 1;  L.F.Ux := 1; L.F.Uy := 0;
               when 3 => L.F.Vx := 0;  L.F.Vy := -1; L.F.Ux := 1; L.F.Uy := 0;
               when others => raise Bad_Save;
            end case;
            L.F.Pad := Get_I16;
            L.F.Door_Run := Natural (Get (1));
            L.F.Door_Row := Get_I16;
            for U in L.F.Front'Range loop
               L.F.Front (U) := Natural (Get (1));
            end loop;
            if L.Zone not in 1 .. N_Zones then
               raise Bad_Save;
            end if;
         end;
      end loop;
      Hold_On := Get_B;                 --  (23: whether the cook keeps a pot's fill)
      Curing_On := Get_B;               --  (curing, the lord's cart and its salt)
      Cart_Set := Get_B;
      Cart_Tried := Get_B;
      Cart_P := Get_V;
      Cart_X := Get_B;
      Cart_Salt_N := Natural (Get (2));
      N_Salted := Natural (Get (4));
      N_Unsalted := Natural (Get (4));
      N_Meat_Lost := Natural (Get (4));
      for K in V23_Kinds loop
         Demand (K) := Natural (Get (2));
         Reserves (K) := Natural (Get (2));
      end loop;
      Ladders_On := Get_B;              --  (ladders)
      N_Ladders := Natural (Get (2));
      N_Ladders_Lost := Natural (Get (2));
      for H in 1 .. N_Houses loop
         Houses (H).Ladder := Natural (Get (1));
         Houses (H).Ladder_P := Get_V;
         Houses (H).Ladder_Fells := Natural (Get (1));
         if Houses (H).Ladder > 4 then
            raise Bad_Save;
         end if;
      end loop;
      for I in 1 .. N_Members loop
         Band (I).Ladder_Of := Natural (Get (1));
         if Band (I).Ladder_Of > N_Houses then
            raise Bad_Save;
         end if;
      end loop;
      Holes_On := Get_B;                --  (24: a hole under a path filled as it is laid)
      Pull_On := Get_B;                 --  (25: the lord's cart pulled into a stockpile)
      Cart_Turn := Get_F;
      Cart_Towed := Get_B;
      Cart_By := Natural (Get (1));
      Cart_Bound := Get_B;
      Goal_P := Get_V;
      Goal_Turn := Get_F;
      Cart_From := Get_V;
      if Cart_By > N_Members or else (Cart_Towed and then Cart_By = 0) then
         raise Bad_Save;
      end if;
   else
      --  (a blob of before housing: nobody is building a house; beds are
      --  made from now on, as a colony founded now makes them)
      N_Lots := 0;
      Lots_Are_Short := False;
      Pace_Now := 1.0;                  --  (and it works and walks as it did)
      Hold_On := False;                 --  (and its cook keeps nothing back, as none did)
      Curing_On := False;               --  (no cart, and its meat in joints)
      Ladders_On := False;              --  (and its roofs thatched from the ground)
      Holes_On := False;                --  (and its paths laid down into holes)
      Pull_On := False;                 --  (and the cart, had it one, left where it stood)
      Cart_Towed := False;
      Cart_Bound := False;
      Cart_By := 0;
      Cart_Tried := True;
      Beds_On := True;
      Bed_Sheaves := 0;
      for I in 1 .. N_Members loop
         Band (I).Bed := False;
         Band (I).Bed_Has := 0;
         Band (I).Placed := False;
      end loop;
      for I in 1 .. N_Members loop
         Band (I).Site := 0;
         Band (I).Site_Patch := 0;
      end loop;
   end if;
   Count_Housing;
   BP_Of := 0;
   --  what of the paths is still to lay is read from the ground at the next
   --  step (till then every stretch is taken to be all to lay, so that the
   --  colony's ground reaches it)
   for K in 1 .. N_Paths loop
      Path_List (K).Known := False;
      Path_List (K).Todo := (if Labour_On then All_Metres (Path_List (K)) else 0);
   end loop;
   Count_Paths;
   Paths_Stale := True;
   --  what each had reserved, and the way it was going
   for I in 1 .. N_Members loop
      declare
         M : Member renames Band (I);
      begin
         if M.State in To_Bush | Picking and then M.Bush in 1 .. N_Bushes then
            Bushes (M.Bush).Reserved_By := I;
         end if;
         if M.State in To_Store | Storing and then M.Cell in 1 .. N_Cells then
            Cells (M.Cell).Incoming := Cells (M.Cell).Incoming + M.Carried;
         end if;
         if M.State = To_Eat and then M.From_Pot then
            Pot_Out := Pot_Out + M.Ration;
         elsif M.State = To_Eat and then M.Cell in 1 .. N_Cells then
            Cells (M.Cell).Outgoing := Cells (M.Cell).Outgoing
              + Items_For (M.Ration, Positive'Max (1, Raw_Food (Cells (M.Cell).Kind)));
         end if;
         if M.State in To_Take | Taking and then M.Cell in 1 .. N_Cells then
            Cells (M.Cell).Outgoing := Cells (M.Cell).Outgoing + M.Due;
         end if;
         if M.State in To_Tree | Chopping and then M.Tree in 1 .. N_Trees then
            Trees (M.Tree).Reserved_By := I;
         end if;
         if M.State in To_Pile | Lifting and then M.Pile in 1 .. N_Piles then
            Piles (M.Pile).Claimed := Piles (M.Pile).Claimed + 1;
         end if;
         if M.State in To_Butcher | Butchering and then M.Prize in 1 .. N_Carcasses
           and then M.Cell in 1 .. N_Cells and then M.Cell2 in 1 .. N_Cells
         then
            Cells (M.Cell).Incoming := Cells (M.Cell).Incoming + Meat_Of (Carcasses (M.Prize).Class);
            Cells (M.Cell2).Incoming := Cells (M.Cell2).Incoming + 1;
         end if;
      end;
   end loop;
   if Pos /= B'Last + 1 then
      raise Bad_Save;
   end if;
   Ok := True;
exception
   when Bad_Save | Constraint_Error =>
      Reset;
      Ok := False;
end Load;
