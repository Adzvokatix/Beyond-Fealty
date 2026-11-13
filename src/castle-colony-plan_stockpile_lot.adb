separate (Castle.Colony)
procedure Plan_Stockpile_Lot (X0, Y0, X1, Y1 : Float) is
   Ex, Ey, Gap : Float;
begin
   Way_Of_Path ((X0, Y0, 0.0), (X1, Y1, 0.0), Ex, Ey, Gap);
   declare
      --  the corners along and across the lot's way; its places are the
      --  whole metres they span
      A0 : constant Float := X0 * Ex + Y0 * Ey;
      A1 : constant Float := X1 * Ex + Y1 * Ey;
      B0 : constant Float := Y0 * Ex - X0 * Ey;
      B1 : constant Float := Y1 * Ex - X1 * Ey;
      Ia0 : constant Integer := Integer (Float'Floor (Float'Min (A0, A1)));
      Ia1 : constant Integer := Integer (Float'Ceiling (Float'Max (A0, A1))) - 1;
      Ib0 : constant Integer := Integer (Float'Floor (Float'Min (B0, B1)));
      Ib1 : constant Integer := Integer (Float'Ceiling (Float'Max (B0, B1))) - 1;
   begin
      Plan_Lot (Ex, Ey, Float (Ia0), Float (Ia1 + 1), Float (Ib0), Float (Ib1 + 1),
                Seed => (X0, Y0, 0.0), Step_B => Integer (Zone_Step_M * 4.0), Places => True,
                Ia0 => Ia0, Ia1 => Ia1, Ib0 => Ib0, Ib1 => Ib1);
      if Plan_Refused = Too_Large then
         return;
      end if;
      --  it has to come within a metre of a path (and is then drawn out to it)
      if not Plan_At_Path then
         Plan_Refused := Off_Path;
      elsif Plan_Refused = Lot_Ok and then not Zone_Room then
         Plan_Refused := No_Room;
      end if;
      if Plan_Refused /= Lot_Ok then      --  nothing to show of a lot that is refused
         Plan_N := 0;
         Plan_Blocks := 0;
         Plan_Cells_N := 0;
         Plan_Under_N := 0;
      end if;
   end;
end Plan_Stockpile_Lot;
