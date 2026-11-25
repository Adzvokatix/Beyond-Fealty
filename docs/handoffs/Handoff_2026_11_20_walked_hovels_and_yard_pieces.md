# Castle Game handoff (2026-11-20: turned hovels walked where they are drawn; a stockyard's roofs smoothed and its fence drawn along the path)

The round before it is `Handoff_2026_11_20_stockyard_along_a_path.md`. Everything is on branch
`stockpile`, not merged; `main` is 537176c. No merge word was given.

## Next session: start here (his answers to this round's calls, 2026-11-20; nothing of them built)

His words, whole:

> 1. lets make the hovel walls solid, 2. turn the fence posts. 3. connect the rounded edges together along the length, and texture the roof of the outdoor storage the same as all the other roofs, that is the defult for all thatch roofs 4. see 3 5. if turning and building at an angle is going to cause a lot of issues tell me, they either act like the straight builds or we need to change the way we tackle this situation so it works.
>
> Continue with the rest of the operations please. Doing great, we just need to work through all the details.

My reply to that was cut off by the service's safeguard before anything of it ran (the working tree showed
no change from it). Then: "can you wrap up what we have now and prepare for a session clear so I can fix
the interruptions". So the session was closed here, and this is what is owed, call by call:

1. **Call 1, hovel walls: "make the hovel walls solid".** A turned hovel's walls as drawn shut the feet,
   as the storehouse's do (not slowed). What stopped it: on hillsides the ground made round a hovel as
   drawn left pockets a serf could drop into and not climb out of (5 to 84 spots in `colony_check`'s
   streets by how thick the wall was taken; `Handoff` above, "Where what was built departs"). So the
   ground made round it has to leave none (or the pockets be found and shut each time a hovel stands);
   the measure is `colony_check`'s hillside streets, the steep one too, at 0 pits, and
   `tools/turned_streets.sh`.
2. **Call 2, the fence: "turn the fence posts".** The posts drawn on the fence's line as pieces too,
   their blocks laid as pieces (hidden), as the rails' are: the whole fence along the path.
3. **Call 3, the roof: "connect the rounded edges together along the length, and texture the roof of
   the outdoor storage the same as all the other roofs, that is the defult for all thatch roofs".** The
   rounded edge drawn as one piece along each edge of a covering's roof (it is a metre-long roll at a
   time now), and the roof textured as every other thatch roof is (the dressed roofs' look in the land's
   shader): one thatch texture, the default for all thatch roofs. **His rule from now on: every thatch
   roof looks the same.** The dressed roofs are the measure ("the roofs top is perfect", 2026-11-19: a
   pixel measure): the covering is brought to their look, never their look changed. The covering is a
   prop, lit as props are, so match it in a still beside a dressed roof.
4. **Call 4, square stockyards' coverings smoothed too: "see 3"** (all thatch roofs alike: they stay
   smoothed, and take the same texture).
5. **Call 5, a question and a ruling: whether building at an angle causes a lot of issues; "they either
   act like the straight builds or we need to change the way we tackle this situation so it works".**
   The ruling: what I put to him as call 5 (a pointer at a rail or a smoothed roof meets the hidden
   block behind it, a dug rail block leaves its drawn rail) is not accepted. Whichever way is taken,
   pointing at a rail picks the rail and digging it removes it, as on a straight build. The question
   is answered below ("Building at an angle: where it stands") with two ways put to him.

**The default if he says no more than "continue"** (his standing word: no stops): the rework (way 1
below) is done only on his word. Without it, go on the present way: first run the gate from a clean copy
of HEAD (gate 66 ran on 5427629; since 1964f96 only `edit_check` and `path_check` have run), then item 3
(nothing he chooses can change it), then 1 and 2, then the pointer and the dig of 5, then the three owed
below.

Then the rest owed (not held): a stair to a turned hovel's door cut from its walls as they stand; a
turned hovel's builder's jump at its ring; a faint line in the far view where a turned house stands.

