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

   --  To the nearest patch of its house's ground that still has work in it.
   --  With none left the ground is ready.
   function Go_Level return Boolean is
      Wants : Site_Flags;
      Sum   : Site_Sums;
      Any   : Boolean := False;
   begin
      Site_Patches (H, Wants, Sum);
      for Attempt in 1 .. 3 loop
         declare
            Best   : Natural := 0;
            Best_D : Float := Float'Last;
            At_P   : Vec3 := (0.0, 0.0, 0.0);
         begin
            for P in Wants'Range loop
               if Wants (P) then
                  Any := True;
                  if not Failed (M, Site_Patch_Fail + P) then
                     declare
                        C : constant Vec3 := (Sum (P).X / Sum (P).Z, Sum (P).Y / Sum (P).Z, Pad_Z (Houses (H).F));
                        D : constant Float := Flat_Dist (C, M.Pos);
                     begin
                        if D < Best_D then
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
               return True;
            end if;
            Remember_Failure (M, Site_Patch_Fail + Best);
         end;
      end loop;
      if not Any then
         Read_Zone_Ground (Houses (H).Zone);   --  (its ground as it is made ready, before anything stands on it)
         Houses (H).Pad_Done := True;
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
      K0 := Kind_Of_Block (BP (Hs.Placed + 1).M);
      for K in Hs.Placed + 1 .. Integer'Min (BP_N, Hs.Placed + Lay_Blocks) loop
         exit when Kind_Of_Block (BP (K).M) /= K0;
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
   if H = 0 then
      for K in 1 .. N_Houses loop
         if not Houses (K).Built and then Builder_Of (K) = 0 and then not Failed (M, Site_Fail + K) then
            H := K;
            exit;
         end if;
      end loop;
      if H = 0 or else not Best_Free_Builder then
         return False;
      end if;
      M.Site := H;
   end if;
   if Failed (M, Site_Fail + H) then
      return False;
   end if;
   --  its ground first
   if not Houses (H).Pad_Done then
      if Go_Level then
         return True;
      end if;
      if not Houses (H).Pad_Done then
         Remember_Failure (M, Site_Fail + H);  --  (work left in its ground, and no way to any of it)
         return False;
      end if;
   end if;
   Blueprint_Of (H);
   if Houses (H).Placed >= BP_N then
      Finish_House (H);
      return False;
   end if;
   declare
      Hs : House_Rec renames Houses (H);
      K  : constant Item_Kind := Kind_Of_Block (BP (Hs.Placed + 1).M);
      Short : constant Natural := (if K = Nothing then 0 else House_Short (H, K));
      Free  : constant Natural := (if K = Nothing then 0 else Free_For_Building (K));
   begin
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
