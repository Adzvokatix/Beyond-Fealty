# Food and needs

- Packages: Castle.Colony
- Check: colony_check (its needs, camp, fending, vegetables and winter sections)
- Saves: the colony blob, versions 7 to 10
- Stage: stage 4 (Handoff_2026_11_09_stage_4_camp_and_food.md)

* **Eating and sleeping** (stage 4). Everyone eats and sleeps, on the
  game clock: at the normal `--timescale` a colony second is a game minute,
  so a game day is 24 minutes at 1x. Food is counted in points; an adult
  eats `Day_Food` (240) a game day, an elder 80 % of that, a child 60 %. A
  belly holds 10 hours of food; at 40 % a member eats at the next break in
  its work, at 15 % it leaves off work to eat if there is food (never with
  a load in its arms, a butchering, a shot or a pot on the fire under way).
  **A load in its arms is taken where it was going first**, and then it
  eats (`Load_First` in `Think`; John, 2026-11-13: "people carrying items
  to the stockpile will stop and eat instead of completing their task and
  then eating, this creates an oddity where foresters carrying logs back
  to the stockpile have a log on their sholder while they are eating"). A
  gatherer goes home with a part load rather than pick more. Not so: for
  one that fends (what it carries is its meal); for one down to its last
  (below 15 %: what it carries has had hours to get where it was going,
  and has not); with nowhere in the stockpiles to put it; and for food of
  its own gathering when there is no stew to be had, which it eats where
  it is, as before. (Taken home, that food went into the stores, where
  the cook keeps a pot's fill: on the housing run's first day, with
  nothing cooked yet, the band went hungry beside it and fended, the cook
  with them, and nothing was cooked until the next morning.) On the
  reference band (seed 1, all of 2026-11-12 on, 41 days) 47 meals were
  begun with a load in the eater's arms, every one of them stew at the
  fire: 31 by gatherers with what they were taking home, 7 by the
  forester with a log for the stockpile, 9 by the cook with a load for
  the pot or the fire. Now none (on the housing run 66, now one, by a
  fender). Food in hand over those 41 days 10.1 to 14.8 days (10.1 to
  17.2 before), 16 deer (17), nobody died.
  `colony_check` looks at every meal of three days of a band with a cook,
  foresters and gatherers. Stew comes first: it takes a bowl at the pot
  (set aside for it on the way) and sits at the fire to eat it. Without
  stew it eats raw: what it carries if that is food, else from the
  nearest stockpile cell, apples first, then berries, then vegetables
  (the cook's best greens are left to last). Raw food fills a belly
  poorly; cooked into stew the same food goes about three times as far,
  and meat is never eaten raw:

  | | raw | in stew |
  |---|---|---|
  | a pound of meat (a joint, with `--no-curing`) | (never) | 48 (30) |
  | a vegetable | 3 | 8 |
  | an apple | 2 | 5 |
  | a handful of berries | 1 | 3 |
  | a handful of grain | (never) | 4 |

  **What the cook keeps** (John, 2026-11-12: "rather than waiting for the
  cook to use the stockpile to cook food, the serfs were eating raw
  directly from the stockpile preventing food from being cooked, can the
  cook reserve food in the stockpile and only suprlus is availible to eat
  raw if no stew is present"; first values of mine, his to tune). While
  the camp's hearth stands and the band has a living cook, a pot's fill of
  what is stored is the cook's (`Cook_Keeps`, 900 points as stew, whatever
  is in the pot already): meat for half of it while there is meat, and for
  the rest greens in the cook's own order (vegetables, berries, apples),
  from what the winter store does not hold. Nobody eating raw touches
  those greens: only what is over them is eaten raw, and only with no stew
  to be had, as before. So with less than a pot's fill stored the hungry
  wait for the stew; at 15 % they fend for themselves, as with nothing
  stored. Someone starving who has found nothing to gather breaks into
  what is kept, as into the winter store (a serf won't let itself
  starve); in winter, when nothing can be gathered, that is anyone below
  15 %. Before the hearth stands, and in a band with no cook, nothing is
  kept: there is nobody to cook it. What a serf carries is its own to eat,
  as it was. The camp's sheet says what is kept ("Kept for the pot: 57
  vegetables, 30 berries"). `--no-cook-hold` (`Set_Cook_Hold (False)`) is
  the stores as they were; the seven older reference runs are held at it.
  Measured on the reference band (seed 1, with everything of 2026-11-12
  on: today's pace, meat by the pound, the standing orders). **The first
  day** (traced with `colony_run --who`): the hearth stands at a quarter
  past ten; the cook makes its bed, picks up sticks (no log is stored
  yet), and from a quarter past eleven carries the pot's fill to it a load
  at a time as it comes in (ten pounds of meat, then vegetables twelve at
  a time: 53 by twenty past one), going for sticks twice more as the fire
  burns down; it stirs from ten to two, and the first stew is ready at
  half past two. With nothing kept the pot is longer in filling, since the
  hungry eat from the same vegetables, and the stew is ready at a quarter
  past three. Either way **the pot is not stirred until it is full or
  there is nothing more to fetch** (`Think_Cook`: a rule of stage 4, not
  changed here): on a first day that is three hours with food in the pot
  and none to eat, and it is the larger part of what a hungry band is
  seen waiting for. With the hold the hungry wait: the hungriest is at
  25 % when the stew comes (32 % with nothing kept), and nobody fends.
  **Over 41 days**: 363 berries and 16 vegetables are eaten raw where 637
  and 80 are with nothing kept, 47,183 points of stew are cooked where
  46,709 are, and all six are living at the end either way. With no
  orders given (no winter store, the meat reserve 20 lb): the first stew
  at a quarter to three where a quarter past three; 11 vegetables eaten
  raw in 41 days where 60 berries and 123 vegetables. It
  bites when little is stored (a first day, a lean week): with meat by
  the pound the pot is seldom empty, and little is eaten raw either way.
  **Meat is counted in pounds since 2026-11-12**, a doe's sixty being two
  days' food for the six, kept whole if she is salted as she is butchered
  (`colony.md`, "The lord's cart"); every figure in this document from
  before that day is of joints, eight to a doe.
  With nothing to eat it works on, "hungry"; with an empty belly it is
  "starving" and walks and works at 60 % until it has eaten. At night (9 pm
  to half past 5, children an hour and elders half an hour earlier to
  bed, give or take a little each) everyone puts its load away, eats supper
  unless nearly full, and sleeps at its own place round the fire (round
  the stake while there is no camp; in its hovel when it has one), getting
  hungry half as fast. It lies on its side, a little curled up, under its
  cloak, and on a bed of straw once it has made one (`habitation.md`: the
  bed and the cloak change nothing but what is seen; `Set_Beds (False)`,
  `--no-beds`, is the band without beds). The band panel shows the food in days (stored and in the pot, as
  the cook would make it), how many are hungry and asleep, and the band's
  confidence; the status words say "eating stew", "eating", "asleep",
  "hungry:", "starving:", "fending for itself:".
  `Castle.Colony.Set_Needs (False)` switches it all off (the older sections
  of `colony_check` check the work alone).
* **The camp.** Campfire in the tools panel, then a click: a 7 m square
  with the fire where you clicked, on ground no more than a metre above or
  below the fire's and with nothing on it but grass (a tree, bush, stone,
  water, the stake or a stockpile in the way refuses it, as does a path or
  a zone within 3 m of the fire, and the log says what and where). One to a
  colony; it can't be moved yet. It is a zone like any other
  (`docs/systems/colony.md`, "Zones"): turned to a path that passes within
  a metre of its square and drawn out to that path's edge. Four seat logs
  go round the fire (two places each), the firewood is stacked in its
  south-east corner, and the band sleeps round it.
* **Building it** (John, 2026-11-10: "the fire just doesn't magically
  appear, they build it, the current model comes into existent after they
  deliver stone and wood to build it, then the one of the few exceptions in
  this game the pot can magically appear ... they also need to prepare the
  ground, compacting the earth around the campfire grass disappears"; first
  values and first rules, his to tune). Zoning the camp only marks it.
  Then the band builds it (`Think_Build`): the cook as its own work, and
  as an extra task whoever else has empty hands and a place among the
  extra hands (two of six at a time; those with no job always:
  `docs/systems/colony.md`, "Extra tasks"; John, 2026-11-11: "we should
  limit the amount of workers that can perform extra tasks". Until then
  everyone turned to it before its job).
  * **The ground** is made ready a square metre at a time, from the fire
    outward, one person to a patch (4 s a visit at a rate of 1, `Tamp_S`;
    `Site_Work`, which teaches building): what grows on the camp's ground
    is cut, and within 2.6 m of the fire (`Hearth_Ground_M`: its floor) the
    ground is made level and the turf cut off to bare earth (edits like any
    other). A patch is written all at once, so the ground round it is
    worked out again once and not block by block. A patch is worked from
    as near as can be got to its middle, within 1.6 m (`Patch_Reach_M`): a
    bank is dug from its foot.
  * **The floor is levelled** (John, 2026-11-11: "I have tested it on
    uneven ground, and it causes some issues with the logs and such, so I
    think we need to have them level the terrain at least for the
    compacted part, they can move the dirt to the stockpile"; first rules
    of mine, his to change).
    * Its level is chosen when the camp is marked: the highest at which
      the earth dug off what stands above it, with the turf cut off the
      rest, fills the hollows below it. So the earth is always there, and
      on a slope the floor is cut into the high side and built out on the
      low. The camp's sheet says "Floor: 78 blocks of earth to dig off,
      106 to fill", and "level" when it is.
    * Whoever makes a square metre of the floor ready digs off what
      stands above the level, a basketful a visit (16 blocks,
      `Carry_Limit (Earth)`), and fills its hollows with what earth it
      has. Earth left in its hands it carries to another hollow if one
      wants it (it waits a moment if each has someone at it), else to the
      stockpile, where it is heaped as **earth**, a kind of its own
      (`docs/systems/colony.md`); with no stockpile, or no room, it is
      thrown aside.
    * The turf cut off the floor lies there as earth for its hollows, a
      block for every two block columns (`Sod_Share`). It is used once
      nothing is left to dig off, and never carried away. This is the one
      place earth comes from nothing: the ground under the turf stays
      where it is. Without it a hollow a few blocks larger than the high
      ground could only be dealt with by lowering the whole floor a block
      (304 blocks to dig, not 78, on the slope measured below).
    * A hollow still there after that is filled from the stockpile's
      earth; with none to be had anywhere it is left, and the hearth is
      built all the same. Rock is not dug: a column of it stands as it is.
    * The camp's zone reads its ground again whenever it is dug or filled
      (`Read_Camp_Ground`), the fire's place follows its ground, and once
      the camp stands a place on its floor is at the floor's level.
    * `--camp-built` and `--stoke` level it on the spot, the earth from
      nowhere and to nowhere. `--no-level` (`Set_Levelling (False)`)
      leaves a floor as it lies, as it was before; with the band's labour
      off nothing of the ground is touched.
    * Measured on seed 1, the reference band, the stockpile at the stake
      (again on generator 13, 2026-11-11; on generator 12 in brackets):
      the reference camp (a slope of 1 in 30: 28 blocks to dig, none to
      fill) has its hearth at a quarter to twelve, a quarter of an hour
      later than with its floor left (half past twelve, three quarters
      later); at 1158 1090 (97 to dig, none to fill, the stockpile some
      30 m off) at a quarter to three, two and three quarter hours later
      (half past four, three and a quarter); at 1156 1099 (a slope of 1
      in 8: 78 to dig, 106 to fill, all of the dug earth going into the
      hollows) at a quarter to one, no later (half past one, three
      quarters). What costs is carrying earth to a stockpile, not the
      digging.
    * Not levelled: the rest of the camp's square, where the firewood is
      stacked (3.9 m from the fire) and the band sleeps (from 2.7 m).
      Not there yet: saying before the camp is marked what its floor will
      take; a use for the earth.
  * **Stone:** 10 for the ring (`Hearth_Stones`). From the stockpile if it
    holds any; else whoever goes for it prises it off the nearest boulder
    itself, as a porter does, and carries it straight to the hearth. What
    is over goes on to a stockpile.
  * **Wood:** 3 pieces for the crossbar (`Hearth_Wood`). A log from the
    stockpile, carried by one whose work logs are (the cook, who keeps the
    camp, or a forester); from anyone else, or with none stored, an armful
    of deadwood from under the nearest tree, as the cook's sticks are.
    Never by a porter: porters carry no wood. (The decision of 2026-11-08
    stands: no idle hands hauling logs.)
  * With the ground ready and both delivered **the hearth stands**: the
    ring of stones, the crossbar, and the pot with them (the pot is the
    band's own). Until then what has been brought lies at the fire's place,
    there is nothing to cook at (the cook gathers meanwhile, or says "the
    camp is not built yet"), and the camp's sheet says what its hearth is
    short of.
  * **The seats** are laid as soon as there are logs in the stockpile, a
    log each, by the cook and by a forester, before anything else of their
    own: the hearth does not wait for them, nor they for the cook to have
    nothing else to do (they used to come after its fire, its pot and two
    logs of firewood, hours late; John, 2026-11-10: "a lag in laying the
    logs for the seating"). On the check's meadow a cook alone lays all
    four within two and a half game hours of the logs being there.
  * What the building still takes is in the demand table as well (the
    camp's rows: "10 stone once", and the crossbar's wood with the seats'),
    so porters and foresters bring it in to the stockpile, where the
    builders find it first. A band with neither still gets its hearth: by
    its own hands, as it could always cook on sticks.
  * Measured: on the check's meadow five with no job and nothing stored
    build it in 137 game minutes (103 when a sixth, a porter, turned to it
    too: it goes on with its own work now, the five being hands enough). On the
    reference run (seed 1 on generator 13: 56 square metres of the camp
    to make ready, 28 blocks of earth to dig off its floor), the cook and
    two others at it, the hearth stands four and three quarter game hours
    after the start, at a quarter to twelve, and the first stew is cooked
    by three that afternoon (with all hands and no levelling, as it was
    built first: two and a quarter hours). On generator 12, with 64
    square metres to make ready, it was five and a half hours and the
    stew that evening.
  * There is no limit on how far they go for it (John, the same day, on
    being told a site with no boulder in reach got no hearth: "Don't place
    a distance limit on initial gathering, if they have to walk 200m to get
    stone they walk 200m"). With none in reach of their work the band looks
    further, a ring at a time, and whoever is free walks out for it
    (`docs/systems/colony.md`, "How far the band looks"). Only at the
    engine's limit of 256 m does the sheet stay at "Short of 10 stone".
  * The first day's cost stands (John, the same answer): eating raw from
    the stockpile, or fending for oneself when it is empty or held, "is the
    opportunity cost for not having a stockpile or food cooking"; cooked
    food goes further than raw, and meat is never eaten raw. (Since
    2026-11-12 what is "held" is also the cook's pot's fill, once the
    hearth stands: "What the cook keeps", above. Until it stands the
    stockpile is eaten raw as it was.) Those are the
    eating rules above, unchanged: a member eats at the next break in its
    work once below 40 %, and leaves its work to eat, or with nothing free
    to eat to fend for itself, below 15 % (`Hungry_At`, `Very_Hungry`).
  * `--camp-built` (`Build_Camp_Now`) builds it on the spot for a scripted
    start, as `--supply` conjures goods; `--stoke HOURS` does too, and
    lights the fire. `--no-labour` (`Set_Labour (False)`) is the
    camp as it was: it stands the moment it is zoned, the grass on it cut.
  The fire burns in the ring of stones under the crossbar, and from it
  hangs the iron pot (how the fire is drawn, and the light and shadows it
  casts: `docs/systems/rendering.md`, "The fire").
* **The fire** (John, 2026-11-10: "fire life needs to be extended to
  about 8hours with a 3 hour diedown for restoking"; first values, his to
  tune). A log on it burns 8 game hours (`Log_Hours`). Then it dies down
  for 3 more (`Die_Down_Hours`), its flames sinking to embers, and all
  that while a log put on it takes at once and it is away again: that is
  when it is restoked. After that it is out. It is tended by hand: nothing
  goes on it but what someone puts there (it used to take a log off its
  stack by itself). The cook sees to it whenever it is wanted and there is
  not enough on it:
  * for cooking: enough to see a pot through;
  * for the night, from two hours before bedtime (`Stoke_Ahead_Hours`):
    enough that it burns, or at least glows, till waking. A log at bedtime
    lasts the night (8.5 hours) and leaves embers to restoke in the
    morning; the cook sees to it before it lies down even if bedtime has
    come;
  * in winter, when it is kept in all day: as soon as it begins to die
    down.
  A fire dying down still warms those asleep round it (nobody is cold by
  embers); it does not cook: a cook whose fire burns out mid-pot stokes it
  and stirs on. Lighting a fire gone cold costs nothing more than stoking
  one on its embers (not asked for; his to say). Logs come from the
  stockpile and are stacked by the fire (4 at most), and the cook stokes
  from the stack (`stoking the fire`); a log brought to a fire that is down
  goes straight on it. With no logs stored the cook picks up an armful of
  dead sticks under the nearest tree instead (1.5 hours), for cooking
  only, so a band without a forester can still cook. Measured on the
  reference run (seed 1, the reference band): 2 to 3 logs a day outside
  winter (2.3 on average; it was 4), 3 a day in winter (it was 6), and
  nobody cold on any winter night (so too on generator 13). The camp asks the stores for 2 logs a
  day, 3 in winter (`Fire_Day_Logs`). The camp's sheet says "burning, 6.2 h
  of wood on it", "dying down, 2.1 h left to restoke it" or "out".
  `--no-labour` (`Set_Labour (False)`) is the fire as it was: a log
  burns 4 hours, the fire feeds itself from its stack, there is no dying
  down; the older checks and the reference logs run with it.
* **The cook.** First the fire (above). Then the pot: once the stew in it is down to half (450 of 900
  points) the cook fetches from the stockpile, a load at a time, meat for
  up to half the pot and greens for the rest: vegetables, or berries when
  the vegetables are gone, or apples after those; all meat or all greens
  when that is all there is. It stirs it over the fire for a game hour
  (less the better a cook it is, more the worse: its work rate),
  and the pot holds the stew value of everything put in, a quarter more
  for meat and greens together, and from a tenth less to a fifth more by
  the cook's skill. Then it lays the seat logs and fills the stack. With
  nothing to cook it goes gathering ("nothing to cook:") until there is.
  Nobody need be told to cook: once there is a camp and something to cook,
  and nobody has ever cooked, the band's best cook takes it up on its own
  (the player's choice stands after that). The best cook is whoever has
  the best aptitude for cooking; how good a cook each is now is its level
  in the skill (`docs/systems/colony.md`, "Skills"). With skills off
  (`--no-skills`) a cook's worth is the number from its seed that it was
  before there were skills, a tenth more or less.
* **Grain** is a by-product of straw, so gatherers aren't loaded with it:
  a porter cutting straw cuts wild grain as readily as tall grass (the
  whole stalk, to the ground), and each plant gives two handfuls of grain
  with its sheaf. The grain rides home with the straw and goes into a
  stockpile cell of its own. It isn't eaten raw; the cook puts it in the
  pot last, after vegetables, berries and apples. It only comes in while
  straw is being cut, so the straw reserve limits it for now.
* **Fending for itself.** A member down to 15 % with no stew, nothing in
  the stockpiles and nothing in its hands leaves its job and gathers for
  itself, eating as soon as it has enough; its own work waits ("fending
  for itself:"). **It goes for whatever there is to eat nearest to where
  it stands** (John, 2026-11-12: "serfs would go long distances to fend
  for themselves to eat vegetables when furit and berries were near by"):
  a ripe bush, an apple tree in fruit or wild vegetables, by the way to
  it alone. A gatherer's rules are not its own (vegetables alone while
  none are stored, vegetables worth a longer way, the way home from a
  bush counted with the way to it): until that day a fender was sent by
  them, and six starving by the stake with bushes all about walked to
  the vegetables 20 m off. **One that carries a kill and has nowhere to
  butcher it** (every place of the stockpile taken) stands with it while
  it can; hungry, or night come, it puts the deer down and sees to itself
  (a serf won't let itself starve), and a kill lying out is fetched only
  while there is somewhere to butcher it. Until 2026-11-12 it stood with
  the deer in its arms and starved, since no need is seen to by one that
  carries a kill: found in the stage 6 run at the band's new pace. In winter a member whose
  belly has been empty for two game days dies of hunger and lies where it
  fell; outside winter they fend for themselves, weak but alive.
* **Winter.** Nothing is gathered in winter: the berries are gone and the
  roots lie under the snow ("nothing to gather in winter"); hunting goes
  on. So the band lives on what it stored, and the winter store is the
  order for that (band panel, in days; `--winter-store N`; off by default):
  outside winter that many days of the band's food are held back in the
  stockpiles, the kinds that keep first (grain, apples, meat, then
  vegetables and berries). Neither the cook nor anyone eating raw touches
  them, and gatherers work as if that food weren't there. The store is
  built from surplus: a day's food (pot and stockpiles together) is never
  held, so ordering a store starves nobody. Only someone
  starving who has found nothing to gather breaks into it. In winter the
  hold lifts by itself. The fire is kept in all day and night in winter
  (three logs a day) and the cook fills its stack before anything else.
  (Since stage 6a, 2026-11-12: nor is anyone cold asleep under its own roof, fire or no fire: `habitation.md`.)
  Anyone asleep in winter away from a fire that burns or glows is cold: it gets hungry
  at the waking rate, and its mood can rise no higher than 30 %; the band
  panel says how many.
  Measured on seed 1 (the README's stake, camp at 1172 1082, a 10 x 5
  stockpile, nothing stored, from summer's fifth day, `--winter-store 10
  --reserve meat 60`): the first winter is touch and go, and turns on a
  hunt or two. On generator 13, as measured again on 2026-11-11 after a
  goal out of reach was always known for one (`routes.md`: nothing of
  these rules changed), a cook, two hunters, two gatherers and a forester
  go into winter with 6 days of food, have none left four days before its
  end, and all six see the spring; a cook, two hunters and three
  gatherers with no forester go in with 11 days, sleep cold most nights,
  have none left three days before its end and lose two. (Measured that
  morning, before that change: the first band lost one of the six and
  the second none. On generator 12, the same bands and the same rules: 5
  days and four of the six dead; 12 days and all dead in its last two
  days.) It turns on a hunt or two, and on where a gatherer stands under
  an apple tree. Balancing that is still to do.
* **Confidence.** Each member's mood eases, over about half a game day,
  toward how it is living: 80 % fed on stew, 55 % fed on raw food, 35 %
  hungry, 10 % starving, nothing while it has to fend for itself, and
  starting to fend takes another 10 % off at once; a death takes 25 % off
  everyone. The band panel shows only their mean (a person's own mood is in its
  tooltip in the development view, under the rule that marks what the
  player's character could not know: the game's own tooltips will leave it
  out), the band's confidence in
  the player, not each one's. (Leaving when it runs low, theft and spoilage
  come later.)
* **The band's pace** (2026-11-12; `colony.md`, "The band's pace"): the
  band works and walks half as fast again as it did when everything below
  was measured, and hunger goes by the clock as it did. Nothing here was
  retuned for it, on purpose (it is John's to ask for): the figures below
  and under "Winter" are the band at pace 1 (`--pace 1`), and what the
  reference band does at the new pace is in the pass's handoff
  (`docs/handoffs/Handoff_2026_11_12_housing_pass.md`, "Measured").
* **How it was tuned.** On seed 1 at the README's stake, with the camp at
  1172 1082 and nothing stored to start with, `--log-hours 2` over four
  and a half game days: a cook, two hunters, two gatherers and a forester
  keep six fed with about two days' food in hand (the hungriest at 40 %,
  nobody hungry for long); a cook, a hunter, a gatherer and a forester
  just about hold their own (the stock slips from a day to a third of one);
  two gatherers and no cook go hungry and end up fending for themselves.
  (That was before deer wandered in: hunting then ran dry after about four
  deer. See "Winter" for the runs since.)
