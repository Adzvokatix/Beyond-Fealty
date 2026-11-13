separate (Castle.Colony)
function Go_Haul (I : Positive) return Boolean is
   M : Member renames Band (I);
begin
   if Own_Logs (I) = 0 then
      M.Why := Nothing_To_Haul;
      return False;
   end if;
   if not Room_For (Wood) then
      M.Why := No_Room;
      return False;
   end if;
   for Attempt in 1 .. 3 loop
      declare
         Best   : Natural := 0;
         Best_D : Float := Float'Last;
      begin
         for K in 1 .. N_Piles loop
            if Piles (K).Count > Piles (K).Claimed and then Its_Pile (K, I)
              and then not Failed (M, Pile_Base_Id + K)
            then
               declare
                  D : constant Float := Flat_Dist (M.Pos, Piles (K).Centre);
               begin
                  if D < Best_D then
                     Best_D := D;
                     Best := K;
                  end if;
               end;
            end if;
         end loop;
         if Best = 0 then
            M.Why := (if Attempt = 1 then Nothing_To_Haul else No_Way);
            return False;
         end if;
         if Route_To (M, Piles (Best).Centre, 1.0) then
            Release (M, I);
            M.Pile := Best;
            Piles (Best).Claimed := Piles (Best).Claimed + 1;
            Piles (Best).Owner := I;
            M.State := To_Pile;
            return True;
         end if;
         Remember_Failure (M, Pile_Base_Id + Best);
         M.Why := No_Way;
      end;
   end loop;
   return False;
end Go_Haul;
