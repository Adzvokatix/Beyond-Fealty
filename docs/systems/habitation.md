# Habitation

- Packages: Castle.Buildings (the hovel: its design and its blueprint), Castle.Colony ("housing": zones, lots, the builder, residency), Castle.Buildings.Layout and Iso (the older preview)
- Source: `src/castle-buildings.*`, `src/castle-colony.ads` ("housing"), `src/castle-colony.adb` ("housing: where a house stands", "housing: blueprints, lots, the ground", "housing: the builder", "housing: zoning"), `src/castle-colony-think_house.adb`, `src/castle-colony-step_house.adb`
- Check: colony_check ("housing", 53 checks), pick_check (6); `tools/reference_check.sh` (`reference_run_stage6.txt`); `tools/stress.sh runner` (the housing run kept and not kept, and on two workers)
- Saves: in the colony blob, version 19
- Stage: 6a (2026-11-12; `docs/production/briefs/Stage_6_brief.md`, `docs/handoffs/Handoff_2026_11_12_stage_6a_habitation.md`). Built on rules drawn from the design documents with first values of mine and put to John; two of them he answered while it was being built ("one hovel per person for now, dirt discarded is fine for now"). Accepted as built on 2026-11-12 ("ok the building looks great, I am impressed, works wonderfully on my end as is"); the calls he did not take up stand by default.
- References: John's, added 2026-11-12 while it was being built, in `~/CASTLE_GAME/Design Refrences/` (outside git: fifteen pictures of twelfth-century peasant houses and villages) with a text on the peasant house of that century; the handoff has his words and the text. How the hovel is made is drawn from them ("The hovel", below; what of them is not built is under "Not there yet").

## What the player does

Housing is a zone. The Housing tool (the Tools panel, or "Housing from
here" in the ground's menu), then two corners beside a path: the lot is
laid out the way every zone is (`colony.md`, "Zones": fill, snap,
terminate), shown as it would be taken while the second corner is chosen,
and it has to come within a metre of a path's edge. It is refused where
not one hovel would fit, and beyond the reach the band's ground can be
kept in at (256 m from the stake). The note says how many hovels it has
room for as things stand. That is all the player does: which lot, which
house, for whom and when are the band's own.

## What the band does

* **Everyone without a home asks for one**, a hovel each (John,
  2026-11-12: "one hovel per person for now"). Once a colony second
  (`Begin_Houses`) a hovel is begun for whoever has none, in the band's
  order: it is that person's from its first block. Only so many are begun
  at once: as many as there are foresters to build them, and one even with
  none, so that the zone can say what it waits for. A hovel whose owner has
  died goes to the first without one.
* **Where.** The free frontage nearest the homestake along any path a
  housing zone lies on (`Place_House`): a point every metre of every path,
  to either side, taken in order of its distance from the stake. The house
  stands square to the block grid, facing the path, its front wall half a
  metre to a metre off the path's edge; where the path runs aslant it steps
  back until it is clear, 3 m at most. Its walls and the bank round them
  must lie wholly on the zone's free ground (so a tree, a bush, a boulder or
  water on a lot refuses it: nothing clears a lot yet), on ground that falls
  no more than 2 m across it. It keeps a lot 7 m along the path and 7 m
  back, and no two lots overlap.
* **Its door can always be got to** (`Door_Way`, `Door_Steps`,
  `Target_Row`). Straight out from the door to the path's ground is the
  door's way: level with the floor for three blocks (`Door_Landing_B`: a
  serf stepping down to a door from higher ground would not clear the eave
  and the lintel), then a stair of single steps, cut or built up, to the
  path. A floor can so lie only a step above or below the path where the
  path is hard by, and a step more for each further block: a pad that would
  lie higher is cut down to that (more is dug off, and thrown aside), and a
  house whose pad would lie lower stands further back from the path until
  its stair is long enough (3 m at most, as on a slanting path). The way is
  part of the house's ground: its builder makes it with the pad, and the
  footpath laid when the house stands runs down it.
