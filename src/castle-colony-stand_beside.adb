separate (Castle.Colony)
function Stand_Beside (P : Block_Pos; Where : out Vec3) return Boolean is
   Nx   : constant Integer := Floor_Div (Integer (P.X), 2);
   Ny   : constant Integer := Floor_Div (Integer (P.Y), 2);
   C    : constant Vec3 := Centre_Of (P);
   Best : Float := Float'Last;
begin
   Where := C;
   for Dx in -3 .. 3 loop
      for Dy in -3 .. 3 loop
         declare
            N : Natural;
            F : Castle.Nav.Floor_List;
         begin
            Castle.Nav.Floors_At (Nx + Dx, Ny + Dy, N, F);
            for Fi in 1 .. N loop
               if F (Fi).Speed > 0.0 and then F (Fi).Z in Integer (P.Z) - 7 .. Integer (P.Z) + 2 then
                  declare
                     On_Rock : Boolean := False;
                     Pt : constant Vec3 := ((Float (Nx + Dx) + 0.5) * 0.5, (Float (Ny + Dy) + 0.5) * 0.5,
                                            Float (F (Fi).Z) * 0.25);
                     D  : constant Float := Flat_Dist (Pt, C);
                  begin
                     for A in 0 .. 1 loop
                        for B2 in 0 .. 1 loop
                           On_Rock := On_Rock
                             or else Mat ((Nx + Dx) * 2 + A, (Ny + Dy) * 2 + B2, F (Fi).Z - 1) = Boulder;
                        end loop;
                     end loop;
                     if not On_Rock and then D < Best then
                        Best := D;
                        Where := Pt;
                     end if;
                  end;
               end if;
            end loop;
         end;
      end loop;
   end loop;
   return Best < Float'Last;
end Stand_Beside;
