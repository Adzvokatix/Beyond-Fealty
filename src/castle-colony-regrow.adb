separate (Castle.Colony)
procedure Regrow is
   Winter : constant Boolean :=
     Castle.Climate."=" (Castle.Climate.Season_Of (Castle.Climate.Day_Of_Year (Now_Hours)),
                         Castle.Climate.Winter);
begin
   if Winter then
      return;
   end if;
   for K in 1 .. N_Bushes loop
      declare
         Bu : Bush renames Bushes (K);
      begin
         if Bu.Regrow_At >= 0.0 and then Now_Hours >= Bu.Regrow_At and then Bu.Reserved_By = 0 then
            Bu.Ripe := 0;
            for J in 1 .. Bu.N loop
               declare
                  P : Block_Pos renames Bu.Blocks (J);
                  M : constant Material := Mat (Integer (P.X), Integer (P.Y), Integer (P.Z));
               begin
                  if M = Bare_Bush then
                     Write_Src (Integer (P.X), Integer (P.Y), Integer (P.Z), (Mat => Berry_Bush, State => 0));
                     Bu.Ripe := Bu.Ripe + 1;
                  elsif M = Berry_Bush then
                     Bu.Ripe := Bu.Ripe + 1;
                  end if;   --  dug up or built over: gone
               end;
            end loop;
            Bu.Regrow_At := -1.0;
         end if;
      end;
   end loop;
   for K in reverse 1 .. N_Pulled loop
      if Now_Hours >= Pulled (K).At_H + Long_Float (Veg_Regrow_Days) * 24.0 then
         declare
            X : constant Integer := Integer (Pulled (K).P.X);
            Y : constant Integer := Integer (Pulled (K).P.Y);
            Z : constant Integer := Integer (Pulled (K).P.Z);
            CX : constant Integer := Floor_Div (X, Chunk_B);
            CY : constant Integer := Floor_Div (Y, Chunk_B);
         begin
            --  (not where a house has been begun since: in its doorway, say)
            if Mat (X, Y, Z) = Air and then Mat (X, Y, Z - 1) in Grass | Dirt
              and then not (N_Houses > 0 and then In_A_House (X, Y, Z))
            then
               Write_Src (X, Y, Z, (Mat => Wild_Vegetables, State => 0));
               if CX in Sources'Range (1) and then CY in Sources'Range (2) then
                  Sources (CX, CY) := Sources (CX, CY) or Source_Bit (Vegetables);
               end if;
            end if;
         end;
         Pulled (K) := Pulled (N_Pulled);
         N_Pulled := N_Pulled - 1;
      end if;
   end loop;
end Regrow;
