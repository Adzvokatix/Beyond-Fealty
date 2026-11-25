# Castle Game handoff (2026-11-17: the stockpile's second pass, the storehouse built: asked for on the second morning, raised by the builders on the stockpile, its yard beaten, fenced with a gateway, coverings along its back)

The first pass and his answer to it are in `Handoff_2026_11_17_stockpile_first_pass.md`; his design
whole is in `docs/production/briefs/Stage_6_brief.md`, "His design of it". Everything here is on branch
`stockpile`, not merged.

## John's words

What he asked of this pass (from his design, 2026-11-17):

> On the second day, the advisor asks the player to zone more area, if the stockpile isn't big enough,
> to build the storehouse, the stockpile will then be "upgraded" if it meets the requirements, the
> builders will build a stockhouse, compact the land of the stockpile, build a fence with a gate, build
> coverings for outside materials, etc... Stockhouse gets a wood floor. ... there will be a staging area
> in front for the stockman ... The coverings will be along the edges of the stockpile next to the
> fences, the backside. So think of a thatch roof with four posts with a larger opening at the front, to
> pile things under ... But we aren't doing the player and advisor thing just yet, so just simulate the
> request. I don't know make the stockhouse some reasonable size, 5x10m same as the houses, but door is
> on the end of the warehouse, path to the door, I think should work for the start. ... make the minimum
> zoning area 15x15m for the stockpile, it can be larger the workers will adapt, but that will fit the
> storehouse with the 5m of staging area at the front, the fence and coverings for the outdoor stocks.

And the word to build it, closing his answer to the first pass: "We can continue." He changed none of
the six defaults put to him in that handoff's "Next".

## The six defaults, as built

1. **The request**: at 7 h on the morning after the stake's day the first stockpile whose places make a
   lot at least 15 m by 15 m, square to the block grid, with room for the storehouse at one end, is
   upgraded; with none the request stands and is made again every game hour. The advisor is a note at
   the foot of the screen and a line in the runner's log ("advisor, day 21 at 7.0 h: The storehouse goes
   on stockpile 1: the places under and before it are closed, and the builders will raise it"; with none
   large enough: "A storehouse wants a stockpile of 15 m by 15 m, square to the grid, with room for it at
   one end: zone more ground"). As put to him.
2. **The layout**: the storehouse 5 m by 10 m at the end of the lot nearest the stake, its length running
   back from the path, its door in the end toward the path, 4.5 m of staging between the lot's front and
   the door (`Store_Yard_B`: half a metre short of his 5 m, so that the storehouse and the half metre of
   ground kept round its back fit in a lot 15 m deep; a first value, his to set); the coverings along the
   back by the fence; the fence on the lot's outer line with its gateway before the door; the overflow
   outside the fence. **The path to the door is the staging's beaten ground**, from the zone's path
   through the gateway to the door: no path of its own is laid. As put to him, but for that.
3. **What the storehouse is**: a hovel's frame and walls (timber, wattle and daub, thatch), a floor of
   plank, a door 2 m wide, no windows; what it takes asked of the stores as a house's is, raised by the
   builders. As put to him.
4. **The fence**: posts and rails of logs, a post every 2 m. **The gate is a gateway, not a gate**: two
   posts either side of an opening 2 m wide and a plank across their tops; no leaf of planks that swings
   (put to him as "a gate of planks"). A leaf would be a thing that moves in the walking map, which
   nothing else is.
5. **A covering**: thatch on four posts, 3 m along the fence and 2 m deep, its front 2.5 m high and its
   back 2 m, open all round under the roof; as many as fit along the back beside the storehouse: two on a
   lot of 15 m (a third wants 3 m and 2.75 m are left). As put to him.
