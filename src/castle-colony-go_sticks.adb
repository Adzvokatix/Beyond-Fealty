separate (Castle.Colony)
function Go_Sticks (I : Positive; For_Use : Camp_Use := For_Fire; Reach_M : Float := Work_Radius_M) return Boolean is
   M : Member renames Band (I);
begin
   for Attempt in 1 .. 3 loop
      declare
         Best   : Natural := 0;
         Best_D : Float := Float'Last;
      begin
         for K in 1 .. N_Trees loop
            if not Trees (K).Down and then not Failed (M, Tree_Base_Id + K)
              and then Flat_Dist (Tree_Base (K), Stake_At) <= Reach_M
            then
               declare
                  D : constant Float := Flat_Dist (M.Pos, Tree_Base (K));
               begin
                  if D < Best_D then
                     Best_D := D;
                     Best := K;
                  end if;
               end;
            end if;
         end loop;
         if Best = 0 then
            M.Why := No_Source;
            M.Fetch := Sticks;
            return False;
         end if;
         if Route_To (M, Tree_Base (Best), Half_W (Best) + 0.9) then
            Release (M, I);
            M.Fetch := Sticks;
            M.Tgt := (Integer_16 (Trees (Best).Info.Bx), Integer_16 (Trees (Best).Info.By),
                      Integer_16 (Trees (Best).Info.Bz));
            M.Use_For := For_Use;
            M.State := To_Source;
            return True;
         end if;
         Remember_Failure (M, Tree_Base_Id + Best);
         M.Why := No_Way;
      end;
   end loop;
   return False;
end Go_Sticks;
