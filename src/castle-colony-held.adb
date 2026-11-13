separate (Castle.Colony)
function Held (K : Item_Kind) return Natural is
   Left  : Integer := Integer (Float (Store_Days) * Day_Need);
   Total : Integer := Pot_Stew + Pot_Raw;
begin
   if Store_Days = 0 or else Winter_Now or else Stew_Food (K) = 0 then
      return 0;
   end if;
   --  the store is built from surplus: a day's food (pot and stockpiles) is never held
   for J of Keep_Order loop
      Total := Total + Free_Stock (J) * Stew_Food (J);
   end loop;
   Left := Integer'Min (Left, Integer'Max (0, Total - Integer (Free_Day * Day_Need)));
   for J of Keep_Order loop
      declare
         Have_N : constant Natural := Free_Stock (J);
         Take   : constant Natural := Natural'Min (Have_N, (Integer'Max (0, Left) + Stew_Food (J) - 1) / Stew_Food (J));
      begin
         if J = K then
            return Take;
         end if;
         Left := Left - Take * Stew_Food (J);
      end;
   end loop;
   return 0;
end Held;
