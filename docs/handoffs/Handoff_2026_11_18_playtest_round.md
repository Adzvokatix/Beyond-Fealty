# Castle Game handoff (2026-11-18: his playtest notes: the faults reproduced and mended, the stockpile placed once, the storehouse moved to a stockyard)

The three passes before it are in `Handoff_2026_11_17_stockpile_first_pass.md`,
`Handoff_2026_11_17_storehouse.md` and `Handoff_2026_11_17_storehouse_used.md`; his design whole in
`docs/production/briefs/Stage_6_brief.md`. Everything here is on branch `stockpile`, not merged.

## John's words

His message, whole: "~/CASTLE_GAME/PLAYTEST NOTES, thoughts". The file, whole:

> PLAYTEST NOTES
>
> Tuesday 11/17
>
> BUG: Grass in the air issue when compacting ground, grass is visible, not attached to the ground in places. Even before compacting. Investigate.
> DESIGN CHANGE: Keep stockpile, move storehouse to a new stockyard zone. Storehouse to be built with doors at each end of the building, the fence is to be placed around the stockyard with the gates extending from the storehouse, inline with the inside wall of the storehouse to the stockyard.
> BUG: Hunters can't find deer even when the deer are close.
> BUG: Gatherers can't find berries even when they are close.
> DESIGN ADDITION: Add apple gathering to the list of foods.
> DESIGN ADDITION: level the stockyard, same as houses
> DESIGN IMPROVEMENT: paths still need to be leveled as well to elimiate small bumps and holes in the road, some holes get filled, others don't.
> DESIGN CHANGE: Change stockpile to a onetime placement of a 10x10 zone, remove overflow, use the last 10 blocks as a singal to the serfs to slow/cease production if the stockpile gets full.
> DESIGN ADDITION: Add doors and animations to buildings.
> DESIGN ADDITION: Add cart wheel animations
> DESIGN IMPROVEMENT: Make the tatched roofs thicker when smoothing, fuller and add charecter of straw to the edges of the roof.
> DESIGN ADDITION: Add stone, berries, apples, and salt to the list of resources in the stockpile/storeyard tooltip.
> BUG: ladders stored on the edge of the stockpile, when building the fence, prevents the builder from continuing, causing the builder to stall. Fixed with the stockyard-stockpile change, but need make sure serfs have a way to continue their work if they meet obstacles.
> DESIGN IMPROVEMENT: Fell apple tress in the stockyard.
> DESIGN ADDITION: Add builder to the job list.
> DESIGN IMPROVEMENT: When stockyard is built, change all deliveries and pickups to the stokyard from the stockpile.
> DESIGN ADDITION: Add away to delete parts of a zone, and if a structure exists, mark a structure for razing.
> DESIGN IMPROVEMENT: Storehouse needs the transparency the same as the habitations.
> DESIGN IMPROVEMENT: The newstockyard zone will make it easier to build the storehouse on angled paths.
> BUG: The end of a zone wraps around the end of a path if it extends past it.
> DESIGN IMPROVEMENT: Fix floating timber for windows on houses, make the timber extend the length of the timber columns it sit's inside. Change the color of the first fraction of blocks around the window, like planks as trim.
> DESIGN IMPROVEMENT: Fix thatching animation so serfs don't pop on and off the ladder between smoothing sections.
> DESIGN IMPROVEMENT: Add timber truss the the ends of the houses and cross member support to the sides of the houses perpendicular to the door, add trusses, ridge beam, and cross member support for the storehouse.

