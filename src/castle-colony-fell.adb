separate (Castle.Colony)
procedure Fell (K : Positive; From : Vec3; By : Positive) is
   T    : Tree_Rec renames Trees (K);
   Base : constant Vec3 := Tree_Base (K);
   Dx   : Float := Base.X - From.X;
   Dy   : Float := Base.Y - From.Y;
   L    : constant Float := Sqrt (Dx * Dx + Dy * Dy);

   --  Whether bark at (Bx, By, Bz), outside this tree's own trunk, is a
   --  neighbour's trunk: a branch drawn alone can cross a column where
   --  another tree of the same bark stands, and that trunk stays.
   function Neighbours_Trunk (Bx, By, Bz : Integer) return Boolean is
      I : constant Integer := Floor_Div (Bx, Tree_Cell_B);
      J : constant Integer := Floor_Div (By, Tree_Cell_B);
   begin
      if Find_Src = null
        or else (Bx in T.Info.Bx .. T.Info.Bx + T.Info.Trunk_W - 1
                 and then By in T.Info.By .. T.Info.By + T.Info.Trunk_W - 1)
      then
         return False;
      end if;
      declare
         N : constant Tree_Info := Find_Src (I, J);
      begin
         return N.Valid and then Bx in N.Bx .. N.Bx + N.Trunk_W - 1 and then By in N.By .. N.By + N.Trunk_W - 1
           and then Bz <= N.Bz + N.Trunk_H;
      end;
   end Neighbours_Trunk;

   procedure Take (Bx, By, Bz : Integer; M : Material) is
   begin
      if Bz > T.Info.Bz and then Mat (Bx, By, Bz) = M and then (Shape_Src /= null or else M in Trunk)
        and then not (M in Trunk and then Neighbours_Trunk (Bx, By, Bz))
        and then not (M in Trunk and then N_Houses > 0 and then In_A_House (Bx, By, Bz))   --  (a house's own timber)
      then
         Write_Src (Bx, By, Bz, Air_Block);
      end if;
   end Take;
begin
   if L > 0.01 then
      Dx := Dx / L;
      Dy := Dy / L;
   else
      Dx := 1.0;
      Dy := 0.0;
   end if;
   if Shape_Src /= null then
      Shape_Src (T.I, T.J, Take'Access);
   else
      for Z in T.Info.Bz + 1 .. T.Info.Bz + T.Info.Trunk_H loop   --  no shape known: the trunk alone
         for X in T.Info.Bx .. T.Info.Bx + T.Info.Trunk_W - 1 loop
            for Y in T.Info.By .. T.Info.By + T.Info.Trunk_W - 1 loop
               Take (X, Y, Z, Mat (X, Y, Z));   --  only if it is trunk (below)
            end loop;
         end loop;
      end loop;
   end if;
   T.Down := True;
   N_Felled := N_Felled + 1;
   declare
      R    : constant Float := Half_W (K) + 1.0;
      Px   : constant Float := Base.X + Dx * R;
      Py   : constant Float := Base.Y + Dy * R;
      Z    : constant Float := Castle.Nav.Surface_Z (Px, Py);
      Slot : Natural := 0;
   begin
      for P in 1 .. N_Piles loop
         if Piles (P).Count = 0 and then Piles (P).Claimed = 0 then
            Slot := P;
            exit;
         end if;
      end loop;
      if Slot = 0 and then N_Piles < Max_Piles then
         N_Piles := N_Piles + 1;
         Slot := N_Piles;
      end if;
      if Slot > 0 then
         Piles (Slot) := (Centre => (Px, Py, (if Z >= 0.0 then Z else Base.Z)),
                          Turn => Arctan (Dy, Dx), Count => Logs_Of (T.Info), Claimed => 0, Owner => By);
      end if;
   end;
end Fell;
