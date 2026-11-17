# Castle Game handoff (2026-11-12 and 13: a pass on building and zoning after stage 6a, in five rounds. First: housing pulled along a path and combined where it meets housing; a house's ground walled with stone where it rises and falls; roofs trimmed to one slope by their builders. Second, on John's answers to the first: lots laid out beforehand and hovels drawn for by lot when they stand; the ground between neighbours made one, their walls met; serfs asleep on their sides; beds of straw; cloaks. Third, on what he found trying the second: sleepers on level ground across the way to the fire; beds before hovels for stored straw; a fender goes for the nearest food; housing of all the ground inside a round of paths; a path drawn on its ground; no housing across the road off a path's end; the band half as fast again. Fourth, on what he found trying the third: no stone stair where a door is all but level with its path; a ladder for the roof; the cook keeps a pot's fill of the stores; meat by the pound, a doe's sixty, and the lord's cart of salt. Fifth, on what he found trying the fourth: a load in a serf's arms taken where it was going before it eats; a hovel's lot levelled with its holes filled, not dug down to them; holes under a path filled as it is laid; a builder takes up a house left half built. Built on branch `housing-pass`, put to John and accepted 2026-11-13; on `main`; Claude Code)

- **Accepted: John, 2026-11-13, whole: "accepted".** It came while the fifth round was being built,
  before it was reported to him; read as the pass accepted with the fifth round's mending in it. The
  round was finished, gated and merged: `main` fast-forwarded from 2e2301f (stage 6a as he accepted
  it) to the branch's last commit. He took up none of the calls of the third, fourth or fifth rounds:
  they stand by default ("His calls"). If he meant the fourth round only, `main` goes back to 1e28018
  and the fifth round stays on `housing-pass`.
