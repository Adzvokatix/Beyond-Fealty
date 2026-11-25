separate (Castle.Colony)
procedure Advance (Seconds : Float; Hours : Long_Float) is
begin
   Now_Hours := Hours;
   Left_Over := Left_Over + Float'Max (0.0, Seconds);
   if Trees_Pending and then Left_Over >= Tick_S then
      Trees_Pending := False;
      for X in Indexed'Range (1) loop
         for Y in Indexed'Range (2) loop
            if Indexed (X, Y) then
               Index_Trees (X, Y);
            end if;
         end loop;
      end loop;
   end if;
   Ground_In := Ground_Reach_M;        --  (the host has that much of the ground in before it calls)
   Castle.Herds.Set_Ground (Own_Region);
   while Left_Over >= Tick_S loop
      Left_Over := Left_Over - Tick_S;
      Tick_N := Tick_N + 1;
      if Curing_On and then Stake_Set and then not Cart_Tried then
         Cart_Tried := True;                        --  (the lord's cart, come with the band)
         Place_Cart;
      end if;
      Keep_Off_Turned;                               --  (the walking map told of a turned hovel that stands,
      Walk_Drawn;                                    --  and of a storehouse walked where it is drawn)
      Index_Some (2);
      if Tick_N mod Tick_Hz = 0 then
         Regrow;
      end if;
      if N_Housing > 0 and then Tick_N mod Tick_Hz = 1 then
         Begin_Houses;                              --  a house begun for whoever has none
      end if;
      if Stock_Stale or else Tick_N mod Tick_Hz = 1 then   --  once a second, and on the very first step
         Take_Stock;
         Stock_Stale := False;
      end if;
      if Camp_Set and then not Camp_Built and then Tick_N mod Tick_Hz = 1 then
         Check_Built;                               --  (and how much of its ground is still to do)
      end if;
      if Labour_On and then (Paths_Stale or else Tick_N mod Tick_Hz = 1) then
         Refresh_Paths;                             --  what of the planned paths is still to lay
         Look_Near_Again;
      end if;
      --  (what of the square's walls is still to lay: counted at once when its ground has moved,
      --  which whatever of the band's moves it says, and once a minute besides, to see what the
      --  player has dug: counted every second, thirty days on a walled square cost half as much
      --  again, and a wall that waits for stone would cost that for good)
      if Camp_Square and then Walls_On and then Labour_On and then Camp_Zone_N > 0
        and then Zones (Camp_Zone_N).Built
        and then (Walls_Stale or else Tick_N mod (60 * Tick_Hz) = 4)
      then
         Count_Walls;
      end if;
      if Beds_On and then Tick_N mod (60 * Tick_Hz) = 7 then
         Keep_Beds;                                 --  (a place by the fire that has been built or dug on)
      end if;
      Keep_Cart;
      for I in 1 .. N_Members loop
         Step_Member (I);
      end loop;
      Keep_Cart;                                    --  (the lord's cart in one place, pulled or standing)
      if Tick_N mod Tick_Hz = 0 then                --  (a measure: the overflow places in use)
         declare
            N : Natural := 0;
         begin
            for K in 1 .. N_Cells loop
               if Cells (K).Overflow and then Cells (K).Kind /= Nothing then
                  N := N + 1;
               end if;
            end loop;
            Store_Now.Overflow_Most := Natural'Max (Store_Now.Overflow_Most, N);
            if N > 0 then
               Store_Now.Busy_S := Store_Now.Busy_S + 1.0;
            end if;
         end;
      end if;
      for I in 1 .. N_Members loop                  --  (a measure: who stands for want of room)
         if not Band (I).Is_Dead and then Band (I).State in Idle | Strolling and then Band (I).Why in No_Room | Nearly_Full then
            if Band (I).Carried > 0 then
               Store_Now.Holding_S := Store_Now.Holding_S + Tick_S;
               Store_Now.Holding_Of (Band (I).Carry) := Store_Now.Holding_Of (Band (I).Carry) + Tick_S;
            else
               Store_Now.Roomless_S := Store_Now.Roomless_S + Tick_S;
            end if;
         end if;
      end loop;
      Tend_Fire;
      if Tick_N mod Tick_Hz = 0 then
         Choose_Cook;
      end if;
      if Store_On and then Store_House = 0 and then Tick_N mod Tick_Hz = 2 then
         Ask_Storehouse;                            --  (the second morning's request: the advisor's, simulated)
      end if;
      if Tick_N mod Tick_Hz = 5 then
         Drop_Emptied;                              --  (a stockpile ordered removed, once it is empty)
      end if;
      if Tick_N mod Tick_Hz = 4 then
         Level_Places;                              --  (a stockpile's place made level when something is first put on it)
      end if;
      if Store_House > 0 and then Tick_N mod Tick_Hz = 3 then
         Choose_Keeper;                             --  (a stockman, once the storehouse stands,
         Choose_Carpenter;                          --  and a carpenter)
      end if;
      --  the deer, startled by anyone too near
      declare
         Near : Castle.Herds.People (1 .. Living);
         N    : Natural := 0;
      begin
         for I in 1 .. N_Members loop
            if not Band (I).Is_Dead then
               --  a hunter at its hunt (creeping, drawing, standing still) is hard to see;
               --  and one who has not moved over the ground in this step frightens no herd
               --  (John, 2026-11-13: "a person standing still doesn't frighten a herd")
               N := N + 1;
               Near (N) := (P => Band (I).Pos,
                            Stalking => Band (I).Job = Hunter and then Band (I).State in Stalking | Aiming | Recovering,
                            Still => Band (I).Pos.X = Band (I).Prev.X and then Band (I).Pos.Y = Band (I).Prev.Y);
            end if;
         end loop;
         Castle.Herds.Step (Tick_S, Now_Hours, Near);
      end;
      Age_Arrows;
   end loop;
end Advance;
