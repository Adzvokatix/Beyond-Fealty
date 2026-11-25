# Castle Game handoff (2026-11-19: his answers to two rounds: stockpiles of any size again, wood from 250 m, the carpenter by skill, the trim inside; buildings at 45 degrees asked)

The round before it is `Handoff_2026_11_19_foresters_and_paths.md`; before that,
`Handoff_2026_11_19_answers_round.md`. This is his answer to both. Everything is on branch `stockpile`,
not merged; `main` is 537176c. No merge word was given.

## John's words, whole

> for razing that works well, yes the one time placement has be supersceeded, we go back to variable
> size stockpile, placed along the path, the new design document I added is to be integrated,
> Carpenter comes by skill like the others, Trim width yes inside the house too, the roofs top is
> perfect, great job, for 6 in the previous message that sounds great. For this message, is there a way
> we can just turn the buildings and build them at a 45 degree angle without stepping? Let workers go
> 250m for resources, wood is a vital resource. Trees do not grow back yet, but they will, we can do
> that later. When that is done we have a lot of polishing to do but you have done a very good job on
> what we need so far

Mapped to the calls of the two rounds:

| His words | The call | What was done |
|---|---|---|
| "for razing that works well" | answers round, 1: the two readings | nothing: they stand |
| "the one time placement has be supersceeded, we go back to variable size stockpile, placed along the path" | answers round, 2: his note against his document | built |
| "the new design document I added is to be integrated" | the same | read as `docs/design/detailed_mechanics.json` (the only document added since the ninth); the network's first pass built, the rest ordered in the brief: "His calls", 1 |
| "Carpenter comes by skill like the others" | answers round, 3 | built |
| "Trim width yes inside the house too" | answers round, 4 | built; the width stays 8 cm |
| "the roofs top is perfect" | answers round, 5 | nothing: **the roof's top is now a measure too** |
| "for 6 in the previous message that sounds great" | answers round, 6: a gateway under two metres | nothing: one leaf and a gap stands |
| "is there a way we can just turn the buildings and build them at a 45 degree angle without stepping?" | this round, 1 | **not built; one wall shown that way in a scratch build**: below |
| "Let workers go 250m for resources, wood is a vital resource" | this round, 3 and 5 | **foresters only**: below |
| "Trees do not grow back yet, but they will, we can do that later" | this round, 4 | written into the plan, unbuilt |

## Owed, said first

- **"Workers" and "resources" are more than foresters and wood.** Built: a forester goes 250 m. Not
  built: porters going further for straw and stone, gatherers for berries, apples and vegetables,
  hunters. Each is its own finder: the porters' has to ask its way as the foresters' now does (a
  search a place is what made the first try of this slow); bushes are only looked for within 88 m of
  the stake; the herds live within their range of the stake until they come apart from it (his word
  of 14 November). Next, in that order.
- **Buildings at 45 degrees without stepping**: one wall drawn so in a scratch build (not in the
  branch); the roof not tried; no building. Next.

## Stockpiles: any size, along the path, as many as wanted

- The player's stockpile is zoned corner to corner again ("Stockpile from here" on the ground's menu,
  or the Stockpile tool: two clicks), as often as wanted. The 10 m square placed once is behind
  `--one-stockpile` (`Set_One_Stockpile`).
- **A stockpile stays open when the storehouse stands** (`Set_Stores_Move (False)` is the default;
  `--stores-move` closes them and has them carried over, as before). **This reverses his note of 17
  November** ("change all deliveries and pickups to the stokyard from the stockpile") on the ground
  that the document's stockpiles are intermediate stores; and **until there are stock hands nothing
  carries goods on from a stockpile to the yard**: first among his calls.
- A stockpile's lot is turned to its path, at 45 degrees as well: the two corners are opposite corners
  along and across the path. Seen: one of 115 places beside a path at 45 degrees, used for five days,
  and a second zoned there with a scripted pointer through the ground's menu ("stockpile zoned: 52
  cells").
- **A save from an earlier build loads with these rules** (blobs of 30 to 33: the placed-once rule and
  the move are let go on load).
- `colony_run --haul-stats` (new): the metres walked with something in the arms. 41 days, the band of
  thirteen, the reference site, one stockpile, one run each: 66.3 km carried in all with the stockpile
  open beside the yard, 72.5 km with it closed and carried over. The count of loads it prints counts
  every time arms are emptied, so "metres a load" is not a measure of anything yet.

## The carpenter, by skill

The forester free for it that is best at carpentry (`Skill (Carpentry)`: each of the band arrives with a
level of its own, and fitting out a shelf or a barrel practises it). Until now it was whoever had raised
the storehouse. No switch: it is who is chosen, once.

## The trim, inside too

