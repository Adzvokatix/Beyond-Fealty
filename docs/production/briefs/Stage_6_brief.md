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