**The `/doctor` trim of `CLAUDE.md`** (19 of the 39 opening lines of "Conventions from past sessions"
condensed: 18,141 characters; every gotcha kept) was left uncommitted here for his review and **is
committed since (54e7fdd)**.

**What came next** (the session after the clear): gate 67 on 54e7fdd passed with every state equal to gate
66's, and his answer to "Building at an angle" below changed what is built of the list above (items 1 and
2 are not built the present way): `Handoff_2026_11_20_placements_with_paths_and_the_square.md`.

### Building at an angle: where it stands (my answer to call 5)

It works, but every system that touches a building has needed its own turned case, and each new one will.
A turned building is two things in two places: its blocks stand square on the grid (what the feet, a ray,
a dig, water, shadows and the far view read) and it is drawn turned. Each system has had to be told:

- walking: the hidden square made walkable, the drawn walls and doorways told the walking map by hand
  (`Castle.Nav.Set_Drawn`), and on hillsides the ground made for it left pockets (call 1);
- pointing: a ray taken back through the turn (`Castle.Pick`), the hidden ground kept off the cursor;
- drawing: people, beds, cloaks, doors and the cleared roof put through the turn by hand; the far view
  through the turn (and a faint line still owed);
- the ground: made under the house as drawn, the stair still cut from its walls as they stand (owed);
- the stockyard: its yard designed in one frame and built in another (`D_U`, `Y_Point`), its rails and
  roofs drawn as pieces over blocks the land leaves out, so a dig or a pointer meets a block that is not
  drawn, and the builder drawn eased through the turn.

Two ways on, put to him (my recommendation first):

1. **Make a turned building one thing every system reads the same way**: its blocks kept in its own
   turned grid, and walking, pointing, digging, the cutaway and drawing all looking a place up through
   its turn by one shared routine, so a turned build acts like a straight one by construction and a new
   system needs nothing of its own. A larger rework (several rounds; to be sized first by listing every
   turned case in the code: `Turn`, `Yard_Turned`, `Walked_Drawn`, `Turned_In`, `Through_Turn`, `Piece`),
   best done before more kinds of building go up at 45 degrees.
2. **Keep the way it is and work through each case** as found: cheaper now, a cost every time a system or
   a kind of building is added.

## John's words

> Let's do that, and what do you think about turning the fence too? The outdoor roof covering needs a smoothing pass.

Then, after two replies of mine were cut off by the service's safeguard and the session's model was
changed: "Lets try again, I don't know what hit the safeguard, and I know you can't tell me. How did
this affect the process though. Did you figure out how to turn the fence, and smooth the roof of the
outdoor storage at the stockpile?", "ok can we not work on the project anymore?", and "Opus you are
up, can you continue the project?".

Read so:

1. "Let's do that" answers the offer that ended the last round: "The same approach would remove the
   turned hovel's hidden square (grass to the eye, a wall to the feet)." Built.
2. "What do you think about turning the fence too?" is a question. My answer, with stills: yes, and
   it is built behind a switch (below). The fence's posts stay columns of blocks; its rails and the
   planks over its gateways are drawn straight along the path.
