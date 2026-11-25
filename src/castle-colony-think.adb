separate (Castle.Colony)
procedure Think (I : Positive) is
   M : Member renames Band (I);
   Gathers : constant Boolean := M.Job = Gatherer or else (M.Job = Cook and then M.Use_For = For_Store);
   --  a part load of what its job brings in: get more before going home
   --  A load in its arms is taken where it was going first, and then it
   --  eats (John, 2026-11-13: "people carrying items to the stockpile will
   --  stop and eat instead of completing their task and then eating, this
   --  creates an oddity where foresters carrying logs back to the stockpile
   --  have a log on their sholder while they are eating"): not when it
   --  fends (what it carries is its meal), nor when it is down to its last
   --  (Very_Hungry: what it carries has had hours to go where it was
   --  going), nor with nowhere in the stockpiles to put it; and food of its
   --  own gathering it eats from where it is, as before, when there is no
   --  stew to be had.  (Taken home first, that food went to the stores,
   --  where the cook keeps a pot's fill: on a first day with nothing cooked
   --  yet the band went hungry beside it, fended, and the cook with them,
   --  and nothing was cooked until the next morning.)
   function Load_First return Boolean is
     (Needs_On and then M.Carried > 0 and then not M.Fends and then M.Fed >= Very_Hungry
      and then (M.Use_For /= For_Store or else Can_Store (M))
      and then not (Raw_Food (M.Carry) > 0 and then M.Use_For = For_Store
                    and then (Stew_Free = 0 or else Failed (M, Camp_Id))));

   --  (not when night has come, nor when it is hungry with a load to take home first)
   Topping_Up : constant Boolean :=
     M.Carried > 0 and then M.Carried < Carry_Limit (M.Carry)
     and then ((Gathers and then M.Carry in Berries | Vegetables | Apples)
               or else (M.Job = Porter and then M.Carry in Straw | Stone | Water and then M.Carry = M.Fetch))
     and then not Bedtime (M)
     and then not (M.Fed < Hungry_At and then Load_First);

   --  Needs first: eat if hungry (stew, else what it carries, else from
   --  the stockpile), and at night, once its hands are free, to bed.
   --  True: it is seeing to one of them.
   function Sees_To_Needs return Boolean is
      Wants_Food : constant Boolean := M.Fed < (if Bedtime (M) then Supper_At else Hungry_At);
      Loaded     : constant Boolean := Load_First;
   begin
      if Wants_Food and then not Loaded then
         if Go_Eat_Stew (I) or else Eat_Carried (M) then
            return True;
         end if;
         if M.Carried = 0 and then Go_Eat (I) then
            return True;
         end if;
         --  nothing to be had and starving: it fends for itself
         --  (its hands full of something else: that first)
         if M.Fed < Very_Hungry and then not Bedtime (M) and then not Failed (M, Fend_Id) then
            if M.Carried = 0 and then Go_Fend (I) then
               return True;
            end if;
            Remember_Failure (M, Fend_Id, Seconds => (if M.Carried = 0 then 60 else 20));
         end if;
      end if;
      if M.Carried = 0 and then Bedtime (M) then
         --  the cook sees to the fire for the night before it lies down
         if M.Job = Cook and then Labour_On and then Camp_Built and then Fire_Wants (Cooking => False)
           and then Tend_By_Hand (I, Cooking => False)
         then
            return True;
         end if;
         if not Go_Bed (I) then
            M.Wait := 5.0;
            M.State := Idle;
         end if;
         return True;
      end if;
      return False;
   end Sees_To_Needs;
begin
   M.Thoughts := M.Thoughts + 1;
   M.Why := Nothing_Yet;
   if Needs_On and then M.Carry /= Carcass and then Sees_To_Needs then
      Drop_Stretch (M);                         --  (a stretch of path it had is given up)
      return;
   end if;
   --  a stockpile the player has ordered removed: a porter with empty hands takes a load out of it
   --  before anything else of its work
   if M.Job = Porter and then M.Carried = 0 and then (for some Z in 1 .. N_Zones => Zones (Z).Leaving)
     and then Go_Move_In (I)
   then
      return;
   end if;
   if M.Carry = Carcass then                    --  home with it, or (no hunter now) put it down
      --  (given another job with a deer on its shoulders, it brings the deer home and butchers it
      --  first: Kill_Home_On; else, and with nowhere to butcher it, it puts it down where it stands)
      if M.Job /= Hunter and then not Kill_Home_On then
         Note_Drop (M, No_Hunter_Now);
         Drop_Carcass (M);
      elsif Go_Butcher (I) then
         return;
      elsif M.Job /= Hunter then
         Note_Drop (M, No_Hunter_Now);
         Drop_Carcass (M);
      elsif Needs_On and then (M.Fed < Hungry_At or else Bedtime (M)) then
         --  nowhere to butcher it, and it is hungry or night has come: it
         --  puts its kill down and sees to itself (a serf won't let itself
         --  starve: it stood with the deer in its arms until there was room,
         --  which at the pace of 2026-11-12 the reference band's one
         --  stockpile ran out of); the kill lies there until there is room
         Note_Drop (M, (if M.Why = No_Way then No_Way_Home else No_Room_For_It));
         Drop_Carcass (M);
         if Sees_To_Needs then
            return;
         end if;
      else
         M.Wait := 5.0;
         M.State := Idle;
         return;
      end if;
   end if;
   --  its place by the fire, the first time it thinks once the camp stands
   if Beds_On and then not M.Placed and then Camp_Built and then not (N_Houses > 0 and then Housed (I)) then
      Place_Bed (I);
   end if;
   --  its bed, once the camp stands (and again when a house is its own):
   --  straw for it, and to where it sleeps with that.  Before the band's
   --  building as before its job (John, 2026-11-12: "basic needs take
   --  priority"); what it has in its hands for the camp is seen to first.
   if (Beds_On or else M.Use_For = For_Bed) and then Think_Bed (I) then
      Drop_Stretch (M);
      return;
   end if;
   --  a log taken to make a ladder of: made where it stands with it, at the
   --  stockpile (taken for that and come to nothing: no errand any more)
   if M.Use_For = For_Ladder then
      if M.Carry = Wood and then M.Carried >= Ladder_Wood then
         M.State := Making;
         M.Work := 0.0;
         M.Spot := M.Pos + (0.0, 0.0, 0.6);
         return;
      end if;
      M.Use_For := For_Store;
   end if;
   --  the band builds what is marked (its camp, then the paths) before
   --  anyone goes about its job (and anyone left holding something meant
   --  for the camp puts that right)
   if Labour_On
     and then ((Camp_Set and then Camp_Zone_N > 0
                and then (not Zones (Camp_Zone_N).Built or else Seats_Laid < Seat_Logs))
               or else Paths_Left_M > 0
               or else (M.Carry = Earth and then M.Carried > 0)
               or else Cart_To_Pull
               or else Box_Trees_Standing > 0    --  (a tree to fell in a stockpile put down whole)
               or else Wall_Left_N > 0           --  (the square's walls to lay)
               or else M.Use_For = For_Wall      --  (stone in hand for them, whoever holds it)
               or else (M.Job /= Cook and then M.Use_For not in For_Store | For_House | For_Bed | For_Ladder | For_Fitting))
   then
      if Think_Build (I) then
         return;
      end if;
   else
      Drop_Stretch (M);                         --  (no path left to lay)
   end if;
   if M.Job = Cook then
      Think_Cook (I, Topping_Up);
      return;
   end if;
   --  a load for the house it is building: there with it
   if M.Carried > 0 and then M.Use_For = For_House and then Think_House (I) then
      return;
   end if;
   --  a log for the carpenter's next shelf or barrel: there with it
   if M.Carried > 0 and then M.Use_For = For_Fitting and then Think_Carpenter (I) then
      return;
   end if;
   if M.Carried > 0 and then not Topping_Up then
      if Go_Store (I) then
         return;
      end if;
      M.Wait := 5.0;
      M.State := Idle;
      return;
   end if;
   if M.Job = Gatherer then
      if not (for some G of Gathered => Asked_For (G)) then
         --  nothing it brings in is asked for: home with what it has, then rest
         if M.Carried > 0 and then Go_Store (I) then
            return;
         end if;
         M.Why := (if M.Carried > 0 and then M.Why = No_Room then No_Room else Enough_Food);
         Rest (I);
         return;
      end if;
      Think_Gather (I, Topping_Up, Asked_Only => True);
      return;
   end if;
   if M.Job = Forester then
      --  every log of the last tree home before the next is felled
      if Go_Haul (I) then
         return;
      end if;
      --  the carpenter: the storehouse's shelves and barrels, and no house
      if Is_Carpenter (I) and then Think_Carpenter (I) then
         return;
      end if;
      --  a builder: its house, while there is something to build it with
      declare
         Waits : Why_Idle := Nothing_Yet;
      begin
         if N_Houses > 0 and then not Is_Carpenter (I) then
            if Think_House (I) then
               return;
            end if;
            Waits := M.Why;
         end if;
         if Own_Logs (I) = 0 and then Go_Fell (I) then
            return;
         end if;
         --  (what it says it waits for is its house's: straw, whatever kept it
         --  from felling meanwhile; wood, when the stores have enough for all but building)
         if Waits in No_Thatch | No_Stone or else (Waits = No_Timber and then M.Why = Enough_Wood) then
            M.Why := Waits;
            Rest (I);
            return;
         end if;
      end;
      if M.Why = Enough_Wood then
         Rest (I);
      elsif Room_Gated and then M.Why in No_Room | Nearly_Full and then M.Carried = 0 then
         Wait_For_Room (I);
      else
         M.Wait := 4.0;
         M.State := Idle;
      end if;
      return;
   end if;
   --  the stockman: the storehouse's work before a porter's
   if M.Job = Porter and then Is_Keeper (I) and then Think_Keeper (I) then
      return;
   end if;
   if M.Job = Porter then
      if M.Carried > 0 then                       --  topping up
         if Go_Fetch (I, M.Carry) then
            return;
         end if;
         declare
            Why : constant Why_Idle := M.Why;
         begin
            if Go_Store (I) then
               return;
            end if;
            M.Why := (if M.Why = No_Room then No_Room else Why);
         end;
         M.Wait := 4.0;
         M.State := Idle;
         return;
      end if;
      --  porters never carry wood: what the colony is short of, first things first
      declare
         K : constant Item_Kind := Wanted (M);
         Short, Roomless : Boolean := False;
      begin
         if K /= Nothing then
            if Go_Fetch (I, K) then
               return;
            end if;
         else
            --  why nothing is wanted: all there is to be had, nowhere to
            --  put what is short, or none of it found lately
            for F of Fetch_Order loop
               if Asked_For (F) then
                  Short := True;
                  if (if Last_N > 0 then not Room_To_Set_Out (F) else not Room_For (F)) then
                     Roomless := True;
                  elsif Failed (M, Kind_Id (F)) then
                     M.Fetch := F;
                  end if;
               end if;
            end loop;
            M.Why := (if not Short then Stocks_Full elsif Roomless then Full_Why else No_Source);
         end if;
      end;
      if M.Why in Stocks_Full | No_Source and then Go_Move_In (I) then
         return;                                --  (nothing to fetch: a load out of the old stockpile)
      end if;
      if M.Why = Stocks_Full then
         Rest (I);
      elsif Room_Gated and then M.Why in No_Room | Nearly_Full then
         Wait_For_Room (I);
      else
         M.Wait := 4.0;
         M.State := Idle;
      end if;
      return;
   end if;
   if M.Job = Hunter then
      --  salt for its kills first, a sackful from the lord's cart when the stores are low of it
      if Go_Cart (I) then
         return;
      end if;
      --  a kill lying out there first (while there is somewhere to butcher it)
      if (not Needs_On or else (Room_For (Meat) and then Room_For (Hide))) and then Go_Carcass (I) then
         return;
      end if;
      if Deer_Safe then
         M.Why := Deer_Spared;
      elsif not Asked_For (Meat) then
         M.Why := Enough_Meat;
         Rest (I);
         return;
      elsif (if Last_N > 0 then not Room_To_Set_Out (Meat) or else not Room_To_Set_Out (Hide)
             else not Room_For (Meat) or else not Room_For (Hide))
      then
         M.Why := Full_Why;
         if Room_Gated then
            Wait_For_Room (I);
            return;
         end if;
      elsif Go_Hunt (I) then
         return;
      end if;
      M.Wait := 4.0;
      M.State := Idle;
      return;
   end if;
   Stroll (I);
end Think;
