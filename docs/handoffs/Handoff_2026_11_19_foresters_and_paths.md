# Castle Game handoff (2026-11-19: foresters with no tree in reach, and paths straight or at 45 degrees)

The round before it is `Handoff_2026_11_19_answers_round.md` (his eight answers). This is what he sent
after it. Everything is on branch `stockpile`, not merged; `main` is 537176c. No merge word was given.

## John's words, whole

> Still having issues with the foresters not finding trees in range, we need to do something about the
> paths being at slight angles, I think we need to lock the paths to straight and 45 degree angles,
> slighty being off doesn't really work in a voxel world, then we can start planning structures on that
> design pathway, keeps things tight and simple

Taken as:

- **"Still having issues with the foresters not finding trees in range"**: a fault. Reproduced first,
  below. No earlier report of his names foresters (his notes of 17 November name hunters and
  gatherers): "still" was read as the same kind of fault, not as one already worked on.
- **"lock the paths to straight and 45 degree angles"**: built.
- **"then we can start planning structures on that design pathway"**: his next topic. Nothing built;
  what the build does today beside such a path is shown and put to him ("His calls").

There is no save of his playthrough (`saves/quicksave.castle` holds no colony), so his own site was not
seen. The fault was made in the runner two ways.

## The foresters

### Reproduced

`colony_run --tree-stats` (new, kept) counts the trees standing by how far from the stake they are, and
each forester's hours by what its status said.

- **By playing on, at the reference site** (the band of thirteen with housing, the stockpile and the
  stockyard). 115 trees to fell stand within 60 m of the stake, 189 more 60 to 80 m off, and 11 apple
  trees. Nothing grows back. By the hundred and thirtieth day none is left within 60 m; from then on
  the foresters said "no trees to fell in reach" (1,232 serf-hours), no log was in the stores, nothing
  more was burnt, and by the hundred and sixtieth day all thirteen had died of hunger, with 189 trees
  standing 60 to 80 m from the stake.
- **By where the stake is put** (seed 1, stake 1000 900: open land by a river, the wood past it). Five
  trees to fell within 60 m, three of them across the river; ten apple trees; 44 to fell 60 to 80 m
  off. In twenty days the foresters felled two trees and stood 752 serf-hours saying "no trees to fell
  in reach" (and 61 "can't get there"); three hovels stood at 13 % of their frames, "waits for wood",
  for the whole of it.

Three things said "no trees to fell in reach" with trees in sight, and the status did not tell them
apart: trees past 60 m of the stake (work is looked for within `Work_Radius_M` of the stake, not of the
forester); apple trees, which are spared by a standing order; and trees there is no way to (after a
failed try the tree was passed over for a minute and the reason overwritten).

### Built (`Set_Wood_Reach`, `--no-wood-reach`; colony blob 33)

- **A forester with no tree left to fell that it can get to looks a ring further** (16 m), and
  another, to 124 m from the stake at the most (`Fell_Reach_Max_M`: the work radius and four rings; a
  first value). How far they look now is `Fell_Reach_M`; it never comes back in, since nothing grows
  back. The colony's ground and what it looks through reach as far. Among the trees in reach the
  choice is as it was (the way there and half the way from the stake), so the nearest are still felled
  first. A tree somebody else is felling is no reason to look further.
- **A tree there is no way to costs a look, not a search**: its way is asked of the walking map's
  pieces of ground alone, and it is then nobody's to try for an hour (`Tree_No_Way_S`). At the
  open-land site 304 of the 592 trees to fell within 124 m cannot be got to from the stake at all.
- **A tree that can be got to only by a long way round is left too** (`Fell_Budget`, 16,000 floors of
  search; left for a day, `Tree_Round_S`). Found in the same run: before it, 20 of 37 ways planned
  to a tree were to one about 70 m off and 310 to 340 m round by a ford, 60 ms a search, and as far
  again with each log; in twenty days the foresters were hungry 133 serf-hours carrying. With it,
  19.
- **The reason is said**: "can't get to the trees left in reach", "the trees left in reach are being
  felled by others", "only apple trees stand in reach, and they are spared", "looking further off for
  a tree to fell"; "no trees to fell in reach" only when there are none.

