with Castle.Blocks; use Castle.Blocks;
with Castle.Dims;  use Castle.Dims;

--  A stack is one 8 m x 8 m chunk column at full world height
--  (32 x 32 x 256 blocks = 512 KB).  It is the unit of *generation*,
--  because surface, water and features are decided per column; the 32^3
--  chunk is the unit of storage, meshing and streaming.
package Castle.Stacks is

   type Stack_Grid is
     array (0 .. Chunk_B - 1, 0 .. Chunk_B - 1, 0 .. Height_B - 1) of Block;
   --  (X, Y, Z) with Z fastest: a chunk's 32-block vertical run is one
   --  64-byte cache line.

   type Stack_Grid_Access is access Stack_Grid;

end Castle.Stacks;
