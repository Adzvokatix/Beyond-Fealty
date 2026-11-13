separate (Castle.Colony)
procedure Index_Stack (CX, CY : Integer; Far : Boolean := False) is
   type Pos_Array is array (Positive range <>) of Block_Pos;
   Max_Found : constant := 8_192;
   Found  : Pos_Array (1 .. Max_Found);
   NF     : Natural := 0;
   Parent : array (1 .. Max_Found) of Natural;
   Where_Is : Block_Maps.Map;

   function Root (K : Positive) return Positive is
      R : Positive := K;
   begin
      while Parent (R) /= R loop
         R := Parent (R);
      end loop;
      return R;
   end Root;
begin
   Indexed (CX, CY) := True;
   Index_Trees (CX, CY);
   for I in 0 .. Castle.Nav.Cells_Per_Stack - 1 loop
      for J in 0 .. Castle.Nav.Cells_Per_Stack - 1 loop
         declare
            Nx : constant Integer := CX * Castle.Nav.Cells_Per_Stack + I;
            Ny : constant Integer := CY * Castle.Nav.Cells_Per_Stack + J;
            N  : Natural;
            F  : Castle.Nav.Floor_List;
         begin
            Castle.Nav.Floors_At (Nx, Ny, N, F);
            for Fi in 1 .. N loop
               if F (Fi).Water > 0 then
                  Sources (CX, CY) := Sources (CX, CY) or Source_Bit (Water);
               end if;
               for A in 0 .. 1 loop
                  for C in 0 .. 1 loop
                     for Z in F (Fi).Z - 1 .. F (Fi).Z + 12 loop
                        declare
                           Bx : constant Integer := Nx * 2 + A;
                           By : constant Integer := Ny * 2 + C;
                           M  : constant Material := Mat (Bx, By, Z);
                        begin
                           if M in Tall_Grass | Wild_Grain and then Z = F (Fi).Z then
                              Sources (CX, CY) := Sources (CX, CY) or Source_Bit (Straw);
                           elsif M = Wild_Vegetables and then Z = F (Fi).Z then
                              Sources (CX, CY) := Sources (CX, CY) or Source_Bit (Vegetables);
                           elsif M = Boulder and then Z = F (Fi).Z - 1 then
                              Sources (CX, CY) := Sources (CX, CY) or Source_Bit (Stone);
                           end if;
                           if not Far and then M in Berry_Bush | Bare_Bush and then NF < Max_Found
                             and then not Where_Is.Contains (Key_Of (Bx, By, Z))
                           then
                              NF := NF + 1;
                              Found (NF) := (Integer_16 (Bx), Integer_16 (By), Integer_16 (Z));
                              Parent (NF) := NF;
                              Where_Is.Insert (Key_Of (Bx, By, Z), NF);
                           end if;
                        end;
                     end loop;
                  end loop;
               end loop;
            end loop;
         end;
      end loop;
   end loop;
   --  touching blocks belong together (26 neighbours)
   for K in 1 .. NF loop
      for Dx in -1 .. 1 loop
         for Dy in -1 .. 1 loop
            for Dz in -1 .. 1 loop
               declare
                  C : constant Block_Maps.Cursor :=
                    Where_Is.Find (Key_Of (Integer (Found (K).X) + Dx, Integer (Found (K).Y) + Dy,
                                           Integer (Found (K).Z) + Dz));
               begin
                  if Block_Maps.Has_Element (C) then
                     declare
                        A : constant Positive := Root (K);
                        Z : constant Positive := Root (Block_Maps.Element (C));
                     begin
                        if A /= Z then
                           Parent (Integer'Max (A, Z)) := Integer'Min (A, Z);
                        end if;
                     end;
                  end if;
               end;
            end loop;
         end loop;
      end loop;
   end loop;
   --  one bush per group, or joined to the bushes it touches
   for K in 1 .. NF loop
      if Root (K) = K then
         declare
            Touch  : array (1 .. 8) of Natural := [others => 0];
            NT     : Natural := 0;
            Target : Natural := 0;
         begin
            for J in K .. NF loop
               if Root (J) = K then
                  for Dx in -1 .. 1 loop
                     for Dy in -1 .. 1 loop
                        for Dz in -1 .. 1 loop
                           declare
                              C : constant Block_Maps.Cursor :=
                                Bush_Of.Find (Key_Of (Integer (Found (J).X) + Dx, Integer (Found (J).Y) + Dy,
                                                      Integer (Found (J).Z) + Dz));
                           begin
                              if Block_Maps.Has_Element (C) then
                                 declare
                                    Id  : constant Positive := Block_Maps.Element (C);
                                    New_One : Boolean := True;
                                 begin
                                    for T in 1 .. NT loop
                                       New_One := New_One and then Touch (T) /= Id;
                                    end loop;
                                    if New_One and then NT < Touch'Last
                                      and then Bushes (Id).Reserved_By = 0
                                    then
                                       NT := NT + 1;
                                       Touch (NT) := Id;
                                    end if;
                                 end;
                              end if;
                           end;
                        end loop;
                     end loop;
                  end loop;
               end if;
            end loop;
            if NT > 0 then
               Target := Touch (1);
               for T in 2 .. NT loop
                  Target := Natural'Min (Target, Touch (T));
               end loop;
               --  the others it touches go into the target too
               for T in 1 .. NT loop
                  if Touch (T) /= Target then
                     declare
                        From : Bush renames Bushes (Touch (T));
                        Into : Bush renames Bushes (Target);
                     begin
                        for J in 1 .. From.N loop
                           if Into.N < Max_Bush_Blocks then
                              Into.N := Into.N + 1;
                              Into.Blocks (Into.N) := From.Blocks (J);
                              Bush_Of.Replace (Key_Of (Integer (From.Blocks (J).X), Integer (From.Blocks (J).Y),
                                                       Integer (From.Blocks (J).Z)), Target);
                           end if;
                        end loop;
                        Into.Regrow_At := (if Into.Regrow_At < 0.0 then From.Regrow_At
                                           elsif From.Regrow_At < 0.0 then Into.Regrow_At
                                           else Long_Float'Max (Into.Regrow_At, From.Regrow_At));
                        From.N := 0;
                        From.Ripe := 0;
                        From.Regrow_At := -1.0;
                     end;
                  end if;
               end loop;
            elsif N_Bushes < Max_Bushes then
               N_Bushes := N_Bushes + 1;
               Target := N_Bushes;
               Bushes (Target) := (Centre => (0.0, 0.0, 0.0), Radius => 0.0, N => 0, Blocks => <>, Ripe => 0,
                                   Reserved_By => 0, Regrow_At => -1.0);
            end if;
            if Target > 0 then
               declare
                  Into : Bush renames Bushes (Target);
               begin
                  for J in K .. NF loop
                     if Root (J) = K and then Into.N < Max_Bush_Blocks then
                        Into.N := Into.N + 1;
                        Into.Blocks (Into.N) := Found (J);
                        Bush_Of.Include (Key_Of (Integer (Found (J).X), Integer (Found (J).Y),
                                                 Integer (Found (J).Z)), Target);
                     end if;
                  end loop;
               end;
               Refresh (Target);
            end if;
         end;
      end if;
   end loop;
end Index_Stack;
