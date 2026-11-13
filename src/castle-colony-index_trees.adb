separate (Castle.Colony)
procedure Index_Trees (CX, CY : Integer) is
   X0 : constant Integer := CX * Chunk_B;
   Y0 : constant Integer := CY * Chunk_B;
begin
   if Find_Src = null then
      return;
   end if;
   for I in Floor_Div (X0, Tree_Cell_B) .. Floor_Div (X0 + Chunk_B - 1, Tree_Cell_B) loop
      for J in Floor_Div (Y0, Tree_Cell_B) .. Floor_Div (Y0 + Chunk_B - 1, Tree_Cell_B) loop
         declare
            T : constant Tree_Info := Find_Src (I, J);
         begin
            if T.Valid and then T.Bx in X0 .. X0 + Chunk_B - 1 and then T.By in Y0 .. Y0 + Chunk_B - 1
              and then I >= 0 and then J >= 0
              and then not Tree_Of.Contains (Key_Of (I, J, 0)) and then N_Trees < Max_Trees
            then
               N_Trees := N_Trees + 1;
               Trees (N_Trees) := (I => I, J => J, Info => T,
                                   Down => Mat (T.Bx, T.By, T.Bz + 1) not in Trunk, Reserved_By => 0,
                                   others => <>);
               Tree_Of.Insert (Key_Of (I, J, 0), N_Trees);
            end if;
         end;
      end loop;
   end loop;
end Index_Trees;
