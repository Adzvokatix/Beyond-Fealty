# Castle Game handoff (2026-11-21: the square thirteen metres with its path, a special zone's area first, the stockyard twenty metres, a larger storehouse nearer its path, food and barrels stacked)

The round before it is `Handoff_2026_11_20_placements_with_paths_and_the_square.md` (its "Next (in his
order)" has where that stood: branch `stockpile`, its code d53ba6f's, gate 74 passed, nothing merged;
`main` is 537176c). Everything here is on branch `stockpile` too. **No merge word was given** ("Great
job, I like what I see" is praise).

## Where it stands now (2026-11-21, night; read this first)

Branch `stockpile`, **nothing merged** (`main` is 537176c; he has given no merge word). On top of
gate 82's code: the square's stair back at the middle of its side (a1d43b2), **the stockyard's stair
in a corner of the zone (757c2d0: gate 83 passed)**, and after it the rule held to a levelled
stockyard with the tools for the square's path (e20ed8d: **gate 84 passed**, below); then documents
only. `bin/` holds e20ed8d's build, release and debug (copied from gate 84's own clean build with
`pgrep -x castle_game` empty, one file of each compared after). **In a scratch tree only**: the mend for the jumps in the square's path
(its patch in `releases/wip/`), and the hearth before the whole floor (its patch there too).

**Gate 83** (757c2d0, from a clean `git archive` copy, `$S/rungate83.sh`): both builds from nothing
(6 warnings, all `water_sim_check`'s); the nine checks in debug, `colony_check` 1025; the reference
logs line for line; the stockyard's fourteen sites in release and debug (each with where its way in
is, no pit); the turned streets in both; the square's sites in both (323 squares, 55 stairs each at
the middle of its side; the fourteen awkward sites 40 member-hours with an empty belly; the sloping
square eafd146fcd25809a, gate 81's); **the stress runner's fifteen states gate 82's, every one**
(six_4_years 0f6e9ac3e04d59fc, six_41_days 42613bf288a4dc5e, housing_41_days d08378f42ca99dab,
crowd_as_it_is 21aaf5d3e27b4213, crowd_at_work 604d849343d51d27); flora 5676219328934879273.

**Gate 84** (e20ed8d, from a clean copy, `$S/rungate84.sh`): both builds from nothing (the six known
warnings); the nine checks in debug, `colony_check` 1026 (the check with the stockyard's levelling
off among them); the reference logs line for line; the stockyard's fourteen sites and the turned
streets in release and debug; the square's sites in both (55 stairs each at the middle of its side;
40 member-hours with an empty belly at the fourteen awkward sites; the sloping square
eafd146fcd25809a); the stress runner's fifteen states gate 82's, every one; flora
5676219328934879273.

**His calls open** (none answered; each stands at what is built):
1. **The square's path** (his words of the late evening): the mend tried is in a scratch tree; the
   ways are in the section below. Default: a block a quarter metre where the levelled stretch ends.
2. **A stockyard whose far corner lies over 2 m off its floor** (the hillside test sites, with the
   storehouse of before): no stair now, the level end is the way in; or a longer flight.
3. **The floor's level is still held to the three steps that fit before the storehouse**, which a
   stair in a corner no longer needs: some of the 115 sides refused today would take a stockyard
   (not counted, not built).
4. Of two banked corners the lower, and of two as high the nearer the homestake (mine).
5. The square's corner rule: kept off behind `--square-stair-corner`, or taken out.
6. From the reports before: the hearth before the whole floor (recommended; scratch only); what
   should fail a gate; the stockyard's walls; the storehouse's size, its distance aslant, the
   stacks' heights.

