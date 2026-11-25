separate (Castle.Colony)
function Go_Store (I : Positive) return Boolean is
   M : Member renames Band (I);
   Keeper : constant Boolean := Is_Keeper (I);   --  the stockman: a place fitted out for it first
begin
   for Attempt in 1 .. 3 loop
      declare
         Best : Natural := 0;
         Best_D : Float := Float'Last;
      begin
         for K in 1 .. N_Cells loop
            declare
               C : Cell renames Cells (K);
            begin
               if (Takes (K, M.Carry, M.Carried) or else (Keeper and then Keeps (K, M.Carry, M.Carried)))
                 and then not Failed (M, Cell_Base + K)
               then
                  declare
                     --  (an overflow place only when no ordinary place takes it)
                     D : constant Float := Flat_Dist (M.Pos, C.Centre) + (if C.Overflow then Overflow_Last else 0.0)
                       - (if Keeper and then C.Fit /= Ground then Overflow_Last else 0.0);
                  begin
                     if D < Best_D then
                        Best_D := D;
                        Best := K;
                     end if;
                  end;
               end if;
            end;
         end loop;
         if Best = 0 then
            if Store_Now.First_Full < 0.0 then
               Store_Now.First_Full := Now_Hours;      --  (a measure)
            end if;
            M.Why := No_Room;
            return False;
         end if;
         if Route_To (M, Cells (Best).Centre, 0.6) then
            if Cells (Best).Overflow then
               Store_Now.Overflow_Loads := Store_Now.Overflow_Loads + 1;   --  (a measure)
            end if;
            M.Cell := Best;
            Cells (Best).Kind := M.Carry;
            Cells (Best).Incoming := Cells (Best).Incoming + M.Carried;
            M.State := To_Store;
            return True;
         end if;
         Remember_Failure (M, Cell_Base + Best);
         M.Why := No_Way;
      end;
   end loop;
   return False;
end Go_Store;
