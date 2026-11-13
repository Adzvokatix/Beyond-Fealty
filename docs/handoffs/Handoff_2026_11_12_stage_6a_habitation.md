# Castle Game handoff (2026-11-12: stage 6a, habitation: a housing zone along a path, a hovel begun for everyone without a home, builders from the foresters raising them from logs and straw, the owner asleep under its own roof; the hovel remade the same day from John's references, a timber frame filled with wattle and daub; built on branch `stage-6` and put to John; not yet accepted; stage 6b, stockpile mechanics, asked of him; Claude Code)

- **Closed: accepted as built, 2026-11-12, and merged into `main`.** John, after trying it: "ok the
  building looks great, I am impressed, works wonderfully on my end as is", and in the same message a
  pass of changes to building and zoning (retaining walls and stone stairs where the ground rises and
  falls, roofs smoothed by their builders, housing zones pulled along a path and combined where they
  overlap: "John's words", the fourth, has it whole; the pass has a handoff of its own). He took up
  none of 6a's calls, so each stands by default, as built: first values, his to tune; don't treat one
  as settled against him, and don't change one unasked. What follows is as it was written when 6a was
  put to him.
- Branch `stage-6` (from `main` at a4859bb), now `main`.
  Stage 6 is in two parts, as stage 5 was in three: **6a, habitation, is this handoff; 6b, stockpile
  mechanics, is not designed and not built** ("6b", below, is what was asked of him). He has since
  said what comes before it: "then we will have an intermediate sleeping, beds, campfire to house
  transition. After that we will get to the stockpile, and how the player manages this." Both are his
  to open.
- **Two rounds, one day.** The first was closed at 77b6f83 and its zip made. The second (08066af,
  9f7e6b7, 546f22c) is a door that can always be got to, found wanting on a hillside; the hovel remade
  from the references John added while that was being mended ("John's words", the third); and a
  builder that stood awake all night with a load in its arms, found by counting who was at home. This
  file is brought up to the second: where a figure of the first is kept, it says so.
- **Phase B's gate is not called.** It is his to say, with the decisions due at this stage's close
  ("Decisions due", below).