6. **The ground compacted**: **beaten where it lies, not levelled** (put to him as "levelled and beaten as
   the camp's is"). The yard's blocks are laid on each column's own top when they are laid; a covering
   stands on posts down to their own ground under a roof as high as its highest. The storehouse itself
   stands on a levelled pad, walled where the ground rises or falls, as a hovel does. Levelling a lot of
   225 m2 as the camp's 49 m2 is levelled was not built: what it would cost in earth and time was not
   measured.

## What was built

On branch `stockpile` after the first pass and the overflow signal:

1. **The storehouse's design and its yard in the blueprint** (7dee523): `Castle.Buildings`:
   `Building_Kind` (`Hovel`, `Storehouse`), `Storehouse_Design`, a house's `Floor` (a hovel's beaten
   earth, the storehouse's plank), its yard (bounds, gateway, coverings), the blueprint's three new stages
   after the roof's trimming (`Beaten`, `Fence`, `Cover`); room for a building 10 m long (`Max_Long_B` 40,
   `Max_House_Blocks` 16,384, `Max_Site_Patches` 540; the fail memos' ranges moved with it).
2. **The storehouse built on the stockpile** (a74aeb4): the request (`Ask_Storehouse`,
   `Place_Storehouse`), the places under it and before it closed (`Cell.Closed`: nothing put there, what
   lies there taken first, and its builder carries what is left into the stockpile before its ground is
   made ready: `Go_Clear_Closed`), raised as a hovel is and then its yard (`House_Phase` `Yard`), laid on
   the ground as it lies (`Lay_Bout`); nobody's home, not counted as housing. The note (game) and the log
   line (runner). `--no-storehouse` (`Set_Storehouse`), saved. The reference runs, the stress test and
   the look costs run with it off: the eight logs line for line, none recorded again.
3. **The request made again every hour, as meant** (dc71747): the request is asked once a colony second,
   and its hourly repeat was tested by the tick, which never fell on that second: a stockpile zoned large
   enough after the second morning never took the storehouse. Found by the check written for it, before
   anything was put to him. With it: a stockpile named by its number among the stockpiles (the player
   sees no zone's number), and the first note shortened (a note is a line of 120 characters: it was cut
   at "raise").
4. **Colony blob 27** (9a46aeb): the storehouse put a house's kind and its yard into the middle of the
   houses' section, so a save of the first pass's build (blob 26, put to him to try) would have been
   read wrongly. 26 is refused now, as 18 to 25 are.

colony_check 667 (11 new, and 25 and 26 among the versions refused): before the morning nothing asked; on it, the storehouse begun 5 m by 10 m at
the lot's end nearest the stake, its door toward the path; 90 places closed; its builder takes away the
600 berries lying there, all into the stockpile, before the ground is touched; standing 2.9 days on, 18
logs and 43 sheaves, all from the stores; a floor of plank, the yard beaten, the fence, the gateway open
(7 of 7 columns), two coverings of thatch; a way from the stake into the yard through the gateway and to
the door; saved and loaded to the same bytes; off, nothing asked; with only a stockpile of 3 m by 2 m the
request stands, and one of 15 m by 15 m zoned after the morning takes it 21 minutes on.

## Measured

`colony_run`, the reference site (stake 1178 1078, camp 1172 1082), the reference orders, today's pace,
the band of thirteen (four gatherers, three foresters, two porters, three hunters, a cook), housing on
both sides of a path west, the stockpile of 15 m by 15 m at 1180 1075 to 1195 1060, from summer's
fifth day:

- **The storehouse**: asked at 7.0 h on day 21; no builder the first day (the three foresters were all
  at hovels), then one (Joan); its floor by day 23, its walls by day 24, its yard by day 25, **standing by
  day 26** (five days on); 18 logs and 43 sheaves. The sixth hovel stood a day later than without it (day
  27 against 26). Nobody died in 41 or 50 days either way. The runner takes 16.2 s for the 41 days with
  it, 14.0 without.
- **What it costs the band to live with it**: over 50 days, side by side with `--no-storehouse`; and, in
  a scratch build not committed, with the fence left out of the blueprint, and with three more openings
  of 2 m in the fence (one in the back, one in each end):

| 50 days | Stew cooked | Berries eaten raw | Hungry serf-hours | Confidence at its lowest |
|---|---|---|---|---|
| no storehouse | 113,980 | 10,993 | 1,116 | 59 % |
| **the storehouse as built (one gateway)** | 104,321 | 18,099 | 2,181 | 25 % |
| the storehouse, no fence | 111,256 | 13,376 | 1,262 | 44 % |
| the storehouse, an opening in each side | 110,532 | 13,394 | 1,284 | 48 % |

  **The fence with its one gateway is most of the cost**: the gateway is on the north side, by the path,
  at the lot's west end, and with it the band made fewer trips in 41 days (26,955 routes planned against
  31,031 unfenced) and each took more finding (7.05 million floors looked at against 4.10). Which loads
  walk furthest round was not traced. The cook's pot fills more slowly and more food is eaten raw.
  **Nobody died, but at its lowest the band's confidence was 25 %** (the first winter's start: on the
  second day of it, at midday, all thirteen were hungry at once; without the storehouse at most six
  were). With an opening in each side the fence costs almost nothing more than no fence. The rest of the
  cost is the places closed under the storehouse and before it, which were the nearest to the camp.

