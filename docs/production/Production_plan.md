# Castle Game production plan (agreed 2026-11-07; stages 0 to 4, 4R, 5a, 5b and 5c done; the water and its look, shadows and the fire, zones, the fire's life and the camp built, and the last pass on models, trees and grass, then the sky and the weather's look, a stress test, the pathing work and falls thrown from the lip, done between 5c and 6 and all accepted; stage 6 opened by John 2026-11-11 and in two parts: 6a habitation built and accepted 2026-11-12, on `main`; then, asked by him in the same message, a pass on building and zoning (retaining walls and stone stairs, roofs smoothed by their builders, housing zones pulled along a path and combined), built and put to him, a second round on his answers the same day (lots laid out beforehand, hovels drawn for by lot, the ground between neighbours made one, sleepers on their sides, beds of straw, cloaks), built and put to him again, and a third on what he found trying that (level places by the fire, beds before hovels for straw, a fender to the nearest food, housing inside a round of paths, a path drawn on its ground, no housing across a connecting road, the band half as fast again), built and put to him a third time, and a fourth on what he found trying that (no stone stair where a door is all but level with its path, a ladder for the roofs, the cook's hold on the stores, meat by the pound and the lord's cart of salt, with the first of the story), built and put to him a fourth time, and a fifth on what he found trying that (a load taken home before its carrier eats, a lot levelled with its hollows filled, no grass left in the air, holes under a path filled, a half-built house taken up), and accepted 2026-11-13: on `main`; after it, in his order, the transition from sleeping by the fire to the house, then the stockpile, both his to open and not designed: start from the newest file in docs/handoffs/)

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

## Building and zoning, a pass after 6a, in five rounds (BUILT 2026-11-12 and 13 on branch `housing-pass`; put to John five times; ACCEPTED 2026-11-13, "accepted"; merged into `main`; see docs/handoffs/Handoff_2026_11_12_housing_pass.md)
- His words, whole, are in Handoff_2026_11_12_stage_6a_habitation.md ("John's words", the fourth). In
  short: where a zone's ground rises and falls, a retaining wall of stone from the stockpile in the
  quarter metre next to the path, stone stairs on the door's path, the earth behind a building dug away
  and a retaining wall built, walls joined where buildings stand in a line and built between houses
  that step down; roofs smoothed by their builders, with rounded edges round the perimeter; a housing
  zone a fixed distance deep that fits a hovel, pulled along its path to the length wanted, combined
  with any housing zone it overlaps, and reaching no further than seven blocks past the end or the
  turn of a path.
- Built from that with first values of mine, in three commits and a fourth. Zoning: a strip along the
  path's straight run (the stretches a path is recorded as are one run), 9.5 m deep, all its free
  ground taken whether or not a hovel fits, combined with housing it overlaps or touches. Walls: a
  house's site is a level yard to its path and two blocks behind and beside; where what is beside it
  stands more than a block over or under, a wall of stone (a new block), each house walling its own;
  stone treads on the door's stair; stone the third thing carried to a house, the hearth first.
  Roofs: a last stage of the blueprint, the top thatch laid again with a state that says it is
  dressed, drawn sloped by the mesher and the land's vertex shader. Colony blob 20 (18 and 19
  refused). colony_check 475 -> 509; `tools/reference_check.sh` holds the seven logs and the eighth,
  recorded again.
- Measured: a hovel in about four game days from one forester; on the hillside east of the stake up
  to 25 stones a hovel; on ground falling 2 m in 7, 24 on average. The look costs 0.02 to 0.05 ms at
  the fixed views with the most land. Two faults of mine found by reading who was at home at each
  midnight of a run built by hand, and mended: a builder starved in the pit of a stair dug out before
  its stone had come, and one in a yard a metre wide under a wall it could drop down and not climb.
