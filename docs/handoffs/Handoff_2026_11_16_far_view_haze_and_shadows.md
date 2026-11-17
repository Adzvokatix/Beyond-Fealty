# Castle Game handoff (2026-11-16: the far view accepted and merged; on his answer, a second round: the white dots found and closed, the sun's shadows and the water's mirror past the view's edge, a haze on the ground and at the map's rim, the old far land out of the game)

- **The far view is on `main`.** John, having tried it (2026-11-15): "Merge it, and on by default".
  `main` was fast-forwarded to ae68368 (the far view as he tried it, gated) before anything of this
  round was written, and to the head of branch `far-view` (this round) once it was gated. The
  working copy is on `main`. To have the far view as he tried it:
  `git checkout far-view && git branch -f main ae68368 && git checkout main`. To have the game before
  the far view: the same with `eb507d4`.
- **This round is built from his answer of the same message, with first values of mine, and merged
  with it**: he asked for each piece by name and then "Merge it, and on by default ... Then the
  stockpile". What he said is his; the numbers but for his two (1 m, 12 m) are first values: don't
  treat one as settled against him, and don't change one unasked.
- Commits after ae68368, each one piece: 37d1df1 (the dots, the floor), 64b06d2 and efb4637 (the
  far shadows), 1dbdb03 (the far mirror; the floor found by walking), 42a460a and b0c85a3 (the
  ground haze and the rim), 85b8b44 (the old far land out), e5ee9ed (`--drawn-still`), documents,
  and last the far maps read with four taps and drawn again every 20 frames (found by counting
  again after the review).
- Checks, from a clean copy (`git archive`) built from nothing, on b0c85a3. **Two things of the
  renderer were changed after that gate** (the far maps read with four taps for one, and drawn again
  every 20 frames for 45: the advisor's review found the stillness and the hole counts quoted from
  before the last changes, and the stillness did not hold when run again); for those the two builds
  were made again from a clean copy of the final commit (the six known warnings only) and the nine
  checks, the logs and the stress runner were not run again, none of them linking the renderer. On
  b0c85a3: both builds with the six known warnings only; all nine checks in debug, their counts
  as they were (water_sim 77, edit_check 41, ui 112, dynamics 18, serf 19, path_check 70,
  colony_check 643, deer 14, pick 59); `tools/reference_check.sh` eight logs line for line, none
  recorded again; `tools/stress.sh runner` "nothing died, nothing dropped", its states those of
  `main` (crowd_at_work and crowd_whole_map 7c212dc927735695, crowd_as_it_is a2f49f53239ef741,
  housing_2_workers 3796cb59384abfa4); the flora's hash the same in both builds. The commits before
  it were not gated one by one. The debug build of the game was run by hand as well (a band at work
  with a pan of 520 m and back; a rainy dusk from 300 m back with the clock at twenty times):
  nothing raised.
- Versions: generator 14, save format 6, colony blob 25, the herds' blob 2: as they were. Nothing of
  the round is saved, and the colony knows nothing of it.
