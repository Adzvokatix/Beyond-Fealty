separate (Castle.Colony)
procedure New_Stockpile_Zone (From : Positive) is
begin
   N_Zones := N_Zones + 1;
   Zones (N_Zones) := (Kind => Stockpile_Zone, Cells => N_Cells - From + 1, others => <>);
   for K in From .. N_Cells loop
      Cells (K).Zone := N_Zones;
   end loop;
   Take_Plan (N_Zones);
end New_Stockpile_Zone;
