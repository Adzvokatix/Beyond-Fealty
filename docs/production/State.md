# Where the project stands

One page. It is rewritten at the close of every session, not added to: what happened and why is in the
handoffs and the stage log; this says only where things are. If a line here and the newest handoff
disagree, the handoff is right and this page is to be mended.

**As of 2026-11-24, morning: the voxel people are merged into `main` on his word** ("great I like it, when
the shell is done, merge and get ready for a clear, next we are going to polish up the animations"): the
serfs shaped as the bought skeleton, their heads smaller, shorter and oval with a mass of hair and ears,
their faces and hair a voxel fine, thinner arms clipped into the chest, thumbs, the elbows out at rest,
the chin and the crown rounded, all on his word, and drawn as voxel parts. **Next, in his words: the
animations polished, his to open** (below). The working copy is on `main`; new work goes on a new branch
from it. (`docs/handoffs/Handoff_2026_11_23_voxel_people_drawn.md`: every round of the voxel people, his
words whole, to "His word to merge"; the count before it: `Handoff_2026_11_23_voxel_people_counted.md`.)

## The build

- **`main` holds the voxel people, merged on his word of 2026-11-24, morning** ("when the shell is done,
  merge": the gate then running, on 22551f9, passed): fast-forwarded from 091b720 to 027491d (branch
  `voxel-people`, 36 commits), and the commit after records it. To undo: `git checkout main &&
  git reset --hard 091b720`. His brief `docs/design/Voxel_people_brief.md`, step 1, then his messages of
  2026-11-23, night, and of 2026-11-24, each in the handoff with how it was read.
  - **The reference body** (`--no-reference-body`: the serfs as before them, to the bit): the bought
    skeleton's proportions (the hips' joints at 41.9 % to 45.9 % of the height, the hands to the middle
    of the thigh, no neck) with **the head smaller than its third**: 7 or 8 pixels tall (a pixel cut from
    the crown, the legs and the trunk longer for it, so that the serf is its genome's height), 21.6 % to
    25.8 % of the height; a button nose set into the face; more form's waist and limbs kept, the arms a
    voxel thinner and two voxels into the chest at the shoulder; thumbs; the elbows out at rest
    (`--no-rest-arms`).
  - **The head's shape** (`--no-head-shape`: the hair's mass, the ears and the beard off): the hair a
    mass that narrows over the crown and down the sides, so the head is an oval; ears where the sides are
    bare; a full beard round the jaw; the chin's and the crown's edges rounded a step more than the
    head's sides (`Box.Round_Ends`, voxel parts only). The face and the hair **painted a voxel fine** (on
    a skin sheet grown to 128 rows; a departure from the brief, which paints on the voxels). The winter
    hood rounder.
  - **Drawn as voxel parts** (`--no-voxel`: as boxes): in the view and in every shadow; a face's colour
    read where it is drawn, not carried by its quad (a departure from the brief: 1,762 triangles a serf
    for the brief's way's 7,429). The GPU a frame as before within a few hundredths of a millisecond
    (timed at 1,557 triangles a serf, before the smaller head and what followed: not timed again).
  - **Gated at 22551f9: passed** (and on the way at 409eb55, 85132c5, 85511a1 and 4383be6); the commits
    after it are documents. The colony is as it was to its state (the game as it is played,
    d5bb6e2fdd00202f).
- Before them, `main` took his notes of 2026-11-22 and of 2026-11-23, **merged on his word of 2026-11-23
  ("1. merge")**: it was fast-forwarded from da7c7b9 to fa3f1b3 (branch `playtest-notes-2`, which stood
  on `playtest-notes`: 25 commits), and the commit after records it. To undo: `git checkout main &&
  git reset --hard da7c7b9`.
  - Of 2026-11-22: the development entries of a person's menu, the eaters' arms, a deer one piece on
    steep ground, herds not put up trees, the sleeper's cloak, the serfs with more form.
  - Of 2026-11-23: the zones' lost ground mended; and eleven rules, ten behind a switch that gives the
    game as it was: a site's ground worked from beside it (`--no-reach-out`) and a storehouse's there
    and back (`--no-zigzag`); a path stepped where it meets trodden ground (`--no-paths-meet`) and a
    door's way made again to its path (`--no-door-meet`); a deer butchered by whoever carries it home
    (`--no-kill-home`); a stockpile's place made level when something is put on it
    (`--no-place-level`) and room round the cart (`--no-cart-room`); the truss to the ends of its
    wall, symmetrical (`--no-full-truss`); the player removes a stockpile (a row on its menu: no
    switch); builders with no house of their own help at a larger one (`--no-build-help`); and, found
    on the way, a walker at the height of the place it steps into (`--no-step-at-edge`).
