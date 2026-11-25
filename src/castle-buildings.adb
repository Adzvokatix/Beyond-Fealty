with Interfaces;  use Interfaces;
with Castle.Hash; use Castle.Hash;

package body Castle.Buildings is

   function Cell_X (H : House; U, V : Integer) return Integer is (H.Fx + U * H.Ux + V * H.Vx);
   function Cell_Y (H : House; U, V : Integer) return Integer is (H.Fy + U * H.Uy + V * H.Vy);

   function Min_Depth (W : Integer) return Integer is
     ((Min_Floor_B + (W - 2) - 1) / (W - 2) + 2);

   ------------
   -- Design --
   ------------

   function Design (Seed : U64; Level : Natural := 0) return House is
      pragma Unreferenced (Level);
      H  : House;
      Hk : constant U64 := Mix (Seed + 1);
   begin
      H.W := Min_Width_B + Integer (Seed mod U64 (Max_Width_B - Min_Width_B + 1));
      H.D := Integer'Min (Max_Depth_B,
                          Min_Depth (H.W) + Integer (Shift_Right (Seed, 8) mod U64 (Depth_Var_B + 1)));
      H.Wall_H := Wall_H_B - Integer (Hk mod 2);
      H.Ridge_Along_U := H.W >= H.D;

      --  The door: in the middle half the time, otherwise toward one corner.
      declare
         Off : constant Integer :=
           (case Shift_Right (Hk, 8) mod 4 is
               when 0 | 1  => H.W / 2 - Door_W_B / 2,
               when 2      => 2,
               when others => H.W - 2 - Door_W_B);
      begin
         H.Openings (1) := (Front, Off, Door_W_B, 0, Door_H_B);
         H.Open_N := 1;

         --  A small window beside it, on the wider side of the front: a block
         --  clear of the door's jamb and of the end wall's inner face.
         declare
            L_Lo : constant Integer := 2;
            L_Hi : constant Integer := Off - 3;
            R_Lo : constant Integer := Off + Door_W_B + 2;
            R_Hi : constant Integer := H.W - 3;
            L_N  : constant Integer := L_Hi - L_Lo + 1;
            R_N  : constant Integer := R_Hi - R_Lo + 1;
            On_Left : constant Boolean :=
              L_N > R_N or else (L_N = R_N and then (Shift_Right (Hk, 16) and 1) = 1);
            Lo   : constant Integer := (if On_Left then L_Lo else R_Lo);
            Room : constant Integer := (if On_Left then L_N else R_N);
         begin
            if Room >= Window_B then
               H.Open_N := H.Open_N + 1;
               H.Openings (H.Open_N) :=
                 (Front, Lo + (Room - Window_B) / 2, Window_B, Window_Up_B, Window_B);
            end if;
         end;
      end;

      --  Now and then a smaller window in another wall: in the middle or
      --  toward a corner, short or tall.
      declare
         Wk   : constant U64 := Mix (Hk + 977);
         Side : constant Wall_Side := (case Wk mod 3 is when 0 => Back, when 1 => Left, when others => Right);
         Len  : constant Integer := (if Side = Back then H.W else H.D);
         Tall : constant Boolean := (Shift_Right (Wk, 16) and 1) = 1;
         Off  : constant Integer :=
           (case Shift_Right (Wk, 8) mod 3 is when 0 => Len / 2 - 1, when 1 => 2, when others => Len - 4);
      begin
         if Unit (Mix (Hk + 31)) < 0.5 then
            H.Open_N := H.Open_N + 1;
            H.Openings (H.Open_N) := (Side, Off, 2, (if Tall then 4 else 5), (if Tall then 3 else 2));
         end if;
      end;
      return H;
   end Design;

   function Storehouse_Design (W : Positive := Store_W_B; D : Positive := Store_D_B) return House is
      H : House;
   begin
      H.Kind := Storehouse;
      H.W := W;
      H.D := D;
      H.Wall_H := Wall_H_B;
      H.Ridge_Along_U := True;                 --  (its gables at its ends, where its doors are)
      H.Floor := Plank;
      H.Openings (1) := (Left, (D - Store_Door_W_B) / 2, Store_Door_W_B, 0, Door_H_B);
      H.Openings (2) := (Right, (D - Store_Door_W_B) / 2, Store_Door_W_B, 0, Door_H_B);
      H.Open_N := 2;
      return H;
   end Storehouse_Design;

   Turn_C : constant Float := 0.707_106_78;
   --  (a turn to the left on the map is one from U toward V in a frame that is right-handed)
   function Turn_S (H : House) return Float is (Float (H.Turn * (H.Ux * H.Vy - H.Uy * H.Vx)) * Turn_C);
   function Pivot_U (H : House) return Float is
     (if H.Kind = Storehouse then H.Piv_U
      else Float (H.Openings (1).Offset) + Float (H.Openings (1).Width - 1) / 2.0);
   function Pivot_V (H : House) return Float is (if H.Kind = Storehouse then H.Piv_V else 0.0);

   procedure Back_Turn (H : House; U, V : Float; Qu, Qv : out Float) is
      Du : constant Float := U - Pivot_U (H);
      Dv : constant Float := V - Pivot_V (H);
   begin
      if H.Turn = 0 then
         Qu := U;
         Qv := V;
      else
         Qu := Pivot_U (H) + Turn_C * Du + Turn_S (H) * Dv;
         Qv := Pivot_V (H) - Turn_S (H) * Du + Turn_C * Dv;
      end if;
   end Back_Turn;

   procedure Fore_Turn (H : House; U, V : Float; Qu, Qv : out Float) is
      Du : constant Float := U - Pivot_U (H);
      Dv : constant Float := V - Pivot_V (H);
   begin
      if H.Turn = 0 then
         Qu := U;
         Qv := V;
      else
         Qu := Pivot_U (H) + Turn_C * Du - Turn_S (H) * Dv;
         Qv := Pivot_V (H) + Turn_S (H) * Du + Turn_C * Dv;
      end if;
   end Fore_Turn;

   procedure Design_Of (H : House; U, V : Integer; Du, Dv : out Integer) is
      Qu, Qv : Float;
   begin
      if Yard_Turned (H) then
         Back_Turn (H, Float (U), Float (V), Qu, Qv);
         Du := Integer (Float'Rounding (Qu));
         Dv := Integer (Float'Rounding (Qv));
      else
         Du := U;
         Dv := V;
      end if;
   end Design_Of;

   function Under_Drawn (H : House; U, V : Float; Margin : Float := 0.0) return Boolean is
      Qu, Qv : Float;
   begin
      Back_Turn (H, U, V, Qu, Qv);
      return Qu in -0.5 - Margin .. Float (H.W) - 0.5 + Margin and then Qv in -0.5 - Margin .. Float (H.D) - 0.5 + Margin;
   end Under_Drawn;

   function Drawn_Box (H : House; Margin : Float := 0.0) return Frame_Box is
      Lo_U, Lo_V : Float := Float'Last;
      Hi_U, Hi_V : Float := Float'First;
      procedure Corner (U, V : Float) is
         Au, Av : Float;
      begin
         Fore_Turn (H, U, V, Au, Av);
         Lo_U := Float'Min (Lo_U, Au);  Hi_U := Float'Max (Hi_U, Au);
         Lo_V := Float'Min (Lo_V, Av);  Hi_V := Float'Max (Hi_V, Av);
      end Corner;
   begin
      Corner (-0.5 - Margin, -0.5 - Margin);
      Corner (Float (H.W) - 0.5 + Margin, -0.5 - Margin);
      Corner (Float (H.W) - 0.5 + Margin, Float (H.D) - 0.5 + Margin);
      Corner (-0.5 - Margin, Float (H.D) - 0.5 + Margin);
      return (U0 => Integer (Float'Floor (Lo_U)), U1 => Integer (Float'Ceiling (Hi_U)),
              V0 => Integer (Float'Floor (Lo_V)), V1 => Integer (Float'Ceiling (Hi_V)));
   end Drawn_Box;

   function Covering_At (H : House; U, V : Integer) return Natural is
   begin
      if V in H.Yard_V1 - Cover_D_B .. H.Yard_V1 - 1 then
         for K in 1 .. H.Covers loop
            if U in H.Cover_U (K) .. H.Cover_U (K) + Cover_W_B - 1 then
               return K;
            end if;
         end loop;
      end if;
      return 0;
   end Covering_At;

   ---------------
   -- Blueprint --
   ---------------

   Clash_N : Natural := 0;       --  (the last blueprint's: blocks of a turned yard left out, its own blocks standing there)

   procedure Blueprint (H : House) is
      Base : constant Integer := H.Pad;
      Top  : constant Integer := Base + H.Wall_H;
      U_Lo : constant Integer := (if H.Shared_Left then 0 else -1);       --  no eave over a neighbour
      U_Hi : constant Integer := (if H.Shared_Right then H.W - 1 else H.W);

      procedure Emit (U, V, Z : Integer; M : Material; S : Stage; State : Natural := 0) is
      begin
         Put (Cell_X (H, U, V), Cell_Y (H, U, V), Z, M, S, State);
      end Emit;

      --  How a dressed block of the roof lies: Toward_V, its slope runs along
      --  V (the ridge along U), else along U; Up, it falls toward the higher
      --  V (or U); Eave, Cap: the lowest of its slope, a ridge's one middle
      --  block; End_Lo, End_Hi: it is the first of its row, or the last.
      function Lies (Toward_V, Up, Eave, Cap, End_Lo, End_Hi : Boolean) return Natural is
         --  the way it falls, and the way its row runs, on the block grid
         Fx : constant Integer := (if Toward_V then H.Vx else H.Ux) * (if Up then 1 else -1);
         Fy : constant Integer := (if Toward_V then H.Vy else H.Uy) * (if Up then 1 else -1);
         Rx : constant Integer := (if Toward_V then H.Ux else H.Vx);
         Ry : constant Integer := (if Toward_V then H.Uy else H.Vy);
         Row_Up : constant Boolean := Rx + Ry > 0;      --  its row's first block is at the low end of that axis
      begin
         return Dressed
           + (if Fx > 0 then 0 elsif Fx < 0 then 1 elsif Fy > 0 then 2 else 3)
           + (if Eave then At_Eave else 0) + (if Cap then At_Ridge else 0)
           + (if (End_Lo and then Row_Up) or else (End_Hi and then not Row_Up) then Verge_Lo else 0)
           + (if (End_Hi and then Row_Up) or else (End_Lo and then not Row_Up) then Verge_Hi else 0);
      end Lies;

      function Opening_At (U, V, Z : Integer) return Boolean is
      begin
         for K in 1 .. H.Open_N loop
            declare
               O       : Opening renames H.Openings (K);
               Along   : constant Integer := (case O.Side is when Front | Back => U, when Left | Right => V);
               On_Wall : constant Boolean :=
                 (case O.Side is
                     when Front => V = 0,
                     when Back  => V = H.D - 1,
                     when Left  => U = 0,
                     when Right => U = H.W - 1);
            begin
               if On_Wall and then Along in O.Offset .. O.Offset + O.Width - 1
                 and then Z - Base in O.Bottom .. O.Bottom + O.Height - 1
               then
                  return True;
               end if;
            end;
         end loop;
         return False;
      end Opening_At;

      --  A stud stands at P of a wall whose corners are at 0 and Last: the
      --  wall in bays as near Stud_B as divide it evenly.
      function Is_Stud (P, Last : Integer) return Boolean is
         Bays : constant Integer := Integer'Max (1, (Last + Stud_B / 2) / Stud_B);
      begin
         return (for some K in 1 .. Bays - 1 => (K * Last + Bays / 2) / Bays = P);
      end Is_Stud;

      --  A post of the frame stands at (U, V) of the walls' line: a corner,
      --  a jamb of the door, a stud about every Stud_B along a wall; never
      --  where a door or a window is, and no stud hard by a jamb.
      function Is_Post (U, V : Integer) return Boolean is
         Side_U : constant Boolean := U = 0 or else U = H.W - 1;
         Side_V : constant Boolean := V = 0 or else V = H.D - 1;
      begin
         if Side_U and then Side_V then
            return True;
         end if;
         for K in 1 .. H.Open_N loop
            declare
               O       : Opening renames H.Openings (K);
               Along   : constant Integer := (case O.Side is when Front | Back => U, when Left | Right => V);
               On_Wall : constant Boolean :=
                 (case O.Side is
                     when Front => V = 0,
                     when Back  => V = H.D - 1,
                     when Left  => U = 0,
                     when Right => U = H.W - 1);
            begin
               if On_Wall and then Along in O.Offset .. O.Offset + O.Width - 1 then
                  return False;
               end if;
            end;
         end loop;
         for K in 1 .. H.Open_N loop             --  a door's jambs, and no stud hard by one
            declare
               Door    : Opening renames H.Openings (K);
               Along   : constant Integer := (case Door.Side is when Front | Back => U, when Left | Right => V);
               On_Wall : constant Boolean :=
                 (case Door.Side is
                     when Front => V = 0,
                     when Back  => V = H.D - 1,
                     when Left  => U = 0,
                     when Right => U = H.W - 1);
            begin
               if Door.Bottom = 0 and then On_Wall then
                  if Along = Door.Offset - 1 or else Along = Door.Offset + Door.Width then
                     return True;
                  elsif Along = Door.Offset - 2 or else Along = Door.Offset + Door.Width + 1 then
                     return False;
                  end if;
               end if;
            end;
         end loop;
         return (if Side_V then Is_Stud (U, H.W - 1) else Is_Stud (V, H.D - 1));
      end Is_Post;

      --  Door jambs either side of the door and a lintel over it; a sill one
      --  block wider than each window, under it.
      function Trim_At (U, V, Z : Integer) return Boolean is
      begin
         --  (a door is an opening from the floor up: the first, in the front of a hovel; one in each end
         --  of a storehouse)
         for K in 1 .. H.Open_N loop
            declare
               Door    : Opening renames H.Openings (K);
               Along   : constant Integer := (case Door.Side is when Front | Back => U, when Left | Right => V);
               On_Wall : constant Boolean :=
                 (case Door.Side is
                     when Front => V = 0,
                     when Back  => V = H.D - 1,
                     when Left  => U = 0,
                     when Right => U = H.W - 1);
            begin
               if Door.Bottom = 0 and then On_Wall then
                  if (Along = Door.Offset - 1 or else Along = Door.Offset + Door.Width)
                    and then Z - Base in 0 .. Door.Height - 1
                  then
                     return True;
                  elsif Along in Door.Offset - 1 .. Door.Offset + Door.Width and then Z - Base = Door.Height then
                     return True;
                  end if;
               end if;
            end;
         end loop;
         for K in 2 .. H.Open_N loop
            declare
               O       : Opening renames H.Openings (K);
               Along   : constant Integer := (case O.Side is when Front | Back => U, when Left | Right => V);
               On_Wall : constant Boolean :=
                 (case O.Side is
                     when Front => V = 0,
                     when Back  => V = H.D - 1,
                     when Left  => U = 0,
                     when Right => U = H.W - 1);
            begin
               if O.Bottom > 0 and then On_Wall and then not H.Sill and then Along in O.Offset - 1 .. O.Offset + O.Width
                 and then Z - Base = O.Bottom - 1
               then
                  return True;
               elsif O.Bottom > 0 and then On_Wall and then H.Sill
                 and then (Z - Base = O.Bottom - 1 or else Z - Base = O.Bottom + O.Height)
               then
                  --  (John, 2026-11-17: "Fix floating timber for windows on houses, make the timber
                  --  extend the length of the timber columns it sit's inside": from the post on its
                  --  one side to the post on its other, under it and over it)
                  declare
                     Len : constant Integer := (case O.Side is when Front | Back => H.W, when Left | Right => H.D);
                     function Post_Along (A : Integer) return Boolean is
                       (A <= 0 or else A >= Len - 1
                        or else (case O.Side is
                                    when Front => Is_Post (A, 0),
                                    when Back  => Is_Post (A, H.D - 1),
                                    when Left  => Is_Post (0, A),
                                    when Right => Is_Post (H.W - 1, A)));
                     Lo : Integer := O.Offset - 1;
                     Hi : Integer := O.Offset + O.Width;
                  begin
                     while not Post_Along (Lo) loop
                        Lo := Lo - 1;
                     end loop;
                     while not Post_Along (Hi) loop
                        Hi := Hi + 1;
                     end loop;
                     if Along in Lo + 1 .. Hi - 1 then
                        return True;
                     end if;
                  end;
               end if;
            end;
         end loop;
         return False;
      end Trim_At;

      --  The wall to either side of a window, between its sill and its
      --  lintel, is of plank (John: "Change the color of the first fraction
      --  of blocks around the window, like planks as trim").
      function Plank_At (U, V, Z : Integer) return Boolean is
      begin
         if not H.Sill or else not H.Jambs then
            return False;
         end if;
         for K in 2 .. H.Open_N loop
            declare
               O       : Opening renames H.Openings (K);
               Along   : constant Integer := (case O.Side is when Front | Back => U, when Left | Right => V);
               On_Wall : constant Boolean :=
                 (case O.Side is
                     when Front => V = 0,
                     when Back  => V = H.D - 1,
                     when Left  => U = 0,
                     when Right => U = H.W - 1);
            begin
               if O.Bottom > 0 and then On_Wall and then (Along = O.Offset - 1 or else Along = O.Offset + O.Width)
                 and then Z - Base in O.Bottom .. O.Bottom + O.Height - 1
               then
                  return True;
               end if;
            end;
         end loop;
         return False;
      end Plank_At;

      --  Every place of the walls' line, walked round the house: the front
      --  wall, the right, the back, the left.
      procedure Round (Visit : not null access procedure (U, V : Integer)) is
      begin
         for U in 0 .. H.W - 1 loop
            Visit (U, 0);
         end loop;
         for V in 1 .. H.D - 1 loop
            Visit (H.W - 1, V);
         end loop;
         for U in reverse 0 .. H.W - 2 loop
            Visit (U, H.D - 1);
         end loop;
         for V in reverse 1 .. H.D - 2 loop
            Visit (0, V);
         end loop;
      end Round;

      --  The roof's timbers (H.Truss; John, 2026-11-17: "Add timber truss the
      --  the ends of the houses and cross member support to the sides of the
      --  houses perpendicular to the door, add trusses, ridge beam, and cross
      --  member support for the storehouse").  Across: a place along the
      --  span its roof falls over (V, with its ridge along U; else U), and
      --  Span that many; Step: how far in from the nearer eave wall's outer
      --  side it is, from 1.  Its thatch there is at rows Top - 1 + Step
      --  and Top - 2 + Step.
      Span   : constant Integer := (if H.Ridge_Along_U then H.D else H.W);
      Length : constant Integer := (if H.Ridge_Along_U then H.W else H.D);
      Middle : constant Integer := (Span - 1) / 2;
      function Step (Across : Integer) return Integer is (Integer'Min (Across + 1, Span - Across));
      --  In a gable end (the walls' line, over its beam): its king post, and
      --  a rafter under each slope, a block under the gable's top (which is
      --  trimmed to the slope with the thatch).
      --  (H.Full: a king post at each of the two middle places of an even span)
      function Is_King (Across : Integer) return Boolean is
        (Across = Middle or else (H.Full and then Span mod 2 = 0 and then Across = Middle + 1));
      function Gable_Timber (Across, Z : Integer) return Boolean is
        (H.Truss and then Across in 1 .. Span - 2 and then Z in Top .. Top + Step (Across) - 4
         and then (Is_King (Across) or else Z >= Top + Step (Across) - 5));      --  (two deep: its steps join)
      --  H.Full: the line of a gable's rafter goes on down through the wall's top corner to its
      --  corner post, under the wall's top beam (which is timber already): at the place next to
      --  the corner two blocks, at the next one.  In a gable wall alone, and never in an opening
      --  or where the wall has timber or plank of its own.
      function Brace_Rows (Across, Z : Integer) return Boolean is
        (H.Truss and then H.Full and then Across in 1 .. Span - 2 and then Step (Across) in 2 .. 3
         and then Z in Top + Step (Across) - 5 .. Top + Step (Across) - 4 and then Z < Top - 1);
      --  A tie beam crosses at this place along its length (never a gable end).
      Tie_Bays : constant Integer := Integer'Max (1, (Length - 1 + Tie_B / 2) / Tie_B);
      function Is_Tie (Along : Integer) return Boolean is
        (H.Truss and then (for some K in 1 .. Tie_Bays - 1 => (K * (Length - 1) + Tie_Bays / 2) / Tie_Bays = Along));
      procedure Emit_Roof_Timber (Along, Across, Z : Integer) is
      begin
         if H.Ridge_Along_U then
            Emit (Along, Across, Z, Log, Trim);
         else
            Emit (Across, Along, Z, Log, Trim);
         end if;
      end Emit_Roof_Timber;
      --  (a place of the walls' line that is a gable's brace: U, V as the walls are walked)
      function Brace_At (U, V, Z : Integer) return Boolean is
         Along  : constant Integer := (if H.Ridge_Along_U then U else V);
         Across : constant Integer := (if H.Ridge_Along_U then V else U);
      begin
         return (Along = 0 or else Along = Length - 1) and then Brace_Rows (Across, Z)
           and then not Opening_At (U, V, Z) and then not Is_Post (U, V) and then not Trim_At (U, V, Z)
           and then not Plank_At (U, V, Z);
      end Brace_At;

      --  Two blocks of roof over column (U, V), the upper at row Z (D: how
      --  far in from the eave, 0 the eave itself).  The lower is left out
      --  where a wall's top beam already is.
      procedure Roof_Blocks (U, V, Z, D : Integer) is
         On_Wall : constant Boolean := U in 0 .. H.W - 1 and then V in 0 .. H.D - 1;
      begin
         if D > 0 and then (Z - 1 >= Top or else not On_Wall) then
            Emit (U, V, Z - 1, Thatch, Roof);
         end if;
         Emit (U, V, Z, Thatch, Roof);
      end Roof_Blocks;
   begin
      Clash_N := 0;
      --  The floor: the threshold under the door, then the earth inside the
      --  walls, beaten hard row by row, each row back the other way.
      if Yard_Turned (H) then
         --  (a storehouse drawn turned on a stockyard along its path: its floor under it as drawn, to
         --  the middle of its walls, and under each doorway as drawn the wall's whole thickness; the
         --  ground its blocks stand on is beaten with the yard, after it stands)
         declare
            Bx  : constant Frame_Box := Drawn_Box (H);
            U_A : constant Integer := Integer'Min (Bx.U0, -1);
            U_B : constant Integer := Integer'Max (Bx.U1, H.W);
            V_A : constant Integer := Integer'Min (Bx.V0, -1);
            V_B : constant Integer := Integer'Max (Bx.V1, H.D);
            function Threshold (Qu, Qv : Float) return Boolean is
            begin
               for K in 1 .. H.Open_N loop
                  declare
                     O  : Opening renames H.Openings (K);
                     A0 : constant Float := Float (O.Offset) - 0.5;
                     A1 : constant Float := Float (O.Offset + O.Width) - 0.5;
                  begin
                     if O.Bottom = 0
                       and then (case O.Side is
                                    when Front => Qv in -0.5 .. 0.0 and then Qu in A0 .. A1,
                                    when Back  => Qv in Float (H.D - 1) .. Float (H.D) - 0.5 and then Qu in A0 .. A1,
                                    when Left  => Qu in -0.5 .. 0.0 and then Qv in A0 .. A1,
                                    when Right => Qu in Float (H.W - 1) .. Float (H.W) - 0.5 and then Qv in A0 .. A1)
                     then
                        return True;
                     end if;
                  end;
               end loop;
               return False;
            end Threshold;
         begin
            for V in V_A .. V_B loop
               for K in 0 .. U_B - U_A loop
                  declare
                     U : constant Integer := (if (V - V_A) mod 2 = 0 then U_A + K else U_B - K);
                     Qu, Qv : Float;
                  begin
                     Back_Turn (H, Float (U), Float (V), Qu, Qv);
                     if (Qu in 0.0 .. Float (H.W - 1) and then Qv in 0.0 .. Float (H.D - 1)) or else Threshold (Qu, Qv) then
                        Emit (U, V, Base - 1, H.Floor, Floor);
                     end if;
                  end;
               end loop;
            end loop;
         end;
      elsif H.Turn_Ground and then H.Turn /= 0 then
         --  (one drawn turned: under it as drawn, to the middle of its walls, and under its doorway as
         --  drawn the whole of the wall's thickness: its threshold)
         declare
            Bx   : constant Frame_Box := Drawn_Box (H);
            Door : Opening renames H.Openings (1);
         begin
            for V in Bx.V0 .. Bx.V1 loop
               for K in 0 .. Bx.U1 - Bx.U0 loop
                  declare
                     U : constant Integer := (if (V - Bx.V0) mod 2 = 0 then Bx.U0 + K else Bx.U1 - K);
                     Qu, Qv : Float;
                  begin
                     Back_Turn (H, Float (U), Float (V), Qu, Qv);
                     if (Qu in 0.0 .. Float (H.W - 1) and then Qv in 0.0 .. Float (H.D - 1))
                       or else (Qv in -0.5 .. 0.0
                                and then Qu in Float (Door.Offset) - 0.5 .. Float (Door.Offset + Door.Width) - 0.5)
                     then
                        Emit (U, V, Base - 1, H.Floor, Floor);
                     end if;
                  end;
               end loop;
            end loop;
         end;
      else
         for K in 1 .. H.Open_N loop
            declare
               Door : Opening renames H.Openings (K);
            begin
               if Door.Bottom = 0 then
                  for A in Door.Offset .. Door.Offset + Door.Width - 1 loop
                     case Door.Side is
                        when Front => Emit (A, 0, Base - 1, H.Floor, Floor);
                        when Back  => Emit (A, H.D - 1, Base - 1, H.Floor, Floor);
                        when Left  => Emit (0, A, Base - 1, H.Floor, Floor);
                        when Right => Emit (H.W - 1, A, Base - 1, H.Floor, Floor);
                     end case;
                  end loop;
               end if;
            end;
         end loop;
         for V in 1 .. H.D - 2 loop
            for K in 1 .. H.W - 2 loop
               Emit ((if V mod 2 = 1 then K else H.W - 1 - K), V, Base - 1, H.Floor, Floor);
            end loop;
         end loop;
      end if;

      --  The frame: each post raised whole; then the sills and the door's
      --  lintel; then the beam along the top of every wall.
      declare
         procedure Post (U, V : Integer) is
         begin
            if Is_Post (U, V) then
               for Z in Base .. Top - 2 loop
                  Emit (U, V, Z, Log, Trim);
               end loop;
            end if;
         end Post;
         procedure Beam (U, V : Integer) is
         begin
            Emit (U, V, Top - 1, Log, Trim);
         end Beam;
      begin
         Round (Post'Access);
         for Z in Base .. Top - 2 loop
            declare
               procedure Rail (U, V : Integer) is
               begin
                  if not Is_Post (U, V) and then not Opening_At (U, V, Z) and then Trim_At (U, V, Z) then
                     Emit (U, V, Z, Log, Trim);
                  elsif not Is_Post (U, V) and then Plank_At (U, V, Z) then
                     Emit (U, V, Z, Plank, Trim);
                  end if;
               end Rail;
            begin
               Round (Rail'Access);
            end;
         end loop;
         Round (Beam'Access);
      end;

      --  The roof's timbers: each gable's truss (its king post, then its
      --  rafters from the eaves up); the tie beams, one end of the house to
      --  the other; and in a storehouse a truss on each tie beam and the
      --  ridge beam over their king posts.
      if H.Truss then
         for End_K in 0 .. 1 loop
            declare
               Along : constant Integer := (if End_K = 0 then 0 else Length - 1);
            begin
               for Z in Top .. Top + Step (Middle) - 4 loop
                  Emit_Roof_Timber (Along, Middle, Z);
                  if Is_King (Middle + 1) then
                     Emit_Roof_Timber (Along, Middle + 1, Z);
                  end if;
               end loop;
               for K in 1 .. Span - 2 loop
                  declare      --  (from each eave in turn, toward the ridge)
                     Across : constant Integer := (if K mod 2 = 1 then (K + 1) / 2 else Span - 1 - K / 2);
                  begin
                     for Z in Top - 3 .. Top - 2 loop          --  (H.Full: its rafter's foot, in the wall's corner)
                        if Brace_At ((if H.Ridge_Along_U then Along else Across),
                                     (if H.Ridge_Along_U then Across else Along), Z)
                        then
                           Emit_Roof_Timber (Along, Across, Z);
                        end if;
                     end loop;
                     if not Is_King (Across) then
                        for Z in Top + Step (Across) - 5 .. Top + Step (Across) - 4 loop
                           if Gable_Timber (Across, Z) then
                              Emit_Roof_Timber (Along, Across, Z);
                           end if;
                        end loop;
                     end if;
                  end;
               end loop;
            end;
         end loop;
         for Along in 1 .. Length - 2 loop
            if Is_Tie (Along) then
               for Across in 1 .. Span - 2 loop
                  Emit_Roof_Timber (Along, Across, Top - 1);
               end loop;
               if H.Kind = Storehouse then
                  for Z in Top .. Top + Step (Middle) - 4 loop
                     Emit_Roof_Timber (Along, Middle, Z);
                     if Is_King (Middle + 1) then
                        Emit_Roof_Timber (Along, Middle + 1, Z);
                     end if;
                  end loop;
                  for Across in 1 .. Span - 2 loop           --  (a rafter under the thatch's underside)
                     if not Is_King (Across) and then Step (Across) >= 3 then
                        Emit_Roof_Timber (Along, Across, Top + Step (Across) - 3);
                     end if;
                  end loop;
               end if;
            end if;
         end loop;
         if H.Kind = Storehouse or else H.Ridge then
            for Along in 1 .. Length - 2 loop
               Emit_Roof_Timber (Along, Middle, Top + Step (Middle) - 3);
               if Is_King (Middle + 1) then
                  Emit_Roof_Timber (Along, Middle + 1, Top + Step (Middle) - 3);
               end if;
            end loop;
         end if;
      end if;

      --  The walls: wattle and daub between the timbers, bottom course
      --  first, each walked round the house.
      for Z in Base .. Top - 2 loop
         declare
            procedure Panel (U, V : Integer) is
            begin
               if Opening_At (U, V, Z) then
                  Emit (U, V, Z, Air, Walls);
               elsif not Is_Post (U, V) and then not Trim_At (U, V, Z) and then not Plank_At (U, V, Z)
                 and then not Brace_At (U, V, Z)
               then
                  Emit (U, V, Z, Daub, Walls);
               end if;
            end Panel;
         begin
            Round (Panel'Access);
         end;
      end loop;

      --  The roof: 45 degree steps along the longer side, two blocks thick,
      --  one block of eave except over a shared wall; the gable ends closed
      --  in daub under it, one end and then the other.
      if H.Ridge_Along_U then
         for U_End in 0 .. 1 loop
            for V in 1 .. H.D - 2 loop
               for Zg in Top .. Top - 1 + Integer'Min (V + 1, H.D - V) - 2 loop
                  if not Gable_Timber (V, Zg) then
                     Emit ((if U_End = 0 then 0 else H.W - 1), V, Zg, Daub, Gables);
                  end if;
               end loop;
            end loop;
         end loop;
         for V in -1 .. H.D loop
            declare
               D : constant Integer := Integer'Min (V + 1, H.D - V);
            begin
               for K in 0 .. U_Hi - U_Lo loop
                  Roof_Blocks ((if V mod 2 = 0 then U_Lo + K else U_Hi - K), V, Top - 1 + D, D);
               end loop;
            end;
         end loop;
         for V in -1 .. H.D loop                --  trimmed, the same way
            declare
               D : constant Integer := Integer'Min (V + 1, H.D - V);
            begin
               for K in 0 .. U_Hi - U_Lo loop
                  declare
                     U : constant Integer := (if V mod 2 = 0 then U_Lo + K else U_Hi - K);
                  begin
                     Emit (U, V, Top - 1 + D, Thatch, Dress,
                           Lies (Toward_V => True, Up => V + 1 > H.D - V, Eave => D = 0, Cap => V + 1 = H.D - V,
                                 End_Lo => U = U_Lo and then not H.Shared_Left,
                                 End_Hi => U = U_Hi and then not H.Shared_Right));
                     --  (past a gable its underside too, where it is two blocks thick and falls one way;
                     --  and over the gable, with the top of the gable's daub under it)
                     if (U < 0 or else U > H.W - 1) and then D > 0 and then V + 1 /= H.D - V then
                        Emit (U, V, Top - 2 + D, Thatch, Dress,
                              Under + Lies (Toward_V => True, Up => V + 1 > H.D - V, Eave => False, Cap => False,
                                            End_Lo => U = U_Lo, End_Hi => U = U_Hi));
                     elsif (U = 0 or else U = H.W - 1) and then D >= 3 and then V + 1 /= H.D - V then
                        Emit (U, V, Top - 2 + D, Thatch, Dress,
                              Under + Lies (Toward_V => True, Up => V + 1 > H.D - V, Eave => False, Cap => False,
                                            End_Lo => False, End_Hi => False));
                        Emit (U, V, Top - 3 + D, Daub, Dress,
                              Lies (Toward_V => True, Up => V + 1 > H.D - V, Eave => False, Cap => False,
                                    End_Lo => False, End_Hi => False));
                     end if;
                  end;
               end loop;
            end;
         end loop;
      else
         for V_End in 0 .. 1 loop
            for U in 1 .. H.W - 2 loop
               for Zg in Top .. Top - 1 + Integer'Min (U + 1, H.W - U) - 2 loop
                  if not Gable_Timber (U, Zg) then
                     Emit (U, (if V_End = 0 then 0 else H.D - 1), Zg, Daub, Gables);
                  end if;
               end loop;
            end loop;
         end loop;
         for U in U_Lo .. U_Hi loop
            declare
               D : constant Integer := Integer'Min (U + 1, H.W - U);
            begin
               for K in 0 .. H.D + 1 loop
                  Roof_Blocks (U, (if U mod 2 = 0 then K - 1 else H.D - K), Top - 1 + D, D);
               end loop;
            end;
         end loop;
         for U in U_Lo .. U_Hi loop             --  trimmed, the same way
            declare
               D : constant Integer := Integer'Min (U + 1, H.W - U);
            begin
               for K in 0 .. H.D + 1 loop
                  declare
                     V : constant Integer := (if U mod 2 = 0 then K - 1 else H.D - K);
                  begin
                     Emit (U, V, Top - 1 + D, Thatch, Dress,
                           Lies (Toward_V => False, Up => U + 1 > H.W - U, Eave => D = 0, Cap => U + 1 = H.W - U,
                                 End_Lo => V = -1, End_Hi => V = H.D));
                     if (V < 0 or else V > H.D - 1) and then D > 0 and then U + 1 /= H.W - U then
                        Emit (U, V, Top - 2 + D, Thatch, Dress,
                              Under + Lies (Toward_V => False, Up => U + 1 > H.W - U, Eave => False, Cap => False,
                                            End_Lo => V = -1, End_Hi => V = H.D));
                     elsif (V = 0 or else V = H.D - 1) and then D >= 3 and then U + 1 /= H.W - U then
                        Emit (U, V, Top - 2 + D, Thatch, Dress,
                              Under + Lies (Toward_V => False, Up => U + 1 > H.W - U, Eave => False, Cap => False,
                                            End_Lo => False, End_Hi => False));
                        Emit (U, V, Top - 3 + D, Daub, Dress,
                              Lies (Toward_V => False, Up => U + 1 > H.W - U, Eave => False, Cap => False,
                                    End_Lo => False, End_Hi => False));
                     end if;
                  end;
               end loop;
            end;
         end loop;
      end if;

      if H.Woodpile /= 0 then
         declare
            U : constant Integer := (if H.Woodpile = 1 then -1 else H.W);
         begin
            for V in 2 .. 5 loop
               for Z in Base .. Base + 1 loop
                  Emit (U, V, Z, Log, Extras);
               end loop;
            end loop;
         end;
      end if;

      --  A storehouse's yard (its lot, the stockyard): its ground beaten, row
      --  by row back and forth, all but under the storehouse and the bank
      --  round it; the fence round the yard behind it, a stretch at a time,
      --  posts raised first, from the left gateway out, back, along the back,
      --  forward and in to the right gateway; the two gateways beside its
      --  ends, in line with its inside wall (John, 2026-11-17: "the fence is
      --  to be placed around the stockyard with the gates extending from the
      --  storehouse, inline with the inside wall of the storehouse to the
      --  stockyard"); the coverings, their posts and then their roofs, a
      --  strip at a time from the front.
      if H.Kind = Storehouse then
         declare
            function Under_It (U, V : Integer) return Boolean is
              (U in -Apron_B .. H.W - 1 + Apron_B and then V in -Apron_B .. H.D - 1 + Apron_B);
            Gate_V : constant Integer := H.D - 1;      --  the gateways' line: its inside wall's
            --  each gateway from the storehouse's end out, Store_Gate_W_B wide (all the gap, if it is less)
            L_Gate : constant Integer := Integer'Max (H.Yard_U0 + 1, -Store_Gate_W_B);         --  .. -1
            R_Gate : constant Integer := Integer'Min (H.Yard_U1 - 1, H.W - 1 + Store_Gate_W_B);  --  H.W ..
            --  the fence's line, from the left gateway's post round to the right one's
            Side_L : constant Integer := L_Gate - 1 - H.Yard_U0;     --  blocks of it along the gate line, left
            Deep   : constant Integer := H.Yard_V1 - Gate_V;          --  back along each side
            Across : constant Integer := H.Yard_U1 - H.Yard_U0;       --  along the back
            Side_R : constant Integer := H.Yard_U1 - (R_Gate + 1);    --  along the gate line, right
            N_Line : constant Integer := Side_L + Deep + Across + Deep + Side_R + 1;
            procedure Line_At (K : Integer; U, V : out Integer; Corner : out Boolean) is
               P : Integer := K;
            begin
               Corner := False;
               if P <= Side_L then
                  U := L_Gate - 1 - P;
                  V := Gate_V;
                  Corner := P = 0 or else P = Side_L;
                  return;
               end if;
               P := P - Side_L;
               if P <= Deep then
                  U := H.Yard_U0;
                  V := Gate_V + P;
                  Corner := P = Deep;
                  return;
               end if;
               P := P - Deep;
               if P <= Across then
                  U := H.Yard_U0 + P;
                  V := H.Yard_V1;
                  Corner := P = Across;
                  return;
               end if;
               P := P - Across;
               if P <= Deep then
                  U := H.Yard_U1;
                  V := H.Yard_V1 - P;
                  Corner := P = Deep;
                  return;
               end if;
               P := P - Deep;
               U := H.Yard_U1 - P;
               V := Gate_V;
               Corner := U = R_Gate + 1;
            end Line_At;
            --  One drawn turned (Yard_Turned): where a place of this design is made, on the grid.
            procedure Real_Of (Du, Dv : Float; U, V : out Integer) is
               Qu, Qv : Float;
            begin
               Fore_Turn (H, Du, Dv, Qu, Qv);
               U := Integer (Float'Rounding (Qu));
               V := Integer (Float'Rounding (Qv));
            end Real_Of;
            --  (the columns of its frame that a piece of the design lies within)
            function Real_Box (U0, U1, V0, V1 : Float) return Frame_Box is
               Lo_U, Lo_V : Float := Float'Last;
               Hi_U, Hi_V : Float := Float'First;
               procedure Corner (U, V : Float) is
                  Au, Av : Float;
               begin
                  Fore_Turn (H, U, V, Au, Av);
                  Lo_U := Float'Min (Lo_U, Au);  Hi_U := Float'Max (Hi_U, Au);
                  Lo_V := Float'Min (Lo_V, Av);  Hi_V := Float'Max (Hi_V, Av);
               end Corner;
            begin
               Corner (U0, V0);
               Corner (U1, V0);
               Corner (U1, V1);
               Corner (U0, V1);
               return (U0 => Integer (Float'Floor (Lo_U)), U1 => Integer (Float'Ceiling (Hi_U)),
                       V0 => Integer (Float'Floor (Lo_V)), V1 => Integer (Float'Ceiling (Hi_V)));
            end Real_Box;
            --  (where its own blocks stand, eaves and all: nothing of its yard is made there, for
            --  whatever of timber or thatch stands there is drawn turned with it)
            function Its_Blocks (U, V : Integer) return Boolean is (U in -1 .. H.W and then V in -1 .. H.D);
            --  (a column of its fence, a gateway or a covering is clear of them: counted where one is
            --  not, and whoever lays a yard out sees to it that none is: Yard_Clashes)
            function Clear (U, V : Integer) return Boolean is
            begin
               if Its_Blocks (U, V) then
                  Clash_N := Clash_N + 1;
                  return False;
               end if;
               return True;
            end Clear;
            --  A line of the design as it is made: its columns in order, each beside the one before
            --  (never corner to corner: a fence so made would let a body through).
            type Line_Col is record
               U, V : Integer := 0;
               Post : Boolean := False;
            end record;
            type Line_Cols is array (1 .. 3 * N_Line + 3 * (Store_Gate_W_B + 2) + 8) of Line_Col;
            Cols   : Line_Cols;
            N_Cols : Natural := 0;
            Last_Du, Last_Dv : Float := 0.0;
            procedure Add_Col (Du, Dv : Float; Post : Boolean) is
               U, V : Integer;
            begin
               Real_Of (Du, Dv, U, V);
               if N_Cols > 0 and then Cols (N_Cols).U = U and then Cols (N_Cols).V = V then
                  Cols (N_Cols).Post := Cols (N_Cols).Post or else Post;
               else
                  if N_Cols > 0 and then Cols (N_Cols).U /= U and then Cols (N_Cols).V /= V then
                     --  (corner to corner: the column between them nearer the line)
                     declare
                        Mu : constant Float := (Du + Last_Du) / 2.0;
                        Mv : constant Float := (Dv + Last_Dv) / 2.0;
                        Au, Av, Bu, Bv : Float;
                     begin
                        Back_Turn (H, Float (Cols (N_Cols).U), Float (V), Au, Av);
                        Back_Turn (H, Float (U), Float (Cols (N_Cols).V), Bu, Bv);
                        N_Cols := N_Cols + 1;
                        if (Au - Mu) ** 2 + (Av - Mv) ** 2 <= (Bu - Mu) ** 2 + (Bv - Mv) ** 2 then
                           Cols (N_Cols) := (Cols (N_Cols - 1).U, V, False);
                        else
                           Cols (N_Cols) := (U, Cols (N_Cols - 1).V, False);
                        end if;
                     end;
                  end if;
                  N_Cols := N_Cols + 1;
                  Cols (N_Cols) := (U, V, Post);
               end if;
               Last_Du := Du;
               Last_Dv := Dv;
            end Add_Col;
         begin
            if Yard_Turned (H) then
               declare
                  Bx : constant Frame_Box :=
                    Real_Box (Float (H.Yard_U0) - 0.5, Float (H.Yard_U1) + 0.5, Float (H.Yard_V0) - 0.5, Float (H.Yard_V1) + 0.5);
               begin
                  for V in Bx.V0 .. Bx.V1 loop
                     for K in 0 .. Bx.U1 - Bx.U0 loop
                        declare
                           U : constant Integer := (if (V - Bx.V0) mod 2 = 0 then Bx.U0 + K else Bx.U1 - K);
                           Du, Dv : Integer;
                        begin
                           Design_Of (H, U, V, Du, Dv);
                           --  (where its own blocks stand too: that ground is the yard's as any, and whoever
                           --  beats it walks there once its walls and roof are up)
                           if Du in H.Yard_U0 .. H.Yard_U1 and then Dv in H.Yard_V0 .. H.Yard_V1
                             and then not Under_It (Du, Dv)
                           then
                              Emit (U, V, Base - 1, Footpath, Beaten);
                           end if;
                        end;
                     end loop;
                  end loop;
               end;
               if H.Yard_V1 > Gate_V and then H.Yard_U1 > H.Yard_U0 then
                  declare
                     Run : Integer := 0;
                  begin
                     for K in 0 .. N_Line - 1 loop
                        declare
                           U, V   : Integer;
                           Corner : Boolean;
                        begin
                           Line_At (K, U, V, Corner);
                           Add_Col (Float (U), Float (V), Post => Run mod Fence_Post_B = 0 or else Corner or else K = N_Line - 1);
                           Run := (if Corner then 0 else Run) + 1;
                        end;
                     end loop;
                  end;
                  for K in 1 .. N_Cols loop
                     if Clear (Cols (K).U, Cols (K).V) then
                        if Cols (K).Post then
                           for Z in Base .. Base + Fence_H_B - 1 loop
                              Emit (Cols (K).U, Cols (K).V, Z, Log, Fence);
                           end loop;
                        else
                           Emit (Cols (K).U, Cols (K).V, Base + 1, Log, Fence, (if H.Fence_Pieces then Castle.Blocks.Piece else 0));
                           Emit (Cols (K).U, Cols (K).V, Base + Fence_H_B - 1, Log, Fence, (if H.Fence_Pieces then Castle.Blocks.Piece else 0));
                        end if;
                     end if;
                  end loop;
                  --  the gateways: the post at each end of the fence raised, and a plank across to the
                  --  storehouse's corner as it is drawn
                  for Z in Base + Fence_H_B .. Base + Gate_Post_H_B - 1 loop
                     Emit (Cols (1).U, Cols (1).V, Z, Log, Fence);
                     Emit (Cols (N_Cols).U, Cols (N_Cols).V, Z, Log, Fence);
                  end loop;
                  --  (the plank's end under the storehouse's eave is of the storehouse's own blocks, where
                  --  it stands in its frame: drawn turned with it, it meets the rest at its corner as drawn)
                  Emit (-1, Gate_V, Base + Gate_Post_H_B, Plank, Fence, (if H.Fence_Pieces then Castle.Blocks.Piece else 0));
                  Emit (H.W, Gate_V, Base + Gate_Post_H_B, Plank, Fence, (if H.Fence_Pieces then Castle.Blocks.Piece else 0));
                  for Side in 1 .. 2 loop
                     N_Cols := 0;
                     if Side = 1 then
                        for U in L_Gate - 1 .. -2 loop
                           Add_Col (Float (U), Float (Gate_V), False);
                        end loop;
                     else
                        for U in H.W + 1 .. R_Gate + 1 loop
                           Add_Col (Float (U), Float (Gate_V), False);
                        end loop;
                     end if;
                     for K in 1 .. N_Cols loop
                        if Clear (Cols (K).U, Cols (K).V) then
                           Emit (Cols (K).U, Cols (K).V, Base + Gate_Post_H_B, Plank, Fence, (if H.Fence_Pieces then Castle.Blocks.Piece else 0));
                        end if;
                     end loop;
                  end loop;
               end if;
               --  the coverings: each one's four posts, then its roof where it lies, by how far back
               for C in 1 .. H.Covers loop
                  declare
                     U0 : constant Integer := H.Cover_U (C);
                     U1 : constant Integer := U0 + Cover_W_B - 1;
                     V0 : constant Integer := H.Yard_V1 - Cover_D_B;
                     V1 : constant Integer := H.Yard_V1 - 1;
                     procedure Post_At (Du, Dv, Hgt : Integer) is
                        U, V : Integer;
                     begin
                        Real_Of (Float (Du), Float (Dv), U, V);
                        if Clear (U, V) then
                           for Z in Base .. Base + Hgt - 1 loop
                              Emit (U, V, Z, Log, Cover);
                           end loop;
                        end if;
                     end Post_At;
                  begin
                     Post_At (U0, V0, Cover_Front_H_B);
                     Post_At (U1, V0, Cover_Front_H_B);
                     Post_At (U0, V1, Cover_Back_H_B);
                     Post_At (U1, V1, Cover_Back_H_B);
                  end;
               end loop;
               for C in 1 .. H.Covers loop
                  declare
                     U0 : constant Integer := H.Cover_U (C);
                     V0 : constant Integer := H.Yard_V1 - Cover_D_B;
                     Bx : constant Frame_Box :=
                       Real_Box (Float (U0) - 0.5, Float (U0 + Cover_W_B) - 0.5, Float (V0) - 0.5, Float (V0 + Cover_D_B) - 0.5);
                  begin
                     for V in Bx.V0 .. Bx.V1 loop
                        for K in 0 .. Bx.U1 - Bx.U0 loop
                           declare
                              U : constant Integer := (if (V - Bx.V0) mod 2 = 0 then Bx.U0 + K else Bx.U1 - K);
                              Du, Dv : Integer;
                           begin
                              Design_Of (H, U, V, Du, Dv);
                              if Du in U0 .. U0 + Cover_W_B - 1 and then Dv in V0 .. V0 + Cover_D_B - 1
                                and then Clear (U, V)
                              then
                                 Emit (U, V,
                                       Base + Cover_Front_H_B
                                       - ((Dv - V0) * (Cover_Front_H_B - Cover_Back_H_B) + (Cover_D_B - 1) / 2) / (Cover_D_B - 1),
                                       Thatch, Cover);
                              end if;
                           end;
                        end loop;
                     end loop;
                  end;
               end loop;
               --  the coverings' roofs smoothed: each one's thatch again, a row of its design at a time
               --  from its front to its back
               if H.Smooth_Covers then
                  for C in 1 .. H.Covers loop
                     declare
                        U0 : constant Integer := H.Cover_U (C);
                        V0 : constant Integer := H.Yard_V1 - Cover_D_B;
                        Bx : constant Frame_Box :=
                          Real_Box (Float (U0) - 0.5, Float (U0 + Cover_W_B) - 0.5, Float (V0) - 0.5, Float (V0 + Cover_D_B) - 0.5);
                     begin
                        for Row in V0 .. V0 + Cover_D_B - 1 loop
                           for V in Bx.V0 .. Bx.V1 loop
                              for U in Bx.U0 .. Bx.U1 loop
                                 declare
                                    Du, Dv : Integer;
                                 begin
                                    Design_Of (H, U, V, Du, Dv);
                                    if Dv = Row and then Du in U0 .. U0 + Cover_W_B - 1 and then not Its_Blocks (U, V) then
                                       Emit (U, V,
                                             Base + Cover_Front_H_B
                                             - ((Dv - V0) * (Cover_Front_H_B - Cover_Back_H_B) + (Cover_D_B - 1) / 2)
                                               / (Cover_D_B - 1),
                                             Thatch, Smooth, Castle.Blocks.Piece);
                                    end if;
                                 end;
                              end loop;
                           end loop;
                        end loop;
                     end;
                  end loop;
               end if;
               return;
            end if;
            for V in H.Yard_V0 .. H.Yard_V1 loop
               for K in 0 .. H.Yard_U1 - H.Yard_U0 loop
                  declare
                     U : constant Integer := (if (V - H.Yard_V0) mod 2 = 0 then H.Yard_U0 + K else H.Yard_U1 - K);
                  begin
                     if not Under_It (U, V) then
                        Emit (U, V, Base - 1, Footpath, Beaten);
                     end if;
                  end;
               end loop;
            end loop;
            --  the fence: a stretch between two posts at a time, the post first
            if H.Yard_V1 > Gate_V and then H.Yard_U1 > H.Yard_U0 then
               declare
                  Run : Integer := 0;           --  blocks since the last post
               begin
                  for K in 0 .. N_Line - 1 loop
                     declare
                        U, V   : Integer;
                        Corner : Boolean;
                     begin
                        Line_At (K, U, V, Corner);
                        if Run mod Fence_Post_B = 0 or else Corner or else K = N_Line - 1 then
                           for Z in Base .. Base + Fence_H_B - 1 loop
                              Emit (U, V, Z, Log, Fence);
                           end loop;
                           Run := (if Corner then 0 else Run);
                        else
                           Emit (U, V, Base + 1, Log, Fence);
                           Emit (U, V, Base + Fence_H_B - 1, Log, Fence);
                        end if;
                        Run := Run + 1;
                     end;
                  end loop;
               end;
               --  the gateways: the post at the fence's end raised to a man's height, and a plank across
               --  from it to the storehouse's wall
               for Z in Base + Fence_H_B .. Base + Gate_Post_H_B - 1 loop
                  Emit (L_Gate - 1, Gate_V, Z, Log, Fence);
                  Emit (R_Gate + 1, Gate_V, Z, Log, Fence);
               end loop;
               for U in L_Gate - 1 .. -1 loop
                  Emit (U, Gate_V, Base + Gate_Post_H_B, Plank, Fence);
               end loop;
               for U in H.W .. R_Gate + 1 loop
                  Emit (U, Gate_V, Base + Gate_Post_H_B, Plank, Fence);
               end loop;
            end if;
            --  the coverings: four posts each, then the roofs, a strip at a
            --  time from the front, falling from Cover_Front_H_B to Cover_Back_H_B
            for C in 1 .. H.Covers loop
               declare
                  U0 : constant Integer := H.Cover_U (C);
                  U1 : constant Integer := U0 + Cover_W_B - 1;
                  V0 : constant Integer := H.Yard_V1 - Cover_D_B;
                  V1 : constant Integer := H.Yard_V1 - 1;
               begin
                  for Z in Base .. Base + Cover_Front_H_B - 1 loop
                     Emit (U0, V0, Z, Log, Cover);
                     Emit (U1, V0, Z, Log, Cover);
                  end loop;
                  for Z in Base .. Base + Cover_Back_H_B - 1 loop
                     Emit (U0, V1, Z, Log, Cover);
                     Emit (U1, V1, Z, Log, Cover);
                  end loop;
               end;
            end loop;
            for C in 1 .. H.Covers loop
               declare
                  U0 : constant Integer := H.Cover_U (C);
                  V0 : constant Integer := H.Yard_V1 - Cover_D_B;
               begin
                  for Dv in 0 .. Cover_D_B - 1 loop
                     declare
                        Hgt : constant Integer :=
                          Cover_Front_H_B - (Dv * (Cover_Front_H_B - Cover_Back_H_B) + (Cover_D_B - 1) / 2) / (Cover_D_B - 1);
                     begin
                        for K in 0 .. Cover_W_B - 1 loop
                           Emit ((if Dv mod 2 = 0 then U0 + K else U0 + Cover_W_B - 1 - K), V0 + Dv, Base + Hgt, Thatch, Cover);
                        end loop;
                     end;
                  end loop;
               end;
            end loop;
            --  the coverings' roofs smoothed: each one's thatch again, a row at a time from its front
            if H.Smooth_Covers then
               for C in 1 .. H.Covers loop
                  declare
                     U0 : constant Integer := H.Cover_U (C);
                     V0 : constant Integer := H.Yard_V1 - Cover_D_B;
                  begin
                     for Dv in 0 .. Cover_D_B - 1 loop
                        declare
                           Hgt : constant Integer :=
                             Cover_Front_H_B - (Dv * (Cover_Front_H_B - Cover_Back_H_B) + (Cover_D_B - 1) / 2) / (Cover_D_B - 1);
                        begin
                           for K in 0 .. Cover_W_B - 1 loop
                              Emit ((if Dv mod 2 = 0 then U0 + K else U0 + Cover_W_B - 1 - K), V0 + Dv, Base + Hgt, Thatch,
                                    Smooth, Castle.Blocks.Piece);
                           end loop;
                        end;
                     end loop;
                  end;
               end loop;
            end if;
         end;
      end if;
   end Blueprint;

   function Yard_Clashes (H : House) return Natural is
      procedure Nothing (Bx, By, Bz : Integer; M : Material; S : Stage; State : Natural) is null;
      procedure Draw is new Blueprint (Nothing);
   begin
      Draw (H);
      return Clash_N;
   end Yard_Clashes;

end Castle.Buildings;
