# Castle Game production plan (agreed 2026-11-07; stages 0 to 4, 4R, 5a, 5b and 5c done; the water and its look, shadows and the fire, zones, the fire's life and the camp built, and the last pass on models, trees and grass, then the sky and the weather's look, a stress test, the pathing work and falls thrown from the lip, done between 5c and 6 and all accepted; stage 6 opened by John 2026-11-11 and in two parts: 6a habitation built and accepted 2026-11-12, on `main`; then, asked by him in the same message, a pass on building and zoning (retaining walls and stone stairs, roofs smoothed by their builders, housing zones pulled along a path and combined); after it, in his order, sleeping and beds (the campfire to the house) and then the stockpile, neither designed: start from the newest file in docs/handoffs/)

Principle: build the colony "spine" once (state, clock, items, jobs, stockpile, saves), then add each
resource as a new job + its work animation on a loop that already runs, saves and is tested. Each stage
ends with a headless check tool, a demo video, README and zip.

John's loop: paths -> stockpile (and later habitation) zones along them create the demand -> job
designation creates the means -> the search for resources (wood, water, stone, grass/straw, food, hide).

## Stage 0: aquifer layer (DONE)
- Aquifer blocks removed from generation (Generator_Version 9; older saves are refused): wet rock is its
  own rock. The aquifer stays a field (Well_Info, shoring by water table). F8 / --wellmap draws the
  aquifer heat map on the marks layer. The freed Material slot became Bare_Bush (32-bit material masks).

## Stage 1: the spine, berries start to finish (DONE)
- Castle.Colony: fixed clock (20 ticks per colony second; game passes frame time x speed; pause, 1x, 2x,
  3x on Space / 1 2 3 and the status panel). One step drives the sky clock, the colony and the serfs
  (a 30th of a second per frame in --record).
- Homestake: Tools panel -> Homestake -> click. A 1.75 m post; a band of 6 (one elder), unassigned.
  The stake's priority gradient: a gatherer takes the ripe bush with the lowest
  (distance to it + 0.5 x distance to the stake), within 60 m of the stake.
- Paths: click along; each click lays 1 m of footpath from the last (grass/grain cut); right click ends.
- Stockpiles: two corners; 1 m cells; must come within 1 m of a path; grass/grain on the cells cut (so the
  baskets can be seen); cells with a bush, log, stone, or > 0.5 m off level left out. A cell holds one
  kind (120 handfuls of berries).
- Items: Item_Kind (Berries live; Wood, Stone, Water, Straw, Meat, Hide declared, with carry and cell
  limits). Berries in handfuls; a basket holds 30.
- Job loop: think -> reserve (bush, cell room) -> route (Castle.Nav) -> pick (a handful per 1.5 s, the
  ripe block nearest the hands turns Bare_Bush via the edit path) -> carry -> put down at the cell's edge.
  Fail memo: an unreachable bush or cell is left alone 60 s. Reasons shown: nothing ripe in reach,
  nowhere to put berries, can't get there.
- Bushes: union-find over the berry-bush blocks of each stack, merged across stack edges; a few stacks
  indexed per step, nearest first. Regrow after 6 game days, never in winter.
- Band panel (Tab): name (click to follow), Idle / Gath / Wood / Hunt / Port, status line, stockpile total.
- The colony's ground (stacks within 80 m of the stake) stays loaded wherever the camera goes; the colony
  waits while any of it is still streaming in (after a load), so nothing is misread for want of blocks.
- Saves: format 5 carries a colony blob (members, jobs, loads, reservations, routes, fail memo); a load
  resumes exactly (colony_check: save -> load -> save is byte-identical, and 400 s later the colony is
  where it would have been). The game logs one "colony:" line at every save and load.
- Drawn: serfs picking (hands circling at the bush, facing it) and putting down (bend and reach),
  baskets on stockpile cells (one per 30 handfuls, up to 4 a cell), stockpile outlines, F6 routes.
- colony_check (debug, ~1 min): all pass, including zoning on long grass.
- Held back on purpose (agreed): hunger, the player's own character, standing orders.
- Known limits: work only within 60 m of the stake; serfs work through the night (sleep comes with
  needs); one item kind per cell; no items lying loose on the ground; no carrying animation beyond the
  basket on the hip.