- **`stockpile-flat` is merged into `main` on his word of 2026-11-23, afternoon** ("let's go back to
  the stepped version, not the cut one, let's block the players placement if it's too steep ...
  then merge"): fast-forwarded from 5261caa. To undo: `git checkout main && git reset --hard 5261caa`.
  - **The stockpile is stepped, as it was**: a stockpile made one level (built that morning on his
    "flatten the stockpile", a cut of four metres at the far corner of his own) is **off by
    default**; `--pile-flat` gives it, with its checks; nothing of it is taken out.
  - **A stockpile is refused on ground too steep** (`--no-steep-refuse`): some part of its ground
    rises more than half a metre over a metre along the block grid, or a ledge lies in it. 2 of 58
    tried are refused; his own is taken. By the other reading of "1/2 slope" (the land's true fall)
    10 of the 58 would be, his own among them: not built, his to say.
- The game in `bin/` is the gated build of 22551f9 (`main`'s code), put there on 2026-11-24 at 09:24
  (after 4383be6's at 08:30, 85511a1's at 06:37, 85132c5's at 04:56 and 409eb55's at 01:07, which had
  replaced 6c118a2's). With `--no-reference-body --no-voxel` it draws the serfs as before the voxel
  people (shown on 409eb55, and on 9718f8a with the skin sheet grown: a still of seven against 6c118a2's
  game, as near as two runs of that game are to each other).
- The colony's blob is version 46 (45: which houses have the fuller truss; 46: which stockpiles are
  ordered removed; 30 to 45 still read), the generator 16, the save format 6.
- The gate is `tools/gate.sh`; it holds the game as it is played to a kept log (`tools/today_check.sh`),
  which was recorded again with each rule of these rounds (its state is d5bb6e2fdd00202f; with
  `--pile-flat` the game ends at fb79e4cc482d0be5, kept nowhere), and since 2026-11-23 saves that game on its
  twentieth day, loads it and runs it on to the straight run's state (five commits of this round, none
  of them put in `bin/`, could not load a save of their own with a new hovel standing). In that log all
  thirteen live through the 41 days (the log of before had a builder starve in a pocket of ground at
  her lot: she stood on the square metre she dug; that run says so and no more).
- His design document is version 0.15 (`docs/design/detailed_mechanics.json`). A change to it is made only
  on his word, by exact strings (`docs/conventions/how_we_work.md`).

## What is next, in his words

> next we are going to polish up the animations (2026-11-24)

His to open: nothing of it is built, and nothing has been asked of him about it. What the voxel people
left that bears on it:

- **The hands go into the head at work** (`serf_check`, "hands at work", printed and not failed; counted
  on 22551f9): of 60 serfs at each work, all 60 at chopping (3.0 pixels deep) and aiming (2.9), all 60 at
  eating and sitting to eat (1.4); picking 3 (1.5), putting down 3 (0.5), stirring 3 (0.8). The body
  before the voxel people did it too (chopping 2.4, aiming 3.0, eating 1.1, picking 5): the poses were
  made for a head of six pixels.
- **Two calls of the voxel people bear on it** (`Handoff_2026_11_23_voxel_people_drawn.md`, "His calls";
  each stands as built on no word): keep the hands out of the head (the bow drawn to beside the face,
  the axe wound up beside it), default the poses as they were; a belly joint (the skeleton bends at its
  belly as well as its waist, ours at the waist only), default not added.
- **The arms at rest** (`Castle.Serfs.Rest_Arms`, `--no-rest-arms`; his list of 2026-11-24): the upper arm
  0.18 rad out, the forearm turned 0.30 back in, the elbow bent 0.17 more; gone as a serf walks (at
  0.6 m/s) and as it works. First values.
- **Not looked at on the new body**: a deer carried across the shoulders (placed by the shoulders'
  height); the serfs moving (shimmer was counted on a still pair of frames before the faces were made
  finer, not counted since, and never watched).
- His brief leaves animation out ("Not in this brief": "animation (unchanged: `Castle.Poses`)"); its
  steps 2 to 5 are not built (the face and the hair painted a voxel fine on the skin answered part of
  step 3's detail, not its way).
- Where it is: the poses are `Castle.Poses` (two-bone IK), set by `Castle.Serfs` (`docs/systems/people.md`);
  a serf's voxel parts are rigid, one a bone, made when its look is made: moving a serf moves its bones
  (`docs/conventions/rendering.md`, the entry of 2026-11-24). A still of a few serfs in the game:
  `~/CASTLE_GAME/releases/voxel_people_2026_11_24/tools/lineup.sh` (its header); `--lineup N
  --lineup-does JOB` puts N serfs in a row at a work.

The arrival was named before it and is not opened; which comes first after the animations is his to say:

> the next part is adding the horses for the cart and how the colony arrives, they will be pulling the
> cart to the spot with the horses, it won't be magically popping in with the people (2026-11-22)

His notes of 2026-11-22 and of 2026-11-23 came before it ("what we need to fix real quick before we get
to the next step"; "ok a couple of issues"), then the voxel people: all merged. Four calls on the arrival
were put to him on 2026-11-22 and are not answered. Each with what is built on a bare "go":

1. **One cart, or the design document's start?** His sentence says the horses for the cart; the document's
   game start has two carts, two horses, a priest and a load for each cart. Default: the one cart with its
   salt as now, two horses drawing it, the thirteen walking with it; the second cart, the priest, the loads
   and the messenger not built.
2. **Where they start walking from.** Default: a set distance from the spot, out of the default view, on a
   side the cart has a way in from; the distance a first figure, given with its count. The other way: from
   the edge of the map, the whole journey.
3. **Where no way takes a cart all the way** (steep ground, trees). Default: the horses draw it as near as a
   cart can get, it is set down there, and the band goes on to the spot on foot.
4. **The horses once the cart is set down.** Default: unhitched and standing by the cart, drawn only; they
   need nothing and do no work, and the cart's later moves stay as they are.

**The day they arrive is settled** (his word, 2026-11-22): the 6th day of summer, as the game's clock already
has it; his document was changed to it (0.15), and its thaw is day 40.

"The spot" is read as the place he staked. The colony left with no cart on a hillside is mended with this
part (his word); the three squares where it happened are where the arrival is tried: 1258 1058 and
890 1290 (both at 45 degrees), 950 1290 (square). **At 950 1290 all thirteen die of hunger within 41 days**
(counted 2026-11-23, with the rules of that day off as with them on). A fourth start with no cart: the
start of `tools/today_run.sh` with its housing pulled westward from 1231 1058 in the place of eastward.

## On hold, in his words

- **The logistics network's later passes**: "for the next couple of days we will be polishing, so hold off
  on the integration" (2026-11-19). Its first pass is built; `docs/production/briefs/Stage_6_brief.md`,
  "The logistics network", has the passes.
- **The lord's cart**: "leave the cart doing whatever it's doing right now, we are going to work on the
  logistics soon" (2026-11-22). Nothing of where it goes and stands is touched until then. (Of
  2026-11-23, on his "clipping issues where the cart or goods are placed on top of each other": nothing is
  put on the places beside its wheels or under its shafts. That is which places take goods, not the cart.)
- **The design document's mechanics**: brought into the project on 2026-11-22 (checked, mapped to the
  build); none of it built by that. `docs/design/Mechanics_crosswalk.md`.
- **What becomes of the only stockpile when it is removed**: "just leave the stockpile for the moment,
  we can get to that when we do the horses and carts" (2026-11-23). As built: with none put down in its
  place the band can store nothing and starves (thirteen dead by the twenty-eighth day of a run).
- **The lots' polish**: "We can polish how the lots are built after" (2026-11-20).
- **Trees growing back**: "Trees do not grow back yet, but they will, we can do that later" (2026-11-19).
- **The player's own figure and his advisor**: "we aren't doing the player and advisor thing just yet"
  (2026-11-17).

## His open calls

They are not gathered into one list. Each round's are in its handoff, under the heading named; a call
answered later is answered in a later handoff. The last time he asked for the whole list was 2026-11-13.
His word of 2026-11-19 stands: "The questions can rest for now": none is acted on or asked again unasked.

- **A stockpile one level** (`Handoff_2026_11_23_a_stockpile_is_one_level.md`, "His calls" and "His
  answer (2026-11-23, afternoon)"): answered. Merged, with the rule off; its three calls (the level,
  a boulder, the banks) fall away with it. **One of mine stands open**: which reading of "over 1/2
  slope" (above).
- **The voxel people** (merged 2026-11-24): the count's two answered on 2026-11-23, night (the
  skeleton's proportions; the mesh stands as built, looked up). Three new in
  `Handoff_2026_11_23_voxel_people_drawn.md`, "His calls": the hands at work going into the head (they
  did before the voxel people too) and a belly joint stand as built, and bear on the animations (above);
  a tall man's head answered on 2026-11-24 (the head a bit smaller); the head a pixel narrower (a
  picture) stands as built, six wide; the faces a voxel fine answered ("make the detail finer"). Open:
  the whole figure a voxel fine (clothes, hems, a buckle, fingers), default not now.
- **His notes of 2026-11-23** (`Handoff_2026_11_23_paths_builders_and_stockpiles.md`, "His calls" and
  "His answers"): all four answered on 2026-11-23. Merged; the stockpile flattened whole (built, the
  entry above); the removal of the only stockpile left as built "for the moment" ("On hold",
  above); the helping as built.
- **His notes of 2026-11-22** (`Handoff_2026_11_22_playtest_notes.md`, "His calls"), not answered by his
  messages of the 23rd but for the merge, which his "1. merge" took with the round after it: the serfs' new look (keep,
  change or off); the deer that step down onto mountain ledges and cannot step back up; the seven arrays
  this compiler may read wrongly. **The builder left in a pocket of ground** was put to him as a round of
  its own; it was not opened, and the rule of 2026-11-23 that a builder works its ground from beside it
  is what stands in its place (above).
