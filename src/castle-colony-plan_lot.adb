separate (Castle.Colony)
procedure Plan_Lot
  (Ex, Ey             : Float;
   Ra0, Ra1, Rb0, Rb1 : Float;
   Seed               : Vec3;
   Step_B             : Natural;
   Places             : Boolean;
   Ia0, Ia1, Ib0, Ib1 : Integer := 0;
   Least              : Float := 0.0;
   Overflow           : Natural := 0;
   Clear_All          : Boolean := False;
   One_Level          : Boolean := False;
   Steep_B            : Natural := 0;
   Oa, Ob             : Float := 0.0;
   Drawn_Out          : Boolean := True;
   Keep_Feet          : Boolean := False;
   Fell_Trees         : Boolean := False)
is
   Half : constant Float := Path_Width_M / 2.0;

   --  along and across the lot's way, and back (measured from Oa, Ob: nought
   --  as a rule, and then exactly as before; a box put down whole measures
   --  from its own corner, so that its places lie on its own whole metres)
   function Fa (X, Y : Float) return Float is (X * Ex + Y * Ey - Oa);
   function Fb (X, Y : Float) return Float is (Y * Ex - X * Ey - Ob);
   function Wx (A, B : Float) return Float is ((A + Oa) * Ex - (B + Ob) * Ey);
   function Wy (A, B : Float) return Float is ((A + Oa) * Ey + (B + Ob) * Ex);

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
      if not Drawn_Out then
         return False;                      --  (a box put down whole is its box, and no more)
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
      if Path_Here (Mid (Bx, By)) or else Zone_Of_Block (Bx, By) /= 0 or else Strip_Kept (Bx, By) then
         return -1;                        --  (a path's, a zone's, or kept for the square's wall)
      end if;
      if Clear_All then                    --  (whatever stands on it is to be cleared: the ground under it)
         if Cart_On_Block (Bx, By) then
            return -1;
         end if;
         Zr := Top_By (Bx, By, Near);
         if Keep_Feet and then Zr >= 0 and then Mat (Bx, By, Zr + 1) in Trunk then
            return -1;                     --  (a tree's foot: left standing, not the lot's)
         end if;
         return (if Zr >= 0 and then Mat (Bx, By, Zr + 1) = Water then -1 else Zr);
      end if;
      Zr := Ground_Row (Bx, By, Near);
      if Fell_Trees and then (Zr < 0 or else Mat (Bx, By, Zr) in Trunk) then
         --  (a tree stands there, to be felled: the ground under its foot; under a bough alone, none)
         Zr := Top_By (Bx, By, Near);
         return (if Zr >= 0 and then Mat (Bx, By, Zr + 1) in Trunk then Zr else -1);
      end if;
      if Zr < 0 or else Mat (Bx, By, Zr) in Trunk
        or else Mat (Bx, By, Zr + 1) not in Air | Tall_Grass | Wild_Grain | Wild_Vegetables
      then
         return -1;
      end if;
      return Zr;
   end Free_Row;

   --  (Steep_B) The land's own top there: no boulder's and no tree's foot,
   --  which stand on a slope without being one.
   Ledge_In_It : Boolean := False;
   function Earth_Top (Bx, By, Row : Integer) return Boolean is
     (Mat (Bx, By, Row) /= Boulder and then Mat (Bx, By, Row + 1) not in Trunk
      and then Mat (Bx, By, Row + 1) /= Boulder);

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
   Plan_Over_N := 0;
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
                           elsif Steep_B > 0 and then Earth_Top (Gx0 + X, Gy0 + Y, Row)
                             and then Earth_Top (Gx0 + Nx, Gy0 + Ny, Zr)
                           then
                              Ledge_In_It := True;     --  (a ledge in the lot: Steep_B)
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
               Z  : Float := Castle.Nav.Surface_Z (Cx, Cy);
               Zn : Integer := B (Z) - 1;
               Fits : Boolean;
               Under_0 : constant Natural := Plan_Under_N;
            begin
               --  (a place over a tree that is to be felled: the highest floor at its middle may be the
               --  tree's top, or there is none: its height is its ground's, read from the lot's)
               if Fell_Trees and then B (Cx) - Gx0 in 0 .. W - 1 and then B (Cy) - Gy0 in 0 .. H - 1
                 and then G (B (Cx) - Gx0, B (Cy) - Gy0) >= 0
                 and then (Z < 0.0 or else abs (Zn - Integer (G (B (Cx) - Gx0, B (Cy) - Gy0))) > 2)
               then
                  Zn := Integer (G (B (Cx) - Gx0, B (Cy) - Gy0));
                  if Mat (B (Cx), B (Cy), Zn + 1) in Trunk then
                     Zn := Zn + 2;                 --  (under a foot the ground is read under its roots)
                  end if;
                  Z := Float (Zn + 1) * 0.25;
               end if;
               Fits := (Z >= 0.0 or else Clear_All) and then N_Cells + Plan_Cells_N < Max_Cells;
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
                                or else (not Clear_All and then not One_Level
                                         and then abs (Integer (G (Bx - Gx0, By - Gy0)) - Zn) > 2)
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

   --  its ground reaches Least along and across (by the middles of its
   --  block columns, a block added, a block and a half spared for a lot
   --  that lies aslant the block grid)
   if Least > 0.0 and then Plan_Refused = Lot_Ok then
      declare
         A_Lo, B_Lo : Float := Float'Last;
         A_Hi, B_Hi : Float := Float'First;
         procedure Reach (Bx, By : Integer) is
            P : constant Vec3 := Mid (Bx, By);
         begin
            A_Lo := Float'Min (A_Lo, Fa (P.X, P.Y));
            A_Hi := Float'Max (A_Hi, Fa (P.X, P.Y));
            B_Lo := Float'Min (B_Lo, Fb (P.X, P.Y));
            B_Hi := Float'Max (B_Hi, Fb (P.X, P.Y));
         end Reach;
      begin
         for K in 1 .. Plan_N loop
            Reach (Integer (Plan_Run (K).X0), Integer (Plan_Run (K).Y));
            Reach (Integer (Plan_Run (K).X1), Integer (Plan_Run (K).Y));
         end loop;
         if A_Hi - A_Lo + 0.25 < Least - 0.375 or else B_Hi - B_Lo + 0.25 < Least - 0.375 then
            Plan_Refused := Too_Small;
         end if;
      end;
   end if;

   --  Steep_B: no part of its ground rises more than that many blocks in a
   --  metre, and no ledge lies in it (the rule is with Set_Steep_Refuse).
   if Steep_B > 0 and then Plan_Refused = Lot_Ok then
      declare
         Steep : Boolean := Ledge_In_It;
      begin
         Scan :
         for X in 0 .. W - 1 loop
            for Y in 0 .. H - 1 loop
               if G (X, Y) >= 0 and then Earth_Top (Gx0 + X, Gy0 + Y, Integer (G (X, Y))) then
                  if (X + 4 <= W - 1 and then G (X + 4, Y) >= 0
                      and then abs (Integer (G (X + 4, Y)) - Integer (G (X, Y))) > Steep_B
                      and then Earth_Top (Gx0 + X + 4, Gy0 + Y, Integer (G (X + 4, Y))))
                    or else (Y + 4 <= H - 1 and then G (X, Y + 4) >= 0
                             and then abs (Integer (G (X, Y + 4)) - Integer (G (X, Y))) > Steep_B
                             and then Earth_Top (Gx0 + X, Gy0 + Y + 4, Integer (G (X, Y + 4))))
                  then
                     Steep := True;
                     exit Scan;
                  end if;
               end if;
            end loop;
         end loop Scan;
         if Steep then
            Plan_Refused := Too_Steep;
         end if;
      end;
   end if;

   --  a stockpile's overflow: up to Overflow places more, 1 m square on the
   --  lot's whole numbers in the ring just outside Ia0 .. Ia1 by Ib0 ..
   --  Ib1, each wholly on free ground that is not the lot's (no path's, no
   --  zone's, nothing standing on it but what grows and can be cut) and
   --  within half a metre of level; those nearest a path first, of equals
   --  the first found.  Their ground is the lot's from now on.
   if Places and then Overflow > 0 and then Plan_Refused = Lot_Ok then
      declare
         Most_Ring : constant Positive := 2 * (Ia1 - Ia0 + 3) + 2 * (Ib1 - Ib0 + 1);
         type Ring_Spot is record
            I, J : Integer;
            D    : Float;
         end record;
         Ring  : array (1 .. Most_Ring) of Ring_Spot;
         N     : Natural := 0;
         Taken : array (1 .. Most_Ring) of Boolean := [others => False];

         function To_Path (P : Vec3) return Float is
            D : Float := Float'Last;
         begin
            for K in 1 .. N_Near loop
               D := Float'Min (D, Seg_Dist (P, Path_List (Near_Seg (K))));
            end loop;
            return D;
         end To_Path;

         --  The square at I, J: wholly free ground (Under: how many of its
         --  block columns there are, into Plan_Under from Plan_Under_N + 1).
         function Free_Square (I, J : Integer; Under : out Natural) return Boolean is
            Cx : constant Float := Wx (Float (I) + 0.5, Float (J) + 0.5);
            Cy : constant Float := Wy (Float (I) + 0.5, Float (J) + 0.5);
            Z  : constant Float := Castle.Nav.Surface_Z (Cx, Cy);
            Zn : constant Integer := B (Z) - 1;
         begin
            Under := 0;
            if Z < 0.0 or else N_Cells + Plan_Cells_N >= Max_Cells then
               return False;
            end if;
            for Bx in B (Cx - 0.75) .. B (Cx + 0.75) loop
               for By in B (Cy - 0.75) .. B (Cy + 0.75) loop
                  declare
                     P  : constant Vec3 := Mid (Bx, By);
                     A  : constant Float := Fa (P.X, P.Y);
                     Bb : constant Float := Fb (P.X, P.Y);
                  begin
                     if A >= Float (I) and then A < Float (I + 1) and then Bb >= Float (J) and then Bb < Float (J + 1) then
                        if (Bx - Gx0 in 0 .. W - 1 and then By - Gy0 in 0 .. H - 1 and then G (Bx - Gx0, By - Gy0) >= 0)
                          or else Plan_Under_N + Under = Plan_Under'Last
                        then
                           return False;           --  (the lot's own, or no room to note it)
                        end if;
                        declare
                           Zr : constant Integer := Free_Row (Bx, By, Zn);
                        begin
                           if Zr < 0 or else abs (Zr - Zn) > 2 then
                              return False;
                           end if;
                           Under := Under + 1;
                           Plan_Under (Plan_Under_N + Under) := (Integer_16 (Bx), Integer_16 (By), Integer_16 (Zr));
                        end;
                     end if;
                  end;
               end loop;
            end loop;
            return Under > 0;
         end Free_Square;
      begin
         for I in Ia0 - 1 .. Ia1 + 1 loop
            for J in Ib0 - 1 .. Ib1 + 1 loop
               if I in Ia0 - 1 | Ia1 + 1 or else J in Ib0 - 1 | Ib1 + 1 then
                  N := N + 1;
                  Ring (N) := (I, J, To_Path ((Wx (Float (I) + 0.5, Float (J) + 0.5),
                                              Wy (Float (I) + 0.5, Float (J) + 0.5), 0.0)));
               end if;
            end loop;
         end loop;
         for Pick in 1 .. Overflow loop
            declare
               Best  : Natural := 0;
               Under : Natural;
            begin
               --  the nearest a path of those not yet looked at, until one is free
               loop
                  Best := 0;
                  for K in 1 .. N loop
                     if not Taken (K) and then (Best = 0 or else Ring (K).D < Ring (Best).D) then
                        Best := K;
                     end if;
                  end loop;
                  exit when Best = 0;
                  Taken (Best) := True;
                  exit when Free_Square (Ring (Best).I, Ring (Best).J, Under)
                    and then Plan_N + Under <= Max_Plan_Runs and then N_Runs + Plan_N + Under < Max_Zone_Runs;
               end loop;
               exit when Best = 0;
               declare
                  Cx : constant Float := Wx (Float (Ring (Best).I) + 0.5, Float (Ring (Best).J) + 0.5);
                  Cy : constant Float := Wy (Float (Ring (Best).I) + 0.5, Float (Ring (Best).J) + 0.5);
               begin
                  for K in Plan_Under_N + 1 .. Plan_Under_N + Under loop
                     Plan_N := Plan_N + 1;           --  its ground: a block column to a strip
                     Plan_Run (Plan_N) := (Y => Plan_Under (K).Y, X0 => Plan_Under (K).X, X1 => Plan_Under (K).X,
                                           Z => Plan_Under (K).Z);
                     Plan_Blocks := Plan_Blocks + 1;
                  end loop;
                  Plan_Under_N := Plan_Under_N + Under;
                  Plan_Cells_N := Plan_Cells_N + 1;
                  Plan_Cell (Plan_Cells_N) := (Cx, Cy, Castle.Nav.Surface_Z (Cx, Cy));
                  Plan_Over_N := Plan_Over_N + 1;
               end;
            end;
         end loop;
      end;
   end if;
end Plan_Lot;