Taken as: his answer on the stockpile's layout ("I have to think about the stockpile layout some more",
the day before), and what he found trying the storehouse. Built this round: the five faults, the
stockpile's change, the stockyard with everything he says of it, and the two cheap interface lines.
**Not built, and put to him as the next pass with a default each** ("Next", below): the looks (doors,
cart wheels, thatch, the windows' timber, trusses, the thatcher on its ladder), the builder in the job
list, deleting part of a zone and razing, paths levelled, a rule for serfs who meet an obstacle. No
merge word: nothing is merged.

## The faults, each made before it was changed

1. **"Hunters can't find deer even when the deer are close"**: reproduced (the band of thirteen, eight
   days: 285 hourly lines of a hunter saying "no deer to hunt in reach" with a grown deer 20 to 50 m
   off, inside the hunting range). Every herd in reach was down to three, the number left to breed
   (`Spare_Last`), with two more wandering in every three days: three hunters take the two herds of
   five down to three in four hours. Nothing of the hunting was changed. **They say why now**: "the deer
   near are left to breed: no herd has more than 3", or "letting the herd it shot at settle"; a deer of
   such a herd says "Hunted: not: its herd is down to 3, left to breed" on its sheet.
2. **"Gatherers can't find berries even when they are close"**: reproduced with eight gatherers (359
   hourly lines of "nothing to gather in reach" in ten days). Two causes, by the nearest ripe bush each
   time: **a bush was one gatherer's while it picked there** (seven stood 3 to 21 m from a bush of 111
   handfuls), and **every bush within 60 m of the stake picked bare** with ripe ones at 60.6 m. The
   first is mended: **a bush takes as many pickers as it has basketfuls** (`Set_Bush_Sharing`;
   `--one-to-a-bush`: one, as before, and then the rest say "the bushes near are being picked by
   others"). The second is the band's reach and is left (his call, below). My first reading (no room
   in the stockpile) was wrong for this run: the same run again showed the lines unchanged; that reason
   is said too now where it is the reason.
3. **"Grass in the air ... Even before compacting"**: reproduced by scanning blocks
   (`colony_run --floating`: 110 blocks of long grass standing on air the moment a stockpile was zoned,
   19 after eight days). Long grass is two blocks high in drifts, and four things cut only the block
   over the ground: clearing a stockpile's places when it is zoned ("even before compacting"), laying a
   path, beating a yard ("when compacting"), and a porter cutting straw (the block it found, often the
   lower). All four cut the whole plant now; a porter cuts a tuft from its top (`Set_Top_Cut`,
   `--no-top-cut`: stage 6's reference log runs with it, since which block is left for the next cut
   moves that run). One block is left within 60 m of the reference stake: a stalk of wild grain two
   rows over the ground at 1200.75 1023.25, there before the band does anything (the generator's: not
   looked into).
4. **"The end of a zone wraps around the end of a path if it extends past it"**: reproduced (housing
   pulled past its path's end took the ground round the end as far as the path's middle line). Past an
   end it begins at the line of the path's edge now.
5. **"Storehouse needs the transparency the same as the habitations"**: found by reading: a storehouse
   whose yard was being laid (after its roof) was not offered to the camera's cut-away, and one whose
   builder had stalled at the fence never left that phase. It is offered while its yard is laid now
   (seen: a still of day 27, its yard 70 % laid, the camera's line through it: roof and near wall
   cleared).
