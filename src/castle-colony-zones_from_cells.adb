separate (Castle.Colony)
procedure Zones_From_Cells is
   Stack : array (1 .. Max_Cells) of Positive;
   Top   : Natural;

   function Touch (A, B : Positive) return Boolean is
     (abs (Cells (A).Centre.X - Cells (B).Centre.X) + abs (Cells (A).Centre.Y - Cells (B).Centre.Y) < 1.25
      and then (abs (Cells (A).Centre.X - Cells (B).Centre.X) < 0.25
                or else abs (Cells (A).Centre.Y - Cells (B).Centre.Y) < 0.25));
begin
   N_Zones := 0;
   Camp_Zone_N := 0;
   for K in 1 .. N_Cells loop
      Cells (K).Zone := 0;
   end loop;
   for First in 1 .. N_Cells loop
      if Cells (First).Zone = 0 then
         declare
            --  out of zones (hundreds of single cells): the rest join the last
            Z : constant Positive := (if N_Zones < Max_Zones - 1 then N_Zones + 1 else N_Zones);
         begin
            if Z > N_Zones then
               N_Zones := Z;
               Zones (Z) := (Kind => Stockpile_Zone, Lo => (Float'Last, Float'Last, Float'Last),
                             Hi => (Float'First, Float'First, Float'First), Cells => 0, others => <>);
            end if;
            Top := 1;
            Stack (1) := First;
            Cells (First).Zone := Z;
            while Top > 0 loop
               declare
                  K : constant Positive := Stack (Top);
                  C : Vec3 renames Cells (K).Centre;
                  R : Zone_Rec renames Zones (Z);
               begin
                  Top := Top - 1;
                  R.Cells := R.Cells + 1;
                  R.Lo := (Float'Min (R.Lo.X, C.X - 0.5), Float'Min (R.Lo.Y, C.Y - 0.5), Float'Min (R.Lo.Z, C.Z));
                  R.Hi := (Float'Max (R.Hi.X, C.X + 0.5), Float'Max (R.Hi.Y, C.Y + 0.5), Float'Max (R.Hi.Z, C.Z));
                  for J in 1 .. N_Cells loop
                     if Cells (J).Zone = 0 and then Touch (K, J) then
                        Cells (J).Zone := Z;
                        Top := Top + 1;
                        Stack (Top) := J;
                     end if;
                  end loop;
               end;
            end loop;
         end;
      end if;
   end loop;
   if Camp_Set then
      New_Camp_Zone;
   end if;
end Zones_From_Cells;
