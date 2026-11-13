separate (Castle.Colony)
procedure Think_Cook (I : Positive; Topping_Up : Boolean) is
   M : Member renames Band (I);
   Want_Cook : constant Boolean := Pot_Stew < Pot_Low or else Pot_Raw > 0;
   Can_Cook  : constant Boolean := Pot_Raw > 0 or else Stew_Stock > 0;
begin
   if not Camp_Set then
      M.Use_For := For_Store;
      if M.Carried > 0 then
         if Go_Store (I) then
            return;
         end if;
         M.Wait := 5.0;
         M.State := Idle;
         return;
      end if;
      M.Why := No_Camp;
      Stroll (I);
      return;
   end if;
   --  a camp not built yet (what there was for it to do on it, it has looked
   --  for): nothing to cook at, so out gathering till there is
   if not Camp_Built then
      M.Use_For := For_Store;
      Think_Gather (I, Topping_Up);
      if M.State = Idle then
         M.Why := Camp_Unbuilt;
      end if;
      return;
   end if;
   --  a load for the camp: there with it
   if M.Carried > 0 and then M.Use_For /= For_Store then
      if Go_Camp (I) then
         return;
      end if;
      M.Use_For := For_Store;                  --  no way to the camp: to a stockpile, then
      if Go_Store (I) then
         return;
      end if;
      M.Wait := 4.0;
      M.State := Idle;
      return;
   end if;
   --  a load it gathered: home with it when there is cooking to do, else more
   if M.Carried > 0 then
      if Want_Cook and then Can_Cook then
         Think_Gather (I, Topping_Up => False);
      else
         Think_Gather (I, Topping_Up);
      end if;
      return;
   end if;
   --  in winter the fire comes before anything: its stack kept up
   if Winter_Now and then Fire_Logs < 2 and then Free_Stock (Wood) > 0 and then Go_Take (I, Wood, 1, For_Fire) then
      return;
   end if;
   --  the fire, tended by hand: wood on it whenever it is wanted and low
   if Labour_On and then Fire_Wants (Cooking => Want_Cook and then Can_Cook) then
      if Tend_By_Hand (I, Cooking => Want_Cook and then Can_Cook) then
         return;
      end if;
      if Want_Cook and then Can_Cook and then Fuel_H < Cook_Hours then    --  no wood to be had: no cooking yet
         M.Wait := 4.0;
         M.State := Idle;
         return;
      end if;
   end if;
   if Want_Cook and then Can_Cook then
      if not Labour_On and then not Fuel_Ok then
         if Free_Stock (Wood) > 0 and then Go_Take (I, Wood, 1, For_Fire) then
            return;
         end if;
         if Go_Sticks (I) then
            return;
         end if;
         M.Wait := 4.0;
         M.State := Idle;
         return;
      end if;
      declare
         K : constant Item_Kind := Next_Ingredient;
      begin
         if K /= Nothing and then Go_Take (I, K, Positive'Min (Ingredient_Count (K), Usable (K)), For_Pot) then
            return;
         end if;
      end;
      if Pot_Raw > 0 and then Go_Stir (I) then
         return;
      end if;
   end if;
   --  the camp's comforts: some firewood, then the seats, then a full stack
   if Free_Stock (Wood) > 0 then
      if Fire_Logs < 2 or else (Seats_Laid >= Seat_Logs and then Fire_Logs < Fire_Stack) then
         if Go_Take (I, Wood, 1, For_Fire) then
            return;
         end if;
      elsif Seats_Laid < Seat_Logs then
         if Go_Take (I, Wood, 1, For_Seat) then
            return;
         end if;
      end if;
   end if;
   --  nothing to cook: out gathering till there is, unless the pot is full
   M.Use_For := For_Store;
   if Pot_Stew < Pot_Low then
      Think_Gather (I, Topping_Up);
      if M.State = Idle then
         M.Why := Nothing_To_Cook;
      end if;
      return;
   end if;
   M.Why := Pot_Full;
   Stroll (I, Camp_At);
end Think_Cook;
