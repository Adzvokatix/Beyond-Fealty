with Interfaces;
with Castle.Colors;

--  The block is the one atom of the world: terrain, water, ore, trees,
--  buildings and creatures are all built from 0.25 m blocks (16 bits each).
--
--  Storage keeps only the skin (the top 2 m of ground and everything above
--  it) at block resolution.  Below that the world is never stored: a chunk
--  holds Deep_Fill there, and Castle.Geology.Deep_Brick produces any 1 m
--  cell on demand.  Generated deep cells are bricks: one value per 1 m cell
--  (4 x 4 x 4 blocks); an ore body thinner than a metre is carried as a
--  grade (the fraction of the brick that is ore).
package Castle.Blocks with Pure is

   type Material is
     (Air,
      Deep,   --  below the skin, not generated yet: ask Castle.Geology.Deep_Brick
      --  ground
      Bedrock, Granite, Limestone, Sandstone,
      Dirt, Grass, Sand, Gravel, Clay,
      --  water
      Water,
      --  resources
      Coal, Iron_Ore, Bog_Iron, Silver_Ore, Gold_Ore, Rock_Salt, Placer_Gravel,
      --  overworld
      Boulder,
      Log, Aspen_Log, Pine_Log,                             --  trunks (Log is also built with)
      Leaves, Dark_Leaves, Aspen_Leaves, Pine_Needles, Apple_Leaves,   --  crowns
      Berry_Bush, Bare_Bush,                                --  Bare_Bush: picked
      Tall_Grass, Wild_Grain,
      Wild_Vegetables,                                      --  roots and greens, one plant a block
      --  built
      Plank, Shingle, Footpath,
      Thatch,                                               --  a roof of straw (on the end: blocks are saved by position)
      Daub,                                                 --  wattle and daub: a wall's panels between its timbers
      Fieldstone)                                           --  gathered stones laid dry: a retaining wall, a stair's treads
     with Size => 8;

   subtype Trunk is Material with Static_Predicate => Trunk in Log | Aspen_Log | Pine_Log;
   --  What a tree's trunk is made of (Log is also a building material).
   subtype Crown is Material
     with Static_Predicate => Crown in Leaves | Dark_Leaves | Aspen_Leaves | Pine_Needles | Apple_Leaves;
   --  A tree's leaves or needles.

   type Block is record
      Mat   : Material := Air;
      State : Interfaces.Unsigned_8 := 0;
      --  Reserved: sub-block shape and orientation, fluid level, growth stage.
   end record
     with Size => 16;

   for Block use record
      Mat   at 0 range 0 .. 7;
      State at 1 range 0 .. 7;
   end record;

   Air_Block : constant Block := (Mat => Air, State => 0);

   --  A block of thatch that has been dressed (a roof's steps trimmed to
   --  one slope by whoever thatched it) says so in its state, and how it
   --  lies (and so does the top block of daub of a gable's step under it,
   --  whose top is brought up to the same slope): the mesher marks its faces and the renderer draws them sloped
   --  (Castle.Mesher, "A dressed roof").  Nothing else reads a block's
   --  state but Seen_Mat (below).
   Dressed     : constant := 128;   --  it is trimmed
   Falls_Mask  : constant := 3;     --  the way its top falls: 0 toward +x, 1 -x, 2 +y, 3 -y
   At_Eave     : constant := 4;     --  it is the lowest of its slope: its edge is cut blunt, half a block thick
   At_Ridge    : constant := 8;     --  it is a ridge's one middle block: it falls both ways from its middle line
   Verge_Lo    : constant := 16;    --  it ends its row at the roof's edge down the other axis (toward -y for a
   Verge_Hi    : constant := 32;    --  slope along x, -x for one along y), or up it: that edge is drawn in a little
   Under       : constant := 64;    --  it is the lower of the two blocks of thatch there, where the roof hangs
                                    --  out past a gable: its underside is trimmed to the slope as the top is

   --  A block of a stockyard laid as one of the pieces its design is drawn
   --  as (2026-11-20; Castle.Colony.Yard_Pieces): a rail or a gateway's
   --  plank of a stockyard along a path at 45 degrees, the roof of a
   --  covering once smoothed.  Its state is Piece (log, plank or thatch,
   --  never dressed), and what draws the land (Castle.Mesher, Castle.Lod)
   --  leaves it out: the piece is drawn instead.  To everything else it is
   --  the block it is: the feet, a ray, water, a save.
   Piece       : constant := 1;

   type Brick is record
      Mat     : Material := Air;               --  the ore, or the rock itself
      Host    : Material := Air;               --  rock around a partial-grade ore
      Grade   : Interfaces.Unsigned_8 := 255;  --  ore fraction; 255 = all of it
      Deposit : Interfaces.Unsigned_8 := 0;    --  owning deposit (1 .. 255), 0 = none
   end record
     with Size => 32;

   for Brick use record
      Mat     at 0 range 0 .. 7;
      Host    at 1 range 0 .. 7;
      Grade   at 2 range 0 .. 7;
      Deposit at 3 range 0 .. 7;
   end record;

   Air_Brick : constant Brick := (Mat => Air, Host => Air, Grade => 255, Deposit => 0);
   Deep_Fill : constant Brick := (Mat => Deep, Host => Deep, Grade => 255, Deposit => 0);

   function Plain (M : Material) return Brick is
     (Brick'(Mat => M, Host => M, Grade => 255, Deposit => 0));

   type Material_Class is (Gas, Solid, Liquid, Plant);

   Class_Of : constant array (Material) of Material_Class :=
     (Air   => Gas,
      Water => Liquid,
      Crown | Berry_Bush | Bare_Bush | Tall_Grass | Wild_Grain | Wild_Vegetables => Plant,
      others => Solid);

   Is_Ore : constant array (Material) of Boolean :=
     (Coal | Iron_Ore | Bog_Iron | Silver_Ore | Gold_Ore | Rock_Salt | Placer_Gravel => True,
      others => False);

   --  Every colour from the palette (Castle.Colors), by name.
   Base_Hex : constant array (Material) of Castle.Colors.Hex_Code :=
     (Air           => Castle.Colors.Fog_Blue,
      Deep          => Castle.Colors.Ash_Stone,
      Bedrock       => Castle.Colors.Ash_Stone,
      Granite       => Castle.Colors.Stone_Gray,
      Limestone     => Castle.Colors.Fog_Gray,
      Sandstone     => Castle.Colors.Copper_Brown,
      Dirt          => Castle.Colors.Mudstone,
      Grass         => Castle.Colors.Forest_Gold_Green,
      Sand          => Castle.Colors.Sand_Tan,
      Gravel        => Castle.Colors.Warm_Gray,
      Clay          => Castle.Colors.Aged_Leather,
      Water         => Castle.Colors.Storm_Blue,      --  River_Slate read as a grey road from afar
      Coal          => Castle.Colors.Charcoal,
      Iron_Ore      => Castle.Colors.Warm_Copper,
      Bog_Iron      => Castle.Colors.Warm_Umber,
      Silver_Ore    => Castle.Colors.Silvered_Steel,
      Gold_Ore      => Castle.Colors.Aged_Gold,
      Rock_Salt     => Castle.Colors.Salt_Pale,
      Placer_Gravel => Castle.Colors.Gilded_Amber,
      Boulder       => Castle.Colors.Mist_Iron,
      Log           => Castle.Colors.Weathered_Oak,
      Aspen_Log     => Castle.Colors.Silvered_Steel,
      Pine_Log      => Castle.Colors.Aged_Leather,
      Leaves        => Castle.Colors.Deep_Hunter,
      Dark_Leaves   => Castle.Colors.Deep_Forest,
      Aspen_Leaves  => Castle.Colors.Aspen_Green,
      Pine_Needles  => Castle.Colors.Pine_Shadow,
      Apple_Leaves  => Castle.Colors.Emerald_Lift,
      Berry_Bush    => Castle.Colors.Olive_Dark,
      Bare_Bush     => Castle.Colors.Moss_Shadow,
      Tall_Grass    => Castle.Colors.Grass_Seed,
      Wild_Grain    => Castle.Colors.Gilded_Amber,
      Wild_Vegetables => Castle.Colors.Sprout_Green,
      Plank         => Castle.Colors.Copper_Brown,
      Shingle       => Castle.Colors.Dark_Bark,
      Footpath      => Castle.Colors.Ashen_Brown,
      Thatch        => Castle.Colors.Thatch_Straw,
      Daub          => Castle.Colors.Daub_Clay,
      Fieldstone    => Castle.Colors.Field_Stone);

   function Base_Color (M : Material) return Castle.Colors.RGB is (Castle.Colors.Of_Hex (Base_Hex (M)));

   --  What a block is drawn as: a piece's block (Piece) as air.
   function Seen_Mat (B : Block) return Material is
     (if Interfaces."=" (B.State, Piece) and then B.Mat in Log | Plank | Thatch then Air else B.Mat);

end Castle.Blocks;
