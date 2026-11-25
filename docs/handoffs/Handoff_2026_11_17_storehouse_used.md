# Castle Game handoff (2026-11-17: the stockpile's third pass, the storehouse used: its places fitted out, a stockman, a carpenter, water)

The first two passes are in `Handoff_2026_11_17_stockpile_first_pass.md` and
`Handoff_2026_11_17_storehouse.md`; his design whole in `docs/production/briefs/Stage_6_brief.md`.
Everything here is on branch `stockpile`, not merged.

## John's words

His answer to the storehouse (the second pass), whole:

> Ok, I am researching, barrels of water is not a good storage idea for berries and apples. So they can
> just be stacked in the baskets in the storehouse by the stockman. I like the design so far, we don't
> need to worry about travel distance right now or winter survival, just yet. Let's move on to the next
> step, I have to think about the stockpile layout some more. Leave the questions open I will get to them
> after.

And what this pass builds, from his design:

> When the stockhouse is completed, we upgrade a serf to manage the stockhouse, who will organize the
> stockpile, a carpenter will also come about from the builders, and a serf can take a builders spot. A
> carpenter will build barrels and shelves in the storehouse, the stockman will pack the barrels with
> meat and salt, porters can also begin bringing water to stockhouse, there will be a staging area in
> front for the stockman, and the barrels of water can be used for berries and apples, hides placed on
> the self. We need to let the stockman pile the wood and straw under the coverings, and they need to
> extend across blocks so he can stack them higher. ... we need to watch stone as well. ... Stockman can
> bring the cart to the front of the storehouse, and unload all the salt into the storehouse, the
> ladders can be leaned up against the storehouse when not in use.

Taken as: the third pass, on the defaults in the last handoff's "Next" with his change (berries and
apples in their baskets inside, barrels for meat and water only); the storehouse's calls left open as he
asked, nothing built on them; the walk round the fence and the first winter not to be worried about now
(nothing changed for either).

## What it does now

When the storehouse stands:

