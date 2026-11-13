with Interfaces;    use Interfaces;
with Castle.Maps;   use Castle.Maps;
with Castle.Chunks; use Castle.Chunks;
with Castle.Blocks;
with Castle.Edits;
with Castle.Water;
use type Castle.Edits.Rim_Access;
use type Castle.Water.View_Access;

--  Greedy mesher: turns one generated stack (8 x 8 m, full height) into
--  packed quads.  Faces between equal neighbouring faces merge into one
--  rectangle, so flat ground and walls cost a handful of quads.
--
--  Quad layout (two words, decoded in the vertex shader):
--    W0: x 0..4, y 5..9, z 10..19 (block in the stack), w-1 20..24, face 25..27,
--        28 a cell of open water (the renderer's own), 29 soft (below),
--        30 a tuft (below)
--    W1: h-1 0..7, material 8..15, corner occlusion 16..23, fringe 24..31
--  Corner occlusion is two bits per corner of each block face (3 open .. 0
--  boxed in), in the order (u-, v-), (u+, v-), (u+, v+), (u-, v+); faces
--  only merge with faces that share it, so it repeats block by block.
--  Faces: 0 +X, 1 -X, 2 +Y, 3 -Y, 4 +Z, 5 -Z.  w runs along the face's u
--  axis (y for X faces, x otherwise), h along v (z for side faces, y for
--  top and bottom).
--
--  Fringe (John, 2026-11-11: "it would be nice if the edges around the
--  paths and compacted areas had some charecter too it"): on a top face of
--  turf or of bare earth, which of the eight blocks round it are the other
--  kind (bits 0 .. 3 the sides -x, +x, -y, +y; 4 .. 7 the corners -x -y,
--  +x -y, +x +y, -x +y), each within a block of its height.  The renderer
--  draws grass creeping onto the earth along those sides and the turf worn
--  along them.  It is part of what faces must share to merge.
--
--  Soft quads (John, the same day: foliage "needs a bit more organic feel to
--  it"): a face of foliage (Soft, below) that lies along an edge or at a
--  corner of its clump is a quad of its own, one block, never merged, so
--  that the corners of the block grid there can be moved.  Its w and h are
--  1 and their fields, with the occlusion's and the fringe's, carry six bits
--  for each of its four corners (in the occlusion's order: W1 16..31, then
--  W1 0..7): two bits an axis, x then y then z, 0 not, 1 drawn up the axis,
--  2 down it, toward where the foliage lies about that corner (Pull, in the
--  body); all zero for a corner that stays where it is.  A corner is moved
--  if it is drawn in on two axes or three: the renderer cuts it back, so a
--  clump of leaves has its edges and corners rounded off.  Every face that
--  meets a corner carries the same bits for it, so the faces stay joined;
--  a face none of whose corners is moved (a flat side of a clump) is meshed
--  and merged like any other.
--
--  Tufts (John, 2026-11-11: "grass can get a slight overhaul"): a plant
--  that stands on the ground by itself (Tuft, below: tall grass, wild
--  grain, wild vegetables) is meshed a column at a time, not merged with
--  the tufts beside it: each of its four sides one quad as high as the
--  plant (w 1, h its blocks), and its top one quad, all marked with bit
--  30.  A side shows wherever no solid block stands against it, another
--  tuft included, so every tuft is whole by itself and the renderer can
--  lean it, draw its top in and make it taller or shorter than its block,
--  by where it stands (Castle.Render, "Grass").  Its faces carry no
--  occlusion.  Tufts cast no shadow, so they come last among a stack's
--  solid quads (Mesh.Cast counts the rest) and a light's depth map is
--  drawn without them.
package Castle.Mesher is

   Soft_Bit : constant Unsigned_32 := 2 ** 29;
   Tuft_Bit : constant Unsigned_32 := 2 ** 30;

   subtype Tuft is Castle.Blocks.Material
     with Static_Predicate =>
       Tuft in Castle.Blocks.Tall_Grass | Castle.Blocks.Wild_Grain | Castle.Blocks.Wild_Vegetables;
   --  What is meshed as tufts.

   subtype Soft is Castle.Blocks.Material
     with Static_Predicate => Soft in Castle.Blocks.Crown | Castle.Blocks.Berry_Bush | Castle.Blocks.Bare_Bush;
   --  What is meshed as soft quads.

   subtype Turf is Castle.Blocks.Material with Static_Predicate => Turf in Castle.Blocks.Grass;
   subtype Bare is Castle.Blocks.Material
     with Static_Predicate => Bare in Castle.Blocks.Dirt | Castle.Blocks.Footpath;
   --  The two kinds of ground a fringe lies between.

   type Quad is record
      W0, W1 : Unsigned_32;
   end record;
   for Quad use record
      W0 at 0 range 0 .. 31;
      W1 at 4 range 0 .. 31;
   end record;

   type Quad_Array is array (Positive range <>) of aliased Quad;
   type Quad_Access is access Quad_Array;

   type Mesh is record
      Solid : Quad_Access;          --  opaque and cut-out faces, the tufts last
      Cast  : Natural := 0;         --  how many of them can cast a shadow: all but the tufts
      Water : Quad_Access;          --  blended pass
      Z_Lo  : Integer := 0;         --  block rows the stack's faces span
      Z_Hi  : Integer := 0;
   end record;

   procedure Build (W : World; CX, CY : Integer; Work : Stack_Work; M : out Mesh;
                    Rim  : Castle.Edits.Rim_Access := null;
                    View : Castle.Water.View_Access := null);
   --  View: the live water round the stack, which wins over the generator's.
   --  Neighbour columns across the stack edge come from the column
   --  functions, so ground and water faces between stacks are culled
   --  exactly.  Features in the neighbour (a tree crossing the edge) count
   --  as air there, which only adds a few hidden faces.  Rim carries the
   --  player's edits in those neighbouring columns, which win over the
   --  generator.  Blocks below the skin (Deep) that an edit has laid open are
   --  drawn as their real rock or ore.

   procedure Free (M : in out Mesh);
   function Count (Q : Quad_Access) return Natural is (if Q = null then 0 else Q'Length);

end Castle.Mesher;
