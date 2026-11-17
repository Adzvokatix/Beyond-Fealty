# Castle Game handoff (2026-11-15: the far view. Everything in view: the world itself at coarser blocks, in rings to the map's edge, cross-faded; his list of techniques weighed)

- **Built on branch `far-view` from `main` at eb507d4 (the whole map held); put to John; NOT MERGED.**
  `git checkout main` is the game without it. On the branch the far view is on unless `--no-lod`,
  which is `main`'s picture to the pixel.
- Two commits of work: 7897ef5 (the measuring tool and `Castle.Lod`: measured before anything was
  drawn) and 0d9338d (the far view drawn); what follows them is documents.
- Checks, from a clean copy (`git archive`) built from nothing, on 0d9338d: both builds with the six
  known warnings only; all nine checks in debug (edit_check 36 -> 41; the rest as they were:
  path_check 70, colony_check 643); `tools/reference_check.sh` eight logs line for line, none recorded
  again; `tools/stress.sh runner` "nothing died, nothing dropped", its states those of `main`
  (crowd_at_work and crowd_whole_map 7c212dc927735695, crowd_as_it_is a2f49f53239ef741,
  housing_2_workers 3796cb59384abfa4); the flora's hash the same in both builds. 7897ef5 by itself
  was not gated (nothing ran its code but its own tool).
- Versions: generator 14, save format 6, colony blob 25, the herds' blob 2: as they were. Nothing of
  the far view is saved, and the colony knows nothing of it.
