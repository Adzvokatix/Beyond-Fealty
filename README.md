# Castle Game engine — world generation and the 3D view

Procedural voxel world for the castle colony game, in Ada 2022.
2048 m x 2048 m x 256 m, 0.25 m blocks.  Mountains peak around 160 m.

## The project

Castle Game is a colony game on a generated voxel world. The player says
where (a homestake, paths, stockpiles, a camp, reserves and protections);
the people decide what and when, feed themselves, and say why when they
can't. Today a band of thirteen arrives with the lord's cart, gathers,
fells, hunts, cooks, builds its hovels and lives through the seasons at a
camp, its stockpile ten metres square, placed once, its last ten places
kept for loads in hand; and, from the second morning, a storehouse raised
on a stockyard the player zones beside a path (its ground levelled, a
door in each end, its yard fenced with a gateway beside each end and
coverings along the back; beside a path at 45 degrees the yard is laid
out along the path, its storehouse drawn turned to lie along it), kept by
a stockman, its shelves and barrels
made by a carpenter, the stores moved into it when it stands. Its houses
have doors that open, trusses in their gables and tie beams under a full
thatch; its paths are levelled as they are laid; housing can be taken out
again, and a hovel nobody owns razed. Point at a person, a stockpile, the camp or a deer
and a tooltip says what it is and is doing, and a right click offers what
may be done with it. People have skills that grow with the work they do
(stage 5b). Housing, trades, an
economy and lordship are ahead (the phases are in the framework).

<img width="2560" height="1440" alt="swappy-20261121-220829" src="https://github.com/user-attachments/assets/c924f5e7-ac4f-4254-b100-02c070554c50" />
<img width="2560" height="1440" alt="swappy-20261121-220831" src="https://github.com/user-attachments/assets/974ff76c-03e9-4a88-ade3-5a4a18c88197" />
<img width="2560" height="1440" alt="swappy-20261121-221305" src="https://github.com/user-attachments/assets/cedb78ae-2130-458e-962a-924499d61704" />
<img width="2560" height="1440" alt="swappy-20261121-221607" src="https://github.com/user-attachments/assets/9feb4496-5076-4d64-98c4-369d191a0a9b" />
<img width="2560" height="1440" alt="swappy-20261121-221609" src="https://github.com/user-attachments/assets/a5d3e0d1-5632-4233-8d0e-3843706d467a" />


Where to read:

- `docs/production/Production_Framework.md`: what must stay true, the phases, how a stage is run.
- `docs/production/Production_plan.md`: which stage is live and what was deferred.
- `docs/handoffs/`: one note per session; the newest says what comes next.
- `CLAUDE.md`: the standing rules for work in this repo.
- `docs/systems/`: one README per system, as the code has it. This file keeps only what spans them.

