# Routes

- Packages: Castle.Nav, Marks
- Check: path_check (about 40 s)
- Saves: routes are saved with each member in the colony blob
- Stage: phase A

## Routes

Serfs find their way on a map of the ground, not by feeling along it
(`Castle.Nav`). The map is kept in 0.5 m cells, 2 x 2 block columns: about
a body's width, so a cell a serf can stand in has room for it, a 1 m door
always holds one, and a wall, a trunk or a post closes the cells it stands
in.

* **Floors.** A cell has a floor for each level a serf can stand on there,
  up to four: the ground, a bridge's deck over a river, a tunnel under a
  hill, an upper storey. A floor needs all four columns open for 1.75 m
  above it and two of them standing on ground no more than a block lower.
  Each floor keeps its height, the room over it, the water on it and how
  quick it is to cross: a footpath or planks 1.15 times a walk on grass,
  gravel and clay 0.9, rock 0.85, sand 0.75, bog 0.6; tall grass, a grain
  field, bushes or low foliage at the feet slow that further, and wading
  takes 0.55 of it in 25 cm of water, 0.3 in 50 cm. Deeper water and roofs
  are not walked. The floors are read from the column stretches the water
  code keeps for every loaded stack (`Castle.World_Blocks`), a stack at a
  time when a route first needs it and again whenever the stack's ground has
  changed (`Ground_Version`: built, dug, placed on, dropped).
* **A roof is not walked on** (`Ground_Speed`: shingle and, since stage 6a,
  thatch, are floors nobody stands on). So `Surface_Z` under a roof
  answers with the floor inside the house, and a route's end is chosen by
  the height asked for (`Nearest`): a spot inside a house is given at its
  floor's height (the colony takes it from the house's pad, never from the
  map). A hovel's 1 m doorway always holds a cell, whatever its place on
  the block grid (proved for every offset and all four ways a house can
  face before stage 6a was built on it). **That was on level ground.** A
  step down to a door from ground half a metre higher comes under the
  eave and the lintel, and a step wants its head room over both cells: so
  a house's ground has a landing before the door, level with the floor for
  three blocks, and then single steps to the path (`habitation.md`, "Its
  door can always be got to"; found with two of four owners shut out on a
  hillside, and held by `colony_check` on a made-up one).
* **Steps.** Between neighbouring cells a step goes up at most 0.5 m and
  down at most 1 m (so a 1 m ledge is a way down only), with room overhead
  for the body all the way; a diagonal step is allowed only when both cells
  beside it could be walked as well, so no corner is cut past a wall.
* **Cost is time.** A step costs the seconds it takes: the way across at
  the two cells' speed, plus 2.5 s a metre climbed and 0.5 s a metre down
  (0.6 s more for a drop deeper than a step up can be). A* searches the
  floors with an estimate of the time left (the straight line at a
  footpath's speed, plus the least climbing or descending there can be)
  inflated by `Heuristic_Weight` = 1.15, so the search heads for the goal
  instead of fanning out over open country: on seed 1, 2.4 times quicker,
  for routes 0.3 % slower on the whole, and never more than 15 % slower
  than the quickest there is. A footpath is still taken where it saves time
  and not where it doesn't, a river crossed at a bridge or a ford. (At 1.3
  a footpath worth a short detour is no longer taken; `path_check` holds
  that line.)
