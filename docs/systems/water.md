# Live water

- Packages: Castle.Water; Castle.Falls (how a fall is drawn)
- Check: water_sim_check (about 2 minutes); water_check measures
- Saves: live water in the game save (from format 2)
- Stage: phase A

## Live water

Generated rivers, streams and lakes are source water: asleep it holds the
level it was made at, and what is simulated of it (`Castle.Water`) is how
far it stands from that level. Water the player lets out of it is
simulated until it settles, soaks away or dries. Dig into a riverbank and
the river spills into the pit, dropping beside the cut; dig a tunnel under
the bank and it floods to its roof; close the cut and the river comes back
to its level. Water is kept in saves.

* **Source water.** Every column the generator made river, stream or lake
  (`Flowing`) has the level it rests at (`Rest`: the generated surface at
  that column, `Castle.Geology.Water_Level`, carried from the generator
  through the stack's summary, so it is known whatever is dug or built
  there before the water first wakes). It is the level resting water is
  drawn at, to the unit, so water lies the same asleep and awake. (A woken
  stack used to stand at the top of its water blocks, up to a block off
  the smooth surface drawn round it: a lake showed the square of what had
  woken, edged by a bright line.)
  Resting, it is drawn as a surface cell whose ripples follow the
  generated currents (`Castle.Currents`: the discharge run down each
  channel, spread across it, slowed at the banks; lakes still but near
  inlets and outlets).
