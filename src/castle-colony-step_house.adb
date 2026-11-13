separate (Castle.Colony)
procedure Step_House (I : Positive) is
   M    : Member renames Band (I);
   H    : constant Natural := M.Site;
   Ok   : Boolean;
   --  the house it came for is still to be built
   Live : constant Boolean := H in 1 .. N_Houses and then not Houses (H).Built;

   --  A bout: the next blocks of its blueprint laid from what lies there,
   --  Lay_Blocks at most, as far as they are within reach of where it
   --  stands (the first always is) and nobody stands where one goes.
   procedure Lay_Bout (Laid : out Natural) is
      Hs : House_Rec renames Houses (H);
   begin
      Laid := 0;
      Blueprint_Of (H);
      while Hs.Placed < BP_N and then Laid < Lay_Blocks loop
         declare
            Bk : BP_Block renames BP (Hs.Placed + 1);
            K  : constant Item_Kind := Kind_Of_Block (Bk.M);
            X  : constant Integer := Integer (Bk.X);
            Y  : constant Integer := Integer (Bk.Y);
            Z  : constant Integer := Integer (Bk.Z);
            At_Block : constant Vec3 := ((Float (X) + 0.5) * 0.25, (Float (Y) + 0.5) * 0.25, Float (Z) * 0.25 + 0.125);
         begin
            exit when K /= Nothing and then Hs.Lying (K) = 0;
            exit when Laid > 0 and then Flat_Dist (M.Pos, At_Block) > Build_Reach_M + Reach_Slack_M;
            exit when Someone_At (X, Y, Z, But => I);
            Write_Src (X, Y, Z, (Mat => Bk.M, State => 0));
            Hs.Placed := Hs.Placed + 1;
            if K /= Nothing then
               Hs.Lying (K) := Hs.Lying (K) - 1;
            end if;
            Laid := Laid + 1;
            M.Spot := At_Block;
         end;
      end loop;
      if Hs.Placed >= BP_N then
         Finish_House (H);
      end if;
   end Lay_Bout;
begin
   case M.State is
      when To_Site =>
         Keep_Route_Good (M, Ok);
         if not Ok or else not Live then
            if not Ok and then H > 0 then
               Remember_Failure (M, Site_Fail + H, Seconds => 30);
            end if;
            M.Site_Patch := 0;
            M.State := Idle;
            M.Wait := 0.3;
         elsif Walk_On (M, 0.5) then
            --  what it carried there is the site's now
            if M.Carried > 0 and then M.Use_For = For_House and then M.Carry in Wood | Straw then
               Houses (H).Got (M.Carry) := Houses (H).Got (M.Carry) + M.Carried;
               Houses (H).Lying (M.Carry) := Houses (H).Lying (M.Carry) + M.Carried * Blocks_Per (M.Carry);
               M.Carry := Nothing;
               M.Carried := 0;
            end if;
            M.Use_For := For_Store;
            M.State := Raising;
            M.Work := 0.0;
         end if;

      when Raising =>
         if not Live then
            M.Site_Patch := 0;
            M.State := Idle;
            M.Wait := 0.2;
         elsif M.Site_Patch > 0 then
            M.Work := M.Work + Tick_S * Work_Rate (M, Site_Work);
            if M.Work >= Tamp_S then
               Level_Patch (H, M.Site_Patch);
               M.Site_Patch := 0;
               M.State := Idle;
               M.Wait := 0.2;
            end if;
         else
            M.Work := M.Work + Tick_S * Work_Rate (M, House_Raising);
            if M.Work >= Lay_S then
               declare
                  Laid : Natural;
               begin
                  Lay_Bout (Laid);
                  M.State := Idle;
                  M.Wait := (if Laid = 0 then 2.0 else 0.1);
               end;
            end if;
         end if;

      when others =>
         null;
   end case;
end Step_House;
