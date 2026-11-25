# Castle Game handoff (2026-11-20: his design for placing zones with their paths, zones on their own grid, the homestake and the campfire made one)

The round before it is `Handoff_2026_11_20_walked_hovels_and_yard_pieces.md` (its "Next session: start
here" is what this answers). Everything is on branch `stockpile`, not merged; `main` is 537176c. No merge
word was given.

## John's words

The session was cleared and opened again ("Hello claude, ready to pick up where we left off?"). My reply
gave him, for the first time, the answer to his call 5 (whether building at an angle causes a lot of
issues: yes, as it is built; two ways on: a turned building's blocks kept in its own turned grid, or the
present way mended case by case) and said what would be built on no further word. His answer, whole:

> Ok, let's do this, let's lock the size of the stockpile, if the player places it, it will be a square box, lets fix the path artifcats by including the path in front of the stockpile, the player can rotate the placement. Since the paths are now snapped to specific directions, they can either align it with an existing path, rotate and snap it to the end of or if they orientate it at an angle to the middle of a path it will snap at that angle to the path. Along with a warning for overlap. This should make things easy for us and the player; and allow us to make the angled zones their own grid. We can do this with all zones including the stockpile. Let's merge the homestake and the campfire, no physical stake now, lets expand the campfire/homestake, to a 10x10 area, terriform so the entire area is flat, and build a path around the perimeter. The idea is when the campfire becomes obsolete, it can become the village center, or town square. The player can start building off of it as the please. This should solve a lot of other issues for us. Habitation zones can remain flexible the way they are. We can polish how the lots are built after we get through all of what we have on our plate, it's a lot. What do you think?
> To be clear, when the player starts laying the habitation what we are chaning with the zone right now is that it will include the path with the zone placement, it will allow either an overlap, extension, or intersection with an existing path.

## Read so, clause by clause

| | His words | Read as | When |
|---|---|---|---|
| 1 | "Ok, let's do this" | He takes the first of the two ways (what is built on an angled zone kept in a grid of its own), by the design that follows. **So his items 1 and 2 of the round before (hovel walls solid, the fence's posts turned) are not built the present way**: they come with the zone's own grid. Item 3 (the covering's roof) is untouched by this and still owed. | |
| 2 | "let's lock the size of the stockpile, if the player places it, it will be a square box" | The player's stockpile is one size, a square, put down whole: no corners drawn. 10 m a side (his figure of 2026-11-17, `Stockpile_Side_M`); as many as the player likes (his word of 2026-11-19). The scripts' two corners (`--stockpile`) stay, for the kept logs. | first pass |
| 3 | "lets fix the path artifcats by including the path in front of the stockpile" | The placement brings its own stretch of path along its front, one piece with the box, laid by the band as any path is. No report of his names the artifacts; what stills of this build show is below ("The join today"). | first pass |
| 4 | "the player can rotate the placement" | A key turns what is held an eighth at a time: eight ways. | first pass |
| 5 | "they can either align it with an existing path, rotate and snap it to the end of or if they orientate it at an angle to the middle of a path it will snap at that angle to the path" | Three snaps. Its path over a path that runs the same way (nothing new laid where one lies). Its path begun at a path's end, running on any of the eight ways. Its path's end on the middle line of a path that runs another way. | first pass |
| 6 | "Along with a warning for overlap" | Held over ground it cannot have, it is shown in the refused colour with the reason by the cursor, and a click there does nothing. Whether anything may ever be placed over something is his (call 2). | first pass |
| 7 | "allow us to make the angled zones their own grid" | The placement is the zone's frame: a corner and one of the eight ways, **saved with the zone from this round on**. What is built on an angled zone is to be kept on that grid: the engine's work, sized in the brief, not begun this round. | the frame now; the engine after the placements |
| 8 | "We can do this with all zones including the stockpile" | Every zone is placed so: the stockyard too. | after the first pass |
| 9 | "Let's merge the homestake and the campfire, no physical stake now, lets expand the campfire/homestake, to a 10x10 area, terriform so the entire area is flat, and build a path around the perimeter" | One placement begins the colony: a square of 10 m by 10 m (the camp is 7 m now), turned as the player likes, no post, the fire at its middle; the band levels all of it and lays a path round it. "The stake" stays a point, the fire's: the reach, the herds and the ground kept in are measured from it as before. | first pass |
| 10 | "when the campfire becomes obsolete, it can become the village center, or town square. The player can start building off of it" | Later. The square's four paths are paths like any other: a placement snaps to them. | |
| 11 | "Habitation zones can remain flexible the way they are" and "when the player starts laying the habitation ... it will include the path with the zone placement, it will allow either an overlap, extension, or intersection with an existing path" | Housing is still pulled to any length, and the pull lays its path with it: along a path that is there, nothing new; from a path's end, the path goes on; across or up to another, they meet. | after the first pass |
| 12 | "We can polish how the lots are built after we get through all of what we have on our plate, it's a lot" | The lots' polish (the stair to a turned door, the builder's jump, the hovels' walls) waits until the rest is through. | not now |
| 13 | "What do you think?" | Answered first in the reply (below). | |

## What I told him I think

It is right, and better than what I had put to him: I had each building as the thing with a grid of its
own; he makes the placed zone the thing, and it comes with its path and its way. Every system then has
one frame to ask of a zone instead of a case a building, and the two things most of the turned faults
came from go: a lot worked out afterwards from whatever path is nearest, and corners drawn by hand that
do not fit a diagonal. Three things said with it:

1. At 45 degrees a length does not end on a corner of blocks: 10 m is 28.3 blocks of a path's diagonal.
   So an angled box is 28 blocks along (9.9 m), that its path ends where another can join it.
2. A grid of its own is for what is built. The ground under it stays the map's, levelled; its edge can be
   drawn straight (as a turned hovel's floor is now), but a cut into a hillside steps unless its walls go
   on the zone's grid too.
3. The merge changes the first days of every game (some 100 square metres to level and 44 m of path
   before the band has a fire): to be measured against the start as it is; the kept runs hold the old
   start behind a switch.

## The join today (stills of this build, 54e7fdd)

A stockpile of 10 m by 10 m zoned beside a straight path and one beside a path at 45 degrees at the
reference site (`--paths-built --camp-built`, a quarter day). Beside the straight path the lot's side
lies on the path's edge. **Beside the path at 45 degrees the zone's edge is a sawtooth of block corners
all round, and slivers of grass lie between it and the path.** (Scratch stills; the pair to keep is made
with the first pass, before and after.)

## Gate 67 (the wrap-up's first item)

From a clean copy of 54e7fdd, both builds from nothing, six known warnings: water_sim 77, edit 41, ui
112, dynamics 18, serf 19, path 88, colony 845, deer 14, pick 78, all in debug and all passed; the eight
reference logs line for line; the six stockyard sites and the three turned streets in release and in
debug; the stress runner, nothing died and nothing dropped, **every state equal to gate 66's**
(six_4_years 7b5b27750ebfb6c6, six_41_days b249754bb0c8acfc, housing b1a987c8659fc4ff, crowd_as_it_is
27139037a77be695, crowd at work b0d6fe84b2d1863f); flora 5676219328934879273 in both builds. So 1964f96
(the stack's rim) moved no run.

The `CLAUDE.md` trim the wrap-up left uncommitted is committed (54e7fdd): the paragraph about it in the
handoff before this is out of date.

## The passes, as I read them (his "it's a lot")

Each a commit a rule, each with its switch; the kept runs and both `Reset`s hold the new rules off.

1. **First pass (this round)**: the covering's roof (his item 3, promised first); the stockpile put down
   as a square with its path, turned by a key, snapped three ways, refused with its reason shown; the
   homestake and the campfire one square with its path round it.
2. **After it**: housing pulled with its path; the stockyard put down as a box.
3. **The zone's own grid** (the engine): what is built on an angled zone kept on the zone's grid and
   read through it by one routine (walking, pointing, digging, the cleared roof, drawing, the far view,
   shadows, saves); the stockyard moved to it first (its fence's posts, its coverings, its storehouse),
   then the hovels. Sized in the brief before anything of it is built.
4. **The lots' polish**, by his word after all of that.

## His calls (each with what is built on no word)

1. **"10x10"**: taken as 10 m by 10 m of floor with the path laid round the outside of it (12 m over
   all). The other reading is the path inside the 10 m (8 m of floor).
2. **The warning for overlap**: shown, and the click refused. The other reading lets a placement go over
   something, and then what gives way is his to say.
3. **Sizes**: the stockpile 10 m square, as many as wanted; the stockyard one size too when it is placed
   so (16 m square, the size every measured site of it has used).
4. **Housing's side**: one side of the pulled path a pull, the turning key changing the side. The other
   reading is houses on both sides at once.

## His answers to those (the same hour, while the roof was being built)

> so for angled zones what happens is, the .25m blocks around it that will fit the zone are terraformed. Make terraforming for zones take as much of a 1m section as the can. The path artifacts are when the zone collides with the path and part spills/wraps over the end, or disrupts the box. So don't worry about that. Yes place the path around the outside of the 10x10m so it will be 12x12m when it's built. for the overlap, the click is refused for special zones like the stockyard/storehouse zone. The habitation can continue to overlap and join as is. Sizes stand, but you may modify at your discresion. Housing on one side, if they want both sides they can lay down the zones twice. OR we can allow the player to select a double or single row?

| His words | Answers | So |
|---|---|---|
| "for angled zones ... the .25m blocks around it that will fit the zone are terraformed. Make terraforming for zones take as much of a 1m section as the can" | my second point (the ground under a zone's own grid) | **His rule for an angled zone's ground**: it is the map's quarter-metre blocks that fit within the zone, made level; the work goes a square metre at a time, and a metre the zone's edge cuts is taken as far as it lies in the zone. So an angled zone's edge on the ground steps by the block, and that is as it should be. |
| "The path artifacts are when the zone collides with the path and part spills/wraps over the end, or disrupts the box. So don't worry about that." | "The join today" above | The artifacts are a zone wrapped round a path's end or a box broken by a path (his note of 2026-11-17: a zone that "wraps around the end of a path"), which a placement that brings its own path cannot do. **The sawtooth edge is not a fault**: nothing is built against it. |
| "Yes place the path around the outside of the 10x10m so it will be 12x12m when it's built." | call 1 | 10 m by 10 m of floor, the path round it, 12 m by 12 m over all. |
| "for the overlap, the click is refused for special zones like the stockyard/storehouse zone. The habitation can continue to overlap and join as is." | call 2 | A placed box (the stockpile, the stockyard, the square) over anything is refused, with its reason shown. Housing joins and overlaps housing as it does today. |
| "Sizes stand, but you may modify at your discresion." | call 3 | 10 m and 16 m, mine to change with a reason. |
| "Housing on one side, if they want both sides they can lay down the zones twice. OR we can allow the player to select a double or single row?" | call 4, and a question | One side a pull. The question answered yes: the key that turns a box steps a housing pull through one side, the other side and both (a double row), built with the pull. |

(Being built: what follows is written as each piece closes.)

## Built: the covering's roof (his item 3 of the round before)

His words: "connect the rounded edges together along the length, and texture the roof of the outdoor
storage the same as all the other roofs, that is the defult for all thatch roofs".

- **The rounded edge is one roll from corner to corner.** It was a metre at a time, each piece's ends
  rounded off, so the edge read as a string of pieces. Now a piece reaches 15 cm past each end of its
  metre (`Castle.Props.Roll_Lap_M`) and every second piece is half a centimetre narrower
  (`Thatch_Roll (Inner => True)`): where one is rounded off its neighbour is whole, and no two of one
  width lie in each other (they would show now one and now the other). Which metre is which goes by
  where it lies along the row of coverings, so the edge runs on across coverings that meet; along the
  back the other way round, and down an end from the other of its front corner's. At a corner the two
  edges end in one rounded knuckle.
- **The roof's texels are the land's own for a block of thatch** (`Castle.Textures`, made from the
  world's seed, `Castle.Props.Set_Texel_Seed`): a variant a block by its place on the roof, the dark
  line at each course's lower edge. It had texels of its own (a regular chequer).
- A prop's skin can be filled where no face lies (`Many_Boxes`' `Fill`): the roof's and the roll's are,
  with straw, so no dark rim shows on them from afar.
- **`--no-cover-thatch`** (the game's; `Castle.Props.Cover_Thatch`): as it was drawn.
- Drawing only: nothing of the colony, the blocks or a save is touched.

**Measured.** Close to a square stockyard's covering at 13 h, the roof's middle is the colour it was
(151, 115, 41 against 150, 115, 41 of 255): the same straw, other texels. A hovel's dressed roof in the
same light is (82, 64, 25) on its sunlit slope: the same hue (red to green to blue as 1 : 0.77 : 0.28),
half as bright because it stands at 45 degrees to a high sun where the covering lies nearly level.
**With the switch off the picture is the build before's**: three stills of each build close to the
covering, 0 pixels apart; three of the turned stockyard from 30 m, 233 to 1,588 apart where the build
before is 364 to 1,636 from itself.

**Seen**: close and from 60 m, a square stockyard and one along a path at 45 degrees; half smoothed
(day 27, 13 h: the roll along a part roof's front and outer end, the stepped rows behind); in rain and
at night. `~/CASTLE_GAME/releases/cover_roof_thatch.png`.

**What it is not.** The roof is still a piece lit as the cart and the barrels are: in rain it does not
darken as the land's thatch does, and it is one even plane where a dressed roof's top is ragged (his
word for the covering was a smoothing). A dressed block falls a whole block a block; a covering falls a
quarter of one, so it cannot be dressed thatch as it stands.

## Built: the stockpile put down whole, with its path (colony blob 42)

His words: "let's lock the size of the stockpile, if the player places it, it will be a square box, lets
fix the path artifcats by including the path in front of the stockpile, the player can rotate the
placement ... they can either align it with an existing path, rotate and snap it to the end of or if they
orientate it at an angle to the middle of a path it will snap at that angle to the path. Along with a
warning for overlap."

**Where the build departs from what I told him.** I said an angled box would be 28 blocks along
(9.9 m). It is **29 (10.25 m)**: the least whole number of slanting blocks not shorter than 10 m, so that
an angled stockpile has its hundred places as a straight one has (28 gave nine rows of ten).

What the player does: the Stockpile tool holds a box by its middle; **Z and X turn it** an eighth a
press (`Castle.Input`'s `Turn_Held_Left`, `Turn_Held_Right`); a click puts it down; the tool stays in
hand for another; Esc puts it away. The ground's menu has "Stockpile, 10 by 10 m, with its path", which
takes the tool up. Held where it would be refused, the box is drawn in the refused colour and **the
reason stands by the cursor** at once.

In the colony (`castle-colony.ads`, "placements"):

- **`Box_At (Kind, Middle, Way)` is the one routine that says where a held box lies**; what shows it
  (`Plan_Box`) and what places it (`Place_Box`) both ask it, and held by its own middle (`Box_Middle`) a
  box is given back as it is. `Castle.Actions`' `Place_Stockpile` order carries the middle and the way
  (`Pile_Way`).
- **The box**: its path a stretch along its front, begun on a corner of blocks, a whole number of
  blocks along one of the eight ways; the box on the left of that way from the path's edge back, 10 m
  deep, as long as its front (10 m straight, 10.25 m aslant). On open ground every block column of the
  box is its ground and none lies between it and its path, at all eight ways (the check, and
  `colony_run --box-stats`).
- **Drawn to a path that is there** (one that lies on the corners of blocks), by the least move of:
  *along* (turned that path's way or straight back along it, its front within 5.5 m of the path's line:
  its path is that line and nothing new is laid where a path lies; an end of it within 2 m of an end of
  the path, or of a box put down along that line already, is put there); *an end* (turned another way,
  an end of its front within 2 m of a path's end); *the middle* (an end within 2 m of a path's line: its
  path meets that line where its own line crosses it). Where its path meets another so, the box begins
  as many blocks on as keep it off that path: two squarely, one aslant on the open side. On the side
  the other path runs into, it cannot be kept off it and is refused.
- **Refused**, with the reason: no ground under its path's ends; a zone or the lord's cart in its
  path's way; any of its box a zone's ground ("it overlaps a stockpile", "... the camp", "... housing",
  "... the stockyard") or a path's ("it overlaps a path"); no place on its ground.
- **Its path** is laid as any path is, by the band, only where no stretch lies along its line already
  (`Path_Gaps`): beside a path, none; from a path's end, the part beyond.
- **Its lot** is planned by the lot planner every zoning uses (`Plan_Lot`, which can now measure from a
  corner of the lot's own, `Oa`, `Ob`, and leave a side undrawn, `Drawn_Out`), with its own path taken
  as lying there: its ground the block columns whose middles lie in the box (his "the .25m blocks around
  it that will fit the zone"), its places on its own whole metres. A tree, a bush or a boulder in it
  leaves places out, as in a stockpile zoned by two corners; nothing is cleared for it.
- **The zone keeps its frame** (`Zone_View.Placed`, `From`, `Way`, `Along_B`; saved): where its front
  begins on its path's middle line, which way, how many blocks. That is the grid what is built on an
  angled zone is to be kept on.
- **A slanting box's two ends run through the middles of blocks**: such a column is the box's at its
  beginning and not at its end (`Box_Edge_M`, a centimetre), the same in the counting and in the lot,
  so a box begun where another ends has what the other leaves. (Found by the check: without it 13 to
  29 columns of a box turned north-east or south-west went by which way the sum fell.)
- `Set_Box_Place` (`--no-box-place`): the player's stockpile zoned corner to corner, as before. The
  scripts' `--stockpile X0 Y0 X1 Y1` is unchanged; `--stockpile-box X Y WAY` puts a box down as the tool
  does. `colony_check`'s and `pick_check`'s `Reset` hold the switch off.
- The game's `--pointer` has `turn N`.

**Measured.**

- The eight reference logs line for line (the lot planner's two new parameters change nothing where
  they are not given).
- `colony_run --box-stats`, the reference site: a box along the first path is 98 places (the bush at
  its corner), the 98 the two corners gave; along the path at 45 degrees, on its clear side, 1,653 block
  columns all its own and 100 places.
- Twenty days of the band of thirteen with its housing, one run each: the box beside the first path 13
  living, nobody starving, confidence 76 % at the end; the two-corner stockpile there 77 %; a box held
  free 25 m off, with 10.25 m of path of its own, 62 % (86 places among bushes, further to walk). The
  band laid the free box's path and pulled the lord's cart into the box.

- **What holding it costs**: 0.6 to 0.8 ms of the main thread a frame (1.9 to 2.1 ms against 1.3 with
  the path tool in hand, three runs of 2,900 frames each, nothing else running): its lot is planned anew
  every frame, as every zone's preview is. Held where it is refused (before the lot is planned) it
  costs nothing to tell (1.36).
- **Checks**: `colony_check` 871 (it was 845): a section of 25 (every way on open ground: a hundred
  places, a path from a corner of blocks to one, every block column of the box its ground, held by its
  own middle it lies as it lay; each way it is drawn to a path, and the side it is refused on; refused
  over a stockpile and across a path; against a neighbour; the player's order and the menu; saved and
  loaded to the same bytes; a street's lots not moved by a box put down beside its path), and a blob
  of 41 loaded. In debug, with `pick_check` 78, `path_check` 88, `ui_check` 112, `edit_check` 41,
  `serf_check` 19.

**Seen** (`~/CASTLE_GAME/releases/stockpile_box.png`): held along a path at 45 degrees; going on from a
path's end; a branch from a path's middle; refused over a stockpile, its reason by the cursor.

**Not exercised**: the Z, X and Esc keys themselves (a scripted run reads no keyboard: the scripted
pointer's `turn` sets what they set).

## Built: the homestake and the campfire one (colony blob 43)

His words: "Let's merge the homestake and the campfire, no physical stake now, lets expand the
campfire/homestake, to a 10x10 area, terriform so the entire area is flat, and build a path around the
perimeter. The idea is when the campfire becomes obsolete, it can become the village center, or town
square. The player can start building off of it as the please"; and, of my first call: "Yes place the
path around the outside of the 10x10m so it will be 12x12m when it's built."

**Where the build departs from his words, or goes past them.**

1. **Something may stand on the square, but not by its fire.** The camp's own rule refuses a camp with a
   tree, a bush or a boulder anywhere on it. Kept for 12 m by 12 m it refused half the places a square
   could otherwise be founded on (`colony_run --square-census 48 4`, below), and the old stake could be
   raised anywhere. So a thing standing within 4 m of the middle refuses it (the fire, its seats, its
   wood); further out it is left standing and the square is made round it. His to say (call 5).
2. **On rising ground the square is a terrace, and its path is level with it only where the land is
   within half a metre of its level.** All of its floor is brought to one level (earth dug off the
   high side, filled on the low). Its path is laid as any path is and brought to the square's level
   where the ground lies within half a metre of that (the paths' own rule for how far they move the
   ground); beyond that it lies as the land does, and a bank of earth stands between it and the floor.
   No wall of stone and no stair is built there, as there is round a hovel's terrace. His call 6.
3. **All of the floor is trodden to bare earth**, as the ground by a camp's fire is. He said flat; he did
   not say what it is covered with.
4. **The scripts' `--stake` and `--camp` found a colony as they did.** Every kept run and every site of
   the gate says them, with paths that begin where a square would lie. `--square X Y WAY` founds one the
   new way; the player's Homestake tool is the square (`--no-square`: the post, the camp zoned apart).

What the player does: the Homestake tool holds the square by its middle, its path round it; Z and X
turn it (squarely or aslant: there are two ways it can lie); a click founds the colony. Held where it
is refused it is drawn in the refused colour, the reason by the cursor.

In the colony (`castle-colony.ads`, "the homestake and the campfire one"):

- **`Place_Square (Middle, Way, Band, Seed)`** founds it: the stake's place is the fire's, the square's
  middle, on a corner of blocks (`Place_Stake` with `Post => False`: no post); the band arrives round
  it; the square is the camp's zone, 10 m a side squarely and 9.96 m aslant (its path's corners 31
  blocks from the middle along X and Y, so its sides run from corner of blocks to corner of blocks);
  round the outside four stretches of path from corner to corner, 12 m over all. `Plan_Square` is what
  it would take; `Square_Refusal` why not: a stake raised already; no ground under its middle; water;
  ground more than 1.5 m off its middle's level (`Square_Fall_M`) or with a bank of 2 m in it; something
  standing within 4 m of its middle (`Square_Core_M`).
- **All of a square is the camp's floor** (`Camp_Square`, saved; `Near_Fire` is true of all of it): the
  band makes it ready a square metre at a time, digs it to its level and fills its hollows with the
  earth, treads it bare, and only then is the hearth built, as a camp's is.
- **Its path** is four paths like any other (a box is drawn to them, along a side or at a corner; a
  path goes on from a corner). A block column of path round the square is laid at the square's level
  where the ground is within half a metre of it (`In_Square_Path`, in `Lay_Metre`).
- **"The stake" is still a point**: the reach, the herds, the ground kept in and the cart's place are
  measured from the fire as they were from the post.
- The zone keeps its frame (`Placed`; `From` the first corner of its path's line; `Along_B` 44 or 31).
- `Castle.Actions`: a `Raise_Stake` order says `As_Square` and `Stake_Way`; `Square_Stake` is what the
  player's own orders are (the menu's line holds it to be turned). `colony_check`'s `Reset` holds it
  off. Not saved: it is how an order is made.
- The game's scripted pointer runs from when the view has filled in a game no option founds a colony
  in, so the founding itself can be pointed at and clicked.

**Measured.**

- **Where a square can be founded** (`colony_run --square-census 48 4`: its middle tried every 4 m
  within 48 m, 441 places, squarely; aslant within a few of the same):

  | round | taken | refused for something by the fire | for water | for the ground | no ground at its middle |
  |---|---|---|---|---|---|
  | the reference stake (1178 1078) | 95 | 88 | 0 | 253 | 5 |
  | open land by the river (1000 900) | 183 | 88 | 79 | 23 | 68 |
  | 1100 1000 | 6 | 15 | 65 | 322 | 33 |
  | 900 1100 | 0 | 22 | 0 | 408 | 11 |

  With the camp's rule (nothing standing anywhere on it) the first two took 64 and 107. "For the
  ground" is ground that lies more than 2 m over its middle or 4 m under it somewhere on it: the
  hillside and the mountain. Not one place of all four was refused for lying between 1.5 m and that.
- **What the new start costs** (fifty days, the band of thirteen with its housing, its stockpile and its
  stockyard, one run each; the square where the camp was, its path's south side part of the street):

  | | hungry serf-hours | lowest confidence | living | the fire's first log burnt | first five days' hungry hours |
  |---|---|---|---|---|---|
  | the reference site, as it was (`--stake`, `--camp`) | 1,318 | 46 % | 13 | day 20, 16 h | 109 |
  | the same, founded on a square | 1,412 | 43 % | 13 | day 20, 19 h | 93 |
  | the open site, as it was | 1,154 | 47 % | 13 | day 20, 17 h | 114 |
  | the same, founded on a square | 992 | 48 % | 13 | day 20, 21 h | 102 |

  The fire burns three to four hours later (a hundred square metres to make ready where there were
  forty-nine, all of them to level and tread where there were twenty-one); nothing else moved by more
  than one run differs from another.
- **Awkward places** (twelve days each, squarely and aslant, a stockpile put down against each of the
  four sides of its path): rising ground north of the reference stake (1172 1092: 1,959 blocks of
  earth to dig off and 923 to fill; 1160 1090), bushes and a boulder by (1186 1068), trees by the path
  at 45 degrees (1150 1062), the open site (1000 912, 1010 890). All twelve: founded, four stockpiles
  put down (64 to 100 places each), the fire burning (33 to 35 logs burnt), 13 living, no line of
  anyone starving.
- **Checks**: `colony_check` a section of 13 (founded squarely and aslant by one order: no post, the
  stake the fire's place, the floor all the zone's, four stretches round it, footpath where it should
  be and grass past it; the cart clear of both; once only; a stockpile drawn to a side of its path and
  refused on its floor; saved and loaded; refused for water and for a boulder by the fire; a boulder
  further out left standing; on ground rising a block a metre every one of its 1,600 block columns at
  one level and trodden bare, 160 of its path's level with it and 540 as the ground lies, no pit among
  1,359 spots; refused on ground rising a block every half metre; the band of six building it: ground
  ready in 131 colony seconds, path laid in 250, hearth standing after 213), and a blob of 42 loaded.

**Seen** (`~/CASTLE_GAME/releases/founding_square.png`): held aslant; three days on, a street begun
from its path; on rising ground, a stockpile against each side; founded aslant.

**Not exercised**: the keys themselves, as above.

## Gate 68

From a clean copy of 10a76f9, both builds from nothing, the six known warnings: water_sim 77, edit 41, ui
112, dynamics 18, serf 19, path 88, **colony 885**, deer 14, pick 78, all in debug and all passed; the
eight reference logs line for line; the six stockyard sites and the three turned streets in release and
in debug; the stress runner, nothing died and nothing dropped, each run's state equal to its fellows'
(six_4_years bcd712a4fd9ea6d9, six_41_days d580854cf5cac587, housing 6794042cea5a9e70, crowd_as_it_is
65a9d38031d4e79a, crowd at work 3f7c2c6949cec18c: every hash moved from gate 67's, as a blob that
carries four bytes more must: a byte for the box switch, one a zone, one for the square); flora
5676219328934879273 in both builds.

`bin/` in the working copy is built from 10a76f9 (release and debug, his game not running), and its
`colony_check` run in debug: 885.

The zip of the round is `~/CASTLE_GAME/releases/castle_game_placements_and_the_square.zip`.

## After gate 68: the square and the box tried the way the player makes them

Gate 68 proved the runner and the checks. Before the pass was called done the two things he does first
in the game were tried as he does them, and the square's ground was looked over for pits with things
standing on it. **Five faults of mine in 10a76f9, all mended; one of them was a thing I had told him
that was not so.** (1f47f1c the first four and the two of the interface; the fifth its own commit.)

1. **A tree anywhere on the square refused it, and the reason shown was the wrong one.** I had told him
   "a tree, bush or boulder within 4 m of the middle refuses it; further out it is left standing". For a
   bush and a boulder that was so. A tree's trunk read as ground more than 2 m off the middle's level, so
   a square with a tree anywhere on its floor or its path was refused with "the ground rises and falls
   too much for it (it is 200 cm off its middle's; 150 cm at most)". The census figures I gave him (95 and
   183 of 441) were measured with that fault in them. Now the ground is read under whatever stands on it
   (`Top_By`), and a tree's foot or a boulder refuses the square only within 4 m of its middle.
2. **A bush left standing where the floor is filled up round it stands in a hole a serf drops into and
   cannot climb out of.** Made in the check (a bush three blocks across on the low side of ground rising
   a block a metre: four spots of pit); **not found at any real site** (the scan below, with the colony as
   it was at 10a76f9: 199 squares, no pit). Now **bushes on the floor, and what hangs low over it of a
   tree, are cleared at the founding**, and their ground is floor like the rest (`Plan_Lot`'s
   `Clear_All` with `Keep_Feet`: all of the box but a tree's foot). A bush no longer refuses a square
   anywhere.
3. **A tree left standing on the floor is spared by the foresters, as an apple tree is**
   (`On_Square_Floor`, in `Go_Fell`). Felled, its foot left a hole in a floor filled up round it (made in
   the check: four spots of pit once the trunk was gone). Levelling its place when it is felled was
   tried first and given up: before the floor is made it digs a hole of its own on the high side.
4. **A floor that would lie cut off is refused** (`Cut_Off`): made level, some of its edge must have
   ground beside it within a step (half a metre) of its level, two metres' worth of block columns, or
   nobody could come back up onto it, or out of it. A knoll 7 m across and 1.5 m high does it in the
   check; **none of the 798 real places the census takes is refused for it.** With the band's labour off
   the floor is left as it lies and nothing is asked.

5. **Whoever stood on the square's floor more than 3 m from the fire, while the ground was dug or filled
   under them, stood in it or over it until they next walked** (by up to half a metre: `Settle_On_Floor`
   settled only those by the fire, as for a camp, whose floor reaches no further). It reaches the
   square's corners now. Measured (`colony_run --feet-stats`, kept: each colony second, how far each
   one's feet are off the nearest floor of the cell they are in): on the three squares with the most to
   dig and fill, two days, 83, 52 and 156 serf-seconds of 37,440 more than a block off before, 63, 32
   and 154 after; **all 23 that are more than a step off are someone walking**: stepping down a bank at
   the square's edge (a metre at the most, which the walking map lets a serf do), or across a patch dug
   since its way was planned (a second in the air, until the way is planned again: as on any ground the
   band digs). Nobody stands so. The old founding on its level ground: none.

And two of the interface:

6. **`--no-box-place` did nothing in a game whose colony the player founds by hand** (it was applied
   only when a scenario founds one). It is applied at once now, as `--no-square` is. Shown: two stills
   of the Stockpile tool after a founding by the tool's click, the box held without the option and the
   two-corner tool with it.
7. **The reason by the cursor stayed there** once the cursor was off the ground or over a panel
   (`Tools.Warn` was written only when a preview was drawn). It is cleared every frame first.

**What was tried, and what it showed.**

- **Founded by the tool's click in the game**, in release (aslant, at 1172.25, 1081.75) and in debug
  (squarely at 1146, 1110: ground that takes 1,190 blocks of digging and 1,149 of filling, a tree on its
  floor), at speed 120, saved a day on by `--save-at`, the save run on in the runner in release and in
  debug: floor level, its hearth standing, one block column nobody's (the tree's foot), its path laid a
  day later. No exception in debug. (The stills before this stopped at the hover.)
- **Saved half built, run on from the save: the straight run's state**, twelve times of twelve: the
  old founding (the control), a square on that sloping ground with a stockpile against its west side,
  a square aslant on the open land with two, and the old founding with a stockpile put down free (its
  own 10 m of path to lay), each saved after 90 colony seconds, six hours and a day and run on to three
  days (`$S/half.sh`, `half2.sh`). The path round a square is not begun on the first day: the band
  builds the hearth first; it is laid by the third.
- **Squares founded and made on the spot at real places** (`colony_run --square-scan 96 16`, kept: a
  16 m grid within 96 m of each of ten places of seed 1, squarely and aslant by turns; every spot within
  9 m of the middle that can be got to from the fire is asked the way back): **286 founded, no pit by
  any; every fire got to and from the land 14 m off on two sides at the least (251 on all four, 23 on
  three, 12 on two); 61 block columns left out of their floors (trees' feet).** With the colony as at 10a76f9: 199 founded, no pit, 511 columns left out
  (bushes and trees' feet).
- **Where a square can be founded now** (`--square-census 48 4`, 441 places): round the reference stake
  164 squarely and 175 aslant (153 refused for a tree or a boulder by the fire, 121 for ground more
  than 1.5 m off, none for a floor cut off); on the open land by the river 230 and 229 (60 for something
  by the fire, 83 for water, 68 for no ground under some of it).
- **The twelve awkward sites**, twelve days, a stockpile against each side: all founded, the fire
  burning (33 to 35 logs burnt), thirteen living, nobody starving. **Fifty days at the two baseline
  sites**: 1,412 hungry serf-hours and 43 % at the worst by the reference stake (as before); 878 and
  62 % on the open land (992 and 48 % before: another run, since its bushes are cleared).
- **The held stockpile swept** (new checks): every 0.35 m and every way round a straight path and one at
  45 degrees (90,149 holdings) and round the square, squarely and aslant (67,712 each), in debug: no
  exception; held again by its own middle each lies as it lay, or (1.5 to 3 % of them, held at the very
  edge of a path's reach) is drawn to that path and then does; none goes on moving; of 307 put down,
  none has a path's ground or another zone's in its box.
- **Squares saved by 10a76f9** (on the hillside squarely and aslant, on the flat with stockpiles
  against them) load in this build and run four days: thirteen living, nobody starving, their paths
  laid.
- `colony_check` is 891 (six more: the two sweeps of the square, the one of the paths, the trees' feet
  and bushes on a slope, the spared pine, the knoll). `tools/square_sites.sh` (kept, in the gate): the
  scan at the ten places, the twelve awkward sites, and a square saved half built and run on.

## Gate 69

From a clean copy of 3eff3c6, both builds from nothing, the six known warnings: water_sim 77, edit 41, ui
112, dynamics 18, serf 19, path 88, **colony 891**, deer 14, pick 78, all in debug and all passed; the
eight reference logs line for line; the six stockyard sites and the three turned streets in release and
in debug; **the square's sites** (`tools/square_sites.sh`, new in the gate: 286 squares at ten places,
none with a pit, none whose fire cannot be got to; the twelve awkward sites; a square saved half built
and run on); the stress runner, nothing died and nothing dropped, **every state equal to gate 68's**
(six_4_years bcd712a4fd9ea6d9, six_41_days d580854cf5cac587, housing 6794042cea5a9e70, crowd_as_it_is
65a9d38031d4e79a, crowd at work 3f7c2c6949cec18c: no colony but one founded on a square was touched);
flora 5676219328934879273 in both builds. The square's sites pass with the debug build too (run apart,
four minutes; in the gate from the next one on), the half-built run's state the same in both builds
(3421951c0288446f).

`bin/` in the working copy was built from 3eff3c6 at 14:40 (release and debug, his game not running).
The zip of the round, `~/CASTLE_GAME/releases/castle_game_placements_and_the_square.zip`, is remade from
3eff3c6's tree.

## Built: housing pulled with its path (the second pass of his order)

His words: "To be clear, when the player starts laying the habitation what we are chaning with the zone
right now is that it will include the path with the zone placement, it will allow either an overlap,
extension, or intersection with an existing path"; "The habitation can continue to overlap and join as
is"; "Housing on one side, if they want both sides they can lay down the zones twice. OR we can allow
the player to select a double or single row?" (answered yes, by the key that turns a box).

**What the player does.** The Housing tool: a click where it begins, the path's line follows the cursor
(one of the eight ways, as the path tool's does), a click puts it down: its path is planned for the band
to lay and housing is zoned along it. Z and X step the rows: this side, the other side, both. Shown
before the second click: the line, each row's ground, and (refused) the row's outline in the refused
colour with the reason by the cursor.

**Where the build goes past his words, or reads them.**

1. **"Overlap" is his gesture as it was.** Begun within 12 m of a path (`Housing_Snap_M`, his figure of
   2026-11-12) and pulled the way that path runs, beside some of it, it is housing along that path: no
   path is laid, and the strip is **Zone_Housing's for the same two points, block column for block
   column** (checked on eight pulls: near and 11.5 m off, short and long, either way, on the path
   itself, beside a path at 45 degrees). What that reach costs him: this tool cannot begin a second
   street parallel to a street within 12 m of it (it is read as housing along the first); the path tool
   lays any path.
2. **"Extension"**: pulled past an end of that path by half a metre or more, the path goes on from its
   end to where the pull went (a whole number of blocks), and the housing with it. Before, the strip
   stopped 1.75 m past the end.
3. **"Intersection"**: begun elsewhere, or pulled another way, its path is a line of its own, as the path
   tool draws one: from a path's middle line or end where it is begun on one, up to a path it comes
   to, or on across it. What of the line a path lies along already is not laid again.
4. **Where its path would run through housing already zoned, the housing gives way** (the block columns
   under the path are no zone's any more; the lots still to begin are laid out anew). Without this,
   once a street has housing along both its sides nothing can leave it but from its ends. Not through a
   hovel's lot, begun or standing, nor a stockpile, the camp, the stockyard or the lord's cart: refused,
   with the reason. **The path tool is as it was** (a path alone goes round zones). His call 10.
5. **The rows.** "This side" is the side it was begun on. Begun on its own line (a line of its own
   always is), that is the left of the way it was pulled; or the right, where the left can take no
   housing and the right can (along a side of the square: the side off its floor).
6. As before: a row is 9.5 m deep (13.4 m beside a path at 45 degrees), a pull 60 m at the most, the
   lots laid out by the band's own rules. Nothing of a pull is saved that was not (paths and housing
   zones): no blob change.
7. `--housing X0 Y0 X1 Y1` in scripts is the strip beside a path, as ever (the eighth reference log is
   line for line); `--housing-pull X0 Y0 X1 Y1 ROWS` (0 this side, 1 the other, 2 both) is the pull;
   `--no-housing-pull` gives the player the old tool (`Castle.Actions.Housing_Pull`, set where the option
   is read).

**In the code.** `Castle.Colony.Pull_Line (Begun, Pulled_To)` reads the two points once (`Pull_View`:
its line, along a path or not, which side is the side begun, how much path is new); `Plan_Housing_Pull
(Line, Begun_Side)` plans one row with nothing changed (its path taken as lying there: the stretches
`Lay_Path` would keep it as, appended for the plan and gone again); `Pull_Housing (Line, Rows, Lots)`
plans every row asked and every stretch to lay before laying anything, takes housing out from under its
path (`Unzone_Box` with a column test), lays the stretches, zones the rows. The strip's planner
(`Plan_Housing_Lot`) has one new defaulted parameter, the stretch it lies along; `Path_Gaps` is
`Line_Gaps` for any line. The order is `Castle.Actions.Pull_Housing` (Begun, Pulled_To, Rows); the
interface's three ways in (the tool's click, "Housing to here", the ground's menu) give it when the
switch is on.

**Measured.**

- `colony_check` is 909 (18 new, "housing pulled with its path": his gesture as it was; the other row
  and both; past either end; a line of its own with each row, what was planned being what was taken;
  31 m at 45 degrees with the band's labour on, one strip a row; a second pull from its end; from the
  square: out from every corner every way that leads away, out from each side's middle, along each side
  either way, squarely and aslant; up to a path and across one; a street off a street through its
  housing; refused through a hovel's lot and a stockpile; the order, the menu, a serf may not; a save).
- **By the tool's own clicks in the game**, release and debug: founded, a pull of both rows, a second
  north off it through its housing ("housing gave way under it"), a stockpile put down; saved; the save
  run on six days in the release and the debug runner: thirteen living, the same state in both.
- **Fifty days at the two baseline sites**, the streets pulled east and west from the square's south
  corners, both rows, a stockpile against its north side: 1,031 hungry serf-hours and 59 % at the worst
  by the reference stake, eleven hovels standing; 984 and 56 % on the open land, seven standing; nobody
  starving.
- **The frame while a pull is held**, 60 m at 45 degrees: one row 4.4 ms more, both rows 7.4 ms more
  (the old tool's one strip of that length is about the one row's). The row the first reading looked at
  is kept, not planned twice (before that: 6.8 and 10.7 ms).
- **Saved with its paths still to lay and run on: the straight run's state** in a colony where nobody
  builds (three of three: after 90 colony seconds, six hours, a day; four days in all).

**Found, not of this round, not mended.** A colony in which hovels are being built, saved in its first
day and run on, does not end in the state of the run that was not broken (seven days: one hovel more
standing, the lots laid out otherwise; thirteen living either way). It is so with housing zoned the old
way too, and **in the build before this round** (54e7fdd): `$S/half4.sh oldhousing ...`. A save after
four days does end the same. The pull's own state carries over exactly (above).

## Gate 70

From a clean copy of cc0c8f0 (the housing pull), both builds from nothing, the six known warnings:
water_sim 77, edit 41, ui 112, dynamics 18, serf 19, path 88, **colony 909**, deer 14, pick 78, all in
debug and all passed; the eight reference logs line for line; the six stockyard sites and the three
turned streets in release and in debug; the square's sites in release and in debug (286 squares, none
with a pit; the twelve awkward sites; the half-built run's state 3421951c0288446f in both); the stress
runner, nothing died and nothing dropped, **every state equal to gate 69's** (six_4_years
bcd712a4fd9ea6d9, six_41_days d580854cf5cac587, housing 6794042cea5a9e70, crowd_as_it_is
65a9d38031d4e79a, crowd at work 3f7c2c6949cec18c: the strip beside a path, which those runs zone, is
untouched); flora 5676219328934879273 in both builds.

`bin/` in the working copy was built from cc0c8f0's tree at 15:30 (release and debug, his game not
running), and its `colony_check` run in debug: 909.

## His answer to two of the square's calls (2026-11-20, while the pull was being built)

Whole:

> a tree left on a square, can stay in habitation zone, if it doesn't interfere with anything, or felled and removed anywhere else.  stone wall and stair, also step the stone walls towards the higher ground if over 1m. so from lower ground for each 1m of retaining wall step inwards .25

Read so (the reading is put to him in the report that follows it):

| | His words | Read as | When |
|---|---|---|---|
| a | "a tree ... can stay in habitation zone, if it doesn't interfere with anything" | In housing a tree stays where it is in nothing's way, as it does today (no lot is laid out on it; a tree between two houses keeps them apart). One that is in the way of a lot being felled is the lots' own pass (clearing a lot is not built), written into the brief, unbuilt. | the lots' polish |
| b | "or felled and removed anywhere else" | **On the square a tree is felled and taken out by the band, and its place made floor**: it neither refuses the square nor is left standing (this takes back call 5's tree and call 9; a boulder is as it was). The stockyard clears its trees already. A stockpile's box still leaves a tree standing and goes without the places under it: asked of him, with that as what stands on no word. | next, its own commit and switch |
| c | "stone wall and stair" | The square's banks are held by walls of stone, with a stair where the way onto it is more than a step, as round a hovel's terrace (call 6). | next, its own commit and switch |
| d | "also step the stone walls towards the higher ground if over 1m. so from lower ground for each 1m of retaining wall step inwards .25" | A retaining wall higher than a metre is stepped back toward the higher ground: counted up from the lower ground, a block (0.25 m) back for every whole metre of wall. Built for the square's walls with (c); a hovel's terrace walls are as they were (asked of him: they are of the lots' polish). | with (c) |

Not answered: call 7 (the floor bare earth all over), 8, 10, 11: they stand.

## His answer to the three calls of the pull's report (2026-11-20, an hour on)

The calls as they were put to him: "1. A pull's path through housing: the housing gives way (as built),
or refused? And should the Path tool do the same? 2. A stockpile's box still leaves a tree standing and
loses the places under it. Fell its trees too? 3. A hovel's terrace walls stay as they are; step them
the same way when the lots are polished?" His answer, whole:

> 1. a paths pull through housing should give way as built, if the path can pass and not interfere with anything built. 2. fell the tree in the stockpile. 3. yeah we can do that when the lots are polished

| | His words | Read as | When |
|---|---|---|---|
| 1 | "a paths pull through housing should give way as built, if the path can pass and not interfere with anything built" | The housing gives way under a path pulled through it, as it is built for the housing pull: where the path can pass and is in the way of nothing built (never a hovel's lot, begun or standing). **And the path tool the same** ("a path's pull"; the second half of the call): a path alone through housing no longer refuses; through any other zone it still does. The reading of the second half is put to him. | its own commit and switch |
| 2 | "fell the tree in the stockpile" | A tree that stands in a stockpile is felled and taken out, and the places under it are the stockpile's (with (b) of his answer before: "felled and removed anywhere else"). | its own commit and switch |
| 3 | "yeah we can do that when the lots are polished" | A hovel's terrace walls are stepped back a block a metre, as the square's are, **in the lots' polish**, not now: written into the brief. | the lots' polish |

## Built: a square's trees felled and taken out (his answer, clause b)

His words: "a tree left on a square, can stay in habitation zone, if it doesn't interfere with anything,
or felled and removed anywhere else."

**What it does now.** A tree anywhere on the square, on its floor or on the path round it, neither
refuses it nor is left: its foot is the square's ground like the rest (`Plan_Lot`'s `Clear_All`, no
`Keep_Feet`). The band fells every such tree before the ground is made under it (`Go_Fell_Square`, first
in the camp's building in `Think_Build`: anyone does, as a builder fells a stockyard's own); what is left
of it, stump and roots, is earth from then on (`Stump_Out`, in `Fell`); nothing is dug or filled under a
foot that still stands (`Foot_On`), and the camp is not built while one stands (`Square_Trees_Standing`
in `Check_Built`). Its logs lie where it fell, away from the fire, and are settled on the floor and the
path as those are made (`Settle_Piles`); the cook and the foresters carry them. Built on the spot
(`Build_Camp_Now`, the band's labour off) the trees are felled on the spot. The trees are known from the
founding (`Index_Trees` for the square's stacks in `Place_Square`).

**Where it goes past his words, or reads them.**

1. **A tree on the path round the square is felled too** (the 12 m, not only the 10).
2. **A boulder is as it was**: within 4 m of the middle it refuses the square, further out it is left
   and the floor made round it. He spoke of trees.
3. **A square founded round its trees keeps them** (one founded by the builds of this morning, or with
   `--no-square-fell`): its tree's foot is not its ground, and felled it would leave a hole in a floor
   filled up round it, so the foresters spare it still (`Tree_Spared`). Proved: such a square saved and
   run on twelve days with foresters at work, the tree standing, no pit (`tools/square_sites.sh`, 4).
4. **The band arrives on the ground.** Among trees, some of the band arrived on a tree's top (the
   highest floor where they were to stand) and stood there 5 m up for the first seconds: found by
   `--feet-stats` at a wooded square. They arrive on the floor nearest the square's own height now, a
   little further out if there is none there (`Place_Stake`, only for a founding with no post: the old
   founding is as it was, for the reference logs).
5. `Castle.Colony.Set_Square_Fell` (`--no-square-fell`; not saved): off, a tree is left standing as it
   first was.

**Measured.**

- **Where a square can be founded** (`--square-census 48 4`, 441 places, squarely and aslant): round
  the reference stake 261 and 273 (164 and 175 with trees left); on the open land 244 and 244 (230 and
  229). Refused for a boulder by the fire: 47 and 43; for a tree: none.
- **Squares founded and made at real places** (`tools/square_sites.sh`): **524** (286 with trees
  left), **1,553 trees felled for 293 of them** (eleven on one at the most), none with a pit by it, no
  fire out of reach, no camp left unbuilt, every pile of logs on the ground. Fourteen awkward sites
  twelve days each, two of them in the wood with ten trees on each: all healthy, no tree left to fell.
- **What the felling costs the first day** (the band of thirteen, a stockpile beside it;
  `$S/fire.sh`): at the two places both rules take, the hearth stands in hour 13 where it stood in
  hour 11 (1,190 blocks to dig and 1,149 to fill there) and in hour 3 either way; the first log is
  burnt in the same hour or one later. In the wood, ten trees on the square: the hearth stands after
  hour 6, the first log burnt in hour 7 or 8 (with trees left those places were refused).
- **By the tool's click in the game**, in the wood, release and debug: founded, the trees felled,
  their logs on the floor; saved; run on in both runners: the same state, no pit.
- **Saved after 30, 60 and 90 colony seconds and run on: the straight run's state** (a wooded square;
  all ten trees were down by the first of those).
- `colony_check` 910: a pine 1.2 m from where the fire is to be (founded all the same; felled after 28
  colony seconds; nothing of it left; its place floor; its logs on the floor; the hearth after 174, not
  before the tree was down); the two checks of trees left standing, under the switch.

## Built: a tree in a stockpile felled (his second answer, 2)

His words: "fell the tree in the stockpile." A tree that stands in a stockpile put down whole is the
stockpile's to clear: its foot is the stockpile's ground (`Plan_Lot`'s `Fell_Trees`: the ground under a
foot, never under a bough alone), a place lies over it (a hundred places where there were ninety-nine),
**closed while the tree stands** (nothing is put there); whoever has a place at an extra task fells it
(`Go_Fell_Box`, in `Think_Build` before the paths: as its path is laid), its stump and roots are earth
(`Stump_Out`), and its place is opened (`Box_Tree_Felled`; not if the stores have moved to the
storehouse, which closed them all). A bush or a boulder in it leaves places out, as ever.
`Castle.Colony.Set_Box_Fell` (`--no-box-fell`; not saved): off, a tree leaves places out too. A
stockpile put down before keeps its trees (their feet are not its ground). The corner-to-corner
stockpile of scripts (`--stockpile`) is as it was.

Measured: at 1150 1062, four stockpiles against the square: 85 and 96 places with one and three closed
at the start, five trees to fell; four days on 86 and 99 open, none closed, no tree left (with the
switch off: 84 and 90). Two checks (put down over a tree: a hundred places, one closed, the tree down
after some seconds, nothing of it left, the place open; with the switch off: ninety-nine, the tree
standing).

### Found after gate 71, and mended (told to him first in the report that follows)

I had told him "the place under it is kept closed until spare hands fell the tree, then opened".
That was so only while something else kept the band at its building:

1. **A stockpile put down along a path that is already laid kept its tree.** `Think` calls
   `Think_Build` only on a list of reasons (the camp or its seats to build, a path to lay, earth in
   hand, the lord's cart to pull); a tree in a stockpile was not one. Every run and check of mine had
   a path to lay or a camp to build at the time. Made the player's way: a band with jobs three days
   in (camp built, four seats, the cart in a stockpile, no path to lay), a stockpile put down by the
   tool's click east of the square over a standing tree, run on six days: **the tree stood at the
   end**; with the mend it is down (`$S/shots/pj_boxE.sav`). In the check, with the mend out: not
   felled in fifty minutes; with it: after eighteen seconds.
2. **The stump of a tree felled before the stockpile was put down kept the place over it closed
   for good.** Three days in, the trees nearest the fire are stumps (a forester's felling leaves
   the stump and the roots); the same click west and south of the square gave 85 places with one
   closed and 96 with three closed, still so six days on. Now a stump is taken out as a tree is
   (`Box_Stump`, `Go_Fell_Box`, `Step_Wood`'s `Chopping`: `Stump_Out`, `Box_Tree_Felled`), in the
   time the tree took to fell, and no log comes of it: 86 and 99 places, none closed.

Also: the count of them asks only the trees within the stockpiles' own columns (twelve days in the
wood with four stockpiles: 6.5 s against 6.4 before the gate asked it at every thought);
`colony_run --box-stats` says "N trees or stumps still to take out of stockpiles", always;
`tools/square_sites.sh` has a fifth part (four stockpiles with trees in them saved after 90 colony
seconds, two trees standing, and run on: the straight run's state 76d134cb35a704c2). Three checks
(the laid path; the stump; `colony_check` 916).

## Built: the path tool's path through housing (his second answer, 1)

His words: "a paths pull through housing should give way as built, if the path can pass and not
interfere with anything built." Read as the answer to both halves of the call: the housing pull's path
stays as built, **and the path tool's own path goes through housing the same way**
(`Castle.Colony.Lay_Path_Through`, which the `Lay_Path` order calls): the housing gives way under it
(`Housing_Gives_Way`: the block columns within the path's width are no zone's any more, the lots still
to begin laid out anew); through a hovel's lot, begun or standing, it is refused ("a hovel's lot is in
the way: a path goes through housing only where nothing is built"); through a stockpile, the camp, the
stockyard or the lord's cart, as it always was. `Set_Path_Through` (`--no-path-through`; not saved).
`Lay_Path` itself is untouched (what the colony's own routines lay). Two checks.

## Built: the square's walls and stair (his answer, clauses c and d)

His words: "stone wall and stair, also step the stone walls towards the higher ground if over 1m. so
from lower ground for each 1m of retaining wall step inwards .25". Told to him beforehand as what
would be built on no word (the report of 17:50): the walls on the square's own outermost quarter
metre, the step taken out of the floor; a stair at the middle of each side whose bank there is more
than a step, none over 2 m; aslant, a set-back of one diagonal row (18 cm); built after the hearth
and the path, so that the first fire comes no later.

**Where the build goes beyond his words** (each said to him first in its report):

- **The square's path is laid otherwise while the walls are on**: a slice of it, the block columns
  across its width at one quarter metre along, is brought to the floor's level whole or not at all.
  Column by column, as it was, a bank three blocks high ran along the middle of the path for half
  the length of a side (1184 784: 25 block columns of wall and a way of 20 m round), where no wall of
  the square's could stand. With `--no-square-walls` the path is laid as it was.
- **A wall is planned only against a laid path**: against a stretch still to lay it waits; against a
  boulder in the path's line, or under a tree left standing (a square founded with
  `--no-square-fell`), none is built.
- **A stair needs a bank of three blocks over all its width** (a metre squarely, 1.6 m aslant) and
  all one way; a bank of half a metre is walled and stepped over like any other half metre of the
  land.
- **Stone left over with no room in the stores is left lying** (gone), as earth is thrown aside.

**The design** (the spec, "The square's walls and stair"; `docs/systems/colony.md`): nothing is
kept. `Plan_Walls` gives each floor column the row its top is brought to and its lowest row of stone,
from the floor's level, how many rings in from the edge it lies, and the top of the laid path at the
end of its strip (`Wall_Column`, `Stair_Top`); a column standing more than a block over what is
beside it is stone from there up, a lift from its own lowest row, a stair's step its tread.
`Column_Work` reads what is left of a column from its blocks (earth over its top to dig off, then
stone from its lowest stone row or from just over its ground, whichever is lower: so what was dug
level at the founding is built up again in stone). The count and the laying use those two alone.
`Wall_Ready` orders the work: from the bank outward, from the path inward. The labour is an extra
task after the paths (`For_Wall`); the count is on a fixed tick, at once when the ground by the
square has moved, once a minute when nothing is left.

**Measured** (seed 1, generator 14):

- **Ten places, 524 squares, their walls built on the spot** (`tools/square_sites.sh`; `$S/scanw.sh`):
  95 walled (18 in a hundred), 30 with a wall set back, 38 with a stair (58 stairs); the highest
  bank 7 blocks (1.75 m); **no pit, no fire out of reach, nothing left to lay.** A wall set back
  twice and a side too high for a stair are met nowhere (they are arithmetic alone).
- **The way between the middle of each side's path and the fire, there and back**: of 2,063 sides
  76 are shorter (by 8.9 m on average), one longer (by 0.6 m), the rest the same; the longest was
  30.1 m and is 14.7 m.
- **Stone**: 15,392 blocks for the 95 (ten stones each on average: a stone is sixteen blocks, a load
  four stones); the most for one, 660 blocks (41 stones, eleven loads), with 130 blocks of earth to
  dig off for ledges and steps.
- **The band of thirteen, twelve days, at the eight heaviest** (`$S/walls.sh`), with the walls and
  without (the figures of the build as it stands after the two reviews, below): **the hearth** in
  the same hour at seven and an hour sooner at one; **the first log burnt** in the same hour at
  four, an hour sooner at three and an hour later at one (the walls themselves wait for the fire to
  be lit; what differs before it is the path, laid a slice at a time, and where those by a bank are
  settled, and the hours move both ways); hungry serf-hours 2,551 without and 2,502 with (six of
  the eight less, 190 for 194 to 517 for 556; more at two, 243 for 231 and 291 for 262); the lowest
  confidence 10 to 58 in a hundred with, 10 to 59 without; the walls begun when the fire is lit
  (8.4 to 26.9 game hours in) and done one to eleven game hours later (through the night at
  three); thirteen sleeping places by the fire given up to a wall or a stair over the eight (four
  at the most at one, of thirteen: each chooses another within the hour).
- **Fourteen awkward sites, twelve days**: six have banks; all walled by the band, nothing left, no
  pit; hungry serf-hours 1,369 with, 1,299 without (one of the six makes the difference, 331 for
  259: its first two days, 147 for 93); **the eight without banks end in the very same state with
  the walls on or off** (the hashes compared). Over the fourteen walled squares of the two lists:
  3,871 with, 3,850 without.
- **Housing pulled from the square, fifty days** (`$S/pull.sh`): on the bank by the reference stake
  1,039 hungry serf-hours and a lowest confidence of 52 in a hundred with the walls, 1,031 and 59
  without, eleven hovels either way, nobody starving; on the open land the same state with or
  without (984, 56, seven hovels).
- **Thirty days on a walled square**: 13.8 s with the walls against 13.9 without (counted every
  second for good it was 18.3: hence only when the ground has moved, and once a minute); with
  walls that wait for stone the whole thirty days (no porter, none to be prised in reach): 11.7 s
  against 11.9.
- **Where the band stands** (`colony_run --feet-stats`, against the blocks of each one's own
  column): more than a metre over the ground under them, moving or not, 225 serf-seconds with the
  walls and 301 without, of 1.8 million (at a bank over a metre the walking map's cell of four
  columns is the bank's top: that was there); standing still more than half a metre over it, 1,745
  against 793: idle hands resting on a ledge or a wall's top. The drawn figure finds its own ground
  and stands on it.
- **Saves**: a square saved after nine game hours, 291 blocks of its walls' stone still to lay, and
  run on to three days: the straight run's state (c49eb1f6773c79b3); with `--no-square-walls` that
  site ends in gate 72's state (f42bd0412bb19cf5), and a flat square (1150 1062) in the same state
  with the walls on or off (76d134cb35a704c2). Founded by the tool's click in the game, release and
  debug, a stockpile put down by the click, saved in the runner with 595 and 611 blocks still to
  lay and run on: the straight run's state in both (that was the build before the walls waited for
  the fire: such a band, given no jobs, lights none, and on the final tree its walls are wanted
  from the third day, 48.0 game hours in, and done by 50.0; saved on five half minutes round that
  and while they are half laid, release and debug, each runs on to the straight run's state).
  **Two squares saved by the build he had**
  (5cd89a8, three days in, their paths laid column by column) and run on five days: the walls
  wanted at once (656 and 632 blocks), done within three game hours, no pit, nobody starving.

**Checks** (`colony_check`, "the square's walls and stair": fifteen; 931 in all, the one of the
fire now holding the third day too): on the meadow
rising a block a metre, squarely with its middle on an odd and an even block: the plan and the
blocks column by column, the two lifts each side, the stairs four columns wide from an even one,
the ways before and after; aslant on ground rising along the diagonal; built by the band squarely
and aslant, with a way to the fire planned for each of the six at every second, nobody in a wall,
no pit at any twentieth second, saved half laid to the same bytes; a boulder in the path's line
and one on the floor's edge; nothing wanted before the fire is lit; no stone in reach; one held
still where a wall is to go, who steps aside (the band's own builds never have anyone standing
there: with the guard out of `Wall_Bout` they pass, and this one fails); the switch off.

**After the review of b9824f8** (gate 73 had passed on it: colony 929, every stress state equal to
gate 70's), mended in the commit after it:

1. **Whoever stood at a wall's foot was, to the colony, on top of the wall.** `Wall_Bout` settled
   those by it on the walking map's floor, which in the half metre at a wall's foot is the wall's
   top: the layer itself stood a metre "in the air" between bouts and set out from the top. On a
   walled square, where the ground of one's own block column lies more than a step off the cell's
   floor, one is settled on that ground (`Own_Ground`, in `Settle_On_Floor` and `Settle_Piles`);
   within a step nothing is changed, so a square without banks is the same run.
2. **A sleeper with no level place left lost its bed every hour.** At one walled square (886 1298,
   aslant: a stair and two lifts on two sides) the thirteenth found no place, took the old ring's,
   which lies by the path, was told each hour that it was no place, and made its bed again: 188
   times in twelve days, 424 hungry serf-hours against 262. A place of the old ring is kept on a
   square (`Bed_Kept`): 291.
3. **The walls wait for the fire** (a log burnt, or the fire burning): begun as the hearth stood,
   they took the hands that bring the first log.
4. **The count** runs when the ground by the square has moved and once a minute, not every second
   while any is left (a wall that waits for stone would have cost half as much again for good).
5. `tools/square_sites.sh` judged a pile of logs by its cell's floor: at a wall's foot that is the
   wall's top; `--square-scan` takes the ground of the pile's own block column too.
6. Said wrongly in the commit before: "the hearth and the first log in the same hour with the walls
   and without" (the script took line numbers for hours: as above).

**After a second review, of cce7130** (the gate begun on it was stopped), mended in the commit after:

7. **A run saved between the lighting of the fire and the next count of the walls ran on
   otherwise.** Nothing marked the walls to be counted when the fire was lit: the straight run
   learnt of them at the minute's turn, a loaded one at its first step. Found by saving six walled
   squares on each of eleven half minutes round that moment: 1178 1094 saved after 810 colony
   seconds parted from the straight run. `Feed_Fire` and `Stoke` mark them now; all sixty-six saves
   run on to the straight run's state, and three of the squares are in `tools/square_sites.sh`
   (its sixth part).
8. **A sleeper's place of the old ring is kept only while the walls are on** (it was kept on every
   square): `--no-square-walls` is the square as it was again, by its code and not by samples
   (f42bd0412bb19cf5 at the sloping site).
9. **With no fire lit at all** (a band nobody has given a forester or a cook: a square founded by
   the tool's click and left) the walls are wanted from the colony's third day. From the second,
   they began three hours before the fire of a square whose first log comes the next morning (1336
   936), and that log came an hour later.
10. Every figure quoted here was taken again on the final tree (`$S/final.sh`).

**Found on the way, not mended**: under a bough that hangs within two metres of it, a metre of
any path is not laid (the path's own reading takes the bough for the ground): 187 edge columns of
22 of the 524 squares have no path laid by them, and no wall there.

## Gates 71 to 74

**Gate 71**, from a clean copy of 5cd89a8 (the square's trees felled, the path tool through housing,
a stockpile's tree felled): both builds from nothing, the six known warnings; water_sim 77, edit 41,
ui 112, dynamics 18, serf 19, path 88, **colony 914**, deer 14, pick 78, all in debug and all passed;
the eight reference logs line for line; the stockyard sites and the turned streets in release and in
debug; the square's sites in release and in debug (524 squares, none with a pit; the fourteen
awkward sites; the half-built run's state f42bd0412bb19cf5; the square founded round its tree); the
stress runner, nothing died and nothing dropped (the crowd's states 3f7c2c6949cec18c as gate 70's;
its whole table was not kept); flora 5676219328934879273 in both builds. It was the baseline for
what was found next.

**Gate 72**, from a clean copy of 832f1ea (the two faults found after gate 71, mended): the same,
with **colony 916** and the square's sites' fifth part (four stockpiles with trees in them saved
while two stand, run on: the straight run's state 76d134cb35a704c2) in release and in debug; the
stress runner's **every state equal to gate 70's** (six_4_years bcd712a4fd9ea6d9, six_41_days
d580854cf5cac587, housing 6794042cea5a9e70, crowd_as_it_is 65a9d38031d4e79a, crowd at work
3f7c2c6949cec18c). `bin/` in the working copy was built from 832f1ea's tree at 17:48 (release and
debug, his game not running), and its `colony_check` run in debug: 916.

**Gate 73**, from a clean copy of b9824f8 (the square's walls and stair as first committed): the
same, with **colony 929**; every stress state equal to gate 70's. It stands as the baseline for the
two reviews' mends; a gate begun on cce7130 (the first review's) was stopped when the second review
found more.

**Gate 74**, from a clean copy of d53ba6f (the walls with both reviews' mends), both builds from
nothing, the six known warnings: water_sim 77, edit 41, ui 112, dynamics 18, serf 19, path 88,
**colony 931**, deer 14, pick 78, all in debug and all passed; the eight reference logs line for
line; the stockyard sites and the turned streets in release and in debug; **the square's sites in
release and in debug, all six parts** (524 squares with their walls and stairs, none with a pit, 95
walled, 30 with a wall set back, 58 stairs, nothing left to lay; the fourteen awkward sites, six
walled by the band; the half-built run's state c49eb1f6773c79b3 with a save taken while 291 blocks
of the walls' stone were still to lay; the square founded round its tree; the stockpiles with
trees, 76d134cb35a704c2; three walled squares saved on each of eleven half minutes round the
lighting of their fire); the stress runner, nothing died and nothing dropped, **every state equal to
gate 70's** (six_4_years bcd712a4fd9ea6d9, six_41_days d580854cf5cac587, housing 6794042cea5a9e70,
crowd_as_it_is 65a9d38031d4e79a, crowd at work 3f7c2c6949cec18c: none of those runs has a square);
flora 5676219328934879273 in both builds. `bin/` in the working copy was built from d53ba6f's tree
at 21:24 (release and debug, his game not running).

## His calls (each stands as built on no word)

His four answers of the same hour are above ("His answers to those"). Open since:

5. (Answered for trees: felled and taken out, above.) **A boulder on the square more than 4 m from its
   middle is left standing, one nearer refuses it; bushes on its floor are cleared.**
6. (Answered: "stone wall and stair, also step the stone walls towards the higher ground if over 1m.
   so from lower ground for each 1m of retaining wall step inwards .25". Built, above.)
7. **All of its floor is bare earth.**
8. First values of mine: 1.5 m of fall from its middle's level (`Square_Fall_M`), 4 m clear round the
   fire (`Square_Core_M`), a box drawn along a path from within 5.5 m of its line and to an end or a
   middle from within 2 m (`Box_Snap_M`).
9. (Answered: a tree on the square is felled and taken out. A square founded round its trees before
   this keeps them, spared.)
10. (Answered: "should give way as built, if the path can pass and not interfere with anything
    built". The path tool's own path has the same leave now: my reading of "a paths pull", put to him.)
11. **Begun within 12 m of a path and pulled the way it runs, a pull is housing along that path**, not
    a street of its own beside it (his reach of 2026-11-12, kept).
12. **The square's walls stand on its own outermost quarter metre**, and a wall set back takes its
    step out of the floor (a block column narrower a metre of wall on that side); the path keeps
    its metre. The other way: the wall's foot in the path.
13. **The square's path steps with the ground along a walled side** (a slice of it level with the
    floor only where all its width is within half a metre); before, its inner columns were cut to
    the floor's level and the bank ran along the path.
14. **A stair at the middle of each side whose bank is 75 cm to 2 m across all its width**; 57 of the
    95 walled squares have none (their banks are lower than that at the middle, or only by a
    corner); a bank over 2 m would have none (none is met).
15. **Aslant**: a set-back of one diagonal row of blocks (18 cm for his 25; two rows are 35); a stair
    1.6 m wide, its steps 35 cm deep.
16. **The walls come after the fire and after the paths the player has planned**; a load of stone
    for them is carried through the night; stone left over with no room in the stores is left
    lying.
17. **First values**: a stone sixteen blocks of wall (the hovels' figure), four seconds a stone.

Held by his word, as before: the logistics network's later passes; the earlier open calls; trees
growing back.

## Next (in his order)

**Where it stands at the end of 2026-11-20** (branch `stockpile`: its code is d53ba6f's, on which
gate 74 passed, the commits after it are this document and the stage log alone; `bin/` built from
it at 21:24; the zip in `~/CASTLE_GAME/releases/` remade from the head; `main` is 537176c and
nothing is merged: no merge word was given). His last
words were his two answers above; everything they asked is built and told to him, the calls of
each stand listed. **Awaiting his word**: the calls 5, 7, 8 and 11 to 17 above (each stands as
built); whether "a paths pull" covered the Path tool; and the colony that builds hovels, saved in
its first day and run on, not ending as the straight run does (found, older than this round, not
mended).

1. (Built, above: housing pulled with its path.)
2. The stockyard put down as a box, 16 m square.
3. The zone's own grid (`docs/production/briefs/Stage_6_brief.md`, "The zone's own grid, sized"): a
   scratch proof first, shown to him.
4. The lots' polish (with it, by his answers: a tree in a lot's way felled, a hovel's terrace walls
   set back a block a metre as the square's are).

Owed from earlier rounds, still: the faint line in the far view where a turned house stands.

## Test windows and input

Stills in short windows of mine from a scratch build, each only when `pgrep` found his game not
running; every one scripted (the camera by options, the pointer by `--pointer`). The Z, X and Esc keys
were not pressed by anything. Nothing pushed.
