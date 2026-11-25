# Castle Game handoff (2026-11-19: step two of the turned building: what is inside, drawn through the turn)

The round before it is `Handoff_2026_11_19_turned_building_step_one.md`. Everything is on branch
`stockpile`, not merged; `main` is 537176c. No merge word was given.

## John's words

> ok next step

## Built

With `--turn-houses` (still the only thing that turns a house), whatever is in a hovel is now drawn
through that hovel's turn:

- **Whoever is within its walls**: all of the figure, and what is placed from it (what it carries, its
  ground shadow). `Castle.Serfs.Turn_About`, asked each frame by the game for a member standing in a
  house that is drawn turned (`Castle.Colony.House_On`). It is turned as it is drawn, after it has
  been animated where it stands on the map, so its feet are on the floor it really stands on.
- **Its cloak**: worked out where the serf and its bed are on the map, as before (`Castle.Cloth`), and
  drawn through the turn (`Castle.Props.Put_Cloth`).
- **Its bed, its door's leaf, the trim of its windows** (the game's `Put_In_House`).

Seen: three hovels with their roofs cleared, asleep at home, as they stand and drawn turned
(`~/CASTLE_GAME/releases/turned_houses_step2.png`): each bed, sleeper and cloak lies in the turned
house where it lies in the square one. **Not seen in a still: the door's leaf and the trim on a turned
house** (they go through the same turn as the bed; the views tried showed neither clearly), and nobody
was watched walking in through a turned doorway.

**Not as the brief had it**: no house carries a turn of its own yet, and nothing is saved. A house is
first placed turned in step three; until then the turn is the looking switch's.

`--clock-add H` (new, the game's): a loaded save's clock moved on H hours with the colony left as it
was saved, as the time keys do. For a still of sleepers by daylight; nothing measured with it.

## A house standing square is drawn as before

Nothing is turned unless a turn is set. Stills, the proof's options, this build against step one's
build: a view of sleepers with roofs cleared 2 pixels of 1,024,000 (that build against itself, 2); a
daylight view over three takes each, 2, 12 and 47 (that build against itself 38 and 41, this one
against itself 5 and 6). Within the builds' own noise; not zero.

## Known limits

- A serf is turned whole from the moment it is inside the walls' line: in a doorway a hand's breadth
  off its middle it shifts up to 19 cm as it crosses (the turn is about the doorway's middle).
- A builder working at a turned house from outside its walls is drawn where it stands on the map, not
  beside the turned wall. Step three (where a turned house's ground is) has to settle it.
- The far view, the roof cleared on the camera's line, the wall cleared on the eye's side, the
  pointer and a house's outline when pointed at still go by the house as it stands on the grid.
- Hovels built side by side run into each other when all are turned.

## Gate

Gate 58, from a clean copy of 66f87c5: both builds from nothing with the six known warnings and no
error; the nine checks in debug (water_sim 77, edit 41, ui 112, dynamics 18, serf 19, path 70, colony
797, deer 14, pick 59), none failing; the eight reference logs line for line; the three stockyard
sites; the stress runner, nothing died and nothing dropped, its states those of gates 56 and 57; the
flora hash unchanged. None of that draws a picture: what says the picture is right is the stills.

## Next

Step three, the ground: a lot for a turned house (where it stands square and where it is drawn, both
level and kept clear), houses beside a path at 45 degrees placed turned and further apart, the turn
kept with the house and saved.

## Test windows and input

Stills in short windows of mine, his game not running. All input scripted. Nothing pushed.
