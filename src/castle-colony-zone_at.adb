separate (Castle.Colony)
function Zone_At (Z : Positive) return Zone_View is
   R : Zone_Rec renames Zones (Z);
   V : Zone_View := (Kind => R.Kind, Lo => R.Lo, Hi => R.Hi, Turn => R.Turn, Along => R.Along, Across => R.Across,
                     Blocks => R.Blocks, Built => R.Built, Got => R.Got, Cells => R.Cells, Yard => R.Yard, Leaving => R.Leaving,
                     Placed => R.Placed, From => (Float (R.Fx) * 0.25, Float (R.Fy) * 0.25, R.Lo.Z),
                     Way => R.Way, Along_B => R.Along_B, others => <>);
begin
   case R.Kind is
      when Stockpile_Zone =>
         for K in 1 .. N_Cells loop
            declare
               C : Cell renames Cells (K);
            begin
               if C.Zone = Z and then C.Overflow then
                  V.Cells := V.Cells - 1;
                  V.Overflow := V.Overflow + 1;
               elsif C.Zone = Z and then C.Closed then
                  V.Cells := V.Cells - 1;          --  (under or before the storehouse: no place now)
               end if;
               if C.Zone = Z and then C.Kind /= Nothing then
                  if C.Overflow then
                     V.Over_In_Use := V.Over_In_Use + 1;
                  elsif C.Closed then
                     null;
                  else
                     V.In_Use := V.In_Use + 1;
                  end if;
                  V.Holds (C.Kind) := V.Holds (C.Kind) + C.Count;
                  V.Coming (C.Kind) := V.Coming (C.Kind) + C.Incoming;
                  V.Going (C.Kind) := V.Going (C.Kind) + C.Outgoing;
               end if;
            end;
         end loop;
      when Camp_Zone =>
         V.Holds (Wood) := Fire_Logs;
         for I in 1 .. N_Members loop                    --  what the cook is bringing
            declare
               M : Member renames Band (I);
            begin
               if not M.Is_Dead and then M.State in To_Camp | Putting_In and then M.Use_For not in For_Store | For_Bed
                 and then M.Carried > 0
               then
                  V.Coming (M.Carry) := V.Coming (M.Carry) + M.Carried;
               end if;
            end;
         end loop;
      when Habitation_Zone =>
         for H in 1 .. N_Houses loop
            if Houses (H).Zone = Z then
               V.Homes := V.Homes + 1;
               if Houses (H).Built then
                  V.Homes_Built := V.Homes_Built + 1;
               else
                  V.Built := False;                      --  (something on it is still being built)
               end if;
               for K in Item_Kind loop
                  V.Short (K) := V.Short (K) + House_Short (H, K);
                  V.Got (K) := V.Got (K) + Houses (H).Got (K);
               end loop;
            end if;
         end loop;
         for I in 1 .. N_Members loop                    --  what its builders are bringing
            declare
               M : Member renames Band (I);
            begin
               if not M.Is_Dead and then M.Use_For = For_House and then M.Carried > 0 and then M.Site in 1 .. N_Houses
                 and then Houses (M.Site).Zone = Z
               then
                  V.Coming (M.Carry) := V.Coming (M.Carry) + M.Carried;
               end if;
            end;
         end loop;
         V.No_Room := Room_Short;
         for K in 1 .. N_Lots loop
            if Lots (K).Zone = Z then
               V.Lots := V.Lots + 1;
            end if;
         end loop;
   end case;
   for I in 1 .. N_Members loop
      declare
         P : Vec3 renames Band (I).Pos;
      begin
         if not Band (I).Is_Dead and then Zone_On (P.X, P.Y) = Z then
            V.People := V.People + 1;
         end if;
      end;
   end loop;
   return V;
end Zone_At;