* **The hovel** (`Castle.Buildings.Design`; its size and its place from
  the generation spec, `docs/design/preliminary_PROCEEDURAL_GENERATION.txt`;
  how it is made from John's references of 2026-11-12, the peasant house of
  the twelfth century). From its seed alone: 5.25 to 6.5 m along the path
  and deep enough for 25 square metres of floor (6 m at most), one room,
  walls 2.25 or 2.5 m, the ridge along its longer side; a door 1 m by 2 m
  in the front wall, in the middle or toward a corner; beside it, on the
  wider side, a small window (half a metre square, 1.25 m off the floor,
  to keep the heat in); half the time another in another wall. **A timber
  frame filled with wattle and daub**: a post of dark log at every corner,
  either side of the door and about every metre of wall (`Stud_B`), a beam
  along the top, a lintel over the door and a sill under each window; pale
  daub between the timbers and in the gables (a block of its own, `Daub`:
  `Castle.Colors.Daub_Clay`, darkening when wet); **a floor of beaten
  earth** (the pad's own ground trodden hard, as a path is); a roof of
  thatch two blocks thick, a block of rise to a block of run, with a block
  of eave. A blueprint is a pure function of the house's seed and of where
  it stands: the colony keeps the seed and the place, never the blocks.
* **Builders come from the foresters** (`Trade_Kind`, `Trade_From`: the
  first earned trade). A forester takes a house that has no builder, the
  best at building first, and is its builder until it stands
  (`Site_Of`, `Trade_Of`). Nobody is appointed (it is not a job in anyone's
  menu) and no skill is asked. Building is its own work, not an extra task:
  it counts against no limit on hands, and the camp's building and the
  paths come first for it as for anyone. Given another job, it leaves the
  house to the next forester free to take it, and a log in its hands goes
  back to the stockpile.
* **The ground first.** A square metre at a time (`Tamp_S`, at its rate for
  `Site_Work`): what grows on the lot is cut, a neighbouring tree's leaves
  and boughs hanging where the house and its eaves will be are lopped (the
  tree stands, and is felled as any other: nothing of a felled tree is
  taken out of a house, `In_A_House`), the ground under the walls is
  brought to one level (the pad), the door's way is cut or built up, and a
  bank is feathered round it, a metre wide behind and beside (as far as the
  lot is) and half a metre before the front wall, one block of rise to a
  block of run. The pad's level is the
  highest at which what is dug off is at least what the hollows take, as
  for the camp's floor. The earth is the site's own: what is over is thrown
  aside on the lot (John, 2026-11-12: "dirt discarded is fine for now"),
  not carried to a stockpile.
* **Then the blueprint, block by block** in its order
  (`Castle.Buildings.Blueprint`): the threshold under the door and the
  floor beaten, row by row; the frame
  (each post raised whole, round the house; the sills and the lintel; the
  beam along the top); the daub, a course at a time, each walked round the
  house; the gables; the roof, strip by strip from one eave over the ridge
  to the other; and, when the last block is laid, a footpath from the door
  to the path. The builder lays sixteen blocks, a square metre, in a bout
  of 5 s (`Lay_Blocks`, `Lay_S`, at its rate for `House_Raising`, which
  teaches building, a little carpentry and less forestry), from what lies
  at the site, standing clear of the wall it is at (outside for the walls
  and what is near them, inside for the rest). A block is not laid where
  someone else stands.
* **Materials** are carried from the stockpile by the builder, a log or a
  load of straw (six sheaves) at a time, and are the site's from when they
  arrive. **Timber is logs** (a log makes 96 blocks: `Planks_Per_Log`);
  **thatch is straw, and so is daub** (a sheaf makes 64 blocks of either:
  `Thatch_Per_Sheaf`; the daub's earth is the site's own and its wattle
  what was cut there, neither carried nor counted); **the floor takes
  nothing** but the work (`Kind_Of_Block`). All of a house's timber is laid
  before anything of straw (`colony_check` holds every blueprint to it:
  `Next_Kind` rests on it). What a house takes is counted from its
  blueprint (3 or 4 logs and 26 to 31 sheaves; as first built, of plank,
  it was 14 to 16 logs and 17 to 19 sheaves) and what its zone's houses are
  still short of is asked of the stores (the zone's `Once` rows of the
  demand table: `colony.md`, "Demand"), so foresters fell and porters cut
  straw for it. Building never takes the logs the camp's fire
  burns in a day, nor those its seats and its hearth still want
  (`Free_For_Building`). What is left of the last log and sheaf when the
  house stands is offcuts.
* **Reversion.** A builder with nothing to build with (no wood in store
  that building may take; no straw, once the frame stands) goes on as the
  forester it is: it fells while wood is asked for, and comes back to its
  house when there is something to lay. Its status says what its house
  waits for ("no straw to build Cedric's hovel with"). At nightfall, or
  very hungry, it leaves off as anyone does, but a load already on its way
  to the house is carried there first. **So with nobody
  cutting straw a house stops at its bare frame** (a porter cuts straw; the
  reference band has none).
* **Residency.** When its hovel stands its owner lives there: it sleeps in
  it (`Bed_Spot`: in the back corner, a metre off the walls, lying along
  the house) instead of by the fire, and asleep under its own roof it is
  not cold in winter, fire or no fire (`At_Home`, `Cold`). Nothing else
  follows from having a home yet.
* **The colony's ground reaches its housing** (`Ground_Reach_M`): the
  stacks under every housing zone stay loaded wherever the camera is, as
  the ground the band works on does.

## What is shown

A housing zone is filled like any zone (a pale blue). A house begun is
outlined where its walls will stand, with a mark at its door, until it
stands. A tooltip on a house (its walls, its roof, or the ground inside
its outline: `Castle.Pick`, `A_House`; `Castle.Views.House`) says whose it
is, what is being built (the ground, the floor, the frame, the walls, the
roof) and how far, who builds it, the logs and sheaves
carried to it of what it takes, and what it waits for (a builder, wood,
straw, a way to it). The zone's sheet says how many stand and how many
are being built, who is still without a home, a line for each house being
built, what the zone still takes, and why nothing moves when nothing does
(no builder: builders come from the foresters; no room for another: mark
more housing along a path). A person's sheet says where it lives, and a
builder's what it builds. The log's `housing:` line says the same, and
how many are at home (asleep or not, inside their own walls:
`Castle.Scenario.Housing_Line`).

## Options

`--housing X0 Y0 X1 Y1` (a housing zone, up to 8), `--homes-built` (a
hovel for everyone the zones have room for, built on the spot, as
`--camp-built` builds the camp). `colony_run --no-memos` also turns off
what housing keeps only to save work (a blueprint drawn once while it is
the one in hand; a search for a lot that found none not made again until
a zone, a path or a house has changed): a run must end the same either
way, and `tools/stress.sh runner` proves it.

## Tunables

At the top of `castle-buildings.ads`: the hovel's sizes (`Min_Floor_B`,
`Min_Width_B`, `Max_Width_B`, `Max_Depth_B`, `Depth_Var_B`, `Wall_H_B`),
its openings and its frame (`Door_W_B`, `Door_H_B`, `Window_B`,
`Window_Up_B`, `Stud_B`), where it stands (`Setback_Min_B`,
`Setback_Max_B`, `Max_Push_B`, `Max_Step_B`, `Apron_B`, `Apron_Front_B`,
`Door_Landing_B`, `Lot_B`). In `castle-colony.ads`, "housing":
`Lot_M`, `Planks_Per_Log`, `Thatch_Per_Sheaf`, `Lay_Blocks`, `Lay_S`,
`Build_Reach_M`, `Reach_Slack_M`, `Stand_Off_B`, `Stand_In_B`,
`Stand_Near_M`, `Bed_In_B`, `Home_M`, and the capacities (`Max_Houses`,
`Max_House_Blocks`, `Max_Fronts`, `Max_Site_Patches`).

