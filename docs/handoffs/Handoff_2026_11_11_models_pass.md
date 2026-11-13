# Castle Game handoff (2026-11-11: the last pass before stage 6: rounded models, the bow and the axe carried, soft foliage, the herds' flight, the fringe of paths; then, from John's answer, a quiver, grass as tufts and generator 13: trees reshaped, tall grass in drifts; accepted as built the same day and merged into `main`; Claude Code)

- **Closed: accepted as built.** John, on the report of the second build: "impressive, the world is in
  desirable state, merge it into main and prepare for a session clear". `models-pass` is fast-forwarded
  into `main`; the zip is of `main`. Two rounds, both built with first rules and values of mine: those
  values stand as first values, his to tune (see "What his acceptance covers", below).
- **Stage 6 (habitation, with stockpile mechanics rolled in) is his to open in a new session**, as the
  handoff before this one says. Nothing of it is designed. This file is where that session starts.
- Code: GAME_alpha_1_3/compiled, `main` (the work was done on branch `models-pass` from `main` at 2261926,
  which is kept).
  - Round one: 48825f6 (models and tools), e0667b6 (foliage and the fringe), d6a2821 (the herds), 556d083
    (two small changes found on review). Tag `models-pass-1` is that build as it was put to him.
  - Round two: e11b84e (the quiver), 3117a5d (grass drawn as tufts), 69ee631 (generator 13: trees, tall
    grass, the seven reference logs regenerated), 4c22f4f (the quiver swung up when he sits, and the older
    documents' first-day figures measured again); documents and the demo's script between and after.
  - Zip: CASTLE_GAME/releases/castle_game_models_pass.zip (a `git archive` of `main` at the closing
    commit, documents only after 4c22f4f). Demo: models_pass.mp4 (tools/demo_models_pass.sh), 65 s.
- Checks, run from a clean copy of 4c22f4f (the last commit that changes code), built from nothing in debug
  and in release with the six known warnings: all nine checks pass in debug (colony_check 422);
  `tools/reference_check.sh` passes, all seven runs against their regenerated logs; the reference band's
  state after two days is the same at two and at eight workers, in the debug build, and through a save
  taken half a day in.
  `tools/shadow_still.sh` reads 0.00 % at one, three and (at dusk) one game minute a second.
  `./bin/flora_stats` draws three thousand trees of each kind alone: none reaches past the generator's 20
  blocks, and the debug and the release build hash their shapes alike.
- Versions: **`Generator_Version` 13** (trees reshaped, tall grass in drifts): a save made before it is
  refused, with a line saying why. Save format 6 as it was. Colony blob 17 (round one: the herds' own blob
  1 -> 2, nothing of the colony's). The older colony blobs still load and `colony_check` still has them.

## John's words (2026-11-11)
"ok before we start stage six this is our final pass at some improvements for what we currently have, this
has to do with models, first I would like to improve the model generation we have, a slight drift away from
the voxel block design, something that removes the minecraft feel from the models, but not too much a hybrid,
a tiny bit of smoothing, slightly higher triangle count for our models going forward, nothing too expensive.
The next is foliage, needs a bit more organic feel to it. The shortbow for the hunter is a bit of an issue,
right now it's just a stick jutting directly out from the hand, same with the axe, and is there a way to
place the bow on the back, and the axe on the hip when they aren't swinging it, deer pathfinding is kinda
wonky, when the herd node move away and deer panic they start to rubberband and swing around, they also
don't mind submerging themselves in water. The last is the texturing when the serfs build paths and what
not, it would be nice if the edges around the paths and compacted areas had some charecter too it. That is
about it."

And, while the work was under way: "forgot to say can we curve the bow too".

His answer to the first build, the same day:

"Ok, don't worry about ever being compatible about mainting compatibility with old saves during production.
So we can rewrite the trees, grass can get a slight overhaul. A quiver would be nice, full animations are
not important, we want a happy balance between realism and immersion, so just enough realism to be immersive
without being expensive and time consuming if that make sense."

How they were read:
- "the model generation ... going forward": the way every model is made and drawn, not five models redone.
  So the change is in the box itself (`Castle.Bodies.Box.Round`, `Taper`) and in the one shader that draws
  boxes: serfs, deer and every prop got it at once, and the next model gets it for nothing.
- "not too much a hybrid, a tiny bit of smoothing": still boxes on the 5 cm pixel with the painted skin as
  it was; their edges rounded, limbs tapered. No new meshes.
- "place the bow on the back, and the axe on the hip when they aren't swinging it": the bow is out for the
  stalk and the shot, the axe for the chopping; stowed the rest of the time, walking to the tree included.
- "rubberband and swing around": measured before anything was changed (below); both were in the herds'
  simulation, not in how the deer are drawn.
- "the edges around the paths and compacted areas": where a footpath or the camp's trodden floor meets
  grass. Drawn, not dug: no block changes.
- The answer is to the four calls the first report put to him. "don't worry about ... old saves ... So we
  can rewrite the trees": the generator may change; rounder crowns were the thing held back for it. "grass
  can get a slight overhaul": the first round had left grass alone. "A quiver would be nice, full animations
  are not important": a quiver, and no hand reaching for it or for a tool. The last sentence I took as a
  standing rule for every look from here on, and the first as a standing rule for production; both are in
  the framework and in CLAUDE.md in his words.
- "Ok" I did not take as acceptance of the first build: he names what to do next and says nothing of having
  run it. So the first round's values still stood as mine until his answer to the second.

His answer to the second build, the same day:

"impressive, the world is in desirable state, merge it into main and prepare for a session clear"

## What his acceptance covers
- The whole pass, both rounds, as built: it is on `main`. Recorded in his words and no further: he did not
  go through the calls below one by one, so each stands by default as a first value of mine, his to tune,
  and none is to be changed unasked.
- "prepare for a session clear": the documents are closed (this handoff, the plan, the stage log, the
  framework, CLAUDE.md), the zip is remade from `main`, the session's scratch files are gone. The older
  branches and tags are as they were; `models-pass` and the tag `models-pass-1` are kept.
- One thing his acceptance makes possible and that was **not** done in closing, because it changes the
  colony's code after the build he accepted: the herds as they were (`--deer-scatter`, `Set_Scatter`, the
  old half of `Castle.Herds`) can now be taken out. Six of the seven reference logs run with it and would
  be regenerated in that commit. It is a clean-up for whoever next works on the herds, not owed.

## What John sees on first launch
New in the second round:
1. **Trees are trees.** A broadleaf's crown is lumpy domes of leaves hanging round the top third of its
   trunk, on boughs; no flat top, no box. Spruces are cones of drooping whorls with a spire, pines bare
   boles with flat plates of needles high up, aspens slim columns of small puffs with the pale trunk showing
   between them, apples small round heads. In winter a broadleaf is boughs and twigs. Every tree stands
   where it stood and is the kind it was.
2. **Crowns are solid.** The gaps between the leaves are dark, the inside of the crown, not holes with the
   sky in them.
3. **Grass is grass.** A tuft is a few leaning blades, no two alike, lit like the turf it stands in; it was
   a cube with barred sides, black on the side away from the sun. Long grass stands in drifts, knee-high in
   their hearts, with short turf between; wild grain is a stand of stalks with its ears at the top.
4. **A meadow's steps are banks of turf**, a little darker than the flat, where they were black risers; and
   the meadow is lighter and darker in drifts.
5. **The hunter has a quiver**: a leather tube on his belt behind the hip of his drawing hand, the fletched
   ends of four arrows standing out of it; swung up along the belt when he sits to eat.
6. **A save from before today does not load.** The game says it was made by another version of the world
   generator.
7. **The reference band's first day and first winter go otherwise**, with no rule of the colony changed: the
   world is another, and a run turns on a hunt or two. The hearth stands at a quarter to twelve (it was half
   past twelve), the first stew is cooked by three (a quarter to eight), nobody goes to bed hungry the first
   night (three did), and one of the six dies in the winter (four did).

From the first round, as put to him then:
8. **Everyone is rounded.** Heads, limbs, bodies, deer, logs, stones, the pot: boxes still, edges and corners
   rounded off, limbs narrowing to wrist and ankle, a waist, a jaw.
9. **The hunter's bow is a curved stave with a string, across his back.** Stalking, it is in his off hand,
   carried level; to shoot he stands it upright and draws: the limbs bend, the string comes back to his
   cheek with an arrow on it. A couple of seconds after the shot it is across his back again; with a deer
   across his shoulders it rides level across the small of his back, under the load.
10. **The forester's axe has a haft, a poll and a bit, and hangs behind her hip.** It is in both hands only
   while she chops.
11. **A path's edge is ragged**: grass creeps onto it, the turf beside it is worn through and yellowed, a few
    pebbles lie along it. The same round the camp's trodden floor, which has lost its stair-stepped rim.
12. **A startled herd runs off together** and stands where it stops. No deer bolts fifty metres on its own
    and trots back; none stands in a pool.

## His calls (what I decided that he may want otherwise)
Second round:
- **Every tree is where it was, the kind it was, with the trunk it had.** Only its shape is new. So the
  band's wood, its logs and what a forester fells are as they were. Moving or resizing trees is one more
  generator change, free now, not done.
- **A crown hangs to about two thirds of the way up the trunk** and is rounder for fewer blocks than it was
  (a broadleaf about 1,960, where it was 2,490). A forest's canopy looked as closed to me in the stills as
  it was; I did not measure it.
- **Trunks are still square columns**, one or two blocks wide. Drawing them round is not done.
- **Bushes are the lumps they were.**
- **Tall grass is half as much**, 16 % of the turf's columns where it was 30 %, standing in drifts. It is
  straw to the band, and still found: the reference band has no porter, so I ran it with two, and they had
  24 straw in store after three days (the reserve is 20).
- **A step in a meadow is lit as a bank of grass.** It no longer stands in its own shade, so a slope reads
  as turf with soft steps, not as a contour map. Steps of earth and rock are as they were.
- **The quiver is on the hip, not the back**: the bow lies across the back and a deer goes across the
  shoulders. It always shows four arrows.
- **Nothing reaches.** No hand goes to the quiver, the hip or the back (his words). The tool comes to the
  hand over about half a second, as in the first round.
- **Nothing sways**, grass included. Grass could (it casts no shadow); leaves could not without the sun's
  shadows, which are held still on purpose, stirring with them.

First round, unchanged:
- **How round.** A box's edges are rounded by 0.28 of its thinnest side, 6 cm at most; a head by 7.5 cm.
  Limbs narrow by a sixth. `castle-bodies.ads`, top.
- **Which hip, which shoulder.** The axe behind the hip of the dominant side; the bow's upper limb over the
  off shoulder (the hand that holds it).
- **The herd's flight** is seven rules of mine (`docs/systems/deer.md`): a start of 0.6 to 0.9 s on a
  heading of its own, then with the node; the node at 5 m/s (it was 4); a herd in flight is turned only by
  someone within 8 m; turning limited to 2.5 rad/s, 4.5 in flight; a deer left 8 m behind takes the way the
  node went.
- **Deer do not wade at all, calm, and a quarter metre in flight.** So a herd no longer crosses a stream
  half a metre deep: it stays on its bank unless there is a dry way round.
- **A cornered herd still breaks.** Herds keep within 70 m of the stake (the ground that stays loaded).
  Pressed against that edge with the danger inside it, the node tries shorter flights and ways round past
  the danger; with none, each deer bolts a second or two by itself and comes back, which is the old look in
  small.
- **The fringe is one block wide each side**, and only between grass and footpath or dirt. Not against sand,
  gravel or rock. It applies to natural ground too, wherever generated dirt lies level with grass.

## Built
Second round:
- **The quiver** (e11b84e): `Castle.Props.Quiver`, placed from the hip's frame in `Castle.Serfs.Show_Tool`
  (`Quiver_Tilt`), mirrored for the left-handed, further out over a winter cloak, none on a child.
- **Grass drawn** (3117a5d): `Castle.Mesher` "Tufts" (`Tuft_Bit`: a plant on the ground is a column of quads
  of its own, never merged with its neighbour's); the vertex shader leans it, draws its top in and makes it
  taller or shorter by the column it stands in; the fragment shader lights it as turf, darker at the root,
  and draws its top as blade tips. The side of a block of turf is lit as a bank (`Turf_Up`). The meadow's
  tone goes by a noise (`Meadow_Tone`, `Meadow_Sere`). `Tuft_*`, `Grain_Tips`, `Turf_Up`, `Meadow_*` at
  the top of `castle-render.ads`. No block changed in this commit: the seven reference runs matched as
  they were.
- **Generator 13** (69ee631):
  - Trees: `Castle.Flora.Draw_Tree` rewritten (`Puff`, `Bough`, `Twigs`, `Fill`; the spruce's whorls);
    `Tree_At` untouched. `Tree_Reach` is in the spec now. A stack draws every trunk before any bough
    (`Tree_Part`), so a bough never lies in a neighbour's trunk. Constants at the top of `castle-flora.ads`.
  - Tall grass: `Castle.Geology`, the last branch of the ground cover, on a new channel (`Grass_Drift`);
    `Grass_*` at the top of `castle-geology.ads`. Vegetables and grain are placed first, as they were.
  - With it, in the drawing: the gaps between leaves filled dark (`Foliage_Deep`) and the fraying turned
    down (`Foliage_Ragged` 0.5 -> 0.22), both because a round crown is all edge; a tall plant's lower blocks
    drawn as stalks; tufts last in a stack's quads and out of every depth pass (`Mesh.Cast`).
  - `tools/flora_stats`: three thousand trees of each kind drawn alone, their reach (fails past
    `Tree_Reach`), bark off the trunk under a serf's height, branch blocks in a neighbour's trunk, a hash of
    the shapes, and the tall grass.
  - The seven reference logs regenerated, each with the options it had.

First round:
- **Rounded boxes** (48825f6): `Box.Round`, `Box.Taper`, `Rounding`; `Box_Face_Source` draws a box as six
  faces of nine cells (324 vertices; `Castle.Figures.Box_Vertices`), in the figure shader and the caster's.
  Serf tapers and the head's rounding at the top of `castle-bodies.ads`; the deer's at the top of
  `castle-deer.ads` (its two body boxes now overlap by two pixels).
- **Tools** (48825f6): the axe and the bow out of `Castle.Bodies.Build`; `Castle.Props.Axe`, `Put_In`,
  `Put_Bow`, `Bow_Rest`; `Castle.Serfs.Show_Tool`, `Tool_W`, `Axe_Hold_S`, `Bow_Hold_S`. The bow is eleven
  boxes on eleven bones (a grip, four pieces a limb, two halves of string). The aim's hands moved a little
  (the bow arm all but straight, the draw level). The arrow is 3 cm thick, where it was 5.
- **Foliage** (e0667b6): `Castle.Mesher` soft quads (`Soft_Bit`, `Pull`, `Corner_Pulls`, `Emit_Soft`); the
  world's vertex shader moves the corners (`v_grid`, `v_bend`); the fragment shader ruffles, masses and
  lifts. `Foliage_*` at the top of `castle-render.ads`.
- **The fringe** (e0667b6): `Castle.Mesher.Fringe`, `Surface`, eight bits a top face; the mesher's edge
  columns carry the generator's top block; the fragment shader's fringe block. `Fringe_*` at the top of
  `castle-render.ads`.
- **The herds** (d6a2821): `Castle.Herds.Flee`, `Step_With_Herd`, `Head_Step`, `Trail_Point`, `Travel`,
  `Dry_Spot`, `Water_At`; `Set_Scatter`, `Scatter`; `Castle.Nav.Plan`'s `Wade` (and `Step_Free`, so the
  pieces of ground stay a serf's). The old way is whole in the code beside the new.
- **For looking and measuring**: `--lineup-turn RAD`, `--lineup-does MOTION` (the game); `--deer-track FILE`
  (`colony_run`); `--deer-scatter` (both).

## Measured
Everything here is on the world of generator 13. What the first report gave him was measured on generator
12, and a different world is a different run, so each was measured again; the old figures follow in
brackets.
- The herds (seed 1, the reference band, four game days from six on day 20, `colony_run --deer-track`):

  | | as they were | fleeing together |
  |---|---|---|
  | deer-seconds in water | 2,661 of 41,316 (6.4 %); 2,524 deeper than a block | 5 of 44,750 (0.01 %); none deeper than a block |
  | further than 15 m from its node | 3,942 s; furthest 146 m | 1 s; furthest 16 m |
  | walked in the 20 s after a panic | 28.0 m | 3.7 m |
  | heading turned over 120 degrees from one second to the next, on the move | 295 times | 32 times |

  (Generator 12: 334 against 23 in water; 4,931 s against 8 astray; 27.8 m against 3.9; 139 turns against
  36.) The herds as they were go by chance from world to world; the herds fleeing together hardly do.
- Hunting, over the 41 days of the reference run: 31 deer with 75 arrows, and 31 with 83 with the herds as
  they were. (Generator 12: 32 with 87, and 29 with 72.) So the first report's "hunting comes out a little
  differently" does not hold as a rule: on this world it is the same kills for fewer arrows.
- The first winter moved again, as it will: five of six alive at the end of the run with everything on,
  three with the herds as they were. (Generator 12: three, and one.) Not tuned. The band with no forester
  (a cook, two hunters, three gatherers) sleeps cold most winter nights and all six see the spring; on
  generator 12 all six died.
- The reference band's first day, with the quarter-hour lines (`--log-hours 0.25`) and runs cut short to
  see when the camp stops being built: hearth at a quarter to twelve (a quarter past nine with
  `--all-hands --no-level`, half past eleven with `--no-level`), first stew by three in the afternoon,
  nobody hungry at midnight. The camp's lot has 56 square metres to make ready, where it had 64. The
  hearth at the two other sites `needs.md` quotes: 1158 1090 at a quarter to three, 1156 1099 at a quarter
  to one. `colony.md` and `needs.md` have them with the old figures beside them.
- `tools/reference_check.sh`, seven runs of 41 game days, each line for line against its log, all seven
  regenerated in 69ee631. Before the world changed, the quiver and the drawing of grass each left all seven
  matching as they were.
- The run with everything on gives the same state at two and at eight workers and in the debug build
  (ee6e59375a8b709a, two days), and the same through a save taken half a day in and loaded.
- What the looks cost (RX 6900 XT, 1280 x 720, the default view, GPU a frame, now against `main`):

  | view | before | after round one | now |
  |---|---|---|---|
  | open meadow | 1.30 ms | 1.66 ms | 1.71 ms |
  | looking down on the forest from 26 m | 0.38 ms | 0.45 ms | 0.46 ms |
  | the band at its camp by day | 1.48 ms | 1.96 ms | 2.05 ms |
  | the same at night, the fire casting | 0.93 ms | 1.35 ms | 1.45 ms |

  Quads resident over the view 3.71 million -> 4.26 -> 4.60. On the way: tufts drawn one by one, at the old
  30 % of the turf's columns, made it 4.81 million and 1.96 ms on the meadow; the round crowns 5.22 million
  and 2.03; standing the tall grass in drifts, half as many tufts, brought it back. Worker time to generate
  and mesh a stack is 6.3 ms, as it was.
- `tools/shadow_still.sh`: pixels stepping by more than 6 levels, 0.00 % at one game minute a second, at
  three, and at dusk.
- Trees (`./bin/flora_stats`, seed 1, three thousand of each kind or all there are): furthest reach 15
  blocks out and 16 above the trunk's top (the generator looks 20); no bark off the trunk under 1.75 m but
  an apple's (381 blocks on 258 apples, where it was 755); 94 branch blocks, over 3,000 broadleaves, lie
  where a neighbour's trunk stands (19 before), which felling leaves alone and the world never holds.

## Saves
`Generator_Version` 13: `Castle.Saves` refuses a save made by another ("... was made by another version of
the world generator; its edits would land on a different world"). By his rule nothing is done to carry an
old save over, here or from now on. The colony's blob is 17, from round one: the herds' blob version 2,
after version 1's content, whether the herds scatter as they were (a byte) and for every deer slot the
seconds left of its start (f32). The older blobs `colony_check` keeps (`tools/colony_v14.bin` to
`colony_v16.bin`) still load and still pass on the new world; the day one fails, the check and the blob go.

## Options
`--deer-scatter` (the herds as they were; saved with the colony). `colony_run --deer-track FILE`. In the
game: `--lineup-turn RAD`, `--lineup-does stand|walk|pick|put_down|chop|sneak|aim|eat|lie|stir|sit_eat`.
Nothing new in round two.

## Bugs found and fixed (mine, in this work, in no build John has had but the first three of round one)
Round two:
- A round crown stood against the sky like a veil: the sky showed through the painted gaps of its near side,
  because the far side's back is never drawn. The gaps are the crown's dark inside now.
- Wild grain drawn tuft by tuft was a field of yellow boxes with lids. Its top is ears now, two texels in
  five, and below its top block it is stalks.
- The first shapes put three and a half times as much bark within a serf's height round an apple tree as
  the old ones (boughs leaving the short trunk low), which would have closed the ground where a gatherer
  stands to pick. An apple's boughs leave from the top of its trunk now: half as much as the old.
- A bough crossed where a neighbour stands twelve times as often as before. Felling already left that
  block alone; but if the bough was drawn first the block was the wrong tree's bark in the neighbour's
  trunk. Every trunk is drawn before any bough now.
- A two-block trunk drawn one block wide in its crown would have let a neighbour's bough lie in the empty
  part, where felling protects it and nothing would ever take it out. Trunks are whole to the top.

Round one:
- A herd's node could end a flight standing in a quarter metre of water, and its deer, told to make for it,
  stood in the water with it. The node's way is cut back to its last dry turn now.
- A deer that had run onto a ledge, the only way off behind it, stood there for hours: it looked for a way
  only within a quarter turn of where it wanted to go. It turns on round until it finds one now.
- Calm deer could not follow a node whose dry way went round a pool: they made straight for it and stopped
  at the water. They take the node's way now (rule 6).
- A wade limit set for one plan would have got into the pieces of ground if a stack was first mapped during
  that plan, and serfs' routes would then have called fordable goals out of reach. The pieces are made with
  a step of their own (`Step_Free`). Found on reading, before any run showed it.
- The first soft foliage made two fifths more quads over the whole view.
- The bow across the back passed through a deer carried across the shoulders. It is let down under the load.
- With no multisampling the frayed corners of a crown would have thinned to nothing with distance (their
  coverage fell under the alpha test). Far off they are whole there now.

## Known limits
- Seen in stills and recordings only, like every look before it. Round two: each kind of tree from the
  meadow, from above and at the default view, in summer, autumn, winter, rain, at dusk and with `--msaa 0`;
  the meadow at ground level from the sunny and the shaded side, from 6 m, 18 m and the default view, under
  snow, in rain, dried in autumn; grain and wild vegetables close; the quiver from six sides standing,
  aiming and in winter dress, on a hunter walking out and coming home with a deer, and in seed 44's row.
  Round one: as its report said (the row of seven, the stalk, the draw and the stroke, a left-handed pair,
  the path and the camp's floor, one herd's flight).
- The herds were measured in the runner, which has no bodies. What the drawn deer do in a flight was looked
  at in the demo's recording, not measured.
- A crown that crosses the edge of a stack has an unsoftened line there: corners of the block grid on a
  stack's edge are not moved. On round crowns I could not find it in a still; it is there.
- Figures in the older documents that were measured on seed 1 and not made again on generator 13: when the
  reference path is laid (half past one, `colony.md`), the far path of `colony.md` ("Far ones"), the stone
  runs with `--stone-from 150`, the tuning runs of `needs.md` ("How it was tuned") and the route timings of
  `routes.md`. Each says when it was measured.
- The forester's axe still hangs straight down behind her when she sits, as in round one; only the quiver
  is swung up.
- Snow: the pale stipple on a snowed slope at the default view (dried grass on the steps' risers) is in the
  first round's build too; I compared a still of each.
- The quiver's arrows and the bow's lower limb overlap behind the hip when the bow is slung.
- A tuft's blades bend a little along the diagonal of each side (its top is drawn in, and a texel is laid
  on the side's two triangles one at a time).
- Wild vegetables are as they were from above: a rosette with the root's colour at its foot, which reads as
  orange flecks on the ground.
- The fringe's width is capped at a block: a wide worn verge is not possible this way.
- Deer cross no water deeper than a quarter metre (his call, above).
- Driven only by scripted starts; nothing of this work adds a click or a key.

## Not done
- Trunks drawn round; bushes reshaped; trees of other sizes or in other places; roots at a trunk's foot
  (bark near the ground changes where a serf can walk: it wants its own look at the walking map).
- Grass or leaves that sway; flowers.
- A hand that reaches for its tool or its quiver (left out on his word); tools for the gatherer, the porter
  and the cook.
- A fringe against sand and rock, or wider than a block.
- The herds as they were are still in the code behind `--deer-scatter`, as the other column of every
  measurement above. He has accepted the new herds, so they can go, with six of the seven reference logs'
  `--deer-scatter` ("What his acceptance covers", above): not done in closing.
- Deer extras that were already deferred (the tail's flag, lying down).

## Next
- **Stage 6, habitation, with stockpile mechanics rolled into it**, his to open in a new session: start
  from his words, then the stage brief from the framework's template. Branch from `main`. The pointers in
  Handoff_2026_11_11_hands_and_level.md ("Next") still stand. A new model for it (a hovel's parts, a
  builder's tools) is boxes with `Round` and `Taper`, and what a serf carries is a prop placed from its
  frames. Its saves need carry nothing over from today's (his rule): bump and refuse.
