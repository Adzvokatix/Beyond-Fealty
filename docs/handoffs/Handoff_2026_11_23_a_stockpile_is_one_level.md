# Handoff, 2026-11-23 (later): a stockpile is one level

**Where this ended (read this first).** The rule this handoff describes was **set aside the same
afternoon** on his word ("let's go back to the stepped version, not the cut one"): it is **off by
default**, `--pile-flat` gives it, and the option `--no-pile-flat` of the sections below no longer
exists. In its place **a stockpile is refused where its ground is too steep**
(`--no-steep-refuse`). Branch `stockpile-flat` was then **merged into `main`** on his "then merge"
(gated at 6c118a2). All of that is under "His answer (2026-11-23, afternoon), and what was done on
it", near the end; the calls, the gate and the costs above it are the morning's, kept as the record
of what was built and why. One call of that section stands open: which reading of "over 1/2 slope".

The piece his second answer of the day opened. Branch `stockpile-flat`, made from `main` (5261caa),
gated at 8ae4d75 in the morning. One rule behind one switch (then `--no-pile-flat`, which gave the
stockpiles of the morning of 2026-11-23, each place by itself). The round before it, merged on his
"1. merge", is `Handoff_2026_11_23_paths_builders_and_stockpiles.md`.

## His words

> 2. flatten the stockpile, let's just make this easy for ourselves.

(of the call "A stockpile flattened whole, or each place by itself?", 2026-11-23). His other three
answers of that message are recorded at the end of the handoff before this one.

## What I had told him that was not so

The call he answered said: "that is cutting and filling up to a metre at its ends on the ground of
the game as it is played, walls of stone where the land beside stands more than a block off it,
and somebody to do it before the first load". None of the three is what is built, and the first
was wrong when I wrote it:

- **"Up to a metre"**: the tops of the ground under the stockpile of the game as it is played lie
  sixteen blocks apart, four metres, from its corner by the square to its far corner (19.50 to
  23.50 m; `colony_run --flat-scan`). I had looked at the places that held something, near its
  front. Built, its floor lies at 19.75 m, the level of its ground beside its path: **a cut of
  sixteen blocks, four metres, at its far corner**, a fill of two blocks at its front, 9,572
  blocks moved.
- **"Walls of stone"**: none is built. Where the land beside stands off the floor it stands as a
  bank, cut straight down, of whatever the hill is made of.
- **"Somebody to do it"**: nobody does. It is one level the moment it is put down, as a place was
  made level the moment something was put on it.

The row of the handoff before this one that recorded his answer said "some two metres of cutting at
one corner and of filling at the other": that was of a level at the middle of its ground, which is
not the level built. Mended there.

## The rule as built

`Castle.Colony.Set_Pile_Flat`, `--no-pile-flat`; on by default; not saved (a place's height is, and
whether it is closed). `Flatten_Pile`, called where a stockpile is put down (dragged or put down
whole) and again where something that was in its way is gone. The spec has it whole, under "A
stockpile is one level"; `docs/systems/colony.md` under the same words.

1. **One level, its path side's.** The level is the middle one (the lower of two) of the tops of
   its ground's block columns that have a path's column beside them; with none, of all its ground.
   Every place of it has that height.
2. **The land is cut or filled whatever it is made of**: earth, rock, a boulder, ore at the
   surface; as far as six metres (`Flat_Most_B`, 24 blocks). What lay on top lies on top (turf
   stays turf, rock rock). A boulder is cut through and its stone is gone, as the earth is; no
   block of a boulder is left in the floor's top (it would be prised out for its stone and leave a
   hole under what is stored).
3. **It is all of what was marked.** Its lot is planned for ground that will be one level: it
   takes the ledges in its box, and a place lies on it however the land falls under the place
   (`Plan_Lot`, `One_Level`).
4. **What the zoning still leaves out inside it goes with it**: a bush stands on an island of
   ground that is not the stockpile's; the island is brought to the level and the bush goes up or
   down with its ground, block column by block column. Leaves that hang where the floor comes up
   are lopped as high as a serf stands.
