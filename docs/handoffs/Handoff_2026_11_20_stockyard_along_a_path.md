# Castle Game handoff (2026-11-20: the stockyard beside a path at 45 degrees, laid out along the path)

The round before it is `Handoff_2026_11_20_ways_told.md`. Everything is on branch `stockpile`, not
merged; `main` is 537176c. No merge word was given.

## John's words

> Ok go on with the second way for the stockyard

The second of the three ways put to him, as it was put: "The yard laid out for real along the path,
only the storehouse drawn turned. The yard's ground, places and fence follow the path on the grid the
way a stockpile's places do today, so the fence steps a block at a time. Only the storehouse has the
hidden square."

## Where what was built departs from what he chose from

1. **The storehouse has no hidden square once its walls and roof are up.** Its doors are in its two
   ends, 10 m apart, and no point it could be turned about holds both: drawn through the turn, as a
   hovel's people are, whoever walked in at an end door would have been seen to jump about 4 m, and
   the square its blocks stand on would have been a wall to the feet 3 m out into its staging and its
   ladders' row. So **the feet go by the storehouse as it is drawn** (below). The square is there to
   nobody: it is walked as the yard it looks like.
2. **The coverings are stepped**, as the fence is. What he chose from said the fence; it did not say
   the coverings. They are not drawn turned because a covering stands hard against the back fence:
   turned an eighth about itself, its own blocks would stand across the fence's line, three quarters
   of a metre past the row it is drawn in, and two coverings side by side would stand in each other.
   Turned with the storehouse instead, their blocks would have to stand outside the yard. His to say
   (call 1).
3. **Its builder is still drawn through the turn while its frame, walls and roof go up** (it works
   at the blocks, which stand square). The whole turn at the edge of where it works is some 6 m, and
   by the rule a turned hovel's builder is drawn by that would be a jump, twice a load. It is eased
   for the storehouse: all of the turn within 8.6 m of its middle (3 m beyond its corners), less and
   less over the next 6 m. Nobody is drawn through its turn before its floor is laid or after its
   roof is on.

## Built (commits 3362b00, a5300dd and 1a3d9d0; colony blob 39)

- **Beside a path at 45 degrees a stockyard is laid out along the path** (`Set_Yard_Turn`,
  `--no-yard-turn`; saved). Its lot is the whole metres its two corners span along and across the
  path's way, as a stockpile's is, 15 m to 25 m each way, all of it taken or none. Its places lie
  along the path. Beside a straight path nothing is changed.
- **Its storehouse's own blocks stand square to the grid about its middle and are drawn turned an
  eighth**, so that it lies along the path in the middle of its lot's front, its front wall 4.5 m
  back, as a square stockyard's does. The point it is turned about (`House.Piv_U`, `Piv_V`, saved) is
  the one that puts its walls as drawn on its places' lines.
- **Everything else of it is designed as a square stockyard's is and made where the turn puts it**
  (`Castle.Buildings.Design_Of`; in the colony `D_U`, `D_V`, `Y_Point`): its ground brought to its
  floor's level and walled in stone where the land beside stands over or under; the stair of its way
  in; its yard beaten; **its fence and its gateways' planks as lines of blocks, each beside the one
  before** (never corner to corner: a body would pass); its coverings, each block column at the
  height its place in the covering has; its places fitted out (floor, shelves, barrels, coverings,
  ladders against the back wall) by where each lies in the design.
- **Once its walls and roof are up the feet go by it as it is drawn** (`Castle.Nav.Set_Drawn`;
  `House_View.Walked_Drawn`). A cell of the walking map that touches a wall as drawn has no floor; a
  cell where its own blocks stand has one floor at its pad's level, whatever stands there. So its two
  doorways as drawn are the ways in, whoever is in it is where they are seen, and what lies in it
  lies where it is seen. **This is the one place where the walking map is not read from the blocks.**
- A turned house's floor is drawn of its own stuff (`Castle.Render.Turn.Floor`: a storehouse's plank).
- The pointer: the ground within its walls as they stand is not the cursor's to dig or build on
  (what is dug there would not be walked by).
- **The instant build lays a turned yard as its builder does** (`Yard_Row`, shared with `Step_House`).
  The new check found it writing the fence's posts into the yard's own walls of stone and filling the
  stair (it wrote each block at the row it is drawn up at, not on the ground as it lies). A square
  yard's instant build is as it was: the checks' worlds did not move.
