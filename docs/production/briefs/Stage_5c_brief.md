# Stage 5c brief: the demand chain (phase B)

2026-11-10. **Accepted as built, 2026-11-10** (John, after trying it: "those mechanics work well and we will polish them up later"; first values, his to tune). As first written: proposed, not agreed. John said "5c it is"; the rules below are drawn from the framework's
"Demand drives demand" and "Needs, then demand" (agreed 2026-11-09) and the plan's line for this stage,
with first values of mine. The stage is built on them on branch `stage-5c`. Nothing is merged, zipped or
written into CLAUDE.md as a designer's rule until John agrees or changes them.

- **Goal:** people work because something is asked for, and stop when it is in store; the player sees
  what is asked, by whom, and who answers, and the only thing he sets is the surplus.

## Pillars touched

| Pillar | How it is met |
|---|---|
| 1 The player says where; demand says what and when | Nothing sets a producer to work but a row of the table; the player's rows are surpluses only |
| 3 Serfs are self-reliant | Eating, sleeping, fending and the cook's gathering ask nobody's leave |
| 4 Failure is visible | A resting producer says "enough food in store"; a good nobody brings in reads "asked of nobody" |
| 7 Emergence over scripting | A large winter store keeps the hunters out until the herds are down to three |
| 8 Evidence, not explanations | The table states what the stores have of what is asked, and who asks; it does not say what to do |
| 9 Few natural parameters | Two numbers (a day, two days) and the surpluses there already were |

## Rules proposed to John

1. **Who asks.** The band asks for its day's food (any food, counted as the pot would make it). The camp
   asks for its fire's logs by the day (4; 6 in winter) and once for its seats' (4). The paths ask for
   stone (the old quota of 20). None of it is set by hand.
2. **The player asks only for surpluses**, kept on top of what is used: wood 20 (it was "no limit"),
   straw 20, meat 20, vegetables 40, and the winter store in days of food (none by default).
3. **Two levels.** A good with users is asked for once the stores are down to its surplus and one day
   of its use, and until they hold the surplus and two days. A good nobody uses by the day (straw,
   stone, meat as meat) is asked for while it is short of what is wanted.
4. **Producers answer what is asked, and nothing else.** A forester fells while wood is asked for; a
   porter fetches straw and stone while they are; a hunter hunts while meat is, or food; a gatherer
   gathers while food is asked for, or else only the kind of its own that is short (vegetables). With
   nothing asked they finish what is in hand, take it home, say so, and stroll about the camp.
5. **Hunters answer the band's food**, not only the meat reserve. This changes the decision of
   2026-11-08 ("only while meat is short of its reserve") by the later one ("a hunter delegated by the
   player has the capacity, so he has the need to hunt"). Meat is food only with a camp and a cook.
6. **The winter store is asked for all year.** In winter the hold on it lifts (it is eaten) and whoever
   can still bring food in, the hunters, goes on.
7. **Needs first, as ever:** eating, sleeping, fending for oneself, and a cook gathering because it has
   nothing to cook, are not gated.
8. **One demand for the whole colony:** the stockpiles together are "the stores".
9. **Seen:** the Stores tab is the table; a stockpile's sheet says what the stores ask for, the camp's
   what it asks; a resting producer's status says why.

## What this changes on first launch (measured, seed 1, the reference setup)

| | Before (5b) | With the chain |
|---|---|---|
| No winter store ordered | Gatherers never stopped; about 5 days of food by winter | Food kept between 1 and 2 days; all six dead by day 52 |
| Winter store 10, meat 60 (the reference run) | 63 meat and 5.2 days of food into winter; all six dead by day 58 | 141 meat and 6.6 days; food lasts to day 57; two of six alive at spring |
| Wood | 167 logs by day 44 | 24 to 31, the forester resting between |

Winter is still not survived and is not tuned (the designer's call).

## Out of scope

| | Where it goes |
|---|---|
| A stockpile with kinds and demand of its own | When there is a second kind of store |
| The pot as a store in the table (it already works at two levels: cooks at 450, fills to 900) | Shown on the camp's sheet only |
| Demand per homeless serf, blueprints asking for wood and straw | Stage 6: rows with a zone as the asker |
| A farmer passing demand to farmhands; reversion | Stages 8 and 10 |
| The supply and demand window as the player's interface | Phase D; the Stores tab is the development view |

## State and saves

- Colony blob 13: the switch, whether food is being asked for, how many kinds, whether each is.
- Before 13: the chain on; a wood reserve of none (no limit) becomes 20; stock taken at the first step.
- `tools/colony_v12.bin` was cut with the version 12 code (ac56903).

## Packages

Touched: Castle.Colony (the table, the levels, `Asked_For`, `Take_Stock`), Castle.Views (`Demand`),
Castle.HUD (the Stores tab), Castle.Actions (a label), Castle.Scenario (`--no-demand`, the demand line).

## Leaves room for

| Later system | The hook |
|---|---|
| Habitation (6) | A row: `Who => A_Zone`, the zone, what, how much, once |
| Trades and farms | `Brings (job, kind)`; `By` on an order's row is an Actor, so a farmer can be the one who asks |
| Reversion | The two-level latch is the pattern |
| Balance (G) | `Ask_Below_Days`, `Ask_Until_Days`, `Default_Reserve`; `--no-demand` is the baseline |

## Tunables

`Ask_Below_Days` 1, `Ask_Until_Days` 2; `Default_Reserve` wood 20, straw 20, meat 20, vegetables 40;
the fire's day: the night's logs and one for cooking (4), 6 in winter.

## Check

colony_check, 39 new: rows by asker; levels as sums of rows; the latch both ways at one stock; a save
between the levels, byte for byte and 400 s on; a forester stopping at the high level; gatherers
stopping, resting a day and going out again; one kind short alone; hunters answering food (and not
without a cook); a porter; the version 12 blob; the switch saved. The older sections run with the chain
off. `tools/reference_check.sh`: chain off is stage 5b's log, chain and skills off is stage 5a's.

## Not done yet

A demo video; the zip; the close.
