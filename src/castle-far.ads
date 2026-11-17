with Interfaces;
with Castle.Dims;
with Castle.Maps;     use Castle.Maps;
with Castle.Textures;

--  The far land (John, 2026-11-14: "what would it cost to cover the entire
--  world with one mesh and draw locally over it ... far mountains need a
--  texture, they don't need detail, but something has to be there").
--
--  The whole world as one coarse sheet, worked out once from the
--  generator's map with no stack made: a height for every corner of a grid
--  of Cell_M cells and, for every cell, what is seen on it from far off.
--  The renderer draws it under the whole world, and it is seen wherever no
--  stack's own mesh is drawn (Castle.Render, "The far land").  Nothing
--  here knows of the game: it shows the world as it was made, so nothing
--  dug, laid or built.
--
--  The sheet lies under the land as it was made, everywhere on dry ground:
--  each corner under the lowest ground of every cell that meets at it, so
--  that the flat triangles between corners are under every block column
--  they span.  A stack's own mesh therefore hides it, and it needs no hole
--  cut in it where a mesh is drawn; it is dropped there only where the
--  land is no longer as it was made (a stack that has been edited) and
--  where it stands at open water's level (a cell that is Wet: the water's
--  own surface is drawn over its bed, and the sheet would lie between).
--
--  A cell is one of the generator's tree cells (Castle.Flora.Tree_Cell: 4
--  m), so a cell with a tree in it is that tree's crown and a forest comes
--  out as its own trees, cell by cell.
package Castle.Far is

   Cell_M : constant := 4;
   Cells  : constant := Castle.Dims.Size_M / Cell_M;      --  512 each way

   --  What a cell is, for what the seasons do to it far off.
   type Class is (Bare,          --  rock, sand, earth: as it is
                  Turf,          --  grass: dries in late summer
                  Broadleaf,     --  a crown that turns and falls
                  Aspen,         --  one that turns gold, and falls
                  Conifer,       --  one that keeps its needles
                  Open_Water);
   Class_Step : constant := 40;  --  a class is kept as its position times this, in a texel's fourth byte,
   Wet_Step   : constant := 20;  --  and this more if the cell is Wet: open water in it or beside it (where its corners look)

   type Texel is record
      R, G, B : Interfaces.Unsigned_8 := 0;    --  the ground's colour (the material's own average; under water, its bed's)
      A       : Interfaces.Unsigned_8 := 0;    --  Class'Pos * Class_Step (+ Wet_Step)
   end record with Convention => C;
   type Texel_Grid is array (0 .. Cells - 1, 0 .. Cells - 1) of aliased Texel with Convention => C;   --  (y, x)
   type Height_Grid is array (0 .. Cells, 0 .. Cells) of aliased Interfaces.IEEE_Float_32 with Convention => C;   --  (y, x)
   type Texel_Grid_Access is access Texel_Grid;
   type Height_Grid_Access is access Height_Grid;

   Sink_M : constant := 0.5;
   --  A corner stands this far under the lowest of the map's heights (or
   --  open water's levels) that any block column of the four cells meeting
   --  at it is made from.  (A block column's top is the map's height there,
   --  between four of its metres, give or take 0.12 m of detail and the
   --  rounding to a block: a quarter metre at most.  So the sheet is at
   --  least a quarter metre under every dry block column.)

   function Corner_Z (W : World; I, J : Integer) return Float;
   --  The height (m) of corner (I, J) of the grid, I and J in 0 .. Cells.

   function Sheet_Z (W : World; Xm, Ym : Float) return Float;
   --  The sheet's height at a place, as it is drawn: each cell two flat
   --  triangles, split from its south-west corner to its north-east.

   function Wet (W : World; I, J : Integer) return Boolean;
   --  Open water somewhere among the map's metres that the corners of cell
   --  (I, J) look at.

   function Cell_Of (W : World; Overall : Castle.Textures.Texel_Data; I, J : Integer) return Texel;
   --  Cell (I, J): from the tree that stands in it, if one does, and the
   --  ground at its middle.  Overall is the block textures' third level
   --  (Castle.Textures.Texture_Set.Overall): each material's average colour.

   function Crown_Of (Overall : Castle.Textures.Texel_Data; C : Class) return Texel;
   --  The colour of a crown of that class (a broadleaf's lighter leaves),
   --  as the textures have it.

   procedure Build (W : World; Overall : Castle.Textures.Texel_Data; Z : out Height_Grid; C : out Texel_Grid);

end Castle.Far;