## Stage 2: forester and porter (DONE 2026-11-08, in the terminal; see docs/handoffs/Handoff_2026_11_08_stage_2.md)
- Forester: the nearest standing tree (stake gradient as for bushes), chopped two-handed (12 s slim,
  24 s thick); the tree comes down through the edit path (every block the generator gave it above a
  one-block stump; roots stay), its logs (1-8, a metre each) lying past the stump. The forester carries
  every log of that tree home on its shoulder before felling the next; the pile is its own.
- Porters never carry wood. They fetch straw first (tall grass, for the thatch) up to a reserve, then
  stone on demand (prised off boulders above the grass only; a starting quota of 20 for paving).
- Water: not fetched until there is a use and barrels (agreed 2026-11-08).
- Standing orders: spare apple trees (on by default), wood reserve (no limit by default), straw reserve.
- Changed from the first draft by agreement (2026-11-08): no "idle hands haul"; no porter log hauling;
  stone on demand rather than a reserve; water deferred.

## Stage 3: deer and the hunter (DONE 2026-11-08, in the terminal; see docs/handoffs/Handoff_2026_11_08_stage_3.md)
- Deer: fawn, doe, young stag, stag, in summer and winter coats, boxes on the serfs' fifteen bones put to
  a four-legged use, with their own pose solver. Castle.Animals is a four-legged stepper locked to the
  gait's phase (walk, trot, bound); hooves never slide. deer_check covers it.
- Herds (John's design): each herd has a node that grazes, plans the routes and decides the direction of
  travel; the deer wander round it on spots of their own. Someone near, or an arrow, makes the node flee
  and the deer scatter; when the panic wears off they regroup round the node. Fawns each spring; deer
  grow up by age.
- Hunter: a short bow (the starting weapon; the sling is dropped). It stalks crouched to within 18 m,
  shoots with a clear line (arrows drawn in flight), carries the kill home across its shoulders and
  butchers it at the stockpile into meat and a hide. It hunts only while meat is short of its reserve
  (20), never a herd of three or fewer, and not at all with Spare deer on.
- Changed from the draft: one look per class and coat instead of a genome per deer; the "don't hunt"
  order is Spare deer, with a meat reserve beside it; arrows aren't saved (the hit is decided as it is
  loosed).
- Demo: colony_stage3_hunt.mp4 (one hunter: stalk, shot, carry, butchering).

## Stage 4: food and needs (DONE 2026-11-09, in the terminal; see docs/handoffs/Handoff_2026_11_09_stage_4_camp_and_food.md)
- Built: hunger and sleep; the camp zone with fire, pot and seats; the cook (chooses itself); stew over raw
  food; wild vegetables (new flora), apples, grain with the straw; fending for oneself, confidence, death
  by hunger in winter; the winter store order, the fire kept in all winter, cold nights; deer wander in.
- Open: winter balance (the standard band starves late in the first winter on seed 1), theft, spoilage,
  leaving when confidence is low. Demo: colony_stage4_camp.mp4.
- The plan as written was:
- Hunger and eating from the stockpile (the stockpile gets a consumer: tune "2-3 foragers feed 6");
  sleep; campfire, best cook cooks; wild grain, wild vegetables (new flora), apples in autumn; first winter.

## Stage 4R: the runner (DONE 2026-11-09)
- colony_run: the real world and the colony with no window, on fixed steps, so phase gates and measurements
  repeat exactly and a game year takes seconds. The colony's scripted options, setup and log lines move
  into a package the game and the runner share (Castle.Scenario).
- Result: 41 game days in 11 s; same state hash with any worker count, in debug and release; --save makes a
  save the game opens; --expect HASH makes a run a test. Not in it: live water. tools/reference_run.sh is
  the reference run; reference_run_stage4.txt its log from summer through the first winter.

