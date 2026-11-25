# Castle Game handoff (2026-11-19: step four of the turned building: pointing and the cleared roof)

The round before it is `Handoff_2026_11_19_turned_building_ground.md` (the ground of step three), of
the same word of his. Everything is on branch `stockpile`, not merged; `main` is 537176c. No merge
word was given.

## John's words

> you're doing a great job, continue

Step four was named next in the steps put to him ("Pointing and the cutaway through the turn"), so it
was gone on with when the ground was closed.

## Owed of this step, said first

**The far view still draws a turned house as it stands**, unturned, where it is drawn from the far
tiles. Not looked at, not measured.

## Built (commits a481678, e75981c, a2f981f; nothing saved)

- **A house drawn turned is pointed at where it is drawn** (`Castle.Pick.Look`'s `Cast`). The
  pointer's ray is taken back through the house's turn and walked into the blocks again from where
  it comes to the house as it stands: what it meets there is what the pointer is on as the house is
  drawn (its thatch, a wall, through a cleared roof its floor). A house begun and not yet built is
  its ground as drawn.
- **Where the house really stands, and nothing is drawn, the pointer no longer says the house.** The
  ray walks into blocks that are drawn elsewhere, so it is taken on to the level of the pad: the
  zone there. Never the block: no brush box is shown on such a block and a click digs nothing there
  (`Thing.Turned`); a click of a tool on the ground goes where the ray meets what is seen.
- **People inside a turned house are pointed at where they are drawn**, and **nobody is pointed at
  through a turned house**: the pointer's sight ends where the ray meets the house as drawn, though
  no block stands there for the ray to walk into. (Found by a check written before the mending: from
  past a turned hovel, level, the pointer said the person standing 37 m off on its other side.)
- **The pointer finds a sleeper as the colony lays it** (its feet toward what it lies by), in any
  house. Found on the way: in a save just loaded the pointer found a sleeper only at its feet, the
  shape being laid the way the body last faced, which a body that has not walked since the load does
  not have.
- **The ground kept off reaches right up to the walls as they stand** (it stopped a block short:
  a lane a cell wide at full pace inside the house as drawn). Others on that ground while a hovel
  stood: 1 s in all on the flat street's eleven days, where it was 22 after the ground was made and
  210 before.
- **Its roof and walls are cleared by where it is drawn** (`Castle.Cutaway.Roof`'s turn,
  `Of_Corners`' `Pivot` and `Radians`, `Home`): the eye, what it looks at and what the pointer is on
  are each taken back through the house's turn, so the roof clears when the line crosses the house
  as drawn, and the walls cleared are those that face the eye as drawn (the land's shader is given
  the eye as each cleared house stands: `u_roof_e`).

### Seen

`~/CASTLE_GAME/releases/turned_houses_step4.png`: the pointer on a turned hovel where it is drawn
(the hovel's panel, its roof cleared, its outline as drawn); the pointer where it really stands (the
housing's panel); the eye's line through a turned hovel from either side of the street (roof and
near walls cleared, the bed inside); the pointer on a sleeper in a cleared turned hovel, in the middle
of the bed as drawn (the clock moved to noon to see: his panel). **A street of square hovels with a roof cleared, this build
against the build before**: 641 to 1,765 pixels of 1,024,000 differ, where each build differs from
itself by 1,353 and 1,371 (a cleared roof is drawn in dots).

## Checks

`pick_check` 69 (it was 59): a turned hovel begun, the ground it is drawn on is the house and the
ground it stands on the zone; built, pointing down at it where it is drawn meets its thatch, and where
it stands meets the zone's ground, not a block; without the caster, as before; the eye's line down
through it as drawn clears its roof and down through where it stands clears none; with the roof
cleared the pointer goes through to its floor as drawn; from past it, level, at somebody on its other
side: a house, not the person; from the path at its front as drawn.

With both of the ground's switches off (`--no-turn-ground --no-keep-off`) the flat street's eleven
days are still line for line step three's, on this build.

## Gate

Gate 61, from a clean copy of a2f981f: both builds from nothing with the six known warnings and no
error; the nine checks in debug (water_sim 77, edit 41, ui 112, dynamics 18, serf 19, path 70, colony
811, deer 14, **pick 69**), none failing; the eight reference logs line for line; the three stockyard
sites; the two turned streets, and **the same two in the debug build** (new in the gate: eleven days
of digging with ground kept off, the walking map's mended stacks held against the stacks read
whole); the stress runner, nothing died and nothing dropped; the flora hash unchanged.

**The five stress states are gate 60's** (six_4_years 525a4d82eb39219b, six_41_days 13670c685087c0ad,
housing 71f9fa970ff8a2a4, crowd_as_it_is 08038b4f1a4bacee, crowd at work 1fe04e7de9872b9c): the
step saved nothing and moved nothing of the colony's where no house is turned.

`bin/` in the working copy was built from this commit, his game not running; `colony_check` (811),
`pick_check` (69) and `tools/turned_streets.sh` were run from it.

## Known limits

- **What stands behind the place of a turned house and before the ground is not pointed at there**: a
  person seen across the bare square from a low eye, on the far side of where the house stands, is
  found only as far as the ray's meeting with the pad's level. The blocks are walked once for the
  world and once for each turned house.
- The pointer's own block (the tool that digs and builds a block at a time) is off on a turned house
  and on its place; it shows on the house's floor, which is where it is drawn.
- The far view (above).
- A person awake inside a turned house was not pointed at in a window (the sleeper was); a person
  walking in is drawn through the turn over a moment, and the pointer goes by the whole turn at once.
- Not seen: the cleared roof with a builder at work; a turned house pointed at on foot (stage 7).

## Still owed, not held

- The far view through the turn.
- What the ground left: the square a turned house stands on is turf to the eye and a wall to the
  feet; a stair to a turned door is cut straight out from the walls as they stand.
- The stockyard turned (step five).
- From "workers 250 m": a gatherer's or a porter's way asked first; the hunters.

## Test windows and input

Stills in short windows of mine, each only when `pgrep` found his game not running. All input
scripted (the camera placed and the pointer parked by options). Nothing pushed.