* **Out of reach, at once.** Each stack's floors are labelled by the
  pieces of ground they make (floors joined by a step either way), and the
  pieces are linked across stack edges (worked out again when either
  stack's ground changes). Before a search, the pieces round the start and
  round the goal are looked over: when either side is wholly known (it
  touches no stack that is loaded but not yet mapped) and doesn't hold the
  other, the goal can't be reached, and the route goes straight to the
  floor nearest it that can be, the same route a search of everything
  would have ended with, without that search. The labels only ever prove a
  goal out of reach (a 1 m drop is a way down only), so anything else is
  searched for as before. A goal cut off by water costs a full search the
  first time (that maps the ground round it) and well under a millisecond
  after; a room with no door is known at once.
* **A way that keeps dry** (2026-11-11, for the herds: `deer.md`).
  `Castle.Nav.Plan (..., Wade => N)` takes no step onto a floor under more
  than N rows of water (a serf wades two, half a metre, which is the
  default and the most). **Since 2026-11-13 the pieces of ground asked
  are those of the plan's own going** ("A herd is told that water blocks
  it", below): until then they were a serf's whatever plan was being
  made, a goal that only wading reaches was not known to be out of
  reach, and it was searched for to the budget every time. Such a plan
  still has a budget (the herds' is 40,000 floors,
  `Castle.Herds.Herd_Budget`), for a way that is there but long.
* **Pulled straight.** The cells found are pulled into straight lines
  wherever a straight line can be walked and is no slower, first over the
  cells, then over those lines. A route is a line of points with the time
  each is reached, and a serf walks it at that pace (slower uphill, wading,
  on sand), scaled by its own speed.
* **Edits.** A route keeps the ground versions of the stacks it crosses.
  Twice a second each walker looks whether any changed; if the rest of its
  route can no longer be walked step by step, or the route fell short of
  its goal, it is planned again from where the serf is. Dig a pit across a
  serf's way and it walks round; lay a bridge and the serfs waiting at the
  bank use it. With nowhere to go a serf waits and tries again every 2 s.

* **Out of reach is always known** (2026-11-11). The looking-over of the
  pieces used to give up wherever the start's ground touched a stack
  that was loaded but not mapped as it is now ("anything may lie there"),
  and with a band at work some stack of the ground always is: an edit
  anywhere in it since it was last looked at is enough. Then the goal was
  searched for through everything in reach. A gatherer making for apples
  up a tree did that about once a game day: 131,000 floors and 55 ms, a
  frame held at any speed. Such a stack is now mapped, or mended, there
  and then (`Castle.Nav.Map_On_The_Way`), so the question is always
  answered and the route goes straight to the nearest floor in reach:
  the reference band's slowest plan in 41 days is 17 ms where it was 62
  (and that one is a herd's dry way running out of its own budget), and
  its planning takes 2.1 s in all where it took 3.4. **This changes
  where some routes end**: the nearest floor by the pieces is not always
  the very floor the long search ended on (the two break ties otherwise),
  and which of the two a route got used to hang on whether a stack
  somewhere had been edited lately. So the runs moved, from the day the
  apples ripen: the seven reference logs were regenerated with this
  change, and the first winter came out otherwise (`needs.md`).
* **Mended, not read anew** (2026-11-11). An edit changes one cell of a
  stack's 256, and a cell is read from its own four columns and nothing
  else. `Castle.World_Blocks` now remembers, for each stack, the last 48
  columns edited and the version each gave it (`Changes_Since`), and
  `Castle.Nav.Stack` reads again only the cells over the columns changed
  since it last looked; the pieces of ground are worked out again only if
  a cell came out otherwise (a berry picked changes no floor), and the
  borders between stacks go by when a stack's cells last changed
  (`Shape`), not by its version. A stack kept anew by a rebuild, dropped,
  or edited in more columns than are remembered is still read whole. The
  map is the same either way: with assertions on (the debug build) every
  mended stack is read whole beside it and compared, cells and pieces
  (`Check_Mended`: 3,051 mends in the reference band's year, none
  otherwise). `Castle.Nav.Mending` off reads every changed stack whole,
  as it was.

F6 (or `--paths`) draws each walker's route over the ground (red when it
can't reach its goal), and F7 (`--navmap`) the map itself 30 m round the
camera: every cell a serf can stand in at the level nearest the camera,
coloured by speed (blue a footpath or planks, green grass, yellow sand or
rock, orange bog or brush, red wading). Where nothing is drawn, no one
walks.

```sh
# a 2 m pit dug across a walker's way after it has set out, routes shown
./bin/castle_game --at 1175 1075 --walk 1167 1075.2 1183 1075.2 \
                  --dig 1173 1073 14.25 1177 1077 16.5 --late --paths --cam 2.6 0.75 13
# a plank bridge over the river by 958 913, three walkers, routes and the map
./bin/castle_game --at 958 913 --fill 948 908.5 16.0 968 910 16.2 --walk 940 921 975 899 \
                  --walk 941 935 976 935 --walk 975 925 942 904 --paths --navmap --cam 2.2 0.95 34
```

## What routing costs, and what was done about it (2026-11-11)

John, after the stress test, with a note from the design side: "that is
for pathing optimization, up to you how we implement it". The note, in
short: (1) trips through anchors (storehouse, workbench, field gate), the
leg to the nearest anchor planned fresh and the way between anchors a
remembered plan, so the store of plans is a pure cache and stays out of
the save; (2) replan only when a route's own cells change, not on any
edit in a stack it crosses; (3) rebuild the walking map only round the
edited cells, once a colony tick, which "goes after the cost the profile
actually flagged"; (4) a coarse graph over the stacks, with the player's
paths as its main links.

It was measured before anything was built (`colony_run --nav-stats`: the
seconds in the colony's steps, the map's reads, every plan; the twelve
slowest plans with where from and where to). The reference band with its
standing orders through 41 days, and a band of forty-eight through 12:

| | six, 41 days | forty-eight, 12 days |
|---|---|---|
| the colony's steps, in all | 8.3 s | 30.5 s |
| ... in planning routes | 3.4 s (13,734 plans) | 4.9 s (20,578) |
| ... of which plans of 5 ms or more | 2.4 s in 87 | 2.5 s in 191 |
| ... in reading the walking map | 0.2 s (4,493 stacks, 1.15 M cells) | 0.5 s (11,326 stacks, 2.9 M cells) |
| the slowest colony second | 62 ms | 62 ms |

What that said of the note's four:

- **(2) was already so.** A route is not thrown out by an edit: twice a
  second a walker whose stacks have changed walks the rest of its route
  again (`Still_Good`) and keeps it if it can still be walked. That
  re-walk is cheap: 2,143 of them in the 41 days.
- **(3) was so, and was not the cost.** Every edited column gave its
  stack a new version, and the map read all 256 cells of the stack and
  labelled it again the next time anyone looked: but that was 2 % of the
  colony's time. What the profile had flagged under the map's name was
  the colony searching for sources through it (below). It is mended now
  all the same ("Mended, not read anew", above): exact, and half to a
  quarter of the cells.
- **What cost most was a search of everything in reach** for a goal
  nobody can stand at (fruit up a tree), whenever the pieces of ground
  could not prove it out of reach: 55 ms, about once a game day, in a
  band of six. Fixed ("Out of reach is always known", above); this is
  the one change here that moves where anyone walks.
- **(1) and (4) are not built.** After the rest, planning is 2.0 s of the
  six's 5.9 s, its slowest plan 17 ms (a herd's dry way running out of
  its own budget of 40,000 floors: 54 of those are 0.85 s of it; known
  out of reach and refused since 2026-11-13, below), and
  4.7 s of the forty-eight's 9.1 s, its slowest 28 ms (a way of 99 m
  through the forest, 61,000 floors looked at: 175 plans of 5 ms or more
  are 1.9 s). Those long ways are what a coarse graph would take to a
  millisecond or two. It would also change where everyone walks (through
  the gates between stacks, or through the anchors), so every reference
  log would move again; the anchors the note names are buildings stage 6
  has still to make; and a band of six has no way long enough to want
  it. The pieces of ground and the borders between stacks are its start,
  and they are always current now. It is for when there are zones to
  anchor to, or dozens of people.