| System | README | Packages (Castle.*) | Check |
|---|---|---|---|
| The world | `docs/systems/world.md` | Terrain, Geology, Deposits, Hydrology, Flora, Chunks, Worldgen, Maps | the preview's checksum; `flora_stats`, `terrain_stats`, `probe` measure |
| Climate | `docs/systems/climate.md` | Climate | `climate_year` prints a year |
| Rendering | `docs/systems/rendering.md` | Streaming, Mesher, Textures, Render, Camera, Colors, Currents, Lod, Far | `camera_check` (needs a window); `tools/shadow_still.sh` measures; `edit_check` has the far view's tiles and the far land |
| The interface | `docs/systems/interface.md` | Font, UI, HUD, Input, Views, Pick, Rays | `ui_check`, `pick_check` |
| Editing and saves | `docs/systems/edits_and_saves.md` | Edits, World_Blocks, Saves | `edit_check` |
| Live water | `docs/systems/water.md` | Water | `water_sim_check` |
| People | `docs/systems/people.md` | Bodies, Poses, Second_Order, Figures, Serfs, Props, Fire (the fire is in `rendering.md`, with its light) | `serf_check`, `dynamics_check` |
| Deer | `docs/systems/deer.md` | Deer, Animals, Herds | `deer_check` |
| Routes | `docs/systems/routes.md` | Nav, Marks | `path_check` |
| The colony | `docs/systems/colony.md` | Colony, Actions, Scenario | `colony_check`; `colony_run` on the real world |
| Food and needs | `docs/systems/needs.md` | Colony | `colony_check` |
| Habitation | `docs/systems/habitation.md` | Buildings, Colony (housing); Buildings.Layout and Iso for the older preview | `colony_check`, `pick_check`; `tools/reference_check.sh` (stage 6's log) |

A change in how a system behaves updates its README in the same commit.

## Build and run

Toolchain: GNAT (GCC 13 or newer) and gprbuild, or Alire (alire.toml untested).
On Ubuntu 24.04: `apt install gnat gprbuild libglfw3-dev libgl1-mesa-dev xvfb`.

```sh
gprbuild -P castle.gpr -XCASTLE_MODE=release -j0
./bin/worldgen_preview --seed 1 --out preview --workers 15 --samples 1024

# checked build: range, overflow and validity checks plus assertions,
# executables in bin/debug/ (the switch is CASTLE_MODE, not Mode)
gprbuild -P castle.gpr -XCASTLE_MODE=debug -j0
./bin/debug/water_sim_check && ./bin/debug/edit_check && ./bin/debug/ui_check \
  && ./bin/debug/dynamics_check && ./bin/debug/serf_check && ./bin/debug/path_check \
  && ./bin/debug/colony_check && ./bin/debug/deer_check && ./bin/debug/pick_check
```

Options: `--seed N`, `--out DIR`, `--workers N` (default: all CPUs),
`--samples N` (stacks in the storage/timing survey), `--no-maps`.

Mountain shape is two constants in `src/castle-terrain.ads`:
`Mountain_Relief_M` (160) and `Ridge_Scale_M` (420; wider is gentler).
Heights above `Knee_M` (168 m) are compressed smoothly toward
`Terrain_Cap_M` (208 m), so no summit is ever cut flat, and 48 m stay free
above the cap for trees and towers.  `./bin/terrain_stats [SEED ...]`
prints peaks, height percentiles and mountain slope percentiles (100 % is
45 degrees) for tuning them.  Changing either constant changes every
world; bump `Generator_Version` when you do.

## The game window

Needs GLFW 3 and an OpenGL 4.5+ driver (asks for 4.6 first).  On
Garuda/Arch: `sudo pacman -S glfw` (Mesa is already there).  GLFW 3.4 runs
natively on Wayland, so Sway is fine.

```sh
./bin/castle_game                       # seed 1, 160 m view, all CPUs but one
./bin/castle_game --seed 7 --at 900 1400 --view 240 --novsync
```

Options: `--seed N`, `--at X Y` (start focus, metres), `--view M` (stream
radius, metres), `--size W H`, `--float` (a window that can't be resized:
Sway and other tiling compositors float it at exactly `--size` instead of
tiling it; the app id is `castle` for window rules), `--workers N`,
`--novsync`, `--no-lod` (no far view: nothing drawn past the view and the haze whole at its edge, the picture as it was before the far view: `docs/systems/rendering.md`, "The far view"), and of the far view's parts `--no-far-shadows` (nothing past the view's edge casts or takes the sun's shadow), `--no-far-mirror` (far water mirrors the sky alone), `--no-ground-haze` (no haze on the ground and none at the map's rim), `--haze X` (the ground haze X times as thick), `--rim M` (the map's rim goes into the haze over M metres, 12 as built), `--no-floor` (holes in the land show the sky), `--no-low-horizon` (the sun and the moon cut off at eye level, not gone down behind the map's edge), `--no-round-boulders` (a boulder's edges and corners in steps), `--no-boulder-feet` (a boulder standing on the ground instead of spreading into it), `--no-whole-map` (a stack's blocks are dropped with its mesh, as before 2026-11-14: the game holds every stack's blocks and streams the meshes alone, `docs/systems/world.md`, "The whole map held"), `--msaa N`
(default 4, 0 to switch off),
`--cam YAW PITCH DIST`, `--clouds C` (force cloud cover 0-1), `--day D` (0-59) and `--time HOUR` (0-24) to start at,
`--timescale H` (game hours per real second, default 1/60: a game minute a
second), `--weather clear|cloudy|rain|snow|storm` and `--snow METRES` (force
what you see, not the climate), `--mist AMOUNT` and `--wet AMOUNT` (0-1: force how much mist lies and how wet the
ground is), `--moon PHASE` (0 new, 0.5 full: hold the moon there), `--nostars`, `--noshadows` (neither the sun's nor the fire's), `--noreflect` (water mirrors the sky alone, not the land),
`--flatclouds` (the clouds as one flat layer, not walked through), `--loadorder` (the land drawn in the order it was loaded, not nearest first), `--nomist`, `--nowet`, `--lights N` (N fires scattered
round the start, to see and to cost many lights), `--hitch MS` (a frame that takes the CPU longer says where the time went; at the end, how many stacks of the walking map were read whole and how many mended),
`--msaa N`, `--watersteps N` (open water drawn in steps of 1/N
block, default 8; 0 for one smooth sheet), `--nofalls` (falls drawn as they were: a curtain on the face, a film down a slope), `--throw S` (the share of
the lip's speed a fall's sheet leaves with), and for headless checks `--hold-wait` (a scripted run does not end before the whole map is held), `--far-wait` (nor before the far view is whole; a recording given it begins only then), `--settle N` (nor before N frames with nothing more coming in: their GPU and CPU times are said apart, and `tools/look_cost.sh` reads those), `--no-far-cull` (every face of a far tile sent), `--drawn-still` (drawn time holds still: clouds, ripples and flames do not move, so two builds' pictures of one view can be compared pixel by pixel; with `--workers 1 --timescale 0 --no-whole-map`, which make the stacks arrive in one order and stop the sun), `--mem` (what the process holds, at the end), `--save-at F PATH`, `--load-at F PATH` and `--probe-block X Y Z` (a save and a load at a frame after the view filled, and what block the simulation reads at a place at the end: the proofs of what is held), `--frames N --shot FILE.png`
(render until the view has streamed in, save, exit; a run with `--frames`
or `--record` takes no keyboard or mouse input, so its window can't be
steered by keys meant for another) with `--pan DX DY`
(glide the camera once the view is full, to exercise re-streaming; with `--pan-back`, back again once
the far view has filled: the way to see what a look kept by place does when the camera has been away).
`--pointer "FRAME:COMMAND, ..."` drives the cursor in such a run (move to a
pixel, follow a member or a deer, a point of the ground, click, right
click, wheel, Esc, take up a colony tool): `docs/systems/interface.md`, "A scripted pointer".

Saves and scripted edits: `--load FILE` starts from a save (the world is
made from the save's seed; the view is the save's unless `--at` or `--cam`
is given with it, which then stands), `--save FILE` writes one when
`--frames` or `--record` ends,
`--dig X0 Y0 Z0 X1 Y1 Z1` digs out a box (metres) before anything streams
in, `--late` makes that dig happen once the view has loaded instead (the
same path a click takes, rebuilds and all), and `--fill X0 Y0 Z0 X1 Y1 Z1`
fills a box with planks once loaded.  For example, a notch along the coal
vein next to the default view, saved and loaded back:

```sh
./bin/castle_game --at 1225 1094 --dig 1216 1086 1 1234 1108 80 --frames 3 --shot notch.png --save notch.castle
./bin/castle_game --load notch.castle
```

| Action | Keys and mouse |
|---|---|
| Pan | W A S D or arrow keys; middle-drag grabs the ground |
| Turn | Q / E; right-drag orbits |
| Tilt | R / F or Page Up / Page Down |
| Zoom | mouse wheel, + / - |
| Reset view | Home |
| Scrub hours | [ and ] |
| Scrub days | , and . |
| Point at a person, a zone, a deer | rest the cursor on it: a tooltip says what it is and is doing |
| What you may do with it | right click: a menu (a person's job, follow; a stockpile's reserves; the ground: path, stockpile, camp, housing along a path, housing inside the paths round it) |
| Dig | left click: the brush box round the block under the cursor (yellow outline) |
| Place | Ctrl + left click: fills the brush box in front of the face pointed at |
| Brush size | B: 25 cm, 1 m, 2 m |
| Material to place | M: plank, log, shingle, granite, dirt, sand, footpath |
| Quick save / load | F5 / F9 (`saves/quicksave.castle`) |
| Panels | F1 keys, F2 survey, F3 debug, F4 hide all |
| Interface smaller / larger | F10 / F11: a quarter of a step at a time, remembered in `saves/settings.txt` (`--uiscale 2.5` for one run) |
| Serfs' routes, the walking map, the aquifer | F6, F7, F8 |
| Houses opened (roof and near walls): where the camera and the pointer are, all of them, none | H |
| Pause, game speed | Space; 1, 2, 3 |
| The band | Tab: tabs for the Band (a scroll list), Stores, Camp, Orders |
| Colony tools | the Tools panel: Homestake (the square the colony is founded on, held and turned), then Path, Stockpile (a box with its path, held and turned), Housing and Stockyard; or the ground's menu |
| Z / X | turn what is held to be put down, an eighth of a turn |
| Screenshot | F12 (`screenshot.png`, interface included) |
| Cancel, then quit | Esc: closes a menu or ends a path line or housing half drawn, or puts away a box held to be put down; with nothing to cancel, quits |

Bindings live in `Castle.Input.Bindings`, one table, ready for the options
menu.

## Layout

```
src/castle-dims.ads        world dimensions
src/castle-hash.*          counter-based hashing (SplitMix64)
src/castle-noise.*         Perlin 2D/3D, fBm, ridged
src/castle-colors.ads      the palette: named hex codes, RGB
src/castle-blocks.ads      Material, Block (16 bit), Brick (32 bit), each material's palette colour
src/castle-fields.*        1 m and 4 m global fields, bilinear sampling
src/castle-maps.*          World record, deposit objects, spatial index
src/castle-jobs.*          Parallel_For over Ada tasks
src/castle-terrain.*       heightmap
src/castle-geology.*       skin and deep material, aquifer field, wells
src/castle-deposits.*      root-like veins, precious tips, bog iron
src/castle-hydrology.*     lakes, silting, meandering channels, water table
src/castle-flora.*         trees, bushes, boulders
src/castle-chunks.*        stack generation and two-level packing
src/castle-worldgen.*      the pipeline
src/castle-png.*           dependency-free PNG writer
src/castle-preview.*       maps, sections, survey
src/castle-buildings.*     the hovel (a timber frame filled with wattle and daub, thatched): its design from a seed, and its blueprint block by block in building order
src/castle-buildings-layout.*  the first layout of houses on the generated fields (village_preview's)
src/castle-iso.*           isometric voxel renderer for previews
src/castle-glfw.ads        thin GLFW binding (window, context, input)
src/castle-gl.ads          thin OpenGL 4.5 binding, linked directly to libGL
src/castle-platform.*      window and context creation (4.6, falls back to 4.5)
src/castle-input.*         named actions and key bindings
src/castle-settings.*      what the player has set that belongs to no game (the interface's scale), in saves/settings.txt
src/castle-math.*          matrices and frustum culling
src/castle-camera.*        orbit camera that rides the ground and keeps clear of it
src/castle-textures.*      5 x 5 procedural block textures
src/castle-mesher.*        greedy mesher, stack to packed quads; foliage's edges as soft quads, the fringe between turf and bare earth
src/castle-streaming.*     worker pool: generate and mesh stacks nearest-first (or a stack's blocks alone, for what is held and not drawn)
src/castle-far.*           the far land: the whole world as one coarse sheet, from the generator's map (out of the game since 2026-11-16, kept and still compiled: rendering.md, "The far land")
src/castle-lod.*           the far view: a tile of the world at coarser blocks, reduced from its stacks and meshed
src/castle-render.*        shaders, quad arena, culling, indirect draws, edit outline, figures
src/castle-edits.*         the player's edits: blocks and whole bricks, generations
src/castle-world_blocks.*  packed copies of loaded stacks: block lookups, ray picking, ground versions
src/castle-saves.*         save files
src/castle-water.*         live water: virtual pipes between stretches of columns, sleeping stacks; source water that
                           drops beside a cut and comes back to its level
src/castle-falls.*         falls as they are drawn: the sheet thrown from a lip, column by column, from the simulated flow
src/castle-font*.ad?       the UI pixel font: glyph table (generated) and atlas
src/castle-ui.*            the 2-D layer: text, panels, bars, buttons, tables, tabs, scroll lists, tooltips, popups; one draw call
src/castle-hud.*           the development panels (status, tools, ground, debug, survey, keys, the band's tabs),
                           and the tooltip and context menu on what the cursor points at
src/castle-second_order*   second-order dynamics (f, zeta, r) solved exactly over each frame;
                           instances for Float (_1) and Vec3 (_3)
src/castle-bodies.*        serf genome, skeleton, boxes on the 5 cm pixel grid (drawn rounded and tapered), mirrored painted skins, outfits
src/castle-poses.*         a pose to a frame per bone, two-bone IK
src/castle-figures.*       people for the renderer: looks (skins), bones and boxes each frame (all of which cast shadows),
                           the disc under each for where nothing casts one
src/castle-serfs.*         serfs on screen: lineup, walkers on routes, the stepper and their filters; the axe and the bow carried, stowed or in the hand
src/castle-nav.*           the walking map (0.5 m cells, a floor per level) and routes: travel-time A*, pulled straight
src/castle-marks.*         strips over the ground: routes, the walking map, the zones
src/castle-zone_marks.*    a zone's ground as marks: filled in, a line round its edge; a lot before it is taken
src/castle-colony.*        the colony: clock, band, jobs, homestake, paths, stockpiles, bushes, its save (state, helpers, stubs)
src/castle-colony-*.adb    its larger subprograms, one a file (subunits): think, go_*, step_*, save, load ...
src/castle-scenario.*      a colony set up from the command line, and its log lines: shared by the game and colony_run
src/castle-actions.*       the action table: what an actor may do to what, one door for every interface (Perform), menus
src/castle-views.*         data views: a person, a zone or a deer as a sheet of named lines, for panels and tooltips
src/castle-rays.*          a ray walked into the blocks (the loaded world's, or a check's)
src/castle-pick.*          what a ray points at: a person, a deer, a zone, else the block; reach
src/castle-cloth.*         cloth: a sheet of particles hung from points or laid over a body, stepped by drawn time (the cloaks)
src/castle-cutaway.*       roofs cleared on the camera's ray: which, how much, faded by drawn time (drawing and pointing only)
src/castle-props.*         things set down in the world, drawn as figures: basket, log, sheaf, stone, clod of earth, bucket, the camp's
src/castle-fire.*          a fire as it is seen: flames, sparks and smoke out of small pieces, and where its light comes from
src/castle-deer.*          deer: classes, boxes and painted coats on the fifteen bones, the four-legged pose
src/castle-animals.*       animals on screen: the gait-locked stepper, walk, trot and bound, grazing
src/castle-herds.*         herds: a node that grazes, travels and flees (in a chain, never where water blocks it), deer wandering round it and fleeing with it, out of water, fear (of one who walks, not of one who stands), fawns, saves
game/castle_game.adb       the game executable
tools/worldgen_preview.adb command-line driver
tools/probe.adb            point queries for debugging the generator
tools/village_preview.adb  the first habitation prototype: a village drawn from above (Castle.Buildings.Layout)
tools/terrain_stats.adb    heights, mountain slopes and cliff faces, for tuning the terrain
tools/colony_run.adb       the colony on the real world with no window, on fixed steps: gates, measurements, the reference run
                           (--nav-stats: what the colony's steps, the walking map and the routes cost;
                           --prove-dry: every dry way the pieces of ground call out of reach searched for whole)
tools/reference_run.sh     the reference run's command line
tools/reference_check.sh   the 41-day reference run eight ways (all of them a band of six on a stockpile of 10 m by 5 m with no overflow and no storehouse, as they were measured: --band 6 --stockpile-least 0 --no-overflow --last-places 0 --one-to-a-bush --no-storehouse in reference_run.sh, and --no-top-cut for the eighth; seven with --no-beds --pace 1: nothing else off; --deer-scatter; and with it --all-hands --no-level; --paths-built; --no-labour; --no-demand; --no-skills; and one with beds, housing, a porter, a second stockpile, the band's pace of today, the cook's hold, the lord's cart and ladders; the seven also with --no-cook-hold --no-curing), each its kept log, line for line
tools/demo_stage5a.sh, demo_stage5b.sh   the stage demos, recorded with a scripted pointer (need ffmpeg)
tools/demo_stage6.sh, demo_housing_pass.sh   stage 6a's, and the pass after it (housing pulled along a path and filled inside a round of paths, a path drawn on its ground, walled ground, roofs trimmed, the wall as one behind a row, beds on level ground across the way to the fire, cloaks, sleepers)
tools/flora_stats.adb      trees by kind, forest cover and density, lone trees, berry bushes, wild vegetables, tall grass, boulders by the mountain mask,
                           for tuning; draws three thousand trees of each kind alone and fails if one reaches past Tree_Reach
tools/climate_year.adb     a year of weather, snow, ice and mist, for tuning the climate
tools/camera_check.adb     pans the camera over the tallest mountain and reports jolts,
                           tilt and zoom swings and ground clipping (all should stay tiny)
tools/edit_check.adb       editing and saves end to end, without a window
tools/lod_stats.adb        what the far view costs: quads and worker time a tile at each level, and whole rings of them
tools/water_sim_check.adb  the water simulation on made-up ground: basin, dam, river, tunnel, save; source water opened,
                           closed, built in; a flow established
tools/demo_water.sh        records the water demo (a lake cut into and closed again, the tarn)
tools/demo_shadows_fire.sh records the shadows and fire demo (morning, afternoon, dusk into night at the camp, the fire close up)
tools/demo_camp_zones.sh   records the camp and zones demo (a stockpile along a path at an angle, the band building the camp, the fire dying down)
tools/demo_herd_chain.sh, demo_herds_still.sh   the herds: a flight going down a herd in a chain; one of the band left standing among a herd, which grazes on
tools/demo_paths_reach.sh  records the paths and reach demo (a path planned and laid by the band, one 150 m out, the band looking far for stone)
tools/demo_hands_level.sh  records the hands and levelling demo (two at a time laying a path a stretch each, a camp's floor levelled on a slope, earth heaped in the stockpile)
tools/shadow_still.sh      do the shadows hold still?  records a still view with the clock running and measures the change
tools/look_cost.sh         what a frame costs the GPU at twelve fixed views (the four every look is costed at, then sky, water and weather)
tools/stockyard_sites.sh   seventeen stockyards since 2026-11-22 (its own header says each; the first eleven:) eighteen days each (four of them with the storehouse of 12 m by 8 m, the rest with the storehouse of before, --storehouse 10 5 4.5: ground the larger one is refused on; five put down whole, twenty metres square with their path: --stockyard-box; all four hundred places, the storehouse fronting its own path; at every one the lord's cart brought before the storehouse and its salt carried in, and every block column the storehouse's own blocks stand in its stockyard's ground); the first six: three square to the grid (beside a path aslant up the reference hillside as it was found; the largest, 25 m a side, there; beside a path at 45 degrees on the flat with --no-yard-turn) and three laid out along a path at 45 degrees (on the flat; the least on ground that falls 3 m; the largest): fails if a storehouse does not stand or anyone starved, and for those along a path if any of the ground is off its level or anyone stood in a wall as the storehouse is drawn
tools/yard_corners.py      the two corners that zone a stockyard along a path at 45 degrees (for colony_run's --stockyard)
tools/turned_streets.sh    hovels turned to a path at 45 degrees, on the flat, on rising ground and up a steep hillside, eleven days each (every member's state printed each hour): fails if fewer than four stand, anyone died or was said to be starving (the empty bellies are counted and said), any ground a hovel is drawn on is off its level or grown over, anyone else stood on it for long, anyone was in a wall of one as it is drawn, or a bed is not got to by its door (NO_WALK=1: hovels walked as they stand, as before 2026-11-20)
tools/square_sites.sh      the square a colony is founded on, at real places: squares founded and made over a grid at ten places, their walls and stairs with them, and each scanned for pits and for a way to its fire (colony_run --square-scan), two of the places again with the paths laid last metre first and with the walls built when half the paths are laid (no square may stand otherwise); fourteen awkward sites twelve days each; a square saved half built (its floor, its walls) and run on from the save; a square founded round its tree; stockpiles with trees in them saved and run on: fails on a pit, a fire out of reach, anyone starved, a wall left unfinished, or a run that ends otherwise than the straight one (about four minutes)
tools/herd_places.sh       where herds are put down, at real places: a colony founded at each of 400 stakes and its two herds looked at (colony_run --herd-scan); none on a tree's trunk, none where a deer cannot walk off; and the same count with the rule off, which must still find some
tools/stress.sh            the stress test: years of the colony, a band of forty-eight, wide views, a long pan, the debug build
                           through a year (docs/production/Stress_test.md has what it found)
tools/demo_sky_weather.sh  records the sky and weather demo (clouds, a sunset, the moon, snow, rain and pools, mist, sixty-four lights)
tools/demo_moon.sh         records the moon and stars demo (stars turning, the full moon, a half moon, the afternoon moon, moonlit snow, the camp by moonlight)
tools/demo_falls.sh        records the falls demo (a lake cut onto a hillside and onto a cliff, each as it was drawn and as it is)
tools/frame_change.py      how much a recording changes from frame to frame (needs numpy and Pillow)
tools/ui_check.adb         the interface layer without a window
tools/dynamics_check.adb   the filters against theory: overshoot, stability, frame-rate independence
tools/serf_check.adb       serfs: 36,000 builds, symmetry, standing, IK, walking
tools/path_check.adb       routes on made-up ground with known answers; timing on seed 1
tools/colony_check.adb     the berry loop on a made-up meadow, through a save and back
tools/deer_check.adb       deer: builds, IK, the stepper's gaits (no sliding, footfall, frame-rate independence); on a made-up hillside and cliff, one piece
tools/pick_check.adb       pointing at things: the person in front of the zone in front of the block; walls, reach
tools/test_world.*         the made-up world path_check, colony_check and pick_check share
tools/colony_v7.bin, _v10 to _v16.bin   colony blobs of older formats, for colony_check to load
tools/water_probe.adb      generated water block by block round a point
tools/fall_find.adb        the biggest falls on seed 1
tools/font_glyphs.py       the font's glyph pictures; writes src/castle-font_data.ads
tools/water_check.adb      water over the whole map: water standing above dry ground,
                           steps in the flow, lake outflows, streams near lakes left unjoined
tools/today_run.sh, today_check.sh   the game as it is played (every rule at its default: a square, a stockpile, the stockyard, housing,
                           thirteen with jobs), 41 days against its kept log, line for line and to its state
tools/scratch_build.sh     the working copy built in another directory (nothing compiled or linked in the working copy)
tools/check_section.sh     one section of colony_check alone, cut out and built in a scratch copy
tools/belly.py, logsame.sh member-hours with an empty belly in a run's log; two runs' logs line for line across a blob bump
tools/gate.sh              the gate: a commit proved from a clean copy of it (both builds, the nine checks in debug, the reference
                           check, the three site scripts in both builds, the stress runner); three quarters of an hour
tools/mechanics_check.py   John's design document against itself and, through tools/mechanics_map.json, against the code's lists
tools/docs_check.py        every option, path and identifier the living documents name, looked for in the sources, and the other way
tools/switch_census.py     every switch: its default, its option, which part of the gate runs it which way (docs/systems/switches.md)
tools/unused_entities.py   what a specification declares and nothing uses, from the compiler's cross-references
tools/code_shape.py        where the code is long, where it repeats itself, the constructs worth a look
tools/gate_coverage.sh     what the gate never runs: its parts in a build that counts lines (tools/coverage_report.py reads it)
src/castle-climate.*       calendar, weather, snow and ice
```

```
docs/production/           State.md (where the project stands: one page), the framework, the plan, the restructure plan and its
                           inventory, the stage log, reference runs
docs/systems/              one README per system; switches.md lists every switch
docs/conventions/          what past sessions learned and John ruled, a file a part of the game (CLAUDE.md has the index)
docs/handoffs/             Handoff_YYYY_MM_DD_topic.md, one per session
docs/design/               detailed_mechanics.json (John's design of the colony, its people and its economy) and
                           Mechanics_crosswalk.md (it beside the build); the design report, the organized design, jobs, the
                           asset guide, the generation spec and the design conversations it was drawn from; the palette
                           (color_palette.txt is the source of every colour)
docs/reference/            REFERENCES.md (the papers, kept outside git in CASTLE_GAME/papers/), the .kkrieger notes
```

Outside the repo: `CASTLE_GAME/releases/` holds the stage zips and demo
videos, `CASTLE_GAME/papers/` the reference PDFs and video.