- The inspection's: of the fourteen places where his document, his later words and the build differ
  (`docs/design/Mechanics_crosswalk.md`, "Where they differ") he ruled on three on 2026-11-22 and eleven
  stand. Of the nine calls at the end of the inspection's handoff he answered the merge and the scratch
  files in `/tmp` (left: "I have plenty of space"; not to be raised again); the rest stand.
- The arrival's four, above.
- `Handoff_2026_11_22_corners_and_mends.md`: the landings a block up or down between two level stretches
  (7 of 1,292 corners), "his to say if he takes it for a fault".
- `Handoff_2026_11_21_square_thirteen_and_stockyard_twenty.md`, "What I told him I think, and the calls put
  to him": the hearth before the whole floor, and what should fail a gate on hunger, among them.
- `Handoff_2026_11_20_placements_with_paths_and_the_square.md`, "His calls (each stands as built on no word)".
- `Handoff_2026_11_20_walked_hovels_and_yard_pieces.md`, `..._stockyard_along_a_path.md`, `..._ways_told.md`:
  "His calls".
- The storehouse's, of 2026-11-17 ("Leave the questions open I will get to them after"): the handoffs of
  that day, and the fence's one gateway (`docs/conventions/stores.md`).

## Found and not mended

Likewise where each round left them: "Found and not mended", "Owed" and "Known limits" in the handoffs
above; the entries of that name in `docs/conventions/square.md`, `paths_and_placements.md` and
`saves_and_checks.md`; the inspection's findings in its handoff; the four of
`Handoff_2026_11_22_playtest_notes.md` (deer on mountain ledges; the compiler and arrays with negative
bounds; the highest floor at a place being a trunk's top; the pocket of ground, above); and, of 2026-11-23
(`Handoff_2026_11_23_paths_builders_and_stockpiles.md`, "Found on the way"): the band dead at the square
at 950 1290; a hovel's way half a metre off the square's own path where that was raised after the hovel
was placed; a stockpile's place on a steep bit, more than three blocks off its level; the camp's floor
made ready from on it; three builders at one floor walking round one another, and two of them on one
spot at the storehouse; a band starved by the removal of its only stockpile (his call); two bands with a stockyard
and no stockpile going hungry; the strip of turf of his pictures, not made to happen. And of the piece
after it (`Handoff_2026_11_23_a_stockpile_is_one_level.md`): someone on the rim of a cut whose edge
does not lie on the walking map's half metre stands, by the colony's count, over the cut, in the
air by the bank's height; someone stopped a block or two deep for a second at a stockpile's edge;
live water beside a deep cut was not run; stone laid in a square's wall, and a path raised, where
someone stands (a forester a metre deep for eighteen seconds, a gatherer two blocks deep for
thirty-four); `--puddle` pours nothing without `--late`; a stockpile already in a save is not made
one level; a block column more than six metres off its level, not tried; two changes about the
cart not proved by cutting, and a comment in `Level_Places` that credits the wrong one (owed with
the next commit of code). And of the voxel people (`Handoff_2026_11_23_voxel_people_drawn.md`, "What he
might take for a fault" and each round's): the hands in the head at work (above); the brief's two first
values, printed by `serf_check` as MISS (a look merged by colour as the brief has it, 7,429 triangles
for its 2,600; a look's colours merged for room in its palette in 364 of 7,200 looks).

## How a session starts

1. This page.
2. `CLAUDE.md`, and from `docs/conventions/` the file of each part the work touches.
3. The newest handoff.
4. Is his game running? `pgrep -x castle_game`. If it is, or he says he is playing: build only in a
   scratch copy, open no window.
5. `git status` before any `git add` (his design document changes under a session: he works on it elsewhere).