* **Asleep and awake** (John's rule, 2026-11-10). Asleep, source water
  holds its level and gives what it has to whatever opens beside it, at
  most its share of the channel's discharge through each face a step
  (`River_Supply` in the game: Q / width over a 0.25 m face). A block dug
  out beside it wakes it (the nine stacks round the edit). Awake, it is
  water like any other, with two differences:
  * *Between source water and source water the flow goes by how far each
    has dropped from its own level, not by their heights.* At their levels
    nothing is simulated to move, whatever the fall between them: a stream
    lies down its hill as it was made however much of it is awake, and the
    water higher up does not come down on the water below. (The river's
    own flow is drawn, not simulated: the simulation only carries what an
    edit changed.)
  * *A column below its level is filled again*: a share of what it lacks
    each step (all of it over about `Refill_Seconds`, 2 s) and at most its
    refill a step (`Source_Refill` in the game: an eighth of a river
    column's own flow; 4 cm a second for a lake). One above its level runs
    off as fast.

  So where a bank is opened the water beside the cut drops and runs out
  through it, the drop fading with distance into the water still at its
  level (a lake 3 m deep behind a cut 1 m wide and 1.5 m deep: 24 cm at
  the cut, 7 cm 2 m in, under 1 cm 8 m in). Where the drop reaches resting
  source water (more than `Wake_Drop`, 3 cm), that wakes too, so the
  active water spreads as it loses height. Closed again, the water comes
  back to its level, is put exactly on it as it falls asleep
  (`Settle_Within`, 8 mm), and sleeps. A river gives what it carries: its
  refill and its resting ends bound what a cut can draw. There are still
  no dams and no rerouting of rivers: beyond the water that is awake, a
  river runs on at its level as it was made.
* **The world as made holds its water.** Where source water stands over
  lower ground in the generated world (the lip of a fall, the dry rock of
  a fall's face), nothing runs out: source water goes out to other ground
  only across a face one of whose two columns has been dug or built in
  (`Touched`: its open rows are not what they were; cutting a plant does
  not count). Water may always run into a source. (Before this, a stack
  woken near a fall leaked down beside it for good: of six falls tried on
  seed 1, each kept one to four stacks awake; now none.)
* **Stretches.** A column holds up to four stretches: runs of open rows,
  each lying on a solid block under a solid block (or open sky). Water lies
  in a stretch from its floor up and never rises above its ceiling.
* **Pipes.** Water passes between neighbouring columns wherever two of
  their stretches share open rows. Each opening is a pipe whose flow keeps
  momentum between steps and gains the head across it times g h dt^2 / l^2
  (two thirds of gravity). Flows are kept in sixteenths of a unit and only
  whole units move, so even the faintest slope still levels.
* **Heavy damping, no waves.** Friction takes a share each step that grows
  as water thins, plus 5 % a step in water 1 m deep or more: a pond 10 m
  across is critically damped, so released water runs and settles without
  sloshing, and ripples die within a second. (Damping this hard would stop
  a river carrying its discharge; that is why rivers are locked.)
* **Released water runs out.** With leaking on (the game; tests run with
  it off for exact books) a column that is not source water keeps 1/256 of
  what it passes on, and a thin sheet on the move (under 1/16 m) soaks away
  at about 1 cm/s. Let out of a river, water spreads round the breach or
  runs some tens of metres down a channel dug for it, and never floods a
  valley. Still water passes nothing on and so keeps its own.
* **Drying.** Once a game minute `Dry_Out` takes what each floor soaks up
  (mm a game hour: gravel 40, sand 25, soil 8, sandstone 2, clay and
  limestone 0.5, laid blocks none) and, under open sky, evaporation from
  the weather (about 2 mm an hour in warm sun, none in rain or frost). A
  puddle on rock lasts about a day. Source water is left out: it is fed
  as fast as it dries. (It was not left out before, and nothing filled a
  locked column again: a river once woken sank into a gravel bed at a
  metre a game day.)
* **Edits.** Digging or placing reads the column's stretches again. Water
  stays in the rows it lay in, where they are still open, and settles on
  the floor of the stretch they are now part of: dug out below, it falls
  in. Water in rows that are now solid is gone (counted as gone out): a
  block placed in water takes its place, so nothing climbs onto what is
  built in it, and a bed raised under water leaves the level where it was.
  Source water filled in to its level is source water no longer, for as
  long as that stands (dug out again, the water comes back); a bed dug
  deeper under it leaves a dip that fills as any drop in it does. The game
  tells the water an edit is coming (`About_To_Change`) before it tells it
  the edit is made (`Ground_Changed`), so the simulation has seen the
  ground as it lay. (It used to see the first column of an edit only
  afterwards, with its water blocks dug away: a dry shaft through a lake
  wherever the first block was dug under it.)
* **Every drop counted.** Depths are integers (65,536 to a block); every
  unit that leaves one stretch arrives in another or is entered in the
  ledger (`Total + Went_Out - Came_In` never changes; what leaks or dries
  is counted in `Dried`). The same start gives the same end to the unit.
* **Awake and asleep stacks.** Only awake stacks are simulated; a stack
  sleeps once nothing has moved in it for 5 s. At most 48 are awake at
  once, and water gets at most 6 ms of a frame: past that it slows, not
  the game. Ten ticks a second, four steps a tick, main thread.
* **A flow established sleeps too.** When for 10 s (`Steady_Seconds`) no
  awake stack with water on the move has had a column deeper than a sheet
  stand more than 8 mm from where it stood (`Steady_Within`), nor gained or
  lost more than a block of water in all (`Steady_Sum`), everything awake
  sleeps as it lies. The stacks still running are kept as running water
  (`Is_Running`): their currents stay drawn, nothing dries off them (what
  feeds them still does), and a save has them as awake, so they find their
  flows again after a load. They wake together, as any resting water does,
  when something beside them changes: close the cut and it all wakes, runs
  out and sleeps for good. A stream cut onto level ground sleeps 40 s
  after the cut. Only a flow that is fed counts (water came in from
  source water over those 10 s): a pond that is only levelling is left to
  the quiet rule, and so is not kept from drying. A ditch dug off a stream
  and full to its level sleeps this way too, as running water: the stream
  falls a little along the ditch's mouth, so a little always runs in at
  the upper end and out at the lower. **Not yet:** water tumbling down a steep slope comes in
  pulses (a column there empties and fills from one tick to the next), so
  it never stands that still and stays awake, as all running water did
  before. Averaging over the pulses would let it sleep, but would also
  stop a pond that is filling slowly; left for a decision.
* **Drawing.** Open-sky water (the top stretch of a column, live or
  resting) is drawn as surface cells from a texture that wraps round the
  camera: previous and current level and the floor, blended between ticks,
  so a change in level needs no new mesh. **The texture is a window of the
  world, 64 stacks across (128 for a wide view), and a slot of it is its
  window stack's alone** (`Castle.Render.Set_Surface_Focus`,
  `In_Surface_Window`, `Owns_Surface`; John, 2026-11-13: "water surface
  stop rendering around the homesteak and some a little distance away,
  water was still there, surface rendered when activated"). Two stacks
  512 m apart share a slot. The view's own stacks never do, but the
  colony's ground stays loaded wherever the camera is: with the camera far
  enough away (520 m in the run that showed it; 150 m did nothing), the
  stacks loaded there were written over the kept stacks' texels and hid
  them when they were unloaded (the river by the stake a dry bed on coming
  back, since a kept stack is never loaded again), and whatever was
  written of the colony's ground meanwhile (a stack meshed again after the
  band's work) was written over the far view's water (a river 512 m from a
  working band's ground, dry along a stretch). Now a stack outside the window is not written, a
  stack hides only a slot it owns, a slot whose owner leaves the window is
  hidden, and every loaded stack the window comes back to has its texels
  written again (the game's `Own_Texels`: an awake stack's last tick, a
  resting one's pool). The debug build checks after every `Stream` that
  each loaded stack inside the window owns its slot. The fault was as old
  as the kept ground (the far end was run on `main` and shows there). It is drawn **stepped** (John,
  2026-11-10: "rippling by stepping the water instead of smoothing"): each
  column stands flat at its own level, taken to the nearest eighth of a
  block (3 cm), with a riser down to any lower neighbour, lit as falling
  water. Still water is one flat face; water dropping toward a cut goes
  down in rings of steps round it; water on the move ripples as its steps
  shift; a fall is a curtain (of generated water at rest; water let out
  over a drop is thrown from the lip: *Falls*, below). `--watersteps N` sets the steps to a block,
  and `--watersteps 0` draws the one sheet of before instead: each corner
  of the block grid at the mean level of every wet column meeting there,
  a slope of water lying as a slope and a fall as the sheet running
  steeply down, with falling-water streaks where it is steep. Water in
  tunnels and under overhangs is laid as blocks and meshed. `--flowmap`
  colours water by its current. Its colour and how much of its bed shows
  go by its depth, and it mirrors the land round it as well as the sky
  (`docs/systems/rendering.md`: deeper water, deeper hue; water mirrors
  the world; `--noreflect`).
* **Falls** (John, 2026-11-11; `Castle.Falls`). Water leaving a column
  over a drop is drawn as a sheet thrown from the lip, not on the face
  under it. The simulation moves water a column a step, so what goes over
  a lip comes down the face below: it was drawn there, a film on every step
  of a slope, a curtain flat against a wall (and edge-on, from the side,
  nothing at all). Now each face of a column that water leaves by, with at
  least 1 cm of it over the sill (`Over_Least`) and a drop of three
  quarters of a block or more just beyond (`Clear_Least`), throws a sheet:
  it goes out at the speed the simulation has the water leaving with
  (`Throw`, a share of it: 1; no faster than `Throw_Most`, 3 m/s, and no
  slower than `Throw_Least`, 0.6) and falls as a thrown thing does, column
  by column, until it meets ground or water, 8 m out at most. Over each
  column it passes the sheet is a slab, from where it comes in down to
  where it goes out, at least half a block thick (twice the water over the
  sill: `Sheet_Over`, `Sheet_Least`, `Sheet_Most`); where its underside
  would be within two blocks of what lies under it, it is drawn down to it
  (`Join`). So over a sheer drop the water is an arch standing clear of the
  wall and going into its pool as one foot; down a steep slope every step
  throws over the next few, and the sheets together are one body standing
  a block or so off the slope, its outline shifting as the speeds do. The
  speed drawn is settled over about a second (`Settle`), because a step's
  flow on a slope swings between a tenth and ten times its mean from tick
  to tick. Sheets are kept while a flow sleeps as running water, and form
  again with the flows after a load.

  **It is a drawing and nothing else.** The simulated water still runs
  down the face, column by column, exactly as it did (under a sheet that
  falls free, water thinner than a block is not drawn: it is the same
  water); `water_sim_check` and every rule above are untouched, nothing of
  it is saved, and nothing the colony does goes by it. Generated water
  throws nothing onto generated water, asleep or awake (what moves
  between its columns when it is woken is how far each has dropped from
  its level, not the stream's flow): a stream's own fall is still a
  curtain, and so is what pours into a pit dug in a lake's bed. The water
  it gives a cut throws as any does. `--nofalls` draws falls as they were; `--throw S` sets
  the share. How it is drawn: `docs/systems/rendering.md`, "Falls".
* **Saves.** Every simulated stack goes in the save: its stretches, their
  depths, which columns are source water and the level each rests at,
  which have been dug or built in, and whether it was awake. About 9 KB a
  stack (format 6; in an older save source water rests where it lay, and
  every column counts as dug or built in).

Limits: there is no pressure, so a shaft fed through a full tunnel fills
only to the tunnel's roof.

## John's rules (2026-11-10), and what stands for each

His words, from testing the build of that morning (the sheer wall of water
at a cut, water climbing onto planks, the dry lake bed):

* "water that was placed into the world is source water, asleep or awake";
  "if water is actively flowing, meaning that a block has been removed next
  to source water it becomes awake, the water level begins to drop": *Source
  water*, *Asleep and awake* above.
* "the farther active water moves away from source water the farther it
  drops, when active water reaches a threshold drop it awakens the source
  water behind it, and begins to radiate outward": the drop fading into the
  water at its level; `Wake_Drop`.
* "we have to be careful that active source water say the stream flowing
  down from the mountain does not become overrun with the higher elevation
  source blocks trying to seek its level": the flow between source water
  and source water goes by how far each has dropped, not by height; and the
  world as made holds its water.
* "when water is filled in it removes the asleep source blocks not replacing
  it, so it doesn't climb on placed blocks, that also resets the source
  water elevation it is trying to get": *Edits* above; filled in to its
  level it is source water no longer.
* "once the flow is established it can fall asleep again": *A flow
  established sleeps too*, with its limit.
* "rippling by stepping the water instead of smoothing": *Drawing*.
* "you can simulate momentum and velocity by simply allowing the water to
  move further in relation to the column of water moving forward": what
  stands today is the pipes' own momentum (a flow keeps what friction
  leaves of it from step to step, and gains by the head times the water
  over the sill, so more column behind it is more speed, up to a column a
  step, 10 m/s). Water does not yet travel further than the next column in
  one step: no jet off a ledge. Not built; see below.

His words on falls came the next day (2026-11-11), with three pictures of
a lake let out through a cut and down a hillside into a pool held by a
wall: "look at the big hole and the almost linear path the water is taking
down, can we make it more of a arch, water rollong over itself, and second
can we have the water extend from the wall face so it doesn't become just
streams down the wall face, I think the arch flow dynamic would take care
of that but if it doesn't." *Falls* above is what stands: the arch and the
standing off the face are drawn, from the simulated speed at the lip; the
flow itself is as it was.

He accepted the falls the same evening, and with them gave his own account
of the water in use: "That is perfect, I built an aquaduct from the mountain lake to the valley, and got water to the village with ease and was able to build a dam and and run the water into it and build a small resevoir that filled and held next the village, and when the water started getting to the desired level I just cut the flow down and everything leveled out, great job. Everything flows and looks perfect now." That is his
test, not one made here, and how he did it he said next: "well I built resivors and chained them down the mountain so I could have enough water level to pass down to the next, and out the valley, you just have to keep holding the water back and then letting it out in stages, which is what we want we don't want a players computer locking up becuase they cut a hole to the bottom of the lake and all the water started gushing into the valley, we could let the water travel farther faster later, becuase the player isn't going to be cutting 2m^2 chunks out of a mountain at a time, but you made it so I can tweak the dials when we are ready for that."

So, by his account, the water went down the mountain by stages: a
reservoir filled, held, and let out to the next. **That water does not
travel further and faster of itself is wanted, and decided for now**: a
cut to the bottom of a lake must not send the lake into the valley and
lock a player's computer. Letting it travel further and faster is for
later, by the dials (*How far released water runs*, below). Nothing of
his test was built or measured here, and it has no check of its own. (I
first wrote here that his channel had carried the lake's water to the
valley, further than the rules say: that was my guess from his first
message, and wrong.)

These were first values and a first reading of his words, put to him with the
build. He accepted it as built the same day: "Everything is working as it should, I am not seeing any room for improvement right now, I am happy with the state of water, all my tests achive the desired result." They stand, his
to tune.

## Not there yet

* **Reach** (his rule above): water leaving a ledge with a deep column
  behind it landing some columns out, a jetting fall. Since 2026-11-11 it
  is drawn so (*Falls*), and the water itself still moves one column a
  step: under the arch it goes down the face and reaches the pool at the
  wall's foot, not where the arch comes down. Making it land there would
  touch the step: the soak is by the column passed, so water thrown over
  ten columns would run further on every steep slope; the wake rules and
  the 77 checks go by neighbours. It may also be the cure for the pulses
  below. His to ask for.
* **Generated falls are curtains still.** A stream's own fall has no
  simulated flow to throw. It could be thrown from the generated current
  (`Castle.Currents`) the same way; not asked for.
* **Running water on a slope never sleeps**: it comes in pulses. Either the
  pulses are damped, or steadiness is judged on averages (which would also
  stop a pond that fills slowly).
* **Settled water is not source water.** Water let out that comes to rest
  sleeps, but holds only what it has: a pond filled from a cut drains if it
  is opened. (His words were "if new water settles it becomes source
  water"; whether a filled pond should become an endless source is his to
  say.)
* **No dams, no rerouting**, and none planned (John, 2026-11-10: "We
  scrapped dams and rerouting, maybe something we can do later, but it's
  not the purpose of this game"). Beyond the water that is awake a river
  runs on at its level as it was made; block a stream and it neither backs
  up nor runs dry below. That is of generated rivers. Water let out of a
  source is another matter: on 2026-11-11 he took it down a mountain to a
  village by reservoirs chained one below the other, each held back by a
  wall and let out to the next (his words, above), with the water as it
  is.
* **How far released water runs** (the leak and the sheet's soak) was set
  for the trickle a locked source gave through a cut. A cut now passes what
  its size and the water's depth allow (about 1.6 m^3/s through 1 m by
  1.5 m), so more comes out; the soak was left as it was. **It stays as it
  is for now** (John, 2026-11-11, after taking water down a mountain by
  reservoirs in stages: "which is what we want ... we could let the water
  travel farther faster later ... you made it so I can tweak the dials
  when we are ready for that"). The dials, none of them changed since he
  accepted the water:
  * how far it runs: `Leak_Den` (a column keeps 1/256 of what it passes
    on), `Sheet_Depth` and `Sheet_Loss` (a sheet under 1/16 m on the move
    soaks away at about 1 cm a second), in the body, `castle-water.adb`,
    under "Source water and drying"; and what each floor soaks up
    (`Seep_Rate` in the game) with the weather's evaporation (`Dry_Water`);
  * how fast it runs: `G_Den` (the pull of the head), `Friction`,
    `Still_Share` (the damping), `Substeps`, at the top of
    `castle-water.adb`;
  * how much a source gives: `Lake_Refill` (4 cm a second), `River_Supply`
    and `Source_Refill` in the game; `Refill_Seconds`, `Wake_Drop` in
    `castle-water.ads`;
  * how much of it the machine will do: `Max_Awake` (48 stacks at once, in
    `castle-water.ads`) and the 6 ms of a frame the water gets (the game's
    loop). These two are what stand between a great flood and a locked
    computer: a flood past them slows down, the game does not.
  A change to the first three groups moves `water_sim_check`'s figures:
  run it, and say which.

`./bin/debug/water_sim_check` tests the simulation on made-up ground
(basin, breach, river cut and what it draws, tunnel, drying on sand and
rock, a spill that stops spreading, calm pond, building in water, save and
back, the ledger, determinism; and source water: first touched, a gap made
with the world, a lake opened and closed again, a save with it drawn down,
built in and dug out, a stream on a hill, a flow established and the cut
closed; 77 checks, about 3.5 minutes in debug). A
scripted run prints one line on the live water when it ends (`water out of
its sources: N columns, V m^3; source water below its level: N columns, at
most D m`). Test options on the game:
`--dig` (up to eight boxes), `--fill`, `--puddle X0 Y0 Z0 X1 Y1 Z1 DEPTH`
(pour water there once loaded), `--late` (do the edits once the view has
loaded, the same path a click takes), `--simticks N` (run N water ticks at
once after them), `--timescale H`, `--flowmap`, `--nofalls`, `--throw S`
(a scripted run with a fall in it ends with "falls: sheets over N
columns"):

```sh
./bin/castle_game --at 969 909 --dig 963.5 908 13.5 973 909 14.5 --dig 972 907 13.5 974.5 910 20 \
                  --late --simticks 600 --frames 3 --shot tunnel.png --save tunnel.castle
```

Headless screenshots (tool calls in the sandbox stop at 300 s, so start
long runs in the background and poll). GLFW 3.4+ prefers Wayland whenever
`WAYLAND_DISPLAY` is set, so under a Wayland desktop `xvfb-run` alone still
opens a real window (on the real GPU); either run the game with `--float`
so it floats at its `--size`, or `env -u WAYLAND_DISPLAY xvfb-run ...` for a
truly hidden window (software GL, slow):

```sh
xvfb-run -a -s "-screen 0 640x360x24" ./bin/castle_game --size 640 360 --view 48 \
         --at X Y --cam YAW PITCH DIST --frames N --shot out.png --novsync
```
