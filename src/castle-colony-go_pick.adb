separate (Castle.Colony)
function Go_Pick (I : Positive) return Boolean is
   M : Member renames Band (I);
begin
   --  (told of the ways: more of them asked in one thought, each a look at the map's pieces, no search)
   for Attempt in 1 .. (if Told_On then Ask_Tries else 3) loop
      declare
         Best : Natural := 0;
         Best_S : Float := Float'Last;
      begin
         for K in 1 .. N_Bushes loop
            declare
               Bu : Bush renames Bushes (K);
            begin
               if Bu.Ripe > 0 and then Bush_Free (K, I)
                 and then not Failed (M, K) and then not No_Way_Told (K)
                 and then Flat_Dist (Bu.Centre, Stake_At) <= Food_Reach_M
               then
                  declare
                     S : constant Float := Flat_Dist (M.Pos, Bu.Centre) + Stake_Weight (M) * Flat_Dist (Stake_At, Bu.Centre);
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
         if (if Told_On then Route_Asked (M, Bushes (Best).Centre, Bushes (Best).Radius + 0.7, Best)
             else Route_To (M, Bushes (Best).Centre, Bushes (Best).Radius + 0.7))
         then
            Release (M, I);
            M.Bush := Best;
            if Bushes (Best).Reserved_By = 0 or else not Share_On then
               Bushes (Best).Reserved_By := I;
            end if;
            M.State := To_Bush;
            return True;
         end if;
         Remember_Failure (M, Best);
         M.Why := No_Way;
      end;
   end loop;
   return False;
end Go_Pick;
