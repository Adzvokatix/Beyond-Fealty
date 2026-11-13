separate (Castle.Colony)
procedure Step_Camp (I : Positive) is
   M  : Member renames Band (I);
   Ok : Boolean;
begin
   case M.State is
      when To_Take =>
         Keep_Route_Good (M, Ok);
         if not Ok or else M.Cell = 0 then
            if M.Cell > 0 then
               Remember_Failure (M, Cell_Base + M.Cell);
            end if;
            Release (M, I);
            M.State := Idle;
            M.Wait := 1.0;
         elsif Walk (M, Cells (M.Cell).Centre, 0.55) then
            M.State := Taking;
            M.Work := 0.0;
            M.Spot := Cells (M.Cell).Centre;
         end if;

      when Taking =>
         M.Work := M.Work + Tick_S * Work_Rate (M, Handling);
         if M.Cell = 0 then
            M.State := Idle;
         elsif M.Work >= Take_S then
            declare
               C : Cell renames Cells (M.Cell);
               K : constant Item_Kind := C.Kind;
               N : constant Natural := Natural'Min (M.Due, C.Count);
            begin
               C.Outgoing := C.Outgoing - Natural'Min (C.Outgoing, M.Due);
               C.Count := C.Count - N;
               if C.Count = 0 and then C.Incoming = 0 and then C.Outgoing = 0 then
                  C.Kind := Nothing;
               end if;
               M.Due := 0;
               M.Cell := 0;
               if N > 0 then
                  M.Carry := K;
                  M.Carried := N;
               end if;
            end;
            M.State := Idle;
            M.Wait := 0.2;
         end if;

      when To_Camp =>
         Keep_Route_Good (M, Ok);
         if not Ok or else not Camp_Set then
            Remember_Failure (M, Camp_Id, Seconds => 20);
            M.State := Idle;
            M.Wait := 2.0;
         elsif Walk_On (M, 0.3) then
            M.Work := 0.0;
            if M.Carried = 0 and then M.Use_For = For_Stoke then   --  come to put a log on the fire
               M.State := Stoking;
               M.Spot := Camp_At + (0.0, 0.0, 0.1);
            elsif M.Carried = 0 then                  --  come to stir the pot
               M.Use_For := For_Store;
               M.State := (if Pot_Raw > 0 then Cooking else Idle);
               M.Spot := Camp_At + (0.0, 0.0, 0.5);
            else
               M.State := Putting_In;
               M.Spot := (case M.Use_For is
                             when For_Fire => (if M.Carry = Sticks then Camp_At + (0.0, 0.0, 0.1)
                                               else Camp_At + Camp_Off (Stack_Off.X, Stack_Off.Y)),
                             when For_Seat => Seat_Log (Integer'Min (Seat_Logs, Seats_Laid + 1)),
                             when For_Ring | For_Frame | For_Floor | For_House => Camp_At + (0.0, 0.0, 0.1),
                             when For_Pot | For_Store | For_Stoke => Camp_At + (0.0, 0.0, 0.5));
            end if;
         end if;

      when Putting_In =>
         M.Work := M.Work + Tick_S * Work_Rate (M, Handling);
         if M.Work >= Put_In_S and then M.Use_For in For_Ring | For_Frame then
            --  for the hearth: what it is still short of is set down for it,
            --  and the rest (stone, a log) goes on to a stockpile
            declare
               K     : constant Item_Kind := (if M.Use_For = For_Ring then Stone else Wood);
               Used  : constant Natural :=
                 Natural'Min (Hearth_Short (K), (if M.Use_For = For_Ring then M.Carried else 1));
            begin
               if Camp_Zone_N > 0 then
                  Zones (Camp_Zone_N).Got (K) := Zones (Camp_Zone_N).Got (K) + Used;
               end if;
               M.Carried := (if M.Use_For = For_Frame and then Used = 1 then 0
                             elsif M.Carry = Sticks then 0 else M.Carried - Used);
               if M.Carried = 0 then
                  M.Carry := Nothing;
               end if;
            end;
            M.Use_For := For_Store;
            Check_Built;
            M.State := Idle;
            M.Wait := 0.3;
         elsif M.Work >= Put_In_S then
            case M.Use_For is
               when For_Pot =>
                  Pot_Raw := Pot_Raw + M.Carried * Stew_Food (M.Carry);
                  if M.Carry = Meat then
                     Pot_Meat := Pot_Meat + M.Carried * Stew_Food (Meat);
                  end if;
                  In_Pot_N (M.Carry) := In_Pot_N (M.Carry) + M.Carried;
               when For_Fire =>
                  if M.Carry = Sticks then
                     Feed_Fire (Sticks_Hours * Float (M.Carried));
                  elsif Labour_On and then Fuel_H <= 0.0 and then M.Carried > 0 then
                     --  the fire is down, or out: this log straight on it, any more to the stack
                     Feed_Fire (Log_Burns);
                     N_Burnt := N_Burnt + 1;
                     Fire_Logs := Fire_Logs + M.Carried - 1;
                  else
                     Fire_Logs := Fire_Logs + M.Carried;
                  end if;
               when For_Seat =>
                  if Seats_Laid < Seat_Logs then
                     Seats_Laid := Seats_Laid + 1;
                  else
                     Fire_Logs := Fire_Logs + M.Carried;
                  end if;
               when For_Store | For_Stoke | For_Ring | For_Frame | For_Floor | For_House =>
                  null;
            end case;
            M.Carry := Nothing;
            M.Carried := 0;
            M.Use_For := For_Store;
            M.State := Idle;
            M.Wait := 0.3;
         end if;

      when Cooking =>
         if Pot_Raw = 0 or else not Camp_Set then
            M.State := Idle;
            M.Wait := 0.3;
         elsif Fuel_H <= 0.0 then
            if Fire_Logs = 0 or else Labour_On then   --  out of wood, or the fire to be stoked: that first
               M.State := Idle;
               M.Wait := 0.3;
            end if;                                   --  (else the stack lights it, this step)
         else
            M.Work := M.Work + Tick_S * Work_Rate (M, Camp_Keeping);
            if M.Work >= Cook_Hours * 60.0 then
               declare
                  Mixed : constant Boolean := Pot_Meat > 0 and then Pot_Meat < Pot_Raw;
                  F     : constant Float :=
                    (if Mixed then Balanced_Bonus else 1.0) * Pot_Yield_Of (I);
                  Made  : constant Natural := Natural (Float'Floor (Float (Pot_Raw) * F + 0.5));
               begin
                  Pot_Stew := Pot_Stew + Made;
                  N_Cooked := N_Cooked + Made;
                  Pot_Raw := 0;
                  Pot_Meat := 0;
               end;
               M.State := Idle;
               M.Wait := 0.5;
            end if;
         end if;

      when Stoking =>
         M.Work := M.Work + Tick_S * Work_Rate (M, Handling);
         if M.Work >= Put_In_S then
            if Fire_Logs > 0 and then Camp_Set then
               Fire_Logs := Fire_Logs - 1;
               N_Burnt := N_Burnt + 1;
               Feed_Fire (Log_Burns);
            end if;
            M.Use_For := For_Store;
            M.State := Idle;
            M.Wait := 0.3;
         end if;

      when others =>
         null;
   end case;
end Step_Camp;
