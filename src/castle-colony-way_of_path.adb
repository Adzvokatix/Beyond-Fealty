separate (Castle.Colony)
procedure Way_Of_Path (A, C : Vec3; Ex, Ey : out Float; Dist : out Float) is

   function Cross (Ox, Oy, Px, Py, Qx, Qy : Float) return Float is ((Px - Ox) * (Qy - Oy) - (Py - Oy) * (Qx - Ox));

   --  How near the line A .. C comes to segment S (0 where they cross).
   function Gap (S : Path_Seg) return Float is
      D1 : constant Float := Cross (A.X, A.Y, C.X, C.Y, S.A.X, S.A.Y);
      D2 : constant Float := Cross (A.X, A.Y, C.X, C.Y, S.B.X, S.B.Y);
      D3 : constant Float := Cross (S.A.X, S.A.Y, S.B.X, S.B.Y, A.X, A.Y);
      D4 : constant Float := Cross (S.A.X, S.A.Y, S.B.X, S.B.Y, C.X, C.Y);
   begin
      if ((D1 > 0.0 and then D2 < 0.0) or else (D1 < 0.0 and then D2 > 0.0))
        and then ((D3 > 0.0 and then D4 < 0.0) or else (D3 < 0.0 and then D4 > 0.0))
      then
         return 0.0;
      end if;
      return Float'Min (Float'Min (Seg_Dist (A, S), Seg_Dist (C, S)),
                        Float'Min (Seg_Dist (S.A, Path_Seg'(A => A, B => C, others => <>)),
                                   Seg_Dist (S.B, Path_Seg'(A => A, B => C, others => <>))));
   end Gap;

   Best : Natural := 0;
begin
   Dist := Float'Last;
   for K in 1 .. N_Paths loop
      declare
         G : constant Float := Gap (Path_List (K));
      begin
         if G < Dist then
            Dist := G;
            Best := K;
         end if;
      end;
   end loop;
   Ex := 1.0;
   Ey := 0.0;
   if Best = 0 then
      return;
   end if;
   declare
      S  : Path_Seg renames Path_List (Best);
      Dx : Float := S.B.X - S.A.X;
      Dy : Float := S.B.Y - S.A.Y;
      L  : constant Float := Sqrt (Dx * Dx + Dy * Dy);
      T  : Float;
   begin
      if L < 0.01 then
         return;
      end if;
      Dx := Dx / L;
      Dy := Dy / L;
      --  quarter turns until it points within 45 degrees of east
      for Turn in 1 .. 3 loop
         exit when Dx > 0.0 and then abs Dy <= Dx;
         T := Dx;
         Dx := Dy;
         Dy := -T;
      end loop;
      if Dy = 0.0 then
         Dy := 0.0;               --  (never the negative nought a quarter turn leaves)
      end if;
      Ex := Dx;
      Ey := Dy;
   end;
end Way_Of_Path;