5. **Left until it is free**: the ground a tree stands on (the tree stands on a pillar of its own
   earth, or in a hollow, until the band has felled it, stump and roots, as it fells any tree in a
   stockpile put down whole; then the stockpile is made level where it stood); and the ground
   under the lord's cart and a metre round it (made level when the cart is drawn off it).
6. **Left for good**: a block column more than six metres off the level; one with water in what
   would be moved; one beside water that stands higher than it would be cut to (the water's
   bank); one with something built or standing where the earth would go. A place with such a
   column in it is closed for good.
7. Whoever stands there is put on the ground as it is now, and logs or a deer lying there; every
   way being walked is found again.

## Why each part is as it is (what the runs showed)

- **The level** was chosen by count, before anything was built, over 58 stockpiles as the land lay
  on their third day (the stockpile of the game as it is played, four at each of fourteen awkward
  squares, the reference run's; `colony_run --flat-scan` with the rule off, the measure as
  mended, below):

  | the level | deepest cut | highest fill | blocks moved | all of the front within two blocks of its path | half of it or more | none of it |
  |---|---|---|---|---|---|---|
  | the lowest of its ground beside a path | 20 | 7 | 123,871 | 43 | 54 | 0 |
  | **the middle of its ground beside a path (built)** | 18 | 7 | 95,167 | 45 | 56 | 0 |
  | the middle of its path's columns there | 19 | 7 | 125,513 | 42 | 57 | 0 |
  | the middle of all its ground | 13 | 7 | 64,359 | 43 | 47 | **4** |

  At the middle of all its ground four stockpiles have no part of their front within a step of
  their path: no way in. His own is one of the four (its floor would lie at 21.25 m, a metre to two
  over its path).
- **A bush** left where it stood under a floor filled in round it stood in a pit: a gatherer walked
  in, could not climb out (the walking map lets one drop a metre and climb half) and starved, at
  the square in the wood (816 964), in the first run of the rule. The same run was the first with a
  stockpile put down with the stake: its bushes were not yet known (a stack is looked through for
  them some ticks after the stake is put), so they are looked for first.
- **A tree's place looked at once**: with a trunk in the way a place was marked as looked at, and
  the earth its stump left stood two blocks over the floor for good; a run loaded before the
  felling made it level where the straight run did not (`tools/square_sites.sh`, the square at
  1320 980). A place with a trunk in the way is looked at again.
- **Rock and boulders were first left as they lay** (the square leaves a boulder standing and is
  made round it). At ten of the 58 rock or a boulder stood in the box off its level: 73 places
  closed over them, the
  boulder on a plinth of its own earth where the floor was cut round it; and the band prises
  stone off a boulder for the square's walls, so by the third day the earth under one stood bare,
  ten blocks over the floor at the square at 1172 1092, or in a hole of it. And **bog iron lies in
  the turf of three block columns in ten** at the reference stake: every such column off the level
  would have been left. So the land is cut whatever it is made of.
- **A boulder whose top lay at the level already** was left as floor, and prised out of it from
  the stockpile's edge inwards: eight block columns three blocks low on the twelfth day, at the
  same square. No boulder block is left in a floor's top.
- **The whole box**: the lot was planned on the land as it lay, so a stockpile on a hillside had
  no places on its steep bits though the floor there was now flat (a knoll in the made-up world: 98
  places of 100). Planned for one level: 5,626 places at the 58 for 5,585. The ledges it now takes
  as well changed nothing at those 58 (93,025 block columns of ground either way); the made-up
  check has one (a ledge a metre and a half high: 64 places for 32).
