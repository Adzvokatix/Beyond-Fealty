with Interfaces;
with Castle.Blocks; use Castle.Blocks;
with Castle.Maps;   use Castle.Maps;
with Castle.Stacks; use Castle.Stacks;
with Castle.Dims;  use Castle.Dims;

--  Two-level chunk storage.  A chunk (8 m cube) is 8 x 8 x 8 bricks; a
--  brick is one value for a homogeneous 1 m cell, or a reference to 64
--  blocks where detail exists, kept small (below: 128 bytes whole, 14 to
--  66 as they are kept).  Only the skin is generated: the
--  top 2 m of ground and everything above it, cliff faces included.  Below
--  the skin a chunk holds Deep_Fill, resolved on demand by
--  Castle.Geology.Deep_Brick.  Packing keeps a skin brick fine only if its
--  64 blocks differ.
package Castle.Chunks is

   Bricks_Per_Chunk : constant := Chunk_B / Blocks_Per_Meter;   --  8
   subtype Brick_Index is Integer range 0 .. Bricks_Per_Chunk - 1;

   type Fine_Brick is array (0 .. 3, 0 .. 3, 0 .. 3) of Block;  --  128 bytes: a fine brick, whole

   --  A chunk's fine bricks are kept small, nothing lost (2026-11-14; John:
   --  "the inhabitants don't care what texture the objects are only the
   --  player does ... we need to be smart about this", and of the ground
   --  under the surface: "Let's see if we can cut the burried skin down to
   --  4kb a stack").  Counted over the whole map no fine brick holds more
   --  than sixteen different blocks, and seven in ten hold two (leaf and
   --  air, turf and earth, earth and rock).  So a fine brick is a record of
   --  16-bit words in its chunk's pool: how many different blocks it holds
   --  (K), those blocks, and then for each of its 64 places which of them
   --  it is, in one bit (K to 2), two (to 4) or four (to 16).  14 bytes for
   --  two blocks, 26 for four, 66 for sixteen; a brick of more is written
   --  whole (K = 0, 130 bytes).  A chunk's ref grid says where each fine
   --  brick's record begins.  Read through Block_In and Fine_At only.
   type Word_Pool is array (Positive range <>) of Interfaces.Unsigned_16;
   type Word_Pool_Access is access Word_Pool;

   Small_Bricks : Boolean := True;
   --  Off (colony_run --whole-bricks): every fine brick written whole, as
   --  it always was.  Storage only: a block read is the same block either
   --  way, the debug build unpacks every brick it packs and compares, and
   --  tools/stress.sh runs the crowd both ways.  Set before anything is
   --  packed.

   type Brick_Grid is array (Brick_Index, Brick_Index, Brick_Index) of Brick;  --  2 KB
   type Brick_Grid_Access is access Brick_Grid;

   type Ref_Grid is
     array (Brick_Index, Brick_Index, Brick_Index) of Interfaces.Unsigned_16;
   --  0: a coarse brick; else where the fine brick's record begins in Fine
   type Ref_Grid_Access is access Ref_Grid;

   type Chunk is record
      Uniform : Boolean := True;
      Fill    : Brick   := Air_Brick;
      Bricks  : Brick_Grid_Access;
      Refs    : Ref_Grid_Access;
      Fine    : Word_Pool_Access;
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
   function Fine_At (C : Chunk; I, J, K : Brick_Index) return Fine_Brick;
   --  The fine brick at (I, J, K) of a chunk, whole (it must be one: its ref not 0).

   --  What a packed stack takes, counted (measuring: colony_run --mem), and
   --  what its fine bricks hold: by the first of these found in a brick.
   type Brick_Kind is
     (Holds_Built,     --  something built (plank, thatch, daub, a footpath, ...)
      Holds_Tree,      --  trunk or crown
      Holds_Plant,     --  a bush, tall grass, grain, wild vegetables
      Holds_Water,
      Holds_Boulder,
      Holds_Surface,   --  air and ground: the open surface
      Holds_Buried);   --  no air in it: ground under the surface where materials meet
   type Kind_Counts is array (Brick_Kind) of Natural;
   type Stack_Sizes is record
      Bytes_Array : Natural := 0;       --  the stack's array of chunks
      Bytes_Grids : Natural := 0;       --  brick and ref grids of its chunks that are not uniform
      Bytes_Fine  : Natural := 0;       --  its fine bricks
      Chunks_Fine : Natural := 0;       --  chunks that are not uniform
      Allocations : Natural := 0;
      Fine        : Kind_Counts := (others => 0);
      Fine_Bytes  : Kind_Counts := (others => 0);    --  what the bricks of each kind take as they are kept
   end record;
   function Sizes_Of (S : Chunk_Stack) return Stack_Sizes;
   function Kind_Of (F : Fine_Brick) return Brick_Kind;
   procedure Free (S : in out Chunk_Stack);
   procedure Free (Work : in out Stack_Work_Access);

end Castle.Chunks;
