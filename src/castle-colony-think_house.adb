separate (Castle.Colony)
function Think_House (I : Positive) return Boolean is
   M : Member renames Band (I);
   H : Natural := M.Site;

   --  The best at building of the foresters with no house to build takes
   --  one (of equals, the first).
   function Best_Free_Builder return Boolean is
     (for all J in 1 .. N_Members =>
        J = I or else Band (J).Is_Dead or else Band (J).Job /= Forester or else Band (J).Site /= 0
        or else Band (J).Skill (Building) < M.Skill (Building)
        or else (Band (J).Skill (Building) = M.Skill (Building) and then J > I));

   --  How far on a house is: nothing while its ground is being made ready,
   --  then by the blocks of it laid.
   function On_By (K : Positive) return Natural is (if Houses (K).Pad_Done then 1 + Houses (K).Placed else 0);
   function Further_On (A, B : Positive) return Boolean is (On_By (A) > On_By (B));

   --  To a spot the work can be done from: Spot if it can be got to (or
   --  near enough), else Other.  What it has in its hands it keeps.
   function Go_To (Spot, Other : Vec3; Hands : Vec3; Patch : Natural) return Boolean is
      Load   : constant Item_Kind := M.Carry;
      Loaded : constant Natural := M.Carried;
      Use_Of : constant Camp_Use := M.Use_For;
   begin
      if Route_To (M, Spot, Stand_Near_M) or else Route_To (M, Other, Build_Reach_M) then
         Release (M, I);
         M.Carry := Load;
         M.Carried := Loaded;
         M.Use_For := Use_Of;
         M.Site_Patch := Patch;
         M.Spot := Hands;
         M.State := To_Site;
         return True;
      end if;
      return False;
   end Go_To;

   --  To a patch of its house's site that still has work in it: earth to
   --  move, or stone to lay where some lies there.  The patches nearest its
   --  path first (its door's way among them: the ground is dug from the
   --  front back, so that whoever digs is never left in a pit), and of
   --  those the nearest to where it is.  With no work left the ground is
   --  ready.  No_Stone: stone is still to lay, and none lies there.
   function Go_Level (No_Stone_There : out Boolean) return Boolean is
      Dig, Wall : Site_Flags;
      Sum   : Site_Sums;
      Left  : Natural;
      Any   : Boolean := False;
   begin
      No_Stone_There := False;
      Site_Patches (H, Dig, Wall, Sum, Left);
      Note_Stone (H, Left);
      for Attempt in 1 .. 3 loop
         declare
            Best   : Natural := 0;
            Best_B : Natural := Natural'Last;
            Best_D : Float := Float'Last;
            At_P   : Vec3 := (0.0, 0.0, 0.0);
         begin
            for P in Dig'Range loop
               if Dig (P) or else Wall (P) then
                  Any := True;
                  if Wall (P) and then Houses (H).Lying (Stone) = 0 then
                     No_Stone_There := True;
                  elsif not Failed (M, Site_Patch_Fail + P) then
                     declare
                        C : constant Vec3 := (Sum (P).X / Sum (P).Z, Sum (P).Y / Sum (P).Z, Pad_Z (Houses (H).F));
                        D : constant Float := Flat_Dist (C, M.Pos);
                     begin
                        if Patch_Band (P) < Best_B or else (Patch_Band (P) = Best_B and then D < Best_D) then
                           Best_B := Patch_Band (P);
                           Best_D := D;
                           Best := P;
                           At_P := C;
                        end if;
                     end;
                  end if;
               end if;
            end loop;
            if Best = 0 then
               exit;
            end if;
            if Go_To (At_P, At_P, At_P, Best) then
               No_Stone_There := False;
               return True;
            end if;
            Remember_Failure (M, Site_Patch_Fail + Best);
         end;
      end loop;
      if not Any then
         Read_Zone_Ground (Houses (H).Zone);   --  (its ground as it is made ready, before anything stands on it)
         Houses (H).Pad_Done := True;
         Houses (H).Lying (Stone) := 0;        --  (what is left of the last stone is rubble)
         Note_Stone (H, 0);
      end if;
      return False;
   end Go_Level;

   --  To where the next blocks of its house are laid from: beside the
   --  middle of them, outside the walls for what is at or near a wall,
   --  inside for the rest.
   function Go_Lay return Boolean is
      Hs  : House_Rec renames Houses (H);
      F   : CB.House renames Hs.F;
      Su, Sv : Float := 0.0;
      N   : Natural := 0;
      K0  : Item_Kind;
      Fw  : constant Float := Float (F.W);
      Fd  : constant Float := Float (F.D);
   begin
      Blueprint_Of (H);
      if Hs.Placed >= BP_N then
         return False;
      end if;
      --  the roof, from a ladder: with one in its arms, to under the eave
      --  of the slope that is next, to stand it there; with one standing
      --  under that eave, to its foot
      if Ladders_On and then Roof_Next (Hs) then
         declare
            Bk   : BP_Block renames BP (Hs.Placed + 1);
            Side : constant Positive := Roof_Side (F, Integer (Bk.X), Integer (Bk.Y));
            Hand : constant Vec3 :=
              ((Float (Bk.X) + 0.5) * 0.25, (Float (Bk.Y) + 0.5) * 0.25, Float (Bk.Z) * 0.25 + 0.125);
         begin
            if M.Carry = Ladder and then M.Carried > 0 then
               if Go_To (Ladder_Place (F, Side, Stand_Off_B), Ladder_Place (F, Side, 0.0), Hand, 0) then
                  return True;
               end if;
               Remember_Failure (M, Ladder_Fail + H, Seconds => 600);   --  (nowhere to stand it: from the ground, then)
               return False;
            elsif Hs.Ladder = Side and then not Failed (M, Ladder_Fail + H) then
               if Route_To (M, Hs.Ladder_P, 0.5) then
                  Release (M, I);
                  M.Site_Patch := 0;
                  M.Spot := Hand;
                  M.State := To_Site;
                  return True;
               end if;
               Remember_Failure (M, Ladder_Fail + H, Seconds => 300);   --  (no way to it: from the ground)
            end if;
         end;
      elsif M.Carry = Ladder and then M.Carried > 0 then
         return False;                         --  (no roof to stand it at: to a stockpile with it)
      end if;
      K0 := Kind_Of (BP (Hs.Placed + 1));
      for K in Hs.Placed + 1 .. Integer'Min (BP_N, Hs.Placed + Lay_Blocks) loop
         exit when Kind_Of (BP (K)) /= K0;
         Su := Su + Float (H_U (F, Integer (BP (K).X), Integer (BP (K).Y)));
         Sv := Sv + Float (H_V (F, Integer (BP (K).X), Integer (BP (K).Y)));
         N := N + 1;
      end loop;
      Su := Su / Float (N);
      Sv := Sv / Float (N);
      declare
         Mid   : constant Vec3 := H_Point (F, Su, Sv);
         First : constant Vec3 :=
           ((Float (BP (Hs.Placed + 1).X) + 0.5) * 0.25, (Float (BP (Hs.Placed + 1).Y) + 0.5) * 0.25,
            Float (BP (Hs.Placed + 1).Z) * 0.25 + 0.125);
         Tu : Float := Su;
         Tv : Float := Sv;
      begin
         if not (Su in Stand_In_B .. Fw - 1.0 - Stand_In_B and then Sv in Stand_In_B .. Fd - 1.0 - Stand_In_B) then
            --  out through the nearest wall, Stand_Off_B clear of it
            declare
               D_Left  : constant Float := Su;
               D_Right : constant Float := Fw - 1.0 - Su;
               D_Front : constant Float := Sv;
               D_Back  : constant Float := Fd - 1.0 - Sv;
               Least   : constant Float := Float'Min (Float'Min (D_Left, D_Right), Float'Min (D_Front, D_Back));
            begin
               if Least = D_Front then
                  Tv := -Stand_Off_B;
               elsif Least = D_Back then
                  Tv := Fd - 1.0 + Stand_Off_B;
               elsif Least = D_Left then
                  Tu := -Stand_Off_B;
               else
                  Tu := Fw - 1.0 + Stand_Off_B;
               end if;
               Tu := Float'Max (-Stand_Off_B, Float'Min (Fw - 1.0 + Stand_Off_B, Tu));
               Tv := Float'Max (-Stand_Off_B, Float'Min (Fd - 1.0 + Stand_Off_B, Tv));
            end;
         end if;
         return Go_To (H_Point (F, Tu, Tv), Mid, First, 0);
      end;
   end Go_Lay;

