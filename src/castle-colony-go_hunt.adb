separate (Castle.Colony)
function Go_Hunt (I : Positive) return Boolean is
   M : Member renames Band (I);
   Best : Natural := 0;
   Best_D : Float := Float'Last;
begin
   for K in 1 .. Castle.Herds.Deer_Slots loop
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
      M.Why := No_Prey;
      return False;
   end if;
   M.Prey := Best;
   M.State := Stalking;
   M.Route.N := 0;
   M.Work := 0.0;                    --  how long it has been after this one
   M.Check_Tick := Tick_N;           --  plan at once
   return True;
end Go_Hunt;
