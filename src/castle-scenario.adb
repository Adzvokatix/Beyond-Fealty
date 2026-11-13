with Ada.Command_Line; use Ada.Command_Line;
with Ada.Text_IO;      use Ada.Text_IO;
with Castle.Actions;
with Castle.Climate;
with Castle.Herds;
with Castle.Math;      use Castle.Math;
with Castle.Nav;
with Castle.Text;      use Castle.Text;

package body Castle.Scenario is

   use Castle.Colony;

   function Parse (S : in out Setup; I : in out Positive) return Boolean is
      function Arg (K : Natural) return String is (Argument (I + K));
      A : constant String := Arg (0);
   begin
      if A = "--stake" then
         S.Stake := True;
         S.Stake_X := Float'Value (Arg (1));
         S.Stake_Y := Float'Value (Arg (2));
         I := I + 3;
      elsif A = "--path" then
         if S.Path_N < S.Paths'Last (1) then
            S.Path_N := S.Path_N + 1;
            for K in 1 .. 4 loop
               S.Paths (S.Path_N, K) := Float'Value (Arg (K));
            end loop;
         end if;
         I := I + 5;
      elsif A = "--stockpile" then
         if S.Pile_N < S.Piles'Last (1) then
            S.Pile_N := S.Pile_N + 1;
            for K in 1 .. 4 loop
               S.Piles (S.Pile_N, K) := Float'Value (Arg (K));
            end loop;
         end if;
         I := I + 5;
      elsif A = "--housing" then
         if S.Housing_N < S.Housing'Last (1) then
            S.Housing_N := S.Housing_N + 1;
            for K in 1 .. 4 loop
               S.Housing (S.Housing_N, K) := Float'Value (Arg (K));
            end loop;
         end if;
         I := I + 5;
      elsif A = "--homes-built" then
         S.Homes_Built := True;
         I := I + 1;
      elsif A = "--camp" then
         S.Camp := True;
         S.Camp_X := Float'Value (Arg (1));
         S.Camp_Y := Float'Value (Arg (2));
         I := I + 3;
      elsif A = "--camp-built" then
         S.Camp_Built := True;
         I := I + 1;
      elsif A = "--stoke" then
         S.Stoke := Float'Value (Arg (1));
         I := I + 2;
      elsif A = "--gatherers" then
         S.Gatherers := Natural'Value (Arg (1)); I := I + 2;
      elsif A = "--foresters" then
         S.Foresters := Natural'Value (Arg (1)); I := I + 2;
      elsif A = "--porters" then
         S.Porters := Natural'Value (Arg (1)); I := I + 2;
      elsif A = "--hunters" then
         S.Hunters := Natural'Value (Arg (1)); I := I + 2;
      elsif A = "--cooks" then
         S.Cooks := Natural'Value (Arg (1)); I := I + 2;
      elsif A = "--band" then
         S.Band := Positive'Value (Arg (1)); I := I + 2;
      elsif A = "--job" then
         declare
            Who : constant Integer := Integer'Value (Arg (1));
            J   : constant String := Arg (2);
         begin
            if Who not in S.Job_Set'Range
              or else J not in "gatherer" | "forester" | "porter" | "hunter" | "cook" | "none"
            then
               Put_Line ("--job: a member (1 .. " & Img (Integer'(Max_Members))
                         & ") and gatherer, forester, porter, hunter, cook or none, not " & Arg (1) & " " & J);
            else
               S.Job_Set (Who) := True;
               S.Job_Given (Who) :=
                 (if J = "gatherer" then Gatherer elsif J = "forester" then Forester elsif J = "porter" then Porter
                  elsif J = "hunter" then Hunter elsif J = "cook" then Cook else Unassigned);
            end if;
         end;
         I := I + 3;
      elsif A = "--supply" then
         declare
            K : Item_Kind := Nothing;
         begin
            for J in Item_Kind loop
               if Name (J) = Arg (1) then
                  K := J;
               end if;
            end loop;
            if Arg (1) = "logs" then
               K := Wood;
            end if;
            if K = Nothing or else Cell_Limit (K) = 0 then
               Put_Line ("--supply: meat, berries, vegetables, apples, grain, wood, stone, straw or earth, not "
                         & Arg (1));
            else
               S.Supply (K) := Natural'Value (Arg (2));
            end if;
         end;
         I := I + 3;
      elsif A = "--reserve" then
         declare
            K : constant Item_Kind :=
              (if Arg (1) = "straw" then Straw elsif Arg (1) = "meat" then Meat
               elsif Arg (1) = "vegetables" then Vegetables elsif Arg (1) in "wood" | "logs" then Wood else Nothing);
         begin
            if K = Nothing then
               Put_Line ("--reserve: wood, straw, meat or vegetables, not " & Arg (1));
            elsif K = Wood then
               S.Wood_Reserve := Natural'Value (Arg (2));
               S.Wood_Given := True;
            else
               S.Reserves (K) := Natural'Value (Arg (2));
            end if;
         end;
         I := I + 3;
      elsif A = "--wood-reserve" then
         S.Wood_Reserve := Natural'Value (Arg (1)); S.Wood_Given := True; I := I + 2;
      elsif A = "--winter-store" then
         S.Winter_Store := Natural'Value (Arg (1)); I := I + 2;
      elsif A = "--spare-deer" then
         S.Spare_Deer := True; I := I + 1;
      elsif A = "--fell-apples" then
         S.Fell_Apples := True; I := I + 1;
      elsif A = "--no-skills" then
         S.Skills := False; I := I + 1;
      elsif A = "--no-demand" then
         S.Demand := False; I := I + 1;
      elsif A = "--no-needs" then
         S.Needs := False; I := I + 1;
      elsif A in "--no-labour" | "--instant-camp" then
         S.Labour := False; I := I + 1;
      elsif A = "--paths-built" then
         S.Paths_Built := True; I := I + 1;
      elsif A = "--stone-from" then
         S.Stone_From := Float'Value (Arg (1)); I := I + 2;
      elsif A = "--extra-hands" then
         S.Extra_Hands := Natural'Value (Arg (1)); I := I + 2;
      elsif A = "--all-hands" then
         S.All_Hands := True; I := I + 1;
      elsif A = "--no-level" then
         S.No_Level := True; I := I + 1;
      elsif A = "--deer-scatter" then
         S.Deer_Scatter := True; I := I + 1;
      elsif A = "--by-skill" then
         S.By_Skill := True; I := I + 1;
      elsif A = "--skills-at" then
         S.Skills_At := Float'Value (Arg (1)); I := I + 2;
      else
         return False;
      end if;
      return True;
   end Parse;

   function Body_Job (J : Castle.Colony.Job_Kind) return Castle.Bodies.Job_Kind is
     (case J is
         when Unassigned => Castle.Bodies.Idle,
         when Gatherer   => Castle.Bodies.Gatherer,
         when Forester   => Castle.Bodies.Forester,
         when Hunter     => Castle.Bodies.Hunter,
         when Porter     => Castle.Bodies.Porter,
         when Cook       => Castle.Bodies.Idle);

   procedure Apply (S : Setup; Seed : Castle.Hash.U64) is
      use Castle.Actions;
      function At_Ground (X, Y : Float) return Vec3 is ((X, Y, Castle.Nav.Surface_Z (X, Y)));
      P : constant Vec3 := At_Ground (S.Stake_X, S.Stake_Y);
      R : Result;
      --  Everything here is the player's doing, through the action table.
      procedure Order_It (O : Order) is
      begin
         Perform (O, R);
      end Order_It;
   begin
      if P.Z < 0.0 then
         Put_Line ("--stake: nowhere to stand at" & Img (S.Stake_X, 1) & "," & Img (S.Stake_Y, 1));
         return;
      end if;
      Set_Skills (S.Skills);                         --  the world's to say, like the band's size
      Set_Demand_Chain (S.Demand);
      Set_Labour (S.Labour);
      if not S.Needs then
         Set_Needs (False);                          --  (said only when asked: a colony's own is on)
      end if;
      Castle.Herds.Set_Scatter (S.Deer_Scatter);     --  (before the stake: the herds are placed by it)
      Set_Arrivals (S.Band, Castle.Hash.Derive (Seed, 7));
      Order_It ((What => Raise_Stake, By => The_Player, Stake_At => P));
      Set_Stone_From (S.Stone_From);
      Set_Levelling (not S.No_Level);
      if S.All_Hands then
         Set_Extra_Hands (Max_Members);
         Set_Stretches (False);
      elsif S.Extra_Hands > 0 then
         Set_Extra_Hands (S.Extra_Hands);
      end if;
      if S.Skills_At >= 0.0 then                     --  a measuring band: nobody's doing
         for I in 1 .. Members loop
            for K in Working_Skill loop
               Set_Skill (I, K, S.Skills_At);
            end loop;
         end loop;
      end if;
      for K in 1 .. S.Path_N loop
         Order_It ((What => Lay_Path, By => The_Player,
                    From => At_Ground (S.Paths (K, 1), S.Paths (K, 2)),
                    To => At_Ground (S.Paths (K, 3), S.Paths (K, 4))));
         Put_Line (if R.Count = 0 then "path refused: " & Path_Refusal
                   elsif Labour then "path planned:" & R.Count'Image & " blocks of footpath to lay"
                   else "path laid:" & R.Count'Image & " blocks of footpath");
      end loop;
      if S.Paths_Built and then Paths_To_Lay > 0 then
         Build_Paths_Now;                            --  footpath from nowhere, like the goods below
         Put_Line ("the paths laid");
      end if;
      for K in 1 .. S.Pile_N loop
         Order_It ((What => Zone_Stockpile, By => The_Player, X0 => S.Piles (K, 1), Y0 => S.Piles (K, 2),
                    X1 => S.Piles (K, 3), Y1 => S.Piles (K, 4)));
         Put_Line (if R.Count = 0 then "stockpile refused: " & Stockpile_Refusal
                   else "stockpile zoned:" & R.Count'Image & " cells");
      end loop;
      if S.Camp then
         Order_It ((What => Zone_Camp, By => The_Player, Fire_At => At_Ground (S.Camp_X, S.Camp_Y)));
         Put_Line (if R.Done then "camp zoned" else "camp refused: " & Camp_Refusal);
         if R.Done and then Camp_State.Floor_Z >= 0.0 then
            Put_Line ("camp floor: to be level at " & Img (Camp_State.Floor_Z, 2) & " m:" & Camp_State.To_Dig'Image
                      & " blocks of earth to dig off," & Camp_State.To_Fill'Image & " to fill");
         end if;
         if R.Done and then S.Camp_Built and then not Camp_State.Built then
            Build_Camp_Now;                          --  a hearth from nowhere, like the goods below
            Put_Line ("the camp built");
         end if;
         if R.Done and then S.Stoke > 0.0 then       --  a fire from nowhere, like the goods below
            Stoke (S.Stoke);
            Put_Line ("the fire lit, " & Img (S.Stoke, 1) & " hours on it");
         end if;
      end if;
      for K in 1 .. S.Housing_N loop
         Order_It ((What => Zone_Housing, By => The_Player, X0 => S.Housing (K, 1), Y0 => S.Housing (K, 2),
                    X1 => S.Housing (K, 3), Y1 => S.Housing (K, 4)));
         Put_Line (if R.Count = 0 then "housing refused: " & Housing_Refusal
                   else "housing zoned: room for" & R.Count'Image & (if R.Count = 1 then " hovel" else " hovels"));
      end loop;
      if S.Homes_Built and then S.Housing_N > 0 then
         Build_Homes_Now;                            --  houses from nowhere, like the goods below
         Put_Line ("homes built:" & House_Count'Image);
      end if;
      for K in Item_Kind loop                        --  goods from nowhere: no actor's doing
         if S.Supply (K) > 0 then
            declare
               Placed : Natural;
            begin
               Supply (K, S.Supply (K), Placed);
               Put_Line ("supplied" & Placed'Image & " " & Name (K));
            end;
         end if;
      end loop;
      if S.By_Skill and then S.Skills then
         --  each job to whoever of those still without one is best at its skill
         declare
            Wanted : constant array (Job_Kind) of Natural :=
              [Unassigned => 0, Gatherer => S.Gatherers, Forester => S.Foresters, Porter => S.Porters,
               Hunter => S.Hunters, Cook => S.Cooks];
            Order  : constant array (1 .. 5) of Job_Kind := [Gatherer, Forester, Porter, Hunter, Cook];
         begin
            for J of Order loop
               for N in 1 .. Wanted (J) loop
                  declare
                     Best : Natural := 0;
                  begin
                     for I in 1 .. Members loop
                        if Job_Of (I) = Unassigned
                          and then (Best = 0 or else Skill_Of (I, Job_Skill (J)) > Skill_Of (Best, Job_Skill (J)))
                        then
                           Best := I;
                        end if;
                     end loop;
                     exit when Best = 0;
                     Order_It ((What => Give_Job, By => The_Player, Whom => Best, Job => J));
                  end;
               end loop;
            end loop;
         end;
      else
         for I in 1 .. Members loop
            declare
               J : constant Job_Kind :=
                 (if I <= S.Gatherers then Gatherer
                  elsif I <= S.Gatherers + S.Foresters then Forester
                  elsif I <= S.Gatherers + S.Foresters + S.Porters then Porter
                  elsif I <= S.Gatherers + S.Foresters + S.Porters + S.Hunters then Hunter
                  elsif I <= S.Gatherers + S.Foresters + S.Porters + S.Hunters + S.Cooks then Cook
                  else Unassigned);
            begin
               if J /= Unassigned then
                  Order_It ((What => Give_Job, By => The_Player, Whom => I, Job => J));
               end if;
            end;
         end loop;
      end if;
      for I in 1 .. Members loop                     --  and those said one by one
         if S.Job_Set (I) then
            Order_It ((What => Give_Job, By => The_Player, Whom => I, Job => S.Job_Given (I)));
         end if;
      end loop;
      if S.Wood_Given then                           --  else the colony's own: a surplus of 20, or with no chain no limit
         Order_It ((What => Set_Reserve, By => The_Player, Kind => Wood, Amount => S.Wood_Reserve));
      end if;
      Order_It ((What => Spare_Apples, By => The_Player, On => not S.Fell_Apples));
      Order_It ((What => Set_Reserve, By => The_Player, Kind => Straw, Amount => S.Reserves (Straw)));
      Order_It ((What => Set_Reserve, By => The_Player, Kind => Meat, Amount => S.Reserves (Meat)));
      Order_It ((What => Set_Reserve, By => The_Player, Kind => Vegetables, Amount => S.Reserves (Vegetables)));
      Order_It ((What => Castle.Actions.Spare_Deer, By => The_Player, On => S.Spare_Deer));
      Order_It ((What => Set_Winter_Store, By => The_Player, Days => S.Winter_Store));
      Put_Line ("the band:");
      for I in 1 .. Members loop
         Put_Line ("  " & Name_Of (I) & ", "
                   & Castle.Bodies.Describe (Genome_Of (I), (Job => Body_Job (Job_Of (I)), Winter => False))
                   & (if Skills and then Has_Skill (Job_Of (I))
                      then "; " & Name (Job_Skill (Job_Of (I))) & " " & Img (Skill_Of (I, Job_Skill (Job_Of (I))), 2)
                           & " (learns x" & Img (Aptitude_Of (I, Job_Skill (Job_Of (I))), 1) & ")"
                      else ""));
      end loop;
   end Apply;

   function Deer_Alive return Natural is
      N : Natural := 0;
   begin
      for K in 1 .. Castle.Herds.Deer_Slots loop
         if Castle.Herds.Alive (K) then
            N := N + 1;
         end if;
      end loop;
      return N;
   end Deer_Alive;

   function Colony_Line return String is
      Working, Carried_N, Hungry_N, Asleep_N : Natural := 0;
   begin
      if not Has_Stake then
         return "";
      end if;
      for I in 1 .. Members loop
         if Job_Of (I) /= Unassigned then
            Working := Working + 1;
         end if;
         if Hungry (I) then
            Hungry_N := Hungry_N + 1;
         end if;
         if Asleep (I) then
            Asleep_N := Asleep_N + 1;
         end if;
         if Carrying (I) = Berries then
            Carried_N := Carried_N + Carried (I);
         end if;
      end loop;
      return "colony:" & Members'Image & " in the band," & Living'Image & " living," & Working'Image
        & " at work, tick" & Ticks'Image & ";" & Stored (Berries)'Image & " berries stored,"
        & Carried_N'Image & " carried," & Berries_Left'Image & " on"
        & Bush_Count'Image & " bushes;" & Trees_Felled'Image & " of" & Tree_Count'Image
        & " trees felled," & Stored (Wood)'Image & " logs stored," & Logs_Lying'Image & " lying;"
        & Stored (Straw)'Image & " straw," & Stored (Stone)'Image & " stone," & Stored (Grain)'Image
        & " grain stored;" & Deer_Alive'Image
        & " deer in" & Castle.Herds.Herd_Count'Image & " herds;" & Kills'Image & " killed with" & Shots'Image
        & " arrows," & Stored (Meat)'Image & " meat," & Stored (Hide)'Image & " hides stored;"
        & Eaten'Image & " food eaten," & Hungry_N'Image & " hungry," & Asleep_N'Image & " asleep, food for "
        & Img (Food_Days, 1) & " days, confidence" & Integer (100.0 * Confidence)'Image & " %";
   end Colony_Line;

   procedure Put_Report (After_Colony_Line : String := "") is
   begin
      if not Has_Stake then
         return;
      end if;
      Put_Line (Colony_Line & After_Colony_Line);
      if Has_Camp then
         declare
            C : constant Camp_View := Camp_State;
         begin
            if not C.Built then
               Put_Line ("camp: being built:" & C.Ground_Left'Image & " square metres of ground to make ready, stone"
                         & C.Stones'Image & " of" & Integer'Image (Hearth_Stones) & ", wood" & C.Frame'Image & " of"
                         & Integer'Image (Hearth_Wood));
            end if;
            Put_Line ("camp: fire " & (if C.Burning then "burning (" & Img (C.Fuel_H, 1) & " h)"
                                       elsif C.Dying then "dying down (" & Img (C.Ember_H, 1) & " h)" else "out") & ","
                      & C.Logs'Image & " logs stacked," & C.Burnt'Image & " burnt," & C.Seats'Image & " seats; stew"
                      & C.Stew'Image & " in the pot," & Cooked'Image & " cooked from" & Put_In_Pot (Meat)'Image
                      & " meat," & Put_In_Pot (Vegetables)'Image & " vegetables," & Put_In_Pot (Berries)'Image
                      & " berries," & Put_In_Pot (Apples)'Image & " apples," & Put_In_Pot (Grain)'Image
                      & " grain; eaten raw" & Eaten_Raw (Berries)'Image
                      & " berries," & Eaten_Raw (Vegetables)'Image & " vegetables," & Eaten_Raw (Apples)'Image
                      & " apples");
         end;
      end if;
      for I in 1 .. Members loop
         if Job_Of (I) = Cook then
            Put_Line ("the cook, " & Name_Of (I) & ": " & Status (I));
         end if;
      end loop;
      if Skills then
         Put_Line (Skills_Line);
      end if;
      if Demand_Chain then
         Put_Line (Demand_Line);
      end if;
      if Housing_Line /= "" then
         Put_Line (Housing_Line);
      end if;
   end Put_Report;

   function Housing_Line return String is
      Standing_N, Building_N, Home_N : Natural := 0;
      function From (H : Positive) return String is
      begin
         if H > House_Count then
            return "";
         end if;
         declare
            V : constant House_View := House_At (H);
         begin
            return
              (if V.Phase = Standing then ""
               else "; " & (if V.Owner in 1 .. Members then Name_Of (V.Owner) & "'s" else "nobody's") & ": "
                    & (case V.Phase is
                          when Ground => "the ground", when Flooring => "the floor", when Framing => "the frame",
                          when Walling => "the walls",
                          when Roofing | Standing => "the roof")
                    & " " & Img (Integer (100.0 * Float (V.Placed) / Float (Integer'Max (1, V.Blocks)))) & " %, wood "
                    & Img (V.Got (Wood)) & " of " & Img (V.Takes (Wood)) & ", straw " & Img (V.Got (Straw)) & " of "
                    & Img (V.Takes (Straw))
                    & (if V.Builder in 1 .. Members then ", built by " & Name_Of (V.Builder) else ", no builder")
                    & (case V.Waits is
                          when Not_Waiting | For_A_Builder => "", when For_Wood => ", waits for wood",
                          when For_Straw => ", waits for straw", when For_A_Way => ", no way to it"))
              & From (H + 1);
         end;
      end From;
   begin
      if House_Count = 0 and then not (for some Z in 1 .. Zone_Count => Zone_At (Z).Kind = Habitation_Zone) then
         return "";
      end if;
      for H in 1 .. House_Count loop
         if House_At (H).Phase = Standing then
            Standing_N := Standing_N + 1;
         else
            Building_N := Building_N + 1;
         end if;
      end loop;
      for I in 1 .. Members loop
         if At_Home (I) then
            Home_N := Home_N + 1;
         end if;
      end loop;
      return "housing:" & Standing_N'Image & " standing," & Building_N'Image & " being built," & Homeless'Image
        & " without a home," & Home_N'Image & " at home" & From (1);
   end Housing_Line;

   function Resting_N return Natural is
      N : Natural := 0;
   begin
      for I in 1 .. Members loop
         if Person (I).Resting then
            N := N + 1;
         end if;
      end loop;
      return N;
   end Resting_N;

   function Demand_Line return String is
      F : constant Good_View := Food_Demand;
      function Days (Points : Natural) return String is
        (Img ((if F.A_Day > 0 then Float (Points) / Float (F.A_Day) else 0.0), 1));
      function From (K : Item_Kind) return String is
         G : constant Good_View := Demand_For (K);
      begin
         return (if G.High > 0
                 then "; " & Name (K) & " " & Img (G.Have) & " of " & Img (G.High)
                      & (if G.Asked then (if G.Makers = 0 then ", asked of nobody" else ", asked") else "")
                 else "")
           & (if K = Item_Kind'Last then "" else From (Item_Kind'Succ (K)));
      end From;
   begin
      return "demand: food " & Days (F.Have) & " of " & Days (F.High) & " days"
        & (if F.Asked then (if F.Makers = 0 then ", asked of nobody" else ", asked") else "")
        & From (Item_Kind'First) & ";" & Resting_N'Image & " at rest";
   end Demand_Line;

   function Skills_Line return String is
      function From (S : Skill_Kind) return String is
         Sum : Float := 0.0;
         N   : Natural := 0;
      begin
         for I in 1 .. Members loop
            if not Dead (I) and then Has_Skill (Job_Of (I)) and then Job_Skill (Job_Of (I)) = S then
               Sum := Sum + Skill_Of (I, S);
               N := N + 1;
            end if;
         end loop;
         return (if N = 0 then "" else " " & Name (S) & " " & Img (Sum / Float (N), 2) & " (" & Img (N) & ")")
           & (if S = Working_Skill'Last then "" else From (Skill_Kind'Succ (S)));
      end From;
   begin
      return "skills:" & From (Working_Skill'First);
   end Skills_Line;

   function Food_Line (Hours : Long_Float) return String is
      Min_Fed  : Float := 1.0;
      Sum_Fed  : Float := 0.0;
      Hungry_N, Cold_N : Natural := 0;
      H : constant Float := Castle.Climate.Hour_Of_Day (Castle.Climate.Game_Hours (Hours));
   begin
      for I in 1 .. Members loop
         if not Dead (I) then
            Min_Fed := Float'Min (Min_Fed, Fed_Of (I));
            Sum_Fed := Sum_Fed + Fed_Of (I);
         end if;
         if Hungry (I) then
            Hungry_N := Hungry_N + 1;
         end if;
         if Cold (I) then
            Cold_N := Cold_N + 1;
         end if;
      end loop;
      return "food: day"
        & Integer (Float'Floor (Castle.Climate.Day_Of_Year (Castle.Climate.Game_Hours (Hours))))'Image & " "
        & Img (H, 1) & " h: " & Living'Image & " living, confidence" & Integer (100.0 * Confidence)'Image
        & " %, fed " & Img (100.0 * Min_Fed, 0) & "/"
        & Img (100.0 * Sum_Fed / Float'Max (1.0, Float (Living)), 0)
        & " %, hungry" & Hungry_N'Image & ", cold" & Cold_N'Image & ", eaten" & Eaten'Image & ", cooked" & Cooked'Image
        & ", stew" & Camp_State.Stew'Image & ", days " & Img (Food_Days, 2) & " (held " & Img (Store_Held_Days, 1)
        & "), deer" & Deer_Alive'Image & ", burnt" & Camp_State.Burnt'Image
        & "; stored meat" & Stored (Meat)'Image & ", veg" & Stored (Vegetables)'Image & ", berries"
        & Stored (Berries)'Image & ", apples" & Stored (Apples)'Image & ", grain" & Stored (Grain)'Image
        & ", logs" & Stored (Wood)'Image
        & "; in the pot meat" & Put_In_Pot (Meat)'Image & ", veg" & Put_In_Pot (Vegetables)'Image
        & ", berries" & Put_In_Pot (Berries)'Image & ", apples" & Put_In_Pot (Apples)'Image
        & ", grain" & Put_In_Pot (Grain)'Image
        & "; raw" & Natural'Image (Eaten_Raw (Berries) + Eaten_Raw (Vegetables) + Eaten_Raw (Apples))
        & "; kills" & Kills'Image & ", pulled" & Vegetables_Pulled'Image & ", berries left" & Berries_Left'Image
        & ", apples left" & Apples_Left'Image
        & (if Demand_Chain
           then "; asked:" & (if Food_Demand.Asked then " food" else "")
                & (if Demand_For (Meat).Asked then " meat" else "")
                & (if Demand_For (Vegetables).Asked then " vegetables" else "")
                & (if Demand_For (Wood).Asked then " wood" else "")
                & (if Demand_For (Straw).Asked then " straw" else "")
                & (if Demand_For (Stone).Asked then " stone" else "")
                & ", at rest" & Resting_N'Image
           else "")
        & (if Has_Camp and then not Camp_State.Built
           then "; camp to build: ground" & Camp_State.Ground_Left'Image & ", stone" & Camp_State.Stones'Image
                & ", wood" & Camp_State.Frame'Image
                & (if Camp_State.To_Dig + Camp_State.To_Fill > 0
                   then ", to dig" & Camp_State.To_Dig'Image & ", to fill" & Camp_State.To_Fill'Image else "")
           else "")
        & (if Looking_M > 0.0 then "; looking as far as " & Img (Looking_M, 0) & " m" else "")
        & (if Paths_To_Lay > 0 then "; path to lay:" & Paths_To_Lay'Image & " m" else "")
        & (if Housing_Line /= "" then "; " & Housing_Line else "")
        & (if Labour and then At_Extra > 0 and then Extra_Hands < Members      --  (while there is a limit)
           then "; at extra tasks" & At_Extra'Image & " (of" & Extra_Hands'Image & " at most)" else "");
   end Food_Line;

end Castle.Scenario;