6. **"ladders stored on the edge of the stockpile ... causing the builder to stall"**: **not
   reproduced.** A run with the storehouse on the stockpile and ladders stored there built it through.
   Nothing was changed for it; the fence no longer stands on a stockpile (his "Fixed with the
   stockyard-stockpile change"). The one place a builder can wait without end is found by reading
   (`Lay_Bout`: it lays nothing while someone stands where the next block goes, and looks again every
   two seconds): whether that is what he saw is not known. A rule for it is in "Next".

## The stockpile ("a onetime placement of a 10x10 zone, remove overflow, use the last 10 blocks as a singal")

- **The player's stockpile is one click beside a path**: ten metres square, its front on the path's
  edge, the click across from its middle, a hundred places where nothing stands in the way; turned to
  its path as any lot is. Placed once: the tool and the ground's menu offer it until one is zoned. The
  scripts' corner-to-corner stockpile (`--stockpile X0 Y0 X1 Y1`) stays, of any size.
- **No overflow** unless `--overflow`, and no least size unless `--stockpile-least` (the 15 m were for
  the storehouse).
- **The last ten empty places are kept for loads already in hands or lying out** (a forester's felled
  logs, a hunter's kill): while no more than ten are empty, nobody sets out for a load that would need
  one (a gatherer, a porter, a forester felling, a hunter); what has a place of its own kind with room
  still goes there. Whoever is held back says "the stockpile is nearly full: nothing more brought in"
  and rests about the camp. Never more than a tenth of the places are kept (his ten are of a hundred:
  on a scripted stockpile of eight, ten kept would be all of it). `--last-places 0`: none, as before.

## The stockyard

Read from his words as (the stills show it: `~/CASTLE_GAME/releases/stockyard.png`):

- **A zone of its own**, the Stockyard tool: two corners beside a path, 15 m to 25 m a side, **square to
  the block grid whatever way its path runs**; its side by the path is drawn out to it, so beside a
  path aslant the ground between is its staging. One, placed once. Its places are closed until its
  storehouse stands. A stockyard on which no storehouse could stand is refused when it is zoned, and
  says why (its ground falls more than 3 m from end to end, or its floor would lie more than 2 m off
  its path).
- **The second morning's request is for a stockyard** ("A storehouse wants a stockyard of 15 m by 15 m
  beside a path: zone one"); zoned before or after, the storehouse is begun on it.
- **The storehouse**: in the middle of the stockyard's front, **its length (10 m) along the path**, 5 m
  deep, 4.5 m of staging before it; **a door 2 m wide in each end**, none in its front; its ridge
  along its length.
- **The fence** round the yard behind it, and **a gateway beside each end, from the storehouse's corner
  out, in the line of its back wall** (its "inside wall": the one toward the yard). So the doors and
  the staging are outside the fence, by the path, and the yard is got into past either end. A gateway
  is two metres, a post at its far side and a plank across at head height, no leaf (as before).
- **Coverings** side by side along the back fence, as many as fit (four on 15 m).
- **Levelled, same as houses**: all of the lot, from the staging to the back fence, is brought to the
  storehouse's floor by its builder before anything is raised, walled with stone where the land beside
  it stands more than a block over or under; the way in from the path is the middle of the front, a
  stair where the path lies more than a block off the floor. `--no-yard-level`: the storehouse's own
  pad alone, as before.
- **What stands on it is cleared**: its trees are felled first by its builder, apple trees too
  whatever the order to spare them, their logs carried home; stumps, bushes and boulders go with the
  ground.
- **Fitted out when it stands** as before, for its new shape: inside, nine places along and four deep;
  the two middle places by each door kept clear; a barrel in each corner and the place beside it (the
  two back corners' for water); a shelf's three places in the middle of the front wall and of the
  back; the rest floor (18). In the yard: the places under the coverings (24 on 15 m), a ladder's
  place each along the outside of the back wall (9), the rest ordinary places (42 on 15 m).
- **The stores move in**: when the storehouse stands, the stockpile's places are closed; what lies
  there is taken from first and carried over, by the stockman before it sorts and by a porter with
  nothing else to fetch. `--stockpile-stays`: the stockpile goes on beside it.

**Found with the debug build on the reference site before it was put to him, and mended**: a stockyard
beside a path aslant up the hillside east of the stake, and the largest one on the same hillside, each
left its builder starving in the staging. A house's ground is dug by rows from the path; a stockyard's
staging is deep, and its far corner, dug first, lay 2 m under the path. A storehouse's ground is dug
down the stair of its way in and then outward from the stair's foot now, so what is dug always has its
way out. `tools/stockyard_sites.sh` runs those two sites and fails on anyone starving (it fails with
the old order; `colony_check`'s made-up hillside does not catch it, and says so).

## The two cheap interface lines

- **The stores' sheet lists the staples always** (berries, wood, stone, straw, meat, hides, vegetables,
  apples, salt: "none" where there is none): a kind was listed only while some of it lay there.
- **Apples have a reserve** ("Keep in store", beside wood, straw, meat and vegetables): asked for, the
  gatherers go for them. Apples were gathered already, from summer's tenth day to autumn's end; a game
  begun on summer's fifth sees none for five days.

## Measured

`colony_run`, the reference site, the band of thirteen with housing, the stockpile ten metres square
at 1180 1075, a stockyard 15 m by 15 m at 1196 1075 to 1211 1060 (its ground rises 2.2 m), 50 days:

- **When**: the request at 7.0 h on day 21; its ground 58 hours of the log; standing on day 28 at
  9.4 h (seven days; the storehouse on a stockpile, its yard as it lay, took four and a half); the
  stockman and the carpenter that second; the cart at its front 1.2 h later; all fourteen shelves and
  barrels by day 29 at 18.9 h. Nobody died.
- **What moving the stores costs is where the stockyard is put** (hungry serf-hours over 50 days, a run
  each; a run moves by hundreds for a small change):

| 50 days | the stockyard 20 m further from the camp than the stockpile | the stockyard nearer the camp than the stockpile |
|---|---|---|
| no storehouse (the stockpile alone) | 1,019, confidence at its lowest 52 % | 1,779, 35 % |
| the stockyard, the stores moved in (as built) | 2,430, 26 % | 1,000, 55 % |
| the stockyard, the stockpile staying (`--stockpile-stays`) | 1,247, 52 % | 1,134, 51 % |

- **The last places**: on a stockpile of ten metres square the band of thirteen never fills it (36 of
  98 places in use after 41 days: the signal never came). On one of 18 places: 94 serf-hours stood
  holding a load against 2,089 with none kept, and 1,305 at rest for want of room against 85.
- The runner: 21.0 s for the 50 days with the stockyard, 17.0 without.

`colony_check` 722 (44 new): the six faults' sections (a hunter's reason, housing past a path's end,
grass in the air three ways and with `--no-top-cut`, a bush shared and not, the last places kept, not
kept, and on a stockpile of eight, the stockpile placed once); the storehouse's sections on a stockyard
(a door in each end and none in front, the gateways, no way in but by them, the stores moved, saved and
loaded); a stockyard over a hump, a hollow, a bush, a boulder and an apple tree, levelled and cleared,
and as it lies; beside a path aslant; up a hillside; the largest one's blueprint (15,088 blocks). The
eight reference logs line for line, none recorded again (the reference runs and the stress test say
`--last-places 0 --one-to-a-bush`, stage 6's `--no-top-cut` as well).

## Gate

From a clean copy of 6c96645 (gate 47): both builds with the six known warnings only; the nine checks
(water_sim 77, edit 41, ui 112, dynamics 18, serf 19, path 70, colony 722, deer 14, pick 59); the eight
reference logs line for line (none recorded again); `tools/stockyard_sites.sh` (both hillside sites: the
storehouse stands, nobody starved); the stress runner "nothing died, nothing dropped", every pair of
runs in one state (six_4_years 941f19d62cc86a83, six_41_days 6685d72d2cff6a39, housing
2bb1e7ca8a68e6ba, crowd_as_it_is 94ed253b9febd23a, the crowd at work 4febcfb380602986): the states are
new because the blob is (the band the same by the eight logs). The flora's hash as it was
(5676219328934879273).

## His calls (first values of mine)

1. **How the doors and gates are read** (above, and the first still): the storehouse along the path,
   a door in each end outside the fence, a gateway beside each end in the line of its back wall. If
   the doors are to open into the yard, or the storehouse to stand end-on to the path, it is the
   blueprint's and the fitting's to change.
2. **Moving the stores in** costs or gains by where the stockyard is (the table). As he asked; the
   stockpile staying is one switch.
3. **The gatherers' reach** is 60 m from the stake (80 for vegetables when they are short). With eight
   gatherers everything nearer is picked bare in four days and ripe bushes stand just past it. Left as
   it is.
4. **The hunters' herds**: left to breed at three, two wandering in every three days. Left as it is;
   said now.
5. **The last places**: ten, a tenth at most; "slow/cease" read as: nothing new that needs an empty
   place, a place of its own kind still filled.
6. **A bush shared**: as many pickers as it has basketfuls of thirty.
7. **The stockyard's sizes**: 15 m to 25 m; 4.5 m of staging; gateways of 2 m with no leaf; its fall
   3 m at most and its floor within 2 m of its path; the way in a stair in the middle of the front.
8. **The stockyard on 15 m holds 42 ordinary places**, 24 under the coverings (three times as much
   each) and 32 inside, against the stockpile's hundred. A larger one has more yard.
9. **The one stockpile cannot be moved or enlarged** once placed.
10. **Apples**: a reserve, and the staples always listed; berries have no reserve (he named apples).

**Still open from the passes before** (`Handoff_2026_11_17_storehouse.md` and `_used.md`): a gateway
with no leaf, the coverings' sizes, the note said again on a load, packing meat takes no salt, water
has no use, the sizes of shelves and barrels, the carpenter felling when all is made.

## Known limits

- With `--no-yard-level` what stands on the lot leaves its places out, and a bush or a boulder under
  the storehouse refuses it (as a hovel's lot); the refusal then says the levelled yard's reason.
- A tree the band has not found (past its reach) is not felled first: what of it hangs over the yard
  is lopped with the ground.
- Barrels, shelves and leaning ladders are drawn, not blocks (as before).
- A save of the last build is refused (colony blob 30; 18 to 29 refused).
- **The stockyard's preview does not ask whether a storehouse could stand there**: on ground that
  falls too much it is shown as it would be taken, and the click refuses it, with the reason in the
  note.
- The Stockpile and Stockyard buttons of the Tools panel and their previews were not exercised (the
  ground's menu was, by a scripted pointer: below).

## Test windows and input

All input was scripted: the runner for every figure; the game with `--load` of a runner's save,
`--frames`, `--shot`, `--hud none`, `--timescale 0`, `--weather clear`, `--all-roofs` or
`--no-cutaway` for the stills. Every window was mine, under `timeout`, opened after checking his game
was not running. The one-click stockpile and the stockyard were zoned through the ground's menu by a
scripted pointer (`--pointer`: "Stockpile here, 10 by 10 m", 98 places; "Stockyard from here" and a
second corner, 256 places; the buttons gone from the Tools panel after), and the debug game was run on
a save with the stockyard standing. Nothing of the pointer's real input path was touched.

## Next: what of his notes is not built, a default each

On his word, each a commit with its switch:

1. **Paths levelled** ("small bumps and holes ... some holes get filled, others don't"): a laid path's
   columns brought to a line between its ends within a block (today only closed hollows of a few
   columns are filled). Default: bumps of one block cut, holes of one block filled, along the path's
   own width.
2. **Builder in the job list**: a sixth job the player gives; such a serf builds before a forester
   does and fells when there is nothing to build with. Default: it counts among the four.
3. **Deleting part of a zone, and razing**: a tool that takes ground out of a zone; a house on it is
   marked, its builder takes it down block by block and its timber and straw go back to the stores.
   Default: half of what it took comes back.
4. **Doors, and their opening**: a leaf of planks in each doorway and gateway, drawn open while someone
   is within a metre (drawn only: the walking map as it is).
5. **Cart wheels turning** as it is pulled (drawn only).
6. **Thatch thicker and fuller, straw at its edges**: the dressed roof a block thicker at the eaves,
   a ragged fringe drawn along eaves and verges.
7. **The windows' timber**: the sill and a lintel run from post to post; the blocks round the opening
   drawn as plank.
8. **Trusses, a ridge beam, cross members** in the hovels' gables and along the storehouse.
9. **The thatcher on its ladder**: kept up the ladder between two bouts of the same slope.
10. **A serf that meets an obstacle**: whoever stands where a block is to go steps aside when it is
    not walking; a builder passes over a block it cannot lay and comes back to it.

Items 6 to 8 change what a hovel is made of (its blueprint, what it takes, stage 6's reference log):
each would be recorded again, or kept behind a switch.
