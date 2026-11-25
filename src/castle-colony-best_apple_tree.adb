separate (Castle.Colony)
function Best_Apple_Tree (I : Positive) return Natural is
   M      : Member renames Band (I);
   Best   : Natural := 0;
   Best_S : Float := Float'Last;
begin
   if not Apple_Season then
      return 0;
   end if;
   for K in 1 .. N_Trees loop
      if Trees (K).Info.Kind = Apple and then Apples_On (K) > 0
        and then (Trees (K).Reserved_By = 0 or else Trees (K).Reserved_By = I)
        and then not Failed (M, Tree_Base_Id + K) and then not No_Way_Told (Tree_Base_Id + K)
        and then Flat_Dist (Tree_Base (K), Stake_At) <= Food_Reach_M
      then
         declare
            S : constant Float := Flat_Dist (M.Pos, Tree_Base (K)) + Stake_Weight (M) * Flat_Dist (Stake_At, Tree_Base (K));
         begin
            if S < Best_S then
               Best_S := S;
               Best := K;
            end if;
         end;
      end if;
   end loop;
   return Best;
end Best_Apple_Tree;