3. "The outdoor roof covering needs a smoothing pass" is his own term of 2026-11-12 for roofs ("the
   roofs, are to be smoothed, but not rendered smooth instantly, the builders smooth the roofs so
   they don't step, rounded edges around the peremeter"). Built: the builder smooths each covering's
   roof after it is laid, a row at a time; a smoothed roof is one plane with its edges rounded.

What the cut-off replies cost: nothing built was lost. The first was cut in the middle of the
hovels' work, before anything was committed; the working copy kept every change, and the work went
on from it. The fence and the roof had not been begun then.

## Where what was built departs from what he asked

1. **A turned hovel's walls as drawn slow the feet; they do not shut.** The storehouse's drawn walls
   are walls (no floor). Shut so, a hovel on a hillside made pits: the ground made round it as drawn
   was laid out when its walls were no walls, and with them walls, pockets of it were left at its
   floor's level that a serf could drop into from the higher ground and not climb out of.
   `colony_check`'s hillside streets found 5 such spots with the thinnest wall that holds, 59 and 84
   with thicker ones. Slowed, none. A step onto or off a hovel's wall as drawn is reckoned at a
   hundredth of the pace (`Castle.Nav.Wall_Pace`: a metre of wall costs a way as much as 100 m of
   turf; round the longest hovel is some 20 m), so a way round is always taken. In three turned streets
   over eleven days nobody was in a wall as drawn for even a second, and every bed is got to by its
   door. Somebody could still walk through one if there were no other way at all; the project's rule
   for that ground ("it slows, it never shuts") is why. His call 1.
2. **The fence is turned by its rails, not by its posts.** Each post stays a column of blocks where it
   is laid, stepped along the line a block at a time as before; the rails between them and the planks
   over the gateways are drawn straight from post to post (and from a gateway's post to the
   storehouse's corner as it is drawn). The rails' own blocks stay where they are laid and are what
   the feet meet, up to 0.2 m off the drawn rail. A square stockyard's fence is as it was. His call 2.
3. **A smoothed roof is drawn as a piece, not dressed blocks.** A hovel's dressed roof falls a block
   for each block across, or half a block; a covering's falls two blocks in eight, and at 45 degrees
   a dressed block can fall no way at all. So the covering's blocks stay where they are laid (the
   feet, a ray and a save meet them as ever), are left out of what the land draws once smoothed, and
   the roof is drawn as one plane from its front edge to its back with a rounded edge along all four
   sides (none where two coverings meet: the two are one roof). It is lit as the props are (the barrels,
   the cart), not as the land is. His call 3.
4. **Every stockyard's coverings are smoothed, square ones too.** His sentence did not say which.
5. **A pointer at a rail or a smoothed roof meets the block behind it**, as a ray meets the hidden
   square of a turned house. Within 0.2 m of what is drawn.

## Built (commits d03a519, 5427629 and 1964f96; colony blob 41)

### A hovel placed turned is walked where it is drawn (d03a519; blob 40)

- `Castle.Buildings.House.Walk`, fixed when a hovel is placed turned with its ground made where it
  is drawn (`Set_Hovel_Walk`, `--no-hovel-walk`; saved with it, +8 in its turn's byte). From when
  its walls and roof are up (`Walked_Drawn`, as the storehouse's) `Walk_Drawn` gives the walking map
  its walls as drawn, its doorway and the box its blocks stand in.
- **Its bed is in it as drawn** (`Bed_Place`, `House_Inward` for the way a sleeper faces), and so is
  whoever is in it: nobody in it is drawn through its turn any more (`People_Turned`: only its builder,
  while it goes up). The game draws its bed where the colony says (`Show_Beds`).
- **Nothing is kept off it** (`Keep_Off_Turned` leaves it out): its walls as drawn are walls.
- **The walking map** (`Castle.Nav`): a building's `Slow` walls (a hovel's) give the cells they
  touch floors at `Wall_Speed`, a step onto or off one reckoned at `Wall_Pace`, and a way straightened
  through one reckoned so too (`Line`: without it a way planned round a hovel was straightened through
  its wall: two serfs walked through walls in the first runs). A building's `Door` pieces hold the
  cells whose middles lie in them open: a hovel's doorway is a metre wide, and at 45 degrees a cell
  spans 0.71 m along the wall (`path_check`: of 50 places of the doorway on the cells, with walls that
  shut and no doorway held, 38 had no way in). Every building's walls are asked before any box (one's
  box made level could open another's wall). Only cells wholly in a hovel's box are made level (a cell
  half on the bank above a hovel on a hillside was a pit), at turf's pace. The list holds 64.
- The pointer: the ground within any house walked where it is drawn is not the cursor's at its pad's
  row either (`Castle.Pick`).
- `colony_run --turn-stats`: for each walked house, the serf-seconds within it, where its blocks
  stand and in a wall as drawn; the first three in a wall named, with their way's ends; whether the
  way from the stake to its bed is found and goes through a wall. `tools/turned_streets.sh` fails on
  anyone in a wall as drawn or a bed not got to by its door (`NO_WALK=1`: the way before).

### A stockyard's pieces (5427629; blob 41)

- **The coverings' roofs smoothed** (`Set_Smooth_Covers`, `--no-smooth-covers`; `House.Smooth_Covers`,
  said when a storehouse is begun): the blueprint's last stage (`Smooth`) is each covering's thatch
  again, a row at a time from its front, with the state `Castle.Blocks.Piece`: work alone, as a
  hovel's thatch is trimmed (nothing carried; the builder "smoothing the coverings' roofs by the
  storehouse"). 369 to 408 blocks more of a blueprint of some 9,000.
- **A turned yard's fence in pieces** (`Set_Fence_Pieces`, `--no-fence-pieces`; `House.Fence_Pieces`):
  its rails and gateway planks are laid with the state `Piece` as they go up.
- **What the land draws leaves a piece's blocks out** (`Castle.Blocks.Seen_Mat`, read by
  `Castle.Mesher` and `Castle.Lod`; a block's state, as a dressed roof's is). Nothing else reads it.
