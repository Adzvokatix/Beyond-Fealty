separate (Castle.Colony)
procedure Step_House (I : Positive) is
   M    : Member renames Band (I);
   H    : constant Natural := M.Site;
   Ok   : Boolean;
   Beside : Boolean := False;     --  it is going to the place chosen beside its work (Goes_Beside)
   --  the house it came for is still to be built
   Live : constant Boolean := H in 1 .. N_Houses and then not Houses (H).Built;

   --  A bout: the next blocks of its blueprint laid from what lies there,
   --  Lay_Blocks at most, as far as they are within reach of where it
   --  stands (the first always is) and nobody stands where one goes.
   procedure Lay_Bout (Laid : out Natural) is
      Hs : House_Rec renames Houses (H);
      --  from its ladder every block of the slope it stands under is within reach
      On_It : constant Boolean := At_Ladder (I);
   begin
      Laid := 0;
      Bout_Blocked := False;
      Blueprint_Of (H);
      while Hs.Placed < BP_N and then Laid < Lay_Blocks loop
         declare
            Bk : BP_Block renames BP (Hs.Placed + 1);
            K  : constant Item_Kind := Kind_Of (Bk);
            X  : constant Integer := Integer (Bk.X);
            Y  : constant Integer := Integer (Bk.Y);
            Yard : constant Boolean := Bk.S in CB.Beaten | CB.Fence | CB.Cover | CB.Smooth;
            --  a storehouse's yard is laid on the ground as it lies: its rows
            --  counted from the row over the ground's top (a covering's: the
            --  highest under it); nothing laid where something else stands
            Top : Integer := -1;
            Z  : Integer := Integer (Bk.Z);
            Skip : Boolean := False;
         begin
            if Yard then
               Yard_Row (Hs, Bk, Z, Top, Skip);
            end if;
            declare
               At_Block : constant Vec3 :=
                 ((Float (X) + 0.5) * 0.25, (Float (Y) + 0.5) * 0.25, Float (Z) * 0.25 + 0.125);
            begin
               exit when K /= Nothing and then Hs.Lying (K) = 0 and then not Skip;
               exit when Laid > 0
                 and then (if On_It and then Hs.Placed < Hs.Dress_N and then Roof_Side (Hs.F, X, Y) = Hs.Ladder then False
                           else Flat_Dist (M.Pos, At_Block) > Build_Reach_M + Reach_Slack_M);
               if not Skip and then Someone_At (X, Y, Z, But => I) then
                  if Way_On then
                     Make_Way (X, Y, Z, But => I);      --  (one standing there steps aside; one walking is let pass)
                  end if;
                  if Someone_At (X, Y, Z, But => I) then
                     Bout_Blocked := True;
                     exit;
                  end if;
               end if;
               if not Skip then
                  if Bk.S = CB.Beaten then
                     Cut_Plants (X, Y, Z);       --  (what grows on it cut, the whole of it: John, 2026-11-17,
                  end if;                        --  "Grass in the air issue when compacting ground")
                  Write_Src (X, Y, Z, (Mat => Bk.M, State => Bk.St));
                  --  a covering's post stands on its own ground: down to it
                  if Bk.S = CB.Cover and then Bk.M = Log and then Integer (Bk.Z) = Hs.F.Pad then
                     for Zf in Top + 1 .. Z - 1 loop
                        if Mat (X, Y, Zf) in Air | Tall_Grass | Wild_Grain | Wild_Vegetables then
                           Write_Src (X, Y, Zf, (Mat => Log, State => 0));
                        end if;
                     end loop;
                  end if;
                  if K /= Nothing then
                     Hs.Lying (K) := Hs.Lying (K) - 1;
                  end if;
               end if;
               Hs.Placed := Hs.Placed + 1;
               Laid := Laid + 1;
               M.Spot := At_Block;
            end;
         end;
      end loop;
      if Hs.Placed >= BP_N then
         Finish_House (H);
      end if;
   end Lay_Bout;

   --  A bout of taking down (a house marked for razing): its blueprint's
   --  last blocks laid come off, twice as many as a bout lays; what each
   --  took lies at the site again.  Its floor of beaten earth stays, as
   --  ground.  With none left the house is gone (Remove_House).
   procedure Raze_Bout is
      Hs : House_Rec renames Houses (H);
   begin
      Blueprint_Of (H);
      Hs.Placed := Natural'Min (Hs.Placed, BP_N);
      for N in 1 .. 2 * Lay_Blocks loop
         exit when Hs.Placed = 0;
         declare
            Bk : BP_Block renames BP (Hs.Placed);
            K  : constant Item_Kind := Kind_Of (Bk);
            X  : constant Integer := Integer (Bk.X);
            Y  : constant Integer := Integer (Bk.Y);
            Z  : constant Integer := Integer (Bk.Z);
         begin
            if Bk.S = CB.Smooth then
               --  (a covering's smoothing undone: its thatch as it was laid, stepped, until it comes off)
               declare
                  Zr, Top : Integer;
                  Skip    : Boolean;
               begin
                  Yard_Row (Hs, Bk, Zr, Top, Skip);
                  if not Skip and then Mat (X, Y, Zr) = Bk.M then
                     Write_Src (X, Y, Zr, (Mat => Bk.M, State => 0));
                  end if;
               end;
            elsif Bk.S not in CB.Floor | CB.Dress and then Bk.M /= Air and then Mat (X, Y, Z) = Bk.M then
               Write_Src (X, Y, Z, Air_Block);
            end if;
            if K /= Nothing and then Bk.S /= CB.Dress then
               Hs.Lying (K) := Hs.Lying (K) + 1;
            end if;
            Hs.Placed := Hs.Placed - 1;
         end;
      end loop;
      if Hs.Placed = 0 then
         Remove_House (H);
      end if;
   end Raze_Bout;
begin
   case M.State is
      when To_Site =>
         Beside := Goes_Beside (M);
         Keep_Route_Good (M, Ok);
         if not Ok or else not Live then
            --  (the place beside its work lost on the way: it chooses again at once, another place
            --  or the work itself; the house is not left alone for it)
            if not Ok and then H > 0 and then not Beside then
               Remember_Failure (M, Site_Fail + H, Seconds => 30);
            end if;
            M.Site_Patch := 0;
            M.State := Idle;
            M.Wait := 0.3;
         elsif Walk_On (M, (if Beside then 0.0 else 0.5)) then
            --  what it carried there is the site's now
            if M.Carried > 0 and then M.Use_For = For_House and then M.Carry = Ladder then
               --  the ladder stood under the eave of the slope that is next (of a roof none is next of: the front)
               Blueprint_Of (H);
               Houses (H).Ladder :=
                 (if Roof_Next (Houses (H)) and then Houses (H).Placed < BP_N
                  then Roof_Side (Houses (H).F, Integer (BP (Houses (H).Placed + 1).X), Integer (BP (Houses (H).Placed + 1).Y))
                  else 1);
               Houses (H).Ladder_P := M.Pos;
               Houses (H).Ladder_Fells := 0;
               M.Carry := Nothing;
               M.Carried := 0;
            elsif M.Carried > 0 and then M.Use_For = For_House and then M.Carry in Wood | Straw | Stone then
               Houses (H).Got (M.Carry) := Houses (H).Got (M.Carry) + M.Carried;
               Houses (H).Lying (M.Carry) := Houses (H).Lying (M.Carry) + M.Carried * Blocks_Per (M.Carry);
               if M.Carry = Stone then
                  Note_Stone (H, Houses (H).Stone_Left);
               end if;
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
               --  its earth moved; then, of the stone that lies there, a bout's worth laid
               Level_Patch (H, M.Site_Patch);
               declare
                  Laid : Natural;
               begin
                  Wall_Patch (H, M.Site_Patch, Natural'Min (Lay_Blocks, Houses (H).Lying (Stone)), Laid);
                  Houses (H).Lying (Stone) := Houses (H).Lying (Stone) - Laid;
                  Note_Stone (H, (if Houses (H).Stone_Left > Laid then Houses (H).Stone_Left - Laid else 0));
               end;
               if Reach_On then
                  Stand_On_Fill (H);          --  (whoever the earth or the stone closed over stands on it)
               end if;
               M.Site_Patch := 0;
               M.State := Idle;
               M.Wait := 0.2;
            end if;
         else
            M.Work := M.Work + Tick_S * Work_Rate (M, House_Raising);
            if Houses (H).Raze then
               if M.Work >= Lay_S then
                  Raze_Bout;                      --  (the house may be gone after it: H is not used again)
                  M.State := Idle;
                  M.Wait := 0.1;
               end if;
            elsif M.Work >= (if Houses (H).Placed >= Houses (H).Roof_N then Trim_S else Lay_S) then
               declare
                  Laid : Natural;
               begin
                  Lay_Bout (Laid);
                  M.State := Idle;
                  M.Wait := (if Laid = 0 then 2.0 else 0.1);
                  if Laid = 0 and then Bout_Blocked then          --  (a measure: someone stood in the way)
                     Blocked_Run (I) := Blocked_Run (I) + 2.0 + M.Work;
                     Blocked_Total := Blocked_Total + 2.0 + M.Work;
                     Blocked_Longest := Float'Max (Blocked_Longest, Blocked_Run (I));
                  else
                     Blocked_Run (I) := 0.0;
                  end if;
               end;
            end if;
         end if;

      when Making =>
         --  a ladder, of the log in its arms, where it stands
         M.Work := M.Work + Tick_S * Work_Rate (M, House_Raising);
         if M.Carry /= Wood or else M.Carried < Ladder_Wood then
            M.Use_For := For_Store;
            M.State := Idle;
            M.Wait := 0.2;
         elsif M.Work >= Ladder_S then
            M.Carry := Ladder;
            M.Carried := 1;
            M.Use_For := For_House;
            N_Ladders := N_Ladders + 1;
            M.State := Idle;
            M.Wait := 0.2;
         end if;

      when To_Ladder =>
         --  to where a ladder stands, to take it away: for its own roof if that wants one, else to a stockpile
         Keep_Route_Good (M, Ok);
         if not Ok or else M.Ladder_Of not in 1 .. N_Houses or else Houses (M.Ladder_Of).Ladder = 0 then
            if not Ok and then M.Ladder_Of in 1 .. N_Houses then
               Remember_Failure (M, Ladder_Fail + M.Ladder_Of, Seconds => 120);
            end if;
            M.Ladder_Of := 0;
            M.State := Idle;
            M.Wait := 0.5;
         elsif Walk_On (M, 0.6) then
            Houses (M.Ladder_Of).Ladder := 0;
            M.Carry := Ladder;
            M.Carried := 1;
            M.Use_For := (if Live and then Roof_Next (Houses (H)) and then Houses (H).Ladder = 0 then For_House else For_Store);
            M.Ladder_Of := 0;
            M.State := Idle;
            M.Wait := 0.3;
         end if;

      when others =>
         null;
   end case;
end Step_House;