1. **Its places are fitted out.** Inside, on the plank floor: the row by the door kept clear; along each
   long wall a shelf of three places (hides, six to a place); the two back rows barrels, eight in all
   (the two at the back on the yard's side for water, twelve pails each; six for meat, 60 lb each); the
   rest floor, eighteen places for baskets (berries, apples, vegetables, grain) and sacks of salt. In the
   yard: the places under a covering hold three times as much wood, straw or stone, stacked up to 1.5 m;
   the places along the outside of its long wall on the yard's side hold a ladder each, leaned against
   the wall. A place fitted out takes only what it is for, and only from the stockman (but water, which
   porters pour into the water barrels); anyone takes from any place (the cook its meat from the barrels,
   the hungry from the baskets).
2. **A stockman**: the porter with the most portering (another if it dies or is given other work). With
   its hands empty, before a porter's work: a load out of the overflow; the lord's cart pulled to the
   storehouse's front (in the staging, beside the way to the door) and its salt carried in a sack at a
   time; then the yard sorted, a load at a time, into the places fitted out for it. It fetches as a
   porter when there is nothing of the storehouse to do. `--no-stockman`.
3. **A carpenter**: the storehouse's builder (else the free forester with the most building). It builds
   no house, so its place among the four builders is another forester's ("a serf can take a builders
   spot"). It takes a log from the stores (as a builder does, never the fire's day of logs) to each shelf
   and barrel, the shelves first, and makes it there (an hour a shelf's place, two a barrel, a log each);
   the logs are asked for in the stores' once rows. With all fourteen made it fells. `--no-carpenter`.
4. **Water**: a porter with nothing else asked of it fetches two pails from the nearest water to a water
   barrel with room. Nothing uses it yet. `--no-water`.
5. **Drawn**: barrels (shut, or open and full of water), shelves with the hides on their boards, ladders
   leaned on the wall, taller stacks under the coverings, two buckets in a water carrier's hands.

## Built differently from the defaults put to him

- **The stockman is a porter given the storehouse's work first, not a job of its own** (put to him as "a
  job of its own"): a job would want its row in the job menu and in what each job brings in; this way it
  fetches as a porter when the storehouse wants nothing. Its sheet says "Trade: Stockman".
- **The carpenter is made when the storehouse stands, from its builder** (put to him as "the builder with
  the most forestry, once the hovels stand"): the storehouse's builder is free at that moment, and the
  hovels go on with the other foresters.
- **Berries and apples in their baskets on the floor, not in barrels** (his answer). Vegetables and grain
  go there too (mine).

## Measured

`colony_run`, the reference site, the band of thirteen with housing, the stockpile of 15 m by 15 m, from
summer's fifth day:

- **When**: the request at 7.0 h on day 21; the storehouse standing on day 25 at 17.8 h; the stockman
  (Alan) and the carpenter (Joan) made the same second; the cart at the storehouse's front half an hour
  later and its salt all carried in; all fourteen shelves and barrels made by day 27 at 12.4 h (43 hours);
  the water barrels full soon after. Nobody died in 50 days; six hovels stood.
- **What it holds** (day 70, 50 days on): 33 hides on the shelves (of 36), 352 lb of meat in the barrels
  (of 360), 24 pails of water, 45 lb of salt and 25 vegetables on the floor, 23 logs, 24 sheaves and 21
  stones under the coverings, three ladders against the wall. Hides and meat past the shelves' and the
  barrels' room stay in the yard.
- **The band**, 50 days, a run each:

| 50 days | Hungry serf-hours | Confidence at its lowest | Stew cooked | Berries eaten raw |
|---|---|---|---|---|
| no storehouse | 1,116 | 59 % | 113,980 | 10,993 |
| the storehouse, nobody using it | 1,745 | 37 % | 107,128 | 15,580 |
| **the storehouse used** | 1,231 | 33 % | 111,736 | 12,581 |

  One run each, and a run moves by hundreds of serf-hours for a small change: the middle row is the
  setting I reported as 2,181 and 25 % last time; between the two runs only the skill that moving a load
  out of a closed place practises changed. Not chased: travel and the first winter are not to be worried
  about now (his word).
- The runner: 19.0 s for the 50 days with it, 16.8 without the storehouse.

colony_check 678 (11 new): the places fitted out (18 floor, 6 shelves, 6 barrels for meat and 2 for
water, 12 under the coverings, 8 against the wall); the stockman the porter with the most portering and
the carpenter the forester who built it; the fourteen made in 28.5 game hours, a log each; the cart at
the front and its 240 lb of salt carried in; the yard sorted (hides on the shelves, meat in the barrels,
berries inside, wood, straw and stone under the coverings, ladders against the wall); water from the pond
to the barrels; everything where it may be; saved and loaded to the same bytes; with the three switches
off nobody is either and nothing is made, sorted or fetched. The eight reference logs line for line.

## Gate

From a clean copy of b767ff5 (gate 46): both builds with the six known warnings only; the nine checks
(water_sim 77, edit 41, ui 112, dynamics 18, serf 19, path 70, colony 678, deer 14, pick 59); the eight
reference logs line for line (none recorded again); the stress runner "nothing died, nothing dropped",
every pair of runs in one state (six_4_years 3c952853735ed2b6, six_41_days f2b64a313b5fa25d, housing
3204caff97d0b09f, crowd_as_it_is a41ce72b57d39bac, the crowd at work 3d49c4487f5e6120): each the
storehouse's size and 102 bytes more for 48 places (a fitting and a flag a place, six bytes more), the
band the same by the eight logs. The flora's hash as it was (5676219328934879273).

## His calls

**Still open from the storehouse, as he asked** (`Handoff_2026_11_17_storehouse.md`, "His calls"): the
gate as a gateway with no leaf, the yard beaten where it lies, two coverings and their sizes, the 4.5 m
of staging, only a stockpile square to the grid taking a storehouse, the note said again on a load. The
first of them, the one gateway, he set aside for now.

**New, first values of mine:**

1. **The stockman a porter, the carpenter its builder** (above).
2. **Packing meat into a barrel takes no salt**: the meat is salted when it is butchered, as before, and
   the stockman only moves it. Salt for the barrels would be a number of his.
3. **Water has no use yet**: two barrels, twelve pails each. Its first use (the pot, drinking, a trade)
   is his.
4. **The sizes**: six hides to a shelf's place, 60 lb of meat to a barrel, three times a place's own
   under a covering, a ladder to a place on the wall; eighteen places of floor, the row by the door clear.
5. **"Extend across blocks so he can stack them higher"** is read as places under a covering that hold
   three times as much, side by side along it, each stacked up to 1.5 m; one long pile drawn across them
   was not built.
6. **Anyone takes from inside**: the cook from the barrels, the hungry from the baskets. Only the stockman
   puts things in.
7. **The carpenter, with all made, fells as a forester and builds no house**; it stays the carpenter for
   whatever it is given to make next.

## Known limits

- Shelves, barrels and leaning ladders are drawn, not blocks: the walking map goes through them, as it
  goes through a stockpile's baskets.
- What lay in a yard's place before it was fitted out (a hide where a ladder now leans) is moved by the
  stockman; with `--no-stockman` it stays.
- The code is one commit for the four systems (b767ff5), each with its switch: they share the places'
  tests and could not be told apart in it.
- A save from the storehouse's build is refused (colony blob 28; 18 to 27 refused).
- A water carrier was not filmed.

## Test windows and input

All input was scripted: the runner for every figure; the game with `--load` of a runner's save of day 30,
`--frames`, `--shot`, `--hud none`, `--timescale 0`, `--all-roofs` for the inside. Every window was mine,
under `timeout`, opened after checking his game was not running. Nothing of the pointer's real input
path was touched.

Stills: `~/CASTLE_GAME/releases/storehouse_used.png`: inside (the barrels at the back, two open with
water; the shelves along the wall; baskets of berries and apples and sacks of salt on the floor); from
above with the roofs open; the coverings with logs, straw and stone stacked under them and the ladders
against the long wall; from the path, the cart beside the door and the salt and baskets inside it.

## Next

His: the stockpile's layout ("I have to think about the stockpile layout some more"), then the open
calls. Nothing further of the design is unbuilt but what he named for later (two carts and the inventory
system, tools and weapons in them; the player and the advisor).