### The same runs after

| | as it was (`--no-wood-reach`) | now |
|---|---|---|
| reference site, 185 days: living at the end | 0 (all dead by day 160) | 13 |
| the same: logs in the stores from day 135 on | 0 | 21 to 31 |
| the same: foresters' serf-hours "no trees to fell in reach" | 1,232 | 0 |
| the same: how far the foresters look at the end | 60 m | 76 m |
| open-land site, 20 days: trees felled | 2 | 39 |
| the same: hovels standing | 0 (three at 13 % of the frame) | 3 |
| the same: logs in the stores at the end | 0 | 33 |
| the same: foresters' serf-hours "no trees ..." or no way | 813 | 8 ("can't get to the trees left in reach") |
| the same: the colony's steps, seconds of computing | 26.8 | 33.4 |

One run each. **Why the band without wood starved was not looked into**: in both runs the stores ran
out of food at the end of that third winter (with the change all thirteen were hungry on its last day,
and lived).

The eight reference logs are line for line with `--no-wood-reach` (as the scripts now run them) and
with the foresters looking further as well, and so is the band of thirteen's 41 days at the reference
site: where trees stand near, nothing moves.

## Paths straight or at 45 degrees

### Built (`Castle.Actions.Path_Snap`, `--no-path-snap`; nothing saved)

- A path is ordered along the nearest of eight ways (east, north east, north ...), a whole number of
  blocks long, begun on a corner of four blocks. Its sides fall on block edges: **four blocks across
  all along when straight; at 45 degrees five, its edge a step a block.**
- A line begun on a path begins on that path's middle line; begun by a path's end, at that end. A line
  drawn up to a path ends on its middle line. A line pointed at where it begins (nearer than half a
  metre) is no line: a second click on the same spot lays nothing.
- **The line shown while it is drawn is the line that will be laid** (one pair of functions:
  `Castle.Colony.Path_Line_Start`, `Path_Line_End`; the order, the tool and the scripts' `--path` all
  go through `Castle.Actions`).
- `Castle.Colony.Lay_Path` itself lays whatever line it is given. **Paths already laid lie as they
  lay.**

### What stands beside such a path today

Looked at, not changed (stills, flat ground west of the reference stake, eleven days):

- **A hovel is never turned**: it stands square to the blocks whichever way its path runs. Beside a
  path a little off straight (as before) the hovels are set back unevenly, the path's edge steps at
  odd places and the zone's edge is ragged.
- **The same order now** gives a straight path, a zone with straight edges and the hovels in a line:
  six stand either way.
- **Beside a path at 45 degrees** the zone's edges are clean diagonals; the hovels stand square to
  the blocks, stepped back along it, each with its own short way to the path. **Fewer fit**: the two
  strips had room for three hovels and one (four standing), where the same length along a straight
  path had three and three. One layout.
- **A stockyard beside a path at 45 degrees is taken only where a corner of its box comes to the
  path** (its lot is square to the blocks, and its storehouse has to stand within 2 m of the path):
  on the flat south west of the stake two boxes of five tried were taken, and the storehouse of one
  stood in eighteen days. **On the hillside east of the stake none of ten boxes beside the
  45-degree line was taken**, where the line as it used to be drawn (35 degrees) took one. The gate
  found this: the hillside site was first run at 45 degrees and its stockyard was refused.

## Saves

A run at the open-land site saved on its tenth day (trees left untried in it) and loaded for ten more
ends in the state of the straight twenty days (526257bcd59820f9).

Colony blob **33** (how far the foresters look, whether they look further, the trees left untried).
**Blobs of 30, 31 and 32 are still read**: a colony saved by this morning's build loads, its foresters
looking further when they have to.

## Checks

`colony_check` 790 (it was 767): the foresters (as it was with the switch off; a ring further and both
trees home; saved and loaded to the same bytes; each of the four reasons said; a walled-in tree not
asked every thought; a save with that tree left untried loaded and run on to the colony that was never
saved), a blob of 32 loaded, and the paths (two thousand lines pointed any way: each
exactly one of the eight ways, on corners, and given back as it is when given again; four blocks
across; five at 45 degrees with a step a block; begun on a path and drawn up to one; no stub from a
click twice on one spot; the switch off).
`tools/stockyard_sites.sh` has a third site: a stockyard beside a path at 45 degrees on the flat south
west of the stake (the first is the slant the pit was found on, kept with `--no-path-snap`).

