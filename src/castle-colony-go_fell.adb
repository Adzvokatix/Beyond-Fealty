separate (Castle.Colony)
function Go_Fell (I : Positive) return Boolean is
   M : Member renames Band (I);
begin
   if not Asked_For (Wood) then
      M.Why := Enough_Wood;
      return False;
   end if;
   if Last_N > 0 and then not Room_To_Set_Out (Wood) then     --  (the stores' last places kept)
      M.Why := Nearly_Full;
      return False;
   end if;
   if Wood_Far_On then
      --  Looking as far as it has to (the spec, Fell_Reach_M).  The trees it may fell,
      --  the best first (the way there and half the way from the stake, as ever), are each
      --  asked of the walking map's pieces of ground alone (Refuse: no search for one out
      --  of reach), Fell_Tries of them at the most in one thought; one there is no way to
      --  is then nobody's to try for Tree_No_Way_S.  So a wood across a river costs a look
      --  a tree and not a search a tree, and whoever finds no way to any looks further.
      --  The search for a way is given Fell_Budget floors: a tree that can be got to only
      --  by a way far longer than it is off (72 m off and 330 m round by the ford, at the
      --  site this was measured on, 125,000 floors and 60 ms a search, and as far back with
      --  each log) is left as one there is no way to, for Tree_Round_S.
      declare
         Reach  : constant Float := Fell_Reach_M;
         N      : Natural := 0;                          --  the trees it may try (Fell_Cand, Fell_Score)
         --  why there is none, if there is none: of the trees standing in reach
         No_Way_N, Taken_N, Spared_N : Natural := 0;
         Home_Asked, Home_Way : Boolean := False;
         Round   : Boolean;
         Round_N : Natural := 0;                         --  trees tried that had only a long way round
         Tried   : Natural := 0;                         --  trees tried and found without a way, this thought
      begin
         for K in 1 .. N_Trees loop
            declare
               T : Tree_Rec renames Trees (K);
            begin
               if not T.Down and then Flat_Dist (Tree_Base (K), Stake_At) <= Reach
                 and then (Wood_From = 0.0 or else Flat_Dist (Tree_Base (K), Stake_At) >= Wood_From)
               then
                  --  (one that is not to be felled is counted only if it stands still; it is
                  --  marked as gone only by whoever could have felled it, as it always was)
                  if (Apples_Safe and then T.Info.Kind = Apple) or else Tick_N < T.No_Way_Till
                    or else (T.Reserved_By /= 0 and then T.Reserved_By /= I)
                    or else Tree_Spared (K)       --  (one left standing on the square the colony was founded on)
                  then
                     if Mat (T.Info.Bx, T.Info.By, T.Info.Bz + 1) in Trunk then
                        if T.Reserved_By /= 0 and then T.Reserved_By /= I then
                           Taken_N := Taken_N + 1;
                        elsif (Apples_Safe and then T.Info.Kind = Apple) or else Tree_Spared (K) then
                           Spared_N := Spared_N + 1;
                        else
                           No_Way_N := No_Way_N + 1;
                        end if;
                     end if;
                  elsif Mat (T.Info.Bx, T.Info.By, T.Info.Bz + 1) not in Trunk then
                     T.Down := True;                  --  gone since it was found
                  else
                     N := N + 1;
                     Fell_Cand (N) := K;
                     Fell_Score (N) := Flat_Dist (M.Pos, Tree_Base (K)) + 0.5 * Flat_Dist (Stake_At, Tree_Base (K));
                  end if;
               end if;
            end;
         end loop;
         for Attempt in 1 .. Natural'Min (N, Fell_Tries) loop
            declare
               Best : Positive := Attempt;
               K    : Positive;
            begin
               for C in Attempt + 1 .. N loop           --  (the best of those not yet tried, to the front)
                  if Fell_Score (C) < Fell_Score (Best) then
                     Best := C;
                  end if;
               end loop;
               K := Fell_Cand (Best);
               Fell_Cand (Best) := Fell_Cand (Attempt);
               Fell_Score (Best) := Fell_Score (Attempt);
               if Route_To (M, Tree_Base (K), Half_W (K) + 0.9, Refuse => True,
                            Budget => Fell_Budget + Integer (Fell_Budget_M * Flat_Dist (M.Pos, Tree_Base (K)))) then
                  Release (M, I);
                  M.Tree := K;
                  Trees (K).Reserved_By := I;
                  M.State := To_Tree;
                  return True;
               end if;
               --  no way to it, or none but a long way round (the search ran out: a river between
               --  with a ford far off).  From where the band lives, that is: one who has no such
               --  way home either (cut off, or across that river itself) says nothing of it to the
               --  others, and looks no further for it.
               Round := Castle.Nav.Last_Stats.Cut_Short;
               if not Home_Asked then
                  Home_Asked := True;
                  Home_Way := Castle.Nav."="
                    (Castle.Nav.Plan (M.Pos, Stake_At,
                                      Budget => Fell_Budget + Integer (Fell_Budget_M * Flat_Dist (M.Pos, Stake_At)), Within => Own_Region, Refuse => True).Result,
                     Castle.Nav.Found);
               end if;
               if Home_Way then
                  Trees (K).No_Way_Till := Tick_N + (if Round then Tree_Round_S else Tree_No_Way_S) * Tick_Hz;
               end if;
               if Round then
                  Round_N := Round_N + 1;
               end if;
               No_Way_N := No_Way_N + 1;
               Tried := Attempt;
               exit when Round_N >= Fell_Round_Tries;    --  (each of those was a search: no more of them in one thought)
            end;
         end loop;
         --  none it can fell that near.  Once every tree there has been tried (this thought or
         --  before: nothing left that nobody has asked the way to), and unless others are at the
         --  trees there are, it looks a ring further off, once all the ground this near is in and
         --  looked through; the next time it thinks, it looks there.
         if Taken_N = 0 and then Tried = N and then (N = 0 or else Home_Way) and then Reach < Fell_Reach_Max_M
           and then Reach <= Ground_In and then Looked_Through (Reach)
         then
            Wood_Reach := Float'Min (Fell_Reach_Max_M, Reach + Reach_Step_M);
            M.Why := Trees_Further;
         else
            M.Why := (if Taken_N > 0 then Trees_Taken elsif No_Way_N > 0 then Trees_No_Way
                      elsif Spared_N > 0 then Trees_Spared else No_Tree);
         end if;
         return False;
      end;
   end if;
   --  no further than the work radius, as it was before 2026-11-19
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
                 and then not Tree_Spared (K)
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
