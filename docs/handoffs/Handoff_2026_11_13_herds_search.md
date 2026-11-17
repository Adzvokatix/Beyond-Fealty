# Castle Game handoff (2026-11-13: "the stress test for the cart issues": why the stress runner's crowd took 22 s for 12 with the lord's cart pulled, found, and the work it cost kept; then, at his word, a herd's flight changed: a chain from the deer nearest the danger, the deer locked to the node; then his answer to the finding's calls, built: water blocks a herd and it knows, and one who stands still frightens none. Branch `herds-search` from `main`; Claude Code)

- **Accepted 2026-11-14, after he had tried it ("My testing otherwise shows acceptable results so I
  think we can merge clean-up and continue, if you concur"): on `main`.** His words whole, how they
  are read, and what he said of the deer and the ecosystem to come: "Accepted", below. It was branch
  `herds-search`, from `main` at c7300ee (the cart, the cloaks, the roofs and the water's mend: his
  words are in `Handoff_2026_11_13_cart_and_cloaks.md`); `git checkout herds-search && git branch -f
  main c7300ee` puts `main` back where it was. The last commit that changes code is b7bd3fa, gated
  from a clean copy; what follows it is documents.
- Three commits of work: 17bde03 (the finding; a plan that ran out of budget remembered: nothing
  anyone does is changed by it), 73a9b9d (the herds' flight in a chain: that changes what a herd
  does, at his word) and eb72190 (one kind of plan kept out of the memory, which was not exact for
  it; the documents brought to what the last build measures). **Then, on his answer to the calls
  (2026-11-13; built by 2026-11-14): 78d9f86 (a herd is told that water blocks it: pieces of ground
  for dry going) and 6fa8092 (one who stands still frightens no herd).** After them: be4af0a (the
  runner's `--who` says where each herd is and who is nearest it; a demo script; documents) and
  b7bd3fa (the cell cache cleared after a plan kept to a region; the stress runner proves the crowd's
  refusals; documents corrected).
- Checks, from a clean copy (`git archive`) built from nothing, on 17bde03, on 73a9b9d and on
  eb72190: both builds with the six known warnings only; all nine checks in debug
  (path_check 48 -> 54 with the memory; colony_check 621 -> 623 with the chain; the rest as they
  were; on 17bde03 itself path_check failed its six new checks when run whole, its made-up world not
  attached again after the real one: mended in the next commit); `tools/reference_check.sh` line for
  line: on 17bde03 with no log recorded again (the memory changes no run), and with the chain the two
  logs that have the herds fleeing together recorded again (the six with `--deer-scatter` are as they
  were); `tools/stress.sh runner` ("nothing died, nothing dropped", with a new line: the crowd's sixty
  days with nothing remembered end in the same state); the flora's hash the same in both builds.
- **The same from a clean copy on 78d9f86, on 6fa8092** (his answer's two rules) **and on b7bd3fa**
  (the runner's `--who`, a new line of the stress runner, the cell cache cleared after a plan kept to
  a region; what follows it is documents only): both builds with
  the six known warnings only; the nine checks (path_check 69, then colony_check 629 and 635);
  `tools/reference_check.sh` eight logs line for line, the two with the herds fleeing together
  recorded again in each commit and the six with `--deer-scatter` not moved by either;
  `tools/stress.sh runner` "nothing died, nothing dropped", the crowd's state the same with nothing
  remembered, 461 to 462 MB as before (and, on the last, the same with every refusal proved:
  `crowd_prove_dry`); the flora's hash the same in both builds.
- Versions: nothing moved. `Generator_Version` 13, save format 6, colony blob 25, the herds' own blob
  2 (a field of a deer is reused: what was the seconds left of its own start is the seconds until its
  turn in the chain). Nothing of the two rules of his answer is saved (the pieces of ground are worked
  out from the floors; who stands still is read each step).
- Driven only by script: nothing of the interface or the pointer is touched.
- **Test windows of mine on his desktop**: for the finding and the memory, none (all of it the
  runner's); for the chain, two recordings of a herd's ground (600 and 840 frames) and the demo twice;
  for the two rules of his answer, one still (150 frames), the new demo once (480 frames) and the
  chain's demo once more (800 frames), to see that it still shows what it says.
- Zip: CASTLE_GAME/releases/castle_game_herds_search.zip (a `git archive` of the branch). Demos:
  colony_herd_chain.mp4 (`tools/demo_herd_chain.sh`), ten seconds: a herd of four on the rock
  north-east of the stake, a hunter coming up; they turn and set off one after another and run with
  their node the same way (recorded again on the last build). colony_herds_still.mp4
  (`tools/demo_herds_still.sh`), fifteen seconds: one of the crowd left standing with its berries in
  the middle of a herd of five, which grazes on round it. **Not in a video: a herd turning from water
  (no moment of it was found to film; it is in the checks and the counts).**

## John's words

2026-11-13, of the list of open questions: "So that is it for this first pass, then we will track down
the cart issues, then the stockpile." And, asked whether he accepts that branch: "ok commit we are at
a good spot right now, then the stress test for the cart issues, and at last we can get to the
stockpile".

How it is read: "the cart issues" and "the stress test for the cart issues" are the one thing of the
cart left unexplained in the handoff before this: with the pull, `tools/stress.sh runner`'s crowd
(forty-eight, `--no-needs --no-demand`, sixty days) took 22 to 24 s where it took 12, the time in the
herds' plans. Find why; mend what can be mended without changing what anyone does; put the rest to
him. The stockpile is his to open after it.

## Found

With `colony_run --nav-log FILE` (new: a line for each plan that runs out of budget as it happens, and
who of the band stood nearest):

- **737 plans ran out of budget in the crowd's sixty days with the pull; none without.** 721 of them
  were one question: a herd's flight from (1200, 1030) to a place 30 m off toward (1174, 1016), asked
  every three seconds for some forty-two hours (from six in the morning of day 24 to the midnight
  after day 25), 40,000 floors each (14 to 16 ms): 10.7 s of the run's 23.
- **Of all 737 the pieces of ground had said the place could be got to** (`MET`): they are a serf's,
  who wades half a metre. The herd's search keeps out of water deeper than a quarter metre and finds
  no way within its budget: the known limit of `routes.md` ("a herd's dry way running out of its own
  budget"). A serf's way between the same two places is there, 60 m long (`--try-plan`, new).
- **It was asked every three seconds because a forester stood 8.8 m from the herd's node all that
  time**, a log in its arms and "nowhere to put wood". Whoever is within 15 m of a deer startles
  its herd again every three seconds (`Settle_S`); with no dry way out the herd stays where it is and
  each deer bolts a moment by itself.
- **Twenty of the forty-eight stand with nowhere to put their load from the second day on, with the
  pull or without** (at the fifth midnight, with the pull: eleven with berries, six with wood, three
  with vegetables; the stockpile is full). Where they are left standing differs.
- **The ground answers the same either way**: that way asked of the ground without the pull, with
  it, and with the reference band an hour old runs out of budget the same, to the same 23.6 m of a
  way. The pull changes no map; it changes who stands where.
- **Not found: why one of them stands by that herd in each of the eight starts tried with the pull
  (3 to 935 such plans) and in none without.** From half past six it is the same forester by the same
  herd, seven metres off (181 plans from one spot). What is known (`--deer-track`, both ways, from
  seven): the cart is lifted between half past seven and twenty to eight; a deer of the nearer herd
  first steps otherwise at ten past nine, and the runs are other runs from then on; the western
  herd's own way first differs at half past eleven that morning; by the fourth day it is 50 m south of the stake with the pull, by the wood and
  the water where it is cornered, and 60 m north of it without.

## Mended (work kept; nothing anyone does is changed)

`Castle.Nav.Plan` remembers a plan that ran out of budget: its route, by where it was from and to, its
budget, weight and wade, and by the version of every stack in a box round everything it read (the
cells it looked at and the pieces of ground it went by, a stack more each way; sixteen at most). Asked
the same again while none of that ground has moved, it answers from memory: the route a search would
give. `Castle.Nav.Set_Spent_Memos` (`colony_run --no-memos`) switches it off.

Measured on 17bde03, the herds as they then fled (seed 1, the stress runner's crowd):
- sixty days from seven: **13.3 s for 23.6**; 706 of the 737 answered from memory; the state the same
  (1f768b5277de9411) with it on and off;
- twenty days from half past six: 9.9 s for 19.1; 659 of 935 from memory (the rest are asked of
  ground that had moved in between, or are other questions: 84 different ones); the same state;
- twenty days from eight: 34 such plans, none asked twice: no change, the same state.

**Measured on the branch's last build, the herds fleeing in a chain: the memory answers nothing.**
Twenty days from half past six, a quarter past seven, eight, half past eight and nine: 5, 0, 25, 502
and 7 plans out of budget, none asked twice to the decimetre, the times the same with the memory and
without (6.3, 5.9, 7.1, 13.1 and 5.9 s), the states the same. From half past eight a forester stands 9
to 14 m from a herd through days 28 to 30 with nowhere to put its wood; the herd flees a short way
and is back every four or five game minutes, and each flight's first way is a search to its budget
from a place a hand's breadth from the last: 7 s of that run's 13. The stress runner's own crowd
(from seven) takes 13.7 s on this build because its history has no herd so placed, not because
anything was remembered. **(As it stood before his answer to the calls, which ended it: "His answer to
the finding's calls, built", below.)** **So: the cause is found; what was built for it mends a herd that cannot
move at all, as the herds were, and is no more than insurance now; the cost itself was still there
when a serf is left standing by a herd that water hems in (one start in five), and what would end it
is his to say (his calls, below).**

Checked: `path_check` on a made-up river with a ford (a serf's way is there; kept dry it is searched to
its budget; asked again it is answered from memory, the same way point for point; asked with another
wade, or with a post put up near its start, it is searched again; switched off, searched each time):
six checks, and with the ground's test or the wade taken out of the memo's key two of them fail.
`tools/stress.sh runner` has `crowd_no_memos`.

New for measuring (`docs/systems/colony.md`, "colony_run"): `--nav-log FILE`, `--try-plan X0 Y0 Z0 X1
Y1 Z1 WADE`; `--nav-stats` says how many plans were answered from memory and, of those that ran out
of budget, what the pieces of ground had said.

## A herd's flight changed, at his word (while the above was being closed)

His words, whole: "Let's change direction for the deer herd, instead of panic running them in different
directions, lock them to the node and they run with the node, from the closest to the hunter in a chain
reaction"

How it is read: a deer no longer starts on a heading of its own, and none bolts by itself. In a
flight every deer is locked to the node (it runs for its own place round it, as the second half of a
flight already went); the flight begins with the deer nearest the danger and goes down the herd, each
next nearest a moment after the one before. The number (a quarter of a second a link) is mine.

As built (`docs/systems/deer.md`, rules 1 and 4):
- `Castle.Herds.Flee` gives each deer its turn: how many of the herd are nearer the danger, times
  `Chain_S` (0.25 s). The nearest turns the way the node goes and sets off with it at once; each next
  stands, head up, then turns and sets off. Nothing else of the flight is changed (the node's ways,
  the pace, keeping out of water, the trail of one left behind, a herd in flight only turned).
- With nowhere for the node to go the herd stays with it, heads up; none bolts (each did, a second
  or two on a heading of its own).
- A fault of mine on the way: left facing as it stood, a deer set off at the danger for a step or
  two before it had turned (`colony_check` counts steps toward the danger: 3); each is turned the way
  the node goes as its turn comes.
- A save from before the herds fled together loads with no deer waiting a turn.

Seen in the game (the demo, every third frame across the second they set off): the doe and the fawn
on the hunter's side turn and go first, the stag stands a few tenths of a second more, head up and
as it stood, then turns; from then on all four run the same way.

Checked: `colony_check` 621 -> 623: the five of a herd set off in steps 1, 6, 11, 16 and 21 of a
flight (twentieths of a second), the nearest to the danger first, none toward it; penned in with the
danger a metre from the node, none of those inside moves. With the links at nothing, or the bolting
put back, each fails.

Measured (seed 1): four days of tracks of the reference band (`--deer-track`): 90 deer set off where
120 did; 5 deer-seconds on a wet floor where there were 106; further than 15 m from its node 2 s (4);
a heading turned over 120 degrees in a second, on the move, 107 times (135). The band's 41 days: 16
deer with 37 arrows where it was 14 with 45; all six live either way. The two reference logs with the
herds fleeing together were recorded again: the eighth (today's band, housing) ends as it did by its
counts (all six live, 14 deer with 30 arrows, 14 salted); the first (the band of before the pass: no
beds, pace 1, no cook's hold, no curing) has three living where it had four, 31 deer with 83 arrows
where it had 33 with 89 (whose winter it is in that run has gone both ways with every change to it).
The stress runner's crowd: 13.8 s, 40 plans out of budget and none asked twice: on that history no
herd is cornered by one who stands by it, so the memory has nothing to do there (its effect is
measured on 17bde03, above).

His calls, for the chain (first, what it moved: today's reference band takes 16 deer with 37 arrows in
its 41 days where it took 14 with 45, all six living either way; the older-configured log has three
living where it had four):

4. **A quarter of a second a link** (`Chain_S`): a herd of five is all off in a second.
5. **The order is by how near the danger each deer is**, not from neighbour to neighbour.
6. **Each waits standing, head up, and turns as it sets off**; none turns before its turn.
7. **A herd with nowhere to go does not move at all** now, for as long as the danger stands there.

## His answer to the finding's calls, built (2026-11-13 and 14)

His words, whole: "Ok, lets do a mix, a person standing still doesn't frighten a herd, and let them know
that water blocks them, when we get to the stockpile mechanics we will reserve a portion of the
stockpile for overflow"

How it is read, by the numbers of the calls below ("His calls, for the finding"):
- "a person standing still doesn't frighten a herd": call 1. Built.
- "let them know that water blocks them": call 0. Built.
- "when we get to the stockpile mechanics we will reserve a portion of the stockpile for overflow":
  call 3, and it is the stockpile's: a thing he has said of it, written down for it (the plan, the
  brief), **not built**. How much is reserved, for what, and what a serf does when that too is full
  are his to say when he opens it.
- Call 2 (a herd that found no way let be for a while) he did not take up: not built.
- Calls 4 to 7 (the chain's) he did not speak of: they stand as built, unanswered.
- He did not say he accepts the branch: not merged when this was written. (He accepted it in his
  next message: "Accepted", below.)

### Water blocks a herd, and it knows (78d9f86)

- **The walking map keeps pieces of ground for dry going** (`Castle.Nav`): beside a serf's, for each
  stack a plan asks about, the pieces that can be gone over no deeper than no water at all (a herd
  grazing) and no deeper than a quarter metre (a herd in flight), worked out when first asked and again
  when the stack's floors have changed. A plan asks the pieces of its own going. A serf's plans read
  what they read before (the six reference logs with the herds as they were: line for line).
- **A herd's ways are refused where they cannot be gone** (`Castle.Herds.Go`: `Plan (..., Within,
  Refuse)`): a place its pieces do not join, on the ground within 76 m of the stake
  (`Dry_Reach_M`), is not fled to or grazed to: no search, no route, and the next direction is tried.
  Before, each such way was searched for over 40,000 floors and then made for as far as the bank.
- **76 m, because every stack that near the stake is ground the game keeps loaded** wherever the
  camera is (`colony_check` has the sum: the furthest such stack is 117 by the squares of its steps
  from the stake's, of 121 kept). So a herd is answered the same looked at or not, and the looking
  over is of some three hundred stacks however much is in view.
- **The first thing done was to ask what the true answer is** (`colony_run --try-plan` with
  `--try-budget`): the cornered herd's logged way, searched for with no budget, runs out of ground at
  114,643 floors and ends at the bank. It is out of reach; it was never a long way round.
- Measured against the commit before (seed 1): plans out of budget in the crowd's twenty days from
  five starts 5, 0, 25, 502 and 7; **none now**. Ways refused 7, 8, 9, 546 and 240, at 0.08 ms each.
  The run from half past eight 6.4 s for 13.1. The stress runner's sixty days: none out of budget for
  40. The reference band's 41 days: none for 16; 15 deer with 45 arrows where it was 16 with 37.
- **Proved on the real world**: `colony_run --prove-dry` searches for every way the pieces call out
  of reach, with the pieces off and no budget, over all the ground the plan may go on, and stops the
  run if one is found; and works a stack's kept pieces out again each time they are used. Three runs
  with this rule alone (546, 240 and 50 answers) and three with both rules (54, 22 and 38): every one
  borne out, the states the same as without the proving.
- Checks: `path_check` 54 -> 69 (the made-up river: a serf's way by a ford; a hand of water: there
  too; dry: out of reach at once, 40 floors looked at; refused: none; with the pieces off, searched
  whole: not there; a causeway laid and taken away; a region with the ford in it and without; a
  nearer crossing outside the region not taken; the memory's checks re-seated on a ford further off
  than the budget, since a dry way over the river is no longer searched for at all). `colony_check`
  623 -> 629 (a herd on one bank of a river, someone walking up behind it: the ways over refused,
  each searched for whole and not there, 62 floors looked at in all, the herd off along its own bank,
  no deer over the river or in it; and the sum of the 76 m). Broken six ways in turn (the dry pieces
  made a serf's; never worked out again; the looking over let out of its region; the steps let out
  of it; nothing refused; the memory's key without the refusal), each fails its checks; a seventh
  (the border between stacks tested as a serf's) changes nothing, the pieces already leaving out
  what it would.
- The two reference logs with the herds fleeing together recorded again: the first ends with five
  living where it had three (32 deer with 78 arrows for 31 with 83), the eighth as it did by its
  counts (all six, 14 deer with 30 arrows, 14 salted).

### One who stands still frightens no herd (6fa8092)

- **Who stands still is the colony's to say**, each step (a twentieth of a second), of each of the
  band: one whose place on the ground has not moved in that step (`Castle.Colony.Advance`,
  `Castle.Herds.Person.Still`). The herds' new way skips them, for a startle and for the turning of a
  herd already in flight. The herds as they were (`--deer-scatter`) mind everyone, as they did.
- Measured against the commit before (seed 1): the crowd's herds were frightened 1,487, 612, 4,462,
  2,421 and 729 times in twenty days from the five starts; **14, 16, 13, 18 and 24 now**
  (`Castle.Herds.Frights`, in `--nav-stats`). Nearly all of it had been the twenty of the forty-eight
  left standing with a load. Those runs take 5.0 s each where they took 6.0 to 6.7; the stress
  runner's sixty days 9.1 s where they took 12.9 (and 13.7 before either rule). The reference band's
  41 days: 82 frights for 89; 15 deer with 36 arrows for 15 with 45; all six living.
- Checks: `colony_check` 629 -> 635: someone standing 9 m from a deer for half a minute (nothing),
  then walking (off at once); and **through the colony's own steps**, a gatherer of the band at a
  bush 9 m from a penned herd: within 15 m of a deer for 56 seconds, the herd frightened three times
  in the 11 it walks, never in the 44 it stands picking. With the rule taken out of the colony, or
  out of the herds, 14 frights in those 44 seconds and the checks fail.
- The two logs recorded again: the first five living, 33 deer with 72 arrows; the eighth all six, 15
  deer with 32 arrows, 15 salted.

### Found while measuring, and not looked into further

Sixteen days of tracks (`--deer-track`), the chain against both rules: 189 deer set off in a flight
where 210 did; no deer-second on a wet floor where there were 8; in flight a heading turned over 120
degrees in a second 23 times where it was 56. **Calm, it was 748 times where it was 373, and a deer
was further than 15 m from its node for 78 seconds where it was 21.** Partly by where the herds were:
with both rules they spent 70 % of their time north of the stake, on a hillside, where it was 26 %,
and on that ground a calm deer turned sharply more often in the run before too (0.27 times a hundred
seconds north of the stake against 0.16 south; on single squares of the hillside 0.4 to 1.1). That
accounts for some of it (at the old rates, about 460 of the 748). **The rest is not explained**: north
of the stake the rate itself is 0.49 a hundred seconds where it was 0.27 (south, 0.14 for 0.16).
Three times a deer stood pacing 15 to 20 m behind its node on that hillside for a quarter to half a
minute before it found its way down. Neither rule touches the calm deer's stepping, which is not the
same as showing they change nothing of it. Why the herds moved north is not found.

### His calls, for these two (first, what they moved)

8. **A hunter drawing its bow, or waiting for the deer to settle, stands still: no herd sees it at
   any distance** (it was seen within 7 m). The band's 41 days: 15 deer with 36 arrows; with water
   alone 15 with 45; before either 16 with 37.
9. **Work on the spot is standing still**: a forester felling 5 m from a deer, a gatherer picking,
   frighten nobody. Noise is not a thing the herds know.
10. **Still is one step.** One who stops walking is no danger at once; one who shifts a step within
    15 m of a herd that has been calm three seconds frightens it.
11. **A deer comes as near as it likes to one who stands** (in the demo, two or three metres).
    Nothing keeps it off.
12. **A herd's ways are looked for only within 76 m of the stake**: a way round water that leaves
    that ground is refused with the rest.
13. **Refused, a herd does not run to the water's edge** as it did (deer stood in the shallows
    there): it takes another way, or with none stays, heads up (rule 4, as before).
14. **The memory of spent plans has had nothing to remember since** (none answered in any run
    measured). It is proved to change nothing and stays as insurance; it can as well come out.

## His calls, for the finding (none built: each changes what a herd or a serf does, and the reference logs with it)

0. (**Taken up and built: above.**) **Pieces of ground for dry going**, so that a herd's way across water is known out of reach
   without a search of 40,000 floors. It ends the cost whoever stands where; the way a herd then
   takes would end elsewhere than it does now, so every log with herds in flight would move.
1. (**Taken up and built: above.**) **One who stands still frightens a herd as one who walks does**, every three seconds for as long
   as it stands within 15 m. The herds' own rule reads "someone walking within Fear_M of a deer". A
   herd could take no fright of one who has stood still a while.
2. (Not taken up.) **A herd that cannot get away is frightened again every three seconds.** It could be let be for a
   time after a flight that found no way. (With the chain it no longer bolts about meanwhile.)
3. (**His answer: "when we get to the stockpile mechanics we will reserve a portion of the stockpile for overflow".**) **A serf with nowhere to put its load stands where it is, for days** (twenty of the crowd's
   forty-eight from the second day). What a full stockpile should mean is the stockpile's, and his to
   open: it was question 20 of the list.

## Accepted (2026-11-14)

His words, whole: "Well when we add the entire ecosystem we are going to have to seperate the deer from the stake and the entire map gets populated, keep that in mind. The rest of the conditons are acceptable keep them. When we do that we can solve the cornered herd problem by letting them travel farther, are we capable of realizing this? My testing otherwise shows acceptable results so I think we can merge clean-up and continue, if you concur."

How it is read, by the numbers of the calls above:
- **"I think we can merge clean-up and continue, if you concur"**: he accepts the branch if I see no
  reason against it. I see none: the last commit that changes code (b7bd3fa) is gated from a clean
  copy, every refusal of a herd's way is proved by a whole search in the stress runner, and the one
  figure not explained (calm deer turning sharply more often: "Found while measuring") is a known
  limit, written down. `main` is fast-forwarded to the branch. Clean-up: these documents; the working
  copy left on `main`; the branches kept, as every one before was. Continue: the stockpile, his to
  open ("Next").
- **"The rest of the conditons are acceptable keep them"**: the conditions put to him in the report
  (calls 8 to 13) stand as built, and the chain's (4 to 7) and the memory of spent plans (14) are
  accepted with the branch, as built. He did not rule on each: first values still, his to tune.
- **"when we add the entire ecosystem we are going to have to seperate the deer from the stake and
  the entire map gets populated, keep that in mind"**: a direction for a later stage, not a request.
  Nothing built. It is about the conditions that are the stake's: the 70 m a herd keeps within, the
  32 m it keeps off, and the 76 m its ways are looked for on (call 12, which this round added). They
  are kept for now and go when the ecosystem comes. Written down in `docs/systems/deer.md` ("To come:
  the herds apart from the stake"), with everything in the code that leans on the stake.
- **"When we do that we can solve the cornered herd problem by letting them travel farther"**: call 2
  (a herd that found no way let be for a while) is not built and is left to that stage, by his word.
- **"are we capable of realizing this?"**: answered yes, from the code and from a count made for the
  answer (below).

### What "letting them travel farther" would change, counted

A scratch build (counters in `Castle.Herds.Flee`, taken out again, nothing committed; the runs end in
the same states with them in). Seed 1, the branch as accepted:

| | the band, 41 days | the band, 240 days | the crowd, 60 days |
|---|---|---|---|
| herds startled | 80 | 455 | 30 |
| of them with no way at all | 0 | 0 | 0 |
| fled straight away from the danger, the full 30 m | 15 | 106 | 13 |
| directions turned down: past the 70 m | 272 | 1,535 | 59 |
| too near the stake | 0 | 8 | 6 |
| under water, or no floor there | 4 | 36 | 1 |
| out of reach dry (refused) | 12 | 54 | 1 |

(The first column lies inside the second: the band's 41 days are the first 41 of its 240. The sums
below are of the second and the third. As first written here, and in the message of commit 2e3f9f9,
they counted those 41 days twice: 565, 431 and 1,866 of 1,988.)

- **No herd was cornered in any of these runs**: every one of 485 startles found a way.
- **Three flights in four could not go straight away from the danger (366 of 485), and more than
  nine times in ten what turned a direction down was the 70 m from the stake (1,594 of 1,700)**, not
  water. So letting herds travel
  farther removes most of what turns a herd aside today. It does not remove ground truly ringed by
  water; none was met here.

What the code shows of whether it can be done:
- **The herds are the colony's today**: founded with the stake (`Castle.Herds.Found`), placed 30 to 55
  m from it, leashed to it (`In_Range`: every flight's and every grazing move's target, and every
  step of a deer), their ways looked for within 76 m of it, hunted only within 70 m of it
  (`Go_Hunt`), stepped by `Castle.Colony.Advance`, saved inside the colony's blob, eight herds and
  sixty-four deer at most.
- **A deer walks only the walking map, which has floors only where blocks are loaded**, and the
  colony must come out the same wherever the camera is. That is the one hard constraint: how fully
  a far herd is simulated must go by the colony's own ground, never by what happens to be loaded
  for the camera. (The 76 m exists for exactly that reason.)
- **The generated world can be asked about any metre of the map with nothing loaded**: its height
  and whether it is dry, shore, stream, river or lake (`Castle.Maps`, `Castle.Geology.Surface_B`).
  So a herd far from any colony can be a node on that map, and its deer made when it comes onto
  ground a colony keeps.
- Not designed, not costed, and every reference log with herds would move. His to open.

## Known limits

- The memory helps only when the same question is asked to the hair of ground that has not moved: a
  herd that shuffles a hand's breadth between flights (as it does with the chain), or one beside a
  band at work on the ground it reads, is searched for each time.
- `--nav-log` with the memory on leaves out the askings answered from memory: run it with
  `--no-memos` to see every one.
- A dry way that is there but longer than the herd's budget is still searched for to the budget (the
  pieces say it can be got to): none in any run measured since the pieces for dry going.
- A herd whose every way is refused is asked again each time it is frightened: 29 refusals at most,
  some 2 ms.
- Nothing of a herd turning from water is in a video.
- On steep ground a calm deer is held up by the ground, and calm deer turn sharply twice as often
  as before these two rules, only partly because of where the herds now are ("Found while
  measuring", above).
- Why the pull puts a forester by that herd every time is not found.

## Next

The stockpile, his to open ("and at last we can get to the stockpile"; and, accepting this branch,
"merge clean-up and continue"). He has said one thing of it since: "when we get to the stockpile
mechanics we will reserve a portion of the stockpile for overflow". Four things were asked of him
with the report of the merge, each with a default of mine that he can take in a word: how large the
overflow is (a quarter of a stockpile's places); what it takes (any load that no ordinary place
takes); what a serf does when the overflow is full too (sets its load down where it stands and goes
on; nobody sets out for that kind until there is room); and whether the improvements (a covering, a
fence, a storehouse) come in this pass or after (after). **Nothing of it is built or designed, and
nothing is to be built until he opens it: the defaults are offers, not leave to build on silence.**
On the table for it besides, from the list of open questions: what a full stockpile should mean (20); which improvements, in what order,
what starts each and what each does (21); the salt, which matters only at the butchering while nothing
spoils (22); whether the cart's salt counts as stock (2, which he put to the stockpile).
