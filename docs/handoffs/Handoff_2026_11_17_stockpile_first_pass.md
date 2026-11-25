# Castle Game handoff (2026-11-17: the far view's third round merged; the stockpile opened with a piece of the story, and its first pass built: thirteen arrive, four builders at most, a stockpile at least 15 m by 15 m, five places of overflow round it)

Branch `stockpile` from `main` (537176c: the third round merged, and the merge recorded), not merged.
`main` is the way back: `git checkout main` and both builds again.

## John's words

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

"Ok merge.": the far view's third round, `main` fast-forwarded to it (d0efbb9) and the merge recorded
(537176c). The rest opens the stockpile. It answers in prose the four questions put to him with it:
the overflow is five places round the stockpile, for whatever no place in it takes, and nobody goes
out for more until there is room; the improvements are the passes. Read as three passes (the stage
brief, "His design of it", has them): **the start** (this one), **the storehouse built**, **the
storehouse used**.

## His sentences, one by one

- The story (the count's far lands, isolated; the cart part of it; a messenger to a retinue of serfs
  and an advisor at the stake; a boon of supplies for the first few winters): written into the brief.
  Nothing of it built: "we aren't doing the player and advisor thing just yet". What the boon holds
  besides the cart's salt he did not say.
- "So we need 13 starting serfs": built. Thirteen arrive at the stake, unassigned
  (`Castle.Colony.Arrivals`, the game's and the runner's default; `--band N` as before).
- "the player begins by delegating the tasks, as we have done": as it is (everyone arrives
  unassigned; the player gives the jobs).
- "the cook becomes the cook when it is open": already so (`Choose_Cook`: once a camp is marked and
  there is something to cook, if the player has named no cook, the best cook of the band takes it up
  on its own). Nothing built. If "open" meant once the hearth stands, that is a line to change.
- "let's limit the number of builders that can be promoted to four": built (`Most_Builders`).
- The second day's request, the upgrade, the storehouse, the compacted ground, the fence and gate,
  the coverings, the wood floor: the second pass. Not built.
- The stockman, the carpenter, a serf taking a builder's place, barrels, shelves, meat and salt
  packed, water, the staging area, wood and straw piled under the coverings higher across blocks,
  stone watched, the cart unloaded at the storehouse's front, ladders leaned against it: the third
  pass. Not built.
- "for the 5 blocks of overflow ... use 5 free blocks around the stockpile as an overflow to set
  things down ... and then they won't collect anymore until space frees up. That is the start.":
  built. Read "blocks" as a stockpile's places of a metre (a block is a quarter of a metre: five of
  those would not hold a log).
- "make the minimum zoning area 15x15m for the stockpile, it can be larger the workers will adapt":
  built.
- "5x10m same as the houses, but door is on the end of the warehouse, path to the door": the second
  pass.

## What was built (a commit each, each new rule with its switch)

1. **The measure first** (`colony_run --store-stats`, 45b7ef8, 3d37f5b): the serf-hours the living
   stood with a load and nowhere to put it (by what they held) and empty-handed for want of room; when
   a load first found no place; the places in use; loads sent to an overflow place, the most in use at
   once and at the end. Nothing saved, nothing decided by it.
2. **Thirteen arrive** (18bd990): `Castle.Colony.Arrivals` 13 (the scenario's and the actions'
   default). The reference runs, the stress test and the look costs say `--band 6`.
3. **At most four builders** (d745b02): a fifth forester fells; no more houses begun at once than can
   have builders (`Begin_Houses`). `--builders 0`: no limit. Saved: colony blob 26 (25 refused).
4. **A stockpile at least 15 m by 15 m** (a41110e): the ground a lot fills, drawn out to its path,
   reaches 15 m along its path and across, measured by its block columns' middles with a block and a
   half spared for a lot aslant the grid; else "it is too small (a stockpile is at least 15 m by 15
   m)", its outline red while drawn. `--stockpile-least 0`: any size. Saved.