## Gate

From a clean copy of 9a46aeb (gate 45): both builds with the six known warnings only; the nine checks
(water_sim 77, edit 41, ui 112, dynamics 18, serf 19, path 70, colony 667, deer 14, pick 59); the eight
reference logs line for line (none recorded again); the stress runner "nothing died, nothing dropped",
every pair of runs in one state (six_4_years 052e04509a4a2da6, six_41_days 3a18b06b11046f19, housing
a81e4743580ea089, crowd_as_it_is 1e3acf2e8b3f541c, the crowd at work 764f7f7c2f7f33a6). The states are
new because the blob is: each is the first pass's size and 53 bytes more for 48 places (137,738 then,
137,791 now, for six_41_days: whether a storehouse is asked for, the stake's day, whether asked, its
house, a closed flag a place); that the band does the same is the eight logs' proof. The flora's hash as
it was (5676219328934879273). Two gates before it (of a74aeb4 and dc71747) were stopped part way when
the next commit came; neither had failed.

## His calls (first values of mine)

1. **The one gateway** (measured above: with it the band was hungry twice as long and its confidence
   fell to 25 % in the first winter). As built: one, before the door, as put to him ("a fence with a
   gate"). The other ways, each a few lines: an opening in each side of the fence (measured: 1,284
   hungry serf-hours, lowest 48 %, against 1,262 and 44 % with no fence at all), or no fence until there
   is something for it to keep out (theft is stage 11). I would take an opening in each side.
2. **The gate a gateway, with no leaf** (default 4, above).
3. **The yard beaten where it lies, not levelled** (default 6, above). On the reference lot, nearly flat,
   nothing shows of it; on a slope the yard's places would lie as they do now.
4. **Two coverings on a lot of 15 m**, beside the storehouse along the back; a larger lot has more (up to
   eight). The covering's sizes are mine.
5. **What lay on the places closed is carried into the stockpile by the storehouse's builder** before
   its ground is begun, a load at a time; with no room for it, the storehouse is not begun and its
   builder fells meanwhile, as a forester does. It is eaten from first meanwhile, as the overflow is.
6. **Only a stockpile square to the block grid takes a storehouse** (a lot aslant a path at an angle
   would need the storehouse turned with it: a hovel is built square to its path, so it could be, but
   the yard's fence and coverings are laid on the grid). A stockpile aslant is passed over and the
   request stands.
7. **The lord's cart** stands where it was pulled on the first day, which on the reference site is the
   staging before the storehouse's door, just inside the gateway (the band gets by it: nothing went
   unstored for want of a way in 50 days). Bringing it to the storehouse's front is the stockman's
   (third pass).
