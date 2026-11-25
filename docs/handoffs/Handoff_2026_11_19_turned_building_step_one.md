# Castle Game handoff (2026-11-19: step one of the turned building, the draw; and a second storey's stairs)

The round before it is `Handoff_2026_11_19_turned_building_and_workers.md`. Everything is on branch
`stockpile`, not merged; `main` is 537176c. No merge word was given.

## John's words, whole

> Ok step one of the turned building, and a question what happens if we add a second story to the
> building can serfs interact with the stairs inside?

## Step one: the draw

Built: `Castle.Render.Set_Turns` (`docs/systems/rendering.md`, "A building drawn turned"). Every block
of timber, daub, thatch or plank in a turn's box, from the house's floor up, is drawn turned about a
point, as one piece: it casts turned (the same vertex shader draws the land into the sun's maps and
the fire's), it is lit by its faces as they are turned, and a roof or a wall is cleared by where the
house stands on the grid. Drawing only: nothing else in the game knows.

`--turn-houses` (the game's, for looking at it): every hovel turned 45 degrees about the middle of its
doorway. **Its door's leaf, its trim, its people and its bed are not turned yet** (step two), and
hovels built side by side for standing square run into each other when all are turned (step three
sets them apart). The still: `~/CASTLE_GAME/releases/turned_houses_step1.png` (three hovels as they
stand, and the same three turned).

**Not as the brief first had it**: the house's blocks are not meshed apart from the map's. They stay
the map's own, where the house stands square on the grid, and are drawn turned. That is less to build
and it is what answers his question below.

Proof that a house standing square is drawn as before: three views (whole roofs; a roof cleared on the
camera's line; all roofs cleared), the proof's options, this build against the build before: 6, 19
and 8 pixels of 1,024,000 differ; the build before differs from itself by 10, 32 and 7 (scattered
pixels in both; not found what moves them). So: no more than the old build's own noise, and not zero.

Cost: one view with three hovels turned, 0.76 ms of the card; unturned 0.78 (one short run each).

## His question: a second storey, and the stairs inside

**A building that stands square: yes, with the walking the game has.** A stair is blocks. The walking
map keeps up to four floors over one spot (`Castle.Nav.Max_Floors`), a serf steps up half a metre and
down a metre, and needs 1.75 m of head room; planks are the quickest ground there is. Serfs climb the
stone steps to a door today by the same rule. What a second storey needs is in the building: a
blueprint with a floor of planks and a stair with head room over it, something to do upstairs (a bed),
and which floor a cleared roof shows.

**A turned building: yes, the same way, because of how step one was built.** The house's real blocks,
its stair among them, stand square on the grid, and the serf walks those. In step two whatever is
within its walls is drawn through the house's turn, so its feet are on the treads as they are drawn.
The turn is about the doorway: the one point where inside and outside meet with no jump.

Nothing of a second storey is built.

## What the steps after are now (the brief has them)

2. What is inside drawn through the turn: the door's leaf, the trim, beds, people within the walls. A
   house carries its turn, saved.
3. The ground: a lot for a turned house is where it stands square and where it is drawn, both kept
   clear and level; houses beside a path at 45 degrees stand further apart.
4. Pointing and the cutaway through the turn.

## Gate

Gate 57, from a clean copy of 9290948: both builds from nothing with the six known warnings and no
error; the nine checks in debug (water_sim 77, edit 41, ui 112, dynamics 18, serf 19, path 70, colony
797, deer 14, pick 59), none failing; the eight reference logs line for line; the three stockyard
sites; the stress runner, nothing died and nothing dropped, **its states those of gate 56** (the change
is drawing alone); the flora hash unchanged. None of that draws a picture: what says the picture is
right is the stills above.

## Known limits

- The far view draws a turned house unturned.
- The roof's cover on the camera's line, the wall's on the eye's side and the pointer go by the house
  as it stands on the grid: wrong for a turned house until step four.
- Blocks of timber, daub, thatch or plank that are not the house's but stand in its box from its floor
  up (a neighbour's eave within half a metre; a log lying against its wall) are turned with it.
- Nothing of the real pointer could be driven; the stills are scripted.

## Test windows and input

Stills in short windows of mine, his game not running. All input scripted. Nothing pushed.
