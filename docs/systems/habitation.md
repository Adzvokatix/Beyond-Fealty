# Habitation

- Packages: Castle.Buildings (the hovel: its design and its blueprint), Castle.Colony ("housing": zones, lots, the builder, residency), Castle.Buildings.Layout and Iso (the older preview)
- Source: `src/castle-buildings.*`, `src/castle-colony.ads` ("housing"), `src/castle-colony.adb` ("housing: where a house stands", "housing: blueprints, lots, the ground", "housing: the builder", "housing: zoning", "beds"), `src/castle-colony-think_house.adb`, `src/castle-colony-step_house.adb`, `src/castle-colony-think_bed.adb`; the sleeper, the bed and the cloak as drawn: `src/castle-serfs.adb` (`Sleep`), `src/castle-props.adb` (`Pallet`, `Cloak_Folded`, `Cloak_Spread`), `game/castle_game.adb` (`Show_Beds`, `Show_Cloaks`)
- Check: colony_check ("housing", "beds", "a ladder for the roof", "a builder given other work mid build" and "a lot with a couple of holes in it", 159 checks: thirteen of them the fourth round's, three the fifth's), pick_check (6); `tools/reference_check.sh` (`reference_run_stage6.txt`, with beds and at today's pace; the seven older logs with `--no-beds --pace 1`); `tools/stress.sh runner` (the housing run kept and not kept, and on two workers)
- Saves: in the colony blob (version 25 when this was written; 44 on 2026-11-22)
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
  across half the stair's foot). **Its steps are made again to the path as it
  lies** (2026-11-23, his "we have blocks that aren't knocked down";
  `Meet_Door`, `Set_Door_Meet`, `--no-door-meet`, not saved): the way is
  planned when the hovel is placed, against the ground where it will meet
  its path (`Door_Row`), and the path is laid afterwards, brought to its own
  line or the square's level and stepped where it meets other paths. So a
  step of the way could stand a block over a path that had come to lie
  lower, or the way end half a metre off it. When the hovel's ground is
  ready, and again when it stands, the columns of its way past the landing
  are made again between the landing's level and the laid path's top beyond
  the way's end, a block a column from the path's side back; and where the
  way has not columns enough, the path's edge before it is stepped as a path
  is (never the square's own). Only where the path is laid there; not a
  storehouse's way, nor a hovel's whose ground is made where it is drawn
  turned. A floor can so lie only a step above or below the path where the
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
  menu) and no skill is asked. **At most four at once** (2026-11-17, John:
  "let's limit the number of builders that can be promoted to four";
  `Most_Builders`, `Set_Builders`, saved: blob 26): a fifth forester fells,
  and no more houses are begun at once than there can be builders for
  (`Begin_Houses`). `--builders 0`: no limit, as before (`colony_check`:
  six foresters and room for eight hovels, four builders and four hovels
  begun; with no limit six and six). Building is its own work, not an extra task:
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
* **A builder with no house of its own helps at a larger one** (2026-11-23, his "let's also have
  builders who finish their project help finish larger projects together"; `Set_Build_Help`,
  `--no-build-help`, not saved; `Helping`, `Builders_At`; in `Think_House`). A forester that could take
  a house (the best free at building, while fewer than `Most_Builders` build) and finds none without a
  builder goes to a larger house that is being built: one whose blueprint is more than `Help_Over_B`
  (6,000 blocks: a hovel's is some 3,400, the storehouse's some 15,000), the one with the most still
  to lay, where no more than `Help_Most` (3) build already. `M.Site` is that house for it too: it makes ready a
  square metre nobody else of its builders is at, stands on no place another of them stands on,
  fetches what the house is short of, and lays the next blocks of its blueprint. **The house is its
  first builder's** (`Builder_Of`: the lowest number); a helper is whoever else has it (`Helping`),
  which nothing saves. It leaves when a house has no builder (it takes that one) and while the roof is
  thatched (one ladder, one thatcher); else it stays until the house stands. Today the rule means the
  storehouse. Helpers count among the `Most_Builders`. Measured (`colony_run --builder-stats`,
  "helping"; the build gated on 2026-11-23): in the game as it is played, eight hovels to build, the
  storehouse stands after 16.04 days for 17.26 (three builders at it at the most, 4,859 serf-seconds
  of help: the foresters are at hovels until the fourteenth day); with two hovels to build, after
  9.97 days for 15.21; at three other squares with no hovels to build, after 8.44, 8.24 and 8.07 days
  for 15.35, 13.29 and 13.46. **Three at one floor walk round one another**: each takes the nearest
  square metre of the same row, so a builder's next is 1.7 to 2.9 m from its last where one alone
  has 1.4 to 1.8 m (having each take first what it stands nearest to measured no better).
* **The ground first**, a square metre at a time (`Tamp_S`, at its rate for
  `Site_Work`), **from the path back** (`Go_Level`, `Patch_Band`: whoever
  digs is never left in a pit). **Worked from beside it** (2026-11-23, his
  "the builder is standing on the blocks their placing and when the place
  them they fall through, maybe extend their reach a little bit";
  `Go_Beside`, `Set_Reach_Out`, `--no-reach-out`, not saved): its builder
  stands on a place of the walking map within `Site_Reach_M` (1.75 m) of
  the middle of the work, none of whose block columns that bout writes, for
  choice one with no work left in it and of those the nearest to where it
  stands, **and only one with a way back to the stake** (a square metre dug
  down beside higher ground can be walked into and not out of: the three
  best places are tried); with none, on the square metre as before, and
  whoever is then left with earth or stone over its feet is stood on it
  (`Stand_On_Fill`, `Stood_On_Fill`). **It goes all the way to the place
  chosen** (`Goes_Beside`: its goal is the place, its spot the middle of the
  work, both saved; so `Near_Of` is `Beside_Near_M` and the walk ends at the
  way's end): until late on 2026-11-23 it stopped within half a metre, as a
  builder stops short of any work, and half a metre short of a place none
  of whose columns is written is another place; a way found again on the
  way could end `Build_Reach_M` off. A place lost on the way is chosen
  again at once (the house is not left alone for it). Before the rule a
  builder stood on the middle of the work: in the game as it is played,
  eighteen days, 102 serf-seconds making ground ready with a block in its
  own block column at its feet (one or two blocks deep), and none with the
  rule there or at five other stockyards
  (`colony_run --builder-stats`: "in the ground"). What grows on the site is cut; a
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

## The storehouse

The stockpile's second pass (2026-11-17; why and when it is asked for:
`colony.md`, "The storehouse"; his words whole: the brief and
`docs/handoffs/Handoff_2026_11_17_storehouse.md`). **It is a house of
another kind** (`Castle.Buildings.Building_Kind`: `Hovel`, `Storehouse`;
`House.Kind`), so everything of a hovel's building is its: the site found
by `Try_Lot`, its ground levelled and walled as a hovel's, its blueprint
laid from the stores by a builder, ladders at its eaves. What differs:

* **Its design is fixed** (`Storehouse_Design`, not drawn from a seed):
  `Store_W_B` by `Store_D_B` (5 m by 10 m), the ridge along its length,
  its door of `Store_Door_W_B` (2 m) in the end toward the path, a floor
  of plank (`House.Floor`: a hovel's is beaten earth), no windows.
* **Its yard is the stockpile's lot** (`Yard_U0` to `Yard_V1`, in the
  house's own frame, the front `Store_Yard_B` before the door), laid in
  the blueprint after the roof's trimming, so built after the storehouse
  (`House_Phase` `Yard`): the lot's ground beaten (`Beaten`, a footpath
  block where the ground is grass or earth, plants over it cut), a fence of
  logs on its outer line (`Fence`: a post of `Fence_H_B` every
  `Fence_Post_B` blocks, two rails between) from the gateway round, the
  gateway before the door (two posts `Gate_Post_H_B` high either side of
  an opening as wide as the door, a plank across their tops: no leaf),
  and the coverings along the back beside the storehouse (`Cover`: thatch
  on four posts, `Cover_W_B` along the fence by `Cover_D_B` deep, its
  front `Cover_Front_H_B` high and its back `Cover_Back_H_B`, as many as
  fit, at most `Max_Covers`: two on a lot of 15 m). **The yard is laid on
  the ground as it lies** (`Lay_Bout` maps a yard block's height from the
  column's top when it is laid, `Top_By`), not on the storehouse's pad: a
  covering's posts go down to their own ground under a roof as high as its
  highest. A block of the yard that cannot be laid (no grass or earth to
  beat) is passed over and takes nothing.
* **What it takes** is counted from its blueprint as a hovel's is: the
  storehouse's wood (frame and plank) and straw, then the yard's wood
  (fence, gateway, posts) and straw (the coverings' thatch), in that order
  (`Next_Kind`); 18 logs and 43 sheaves on a lot of 15 m.
* **It is nobody's home**: no lot is drawn for it (`Draw_Owner`), housing
  counts hovels only (`Houses_Open`, the log's `housing:` line), and its
  sheet says "the storehouse" with what is being built.
* **Standing, it is fitted out and kept** (the third pass; `colony.md`,
  "The storehouse used"): its stockpile's places inside it on the floor,
  shelves and barrels made by **a carpenter**, its builder: a forester that
  builds no house from then on, so its place among the builders
  (`Most_Builders`) is another forester's. Shelves and barrels are drawn
  (`Castle.Props.Shelf`, `Castle.Props.Barrel`), never blocks: the walking
  map goes through them, as through baskets.

### The storehouse on a stockyard (2026-11-18)

John's notes of 2026-11-17, after trying the storehouse ("Keep stockpile, move storehouse to a new
stockyard zone. Storehouse to be built with doors at each end of the building, the fence is to be
placed around the stockyard with the gates extending from the storehouse, inline with the inside wall
of the storehouse to the stockyard"; "level the stockyard, same as houses"; "Fell apple trees in the
stockyard"; "The newstockyard zone will make it easier to build the storehouse on angled paths").
**What is said above of where the storehouse stands and how it is fitted out is how it was.**
`docs/handoffs/Handoff_2026_11_18_playtest_round.md`; the zone itself is in `colony.md`.

- **Its design** (`Castle.Buildings.Storehouse_Design`): `Store_W_B` (10 m) along its front, the side
  toward the path, `Store_D_B` (5 m) back; its ridge along its length; a door `Store_Door_W_B` wide
  in the middle of each end (`Openings` 1 and 2, `Left` and `Right`), none in its front. A door is an
  opening from the floor up, on any wall: the blueprint gives each one jambs, a lintel and a
  threshold (it gave them to the first opening, in the front wall).
- **Where** (`Place_Storehouse`): in the middle of the lot's front, its left wall on the last block of a
  place so that whole places lie inside it (nine along, four deep), its front wall `Store_Yard_B` back
  from the lot's front.
- **Its yard in the blueprint**: the ground beaten; the fence round the yard behind it, from the left
  gateway's post out to the side, back, along the back, forward and in to the right gateway's post;
  **a gateway beside each end, from its corner out, in the line of its back wall** (`Store_Gate_W_B`,
  a post at its far side raised to `Gate_Post_H_B`, a plank across; the eave's end is over the block
  nearest the wall); the coverings side by side along the back, on the lot's whole metres.
- **Its ground is all its lot** (`Yard_Site`; `Apron_L`, `Apron_R`, `V_Hi`, `Lot_Left`, `Lot_Right`,
  `Lot_Back` take a storehouse's from its yard): chosen, read and worked by the routines a hovel's is
  (`Check_Lot`, `Choose_Pad`, `Front_Yard`, `Site_Patches`, `Level_Column`, `Wall_Patch`), walled with
  stone where the land beside it stands more than a block over or under. Its fall may be `Yard_Fall_B`
  (3 m) from end to end. `Set_Yard_Level`, `--no-yard-level`: its own pad and the bank round it alone.
- **Its way in** is the middle of its front (`Way_Lo`, `Way_Hi`: a hovel's is its door's columns;
  `Store_Way_U` puts a storehouse's on two whole patches of its ground), found by `Door_Way` as far out
  as `Front_Most`; its floor lies within `Yard_Step_B` (2 m) of the path where the way meets it, a stair
  between them as a hovel's door has.
  **Since the evening of 2026-11-21 a stockyard's stair stands in a corner of the zone** (John: "I was
  talking about the stockyard having the stair in the corner rather than the middle"; the spec, "The
  stockyard's stair in a corner of the zone"; `Set_Yard_Stair_Corner`, `--yard-stair-middle` is as it
  was). The floor's level is judged by the way at the middle of the front as ever; where that way would
  have steps, `Choose_Way_End` puts the way in at an end of the stockyard's front (`House.Way_End`):
  two metres, a block column in from the side's rim, a block a step from the path's edge inward
  (`End_Steps`), on past the front wall's line beside the storehouse's end if the flight is longer than
  the staging is deep. The end away from one where the path comes in level; of two banked ends the
  lower; none where an end is level and no end takes a stair. `Way_Lo` and `Way_Hi` are that way;
  `Mid_Lo` and `Mid_Hi` are the middle of the storehouse's front, which the cart, the ladder and a
  razing go by still.
  **Since 2026-11-22 its floor lies at its path's level at the lower corner of its front** (John: "Set
  the floors level of the stockyard to the path level at the lower corner, the higher corner along the
  path gets the stairs"; `Set_Yard_Floor_Low`, `--yard-floor-by-land` is the paragraph above alone):
  `Floor_By_Path` in `Try_Lot` reads the path at the front's two ends and at the middle of the
  storehouse's front (`Path_At`: the path's own nearest block column, the middle one of the way's
  eight), sets `Pad` by the lower end and puts the way in at the higher end where the path stands two
  to eight blocks over the floor there (over eight: no stair, the level end), at the middle where all
  three lie within a block. `Door_Row` is the row the floor was set against. A floor can stand over the
  land it is put on (filled; walls of stone hold it up), which no house's pad did before.
- **Its rows are worked there and back** (2026-11-23, his "they walk back and fourth like a typewriter
  instead of a zigzag"; `Set_Zigzag`, `--no-zigzag`, not saved): the rows of that order are a metre deep,
  and within a row the square metre nearest to where its builder stands is next, so a row is begun where
  the last one ended. Each row used to be begun at the same end (equal distances went by the patch's
  number) and its builder walked the row's length back. Counted at six stockyards, eighteen days each,
  the storehouse's ground alone (the build gated on 2026-11-23, one builder a house): one square metre
  lay 3.2 to 6.3 m from the one before on the average (77 to 247 of some 290 to 550 more than 3 m
  off), and 1.4 to 1.8 m now (13 to 40 of some 260 to 510); the walk to a square metre 3.7 to 6.5 m,
  now 1.8 to 2.5 (`colony_run --builder-stats`). With helpers at the same floor, 1.7 to 2.9 m ("Three
  at one floor", above). The order of the rows is as
  it was. A stockyard whose way in is at the middle of its front has two arms to a row, and its builder
  crosses from one to the other once a row.
- **It is dug in the order it is walked when all is made** (`Yard_Order`, in `Go_Level`): down the stair
  of the way in from the path, then outward over the floor from the stair's foot. **A hovel's rows from
  the path would leave its builder in a pit**: a stockyard's staging is 4.5 m deep and more, and beside
  a path aslant up a hillside its far corner, dug first, lay 2 m under the path and under everything
  round it (found on the reference site with the debug build; `tools/stockyard_sites.sh` runs the two
  sites it was found on and fails on anyone starving).
- **What stands on it is cleared**: its trees are felled by its builder before its ground is touched
  (`Go_Fell_Yard`, from `Think_House`: whatever their kind and whatever the order to spare apple trees;
  the logs are its own to carry home, as any tree's it fells); a stump, a bush, what hangs over the yard
  of a tree beside it go with the ground (`Stands_Over`, `Level_Column`), a boulder as ground does.
- **Fitted out** (`Fit_Storehouse`): inside, columns along its length and rows from its front wall: the
  two middle places by each door kept clear (`Kept_Clear`: no place at all), a barrel in each corner and
  the place beside it along the front and the back wall (the two back corners' for water), a shelf's
  `Shelf_Places` in the middle of the front wall and of the back, the rest floor. In the yard: `Cover`
  under the coverings, `Lean` in the row behind its back wall (a ladder each, against the wall's
  outside: `Fit_Wall`), the rest ordinary places, open now. The staging, the ground beside its ends and
  the row its back wall and the gateways stand in are `Kept_Clear`.
- **The cart** is brought to the staging beside the middle of the storehouse's front (`Cart_Front`;
  where the way in was, and is unless it has steps).
- **A storehouse whose yard is being laid is opened by the camera** as one that stands is (the game's
  `Follow_Roofs` offers the `Yard` phase).
- Limits that grew for it: `Max_House_Blocks` 24,576 (the largest stockyard's blueprint is 15,088),
  `Max_Site_Patches` 1,134 (`Patch_Bands` 42: a patch number is not what it was, so a save of the build
  before is refused), ladders' fail memos from 21,400.

### A stockyard along a path at 45 degrees (2026-11-20)

John, of three ways put to him: "Ok go on with the second way for the stockyard"
(`docs/handoffs/Handoff_2026_11_20_stockyard_along_a_path.md`). `Set_Yard_Turn`, `--no-yard-turn`: off,
a stockyard is square to the grid beside any path, as above. Saved (blob 39).

- **The lot lies along the path**: `Plan_Stockyard_Lot`, where the path nearest its two corners runs at
  45 degrees, takes the whole metres the corners span along and across the path's way (`Way_Of_Path`,
  `Plan_Lot` as a stockpile's), 15 m to 25 m each way, every place of it or none. The two corners are
  opposite corners of the lot: two straight along the path's way, or straight across it, are a strip a
  metre wide (`tools/yard_corners.py` works corners out for a script).
- **The storehouse's own blocks stand square to the grid, and are drawn turned an eighth**
  (`Place_Storehouse_Turned`; `Castle.Buildings.Yard_Turned`: a storehouse with `Turn /= 0`). It stands
  with its middle on the block corner nearest where its middle is to be drawn, and is turned about the
  point (`House.Piv_U`, `Piv_V`, near its middle) that carries its walls, as drawn, onto its places'
  lines: its left wall on the last block of a place, its front wall `Store_Yard_B` back from the lot's
  front, as a square one's.
- **Its frame and its design.** Its *frame* (`H_X`, `H_U`, `H_Point`) is where its own blocks are.
  Everything else of it is *designed* in that frame exactly as a square stockyard's is (`Yard_U0` ..,
  `Front`, the way in, the gateways, the coverings, a place's fitting) and made where the turn puts it:
  the design's place (U, V) at `Fore_Turn (U, V)`. `Design_Of` (the colony's `D_U`, `D_V`) says which
  place of the design a column of the frame is made as. Every column has one; a place of the design has
  one column, two or none. **So a piece of ground is gone over by the frame's columns and asked of the
  design** (`In_Site`, `Level_Of`, `In_Door_Way`, `Is_Stair`, `Patch_Of`; `Site_U_Lo` .. are the frame's
  box of it), and a line or a spot goes from the design to the world (`Y_Point`, `Y_X`, `Y_Y`). With no
  turn the two are one, and a square stockyard's code is the same code.
- **What is made for real, block by block**: its ground at its floor's level, walled in stone where
  the land beside stands over or under; the stair of its way in, its treads lying across the way as
  the design has them (so aslant on the grid); its yard beaten; **its fence and its gateways' planks,
  a line of columns each beside the one before** (`Add_Col`: where two of the design's fall corner to
  corner on the grid the column between is added, or a body would pass); its coverings, each column at
  the height its place in the covering has (their edges stepped). A fence at 45 degrees has more blocks
  in it: a 16 m yard takes 21 logs for a square one's 19.
- **Nothing of the yard stands among the storehouse's own blocks** (they are drawn turned: it would be
  seen elsewhere). `Yard_Clashes` counts what would, and a stockyard is taken only where it is nought
  (every size from 15 m to 25 m is: `colony_check`). The end of each gateway's plank, under the eave,
  is laid in the frame as one of the storehouse's own blocks, and so is drawn at its corner as drawn.
- **The feet go by the storehouse as it is drawn, once its walls and roof are up** (`Walked_Drawn`:
  its blocks laid as far as its roof's trimming; `Walk_Drawn` tells `Castle.Nav.Set_Drawn`; `routes.md`).
  Its walls as drawn are walls, its two doorways as drawn the ways in, and where its blocks stand is
  walked as the yard it looks like. So its places inside are within it as drawn, whoever is in it is
  where they are seen, and it has no hidden square: its doors are in its ends, 10 m apart, and no point
  to turn it about holds both (drawn through the turn, as a hovel's people are, whoever walked in would
  have jumped 4 m). While its frame, walls and roof go up its builder works at the blocks and is drawn
  through the turn (`House_View.People_Turned`), eased over 6 m beyond where it works (the game's
  `Ease_M`).
- **Fitted out as a square one**: `Fit_Storehouse` takes each place's square in the design (four
  blocks each way about its middle); a 16 m yard has 18 places of floor, 6 of shelf, 6 and 2 barrels,
  24 under the coverings, 9 against the wall, 63 of the yard, 128 kept clear, either way it lies.
- **The instant build** (`Raise_Now`) lays such a yard by `Yard_Row`, as `Step_House` does (on the
  ground as it lies); a square one's is written as drawn up, as before.
- The rule for the fall is the stockyard's own (3 m from end to end, `Yard_Fall_B`), taken over the lot
  as it lies. Limits: the largest's blueprint is 15,550 blocks.


### Turned hovels walked where they are drawn; a stockyard's pieces (2026-11-20)

His word: "Let's do that, and what do you think about turning the fence too? The outdoor roof
covering needs a smoothing pass." (`Handoff_2026_11_20_walked_hovels_and_yard_pieces.md`.)

- **A hovel placed turned is walked where it is drawn** (`Set_Hovel_Walk`, `--no-hovel-walk`;
  `House.Walk`, fixed when it is placed, saved in its turn's byte): once its walls and roof are up
  the walking map goes by it as drawn (`routes.md`, "A building walked where it is drawn"): its
  walls as drawn slow the feet to a hundredth (they do not shut: on hillsides that made pits), its
  doorway is held open, the square its blocks stand on is walked as the turf it looks. Its bed is
  in it as drawn (`Bed_Place`; `House_Inward` for the way a sleeper faces), nobody in it is drawn
  through its turn (but its builder while it goes up), and nothing is kept off it. A hovel of an
  older blob stays walked as it stands.
- **A covering's roof is smoothed** (`Set_Smooth_Covers`, `--no-smooth-covers`; `House.Smooth_Covers`,
  said when a storehouse is begun): the blueprint's last stage, `Smooth`, is each covering's thatch
  again, a row at a time from its front, laid with the state `Castle.Blocks.Piece` (work alone: the
  builder "smoothing the coverings' roofs by the storehouse"). A smoothed row is left out of what
  the land draws and drawn as part of one plane from the covering's front edge to its back, a
  rounded edge all round but where two coverings meet (`rendering.md`, "A stockyard's pieces").
  Every stockyard's, square ones too. **Since his answer of the same day** ("connect the rounded edges
  together along the length, and texture the roof of the outdoor storage the same as all the other
  roofs, that is the defult for all thatch roofs"): the rounded edge is one roll from corner to corner
  (its pieces lap 15 cm into one another, every second a hair narrower so that none shows through its
  neighbour), and the roof's texels are the land's own for a block of thatch, a variant a block
  (`Castle.Props.Cover_Thatch`; the game's `--no-cover-thatch`: as it was drawn). It is still a
  piece lit as the cart and the barrels are, and one even plane: a covering falls a quarter block a
  block, where a dressed roof's block falls a whole one.
- **A turned stockyard's fence in pieces** (`Set_Fence_Pieces`, `--no-fence-pieces`;
  `House.Fence_Pieces`): its rails and the planks over its gateways are laid as pieces and drawn
  straight from post to post, and from a gateway's post to the storehouse's corner as drawn. Its posts
  stay columns of blocks where they are laid. The pieces' blocks stay where they are laid: the feet,
  a ray, water and a save meet them as ever.
- `Castle.Colony.Yard_Pieces` is what is drawn (kept per house until its place or its count of
  blocks laid changes, and not kept while its ground is not yet in). `colony_run --turn-stats` says
  it for each storehouse.

### The storehouse twelve metres by eight, a metre and a half from its path (2026-11-21)

His words: "bring the storehouse forward 3m towards the path so that the fenced area becomes 3m deeper
, add 2m to the width of the storehouse, so that it is now 8x12." Read as the result he names: the
storehouse of before (10 m along its front, 5 m back) with his 2 m and his 3 m, its front wall 3 m
nearer its path and its back wall where it was. **So the fenced yard is as deep as it was** (the
fence and the gateways stand in the back wall's line: 10.5 m of a stockyard of 20 behind it, with the
storehouse of before and with this one; 5 m more than the least stockyard of before had, by the
larger zone alone). His "so that the fenced area becomes 3m deeper" and his "8x12" cannot both be had
on 20 m: 1.5 + 8 + 10.5. A storehouse 5 m back brought forward gives the 13.5 m (`--storehouse 12 5
1.5`). Put to him as his call. (`Handoff_2026_11_21_square_thirteen_and_stockyard_twenty.md`.)

- **Its size is the colony's setting, and a storehouse keeps what it was begun with**
  (`Castle.Colony.Set_Store_Size (Long_B, Deep_B, Staging_B)`, in blocks; `--storehouse LONG DEEP
  STAGING`, in metres: 12 8 1.5 unless told, `--storehouse 10 5 4.5` is the storehouse of before; not
  saved: it speaks of the next one). `Castle.Buildings.Storehouse_Design (W, D)` makes it at any size
  of whole metres, its two doors in the middle of its ends. Its walls are saved with it (blob 44, a
  byte each after its kind); a storehouse of an older blob is 40 by 20 blocks.
- **Beside a path at 45 degrees it stands 3.5 m from the path, not 1.5** (`Store_Turned`): its own
  blocks stand square to the grid about its middle and are drawn turned, so a corner of them reaches
  (W + D) / 2 x 0.707 blocks toward the path, further than the front wall is drawn; nearer than 14
  blocks a corner stood across the path (28 block columns of it with 6). The staging there is what
  keeps every one of its own blocks on its stockyard's ground, for either size, and the plan refuses
  a place where one would not be (`Storehouse_Lie`'s `Own_Out`, `Own_On_Path`; `colony_run
  --box-stats` says "0 block columns its own blocks stand in are not its stockyard's").
- **How it lies on a stockyard put down whole** (`colony_run --box-stats`): squarely 1.5 m of ground
  before its front wall to its path's edge, 10.5 m of yard behind its back wall, 3.75 and 4.25 m
  beside its ends; along a path at 45 degrees 3.5 m (to 3.75 where its ground is stepped), 8.5 m
  behind, the same beside. Inside, seven places by eleven: 57 on its floor, 8 barrels, 6 shelves, 6
  kept clear before its doors (`Fit_Storehouse`: a place is kept clear only where it lies before a
  door, now that the ends are wider than the doors).
- **What it takes**: 15,054 to 15,263 blocks in its blueprint on a stockyard of 20 m (19,307 on the
  largest of two corners; the ceiling is 24,576), 33 to 35 logs and 78 to 79 sheaves, where the
  storehouse of before took 11,952 to 12,123 blocks, 21 to 24 logs and 47 sheaves. It is in use two
  days later (10.1 to 10.5 days after the founding for 8.1 to 8.2).
- **Where it does not go.** A place whose floor would lie too far off its path's level for three
  steps (the hillside sites of `tools/stockyard_sites.sh`: refused when the stockyard is put down,
  "it falls more than 3 m, or lies too far off its path's level"), and the two stockyards of two
  corners along a path at 45 degrees in that script that are 15.4 m and 14.4 m a side (the largest,
  24.4 m, takes it; two of 16 m squarely take it too). Of 1,292 sides of the ten places' squares 828
  take a stockyard of 20 m with it, where 845 took one with the storehouse of before (426 for 442
  squarely, 402 for 403 aslant).
- **The lord's cart's place before it is looked for** (`Cart_Front`; `Set_Cart_Search`,
  `--one-cart-place` is the one place of before; not saved). It was one place: across the staging,
  hard by the way in, on the wider side of the yard. Where the bed did not fit there (a bank beside
  it, a stair, the storehouse's own blocks at 45 degrees) the cart was never brought and its salt
  stayed in it: at four of the nine test stockyards, older than this pass. Now the old place first,
  then along the front (which 1.5 m of staging has room for), the other side of the way in, and
  further from the way a metre at a time: the first that takes the bed. With the storehouse of
  before and the search on, the cart is brought and its salt carried in at all nine.
- **With `--storehouse 10 5 4.5 --one-cart-place` everything is as it was**: the nine sites' logs
  are 82fa10b's line for line, and twenty-seven saves of the builds before (two corners and boxes,
  not begun, half built, standing) run on to the same logs (in the commit of the size itself; since
  the lot's timbers are given back on load, the four of them with lots still to begin run on to
  houses with their timbers, and so to other logs). A stockyard of an older save that is not
  yet begun and that the larger storehouse does not fit gets none (the advisor's note says its ground
  will no longer take one): there is no save compatibility during production.

### Food and full barrels stacked in the storehouse (2026-11-21)

His words: "Allow food and full barrels to be stacked in the storehouse." (`Set_Store_Stacks`,
`--no-store-stacks` is as before; held off in both `Reset`s; not saved.)

- **A place on the storehouse's floor holds its baskets of food three high** (`Floor_Stack`; berries,
  apples, vegetables, grain: 360 berries for 120; salt, the yard's places and the places under the
  coverings as they were). `Place_Limit` alone says so: **the stockman still puts a load in the
  nearest place that keeps it**, so with a higher place the food stands in fewer of them (600
  berries in 3 places for 5). Drawn a tier to a place's own worth, four baskets a tier, each tier
  20 cm over the one below (`Castle.Props.Basket_Tall`); the first tier is drawn as it always was.
- **A barrel that is full has a second barrel stood on it** (`Barrel_Stack` 2; `Cell_View.Second`):
  the carpenter makes it there, a log and a barrel's work, after the shelves and every place's first
  barrel (`Next_Fitting`, `Wants_Second`: its first holds a barrel's worth, counted by what is in it,
  not what is on its way). The place holds two barrels' worth from then on (120 lb of meat, 24 pails).
  The lower one is drawn shut, the upper one as a single barrel is (open and full of water once more
  than the lower one's worth is in). A second barrel that stands, stands, whatever the switch says
  later. Saved as 2 in its place's byte for its barrel (blob 44 still, as the square's strips went
  into spare bits; a blob written before has 0 or 1 there).
- **How high are first values of mine, his calls** (three baskets, 65 cm; two barrels, 1.6 m).
- **What it does** (fifty days at three stockyards, on against off): the floor was never more than a
  third in use before (at most 14, 17 and 19 of its 57 places held food at once), so stacking does
  not let the band keep more food, it puts it in fewer places (at most five places stacked at once
  over thirty days at one of them). **The barrels are where it adds room**: all six meat barrels were
  full at once for two fifths of the time at one site; with the stacks 5, 3 and 4 of the six stand
  two high at the end and 645, 534 and 570 lb of meat are kept for 319, 336 and 360; both water
  barrels stand two high (48 pails for 24). Hungry serf-hours 1,003, 1,276 and 1,237 for 1,016,
  1,216 and 1,445; nobody died either way (member-hours with an empty belly, of every
  member at every hourly look: 6, 44 and 8 against 16, 4 and 6: no one way).
- **With `--no-store-stacks` the build is the build before**: the nine sites with the new storehouse
  and with the old, and 62 saves taken half way, end in the same states (the blob is not changed, so
  the states compare).

## What a house is made of since 2026-11-19

John's notes of 2026-11-17, built in the pass of 2026-11-19 (`docs/handoffs/Handoff_2026_11_19_next_pass.md`).
A house keeps how it was begun (`Castle.Buildings.House.Truss`, `.Sill`, set by the colony when it
begins one and saved with it), so a house begun before stays as it is.

- **A window's timber** (`Set_Window_Timber`, `--no-window-timber`). "Fix floating timber for windows on
  houses, make the timber extend the length of the timber columns it sit's inside. Change the color of
  the first fraction of blocks around the window, like planks as trim." The sill runs from the post on
  the window's one side to the post on its other, a lintel over it the same, and the block to either
  side of the opening is plank. Whole blocks: a trim thinner than a block would be a drawing.
- **The roof's timbers** (`Set_Roof_Timbers`, `--no-roof-timbers`). "Add timber truss the the ends of the
  houses and cross member support to the sides of the houses perpendicular to the door, add trusses,
  ridge beam, and cross member support for the storehouse." In each gable end a king post from the
  wall's beam up, and a rafter two blocks deep under each slope, a block under the gable's trimmed top;
  tie beams at the beam's row from eave wall to eave wall, about every `Tie_B` (2 m) of the house's
  length; in a storehouse a king post and rafters on each tie beam and a ridge beam from gable to
  gable. All of stage `Trim`: raised with the frame, before any daub. A hovel takes 77 to 122 blocks of
  timber more (a log makes 96; five logs at the most, as before), the storehouse 260. A tie beam is
  2 m or 2.25 m over the floor: walked under.
- The blueprint is otherwise block for block what it was (four hundred hovels and the storehouse
  compared, `colony_check`).
- **The truss to the ends of its wall, the same either side of its middle** (2026-11-23;
  `CB.House.Full`, `Set_Full_Truss`, `--no-full-truss`; a house keeps it, saved with the colony: blob
  45). "can we extend the truss to the end of the wall? make it symmetrical, either add another support
  if the length is even?" A gable's rafters met the wall's top beam three blocks in from either
  corner, and its king post stood at the lower of the two middle places where the span is an even
  number of blocks (188 of four hundred hovels; the storehouse, 20 and 32 across). Now the line of
  each rafter goes on down through the wall's top corner to its corner post (`Brace_At`: three blocks
  of timber where there was daub, at either end of each gable; never in an opening or where the wall
  has timber or plank of its own), and an even span has two king posts side by side, in its gables and
  on a storehouse's tie beams, and two ridge beams (`Is_King`). Twelve blocks of timber more for an odd
  span, 41 to 47 for an even one, 84 for the storehouse of 40 by 20. Over the wall's top beam every
  gable's timber is the same either side of its middle (`colony_check`, four hundred hovels).
- Since his answers of the same day: **a hovel has a ridge beam too** (`CB.House.Ridge`; "eh, go ahead
  and add a ridge beam to the hovels"), and **the wall beside a window is daub again**, with a thin
  trim of plank drawn up each side of the opening and across its top (`CB.House.Jambs` false;
  `Window_At`, `Castle.Props.Window_Trim`; "Thin trim around the tops and side(s)"). The trim is drawn
  on every house's windows; a house begun with plank blocks there keeps them.
- **The stockyard's gateways have leaves** ("yeah add the leafs on the gateways"): two of rails in
  each, hung once its post is raised, swung into the yard while anyone or the cart is near
  (`Gateway_At`, `Castle.Props.Gate_Leaf`). Drawn only.
- **Doors** are drawn, not built: a leaf of planks in each doorway of a house whose walls stand, two
  in a storehouse's doorways, swung in while anyone is within 1.3 m (`Doorway_At`; the game's
  `Show_Doors`, `--no-doors`). The stockyard's gateways have none.

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

- `--no-build-help`: one builder a house, as before 2026-11-23 (not saved; held off in the reference
  runs and `colony_check`'s `Reset`). `--no-full-truss`: a house begun from now on has the truss of
  before (saved with the colony).
- `--no-paths-meet`: a path is left half a metre off the trodden ground it meets; `--no-door-meet`: a
  door's way is left as it was planned when its hovel was placed; both as before 2026-11-23. Neither
  is saved; the reference runs, `stress.sh`, `look_cost.sh` and `colony_check`'s `Reset` hold both off.
- `--no-reach-out`: a builder stands on the square metre of ground it makes ready, as before
  2026-11-23. `--no-zigzag`: a storehouse's ground is worked every row from the same end, likewise.
  Neither is saved; the reference runs, `stress.sh`, `look_cost.sh` and `colony_check`'s `Reset` hold
  both off.
- `--no-hovel-walk`: a hovel placed turned is walked as it stands (its people drawn through its turn,
  the ground it is drawn on kept off), as before 2026-11-20. Saved.
- `--no-smooth-covers`, `--no-fence-pieces`: a storehouse begun from now on has its coverings' roofs
  left stepped, and (along a path at 45 degrees) its fence laid and drawn stepped, as before
  2026-11-20. Saved.
- `--no-cover-thatch` (the game's, drawing only): a covering's smoothed roof with texels of its own
  and its rounded edge a metre at a time, as first drawn.
- `--stockpile-box X Y WAY`: a stockpile put down whole with its path, as the player's tool puts it;
  `--housing-pull X0 Y0 X1 Y1 ROWS`: housing pulled with its path from the first point to the second,
  as the player's tool pulls it (ROWS 0: the side it was begun on, 1: the other, 2: both);
  `--no-housing-pull`: the player's tool the strip beside a path that is there (`--housing` is that
  strip, always).
  `--no-box-place`: the player's stockpile zoned corner to corner. `--square X Y WAY`: the colony
  founded on a square, the homestake and the campfire one; `--no-square`: the player's homestake the
  post, the camp apart (`colony.md`). Both `--no-` switches are set where they are read, so a colony
  the player founds by hand in that game has them too. The runner's `--square-census R STEP` and
  `--square-scan R STEP` (`colony.md`) count where a square can be founded and look every one
  founded over for pits; `--box-stats` says, of a square, how its floor, its hearth and its path
  stand (at the start, as loaded, and at the end).

(The windows' trim is on the wall's inner face too since 2026-11-19, "inside the house too".)

(A hovel beside a path at 45 degrees is turned to it since 2026-11-19: `House.Turn`, set by `Place_House`
from the path nearest its doorway, `--no-house-turn`. Drawing only: the house stands square on the grid
for everything the colony does; `rendering.md`, "A building drawn turned". **Its ground is made where
it is drawn as well** (`House.Turn_Ground`, `Set_Turn_Ground`, `--no-turn-ground`): the block columns
under it as drawn, and two round, are of its site (levelled to its pad, cleared, walled) and of its
lot; its floor of beaten earth is laid under it as drawn, its threshold under its doorway as drawn,
and the square it stands on keeps its turf; its door's way is trodden square to the path where there
is no stair; it reaches its ground to no neighbour's. The fall of the ground (2 m at the most) is
taken under its walls as they stand, as a square house's is, so a turned hovel is placed wherever a
square one would be, and its ground is made under it as drawn however far the land falls there
(his word of 2026-11-19: "they need to be able to place diagonals on hillsides if they want to";
`Set_Turn_Fall`, `--turn-fall`, for the rule of some hours before, under its walls as drawn too).
Its floor's edge is drawn stepped by the texel, under its walls (`rendering.md`). Who walks keeps off the ground a standing
one is drawn on (`Set_Keep_Off`, `--no-keep-off`; `routes.md`). `colony_run --turn-stats`,
`tools/turned_streets.sh`.)

(Since 2026-11-20: `--no-yard-turn`: a stockyard beside a path at 45 degrees is square to the grid, as
before that day; on, the default, it is laid out along the path, its storehouse drawn turned and
walked where it is drawn ("A stockyard along a path at 45 degrees", above). `colony_run --turn-stats`
says its ground and who walked where; `tools/stockyard_sites.sh` has three such; `tools/yard_corners.py`
works out the two corners for a script.)

(Since 2026-11-19: `--no-roof-timbers`, `--no-window-timber` (a house is begun as before that day),
`--no-path-level`, `--no-make-way`; the game's own `--no-doors`, `--no-wheel-roll`, `--no-full-thatch`,
and for stills `--doors-open`, `--wheel-turn R`.)

`--housing X0 Y0 X1 Y1` (a housing zone, up to 8), `--housing-inside X Y`
(all the ground inside the paths round that point, up to 8), `--homes-built` (a
hovel for everyone the zones have room for, built on the spot and drawn
for, as `--camp-built` builds the camp), `--no-beds` (nobody makes itself
a bed: the band as it was, which the seven older reference logs are run
with), `--no-ladders` (every roof thatched from the ground, as before the
pass's fourth round), `--no-storehouse` (none asked for on the second
morning), `--builders N` (at most N builders at once, 4 unless set; 0: no
limit), `--no-stockman`, `--no-carpenter`, `--no-water` (the storehouse
standing and nobody using it). `colony_run --no-memos` also turns off what housing keeps only to
save work (a blueprint drawn once while it is the one in hand): a run
must end the same either way, and `tools/stress.sh runner` proves it.

## Tunables

At the top of `castle-buildings.ads`: the hovel's sizes (`Min_Floor_B`,
`Min_Width_B`, `Max_Width_B`, `Max_Depth_B`, `Depth_Var_B`, `Wall_H_B`),
its openings and its frame (`Door_W_B`, `Door_H_B`, `Window_B`,
`Window_Up_B`, `Stud_B`), where it stands (`Setback_Min_B`,
`Setback_Max_B`, `Max_Push_B`, `Max_Step_B`, `Apron_B`, `Apron_Front_B`,
`Door_Landing_B`, `Lot_B`, `Max_Reach_B`); the storehouse's (`Store_W_B`,
`Store_D_B`, `Store_Door_W_B`, `Store_Yard_B`, `Fence_H_B`, `Fence_Post_B`,
`Gate_Post_H_B`, `Cover_W_B`, `Cover_D_B`, `Cover_Front_H_B`,
`Cover_Back_H_B`, `Max_Covers`; `Max_Long_B` 40, the longest side a
building may have). In `castle-colony.ads`, with `Zone_Housing`:
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

- Blob 44 (2026-11-21): with a storehouse, after its kind, its walls along its front and back from
  it, a byte each in blocks. Blobs 30 to 43 still read: a storehouse of theirs is 40 by 20.
- **A lot still to begin is saved as its place alone, and its house designed anew from its serial's
  seed on load: whatever is given a design after `Castle.Buildings.Design` must be given again
  there** (`Give_Timbers`, which `Place_House` and the loader both call). Until 2026-11-21 the
  loader left the roof's timbers, the windows' timber, the plank beside the windows and the ridge
  beam as the design alone has them, and every house begun after a load from a lot laid out before
  it was built as houses were before those passes. `Lot_Design` (for the checks) is a lot's house,
  whole: a check holds every lot the same design across a save.
- Blob 41 (2026-11-20): a byte with each storehouse after what it is turned about (1: its coverings'
  roofs smoothed, 2: its fence in pieces), and the two switches at the end. Blob 40: 8 in a house's
  turn byte if it is walked where it is drawn (only one whose ground is made there), and the switch at
  the end. Blobs 30 to 40 still read: their hovels walked as they stand, their stockyards as begun.

(Blob 39, 2026-11-20: with a storehouse, the point it is turned about, two numbers; at the end, whether a
stockyard beside a path at 45 degrees is laid out along it. Blobs of 30 to 38 are read: a stockyard of
theirs is as it was zoned.)

(Blob 32, his answers of 2026-11-19: with each house also whether plank stands beside its windows and
whether a hovel has a ridge beam; at the end who is set to building. Blobs of 30 and 31 are read: a
house of 31 has the plank and no ridge beam in a hovel, as it was begun.)

(Blob 31, 2026-11-19: with each house, after how far its ground reaches, whether it has its roof's
timbers, its windows' timber, and whether it is marked for razing; at the blob's end whether making way
and path levelling are on and how the next house is to be made. A blob of 30 is still read: its houses
without, the switches as a new colony's.)

Colony blob 26 (25 before the stockpile's first pass), after everything of 17: how many houses have ever been
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
(`colony.md`, "The lord's cart"). Blob 26 (the stockpile's passes): a
house's kind after its seed, and for a storehouse its yard (its four
bounds, the gateway's place, the coverings and where each stands); at the
end how many may be builders, then the rest of the first pass
(`colony.md`), then whether a storehouse is asked for, the stake's day,
whether it has been asked, the storehouse's house and each place's closed
flag. A house's
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
