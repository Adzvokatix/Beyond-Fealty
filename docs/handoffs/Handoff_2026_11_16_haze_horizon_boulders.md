# Castle Game handoff (2026-11-16, evening: the far view's third round, on his answer to the second: no haze on the mountains and no fingers, the land's haze as thin as the water's, the sun and the moon go down behind the map's edge, the boulders drawn round; and on his answers to that, the boulders into the ground, generator 15, then trees through the rock, generator 16, and the rock's flicker)

- **On branch `haze-horizon-boulders`, from `main` at c8f1c40 (the second round as merged), not
  merged**: he asked for each piece by name and said nothing of merging, so `main` stays where he
  accepted it. The working copy is on the branch and both builds are of it. To go back to what he
  had: `git checkout main`, then build it again (`gprbuild -P castle.gpr -XCASTLE_MODE=release -j0`,
  and `debug` likewise), or `./bin/castle_game` stays the branch's. The horizon and the boulders
  have switches (`--no-low-horizon`, `--no-round-boulders`); the haze's change has none of its own
  (`--no-ground-haze` takes all of the haze away): `main` is the way to see it as it was.
- Commits, one piece each: 0d24702 (the haze), 5e5ce93 (the horizon), 087c8ba (the boulders), then
  the documents.
- Checks, from a clean copy (`git archive` of 087c8ba) built from nothing (the mesher is under the
  checks this time): both builds with the six known warnings only; all nine checks in debug, their
  counts as they were (water_sim 77, edit_check 41, ui 112, dynamics 18, serf 19, path_check 70,
  colony_check 643, deer 14, pick 59); `tools/reference_check.sh` eight logs line for line, none
  recorded again; `tools/stress.sh runner` "nothing died, nothing dropped", its states those of
  `main` (crowd 7c212dc927735695, crowd_as_it_is a2f49f53239ef741, housing 3796cb59384abfa4); the
  flora's hash 5676219328934879273 in both builds. After it came the documents and a comment in
  `castle-render.ads` corrected (no code); both builds were made again from the final commit.
- The numbers are first values of mine, his calls at the end; what he said is his.

## John's words

