separate (Castle.Colony)
procedure Refresh (K : Positive) is
   Bu : Bush renames Bushes (K);
   Sx, Sy : Float := 0.0;
   Low : Integer := Integer'Last;
begin
   Bu.Ripe := 0;
   Bu.Radius := 0.0;
   if Bu.N = 0 then
      return;
   end if;
   for J in 1 .. Bu.N loop
      Sx := Sx + (Float (Bu.Blocks (J).X) + 0.5) * 0.25;
      Sy := Sy + (Float (Bu.Blocks (J).Y) + 0.5) * 0.25;
      Low := Integer'Min (Low, Integer (Bu.Blocks (J).Z));
      if Mat (Integer (Bu.Blocks (J).X), Integer (Bu.Blocks (J).Y), Integer (Bu.Blocks (J).Z)) = Berry_Bush then
         Bu.Ripe := Bu.Ripe + 1;
      end if;
   end loop;
   Bu.Centre := (Sx / Float (Bu.N), Sy / Float (Bu.N), Float (Low) * 0.25);
   for J in 1 .. Bu.N loop
      Bu.Radius := Float'Max (Bu.Radius,
        Flat_Dist (Bu.Centre, ((Float (Bu.Blocks (J).X) + 0.5) * 0.25,
                               (Float (Bu.Blocks (J).Y) + 0.5) * 0.25, 0.0)) + 0.125);
   end loop;
   if Bu.Ripe < Bu.N and then Bu.Regrow_At < 0.0 then
      Bu.Regrow_At := Now_Hours + Long_Float (Regrow_Days) * 24.0;
   end if;
end Refresh;
