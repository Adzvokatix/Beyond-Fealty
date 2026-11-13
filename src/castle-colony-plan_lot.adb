separate (Castle.Colony)
procedure Plan_Lot
  (Ex, Ey             : Float;
   Ra0, Ra1, Rb0, Rb1 : Float;
   Seed               : Vec3;
   Step_B             : Natural;
   Places             : Boolean;
   Ia0, Ia1, Ib0, Ib1 : Integer := 0)
is
   Half : constant Float := Path_Width_M / 2.0;

   --  along and across the lot's way, and back
   function Fa (X, Y : Float) return Float is (X * Ex + Y * Ey);
   function Fb (X, Y : Float) return Float is (Y * Ex - X * Ey);
   function Wx (A, B : Float) return Float is (A * Ex - B * Ey);
   function Wy (A, B : Float) return Float is (A * Ey + B * Ex);

   --  The block columns it is worked out over: the lot's box and the
   --  margin a side can be drawn out by.
   Margin : constant Float := Snap_M + 0.5;
   Xs : constant array (1 .. 4) of Float := [Wx (Ra0, Rb0), Wx (Ra1, Rb0), Wx (Ra1, Rb1), Wx (Ra0, Rb1)];
   Ys : constant array (1 .. 4) of Float := [Wy (Ra0, Rb0), Wy (Ra1, Rb0), Wy (Ra1, Rb1), Wy (Ra0, Rb1)];
   X_Lo : constant Float := Float'Min (Float'Min (Xs (1), Xs (2)), Float'Min (Xs (3), Xs (4)));
   X_Hi : constant Float := Float'Max (Float'Max (Xs (1), Xs (2)), Float'Max (Xs (3), Xs (4)));
   Y_Lo : constant Float := Float'Min (Float'Min (Ys (1), Ys (2)), Float'Min (Ys (3), Ys (4)));
   Y_Hi : constant Float := Float'Max (Float'Max (Ys (1), Ys (2)), Float'Max (Ys (3), Ys (4)));
   Gx0 : constant Integer := B (X_Lo - Margin);
   Gy0 : constant Integer := B (Y_Lo - Margin);
   W   : constant Integer := B (X_Hi + Margin) - Gx0 + 1;
   H   : constant Integer := B (Y_Hi + Margin) - Gy0 + 1;

   --  A block column of the lot: not looked at yet, not its ground, or the
   --  row of its ground's top once the fill has reached it.
   Unseen : constant Integer_16 := -3;
   Out_Of : constant Integer_16 := -2;
   G     : Plan_Grid renames Plan_G.all;
   Queue : Plan_Spots renames Plan_Q.all;
   Head, Tail : Natural := 0;

   --  the paths near enough to matter
   Near_Seg : array (1 .. Max_Paths) of Positive;
   N_Near   : Natural := 0;

   function Mid (Bx, By : Integer) return Vec3 is ((Float (Bx) + 0.5) * 0.25, (Float (By) + 0.5) * 0.25, 0.0);

   function Path_Here (P : Vec3) return Boolean is
   begin
      for K in 1 .. N_Near loop
         if Seg_Dist (P, Path_List (Near_Seg (K))) <= Half then
            return True;
         end if;
      end loop;
      return False;
   end Path_Here;

   --  Of the lot as drawn, or of the strip that draws one of its sides out
   --  to a path: between the side and the path's edge, where they are no
   --  more than Snap_M apart and the side faces the path.
   function Of_Lot (Bx, By : Integer) return Boolean is
      P  : constant Vec3 := Mid (Bx, By);
      A  : constant Float := Fa (P.X, P.Y);
      Bb : constant Float := Fb (P.X, P.Y);
      Da : constant Float := Float'Max (0.0, Float'Max (Ra0 - A, A - Ra1));
      Db : constant Float := Float'Max (0.0, Float'Max (Rb0 - Bb, Bb - Rb1));
      Best : Float := Float'Last;
      Fx, Fy : Float := 0.0;                --  the nearest point of a path's middle
   begin
      if A >= Ra0 and then A < Ra1 and then Bb >= Rb0 and then Bb < Rb1 then
         return True;
      end if;
      if (Da > 0.0 and then Db > 0.0) or else Da + Db > Snap_M then
         return False;                      --  out past a corner, or too far off
      end if;
      for K in 1 .. N_Near loop
         declare
            S  : Path_Seg renames Path_List (Near_Seg (K));
            Dx : constant Float := S.B.X - S.A.X;
            Dy : constant Float := S.B.Y - S.A.Y;
            L2 : constant Float := Dx * Dx + Dy * Dy;
            T  : constant Float :=
              (if L2 > 0.0 then Float'Max (0.0, Float'Min (1.0, ((P.X - S.A.X) * Dx + (P.Y - S.A.Y) * Dy) / L2))
               else 0.0);
            Qx : constant Float := S.A.X + Dx * T;
            Qy : constant Float := S.A.Y + Dy * T;
            D  : constant Float := Sqrt ((P.X - Qx) ** 2 + (P.Y - Qy) ** 2);
         begin
            if D < Best then
               Best := D;
               Fx := Qx;
               Fy := Qy;
            end if;
         end;
      end loop;
      if Best = Float'Last or else Da + Db + (Best - Half) > Snap_M + 0.001 then
         return False;
      end if;
      declare
         --  the way out of the lot here, and the way to the path
         Na : constant Float := (if Da > 0.0 then (if A < Ra0 then -1.0 else 1.0) else 0.0);
         Nb : constant Float := (if Da > 0.0 then 0.0 elsif Bb < Rb0 then -1.0 else 1.0);
         Va : constant Float := Fa (Fx - P.X, Fy - P.Y);
         Vb : constant Float := Fb (Fx - P.X, Fy - P.Y);
      begin
         return Na * Va + Nb * Vb >= Snap_Facing * Best;
      end;
   end Of_Lot;

   --  The row of the free ground at a block column near row Near: ground
   --  no path lies on and no zone has, with nothing on it but what grows
   --  and can be cut.  -1: none.
   function Free_Row (Bx, By, Near : Integer) return Integer is
      Zr : Integer;
   begin
      if Path_Here (Mid (Bx, By)) or else Zone_Of_Block (Bx, By) /= 0 then
         return -1;
      end if;
      Zr := Ground_Row (Bx, By, Near);
      if Zr < 0 or else Mat (Bx, By, Zr) in Trunk
        or else Mat (Bx, By, Zr + 1) not in Air | Tall_Grass | Wild_Grain | Wild_Vegetables
      then
         return -1;
      end if;
      return Zr;
   end Free_Row;

   procedure Push (X, Y : Integer; Row : Integer) is
   begin
      G (X, Y) := Integer_16 (Row);
      Tail := Tail + 1;
      Queue (Tail) := (Integer_16 (X), Integer_16 (Y));
   end Push;

   --  The free block of the lot nearest the seed, to fill from.
   procedure Find_Start (Found : out Boolean) is
      Sx : constant Integer := Integer'Max (0, Integer'Min (W - 1, B (Seed.X) - Gx0));
      Sy : constant Integer := Integer'Max (0, Integer'Min (H - 1, B (Seed.Y) - Gy0));
      Best_X, Best_Y, Best_Row : Integer := -1;
      Best_D : Float := Float'Last;

      procedure Try (X, Y : Integer) is
      begin
         if X in 0 .. W - 1 and then Y in 0 .. H - 1 and then Of_Lot (Gx0 + X, Gy0 + Y) then
            declare
               P  : constant Vec3 := Mid (Gx0 + X, Gy0 + Y);
               Sz : constant Float := Castle.Nav.Surface_Z (P.X, P.Y);
               D  : constant Float := Flat_Dist (P, Seed);
               Zr : constant Integer := (if Sz >= 0.0 then Free_Row (Gx0 + X, Gy0 + Y, B (Sz) - 1) else -1);
            begin
               if Zr >= 0 and then D < Best_D then
                  Best_D := D;
                  Best_X := X;
                  Best_Y := Y;
                  Best_Row := Zr;
               end if;
            end;
         end if;
      end Try;
   begin
      Found := False;
      for R in 0 .. Integer'Max (W, H) loop
         for X in Sx - R .. Sx + R loop
            Try (X, Sy - R);
            if R > 0 then
               Try (X, Sy + R);
            end if;
         end loop;
         for Y in Sy - R + 1 .. Sy + R - 1 loop
            Try (Sx - R, Y);
            Try (Sx + R, Y);
         end loop;
         --  a ring further out can hold nothing nearer than this ring's best
         exit when Best_X >= 0 and then Best_D <= Float (R) * 0.25;
      end loop;
      if Best_X >= 0 then
         Push (Best_X, Best_Y, Best_Row);
         Found := True;
      end if;
   end Find_Start;

