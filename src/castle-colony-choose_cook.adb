separate (Castle.Colony)
procedure Choose_Cook is
   Best : Natural := 0;
begin
   if Cook_Chosen or else not Camp_Set or else not Needs_On then
      return;
   end if;
   if Has_Cook then
      Cook_Chosen := True;
      return;
   end if;
   if Stew_Stock = 0 then
      return;
   end if;
   for I in 1 .. N_Members loop
      if not Band (I).Child and then not Band (I).Is_Dead
        and then (Best = 0 or else Cooking_Of (I) > Cooking_Of (Best))
      then
         Best := I;
      end if;
   end loop;
   if Best > 0 then
      Set_Job (Best, Cook, By => No_One);      --  its own choice: nobody gave it the job
      Cook_Chosen := True;
   end if;
end Choose_Cook;