2026-11-16, having had the second round (the far view's haze, shadows and mirror) merged:

> let's remove the fingers and haze off the mountains and the 85% as as snow, the subtle mist above
> the far water was better, let's lower the line of the horizon below the edge of the map, so it it's
> harsh edge with the sun and moon can't be seen as easily from a high view angle or vantage point.
> Let's smooth the boulders.

(The message came twice, word for word.) He did not answer the stockpile's four questions; they are
put again at the end, with their defaults. Nothing of the stockpile was built.

## His sentences, one by one

- **"remove the fingers and haze off the mountains"**: the fingers were the first build's filling of
  every gully to the land's mean round it (8 m deep at most), which ran up the mountains in white
  tongues; that filling is gone. And there is no haze where the generator's mountain mask is 0.2 or
  more, all of it under 0.1 (the foot of the mountains, as the boulders have it), eased between.
  Open water keeps its mist wherever it is (a tarn in the mountains too). The thinning on steep
  ground stays. (0d24702)
- **"the 85% as as snow, the subtle mist above the far water was better"**: 85 % was in no build he
  had: I lowered it to 75 % before the merge and said 85 % in the report. Read as: the far land's
  thick white haze goes, and the far water's mist is the measure. The water's haze was a third of a
  metre deep at the land's rates, which came to 2.9 % at the focus, 21.5 % at the view's edge and
  38.4 % far off; those are now the land's and the water's alike (the land's were 8 %, 50 %, 75 %).
  So far land lies under the mist far water had, and the water is as it was: the lake view against
  `main`, pixel for pixel, differs nowhere on the water but at the shore, where the haze's texture of
  2 m mixes land and water. (0d24702)
- **"lower the line of the horizon below the edge of the map"**: found first. From 440 m back over
  the middle of the map the map's edge is about 4 degrees under eye level; between the two the sky's
  pass drew the haze, and the sun was cut off on it by a straight line at eye level, well over the
  land (a still of it: the sun's lower part sliced off in mid-air). Now, under eye level, the sky is
  still that haze (the land and its 12 m rim go into that colour), but the sun and the moon are drawn
  on it down to where the map's edge is in that direction (the land's height where the line of sight
  leaves the map, less 10 m), fading out over the last 1.7 degrees under eye level (`Sun_Gone`, over
  which the sun's light on the land goes too). **What that gives is not the same from every height.**
  From low down the line is under the map's edge as he asked: 200 m back at the lowest tilt (the eye
  some 25 m up) the sun now goes down behind the trees at the map's edge, where on `main` it was
  sliced off in mid-air a little over them. From high up the edge is further down than the fade
  reaches (440 m back: 4 degrees against 1.7), so the sun fades out in the haze above the land: no
  line any more, but not the land hiding it either. (5e5ce93)
- **"Let's smooth the boulders."**: drawn round, their blocks untouched. A boulder's faces are soft
  quads, as foliage's are: its edges and corners drawn in half a block, its hollows drawn out half a
  block, so a step of one block is one slope and a notch is filled; lit as a round thing. On a
  stack's 8 m line, where foliage's corners stay put, a boulder's are moved too, by what both stacks
  work out alike from the generator (2,386 of the 4,477 boulders cross one), and grass at a
  boulder's foot does not count as rock. Those two I built first, for steps a close still showed on a
  boulder across a stack's edge, and they changed it little; what took the steps away was drawing the
  hollows out, which came after (the steps were the rock's own notches). (087c8ba)

## Measured

- **The haze**: no shader change, no cost; the lake view, `main` against the branch with the
  picture held still (`--workers 1 --timescale 0 --no-whole-map --drawn-still`, frame 30): `main`
  against itself 0 of 518,400 pixels; against the branch the water unchanged but at the shore, the
  mountains round it cleared.
- **The horizon**: switch on and off, the same build, the picture held still: looking away from the
  sun 0 of 518,400 pixels differ; looking into the sunset 261, all under the sun. The sunset view
  from 440 m: 5.94 to 5.98 ms either way (no cost seen). Stills at 19.75, 19.85, 19.95 and 20.05 h
  (the sun from 0.4 degrees over eye level to 2.2 under), a night with a setting moon, the eye over
  the map's west edge and the eye outside the map looking in.
- **The boulders**: quads in a view +0.4 % (4,116,481 to 4,133,931 over a meadow strewn with them);
  a stack's meshing as long as it was (8.6 to 8.8 ms of a worker); frame 1.77 and 1.79 ms on and
  off, 0.53 and 0.54 close up, 4.94 and 4.93 at the mountain lake. Five close views and a low pan of
  240 frames over the boulders by the stake (across several stack lines), with no floor and no ground
  haze: no pixel of sky, on or off. The sun's shadows hold still (`tools/shadow_still.sh --timescale
  0.05`, three runs: 0.00 %). The dark points on a boulder on bare rock are there with shadows off
  too: the shape, not a shadow. The flora's hash as it was (5676219328934879273).
- Stills of all three, `main` beside the branch, nine rows:
  `~/CASTLE_GAME/releases/haze_horizon_boulders_before_after.png` (the three sunset rows are the
  branch with `--no-low-horizon` beside it on, which is `main`'s sky). No film: a recording's clock
  runs on through the wait for the map, so a sunset cannot be started at a given hour; the two
  hours side by side stand in for it. The branch as a zip: `castle_game_haze_horizon_boulders.zip`.

## His calls (new with this round)

1. **From high up the sun fades out in the haze above the land, not behind it**: the line he asked to
   go under the map's edge is under it from low down (the land cuts the sun off), but from high up
   the edge is further down than the sun's fade reaches. The other way: the sun bright all the way
   down to the land's edge from any height, at the price of a bright sun in a sky already near
   night (from 440 m up the land's light is gone some 2 degrees before the sun reaches the edge).
   As built, the last of it is seen for its own breadth after its light has left the land.
2. **The far haze is thin now, and "The vegetation is solved by the haze" was said of the thick
   one**: the yellow patches of grass and grain end at the view's edge (there are none in the far
   view), under half haze before and a fifth now. I could not find a patch lying across the view's
   edge to show it in a still; in the forest, meadow and high views I took, no patch's end shows. If
   it shows to him, the edge's figure alone can go back up.
3. **Near the focus the land's haze is 2.9 %, not 8 %**: the price of one haze for land and water
   with the water unchanged.
4. **No haze in the mountains, by the generator's mountain mask** (from 0.1 of it to 0.2): a valley
   high in the mountains is clear too; a lake there keeps its mist.
5. **The boulders' half block**: a one-block knob on a boulder comes to a point (some read as
   teeth); the shapes themselves are the generator's (a rounder rock in the making is a change of
   the world, the stone counts and the reference logs with it).
6. Still open from the second round: **the rim at 12 m and the haze's colour** (the sky's at the
   horizon). Not answered, so not taken as accepted.

## Known limits

- A boulder's corner on a stack's edge goes by the boulder as it was made: where a stone has been
  prised off on that line, the corner may lean toward it.
- A bush touching a boulder at a corner both meet is drawn by two rules there (a bush's corner on
  a stack's edge does not move; a rock's does).
- The far view's tiles draw boulders in their own coarse cells, as before.
- The moon, as before, fades by its own height (none under 0.6 degrees under the horizon): it never
  reaches the map's edge from high up.
- Not run on another GPU. The debug build of the game was run once, scripted (the boulder on a stack's edge at dusk, panned 520 m away and back): nothing raised.

## Test windows and input

All input was scripted (`--cam`, `--time`, `--shot`, `--record`); every window was mine, opened
only after checking his game was not running. The debug run, given no `--shot`, wrote the game's own
`screenshot.png` in the repo's folder over whatever was there (git ignores it).

## The stockpile (next, by his word "Then the stockpile")

Four questions, each with a default he can take in a word; the defaults are offers, not leave to
build on silence:

1. How large is the overflow? A quarter of a stockpile's places.
2. What does it take? Any load no ordinary place takes.
3. When the overflow is full too? The serf sets its load down where it stands, and nobody sets out
   for that kind until there is room.
4. The improvements (a covering, a fence, a storehouse): this pass or after? After.

## His answer, and the boulders into the ground (the same night)

> ok great I like the changes, the last thing we need to do for visual asthetic, is make the base of
> the boulders, so they don't look like balls plopped everywhere, they need extend into the ground.

Taken as liking what he saw, not as "merge": still on the branch, unmerged. The calls above stand as
built. One commit after 6275352, with the documents and the logs.

- **Found first**: a boulder's centre already sits at the ground's level or a block under it, so half
  of each was always buried; what was missing was spread where the rock meets the ground, and on a
  slope the downhill side hung over the ground.
- **Tried in the drawing first** (`Boulder_Feet`, `--no-boulder-feet`): the corners where the rock
  meets level ground drawn out 0.75 of a block and down 0.4, so the lowest face leans out and goes
  under the ground. At most a quarter of a metre: close up it shows, from 60 m nothing. Kept, as the
  finish where rock meets ground.
- **So the shape is the generator's (generator 15)**: column by column, on each column's own ground,
  nothing is hollow under a boulder (everything under its round goes down into the ground's top
  block; on a slope the downhill side goes down to the ground), and a skirt round its foot 0.4 wider
  than the round for two blocks and 0.2 for the next, on a gentler noise so its edge has no loose
  blocks. Where the boulders are, how many and their rounds are as they were.
- **Its price**: the world changed, so saves from before are refused; **all eight reference logs
  were recorded again** (every run's scene set as it was, to the line; how each ends moved both
  ways: living at the end of the eight 32 before, 29 after); the 16 boulders by the stake are
  9,638 blocks of rock for 6,071, 5,733 over the ground for 3,554, and cover 146 m2 of ground for
  63 (about 60 % more rock, 2.3 times the ground under it), so there is more stone to prise.
  There is no switch for it: a world that changed by an option would not be the world a save was
  made in. The way back is the commit before it (`git checkout 006576c~2`, then build both modes). The two herd demos'
  moments (found on generator 14) were not looked for again.
- Measured: the nine checks as they were (77, 41, 112, 18, 19, 70, 643, 14, 59); the reference check
  passes on the new logs; making a stack 1.45 ms of a worker for 1.43; meshing one 8.9 ms (8.6 to
  8.8 before); quads +0.6 % over a meadow of boulders; the frame 1.79 to 1.82 ms (1.77 to 1.79);
  five close views and the low pan with no floor and no ground haze: no sky through; the shadows'
  still view 0.00 % in eight runs of ten, 0.01 % in two (the build before the rounding: 0.01 % in one
  of six); the debug build run over the boulders and panned away and back: nothing raised.
- Gated from a clean copy of 76247fe: both builds with the six known warnings only; the nine checks
  as they were; the eight logs (as recorded again) line for line; the stress runner "nothing died,
  nothing dropped", its states new with the world and alike within each family (crowd
  5a7d6d76b87e7780, crowd_as_it_is 73f294226ca2eace, housing b2da6dd40e9295ce); the flora's hash of
  the trees and bushes as it was (5676219328934879273).
- How each log's end moved: the herds' flight run ended with no one living and now ends with four;
  the hands and levelling run and stage 5b's ended with five and four and now end with no one; stage
  5a's 2 to 6, the camp and zones 6 to 4, the other three as they were.
- Looked at again on the final build: the five close views and the low pan, no sky through (the
  boulder on a stack's edge the same to the pixel as before the edge corners kept their columns);
  the map from 440 m and a forest from 140 m beside the same before generator 15: the far view's
  boulders a little larger as grey dots in the meadows, no grey patches. A boulder crossing the
  first ring of the far view was not watched in motion (the pan recorded hardly moved).
- Trees: 697 of the map's 99,220 have the foot of their trunk in a boulder (370 by the round
  alone): the trunk stands on the rock there, as a tree does that grows out of one.
- Stills: `~/CASTLE_GAME/releases/boulders_into_the_ground.png` (as he had them beside now, five
  views).
- His calls: **the skirt's 0.4** (the ground under rock more than doubles); **the generator's change
  itself** (the way back is the commit before it); on a terraced slope the rock going down to the
  ground ends in points where it meets the steps.

## His next answer: trees through the rock, and the rock's flicker (2026-11-17)

> The rock sizing is fine, see if we can do something about the trees being on top of the rock, the
> trees should go through the rock to the ground, don't worry about the herds, we are about to detach
> the herds from the stake, we can control their placement afterwords. The stepped slope rock is great
> as is. There is some flickering around some of the surface textures for the rock, see if we can
> change that, or redesign the rocks generation to fit the smoothing, it looks like overlapping
> meshes to me. Whatever requires the least work to fix.

Still on the branch, unmerged. Taken as: the skirt's 0.4 and the slope's rock accepted as they are;
the herds' demos and the logs' herd moments no concern.

- **The flicker, found first**: a slow pan recorded past three boulders and every pixel counted that
  steps and steps straight back between three frames. Past the boulder on a slope 868 such pixels in
  120 frames, 67 with the boulders drawn in steps: the rounding's. In a frame of it, hatched stripes
  on a sliver: a soft quad's four corners move different ways, so it is not flat, and cut along the
  wrong diagonal its two triangles fold back across the faces round them. **Mended in the drawing**
  (the least work, nothing of the world): the vertex shader works out all four corners and cuts along
  the diagonal that folds least. 868 -> 30; past the boulder on a stack's edge 1,269 -> 1,119 (in
  steps 978; the rest is grass). No frame cost seen (1.81 to 1.84 ms). The mountains' own rock
  shimmers in a pan too (its fine texels and one-block pits): older than the rounding (the second
  round's build the same, 8,268 for 6,815) and not changed.
- **Trees through the rock (generator 16)**: a trunk where a boulder lies stood on the rock (697 of
  the map's 99,220 trees). Letting the trunk replace the rock alone changed nothing to see (the rock
  still wrapped it), so the rock gives way round a trunk, a block each side, from the ground up (the
  ground's top block put back as it was): the trunk stands on the ground in a cleft of the rock, and
  the rounding draws the cleft's walls in to it.
- Its price: saves from generator 15 refused; all eight logs recorded again (each scene as it was;
  one log unmoved; living at the end of the eight 29 -> 33).
- Gated from a clean copy of d4c843c: both builds with the six known warnings only; the nine checks
  as they were; the eight logs (as recorded again) line for line; the stress runner "nothing died,
  nothing dropped", its states new with the world (crowd d0f37a9fe49ed1c2, crowd_as_it_is
  a8fb418744446be8, housing f5f4ce1950813a9b). Stills: `~/CASTLE_GAME/releases/rock_flicker_and_trees.png`.
- Checked on the final build: the nine checks, five close views and the low pan with no sky through,
  the shadows' still view 0.00 % three times, a debug run by a tree in a boulder panned away and back.
- Limits: a tree felled in a cleft leaves the cleft; at a stack's edge the corners lean toward the
  rock as made (the cleft is not known there); the trunk does not show its foot in every view (where
  the rock's foot spreads to meet it).

## His word on it (2026-11-17)

> I love what I see great job, it really came together, I am not experiencing any anomolies, is tree
> leaving a whole in the stone is expected, no need to change it.

Taken as: what he has tried shows him nothing wrong; **a tree felled in a cleft leaves its hole in the
rock, and that is expected: not a limit, not to be mended.** The cleft's width (a block each side) was
not spoken of: it stands as built. He did not say "merge": the branch stays as it is, unmerged, `main`
at c8f1c40. Nothing was built on this answer. The stockpile's four questions are still open, with
their defaults (above): the defaults are offers, not leave to build on silence.

## Merged (2026-11-17)

> Ok merge.

`main` fast-forwarded to the branch (d0efbb9: the code is d4c843c's, gated as gate 41). The way back:
`git checkout c8f1c40` (main before it) and both builds again.
