separate (Castle.Colony)
procedure Step_Wood (I : Positive) is
   M  : Member renames Band (I);
   Ok : Boolean;
begin
   case M.State is
      when To_Tree =>
         Keep_Route_Good (M, Ok);
         if not Ok or else M.Tree = 0 or else Trees (M.Tree).Down then
            Release (M, I);
            M.State := Idle;
            M.Wait := 0.5;
         elsif Walk (M, Tree_Base (M.Tree), Half_W (M.Tree) + 0.75) then
            M.State := Chopping;
            M.Work := 0.0;
            M.Spot := Tree_Base (M.Tree) + (0.0, 0.0, 0.8);
         end if;

      when Chopping =>
         if M.Tree = 0 or else Trees (M.Tree).Down
           or else Mat (Trees (M.Tree).Info.Bx, Trees (M.Tree).Info.By, Trees (M.Tree).Info.Bz + 1) not in Trunk
         then
            if M.Tree > 0 then
               Trees (M.Tree).Down := True;
            end if;
            Release (M, I);
            M.State := Idle;
            M.Wait := 0.5;
         else
            M.Work := M.Work + Tick_S * Work_Rate (M, Felling);
            if M.Work >= Chop_S (Trees (M.Tree).Info) then
               Fell (M.Tree, M.Pos, I);
               Release (M, I);
               M.State := Idle;
               M.Wait := 1.0;
            end if;
         end if;

      when To_Pile =>
         Keep_Route_Good (M, Ok);
         if not Ok or else M.Pile = 0 or else Piles (M.Pile).Count = 0 then
            if M.Pile > 0 and then not Ok then
               Remember_Failure (M, Pile_Base_Id + M.Pile);
            end if;
            Release (M, I);
            M.State := Idle;
            M.Wait := 0.5;
         elsif Walk (M, Piles (M.Pile).Centre, 0.8) then
            M.State := Lifting;
            M.Work := 0.0;
            M.Spot := Piles (M.Pile).Centre;
         end if;

      when Lifting =>
         M.Work := M.Work + Tick_S * Work_Rate (M, Handling);
         if M.Pile = 0 or else Piles (M.Pile).Count = 0 then
            Release (M, I);
            M.State := Idle;
            M.Wait := 0.5;
         elsif M.Work >= Lift_Log_S then
            Piles (M.Pile).Count := Piles (M.Pile).Count - 1;
            Release (M, I);              --  gives back the claim
            M.Carry := Wood;
            M.Carried := 1;
            M.State := Idle;
            M.Wait := 0.2;
         end if;

      when others =>
         null;
   end case;
end Step_Wood;
