# Castle Game handoff (2026-11-19: step three of the turned building: hovels placed turned; the ground under them not yet)

The round before it is `Handoff_2026_11_19_turned_building_step_two.md`. Everything is on branch
`stockpile`, not merged; `main` is 537176c. No merge word was given.

## John's words

> Ok step 3

## Owed of this step, said first

Step three was "the ground: a lot for a turned house, where it really stands and where it is drawn,
both level and kept clear; houses beside a path at 45 degrees placed turned and further apart; the
turn kept with the house and saved". **Built: the houses placed turned, the turn kept and saved, the
builder and the ladder. Not built: the ground.** A turned hovel's lot is still the square one, so:

- **Half its beaten floor shows beside it.** The house is drawn swung about its doorway; the pad it
  really stands on stays where it is, and the part the drawn house does not cover is a bare square
  of beaten earth at its side (the stills).
- **The part of the house drawn off its pad stands on the ground as it lies.** On the flat that is
  grass at the same level; on a slope it will hang over or sink in. One hillside hovel was looked at
  and read well; nothing was measured.
- **Someone crossing its yard is drawn walking through the drawn walls**, and cannot go where the
  house really stands though nothing is drawn there.
- Houses are no further apart than before: in the one layout looked at, on the flat, the drawn
  hovels do not touch (a gap between each; not measured).

## Built

- **A hovel beside a path at 45 degrees is turned to it.** When it is placed, the path nearest its
  doorway is looked at; if that runs at 45 degrees on the block grid the hovel is to be drawn an
  eighth of a turn about the middle of its doorway, the way that lays its front along the path
  (`Castle.Buildings.House.Turn`, `Turn_For`; `House_View.Turn`, `Lot_Turn`). Kept with the house
  and saved. `Set_House_Turn`, `--no-house-turn`.
- **Nothing else of the colony goes by it.** The band's eleven days beside such a path are line for
  line the run with `--no-house-turn`: the same hovels, begun and standing on the same days.
- The game draws each turned hovel by its own turn (`--turn-houses` still turns every hovel, to
  look). **Its builder is drawn through the turn while it works within three metres of it, and the
  ladder at its eave.**
- **A turn comes on and goes off over a moment** (`Castle.Serfs`): nobody jumps at a doorway or on
  coming to the site.

Seen (`~/CASTLE_GAME/releases/turned_houses_step3.png`): four hovels along a path at 45 degrees, each
with its front along the path, on the fourth day (one being roofed) and the eleventh. One hovel on the
hillside east of the stake. **Not watched: a builder at work on a turned frame, anyone walking in.**

## Saves

Colony blob **36** (a house's turn, and whether houses are turned). Blobs of 30 to 35 are still read:
their houses stand as they did; a hovel placed from now on beside a path at 45 degrees is turned.

## Checks

`colony_check` 801 (it was 797): beside a path at 45 degrees, either way and on either side, every lot
is turned the way that lays its front along the path (15 lots); beside a straight path none; a hovel
begun there keeps its turn through a save and a load; with the switch off none.

## Gate

Gate 59, from a clean copy of 9d63a1d: both builds from nothing with the six known warnings and no
error; the nine checks in debug (water_sim 77, edit 41, ui 112, dynamics 18, serf 19, path 70, **colony
801**, deer 14, pick 59), none failing; the eight reference logs line for line; the three stockyard
sites; the stress runner, nothing died and nothing dropped; the flora hash unchanged.

The stress states moved with the blob (a byte a house, one for the switch): six_4_years
3c6de2afdde92c6c, six_41_days bed8b03fa106fc52, housing 5c4b73b01578cc69, crowd_as_it_is
cc790fa72ac52a89, crowd at work 94c2d901b076c5b5; each case agrees with its own variants.

## Next

The ground of step three: the levelled lot wide enough for the house as it is drawn (it reaches
about three metres past one side wall and two before the front), what to do with the floor that
shows, and nobody outside walking through. Then step four (pointing and the cleared roof through
the turn).

## Test windows and input

Stills in short windows of mine, his game not running. All input scripted. Nothing pushed.