- `colony_run --turn-stats` says, of such a storehouse: the block columns of all its ground, those not
  at their level, those grown over, and (from when the feet go by it as drawn) the serf-seconds spent
  within it, where its blocks stand, and in a wall as drawn. The game's `--pointer` script has
  `tool NAME` (the colony tool taken up, for a still of what a click would do) and `follow I` (the eye
  on member I). `tools/yard_corners.py` works out the two corners for a script.
- **A worn cloak turns with its wearer wherever about a turned house that is.** It was turned by
  where the cloth lay: within the walls as they stand, or not at all. So the cloak of a builder at
  work outside the walls (a turned hovel's, since step one) was drawn where the builder stands, apart
  from the figure. Found by reading while the storehouse's builder was eased, **then reproduced in
  the build before**: a save of its own with turned hovels going up, the game with `--winter`, the
  same six frames of each build. In the build before a cloak stands alone on the grass some 4 m from
  the hovel in each of them; in this build none does, and what differs between the two builds'
  frames is that cloak and its place on the figure.

## Measured

The three stockyards along a path of `tools/stockyard_sites.sh` (the band of thirteen at the
reference stake, with its housing and its stockpile), eighteen days each, one run each of this
build:

| | on the flat, 16 m by 16 m | ground that falls 3 m, 15 m by 15 m | on the flat, 25 m by 25 m |
|---|---|---|---|
| the log's first line with the storehouse standing (zoned day 20 at 7 h; a line every 12 h) | day 28, 0 h | day 32, 0 h | day 32, 12 h |
| logs and sheaves it takes | 21, 44 | 20, 44 | 26, 50 |
| blocks in its blueprint | 8,812 | 8,198 | 15,550 |
| block columns of its ground | 4,301 | 3,631 | 10,251 |
| of them not at their level, or grown over | 0 | 0 | 0 |
| stones in its ground (walls, a stair) | 1 | 45 | 1 |
| serf-seconds within it as drawn | 5,086 | 3,304 | 2,189 |
| where its own blocks stand (off it as drawn) | 201 | 136 | 215 |
| in a wall as drawn | 0 | 0 | 0 |
| living, lines of anyone starving | 13, 0 | 13, 0 | 13, 0 |

A square stockyard of 16 m by 16 m beside the same path on the flat (the site as it was,
`--no-yard-turn`) stands by the same line of the log as the first (day 28, 0 h) and takes 19 logs
and 44 sheaves: a fence at 45 degrees has more blocks in it. The limit on a blueprint is 24,576
blocks.

**Slopes.** The rule is the stockyard's own and was not touched: its ground may fall 3 m from end
to end, no more. Lots of 15 m tried along three paths at 45 degrees near the stake, seven places a
side; and, with `--no-yard-turn`, eight square boxes a side with a corner at the path:

| path, side | square to the grid | along the path |
|---|---|---|
| up the steep hillside east (20 to 30 %), either side | 0 of 16 | 0 of 14 |
| north-west over rising ground, its south-west side | 5 of 8 | 7 of 7 |
| the same, its north-east side | 0 of 8 | 0 of 7 |
| south-east over falling ground, its north-east side | 0 of 8 | 2 of 7 |
| the same, its south-west side | 1 of 8 | 5 of 7 |

Of the twenty-eight refusals along the path, twenty-six were for the fall (3.25 m to 8.75 m across
the lot, for 3 m). The other two, at the near end of the south-east path's south-west side, were
"that ground cannot all be taken" (the stockpile and the first path lie by that end). On no side
tried was a square one taken and one along the path not. (A lot at 45 degrees lies cornerwise to the
grid, 21 m from corner to corner where a square one of 15 m spans 15: where the land falls along the
grid it meets more of the fall. No such place turned up in these.)

## What says nothing else moved

- **Square stockyards**: the three sites of `tools/stockyard_sites.sh` as they were (beside a path
  aslant; the largest on the hillside; beside a path at 45 degrees with `--no-yard-turn`), eighteen
  days each, are line for line the build before's (0 lines of 651 to 657 differ; the state differs by
  the blob's nine bytes).
- **Saves of the build before** (blob 38): a square storehouse standing, one with its yard 62 %
  laid, and a street of five turned hovels, each loaded by this build and run on six days, are line
  for line the build before's own run from the same save.
- **To the pixel**: the build before's game against this one's (the final commit's) on that street
  of turned hovels, on one of them with its roof cleared (the floor's rule in the shader was
  touched), and on the square stockyard, two stills of each: no pixel differs outside the one spot in
  each where something moves (the fire; a bed's cloth), where two stills of one build differ as much
  (28 to 323 pixels between the builds, 58 to 323 between two of one).
- The eight reference logs, line for line (they have no storehouse).
- **Saved and loaded**: the run on the flat saved on its fifth day (the roof going up), at six and a
  half (the yard being laid, the feet going by the drawing) and on its ninth (standing), each loaded
  and run to twelve, ends in the state of the twelve days straight (735be40d9b0cbb6a).

## Seen

`~/CASTLE_GAME/releases/stockyard_along_a_path.png`: from above; looked into from the path, its
front and roof cleared; from behind (a gateway, the fence and the coverings); being built; on ground
that falls 3 m (in shade: that still brightened 1.8 times); and from far off. A recording of the
storehouse standing, its roof cleared, shows people at its doorways as drawn and in it at its floor's
level. `~/CASTLE_GAME/releases/stockyard_tool_corners.png`: the stockyard tool's preview for three
pairs of corners, as the game shows it (evening: brightened 1.5 times): opposite corners of the lot;
the second straight across the path; the second straight along it.

**The builder, followed**: a recording from above with the eye held on where the storehouse's
builder is (the game's `--pointer` `follow I`, new) while the roof goes up. Her figure, which is
where she is drawn, draws away from that point step by step as she comes in with a load, to 4 or
5 m at her work at the wall as drawn, and comes back to it as she leaves: no jump in frames 0.6 s
apart. (Before the turn was eased the rule was all or nothing at 8.6 m from the storehouse's middle:
6.6 m at once.)

`~/CASTLE_GAME/releases/turned_builder_cloak.png`: the builder's cloak at a turned hovel in winter,
the same frame of the build before and of this one.

## Saves

Colony blob **39**: with a storehouse, the point it is turned about; and the switch. **Blobs of 30 to
38 are still read**: a stockyard they hold is as it was zoned, and one zoned from then on beside a
path at 45 degrees lies along it.

## Checks

- `path_check` 84 (it was 70): the walking map's list on the made-up meadow. A building walked where
  it is drawn: in at a doorway as drawn and nowhere through a wall as drawn; at the floor's level
  where its blocks stand, with one floor there; one doorway shut, round by the other, each way; both
  shut, no way in from thirty-six sides nor out (a wall at 45 degrees does not leak); whoever stands
  where a wall is drawn when it shuts walks off it; the list taken away, as its blocks stand again.
- `colony_check` 833 (it was 817): a blob of 38 loaded; and a section of fifteen: zoned either way
  the path runs, on either side; drawn along the path; every column of its ground at its level; the
  ways in by the doorways as drawn; where its blocks stand walked at its pad's level; each doorway and
  each gateway a way by itself; both gateways shut, the yard behind shut in (the stepped fence and the
  back wall as drawn let nobody through); no pit; saved and loaded to the same bytes; **fitted out as
  a square one of its size** (18 of floor, 6 of shelf, 6 and 2 barrels, 24 under the coverings, 9
  against the wall, 63 of the yard, 128 kept clear: the same of each); on ground rising a block every
  2.5 m, four of four, 733 steps each a wall of stone; every size from 15 m to 25 m (60 tried) taken;
  the player's two corners through `Castle.Actions`; `--no-yard-turn`.
- `pick_check` 78 (it was 69): pointing down at it where it is drawn says the storehouse; down at
  where its blocks stand, the yard; in at a doorway of it as it stands, ground that is not the
  cursor's to dig; somebody standing where its blocks stand is pointed at; somebody inside is not,
  through its roof, and is, with its roof cleared; never a person behind it as drawn.
- `tools/stockyard_sites.sh`: six sites (it was three): the three square ones, and three along
  their paths (the table above), which also fail on ground off its level, anyone in a wall as drawn,
  or nobody within it.

## Gate

Gate 65, from a clean copy of 1a3d9d0: both builds from nothing with the six known warnings and no
error; the nine checks in debug (water_sim 77, edit 41, ui 112, dynamics 18, serf 19, **path 84,
colony 833**, deer 14, **pick 78**), none failing; the eight reference logs line for line; the six
stockyard sites in release and in debug (where every mended stack of the walking map is checked
against a whole read); the three turned streets in release and in debug; the stress runner, nothing
died and nothing dropped; the flora hash unchanged (5676219328934879273 in both builds).

The stress states moved with the blob (a byte for the switch): six_4_years 509fbfe7fe017a53,
six_41_days 49a163ad8f019b3d, housing 7175f6bbb8f3ee48, crowd_as_it_is da01ba62dc8f571e, crowd at
work c75c2bce96045c24; each case agrees with its own variants. The eight logs, the three square
stockyards line for line and the saves of the build before run on are what says the behaviour did not
move where no stockyard lies along a path.

(A first gate was begun on a5300dd and stopped when the `follow` command went into the game after
it: the gate recorded is of the final code.)

`bin/` in the working copy was built from 1a3d9d0 (release and debug), his game not running;
`colony_check` (833), `pick_check` (78), `path_check` (84), `tools/stockyard_sites.sh` and
`tools/turned_streets.sh` were run from it.

## His calls (first values of mine)

1. **The coverings are stepped.** They could be made pieces drawn at any turn, as the cart and the
   barrels are, not blocks: clean edges, and nothing to walk into but their posts. That is a new kind
   of built thing (what a builder raises block by block would be raised some other way).
2. **The 3 m a stockyard's ground may fall is taken over the lot as it lies along the path.** On
   the steep hillside east of the stake no stockyard is taken either way (the table above), where a
   turned hovel is since his "they need to be able to place diagonals on hillsides if they want to".
   The number is his.
3. **The builder's turn is eased over 6 m** beyond where it works (`Ease_M`, the game's): it is drawn
   a little off where it walks for that far round the storehouse while its frame, walls and roof go
   up. A turned hovel's builder is drawn as before, all or nothing at 3 m: its neighbours stand
   nearer than the easing would reach.
4. **Two corners straight along the path's way, or straight across it, span a strip a metre wide**
   and are refused as too small: the tool's second corner is the lot's opposite corner, as a
   stockpile's is beside such a path. The preview shows the lot as the cursor moves.
5. The calls of the rounds before stand open as they were, at rest by his word.

## Known limits

- **What is dug or built where the storehouse's own blocks stand is not walked by** (the walking
  map has that ground level at its pad). The cursor is kept off it; a script or a later tool that
  edits there would have to tell the map.
- **The lord's cart at its front is drawn along the yard and stands square to the grid** for what
  asks where it is (the pointer, the places under it): its bed is a box along X or Y, as it always
  was. Up to half a metre out at its ends.
- The builder's ladder stands at the storehouse's wall as it stands and is drawn at it as drawn;
  whoever fetches it afterwards walks to where it stands.
- While its frame, walls and roof go up, the square its blocks stand on is a wall to the feet (its
  builder's own work), and its frame as it is drawn can be walked through, as a turned hovel's can
  while it is built. Nothing has business in the yard then (its places are closed), but whoever
  crosses the lot goes round what is not seen and through what is, for those three days or so.
- A strip of grass up to a metre wide lies between the path and the yard's beaten ground, where the
  lot's whole metres do not come to the path's edge: as beside a straight path.
- Not seen: the storehouse's own builder in winter (a hovel's was: above); a stockyard beside a path
  at 45 degrees that ends half way along its front.

## Still owed, not held

- The square a turned **hovel** really stands on is turf to the eye and a wall to the feet; a stair
  to a turned hovel's door is cut straight out from the walls as they stand; a turned hovel's
  builder jumps at its ring. **The storehouse's way (the feet by the drawing) would mend the first.**
- A faint line in the far view where a turned house stands (cause not found).
- The hunters, and the gatherers' hunger far out (put to him the round before).

## Test windows and input

Stills and six recordings in short windows of mine, each only when `pgrep` found his game not
running. All input scripted (the camera placed by options, the pointer parked or moved by
`--pointer`). Nothing pushed.
