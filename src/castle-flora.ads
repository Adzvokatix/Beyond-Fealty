with Castle.Blocks; use Castle.Blocks;
with Castle.Hash;   use Castle.Hash;
with Castle.Maps;   use Castle.Maps;
with Castle.Stacks; use Castle.Stacks;
with Castle.Geology; use Castle.Geology;

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

   --  How many of the boulders the ground would bear there are (John,
   --  2026-11-14, looking at the mountains: "I propose we scale back boulders
   --  on mountainous terrain by about 80%, let's compensate with increasing
   --  boulders on open terrain by 30% ... they are littered with boulders,
   --  and the player probably won't be accessing a majority of them").  By
   --  the generator's own mountain mask (0 open land .. 1 mountain): the
   --  open land's share where the mask is nothing, the mountains' from
   --  Boulder_Foot up, eased between.  A boulder's chance is rolled once for
   --  its place, so those left on a mountain are of those that were there,
   --  and those of the open land are all still there with more among them.
   --  A boulder goes into the ground (generator 15; John, 2026-11-16: "make
   --  the base of the boulders, so they don't look like balls plopped
   --  everywhere, they need extend into the ground").  Column by column
   --  (each column's own ground, so on a slope it follows the slope): the
   --  round with its noise as it was; everything under the round down into
   --  the ground's top block, so nothing is hollow under a boulder (on a
   --  slope its downhill side goes down to the ground); and round its foot
   --  a skirt, Skirt_Spread wider than the round in the ground's top block
   --  and the first over it and half that in the next (Skirt_Rise blocks),
   --  on a gentler noise of the column alone, so its edge has no loose
   --  blocks.  None of that over open water.  (Castle.Flora.Rock_Column.)
   Skirt_Spread : constant := 0.4;
   Trunk_Cleft  : constant := 1;
   --  (generator 16; John, 2026-11-16: "the trees should go through the rock
   --  to the ground") A tree where a boulder lies: the rock gives way this
   --  many blocks round its trunk, from the ground up, so the trunk stands
   --  on the ground in a cleft of the rock, not on top of it.
   Skirt_Rise   : constant := 2;
   Rock_Reach   : constant := 11;
   --  No block of a boulder is further than this from its centre sideways
   --  (Rh 6 at most: 6 + 1 + Skirt_Spread * 6.5, rounded up, is 10).

   Boulders_Open     : constant := 1.3;
   Boulders_Mountain : constant := 0.2;
   Boulder_Foot      : constant := 0.2;

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

   function In_Rock (W : World; L : Lump; Bx, By, Bz : Integer) return Boolean;

   function Rock_Reach_Of (L : Lump) return Integer;
   --  How far sideways from its centre boulder L reaches.
   type Rock_Span is array (-12 .. 36) of Boolean;
   procedure Rock_Column (L : Lump; X, Y : Integer; C : Column; Lo : out Integer; Span : out Rock_Span);
   --  Boulder L in column (X, Y) whose ground is C: block Lo + K is rock
   --  where Span (K) (In_Rock's own test, for a caller that asks of a
   --  whole column).
   --  Whether boulder L by its shape takes in block (Bx, By, Bz), whatever
   --  it would find there: the generator's own test (Rock_Column).  For the
   --  mesher, which rounds a boulder off on a stack's edge by what the
   --  stacks on both sides of it can work out alike.

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
