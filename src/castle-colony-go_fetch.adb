separate (Castle.Colony)
function Go_Fetch (I : Positive; K : Item_Kind; Reach_M : Float := 0.0; Least_M : Float := 0.0)
                   return Boolean is
   M : Member renames Band (I);
   --  (no reach given: as far as the porters look now)
   Reach : constant Float := (if Reach_M > 0.0 then Reach_M else Haul_Reach_M);
   P : Block_Pos;
   Found : Boolean;
   Stand : Vec3;
begin
   M.Fetch := K;
   for Attempt in 1 .. (if Told_On then Ask_Tries else 3) loop
      Find_Source (K, M.Pos, I, P, Found, Reach, Least_M);
      if not Found then
         if Reach_M = 0.0 and then Attempt = 1 and then M.Job = Porter then
            Look_Further_For (Food => False);       --  (none of it in reach: a ring further, the next time)
         end if;
         M.Why := No_Source;
         Remember_Failure (M, Kind_Id (K));   --  the other kinds first, a while
         return False;
      end if;
      --  water is only looked for where it can be waded, so the way goes
      --  right to it; stone is got at from the ground beside the boulder
      if K = Stone and then not Stand_Beside (P, Stand) then
         null;
      elsif (if Told_On
             then Route_Asked (M, (if K = Stone then Stand else Centre_Of (P)), (if K = Stone then 0.3 else 0.6),
                               Source_Id (P))
             else Route_To (M, (if K = Stone then Stand else Centre_Of (P)), (if K = Stone then 0.3 else 0.6)))
      then
         Release (M, I);
         M.Tgt := P;
         M.State := To_Source;
         return True;
      end if;
      Remember_Failure (M, Source_Id (P));
      M.Why := No_Way;
   end loop;
   Remember_Failure (M, Kind_Id (K));   --  none of it to be got at: the other kinds first, a while
   return False;
end Go_Fetch;
