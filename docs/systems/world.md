# The world

- Packages: Castle.Terrain, Geology, Deposits, Hydrology, Flora, Chunks, Worldgen, Maps, Channels, Stacks
- Check: none of its own (worldgen_preview's survey checksum; terrain_stats, flora_stats, probe, water_probe, fall_find measure it)
- Saves: nothing is saved: the world is the seed and Generator_Version (16 since 2026-11-17)
- Stage: phase A, and the palette and forests of 2026-11-08 (Handoff_2026_11_08_world_look.md); wild vegetables in
  stage 4; trees reshaped and tall grass in drifts, 2026-11-11 (Handoff_2026_11_11_models_pass.md)

`./bin/probe X Y [X Y ...]` prints what the generator put at metre position
(X, Y) for seed 1: height, water, moisture, surface, veins, deposits.
`./bin/water_probe X Y [R]` prints the generated water round (X, Y) block
by block (ground row and water rows) over the 1 m fields, and
`./bin/fall_find` lists seed 1's biggest falls, for looking at water.

Output (`preview/`, uncompressed PNG; `optipng` shrinks them):

- `terrain.png` — 1 px = 1 m: what the player sees, outcrops included.
- `outcrops.png` — two 256 m windows at 1 px per block around a coal and an
  iron outcrop (veins with gold preferred).
- `resources.png` — 1 px = 2 m: vein outcrops (bright discs), each vein's
  roots seen through the ground (faint), silver tips (blue) and gold tips
  (yellow), bog iron.
- `aquifer.png` — the well heatmap: hue = yield (red poor, blue good),
  brightness = depth to water.
- `sections.png` — four 256 m cuts at 2 px per block: along the heading of a
  coal and an iron vein, with the whole root system X-rayed onto the cut
  (gold yellow, silver blue), the highest peak, the largest river. Each cut
  is cropped to the ground it crosses. The stored 2 m skin is drawn per
  block; the deep is generated on the fly and drawn dimmed with 1 m outlines.

The survey prints a content checksum that must not change with `--workers`.

## The world model

* **Every common resource is visible from the surface.** Coal, iron and salt
  are veins grown like tree roots: a trunk breaks the surface in a small
  outcrop a few metres across, with loose ore strewn up to 6 m round its
  mouth, and dives into the hill, snaking and splitting into thinner
  branches that taper out deeper in. Tips steer toward a band of cover that
  deepens with distance, so a vein follows the hill instead of sinking to
  the bedrock. A mine starts at the outcrop and follows the vein. Bog iron
  shows as rust-speckled turf over a limonite layer 0.5 m down.
* **Gold and silver sit in the deep tips.** Only branch ends at least 35 m of
  vein in from the outcrop and 5 m below ground, and up to two tubes back
  from them, carry silver or gold, chosen per 1 m cell. They are never in
  reach at the start. `Castle.Deposits.Precious` is the tuning table (odds
  and shares per vein kind; gold odds rise in mountain districts).
  The cover test looks only at each tube's ends, so where a rich tube runs
  under a gully or behind a cliff face its middle can come within the 2 m
  skin and show a glint of silver or gold at the surface. That is kept on
  purpose: a rare surface sign of a rich vein worth following.
* **Shoring.** `Castle.Geology.Needs_Shoring (Host, Cover_M)`: digging under
  more than `Safe_Cover_M` metres of ground needs engineers to shore it (granite
  14, limestone 9, sandstone 6, water-bearing rock 4; a tuning table).
* **Only the skin is generated:** the top 2 m of ground and everything above
  it, cliff faces included. Nothing below it is generated or stored;
  `Castle.Geology.Deep_Brick` produces any 1 m cell on demand (well shaft,
  cellar, mine), always the same for the same seed and `Generator_Version`.
* **Aquifers are a field, not voxels.** `Castle.Geology.Well_Info` returns the
  depth to water and yield for the well tooltip; the heat map draws the same
  field, in the game too (F8, `--wellmap`: 30 m round the camera, hue the
  yield from red to blue, darker the deeper the water). Wet rock looks like
  dry rock (up to generator version 8 it was a block of its own, Aquifer,
  which showed at the bottom of any deep hole); shoring still treats it as
  failing first (`Water_Bearing`).
* **Forests and open land** (`Castle.Flora`). Trees grow in forest patches
  about 190 m across with fairly sharp edges (`Forest_Density`), where they
  stand thick: up to a tree in every 4 m cell (`Tree_Cell`). Between the
  forests the land is open, dotted now and then with a lone tree
  (`Lone_Chance`, about one per 900 m^2): a wild apple in the lowlands,
  since fruit trees want the sun, a spruce up high. Apples grow nowhere
  else. Berry bushes favour forest edges (half as many as before generator
  10: `Bush_Share`). On seed 1, `./bin/flora_stats` counts 41 % of the land
  as forest at about 500 trees a hectare, 11 trees a hectare in the open
  (two thirds of them apples) and 25,000 berry bushes. It also lists what
  grows within 60 m of a spot and the nearest tree of each kind
  (`flora_stats [SEED [X Y]]`), draws up to three thousand trees of each
  kind alone and says how far they reach (it fails if one reaches past
  `Tree_Reach`, 20 blocks: no stack and no felling looks further), how
  much bark stands off the trunk under a serf's height, and a hash of all
  their shapes, which the debug and the release build must agree on.
* **Boulders** (`Castle.Flora.Boulder_At`; generator 14). A place for one
  every 6 m, held or not by how rocky the ground is there (a little
  everywhere, more on slopes, in the mountains and in rocky patches), a
  chance rolled once for the place. John, 2026-11-14, looking at the
  mountains: "I propose we scale back boulders on mountainous terrain by
  about 80%, let's compensate with increasing boulders on open terrain by
  30% ... they are littered with boulders, and the player probably won't
  be accessing a majority of them". So the chance is taken 1.3 times
  where the generator's mountain mask is nothing and a fifth from 0.2 of
  it up, eased between (`Boulders_Open`, `Boulders_Mountain`,
  `Boulder_Foot`, at the top of `castle-flora.ads`). Counted by
  `flora_stats` over the map (seed 1), by that mask:

  | | of the map | boulders, generator 13 | generator 14 |
  |---|---|---|---|
  | open land (mask under 0.1) | 79.5 % | 2,217 | 2,828 (+28 %) |
  | the foot of the mountains (0.1 to 0.2) | 3.2 % | 443 | 202 |
  | mountains (0.2 and over) | 17.3 % | 7,275 | 1,447 (-80 %) |
  | the whole map | | 9,935 | 4,477 |
  | within 60 m of the reference stake | | 30 | 16 |

  Those left on a mountain are of those that were there, and the open
  land's are all still there with more among them (the roll is the
  place's). Round the reference stake there are fewer: it stands at a
  mountain's foot (the mask is 0.38 to 0.52 on the crag north-east of
  it, and 0.1 or more at a quarter of the places within 60 m). Every run's scene is set as
  it was (the stockpiles' places, the camp's floor, the hovels' room, to
  the line), and all eight reference logs were recorded again. What it
  saves in memory is nothing to speak of (boulders were 0.8 % of the fine
  bricks; the map kept small is 990 MB for 992); in a view of that
  mountainside from above it is 2 % of the quads. It is for the eye.
  Since 2026-11-16 a boulder is drawn round (`rendering.md`, "Boulders
  drawn round").
* **A boulder goes into the ground** (generator 15, 2026-11-16; John, the
  boulders drawn round: "make the base of the boulders, so they don't look
  like balls plopped everywhere, they need extend into the ground").
  `Castle.Flora.Rock_Column`, column by column, each column by its own
  ground (so on a slope it follows the slope): the round with its noise as
  it was; then, on dry ground, everything under the round down into the
  ground's top block, so nothing is hollow under a boulder (on a slope its
  downhill side goes down to the ground, where it hung over it); and round
  its foot a skirt 0.4 wider than the round (`Skirt_Spread`) in the ground's
  top block and the first over it, and 0.2 in the next (`Skirt_Rise`, 2), on
  a gentler noise of the column alone, so its edge has no loose blocks. Its
  centre is where it was (at the ground's level or a block under it: half
  of it was always buried), so what was missing was spread where the rock
  meets the ground; the drawing alone could give it a quarter of a metre at
  most (`rendering.md`, "Boulders drawn round", the foot), which did not
  show from 60 m. The 16 boulders within 60 m of the reference stake: rock
  blocks 6,071 -> 9,638, those over the ground 3,554 -> 5,733, the ground
  they cover 1,006 block columns -> 2,336 (63 m2 -> 146). The boulders and
  where they are are as they were (4,477; `Boulder_At` untouched);
  `Rock_Reach` is 11 blocks (8). Making a stack costs what it did (1.45 ms
  of a worker for 1.43, the whole map held). **All eight reference logs
  were recorded again**: every run's scene is set as it was, to the line;
  how each ends moved, both ways (living at the end of the eight: 32
  before, 29 after). Saves from generator 14 are refused, as any change of
  generator's.
* **A tree goes down through a boulder to the ground** (generator 16,
  2026-11-17; John: "see if we can do something about the trees being on
  top of the rock, the trees should go through the rock to the ground").
  697 of the map's 99,220 trees stand where a boulder lies (370 by the
  round alone, before generator 15); their trunks stood on the rock. Now
  the rock gives way round a trunk `Trunk_Cleft` blocks (1) each side, from
  the ground's top block (put back as the column has it) up to the trunk's
  top, and the trunk itself may take the place of rock (`Trunk_Wood`; a
  branch may not): the trunk stands on the ground in a cleft of the rock.
  The mesher's stack-edge corners do not know the cleft (they lean toward
  the rock as made, both stacks alike). A tree felled there leaves its cleft
  in the rock, and that is expected (John, the same day: "tree leaving a
  whole in the stone is expected, no need to change it"). All eight reference logs recorded
  again: every scene set as it was; one run did not move, the rest ended
  otherwise (living at the end of the eight: 29 before, 33 after).
* **Tall grass** (generator 13, `Castle.Geology`; John, 2026-11-11: "grass
  can get a slight overhaul"). It stands in drifts, not evenly: a noise
  about 9 m across (`Grass_Drift_M`, a channel of its own) says how thick.
  Out of a drift 3.5 % of the turf's columns carry a tuft, in the heart of
  one 46 % (`Grass_Thin`, `Grass_Thick`; more on moist ground, fewer on
  dry), and there three tufts in ten stand two blocks high (`Grass_Long`).
  On seed 1 a tuft stands on 16 % of the turf's columns, one in six of
  them long. (Up to generator 12 it was 18 to 48 % everywhere, by moisture
  alone: 30 % on seed 1.) A tuft is straw to the band, so no land is
  without. Wild vegetables and wild grain are placed first, as they were.
  How a tuft is drawn: `rendering.md`, "Grass".
* **Wild vegetables** (generator 11, `Castle.Geology`). Roots and greens,
  one plant a block (`Wild_Vegetables`: bright green leaves in a rosette, the top
  of a wild carrot, turnip, parsnip or onion showing at the foot), grow in
  patches about 20 m across on moist, gentle grassland, thickest in the
  middle of a patch (`Veg_Edge`, `Veg_Chance`). They don't cast shadows and
  vanish under snow like grass. On seed 1 there are about 590 within 60 m
  of the README's stake and some 700 to a hectare of grassland.
* **Trees.** Five kinds, each with its own bark and leaf blocks. Where a
  tree stands, its kind, its trunk and the size of its crown are as they
  have been since generator 10 (`Tree_At`), so the colony's trees, their
  logs and their felling are unchanged; how it is shaped is generator 13
  (John, 2026-11-11: "we can rewrite the trees"; `Draw_Tree`, first values
  at the top of `castle-flora.ads`). A crown is puffs of leaves: domes,
  each an ellipsoid cut off flat a little under its middle, its surface
  lumpy on a smooth noise three or four blocks across (`Crown_Lump`,
  `Crown_Wave`), where it was boxes with their corners cut off. A puff
  hangs on a bough, a curve of bark that leaves the trunk, goes out and
  then up (`Bough_Out`, `Bough_Rise`), and has two or three twigs in it,
  so a tree bare in winter is boughs and twigs, not a pole.
  * **Broadleaf:** brown bark (`Log`). A dome over the trunk and a ring of
    three to six puffs round it, hanging to about two thirds of the way
    up the trunk, in one of three habits: wide and low (two more puffs on
    the dome's shoulders), tall (domes stacked up the leader), or ragged
    (fewer, of every size, the whole of it leaning one way). Leaves are
    light (`Leaves`) or dark (`Dark_Leaves`).
  * **Aspen:** silver bark with dark scars (`Aspen_Log`), tall and slim:
    five to seven small puffs of pale leaves (`Aspen_Leaves`) up the top
    half of the trunk, each a little to one side of it and the next to
    another, so the trunk shows between them. Aspens stand together in
    groves and all turn gold in autumn.
  * **Spruce:** a dark cone of whorls from a quarter of the way up the
    trunk, one about every 1.4 m (`Spruce_Whorl_B`), each widest at its
    foot and drawn in by half above (`Spruce_Tier`), hanging lower the
    further out it reaches (`Spruce_Droop`), its boughs in five lobes that
    turn from whorl to whorl (`Spruce_Lobe`); a spire on top.
  * **Pine:** red-brown bark (`Pine_Log`), bare most of its height but for
    two or three dead stubs, with three to five flat plates of needles at
    the top on boughs that bend up to them.
  * **Apple:** short, the wide habit small: a round head of leaves with
    apples in it, hanging low round the trunk on boughs that leave it at
    its top, so there is room to stand under them and pick.

  Conifers take over with height. Each crown is also tinted a little
  lighter or darker, yellower or bluer, about tree by tree (in the shader).
  `Castle.Blocks.Trunk` and `Crown` are the sets of bark and leaf blocks.
  Three rules the shapes keep, for whoever changes them:
  * A tree's shape goes by its seed and by where its blocks are in the
    world, nothing else: each stack it reaches into draws it alone.
  * No block of it lies further than `Tree_Reach` (20 blocks) from its
    trunk, sideways or above its top.
  * A stack draws the trunk of every tree before the boughs and leaves of
    any, so a bough that crosses where another tree stands never lies in
    that tree's trunk. No bough or stub of a broadleaf, an aspen, a spruce
    or a pine is within a serf's height of the ground (bark is solid: it
    would change where a serf can walk); an apple's are lower, as they
    were, though fewer than they were.

  On seed 1 a broadleaf drawn alone is about 1,960 blocks (2,490 before),
  an aspen 700 (880), a spruce 1,670 (as before), a pine 600 (740), an
  apple 430 (380): rounder for fewer blocks.
* **Cliffs.** In patches of hill and mountain country, steep ground is
  remapped through a terrace curve into ledges and near-vertical rock risers
  5-14 m tall. Riser height, sharpness and the level the steps start from
  wander with noise, so the bands break up. Constants in `castle-terrain.ads`.
* **Water.** Depressions shallower than 2.5 m or smaller than 6,000 m^2 silt
  up into flat wet meadow; deeper and wider ones are lakes at their spill
  level, and so is a small one that is deep (generator 12: 4 m or more and
  at least 500 m^2, `Tarn_Min_Depth` and `Tarn_Min_Area`): a tarn. On seed
  1 that makes 8 tarns beside the 5 lakes, all in the mountains. (Before,
  a hollow 11 m deep and 2,400 m^2 wide at 1311, 1465 silted up to its
  brim for want of area: a dry lake bed of bare rock with a stream running
  out of it. The lowland flats, all under 1.1 m deep, still silt up.)
  A stream exists where its catchment reaches 60,000 m^2, and its
  head then climbs its main stem up to 6,000 m^2: fewer feeds, running
  further up the hills. Every channel is built to carry live water:
  * it has a discharge, catchment x `Runoff` (game scale: the largest rivers
    carry about 10 m^3/s);
  * its water surface is worked out along the network, upstream first:
    0.35 m under the lowest ground across the flow at its banks, falling at
    least 2 mm a metre all the way to its mouth, graded (no steeper than
    4 cm a metre unless the ground itself is, so a dip or a tributary is
    met over a stretch, not in one step), and backed up to a lake's level
    where a river ends in one; the freeboard ramps in over the first 8 m
    from a lake, so outflows leave at the lake's level instead of draining
    it;
  * its width grows with the square root of the discharge (5 sqrt Q, up to
    24 m), and the bed lies the flow's Manning depth below the surface, with
    a rough bed (n = 0.1), so rivers run slower and deeper: at least 1 m
    for a river, 0.75 m for a stream (seed 1: rivers 0.97 m deep on
    average, streams 0.66 m);
    Manning is solved cubed, so only exactly rounded arithmetic is used and
    worlds come out the same on every machine.
  Lake outflows are channel down to the first stream within
  `Connect_Range_M` (60 m). A meander pass displaces every channel with one
  smooth warp field, so tributaries still meet their river exactly; a cell
  inside a channel takes bed and level from the one centre nearest it.
  Steep beds carry a film of fast water over the bed (never the banks).
  A fall is not built from blocks: the surface sheet runs down it (see
  Drawing under Live water). (Up to generator version 7 the columns at the
  foot of a fall were filled to the level above as a curtain; per 0.25 m
  column, on 1 m D8 drainage, that stood as loose pillars.) Water
  never stands above the ground beside it: a dry block column next to water
  held above its ground is raised, up to 1 m, to the water's surface.
  Constants in `castle-hydrology.ads`; `./bin/water_check` measures all of
  it over the whole map (seed 1: 82% of channel-line cells fall to the next
  and 0.4% rise, no steps of 2+ blocks inside rivers, banks within 25 cm of
  the water halved against the old beds).

Pipeline (`castle-worldgen`): terrain -> geology fields -> hydrology
(Priority-Flood, silting, D8 drainage kept in `W.Down`, meandering channels,
water table) -> deposits -> aquifer field.

## Storage

A chunk is an 8 m cube = 8 x 8 x 8 bricks. A brick is 32 bits: material,
host rock, ore grade, owning deposit. A skin brick whose 64 blocks differ
keeps them (a fine brick: 128 bytes whole; kept small since 2026-11-14,
14 to 66 bytes, "What a stack costs to keep" below). Chunks below the
skin hold `Deep_Fill`. The skin is
a regenerable cache; a save is the seed, `Generator_Version`, clock,
climate, camera and the edits (see Editing and saves).

## What a stack costs to keep (2026-11-14)

John, of holding ground for the simulation that nobody is looking at:
"the inhabitants don't care what texture the objects are only the player
does, so let's find out what the 68kb is, 4.7 GB isn't going to be
acceptable, so we need to be smart about this". And his ceiling, the same
day: "we want to be comfortable on 8gb of ram, that means consuming 4gb
is our ceiling".

What is kept of a loaded stack for the simulation (`Castle.World_Blocks`:
its packed blocks and its ground summary; the game keeps its mesh
besides, in the renderer's arena) is counted by `colony_run --mem`, from
the sizes of the objects and how many of each are allocated, and
`--ground-stacks N` brings in as much ground as is asked (400: the whole
map, 65,536 stacks), `--no-mesh` with no mesh built. Over the whole map,
seed 1, generator 13, as it was before anything was changed:

| part of a stack | bytes | of it | read by |
|---|---|---|---|
| the ground summary: for each of 1,024 block columns, room for four stretches of open space and their water | 32,768 | 47 % | the walking map, the water |
| fine bricks: a cubic metre whose 64 blocks differ, 225 of them | 28,800 | 41 % | `Block_At`: the walking map (two materials a floor), the colony, the pointer |
| brick and ref grids of the 2.2 chunks that are not uniform | 6,800 | 10 % | with them |
| the array of chunks | 1,280 | 2 % | with them |

68.0 KB a stack, 4,355 MB for the map, the process holding 4.76 GB (the
map-wide fields of the generator are some 290 MB of that). Fine bricks by
what they hold: trees 38 %, plants 20.5 %, ground with no air in it
(under the surface, where materials meet) 28.5 %, open surface 9 %, water
2.7 %, boulders 0.8 %. A stack's blocks run from 5 KB to 75 (half under
31, nine tenths under 56; the heaviest is forest). A stack's blocks are
made in 1.4 ms of CPU and its mesh in 6.6 more: the whole map comes in
without meshes in 3.9 s on 32 threads.

**The ground summary is kept small** (`Castle.Water.Small_Summary`; his
word: "Sure build the compact summary"). Of every hundred block columns
89 are plain: one stretch, open to the sky, dry and not source water,
which the row of their floor says whole. Each column has a place of 16
bits: a plain column's is its floor; any other's is where its record
begins in a pool of 16-bit words (how many stretches and whether it
flows, its rest level, three words a stretch). Nothing is lost. It is
read a column at a time and written the same: over itself where a plain
column stays plain or another keeps its number of stretches, and by
packing the stack's summary again where not (three edits in a hundred of
the crowd's: 4,353 of 151,199 in its sixty days, with no time to
measure). **3.7 KB a stack where it was 32: the map 2,546 MB kept, the
process 2.87 GB.** `Castle.World_Blocks.Small_Summaries` off (`colony_run
--full-summaries`, and the game's) keeps it whole as it always was; a run
is the same either way (`tools/stress.sh runner`, `crowd_full_sums`), and
the debug build unpacks every summary it keeps and every column it writes
and compares with the whole. `edit_check` has it (four stacks of the
world, a made-up summary with columns of every kind, four thousand
columns written one at a time, a stack kept and dug into by the game's
own calls, small and whole); broken six ways, it fails each.

**Fine bricks are kept small** (`Castle.Chunks`, the same day; his words,
of the ground under the surface: "Let's see if we can cut the burried
skin down to 4kb a stack, and see what that buys us"). Counted over the
whole map, no fine brick holds more than sixteen different blocks, and
seven in ten hold two (leaf and air, turf and earth, earth and rock): of
the 4.2 million with no air in them, 98 in a hundred. So a fine brick is
kept as a record of 16-bit words in its chunk's pool: how many different
blocks it holds, those blocks, and for each of its 64 places which of
them it is, in one bit (two blocks), two (to four) or four (to sixteen):
14, 26 and 66 bytes; a brick of more is written whole. Nothing is lost.
`Castle.Chunks.Block_In` reads a block out of it (the one reader;
`Fine_At` gives a brick whole). **3.9 KB of fine bricks a stack where
they were 28.2; the ground with no air in it 0.9 KB where it was 8.0.**
`Small_Bricks` off (`colony_run --whole-bricks`) writes them whole as
they always were: a run is the same either way (`crowd_whole_bricks` in
`tools/stress.sh runner`), and the debug build reads back every brick it
packs, place by place, against the blocks it was made of: run over the
whole map, 14.7 million bricks, none other. `edit_check` has bricks made
up of 2, 3, 4, 5, 15, 16, 17 and 64 different blocks; broken five ways,
it fails each. **It costs a little time**: a block read out of a fine
brick is a few shifts where it was an index; the band's 41 days take 5.5
s where they took 5.3 to 5.4, the crowd's 60 days 8.9 for 8.7 (the
machine quiet, the switch turned to and fro).

The other way to his 4 KB was tried and not taken: **the generator's
skin 1 m deep in place of 2** (a scratch build, not committed). The
ground with no air in it came to 3.4 KB a stack (fine bricks 23.6 for
28.2; the map 314 MB less), and the reference band's 41 days and the
housing run's ended in the same states. But the housing run read 23
blocks below the skin where it reads 15 (of 247 million): with a thinner
skin the colony is answered "not made yet" a little more often when it
digs. Nothing came of it in those runs; it changes what a reader can be
told, and kept small the same bricks come to 0.9 KB at the full 2 m. His
to say if he wants it besides.

Where that leaves a stack, over the whole map:

| | bytes a stack | the whole map kept | the process holds |
|---|---|---|---|
| as it was | 68.0 KB | 4,355 MB | 4.76 GB |
| the summary kept small | 39.8 KB | 2,546 MB | 2.87 GB |
| and the fine bricks | 15.5 KB | 992 MB | 1.28 GB |

Of the 15.5 KB: the summary 3.7, fine bricks 3.9, the brick and ref
grids of chunks that are not uniform 6.6 (now the largest part: 3 KB a
chunk, not looked into), the array of chunks 1.3. A stack's blocks run
from 4 KB to 22 (half under 11). The walking map is beside all this:
14.4 KB for a stack someone has walked, and 5.2 for each kind of dry
going asked there.

(On generator 14, the boulders thinned: 990 MB kept, the process 1.27
GB.) **The game itself, at its default view of 1,257 stacks, holds 62 MB
less**, measured: `main`'s build and this one in a hidden window with
software drawing, 1,829 MB and 1,767 MB once the view had filled (the
totals are that renderer's; the difference is the game's). The
whole-map figures above are the runner's; the game holds the whole map
since the same day (next).

## The whole map held (2026-11-14)

John: "can make the whole map solid and stream only the mesh?", and,
with the counts above before him: "ok build it with the whole map solid
we can do that now before the stockpile".

**The game keeps every stack's blocks and its ground summary** (what the
simulation reads: `Castle.World_Blocks`) from soon after it starts, and
streams the meshes alone. In `game/castle_game.adb`:

- `States` is the mesh's state. A stack out of view is asked for
  **without a mesh** (`Castle.Streaming.Request (..., Mesh => False)`: its
  blocks and summary alone, 1.4 ms of a worker where a meshed stack is
  9), in rings round the stack first looked at, 256 out at a time, behind
  everything the view asks for (their results wait in a ring of their
  own, so a mesh the view asked for is never behind them). The main
  thread keeps them for at most half a millisecond of a frame.
- A stack that leaves the view gives up its mesh and what is drawn of
  its water, and **keeps its blocks**. The colony's own ground stays
  meshed wherever the camera is, as it always did (`Colony_Holds`).
- **What is held and not drawn is made again when its edits have moved**:
  the map is looked over all the time (`Hold_More`: 4,096 stacks a frame
  while it finds any to ask for, 256 once a whole round has found none),
  and a held stack whose edit generation is not the one it was kept at
  (`Held_Gen`: a dig across its edge; a load) is asked for again. After a
  load every stack held and not drawn is (`Hold_Stale`). A result older
  than what is held never replaces it.
- Live water in a stack that is not drawn is the water simulation's, as
  it always was while a stack was unloaded; the stack's kept blocks have
  the water it was last made with, and it is made again with the live
  water when it comes into view.
- `--no-whole-map`: as before, a stack is dropped with its mesh.

**What it costs, measured in the game** (the default view at the
reference stake, a real window of 1,280 x 720, twice each way):

| | the old way | the whole map held |
|---|---|---|
| the process holds, no band | 548 MB | 1,526 to 1,533 MB |
| with the reference band, panned 520 m off and back | 609 MB | 1,582 MB |
| the view filled | 0.49 s | 0.47 s |
| the whole map held | never | 12.1 s after the first frame |
| the main thread's work a frame, over the first fifteen seconds | 0.12 ms | 0.93 to 1.00 ms |
| its longest frame after the view filled, no band | 0.4 to 0.8 ms | 4.9 to 5.2 ms |

**About 0.98 GB more, 1.5 to 1.6 GB in all: under his ceiling of 4 GB.**
The peak is the same as the end (nothing is held twice). The holding
takes 0.4 s of the main thread in all, and 1.1 to 2.3 ms in its worst
frame (4.6 once, with a band at work and the camera panning); the
longer frames while it runs (some forty of seven hundred over 2.5 ms,
none over 5.2) are the drawing waiting on processors the workers have,
for those twelve seconds. A pan of 520 m with a band at work has the same
long frames both ways (10 to 14 ms, the view's own meshes coming in).
On a machine with few processors it takes longer in the background (64
thousand stacks at 1.4 ms each, over the workers) and the main thread's
half millisecond a frame is the same. (With the
far view's tiles made before what is only held, the map is held 18.3 s
after the first frame on 31 workers, and 67.6 s on three, 23.8 without
the far view: `rendering.md`, "The far view".)

**What changes besides the memory:**

- **Released water runs as it does at a wide view, whatever the view.**
  Ground that was not loaded was a wall to the water. A lake let out
  through a cut with a view of 16 m piled 194 m³ against the edge of the
  loaded ground (13 stacks simulated); with the whole map held it does
  what it does at any view (28.6 m³ out of its sources, 21 stacks). How
  far and how fast it runs is as it was (`Max_Awake` and John's dials in
  `water.md`). In the first seconds after a start the far ground is still
  coming in.
- **The colony goes by its own ground, not by what is loaded**
  (`colony.md`, "The colony's own ground"): with everything loaded,
  nothing else bounds it. `--walk` and `--deer-walk` keep to the ground
  round their two ends for the same reason (`Castle.Serfs.Walker_Round_M`).
- **What the player plans can be read anywhere**, at once (a path's
  line, a zone), where it could be read only on ground the camera had
  passed over.

**Proved** (scripted, `--save-at F PATH`, `--load-at F PATH`,
`--probe-block X Y Z`, `--hold-wait`, `--mem`):

- a hole dug, the camera panned 520 m off: the block in the hole reads
  air, the one under it the rock the dig laid open, "its stack is held
  and not drawn" (the old way: nothing is held there);
- the same with a save from before the dig loaded while the camera is
  away: the block reads earth again. With the asking-again taken out it
  reads air, the stale hole;
- the debug build through both, and through a lake let out, a pan away
  and back (every summary kept is unpacked and compared, every loaded
  stack in the water's window holds its own texels): nothing raised, the
  water drawn on coming back as the old way draws it;
- 65,536 of 65,536 stacks held at the end of each run (the run's own
  count), and no job lost.

**The streaming's two silent limits are gone** (`Castle.Streaming`): the
queue held 32,768 jobs and dropped what came after, and a result that
found the ring of 8,192 full was dropped and leaked. That was the
"crawl" of asking the runner for every stack at once: on `main` it does
not end (stopped after 60 s); now it takes 8 s. The queue has room for
every stack twice, a worker with a result waits while the ring is full,
and a job lost would be said loudly at the end of a run.

Not done: the colony's own ground is still meshed while out of view (a
rebuild of an edited stack there costs a mesh nobody sees: 995 in the
band's 41 days); a held stack coming into view is made again from the
generator, not meshed from what is held.
