separate (Castle.Colony)
function Best_Bush (I : Positive) return Natural is
   M      : Member renames Band (I);
   Best   : Natural := 0;
   Best_S : Float := Float'Last;
begin
   for K in 1 .. N_Bushes loop
      declare
         Bu : Bush renames Bushes (K);
      begin
         if Bu.Ripe > 0 and then (Bu.Reserved_By = 0 or else Bu.Reserved_By = I)
           and then not Failed (M, K)
           and then Flat_Dist (Bu.Centre, Stake_At) <= Work_Radius_M
         then
            declare
               S : constant Float := Flat_Dist (M.Pos, Bu.Centre) + 0.5 * Flat_Dist (Stake_At, Bu.Centre);
            begin
               if S < Best_S then
                  Best_S := S;
                  Best := K;
               end if;
            end;
         end if;
      end;
   end loop;
   return Best;
end Best_Bush;
