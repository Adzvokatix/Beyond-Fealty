separate (Castle.Colony)
function Go_Pick (I : Positive) return Boolean is
   M : Member renames Band (I);
begin
   for Attempt in 1 .. 3 loop
      declare
         Best : Natural := 0;
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
         if Best = 0 then
            M.Why := No_Bush;
            return False;
         end if;
         if Route_To (M, Bushes (Best).Centre, Bushes (Best).Radius + 0.7) then
            Release (M, I);
            M.Bush := Best;
            Bushes (Best).Reserved_By := I;
            M.State := To_Bush;
            return True;
         end if;
         Remember_Failure (M, Best);
         M.Why := No_Way;
      end;
   end loop;
   return False;
end Go_Pick;
