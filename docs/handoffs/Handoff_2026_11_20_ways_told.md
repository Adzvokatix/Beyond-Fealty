# Castle Game handoff (2026-11-20: gatherers and porters told of ways that are not there)

The round before it is `Handoff_2026_11_20_far_view_and_answers.md`, of the same word of his ("Ok lets
continue"). Everything is on branch `stockpile`, not merged; `main` is 537176c. No merge word was given.

## What this is

The rest of his "Let workers go 250m for resources, wood is a vital resource" (2026-11-19), owed since
the gatherers and the porters were given their reach: "a gatherer's or a porter's way asked first, so
that one whose nearest is across water looks past it". The stockyard at 45 degrees waits for his
word, so this was gone on with.

## Reproduced first

`colony_run --work-stats` (new, kept) says what the gatherers, the porters and the hunters were
doing, a colony second at a time, by their status. The band of thirteen at the open site by a river
(seed 1, stake 1000 900), twenty days:

- **The four gatherers said "can't get there" for 722 serf-hours** (more than half their waking time),
  with bushes they could get to further off. 41,538 ways were asked and refused.
- Why: a gatherer went for the bush nearest it; across the river there is no way; it remembered that
  for a minute, in a list of eight, and tried three in a thought. With a dozen such bushes nearer
  than the first it could reach it went round them for ever, and since what it said was "can't get
  there" and not "nothing in reach", it never looked further either.

## Built (commit 87e75af; colony blob 38)

- **What one finds there is no way to, the others are told** (`Set_Ways_Told`, `--no-ways-told`; only
  while the band looks further, `Set_Wood_Reach`). The way to a bush, an apple tree or a place to fetch
  from is asked of the walking map's pieces of ground first (no search where they show it out of
  reach). One with no way to it, found by somebody who has a way home, is nobody's to try for a day
  (ten where a whole search ran out). So the next thought is of the next nearest, sixteen at a time
  (`Ask_Tries`), and when none in reach is left untried the band looks a ring further, as it does when
  there are none.
- A forester's short search (300 floors a metre) was tried for these ways and dropped: ways through
  the camp and the housing to vegetables 86 m off ran out of it, 672 times in the reference band's 41
  days, and were told as no way. The search is a plan's whole one.

### The same run after

| open site by a river, 20 days | as it was (`--no-ways-told`) | now |
|---|---|---|
| gatherers' serf-hours "can't get there" (hungry or not) | 722 | 18 |
| going out for berries or vegetables | 132 | 440 |
| carrying home | 97 | 344 |
| hungry, whatever at | 52 | 194 |
| starving | 0 | 9.6 |
| days of food held at the end | 8.3 | 11.7 |
| vegetables pulled | 615 | 890 |
| how far the gatherers look | 60 m | 250 m |
| the colony's steps, seconds of computing | 27.9 | 13.3 |
| living | 13 | 13 |

One run each. **The gatherers are hungry nearly four times as long now, and one was "starving" for
9.6 serf-hours, on its way home with a basket from far off**: they look 250 m out where they stood by
the stake before. Nobody died, and the band holds more food.

**Played on for 120 days at the open site** (two winters; one run each): with the ways told all
thirteen are living at the end; **without, all thirteen died of hunger in the second winter**. Told,
the gatherers were hungry at their work for some 620 serf-hours of the 120 days and starving for 53.5.

At the reference site, where every place can be got to, the band's 41 days are line for line the run
with `--no-ways-told` (the gatherers look 92 m in both). A run at the open site saved on its tenth day
and loaded for ten more ends in the state of the twenty days straight (d2ed29d7c80d6ddc).

## The hunters: not built, and why

At the open site the three hunters said "the deer near are left to breed: no herd has more than 3" for
621 serf-hours of the twenty days. **It is not a reach of theirs**: the deer live within 70 m of the
stake by the herds' own rule (`Castle.Herds.Range_M`), and a herd down to three is left alone by his
rule. More deer further off is a change to the herds, his to say.

## Saves

Colony blob **38**: whether the band is told, and what it has been told (a number and a time each).
**Blobs of 30 to 37 are still read.**

## Checks

`colony_check` 817 (it was 813): a blob of 37 loaded; a gatherer whose nearest sixty-six bushes are
walled in picks nothing in fifteen minutes and says "can't get there" as it was, and told of the ways
picks from the one it can get to, with the walled ones nobody's to try; saved and loaded to the same
bytes with what was told.

## Gate

Gate 64, from a clean copy of 87e75af: both builds from nothing with the six known warnings and no
error; the nine checks in debug (water_sim 77, edit 41, ui 112, dynamics 18, serf 19, path 70, **colony
817**, deer 14, pick 69), none failing; the eight reference logs line for line; the three stockyard
sites; the three turned streets in release and in debug; the stress runner, nothing died and nothing
dropped; the flora hash unchanged.

The stress states moved with the blob (three bytes): six_4_years a37cc62b04c20d53, six_41_days
808fb6ef829adb95, housing aed9a22c3b3ba498, crowd_as_it_is c3ec5348cedc2104, crowd at work
bdc6357a138f5d78; each case agrees with its own variants. The eight logs are what says the behaviour
did not move where the reach is held off.

`bin/` in the working copy was built from this commit, his game not running; `colony_check` (817),
`pick_check` (69) and `tools/turned_streets.sh` were run from it.

## His calls (first values of mine)

1. **A day before a place with no way is tried again** (`Tree_No_Way_S`, the foresters' number).
2. **Sixteen places asked in one thought.**
3. **The gatherers' reach ran out to 250 m at the open site in twenty days**, and one starved for a
   while on the way home. A gatherer that eats from its basket when it is starving, or a reach that
   comes back in when bushes near are ripe again, would each be a rule of his.
4. **The hunters** (above): more deer further from the stake, or herds that range further.

## Known limits

- A place told as no way stays so for a day though a path or a bridge is laid to it meanwhile.
- The table of what is told holds one place to a number (4,096 of them): two places that fall on the
  same number put each other out, and are asked again.
- Not looked at: the porters at a site where stone or straw lies across water (the rule is theirs
  too; no such site was run).
- A bush's number never changes while a colony lives (bushes are only added), so what is told of one
  is never another's.

## Test windows and input

No window was opened for this piece: runs of `colony_run` only. Nothing pushed.
