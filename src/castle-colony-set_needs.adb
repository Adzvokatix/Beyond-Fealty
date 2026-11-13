separate (Castle.Colony)
procedure Set_Needs (On : Boolean) is
begin
   if On = Needs_On then
      return;
   end if;
   Needs_On := On;
   if not On then                       --  nobody on the way to eat or to bed
      for I in 1 .. N_Members loop
         declare
            M : Member renames Band (I);
         begin
            if M.State in To_Eat | Eating | To_Bed | Sleeping | To_Seat then
               if M.State in To_Eat | To_Seat then
                  Unreserve_Food (M);
               end if;
               M.Ration := 0;
               M.From_Pot := False;
               M.Seat := 0;
               M.Route.N := 0;
               M.State := Idle;
               M.Wait := 0.0;
            end if;
         end;
      end loop;
   end if;
end Set_Needs;
