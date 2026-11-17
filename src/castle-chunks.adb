with Ada.Unchecked_Conversion;
with Ada.Unchecked_Deallocation;
with Castle.Geology; use Castle.Geology;
with Castle.Flora;

package body Castle.Chunks is

   procedure Free_Bricks is new Ada.Unchecked_Deallocation (Brick_Grid, Brick_Grid_Access);
   procedure Free_Refs   is new Ada.Unchecked_Deallocation (Ref_Grid, Ref_Grid_Access);
   procedure Free_Fine   is new Ada.Unchecked_Deallocation (Word_Pool, Word_Pool_Access);

   use type Interfaces.Unsigned_16;

   --  A fine brick's record in its chunk's pool (the spec): a word of how
   --  many different blocks it holds (0: written whole), those blocks, then
   --  which of them each of its 64 places is, place X + 4 Y + 16 Z, packed
   --  from each word's low end.
   function To_Word is new Ada.Unchecked_Conversion (Block, Interfaces.Unsigned_16);
   function To_Block is new Ada.Unchecked_Conversion (Interfaces.Unsigned_16, Block);

   Most_Words : constant := 65;      --  a brick written whole
   function Bits_For (K : Positive) return Positive is (if K <= 2 then 1 elsif K <= 4 then 2 else 4);
   function Words_For (K : Natural) return Positive is (if K = 0 then Most_Words else 1 + K + 4 * Bits_For (K));

   --  Write F at Pool (At_W ..); Used: the words it took.
   procedure Write_Fine (F : Fine_Brick; Pool : in out Word_Pool; At_W : Positive; Used : out Positive) is
      Seen : array (1 .. 16) of Block;
      K    : Natural := 0;
      Which : array (0 .. 63) of Natural := (others => 0);
      Whole : Boolean := not Small_Bricks;
   begin
      if not Whole then
         Places :
         for Z in 0 .. 3 loop
            for Y in 0 .. 3 loop
               for X in 0 .. 3 loop
                  declare
                     B : constant Block := F (X, Y, Z);
                     N : Natural := 0;
                  begin
                     for I in 1 .. K loop
                        if Seen (I) = B then
                           N := I;
                           exit;
                        end if;
                     end loop;
                     if N = 0 then
                        if K = 16 then
                           Whole := True;
                           exit Places;
                        end if;
                        K := K + 1;
                        Seen (K) := B;
                        N := K;
                     end if;
                     Which (X + 4 * Y + 16 * Z) := N - 1;
                  end;
               end loop;
            end loop;
         end loop Places;
      end if;
      if Whole then
         Pool (At_W) := 0;
         for Z in 0 .. 3 loop
            for Y in 0 .. 3 loop
               for X in 0 .. 3 loop
                  Pool (At_W + 1 + X + 4 * Y + 16 * Z) := To_Word (F (X, Y, Z));
               end loop;
            end loop;
         end loop;
         Used := Most_Words;
         return;
      end if;
      declare
         Bits : constant Positive := Bits_For (K);
         Per  : constant Positive := 16 / Bits;          --  places to a word
         Base : constant Positive := At_W + 1 + K;
      begin
         Pool (At_W) := Interfaces.Unsigned_16 (K);
         for I in 1 .. K loop
            Pool (At_W + I) := To_Word (Seen (I));
         end loop;
         for W in 0 .. 4 * Bits - 1 loop
            Pool (Base + W) := 0;
         end loop;
         for P in Which'Range loop
            Pool (Base + P / Per) :=
              Pool (Base + P / Per) or Interfaces.Shift_Left (Interfaces.Unsigned_16 (Which (P)), Bits * (P mod Per));
         end loop;
         Used := Words_For (K);
      end;
   end Write_Fine;

   --  The block at place P (X + 4 Y + 16 Z) of the fine brick whose record begins at Pool (W).
   function Read_Fine (Pool : Word_Pool; W : Positive; P : Natural) return Block is
      K : constant Natural := Natural (Pool (W));
   begin
      if K = 0 then
         return To_Block (Pool (W + 1 + P));
      elsif K <= 2 then
         return To_Block (Pool (W + 1 + Natural (Interfaces.Shift_Right (Pool (W + 1 + K + P / 16), P mod 16) and 1)));
      elsif K <= 4 then
         return To_Block
           (Pool (W + 1 + Natural (Interfaces.Shift_Right (Pool (W + 1 + K + P / 8), 2 * (P mod 8)) and 3)));
      else
         return To_Block
           (Pool (W + 1 + Natural (Interfaces.Shift_Right (Pool (W + 1 + K + P / 4), 4 * (P mod 4)) and 15)));
      end if;
   end Read_Fine;

   function Fine_At (C : Chunk; I, J, K : Brick_Index) return Fine_Brick is
      W : constant Positive := Positive (C.Refs (I, J, K));
      F : Fine_Brick;
   begin
      for Z in 0 .. 3 loop
         for Y in 0 .. 3 loop
            for X in 0 .. 3 loop
               F (X, Y, Z) := Read_Fine (C.Fine.all, W, X + 4 * Y + 16 * Z);
            end loop;
         end loop;
      end loop;
      return F;
   end Fine_At;
   procedure Free_Work   is new Ada.Unchecked_Deallocation (Stack_Work, Stack_Work_Access);

   --------------
   -- Generate --
   --------------

   procedure Generate
     (W     : World;
      CX, CY : Integer;
      Work  : in out Stack_Work;
      Clear : access function (Bx, By : Integer) return Boolean := null)
   is
      X0     : constant Integer := CX * Chunk_B;
      Y0     : constant Integer := CY * Chunk_B;
      Mx0    : constant Integer := X0 / Blocks_Per_Meter;
      My0    : constant Integer := Y0 / Blocks_Per_Meter;
      Border : constant := Blocks_Per_Meter;   --  one brick of neighbours

      type Surf_Grid is
        array (-Border .. Chunk_B - 1 + Border, -Border .. Chunk_B - 1 + Border) of Integer;
      Surf : Surf_Grid;

      function Clamp_B (B : Integer) return Integer is
        (Integer'Max (0, Integer'Min (Size_B - 1, B)));
   begin
      --  1. Ground surface of every block column, with a 1 m border.
      for LX in Surf'Range (1) loop
         for LY in Surf'Range (2) loop
            Surf (LX, LY) := Surface_B (W, Clamp_B (X0 + LX), Clamp_B (Y0 + LY));
         end loop;
      end loop;

      --  2. Per brick column: where the skin starts (Skin_Depth_M below the
      --     lowest ground in its 3 x 3 brick neighbourhood, so cliff faces
      --     stay in the skin).  Below it nothing is generated.
      for I in Brick_Index loop
         for J in Brick_Index loop
            declare
               Lo : Integer := Integer'Last;
               Hi : Integer := 0;
               BC : constant Brick_Column := Prepare_Brick_Column (W, Mx0 + I, My0 + J);
            begin
               for LX in 4 * I - Border .. 4 * I + 3 + Border loop
                  for LY in 4 * J - Border .. 4 * J + 3 + Border loop
                     Lo := Integer'Min (Lo, Surf (LX, LY));
                  end loop;
               end loop;
               for LX in 4 * I .. 4 * I + 3 loop
                  for LY in 4 * J .. 4 * J + 3 loop
                     Hi := Integer'Max (Hi, Surf (LX, LY));
                  end loop;
               end loop;
               Work.Skin (I, J) :=
                 Integer'Max (1, (Lo - Skin_Depth_M * Blocks_Per_Meter) / Blocks_Per_Meter);
               for Mz in 0 .. Height_M - 1 loop
                  if Mz < Work.Skin (I, J) then
                     Work.Rock (I, J, Mz)   := Deep_Fill;   --  not generated, not stored
                     Work.Coarse (I, J, Mz) := Deep_Fill;
                  else
                     if Mz <= Hi / Blocks_Per_Meter + 1 then
                        Work.Rock (I, J, Mz) := Rock_At (W, BC, Mz);
                     else
                        Work.Rock (I, J, Mz) := Air_Brick;
                     end if;
                     Work.Coarse (I, J, Mz) := Brick_At (BC, Mz, Work.Rock (I, J, Mz));
                  end if;
               end loop;
            end;
         end loop;
      end loop;

      --  3. The fine skin, block by block.  Rows at or above the old
      --     Air_From are still air from the last stack this scratch held,
      --     so a tall world costs nothing above the ground.
      declare
         Old_Air  : constant Integer := Work.Air_From;
         Ground   : Integer := 0;
         Features : Integer := -1;
      begin
         for LX in 0 .. Chunk_B - 1 loop
            for LY in 0 .. Chunk_B - 1 loop
               declare
                  I   : constant Brick_Index := LX / Blocks_Per_Meter;
                  J   : constant Brick_Index := LY / Blocks_Per_Meter;
                  Bx  : constant Integer := X0 + LX;
                  By  : constant Integer := Y0 + LY;
                  Z_S : constant Integer := Work.Skin (I, J) * Blocks_Per_Meter;
                  C   : constant Column  := Prepare_Column (W, Bx, By);
                  Top : constant Integer := Integer'Max (C.Solid + C.Plant_H, C.Water_Top);
               begin
                  --  source water: rivers, streams and lakes (a fixed-level
                  --  edge to the simulation, giving at most its supply)
                  Work.Flowing (LX, LY) := C.Kind in Castle.Maps.River | Castle.Maps.Stream | Castle.Maps.Lake;
                  --  the level it holds, as generated, whatever is dug or
                  --  built there later (0: no water in this column)
                  Work.Rest (LX, LY) :=
                    (if Work.Flowing (LX, LY) and then C.Water_Top > C.Solid
                     then Water_Level (W, Bx, By, C.Solid, C.Water_Top - C.Solid) else 0.0);
                  for Z in 0 .. Z_S - 1 loop
                     Work.G (LX, LY, Z) := (Mat => Deep, State => 0);
                  end loop;
                  for Z in Z_S .. Top - 1 loop
                     Work.G (LX, LY, Z) :=
                       (Mat   => Skin_Material (W, C, Work.Rock (I, J, Z / Blocks_Per_Meter), Bx, By, Z),
                        State => 0);
                  end loop;
                  for Z in Top .. Old_Air - 1 loop
                     Work.G (LX, LY, Z) := Air_Block;
                  end loop;
                  Ground := Integer'Max (Ground, Top);
               end;
            end loop;
         end loop;

         --  4. Trees, bushes, boulders.
         Castle.Flora.Decorate (W, X0, Y0, Work.G, Features, Clear);
         Work.Air_From := Integer'Max (Ground, Features + 1);
      end;
   end Generate;

   ------------
   -- Deepen --
   ------------

   procedure Deepen (W : World; CX, CY : Integer; Work : in out Stack_Work; Old_Skin : Skin_Grid) is
      X0 : constant Integer := CX * Chunk_B;
      Y0 : constant Integer := CY * Chunk_B;
   begin
      for I in Brick_Index loop
         for J in Brick_Index loop
            if Work.Skin (I, J) < Old_Skin (I, J) then
               declare
                  BC : constant Brick_Column :=
                    Prepare_Brick_Column (W, X0 / Blocks_Per_Meter + I, Y0 / Blocks_Per_Meter + J);
               begin
                  for Mz in Work.Skin (I, J) .. Old_Skin (I, J) - 1 loop
                     Work.Rock (I, J, Mz) := Rock_At (W, BC, Mz);
                     Work.Coarse (I, J, Mz) := Brick_At (BC, Mz, Work.Rock (I, J, Mz));
                  end loop;
               end;
               for LX in 4 * I .. 4 * I + 3 loop
                  for LY in 4 * J .. 4 * J + 3 loop
                     declare
                        C : constant Column := Prepare_Column (W, X0 + LX, Y0 + LY);
                     begin
                        for Z in Work.Skin (I, J) * Blocks_Per_Meter .. Old_Skin (I, J) * Blocks_Per_Meter - 1 loop
                           if Work.G (LX, LY, Z).Mat = Deep then
                              Work.G (LX, LY, Z) :=
                                (Mat   => Skin_Material (W, C, Work.Rock (I, J, Z / Blocks_Per_Meter),
                                                         X0 + LX, Y0 + LY, Z),
                                 State => 0);
                           end if;
                        end loop;
                     end;
                  end loop;
               end loop;
            end if;
         end loop;
      end loop;
   end Deepen;

   ----------
   -- Pack --
   ----------

   --  Every fine brick of a chunk just packed reads back, place by place,
   --  the blocks it was made of.
   procedure Check_Packed (C : Chunk; Work : Stack_Work; CZ : Integer) is
   begin
      if C.Refs = null then
         return;
      end if;
      for I in Brick_Index loop
         for J in Brick_Index loop
            for K in Brick_Index loop
               if C.Refs (I, J, K) /= 0 then
                  declare
                     F : constant Fine_Brick := Fine_At (C, I, J, K);
                  begin
                     for X in 0 .. 3 loop
                        for Y in 0 .. 3 loop
                           for Z in 0 .. 3 loop
                              if F (X, Y, Z) /= Work.G (4 * I + X, 4 * J + Y, 4 * (CZ * Bricks_Per_Chunk + K) + Z) then
                                 raise Program_Error with "Castle.Chunks: a fine brick kept small reads back other blocks"
                                   & " than it was made of (chunk" & CZ'Image & ", brick" & I'Image & J'Image & K'Image & ")";
                              end if;
                           end loop;
                        end loop;
                     end loop;
                  end;
               end if;
            end loop;
         end loop;
      end loop;
   end Check_Packed;

   procedure Pack (Work : Stack_Work; S : out Chunk_Stack) is
   begin
      for CZ in Chunk_Stack'Range loop
        if CZ * Chunk_B >= Work.Air_From then
         S (CZ) := (Uniform => True, Fill => Air_Brick, Bricks => null, Refs => null, Fine => null);
        else
         declare
            Bricks : Brick_Grid;
            Refs   : Ref_Grid := (others => (others => (others => 0)));
            Pool   : Word_Pool (1 .. Most_Words * Bricks_Per_Chunk ** 3);
            Count  : Natural := 0;            --  fine bricks
            Words  : Natural := 0;            --  words of Pool written
         begin
            for I in Brick_Index loop
               for J in Brick_Index loop
                  for K in Brick_Index loop
                     declare
                        Mz : constant Integer := CZ * Bricks_Per_Chunk + K;
                     begin
                        if Mz < Work.Skin (I, J) then
                           Bricks (I, J, K) := Work.Coarse (I, J, Mz);
                        else
                           declare
                              First : constant Block := Work.G (4 * I, 4 * J, 4 * Mz);
                              Same  : Boolean := True;
                              Votes : array (Material) of Natural := (others => 0);
                              Major : Material := First.Mat;
                           begin
                              for X in 0 .. 3 loop
                                 for Y in 0 .. 3 loop
                                    for Z in 0 .. 3 loop
                                       declare
                                          B : constant Block := Work.G (4 * I + X, 4 * J + Y, 4 * Mz + Z);
                                       begin
                                          Same := Same and then B = First;
                                          Votes (B.Mat) := Votes (B.Mat) + 1;
                                       end;
                                    end loop;
                                 end loop;
                              end loop;
                              if Same then
                                 Bricks (I, J, K) := Plain (First.Mat);
                              else
                                 for M in Material loop
                                    if Votes (M) > Votes (Major) then
                                       Major := M;
                                    end if;
                                 end loop;
                                 Count := Count + 1;
                                 declare
                                    F    : Fine_Brick;
                                    Used : Positive;
                                 begin
                                    for X in 0 .. 3 loop
                                       for Y in 0 .. 3 loop
                                          for Z in 0 .. 3 loop
                                             F (X, Y, Z) := Work.G (4 * I + X, 4 * J + Y, 4 * Mz + Z);
                                          end loop;
                                       end loop;
                                    end loop;
                                    Write_Fine (F, Pool, Words + 1, Used);
                                    Refs (I, J, K) := Interfaces.Unsigned_16 (Words + 1);
                                    Words := Words + Used;
                                 end;
                                 Bricks (I, J, K) := Plain (Major);   --  representative, for LOD
                              end if;
                           end;
                        end if;
                     end;
                  end loop;
               end loop;
            end loop;

            declare
               Uniform : Boolean := Count = 0;
            begin
               if Uniform then
                  Check :
                  for I in Brick_Index loop
                     for J in Brick_Index loop
                        for K in Brick_Index loop
                           if Bricks (I, J, K) /= Bricks (0, 0, 0) then
                              Uniform := False;
                              exit Check;
                           end if;
                        end loop;
                     end loop;
                  end loop Check;
               end if;
               if Uniform then
                  S (CZ) := (Uniform => True, Fill => Bricks (0, 0, 0),
                             Bricks => null, Refs => null, Fine => null);
               else
                  S (CZ) := (Uniform => False, Fill => Air_Brick,
                             Bricks  => new Brick_Grid'(Bricks),
                             Refs    => (if Count = 0 then null else new Ref_Grid'(Refs)),
                             Fine    => (if Count = 0 then null
                                         else new Word_Pool'(Pool (1 .. Words))));
                  --  (assertions on: every fine brick kept reads back the blocks it was made of)
                  pragma Debug (Check_Packed (S (CZ), Work, CZ));
               end if;
            end;
         end;
        end if;
      end loop;
   end Pack;

   function Bytes (C : Chunk) return Natural is
   begin
      if C.Uniform then
         return Brick'Size / 8;
      end if;
      return Brick_Grid'Size / 8
        + (if C.Refs = null then 0 else Ref_Grid'Size / 8)
        + (if C.Fine = null then 0 else C.Fine'Length * 2);
   end Bytes;

   function Fine_Count (C : Chunk) return Natural is
      N : Natural := 0;
   begin
      if C.Refs /= null then
         for R of C.Refs.all loop
            if R /= 0 then
               N := N + 1;
            end if;
         end loop;
      end if;
      return N;
   end Fine_Count;

   function Kind_Of (F : Fine_Brick) return Brick_Kind is
      Has_Air, Has_Built, Has_Tree, Has_Plant, Has_Wet, Has_Boulder : Boolean := False;
   begin
      for X in 0 .. 3 loop
         for Y in 0 .. 3 loop
            for Z in 0 .. 3 loop
               case F (X, Y, Z).Mat is
                  when Air => Has_Air := True;
                  when Plank | Shingle | Footpath | Thatch | Daub | Fieldstone => Has_Built := True;
                  when Trunk | Crown => Has_Tree := True;
                  when Berry_Bush | Bare_Bush | Tall_Grass | Wild_Grain | Wild_Vegetables => Has_Plant := True;
                  when Water => Has_Wet := True;
                  when Boulder => Has_Boulder := True;
                  when others => null;
               end case;
            end loop;
         end loop;
      end loop;
      return (if Has_Built then Holds_Built elsif Has_Tree then Holds_Tree elsif Has_Plant then Holds_Plant
              elsif Has_Wet then Holds_Water elsif Has_Boulder then Holds_Boulder
              elsif Has_Air then Holds_Surface else Holds_Buried);
   end Kind_Of;

   function Sizes_Of (S : Chunk_Stack) return Stack_Sizes is
      R : Stack_Sizes;
   begin
      R.Bytes_Array := Chunk_Stack'Object_Size / 8;
      R.Allocations := 1;
      for C of S loop
         if not C.Uniform then
            R.Chunks_Fine := R.Chunks_Fine + 1;
            R.Bytes_Grids := R.Bytes_Grids + Brick_Grid'Object_Size / 8;
            R.Allocations := R.Allocations + 1;
            if C.Refs /= null then
               R.Bytes_Grids := R.Bytes_Grids + Ref_Grid'Object_Size / 8;
               R.Allocations := R.Allocations + 1;
            end if;
            if C.Fine /= null then
               R.Bytes_Fine := R.Bytes_Fine + C.Fine'Length * 2 + 8;   --  (and its bounds)
               R.Allocations := R.Allocations + 1;
               for I in Brick_Index loop
                  for J in Brick_Index loop
                     for K in Brick_Index loop
                        if C.Refs (I, J, K) /= 0 then
                           declare
                              Kd : constant Brick_Kind := Kind_Of (Fine_At (C, I, J, K));
                           begin
                              R.Fine (Kd) := R.Fine (Kd) + 1;
                              R.Fine_Bytes (Kd) := R.Fine_Bytes (Kd)
                                + 2 * Words_For (Natural (C.Fine (Positive (C.Refs (I, J, K)))));
                           end;
                        end if;
                     end loop;
                  end loop;
               end loop;
            end if;
         end if;
      end loop;
      return R;
   end Sizes_Of;

   function Block_In (S : Chunk_Stack; X, Y, Z : Integer) return Block is
      C : Chunk renames S (Z / Chunk_B);
   begin
      if C.Uniform then
         return (Mat => C.Fill.Mat, State => 0);
      end if;
      declare
         I : constant Brick_Index := X / Blocks_Per_Meter;
         J : constant Brick_Index := Y / Blocks_Per_Meter;
         K : constant Brick_Index := (Z mod Chunk_B) / Blocks_Per_Meter;
      begin
         --  A chunk of differing plain bricks has no fine ones, nor refs.
         if C.Refs = null or else Interfaces."=" (C.Refs (I, J, K), 0) then
            return (Mat => C.Bricks (I, J, K).Mat, State => 0);
         end if;
         return Read_Fine (C.Fine.all, Positive (C.Refs (I, J, K)), X mod 4 + 4 * (Y mod 4) + 16 * (Z mod 4));
      end;
   end Block_In;

   procedure Free_Stack is new Ada.Unchecked_Deallocation (Chunk_Stack, Chunk_Stack_Access);

   procedure Free (S : in out Chunk_Stack_Access) is
   begin
      if S /= null then
         Free (S.all);
         Free_Stack (S);
      end if;
   end Free;

   procedure Free (S : in out Chunk_Stack) is
   begin
      for C of S loop
         if C.Bricks /= null then
            Free_Bricks (C.Bricks);
         end if;
         if C.Refs /= null then
            Free_Refs (C.Refs);
         end if;
         if C.Fine /= null then
            Free_Fine (C.Fine);
         end if;
      end loop;
   end Free;

   procedure Free (Work : in out Stack_Work_Access) is
   begin
      Free_Work (Work);
   end Free;

end Castle.Chunks;