**Owed**: the lord's cart not brought before the storehouse at two of eight squares' stockyards, by
both rules (seen in the band's runs, not looked into); a route that ends short planned anew after a
load; the holder of a bush two are picking; the advisor's note for an older save's stockyard; tall
grass drawn in another pose in two saves; the 20 sides with no way from their path's middle.

## His words of 2026-11-21, late evening: the jumps in the square's path (the newest; sent while the stockyard's stair was in hand)

**His words, whole:**

> we need to do something about having the .5m jumps in the path around the square too.

| clause | his words | read as | state |
|---|---|---|---|
| a | "the .5m jumps in the path around the square" | The path round a square is brought to the floor's level a quarter metre of its length at a time, where all of that slice lies within half a metre of the level (`Path_Level_B`, 2 blocks), and left as the land lies where it does not. Where the levelled stretch ends, the path steps two or three blocks at once: half a metre and more. | **Counted** (below): 272 such steps on 192 sides of 71 of the 323 squares, 258 of them where a levelled stretch ends. |
| b | "we need to do something about ... too" | A fault he names with no mend named: mine to propose, measured, and his to choose. "Too": beside the stair's place. | **A mend tried in a scratch tree, not in the repository or `bin/`** (below): its numbers, its stills and the ways put to him. |

### The jumps in the square's path: counted, and a mend tried (2026-11-21, night)

**The count** (`colony_run --square-scan 100 20 --square-path`, new: each side's path read a quarter
metre at a time as its own stretch is laid, `Castle.Colony.For_Square_Path_Slices`; the ten places,
323 squares made on the spot with their paths and walls, 1,292 sides, 63,127 quarter metres of path,
57,540 of them all at the floor's level): from one quarter metre to the next the path steps a block
at 711 places, **two blocks at 208 and three at 64, never four**; those 272 are on 192 sides of 71
squares (252 squares have none). **258 of the 272 lie where a quarter metre at the floor's level
meets one that is not** (the end of a levelled stretch: his jump); 7 within a metre and a quarter of
a side's end, where two sides' paths meet; 7 elsewhere, the land's own. 157 quarter metres have two
blocks or more between their own columns, across the path (a bank through its width, in stretches
left as the land lies).

**The mend tried** (the patch `~/CASTLE_GAME/releases/wip/path_steps_trial_on_the_stockyard_stair.patch`
on the head; the scratch tree `$S/ptrial`, its runners `$S/keep/colony_run_p6` and, with the
re-laying below, `colony_run_p7`; `Set_Path_Steps`, `--no-path-steps`): **where a levelled stretch ends, the path steps to the land a block a quarter
metre**. The slice next to the last level one is brought to one block off the floor's level, toward
the land's side of it, the next to two, and so on while the land's middle there lies at least that
far off and every column of the slice is within half a metre of that row; a slice is stepped whole or
not at all; the level stretch itself is not touched, and no column moves more than the half metre
it could move before. All of it in `Lay_Metre` (`Read_Steps`, after `Read_Slices`). The walls go by
the path as laid, as ever (a bank of a block beside a step has no wall; the strip before it is
capped at the step's level).

- **Made on the spot, the ten places**: steps of two blocks or more **27 for 272** (26 of two, 1 of
  three), on 24 sides of 23 squares for 192 of 71; **at a levelled stretch's end 11 for 258**. What
  is left there: slices whose own columns lie too far apart to be brought to one row, and corners.
- **By the band** (23 squares, six days, `$S/pstep.sh`): steps of two blocks or more 8 for 74;
  nobody dead, no pit, nothing of the walls left to lay by either; member-hours with an empty belly
  213 for 229.
- **Why it is not in the repository: what is laid depends, a little, on who lays which metre
  first, and that is so of the path as it is.** The same 323 squares with their paths laid last
  metre first (`--paths-backward`, new; the same reader for every figure here): **as it is**, 272
  jumps both ways, but 57,528 level quarter metres for 57,540 and 261 of the jumps at a level end for
  258; **with the mend**, 26 jumps for 27, 16 at a level end for 11, 57,529 level quarter metres for
  57,540. **Where the two orders differ** (each side's line of the forward scan against the backward
  one's, 1,256 sides read in both): as it is, 41 quarter metres on 35 sides of 26 squares, **every
  one within the first or last metre and a quarter of a side**, where two sides' paths meet; with
  the mend, 116 quarter metres on 60 sides of 35 squares, 114 of them there and 2 further along. So
  the order matters at the sides' ends today, and the mend makes more of it. And the band's path
  stands otherwise than the one made on the spot at 6 of the 23 squares
  as it is and at 7 with the mend (**not sorted by cause**: at one of them it is something lying on
  the level path in both arms, at another the difference is at the middle of a side, at others by a
  side's end). The mend reads its neighbours' state from the ground (a slice already laid is level
  only at the floor's level; one laid all at one row K blocks off it, K slices from a level one, is
  a step laid before); a slice whose level neighbour could not be read when its own metre was laid
  keeps its jump.
- **Tried on top of it: the steps beside a level slice made again when a neighbouring metre is laid**
  (laid ground re-laid; in the patch): made on the spot 21 jumps for 27 (7 at a level end for 11),
  laid backward 26 (12); by the band at the 23 squares 7 for 8. **It does not make the order
  matter less**, and it takes 13 quarter metres out of the level stretches (57,527 for 57,540: it
  re-lays ground the other side's stretch had laid level where the two cross), which the mend
  without it does not.
- **It has no check, no debug run, no gate, and has not been tried from a half-laid save.**

**The ways, put to him** (the first is the default I would build):

1. **A block a quarter metre where the levelled stretch ends** (tried): three short steps of earth
   in the path. It leaves about one jump in ten (27 of 272 made on the spot). Before it is built
   I would settle what a quarter metre is laid as where two sides' paths meet, so that the path
   comes out the same whoever lays it: every one of the 41 quarter metres that differ by the order
   of laying today lies there.
2. The same, a step every half metre or every metre: longer and gentler, more earth moved, the path
   a block or two off the land beside it for that length.
3. The steps of stone, as a stair's are (his "stairs built on the path from stone as it rises or
   falls", 2026-11-12, of a door's way): the wall builders' work, not the path layers'.
4. Bring more of the path level (a metre off, not half): the jump moves to where that ends and is
   higher.

The sheet: `~/CASTLE_GAME/releases/square_path_jumps_tried.png` (the stand-in's square, made by the
band in six days: the west and the south side as they are and with the mend).

## His words of 2026-11-21, evening: the stair was the stockyard's (read this second)

Sent in answer to the report of the square's stair in its corner. **His words, whole:**

> No let's go back to square stair middle, I was talking about the stockyard having the stair in the
> corner rather than the middle.

**The retraction this makes** (said, did, does now). *Said*: that his words of the afternoon ("The
path level at one corner is great, move the stair to the opposite corner instead of the center, if a
stair is to be had it's to be at the corner of the zone") answered the old call 1, a square's stair,
and that the stockyard's stair was a call to put to him. *Did*: moved the square's stairs to its
corners (e25f730, 7a13338, gate 82) and left the stockyard's at the middle of its storehouse's front.
*Does now*: the square's stair stands at the middle of its side again, and the stockyard's is the
piece in hand. Nothing told what he was looking at (no screenshot, no zone named); the reading was
taken from which zone had a stair at a middle and a level corner in the sheets sent, and the
stockyard had both in his game. The lesson is in the memory: **a message that names no zone, where
two zones fit, is put to him as the first line of the report before the larger of the two is
built**, or the one that is cheaper to undo is built first.

| clause | his words | read as | state |
|---|---|---|---|
| a | "No let's go back to square stair middle" | The square's stair at the middle of its side, as the build he had (7505b5f) has it. The corner rule for the square is not wanted. | **Done** (the commit of this section): `Set_Square_Stair_Corner` is off unless told otherwise; `--square-stair-corner` turns it on, `--square-stair-middle` is still read (he was given that word). The sloping square ends in gate 81's state again (eafd146fcd25809a). Not taken out of the code: his to say. |
| b | "I was talking about the stockyard having the stair in the corner rather than the middle" | The stockyard's stair is the flight of its way in from its path, at the middle of its storehouse's front. It is to stand at a corner of the zone. With his words of the afternoon read of the stockyard: where the path comes in level at one corner of the front, that is kept as it is, and the stair stands at the other corner of the front; a stair anywhere stands at a corner. | **Built** (the section below), switch `--yard-stair-middle`. |

**What falls away**: the five calls of the afternoon's report about the square's corner rule (a stair
beside a level way in; "the opposite corner" of a square; the three things of mine; the cap). The
stockyard's stair, its call 2, is answered. **Still open, at their defaults** (he has answered none):
the four of the report before (the hearth before the whole floor; what should fail a gate; the
stockyard's walls; the storehouse's size, its distance aslant, the stacks' heights).

### The stockyard's stair in a corner of the zone: counted, then built (2026-11-21, evening)

**What it was.** A stockyard's floor is level; its path follows the land. Its way in was two metres at
the middle of its storehouse's front, across the staging, with steps wherever the path lay more than
a block off the floor there (three at the most in the metre and a half before the storehouse of 12 m
by 8 m). The storehouse's doors are in its ends.

**The count first** (`colony_run --square-scan 100 20 --yard-census --yard-walls`; a new reading,
`Castle.Colony.Stockyard_Front`: the path's ground against the floor at the two ends of the front and
at its middle). The ten places, 1,292 sides, **828 stockyards taken, 713 with no steps, 115 with
steps at the middle** (as counted at noon). Of the 115:

- **60 have the path level at one front corner** (within a block of the floor) **and a bank a stair
  can stand against at the other**: 2 blocks at 11, 3 at 15, 4 at 15, 5 at 10, 6 at 3, 7 at 6. His
  words fit these as they stand: the stair to the opposite corner.
- **54 have a bank at both corners**: the lower of the two is 2 blocks at 35, 3 at 16, 4 at 2 and 6 at
  1 (both corners over the floor or both under at 47; one over and one under at 7).
- **1 has the path level at both corners** and a hump at the middle alone.
- None has a corner more than 8 blocks (2 m) off its floor.

**The rule as built** (the spec, "The stockyard's stair in a corner of the zone";
`Set_Yard_Stair_Corner`, `--yard-stair-middle` is as it was; not saved; `Choose_Way_End` in
`Try_Lot`):

- **The floor's level is chosen as it was**, by the land under the stockyard and by the path at the
  middle of its front. So the same places take a stockyard, at the same level (828 of 1,292 by both
  rules, the plan and the click agreeing at every one).
- **A stockyard with no steps at that middle is as it was** (713 of 828; seven of the script's
  eleven sites end in the same state by both rules).
- **One that would have steps there has its way in at an end of its front instead**: two metres wide,
  a block column in from the side's rim (the rim, walled where the land beside it stands over or
  under, is the stair's outer flank), a block a step from the path's edge inward, as many steps as
  there are blocks between path and floor at that end (2 to 8), a landing at its foot. **Beside the
  storehouse's end no wall stands across it, so a flight longer than the staging is deep runs on
  past the line of the front wall** (37 of the 114 stairs have four steps or more; squarely, where
  the staging is six block columns deep, such a flight's landing lies past that line, and a flight
  of seven its last step). The middle of the front is then rim like the rest: stone where the path
  lies more than a block off.
- **Which end.** One end level and the other taking a stair: the other, the opposite corner. A bank
  at both: the lower (the shorter flight); of two as high the end nearer the homestake by a metre
  or more, else the end the design counts from (**mine, his to change**). One end only takes a
  stair: that one. **An end level and no end taking a stair: no stair**, the way in is the level end.
  Neither end level nor taking one (the path does not reach them, or lies over 2 m off at both, or
  the flight has no room): the way and its stair stay at the middle (none at the ten places).
- What follows the way in: the levels, the plan of each column, the footpath, the order its ground is
  dug in (down the stair, then outward from its foot: `Yard_Order`), the patches (`Patch_Of` counts a
  yard whose way is at its high end from that end, so the stair's patches hold nothing beside the
  way there either). What stays at the middle of the storehouse's front: the lord's cart's place,
  the ladder's, the place a razing is done from (`Mid_Lo`, `Mid_Hi`).
- **A storehouse keeps the way it was begun with** (`Castle.Buildings.House.Way_End`): two more
  values (4, 8) in its byte of blob 41, **no new version** (every state of a colony without such a
  stair is byte for byte what it was; the build before reads a blob that has one as a bad save).

**What came of it at the ten places**: the way in of 63 is at the low end of the front and of 52 at
the high end; **114 stairs** (the one that is level at both corners has none): 48 of two steps, 29 of
three, 20 of four, 6 of five, 5 of six, 6 of seven. 365 steps in all for 296 (3.2 a stair for 2.6:
the far end from a level corner is the higher end; the longest 7 for 6). Fewer block columns of
steps (2,988 for 6,728: a flight is as long as its steps, where the way across a staging of 3.5 m
was all steps) and **less stone in all the stockyards' ground: 123,041 blocks for 126,866.**

**Built on the spot at all 115, by both rules, and scanned** (`--yard-built`: the square, its path
and its walls made first, as a band three days in has them; then the stockyard put down, its ground
and storehouse raised, its yard laid as a builder lays it; every half metre of its ground and 2 m
round it tried from the fire and back; the land put back between one and the next): **no pit with
the stair in the corner** (0 of 342,430 spots; with the stair at the middle 2 spots, at two
stockyards), a way from the fire to the middle of the storehouse's floor and back at every one.
**That way is shorter at 35, longer at 21 and the same at 59**: 43.3 m there and back on the mean
for 44.9, the longest 61.1 for 65.2 (the most it grew 15.4 m, the most it shrank 20.2).

**The band, eighteen days, thirteen people, eight of those stockyards** (the longest flights, up and
down, squarely and along a path at 45 degrees; a stockpile on another side; `$S/ystair.sh`, kept in
`releases/wip/scripts/`): all sixteen runs end with the storehouse standing, thirteen living, nobody
said to be starving, no pit on the yard or by the square. The storehouse stands sooner or as soon at
7 of 8 (hours standing at the end 110 for 96, 140 for 137, 36 for 24, 63 for 62, 72 for 68, 87 for
89, 119 for 113, 90 for 83). Member-hours with an empty belly 28 for 21 (17 and 17, 9 and 0, 1 and 4,
1 and 0, the rest none: the 9 are three asleep on the last night). Feet more than a step off the
ground 409 serf-seconds for 396, standing still in the air 356 for 381. **Seen, by both rules, not
looked into**: at two of the eight the lord's cart was not brought before the storehouse and its salt
not carried in (at one of them the storehouse had stood five days).

**The script's eleven sites** (`tools/stockyard_sites.sh`): with the switch off all eleven end in the
states of the build before (`$S/yard11.sh`). With it on, seven are unchanged (no steps) and four
change: one has a stair of two steps at its corner; **the three on the hillside, which keep the
storehouse of before with 4.5 m of staging, have no stair now**: their path is level at one end of
the front and 11 blocks (2.75 m) over the floor at the other (or, beside the path aslant, does not
run along the far end at all), and a stockyard's stair is 2 m at the most. Their way in is the level
end. **His call**: a longer flight there, or none (built). **It did not arise at the ten places**
(no corner of the 115 lies more than seven blocks off its floor), which is a count and not a rule:
squarely the storehouse of 12 m by 8 m has three steps of staging at its middle, but beside a path at
45 degrees it has eight, so a far corner over two metres can come with it too.
The script now fails on a stair at the middle of a storehouse's front, on a pit, and on no way from
the fire into the storehouse; it has three more sites (seven steps down squarely and along a path at
45 degrees, five steps up), each failing unless its stair is that long and at an end.

**What he praised, as the measure, and where it was taken.** No screenshot or note says which
stockyard he looked at; **the stand-in is the square at 1238 1058 with a stockyard south of it** (the
path a block under the floor at the west corner, 2 over at the middle, 7 over at the east corner).
A check builds such a front by both rules: within 3 m of the level corner 0 of 576 block columns
differ. At the stand-in built by the band (14.5 days, both rules) 69 block columns of 7,396 stand
otherwise, every one of them one of the two stairs' own (19 where the stair at the middle stood, 50
where the corner's stands, 9.25 m and more from the level corner). Built on the spot from the same
morning, **the still of the level corner is the same to the pixel**: 0 of 730,400 right of the
square (all 3,888 pixels that differ lie over the square's own floor at the lower left, where the
band stands; two stills of one save differ there by 150). Claimed there and nowhere else. (The two
stills were taken with the scratch game as it was an hour before the rule's commit; the commit
differs from that build only in where a storehouse still being raised has its door's mark drawn,
and both storehouses stand.)

**Tried as the player makes it, and on what he has.**

- **By the tool's click in the game**, release and debug, on the square three days in (camp, paths
  and cart done): the stockyard put down south of it, its storehouse begun at once; saved, run on
  sixteen days in release and debug to one state each (c130857fb8e2448c; the debug game's click
  582e3d0b3d135ec7): the storehouse stands, seven steps in the far corner, nobody with an empty
  belly, no pit, the cart before it. Clicked with `--yard-stair-middle`, the new build and the
  build he has run the save on to the same state (3c980285af1e3bff).
- **Saved while its ground is made and while it is raised, and run on**: ten moments from an hour
  after the storehouse is begun to the seventh day, at two stockyards (squarely and at 45 degrees):
  the straight run's state at 10 of 10 each; with the switch off the same.
- **Seven saves of the build he has** (7505b5f's runner: a stockyard put down and not begun; its
  ground half made, nearly made; its storehouse raised to its walls; standing; squarely and at 45
  degrees), run on four days by the new build, release and debug: **a storehouse begun keeps its
  stair at the middle and runs on to the state his build runs on to** (6 of 6); the one not begun
  gets its stair in the corner (release and debug one state, no pit) and with the switch off his
  build's state.

**Checks**: a section of eleven, "the stockyard's stair in a corner of the zone" (the level corner
and the far one, up and down; a bank at both ends; level at both; along a path at 45 degrees; built
on the spot as planned; the measure; with the stockyard's levelling off; saved and loaded both ways).
`colony_check`'s own `Reset` holds the rule off, as it holds every rule newer than its older sections.

**Three things the advisor asked after the rule's commit (757c2d0), and what each showed.**

- **With the stockyard's levelling off (`--no-yard-level`) the rule left a storehouse with no way
  in**: its ground is then its own pad and the yard before its front, the ends of the stockyard's
  front are not its ground to make, and the way was moved there all the same (the gate could not
  see it: `colony_check` holds the rule off outside its own section, and the scripts' sloping sites
  refuse a storehouse with the levelling off). **Mended in the next commit**: only a levelled
  stockyard's stair moves (`Yard_Site` in `Try_Lot`); a check builds one with the levelling off
  (a stair of two steps at the middle, a way in from the fire) and fails with the guard cut ("its way
  in stays at the low end of its front").
- **Pits while it is dug**: the twenty half-built saves of the two corner-stair stockyards (an hour
  after the storehouse is begun to the seventh day) scanned: no pit at any, a way from the fire to
  the storehouse's place and back at all.
- **The stair's first tread against the path beside it** (the square and its path made first; the
  tread is at the level of the stockyard's own outermost column): level with the path at 97 of the
  114 stairs, a block off at 16, **two blocks off at 1** (840 920 aslant, its north-west side: the
  tread half a metre under the path). With the stair at the middle: level at 41 of 115, a block at
  47, two blocks at 24, three at 3. So the corner stair meets its path better than the middle one
  did; the one that does not is the fault he named of the square's path, at a stockyard.

**Tools that came with it** (in the rule's commit: they print what it decides): `Stockyard_Front`,
`For_Yard_Plan`, `Yard_Stair_Whole`; `colony_run --yard-map` (the plan and the ground as it stands),
`--yard-now` (the storehouse begun raised on the spot at the end of a run), `--yard-pits`,
`--yard-built` (the census builds and scans each one); `Build_Homes_Now (As_Laid => True)`.
**Three ways the first counts were wrong, found before they were quoted**: a square stockyard raised
on the spot had its ground beaten at the floor's row over a stair that lies under the floor (the
checks' old shortcut: `As_Laid` lays it as a builder does); the way into the storehouse was aimed at
its roof (`Surface_Z` is the highest floor); and the census built each stockyard into the ground the
last one had been built on (a 20 m grid of squares with a stockyard on every side: `Land_Back` puts
the land back between them; with the leftovers, 19 stockyards "had pits" by either rule).

## His words of 2026-11-21, afternoon: the stair to the corner (read of the square, which he did not mean: the section above)

**Where it stood (2026-11-21, late afternoon; the section "Where it stands now" at the top is
newer).** Branch `stockpile`, **nothing merged** (`main` is 537176c; he has given no
merge word). On top of the stacking (7505b5f): documents and the site scripts' count of empty bellies
(8510794, c4ae8d6, 4dc12ce), his words of the afternoon (abbbcf5), **the census of a stockyard's
stone, tools only (3556406), the square's stair in a corner of the zone (e25f730) and its refinement
(7a13338: of two ends, the corner that is not a level way in already).** **Gate 82 passed on 7a13338**
(below). `bin/` is rebuilt at the head after it (never while `pgrep -x castle_game` finds his).
In a scratch tree only: the hearth before the whole floor (its patch in `releases/wip/` still applies
to the head). **His calls open**: the five of this section (the stair beside a level way in; the
stockyard's flight; "the opposite corner"; the three things of mine; the cap), and the four of the
report before, which he did not answer (the hearth before the whole floor; what should fail a gate;
the stockyard's walls; the storehouse's size, its distance aslant, the stacks' heights). **Owed**: a
route that ends short planned anew after a load; the holder of a bush two are picking; the advisor's
note for an older save's stockyard; and what this section lists as seen and not looked into.

**Gate 82** (7a13338, from a clean `git archive` copy, `$S/rungate82.sh`): both builds from nothing
(6 warnings, all `water_sim_check`'s; no error); the nine checks in debug, `colony_check` 1014; the
reference logs line for line; the stockyard's sites and the turned streets in release and debug,
their figures gate 81's; the square's sites in release and debug (323 squares, 52 stairs each in a
corner, none at a middle, no side's lost, 3 sides' another side's, 2 beside a level way in; the
fourteen awkward sites 40 member-hours with an empty belly, as at the head before); the stress
runner's fifteen states gate 81's, every one (six_4_years 0f6e9ac3e04d59fc, six_41_days
42613bf288a4dc5e, housing_41_days d08378f42ca99dab, crowd_as_it_is 21aaf5d3e27b4213, crowd_at_work
604d849343d51d27); flora 5676219328934879273. The sloping square with the gate's own runner: **as
built 52e0288f83480020** (gate 81: eafd146fcd25809a, which `--square-stair-middle` still gives);
walls inside 7707060159d51866, ten metres inside a991f5d1a668fa08, ten metres with no walls
b55ae2f49eead7d6, four stockpiles 60b001de3190d916: all gate 81's (the rule does not reach a square
with its walls inside).

Sent in answer to the report of the hearth before the whole floor (whose four calls he did not
answer: they stand open, at their defaults; no merge word). **His words, whole:**

> The path level at one corner is great, move the stair to the opposite corner instead of the center,
> if a stair is to be had it's to be at the corner of the zone.

| clause | his words | read as | state |
|---|---|---|---|
| a | "The path level at one corner is great" | Praise, and a measure: by the level corner he was looking at nothing changes. Not a merge word. | **Shown there**: the blocks within 3 m of it the same by both rules (a check; three real squares); the still of 1238 1058's level corner the same to the pixel. **Not so of every corner where a path comes in level** (his call 1). |
| b | "move the stair to the opposite corner instead of the center" | Answers call 1. **Built as: the stair stands at the end of its own side away from that side's level end.** The other reading, the corner diagonally across the square from the level one, was counted and not built. | **Built** (the commit after the census tool's), switch `--square-stair-middle`. His call 1 below. |
| c | "if a stair is to be had it's to be at the corner of the zone" | A rule for zones. Built for the square. **The stockyard's own flight is at the middle of its front and was not moved.** | **His call 2 below.** |

What he was looking at, as far as can be told (no new screenshot or note of his): the sheet
`~/CASTLE_GAME/releases/square_walls_outside.png`, or the same squares in `bin/`. Its first row is the
square at 1238 1058 on seed 1, its second the one at 1146 1110 seen close: the path level by the
stockpile at the left corner, the north wall rising from there to the right, a stair of three steps at
its middle. **Both pictures show a wall that begins at the level corner, with a stair at its middle**
(the scan: at 1146 1110 the north wall is two blocks high at its west end, and the corner is level on
its west side): "the opposite corner" is read as that wall's other end.

### The stair to the corner: counted, then built (2026-11-21, afternoon)

**The count first** (the advisor: do not settle the corner from one picture). The ten places' 20 m
grid, 1,210 places, 323 squares founded and made on the spot (`colony_run --square-scan 100 20`; the
runner now prints "where a stair can stand" and "level corners" with every scan):

- **Today's stairs**: 35 squares have one, 55 stairs, each at the middle of a side.
- **Can each stand at an end of its own side?** All 55: 30 take a stair at one end only (the other end
  level at 13, a bank under a stair's at 16, over a stair's or mixed at 1), 25 at both ends (8 of them
  as high at both), none at neither. No side is too high at its middle.
- **The other reading**: 260 of the 323 squares have all four corners level, 26 three, 22 two, 10 one,
  5 none. Of 1,172 level corners the corner diagonally across is level too at 1,132, takes a stair at
  28 and neither at 12. One stair at each corner diagonally across from a level one: 28 stairs at 27
  squares, and **20 of the 35 squares that have a stair today would have none.** (At 1146 1110 itself
  the corner diagonally across from the level corner by the stockpile is level too: by that reading
  the stair on the north wall would have nowhere to go.) A stair at every corner that takes one: 105
  at 53 squares.

**The rule as built** (the spec, "The stair stands in a corner of the zone"; `Set_Square_Stair_Corner`,
`--square-stair-middle` is as it was; not saved; held to squares whose walls stand outside their
floor):

- **The same sides have a stair as had one** (a bank of three to eight blocks at the side's middle,
  all one way). He said move: none is added.
- It stands at one of that side's two ends, the last metre of the floor along it, its outer flank the
  wall of the side it meets there, the strip before it its landing. **Judged where it stands**: an end
  takes it if the bank there is three to eight blocks all one way. So a side with a level end has its
  stair at the other end, the opposite corner.
- Nothing stands at the middle of any side.
- **Of two ends that both take it (25 of the 55 sides): the one whose corner is not a level way in
  already**, that is, where the path of the side met there does not come in level. A side banked
  from end to end, with the next side level where they meet, has its stair at the far end from that
  corner, though the bank is higher there. (**Added after the advisor read my own list**: with the
  lower bank alone deciding, 9 of the 53 stairs stood in a corner that is level on its other side,
  7 of them on sides whose far end takes a stair too. Those 7 moved; a second commit.)
- **Mine, unasked, each his to change** (his call 4): where that does not decide, the lower bank
  (a shorter flight); of two as high, the end come to last going round the square with the floor on
  the right, so that two sides banked evenly, one up and one down, have their stairs in corners
  diagonally across; **one stair to a corner** (two sides whose stairs fall in one corner share the
  lower bank's: 3 of the 55); a stair at the floor's corner is a block column wider where the
  floor's edge is half a cell of the walking map (else a slot 25 cm wide between stair and corner).
- **A side with one end only that takes it has it there, though that corner be a level way in on
  the other side** (2 of the 52 at the ten places, 840 940 and 870 1290; and the south-west of
  1146 1110, the square of his picture: the west path comes in level there and the south path lies
  three blocks under the floor). Left built and counted (`Stairs_By_Level`): **his call 1**.
- A square with its walls on its own edge (`--square-walls-inside`) keeps its stair at the middle.

**What came of it** (the same 323 squares): 52 stairs at the same 35 squares (25 at one end of their
side, 27 at the other; 3 sides' another side's; none lost). The highest bank a stair stands against 8
blocks, the cap (7 at a middle); 233 blocks of bank gone up or down by them in all for 216 (4.5 steps
a stair for 3.9: the far end from a level corner is the higher end). Stone in all the walls 18,629
blocks for 18,453. No pit, nothing left to lay, the fire got to from as many sides as before.

**What it costs: the way in from the middle of a walled side.** From the middle of each side's path
to the fire and back (`--square-pits` says it of one square, the scan of all): 54 sides' ways are
longer, none shorter, by 5.5 m on the mean; **the longest is 26.0 m where it was 13.0** (1200 720);
at the 35 squares the mean is 14.9 m for 12.7; over all 1,292 sides 12.39 m for 12.16. (20 sides
have no way from their path's middle by either rule, the same 20: not looked into. The measure first
said two sides had lost
their way: the walking map has no floor at the very middle of a path along the foot of a wall aslant,
which was the stair's landing before; it now tries a quarter metre at a time along the side.)

**The band, twelve days, thirteen people, 23 squares** (the fifteen sites and the eight heaviest;
`$S/st_all.sh`, kept in `releases/wip/scripts/`): the 12 with no stair end in the same state by both
rules. At the 11 with one: stairs 22 for 24; member-hours with an empty belly 234 for 229 (224 and
222 of them the first day); hungry serf-hours 3,746 for 3,658; lowest confidence 30 for 31 on the
mean, 13 for 12 the least; nobody dead; no pit; no column of a floor stone but a stair's. Feet more
than a step off the ground under them 829 serf-seconds for 720 (of 2.47 million; where, not looked
at: the runs list only their first fourteen), standing still in the air 118 for 138. **The sums
hide two squares**: at 1146 1110, the square of his picture, 21 member-hours with an empty belly
for 13, 328 hungry serf-hours for 249, and the lowest confidence 32 % for 49; at 1172 1092
squarely the walls were done after 23.0 game hours for 14.8 (they ran into the night). Others go
the other way (930 1270: 18 for 21).

**What he praised, as the measure, and where it holds.** A check builds a square on ground rising to
the north-east, its path level at two corners, by both rules: within 3 m of the level corners, strip
and path with them, 0 of 1,152 block columns differ. At 1146 1110, 1238 1058 and 1258 1058 built on
the spot by both rules, every block column that differs is a stair's own place (67, 97 and 140 of
them, in four, five and four groups: the stairs that stood and the stairs that stand); none is
within 3 m of the corner by the stockpile at either of the squares of his sheet. **It does not hold
of every corner where a path comes in level** (I had written it so; the advisor's count): 1146
1110's south-west, level on its west side, now has the south side's stair, 13 columns of it. **The still of 1238 1058's level
corner is the same to the pixel** (0 of 448,000 in the left 560 by 800; two stills of one save: 0).
At 1146 1110 the blocks are the same and the picture is not, by 599 pixels of that part: the tufts
of tall grass over the meadow are drawn in another pose in the two saves (seen, not looked into:
owed, below).

**Tried as the player makes it, and on what he has.**

- Founded by the tool's click in the game at 1238 1058, release and debug, nobody given a job, run on
  four days: the walls begun on the third day, two stairs in corners, no pit; **saved while the corner
  stairs are half laid** (after 2,910, 2,940 and 2,970 colony seconds) **and run on: the straight
  run's state each time**, both builds. With the switch off the new build runs the save on to the
  state the build he has does.
- **Three saves of the build he has** (7505b5f's; the sloping square with its middle stairs half laid
  and laid, 1238 1058 with three laid), run on two and a half days by the new build, release and
  debug to the same states, no raise: **the corner stairs are built** (117 and 130 blocks of stone
  more at the two whose walls were done) **and the stairs at the middles stay as they were laid**
  (nothing takes laid stone up; the one that goes down keeps its two upper steps and is closed at
  its foot by the rim that now runs past it, read from the map of the square as it stands); no pit. With the
  switch off the new build runs each on to the state the build he has does. No rule was made for
  old saves.
- With the switch off, the sloping square as built ends in the head's state (eafd146fcd25809a); with
  it on, 52e0288f83480020 (the same before and after the second commit: both its stairs stand at
  the only end of their side that takes one). **And at all 23 squares of the band's twelve days the
  new build with the switch off ends in the state the build he has ends in** (7505b5f's runner,
  `$S/head23.sh`).

**Found on the way, and where it went.**

- The census of a stockyard's stone went into the repository (owed since noon; 3556406), with the
  stockyard's stair counted apart.
- `$S/sec.sh` ran the last binary when its section's heading was not found: it now says NOT BUILT.
- **Owed, seen and not looked into**: tall grass drawn in another pose in two saves that differ only
  in blocks elsewhere in the view (does it jump when someone digs nearby?); the 20 sides with no way
  from their path's middle to the fire.
- **Owed with the next code commit** (left so that the gated commit stays the code's head): the
  comment of the second check of 7a13338 says the side's far end is "two blocks"; the path there is
  brought level, and the check's own line prints 0. The check is right, its comment is not.

**His calls, in the report of it:**

1. **A stair beside a level way in**: where the only end of a side that takes a stair is a corner
   the next side's path comes into level (the south-west of 1146 1110; 2 of 52 at the ten places):
   built there, or that side has none.
2. **The stockyard's stair**: it is the flight of the stockyard's own way in from its path, at the
   middle of its storehouse's front, where the path lies more than a block off the floor: 115 of 828
   stockyards. His rule names it and it is not moved. To put it at a corner of the zone the way in
   moves to an end of the front (the storehouse's doors are in its ends, so it would lead straight
   to one): a pass of its own, on his word; its questions are in the brief.
3. **"The opposite corner"**: the far end of the stair's own wall from the level corner (built), or
   the corner diagonally across the square (20 of 35 squares then have no stair).
4. The three things of mine in the rule (the lower of two ends where no corner is level; one stair
   to a corner; the tie).
5. The 2 m cap stays (his accepted figure): no stair is lost to it at an end today (one side has an
   end over it and takes its stair at the other).

The sheet: `~/CASTLE_GAME/releases/square_stair_in_the_corner.png`.

## Where it stood (2026-11-21, late morning; the list above is newer)

- Branch `stockpile`, **nothing merged** (`main` is 537176c). In order: the square 13 m (0154dcf), his
  rule 1 (683c9e4, aac655b, e694aa4), a square under a tree (68ba4ec), the stockyard put down whole
  (82fa10b, 8fa2576), **the storehouse 12 m by 8 m (d714016), two things a save left out (ecbe1a0),
  food and barrels stacked (7505b5f)**. Gates: 77 (e694aa4), 78 and 79 (82fa10b, 8fa2576), **80
  (ecbe1a0) and 81 (7505b5f) passed.** Everything of his message of 2026-11-21 is built. Since then
  only documents and the three site scripts have changed (8510794: no source, `bin/` is 7505b5f's);
  the scripts pass in both modes with every member's state printed each hour and the empty bellies
  counted. **Three corrections went to him in one afternoon** (nobody starved; the recount that
  counted a word; a column headed his build's that was not): the first section below has them.
- **In a scratch tree only, with their diffs and the scripts that measure them kept in
  `~/CASTLE_GAME/releases/wip/`**: the census of a stockyard's stone, and the trial of the hearth
  before the whole floor. Nothing more moves without his word.
- **Reported to him**: the square, rule 1, the stockyard box (its report also told him of the 3.5 m at
  45 degrees and of the lot's timbers lost in a save), the storehouse's size (on gate 80, with the
  call of his two clauses first), the stacking (on gate 81). `bin/` is rebuilt at each report (never
  while `pgrep -x castle_game` finds his); it holds 7505b5f's code.
- **His calls, each standing at its default on no word** (call 1 was answered in the afternoon: the
  section above):
  1. A square's stair is cut into its floor (built). **Answered: in a corner of the zone.**
  2. **8 by 12 with the fenced yard as deep as before (built), or the yard 3 m deeper with a
     storehouse 5 m back (`--storehouse 12 5 1.5`)**: his two clauses cannot both be had on 20 m.
  3. Beside a path at 45 degrees the storehouse stands 3.5 m off, not 1.5 (built).
  4. Baskets three high, barrels two (built).
  5. The stockyard's own retaining walls: **counted, none moved** (they stand under its fence or on
     its staging's edge, never on a place: the section of that name); outside all the same if he says.
  6. The hearth built once the middle of the floor is level: **tried in a scratch build, not in the
     repository** (the section "Where today's square costs"): it takes the first night's empty
     bellies from 85 to 6 at fifteen sites and from 144 to 4 at the eight heaviest. On his word.
- **Owed**: a route that ends short planned anew after a load, and the holder of a bush two are
  picking (each wants more in the blob: "Why a save does not always run on", below); the advisor's
  note for a stockyard of an older save that the larger storehouse does not fit says the wrong
  reason; the census of a stockyard's stone into the repository. **Put to him**: what should fail a
  gate (a death, or an empty belly); whether the hearth should come before the whole floor (call 6:
  today's square costs empty bellies in its first days). Then, in his order: the zone's own grid,
  the lots' polish.

## A retraction owed across this whole round, and its own correction (2026-11-21, noon and after)

**What was said**: in this handoff and in the reports of the square's size, of rule 1, of the storehouse
and of the stacking: "nobody starves", "nobody starving in any", for runs of twelve and of fifty days.
**What those runs could show**: a death, and a state worded "starving" of someone *without a bed* (the
food line names the bedless with what they are doing). They printed nobody's state (`--who` does).

**Then the first recount was wrong too, and he was sent it**: I counted the `who:` lines worded
"starving". The game words a state so only while its bearer works; **an empty belly on the way to the
pot, asleep or fending is not worded so**. So "1 hour at one site against 18 at four", "it goes with
the size at the three open-land runs" and every "hours said to be starving" below this line in the
first version were counts of a word. At 1000 912 squarely the word gave 0 hours at ten metres and 8 at
eleven; the bellies give 13 and 17.

**The measure that is the game's own** (`Person.Starving`: its belly empty; the spec: "once its belly
is empty it is starving, and walks and works at Starving_Pace until it has eaten"): a `who:` line at
0 % fed with its place printed, which the runner adds for whoever is starving. `$S/belly.py LOG...`
counts them: **member-hours with an empty belly** (one for each of the band at each hourly look).
Every run below is the head's code (7505b5f) unless said; **nobody died in any of them**.

- **An empty belly for an hour before a meal is ordinary, in his build too.** His build's square
  (ten metres, walls inside: `--square-10 --square-walls-inside --no-fire-ground`), fifteen sites,
  fifty days: 111 member-hours, some at every site (of 234,000). d53ba6f's own runner at the open
  land: 12 in fifty days.
- **Today's square costs more of them**:

  | | his build's square | 11 m, walls inside | 11 m, walls outside (today) |
  |---|---|---|---|
  | fifteen sites, twelve days | 21 (at 1 site) | | 85 (at 3) |
  | the eight heaviest squares, twelve days | 36 (at 2) | 181 (at 8) | 144 (at 8) |
  | fifteen sites, fifty days | 111 | 160 | 177 |
  | the same: hours in which the least fed is at nothing | 66 | 85 | 85 |

  (Ten metres with the walls outside: 140 in fifty days, 29 in the first twelve. **He was sent 29 as
  his build's square for the twelve days: that set had been run with `--square-10` alone, which at
  the head is ten metres with the walls outside; by his build's rules it is 21.** The fire's ground
  moves nothing.) Hungry serf-hours over
  the fifteen and fifty days are the same, 13,559 and 13,583. Single runs, but all one way: the
  larger floor and the walls take the band's first days (the hearth an hour later on the level and
  up to three on slopes, as its report said), and bellies run empty more often for it. The fourteen
  awkward squares, twelve days: 40 at 2 of 14; the thirteen under trees: 0.
- **The storehouse and the stacks: no one way.** Fifty days, the storehouse of before, the new one,
  the new with the stacks: at the open-land stockyard 26, 16, 6; south of the west path 0, 4, 44;
  along the path at 45 degrees 3, 6, 8. (The open land with no stockyard at all: 15; 12 in
  d53ba6f's runner with its own square.) Sixteen days on from the tool's click: the box in 82fa10b's
  build 5, the storehouse 13, with the stacks 3.
- **Two years** (`$S/winter.sh`; the run that was going when the stacking was reported): 13 living at
  each of three stockyards with the stacks off and on; member-hours with an empty belly 103 and 66 at
  the open land, 40 and 75 south of the west path, 47 and 35 along the path at 45 degrees; hungry
  serf-hours 2,760 and 2,609, 3,346 and 3,105, 3,608 and 3,787; lowest confidence 34 and 58, 38 and
  31, 39 and 37.
- **Also printed with a place: whoever "can't get there"** (a way that failed): 238 member-hours over
  the fifteen sites and fifty days with his build's square, 246 with today's; none at the stockyards
  south of the west path or along the path at 45 degrees; 24 to 58 at the open land. Not looked into.
- **What happens to one of them** (1000 912 squarely at eleven metres, three mornings running): a
  gatherer wakes at 58 %, sets out at six for wild vegetables at 50 % (the near ones are picked by the
  fourteenth day; its reach has grown to 80 m), walks three hours for them, and carries two to four
  home for two or three more, at nothing for the last. At twelve it eats stew and is at 70 to 90 %.
  **As the needs are specified**: one eats at its next break once down to 40 %, and at 15 % stops
  what it is doing "(never a load in its arms or a butchering: those are finished first)", which is
  his word of 2026-11-13; a walk with a load has no break in it. Not a fault and not mended.
- **The gate's scripts** print every member's state each hour since this (they printed none, or
  twice a day), and their pattern for a death matches what the runner prints ("has died of hunger";
  "dead, of hunger" matched nothing: checked on a run that ended with nobody living, 13 lines). They
  fail on a death or a state worded starving, and say "nobody died or was said to be starving (N
  member-hours with an empty belly)". Run from the working copy in both modes: all pass; the counts
  they print: the fourteen awkward squares 40, the four under trees 0, the eleven stockyards 0 at
  eight, 1 at two and 31 at the largest on the hillside, the turned streets 0. (About 50 s, 13 s and
  four minutes in release.) **What should fail a gate is his call** (put to him).

Below, "nobody starved" stands only for that; where it was said of runs that printed no states it
now reads "nobody died".

## John's words (2026-11-21, whole)

> Great job, I like what I see. Let's expand the campfire/homestake square to 13x13m (with the footpath) so the campfire is in the center. 1. A rule, the area of a special zone like these takes precedent, so if a retaining wall is needed put it on the zones edge, shift the path. So the area of the campfire stays 11x11m + the wall on the sides if needed then the path that follows, the size can change overall. 2 and 3 are fine as you  made them. 4. That is acceptable. 5. That is also acceptable. 6. That is acceptable.
>
> For the stockyard, lets expand the zones to 20x20, bring the storehouse forward 3m towards the path so that the fenced area becomes 3m deeper , add 2m to the width of the storehouse, so that it is now 8x12. Allow food and full barrels to be stacked in the storehouse.
>
> How does that sound?

The numbers 1 to 6 answer the six calls of the walls' report (calls 12 to 17 of the handoff before:
where the walls stand; the angled set-back; the angled stair; when a side has a stair; when the walls
begin; stone left over).

## Read so, clause by clause

| | His words | Read as | When |
|---|---|---|---|
| a | "Great job, I like what I see." | Praise. Not a merge word: nothing is merged. | |
| b | "expand the campfire/homestake square to 13x13m (with the footpath) so the campfire is in the center" | The floor 11 m by 11 m (44 blocks a side), its path round it making 13 by 13. An odd number of metres, so that the fire has a middle metre of its own: the square's ground is worked a square metre at a time, and with 10 m the fire stands on the corner where four of those metres meet. With 11, and the metres counted from the floor's edges, it stands in the middle of the middle one. The stake's place stays the exact middle (a corner of blocks, 22 each way). | first, its own commit and switch |
| c | "1. A rule, the area of a special zone like these takes precedent, so if a retaining wall is needed put it on the zones edge, shift the path. So the area of the campfire stays 11x11m + the wall on the sides if needed then the path that follows, the size can change overall." | **A rule for special zones**: the zone's area is kept whole. A retaining wall stands outside the 11 by 11, on its edge, and the path lies beyond the wall; a walled side is that much further out, and the whole is no longer a fixed 13 by 13. (It answers call 12 the other way: I had the wall on the floor's own outermost quarter metre and the step taken out of the floor.) | second, its own commit and switch |
| d | "2 and 3 are fine as you made them." | Calls 13 and 15 of the handoff before stand: aslant a set-back of one diagonal row (18 cm); a stair 1.6 m wide aslant, its steps 35 cm deep. (His 2 and 3 are the report's: the angled set-back and the angled stair.) | closed |
| e | "4. That is acceptable. 5. That is also acceptable. 6. That is acceptable." | A stair only for banks of 75 cm to 2 m; the walls after the fire is lit and the planned paths, on the third day with no fire; stone left over with no room left lying. | closed |
| f | "For the stockyard, lets expand the zones to 20x20" | The stockyard is one zone 20 m by 20 m (the brief's next pass had it put down as a box of 16 m; the two-corner tool takes 15 m at the least today). | after the square |
| g | "bring the storehouse forward 3m towards the path so that the fenced area becomes 3m deeper" | The storehouse stands 3 m nearer the path: of today's 5 m of staging before it 2 m are left, and the fenced yard behind it is 3 m deeper. | with f |
| h | "add 2m to the width of the storehouse, so that it is now 8x12" | **"8x12" is not a size the storehouse has in his build**: its walls are 5 m by 10 m (his own figure of 2026-11-17: "make the stockhouse some reasonable size, 5x10m same as the houses"); with its roof's overhang it is 5.5 by 10.5. Read as the instruction it gives, two metres on its width, the rest as it is: walls of 7 m by 10 m. The other reading, walls of 8 m by 12 m, is put to him (nearly twice today's floor). | with f; his call |
| i | "Allow food and full barrels to be stacked in the storehouse." | A place on the storehouse's floor holds baskets of food stacked, and a barrel's place more than one full barrel. How high is not said: first values of mine, his calls. | after f to h |
| j | "How does that sound?" | A short reply first (what I think, at most four calls with defaults), then built in his order, a reply at each piece he can try. | |

## Measured before the reply

- **Where a square can be founded at 11 m** (`colony_run --square-census 48 4`, 441 places, squarely
  and aslant; a scratch tree with the size alone changed, beside d53ba6f's): round the reference stake
  251 and 257 take one where 261 and 273 do today; on the open land by 1000 900, 235 and 237 for 244
  and 244. About one place in twenty-five fewer (the same 1.5 m of fall over a wider footprint, and
  more water under it on the open land).
- **The storehouse as drawn**: walls 40 by 20 blocks, the roof a block over on every side.
- **The fire is drawn in the square's exact middle today** (`Camp_At` is the stake's place); what is
  off is the metre it stands in.

## What I told him I think, and the calls put to him (each stands as its default on no word)

1. **The stair** stays cut into the floor, a metre wide and up to two metres in: the one thing left
   inside the 11 by 11. The other way: outside with the wall, the path further out on that side.
2. **The storehouse's size**: walls of 7 m by 10 m (two metres on its width). The other: 8 m by 12 m.
3. **How high things stack in the storehouse**: baskets of food three high (as wood under a
   covering), full barrels two high.
4. **His rule and the stockyard's own retaining walls**: they move outside its 20 by 20 in a pass of
   their own after its box; the hovels' at the lots' polish.

## Built: the square eleven metres, thirteen with its path (`Set_Square_Wide`, `--square-10` is the old)

- **What it is.** A square is founded with a floor of 11 m (44 blocks a side; aslant 11.02 m, its
  path's corners 34 blocks from its middle along X and Y) and its path round it from 5.5 to 6.5 m out:
  13 m over all. Its ground is made ready in **121 square metres counted from its edges**, so the fire
  stands in the middle of the middle one (on ten metres there were 100 and the fire stood where four
  met). 48 m of path squarely, 52 aslant (44 before).
- **A square keeps the size it was founded with.** The size is read from the zone's saved frame
  (`Along_B`: 48 or 34 blocks; 44 or 31 of a ten-metre one), never from the switch, in everything
  that asks of a founded square; a camp's and a ten-metre square's square metres keep their old
  numbers (a member's patch is saved by its number). The four saves kept from his build, run on two
  days in his build and in this one, end in the same states.
- **Unchanged with the switch off**: the sloping test site (1146 1110) founded with `--square-10` ends
  in gate 74's states (c49eb1f6773c79b3 with walls, f42bd0412bb19cf5 without), the four stockpiles with
  trees in 76d134cb35a704c2, and the scan of 1,210 places at ten metres gives his build's figures to
  the block (330 founded, 63 walled, 22 set back, 32 with a stair, 12,182 blocks of stone).
- **What it costs** (measured, band of thirteen, twelve days, the fifteen sites of the sites script
  that take a square of either size):
  - **Fewer places take one**: of 1,210 places on a 20 m grid round ten spots, 321 for 330 (the census
    before the reply said one in twenty-five). The three squares with the highest banks that I used
    as walled test sites (1336 936, 1250 1054, 1130 1142, also 1178 1094) are now refused: 175 cm of
    fall where 150 is the most.
  - **The hearth stands later**: an hour later on level ground (after 4 game hours for 3, 6 for 5),
    two hours later in the wood (8 for 6), **three hours later on the three sloping sites** (11 for 8,
    12 for 9): all of the floor is made level before the hearth is built, and there is a fifth more
    floor, a third more earth to move on a slope. Mean over the fifteen: 6.5 hours for 5.1.
  - **Hunger**: 3,328 hungry serf-hours in twelve days for 3,178 (a twentieth more), nearly all of it
    at those three sloping sites (296 for 200, 360 for 329, 298 for 272); the lowest confidence there
    36 % and 26 % for 60 and 46. Nobody dies at any of the fifteen (member-hours with an empty belly in those twelve days, counted
    since: 21 with his build's square, 85 with today's; see the retraction at the top).
  - **Stone**: 13,991 blocks for the walls of the 64 walled squares, where 63 took 12,182 (the most
    for one 46 stones for 42); the way from the middle of a side's path to the fire and back a metre
    longer (12.05 m for 11.01).
  - **On the eight squares with the highest banks it costs much more than on those fifteen**
    (measured after the size was reported to him; 870 1290, 930 1270, 950 1290, 1200 720, 1238 1058,
    1320 1000 squarely, 890 1290 and 1258 1058 aslant; twelve days). At ten metres the hearth
    stands after 9 to 11 game hours and the first log burns in hour 10 to 12; at eleven the hearth
    after 12 to 15 and **the first log on the second day at four of the eight** (hour 24 to 26: the
    fire is not lit before night). Hungry serf-hours 2,749 for 1,944; the lowest confidence 16 to
    37 % for 47 to 59; someone is said to be starving at three of the eight (five lines of the log),
    at none at ten metres. **This is what the call about the hearth is for.**
- **Checks**: a new section of eight ("the square eleven metres, thirteen with its path": its floor
  and path squarely and aslant, 121 square metres and 48 m of path, a ten-metre square saved and
  loaded where squares are founded eleven, both ways made level on rising ground with no pit, the
  band of six building it). The older sections found squares ten metres (`Reset` holds the switch
  off, as it holds each rule that came after them). colony_check 941 of 941 in debug.
- **The sites script** (`tools/square_sites.sh`) scans a 20 m grid within 100 m of its ten places now
  (16 m and 96 before: eleven metres aslant reach 9.2 m from the middle, the next square's side is
  6.5 from its own) and asks 280 founded, 45 walled, 14 set back, 24 with a stair (321, 64, 21 and
  34 are); its half-built save is taken in the middle of the hours the walls are laid in, read from
  the straight run, on a half minute; its three window squares are 1238 1058, 1258 1058 and 1320 980
  (the three before do not take eleven metres).

**Gate 75** (0154dcf, from a clean copy): both builds, the nine check programs in debug (colony_check
941 of 941), all eight reference logs line for line, the stockyard's sites and the turned streets in
both modes, the square's sites in both modes, the stress runner with every state gate 70's
(six_4_years bcd712a4fd9ea6d9, six_41_days d580854cf5cac587, housing 6794042cea5a9e70, crowd_as_it_is
65a9d38031d4e79a, crowd at work 3f7c2c6949cec18c), the flora's hashes. `bin/` was built from it at
03:44 on 2026-11-21, and he was told (the sheet: `~/CASTLE_GAME/releases/square_thirteen.png`).

**Put to him with that report, and standing at its default on no word:** when the hearth is built.
As it is, after all of the floor is level; the other way builds it as soon as the middle is level
and finishes the floor after (the fire lit about as early as on ten metres). Not built.

## Built: the walls outside the floor, the path beyond them (his rule 1; `Set_Square_Outside`)

- **What it is.** A square founded under the rule has a strip kept outside each side of its floor
  where that side's bank will want a wall: squarely a ring (a block column, 25 cm) for each lift of
  the highest wall that side is to have, three at the most; **aslant two rings (two diagonal rows,
  35 cm) wherever a wall is wanted**, the second the wall's capped top where it has one lift. The wall
  stands in the strip, the path beyond it; the four stretches run between the corners where the four
  lines meet, and the square with its path is wider than 13 m by as much on that side. **All of the
  floor is floor.** Against higher ground the lowest lift stands beside the floor and the top one,
  flush with the path, furthest out; holding the floor up, a rim of stone flush with the floor and
  the lower lifts further out (his "from lower ground for each 1m of retaining wall step inwards
  .25", unchanged, counted from the floor's edge outward now).
- **The stair is as he saw it** (the default of call 1 in the reply): cut into the floor from its
  edge, a block a step; the strip before it is a landing of stone at the path's level.
- **Where a side's path lies level with the floor there is no strip to see**: a quarter metre of the
  path's length is brought to the floor's level strip and all, or not at all, so there the strip is
  laid as path and the path is that much wider. Beside a bank, what of the strip the wall does not
  want is brought to the path's level and capped with stone (the wall's top that much broader).
  **Unasked, and his to change**: I first left that part as it lay, and it was tufts of grass on the
  wall's top with a slot behind them.
- **The strips are judged when the square is planned**, so the tool's ghost shows the path where it
  will be laid, and they are the square's from then on (saved in spare bits of its zone's frame:
  blob 43 still, and a square of before the rule is saved to the byte as it was). What is built is
  still read from the path as laid, so where the forecast is wrong nothing sticks and no floor is
  taken: a wall with too few rings stands steeper in those it has; on a side with no strip a bank is
  left earth, as banks were before there were walls. **Measured on 1,210 places (320 squares, 70 of
  them with a strip, 212 sides, 345 rings): no side is asked more than was kept; 74 are asked fewer
  (nearly all of them angled sides with a wall of one lift, which keep two rings by the rule above);
  and no side with no strip is asked for a wall.** (As first committed, 683c9e4 and aac655b: 213
  sides, 349 rings, 77 asked fewer, and one side with no strip asked for a wall, 2 m of its bank
  left earth. That side was the fault gate 76 found: the next section.)
- **What it costs**, against the same square with its walls inside (`--square-walls-inside`):
  - **Stone**: 18,453 blocks for the 320 squares where 13,991 were laid (a third more: the walls
    run round a longer line, their tops are capped, 2,039 block columns of it, a landing before each
    stair; 18,515 and 2,100 before the mend of the next section); the most for one square 62 stones
    for 46. One bank is 2.25 m now (870 1290: its path lies further up the slope)
    and its wall is set back twice.
  - **One place fewer** takes a square (320 for 321: ground wanting under a shifted path).
  - **The eight heaviest squares, twelve days** (the band of thirteen, walls inside against
    outside): every wall is finished, in the same hour or the next (between hour 23 and 28), no
    pit; hungry serf-hours 2,709 for 2,749; someone said to be starving at none for three; the
    lowest confidence 12 to 42 % for 16 to 37. The rule costs the band nothing there that the size
    has not cost already (above).
  - **Time and hunger, fifteen sites, twelve days**: the hearth stands in the same hour at fourteen
    and an hour later at one; 3,307 hungry serf-hours for 3,328; lowest confidence better at the
    sloping site (49 % for 36), worse at one angled one (1172 1092: 26 % for 52), the rest within
    three points. Nobody dies. (**Not "nobody starves", as this said**: member-hours with an empty belly
    in those twelve days, counted since, are 181 with the walls inside and 144 outside, at all eight
    squares; 36, at two of them, with his build's square.)
  - The way from the middle of a side's path to the fire and back is 12.15 m for 12.05; 24 of 1,280
    sides have none from their path's middle (21 with the walls inside).
  - **An angled square's path lies 35 cm further out on a walled side even for a wall of one lift**
    (two rings, the second its capped top): 74 of the 212 sides with a strip keep more than their
    wall asks.
- **With the rule off nothing moves**: `--square-walls-inside` at eleven metres ends in the size
  commit's state (89f00438833d9699); with `--square-10` too, in gate 74's (c49eb1f6773c79b3;
  f42bd0412bb19cf5 with walls off). The four saves kept from his build run on to the same states in
  his build and in this one: a square keeps the rule it was founded under.
- **Faults found building it, each with what caught it**:
  - *A stockpile could not be put down along the path of an angled square whose adjoining sides had
    strips an odd number of rings apart* ("it overlaps a path"): the lines of two such sides cross at
    the middle of a block's edge. Four of seven angled test squares with a strip; **the band starved
    at all four** (no stockpile). Caught by the timing run's count of stockpiles put down, not by a
    check. My first mend ran each stretch on to the corner of blocks beyond; then the stockpile went
    down, but along a path of its own 18 cm beside the square's (10 m of it "new"): a path at 45
    degrees that things lie along runs on every other diagonal of the grid. So **an angled square's
    strip is two rings or none**, and its path's lines are the diagonals they always were, a step
    further out. A check plans angled squares on four rises (none has any other strip) and holds a
    stockpile by each side of one (each lies along that side's own path, none of its path new).
  - *Housing pulled along a walled side took the strip* (after the rule's commit, 683c9e4; put to me
    by the review before the report): with a row toward the square, eighty block columns of the
    strip along ten metres became housing ground; the strip was then not laid as path where it
    should be and the wall stood on housing. **A strip is nobody's to zone now** (`Strip_Kept`, asked
    by the three planners that take ground: a lot's, housing's strip, housing's fill): the row toward
    the square is refused as it is beside a floor ("there is no clear ground there to build on"),
    the row away from it is zoned as ever. `Square_Walls_State` counts strip columns that are a
    zone's (none); a check pulls housing three ways along a walled side, and fails with the guard
    cut (32 columns taken).
  - *A boulder in the path's line left a pocket*: no path there to read, so the strip before it was
    left as it lay, a bank of earth and rock between two walls that a serf could step down onto from
    the path above and not leave (one square of 320, four spots). The wall runs on before the rock
    now at the height it has beside it. `colony_run --square-pits` says where a pit is.
  - *The strip left as it lay* (above), and a landing I first made steps of (the stair began in the
    strip, 25 to 50 cm less of the floor cut: not what I had told him, so taken back).
- **By the tool's click in the game, release and debug**: a square founded squarely at 1238 1058
  (rings 2 2 2 2) and aslant at 1160 1090 (2 0 2 0), a stockpile put down by each by click, saved,
  run on four days (three in debug): walls finished, no pit. On two colonies three days old, a
  second stockpile put down by click along a shifted path (the east side of 1146 1110, the north-west
  side of 1160 1090), run on: as it should be. The tool's ghost shows the path where it will lie.
- **Checks**: a new section of twenty ("the square's walls outside its floor, its path beyond
  them"): planned, founded and made on three rises, squarely and aslant (the rings kept, the path's
  four lines, **the level it was planned at is the level it is founded at**, the path as laid asks
  what was kept, every column as planned, no column of the floor off its level or stone but a
  stair's, no pit); the strip laid as path where the path is level; saved and loaded; a square
  founded with its walls inside keeps them under the rule; a bank raised after the founding beside a
  side with no strip and beside one with a ring (left earth; steeper; no floor taken, nothing left
  counted); the angled strips; built by the band squarely and aslant with a way to the fire every
  second and a pit scan every twenty. colony_check 961 of 961 in debug; all eight reference logs
  line for line.
- **The sites script** fails now too if any column of a floor is stone and no stair's, or if the
  strips are too narrow or wanting on more than three sides in all (none is; six and one until the
  mend of the next section), or if a square is founded at another level than planned; and **its stockpiles are
  pinned**: at each of the fourteen awkward sites all four go down, each along that side's own path
  with none of its path new (fifty-six in all), and the one, four and one of its other parts
  likewise. Held as the script holds them, four stockpiles go down so at sixteen squares with the
  walls inside and outside alike, among them a side with one ring (1146 1110) and two with three
  (870 1290).

## Gate 76 stopped: three squares were founded a block lower than planned (mended, its own commit)

- **What the gate showed.** Gate 76 (aac655b, a clean copy) passed its checks, the reference logs,
  the stockyard's sites, the turned streets and the square's sites in release; in the **debug** run
  of the square's sites two of the ten scans raised `Place_Square`'s assertion "a square is founded
  at the level it was planned at" (at 780 940 aslant and 1240 720 squarely), and then stood for half
  an hour: the run-time says what was raised and waits for the workers' tasks, which nobody stops.
  I stopped the gate. Nothing in release shows it (assertions are off there), and the made-up world
  of the checks has no trees on its rises.
- **The fault.** A square's strips are judged in its plan against "the level the floor is to have".
  The plan reckoned that level without the block columns a tree's foot stands on (as the cut-off
  test before it always did); the founding (`Choose_Level`) counts them, their ground two blocks
  down under the roots, as ground to fill. Where trees stand on the floor and the earth to dig and
  to fill is near balance, the founded floor is a block (25 cm) lower than the plan's. **Three
  squares of 320** on the ten places (780 940 and 840 920 aslant, 1240 720 squarely): their strips
  were judged for a floor 25 cm higher than they got. **One of them was the side "with no strip
  that is asked for a wall, 2 m of bank left earth" of the figures above**: not a forecast missing
  the path, as I had it, but this.
- **The mend** (`Level_For (..., With_Feet => True)` for `Square_Plan.Level_Row` and
  `Forecast_Strips`; the cut-off test keeps its own level, so nothing of a square with the rule off
  moves): all 320 are founded at the level planned; no side with no strip is asked for a wall; 212
  sides with a strip (213), 345 rings (349), 74 asked fewer than kept (77), stone 18,453 (18,515).
  Every state quoted for the rule is as it was (the sloping site's four, e8b03aeb42a10239 with the
  walls outside; the stockpiles' ead8b40dde19eb1d; the fifteen sites' and the eight heaviest
  squares' thirty and sixteen runs each end in the state they had): the three squares are in none
  of them.
- **What holds it now.** `colony_run --square-scan` counts squares founded at another level than
  their plan said and names them; `tools/square_sites.sh` fails on one (and on strips wanting on
  more than three sides, where it let six by). A check in the made-up world: three trees on a flat
  floor whose south part lies two blocks lower over a column more each time, twenty-six sizes round
  the one where the level drops; with the mend cut from a copy it fails at the three sizes from the
  drop on (colony_check 963 of 963 in debug). `colony_run` leaves with 1 when it raises, saying
  what and where, so a scan that raises fails its script at once. The two scans that raised were run again in debug with the mend: no
  raise, none founded off its plan.
- **For the next time**: a plan that judges by a figure the founding works out again must take it
  from the very same reckoning, and a scan of real places is run in debug before the gate, not
  first in it.

**Gate 77** (e694aa4, from a clean copy): passed. Both builds (the six known warnings), the nine check
programs in debug (colony_check 963 of 963), all eight reference logs line for line, the stockyard's
sites and the turned streets in both modes, **the square's sites in both modes** (the debug scans that
raised in gate 76: 320 squares, every one founded at the level planned), the stress runner with every
state gate 75's (six_4_years bcd712a4fd9ea6d9, six_41_days d580854cf5cac587, housing 6794042cea5a9e70,
crowd_as_it_is 65a9d38031d4e79a, crowd at work 3f7c2c6949cec18c), the flora's hashes
(5676219328934879273 in both builds). `bin/` was built from e694aa4 on 2026-11-21 at 06:42 (release)
and 06:44 (debug) with a clean working copy.

## A square under a tree: its stake on a bough, or refused after its plan (mended, its own commit)

Found while measuring the stockyard against the squares of the ten places, **older than this round**
(as old as the square among trees, gate 71), and worse than the first sight of it, which is what the
report of rule 1 told him ("at 3 of 323 places the ghost of the square says yes and the click says
there is no ground").

- **The fault.** A square's plan carries, as its middle's height, the highest floor there
  (`Castle.Nav.Surface_Z`): under a tree that is a bough of the crown, 4 to 7 m up. The plan reads
  the fire's own ground under it; the founding asked `Place_Stake` for ground *near that height*.
  - With a bough over the fire's own block column, the "ground" found was the bough: the stake's
    place, and the fire's, was put up there, and **the band arrived on the tree tops round it** ("the
    floor nearest the square's height"). **11 squares of 323.** Ten of them run twelve days with the
    band of thirteen: somebody said to be starving at seven (101 to 279 lines), feet more than a step
    off the ground for up to 87,094 serf-seconds, the worst 4.75 to 7 m up.
  - With the bough beside that column, no ground was found within 4 m: the square its plan had
    shown as taken was refused, "there is no ground there for it". **3 more.**
  The scan never showed it: it founds six and makes the square on the spot, where the trees are
  felled at once. The fourteen awkward sites of the script have none such.
- **The mend** (`Set_Fire_Ground`, `--no-fire-ground` is as it was; not saved): `Place_Square` hands
  `Place_Stake` the ground the plan read (`As_Read`); beside a tree's foot that stands on the fire's
  own place, the ground by it. Where nothing lies over the middle the stake is where it always was
  (the sloping site's states c49eb1f6773c79b3 and e8b03aeb42a10239; ead8b40dde19eb1d).
- **After it**: all 13 run twelve days: founded, the hearth after 3 to 9 game hours, nobody died
  (and no empty belly at any hourly look, counted since),
  no pit, feet never more than a step off the ground (31 serf-seconds at one, the worst 1 m). The
  ten places: **323 founded of 323 planned** (320), none with its fire more than 2 m off its floor's
  level (11); 1,165 trees felled (1,145); every other sum as it was (70 walled, 212 sides, 345 rings,
  stone 18,453; with the walls inside 324 founded, stone 13,991).
- **What holds it**: `colony_run --square-scan` counts squares planned and not founded, and fires
  off the ground; `tools/square_sites.sh` fails on either and runs four of the fourteen twelve days
  with a band (its part 2b: nobody starved, feet on the ground). Four checks in the made-up world: a
  sheet of timber 5 m over the middle, over the fire's own column and beside it, with the switch on
  and off (off: the stake 5 m up and all six of the band up there; the plan yes and the founding
  no). colony_check 967 of 967 in debug.
- **By the tool's click**: a square founded in that wood by click in both builds (it lands on a
  neighbouring corner: the scripted pointer's ray meets the crown, and I could not aim it at a corner
  under a bough). The tool and `--square` both go through `Place_Square`; the fourteen places were
  founded by `--square`.

## Built: the stockyard put down whole, twenty metres square (`Set_Yard_Box`, `--no-yard-box` is the two corners)

His clause f ("For the stockyard, lets expand the zones to 20x20"), built as the brief's pass 3 had
it (the stockyard put down as a box) at his size. **The gesture changes with the size**: he said
"expand", and the Stockyard tool now holds one box with its path, as the Stockpile tool does, where
it took two corners of 15 to 25 m. `--no-yard-box` brings the two corners back in the same build.

- **What it is.** `Place_Box` with `Stockyard_Box`: 20 m square, its path along its front, held by
  its middle, turned by Z and X, drawn to a path as a stockpile's box is, refused over anything
  with the reason by the cursor. Four hundred places on its own whole metres, all of them or none.
  Its zone is the stockyard's as ever (a stockpile's zone with the flag, its places closed until the
  storehouse stands), with its frame kept. No blob change.
- **Asked of me before it was built, and what was done about each**:
  - *The plan must refuse wherever the click would.* The storehouse is tried on the planned ground,
    in the plan, with the box's own path counted as lying there (`Try_Store_On_Plan`). Two corners
    learn it only after the zone is made. A check holds the colony's bytes the same across a plan
    that says yes (32 of 32) and across a refused click; at 1,280 real sides the plan and the click
    disagreed at none (1,292 sides in the final count).
  - *Take the front from the box's frame.* `Front_Of_Zone`: a placed zone fronts the path it was put
    down along. With the front taken from the nearest path, as two corners take it, two checks
    fail: another path flush along its back (the storehouse stood 15.5 m from its own path), and a
    box turned north from a path's end with that path along its south side (10.25 m).
  - *The whole metre.* Eight ways by four quarter-metre offsets on open land of seed 1
    (`$S/yoff.sh`) and in a check: four hundred places and the same storehouse every time, 4.5 m
    from its path's edge (to 4.75 at 45 degrees).
  - *The staging a measured distance.* `Storehouse_Lie` (`colony_run --box-stats`): the ground
    before the front wall to the path's edge, the yard behind, beside its ends. A box: 4.5 m, 10.5 m,
    4.75 and 5.25 m. Two corners of 20 m on the same ground: 5.0 m before it (the half metre drawn
    out to the path).
  - *The cart.* Held over the lord's cart on a first morning: refused in the plan and by the click,
    "the lord's cart stands on it" (a still: `$S/shots/yb_cart_click.png`); with the cart gone the
    same place takes it.
  - *The ghost's cost.* 1.3 ms of the main thread a frame and 0.3 of the card while it is held
    (a stockpile's box 0.4 and none; 2,500 settled frames each).
- **How many places take one** (`colony_run --square-scan 100 20 --yard-census`: one held against
  each side of every square of the ten places, along that side's own path, 1,292 sides): **845**.
  Two corners of 20 m: 848. Two corners of 15 m, the least there was: **985**. A stockpile's box:
  1,288. Refused: no storehouse could stand 98, ground that cannot all be taken 319, no ground for
  its path 30. (He was told 836 of 1,280 and 976: counted before the three squares under trees
  were founded.)
- **Old stockyards are as they were**: the six sites of the script end in the states gate 76's
  build ends in (`$S/yard6.sh`); fifteen saves of that build (a stockyard not begun, half built and
  standing, squarely and at 45 degrees) run on to the same states in both (`$S/yold.sh`).
- **By the tool's click**, release and debug: put down east of a square three days old, saved, run
  on sixteen days: the storehouse stands, nobody died (5 member-hours with an empty belly, counted
  since), no pit. The sheet sent with its report is
  `~/CASTLE_GAME/releases/stockyard_put_down_whole.png` (the box held, put down, refused over the
  cart, built squarely and along a path at 45 degrees).
- **Saved half built and run on** (`$S/yhalf.sh`): along the path at 45 degrees on the flat, saved
  after 0.5, 2, 4, 6, 9 and 13 days: the straight run's state each time. On the hillside, from the
  fourth day on; saved after half a day or two it runs on otherwise, **and so does a stockyard of
  two corners there in gate 76's build, and so does that band with no stockyard at all**: the older
  fault of a colony with housing saved in its first days (CLAUDE.md), not the box's. Still owed.
- **Checks**: a section of sixteen ("the stockyard put down whole, twenty metres square").
  `tools/stockyard_sites.sh` has three more sites (on the hillside; along a path at 45 degrees on
  the flat; along the one that falls, on its other side), and fails unless all four hundred places
  are taken and the storehouse fronts its own path; all nine pass in both modes.
- **A fault of the box found after its commit, mended in the next** (82fa10b had it): on a box turned
  east or north the storehouse had **14 places on its floor for 18**. A placed zone's places are
  counted from its front's beginning less a centimetre (`Box_Edge_M`); `Fit_Storehouse` took a
  place's four blocks from the block its middle lies in, so a column of them (or a row) was judged a
  block further back along the box's way, found "under the wall" and kept clear. Rounded to the
  nearest corner of blocks now; for a zone of two corners, whose middles are exact, nothing moves.
  Seen in the map of a check of the next piece; my trials of the box had read how the storehouse
  lies at every way, and its places only at the ways west and south. A check raises the storehouse
  on the spot at each of the eight ways and counts them (it fails with the mend cut: 6 of 8).
- **What he might take for a fault**: on the side of the falling path where the least stockyard of
  the old script lies, no box of twenty metres is taken (the ground falls more than a storehouse's
  may); a boulder or a pond in the box refuses it whole, where two corners could be drawn round
  them; the advisor's note says "20 m by 20 m with its path: put one down" now.

**Gate 78** (82fa10b, from a clean copy): passed. **Gate 79** (8fa2576, the head with the fourteen
for eighteen mended, from a clean copy): passed. Each: both builds (the six known warnings), the nine
check programs in debug (colony_check 983 and 984), all eight reference logs line for line, the
stockyard's nine sites and the turned streets in both modes, the square's sites in both modes (323
squares founded of 323 planned, four under a tree), the stress runner with every state gate 77's
(six_4_years bcd712a4fd9ea6d9, six_41_days d580854cf5cac587, housing 6794042cea5a9e70, crowd at work
3f7c2c6949cec18c), the flora's hashes (5676219328934879273 in both builds). `bin/` was built from
8fa2576 on 2026-11-21 at 08:54 (release) and 08:56 (debug) with a clean working copy.

## Built: the storehouse twelve metres by eight, a metre and a half from its path (`Set_Store_Size`, `--storehouse 10 5 4.5` is the old)

His clauses g and h ("bring the storehouse forward 3m towards the path so that the fenced area becomes
3m deeper , add 2m to the width of the storehouse, so that it is now 8x12"). **Read as the result he
names, which his own figures add up to**: the storehouse of before is 10 m along its front and 5 m
back; with his 2 m and his 3 m it is 12 by 8; its front wall comes 3 m nearer its path and its back
wall stays.

**What that reading does not give him: a deeper fenced yard.** The fence and the gateways stand in the
back wall's line, and the back wall has not moved: behind it there are 10.50 m of a stockyard of 20,
with the storehouse of before and with this one (`colony_run --box-stats`, and the two stills from
above, old and new, show the fence in the same place). That is 5 m more than the least stockyard of
before had (15 m: 5.5 m), by the larger zone alone. His "so that the fenced area becomes 3m deeper"
and his "8x12" cannot both be had on 20 m (1.5 + 8 + 10.5); a storehouse 5 m back brought forward
gives 13.5 m of yard (`--storehouse 12 5 1.5`). **I wrote for a while that the fence runs from the
front wall's line and the fenced ground was therefore 3 m deeper: it does not, and it was not** (a
still misread; the advisor read `Fit_Storehouse`'s header against it; taken out of every document
before the commit). First in the report, as his call. He was told 7 by 10 first, then that the
default would be 8 by 12: the other readings are one setting away, each tried squarely and at 45
degrees before it was offered (below).

- **Where the build departs from what he was told.** "1.5 m is left before the storehouse" holds
  squarely. **Beside a path at 45 degrees it is 3.5 m**: the storehouse's own blocks stand square to
  the grid about its middle and are drawn turned, and a corner of them reaches further toward the
  path than the front wall is drawn. With 1.5 m, 28 block columns of the storehouse stood off its
  ground, 25 of them on the path, and nothing in the plan refused it (the advisor asked where the
  blocks stand; `Storehouse_Lie.Own_Out` now counts them and the plan refuses any). 14 blocks of
  staging keep them all on its ground, for either size. His call (6 in the report).
- **Changed unasked: the lord's cart's place before the storehouse is looked for** (`Cart_Front`;
  `Set_Cart_Search`, `--one-cart-place` is as it was). It was one place, across the staging; a
  metre and a half has no room for a cart across it. And it turned out that with the storehouse of
  before the cart was never brought at four of the nine test stockyards (its bed did not fit the one
  place; its salt stayed in the cart: older than this round, and nothing asked). Now along the front
  too, either side of the way in, a metre further at a time. All eleven sites fail unless the cart is
  brought and its salt carried in.
- **Taken out before the commit: a rule of mine that gave a stockyard the storehouse of before where
  the new one did not fit** (the advisor: wider than its comment, no check, unasked). A stockyard of
  an older save that is not yet begun and too small or too steep for the larger storehouse gets none;
  the advisor's note then says its ground "will no longer take a storehouse: it has been dug or built
  on since it was zoned", which is not why. Left: there is no save compatibility during production,
  and a stockyard put down now is refused where the storehouse would not stand.
- **How it lies** (`colony_run --box-stats`, the final build): squarely 1.50 m before its front wall,
  10.50 m of yard behind, 3.75 and 4.25 m beside its ends; at 45 degrees 3.50 m (3.75 at the most),
  8.50 m behind; no block column of its own off its ground at any of the eleven sites. Inside, seven
  places by eleven: 57 on the floor (18 before), 8 barrels, 6 shelves, 6 kept clear before the doors.
- **What it costs** (the final build; `$S/y50.sh`, `$S/ycensus.sh`):
  - 828 of 1,292 sides of the ten places' squares take a stockyard with it, 845 with the storehouse
    of before (426 for 442 squarely, 402 for 403 aslant; "no storehouse could stand" 115 for 98).
  - 15,054 to 15,263 blocks in its blueprint on a stockyard of 20 m, 33 to 35 logs, 78 to 79 sheaves
    (before: 11,952 to 12,123 blocks, 21 to 24 logs, 47 sheaves). The stockman is named 10.1 to 10.5
    days after the founding, for 8.1 to 8.2.
  - Fifty days, three stockyards, the new storehouse against the old (hungry serf-hours; lowest
    confidence): along the path at 45 degrees 1,445 for 1,301 (40 for 52); east of the open-land
    square 1,016 for 1,115 (52 for 41); south of the west path 1,216 for 1,205 (42 for 35). Nobody
    died in any (member-hours with an empty belly, counted since: 16 for 26 at the open-land square,
    4 for 0 south of the west path, 6 for 3 along the path at 45 degrees).
  - Refused with it: the hillside sites of the script (its floor too far off its path's level for the
    three steps 1.5 m leaves), and the two stockyards of two corners along a path at 45 degrees that
    are 15.4 and 14.4 m a side. Those sites keep the storehouse of before in the script.
- **The other readings, each run eighteen days squarely (the box south of the west path) and along
  the path at 45 degrees** (the final build; each stands, its places fitted out, nobody starving, the
  cart before it with its salt carried in, no block column of its own off its ground):

  | `--storehouse` | walls | before it, squarely / at 45 | fenced yard behind, squarely / at 45 | floor places | logs, sheaves |
  |---|---|---|---|---|---|
  | (none: built) | 12 m by 8 m | 1.5 / 3.5 m | 10.5 / 8.5 m | 57 | 33 to 35, 78 to 79 |
  | `12 5 1.5` | 12 m by 5 m | 1.5 / 4.5 m | **13.5** / 10.5 m | 26 | 24 to 26, 54 |
  | `10 7 1.5` | 10 m by 7 m | 1.5 / 3.5 m | 11.5 / 9.5 m | 36 | 26 to 28, 61 to 62 |
  | `10 8 1.5` | 10 m by 8 m | 1.5 / 3.5 m | 10.5 / 8.5 m | 43 | 29 to 31, 69 |
  | `10 5 4.5` | the storehouse of before | 4.5 / 4.5 m | 10.5 / 10.5 m | 18 | 21 to 24, 47 |

  (A long thin storehouse reaches further at 45 degrees: 12 by 5 stays 4.5 m off its path there.)
- **With `--storehouse 10 5 4.5 --one-cart-place` nothing moves**: the nine sites' logs are
  82fa10b's line for line (`$S/yard9.sh`, `$S/logsame.sh`: the blob's version is in the state's hash,
  so runs across a bump are compared by their logs), and twenty-seven saves of the builds before
  (fifteen of two corners from gate 76's build, twelve boxes of 82fa10b: not begun, half built,
  standing; squarely and at 45 degrees) run on to the same logs (`$S/yold2.sh`). By today's rules a
  storehouse begun keeps 40 by 20 (23 of them), one not begun gets 48 by 32 (1) or none (3).
  **That is this commit (d714016). At the next (ecbe1a0) 23 of the 27 do**: the four that differ are
  the hillside band's saves of its first two days, whose houses begun after the load now have their
  timbers, which is the lot's mend doing what it is for.
- **By the tool's click**, release and debug (the builds with the next commit's two mends in): put down east of a square three days
  old, saved, run on sixteen days: the storehouse stands, walls 48 by 32, 1.50 m from its path's
  edge, nobody died (13 member-hours with an empty belly, counted since), no pit, the cart before
  it.
- **Saved half built and run on**: 62 saves (the west band with the new storehouse and the old, the
  path at 45 degrees with both, the hillside with the old; `$S/runon_all2.sh`). In this commit's
  build 57 run on to the straight run's state; the five that do not are the three causes of the next
  section, none the storehouse's (with the two that are mended there, 60; the other two are one
  moment, `yh3/new_4.sav` and `yhalf2/west_4.sav`, the route that ends short).
- **Checks**: a section of nine ("the storehouse eight metres by twelve, a metre and a half from its
  path"), a check that a colony of blob 43 loads, one for a trunk on the fire's own column; the pinned
  blob versions 43 to 44. colony_check 996. `tools/stockyard_sites.sh` has eleven sites, passes in
  both modes.
- **Blob 44**: a storehouse's walls, a byte each, after its kind. Blobs 30 to 43 read as 40 by 20.

**Gate 80** (ecbe1a0, the storehouse's size and the two load mends, from a clean copy): passed. Both
builds (the six known warnings), the nine check programs in debug (colony_check 999), all eight
reference logs line for line, the stockyard's eleven sites and the turned streets in both modes, the
square's sites in both modes, the stress runner, the flora's hashes (5676219328934879273 in both
builds). `bin/` was built from ecbe1a0 on 2026-11-21 at 10:36 (release) and 10:38 (debug).

**Blob 44 moves every state's hash: what stands in for "the states of the gate before"** (the
advisor asked before the gate was started). Each run was made in gate 79's build and in this one with
`--save`, and the two saves compared byte for byte (`$S/stress_cmp.sh`, `$S/square_cmp.sh`): **every
pair differs in nine bytes, the blob's version (44 for 43) and the save's own check sum, its last
eight.** None of these colonies has a storehouse, which is all the blob gained.

| run | blob 43 (gates 75 to 79) | blob 44 (gate 80 on) |
|---|---|---|
| six, four years (and on two workers) | bcd712a4fd9ea6d9 | 0f6e9ac3e04d59fc |
| six, 41 days (and read anew) | d580854cf5cac587 | 42613bf288a4dc5e |
| housing, 41 days (read anew; two workers) | 6794042cea5a9e70 | d08378f42ca99dab |
| the crowd as it is | 65a9d38031d4e79a | 21aaf5d3e27b4213 |
| the crowd at work (and its six other ways) | 3f7c2c6949cec18c | 604d849343d51d27 |
| the sloping square as built (the sites script prints it) | e8b03aeb42a10239 | eafd146fcd25809a |
| its walls inside (`--square-walls-inside`) | 89f00438833d9699 | 7707060159d51866 |
| ten metres, walls inside (`--square-10` too) | c49eb1f6773c79b3 | a991f5d1a668fa08 |
| ten metres, no walls (`--no-square-walls` too) | f42bd0412bb19cf5 | b55ae2f49eead7d6 |
| four stockpiles with trees (the sites script prints it) | ead8b40dde19eb1d | 60b001de3190d916 |
| the same at ten metres | 76d134cb35a704c2 | 939db2291481d489 |

The gate's own stress run and sites script printed the right-hand states.

## Built: food and full barrels stacked in the storehouse (`Set_Store_Stacks`, `--no-store-stacks` is the old)

His clause i ("Allow food and full barrels to be stacked in the storehouse"). The heights are the
defaults he was given and has not answered (call 3: baskets three high, barrels two).

- **Measured before any code** (the advisor asked for it: the logs showed the floor nearly empty, so
  would a higher limit ever show a stack?). Fifty days at three stockyards in the build before, a
  look each colony minute (a trial build with a counter in `Advance`): **at most 14, 17 and 19 of the
  floor's 57 places held food at once** (954, 1,309 and 1,384 of berries, apples and vegetables at
  the most); all six meat barrels were full at once at one site for two fifths of the looks (at most
  four at the others); both water barrels full. And with the floor's limit raised threefold in that
  trial build the fullest place reached 283 to 300 % of a place's own: **the stockman puts a load in
  the nearest place that keeps it (`Go_Store`), so a higher place alone makes the stacks**. No rule
  about where he puts things was needed or changed.
- **What was built.** `Place_Limit`: a floor place holds `Floor_Stack` (3) times its own of berries,
  apples, vegetables and grain; a barrel's place twice a barrel once its second stands. The carpenter
  makes a second barrel on a first that is full (`Wants_Second`: what it holds, not what is on its
  way), after the shelves and every first barrel, for a log and a barrel's work. Drawn: a tier of
  baskets to a place's own worth, 20 cm over the one below; the second barrel on the first, which is
  shut then.
- **Chosen unasked, each a line in the report**: water barrels stack as meat barrels do; salt (sacks),
  the yard's places and the places under the coverings do not; a second barrel costs a log and is made
  only on a barrel that is full; a second barrel that stands stays when the switch goes off.
- **Not a blob bump**: a second barrel is 2 in its place's byte for its barrel (0 or 1 before), blob
  44 still, written only for a barrel's place. So states compare across this commit.
- **With `--no-store-stacks` the build is the build before** (ecbe1a0): the nine sites with the new
  storehouse and with the old (18 of 18 states), the 62 saves taken half way (62 of 62), three
  fifty-day runs (states and logs). The storehouse's floor is drawn pixel for pixel as by the build
  before with it off (0 of 1,024,000; the drawing asks no switch: a place that holds no more than its
  own worth is drawn as it always was. With it on a still differs in 1,631 pixels, 62 of them on the
  floor: the band is elsewhere after a few ticks, not the baskets).
- **What it does** (fifty days, three stockyards, on against off; `$S/stk3`): 5, 3 and 4 of the six
  meat barrels stand two high at the end and 645, 534 and 570 lb of meat are kept, for 319, 336 and
  360; both water barrels two high, 48 pails for 24. Hungry serf-hours 1,003 for 1,016 (east of the
  open-land square), 1,276 for 1,216 (south of the west path), 1,237 for 1,445 (the path at 45
  degrees); lowest confidence 60 for 52, **31 for 42**, 37 for 40. Nobody died either way (member-hours with an
  empty belly, counted since: 6 for 16, 44 for 4, 8 for 6). At
  most five floor places stacked at once over thirty days at the west stockyard (1,230 of food on
  the floor at the most, 1,309 with the stacks off). **So: stacking food adds no room that was
  wanted, it puts the food in fewer places; the barrels are where it adds room.**
- **Saved and run on** (`$S/s3_half.sh`): two stockyards with the stacks on, saved after 0.5, 4.5, 9,
  11.5, 13.75 and 16.25 days (the last three with places stacked and barrels two high): the straight
  run's state, 12 of 12. A save taken while the carpenter is making a second barrel (12.4375 days at
  the west stockyard) runs on to the straight state too.
- **His way into it** (the advisor: he will load a save of today's build with a storehouse standing):
  five saves of the builds before, two with the storehouse of 10 m by 5 m and three with the new,
  their barrels made, loaded with the stacks on: eight days on in release and four in debug, nothing
  raised, nobody starving, second barrels made on the full ones (3 to 6 of the six two high, both
  water barrels), baskets stacked. The debug game opened on a save with stacks for four hundred
  frames: nothing raised.
- **Checks**: a section of five ("food and full barrels stacked in the storehouse": what a place
  holds, on and off; the stockman carries 600 berries in, 360 in the fullest place and 3 places for 5;
  a full barrel gets its second and takes 80 lb for 60; it comes back from a save to the same bytes;
  with the stacks off the six barrels fill and none has a second). colony_check 1004. The eleven sites
  pass in both modes with the stacks on.

**Gate 81** (7505b5f, the stacking, from a clean copy): passed. Both builds (the six known warnings),
the nine check programs in debug (colony_check 1004), all eight reference logs line for line, the
stockyard's eleven sites and the turned streets in both modes, the square's sites in both modes, the
stress runner with **every state gate 80's outright** (the blob is not changed: six_4_years
0f6e9ac3e04d59fc, six_41_days 42613bf288a4dc5e, housing d08378f42ca99dab, the crowd as it is
21aaf5d3e27b4213, at work 604d849343d51d27), the flora's hashes (5676219328934879273 in both builds).
The sheet sent with its report is `~/CASTLE_GAME/releases/storehouse_stacked.png` (the same day with
the stacks off and on; close; later with meat barrels two high); the storehouse's own is
`~/CASTLE_GAME/releases/storehouse_twelve_by_eight.png`.

## Where today's square costs: the first night; and the hearth before the whole floor, tried (call 6)

- **When the extra empty bellies fall** (the twelve-day logs, each empty-belly `who:` line by the hour
  of its run and by what its bearer does): **the first day, almost all of them**, asleep or fending,
  after the hearth stands. Fifteen sites: his build's square 21, all in the first day and all asleep;
  today's 85, 83 of them in the first day (65 asleep, 20 fending). The eight heaviest: 36 and 144
  (139 in the first day). Over fifty days the first day has 21 against 83 and the days after the
  twelfth 90 against 92: **after the first night there is no difference.** None is before the hearth
  stands, none with stone or earth in hand.
- **Why**: the band makes the whole floor ready before anyone fetches the hearth's stone and wood
  (`Think_Build`'s order: the ground "from the fire outward", every square metre of it, then the
  ring's stone, then the crossbar's wood), and the cook is at the floor with the rest. On 121 square
  metres for 100, and with banks to cut, the hearth stands later (at the fifteen sites 6.6 h after the founding on the mean
  for 5.1 with his build's square; at the eight heaviest 13.2 h for 9.8); at the heaviest the first
  log then burns the next morning (19.4 h on the mean, 25 at the most; 10.8 and 12 with his square)
  and the first stew is cooked after 28.6 h. No supper the first evening: the band sleeps empty.
- **The hearth before the whole floor, tried in a scratch build** (his call 6, which I had
  recommended and left unbuilt; `Set_Hearth_First`, `--hearth-first`, off unless told; nothing of it
  is in the repository or in `bin/`): the ground within `Hearth_Ground_M` (2.6 m) of the fire first;
  then the ring's stone and the crossbar's wood, and the hearth stands on that; the rest of the floor
  after it; **the cook at its fire once the hearth stands**; beds and the square's walls wait for
  the whole floor as they did. With the switch off the sloping square ends in the head's state
  (nothing is saved for it: what of the floor is left is counted).

  | twelve days, today's square | as it is | the hearth first |
  |---|---|---|
  | **the fifteen sites**: the hearth stands after | 6.6 h (12 at the most) | 1.9 h (3) |
  | the first log burns after | 7.7 h (13) | 3.8 h (6) |
  | the first stew after | 11.5 h (27) | 7.1 h (11) |
  | member-hours with an empty belly | 85 | 6 |
  | hungry serf-hours | 3,307 | 3,142 |
  | lowest confidence, mean and least | 55 %, 26 % | 62 %, 56 % |
  | feet more than a step off the ground, serf-seconds | 219 | 728 |
  | **the eight heaviest**: the hearth stands after | 13.2 h (14) | 2.2 h (3) |
  | the first log | 19.4 h (25) | 3.5 h (4) |
  | the first stew | 28.6 h (31) | 6.8 h (10) |
  | member-hours with an empty belly | 144 | 4 |
  | hungry serf-hours | 2,709 | 1,738 |
  | lowest confidence, mean and least | 30 %, 12 % | 62 %, 60 % |
  | feet more than a step off the ground, serf-seconds | 517 | 1,017 |

  (His build's square: 21 and 36 member-hours.) Thirteen living, the floor done and no pit at every
  one of the 46 runs.
- **What it costs**: the whole floor is done later, and the walls with it (at the 17 walled squares
  they are first wanted after 17.2 h on the mean for 13.4, and done after 20.2 h for 17.2); the band
  lives on the square while its outer floor is still being cut, so **feet are off the ground more**
  (728 serf-seconds for 219, 1,017 for 517; of 3.4 and 1.8 million): with those by the fire set on the
  ground each second while the floor is worked, what is left is of people moving (nobody stands still off the ground at the worst of them); where
  and at what was not looked at.
- **Found building it**: with only the ground by the fire gone to, a hollow there waited for earth
  that only the rest of the floor has (the advisor had said so): the rest of the floor is gone to
  once nothing of the hearth's is left to do. And a hearth that stands with the cook still at the
  floor lit no fire a minute sooner (the first log 25 h after the founding, as before): the band's
  rule that what is marked comes before anyone's job held the cook.
- **Where the trial goes past the words of call 6** ("the hearth built once the middle of the floor is
  level"): the cook leaves the floor for its fire once the hearth stands (without that, nothing came
  sooner); the rest of the floor is opened to whoever has nothing of the hearth's to do, before the
  hearth stands; those by the fire are set on the ground as it is each second while the floor is
  still worked.
- **What the trial did not try**: the debug build; a save taken while the floor is still to finish,
  run on (the switch is not saved, and what is left of the floor is unknown for a second after a
  load); a square whose middle is under a tree; anything past twelve days; a check of its own.
- **Its diff** on the census's: `~/CASTLE_GAME/releases/wip/hearth_first_trial_on_the_census.patch`
  (`$S/hf_one.sh`, `$S/hf_all.sh` measure it). It has no check of its own yet and has not been
  through a gate: on his word it is one bounded pass (a check section, the documents, the gate).

## The stockyard's own retaining walls: counted, and none moved (2026-11-21; his rule 1, call 5)

Call 5 had the stockyard's walls "outside its 20 by 20 in a pass of their own". **Counted before
anything was built** (the advisor: are its stone columns among its places at all?), and the count
says his rule is already met there:

- **Where they stand today.** A storehouse's site is its stockyard's ground, and `Plan_Of` makes a
  column on its rim of stone where the ground beside it stands more than a block over or under the
  yard's level: on the zone's own outermost block column. A census of every stockyard the ten places
  take, each with its storehouse begun (`colony_run --square-scan 100 20 --yard-census --yard-walls`;
  `Castle.Colony.Stockyard_Walls`): **492 of 828 have stone on their rim**, 336 none; the tallest wall
  to two blocks at 201, to four at 167, to eight at 117, over at 7 (ten blocks, 2.5 m, the tallest).
- **What that stone stands on** (38,756 block columns in all; by the stockyard's design, and read
  again from four that are built): treads of the stair and the way in 762; **the ground before the
  line of its back wall, 18,444** (its staging and beside the storehouse's ends: `Fit_Storehouse`
  keeps all of it clear, there are no places there); **the line its fence stands on, 19,550** (the
  sides from that line back, and the back: the fence's posts and rails are on that very column);
  **a place's ground where goods lie with no fence on it: 0, at no stockyard.** Built: the box on
  the hillside has 119 columns of rim stone, 8 stair, 99 before the back wall's line, 11 with the
  fence's timber over them, none on a place for goods; the one on the open land 21, all under the
  fence.
- **So nothing of a stockyard's four hundred places is taken by its walls**: they stand where its
  fence stands or on the edge of ground nothing is kept on. Moving them out would make the zone 25 cm
  larger on a walled side and shift the path on its front, for no place gained. **None built; put to
  him as the answer to call 5**, with the count. If he wants them outside all the same: the back and
  the sides are one bounded pass (no path there); the front needs his calls (the path's shift, the
  stair, a path at 45 degrees), and `Plan_Of` and `In_Site` are the hovels' too.
- **The census tool is in the repository since the afternoon** (the commit before the stair's:
  `Castle.Colony.Stockyard_Walls`, `colony_run --yard-walls`; no rule of the game is touched by it).
- **A stockyard's only stair, counted apart** (for his "if a stair is to be had it's to be at the
  corner of the zone"): it is the flight of **the stockyard's own way in from its path**, which is
  the middle of its storehouse's front, 2 m wide, across the staging (`Store_Way_U`; the
  storehouse's doors are in its ends); it has steps only where the path lies more than a block off
  the floor (`Is_Stair`, a house's rule). **115 of the 828 stockyards have one** (713 have none:
  their path lies within a block of the floor), 6,728 block columns of steps in all; of the 762
  columns of rim stone counted above as "the stair and the way in", 748 are steps; the most
  between a path and a floor 6 blocks. **At the middle of the front, not at a corner: left as it
  is, and put to him** (to move it is to move the stockyard's way in, with the staging, the cart's
  place and the gateways that go by it: a piece of its own, not a stair moved).

## Why a save does not always run on as the straight run does: three causes found (2026-11-21)

Found proving the next piece (the storehouse's size, in a scratch tree): of 21 saves of one colony two
did not run on to the straight run's state. Traced with the runner's lines taken every three colony
seconds (`--log-hours 0.05 --who`), then each cause tried alone in a scratch build. **The first two
are mended** (the commit after the storehouse's size), **the third is owed.** With the two, 60 of 62
saves taken half way run on to the straight run's state (`$S/runon_all2.sh`: the west band with the
new storehouse and the old, the path at 45 degrees with both, the hillside with the old); the two that
do not are one moment, `yh3/new_4.sav` and `yhalf2/west_4.sav`: the route that ends short. With all
three tried in a scratch build, 62 of 62. A straight run is not touched by either mend (the five
straight states are the same with and without them).

- **A lot's house loses its timbers in a save** (the "older fault of a colony with housing saved in
  its first days", owed since the round before): a lot still to begin is saved as its place alone and
  its design made anew from its seed on load, but `Place_House` gives a planned lot the roof's
  timbers, the windows' timber and the ridge beam after designing it (`F.Truss`, `F.Sill`,
  `F.Jambs := False`, `F.Ridge := True`) and the loader does not. **Every house begun after a load
  from a lot planned before it is built as houses were before those passes**: no trusses, no tie
  beams, no ridge beam, plank beside its windows (4 logs and 28 sheaves for 5 and 27). A lot laid
  out anew after the load (a path laid, a zone changed) has them again, which is why it showed only
  in the first days. **Mended**: `Give_Timbers` is what a lot is given when it is laid out and given
  again when it is read. The hillside band saved after half a day and after two runs on to the
  straight state (fcd84133597297b7); without, not (a5cf21e047c586e4). Two checks: every lot the
  same design, whole, across a save (`Lot_Design`: nothing else that is given at planning is lost);
  the houses begun from them after the load have their timbers. With the mend cut: 0 of 3 lots the
  same, 1 of 4 hovels with timbers.
- **An apple tree being picked is nobody's after a load**: reservations are not saved but made again
  from what each of the band is doing, a tree's only for `To_Tree | Chopping`. A gatherer going for
  apples or picking them (`To_Source | Gathering` with `Fetch = Apples`) holds its tree in a straight
  run and not after a load, so another goes for the same tree. **Mended: a tree is whoever's errand
  it is** (`M.Tree`): it is taken and let go together with that in every state, so the loader gives
  it back by that alone (the advisor: a gatherer whose way to its tree fails goes idle still holding
  it, which a rule by states would miss). Counted each colony minute of two thirty-day runs: by the
  old rule a load would have made another holder at 14 and 17 of the looks at a held tree, by whose
  errand it is at none. The save of the apple season's first morning runs on to the straight state.
  A check (with the mend cut: held by nobody).
- **Seen in that count and left**: of two pickers at one bush the loader makes the later of the band
  its holder, where a straight run has whoever came first (44 and 42 looks of about 300). It changed
  none of the 62 runs; exact only with the holder in the blob. Owed with the route.
- **A route that ends short is planned anew after a load** (owed): a route's stamps come out of a
  save with no version, so the first look after a load takes every route's ground for changed; one
  that reaches its goal is walked again and kept, one that ends short (`Partial`: a forester going
  for a log that lies on a bough) is planned anew from where he stands, which a straight run does
  only when its ground did change. Nothing the player sees. Exact only with one more byte a member in
  the blob (whether the ground under its route was as stamped when saved; such a route stamped again
  at the first step after the load); tried without the byte it mends the save in hand but not one
  whose ground had just changed.

## Found on the way

- **A metre of path under a bough was never laid** (commit 17c8aa9, its own switch
  `Set_Metre_Ground`, `--no-metre-ground`): whoever lays a metre goes to its middle "on the ground",
  which was the walking map's highest floor there; under a bough of timber that can be stood on that
  is the bough. On the sloping test site founded eleven metres the north path's third metre lay
  under a tree that stands beside the square and is not felled for it; it was still grass after
  three days, and the wall, which waits for its path, had a gap a metre wide. Now the floor nearest
  the stretch's own height is taken. Older than this round (it is the "path unlaid under low boughs"
  of the list before, or one kind of it); the gated states did not move with it.
- **The scan's "edge columns with no path laid by them" were the last site's cart** (187 at ten
  metres, 701 at eleven on the old grid): the scan founds one colony after another in one world,
  `Reset` leaves the world as it is, and the bed of the last colony's cart, eight metres north of
  where that was founded, stood in the next one's path. `Castle.Colony.Take_Cart_Away` (for such
  tools) lifts it first. With it, and the mend above, 4 such columns are left at ten metres and none
  at eleven. Not a fault of the game: it has one cart, set down after the square is there.
- **A save taken off colony_run's thirty-second beat does not keep step with the straight run** (the
  runner says so when it saves: it packs edited ground anew every thirty colony seconds of its own
  run). My first new half-built save, 744 colony seconds in, ran on to another state two days later;
  saves 741 to 745 seconds in, of every thirty, do, and from no other second. The script's save is
  on the beat now. Nothing of the game's.

## Kept from his build for later proofs

`$S/build/bin/colony_run_d53`, `castle_game_d53` (d53ba6f's code) and four saves of it in `$S/keep`:
a walled square with its walls done (1250 1054, three days), the same half laid (ten game hours in),
an angled one half laid (1130 1142, eighteen hours in), and a square without banks (1150 1062). (The
scratchpad is on tmpfs: after a reboot they are made again from d53ba6f in a worktree.)
