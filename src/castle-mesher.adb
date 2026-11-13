with Ada.Unchecked_Deallocation;
with Castle.Blocks;  use Castle.Blocks;
with Castle.Dims;    use Castle.Dims;
with Castle.Geology; use Castle.Geology;

package body Castle.Mesher is

   procedure Free_Q is new Ada.Unchecked_Deallocation (Quad_Array, Quad_Access);

   procedure Free (M : in out Mesh) is
   begin
      if M.Solid /= null then
         Free_Q (M.Solid);
      end if;
      if M.Water /= null then
         Free_Q (M.Water);
      end if;
   end Free;

   --  Growable quad list.
   type Buffer is record
      Data  : Quad_Access;
      Count : Natural := 0;
   end record;

   procedure Push (B : in out Buffer; Q : Quad) is
   begin
      if B.Data = null then
         B.Data := new Quad_Array (1 .. 2_048);
      elsif B.Count = B.Data'Last then
         declare
            Bigger : constant Quad_Access := new Quad_Array (1 .. 2 * B.Data'Last);
         begin
            Bigger (1 .. B.Count) := B.Data (1 .. B.Count);
            Free_Q (B.Data);
            B.Data := Bigger;
         end;
      end if;
      B.Count := B.Count + 1;
      B.Data (B.Count) := Q;
   end Push;

   function Take (B : in out Buffer) return Quad_Access is
      R : Quad_Access := null;
   begin
      if B.Count > 0 then
         R := new Quad_Array'(B.Data (1 .. B.Count));
      end if;
      if B.Data /= null then
         Free_Q (B.Data);
      end if;
      return R;
   end Take;

   type Edge_Column is record
      Solid, Water_Top : Integer := 0;
      Top : Material := Air;         --  what its ground is at the top, as generated (Air: bare rock)
   end record;
   type Edge is array (0 .. Chunk_B - 1) of Edge_Column;

   type Mask_Grid is array (0 .. Chunk_B - 1, 0 .. Height_B - 1) of Unsigned_32;
   --  material + 1, occlusion << 8, fringe << 16; a tuft: bit 24, and which
   --  column it is in (bits 25 and 26: odd along u, odd along v), so that a
   --  tuft's faces merge up its own column and never with the next tuft's
   Mask_Tuft  : constant Unsigned_32 := 2 ** 24;
   Mask_Odd_U : constant Unsigned_32 := 2 ** 25;
   Mask_Odd_V : constant Unsigned_32 := 2 ** 26;

   procedure Build (W : World; CX, CY : Integer; Work : Stack_Work; M : out Mesh;
                    Rim  : Castle.Edits.Rim_Access := null;
                    View : Castle.Water.View_Access := null) is
      X0 : constant Integer := CX * Chunk_B;
      Y0 : constant Integer := CY * Chunk_B;
      West, East, South, North : Edge;          --  x = -1, x = 32, y = -1, y = 32
      Z_Lo : Integer := Height_B - 1;
      Z_Hi : Integer := 0;
      Solid_B, Water_B, Tuft_B : Buffer;
      Mask : Mask_Grid;

      function Edge_Of (Bx, By : Integer) return Edge_Column is
      begin
         if Bx < 0 or else By < 0 or else Bx >= Size_B or else By >= Size_B then
            return (Solid => 0, Water_Top => 0, Top => Air);   --  the world's rim stays open
         end if;
         declare
            C : constant Column := Prepare_Column (W, Bx, By);
         begin
            return (Solid => C.Solid, Water_Top => C.Water_Top, Top => C.Top);
         end;
      end Edge_Of;

      --  Material at stack-local (X, Y, Z), looking across the edges.
      function Mat (X, Y, Z : Integer) return Material is
      begin
         if Z < Z_Lo then
            return Deep;                           --  under the meshed band: solid
         elsif Z >= Height_B then
            return Air;
         elsif X in 0 .. Chunk_B - 1 and then Y in 0 .. Chunk_B - 1 then
            return Work.G (X, Y, Z).Mat;
         end if;
         if View /= null and then View (X, Y).Sim then
            for K in 1 .. View (X, Y).C.N loop
               declare
                  St : Castle.Water.Stretch renames View (X, Y).C.S (K);
               begin
                  if Z >= St.Floor and then Z < St.Ceil then
                     return (if Z < St.Floor + St.Water then Castle.Blocks.Water else Air);
                  end if;
               end;
            end loop;
         end if;
         declare
            Edited : Material;
         begin
            if Castle.Edits.Rim_Material (Rim, X, Y, Z, Edited) then
               return Edited;
            end if;
         end;
         declare
            --  Past a corner of the stack (occlusion looks diagonally) the
            --  nearest edge column stands in.
            Yc : constant Integer := Integer'Max (0, Integer'Min (Chunk_B - 1, Y));
            E  : constant Edge_Column :=
              (if X < 0 then West (Yc)
               elsif X >= Chunk_B then East (Yc)
               elsif Y < 0 then South (X)
               else North (X));
         begin
            --  (its top block by name, where the generator says what it is: the
            --  fringe between turf and bare earth carries on across the edge)
            return (if Z = E.Solid - 1 and then E.Top /= Air then E.Top
                    elsif Z < E.Solid then Deep elsif Z < E.Water_Top then Castle.Blocks.Water else Air);
         end;
      end Mat;

      --  Foliage is drawn soft (see the spec).  How the corner of the block
      --  grid at (Gx, Gy, Gz) is drawn in: of the eight blocks that meet
      --  there, those that are something (ground, wood, leaves, grass) are
      --  its body, and it is drawn toward the body along each axis on which
      --  at least half of the body lies to one side.  Two bits an axis: 0
      --  not, 1 up the axis, 2 down it.  A corner on the stack's edge is left
      --  where it is: the neighbour's trees are not known here, and the two
      --  stacks must agree on where it goes.
      function Pull (Gx, Gy, Gz : Integer) return Unsigned_32 is
         Sx, Sy, Sz, C : Integer := 0;
         function Code (S : Integer) return Unsigned_32 is
           (if 2 * abs S >= C then (if S > 0 then 1 else 2) else 0);
      begin
         if Gx = 0 or else Gx = Chunk_B or else Gy = 0 or else Gy = Chunk_B then
            return 0;
         end if;
         for Dz in -1 .. 0 loop
            for Dy in -1 .. 0 loop
               for Dx in -1 .. 0 loop
                  if Class_Of (Mat (Gx + Dx, Gy + Dy, Gz + Dz)) in Solid | Plant then
                     C := C + 1;
                     Sx := Sx + 2 * Dx + 1;
                     Sy := Sy + 2 * Dy + 1;
                     Sz := Sz + 2 * Dz + 1;
                  end if;
               end loop;
            end loop;
         end loop;
         if C = 0 or else C = 8 then
            return 0;
         end if;
         return Code (Sx) or Shift_Left (Code (Sy), 2) or Shift_Left (Code (Sz), 4);
      end Pull;

      --  The ground at the top of the column beside a top face at height Z:
      --  its highest block within a block of Z, if that is open above.
      function Surface (X, Y, Z : Integer) return Material is
      begin
         for Dz in reverse -1 .. 1 loop
            if Class_Of (Mat (X, Y, Z + Dz)) = Solid and then Class_Of (Mat (X, Y, Z + Dz + 1)) /= Solid then
               return Mat (X, Y, Z + Dz);
            end if;
         end loop;
         return Air;
      end Surface;

      --  The fringe of a top face (see the spec): which of the four blocks
      --  beside it (bits 0 .. 3: -x, +x, -y, +y) and of the four at its
      --  corners (bits 4 .. 7: -x -y, +x -y, +x +y, -x +y) are the other
      --  kind of ground, bare earth beside turf or turf beside bare earth.
      function Fringe (X, Y, Z : Integer; Mb : Material) return Unsigned_32 is
         type Steps is array (0 .. 7) of Integer;
         Ox : constant Steps := (-1, 1, 0, 0, -1, 1, 1, -1);
         Oy : constant Steps := (0, 0, -1, 1, -1, -1, 1, 1);
         R  : Unsigned_32 := 0;
      begin
         if Mb not in Turf | Bare then
            return 0;
         end if;
         for K in Steps'Range loop
            declare
               N : constant Material := Surface (X + Ox (K), Y + Oy (K), Z);
            begin
               if (if Mb in Turf then N in Bare else N in Turf) then
                  R := R or Shift_Left (1, K);
               end if;
            end;
         end loop;
         return R;
      end Fringe;

      function Visible (Mb, Mn : Material) return Boolean is
        (case Class_Of (Mb) is
            when Solid  => Class_Of (Mn) /= Solid,
            when Liquid => Class_Of (Mn) in Gas | Plant,
            when Plant  => Class_Of (Mn) /= Solid and then Mn /= Mb,
            when Gas    => False);

      --  Each column's highest solid block.  Water above it is the
      --  column's open-sky water, which the renderer draws as surface
      --  cells at fractional height; only water below (in tunnels and
      --  under overhangs) is meshed here as blocks.
      Top_Solid : array (0 .. Chunk_B - 1, 0 .. Chunk_B - 1) of Integer :=
        (others => (others => -1));

      procedure Emit (Face, X, Y, Z, Wd, Ht : Integer; Mt : Material; Ao, Fr : Unsigned_32; Tufted : Boolean) is
         Q : constant Quad :=
           (W0 => Unsigned_32 (X)
                  or Shift_Left (Unsigned_32 (Y), 5)
                  or Shift_Left (Unsigned_32 (Z), 10)
                  or Shift_Left (Unsigned_32 (Wd - 1), 20)
                  or Shift_Left (Unsigned_32 (Face), 25)
                  or (if Tufted then Tuft_Bit else 0),
            W1 => Unsigned_32 (Ht - 1)
                  or Shift_Left (Unsigned_32 (Material'Pos (Mt)), 8)
                  or Shift_Left (Ao, 16)
                  or Shift_Left (Fr, 24));
      begin
         if Mt = Castle.Blocks.Water then
            Push (Water_B, Q);
         elsif Tufted then
            Push (Tuft_B, Q);
         else
            Push (Solid_B, Q);
         end if;
      end Emit;

      --  How the four corners of a face of foliage are drawn in: six bits a
      --  corner, in the order the occlusion's are; and whether any of them
      --  is moved (drawn in on two axes or three: a flat side stays put).
      procedure Corner_Pulls (Face, X, Y, Z : Integer; F : out Unsigned_32; Moved : out Boolean) is
         D  : constant Integer := Face / 2;
         Up : constant Integer := (if Face mod 2 = 0 then 1 else 0);   --  the face's own plane
         type Steps is array (0 .. 3) of Integer;
         Cu : constant Steps := (0, 1, 1, 0);
         Cv : constant Steps := (0, 0, 1, 1);
      begin
         F := 0;
         Moved := False;
         for K in Steps'Range loop
            declare
               P : constant Unsigned_32 :=
                 (case D is
                     when 0      => Pull (X + Up, Y + Cu (K), Z + Cv (K)),
                     when 1      => Pull (X + Cu (K), Y + Up, Z + Cv (K)),
                     when others => Pull (X + Cu (K), Y + Cv (K), Z + Up));
               N : constant Natural :=
                 (if (P and 3) /= 0 then 1 else 0) + (if (P and 12) /= 0 then 1 else 0)
                 + (if (P and 48) /= 0 then 1 else 0);
            begin
               if N >= 2 then
                  F := F or Shift_Left (P, 6 * K);
                  Moved := True;
               end if;
            end;
         end loop;
      end Corner_Pulls;

      --  One face of one block of foliage, some corner of it moved.
      procedure Emit_Soft (Face, X, Y, Z : Integer; Mt : Material; F : Unsigned_32) is
      begin
         Push (Solid_B,
               (W0 => Unsigned_32 (X)
                      or Shift_Left (Unsigned_32 (Y), 5)
                      or Shift_Left (Unsigned_32 (Z), 10)
                      or Shift_Left (Unsigned_32 (Face), 25)
                      or Soft_Bit,
                W1 => (Shift_Right (F, 16) and 16#FF#)
                      or Shift_Left (Unsigned_32 (Material'Pos (Mt)), 8)
                      or Shift_Left (F and 16#FFFF#, 16)));
      end Emit_Soft;

   begin
      --  The band worth meshing: from the lowest skin block (everything
      --  under it is Deep, solid, and never shows) to the highest non-air.
      for I in Brick_Index loop
         for J in Brick_Index loop
            Z_Lo := Integer'Min (Z_Lo, Work.Skin (I, J) * Blocks_Per_Meter);
         end loop;
      end loop;
      for X in 0 .. Chunk_B - 1 loop
         for Y in 0 .. Chunk_B - 1 loop
            for Z in reverse Z_Lo .. Work.Air_From - 1 loop
               if Work.G (X, Y, Z).Mat /= Air then
                  Z_Hi := Integer'Max (Z_Hi, Z);
                  exit;
               end if;
            end loop;
         end loop;
      end loop;

      --  Edits in the rim reach down too: a neighbour's tunnel along the
      --  edge needs this stack's wall beside it.
      if Rim /= null then
         for E of Rim.all loop
            Z_Lo := Integer'Min (Z_Lo, Integer'Max (0, E.Z - 1));
         end loop;
      end if;

      if Z_Hi < Z_Lo then
         M := (Solid => null, Cast => 0, Water => null, Z_Lo => 0, Z_Hi => 0);
         return;
      end if;

      for K in 0 .. Chunk_B - 1 loop
         West (K)  := Edge_Of (X0 - 1, Y0 + K);
         East (K)  := Edge_Of (X0 + Chunk_B, Y0 + K);
         South (K) := Edge_Of (X0 + K, Y0 - 1);
         North (K) := Edge_Of (X0 + K, Y0 + Chunk_B);
      end loop;

      for X in 0 .. Chunk_B - 1 loop
         for Y in 0 .. Chunk_B - 1 loop
            for Z in reverse Z_Lo .. Z_Hi loop
               if Class_Of (Mat (X, Y, Z)) = Solid then
                  Top_Solid (X, Y) := Z;
                  exit;
               end if;
            end loop;
         end loop;
      end loop;

      for Face in 0 .. 5 loop
         declare
            D  : constant Integer := Face / 2;                 --  0 x, 1 y, 2 z
            S  : constant Integer := (if Face mod 2 = 0 then 1 else -1);
            Vn : constant Integer := (if D = 2 then Chunk_B else Z_Hi - Z_Lo + 1);
            Lo : constant Integer := (if D = 2 then Z_Lo else 0);
            Hi : constant Integer := (if D = 2 then Z_Hi else Chunk_B - 1);
            Dx : constant Integer := (if D = 0 then S else 0);
            Dy : constant Integer := (if D = 1 then S else 0);
            Dz : constant Integer := (if D = 2 then S else 0);
            --  The face's u and v axes (as the shader reads them).
            Ux : constant Integer := (if D = 0 then 0 else 1);
            Uy : constant Integer := (if D = 0 then 1 else 0);
            Vy : constant Integer := (if D = 2 then 1 else 0);
            Vz : constant Integer := (if D = 2 then 0 else 1);

            function Occ (X, Y, Z : Integer) return Natural is
              (if Class_Of (Mat (X, Y, Z)) = Solid then 1 else 0);

            --  Occlusion at the four corners of a face whose open side is
            --  the cell (Ox, Oy, Oz): a corner with solid blocks on both
            --  sides is fully boxed in, otherwise each solid neighbour
            --  (sides and diagonal) darkens it a step.
            function Corners (Ox, Oy, Oz : Integer) return Unsigned_32 is
               type Steps is array (0 .. 3) of Integer;
               Su : constant Steps := (-1, 1, 1, -1);
               Sv : constant Steps := (-1, -1, 1, 1);
               R  : Unsigned_32 := 0;
            begin
               for K in Steps'Range loop
                  declare
                     S1 : constant Natural := Occ (Ox + Su (K) * Ux, Oy + Su (K) * Uy, Oz);
                     S2 : constant Natural := Occ (Ox, Oy + Sv (K) * Vy, Oz + Sv (K) * Vz);
                     Cn : constant Natural :=
                       Occ (Ox + Su (K) * Ux, Oy + Su (K) * Uy + Sv (K) * Vy, Oz + Sv (K) * Vz);
                     A  : constant Natural := (if S1 + S2 = 2 then 0 else 3 - (S1 + S2 + Cn));
                  begin
                     R := R or Shift_Left (Unsigned_32 (A), 2 * K);
                  end;
               end loop;
               return R;
            end Corners;
         begin
            for Sl in Lo .. Hi loop
               --  which faces of this slice show, by material
               for V in 0 .. Vn - 1 loop
                  for U in 0 .. Chunk_B - 1 loop
                     declare
                        X  : constant Integer := (if D = 0 then Sl else U);
                        Y  : constant Integer := (if D = 0 then U elsif D = 1 then Sl else V);
                        Z  : constant Integer := (if D = 2 then Sl else Z_Lo + V);
                        Raw : constant Material := Work.G (X, Y, Z).Mat;
                        --  Deep laid open by an edit shows its real rock (or ore).
                        Mb  : constant Material :=
                          (if Raw /= Deep then Raw
                           else (declare
                                    R : constant Brick := Work.Rock (X / 4, Y / 4, Z / 4);
                                    V : constant Material := (if R.Grade < 128 then R.Host else R.Mat);
                                 begin
                                    (if V in Air | Deep | Castle.Blocks.Water then Granite else V)));
                        Shows : constant Boolean :=
                          Mb /= Air
                          and then not (Mb = Castle.Blocks.Water and then Z > Top_Solid (X, Y))
                          and then (if Mb in Tuft and then D < 2
                                    then Class_Of (Mat (X + Dx, Y + Dy, Z + Dz)) /= Solid   --  a tuft is whole by itself
                                    else Visible (Mb, Mat (X + Dx, Y + Dy, Z + Dz)));
                        Pulls : Unsigned_32 := 0;
                        Moved : Boolean := False;
                     begin
                        if Shows and then Mb in Soft then
                           Corner_Pulls (Face, X, Y, Z, Pulls, Moved);
                        end if;
                        if Moved then
                           Mask (U, V) := 0;
                           Emit_Soft (Face, X, Y, Z, Mb, Pulls);   --  a block's face of its own, never merged
                        elsif Shows and then Mb in Tuft then
                           Mask (U, V) :=
                             Unsigned_32 (Material'Pos (Mb) + 1) or 16#FF00# or Mask_Tuft
                             or (if U mod 2 = 1 then Mask_Odd_U else 0)
                             or (if D = 2 and then V mod 2 = 1 then Mask_Odd_V else 0);
                        else
                           Mask (U, V) :=
                             (if Shows
                              then Unsigned_32 (Material'Pos (Mb) + 1)
                                   or Shift_Left (Corners (X + Dx, Y + Dy, Z + Dz), 8)
                                   or (if Face = 4 then Shift_Left (Fringe (X, Y, Z, Mb), 16) else 0)
                              else 0);
                        end if;
                     end;
                  end loop;
               end loop;

               --  merge equal faces into rectangles
               for V in 0 .. Vn - 1 loop
                  declare
                     U : Integer := 0;
                  begin
                     while U < Chunk_B loop
                        declare
                           C : constant Unsigned_32 := Mask (U, V);
                        begin
                           if C = 0 then
                              U := U + 1;
                           else
                              declare
                                 Wd   : Integer := 1;
                                 Ht   : Integer := 1;
                                 Done : Boolean := False;
                              begin
                                 while U + Wd < Chunk_B and then Mask (U + Wd, V) = C loop
                                    Wd := Wd + 1;
                                 end loop;
                                 while not Done and then V + Ht < Vn and then Ht < 256 loop
                                    for K in 0 .. Wd - 1 loop
                                       if Mask (U + K, V + Ht) /= C then
                                          Done := True;
                                          exit;
                                       end if;
                                    end loop;
                                    if not Done then
                                       Ht := Ht + 1;
                                    end if;
                                 end loop;
                                 for Hv in 0 .. Ht - 1 loop
                                    for K in 0 .. Wd - 1 loop
                                       Mask (U + K, V + Hv) := 0;
                                    end loop;
                                 end loop;
                                 Emit (Face,
                                       X  => (if D = 0 then Sl else U),
                                       Y  => (if D = 0 then U elsif D = 1 then Sl else V),
                                       Z  => (if D = 2 then Sl else Z_Lo + V),
                                       Wd => Wd, Ht => Ht,
                                       Mt => Material'Val (Integer (C and 255) - 1),
                                       Ao => Shift_Right (C, 8) and 255,
                                       Fr => (if (C and Mask_Tuft) /= 0 then 0 else Shift_Right (C, 16) and 255),
                                       Tufted => (C and Mask_Tuft) /= 0);
                                 U := U + Wd;
                              end;
                           end if;
                        end;
                     end loop;
                  end;
               end loop;
            end loop;
         end;
      end loop;

      --  the tufts after everything that can cast a shadow
      declare
         Casting : constant Natural := Solid_B.Count;
      begin
         for K in 1 .. Tuft_B.Count loop
            Push (Solid_B, Tuft_B.Data (K));
         end loop;
         if Tuft_B.Data /= null then
            Free_Q (Tuft_B.Data);
         end if;
         M := (Solid => Take (Solid_B), Cast => Casting, Water => Take (Water_B), Z_Lo => Z_Lo, Z_Hi => Z_Hi);
      end;
   end Build;

end Castle.Mesher;
