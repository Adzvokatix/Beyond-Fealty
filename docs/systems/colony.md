# The colony

- Packages: Castle.Colony, Castle.Actions, Castle.Scenario
- Source: `src/castle-colony.ads` (the tunables and capacities), `src/castle-colony.adb` (state, helpers, and a stub per larger subprogram: the index), `src/castle-colony-<name>.adb` (one subprogram each)
- Check: colony_check (635 checks, about 85 s); colony_run --expect for runs on the real world; tools/reference_check.sh
- Saves: the colony blob, version 25, inside the game save
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
  1.75 m tall is raised there and the band (six by default,
  one of them old) arrives round it, none assigned, each with a name of
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
  It reserves a bush or an apple tree, so no two work one; it walks there
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
  from the stake, within 60 m of the stake), reserves it and walks to the
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
  * Water is not fetched yet: it waits for a use and for barrels to keep
    it in. (The fetching can find and draw it, two buckets at a time where
    it can be waded; it is just not asked for.)
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
    `Supply`'s). Standing on a stockpile's ground it stays. Nothing else
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
`--save FILE` (a save the game opens with `--load`), and `--deer-track
FILE` (a line for every deer after every colony second: the second, the
deer, its herd, where it is, whether it is in panic, the rows of water it
stands in, its herd's node; for looking at how the herds move: `deer.md`,
"Measured").

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
