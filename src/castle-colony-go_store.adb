separate (Castle.Colony)
function Go_Store (I : Positive) return Boolean is
   M : Member renames Band (I);
begin
   for Attempt in 1 .. 3 loop
      declare
         Best : Natural := 0;
         Best_D : Float := Float'Last;
      begin
         for K in 1 .. N_Cells loop
            declare
               C : Cell renames Cells (K);
               Takes : constant Boolean :=
                 (C.Kind = M.Carry and then C.Count + C.Incoming + M.Carried <= Cell_Limit (M.Carry))
                 or else (C.Kind = Nothing and then C.Incoming = 0);
            begin
               if Takes and then not Failed (M, Cell_Base + K) then
                  declare
                     D : constant Float := Flat_Dist (M.Pos, C.Centre);
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
            M.Why := No_Room;
            return False;
         end if;
         if Route_To (M, Cells (Best).Centre, 0.6) then
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
