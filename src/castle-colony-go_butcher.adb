separate (Castle.Colony)
function Go_Butcher (I : Positive) return Boolean is
   M    : Member renames Band (I);
   Meat_N : constant Positive := Meat_Of (Carcasses (M.Prize).Class);
   Mc, Hc : Natural := 0;
   Md, Hd : Float := Float'Last;
begin
   for K in 1 .. N_Cells loop
      declare
         C : Cell renames Cells (K);
         D : constant Float :=               --  (an overflow place only when no ordinary place takes it)
           Flat_Dist (M.Pos, C.Centre) + (if C.Overflow then Overflow_Last else 0.0);
      begin
         if Takes (K, Meat, Meat_N) and then D < Md
         then
            Md := D;
            Mc := K;
         end if;
      end;
   end loop;
   for K in 1 .. N_Cells loop
      declare
         C : Cell renames Cells (K);
         D : constant Float :=               --  (an overflow place only when no ordinary place takes it)
           Flat_Dist (M.Pos, C.Centre) + (if C.Overflow then Overflow_Last else 0.0);
      begin
         if K /= Mc and then Takes (K, Hide, 1) and then D < Hd
         then
            Hd := D;
            Hc := K;
         end if;
      end;
   end loop;
   if Mc = 0 or else Hc = 0 then
      M.Why := No_Room;
      return False;
   end if;
   if not Route_To (M, Cells (Mc).Centre, 0.6) then
      M.Why := No_Way;
      return False;
   end if;
   Cells (Mc).Kind := Meat;
   Cells (Mc).Incoming := Cells (Mc).Incoming + Meat_N;
   Cells (Hc).Kind := Hide;
   Cells (Hc).Incoming := Cells (Hc).Incoming + 1;
   M.Cell := Mc;
   M.Cell2 := Hc;
   M.State := To_Butcher;
   return True;
end Go_Butcher;
