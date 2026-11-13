# Castle Game handoff (2026-11-11: extra hands limited; a stretch of path to a serf; the camp's floor levelled and its earth stored; between stages 5c and 6; closed 2026-11-11 as built; Claude Code)

- **Closed.** Built from John's answer on the paths and reach work, with first rules and values of mine,
  and put to him with the build. He closed the session on the report of it ("John's answer", below): it
  stands as built, first values, his to tune. `hands-and-level` is merged into `main` (fast-forward).
- **Stockpile mechanics are rolled in with stage 6, by his decision, and he opens that in a new session.**
  Nothing of it is designed, here or anywhere, and there is no stage 6 brief yet: wait for him. Earth in
  store is only a heap nobody asks for.
- Code: GAME_alpha_1_3/compiled, branch `hands-and-level` from `main` at b14220c (paths planned and laid, no
  limit on how far: closed and merged the same day). Four code commits: 761f4e6 (the limit), 74efb35
  (stretches), 00639ab (the floor), a842e89 (the earth's fetching gated, more checks, with the documents and
  the demo's script); documents only after that. The zip is the closing commit:
  CASTLE_GAME/releases/castle_game_hands_level.zip, remade from `main`. Demo: hands_and_level.mp4
  (tools/demo_hands_level.sh), 41 s.
- Checks: all nine pass in debug from a clean copy (`git archive`) of a842e89, built from nothing, with the
  six known warnings; `tools/reference_check.sh` passes there, all six runs. colony_check 358 -> 404.
- Versions: Generator_Version 12 and save format 6 as they were. Colony blob 15 -> 16. Older blobs load;
  `tools/colony_v15.bin` was written by `main` before the format moved.

## John's words (2026-11-11, on trying the paths and reach build)
"excelent, the framework is starting to take shape, we should limit the amount of workers that can perform
extra tasks, for roads I suggest that when a serf starts compacting a road they are assigned a stretch, say
20m for example, the campfire, I have tested it on uneven ground, and it causes some issues with the logs and
such, so I think we need to have them level the terrain at least for the compacted part, they can move the
dirt to the stockpile, then we are going to work on stockpile mechanics"

How it was read:
- "excelent, the framework is starting to take shape": the paths and reach work is accepted as built (closed,
  merged; its handoff has the record).
- "limit the amount of workers that can perform extra tasks": a number of hands, over everything the band does
  that is nobody's job. He gave no number.
- "when a serf starts compacting a road they are assigned a stretch, say 20m": the stretch is that serf's; one
  serf to a stretch; 20 m.
- "level the terrain at least for the compacted part": the ground within 2.6 m of the fire, where the turf is
  trodden and the seat logs lie. Not the rest of the camp's square.
- "they can move the dirt to the stockpile": earth is a thing, carried and stored. What a hollow of the floor
  takes goes there first; what is over goes to the stockpile.
- "then we are going to work on stockpile mechanics": the next topic, his to open. Not this build.

## John's answer (2026-11-11, on the report of this build)
"great, I think we are at a point to end the session,
I have decided to roll the stockpile mechanics in with phase 6, becuase there are a lot of overlap,
I will start that in a new session"

How it was read:
- "great ... we are at a point to end the session": the work is closed as built, as every stage before it was
  closed when he named what comes next. He did not say he had tried this build, and this record does not
  say so either. The rules below are first values, his to tune.
- None of "His calls" below was taken up. They were shown to him in the report, the turf's earth first, so
  they stand by default: don't treat one as settled against him, and don't change one unasked.
- "roll the stockpile mechanics in with phase 6, becuase there are a lot of overlap": his word is "phase 6".
  The framework letters its phases (B is the band, stages 1 to 6) and numbers its stages, and the next one in
  the plan is stage 6, habitation: I read him as meaning that stage. If he meant something else, the plan's
  line under stage 6 is the one to move.
- "I will start that in a new session": his to open. Nothing was designed or briefed for it here.

## What John sees on first launch
1. **A planned path is laid by one serf to each 20 m**, not by the whole band. The rest go on with their work.
   His 18 m path is one serf's; a long one is laid two stretches at a time.
2. **Only two of six turn to the camp or a path at once** (those with a job). Anyone with no job still turns to
   it at once, and the cook builds its own camp beside them.
3. **The hearth stands later**: half past twelve on the reference run, where it was a quarter past nine. The
   first stew is that evening, and three of the six go to bed hungry the first night.
4. **A camp marked on uneven ground is levelled** round the fire as its ground is made ready: the high side dug
   off, the low built up, a flat floor of bare earth. Its sheet says "Floor: 78 blocks of earth to dig off, 106
   to fill". The seat logs lie flat.
5. **Earth in the stockpile**: what is over from the digging is carried there and heaped as dark clods; the
   stockpile's sheet lists "Earth". On the reference site that is 28 blocks.
6. A camp on a slope takes longer: three quarters of an hour to three hours more, by how much earth has to be
   carried how far.

## His calls (what I decided that he may want otherwise)
- **The turf cut off the floor counts as earth for its hollows** (a block for every two block columns), and
  that earth comes from nothing: the ground under the turf stays where it is. It is the only place in this
  work where matter is not accounted for, and it sits against "the fire just doesn't magically appear". Why:
  the floor's level has to be one at which the hollows can be filled, and on blocky ground the dug earth alone
  falls a few blocks short as often as not; the only other honest level is then a whole block lower, and the
  whole floor is dug down. On the slope measured (1156 1099) that is 304 blocks to dig and carry off, against
  78 dug and tipped into the hollows. The alternatives: dig the 304; or leave the low side as it lies and only
  cut (the logs then lie right on the high side only).
- **The limit covers the camp's building too.** That is what puts the hearth at half past twelve. If the camp
  should stay everyone's first task and the limit bite on paths (and whatever comes later), it is one condition
  in `Think_Build`.
- **The number: a third of the living band, at least one** (two of six). Nothing in the game sets it yet;
  `--extra-hands N` does from the command line.
- **The cook builds its own camp and is not counted** (so the camp has the cook and two others).
- **Someone with no job always helps, and counts**: while the idle are enough, nobody leaves a job.
- **After its 20 m a serf goes back to its own work**, and may be given another stretch when its hands are
  next empty and there is a place. Going to eat or to sleep gives its stretch up to the next comer.
- **16 blocks of earth to a basket, 64 to a place in the stockpile.** A visit digs a basketful in the same 4 s
  a square metre of treading takes.
- **With no stockpile, or no room in one, earth over is thrown aside** (it is gone). So a band with no
  stockpile levels faster than one with a stockpile far off.
- **Rock is not dug**: a column of it in the floor stands as it is.
- **Only the floor is levelled.** The firewood stack (3.9 m from the fire, the camp's corner) and the places
  the band sleeps (from 2.7 m) are on the ground as it lies. On the one-in-eight slope the stack sat right in
  my shot; I did not make it level.

## Rules as built (first values, his to tune)
Extra tasks (`docs/systems/colony.md`, "Extra tasks"):
1. An extra task is the camp's building or a path's laying.
2. At most a third of the living, at least one, are at them at once.
3. Someone with a job turns to one, hands empty, only while fewer than that are at them.
4. Someone with no job never waits, and counts.
5. The cook at its own camp never waits, and does not count. At a path it is a hand like any other.
6. A load already in hand for the camp is always carried there.

Paths (`docs/systems/colony.md`, "Paths"):
7. A path is kept as stretches of 20 m, the last what is left; a shorter click is its own.
8. Whoever starts on a path is given a stretch nobody has, the nearest, weighed toward the stake.
9. It lays it end to end, alone, and goes back to its own work.
10. After a short stretch it goes on to another, till it has laid 20 m.
11. Leaving for anything else gives the stretch up.

The floor (`docs/systems/needs.md`, "The floor is levelled"):
12. The floor is the camp's ground within 2.6 m of the fire.
13. Its level, chosen when the camp is marked: the highest at which what is dug off, with the turf cut off the
    rest, fills the hollows.
14. A visit to a square metre of it digs off a basketful, cuts its turf and fills its hollows from the
    digger's hands.
15. Earth left in hand goes to another hollow (waiting a moment if each has someone at it), else to the
    stockpile, else is thrown aside.
16. Once nothing is left to dig, hollows take the turf's earth, then the stockpile's. With none, a hollow is
    left and the hearth is built all the same.
17. Rock stands.

## Built
- **The limit** (761f4e6): `At_Extra_Task (J)` reads from what J is doing whether it is a hand at an extra task;
  `Has_Place` in `Think_Build` is the gate. Nothing is kept, so a place cannot leak. `Set_Extra_Hands`,
  `Extra_Hands`, `At_Extra`; `Extra_Share`.
- **Stretches** (74efb35): `Path_Stretch_M` (it was `Path_Piece_M`, 32 m); a stretch is held by being at it
  (`Site_Seg`); `Site_Laid` counts the turn; `Drop_Stretch`. `Think`'s needs are a function of their own now
  (`Sees_To_Needs`), nothing changed in what they do. `Set_Stretches`, `Stretch_Of`, `Laid_By`.
- **The floor** (00639ab): `Choose_Level`, `Camp_Level`, `Make_Ready (P, I)` (cut, turf, fill, in that order),
  `Read_Camp_Ground` (the zone's strips remade after every dig or fill), `Settle_On_Floor`, `Sod_Bits`,
  `Patch_Reach_M` (a bank is dug from its foot). `Set_Levelling`. `Camp_View` has `To_Dig`, `To_Fill`,
  `Floor_Z`; the camp's sheet a "Floor" row.
- **Earth**: the last of `Item_Kind`; `Castle.Props.Clod` and a heap of them for a stockpile place. Nobody asks
  for it, fetches it or eats it. `--supply earth N` works.
- **Old demos**: `tools/demo_camp_zones.sh` and `demo_paths_reach.sh` run with `--all-hands --no-level`, so
  they record what they did. The three older scripts are as they were; a camp they build on the spot now has
  a level floor.

## Measured (seed 1, the reference setup, colony_run; and the check's meadow)
- `tools/reference_check.sh`, six runs of 41 game days, each line for line against its kept log: everything on
  (reference_run_hands_level.txt, new); `--all-hands --no-level` (the paths and reach log: so the limit, the
  stretches, the levelling and earth left everything else exactly alone); with `--paths-built` (the camp and
  zones log); `--no-labour` (stage 5c's); with `--no-demand` (5b's); with `--no-skills` (5a's).
- The run with everything on gives the same state at two worker counts (10b209c22dae51f8). So does two days
  with the camp on the one-in-eight slope (6647c7f03cb2b921), and so does that run through a save taken while
  its floor is being levelled (0.0625 days in) and loaded.
- The reference run's first day:

  | | hearth stands | 18 m path laid | first stew | first midnight: fed (least/mean), hungry |
  |---|---|---|---|---|
  | all hands, no levelling (as before) | 9:15 | 9:45 | 15:15 | 66/78 %, 0 |
  | all hands, levelling | 9:45 | 10:00 | 15:45 | 70/79 %, 0 |
  | a limit of 4 | 10:15 | 11:45 | 20:45 | 27/73 %, 1 |
  | a limit of 3 | 11:00 | 12:15 | 18:15 | 67/79 %, 0 |
  | **a third: 2 (the build)** | **12:30** | **13:30** | **19:45** | **26/50 %, 3** |
  | a limit of 1 | 14:30 | 16:00 | 20:00 | 73/78 %, 0 |

  The hearth's hour follows the limit. The first night does not: it is fine, hungry, fine, hungry down the
  table. What decides it is whether the cook has a pot on before the band's first hunger at one in the
  afternoon; after that what the gatherers bring is eaten raw as it comes, and the stock stays empty till
  evening (the cook's afternoon, traced: seat logs till half past one, firewood till half past three, then
  nothing in store to cook till it pulls vegetables itself at five). By the second midnight every row is fed
  (76/81 % in the build).
- The first winter moved again, as it will: one of six is alive at the end of the new log (four in the paths
  and reach log). Not tuned.
- Levelling, the reference band, the stockpile at the stake:

  | camp | to dig / to fill | hearth, floor levelled | floor left |
  |---|---|---|---|
  | the reference one, 1172 1082 (1 in 30) | 28 / 0 | 12:30 | 11:45 |
  | 1158 1090, the stockpile some 30 m off | 97 / 0 | 16:30 | 13:15 |
  | 1156 1099 (1 in 8) | 78 / 106 | 13:30 | 12:45 |

  What costs is carrying earth to a stockpile, not digging it: the steep site, where all of it goes into the
  hollows, costs no more than the nearly flat one.
- Stretches, the check's meadow: one serf lays 20 m in 106 game minutes; six with no job lay 58 m (three
  stretches) in 133; six gatherers lay it two at a time in 308, gathering between turns.

## Saves
Colony blob 16, after 15's sections: the limit as set (u8), whether paths are laid by the stretch, for each
member the metres laid of its stretch (u8); whether a camp's floor is levelled, its level (i16; -1: left as it
lies), the turf's earth lying on it (u16), blocks left to dig and to fill as last counted (u16 each: who does
what goes by them), and what is asked and kept of earth (u16 each). A blob before 16 loads with the limit by
the rule and stretches on; a camp that stood is left as it lies; one still being built has its floor levelled
from then on (its level is chosen at the first step, once the ground is in).

## Options
`--extra-hands N`, `--all-hands` (no limit, and paths by the metre: the two together are extra tasks as they
were), `--no-level`. `--supply earth N`. The log says `camp floor: to be level at 17.50 m: 78 blocks of earth
to dig off, 106 to fill`; the food line of `--log-hours` says `to dig N, to fill N` with the camp's building
and `at extra tasks N (of M at most)` while a limit holds.

## Bugs found and fixed (mine, in this work, in no build John has had)
- A new item kind broke the loading of every older blob: the kinds version 9 added were written as "Grain to
  the last kind", so one kind more was read from each. Caught by the checks that load the kept blobs. The range
  is closed now, and CLAUDE.md says how the next kind is added.
- Workers took the places at an extra task before the idle had thought (the idle count from the start now).
- An earth carrier who found every hollow with someone at it carried its load to the stockpile past them (it
  waits now).
- A camp across a ledge was never finished: the square metres up on the ledge could not be walked to, and
  nobody dug the bank from below (they do now, from 1.6 m).
- Earth was fetched from the stockpile for a hollow nobody could get to, carried back and fetched again
  (found on review before any run showed it; a check walls a pit off to hold it).

## The save finding: explained (2026-11-11, after the close)
I had found that a run loaded from some saves parts from the uninterrupted run about a day later, and named
no cause. John, the same day: "I was thinking about the saves, I did notice something that might be the cause the scrubbing hours and days, time advance, it meerly advances the clock, but the world doesn't march with it. Could be something there."

It was not the time keys (the runner has none), but it was that kind of thing: a count that does not march
with the world's own clock.
- **The cause is the runner's, and no colony state is lost.** `colony_run` rebuilds edited stacks every 30
  colony seconds (`Rebuild_S`), counted from the start of each run, and a run started from a save has all its
  edited ground rebuilt at the start. A save taken between two rebuilds therefore gives a loaded run that
  knows of the ground edited since the last rebuild up to 30 s sooner than the run that carried on would
  have (stack versions move on a rebuild: that is when a route is found again and a stack looked through
  again). Nothing shows at once; some later decision falls a step differently.
- **Proved:** two days with the camp on the slope, saved at ten moments and loaded. Every save on a multiple
  of 30 colony seconds (60, 120, 150, 420, 450, 1020) ends in the same state as the uninterrupted run; every
  other (86, 144, 432, 1000) ends in a different one. It fits the first report of it too: the saves that
  parted there were all between rebuilds (86, 144 and 432 s, and `main`'s at 86), none on a rebuild ever
  did (90, 180, 360 s), and two between rebuilds (45 and 58 s) happened not to part within the run.
- **What it means:** the colony's save is exact, as `colony_check` shows on the meadow, where an edit is
  known at once. In the runner, compare a run with a loaded one only from a save taken on a rebuild: a run
  whose length is a multiple of 30 colony seconds, 1/48 of a game day. `colony_run --save` says so when a
  save is not. In the game stacks are rebuilt as workers come free, so no two runs agree to the unit there
  anyway (CLAUDE.md, "Measuring").
- Not changed: the 30 s. Rebuilding every colony second would make any save comparable, and would move
  every reference log.

## The time keys: John's observation; they stay a debug tool (his decision), nothing changed
The keys that scrub the clock (hours forward and back, days forward and back with comma and full stop) add
to the game's clock and that is all: the colony takes no steps for the time passed over. What that does,
from the code:
- **Follows the clock, so jumps with a scrub:** bedtime and waking, the season and winter, the apple season,
  berries growing back on a bush and wild vegetables growing back (both are "at this hour or later"), the
  deer (ages, the pair that arrives every three days, births by the year), the weather.
- **Follows the colony's steps, so does not move:** hunger, work and walking, a fire's burning down, skills,
  what each remembers it could not reach.
- So a day scrubbed forward regrows every bush and brings the night without anyone getting hungrier or a
  log burning; and scrubbing back runs the clock behind things dated after it (a bush's hour to regrow, a
  deer's birth).
- The climate does have a catch-up for this (gone back, or far ahead, it replays the month before); the
  colony has none.
Put to him as his to decide (a development tool as they are, forward only, or a fast run of the colony's
own steps through the time passed over), he answered the same day: "no the scrubbing will reman a debug tool
for now". So they stay as they are. A later "sleep till morning" or time skip is a different thing and would
have to march the colony; nothing of it is planned.

## Known limits
- Nothing in the game sets the limit or says how many are at extra tasks. The band's panel shows each one's
  doing.
- The camp tool does not say what a floor will take before the camp is marked; its sheet does after.
- A bank left at the floor's edge can be too high to climb on that side (three blocks in the check's ledge
  case); the floor is reached from another side.
- A square metre of the camp's ground nobody can get to within 1.6 m keeps the hearth from standing, as an
  unreachable one always did.
- The colony's walking surface is in half-metre cells that take their highest block column, so at the floor's
  edge on the high side a serf walks a block up for the last half metre. On a camp that stands, places on the
  floor (the seats) are at the floor's level whatever that cell says.
- Earth carried is not drawn in anyone's hands (nor is stone, nor berries).
- A stretch held by someone who goes to eat is taken by the next comer; with nobody free it waits for the
  first to come back.
- Driven only by scripted starts and a scripted pointer: nothing of this work adds a click.
- Looked at in stills and recordings only: the levelling on the one-in-eight slope from two sides, the camp
  standing on it with its seats and its firewood, the earth heaped in the stockpile, two at a time on a path.

## Not done
- Stockpile mechanics (his next topic). A use for earth.
- A say for the player in the limit, or in who lays which stretch.
- Levelling under the firewood and the beds. Saying a floor's cost before the camp is marked.

## Next
- **Stage 6, habitation, with stockpile mechanics rolled into it** (his decision, above). He opens it in a
  new session: start from his words, then the stage brief from the framework's template. Nothing of either is
  designed.
- What is already there for it to build on, as pointers and not as a design: a lot laid out by `Plan_Lot`;
  what is built on a zone as a row of `Build_Takes` on the zone record; builders through `Think_Build` and
  `Has_Place` (the limit on extra hands); a floor levelled the way `Make_Ready` does the camp's; earth as a
  stored kind with no use yet. His first message of this run of work said where stockpiles are going: "they
  will eventually start upgrading the stockpile, build a storehouse, warehouse, fences and outdoor storage
  will get coverings".
- The save finding is explained (above): nothing is owed for it. In the runner, take a save that is to be
  compared on a multiple of 30 colony seconds.
- The time keys (above): a debug tool for now, by his decision. Nothing owed.