begin
   if M.Job /= Forester or else N_Houses = 0 then
      return False;
   end if;
   if H > 0 and then (H > N_Houses or else Houses (H).Built) then
      M.Site := 0;                             --  (it stands: its builder is free)
      H := 0;
   end if;
   --  a load for its house: there with it (with no way, or no house any
   --  more, to a stockpile)
   if M.Carried > 0 then
      if M.Use_For /= For_House then
         return False;
      end if;
      if H > 0 and then not Failed (M, Site_Fail + H) then
         if Go_Lay then
            return True;
         end if;
         Remember_Failure (M, Site_Fail + H);
      end if;
      M.Use_For := For_Store;
      return False;
   end if;
   if M.Use_For = For_House then
      M.Use_For := For_Store;
   end if;
   --  a ladder left standing at a hovel that is built: back to a stockpile
   --  with it while there is room there (its own roof, if that wants one,
   --  has it instead: below)
   if Ladders_On and then not (H > 0 and then Roof_Next (Houses (H)) and then Houses (H).Ladder = 0)
     and then Room_For (Ladder)
   then
      declare
         K : constant Natural := Spare_Ladder (I);
      begin
         if K > 0 and then Go_Ladder (I, K) then
            return True;
         end if;
      end;
   end if;
   --  The house it builds: the one furthest on of those nobody is
   --  building, and its own if that is not behind them.  A house left half
   --  built (its builder sent to other work, or dead) is taken up before
   --  one barely begun, so its builder's own goes back to whoever is free
   --  (John, 2026-11-13: "I then sent him back to cooking mid build and it
   --  didn't free up the assignment for the build": the other forester was
   --  levelling the ground of a third hovel, and kept at it).
   declare
      Best : Natural := 0;
   begin
      for K in 1 .. N_Houses loop
         if K /= H and then not Houses (K).Built and then Builder_Of (K) = 0 and then not Failed (M, Site_Fail + K)
           and then (Best = 0 or else Further_On (K, Best))
         then
            Best := K;
         end if;
      end loop;
      if H > 0 and then Best > 0 and then Further_On (Best, H) then
         H := Best;                               --  (what of its own lies at its site stays there)
         M.Site := H;
         M.Site_Patch := 0;
      elsif H = 0 then
         if Best = 0 or else not Best_Free_Builder then
            return False;
         end if;
         H := Best;
         M.Site := H;
      end if;
   end;
   if Failed (M, Site_Fail + H) then
      return False;
   end if;
   --  its ground first: the earth, and the walls of stone that hold it
   if not Houses (H).Pad_Done then
      declare
         No_Stone_There : Boolean;
      begin
         if Go_Level (No_Stone_There) then
            return True;
         end if;
         if not Houses (H).Pad_Done and then No_Stone_There then
            declare
               Short : constant Natural := House_Short (H, Stone);
               Free  : constant Natural := Free_For_Building (Stone);
            begin
               if Short > 0 and then Free > 0
                 and then Go_Take (I, Stone, Positive'Min (Short, Positive'Min (Carry_Limit (Stone), Free)), For_House)
               then
                  return True;
               end if;
               M.Why := No_Stone;              --  (it goes on as the forester it is)
               return False;
            end;
         elsif not Houses (H).Pad_Done then
            Remember_Failure (M, Site_Fail + H);  --  (work left in its ground, and no way to any of it)
            return False;
         end if;
      end;
   end if;
   Blueprint_Of (H);
   if Houses (H).Placed >= BP_N then
      Finish_House (H);
      return False;
   end if;
   declare
      Hs : House_Rec renames Houses (H);
      K  : constant Item_Kind := Kind_Of (BP (Hs.Placed + 1));
      Short : constant Natural := (if K = Nothing then 0 else House_Short (H, K));
      Free  : constant Natural := (if K = Nothing then 0 else Free_For_Building (K));
   begin
      --  its roof is thatched from a ladder: with none at the house, one
      --  left at a hovel that stands, or one from a stockpile, or one made
      --  there of a log that building may take; with one under the other
      --  eave, that one carried round.  With none to be had, from the
      --  ground as it was.
      if Ladders_On and then Roof_Next (Hs) and then not Failed (M, Ladder_Fail + H) then
         if Hs.Ladder = 0 then
            declare
               Spare : constant Natural := Spare_Ladder (I);
            begin
               if Spare > 0 and then Go_Ladder (I, Spare) then
                  return True;
               end if;
               if Free_Stock (Ladder) > 0 and then Go_Take (I, Ladder, 1, For_House) then
                  return True;
               end if;
               if Free_For_Building (Wood) >= Ladder_Wood and then Go_Take (I, Wood, Ladder_Wood, For_Ladder) then
                  return True;
               end if;
               --  no log in the stores that building may take: it goes and fells for one, as the
               --  forester it is (the log is asked for with the house's timber), a tree or two at the most
               if Free_For_Building (Wood) < Ladder_Wood and then Hs.Ladder_Fells < Ladder_Fells_Most
                 and then Own_Logs (I) = 0 and then Go_Fell (I)
               then
                  Hs.Ladder_Fells := Hs.Ladder_Fells + 1;
                  return True;
               end if;
            end;
         elsif Hs.Ladder /= Roof_Side (Hs.F, Integer (BP (Hs.Placed + 1).X), Integer (BP (Hs.Placed + 1).Y)) then
            if Go_Ladder (I, H) then
               return True;
            end if;
         end if;
      end if;
      --  what takes nothing is done, and what lies there is laid; then
      --  more is fetched
      if K = Nothing or else Hs.Lying (K) > 0 then
         if Go_Lay then
            return True;
         end if;
         Remember_Failure (M, Site_Fail + H);
         return False;
      end if;
      if Short > 0 and then Free > 0
        and then Go_Take (I, K, Positive'Min (Short, Positive'Min (Carry_Limit (K), Free)), For_House)
      then
         return True;
      end if;
      --  nothing to build with: it goes on as the forester it is
      M.Why := (if K = Straw then No_Thatch else No_Timber);
      return False;
   end;
end Think_House;