## Saves

Colony blob 19, after everything of 17: how many houses have ever been
begun (the next one's seed is made from it), then each house's zone, seed,
front-left corner, the way it faces, its pad's level, how long its door's
way is and the row of the ground where that meets the path, whose it is, whether
its ground is ready and whether it stands, how many blocks of its
blueprint are laid, the logs and sheaves carried to it and how many
blocks' worth of each lie there not yet laid; then, for each member, the
house it is building and the patch of its ground it is at. A house's size
and openings are its seed's (`Design`), and what it takes is counted from
its blueprint again on a load. **So a change to `Design`, to the order
`Blueprint` emits in or to what a house keeps moves the blob's version** (a
saved count of blocks laid would mean other blocks): 18 was housing's
first layout and the hovel of plank, on the stage's branch only, and is
refused; a blob of before it loads with no houses. By John's rule of
2026-11-11 no version 17 or 18 blob is kept and no check loads one
(`colony_check` marks a blob 18 and sees it refused).

## What it costs (seed 1, the reference site, release)

- The stage 6 run's 41 days: the colony's steps 5.9 s (the reference
  band's without housing the same), 14,513 plans where that has 12,112 (a
  builder plans a short way for every bout), the longest colony second
  17.8 ms against 17.3. (A carrying state that bedtime may interrupt plans
  twenty times a second all night: the first round's build read 29,953.)
- The hamlet of six at the default view (1280 x 720, RX 6900 XT): 0.12 ms
  of GPU a frame more than the same ground without its houses, 0.13 in
  rain; 36,000 quads.
- Planning a zone while its second corner is chosen: 0.8 to 1.0 ms a
  frame for a lot 52 m by 10 m (six hovels), the same as a stockpile's
  plan of that size.

## The older preview

`./bin/village_preview [residents]` is the first prototype, kept: it finds
a dry hillside near water, lays a branching pathway network from the
stake, zones habitation round it and builds one house per resident, some
sharing a side wall (`Castle.Buildings.Layout`, on the generated fields),
and renders `preview/village.png` with the isometric renderer. Its houses
are drawn by the same `Blueprint` the game builds from.

## Not there yet

- Of John's references, not built (each is his to ask for): **a hearth**,
  the open fire in the middle of the room with no chimney, and sleeping by
  its embers (it would be the first fire indoors: which lights cast is an
  open decision of the lights' table, and whether a roof alone keeps the
  cold off is a call of this stage he has not taken up); **low stone
  footings** under the frame (the spec's improvement, "a stone base": it
  would give the stone in store its first use in a house); **straw or
  rushes on the floor**; **furniture** (benches, stools, a trestle table,
  a chest); **shutters or skins** on the windows and a door that shuts; a
  roof steeper than one to one, and deeper eaves (the eave is why a door
  needs its landing: a deeper one would want the door's way looked at
  again); the longhouse, the croft behind a house and its fence.
- Clearing a lot (a bush, a tree or a boulder on it refuses it); houses at
  any angle but square to the grid; shared walls; improvement (a storey).
- Families (a hovel each, children too); choosing who is housed first.
- Un-zoning; pulling a house down; mending one that has been dug into (a
  block dug out of a standing house stays out).
- A builder's tools and a building animation of its own (it crouches to
  its work as a serf making ground ready does); scaffolding (the roof is
  laid from the ground).
- A view into a house from above: its owner asleep inside is under the
  roof and is not seen.
- Stockpile improvements (stage 6b: `Stage_6_brief.md` lists what is
  asked of John).
- Rock under a pad is dug as earth is; earth for a hollow is never short
  by how the pad's level is chosen, but ground dug up on a lot after it
  was begun is filled from nowhere.
