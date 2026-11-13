separate (Castle.Colony)
procedure Ground_From_Cells is
   Max_Strips : constant := 4 * Max_Cells;
   type Strip_Array is array (1 .. Max_Strips) of Run_Rec;
   type Strip_Access is access Strip_Array;
   procedure Free is new Ada.Unchecked_Deallocation (Strip_Array, Strip_Access);
   S : Strip_Access := new Strip_Array;
   N : Natural;

   function Before (L, R : Run_Rec) return Boolean is (L.Y < R.Y or else (L.Y = R.Y and then L.X0 < R.X0));

   procedure Add (R : Run_Rec) is
   begin
      if N_Runs < Max_Zone_Runs then
         N_Runs := N_Runs + 1;
         Runs (N_Runs) := R;
      end if;
   end Add;
begin
   N_Runs := 0;
   for Z in 1 .. N_Zones loop
      Zones (Z).First := 0;
      Zones (Z).N := 0;
      Zones (Z).Turn := 0.0;
   end loop;
   for Z in 1 .. N_Zones loop
      if Zones (Z).Kind = Stockpile_Zone then
         --  four strips a cell, put in order, those end to end at one level joined
         N := 0;
         for K in 1 .. N_Cells loop
            if Cells (K).Zone = Z then
               declare
                  X0 : constant Integer := B (Cells (K).Centre.X - 0.5 + 0.01);
                  Y0 : constant Integer := B (Cells (K).Centre.Y - 0.5 + 0.01);
                  Zr : constant Integer := B (Cells (K).Centre.Z) - 1;
               begin
                  for J in 0 .. 3 loop
                     N := N + 1;
                     S (N) := (Y => Integer_16 (Y0 + J), X0 => Integer_16 (X0), X1 => Integer_16 (X0 + 3),
                               Z => Integer_16 (Zr));
                  end loop;
               end;
            end if;
         end loop;
         for I in 2 .. N loop
            declare
               R : constant Run_Rec := S (I);
               J : Natural := I - 1;
            begin
               while J >= 1 and then Before (R, S (J)) loop
                  S (J + 1) := S (J);
                  J := J - 1;
               end loop;
               S (J + 1) := R;
            end;
         end loop;
         Zones (Z).First := N_Runs;
         for I in 1 .. N loop
            if N_Runs > Zones (Z).First and then Runs (N_Runs).Y = S (I).Y and then Runs (N_Runs).Z = S (I).Z
              and then Integer (Runs (N_Runs).X1) + 1 = Integer (S (I).X0)
            then
               Runs (N_Runs).X1 := S (I).X1;
            else
               Add (S (I));
            end if;
         end loop;
         Zones (Z).N := N_Runs - Zones (Z).First;
         Measure_Zone (Z);
      end if;
   end loop;
   Free (S);
   --  the camp's square, less what a stockpile has of it
   if Camp_Set and then Camp_Zone_N in 1 .. N_Zones then
      declare
         Z    : constant Positive := Camp_Zone_N;
         Cx   : constant Integer := Integer (Float'Floor (Camp_At.X * 4.0 + 0.5));
         Cy   : constant Integer := Integer (Float'Floor (Camp_At.Y * 4.0 + 0.5));
         Half : constant Integer := Integer (Camp_Size_M * 2.0);
         Zr   : constant Integer := B (Camp_At.Z) - 1;
         X    : Integer;
      begin
         Zones (Z).First := N_Runs;
         for Y in Cy - Half .. Cy + Half - 1 loop
            X := Cx - Half;
            while X <= Cx + Half - 1 loop
               if Zone_Of_Block (X, Y) = 0 then
                  declare
                     X0 : constant Integer := X;
                  begin
                     while X + 1 <= Cx + Half - 1 and then Zone_Of_Block (X + 1, Y) = 0 loop
                        X := X + 1;
                     end loop;
                     Add ((Y => Integer_16 (Y), X0 => Integer_16 (X0), X1 => Integer_16 (X), Z => Integer_16 (Zr)));
                  end;
               end if;
               X := X + 1;
            end loop;
         end loop;
         Zones (Z).N := N_Runs - Zones (Z).First;
         Measure_Zone (Z);
      end;
   end if;
   for K in 1 .. N_Cells loop
      Cells (K).Turn := 0.0;
   end loop;
   Zones_Ver := Zones_Ver + 1;
end Ground_From_Cells;
