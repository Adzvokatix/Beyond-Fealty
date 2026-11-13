separate (Castle.Colony)
procedure Step_Gather (I : Positive) is
   M  : Member renames Band (I);
   Ok : Boolean;
begin
   case M.State is
      when To_Bush =>
         Keep_Route_Good (M, Ok);
         if not Ok or else M.Bush = 0 or else Bushes (M.Bush).Ripe = 0 then
            Release (M, I);
            M.State := Idle;
            M.Wait := 0.5;
         elsif Walk (M, Bushes (M.Bush).Centre, Bushes (M.Bush).Radius + 0.45) then
            M.State := Picking;
            M.Work := 0.0;
            M.Spot := Bushes (M.Bush).Centre;
         end if;

      when Picking =>
         if M.Bush = 0 then
            M.State := Idle;
            return;
         end if;
         declare
            Bu : Bush renames Bushes (M.Bush);
         begin
            M.Work := M.Work + Tick_S * Work_Rate (M, Picking);
            if M.Work >= Pick_S then
               M.Work := M.Work - Pick_S;
               --  the ripe block nearest the hands
               declare
                  Pick : Natural := 0;
                  Best : Float := Float'Last;
               begin
                  for J in 1 .. Bu.N loop
                     declare
                        P : Block_Pos renames Bu.Blocks (J);
                        C : constant Vec3 := ((Float (P.X) + 0.5) * 0.25, (Float (P.Y) + 0.5) * 0.25,
                                              (Float (P.Z) + 0.5) * 0.25);
                        D : constant Float := Flat_Dist (C, M.Pos) + 0.3 * abs (C.Z - (M.Pos.Z + 0.6));
                     begin
                        if D < Best and then Mat (Integer (P.X), Integer (P.Y), Integer (P.Z)) = Berry_Bush then
                           Best := D;
                           Pick := J;
                        end if;
                     end;
                  end loop;
                  if Pick = 0 then
                     Bu.Ripe := 0;
                  else
                     declare
                        P : Block_Pos renames Bu.Blocks (Pick);
                     begin
                        Write_Src (Integer (P.X), Integer (P.Y), Integer (P.Z), (Mat => Bare_Bush, State => 0));
                        M.Spot := ((Float (P.X) + 0.5) * 0.25, (Float (P.Y) + 0.5) * 0.25,
                                   (Float (P.Z) + 0.5) * 0.25);
                     end;
                     Bu.Ripe := Bu.Ripe - 1;
                     M.Carry := Berries;
                     M.Carried := M.Carried + 1;
                     if Bu.Regrow_At < 0.0 then
                        Bu.Regrow_At := Now_Hours + Long_Float (Regrow_Days) * 24.0;
                     end if;
                  end if;
               end;
               if Bu.Ripe = 0 or else M.Carried >= Carry_Limit (Berries) or else Has_Its_Fill (M) then
                  Release (M, I);
                  M.State := Idle;
                  M.Wait := 0.3;
               end if;
            end if;
         end;

      when To_Store =>
         Keep_Route_Good (M, Ok);
         if not Ok then
            Cells (M.Cell).Incoming := Cells (M.Cell).Incoming - M.Carried;
            if Cells (M.Cell).Count = 0 and then Cells (M.Cell).Incoming = 0 then
               Cells (M.Cell).Kind := Nothing;
            end if;
            M.Cell := 0;
            M.State := Idle;
            M.Wait := 1.0;
         elsif Walk (M, Cells (M.Cell).Centre, 0.55) then   --  at its edge, to reach in
            M.State := Storing;
            M.Work := 0.0;
            M.Spot := Cells (M.Cell).Centre;
         end if;

      when Storing =>
         M.Work := M.Work + Tick_S * Work_Rate (M, Handling);
         if M.Work >= Store_S then
            declare
               C : Cell renames Cells (M.Cell);
            begin
               C.Count := C.Count + M.Carried;
               C.Incoming := C.Incoming - M.Carried;
            end;
            M.Carried := 0;
            M.Carry := Nothing;
            M.Cell := 0;
            if M.Grain > 0 then                   --  the grain that came with the straw
               declare
                  Placed : Natural;
               begin
                  Supply (Grain, M.Grain, Placed);
                  M.Grain := M.Grain - Placed;
               end;
            end if;
            M.State := Idle;
            M.Wait := 0.5;
         end if;
      when others =>
         null;
   end case;
end Step_Gather;