- Code: GAME_alpha_1_3/compiled, branch `housing-pass`.
  - First round: 2b76ad1 (zoning), 5993ea2 (walls and stairs of stone), d5f502a (roofs trimmed),
    ffa938a (no yard a pit); put to him at 6a52e6c.
  - Second round: 216bbe7 (lots laid out beforehand, the lottery), 46f894e (the ground between
    neighbours made one), 077f1fa (asleep on its side), ffb12d4 (beds), 7b7ca34 (cloaks), 5f8d60a and
    b213248 (checks; a house's reach taken with its lot), e94716b (the demo's script), 51b7ee8 (a bed
    laid only where its maker sleeps now); put to him at 050cce4.
  - Third round: cea5db8 (no housing across the road off a path's end; housing inside a round of
    paths; a path drawn on its ground), b87019a (where each lies by the fire; a bed's straw and its
    turn), 3b2fe5e (a fender goes for the nearest food; five reference logs recorded again), f489288
    (the band's pace; a hunter with nowhere to butcher its kill); put to him at 4fca9a0.
  - Fourth round: 3117f7f (his words), c014061 (the stair), 44c5880 (the cook's hold; colony blob
    23), 3a88244 (the lord's cart, salt, meat by the pound), 5bae8a6 (the ladder), b67735a (the
    ladder's log asked for, felled for and made of the builder's own; the eighth reference log
    recorded again), 51548c6 (documents; the demo's script), 600bcfd (a way asked to a place on the
    cart planned to beside it; the eighth log once more), d726257 (documents), and the branch's last
    commit then, 1e28018 (a stored ladder drawn stood against a pole; that round's last figures).
  - Fifth round: edb8a7b (his words), 972269c (a builder takes up a house left half built),
    e43aba0 (a pad levelled as if its holes were filled), c82f798 (a load taken home before its
    carrier eats; the eight reference logs recorded again), d5b0ab5 (holes under a path filled;
    colony blob 24), 94fdfbb (documents; the demo's script), 71901b5 (hollows closed in by higher
    ground in place of the local test; plants never left over a hole, the game's dig among them; a
    load nowhere would take), b70eb70 (documents), 3bccba1 (his acceptance recorded), and the last
    commit (a column of path raised only where the ground read round it is its own top, a metre at
    most; documents).
  - Zip: CASTLE_GAME/releases/castle_game_housing_pass.zip (a `git archive` of `main` at the pass's
    closing commit; it replaces the fourth round's zip of the same name). `castle_game_stage6a.zip` is `main`,
    stage 6a as accepted. Demo: colony_housing_pass.mp4 (tools/demo_housing_pass.sh), seventeen parts, 151 s:
    the fifth round's first (a lot with two holes levelled where it lies; a path over holes, as it was
    and filled), then the cart and its salt, a roof thatched from a ladder, and the earlier rounds'.
- Checks, from a clean copy (`git archive`) of 186164f (the round's last code; after it only this
  paragraph), built from nothing, and before that on b70eb70 (71901b5's code: the gate was run twice,
  since a review after the first found the path's fault 186164f mends): debug and release with the six known warnings and no other;
  all nine checks pass in debug (colony_check 610 -> 616, the rest as they were); `tools/reference_check.sh`
  holds its eight logs line for line (all eight recorded again in c82f798 for the eating; the seven
  older ones now held at `--no-path-holes` as well); `tools/stress.sh runner` passes ("nothing died,
  nothing dropped"); the flora's hash is the same in both builds. Fourth round: the same gate on
  1e28018, colony_check 573 -> 610, pick_check 38 -> 41.
- Versions: `Generator_Version` 13 and save format 6 as they were. **Colony blob 23 -> 24** (whether
  a hole under a path is filled; 18 to 23 are refused: **the fourth round's saves do not load**).
  Fourth round: 22 -> 23 (the cook's hold, curing, the cart and its salt, ladders); on their ends
  `Item_Kind` (`Salt`, `Ladder`), `Castle.Pick.Thing_Kind` (`A_Cart`).
- Driven only by script: the dig taking what grew on what it removes (`--late --dig`, as a click
  digs); a click with the real mouse was not driven. No tool, menu, sheet or tooltip changed. Fourth round:
  the cart's tooltip (a scripted pointer rested on it); a right click on the cart opens the ground's
  menu as on any ground, and that was not driven at all.
- **Test windows of mine on his desktop**, fifth round: some fifteen stills (his lot reproduced with
  two holes dug in it, before and after; the eighth reference run's sixth pad from five places, two of
  them inside a roof; a path over holes with the fill on and off), the game run short seven times to
  dig holes and save (three of them digging one row under tall grass, one as a click digs), and the
  demo once (seventeen parts, recorded on 71901b5: the last change to the path's fill alters none of
  its parts' ground). Fourth round: some twenty stills (doors beside
  slanting paths before and after, the cart four times, a ladder at a front, a back and both side
  eaves), a recording of 200 frames for the cart's tooltip, nine runs of 2,500 frames at the camp's
  fixed view for what the cart costs, four trials of the demo's new parts, a ladder carried and a
  ladder stored (a recording of 330 frames and two stills), a bare stake, and the demo four times
  (fourteen parts, one at 120 times speed). One run of the debug build's game hung on a fault of mine
  (the cart's first boards did not fit a prop's skin: "Bugs") for five minutes until I stopped it;
  its window may have stood on his desktop the while. Third round: some thirty stills and short runs, four runs of 2,000 frames, the demo's
  eleven parts. Second round: some sixty stills, the twelve fixed views once, the hamlet fourteen
  times, the shadow stills once, the demo twice. First round: some thirty-five stills, the twelve
  views four times, the hamlet eight times, the shadow stills six times, the demo twice. None is how
  the game plays.

## John's words

2026-11-12, accepting stage 6a (whole: it is also in the 6a handoff): "ok the building looks great, I am impressed, works wonderfully on my end as is, now some changes to building and zoning, first changing elevlations, if the zone is going higer and lower in elevation, the .25m next to the path will be reserved for a retaining wall built from stone in the stockpile, stairs built on the path from stone as it rises or falls to the door, dirt around the back of a blueprint  is dug away and a retaining wall is built, if multiple buildings are along that same axis then the retaining wall is extended as one, same with houses that step down, retaining walls built between them if they share a wall a retaining wall is built along the shared wall if its over .25m. Next the roofs, are to be smoothed, but not rendered smooth instantly, the builders smooth the roofs so they don't step, rounded edges around the peremeter. For zoning, we need to be able to expand the zone by overlap, I couldn't get the zone to snap to the road or other zone when trying to expand a zone, and when i place a diagonal zone next to a straight zone i couldn't expand because of overlap and minimum size rule, so I suggest this fix, instead of locking the player out for a size discrepency, make the area fixed distance from the path that will fit a hovel, and then they can pull it along the path to the desired length, and if they intersect with another habitation zone let them overlap and just combine the entire zone, to fix the player from being able to pull the zone as far as they want, don't let them go farther than 7 blocks from the end or turn of a path. That we can do for this pass, then we will have an intermediate sleeping, beds, campfire to house transition. After that we will get to the stockpile, and how the player manages this."

2026-11-12, on the pass as first put to him (whole): "Yes extend as one and they, don't need to be extended as a straight line they can meet and turn into each other, just take the difference between the two. The roof looks good, no need to write a seperate shader program for something that is going to realize it's cost eventually. Hovels need to fit within the confines of the zones, if they don't fit the housing deficit stands until the player designates more area, when we get to the players character they will be told that is problem they need to rectify. Don't let the serfs search for a lot, just assign it to them by lottery, when the construction is complete. So the next things on top of that are have serfs sleep on their side, when the campground is built have them pull or collect straw for a bed, and can we add cloaks, they can set down next to their bed during the summer, wear it during with their winter clothes in the winter, and use it as a blanket when they sleep? When they get assigned a home they can build a new straw bed in their house, we will let the old one decay outside when we add decay later. I think that is enough of this pass before I discuss the stockpile."

2026-11-12, on the second round (whole; with two pictures, a camp on a hillside with its beds and sleepers over the edges of the terraces, and a block inside four paths zoned as housing with a slice of zone on the far side of one of them): "ok, a couple of faults, it would be nice if the serfs found level ground and slept perpendicular to the fire, serfs didn't create a bed when straw was in the stockpile, might have been reserved by the housing, basic needs take priority, serfs would go long distances to fend for themselves to eat vegetables when furit and berries were near by, it would be nice if player had a fill option for closed loop paths, the pathing zone also just forms a stright line by elevation and it is in the air above the ground instead of drawing along it, if a player starts to draw a habitation zone that extends the length of a path and crosses over a path that changes direction a slice of the habitation zone passes over the connecting road, that should be enough for this pass."

And a little after, while that was being built (whole): "also can we increase the work and travel speed of serfs by about 50%"

2026-11-12, on the third round (whole; with one picture, `swappy-20261112-202523.png` in `~/CASTLE_GAME/TEST SCREENSHOTS/`: a hovel on a hillside beside a path that climbs across the picture in terraces, the ground before its door level out to the path, and where the door's way meets the path a patch of fieldstone some four blocks wide and three deep with one step in it): "[Image #16], so a minor tweak with the house pathing and stepping as shown in the image, the stairs were added when the pathway was pretty much already leavel witht he house path, serfs building spend a lot of time walking around the house thatching, can we have them construct a ladder in the stockpile, and use the ladder to thatch roofs, that would be cool, the other thing i noticed is that rather than waiting for the cook to use the stockpile to cook food, the serfs were eating raw directly from the stockpile preventing food from being cooked, can the cook reserve food in the stockpile and only suprlus is availible to eat raw if no stew is present, we need to up the amount of meat a single deer can provide, we are looking at 60lbs of field dressed meat from a deer that should be enough to feed a camp for a couple of days when smoked or cured, we can talk abit about the story now, the player is a minor noble tasked wtih improving the land by their lord, taxes on production would come after a few years, so the lord provides a small workforce a minimum of starting supplies so for now lets just add a cart with salt in it for curing, we can expand the supplies later and work the story in as we get to the players role, but for now that way a single deer can provide for the camp for a couple of days"

2026-11-13, on the fourth round (whole; with one picture, `swappy-20261112-235645.png` in `~/CASTLE_GAME/TEST SCREENSHOTS/`: a hovel's lot beside a path dug down a block over all its ground, a builder in it, the turf standing round its back and its left side as a bank, a green patch or two on its floor): "Some new things I found on my latest testing, people carrying items to the stockpile will stop and eat instead of completing their task and then eating, this creates an oddity where foresters carrying logs back to the stockpile have a log on their sholder while they are eating, I am sure this can happen while carrying other things too. [Image #17] This screen shot shows dirt having been removed, and the grass stays in the air. It also shows that othewise even ground was dug out entirely becuase it had a couple of holes in it, instead of just filling the holes. It would be nice if there was a way for serfs to fill in holes in the path when they are compacting the ground."

And a little after, while that was being looked into (whole): "Also, I removed the cook from cooking, he started building a house, the build was asigned to him, I then sent him back to cooking mid build and it didn't free up the assignment for the build."

How it was read.

First round: three things, built in the order zoning, walls, roofs, each its own commit.

Second round, sentence by sentence:
- "Yes extend as one ... they can meet and turn into each other, just take the difference between the
  two": a house begun beside an earlier one makes the ground between them ready with its own, so the
  two stand on one terrace (or on two with one wall between) and the walls behind them are one wall
  that turns where their backs differ.
- "The roof looks good, no need to write a seperate shader program": nothing done; the look's cost
  stands as measured.
- "Hovels need to fit within the confines of the zones, if they don't fit the housing deficit stands
  until the player designates more area": **the hovel next in turn is never passed over for a smaller
  one that would fit.** If it fits nowhere, no more are begun until there is more housing. (This is my
  reading of the sentence against what I had told him, that hovels which fit nowhere were passed over;
  if he meant only that a hovel never stands outside a zone, which was already so, the passing over
  can come back: one loop.)
- "Don't let the serfs search for a lot, just assign it to them by lottery, when the construction is
  complete": the lots of all the houses still to begin are laid out when the player zones or lays a
  path, never while the band works; a house is nobody's while it is built, and the moment it stands
  it is drawn for by lot among the living who have none.
- "have serfs sleep on their side": the pose, drawing only.
- "when the campground is built have them pull or collect straw for a bed": each makes its own, once
  the camp stands: straw from the stockpile, or cut by its own hand.
- "can we add cloaks, they can set down next to their bed during the summer, wear it during with their
  winter clothes in the winter, and use it as a blanket when they sleep?": yes, all three, drawing only.
- "When they get assigned a home they can build a new straw bed in their house, we will let the old
  one decay outside": a second bed, in the house; the first stays where it was made.

Third round, clause by clause:
- "it would be nice if the serfs found level ground and slept perpendicular to the fire": each of the
  band chooses a place of its own round the fire once the camp stands, lying across the way to the
  fire (not with its feet to it, as it lay), on ground level under all its length; it sleeps there
  and makes its bed there. **"Perpendicular to the fire" is read as side on to it**: its length
  square to the line from it to the fire. They lay with their feet to the fire before, which is the
  other thing the words could mean; if that is what he wants kept, with only the level ground new,
  it is the two lines of `Place_Bed` that say which way a place lies, and `Bed_Near_M`.
- "serfs didn't create a bed when straw was in the stockpile, might have been reserved by the
  housing, basic needs take priority": a bed takes stored straw whatever the hovels being built still
  want of it. **I could not make a serf go without a bed with straw stored**, in runs of my own on
  sloping ground with and without housing, in summer, autumn and winter: in every one all six had a
  bed by the next morning (the runs are under "Measured"). So I do not know which of three things in
  the code he met, and changed all three: the hovels' first call on stored straw (his ruling either
  way); a memo that kept one who had found no grass to cut from the stockpile as well, for thirty
  game hours; and the band's paths coming before a bed.
- "serfs would go long distances to fend for themselves to eat vegetables when furit and berries were
  near by": one that fends goes for whatever there is to eat nearest to it. It was being sent by the
  gatherer's rules.
- "it would be nice if player had a fill option for closed loop paths": "Housing inside these paths"
  in the ground's menu takes all the free ground inside the round of paths the point lies in. He named
  no kind of zone; his picture was of housing, and housing is what it fills.
- "the pathing zone also just forms a stright line by elevation and it is in the air above the ground
  instead of drawing along it": a planned path, and the line being drawn with the Path tool, are shown
  as the block columns they will turn, each on its own ground.
- "if a player starts to draw a habitation zone that extends the length of a path and crosses over a
  path that changes direction a slice of the habitation zone passes over the connecting road": a
  strip's ground is begun only from beside its own path, so the seven blocks past a turn are never
  taken on the far side of the road that leads off it.
- "also can we increase the work and travel speed of serfs by about 50%": the band works and walks
  half as fast again; hunger, sleep and learning go by the clock as they did.

Fourth round, clause by clause:
- "a minor tweak with the house pathing and stepping as shown in the image, the stairs were added when
  the pathway was pretty much already leavel witht he house path": reproduced first (a hovel beside a
  slanting path whose floor lies one block off the path's ground: every column of its door's way past
  the landing was a tread of stone, four wide and as deep as the path lay aslant). A stair is now made
  only where the path lies more than a block off the floor, as a wall is; one block is a step of
  earth like any other.
- "serfs building spend a lot of time walking around the house thatching, can we have them construct
  a ladder in the stockpile, and use the ladder to thatch roofs, that would be cool": measured first
  (at a roof its builder was 270 game minutes thatching and 183 going from bout to bout, and trimming
  it 71 and 127). When a roof is next its builder makes a ladder at the stockpile, of a log, carries
  it to the house, stands it under the eave and lays every bout of that slope from it; then carries it
  round. "Thatch roofs" is taken as the roof and its trimming, not the gables or the walls' tops.
- "rather than waiting for the cook to use the stockpile to cook food, the serfs were eating raw
  directly from the stockpile preventing food from being cooked, can the cook reserve food in the
  stockpile and only suprlus is availible to eat raw if no stew is present": while the hearth stands
  and a cook lives, a pot's fill of what is stored is the cook's; only what is over it is eaten raw,
  and only with no stew, as before. What "surplus" is over he did not say: a pot's fill is mine.
- "we need to up the amount of meat a single deer can provide, we are looking at 60lbs of field
  dressed meat from a deer that should be enough to feed a camp for a couple of days when smoked or
  cured": meat is counted in pounds, a doe gives sixty, and a pound is worth what makes sixty of them
  two days' food for six. "When smoked or cured" is read as: salted, all of it is kept; unsalted, only
  what is eaten before it turns. Spoilage of what is stored is a later stage's and is not built;
  smoking is not built.
- "we can talk abit about the story now, the player is a minor noble tasked wtih improving the land by
  their lord, taxes on production would come after a few years, so the lord provides a small
  workforce a minimum of starting supplies so for now lets just add a cart with salt in it for
  curing, we can expand the supplies later and work the story in as we get to the players role":
  his words are recorded (the framework's decisions). Built of them: the cart, standing by the
  homestake when the band arrives, with salt in it. Nothing else of the story.

Fifth round, clause by clause (each reproduced before anything was changed):
- "people carrying items to the stockpile will stop and eat instead of completing their task and then
  eating, this creates an oddity where foresters carrying logs back to the stockpile have a log on
  their sholder while they are eating, I am sure this can happen while carrying other things too":
  found in the code (a hungry serf went for stew whatever was in its arms) and counted: on the
  reference band 47 meals in 41 days were begun with a load, every one stew at the fire, 31 by
  gatherers with what they were taking home, 7 by the forester with a log, 9 by the cook with a load
  for the pot or the fire. A load is now taken where it was going first, and then it eats. **Food of
  a gatherer's own gathering it still eats from where it is when there is no stew**, as before: taken
  home first, it went into the stores, which the cook now keeps a pot's fill of, and on the housing
  run's first day the band went hungry beside them, fended, the cook with them, and nothing was cooked
  until the next morning ("His calls").
- "This screen shot shows dirt having been removed, and the grass stays in the air. It also shows
  that othewise even ground was dug out entirely becuase it had a couple of holes in it, instead of
  just filling the holes": reproduced on level ground by the reference stake with two holes a block
  deep dug in the first hovel's lot: the whole site went down a block to their bottoms, and its edge
  stood round it as a bank of turf, as in his picture. The pad's level is now reckoned as if its
  hollows were filled, and they are. **"The grass stays in the air" I read as grass left over a
  hole dug under it**: a hole dug under tall grass, as the dig tool digs one, takes the turf and leaves
  the grass standing on nothing, and the levelling cut only what stood on a column's top. Now the dig
  takes what grew on what it removes, and a site or a path cuts whatever is left over a hole. **That
  was not what he saw** (his word after the merge, under "After the pass", below): his grass stayed on
  a couple of blocks where it had been gathered before the plot was begun, and the grass went with the
  ground every other time. The cause is not found; he will reproduce it if he sees it again.
- "It would be nice if there was a way for serfs to fill in holes in the path when they are compacting
  the ground": built, with a switch of its own (a wish, not a fault): a hollow under a metre of path
  is filled as the metre is laid, by the same test as a pad's.
- "Also, I removed the cook from cooking, he started building a house, the build was asigned to him,
  I then sent him back to cooking mid build and it didn't free up the assignment for the build":
  reproduced (the cook made a forester, then a cook again with the roof of her hovel two thirds
  thatched). The hovel was let go at once ("no builder"), but the other forester had begun a third
  hovel's ground by then and kept to it until it stood: the one half built waited a day. **Read as
  that**: a builder now takes up a house left further on than its own. If what he saw was something
  else (his own sheet still naming the cook, say), it did not happen in any of some ninety runs with
  the change made at a different minute ("His calls").

What he said is his; every number, and everything he did not say, is a first value of mine ("His
calls"). The stockpile is his to open and is not designed here.

## After the pass

2026-11-13, after the pass was merged (whole; the rest of the message, the cart
and the cloaks, is `Handoff_2026_11_13_cart_and_cloaks.md`'s): "I saw the grass going with the ground
every other time, it seemed to have just happened on a couple of blocks, the gatherer had been
collecting grass on the blocks before the plot began being built, maybe there is something there where
the state of the grass has been modified but not completed and the grass remains? Just leave it for
now, if I reproduce it again, I will try and recreate the exact conditions for debugging." Left at his
word: nothing done. Whether `Cut_Plants` (a site's levelling cuts whatever is left over a hole) covers
what he saw is untested.

## What John sees on first launch

Since the fourth round:
1. **The fourth round's saves are refused** (colony blob 24).
2. **Nobody eats with a log on its shoulder.** A serf with a load takes it where it was going, then
   eats; a gatherer that grows hungry goes home with a part load. A gatherer with no stew to be had
   still eats from what it has gathered, where it is, and one below 15 % eats whatever it holds.
3. **A hovel's lot with a hole or two in level ground is levelled where it lies**: its builder fills
   the holes (up to four square metres each), and the lot is not dug down to their bottoms. On his
   kind of lot the ground is ready about three hours sooner. A slope is levelled as it was.
4. **No grass left in the air.** Digging a block takes what grew on it; a builder or a path cuts
   whatever was left over a hole.
5. **A path the band lays fills the holes under it**: a pit, a dent, a ditch closed at its ends, up
   to four square metres, is filled with earth and the path laid flat over it. A step of a slope is
   left a step. A hole beside the path stays.
6. **A house left half built is taken up.** Take its builder off for another job and the next
   forester leaves a hovel barely begun for it, and goes back to its own when it stands.
7. Option: `--no-path-holes` (a path laid down into holes, as it was).

Since the third round:
1. **The third round's saves are refused** (colony blob 23).
2. **A cart stands a few metres from the homestake** from the moment the stake is raised: four
   wheels, boards, shafts, six sacks of salt. Pointing at it says what is in it (240 lb). Nobody walks
   through it, a stockpile or housing marked across it leaves its ground out, and a camp marked over
   it or a path laid through it is refused ("the lord's cart stands there: it cannot be moved yet").
   It goes to the first level, open ground found going out from the stake from four metres and round
   from the north, so by a bare stake it stands four metres north of it.
3. **A hunter's first errand is a sack of salt**, from the cart to the stockpile, and another whenever
   less than 16 lb is stored. A deer is salted as it is butchered.
4. **A deer feeds the band for days.** Meat is counted in pounds, a doe is sixty, and the Food line
   goes up by two days when one comes in. The reference band kills 17 deer in 41 days where it killed
   33, has eleven to seventeen days of food in hand through autumn and winter where it had three to
   twelve, and hunters and gatherers are at rest much of the time. **A first winter costs the band nothing now**, with or
   without a winter store ordered ("His calls", the first).
5. **With little stored, the hungry wait for the stew.** Once the hearth stands, a pot's fill of what
   is stored is the cook's, and nobody eats it raw: a serf below 40 % says "hungry:" and works on. The
   camp's sheet has "Kept for the pot". On a first day the stew is ready about half past two; the
   hungriest is at 25 % by then.
6. **A roof is thatched from a ladder.** Its builder is seen making one at the stockpile (or felling
   a tree for the log first), carrying it over its shoulder, standing it under the eave, and working
   from its rungs; it carries it round to the other eave, and back to the stockpile when the hovel
   stands. A roof takes two thirds of the time it took.
7. **No patch of stone before a door that is a step off its path.** Two blocks or more still get
   their stair.
8. Options: `--no-cook-hold`, `--no-curing`, `--cart-salt LB`, `--no-ladders`; `colony_run --who`
   (what each of the band is doing, under each food line).

Since the second round:
1. **The second round's saves are refused** (colony blob 22). A save from before stage 6a loads, with
   no houses, and its band keeps the pace it had.
2. **Everyone is half as fast again**, at work and on foot. Hunger and sleep go by the clock as they
   did, so the same band has more to show for a day: at the reference site the six hold 11.8 days of
   food at their most where they held 5.6, nobody is hungry at any midnight of the first winter, and
   all six are living at its end where three were ("Measured"). Nothing was retuned.
3. **A faster band fills its stockpile.** With the reference stockpile of 48 places and housing being
   built, every place is taken by the thirty-seventh day (thirty-odd hides among them). Gatherers
   with nowhere to put their berries stand holding them, awake at night. A hunter home with a deer
   and nowhere to butcher it now puts it down when it is hungry or night comes, and fetches it when
   there is room (it stood with it and starved: a fault, below). What a full stockpile should mean is
   his to say with the stockpile.
4. **By the fire each lies across the way to it, on a level place of its own**: a ring just clear of
   the camp's floor on level ground; on a hillside above and below the fire, along the hill, as far
   as 5.5 m out. Its bed is made there. Asleep, its face is to the fire.
5. **A bed is made before anything of the band's building but the camp**, and takes stored straw
   first, whatever the hovels being built still want.
6. **Starving, a serf goes to the nearest food**, whatever it is.
7. **"Housing inside these paths"** in the ground's menu (below "Housing from here", wherever a path
   has been marked): the whole block inside the paths round that point becomes housing, one zone with
   any housing already in it, and the note says how many hovels it has room for. Where the paths do
   not close: "no housing there: the paths round that ground do not close (or it is more than 50 m
   from there to them)". There is no preview.
8. **A strip pulled past a turn ends at the road that leads off**: nothing of it on the far side.
   Where no road is in the way it still runs its seven blocks past the end.
9. **A path being drawn, and a path planned, lie on the ground**, block column by block column, over
   every terrace; neither hangs in the air or is buried.
10. `--pace 1` is the band as it was; `--housing-inside X Y` fills a block from the command line.

Since the first round:
1. The first round's saves are refused too. A save from before stage 6a loads, with
   no houses.
2. **"Room for N hovels" is exact, and counts the hovels not yet begun.** The lots are laid out at
   the click. The note reads as before ("housing zoned: room for 1 hovel", "housing extended: room
   for 2 hovels now"); the zone's tooltip has a line "Room for: 2 more hovels". **In the demo's first
   part the notes now read 1 and then 2 where the first round's read 2 and 4**: one hovel is begun
   between the two clicks and is no longer counted, and the fourth in turn, which the first round
   passed over for a smaller one, does not fit on what is left. Where the next hovel in turn does not
   fit the note says "room for no hovel yet: the next in turn does not fit on it (pull it further, or
   mark more elsewhere)", and the tooltip "No room: for another hovel: mark more housing along a
   path".
3. **Fewer hovels on some ground than before.** Nothing is passed over, so a length of housing holds
   the next hovels in turn or stops at the first that does not fit: above the hillside path east of
   the stake four where five stood. On the steepest ground a lot may lie on, at 3 of 24 angles of the
   path, the hovel next in turn stands on neither side and one side holds none until he marks housing
   elsewhere.
4. **A hovel being built is nobody's.** Its tooltip says "For: whoever draws it when it stands"; its
   builder is "going to work on a hovel". The moment it stands it is somebody's ("Lives here"), and
   that person's sheet says "Home: a hovel of its own, drawn by lot". Whoever drew it sleeps there
   from that night (from the next, if it was already asleep by the fire).
5. **On a hillside a row of hovels stands on one terrace with one wall behind it.** The later house's
   builder digs out the ground between it and its neighbour and walls it with its own; the wall
   behind turns where the two backs differ; where the two floors are more than a block apart there is
   one wall between them. **Not where a tree stands between two lots**: those two stay apart, each
   with its own side wall (above the path east of the stake: three hovels as one and the fourth apart).
6. **Asleep, they lie on their sides, a little curled up.** The dead lie on their backs, as before.
7. **Beds of straw round the fire.** Within a few hours of the camp standing each of the band has cut
   two sheaves (or fetched them from the stockpile if it has straw to spare) and made a bed where it
   sleeps. Its sheet says "Bed: of straw, by the fire". It sleeps on it.
8. **A new bed in its hovel.** Whoever draws a hovel makes another bed in it, that day or the next;
   the one by the fire stays.
9. **Cloaks.** Each has one, of the wool its winter cloak always was. Outside winter it lies folded by
   the head of its owner's bed; in winter it is on its owner's back; asleep, its owner lies under it.
10. `--lineup 6 --lineup-does Sleep` shows a row asleep under their cloaks in daylight (no colony).
    `--no-beds` is the band as it was before beds.

From the first round, as it was:
1. **Housing is pulled, not cornered.** The Housing tool (or "Housing from here"), a click beside a
   path, and the strip shows along that path as far as the cursor is pulled along it; a second click
   takes it. It reaches 9.5 m back from the path's edge, more beside a path that runs aslant.
2. **It never refuses for size.** Pull again from inside it or from its end: one zone. A pull that
   crosses a gap between two zones makes them one. A strip aslant and a straight one that meet are one.
3. **It stops 7 blocks past the end or the turn of its path**, and 60 m in one pull.
4. **On sloping ground a house stands on a level terrace held by stone**: a wall along the path's
   edge, a wall close behind the house, a wall under the low side, stone treads on the stair to the
   door. On level ground there is none of it.
5. **Stone has to be there.** The hearth's ten stones are the camp's first; on the hillside east of
   the stake a hovel takes 3 to 25. With none in store the builder goes back to felling and the
   tooltip says "Waits for: stone in the stores"; a porter gathers it when it is asked for.
6. **Roofs go from steps to a slope behind the builder**, strip by strip.
7. **A hovel takes about four game days from one forester.**

## His calls (what I decided that he may want otherwise)

Fifth round. The first two change what he sees most.
1. **A gatherer still eats from its own basket when there is no stew.** The plain reading of his
   sentence is that it takes its load home first like anyone. Built that way first, it starved the
   housing run's first day: what the gatherers brought home went into the stores, the cook keeps a
   pot's fill of those (his rule of the fourth round), nothing was cooked yet, and nobody else could
   eat it; the band fell below 15 % and fended, the cook with them, and nothing was cooked until the
   next morning. So a gatherer eats where it is, as before, from what it has gathered, unless stew is
   to be had; then it takes its load home first. A load taken home first is also how the hold will
   work best once a first day has stew in it: his.
2. **"The grass stays in the air" was read as grass left floating over a hole dug under it** (mended
   anyway); what he saw was something else, not found (below, "After the pass"). The bank of turf
   round a cut was the other thing his picture shows: its side is drawn green, as every step of the
   meadow's turf is (the grass look of 2026-11-11), and it was not changed. His lot is no longer dug,
   so it has none; a lot cut into a slope still has one. Drawing a cut's side as earth with a lip of
   turf, and a natural step as it is, would want the renderer to know which was dug: possible, not
   built.
3. **One below 15 % eats whatever it holds**, as before, since what it carries has had two and a half
   hours to get where it was going and has not (no room, or no way). One that fends eats what it
   gathered. With nowhere in the stockpiles for its load, it eats with it in its arms: what a full
   stockpile should mean is his to open.
4. **A hollow is ground at one level closed in on every side by higher ground, at most 64 columns**
   (four square metres: `Hollow_Most`), filled to the lowest of the ground round it, twice over (a
   hollow in the bottom of a hollow fills up to the rest of it, then that to the ground round it). A
   pit, a dent, a ditch closed at its ends. Anything that goes on to lower ground (a step, its inside
   corner, a notch running into it) and anything wider is left as the land lies. Round a metre of
   path a hollow must lie within ten columns of it to be seen (`Hollow_Reach_B`).
5. **The earth for a hole is the turf cut off the floor or the path**, never carried, and nothing
   counts it (a hovel's pad has a few hundred columns of turf, a metre of path a couple of dozen; a
   hole of a few columns is far less). The earth heap in the stockpile is still asked for by nobody.
6. **A path laid at once with the band's labour off is laid as it was**, down into its holes: only a
   metre the band lays (or `--paths-built`) is filled. A path already laid is not gone over again.
7. **A builder leaves its own hovel for one left further on than it**: on by nothing while a site's
   ground is made ready, then by the blocks laid. Its own then waits for the next free forester; what
   lies at its site stays there.

Fourth round. The first five change what he sees most.
1. **A first winter costs nothing now, and nothing was retuned.** A doe was 240 points of food and is
   2,880 (60 lb at 48 a pound: `Deer_Lb`, `Pound_Stew`), which is his sentence taken as it stands.
   The day's food, the pot, the reserves and the winter are as they were. With no orders at all the
   reference band used to starve in its first winter (the design: "the surplus is the player's to
   require"); it now lives through it with one to five days of food in hand and nobody hungry at a
   midnight. Whether the game wants that, or the pound made worth less, is his.
2. **Nothing spoils, so salt's whole effect is at the butchering**: salted, a deer's meat is all
   kept; with no salt a quarter is (`Fresh_Div`). That quarter, fifteen pounds of a doe, is still
   three times what her eight joints were, so a band whose salt has run out is better fed than any
   band was. Spoilage is stage 11's and I did not build it into this; smoking is not built.
3. **The cart**: 240 lb of salt (`Cart_Salt_Lb`: forty does), a pound to ten of meat. It cannot be
   moved, emptied or filled. Where it stands is the code's choice, not the player's. Salt is carried
   by hunters to the stockpile and kept there like any good (a sack to twenty pounds); it is never
   asked for, since nobody can make it.
4. **The cook keeps a full pot's worth** (`Cook_Keeps`, 900 points as stew, whatever is in the pot),
   only once the hearth stands and while a cook lives; the starving who have found nothing to gather
   break into it, as into the winter store, and in winter that is anyone below 15 %; what a serf
   carries it may still eat.
5. **The cook does not stir until the pot is full or nothing more is to be fetched**, and that, more
   than raw eating, is what a hungry band is seen waiting for: on the reference band's first day the
   pot is two hours in filling, a load at a time as the vegetables come in, and the stew is ready at
   half past two with the hearth standing since a quarter past ten. It is a rule of stage 4 and I did
   not change it. Stirring at half a pot, or when somebody is hungry, would be a small change.
6. **The ladder is for the roof and its trimming only.** Gables and the walls' tops are daubed from
   the ground as they were, with the same walking round (215 game minutes at the walls of the hovel
   measured). One log, twenty seconds to make. With no log free its builder fells for it, two trees
   at the most, then thatches from the ground. Two builders make a ladder each. Between two hovels it
   goes back to the stockpile and is fetched again.
7. **No climbing is shown**: the builder is on the ground or up the ladder, and works there in the
   crouch it has for all its building.
8. **One block is no stair**: a door's way a block above or below its path is earth with a step in
   it. Two blocks or more is a stair of stone, as it was.
9. The meat reserve's default is 20 as it was, now pounds: hunters go out when less than a third of a
   doe is stored or on its way. A deer's weight by its kind: fawn 20, young stag 45, doe 60, stag 75.

Third round. The first six change what he sees most.
1. **The pace is one number, 1.5, on every work timer and every step** (`Serf_Pace`): picking,
   felling, reaping, butchering, tamping, laying a block, lifting and putting down, walking, strolling,
   a hunter's stalk. Not on hunger, sleep, the clock, what an hour's work teaches, a hunter's patience
   at its aim, or the deer. **Nothing was retuned for it**: food values, the day's food, the reserves
   and the winter are as they were, and the first winter, which killed half the reference band, now
   kills none of it. His to say whether that is wanted.
2. **A full stockpile.** I mended the one thing a serf starved of (the hunter's kill) and nothing
   else: gatherers still stand awake with what they cannot store, and hides still take places nobody
   has a use for. The eighth reference run has a second stockpile so that it stays a check of housing.
3. **Across the way to the fire comes before level.** Every place lies square to the way to the fire;
   of those, level ground is taken first, a place one block out of level counts 3 m further off, and
   more than two blocks out is no place. On a hill that puts the sleepers above and below the fire.
   It never lies along a contour that runs another way. With no place at all within 5.5 m it lies as
   it did, on the ring with its feet to the fire.
4. **No further than 5.5 m from the fire**, because one asleep more than 6 m from a warm fire is cold
   in winter. On level ground that is room for thirty-odd; a larger band's rest lie on the old ring.
5. **A bed before the paths, not before the camp**: it waits for the camp to stand, then comes before
   every other building of the band's and before its job. The reference six had theirs an hour and a
   quarter after their camp stood.
6. **A bed takes any stored straw; building holds none back for beds.** A builder may take the last
   sheaf, and a sleeper then cuts its own.
7. **Asleep it faces the fire**, and heads and feet turn about round the ring (odd and even members).
8. **A place is kept**, bed or no bed, until a path, a house's ground or a dig comes to it; then the
   bed there is gone with its straw and its maker chooses again. Housing merely marked over it does
   not move it.
9. **One who found no grass to cut looks again thirty game hours later** (it was so; what changed is
   that the stockpile is asked first, every time).
10. **A fender goes by the straight way to the food and nothing else**: not what it is, not how far
    from the stake. Gatherers go by his stage 4 rules as before. `Hungry_At` and `Very_Hungry` are
    untouched.
11. **The filling is of housing only**, and takes whatever free ground is closed round: by paths, and
    by water, another zone or a line of boulders where those close it, so long as a path lies beside
    it somewhere. It is as deep as the paths lie apart, so his depth "that will fit a hovel" and his
    seven blocks are a strip's rules, not its. A lane cannot be laid inside it afterwards (a path
    goes round zones): lay the lane first. No preview.
12. **A side road that leaves a strip's own path part way along it does not end the strip**: it goes
    on beyond, on both sides of the side road. Only the ground past the path's own end is held back.
13. **The seven blocks past an end stay** wherever nothing is in the way of them.

Answered by him on 2026-11-12, and built as he said (second round): the walls behind a row are one (first round's
call 8); no second shader program (the look's cost stands); nothing is passed over (call 6); the search
for a lot is gone from the band's work.

Lots and the lottery
1. **Nothing is passed over**, as I read him (above). What it costs him is in "What John sees", 3.
2. **The draw**: among the living who have no hovel, at the moment one stands, by the hovel's own
   seed. No turn, no merit, no household: whoever it falls to. A builder may build five and draw none.
3. **A dead owner's hovel is drawn for again**, the second after, among those without.
4. **Lots are laid out at the click** (and when a path is laid), all of them, nearest the homestake
   first. A lot is looked at once more when its house is begun; only if it no longer holds its house
   are they laid out anew.

The ground between neighbours
5. **Which houses are neighbours**: two that face the same way along one path, their walls side by
   side, with no room for another lot between (so up to 7 m and a little apart). Not across a turn of
   the path, not across the path.
6. **A tree keeps two houses apart.** Anything a zone does not take (a tree, a bush) standing in the
   gap, and the later house keeps to its own ground; each walls its own side as in the first round. I
   tried the ground made one round the tree's foot: in a gap a few blocks wide the tree's own ground,
   walled, shuts the back of the gap off, and what lies behind it is a pit (a check found it). The
   other way is for the builder to fell the tree; not built, his to say.
7. **The later house does the work** and pays the stone: all the ground between, to its own floor's
   level, and the wall between the two if their floors are more than a block apart. The earlier house's
   side wall, if it had one, is taken down to what is still wanted of it.
8. **On level ground too** the ground between two hovels is the later one's to clear (what grows there
   is cut); nothing else is seen of it.

Sleep, beds, cloaks
9. **A bed and a cloak change nothing but what is seen.** Nobody is warmer, better rested or happier
   for either. He gave them no effect, so they have none.
10. **A bed is two sheaves** (`Bed_Straw`), or what its maker could come by, one at least: a thin bed
    if night falls on it with one sheaf in its arms.
11. **Hovels have first call on stored straw.** A bed is made from the stockpile only when it holds
    more than the hovels being built still want; otherwise its maker cuts its own, as a porter cuts
    straw (the grain of wild grain cut this way is carried to the stores).
12. **When**: as soon as the camp stands, before its maker goes to its job; and again as soon as a
    hovel is its own. With grass 25 m off the six had theirs in two and a half hours; from a
    stockpile with straw to spare, in minutes.
13. **Until its bed is made an owner sleeps on its hovel's floor**, under its roof.
14. **A house's bed stays with the house**: a hovel drawn for again has its bed already.
15. **The bed by the fire stays**, where it was made, its maker's or a dead one's, as he said.
16. **The dead lie on their backs** as they did; only sleepers lie on their sides.
17. **In a winter sleep the hood stays on**; the cloak is off the back and over the sleeper.
18. **The cloak is nothing the colony knows of.** Everyone has always had one (the winter outfit's);
    where it is drawn follows from the season and from what its owner is doing. It cannot be lost,
    lent or made.
19. **Which side a serf sleeps on** is its own, from its seed.

Standing from the first round (his to change; none answered): "7 blocks" is 1.75 m; housing is 9.5 m
deep; touching counts as overlapping; a strip is begun within 12 m of a path and pulled 60 m at most;
its ground does not jump a path; a house may stand 5 m back from a path aslant; "over .25m" is more
than one block; shared walls are not built; **no yard behind a house** (a metre of yard under a wall
is a pit); sixteen blocks of wall to a stone; the earth goes nowhere; earth stands where stone is to
go until the stone is laid; a trimmed roof is one flat slope, not a curve; trimming is a stage after
thatching; the inside of a roof is in steps still. From 6a: daub is straw; a roof alone keeps the cold
off; the hearth, footings, furniture and shutters of his references are not built.

## Rules as built (first values, his to tune)

`docs/systems/habitation.md` has them whole. In short: housing is a strip along a path's straight
run, from the path's edge 9.5 m back, as long as it is pulled, no further than 7 blocks past an end or
a turn; all its free ground is taken; housing it meets is combined with it. The lots of the hovels
still to begin are laid out at once, the next in turn on the free frontage nearest the homestake,
until one fits nowhere. A house is begun on the first lot while more are without a hovel than hovels
are being built, as many at once as there are foresters; it is nobody's until it stands, then drawn
for. Its site is its walls, two blocks behind and beside, all the ground before it to its path, and
the ground between it and an earlier neighbour, at its floor's level; where what is beside the site
stands more than a block over or under, the site's edge is a wall of stone; between two sites the wall
is the earlier house's; the door's stair has stone treads. A roof is thatched in steps and then
trimmed. A serf with no bed where it sleeps, its camp standing or a hovel its own, fetches or cuts two
sheaves and lays them there.

Third round: housing is also all the free ground inside a round of paths, taken from one point. A
strip's ground is begun from beside its own path and nowhere else. By the fire each of the band has a
place of its own, across the way to the fire, level if there is level ground within 5.5 m; a bed
comes before the band's paths and has stored straw before a hovel has. One that fends goes for the
nearest food. One with a kill and nowhere to butcher it puts it down when hungry. The band works and
walks at a pace of 1.5.

Fourth round: a door's way is a stair of stone only where the path lies more than a block off the
floor. While the hearth stands and a cook lives, a pot's fill of what is stored is kept from being
eaten raw. Meat is in pounds: a doe sixty, a pound 48 points in the pot. The band comes with a cart
of 240 lb of salt, a thing in the world; a hunter keeps 16 lb in the stockpile, a sackful at a time;
a deer is salted as it is butchered, a pound to ten, and kept whole, or a quarter of it with none. A
builder whose roof is next gets a ladder (left at a built hovel, stored, made of a free log at the
stockpile, or of a log it fells for), stands it under the eave of the slope that is next and lays
that slope from it; a ladder left at a built hovel goes to the next roof or back to a stockpile.
`docs/systems/needs.md` ("What the cook keeps"), `colony.md` ("The lord's cart") and `habitation.md`
("A ladder for the roof") have them whole.

Fifth round: a load in a serf's arms is taken where it was going before it eats, unless it fends,
is below 15 %, has nowhere to put it, or holds food of its own gathering with no stew to be had; a
hungry gatherer does not top up its load. A hollow is ground at one level closed in on every side by
higher ground, at most 64 columns; a pad's level is reckoned as if its hollows (twice over) were
filled, and they are; a metre of path the band lays fills those within ten columns of it. A dig takes
the plants on what it removes, and levelling or laying cuts whatever is left over a hole. Of the houses nobody builds, a
builder takes the one furthest on, and leaves its own for one further on than it.
`docs/systems/needs.md` (eating), `habitation.md` (the ground first; builders) and `colony.md` (paths:
holes filled) have them whole.

## Built

First round
- **Zoning** (2b76ad1): `Plan_Housing_Lot`, `Run_Of`, `Join_Plan`, `Zone_Housing`, `Housing_Joined`.
- **Walls** (5993ea2, ffa938a): the block `Fieldstone`; a house's `Front`; `In_Site`, `Level_Of`,
  `Plan_Of`, `Top_By`, `Work_In`, `Site_Patches`, `Level_Column`, `Wall_Patch`; stone in
  `Kind_Of_Block`, `Note_Stone`, `Free_For_Building`; `Go_Level`; `No_Stone`, `For_Stone`; `Apron_B` 2.
- **Roofs** (d5f502a): `Castle.Blocks.Dressed`; the blueprint's `Dress` stage; the mesher's
  `Slope_Code`; the vertex shader's moved corners and normal; `Trimming`.

Second round
- **Lots and the lottery** (216bbe7): `Lots`, `Plan_Lots`, `Try_Lot` (out of `Place_House`),
  `Begin_Lot`, `Draw_Owner`, `Begin_Houses` again; `Lot_Count`, `Lot_At`, `Lots_Short`, `Room_Short`;
  `House_Tries` is gone; `Zone_View.Lots`.
- **The ground between neighbours** (46f894e, 5f8d60a): `Reach_L`, `Reach_R` and a wider `Front` in
  `Castle.Buildings.House`; `Join_Site`; `Site_U_Lo`, `Site_U_Hi`; `Plan_Of` by house, with
  `Site_Of_Block`; `For_Site` (a builder's columns: its own, and the earlier neighbour's along it);
  `Max_Site_Patches` 384; a door's way to the path's edge at each of its columns (`In_Door_Way`,
  `Level_Of`, `Is_Stair`, `Lay_Door_Path`); `Lot_Take` takes the reach; `Build_Homes_Now
  (Last_First)`; the housing line's "not at home".
- **Asleep on its side** (077f1fa): `Castle.Serfs.Sleep`, `Lies_On`, `Posed`, `Lay_Down`'s roll.
- **Beds** (ffb12d4, 7b7ca34): `Set_Beds`, `Bed_Straw`, `For_Bed`, `Think_Bed`
  (castle-colony-think_bed.adb), `Make_Bed`, `Wants_Bed`, `Has_Bed`, `Camp_Bed`, `Sleeping_Place`,
  `Lie_On_Bed`; `Castle.Props.Pallet`; `--no-beds`; `Castle.Scenario.Beds_Line`.
- **Cloaks** (7b7ca34): `Outfit.Cloak_Off`, `Rig.Cloak`; `Castle.Props.Cloak_Folded`, `Cloak_Spread`;
  `Castle.Serfs.Cloak_Of`, `Lies`, `Lying_Frame`, `Height_Of`; the game's `Show_Beds`, `Show_Cloaks`.
- **Checks**: colony_check 475 -> 509 (first round) -> 541. `tools/demo_housing_pass.sh` (nine parts).

Third round
- **Zoning** (cea5db8): `Fronts_Own`, `Of_Run` (a strip's fill begun from beside its own path);
  `Plan_Housing_Fill`, `Zone_Housing_Inside`, `Plan_Housing_Inside`, the action `Fill_Housing`,
  `--housing-inside`; `Close_Housing_Plan`, `Take_Housing_Plan` (shared with the strip);
  `For_Path_Left`, `For_Path_Line`, `Paths_Left_Key`, `Line_Pieces`, `Line_Piece`;
  `Castle.Zone_Marks.Show_Paths` by block columns and `Show_Path_Line`.
- **Beds** (b87019a): `Place_Bed`, `Lie_Ground`, `Lie_Gap`, `Bed_Kept`, `Keep_Beds`; `Member.Placed`,
  `Bed_Dir`, `Bed_Lo`, `Bed_Hi`, `Bed_Has`; `Own_Facing`; `Bed_View.By_Fire`; the tunables `Bed_Near_M`
  to `Bed_Uneven_B`; `Think_Bed` asks the stockpile first and `Think` asks it before the band's
  building; `No_Way_Id`; `Castle.Serfs.Lie_Facing`; the beds line names who has none.
- **Fending** (3b2fe5e): `Go_Forage`'s `Nearest`, `Stake_Weight`.
- **The pace** (f489288): `Serf_Pace`, `Set_Pace`, `Pace`, `--pace`; a hunter's kill put down in
  `Think`; `tools/reference_check.sh` holds seven runs at `--pace 1` and gives the eighth a second
  stockpile.
- **Checks**: colony_check 541 -> 573 (thirty-two more; a leftover print taken out of it).
  `tools/demo_housing_pass.sh` (eleven parts).

Fourth round
- **The stair** (c014061): `Is_Stair` by `Retain_Over_B`.
- **The cook's hold** (44c5880): `Cook_Hold`, `Raw_Free`, `Cook_Keeps`, `Set_Cook_Hold`, `Cook_Held`;
  `Go_Eat` and `Food_In_Store` go by `Raw_Free`; the camp's sheet's "Kept for the pot";
  `--no-cook-hold`; `colony_run --who` (`Castle.Scenario.Put_Who`).
- **The cart, salt, meat by the pound** (3a88244): `Salt` and `Ladder` on the end of `Item_Kind`;
  `Carry_Limit`, `Cell_Limit` and `Stew_Food` functions over `Carry_Table`, `Cell_Table`,
  `Stew_Table`; `Deer_Lb`, `Deer_Joints`, `Pound_Stew`, `Kept_Of`, `Salt_For`; `Place_Cart`,
  `Cart`, `Cart_On`, `Cart_Beside`, `Cart_On_Block`; `Go_Cart`, the states `To_Cart` and `At_Cart`,
  `Use_Salt`; the butchering's yield in `Step_Hunt`; a camp over the cart and a path through it
  refused; `Castle.Pick` (`A_Cart`), `Castle.Views.Cart`; `Castle.Props.Put_Cart`, `Wheel`, `Sack`;
  `Set_Curing`, `--no-curing`, `--cart-salt`; the log's `salt:` line.
- **The ladder** (5bae8a6, b67735a): `Roof_Next`, `Roof_Side`, `Ladder_Place`, `Ladder_At`,
  `At_Ladder`, `Aloft`, `Shown_At`, `Spare_Ladder`, `Go_Ladder`, `Ladder_Short`, `Wants_Ladder_Log`;
  the states `Making` and `To_Ladder`, the use `For_Ladder`; `House_Rec.Ladder`, `Ladder_P`,
  `Ladder_Fells`, `Dress_N`; the bout from the ladder in `Lay_Bout`; `Castle.Serfs.Perch`;
  `Castle.Props.Ladder`, `Put_Ladder`, `Put_Ladder_Stood`; `Set_Ladders`, `--no-ladders`; the log's
  `ladders:` line; `Off_Cart` in `Route_To` (600bcfd).
- **Checks**: colony_check 573 -> 610 (thirty-seven more: two for the stair, five for the hold,
  nineteen for the cart and salt, eleven for ladders), pick_check 38 -> 41. Its own `Reset` holds
  the three new systems off for every older section. Eleven of the changes were taken out again, in seven
  trial builds (the stair's test, the raw eaters' limit, the salted yield and the salt's use, the
  three refusals round the cart, a way kept off the cart, the bout from the ladder, the ladder's
  return, the felling for its log), and each time the check written for it failed. `tools/reference_check.sh`
  holds seven runs at `--no-cook-hold --no-curing` besides what it held them at.
  `tools/demo_housing_pass.sh` (fourteen parts).

Fifth round
- **A builder takes up a house left half built** (972269c): `On_By`, `Further_On` in `Think_House`;
  the house it picks is the one furthest on of those nobody builds.
- **A pad levelled as if its holes were filled** (e43aba0): `Hole_Fill`, `Round_Tops`; `Choose_Pad`
  reckons on its lot's tops with holes filled twice over.
- **A load taken home before its carrier eats** (c82f798): `Load_First` in `Think`; `Topping_Up`
  stops when it is hungry with a load to take home. The eight reference logs recorded again.
- **Holes under a path filled** (d5b0ab5): `Path_Fill` in `Lay_Metre`; `Set_Path_Holes`,
  `Path_Holes`, `--no-path-holes`; colony blob 24.
- **Hollows, plants over a hole, a full stockpile** (71901b5): `Fill_Hollows`, `Top_Grid`,
  `Hollow_Most`, `Hollow_Reach_B` in place of the local test (`Hole_Fill`, `Path_Fill` gone); the
  ground round a metre read once a metre; `Cut_Plants`, `Plants_Over` in a site's levelling and a
  path's laying; the game's `Edit_Box` takes the plants on what it digs; `Can_Store` (`Go_Store`'s
  own test) for a load nowhere would take.
- **A column of path raised only from its own top** (the last commit): the ground round a metre read
  as earth, turf or path only (`Raw`, the reading before its hollows are filled); a column raised
  only where that reading is its own top, by `Hollow_Rise_B` (four blocks) at most.
- **Checks**: colony_check 610 -> 616 (two for the builder, one for the lot with holes, one for every
  meal of three days, two for the path), each taken out again in a trial build (the builder's switch,
  the hole test for the pad, the load first, the path's fill) and failing then; its own `Reset` holds
  the path's fill off. `tools/reference_check.sh` holds the seven older runs at `--no-path-holes` too.
  `tools/demo_housing_pass.sh` (seventeen parts).

## Measured, fifth round (seed 1, colony_run unless said; the eating and the builder on c82f798 and
972269c, the lot, the grass and the paths on 71901b5)

- **Meals begun with a load in the eater's arms**, on the reference band with its standing orders
  through 41 days (all of the pass on) and on the eighth reference run (housing):

  | | before | after |
  |---|---|---|
  | reference band: meals begun with a load | 47 (31 gatherers', 7 the forester's logs, 9 the cook's) | 0 |
  | reference band: food in hand, morning by morning after the first | 10.1 to 17.2 days | 10.1 to 14.8 |
  | reference band: deer killed, died | 17, none | 16, none |
  | housing run: meals begun with a load | 66 | 1 (a fender) |
  | housing run, first day, with gatherers taking their own food home first | cooked by 20:00 | nothing cooked by six the next morning, all six at 0 % fed |
  | the same with a gatherer eating from its basket when there is no stew (as built) | | as before through its first day: the same stew cooked and the same eaten raw by midnight |

  Every meal is stew at the fire in both: the loads were all carried to the pot. The seven older
  reference runs, recorded again, moved both ways in their first winter: deaths 0, 6, 2, 6, 1, 6, 6
  before (27), 2, 1, 0, 6, 6, 1, 1 after (17). In the eighth all six live, as before.
- **His lot**: level ground by the reference stake with two holes a block deep dug in the first
  hovel's lot (and a rise behind it dug level, so that nothing but the holes stood off it). As it was
  the pad went down a block, the whole site was dug, and its ground was ready between ten and half
  past eleven (from half past five). Now its floor is where the ground lies, the two holes are filled,
  and the ground is ready between seven and half past eight. With two holes four by four dug one row
  deep under tall grass, as the dig tool digs (`--late --dig`): as the round was first built three
  blocks of grass stood in the air over them after the dig and still after the levelling; now the dig
  takes them (35 edits for 32 blocks dug), and with holes dug first the old way the levelling cuts
  what floats (none left of 26 plant blocks). On `colony_check`'s meadow, a lot with three holed
  columns: the pad 3.75 m and 334 game minutes of levelling; now 4.00 m and 38 (53 with a hole four by
  four and grass over a hole besides). The eighth reference run's six pads are where they were (its
  lots are on two levels, 64 and 65, with no hollows), and the east hillside built both sides of its
  path runs the same with the path's fill on and off (no hollow under those paths either: eight
  standing, eight at home after twelve days, both ways).
- **The cook sent back mid build**, the supplied builder run along the path west (two foresters,
  everything supplied, the cook made a forester at once and a cook again at twenty to seven on the
  second evening, her roof two thirds thatched, the other forester at a third hovel's ground): before,
  the hovel stood with no builder for a day, until the other's own stood; now the other was at it
  fifty game minutes later (she ate first), thatching from its ladder. `colony_check`: 8 game minutes,
  where it was 910.
- **Paths**: no hole lies under the reference paths: the eight logs are the same with the fill on and
  off. A path over a pit of one column, one of two, one of two by two and a ditch across it, on
  `colony_check`'s meadow and by the reference stake (the demo's parts p and q): all filled; a step up
  across it laid as it lies.

## Measured, fourth round (seed 1, colony_run unless said; on 600bcfd, the round's last change to the colony)

The reference band is the six at the reference site (two gatherers, a forester, two hunters, a cook)
with its standing orders (`--winter-store 10 --reserve meat 60`), 41 days from summer's fifth through
the first winter, at today's pace; one run each.

- **Meat by the pound and the cart.**

  | | before the round | with the round | the same with no salt (`--cart-salt 0`) |
  |---|---|---|---|
  | deer killed | 33 | 17 | 34 |
  | food in hand, from the fifth midnight on | 3.2 to 11.8 days | 11.3 to 17.2 days | 5.6 to 12.3 days |
  | hungry at a midnight | never | never | never |
  | living at the first winter's end | 6 of 6 | 6 of 6 | 6 of 6 |
  | salt used | | 102 lb (120 left in the cart, 18 stored) | none |
  | meat lost for want of salt | | none | 1,432 lb |

  Food is asked for at three of the forty-two midnights (vegetables at most: the gatherers go for
  those and little else). Into the pot go 535 lb of meat, 1,622 vegetables and 423 berries, where
  222 joints, 1,703 vegetables and 7,065 berries went.
- **A bare launch** (the same band and site with no orders given: no winter store, the meat reserve
  20): before the round nobody is living at the first winter's end (at the third round's pace, and at
  the old one); with it all six are, never hungry at a midnight, with between 1.1 and 5.1 days of
  food in hand, 12 deer killed, 140 lb of salt left in the cart. (The same with no salt either: all
  six live, on never more than two days of food and often hungry.)
- **The cook's hold**, measured with everything else of the round on, against `--no-cook-hold`:

  | | with the hold | with nothing kept |
  |---|---|---|
  | first day: the first stew ready | half past two | a quarter past three |
  | first day: the hungriest when it is | 25 % | 32 % |
  | first day: anyone fending for itself | nobody | nobody |
  | 41 days: eaten raw | 363 berries, 16 vegetables | 637 berries, 80 vegetables |
  | 41 days: stew cooked | 47,183 points | 46,709 points |

  The first day, traced: the hearth stands at a quarter past ten; the cook makes its bed, picks up
  sticks, and from a quarter past eleven carries the pot's fill to it a load at a time (ten pounds of
  meat, then vegetables twelve at a time, 53 by twenty past one), going for sticks twice more; it
  stirs from ten to two. So most of what the band waits for is the pot's filling, not raw eating
  ("His calls", the fifth). With meat by the pound the pot is seldom empty and little is eaten raw
  either way.
- **A ladder.** One forester building along the level path west with wood, straw and stone
  supplied (so that only its own time counts), game minutes over six days:

  | | from the ground | from a ladder |
  |---|---|---|
  | hovels standing (and the next one's roof begun) | 2 | 3 |
  | thatching: at work, and going to its work | 588 and 398 | 825 and 55 |
  | trimming: at work, and going to its work | 138 and 310 | 208 and 0 |
  | the ladder: making it, carrying it, going for it | | 16, 155 and 36 |

  So from the ground half of a roof's time is walking, and from a ladder a twentieth; the ladder's
  own errands are about an hour a hovel (carried to the house, round it three times and back to the
  stockpile).

  On the check's meadow at the old pace: 20 game minutes going to its work at two roofs, where it was
  1,023; the two hovels in 3,525 game minutes, not 4,340. In the stage 6 run, with nothing supplied
  (a hovel waits for straw and wood there), the six stand by the midnights of days 23, 25, 27, 29,
  32 and 35 where they stood by those of 23, 26, 28, 31, 34 and 36; one ladder serves all six, and
  the first is made of a log its builder felled for it at five in the evening of the second day.
- **Where a ladder's foot stands**, on four hillside paths with hovels on both sides (a dozen
  roofs): 1.25 to 2.5 m under the eave and 0.2 to 1.1 m out from it; never above the eave. Stills
  were looked at of a back eave behind ground cut into the hill and of both side eaves of a hovel
  that stands gable to the path with a neighbour built.
- **Everything on together**: the reference band with a porter for a hunter and housing on both
  sides of the hillside path east, no orders, 41 days: six hovels by the sixteenth day (the midnights
  of days 23, 25, 28, 30, 33 and 36), as many at home as stand at every midnight, six living, one
  ladder made, nobody at an errand with a ladder or a sack of salt for more than two hourly lines
  running.
- **A run goes on the same from a save**: eight days of that run end in one state
  (5d97d77e66169803) straight, on two workers, in the debug build, and through a save taken on its
  third morning with the roof half thatched and the ladder standing.
- **The cart's cost**: 2.03, 2.03 and 2.00 ms a frame at the camp's fixed view with it, 2.02, 1.99
  and 2.01 without (`ONLY=camp_day tools/look_cost.sh`, and with `--no-curing`): nothing that can be
  measured. It is 43 boxes with all its sacks. The ladder (14 boxes) was not costed.
- **What the colony's steps cost** (`colony_run --nav-stats`, the stage 6 run's 41 days, the round
  on and its three switches off, twice each on a quiet machine): 5.5 s of steps with it on and 5.6
  with it off; the slowest single plan 17 ms and 19; the longest colony second 29 to 31 ms and 19
  (traced: it is one second, at a quarter past one on day 42, with two plans in it that took 29 ms
  between them; no one thing in the run is slower than it was). As the cart was first built those were 6.9 s and 57 ms: see "Bugs".

## Measured, third round (seed 1, colony_run unless said; on f489288, the round's last change to the code)

- **The band's pace, the reference band** (the six at the reference site with its standing orders,
  `tools/reference_run.sh 41 --winter-store 10 --reserve meat 60`, 41 days from summer's fifth; one
  run each):

  | | pace 1 (`--pace 1`) | pace 1.5 |
  |---|---|---|
  | food in hand at its most | 5.6 days (day 45) | 11.8 days (day 44) |
  | hungry at a midnight | from day 55 (four of six, then all) | never |
  | living at the first winter's end | 3 of 6 | 6 of 6, with 5.1 days in hand |
  | deer killed, trees felled | 32, 39 | 33, 46 |

  The band is asked for food only up to what its orders say, so at the faster pace it reaches that
  and rests; it does not gather half as much again.
- **The pace, the stage 6 run** (the eighth reference run: housing west of the stake, a porter for a
  hunter). With `--pace 1` this build gives the log kept before the pace was changed, line for line,
  so the pace is the one cause of what follows. At pace 1.5, **with the one stockpile of 48 places**:
  the six hovels stand by the thirty-sixth day (the forty-seventh at pace 1); every place is taken by
  the thirty-seventh (31 hides among them); at five midnights from then on one or two gatherers are
  awake with berries or vegetables they cannot put down; a hunter with a deer and nowhere to butcher
  it stood with it, starving, until the change below. **With a second stockpile** (as the run is kept
  now): six beds by the first midnight; hovels by the midnights of days 23, 26, 28, 31, 34 and 36;
  as many at home as stand at every midnight; 11.9 days of food at its most; all six living at the
  first winter's end with 4.9 days in hand. State 246d0e0298bb53dd.
- **The first day** at the new pace, the reference band: its camp stands three hours after it comes
  (ten o'clock), all six have a bed an hour and a quarter later, and the 18 m of path are laid by half
  past eleven.
- **A bed with straw stored, on sloping ground** (a camp at 1196 1080 on the foot of the hill east of
  the stake, 30 sheaves supplied, built by the band; before the round's changes to beds): with no
  housing five of six had a bed by the first midnight and all six by morning; with housing along the
  path east (the hovels wanting more straw than is stored) all six by the first midnight, each
  cutting its own; the same in autumn (day 34) and in winter (day 46); two other sloping camps the
  same. **Nobody was left without a bed in any of them**: what John saw is not reproduced.
- **Where they lie** (colony_check, ground rising a block a metre): six places, all six level under
  all their length, all across the way to the fire, the furthest 5.5 m out, no two middles nearer than
  a metre; all six asleep on them at midnight. With the search taken out the same check has none
  level and one of six not on its bed.
- **Where they lie, on the steepest ground a camp may be marked on**, falling every way 15 degrees
  apart (colony_check; slopes of 0.20 to 0.28, a metre off the camp's middle within its square): 24
  camps, 144 sleepers: **124 on level ground, 20 a block out of level, none two blocks out, none on
  the old ring**, all across the way to the fire and within 5.5 m. The same camps with straw stored
  and the search taken out (an experiment, not kept): all 144 beds were made on the old ring too,
  but 23 of the 144 were not asleep on their place at midnight; with the search all 144 were. So the
  old ring on a slope gives sleepers off their beds, as in his picture, and still no serf without a
  bed.
- On seed 1, three sloping camps (1196 1080, 1192 1082, 1206 1070) looked at with their beds made:
  six each, on the terraces above the camp's bank and on the level below it (the first is the demo's
  seventh part).
- **The walk at the new pace**, one serf followed close with a sheaf on its shoulder, the same run
  at 1.5 and at `--pace 1`: the stride is longer and the legs alternate as they did; nothing trails
  or skates that I could see in frames a seventh of a second apart. Looked at, not measured.
- **Fending**, at pace 1 (the five reference runs in which somebody fends, before and after): the
  number living at the first winter's end is 6 and 6 (herds' flight), 4 and 4 (paths and reach), 5 and
  5 (stage 5c), 3 and none (stage 5b), 2 and none (stage 6). Who is where in autumn moves that
  winter; it is not tuned.
- **A strip and a road off its path's end** (colony_check): the road turned through every angle 15
  degrees apart, housing pulled the length of the path and past its end on either side: 16 of 46 were
  in two pieces before, none now; where the road leads off on the other side the strip still runs
  past the end, 18 of 18.
- **Filling** (colony_check): 39 m square inside four paths, 24,336 block columns, one zone, room for
  16 hovels along the four paths; worked out with its hovels counted in 5.5 ms. In the game, a block
  36 m by 24 m on sloping ground filled and in view: the frame's GPU time is what it was (0.52 and
  0.56 ms against 0.53 and 0.56) and its CPU time 0.20 ms for 0.13.
- **What it costs.** The stage 6 run's steps over 41 days: 5.7 s; the longest colony second 19.7 ms
  (17.5 with `--pace 1` in the same run; 18.0 to 18.7 before the round). A pull shown each frame
  0.7 ms; the click that zones 1.0 ms: as they were.
- **One state**: the reference band four years on one worker and on two; the housing run kept, with
  nothing kept to save work, and on two workers; a hillside camp with housing four days in release,
  in debug and on two workers.
- Not measured again: the twelve fixed views and the shadows' stillness (nothing of the round draws
  but marks on the ground, a pose's side and the same pallets elsewhere).

## Measured, second round (seed 1, colony_run unless said; on e94716b; **at pace 1, before the third round**)

- **Who gets home**, built by hand, two foresters, a band of eight, the hillside east of the stake,
  wood, straw and stone supplied: above the path four hovels by the midnights of days 23, 24, 27 and
  29 (3, 8, 16 and 25 stones), below it four by days 24, 25, 30 and 31 (5, 13, 23 and 14); at every
  midnight as many at home as stand. **With no stone supplied**, above the path: the one porter
  gathers it and the four stand by the same days; at one midnight one of three is not at home. Read
  three minutes at a time: the third hovel stood at nine that evening, the one it fell to was asleep
  by the fire at that minute, and slept on there. No route was asked for and none failed.
- **Its ground made one**, the same hillside: above the path two of the three pairs of neighbours,
  below it two of three; in each row a tree's foot in the gap keeps the third pair apart (the cause
  read out of `Join_Site`, not guessed).
- **A save through walls being built and beds being made** (no stone supplied; saved on a rebuild at
  five hours, when the eight have just made their beds, and at 4.44 and 5.25 days with 4 and then 24
  of a site's 25 stones there): on to seven days all three end where the run straight through does,
  adc1172012b79780.
- **Made-up ground** (colony_check): 28 m of housing on either side of a path, each side by itself,
  holds the next two hovels in turn or more at every angle on the flat. On ground falling 2 m in 7
  the two sides together hold three or more at every angle; at 3 of 24 the second side holds none.
  The 120 hovels built there: a way from the stake to every bed; every step of more than a block
  round them walled (15,562 of them, none bare; 24 stones a hovel on average, 45 at the most); 48 times
  a hovel's ground reaches over to a neighbour's, none of it left as it lay and no wall left standing between two yards; no yard a pit.
  The same by hand: a second hovel built beside the first, above the path and below it; and two
  hovels begun at once by two foresters, above and below, the ground of both in the making at the
  same time.
- **The stage 6 run** (`reference_run_stage6.txt`, recorded anew with beds): the six beds made by
  the first midnight (twelve sheaves, cut by their makers: nothing is in store); the six hovels by
  the midnights of days 24, 28, 32, 36, 41 and 46, each with a bed in it by the midnight after;
  everyone at home each midnight until the winter. State 251fb3ab4c829d4f after 41 days, the same
  with nothing kept to save work and on two workers; db5f70499a837039 after twelve, straight through,
  on two workers, in the debug build and through a save taken at six days.
- **The first afternoon**, which the beds take an hour or three of: the same run with `--no-beds`
  has four of six hungry at the first midnight (fed 8 to 28 %); with beds none (49 to 67 %), and its
  first four hovels stand a day sooner (the last two the same days). One run each: it shows the beds
  do not cost the band its first night, not that they help.
- **Its winter**: three of six living at spring on this build. Across the two rounds' builds the same
  band has ended with anything from none to four; it is the same first winter, settled by a deer or
  two, and is not tuned.
- **Night in the middle of the errand** (colony_check): the camp built at 120 moments from ten past
  eight to ten past nine, the grass 25 m off: whoever has straw in its arms when its night comes lays
  it (four of the runs had a thin bed of one sheaf), nobody holds straw into the night, every sheaf cut
  is in a bed or stored, all are asleep at midnight. Without the line that lays a part load at night
  the check fails.
- **What it costs.** The colony's steps over the 41 days: 5.7 s (the plain band's, with no housing
  and no beds, 5.9); **the longest colony second 18.0 to 18.7 ms** over three runs (it was 31 ms with
  the search for a lot in it; the plain band's is 17.2), and it is a route planned, not a lot. The click that zones housing, every lot laid out with it: 1.0 ms
  (three zones made two, seven lots). A pull shown each frame: 0.7 ms for 40 m.
- **The look** (RX 6900 XT, 1280 x 720). The twelve fixed views read what the first round's build
  read to two hundredths (the camp by day 1.97 ms against 1.95 to 1.99, by night 2.07 against 2.07 and
  2.08: six beds and six cloaks cost nothing that can be read). The hamlet of six, the first round's
  build beside this one: by day 2.55 to 2.58 ms against 2.56 to 2.60; at night, everyone asleep under
  a cloak, 2.53 and 2.58 against 2.59 and 2.59. `tools/shadow_still.sh`: 0.00 %.
- From the first round, not measured again: trimmed roofs in rain and in snow; the land's shaders
  0.02 to 0.05 ms more with no roof in view (his to leave, as he said).

## Saves

Colony blob 24: as 23, and on its end whether a hole under a path is filled (a byte). 18 to 23 are
refused. A blob of before housing loads with it off.

Colony blob 23 was: as 22, and on its end whether the cook keeps a pot's fill; whether meat is cured,
whether the cart stands and has been looked for a place, where, the way it lies, its salt, the deer
salted and not and the meat lost; what is asked and kept of salt and ladders; whether roofs are
thatched from ladders, those made and lost, for each house the eave its ladder is under, where its
foot is and the trees felled for want of one, and for each member the house whose ladder it is going
for. 18 to 22 are refused. A blob of before housing loads with nothing kept by its cook, no cart, its
meat in joints and no ladders.

Colony blob 22 was: as 21, and the band's pace (four bytes) and, for each member, the sheaves in its bed
by the fire, whether it has chosen a place there, the way it lies and the rows of the ground under it
(ten bytes more). 18 to 21 are refused. A blob of before housing loads at pace 1, with beds on and
none made and nobody's place chosen.

Colony blob 21 was: as 20, and the lots laid out (a count, whether the next hovel fits nowhere, each lot's
zone and where its house would stand: 106 bytes a lot); for each house how far its ground reaches to
either side and whether a bed has been made in it, its front yard now 94 bytes; a builder's patch of
ground in two bytes; whether beds are made, the sheaves in them all, and each member's own bed at the
camp and where. 18 to 20 are refused. A blob of before housing loads with beds on and none made.

## Bugs found and fixed

**Fifth round.** The four he named, each reproduced first: a meal begun with a load (47 on the
reference band in 41 days); a lot dug down to the bottom of its holes; a half-built house waiting a
day for a builder busy at a newer one; holes left under paths (a wish). Mine, made and mended within the
round (the first two found before they were committed, the rest after, before the round was reported):
- **The plain reading of "complete their task and then eat" starved the housing run's first day**
  (above, "His calls" first). Found by measuring it on both runs before committing; the reference band
  alone did not show it.
- **The first fix for the holes counted the turf of the floor as earth for any hollow**, the camp's
  own rule; on a hillside that raised pads a block and three hillside checks of `colony_check` failed
  (steps left bare, a reach of nothing). Replaced by a hole test.
- **That first hole test was local** (more than half of the eight round a column higher, none
  lower): it filled the end of a notch running into a step, and nothing wider than two blocks.
  Replaced by closed hollows (71901b5; committed, then mended before the round was put to him).
- **I read "the grass stays in the air" as the bank of turf** after a scan found nothing over air:
  my test holes had been dug with the grass over them. Dug as he would dig one, the grass floated
  (71901b5).
- **A full stockpile kept the hungry from eating**: whether to carry a load home first asked whether
  one more item fitted in a cell; delivering it needs a cell for all of it. Gatherers with full
  baskets went hungry to 15 % beside stew (six meals of three days in `colony_check`'s look at every
  meal). `Can_Store` is `Go_Store`'s own test (71901b5).
- **A column of path could be raised to a bough**: the ground round a metre was read from one height,
  a column's own top from another, and the higher of the two was laid at, so a log or a bough a few
  rows over a hump was taken for the ground and the path filled up to it. A column is now raised only
  where the ground read round the metre is its own top, by a metre at most, and only earth, turf or
  path is read as ground (the last commit; `colony_check` has the hump with a log eight rows over it).

**Fourth round.** In the build John has (the third round's zip) I found no fault beside the one he
named (the stair). Mine, made and mended within the round:
- **The cart's first boards did not fit a prop's skin, and the game crashed** ("stack smashing
  detected": a prop's boxes are painted into one skin of 128 by 64 texels, and nothing checked that
  they fit). The cart is now six looks of a few boxes each, a ladder's rails two boxes each, and
  `Many_Boxes` refuses what does not fit. The debug build's game hung on it for five minutes before I
  stopped it.
- **No ladder was ever made in the stage 6 run** as the ladder was first built: a lone forester's
  every log goes to the fire and the frames, and none was free when a roof came. The log is now asked
  for with the house's timber, felled for if there is none, and the builder's own first log home is
  made into the ladder.
- A ladder whose foot stands on high ground behind a house would have lain flat along the eave: it
  leans at least 1.3 up for a metre out.
- A ladder put by in a stockpile lay across its place and through the goods of the two places
  either side of it (it is 3.4 m long): it is drawn stood against a pole in its own place.
- With the demand chain off, salt and ladders counted as asked for (the rule's "everything else is
  always wanted"): they are not.
- **A stroll toward the cart cost 57 ms.** A goal under the cart's bed has no ground to stand on,
  and the planner looks over all the band's ground before it gives such a one up. Idle hands stroll
  round the stake and the camp, where the cart stands, and with a deer worth two days there are more
  idle hands: twelve such plans were the twelve slowest of the stage 6 run, each a frame of 57 ms.
  A way asked to a place on the cart is now planned to beside it. Found by `--nav-stats` after the
  first gate had passed, so the gate was run again.
- I had written that the first stew "waits for firewood". The trace does not say so (it waits for
  the pot's filling, and for sticks twice); the document says what the trace shows.

**Third round. In the build John had then** (the second round's zip), beside the faults he named:
- **A hunter starved with a deer in its arms.** Home with a kill and every place of the stockpile
  taken, it stood holding it until there was room; no need is seen to by one that carries a kill, so
  it did not eat. It never happened in a kept run at the old pace; at the new one the stage 6 run had
  it on the thirty-seventh day. Hungry, or night come, it now puts the kill down and sees to itself,
  and fetches a kill lying out only while there is somewhere to butcher it.
- **One who had found no grass to cut was kept from the stockpile's straw as well**, for thirty game
  hours (one memo for two things).
- A leftover line of mine printed "STEP n" some hundreds of times in `colony_check`'s output.

Mine, in this round's work, in no build he has had: the first search for a place kept sleepers 1.2 m
apart end to end as well as side by side, so five of six lay on the nearest ring and the sixth
further out (0.9 m now, and six fit); a release build of `colony_check` that I had not rebuilt after
changing the check gave eleven failures that were its own age and nothing else.

**Second round. One in a build John had** (the first round's zip):
- **A stub of wall across half a stair's foot.** Beside a path that
  runs aslant the columns of a door's way are not all as long; the stair was made over the shortest,
  and the longer ones ended in the yard's own front wall, two blocks high across half the foot of the
  stair. The door's way now reaches the path's edge at every one of its columns. Found by a check
  written for something else (stone standing proud between two yards).

Mine, in this round's work, in no build he has had:
- A sleeper lay beside its bed, not on it: a serf lies down wherever it stops within a step of its
  place. With a bed it now lies down on it.
- A serf to whom a hovel fell while it was carrying straw to the fire laid the straw by the fire, and
  the hovel was marked as having a bed. A bed is now laid only where its maker sleeps at that moment;
  come to the fire, it carries the straw on to its hovel.
- The ground made one round a tree's foot left a pit behind the tree (above, call 6). Taken out.
- The spread cloak left the sleeper's arm, hip and knee outside it, three times over.

First round (as reported then): a strip's ground jumped a path; a front yard thirty blocks long past
a path's end; **a builder starved in the pit of his own stair**; **a builder starved in a back yard**;
dark teeth along a trimmed roof's ends; a strip's hovels counted every frame.

## Known limits

Fifth round:
- **A cut's side is still drawn as turf**: a lot cut into a slope, or ground dug by the player, shows
  a bank of grass at its edge, as a natural step does.
- **A hollow wider than 64 columns** (four square metres) is not filled, under a pad or a path, nor
  one that opens on to lower ground; nor a hole beside a path, one under a path laid before the round
  (it is not gone over again), or one under a path laid with the band's labour off.
- **A dig scripted before the ground is loaded** (`--dig` without `--late`) cannot see what grows on
  what it digs, and leaves it: the levelling cuts it later. Nothing of the game's dig is checked
  headless.
- **A hungry gatherer with no stew still eats from its basket**, and anyone below 15 % with whatever
  it holds: a load can be seen in the arms of one eating in those two cases.
- **Nobody is assigned a house by the player**: who builds what is the band's own choice, as it was.

Fourth round:
- **The cart** cannot be moved, emptied or filled by the player. Only its bed is solid: a serf can
  stand among its wheels and shafts. The dig tool takes a block out of its bed (hidden under the
  boards) as it does out of a house. With no level, open ground within 20 m of the stake there is no
  cart, and the log says so. `--no-curing` has to be said before the stake is raised.
- **Salt running out** is not told to the player but on the cart's sheet and the log's line.
- **Hunters and gatherers are at rest much of the time** now that a deer is two days' food: there is
  nothing else for them to do yet.
- **A ladder** goes back to the stockpile between two hovels and is fetched again (a walk each way);
  it is used for the roof only; one lost with a carrier who dies is counted and not checked; the
  builder is not shown climbing; a ladder is nothing in the world, so a serf walks through one.
- **The eighth reference run still has its second stockpile**, though with a third of the hides it no
  longer fills the first.
- The first roof of a new colony costs its builder a tree felled for the ladder's log (half a game
  hour in the stage 6 run).

Third round:
- **A full stockpile** leaves gatherers awake with what they cannot store, and hides take places
  nobody has a use for. His to open with the stockpile.
- A sleeper lies across the way to the fire and never along a contour that runs another way; on a
  hill some places are a block or two out of level and part of the bed stands in the air there. With
  no place within 5.5 m, and for more than the thirty-odd places level ground has, it is the old ring.
- The filling of a round of paths has no preview and fills housing only. Refused, it says the paths
  do not close but not where the gap is.
- A hunter fetches a kill lying out when the stockpile has room for meat and for a hide
  (`Room_For`), but butchering wants room for the whole kill and a second place: with the stockpile
  all but full it can lift the same deer and put it down again between meals.
- A path's mark is flat on each block column: on a path that will be laid over a step, the step's
  face is not marked.
- Nothing was retuned for the pace; every figure in `docs/systems/needs.md` is the band at pace 1.
- Not covered by a check: the menu's row carried out with a real mouse, the Path tool's line and the
  planned paths as drawn (stills, and the demo's third part), which side a sleeper lies on.

- A wall is one block thick, and is not mended if the ground beside it is dug away afterwards.
- **A tree between two lots keeps their ground apart**, and felling it later does not join them.
- A hovel that the plan cannot place blocks every hovel after it until there is housing it fits on:
  on steep ground that may be housing somewhere else, however long this strip is pulled.
- A hovel drawn after its winner is asleep is slept in from the next night.
- A bed lies flat: on ground that falls away under it, part of it stands in the air. The spread
  cloak is two boxes, and reads as a mound, not as cloth.
- The walking map takes the highest of four block columns, so a serf can be seen to walk along the
  top of a wall with half a foot over the gap behind a house.
- A pull across a stack's edge while a roof is half trimmed can leave a triangle open at that edge
  until the row is trimmed through.
- Not covered by a check: the Housing tool's two clicks and its notes (the demo shows them); where a
  cloak is drawn (stills and the demo); a roof trimmed across a stack's edge.

## Not done

- The stockpile, and how the player manages it. His to open. What a full one should mean is part of
  it (above).
- Any retuning for the pace or for meat by the pound. Spoilage; smoking. Anything more of the story
  than the cart. A change to when the cook stirs. A ladder for gables and walls.
- A cut's side drawn as earth. Earth carried to a hole from the earth heap. Holes under paths laid
  before the fifth round, and wider dips.
- A preview of the filling. A fill for any other kind of zone.
- Any effect of a bed or a cloak. Decay of the old bed (his, later). Felling a tree that stands
  between two lots. Shared walls. Houses at an angle to the grid. The hearth in a hovel.

## Next

- **What he gave as next, in his order** (2026-11-12, with the acceptance of 6a): "then we will have
  an intermediate sleeping, beds, campfire to house transition. After that we will get to the
  stockpile, and how the player manages this." Neither is designed; both are his to open. Beds by the
  fire and in a hovel are built (this pass's second round): what the transition is to be beyond that
  is his. What a full stockpile should mean (a load nowhere would take, hides nobody uses) belongs to
  the stockpile.
- **His answers** to the calls of the third, fourth and fifth rounds, if he gives any; they stand by
  default.
- What a build is checked by: the nine checks in debug, `tools/reference_check.sh` (eight logs; the
  seven older ones held at `--no-beds --pace 1 --no-cook-hold --no-curing --no-path-holes`),
  `tools/stress.sh runner`, and for a look `tools/look_cost.sh` against the build before it and
  `tools/shadow_still.sh`. After any change to housing or to an errand that carries something, read
  "standing" against "at home" and the beds against the band at every midnight of a run built by hand
  on a hillside, both sides of a path; scan the ground for pits (`Count_Pits` in colony_check); and
  for anything that digs or fills, scan the blocks for anything left over air.
