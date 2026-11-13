# Castle Game handoff (2026-11-11: what routing and the colony's steps cost, and what was done about it; built on John's word "up to you how we implement it"; accepted as built the same day and merged into `main`; Claude Code)

- **Closed: accepted as built.** John, after trying it: "perfect, everything checks out, looks awesome and works great".
  Branch `pathing` (on top of `sky-and-weather`, accepted in the same words) is fast-forwarded into `main`
  and kept. One change here moves where people walk, so the seven reference logs are regenerated and the
  first winter comes out otherwise; everything else changes no run. His calls below were not taken up
  and stand by default: first, call 1, the change that moved the runs.
- Code: GAME_alpha_1_3/compiled, branch `pathing`.
  - 931b453 the walking map mended, the edit store asked only about edited columns, counters (exact);
  - c8e1c4a a goal out of reach always known for one (moves where some routes end: the seven logs);
  - 5368976 the source memos, the indexing rings, the switches that turn the work-savers
    off (exact); documents after, and `sky-and-weather` merged in again for its last commits (John's
    answer in the documents; the afternoon moon; the second demo).
  - Zip: CASTLE_GAME/releases/castle_game_pathing.zip (a `git archive` of the branch). No demo: there is
    nothing to see but frame times.
- Checks, and which build each was run on:
  - On 5368976, the last commit that changes the colony, the walking map or the runner: debug and
    release with the six known warnings and no other; all nine checks pass in debug (colony_check 422);
    `tools/reference_check.sh` holds the seven logs as regenerated in c8e1c4a, line for line; the
    reference band's year in the debug build, where every mended stack of the walking map is read whole
    beside it and compared (3,750 mends), ends in the release build's state; all of `tools/stress.sh`
    (docs/production/Stress_test.md, "Run again after the pathing work"): nothing died, the colony the
    same on two and three workers and the same with the walking map read whole and no source memos, one
    thing dropped as on `main` (the view of 512 m), and the debug build's game through a year of weather
    at 240 times speed, checking every mend, raised nothing.
  - On the merge after it (7768aab: `sky-and-weather`'s afternoon moon, a change to one shader): both
    builds again with no new warning, the nine checks and `tools/reference_check.sh` again, all passing.
  - On the commit after that (one line the game prints with `--hitch`): the game alone was rebuilt, and
    the debug build's game was run with the band digging its camp's floor and laying its path in water
    poured over the site, the walking map read every frame (`--navmap`): 191 stacks mended and compared,
    water awake in 30 stacks, nothing raised.
- Versions: **none moved.** `Generator_Version` 13, save format 6, colony blob 17. Nothing new is saved:
  what was added is kept to save work and is forgotten on a load. The reference logs moved (c8e1c4a).

## John's words (2026-11-11)
After the stress test and the report of the sky's first round, with a note pasted from the design side:
"One of the discussions I was having in the project [the note] , that is for pathing optimization, up to
you how we implement it."

The note: "Repeatability without saving the store. The store only has to be saved if the routing rule
depends on what's in it, as in 'use a stored route when one exists, otherwise plan fresh'. Fix the rule
instead: trips always go through the anchors (storehouse, workbench, field gate). The serf plans its
short leg to the nearest anchor fresh, and the anchor-to-anchor part is just a remembered plan. After a
load the store starts empty, the same plans come back out, and the walk is identical. The store is then
a pure cache and stays out of the save. Construction. Two changes narrow the churn: Replan only when a
route's own cells change. A route keyed to stack versions is thrown out by any edit anywhere in that 8 m
stack. Keep a short list of the cells each edit touched, and replan only when one of them is on the
route or right beside it. A builder placing blocks at the far end of a stack then stops invalidating
every trip through it. Rebuild the walking map locally, once per tick. Rebuild only around the edited
cells, and once per colony tick rather than once per block placed. That goes after the cost the profile
actually flagged, which a route store can't touch. The coarse graph. Stored routes between zones is
hierarchical pathfinding (HPA*). Your stacks are natural clusters and already carry the version numbers
it needs, with the player's paths as the main links."

How it was read: "up to you how" as leave to find out what costs and fix that, with the note as where to
look first, not as four things to build. So it was measured before anything was changed, and what was
built is what the measurements asked for, which is not quite what the note expected.

## What the measurements said of the note
- **"A route ... is thrown out by any edit anywhere in that 8 m stack": it was not.** A walker whose
  stacks have changed walks the rest of its route again, twice a second, and keeps it if it still can be
  walked (`Keep_Route_Good`, `Still_Good`). That re-walk is 2,143 times in the reference band's 41 days,
  and cheap. Nothing was changed.
- **"Rebuild the walking map locally ... the cost the profile actually flagged": the map did rebuild a
  whole stack for every edit, and it was 2 % of the colony's time.** What the flat profile showed under
  the map's name (`Floors_At`) was the colony reading the map cell by cell to search for sources. The
  map is mended now anyway: exact, cheap to do, and it makes the fix below cheap.
- **The store and the coarse graph: not built.** What they would speed up is the long way, and after the
  rest the long ways are a 17 ms herd's plan for six and 28 ms forest crossings for forty-eight. They
  change where everyone walks, their anchors are stage 6's buildings, and six people have no way long
  enough. `routes.md` has the numbers.

## What John gets
1. **The stutter about once a game day is gone.** A gatherer making for apples up a tree searched all
   the ground in reach for a way to the fruit before giving up and standing under it: 55 ms, a held
   frame at any speed. It is known out of reach for one now, at once.
2. **What he watched in the stress test runs three to four times lighter.** Forty-eight at the camp at
   240 times speed: the CPU's frame 11 to 12 ms before, under 3 after; frames over 50 ms 72 to 81 in
   thirty seconds before, 5 after.
3. **The reference band's first winter comes out otherwise**: all six see the spring where one died
   (Alys, the forester: so the band goes on felling, 137 trees in four years where it was 40), and with
   no forester two die where none did. No rule of the colony changed (his call 1).
4. Nothing else he can see.

## His calls (what I decided that he may want otherwise)
1. **One change moves the runs, and I made it.** When a goal cannot be reached, the route ends at the
   nearest floor that can. That floor was found two ways: by the pieces of ground, at once, or, when a
   stack somewhere in reach had been edited since it was last looked at, by searching everything; the
   two do not always end on the same floor (they break ties otherwise), and which one a route got was an
   accident of what had been dug lately. Now it is always the first. So from the day the apples ripen
   the reference run goes otherwise, and its winter with it: the logs were regenerated in that commit,
   and `needs.md`, `deer.md` and the framework say what moved. The winter's figures were never more than
   "it turns on a hunt or two"; if he would rather the old runs stood, `Castle.Nav.Map_On_The_Way` off
   gives them back, with the stutter.
2. **The coarse graph and the route store are left for stage 6 or after** (above).
3. **Herds were not touched.** A herd's dry way that only wading would reach still searches to its own
   budget (17 ms, about once a game day): the slowest thing left in a band of six.
4. **The colony's own costs were fixed where they were found**, though they are not routing: the source
   search, the edit store, the indexing pass. All three change no run.

## Built
- **Counters** (931b453): `Castle.Nav.Totals`, `Slowest`; `Castle.World_Blocks.Stamps_By_Edit`,
  `Stamps_By_Stack`; `colony_run --nav-stats` prints them with the seconds in the colony's steps and the
  longest colony second.
- **The edit store asked only about edited columns** (931b453): `Castle.World_Blocks` keeps a bit a
  column for each edited stack (`Edit_Notes`); `Block_At` asks `Castle.Edits.Find` only for those.
- **The walking map mended** (931b453): `Castle.World_Blocks.Changes_Since` (the last 48 edited columns
  of a stack with the version each gave it); `Castle.Nav.Set_Source (..., Changes)`; `Castle.Nav.Stack`
  reads again only the cells over them and labels again only if one changed; borders by `Shape`;
  `Check_Mended` under assertions; `Castle.Nav.Mending`.
- **Out of reach always known** (c8e1c4a): `Gather` maps or mends a stale stack on the way instead of
  calling the question open; `Castle.Nav.Map_On_The_Way`.
- **Source memos**: `Source_Memo`, `Read_Stack` in `Find_Source`; `Castle.Colony.Set_Source_Memos`.
- **Indexing rings**: `Index_Some` walks each ring's own stacks only.
- **Switches for proving the work-savers change nothing**: `colony_run --no-mending --no-memos`;
  `tools/stress.sh runner` runs the reference band both ways and compares the states.

## Measured (seed 1, the reference site, the reference run's standing orders; `colony_run --nav-stats`)

| | six, 41 days: before | after | forty-eight, 12 days: before | after |
|---|---|---|---|---|
| the colony's steps, in all | 8.3 s | 5.9 s | 30.5 s | 9.1 s |
| in planning routes | 3.4 s | 2.0 s | 4.9 s | 4.7 s |
| plans of 5 ms or more | 87, 2.4 s | 78, 1.05 s | 191, 2.5 s | 175, 1.9 s |
| the slowest plan | 62 ms | 17 ms | 59 ms | 28 ms |
| the slowest colony second | 62 ms | 18 ms | 62 ms | 46 ms |
| reading the walking map | 0.20 s, 1.15 M cells | 0.12 s, 0.65 M | 0.52 s, 2.9 M | 0.16 s, 0.76 M |

- By change, forty-eight's 12 days: the source memos 29.8 s to 9.1; mending 9.6 to 9.0; the edit store
  and the indexing rings a few tenths each. Six's 41 days: the out-of-reach proof 8.2 s to 6.9; the
  indexing rings 6.9 to 6.0; the rest a tenth or two each.
- The stress test's runner part: the reference band's four years 58.1 s (62.8), all six living (five);
  forty-eight's year as the game has it 25.2 s (76.6); forty-eight at work 15.1 s (21.4). 461 MB.
- In the game, forty-eight at the camp, 240 times speed, a storm, thirty seconds, twice each: CPU a
  frame 11.1 and 11.7 ms before, 2.9 and 2.6 after; frames over 50 ms 72 and 81, then 5 and 5; the worst
  245 and 434 ms, then 211 and 237 (the half hour in which all forty-eight find the stores empty).
- The debug build's game, the reference band through a year of weather at 240 times speed: 399 s for
  its 22,000 frames where it took 530; the CPU's frame 1.9 ms on average where it was 6.3, and 0.21 s
  at worst where it was 1.3 s.
- Exactness: the states of the two measuring runs were the same before and after each of the exact
  changes (c8a723f2fc32319a and 036e99210667aa36 up to c8e1c4a; 6a4db8e8394b1806 and 08fc0669891bceb5
  after it), and are the same with `--no-mending`, with `--no-memos` and with both. So are the stress
  test's three long runs with both off: the reference band's four years (0c40aa82baadfbdb), forty-eight's
  year (6fa38c4b974def68) and forty-eight at work for a year (a47b51189548187d).

## Saves
Nothing new. The memos and the notes of edits are forgotten on a load, and nothing is decided by
whether they are there.

## Options
`colony_run --nav-stats`, `--no-mending`, `--no-memos`. The game's `--hitch MS` also says, at the end,
how many stacks of the walking map were read whole and how many mended.

## Bugs found and fixed
Already in `main`, none of them a wrong answer, all of them time:
- A goal out of reach searched for through everything in reach, whenever a stack somewhere had been
  edited since the map last looked at it (his call 1).
- Every search for a source read the ground again.
- `Block_At` asked the edit store, a protected call, for every block of a stack with one edit in it.
- `Index_Some` walked a square to find its rim, for every ring, every step.

Mine, in this work, in no build John has had:
- The first form of the edit log could not tell whether it still held every change since a version: its
  entries are stamped with the world's count of changes, not the stack's, so a gap proved nothing. It
  keeps the version of the newest entry it has let go, and says "all of it" for anything older.

## Known limits
- The mended map is proved the same as the map read whole only where it is checked: under assertions
  (the debug build), which every debug run does for every mend. `path_check` and `colony_check` use
  made-up worlds with no edit log, so they read whole.
- `Changes_Since` remembers 48 columns a stack; a tree felled in one go is more, and that stack is read
  whole (as before).
- The first out-of-reach question in a newly loaded view maps every loaded stack the ground reaches:
  about 45 microseconds a stack, 60 ms for the default view, once.
- Measured in the runner, which has no live water; the game's figures are the two runs above.
- Live water and the mended map: nothing the walking map reads is written by the water. It reads the
  kept summary of the ground and the blocks; the summary is written by `Keep` (a whole stamp) and
  `Reground` (a logged column), the blocks by `Keep` and by the edit store, whose only writers are the
  game's two edit paths, and both call `Note_Edit` and `Reground` for every column they touch. That is
  by reading the code, and by the one run in "Checks" with poured water; source water woken by a cut
  with the band at work beside it was not run (the reference site has no water near, and the lake's
  shore is too steep to camp on).

## Not done
- The route store, the anchors, the coarse graph (his call 2). A budget for the colony's steps in a
  frame (left out on his word).
- A herd's dry way known out of reach without a search (his call 3).
- `Held`, the food held back for winter, is asked for by every member every think and adds up the
  stores each time: about a tenth of forty-eight's time now. Found, not touched.

## Next
- Accepted and merged (the top of this file). With the acceptance he asked for one change to the
  water's look, falls that arch and stand off the wall: the handoff after this one.
- Then stage 6, his to open. For its builders: an edit costs the walking map one cell now, and a route
  through a stack being built in is walked again, not planned again, unless a block lands on it.
