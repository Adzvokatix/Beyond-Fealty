separate (Castle.Colony)
procedure Step_Needs (I : Positive) is
   M  : Member renames Band (I);
   Ok : Boolean;
begin
   case M.State is
      when To_Eat =>
         Keep_Route_Good (M, Ok);
         if M.From_Pot then
            if not Ok or else not Camp_Set then
               Unreserve_Food (M);
               Remember_Failure (M, Camp_Id, Seconds => 20);
               M.State := Idle;
               M.Wait := 1.0;
            elsif Walk_On (M, 0.3) then                 --  at the pot: a bowl of it
               Pot_Out := Pot_Out - Natural'Min (Pot_Out, M.Ration);
               M.Ration := Natural'Min (M.Ration, Pot_Stew);
               Pot_Stew := Pot_Stew - M.Ration;
               M.Spot := Camp_At + (0.0, 0.0, 0.45);
               if M.Seat > 0 and then Route_To (M, Seat_Place (M.Seat), 0.3) then
                  M.State := To_Seat;
               else
                  M.Seat := 0;
                  Start_Eating (M, M.Ration);
               end if;
            end if;
         elsif not Ok or else M.Cell = 0 then
            Unreserve_Food (M);
            M.State := Idle;
            M.Wait := 1.0;
         elsif Walk (M, Cells (M.Cell).Centre, 0.55) then   --  at its edge, to reach in
            declare
               C   : Cell renames Cells (M.Cell);
               K   : constant Item_Kind := C.Kind;
               Per : constant Positive := Positive'Max (1, Raw_Food (K));
               Due : constant Natural := Items_For (M.Ration, Per);   --  set aside for it
               N   : constant Natural := Natural'Min (Due, C.Count);
            begin
               C.Outgoing := C.Outgoing - Natural'Min (C.Outgoing, Due);
               C.Count := C.Count - N;
               if C.Count = 0 and then C.Incoming = 0 and then C.Outgoing = 0 then
                  C.Kind := Nothing;
               end if;
               Raw_Eaten_N (K) := Raw_Eaten_N (K) + N;
               M.Spot := C.Centre;
               M.Cell := 0;
               if N = 0 then
                  M.Ration := 0;
                  M.State := Idle;
                  M.Wait := 0.5;
               else
                  Start_Eating (M, N * Per);
               end if;
            end;
         end if;

      when To_Seat =>                                  --  with its bowl, to its place at the fire
         Keep_Route_Good (M, Ok);
         if not Ok then
            M.Seat := 0;
            Start_Eating (M, M.Ration);
         elsif Walk (M, Seat_Place (M.Seat), 0.0) then
            if Flat_Dist (M.Pos, Seat_Place (M.Seat)) < 0.6 then
               M.Pos := (Seat_Place (M.Seat).X, Seat_Place (M.Seat).Y, M.Pos.Z);
            end if;
            M.Spot := Camp_At + (0.0, 0.0, 0.3);
            Start_Eating (M, M.Ration);
         end if;

      when Eating =>
         declare
            Dur : constant Float := Eat_Base_S + Eat_Per_Point_S * Float (M.Ration);
         begin
            M.Work := M.Work + Tick_S;
            M.Fed := Float'Min (1.0, M.Fed + Float (M.Ration) / Belly_Points (M) * Tick_S / Dur);
            if M.Work >= Dur then
               M.Ration := 0;
               M.From_Pot := False;
               M.Seat := 0;
               M.Fends := False;
               M.State := Idle;
               M.Wait := 0.3;
            end if;
         end;

      when To_Bed =>
         Keep_Route_Good (M, Ok);
         if not Ok then
            M.State := Idle;
            M.Wait := 2.0;
         elsif Walk (M, Bed_Spot (I), 0.3) then
            M.Route.N := 0;
            M.State := Sleeping;
            M.Spot := Bed_Facing (I);                 --  feet to the fire (at home: along its house)
         end if;

      when Sleeping =>
         if not Bedtime (M) then          --  morning
            M.State := Idle;
            M.Wait := 0.5 + 2.0 * Hash01 (M, 5);
         end if;

      when others =>
         null;
   end case;
end Step_Needs;
