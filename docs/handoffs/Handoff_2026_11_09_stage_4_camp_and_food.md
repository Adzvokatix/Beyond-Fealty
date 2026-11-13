# Castle Game handoff (2026-11-09: stage 4, the camp, the cook and food; Claude Code)

- Code: GAME_alpha_1_3/compiled, branch main. Commits 18fc3ff (eating and sleeping), 3aab793 (camp and
  cook) and the one after it (vegetables, apples, fending, confidence, death, firelight).
- All eight checks pass in debug. Still only the 6 known warnings.
- **Generator_Version is 11** (wild vegetables). Saves from before are refused. Colony blob version 8;
  version 7 and older still load.

## John's rules (2026-11-08), the theme of the game
- Serfs are self-reliant: hunger ticks down and a serf won't let itself starve.
- The campfire is a zone, 7 x 7 m, fire in the middle, logs round it for seats, the band sleeps round it.
  The iron pot over the fire they brought with them.
- Anyone can eat raw food (fruit, berries, vegetables) but it fills poorly. The cook makes stew from meat
  and vegetables, berries when the vegetables are gone, then fruit. Stew is taken before raw food.
- Gatherers go for wild vegetables first: one score of distance, demand and stock.
- Starving with no food to be had, serfs leave their job to find food (production stalls) and confidence
  falls. In winter, with none at all, they die.
- Mood is per serf; the player sees only the band's average (confidence).
- A cook, a hunter or two and a gatherer or two should feed a starting band with a small surplus.
- Later: theft, spoilage, people leaving when confidence runs low.

## Built
- Camp: Campfire tool or `--camp X Y`. Fire in a stone ring, crossbar and pot, four seat logs, firewood
  stack, flames that flicker and light the ground at night.
- Cook (a job; the first one chooses itself): fire first (logs, or dead sticks when no logs are stored),
  then the pot, then seats. Gathers when there is nothing to cook.
- Food values (raw / in stew): meat never / 30, vegetable 3 / 8, apple 2 / 5, berries 1 / 3. A quarter
  more for meat and greens together. An adult eats 240 points a game day.
- Wild vegetables: a new plant block in patches about 20 m across; pulled one at a time, growing back in
  10 days, not in winter. Apples: summer's tenth day to the end of autumn, about 40 a tree a year.
- Fending for itself, confidence in the band panel, death by hunger in winter after two days empty.
- New poses: stirring the pot, eating seated on a log.
- Options: `--cooks N`, `--supply KIND N`, `--log-hours H`, `--speed` up to 60 for long runs.

## Measured (seed 1, stake 1178 1078, camp 1172 1082, nothing stored, 4.5 game days)
| Band at work | Result |
|---|---|
| cook, 2 hunters, 2 gatherers, forester | about 2 days of food in hand, lowest belly 28 %, confidence 78 % |
| cook, 1 hunter, 1 gatherer, forester | holds on, stock slips to a third of a day, lowest belly 30 % |
| 2 gatherers, no cook or camp | hungry from day 2, fending, confidence 14 % |

- Hunting stops after about 4 deer near home (herds are never hunted below three, no new herds arrive).
  After that the stew is vegetables and berries. This will matter for winter.

## Added 2026-11-09 (John)
- Vegetable leaves are a brighter green (Sprout_Green, derived). See wild_vegetables.png.
- Grain is a by-product of straw: a porter cutting wild grain gets a sheaf and two handfuls of grain.
  Not eaten raw; 4 points in stew; the cook uses it last. Colony blob version 9.

## Winter (added 2026-11-09, commit after 2c3663b)
- Nothing is gathered in winter; hunting goes on.
- Winter store order (band panel, `--winter-store N` days): held back outside winter, keeping kinds first
  (grain, apples, meat, vegetables, berries); built from surplus only (a day's food is never held); lifts
  in winter. Only the starving with nothing to gather break into it.
- The fire burns all day and night in winter (6 logs a day); the cook fills its stack first. Asleep away
  from a burning fire is cold: hungry at the waking rate, mood capped at 30 %.
- Every 3 days two deer join a herd that has fewer than five.
- Colony blob version 10. `--speed` goes to 240 for scripted runs.
- Demo: colony_stage4_camp.mp4 (58 s: dusk at the camp, supper at the fire, the band asleep round it).
- Zip: castle_game_stage4.zip.

## Winter balance: NOT survived yet (seed 1, from summer day 5, nothing stored, store order 10 days)
| Band | Food at winter's start | Outcome |
|---|---|---|
| cook, 2 hunters, 2 gatherers, forester | 5 days | 4 of 6 dead in the last days of winter |
| cook, 2 hunters, 3 gatherers, no forester | 12 days | cold all winter, all dead in the last 2 days |
- Winter hunting brings in under a fifth of what the band eats (about 0.8 deer a day).
- Levers for John: what an adult eats (240 a day), gatherer output, deer arriving in winter, winter length,
  gatherers hunting in winter.

- John's call (2026-11-09): leave it. Balancing comes later; the swings show the mechanics working in
  concert, and the second layer (village growth, taming, farms, herdsmen, more animals) will change the
  numbers.

## Not done in stage 4 yet
- The camp can't be moved or removed. Dead serfs stay where they fell (no burial).
- Cooking skill is a number from the serf's seed until stage 5 brings skills.
