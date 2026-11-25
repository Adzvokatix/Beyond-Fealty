# Castle Game handoff (2026-11-19: the ground of a turned hovel: the rest of step three)

The round before it is `Handoff_2026_11_19_turned_building_step_three.md` (hovels placed turned; the
ground said first as owed). Everything is on branch `stockpile`, not merged; `main` is 537176c. No
merge word was given.

## John's words

> you're doing a great job, continue

Taken as: go on with what the report before it named as next (the ground under the house as drawn,
then step four). **Praise is not a merge word**: nothing was merged.

## What was owed, measured first

`colony_run --turn-stats` (new, kept) says for each turned hovel: the block columns it is drawn on off
its walls' own place, those not at its pad's level, those with something growing over them, and who
stood there, a colony second at a time. The band of thirteen, eleven days, as step three left it:

| | flat street | gentle rise | rising ground | the hillside east |
|---|---|---|---|---|
| hovels standing | 4 | 4 | 4 | 1 |
| columns drawn on, off the walls' place | 1,193 | 1,156 | 1,156 | 257 |
| of them not at the pad's level | 0 | 87 (2 rows at most) | 466 (5 rows at most) | 135 (5 rows) |
| with a tree, a bough or a bush over them | 0 | 0 | 0 | 35 |
| others than builder and owner there while it stood | 210 s | 43 s | 9 s | 7 s |

So on the flat the house was drawn on good ground and walked through (some dozens of crossings in
eleven days); on a slope half of it hung over or sank in by up to 1.25 m.

## Built (commit 12f0d25; colony blob 37)

- **A turned hovel's ground is made where it is drawn** (`Set_Turn_Ground`, `--no-turn-ground`;
  `House.Turn_Ground`, fixed when the house is placed and saved with it). The block columns under the
  house as drawn, and two round them, are of its site with the square ground it stands on: brought to
  its pad's level, cleared of what grows and of boughs as high as its ridge, walled in stone where the
  land beside stands over or under. They are of its lot too: no other house's lot or ground comes
  there, and a hovel is not placed where they are not its zone's free ground or where the ground
  falls more than 2 m under its walls as drawn. A turned hovel reaches its ground to no neighbour's.
- **Its floor of beaten earth is laid under it as drawn** (`Castle.Buildings.Blueprint`), to the
  middle of its walls as drawn, its threshold under its doorway as drawn. The square it stands on
  keeps its turf.
- **Its door's way is trodden square to the path**, straight out from the door as drawn, where there
  is no stair to the door (a stair is still cut straight out from the walls as they stand).
- **Who walks keeps off it** (`Set_Keep_Off`, `--no-keep-off`; `Castle.Nav.Set_Kept`). The ground a
  standing turned hovel is drawn on, less its walls' own place and the way from its door, is walked at
  a tenth of the pace: a way round is taken wherever there is one, and whoever has business there
  still gets there. Nothing is shut, so nobody can be shut in. From when it stands until it is marked
  to be razed: its builder works there before.
- **The outline of the house that is not there is gone**: the mesher darkens the ground along a wall's
  foot, and the walls are drawn elsewhere. Cleared in the land's vertex shader for the ground in a
  turn's box.
- The plan of a house being built, its door's mark and the outline of the house pointed at are drawn
  where the house is drawn.
- The turn's geometry is in one place: `Castle.Buildings.Back_Turn`, `Fore_Turn`, `Under_Drawn`,
  `Drawn_Box`. `House_View.Turn_Ground`, `Drawn`, `Drawn_Door`; `Lot_Drawn_At`; `House_Drawn_On`.

### The same runs after

| | flat street | gentle rise | rising ground | the hillside east |
|---|---|---|---|---|
| hovels standing | 5 | 4 | 4 | 0 (no lot is taken) |
| columns not at the pad's level | 0 | 0 | 0 | |
| with something growing over | 0 | 0 | 0 | |
| others there while it stood | 22 s | 1 s | 0 s | |
| stones in their ground (square ground: turned) | 1 : 1 | 10 : 5 | 25 : 52 | |
| the last of the four stood | as soon | as soon | a day later (day 7.4 for 6.4) | |

One run each. All thirteen living in each. **On the hillside east of the stake (20 to 30 %) no turned
hovel is placed any more**, where one was before: under its walls as drawn the ground falls more than
2 m. **On the flat a fifth fits** in the strips that held four.

With `--no-keep-off` a run is line for line the run before the keep-off was written; with
`--no-turn-ground` as well, line for line the build of step three. A run saved on its fifth day
(three standing, two being built) and loaded for seven more ends in the state of the eleven days
straight (b9b1fcc36bf08cda). A turned hovel marked while it is being built is taken down, and four
stand at the end.

### Seen

