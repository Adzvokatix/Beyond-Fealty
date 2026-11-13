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

   ---------------
   -- Blueprint --
   ---------------

   procedure Blueprint (H : House) is
      Base : constant Integer := H.Pad;
      Top  : constant Integer := Base + H.Wall_H;
      U_Lo : constant Integer := (if H.Shared_Left then 0 else -1);       --  no eave over a neighbour
      U_Hi : constant Integer := (if H.Shared_Right then H.W - 1 else H.W);

      procedure Emit (U, V, Z : Integer; M : Material; S : Stage) is
      begin
         Put (Cell_X (H, U, V), Cell_Y (H, U, V), Z, M, S);
      end Emit;

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

      --  Door jambs either side of the door and a lintel over it; a sill one
      --  block wider than each window, under it.
      function Trim_At (U, V, Z : Integer) return Boolean is
         Door : Opening renames H.Openings (1);
      begin
         if V = 0 then
            if (U = Door.Offset - 1 or else U = Door.Offset + Door.Width)
              and then Z - Base in 0 .. Door.Height - 1
            then
               return True;
            elsif U in Door.Offset - 1 .. Door.Offset + Door.Width and then Z - Base = Door.Height then
               return True;
            end if;
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
               if On_Wall and then Along in O.Offset - 1 .. O.Offset + O.Width
                 and then Z - Base = O.Bottom - 1
               then
                  return True;
               end if;
            end;
         end loop;
         return False;
      end Trim_At;

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
         Door : Opening renames H.Openings (1);
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
         if V = 0 and then (U = Door.Offset - 1 or else U = Door.Offset + Door.Width) then
            return True;
         end if;
         if V = 0 and then (U = Door.Offset - 2 or else U = Door.Offset + Door.Width + 1) then
            return False;
         end if;
         return (if Side_V then Is_Stud (U, H.W - 1) else Is_Stud (V, H.D - 1));
      end Is_Post;

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
      --  The floor: the threshold under the door, then the earth inside the
      --  walls, beaten hard row by row, each row back the other way.
      for U in H.Openings (1).Offset .. H.Openings (1).Offset + H.Openings (1).Width - 1 loop
         Emit (U, 0, Base - 1, Footpath, Floor);
      end loop;
      for V in 1 .. H.D - 2 loop
         for K in 1 .. H.W - 2 loop
            Emit ((if V mod 2 = 1 then K else H.W - 1 - K), V, Base - 1, Footpath, Floor);
         end loop;
      end loop;

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
                  end if;
               end Rail;
            begin
               Round (Rail'Access);
            end;
         end loop;
         Round (Beam'Access);
      end;

      --  The walls: wattle and daub between the timbers, bottom course
      --  first, each walked round the house.
      for Z in Base .. Top - 2 loop
         declare
            procedure Panel (U, V : Integer) is
            begin
               if Opening_At (U, V, Z) then
                  Emit (U, V, Z, Air, Walls);
               elsif not Is_Post (U, V) and then not Trim_At (U, V, Z) then
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
                  Emit ((if U_End = 0 then 0 else H.W - 1), V, Zg, Daub, Gables);
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
      else
         for V_End in 0 .. 1 loop
            for U in 1 .. H.W - 2 loop
               for Zg in Top .. Top - 1 + Integer'Min (U + 1, H.W - U) - 2 loop
                  Emit (U, (if V_End = 0 then 0 else H.D - 1), Zg, Daub, Gables);
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
   end Blueprint;

end Castle.Buildings;
