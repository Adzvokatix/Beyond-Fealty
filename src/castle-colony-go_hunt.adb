separate (Castle.Colony)
function Go_Hunt (I : Positive) return Boolean is
   M : Member renames Band (I);
   Best : Natural := 0;
   Best_D : Float := Float'Last;
   Bred, Settling : Boolean := False;   --  deer in reach left alone: their herds too small; just shot at
begin
   for K in 1 .. Castle.Herds.Deer_Slots loop
      if Castle.Herds.Alive (K) and then Flat_Dist (Castle.Herds.Where (K), Stake_At) <= Castle.Herds.Range_M
        and then Castle.Deer."/=" (Castle.Herds.Class_Of (K), Castle.Deer.Fawn) and then Castle.Herds.Herd_Of (K) > 0
      then
         if Castle.Herds.In_Herd (Castle.Herds.Herd_Of (K)) <= Spare_Last then
            Bred := True;
         elsif Failed (M, Prey_Base_Id + K) or else Failed (M, Prey_Base_Id + 500 + Castle.Herds.Herd_Of (K)) then
            Settling := True;
         end if;
      end if;
      if Fair_Game (K) and then not Failed (M, Prey_Base_Id + K)
        and then not Failed (M, Prey_Base_Id + 500 + Castle.Herds.Herd_Of (K))
        and then Flat_Dist (Castle.Herds.Where (K), Stake_At) <= Castle.Herds.Range_M
      then
         declare
            D : constant Float := Flat_Dist (M.Pos, Castle.Herds.Where (K));
         begin
            if D < Best_D then
               Best_D := D;
               Best := K;
            end if;
         end;
      end if;
   end loop;
   if Best = 0 then
      --  (why: what John saw, 2026-11-17, "Hunters can't find deer even when the deer are close":
      --  they were close, and their herds were down to their last three)
      M.Why := (if Settling then Herd_Settling elsif Bred then Herds_Breeding else No_Prey);
      return False;
   end if;
   M.Prey := Best;
   M.State := Stalking;
   M.Route.N := 0;
   M.Work := 0.0;                    --  how long it has been after this one
   M.Check_Tick := Tick_N;           --  plan at once
   return True;
end Go_Hunt;
