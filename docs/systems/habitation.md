# Habitation

- Packages: Castle.Buildings (the hovel: its design and its blueprint), Castle.Colony ("housing": zones, lots, the builder, residency), Castle.Buildings.Layout and Iso (the older preview)
- Source: `src/castle-buildings.*`, `src/castle-colony.ads` ("housing"), `src/castle-colony.adb` ("housing: where a house stands", "housing: blueprints, lots, the ground", "housing: the builder", "housing: zoning", "beds"), `src/castle-colony-think_house.adb`, `src/castle-colony-step_house.adb`, `src/castle-colony-think_bed.adb`; the sleeper, the bed and the cloak as drawn: `src/castle-serfs.adb` (`Sleep`), `src/castle-props.adb` (`Pallet`, `Cloak_Folded`, `Cloak_Spread`), `game/castle_game.adb` (`Show_Beds`, `Show_Cloaks`)
- Check: colony_check ("housing", "beds", "a ladder for the roof", "a builder given other work mid build" and "a lot with a couple of holes in it", 159 checks: thirteen of them the fourth round's, three the fifth's), pick_check (6); `tools/reference_check.sh` (`reference_run_stage6.txt`, with beds and at today's pace; the seven older logs with `--no-beds --pace 1`); `tools/stress.sh runner` (the housing run kept and not kept, and on two workers)
- Saves: in the colony blob, version 25
- Stage: 6a (2026-11-12; `docs/production/briefs/Stage_6_brief.md`, `docs/handoffs/Handoff_2026_11_12_stage_6a_habitation.md`). Built on rules drawn from the design documents with first values of mine and put to John; two of them he answered while it was being built ("one hovel per person for now, dirt discarded is fine for now"). Accepted as built on 2026-11-12 ("ok the building looks great, I am impressed, works wonderfully on my end as is"); the calls he did not take up stand by default.
- References: John's, added 2026-11-12 while it was being built, in `~/CASTLE_GAME/Design Refrences/` (outside git: fifteen pictures of twelfth-century peasant houses and villages) with a text on the peasant house of that century; the handoff has his words and the text. How the hovel is made is drawn from them ("The hovel", below; what of them is not built is under "Not there yet").
- A pass after 6a (2026-11-12; `docs/handoffs/Handoff_2026_11_12_housing_pass.md` has John's words whole): housing pulled along a path and combined where it meets housing; a house's ground walled with stone where it rises and falls, its door's stair of stone; roofs trimmed by their builders. Built from his message with first values of mine and put to him. **A second round on his answers** (the same day, his words whole in the same handoff): the lots of the houses still to begin laid out when housing is zoned, never passed over, a hovel nobody's until it stands and then drawn for by lot; the ground between two neighbours made one and their walls met; serfs asleep on their sides; a bed of straw each, by the fire and again in its hovel; cloaks. **A third round on what he found trying the second** (the same day, his words whole in the same handoff): each of the band finds level ground by the fire and lies across the way to it; a bed has the stockpile's straw before a hovel has; no housing across the road that leads off a path's end; housing of all the ground inside a round of paths; a planned path drawn on its ground. **A fourth round on what he found trying the third** (the same day, his words whole in the same handoff): a stair of stone to a door only where the path lies more than a block off the floor; a ladder for the roof, made at the stockpile and thatched from. (Of the same round, in `needs.md` and `colony.md`: the cook's hold, meat by the pound, the lord's cart of salt.) **A fifth round on what he found trying the fourth** (2026-11-13, his words whole in the same handoff): a hovel's lot levelled as if its holes were filled, and they are; a builder takes up a house left further on than its own. (Of the same round, in `needs.md` and `colony.md`: a load taken where it was going before its carrier eats; holes under a path filled.) **The pass was accepted on 2026-11-13** (John, whole: "accepted"): on `main`. Its rules are first values, his to tune.

## What the player does

Housing is marked along a path (John, 2026-11-12: "make the area fixed
distance from the path that will fit a hovel, and then they can pull it
along the path to the desired length, and if they intersect with another
habitation zone let them overlap and just combine the entire zone ...
don't let them go farther than 7 blocks from the end or turn of a path").
The Housing tool (the Tools panel, or "Housing from here" in the ground's
menu), a click beside a path, and a second click as far along the path as
the housing is to go (`Zone_Housing`, `Plan_Housing_Lot`):

* **It is a strip along the path's straight run**, on the side it was
  begun on, from the path's edge 9.5 m back (`Housing_Deep_M`: what the
  largest hovel takes below a path on ground that falls 2 m across its lot;
  beside a path that runs aslant, more, 13.4 m at 45 degrees, since a house
  stands square to the block grid). The second point says only how far
  along. It is shown as it would be taken while it is pulled.
* **A run is the path as the player laid it**: the stretches a path is
  recorded as, end to end in a line, are one run (`Run_Of`). A strip reaches
  no further than 7 blocks past the run's end or its turn
  (`Housing_Past_B`: enough to meet a strip along the path's next leg), and
  no further than 60 m in one pull (`Housing_Long_M`: pull again from its
  end).
* **It is begun within 12 m of a path** (`Housing_Snap_M`), anywhere on
  the side wanted: there is no edge to hit.
* **Its ground is every free block column of the strip that can be got to
  from its own path's edge** without crossing a path, another kind of
  zone, or anything standing. It is taken whether or not a hovel fits on
  it: a strip too short for one is housing all the same, and says "room
  for no hovel yet". **The edge it is begun from is the ground beside the
  path itself, where no other path lies nearer** (John, 2026-11-12: "if a
  player starts to draw a habitation zone that extends the length of a
  path and crosses over a path that changes direction a slice of the
  habitation zone passes over the connecting road"): the seven blocks past
  an end or a turn are reached from there or not at all, so a road that
  leads off the end has no housing on its far side. A side road that
  leaves the strip's own path part way along it does not end the strip:
  it goes on beyond, on both sides of the side road and never on it.
* **Housing it overlaps or touches is combined with it** into one zone
  (`Join_Plan`), the houses of each with it: a zone is extended by pulling
  again from inside it or from its end, and two zones are made one by a
  pull across the gap. (A zone grown past 100 m is left as it is, and the
  strip is a zone beside it.)
* It is refused only with no path within reach of where it was begun,
  begun and ended past the same end of its path, with no free ground in
  the strip ("that ground is housing already"), or beyond the reach the
  band's ground can be kept in at (256 m from the stake).

**All the ground inside a round of paths** (John, 2026-11-12: "it would
be nice if player had a fill option for closed loop paths"): "Housing
inside these paths" in the ground's menu (`Fill_Housing`,
`Zone_Housing_Inside`, `Plan_Housing_Fill`; `--housing-inside X Y`). From
the point clicked it takes every free block column that can be got to, a
block at a time to the four sides, until paths, other zones and whatever
stands have stopped it on every side; housing it meets is combined with
it, and the lots are laid out anew, as for a strip. It is as deep as the
paths lie apart: a strip's fixed depth and its seven blocks past a turn
are a strip's rules, not its (the middle of a block 40 m square is
housing, 19 m from any path, though no hovel fronts a path from there).
It is refused where the ground is not closed round (it runs on 200 block
columns from the point, or to ground that is not in: "the paths round
that ground do not close"), where no path lies beside it, begun on a
path, a zone or something standing, or too far from the stake. There is
no preview: the choice takes it. A path cannot afterwards be laid
through it (`Lay_Path` goes round zones): a lane inside is laid first.

**The lots are laid out at the click** (`Plan_Lots`; John, 2026-11-12:
"Don't let the serfs search for a lot"): the next hovel in turn on the
free frontage nearest the homestake that any housing has, the one after
it with that lot taken, and so on until one fits nowhere. The note says
how many of them lie on this zone ("room for 2 hovels"; `Lot_Count` is
all of them), and the zone's sheet has "Room for: 2 more hovels". **The
hovel next in turn is never passed over for a smaller one** ("Hovels
need to fit within the confines of the zones, if they don't fit the
housing deficit stands until the player designates more area"): where it
fits nowhere the note says so, the sheet says "No room", and nothing more
is begun until housing is marked that it fits on (`Lots_Short`,
`Room_Short`). They are laid out again when a path is laid, and saved.
That is all the player does: which lot, which house, for whom and when
are the band's own.

## What the band does

* **Everyone without a home asks for one**, a hovel each (John,
  2026-11-12: "one hovel per person for now"). Once a colony second
  (`Begin_Houses`), while more are without a hovel than hovels are being
  built, another is begun on the first lot laid out (`Begin_Lot`: that lot
  alone is looked at again, and only if it no longer holds its house are
  the lots laid out anew). Only so many are begun at once: as many as there
  are foresters to build them, and one even with none, so that the zone can
  say what it waits for.
* **A hovel is nobody's until it stands, and is then drawn for by lot**
  (John, 2026-11-12: "just assign it to them by lottery, when the
  construction is complete"). The moment its last block is laid
  (`Finish_House`, `Draw_Owner`) it falls to one of the living who have
  none, picked by the hovel's own seed and how many are in the draw:
  nothing timed, so a run is the same run. A hovel whose owner has died is
  nobody's the second after and is drawn for again among those without.
* **Where.** The free frontage nearest the homestake along any path a
  housing zone lies on (`Place_House`, when the lots are laid out): a point
  every metre of every path, to either side, taken in order of its distance
  from the stake. The house
  stands square to the block grid, facing the path, its front wall half a
  metre to a metre off the path's edge; where the path runs aslant it steps
  back until it is clear, 3 m at most. Its walls and the bank round them
  must lie wholly on the zone's free ground (so a tree, a bush, a boulder or
  water on a lot refuses it: nothing clears a lot yet), on ground that falls
  no more than 2 m across it. It keeps a lot 7 m along the path and 7 m
  back, and no two lots overlap. Beside a path that runs aslant it steps
  back until it is clear, 5 m at most (`Max_Push_B`). Each hovel's size is
  its own, and the larger want more room on a hillside or beside a path
  aslant: on ground that falls 2 m in 7, at 3 of 24 angles of its path, the
  hovel next in turn stands on neither side and one side holds none.
* **Its ground is a yard at its floor's level, walled with stone where the
  land rises and falls** (John, 2026-11-12: "the .25m next to the path will
  be reserved for a retaining wall built from stone in the stockpile,
  stairs built on the path from stone as it rises or falls to the door,
  dirt around the back of a blueprint is dug away and a retaining wall is
  built, if multiple buildings are along that same axis then the retaining
  wall is extended as one, same with houses that step down, retaining walls
  built between them if they share a wall a retaining wall is built along
  the shared wall if its over .25m"). A house's site (`In_Site`) is its
  walls, two blocks of ground behind and to either side of them (as far as
  its lot is: `Apron_B`) and, before its front wall, all the ground to its
  path (`Front`). All of it is brought to the floor's level but the door's
  stair. **Behind and beside, no more than those two blocks**: one of open
  ground, and one that is the wall where there is one. A yard wide enough
  to stand in between a house and a wall over a serf's head is a pit with
  no way out (the walking map lets a serf drop a metre and climb half of
  one): the first version had a metre of yard, and a builder daubing a back
  wall from it starved there. `colony_check` plans a way back to the stake
  from every spot round a hovel that a serf can get to. Then, column
  by column (`Plan_Of`):
  * where the ground beside the site stands **more than a block over it**
    (`Retain_Over_B`), the site's edge is a wall of stone against that
    ground, its top flush with it: the earth behind a house is dug away
    to the wall, and what is beyond stays;
  * where the site stands more than a block over what is beside it (lower
    ground, the path, a lower step of its own stair), its edge is a wall
    holding it up, stone from the foot of the drop;
  * the block of the zone next to the path is the first or the second of
    those wherever the floor is higher or lower than the path;
  * a step of the door's stair has a tread of stone. **There is a stair
    only where the path's ground lies more than a block above or below the
    floor** (`Is_Stair`; John, 2026-11-12, with a picture of a patch of
    fieldstone before a door on ground all but level: "the stairs were
    added when the pathway was pretty much already leavel witht he house
    path"). One block is a step like any other of the land's and is left
    as earth: until then any difference at all made every column of the
    door's way past its landing a tread of stone, four wide and as deep as
    the path lay aslant.
  **Each house walls its own site as it finds the ground beside it**; the
  site is read from the world each time, never kept.
* **The ground between two neighbours is made one** (John, 2026-11-12, of
  the walls behind a row, which stood each by itself: "Yes extend as one
  and they, don't need to be extended as a straight line they can meet and
  turn into each other, just take the difference between the two"). A
  house begun beside an earlier one (`Join_Site`: facing the same way along
  the same path, their walls side by side, with no room for another lot
  between) reaches over to the earlier one's ground (`Reach_L`, `Reach_R`,
  32 blocks at most): the ground between the two is its own to make ready,
  to its own floor's level, from its path back to the end of its own back
  yard. So two hovels stand on one terrace, the wall behind them is one
  wall, and where one stands deeper than the other the deeper one's side
  wall is the turn between the two backs. **Between two sites there is one
  wall, and it is the earlier house's** (`Plan_Of`, `Site_Of_Block`): the
  earlier house's edge is planned against the later one's level, the later
  one plans nothing against the earlier one's, and the later one's builder
  makes what of the earlier one's edge is changed by it (`For_Site`): a
  wall of stone where their floors are more than a block apart, none where
  they are not, the earlier one's own side wall taken down to what is still
  wanted. Either may be built first, or both at once: `colony_check` builds
  them each way and scans the ground between for earth left as it lay, for
  stone standing over both yards, for a bare step and for a pit. **A tree
  between two lots keeps them apart** (anything a zone does not take): the
  later house keeps to its own ground, and each walls its own side. The
  ground made one round the tree's foot was tried: in a gap a few blocks
  wide the tree's own ground, walled, shuts the back of the gap off, and
  what lies behind it is a pit. Houses do not share walls yet: his rule for
  a shared wall is applied to the wall between two terraces.
* **Its door can always be got to** (`Door_Way`, `Door_Steps`,
  `Level_Of`). Straight out from the door to the path's ground is the
  door's way: level with the floor for three blocks (`Door_Landing_B`: a
  serf stepping down to a door from higher ground would not clear the eave
  and the lintel), then a stair of single steps, cut or built up, to the
  path (of stone where it climbs more than a block, above). Beside a path that runs aslant the door's columns are not all as
  long: the stair is made over the shortest (`Door_Run`), and what the
  longer ones have past it lies at the level of the stair's foot, out to
  the path's edge (as first built they ended in a stub of the yard's wall
  across half the stair's foot). A floor can so lie only a step above or below the path where the
  path is hard by, and a step more for each further block: a pad that would
  lie higher is cut down to that, and a house whose pad would lie lower
  stands further back from the path until its stair is long enough. The
  pad's level is the highest at which the earth dug off the whole site is
  at least what its hollows take (`Choose_Pad`), **reckoned as if its holes
  were filled** (`Fill_Hollows`: a hollow is ground at one level, its
  columns side by side, each closed in on its four sides by higher ground
  or the hollow's own, nothing lower beside it, at most `Hollow_Most`, 64
  columns, four square metres; filled to the lowest of the ground round it,
  twice over, so a hollow in a hollow fills up). They are filled with the
  turf cut off its floor. A step of a slope, the inside corner of one, a
  notch running into one, all go on to lower ground: no hollow, and a pad
  on a slope is where it was. John,
  2026-11-13: "othewise even ground was dug out entirely becuase it had a
  couple of holes in it, instead of just filling the holes". Reckoned on
  the ground as it lay, two holes a block deep in level ground wanted three
  blocks of earth that nothing dug off gave, so the whole site went down a
  block (334 game minutes of digging on `colony_check`'s meadow, where the
  ground is now ready in 38 to 53, with a hole four by four besides). **And
  grass left in the air**: a hole dug under tall grass (the dig tool took
  the turf and left the grass) left it in the air, and the levelling cut
  only what stood on a column's top. Now the game's dig takes what grew on
  the ground it removes, and a site's levelling cuts whatever is left over
  a hole (`Cut_Plants`, `Plants_Over`; a path's laying too). That is one
  way grass floats; what John saw ("the grass stays in the air") was found
  on a couple of blocks only, where grass had been gathered before the plot
  was begun, and its cause is not known: he will reproduce it if he sees it
  again (2026-11-13, "Just leave it for now"). Whether `Cut_Plants` covers
  it is untested. The
  turf's side at a cut is still drawn as a bank of grass, as a step in the
  meadow is.
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
  of eave, **laid in steps and then trimmed to one slope** ("The roof
  trimmed", below). A blueprint is a pure function of the house's seed and of where
  it stands: the colony keeps the seed and the place, never the blocks.
* **Builders come from the foresters** (`Trade_Kind`, `Trade_From`: the
  first earned trade). A forester takes a house that has no builder, the
  best at building first, and is its builder until it stands
  (`Site_Of`, `Trade_Of`). Nobody is appointed (it is not a job in anyone's
  menu) and no skill is asked. Building is its own work, not an extra task:
  it counts against no limit on hands, and the camp's building and the
  paths come first for it as for anyone. Given another job, it leaves the
  house to the next forester free to take it, and a log in its hands goes
  back to the stockpile. **Of the houses nobody is building, the one
  furthest on is taken first, and a builder leaves its own for one left
  further on than it** (`Further_On` in `Think_House`: nothing while a
  house's ground is made ready, then by the blocks laid; its own house
  goes back to whoever is free, and what lies at its site stays there).
  John, 2026-11-13: "I removed the cook from cooking, he started building
  a house, the build was asigned to him, I then sent him back to cooking
  mid build and it didn't free up the assignment for the build". It had
  been left, but the other forester was levelling the ground of a third
  hovel by then, and a builder kept to its own until it stood: the house
  half built waited a day for it. `colony_check` sends the builder of the
  hovel further on to cook with its roof on (the other is at it eight
  game minutes later, and back at its own when that one stands; 910
  minutes the old way), and then the one behind (the other keeps to its
  own).
* **The ground first**, a square metre at a time (`Tamp_S`, at its rate for
  `Site_Work`), **from the path back** (`Go_Level`, `Patch_Band`: whoever
  digs is never left in a pit). What grows on the site is cut; a
  neighbouring tree's leaves and boughs hanging where the house and its
  eaves will be are lopped (the tree stands, and is felled as any other:
  nothing of a felled tree is taken out of a house, `In_A_House`); earth
  standing over where a column's top is to be is dug off, and a hollow
  filled. The earth is the site's own: what is over is thrown aside on the
  lot (John, 2026-11-12: "dirt discarded is fine for now"), not carried to
  a stockpile. **Then its walls and its stair's treads, of stone**: with
  the earth of a square metre moved, a bout's worth of the stone that lies
  at the site is laid there, from the foot of each wall up (`Wall_Patch`).
  **Earth that stands where stone is to go is left until the stone is laid
  in its place**: a wall is never dug out first and built after, so the
  ground of a site is whole at every moment.
* **Then the blueprint, block by block** in its order
  (`Castle.Buildings.Blueprint`): the threshold under the door and the
  floor beaten, row by row; the frame
  (each post raised whole, round the house; the sills and the lintel; the
  beam along the top); the daub, a course at a time, each walked round the
  house; the gables; the roof, strip by strip from one eave over the ridge
  to the other; then the roof trimmed, strip by strip the same way; and,
  when the last block is laid, a footpath from the door to the path. The builder lays sixteen blocks, a square metre, in a bout
  of 5 s (`Lay_Blocks`, `Lay_S`, at its rate for `House_Raising`, which
  teaches building, a little carpentry and less forestry), from what lies
  at the site, standing clear of the wall it is at (outside for the walls
  and what is near them, inside for the rest). A block is not laid where
  someone else stands.
* **The roof trimmed** (John, 2026-11-12: "the roofs, are to be smoothed,
  but not rendered smooth instantly, the builders smooth the roofs so they
  don't step, rounded edges around the peremeter"). The last stage of a
  blueprint (`Dress`) is the top block of thatch of each column of the
  roof laid again, now with a state that says it is dressed and how it
  lies (`Castle.Blocks.Dressed`); where the roof hangs out past a gable or
  lies on one, the block under it and the top of the gable's daub as well.
  It is work alone: sixteen blocks a bout of 2 s (`Trim_S`), five or six
  game hours a roof. A dressed block is drawn with its top on the roof's
  slope, a blunt edge at the eave, a low cap along the ridge and its ends
  drawn in a little (`rendering.md`, "A dressed roof"): a roof is seen to
  go from steps to a slope strip by strip, behind its builder.
* **A ladder for the roof** (John, 2026-11-12: "serfs building spend a lot
  of time walking around the house thatching, can we have them construct a
  ladder in the stockpile, and use the ladder to thatch roofs, that would
  be cool"; first rules and values of mine, his to tune). From the ground
  a builder stood beside the middle of each bout's blocks, outside the
  nearest wall, and a roof is laid strip by strip the house's whole
  length: every bout was a walk to the next wall, and trimming the same
  again (measured below: more of a roof's time went in walking than in
  thatching).
  * When a house's roof is next (`Roof_Next`) its builder gets a ladder:
    one left standing at a hovel that is built, else one from a stockpile,
    else **it makes one at the stockpile**, of a log that building may
    take (`Ladder_Wood`; `Free_For_Building`), where it stands with the log
    (`Ladder_S`, 20 s at its rate of building: "making a ladder").
  * **The log is asked of the stores with the house's timber** from the
    day the house is begun, while there is no ladder to be had for it
    (`Ladder_Short`, in the zone's `Once` row for wood). In a young colony
    that is not enough: every log a lone forester brings in goes to the
    fire and the frames, and when the roof comes none is free. So **its
    builder then goes and fells for it**, as the forester it is
    (`Ladder_Fells_Most`: two trees at the most), and the first log it
    carries home is not stacked: the ladder is made of it there
    (`Wants_Ladder_Log`). In the stage 6 run's first hovel that is a
    tree felled at five in the evening, a ladder made by half past, and
    the builder up it at six.
  * It carries it to the house over its shoulder and stands it under the
    eave of the slope that is next, at the middle of that wall and clear
    of the door (`Ladder_Place`: 3.5 blocks out, or as near as it can get,
    as a builder's standing place is found for any bout).
  * **From the ladder a bout is laid with no walking**: every block of
    that slope is within its reach (`At_Ladder`, `Lay_Bout`), the bout
    still sixteen blocks and five seconds. It is seen up on the rungs
    (`Aloft`, `Shown_At`; `Castle.Serfs.Perch` draws the whole of it that
    much higher: no climbing is shown).
  * When the other slope is next it carries the ladder round ("going for
    the ladder", "carrying the ladder to ..."): four stands to a roof, two
    for the thatch and two for its trimming.
  * **A ladder left at a hovel that stands** goes to the next roof that
    wants one, or back to a stockpile while there is room there (a ladder
    is a stored good: two to a place).
  * **Never a reason to stop**: with no ladder to be had, no log for one
    and no tree it may fell (or two felled and still none), and where a
    ladder cannot be stood or got to, the roof is thatched from the ground
    as it was.
  * A ladder is in one place at every moment: stored, carried, or standing
    at a house (`colony_check` adds them up every second; one carried by
    somebody who dies is lost with the rest of its load, and counted).
    Two builders at two roofs make a ladder each. It is drawn
    (`Castle.Props.Ladder`, `Put_Ladder`; in a stockpile's place it is
    stood all but upright against a pole, `Put_Ladder_Stood`, since lying
    its 3.4 m ran through the goods of the places beside it) and is
    nothing in the world: no block, nothing of the walking map.
  * `--no-ladders` (`Set_Ladders (False)`) is every roof from the ground.
  * Measured (seed 1, the reference site, one forester building along the
    level path west with wood, straw and stone supplied, today's pace):
    from the ground a first roof is 270 game minutes of thatching and 183
    of going to its work, and its trimming 71 and 127. Over six days, from
    the ground, two hovels stand and a third's roof is begun: 588 minutes
    thatching and 398 going to its work, 138 trimming and 310. With
    ladders, in the same six days, three stand and a fourth's roof is
    begun: 825 thatching and 55 going to its work, 208 trimming and none;
    the ladder itself is 16 minutes in the making, 155 carried (to the
    houses, round them and back to the stockpile) and 36 gone for. On the
    check's meadow at the old pace: 20 game minutes
    going to its work at two roofs, where it was 1,023, and the two hovels
    stand in 3,525 game minutes, not 4,340. In the stage 6 run (nothing
    supplied: straw and wood are what a hovel waits for) the six stand by
    the midnights of days 23, 25, 27, 29, 32 and 35, where they stood by
    those of 23, 26, 28, 31, 34 and 36; one ladder serves all six.
* **Materials** are carried from the stockpile by the builder, a log, a
  load of straw (six sheaves) or of stone at a time, and are the site's
  from when they arrive. **Stone comes first**: a stone makes sixteen
  blocks of wall or stair (`Wall_Per_Stone`); what a site still wants of it
  is counted from the ground as it stands (`Site_Patches`, `Note_Stone`),
  so the count moves if the ground beside it does; the camp's hearth has
  first call on the stones in store (`Free_For_Building`). Level ground
  takes none (of the stage 6 run's six lots one takes a stone); on the
  hillside east of the reference stake a hovel takes up to 25; on ground
  that falls 2 m in 7 it takes 24 on average and 45 at the most, with
  1,500 blocks of earth moved. **Timber is logs** (a log makes 96 blocks: `Planks_Per_Log`);
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
* **Reversion.** A builder with nothing to build with (no stone for its
  ground's walls; no wood in store that building may take; no straw, once
  the frame stands) goes on as the
  forester it is: it fells while wood is asked for, and comes back to its
  house when there is something to lay. Its status says what its house
  waits for ("no straw to build a hovel with"). At nightfall, or
  very hungry, it leaves off as anyone does, but a load already on its way
  to the house is carried there first. **So with nobody
  cutting straw a house stops at its bare frame** (a porter cuts straw; the
  reference band has none).
* **Residency.** Whoever a hovel falls to lives there: it sleeps in it
  (`Bed_Spot`: in the back corner, a metre off the walls, lying along the
  house) instead of by the fire, from that night (from the next, if it had
  gone to sleep by the fire before the hovel stood), and asleep under its
  own roof it is not cold in winter, fire or no fire (`At_Home`, `Cold`).
  Nothing else follows from having a home yet.
* **A bed of straw** (John, 2026-11-12: "when the campground is built
  have them pull or collect straw for a bed ... When they get assigned a
  home they can build a new straw bed in their house, we will let the old
  one decay outside when we add decay later"). Each of the band makes its
  own where it sleeps (`Wants_Bed`, `Think_Bed`): by the fire as soon as
  the camp stands, before the band's building and before its job, and
  another in its hovel as soon as one is its own. Two sheaves
  (`Bed_Straw`): from the stockpile if it holds any, whatever the hovels
  being built still want of it (John, 2026-11-12: "serfs didn't create a
  bed when straw was in the stockpile, might have been reserved by the
  housing, basic needs take priority"), else cut by its own hand as a
  porter cuts straw (the grain of wild grain cut so is carried to the
  stores afterwards). It carries them to where it sleeps and
  lays them (`Make_Bed`; what grows under the bed is cut). With no more to
  be had, or night come with one sheaf in its arms, it lays what it has: a
  thin bed. With none stored and none found to cut it looks for some to
  cut again thirty game hours later, and takes straw from the stockpile
  the moment some is there; it sleeps on the ground meanwhile (an owner on
  its hovel's floor, under its roof).
  The bed by the fire stays where it was made, its maker's or a dead
  one's; a hovel's bed is the hovel's, and whoever the hovel falls to next
  has it. A bed is laid only where its maker sleeps at that moment: one to
  whom a hovel falls on its way to the fire with its straw carries the
  straw on to the hovel. With a bed, a serf come within a step of it lies
  down on it, not beside it (`Lie_On_Bed`). **A bed changes nothing but what is seen**: no
  warmth, no rest. `Set_Beds (False)` (`--no-beds`) is the band as it was.
* **Where each lies by the fire** (John, 2026-11-12: "it would be nice if
  the serfs found level ground and slept perpendicular to the fire").
  The first time it thinks once the camp stands, each of the band chooses
  a place of its own (`Place_Bed`): its middle on a ring round the fire,
  3.0 to 5.5 m out and half a metre apart (`Bed_Near_M`, `Bed_Far_M`,
  `Bed_Ring_M`: clear of the camp's level floor, and near enough that a
  warm fire keeps the cold off), lying across the way to the fire; on the
  camp's ground or nobody's, no path's, bare but for what grows and can be
  cut and with nothing over it; 0.9 m at the least from the next
  sleeper's line (`Bed_Apart_M`); got to on foot from the cook's side of
  the fire. Of those, the nearest to the fire whose ground is level under
  all its length (read from the blocks, a metre to either end of its
  middle and a block to either side: `Lie_Ground`); a place a block out
  of level counts 3 m further off (`Bed_Step_M`) and one more than two
  blocks out is no place (`Bed_Uneven_B`). So on a hillside they lie
  above and below the fire, along the hill. With no such place it lies as
  the band did before, on a ring 2.7 m out with its feet to the fire,
  whatever the ground. The place is chosen once and kept (`Placed`,
  `Bed_At`, `Bed_Dir`; saved): it is where it sleeps with or without a
  bed, and where it makes its bed. Once a game hour (`Keep_Beds`) a place
  that a path, a house's ground or a dig has come to is nobody's any more,
  a bed made there is gone with its straw, and whoever still sleeps by the
  fire chooses again and makes its bed again. One lie feeds everything
  that shows or uses it (`Bed_Spot`, `Bed_Facing`, `Camp_Bed`,
  `Sleeping_Place`, the grass cut under a bed, the pallet, the cloak);
  asleep across the way to the fire its face is to the fire
  (`Castle.Serfs.Lie_Facing`: the side it lies on follows from the way it
  lies). With `--no-beds` nothing is chosen and the band lies on the old
  ring, exactly.
* **Cloaks** (John, 2026-11-12: "can we add cloaks, they can set down
  next to their bed during the summer, wear it during with their winter
  clothes in the winter, and use it as a blanket when they sleep?").
  Everyone has one, of the wool its winter outfit's cloak always was
  (`Castle.Bodies.Rig.Cloak`). Nothing of it is the colony's: the game
  draws it from the season and from what its owner is doing
  (`Show_Cloaks`): awake outside winter, folded by the head of its owner's
  sleeping place; awake in winter, on its owner's back; asleep, spread
  over its owner, and in winter off its back the while
  (`Outfit.Cloak_Off`: one cloak, never two; the hood stays on). **A cloak
  changes nothing but what is seen.**
* **Asleep, a serf lies on its side**, a little curled up (John,
  2026-11-12: "have serfs sleep on their side"; `Castle.Serfs.Sleep`,
  `serfs.md`): which side is its own. The dead lie on their backs, as they
  did.
* **The colony's ground reaches its housing** (`Ground_Reach_M`): the
  stacks under every housing zone stay loaded wherever the camera is, as
  the ground the band works on does.

## What is shown

A housing zone is filled like any zone (a pale blue). A house begun is
outlined where its walls will stand, with a mark at its door, until it
stands. A tooltip on a house (its walls, its roof, or the ground inside
its outline: `Castle.Pick`, `A_House`; `Castle.Views.House`) says whose it
is (being built: "For: whoever draws it when it stands"), what is being built (the ground, the floor, the frame, the walls, the
roof, the roof's trimming) and how far, who builds it, the stones, logs and sheaves
carried to it of what it takes, and what it waits for (a builder, wood,
straw, a way to it). The zone's sheet says how many stand and how many
are being built, who is still without a home, how many more hovels it has
room for, a line for each house being built, what the zone still takes,
and why nothing moves when nothing does (no builder: builders come from
the foresters; no room for another: mark more housing along a path). A
person's sheet says where it lives ("a hovel of its own, drawn by lot")
and what bed it has ("of straw, by the fire", "of straw, in its hovel",
"none yet"), and a builder's what it builds. The log's `housing:` line
says the same, how many are at home (asleep or not, inside their own
walls), how many more there is room for, and, when some are at home, who
has a home and is not in it and what it is at
(`Castle.Scenario.Housing_Line`); its `beds:` line how many of the living
have a bed, the sheaves in them all and, once the camp stands, who has
none and what it is at (`Beds_Line`).

A bed is a flat heap of straw, 1.9 m by 0.8 m, lying back from where its
sleeper's feet are (`Castle.Props.Pallet`; `Camp_Bed`, `House_View.Has_Bed`).
A cloak is two looks to a wool, made when first asked for
(`Cloak_Folded`, `Cloak_Spread`: the spread one a low mound of two boxes
over the sleeper from its shoulders to its feet, its head out).
`--lineup N --lineup-does Sleep` shows a row asleep under their cloaks
in daylight, with no colony.

## Options

`--housing X0 Y0 X1 Y1` (a housing zone, up to 8), `--housing-inside X Y`
(all the ground inside the paths round that point, up to 8), `--homes-built` (a
hovel for everyone the zones have room for, built on the spot and drawn
for, as `--camp-built` builds the camp), `--no-beds` (nobody makes itself
a bed: the band as it was, which the seven older reference logs are run
with), `--no-ladders` (every roof thatched from the ground, as before the
pass's fourth round). `colony_run --no-memos` also turns off what housing keeps only to
save work (a blueprint drawn once while it is the one in hand): a run
must end the same either way, and `tools/stress.sh runner` proves it.

## Tunables

At the top of `castle-buildings.ads`: the hovel's sizes (`Min_Floor_B`,
`Min_Width_B`, `Max_Width_B`, `Max_Depth_B`, `Depth_Var_B`, `Wall_H_B`),
its openings and its frame (`Door_W_B`, `Door_H_B`, `Window_B`,
`Window_Up_B`, `Stud_B`), where it stands (`Setback_Min_B`,
`Setback_Max_B`, `Max_Push_B`, `Max_Step_B`, `Apron_B`, `Apron_Front_B`,
`Door_Landing_B`, `Lot_B`, `Max_Reach_B`). In `castle-colony.ads`, with `Zone_Housing`:
`Housing_Deep_M`, `Housing_Past_B`, `Housing_Snap_M`, `Housing_Long_M`,
`Run_Straight`, `Run_Joint_M`; and under "housing" `Retain_Over_B`,
`Wall_Per_Stone`, `Trim_S`; with the beds, `Bed_Straw` and where a sleeper
lies by the fire (`Bed_Near_M`, `Bed_Far_M`, `Bed_Ring_M`, `Bed_Apart_M`,
`Bed_Step_M`, `Bed_Uneven_B`). In `castle-colony.ads`, "housing":
`Lot_M`, `Planks_Per_Log`, `Thatch_Per_Sheaf`, `Lay_Blocks`, `Lay_S`,
`Build_Reach_M`, `Reach_Slack_M`, `Stand_Off_B`, `Stand_In_B`,
`Stand_Near_M`, `Bed_In_B`, `Home_M`, the ladder's (`Ladder_Wood`,
`Ladder_S`, `Ladder_M`), and the capacities (`Max_Houses`,
`Max_House_Blocks`, `Max_Fronts`, `Max_Site_Patches`).

## Saves

Colony blob 25, after everything of 17: how many houses have ever been
begun (the next one's seed is made from it), then each house's zone, seed,
front-left corner, the way it faces, its pad's level, how long its door's
way is and the row of the ground where that meets the path, its front yard
(how far its ground reaches toward the path at each place along its front
and along what it reaches over to a neighbour's: 94 bytes), how far it
reaches to either side, the stones carried to it, the blocks' worth of
stone lying there and the blocks of wall still to lay as last counted,
whose it is, whether a bed has been made in it, whether its ground is
ready and whether it stands, how many blocks of its blueprint are laid,
the logs and sheaves carried to it and how many blocks' worth of each lie
there not yet laid; then, for each member, the house it is building and
the patch of its ground it is at (two bytes: a site may be 384 patches);
then the band's pace (`docs/systems/colony.md`) and the beds (whether
they are made, the sheaves in them all, each member's own at the camp,
where, the sheaves in it, and its place by the fire: whether it has
chosen one, the way it lies there and the rows of the ground under it);
then the lots laid out (a count,
whether the next hovel fits nowhere, each lot's zone and where its house
would stand: its house is the design of its serial's seed); then what the
pass's fourth round added (23): whether the cook keeps a pot's fill;
whether meat is cured, whether the cart stands and has been looked for a
place, where, the way it lies, its salt, the deer salted and not and the
meat lost; what is asked and kept of salt and ladders; whether roofs are
thatched from ladders, those made and lost, for each house the eave its
ladder stands under, where its foot is and the trees its builder has
felled for want of one, and for each member the house whose ladder it is
going for; then the fifth round's (24): whether a hole under a path is
filled as it is laid (`colony.md`, "Paths"); then the lord's cart's tow
(`colony.md`, "The lord's cart"). A house's
size and openings are its seed's (`Design`), and what it takes is counted
from its blueprint again on a load. **So a change to `Design`, to the
order `Blueprint` emits in or to what a house keeps moves the blob's
version** (a saved count of blocks laid would mean other blocks): 18 to 24
were housing before the pass's fifth round, before its fourth, before the band chose where to lie, before its lots were
laid out beforehand, before its ground was walled and its roof trimmed
(the hovel of plank, stage 6a's as accepted, the pass's first and second
rounds) and are refused; a blob of before them loads with no houses, beds
on and none made, at the pace the band had, with nothing kept by its
cook, no cart, its meat in joints and no ladders. By John's rule of
2026-11-11 no blob of 17 to 21 is kept and no check loads one
(`colony_check` marks a blob 18 to 24 and sees each refused). A zone's number can change when
housing is combined: whatever keeps one (a stockpile's places, the camp, a
house) is renumbered in `Join_Plan`, and the lots are laid out anew.

## What it costs (seed 1, the reference site, release)

- The stage 6 run's 41 days: the colony's steps about 5.7 s (the reference
  band's without housing or beds 5.9), some 14,600 plans where that has
  12,112 (a builder plans a short way for every bout). The longest colony
  second is 18.0 to 18.7 ms (the plain band's 17.2), a route planned: no
  lot is searched for while the band works (with the search in it, in the
  pass's first round, it was 31 ms).
  (Those at the pace the band had until 2026-11-12. At today's, the same
  run with its second stockpile: 5.7 s, the longest second 19.7 ms, 17.5
  with `--pace 1`.)
- Planning a strip while it is pulled: 0.7 ms a frame for 40 m (its
  ground only: `Plan_Housing (..., Count => False)`). The click that zones
  it, every lot of every housing zone laid out with it: about 1 ms for
  seven lots on two zones. Filling a block 39 m square inside four paths,
  its sixteen lots laid out: 5.5 ms, once, at the click. A block 36 m by
  24 m filled and in view: nothing on the GPU that can be read, 0.07 ms a
  frame on the CPU (its ground's strips laid as marks).
- The look (1280 x 720, RX 6900 XT): the hamlet of six at the default view
  costs 0.11 to 0.15 ms of GPU a frame more than the same ground without
  its houses (2.45 against 2.30 to 2.35; in rain 2.80 against 2.66 to
  2.72); 43,700 quads (a dressed roof's faces are a quad to a block). The
  twelve fixed views, `main` and the branch back to back, twice: 0.02 to
  0.05 ms more at the four with the most land in them (the meadow 1.73
  against 1.76 and 1.77), the rest the same to two hundredths: the land's
  shaders have a dressed roof's two branches in them whether or not a roof
  is in the view (John, 2026-11-12: "no need to write a seperate shader
  program for something that is going to realize it's cost eventually").
  Beds, cloaks and sleepers on their sides: the camp's two fixed views and
  the hamlet read what they read before, by day and at night with everyone
  asleep under a cloak, to two or three hundredths.

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
- Clearing a lot (a bush, a tree or a boulder on it refuses it; **a tree
  between two lots keeps their ground apart**, and felling it afterwards
  does not join them); houses at any angle but square to the grid; shared
  walls (his rule for the wall along one is applied to the wall between two
  terraces); improvement (a storey).
- Walls: a wall is one block thick and is not mended if the ground beside
  it is dug away afterwards (a finished house's site is read again only by
  the builder of a house begun beside it); the yard is bare earth. Stone
  under a pad is dug as earth is.
- Lots: a hovel the plan cannot place blocks every hovel after it until
  there is housing it fits on; nothing shows the player where the lots lie
  before their houses are begun (`Lot_At` has them).
- Beds and cloaks: neither does anything; the old bed by the fire does not
  decay (John: later); a bed lies flat, so on a place a block or two out
  of level, or on the old ring where there was no place, part of it
  stands in the air; a sleeper lies across the way to the fire and never
  along a contour that runs another way (level and across cannot both
  hold everywhere on a hill: across is kept, and a place up to two blocks
  out of level taken); more than the thirty-odd places there are within
  5.5 m of a fire on level ground lie on the old ring; a place is not
  given up for a zone marked over it, only for a path or a house's ground;
  the spread cloak is two boxes, a mound and not cloth; a hovel drawn
  after its winner is asleep is slept in from the next night.
- The filling of a round of paths: no preview; housing only (no other
  kind of zone is filled so); what closes it may be water or a line of
  boulders as well as a path, so long as a path lies beside it somewhere.
- Roofs: the underside of a roof inside the house is in steps still (seen
  now through a roof cleared on the camera's ray, `rendering.md`, within the
  taper by the walls); the roof's pitch is one to one; a ray pointed at
  a trimmed roof meets the block it was (the tooltip's reach is half a
  block generous there).
- Families (a hovel each, children too); any say in who is housed first (it is a lottery).
- Un-zoning; pulling a house down; mending one that has been dug into (a
  block dug out of a standing house stays out).
- A builder's tools and a building animation of its own (it crouches to
  its work as a serf making ground ready does, on its ladder too);
  climbing (it is on the ground or up the ladder); scaffolding; a ladder
  for the gables and the tops of the walls (they are daubed from the
  ground, with the same walking round: John asked for the roof).
- A view into a house from above: its owner asleep inside is under the
  roof and is not seen.
- Stockpile improvements (stage 6b: `Stage_6_brief.md` lists what is
  asked of John).
- Rock under a pad is dug as earth is; earth for a hollow is never short
  by how the pad's level is chosen (a hole's by the turf of the floor), but
  ground dug up on a lot after it was begun is filled from nowhere.
