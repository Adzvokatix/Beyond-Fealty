with Ada.Command_Line; use Ada.Command_Line;
with Ada.Numerics.Elementary_Functions;
with Ada.Strings.Unbounded;
with Ada.Text_IO;      use Ada.Text_IO;
with Castle.Actions;
with Castle.Climate;
with Castle.Herds;
with Castle.Math;      use Castle.Math;
with Castle.Nav;
with Castle.Text;      use Castle.Text;
with Castle.Buildings;

package body Castle.Scenario is

   use Castle.Colony;
   use type Castle.Buildings.Building_Kind;

   function Parse (S : in out Setup; I : in out Positive) return Boolean is
      function Arg (K : Natural) return String is (Argument (I + K));
      A : constant String := Arg (0);
   begin
      if A = "--stake" then
         S.Stake := True;
         S.Stake_X := Float'Value (Arg (1));
         S.Stake_Y := Float'Value (Arg (2));
         I := I + 3;
      elsif A = "--square" then
         S.Stake := True;
         S.As_Square := True;
         S.Stake_X := Float'Value (Arg (1));
         S.Stake_Y := Float'Value (Arg (2));
         S.Square_Way := Natural'Value (Arg (3)) mod 8;
         I := I + 4;
      elsif A = "--square-10" then
         Castle.Colony.Set_Square_Wide (False);    --  (a square founded ten metres, twelve with its path, as it first was)
         I := I + 1;
      elsif A = "--square-walls-inside" then
         Castle.Colony.Set_Square_Outside (False);  --  (a square's walls on its own outermost quarter metre, its path
         I := I + 1;                                --  a fixed ring, as squares were until 2026-11-21)
      elsif A = "--no-corner-whole" then
         Castle.Colony.Set_Corner_Whole (False);   --  (the square metre where two sides' paths cross laid a quarter
         I := I + 1;                               --  metre of each side's at a time, as before 2026-11-22, later)
      elsif A = "--no-corner-steps" then
         Castle.Colony.Set_Corner_Steps (False);   --  (no step of stone where two sides' paths cross, as before
         I := I + 1;                               --  2026-11-22, later)
      elsif A = "--no-strip-wait" then
         Castle.Colony.Set_Strip_Wait (False);     --  (a column of two sides' strips walled by whichever side's path
         I := I + 1;                               --  is laid first, as before 2026-11-22, later)
      elsif A = "--no-line-ground" then
         Castle.Colony.Set_Line_Ground (False);    --  (a planned line's end under a tree at the height of the bough
         I := I + 1;                               --  over it, as before 2026-11-22, later)
      elsif A = "--no-path-steps" then
         Castle.Colony.Set_Path_Steps (False);     --  (the square's path left to step half a metre and more where a
         I := I + 1;                               --  levelled stretch of it ends, as before 2026-11-22)
      elsif A = "--no-square-walls" then
         Castle.Colony.Set_Square_Walls (False);   --  (a square's banks left earth, as they first were)
         I := I + 1;
      elsif A = "--yard-stair-middle" then
         Castle.Colony.Set_Yard_Stair_Corner (False);     --  (a stockyard's stair at the middle of its storehouse's
         I := I + 1;                                      --  front, as before the evening of 2026-11-21)
      elsif A = "--yard-floor-by-land" then
         Castle.Colony.Set_Yard_Floor_Low (False);        --  (a stockyard's floor chosen from the land under it, as
         I := I + 1;                                      --  before 2026-11-22; its stair in a corner all the same)
      elsif A = "--square-stair-corner" then
         Castle.Colony.Set_Square_Stair_Corner (True);    --  (a square's stair at an end of its side, in a corner of
         I := I + 1;                                      --  the zone: built 2026-11-21 on a misreading, kept off)
      elsif A = "--square-stair-middle" then
         Castle.Colony.Set_Square_Stair_Corner (False);   --  (a square's stair at the middle of its side: as it is
         I := I + 1;                                      --  unless told otherwise; kept, he was given this word)
      elsif A = "--no-path-through" then
         Castle.Colony.Set_Path_Through (False);   --  (a path through housing refused, as before)
         I := I + 1;
      elsif A = "--no-metre-ground" then
         Castle.Colony.Set_Metre_Ground (False);   --  (a metre of path gone to on the first floor there, as before)
         I := I + 1;
      elsif A = "--no-box-fell" then
         Castle.Colony.Set_Box_Fell (False);       --  (a tree in a stockpile leaves places out, as before)
         I := I + 1;
      elsif A = "--no-square-fell" then
         Castle.Colony.Set_Square_Fell (False);    --  (a tree on the square left standing, as it first was)
         I := I + 1;
      elsif A = "--no-square" then
         Castle.Actions.Square_Stake := False;     --  (at once: it is how the player's own order is made)
         I := I + 1;
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
      elsif A = "--stockpile-box" then
         if S.Box_N < S.Boxes'Last (1) then
            S.Box_N := S.Box_N + 1;
            for K in 1 .. 3 loop
               S.Boxes (S.Box_N, K) := Float'Value (Arg (K));
            end loop;
         end if;
         I := I + 4;
      elsif A = "--no-fire-ground" then
         Castle.Colony.Set_Fire_Ground (False);    --  (a square founded as it was: its stake looked for near the
         I := I + 1;                               --  highest floor at its middle)
      elsif A = "--no-box-place" then
         S.No_Box_Place := True;
         Castle.Colony.Set_Box_Place (False);      --  (at once too: a colony the player founds by hand is not scripted)
         I := I + 1;
      elsif A = "--housing" then
         if S.Housing_N < S.Housing'Last (1) then
            S.Housing_N := S.Housing_N + 1;
            for K in 1 .. 4 loop
               S.Housing (S.Housing_N, K) := Float'Value (Arg (K));
            end loop;
         end if;
         I := I + 5;
      elsif A = "--housing-pull" then
         if S.Pull_N < S.Pulls'Last (1) then
            S.Pull_N := S.Pull_N + 1;
            for K in 1 .. 5 loop
               S.Pulls (S.Pull_N, K) := Float'Value (Arg (K));
            end loop;
         end if;
         I := I + 6;
      elsif A = "--no-housing-pull" then
         Castle.Actions.Housing_Pull := False;     --  (at once: it is how the player's own order is made)
         I := I + 1;
      elsif A = "--housing-inside" then
         if S.Inside_N < S.Inside'Last (1) then
            S.Inside_N := S.Inside_N + 1;
            for K in 1 .. 2 loop
               S.Inside (S.Inside_N, K) := Float'Value (Arg (K));
            end loop;
         end if;
         I := I + 3;
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
      elsif A = "--no-beds" then
         S.No_Beds := True; I := I + 1;
      elsif A = "--no-cook-hold" then
         S.No_Cook_Hold := True; I := I + 1;
      elsif A = "--no-curing" then
         S.No_Curing := True; I := I + 1;
      elsif A = "--no-ladders" then
         S.No_Ladders := True; I := I + 1;
      elsif A = "--no-path-holes" then
         S.No_Path_Holes := True; I := I + 1;
      elsif A = "--no-cart-pull" then
         S.No_Cart_Pull := True; I := I + 1;
      elsif A = "--builders" then
         S.Builders := Natural'Value (Arg (1)); I := I + 2;
      elsif A = "--stockpile-least" then
         S.Stockpile_Least := Float'Value (Arg (1)); I := I + 2;
      elsif A = "--no-overflow" then        --  (as it is now: kept for the scripts that say it)
         S.No_Overflow := True; I := I + 1;
      elsif A = "--overflow" then
         S.Overflow := True; I := I + 1;
      elsif A = "--last-places" then
         S.Last_Places := Integer'Value (Arg (1)); I := I + 2;
      elsif A = "--no-storehouse" then
         S.No_Storehouse := True; I := I + 1;
      elsif A = "--no-stockman" then
         S.No_Stockman := True; I := I + 1;
      elsif A = "--no-carpenter" then
         S.No_Carpenter := True; I := I + 1;
      elsif A = "--no-water" then
         S.No_Water := True; I := I + 1;
      elsif A = "--no-top-cut" then
         S.No_Top_Cut := True; I := I + 1;
      elsif A = "--storehouse" then
         --  (LONG DEEP STAGING, metres: 12 8 1.5 unless said; 10 5 4.5 is the storehouse of before
         --  2026-11-21.  Set at once: it speaks of the storehouse begun from now on, in a colony the
         --  player founds by hand too.)
         Castle.Colony.Set_Store_Size (Long_B    => Positive (Float'Rounding (Float'Value (Arg (1)) * 4.0)),
                                       Deep_B    => Positive (Float'Rounding (Float'Value (Arg (2)) * 4.0)),
                                       Staging_B => Positive (Float'Rounding (Float'Value (Arg (3)) * 4.0)));
         I := I + 4;
      elsif A = "--one-cart-place" then
         Castle.Colony.Set_Cart_Search (False);     --  (the cart's one place before the storehouse, as it was)
         I := I + 1;
      elsif A = "--no-store-stacks" then
         Castle.Colony.Set_Store_Stacks (False);    --  (a place in the storehouse its own, one barrel to a place)
         I := I + 1;
      elsif A = "--stockyard-box" then
         S.Yard_Box := True;
         for K in 1 .. 3 loop
            S.Yard_Box_At (1, K) := Float'Value (Arg (K));
         end loop;
         I := I + 4;
      elsif A = "--no-yard-box" then
         S.No_Yard_Box := True;
         Castle.Colony.Set_Yard_Box (False);       --  (at once too: a colony the player founds by hand is not scripted)
         I := I + 1;
      elsif A = "--stockyard" then
         S.Yard := True;
         for K in 1 .. 4 loop
            S.Yard_At (1, K) := Float'Value (Arg (K));
         end loop;
         I := I + 5;
      elsif A = "--no-yard-level" then
         S.No_Yard_Level := True; I := I + 1;
      elsif A = "--set-builders" then
         S.Set_Builders := Natural'Value (Arg (1)); I := I + 2;
      elsif A = "--name-stockman" then
         S.Name_Stockman := Natural'Value (Arg (1)); I := I + 2;
      elsif A = "--name-carpenter" then
         S.Name_Carpenter := Natural'Value (Arg (1)); I := I + 2;
      elsif A = "--no-roof-timbers" then
         S.No_Roof_Timbers := True; I := I + 1;
      elsif A = "--no-window-timber" then
         S.No_Window_Timber := True; I := I + 1;
      elsif A = "--no-path-level" then
         S.No_Path_Level := True; I := I + 1;
      elsif A = "--no-make-way" then
         S.No_Make_Way := True; I := I + 1;
      elsif A = "--no-reach-out" then
         S.No_Reach_Out := True; I := I + 1;
         Castle.Colony.Set_Reach_Out (False);          --  (where it is read: a game founded by hand obeys it too)
      elsif A = "--no-zigzag" then
         S.No_Zigzag := True; I := I + 1;
         Castle.Colony.Set_Zigzag (False);          --  (where it is read: a game founded by hand obeys it too)
      elsif A = "--no-paths-meet" then
         S.No_Paths_Meet := True; I := I + 1;
         Castle.Colony.Set_Paths_Meet (False);          --  (where it is read: a game founded by hand obeys it too)
      elsif A = "--no-door-meet" then
         S.No_Door_Meet := True; I := I + 1;
         Castle.Colony.Set_Door_Meet (False);
      elsif A = "--no-kill-home" then
         S.No_Kill_Home := True; I := I + 1;
         Castle.Colony.Set_Kill_Home (False);
      elsif A = "--no-full-truss" then
         S.No_Full_Truss := True; I := I + 1;
      elsif A = "--no-build-help" then
         S.No_Build_Help := True; I := I + 1;
         Castle.Colony.Set_Build_Help (False);
      elsif A = "--no-place-level" then
         S.No_Place_Level := True; I := I + 1;
         Castle.Colony.Set_Place_Level (False);
      elsif A = "--no-cart-room" then
         S.No_Cart_Room := True; I := I + 1;
         Castle.Colony.Set_Cart_Room (False);
      elsif A = "--no-step-at-edge" then
         S.No_Step_At_Edge := True; I := I + 1;
         Castle.Colony.Set_Step_At_Edge (False);
      elsif A = "--pile-flat" then
         S.Pile_Flat := True; I := I + 1;
         Castle.Colony.Set_Pile_Flat (True);
      elsif A = "--no-steep-refuse" then
         S.No_Steep_Refuse := True; I := I + 1;
         Castle.Colony.Set_Steep_Refuse (False);
      elsif A = "--wood-from" then
         S.Wood_From := Float'Value (Arg (1)); I := I + 2;
      elsif A = "--no-house-turn" then
         S.No_House_Turn := True; I := I + 1;
      elsif A = "--no-turn-ground" then
         S.No_Turn_Ground := True; I := I + 1;
      elsif A = "--no-keep-off" then
         S.No_Keep_Off := True; I := I + 1;
      elsif A = "--turn-fall" then
         S.Turn_Fall := True; I := I + 1;
      elsif A = "--no-ways-told" then
         S.No_Ways_Told := True; I := I + 1;
      elsif A = "--no-yard-turn" then
         S.No_Yard_Turn := True; I := I + 1;
      elsif A = "--no-hovel-walk" then
         S.No_Hovel_Walk := True; I := I + 1;
      elsif A = "--no-smooth-covers" then
         S.No_Smooth_Covers := True; I := I + 1;
      elsif A = "--no-fence-pieces" then
         S.No_Fence_Pieces := True; I := I + 1;
      elsif A = "--one-stockpile" then
         S.One_Stockpile := True; I := I + 1;
      elsif A = "--stores-move" then
         S.Stores_Move := True; I := I + 1;
      elsif A = "--no-path-snap" then
         S.No_Path_Snap := True; I := I + 1;
         Castle.Actions.Path_Snap := False;       --  (at once: a game that loads a save founds nothing)
      elsif A = "--no-wood-reach" then
         S.No_Wood_Reach := True; I := I + 1;
      elsif A = "--stockpile-stays" then
         S.Stockpile_Stays := True; I := I + 1;
      elsif A = "--one-to-a-bush" then
         S.One_To_A_Bush := True; I := I + 1;
      elsif A = "--cart-salt" then
         S.Cart_Salt := Integer'Value (Arg (1)); I := I + 2;
      elsif A = "--pace" then
         S.Pace := Float'Value (Arg (1)); I := I + 2;
      elsif A = "--deer-scatter" then
         S.Deer_Scatter := True; I := I + 1;
      elsif A = "--herds-anywhere" then
         S.Herds_Anywhere := True; I := I + 1;
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
      Flat_0 : Natural := 0;        --  (the stockpiles made one level before an order: what it made flat is said)
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
      Castle.Herds.Set_Walk_Off (not S.Herds_Anywhere);
      Set_Arrivals (S.Band, Castle.Hash.Derive (Seed, 7));
      Set_Curing (not S.No_Curing);                  --  (before the stake: the cart comes with the band)
      if S.Cart_Salt >= 0 then
         Set_Cart_Salt (S.Cart_Salt);
      end if;
      Order_It ((What => Raise_Stake, By => The_Player, Stake_At => P, As_Square => S.As_Square,
                 Stake_Way => S.Square_Way));
      if S.As_Square then
         Put_Line (if Has_Stake
                   then "the colony founded on a square: its middle at " & Img (Stake.X, 2) & ", " & Img (Stake.Y, 2)
                        & (if S.Square_Way mod 2 = 0 then ", squarely" else ", aslant") & ";"
                        & Natural'Image (Zone_At (Camp_Zone).Blocks) & " block columns of floor"
                        & (if Camp_State.Floor_Z >= 0.0
                           then ", to be level at " & Img (Camp_State.Floor_Z, 2) & " m (" & Img (Camp_State.To_Dig)
                                & " blocks of earth to dig off, " & Img (Camp_State.To_Fill) & " to fill)"
                           else "")
                        & "; a path round it," & Natural'Image (Paths_To_Lay) & " m to lay"
                   else "the square refused: " & Square_Refusal);
      end if;
      Set_Stone_From (S.Stone_From);
      Set_Wood_From (S.Wood_From);
      Set_Levelling (not S.No_Level);
      Set_Beds (not S.No_Beds);
      Set_Cook_Hold (not S.No_Cook_Hold);
      Set_Ladders (not S.No_Ladders);
      Set_Path_Holes (not S.No_Path_Holes);
      Set_Cart_Pull (not S.No_Cart_Pull);
      if S.Builders >= 0 then
         Set_Builders (S.Builders);
      end if;
      if S.Stockpile_Least >= 0.0 then
         Set_Stockpile_Least (S.Stockpile_Least);
      end if;
      Set_Overflow (S.Overflow and then not S.No_Overflow);
      if S.Last_Places >= 0 then
         Set_Last_Places (S.Last_Places);
      end if;
      Set_Storehouse (not S.No_Storehouse);
      Set_Stockman (not S.No_Stockman);
      Set_Carpenter (not S.No_Carpenter);
      Set_Water (not S.No_Water);
      Set_Top_Cut (not S.No_Top_Cut);
      Set_Bush_Sharing (not S.One_To_A_Bush);
      Set_Yard_Level (not S.No_Yard_Level);
      Set_Stores_Move (S.Stores_Move and then not S.Stockpile_Stays);   --  (--stockpile-stays: the default since 2026-11-19)
      Set_One_Stockpile (S.One_Stockpile);
      Set_Box_Place (not S.No_Box_Place);
      Set_Yard_Box (not S.No_Yard_Box);
      Set_Make_Way (not S.No_Make_Way);
      Set_Reach_Out (not S.No_Reach_Out);
      Set_Zigzag (not S.No_Zigzag);
      Set_Paths_Meet (not S.No_Paths_Meet);
      Set_Door_Meet (not S.No_Door_Meet);
      Set_Kill_Home (not S.No_Kill_Home);
      Set_Wood_Reach (not S.No_Wood_Reach);
      Set_House_Turn (not S.No_House_Turn);
      Set_Turn_Ground (not S.No_Turn_Ground);
      Set_Keep_Off (not S.No_Keep_Off);
      Set_Turn_Fall (S.Turn_Fall);
      Set_Ways_Told (not S.No_Ways_Told);
      Set_Yard_Turn (not S.No_Yard_Turn);
      Set_Hovel_Walk (not S.No_Hovel_Walk);
      Set_Smooth_Covers (not S.No_Smooth_Covers);
      Set_Fence_Pieces (not S.No_Fence_Pieces);
      Castle.Actions.Path_Snap := not S.No_Path_Snap;     --  (how a path's line is read when it is ordered)
      Set_Path_Level (not S.No_Path_Level);
      Set_Roof_Timbers (not S.No_Roof_Timbers);
      Set_Full_Truss (not S.No_Full_Truss);
      Set_Build_Help (not S.No_Build_Help);
      Set_Place_Level (not S.No_Place_Level);
      Set_Cart_Room (not S.No_Cart_Room);
      Set_Step_At_Edge (not S.No_Step_At_Edge);
      Set_Pile_Flat (S.Pile_Flat);
      Set_Steep_Refuse (not S.No_Steep_Refuse);
      Set_Window_Timber (not S.No_Window_Timber);
      if S.Pace > 0.0 then
         Set_Pace (S.Pace);
      end if;
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
         Flat_0 := Piles_Flattened;
         Order_It ((What => Zone_Stockpile, By => The_Player, X0 => S.Piles (K, 1), Y0 => S.Piles (K, 2),
                    X1 => S.Piles (K, 3), Y1 => S.Piles (K, 4)));
         declare
            Over : Natural := 0;               --  (of those, its overflow's)
         begin
            for C in Cell_Count - R.Count + 1 .. Cell_Count loop
               if Cell_At (C).Overflow then
                  Over := Over + 1;
               end if;
            end loop;
            Put_Line (if R.Count = 0 then "stockpile refused: " & Stockpile_Refusal
                      else "stockpile zoned:" & Natural'Image (R.Count - Over) & " cells"
                           & (if Over > 0 then " and" & Over'Image & " for its overflow round it" else ""));
            if Piles_Flattened > Flat_0 then
               Put_Line ("stockpile " & Last_Flat_Said);
            end if;
         end;
      end loop;
      for K in 1 .. S.Box_N loop
         declare
            Way : constant Way_Index := Natural (S.Boxes (K, 3)) mod 8;
            Mid : constant Vec3 := At_Ground (S.Boxes (K, 1), S.Boxes (K, 2));
            Plan : constant Box_Plan := Plan_Box (Stockpile_Box, Mid, Way);
         begin
            --  (through the colony's own routine, whatever Set_Box_Place says of the player's tool)
            Flat_0 := Piles_Flattened;
            Place_Box (Stockpile_Box, Mid, Way, R.Count);
            Put_Line (if R.Count = 0 then "stockpile refused: " & Box_Refusal
                      else "stockpile put down:" & R.Count'Image & " cells; its path from "
                           & Img (Plan.Where.From.X, 2) & ", " & Img (Plan.Where.From.Y, 2) & " to "
                           & Img (Plan.Where.To.X, 2) & ", " & Img (Plan.Where.To.Y, 2) & ", "
                           & Img (Plan.New_Path_M, 2) & " m of it new ("
                           & (case Plan.Where.Snap is
                                 when Free => "held free", when Along_Path => "along a path",
                                 when At_End => "at a path's end", when At_Middle => "at a path's middle") & ")");
            if Piles_Flattened > Flat_0 then
               Put_Line ("stockpile " & Last_Flat_Said);
            end if;
         end;
      end loop;
      if S.Yard_Box then
         declare
            Way : constant Way_Index := Natural (S.Yard_Box_At (1, 3)) mod 8;
            Mid : constant Vec3 := At_Ground (S.Yard_Box_At (1, 1), S.Yard_Box_At (1, 2));
            Plan : constant Box_Plan := Plan_Box (Stockyard_Box, Mid, Way);
         begin
            --  (through the colony's own routine, whatever Set_Yard_Box says of the player's tool)
            Place_Box (Stockyard_Box, Mid, Way, R.Count);
            Put_Line (if R.Count = 0 then "stockyard refused: " & Box_Refusal
                      else "stockyard put down:" & R.Count'Image & " places, closed until its storehouse stands; its path from "
                           & Img (Plan.Where.From.X, 2) & ", " & Img (Plan.Where.From.Y, 2) & " to "
                           & Img (Plan.Where.To.X, 2) & ", " & Img (Plan.Where.To.Y, 2) & ", "
                           & Img (Plan.New_Path_M, 2) & " m of it new ("
                           & (case Plan.Where.Snap is
                                 when Free => "held free", when Along_Path => "along a path",
                                 when At_End => "at a path's end", when At_Middle => "at a path's middle") & ")"
                           & (if Plan.Lot.Ok then "" else "; ITS PLAN SAID NO"));
            if R.Count = 0 and then Plan.Lot.Ok then
               Put_Line ("stockyard: ITS PLAN SAID YES");
            end if;
         end;
      end if;
      if (S.Box_N > 0 or else S.Yard_Box) and then S.Paths_Built and then Paths_To_Lay > 0 then
         Build_Paths_Now;
         Put_Line ("their paths laid");
      end if;
      if S.Yard then
         Order_It ((What => Zone_Stockyard, By => The_Player, X0 => S.Yard_At (1, 1), Y0 => S.Yard_At (1, 2),
                    X1 => S.Yard_At (1, 3), Y1 => S.Yard_At (1, 4)));
         Put_Line (if R.Count = 0 then "stockyard refused: " & Stockyard_Refusal
                   else "stockyard zoned:" & R.Count'Image & " places, closed until its storehouse stands");
      end if;
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
         Put_Line (if not R.Done then "housing refused: " & Housing_Refusal
                   else (if Housing_Joined > 0 then "housing extended: room for" else "housing zoned: room for")
                        & R.Count'Image & (if R.Count = 1 then " hovel" else " hovels")
                        & (if Housing_Joined > 0 then " now" else ""));
      end loop;
      for K in 1 .. S.Pull_N loop
         declare
            Begun : constant Vec3 := At_Ground (S.Pulls (K, 1), S.Pulls (K, 2));
            To_P  : constant Vec3 := At_Ground (S.Pulls (K, 3), S.Pulls (K, 4));
            Rows  : constant Pull_Rows := Pull_Rows'Val (Natural (S.Pulls (K, 5)) mod 3);
            Line  : constant Pull_View := Pull_Line (Begun, To_P);
         begin
            Order_It ((What => Pull_Housing, By => The_Player, Begun => Begun, Pulled_To => To_P, Rows => Rows));
            Put_Line (if not R.Done then "housing pull refused: " & Pull_Refusal
                      else "housing pulled " & (if Line.Along_Path then "along a path" else "with a line of its own")
                           & " from " & Img (Line.From.X, 2) & ", " & Img (Line.From.Y, 2) & " to "
                           & Img (Line.To.X, 2) & ", " & Img (Line.To.Y, 2) & ": " & Img (Pull_Path_M, 2)
                           & " m of path new," & Natural'Image (Pull_Rows_Zoned)
                           & (if Pull_Rows_Zoned = 1 then " row" else " rows") & " zoned, room for"
                           & R.Count'Image & (if R.Count = 1 then " hovel" else " hovels")
                           & (if Pull_Gave_Way > 0
                              then ";" & Natural'Image (Pull_Gave_Way) & " block columns of housing gave way under it"
                              else ""));
         end;
      end loop;
      for K in 1 .. S.Inside_N loop
         Order_It ((What => Fill_Housing, By => The_Player, Inside => (S.Inside (K, 1), S.Inside (K, 2), 0.0)));
         Put_Line (if not R.Done then "housing refused: " & Housing_Refusal
                   else (if Housing_Joined > 0 then "housing extended: room for" else "housing zoned: room for")
                        & R.Count'Image & (if R.Count = 1 then " hovel" else " hovels")
                        & (if Housing_Joined > 0 then " now" else ""));
      end loop;
      if S.Homes_Built and then S.Housing_N + S.Inside_N + S.Pull_N > 0 then
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
      declare                                        --  (and the first of the foresters set to building)
         Left : Natural := S.Set_Builders;
      begin
         for I in 1 .. Members loop
            if Left > 0 and then Job_Of (I) = Forester then
               Order_It ((What => Make_Builder, By => The_Player, Whom => I, Job => Forester));
               Left := Left - 1;
            end if;
         end loop;
      end;
      if S.Name_Stockman in 1 .. Members then        --  (and the stockman and the carpenter named by hand)
         Order_It ((What => Make_Stockman, By => The_Player, Whom => S.Name_Stockman, Job => Porter));
      end if;
      if S.Name_Carpenter in 1 .. Members then
         Order_It ((What => Make_Carpenter, By => The_Player, Whom => S.Name_Carpenter, Job => Forester));
      end if;
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
                   & Castle.Bodies.Describe (Genome_Of (I), (Job => Body_Job (Job_Of (I)), Winter => False, Cloak_Off => False))
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
      if Storehouse_Line /= "" then
         Put_Line (Storehouse_Line);
      end if;
      if Beds_Line /= "" then
         Put_Line (Beds_Line);
      end if;
      if Cart_Line /= "" then
         Put_Line (Cart_Line);
      end if;
      if Ladders_Line /= "" then
         Put_Line (Ladders_Line);
      end if;
   end Put_Report;

   --  Ladders ("": none has been made).
   function Ladders_Line return String is
      Carried_N : Natural := 0;
   begin
      if Ladders_Made = 0 then
         return "";
      end if;
      for I in 1 .. Members loop
         if Carrying (I) = Ladder then
            Carried_N := Carried_N + Carried (I);
         end if;
      end loop;
      return "ladders:" & Ladders_Made'Image & " made," & Ladders_Standing'Image & " standing at a house,"
        & Stored (Ladder)'Image & " stored," & Carried_N'Image & " carried," & Ladders_Lost'Image & " lost";
   end Ladders_Line;

   --  The lord's cart and the salt ("": no curing, or no stake yet).
   function Cart_Line return String is
   begin
      if not Curing or else not Has_Stake then
         return "";
      end if;
      return "salt:" & (if Cart.Here then Cart.Salt'Image & " lb in the cart" else " no cart") & ","
        & Stored (Salt)'Image & " stored;" & Deer_Salted'Image & " deer salted," & Deer_Unsalted'Image
        & " not," & Meat_Lost'Image & " lb of meat lost"
        & (if Cart_Pull and then Cart.Here
           then "; the cart " & (if Cart.Towed then "in tow by " & Name_Of (Cart.By)
                                 elsif Cart_In_Stockpile then "in a stockpile" else "where it stood")
           else "");
   end Cart_Line;

   --  Beds: who of the living has one where it sleeps, and the straw in
   --  them all ("": nobody makes beds, or there is no camp yet).
   function Beds_Line return String is
      Have : Natural := 0;
      --  whoever has none where it sleeps, once the camp stands, and what it is at
      function Without (I : Positive) return String is
        (if I > Members then ""
         else (if not Dead (I) and then not Has_Bed (I) then "; without one: " & Name_Of (I) & " (" & Status (I) & ")" else "")
              & Without (I + 1));
   begin
      if not Beds or else not Has_Camp then
         return "";
      end if;
      for I in 1 .. Members loop
         if not Dead (I) and then Has_Bed (I) then
            Have := Have + 1;
         end if;
      end loop;
      return "beds:" & Have'Image & " of" & Living'Image & " have one," & Straw_In_Beds'Image & " sheaves in them"
        & (if Camp_State.Built then Without (1) else "");
   end Beds_Line;

   function Housing_Line return String is
      Standing_N, Building_N, Home_N, Razing_N : Natural := 0;
      function From (H : Positive) return String is
      begin
         if H > House_Count then
            return "";
         end if;
         declare
            V : constant House_View := House_At (H);
         begin
            return
              (if V.Phase = Standing or else V.Kind /= Castle.Buildings.Hovel then ""
               elsif V.Marked
               then "; a hovel being taken down: " & Img (V.Placed) & " of " & Img (V.Blocks) & " blocks left"
                    & (if V.Builder in 1 .. Members then ", by " & Name_Of (V.Builder) else ", no builder") & From (H + 1)
               else "; a hovel: "
                    & (case V.Phase is
                          when Ground => "the ground", when Flooring => "the floor", when Framing => "the frame",
                          when Walling => "the walls",
                          when Roofing => "the roof", when Trimming | Yard | Standing => "the roof's trimming")
                    & " " & Img (Integer (100.0 * Float (V.Placed) / Float (Integer'Max (1, V.Blocks)))) & " %, wood "
                    & Img (V.Got (Wood)) & " of " & Img (V.Takes (Wood)) & ", straw " & Img (V.Got (Straw)) & " of "
                    & Img (V.Takes (Straw))
                    & (if V.Takes (Stone) > 0 then ", stone " & Img (V.Got (Stone)) & " of " & Img (V.Takes (Stone)) else "")
                    & (if V.Builder in 1 .. Members then ", built by " & Name_Of (V.Builder) else ", no builder")
                    & (case V.Waits is
                          when Not_Waiting | For_A_Builder => "", when For_Wood => ", waits for wood",
                          when For_Straw => ", waits for straw", when For_A_Way => ", no way to it",
                          when For_Stone => ", waits for stone"))
              & From (H + 1);
         end;
      end From;
      --  with some at home, whoever has a home and is not in it, and what it is at
      function Away (I : Positive) return String is
        (if I > Members then ""
         else (if Housed (I) and then not Dead (I) and then not At_Home (I)
               then "; not at home: " & Name_Of (I) & " (" & Status (I) & ")" else "")
              & Away (I + 1));
   begin
      if (for all H in 1 .. House_Count => House_At (H).Kind /= Castle.Buildings.Hovel)
        and then not (for some Z in 1 .. Zone_Count => Zone_At (Z).Kind = Habitation_Zone)
      then
         return "";
      end if;
      for H in 1 .. House_Count loop
         if House_At (H).Kind /= Castle.Buildings.Hovel then
            null;                                  --  (the storehouse: its own line)
         elsif House_At (H).Phase = Standing then
            Standing_N := Standing_N + 1;
         elsif House_At (H).Marked then
            Razing_N := Razing_N + 1;              --  (nobody's, coming down: not one being built)
         else
            Building_N := Building_N + 1;
         end if;
      end loop;
      for I in 1 .. Members loop
         if At_Home (I) then
            Home_N := Home_N + 1;
         end if;
      end loop;
      return "housing:" & Standing_N'Image & " standing," & Building_N'Image & " being built,"
        & (if Razing_N > 0 then Razing_N'Image & " being taken down," else "") & Homeless'Image
        & " without a home," & Home_N'Image & " at home, room for" & Lot_Count'Image & " more"
        & (if Room_Short then " (no room for the next)" else "") & From (1)
        & (if Home_N > 0 then Away (1) else "");
   end Housing_Line;

   --  The storehouse: how far on, what it has of what it takes, who builds
   --  it ("" before the second morning, or with it off).
   --  What the storehouse's places hold, by what they are fitted out as,
   --  and who keeps it and makes for it.
   function Fitted_Line return String is
      use Ada.Strings.Unbounded;
      Out_S : Unbounded_String;
      procedure Part (F : Fitting; Title : String) is
         Places, Made_N, Full, Two_High, Stacked : Natural := 0;
         Held : array (Item_Kind) of Natural := [others => 0];
         Parts : Unbounded_String;
      begin
         for K in 1 .. Cell_Count loop
            declare
               C : constant Cell_View := Cell_At (K);
            begin
               if C.Fit = F and then not C.Closed then
                  Places := Places + 1;
                  if C.Made then
                     Made_N := Made_N + 1;
                  end if;
                  if C.Second then
                     Two_High := Two_High + 1;
                  end if;
                  if C.Count > 0 then
                     Full := Full + 1;
                     Held (C.Kind) := Held (C.Kind) + C.Count;
                     if F = Floor and then C.Count > Cell_Limit (C.Kind) then
                        Stacked := Stacked + 1;      --  (more than a place's own: baskets on baskets)
                     end if;
                  end if;
               end if;
            end;
         end loop;
         for K in Item_Kind loop
            if Held (K) > 0 then
               Parts := Parts & (if Length (Parts) > 0 then ", " else "") & Img (Held (K)) & " " & Name (K);
            end if;
         end loop;
         Out_S := Out_S & (if Length (Out_S) > 0 then "; " else "") & Title & " " & Img (Places)
           & (if F in Shelf | Meat_Barrel | Water_Barrel
              then " (" & Img (Made_N) & " made" & (if Two_High > 0 then ", " & Img (Two_High) & " two high" else "") & ")"
              else "")
           & (if Stacked > 0 then " (" & Img (Stacked) & " stacked)" else "")
           & (if Full > 0 then ": " & To_String (Parts) else "");
      end Part;
   begin
      Part (Floor, "floor");
      Part (Shelf, "shelves");
      Part (Meat_Barrel, "meat barrels");
      Part (Water_Barrel, "water barrels");
      Part (Cover, "under the coverings");
      Part (Lean, "against the wall");
      return To_String (Out_S)
        & "; stockman " & (if Stockman in 1 .. Members then Name_Of (Stockman) else "none")
        & "; carpenter " & (if Carpenter in 1 .. Members then Name_Of (Carpenter) else "none")
        & "; the cart " & (if Cart.Here then (if Cart_At_Storehouse then "at the storehouse's front, " else "elsewhere, ")
                              & Img (Cart.Salt) & " lb of salt in it" else "gone");
   end Fitted_Line;

   function Storehouse_Line return String is
   begin
      if Storehouse = 0 then
         return (if Storehouse_Note = "" then "" else "storehouse: none: " & Storehouse_Note);
      end if;
      declare
         V : constant House_View := House_At (Storehouse);
      begin
         if V.Phase = Standing then
            return "storehouse: on the stockyard, standing; " & Fitted_Line;
         end if;
         return "storehouse: on the stockyard, "
           & (case V.Phase is
                 when Ground => "its ground", when Flooring => "its floor", when Framing => "its frame",
                 when Walling => "its walls", when Roofing => "its roof", when Trimming => "its roof's trimming",
                 when Yard => "its yard", when Standing => "standing")
           & (if V.Phase = Standing then ""
              else " " & Img (Integer (100.0 * Float (V.Placed) / Float (Integer'Max (1, V.Blocks)))) & " %, wood "
                   & Img (V.Got (Wood)) & " of " & Img (V.Takes (Wood)) & ", straw " & Img (V.Got (Straw)) & " of "
                   & Img (V.Takes (Straw))
                   & (if V.Takes (Stone) > 0 then ", stone " & Img (V.Got (Stone)) & " of " & Img (V.Takes (Stone)) else "")
                   & (if V.Builder in 1 .. Members then ", built by " & Name_Of (V.Builder) else ", no builder")
                   & (case V.Waits is
                         when Not_Waiting | For_A_Builder => "", when For_Wood => ", waits for wood",
                         when For_Straw => ", waits for straw", when For_A_Way => ", no way to it",
                         when For_Stone => ", waits for stone"));
      end;
   end Storehouse_Line;

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

   procedure Put_Who is
   begin
      for I in 1 .. Members loop
         if not Dead (I) then
            Put_Line ("  who: " & Name_Of (I) & "," & Integer (100.0 * Fed_Of (I))'Image & " % fed: " & Status (I)
                      & (if Aloft (I) then " (up its ladder, " & Img (Shown_At (I).Z - Where (I).Z, 1) & " m)" else "")
                      --  (one that starves, or cannot get somewhere: where it is, to find the pit it is in)
                      & (if Person (I).Starving or else Status (I) = "can't get there"
                         then " (at " & Img (Where (I).X, 1) & " " & Img (Where (I).Y, 1) & " " & Img (Where (I).Z, 2) & ")"
                         else ""));
         end if;
      end loop;
      for H in 1 .. House_Count loop                 --  (and each ladder standing: how far its foot is under the eave)
         if Ladder_At (H).Standing then
            Put_Line ("  ladder: at house" & H'Image & " (" & Img (House_At (H).Door.X, 0) & ", " & Img (House_At (H).Door.Y, 0)
                      & "), side" & Ladder_At (H).Side'Image & ", its foot " & Img (Ladder_At (H).Top.Z - Ladder_At (H).Foot.Z, 2)
                      & " m under the eave and "
                      & Img (Ada.Numerics.Elementary_Functions.Sqrt ((Ladder_At (H).Top.X - Ladder_At (H).Foot.X) ** 2
                                   + (Ladder_At (H).Top.Y - Ladder_At (H).Foot.Y) ** 2), 2) & " m out from it");
         end if;
      end loop;
   end Put_Who;

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
        & (if Storehouse_Line /= "" then "; " & Storehouse_Line else "")
        & (if Beds_Line /= "" then "; " & Beds_Line else "")
        & (if Cart_Line /= "" then "; " & Cart_Line else "")
        & (if Labour and then At_Extra > 0 and then Extra_Hands < Members      --  (while there is a limit)
           then "; at extra tasks" & At_Extra'Image & " (of" & Extra_Hands'Image & " at most)" else "");
   end Food_Line;

end Castle.Scenario;
