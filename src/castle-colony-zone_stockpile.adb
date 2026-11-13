separate (Castle.Colony)
procedure Zone_Stockpile (X0, Y0, X1, Y1 : Float; Cells : out Natural) is
   First : constant Natural := N_Cells;
begin
   Cells := 0;
   Plan_Stockpile_Lot (X0, Y0, X1, Y1);
   if Plan_Refused /= Lot_Ok then
      return;
   end if;
   Clear_Places;                              --  what grows where things will be put is cut
   for K in 1 .. Plan_Cells_N loop
      N_Cells := N_Cells + 1;
      Castle.Colony.Cells (N_Cells) := (Centre => Plan_Cell (K), Turn => Plan_Turn, others => <>);
   end loop;
   Cells := N_Cells - First;
   New_Stockpile_Zone (First + 1);            --  one zoning, one zone
end Zone_Stockpile;
