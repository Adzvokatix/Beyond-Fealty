separate (Castle.Colony)
procedure Supply (K : Item_Kind; N : Natural; Placed : out Natural) is
   Left : Natural := N;
begin
   Placed := 0;
   if Cell_Limit (K) = 0 then
      return;
   end if;
   for Pass in 1 .. 2 loop
      for C in 1 .. N_Cells loop
         exit when Left = 0;
         declare
            Cl : Cell renames Cells (C);
         begin
            if (Pass = 1 and then Cl.Kind = K)
              or else (Pass = 2 and then Cl.Kind = Nothing and then Cl.Incoming = 0 and then not Under_Cart (C))
            then
               declare
                  Room : constant Natural := Integer'Max (0, Cell_Limit (K) - Cl.Count - Cl.Incoming);
                  Put  : constant Natural := Natural'Min (Room, Left);
               begin
                  if Put > 0 then
                     Cl.Kind := K;
                     Cl.Count := Cl.Count + Put;
                     Left := Left - Put;
                     Placed := Placed + Put;
                  end if;
               end;
            end if;
         end;
      end loop;
   end loop;
end Supply;
