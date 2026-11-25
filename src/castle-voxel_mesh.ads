with Interfaces;

--  A small voxel volume and its mesh (docs/design/Voxel_people_brief.md,
--  sections 2 and 5): what a figure built of voxel parts is made with.  A
--  part is one grid, a byte a voxel (an index into its look's palette, 0
--  air), indexed from 0; where its corner lies in its bone's frame is its
--  own offset.  Mesh merges the exposed faces of a part into rectangles of
--  one palette index and one facing (greedy, as Castle.Mesher does for the
--  land's stacks; nothing of that package is used: it is tied to stacks,
--  water and the world's occlusion).  Faces between two parts are not
--  culled.  Nothing here knows what a serf is.
package Castle.Voxel_Mesh is

   Vx : constant := 0.025;       --  metres to a voxel: two to a body pixel (Castle.Bodies.Px)

   Side : constant := 64;        --  a part is no more than this many voxels a side (6 bits a coordinate)
   subtype Coord is Integer range 0 .. Side - 1;
   subtype U8 is Interfaces.Unsigned_8;
   subtype U32 is Interfaces.Unsigned_32;

   type Grid is array (Coord, Coord, Coord) of U8;      --  (x, y, z)
   type Grid_Access is access Grid;

   type Part is record
      G          : Grid_Access;
      Nx, Ny, Nz : Natural := 0;     --  how much of the grid is used
      Ox, Oy, Oz : Integer := 0;     --  the voxel of the bone's frame that grid (0, 0, 0) is
   end record;

   type Facing is (Pos_X, Neg_X, Pos_Y, Neg_Y, Pos_Z, Neg_Z);

   --  A rectangle of faces: its lowest voxel, how many voxels it spans
   --  along its two axes (U then V: for a face across X they are Y and Z,
   --  across Y: X and Z, across Z: X and Y), its facing and its colour.
   --  Two words, to be decoded in a vertex shader as the land's quads are:
   --    A: x | y << 6 | z << 12 | (w - 1) << 18 | (h - 1) << 24
   --    B: facing | palette index << 3 | bone << 11
   type Quad is record
      A, B : U32 := 0;
   end record with Convention => C;
   type Quad_Array is array (Positive range <>) of Quad with Convention => C;

   function Pack (X, Y, Z : Coord; W, H : Positive; F : Facing; Colour : U8; Bone : Natural) return Quad;
   procedure Unpack (Q : Quad; X, Y, Z : out Coord; W, H : out Positive; F : out Facing; Colour : out U8;
                     Bone : out Natural);

   --  The quads of part P, added to Quads after N (N is moved on).  Raises
   --  Constraint_Error if they do not fit.  By_Colour: a rectangle is of one
   --  palette index, which its quad carries (the brief's mesh); else of any,
   --  its colour 0, to be looked up voxel by voxel where it is drawn (what
   --  the game draws since 2026-11-23: a fifth of the triangles or less).
   procedure Mesh (P : Part; Bone : Natural; Quads : in out Quad_Array; N : in out Natural;
                   By_Colour : Boolean := True);

   --  How many quads P would be: merged by colour as Mesh merges them; merged
   --  whatever the colour (were a face's colour looked up, not carried by its
   --  quad); and not merged at all (a quad an open side).  For counting.
   procedure Quads_Of (P : Part; By_Colour, Any_Colour, Unmerged : out Natural);

   --  P at half the fineness: a voxel of the result is solid if four or more
   --  of its eight are, and has the commonest colour among them (the lowest
   --  index on a tie).  Into Into's grid.
   procedure Halve (P : Part; Into : in out Part);

   --  How many voxels of P are solid, and how many of those have a side open.
   procedure Count (P : Part; Solid, Surface : out Natural);

end Castle.Voxel_Mesh;
