separate (Castle.Colony)
procedure Step_Build (I : Positive) is
   M  : Member renames Band (I);
   Ok : Boolean;
   --  it is at a metre of path (else at a patch of the camp's ground)
   At_Path : constant Boolean := M.Site_Seg in 1 .. N_Paths and then M.Site_M > 0;
   --  what it came for is still to do
   Wanted  : constant Boolean :=
     (if At_Path then Path_Todo (M.Site_Seg, M.Site_M) else M.Patch > 0 and then not Camp_Built);

   --  Done with that metre: its stretch is still its own (it thinks again,
   --  and goes on to the next of it); with no stretches, it has none.
   procedure Leave_Metre is
   begin
      M.Site_M := 0;
      if not Stretches_On then
         M.Site_Seg := 0;
         M.Site_Laid := 0;
      end if;
   end Leave_Metre;
begin
   case M.State is
      when To_Patch =>
         Keep_Route_Good (M, Ok);
         if not Ok or else not Wanted then
            if not Ok and then M.Patch > 0 then
               Remember_Failure (M, Patch_Fail + M.Patch);
            elsif not Ok and then At_Path then
               Remember_Failure (M, Path_Fail + (M.Site_Seg * 33 + M.Site_M) mod 1_400);
            end if;
            M.Patch := 0;
            Leave_Metre;
            M.State := Idle;
            M.Wait := 0.3;
         elsif Walk_On (M, 0.7) then
            M.State := Tamping;
            M.Work := 0.0;
         end if;

      when Tamping =>
         M.Work := M.Work + Tick_S * Work_Rate (M, Site_Work);
         if not Wanted then
            M.Patch := 0;
            Leave_Metre;
            M.State := Idle;
         elsif M.Work >= Tamp_S then
            if At_Path then
               Lay_Metre (M.Site_Seg, M.Site_M);
               M.Site_Laid := Natural'Min (255, M.Site_Laid + 1);
            else
               Make_Ready (M.Patch, I);
               if M.Carried > 0 and then M.Carry = Earth then
                  M.Use_For := For_Floor;            --  (what it dug off: for a hollow, if one wants it)
               end if;
               Check_Built;
            end if;
            M.Patch := 0;
            Leave_Metre;
            M.State := Idle;
            M.Wait := 0.2;
         end if;

      when others =>
         null;
   end case;
end Step_Build;
