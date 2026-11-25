# Castle Game — Production Framework

Nov 9, 2026 · @John

## How to use this framework

This is the entry point for any new session on Castle Game, in Claude Code or in chat. It holds what stays true between stages: the design pillars, the architecture rules, the phase plan and the working protocol. It does not describe the code; the README does.

Load documents in this order, and only the parts the stage needs.

| Order | Document | What it answers | Load |
| --- | --- | --- | --- |
| 1 | Production Framework (this) | What must stay true, where the project is going, how a stage is run | Every session |
| 2 | docs/production/Production\_plan.md | Which stage is live, its scope, what was deferred | Every session |
| 3 | The latest handoff, in docs/handoffs | What the last session changed, measured and left open | Every session |
| 4 | CLAUDE.md, in the repo | Standing rules agreed with John for terminal sessions | Every Claude Code session |
| 5 | README.md and docs/systems | The project in perspective, with one README per system for how the code behaves | The main README every session; only the system READMEs the stage touches |
| 6 | Design documents, in docs/design | Intent for systems not built yet | Only the one the stage implements |

Since 2026-11-22 a session starts from `docs/production/State.md`, one page that says where the project stands, what is next, what is on hold and where John's open calls are; `CLAUDE.md` has the order of reading. The table above stands for what each document answers.

Three terms keep the plans apart. A phase is a group of stages that ends at a playable gate. A stage is one unit of work that ends with a check, a demo, the README, a zip and a handoff. An era is a period of play inside the game, such as the opening or the early colony.

The work order for bringing the production folder in line with this framework is in Restructure plan.

## Design pillars

Every module is judged against these ten rules before it is built and again at its stage close. They condense the design report of 5 November and the design conversations that followed.

| # | Pillar | What it means for a module |
| --- | --- | --- |
| 1 | The player says where; demand says what and when | A zone, path or order states intent and priority. It never places a building or orders a product, and it cannot produce what the settlement lacks the capacity to make. |
| 2 | One controllable character | Only the player's own character is controlled directly. Everything else is the starting jobs, zones, paths, reserves and protections, and later hiring and promotion. |
| 3 | Serfs are self-reliant | People meet their own needs first, then turn to their wants. If a need can be met within reach, the colony assigns the job itself. No alert asks the player to fix what a serf can already see. |
| 4 | Failure is visible and recoverable | When autonomy fails, a serf says why. The fix is at the level of zones, paths or priorities, never single blocks. |
| 5 | Conditions improve things; clicks don't | Buildings and trades advance when occupancy, materials, skill and demand allow. There is no upgrade button. |
| 6 | The seat is the exception, and it costs | The player designs his own house, manor, keep and castle. They draw on the same labor and materials as everything else, and he decides when to start. |
| 7 | Emergence over scripting | Scarcity, opportunity cost and simple wants and needs produce the events. Managing a resource is never told to the player: ask too large a surplus of meat and the hunters hunt the deer out. With everything running together there is no time to micromanage; this is a lord-of-the-land game, not one played from the pause button. Scripted content is only outside stimulus: traveling merchants, vagabonds, troupes, foreign relations, battles. |
| 8 | Evidence, not explanations | Reports state true conditions within an official's remit. The game never assembles the causal chain, and not knowing does not excuse the player. |
| 9 | Few natural parameters | A behavior is a simple function with a handful of named tunables. No custom AI per occupation and no special case per shortage. |
| 10 | Progression teaches governing | Play starts at ground level with communal labor and grows into wages, taxes and officials. Each layer the player ran by hand is one he later delegates. |

### The player's interface (agreed 2026-11-09)

The game is a hybrid of an RPG and a colony sim: the player is one person in the world, and what he can affect is bounded by what that person can do.

