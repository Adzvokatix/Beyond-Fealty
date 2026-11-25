# Castle Game handoff (2026-11-19: the next pass of his playtest notes: the ten items left, and his design document)

The round before it is `Handoff_2026_11_18_playtest_round.md` (his notes whole, the faults, the
stockpile placed once, the stockyard); its "Next" listed ten items of his notes not built, a default
each. This is that pass. Everything here is on branch `stockpile`, not merged; `main` is 537176c.

## John's words

His message, whole: "/home/bythergig/CASTLE_GAME/GAME_alpha_1_3/compiled/docs/design/detailed_mechanics.json,
ok I have organized and planned out alot of what we are working on and some minor changes, I like what
you have built so far, but I have a new idea for the stockpile, stockyard, storehouse. I am running a
playtest right now, we can continue to the next pass, I will compile anything I see from this
playthrough and get back to you."

Taken as:

- **"we can continue to the next pass"**: the ten items, built here.
- **"I like what you have built so far"**: not a merge word. Nothing is merged.
- **"I have a new idea for the stockpile, stockyard, storehouse"**: his to open. The document he
  names has a stores model that differs from what is built ("His design document", below); whether
  that is the new idea or the idea is still to come, he has not said. **Nothing of the stores was
  changed**, and razing was kept to housing for the same reason.
- **"I am running a playtest right now"**: nothing was built or linked in the working copy. Every
  build of this pass was made in a scratch copy; `bin/` is still the build of 6e71f8a he was playing.
  **To play this pass the game has to be built** (`gprbuild -P castle.gpr -XCASTLE_MODE=release -j0`).

## The ten items

His words for each are in the round before's handoff, whole. Where what was built departs from the
default that handoff put to him, it says so first.

1. **Paths levelled.** A metre of path is brought to the path's own line as it is laid: at each quarter
   metre along it the middle height of the ground across its width, smoothed over a metre before and
   behind. A bump or a dent shorter than that is gone, a slope keeps every step, and across its width
   the path lies level. A column is moved half a metre at the most (`Path_Level_B`, 2 blocks: the
   default said one); further off it is a bank or a ditch and the path goes over it as it did. Never
   through water. `Set_Path_Level`, `--no-path-level`; saved.
2. **Builder in the job list. Departs from the default**: the default made it a sixth job the player
   gives. His document makes the builder ("Wright") a job that comes from the woodcutter's and is not
   among the opening jobs. So it is **shown, not given**: the band's lists call a serf by its trade
   while it has one (Builder, Stockman, Carpenter). `Castle.Views.Job_Label`. The menu of jobs is as it
   was.
