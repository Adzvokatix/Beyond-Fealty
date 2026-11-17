--  World dimensions.  Everything else derives from these numbers.
package Castle.Dims with Pure is

   Blocks_Per_Meter : constant := 4;                             --  0.25 m blocks
   Size_M           : constant := 2_048;                         --  map edge
   Height_M         : constant := 256;                           --  256 one-metre layers
   Size_B           : constant := Size_M * Blocks_Per_Meter;     --  8192
   Height_B         : constant := Height_M * Blocks_Per_Meter;   --  1,024
   Chunk_B          : constant := 32;                            --  8 m chunk edge
   Chunks_XY        : constant := Size_B / Chunk_B;              --  256
   Chunks_Z         : constant := Height_B / Chunk_B;            --  8
   Layer_B          : constant := Blocks_Per_Meter;              --  blocks per 1 m layer

   Base_Elevation_M : constant := 16.0;
   Hill_Elevation_M : constant := 24.0;

   function Floor_Div (A, B : Integer) return Integer is
     (if A >= 0 then A / B else -((-A + B - 1) / B));
   --  Floor division for B > 0.

   function Center_M (B : Integer) return Float is
     ((Float (B) + 0.5) / Float (Blocks_Per_Meter));
   --  Centre of block B, in metres.

   function Layer_Of (Bz : Integer) return Integer is (Bz / Layer_B);
   --  The 1 m layer (0 .. Height_M - 1) that block row Bz belongs to.

end Castle.Dims;
