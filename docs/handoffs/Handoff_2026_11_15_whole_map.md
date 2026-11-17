# Castle Game handoff (2026-11-15: the whole map held. The game keeps every stack's blocks and streams the meshes alone; the colony reads its own ground and nothing beyond; a far land tried, and set aside behind `--far`)

- **Accepted 2026-11-15 ("let's merge what we have now, let's keep the whole-map, we paid for
  it"): on `main`.** It was branch `whole-map`, from `main` at 52adac2 (ground-memory);
  `git checkout whole-map && git branch -f main 52adac2` puts `main` back where it was. **The far
  land is off unless asked for** (`--far`), by his word of the same day; the haze is what it was.
- Six commits of work: 401e4df (the colony reads its own ground and nothing beyond), 941dd16 (what
  the player plans is read from the ground that is held; the band's ground reaches a stockpile and
  the camp), c72dc45 (the game holds the whole map and streams the meshes alone), 6b13822 (the far
  land), def2910 (the far sheet laid under the land), 7c567af (the far land off unless asked for).
- Checks, from a clean copy (`git archive`) built from nothing, on 401e4df, 941dd16, c72dc45 and
  7c567af (which holds the two far-land commits): both builds with the six known warnings only; all
  nine checks in debug (path_check 69 -> 70, colony_check 635 -> 638 -> 643, edit_check 32 -> 36;
  the rest as they were); `tools/reference_check.sh` eight logs line for line, **none recorded
  again**; `tools/stress.sh runner` "nothing died, nothing dropped", with one new line
  (`crowd_whole_map`: the crowd's sixty days with every stack of the world in end in the state they
  end in on the colony's own ground); the stress runner's three states are those of `main`
  (crowd_at_work 7c212dc927735695, crowd_as_it_is a2f49f53239ef741, housing 3796cb59384abfa4); the
  flora's hash the same in both builds.
- Versions: generator 14, save format 6, colony blob 25, the herds' blob 2: as they were. Nothing
  of what is held, of the colony's own ground or of the far land is saved.
- Driven only by script: a load in the middle of a game (`--load-at`, standing in for the quick-load
  key), a dig and a pan (`--late --dig`, `--pan`). Nothing of the interface or the pointer is
  touched.
- **Test windows of mine on his desktop**, every one opened after looking that his own game was not
  running: some two hundred and fifty scripted runs in all. Most are the look-cost script's twelve
  views of 2,500 frames, run nine times (three builds, three rounds); the rest are the band with the
  camera panned 520 m off and back (six), the whole map's coming-in timed (about a dozen), a lake
  let out through a cut (eight), the demo walkers and deer (four), stills and recordings of the far
  land (about sixty), still views recorded to compare pictures pixel by pixel (about thirty), the
  shadows' stillness (seven), and the debug build (five). Nothing was built in the working copy
  while his game ran.
- Zip: CASTLE_GAME/releases/castle_game_whole_map.zip (a `git archive` of `main` at the merge).
  Pictures: CASTLE_GAME/releases/far_land_before_after.png (four views without and with `--far`)
  and far_land_pan.mp4 (a low pan with `--far`): of the far land he set aside, kept for the
  sidetrack that follows.

## John's words

2026-11-14, with the counts of what the ground costs before him. Whole:

"one question, what would it cost to cover the entire world with one mesh and draw locally over it,
like a dark grey, if we load the whole map, then far mountains need a texture, they don't need
detail, but something has to be there?"

"ok build it with the whole map solid we can do that now before the stockpile"

2026-11-15, having tried the build (the first sent while I was closing; the second after it):

"Ok, getting I am getting a bit sidetracked, we got what we came for, the whole map is loaded, let's
bring back the haze, --no-far the default, I don't want to rework the entire rendering pipeline right
now, we can sort that out later if we want to, so let's stick with that, wrap-up and get to
stockpiles"

"ok, well the LOD levels pop, so we have to fix that, let's do this, if we are going to rework
rendering let's go all the way, let's figure out how to get everything in view, so, my plan, open for
input, let's merge what we have now, let's keep the whole-map, we paid for it, --no-far is the defualt
for now, far is ugly with the flat terrain and popping assets, the fog works better in that state.
Let's sidetrack, and try and solve this to the full extent that we can, mipmaps, quadtree/clipmap
terrain LODs with geomorphing, LOD trees, imposters we half to, let's try tilt-shift with a hybrid,
load imposters outside the camera view, blur them, tilt shift the scene, serfs don't care if the tree
is rendered or an imposter, or two pass hi-z occlusion culling, warp the field of view to extend far
terrain and compensate for close terrain and objects, so we can pull more in but at the same time put
more at lower levels of detail, 64-bit programmable vertex pulling, fustrum culling before draw
submissions, zbuffer optimization, back-face chunk / normal-cone culling, voxel distance LODs, vertex
and quad data compression, spacial partioning and meshlets, progressive ring LODs for terrain stacks,
CPU compute frustum, ditherd cross-fade, stochaic alpha-to-coverage screen-door dither, hysteresis and
screen-space pixel size thresholds. I don't know what combination of those works or not, and what we
can use for our project so consider them, and let's see if we cannot crack this. That is all I got
from my research."

Read so: the second message stands over the first where they differ. Merge the branch; the whole map
held stays; the far land off by default and the haze as it was; then, before the stockpile, a
sidetrack of its own: how to get everything in view, the techniques he lists to be weighed against
this renderer by measurement.

## Measured before anything was built

The runner with every stack of the world in (`colony_run --ground-stacks 400 --no-mesh
--nav-stats`), the reference band's 41 days: **85.3 s where they take 5.5.** The walking map read
57,946 stacks whole; plans looked at 135.9 million floors (885,601 as a rule); the slowest plan took
3.8 s; 450 plans ran out of budget. With nothing unloaded to stop it, a goal out of reach was looked
for over all the ground there was: what was loaded had bounded everything. So the colony's own ground
came first.

## As built

**The colony's own ground** (`docs/systems/colony.md`, the section of that name).
`Castle.Colony.Set_Ground_Stacks (N)`: the host says which stacks are the colony's (within N of the
stake's, counted stack to stack), and the band reads nothing beyond them, whatever else is loaded: one
function asks whether a stack is in (`Own_V`), and the band's routes keep to it
(`Castle.Nav.Within_Stacks`, a region counted in stacks), as do the herds as they were. N is the
runner's rule since it was written (the reach in stacks and five more, never fewer than were in); the
game keeps the same now (it kept three more than the reach, and the colony read whatever else the
camera had loaded). What the player plans is not the band's doing and is read from all the ground that
is held (a path's line shown and counted, the ground inside a round of paths). The band's reach covers
a stockpile and the camp as it covers housing (`Stores_Far`, up to 256 m).

**The whole map held** (`docs/systems/world.md`, the section of that name). The game keeps every
stack's blocks and ground summary from soon after it starts and streams the meshes alone: a stack out
of view is asked for without a mesh (`Castle.Streaming.Request (..., Mesh => False)`: 1.4 ms of a
worker for 9), in rings round the first view, 256 out at a time, behind all the view asks; the main
thread keeps them for half a millisecond of a frame at most. A stack leaving the view gives up its mesh
and keeps its blocks. What is held and not drawn is made again when its edits have moved (a load, a dig
across its edge). `--no-whole-map` is the old way. `Castle.Streaming`'s two silent limits are gone (it
dropped jobs past 32,768 queued and results past 8,192 waiting: the runner's "crawl" when asked for
every stack at once).

**The far land** (`docs/systems/rendering.md`, the section of that name; off unless `--far`). The
whole world as one coarse sheet from the generator's map (`Castle.Far`: a corner every 4 m, laid under
the land as it was made; a cell coloured by its ground or the tree on it), drawn under the world and
seen wherever no stack's mesh is; the haze thinner at the view's edge with it. He tried it and set it
aside: flat, and things pop where a mesh takes over from the sheet.

## Measured, as built

| | the old way | the whole map held |
|---|---|---|
| the game holds, default view, no band | 548 MB | 1,526 to 1,533 MB |
| with the reference band, panned 520 m off and back | 609 MB | 1,582 MB |
| the view filled | 0.49 s | 0.47 s |
| the whole map held | never | 12.1 s after the first frame (31 workers) |
| the main thread's work a frame, over the first fifteen seconds | 0.12 ms | 0.93 to 1.00 ms |
| its longest frame after the view filled, no band | 0.4 to 0.8 ms | 4.9 to 5.2 ms |

About 0.98 GB more, 1.5 to 1.6 GB in all: under his ceiling of 4 GB. Once the map is held a frame
costs what `main`'s does (0.50 for 0.50, 0.84 for 0.85, 1.28 for 1.29 ms of GPU at three of the fixed
views). A pan of 520 m with a band at work has the same long frames both ways (10 to 14 ms: the view's
own meshes).