**A plan that ran out of budget is remembered** (2026-11-13; John, of the
stress runner's crowd taking 22 s for 12 with the lord's cart pulled: "then
the stress test for the cart issues";
`docs/handoffs/Handoff_2026_11_13_herds_search.md`). What was found, with
`colony_run --nav-log FILE` (every plan that runs out of budget as it
happens: when, from where to where, its budget and wade, what the pieces
of ground had said, and who of the band stood nearest):

- 737 plans ran out of budget in the crowd's sixty days with the pull, none
  without; 721 of them were one question, a herd's flight from (1200,
  1030) to a place 30 m off, asked every three seconds for some forty-two
  hours (from six in the morning of day 24 to the midnight after day 25),
  each a search of 40,000 floors (14 to 16 ms): 10.7 s of the run's 23.
- The pieces of ground said the place could be got to every time (`MET`:
  a serf's, who wades), and the search, kept out of water deeper than a
  quarter metre, could not get there: the known limit above, a herd's dry
  way running out of its own budget.
- It was asked again and again because a forester stood 8.8 m from the
  herd's node all that time, a log in its arms and "nowhere to put
  wood" (twenty of the forty-eight stand so from the second day, with the
  pull or without, eleven with berries, six with wood and three with
  vegetables at the fifth midnight: the stockpile is full): whoever is within 15 m of a
  deer startles the herd again every three seconds (`Settle_S`), and a
  herd with no dry way out stays where it is. (The herds' flight was
  changed the same day, at his word: `deer.md`. On that band's history
  the crowd's sixty days have 40 such plans, none asked twice, and take
  13.8 s with the memory or without; the figures here are the commit
  before it.)
- The ground does not answer otherwise for the pull: the same way asked
  of the ground without the pull, with it, and with the reference band an
  hour old runs out of budget the same (`colony_run --try-plan`). With
  the pull the crowd is only left standing in other places. Why one of
  them is by that herd in each of the eight starts tried with the pull,
  and in none without, is not found.

