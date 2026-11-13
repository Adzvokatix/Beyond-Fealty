# Castle Game handoff (2026-11-10: paths planned and laid by the band; no limit on how far the camp's building is fetched from; between stages 5c and 6; closed: accepted as built, 2026-11-11; Claude Code)

- **Closed.** Built from John's answer on the camp and zones work, with first rules of mine, and put to him
  with the build. He tried it and accepted it as built on 2026-11-11 ("John's answer", below): first values,
  his to tune. `paths-and-reach` is merged into `main` (fast-forward).
- Code: GAME_alpha_1_3/compiled, branch `paths-and-reach` from `main` at ab1762d (zones, the fire's life, the
  camp built: closed and merged the same day). One code commit, 84e8dea. The zip is the closing commit
  (documents, the demo's script and `tools/colony_v15.bin`): CASTLE_GAME/releases/castle_game_paths_reach.zip,
  remade from `main`. Demo: paths_and_reach.mp4 (tools/demo_paths_reach.sh), 41 s.
- Checks: all nine pass in debug from a clean copy (`git archive`) of 84e8dea, built from nothing, with the
  six known warnings; `tools/reference_check.sh` passes there, all five runs. colony_check 337 -> 358.
- Versions: Generator_Version 12 and save format 6 as they were. Colony blob 14 -> 15 (how far the band is
  looking, the measuring bar on near stone, the metre of path each member is at). Older blobs load;
  `tools/colony_v14.bin` was written by `main` before the format moved.

## John's words (2026-11-10, on trying the camp and zones build)
"Don't place a distance limit on initial gathering, if they have to walk 200m to get stone they walk 200m,
they don't have to eat just stew, if they are hungry they can forrage themselves if the storage is depleated
or reserved, eat raw forrage from the stockpile if it's availible, etc, that is the opprotunity cost for not
having a stockpile or food cooking, same with eating raw forrage cooked recovers hunger more efficiently than
raw, raw meat won't be consumed that must be prepared, other than that everything you have works wonderfully,
it is starting to take shape, the path should work the same way, the player plans it the serfs build it."

How it was read:
- "everything you have works wonderfully": the camp and zones work is accepted as built (closed, merged; its
  handoff has the record).
- "Don't place a distance limit on initial gathering": what the camp's building takes (stone, deadwood) is
  fetched from as far as it has to be. Ordinary work keeps its reach.
- The eating paragraph: stage 4's rules, restated as the reason the first day's cost stands. Checked against
  day one of the reference run before deciding there was nothing to change: whenever raw food lay free in the
  stockpile the hungry ate it, down to nothing (at 13:00, six hungry, 24 vegetables and 30 berries stored; by
  14:30 none stored). Nothing changed. The thresholds are as they were: a member eats at its next break below
  40 %, and leaves its work to eat, or to fend for itself when nothing is free, below 15 %. If "hungry" meant
  that fending should begin at 40 %, that is one constant (`Very_Hungry` in that test), and it moves every
  reference log.
- "the path should work the same way": a path is planned by the player and laid by the band, by the camp's rule.

## John's answer (2026-11-11, on trying this build)
"excelent, the framework is starting to take shape,
we should limit the amount of workers that can perform extra tasks,
for roads I suggest that when a serf starts compacting a road they are assigned a stretch, say 20m for example,
the campfire, I have tested it on uneven ground, and it causes some issues with the logs and such,
so I think we need to have them level the terrain at least for the compacted part, they can move the dirt to the stockpile,
then we are going to work on stockpile mechanics"

How it was read:
- "excelent, the framework is starting to take shape": this work is accepted as built. The rules below stand
  as first values, his to tune.
- Of "His calls" below he answered one: **who lays paths, and when** ("we should limit the amount of workers
  that can perform extra tasks, for roads ... when a serf starts compacting a road they are assigned a
  stretch, say 20m"). Everyone before its job, a metre at a time, is overruled: a limit on how many do extra
  tasks at once, and a path laid a stretch to a serf. The others were shown to him and not taken up, so they
  stand by default.
- New from the same answer, and the next work (`docs/handoffs/`, the handoff after this one): the camp's
  compacted ground levelled by the band, the earth dug off taken to the stockpile. After that, stockpile
  mechanics (his next topic; nothing of it is designed yet).

## What John sees on first launch
1. **A path is not there when it is drawn.** Each stretch clicked shows as a pale strip. The band walks over
   and lays it a metre at a time, outward from the stake; the strip gives way to footpath as they go.
2. **Everything else treats the plan as the path at once**: a stockpile can be zoned against a path that is
   still only a strip, and no zone takes a planned path's ground.
3. **Every planned stretch draws the whole band off its work first**, as the camp does (the camp's building
   comes before the paths). For the camp that happens once; for paths it happens on every click. A 20 m path
   costs six people about half a game hour; a 136 m one cost the reference band its first afternoon.
4. **A path planned far off is walked to and laid**; the game pauses the colony for a moment while the ground
   out there comes in.
5. **With no stone near, the band goes further for it.** The camp's sheet says "Looking for it: as far as
   156 m from the stake"; one or two walk out and the rest go on with their work. A 150 m walk each way is
   four game hours, so the hearth stands in the afternoon. On seed 1 this will hardly be seen: stone was
   within reach at every site tried.
6. A bit of a laid path dug up is laid again within a minute or so.

## His calls (what I decided that he may want otherwise)
- **Who lays paths, and when.** Everyone, before its job, the unassigned too, on every stretch planned: the
  camp's rule, taken literally ("the same way"). The alternative is one line in `Think`: only those with
  nothing asked of them (resting, unassigned) lay paths, and the rest carry on.
- **The camp first, then paths.** A member turns to a path only when the camp has nothing for it to do.
- **A path takes labour only.** No stone: paving waits for masons, as before.
- **A planned path cannot be taken back.** Nor could a laid one.
- **256 m is as far as the band looks.** Not a rule: about as much ground as the engine can keep in beside the
  view. Past that the camp's sheet says no further is known.
- **Only the camp's building looks further.** Foresters, gatherers, porters and hunters keep their 60 to 80 m.
- **Far ground is let go again** once the camp stands and everyone is back.
- **Deadwood is not looked further for** while there are logs stored and a cook or a forester to bring them.

## Rules as built (first values, his to tune)
Paths (`docs/systems/colony.md`, "Paths"):
1. A stretch marked is planned: a path for zoning from that moment, grass to walk on until it is laid.
2. The band lays it, by the camp's rule and after the camp: a metre each (4 s at a rate of 1), the metre with
   the least way to it, weighed toward the stake; what grows on it cut, the top of the ground turned to
   footpath.
3. What is still to lay is read from the ground, once a colony second: a stretch dug up is laid again; rock,
   water and trunks under a path stay.
4. A stretch longer than 32 m is kept as pieces.
5. The colony's ground reaches as far as any stretch still to lay.

How far (`docs/systems/colony.md`, "How far the band looks"):
6. The camp's stone and deadwood are looked for within reach of the band's work (60 m) first.
7. With none there that can be got at, the band looks 16 m further at a time, each ring in and looked through
   before the next, until there is some or 256 m is reached.
8. Whoever is free walks out for it; the rest go on with their work.
9. The camp standing and everyone back within 76 m of the stake, the band looks no further than its work.

## Built
- **Planned paths** (84e8dea): `Lay_Path` records the stretch (pieces of `Path_Piece_M`) and edits nothing;
  `For_Path_Work` is the one reading of what a stretch still has to turn; `Refresh_Paths` (once a colony
  second, inside `Advance`) keeps each stretch's metres-to-lay as a mask; `Think_Build`'s `Go_Lay` sends a
  member to a metre, `Step_Build` lays it (`Lay_Metre`, a metre at once). `Castle.Zone_Marks.Show_Paths` draws
  what is still to lay. `Build_Paths_Now`.
- **The reach** (84e8dea): `Far_Reach` (saved), `Look_Further`, `Looked_Through`, `Look_Near_Again`;
  `Ground_Reach_M` is what a host keeps loaded (the game's `Colony_R`, the runner's `Ground_R`, both
  functions of it now); `Ground_In` is the colony's record that the host had it in when the step began.
  `Find_Source`, `Go_Fetch` and `Go_Sticks` take a reach. A far stack is looked through without its bushes
  (`Index_Stack (..., Far => True)`).
- **The switch** is `Set_Labour` / `--no-labour` now (it was `Set_Camp_Labour` / `--instant-camp`, which is
  still taken on the command line): off, the camp stands and a path is laid when marked.
- A stretch's ends planned on ground that was not in get their height when it is.

## Measured (seed 1, the reference setup, colony_run; and the check's meadow)
- `tools/reference_check.sh`, five runs of 41 game days, each line for line against its kept log: everything
  on (reference_run_paths_reach.txt, new); `--paths-built` (the camp and zones log: so the planned paths, the
  reach and the far look left everything else exactly alone); `--no-labour` (stage 5c's); with `--no-demand`
  (5b's); with `--no-skills` (5a's).
- The run with everything on gives the same state at two worker counts (4037589911ee4f80).
- Laying. Meadow: six lay 20 m in 35 game minutes, four at once. Reference run: the 18 m path is laid
  between 9:15 and 9:45, after the camp.
- A far path. Reference setup with `--path 1194 1076 1330 1076` (136 m east, its end 152 m from the stake):
  the ground widened once at the start; 126 m of it lies on ground that takes a path (the rest is bare rock);
  laid by two in the afternoon, the whole band at it. The same state at two worker counts. In the game the
  same start runs through without a stall.
- Far stone. No natural site was found: of 49 stakes tried across seed 1, ten took a camp and none of those
  had to look past its work's reach. So `--stone-from 150` (the camp's builders take no stone from within
  150 m): the band looks out to 156 m by nine (the ground widened six times), the first eight stones are set
  at a quarter past two, the hearth stands a little after four; the same state at two worker counts, and
  through a save taken mid-trip (0.3 days in) and loaded (eaca75367c81d7fb both ways).
- What looking far costs a save: with every far stack looked through for bushes as well the blob was 451 KB;
  looked through for boulders and trees only it is 183 KB (141 KB with nobody looking). 2,357 trees are known
  at 156 m; the table holds 4,096, which is about 200 m of this world.
- The first winter moved again, as it will: two of six die in its last days in the run with everything on
  (three in the camp and zones log). Not tuned.

## Saves
Colony blob 15: after 14's sections, how far the band is looking (f32), the measuring bar on near stone
(f32), and for each member the stretch of path it is at (u16) and the metre (u8). What of a path is still to
lay is not saved: it is read from the ground at the first step after a load. A blob before 15 loads with the
band looking no further than its work; its paths, laid when they were marked, read as laid.

## Options
`--no-labour` (the colony before the band built what is marked; `--instant-camp` still taken),
`--paths-built`, `--stone-from M`. The log says `path planned: N blocks of footpath to lay`; the food line of
`--log-hours` ends with `looking as far as N m` and `path to lay: N m` while they hold; the runner's last line
says how many times the ground widened.

## Bugs found and fixed (mine, in this work, in no build John has had)
- The runner did not bring the wider ground in before its first step when a path was planned far out at the
  start, so the far pieces read as nothing to lay.
- A far stretch's ends had no height (planned on ground not in), so nothing of it was found to lay.
- The band looked out to 256 m for deadwood while logs lay stored and the cook was bringing them.
- Looking far looked every far stack through for bushes: the save tripled.

## Known limits
- Looking further gives up on a boulder nobody can get to only one at a time (a member remembers eight places
  it could not reach): a ring of unreachable boulders can hold the search up.
- If nothing is found within 256 m the ground stays that wide.
- The game pauses the colony each time its ground widens, until the new ring is in.
- The tree table (4,096) fills at about 200 m on seed 1; trees past that are not known (it matters only to
  deadwood fetched from that far).
- A planned path over a river is laid on both banks by whoever can reach each; metres nobody can reach stay
  planned, and are tried again every minute.
- A stretch of before there were pieces, longer than 64 m, is counted to its 64th metre and the rest as one.
- The older demo scripts ask for `--paths-built` as well now.
- Driven only by a scripted pointer: planning a path from the ground's menu, stretch by stretch, and zoning a
  stockpile against it. The real mouse was not exercised.
- Looked at in stills and recordings only: a planned path and its laying from the usual view and from high
  above; the camp's sheet while the band looks far.

## Not done
- Taking a planned path back. Who lays paths as anyone's choice. Paving.
- Looking further for anything but the camp's building.

## Next
- The limit on extra hands, paths laid a stretch to a serf, the camp's ground levelled (his answer, above).
- Then stockpile mechanics, his next topic.
- Stage 6, habitation: a hovel's lot through `Plan_Lot`, its building a row of `Build_Takes`, its builders
  through `Think_Build`; a street is a planned path already.
