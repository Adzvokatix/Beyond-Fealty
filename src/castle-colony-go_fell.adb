separate (Castle.Colony)
function Go_Fell (I : Positive) return Boolean is
   M : Member renames Band (I);
begin
   if not Asked_For (Wood) then
      M.Why := Enough_Wood;
      return False;
   end if;
   for Attempt in 1 .. 3 loop
      declare
         Best   : Natural := 0;
         Best_S : Float := Float'Last;
      begin
         for K in 1 .. N_Trees loop
            declare
               T : Tree_Rec renames Trees (K);
            begin
               if not T.Down and then (T.Reserved_By = 0 or else T.Reserved_By = I)
                 and then not (Apples_Safe and then T.Info.Kind = Apple)
                 and then not Failed (M, Tree_Base_Id + K)
                 and then Flat_Dist (Tree_Base (K), Stake_At) <= Work_Radius_M
               then
                  if Mat (T.Info.Bx, T.Info.By, T.Info.Bz + 1) not in Trunk then
                     T.Down := True;                  --  gone since it was found
                  else
                     declare
                        S : constant Float :=
                          Flat_Dist (M.Pos, Tree_Base (K)) + 0.5 * Flat_Dist (Stake_At, Tree_Base (K));
                     begin
                        if S < Best_S then
                           Best_S := S;
                           Best := K;
                        end if;
                     end;
                  end if;
               end if;
            end;
         end loop;
         if Best = 0 then
            M.Why := No_Tree;
            return False;
         end if;
         if Route_To (M, Tree_Base (Best), Half_W (Best) + 0.9) then
            Release (M, I);
            M.Tree := Best;
            Trees (Best).Reserved_By := I;
            M.State := To_Tree;
            return True;
         end if;
         Remember_Failure (M, Tree_Base_Id + Best);
         M.Why := No_Way;
      end;
   end loop;
   return False;
end Go_Fell;
