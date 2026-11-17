separate (Castle.Colony)
procedure Step_Fetch (I : Positive) is
   M  : Member renames Band (I);
   Ok : Boolean;
begin
   case M.State is
      when To_Source =>
         Keep_Route_Good (M, Ok);
         declare
            --  stone: the spot beside the boulder; the rest: the thing itself
            Stop_At : constant Vec3 := (if M.Fetch = Stone then M.Goal else Centre_Of (M.Tgt));
         begin
            if not Ok or else not Source_At (M.Fetch, M.Tgt) then
               if not Ok then
                  Remember_Failure (M, Source_Id (M.Tgt));
               end if;
               M.State := Idle;
               M.Wait := 0.3;
            elsif Walk (M, Stop_At, (case M.Fetch is
                                        when Stone => 0.25, when Straw | Vegetables => 0.45,
                                        when Sticks | Apples => 1.1,
                                        when others => 0.5))
            then
               M.State := Gathering;
               M.Work := 0.0;
               M.Spot := Centre_Of (M.Tgt);
            end if;
         end;

      when Gathering =>
         M.Work := M.Work + Tick_S * Work_Rate (M, Work_For (M.Fetch));
         if M.Work >= Fetch_S (M.Fetch) and then M.Fetch = Apples then
            M.Work := 0.0;
            if M.Tree > 0 and then Apples_On (M.Tree) > 0 then
               Pick_Apple (M.Tree);
               M.Carry := Apples;
               M.Carried := M.Carried + 1;
            end if;
            if M.Carried >= Carry_Limit (Apples) or else M.Tree = 0 or else Apples_On (M.Tree) = 0
              or else Has_Its_Fill (M)
            then
               Release (M, I);
               M.State := Idle;
               M.Wait := 0.3;
            end if;
         elsif M.Work >= Fetch_S (M.Fetch) then
            M.Work := 0.0;
            if Source_At (M.Fetch, M.Tgt) then
               --  wild grain: the stalk cut to the ground, its grain kept with the straw
               if M.Fetch = Straw and then Mat (Integer (M.Tgt.X), Integer (M.Tgt.Y), Integer (M.Tgt.Z)) = Wild_Grain
               then
                  M.Grain := M.Grain + Grain_Per_Plant;
                  for Up in 1 .. 3 loop
                     exit when Mat (Integer (M.Tgt.X), Integer (M.Tgt.Y), Integer (M.Tgt.Z) + Up) /= Wild_Grain;
                     Write_Src (Integer (M.Tgt.X), Integer (M.Tgt.Y), Integer (M.Tgt.Z) + Up, Air_Block);
                  end loop;
               end if;
               if M.Fetch in Straw | Stone | Vegetables then   --  cut, prised off, pulled
                  Write_Src (Integer (M.Tgt.X), Integer (M.Tgt.Y), Integer (M.Tgt.Z), Air_Block);
               end if;
               if M.Fetch = Vegetables then
                  Remember_Pulled (M.Tgt);
               end if;
               M.Carry := M.Fetch;
               M.Carried := M.Carried + 1;
            end if;
            if M.Carried >= Carry_Limit (M.Fetch) or else Has_Its_Fill (M)
              or else (M.Use_For = For_Bed and then M.Carried >= Bed_Straw)       --  (a bed's worth, and no more)
            then
               M.State := Idle;
               M.Wait := 0.3;
            elsif Next_Near (M) then
               M.Spot := Centre_Of (M.Tgt);
            else
               M.State := Idle;                       --  more of it further off, or home
               M.Wait := 0.2;
            end if;
         end if;

      when others =>
         null;
   end case;
end Step_Fetch;
