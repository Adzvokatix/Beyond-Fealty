with Ada.Numerics.Elementary_Functions; use Ada.Numerics.Elementary_Functions;
with Interfaces;     use Interfaces;
with Castle.Dims;    use Castle.Dims;
with Castle.Fields;  use Castle.Fields;
with Castle.Geology; use Castle.Geology;
with Castle.Hash;    use Castle.Hash;
with Castle.Noise;   use Castle.Noise;

package body Castle.Buildings.Layout is

   function Cell_X (H : House; U, V : Integer) return Integer is (H.Fx + U * H.Ux + V * H.Vx);
   function Cell_Y (H : House; U, V : Integer) return Integer is (H.Fy + U * H.Uy + V * H.Vy);

   -----------
   -- Level --
   -----------

   procedure Level (W : World; H : House; Id : Positive; Occ : Occupancy) is
   begin
      for V in -Apron_B .. H.D - 1 + Apron_B loop
         for U in -Apron_B .. H.W - 1 + Apron_B loop
            declare
               Bx : constant Integer := Cell_X (H, U, V);
               By : constant Integer := Cell_Y (H, U, V);
               Du : constant Integer := (if U < 0 then -U elsif U >= H.W then U - H.W + 1 else 0);
               Dv : constant Integer := (if V < 0 then -V elsif V >= H.D then V - H.D + 1 else 0);
               D  : constant Integer := Integer'Max (Du, Dv);
            begin
               if Bx in Occ'Range (1) and then By in Occ'Range (2)
                 and then (Occ (Bx, By) <= 0 or else Occ (Bx, By) = Id)
               then
                  declare
                     Old     : constant Integer := Surface_B (W, Bx, By);
                     New_Top : constant Integer :=
                       (if D = 0 then H.Pad
                        else H.Pad + Integer'Max (-D, Integer'Min (D, Old - H.Pad)));
                  begin
                     Column (Bx, By, Old, New_Top);
                  end;
               end if;
            end;
         end loop;
      end loop;
   end Level;

   -------------
   -- Lay_Out --
   -------------

   function Seg_Dist (Px, Py : Float; A, B : Point) return Float is
      Dx : constant Float := B.X - A.X;
      Dy : constant Float := B.Y - A.Y;
      L2 : constant Float := Dx * Dx + Dy * Dy;
      T  : constant Float :=
        (if L2 > 0.0 then Clamp (((Px - A.X) * Dx + (Py - A.Y) * Dy) / L2, 0.0, 1.0) else 0.0);
   begin
      return Sqrt ((Px - (A.X + T * Dx)) ** 2 + (Py - (A.Y + T * Dy)) ** 2);
   end Seg_Dist;

   procedure Lay_Out
     (W : World; Net : Network; X0, Y0, X1, Y1 : Integer; Residents : Positive; P : out Plan)
   is
      Seed : constant U64 := Derive (W.Seed, 4000);

      type Attach is record
         Way            : Positive := 1;
         Side           : Integer  := 1;
         Dist           : Float    := 0.0;
         Px, Py, Tx, Ty : Float    := 0.0;
      end record;
      Attaches : array (1 .. 2_048) of Attach;
      N_At     : Natural := 0;

      type Verdict is (Clear, On_Path, Blocked);

      function In_Zone (Bx, By : Integer) return Boolean is
        (Bx in P.Occ'Range (1) and then By in P.Occ'Range (2));

      --  Shared_Id > 0: the column U = Shared_U (and the ring beyond it) may
      --  belong to house Shared_Id.
      function Check (H : House; Shared_Id : Natural; Shared_U : Integer) return Verdict is
         Lo   : Integer := Integer'Last;
         Hi   : Integer := Integer'First;
         Ring : constant Integer := (if Shared_U = 0 then -1 else H.W);
      begin
         for V in -1 .. H.D loop
            for U in -1 .. H.W loop
               declare
                  Bx     : constant Integer := Cell_X (H, U, V);
                  By     : constant Integer := Cell_Y (H, U, V);
                  Inside : constant Boolean := U in 0 .. H.W - 1 and then V in 0 .. H.D - 1;
               begin
                  if not In_Zone (Bx, By) then
                     return Blocked;
                  end if;
                  declare
                     O : constant Integer := P.Occ (Bx, By);
                  begin
                     if Inside then
                        if O = Path_Cell or else O = Margin_Cell or else O = Door_Cell then
                           return On_Path;
                        end if;
                        if W.Water (Idx (Clamp_Cell (Bx / Blocks_Per_Meter),
                                         Clamp_Cell (By / Blocks_Per_Meter))) > 0.0
                        then
                           return Blocked;
                        end if;
                        declare
                           T : constant Integer := Surface_B (W, Bx, By);
                        begin
                           Lo := Integer'Min (Lo, T);
                           Hi := Integer'Max (Hi, T);
                        end;
                     end if;
                     if O > 0
                       and then not (Shared_Id > 0 and then O = Shared_Id
                                     and then (U = Shared_U or else U = Ring))
                     then
                        return Blocked;
                     end if;
                  end;
               end;
            end loop;
         end loop;
         return (if Hi - Lo > Max_Step_B then Blocked else Clear);
      end Check;

      procedure Place (H : in out House; Dist : Float; Hk : U64) is
         Id  : constant Positive := P.Count + 1;
         Sum : Long_Long_Integer := 0;
      begin
         for V in 0 .. H.D - 1 loop
            for U in 0 .. H.W - 1 loop
               Sum := Sum + Long_Long_Integer (Surface_B (W, Cell_X (H, U, V), Cell_Y (H, U, V)));
            end loop;
         end loop;
         H.Pad           := Integer (Float (Sum) / Float (H.W * H.D));
         H.Wall_H        := Wall_H_B - 1 + Integer (Hk mod 3);
         H.Ridge_Along_U := H.W >= H.D;
         H.Dist          := Dist;

         --  Door: middle half the time, otherwise near one corner.
         declare
            Off : constant Integer :=
              (case Shift_Right (Hk, 8) mod 4 is
                  when 0 | 1  => H.W / 2 - Door_W_B / 2,
                  when 2      => 2,
                  when others => H.W - 2 - Door_W_B);
         begin
            H.Openings (1) := (Front, Off, Door_W_B, 0, Door_H_B);
            H.Open_N := 1;
         end;

         --  One to three windows: middle or near a corner, short or tall,
         --  never on a shared wall, never beside the door.
         for K in 1 .. 1 + Integer (Shift_Right (Hk, 12) mod 3) loop
            declare
               Wk   : constant U64 := Mix (Hk + U64 (K) * 977);
               Side : constant Wall_Side :=
                 (case Wk mod 4 is when 0 => Back, when 1 => Left, when 2 => Right, when others => Front);
               Len  : constant Integer := (if Side = Front or else Side = Back then H.W else H.D);
               Tall : constant Boolean := (Shift_Right (Wk, 16) and 1) = 1;
               Off  : Integer :=
                 (case Shift_Right (Wk, 8) mod 3 is when 0 => Len / 2 - 1, when 1 => 2, when others => Len - 4);
               Ok   : Boolean := not ((Side = Left and then H.Shared_Left)
                                      or else (Side = Right and then H.Shared_Right));
            begin
               if Side = Front then
                  if H.Openings (1).Offset = H.W / 2 - Door_W_B / 2 then
                     Ok := False;
                  elsif H.Openings (1).Offset < H.W / 2 then
                     Off := H.W - 4;
                  else
                     Off := 2;
                  end if;
               end if;
               for J in 1 .. H.Open_N loop
                  if H.Openings (J).Side = Side and then abs (H.Openings (J).Offset - Off) < 4 then
                     Ok := False;
                  end if;
               end loop;
               if Ok and then H.Open_N < H.Openings'Last then
                  H.Open_N := H.Open_N + 1;
                  H.Openings (H.Open_N) :=
                    (Side, Off, 2, (if Tall then 4 else 5), (if Tall then 3 else 2));
               end if;
            end;
         end loop;

         for V in 0 .. H.D - 1 loop
            for U in 0 .. H.W - 1 loop
               P.Occ (Cell_X (H, U, V), Cell_Y (H, U, V)) := Id;
            end loop;
         end loop;

         --  A woodpile against a free side wall, now and then.
         if Unit (Mix (Hk + 31)) < Woodpile_Rate then
            for Side_K in 1 .. 2 loop
               declare
                  U    : constant Integer := (if Side_K = 1 then -1 else H.W);
                  Free : Boolean := (if Side_K = 1 then not H.Shared_Left else not H.Shared_Right);
               begin
                  for V in 2 .. 5 loop
                     if not In_Zone (Cell_X (H, U, V), Cell_Y (H, U, V))
                       or else P.Occ (Cell_X (H, U, V), Cell_Y (H, U, V)) /= Free_Cell
                     then
                        Free := False;
                     end if;
                  end loop;
                  if Free then
                     H.Woodpile := Side_K;
                     for V in 2 .. 5 loop
                        P.Occ (Cell_X (H, U, V), Cell_Y (H, U, V)) := Id;
                     end loop;
                     exit;
                  end if;
               end;
            end loop;
         end if;

         --  The door path, straight out to the pathway.
         for U in H.Openings (1).Offset .. H.Openings (1).Offset + Door_W_B - 1 loop
            for T in 1 .. Max_Push_B + 8 loop
               declare
                  Bx : constant Integer := Cell_X (H, U, -T);
                  By : constant Integer := Cell_Y (H, U, -T);
               begin
                  exit when not In_Zone (Bx, By);
                  exit when P.Occ (Bx, By) = Path_Cell or else P.Occ (Bx, By) > 0;
                  P.Occ (Bx, By) := Door_Cell;
               end;
            end loop;
         end loop;

         declare
            procedure Count_Earth (Bx, By, Old_Top, New_Top : Integer) is
               pragma Unreferenced (Bx, By);
            begin
               if New_Top < Old_Top then
                  H.Cut := H.Cut + (Old_Top - New_Top);
               else
                  H.Fill := H.Fill + (New_Top - Old_Top);
               end if;
            end Count_Earth;
            procedure Measure is new Level (Count_Earth);
         begin
            Measure (W, H, Id, P.Occ.all);
         end;

         P.Count         := Id;
         P.Houses (Id)   := H;
      end Place;

      --  A neighbour sharing the host's side wall, same frontage line.
      procedure Attach_Neighbour (Host : Positive; Sgn : Integer; Hk : U64; Chain : Natural) is
         Nb : House;
      begin
         if P.Count >= Residents then
            return;
         end if;
         Nb.Ux := P.Houses (Host).Ux;
         Nb.Uy := P.Houses (Host).Uy;
         Nb.Vx := P.Houses (Host).Vx;
         Nb.Vy := P.Houses (Host).Vy;
         Nb.W  := Min_Width_B + Integer (Hk mod (Max_Width_B - Min_Width_B + 1));
         Nb.D  := Min_Depth (Nb.W) + Integer (Shift_Right (Hk, 8) mod (Depth_Var_B + 1));
         if Sgn > 0 then
            Nb.Fx := P.Houses (Host).Fx + (P.Houses (Host).W - 1) * Nb.Ux;
            Nb.Fy := P.Houses (Host).Fy + (P.Houses (Host).W - 1) * Nb.Uy;
            Nb.Shared_Left := True;
         else
            Nb.Fx := P.Houses (Host).Fx - (Nb.W - 1) * Nb.Ux;
            Nb.Fy := P.Houses (Host).Fy - (Nb.W - 1) * Nb.Uy;
            Nb.Shared_Right := True;
         end if;
         if Check (Nb, Host, (if Sgn > 0 then 0 else Nb.W - 1)) = Clear then
            declare
               Hh   : House renames P.Houses (Host);
               Gone : constant Wall_Side := (if Sgn > 0 then Right else Left);
               Kept : Natural := 0;
            begin
               if Sgn > 0 then
                  Hh.Shared_Right := True;
               else
                  Hh.Shared_Left := True;
               end if;
               for K in 1 .. Hh.Open_N loop   --  the host's windows on that wall close
                  if Hh.Openings (K).Side /= Gone then
                     Kept := Kept + 1;
                     Hh.Openings (Kept) := Hh.Openings (K);
                  end if;
               end loop;
               Hh.Open_N := Kept;
               Place (Nb, Hh.Dist + Float (Nb.W) / 8.0, Mix (Hk + 5));
               P.Shared := P.Shared + 1;
            end;
            if Chain > 0 and then Unit (Mix (Hk + 9)) < Shared_Rate * 0.5 then
               Attach_Neighbour (P.Count, Sgn, Mix (Hk + 11), Chain - 1);
            end if;
         end if;
      end Attach_Neighbour;

      procedure Try (K : Positive) is
         A  : constant Attach := Attaches (K);
         Nx : constant Float  := -A.Ty * Float (A.Side);
         Ny : constant Float  := A.Tx * Float (A.Side);
         Hk : constant U64    := Hash_2 (Seed, K, 17);
         Hw : constant Float  := Net.Ways (A.Way).Width / 2.0;
         H  : House;
      begin
         if abs Nx >= abs Ny then
            H.Vx := (if Nx > 0.0 then 1 else -1);
            H.Vy := 0;
            H.Ux := 0;
            H.Uy := 1;
         else
            H.Vx := 0;
            H.Vy := (if Ny > 0.0 then 1 else -1);
            H.Ux := 1;
            H.Uy := 0;
         end if;
         H.W := Min_Width_B + Integer (Hk mod (Max_Width_B - Min_Width_B + 1));
         H.D := Min_Depth (H.W) + Integer (Shift_Right (Hk, 8) mod (Depth_Var_B + 1));
         declare
            Pcx      : constant Integer := Floor_I (A.Px * 4.0);
            Pcy      : constant Integer := Floor_I (A.Py * 4.0);
            Base_Off : constant Integer :=
              Integer (Float'Ceiling (Hw * 4.0)) + Setback_Min_B
              + Integer (Shift_Right (Hk, 16) mod (Setback_Max_B - Setback_Min_B + 1));
            Probe_X  : constant Integer := Pcx + H.Vx * (Base_Off + 2);
            Probe_Y  : constant Integer := Pcy + H.Vy * (Base_Off + 2);
            Sgn      : constant Integer :=
              (if A.Tx * Float (H.Ux) + A.Ty * Float (H.Uy) >= 0.0 then 1 else -1);
         begin
            if not In_Zone (Probe_X, Probe_Y) or else P.Occ (Probe_X, Probe_Y) > 0 then
               return;   --  this frontage is taken
            end if;
            for Push in 0 .. Max_Push_B loop
               declare
                  Off : constant Integer := Base_Off + Push;
               begin
                  H.Fx := Pcx + H.Vx * Off - H.Ux * (H.W / 2);
                  H.Fy := Pcy + H.Vy * Off - H.Uy * (H.W / 2);
                  case Check (H, 0, 0) is
                     when Clear =>
                        Place (H, A.Dist + Float (Off) / 4.0, Mix (Hk + 1));
                        if Unit (Mix (Hk + 2)) < Shared_Rate then
                           Attach_Neighbour (P.Count, Sgn, Mix (Hk + 3), 1);
                        end if;
                        return;
                     when On_Path =>
                        null;   --  slide further off a slanting pathway
                     when Blocked =>
                        return;
                  end case;
               end;
            end loop;
         end;
      end Try;

   begin
      P.Count  := 0;
      P.Shared := 0;
      P.Occ    := new Occupancy (X0 .. X1 - 1, Y0 .. Y1 - 1);
      for X in P.Occ'Range (1) loop
         for Y in P.Occ'Range (2) loop
            P.Occ (X, Y) := Free_Cell;
         end loop;
      end loop;

      --  Rasterise the pathways and their clear margin.
      for K in 1 .. Net.Count loop
         declare
            Way : Pathway renames Net.Ways (K);
            Hw  : constant Float := Way.Width / 2.0;
         begin
            for S in 1 .. Way.Count - 1 loop
               declare
                  A   : constant Point   := Way.Pts (S);
                  B   : constant Point   := Way.Pts (S + 1);
                  Bx0 : constant Integer := Integer'Max (X0, Floor_I ((Float'Min (A.X, B.X) - Hw - 1.0) * 4.0));
                  Bx1 : constant Integer := Integer'Min (X1 - 1, Floor_I ((Float'Max (A.X, B.X) + Hw + 1.0) * 4.0));
                  By0 : constant Integer := Integer'Max (Y0, Floor_I ((Float'Min (A.Y, B.Y) - Hw - 1.0) * 4.0));
                  By1 : constant Integer := Integer'Min (Y1 - 1, Floor_I ((Float'Max (A.Y, B.Y) + Hw + 1.0) * 4.0));
               begin
                  for By in By0 .. By1 loop
                     for Bx in Bx0 .. Bx1 loop
                        declare
                           D : constant Float := Seg_Dist (Center_M (Bx), Center_M (By), A, B);
                        begin
                           if D <= Hw then
                              P.Occ (Bx, By) := Path_Cell;
                           elsif D <= Hw + 0.25 and then P.Occ (Bx, By) = Free_Cell then
                              P.Occ (Bx, By) := Margin_Cell;
                           end if;
                        end;
                     end loop;
                  end loop;
               end;
            end loop;
         end;
      end loop;

      --  Attach points every metre along both sides of every pathway.
      for K in 1 .. Net.Count loop
         declare
            Way   : Pathway renames Net.Ways (K);
            Along : Float := 0.0;
         begin
            for S in 1 .. Way.Count - 1 loop
               declare
                  A   : constant Point := Way.Pts (S);
                  B   : constant Point := Way.Pts (S + 1);
                  Len : constant Float := Sqrt ((B.X - A.X) ** 2 + (B.Y - A.Y) ** 2);
                  T   : Float := 0.5;
               begin
                  if Len > 0.01 then
                     while T < Len loop
                        for Side in -1 .. 1 loop
                           if Side /= 0 and then N_At < Attaches'Last then
                              N_At := N_At + 1;
                              Attaches (N_At) :=
                                (Way  => K, Side => Side, Dist => Way.Start_Dist + Along + T,
                                 Px   => A.X + (B.X - A.X) * T / Len, Py => A.Y + (B.Y - A.Y) * T / Len,
                                 Tx   => (B.X - A.X) / Len, Ty => (B.Y - A.Y) / Len);
                           end if;
                        end loop;
                        T := T + 1.0;
                     end loop;
                  end if;
                  Along := Along + Len;
               end;
            end loop;
         end;
      end loop;

      for I in 2 .. N_At loop   --  nearest the stake first
         declare
            Key : constant Attach := Attaches (I);
            J   : Integer := I - 1;
         begin
            while J >= 1 and then Attaches (J).Dist > Key.Dist loop
               Attaches (J + 1) := Attaches (J);
               J := J - 1;
            end loop;
            Attaches (J + 1) := Key;
         end;
      end loop;

      for K in 1 .. N_At loop
         exit when P.Count >= Residents;
         Try (K);
      end loop;
   end Lay_Out;

end Castle.Buildings.Layout;
