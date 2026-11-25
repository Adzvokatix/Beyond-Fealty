separate (Castle.Colony)
procedure Think_Gather (I : Positive; Topping_Up : Boolean; Asked_Only : Boolean := False) is
   M : Member renames Band (I);
begin
   if M.Carried > 0 and then not Topping_Up then
      if Go_Store (I) then
         return;
      end if;
      M.Wait := 5.0;
      M.State := Idle;
      return;
   end if;
   if Go_Forage (I, Only => (if M.Carried > 0 then M.Carry else Nothing), Asked_Only => Asked_Only) then
      return;
   end if;
   if M.Carried > 0 then
      declare
         Why : constant Why_Idle := M.Why;
      begin
         if Go_Store (I) then
            return;
         end if;
         M.Why := (if M.Why = No_Room then No_Room else Why);
      end;
   end if;
   if Room_Gated and then M.Why in No_Room | Nearly_Full and then M.Carried = 0 then
      Wait_For_Room (I);                    --  (its leisure at the campfire, or the overflow moved in)
      return;
   end if;
   M.Wait := 4.0;
   M.State := Idle;
end Think_Gather;
