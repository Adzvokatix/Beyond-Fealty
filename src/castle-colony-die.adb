separate (Castle.Colony)
procedure Die (I : Positive) is
   M : Member renames Band (I);
begin
   if M.State in To_Eat | To_Seat then
      Unreserve_Food (M);
   end if;
   if M.State in To_Butcher | Butchering then
      Unreserve_Butcher (M);
   end if;
   if M.State in To_Store | Storing and then M.Cell in 1 .. N_Cells then
      Cells (M.Cell).Incoming := Cells (M.Cell).Incoming - Natural'Min (Cells (M.Cell).Incoming, M.Carried);
      if Cells (M.Cell).Count = 0 and then Cells (M.Cell).Incoming = 0 and then Cells (M.Cell).Outgoing = 0 then
         Cells (M.Cell).Kind := Nothing;
      end if;
      M.Cell := 0;
   end if;
   if M.Carry = Carcass then
      Drop_Carcass (M);
   end if;
   if M.Carry = Ladder and then M.Carried > 0 then
      N_Ladders_Lost := N_Ladders_Lost + M.Carried;      --  (lost with the rest of what it carried)
   end if;
   Release (M, I);
   M.Site := 0;
   M.Ladder_Of := 0;
   M.Use_For := For_Store;
   M.Prey := 0;
   M.Carry := Nothing;
   M.Carried := 0;
   M.Grain := 0;
   M.Route.N := 0;
   M.Pace := 0.0;
   M.Fends := False;
   M.State := Idle;
   M.Is_Dead := True;
   N_Deaths := N_Deaths + 1;
   for J in 1 .. N_Members loop
      if J /= I and then not Band (J).Is_Dead then
         Band (J).Mood := Float'Max (0.0, Band (J).Mood - Mood_Grief);
      end if;
   end loop;
end Die;