begin
   Plan_N := 0;
   Plan_Blocks := 0;
   Plan_Cells_N := 0;
   Plan_Under_N := 0;
   Plan_At_Path := False;
   Plan_Turn := Arctan (Ey, Ex);
   Plan_Corner := [(Xs (1), Ys (1), 0.0), (Xs (2), Ys (2), 0.0), (Xs (3), Ys (3), 0.0), (Xs (4), Ys (4), 0.0)];
   if Ra1 - Ra0 > Max_Lot_M or else Rb1 - Rb0 > Max_Lot_M or else W > Max_Plan_B or else H > Max_Plan_B then
      Plan_Refused := Too_Large;
      return;
   end if;
   if Ra1 <= Ra0 or else Rb1 <= Rb0 then
      Plan_Refused := No_Ground;
      return;
   end if;
   Plan_Refused := Lot_Ok;
   for K in 1 .. N_Paths loop
      declare
         S : Path_Seg renames Path_List (K);
         R : constant Float := Margin + Half;
      begin
         if Float'Max (S.A.X, S.B.X) >= X_Lo - R and then Float'Min (S.A.X, S.B.X) <= X_Hi + R
           and then Float'Max (S.A.Y, S.B.Y) >= Y_Lo - R and then Float'Min (S.A.Y, S.B.Y) <= Y_Hi + R
         then
            N_Near := N_Near + 1;
            Near_Seg (N_Near) := K;
         end if;
      end;
   end loop;
   for X in 0 .. W - 1 loop
      for Y in 0 .. H - 1 loop
         G (X, Y) := Unseen;
      end loop;
   end loop;

   --  the fill: out from the start over free ground of the lot, a block at
   --  a time to the four sides, never up or down a ledge
   declare
      Found : Boolean;
      Dx : constant array (1 .. 4) of Integer := [1, -1, 0, 0];
      Dy : constant array (1 .. 4) of Integer := [0, 0, 1, -1];
   begin
      Find_Start (Found);
      while Head < Tail loop
         Head := Head + 1;
         declare
            X   : constant Integer := Integer (Queue (Head).X);
            Y   : constant Integer := Integer (Queue (Head).Y);
            Row : constant Integer := Integer (G (X, Y));
         begin
            for D in 1 .. 4 loop
               declare
                  Nx : constant Integer := X + Dx (D);
                  Ny : constant Integer := Y + Dy (D);
               begin
                  if Nx in 0 .. W - 1 and then Ny in 0 .. H - 1 and then G (Nx, Ny) = Unseen then
                     if Path_Here (Mid (Gx0 + Nx, Gy0 + Ny)) then
                        G (Nx, Ny) := Out_Of;
                        Plan_At_Path := True;        --  its ground comes right up to a path here
                     elsif not Of_Lot (Gx0 + Nx, Gy0 + Ny) then
                        G (Nx, Ny) := Out_Of;
                     else
                        declare
                           Zr : constant Integer := Free_Row (Gx0 + Nx, Gy0 + Ny, Row);
                        begin
                           if Zr < 0 then
                              G (Nx, Ny) := Out_Of;
                           elsif abs (Zr - Row) <= Step_B then
                              Push (Nx, Ny, Zr);
                           end if;              --  (else a ledge from here: another side may reach it)
                        end;
                     end if;
                  end if;
               end;
            end loop;
         end;
      end loop;
   end;

   --  its ground as strips: rows south to north, west to east in a row
   Rows :
   for Y in 0 .. H - 1 loop
      declare
         X : Integer := 0;
      begin
         while X < W loop
            if G (X, Y) >= 0 then
               declare
                  X0 : constant Integer := X;
                  Zr : constant Integer_16 := G (X, Y);
               begin
                  while X + 1 < W and then G (X + 1, Y) = Zr loop
                     X := X + 1;
                  end loop;
                  if Plan_N = Max_Plan_Runs or else N_Runs + Plan_N >= Max_Zone_Runs then
                     Plan_Refused := (if Plan_N = Max_Plan_Runs then Too_Large else No_Room);
                     exit Rows;
                  end if;
                  Plan_N := Plan_N + 1;
                  Plan_Run (Plan_N) := (Y => Integer_16 (Gy0 + Y), X0 => Integer_16 (Gx0 + X0),
                                        X1 => Integer_16 (Gx0 + X), Z => Zr);
                  Plan_Blocks := Plan_Blocks + X - X0 + 1;
               end;
            end if;
            X := X + 1;
         end loop;
      end;
   end loop Rows;

   --  a stockpile's places: 1 m square on the lot's whole numbers, each
   --  wholly on its ground and within half a metre of level
   if Places and then Plan_Refused = Lot_Ok then
      for I in Ia0 .. Ia1 loop
         for J in Ib0 .. Ib1 loop
            declare
               Cx : constant Float := Wx (Float (I) + 0.5, Float (J) + 0.5);
               Cy : constant Float := Wy (Float (I) + 0.5, Float (J) + 0.5);
               Z  : constant Float := Castle.Nav.Surface_Z (Cx, Cy);
               Zn : constant Integer := B (Z) - 1;
               Fits : Boolean := Z >= 0.0 and then N_Cells + Plan_Cells_N < Max_Cells;
               Under_0 : constant Natural := Plan_Under_N;
            begin
               if Fits then
                  for Bx in B (Cx - 0.75) .. B (Cx + 0.75) loop
                     for By in B (Cy - 0.75) .. B (Cy + 0.75) loop
                        declare
                           P  : constant Vec3 := Mid (Bx, By);
                           A  : constant Float := Fa (P.X, P.Y);
                           Bb : constant Float := Fb (P.X, P.Y);
                        begin
                           if A >= Float (I) and then A < Float (I + 1) and then Bb >= Float (J)
                             and then Bb < Float (J + 1)
                           then
                              if Bx - Gx0 not in 0 .. W - 1 or else By - Gy0 not in 0 .. H - 1
                                or else G (Bx - Gx0, By - Gy0) < 0
                                or else abs (Integer (G (Bx - Gx0, By - Gy0)) - Zn) > 2
                                or else Plan_Under_N = Plan_Under'Last
                              then
                                 Fits := False;
                              else
                                 Plan_Under_N := Plan_Under_N + 1;
                                 Plan_Under (Plan_Under_N) :=
                                   (Integer_16 (Bx), Integer_16 (By), G (Bx - Gx0, By - Gy0));
                              end if;
                           end if;
                        end;
                     end loop;
                  end loop;
               end if;
               if Fits and then Plan_Under_N > Under_0 then
                  Plan_Cells_N := Plan_Cells_N + 1;
                  Plan_Cell (Plan_Cells_N) := (Cx, Cy, Z);
               else
                  Plan_Under_N := Under_0;         --  not a place: its ground is not cleared
               end if;
            end;
         end loop;
      end loop;
   end if;
   if Plan_Refused = Lot_Ok and then (Plan_N = 0 or else (Places and then Plan_Cells_N = 0)) then
      Plan_Refused := No_Ground;
   end if;
end Plan_Lot;