- **Where the cart stood**: a stockpile put down over the standing cart (it stands beside the
  square from the first hours; the player's first stockpile may well go there) left the cart's
  ground as the land lay, 160 block columns of it at the square of the game as it is played. The
  band draws the cart to its place in the new stockpile within half a minute. No place is planned
  where the cart stands and the columns its bed stood in are nobody's, so nothing made that
  ground level after: a hollow or a hump as deep as the fill or the cut round it (64 block
  columns a day later, two and three blocks under the floor at that square). The walking map lets
  one drop a metre and climb half, so a hollow of three blocks is one a serf can walk into and
  not out of; none was seen to. It is made level while the cart is in tow (`Level_Places`, by where the cart was
  lifted from, which is saved). `tools/square_sites.sh`, part 7, at three squares; with the mend
  cut it fails at two of them.

## Counted, from the gated code

(The runner's figures by one script, `final_measure.sh`, from a build of the sources as they were
committed, made before the commit; the game's own by the programs the gate built. Logs and scripts:
`releases/wip/logs_2026_11_23_stockpile_one_level/`, `releases/wip/scripts/2026_11_23_stockpile_one_level/`.)

**The game as it is played, 41 days** (`tools/today_run.sh 41`; beside it the same with
`--no-pile-flat`):

| | one level | each place by itself |
|---|---|---|
| living at the end, of thirteen | 13 | 13 |
| lines with "has died", "starving", "can't get there" | 0, 0, 0 | 0, 0, 0 |
| empty-belly member-hours (`tools/belly.py`) | 0 | 0 |
| its stockpile's ground at the end | all 1,598 block columns at 19.75 m | from 19.50 to 23.50 m |
| places that hold something with a block column off their level: third day; forty-first | 0 of 41; 0 of 15 | 0 of 51; 0 of 11 |
| open places with no way to them from the stake, at the end | 0 of 99 | 0 of 99 |
| hovels standing | 8 | 8 |
| the storehouse stood after | 16.21 days | 16.04 |
| salt stored; deer salted, not salted | 64 lb; 30, 0 | 61 lb; 30, 0 |
| the cart in the stockpile (first to tenth day) | at 1236.50 1067.50 | at 1239.50 1068.50 |
| the cart at the end | before the storehouse, at 1232.75 1050.25 | the same |
| midnights with more than three hungry, of 42 | 1, the first: ten hungry | 1, the first: six |
| feet more than a step off the walking map's floor, of 767,520 serf-seconds | 7 | 30 |
| standing still more than half a metre over one's own block column | 117 | 78 |
| more than a metre over it, moving or not | 316 | 367 |
| standing still in the ground | 9 s in 3 times, the longest 7 s, a block deep | 3 s in 3 times |
| the run took | 22.3 s | 22.2 s |

The log of the game as it is played is recorded again with this rule (state fb79e4cc482d0be5;
`main`'s was d5bb6e2fdd00202f, which this build gives with `--no-pile-flat`). **Read for who
lived before it was kept**: no death, no "starving", no "can't get there", nobody at an empty belly
at any hour mark. Ten are hungry at its first midnight where six were; over the sixteen runs of
the count below the hungry at the first midnight are 28 for 24 (8 for 7, 10 for 11 and this 10
for 6), and nobody is hungry at any later midnight of twelve days either way. Its three times of
standing in the ground are none of them on the stockpile's ground (a porter at the square's edge,
a hunter far to the north, a gatherer pulling vegetables); the three with the rule off are all on
it, a second each, at places being made level.

**58 stockpiles** (the same sixteen runs as the table above, the rule on; beside each figure the
same with `--no-pile-flat`):

| | one level | each place by itself |
|---|---|---|
| made one level where put down | 58 of 58, each from its ground beside a path | |
| deepest cut; highest fill | 18 blocks; 7 | |
| cut two metres or more; three or more | 7 stockpiles; 4 | |
| blocks moved | 96,710 (1,667 a stockpile; 14 needed none) | |
| block columns that waited for a tree to be felled or the cart to go | 139 of 93,025 | |
| bushes moved with their ground | 32 | |
| ground at one row, on the third day and on the twelfth | 57 (the 58th has one block column by the cart) | 14; a metre or more from lowest to highest at 28, twenty blocks at the most |
| block columns still to move, by the rule's own reading of each | 0 | |
| block columns left for good; places closed | 0; 0 | |
| front: all of it within two blocks of its path; half or more; none | 46; 56; 0 | 43; 54; 0 |
| places | 5,626 (31 stockpiles with their hundred; the fewest 74) | 5,585 (29; the fewest 59) |
| open places with no way to them from the stake | 41, each where the cart stands | 31, each where the cart stands |
| places that hold something with a block column off their level: third day; twelfth | 0 of 714; 0 of 877 | 9 of 761; 11 of 871 (four blocks at the most) |
| runs with someone dead; with a line "starving"; with "can't get there" | 0; 0; 0 of 16 | 0; 0; 0 of 16 |
| trees and stumps left in stockpiles on the third day | 0 (25 stood in them at each of the two squares in the wood) | 0 |
| a square's walls done (the six squares with any) | within an hour of the other way at each, with fewer stones (385 for 466, 188 for 534) | |
| standing still in the ground: three days; twelve | 70; 104 serf-seconds | 17; 258 |
| feet more than a step off the walking map's floor: three days; twelve | 345; 349 | 157; 158 |
| standing still more than half a metre over one's own block column, twelve days | 553 serf-seconds | 101 |
| more than a metre over it, moving or not, twelve days | 91 | 31 |

The last four rows, by who it was and what they were doing:

- **In the ground**, twelve days, one level: fifteen times in all (a scratch copy of the runner
  said whose ground each stood on). **Three are on a stockpile's ground**: a second each, one or
  two blocks deep, at the edge of two stockpiles of the square at 1172 1092, someone "looking for
  work". The other twelve are on nobody's ground (six), a square's own (three), a path (three);
  the long ones are among those: a gatherer two blocks deep for 34 s where the square's path was
  raised under him as he picked beside it, and a forester in a square's wall (below).
- **More than a step off the floor**: 275 of the 345 are one hunter standing idle where she had laid
  stone in a square's wall; the cell of the walking map she stands in has the wall's top for its
  floor and her feet are at her own block column's ground beside it. The same block columns with
  the rule off; nobody stopped there in that run.
- **Over one's own block column**: 553 serf-seconds for 101, and 91 for 31 more than a metre over
  it. One was read to the block: a porter gathering stone on the bank at the rim of the cut of ten
  blocks at the square at 1160 1090, from the fortieth second. He stands at 1165.99 1106.70 with
  his feet at 20.00 m for fifteen seconds; his own block column is the stockpile's, at 17.50 m; the
  next one north is outside it, at 20.00 m; the walking map's floor where he stands is 20.00 m. A
  cell of the walking map is two block columns each way and has its highest columns' height: here
  it is half bank and half cut (the stockpile's edge lies on an odd block column), and he is in
  the cut's half. So by the colony's count he stands 2.5 m in the air; how the game draws him
  there was not looked at. The others of this row were not read one by one. At his own stockpile:
  316 serf-seconds more than a metre over one's own block column in the 41 days, for 367 with the
  rule off. Not mended: it would mean moving a bank out to the half metre, which is ground
  outside the stockpile.

**The seams** of the round before (`colony_run --seam-stats`, eight layouts, sixteen days; pairs
of trodden block columns two blocks or more apart at the end): with the paths' two rules off 3,
0, 14, 8, 8, 0, 0, 0; with them, each place by itself, 0, 0, 0, 4, 4, 0, 0, 0; **with the stockpile
one level, the same**: 0, 0, 0, 4, 4, 0, 0, 0. The hovels standing at the end are the same in all
three, and nobody died.

**Orders given later** (`--later`): a second stockpile put down on the third day of the game as it
is played (`stockpile-box 1225.6 1058 2`), saved thirty seconds after and run on to the sixth day:
the straight run's state. A stockpile put down on the third day over the standing cart at three
squares, twenty days each:

| the square; the stockpile's level | block columns that waited for the cart | a day later | twenty days |
|---|---|---|---|
| 1238 1058; 17.50 m, a cut of two blocks and a fill of four | 160 | none off its level; the cart drawn to its place 2.5 m off | 13 living; 14 deer salted, none unsalted |
| 832 964 (the wood); 19.50 m, a cut of five | 45 | one, beside the cart at its new place | 13 living; 15 salted, none unsalted |
| 1172 1092; 16.50 m, a block either way | 158 | none | 13 living; 14 salted, none unsalted |

In each the log has four lines worded "starving" and eight to twelve empty-belly member-hours: all of
them in the two days before the stockpile is put down (a band with no stockpile; "nowhere to put
stone"), and the same to the figure with `--no-pile-flat` at the two squares run both ways (the
first two). The cart comes to stand elsewhere in the
stockpile than with the rule off (1237.50 1043.50 for 1236.00 1046.00, and 830.50 975.50 for 828.50
975.50).

**A stockpile already in a save stays as it was.** The save of the game as it is played made by
the build of the morning (`releases/playtest_notes_2026_11_23/saves/the_stockpile_at_breakfast_day_23`)
loads in this build and runs on twenty days: thirteen living, no line with "has died", "starving"
or "can't get there", the cart drawn to the storehouse and its salt carried in. Its stockpile is
not made one level: its ground's tops lie sixteen blocks apart at the end as at the start. With
the rule on, every open place of it is made level by itself within a second of the load, whether
anything lies on it or not (217 of its 1,598 block columns at another height half a minute after
the load than with the rule off): steps a metre square all over it. (Its one time of standing in
the ground in those twenty days, a block deep for 28 s, is a gatherer picking berries 23 m west
of the square.) **Only a stockpile put down anew is one level.**

**A one-level stockpile removed** (this morning's order; the game as it is played with no
storehouse, `--later 48 stockpile-box 1225.6 1058 2 --later 72 remove-stockpile 2`, eight days):
64 sheaves among what lay on it, gone 23.6 game hours later (23.3 with the rule off), thirteen
living, no line with "has died", "starving" or "can't get there", the cart on the other stockpile.
**The cut stays in the hill** when the stockpile is gone: nothing puts the land back.

**In the game** (the gated build's own programs; a real window; the tool's own click by the scripted
pointer, `--pointer "60:tool stockpile, 90:ground 1238.4 1070.4, 200:click"`, `--hitch 5 --mem
--hold-wait --frames 500`, nothing else running; three runs each way): the stockpile is put down
and made one level. **The frame of the click takes 28, 27 and 29 ms of the main thread** (22 or 23
of them the click's own work) **for 5, 6 and 5 ms** (3) with the rule off. The process holds
1,576,932, 1,579,044 and 1,582,924 kB at the end with the whole map held, for 1,574,772, 1,583,264
and 1,581,516 kB with the rule off: no difference (his ceiling is 4 GB). The same click in the
debug game, 420 frames: no assertion, nothing raised. The faces of the cut are whole (a still of
the far corner, by the build before the last change to the code: earth over rock, no hole).

**Water.**

- At his stockpile the same water is awake with the rule and without (12 stacks in each of the six
  runs above; none out of its sources: the game's own count at the end of a run).
- **A stockpile dragged down to a river's bank** (the river at 969 909; `--stake 968 924 --path 960
  920 978 920 --stockpile 963 919 973 909`, in the game, the water live): with the rule 74 places,
  its floor at 16.50 m, a cut of two blocks and a fill of seven beside the river; with the rule off
  67 places. Either way, and with no stockpile there, 12 stacks awake at the end, no water out of
  its sources and none of the river below its level.
- A pond in the made-up world keeps its water and its bank (`colony_check`; with the guard cut the
  bank is cut below the water and the check fails).
- **A pond the game poured, with the rule and without** (`--late --dig 1241 1071 21.0 1243 1073 24.0
  --puddle 1241 1071 20.5 1243 1073 22.0 0.5`: a pit two metres square on the hillside where his
  stockpile goes, 2 m3 of water in it, then the stockpile put down by the tool's click). With the
  rule off: 93 places, the pit and its water as they were (0.50 m deep at the end). **With the
  rule: 99 places, the pit cut away, its water over 365 block columns and all but 0.02 m3 of it
  gone by the end of the run.** With no stockpile put down the pond stays. (Why was not looked
  into; in the made-up world the same pond made of water blocks is left with its bank.)
- **Not tried: a stockpile cut beside a lake or a tarn below its water, with the water live.** No
  such site was sought out. The level is taken from ground beside a path, which is dry land, so
  the water would have to stand above the path side with the stockpile between.

## Found on the way

**Of this piece, mended in it**: the six under "Why each part is as it is".

**The measure, mended** (`tools/colony_run.adb`, `Is_Land`): each of the runner's measures had its
own list of what counts as ground, none with ore or a boulder in it. Where bog iron lies in the
turf the ground read a block low: at the reference stake 27 of 29 places read as having a block
column under their level, and none has. Now one list, the land whatever it is made of. **The
figures of the round before, taken again with it**: the places of the game as it is played (47
with 21 over and 26 under, 13 with 5 and 8; with the place-level rule none of 51 and none of 11)
and the seam table are the same to the figure. No figure in a merged document moved.

**A check that passed with the mend cut**: the tree on a knoll. The pillar under a felled tree is
cut by whichever comes first, the stockpile made level again where a tree of it is felled or the
tree's own place made level a second later. The check's second line is run with
`Set_Place_Level` off so that it has the first alone, and fails with it cut; its comment says so.

**Seen, not of this piece, not mended**:

- **A forester a metre deep for eighteen seconds at the square's wall** (the square at 1172 1092,
  aslant; "making the camp's ground ready"): stone of the wall is laid where he stands. With the
  rule off the same place has it for one second: it is who stands where, not the stockpile. The
  band's builders were moved off their work in the round before; the square's wall-layers were
  not.
- **`--puddle` pours nothing without `--late`** (the game takes the option and says a box was
  dug). Said in `docs/systems/water.md`.
- **A gatherer two blocks deep for thirty-four seconds** where the square's path was raised under
  him as he picked at a bush beside it (the square in the wood); the same class as the forester
  above: ground raised under someone at work on something else.

## What was run, and what could not show a fault

- `colony_check`, the section "a stockpile is one level", eleven lines: the rule against the game
  as it was on a made-up rise; the zone's own ground; a save loaded to the same bytes either way;
  a ledge across it, with the rule and without; rock, a boulder through the level, a boulder at
  it and bog iron; a pond; a broadleaf and a thick conifer on a knoll two metres high, felled from
  the floor; a bush on the rise. Guards proved by cutting: the boulder's block in the floor's top
  (two ways), the water's bank, the making level again when a tree is felled.
- Every rule of the round before and this one off: the log kept before that round, line for line.
  This rule alone off: `main`'s kept log and state.
- The awkward site, real places, the tool's click in release and debug, a band three days in (a
  second stockpile; a stockpile over the cart), saved half a minute after and run on, a save with
  the stockpile finished loaded and run on (the gate's own, on its twentieth day), every figure
  again from the last build by one script.
- **Not run**: live water beside a deep cut (above). `--no-place-level` with this rule on: the
  ground where the cart stood is then not made level (the once-a-second pass does it). The
  pointer's real input, as always.
- **Not tried: the six metres.** No check and no site has a block column further off its level
  than `Flat_Most_B` (none of the 93,025 at the 58; the deepest is eighteen blocks of the
  twenty-four). What the rule does there (leaves it, and closes the place) is as written, not as
  run.
- **Owed: two changes about the cart are not proved by cutting.** A block column the cart stands
  on is asked of before "something stands where the earth would go" (its bed's own blocks would
  have closed the place for good), and a place the cart reaches is no longer left out whole. The
  three squares of `tools/square_sites.sh`, part 7, pass with both and fail without the making
  level while the cart is in tow; neither of these two was cut by itself. And the comment at the
  second, in `Level_Places`, says it mended the sixty-four block columns left where the cart had
  stood: the run after it showed them still there, and the making level in tow is what mended
  them. (The comment is put right in the commit of the afternoon; the two changes are still not
  proved by cutting.)

## The gate

`tools/gate.sh 8ae4d75`, from a clean copy: **passed**, 54 minutes. Both builds from nothing with the
six known warnings and no other; the nine checks in debug (`colony_check` 1,121); the eight
reference logs line for line; the game as it is played, its kept log line for line and its state
(fb79e4cc482d0be5), saved on its twentieth day, loaded and run on to the same; the seventeen
stockyards, the three turned streets and the squares' sites, each in release and in debug (the
squares' with the stockpile over the cart: 160, 45 and 158 block columns waited for it); the
herds' places; the stress runner; the flora's hash the same in both builds. Its log:
`releases/wip/logs_2026_11_23_stockpile_one_level/`.

The commit after it is documents alone (this handoff, the state page, the logs of the stage and the
plan, and wording in `docs/conventions/stores.md`). `bin/` holds the gated build since 2026-11-23,
12:20; `tools/today_check.sh` passes from it.

## What he might take for a fault

- **The cut at the back of his stockpile**: four metres of bank at its far corner, bare earth over
  rock. It is what one level means on that hillside (his call 2).
- **A tree on a pillar of earth, or in a hollow, in a stockpile**, until the band has felled it
  (all 25 at the square in the wood were down by the third day).
- **A boulder gone** where a stockpile was put down over it, a patch of bare earth where it was cut
  through.
- **The cart stands three metres from where it stood before in his stockpile** (1236.5 1067.5 for
  1239.5 1068.5). Nothing of the cart is changed: it stands on the nearest two free places its
  bed fits on, and on a level floor a nearer pair fits.
- **Under the cart the land is as it lay** when a stockpile is put down over the standing cart,
  for the half minute until the band has drawn it to its place; one block column was still so
  beside its new place at one square of three.
- **Someone at the rim of a cut whose edge does not lie on the walking map's half metre** stands,
  by the colony's count, over the cut, in the air by the bank's height (above, "Over one's own
  block column"): 91 serf-seconds more than a metre up in twelve days at the sixteen sites, for 31
  with the rule off. At his own stockpile 316 in the 41 days for 367.
- **Someone stopped a block or two deep for a second at a stockpile's edge**, where its floor was
  filled over the land beside it: three times in twelve days at the sixteen sites.
- **A stockpile already in a save is not made one level**: loaded, its places are made level each
  by itself, all of them. Only one put down anew is one level.
- **The cut stays in the hill when a stockpile is removed.**
- **A pond he pours with the game's own test options** in a stockpile's box is cut away with its
  pit (above, "Water").

## What it costs

One frame of 27 to 29 ms where a stockpile is put down (5 or 6 without the rule). No memory. The
41 days of the game as it is played run in 22.3 s for 22.2. The gate has one part more (three
runs of three days in `tools/square_sites.sh`, and each saved and run on).

## His calls

1. **Merge `stockpile-flat`?** It stands on `main`: a fast-forward of the commits of this piece.
2. **The level: its path side's (built), or its middle?** By its path it is walked into from its
   path (all of its front at 46 of the 58, half of it or more at 56, some of it at every one), and
   on a hillside the back is cut deep: four metres at his own. At the middle
   of all its ground the cut is half as deep (nine blocks at his) and the floor stands a metre to
   two over its path, with no way in at four of the 58 without a stair. Default: as built.
3. **A boulder in a stockpile: cut away with the rest (built), or left standing?** The square
   leaves a boulder standing and is made round it. Left standing in a stockpile it stood on a
   plinth of its own earth with the places over it closed (ten of the 58 stockpiles, 73 places),
   until the band had prised it away. Cut away, its stone is nobody's. Default: as built.
4. **Banks of bare earth (built), or walled with stone as the square is?** I had told him there
   would be walls. Not built: a wall wants stone and somebody to lay it, and the square's and the
   stockyard's walls and stairs are the pattern. Default: as built, the bank as cut.

His third answer stands untouched: the removal of the only stockpile is as it was.

## His answer (2026-11-23, afternoon), and what was done on it

> let's do this, let's go back to the stepped version, not the cut one, let's block the players
> placement if it's too steep, let's say anything where a part is over 1/2 slope,
> /home/bythergig/CASTLE_GAME/GAME_alpha_1_3/compiled/docs/design/Voxel_people_brief.md, I have added
> this and there are model refrences I purchased in the docs/refrences, that is the general shape I
> want to make our serfs, if you need me to install packages so you can see them let me know, if you
> have any questions let me know. then merge

| his words | read as | done |
|---|---|---|
| "let's go back to the stepped version, not the cut one" | calls 2 to 4 fall away: no stockpile is made one level | `Set_Pile_Flat` is **off by default**; `--pile-flat` gives the rule (kept, with its checks; nothing of it is taken out). The game's stockpiles are `main`'s again: the kept log of the game as it is played is `main`'s, line for line and to its state (d5bb6e2fdd00202f) |
| "let's block the players placement if it's too steep, let's say anything where a part is over 1/2 slope" | a stockpile is refused where some part of its ground rises more than half a metre over a metre | `Set_Steep_Refuse`, `--no-steep-refuse` (below) |
| the brief, the bought models, "that is the general shape I want to make our serfs" | the piece his brief describes, opened: on a branch of its own from `main`, step by step as the brief has it, each step shown to him | its own handoff |
| "then merge" | `stockpile-flat` is merged once the two changes above are gated. **Not read as: the serfs merged unseen** (his brief: "Nothing is merged without his word, as ever", each step "shown to John with stills side by side") | `main` fast-forwarded; the hashes are in `State.md` |

**The refusal, as built.** Some part of the ground the stockpile would take rises more than two
blocks over a metre along the block grid, either way (two block columns of its ground four apart);
or a ledge lies in its lot (two neighbouring block columns more than half a metre apart, where as it
was the stockpile ended). A boulder and a tree's foot are not counted. Refused whole, dragged or put
down whole; the pointer says "the ground is too steep for a stockpile there (some of it rises more
than half a metre in a metre)". Not asked of the stockyard.

- **"Over 1/2 slope" has two readings.** Built: along the block grid, each way by itself, which is
  also the step a serf climbs between two places a metre apart. The other: the true fall of the land
  whichever way it runs (a hillside falling 0.4 each way along the grid falls 0.57 aslant). Not
  built. **Counted in a scratch copy** (the two rises of a block column over a metre, squared and
  added, against two blocks squared): it refuses 10 of the 58, **his own among them**; on ground of
  whole blocks a rise of two one way and one the other is already over. His to say.
- **Counted** (the 58 stockpiles of this handoff): 2 refused, both at the square at 1010 890. **His
  own is taken**: its ground rises four metres across the ten of its box, about one in three by
  the diagonal, and as steps a metre square it is what the sheet's right-hand pictures show.
- `colony_check`, "a stockpile is refused on ground too steep", five lines: a rise of half a metre a
  metre taken; three quarters refused, dragged and put down whole; a ledge three blocks high
  refused; a boulder on a gentle rise no slope. With the planner's test cut three of them fail.
- **In the game**, the tool's click over a pit dug into his hillside where his stockpile goes: "no
  stockpile there", the reason at the pointer. (No ground the tool's own facing reaches near the
  squares tried is refused as the land lies: a pit was dug to see the pointer's words.)
- **On ground the band has worked** (the later orders of this handoff, at the defaults): a second
  stockpile on the third day beside the dug square, 99 places; a stockpile over the standing cart
  at the three squares, 92, 100 and 94 places, thirteen living after twelve days; the removal with
  another to carry to, gone after 23.3 game hours. None refused.
- **The saves made by the one-level build** (`releases/stockpile_one_level_2026_11_23/saves/`, the
  third day and the thirtieth) load at the defaults and run on twenty days: thirteen living, the
  cart before the storehouse. Their stockpile stays one level: it is in the save's ground.
- **The gate** on 6c118a2: passed, 55 minutes; `colony_check` 1,126; the game as it is played is
  `main`'s kept log and state again (d5bb6e2fdd00202f), saved on its twentieth day and run on; both
  runs of the squares' sites say "2 of the 56 refused, their ground too steep". Its log:
  `releases/wip/logs_2026_11_23_stockpile_one_level/gate_6c118a2.txt`. `bin/` holds that build.

## Not done

- A wall or a stair at a stockpile's bank (call 4).
- Live water beside a deep cut (not run).
- The horses for the cart and how the colony arrives: his to open (`State.md`).

## Next

(Of the afternoon.) The voxel people, on branch `voxel-people`, wait on his two calls there; the
arrival is his to open. A session starts at `docs/production/State.md`.
