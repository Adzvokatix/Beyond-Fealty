with Interfaces;
with Castle.Blocks; use Castle.Blocks;
with Castle.Maps;   use Castle.Maps;
with Castle.Stacks; use Castle.Stacks;
with Castle.Dims;  use Castle.Dims;

--  Two-level chunk storage.  A chunk (8 m cube) is 8 x 8 x 8 bricks; a
--  brick is one value for a homogeneous 1 m cell, or a reference to 64
--  blocks (128 bytes) where detail exists.  Only the skin is generated: the
--  top 2 m of ground and everything above it, cliff faces included.  Below
--  the skin a chunk holds Deep_Fill, resolved on demand by
--  Castle.Geology.Deep_Brick.  Packing keeps a skin brick fine only if its
--  64 blocks differ.
package Castle.Chunks is

   Bricks_Per_Chunk : constant := Chunk_B / Blocks_Per_Meter;   --  8
   subtype Brick_Index is Integer range 0 .. Bricks_Per_Chunk - 1;

   type Fine_Brick is array (0 .. 3, 0 .. 3, 0 .. 3) of Block;  --  128 bytes
   type Fine_Pool is array (Positive range <>) of Fine_Brick;
   type Fine_Pool_Access is access Fine_Pool;

   type Brick_Grid is array (Brick_Index, Brick_Index, Brick_Index) of Brick;  --  2 KB
   type Brick_Grid_Access is access Brick_Grid;

   type Ref_Grid is
     array (Brick_Index, Brick_Index, Brick_Index) of Interfaces.Unsigned_16;  --  0 = coarse
   type Ref_Grid_Access is access Ref_Grid;

   type Chunk is record
      Uniform : Boolean := True;
      Fill    : Brick   := Air_Brick;
      Bricks  : Brick_Grid_Access;
      Refs    : Ref_Grid_Access;
      Fine    : Fine_Pool_Access;
   end record;

   type Chunk_Stack is array (0 .. Chunks_Z - 1) of Chunk;

   type Column_Bricks is array (Brick_Index, Brick_Index, 0 .. Height_M - 1) of Brick;
   type Skin_Grid is array (Brick_Index, Brick_Index) of Integer;

   type Flow_Grid is array (0 .. Chunk_B - 1, 0 .. Chunk_B - 1) of Boolean;
   type Level_Grid is array (0 .. Chunk_B - 1, 0 .. Chunk_B - 1) of Float;

   type Stack_Work is record
      G      : Stack_Grid;      --  full resolution scratch (skin + features)
      Coarse : Column_Bricks;   --  bricks clipped by the ground
      Rock   : Column_Bricks;   --  rock ignoring the ground
      Skin   : Skin_Grid;       --  lowest fine brick (1 m index) per brick column
      Air_From : Integer := 0;  --  every block row from here up is Air in G
      Flowing  : Flow_Grid := (others => (others => False));   --  river or stream water in the column
      Rest     : Level_Grid := (others => (others => 0.0));    --  its level as generated, in rows (Geology.Water_Level)
   end record;
   type Stack_Work_Access is access Stack_Work;

   procedure Generate
     (W     : World;
      CX, CY : Integer;
      Work  : in out Stack_Work;
      Clear : access function (Bx, By : Integer) return Boolean := null);
   --  Below the skin Work.G and the brick grids hold Deep.

   procedure Pack (Work : Stack_Work; S : out Chunk_Stack);

   procedure Deepen (W : World; CX, CY : Integer; Work : in out Stack_Work; Old_Skin : Skin_Grid);
   --  Where edits lowered the skin below Old_Skin (Castle.Edits.Apply),
   --  generate the newly exposed band the way the skin is generated: real
   --  rock, soil, water table and veins block by block, in place of Deep.

   type Chunk_Stack_Access is access Chunk_Stack;

   function Block_In (S : Chunk_Stack; X, Y, Z : Integer) return Block;
   procedure Free (S : in out Chunk_Stack_Access);
   --  The block at stack-local (X, Y) and row Z of a packed stack.  Below
   --  the skin this is Deep (resolved by Castle.Geology on demand).

   function Bytes (C : Chunk) return Natural;
   function Fine_Count (C : Chunk) return Natural;
   procedure Free (S : in out Chunk_Stack);
   procedure Free (Work : in out Stack_Work_Access);

end Castle.Chunks;