3. **Deleting part of a zone, and razing. Stops at the mark**: the default promised the taking down
   ("its builder takes it down block by block and its timber and straw go back to the stores, half of
   what it took"), and that is **not built**. Built: on the ground's menu on housing, "Take housing out
   from here", then the other corner; every block column of housing in the box is no zone's, and the
   lots still to begin are laid out anew. A hovel begun or standing there keeps its lot and is **marked
   for razing** ("Marked for razing" on its sheet; "Mark this hovel for razing" and "Keep this hovel
   (lift the mark)" on its ground's menu). The mark is a label: a marked hovel is built on, lived in
   and counted as before. Housing only.
4. **Doors.** A leaf of planks in each doorway of a house whose walls stand, two in a storehouse's
   two-metre doorways; swung into the house while anyone is within 1.3 m, shut behind them. Drawn only:
   the doorway is walked through as it was. **Departs from the default: the stockyard's gateways have
   no leaf** (whether a gateway has one is still his call from the round before). `--no-doors`.
5. **Cart wheels** turn as it is pulled, by how far it has gone. Drawn only. `--no-wheel-roll`.
6. **Thatch.** Drawn fuller, the same blocks: a dressed roof's slope lies over its steps' noses, not in
   their hollows (a block thicker, measured upright), the eave's edge a whole block where it was half,
   and the corners along eaves and verges hang unevenly. `--no-full-thatch`. No blueprint change, so
   nothing of the building moved for it.
7. **The windows' timber. "The first fraction of blocks" was built as whole blocks**: the sill and a
   lintel run from the post on the window's one side to the post on its other, and the block to either
   side of the opening is plank. A trim thinner than a block would be a drawing of its own.
   `Set_Window_Timber`, `--no-window-timber`.
8. **Trusses, ridge beam, cross members.** In every gable end a king post and a rafter under each slope
   (where daub was); tie beams across from eave wall to eave wall about every two metres; in the
   storehouse a truss on each tie beam and a ridge beam. **The ridge beam is in the storehouse only**,
   as he wrote it. "Cross member support to the sides of the houses perpendicular to the door" was read
   as the tie beams. Raised with the frame from the house's own logs: 77 to 122 blocks more for a hovel
   (a log makes 96), 260 for the storehouse. Inside a cleared roof they clear with it.
   `Set_Roof_Timbers`, `--no-roof-timbers`.
9. **The thatcher on its ladder.** Counted first, a tick at a time: thatching one roof, the builder was
   drawn down on the ground and up again 114 times. It is shown up its ladder between bouts while straw
   for the roof lies at the house, and all through the trimming (which takes none: counted by itself,
   2,158 ticks up and never down and up); fetching straw or carrying its ladder round it comes down.
   Drawn only.
10. **A serf that meets an obstacle. Half of the default**: whoever stands still where a block is to go
    steps aside to the nearest free ground it can walk out of, and goes on with what it was doing.
    **"A builder passes over a block it cannot lay and comes back to it" is not built**: a house is
    saved as a count of blocks laid in order, and passing over one would change that. Constructed
    first: one of the band stood on a hovel's first post's place for a game day, and its builder laid
    nothing for nineteen game hours. `Set_Make_Way`, `--no-make-way`; saved. In 41 days of the band of
    thirteen no builder ever waited so, with the rule or without, and **among 48 building six hovels
    in 30 days nobody ever stepped aside** (`colony_run --who` counts it; that run's log is line for
    line the run's with `--no-make-way`). It is a net under a case made by hand: **his stall at the
    fence was not reproduced, and whether this is what caused it is not known.**

## Saves

The colony's blob is **31**. **A colony saved by the build he was playing (blob 30) is still read**:
its houses stay as they were begun (no roof timbers, the old sills), the next it begins is made the new
way. Tried: a colony of six hovels and the storehouse saved by that build, run on six days in this
one. A house keeps how it was begun and whether it is marked, with it in the blob.

## Measured

Single runs each, the band of thirteen on the reference site with housing, the stockpile and the
stockyard, 41 days (`colony_run`, release):

| | sixth hovel stands | storehouse stands | living |
|---|---|---|---|
| houses as they were (`--no-roof-timbers --no-window-timber`) | day 8 | day 10 | 13 |
| with their timbers (the default) | day 9 | day 10 | 13 |

(Corrected 2026-11-19: this table had a column "hungry serf-hours", 73 and 23. Those runs were logged
once a day, so the figures were sums of 41 midnight samples, not serf-hours; the column is gone.)

A day's difference in one run each is within what two runs differ by; it was not run often enough to
say more. Both rows have path levelling on. Housing zoned on the hillside east of the stake, two layouts, 30 days, on the new defaults:
five hovels and one hovel standing, nobody starving, nobody without a way (five with levelling off as
well). Both hillside stockyard sites pass (`tools/stockyard_sites.sh`).

## His design document (`docs/design/detailed_mechanics.json`, version 0.6, his, committed as it came)

Read, not built from, except item 2. Where its stores differ from the build:

- **Stockpiles**: his are many, "intermediate stores along a pathway, near where goods are gathered",
  each with a stock hand the yard sends. Built: one stockpile, placed once, closed when the storehouse
  stands.
- **The stockyard**: his is "the colony's central store" of five buildings: stock-house, open yard,
  staging area, granary, stable. Built: one storehouse with a fenced yard, coverings and staging on one
  lot.
- **Who carries**: his stock hands and a stockman who schedules deliveries by cart. Built: porters, and
  a stockman who keeps the storehouse.
- Elsewhere: Forester is his Woodcutter; a priest, a second cart and two horses at the start; the
  builder a Wright. **None of it was renamed or added.**

## Gate

Gate 50, from a clean copy of 234818c (`git archive`, both builds from nothing): release and debug
build with the six known warnings (all of water_sim_check) and no error; the nine checks in debug
(water_sim 77, edit 41, ui 112, dynamics 18, serf 19, path 70, **colony 752**, deer 14, pick 59), none
failing; the eight reference logs line for line (with `--no-path-level --no-roof-timbers
--no-window-timber`; stepping aside on); both stockyard sites; the stress runner, nothing died and
nothing dropped; the flora hash unchanged (5676219328934879273 in both builds).

The stress states moved, as they must when the blob grows (the switches are in it): six_4_years
4f417c79f2b3c997, six_41_days a887f036cbb8cd91, housing b56bd3f68016e7da, crowd_as_it_is
ed287981b1a4be7a, crowd at work db011e76fac81ec0. Each case still agrees with its own variants (two
workers, read anew, no memos, every refusal proved, whole summaries, whole bricks, the whole map).
What says the behaviour did not move is the eight logs.

Two gates before it found one thing: gate 48's debug `colony_check` stopped on an index check, in a
check of mine that wrote a storehouse's yard out past its array (release has no such checks and had
passed). Fixed in 8ec4a80; gate 49 on that commit passed whole; gate 50 is of the last code.

## His calls (first values of mine)

1. **What razing does** (the handoff's default, not built): a marked hovel's builder takes it down
   block by block, half its timber and straw come back to the stores, its owner is without a home
   again, its lot leaves the zone. And whether a marked hovel should stop being built at once.
2. **Whether the document's stores are the new idea**, or it is still to come.
3. **Builder given or earned**: shown only now. A sixth job the player gives is a small pass.
4. **A leaf on the stockyard's gateways**: none now.
5. **The window's trim**: whole plank blocks to either side now; a thin trim round the opening is a
   drawing.
6. **A ridge beam in the hovels** too: storehouse only now.
7. **How far a path may move the ground**: half a metre now, smoothed over a metre either way.
8. **How ragged the thatch**: a corner hangs up to 10 cm (`Thatch_Rag_Drop`).
9. The calls of the round before stand open as they were.

## Known limits

- The mark does nothing yet but say so.
- Housing ground can be taken out; a stockpile's or the stockyard's cannot.
- A housing zone emptied keeps its number in the list; it has no ground and cannot be pointed at.
- The interior roof timbers clear with the roof by their place (timber inside the walls, 1.9 m or more
  over the floor): anything of timber ever built that high inside a house would clear too.
- A door opens for anyone within 1.3 m, on either side of the wall: a serf asleep by its door holds it
  open.
- The far view draws roofs as it did.
- Paths laid before this pass are as they lie; only a metre laid from now on is levelled.

## Test windows and input

Stills were taken in windows of mine, each a few seconds, each only after `pgrep` found his game not
running; the first tries on a hidden display were too slow to use. All input was scripted
(`--frames`, `--pointer`); no one played it. Through the interface with a scripted pointer: the band's
list, the ground's menu on a hovel's lot, and "Take housing out from here" to its second click (the
message: "housing taken out: 20 block columns; 1 hovel there marked for razing (its lot stays)").
**Seen only in a forced pose, never in motion**: a door open (`--doors-open`; nobody was watched
walking through one) and the cart's wheels turned (`--wheel-turn`; no tow was watched). Nothing was
pushed. The sheet of stills is `~/CASTLE_GAME/releases/next_pass.png`.