The same strips on the wall's inner face. Seen on a far wall through a cleared roof.

## Foresters, to 250 m

- `Fell_Reach_Max_M` is 250 m (it was 124, a first value of mine).
- **The reach grows only when every tree in reach has been tried.** As first built (yesterday's
  round) it grew whenever one thought found no tree, so at the open-land site, where the nearest
  thirty-two trees are across the river, it ran straight out to 250 m: the colony's steps took 60 s of
  computing for twenty days where they had taken 27. Now 26 s, the reach 108 m, the same wood in.
- **The search for a way to a tree is given floors by how far off the tree is** (4,000 and 300 a
  metre; measured: a straight way of 125 to 145 m took 100 to 205 a metre, one round by a ford 570 and
  more). A tree with no way is left a day, one with only a long way round ten days.
- `Max_Trees` is 8,000 (it was 4,096: 4,328 trees to fell stand within 220 m of the reference stake).
- `--wood-from M` (`Set_Wood_From`, for measuring, as `--stone-from` is): no tree felled nearer the
  stake. **With every log brought from 150 m or more** the band of thirteen at the reference site had
  its six hovels and its storehouse standing in 41 days, thirteen living and none hungry at the end, 23
  logs in store; the colony's steps 16.7 s of computing against 11.1 s.

## Buildings at 45 degrees without stepping: what can be said now

**For a wall, yes: one has been drawn.** In a scratch build (not in the branch; the changes are kept
as `~/CASTLE_GAME/releases/diag_wall_proof.patch`, fifty lines) a band of blocks laid along a diagonal of
the block grid, ten metres long and two high, is drawn with a flat face and a flat top: each block's
corner that sticks out is drawn in to the block's middle, by the same per-corner codes the trimmed
roofs use (`Emit_Soft` with `Slope`; a third value of a corner's sideways code, half a block toward the
block's middle). The still is on the sheet. Under the drawing the blocks are still whole blocks.

Seen wrong in that still, both mendable: **its shadow is still stepped** (the pass that casts was not
changed), and **there is a crack every eight metres** (at a stack's edge the block beside is not read).

Not tried, and the part most likely to say no: **the roof**. A dressed block of thatch says how it lies
in its state, and that state has no bit left for a slope falling along a diagonal.

Not begun: the building. A house's frame is two whole-block steps (east and north, or turned by
quarter turns), used in 152 places of seven files; turned 45 degrees those steps land on every other
block, so the house has to be laid out on the diagonals: whole blocks along each wall and the cut ones
in the notches. Doors, windows, the site's levelling and its walls of stone all go by that frame.

The order from here: the roof drawn so in a still; then the blueprint and the frame.

## Saves

Colony blob **34** (the measuring start for wood). **Blobs of 30 to 33 are still read**, and go on by
today's rules for stockpiles.

## Gate

Gate 55, from a clean copy of efabe84 (the last commit that changes code): both builds from nothing
with the six known warnings and no error; the nine checks in debug (water_sim 77, edit 41, ui 112,
dynamics 18, serf 19, path 70, **colony 793**, deer 14, pick 59), none failing; the eight reference
logs line for line; the three stockyard sites; the stress runner, nothing died and nothing dropped; the
flora hash unchanged (5676219328934879273 in both builds).

The stress states moved again with the blob: six_4_years d026182e96d071aa, six_41_days
072147a0d1304b8c, housing 568557b5bd314f3f, crowd_as_it_is cb79848b7b0cfdad, crowd at work
940bc7eb64a35b81; each case agrees with its own variants. The eight logs are what says the behaviour
did not move.

## His calls (first values of mine)

1. **How "the document is to be integrated" was read**: as the order to build the logistics network
   in the brief's passes, the first now (stockpiles of any size, any number, open beside the yard).
   Next would be the stock hands (porters who, once the storehouse stands, carry from each stockpile
   to the yard). Until then nothing moves goods on to the yard; `--stores-move` is the rule of your
   17 November note.
2. **How far a stockpile may be from the stake**: 256 m (the engine's reach). None was set.
3. A forester's search for a way: 4,000 floors and 300 a metre. A tree with only a long way round is
   left ten days.
4. The calls of the rounds before stand open as they were.

## Known limits

- The two-corner stockpile tool was driven by a scripted pointer through the ground's menu, not by
  the Stockpile button and not by a real pointer.
- A stockyard's lot is still square to the blocks: beside a path at 45 degrees it is taken only where
  a corner of it comes to the path (the round before).
- The trim inside was looked at on one window.
- Nobody was watched walking 250 m: the runs with wood from 150 m are the measure.

## Test windows and input

Stills in short windows of mine, each only when `pgrep` found his game not running. All input
scripted. Nothing pushed.