5. **Its overflow, and nobody setting out with no room** (94cf891): up to five places of a metre just
   outside the lot, on free ground, nearest a path first (at the lot's two ends by its path), their
   ground the zone's (outlined with it). A load goes to an ordinary place while one takes it, then to
   an overflow place; what is taken from the stores is taken from an overflow place first. Nobody sets
   out for a kind without room for a whole load of it in an ordinary place; a gatherer and a porter
   count the loads already being gathered. `--no-overflow`: as before. Saved.

## Measured

`colony_run --store-stats`, 41 days at the reference site from summer's fifth day, the reference
orders (`--winter-store 10 --reserve meat 60`), today's pace; a band of thirteen (four gatherers,
three foresters, two porters, three hunters, a cook) with housing on both sides of a path west:

| Stockpile | Overflow | Stood with a load, nowhere to put it | Stood empty-handed for want of room | First load with no place | Loads to the overflow |
|---|---|---|---|---|---|
| 15 m by 15 m (217 places) | off | 0 | 0 | never | - |
| 15 m by 15 m (217 + 5) | on | 0 | 0 | never | 0 |
| 10 m by 5 m (48) | off | 12.0 serf-hours | 0 | day 27 | - |
| 10 m by 5 m (48 + 5) | on | 0 | 0 | never | 0 |
| 6 m by 3 m (18) | off | 2,104.1 (berries most of it) | 287.6 | day 20 | - |
| 6 m by 3 m (18 + 5) | on | 0 | 844.1 | never | 23 (at most 4 in use) |

The crowd of forty-eight on 18 places, 20 days: 245.1 serf-hours holding with it off, none with it on
(19 loads to the overflow). Nobody died in any run. On the way: with only "room for one more" asked
before setting out, the 18-place band still held 853 serf-hours (berries, a basket found no place
whole); with room for a whole load asked, 257 (four gatherers set out for the last room); counting
the loads already out, none.

So on a stockpile of the least size nothing fills in 41 days at the reference site; what fills one is
what nobody uses up: hides, and earth from levelling. A stockpile of six places by three (allowed only
with `--stockpile-least 0`) fills on the first day.

## Gate

From a clean copy of 3d37f5b (gate 42): both builds with the six known warnings only; the nine checks
(water_sim 77, edit 41, ui 112, dynamics 18, serf 19, path 70, colony 654 with eleven new, deer 14,
pick 59); the eight reference logs line for line (none recorded again); the stress runner "nothing
died, nothing dropped", every pair of runs in one state (six_41_days 08acc9917935f514, housing
0e730d9f31583086, crowd_as_it_is e8a7e434484fbf07, the crowd at work f1c4881381cb9737). The states
are new because the blob is: each is `main`'s size and six bytes more and one a place (137,684 bytes
then, 137,738 now, for the 48 places of six_41_days); that the band does the same is the eight logs'
proof. The flora's hash as it was (5676219328934879273). Also, the debug runner with thirteen, six
foresters and the 18 places for 20 days: exit 0, nothing raised (7.5 serf-hours held with the five
overflow places full: berries and a kill).

## His calls (first values of mine)

1. **What a serf does when the five overflow places are full too**: it stands with its load, as
   before. No run measured did (the count before setting out keeps the loads out to what there is room
   for). The other way: set it down where it stands.
2. **Where the overflow lies**: the five places nearest a path in the ring just outside the lot, which
   puts them at its two ends beside the path. Their ground is the zone's, so the zone's size on its
   sheet counts them (15 by 17 m for a lot of 15 by 15).
3. **Things nobody uses up stay in the overflow** (hides, earth): emptying it is the stockman's, in the
   third pass. Until then a band whose stockpile fills with hides has an overflow of hides.
4. **The least size's spare**: a lot is measured on the ground it fills, so one drawn 15 m by 14 m
   against a path counts the strip drawn out to the path (14.75 m across) and is taken; a block and a
   half is spared for a lot aslant the grid.
5. **Thirteen arrive unassigned**: the band's ages and sexes are drawn as before; nothing else of the
   start changed (the cart, its salt).
6. **The cook**: as it was (above).

## Known limits

