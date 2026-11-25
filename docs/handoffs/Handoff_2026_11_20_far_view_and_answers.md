# Castle Game handoff (2026-11-20: his three answers; the far view through the turn)

The round before it is `Handoff_2026_11_19_turned_floor_and_hillsides.md`. Everything is on branch
`stockpile`, not merged; `main` is 537176c. No merge word was given.

## John's words, whole

> Ok lets continue,1. stopping at the outer face is preferable. 2. If you think bare earth would match
> better do it. 3. No limit is fine for now, we can adjust later

| his clause | the call it answers | what was done |
|---|---|---|
| "stopping at the outer face is preferable" | 1: the turned floor runs to the walls' outer faces (to the inner faces is a number) | stands as built |
| "If you think bare earth would match better do it" | 2: a floor block's texels past the wall are drawn as turf, where on dug ground bare earth would match | built: bare earth where the ground beside is bare, turf where it is turf |
| "No limit is fine for now, we can adjust later" | 3: no limit on how far the land may fall under a turned hovel as drawn | stands; his to adjust |
| "Ok lets continue" | the steps put to him | the next was the far view: built. The one after, the stockyard turned, is put to him below |

## Built (commit 67563cf; nothing saved)

- **The far view draws a turned house turned.** A house more than the view's ring from what the eye
  looks at is drawn from the far view's tiles (cells of 2, 4 ... blocks), and stood there square, off
  its door's path. The land's vertex shader now turns a tile's cells of a building's stuff too (a cell
  asked by its middle and its top).
- **And the ground it stands on is whole there.** A tile's mesher drew no top to a cell with a
  building's cell on it (`Castle.Lod`), so with the walls drawn elsewhere the ground showed as holes
  along them. It is meshed now. A cell that holds the ground under a wall together with the wall's
  foot stays where it is, as turf at the pad's level.
- **Past a turned wall a floor block's texel is as the ground beside it**: turf where the mesher
  marked turf beside that block, else bare earth.

### Seen

`~/CASTLE_GAME/releases/turned_houses_far_view.png`: the flat street 240 m from what the eye looks at,
from high up, the build before (five hovels square to the grid, off their paths) and this one (turned
along the street). **A faint line still shows where each stands**; what draws it was not found (not
the baked shading, not the far shadows: both were switched off in a scratch build and it stayed).

**A street of square hovels, this build against the build before** (the proof's options): near, no
pixel differs outside the one spot at the fire where something moves (three runs of this build
against one of the build before); far, 98 and 134 pixels of 1,024,000 differ, where each build
differs from itself by about 10,400. **The stray run reported twice (about 2,570 single pixels over
grass and thatch) turned up in the build before this time**: it is not of this work.

Not seen: the bare-earth texel (5 cm at a wall's foot on dug ground; by the rule only).

## Gate

Gate 63, from a clean copy of 67563cf: both builds from nothing with the six known warnings and no
error; the nine checks in debug (water_sim 77, edit 41, ui 112, dynamics 18, serf 19, path 70, colony
813, deer 14, pick 69), none failing; the eight reference logs line for line; the three stockyard
sites; the three turned streets in release and in debug; the stress runner, nothing died and nothing
dropped; the flora hash unchanged. The five stress states are gate 62's.

## His call: the stockyard beside a path at 45 degrees (step five)

Not built: it needs his word, because doing it the hovel's way costs much more here.

- **The hovel's way** (the whole stockyard stands square and is drawn swung about its way in): the
  ground is made twice, where it stands and where it is drawn, and a stockyard is 15 to 25 m a side
  where a hovel is 6; beside each there is a square that size that is grass to the eye and a wall to
  the feet; everything in the yard (the heaps, the cart, whoever is in it) is drawn through the turn.
- **The yard laid out for real along the path, the storehouse alone drawn turned in it**: the yard's
  ground, its places and its fence follow the path on the grid as a stockpile's places do today, so
  the fence steps a block a block; only the storehouse (10 m by 5) has the hidden square.
- **Stockyards kept to straight paths**: nothing built; today one is taken beside a path at 45
  degrees only where a corner of its box comes to the path.

My default if he says only "go on": the second.

## Known limits

- The faint line in the far view (above).
- A far tile's cell is 2 blocks or more, so a turned house's foot can stand up to a cell above or
  into the ground there. Not seen from where a tile is drawn.
- The far view's shadows are cast by the house as it stands.
- **The price of the ground under a building's cells in the far view** (`lod_stats`, seed 1, the world as
  it is made): 6.2 million quads for 6.1 (about 1.5 % more, under 1 MB of the card), because a
  broadleaf tree's trunk is of the same stuff as a house's timber, so every such tree has the ground
  under it drawn too. Measured after gate 63; narrowing the rule to daub, thatch and plank would
  leave a house's corner posts over holes.

## Still owed, not held

- The square a turned house stands on is turf to the eye and a wall to the feet; a stair to a turned
  door is cut straight out from the walls as they stand.
- From "workers 250 m": a gatherer's or a porter's way asked first; the hunters.

## Test windows and input

Stills in short windows of mine, each only when `pgrep` found his game not running. All input
scripted. Nothing pushed.