- **A second round, on his answers** (2026-11-12, his words whole in the same handoff): the walls
  behind a row extended as one ("they can meet and turn into each other, just take the difference
  between the two"); no second shader program; "Hovels need to fit within the confines of the zones,
  if they don't fit the housing deficit stands until the player designates more area"; "Don't let the
  serfs search for a lot, just assign it to them by lottery, when the construction is complete"; and,
  on top, "have serfs sleep on their side, when the campground is built have them pull or collect
  straw for a bed, and can we add cloaks ... When they get assigned a home they can build a new straw
  bed in their house, we will let the old one decay outside when we add decay later. I think that is
  enough of this pass before I discuss the stockpile."
- Built from that in five commits. The lots of the houses still to begin are laid out when housing is
  zoned or a path laid and kept in the save; the hovel next in turn is never passed over; a house is
  nobody's until it stands and is then drawn for among the living without one. A house begun beside
  an earlier one makes the ground between them ready with its own: one terrace, one wall between two,
  the walls behind them met (not where a tree stands between two lots). Asleep, a serf lies on its
  side; the dead on their backs. Each makes a bed of two sheaves where it sleeps once the camp
  stands, from the stockpile if it has straw to spare, else cut by its own hand, and another in its
  hovel; `--no-beds` is the band as it was, and the seven older reference logs are run with it. Each
  has a cloak: folded by its bed, worn in winter, over it asleep. A bed and a cloak change nothing but
  what is seen. Colony blob 21 (18 to 20 refused). colony_check 509 -> 541.
- Measured: the longest colony second back to 18 to 19 ms (31 with the search for a lot in it); the
  click that zones about 1 ms; the camp's and the hamlet's frames what they were; on the hillside east
  of the stake four hovels a side by hand, everyone at home at every midnight; above its path three of
  the four on one terrace and the fourth apart, a tree between. A first-round fault found and mended:
  beside a path aslant a stub of wall stood across half a stair's foot.
- **A third round, on what he found trying the second** (2026-11-12, his words whole in the same
  handoff): "it would be nice if the serfs found level ground and slept perpendicular to the fire,
  serfs didn't create a bed when straw was in the stockpile, might have been reserved by the housing,
  basic needs take priority, serfs would go long distances to fend for themselves to eat vegetables
  when furit and berries were near by, it would be nice if player had a fill option for closed loop
  paths, the pathing zone also just forms a stright line by elevation and it is in the air above the
  ground instead of drawing along it, if a player starts to draw a habitation zone that extends the
  length of a path and crosses over a path that changes direction a slice of the habitation zone
  passes over the connecting road, that should be enough for this pass." and, a little after, "also
  can we increase the work and travel speed of serfs by about 50%".
- Built from that in four commits. By the fire each of the band chooses a place of its own once the
  camp stands, across the way to the fire, level under all its length where there is such ground
  within 5.5 m (else a block or two out of level, else the old ring), and makes its bed there; a bed
  takes stored straw before a hovel does and comes before the band's paths. One that fends goes for
  the nearest food. "Housing inside these paths" in the ground's menu takes all the free ground
  inside a round of paths. A strip's ground is begun from beside its own path alone, so none of it
  lies across the road off a path's end. A planned path and the Path tool's line are drawn block
  column by block column on their ground. The band works and walks at a pace of 1.5 (`--pace 1` is
  the band as it was: the seven older reference runs are held at it). Colony blob 22 (18 to 21
  refused). colony_check 541 -> 573.
- Measured: at the new pace the reference band holds 11.8 days of food at its most (5.6) and all six
  live through the first winter (three did); nothing was retuned. With housing being built it fills
  its one stockpile of 48 places by the thirty-seventh day: gatherers stand awake with what they
  cannot store, and a hunter with a deer and nowhere to butcher it starved holding it, which is
  mended (hungry, it puts the kill down). What a full stockpile should mean is the stockpile's, and
  his to open; the eighth reference run has a second stockpile meanwhile. The fender's rule moved the
  first winter of every run in which somebody fends: five reference logs were recorded again for it.
  I could not make a serf go without a bed with straw stored, in runs of my own.
- **A fourth round, on what he found trying the third** (2026-11-12, with a picture; whole in the
  handoff): "a minor tweak with the house pathing and stepping as shown in the image, the stairs were
  added when the pathway was pretty much already leavel witht he house path, serfs building spend a
  lot of time walking around the house thatching, can we have them construct a ladder in the
  stockpile, and use the ladder to thatch roofs, that would be cool, the other thing i noticed is
  that rather than waiting for the cook to use the stockpile to cook food, the serfs were eating raw
  directly from the stockpile preventing food from being cooked, can the cook reserve food in the
  stockpile and only suprlus is availible to eat raw if no stew is present, we need to up the amount
  of meat a single deer can provide, we are looking at 60lbs of field dressed meat from a deer that
  should be enough to feed a camp for a couple of days when smoked or cured, we can talk abit about
  the story now, the player is a minor noble tasked wtih improving the land by their lord, taxes on
  production would come after a few years, so the lord provides a small workforce a minimum of
  starting supplies so for now lets just add a cart with salt in it for curing, we can expand the
  supplies later and work the story in as we get to the players role, but for now that way a single
  deer can provide for the camp for a couple of days". He did not say he accepts the third round, and
  took up none of its calls.
- Built from that in five commits, each new system behind a switch that gives the band as it was. A
  door's way is a stair of stone only where the path lies more than a block off the floor. The cook
  keeps a pot's fill of what is stored, and only what is over it is eaten raw (`--no-cook-hold`).
  Meat is counted in pounds, a doe's sixty being two days' food for six; the band comes with the
  lord's cart, a thing in the world with 240 lb of salt in it; a hunter keeps a sackful in the
  stockpile, and a deer is salted as it is butchered and kept whole, or a quarter of it with no salt
  (`--no-curing`). A builder makes a ladder at the stockpile when its roof is next (felling for the
  log if it must), stands it under the eave and thatches from it without walking, carries it round
  for the other slope, and stores it after (`--no-ladders`). Colony blob 23 (18 to 22 refused).
  colony_check 573 -> 610, pick_check 38 -> 41.
- Measured (seed 1, the reference band): a first winter costs nothing now and nothing was retuned: 17
  deer in 41 days where 33, eleven to seventeen days of food in hand where three to twelve, all six living; with no orders
  given at all, where the band used to starve, all six live, never hungry at a midnight. Over six
  days at the roofs a builder is 55 game minutes going to its work where it was 398, and none while
  trimming where it was 310; in the stage 6 run the six hovels stand a day sooner. With the hold 363 berries are eaten
  raw in 41 days where 637. **What a hungry band waits for on its first day is mostly the pot's
  filling** (the cook does not stir until the pot is full or nothing more is to be fetched: three
  hours on the reference band's first day), a stage 4 rule reported to him and not changed.
- Of the story, his words are recorded (the framework's decisions) and only the cart is built.
- **A fifth round, on what he found trying the fourth** (2026-11-13, with a picture; whole in the
  handoff): "Some new things I found on my latest testing, people carrying items to the stockpile will
  stop and eat instead of completing their task and then eating, this creates an oddity where
  foresters carrying logs back to the stockpile have a log on their sholder while they are eating, I
  am sure this can happen while carrying other things too. [Image #17] This screen shot shows dirt
  having been removed, and the grass stays in the air. It also shows that othewise even ground was dug
  out entirely becuase it had a couple of holes in it, instead of just filling the holes. It would be
  nice if there was a way for serfs to fill in holes in the path when they are compacting the
  ground." And a little after: "Also, I removed the cook from cooking, he started building a house,
  the build was asigned to him, I then sent him back to cooking mid build and it didn't free up the
  assignment for the build." He did not say he accepts the third or the fourth round.
- Each reproduced first, then built in four commits. A load in a serf's arms is taken where it was
  going before it eats (47 meals begun with one on the reference band in 41 days, now none); a
  gatherer with no stew to be had still eats from its basket, since taking its food home first
  starved the housing run's first day (his call). A hovel's lot is levelled as if its holes were
  filled, and they are (on his kind of lot the ground is ready three hours sooner, and is not dug a
  block down). A path the band lays fills the holes under it (`--no-path-holes`; colony blob 24, 18 to
  23 refused). A builder takes up a house left further on than its own (the half-built one waited a
  day; now under an hour). Grass left over a hole dug under it is mended (the dig takes it, and
  levelling cuts what is left over a hole); what he saw stay in the air, on a couple of blocks where
  grass had been gathered, was not found and is left at his word until he sees it again. A hollow is ground closed in by higher ground, at most four square metres. colony_check 610 -> 616; the eight
  reference logs recorded again for the eating.

## The lord's cart pulled into a stockpile, cloaks of cloth, and roofs cleared on the camera's ray (ACCEPTED 2026-11-13: on `main`; see docs/handoffs/Handoff_2026_11_13_cart_and_cloaks.md)
- His words (whole in the handoff): "Two last things I want to work on before moving to the next stage, the cart, can they pull it into the closest stockpile zone? I also want to try something, an experiment, can we have the cloaks be dynamic cloth, that they wear at the start, then take off when they make their bed, and then draped over them when they sleep, if we can do it, it would be a very cool touch and would translate well when we get to other wearable items later in production." And of the grass that stayed in the air: "Just leave it for now": left.
- Built: once there is a stockpile zone, one of the band pulls the cart to two empty places side by side in the zone nearest it and it stands there (`--no-cart-pull`; colony blob 25). Cloaks are cloth, drawn only: worn from the start, taken off when the bed is made, laid over their owners asleep (`--no-cloth`). colony_check 621.
- His next message (whole in the handoff): "ok I guess it is time, and we should have planned for this and i forgot, semi-transparent roofs on the ray of the camera, It would be nice to have a tapering transparency with full transparency in the middle and semi-trasnparency along the edges wher the roof meets the walls". Built on the same branch: the roof of a house the camera's line passes through is cleared, open in the middle and half drawn over its walls (`Castle.Cutaway`, `--no-cutaway`; drawing and pointing only). pick_check 48. Looking into a hovel through it found a sleeper lying on its cloak: mended (the sheet sticks where it rests).
- A fault he found the same day (his words whole in the handoff): "water surface stop rendering around the homesteak and some a little distance away ... I simply placed the homesteak, moved the camera around and the surface water no longer rendered near the homesteak." Reproduced (the camera 520 m off and back; a river 512 m from a working band's ground going dry, on `main`'s build too): the surface texture wraps every 512 m and the colony's kept ground shared its texels with far stacks. Mended on the same branch: a slot of the texture is its window stack's alone (`docs/systems/water.md`, "Drawing"). `--pan-back`.
- His answer to the roofs and the cloth (whole in the handoff): "For the roof let's run it to the mouse and the camera, along with an option to have all roofs transparent ... What was the question about the cloth, it works great, it would be nice if the clipping was less, but it's workable. After those two things we can get to the salt and the stockpile." Built on the same branch: the pointer's ray clears a roof, the H key (`--all-roofs`) clears them all; a basket or a sack no longer comes through a worn cloak. pick_check 54. **The salt and the stockpile are his to open.**
- His answers to the list of open questions (whole in the handoff): "Let's cut down the walls in-line with the camera too ... as far as the game is concerned the walls are still there to block light. The taper is adequate. We can have the H k toggle through, dynamic transparency, full trasnparency, or no transparency. Move the cart once for now, who pulls works great the way it is ... The cloth is fine ... So that is it for this first pass, then we will track down the cart issues, then the stockpile." Built on the same branch: a cleared house's walls on the camera's side are cleared with its roof (light untouched); H goes through three views. pick_check 59. Asked whether he accepts the branch: "ok commit we are at a good spot right now, then the stress test for the cart issues, and at last we can get to the stockpile". Merged into `main`. **Next, in his order: the cart issues (the herds' time with the pull), then the stockpile, his to open.**

## The herds' searched-out ways, "the cart issues" (ACCEPTED 2026-11-14, on `main`; see docs/handoffs/Handoff_2026_11_13_herds_search.md)
- His words: "then the stress test for the cart issues, and at last we can get to the stockpile".
- Found: with the pull the stress runner's crowd took 22 s for 12 because a herd with no dry way out, frightened every three seconds by a forester left standing by it with nowhere to put its log, asked the walking map the same flight 721 times, 40,000 floors each. Kept now (a plan that ran out of budget is remembered by the ground it read): 13.3 s, the same state. Nothing anyone does is changed; three things that would are put to him (standing still frightening a herd; a cornered herd asked again; a full stockpile leaving serfs standing).
- Then, at his word while it was being closed ("Let's change direction for the deer herd, instead of panic running them in different directions, lock them to the node and they run with the node, from the closest to the hunter in a chain reaction"): a herd's flight goes down it in a chain from the deer nearest the danger, a quarter of a second a link, the deer locked to the node; none bolts by itself. colony_check 623; the two reference logs with the herds fleeing together recorded again.
- His answer to the finding's calls (2026-11-13, whole: "Ok, lets do a mix, a person standing still doesn't frighten a herd, and let them know that water blocks them, when we get to the stockpile mechanics we will reserve a portion of the stockpile for overflow"). Built on the same branch, a commit each: the walking map keeps pieces of ground for dry going and a herd's ways are refused where water blocks them (plans out of budget in the crowd's five starts 5, 0, 25, 502, 7: none now; every refusal of six runs searched for whole and borne out); one of the band who has not moved in a step frightens no herd (the crowd's herds frightened 13 to 24 times in twenty days where it was 612 to 4,462). path_check 69, colony_check 635; the two reference logs with the herds fleeing together recorded again, twice.
- **Accepted 2026-11-14** (whole: "Well when we add the entire ecosystem we are going to have to seperate the deer from the stake and the entire map gets populated, keep that in mind. The rest of the conditons are acceptable keep them. When we do that we can solve the cornered herd problem by letting them travel farther, are we capable of realizing this? My testing otherwise shows acceptable results so I think we can merge clean-up and continue, if you concur."): `herds-search` fast-forwarded into `main`. The conditions put to him stand as built.
- **For a later stage, his word in the same message: the deer apart from the stake, the whole map populated** ("keep that in mind"); the cornered herd is left to it. Not designed, not built: `docs/systems/deer.md`, "To come: the herds apart from the stake", has what leans on the stake today and what was counted. Asked whether it can be done: yes (the handoff has from what).
- The sidetrack before the stockpile, how to get everything in view: built, accepted and merged (the entry "The far view" below).
- The stockpile, by his word ("Then the stockpile"), his to open: opened 2026-11-17 (the next entry). Before it, the same day, a third round of the far view on his answer (branch `haze-horizon-boulders`, gated, not merged: `Handoff_2026_11_16_haze_horizon_boulders.md`); he did not answer the stockpile's questions with it. On 2026-11-17 he looked at the whole round ("I love what I see great job, it really came together, I am not experiencing any anomolies"; the hole a felled tree leaves in the rock "is expected, no need to change it") and did not say merge; then, the same day: "Ok merge.": on `main` (d0efbb9; `c8f1c40` before it). He had said one thing of it: a portion reserved for overflow; four things were asked of him, answered with his design.
- **LIVE (2026-11-17 to 2026-11-19): the stockpile, in passes, by his design** (whole in `docs/production/briefs/Stage_6_brief.md`, "His design of it", with a piece of the story: the count's far lands, a messenger, a retinue, an advisor, the lord's boon; "We need to do this in a few passes I think"). **The first pass ("That is the start") built on branch `stockpile`, gated, not merged** (`Handoff_2026_11_17_stockpile_first_pass.md`): thirteen arrive, at most four builders, a stockpile at least 15 m by 15 m, five overflow places round it and nobody setting out with no room; then, on his answer, the overflow a signal. **The second pass (the storehouse built), on his "We can continue.", built on the same branch, gated, not merged** (`Handoff_2026_11_17_storehouse.md`): the advisor's request simulated on the second morning, the storehouse 5 m by 10 m with a floor of plank and its door on its end, on the stockpile's end nearest the stake, its yard beaten, fenced with a gateway, coverings along the back; colony blob 27. He set its first call (what the fence's one gateway costs the band) aside and left the rest open ("Leave the questions open I will get to them after"). **The third pass (the storehouse used), on his "Let's move on to the next step", built on the same branch, gated, not merged** (`Handoff_2026_11_17_storehouse_used.md`): its places fitted out (shelves, barrels for meat and water, baskets inside, the coverings holding more, ladders against its wall), a stockman, a carpenter, water; colony blob 28. **His playtest notes (2026-11-17, sent 2026-11-18: "~/CASTLE_GAME/PLAYTEST NOTES, thoughts") answered the layout and listed what he found trying it; built on the same branch, gated, not merged** (`Handoff_2026_11_18_playtest_round.md`): the faults reproduced and mended (hunters and gatherers that could not find what was close, grass in the air, a zone round a path's end, the storehouse never opened by the camera), the stockpile placed once, ten metres square, with its last ten places kept and no overflow, the storehouse moved to a stockyard (its length along the path, a door in each end, gateways in the line of its inside wall, its ground levelled as a house's, its trees felled, the stores moved in; on a path aslant too); colony blob 30. **Next is his**: the calls of that handoff (first how the doors and gates were read), and its "Next": what of his notes is not built (paths levelled, the builder in the job list, deleting and razing, doors, cart wheels, thatch, windows, trusses, the thatcher's ladder, a serf that meets an obstacle), a default each. **That next pass built 2026-11-19 on the same branch, gated, not merged** (`Handoff_2026_11_19_next_pass.md`), on his "we can continue to the next pass" (with "I like what you have built so far, but I have a new idea for the stockpile, stockyard, storehouse", and his design document `docs/design/detailed_mechanics.json`, read and not built from but for the builder's name): paths levelled as they are laid, the band's lists calling a serf by its trade, housing ground taken out again and a hovel marked for razing (the taking down itself not built: his first call), doors, the cart's wheels, thatch drawn fuller, a window's timber from post to post, the roof's timbers, the thatcher kept on its ladder, whoever stands where a block goes stepping aside. Colony blob 31, a blob of 30 still read. **Nothing of the stores was changed: his new idea is his to open.** **His eight answers built 2026-11-19 on the same branch, gated, not merged** (`Handoff_2026_11_19_answers_round.md`): razing limited to hovels nobody owns and the taking down built; Builder on a person's menu as a development job; leaves on the gateways; a thin trim drawn round the windows; a ridge beam in the hovels; the whole of a roof's top ragged; paths held for his playtesting; blob 32, blobs of 30 and 31 still read. **"Document's stores is my model the new idea, the logistics network": confirmed, planned in the brief in five passes with a default each, nothing of it built; its first question is his note's one stockpile against his document's many.** **Then, the same day ("Still having issues with the foresters not finding trees in range ... I think we need to lock the paths to straight and 45 degree angles ... then we can start planning structures on that design pathway"), on the same branch, gated, not merged** (`Handoff_2026_11_19_foresters_and_paths.md`): the fault made in the runner two ways (the trees within 60 m of the stake used up by the hundred and thirtieth day; a stake on open land), a forester looking a ring further when it has no tree it can get to (to 124 m), the reason said, a path ordered straight or at 45 degrees on corners of blocks; blob 33, blobs of 30 to 32 still read. **Structures along such paths are his next topic: nothing built** (a house stands square to the blocks today, whichever way its path runs). **His answers to both rounds, the same day, built on the same branch, gated, not merged** (`Handoff_2026_11_19_stockpiles_and_reach.md`): "we go back to variable size stockpile, placed along the path, the new design document I added is to be integrated" (the player's stockpile zoned corner to corner again, any number, open beside the stockyard: the logistics network's first pass, its later passes ordered in the brief), the carpenter by skill, the windows' trim inside too, foresters to 250 m ("Let workers go 250m for resources, wood is a vital resource"); blob 34, blobs of 30 to 33 still read. **Owed from it, in this order: buildings at 45 degrees without steps ("is there a way we can just turn the buildings and build them at a 45 degree angle without stepping?": one wall drawn so in a scratch build, the roof not tried), porters, gatherers and hunters to 250 m, the network's stock hands.** Trees growing back: his to open ("we can do that later"). After that, his word: "a lot of polishing to do". **The same evening** (`Handoff_2026_11_19_turned_building_and_workers.md`): "for the next couple of days we will be polishing, so hold off on the integration, we are goning to finish up the current projects" (**the network's later passes held**), "can't we just \"detatch\" the entire building and rotate it?" (answered with a still of a whole hovel drawn turned, in a scratch build; chosen as the way; its steps in the brief), gatherers and porters to 250 m built (blob 35); the calls rest by his word. **Step one of the turned building built** ("Ok step one of the turned building": `Handoff_2026_11_19_turned_building_step_one.md`): a building's blocks drawn turned as one piece, casting and lit so (`--turn-houses` to look); his question of a second storey's stairs answered (the walking map has it; nothing built); then step two ("ok next step": `Handoff_2026_11_19_turned_building_step_two.md`): whoever is within a turned house's walls, their cloak, the bed, the door's leaf and the trim drawn through its turn; then step three, half ("Ok step 3": `Handoff_2026_11_19_turned_building_step_three.md`): a hovel beside a path at 45 degrees placed turned, the turn kept and saved (blob 36), its builder and ladder with it; then the ground of it ("you're doing a great job, continue": `Handoff_2026_11_19_turned_building_ground.md`): made where the house is drawn (levelled, cleared, walled, of its lot), its floor laid there, its door's way square to the path, the ground kept off by who walks (blob 37; `tools/turned_streets.sh`); then step four's pointing and cleared roof (`Handoff_2026_11_19_turned_building_step_four.md`: a turned house pointed at, and cleared, where it is drawn); then his answers of the same evening (`Handoff_2026_11_19_turned_floor_and_hillsides.md`): the turned floor's edge stepped by the texel under the wall, and a turned hovel placed wherever a square one would be, hillsides too; then the far view through the turn and his three answers (`Handoff_2026_11_20_far_view_and_answers.md`); the stockyard beside a path at 45 degrees put to him as three ways; the rest of the workers' 250 m (`Handoff_2026_11_20_ways_told.md`): gatherers and porters told of ways that are not there, the hunters put to him; and, on his "Ok go on with the second way for the stockyard", **the stockyard laid out along a path at 45 degrees** (`Handoff_2026_11_20_stockyard_along_a_path.md`; blob 39): its lot, places, ground, fence, gateways and coverings made for real along the path, its storehouse drawn turned and, once its walls and roof are up, walked where it is drawn; then, on his "Let's do that, and what do you think about turning the fence too? The outdoor roof covering needs a smoothing pass" (`Handoff_2026_11_20_walked_hovels_and_yard_pieces.md`; blobs 40 and 41), **a turned hovel walked where it is drawn**, **a stockyard's coverings' roofs smoothed** by its builder and **a turned stockyard's fence drawn along the path**; his answers to its calls (owed, not built: hovel walls solid, the fence's posts turned too, a roof's rounded edges one piece along each edge and every thatch roof textured alike, and whether building at an angle should act like the straight builds or be done another way) are at the top of the newest handoff, `Handoff_2026_11_20_walked_hovels_and_yard_pieces.md`, "Next session: start here". Of the story nothing is built but what he asked for: "we aren't doing the player and advisor thing just yet".
- **LIVE (2026-11-20): zones put down whole, on grids of their own, by his design** (his words whole in `docs/handoffs/Handoff_2026_11_20_placements_with_paths_and_the_square.md`; the passes and the sizing of the zone's own grid in `docs/production/briefs/Stage_6_brief.md`, "Zones put down whole, on grids of their own"). It answers the question the round before left with him (whether building at an angle causes a lot of issues): the first of the two ways, with the placed zone as the thing that has a grid of its own. **Built on branch `stockpile`, not merged**: the covering's roof; the stockpile a box put down with its path (held, turned by Z and X, drawn to paths three ways, refused with its reason shown; blob 42); the homestake and the campfire one square with its path round it (blob 43). **Next, in his order**: housing pulled with its path (one side, the other or both by the turning key); the stockyard a box; the zone's own grid in the engine, the stockyard moved to it first (its fence's posts, its coverings, its storehouse), then the hovels; the lots' polish last ("We can polish how the lots are built after we get through all of what we have on our plate"). His items "hovel walls solid" and "turn the fence posts" come with the grid, not before.
- **MERGED 2026-11-22, on his word** ("For now merge everything, and we will work with that state"): branch `stockpile`, everything of the two entries above as far as it is built, gate 86 (`docs/handoffs/Handoff_2026_11_22_corners_and_mends.md`). **Next, his to open after his playtest: the horses for the cart and how the colony arrives** ("they will be pulling the cart to the spot with the horses, it won't be magically popping in with the people"); the colony with no cart on a hillside is mended with it.

## What the ground costs to keep (ACCEPTED 2026-11-14, on `main`: "I accept ground-memory"; see docs/handoffs/Handoff_2026_11_14_ground_memory.md)
- His words: "the inhabitants don't care what texture the objects are only the player does, so let's find out what the 68kb is, 4.7 GB isn't going to be acceptable, so we need to be smart about this"; then "Sure build the compact summary ... we want to be comfortable on 8gb of ram, that means consuming 4gb is our ceiling, I propose we scale back boulders on mountainous terrain by about 80%, let's compensate with increasing boulders on open terrain by 30% ... Let's see if we can cut the burried skin down to 4kb a stack, and see what that buys us."
- Counted over the whole map, what is kept of a stack for the simulation was 68 KB: the ground summary 32, fine bricks 28, grids 7. Built, storage only (the eight logs line for line, the stress states those of `main`): the summary kept small (3.7 KB), the fine bricks kept small (3.9 KB; the buried ground 0.9 where it was 8.0). A stack 15.5 KB; the whole map kept 992 MB where it was 4,355; the game at its default view 62 MB lighter (measured).
- The generator's skin at 1 m was tried for his 4 KB and not taken (it changes what a reader below the skin is told).
- Boulders: a fifth on the mountains, three in ten more on open land, by the generator's mask (9,935 -> 4,477 over the map). Generator 14; all eight logs recorded again. For the eye; nothing in memory.
- **His ceiling: 4 GB for the game.** In the framework's decisions.
- The whole map held for the simulation with only the mesh streamed was put to him as the other thing that could come next, beside the stockpile; he chose it (the next entry).

## The whole map held (ACCEPTED 2026-11-15, on `main`: "let's merge what we have now, let's keep the whole-map, we paid for it"; see docs/handoffs/Handoff_2026_11_15_whole_map.md)
- His words: "ok build it with the whole map solid we can do that now before the stockpile", after asking what it would cost to cover the world with one mesh ("far mountains need a texture, they don't need detail, but something has to be there").
- Measured first: with every stack loaded the band's 41 days took 85 s for 5.5 (what was loaded had bounded the colony). Built: the colony reads its own ground and nothing beyond; what the player plans is read from the ground that is held; the game keeps every stack's blocks and streams the meshes alone (1.5 to 1.6 GB held where it was 0.55; the whole map in 12 s after the first frame); the streaming's two silent limits removed. The eight logs line for line, none recorded again; the stress states those of `main`.
- The far land (the world as one coarse sheet past the view, a thinner haze): built, tried by him, and **off unless asked for** (`--far`): "far is ugly with the flat terrain and popping assets, the fog works better in that state."
- Calls not spoken of, standing as built: the game's colony ground two stacks wider; a stockpile or the camp past the work radius widens the band's ground; released water runs as at a wide view whatever the view.
- **Next, his word of 2026-11-15: "if we are going to rework rendering let's go all the way, let's figure out how to get everything in view ... Let's sidetrack, and try and solve this to the full extent that we can" (his list of techniques is whole in the handoff) "... consider them, and let's see if we cannot crack this."** On a branch of its own; measured before it is built; behind a switch.

## The far view (ACCEPTED 2026-11-15, on `main`: "ok looking good, great performance ... Merge it, and on by default"; a second round on his answer built, gated and merged with it 2026-11-16; see docs/handoffs/Handoff_2026_11_15_far_view.md and Handoff_2026_11_16_far_view_haze_and_shadows.md)
- His words: "if we are going to rework rendering let's go all the way, let's figure out how to get everything in view ... consider them, and let's see if we cannot crack this" (some twenty techniques; the handoff answers each).
- Measured first (`lod_stats`): the whole world as its own blocks at 0.5 to 4 m, in rings, is 6 to 8 million quads beside the view's 4.7.
- Built: `Castle.Lod` (a tile of the world reduced and meshed), drawn by the land's shader in rings about the focus to the map's edge, cross-faded by a fixed pattern, tiles fading in as they come, made again when edited; the haze from the view's edge to 3,600 m. `--no-lod` is `main`'s picture to the pixel.
- Costs 0.0 to 0.5 ms a frame as a rule (1.06 at the lake), 62 MB of the quad buffer, whole in 6.6 s on 31 workers (47 s on three).
- His calls: the haze; how far each level lasts; rings by the focus or the eye; no sun's shadows past the view; far water; grass ending at the view's edge; on by default and merged or not; the far land out or kept; what next of his list.
- **His answer (2026-11-15), and the round built on it**: "the white dot dithering for the LOD rings" found to be holes and closed (108 pixels of sky in one view to none; a dark floor under the land for what is left); "Keep the shadows pst the view's edge" (two depth maps over the whole map, and what stands past the view cast into the view's own maps); "If we can do the same with the water mirror" (far water walks the picture as near water does); "a haze 1m or so the trees poke above ... an opaque boundary haze ... a 12m ring around the map ... fingers between the saddles and ridges" (a haze on the ground, its depth from the generator's map, thin at the focus and three quarters far off; the rim all haze over 12 m); "remove the old far land, but keep the functionality" (out of the game, its code compiled and checked). Costs +0.03 to +0.25 ms a frame at the twelve views. Of the three he left to me (a cheaper shader, rings by the eye, the tiles made with the map's holding) none built: the first measured (a quarter at best, not half), the second with the on-foot view, the third would make what he sees come later.

- **A structural inspection, 2026-11-22, on branch `inspection` (gated; merged the same day on his word, "Okay, merge the branch")**: his four points (his design document brought into the project; the files checked against each other; the code looked over; the project made easier to work in). No rule of the game changed. `docs/handoffs/Handoff_2026_11_22_structural_inspection.md` has what was found and his calls; `docs/production/State.md` is where the project stands from here on.
- **His notes after the merge, 2026-11-22, on branch `playtest-notes` (gated, not merged)**: the development entries of a person's menu (Cook, Builder, Stockman, Carpenter), the eaters' arms, a deer in two halves on steep ground, herds put down up trees, the sleeper's cloak through its clothes, clothes of cloth (tried, dropped), the serfs with more form. Each behind a switch that gives the game as it was; no blob bump; the kept logs line for line. `docs/handoffs/Handoff_2026_11_22_playtest_notes.md` has each fault as it was reproduced, what was found on the way and his calls. **Next, in his words, is the arrival: the horses for the cart and how the colony arrives** (`docs/production/State.md`).
- **His notes of 2026-11-23, on branch `playtest-notes-2` (from `playtest-notes`; gated, not merged)**: the zones' lost ground mended; a site's ground worked from beside it and a storehouse's there and back; a path stepped where it meets trodden ground and a door's way made again to its path; a deer butchered by whoever carries it home; a stockpile's place made level when something is put on it, and room round the cart; the truss to the ends of its wall, symmetrical (blob 45); the player removes a stockpile (blob 46); builders with no house of their own help at a larger one; and, found on the way, a walker at the height of the place it steps into (nobody left standing in a step). `docs/handoffs/Handoff_2026_11_23_paths_builders_and_stockpiles.md`. His calls there: the merge; whether a stockpile is to be flattened whole; what becomes of the goods of a stockpile removed, and what when it is the only one (a band left with none starves); who helps, where and how many.
- **His answers of 2026-11-23, merged that afternoon on his word**: the stockpile stepped as it was, and refused where its ground is too steep (`--no-steep-refuse`); built the same morning and set aside (`--pile-flat` gives it): a stockpile is one level, where it is put down, at the level of its path side, the land cut or filled whatever it is made of, the stockpile all of what was marked (`--no-pile-flat` gives each place by itself). `docs/handoffs/Handoff_2026_11_23_a_stockpile_is_one_level.md`. His calls there: the merge; the level (its path side's or its middle's); a boulder in it cut away or left standing; its banks bare or walled.

## After that pass, in John's order (2026-11-12; NOT DESIGNED, his to open)
(Written 2026-11-12 and overtaken: sleeping and beds came with that pass's second round, and the stockpile he designed himself on 2026-11-17. Where the project stands now is `State.md`.)
- "That we can do for this pass, then we will have an intermediate sleeping, beds, campfire to house transition. After that we will get to the stockpile, and how the player manages this."
- So what the brief called 6b comes third: sleeping and beds first.

## Stage 6b: stockpile mechanics (NOT DESIGNED: asked of John; behind sleeping and beds by his word of 2026-11-12)
(Written before 2026-11-17 and overtaken: he designed it in passes that day, `briefs/Stage_6_brief.md`, "His design of it"; built since and merged 2026-11-22, the entry "MERGED 2026-11-22" above. Kept as it stood.)
- **John, 2026-11-13, of serfs left standing with a load when a stockpile is full: "when we get to the stockpile mechanics we will reserve a portion of the stockpile for overflow".** His, and the one thing of 6b that is: how much, for what kinds, and what a serf does when that too is full are still to ask.
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
- Water fetching (buckets, then barrels): once something uses water (cooking, building) and barrels exist. (Since 2026-11-17 porters draw it into the storehouse's two barrels; nothing uses it yet.)
- Stone demand from masons (paving the paths with stone): replaces the starting quota.
- Uses for meat and hides: meat is eaten in stage 4 (hunger), hides wait for a tanner.
- Deer extras: the tail's flag when alarmed, ears turning, lying down, dying of age, herds splitting or
  new ones arriving.
