with Ada.Unchecked_Deallocation;
with Castle.Blocks;  use Castle.Blocks;
with Castle.Dims;    use Castle.Dims;
with Castle.Geology; use Castle.Geology;
with Castle.Flora;

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
            return Seen_Mat (Work.G (X, Y, Z));
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
      --  (Round_Boulders) On a stack's edge a boulder's corner is drawn in
      --  all the same, by what the stacks on both sides can work out alike
      --  from the generator alone: the ground as it was made, and the
      --  boulders' shapes as they were made (the boulders near the stack,
      --  looked up once, when the first such corner comes).  An edit there
      --  is not seen (the corner may lean toward a stone taken away), but
      --  the two stacks never disagree, so no slit opens between them.
      Rocks   : array (1 .. 36) of Castle.Flora.Lump;
      Rocks_N : Integer := -1;
      type Rock_Bits is array (-32 .. 31) of Boolean;
      type Column_Memo is record
         Bx, By : Integer   := Integer'First;
         Solid  : Integer   := 0;
         Rock   : Rock_Bits := [others => False];   --  block Solid + K is a boulder's
      end record;
      Memo      : array (1 .. 16) of Column_Memo;
      Memo_Next : Natural := 0;
      --  0 open, 1 ground, 2 a boulder
      function Made_Body (Bx, By, Bz : Integer) return Natural is
      begin
         if Rocks_N < 0 then
            Rocks_N := 0;
            for J in Floor_Div (Y0 - 1 - Castle.Flora.Rock_Reach, Castle.Flora.Rock_Cell)
                  .. Floor_Div (Y0 + Chunk_B + Castle.Flora.Rock_Reach, Castle.Flora.Rock_Cell)
            loop
               for I in Floor_Div (X0 - 1 - Castle.Flora.Rock_Reach, Castle.Flora.Rock_Cell)
                     .. Floor_Div (X0 + Chunk_B + Castle.Flora.Rock_Reach, Castle.Flora.Rock_Cell)
               loop
                  declare
                     L : constant Castle.Flora.Lump := Castle.Flora.Boulder_At (W, I, J);
                  begin
                     if L.Valid and then Rocks_N < Rocks'Last then
                        Rocks_N := Rocks_N + 1;
                        Rocks (Rocks_N) := L;
                     end if;
                  end;
               end loop;
            end loop;
         end if;
         if Bx < 0 or else By < 0 or else Bx >= Size_B or else By >= Size_B then
            return 0;                              --  (past the world's rim: open, as Edge_Of has it)
         end if;
         --  (a column is worked out once for the corners round it: the last
         --  sixteen are kept, the ground's level and its rock 32 blocks either
         --  side of that, all the boulders near it as one)
         declare
            Slot : Natural := 0;
         begin
            for M in Memo'Range loop
               if Memo (M).Bx = Bx and then Memo (M).By = By then
                  Slot := M;
               end if;
            end loop;
            if Slot = 0 then
               Memo_Next := Memo_Next mod Memo'Last + 1;
               Slot := Memo_Next;
               declare
                  C  : constant Column := Prepare_Column (W, Bx, By);
                  Mc : Column_Memo renames Memo (Slot);
               begin
                  Mc := (Bx => Bx, By => By, Solid => C.Solid, Rock => [others => False]);
                  for K in 1 .. Rocks_N loop
                     if abs (Bx - Rocks (K).Cx) <= Castle.Flora.Rock_Reach_Of (Rocks (K))
                       and then abs (By - Rocks (K).Cy) <= Castle.Flora.Rock_Reach_Of (Rocks (K))
                     then
                        declare
                           Lo   : Integer;
                           Span : Castle.Flora.Rock_Span;
                        begin
                           Castle.Flora.Rock_Column (Rocks (K), Bx, By, C, Lo, Span);
                           for Q in Span'Range loop
                              if Span (Q) and then Lo + Q - C.Solid in Mc.Rock'Range then
                                 Mc.Rock (Lo + Q - C.Solid) := True;
                              end if;
                           end loop;
                        end;
                     end if;
                  end loop;
               end;
            end if;
            declare
               Mc : Column_Memo renames Memo (Slot);
            begin
               if Bz - Mc.Solid in Mc.Rock'Range and then Mc.Rock (Bz - Mc.Solid) then
                  return 2;
               end if;
               return (if Bz < Mc.Solid then 1 else 0);
            end;
         end;
      end Made_Body;

      --  (Rock: a boulder's corner.  Its body is what is solid about it, grass
      --  round its foot or a bush no part of it; and a hollow in the rock
      --  itself, a corner with rock on five sides or more and nothing else,
      --  is drawn out toward the open as an edge is drawn in, so a notch or
      --  a step in it is filled to a slope as well: then the code has 64 in
      --  it besides.)
      --  (Boulder_Feet) Where a boulder meets level ground (rock over the corner
      --  on one side, the open on the other, and nothing but solid under it)
      --  the corner is its foot: drawn out away from the rock and down into
      --  the ground, so the rock's lowest faces spread into the ground and
      --  go under it; z code 3 says so.  The ground's own corners stay put:
      --  a foot only ever goes down and over solid ground at its level.
      function Pull (Gx, Gy, Gz : Integer; Rock : Boolean := False) return Unsigned_32 is
         Sx, Sy, Sz, C, R : Integer := 0;
         Under, Gu, Ra, Ga, Oa, Fx, Fy : Integer := 0;  --  (for the foot: solid and ground under; rock, ground, open over; rock's sums)
         function Code (S : Integer; Of_N : Integer) return Unsigned_32 is
           (if 2 * abs S >= Of_N then (if S > 0 then 1 else 2) else 0);
         Edge : constant Boolean := Gx = 0 or else Gx = Chunk_B or else Gy = 0 or else Gy = Chunk_B;
      begin
         if Edge and then not Rock then
            return 0;
         end if;
         for Dz in -1 .. 0 loop
            for Dy in -1 .. 0 loop
               for Dx in -1 .. 0 loop
                  --  (a boulder's body is what is solid about it: grass round its foot,
                  --  or a bush, is no part of it)
                  declare
                     M : constant Material := (if Edge then Air else Mat (Gx + Dx, Gy + Dy, Gz + Dz));
                     K : constant Natural :=
                       (if Edge then Made_Body (X0 + Gx + Dx, Y0 + Gy + Dy, Gz + Dz)
                        elsif Rock then (if M = Boulder then 2 elsif Class_Of (M) = Solid then 1 else 0)
                        elsif Class_Of (M) in Solid | Plant then 1 else 0);
                  begin
                     if K > 0 then
                        C := C + 1;
                        R := R + (if K = 2 then 1 else 0);
                        Sx := Sx + 2 * Dx + 1;
                        Sy := Sy + 2 * Dy + 1;
                        Sz := Sz + 2 * Dz + 1;
                     end if;
                     if Dz = -1 then
                        Under := Under + (if K > 0 then 1 else 0);
                        Gu := Gu + (if K = 1 then 1 else 0);
                     elsif K = 2 then
                        Ra := Ra + 1;
                        Fx := Fx + 2 * Dx + 1;
                        Fy := Fy + 2 * Dy + 1;
                     elsif K = 1 then
                        Ga := Ga + 1;
                     else
                        Oa := Oa + 1;
                     end if;
                  end;
               end loop;
            end loop;
         end loop;
         --  (ground under it too: a step within the rock itself is a hollow, below)
         if Rock and then Round_Boulders and then Boulder_Feet and then Under = 4 and then Gu > 0 and then Ra > 0 and then Ga = 0
           and then Oa > 0 and then (Code (-Fx, Ra) /= 0 or else Code (-Fy, Ra) /= 0)
         then
            return Code (-Fx, Ra) or Shift_Left (Code (-Fy, Ra), 2) or Shift_Left (3, 4);
         end if;
         if C = 0 or else C = 8 then
            return 0;
         elsif Rock and then C >= 5 and then R = C then
            --  (the open part's sums are the whole's, less the body's: the whole's are 0)
            return Code (-Sx, 8 - C) or Shift_Left (Code (-Sy, 8 - C), 2) or Shift_Left (Code (-Sz, 8 - C), 4) or 64;
         end if;
         return Code (Sx, C) or Shift_Left (Code (Sy, C), 2) or Shift_Left (Code (Sz, C), 4);
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
      procedure Corner_Pulls (Face, X, Y, Z : Integer; F : out Unsigned_32; Moved : out Boolean;
                              Rock : Boolean := False; Outs : out Unsigned_32) is
         D  : constant Integer := Face / 2;
         Up : constant Integer := (if Face mod 2 = 0 then 1 else 0);   --  the face's own plane
         type Steps is array (0 .. 3) of Integer;
         Cu : constant Steps := (0, 1, 1, 0);
         Cv : constant Steps := (0, 0, 1, 1);
      begin
         F := 0;
         Moved := False;
         Outs := 0;
         for K in Steps'Range loop
            declare
               P : constant Unsigned_32 :=
                 (case D is
                     when 0      => Pull (X + Up, Y + Cu (K), Z + Cv (K), Rock),
                     when 1      => Pull (X + Cu (K), Y + Up, Z + Cv (K), Rock),
                     when others => Pull (X + Cu (K), Y + Cv (K), Z + Up, Rock));
               N : constant Natural :=
                 (if (P and 3) /= 0 then 1 else 0) + (if (P and 12) /= 0 then 1 else 0)
                 + (if (P and 48) /= 0 then 1 else 0);
            begin
               if N >= 2 then
                  F := F or Shift_Left (P and 63, 6 * K);
                  Outs := Outs or (if (P and 64) /= 0 then Shift_Left (1, K) else 0);
                  Moved := True;
               end if;
            end;
         end loop;
      end Corner_Pulls;

      --  A dressed block of thatch (see the spec): how the corner of it at
      --  (Cx, Cy, Cz), each 0 or 1 within the block, is moved, by its state.
      function Slope_Code (Mt : Material; State : Unsigned_8; Cx, Cy, Cz : Integer) return Unsigned_32 is
         Falls  : constant Unsigned_8 := State and Falls_Mask;
         Out_C  : constant Integer := (if Falls < 2 then Cx else Cy);        --  along the way it falls
         Side_C : constant Integer := (if Falls < 2 then Cy else Cx);        --  along its row
         Outer  : constant Boolean := Out_C = (if Falls mod 2 = 0 then 1 else 0);
         Ridge  : constant Boolean := (State and At_Ridge) /= 0;
         Drawn  : constant Boolean :=
           (Side_C = 0 and then (State and Verge_Lo) /= 0) or else (Side_C = 1 and then (State and Verge_Hi) /= 0);
         Code   : Unsigned_32 := 0;
      begin
         if Mt = Daub then                                                   --  a gable's top: its inner edge up a block
            return (if Cz = 1 and then not Outer then Shift_Left (1, 4) else 0);
         end if;
         if (State and Under) /= 0 then                                      --  its underside: the inner edge up a block
            return (if Cz = 0 and then not Outer then Shift_Left (1, 4) else 0)
              or (if Drawn then Shift_Left ((if Side_C = 0 then 1 else 2), (if Falls < 2 then 2 else 0)) else 0);
         end if;
         if Full_Thatch then
            --  Fuller: the slope lies over the steps' noses, not in their hollows (the inner edge
            --  of each block's top up a block, its outer edge where it is); the eave's edge a whole
            --  block thick and drawn out a little; the ridge's one middle block level.
            if Cz = 1 and then not Outer and then not Ridge then
               Code := Shift_Left (1, 4);
            end if;
            if Outer and then (State and At_Eave) /= 0 then
               Code := Code or Shift_Left ((if Falls mod 2 = 0 then 1 else 2), (if Falls < 2 then 0 else 2));
            end if;
            if Drawn and then (Cz = 1 or else (State and At_Eave) = 0) then
               Code := Code or Shift_Left ((if Side_C = 0 then 1 else 2), (if Falls < 2 then 2 else 0));
            end if;
            return Code;
         end if;
         if Cz = 0 then
            return (if Drawn and then (State and At_Eave) = 0
                    then Shift_Left ((if Side_C = 0 then 1 else 2), (if Falls < 2 then 2 else 0)) else 0);
         end if;
         if Ridge then
            Code := Shift_Left (3, 4);                                       --  both its edges half a block down
         elsif Outer then
            Code := Shift_Left ((if (State and At_Eave) /= 0 then 3 else 2), 4);
         end if;
         if Drawn then                                                       --  a quarter in from the roof's end
            Code := Code or Shift_Left ((if Side_C = 0 then 1 else 2), (if Falls < 2 then 2 else 0));
         end if;
         return Code;
      end Slope_Code;

      --  And whether that corner is of the roof's ragged edge (Full_Thatch):
      --  the eave's outer edge, and the end of a row at a verge, above and
      --  below.  The renderer lets such a corner hang a little, each by its
      --  place (John, 2026-11-17: "add charecter of straw to the edges of
      --  the roof").
      function Slope_Rag (Mt : Material; State : Unsigned_8; Cx, Cy, Cz : Integer) return Boolean is
         Falls  : constant Unsigned_8 := State and Falls_Mask;
         Out_C  : constant Integer := (if Falls < 2 then Cx else Cy);
         Side_C : constant Integer := (if Falls < 2 then Cy else Cx);
         Outer  : constant Boolean := Out_C = (if Falls mod 2 = 0 then 1 else 0);
      begin
         --  (and, Ragged_Surface, every corner of the roof's top: the renderer tells those from the
         --  edge's by their having no pull along the ground)
         return Full_Thatch and then Mt = Thatch
           and then ((Outer and then (State and At_Eave) /= 0 and then (State and Under) = 0)
                     or else (Side_C = 0 and then (State and Verge_Lo) /= 0)
                     or else (Side_C = 1 and then (State and Verge_Hi) /= 0)
                     or else (Ragged_Surface and then Cz = 1 and then (State and Under) = 0));
      end Slope_Rag;
      function Slope_Rags (Face : Integer; Mt : Material; State : Unsigned_8) return Unsigned_32 is
         D  : constant Integer := Face / 2;
         Up : constant Integer := (if Face mod 2 = 0 then 1 else 0);
         type Steps is array (0 .. 3) of Integer;
         Cu : constant Steps := (0, 1, 1, 0);
         Cv : constant Steps := (0, 0, 1, 1);
         R  : Unsigned_32 := 0;
      begin
         for K in Steps'Range loop
            if (case D is
                   when 0      => Slope_Rag (Mt, State, Up, Cu (K), Cv (K)),
                   when 1      => Slope_Rag (Mt, State, Cu (K), Up, Cv (K)),
                   when others => Slope_Rag (Mt, State, Cu (K), Cv (K), Up))
            then
               R := R or Shift_Left (1, K);
            end if;
         end loop;
         return R;
      end Slope_Rags;

      --  The four corners of a face of a dressed block, in the occlusion's order.
      function Slope_Pulls (Face : Integer; Mt : Material; State : Unsigned_8) return Unsigned_32 is
         D  : constant Integer := Face / 2;
         Up : constant Integer := (if Face mod 2 = 0 then 1 else 0);
         type Steps is array (0 .. 3) of Integer;
         Cu : constant Steps := (0, 1, 1, 0);
         Cv : constant Steps := (0, 0, 1, 1);
         F  : Unsigned_32 := 0;
      begin
         for K in Steps'Range loop
            F := F or Shift_Left ((case D is
                                      when 0      => Slope_Code (Mt, State, Up, Cu (K), Cv (K)),
                                      when 1      => Slope_Code (Mt, State, Cu (K), Up, Cv (K)),
                                      when others => Slope_Code (Mt, State, Cu (K), Cv (K), Up)),
                                  6 * K);
         end loop;
         return F;
      end Slope_Pulls;

      --  One face of one block of foliage, some corner of it moved (Slope: of
      --  a dressed block of thatch).
      procedure Emit_Soft (Face, X, Y, Z : Integer; Mt : Material; F : Unsigned_32; Slope : Boolean := False;
                           Outs : Unsigned_32 := 0) is
      begin
         Push (Solid_B,
               (W0 => Unsigned_32 (X)
                      or Shift_Left (Unsigned_32 (Y), 5)
                      or Shift_Left (Unsigned_32 (Z), 10)
                      or Shift_Left (Outs, 20)
                      or Shift_Left (Unsigned_32 (Face), 25)
                      or Soft_Bit or (if Slope then Slope_Bit else 0),
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
               if Seen_Mat (Work.G (X, Y, Z)) /= Air then
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
                        Raw : constant Material := Seen_Mat (Work.G (X, Y, Z));
                        --  Deep laid open by an edit shows its real rock (or ore).
                        Mb  : constant Material :=
                          (if Raw /= Deep then Raw
                           else (declare
                                    R : constant Brick := Work.Rock (X / 4, Y / 4, Z / 4);
                                    V : constant Material := (if R.Grade < 128 then R.Host else R.Mat);
                                 begin
                                    (if V in Air | Deep | Castle.Blocks.Water then Granite else V)));
                        State : constant Unsigned_8 := Work.G (X, Y, Z).State;
                        Trim  : constant Boolean := Raw in Thatch | Daub and then (State and Dressed) /= 0;
                        --  what it faces is a dressed block of thatch of this stack that it looks along the
                        --  row of (and is not its like): the trimmed block no longer hides this face
                        Past_Trim : constant Boolean :=
                          D < 2 and then X + Dx in 0 .. Chunk_B - 1 and then Y + Dy in 0 .. Chunk_B - 1
                          and then Work.G (X + Dx, Y + Dy, Z).Mat = Thatch
                          and then (Work.G (X + Dx, Y + Dy, Z).State and Dressed) /= 0
                          and then ((Work.G (X + Dx, Y + Dy, Z).State and Falls_Mask) < 2) = (D = 1)
                          and then not (Trim and then Work.G (X + Dx, Y + Dy, Z).State = State);
                        --  under a roof: a face of a wall, a gable or the frame that thatch lies on is
                        --  drawn (hidden while the roof is whole), since a roof can be cleared on the
                        --  camera's ray (Castle.Cutaway) and the wall's top would be open under it
                        Under_Roof : constant Boolean :=
                          Mb /= Thatch and then not Trim and then Class_Of (Mb) = Solid
                          and then Mat (X + Dx, Y + Dy, Z + Dz) = Thatch;
                        --  under a wall: the top of the ground a house's wall stands on (daub, or the
                        --  frame's timber, which is a trunk's too: so the ground under a tree as well)
                        --  is drawn, since the walls on the camera's side can be cleared with the roof
                        Under_Wall : constant Boolean :=
                          Dz = 1 and then Class_Of (Mb) = Solid and then Mb not in Daub | Log
                          and then Mat (X, Y, Z + 1) in Daub | Log;
                        --  against a boulder (Round_Boulders): drawn, as its corners are drawn in
                        Under_Rock : constant Boolean :=
                          Round_Boulders and then Class_Of (Mb) = Solid and then Mb /= Boulder
                          and then Mat (X + Dx, Y + Dy, Z + Dz) = Boulder;
                        Shows : constant Boolean :=
                          Mb /= Air
                          and then not (Mb = Castle.Blocks.Water and then Z > Top_Solid (X, Y))
                          and then (if Mb in Tuft and then D < 2
                                    then Class_Of (Mat (X + Dx, Y + Dy, Z + Dz)) /= Solid   --  a tuft is whole by itself
                                    else Visible (Mb, Mat (X + Dx, Y + Dy, Z + Dz))
                                         or else (Past_Trim and then Class_Of (Mb) = Solid)
                                         or else Under_Roof or else Under_Wall or else Under_Rock);
                        Pulls : Unsigned_32 := 0;
                        Outs  : Unsigned_32 := 0;
                        Moved : Boolean := False;
                     begin
                        if Shows and then Trim then
                           Mask (U, V) := 0;
                           Emit_Soft (Face, X, Y, Z, Mb, Slope_Pulls (Face, Mb, State), Slope => True,
                                      Outs => Slope_Rags (Face, Mb, State));
                        elsif Shows and then (Mb in Soft or else (Round_Boulders and then Mb = Boulder)) then
                           Corner_Pulls (Face, X, Y, Z, Pulls, Moved, Rock => Mb = Boulder, Outs => Outs);
                        end if;
                        if Shows and then Trim then
                           null;
                        elsif Moved then
                           Mask (U, V) := 0;
                           Emit_Soft (Face, X, Y, Z, Mb, Pulls, Outs => Outs);   --  a block's face of its own, never merged
                        elsif Shows and then Mb in Tuft then
                           Mask (U, V) :=
                             Unsigned_32 (Material'Pos (Mb) + 1) or 16#FF00# or Mask_Tuft
                             or (if U mod 2 = 1 then Mask_Odd_U else 0)
                             or (if D = 2 and then V mod 2 = 1 then Mask_Odd_V else 0);
                        else
                           Mask (U, V) :=
                             (if Shows
                              then Unsigned_32 (Material'Pos (Mb) + 1)
                                   or Shift_Left ((if Under_Roof or else Under_Wall or else Under_Rock then 16#FF#
                                                   else Corners (X + Dx, Y + Dy, Z + Dz)), 8)
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