## Stage 5a: the scaffold (DONE 2026-11-10; see docs/handoffs/Handoff_2026_11_10_stage_5a_scaffold.md)
- The brief (docs/production/briefs/Stage_5a_brief.md) replaced the line this plan had ("tabs, scroll
  lists, windows, tooltips, proven on the band panel") after the interface was agreed on 9 November:
  two interfaces on one widget layer, and the hooks to build before more mechanics.
- Built: zones as things (stockpiles and the camp; colony blob 11); each member's director; the action
  table (Castle.Actions: one door for every interface, permissions, menus); data views (Castle.Views:
  sheets); picking by a ray (Castle.Pick, Castle.Rays); tabs, scroll lists, tooltips and popups in
  Castle.UI; a tooltip on whatever the cursor points at and a context menu on a right click; the band
  panel rebuilt in tabs (Band, Stores, Camp, Orders) with a scroll list; a scripted pointer
  (`--pointer`) for recordings. pick_check added; ui_check 27 -> 59 checks, colony_check 151 -> 206.
- No behaviour changed: the 41-day reference log is line for line stage 4's, and with the blob written
  in the version 10 layout the state hashes are the old ones.
- Not in it (by the brief): draggable windows, text input, skills (5b), the demand chain (5c), the
  player's character (7).
- Demo: colony_stage5a_scaffold.mp4 (tools/demo_stage5a.sh).

## Stage 5b: skills (DONE 2026-11-10; see docs/handoffs/Handoff_2026_11_10_stage_5b_skills.md)
- The brief (docs/production/briefs/Stage_5b_brief.md) holds the nine rules the stage was built on. They
  were put to John after the building; he accepted the stage as built ("critiques that don't concern
  functionality that we can tweak later"), so they stand as first values, his to tune.
- Built: a level and an aptitude for each member in each skill (five working skills, six trade skills
  that only grow alongside); every work timer at rate = condition x skill x direction; a hunter's aim
  and a cook's pot by skill; learning by doing with fractions to related skills; colony blob 12; the
  person's sheet, the person's menu and a Skills tab show them; `--no-skills`, `--by-skill`,
  `--skills-at`, `--job`.
- With skills off the reference run is stage 5a's line for line (tools/reference_check.sh).
- Deferred from this line of the plan, by the brief: job tiers and trades earned by skill (the first
  earned trade, stage 6 or 8); a tab per job (one list holds everyone); capacity (the farmer).
- The plan's line was: proficiency (start levels), aptitude (growth multiplier), skills by use with
  weighted spillover, job tiers; Unassigned tab + a tab per job.

## Stage 5c: the demand chain (DONE 2026-11-10; accepted as built, polish to come)
- See docs/production/briefs/Stage_5c_brief.md (nine rules for John, and what changes on first launch) and
  docs/handoffs/Handoff_2026_11_10_stage_5c_demand.md.
- Built: the demand table (who asks, what, how much), two levels per good, one question before every
  producer sets out, the Stores tab as the table, `--no-demand`, colony blob 13. No demo was recorded.
- Between 5b and 5c, on main (ac56903): the interface's scale in quarter steps (F10, F11), remembered.

## Engine work between 5c and 6: water (DONE 2026-11-10; accepted as built)
- From John's testing: a sheer wall of water at a cut into a lake, water climbing onto planks placed in it, a
  dry lake bed in the mountains. His rules and what stands for each: docs/systems/water.md, "John's rules";
  docs/handoffs/Handoff_2026_11_10_water_drawdown.md.
- Built: source water with a level it rests at, simulated as how far it stands from it (it drops beside a cut,
  the drop fading with distance and waking resting water as it spreads; closed again it comes back and
  sleeps); a stream on a hill keeps to its bed; the world as made holds its water (no more leaks at falls);
  a block placed in water takes its place; a flow that runs on without changing sleeps; water drawn stepped;
  tarns (Generator_Version 12); save format 6.
- Not built: reach (John's idea for momentum: water moving further than the next column in a step), sleep for
  water tumbling down a slope. Dams and rerouting: scrapped by John ("not the purpose of this game").
- Next for water (John, on accepting it): deeper hues for deeper depths, and surface reflections.

## Engine work between 5c and 6: the water's look (DONE 2026-11-10; accepted as built: "looks spectacular")
- John, on accepting the water: "it's clear we need deeper hues for deeper depths, and surface reflections".
- Built: a column of water coloured and made opaque by its depth (Storm Blue, Royal Indigo, Abyss Blue); the
  land, the trees and the people mirrored in open water (the picture read back, the reflected ray walked
  through its depths), `--noreflect`. docs/systems/rendering.md;
  docs/handoffs/Handoff_2026_11_10_water_look.md. No version moved.

## Engine work between 5c and 6: shadows and the fire (DONE 2026-11-10; accepted as built: "Tested and passed, everything works great")
- John: "shadows need work, they flicker, and not everything has shadows yet, we need to get that handled so
  we can streem line shadowing new assets. The current fire animations, the turning bouncing red blocks, is
  cute, but it feels unnatural, also ties into shadows as a light source".
- Built: the sun's shadow maps held at two directions and mixed, so nothing flickers (on a still view one
  pixel in seventeen stepped by more than six levels between two frames at least once in two seconds; now
  none does); everything drawn as a figure
  casts, through the one routine that draws what casts (`Draw_Casters`); shadows fade at dusk and dawn; the
  fire as small pieces of flame that rise and cool, with sparks and smoke (`Castle.Fire`); the fire's light
  casts shadows; `--stoke`. docs/systems/rendering.md ("Shadows", "The fire");
  docs/handoffs/Handoff_2026_11_10_shadows_and_fire.md. No version moved.
- The rules put to John with the build (the handoff) stand as built: first values, his to tune.
- Not built: shadows from the moon; more than one fire's light (the first hearth of stage 6 will want it).

## Colony work between 5c and 6: zones' ground, the fire's life, the camp built (DONE 2026-11-10; accepted as built: "everything you have works wonderfully, it is starting to take shape")
- John: "stockpile dynamics, fire life, zone fill instead of squares, and snapping to pathways, preventing overlap
  and campfire dynamics as well"; his words for each are in docs/handoffs/Handoff_2026_11_10_camp_and_zones.md.
- Built: a zone is the ground it fills, block column by block column (fill, snap to the path, terminate at it), so
  a stockpile lies along its path at any angle and is shown filled in; paths and zones never share ground (one
  lookup; a path through a zone is refused); the tools show a lot before it is taken. The fire burns eight hours
  a log, then dies down for three, and is tended by hand. The camp is built by the band: the ground made ready,
  stone and wood brought, then the hearth and its pot; the seats laid as soon as there are logs. Colony blob 14;
  `--instant-camp`, `--camp-built`; tools/reference_check.sh holds four logs; colony_check 282 -> 337.
- Leaves room for the stockpile's upgrades he named (storehouse, warehouse, fences, coverings): a zone knows its
  path and the way it lies, and what is built on it is a row of `Build_Takes` delivered as the hearth's stone is.
- Not built: un-zoning; lots of other shapes; a cost to lighting a cold fire; the stockpile's own building.
- From his answer, the work that follows: no distance limit on what the camp's building takes ("if they have to
  walk 200m to get stone they walk 200m"), and paths planned by the player and built by the serfs ("the path
  should work the same way").
- Stage 6's first hearth is still the first second fire (the light becomes a table then).

## Colony work between 5c and 6: paths planned and laid, no limit on how far (DONE 2026-11-10; accepted as built 2026-11-11)
- John, on accepting the camp and zones: "Don't place a distance limit on initial gathering, if they have to walk
  200m to get stone they walk 200m" and "the path should work the same way, the player plans it the serfs build it".
- Built: a path is planned by the player and laid by the band a metre at a time (what is still to lay read from
  the ground; zones laid out along a planned path as along a laid one); with no stone or deadwood in reach of
  its work the band looks further, a ring at a time to 256 m, and walks out for it; the colony's ground follows
  its reach. Colony blob 15; `--no-labour` (the switch's name now), `--paths-built`, `--stone-from M`;
  tools/reference_check.sh holds five logs; colony_check 337 -> 358.
- docs/handoffs/Handoff_2026_11_10_paths_and_reach.md has the rules and his calls.
- John, 2026-11-11, on trying it: "excelent, the framework is starting to take shape". The rules stand as
  built: first values, his to tune. In the same answer he overruled one (everyone laying paths before its
  job) and asked for the next work (below).

## Colony work between 5c and 6: extra hands, stretches, the camp's floor (DONE 2026-11-11; closed as built the same day)
- John, on accepting the paths and reach work: "we should limit the amount of workers that can perform extra
  tasks, for roads I suggest that when a serf starts compacting a road they are assigned a stretch, say 20m for
  example, the campfire, I have tested it on uneven ground, and it causes some issues with the logs and such, so
  I think we need to have them level the terrain at least for the compacted part, they can move the dirt to the
  stockpile, then we are going to work on stockpile mechanics".
- Built: at most a third of the band at extra tasks (the camp's building, the paths' laying) at once, those
  with no job always, the cook at its own camp besides; a path laid a stretch of 20 m to a serf; the camp's
  floor levelled as its ground is made ready, the earth dug off into its hollows and what is over to the
  stockpile as earth, a new kind. Colony blob 16; `--extra-hands N`, `--all-hands`, `--no-level`;
  tools/reference_check.sh holds six logs; colony_check 358 -> 404.
- docs/handoffs/Handoff_2026_11_11_hands_and_level.md has the rules and his calls.
- John, 2026-11-11, on the report of it: "great, I think we are at a point to end the session". Closed as
  built: first values, his to tune; the calls put to him were not taken up and stand by default (the handoff
  lists them, the turf's earth first).

## The last pass before stage 6: models, tools, foliage, the herds' flight, the fringe of paths; then trees, grass and a quiver (DONE 2026-11-11; accepted as built)
- John: "before we start stage six this is our final pass at some improvements for what we currently have":
  the models' "minecraft feel" ("a tiny bit of smoothing, slightly higher triangle count ... nothing too
  expensive"), foliage ("a bit more organic feel"), the bow and the axe ("a stick jutting directly out from
  the hand ... the bow on the back, and the axe on the hip", "curve the bow too"), deer ("rubberband and
  swing around ... submerging themselves in water"), and the edges of paths and compacted ground ("some
  charecter").
- Built: every box drawn rounded and tapered (108 triangles a box); the axe and the bow as things carried,
  stowed on the hip and across the back, in the hand at work, the bow a curved stave that bends; crowns and
  bushes drawn with their clumps' edges cut back, ruffled and frayed; the fringe between turf and bare earth
  drawn ragged, with pebbles; the herds fleeing together with their node and keeping out of water.
- His answer to that build, the same day: "don't worry about ever being compatible about mainting
  compatibility with old saves during production. So we can rewrite the trees, grass can get a slight
  overhaul. A quiver would be nice, full animations are not important, we want a happy balance between
  realism and immersion, so just enough realism to be immersive without being expensive and time consuming".
  It names three things more and gives two standing rules (no save compatibility in production; realism
  only as far as it is cheap); it does not say the first build was tested, so nothing is recorded as
  accepted.
- Built on the same branch: the hunter's quiver on his belt; grass drawn as leaning tufts lit like the turf,
  a meadow's steps as banks of grass, the meadow's tone in drifts; and generator 13: trees reshaped (crowns
  of lumpy domes on boughs, spruces of drooping whorls, bare boughs in winter) with every tree where it
  stood, and tall grass in drifts, some of it two blocks high.
- `Generator_Version` 13: saves made before are refused. Save format 6. Colony blob 17 (the herds' blob 2).
  `--deer-scatter` keeps the herds as they were; tools/reference_check.sh holds seven logs, all regenerated
  on the new world; colony_check 404 -> 422.
- Accepted on the report of the second build: "impressive, the world is in desirable state, merge it into
  main and prepare for a session clear". Merged into `main`; the values are first values, his to tune.
- docs/handoffs/Handoff_2026_11_11_models_pass.md has his words, what he sees, his calls and what was
  measured. Tag `models-pass-1` is the first build, as it was put to him.

## Touch-ups and a stress test before stage 6: the sky, mist, wet surfaces, lights; then the moon's light, its phases and stars (DONE 2026-11-11 in two rounds; accepted as built: "perfect, everything checks out, looks awesome and works great")
- John: "final touch-ups and a stress test before we move to stage 6, Volumetric clouds, no moon, black sun
  in winter when snowing, wet surfaces, deferred lighting techniques if not already implemented or not
  effective, Mist/fog?"
- Built: the sun's disc never dark (it was, under heavy cloud and at every sunset); a moon opposite the
  sun, a disc and its glow; the clouds walked through as bodies, in a pass of their own, standing where
  their shadows fall; mist lying on the land, by the weather; wet surfaces (darker by what they are made
  of, a sheen, pools on level bare ground, rain rings); the lights a table with a grid of which reach
  where, 64 in a view, the nearest casting. `--flatclouds`, `--mist`, `--nomist`, `--wet`, `--nowet`,
  `--lights N`, `--hitch MS`, `--no-needs`.
- No version moved and no reference log: nothing of it touches a block, a save or a step of the colony.
- The stress test (`tools/stress.sh`, docs/production/Stress_test.md): nothing died; the colony repeats
  itself over four years, and with the reference run's orders five of the six are living at the end of
  them; a view of 512 m does not fit the quad arena; at 240 times speed the colony's steps can hold a
  frame for a second or more. The last two were so on `main`; neither is changed here.
- The answer to "deferred lighting": the renderer stays a forward one (a G-buffer would cost the
  multisampling and the cut-outs by coverage that foliage, grass and smoke are drawn with); what deferred
  lighting buys, many lights, is had with the table and its grid, 0.4 ms for sixty-four.
- His answer to the first build, the same day: "Moonlight on the land, phases, stars. Sounds great, MSAA
  keep it, no need to save a milisecond, if it becomes an issue later we can deal with it then. Time
  budget we will leave out for now, so we don't interfere with production." Three decisions (the moon;
  multisampling stays; no budget of time for the colony's steps), and nothing of having run the build: so
  it was not recorded as accepted until he had tried both rounds (the heading).
- Round two, built on the same branch: the moon's phases (ten days, from the clock), moonlight on the
  land once the sun's is gone, casting shadows through the sun's held maps, and stars that turn with the
  sky. `--moon PHASE`, `--nostars`. A moonlit night costs what a day does; a moonless one is as it was.
- Not built, each his call: shadows from more than one light (the first hearth in a hovel will want
  it); light shafts; darker moonless nights.
- John, watching the stress test run: "I think our deferred lighting and MSAA 4x is getting expensive"
  (with a note on a single-sample G-buffer and SMAA 1x), then "gpu ms is staying in single digits, CPU is
  getting wild, but that could be a consequence of acceleration". Measured: the drops were the CPU's, the
  colony's steps at 240 times speed; 4x multisampling is half of the GPU's frame, about a millisecond
  (rendering.md, "What multisampling costs"). Nothing of the note is built; the land is drawn nearest
  first now, which saved 2 to 3 %.
- docs/handoffs/Handoff_2026_11_11_sky_and_weather.md has his words, what he sees, his calls and what was
  measured.

## Engine work before stage 6: what routing and the colony's steps cost (DONE 2026-11-11; accepted as built with the touch-ups, in the same words)
- John, with a note from the design side on anchors and a route store kept out of the save, replanning
  only when a route's own cells change, rebuilding the walking map only round an edit, and a coarse
  graph over the stacks: "that is for pathing optimization, up to you how we implement it."
- Measured first (`colony_run --nav-stats`, new). Of the note's four: routes were already walked again
  and kept when their stacks changed; the walking map did read a whole stack for one edit, and that was
  2 % of the colony's time; the long ways a store or a coarse graph would shorten are 17 ms for six and
  28 ms for forty-eight. What cost was elsewhere.
- Built: a goal nobody can stand at (fruit up a tree) is known out of reach at once, where it was
  searched for through everything in reach whenever a stack somewhere had lately been edited (55 ms,
  about once a game day: a held frame); what a search for the nearest straw, stone, water or wild
  vegetables found in a stack is kept until its ground changes (more than a third of the time of a
  band of forty-eight); the walking map mended a cell at a time; the edit store asked only about edited
  columns; the indexing pass walking only its ring.
- The colony's steps: the reference band's 41 days 8.3 s to 5.9, forty-eight's 12 days 30.5 s to 9.1; the
  slowest colony second 62 ms to 18, and 62 to 46. In the game, forty-eight at 240 times speed in a
  storm: the CPU's frame 11 to 12 ms on average to under 3; frames over 50 ms 72 to 81 in thirty seconds,
  to 5.
- One of them moves where people walk (a route to a goal out of reach may end a floor away from where it
  did), so the seven reference logs are regenerated (c8e1c4a) and the first winter comes out otherwise:
  all six live where one died; with no forester two die where none did. The rest change no run, and the
  runner proves it (`--no-mending --no-memos`; `tools/stress.sh runner`).
- Not built: the route store, the anchors and the coarse graph (stage 6's buildings are the anchors; a
  band of six has no way long enough to want them: routes.md, "What routing costs"). No version moved;
  nothing new is saved.
- docs/handoffs/Handoff_2026_11_11_pathing.md has his words, the note, what was measured and his calls.

## Engine work before stage 6: falls thrown from the lip (DONE 2026-11-11; accepted as built: "That is perfect ... Everything flows and looks perfect now.")
- John, on accepting the sky and the pathing, with three pictures of a lake let out through a cut and down
  a hillside: "look at the big hole and the almost linear path the water is taking down, can we make it
  more of a arch, water rollong over itself, and second can we have the water extend from the wall face
  so it doesn't become just streams down the wall face, I think the arch flow dynamic would take care of
  that but if it doesn't."
- Built: water leaving a column over a drop is drawn as a sheet thrown from the lip at the speed the
  simulation has it leaving with, falling column by column until it meets ground or water
  (`Castle.Falls`). Over a sheer drop that is an arch standing clear of the wall; down a steep slope the
  sheets of every step are one body standing off the slope. `--nofalls`, `--throw S`.
- It is a drawing: the simulated water still runs down the face a column a step. No rule of the water
  changed, `water_sim_check` passes untouched, no version moved, nothing is saved.
- Not built, each his call: water that really lands where it is thrown (his "reach" of 2026-11-10: it
  would change how far released water runs on steep ground); generated falls thrown the same way.
- docs/handoffs/Handoff_2026_11_11_falls.md has his words, what he sees, his calls and what was measured.

## Stage 6a: habitation (DONE 2026-11-12: built, accepted the same day and merged into `main`; see docs/handoffs/Handoff_2026_11_12_stage_6a_habitation.md)
- John, after trying it (2026-11-12): "ok the building looks great, I am impressed, works wonderfully on my end as is". He took up none of its calls: they stand by
  default, as built (first values, his to tune). In the same message he asked for the pass below and
  said what follows it.
- John opened stage 6 on 2026-11-11 ("we have completed our preperations on the engine and gotten things
  in a state to continue with stage 6 ... you're in control, go cook"). Nothing of it was designed, so it
  was built from the design documents with first rules and values of mine
  (docs/production/briefs/Stage_6_brief.md), in two parts as stage 5 was in three.
- Built: housing as a zone along a path (the Housing tool, the ground's menu, `--housing`); a hovel begun
  for everyone without a home, on the free frontage nearest the stake (a lot 7 m along the path, the
  house square to the grid, its pad cut into a fall of up to 2 m, its door always to be got to: a
  landing and a stair of single steps to the path); the hovel's size, door and windows from its seed
  (`Castle.Buildings.Design`), the generation spec's; builders from the foresters (the first earned
  trade: a forester takes a house, levels its ground, lays its blueprint block by block from logs and
  straw carried from the stockpile, and fells when there is no wood for it); what a zone's houses
  still take as rows of the demand table; the fire's logs left alone; the owner asleep under its own
  roof and not cold there; a house's tooltip, the zone's and the person's sheets. `--homes-built`.
  colony_check 422 -> 475, pick_check 32 -> 38; tools/reference_check.sh holds the seven logs
  unchanged and an eighth with housing.
- John, while it was being built (2026-11-12): "continue, one hovel per person for now, dirt discarded
  is fine for now". Two of its calls answered; the rest are put to him in the handoff.
- John, later the same day: "I have added some design refrences in the "/Design Refrences" folder,"
  with a text on the twelfth-century peasant house (the handoff has it whole; the folder is
  `~/CASTLE_GAME/Design Refrences/`, outside git). He asked for nothing by name. The hovel was remade
  from them as far as was cheap: a timber frame filled with wattle and daub (a new block, beside the
  thatch's), a floor of beaten earth, small high windows. Timber is logs; daub and thatch are straw;
  the floor is work alone. The hearth, stone footings, furniture, shutters and a steeper roof are put
  to him, not built. Colony blob 19 (18, the hovel of plank, was on the branch only and is refused).
- Measured on seed 1 (the reference band with a porter in the second hunter's place, a path west,
  housing on both sides): one forester raises a hovel in three and a half to four days (3 or 4 logs,
  26 to 31 sheaves); all six are housed two days before winter. The first winter is as touch and go
  as it was and is not tuned: in that run the store runs out on day 55 and two of six die the day
  after; the same band without housing loses one, the reference band none. (That band's winter on the
  four builds of this stage: none, five, five and four of six living. The handoff has the runs side
  by side, and what parts them is a deer or two at either end of the winter.)
- Two faults of the first round's build, found in the second by counting who was at home at midnight
  and mended: a house on ground falling away from its path could shut its owner out; a builder caught
  by nightfall with a load for its house in its arms stood awake where it was until morning.
- Changed from the plan's line: no shared walls, no hearth, no furniture (the spec's hovel has none);
  the "village prototype" is kept for its preview only (`Castle.Buildings.Layout`); "demand per
  homeless serf" is a hovel each, begun as many at once as there are foresters.
- Not built: clearing a lot (a bush, a tree or a boulder on one refuses it); un-zoning; improvement;
  families.
- Demo: colony_stage6a_habitation.mp4 (tools/demo_stage6.sh). Zip: castle_game_stage6a.zip, of the
  branch.

## Building and zoning, a pass after 6a (asked by John 2026-11-12; see the newest handoff)
- His words, whole, are in Handoff_2026_11_12_stage_6a_habitation.md ("John's words", the fourth). In
  short: where a zone's ground rises and falls, a retaining wall of stone from the stockpile in the
  quarter metre next to the path, stone stairs on the door's path, the earth behind a building dug away
  and a retaining wall built, walls joined where buildings stand in a line and built between houses
  that step down; roofs smoothed by their builders, with rounded edges round the perimeter; a housing
  zone a fixed distance deep that fits a hovel, pulled along its path to the length wanted, combined
  with any housing zone it overlaps, and reaching no further than seven blocks past the end or the
  turn of a path.

## After that pass, in John's order (2026-11-12; NOT DESIGNED, his to open)
- "That we can do for this pass, then we will have an intermediate sleeping, beds, campfire to house transition. After that we will get to the stockpile, and how the player manages this."
- So what the brief called 6b comes third: sleeping and beds first.

## Stage 6b: stockpile mechanics (NOT DESIGNED: asked of John; behind sleeping and beds by his word of 2026-11-12)
- The plan's line for stage 6 was: Habitation zone along paths, demand per homeless serf, hovel
  blueprints (village prototype + the procedural generation spec), builders from foresters building
  block by block from wood and straw, residency.
- **With stockpile mechanics rolled in** (John, 2026-11-11: "I have decided to roll the stockpile mechanics in
  with phase 6, becuase there are a lot of overlap, I will start that in a new session"; "phase 6" read as
  this stage). His to open: nothing of it is designed and there is no brief yet. Where he has said
  stockpiles are going (2026-11-10): "they will eventually start upgrading the stockpile, build a
  storehouse, warehouse, fences and outdoor storage will get coverings".
- What 6a leaves for it: a thing built on a zone from a blueprint, by a builder, from materials the
  zone asks the stores for. What is asked of him (the brief, "6b"): which improvements and in what
  order; what starts each (conditions, not a click); what each does (spoilage and theft are stage 11);
  whether it is also something of how goods are kept.
- (The save finding of Handoff_2026_11_11_hands_and_level is explained there: it was the runner's rebuilds,
  not the colony's save. Nothing is owed for it.)
- From the touch-ups before it: a hearth in a hovel is one more `Castle.Fire.Show` and one more
  `Castle.Render.Add_Light`, and it shines through the walls until lights other than the nearest cast.

## Deferred, by agreement
- Needs (hunger) as the consumer that makes stockpiles mean something: stage 4.
- The player's own character (one person in the band who can join the work): after stage 2.
- Standing orders (reserves, protections): with stage 2 (done).
- Water fetching (buckets, then barrels): once something uses water (cooking, building) and barrels exist.
- Stone demand from masons (paving the paths with stone): replaces the starting quota.
- Uses for meat and hides: meat is eaten in stage 4 (hunger), hides wait for a tanner.
- Deer extras: the tail's flag when alarmed, ears turning, lying down, dying of age, herds splitting or
  new ones arriving.
