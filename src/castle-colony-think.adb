separate (Castle.Colony)
procedure Think (I : Positive) is
   M : Member renames Band (I);
   Gathers : constant Boolean := M.Job = Gatherer or else (M.Job = Cook and then M.Use_For = For_Store);
   --  a part load of what its job brings in: get more before going home
   Topping_Up : constant Boolean :=
     M.Carried > 0 and then M.Carried < Carry_Limit (M.Carry)
     and then ((Gathers and then M.Carry in Berries | Vegetables | Apples)
               or else (M.Job = Porter and then M.Carry in Straw | Stone | Water and then M.Carry = M.Fetch))
     and then not Bedtime (M);

   --  Needs first: eat if hungry (stew, else what it carries, else from
   --  the stockpile), and at night, once its hands are free, to bed.
   --  True: it is seeing to one of them.
   function Sees_To_Needs return Boolean is
      Wants_Food : constant Boolean := M.Fed < (if Bedtime (M) then Supper_At else Hungry_At);
   begin
      if Wants_Food then
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
   if M.Carry = Carcass then                    --  home with it, or (no hunter now) put it down
      if M.Job /= Hunter then
         Drop_Carcass (M);
      elsif Go_Butcher (I) then
         return;
      else
         M.Wait := 5.0;
         M.State := Idle;
         return;
      end if;
   end if;
   --  the band builds what is marked (its camp, then the paths) before
   --  anyone goes about its job (and anyone left holding something meant
   --  for the camp puts that right)
   if Labour_On
     and then ((Camp_Set and then Camp_Zone_N > 0
                and then (not Zones (Camp_Zone_N).Built or else Seats_Laid < Seat_Logs))
               or else Paths_Left_M > 0
               or else (M.Carry = Earth and then M.Carried > 0)
               or else (M.Job /= Cook and then M.Use_For not in For_Store | For_House))
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
      --  a builder: its house, while there is something to build it with
      declare
         Waits : Why_Idle := Nothing_Yet;
      begin
         if N_Houses > 0 then
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
         if Waits = No_Thatch or else (Waits = No_Timber and then M.Why = Enough_Wood) then
            M.Why := Waits;
            Rest (I);
            return;
         end if;
      end;
      if M.Why = Enough_Wood then
         Rest (I);
      else
         M.Wait := 4.0;
         M.State := Idle;
      end if;
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
                  if not Room_For (F) then
                     Roomless := True;
                  elsif Failed (M, Kind_Id (F)) then
                     M.Fetch := F;
                  end if;
               end if;
            end loop;
            M.Why := (if not Short then Stocks_Full elsif Roomless then No_Room else No_Source);
         end if;
      end;
      if M.Why = Stocks_Full then
         Rest (I);
      else
         M.Wait := 4.0;
         M.State := Idle;
      end if;
      return;
   end if;
   if M.Job = Hunter then
      if Go_Carcass (I) then                     --  a kill lying out there first
         return;
      end if;
      if Deer_Safe then
         M.Why := Deer_Spared;
      elsif not Asked_For (Meat) then
         M.Why := Enough_Meat;
         Rest (I);
         return;
      elsif not Room_For (Meat) or else not Room_For (Hide) then
         M.Why := No_Room;
      elsif Go_Hunt (I) then
         return;
      end if;
      M.Wait := 4.0;
      M.State := Idle;
      return;
   end if;
   Stroll (I);
end Think;
