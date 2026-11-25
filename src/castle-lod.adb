with Ada.Real_Time;  use Ada.Real_Time;
with Ada.Unchecked_Deallocation;
with Interfaces;     use Interfaces;
with Castle.Edits;
with Castle.Geology;

package body Castle.Lod is

   use Castle.Mesher;

   function Occ (M : Material) return Boolean is (M /= Air and then M /= Water) with Inline;

   subtype Thin is Material
     with Static_Predicate => Thin in Trunk | Plank | Shingle | Thatch | Daub | Fieldstone;

   --  A block as a tile has it: a tuft is nothing.
   function Seen (M : Material) return Material is (if M in Tuft then Air else M) with Inline;

   --  The thing there is most of among K (From .. To): of everything that
   --  is something, or of the thin things alone.
   function Most (K : Kids; From, To : Natural; Thin_Only : Boolean) return Material is
      Best   : Material := Air;
      Best_N : Natural := 0;
   begin
      for I in From .. To loop
         if Occ (K (I)) and then (not Thin_Only or else K (I) in Thin) then
            declare
               N : Natural := 0;
            begin
               for J in From .. To loop
                  if K (J) = K (I) then
                     N := N + 1;
                  end if;
               end loop;
               if N > Best_N then
                  Best_N := N;
                  Best := K (I);
               end if;
            end;
         end if;
      end loop;
      return Best;
   end Most;

   function Parent (K : Kids) return Material is
      N_Occ, N_W, Up_W, N_Thin : Natural := 0;
   begin
      for I in K'Range loop
         if K (I) = Water then
            N_W := N_W + 1;
            if I >= 4 then
               Up_W := Up_W + 1;
            end if;
         elsif K (I) /= Air then
            N_Occ := N_Occ + 1;
            if K (I) in Thin then
               N_Thin := N_Thin + 1;
            end if;
         end if;
      end loop;
      if N_Occ + N_W = 0 then
         return Air;
      elsif Up_W >= 2 and then N_Occ + N_W >= 4 then
         return Water;
      elsif N_Occ >= 4 then
         declare
            U : constant Material := Most (K, 4, 7, False);
         begin
            return (if U /= Air then U else Most (K, 0, 3, False));
         end;
      elsif N_W >= 1 and then N_Occ + N_W >= 4 then
         return Water;
      elsif N_Thin >= 2 then
         return Most (K, 0, 7, True);
      else
         return Air;
      end if;
   end Parent;

   --  A stack's blocks in rows B_Lo .. B_Hi (B_Lo even, B_Hi odd), by halves into Dst.
   procedure From_Blocks (Work : Stack_Work; B_Lo, B_Hi : Integer; Dst : in out Mip) is
      K : Kids;
   begin
      for X in 0 .. Chunk_B / 2 - 1 loop
         for Y in 0 .. Chunk_B / 2 - 1 loop
            for Z in B_Lo / 2 .. B_Hi / 2 loop
               for I in K'Range loop
                  K (I) := Seen (Seen_Mat (Work.G (2 * X + I mod 2, 2 * Y + (I / 2) mod 2, 2 * Z + I / 4)));
               end loop;
               Dst (X, Y, Z) := Parent (K);
            end loop;
         end loop;
      end loop;
   end From_Blocks;

   --  Src, N cells a side in rows Lo .. Hi (Lo even, Hi odd), by halves into Dst.
   procedure Halve (Src : Mip; N : Positive; Lo, Hi : Integer; Dst : in out Mip) is
      K : Kids;
   begin
      for X in 0 .. N / 2 - 1 loop
         for Y in 0 .. N / 2 - 1 loop
            for Z in Lo / 2 .. Hi / 2 loop
               for I in K'Range loop
                  K (I) := Src (2 * X + I mod 2, 2 * Y + (I / 2) mod 2, 2 * Z + I / 4);
               end loop;
               Dst (X, Y, Z) := Parent (K);
            end loop;
         end loop;
      end loop;
   end Halve;

   ------------------------------------------------------------------ meshing

   type Buffer is record
      Data  : Quad_Access;
      Count : Natural := 0;
   end record;

   procedure Free_Q is new Ada.Unchecked_Deallocation (Quad_Array, Quad_Access);

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

   procedure Mesh_Cells
     (S : Scratch; Z_Lo, Z_Hi : Integer; West, East, South, North : Edge_Tops;
      M : out Castle.Mesher.Mesh; With_AO : Boolean := True)
   is
      Solid_B, Water_B : Buffer;
      Top : Column_Rows;                    --  each column's highest cell that is something (Z_Lo - 1: none)
      Vz  : constant Integer := Z_Hi - Z_Lo + 1;

      function Cell (X, Y, Z : Integer) return Material is
      begin
         if Z < Z_Lo then
            return Deep;
         elsif Z > Z_Hi then
            return Air;
         elsif X in 0 .. Chunk_B - 1 and then Y in 0 .. Chunk_B - 1 then
            return S.C (X, Y, Z);
         end if;
         declare
            --  (past a corner of the tile, the nearest edge column stands in)
            Yc : constant Integer := Integer'Max (0, Integer'Min (Chunk_B - 1, Y));
            E  : constant Integer :=
              (if X < 0 then West (Yc) elsif X >= Chunk_B then East (Yc)
               elsif Y < 0 then South (X) else North (X));
         begin
            return (if Z < E then Deep else Air);
         end;
      end Cell;

      procedure Emit (Face, X, Y, Z, Wd, Ht : Integer; Mt : Material; Ao : Unsigned_32) is
         Q : constant Quad :=
           (W0 => Unsigned_32 (X)
                  or Shift_Left (Unsigned_32 (Y), 5)
                  or Shift_Left (Unsigned_32 (Z), 10)
                  or Shift_Left (Unsigned_32 (Wd - 1), 20)
                  or Shift_Left (Unsigned_32 (Face), 25),
            W1 => Unsigned_32 (Ht - 1)
                  or Shift_Left (Unsigned_32 (Material'Pos (Mt)), 8)
                  or Shift_Left (Ao, 16));
      begin
         if Mt = Water then
            Push (Water_B, Q);
         else
            Push (Solid_B, Q);
         end if;
      end Emit;

      type Mask_Grid is array (0 .. Chunk_B - 1, 0 .. Integer'Max (Chunk_B, Vz) - 1) of Unsigned_32;
      Mask : Mask_Grid;
   begin
      M := (Solid => null, Cast => 0, Water => null, Z_Lo => 0, Z_Hi => 0);
      if Z_Hi < Z_Lo then
         return;
      end if;
      for X in 0 .. Chunk_B - 1 loop
         for Y in 0 .. Chunk_B - 1 loop
            Top (X, Y) := Z_Lo - 1;
            for Z in reverse Z_Lo .. Z_Hi loop
               if Occ (S.C (X, Y, Z)) then
                  Top (X, Y) := Z;
                  exit;
               end if;
            end loop;
         end loop;
      end loop;

      for Face in 0 .. 5 loop
         declare
            D  : constant Integer := Face / 2;                 --  0 x, 1 y, 2 z
            Sg : constant Integer := (if Face mod 2 = 0 then 1 else -1);
            Vn : constant Integer := (if D = 2 then Chunk_B else Vz);
            Lo : constant Integer := (if D = 2 then Z_Lo else 0);
            Hi : constant Integer := (if D = 2 then Z_Hi else Chunk_B - 1);
            Dx : constant Integer := (if D = 0 then Sg else 0);
            Dy : constant Integer := (if D = 1 then Sg else 0);
            Dz : constant Integer := (if D = 2 then Sg else 0);
            Ux : constant Integer := (if D = 0 then 0 else 1);
            Uy : constant Integer := (if D = 0 then 1 else 0);
            Vy : constant Integer := (if D = 2 then 1 else 0);
            Vzz : constant Integer := (if D = 2 then 0 else 1);

            function Occ_N (X, Y, Z : Integer) return Natural is (if Occ (Cell (X, Y, Z)) then 1 else 0);

            --  (as the mesher's: two bits a corner, 3 open .. 0 boxed in)
            function Corners (Ox, Oy, Oz : Integer) return Unsigned_32 is
               type Steps is array (0 .. 3) of Integer;
               Su : constant Steps := (-1, 1, 1, -1);
               Sv : constant Steps := (-1, -1, 1, 1);
               R  : Unsigned_32 := 0;
            begin
               for K in Steps'Range loop
                  declare
                     S1 : constant Natural := Occ_N (Ox + Su (K) * Ux, Oy + Su (K) * Uy, Oz);
                     S2 : constant Natural := Occ_N (Ox, Oy + Sv (K) * Vy, Oz + Sv (K) * Vzz);
                     Cn : constant Natural :=
                       Occ_N (Ox + Su (K) * Ux, Oy + Su (K) * Uy + Sv (K) * Vy, Oz + Sv (K) * Vzz);
                     A  : constant Natural := (if S1 + S2 = 2 then 0 else 3 - (S1 + S2 + Cn));
                  begin
                     R := R or Shift_Left (Unsigned_32 (A), 2 * K);
                  end;
               end loop;
               return R;
            end Corners;
         begin
            for Sl in Lo .. Hi loop
               for V in 0 .. Vn - 1 loop
                  for U in 0 .. Chunk_B - 1 loop
                     declare
                        X  : constant Integer := (if D = 0 then Sl else U);
                        Y  : constant Integer := (if D = 0 then U elsif D = 1 then Sl else V);
                        Z  : constant Integer := (if D = 2 then Sl else Z_Lo + V);
                        Mb : constant Material := S.C (X, Y, Z);
                        Key : Unsigned_32 := 0;
                     begin
                        if Mb = Water then
                           if Face = 4 and then Cell (X, Y, Z + 1) = Air then
                              Key := Unsigned_32 (Material'Pos (Water)) + 1 + Shift_Left (255, 8);
                           end if;
                        elsif Mb /= Air then
                           declare
                              Out_Side : constant Boolean :=
                                X + Dx not in 0 .. Chunk_B - 1 or else Y + Dy not in 0 .. Chunk_B - 1;
                              Mn : constant Material := Cell (X + Dx, Y + Dy, Z + Dz);
                           begin
                              --  (the top of what a building's cell stands on is drawn too: a building
                              --  drawn turned, Castle.Render.Set_Turns, is drawn elsewhere, and the
                              --  ground it stands on showed as a hole along its walls)
                              if not Occ (Mn) or else (Out_Side and then Z > Top (X, Y) - Skirt_Cells)
                                or else (Face = 4 and then Mn in Daub | Log | Thatch | Plank
                                         and then Mb not in Daub | Log | Thatch | Plank)
                              then
                                 Key := Unsigned_32 (Material'Pos ((if Mb = Deep then Granite else Mb))) + 1
                                   + Shift_Left ((if With_AO and then not Occ (Mn)
                                                  then Corners (X + Dx, Y + Dy, Z + Dz) else 255), 8);
                              end if;
                           end;
                        end if;
                        Mask (U, V) := Key;
                     end;
                  end loop;
               end loop;
               for V in 0 .. Vn - 1 loop
                  declare
                     U : Integer := 0;
                  begin
                     while U < Chunk_B loop
                        if Mask (U, V) = 0 then
                           U := U + 1;
                        else
                           declare
                              Key : constant Unsigned_32 := Mask (U, V);
                              Wd  : Integer := 1;
                              Ht  : Integer := 1;
                              Same : Boolean;
                           begin
                              while U + Wd < Chunk_B and then Mask (U + Wd, V) = Key loop
                                 Wd := Wd + 1;
                              end loop;
                              loop
                                 exit when V + Ht >= Vn or else Ht = 256;
                                 Same := True;
                                 for K in U .. U + Wd - 1 loop
                                    if Mask (K, V + Ht) /= Key then
                                       Same := False;
                                       exit;
                                    end if;
                                 end loop;
                                 exit when not Same;
                                 Ht := Ht + 1;
                              end loop;
                              for J in V .. V + Ht - 1 loop
                                 for K in U .. U + Wd - 1 loop
                                    Mask (K, J) := 0;
                                 end loop;
                              end loop;
                              Emit (Face,
                                    (if D = 0 then Sl else U),
                                    (if D = 0 then U elsif D = 1 then Sl else V),
                                    (if D = 2 then Sl else Z_Lo + V),
                                    Wd, Ht, Material'Val (Integer (Key and 255) - 1), Shift_Right (Key, 8) and 255);
                              U := U + Wd;
                           end;
                        end if;
                     end loop;
                  end;
               end loop;
            end loop;
         end;
      end loop;

      M.Cast := Solid_B.Count;
      M.Solid := Take (Solid_B);
      M.Water := Take (Water_B);
      M.Z_Lo := Z_Lo;
      M.Z_Hi := Z_Hi;
   end Mesh_Cells;

   ------------------------------------------------------------------ a tile

   procedure Build_Tile
     (W : World; L : Level; TX, TY : Integer; Work : Stack_Work_Access; S : in out Scratch;
      M : out Castle.Mesher.Mesh; Edited : out Boolean; With_AO : Boolean := True; Times : access Tile_Times := null)
   is
      N    : constant Positive := Tile_Stacks (L);        --  stacks a side
      Cb   : constant Positive := Cell_B (L);             --  blocks to a cell
      Cn   : constant Positive := Chunk_B / N;            --  cells a stack gives, a side
      Z_Lo : Integer := Integer'Last;
      Z_Hi : Integer := Integer'First;
      West, East, South, North : Edge_Tops;
      T0   : Time := Clock;

      procedure Lap (D : in out Duration) is
         T : constant Time := Clock;
      begin
         D := D + To_Duration (T - T0);
         T0 := T;
      end Lap;

      function Edge_Top (Bx, By : Integer) return Integer is
        ((Castle.Geology.Surface_B
            (W, Integer'Max (0, Integer'Min (Size_B - 1, Bx)), Integer'Max (0, Integer'Min (Size_B - 1, By))) + Cb / 2)
         / Cb);
   begin
      Edited := False;
      for SY in 0 .. N - 1 loop
         for SX in 0 .. N - 1 loop
            declare
               CX   : constant Integer := TX * N + SX;
               CY   : constant Integer := TY * N + SY;
               B_Lo : Integer := Height_B;
               B_Hi : Integer := 0;
               Lo, Hi : Integer;           --  the stack's rows at the level in hand
            begin
               Generate (W, CX, CY, Work.all);
               if Castle.Edits.Generation (CX, CY) > 0 then
                  declare
                     Rim      : Castle.Edits.Rim_Access;
                     Gen      : Natural;
                     Old_Skin : constant Skin_Grid := Work.Skin;
                  begin
                     Castle.Edits.Apply (CX, CY, Work, Gen, Rim);
                     Deepen (W, CX, CY, Work.all, Old_Skin);
                     Castle.Edits.Free (Rim);
                     Edited := True;
                  end;
               end if;
               if Times /= null then
                  Lap (Times.Generate);
               end if;
               for I in Brick_Index loop
                  for J in Brick_Index loop
                     B_Lo := Integer'Min (B_Lo, Work.Skin (I, J) * Blocks_Per_Meter);
                  end loop;
               end loop;
               B_Lo := Integer'Max (0, B_Lo);
               for X in 0 .. Chunk_B - 1 loop
                  for Y in 0 .. Chunk_B - 1 loop
                     for Z in reverse B_Lo .. Work.Air_From - 1 loop
                        if Seen_Mat (Work.G (X, Y, Z)) /= Air then
                           B_Hi := Integer'Max (B_Hi, Z);
                           exit;
                        end if;
                     end loop;
                  end loop;
               end loop;
               B_Hi := Integer'Max (B_Hi, B_Lo);
               --  (whole cells of the level made)
               B_Lo := (B_Lo / Cb) * Cb;
               B_Hi := Integer'Min (Height_B - 1, (B_Hi / Cb) * Cb + Cb - 1);
               From_Blocks (Work.all, B_Lo, B_Hi, S.A);
               Lo := B_Lo / 2;
               Hi := B_Hi / 2;
               for Step in 2 .. L loop
                  if Step mod 2 = 0 then
                     Halve (S.A, Chunk_B / 2 ** (Step - 1), Lo, Hi, S.B);
                  else
                     Halve (S.B, Chunk_B / 2 ** (Step - 1), Lo, Hi, S.A);
                  end if;
                  Lo := Lo / 2;
                  Hi := Hi / 2;
               end loop;
               for I in 0 .. Cn - 1 loop
                  for J in 0 .. Cn - 1 loop
                     for Z in Lo .. Hi loop
                        S.C (SX * Cn + I, SY * Cn + J, Z) := (if L mod 2 = 1 then S.A (I, J, Z) else S.B (I, J, Z));
                     end loop;
                     S.Lo (SX * Cn + I, SY * Cn + J) := Lo;
                     S.Hi (SX * Cn + I, SY * Cn + J) := Hi;
                  end loop;
               end loop;
               Z_Lo := Integer'Min (Z_Lo, Lo);
               Z_Hi := Integer'Max (Z_Hi, Hi);
               if Times /= null then
                  Lap (Times.Reduce);
               end if;
            end;
         end loop;
      end loop;
      --  every column whole over the tile's rows: ground under its own, nothing over them
      for X in 0 .. Chunk_B - 1 loop
         for Y in 0 .. Chunk_B - 1 loop
            for Z in Z_Lo .. S.Lo (X, Y) - 1 loop
               S.C (X, Y, Z) := Deep;
            end loop;
            for Z in S.Hi (X, Y) + 1 .. Z_Hi loop
               S.C (X, Y, Z) := Air;
            end loop;
         end loop;
      end loop;
      declare
         X0 : constant Integer := TX * N * Chunk_B;
         Y0 : constant Integer := TY * N * Chunk_B;
      begin
         for K in 0 .. Chunk_B - 1 loop
            West (K)  := Edge_Top (X0 - Cb / 2, Y0 + K * Cb + Cb / 2);
            East (K)  := Edge_Top (X0 + Chunk_B * Cb + Cb / 2, Y0 + K * Cb + Cb / 2);
            South (K) := Edge_Top (X0 + K * Cb + Cb / 2, Y0 - Cb / 2);
            North (K) := Edge_Top (X0 + K * Cb + Cb / 2, Y0 + Chunk_B * Cb + Cb / 2);
         end loop;
      end;
      Mesh_Cells (S, Z_Lo, Z_Hi, West, East, South, North, M, With_AO);
      if Times /= null then
         Lap (Times.Mesh);
      end if;
   end Build_Tile;

end Castle.Lod;
