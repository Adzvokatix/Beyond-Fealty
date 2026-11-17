with Castle.Blocks; use Castle.Blocks;
with Castle.Chunks; use Castle.Chunks;
with Castle.Dims;   use Castle.Dims;
with Castle.Maps;   use Castle.Maps;
with Castle.Mesher;

--  The far view (John, 2026-11-15: "if we are going to rework rendering
--  let's go all the way, let's figure out how to get everything in view";
--  of his list: voxel distance LODs, progressive ring LODs for terrain
--  stacks, a quadtree).
--
--  The world at coarser blocks.  A level is a doubling: at level L a cell
--  is 2 ** L blocks a side (half a metre at level 1, 4 m at level 4), and a
--  tile is Chunk_B x Chunk_B cells, so 2 ** L stacks a side (16 m at level
--  1, 128 m at level 4).  A tile is made from the very stacks the game
--  makes: each is generated, the edits laid on it, and reduced by halves
--  (Parent, below); so what is seen far off is the world itself, its trees
--  and whatever has been dug or built, and never a second description of
--  it.  The tile is then meshed into the mesher's own quads (the renderer
--  draws them with the land's shader at 2 ** L times the size), greedy,
--  with the corner occlusion a stack's faces have.
--
--  Reduction, eight cells to one (Parent): water on top if the upper four
--  hold two of water and the eight are half full; else something if half
--  of the eight are something (ground, wood, leaves: what is on top by
--  count among the upper four, else among the lower); else water if half
--  are water or something; else, if two are of a thing that is thin by
--  nature (a trunk, a wall, a roof), that thing, so that a tree keeps its
--  trunk and a hovel its walls a level or two further; else nothing.
--  Grass, grain and wild vegetables are nothing (a tuft is under a pixel
--  where a tile is drawn).
--
--  A tile does not know the tiles beside it.  Past its edge the ground
--  stands as the generator has it (the tops it is handed), and besides,
--  the top Skirt_Cells of every column on the edge show their outward
--  face whatever stands there: where a tile of one level meets one of
--  another the two do not agree to the block, and the skirt closes the
--  crack.
package Castle.Lod is

   Max_Level : constant := 4;
   subtype Level is Positive range 1 .. Max_Level;

   function Cell_B (L : Level) return Positive is (2 ** L);        --  blocks to a cell's side
   function Tile_Stacks (L : Level) return Positive is (2 ** L);   --  stacks to a tile's side
   function Tiles (L : Level) return Positive is (Chunks_XY / 2 ** L);   --  tiles to the map's side

   Skirt_Cells : constant := 3;

   Rows_Most : constant := Height_B / 2;      --  cells high, at level 1

   type Cell_Grid is array (0 .. Chunk_B - 1, 0 .. Chunk_B - 1, 0 .. Rows_Most - 1) of Material;
   type Column_Rows is array (0 .. Chunk_B - 1, 0 .. Chunk_B - 1) of Integer;
   type Edge_Tops is array (0 .. Chunk_B - 1) of Integer;
   --  Along one side of a tile, just outside it: how many cells of ground
   --  stand in each column there.

   type Mip is array (0 .. Chunk_B / 2 - 1, 0 .. Chunk_B / 2 - 1, 0 .. Rows_Most - 1) of Material;

   --  What a worker keeps to make tiles with (1 MB; one to a worker).
   type Scratch is limited record
      C      : Cell_Grid;           --  the tile's cells
      Lo, Hi : Column_Rows;         --  each column's own rows, as its stack gave them
      A, B   : Mip;                 --  a stack being reduced
   end record;
   type Scratch_Access is access Scratch;

   type Kids is array (0 .. 7) of Material;     --  x + 2 y + 4 z
   function Parent (K : Kids) return Material;

   type Tile_Times is record
      Generate, Reduce, Mesh : Duration := 0.0;
   end record;

   procedure Build_Tile
     (W : World; L : Level; TX, TY : Integer; Work : Stack_Work_Access; S : in out Scratch;
      M : out Castle.Mesher.Mesh; Edited : out Boolean; With_AO : Boolean := True; Times : access Tile_Times := null);
   --  Tile (TX, TY) of level L, TX and TY in 0 .. Tiles (L) - 1.  The mesh's
   --  quads and its Z_Lo and Z_Hi are in cells.  Edited: one of its stacks
   --  has been.

   procedure Mesh_Cells
     (S : Scratch; Z_Lo, Z_Hi : Integer; West, East, South, North : Edge_Tops;
      M : out Castle.Mesher.Mesh; With_AO : Boolean := True);
   --  The cells of S.C in rows Z_Lo .. Z_Hi, meshed: under Z_Lo all is
   --  ground, over Z_Hi nothing.

end Castle.Lod;