- Code: GAME_alpha_1_3/compiled, branch `stage-6`: 1a612cd (the brief), 2fdd190 (a thatch block; the
  hovel a function of its seed), 848180a (work in progress kept when a session was cut off: **it does
  not build**; don't bisect onto it), df5ad8a (housing), 8b34336 (hillsides, quicker first values, the
  check), 5f1bde7 (the stage 6 reference log, the memos' switch), 2f802aa (the ground reaches housing;
  the system documents), 80d7abc (the demo's script, the plan), 77b6f83 (this handoff as first
  written), **08066af (the door's way; the hovel of timber, daub and thatch; colony blob 19), 9f7e6b7
  (the threshold under the door beaten with the floor), 546f22c (a builder delivers the load in its
  arms before it leaves off for the night)**, the stage 6 log recorded again in each of the three;
  documents after.
  - Zip: CASTLE_GAME/releases/castle_game_stage6a.zip, remade (a `git archive` of the branch's closing
    commit: documents only after 546f22c). Demo: colony_stage6a_habitation.mp4, recorded again
    (tools/demo_stage6.sh), 65 s.
- Checks, from a clean copy (`git archive`) of 546f22c, built from nothing: debug and release with the
  six known warnings and no other; all nine checks pass in debug (colony_check 422 -> 475, pick_check
  32 -> 38, the rest as they were); `tools/reference_check.sh` holds the seven logs line for line and
  the eighth, with housing, as recorded in 546f22c; `tools/stress.sh runner` passes (the housing run
  kept, with nothing kept to save work, and on two workers: one state). On the working copy:
  `tools/shadow_still.sh` reads 0.00 % by day and at dusk, and with houses in the view only the deer
  step; the debug build's runner gives the release's state after the 41 days.
- Versions: `Generator_Version` 13 and save format 6 as they were. **Colony blob 17 -> 19** (the
  houses, the house each builder is at; 18 was the first round's layout and the hovel of plank, on this
  branch only, and is refused). Two new blocks, `Thatch` and `Daub`, on the end of the materials.
- Driven only by script: the Housing tool (the ground's menu, the lot's preview, the click), the
  house's and the zone's tooltips. The real mouse was not exercised.
- **Test windows of mine on his desktop in the second round**: a dozen stills (the hamlet, three
  hovels going up, a doorway before and after its threshold, the hillside); the hamlet at the default
  view for 2,500 frames a time (the look's cost, with and without its houses, clear and rain, more
  than once); `tools/shadow_still.sh` eight times and one still for its map; the demo's five parts,
  recorded twice over (the second part at 120 times speed). None is how the game plays.

## John's words

2026-11-11, opening the session: "Hello, Claude, we have completed our preperations on the engine and
gotten things in a state to continue with stage 6. Review the directories and docs, do what you need
to do, you're in control, go cook, you've been cruising on this and doing a great job so far!"

How it was read: the stage is open. Nothing of it was designed (the plan had one line and "his to
open"), so, as stages 5b and 5c were, it was drawn from the design documents with first rules and
values of mine, built on a branch, and is put to him here.

2026-11-12, when the work was stopped part way and three calls of the brief were put to him (one hovel
a person, children too; a roof alone keeping the winter cold off; a pad's earth thrown aside, not
stored): "continue, one hovel per person for now, dirt discarded is fine for now".

How it was read: two calls answered, both "for now". The third (the roof and the cold) was in the same
message and was not taken up: it stands by default, as built, his to change.

2026-11-12, later, while a door on a hillside was being mended: "I have added some design refrences in
the "/Design Refrences" folder," and, pasted with it:

> A 12th-century peasant house was a small, simple, single-room shelter built by hand using local,
> natural materials for survival rather than comfort.
>
> Exterior & Structure
>
> - Walls: Built using a timber frame filled with wattle and daub (woven twigs coated in a mixture of
>   mud, clay, and straw). Around this time, builders began shifting from posts dug directly into the
>   dirt to placing timber frames on low stone footings or flat stones to keep the wood from rotting
>   in the wet ground.
> - Roofs: Steeply pitched and thatched with straw, reeds, or heather to shed rain and provide basic
>   insulation.
> - Windows & Doors: Windows were tiny or nonexistent to preserve heat, lacked glass, and were covered
>   with tight wooden shutters or animal skins.
>
> Interior Layout & Living Conditions
>
> - Single Room: Most peasant homes consisted of just one main room that served as the kitchen, living
>   area, workshop, and sleeping quarters for the entire family.
> - The Hearth: An open central fire pit provided heat and light, with no chimney—smoke escaped
>   through gaps in the thatched roof or doors.
> - Flooring: Beaten earth packed hard, usually covered with loose straw or rushes that were
>   periodically layered over as they got dirty.
> - Furniture: Sparse and functional. Furniture was limited to low benches, crude stools, a knockdown
>   trestle table, and heavy wooden chests used to lock away valuable tools or food.
> - Sleeping: Family members slept on straw mattresses or loose straw piled on the floor or low wooden
>   platforms, often clustering near the dying embers of the fire for warmth in winter.

The folder is `~/CASTLE_GAME/Design Refrences/` (outside git, beside `releases/` and `papers/`): fifteen
pictures, all looked at. Of the peasant's house itself: a thatched reconstruction with low stone walls
(Cosmeston); a thatched house walled in upright planks (of the West Stow kind); three small drawings
of a house going up (a frame, the frame braced, daub and thatch); a painting of Wharram Percy, its
long thatched houses each in its croft; a cutaway of a village of about 1200 under its castle (thatch,
frame and daub, a church, a market by the water); a walled village among its fields from the air. Of
what a village grows into: half-timbered houses on stone ground floors with jettied upper storeys and
tiled roofs along cobbled streets (four of them, one with a merchant's cart), a cutaway of such a house
(a workshop below, a store above), a church in a stone town, a watermill, a hill town above its
fields, and a model village from above: thatched half-timbered houses set at every angle along winding
earth paths round a church.

How it was read: he asked for nothing by name. I took it as what the buildings are to be made like, and
the hovel was the one building there is, still open on my desk. So the cheap part was built at once
(the frame and its daub, the floor, the windows: "The hovel", below) and the rest is put to him as
calls, not built (the hearth first). **If he meant them only as something to have by**, going back to
the hovel of plank is a small change, not a checkout: `Blueprint`'s walls and floor and one line of
`Kind_Of_Block`, with the colony blob moved again and the stage 6 log recorded again (the commit
before the remake, 77b6f83, is the first round's build and has both of its faults). Nothing but the
look and what a hovel takes turns on it.

Two things the pictures show that the hovel does not do, beyond the text: **nearly every roof in them
is steeper than one to one**, and **in the model village no house is square to its neighbours**. Both
are in "His calls".

2026-11-12, after trying the second round's build: "ok the building looks great, I am impressed, works wonderfully on my end as is, now some changes to building and zoning, first changing elevlations, if the zone is going higer and lower in elevation, the .25m next to the path will be reserved for a retaining wall built from stone in the stockpile, stairs built on the path from stone as it rises or falls to the door, dirt around the back of a blueprint  is dug away and a retaining wall is built, if multiple buildings are along that same axis then the retaining wall is extended as one, same with houses that step down, retaining walls built between them if they share a wall a retaining wall is built along the shared wall if its over .25m. Next the roofs, are to be smoothed, but not rendered smooth instantly, the builders smooth the roofs so they don't step, rounded edges around the peremeter. For zoning, we need to be able to expand the zone by overlap, I couldn't get the zone to snap to the road or other zone when trying to expand a zone, and when i place a diagonal zone next to a straight zone i couldn't expand because of overlap and minimum size rule, so I suggest this fix, instead of locking the player out for a size discrepency, make the area fixed distance from the path that will fit a hovel, and then they can pull it along the path to the desired length, and if they intersect with another habitation zone let them overlap and just combine the entire zone, to fix the player from being able to pull the zone as far as they want, don't let them go farther than 7 blocks from the end or turn of a path. That we can do for this pass, then we will have an intermediate sleeping, beds, campfire to house transition. After that we will get to the stockpile, and how the player manages this."

How it was read: 6a is accepted as built ("works wonderfully on my end as is"); he did not say which
zip he had tried, and the second round's was the one in `releases/` when he wrote. None of 6a's calls
is answered: they stand by default. The rest of the message is the next pass (walls, roofs, zoning),
built on a branch of its own from `main` and put to him in its own handoff; and the order of what
follows it, which moves the stockpile behind "an intermediate sleeping, beds, campfire to house
transition". Neither of those two is designed here.

## What John sees on first launch

1. **A new tool: Housing** (the Tools panel, under Path and Stockpile; "Housing from here" in the
   ground's menu). Two corners beside a path, as for a stockpile; the lot shows as it would be taken;
   the note says "housing zoned: room for 3 hovels". Away from a path, or where not one hovel would
   fit, it is refused and says why. The zone is a pale blue.
2. **Nothing else is asked of him.** Within a second a hovel is begun for the first of the band: a
   white outline where its walls will stand, a mark at its door, at the end of the zone nearest the
   stake. Its tooltip: "Walter's hovel: a hovel, being built; for Walter; the ground; builder Alys;
   wood 0 of 3 logs; straw 0 of 28 sheaves".
3. **A forester turns builder on its own.** With no forester the hovel waits and says so ("Builder:
   none: builders come from the foresters"). With one, it treads the lot (the grass cut, the ground
   under the walls made level, a bank left round it on a slope), beats the floor, then carries logs
   from the stockpile and raises the frame post by post, the beam along the top; then, with straw,
   daubs the walls a course at a time round the house, the gables, and thatches. With no wood in store
   it goes off felling and comes back.
4. **Daub and thatch need a porter.** With nobody cutting straw a house stops at its bare frame: the
   tooltip says "Waits for: straw in the stores" and the Stores tab "asked of nobody". **The reference
   band has no porter, so marked as it stands it gets frames and nothing more** (in the first round it
   got walls and no roof). Give someone the porter's job.
5. **Three and a half to four game days a hovel from one forester** (3 or 4 logs, 26 to 31 sheaves;
   the hovel of plank took five to six days, 14 to 16 logs and 17 to 19 sheaves). With three foresters
   three go up at once.
6. **It looks like the houses in his pictures, as far as blocks of a quarter metre go**: dark posts
   about a metre apart, pale daub between them and in the gables, a small window high in the wall by
   the door, straw-coloured thatch, a floor of trodden earth.
7. **When it stands its owner sleeps in it.** From above he is under the roof and is not seen. The
   rest still sleep round the fire.
8. **Houses stand square to the grid, close together** (half a metre to under two metres apart), each
   with a footpath from its door to the path. On a slope each is cut into the hill at its own level,
   and where its floor is above or below the path its door has a level landing and then steps.
9. **A lot with a bush, a tree or a boulder on it is passed over**: a zone that looks long enough may
   say "room for 2". Nothing clears a lot yet. A tree beside a lot is left standing and what hangs
   over the house is lopped.
10. The band's sheet lines: a person's "Home", a builder's "Trade: Builder, at Cedric's hovel".
11. A save from `main` still loads (no houses in it). **A save made with the first round's build
    (colony blob 18) is refused**; one from this build does not load in an older one.

## His calls (what I decided that he may want otherwise)

Answered:
1. **A hovel each, children too.** "one hovel per person for now".
2. **A pad's earth is thrown aside on the lot**, not carried to the stockpile (a hovel's worth would
   fill six of a stockpile's places). "dirt discarded is fine for now".

Put to him and not taken up (stands by default):
3. **A roof alone keeps the winter cold off** a sleeper, fire or no fire. It is the only thing a home
   does yet.

New in the second round, from his references (not yet put to him):
- **How far I took them.** Built: the frame and its daub, the floor of beaten earth, the small high
  window, one room, thatch. Not built, each his to ask for: **the open hearth** in the middle of the
  room and sleeping by its embers (the first fire indoors; it meets the call above, 3, and the open
  decision of which lights cast); **low stone footings** (the stone in store would have its first
  use in a house); straw or rushes on the floor; furniture; shutters and a door that shuts; **a roof
  steeper than one to one** with deeper eaves (his text says steep and nearly every picture is; it
  is a change to the blueprint, a fifth or more thatch to a hovel, and the door's landing looked at
  again under a deeper eave); no window at all in some; diagonal braces in the frame; houses set at
  an angle to the grid (the walking map and the lots are on the grid: not cheap); the longhouse and
  the croft; and, for later, the stone ground floor, the jettied storey and the tiled roof.
- **Daub is straw.** A sheaf daubs 64 blocks as it thatches 64; the earth is the lot's own and the
  wattle is what was cut there, neither carried nor counted. So housing now leans on whoever cuts
  straw and hardly on the axe: 3 or 4 logs a hovel. If the wattle should be wood, or the daub's earth
  come from the stockpile (the camp's dug earth would then have a use), it is one line
  (`Kind_Of_Block`) and a count.
- **A beaten floor takes nothing** but the work (three to four game hours of it, read off an hourly
  log of the stage 6 run).
- **A door's way.** Level with the floor for three blocks, then single steps; a pad that would lie too
  high is cut lower (more is dug, and thrown aside); a house whose floor would lie too far below
  stands further back, 3 m at most.

Not yet put to him (the first round's):
4. **Who builds.** Every forester with a house to build is a builder; one builder to a house, the best
   at building first; as many houses begun at once as there are foresters (one, with none). Nobody is
   appointed and no skill is asked. Building is the builder's own work, not an extra task.
5. **Reversion.** A builder fells when no wood can be taken for building and builds when some can.
   Nothing else reverts.
6. **The fire first.** Building never takes the logs the fire burns in a day, nor those the camp's
   seats and hearth still want. It does take the wood surplus he orders kept (the reserve asks
   producers; it holds nothing back).
7. **Whose house first**: the band's order (the builder built its own third in the reference run).
8. **Where**: the frontage nearest the stake; a lot 7 m along the path; half a metre to a metre off the
   path's edge; square to the grid, stepping back up to 3 m on a slanting path; a fall of up to 2 m
   across a lot cut and filled; refused on a bush, a tree, a boulder or water.
9. **What it takes and how long**: a log 96 blocks, a sheaf 64, sixteen blocks a bout of 5 s. They were
   64, 48 and 6 s at first: I quickened them in the first round so that a band of six is housed within
   the 41-day run, and have not slowed them again now that a hovel takes less (the six are housed by
   day 43). The dials are at the top of `castle-colony.ads`, "housing".
10. **Straw is the porter's**: the builder carries it from the stockpile but never cuts it.
11. **The hovel's size and place**: the generation spec's, with the prototype's variation (width,
    depth, wall height, where the door is, a second small window half the time). No shared walls.
12. **Houses keep their ground loaded** as far as the engine can (256 m from the stake; a zone past
    that is refused).
13. **No un-zoning, no pulling down**, as for every zone.

## 6b: stockpile mechanics, asked of John

His words on it: "they will eventually start upgrading the stockpile, build a storehouse, warehouse,
fences and outdoor storage will get coverings" (2026-11-10) and that it overlaps with habitation
(2026-11-11). 6a leaves what the two share: a thing built on a zone from a blueprint, by a builder,
from materials the zone asks the stores for. What I do not have, and have not invented:
1. Which improvements, in what order: a covering, a fence, a storehouse, a warehouse.
2. What starts each (pillar 5: conditions, not a click).
3. What each does. Spoilage and theft are stage 11, so today a covering or a fence would only be seen.
4. Whether it is also something of how goods are kept (kinds to a stockpile, a stockpile's own demand).

## Decisions due at this stage's close (the framework's list)

- Whether 6a's rules stand (above, and the brief's 21).
- 6b's design (above).
- Whether the player's character comes at stage 7; whether phases C to H and stages 7 to 12 stand as
  proposed; the population target for phase C (`Max_Members` 48, a house each at most).
- Phase B's gate: "a band assigned once feeds and houses itself, and the first winter runs its full
  course on standing orders alone". What the stage 6 run shows of it is under "Measured".

## Rules as built (first values, his to tune)

The brief has the 21 as they were proposed and as they now stand. In short: housing is a zone and the
player marks only that; everyone without a home asks for a hovel, begun for a person, as many at once
as there are foresters; the lot nearest the stake, its door always to be got to; the hovel a pure
function of its seed and its place, a timber frame filled with wattle and daub; builders from the
foresters, reverting to felling for want of wood; the fire's logs first; what a hovel takes counted
from its blueprint and asked of the stores by its zone; the ground, the floor beaten, the frame, the
daub, the gables, the roof, the door's path; porters bring the straw; the owner lives there when it
stands, and is not cold under its roof; a dead owner's hovel goes to the next.

## Built

- **`Castle.Buildings`** made a pure function: `Design (Seed)` (size, wall height, door, windows) and
  `Blueprint` (every block in building order: the floor row by row; the frame, each post whole, then
  sills, lintel and beam; the daub walked round course by course; the gables; a thatch roof that
  leaves the walls' top beam alone). The prototype's layout on the generated fields moved to
  `Castle.Buildings.Layout` (village_preview still runs, and draws the same hovel).
- **Two blocks, `Thatch` and `Daub`** (palette: derived entries, Thatch_Straw and Daub_Clay), both
  darkening when wet; thatch is not walked on.
- **Second round**: the door's way (`Door_Way`, `Door_Steps`, a landing and a stair in `Target_Row`,
  the pad cut down or the house stood back in `Place_House`); lopping (`Column_Wants`,
  `Level_Column`) and `In_A_House` in `Fell` and `Regrow`; `Kind_Of_Block` (timber logs, daub and
  thatch straw, the floor nothing) and the `Framing` phase; "N at home" on the log's housing line;
  `House_View.Way` and `Rise`; `Step_Member` leaving a load on its way to a house alone at bedtime.
- **`Castle.Colony`, "housing"**: `Habitation_Zone`; `Zone_Housing`, `Plan_Housing`,
  `Housing_Refusal`; the houses (`House_Rec`: seed, place, pad, owner, how far built, what was carried
  to it); `Place_House` on a grid of the zone's free ground; `Begin_Houses` once a colony second; the
  pad's level and its bank (`Choose_Pad`, `Target_Row`, `Level_Patch`); `Think_House` and
  `Step_House` (states `To_Site`, `Raising`; a load `For_House`); `Free_For_Building`; the zone's
  rows of the demand table; `Bed_Spot`, `At_Home`, `Cold`; `Trade_Kind`; `House_View`, `House_At`,
  `House_On`; `Build_Homes_Now`; `Read_Zone_Ground` (the camp's routine made general); the colony's
  ground reaching its housing.
- **The interface**: `Zone_Housing` in the action table and the ground's menu; the Housing tool and its
  preview; `Castle.Pick`'s `A_House`; `Castle.Views.House` and the housing zone's sheet; the marks of
  a zone and of a house begun; `--housing`, `--homes-built`, the log's `housing:` line.
- **Checks**: colony_check's housing section (53), pick_check's (6), the eighth reference log,
  three lines of `tools/stress.sh runner`. `tools/demo_stage6.sh`. The eleven of the second round:
  night coming on a builder with a log in its arms (it fails without the mend: "hungry: carrying a
  log to Agnes's hovel", five hours on); the floor beaten with nothing carried; a blob marked 18 refused; four hundred blueprints held to their
  order (all the timber before anything of straw, no block twice) and to what they take (two); seven
  hovels either side of a path aslant across a made-up hillside, a way from the stake to every bed,
  no floor further off the path's ground than a landing and a stair can join, every owner asleep in
  its own at midnight (three: two of them fail with a landing of one block); trees felled whose
  shapes reach through a house's corner post (it fails without the guard); a vegetable pulled where
  an eave now hangs not growing back (two; likewise). An older one now also sees a neighbour's leaves
  over a lot lopped.

## Measured (seed 1, the reference site, colony_run unless said; the second round's build)

- **Who can get home.** Houses built on the spot on the hillside east of the stake, a band of ten,
  read at midnight and at three: north of the path (the ground rising behind) 4 of 4 and, on a shorter
  zone, 3 of 3 at home; south of it (the ground falling away) **4 of 4, where the first round's build
  had 2 of 4**: the other two could not get in and slept by the fire. `colony_check` now has the like
  on made-up ground. **And built by hand**: the same south side zoned for a band of eight with two
  foresters and a porter, wood and straw supplied: four hovels by the midnights of days 23, 24, 27 and
  29, their landings and stairs made by their builders, none waiting for a way at any midnight, and
  at every midnight of sixteen days as many at home as stand.
- **The stage 6 run** (`reference_run_stage6.txt`): the reference run with `--path 1176 1076 1140 1076
  --housing 1141 1077 1167 1087 --housing 1141 1075 1175 1065 --porters 1 --hunters 1` (a path west
  over the level ground, housing on both sides with room for three hovels each, a porter in the second
  hunter's place). The six hovels stand by the midnights of days 25, 28, 31, 35, 39 and 43, all raised
  by the one forester: one in three and a half to four days, and at every midnight after everyone
  living who has one is in it. (The hovel of plank: days 26, 31, 36, 42, 48 and 55.)
- **The same state** on two workers, in the debug build, and with nothing kept to save work
  (`--no-mending --no-memos`): 14c17293a7702d19 after 41 days. Through a save taken at six days and on
  to twelve, as straight through: 8725fb5446ea799d.
- **The winter in that run, beside two others.** Into winter (day 45) all three have five and a half
  to six and a half days of food and twenty kills. After it:

  | | food runs out | deer killed, days 45 to 55 | at spring |
  |---|---|---|---|
  | the stage 6 run (a porter for a hunter, housing) | day 55 | 6 | four of six (two die on day 56) |
  | the same band, no housing | day 57 | 8 | five of six |
  | the reference band (two hunters, no porter, no housing) | day 55 to 56 | 8 | all six |

  Nobody is cold in any of them. **The first row is not to be leaned on.** The same band with the same
  orders has now been run four times, each on a different build, and ended the winter with none of
  six (the hovel of plank), five (08066af: the hovel of timber and daub), five (9f7e6b7: four blocks
  of threshold more to a hovel) and four (546f22c: the builder no longer loses a night). In
  all four the store ran out on day 55 or 56 and six deer came down in the winter's first ten days.
  What parts them is when the hunter's next deer come down in the last four days (one each on days 55
  and 56 and two on 57, in this one), and where each of the six happens to be when they do. So a run
  of the first winter is settled by a deer or two at either end of it, as the first round found: it is
  as touch and go as it was, and is not tuned (his standing call). No row is a finding about
  housing. I looked, in the first round, for something in housing that costs the band food and found
  nothing; I have not shown there is nothing.
- **Other bands with housing** (the same site with a zone on the hillside east as well, room for nine,
  41 days). The reference band and a porter (seven): seven hovels by day 45, everyone dead by day 55
  (without housing, day 50). Nine with two foresters and three gatherers: all nine housed by day 39,
  dead by day 52. Ten with three foresters: all nine lots built on by day 34, dead by day 52. A mouth
  more than two hunters and two or three gatherers feed starves the band in its first winter, housed
  or not: the capacity to feed is the player's to see to, and is not tuned.
- **What it costs** (546f22c, the machine otherwise idle). The colony's steps over the 41 days: 5.85
  and 5.96 s with housing, 5.89 without; 14,513 plans against 12,112 (a builder plans a short way for
  every bout), 1.75 s in them against 2.07; the longest colony second 17.8 ms against 17.3. (On
  08066af the same run made 21,803 plans and took about a second longer: most of the difference is
  the builder standing through a night planning its way afresh every time it was made to leave off.
  The first round's build read 29,953.) The zone's plan while its far corner is chosen (first round):
  0.8 to 1.0 ms a frame for 52 m by 10 m, as a stockpile's.
- **The look** (RX 6900 XT, 1280 x 720; 546f22c). The hamlet of six at the default view, twice: 2.29
  and 2.31 ms without the houses, 2.41 and 2.43 with; in rain 2.70 and 2.72 against 2.84 and 2.85
  (36,000 quads for the six; the first round's read 2.28 and 2.42, 2.72 and 2.82). The
  twelve fixed views (`tools/look_cost.sh`) were costed against `main` in the first round, the same to
  two hundredths of a millisecond; nothing of a house is drawn in them and they were not costed again.
  Looked at by day at the default view and close, three being built, in rain at dusk and in snow (the
  demo). `tools/shadow_still.sh` (546f22c): 0.00 % on its own view by day and at dusk; with two houses
  in the view 0.3 % of pixels step, all of them two deer (the map of where the picture changes was
  read beside the view on 08066af; the figure is the same on both).

## Saves

Colony blob 19, after everything of 17: the count of houses ever begun; each house's zone, seed,
corner, facing, pad, its door's way (how long, and the row it comes down or up to), owner, whether its
ground is ready and whether it stands, blocks laid, logs and sheaves carried to it, blocks' worth of
each lying there (33 bytes a house); each member's house and patch. A blob of 17 or before loads with
no houses and nobody building. **18 is refused**: it was the first round's layout and the hovel of
plank, and a count of blocks laid would mean other blocks now. No version 17 or 18 blob is kept and no
check loads one (his rule of 2026-11-11). **A change to `Castle.Buildings.Design`, to the blueprint's
order or to what a house keeps moves the blob's version**: a house is saved as its seed and a count.

## Options

`--housing X0 Y0 X1 Y1` (up to 8), `--homes-built`. `colony_run --no-memos` now also keeps nothing
of housing.

## Bugs found and fixed

**One in what John may have** (the first round's zip, of 77b6f83): **a house on ground that falls
away from its path could shut its owner out.** A pad is cut level into the hillside, the path stays up
on the slope, and the footpath between them was laid on whatever lay there: where the step down to the
door was more than the walking map lets a serf take, or came under the eave, there was no way in. The
house stood, its sheet said "Lives here", and its owner slept by the fire and said nothing. Two of
four on the hillside south of the reference path. Mended in 08066af: a door's way is part of the
house's ground (a landing, then single steps), and a house is not placed where one cannot be made.
Found by counting who was at home at midnight on a hillside, which the first round's checks, all on
level ground, never did; `colony_check` does now.

**A second, in the same zip: a builder caught by nightfall with a log or a load of straw in its arms
for its house stood where it was until morning, awake.** Bedtime made it leave off; it had something
in its hands, so it was not sent to bed; so it took the load up again, and was made to leave off
again, twenty times a second. It lost its night (a sleeper burns half the food a waker does), and
with full hands it could eat only stew: with none in the pot it would have gone hungry there (the
check that now holds this read "hungry: carrying a log" before the mend). It went on in the morning. In the stage 6 run it was seen on one night of the thirty after the
builder's own hovel stood (before that nothing in the log could show it). Mended in 546f22c: a load on
its way to a house is carried there first, as every other load in a serf's arms already was. Found the
same way: with four hovels standing, one midnight's count was three, and the one missing was the
builder, seventeen metres from its bed with six sheaves, from ten at night until five.

Also found in the second round, in the same build:
- A tree's shape is asked of the generator again when it is felled, and a house's timber is of a
  trunk's material: felling a tree whose bough had once reached where a post now stood would have
  taken the post. A neighbour's leaves over a lot were built through and left hanging inside the roof.
  Both mended (the lot's ground is lopped; nothing of a tree is taken out of a house).
- A vegetable pulled on a lot before a house was built there would have grown back under its eaves.
- The threshold under a door was left as a strip of turf between the floor and the door's footpath
  (9f7e6b7: it is beaten with the floor).

Mine, in the first round, in no build he has had:
- The prototype's roof had a log ridge, which the walking map takes for ground: the height of a spot
  inside a house came back as the roof's. Found before anything was built on it (a throwaway check
  that routed a serf in at 64 placements of a house). The roof is thatch throughout, and heights
  inside a house come from its pad.
- The prototype's roof overwrote the walls' top beam under the eaves; its walls were emitted left and
  right in turn, its gables end and end: a builder would have crossed the house for every block.
- With a lot refused where it fell more than a metre, a 32 m zone on the reference hillside held two
  hovels. It is two metres, with a metre's bank, as the prototype had.
- A builder waiting for straw said "no trees to fell in reach".
- The fail memos of a house's patches lay where a source's hashed ones do.
- Under the eaves of a house with low walls on a bank, the zone's ground read as the eave.
- A builder that could find no place clear of a wall would have waited for itself to move.
- A housing zone beyond the ground the band keeps loaded would have been built on only while the
  camera was over it.
- A scripted shot taken two hundred frames after `--homes-built` can show bare ground (the stacks
  are meshed a moment later): the demo drops sixty frames.

## Known limits

- A lot is refused by anything standing on it; houses are square to the grid; they stand close.
- A block dug out of a house is not put back; ground dug on a lot after it was begun is levelled
  from nowhere; rock under a pad is dug as earth is.
- From above, whoever is at home is under the roof. A sleeper's tooltip cannot be had through it.
- The roof is laid from the ground (no scaffold); a builder at work crouches as one making ground
  ready does.
- A stockpile or the camp zoned past the work radius is on ground that is not kept (older than this
  stage); housing is.
- A house's owner whose way home is shut (by something dug or built since: a house is now always
  placed with a way in) sleeps by the fire, and says nothing of it.
- A door's way is checked straight out from the door to the path. A house is still not placed with a
  thought for the way from one lot to the next behind the houses.
- Not covered by a check: a dead owner's hovel going to the next without one (the code is four
  lines; death takes a winter to arrange in the check's world).

## Not done

- 6b. Clearing a lot. Shared walls, improvement, families. Un-zoning.
- Of his references: the hearth, stone footings, rushes, furniture, shutters, a steeper roof, the
  longhouse and the croft ("His calls").
- The phase B close (the gate run recorded as such, the pillars reviewed, the design documents brought
  up to date, phase C staged): it waits for his answers.

## Next

- **His answers**: 6a's rules (the calls above: the references' first), then 6b's four questions.
- If he accepts 6a as built: record his words (the framework's decisions, the plan, the stage log,
  CLAUDE.md, the brief, this file's top), fast-forward `stage-6` into `main`, remake the zip from
  `main`. Nothing else is waiting on a branch.
- If he changes a rule that changes what is built or in what order (`Design`, `Blueprint`): bump the
  colony blob and record `reference_run_stage6.txt` again in that commit.
- What a build is checked by: the nine checks in debug, `tools/reference_check.sh` (eight logs),
  `tools/stress.sh runner`, and for a look `tools/look_cost.sh` against `main` built beside it and
  `tools/shadow_still.sh`.