- A stockpile zoned before the overflow was on (a save from before is refused anyway) has none.
- The older demo scripts (`tools/demo_*.sh`) film moments of their own builds with stockpiles of 10 m
  by 5 m: run on this build their stockpiles are refused unless given `--stockpile-least 0`, and their
  bands are thirteen unless given `--band 6`.
- Room to set out counts loads by the places' room for that kind, and an empty place for every kind at
  once, so with several kinds short of room together the count is generous.

## Test windows and input

All input was scripted (`colony_run`; the game with `--load` of a runner's save, `--frames`, `--shot`,
`--hud none`). Every window was mine, opened under `timeout` after checking his game was not running.
Nothing of the pointer's real input path was touched.

Stills: `~/CASTLE_GAME/releases/stockpile_first_pass.png` (a stockpile of 15 m by 15 m at the reference
stake as zoned, its five overflow places outlined at its two ends by the path; and one of 18 places
after eight days of a band of thirteen, full, with loads in four of its five overflow places).

## Next: the second pass, the storehouse built

On his word. What I would build, each a default he can change:

1. **The request**: on the second morning the first stockpile zoned that meets the requirements (with
   the 15 m least, any) is to be upgraded; with none, the request stands until one is zoned. A line in
   the log and a note on the screen stand in for the advisor.
2. **The layout** of a 15 by 15 lot: the storehouse 5 m by 10 m at the end of the lot nearest the
   stake, its length running back from the path, its door in the end toward the path with the 5 m of
   staging in front of it, and a path from the zone's path to the door; the coverings along the back
   edge by the fence; the fence round the lot's edge with a gate in its front by the path; the overflow
   outside the fence. A larger lot: the same at its end nearest the stake, the rest open ground.
3. **What the storehouse is**: a hovel's frame and walls (timber, wattle and daub, thatch), a floor of
   planks, a wide door; what it takes asked of the stores as a house's is, built by the builders.
4. **The fence**: posts and rails of logs; the gate an opening of 2 m with a gate of planks.
5. **A covering**: thatch on four posts, 3 m along the fence and 2 m deep, open at the front; as many
   as fit along the back.
6. **The ground compacted**: the stockpile's ground levelled and beaten as the camp's is, its places
   kept.

## His answer (the same day), and the overflow as a signal

> So the overflow, signals to the serfs, don't carry anything else to the stockpile, they can go spend
> their leisure time at the campfire if they aren't doing anything else, if they are carylrying
> something put it in the overflow and do the same. When space opens up in the stockpile someone can
> move it from the overflow to the stockpile. And then once a spot opens up at the stockpile, people
> can go back to work. If the player is paying attention during this whole process they should have
> expanded the stockpile by then, if not  it's on them. For now there is nothing else to put in the
> cart besides salt, there may end up being two carts, we will work out the inventory system soon, so
> we can add tools and weapons in there later. We can continue.

Still on the branch, unmerged (no merge word). Taken as: call 1 answered (a load in hand goes to the
overflow; the overflow full too was not spoken of, and stands as it was); call 3 answered (what is in
the overflow is moved into the stockpile when there is room, by whoever is idle for want of room: not
the stockman's alone); the boon is the cart's salt for now (two carts and an inventory system later,
tools and weapons in them: not designed, written into the brief); "We can continue": the second pass,
with the defaults put to him (he changed none of them).

Built (90d7214): while the overflow holds anything or has a load coming, nobody sets out to bring
anything in, of any kind; one with nothing to do for want of room moves a load from the overflow into
an ordinary place with room for it, else spends its leisure about the camp; with the overflow empty
and room, work goes on. Measured on the 18 places (thirteen, housing, 41 days): 0.2 serf-hours held
with nowhere to put it; the overflow held something 135 of 984 game hours, at most three places, 42
loads moved back, empty at the end; 1,616 serf-hours empty-handed about the camp; nobody died. The
crowd on the same: 630 serf-hours about the camp, the overflow busy 18 hours. colony_check 656 (the
overflow moved into more ground zoned, the gatherer back at work after; eaten from first with nobody to
move it); the eight logs line for line.