## Gate

Gate 54, from a clean copy of 498002c (the last commit that changes code): both builds from nothing
with the six known warnings and no error; the nine checks in debug (water_sim 77, edit 41, ui 112,
dynamics 18, serf 19, path 70, **colony 790**, deer 14, pick 59), none failing; the eight reference
logs line for line; the stress runner, nothing died and nothing dropped; the flora hash unchanged
(5676219328934879273 in both builds).

**`tools/stockyard_sites.sh` failed in that gate at its new site**, as it then was: the hillside
stockyard beside its path at 45 degrees was refused (no pit: the stockyard was never zoned). The script
as it is now (88d3be2: that site on the flat) was run in the same clean copy and passes all three.
Gate 53 before it, of a3e2c73 (before the count of trees left untried and its check), passed and
failed the same way.

The stress states moved again with the blob: six_4_years 11e49539d1f6fcbf, six_41_days
ca8e98c2bbc21715, housing 6bc1316934a5e6d0, crowd_as_it_is dde2b113b95b2fc4, crowd at work
a439cc0983ebd1ee; each case agrees with its own variants. The eight logs are what says the behaviour
did not move.

## His calls (first values of mine)

1. **At 45 degrees a house stands square to the blocks, stepped back from the path, and a stockyard
   is taken only where a corner of it comes to the path.** Should they stand along the path instead
   (their walls then stepped a block a block), or are houses and the stockyard kept to straight
   paths? This is the question the next pass turns on.
2. **A path's line on corners of blocks** (a quarter metre). A coarser grid (a metre: every path then
   meets a stockpile's places and a lot's edge exactly) is a small change.
3. **How far a forester may go for a tree**: 124 m from the stake now. Your rule for the camp's stone
   had no limit ("if they have to walk 200m to get stone they walk 200m"). Each log is carried home
   by itself, so far trees are slow wood.
4. **Trees do not grow back.** With the reach the band lasts longer on a site; it does not last for
   ever. Whether a felled tree comes again is a design of yours.
5. **Gatherers and hunters have the same limit** (bushes within 60 m of the stake; vegetables to 80 m
   when short; deer by the herds' range round the stake). Not changed. Should they look further the
   same way?
6. **A tree only reached by a long way round is left** (the search for a way is given 16,000 floors).
7. The calls of the rounds before stand open as they were.

## Known limits

- His own site was not seen; which of the three causes he met is not known.
- Trees past 124 m, or across water, are still out of reach, and the status says which.
- A forester far out comes home with each log: at the open-land site the foresters were at carrying
  and fetching logs 150 serf-hours of twenty days.
- Found on the way, not mended: **a path drawn into a river has a last metre nobody can lay**, and the
  way to it was searched for again and again (45 ms a search, 2,136 times in eight days: 89 s of
  computing for those eight days, against 26 s for twenty with the path kept out of the water). And at the open-land site others of the band asked the way to things across
  the river some 40,000 times in twenty days (bushes, by the look of it: not looked into).
- Paths: an end is on a corner, not on a whole metre. A long line at 45 degrees is kept in stretches
  whose joints are not on corners (the line is; a line begun at a joint begins on the nearest corner
  of the line).
- Nothing of the real pointer's path could be driven here: the stills were taken with a scripted
  pointer (the ground's menu, "Path from here", the pointer moved; and a second leg drawn on from the
  first one's end after a click). "Path to here" in the menu and Esc were not driven.
- On the hillside a line of 51 m at 45 degrees was planned as 470 blocks where one of 42 m on the flat
  was 606: the same count with `--no-path-snap`, so it is the ground there (what the runner holds, or
  what is not earth), not the line.

## Test windows and input

Stills in short windows of mine, each only when `pgrep` found his game not running. All input
scripted. Nothing pushed. The sheet is `~/CASTLE_GAME/releases/foresters_and_paths.png`.
