# Castle Game handoff (2026-11-19: a turned floor stepped by the texel, and turned hovels on hillsides)

The round before it is `Handoff_2026_11_19_turned_building_step_four.md`. Everything is on branch
`stockpile`, not merged; `main` is 537176c. No merge word was given.

## John's words, whole

> The textures are 5x5 on the face of each block right, can't we step the texture so it falls under
> the wall of the house? we don't want to limit the player they need to be able to place diagonals on
> hillsides if they want to

Taken as:

- **"5x5 on the face of each block right"**: yes (`Castle.Textures`: five texels by five a face, so a
  texel is 5 cm).
- **"can't we step the texture so it falls under the wall of the house?"**: read as the floor of a
  turned house, whose edge stood out from under its walls by a block's corner wherever a wall was
  cleared (the pictures of step four showed it). Tried, shown, built. **If he meant something else
  by "the texture" (the dug earth round a house on a slope, say) it is the same mechanism and one
  more rule: put to him.**
- **"we don't want to limit the player ..."**: his answer to the call of the round before ("the fall
  allowed under a turned hovel ... on a steep hillside fewer turned hovels are placed"). Built: a
  turned hovel is placed wherever a square one would be.

## A fault in the build he had, said first

**Where a tree's bough hung over the ground a turned hovel is drawn on, its builder levelled for
ever.** The ground's work asked for the bough to be lopped there and the lopping was done only over
the house as it stands (mine, of the ground's commit 12f0d25, in `bin/` since gate 60). Not met on
the three streets measured then, which have no tree by; met at once on the steep hillside, where the
one hovel stood at "the ground 0 %" for eleven days. Mended: the bough is lopped where it is asked.
The steep hillside is in `tools/turned_streets.sh` now, which is what would have caught it.

## Built (commit 57651d2; nothing saved)

- **The floor of a turned house is stepped by the texel** (`Castle.Render.Set_Turn_Floor`, the game's
  `--no-turn-floor`). The floor is laid in blocks under the house as drawn, and along a wall at 45
  degrees a block's corner stood out past the wall, and the turf in from it, at every step. Now each
  texel of the ground at a turned house's pad is drawn by where it lies as the house is drawn: within
  the walls' outer faces as floor, whatever its block is; a floor block's texel past them as turf;
  and no turf is worn into the floor's edge. So the edge runs along the wall's outer face in steps
  of 5 cm, under the wall. Drawing only: the blocks are what they were.
- **A turned hovel is placed wherever a square one would be** (`Castle.Colony.Set_Turn_Fall`,
  `--turn-fall` to have the rule of the round before back, to measure). The fall of the ground (2 m at
  the most) is taken under its walls as they stand, as a square house's is; its ground is made under
  it as drawn however far the land falls there.
- Nothing grows back under a turned floor as it is drawn (`In_A_House`).

### Measured

The band of thirteen up the hillside east of the stake (20 to 30 %, trees by), eleven days, one run
each:

| | step three (square ground) | the round before | now |
|---|---|---|---|
| lots taken | 1 | 0 | 1 |
| the hovel stands from | day 3.3 | | day 3.5 |
| columns it is drawn on not at its pad's level | 135 of 257 (5 rows) | | 0 |
| with a bough or a bush over them | 35 | | 0 |
| stones in its ground | 29 | | 32 |

All thirteen living. The flat street and the rising one are as they were (five and four hovels).

### Seen

`~/CASTLE_GAME/releases/turned_floor_and_hillside.png`: a turned hovel with its floor laid and its
frame going up, from straight above, the floor in blocks and stepped by the texel; the hovel on the
steep hillside from two sides, on its cut terrace. **A street of square hovels, this build against
the build before** (the proof's options): outside one spot at the fire where something moves, three
pixels of 1,024,000 differ, by one or two steps of 765; one run of this build in three differed
from all the others by about 2,570 single pixels scattered over grass and thatch, as one of four
did the round before (not explained; never yet in the five runs of older builds).

## Checks

`colony_check` 813 (it was 811): on a made-up hillside of a block a metre (25 %), both ways across
it, seven turned hovels stand; under each as drawn the ground is at its pad's level, every step of
more than a block is a wall of stone, no spot of 8,550 is a pit, there is a way to every bed. (With
`--turn-fall` seven stand there too: on a hillside all of one slope the two rules part only in a
narrow band. That the rule off lets a hovel stand where none did is the script's third site.)

`tools/turned_streets.sh` has a third site, the steep hillside, where one hovel has to stand.

## Gate

Gate 62, from a clean copy of 57651d2: both builds from nothing with the six known warnings and no
error; the nine checks in debug (water_sim 77, edit 41, ui 112, dynamics 18, serf 19, path 70, **colony
813**, deer 14, pick 69), none failing; the eight reference logs line for line; the three stockyard
sites; the three turned streets (the steep hillside new) in release and in debug; the stress runner,
nothing died and nothing dropped; the flora hash unchanged. The five stress states are gate 61's.

`bin/` in the working copy was built from this commit, his game not running, and
`tools/turned_streets.sh` run from it.

## His calls (first values of mine)

1. **The floor runs to the walls' outer faces**, so with a wall cleared the floor is seen right
   under where the wall stands. To the walls' inner faces is a number.
2. **Past the walls a floor block's texels are drawn as turf.** On ground that was dug they are a
   texel of green at the wall's foot (5 cm), where bare earth would match.
3. **No limit on how far the land may fall under a turned hovel as drawn**, beyond the 2 m under its
   walls as they stand. Its terrace is cut and walled as deep as that takes; how deep was not
   measured.

## Known limits

- The far view draws a turned house, and its floor, as they stand.
- The floor's blocks are still where they were laid: it is the picture that is stepped. A walker's
  pace on a block is the block's.
- On a steep hillside one lot was taken by a turned hovel and one by a square one; whether as many
  turned hovels as square ones fit along a longer hillside street was not measured.
- Not seen: winter; snow on a turned floor's edge; the edge in rain.

## Still owed, not held

- The far view through the turn; the stockyard turned.
- The square a turned house stands on is turf to the eye and a wall to the feet; a stair to a turned
  door is cut straight out from the walls as they stand.
- From "workers 250 m": a gatherer's or a porter's way asked first; the hunters.

## Test windows and input

Stills in short windows of mine, each only when `pgrep` found his game not running. All input
scripted. Nothing pushed.