- **What is drawn instead** (`Castle.Colony.Yard_Pieces`, kept per house until it changes; the game's
  `Show_Yard_Pieces`): each stretch's two rails once the post that ends it stands, each gateway's plank
  once laid (`Castle.Props.Rail`), and each covering's roof as far back as it is smoothed
  (`Castle.Props.Thatch_Tile`, one piece the size of the roof; `Thatch_Roll` along its edges). Drawn
  as far as the props are: at 160 m they are there.
- A covering's smoothing undone (razing, should a storehouse ever be razed) lays its thatch back
  stepped before it comes off.
- The test world keeps a block's state (it dropped it).

## Measured and proved

- **The way before is kept exactly** (taken again with the final build, 1964f96, after review found
  the first taken before the last changes): with `--no-hovel-walk` the three turned streets are line
  for line the last commit's runs (4ebb0eb), timing and file names aside; with `--no-smooth-covers
  --no-fence-pieces` the turned stockyard's twelve days are too (460 lines). Four saves of earlier
  builds, each with the things this round changes in it, drawn with fixed cameras once everything has
  streamed in (`--hold-wait --far-wait --settle 300`): the flat turned street at night (blob 39), the
  turned stockyard standing with its cart, stockpile and hovels (blob 39), a square storehouse
  standing (blob 38): 0 pixels apart from the last commit's game. A turned street of blob 38: as far
  apart as the last commit's game is from itself (516 pixels by the camp's fire and cloths where it
  drew 446 against itself; its grass sometimes differs by thousands of scattered pixels from run to
  run, in either build). (`Seen_Mat` hides every log, plank or thatch block of state 1, so these saves
  are also the proof that nothing earlier left that state on such a block.)
- **Turned streets, walked** (eleven days each, `--turn-stats`): on the flat 5 hovels, on rising
  ground 4, up the steep hillside 1; nobody starved; in a wall as drawn 0 serf-seconds; within a hovel
  1,723 to 4,346 a hovel; on the square its blocks stand on 4 to 195 (turf, walked); every bed got to
  by its door; at midnight every owner at home. Run times as before (7 to 11 s).
- **Pits**: with the hovels' walls shut, 5 to 84 on `colony_check`'s hillsides by how thick the wall
  was taken; slowed, 0 (of 15,853 to 27,458 spots).
- **Stockyards**: the six of `tools/stockyard_sites.sh` stand with both pieces on; the turned one on
  the flat is first logged standing at the same twelve-hourly line as without (day 28, 0 h); its
  pieces: 36 rails, 2 planks, 4 roofs of 32 rows all smoothed. Its coverings are smoothed between day
  27, 12 h and 15 h (at 13 h: three roofs, 17 of their 24 rows).
- **The smoothing watched** (review asked for it: every still had been of a finished yard): a still
  at 13 h shows a covering smoothed from its front back, its stepped rows behind (sent:
  `stockyard_smoothing_midway.png`), and the game run live from 12 h at full speed to the night shows
  all four roofs smooth, nothing stepped left under them (a block's state written alone is meshed
  again in the game, as a dressed roof's is).
- **A stack's edge** (found on review): a post beside a rail laid as a piece across a stack's edge lost
  the face toward it (the rim of a neighbour's edits gave the mesher the rail's block); reproduced in
  a low still along the fence at x = 1168 with gate 66's build, gone in 1964f96 (`Castle.Edits`: the
  rim is of the blocks as drawn; `edit_check` 41, `path_check` 88 in debug; the rim is the mesher's
  alone).
- **What it costs**: close to a covering (14 m off), the frame settled at 0.59 and 0.60 ms of the card
  with the pieces against 0.58 and 0.59 without (the same site, its pieces off): no cost to be told
  from the run-to-run spread.
- The fence and the smoothing are one commit (5427629) with two switches.
- **Gate 66** (a clean copy of 5427629, both builds from nothing, six known warnings): water_sim 77,
  edit 41, ui 112, dynamics 18, serf 19, path 88, colony 845, deer 14, pick 78, all in debug and all
  passed; the eight reference logs line for line; the six stockyard sites and the three turned streets
  passed in release and in debug (the walking map mended against read whole); the stress runner:
  nothing died, nothing dropped, each run's states equal to its fellows' (six_4_years 7b5b27750ebfb6c6,
  six_41_days b249754bb0c8acfc, housing b1a987c8659fc4ff, crowd_as_it_is 27139037a77be695, crowd at work
  b0d6fe84b2d1863f: every hash moved from gate 65's, as a blob that carries three bytes more must);
  flora hash 5676219328934879273, debug and release.
- `pick_check` has no walked hovel: its rule for a walked house's ground (the cursor's not, at the pad's
  row) is the storehouse's, now asked of any house walked where it is drawn.

## Stills (sent)

The zip of the round is `~/CASTLE_GAME/releases/castle_game_walked_hovels_and_yard_pieces.zip`.

- `~/CASTLE_GAME/releases/stockyard_pieces_turned.png`: the stockyard along the path, before (left)
  and after (right), from above and close to a covering.
- `~/CASTLE_GAME/releases/stockyard_pieces_square.png`: a square stockyard's covering before and
  after its smoothing.
- `~/CASTLE_GAME/releases/stockyard_smoothing_midway.png`: the turned stockyard's coverings while
  its builder smooths them (day 27, 13 h).

## His calls (each with what it does now)

1. **A turned hovel's walls slow, they do not shut**: a way round is always taken, nobody can be shut
   in, and somebody could walk through one only if there were no other way at all. The other way is
   walls that shut and a pass that finds the pockets on hillsides and fills or shuts them each time
   a hovel stands; not built.
2. **The fence turned by its rails**: posts where they are laid, stepped; rails and gateway planks
   straight. The other way would draw the posts on the line too (their blocks hidden).
3. **The smoothed roof**: one plane from the front edge to the back, its courses running along it, a
   rounded edge all round, lit as the props are. First values: the edge 30 cm round, the roof 20 cm
   thick.
4. **Every stockyard's coverings smoothed**, square ones too.
5. **What a pointer meets** at a rail or a smoothed roof is the block behind it; and a rail's block
   dug away leaves its drawn rail standing (what is drawn goes by the blueprint laid, not by the
   blocks).

## Owed, not held

- A stair to a turned hovel's door is cut straight out from the walls as they stand.
- A turned hovel's builder jumps at its ring (the storehouse's is eased).
- A faint line in the far view where a turned house stands (cause not found).

## Waiting on his word (not built)

The hunters (more deer further off, or herds ranging further); the gatherers' hunger at 250 m; the
3 m fall rule for stockyards; whether a lot refused along a path should be offered square. Held by
his word: the logistics network's later passes; the earlier open calls; trees growing back.