- Driven only by script. Nothing of the interface or the pointer is touched.
- **Test windows of mine on his desktop**, each opened after looking that his own game was not
  running: about two hundred and forty scripted runs (the look-cost script's twelve views eleven
  times over and single views of it some forty times; stills; six recordings of 150 to 200 frames;
  the shadows' stillness seven times; the debug build three times). **One of them stood open for ten minutes**: a run I had started without
  `--frames`, which never ends by itself; I stopped it by its task when the command timed out.
- Zip: CASTLE_GAME/releases/castle_game_far_view.zip (a `git archive` of the branch).
- Pictures: CASTLE_GAME/releases/far_view_before_after.png (four views, `--no-lod` beside the far
  view) and far_view_pan.mp4 (a pan with the far view on).

## John's words

2026-11-15, having tried the whole map with the far land (the message is whole in
`Handoff_2026_11_15_whole_map.md`; what of it opens this work):

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

## Measured before anything was drawn

`./bin/lod_stats` (kept), seed 1, tiles taken evenly over the map:

| level | a cell | a tile | quads a tile | a worker makes one in |
|---|---|---|---|---|
| 1 | 0.5 m | 16 m (4 stacks) | 2,086 | 4 ms |
| 2 | 1 m | 32 m (16) | 2,177 | 14 ms |
| 3 | 2 m | 64 m (64) | 2,148 | 56 ms |
| 4 | 4 m | 128 m (256) | 1,412 | 223 ms |

A stack at full detail is 3,800 quads. The whole world in rings about the reference stake (the stacks
to 160 m, each level to twice as far): 6.1 million quads, 47 MB, beside the view's own 4.7 million.
So the whole map as blocks, to its edge, is a little over twice what is drawn today, and it is nearly
all worker time generating stacks (0.75 ms each), not meshing.

## His list, item by item

What is in use already, what was built, what fits later, what I would not do, and why. Where a figure
stands beside an item it was measured; where none does it is my reading of this renderer.

| his item | here |
|---|---|
| voxel distance LODs; progressive ring LODs for terrain stacks | **Built: the core.** The world's own blocks at 0.5, 1, 2 and 4 m, in rings that double. |
| quadtree / clipmap terrain LODs | **Built, as the rings' grid**: each level's tiles are the four of the level below. |
| geomorphing | Not built: it moves a smooth surface's vertices between levels; a block has no in-between. The cross-fade does its job. |
| dithered cross-fade | **Built**: over the last 0.15 of a doubling of distance both levels are drawn, each pixel taking one by a fixed pattern; and a tile coming in takes its pixels over twenty frames. |
| hysteresis; screen-space pixel size thresholds | **Built**: a tile is asked for a little before it shows and kept a little after; doubling the cell with the distance holds a cell at 1.2 to 2.3 pixels (720 lines). The rings go by the focus, not by pixels from the eye: his call 3. |
| 64-bit programmable vertex pulling | **In use since the start** (a quad is 8 bytes, pulled in the vertex shader). The far tiles ride on it: a scale to each draw was all it took. |
| frustum culling before draw submissions; CPU compute frustum | **In use** (every stack's box against the view, on the CPU), now the tiles' too. |
| back-face chunk / normal-cone culling | **Built for the far tiles** (a tile's quads come face by face; those that look away from the eye are not sent: about half). It saves 0.00 to 0.06 ms: the cost is not in the vertices. Not done for the stacks themselves (the sun's maps draw them from another side). |
| mipmaps | **In use in effect**: the block textures have three hand-made levels and the shader goes from texel to average by the pixel's size; a far cell shows its material's average. |
| vertex and quad data compression | Nothing to gain now: 8 bytes a quad; the far view is 62 MB of a 256 MB buffer. |
| LOD trees | **They are the trees themselves, reduced**: a crown of cells, its trunk kept (the rule for thin things). No second model of a tree. |
| imposters | Not built, and not needed so far: a far tile is 1,400 to 2,100 quads whole. A flat picture of a tree must be baked for every kind, season and light, and does worst seen from above, which is this camera. Worth another look for the on-foot view. |
| tilt-shift, blur | Not built: a pass over the finished picture, blurring by depth. It suits the diorama grade and would hide far cells further; it is a look, so his call. |
| two-pass Hi-Z occlusion culling | Not built: from above little hides little (at the default view 94 far tiles are drawn, at the lake 916), and the cost is in fragments, which depth testing already skips. For the on-foot view, where hills hide whole valleys, it earns its keep. |
| z-buffer optimization | Not needed yet: the far plane went from 1,600 to 4,800 m on the same 24-bit buffer (precision goes by the near plane); nothing flickers in the stills. Reversed depth is the mend if it shows; it touches every depth test. |
| spatial partitioning and meshlets | The stacks and tiles are the partition (8 to 128 m). Meshlets answer a cost in vertices, which is not where this one is. |
| stochastic alpha-to-coverage screen-door dither | The cross-fade is a screen door by the pixel. Through alpha-to-coverage two levels' shares do not fit each other exactly (gaps and overlaps); not done. |
| warp the field of view | **I would not**: it bends straight block edges, and the pointer's ray, the sun's maps and the water's mirror all take a plain projection. The rings already put more in at lower detail. |
| "serfs don't care if the tree is rendered or an imposter" | Held to: the far view is drawing only; the colony reads its blocks and nothing of a run moves. |

## As built

`docs/systems/rendering.md`, "The far view", has it whole. In short: `Castle.Lod` makes a tile from
the very stacks the game makes (edits laid on), reduced by halves and meshed into the mesher's own
quads; the workers make tiles after all the view asks; the renderer draws them with the land's shader
at 2^level times the size; a fragment shows the level whose ring it is in, or the finest coarser one
loaded there; rings cross-fade by a fixed pattern; tiles coming in fade in; a tile edited is made
again; the haze begins at the view's edge and is whole at 3,600 m.

## Measured, as built

- **Cost a frame** (twelve views, 2,500 frames each after all is in; 1,280 x 720, multisampled):
  looking down +0.13 to +0.16 ms; close and steep +0.00; toward the horizon +0.39 to +0.50; the lake,
  looking across at the mountains, +1.06 (1.92 for 0.86). Without multisampling the lake's is +0.52:
  the cost is fragments. `--no-lod` costs what `main` does.
- **Memory**: 8.1 million quads, 62 MB of the 256 MB quad buffer; the process 22 MB more (1,510 MB).
  At `--view 240`, 15 million (180 MB of the buffer with the view's own).
- **Coming in**: whole 6.6 s after the first frame on 31 workers (the map held at 18.3 s, 12.0 without
  the far view); on three workers 46.6 s (the map 67.6 s, 23.8 without). 193 s of worker time.
- **Stillness**: once whole, a still view steps as `main`'s does (0.01 % of pixels by more than 6
  levels); from the first frame of a run, at most 0.23 % after the thirteenth frame.
- **A pan of 370 m and back** (no band; one run each way): 23 frames over 4 ms with the far view, 35
  without; the longest 13 ms and 19. No more long frames for it.
- **`--no-lod`** is `main`'s picture to the pixel (two still views, `--no-whole-map` both sides).

## Proved

- `edit_check` 41: the reduction's rules; a made-up tile meshed (level ground is one quad and four
  skirts; a pillar; water; lower ground beside it); a tile of the world at each level made twice the
  same with every quad inside it; a pit dug in the world is in its tile at every level and gone when
  the edits are. Broken three ways (ties to nothing, no skirt, edits not laid on), it fails each.
- In the game: a pit of 36 m dug, the camera taken 420 m off and high: the pit is in the picture.
- The debug build: a band at work with the camera panned 520 m off and back; a dig and a pan: nothing
  raised.

## His calls

1. **The haze.** With the far view there is none within the view and it is whole at 3,600 m; it was
   whole at the view's edge. It is the look he had said works better, changed again: his to set
   (`Far_Haze_M`).
2. **How far each level lasts.** A cell is 1.2 to 2.3 pixels at 720 lines (1.8 to 3.5 at 1,080).
   Coarser sooner is cheaper and blockier (the rings' ratio is one number).
3. **The rings go by the focus.** Pulled far back and low, the ground by the eye is cells of 1 or 2 m.
   Going by the eye as well means tiles streaming as the camera turns.
4. **No sun's shadows past the view's edge**, as nothing was there before; the corner occlusion shades.
5. **Far water mirrors the sky alone.**
6. **Grass, grain and wild vegetables end at the view's edge**; trunks and walls are kept as thick as
   their cells.
7. **Whether it is on by default**, and whether it is merged.
8. **The far land (`--far`)**: superseded; out, or kept?
9. **What next of his list**, if any: a cheaper shader for the far levels (my estimate: half the
   far view's cost); tilt-shift; the rings by the eye; the tiles made in the pass that holds the map.

## Known limits

- A stack's own mesh that comes late does not fade in as a tile does.
- An edit shows far off 2 to 16 s after; live water not at all.
- The quad buffer: `--view 240` fits (180 MB of 256); wider than about 280 m does not, and a tile that
  does not fit is not drawn (said once on the error stream).
- On few processors the far view is slow to come in (47 s on three workers), coarse first.
- At the very start, for a second, the stand-ins are cells of 4 m inside the view itself.
- Not run: on another GPU; with a wide view and a colony's lights; the on-foot view (there is none).

## Next

His answer to the calls. Then, by his word, the stockpile (his to open; the four questions with
defaults are in `Handoff_2026_11_13_herds_search.md`, "Next", and still open).
