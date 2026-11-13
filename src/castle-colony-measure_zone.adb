separate (Castle.Colony)
procedure Measure_Zone (Z : Positive) is
   R  : Zone_Rec renames Zones (Z);
   Ex : constant Float := Cos (R.Turn);
   Ey : constant Float := Sin (R.Turn);
   A0, B0 : Float := Float'Last;
   A1, B1 : Float := Float'First;
   Z0 : Integer := Integer'Last;
   Z1 : Integer := Integer'First;

   procedure Corner (X, Y : Float) is
      A : constant Float := X * Ex + Y * Ey;
      B : constant Float := Y * Ex - X * Ey;
   begin
      A0 := Float'Min (A0, A);
      A1 := Float'Max (A1, A);
      B0 := Float'Min (B0, B);
      B1 := Float'Max (B1, B);
   end Corner;
begin
   R.Blocks := 0;
   R.Bx0 := Integer'Last;
   R.By0 := Integer'Last;
   R.Bx1 := Integer'First;
   R.By1 := Integer'First;
   if R.N = 0 then
      R.Bx0 := 0;
      R.By0 := 0;
      R.Bx1 := -1;
      R.By1 := -1;
      R.Lo := (0.0, 0.0, 0.0);
      R.Hi := (0.0, 0.0, 0.0);
      R.Along := 0.0;
      R.Across := 0.0;
      return;
   end if;
   for K in R.First + 1 .. R.First + R.N loop
      declare
         Run : Run_Rec renames Runs (K);
         X0  : constant Float := Float (Run.X0) * 0.25;
         X1  : constant Float := Float (Integer (Run.X1) + 1) * 0.25;
         Y0  : constant Float := Float (Run.Y) * 0.25;
         Y1  : constant Float := Float (Integer (Run.Y) + 1) * 0.25;
      begin
         R.Blocks := R.Blocks + Integer (Run.X1) - Integer (Run.X0) + 1;
         R.Bx0 := Integer'Min (R.Bx0, Integer (Run.X0));
         R.Bx1 := Integer'Max (R.Bx1, Integer (Run.X1));
         R.By0 := Integer'Min (R.By0, Integer (Run.Y));
         R.By1 := Integer'Max (R.By1, Integer (Run.Y));
         Z0 := Integer'Min (Z0, Integer (Run.Z));
         Z1 := Integer'Max (Z1, Integer (Run.Z));
         Corner (X0, Y0);
         Corner (X1, Y0);
         Corner (X0, Y1);
         Corner (X1, Y1);
      end;
   end loop;
   R.Lo := (Float (R.Bx0) * 0.25, Float (R.By0) * 0.25, Float (Z0 + 1) * 0.25);
   R.Hi := (Float (R.Bx1 + 1) * 0.25, Float (R.By1 + 1) * 0.25, Float (Z1 + 1) * 0.25);
   R.Along := A1 - A0;
   R.Across := B1 - B0;
end Measure_Zone;
