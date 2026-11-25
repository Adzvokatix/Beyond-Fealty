# Stage 6 brief: habitation, with stockpile mechanics (phase B)

2026-11-11, brought up to what was built on 2026-11-12. **6a was accepted as built on 2026-11-12** ("ok the
building looks great, I am impressed, works wonderfully on my end as is") and is on `main`; none of its calls
was taken up, so the rules below stand by default as first values. What follows is as it was put to him.
John answered two of its calls while it was being built (2026-11-12: "continue, one hovel per person for
now, dirt discarded is fine for now"): rules 3 and 16 below stand on his word, "for now". The rest are
proposed, not agreed. As first written: John opened the stage ("we have completed our preperations on the
engine and gotten things in a state to continue with stage 6 ... you're in control, go cook"). Nothing
of it had been designed beyond the documents, so the rules below are drawn from them with first values
of mine: the plan's line for the stage, `docs/design/preliminary_PROCEEDURAL_GENERATION.txt` (the
hovel), `jobs.txt` and the Organized Design (builders from foresters, reversion, base needs first), the
building conversations (pathways set the public edge; a blueprint is a pure function of its pathway
context, seed, occupancy and improvement level) and the framework's pillars. The stage is built on them
on branch `stage-6`. Nothing is merged or written into CLAUDE.md as a designer's rule until John agrees
or changes them.

**John's references, 2026-11-12** (while 6a was being finished: "I have added some design refrences in
the "/Design Refrences" folder," with a text on the twelfth-century peasant house; the handoff has both
whole; the folder is `~/CASTLE_GAME/Design Refrences/`, outside git). He asked for nothing by name. Read
as what the buildings are to be made like, and the cheap part of it built at once: rule 8 is rewritten
from it (a timber frame filled with wattle and daub, a floor of beaten earth, small high windows), rules
15 to 17 follow from it (what a hovel takes, the order of work, what a band with no porter gets), and
rule 10 lists what of it is not built. All of that is as proposed as the rest.

The stage is in two parts, as stage 5 was in three:

- **6a, habitation**: a housing zone along a path, a hovel for everyone without a home, builders from
  the foresters raising them block by block from wood and straw, residency. This brief.
- **6b, stockpile mechanics**: what John has said of it is one sentence (2026-11-10: "they will
  eventually start upgrading the stockpile, build a storehouse, warehouse, fences and outdoor storage
  will get coverings") and that it overlaps with habitation (2026-11-11). 6a builds what the two share:
  a thing built on a zone from a blueprint, by builders, from materials the zone asks the stores for.
  What a stockpile's improvements are, what starts each and what each does is his to say: "6b", below,
  lists what is asked of him.

- **Goal (6a):** the player marks ground for housing along a path; the band sees who has no home, lays
  out a hovel for each, and its foresters build them from the wood and straw the stores are asked for;
  each hovel is somebody's, and that somebody sleeps in it.

## Pillars touched

| Pillar | How it is met |
|---|---|
| 1 The player says where; demand says what and when | A housing zone says where. Which lot, which hovel, for whom and when are the band's: a hovel is begun for each person without a home, nearest the stake first |
| 3 Serfs are self-reliant | Nobody is told to build: a forester turns builder when there is a hovel to raise and wood to raise it with, and goes back to felling when there is none |
| 4 Failure is visible and recoverable | A zone with no room, no builder, or short of wood or straw says so on its sheet; the Stores tab shows straw "asked of nobody" with no porter. The fix is a zone, a path or a job |
| 5 Conditions improve things; clicks don't | There is no "build" button and no builder to appoint. Homelessness, a lot, a forester and materials are the conditions |
| 7 Emergence over scripting | Housing competes with the fire for logs and with felling for the foresters' days |
| 9 Few natural parameters | A lot's size, a hovel's size range, blocks to a log and to a sheaf, blocks laid in a bout |
| 10 Progression teaches governing | The player learns here that one forester cannot house a band by winter: capacity is his to see to |

## Rules proposed to John (6a)

Zoning
1. **Housing is a zone**, marked like a stockpile: two corners, laid out along the nearest path (fill,
   snap, terminate), and it has to come within a metre of a path. It is refused where not one hovel
   would fit. One zoning is one zone; there can be several.
2. **The player marks only the zone.** Lots, blueprints and who lives where are never his.

Demand
3. **Everyone without a home asks for one**: a hovel each, children too (there are no families yet).
   (John, 2026-11-12: "one hovel per person for now".)
4. **A hovel is begun for a person**: it is that person's from its first block, and is shown as theirs.
5. **Only so many are begun at once**: as many as there are foresters to build them, and one even with
   none (so that the zone can say what it waits for).
6. **Where**: the free frontage nearest the homestake, along any path the zone lies on. Each hovel has a
   lot 7 m along the path and 7 m back; no two lots overlap.

The hovel (the generation spec, with the prototype's variation)
7. Its walls stand 0.5 to 1 m back from the path's edge, its door (1 m by 2 m) facing the path, a
   footpath from the door to the path. Houses stand square to the block grid; on a slanting path they
   step back along it. A lot may fall up to 2 m across the house (a hillside): the pad is cut into it.
   A lot is refused where a tree, a bush, a boulder or water stands on it: clearing one is not built.
   **A door can always be got to**: before it the ground is level with the floor for three blocks, then
   a stair of single steps to the path; a floor that would lie too high above the path for that is cut
   lower, and a house whose floor would lie too far below stands further back (3 m at most). (Added
   2026-11-12: on the hillside south of the reference path two of four owners could not get home.)
8. 25 to 30 square metres of floor inside walls a block thick, one room; walls 2.25 or 2.5 m; **a
   timber frame filled with wattle and daub** (posts of dark log at the corners, either side of the
   door and about every metre of wall; a beam along the top, a lintel, sills; pale daub between them
   and in the gables); a small window (half a metre square, 1.25 m off the floor) beside the door, now
   and then another in another wall; **a floor of beaten earth** on ground made level; a gabled roof
   of thatch. (From John's references of 2026-11-12. As first built it was plank walls and a plank
   floor with a window a metre square.)
9. Size, wall height, where the door and windows go are the hovel's own, from its seed: no two alike,
   all of a kind. **A blueprint is a pure function** of where it fronts its path and its seed.
10. **Not in it yet:** shared walls, improvement; and of his references: the open hearth in the middle
    of the room (and sleeping by its embers), low stone footings under the frame, straw or rushes on
    the floor, furniture, shutters and a door that shuts, a steeper roof with deeper eaves, the
    longhouse and the croft behind a house.

Building
11. **Builders come from the foresters.** A forester takes a hovel to build when one has no builder
    (the best at building first); it is that hovel's builder until it stands. Nobody is appointed a
    builder and no skill is asked yet ("nothing is gated by skill" stands).
12. **Reversion:** a builder with nothing to build with (no wood in store that building may take) fells,
    as the forester it is, and comes back to its hovel when there is wood again.
13. **Building is the builder's own work**, not an extra task: it does not count against the limit on
    extra hands, and the camp's building and the paths still come first for it as for anyone.
14. **The fire comes first:** building never takes the logs the fire burns in a day, nor a log the
    camp's seats still want.
15. **What a hovel takes** is counted from its blueprint: a log makes 96 blocks of timber, a sheaf of
    straw 64 blocks of thatch **or of daub** (the daub's earth is the site's own, its wattle what was
    cut there: neither is carried or counted), and the floor takes nothing but the work. First values,
    set so that the mechanism can be seen: 3 or 4 logs and 26 to 31 sheaves a hovel, and one forester
    raises one in three and a half to four days. (As first built, of plank: 14 to 16 logs, 17 to 19
    sheaves, five or six days.) The zone asks the stores for what its hovels are still short of (rows
    of the demand table), so foresters fell and porters cut straw for it.
16. **The order of work:** the ground made level (a pad under the walls, a bank a metre wide round it,
    half a metre before the front wall; what is dug off fills the hollows, and what is over is thrown
    aside on the lot: John, 2026-11-12, "dirt discarded is fine for now"; a hovel's worth would fill
    six places of a stockpile), what hangs over it from a neighbouring tree lopped; the floor beaten;
    the frame, post by post; the daub, course by course; the gables; the roof; the door's path. A log
    or a load of straw is carried from the stockpile to the site by the builder and laid a square
    metre (16 blocks) at a bout of 5 s.
17. **Porters bring the straw to the stockpile** as they always have; a band with no porter gets a
    floor and a bare frame and no more, and the Stores tab says straw is asked of nobody.

Residency
18. **When its hovel stands its owner lives there**: it sleeps in it instead of by the fire.
19. **A roof keeps the cold off:** asleep at home in winter, nobody is cold, fire or no fire. (His call:
    it is the only thing a home does yet, and it moves the winter for whoever is housed.)
20. **A hovel whose owner dies** goes to the next person without a home.

Seen
21. The zone is shown filled like any zone; a hovel's lot is outlined from the moment it is begun. A
    tooltip on a hovel says whose it is, how far along, who builds it and what it waits for; the zone's
    says how many stand, how many are building, who is still without and why nothing moves if nothing
    does; a person's says where it lives.

## Kickoff decisions the framework lists for this stage

| Decision | First value here |
|---|---|
| Reversion: the levels to revert and return at, how many revert | A builder reverts when no wood can be taken for building and returns when some can; the forester's own rule (every log of a tree home before the next is felled) is the batching. Only builders revert, and each only for itself |
| Which lights cast once a hovel has a hearth | Not needed yet: the hovel as built has no hearth. His references of 2026-11-12 give the peasant house an open fire in the middle of the room, so it is his to open with the hearth. Left open |
| The population target for phase C, and the limits | Not moved: `Max_Members` 48, a house each at most. His at the phase C kickoff |
| Whether the player's character comes at stage 7 | His, at this stage's close |

## Out of scope (6a)

| | Where it goes |
|---|---|
| Shared walls, improvement (a storey, a stone base), furniture, a hearth indoors, shutters, rushes on the floor | Stage 12; stage 8; the hearth when he asks (his references have it in the first hovel) |
| A builder's tools and a building animation of its own | When he asks (realism only as far as it is cheap) |
| Un-zoning; pulling a hovel down; repairing one dug into | Later |
| Families sharing a house | Newcomers, stage 11 |
| A view into a house from above | The on-foot view, stage 7 |

## 6b: stockpile mechanics, asked of John

6a leaves the machinery: a zone asks the stores for what is built on it, a builder takes a site, lays a
blueprint's blocks from what it carries there, and the thing stands. What I do not have, and will not
invent:

1. Which improvements, in what order: a covering over outdoor storage, a fence, a storehouse, a
   warehouse.
2. What starts each (pillar 5: conditions, not a click): everyone housed? the stockpile full? a kind
   of good being kept?
3. What each does. Spoilage and theft are stage 11, so today a covering or a fence would only be seen.
   More to a place under a roof? A storehouse that holds what a lot of open ground did?
4. Whether "stockpile mechanics" is also something of how goods are kept (kinds to a stockpile, a
   stockpile's own demand: the 5c brief left "a stockpile with kinds and demand of its own" for "when
   there is a second kind of store").

What he has said of it since (2026-11-13, answering what a serf with nowhere to put its load should
do: twenty of a crowd of forty-eight stand holding theirs from the second day): **"when we get to the
stockpile mechanics we will reserve a portion of the stockpile for overflow"**. Not built. Still to
ask: how large a portion, whether by kind, and what a serf does when the overflow is full too.

### His design of it (2026-11-17), whole

> Ok merge. Ok, stockpile time, it's time for some additonal insight into the story for context. So
> basically the story is this, the count has granted the player, the honor of improving his far lands.
> They are isolated but need to be developed, we added the cart, that is part of the story. When the
> player places the homestake, a "messenger" is sent to the retinue of serfs and an advisor who will
> assist the player throught the game, a boon of supplies to help supplement the development for the
> first few winters is granted to the player by the lord as well. So we need 13 starting serfs,
> basically the player begins by delegating the tasks, as we have done, the cook becomes the cook when
> it is open, let's limit the number of builders that can be promoted to four. On the second day, the
> advisor asks the player to zone more area, if the stockpile isn't big enough, to build the
> storehouse, the stockpile will then be "upgraded" if it meets the requirements, the builders will
> build a stockhouse, compact the land of the stockpile, build a fence with a gate, build coverings for
> outside materials, etc... Stockhouse gets a wood floor. When the stockhouse is completed, we upgrade a
> serf to manage the stockhouse, who will organize the stockpile, a carpenter will also come about from
> the builders, and a serf can take a builders spot. A carpenter will build barrels and shelves in the
> storehouse, the stockman will pack the barrels with meat and salt, porters can also begin bringing
> water to stockhouse, there will be a staging area in front for the stockman, and the barrels of water
> can be used for berries and apples, hides placed on the self. We need to let the stockman pile the
> wood and straw under the coverings, and they need to extend across blocks so he can stack them higher.
> The coverings will be along the edges of the stockpile next to the fences, the backside. So think of a
> thatch roof with four posts with a larger opening at the front, to pile things under, we need to watch
> stone as well. This happens pretty quick so for the 5 blocks of overflow, if there is no space in the
> stockpile, just have them use 5 free blocks around the stockpile as an overflow to set things down so
> they arent carrything them everywhere, and then they won't collect anymore until space frees up. That
> is the start. Stockman can bring the cart to the front of the storehouse, and unload all the salt into
> the storehouse, the ladders can be leaned up against the storehouse when not in use. But we aren't
> doing the player and advisor thing just yet, so just simulate the request. I don't know make the
> stockhouse some reasonable size, 5x10m same as the houses, but door is on the end of the warehouse,
> path to the door, I think should work for the start. I am still trying to work out how to make the
> zoning fluid, maybe do this, make the minimum zoning area 15x15m for the stockpile, it can be larger
> the workers will adapt, but that will fit the storehouse with the 5m of staging area at the front,
> the fence and coverings for the outdoor stocks. We need to do this in a few passes I think

That answers the four questions above in prose: the overflow is five places round the stockpile (1),
for any load no place in it takes (2), and nobody goes out for more until there is room (3); the
improvements (4) are the passes below. What a serf does when the five are full too he did not say.

### The passes, as I read them (his "a few passes")

Only what he named is built of the story: the messenger, the advisor and the lord's boon are not
built ("we aren't doing the player and advisor thing just yet, so just simulate the request"). The
boon, his answer the same day: "For now there is nothing else to put in the cart besides salt, there
may end up being two carts, we will work out the inventory system soon, so we can add tools and
weapons in there later." Not designed.

His answer to the first pass, the same day: the overflow is a signal (nothing brought in while it
holds anything; the idle at leisure at the campfire; what is in it moved into the stockpile when there
is room; then back to work; "If the player is paying attention during this whole process they should
have expanded the stockpile by then, if not it's on them"). Built on the branch. "We can continue":
the second pass, on the defaults in the first pass's handoff.

1. **The start** (built 2026-11-17, branch `stockpile`): thirteen arrive (`Castle.Colony.Arrivals`);
   at most four builders (`Most_Builders`); a stockpile at least 15 m by 15 m (`Stockpile_Least_M`);
   its five overflow places round it, and nobody setting out for what no ordinary place has room for.
   "The cook becomes the cook when it is open" is how it already works (`Choose_Cook`: once a camp is
   marked and there is something to cook, the best cook of the band takes it up on its own, when the
   player has named no cook): nothing built. `docs/handoffs/Handoff_2026_11_17_stockpile_first_pass.md`.
2. **The storehouse built** (built 2026-11-17, branch `stockpile`, on the six defaults he changed
   none of): on the second day the advisor's request, simulated (the first stockpile that meets the
   requirements is upgraded; with the 15 m least every stockpile does); the builders compact the
   stockpile's ground, build the storehouse (5 m by 10 m like a house, a wood floor, its door on an
   end, a path to the door), a fence with a gate round the stockpile, and the coverings along its back
   edges by the fence (thatch on four posts, open wider at the front); 5 m of staging in front of the
   storehouse. `docs/handoffs/Handoff_2026_11_17_storehouse.md` (what was built, measured, his
   calls: first among them what the one gate costs the band's walking).
3. **The storehouse used** (begun 2026-11-17 on his "Let's move on to the next step", with his answer
   to the barrels: "barrels of water is not a good storage idea for berries and apples. So they can just
   be stacked in the baskets in the storehouse by the stockman"; the storehouse's open calls left open,
   "I have to think about the stockpile layout some more"): when it stands a serf is made its stockman (organizes the stockpile, piles
   wood and straw under the coverings, higher across blocks, watches stone, brings the cart to the
   storehouse's front and unloads its salt in, leans the ladders against it when they are not in use);
   a carpenter comes from the builders and a serf takes the builder's place; the carpenter makes
   barrels and shelves in the storehouse; the stockman packs barrels with meat and salt; porters bring
   water to the storehouse; berries and apples in their baskets in the storehouse (his answer: not in
   barrels); hides on the shelves; the staging area in front for the stockman. **Built 2026-11-17 on
   branch `stockpile`** (`docs/handoffs/Handoff_2026_11_17_storehouse_used.md`: the stockman a porter
   given the storehouse's work first, the carpenter its builder, two barrels of water and six of meat,
   shelves for hides, the places under the coverings holding three times as much).
4. **His playtest notes** (2026-11-17, sent 2026-11-18 as "~/CASTLE_GAME/PLAYTEST NOTES, thoughts";
   whole in `docs/handoffs/Handoff_2026_11_18_playtest_round.md`): his answer on the stockpile's layout
   and what he found trying the storehouse. **Built 2026-11-18 on branch `stockpile`**: the stockpile
   "a onetime placement of a 10x10 zone", the overflow removed, "the last 10 blocks" kept as the signal;
   the storehouse moved to "a new stockyard zone", "doors at each end of the building", the fence
   "around the stockyard with the gates extending from the storehouse, inline with the inside wall",
   the stockyard levelled "same as houses", its apple trees felled, "all deliveries and pickups" moved
   to it when it stands, on "angled paths" too; the faults he named, each reproduced first (hunters and
   gatherers that "can't find" what is close, "grass in the air", a zone that "wraps around the end of
   a path", the storehouse's "transparency"); stone, berries, apples and salt on the stores' sheet,
   apples among the foods kept. **Not built, and put to him as the next pass with a default each**:
   paths levelled, the builder in the job list, deleting part of a zone and razing, doors and their
   opening, cart wheels, thatch thicker with straw at its edges, the windows' timber and trim, trusses,
   the thatcher on its ladder, a rule for a serf that meets an obstacle (the fence's stall was not
   reproduced).
5. **The next pass of those notes** (2026-11-19; his message whole in
   `docs/handoffs/Handoff_2026_11_19_next_pass.md`: "we can continue to the next pass", with "I have a
   new idea for the stockpile, stockyard, storehouse" and his design document
   `docs/design/detailed_mechanics.json`). **Built on branch `stockpile`**: a path levelled as it is
   laid; the band's lists calling a serf by its trade (the builder shown, not given: his document makes
   it a job earned from the woodcutter's); housing ground taken out again and a hovel there marked for
   razing; doors; the cart's wheels; thatch drawn fuller with ragged edges; a window's sill and lintel
   from post to post, plank beside the opening; the roof's timbers (gable trusses, tie beams, and in
   the storehouse a truss on each and a ridge beam); the thatcher shown up its ladder between bouts;
   whoever stands where a block is to go stepping aside. **Not built**: the taking down of a marked
   hovel (his first call), a builder passing over a block, a leaf on the gateways. **His document was
   read and nothing built from it but the builder's name; nothing of the stores was changed**: his
   are many stockpiles along the paths each with a stock hand, and a stockyard of five buildings
   (stock-house, open yard, staging area, granary, stable); whether that is the new idea is his to say.

6. **His eight answers to that pass** (2026-11-19, whole in
   `docs/handoffs/Handoff_2026_11_19_answers_round.md`). **Built on branch `stockpile`**: razing
   "limit[ed] ... to unowned" and the taking down itself; Builder on a person's menu as a development
   job ("the player won't need to delegate further, past opening positions"); "leafs on the gateways";
   "Thin trim around the tops and side(s)" of the windows, drawn; "a ridge beam to the hovels"; "that
   ragged look to the entire surface of the roof". Paths: "Hold, off for additonal playtesting, half a
   metere is fine for now". And: **"Document's stores is my model the new idea, the logistics
   network"**: confirmed, planned below, not built.

Each is built a commit a system, each new system with its switch, gated and put to him before the
next.

## The logistics network (his model; ordered 2026-11-19: "the new design document I added is to be integrated"; the first pass built)

His words: "Document's stores is my model the new idea, the logistics network." The document is
`docs/design/detailed_mechanics.json` (0.6 when this was written; 0.15 since 2026-11-22, the same in these
parts; `docs/design/Mechanics_crosswalk.md` sets all of it beside the build): `zones` stockpile and stockyard, `buildings` stock_house,
open_yard, staging_area, granary, `jobs` porter, stock_hand, stockman, `mechanics.supply_chain`.

| His model | What is built | The gap |
|---|---|---|
| Stockpiles: "Intermediate store along a pathway, near where goods are gathered. Gatherers drop goods here; a stock hand from the yard moves them on." Many. | One stockpile, 10 m square, placed once (his note of 17 November: "a onetime placement of a 10x10 zone"), closed when the storehouse stands | His note and his document disagree: **the first question** |
| "The stockyard assigns one stock hand to each stockpile; he works for the yard, not the pile." Stock hands come from porters; a delivery hand takes the carts out | Porters carry everything; the stockman (a porter, by portering skill) keeps the storehouse and moves the stores in | Stock hands; who is assigned where |
| The stockyard: stock-house (inside), open yard (wood, rock, ore, straw outside), staging area (carts, deliveries assembled), granary, stable | One stockyard lot: the storehouse, its fenced yard with coverings, staging before it | The same things under his names, as one plan; granary and stable are new |
| Supply chain: demand placed by buildings; the stockman schedules deliveries from the staging area; "Building materials go to the work site by cart, so builders keep building instead of walking to the stores for every item" | Builders fetch their own logs and sheaves; the demand table asks the stores per zone | Deliveries to sites; the cart as a tool (two carts and two horses come with the settlers in his start) |
| The porter "Draws water and digs clay ... hauling passes to the stock hands once there is a stockyard" | Porters haul, cut straw, bring water | The porter's work narrows when the yard stands |

His answer, 2026-11-19: "yes the one time placement has be supersceeded, we go back to variable size
stockpile, placed along the path, the new design document I added is to be integrated". Read as the
order to build these passes, in turn (`Handoff_2026_11_19_stockpiles_and_reach.md`; the reading is put
to him).

**Held, 2026-11-19, the same evening: "for the next couple of days we will be polishing, so hold off
on the integration".** Pass 1 stays as built; no later pass is built before he says so.

**Passes, a default each:**

1. *Stockpiles as intermediate stores.* **Built 2026-11-19, as he changed it**: any number, of any
   size, zoned corner to corner along a path; they stay open when the storehouse stands
   (`--one-stockpile` and `--stores-move` are the rules before). The last places kept as now. Until
   pass 2 nothing carries goods on from a stockpile to the yard.
2. *Stock hands.* When the storehouse stands, porters become stock hands by portering skill, one
   assigned to each stockpile that holds anything, carrying from it to the yard; the stockman assigns
   them. Default: a trade, as the stockman is (shown in the lists, on the development menu).
3. *The yard under his names.* The storehouse is the stock-house (tier 1, "Store Shed"), the fenced
   yard with coverings the open yard (tier 2, "Yard with Lean-tos"), the ground before the storehouse
   the staging area (tier 1, "Loading Ground"). Default: names and sheets only, nothing moved.
4. *Deliveries.* A house being built asks the yard; the stockman has its timber and straw taken to the
   site, by cart when the load is a cart's worth, by a delivery hand; the builder stays at the site.
   Default: the one cart, hand-drawn as it is towed today, until there are horses.
5. *The granary and the stable*, with farming and with horses: not before.

**One count toward it** (41 days, the band of thirteen, the reference site, one run each; hungry
serf-hours and the lowest confidence): the stockpile closed when the storehouse stands, as built,
1,824 and 20 %; the stockpile kept open (`--stockpile-stays`), 952 and 55 %; a second stockpile at
the far end of the housing, both kept open, 1,261 and 27 %. **It settles nothing**: the first case
measured the day before, with the build of then, came to 1,000 and 55 %, so single runs differ from
one another by as much as these three do. The network wants a measure of its own built with its first
pass (metres walked per load carried), not hunger.

## Structures on straight and 45-degree paths (his word of 2026-11-19; nothing built)

His words: "I think we need to lock the paths to straight and 45 degree angles, slighty being off
doesn't really work in a voxel world, then we can start planning structures on that design pathway,
keeps things tight and simple". The paths are built (`Handoff_2026_11_19_foresters_and_paths.md`); the
structures are his to plan. What the build does today, for that planning:

- A house (a hovel, the storehouse) is never turned: it stands square to the blocks, fronting whichever
  path its zone lies on, and has its own way from its door to the path.
- Beside a straight path the hovels stand in a line and the zone's edge is straight.
- Beside a path at 45 degrees the zone's edges are clean diagonals, the hovels are stepped back along
  the path, and fewer fit (three and one in two strips that hold three and three along a straight path
  of the same length; one layout).
- A stockyard's lot is square to the blocks (`Plan_Stockyard_Lot`), and its storehouse has to stand
  within 2 m of the path. Beside a path at 45 degrees it is taken only where a corner of its box
  comes to the path: two boxes of five on the flat, none of ten on the hillside east of the stake
  (`tools/stockyard_sites.sh` has the flat one; its storehouse stands). The player's stockpile
  (10 m by 10 m, placed once) was not looked at beside a path at 45 degrees.
  **Since 2026-11-20 a stockyard beside a path at 45 degrees is laid out along the path** ("Buildings
  at 45 degrees", 5, below); what this bullet says is the build with `--no-yard-turn`.

Questions for him, a default each:

1. At 45 degrees, does a building stand along the path (walls stepped a block a block) or square to the
   blocks as now? Default: square, as now, until he has seen it.
2. Are housing and the stockyard kept to straight paths, the diagonals being for roads between? Default:
   no rule; anything may be zoned beside either.
3. Does a path's line go by a metre and not a quarter (so that lots and stockpile places meet it
   exactly)? Default: a quarter, as built.

## Buildings at 45 degrees (his question of 2026-11-19; the way chosen; nothing built)

His words, first: "is there a way we can just turn the buildings and build them at a 45 degree angle
without stepping?"; then, having seen a wall of cut blocks: "why can't the blocks just be rotated on top
of each other? do they have to line up? look at the mats the serfs put on the ground ... can't we just
\"detatch\" the entire building and rotate it? I mean it would still be connected to the ground
essentially, right?", and "I am going to let you has it out".

**The way: the building drawn as one turned piece** (his). Two scratch proofs, neither in the branch
(`~/CASTLE_GAME/releases/`): `diag_wall_proof.patch` (a wall of blocks cut corner to corner: flat, but
the roof has no state bit for it) and `turned_building_proof.patch` with `turned_hovel.png` (every
block of a standing hovel turned about its middle in the land's vertex shader: walls, frame and roof
whole). The second is the one to build.

What it has to answer: a building's blocks are the map's own (walking, pointing, the cutaway, what is
laid, what is saved all read the map's grid), and a block on that grid cannot be turned. So the
building's blocks go into a grid of its own, drawn turned; under it on the map's grid stay its level
ground and hidden blocks where its walls stand, to the nearest block.

Steps, each seen before the next:

1. *The draw.* **Built 2026-11-19** (`Castle.Render.Set_Turns`; `--turn-houses` to look at it;
   `rendering.md`, "A building drawn turned"). Not as first written here: the house's blocks are not
   meshed apart; they stay the map's, where the house stands square on the grid, and are drawn turned
   about a point. With no turn set the picture is the build before's to within what that build
   differs from itself by.

   **What that settles for the steps after** (his question of the same day: "what happens if we add a
   second story to the building can serfs interact with the stairs inside?"): the house keeps
   standing square on the grid for everything the game knows (its walls, its floors, a stair, the
   walking map, which already keeps four floors over one spot); what is inside it is drawn through
   the same turn, so feet are on the treads as drawn; and the turn is about the doorway, the one
   point where inside and outside meet with no jump. The price is ground: a turned house needs the
   ground it really stands on and the ground it is drawn on, so turned houses stand further apart,
   and nobody outside may walk through either.
2. *What is inside, drawn through the turn.* **Built 2026-11-19** (`Castle.Serfs.Turn_About`,
   `Castle.Props.Put_Cloth`'s turn, the game's `Put_In_House`): anyone within its walls, their cloak,
   the bed, the door's leaf, the trim. A figure is turned after it is animated where it stands on the
   map. The house does not carry its turn yet: that comes with step 3, where one is first placed
   turned. A builder working from outside a turned house's walls is not handled: step 3's.
3. *Houses placed turned, and the ground.* **Built 2026-11-19**, in two halves. A hovel beside a path
   at 45 degrees carries a turn (`House.Turn`, from `Place_House`; saved; `--no-house-turn`) and is
   drawn by it, its builder and ladder with it; a turn comes on and off over a moment. **And its
   ground** (`Handoff_2026_11_19_turned_building_ground.md`): the block columns under the house as
   drawn, and two round, are of its site and its lot (`House.Turn_Ground`, `Set_Turn_Ground`,
   `--no-turn-ground`); its floor is laid under it as drawn; its door's way is trodden square to the
   path; who walks keeps off the ground a standing one is drawn on (`Set_Keep_Off`, `--no-keep-off`:
   a tenth of the pace, nothing shut). Measured (`colony_run --turn-stats`, `tools/turned_streets.sh`):
   no column a hovel is drawn on off its pad's level, where up to 466 of 1,156 were; others on that
   ground 22 s of eleven days where they were 210. **What it leaves**: the square the house really
   stands on is turf to the eye and a wall to the feet; a stair to a turned door is still cut straight
   out from the walls as they stand; on a steep hillside (20 to 30 %) no turned hovel is placed, the
   fall being taken under the walls as they stand and as drawn together.
4. *Pointing, the cleared roof and the far view* through the turn. **Pointing and the cleared roof
   built 2026-11-19** (`Handoff_2026_11_19_turned_building_step_four.md`): `Castle.Pick.Look` walks
   the ray taken back through a turned house's turn into the blocks again, and where the first walk
   ended in such a house as it stands the zone under is pointed at, never the block;
   `Castle.Cutaway.Roof` carries the turn, and the eye, its line and the pointer are taken back
   through it. **The far view built 2026-11-20** (`Handoff_2026_11_20_far_view_and_answers.md`): a
   far tile's cells of a building's stuff are turned too, and the ground under them is meshed.
   **His answers of the same evening** (`Handoff_2026_11_19_turned_floor_and_hillsides.md`): "can't we
   step the texture so it falls under the wall of the house?": built, the turned floor's edge drawn in
   steps of a texel under the wall (`--no-turn-floor`); and "we don't want to limit the player they
   need to be able to place diagonals on hillsides if they want to": a turned hovel is placed wherever
   a square one would be (`--turn-fall` for the rule before), its terrace cut as deep as that takes.
5. Which houses turn: those whose path runs at 45 degrees. The stockyard after the hovel: put to
   him 2026-11-20 as three ways: the hovel's way (the whole stockyard stands square and is drawn
   swung: its ground made twice, 15 to 25 m a side, and a square that size beside it that is grass to
   the eye and a wall to the feet); the yard laid out for real along the path as a stockpile's places
   are, its fence stepped, the storehouse alone drawn turned in it (my default); stockyards kept to
   straight paths. **His word, the same day: "Ok go on with the second way for the stockyard". Built**
   (`Handoff_2026_11_20_stockyard_along_a_path.md`; `Set_Yard_Turn`, `--no-yard-turn`; blob 39): the
   lot along the path on its whole metres, the places with it; the ground, the stair of the way in,
   the fence, the gateways and the coverings made for real, block by block (the fence and the
   coverings stepped); the storehouse's own blocks square to the grid about its middle, drawn turned.
   **And past what was put to him: once its walls and roof are up the feet go by the storehouse as it
   is drawn** (`Castle.Nav.Set_Drawn`), so it has no hidden square and whoever is in it is where
   they are seen: its two end doors, 10 m apart, could not both be held by any point to turn about.
   His calls of it: the coverings (stepped; they could be pieces drawn at any turn, not blocks); the
   3 m a stockyard's ground may fall, taken over the lot as it lies; the builder's turn eased while
   the frame, walls and roof go up; the two corners that zone it.
   **The same way would mend the hovel's square** (turf to the eye, a wall to the feet): not built,
   his to say.

   **Then, the same day** ("Let's do that, and what do you think about turning the fence too? The
   outdoor roof covering needs a smoothing pass";
   `Handoff_2026_11_20_walked_hovels_and_yard_pieces.md`): **a turned hovel is walked where it is
   drawn** (its walls as drawn slow the feet, they do not shut: shut, on hillsides they made pits;
   `--no-hovel-walk`; blob 40), so it has no hidden square either; **a stockyard's coverings' roofs
   are smoothed** by its builder, a row at a time, and drawn as one plane with a rounded edge
   (`--no-smooth-covers`); and **a turned stockyard's rails and gateway planks are drawn straight
   along the path**, its posts as laid (`--no-fence-pieces`; blob 41). The pieces' blocks stay where
   they are laid, left out of what the land draws. His calls of it are in the handoff. **His answers
   (owed, not built):** hovel walls solid; the fence's posts turned too; a roof's rounded edges one piece
   along each edge, and every thatch roof textured alike ("that is the defult for all thatch roofs");
   and his question whether building at an angle causes a lot of issues ("they either act like the
   straight builds or we need to change the way we tackle this situation so it works"), answered in the
   handoff with two ways put to him: one shared way for every system to read a turned building, or the
   case-by-case way as now. **His answer, 2026-11-20: the first way, by the zone** ("Zones put down
   whole, on grids of their own", below): of these the roof is built, the walls and the posts wait for
   the zone's own grid.

## Zones put down whole, on grids of their own (his design of 2026-11-20; the placements and the square built; the grid sized, not built)

His words, whole, are in `docs/handoffs/Handoff_2026_11_20_placements_with_paths_and_the_square.md`
(with how each clause was read, his answers to the four calls, and what was built). In short: "let's
lock the size of the stockpile, if the player places it, it will be a square box, lets fix the path
artifcats by including the path in front of the stockpile, the player can rotate the placement ... they
can either align it with an existing path, rotate and snap it to the end of or if they orientate it at
an angle to the middle of a path it will snap at that angle to the path. Along with a warning for
overlap. This should make things easy for us and the player; and allow us to make the angled zones their
own grid. We can do this with all zones including the stockpile. Let's merge the homestake and the
campfire ... a 10x10 area, terriform so the entire area is flat, and build a path around the perimeter
... Habitation zones can remain flexible the way they are. We can polish how the lots are built after we
get through all of what we have on our plate"; and of housing: "it will include the path with the zone
placement, it will allow either an overlap, extension, or intersection with an existing path."

**It answers "Buildings at 45 degrees" above**: of the two ways put to him, the first (what is built at
an angle kept in a grid of its own, every system reading it by one routine), with **the placed zone**
as the thing that has the grid. So "hovel walls solid" and "turn the fence posts" are not built the
present way.

His rulings, with it: an angled zone's ground is "the .25m blocks around it that will fit the zone",
made level, "as much of a 1m section as the[y] can" (its edge on the ground steps by the block: no
fault); the path artifacts he meant are a zone that "collides with the path and part spills/wraps over
the end, or disrupts the box"; the square's path lies "around the outside of the 10x10m so it will be
12x12m"; "for the overlap, the click is refused for special zones like the stockyard/storehouse zone.
The habitation can continue to overlap and join as is"; "Sizes stand, but you may modify at your
discresion"; "Housing on one side, if they want both sides they can lay down the zones twice. OR we can
allow the player to select a double or single row?" (answered yes: the key that turns a box is to step
a housing pull through one side, the other and both).

**Passes**, each a commit a rule with its switch:

1. **Built 2026-11-20**: the covering's roof (his item 3); the stockpile put down whole with its path
   (`Castle.Colony.Box_At`, `Plan_Box`, `Place_Box`; `Set_Box_Place`, `--no-box-place`; blob 42); the
   homestake and the campfire one (`Place_Square`; `Castle.Actions.Square_Stake`, `--no-square`; blob
   43). Every placed zone keeps its frame (where its front begins, the way, how long): the grid's.
2. **Built 2026-11-20: housing pulled with its path** (`Castle.Colony.Pull_Line`, `Plan_Housing_Pull`,
   `Pull_Housing`; `Castle.Actions.Housing_Pull`, `--no-housing-pull`; no blob change). Along a path
   that is there nothing is laid and the strip is the old gesture's own; past an end the path goes on;
   anywhere else it is a line of its own, up to a path or across it; Z and X step the rows (this side,
   the other, both); housing with no hovel's lot on it gives way under its path. The path tool stays,
   and still goes round zones (his call 10 in the handoff).
3. **Built 2026-11-21: the stockyard put down as a box**, 20 m square by his word of that day ("For
   the stockyard, lets expand the zones to 20x20"; 16 m was this brief's), its path along its front,
   drawn to paths as a stockpile's box is, refused over anything (`Place_Box` with `Stockyard_Box`;
   `Set_Yard_Box`, `--no-yard-box`; no blob change). Its storehouse is laid out by the frame it is
   given (it fronts its own path), and tried on the planned ground before anything is laid. 845 of
   1,292 sides of the ten places' squares take one, where 985 take the least stockyard of before.
   `Handoff_2026_11_21_square_thirteen_and_stockyard_twenty.md`.
   **And the storehouse 12 m by 8 m, 1.5 m from its path** (his "so that it is now 8x12", the same
   day; `Set_Store_Size`, `--storehouse 10 5 4.5` is the old; blob 44): 3.5 m off a path at 45
   degrees, where its own blocks all lie on its ground; the lord's cart's place before it looked
   for (`Set_Cart_Search`). 828 of the 1,292 sides take a stockyard with it.
   **And food and full barrels stacked in it** (his "Allow food and full barrels to be stacked in
   the storehouse"; `Set_Store_Stacks`, `--no-store-stacks`): baskets three high on its floor, a
   second barrel made on a full one.
   **A square's stair in a corner of the zone: built on a misreading, off behind its switch**
   (`Set_Square_Stair_Corner`, `--square-stair-corner`; gate 82 had it on). His words of the
   afternoon of 2026-11-21 ("The path level at one corner is great, move the stair to the opposite
   corner instead of the center, if a stair is to be had it's to be at the corner of the zone") were
   read of the square; in the evening: "No let's go back to square stair middle, I was talking about
   the stockyard having the stair in the corner rather than the middle". A square's stair stands at
   the middle of its side, as before.
   **The stockyard's stair in a corner of the zone** (the same words, of the stockyard; built
   2026-11-21, evening; `Set_Yard_Stair_Corner`, `--yard-stair-middle` is as it was): a stockyard
   whose way in across the staging would have steps has it at an end of its front instead, a block
   a step from the path's edge, at the end away from a level one, else at the lower bank; 114
   stairs at the ten places where 115 stood at the middles, no pit, less stone. The floor's level
   is still chosen by the middle of the front. **Its three calls were answered on 2026-11-22**
   (the next paragraph): over 2 m no stair; the floor at the path's level at the lower corner; the
   stair at the higher.
   **The stockyard's floor at its path's level at the lower corner of its front** (his "Set the
   floors level of the stockyard to the path level at the lower corner, the higher corner along
   the path gets the stairs", "After 2m no stair built"; built 2026-11-22; `Set_Yard_Floor_Low`,
   `--yard-floor-by-land` is the paragraph above alone): 839 of the 1,292 sides take a stockyard
   (828), 195 have a stair (114), with half as much stone again; every one has the path level at
   one corner of its front. **Open, his calls**: (1) the lord's cart has no place before the
   storehouse where the staging's rim is a wall (squarely, where the front rises: 50 stockyards of
   the ten places for 30 before): leave it in the stockpile (built), stand it by the level corner
   beside the storehouse's end, or let its bed stand against a wall; (2) the cost itself, if it is
   more than he meant: 81 more stairs and half as much stone again, for a floor that meets its
   path at one corner everywhere.
   **The jumps in the square's path** (his "we need to do something about having the .5m jumps in
   the path around the square too", 2026-11-21, late evening): counted (272 steps of two or three
   blocks on 192 sides of 71 of 323 squares, 258 of them where a levelled stretch of the path
   ends); a mend tried in a scratch tree (a block a quarter metre there: 27 left made on the spot,
   8 for 74 by the band at 23 squares), **not built**: what is laid depends a little on who lays
   which metre first, as the path does today, and it has no check or gate. Making the steps again
   when a neighbouring metre is laid was tried too (21 left on the spot, 26 laid backward, 7 by
   the band): it does not take the order out, and it re-lays level ground where two stretches
   cross. Which stretch a square metre goes by where two cross is to be settled first. **Answered
   2026-11-22: "Steps of stone"**, and "The only thing left to fix on the square is the path
   jumps".
   **The square's path stepped with stone** (built 2026-11-22; `Set_Path_Steps`, `--no-path-steps`):
   from the end of a levelled stretch the path goes a block a quarter metre, each step a tread of
   stone laid by the wall builders, planned with the walls from the path as it is laid. 272 jumps
   at the ten places become 50; no stair is moved, lost or made; the order of laying changes what
   it changed before and no more. **Open, his call**: the 37 left at the corners (25 where a
   levelled stretch runs up to the square metre in which two sides' paths cross, 12 by a side's
   end between two quarter metres neither of which is level).
   Two ways of stepping them were tried in a scratch tree; each follows the corner's own state,
   which goes by which side's metre was laid first, and makes more of that (47 and 62 quarter
   metres differ forward against backward, for 41). The default: first the corner's square metre
   is made one thing (brought level whole or not at all, by its own columns, whichever side lays
   it), then the steps run into it. The 7 that are the land's own along a side that is not
   levelled, the 4 at boulders on the path and the 2 beside stairs would stay.
   **Answered 2026-11-22, later: "stick with whatever you think is best"**: the default is built
   (`Set_Corner_Whole`, `Set_Corner_Steps`; each has its switch). The corner's square metre is
   laid as one, level whole or left whole, and is a landing of the flights, which go on round the
   corner. **16 jumps are left of the 272** (2 before a stair, 5 at a boulder, 2 by a side's end,
   7 the land's own); laid last metre first no square stands otherwise. With it, by his "Mend the
   issues you found": a strip's column waits for the path it is planned against
   (`Set_Strip_Wait`), and a planned line's end under a tree has the ground's height
   (`Set_Line_Ground`). **The lord's cart is left as it is by his word** ("leave the cart doing
   whatever it's doing right now, we are going to work on the logistics soon"): where it stands
   before a storehouse whose staging is walled, its towing, and the three hillside squares where
   no place takes it at all (a mend for that last is a patch outside the repository).
4. **The zone's own grid** (below).
5. **The lots' polish**, by his word after all of that: the stair to a turned door, the builder's jump,
   the hovels' walls. With it, by his answers of 2026-11-20: **a hovel's terrace walls stepped back as
   the square's are** ("step the stone walls towards the higher ground if over 1m. so from lower
   ground for each 1m of retaining wall step inwards .25"; of the hovels': "yeah we can do that when
   the lots are polished"), and **a tree that is in a lot's way felled** ("a tree ... can stay in
   habitation zone, if it doesn't interfere with anything": clearing a lot, not built today).

### The zone's own grid, sized (not built)

**What there is to replace.** Everything that knows a turned building is a special case of it. By a
grep for the routines that exist only for turned things (`Back_Turn`, `Fore_Turn`, `Under_Drawn`,
`Design_Of`, `D_U`, `Y_Point`, `Yard_Turned`, `Walk_Drawn`, `Keep_Off_Turned`, `Set_Drawn`,
`Turn_About`, `Put_In_House`, `Turned_In`, `Yard_Pieces`, `Seen_Mat`, `Set_Turns`, the shader's
`u_turn_*`, the cutaway's `Turn_C` ...): **339 lines in 25 source files**, and nine switches. By
system: the colony (the site's columns given the turned ground by hand in `Lot_Take`, `Check_Lot`,
`Choose_Pad`, `Work_In`; the yard designed in one frame and built in another; the walking map told the
walls as drawn; who is drawn through the turn); the buildings (the turn's geometry, the yard's
blueprint as lines of columns each beside the one before); the walking map (drawn walls and doorways
as pieces, the one box not read from the blocks, a slowed wall's pace in two places); pointing (the ray
taken back through each turn, the hidden ground kept off the cursor); drawing (the turn in the land's
vertex shader by a box asked of every vertex, the floor's texel rule, the cleared roof through the
turn, the far tiles' turn, pieces drawn as props over blocks left out of the land); people and props
inside drawn through the turn.

**The thing.** A zone that lies squarely needs nothing: its grid is the map's. A zone that lies aslant
keeps what is built on it in **a store of blocks of its own**, as wide and deep as its box and as high
as what stands on it, with the zone's frame (kept since blob 42). Its ground stays the map's (his
rule: the blocks that fit, made level). One routine takes a place of the world to a place of a zone's
grid and back; one question, "what block is here?", is answered by the map and then by any zone whose
box holds the place. Each reader below asks that and nothing of its own.

| Reader | Today, turned | With the grid | Measure |
|---|---|---|---|
| Storage and saves | the blocks are the map's, on a square that is not where they are drawn | the grid's blocks; a building's are its blueprint laid in order, so they are remade from what is saved now; what a player digs or places in a grid is kept as that grid's edits | saved, loaded, saved: the same bytes; kilobytes a grid |
| Building | the blueprint laid on the map square to it and drawn turned; a yard's fence and coverings stepped along the diagonal | the blueprint laid in the grid, square to the grid: posts, rails, coverings and the storehouse all straight (his "turn the fence posts"); a dressed roof works as on a straight build | the stockyard sites; a square stockyard's blocks the same count |
| Drawing | turned in the land's vertex shader, by a box asked of every vertex; pieces as props | the grid meshed by the land's mesher (a grid is a stack or a few) and drawn by the land's shader through the zone's turn, by the draw; casting into the sun's and the fire's maps | a straight house to the pixel; `tools/look_cost.sh` |
| The cleared roof and walls | the eye and the pointer taken back through the turn | asked in the grid's own places | the stills of step four |
| The far view | the far tiles' cells turned | a grid drawn as it is as far as the props are, reduced beyond | holes counted; the far stills |
| Walking | the walls and doorways as drawn told by hand; a hovel's walls slow, they do not shut | the walking map's cells under a grid's box ask the grid: a cell a wall's block touches as it lies is no floor, a doorway's cells are held open (his "hovel walls solid": the pockets on hillsides are the ground's, shut where the ground is made) | `path_check`'s walked building; `tools/turned_streets.sh`; pits 0 on `colony_check`'s hillsides |
| Pointing and digging | the block behind what is drawn | a ray walked through each grid it crosses, in the grid's places; a block of a grid pointed at, dug and placed as the map's is (his ruling: "pointing at a rail picks the rail and digging it removes it") | `pick_check`, a rail and a roof |
| People and things inside | drawn through the turn, the builder eased | where they are: nothing is drawn through a turn | the recording of the builder |

**Order.** (a) A scratch proof first, shown to him: one grid, a stockyard's fence laid in it, drawn at
45 degrees beside the present one. (b) Storage, the mesh and the draw, behind a switch, with the
stockyard's fence alone moved to it. (c) Walking and pointing through it. (d) The stockyard built into
it whole (coverings, storehouse), the yard's special cases taken out. (e) The hovels, with the lots'
polish. The square's hearth and seats are props and need no grid.

**What it costs, to be measured as it goes**: a grid of a stockyard (16 m by 16 m, 6 m high) is 98,000
blocks, two bytes each before packing; its mesh a few thousand quads; a draw a grid. **What is not
answered yet**: on a hillside the cut round an angled zone is the map's and steps by the block (his
rule for the ground); whether its retaining wall is the map's stone, stepped, or the grid's, straight,
is a call for when (d) is reached.

## Workers 250 m for resources (his word of 2026-11-19; built for foresters, gatherers and porters; the hunters his to say)

"Let workers go 250m for resources, wood is a vital resource." Built: foresters; then gatherers and
porters (a ring further when they find nothing in reach: `Food_Reach_M`, `Haul_Reach_M`; bushes looked
for as far as the gatherers look); then, 2026-11-20 (`Handoff_2026_11_20_ways_told.md`), **what one
finds there is no way to, the others are told** (`Set_Ways_Told`, `--no-ways-told`): the way asked of
the walking map's pieces first, a place with none nobody's to try for a day, so that one whose nearest
is across water looks past it (at the open site by a river the gatherers said "can't get there" for
722 serf-hours of twenty days; 18 now). **The hunters are not a matter of reach**: the deer live within
70 m of the stake by the herds' own rule and a herd down to three is left to breed; at that site the
hunters waited 621 serf-hours of twenty days. More deer further off is a change to the herds: put to
him. Also put to him: the gatherers' reach ran out to 250 m there and they are hungry nearly four
times as long (one starving for a while on the way home).

## Trees growing back (his word of 2026-11-19: "Trees do not grow back yet, but they will, we can do that later")

Unbuilt, and not to be built before he opens it. A felled tree is `Tree_Rec.Down` for good today.

## Razing, later (his answer of 2026-11-19, for the stage that brings farms)

"limit razing buildings to unowned, this happens when a serf passes to a new job and they house
somewhere else, for example when the farm is built." Built now: only a hovel nobody owns is razed. **Not
built, and for that stage**: a serf whose new job houses it elsewhere leaves its hovel, which is then
nobody's and can be razed (or drawn by another).

## State and saves

- Colony blob 19: the houses (zone, seed, place, the way it faces, pad, its door's way, how far
  built, what was delivered and what of it is not yet laid, whose it is), each builder's house and
  patch of its ground. (18 was its first layout and the hovel of plank, on this branch only: refused.) A new `Zone_Kind`, two `Task_State`s, a `Camp_Use` and two `Why_Idle`s, each on the end.
  A house is saved as its seed and a count of blocks laid: a change to `Castle.Buildings.Design` or
  to the blueprint's order moves the blob's version.
- By John's rule of 2026-11-11 no blob of version 17 or 18 is kept and no check is written for one.
- `Generator_Version` 13 and save format 6 do not move. Two new blocks, `Thatch` and `Daub`, on the
  end of the materials (nothing the generator makes).

## Packages

Touched: Castle.Blocks (Thatch, Daub), Castle.Buildings (the design and the blueprint made a pure function of
a seed; the preview's layout kept apart), Castle.Colony (houses, lots, the builder, residency),
Castle.Actions, Castle.Views, Castle.Pick, Castle.HUD, Castle.Zone_Marks, Castle.Scenario, the game.

## Leaves room for

| Later system | The hook |
|---|---|
| Stockpile improvements (6b) | A site is a blueprint on a zone with a builder and what it takes; a covering or a storehouse is another blueprint and another row |
| Earned trades (8) | `Trade_Kind` and where each comes from (`Trade_From`); the builder is its first value |
| Housing that improves (12) | `Castle.Buildings.Design (seed, level)`: the level is a parameter nothing sets yet |
| Anchors for routes (the pathing note) | A house has a door on a path: `House_View.Door` |
| A hearth indoors | `Castle.Fire.Show` and `Add_Light` at a house's hearth place |

## Tunables

`Lot_M` 7; `Planks_Per_Log` 96; `Thatch_Per_Sheaf` 64; `Lay_Blocks` 16 and `Lay_S` 5; `Build_Reach_M`
2.5; where a builder stands and sleeps (`Stand_Off_B`, `Stand_In_B`, `Bed_In_B`, `Home_M`); the hovel's
sizes in `castle-buildings.ads` (`Min_Floor_B` 400, width 21 to 26 blocks, depth 24 at most, walls 9 or
10, a window 2 blocks square 5 up, a stud about every 4, setback 2 to 4, `Max_Push_B` 12, `Max_Step_B`
8, `Apron_B` 4 and `Apron_Front_B` 2, `Door_Landing_B` 3, `Lot_B` 28).

## Check

colony_check, 53 new (422 to 475), and pick_check, 6 new: a housing zone refused off a path and where no hovel fits, taken beside one; a hovel
begun for each without a home, nearest the stake first, lots apart, each wholly on the zone's ground;
its blueprint's blocks counted against what it asks; the zone's rows in the demand table falling as
logs are delivered; a forester turning builder and back with the wood; the fire's logs left alone;
never a porter or a gatherer at a site; every log and sheaf stored, carried, burnt or built in; the
hovel standing block for block as its blueprint; its owner asleep inside it and not cold in winter; a
save taken mid-build, byte for byte and carrying on exactly; no builder and no porter each saying so.
a builder given other work and another forester taking its house up; housing 78 m from the stake and
the colony's ground reaching it; four hundred blueprints held to their order (all the timber before
anything of straw, no block twice); hovels either side of a path aslant across a made-up hillside, a way
to every bed and every owner asleep in its own; trees felled whose shapes reach through a house; a
vegetable not growing back under an eave; night coming on a builder with a log in its arms. `tools/reference_check.sh`: the seven logs unchanged (nothing of this
runs without a housing zone), and an eighth with housing (`reference_run_stage6.txt`).

## Demo

A housing zone marked beside the reference path; the lot outlined; the pad levelled, the floor beaten,
the frame, the daub and the thatch going up; the owners coming out of their doors at dawn.
`tools/demo_stage6.sh`.

## What was measured (seed 1, the reference site; docs/handoffs/Handoff_2026_11_12_stage_6a_habitation.md)

The stage 6 run (the reference band with a porter in the second hunter's place, a path west over the
level ground and housing on both sides of it): the six hovels stand by the midnights of days 25, 28,
31, 35, 39 and 43, all from one forester. The store runs out on day 55 and two of the six die on day
56; the same band without housing loses one, the reference band none. That band's winter has been run
on four builds of this stage and ended with none, five, five and four of six living: the first winter
turns on a deer or two at either end of it, and is not tuned.