`~/CASTLE_GAME/releases/turned_houses_ground.png`: the flat street and the rising one from above, a
close view, two hovels being roofed with their plans drawn round them as they are drawn and a builder
up its ladder at the eave as drawn, and frames of an owner walking in at the turned doorway at
bedtime (night, brightened five times). **The picture with no house turned** (a street of square
hovels, the proof's options, four runs of this build against three of the build before): outside one
spot at the fire where something moves, no pixel differs in three of the four; the fourth differed
from every other run of either build by 2,567 single pixels scattered over the grass and the thatch
(not explained).

## Saves

Colony blob **37**: with each house and each lot laid out whether its ground is made where it is
drawn (in the byte that holds its turn), and the two switches. **Blobs of 30 to 36 are still read**:
their turned houses stand as they did, on the square ground they have, and nothing of theirs is kept
off; a lot they had laid out keeps the square ground it was laid out with; hovels placed from then on
have their ground made where they are drawn.

## Checks

`colony_check` 811 (it was 801): a blob of 36 loaded; and a section of nine: beside a path at 45
degrees either way, on both sides, no other's walls (as they stand or as drawn) on the ground a hovel
is drawn on; its floor under it as drawn and none left under its walls as they stand; the walking map
keeps off each (a way from past one end of it to past the other goes round) and there is a way to
every bed; saved and loaded to the same bytes; on a made-up hillside (a block every two metres) every
column under each as drawn at its pad's level, every step of more than a block a wall of stone, no pit
in 8,629 spots; `--no-turn-ground`; a blob of 36 with turned hovels standing; `--no-keep-off`.

`tools/turned_streets.sh` (new, half a minute): the band beside a path at 45 degrees on the flat and
on rising ground, eleven days each. It fails if fewer than four hovels stand, anyone starved, any
column a hovel is drawn on is off its pad's level or grown over, or anyone else stood there more than
thirty seconds while it stood.

## Gate

Gate 60, from a clean copy of 12f0d25: both builds from nothing with the six known warnings and no
error; the nine checks in debug (water_sim 77, edit 41, ui 112, dynamics 18, serf 19, path 70, **colony
811**, deer 14, pick 59), none failing; the eight reference logs line for line; the three stockyard
sites; the two turned streets (new in the gate); the stress runner, nothing died and nothing dropped;
the flora hash unchanged (5676219328934879273 in both builds).

The stress states moved with the blob (a byte a lot, two for the switches): six_4_years
525a4d82eb39219b, six_41_days 13670c685087c0ad, housing 71f9fa970ff8a2a4, crowd_as_it_is
08038b4f1a4bacee, crowd at work 1fe04e7de9872b9c; each case agrees with its own variants.

After it, `colony_run --turn-stats` came to say each house's door, owner and stones (printing only).

## His calls (first values of mine)

1. **Two blocks of ground round the house as drawn** (half a metre: `Turn_Apron_B`, the bank a square
   house has).
2. **A tenth of the pace on the ground kept off** (`Castle.Nav.Kept_Slow`). Nothing is shut: a serf
   with a reason to go there crawls there.
3. **The fall allowed under a turned hovel is the 2 m a square one has**, taken under its walls as
   they stand and as drawn together, which is a wider piece of ground: on a steep hillside fewer
   turned hovels are placed (none where one was, on the one tried).
4. The calls of the rounds before stand open as they were, at rest by his word.

## Known limits

- **The square the house really stands on is open ground to the eye and a wall to the feet**: turf,
  nothing drawn on it, and nobody can walk across it. Somebody crossing the yard goes round a patch
  of grass.
- **Pointing goes by where the house stands**, not where it is drawn: the pointer over the bare
  square says the hovel, over the half of the house drawn off it says the ground. The cleared roof
  and the far view are the same. This is step four.
- A stair to a turned hovel's door is cut straight out from its walls as they stand, so it meets the
  door as drawn at 45 degrees. On the runs here no turned hovel had one.
- The keep-off begins when the house stands. While it is built its drawn frame can be walked
  through (its builder has to).
- A razed turned hovel leaves its beaten floor where it was drawn, and only its square lot leaves
  its zone.
- A hovel loaded from a blob of 36 keeps the square ground, with the faults of step three.
- Not seen: a stair at a turned door; a turned hovel razed after it stood (only an unowned one is
  razed); winter.

## Still owed, not held

- **Step four**: pointing, the cleared roof and the far view through the turn.
- From "workers 250 m": a gatherer's or a porter's way asked first, as a forester's is, so that one
  whose nearest is across water looks past it; the hunters.

## Test windows and input

Stills and recordings in short windows of mine, each only when `pgrep` found his game not running.
All input scripted (the camera placed by options; the pointer parked). Nothing pushed.
