with Ada.Unchecked_Deallocation;
with Castle.Geology; use Castle.Geology;
with Castle.Flora;

package body Castle.Chunks is

   procedure Free_Bricks is new Ada.Unchecked_Deallocation (Brick_Grid, Brick_Grid_Access);
   procedure Free_Refs   is new Ada.Unchecked_Deallocation (Ref_Grid, Ref_Grid_Access);
   procedure Free_Fine   is new Ada.Unchecked_Deallocation (Fine_Pool, Fine_Pool_Access);
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

   procedure Pack (Work : Stack_Work; S : out Chunk_Stack) is
   begin
      for CZ in Chunk_Stack'Range loop
        if CZ * Chunk_B >= Work.Air_From then
         S (CZ) := (Uniform => True, Fill => Air_Brick, Bricks => null, Refs => null, Fine => null);
        else
         declare
            Bricks : Brick_Grid;
            Refs   : Ref_Grid := (others => (others => (others => 0)));
            Pool   : Fine_Pool (1 .. Bricks_Per_Chunk ** 3);
            Count  : Natural := 0;
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
                                 for X in 0 .. 3 loop
                                    for Y in 0 .. 3 loop
                                       for Z in 0 .. 3 loop
                                          Pool (Count) (X, Y, Z) :=
                                            Work.G (4 * I + X, 4 * J + Y, 4 * Mz + Z);
                                       end loop;
                                    end loop;
                                 end loop;
                                 Bricks (I, J, K) := Plain (Major);   --  representative, for LOD
                                 Refs (I, J, K)   := Interfaces.Unsigned_16 (Count);
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
                                         else new Fine_Pool'(Pool (1 .. Count))));
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
        + (if C.Fine = null then 0 else C.Fine'Length * (Fine_Brick'Size / 8));
   end Bytes;

   function Fine_Count (C : Chunk) return Natural is
     (if C.Fine = null then 0 else C.Fine'Length);

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
         return C.Fine (Positive (C.Refs (I, J, K))) (X mod 4, Y mod 4, Z mod 4);
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
