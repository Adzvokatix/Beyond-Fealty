with Castle.Blocks; use Castle.Blocks;
with Castle.Hash;
with Castle.PNG;    use Castle.PNG;

--  A small isometric voxel renderer for previews (and later the asset
--  viewer).  2:1 projection, Scale px per block edge, depth-buffered, so blocks
--  can be drawn in any order.  Visible faces: top, +Y (left), +X (right).
package Castle.Iso is

   type Grid is array (Natural range <>, Natural range <>, Natural range <>) of Material;
   type Grid_Access is access Grid;

   function Render
     (Vox    : Grid;
      Z_Lo   : Natural;
      Z_Hi   : Natural;
      Seed   : Castle.Hash.U64;
      Flip_X : Boolean := False;
      Flip_Y : Boolean := False;
      Scale  : Positive := 4) return Image_Access;
   --  Flip both to view from the opposite corner (a 180 degree turn), so the
   --  -X and -Y faces are the ones in view.  Scale: pixels per block edge
   --  (even).

end Castle.Iso;
