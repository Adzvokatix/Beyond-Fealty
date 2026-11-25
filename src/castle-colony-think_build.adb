separate (Castle.Colony)
function Think_Build (I : Positive) return Boolean is
   M : Member renames Band (I);
   Camp_To_Build : constant Boolean := Camp_Set and then Camp_Zone_N > 0 and then not Zones (Camp_Zone_N).Built;
   --  Logs are carried by those whose work it is: the cook, who keeps the
   --  camp, and a forester.  (Nobody else hauls logs; porters carry no wood
   --  at all.)
   Carries_Logs : constant Boolean := M.Job in Cook | Forester;

   --  There is a place for it at an extra task: it has no job, or fewer
   --  than the limit are at them (itself not counted; someone with no job
   --  is counted whether it has got there yet or not: its hands are free).
   function Has_Place return Boolean is
      N : Natural := 0;
   begin
      if M.Job = Unassigned then
         return True;
      end if;
      for J in 1 .. N_Members loop
         if J /= I and then (At_Extra_Task (J) or else (Band (J).Job = Unassigned and then not Band (J).Is_Dead)) then
            N := N + 1;
         end if;
      end loop;
      return N < Extra_Hands;
   end Has_Place;
   Place : Boolean;
   Others_At : Boolean := False;   --  Go_Patch found work it could go to, but for someone being at it

   --  To the nearest patch of ground to the fire that still has work in it
   --  (To_Fill: a hollow to tip the earth it carries into) and nobody at it.
   function Go_Patch (To_Fill : Boolean := False) return Boolean is
      Wants   : Patch_Flags;
      Sum     : Patch_Sums;
      Load    : constant Item_Kind := M.Carry;
      Loaded  : constant Natural := M.Carried;
   begin
      Patches_Wanting (Wants, Sum, To_Fill);
      Others_At := False;
      for J in 1 .. N_Members loop
         if J /= I and then not Band (J).Is_Dead and then Band (J).State in To_Patch | Tamping
           and then Band (J).Patch in Wants'Range
         then
            Others_At := Others_At
              or else (Wants (Band (J).Patch) and then not Failed (M, Patch_Fail + Band (J).Patch));
            Wants (Band (J).Patch) := False;         --  someone has that one
         end if;
      end loop;
      for Attempt in 1 .. 3 loop
         declare
            Best   : Natural := 0;
            Best_D : Float := Float'Last;
            At_P   : Vec3 := (0.0, 0.0, 0.0);
         begin
            for P in Wants'Range loop
               if Wants (P) and then not Failed (M, Patch_Fail + P) then
                  declare
                     C : constant Vec3 := (Sum (P).X / Sum (P).Z, Sum (P).Y / Sum (P).Z, 0.0);
                     D : constant Float := Flat_Dist (C, Camp_At);
                  begin
                     if D < Best_D then
                        Best_D := D;
                        Best := P;
                        At_P := C;
                     end if;
                  end;
               end if;
            end loop;
            if Best = 0 then
               return False;
            end if;
            At_P := On_Ground (At_P.X, At_P.Y);
            if Route_To (M, At_P, Patch_Reach_M) then
               Release (M, I);
               M.Carry := Load;                      --  (what it has in its hands it keeps)
               M.Carried := Loaded;
               M.Patch := Best;
               M.Spot := At_P;
               M.State := To_Patch;
               return True;
            end if;
            Remember_Failure (M, Patch_Fail + Best);
         end;
      end loop;
      return False;
   end Go_Patch;

   --  There is a hollow of the floor with nobody at it that it has not
   --  failed to get to.
   function Hollow_Free return Boolean is
      Wants : Patch_Flags;
      Sum   : Patch_Sums;
   begin
      Patches_Wanting (Wants, Sum, To_Fill => True);
      for J in 1 .. N_Members loop
         if J /= I and then not Band (J).Is_Dead and then Band (J).State in To_Patch | Tamping
           and then Band (J).Patch in Wants'Range
         then
            Wants (Band (J).Patch) := False;
         end if;
      end loop;
      return (for some P in Wants'Range => Wants (P) and then not Failed (M, Patch_Fail + P));
   end Hollow_Free;

   --  With stone in its hands for the square's walls: to the nearest patch
   --  of them that still wants any and that nobody is at.  Any: there is
   --  some still to lay, whether or not it could be gone to.
   function Go_Wall (Any : out Boolean) return Boolean is
      Plan    : Wall_Plan;
      Stone_N, Dig_N : Natural;
      Wants   : Patch_Flags;
      Sum     : Patch_Sums;
      Load    : constant Item_Kind := M.Carry;
      Loaded  : constant Natural := M.Carried;
   begin
      Plan_Walls (Plan);
      Walls_Wanting (Plan, Stone_N, Dig_N, Wants, Sum);
      Any := Stone_N > 0;
      Others_At := False;
      for J in 1 .. N_Members loop
         if J /= I and then not Band (J).Is_Dead and then Band (J).State in To_Patch | Tamping
           and then Band (J).Use_For = For_Wall and then Band (J).Patch in Wants'Range
         then
            Others_At := Others_At
              or else (Wants (Band (J).Patch) and then not Failed (M, Patch_Fail + Band (J).Patch));
            Wants (Band (J).Patch) := False;         --  someone has that one
         end if;
      end loop;
      for Attempt in 1 .. 3 loop
         declare
            Best   : Natural := 0;
            Best_D : Float := Float'Last;
            At_P   : Vec3 := (0.0, 0.0, 0.0);
         begin
            for P in Wants'Range loop
               if Wants (P) and then not Failed (M, Patch_Fail + P) then
                  declare
                     C : constant Vec3 := (Sum (P).X / Sum (P).Z, Sum (P).Y / Sum (P).Z, 0.0);
                     D : constant Float := Flat_Dist (C, M.Pos);
                  begin
                     if D < Best_D then
                        Best_D := D;
                        Best := P;
                        At_P := C;
                     end if;
                  end;
               end if;
            end loop;
            if Best = 0 then
               return False;
            end if;
            At_P := On_Ground (At_P.X, At_P.Y);
            if Route_To (M, At_P, Patch_Reach_M) then
               Release (M, I);
               M.Carry := Load;                      --  (the stone in its hands it keeps)
               M.Carried := Loaded;
               M.Use_For := For_Wall;
               M.Patch := Best;
               M.Spot := At_P;
               M.State := To_Patch;
               return True;
            end if;
            Remember_Failure (M, Patch_Fail + Best);
         end;
      end loop;
      return False;
   end Go_Wall;

   --  To a metre of planned path still to lay: of its own stretch if it has
   --  one (Mine), else of a stretch nobody has, which is its own from then
   --  on; the metre with the least way to it, weighed toward the stake (a
   --  path grows outward from it).  With no stretches: any metre nobody is at.
   function Go_Lay (Mine : Natural := 0) return Boolean is
      Laid_So_Far : constant Natural := M.Site_Laid;
      function Memo (K, Metre : Positive) return Natural is (Path_Fail + (K * 33 + Metre) mod 1_400);
      function Claimed (K, Metre : Positive) return Boolean is
        (for some J in 1 .. N_Members =>
           J /= I and then not Band (J).Is_Dead and then Band (J).State in To_Patch | Tamping
           and then Band (J).Site_Seg = K and then Band (J).Site_M = Metre);
      --  stretch K is someone else's
      function Taken (K : Positive) return Boolean is
        (Stretches_On
         and then (for some J in 1 .. N_Members =>
                     J /= I and then not Band (J).Is_Dead and then Band (J).Site_Seg = K
                     and then Band (J).State in Idle | To_Patch | Tamping));
   begin
      for Attempt in 1 .. 3 loop
         declare
            Best_K, Best_M : Natural := 0;
            Best_D : Float := Float'Last;
            At_P   : Vec3 := (0.0, 0.0, 0.0);
         begin
            for K in 1 .. N_Paths loop
               if Path_List (K).Known and then Path_List (K).Todo /= 0 and then (Mine = 0 or else K = Mine)
                 and then not Taken (K)
               then
                  for Metre in 1 .. Integer'Min (64, Path_Metres (Path_List (K))) loop
                     if Path_Todo (K, Metre) and then not Claimed (K, Metre) and then not Failed (M, Memo (K, Metre))
                     then
                        declare
                           P : constant Vec3 := Metre_Middle (Path_List (K), Metre);
                           D : constant Float := Flat_Dist (M.Pos, P) + 0.5 * Flat_Dist (Stake_At, P);
                        begin
                           if D < Best_D then
                              Best_D := D;
                              Best_K := K;
                              Best_M := Metre;
                              At_P := P;
                           end if;
                        end;
                     end if;
                  end loop;
               end if;
            end loop;
            if Best_K = 0 then
               return False;
            end if;
            if Route_To (M, At_P, 0.7) then
               Release (M, I);
               M.Site_Seg := Best_K;
               M.Site_M := Best_M;
               M.Site_Laid := Laid_So_Far;
               M.Spot := At_P;
               M.State := To_Patch;
               return True;
            end if;
            Remember_Failure (M, Memo (Best_K, Best_M));
         end;
      end loop;
      return False;
   end Go_Lay;

   --  What it turns to, if anything.
   function Decide return Boolean is
   begin
   --  earth in its hands, dug off the camp's floor or fetched for it: into
   --  a hollow of the floor if one wants it, else to a stockpile, and with
   --  nowhere to put it, thrown aside
   if M.Carried > 0 and then M.Carry = Earth then
      if Camp_To_Build and then Go_Patch (To_Fill => True) then
         M.Use_For := For_Floor;
         return True;
      end if;
      if Camp_To_Build and then Others_At then
         M.Use_For := For_Floor;                --  every hollow has someone at it: it waits for one
         M.Wait := 1.0;
         M.State := Idle;
         return True;
      end if;
      if Camp_To_Build and then Fill_Left_N > 0 then
         --  hollows there are, and none it can get to: it fetches no earth for them for a good while
         Remember_Failure (M, Hollow_Fail, Seconds => 600);
      end if;
      M.Use_For := For_Store;
      if Go_Store (I) then
         return True;
      end if;
      M.Carry := Nothing;
      M.Carried := 0;
      M.Why := Nothing_Yet;
   end if;
   --  stone in its hands for the walls of the square the colony was founded
   --  on: to where some is still to lay, and laid there; with every such
   --  place someone's, it waits for one; with none it can get to, or none
   --  left, what it has goes to a stockpile (or, with no room for it, is
   --  left lying)
   if M.Carried > 0 and then M.Use_For = For_Wall then
      declare
         Any : Boolean := False;
      begin
         if M.Carry = Stone and then Walls_On and then Camp_Square and then not Camp_To_Build
           and then not Failed (M, Wall_Fail)
         then
            if Go_Wall (Any) then
               return True;
            end if;
            if Any and then Others_At then
               M.Wait := 1.0;
               M.State := Idle;
               return True;
            end if;
            if Any then
               Remember_Failure (M, Wall_Fail, Seconds => 600);
            end if;
         end if;
      end;
      M.Use_For := For_Store;
      if not Can_Store (M) then               --  (and with nowhere to keep it, it is left lying by the wall)
         M.Carry := Nothing;
         M.Carried := 0;
      end if;
      return False;
   end if;
   --  a load for the camp's building: there with it (what is no longer
   --  wanted goes to a stockpile, and deadwood, which is not stored, is let fall)
   if M.Carried > 0 and then M.Use_For in For_Ring | For_Frame | For_Seat then
      if (M.Use_For = For_Ring and then Hearth_Short (Stone) = 0)
        or else (M.Use_For = For_Frame and then Hearth_Short (Wood) = 0)
        or else (M.Use_For = For_Seat and then Seats_Laid >= Seat_Logs and then M.Job /= Cook)
      then
         M.Use_For := For_Store;
         if M.Carry = Sticks then
            M.Carry := Nothing;
            M.Carried := 0;
         end if;
         return False;
      end if;
      if Go_Camp (I) then
         return True;
      end if;
      M.Use_For := For_Store;                --  no way to the camp
      if M.Carry = Sticks then
         M.Carry := Nothing;
         M.Carried := 0;
      end if;
      return False;
   end if;
   if M.Carried > 0 then
      return False;                          --  what it has in its hands first
   end if;
   if M.Use_For in For_Ring | For_Frame | For_Floor | For_Wall
     or else (M.Use_For not in For_Store | For_House | For_Bed and then M.Job /= Cook)
   then
      M.Use_For := For_Store;                --  an errand that came to nothing
   end if;
   --  only so many hands at extra tasks at once (the cook is never kept
   --  from the building of its own camp)
   Place := Has_Place;
   if Camp_To_Build and then (Place or else M.Job = Cook) then
      --  the trees that stand on the square the colony was founded on, felled before its ground is made
      --  under them (John, 2026-11-20: "a tree ... felled and removed anywhere else"); one that someone
      --  else is at, or that cannot be got to, leaves this one to the ground meanwhile
      if Camp_Square then
         declare
            Standing : Boolean;
         begin
            if Go_Fell_Square (I, Standing) then
               return True;
            end if;
         end;
      end if;
      --  the ground first, from the fire outward
      if Go_Patch then
         return True;
      end if;
      --  a hollow of its floor still to fill and nothing left to dig off
      --  that it can get at: with the turf's earth lying there; else with
      --  earth from the stockpile
      if Fill_Left_N > 0 and then Cut_Left_N = 0 and then Sod_Bits >= Sod_Share and then Go_Patch (To_Fill => True)
      then
         return True;
      end if;
      if Fill_Left_N > 0 and then Cut_Left_N = 0 and then Free_Stock (Earth) > 0 and then not Failed (M, Camp_Id)
        and then not Failed (M, Hollow_Fail) and then Hollow_Free
        and then Go_Take (I, Earth, Positive'Min (Fill_Left_N, Carry_Limit (Earth)), For_Floor)
      then
         return True;
      end if;
      if not Failed (M, Camp_Id) then        --  (with no way to the camp for now, nothing is fetched for it)
         --  stone for the ring: the stockpile's, else prised off a boulder,
         --  however far off the nearest is
         if Hearth_Short (Stone) > Build_Coming (For_Ring) then
            declare
               Need : constant Positive := Hearth_Short (Stone) - Build_Coming (For_Ring);
            begin
               if Free_Stock (Stone) > 0 then
                  if Go_Take (I, Stone, Positive'Min (Need, Carry_Limit (Stone)), For_Ring) then
                     return True;
                  end if;
               elsif Go_Fetch (I, Stone, Reach_M => Search_Reach, Least_M => Stone_From) then
                  M.Use_For := For_Ring;
                  return True;
               elsif M.Why = No_Source then
                  Look_Further;
               end if;
            end;
         end if;
         --  wood for the crossbar: a log from the stockpile, by one who
         --  carries logs; else deadwood from under a tree (anyone but a porter)
         if M.Job /= Porter and then Hearth_Short (Wood) > Build_Coming (For_Frame) then
            if Carries_Logs and then Free_Stock (Wood) > 0 then
               if Go_Take (I, Wood, 1, For_Frame) then
                  return True;
               end if;
            elsif Go_Sticks (I, For_Frame, Reach_M => Search_Reach) then
               return True;
            elsif M.Why = No_Source
              and then (Free_Stock (Wood) = 0
                        or else not (for some J in 1 .. N_Members =>
                                       not Band (J).Is_Dead and then Band (J).Job in Cook | Forester))
            then
               Look_Further;                 --  (not while there are logs stored and someone to bring them)
            end if;
         end if;
      end if;
   end if;
   --  a seat log, as soon as there are logs, before anything else of its own
   if Camp_Set and then Carries_Logs and then (Place or else M.Job = Cook) and then not Failed (M, Camp_Id)
     and then Seats_Laid + Build_Coming (For_Seat) < Seat_Logs
     and then Free_Stock (Wood) > 0 and then Go_Take (I, Wood, 1, For_Seat)
   then
      return True;
   end if;
   --  the lord's cart into a stockpile (John, 2026-11-13: "the cart, can they pull it into the closest
   --  stockpile zone?")
   if Place and then Go_Tow (I) then
      return True;
   end if;
   --  the trees that stand in a stockpile put down whole, felled and taken out (John, 2026-11-20:
   --  "fell the tree in the stockpile"): an extra task, as its path is
   if Place and then Box_Trees_Standing > 0 and then Go_Fell_Box (I) then
      return True;
   end if;
   --  then the paths the player has planned
   if Paths_Left_M > 0 then
      if Stretches_On and then M.Site_Seg > 0 then
         --  the next metre of its own stretch
         if Go_Lay (Mine => M.Site_Seg) then
            return True;
         end if;
         --  its stretch is laid (or what is left of it cannot be got to):
         --  after a short one, another that nobody has; else its turn is done
         --  and it goes back to its own work
         if M.Site_Laid < Natural (Path_Stretch_M) then
            M.Site_Seg := 0;
            if Go_Lay then
               return True;
            end if;
         end if;
      elsif Place and then Go_Lay then
         return True;
      end if;
   end if;
   --  then the walls and stairs of the square the colony was founded on (John, 2026-11-20: "stone wall
   --  and stair"): stone for them, a load at a time while more is wanted than is on its way: from a
   --  stockpile, what the hearth and the houses do not want of it; else prised off a boulder within
   --  the band's reach (it looks no further for them)
   if Place and then Wall_Left_N > 0 and then Walls_On and then Camp_Square and then not Camp_To_Build
     and then not Failed (M, Camp_Id) and then not Failed (M, Wall_Fail)
   then
      declare
         Need   : constant Integer := (Wall_Left_N + Wall_Per_Stone - 1) / Wall_Per_Stone - Build_Coming (For_Wall);
         Wanted : constant Natural := (if N_Houses > 0 then Houses_Short (Stone) else 0);
         Free   : constant Natural := Free_For_Building (Stone);
      begin
         if Need > 0 then
            if Free > Wanted then
               if Go_Take (I, Stone, Positive'Min (Need, Positive'Min (Carry_Limit (Stone), Free - Wanted)), For_Wall) then
                  return True;
               end if;
            elsif Go_Fetch (I, Stone, Reach_M => Search_Reach, Least_M => Stone_From) then
               M.Use_For := For_Wall;
               return True;
            else
               Remember_Failure (M, Wall_Fail, Seconds => 600);      --  (none to be had: not asked again for a while)
            end if;
         end if;
      end;
   end if;
   return False;
   end Decide;

   Turned : constant Boolean := Decide;
begin
   --  whatever else it does, its stretch of path is given up
   if M.Site_Seg > 0 and then not (Turned and then M.State = To_Patch) then
      Drop_Stretch (M);
   end if;
   return Turned;
end Think_Build;