What was built keeps work and changes nothing: `Castle.Nav.Plan` remembers
a plan that ran out of budget (its route, by where it was from and to, its
budget, weight and wade, and by the version of every stack in a box round
everything it read: the cells it looked at and the pieces of ground it
went by, a stack more each way; sixteen at most; not one the pieces of
ground called out of reach, whose other goal is picked from stacks far
round), and answers the same question from memory while none of that
ground has moved. **It mends the herd that cannot move at all, which is
what the herds did when it was measured** (17bde03): the crowd's sixty
days took 13.3 s for 23.6 (706 of the 737 from memory), the same state;
from half past six, twenty days, 9.9 s for 19.1 (659 of 935), the same
state. **With the herds' flight in a chain (the same day, at his word) it
answers nothing in the five starts tried**: 5, 0, 25, 502 and 7 plans run
out of budget, none asked twice to the decimetre. From half past eight a
forester stands 9 to 14 m from a herd through days 28 to 30 with nowhere
to put its wood, and the herd flees a short way and is back every four or
five game minutes, each flight's first way a search to its budget from a
place a hand's breadth from the last: 7 s of that run's 13. The stress
runner's own crowd (from seven) takes 13.7 s on that build because its
history has no herd so placed, not because anything was remembered. What
ended the cost is his answer to the calls, built the next day ("A herd is
told that water blocks it", below): the memory has answered nothing
since. `Set_Spent_Memos` (`colony_run --no-memos`) switches it off,
`tools/stress.sh runner` runs the crowd both ways and compares the
states, and `path_check` has it on a made-up river with a ford further
off than the plan's budget (asked again: from memory, the same way point
for point; asked as a serf goes, to be refused, kept to a region, or the
ground moved: searched again). `--nav-stats` says how many plans were answered so and,
of those that ran out of budget, what the pieces had said.

**A herd is told that water blocks it** (2026-11-13; John, answering the
calls above: "Ok, lets do a mix, a person standing still doesn't frighten
a herd, and let them know that water blocks them, when we get to the
stockpile mechanics we will reserve a portion of the stockpile for
overflow"). The second of the three, in `Castle.Nav`:

- **Pieces of ground by the going.** A stack keeps a serf's pieces as it
  always has (worked out with its floors), and beside them, when a plan
  first asks, the pieces that can be gone over no deeper than no water at
  all and no deeper than a quarter metre (`Set_Of`, `Label`: a floor
  under more water than the going allows is of no piece). They are
  worked out again when the stack's floors have changed (`Shape`, which
  the borders between stacks already went by) and not before; 7
  millionths of a second a stack. A plan asks the pieces of its own
  going: a serf's plans read what they read before, to the bit (the six
  reference logs with the herds as they were are line for line).
