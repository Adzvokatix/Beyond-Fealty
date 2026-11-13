with Castle.Blocks; use Castle.Blocks;
with Castle.Hash;   use Castle.Hash;
with Castle.Maps;   use Castle.Maps;
with Castle.Stacks; use Castle.Stacks;

--  Stage 4: overworld features built from blocks - trees, berry bushes and
--  boulders.  Each feature is seeded on a jittered grid cell.  Any stack
--  touched by a feature's bounding box regenerates that feature and writes
--  only its own blocks, so features cross stack boundaries seamlessly, with
--  no ordering between stacks and no shared state between threads.  Grass
--  tufts and wild grain are decided per column in Castle.Geology.
--
--  Trees grow in forests: patches of the map (Forest_Density) where they
--  stand thick, a tree to almost every 4 m cell.  Between the forests the
--  land is open, dotted now and then with a lone tree: a wild apple in the
--  lowlands (fruit trees want the sun), a spruce up high.  In a forest:
--    Broadleaf  brown bark (Log); a dome of leaves over the trunk and a
--               ring of puffs round it, each on a bough, in one of three
--               habits (wide and low, tall and stacked, ragged and
--               leaning); leaves light or dark
--    Aspen      silver bark with dark scars, tall and slim, small puffs of
--               pale leaves up the top half of the trunk, which shows
--               between them; aspens stand together in groves and all turn
--               gold in autumn
--    Spruce     a dark cone of drooping whorls from low on the trunk, a
--               spire on top
--    Pine       red-brown bark, bare most of its height but for a dead
--               stub or two, flat plates of needles high up
--  Conifers take over with height.  Apples grow only alone, in the open.
package Castle.Flora is

   type Species is (Broadleaf, Aspen, Spruce, Pine, Apple);

   type Tree is record
      Valid   : Boolean := False;
      Kind    : Species := Broadleaf;
      Bx, By  : Integer := 0;   --  trunk south-west corner (blocks)
      Bz      : Integer := 0;   --  first block above ground
      Trunk_H : Integer := 0;
      Trunk_W : Integer := 1;
      Crown_R : Integer := 0;
      Bark    : Material := Log;      --  its trunk and branches (a Trunk)
      Leaf    : Material := Leaves;   --  its crown (a Crown)
      Seed    : U64     := 0;
   end record;

   type Lump_Kind is (Bush, Rock);

   type Lump is record
      Valid      : Boolean   := False;
      Kind       : Lump_Kind := Bush;
      Cx, Cy, Cz : Integer   := 0;
      Rh, Rv     : Integer   := 1;   --  horizontal / vertical radius (blocks)
      Seed       : U64       := 0;
   end record;

   Tree_Reach : constant := 20;
   --  No block of a tree is further than this from its trunk, sideways or
   --  above its top (blocks): a stack looks no further for the trees that
   --  reach into it, nor does felling.  tools/flora_stats draws three
   --  thousand of each kind alone and fails if one reaches further.
   Tree_Cell : constant := 16;   --  4 m: Castle.Colony.Tree_Cell_B must match
   Bush_Cell : constant := 12;   --  3 m
   Rock_Cell : constant := 24;   --  6 m

   Lone_Chance : constant := 0.018;   --  of a lone tree in a 4 m cell of open land
   Bush_Share  : constant := 0.82;    --  berry bushes, against the first rule (half as many in all)

   --  How a tree is shaped (generator 13; John, 2026-11-11: "we can rewrite
   --  the trees").  First values.
   Crown_Lump     : constant := 0.34;   --  how lumpy a broadleaf's puffs are (of the squared reach)
   Crown_Wave     : constant := 3.6;    --  blocks across a lump
   Bough_Out      : constant := 0.65;   --  a bough bends this far along its way out,
   Bough_Rise     : constant := 0.15;   --  having risen this share of its climb: out first, then up
   Twig_Out       : constant := 0.55;   --  a twig reaches this share of its puff's radius
   Spruce_Whorl_B : constant := 5.5;    --  blocks from one whorl of a spruce to the next
   Spruce_Tier    : constant := 0.50;   --  a whorl is drawn in by this much at its top
   Spruce_Droop   : constant := 0.30;   --  blocks a whorl hangs lower for each block out from the trunk
   Spruce_Lobe    : constant := 0.16;   --  how far its five boughs stand out of the round
   Spruce_Girth   : constant := 1.12;   --  its lowest whorl against the tree's crown radius

   function Forest_Density (W : World; Xm, Ym : Float) return Float;
   --  0 in the open, up to 0.97 deep in a forest: the chance of a forest
   --  tree in a cell.
   function Tree_At (W : World; I, J : Integer) return Tree;
   function Bush_At (W : World; I, J : Integer) return Lump;
   function Boulder_At (W : World; I, J : Integer) return Lump;

   procedure Tree_Blocks
     (T     : Tree;
      Visit : not null access procedure (Bx, By, Bz : Integer; M : Material));
   --  Every block tree T writes, on its own (as if nothing else were
   --  there): its trunk, rooted two blocks into the ground, branches and
   --  crown.  For felling it: what the world holds there now is the
   --  caller's to compare.  Main thread; allocates a scratch stack.

   procedure Decorate
     (W      : World;
      X0, Y0 : Integer;
      G      : in out Stack_Grid;
      Top    : in out Integer;
      Clear  : access function (Bx, By : Integer) return Boolean := null);
   --  Top is raised to the highest block row any feature wrote.
   --  Writes every feature block that falls inside the stack whose block
   --  origin is (X0, Y0).  Features whose root satisfies Clear are left out
   --  (felled for a zone; in the game, felled trees will be edits instead).

end Castle.Flora;