8. **The storehouse is a house like the hovels to its builders**: it waits for a free builder, and once
   it has one it is built through. With three foresters its builder was one of the three from day 22 to
   day 26, and the sixth hovel stood a day later. Nothing puts it before or after the hovels.

## Known limits

- The note is said when it changes, and once on loading a game (the game's memory of the last note said
  is not in the save): a game loaded after the storehouse is begun says "The storehouse goes on
  stockpile 1 ..." again.
- What stood on the lot when it was zoned stands in the yard: on the reference lot a boulder and a bush
  are inside the fence; a tree or a bush inside leaves its places out (the first pass).
- A save from the first pass's build is refused (blob 26); nothing older loads either.
- The older demo scripts' stockpiles (10 m by 5 m) take no storehouse: on their second morning the
  game says the note asking for more ground.

## Test windows and input

All input was scripted: the runner (`colony_run`) for every figure; the game with `--load` of a runner's
save, `--frames`, `--shot` for the stills, with `--hud none` but for the note's. Every window was mine,
under `timeout`, opened after checking his game was not running. Nothing of the pointer's real input path
was touched (the note is said by the game's loop, not by a click).

Stills: `~/CASTLE_GAME/releases/storehouse.png`: the note at 07:01 on the second morning; the storehouse
standing in its yard from above (the coverings along the back to the left of it, the cart in the staging
before its door); from the path, the gateway and the door; the coverings and the door from over the
fence; the plank floor seen through the roof cleared by the camera.

## Next: the third pass, the storehouse used

On his word. What I would build, each a default he can change, a commit a system and a switch each:

1. **The stockman**: when the storehouse stands, the band's best porter by skill becomes its stockman (a
   job of its own, `Stockman`, taken from the porters; with no porter, the idle one with the most
   portering). It empties the overflow first, then piles logs and straw under the coverings, as high as
   2 m, and brings what lies in the yard's other places nearest the storehouse's door.
2. **The carpenter**: the builder with the most forestry, once the hovels stand (none being built), and
   a forester takes the builder's place. It makes, at the storehouse, from logs: shelves along its long
   walls (two of 3 m), then barrels (a log to a barrel, 0.5 m across), eight to begin.
3. **Barrels and shelves hold what lies out**: meat packed into barrels with salt (60 lb of meat to a
   barrel), hides on the shelves, berries and apples in barrels; a barrel or a shelf is a place of the
   stockpile inside the storehouse, taken from first by the cook.
4. **Water**: porters bring water in barrels from the nearest water to the storehouse once there are
   barrels; the cook's pot the first use of it. To ask him: "the barrels of water can be used for
   berries and apples" reads two ways (barrels like the water's, or the water kept for them).
5. **The cart**: the stockman brings it to the staging before the door and carries its salt in; the
   ladders lean against the storehouse's long wall when no house wants them.
6. **Stone**: piled under a covering, as wood is ("we need to watch stone as well").

## His answer (the same day), and the third pass begun

> Ok, I am researching, barrels of water is not a good storage idea for berries and apples. So they can
> just be stacked in the baskets in the storehouse by the stockman. I like the design so far, we don't
> need to worry about travel distance right now or winter survival, just yet. Let's move on to the next
> step, I have to think about the stockpile layout some more. Leave the questions open I will get to them
> after.

Still on the branch, unmerged (no merge word: "I like the design so far" is not one). Taken as: the
question in "Next" item 4 answered (berries and apples in their baskets, stacked in the storehouse by
the stockman; barrels for meat and for water only); call 1 set aside by his word (the walk round the
fence and the first winter are not to be worried about now: the one gateway stays, nothing is changed
for it); the other calls left open, as he asked ("Leave the questions open I will get to them after"),
and nothing built on them; the stockpile's layout is his to think about; "Let's move on to the next
step": the third pass, on the defaults in "Next" with his change
(`docs/handoffs/Handoff_2026_11_17_storehouse_used.md`).