The runner: the band's 41 days, the housing band's and the crowd's sixty (with needs and without), on
the colony's own ground and with every stack of the world in, end in the same states in the same time
(5.7 and 5.8 s for the band's).

The far land, with `--far`: 0.00 to 0.07 ms of GPU a frame at the twelve fixed views; 3 MB.

## Proved

- The eight reference logs line for line with none recorded again, on every commit; the stress
  runner's states those of `main`.
- `path_check`: a region counted in stacks does what one counted in metres does. `colony_check`: told
  its ground is two stacks, the colony knows of no bush five stacks off on loaded ground and nobody
  goes; a path over bare rock past the band's ground is refused, one on turf is shown and counted by
  its ground, housing inside a round of paths out there is taken, and a stockpile zoned past the work
  radius is the band's ground from then on. Each fails with its read put back.
- In the game, scripted (`--save-at`, `--load-at`, `--probe-block`, `--hold-wait`, `--mem`): a hole
  dug and left 520 m behind reads as dug where it is held and not drawn; a save from before the dig
  loaded while the camera is away, and it reads earth again (a stale hole with the asking-again taken
  out); the debug build through both, and through a lake let out, panned away from and back to; 65,536
  of 65,536 stacks held, no job lost.
- The reference band in the game with the camera panned 520 m off: it gathers and hunts through three
  game hours as it does with the camera on it.
- Released water: a lake let out with a view of 16 m piled 194 m3 against the edge of the loaded
  ground the old way; held, it does what it does at any view (28.6 m3).
- The picture: without `--far` and with `--no-whole-map` it is `main`'s to the pixel (two still
  views, 0 of 518,400 differ). With the whole map held it differs in some 870 scattered pixels, and
  `main` differs from itself by the same pixels when the processors are busy in its first seconds
  (run beside 28 busy processes): the game's own dependence on how long its first frames take, older
  than this, not looked into.