| Rule | What it means |
|---|---|
| Micro and macro | Micro is on foot, over the shoulder in third person or, if the player likes, first person: the player can do anything a serf can (gather, hunt, carry a deer). Macro is the view from above, offered only where the task needs it: placing the stake, zoning, pathing, blueprinting his own house, manor, keep and castle. |
| See and near | On foot the player inspects and orders only what his character can see and is near. Reach grows by delegation, not by camera: later, advisors take a decision and carry it out, and the world reacts as the command spreads. |
| No interruptions | Nothing takes the player out of the world: no conversation screens, no modal dialogs, no alerts. The flow stays streamlined; engagement comes from acting in the world, not from managing panels. |
| Tooltips say, context menus do | A tooltip is as rich as the thing looked at: for a person, the job and title, the current task and status, skill progression, and later needs and wants. A context menu holds the detailed controls, delegation among them. Both hang on the thing under the player's eye. |
| Reports live in the world | Colony-wide status is not a task bar, menu or tab. Once the player has advisors and a house or manor with an office and a desk, he reads reports there. |
| The dev interface is the scaffold | The panels, tabs and lists of the development build give easy access to everything while the game is built. They are not the player's interface, but they are built as the standing structure for it: the same widget layer and the same data views are what the tooltips, context menus and desk reports are later made from. |
| One set of actions | Every player action is a call on the simulation that the dev interface, the game interface and scripts all use. No interface has an action of its own. |
| Information belongs to what is in the world | The interface only shows an aggregation of what things in the world already know. A zone is the unit of aggregation: it gathers what goes on inside its borders. So there is no report on vegetables growing wild, but there is one on a farm's field once farmers plant it. Nothing is known that nobody tends. |
| The player's own HUD | Always there: the basics of his world (time, day, speed), his person and his inventory, and the build and zoning tools. Opening the world tools is what gives the view from above; closing them returns him to his feet. |
| One kind of actor, narrowed by permissions | The player's character and every serf act on the world through the same set of actions. Role, rank and position narrow what each may do; the player is the actor with the widest set, driven by hand. A context menu is the list of what this actor may do to that thing, so it grows with the player's capability and role (talk, delegate a task within the person's job, arrest once there is law). |
| Delegation runs downward | An actor delegates only to those under him, and only within their job: the player to anyone, a farmer to his farmhands in answer to demand, a farmhand to no one. Never upward, never sideways. Near, it is done directly; from afar it is passed through those who can carry it. This is the administration of the settlement: hierarchy, roles and permissions. |

### Needs, then demand (agreed 2026-11-09)

A person nobody has delegated to tends only his own needs (hunger, sleep, and later wants). Delegation adds a demand he must meet on top of his needs. Meeting it, he may delegate in turn to those under him: a farmer has a demand for crops, and farmhands work it for and with him. Three numbers describe every such post, and they are what the balance pass later tunes: capacity (how many he can direct), efficiency (how much his direction improves their output), and skill, which modifies both.

### Demand drives demand (agreed 2026-11-09)

Demand starts with the people and runs up the supply chain. Serfs demand food. The stockpile is the supply chain made solid, so their demand lands on it; the stockpile in turn places demand on whoever can produce what it lacks (a hunter delegated by the player has the capacity, so he has the need to hunt). When the stockpile holds what is asked, the serfs meet their demand by withdrawing from it.

Met in the moment, demand vanishes: the stockpile asks for nothing, production halts, and supply see-saws with never a surplus. So the player adds artificial demand by requiring a surplus, which buffers the flow. Goods, services and production all work this way, and the economy emerges from it. The player's task is never to feed the serfs; it is to see that they have the capacity to feed themselves.

For the demand table this means three kinds of row, linked in a chain: what people consume (derived, never set by hand), what a store is short of (derived from the first and from the surpluses asked of it), and the surplus the player requires (the only kind he sets). Producers answer the second.

### Hooks to build before more mechanics (agreed 2026-11-09)

So that later systems plug in instead of forcing rewrites, these go in early, each with no new behaviour of its own:

| Hook | Today | What goes in | First real user |
|---|---|---|---|
| Who directs whom (in, 5a) | A job per member, set by the player | Each member records who delegated its work (the player today), saved | The first trade with helpers |
| Demand as a table | Reserves, "wanted" and the winter store are separate numbers | One table of demands: what, how much, who asked. The existing orders become its first rows | Farms, workshops, the supply and demand window |
| Actions and permissions (in, 5a) | Scattered calls (Set\_Job, Zone\_Stockpile, ...) | One table of named actions, each with what it applies to and who may do it; the context menu and scripts read it | The player's character; law |
| Work rate and capacity (the rate: in, 5b; capacity waits for the farmer) | Every work timer is already multiplied by one function (slower when starving) | That function becomes rate = condition x skill x direction, and capacity becomes a function too; work times get names | Skills (5b); the farmer |
| Zones as things (in, 5a) | Stockpile cells are loose; the camp is a single special case | A zone record (kind, bounds, what is inside it), with the stockpile and the camp as its first two kinds | Habitation (6), farms (10), reports |
| Data views (in, 5a) | Panels fetch and draw their own data | A view per person and per zone that a panel, a tooltip or a desk report can show | Tooltips (5a), reports (E) |

Settlement generation follows one more rule from the building conversations: constrain first, derive after. Pathways set the public edge; massing, terrain, openings, style and props follow in that order, and no step may break a constraint set before it. A blueprint is a pure function of its pathway context, seed, occupancy and improvement level.

## Architecture

The engine is Ada 2022 on OpenGL 4.5, built in layers that only look downward: the simulation decides, and the figures and renderer only show it. Source is in `src/castle-<package>`, checks and tools in `tools/`, the executable in `game/`.

| Layer | Packages (Castle.\*) | Owns |
| --- | --- | --- |
| Foundations | Dims, Hash, Noise, Math, Fields, Jobs, Colors, Blocks, Text | Dimensions, counter-based hashing, noise, the palette, block and brick formats, parallel loops |
| World generation | Terrain, Geology, Deposits, Hydrology, Flora, Climate, Channels, Stacks, Chunks, Worldgen, Maps, Currents | A pure function of seed and Generator\_Version: the 2 m skin, veins, rivers, trees, weather |
| World state | Edits, World\_Blocks, Water, Saves | Edits written over the generated world, block lookups and ground versions, live water, save files |
| Navigation | Nav, Marks | The walking map (0.5 m cells, up to four floors) and travel-time routes |
| Simulation | Colony, Herds, Buildings | The clock, the band, jobs, stockpiles, needs, standing orders, herds; tier-1 blueprints as a prototype |
| Figures | Bodies, Poses, Second\_Order, Serfs, Deer, Animals, Figures, Props, Fire | Genome to rig and skin, two-bone IK, steppers and filters: movement as presentation; props, and a fire's flames, sparks and smoke |
| Rendering and platform | Streaming, Mesher, Textures, Render, Camera, Platform, GLFW, GL, Input | The worker pool, greedy meshing, one quad buffer, shadows, sky, key bindings |
| Interface | Font, UI, HUD | The immediate-mode 2-D layer and the game's panels |
| Tools and game | tools/, Preview, Iso, PNG, game/castle\_game.adb | Headless checks, previews and tuning statistics; the executable wires the layers together |

Checked against the source at commit 246455d, the rule holds with two leaks. Castle.Colony depends on no renderer, interface or serf presenter, and reaches the world through callbacks the game sets (Set\_World, Set\_Trees). Castle.Herds, though, uses an enum from Castle.Animals, and the colony takes the genome and deer class types from the figure packages.

### Rules that hold across layers

| Rule | How it shows today |
| --- | --- |
| The world is generated, never stored | A save is the seed, Generator\_Version, clocks and edits. Change what the generator makes, bump Generator\_Version, and older saves are refused. |
| Same start, same result | The colony runs 20 fixed steps per game second. Water, climate and river depths use exact arithmetic, and the survey checksum must not change with the worker count. The build sets -ffp-contract=off, so floats never depend on the machine. |
| The simulation decides; figures follow | Castle.Colony decides and Castle.Serfs only shows it. Bodies follow their targets through second-order filters solved exactly per frame. |
| One edit path | A serf picking a bush or felling a tree writes the same block edits a player's click does, so the result is saved and drawn like any other. |
| Reserve, then act | Bushes, trees, cell room and butchering cells are reserved first. An unreachable target is left alone for a minute, and the serf states the reason. |
| Every unit is counted | Checks account for every handful, log and joint as stored, carried, lying or eaten. Water keeps a ledger to the unit. |
| Saves resume exactly | Each subsystem's blob has its own version, and older blobs still load. Save, load, save must give the same bytes mid-activity. |
| Everything is scriptable | Each feature has command-line options, so checks and demo recordings run headless and repeat exactly. |
| Colours are named | Materials name an entry in Castle.Colors, and color\_palette.txt is the source. |
| Stay light | One simulation thread, with workers for generation and meshing. Water gets at most 6 ms of a frame and 48 awake stacks. |
| Mechanisms first, balance last | A stage gives its tunables first values that let the mechanism run. Nothing is rebalanced when a mechanic is added; the whole game is balanced once, in phase G. |

### What a new module must deliver

1. State that steps on the colony clock and is kept in a versioned save blob.
2. Decisions in the simulation layer, with poses and props for what is seen.
3. World changes through the edit path, with reservations, a fail memo and a stated reason for every way it can stall.
4. Named tunables with first values at the top of the package spec, the project's convention, so the balance pass can find every one.
5. Command-line options to set it up and drive it, and its counts in the colony log line. The options work in the windowless runner (colony\_run) as well as the game.
6. Enumerations that are saved by position (Item\_Kind, Job\_Kind, Task\_State, Why\_Idle) get new values on the end only.
7. A headless check of its rules, its accounting and an exact save round trip.
8. A README section, including what is not there yet.
9. A pillar check: nothing asks the player to do what a serf could, and every failure shows its reason.
10. The reference run's log (seed 1, the reference setup, in colony\_run) kept with the stage, so a later stage can see when a new mechanic changed an old one. It records; it does not balance.

## Current state

Since 2026-11-22 where the project stands is kept on one page, `docs/production/State.md`, rewritten at every close. What follows is the record of how it got there, as it was written session by session to 20 November 2026.

As of 10 November 2026 the alpha runs a band of six that feeds itself through stage 4's food and needs, and stage 5a has put the scaffold of the interface under it: zones, directors, the action table, data views, picking, tooltips and context menus. Stage 5a is closed and zipped (castle\_game\_stage5a.zip).

Stage 5b (skills) is closed and zipped too (castle\_game\_stage5b.zip): people have levels and aptitudes, every work timer runs at condition x skill x direction, and skill grows by doing. John accepted it as built, with tuning to come.

A last pass before stage 6 was built on 11 November 2026, on branch `models-pass`: models drawn rounded, the bow and the axe carried, foliage drawn soft, the herds fleeing together and out of water, the edges of paths drawn ragged; and, from John's answer the same day, a quiver, grass drawn as tufts, and generator 13 (trees reshaped, tall grass in drifts) (Handoff\_2026\_11\_11\_models\_pass). John accepted it as built that day ("impressive, the world is in desirable state, merge it into main and prepare for a session clear") and it is on `main`; its values are first values, his to tune. Stage 6, habitation with stockpile mechanics, is next and his to open.

Touch-ups and a stress test followed the same day, on branch `sky-and-weather`: the sun's disc never dark, a moon, the clouds walked through, mist, wet surfaces and the lights made a table, with docs/production/Stress\_test.md for what the stress test found (Handoff\_2026\_11\_11\_sky\_and\_weather). His answer the same day asked for moonlight on the land, the moon's phases and stars ("Sounds great"), which are built as a second round on that branch, and settled two things (multisampling stays; no budget of time for the colony's steps: Decisions in force). Accepted as built that evening, with the pathing work below, after he had tried both: "perfect, everything checks out, looks awesome and works great". Both are on `main`.

The rest of that answer handed over a note on pathing ("that is for pathing optimization, up to you how we implement it"). It was measured before anything was built, and what cost was not what the note expected: a goal out of reach is known at once, source searches are kept and the walking map is mended, which takes the colony's steps from 8.3 s to 5.9 for the reference band's 41 days and from 30.5 s to 9.1 for forty-eight's twelve; the route store and the coarse graph of the note are left for when there are buildings to anchor them to (Handoff\_2026\_11\_11\_pathing; routes.md, "What routing costs"). Accepted as built with the touch-ups, in the same words.

With that acceptance he asked for one change to the water: falls that arch and stand off the wall ("can we make it more of a arch, water rollong over itself ... have the water extend from the wall face so it doesn't become just streams down the wall face"). On branch `falls`, water leaving a column over a drop is drawn as a sheet thrown from the lip, from the speed the simulation has it leaving with; the simulation itself is untouched (Handoff\_2026\_11\_11\_falls; water.md, "Falls"). Accepted as built the same evening, after he had taken water from the mountain lake down to a village in the valley by reservoirs chained one below the other, each held back and let out to the next, and held it by the village behind a dam: "That is perfect ... Everything flows and looks perfect now." On `main`.

Stage 6 was opened by John on 11 November 2026 ("we have completed our preperations on the engine and gotten things in a state to continue with stage 6 ... you're in control, go cook"). Nothing of it had been designed, so it was drawn from the design documents with first rules and values of mine (Stage\_6\_brief) and split as stage 5 was: **6a, habitation, was built on branch `stage-6`, put to him (Handoff\_2026\_11\_12\_stage\_6a\_habitation) and accepted as built on 12 November 2026 ("ok the building looks great, I am impressed, works wonderfully on my end as is"): it is on `main`.** A housing zone along a path, a hovel begun for everyone without a home, builders from the foresters raising them block by block from logs and straw, the owner asleep under its own roof. While it was being built he answered two of its calls ("continue, one hovel per person for now, dirt discarded is fine for now") and, later the same day, added references ("I have added some design refrences in the "/Design Refrences" folder," with a text on the twelfth-century peasant house: `~/CASTLE_GAME/Design Refrences/`, outside git), from which the hovel was remade as far as was cheap: a timber frame filled with wattle and daub, a floor of beaten earth, small high windows; what of them is not built (the hearth first) is put to him. With the acceptance he asked for a pass on building and zoning (retaining walls and stone stairs where the ground rises and falls, roofs smoothed by their builders, housing zones pulled along a path and combined), **which was built on branch `housing-pass` and put to him five times, each round on what he said of the one before (Handoff\_2026\_11\_12\_housing\_pass), and accepted on 13 November 2026 ("accepted"): it is on `main`** (with the fourth he gave the first of the story: the player a minor noble sent by a lord to improve the land, a small workforce and a minimum of supplies, taxes after a few years; of it only the lord's cart of salt is built), and gave the order of what follows: "That we can do for this pass, then we will have an intermediate sleeping, beds, campfire to house transition. After that we will get to the stockpile, and how the player manages this." **Neither of those is designed; 6b, stockpile mechanics, is now the second of them**: the brief lists what was asked of him about it. Phase B's gate is not called: it is his to say, with the decisions due at this stage's close (Open decisions).

Two standing rules came with that answer (John, 11 November 2026). **No save compatibility during production**: "don't worry about ever being compatible about mainting compatibility with old saves during production". The generator and the save layouts change when the game wants them to; the version is bumped and older saves are refused. **Realism only as far as it is cheap**: "full animations are not important, we want a happy balance between realism and immersion, so just enough realism to be immersive without being expensive and time consuming".

The first winter runs its course and is touch and go. On seed 1, none of six dies when the band has a forester and two when it has none; before the pathing work of 2026-11-11, with the same rules, it was one and none, and on generator 12 it was four and all six: it turns on a hunt or two. Balancing it waits for phase G.

| Item | Value |
| --- | --- |
| Code | CASTLE\_GAME/GAME\_alpha\_1\_3/compiled, git, branch main. The latest zip from main is castle\_game\_housing\_pass.zip (castle\_game\_falls.zip before it), a git archive, in CASTLE\_GAME/releases. The plan, handoffs and design documents are in the repo under docs/ (CASTLE\_GAME/DOCUMENTATION is their old home). |
| Toolchain | Ada 2022 with GNAT (GCC 13 or newer) and gprbuild; GLFW 3; OpenGL 4.5 or newer |
| World | 2048 x 2048 x 256 m, 0.25 m blocks, 8 x 8 m stacks, a 60-day year |
| Generator\_Version | 14 (a fifth of the mountains' boulders, three in ten more on open land, 2026-11-14; 13 was trees reshaped and tall grass in drifts, 12 tarns, 11 wild vegetables); older saves are refused, and by John's rule of 2026-11-11 nothing is done to carry one over |
| Game save format | 6 (the level source water rests at; 5 brought the colony blob) |
| Colony blob version | 25 (the lord's cart pulled into a stockpile; on `main` since 2026-11-13), 24 before it (the lots laid out, a house's reach, the beds, each one's place by the fire, the band's pace, the fourth round's: the cook's hold, the lord's cart and its salt, ladders, and the fifth's: holes under a path filled; 18 to 23 refused, 23 the fourth round: 20 was a house's front yard and its stone, 21 the pass's second round, 22 its third); on `main` 19 (the houses, and the house each builder is at; 18, its first layout, is refused); before stage 6a 17 (the herds' own blob 2: whether they scatter as they were, each deer's start; nothing of the colony's). 16: extra hands, stretches, the camp's floor, earth. 15: how far the band looks, each member's metre of path; 14 each zone's ground and what is built on it, the band's labour, the fire's dying down; 13 the demand chain; 12 skills; 11 zones and each member's director) |
| Checks | Nine pass in debug: water\_sim, edit, ui, dynamics, serf, path, colony, deer, pick (colony\_check 475, pick\_check 38, and an eighth reference log, with housing, since stage 6a; colony\_check 635, path\_check 69, edit\_check 32, pick\_check 59, and the seven older logs held at `--no-beds --pace 1 --no-cook-hold --no-curing --no-path-holes`). Six known warnings. colony\_run --expect HASH makes any real-world run a test; tools/reference\_check.sh holds the colony to seven kept logs (everything on; the herds as they were; and with that, extra tasks and paths as they were, paths laid as marked, the band's labour off, no demand chain, no skills), all regenerated on generator 13. flora\_stats fails if a tree reaches past the generator's reach. |
| Jobs | Idle, gatherer, forester, hunter, porter, cook |
| Standing orders | Spare apples, wood reserve, straw reserve, stone wanted, Spare deer, meat reserve, vegetable reserve, winter store |
| Source size | About 42,000 lines of Ada. Castle.Colony is about 6,500 of them: a 710-line spec, a 1,970-line body of state and stubs, and 53 subunit files. game/castle\_game.adb is about 2,700. |
| Interface | Two interfaces on one widget layer. Development: panels on Tab and the F-keys, the band's in five tabs with a scroll list. The game's own, so far: a tooltip on what the cursor's ray points at and a context menu on a right click, from Castle.Views and Castle.Actions |

```sh
gprbuild -P castle.gpr -XCASTLE_MODE=debug -j0
for c in water_sim edit ui dynamics serf path colony deer pick; do ./bin/debug/${c}_check || break; done
gprbuild -P castle.gpr -XCASTLE_MODE=release -j0 && ./bin/castle_game
```

| System | What is live |
| --- | --- |
| World and seasons | Terrain, root-like veins, rivers and lakes, five kinds of tree, berry bushes, wild vegetables, weather, snow and ice |
| Editing, saves, live water | The edit store, atomic saves, source water that drops beside a cut and comes back to its level, released water that settles, soaks away or dries; water drawn stepped, coloured by its depth, and mirroring the land round it; water over a drop drawn as a sheet thrown from the lip |
| Light and shadow | The sun's shadows held still, cast by the land and by everything drawn as a figure; a fire of small rising pieces whose light casts shadows of its own; the clouds walked through, a moon with phases whose light casts shadows, stars, mist, wet surfaces, a table of up to 64 lights |
| People and routes | Seeded serfs with IK and a stepper; travel-time routes that are planned again when the ground changes |
| Colony | Homestake, paths, stockpiles and the camp as zones (each the ground it fills: laid along its path, never over one), the camp built by the band, five working jobs, standing orders, a fixed clock; every order through the action table |
| Skills | A level and an aptitude per person and skill; the work rate (condition x skill x direction); skill by doing, with fractions to related skills; nothing gated by skill yet |
| Interface | Tooltips (a person, a zone, a deer) and context menus (a person, a stockpile, the ground) on what a ray points at; the development panels |
| Food and needs | Hunger, sleep, the camp and cook, stew, fending, the winter store, the winter fire, confidence, death by hunger in winter |
| Deer | Four classes, herds led by a node, fear, fawns, hunting with a short bow, deer wandering in |
| Habitation | On `main` since 2026-11-12 (stage 6a, accepted as built): housing zones along paths, a hovel of timber, daub and thatch begun for everyone without a home, builders from the foresters, residency (habitation.md). On `main`: a prototype only, village\_preview |

Left over from stage 4's close list:

- [x] Record the first-winter run: whether the measured band gets through a whole winter on its store
- [x] Stage demo video: colony\_stage4\_camp.mp4 (its command line is not in the handoff yet)
- [x] Production plan: stage 4 marked done, with what is open
- [x] castle\_game\_stage4.zip from a clean git archive
- [x] Closing handoff: the 9 November handoff carries the winter section and the zip
- [x] README: the "Not there yet" line corrected (restructure step 4)
- [x] README: the Saves paragraph now describes format 5 (restructure step 4)

Limits that shape the stages ahead:

- A view wider than about 400 m does not fit the 256 MB quad arena, and at 240 times speed the colony's steps can hold a frame for a second or more, four with a band of forty-eight (Stress\_test.md). With the reference run's standing orders the reference band is five of six after four years; a band of forty-eight starves within the year, which the land was never meant to feed.
- Work happens within 60 to 80 m of the stake, and as a rule only that ground stays loaded. (The colony's ground follows its reach: it widens, to 256 m at most, while the band fetches for its camp from further off or has a path to lay further out.)
- The interface has no text input or draggable windows; the camp and deer have no menu yet; reach is unlimited, since the view is still from above.
- Routes have no coarse graph for long distances (measured 2026-11-11: the longest ways cost 17 ms for a band of six and 28 ms for forty-eight; routes.md, "What routing costs"), and no shutting doors, ladders or crowding.
- The player has no character yet; it is held back on purpose.
- Hides, water and stone beyond the starting quota have no consumer yet.
- Serf clothing, deer coats, props and the interface still carry their own colour literals.

## Phases

Eight phases carry the game from engine to release, and each ends at a gate the game must pass in a headless run before the next begins. A and B are the agreed plan, grouped; C to H are proposed here and are settled one at a time, at each phase's kickoff.

The people are autonomous in every phase. They meet their own needs first and then their wants: they feed themselves, house themselves where housing is allowed, and fill each new skilled trade as it opens.

The player sets the conditions and the starting jobs. From phase D on he also chooses people: hiring, guards, promoting nobles, learning, an army and a council.

| Phase | What the player does | Systems it adds | Gate | Status |
| --- | --- | --- | --- | --- |
| A Engine | None yet | World generation, rendering, edits and saves, live water, the interface layer, serfs, routes | The checks pass, and the same seed gives the same world on every machine | Done |
| B The band | Sets the conditions: the stake, paths, stockpiles and camp, the starting jobs, reserves, and where housing can go | Stages 1 to 6: the colony spine, base jobs, food and needs, the first winter, skills, the first hovels | A band assigned once feeds and houses itself, and the first winter runs its full course on standing orders alone | In progress |
| C The village | Marks where farms, herds and more housing can go, and joins the work in person | The player's character, earned trades with reversion, farms and herds, newcomers and losses, housing that improves | From paths and zones alone, housing, trades and farms appear, and people fill them without further orders | Proposed |
| D The economy | Starts hiring and funding learning, and sets the levies that pay for them | Coin and trade, appointed roles and workshops, wages and levies, the supply, demand and production window, research and tools | Coin makes the full circuit of wages, purchases and taxes, with every coin counted | Proposed |
| E Governance and threat | Hires guards, promotes nobles to a council, and reads its reports | Officials and their reports, unrest and law, bandits and raids, predators and poaching, renown and tribute | With officials appointed, a seeded crisis can be traced from their reports alone | Proposed |
| F Lordship | Raises an army and builds his seat | The manor, keep and castle, walls, an army, sieges, neighboring barons, diplomacy, scripted visitors | A baron's assault plays out from muster to outcome, and the record shows why it went as it did | Proposed |
| G Balance | Nothing new: a script plays the perfect lord | A windowless long-run tool, the scripted perfect player, one balance pass from the foundation up | The reference run: a perfect village and economy from stake to castle, recorded as the baseline | Proposed |
| H Release | Plays a whole run | Menus, options, key rebinding, audio, the chronicle, performance | A run can be started, saved, loaded and finished from the menus, on more than one seed | Proposed |

A gate proves that a mechanism works end to end on first values; it does not prove balance. Nothing is rebalanced when a mechanic is added. The game is balanced once, in phase G, from the foundation up, so each change can be followed into the middle and late game.

The result is the reference run: a perfect village and economy, showing how the game flows when every decision is right. The player is then the unknown variable, and the imperfections he brings to that flow make each run his own.

Phase B's gate is the design report's first build target. The phases track the eras of play in the Organized Design: the opening and early colony in B and C, the middle game in D, the established settlement in E and F.

Each phase kickoff settles the open design questions that phase is the first to need; they are listed under Decisions and risks.

## Stages

Stages 0 to 6 are the agreed production plan; stages 0 to 4, 4R, 5a, 5b and 5c are done. Stages 7 to 12 are proposed outlines for phase C; each gets its own brief before work starts. Phases D to H are staged at their kickoffs.

| Stage | Phase | Scope | Status |
| --- | --- | --- | --- |
| 0 Aquifer layer | A | The aquifer as a field instead of blocks | Done |
| 1 The spine | B | Clock, band, homestake, paths, stockpiles, the berry loop, saves | Done |
| 2 Forester and porter | B | Felling and logs, straw and stone, the first standing orders | Done |
| 3 Deer and the hunter | B | Deer, herds, the hunt, meat and hides | Done |
| 4 Food and needs | B | Hunger, sleep, the camp and cook, wild vegetables, apples, grain, the first winter | Done |
| 4R The runner | B | colony\_run: the real world and the colony with no window, on fixed steps, so gates and measurements repeat exactly; the colony's scripted options shared with the game (Castle.Scenario). 41 game days in 11 s; the same state hash on any worker count, in debug and release | Done 2026-11-09 |
| 5a Interface: the scaffold | B | Zones as things; who directs whom; the action table (one door for every interface, permissions, menus); data views; picking by a ray (a person, a deer, a zone, else the block); a tooltip on what is picked and a context menu on a right click; the band panel in tabs with a scroll list; a scripted pointer for recordings. Colony blob 11. No behaviour changed: the reference log is stage 4's | Done 2026-11-10 |
| 5b Skills | B | Levels and aptitudes; the work rate (condition x skill x direction); skill by doing with fractions to related skills; a Skills tab, skills on the person's sheet and menu; the placeholder cooking number becomes the cooking aptitude; colony blob 12. Job tiers and earned trades wait for the first earned trade; capacity for the farmer | Done 2026-11-10 |
| 5c The demand chain | B | Consumers, stores and producers linked in one table; the existing reserves become required surpluses; producers start and stop at two levels. Gatherers then stop when demand is met | Done 2026-11-10 |
| 6a Habitation | B | Housing zones along paths; a hovel begun for everyone without a home; the hovel a function of its seed; builders from the foresters (the first earned trade), reversion; the zone's houses' needs in the demand table; residency; the hovel remade from John's references of 2026-11-12 (a timber frame filled with wattle and daub). Colony blob 19. An eighth reference log | Done 2026-11-12: built, accepted as built the same day, on `main` |
| 6b Stockpile mechanics | B | Rolled into stage 6 by John (2026-11-11); what he has said of it: "they will eventually start upgrading the stockpile, build a storehouse, warehouse, fences and outdoor storage will get coverings" | Designed by him in passes on 2026-11-17 (Stage\_6\_brief, "His design of it") and built since: the stockpile, the storehouse, the stockyard, the square; merged 2026-11-22. The logistics network's later passes are held by his word of 2026-11-19 |
| 7 The player's character | C | One directly controlled person who can join the work | Proposed |
| 8 Wood and stone trades | C | Carpenter and mason earned by skill, reversion, furniture, paving, wells and water | Proposed |
| 9 Hide and cloth | C | Tanner and tailor, clothing that wears, winter clothes | Proposed |
| 10 Farm and herd | C | Farm and stable zones, seeds, taming, farmer and herdsman | Proposed |
| 11 Newcomers and losses | C | Wanderers and refugees, people leaving, theft, spoilage, burial | Proposed |
| 12 Housing that improves | C | Hovels that gain a storey, a stone base or a stair when occupancy and materials allow | Proposed |

Handoffs so far, newest first:

| Date | Stage | Handoff | Note |
| --- | --- | --- | --- |
| 2026-11-12 | 6a, habitation: built on branch `stage-6`, put to John, accepted as built and merged | Handoff\_2026\_11\_12\_stage\_6a\_habitation | Colony blob 19 (18 refused); colony\_check 475, pick\_check 38; eight reference logs (the eighth with housing); demo colony\_stage6a\_habitation.mp4; castle\_game\_stage6a.zip, of the branch (both remade after the second round: 08066af, 9f7e6b7, 546f22c) |
| 2026-11-12 | A pass on building and zoning after 6a (housing pulled along a path and combined; walls and stairs of stone; roofs trimmed): built on branch `housing-pass` and put to John; not yet accepted | Handoff\_2026\_11\_12\_housing\_pass | Colony blob 20 (18, 19 refused); colony\_check 509; a new block (Fieldstone) and the first use of a block's state; demo colony\_housing\_pass.mp4; castle\_game\_housing\_pass.zip, of the branch |
| 2026-11-12 | The same pass, a second round on John's answers (lots laid out beforehand, nothing passed over, hovels drawn for by lot; the ground between neighbours made one and their walls met; sleepers on their sides; a bed of straw each, by the fire and in its hovel; cloaks): built on the same branch and put to John again; not yet accepted | Handoff\_2026\_11\_12\_housing\_pass | Colony blob 21 (18 to 20 refused: the first round's saves do not load); colony\_check 541; `--no-beds` keeps the seven older reference logs; demo and zip of the same names, made again |
| 2026-11-12 | The same pass, a third round on what he found trying the second (a level place of its own by the fire for each, across the way to it; a bed before a hovel for stored straw, and before the paths; a fender to the nearest food; housing of all the ground inside a round of paths; a path drawn on its ground; no housing across the road off a path's end; the band's pace 1.5, and a hunter's kill put down when there is nowhere to butcher it): built on the same branch and put to John a third time; not yet accepted | Handoff\_2026\_11\_12\_housing\_pass | Colony blob 22 (18 to 21 refused: the second round's saves do not load); colony\_check 573; `--pace 1` keeps the seven older reference logs, five of them recorded again for the fender's rule; the eighth has a second stockpile; demo and zip of the same names, made again |
| 2026-11-13 | The lord's cart pulled into the stockpile nearest it; cloaks of cloth, an experiment (worn, taken off when the bed is made, laid over the sleeper); then roofs cleared on the camera's ray (open in the middle, half drawn over the walls): built on branch `cart-and-cloaks`, put to John in six rounds and accepted the same day ("ok commit we are at a good spot right now"): on `main` | Handoff\_2026\_11\_13\_cart\_and\_cloaks | Colony blob 25 (18 to 24 refused); colony\_check 621, pick\_check 59; `--no-cart-pull`, `--no-cloth`, `--no-cutaway`, `--all-roofs` (the H key's three views; the near walls cleared with the roof); the eighth reference log recorded again; `Castle.Cloth` and `Castle.Cutaway` new; the water's surface kept when the camera has been away (a fault he found: on `main` too; `--pan-back`); demo colony\_cart\_and\_cloaks.mp4; castle\_game\_cart\_and\_cloaks.zip, of `main` |
| 2026-11-13 | "The stress test for the cart issues": why the stress runner's crowd took 22 s for 12 with the pull. Found (a cornered herd, frightened every three seconds by a forester left standing by it, asking the same dry way 721 times) and the work kept (a plan that ran out of budget remembered); built on branch `herds-search`, put to John; accepted 2026-11-14 | Handoff\_2026\_11\_13\_herds\_search | Nothing anyone does changed: no reference log moved, the states equal with `--no-memos`; `colony_run --nav-log`, `--try-plan`; path\_check 54; tools/stress.sh runner's `crowd_no_memos`; castle\_game\_herds\_search.zip, of the branch |
| 2026-11-13 | A herd's flight in a chain (John: "lock them to the node and they run with the node, from the closest to the hunter in a chain reaction"): on the same branch, put to John; accepted 2026-11-14 | Handoff\_2026\_11\_13\_herds\_search | colony\_check 623; the two reference logs with the herds fleeing together recorded again; `Chain_S`; demo colony\_herd\_chain.mp4 |
| 2026-11-15 | The whole map held (the game keeps every stack's blocks and streams the meshes alone; the colony reads its own ground and nothing beyond); a far land built, tried by John and set aside behind `--far`; built on branch `whole-map`, accepted ("let's merge what we have now, let's keep the whole-map, we paid for it") and fast-forwarded into `main`; a sidetrack opened by him the same day: how to get everything in view | Handoff\_2026\_11\_15\_whole\_map | path\_check 70, colony\_check 643, edit\_check 36; eight reference logs, none recorded again; stress runner with `crowd_whole_map` |
| 2026-11-16 | The far view (everything in view: the world itself at coarser blocks in rings to the map's edge) accepted by John on 2026-11-15 ("ok looking good, great performance ... Merge it, and on by default") and on `main`; and the round he asked for by name with it: the white dots found to be holes and closed, the sun's shadows and the water's mirror past the view's edge, a haze on the ground and at the map's rim, the old far land out of the game; gated and on `main` | Handoff\_2026\_11\_15\_far\_view, Handoff\_2026\_11\_16\_far\_view\_haze\_and\_shadows | Nothing saved, nothing the colony knows; eight logs line for line, none recorded again; edit\_check 41; +0.03 to +0.25 ms a frame at the twelve views for the round; 64 MB of the card's memory for the far shadows; castle\_game\_far\_view\_haze.zip |
| 2026-11-16 | The far view's third round, on his answer to the second: no haze on the mountains and no fingers, the land's haze as thin as the far water's mist, the sun and the moon drawn on under eye level to the map's edge (from low down the land cuts them off; from high up they fade out in the haze above it), the boulders drawn round (their blocks untouched); then on his answer the boulders into the ground (generator 15: nothing hollow under one, a skirt at its foot; all eight reference logs recorded again), trees through the rock (generator 16) and the rock's flicker mended; on branch `haze-horizon-boulders`, gated, not merged (he looked at it, 2026-11-17: "it really came together, I am not experiencing any anomolies"; then "Ok merge.": on `main`, c8f1c40 the way back) | Handoff\_2026\_11\_16\_haze\_horizon\_boulders | Nothing saved, nothing the colony knows; eight logs line for line, none recorded again; edit\_check 41; no frame cost seen; quads +0.4 % in a view strewn with boulders; castle\_game\_haze\_horizon\_boulders.zip |
| 2026-11-17 | The stockpile's first pass, from his design in passes (with a piece of the story, none of it built but what he asked for): thirteen arrive, at most four builders, a stockpile at least 15 m by 15 m, five overflow places round it and nobody setting out for what no ordinary place has room for; on branch `stockpile`, gated, not merged | Handoff\_2026\_11\_17\_stockpile\_first\_pass | Colony blob 26 (25 refused); eight logs line for line (they say --band 6 --stockpile-least 0 --no-overflow); colony\_check 654 (11 new); a band of thirteen on 18 places stood 2,104 serf-hours with a load and nowhere to put it, none with the overflow; castle\_game\_stockpile.zip |
| 2026-11-17 | The stockpile's second pass, on his "We can continue." with the six defaults put to him: the advisor's request simulated on the second morning, the storehouse (5 m by 10 m, a floor of plank, its door on the end toward the path) built by the builders on the stockpile's end nearest the stake, the places under and before it closed, its yard beaten, fenced with a gateway before its door, coverings of thatch along the back; on branch `stockpile`, gated, not merged | Handoff\_2026\_11\_17\_storehouse | Colony blob 27 (18 to 26 refused); eight logs line for line (they say --no-storehouse); colony\_check 667 (11 new); standing five days after the request (18 logs, 43 sheaves); the fence's one gateway costs the band (50 days: 2,181 hungry serf-hours against 1,116, confidence at its lowest 25 % against 59; with an opening in each side 1,284): his first call
| 2026-11-17 | The stockpile's third pass, on his "Let's move on to the next step" (berries and apples in their baskets inside, "Leave the questions open"): the storehouse's places fitted out (shelves for hides, barrels for meat and water, the floor for baskets and salt, the coverings holding three times as much, ladders against its wall), a stockman (a porter: the overflow, the cart to the front and its salt in, the yard sorted), a carpenter (its builder: the shelves and barrels), water; on branch `stockpile`, gated, not merged | Handoff\_2026\_11\_17\_storehouse\_used | Colony blob 28 (18 to 27 refused); eight logs line for line; colony\_check 678 (11 new); the fourteen made in 43 hours of a 50-day run; nobody died
| 2026-11-18 | His playtest notes of the storehouse ("~/CASTLE_GAME/PLAYTEST NOTES, thoughts"): the stockpile "a onetime placement of a 10x10 zone", no overflow, "the last 10 blocks" a signal; the storehouse on "a new stockyard zone" with "doors at each end" and gates "inline with the inside wall", levelled "same as houses", its apple trees felled, deliveries and pickups moved to it; five faults. Built on branch `stockpile` with each fault reproduced first; the rest of the notes (looks, the builder's job, razing, paths levelled) put to him as the next pass | Handoff\_2026\_11\_18\_playtest\_round | Colony blob 30 (18 to 29 refused); eight logs line for line, none recorded again
| 2026-11-19 | The next pass of his playtest notes, on his "we can continue to the next pass": paths levelled as laid, trades shown in the band's lists, housing ground taken out again and a hovel marked for razing (no taking down yet), doors, cart wheels, fuller thatch, a window's timber, the roof's timbers, the thatcher on its ladder, stepping aside; his design document `docs/design/detailed_mechanics.json` (0.6) committed as it came and read, not built from; on branch `stockpile`, gated, not merged | Handoff\_2026\_11\_19\_next\_pass | colony\_check 752; colony blob 31 (30 still read); eight reference logs |
| 2026-11-19 | His eight answers to that pass: "limit razing buildings to unowned" (and the taking down built), jobs past the opening ones by skill with a development list, "leafs on the gateways", "Thin trim around the tops and side(s)", "a ridge beam to the hovels", "that ragged look to the entire surface of the roof"; "Document's stores is my model the new idea, the logistics network" planned in the stage's brief, not built; on branch `stockpile`, gated, not merged | Handoff\_2026\_11\_19\_answers\_round | colony\_check 767; colony blob 32 (30 and 31 still read); eight reference logs |
| 2026-11-19 | "Still having issues with the foresters not finding trees in range" and "lock the paths to straight and 45 degree angles": a forester looks a ring further when it has no tree left that it can get to (the trees within 60 m of the stake were used up by the hundred and thirtieth day at the reference site), and says why it has none; a path is ordered along one of eight ways on corners of blocks; "planning structures on that design pathway" recorded as his next topic, not built; on branch `stockpile`, gated, not merged | Handoff\_2026\_11\_19\_foresters\_and\_paths | colony\_check 790; colony blob 33 (30 to 32 still read); eight reference logs |
| 2026-11-19 | His answers to the two rounds before: "we go back to variable size stockpile, placed along the path, the new design document I added is to be integrated" (stockpiles of any size and number, open beside the stockyard: the logistics network's first pass), "Carpenter comes by skill like the others", "Trim width yes inside the house too", "Let workers go 250m for resources" (foresters; the others owed), "is there a way we can just turn the buildings and build them at a 45 degree angle without stepping?" (one wall drawn so in a scratch build; owed), trees to grow back later; on branch `stockpile`, gated, not merged | Handoff\_2026\_11\_19\_stockpiles\_and\_reach | colony\_check 793; colony blob 34 (30 to 33 still read); eight reference logs |
| 2026-11-19 | "hold off on the integration" (the logistics network's later passes wait; polishing for some days), "can't we just detach the entire building and rotate it?" (shown in a scratch still of a whole hovel; chosen; steps in the stage's brief), gatherers and porters a ring further when they find nothing in reach, to 250 m; on branch `stockpile`, gated, not merged | Handoff\_2026\_11\_19\_turned\_building\_and\_workers | colony\_check 797; colony blob 35 (30 to 34 still read); eight reference logs |
| 2026-11-19 | "Ok step one of the turned building": a building's blocks drawn turned about its doorway as one piece (drawing only; `--turn-houses`), and "what happens if we add a second story to the building can serfs interact with the stairs inside?" answered from the walking map (four floors over a spot, half-metre steps: yes; nothing built); on branch `stockpile`, gated, not merged | Handoff\_2026\_11\_19\_turned\_building\_step\_one | stills against the build before within its own noise; colony\_check 797 |
| 2026-11-19 | "ok next step": the second of the turned building: what is inside a house drawn turned (its people, their cloaks, its bed, its door's leaf, its trim) drawn through its turn; drawing only, by `--turn-houses`; on branch `stockpile`, gated, not merged | Handoff\_2026\_11\_19\_turned\_building\_step\_two | stills against the build before within its own noise; colony\_check 797 |
| 2026-11-19 | "Ok step 3": a hovel beside a path at 45 degrees placed turned by the colony (the turn kept with the house, saved; drawing only), its builder and ladder drawn with it; the ground under the house as drawn left to build; on branch `stockpile`, gated, not merged | Handoff\_2026\_11\_19\_turned\_building\_step\_three | colony\_check 801; colony blob 36 (30 to 35 still read); eight reference logs |
| 2026-11-19 | "you're doing a great job, continue" (praise, not a merge word): the ground of a turned hovel made where it is drawn, its floor there, its door's way square to the path, the ground kept off by who walks; the faults measured before and after; on branch `stockpile`, gated, not merged | Handoff\_2026\_11\_19\_turned\_building\_ground | colony\_check 811; colony blob 37 (30 to 36 still read); `tools/turned_streets.sh` in the gate; eight reference logs |
| 2026-11-19 | (the same word) step four of the turned building: pointing and the cleared roof by where a turned house is drawn; the far view left to build; on branch `stockpile`, gated, not merged | Handoff\_2026\_11\_19\_turned\_building\_step\_four | pick\_check 69; nothing saved; eight reference logs |
| 2026-11-19 | "can't we step the texture so it falls under the wall of the house? we don't want to limit the player they need to be able to place diagonals on hillsides if they want to": the turned floor's edge stepped by the texel; a turned hovel placed wherever a square one would be; a fault of the ground's commit found on the hillside and mended; on branch `stockpile`, gated, not merged | Handoff\_2026\_11\_19\_turned\_floor\_and\_hillsides | colony\_check 813; nothing saved; the steep hillside in `tools/turned_streets.sh` |
| 2026-11-20 | "Ok lets continue,1. stopping at the outer face is preferable. 2. If you think bare earth would match better do it. 3. No limit is fine for now, we can adjust later": the far view through the turn; the bare-earth texel; the stockyard at 45 degrees put to him as three ways; on branch `stockpile`, gated, not merged | Handoff\_2026\_11\_20\_far\_view\_and\_answers | nothing saved; colony\_check 813; eight reference logs |
| 2026-11-20 | (the same word; the rest of "Let workers go 250m for resources") gatherers and porters told of ways that are not there, the fault reproduced first; the hunters and the gatherers' hunger far out put to him; on branch `stockpile`, gated, not merged | Handoff\_2026\_11\_20\_ways\_told | colony\_check 817; colony blob 38 (30 to 37 still read); `colony_run --work-stats`; eight reference logs |
| 2026-11-20 | "Ok go on with the second way for the stockyard" (of three ways put to him): a stockyard beside a path at 45 degrees laid out along the path, made for real but for its storehouse's own blocks, which are drawn turned; the feet go by the storehouse as it is drawn; where it departs from what he chose from said first (no hidden square; the coverings stepped; the builder's turn eased); on branch `stockpile`, gated, not merged | Handoff\_2026\_11\_20\_stockyard\_along\_a\_path | path\_check 84, colony\_check 833, pick\_check 78; colony blob 39 (30 to 38 still read); `tools/stockyard_sites.sh` six sites; `tools/yard_corners.py`; `colony_run --turn-stats` for a turned stockyard; the game's `--pointer` `tool`; eight reference logs |
| 2026-11-20 | "Let's do that, and what do you think about turning the fence too? The outdoor roof covering needs a smoothing pass": a turned hovel walked where it is drawn, its walls slowing the feet rather than shutting them (shut, on hillsides they made pits); a stockyard's coverings smoothed by its builder and a turned one's rails drawn along the path, as props over blocks the land leaves out; where it departs from what he asked said first; on branch `stockpile`, gated, not merged | Handoff\_2026\_11\_20\_walked\_hovels\_and\_yard\_pieces | path\_check 88, colony\_check 845, pick\_check 78; colony blobs 40 and 41 (30 to 39, 30 to 40 still read); `Castle.Blocks.Piece`, `Seen_Mat`; `Castle.Nav.Wall_Pace`; `colony_run --turn-stats` for walked houses and a storehouse's pieces; `tools/turned_streets.sh` fails on anyone in a wall as drawn |
| 2026-11-20 | His design for placing zones, in answer to whether building at an angle causes a lot of issues (yes, as built; two ways put to him): "let's lock the size of the stockpile, if the player places it, it will be a square box, lets fix the path artifcats by including the path in front of the stockpile, the player can rotate the placement ... Along with a warning for overlap ... and allow us to make the angled zones their own grid ... Let's merge the homestake and the campfire, no physical stake now ... a 10x10 area, terriform so the entire area is flat, and build a path around the perimeter". **He takes the first way, by the placed zone.** His rulings with it: an angled zone's ground is the map's quarter-metre blocks that fit, made level; a placed box over anything is refused, housing joins housing as it does; the square's path round the outside of its 10 m; the lots' polish after everything else. Built on branch `stockpile`, not merged: the covering's roof; the stockpile put down whole with its path; the homestake and the campfire one. The zone's own grid sized in the brief, not built | Handoff\_2026\_11\_20\_placements\_with\_paths\_and\_the\_square | colony\_check 885; colony blobs 42 and 43 (30 to 41, 30 to 42 still read); `Castle.Colony.Box_At`, `Plan_Box`, `Place_Box`, `Place_Square`; `colony_run --box-stats`, `--square-census`; `--stockpile-box`, `--square`, `--no-box-place`, `--no-square`, `--no-cover-thatch`; cover\_roof\_thatch.png, stockpile\_box.png, founding\_square.png |
| 2026-11-21 | His answer to the walls' report: the square 13 m with its path, its walls outside its floor ("the area of a special zone like these takes precedent"); the stockyard put down whole, 20 m by 20 m; the storehouse 12 m by 8 m ("so that it is now 8x12"), food and full barrels stacked in it; a stockyard's stair in a corner of the zone (built for the square first and taken back the same day); the count of empty bellies taken again; on branch `stockpile`, gated, not merged | Handoff\_2026\_11\_21\_square\_thirteen\_and\_stockyard\_twenty | Colony blob 44 (30 to 43 still read) |
| 2026-11-22 | His six numbered answers: a stockyard's floor at its path's level at the lower corner of its front and the stair at the higher, none over 2 m; the square's path stepped with stone; on branch `stockpile`, gated, not merged | Handoff\_2026\_11\_22\_stockyard\_floor\_and\_stone\_steps | Gate 85 |
| 2026-11-22 | His three answers ("1. that is fine, 2. leave the cart doing whatever it's doing right now ... 3. stick with whatever you think is best, Mend the issues you found"): the corners of the square's path laid as one and stepped, a strip's wait, a planned line's end under a tree; then **merged into `main` on his word** ("For now merge everything, and we will work with that state"); next by the same message: the horses for the cart and how the colony arrives | Handoff\_2026\_11\_22\_corners\_and\_mends | Gate 86: colony\_check 1059, path\_check 88, pick\_check 78; colony blob 44; eight reference logs |
| 2026-11-22 | A structural inspection, on his four points: his design document brought into the project (checked, mapped to the build), the files checked against each other, the code looked over by instruments, the project made easier to work in (the conventions out of CLAUDE.md, a state page, the gate a script); on branch `inspection`, merged the same day on his word | Handoff\_2026\_11\_22\_structural\_inspection | No rule of the game changed |
| 2026-11-22 | His notes after the merge ("yes add the cook and the stockman and carpenter, what we need to fix ...", with four pictures): a person's development entries; eating, the hands before the chest; a deer one piece on steep ground; a herd put down only where a deer can walk off; a sleeper's cloak over all it is dressed in; clothes of cloth tried and dropped; the serfs with more form; on branch `playtest-notes`, not merged | Handoff\_2026\_11\_22\_playtest\_notes | A switch each; the kept logs line for line; found and left: deer on mountain ledges, a compiler fault |
| 2026-11-23 | His notes with fourteen pictures ("we need to figure out a way to handle how paths and zone buildings meet up ... let's also have builders who finish their project help finish larger projects together ... the stockpile zones just disappeared at some point, let the player remove them if they want to ..."): the zones' lost ground mended; ten rules, each with its switch (ground worked from beside it and there and back; paths and doors' ways made to meet; a deer butchered by its carrier; a stockpile's places made level and room round the cart; the fuller truss; a stockpile removed by the player; builders helping at a larger house); and, found on the way, a walker at the height of the place it steps into (people stood in a step wherever they stopped just past its edge); on branch `playtest-notes-2`, not merged | `docs/handoffs/Handoff_2026_11_23_paths_builders_and_stockpiles.md` |
| 2026-11-23 | His answer "flatten the stockpile, let's just make this easy for ourselves": a stockpile is one level where it is put down, at the level of its path side, the land cut or filled whatever it is made of, all of what was marked; set aside the same afternoon ("let's go back to the stepped version, not the cut one, let's block the players placement if it's too steep"): off by default, a stockpile refused on ground too steep in its place; merged on his "then merge" | `docs/handoffs/Handoff_2026_11_23_a_stockpile_is_one_level.md` |
| 2026-11-14 | What the ground costs to keep: a stack's ground summary and its fine bricks kept small (storage only), the mountains' boulders thinned (generator 14), the generator's skin tried thinner and not taken; built on branch `ground-memory`, put to John; accepted the same day ("I accept ground-memory"): `ground-memory` fast-forwarded into `main`, which is generator 14 from here | Handoff\_2026\_11\_14\_ground\_memory | edit\_check 32; eight reference logs (recorded again for generator 14); `colony_run --ground-stacks`, `--mem`, `--no-mesh`, `--full-summaries`, `--whole-bricks`; `flora_stats` counts boulders; castle\_game\_ground\_memory.zip of the branch; boulders\_before\_after.png |
| 2026-11-14 | The herds' search accepted ("My testing otherwise shows acceptable results so I think we can merge clean-up and continue, if you concur"): `herds-search` fast-forwarded into `main`. In the same message, for a later stage: "when we add the entire ecosystem we are going to have to seperate the deer from the stake and the entire map gets populated, keep that in mind" | Handoff\_2026\_11\_13\_herds\_search | On `main`: path\_check 69, colony\_check 635, eight reference logs; castle\_game\_herds\_search.zip of `main`; demos colony\_herd\_chain.mp4, colony\_herds\_still.mp4; `deer.md`, "To come: the herds apart from the stake" |
| 2026-11-14 | His answer to the finding's calls (2026-11-13: "a person standing still doesn't frighten a herd, and let them know that water blocks them, when we get to the stockpile mechanics we will reserve a portion of the stockpile for overflow"): the first two built on the same branch, a commit each; the third written down for the stockpile; put to John; accepted the same day (the row above) | Handoff\_2026\_11\_13\_herds\_search | path\_check 69, colony\_check 635; `Castle.Nav.Plan`'s `Within` and `Refuse`, `colony_run --prove-dry`; the two logs recorded again twice; demo colony\_herds\_still.mp4 |
| 2026-11-13 | The pass on building and zoning accepted ("accepted", sent while its fifth round was being built); `housing-pass` fast-forwarded into `main` after that round was finished and gated | Handoff\_2026\_11\_12\_housing\_pass | On `main`: colony blob 24, colony\_check 616, pick\_check 41, eight reference logs; castle\_game\_housing\_pass.zip of `main`; demo colony\_housing\_pass.mp4 |
| 2026-11-13 | The same pass, a fifth round on what he found trying the fourth (a load in a serf's arms taken where it was going before it eats; a hovel's lot levelled as if its holes were filled, and they are, not dug down to their bottoms; holes under a path filled as the band lays it; a builder takes up a house left further on than its own): built on the same branch and put to John a fifth time; not yet accepted | Handoff\_2026\_11\_12\_housing\_pass | Colony blob 24 (18 to 23 refused: the fourth round's saves do not load); colony\_check 616; one switch (`--no-path-holes`), the seven older reference logs held at it; the eight logs recorded again for the eating (all moved); demo colony\_housing\_pass.mp4 made again; castle\_game\_housing\_pass.zip, of the branch |
| 2026-11-12 | The same pass, a fourth round on what he found trying the third (a stair of stone only where a path lies more than a block off a door's floor; a ladder for the roof, made at the stockpile and thatched from; the cook keeps a pot's fill of the stores from being eaten raw; meat by the pound, a doe's sixty, salted as she is butchered; the lord's cart of salt, the first thing of the story): built on the same branch and put to John a fourth time; not yet accepted | Handoff\_2026\_11\_12\_housing\_pass | Colony blob 23 (18 to 22 refused: the third round's saves do not load); colony\_check 610, pick\_check 41; three switches (`--no-cook-hold`, `--no-curing`, `--no-ladders`), the seven older reference logs held at the first two and the eighth recorded again with all on; `Salt` and `Ladder` on the end of the item kinds, `A_Cart` of what can be pointed at; demo colony\_housing\_pass.mp4 made again; castle\_game\_housing\_pass.zip, of the branch |
| 2026-11-11 | Falls thrown from the lip: water over a drop drawn as an arch standing off the wall, as a body standing off a slope (a drawing: the simulation untouched); accepted as built the same day | Handoff\_2026\_11\_11\_falls | No version moved; on `main`; demo falls.mp4; castle\_game\_falls.zip, of `main` |
| 2026-11-11 | What routing and the colony's steps cost, on his note on pathing ("up to you how we implement it"): a goal out of reach known at once, source searches kept, the walking map mended; the route store and the coarse graph measured and left; accepted as built the same day | Handoff\_2026\_11\_11\_pathing | No version moved; the seven reference logs regenerated; on `main`; castle\_game\_pathing.zip, of `main` |
| 2026-11-11 | Touch-ups and a stress test before stage 6: the sun's dark disc, a moon, the clouds walked through, mist, wet surfaces, the lights a table; then, on his answer, moonlight, phases and stars; accepted as built the same day | Handoff\_2026\_11\_11\_sky\_and\_weather | No version moved; on `main`; Stress\_test.md; demos demo sky\_and\_weather.mp4; castle\_game\_sky\_weather.zip, of the branch |
| 2026-11-11 | The last pass before stage 6: rounded models, tools carried, soft foliage, the herds' flight, the fringe of paths; then a quiver, grass as tufts and generator 13 (trees reshaped, tall grass in drifts); accepted as built 2026-11-11 | Handoff\_2026\_11\_11\_models\_pass | Generator\_Version 13 (older saves refused); colony blob 17 (the herds' blob 2); colony\_check 422; seven reference logs, regenerated; demo models\_pass.mp4; castle\_game\_models\_pass.zip, of main |
| 2026-11-11 | Extra hands limited, a stretch of path to a serf, the camp's floor levelled, between 5c and 6; closed 2026-11-11 | Handoff\_2026\_11\_11\_hands\_and\_level | Colony blob 16; colony\_check 404; six reference logs; demo hands\_and\_level.mp4; closed as built ("great, I think we are at a point to end the session") |
| 2026-11-10 | Paths planned and laid; no limit on how far, between 5c and 6; closed 2026-11-11 | Handoff\_2026\_11\_10\_paths\_and\_reach | Colony blob 15; colony\_check 358; five reference logs; demo paths\_and\_reach.mp4; accepted as built ("excelent, the framework is starting to take shape") |
| 2026-11-10 | Zones, the fire's life, the camp built, between 5c and 6; closed | Handoff\_2026\_11\_10\_camp\_and\_zones | Colony blob 14; colony\_check 337; four reference logs; demo camp\_and\_zones.mp4 |
| 2026-11-10 | Shadows and the fire, between 5c and 6; closed | Handoff\_2026\_11\_10\_shadows\_and\_fire | Shadows that hold still, figures cast, the fire's look and its shadows; no version moved; demo shadows\_and\_fire.mp4 |
| 2026-11-10 | The water's look, between 5c and 6; closed | Handoff\_2026\_11\_10\_water\_look | Deeper hues by depth, the world mirrored in water; no version moved; stills water\_look\_before\_after.png |
| 2026-11-10 | Water, between 5c and 6; closed | Handoff\_2026\_11\_10\_water\_drawdown | Generator\_Version 12 (tarns); save format 6; water\_sim\_check 77; demo water\_drawdown.mp4 |
| 2026-11-10 | 5c, closed | Handoff\_2026\_11\_10\_stage\_5c\_demand | Colony blob 13; no demo recorded |
| 2026-11-10 | 5b, closed | Handoff\_2026\_11\_10\_stage\_5b\_skills | Colony blob 12; demo colony\_stage5b\_skills.mp4; with skills off the reference log is stage 5a's |
| 2026-11-10 | 5a, closed | Handoff\_2026\_11\_10\_stage\_5a\_scaffold | Colony blob 11; pick\_check added; demo colony\_stage5a\_scaffold.mp4; no behaviour changed |
| 2026-11-09 | Restructure, pass 2 | Handoff\_2026\_11\_09\_restructure\_pass\_2 | The enum move, the colony body in subunits, tunables to the spec; no behaviour changed |
| 2026-11-09 | Restructure, pass 1 | Handoff\_2026\_11\_09\_restructure | Documents into docs/, the README split by system; no code touched |
| 2026-11-09 | 4R, closed | Handoff\_2026\_11\_09\_stage\_4R\_runner | colony\_run and Castle.Scenario |
| 2026-11-09 | 4, closed | Handoff\_2026\_11\_09\_stage\_4\_camp\_and\_food | Generator\_Version 11; colony blob 10; demo colony\_stage4\_camp.mp4 |
| 2026-11-08 | Between 3 and 4 | Handoff\_2026\_11\_08\_world\_look | Palette and forests; Generator\_Version 10 |
| 2026-11-08 | 3, closed | Handoff\_2026\_11\_08\_stage\_3 | deer\_check added; demo colony\_stage3\_hunt.mp4 |
| 2026-11-08 | 2, closed | Handoff\_2026\_11\_08\_stage\_2 | No demo was recorded |
| 2026-11-07 | 0 and 1, closed | Handoff\_2026\_11\_07\_ui | colony\_check added; demo colony\_stage1\_berries.mp4; Generator\_Version 9 |

## Stage protocol

A stage runs kickoff, build, close, and it is done only when every item of the close list holds. This is the plan's rule (a headless check, a demo video, the README and a zip) with the handoff and the version records made explicit.

### Kickoff

1. Start a clean context and load the documents in the order given at the top.
2. Write the stage brief from the template: goal, scope, what is out of scope, pillars touched, state and save changes, checks, demo, and the later systems it must leave room for.
3. Agree the rules with John and date them. They go into the handoff and CLAUDE.md.
4. Settle the open design questions this stage is the first to need, before any code.

### Build

- Add each resource or behavior as a job on the loop that already runs, saves and is tested.
- Give every feature its command-line options as it lands, and measure with them.
- Commit per feature. If the context has to be cleared mid-stage, write an interim handoff first.

### Close

- [ ] All checks pass in debug from a clean unzip, with only the known warnings
- [ ] The stage's rules are in a headless check, including an exact save round trip mid-activity
- [ ] Version changes are recorded: Generator\_Version, save format, blob versions; older blobs still load
- [ ] Tunables are named at the top of the package spec with first values; earlier mechanics are not rebalanced
- [ ] Demo video recorded, with its command line kept
- [ ] README updated: the system's section, options, checks, "Not there yet", layout
- [ ] Production plan updated: done date, what changed from the draft, what was deferred
- [ ] Handoff written from the template, and CLAUDE.md updated with any new rules
- [ ] castle\_game\_stageN.zip made with git archive, building clean
- [ ] Project files refreshed with the README, the plan and the handoff
- [ ] This framework's Current state and Stages brought up to date

The reference setup is seed 1 with the stake at 1178 1078 and the camp at 1172 1082; the reference run is `tools/reference_run.sh` (two gatherers, a forester, two hunters, a cook, nothing stored, from summer's fifth day). Measurements and gates are taken in colony\_run, which repeats exactly; a windowed run with --frames does not. Stage 4's reference log is reference\_run\_stage4.txt; stage 5a's, reference\_run\_stage5a.txt, is the same line for line but for the state hash (the blob is version 11).

A phase close adds four things: the gate run recorded, the pillars reviewed against what was built, the design documents brought up to date, and the next phase staged.

## Documentation set

Each document owns one kind of truth. When two disagree, the most recently dated agreement with John wins, then the README for how the code behaves.

| Document | Source of truth for | Updated |
| --- | --- | --- |
| Production Framework | Pillars, architecture rules, phases, protocol | At a phase close, or when a rule changes |
| README.md | The project in perspective: what it is, build and run, the map of systems, layout | Every stage close |
| System READMEs, in docs/systems | One system each, as the code has it: how it works, options, checks, what is not there yet | In the same commit as the code they describe |
| Production\_plan.md | Stage scope, status, changes from the draft, deferrals | Stage kickoff and close |
| Handoffs | One session: rules agreed, what was built, measurements, bugs, limits, next | Written once at a close and not edited after |
| CLAUDE.md | For terminal sessions: the order of reading, build and tests, the architecture, the index of docs/conventions | When one of those changes |
| docs/production/State.md (since 2026-11-22) | Where the project stands: the build, what is next, what is on hold, where John's open calls are | Rewritten at every close |
| docs/conventions (since 2026-11-22; in CLAUDE.md until then) | What past sessions learned and John ruled, a file a part of the game | When a rule is agreed: at the top of its part's file, dated |
| docs/design/detailed\_mechanics.json | John's design of the colony, its people and its economy | By John, elsewhere; committed as it comes, never changed here |
| docs/design/Mechanics\_crosswalk.md, tools/mechanics\_map.json | That document beside the build | When either moves (tools/mechanics\_check.py fails until they are) |
| docs/systems/switches.md | Every switch, and which part of the gate runs it which way | When a switch is added (tools/switch\_census.py --md) |
| Preliminary Design Report | Design intent, proposals and open questions | Phase close |
| Organized Design, jobs.txt, asset guide | Jobs, resources, zones and how they connect, as first written; detailed\_mechanics.json was drawn from them and says where it changed them (its `changes_from_source`) | Not updated |
| Procedural generation spec | The tier-1 hovel | Stage 6 kickoff |
| color\_palette.txt | Every colour in the world | When the look changes |
| docs/reference: REFERENCES.md (the papers, in CASTLE\_GAME/papers), kkrieger\_notes.md | Techniques behind water, textures and steppers | Not updated |

Names follow the files already in use: `Handoff_YYYY_MM_DD_topic.md`, `castle_game_stageN.zip`, `colony_stageN_topic.mp4`, and `system_check` for check tools.

Project files that lag the repo today:

- [ ] claude\_production-plan.md shows stages 0 and 1 done; the current plan shows 0 to 3
- [x] The asset guide and the Organized Design no longer list the sling (checked 9 November)
- [ ] The README, the three latest handoffs and this framework are not in the project files

### Handoff template

```markdown
# Castle Game handoff (YYYY-MM-DD: stage N, topic; where the work was done)

- Code: path, branch, commits; the zip if one was made.
- Checks: which pass and in which build; warnings.
- Versions: Generator_Version, save format, colony blob, and what each bump added.

## Rules agreed with John (date)
## Built
## Measured (seed, stake, setup, duration)
## Saves
## Options
## Bugs found and fixed
## Known limits
## Not done
## Next
```

### Stage brief template

```markdown
# Stage N brief: name (phase X)

- Goal: one sentence, as the player will see it.
- Pillars touched: which, and how each is met.
- In scope:
- Out of scope:
- Rules to agree with John before code:
- State and saves: new state, blob version, how older blobs load.
- Packages: touched, new.
- Leaves room for: the later systems that will plug into this one, and the hook each needs.
- Tunables: name and first value. Balancing waits for phase G.
- Check: what the headless check must prove.
- Demo: what the video shows, and its command line.
- Read list: README sections, design documents.
```

## Session protocol

Clear the context at every stage close, and mid-stage whenever a module is finished or the session starts re-reading its own work. The handoff is what carries over; nothing else should have to.

There are two workspaces. Claude Code in the terminal owns the code. The README, CLAUDE.md, the plan, the handoffs and the design documents are all in the repo (docs/), so a stage zip carries them. This Project owns design and planning, and receives copies at each stage close. CLAUDE.md should name this framework beside the plan and the latest handoff.

### Closing a session

1. Commit, then run the checks in debug.
2. Write the handoff, including what is not done and the exact next step.
3. Update the README, the plan and CLAUDE.md wherever the session changed what they say.
4. Upload the changed documents to the Project. This step is John's: Claude Code can only send to the Project when John types /send-to-project.

### Starting a clean context

```text
Read, in this order: the Production Framework, Production_plan.md, the latest handoff, and CLAUDE.md.
From README.md read only these sections: <sections for this stage>.
We are starting stage N: <name>. Do not write code yet.
1. Summarize the current state in ten lines, and name anything the documents disagree on.
2. Draft the stage brief from the template in the framework.
3. List the rules and open questions I need to settle before you start.
```

The README was about 79 KB, roughly 20,000 tokens. Since the restructure it is split: the main README (about 12 KB) and one file per system in docs/systems.

| Stage | README sections to load | Design documents |
| --- | --- | --- |
| 5b Skills | interface.md ("Two interfaces, one layer"); colony.md (Zones, Who directs whom, Actions); people.md; needs.md | Design report (skills and professions); jobs.txt |
| 6 Habitation | habitation.md; edits\_and\_saves.md; routes.md; colony.md; the main README's layout | preliminary\_PROCEEDURAL\_GENERATION.txt; design\_conversations.txt |
| 6b Stockpile mechanics | habitation.md; colony.md (Zones, Demand, Stockpiles); briefs/Stage\_6\_brief.md ("6b") | Castle\_Game\_Organized\_Design.md (constructable zones) |

## Decisions and risks

A new session must not reopen the decisions in force, and must not start a stage whose open decisions are unsettled.

### Decisions in force

| Date | Decision |
| --- | --- |
| 2026-11-15 | **The far view is on, by default** ("Merge it, and on by default"): past the view's edge the world itself at coarser blocks to the map's edge, with the sun's shadows, the water's mirror and a haze on the ground a metre deep that goes opaque over the last 12 m to the map's edge (both figures his). **No tilt-shift** ("let's not do tilt shift"). The old far land is out of the game, its code kept ("remove the old far land, but keep the functionality ... just in case"): don't delete it. `--no-lod` must stay the picture before the far view, to the pixel. |
| 2026-11-15 | **The whole map is held, and stays** ("let's keep the whole-map, we paid for it"): every stack's blocks from soon after the start, the meshes alone streamed; the game holds 1.5 to 1.6 GB of its 4. **So nothing may be bounded by what is loaded**: the colony reads its own ground (`Set_Ground_Stacks`), and a run is the same run whatever its host holds. **The far land is off unless asked for** ("far is ugly with the flat terrain and popping assets, the fog works better in that state"), the haze as it was. **Before the stockpile, a sidetrack of his: how to get everything in view** ("if we are going to rework rendering let's go all the way"), his list of techniques to be weighed by measurement. |
| 2026-11-14 | **Memory: the game is to be comfortable on a machine of 8 GB, so 4 GB is its ceiling.** John: "I read the steam hardware survey, 98% of PC's that took the survey have 8gb of memory or more, 90% have 12gb or more, the 87% have 16gb or more, so we want to be comfortable on 8gb of ram, that means consuming 4gb is our ceiling". (The game holds about 510 MB at its default view; a map held whole for the simulation would be about 1 GB more by the counts of that day, worked out from the runner and not run in the game: `docs/systems/world.md`, "What a stack costs to keep". Not built.) |
| 2026-11-14 | **The simulation does not need what only the eye needs.** John: "the inhabitants don't care what texture the objects are only the player does ... we need to be smart about this". Where his questions of that day lead (less ground streamed round the player, NPCs and animals holding their own, the whole map solid and only the mesh streamed) is not designed and is his to open; what a stack costs to keep is counted and its two largest parts kept small (Handoff\_2026\_11\_14\_ground\_memory). |
| 2026-11-13 | After the merge (whole in Handoff\_2026\_11\_13\_cart\_and\_cloaks): "I saw the grass going with the ground every other time, it seemed to have just happened on a couple of blocks, the gatherer had been collecting grass on the blocks before the plot began being built, maybe there is something there where the state of the grass has been modified but not completed and the grass remains? Just leave it for now, if I reproduce it again, I will try and recreate the exact conditions for debugging. Two last things I want to work on before moving to the next stage, the cart, can they pull it into the closest stockpile zone? I also want to try something, an experiment, can we have the cloaks be dynamic cloth, that they wear at the start, then take off when they make their bed, and then draped over them when they sleep, if we can do it, it would be a very cool touch and would translate well when we get to other wearable items later in production." The grass left at his word; the two built on a branch with first values of mine. |
| 2026-11-13 | **The pass on building and zoning accepted**, in a message of one word while its fifth round was being built: "accepted". Read as the pass accepted with that round's mending in it: the round was finished, gated from a clean copy and merged into `main`. Its calls, and those of the third and fourth rounds, stand by default. |
| 2026-11-13 | The pass's fourth round, tried by him (with a picture of a hovel's lot dug down a block over all its ground): "Some new things I found on my latest testing, people carrying items to the stockpile will stop and eat instead of completing their task and then eating, this creates an oddity where foresters carrying logs back to the stockpile have a log on their sholder while they are eating, I am sure this can happen while carrying other things too. [Image #17] This screen shot shows dirt having been removed, and the grass stays in the air. It also shows that othewise even ground was dug out entirely becuase it had a couple of holes in it, instead of just filling the holes. It would be nice if there was a way for serfs to fill in holes in the path when they are compacting the ground." And a little after: "Also, I removed the cook from cooking, he started building a house, the build was asigned to him, I then sent him back to cooking mid build and it didn't free up the assignment for the build." Each reproduced and built as a fifth round on the same branch, with first rules of mine (the handoff lists them as his calls: first, that a gatherer with no stew still eats from its basket, since taking its food home first starved a first day under the cook's hold; second, the bank of turf round a cut, drawn as grass as before; grass floating over a hole dug under it mended, though what he saw, on a couple of blocks where grass had been gathered, is not found and he has said to leave it for now). He did not say he accepts the third or the fourth round: their calls stand by default. Not accepted, not merged. |
| 2026-11-12 | **The story, its first words** (in the same message as the row below): "we can talk abit about the story now, the player is a minor noble tasked wtih improving the land by their lord, taxes on production would come after a few years, so the lord provides a small workforce a minimum of starting supplies so for now lets just add a cart with salt in it for curing, we can expand the supplies later and work the story in as we get to the players role". Recorded as his; nothing of it is designed further. Built of it: the lord's cart with its salt, standing by the homestake when the band arrives. Not built, and his to open: any other supply, the lord, taxes, the player's own person. |
| 2026-11-12 | The pass's third round, tried by him (with a picture of a patch of fieldstone before a door on ground all but level): "a minor tweak with the house pathing and stepping as shown in the image, the stairs were added when the pathway was pretty much already leavel witht he house path, serfs building spend a lot of time walking around the house thatching, can we have them construct a ladder in the stockpile, and use the ladder to thatch roofs, that would be cool, the other thing i noticed is that rather than waiting for the cook to use the stockpile to cook food, the serfs were eating raw directly from the stockpile preventing food from being cooked, can the cook reserve food in the stockpile and only suprlus is availible to eat raw if no stew is present, we need to up the amount of meat a single deer can provide, we are looking at 60lbs of field dressed meat from a deer that should be enough to feed a camp for a couple of days when smoked or cured ... lets just add a cart with salt in it for curing ... but for now that way a single deer can provide for the camp for a couple of days". Built as a fourth round on the same branch with first rules and values of mine (the handoff lists them as his calls: first, that a first winter now costs the band nothing, and that nothing spoils, so salt's whole effect is at the butchering). He did not say he accepts the third round and took up none of its calls: they stand by default. Not accepted, not merged. |
| 2026-11-12 | The pass's second round, tried by him: "ok, a couple of faults, it would be nice if the serfs found level ground and slept perpendicular to the fire, serfs didn't create a bed when straw was in the stockpile, might have been reserved by the housing, basic needs take priority, serfs would go long distances to fend for themselves to eat vegetables when furit and berries were near by, it would be nice if player had a fill option for closed loop paths, the pathing zone also just forms a stright line by elevation and it is in the air above the ground instead of drawing along it, if a player starts to draw a habitation zone that extends the length of a path and crosses over a path that changes direction a slice of the habitation zone passes over the connecting road, that should be enough for this pass." And a little after: "also can we increase the work and travel speed of serfs by about 50%". Three of these are rulings that stand beyond this pass: **basic needs take priority** (a bed has stored straw before a building has, and comes before the band's building); **one that fends for itself goes for what is near**; **the band works and travels about half as fast again** (built as a pace of 1.5 on every work timer and every step; nothing retuned for it, which is his to ask for). The rest are faults and wishes, built as a third round (Handoff\_2026\_11\_12\_housing\_pass). Not accepted yet. | John |
| 2026-11-12 | The pass on building and zoning as first put to him, answered: "Yes extend as one and they, don't need to be extended as a straight line they can meet and turn into each other, just take the difference between the two. The roof looks good, no need to write a seperate shader program for something that is going to realize it's cost eventually. Hovels need to fit within the confines of the zones, if they don't fit the housing deficit stands until the player designates more area, when we get to the players character they will be told that is problem they need to rectify. Don't let the serfs search for a lot, just assign it to them by lottery, when the construction is complete." And more for the same pass: "have serfs sleep on their side, when the campground is built have them pull or collect straw for a bed, and can we add cloaks, they can set down next to their bed during the summer, wear it during with their winter clothes in the winter, and use it as a blanket when they sleep? When they get assigned a home they can build a new straw bed in their house, we will let the old one decay outside when we add decay later. I think that is enough of this pass before I discuss the stockpile." Settled by it: the walls behind a row are one wall, turning where the backs differ; the look's cost with no roof in view stands; a hovel is nobody's until it stands and is then drawn for by lot; lots are not searched for while the band works. Read by me, his to correct: the hovel next in turn is never passed over for a smaller one. First values of mine, his to tune: everything about beds and cloaks he did not say (a bed is two sheaves; hovels have first call on stored straw; neither a bed nor a cloak does anything). The stockpile is his to open. | John |
| 2026-11-12 | Two calls of stage 6a, answered while it was being built: "continue, one hovel per person for now, dirt discarded is fine for now". A hovel each, children too, until there are families; the earth dug for a hovel's pad that its hollows do not take is thrown aside on the lot, not carried to the stockpile. Both "for now". (The rest of 6a's rules are proposed, not agreed: Stage\_6\_brief; the call that a roof alone keeps the cold off was put to him in the same message and not taken up.) | John |
| 2026-11-12 | References for what is built: "I have added some design refrences in the "/Design Refrences" folder," with a text on the twelfth-century peasant house (timber frame filled with wattle and daub, low stone footings, steep thatch, windows tiny or none, one room, an open central hearth with no chimney, a floor of beaten earth under straw or rushes, sparse furniture, sleeping on straw by the embers). He asked for nothing by name; it is read as what buildings are to be made like, and the hovel was remade from it as far as was cheap. What of it is not built is his to ask for (habitation.md, "Not there yet"). Look in `~/CASTLE_GAME/Design Refrences/` before designing anything built. | John (the reading is mine) |
| 2026-11-12 | Stage 6a is accepted as built: "ok the building looks great, I am impressed, works wonderfully on my end as is". None of its calls was taken up, so each stands by default (first values, his to tune). In the same message: a pass on building and zoning (his words whole in Handoff\_2026\_11\_12\_stage\_6a\_habitation), and the order of what follows it: "That we can do for this pass, then we will have an intermediate sleeping, beds, campfire to house transition. After that we will get to the stockpile, and how the player manages this." | John |
| 2026-11-11 | Stage 6 is opened: "we have completed our preperations on the engine and gotten things in a state to continue with stage 6. Review the directories and docs, do what you need to do, you're in control, go cook". Read as: build it from the design documents and put the rules to him at the end, as stages 5b and 5c were. | John |
| 2026-11-11 | How far released water runs stays as it is for now, by design: "well I built resivors and chained them down the mountain so I could have enough water level to pass down to the next, and out the valley, you just have to keep holding the water back and then letting it out in stages, which is what we want we don't want a players computer locking up becuase they cut a hole to the bottom of the lake and all the water started gushing into the valley, we could let the water travel farther faster later, becuase the player isn't going to be cutting 2m^2 chunks out of a mountain at a time, but you made it so I can tweak the dials when we are ready for that." (The dials are listed in water.md, "How far released water runs". Don't lengthen its run or quicken it unasked.) | John |
| 2026-11-11 | Falls thrown from the lip are accepted as built, and the water with them: "That is perfect, I built an aquaduct from the mountain lake to the valley, and got water to the village with ease and was able to build a dam and and run the water into it and build a small resevoir that filled and held next the village, and when the water started getting to the desired level I just cut the flow down and everything leveled out, great job. Everything flows and looks perfect now." The falls' rules and values stand as first values, his to tune; the calls put to him and not taken up stand by default (the handoff lists them: first, that the arch is drawn and the water itself still runs down the face). | John |
| 2026-11-11 | The touch-ups before stage 6 (the sky, the moon's light, phases and stars, mist, wet surfaces, lights) and the pathing work are accepted as built, after he had tried them: "perfect, everything checks out, looks awesome and works great". Their rules and values stand as first values, his to tune; the calls put to him and not taken up stand by default (the two handoffs list them: first, that a goal out of reach is always answered by the pieces of ground, which moved the reference runs; and that moonless nights are as dark as nights were). | John |
| 2026-11-11 | Multisampling stays at 4x: "MSAA keep it, no need to save a milisecond, if it becomes an issue later we can deal with it then." (It is half of the GPU's frame, about a millisecond; the note on a single-sample picture smoothed afterwards is not built: rendering.md, "What multisampling costs".) | John |
| 2026-11-11 | No budget of time for the colony's steps in a frame: "Time budget we will leave out for now, so we don't interfere with production." (At 240 times speed the colony's steps can hold a frame: Stress\_test.md.) | John |
| 2026-11-11 | The moon gives light, has phases, and there are stars: "Moonlight on the land, phases, stars. Sounds great" (asked for on being told each was cheap and none was built). Built with first values of mine: a month of ten days, the full moon's light 0.30 where the sun's is 0.72, the night's own light left as it was under it. | John |
| 2026-11-11 | The time keys stay a debug tool for now: "no the scrubbing will reman a debug tool for now". They move the clock and the colony takes no steps for the time passed over (his own observation: "it meerly advances the clock, but the world doesn't march with it"), so what follows the clock jumps and what follows the colony's steps does not; Handoff\_2026\_11\_11\_hands\_and\_level lists which. Not to be used in anything measured. | John |
| 2026-11-11 | The save finding of the hands and levelling work is explained, on a lead of John's ("the scrubbing hours and days ... it meerly advances the clock, but the world doesn't march with it. Could be something there"): not the time keys, but the same kind of thing in the runner, whose rebuilds of edited stacks are counted from the start of each run. A save taken between two rebuilds loads into a run a little ahead of the one that carried on. No colony state is lost; colony\_run says when a save is not on a rebuild. | John's lead; Claude Code |
| 2026-11-11 | Stockpile mechanics are rolled in with stage 6, habitation: "I have decided to roll the stockpile mechanics in with phase 6, becuase there are a lot of overlap, I will start that in a new session" ("phase 6" read as stage 6, the next in the plan; the framework's phases are lettered). Nothing of it is designed; he opens it. | John |
| 2026-11-11 | Extra hands limited, a stretch of path to a serf and the camp's floor levelled are closed as built: "great, I think we are at a point to end the session", on the report of the build (he did not say he had tried it). The rules of Handoff\_2026\_11\_11\_hands\_and\_level stand as first values, his to tune. The calls put to him were not taken up and stand by default: the turf cut off a camp's floor counts as earth for its hollows (earth from nothing), the limit covers the camp's building with the cook exempt, the number is a third of the band, idle hands always help and count, 16 blocks to a basket, earth thrown aside with no stockpile, only the floor levelled. | John |
| 2026-11-11 | No save compatibility during production: "don't worry about ever being compatible about mainting compatibility with old saves during production. So we can rewrite the trees". The generator and the save layouts change when the game wants them to; the version is bumped and older saves are refused; no new old-version loader or kept blob is written. | John |
| 2026-11-11 | Realism only as far as it is cheap: "full animations are not important, we want a happy balance between realism and immersion, so just enough realism to be immersive without being expensive and time consuming". A thing looks like what it is and sits where it belongs; no reach, draw or hand-over animation is owed; a look's cost is measured and said. | John |
| 2026-11-11 | The last pass before stage 6 (rounded models, tools carried, the quiver, soft foliage, trees reshaped, grass as tufts, the herds' flight, the fringe of paths) is accepted as built: "impressive, the world is in desirable state, merge it into main and prepare for a session clear", on the report of the second build. The rules and values of Handoff\_2026\_11\_11\_models\_pass stand as first values, his to tune; the calls put to him were not gone through one by one and stand by default (trees where they stood; tall grass half as much, in drifts; the quiver on the hip; a meadow's steps lit as banks; trunks square; nothing sways; deer wade no deeper than a quarter metre). The herds as they were stay in the code behind `--deer-scatter` until someone next works on the herds. | John |
| 2026-11-11 | Paths planned and laid, and no limit on how far, are accepted as built ("excelent, the framework is starting to take shape"): the rules of Handoff\_2026\_11\_10\_paths\_and\_reach stand as first values, his to tune. In the same answer he overruled one (everyone laying paths before its job: "we should limit the amount of workers that can perform extra tasks, for roads I suggest that when a serf starts compacting a road they are assigned a stretch, say 20m for example"), asked for the camp's compacted ground to be levelled ("I have tested it on uneven ground, and it causes some issues with the logs and such ... level the terrain at least for the compacted part, they can move the dirt to the stockpile") and named the topic after that ("then we are going to work on stockpile mechanics"). The other calls shown to him were not taken up and stand by default. | John |
| 2026-11-10 | Zones' ground, the fire's life and the camp built are accepted as built ("everything you have works wonderfully, it is starting to take shape"): the rules of Handoff\_2026\_11\_10\_camp\_and\_zones stand as first values, his to tune. A zone is the ground it fills (fill, snap to the path, terminate at it); paths and zones never share ground; the camp is built by the band (the ground, stone, wood, then the hearth and its pot); a log burns eight hours and the fire dies down for three, tended by hand. The first day's cost stands: eating raw, or fending for oneself, is the opportunity cost of having no stockpile or cooking yet (the eating rules of 2026-11-08, restated). Overruled: no distance limit on what the camp's building takes. To come, from the same answer: paths planned by the player and built by the serfs. Standing by default, shown to him and not taken up: logs carried only by the cook and a forester; the unassigned building too; only a stockpile's places cleared of grass. |
| 2026-11-10 | Shadows and the fire are accepted as built ("Tested and passed, everything works great"): the rules of Handoff\_2026\_11\_10\_shadows\_and\_fire stand as first values, his to tune. Whatever is drawn as a figure or meshed into a stack casts a shadow from every light through one routine; a new asset needs no shadow code. Grass, grain and wild vegetables cast none (put to him as his call, not taken up: it stands by default). |
| 2026-11-10 | Stage 5c is accepted as built ("those mechanics work well and we will polish them up later"): its nine rules (Stage\_5c\_brief) stand as first values. Hunters now answer the band's food, which replaces "hunting runs only while meat is short of its reserve" (2026-11-08). |
| 2026-11-10 | Stage 5b is accepted as built. Its nine rules (Stage\_5b\_brief) were put to John as "agree, or change any" and he answered "I only have critiques that don't concern functionality that we can tweak later, the important part is getting the structure in place and working. So 5c it is." They stand as first values, not as rulings: his critiques are still to come. Two things he was asked and did not take up stand as built by default: the band's first cook is the best cooking aptitude, not the best level; a member whose job nobody gave it is directed by no one. |
| 2026-11-10 | John tries every build himself ("I tested it mouse pointer and clicks work with a real mouse. I always test all your builds"). A handoff says once what only a script exercised and leaves it there. |
| 2026-11-10 | Stage 5a's rules: a right click on the ground opens its menu, and Esc (or the menu) ends a path line; the development tooltip shows everything and the view marks what the player's character could know; one stockpile zoning is one zone, and two that touch stay two; deer get a tooltip and no actions yet; the development panels stay on Tab and the F-keys and the game's interface depends on none of them. |
| 2026-11-10 | The first rows of the action table: raise the stake, lay a path, zone a stockpile, zone the camp, give a job, follow a person, set a reserve, set the winter store, spare apples, spare deer. The player may do them all; a serf none yet. |
| 2026-11-09 | The player's interface: micro on foot and macro from above, see and near, no interruptions, tooltips say and context menus do, reports at the desk, the dev interface as the scaffold (Design pillars, "The player's interface"). |
| 2026-11-09 | Demand drives demand: consumers place demand on the stockpile, the stockpile on producers; a required surplus is the player's artificial demand that keeps production from halting. The player ensures capacity, not supply. |
| 2026-11-09 | Needs, then demand: the undelegated tend their needs; delegation adds a demand, and a post is described by capacity, efficiency and skill. |
| 2026-11-09 | Castle.Colony's body is split into subprogram subunits (Restructure plan, "Pass 2 as done"). The restructure is complete; DOCUMENTATION is gone from the tree and docs/ is the only copy. |
| 2026-11-09 | The windowless runner is built now (stage 4R), not before phase G: every gate is a headless run and must repeat exactly. Stage 5 is split into 5a (widgets) and 5b (skills). |
| 2026-11-09 | README.txt (an untracked copy of the README in the repo folder) is deleted. The Restructure plan was written from the stage 4 zip alone; Claude Code adapts it to the real folder tree (its "The tree as it is" section). |
| 2026-11-09 | Stage 4 is closed for now. The README is split into a main README that keeps the whole project in view and one README per system. |
| 2026-11-09 | Mechanisms first, balance last. Nothing is rebalanced when a mechanic is added; the game is balanced once at the end, against a reference run of a perfect village. |
| 2026-11-09 | The people are autonomous: they meet their needs, then their wants, and feed, house and staff themselves. The player sets the conditions and the starting jobs until hiring begins. |
| 2026-11-09 | Grain is a by-product of straw, cut by porters. It is not eaten raw, and the cook uses it last. |
| 2026-11-08 | Serfs are self-reliant: they eat stew before raw food, and a starving serf leaves its job to find food. Mood is per serf, and the player sees only the band's confidence. |
| 2026-11-08 | color\_palette.txt is the source of every colour. Water is Storm Blue. |
| 2026-11-08 | Forests are thick with sharp edges, lone trees in open land are the fruit trees, and berry bushes are halved. |
| 2026-11-08 | A herd has a node that plans, and deer that wander round it. The short bow is the starting weapon; the sling is gone. |
| 2026-11-08 | Hunting runs only while meat is short of its reserve, never takes a herd below three, and carcasses are butchered at the stockpile. |
| 2026-11-08 | No idle hands hauling. Porters never carry wood. Stone is fetched on demand. Water waits for a use and for barrels. |
| 2026-11-07 | The production plan of stages 0 to 6. Each stage ends with a check, a demo, the README and a zip. |
| 2026-11-05 | The player says where and demand says what. A run ends on the player's death. |

### Open decisions

| Decision | Needed by |
| --- | --- |
| Whether phases C to H and stages 7 to 12 stand as proposed | Phase B close |
| Whether stage 6a's rules stand (Stage\_6\_brief, the 21; the handoff's calls: a roof alone keeping the cold off first) | When he has tried it |
| Stage 6b, stockpile mechanics: which improvements and in what order, what starts each, what each does, whether it is also how goods are kept | Before any of it is built |
| Whether the player's character comes at stage 7 | Stage 6 close |
| What bounds the view from above (it is entered by opening the world tools) | Stage 7 kickoff |
| John's critiques of stages 5a and 5b (not about function; not yet listed) and any tuning of 5b's first values | When he brings them |
| A route store between anchors and a coarse graph over the stacks (his note of 2026-11-11; measured and not built: routes.md, "What routing costs") | When stage 6 has buildings to anchor to, or a village has dozens |
| Whether moonless nights should be darker now that the moon makes the difference (they are as nights were) | When he says |
| Whether water should land where a fall is thrown (reach in the simulation's step: it changes how far released water runs on steep ground), and whether generated falls should be thrown as cut ones are | When he says |
| Which lights cast shadows once a hovel has a hearth in it (today the nearest to the focus does and the rest shine through walls) | The first hearth indoors (stage 6a's hovel has none: the generation spec's has none, and a fireplace is the mason's, stage 8) |
| How the player's character is represented: a member of the band driven by input instead of its own thinking, with the same actions | Stage 7 kickoff |
| The population target for phase C, and the limits that follow (Max\_Members is 48, and a house each at most) | Stage 6 close (not moved at its kickoff) |
| Decided: the README is split into one file per system | Before stage 5, by the Restructure plan tab |
| Reversion: the stock levels to revert and return at, and how many workers revert (first value, stage 6a: a builder fells when no wood can be taken for building and builds when some can; only builders revert, each for itself) | His to change; next at stage 8 |
| The newcomer rate, departures and the steps of unrest | Stage 11 |
| Tool wear and tool tiers | Phase D kickoff |
| How merchants judge demand, what happens when wages can't be paid, where generated coin comes from | Phase D kickoff |
| Squires, courtiers and the final tier names | Phase D kickoff |
| Whether walls and arms count as wealth, and how tribute works | Phase E kickoff |
| Whether the lord keeps diplomacy | Phase F kickoff |
| When the generator is frozen, so that saves stop being refused | Before any outside build |
| A population target for each phase, and the fixed limits that follow from it | Each phase kickoff |
| Whether tunables are loaded from a table for the balance pass | Phase G kickoff |

### Risks

| Risk | Why it matters | Guard |
| --- | --- | --- |
| Castle.Colony is large | Done 2026-11-09: its body is split into subprogram subunits (a 1,750-line body of state and stubs, 50 files of one subprogram each). It is still one package with one state. | Keep new state above the stubs; if a part grows a clear boundary of its own (as Herds has), make it a child package with its own blob section then. |
| The 60 to 80 m world | Loaded ground, work reach and routes all assume one small circle round the stake. | Decide the scaling rule at the phase C kickoff: several loaded areas and a coarse route graph. |
| Tuning on one seed and one site | Every measurement so far is seed 1 at 1178 1078. | Leave it for phase G, which balances on several seeds and sites. |
| Interface gaps | Done for now, 2026-11-10: lists, tabs, tooltips and context menus are in, on one widget layer, from shared views and one action table. Desk reports, text input and draggable windows are not. | Build a new panel as a sheet and a new action as a row, never as code of a panel's own (CLAUDE.md). |
| The on-foot view | Over the shoulder the player sees to the horizon, while only the ground round the stake stays loaded and the view radius is modest. The camera is built top-down today. | Picking is on a ray with a reach since 5a (Castle.Pick; Reach\_M is 6 m, unused from above), so a reticle can cast it. Settle draw distance and what stays loaded at the stage 7 kickoff, with the 60 to 80 m world. |
| Document drift | The README already disagrees with itself in two places, and the project copies lag the repo. | The close list, with the repo (docs/) as the one canonical copy. |
| The size of phases D to F | An economy, officials, an army and diplomacy are each a large body of systems. | Hold to pillar 9, and require the headless gate before each phase starts. |
| Balancing last | A mechanism on rough values can hide a fault until phase G, and a game year takes 6 minutes even at the top speed of 240. | Checks force every branch with scripted conditions. The windowless runner (stage 4R) runs the real world on fixed steps, and each stage keeps the reference run's log. |
| The simulation reaches the figures | Mostly done 2026-11-09: Castle.Herds no longer uses Castle.Animals (the enum is Castle.Deer.Standing\_Mode). The colony and herds still take the genome and deer class types from Castle.Bodies and Castle.Deer, which are data, not drawing. | Leave it unless a windowless build ever needs to drop them. |
| Fixed capacities | Max\_Members is 48, with 1,024 stockpile cells and 4,096 bushes and trees. A village will pass 48 people. | Set a population target at each phase kickoff and raise the limits then. |
| The executable is the second monolith | game/castle\_game.adb is 2,662 lines of options, wiring and colony glue, and the windowless runner needs the same setup. | Stage 4R moves the colony's options, setup and log lines into a package the game and the runner share. The rest of the executable waits. |
| Compile-time tunables | The colony's 57 spec constants, and a few in its body, are fixed at build time. A balance pass that tries many values rebuilds for each. | Keep them as they are, all in the spec. Decide at the phase G kickoff whether to load them from a table; a save must then record the table it ran on. |
