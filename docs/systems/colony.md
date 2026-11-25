# The colony

- Packages: Castle.Colony, Castle.Actions, Castle.Scenario
- Source: `src/castle-colony.ads` (the tunables and capacities), `src/castle-colony.adb` (state, helpers, and a stub per larger subprogram: the index), `src/castle-colony-<name>.adb` (one subprogram each)
- Check: colony_check (1,110 checks on 2026-11-23); colony_run --expect for runs on the real world; tools/reference_check.sh; tools/today_check.sh (the game as it is played); the three site scripts
- Saves: the colony blob, version 46 on 2026-11-23, inside the game save (30 to 45 still read; 18 to 29 refused)
- Stage: stages 1 to 3, 4R, 5a to 5c, and the camp and zones work of 2026-11-10 (Handoff_2026_11_07_ui.md, _08_stage_2.md, _08_stage_3.md, _09_stage_4R_runner.md, _10_stage_5a_scaffold.md, _10_stage_5b_skills.md, _10_stage_5c_demand.md, _10_camp_and_zones.md, _10_paths_and_reach.md, _11_hands_and_level.md)

## The colony

`Castle.Colony` is the colony: the band, what each of them is doing and
carrying, the homestake, the paths, the stockpiles, the bushes they pick
and the trees they fell. It decides; `Castle.Serfs` only shows it. The
first loop is berries: paths make room for stockpiles, a stockpile makes
somewhere to bring things, a job makes someone go and get them. The second
is wood: a forester fells a tree and carries its logs home. Porters bring
in straw for the thatch, then stone as it is wanted; they never carry
wood.