- `edit_check`: the far sheet is under every one of 957,440 block columns of 3,740 dry cells, by
  0.31 m at the least; broken, it fails.

## His calls, and what he said of each

1. The haze changed with the far land. **His: "let's bring back the haze".** Done: the far land is
   off unless asked for, and without it the haze is the old line to the pixel.
2. The far land shows the world as it was made, flat. **His: "far is ugly with the flat terrain and
   popping assets, the fog works better in that state".** Off unless asked for; what replaces it is
   the sidetrack.
3. The colony reads only its own ground, and in the game that ground is two stacks wider than it was
   (13 for 11). Not spoken of: stands as built.
4. A stockpile or the camp zoned past the work radius widens the band's ground. Not spoken of: stands
   as built.
5. Released water runs as it does at a wide view, whatever the view. Not spoken of: stands as built.

## Known limits

- The colony's own ground is still meshed while out of view (a rebuild of an edited stack there costs
  a mesh nobody sees).
- A held stack coming into view is made again from the generator, not meshed from what is held.
- On a machine with few processors the map takes longer to come in (64 thousand stacks at 1.4 ms,
  over the workers); the main thread's share a frame is the same. Not run on such a machine.
- A stockpile or the camp further than 256 m from the stake is still not served.
- The far land, with `--far`: flat; shows nothing dug, laid or built; the hand-over at the view's edge
  shows and things pop there; a few white slivers at brooks for a frame or two in a fast pan (cause
  not found); the far plane cuts it at 1,600 m.

## Next

**A sidetrack, by his word, before the stockpile: how to get everything in view** (his list of
techniques above; "consider them, and let's see if we cannot crack this"; "my plan, open for input").
On a branch of its own from `main`. Measure first (what the whole map costs to draw at each level of
detail, in quads, time and memory), weigh his list against this renderer by those counts, build behind
a switch, and put the calls to him. What the far land taught: the sheet's cost is nothing; what was
wrong with it is that it is not the world (flat, no trees, nothing built) and that the step from it to
a stack's mesh is a step from nothing to everything.

**Then the stockpile, his to open.** He has said one thing of it (a portion reserved for overflow);
four things were asked of him with the herds' merge and are still open (`Handoff_2026_11_13_herds_search.md`,
"Next"; `docs/production/briefs/Stage_6_brief.md`).
