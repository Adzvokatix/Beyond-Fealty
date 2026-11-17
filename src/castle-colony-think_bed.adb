separate (Castle.Colony)
function Think_Bed (I : Positive) return Boolean is
   M    : Member renames Band (I);
   --  straw in its arms that is for its bed
   Mine : constant Boolean := M.Use_For = For_Bed and then M.Carry = Straw and then M.Carried > 0;

   --  To where it sleeps, to lay what it has brought.
   function Go_Lay return Boolean is
      Load   : constant Natural := M.Carried;
   begin
      if Route_To (M, Bed_Spot (I), 0.6) then
         Release (M, I);
         M.Carry := Straw;                     --  (what it has in its arms it keeps)
         M.Carried := Load;
         M.Use_For := For_Bed;
         M.State := To_Camp;
         return True;
      end if;
      Remember_Failure (M, No_Way_Id, Seconds => 600);
      M.Use_For := For_Store;                  --  (no way there: the straw goes to a stockpile)
      return False;
   end Go_Lay;
begin
   if not Wants_Bed (I) then
      if M.Use_For = For_Bed then
         M.Use_For := For_Store;               --  (a bed it no longer has to make: its straw to a stockpile)
      end if;
      return False;
   end if;
   if M.Carried > 0 and then not Mine then
      return False;                            --  what it has in its hands first
   end if;
   if Failed (M, No_Way_Id) then                --  (no way to where it sleeps, lately)
      if Mine then
         M.Use_For := For_Store;
      end if;
      return False;
   end if;
   --  enough in its arms, or night come: to its bed's place with it
   if Mine and then (M.Carried >= Bed_Straw or else Bedtime (M)) then
      return Go_Lay;
   end if;
   --  from the stockpile, whatever the hovels being built still want of it
   --  (John, 2026-11-12: "basic needs take priority"); else cut by its own
   --  hand, unless it found none to cut lately
   if not Mine then
      declare
         Free : constant Natural := Free_Stock (Straw);
      begin
         if Free > 0 and then Go_Take (I, Straw, Positive'Min (Bed_Straw, Free), For_Bed) then
            return True;
         end if;
      end;
   end if;
   if Failed (M, Bed_Id) then
      if Mine then
         return Go_Lay;                        --  (none to add to what it has: a thin bed of that)
      end if;
      return False;
   end if;
   declare
      Load : constant Natural := M.Carried;
   begin
      if Go_Fetch (I, Straw) then
         M.Carry := (if Load > 0 then Straw else M.Carry);
         M.Carried := Load;
         M.Use_For := For_Bed;
         return True;
      end if;
   end;
   --  no more to be had now: a thin bed of what it has, or none for a while
   M.Why := Nothing_Yet;
   if Mine then
      return Go_Lay;
   end if;
   M.Use_For := For_Store;
   Remember_Failure (M, Bed_Id, Seconds => 1_800);
   return False;
end Think_Bed;
