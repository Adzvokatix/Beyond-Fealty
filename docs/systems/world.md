# The world

- Packages: Castle.Terrain, Geology, Deposits, Hydrology, Flora, Chunks, Worldgen, Maps, Channels, Stacks
- Check: none of its own (worldgen_preview's survey checksum; terrain_stats, flora_stats, probe, water_probe, fall_find measure it)
- Saves: nothing is saved: the world is the seed and Generator_Version (13)
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
keeps them (128 bytes). Chunks below the skin hold `Deep_Fill`. The skin is
a regenerable cache; a save is the seed, `Generator_Version`, clock,
climate, camera and the edits (see Editing and saves).
