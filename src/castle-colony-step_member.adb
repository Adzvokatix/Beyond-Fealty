separate (Castle.Colony)
procedure Step_Member (I : Positive) is
   M  : Member renames Band (I);
begin
   M.Prev := M.Pos;
   if M.Is_Dead then
      return;
   end if;
   if Needs_On then
      M.Fed := Float'Max (0.0, M.Fed - Tick_S / (Belly_Hours * 60.0)
                                      * (if M.State = Sleeping and then not Cold (I) then 0.5 else 1.0));
      --  its mood eases toward how it is living
      declare
         Fed_Mood : constant Float :=
           (if M.Fends then 0.0 elsif M.Fed <= 0.0 then Mood_Starving elsif M.Fed < Hungry_At then Mood_Hungry
            elsif M.Had_Stew then Mood_Stew else Mood_Raw);
         Target : constant Float := (if Cold (I) then Float'Min (Fed_Mood, Mood_Cold) else Fed_Mood);
      begin
         M.Mood := M.Mood + (Target - M.Mood) * (Tick_S / (Mood_Hours * 60.0));
      end;
      --  in winter, an empty belly long enough is death
      if M.Fed > 0.0 then
         M.Empty_H := 0.0;
      elsif Winter_Now then
         M.Empty_H := M.Empty_H + Tick_S / 60.0;
         if M.Empty_H >= Death_Hours then
            Die (I);
            return;
         end if;
      end if;
      --  night, or very hungry with food to be had (or, with none, to go
      --  and fend for itself): leave off at once (but a load on its way to
      --  a house is carried there first, as any load in its arms is: left
      --  off, it would be taken up again the same moment, all night)
      if Interruptible (M.State)
        and then not (M.State = To_Site and then M.Carried > 0)
        and then (Bedtime (M)
                  or else (M.Fed < Very_Hungry and then not M.Fends
                           and then ((Raw_Food (M.Carry) > 0 and then M.Use_For = For_Store)
                                     or else Food_In_Store or else not Failed (M, Fend_Id))))
      then
         Interrupt (M, I);
      end if;
   end if;
   --  an hour on the job is an hour of practice in the work's skill
   if Skills_On then
      Practise (M, Work_Now (M));
   end if;
   case M.State is
      when Idle =>
         if M.Wait > 0.0 then
            M.Wait := M.Wait - Tick_S;
         else
            Think (I);
         end if;

      when Strolling =>
         if Walk (M, (0.0, 0.0, 0.0), 0.0) then
            M.State := Idle;
         end if;

      when To_Eat | Eating | To_Seat | To_Bed | Sleeping =>
         Step_Needs (I);
      when To_Take | Taking | To_Camp | Putting_In | Cooking | Stoking =>
         Step_Camp (I);
      when To_Bush | Picking | To_Store | Storing =>
         Step_Gather (I);
      when To_Tree | Chopping | To_Pile | Lifting =>
         Step_Wood (I);
      when To_Source | Gathering =>
         Step_Fetch (I);
      when To_Patch | Tamping =>
         Step_Build (I);
      when To_Site | Raising | Making | To_Ladder =>
         Step_House (I);
      when Stalking | Aiming | Recovering | To_Carcass | Lifting_Carcass | To_Butcher | Butchering
         | To_Cart | At_Cart =>
         Step_Hunt (I);
      when To_Tow | Towing =>
         Step_Tow (I);
   end case;
end Step_Member;
