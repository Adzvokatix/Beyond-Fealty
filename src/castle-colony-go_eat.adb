separate (Castle.Colony)
function Go_Eat (I : Positive) return Boolean is
   M : Member renames Band (I);
   Desperate : constant Boolean := M.Fed < Very_Hungry and then (Failed (M, Fend_Id) or else Winter_Now);
   --  (what the winter store holds and what the cook keeps for the pot are
   --  left alone, but not by the starving with nothing to gather)
   function Limit (K : Item_Kind) return Natural is (if Desperate then Free_Stock (K) else Raw_Free (K));
begin
   for K of Raw_Order loop
      for Attempt in 1 .. 3 loop
         declare
            Best   : Natural := 0;
            Best_D : Float := Float'Last;
         begin
            --  the winter store is left alone, but not by the starving with nothing to gather
            exit when Limit (K) = 0;
            for C in 1 .. N_Cells loop
               if Cells (C).Kind = K and then Cells (C).Count > Cells (C).Outgoing
                 and then not Failed (M, Cell_Base + C)
               then
                  declare
                     D : constant Float := Flat_Dist (M.Pos, Cells (C).Centre);
                  begin
                     if D < Best_D then
                        Best_D := D;
                        Best := C;
                     end if;
                  end;
               end if;
            end loop;
            exit when Best = 0;
            if Route_To (M, Cells (Best).Centre, 0.6) then
               declare
                  C   : Cell renames Cells (Best);
                  Per : constant Positive := Raw_Food (K);
                  N   : constant Natural :=
                    Natural'Min (Limit (K), Natural'Min (C.Count - C.Outgoing, Items_For (Want_Points (M), Per)));
               begin
                  M.Cell := Best;
                  M.Ration := N * Per;
                  M.From_Pot := False;
                  C.Outgoing := C.Outgoing + N;
               end;
               M.State := To_Eat;
               return True;
            end if;
            Remember_Failure (M, Cell_Base + Best);
         end;
      end loop;
   end loop;
   return False;
end Go_Eat;
