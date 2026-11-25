separate (Castle.Colony)
function Go_Take (I : Positive; K : Item_Kind; N : Positive; For_Use : Camp_Use) return Boolean is
   M : Member renames Band (I);
begin
   for Attempt in 1 .. 3 loop
      declare
         Best   : Natural := 0;
         Best_D : Float := Float'Last;
      begin
         for C in 1 .. N_Cells loop
            if Cells (C).Kind = K and then Cells (C).Count > Cells (C).Outgoing
              and then not Failed (M, Cell_Base + C)
            then
               declare
                  D : constant Float :=      --  (from an overflow place first)
                    Flat_Dist (M.Pos, Cells (C).Centre) - (if Cells (C).Overflow or else Cells (C).Closed then Overflow_Last else 0.0);
               begin
                  if D < Best_D then
                     Best_D := D;
                     Best := C;
                  end if;
               end;
            end if;
         end loop;
         if Best = 0 then
            return False;
         end if;
         if Route_To (M, Cells (Best).Centre, 0.6) then
            Release (M, I);
            M.Cell := Best;
            M.Due := Natural'Min (N, Cells (Best).Count - Cells (Best).Outgoing);
            Cells (Best).Outgoing := Cells (Best).Outgoing + M.Due;
            M.Use_For := For_Use;
            M.State := To_Take;
            return True;
         end if;
         Remember_Failure (M, Cell_Base + Best);
      end;
   end loop;
   return False;
end Go_Take;