* **The homestake.** Homestake in the tools panel, then a click on the
  ground (or "Raise the homestake here" in the ground's menu): a post
  1.75 m tall is raised there and the band (thirteen by default since
  2026-11-17, `Castle.Colony.Arrivals`: John, "So we need 13 starting
  serfs, basically the player begins by delegating the tasks, as we have
  done"; six before, and six in the reference runs and the stress test,
  `--band 6`) arrives round it, none assigned, each with a name of
  its own (twenty to a sex). Once per colony; the
  stake is the middle of everything that follows.
* **Paths.** The player plans a path and the band lays it (John,
  2026-11-10: "the path should work the same way, the player plans it the
  serfs build it"; first rules of mine, his to change). Path, then click
  along the way: each click marks a stretch 1 m wide from the last one; Esc
  ends the line, or "End the path" in the ground's menu. A right click on
  the ground offers "Path from here" too.
  * **Planned.** A stretch marked is a path from that moment for
    everything but walking: no zone takes its ground, zones are laid out
    along it (a stockpile can be zoned against a path not yet laid), a camp
    keeps its distance. It is shown as a pale strip (it dims at night, as a
    zone's fill does) until it is laid. The ground is grass still, and
    walked as grass.
  * **Laid.** The band lays it a metre at a time, as an extra task
    (below, "Extra tasks"), the camp's building first. A metre takes 4 s
    at a rate of 1 (`Tamp_S`, `Site_Work`): what grows on it is cut and the
    top of the ground turned to footpath, the metre all at once. Footpaths
    are 15 % quicker than grass, so routes take them where that pays, once
    they are laid.
  * **Holes filled** (John, 2026-11-13: "It would be nice if there was a
    way for serfs to fill in holes in the path when they are compacting
    the ground"; first rules of mine, his to change). A hole in the ground
    under a metre is filled with earth as the metre is laid, to the lowest
    of the ground round it, and the path laid over it (`Fill_Hollows` over
    the ground `Hollow_Reach_B`, ten columns, round the metre, in
    `Lay_Metre`: a hollow is ground at one level closed in on every side by
    higher ground, at most 64 columns, the same test a hovel's pad is
    levelled by: `habitation.md`). So a pit, a dent, a ditch closed at its
    ends; a step of a slope, its inside corner and a notch into it go on to
    lower ground and are no hollow, and a path goes up and down a hillside
    as it did. A column is raised only where the ground read round the
    metre is its own top, by a metre at most (`Hollow_Rise_B`), and only
    earth, turf and path are read as ground: a log or a bough a few rows
    over a hump is never taken for it. What was left growing over a hole is
    cut (`Cut_Plants`). The earth is
    the turf cut where the path is laid: nothing is carried for it. Only a
    metre the band lays (or `--paths-built` lays) is filled; with the band's
    labour off a path is laid the moment it is marked, as it was. None lies
    under the reference paths. `--no-path-holes` (`Set_Path_Holes
    (False)`) lays a path down into a hole, as it was; the seven older
    reference runs are held at it. Saved with the colony (blob 24).
  * **A stretch to a serf** (John, 2026-11-11: "for roads I suggest that
    when a serf starts compacting a road they are assigned a stretch, say
    20m for example"; first rules of mine, his to change). A path is kept
    as stretches of 20 m (`Path_Stretch_M`), the last what is left; a
    shorter click is a stretch of its own. Whoever starts on a path is
    given a stretch nobody has, the one with the least way to it, weighed
    toward the stake (so a path grows outward from it). It is that serf's
    alone, and it lays it from end to end; then it goes back to its own
    work, and may be given another when it next has empty hands and there
    is a place for it. Only after a short stretch does it go on to another
    nobody has, till it has laid 20 m. Leaving for anything else (to eat,
    to sleep, for the camp) gives the stretch up, and the next to turn to
    the paths takes it on. So a path takes as many serfs at once as it has
    stretches, and no more than the limit on extra hands allows. What
    cannot be got to (a stretch ending up on a ledge, the far bank of a
    river) pins nobody: it stays planned and is tried again every minute
    or so. On the check's meadow one serf lays a stretch of 20 m in 106
    game minutes; six with nothing else to do lay 58 m (three stretches,
    three of them at it) in 133; six gatherers lay the same, two at a
    time, in about five hours, gathering between turns.
    `Set_Stretches (False)` is the older way (anyone at the paths lays
    whichever metre is nearest, several to a stretch): the older reference
    logs run with it.
  * **Read from the ground.** Which metres are still to lay is not kept:
    it is read from the ground once a colony second (a block column within
    the stretch's width, no zone's, whose top is grass, dirt, sand, gravel
    or clay is still to turn). So a bit of a laid path dug up is found and
    laid again, and rock, water and tree trunks under a path are left as
    they are.
  * **Far ones.** The colony's ground reaches as far as any stretch still
    to lay (below, "Its ground"): a path planned 150 m out is walked to and
    laid (measured on seed 1 before stretches: 136 m east of the reference
    stockpile, 126 m of it on ground that takes a path, laid by two in the
    afternoon of the first day with the whole band at it; it is seven
    stretches now, two at a time).
  * Paths go round zones: a stretch whose line would run through zoned
    ground is refused whole ("a zone is in the way: paths go round zones")
    and the line carries on from where it had got to; one that only brushes
    a zone is laid beside it, and the zone keeps its ground.
  * `--paths-built` (`Build_Paths_Now`) lays what is planned on the spot,
    for a scripted start. With the band's labour off (`--no-labour`) a path
    is laid the moment it is marked, as it used to be.
  * Not there yet: taking a planned path back; paving; a say for the
    player in who lays which stretch.
* **Extra tasks: only so many hands** (John, 2026-11-11: "we should limit
  the amount of workers that can perform extra tasks"; the number and the
  exceptions are first rules of mine, his to change). An extra task is
  what the band does that is nobody's job: the camp's building, the paths'
  laying. At most a third of the living band, and at least one, are at
  them at once (`Extra_Share`; `Extra_Hands` is the limit now, `At_Extra`
  how many are at them): two of six. Whoever has a job turns to an extra
  task, when its hands are empty, only while fewer than that are at them;
  the rest go on with their work.
  * Someone with no job never waits for a place (it has nothing else to
    do), and counts as a hand whether it has got there yet or not: while
    the idle are enough, nobody leaves a job.
  * The camp's building is the cook's own work, not an extra task for it:
    the cook neither waits nor counts there. (At a path it is a hand like
    any other.)
  * A load already in hand for the camp is always carried there.
  * Who is at an extra task is read from what each is doing (at a patch of
    the camp's ground or a metre of path, on an errand for the hearth,
    carrying earth off the camp's floor, between two metres of its
    stretch): nothing is kept, so a place cannot be left held by someone
    who has gone to eat or to bed.
  * `Set_Extra_Hands (N)` sets the number (`--extra-hands N`; 0 is the
    rule again). There is no control for it in the game yet.
    `--all-hands` is extra tasks as they were before the limit (everyone
    before its job, and paths by the metre, not the stretch).
  * What it costs, on the reference run (measured again on generator 13,
    2026-11-11; one run's hours, which a hunt that goes otherwise moves):
    the hearth stands at a quarter to twelve (a quarter past nine with all
    hands and its floor left as it lies, as it was built first; half past
    eleven with only its floor left), and the first stew is cooked by
    three in the afternoon (a quarter to four with all hands and no
    levelling). Nobody goes to bed hungry the first night. The rest of
    the band gathers and hunts meanwhile. (On generator 12 the hearth
    stood at half past twelve, the 18 m path, one serf's, was laid by half
    past one, the first stew was cooked at a quarter to eight and three of
    the six went to bed hungry: what was gathered that afternoon was
    eaten raw before the cook had a pot of it, a matter of an hour either
    way. The camp's lot had 64 square metres to make ready then and has
    56 now, tall grass being thinner. When the path is laid was not
    measured again.)
* **Stockpiles.** Stockpile, then two corners: the lot between them, laid
  out the way every zone is (below): turned to lie along its path, drawn
  out to the path's edge, stopping at any path and any other zone. It has
  to come within a metre of a path's edge (`Snap_M`). Things are put down
  in places 1 m square, in rows along the lot, on its own whole metres;
  a place with a bush, a log or a stone on it, more than half a metre off
  level, or partly off the lot's ground is left out. Grass and grain on the
  places are cut so what is put there can be seen (the rest of its ground
  keeps its grass). A place holds one kind of thing, 120 handfuls of
  berries. What lies there lies the way the lot does. The tool shows the
  lot as it would be taken while the second corner is being chosen
  (`Plan_Stockpile`: the same routine the zoning runs), or its outline in
  red where it would be refused; why is said on the click
  (`Stockpile_Refusal`).
  * **At least 15 m by 15 m** (2026-11-17; John: "make the minimum zoning
    area 15x15m for the stockpile, it can be larger the workers will
    adapt, but that will fit the storehouse with the 5m of staging area at
    the front, the fence and coverings for the outdoor stocks"). The
    ground a lot fills (drawn out to its path) has to reach
    `Stockpile_Least_M` along its path and as far across it, measured by
    the middles of its block columns, a block and a half spared for a lot
    aslant the block grid; else "it is too small" (`Too_Small`), its
    outline red while it is drawn. A tree, a bush or a stone inside leaves
    its places out but not its size. `--stockpile-least M` (0: any size,
    as before; `Set_Stockpile_Least`, saved: blob 26).
  * **Its overflow** (the same day: "for the 5 blocks of overflow, if
    there is no space in the stockpile, just have them use 5 free blocks
    around the stockpile as an overflow to set things down so they arent
    carrything them everywhere, and then they won't collect anymore until
    space frees up"). Zoned with the overflow on, a stockpile gets up to
    `Overflow_Places` (5) places more, 1 m square on its lot's own whole
    metres in the ring just outside it, each wholly on free ground (no
    path's, no zone's, nothing on it but what grows and is cut, within
    half a metre of level), those nearest a path first: at the two ends
    of a lot beside its path. Their ground is the zone's (other zones and
    paths stop at it, it is outlined with the zone, and the zone's size
    counts it); they are its places, flagged (`Cell_View.Overflow`; the
    zone's sheet has a row "Overflow"). A load goes to an ordinary place
    while one takes it, and only then to an overflow place (`Go_Store`,
    the butchering's); scripted supplies never go there (`Supply`), nor
    does the lord's cart. What is taken out of the stores, to eat, to cook
    or to build, is taken from an overflow place first (`Go_Eat`,
    `Go_Take`), so it empties first. **Nobody sets out to bring in a kind
    without room for a whole load of it in an ordinary place**
    (`Room_For`: a porter, a hunter and a forester hauling already asked
    it, for one more; now for a load, and of an ordinary place); a
    gatherer and a porter also count the loads of that kind already being
    gathered (`Room_To_Set_Out`: without it four gatherers went for the
    last room and three came home to none). **The overflow is a signal**
    (his answer the same day: "So the overflow, signals to the serfs,
    don't carry anything else to the stockpile, they can go spend their
    leisure time at the campfire if they aren't doing anything else, if
    they are carylrying something put it in the overflow and do the same.
    When space opens up in the stockpile someone can move it from the
    overflow to the stockpile. And then once a spot opens up at the
    stockpile, people can go back to work."): while an overflow place
    holds anything or has a load coming (`Overflow_Busy`), nobody sets out
    to bring anything in, whatever its kind (`Room_For` is false for
    all). One with nothing to do for want of room (a gatherer, a porter,
    a hunter, a forester with logs to haul) moves a load out of the
    overflow into an ordinary place that has room for it
    (`Go_Clear_Overflow`, counting the loads already on their way), and
    otherwise spends its leisure about the camp, or the stake with no
    camp yet (`Wait_For_Room`: `Rest`), saying "the stockpiles are full".
    With the overflow empty and room again, it goes back to work. One that
    fends picks as before (it eats what it picks). What a serf does when
    the five are full too he has not said: it stands with its load as
    before (0.2 serf-hours in the runs measured: below). `--no-overflow`
    (`Set_Overflow (False)`, saved: blob 26): no overflow places, and a
    gatherer picks with nowhere to put it, as before.
  * **What was measured** (`colony_run --store-stats`, 41 days at the
    reference site, a band of thirteen with housing on both sides of a
    path west): on a stockpile of 15 m by 15 m no load ever found no
    place, with the overflow or without (45 of 222 places in use at the
    end). On one of 18 places (`--stockpile-least 0`, so that it fills)
    without the overflow the band stood 2,104 serf-hours with a load and
    nowhere to put it (berries most of it), with it none: 23 loads went to
    the overflow, and the band stood 844 serf-hours empty-handed for want
    of room instead. The crowd of forty-eight on the same 18 places, 20
    days: 245 serf-hours then none (19 loads to the overflow). Nobody died
    in any of them. With the overflow a signal and moved back (the same
    18 places): 0.2 serf-hours held; the overflow held something 135 of
    984 game hours, at most three places of it, 42 loads moved back into
    the stockpile, nothing in it at the end; the band stood 1,616
    serf-hours empty-handed for want of room (about the camp); the crowd
    630, its overflow busy 18 hours. Hides and earth leave the overflow
    the same way, when a place opens for them.
  * **The storehouse** (the stockpile's second pass, 2026-11-17; John:
    "On the second day, the advisor asks the player to zone more area, if
    the stockpile isn't big enough, to build the storehouse, the stockpile
    will then be "upgraded" if it meets the requirements, the builders will
    build a stockhouse, compact the land of the stockpile, build a fence
    with a gate, build coverings for outside materials, etc... Stockhouse
    gets a wood floor", "But we aren't doing the player and advisor thing
    just yet, so just simulate the request", "make the stockhouse some
    reasonable size, 5x10m same as the houses, but door is on the end of
    the warehouse, path to the door"). At `Store_Morning_H` (7 h) on the
    day after the stake's, the request is made (`Ask_Storehouse`, from
    `Advance`, once a colony second): the first stockpile whose places make
    a lot at least `Storehouse_Lot_M` (15 m) by as much, square to the
    block grid, with ground for the storehouse at one end
    (`Place_Storehouse`, by `Try_Lot` as a hovel's site is found), is
    upgraded; with none the request stands and is made again every game
    hour, so a stockpile zoned large enough later takes it within the hour.
    The advisor is a note (`Storehouse_Note`, its key `Storehouse_Note_Key`:
    the game says it at the foot of the screen when the key moves, the
    runner logs it as "advisor, day D at H h: ..."): "The storehouse goes on
    stockpile N: ..." or "A storehouse wants a stockpile of 15 m by 15 m
    ...: zone more ground". A stockpile is named by its number among the
    stockpiles (`Stockpile_Number`), the player seeing no zone's number.
    **The storehouse is a house of another kind** (`Castle.Buildings`:
    `Building_Kind`, `Storehouse_Design`; `habitation.md`, "The
    storehouse"): 5 m by 10 m at the end of the lot nearest the stake, its
    length running back from the path, its door of 2 m in the end toward
    the path, `Store_Yard_B` (4.5 m) of staging before it to the lot's
    front. **The places under it and before it are closed** (`Cell.Closed`,
    `Cell_View.Closed`): nothing is put there, what lies there is taken
    first (as from an overflow place), and its builder carries what is left
    there into the stockpile before its ground is made ready
    (`Go_Clear_Closed`). Then the builders raise it as they raise a hovel,
    from the stores, and its yard after (below); it is nobody's home and
    counts for nothing in housing. `--no-storehouse` (`Set_Storehouse
    (False)`, saved: blob 27, 28 since): none asked for, as before. The reference
    runs, the stress test and the look costs run with it off.
  * **What it cost the band** (41 and 50 days, the reference site, the
    band of thirteen with housing, 15 m by 15 m): asked at 7.0 h on the
    second morning (day 21), begun by one builder, standing five days on
    (18 logs, 43 sheaves); nobody died, six hovels stood by day 41 with it
    or without. **But the fence's one gate lengthens the band's walk**:
    its work lies south of the stockpile and the gate is on the north by
    the path, so every load from the south walks round. Over 50 days with
    it: 104,321 of stew cooked against 113,980 without the storehouse,
    18,099 berries eaten raw against 10,993, 2,181 hungry serf-hours
    against 1,116, confidence at its lowest 25 % against 59 % (the first
    winter); 26,955 routes planned in 41 days against 31,031 with no fence
    (fewer trips), 7.05 million floors looked at against 4.10 (longer
    ones). With the storehouse and no fence (a scratch build): 111,256 of
    stew, 1,262 hungry serf-hours, lowest 44 %. So the fence is most of
    the cost, the places closed the rest. A second gate is his call
    (`docs/handoffs/Handoff_2026_11_17_storehouse.md`); he set it aside
    for now ("we don't need to worry about travel distance right now or
    winter survival, just yet").
  * **The storehouse used** (the third pass, the same day;
    `docs/handoffs/Handoff_2026_11_17_storehouse_used.md`). When it
    stands its stockpile's places are fitted out (`Fit_Storehouse`;
    `Cell.Fit`, `Cell.Made`, `Cell_View.Fit`, `.Made`, `.Wall`): inside on
    its plank floor (the row by the door kept clear) a shelf of
    `Shelf_Places` along each long wall for hides, barrels in the two back
    rows (`Water_Barrels` for water, the rest for meat), the rest floor for
    baskets and sacks of salt (John: "they can just be stacked in the
    baskets in the storehouse by the stockman"); in the yard, the places
    under a covering (`Cover`, `Cover_Holds` times a place's own) and those
    along the outside of its long wall (`Lean`, a ladder each). **What a
    place takes is one test, as before** (`Takes`, now `Open_To` and
    `Room_In`, by `Place_Limit`): an ordinary place anything but water, a
    water barrel water; a place fitted out takes only what it is for
    (`For_Fit`) and only from the stockman (`Keeps`, in `Go_Store`); `Supply`
    only ordinary places. Anyone takes from any place. **The stockman**
    (`Choose_Keeper`, `Think_Keeper`, before a porter's work; `Is_Keeper`,
    `Trade_Of` = `As_Stockman`): the porter with the most portering; the
    overflow, the cart to the storehouse's front and its salt in
    (`Go_Tow_Front`, `Go_Unload`, `Cart_At_Storehouse`), then the yard
    sorted (`Go_Sort`: from an ordinary place, or one fitted out for
    something else, a load no larger than the room for it). `--no-stockman`.
    For development one can be named by hand (`Name_Stockman`, 2026-11-22:
    a porter, the stockman whatever its portering for as long as it lives
    and porters; named before the storehouse stands, its stockman from the
    moment it does: nobody is, and `Stockman` is 0, until then).
    **The carpenter** (`Choose_Carpenter`, `Think_Carpenter`, `Step_Fitting`,
    states `To_Fitting`, `Fitting_Out`, work `Joinery`; `As_Carpenter`): the
    storehouse's builder, else the free forester with the most building;
    no house; a log from the stores (`Free_For_Building`) to each shelf and
    barrel, made there (`Shelf_S`, `Barrel_S`); the logs in the stores'
    once rows (`Fittings_Left`). `--no-carpenter`. Named by hand likewise
    (`Name_Carpenter`: a forester; a house it was building is left to
    another builder, then or when the storehouse stands). **Water**: `Wanted`
    gives a porter water after straw and stone while the water barrels
    have room (`Room_To_Set_Out (Water)`). `--no-water`. Saved: blob 28.
    The runner logs who and when ("stockman, day D at H h: ...",
    "carpenter, ...") and what the storehouse holds on its `storehouse:`
    line. Measured: standing on day 25, its stockman and carpenter the same
    second, the cart at its front half an hour on, the fourteen shelves and
    barrels made in 43 hours; nobody died in 50 days.
  * **His playtest notes, 2026-11-17, built 2026-11-18**
    (`docs/handoffs/Handoff_2026_11_18_playtest_round.md` has the notes
    whole, each fault as it was reproduced, what was measured and his
    calls). **What is said above of the overflow, the 15 m and the
    storehouse on a stockpile is how it was; this is how it is.**
    - **The player's stockpile is placed once, ten metres square** ("a
      onetime placement of a 10x10 zone"): `Place_Stockpile (X, Y)`, one
      click beside a path (within `Square_Snap_M` of its middle): the
      square on the click's side of the nearest path, its front on the
      path's edge, on the whole metres of its lot (`Square_Of`), then
      zoned as any stockpile is; refused once a stockpile is zoned
      (`One_Stockpile`, `Stockpile_Count`; `Plan_Stockpile_At` for the
      preview). `Zone_Stockpile` (two corners, any size) is the scripts'
      and the checks'. No overflow unless `--overflow`; no least size
      unless `--stockpile-least`.
    - **The stores' last places are kept** ("use the last 10 blocks as a
      singal to the serfs to slow/cease production"): while the empty
      ordinary places (`Empty_Places`) are no more than `Kept_Places`
      (`Last_Places`, 10, and never more than a tenth of the ordinary
      places), `Ordinary_Loads` counts no empty place, so
      `Room_To_Set_Out` is true only of a kind that has a place of its own
      with room; `Room_For` (a load in hand or lying out) still takes any
      place. A gatherer, a porter, a hunter and a forester about to fell
      ask `Room_To_Set_Out`; held back, they say `Nearly_Full` ("the
      stockpile is nearly full: nothing more brought in") and rest
      (`Wait_For_Room`). One test says whether the band waits for room at
      all: `Room_Gated` (the overflow on, or places kept).
      `--last-places 0`: none kept, as before.
    - **The storehouse stands on a stockyard** ("Keep stockpile, move
      storehouse to a new stockyard zone"): a stockpile's zone marked as
      the yard (`Zone_Rec.Yard`, `Zone_View.Yard`, `Stockyard`):
      `Zone_Stockyard (X0, Y0, X1, Y1)`, a lot square to the block grid
      whatever way its path runs (`Plan_Stockyard_Lot`: `Plan_Lot` with
      `Clear_All`, which takes ground that things stand on), 15 m to 25 m
      a side, its side nearest a path drawn out toward it by
      `Yard_Snap_M` (the fill stops at the path), its own lot within a
      metre of the path somewhere along that side; one, placed once; its
      places closed until the storehouse stands; **refused if no
      storehouse could stand on it** (`Place_Storehouse (.., Try_Only)`).
      `Ask_Storehouse` looks for it on the second morning and every game
      hour, and `Zone_Stockyard` begins the storehouse at once if it has
      been asked for. How it is laid out, levelled and fitted out is in
      `habitation.md`, "The storehouse". `--stockyard X0 Y0 X1 Y1`.
    - **The player's stockyard is put down whole, twenty metres square with its path** (John,
      2026-11-21: "For the stockyard, lets expand the zones to 20x20"; `Place_Box` with
      `Stockyard_Box`, the spec's "placements"; `Set_Yard_Box`, `--no-yard-box` is the two corners;
      `--stockyard-box X Y WAY`; no blob change). Held by its middle, turned by Z and X, drawn to a
      path as a stockpile's box is; 80 blocks of front squarely, 57 slanting ones (20.15 m) at 45
      degrees; its four hundred places on its own whole metres from its front's beginning, all of
      them or none.
      - **Its storehouse is tried on the planned ground before anything is laid**
        (`Try_Store_On_Plan`, in `Plan_Box_Lot`, while the box's own path still counts as lying
        there): `Lot_Grid_Of_Plan` is the grid `Try_Lot` works on, made from the plan as
        `Lot_Grid_Of_Zone` makes it from a zone. So the ghost refuses what the click would
        ("its ground will not take the storehouse"), and no path is laid for a stockyard that is
        then not taken. Two corners still learn it after the zone is made, and take it back.
      - **Its front is the side its own path lies along** (`Front_Of_Zone`: a placed zone lies on
        the left of its way), whatever other path is as near another side: a stockyard zoned
        between two corners fronts the nearest path's side, first found south, north, west, east
        (a box turned north from the end of a path that then runs along its south side would front
        that). `Store_Squarely` and `Store_Turned` work the storehouse out from a lot's bounds and
        that way; `Place_Storehouse` and the plan's trial both go through them, from the same
        bounds, read off the places (a placed lot's metres are its own, not the world's: at 45
        degrees they are not whole numbers along and across, and are not rounded).
      - **Measured** (`colony_run --box-stats`, `Storehouse_Lie`): at each of the eight ways and
        with its middle on each quarter of a metre, four hundred places and the storehouse 4.5 m
        from its path's edge (to 4.75 at 45 degrees, where its ground is stepped), 10.5 m of yard
        behind it, 4.75 and 5.25 m beside its ends. A stockyard between two corners has the ground
        drawn out to its path before it: 5.0 m where its corner was given on the whole metre.
        **Those are the storehouse of before** (`--storehouse 10 5 4.5`). Since 2026-11-21 it is
        12 m by 8 m, 1.5 m from its path (`Set_Store_Size`; his "so that it is now 8x12";
        `habitation.md`, "The storehouse twelve metres by eight"): 1.5 m before its front wall,
        10.5 m of yard behind, 3.75 and 4.25 m beside its ends; along a path at 45 degrees 3.5 m
        before it and 8.5 m behind, because its own blocks stand square to the grid and must all
        lie on its stockyard's ground.
      - **Over the lord's cart it is refused by name** ("the lord's cart stands on it"): a
        stockyard is all of its lot. A stockpile's box is laid round the cart.
      - (`--yard-census-corners M` counts stockyards zoned between two corners, M metres a side,
        in the place of ones put down whole; `--yard-walls` with either says where each taken
        stockyard's stone stands and how its path lies at its front's two ends and middle.)
      - **What it costs.** `colony_run --square-scan R STEP --yard-census` holds one against each
        side of every square of the scan's grid, along that side's own path: of 1,292 sides at
        the ten places 845 take one (two corners of 20 m: 848; of 15 m, the least there is: 985;
        a stockpile's box: 1,288); the others: no storehouse could stand 98, ground that cannot
        all be taken 319, no ground for its path 30. The plan and the click disagreed at none.
        Holding it costs the frame 1.3 ms of the main thread and 0.3 ms of the card (a
        stockpile's box 0.4 and none): its plan fills four times the ground (2.1 ms a plan
        squarely and 2.4 at 45 degrees on the mean over those 1,292, a stockpile's 0.85 and
        0.94).
    - **A stockyard's stair stands in a corner of the zone** (John, 2026-11-21: "The path level at
      one corner is great, move the stair to the opposite corner instead of the center, if a stair
      is to be had it's to be at the corner of the zone", and "I was talking about the stockyard
      having the stair in the corner rather than the middle"; the spec, "The stockyard's stair in a
      corner of the zone"; `Set_Yard_Stair_Corner`, `--yard-stair-middle` is as it was; not saved).
      A stockyard's way in was two metres at the middle of its storehouse's front, across the
      staging, with steps wherever the path lay more than a block off the floor there; the
      storehouse's doors are in its ends. The floor's level is chosen as it was (by the land and by
      the path at that middle), and a stockyard with no steps there is as it was. One that would
      have steps there has its way in at an end of its front instead: two metres wide, a block
      column in from the side's rim, a block a step from the path's edge inward, as many steps as
      there are blocks between path and floor at that end (two to eight), on past the line of the
      front wall beside the storehouse's end where the flight is longer than the staging is deep.
      Which end: where the path comes in level at one, the other (the opposite corner); with a
      bank at both, the lower (of two as high the nearer the homestake); where an end is level and
      no end takes a stair, none. Only of a stockyard that is levelled (`--no-yard-level`: its way
      stays at the middle). A storehouse keeps the way it was begun with
      (`Castle.Buildings.House.Way_End`, in spare values of its byte of blob 41). At the ten
      places 115 of 828 stockyards had steps at the middle: 114 have a stair in a corner now (365
      steps for 296, 123,041 blocks of stone in all the stockyards for 126,866), none a pit, and
      the way from the fire into the storehouse is shorter at 35 of them and longer at 21.
      `colony_run --yard-map`, `--yard-pits`, `--yard-built`; the handoff of 2026-11-21 has the
      counts.
    - **A stockyard's floor at its path's level at the lower corner of its front** (John,
      2026-11-22: "Set the floors level of the stockyard to the path level at the lower corner, the
      higher corner along the path gets the stairs", and "After 2m no stair built"; the spec of
      that name; `Set_Yard_Floor_Low`, `--yard-floor-by-land` is the rule above alone; not saved).
      The floor is no longer chosen from the land under the stockyard and held to three steps of
      the path at the middle of its front: it is the row of the path at the lower of the front's
      two corners (the path's own nearest block column beside the way's two metres there, the
      middle one of the eight: `Path_At`), so the path comes in level there at every stockyard;
      the stair stands at the other corner where the path stands two to eight blocks over the
      floor, down from the path; over eight, two metres, none, and the level corner is the way in;
      a front level from corner to corner keeps its way at the middle of the storehouse's front.
      The row is read once, when the storehouse is begun, and kept with it. A stockyard put down
      whole reads its front by the line of its own path, laid or not. **A floor can stand over
      the land**, filled and held up by its walls; nothing but a fall of more than 3 m from end to
      end refuses one put down whole. At the ten places: 839 stockyards taken for 828, 195 stairs
      for 114 (692 steps for 365), half as much stone again (177,492 blocks for 117,954), a floor
      moved at 319 of 828; built on the spot, no pit. **Where the staging's rim is a wall the
      lord's cart has no place before the storehouse** (its bed wants a block clear of anything
      higher on every side, and a metre and a half less a block of wall is too narrow): it stays
      where it stood; squarely at 50 stockyards of the ten places for 30 before. The handoff of
      2026-11-22 has the counts.
    - **The stores move in** ("change all deliveries and pickups to the
      stokyard from the stockpile"): when the storehouse stands
      (`Finish_House`) every stockpile's places are closed (`Cell.Closed`:
      nothing put there, taken from first); a load at a time is carried
      over (`Go_Move_In`: `Go_Clear_Closed` over the stockpiles) by the
      stockman before it sorts and by a porter with nothing else to
      fetch. `Set_Stores_Move`, `--stockpile-stays`. The band's hunger over
      50 days goes by which of the two is nearer the camp (the handoff's
      table: 2,430 hungry serf-hours against 1,019 with the stockyard 20 m
      further off; 1,000 against 1,779 with it nearer).
    - **A bush takes as many pickers as it has basketfuls** (`Bush_Free`,
      `Pickers`; `Set_Bush_Sharing`, `--one-to-a-bush`): he found
      gatherers standing by ripe berries ("Gatherers can't find berries
      even when they are close"); a bush was one gatherer's.
      `Reserved_By` is one of its pickers (another takes it over in
      `Release`).
    - **Why one is idle is said as nearly as it can be**: a hunter with
      deer in reach whose herds are all down to `Spare_Last`
      (`Herds_Breeding`), or whose herd it has just shot at
      (`Herd_Settling`); a gatherer held back by room (`Nearly_Full`,
      `No_Room`), by no way (`No_Way`), by bushes with their pickers
      (`Bushes_Taken`), and only then "nothing to gather in reach".
    - **A plant is cut whole** (`Cut_Plants`) wherever ground is cleared
      (a stockpile's places, a path, a yard beaten; the camp's zoning
      with the band's labour on), and a porter cuts long grass from the
      top of its tuft (`Set_Top_Cut`, `--no-top-cut`): the upper block
      of a tuft two high was left standing on air.
      `colony_run --floating` counts plants over air near the stake.
    Colony blob 30 (18 to 29 refused).
  * **The next pass of his notes (2026-11-19; `docs/handoffs/Handoff_2026_11_19_next_pass.md`).**
    - *A path levelled as it is laid* (`Set_Path_Level`, `--no-path-level`; "paths still need to be
      leveled as well to elimiate small bumps and holes in the road, some holes get filled, others
      don't"). The path has a line of its own: at each quarter metre along a stretch the middle
      height of the ground across its width (closed hollows filled first), smoothed over
      `Path_Level_Span_B` (a metre) before and behind. Each column laid is cut or filled to that
      line where it is within `Path_Level_B` (half a metre) of it and no water lies in the way: a
      bump or a dent is gone, a slope keeps its steps, the path is level across its width. Only a
      metre laid from now on.
    - *A path stepped where it meets trodden ground* (2026-11-23; `Set_Paths_Meet`, `--no-paths-meet`,
      not saved; `Step_Seams`, at the end of `Lay_Metre`; his "we need to figure out a way to handle how
      paths and zone buildings meet up ... we have the .5m jumps where a path is extended from square").
      A metre of path is brought to its own line and the square's path to its floor's level, each by
      itself: where one met the other, or the land stepped two blocks under one, trodden ground lay
      half a metre off the trodden ground beside it. When a metre is laid the columns of path within
      `Meet_Reach_B` (two metres) of it are looked at again: one that stands two blocks or more over
      trodden ground beside it has a block cut off it, one that lies two blocks or more under ground
      that is never moved has a block of earth put under it, and so on until none does or it has been
      moved `Meet_Most_B` (two) blocks. A jump of half a metre becomes two steps of a quarter, a
      quarter metre apart. A column at the edge of what is looked at is never moved (what lies beside
      it out there is not seen). **Never moved: the square's own path, the strips kept for its walls, and
      any zone's ground** (a floor, a door's way). Counted at eight layouts of a square with housing
      along and off its path, sixteen days each (`colony_run --seam-stats`: pairs of block columns
      side by side, both with footpath on top, two blocks or more apart): 33 in all before (14 where
      two paths leave the corners of the square of the game as it is played), 8 with this rule and
      the next, all eight where a hovel fronts the square's own path.
    - *Making way* (`Set_Make_Way`, `--no-make-way`; "need make sure serfs have a way to continue
      their work if they meet obstacles"). A builder lays no block where someone stands, and waited
      for as long as they stood (nineteen game hours, made up in the check). One standing still
      there is put on the nearest free ground of the same zone from which there is a way to the
      stake, and goes on with what it was doing. `Builders_Blocked_S`, and `colony_run --who` at its
      end, say how long builders have waited: never, in 41 days of the band of thirteen.
    - *Ground taken out of the housing* (`Unzone_Housing`, `Mark_Hovel`, `Hovel_At`; "Add away to
      delete parts of a zone, and if a structure exists, mark a structure for razing"). Housing only.
      The block columns in the box leave their zone, the lots still to begin are laid out anew, a
      hovel begun or standing there keeps its lot and is marked. **The mark is a label: nothing is
      taken down.** A zone left with no ground keeps its place in the list and is the next housing
      zoned.
    - The band's lists name a serf by its trade while it has one (`Castle.Views.Job_Label`).
    Colony blob 31; a blob of 30 is still read.
  * **His answers of 2026-11-19 (`docs/handoffs/Handoff_2026_11_19_answers_round.md`).**
    - *Razing* ("limit razing buildings to unowned, this happens when a serf passes to a new job
      and they house somewhere else, for example when the farm is built"). Only a hovel nobody owns
      is marked (one still being built is nobody's); one lived in is refused, and the box that takes
      housing out leaves it with its lot (`Unzone_Lived_In`). A marked hovel is taken down: nobody's
      to draw, asking for nothing, its builder before its door taking its blueprint's blocks off in
      reverse, twice a bout's laying to a bout; what they took lies at the site; at nothing, half
      goes to the stores (`Razed_Came_Back`), the hovel leaves the list (`Remove_House`: every later
      house a number lower) and its lot the zone. The mark lifted, it is built up again.
    - *Jobs* ("serfs fill jobs as the have been, as the are needed, dictated by skill ... the player
      won't need to delegate further, past opening positions"). The opening jobs are the player's;
      a builder is the forester best at building, the stockman the porter with the most portering,
      the carpenter whoever raised the storehouse (by skill since his next answer, below). For development a forester can be set to building
      (`Set_Builder`): it takes a house before any not so set.
    Colony blob 32; blobs of 30 and 31 are still read.
  * **Foresters with no tree in reach, and paths straight or at 45 degrees (2026-11-19;
    `docs/handoffs/Handoff_2026_11_19_foresters_and_paths.md`).**
    - *How far a forester goes for a tree* (`Set_Wood_Reach`, `--no-wood-reach`, `Fell_Reach_M`;
      "Still having issues with the foresters not finding trees in range"). A felled tree does not
      grow back, and work was looked for within `Work_Radius_M` (60 m) of the stake: at the
      reference site the band of thirteen had felled every tree that near by its hundred and
      thirtieth day, with 189 standing 60 to 80 m off, and a stake on open land has few to begin
      with. A forester with no tree left to fell that it can get to looks a ring further
      (`Reach_Step_M`), and another, to `Fell_Reach_Max_M` (124 m) at the most; the reach never
      comes back in. The colony's ground (`Ground_Reach_M`) and what it looks through
      (`Index_Some`) reach as far. The choice among the trees in reach is as it was. A tree
      somebody else is felling is no reason to look further. A tree's way is asked with `Refuse`
      (the walking map's pieces of ground alone say out of reach: no search) and a budget
      (`Fell_Budget` floors: a tree 70 m off and 330 m round by a ford is left); one there is no
      way to is nobody's to try for `Tree_No_Way_S` (an hour), one with only a long way round for
      `Tree_Round_S` (a day), unless the forester that found it so has no short way home itself.
      `Fell_Tries` trees are asked in one thought at the most, `Fell_Round_Tries` of them by a
      search that ran out. Why it has no tree is said (`Why_Idle`: `Trees_No_Way`, `Trees_Taken`,
      `Trees_Spared`, `Trees_Further`; "no trees to fell in reach" only when there are none).
      `colony_run --tree-stats` is the measure. Off, `Go_Fell` is as it was to the line.
    - *A path's line* (`Castle.Actions.Path_Snap`, `--no-path-snap`, `Path_Line_Start`,
      `Path_Line_End`; "I think we need to lock the paths to straight and 45 degree angles,
      slighty being off doesn't really work in a voxel world"). An order to lay a path is laid
      along the nearest of the eight ways, a whole number of blocks long, from a corner of four
      blocks: four blocks across all along when straight, five at 45 degrees with a step a
      block. A line begun on a path begins on its middle line (by its end, at that end); one
      drawn up to a path ends on its middle line. Both functions give back a point that is such a
      point already, so the tool's line and the order are one line. `Lay_Path` itself lays any
      line (the checks and `tools/stockyard_sites.sh`'s first site do); the rule is not saved.
      **The height of a line's point under a tree is the ground's under it** (`Line_Point`;
      `Set_Line_Ground`, `--no-line-ground`; 2026-11-22): the walking map's first floor there is
      a bough, and a stretch whose end had a bough's height looked for the ground of its metres
      by that end four and five metres up and found none (never counted, never laid: 4 of some
      1,680 parts of the paths of stockyards put down whole at ten places, none now).
      Beside a path at 45 degrees a house stands square to the blocks, stepped back, and fewer
      fit; a stockyard there is taken only where a corner of its box comes to the path (none of
      ten boxes on the hillside east of the reference stake). (A hovel there is *drawn* turned to
      the path since the same day, its ground made where it is drawn: `habitation.md`.  And since
      2026-11-20 **a stockyard there is laid out along the path**, its yard made for real, its
      storehouse drawn turned and walked where it is drawn: `Set_Yard_Turn`, `--no-yard-turn`,
      blob 39; `habitation.md`, "A stockyard along a path at 45 degrees".  Later the same day a
      turned hovel is walked where it is drawn too, `Set_Hovel_Walk`, `--no-hovel-walk`, blob 40; a
      stockyard's coverings' roofs are smoothed by its builder and a turned one's fence drawn along
      the path, `Set_Smooth_Covers`, `--no-smooth-covers`, `Set_Fence_Pieces`, `--no-fence-pieces`,
      blob 41; `colony_run --turn-stats` says a walked house's serf-seconds in a wall as drawn and
      whether its bed is got to by its door, and a storehouse's pieces; `habitation.md`, "Turned
      hovels walked where they are drawn; a stockyard's pieces".)
    Colony blob 33; blobs of 30 to 32 are still read.
  * **Zones put down whole (2026-11-20; `docs/handoffs/Handoff_2026_11_20_placements_with_paths_and_the_square.md`;
    his words: "let's lock the size of the stockpile, if the player places it, it will be a square box,
    lets fix the path artifcats by including the path in front of the stockpile, the player can rotate
    the placement ... Along with a warning for overlap ... and allow us to make the angled zones their
    own grid").** The spec's section "placements" is the description; in short:
    - `Box_At (Kind, Middle, Way)` says where a box held by its middle and turned one of the eight
      ways lies: its path a stretch along its front (from a corner of blocks, a whole number of blocks:
      40 straight, 29 aslant for 10 m), the box on the left of that way from the path's edge back. It
      is drawn to a path near it by the least move: along it (its path that path's line, nothing new
      laid; an end put at the path's end or against a box already along that line), to its end, or to
      its middle (where the box's own line crosses the path's); where it meets a path so, the box
      begins as many blocks on as keep it off that path.
    - `Plan_Box` is what it would take (`Box_Refusal`: no ground, a zone or the cart in its path's
      way, its box over a zone or a path, no place); `Place_Box` lays what of its path no stretch
      lies along (`Path_Gaps`) and zones its lot through `Plan_Lot`, its own path taken as lying
      there. A stockpile's box is a stockpile's zone in every way; a bush or a boulder in it leaves
      places out. **A tree in it is felled and taken out** (his "fell the tree in the stockpile";
      `Set_Box_Fell`, `--no-box-fell`, not saved): its foot is the stockpile's ground, the place over
      it closed until whoever has a place at an extra task has felled it (`Go_Fell_Box`) and its
      stump and roots are earth; **the stump of a tree a forester felled before the stockpile was put
      down is taken out the same way** (`Box_Stump`), in the time the tree took to fell. A tree or a
      stump to take out is one of the reasons `Think` turns to the band's building at all.
    - The zone keeps its frame (`Zone_View.Placed`, `From`, `Way`, `Along_B`; blob 42).
    - `Set_Box_Place` (`--no-box-place`: set where the option is read, so a colony the player founds
      by hand has it too) is the player's tool alone; `--stockpile X0 Y0 X1 Y1` is as
      it was, `--stockpile-box X Y WAY` puts one down as the tool does, `colony_run --box-stats` counts
      a placed zone's block columns by whose they are (on open ground all its own, none between it and
      its path).
  * **The homestake and the campfire one (2026-11-20; the same handoff; his words: "Let's merge the
    homestake and the campfire, no physical stake now, lets expand the campfire/homestake, to a 10x10
    area, terriform so the entire area is flat, and build a path around the perimeter ... it can become
    the village center, or town square").** The spec's section of that name is the description; in
    short:
    - `Place_Square (Middle, Way, Band, Seed)` founds the colony on a square: no post; the stake's
      place is the fire's, the square's middle, on a corner of blocks, and whatever is measured from
      the stake is measured from there; the square is the camp's zone (**11 m a side, 11.02 m aslant**,
      since 2026-11-21: "expand the campfire/homestake square to 13x13m (with the footpath) so the
      campfire is in the center"; 10 m and 9.96 before, and with `Set_Square_Wide` off, `--square-10`)
      and **all of it is the camp's floor** (`Camp_Square`): made ready a square metre at a time, dug
      and filled to one level, trodden bare, before the hearth is built. The square metres are counted
      from the floor's edges, eleven each way, so the fire stands in the middle of the middle one (on
      ten metres it stood where four of them met). **A square keeps the size it was founded with**: it
      is read from its zone's frame, which is saved, never from the size of the day. Round the outside
      lie four stretches of path, 13 m over all, laid by the band at the square's level where the
      ground is within half a metre of it (a slice of its width at a time while its banks are walled:
      below).
    - Refused where there is water, where the ground lies more than 1.5 m off its middle's (read
      under whatever stands on it), where a tree's foot or a boulder stands within 4 m of its middle,
      or where its floor, made level, would lie cut off (no two metres of its edge within a step of
      the ground beside it: a knoll, a hollow). **A tree on it is felled and taken out** (his answer
      of 2026-11-20): the band fells every tree on its floor or its path before the ground is made
      under it, stump and roots are earth from then on, its logs lie on the floor, and the camp is not
      built while one stands (`Set_Square_Fell`, `--no-square-fell`: off, a tree is left, its foot not
      the square's ground, and spared by the foresters, as is the tree of any square founded so).
      A boulder further out than 4 m is left standing. **Bushes on its floor, and what hangs within a
      serf's height over it of a tree, are cleared at the founding**, and their ground is floor like
      the rest (a bush left where the floor is filled stands in a pit).
    - **It is founded on the ground its plan read** (`Set_Fire_Ground`, `--no-fire-ground`; 2026-11-21).
      A plan's middle has the height of the highest floor there (`Castle.Nav.Surface_Z`: under a
      crown, a bough or the tree's top); the plan reads the fire's own ground under it (`Top_By`).
      `Place_Square` hands `Place_Stake` that ground (`As_Read`), beside a tree's foot that stands on
      the fire's own place the ground by it. Before, the stake was asked for near the plan's
      middle's height (`Ground_Row`, the highest solid thing within reach): with a bough over the
      fire's own block column the stake's place was the bough, 4 to 7 m up, the band arrived on the
      crowns round it ("the floor nearest the square's height") and whoever could not get down
      starved (11 squares of 323 at seed 1's ten places; somebody said to be starving at 7 of 10
      run twelve days); with the bough beside that column no ground was found within 4 m and the
      square its plan had shown as taken was refused (3 more). `colony_run --square-scan` counts
      squares planned and not founded and fires more than 2 m off their floor's level;
      `tools/square_sites.sh` fails on either and runs four such squares twelve days.
    - `colony_run --square-census R STEP` counts the places round a stake that take one;
      `--square-scan R STEP` (`--square-scan-list` for a line a square) founds one at every place of
      a grid that takes it, makes its floor and its path on the spot, and asks of every spot round it
      that can be got to from the fire the way back (a pit), and of the land 14 m off on each side
      the way to the fire and back. Ten places of seed 1, 524 squares, 1,553 trees felled for them:
      no pit, no fire out of reach. `--square-pits` looks round this colony's square so at the end of
      a run (a save's too); `--feet-stats` says who is off the floor under them.
    - **Its banks are walled with stone, and stairs cut through them** (his answer of 2026-11-20:
      "stone wall and stair, also step the stone walls towards the higher ground if over 1m. so from
      lower ground for each 1m of retaining wall step inwards .25"; the spec, "The square's walls and
      stair"; `Set_Square_Walls`, `--no-square-walls`, not saved). Once the hearth stands, wherever
      the laid path lies more than a block over or under the floor, the floor's edge is a wall of
      fieldstone on the square's own outermost quarter metre: against higher ground flush with the
      path, over lower ground holding the floor up. **A wall over a metre is set back**: counted up
      from the lower ground, each further metre of it stands a block column nearer the higher
      ground (aslant: a diagonal row, 18 cm). **A stair** at the middle of each side whose bank
      there is three to eight blocks over all the stair's width, cut into the floor, a block a
      step. Nothing is kept: `Plan_Walls` reads what each column is to be from the floor's level,
      the square's frame and the laid path outside its strip, `Column_Work` what is left to do from
      the blocks, and the count and the laying go by those two (what cannot be laid is never
      counted: no wall against a stretch of path still to lay, a boulder, or under a tree; rock is
      left). **They are built from the bank outward and dug from the path inward** (`Wall_Ready`),
      so that no half-built wall leaves a place to drop into and not climb out of. The labour is
      an extra task after the paths, once the fire has been lit (or, with none lit at all, from
      the colony's third day): a load of stone `For_Wall`, from a
      stockpile (what the hearth and the houses do not want) or prised off a boulder in reach,
      carried to the nearest patch that can be worked, a stone sixteen blocks and `Tamp_S` seconds;
      a carrier is not left off for night or hunger. Whoever stands at a wall's foot is settled on
      the ground of its own block column (`Own_Ground`), not on the wall's top, which is the
      walking map's floor there. **With the walls on, a slice of the square's path is brought to the
      floor's level whole or not at all** (`Lay_Metre`'s `Read_Slices`), so the bank stands at the
      floor's edge and never along the middle of the path. `colony_run --wall-map` draws the plan
      and the ground as it stands, `--walls-now` builds camp, paths and walls on the spot
      (`--camp-now`: the camp and its paths so, the walls left to the band),
      `--box-stats` says what is left and when they were begun and done; `--square-scan` builds
      them at every square and counts them. Of the 524 squares at ten places 95 are walled, 30
      with a wall set back, 38 with a stair (58 stairs), the highest bank 1.75 m: no pit, and the
      way from the middle of a side's path to the fire and back is 14.7 m at the longest where it
      was 30.1; the most stone for one is 660 blocks (41 stones), ten stones for a walled one on
      average.
    - **A special zone's area is kept whole: the walls stand outside the floor, the path beyond them**
      (his rule of 2026-11-21: "the area of a special zone like these takes precedent, so if a
      retaining wall is needed put it on the zones edge, shift the path. So the area of the campfire
      stays 11x11m + the wall on the sides if needed then the path that follows, the size can change
      overall"; the spec, "A special zone's area is kept whole"; `Set_Square_Outside`,
      `--square-walls-inside` is the paragraph above as it stood). A square founded under the rule
      has a **strip** kept outside each side where that side's bank will want a wall: `Square_Strip`
      rings, a ring a block column squarely and a diagonal row aslant: squarely one for each lift of
      the highest wall that side is to have, three at the most; **aslant two wherever a wall is
      wanted** (35 cm). The wall stands in the strip (against
      higher ground the lowest lift beside the floor and the top one, flush with the path, furthest
      out; holding the floor up, a rim flush with the floor and the lower lifts further out), the
      path lies beyond, the four stretches run between the corners where the four lines meet, and
      the whole is wider than thirteen metres by as much. Nothing of the floor is wall or ledge;
      **a stair's steps are still cut into the floor from its edge**, the strip before them a landing
      of stone at the path's level.
    - **A square's stair in a corner of the zone, not at the middle of its side: a rule behind its
      switch, off** (`Set_Square_Stair_Corner`, `--square-stair-corner`; not saved; the spec, "A
      square's stair in a corner of the zone"). **A square's stair stands at the middle of its
      side.** The rule was built for the square on his words of 2026-11-21, afternoon ("The path
      level at one corner is great, move the stair to the opposite corner instead of the center, if
      a stair is to be had it's to be at the corner of the zone"), which he then said were of the
      stockyard's stair ("No let's go back to square stair middle, I was talking about the stockyard
      having the stair in the corner rather than the middle"). What follows is the rule as it works
      with the switch on. Of a square whose
      walls stand outside its floor (one with its walls on its own edge keeps its stair at the
      middle: the wall of the side it would meet in the corner stands on the floor's outermost
      columns there). **The same sides have a stair as had one**: a side whose bank at its middle is
      three to eight blocks, all one way, over a stair's width. It stands at one of that side's two
      ends, the last metre of the floor along it (four block columns from the floor's corner, five
      where the floor's edge is not the edge of a cell of the walking map; aslant nine diagonal
      rows), its outer flank the wall of the side it meets there, its landing the strip before it.
      **It is judged where it stands** (`Plan_Walls`: `Banks` of each side at its low end, its
      middle and its high end; `Takes`): an end takes it if the bank there is three to eight blocks
      all one way. So a side whose path comes in level at one end has its stair at the other, **the
      opposite corner**. Of two ends that both take it: **the one whose corner is not a level way
      in already** (`Level_Corner`: the path of the side met there within a block of the floor; a
      side banked from end to end, the next side level where they meet, has its stair at the far
      end from that corner, though the bank is higher there); else the lower bank; of two as high
      the end come to last going round the square with the floor on the right (two sides banked
      evenly, one up and one down, then have their stairs in corners diagonally across). With
      neither end taking it the side has none (`Stairs_Lost`). **One stair to a corner**: of two
      sides' there, the lower bank's (`Stairs_Shared`). A side with one end only that takes it has
      it there, be that corner a level way in on the other side (`Stairs_By_Level` counts them:
      his to say). `Walls_View.Stair_At` says where each side's stands,
      `Square_Stair_Sites` the bank at each of the three places (for counting);
      `colony_run --box-stats` and `--square-scan` say both, and `--square-pits` how far it is from
      the middle of each side's path to the fire and back.
      - **Counted before it was built** (323 squares at the ten places, `--square-scan 100 20`): 35
        have a stair, 55 stairs at the middles. Every one of those 55 sides takes a stair at an end:
        30 at one end only (the other end level at 13, a bank under a stair's at 16, over one's or
        mixed at 1), 25 at both (8 as high at both), none at neither. **In corners: 52 stairs at the
        same 35 squares** (three sides' are another side's in the corner they share), the highest
        bank one stands against eight blocks (seven at a middle), 233 blocks of bank gone up or down
        in all for 216, 18,629 blocks of stone in all the walls for 18,453. Two of the 52 stand
        beside a level way in (the only end of their side that takes one; with the lower bank alone
        deciding between two ends it was nine of 53). **The other reading of "the
        opposite corner", the corner diagonally across the square from a level one, was counted and
        not built**: of 1,172 level corners the one across is level too at 1,132 and takes a stair
        at 28: 20 of the 35 squares would have no stair. (A stair at every corner that takes one:
        105 at 53 squares.)
      - **What it costs: the way from the middle of a walled side.** From the middle of each side's
        path to the fire and back, 54 sides' ways are longer and none shorter: 5.5 m more on the
        mean, the longest 26.0 m where it was 13.0 (1200 720 on seed 1); at the 35 squares the mean
        is 14.9 m for 12.7. Twelve days of the band of thirteen at 23 squares (11 with a stair; the
        12 without end in the same state by both): member-hours with an empty belly 234 for 229,
        hungry serf-hours 3,746 for 3,658 at the eleven, nobody dead, no pit, no column of a floor
        stone but a stair's. (Not even: at 1146 1110, the square of his picture, 21 for 13 and the
        lowest confidence 32 % for 49; at 1172 1092 the walls were done after 23 h for 15.)
      - **What he praised is the measure, where he praised it**: by the level corner of his
        picture (a corner level on both its sides, or with no stair come to stand in it) no block
        column stands otherwise within 3 m, strip and path with it (the check, on ground level at
        two corners: 0 of 1,152; at 1146 1110, 1238 1058 and 1258 1058 built on the spot by both
        rules every column that differs is a stair's own place, 67, 97 and 140 of them); the still
        of 1238 1058's level corner is the same to the pixel (0 of 448,000). **Not so of every
        corner where a path comes in level**: a side's stair can come to stand in one that is level
        on the other side only (1146 1110's south-west: 13 of its 67 columns), which is the call
        put to him.
      - **A square loaded with its stair laid at a middle keeps that stone** (nothing takes laid
        stone up) and is built the one in its corner as well: three saves of the build before run
        on so, no pit. No rule was made for them.
      - **The strips are judged when the square is planned** (`Forecast_Strips`, in
        `Plan_Square_Lot`, so the tool's ghost shows the path where it will lie): each side's path is
        tried where it lies and further out while a quarter metre of its length would leave a bank
        of more lifts than the rings kept. It reads the ground as `Lay_Metre` will bring it: a
        quarter metre all within `Path_Level_B` of the floor's level, strip and all, is brought to
        it; a tree's foot is the level ground it will be once felled. **They are judged against
        the level the square is founded at** (`Square_Plan.Level_Row`: `Level_For` with
        `With_Feet`, which counts the ground under the feet of the trees on it among what is to be
        filled, as `Choose_Level` does at the founding; the level by which a square is judged cut
        off or not is reckoned without them, as it always was. Until the gate of 2026-11-21 the
        strips were judged against that one, and three squares of 320 on seed 1 were founded a
        block lower than their strips had been judged for). They are saved with the
        square (over the blocks of its zone's frame, which are fewer than 128: no new bytes, blob
        43 still, and a square of before the rule is saved as it always was, to the byte).
      - **Where a side's path lies level with the floor the strip between is laid with it, as path**
        (`Lay_Metre`: a slice is brought level strip and all, or not at all), so the path is that
        much wider there and the strip is a wall's only beside a bank. Beside a bank, what of the
        strip the wall does not want is brought to the path's level and capped with stone.
      - **The path stepped with stone where a levelled stretch of it ends** (John, 2026-11-21:
        "we need to do something about having the .5m jumps in the path around the square too";
        2026-11-22, of four ways: "Steps of stone"; the spec, "The square's path stepped with
        stone"; `Set_Path_Steps`, `--no-path-steps`; not saved). A quarter metre of the path is
        brought to the floor's level whole or left as the land lies, so the path stood two or
        three blocks off a levelled stretch's end at once. From that end the path now goes a block
        a quarter metre toward the land: the first quarter metre past it a step one block off the
        level, the next two, while the path there lies at least that far off; every column of a
        step a tread of fieldstone, the wall builders' work, planned with the walls from the path
        as it is laid (`Plan_Steps` in `Plan_Walls`; nothing kept). None before a stair, and
        before the middle of a side that has none only steps of one and two blocks (whether a
        side has a stair is read from the path there: the steps leave that reading what it was,
        and no stair is moved, lost or made). The walls and strips beside a step are planned
        against it.
      - **The corners of the path** (John, 2026-11-22, of the 37 jumps then left at them: "stick
        with whatever you think is best"; the spec, "The corners of the square's path").
        **The square metre where two sides' paths cross is laid as one** (`Set_Corner_Whole`,
        `--no-corner-whole`; `Lay_Metre`'s `Lay_Crossing`, `Cross_Of`): all of it when the first
        metre that has a column of it is laid, at the floor's level whole where every column of
        it lies within half a metre of that, else whole as its ground lies; by its own columns
        alone, so it is the same square metre whichever side's metre comes first (a quarter
        metre of each side's at a time, 41 quarter metres at 26 of 323 squares stood otherwise
        laid last metre first; now none). Every column a stretch finds to lay in it is laid,
        whatever the corner's own reading says (one passed over is counted as left for ever).
        **And the steps run into it and through it** (`Set_Corner_Steps`, `--no-corner-steps`):
        the corner's square metre is one step of a flight, a landing, all its columns of stone
        at one row, and a flight that comes to it along one side goes on along the other: the
        path is one round of quarter metres and four landings, a flight running from each level
        one either way. At the ten places **16 jumps of two and three blocks are left of 272**
        (50 before the corners: 2 before a stair, 5 at a boulder, 2 by a side's end, 7 the
        land's own), with 691 quarter metres stepped; laid last metre first no square stands
        otherwise.
      - **A strip's column waits for the path it is planned against** (`Set_Strip_Wait`,
        `--no-strip-wait`): nothing planned, nothing counted as left, while the path column it
        reads on either of its sides, or a quarter metre within a flight's reach of that one, is
        still to lay (`Column_To_Lay`: the very test a stretch finds its columns by, so ground
        no stretch ever comes to holds nothing up). Walled by one side's path before the
        other's was laid, a corner of two strips kept the higher stone; capped beside a quarter
        metre that later became a step, a column stood a block over it. With their walls built
        when half their paths are laid, no square of 323 stands otherwise than built in order
        (25).
      - **What is built is still read from the path as laid** (`Plan_Walls`), so the forecast can be
        wrong without anything sticking: a wall that wants more lifts than its strip has rings
        stands steeper in the rings it has; on a side with no strip a bank is left earth, as banks
        were before there were walls; neither takes any floor. `Square_Walls_State` has the rings
        kept and asked, and counts both. Where a boulder stands in the path's line the wall runs on
        before it at the height it has beside it (`Near_Reading`).
      - **`Part_Of (Geo, Bx, By)` says what of a square a block column is** (floor, strip, path, none
        of it), for the founded square (`Geo_Now`) or one being planned; everything that asked how
        far out a column lay asks that. **A strip is nobody's to zone** (`Strip_Kept`, asked by a
        lot's planner and by housing's two): housing pulled along a walled side with a row toward
        the square is refused there as it is beside a floor. **Aslant a strip is two rings or none**, because a path at 45
        degrees that a stockpile or a turned house can lie along runs on every other diagonal of the
        block grid: with a ring a lift, two sides whose strips were an odd number apart had lines
        that crossed at the middle of a block's edge, and a stockpile held by such a side was
        refused ("it overlaps a path") or put down along a path of its own 18 cm beside the
        square's.
      - Of 323 squares at ten places (a 20 m grid; `tools/square_sites.sh`): 70 have a strip on 212
        sides; the path as laid asks more rings than were kept on none of those sides, fewer on 74
        (an angled side keeps two for a wall of one lift), and a wall on no side with none; every
        one is founded at the level its plan said; no column of any floor is stone but a stair's or
        the earth beside its steps; no pit; nothing left to lay; 18,453 blocks of stone in all where
        walls inside took 13,991.
    - A `Raise_Stake` order says which founding it is; the scripts' `--stake` and `--camp` are the post
      and the camp apart, as ever, and `--square X Y WAY` the square. `Castle.Actions.Square_Stake`
      (`--no-square`) is what the player's tool gives. Blob 43.
  * **Housing pulled with its path (2026-11-20; the same handoff; his words: "it will include the path
    with the zone placement, it will allow either an overlap, extension, or intersection with an
    existing path").** The spec's section of that name is the description; `habitation.md` has the
    player's side of it. `Pull_Line` reads a pull from its two points once; `Plan_Housing_Pull` and
    `Pull_Housing` take what it gives. Along a path that is there it is `Zone_Housing`'s strip for the
    same two points and lays nothing, past an end the path goes on, anywhere else it is a line of its
    own as the path tool draws one; housing with no hovel's lot on it gives way under its path. No blob
    change.
  * **His answers to those two rounds (2026-11-19; `docs/handoffs/Handoff_2026_11_19_stockpiles_and_reach.md`).**
    - *Stockpiles* ("we go back to variable size stockpile, placed along the path"). The player's
      stockpile is zoned corner to corner (the two corners opposite along and across its path), as
      often as wanted; `--one-stockpile` is the 10 m square placed once. A stockpile stays open when
      the storehouse stands; `--stores-move` closes them and has them carried over. A blob of 30 to
      33 loads with these rules.
    - *The carpenter* is the free forester best at carpentry, not whoever raised the storehouse.
    - *Foresters to 250 m* ("Let workers go 250m for resources, wood is a vital resource").
      `Fell_Reach_Max_M` 250; the reach grows only when every tree in reach has been tried; a
      search's budget goes by how far off the tree is (`Fell_Budget` and `Fell_Budget_M` a metre);
      no way is left a day, a long way round ten; `--wood-from M` for measuring. Porters, gatherers
      and hunters are as they were (owed).
    Colony blob 34; blobs of 30 to 33 are still read.
    - *Gatherers and porters to 250 m* (the same evening). A gatherer that finds nothing to gather
      in reach, and a porter that finds none of what it is sent for, looks a ring further the next
      time (`Look_Further_For`; `Food_Reach_M`, `Haul_Reach_M`; never back in; and since 2026-11-20
      what one of them finds there is no way to, the others are told, so that one whose nearest
      is across water looks past it: `Set_Ways_Told`, `--no-ways-told`, `Route_Asked`,
      `Tell_No_Way`, a day before it is tried again; `colony_run --work-stats`; `--no-wood-reach`
      holds them off with the foresters). Bushes are looked for as far as the gatherers look
      (`Index_Some`: a stack looked through for its trees alone is looked through again). Colony
      blob 35. They ask their way of the walking map's pieces first since 2026-11-20, and tell
      each other where there is none (blob 38). The hunters are as they were: the deer live within
      70 m of the stake by the herds' own rule.
* **Zones.** A zone is ground the player has marked for a use, and a thing
  of its own: a kind, its ground, and what is on it. Stockpiles and the
  camp are the first two kinds, housing the third (`Zone_Kind`; stage 6a:
  `habitation.md`; farms will be more of the same record). One zoning is one zone, and two zoned side by
  side stay two. Zones are numbered from 1 in the order they were made.
  * **Its ground** is kept block column by block column (strips of them,
    `Zone_Run_At`), so a zone has whatever outline its place gives it, and
    is shown filled in, with a line round its edge (`Castle.Zone_Marks`).
    John's rule (2026-11-10): "same with all zones, fill, snap, terminate
    at the path, so it can be at diagonals and whatnot ... paths and zone
    need to not overlap, paths remove the possibility of that area becoming
    a zone."
    *Fill:* its ground is every free block column of its lot that can be
    reached from where it was begun (the first corner; the camp's fire)
    without crossing a path, another zone, a ledge higher than half a
    metre (`Zone_Step_M`) or anything standing in the way: a zone flows
    round a tree or a boulder.
    *Snap:* the lot is a rectangle turned to lie along the nearest path,
    whichever way that runs (`Turn`, within 45 degrees of east: which end is
    which does not matter); a side within a metre of a path's edge and
    facing it is drawn out to the edge, so no strip is left between.
    *Terminate:* the fill stops at the path. Ground a path lies on is never
    a zone's, and a lot drawn across a path keeps to the side it was begun
    on.
  * **No overlap.** One lookup says whose a block column is
    (`Zone_Of_Block` in the body; `Zone_On`, `Zone_Top` and `On_Path`
    outside it): a zone's, else a path's, else nobody's. Every zoning, every
    path laid, the picking and the drawing ask it. So one zoned over part
    of another gets only the ground still free, and no block column is ever
    in two zones or in a zone and a path.
  * **The camp** is laid out the same way: its 7 m square turned to a path
    that passes within a metre of it and drawn out to that path's edge,
    east and north otherwise; its seats, beds and firewood turn with it
    (`Camp_Turn`). A path or another zone's ground nearer its fire than
    3 m (`Camp_Clear_M`) refuses it.
  * **What it gathers.** A zone is where information is gathered
    (`Zone_At`): what lies in it by kind, what is on its way in (room set
    aside for a load being carried there; what the cook is bringing to the
    camp), what is set aside to go out (a meal someone is walking to, food for
    the pot), how many of its places are in use and who stands on its
    ground; and its size (`Along` by `Across` its own way, `Blocks`).
    Nothing is counted that is in no zone. No behaviour reads zones yet:
    places are found and filled exactly as before.
  * **What is built on it.** A zone records whether what is to be built
    on it stands (`Built`) and what has been delivered for its building
    (`Got`, against `Build_Takes` for its kind). The camp is the first: its
    hearth takes 10 stone and 3 pieces of wood and its ground made ready,
    and the band builds it (`docs/systems/needs.md`, "Building it"). A
    stockpile takes nothing yet and stands at once. A housing zone's
    takings are not a row of `Build_Takes`: they are what its houses'
    blueprints count up to, asked of the stores the same way
    (`habitation.md`).
  * **Leaves room for** (John, the same day: "they will eventually start
    upgrading the stockpile, build a storehouse, warehouse, fences and
    outdoor storage will get coverings"): a zone already knows the path it
    fronts and the way it lies, which is what a building set on it will
    need (the framework's "pathways set the public edge"), and what a
    building takes is a row of `Build_Takes` delivered the way the hearth's
    stone and wood are.
  * Not there yet: un-zoning, or changing a zone's ground once made; a
    zone's ground following the ground when it is dug; lots of any shape
    but a rectangle.
* **Who directs whom.** Everyone who acts on the colony is an actor
  (`Castle.Colony.Actor`): the player, or a member of the band. Each member
  records its director, the actor who gave it its job: the player for a
  job set from a panel, a menu or the command line; no one for the
  unassigned, and for the band's first cook, who takes the job up on its
  own. `Set_Job (I, J, By)` records it. Nothing reads it yet; it is there
  for the trades whose holders direct helpers (delegation runs only
  downward).
* **Skills** (stage 5b; its rules, `docs/production/briefs/Stage_5b_brief.md`,
  stand as built, with John's tuning to come). Each member has a level,
  none to mastery, in each skill, and an aptitude for each (half to one and
  a half) that says how fast it learns it: its own for life, from its seed.
  Five are the skills of the work there is (gathering, forestry, hunting,
  portering, cooking); six only grow alongside, for the trades to come
  (building, carpentry, stonework, farming, tanning, taming).
  * **What a level does.** Every work timer runs at rate = condition x
    skill x direction. Condition is 0.6 with an empty belly, else 1. Skill
    is 0.75 with none of the work's own skill, 1 at a third of the way to
    mastery (the pace before there were skills), 1.5 at mastery. Direction
    is 1 for everyone: it is where a trade that directs helpers will add
    its worth. The skilled timers are picking and pulling, felling, cutting
    straw and prising stone, the draw of the bow, butchering and stirring
    the pot. Carrying, lifting, putting down and taking from a cell have no
    skill in them (their times have names now: `Store_S`, `Lift_Log_S`,
    `Lift_Carcass_S`, `Take_S`, `Put_In_S`), and walking goes by condition
    alone. A hunter's chance to hit is the old one times 0.8 to 1.4 by its
    hunting, never over 95 %; a cook's pot holds 0.9 to 1.2 of what went in.
  * **What people arrive with.** 15 to 50 % in each working skill (the
    band's elder 20 points more, a child half), up to 10 % in the trades.
    So a band works at about the old pace on the whole, some of it better
    and some worse: who is given which job matters now.
  * **Skill by doing.** An hour on the job is an hour of practice: the
    whole trip counts (going out, the work, carrying it home), by the work
    being done, not the job held, so a cook out gathering, or anyone
    fending for itself, learns gathering. It teaches the work's own skill
    in full and the skills beside it by a fraction (`Learns`: picking gives
    farming 0.2 and cooking 0.1; felling, building 0.15 and carpentry 0.1;
    the hunt, taming 0.1; butchering, tanning 0.3 and cooking 0.2; cutting
    straw, farming 0.3; prising stone, stonework 0.3). A level closes on
    mastery at its aptitude over `Learn_Hours` (600): fast from nothing,
    slower the better it is. Nothing is learnt idle, eating or asleep, and
    nothing is forgotten.
  * **Nothing is gated by skill.** Any job can be given to anyone. The
    first cook is still whoever has the best aptitude for cooking (the same
    member as before skills: the aptitude is the old `Cooking_Of`, spread
    over the range). That is the fastest learner, not the best cook today:
    its level is its own draw, so a band's first pot is about par where
    before skills it was the band's best (about 7 % over).
  * **Off.** `Set_Skills (False)` (`--no-skills`, which holds for a stake
    raised by hand in the game too): everyone works at the one pace, aims
    and cooks as before, and learns nothing. Saved with the colony, so a
    loaded colony keeps the switch it was saved with. With it the reference
    run is stage 5a's, line for line.
  * **Not there yet:** a trade earned by skill, and reverting; job tiers;
    what a director adds (direction) and how many he can direct
    (capacity); tools that cap a skill; teaching; forgetting.
* **Actions.** `Castle.Actions` is the action table: everything an actor
  can do to the world by intent, each a named row saying what it is done to
  (the ground, a person, a stockpile, the camp, a deer, the colony) and the
  lowest rank that may do it. The rows so far: raise the stake, lay a path,
  zone a stockpile, zone the camp, zone housing, give a job, follow a person (the
  interface's own: nothing in the colony changes), set a reserve (wood,
  straw, meat, vegetables), set the winter store, spare apples, spare deer.
  Every interface acts through one door, `Perform (Order)`: the panels, the
  context menus, the game's clicks and the command line (`Castle.Scenario`)
  all build an order and hand it over, and get back whether it was done,
  a count (blocks laid, cells zoned) and, if not, why (not permitted; no
  such target; not now; the ground refused, with the reason in words).
  The player and the serfs are one kind of actor using this one table; today
  the player may do every row and a serf none, and `colony_check` proves
  the refusals. `Menu_For (actor, thing)` is what that actor may do to that
  thing as things stand: it is the context menu's contents, so a menu grows
  as an actor's rank does. What is not in the table: the band's own work,
  and `Supply`, which conjures goods for scripted starts and is nobody's to
  do.
* **Jobs.** A right click on a person gives its menu: a job for each
  there is (its own lit) and Follow. Tab opens the band, where the Band
  tab lists everyone: the name (click it to follow them), the job (click
  it for the same menu) and what they are doing now. Gatherers pick and pull, foresters fell and carry
  their logs, porters fetch straw and stone, hunters hunt deer, the cook
  keeps the camp; the unassigned wait at the stake, taking a few steps now
  and then.
* **Gathering.** A gatherer picks berries off bushes, pulls wild
  vegetables (a plant at a time, 2.5 s each, a basket of 12) and, from
  summer's tenth day to the end of autumn, picks apples (a tree bears about
  40 a year, a basket of 20). What it goes for is one score: its distance
  from the gatherer plus half its distance from the stake (near ones first,
  on the colony's side rather than beyond it), over a pull. Berries pull 1,
  apples 0.9 (fruit last). Vegetables, the cook's best greens, pull 1.3, a
  little further being worth it; half as much again when the band has less
  than a day's food stored (none of that at two days), and up to twice that
  again as the vegetables in store fall short of their reserve (40, in the
  band panel); their reach grows the same way from 60 m to 80 m from the
  stake. With no vegetables in store at all it goes for nothing else while
  there are any in reach, and a basket part full is filled with the same.
  It reserves a bush or an apple tree, so no two work one (**a reservation
  is not saved: the loader gives each back by whose errand the bush or the
  tree is**; a tree's by `M.Tree` in every state since 2026-11-21, when an
  apple tree being picked turned out to be nobody's after a load; of two
  pickers at one bush the loader makes the later of the band its holder,
  which a straight run does not: owed); it walks there
  by `Castle.Nav`; a full basket, or what it has when there is nothing
  left in reach, goes to the nearest stockpile cell with room (room is
  reserved too). When it can't work it says why: nothing to gather in
  reach, nowhere to put berries, can't get there. A bush or a cell it can't
  reach is left alone for a minute instead of being tried every step. A
  vegetable pulled leaves bare ground and grows back 10 game days later,
  but not in winter.
* **Bushes.** Found by looking through the loaded stacks near the stake,
  a few a step, nearest first; a bush is its berry-bush blocks joined
  across neighbours, stack edges included, a handful to a block. Each
  handful turns the ripe block nearest the hands to bare bush (an edit like
  the player's, so it is saved and drawn like any other), and the bush
  thins as it is picked; it bears again 6 game days later, but not while it
  is winter.
* **Felling.** A forester goes for the standing tree with the lowest
  score, as a gatherer does for a bush (its distance plus half its distance
  from the stake, within 60 m of the stake, or as far as the foresters have
  had to look since 2026-11-19: `Fell_Reach_M`), reserves it and walks to the
  trunk. It chops two-handed (12 s for a slim trunk, 24 s for a thick one):
  the axe wound up over the dominant shoulder, swung down into the trunk at
  waist height, the bit left in the wood a moment. Then the tree comes down
  away from the forester: every block the generator gave that tree
  (`Castle.Flora.Tree_Blocks`: the tree drawn on its own into a scratch
  stack), trunk above the stump, branches and crown, is taken out where the
  world still holds it, as block edits like the player's, so a felled tree
  stays felled in saves. A neighbour's trunk is left whole where one of the
  felled tree's branches ran through it (in a thick forest a crown drawn on
  its own can cross where another tree stands: three such blocks to a
  hundred broadleaves since generator 13; in the world that block is the
  neighbour's trunk, since every trunk is drawn before any bough). Bites out of a
  neighbour's crown stay, on purpose: a falling tree takes foliage with it
  (the designer's call). A stump a block tall
  is left, with the roots under it. Its logs, a metre long and 20 cm thick, one for every 2 m of trunk
  per block of width (1 to 8), lie stacked a metre past the stump, along
  the way it fell. The colony finds trees by asking the generator (the game
  hands it `Flora.Tree_At` and `Flora.Tree_Blocks`) for those whose trunks
  stand in the stacks it looks through; one whose trunk is already gone is
  taken as down.
* **Logs.** The logs of a felled tree are its forester's own: no one else
  touches them, and the forester carries every one home before it fells
  the next tree. A log goes one at a time on the off shoulder, fore and aft,
  steadied with the off hand (the axe stays in the dominant one), to the
  nearest stockpile cell that holds wood and has room, or an empty one; a
  cell takes 20, stacked in rows of four. With nowhere to put them the
  forester waits and says so rather than fell more. Logs whose forester is
  given other work are taken over by the next forester to come for wood,
  and a pile a forester can't get to is left a minute, so one out of reach
  doesn't stop the felling.
* **Fetching.** Porters never carry wood. They fetch, first things first
  (counting what is stored, carried, and a full load for each porter
  already out for it), while a stockpile has room:
  * straw first, for the thatched roofs, up to its reserve: tall grass cut
    a block at a time (0.8 s each, 6 to a load, 40 to a cell), the porter
    crouching to it as a gatherer does to a bush;
  * then stone, as much as is wanted: prised off boulders a block at a
    time (2 s each, 4 to a load in the porter's sack, 40 to a cell),
    standing on the ground beside the rock, never on it. Only blocks that
    stand out of the ground on some side are taken: boulders lie half
    buried, and what is under the grass stays, so a boulder carried off
    leaves level ground, not a pit. Stone has no reserve: it is fetched on
    demand. A colony starts wanting 20 (`Stone_Quota`, for paving the paths
    once there are masons); the work that uses stone will ask for more
    (`Castle.Colony.Want`) and take it away as it is used.
  * Water is fetched since the storehouse was fitted out (2026-11-17): a
    porter draws it where it runs and can be waded, two pails at a time,
    into the storehouse's water barrels while they have room ("Water",
    above). Nothing takes it out of the barrels again: it waits for a use.
  When the colony looks through a stack it notes whether there is tall
  grass, a boulder or shallow water in it; a porter searches only stacks
  noted for what it wants, nearest first, and a stack found to have none
  left loses its note. A kind it can't find or can't reach is left a minute
  for the next ("no straw in reach"); with nothing wanted it says "the
  stocks are full". Stockpiles show sheaves stacked and stones in a heap.
* **Hunting.** While meat is short of its reserve (20 by default, counting
  carcasses on their way) and deer are not spared, a hunter goes for the
  nearest grown deer of a herd larger than three. It walks until 30 m off,
  then stalks crouched (seen only within 7 m) toward a spot 15 m from the
  deer, planning again as the herd drifts; 90 s without a shot (a wall,
  water) and it leaves that herd five minutes. Within 18 m and with a clear
  line (blocks and leaves stop an arrow) it draws its short bow 1.5 s and
  looses: the hit is decided then, likelier nearer; the arrow is only drawn.
  Hit or miss, the herd bolts. The kill lies where it fell; the hunter
  carries it home across its shoulders and butchers it at the stockpile
  (meat and a hide) into cells reserved first. **Meat is counted in
  pounds, and a deer's is salted as it is butchered** (2026-11-12; "The
  lord's cart", below): a doe gives 60 lb, a stag 75, a young stag 45, a
  fawn 20, all of it kept if the stockpiles hold a pound of salt for every
  ten of meat, a quarter of it if they hold none. (Until then, and with
  `--no-curing`: joints, doe 8, stag 10, young stag 6, fawn 3.)
* **Where none of its 204 places takes the lord's cart there is no cart** (looked into
  2026-11-22, and left by his "leave the cart doing whatever it's doing right now, we are
  going to work on the logistics soon"): a metre apart from 4 m to 20 m from the fire on
  twelve bearings; a place takes it where the ground under its bed and half a metre round
  lies level within a block, is grass or earth, no zone's, with no path by. On a hillside
  none may (three of the squares run with a band that day: no salt, a quarter of each deer
  kept). A mend that looks further is a patch outside the repository
  (`~/CASTLE_GAME/releases/wip/lords_cart_looked_for_further.patch`), his call.
* **The lord's cart** (John, 2026-11-12: "we need to up the amount of meat
  a single deer can provide, we are looking at 60lbs of field dressed meat
  from a deer that should be enough to feed a camp for a couple of days
  when smoked or cured ... the player is a minor noble tasked wtih
  improving the land by their lord, taxes on production would come after a
  few years, so the lord provides a small workforce a minimum of starting
  supplies so for now lets just add a cart with salt in it for curing, we
  can expand the supplies later and work the story in as we get to the
  players role, but for now that way a single deer can provide for the
  camp for a couple of days"; first values and first rules of mine, his to
  tune; the tunables are in `castle-colony.ads`, "The lord's cart").
  * **Meat by the pound.** A pound is worth 48 points in the pot
    (`Pound_Stew`), so a doe's 60 lb are 2,880 points: two days' food for
    six, who eat 1,392 a day. Twenty pounds to a load, 120 to a
    stockpile's place. The meat reserve is in pounds too (the default is
    20 as it was: hunters go out when less than that is stored or on its
    way; the reference runs' `--reserve meat 60` is a deer's worth).
  * **The cart.** The band arrives with it. At the colony's first step
    with a stake raised it is stood on the first level, open ground found
    going out from the stake a metre at a time from 4 m (to 20 m at the
    most) and round it from the north, its long side to the stake: grass or
    bare earth with nothing on it but grass, no zone's and no path's
    (whatever a scripted start has marked by then it keeps clear of), and
    nothing about it standing higher than its middle. It holds 240 lb of
    salt (`Cart_Salt_Lb`: forty does' worth). **It is a thing in the
    world**: its bed is a slab of timber over the ground, 2 m by 1 m, its
    top at 0.75 m (32 blocks of `Log`, hidden under the boards that are
    drawn round it), so nobody walks through or under it, a stockpile or
    housing marked across it leaves its ground out as it would a tree's, a
    camp marked over it and a path laid through it are refused ("the
    lord's cart stands there: it cannot be moved yet"), it casts its
    shadow, and it can be pointed at (`Castle.Pick`: `A_Cart`; its sheet,
    `Castle.Views.Cart`: the salt left in it, the salt in the stores, what
    a pound cures, the deer salted and the meat lost unsalted, where it
    stands). It cannot be emptied by the player or filled again yet. **A way asked to
    a place on the cart is planned to the nearest place beside it**
    (`Off_Cart`, in `Route_To`): a goal under its bed has no ground to
    stand on, and the planner looks over all the band's ground before it
    gives such a one up (57 ms, where a plan is 1; found in the stage 6
    run, whose idle hands strolled there).
  * **Pulled into the stockpile nearest it** (John, 2026-11-13: "the cart,
    can they pull it into the closest stockpile zone?"; first rules of mine,
    his to change). Once there is a stockpile zone, one of the band pulls
    it there, as an extra task (`Go_Tow`, in `Think_Build` after the camp
    and its seats and before the paths; counted against the limit on
    extra hands; the states `To_Tow` and `Towing`, on the end): it goes to
    the bar across its shafts, takes them up (its bed out of the world:
    `Lay_Bed`) and pulls it at six tenths of its walk (`Cart_Tow_Pace`) to
    a place held for it from the moment it set out (`Find_Cart_Place`,
    `Cart_Bound`, `Goal_P`): two of the zone's places side by side, empty,
    the nearest such to the cart, in the zone nearest it that has them,
    its bed square to the grid along the way the two lie, on level ground
    (any ground a path is laid on), nothing over it, nobody standing
    there, a way from the stake to beside it and to its shafts. There it
    is set down, its bed in the world again, its shafts the way it came.
    **The cart is in one place at every moment**: standing (`Cart_Set`,
    its bed in the world) or in tow (`Cart_Towed`, no bed; drawn its middle
    2.3 m behind its puller, `Cart_Shaft_M`, turned as it goes, the prop
    under its shafts gone, the puller's hands forward on them). Its puller
    called away, interrupted or dead, it is set down where it is, or the
    nearest place within ten metres it fits, or back where it stood
    (`Keep_Cart`, `Set_Cart_Down`, every step). **Nothing is put on a
    place under it** (`Under_Cart`, in `Takes`, the one test of what a
    place takes: `Go_Store`, `Room_For`, `Can_Store`, the butchering's,
    `Supply`'s). **Nor beside its wheels or under its shafts** (2026-11-23;
    `Cart_Reaches`, `Set_Cart_Room`, `--no-cart-room`, not saved; his
    picture of a sack under its wheel): the cart as it is drawn reaches past
    its bed, so the two places to either side of the bed and the two its
    shafts lie over take nothing either (six places more of a stockpile's
    hundred); what lies there already stays until it is taken. Where the cart
    goes and stands is untouched. Standing on a stockpile's ground it stays. Nothing else
    of it changes: its salt is fetched to the stockpile and used as before,
    and nobody sets out with it while a hunter is at it for salt.
    `--no-cart-pull` (`Set_Cart_Pull (False)`, saved: blob 25) leaves it
    where it stood; `colony_check`'s own `Reset` holds it off. By the
    reference stake it is pulled the first morning, at a quarter past
    seven with the camp built, at half past nine when the band builds it.
  * **A hunter keeps salt by for its kills.** With empty hands, before it
    goes after deer: while the stockpiles and the band's hands hold less
    than 16 lb of salt (`Salt_Keep_Lb`: two stags' worth), the cart has
    some, there is room to store it and nobody is at the cart already, it
    fetches a sackful (20 lb) from the cart to a stockpile ("going to the
    lord's cart for salt", "taking salt from the lord's cart"). Salt is a
    stored good like any other (a place holds 240 lb; a sack to twenty
    pounds is drawn), but nobody of the band can make it, so it is never
    in the demand table and never asked for.
  * **Salting.** As a deer is butchered, a pound of salt is used for every
    ten of its meat (`Lb_Per_Salt`: six for a doe) and all of it is kept.
    With none in the stockpiles only what can be eaten before the rest
    turns is kept, one pound in four (`Fresh_Div`); with some, that much
    of it is salted and the rest goes as unsalted meat does. **Nothing
    spoils once it is stored**: spoilage is a later stage's, and until
    then this is the whole of what salt does. Smoking is not built.
  * `--no-curing` (`Set_Curing (False)`, said before the stake) is the
    band as it was: no cart, no salt, meat in joints. The seven older
    reference runs are held at it, and `colony_check` runs every section
    but the cart's with it. `--cart-salt LB` sets what the cart starts
    with (0: a band whose salt has run out). The log has a line for it
    ("salt: 140 lb in the cart, 16 stored; 14 deer salted, 0 not, 0 lb of
    meat lost"), and the food line the same on its end.
  * Measured on the reference band (seed 1, today's pace, the standing
    orders, 41 days through the first winter): 17 deer are killed where 33
    were, 102 lb of salt used (120 left in the cart, 18 stored), no meat
    lost; from the fifth midnight on the band has eleven to seventeen days of
    food in hand (it had three to twelve), with some 300 lb of meat stored; nobody
    is hungry at any midnight and all six see the spring, as they did at
    this pace without it; food is asked for at three of the forty-two
    midnights (vegetables at most of them: the gatherers go for those and
    little else, and put 423 berries in the pot where they put some
    7,000). **Nothing was retuned for it**: what a first winter should
    cost now is John's to say. With no salt (`--cart-salt 0`) the same
    band kills 34 deer and loses 1,432 lb of their meat, has between five
    and a half and twelve days of food in hand, and nobody is hungry or
    dies: an unsalted doe's fifteen pounds
    are still three times what her eight joints were.
* **Demand** (stage 5c; its rules stand as built, John's polish to come;
  `docs/production/briefs/Stage_5c_brief.md`). Nothing sets a producer to
  work but something asked of the stores (all the stockpiles together).
  The table has a row for everything asked (`Demand_Row_At`): the band,
  its day's food; the camp, its fire's logs by the day (2; 3 in winter;
  it was 4 and 6 before the fire burnt eight hours a log), its seats' once
  and, until its hearth stands, the stone and wood that takes; the paths,
  their stone; a housing zone, the logs and sheaves its houses being built
  are still short of, once (stage 6a); and the player's orders,
  the surpluses (wood 20, straw 20, meat 20, vegetables 40, the winter
  store in days of food, asked for all year). A good with users is asked
  for once the stores are down to its surplus and a day of its use
  (`Ask_Below_Days`), and until they hold the surplus and two
  (`Ask_Until_Days`); one nobody uses by the day, while it is short.
  Whether each is being asked for is saved; stock is taken once a colony
  second. Every producer puts the one question, `Asked_For (kind)`: a
  forester for wood, a porter for straw and stone, a hunter for meat
  (asked for by its own count, or because food is and there is a cook to
  make food of it), a gatherer for its kinds (food asked for: anything;
  else only the kind short of its surplus). With nothing asked they take
  home what they have, say "enough food in store" and stroll about the
  camp. Needs are not gated. The Stores tab shows the table
  (`Castle.Views.Demand`): what the stores have of what is wanted,
  "asked" or "asked of nobody", and who asks. `--no-demand`
  (`Set_Demand_Chain (False)`) is the colony as before: gatherers never
  stop, hunters go by the meat reserve, wood has no limit unless given.
  Not there yet: demand per stockpile; prices.
* **Standing orders.** In a stockpile's menu (right click it) and in the
  band panel's Orders tab, a line each with a minus and a plus; the
  protections are in the Orders tab:
  * Spare apples, on by default: apple trees are never felled.
  * The wood reserve, in steps of 10, no limit by default. Once the colony
    has that many logs (stored, lying and carried), the foresters fell no
    more and say so.
  * The straw reserve, 20 by default, in steps of 10 (0: none fetched),
    shown as what the colony has against it; beside it the stone the colony
    has and how much is wanted.
  * Spare deer, off by default: no hunting at all. Beside it the meat
    reserve, 20 by default, in steps of 10 (meat stored and carcasses on
    their way). A herd of three or fewer is never hunted, whatever the
    orders.
* **The clock.** The colony runs in fixed steps, 20 to a game second, so
  the same start gives the same colony whatever the frame rate. Space
  pauses, 1, 2 and 3 run it at that many times (the status panel has the
  same buttons); the sky's clock goes with it.
* **Its ground.** The stacks within reach of the stake stay loaded
  wherever the camera goes, since the band works there whether anyone is
  looking or not; the colony waits while any of them is still streaming in
  (just after a load, say), so no bush is read as bare and no way as shut
  for want of its blocks. How far that is, the colony says
  (`Ground_Reach_M`): its work radius as a rule (60 m, which with the
  hosts' margins is the 88 m and 104 m circles the game and the runner have
  always kept), so nothing changes while nobody goes further; wider while
  the band looks further afield for what its camp takes (next), and as far
  as any stretch of path still to lay. And, since stage 6a, as far as
  any housing zone reaches, for good: people build there and live there.
  And, since 2026-11-14, as far as a stockpile or the camp reaches
  (`Stores_Far`: those within the 256 m the band's ground ever goes; one
  zoned past the work radius used to be served only while the camera kept
  its ground loaded, and further than 256 m is still not served). The game
  asks for the wider ground
  and the colony pauses until it is in (a moment's stop each time it
  widens); the runner brings it in before the next step.
* **How far the band looks** (John, 2026-11-10: "Don't place a distance
  limit on initial gathering, if they have to walk 200m to get stone they
  walk 200m"). The camp's stone and deadwood are looked for within reach of
  the band's work first. When all the ground that near has been looked
  through and holds none that can be got at, the band looks further, a
  ring of 16 m at a time (`Reach_Step_M`), each ring brought in and looked
  through before the next, until there is some; whoever is free walks out
  for it, however far, and the rest go on with their work. The camp's
  sheet says "Looking for it: as far as 156 m from the stake". Once the
  camp stands and everyone is back, the band looks no further than its
  work again and the far ground is let go. Past where anyone gathers
  (88 m) a stack is looked through for boulders and trees only, not for
  its bushes. Deadwood is not looked further for while there are logs
  stored and a cook or a forester to bring them. The limit is the
  engine's: 256 m (`Far_Reach_Max_M`), about as much ground as can be kept
  in beside the view (some 3,800 stacks); at it the sheet says "Looked for
  it: as far as 256 m: no further is known". Ordinary work keeps its 60 m.
  Measured on seed 1 with `--stone-from 150` (stone is never far on this
  world: of ten sites tried across it where a camp could be zoned, none
  had to look): the band looks out to
  156 m in half a game hour (the ground widened six times), the first
  stones are back five hours later (a 150 m walk each way is four game
  hours), the hearth stands at four in the afternoon; the same state at
  two worker counts and through a save taken mid-trip. `--stone-from M`
  (`Set_Stone_From`) is for such measurements: the camp's builders take no
  stone from nearer the stake than M. Not there yet: looking further for
  anything but the camp's building; giving up a boulder that cannot be
  reached in favour of one further off when more than a few are in the way
  (a member remembers eight places it could not get to).
* **Saves.** The colony goes into the save (format 5): members, jobs,
  loads, reservations, routes and all, so a load carries on exactly where it
  was. A save with no colony in it loads with none. The colony's own blob
  has a version of its own: 2 adds the trees it knows, the log piles and the
  standing orders; 3 what each porter is out for, the reserves and the
  stacks' notes of grass, boulders and water; 4 which forester each log
  pile belongs to, and what is wanted; 5 the herds (`Castle.Herds`' own
  blob, with a version of its own); 6 the hunt: each hunter's prey, the
  carcasses lying or carried, the meat reserve, Spare deer and the kills
  and shots so far (arrows in flight or in the ground are not kept); 7
  the needs: whether they are on, the food eaten, each one's belly and the
  meal it is going for; 8 the camp and the cook (the fire, its stack, the
  pot, the seats, what went into the pot and what was eaten raw), the
  vegetables pulled and when, each apple tree's crop, each one's bowl and
  place at the fire, whether it is fending, its mood, its hunger in
  winter and whether it is dead; 9 grain; 10 the winter store order; 11 the
  zones (each one's kind, borders and cell count, the zone of every
  stockpile cell, which is the camp's) and each member's director; 12 the
  skills (whether they are on, how many skills the blob holds, each
  member's level in each); 13 the demand chain; 14 each zone's ground (the
  way its lot lies and its strips of block columns), whether the camp
  takes labour, the fire's dying down, what is built on each zone (whether
  it stands, what has been delivered) and the patch of the camp's ground
  each member is at; 15 how far the band is looking, the measuring bar on
  near stone, and the metre of path each member is at (what of a path is
  still to lay is not saved: it is read from the ground); 16 the limit on
  extra hands as set, whether paths are laid by the stretch and the metres
  each member has laid of its own, whether a camp's floor is levelled,
  the level of this one's, the turf's earth lying on it and what is left
  to dig and fill as last counted, and what is asked and kept of earth
  (the kinds a version knew are fixed ranges, `V4_Kinds` to `V16_Kinds`:
  the next kind added closes the last and opens its own); 20 the houses
  (their front yards and their stone with them) and the house each
  builder is at (`habitation.md`, "Saves"; a blob of before loads with
  none, but 18 and 19, housing before its ground was walled, which are
  refused). Older blobs still load: a version 1
  colony finds the trees of the stacks it had looked through once its
  ground is in; before 4, piles are nobody's (a forester takes them over)
  and the stone reserve becomes the stone wanted; before 5 the herds are
  placed afresh once the ground is in; before 7 everyone is fed and awake;
  before 8 there is no camp and nobody has cooked (`colony_check` loads a
  version 7 blob, `tools/colony_v7.bin`); before 11 the stockpile cells
  become a zone for each group that touches side to side (how they were
  zoned is no longer known, so two zoned touching load as one), the camp
  gets its zone, and everyone with a job is the player's to direct, the
  unassigned nobody's (`tools/colony_v10.bin`, written by the version 10
  code on the check's meadow with a gatherer mid-carry); before 12 skills
  are on and everyone has the levels they would have arrived with
  (`tools/colony_v11.bin`, a forester mid-chop). A version 12 blob says how
  many skills it holds, so one written before a skill was added, or after
  one this build does not know, still loads. Before 14 a zone's ground is
  the square metre under each of its cells, and the camp's its square, as
  they were, whether or not a path runs over them; a camp of then stands,
  as it stood, the camp takes labour from then on, and what was on its
  fire burns on (`tools/colony_v13.bin`, the cook stirring over a burning
  fire). Before 15 the band looks no further than its work, and its paths,
  laid when they were marked, are read from the ground as laid
  (`tools/colony_v14.bin`, the camp being built). Before 16 extra tasks
  take a third of the band and a path is laid by the stretch from then on
  (those at a metre finish it, then one to a stretch), a camp that stands
  is left as it lies, and one still being built has its floor levelled
  (`tools/colony_v15.bin`, six laying two paths). Version 17 changes
  nothing of the colony's own: the herds' blob inside it is its version 2
  (`deer.md`, "Saves"); a blob before it loads with the herds fleeing
  together from then on (`tools/colony_v16.bin`, a herd mid-bolt).

What it costs: in `colony_check` six members take about 0.003 ms a step
on average (debug build, short routes on a small meadow). On real ground
the routes are the cost, 3 ms or so each in release, one whenever someone
sets off.

Scripted, for headless runs: `--stake X Y`, `--path X0 Y0 X1 Y1` (up to
16), `--stockpile X0 Y0 X1 Y1` (up to 8), `--gatherers N` (the first N
start as gatherers), `--foresters N` and `--porters N` (the next N of each),
`--hunters N`, `--cooks N` (the next N after those), `--camp X Y` (the
camp marked: the band builds it), `--camp-built` (that camp built on the
spot), `--stoke HOURS` (the camp built and its fire burning from the start
with that much on it, as `--supply` puts goods in the stockpiles: a fire
to look at without waiting for the band), `--paths-built` (the paths laid
on the spot), `--no-labour` (the colony as it was before what the player
marks took the band's labour: the camp stands and a path is laid when
marked, and the fire feeds itself from its stack, a log every four hours;
`--instant-camp`, its first name, is still taken), `--stone-from M` (a
measuring start: no stone for the camp from nearer the stake than M),
`--extra-hands N` (at most N at extra tasks at once, not a third of the
band), `--all-hands` (extra tasks as before they were limited: everyone
before its job, paths laid by the metre), `--no-level` (a camp's floor
left as it lies), `--no-beds` (nobody makes itself a bed of straw: the
band as it was before the pass after stage 6a; `habitation.md`),
`--pace P` (the band's pace, below: 1 is the band as it worked and walked
until 2026-11-12), `--no-cook-hold` (the cook keeps nothing in the stores
for the pot, as before the pass's fourth round: `needs.md`, "What the cook
keeps"), `--no-curing` (no cart, no salt, meat in joints, as before that
round) and `--cart-salt LB` (the salt the lord's cart starts with): "The
lord's cart", above, `--no-ladders` (roofs thatched from the ground:
`habitation.md`, "A ladder for the roof"),
`--housing X0 Y0 X1 Y1` (a housing zone, up to 8), `--housing-inside X Y` (all the ground inside
the paths round that point) and `--homes-built` (a hovel for everyone those
zones have room for, built on the spot): `habitation.md`,
`--winter-store DAYS`, `--supply KIND N` (N of it in the stockpiles at the start: meat, berries,
vegetables, apples, wood, stone or straw), `--wood-reserve N`,
`--reserve straw|meat N`, `--spare-deer`,
`--fell-apples` (lift the order that spares them), `--no-needs` (nobody eats or sleeps: for the stress test's band of forty-eight, which the land cannot feed), `--no-skills` (everyone
at the one pace), `--by-skill` (the jobs above go to whoever is best at
each, gatherers first and so on in that order, not to the first N members),
`--skills-at LEVEL` (everyone arrives at that level, 0 to 1, in every
working skill: a band of novices or of masters, to measure what skill is
worth), `--job I JOB` (member I's job, after the counts: gatherer,
forester, porter, hunter, cook or none),
`--band N`, `--speed N` (0 to 3 in the panel, up to 240 here for long
runs), `--log-hours H` (a line on the band's food every H game hours: the
living, confidence, bellies, stew, stores, what went into the pot, raw
food eaten, kills, vegetables pulled; the runner's `--who` puts under each a
line for each of the living: its belly and what it is doing, and one for
each herd: its deer, where its node is, whether it is in flight, and who
of the band is nearest it, how far off and at what). `--record DIR N`
saves N frames a thirtieth of a second apart (times the speed), and
`--save FILE` writes a save when `--frames` or `--record` ends; the log
gets one line on the colony at every save and load. `--deer-scatter` is the herds as they were before they fled
together (`deer.md`).

```sh
# a homestake by the berry bushes east of the default view, three gatherers, at 3x
./bin/castle_game --at 1181 1076 --cam 2.5 0.8 15 --stake 1178 1078 --path 1176 1076 1194 1076 \
                  --stockpile 1180 1073 1184 1075 --gatherers 3 --speed 3
# the same place with two foresters and a porter (about five trees felled in four minutes)
./bin/castle_game --at 1181 1076 --cam 2.5 0.8 22 --stake 1178 1078 --path 1176 1076 1194 1076 \
                  --stockpile 1180 1073 1184 1075 --foresters 2 --porters 1 --speed 3
```

### The band's pace

John, 2026-11-12: "also can we increase the work and travel speed of serfs
by about 50%". A colony has a pace (`Castle.Colony.Pace`, `Set_Pace`;
`Serf_Pace`, 1.5, is what one is founded with) and **every work rate and
every pace over the ground is multiplied by it**: `Work_Rate` (so every
timer of work: picking, felling, reaping, butchering, tamping, laying a
block, lifting, putting down) and `Walk`. Nothing else goes by it: not
hunger or sleep (the clock's), not `Vigour` (practice goes by that: an
hour at the work teaches what it taught), not a hunter's patience at its
aim, not `Castle.Nav.Walk_Speed` (the herds, the walkers and `path_check`
go by that), not the deer. It is saved with the colony (since blob 22); a
colony loaded from before it keeps pace 1. `--pace 1` is the band as it
was: the seven older reference runs are held at it, and `colony_check`
starts every section at it but the one that checks the pace (its own
`Reset`), since both were tuned at it.

What it does to the reference band (seed 1, the reference site with its
standing orders, `tools/reference_run.sh 41 --winter-store 10 --reserve
meat 60`, the game's defaults otherwise) is in the pass's handoff,
"Measured": more food in hand sooner, and a stockpile of 48 places
filled. **Nothing was retuned for it** (`needs.md`, "How it was tuned",
was measured at pace 1): his to ask for.

### colony_run: the real world with no window

`./bin/colony_run` runs the colony on the generated world with no window
and no GPU: the ground within reach of the stake is streamed in as the
game streams it, and the colony steps on its fixed clock as fast as the
machine goes (about four game days a second in release; a 41-day run from
summer through the first winter takes 11 s). Nothing waits on real time,
so the same command line gives the same run to the last unit, whatever the
machine or the number of workers; the last line is a hash of the colony's
save blob (`state: ...`) and `--expect HASH` turns that into a test. It
takes the colony's options above (they are parsed and applied by
`Castle.Scenario`, which the game uses too), and `--seed N`, `--day D`,
`--time H`, `--days N`, `--log-hours H`, `--workers N`, `--load FILE`, `--nav-stats` (at the end: what the colony's steps, the walking map and the routes cost, the twelve slowest plans, how often the herds were frightened, how many of their ways were refused as out of reach dry, how many plans ran out of budget and what the pieces of ground had said of them, and how many were answered from the memory of one that had), `--nav-log FILE` (run it with `--no-memos`, or the askings answered from memory are left out; a line for each plan that runs out of budget as it happens: the day and hour, from where to where, its budget and wade, what the pieces said, how far short it ended, and who of the band stood nearest where it began and what they were doing), `--try-plan X0 Y0 Z0 X1 Y1 Z1 WADE` (at the end: a herd's way asked of the ground as it then is, with what it came to; `--try-budget N` the floors it may look at, `--try-within X Y R` the ground it keeps to, `--try-refuse` not made for if out of reach), `--prove-dry` (slow: every dry way the pieces of ground call out of reach is searched for whole, and the run stops if one is there; `routes.md`), `--full-summaries` and `--whole-bricks` (each stack's ground summary kept whole, each fine brick written whole, as before they were kept small: storage only, the run the same), `--ground-stacks N`, `--mem` and `--no-mesh` (measuring what the ground costs to keep: the ground within N stacks of the stake brought in, in batches, 400 being the whole map; what is kept of every stack that is in, counted by part, with what the process holds; the workers making no meshes, which the runner throws away anyway. A run with more ground in ends in the very state of a run on the colony's own ground, since 2026-11-15: the colony reads its own ground and nothing beyond, "The colony's own ground" below; before that it was another run. `world.md`, "What a stack costs to keep"), `--no-mending` and `--no-memos` (the walking map read whole after every change; every search for a source reading the ground again, nothing of housing kept, and no plan that ran out of budget remembered: what only saves work, so a run must end the same with them off),
`--save FILE` (a save the game opens with `--load`), `--floating` (at the end: plants standing on air within the band's reach of the stake, each with where), `--who` (with every log line what each of the band is doing, and where one that starves or cannot get somewhere stands), `--tree-stats` (with every log line the trees standing by how far from the stake they are: to fell within the work radius and how many of those are somebody's, apple trees, and to fell 60 to 80 m, 80 to 100 m and further off, and where each stands when twelve or fewer are left near; at the end how many of the trees to fell within the foresters' reach can be got to from the stake at all, and each forester's serf-hours by what its status said), `--haul-stats` (at the end: the kilometres walked with something in the arms, sampled a colony second at a time; the loads it counts are every time arms are emptied), `--store-stats` (at
the end: the serf-hours the living stood with a load and nowhere to put it,
by what they held, and empty-handed for want of room; when a load first
found no place; the places in use; loads sent to an overflow place, the
most of those in use at once and at the end: a measure, nothing decided
by it), and `--deer-track
FILE` (a line for every deer after every colony second: the second, the
deer, its herd, where it is, whether it is in panic, the rows of water it
stands in, its herd's node; for looking at how the herds move: `deer.md`,
"Measured").

**Measures of 2026-11-23**: `--builder-stats` (who stands still with a block in its own block column,
by what it is doing, and how far a builder walks from one square metre of a site's ground to the next:
`habitation.md`), `--builder-track FILE` (where each square metre was worked from), `--seam-stats [M]`
(within M metres of the stake, 60: trodden ground two blocks or more off the trodden ground beside it,
and earth left standing between a path and what is built; `--seam-hours H` counts every H game hours
too, `--seam-list N` says the first N), `--ground-map X0 Y0 X1 Y1` (at the end, the block columns of
that box drawn twice, north at the top: each one's top over the lowest, and whose each is: a path laid,
stone, a house, a hovel's lot, a path planned, a zone's number), `--watch MEMBER S0 S1` (that member
each colony second from S0 to S1: where its feet are, the top of the ground in its own block column,
the walking map's floors of the cell it is in, what its status says and where its hands go: for finding
why someone stands in the ground or over it). **Read the whole of "in the ground", not only the part
that is a builder making ground ready**: the rest of it was people standing in a step at the stockpile
(`routes.md`, "At the height of the place stepped into"), and the round that changed the ground where
people stand had made it five times what it was before anyone looked (517 serf-seconds to 2,540 in
eighteen days; 703 with the places made level alone taken out, 238 with that and the cart's room).

**A deer is butchered by whoever carries it home** (2026-11-23; `Set_Kill_Home`, `--no-kill-home`, not
saved; `Carcasses_Dropped`; his "a hunter placed the deer in the stockpile without quatering it, I have
only seen it happen once"). A whole deer is laid down in three ways: its carrier is given another job,
there is nowhere to butcher it (no room, or no way) and its carrier is hungry or night has come, or its
carrier dies. By the band's own doing none lay in a stockpile in six runs of 41 days (187 deer). A
hunter given another job as it carries its kill put it down where it stood, and with no other hunter it
lay there for good; it brings the deer home and butchers it first now, and only with nowhere to butcher
it puts it down as before. `colony_run --carcass-stats` counts each way and says every whole deer that
comes to lie on a stockpile's ground.

**The player removes a stockpile** (2026-11-23; `Remove_Stockpile`, `Removal_Refusal`,
`Stockpiles_Removed`; order `Castle.Actions.Remove_Stockpile`, on a stockpile's own menu: "Remove this
stockpile", then "Keep this stockpile"; his "the stockpile zones just disappeared at some point, let
the player remove them if they want to"). Nothing but this order takes a stockpile away. Ordered
removed (`Zone_Rec.Leaving`, `Zone_View.Leaving`; saved: blob 46, 30 to 45 still read), its places are
closed: nothing more is put there, what lies there is taken from first, and a porter with empty hands
carries a load of it to a place with room elsewhere before anything else of its work (`Go_Move_In`,
`Go_Clear_Closed`: the stores' move, which takes nothing unless there is room for it elsewhere). When
nothing lies there, nothing is on its way and nobody's errand names one of its places, it is gone
(`Drop_Emptied`, once a colony second): its strips out of the list, **its places out of theirs, and
whoever holds a place's number after them told the new one** (a member's `Cell` and `Cell2`, a fail
memo of a place: anything new that keeps a place's number is renumbered there). The zone keeps its
number, empty. The order taken back opens its places again (one a tree stands in stays closed). The
stockyard is refused. **With nowhere else to carry to the stockpile stays, closed, for good: a band
whose only stockpile is ordered removed, with none put down in its place, can store nothing and
starves** (`tools/today_run.sh 41 --later 72 remove-stockpile 2`: everyone hungry from the seventh
day, thirteen dead by the twenty-eighth; found after the round's gate and put to John, 2026-11-23). In the game as it is played with no storehouse, a second stockpile put down
after two days and the first ordered removed after three: gone 23.3 game hours later, thirteen living
at the end of eight days, the cart pulled to the other stockpile by the band as it pulls it to any.
`colony_run --later HOURS remove-stockpile ZONE`.

**A stockpile's place is made level when something is first put on it** (2026-11-23;
`Level_Places`, once a colony second; `Set_Place_Level`, `--no-place-level`, not saved; his "the straw
half in the ground and half outside ... we might have to flatten stockpiles"). A place is a square
metre, sixteen block columns, and what lies on it is drawn at the height of its middle (the highest
of the four columns round it); on ground that steps under it the columns a block higher stood
through what lay there, and those a block lower left it over air. In the game as it is played: of
the 47 places that held something at the end of the third day, 21 had a column over the place's level
and the other 26 one under it (`colony_run --place-stats`), and of the 13 at the end of 41 days, 5 and
8; with the rule, none of 51 and none of 11. From the moment a
place of a stockpile holds something or has something on its way, its block columns that are the
zone's ground are brought to the place's own level, `Place_Level_B` (three blocks) at the most, their
tops as they were. Each place by itself, so a stockpile on a slope becomes steps a metre square;
nothing is moved under a place nothing is put on. Not the stockyard's places, nor under a tree's
foot, through water or under the cart. The earth is the turf's. **Each place is then a step from the
next, where people stand to take and to eat**: that is what showed the walkers' height at a step
(`routes.md`, "At the height of the place stepped into"): with that rule off, the round with this
one in it has five times the feet in the ground that the game had before it. `colony_run --carcass-stats`,
`--place-stats`: the two measures of this day's stores.

**A stockpile is refused on ground too steep** (2026-11-23, afternoon; `Plan_Lot`, `Steep_B`;
`Set_Steep_Refuse`, `--no-steep-refuse`, not saved; his "let's block the players placement if it's
too steep, let's say anything where a part is over 1/2 slope"). Read as: some part of the ground it
would take rises more than `Steep_Rise_B` blocks (half a metre) over a metre, along the block grid
either way (two block columns of its ground four apart); or a ledge lies in its lot (two
neighbouring block columns more than `Zone_Step_M` apart: as it was, the stockpile ended there). A
boulder and a tree's foot are not counted. It is refused whole, dragged or put down whole, with the
reason at the pointer: "the ground is too steep for a stockpile there (some of it rises more than
half a metre in a metre)". Not asked of the stockyard, nor of a stockpile that is to be one level.
Counted: of 58 stockpiles (the game as it is played, four at each of fourteen awkward squares, the
reference run's) 2 are refused, both at the square at 1010 890; his own, whose ground rises four
metres across it, about one in three, is taken.

**A stockpile is one level: built, and set aside the same day** (2026-11-23; `Flatten_Pile`;
`Set_Pile_Flat`, **off by default: `--pile-flat` gives it**; not saved; his "flatten the stockpile,
let's just make this easy for ourselves", and, of the picture of his own stockpile cut four metres
into its hill, "let's go back to the stepped version, not the cut one";
`docs/handoffs/Handoff_2026_11_23_a_stockpile_is_one_level.md`). The game's stockpiles are stepped,
each place by itself, as above. What follows is the rule as it is when asked for.
Where a stockpile is put down, dragged or whole, all its ground is brought to one level at once and
by nobody, and every place of it has that height.

- **The level** is the middle one (the lower of two) of the tops of its ground's block columns that
  have a path's column beside them, so that it is walked into from its path; with no such column,
  of all its ground. Counted over 58 stockpiles before it was built (the handoff's table): at the
  middle of all its ground four of them have no way in from their path, his own among them.
- **The land is cut or filled whatever it is made of** (`Of_The_Land`: earth, rock, a boulder, ore
  at the surface), as far as `Flat_Most_B` (24 blocks, six metres; the deepest cut at the 58 is
  eighteen). What lay on top lies on top, but no block of a boulder is left in the floor's top
  (`Flat_Top`): the band prises stone off a boulder wherever a block of it has air over it and an
  open side, and did so out of a stockpile's floor. A boulder cut away is gone, as the earth is.
  Where the land beside stands off the floor it stands as a bank: no wall, no stair.
- **It is all of what was marked.** `Plan_Lot` with `One_Level`: the lot takes the ledges in its box
  (a step as high as `Flat_Most_B`, for `Zone_Step_M`) and a place lies on it however the land falls
  under the place (for half a metre).
- **What the zoning still leaves out inside it goes with it.** A block column that is no zone's and
  cannot be got to from outside without crossing the stockpile's ground is an island of it (a bush
  stands there): brought to the level too. The bushes on it are lifted off first (their stacks
  looked through for bushes first: a stockpile put down with the stake comes before that) and put
  back as far up or down as the ground of each block's own column went. Left as it lay under a
  floor filled in round it, such an island is a pit a serf walks into and not out of.
- **What a block column is to the level** is said in one place, `Flat_Kind`, by `Flat_Column`: at
  it; to move; waiting for a tree on it to be felled (`Box_Tree_Felled` makes the stockpile level
  again where it stood; until then the tree stands on a pillar of its own earth, or in a hollow) or
  for the cart to go from it and a metre round it (its bed is blocks; `Level_Places` makes the
  stockpile level again while the cart is in tow, by where it was lifted from: no place is planned
  where the cart stands and the columns its bed stood in are no zone's); or left for good (more
  than `Flat_Most_B` off, water in what would be moved, water beside it higher than it would be
  cut to, something built on top or standing where the earth would go). **A place with a column
  left for good in it is closed, and kept closed** (`Cell_In_Rock`).
- `Level_Places`, with this rule, makes every open place level as soon as it can and as far as it
  takes, and looks again each second at one something was in the way of. Looked at once, a place
  with a trunk in the way was never looked at again, and a run loaded before the felling made it
  level where the straight run did not.
- Whoever stands on its ground is put on it as it is now (`Settle_On`), and logs or a deer lying
  there; every way being walked is found again. Made level again with nothing of it to move, it
  touches nothing.

In the game as it is played the stockpile's floor lies at 19.75 m: a cut of sixteen blocks at its
far corner, a fill of two at its front, 9,572 blocks moved; the frame of the click takes 27 to 29
ms of the main thread for 5 or 6 (the gated build's own game, three runs each way). `colony_run --flat-scan` (each stockpile's ground as it lies, what each of
four levels would mean for it, and the rule's own reading of every block column of it),
`--column BX BY` (a block column's blocks from six rows over its ground down, and what it is to
its stockpile's level), and `--place-stats`, which now also asks the walking map for a way from the
stake to every open place and back. **The runner's measures have one list of what is ground**
(`Is_Land`: the land whatever it is made of, a path's surface, stone laid dry). Until 2026-11-23
each had its own, none with ore or a boulder in it, and where bog iron lies in the turf the ground
read a block low (27 of 29 places at the reference stake read as a block under their level).

**An order given later in a run** (2026-11-23): `--later HOURS ORDER ...` gives one of the player's
orders that many game hours into the run, through `Castle.Actions.Perform` as a click gives it, and
says what came of it (with `--box-stats`, how every placed zone's ground stands just after):
`housing-pull X0 Y0 X1 Y1 ROWS`, `path X0 Y0 X1 Y1`, `stockpile-box X Y WAY`, `remove-stockpile ZONE`,
`job MEMBER JOB`. Sixteen at the most. A colony founded with everything ordered at once never meets
what a second order days in meets: the zones' lost ground of 2026-11-23 (housing pulled on to housing
once the square's floor was made) was in no kept log for that reason, and
`tools/today_run.sh 4 --later 72 housing-pull 1284 1058 1300 1058 2` shows it in one line.

```sh
tools/reference_run.sh 5        # the reference run: seed 1, the reference stake and camp, the standard band
tools/reference_run.sh 41 --winter-store 10 --reserve meat 60   # summer's fifth day through the first winter
tools/reference_check.sh        # the same 41 days, seven ways, each against its own kept log, line for line
```

`tools/reference_check.sh` is the standing proof that a change left the
rest of the colony alone. (An eighth run, since stage 6a, has what none
of the seven has: a path west over the level ground, housing marked on
both sides of it and a porter in the second hunter's place, against
`reference_run_stage6.txt`, the one run of the eight with beds and at
the band's pace of today; since 2026-11-12 it has a second stockpile
south of the path, because at that pace the band fills one of 48 places
by its thirty-seventh day.) It runs
the 41 days seven ways, **each with `--no-beds`** (none of the seven had
beds: with them each of the band spends an hour or three of its first
afternoon on one) **and `--pace 1`** (the band as it worked and walked
when they were recorded), and each must
match its log in `docs/production/reference_runs/` but for the lines that
time it, the state hash and the lines that say how the paths were laid:
with nothing else off (`reference_run_herds_flight.txt`), with
`--deer-scatter` (the hands and levelling log: the herds as they were
before they fled together), and, with that, `--all-hands --no-level` (the
paths and reach log: extra tasks before they were limited, the camp's
floor left as it lies), with `--paths-built` as well (the camp and zones
log: paths laid as they were marked), with `--no-labour` (stage 5c's),
with `--no-demand` as well (5b's), and with `--no-skills` too (5a's).

Not the game's: live water does not move in the runner (ponds and rivers
rest as generated), and edited stacks are rebuilt every 30 colony seconds,
all at once, where the game rebuilds them as workers come free. A run in
the game with `--frames` follows real frame times, so it never repeats
exactly; the two agree in kind, not to the unit. Measurements and gates
are taken in the runner.

A run loaded from a save (`--load`) carries on exactly as the run that
wrote it would have, from a save taken on a rebuild: a run whose length
is a multiple of 30 colony seconds (1/48 of a game day: `--days 0.0625`,
not `--days 0.06`). The rebuilds are counted from the start of each run,
and a run started from a save has all its edited ground rebuilt at the
start; so from a save taken between two rebuilds the loaded run knows of
the ground edited since the last one up to 30 s sooner than the other
would have, and the two part some time later (a day later, where it was
found). `--save` says when a save is not on a rebuild. The colony's own
save is exact either way: `colony_check` holds a loaded colony to "just
where it would have been" on the meadow, where an edit is known at once.
Proved on seed 1 with the camp on a slope (two days, ten save times: the
six on a multiple of 30 s the same state, the four others not).

`./bin/debug/colony_check` runs a colony on a made-up meadow with six
bushes and checks the loop: the stake and the band, a path, a stockpile
refused away from it and zoned beside it, every handful accounted for
(on the bushes, carried, stored), never two pickers at one bush, the
unassigned keeping to the stake, every bush picked bare and stored within
the hour, growing back in summer but not in winter, a walled-in bush given
up on, a full basket with nowhere to go until a stockpile is zoned, a
stockpile on long grass, and a save taken mid-trip that loads, saves to the
same bytes and 400 s later has the colony exactly where it would have been.
Then four trees of its own (a tree source like the game's): two foresters
and a porter fell all but the apple tree, stump and roots left, trunk and
crown gone; every log is stored, lying or carried and all of them reach the
stockpile; only foresters ever carry wood, and none fells a tree while logs
of its last one still lie; lifting the order brings the apple tree down too; a wood reserve
of 3 stops a lone forester after two trees; felling one of two trees whose
branches run through each other's trunks leaves the other's trunk whole; and a save taken mid-felling
loads to the same bytes and carries on exactly. Then porters on a patch of
tall grass, a half-buried boulder and a shallow pond: straw comes in first
and no stone before the straw is in, then stone up to what is wanted; no
water is fetched; every tuft and stone is stored or carried; the boulder is
taken down to the grass and no further; the porter then says the stocks
are full, and fetches more when more stone is wanted or the straw reserve
raised; straw walled in is given up on for the stone ("no straw in
reach"); a porter beside a forester brings in straw and stone and never a
log; and a save taken mid-fetch loads to the same bytes and carries on
exactly. Then herds: placed round the stake on walkable ground; calm, the
deer keep within a few metres of their node as it drifts on, and graze;
someone walking 12 m off panics a herd, a hunter stalking 10 m off goes
unnoticed but not at 5 m; an arrow sends the node fleeing away from the bow
while the deer scatter, and they settle round it again; fawns come in
spring, once a year, and are grown a year later; and a save taken mid-panic
loads to the same bytes and carries on exactly. Then hunters: they hunt
until the meat reserve is met (counting carcasses on their way) and then
stop; every kill is accounted for as meat and a hide by its class; no herd
is hunted below three; with Spare deer on no arrow is loosed; a herd penned
behind walls is never shot at through them; and a save taken
mid-hunt loads to the same bytes and carries on exactly.

Then the needs: six by a field of bushes with three gatherers and no cook
eat (gatherers from their baskets, the rest from the stockpile), every
handful picked is stored, carried or eaten, all six sleep round the stake
at night and are up in the morning; on raw berries alone they go hungry
and fend for themselves; saves taken mid-meal and at night load to the same
bytes and carry on exactly. A cook, two hunters and two gatherers with a
camp keep six fed for two days with food to spare, and the band is
happier on stew than on raw berries. The camp: refused over a bush, the
stake or a stockpile and taken on the open meadow, its grass cut; a second
refused; a stockpile across it leaves out the camp's ground. The cook with
no logs picks up sticks and lights the fire, puts in the meat and then the
berries, and the pot holds what the rules say; the hungry go to the pot,
nobody eats raw berries while there is stew, and every joint, handful and
log is accounted for; logs come in and it stacks firewood and lays the
seats, and they eat sitting at the fire; at night they sleep round it. The
first cook chooses itself (the best cook, once there is meat, and only
once). Saves mid-cook, and the version 7 blob. Fending: a starving forester
and hunter with nothing stored leave their work to fend for themselves (no
felling meanwhile) and the band's confidence falls; with no food at all
nobody dies in summer, but in winter they die after two days with empty
bellies, lie where they fell, and the living grieve; a save with the dead
carries on exactly. Wild vegetables: with none in store two gatherers pull
vegetables and pick nothing else, every one pulled accounted for, growing
back after ten days but not in winter. Apples: picked in autumn, every one
accounted for; none before summer's tenth day.

Winter: with a day's store ordered the cook leaves the held grain alone
(a day's food stays free), and in winter the hold lifts and it is cooked;
nothing is gathered in winter; with no fire all six sleep cold, with wood
and a cook the fire burns all day and night and nobody is; two deer join a
herd that is short after three days and none a full one. Grain: a porter on a patch of wild grain brings in a sheaf and two handfuls
of grain a plant, stored apart, the whole stalk cut.

Zones and directors: the stockpile zoned beside the path is zone 1 with its
eight cells and the box round them; two zoned touching stay two; one zoned
over part of another gets only the ground still free; a refused one makes
no zone; the camp is a zone of its own; every cell is in exactly one
stockpile zone and each zone counts its cells, before and after a load; a
zone gathers what lies in it, what a gatherer is bringing, what is set
aside for the pot, what the cook is carrying to the camp, and who is inside
its borders at night. Whoever gives a job is its director, the unassigned
have none, nor has the cook who chose itself; zones and directors come back
from a save to the same bytes. The version 10 blob loads: three stockpile
zonings become two zones (the two that touched are one), the camp a third,
every job the player's, a gatherer still mid-carry with its cell expecting
it. Sheets: a person's, a stockpile's, the camp's and a deer's say what
they should, and what the player's character could know leaves out the
mood and the belly. The action table: the player may do every row and a
serf none; a path before the stake, a second stake, a stockpile away from a
path, a job for nobody and a reserve of berries are each refused with their
reason; a serf's order changes nothing; following changes nothing in the
colony; and the menus hold what they should for the ground (before and
after the stake, and after the camp), a person, a stockpile, the camp and
a deer. A band of sixteen has sixteen names.

Skills (the older sections run with skills off, as with needs off): start
levels and aptitudes in their ranges and the same for the same seed; the
cooking aptitude is the old cooking number; the work rate at no skill, a
third and mastery; handling at 1 whatever the skill; a master gatherer
picks twice as fast as a novice; ten hours a gatherer follow the learning
curve to within 2 %, with farming and cooking a fifth and a tenth
alongside, forestry untouched and an idler learning nothing; a cook out
gathering learns gathering; nothing is learnt asleep; the shot and the pot
at no skill, a third and mastery, and a master's pot in the run; with
skills off the pot and the shot are exactly the old ones; the first cook
is the best aptitude; sheets and menus carry the skills and no sheet runs
out of rows; a save mid-work round trips to the same bytes and carries on
to the same levels; blobs holding fewer skills, or one more, load; the
switch is saved; and the version 11 blob loads into skills, its forester
finishing its tree the better for it.

The camp is built: zoning it marks it, nothing standing and its grass
uncut; it asks the stores for 10 stone and 3 logs with its seats' 4; six
make the ground ready together, the grass cut, the turf round the fire
trodden to earth and the rest left grass; with no stone stored they prise
it off the boulder themselves, every stone accounted for, and with no logs
the crossbar is deadwood, none of it carried by the porter; the hearth
then stands and they go back to what they were at; with stone in the
stockpile that is what they build with, the boulder untouched, and the
cook lays the four seat logs from it before anything of its own, nobody
else carrying a log; saves taken with the ground being made ready and with
stone and wood on their way load to the same bytes and carry on exactly;
with no stone to be had the hearth waits and its sheet says for what, the
cook gathers meanwhile, and at night it sleeps (no fire is seen to where
no hearth stands, and the logs stay stored); built on the spot, the cook
lights the fire and cooks. The fire: seven hours on it burns as well as ever,
its flames sink through the last, after eight it is dying down, half way
down an hour and a half on, out after three, nothing gone on it by
itself; wood on a dying fire and it is away again; the cook puts a log on
for the pot and cooks on that one log, stokes it before bed so that it
lasts till waking, and at five it still burns or glows; a save taken with
the fire dying down round trips; embers warm a winter night and a fire
gone out does not; a winter day is three or four logs, never out, nobody
cold. Zones' ground: a zone is its strips of block columns; a plan says
what a zoning would take and changes nothing; a lot three quarters of a
metre short of a path is drawn out to its edge and one further off
refused; a lot drawn across a path stops at it on the side it was begun
on; a lot beside a path at an angle lies along it, filled to the path's
edge all along; a path through a zone is refused whole and one that
brushes it laid beside it; no block column is in a zone and a path; a
camp too near a path is refused, one within a metre drawn out to it, one
beside a path at an angle turned with it; the zones' ground round trips
through a save, and the version 13 blob loads with ground made from its
cells.

Extra tasks: a third of six is two, or the number set; with a job each
never more than two of the five are at the camp or the path, the cook
building beside them; four with no job are all at it and two gatherers
never leave their bushes; with the limit off all five turn to the camp;
the limit is saved; through a night (116 m of path planned at five in the
evening, looked at every twentieth of a second) never more than two, none
holding a place or a stretch asleep, and the path done the next morning;
and through a levelling the same. Stretches: 20 m is one serf's, laid end
to end, the other five standing by; 58 m is three stretches, three at
once and no two on one; with jobs two at a time, back at the bushes
between turns; eight clicks of 5 m and one serf goes on from one to the
next till it has laid 20 m; a path that ends up on a ledge leaves 8 m
planned and nobody held; with stretches off several lay a metre each on
one. The camp's floor: across three steps of ground it is to be level
with the middle one, its sheet saying how much to dig and fill; a save
taken half way loads to the same bytes and carries on exactly; every
column ends at the level, bare, the zone knowing its ground and the
fire's place on it; what was dug went into the hollows and the turf's
earth made up the rest; the seats are laid at the level; built on the
spot it is level at once; with levelling off or the band's labour off
it is left; a hump with a knob of rock: the earth to the stockpile, the
rock standing; with no stockpile the earth is thrown aside; a pit in a
floor of bare earth is filled from the stockpile's earth, and left with
none; a pit walled off is not fetched for to and fro; across a ledge a
metre high the floor is cut in and built out, the earth over stored, the
seats laid. The version 15 blob loads with six at two stretches, who
finish their metres and then keep to one each.

No limit on how far: with the only boulder 76 m from the stake nobody
looks further until none is found in reach; then they look a ring at a
time, as far as 92 m, the colony's ground reaching as far as they look and
the camp's sheet saying so; they walk out for it and the hearth stands;
with the camp standing and everyone back they look no further than their
work; a save taken with someone on the way loads to the same bytes and
carries on exactly. Paths: a path marked is planned, not laid, its ground
grass still; a stockpile is zoned along it all the same; the band lays it
a metre each, several at once, the grass on it cut, and goes back to what
it was at; a zone's ground beside it is not laid; a stretch of 42 m is
kept as two pieces; one through a zone is refused; laid on the spot; a
bit dug up is laid again; a save taken part laid carries on exactly; with
the band's labour off a path is laid as it is marked. The version 14 blob
loads with the camp being built and its paths read as laid, and the band
finishes its hearth.

Housing (stage 6a and the pass after it; `habitation.md` has the rules):
housing begun 16 m from any path refused, and begun and ended past the
end of its path; planned with nothing changed, taken beside the path; with no forester one hovel begun all the
same, for the first of the band, fronting the path half a metre to a metre
off its edge at the end nearest the stake, its blueprint's logs and
sheaves asked of the stores by its zone, and nobody touching it; a
forester taking it up on its own, the pad levelled (a terrace dug off it,
the grass cut, a neighbour's leaves over it lopped, a bank left behind);
its floor beaten with nothing carried; waiting for wood and saying so; a
log at a time fetched and its frame raised, every log stored, carried or
built in, nobody but the builder at the site; a save taken with a log on
its way, byte for byte and 400 s on, and a blob marked 18 refused; its
frame what its logs make, and its walls waiting for straw; daubed and
then thatched, every sheaf accounted for; standing as its blueprint has
it (posts, a doorway under a lintel, a floor of beaten earth, thatch at
the ridge, a footpath from its door), the zone's ground under it its pad
and a way in to the bed; its owner's home, and the next begun beside it; the fire's day of
logs and the seats' never taken for building; the builder felling for its
house with no wood stored, every log of every tree accounted for; the
porter cutting the straw asked for and never carrying it to the site; a
builder given other work, its log back to the stockpile and another
forester taking the house up; housing 78 m from the stake and the colony's
ground reaching it; built on the spot, those with a home asleep in it at
midnight and not cold on a winter night with no fire, the rest cold; the
night coming on a builder with a log in its arms, the log carried to its
house and the builder asleep; four hundred blueprints held to their order (floor, frame, walls, gables,
roof; all the timber before anything of straw; no block twice; what they
take) and to the roof's trimming after it (the top thatch of every column
once); housing pulled along a path (a strip shorter than a hovel taken;
pulled on from inside it over the joints of the path's stretches; seven
blocks past a turn and no further; a pull that overlaps two zones making
them one; a strip aslant and a straight one combined; ground that is
housing already; zone numbers through a combining that does away with a
zone, for the camp, a stockpile's places and the houses, and through a
save; two hovels or more on 28 m beside a path at every angle, on the
flat and on ground that falls 2 m in 7, every hovel built there with a way
in and its walls); the made-up hillside built from the foot of its path
up and from its head down, every step of more than a block round a hovel
walled with stone; a hovel walled by hand below a hillside path (the
hearth's stones left alone, waiting for stone and saying so, every stone
accounted for, its builder never anywhere it cannot walk back from),
above the path as below it; a way back to the stake from every spot round
those hovels that a serf can get to (no yard a pit); seven hovels either side of a path aslant across made-up ground
that falls a block every metre and a half, a way from the stake to every
bed and every owner asleep in its own at midnight; trees felled whose
shapes reach through a house's corner post, the house whole; a vegetable
pulled where an eave now hangs not growing back, one in the open growing
back; the order through the action table (refused for a serf, refused away
from a path with the ground's reason, done beside one), the ground's
menu, and that a builder is not a job to give.

Not there yet (later stages): spoilage, theft,
and people leaving when confidence runs low; the serf menu with tiers;
stockpile improvements (stage 6b); a player character is held back on
purpose. Trees don't topple (the crown goes at once), and
they don't grow back.

## The colony's own ground (2026-11-14)

The game holds the whole map for the simulation (`world.md`, "The whole
map held"), so "what is loaded" no longer bounds anything. The colony is
told its own ground by its host (`Castle.Colony.Set_Ground_Stacks (N)`:
every stack within N stacks of the stake's, counted stack to stack) and
reads nothing beyond it, whatever else is loaded:

- one function asks whether a stack is in (`Own_V` in the colony's body:
  the ground's version on its own ground, nothing off it), used by the
  index, the search for sources, the far look, a path's stretches and the
  laying out of lots: nothing else in the colony may ask the world's
  version reader itself;
- its routes keep to it (`Castle.Nav.Plan (..., Within => Own_Region)`: a
  region counted in stacks, `Castle.Nav.Within_Stacks`), and the herds as
  they were plan on it too (`Castle.Herds.Set_Ground`).

N is `Integer (Ground_Reach_M / 8) + 5`, and never less than it has been:
the runner's rule since it was written, now the game's as well (it kept 3
more than the reach, and the colony read whatever else the camera had
passed over: it knew of a few more bushes and trees at the corners of its
index by where the player had looked). So the colony is the same colony
in the runner, in the game with the camera anywhere, and with the whole
map in. **Measured before it was built**: the band's 41 days with the
whole map in took 85 s for 5.5, the walking map read over 57,946 stacks
and one plan took 3.8 s, because a goal out of reach was looked for over
all the ground there was. With it: the same 5.8 s, and **the run ends in
the very state of a run on the colony's own ground** (the band's 41 days,
the housing band's, the crowd's sixty with needs and without); the eight
reference logs are line for line with none recorded again, and the three
states of the stress runner are those of `main`. `tools/stress.sh runner`
holds it (`crowd_whole_map`: the crowd's sixty days with every stack of
the world in must end as on its own ground), and that line stands in for
the game. `colony_check`: told its ground is two stacks, the colony knows
of no bush five stacks off on loaded ground, and nobody goes. Until the
host says, the colony reads whatever is loaded (the checks' made-up
worlds). Not bounded: the demo walkers of `--walk` and `--deer`, which
plan as they always did.

**What the player plans is not the band's doing**, and is read from all
the ground that is held (the world's version reader itself, in three
places that each say so): the line of a path as it is shown and counted
when marked (`Stretch_In (S, Held => True)`: a path over bare rock out
there is refused as it is near the stake, where taken on trust it was
recorded and never laid), and the ground inside a round of paths for
housing. A path, housing, a stockpile or the camp so marked further out
widens `Ground_Reach_M`, the host says that ground is the colony's own,
and the band goes. `colony_check` has each (with the band's ground set to
two stacks: the made-up world is 64 m, less than the rule's ground), and
each fails with the read put back on the band's own ground.

## What a search for a source keeps (2026-11-11)

`Find_Source` finds the nearest straw, stone, water or wild vegetables by
looking through the flagged stacks ring by ring from where the member
stands. It used to read each such stack's 256 cells, their floors and up
to sixteen blocks a floor, every time anyone looked. Now what it finds in
a stack (the places, in the order the search comes to them) is kept, by
the ground versions of that stack and the four beside it, and read again
only when one of them has moved (`Source_Memo`, `Read_Stack`;
`Castle.Colony.Set_Source_Memos (False)` or `colony_run --no-memos` for as
it was). Who has taken a place, and who has failed at it, is asked each
time as before, so the same place is chosen. Nothing of it is saved, and
`Reset` and `Set_World` forget it. `Index_Some` walks only each ring's own
stacks now, in the order it always did.