- Driven only by script. Nothing of the interface or the pointer is touched.
- **Test windows of mine on his desktop**, each opened after looking that his own game was not
  running: about three hundred scripted runs (stills, cost runs of 2,500 frames, seven of the
  shadows' stillness, nine recordings of 30 to 300 frames, the look-cost script four times), every
  one with `--frames` or `--record` under a timeout. **His game came up once while I worked**
  (about 23:20 on the 15th): from then until it was gone I opened no window and built only in a
  scratch copy, so his `bin/castle_game` was not relinked under it. If that run of his was started
  from the working copy, it was a build from the middle of this round (the dots closed, the floor's
  first version, which from a mountain drew a dark slab over the far valleys: mended since).
- Zip: CASTLE_GAME/releases/castle_game_far_view_haze.zip (a `git archive` of `main`).
- Pictures: CASTLE_GAME/releases/far_view_haze_before_after.png (four views before the round and
  now, and the map's rim at 12 m beside 120 m) and far_view_haze_pan.mp4 (a pan with all of it on).

## John's words

2026-11-15, having tried the far view, whole:

"ok looking good, great performance, we are headed in the right direction, lets do this, Haze, let's
cover the ground around the camera in a haze 1m or so the trees poke above, transparent but enough to
cover loading at a distance and the white dot dithering for the LOD rings, if we can do something
about the white dot dithering, even just making them dark grey would be cool too. Let's do an opaque
boundary haze so the edges of the map, ramping from the transparent to the opaque in a 12m ring
around the map, can we have the haze follow the terrain of the mountains so the tops are still
visible but look natural, like the mist is climbing the mountains with fingers between the saddles
and ridges? Keep the shadows pst the view's edge it doesn't seem too expensive and it keeps other
issues from arising with visuals, sometimes you can see shadows when you can't see what is making
them and then shaddows start popping. If we can do the same with the water mirror that would be
nice. The vegetation is solved by the haze. Merge it, and on by default, remove the old far land,
but keep the functionality just comment it out or something, just in case, let's not do tilt shift,
I will leave the cheaper shader, eye-cetentered rigns, or building the tiles int he same pass up to
you by whatever you think fits best. Then the stockpile, great work."

## His sentences against the nine calls put to him

| call (as put to him) | his answer | done |
|---|---|---|
| 1. the haze | a haze on the ground a metre deep that trees poke above, thin near and covering far; opaque at the map's rim over 12 m; following the mountains, tops clear, fingers in the gullies | built (below) |
| 2. how far each block size lasts | not spoken of | stands as built |
| 3. rings by the focus or the eye | "up to you" | not built: below, "The three he left to me" |
| 4. no sun's shadows past the view | "Keep the shadows pst the view's edge" | built |
| 5. far water mirrors the sky alone | "If we can do the same with the water mirror that would be nice" | built |
| 6. grass ends at the view's edge | "The vegetation is solved by the haze" | the haze is half at that edge; a still shows it |
| 7. merge, on by default | "Merge it, and on by default" | merged |
| 8. the old far land | "remove the old far land, but keep the functionality just comment it out or something, just in case" | out of the game, its code kept (below) |
| 9. what next of his list | "let's not do tilt shift"; the other three "up to you" | none built, each measured or reasoned: below |

And one thing he found that was not among them: "the white dot dithering for the LOD rings".

## What was found: the white dots were holes

Reproduced first: one forest view at noon had 108 pixels of one colour, the sky's at the horizon,
along the first ring. Not dither grain: the two levels' surfaces do not lie in one place (a cell is
as high as its upper half is full), so the two fragments of one pixel stand a little apart on the
ground and read the cross-fade a little apart, and here and there both gave the pixel up and the sky
showed through.

- **`Far_Lap`** (0.075 of a doubling of distance, half the cross-fade): the coarser level has all its
  pixels that much before the finer has given up its last; where both keep one, the nearer is seen.
  108 became 3.
- Those 3 are not the far view's: cracks a pixel wide between two quads of one stack's mesh, which the
  build before the far view has too (counted with multisampling off: the same pixels) and the old haze
  hid by being the sky's colour.
- **A floor under the land** (`Ground_Floor`, `--no-floor`; his "even just making them dark grey"):
  where the land leaves a pixel open below the horizon, over the map, the sky's pass draws dark ground
  (Charcoal, lit by the day) with the air between. It shows through those cracks, and beside a coarse
  tile standing in on a slope while a fast pan comes in (counted with the floor off: up to 9,338 pixels
  of sky for the first 40 frames of a 360 m pan, none after).
- With all in: none of the sky's colour in the land at six still views (three before the haze, which
  has the sky's colour itself).

## As built

`docs/systems/rendering.md`, "The far view", has each whole. In short:

- **The sun's shadows past the view's edge** (`Far_Shadows`, `--no-far-shadows`). Two more depth maps,
  one for each held direction of the sun, over the whole map (0.72 m a texel; 64 MB of the card's
  memory): the stacks' meshes and every far tile in its own ring. Ground past the fog distance reads
  them, four filtered taps each (an edge 2 m wide); inside 0.85 of it the near maps; between, the one goes over to the
  other, by the place and never by the level. And the near maps reach as far up the light as the map
  goes, with the far tiles that stand in the light's way drawn into them: a mountain past the view
  shades the meadow in the view, and a shadow no longer comes into being as what casts it comes into
  the view.
- **Far water mirrors the world** (`Far_Reflections`, `--no-far-mirror`): the walk through the picture
  that near water makes, in strides as many times longer as its cells are larger.
- **The ground haze** (`Ground_Haze`; `--no-ground-haze`, `--haze X`, `--rim M`), in the one routine
  for the air, so the land, the people, the water and the floor all take it. How deep it lies is worked
  out once from the generator's map: 1 m on level ground (his figure), 0.35 m on open water, less the
  steeper the land (none on a mountain's side), and gullies filled to the land's mean over 65 m, 8 m at
  most. A thing is in it by how far it stands over the land as made. How thick: level ground is 8 %
  haze at the focus (or under the eye), half at 0.85 of the fog distance, three quarters from three fog
  distances on. The last 12 m to the map's edge (his figure) all haze. The sky's colour at the horizon.
- **The old far land is out of the game**: its option is commented out (two marked lines in the game
  bring it back), nothing of it is made at the start, and all its code still compiles, with
  `edit_check` still proving `Castle.Far`. Brought back in a scratch copy: it draws as it did.
- **`--drawn-still`**: drawn time holds still, for comparing two builds' pictures.

## Measured

- **The round, a frame** (`tools/look_cost.sh --hold-wait --far-wait --settle 2500`, the build before
  the round and after, back to back; 1,280 x 720, multisampled):

  | view | no far view | before the round | now | the round |
  |---|---|---|---|---|
  | meadow | 1.82 ms | 1.96 | 2.11 | +0.15 |
  | forest (close, steep) | 0.52 | 0.51 | 0.55 | +0.04 |
  | camp by day, by night | 2.05, 2.17 | 2.18, 2.28 | 2.32, 2.42 | +0.14, +0.14 |
  | horizon by day, at dusk, by night | 1.31, 0.99, 1.25 | 1.80, 1.50, 1.74 | 1.86, 1.53, 1.79 | +0.06, +0.03, +0.05 |
  | the lake, looking across | 0.86 | 1.93 | 2.01 | +0.08 |
  | rain, rain from low | 2.31, 1.45 | 2.53, 1.97 | 2.78, 2.17 | +0.25, +0.20 |
  | snow from low | 0.96 | 1.35 | 1.39 | +0.04 |
  | overcast (storm) | 1.40 | 1.92 | 2.08 | +0.16 |

  So the round is +0.03 to +0.25 ms, and the far view with all of it +0.03 to +1.15 over no far view.
  (The two right-hand columns are of the final code; "no far view" was taken an hour before.)
- By part: the far shadows little in dry weather (+0.01 to +0.03 ms at the usual views, +0.12 at the
  forest from 140 m back), **+0.18 in rain and storm** (the wet weather's program pays more for the
  far taps than the dry one does: why was not found); a frame that draws a far map is 2 to 2.5 ms
  longer (every two seconds or so as the sun goes, and three times a second while tiles come in).
  The far mirror: none measured (4.72 ms for 4.76 without,
  looking across a lake). The ground haze: +0.03 to +0.08 at the usual views, +0.20 at the heaviest
  tried. Each switched off costs nothing (rain with all four off 2.51 ms, before the round 2.52).
- **Memory**: 64 MB of the card's for the two far shadow maps; 2 MB for the haze's depth.
- **Stillness**: `tools/shadow_still.sh` 0.00 % at its three settings, on the final code; pulled back
  to 200 m, 0.18 % of pixels step (the river's ripples), the same with the far shadows and without.
  **It did not hold at first**: with one tap to a far map, the run at twenty times the clock read
  0.00 % once and 0.94 % and 1.11 % after (a far shadow's edge crept as the sun went from one held
  direction to the next, the two maps' texels not lying alike on the ground). With four taps (an edge
  2 m wide) three runs in a row read 0.00 %. At the game's own pace it read 0.00 % either way.
- **The holes, counted again on the final code**: none of the sky's colour at four still views with
  the haze off and the floor on (3 with the floor off too: the cracks in a stack's own mesh), and
  none in any of 240 frames of a 360 m pan begun the moment the far view was whole.
- **Coming in, at the screen's own pace** (vsync on, 60 frames a second, as he plays): the far view
  whole 6.6 s after the first frame and the map held at 18.6 s, as with it off (6.6 and 18.3).
- **`--no-lod` is still the picture of the build before the far view** (eb507d4), to the pixel: with
  `--workers 1 --timescale 0 --no-whole-map --drawn-still`, 0 of 518,400 pixels at three of four views
  (meadow and forest, with shadows and without), and at the fourth 659, as many as that build differs
  from itself by between two runs (whether they are the same pixels was not looked at).

## The three he left to me: none built, and why

- **A cheaper shader for the far levels: measured, and not worth it.** With every far fragment drawn
  one flat colour (no texture, no light, no air), the lake's frame is 1.70 ms for 1.99: of the far
  view's 1.13 ms there, 0.83 is not shading at all. Horizon 1.76 for 1.84, meadow 2.04 for 2.09. My
  estimate to him of "about half" was wrong: a quarter at best, at the dearest view. Drawing the far
  tiles nearest first was tried too: nothing (taken out again).
- **The tiles made in the pass that holds the map: by my reckoning it would make what he sees come
  later.** Not measured, reckoned from the counts: it would save about a third of the workers' time
  at the start, but the last level's tiles, which stand in for everything in the first seconds,
  would each also pack their 256 stacks (223 ms -> about 395, by the holding's own 0.67 ms a stack),
  so on three workers they would be whole at about 80 s for 46. On his machine the holding takes
  twelve seconds after the far view at either frame rate (measured, above), about what the main
  thread's half millisecond a frame lets through, so fewer worker seconds would not shorten it. Not
  built.
- **Rings by the eye as well as the focus: the one that changes what he sees, and I'd build it with
  the on-foot view.** Pulled far back and low, the ground by the eye is cells of 1 or 2 m, and the
  haze no longer covers it (it is clear under the eye by design). It means the rule for which level
  shows going by two centres in four places just built (the shader, the draw list, the shadows' casters,
  the game's streaming) and tiles streaming as the camera turns. His to ask for sooner.

## His calls (new with this round)

1. **The rim's 12 m.** His figure, as he gave it. Close by it is a soft end to the land; from a few
   hundred metres it is a line a pixel or two wide. The sheet has it beside 120 m; `--rim M` tries any.
2. **How thick the haze is**: 8 %, half and three quarters (`--haze X` scales them). At 85 % far off
   it read as snow.
3. **The haze on water at a third of the land's**, and no filling of a river's bed: at a metre a far
   lake was a white plain and the mirror he asked for was under it.
4. **Thickness by distance from the focus or from under the eye**, never by the angle it is looked
   through: so a low camera sees the ground at its feet, and what is far from both is hazed.
5. **The gullies' filling** (to the land's mean over 65 m, 8 m at most) **and the mountains' sides
   clear** (from a rise of 0.55 in one).
6. **The haze is the sky's colour at the horizon** (pale by day, dark by night), as the old haze was.
7. **The floor's colour**: Charcoal, lit by the day.
8. **The far shadows cost 0.18 ms in rain**, and a frame every two seconds is 2 ms longer.
9. **The old far land is not commented out as a whole**: its option is, and none of it runs; the code
   compiles so that it cannot go stale. If he wants the text itself commented out, a word.
10. **Rings by the eye**: with the on-foot view, or now.

Standing from before, not spoken of: how far each block size lasts.

## Known limits

- The haze goes by the land as it was made: what is dug or levelled does not move it (a pit is no
  deeper in it than its rim; a floor raised a metre stands out of it).
- Nothing of the haze or the far shadows without the far view (`--no-lod` is the old picture).
- A far shadow is soft (an edge 2 m wide), and the shadow of a tile that has just come in comes up
  to a third of a second after it at 60 frames a second (the maps are drawn again every 20 frames at
  most while tiles come and go). Not looked at in his hands: whether that reads as a shadow popping
  in during a pan at a low sun.
- In rain and storm the far shadows cost more than in dry weather: cause not found.
- While a fast pan comes in, the floor shows as dark wedges beside coarse tiles standing in on slopes.
- A stack's own mesh that comes late does not fade in as a tile does; an edit shows far off 2 to 16 s
  after; live water not at all (as before).
- Not run: on another GPU; the old far land together with the far view.

## Next

**The stockpile, his word: "Then the stockpile".** Nothing of it is built or designed, and the four
things asked of him on 2026-11-14 are still open, each with a default he can take in a word
(`Handoff_2026_11_13_herds_search.md`, "Next"): how large the overflow is (a quarter of a
stockpile's places); what it takes (any load that no ordinary place takes); what a serf does when the
overflow is full too (sets its load down where it stands; nobody sets out for that kind until there
is room); and whether the improvements (a covering, a fence, a storehouse) come in this pass or after
(after). The defaults are offers, not leave to build on silence.