- **A plan can be kept to a region** (`Plan (..., Within => (X, Y, R))`:
  the stacks any part of which lies within R metres of a point). What is
  outside is no ground to it: not stepped on (`Cell_At`), not looked over
  (`Gather`), and a goal its pieces do not join inside the region is out
  of reach whatever lies beyond. The herds' is 76 m round the stake
  (`Castle.Herds.Dry_Reach_M`): every such stack is ground the colony
  keeps loaded wherever the camera is (the game keeps the stacks within
  eleven of the stake's), so a herd is answered the same whether its
  ground is looked at or not, and the looking over is of some three
  hundred stacks at most however much is in view.
- **A plan can be refused** (`Refuse => True`): out of reach by its
  pieces, it is not made for at all: no search, no route. A herd's ways
  are asked so (`Castle.Herds.Go`), and its flight and its grazing try
  their next direction. (Not refused, such a plan ends at the floor
  nearest its goal that can be got to, as a serf's does.)
- **Measured** (seed 1, against the commit before): the cornered herd's
  own question, asked of the crowd's ground at its twenty-ninth day
  (`colony_run --try-plan`), is truly out of reach: searched for with no
  budget it runs out of ground at 114,643 floors (55 ms) and ends at the
  bank. Refused, it costs 0.08 ms. The crowd of forty-eight, twenty days
  from five starts (half past six to nine): plans out of budget 5, 0, 25,
  502 and 7 before, **none in any of them now**; 7, 8, 9, 546 and 240
  ways refused (44 ms for the 546); the run from half past eight takes
  6.4 s for 13.1, the others as they did. The stress runner's sixty days:
  none for 40, 12.9 s for 13.7. The reference band's forty-one days: none
  for 16 (they were its slowest plans), 37 refused; 15 deer with 45
  arrows where it was 16 with 37, all six living either way. The memory
  of spent plans answered nothing in any of these runs: it has had
  nothing to remember since.
- **Proved on the real world.** `colony_run --prove-dry` (`Castle.Nav.
  Prove_Dry`; slow) searches for every dry way the pieces call out of
  reach with the pieces off and no budget, over all the ground the plan
  may go on, and stops the run if one is found; and works a stack's dry
  pieces out again beside the kept ones each time they are used. Run
  through the crowd's twenty days from half past eight and from nine and
  the reference band's forty-one: 546, 240 and 50 answers, each borne
  out, and the states the same as without it. `path_check` has the made-up
  river (a serf's way by a ford; a hand of water: there too; dry: out of
  reach at once, 40 floors looked at; refused: none; a causeway laid and
  taken away; a region with the ford in it and without; a nearer crossing
  outside the region not taken), and `colony_check` a herd on one bank of
  a river with someone walking up behind it. `tools/stress.sh runner` runs
  the crowd's sixty days with the proving on and wants the same state
  (`crowd_prove_dry`): the made-up worlds of the checks read every changed
  stack whole, so only a run on the real world tries kept pieces on mended
  stacks.
- **What is left.** A way that is there dry but longer than the herd's
  budget is still searched for to the budget (the pieces say it can be
  got to): none in the runs above. A herd whose every way is refused is
  asked again each time it is frightened, 29 refusals at most, some 2 ms.

Not built, and his to say: a herd that found no way out being let be for
a while (he took up two of the others, and it is no longer what costs).
One who stands still frightening a herd: his answer above, built in the
commit after this (`deer.md`: the crowd's herds are then frightened 13 to
24 times in twenty days where it was 612 to 4,462, and the stress
runner's sixty days take 9.1 s where they took 12.9 and, before either
rule, 13.7). A serf with nowhere to put its load standing where it
is for days: the stockpile's, of which he has said one thing ("we will
reserve a portion of the stockpile for overflow").

What else the profile showed, none of it routing, all of it fixed without
moving a step of any run (the states of the runs are the same with each
switched off: `colony_run --no-mending --no-memos`, which `tools/stress.sh`
now runs):

- **A search for the nearest source** (straw, stone, water, wild
  vegetables: `Find_Source`) read every cell's floors and blocks of every
  flagged stack again each time anyone looked: with forty-eight hungry,
  more than a third of the colony's time. What a search finds in a stack
  is kept until that stack's ground, or the ground just beside it,
  changes (`colony.md`).
- **The edit store was asked about every block** of a stack with an
  edit anywhere in it (`edits_and_saves.md`).
- **The indexing pass** walked the whole square inside each ring of
  stacks to find the ring, twenty times a second (`Index_Some`).

After all of it, the same two runs:

| | six, 41 days | forty-eight, 12 days |
|---|---|---|
| the colony's steps, in all | 5.9 s | 9.1 s |
| ... in planning routes | 2.0 s (12,112 plans) | 4.7 s (23,820) |
| ... in reading the walking map | 0.12 s (0.65 M cells) | 0.16 s (0.76 M cells) |
| the slowest colony second | 18 ms | 46 ms |
| the slowest plan | 17 ms | 28 ms |

And where John saw it, in the game: forty-eight at the camp at 240 times
speed in a storm, thirty seconds, twice each: the CPU's frame 11.1 and
11.7 ms on average before and 2.9 and 2.6 after; frames over 50 ms 72
and 81 before, 5 and 5 after (the frame the band is set out in, and the
half hour on the third day in which all forty-eight find the
stores empty and plan at once); the worst frame 245 and 434 ms before,
211 and 237 after. The stress test's year of forty-eight in the runner
takes 25 s where it took 77.

`./bin/debug/path_check` tests routes on made-up ground where the answer is
known (open ground, a wall with a door, a 25 cm slit and a 50 cm gap, a pit,
a ledge with a ramp, 0.5 and 0.75 m steps, a stair, a river with a bridge
and a ford, a footpath worth a detour and the same one not, a tunnel under a
hill and one too low, a closed room (known out of reach at once), a room
whose door is shut and opened again, a wall built across a route), then
plans routes between random points on seed 1's own ground (`--real N`, 0 to
skip), each also with the labels off and no inflation, to check that the
labels never call a reachable goal out of reach and that the routes stay
within 15 % of the quickest. In release, 200 routes of up to 170 m take
0.9 ms each on average (26 ms at most: a goal cut off by water, the first
time), run 0.3 % slower than the quickest and 1.5 % longer than the
straight line; a cut-off goal asked for again takes about 0.6 ms.

Not there yet: the first time a goal is cut off on ground not mapped yet,
it is still found out by searching all that can be reached; routes of
hundreds of metres want a coarse graph over stacks above this map (the
pieces of ground and their links are its start); snow slows no one; ladders, doors that
shut, swimming, and serfs keeping out of each other's way.
