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
      if Beds_On and then Tick_N mod (60 * Tick_Hz) = 7 then
         Keep_Beds;                                 --  (a place by the fire that has been built or dug on)
      end if;
      Keep_Cart;
      for I in 1 .. N_Members loop
         Step_Member (I);
      end loop;
      Keep_Cart;                                    --  (the lord's cart in one place, pulled or standing)
      Tend_Fire;
      if Tick_N mod Tick_Hz = 0 then
         Choose_Cook;
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
