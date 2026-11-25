separate (Castle.Colony)
function Walk (M : in out Member; Stop_At : Vec3; Stop_Within : Float; Scale : Float := 1.0) return Boolean is
   R : Castle.Nav.Route renames M.Route;
begin
   if R.N < 2 or else M.Leg >= R.N then
      return True;
   end if;
   if Stop_Within > 0.0 and then Flat_Dist (M.Pos, Stop_At) <= Stop_Within then
      return True;
   end if;
   declare
      Seg_L : constant Float := R.Pts (M.Leg + 1).D - R.Pts (M.Leg).D;
      Seg_T : constant Float := R.Pts (M.Leg + 1).T - R.Pts (M.Leg).T;
      Want  : constant Float :=
        (if Seg_T > 0.001 and then Seg_L > 0.001 then Seg_L / Seg_T else Castle.Nav.Walk_Speed)
        * M.Speed / Castle.Nav.Walk_Speed * Scale * Vigour (M) * Pace_Now;
      Left  : constant Float := R.Pts (R.N).D - (R.Pts (M.Leg).D + M.Along);
      Move  : Float;
   begin
      if Want > M.Pace then
         M.Pace := Float'Min (Want, M.Pace + 2.0 * Tick_S);
      else
         M.Pace := Float'Max (Want, M.Pace - 3.0 * Tick_S);
      end if;
      M.Pace := Float'Max (0.05, Float'Min (M.Pace, Sqrt (2.0 * 2.0 * Float'Max (0.0, Left))));
      Move := M.Pace * Tick_S;
      while Move > 0.0 and then M.Leg < R.N loop
         declare
            L : constant Float := R.Pts (M.Leg + 1).D - R.Pts (M.Leg).D;
         begin
            if M.Along + Move < L then
               M.Along := M.Along + Move;
               Move := 0.0;
            else
               Move := Move - (L - M.Along);
               M.Leg := M.Leg + 1;
               M.Along := 0.0;
            end if;
         end;
      end loop;
      if M.Leg >= R.N then
         M.Pos := R.Pts (R.N).P;
         M.Pace := 0.0;
         return True;
      end if;
      declare
         A : constant Vec3 := R.Pts (M.Leg).P;
         C : constant Vec3 := R.Pts (M.Leg + 1).P;
         L : constant Float := R.Pts (M.Leg + 1).D - R.Pts (M.Leg).D;
         T : constant Float := (if L > 0.0 then M.Along / L else 0.0);
         X : constant Float := A.X + (C.X - A.X) * T;
         Y : constant Float := A.Y + (C.Y - A.Y) * T;
         --  (in the place of the walking map the next point lies in: a point is put where the
         --  height changes, the first eighth of a metre inside the next place)
         In_Next : constant Boolean :=
           Edge_On
           and then Integer (Float'Floor (X / Castle.Nav.Cell_M)) = Integer (Float'Floor (C.X / Castle.Nav.Cell_M))
           and then Integer (Float'Floor (Y / Castle.Nav.Cell_M)) = Integer (Float'Floor (C.Y / Castle.Nav.Cell_M));
      begin
         M.Pos := (X, Y, (if In_Next then C.Z else A.Z));
      end;
   end;
   return False;
end Walk;
