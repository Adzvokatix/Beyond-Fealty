# Castle Game handoff (2026-11-22, his notes after the merge: the development menu, the eaters' arms, the deer's back, herds up trees, the sleeper's cloak, clothes of cloth tried, the serfs with more form)

Branch `playtest-notes`, from `main` at da7c7b9. Eight commits of code and checks, and the documents
after them. **Not merged.** `bin/` holds the gated build of 3333aa2, the last commit that changes anything
a gate builds or runs (copied in on 2026-11-23, his game not running).

## His words (whole)

> yes add the cook and the stockman and carpenter, what we need to fix [Image #4] [Image #5], serfs arms
> and hands are behind there back when they sit down to eat, [Image #6], [Image #7], deer can split in
> half when running up steep terrain, and get stuck in the tree if they spawn in inside a tree?, I had
> someone play the game and they suggest that the serfs need a little bit higher detail, a bit more
> "form", the cloak clipping through their clothing when they sleep needs a bit of a fix? They asked if
> the clothes could be dynamic cloth too, I will leave that up to you, try it, if it's too expensive to
> either work or performance wise, drop it and just add their clothes to the "clip box", so the cloak
> wraps around it when they sleep?

His four pictures (`~/Pictures/Screenshots/swappy_and_misc/`): `swappy-20261119-101017.png` and
`swappy-20261119-101019.png` (serfs on a seat, their arms behind them), `swappy-20261120-025424.png` (a
deer in two halves on a rock face), `swappy-20261115-200157.png` (deer among the boughs of a spruce, a
hunter by).

## How it was read

| His words | Read as | Built |
|---|---|---|
| "yes add the cook and the stockman and carpenter" | The answer to the one call put to him with the merge: Cook to go with a person's development entries, the stockman and the carpenter to be added to them | 1 |
| "serfs arms and hands are behind there back when they sit down to eat" | A fault of the eating pose | 2 |
| "deer can split in half when running up steep terrain" | A fault of how a deer is drawn | 3 |
| "and get stuck in the tree if they spawn in inside a tree?" | A fault, and his guess at its cause, to be found out | 4 |
| "the serfs need a little bit higher detail, a bit more "form"" | His playtester's word, passed on as a thing to do: a look, first values of mine behind a switch, his to judge | 7 |
| "the cloak clipping through their clothing when they sleep needs a bit of a fix?" | A fault of the sleeper's cloak | 5 |
| "They asked if the clothes could be dynamic cloth too, I will leave that up to you, try it, if it's too expensive ... drop it and just add their clothes to the "clip box"" | A trial whose answer is mine to give, with its fallback named | 6: tried, dropped; the fallback is 5 |

Each fault was made to happen first, mended, and the same run taken again. What a run showed is said; what
was only read from the code is said to be so.

## First: what the log of the game as it is played has held since yesterday, and I had not read

`docs/production/reference_runs/today_41_days.txt`, which I recorded on 2026-11-22 during the inspection and
put in the gate, **has one of the thirteen die of hunger**. It is the build on `main`, the one he plays;
nothing of today's work made it or mends it.

- Isabel, a forester, goes "to make the ground ready for a hovel" on day 26 at nine (in the housing pulled
  east of the square), and from ten her line is "no stone to wall the ground of a hovel with" by day and
  "looking for work" by night (a run with a line an hour: `tools/today_run.sh 9 --log-hours 1`). She is not
  seen to eat or to sleep again, is at 0 % fed by three that afternoon, standing at 1269.6 1056.7, and the
  kept log says "Isabel has died of hunger" on day 46. Twelve live on.
- **She stands in a pocket of ground a metre square** at the corner of the hovel's lot: asked for a way from
  there to the square on the morning of day 27, the walking map finds four floors and half a metre of way
  (`tools/today_run.sh 7 --try-plan 1269.6 1056.7 22.75 1238.0 1053.9 18.25 2`: "PARTIAL, 4 floors"). A
  still of it: `~/CASTLE_GAME/releases/playtest_notes_2026_11_22/6_found_a_builder_in_a_pocket_of_ground.png`.
- **It is a pit one can walk into and not out of**: asked the other way on the same morning, a way from the
  square to where she stands is found (32.6 m). (A step goes down a metre and up half of one.)
- What dug the pocket, and why no stone comes, were not looked into. After her death the hovel is built by
  another (eight stand at the end).
- I recorded that log for its cart (`tools/today_run.sh` says why its housing lies east) and did not read it
  for who lived. The inspection's report said nothing of it. **The gate has held the game to a log with a
  death in it since.**
- Not mended: it is a piece of work of its own (the lot's digging), and his to open: call 2.

## 1. The development entries of a person's menu (0355c15)

- **Before**: a person's menu offered every job (no job, gatherer, forester, hunter, porter, cook) and, as a
  development entry, Builder. `--no-dev-jobs`, which stands for the player's menu, still offered Cook; the
  stockman and the carpenter were not on the menu.
- **Now** (`Castle.Actions.Dev_Jobs`, on): no job, Gatherer, Forester, Hunter, Porter, **Cook** (its old
  row), **Builder, Stockman, Carpenter**, Follow. With `--no-dev-jobs`: no job and the four, and Follow: no
  Cook.
- **Stockman** makes the person a porter and the storehouse's stockman whatever its portering; **Carpenter**
  a forester and its carpenter. Named before the storehouse stands, the person is a porter or a forester
  like any other until it does, and its stockman or carpenter from the moment it does. It lasts for as long
  as the person lives and keeps that job; given other work, the next is chosen by skill as ever. Nothing
  new is saved (who the two are always was): no blob bump.
- **Shown**: by a scripted right click and click in the game, release and debug: the Stockman row clicked
  and marked on the menu opened again; likewise Carpenter; the player's menu with `--no-dev-jobs`. In a run
  of the played game's first twenty days with a hunter named stockman and a gatherer named carpenter from
  the start (`tools/today_run.sh 20 --name-stockman 10 --name-carpenter 2`): when the storehouse stood
  (day 36, 14.4 h) the stockman was that hunter and the carpenter that gatherer, the cart was brought to
  the storehouse's front an hour later and all fourteen shelves and barrels were made two days on;
  thirteen living; the debug build ended on the release build's state. **The carpenter-to-be held a hovel's
  lot when the storehouse stood** (the lot of "First", above: he had stood in its pocket, starving, from day
  24, 299 hours by the hourly log): within the hour he was a forester with no house, ate, and made the first
  shelf; the hovel he left was built by another (eight stand at the end). **He got out because the pocket
  was opened, not because he was let go**: asked for a way from there to the square at 14:00 and at 15:00
  of that day the walking map still finds four floors and none; at 16:00 a way of 32.9 m. Who opened it in
  that hour was not looked into (his lot had gone to another builder at 14.4 h). So a carpenter named early
  leaving its house was run; one named while it is building was not (read from the code: the same lines
  as any job given).
- `colony_check`: three older checks of the player's menu say six rows where they said seven; two new
  sections (ten checks).
- The scripts' way: `--name-stockman I`, `--name-carpenter I`.

## 2. Eating, the hands before the chest (01deb5c)

- **Reproduced**: a row of five seated eaters seen from behind (`--lineup 5 --lineup-turn 3.14
  --lineup-does sit_eat`): both forearms folded behind the shoulders. At a meal on the square's seats, from
  a save of the played game (its second morning, eleven o'clock): the same. **Standing eaters had it too**
  (`--lineup-does eat`); he named the seated ones.
- **Cause, printed** (the shoulder, the hand's target and the solved elbow of a seated eater, in the chest's
  own frame): the target 9 cm before the chest's middle, where its front is at 10, and 3 cm from its middle
  line; the elbow 13 cm behind the middle. The hands were placed 20 cm before the hips whatever the trunk
  did, and an eater leans and bends; an arm solved to a point inside the chest with its elbow back has the
  elbow behind the back and the forearm through the body.
- **Now** (`Castle.Serfs.Hands_Before_Chest`; `--no-chest-hands`: as it was): the hands are placed in the
  chest's frame (the food a hand's breadth off its front, the other hand going between it and the mouth),
  and an arm so held bends its elbow down by the ribs.
- **The same runs after**: backs clear in the row from behind; hands before the chest and at the mouth from
  the front; the same meal from the same save, the sitters eating with their hands before them.

## 3. A deer is one piece on steep ground (b6942dc)

- **Reproduced by a count** (`--deer-stats`, new: how far apart a deer's hips and withers were drawn, in
  backs' lengths; `--deer-walk` recorded, 400 frames a walk): up the limestone hillside north-east of the
  reference stake (1204 1112 to 1228 1134) 378 of 400 frames over 1.1 lengths, the furthest 2.62; across
  granite 3.08; on the meadow by the stake 6 frames, 1.14. In a recording from the side: the forequarters
  and the hindquarters apart, as in his picture.
- **Cause** (read from the code, and borne out by the count): the hips and the withers each stood at their
  height over the ground under them, half a spine either side of the middle; the two are a box each on a
  bone each.
- **Now** (`Castle.Animals.Whole_Back`; `--no-whole-back`: as it was): the back is pitched as the ground
  under its two ends asks, no steeper than 45 degrees; the ends stand that much nearer each other across
  the ground, each over the ground there; on steeper ground the higher end keeps its own ground and the
  lower is held up, its legs falling short of their hooves.
- **The same five walks after**: none over 1.1, the furthest 1.00.
- `deer_check`: a made-up hillside (27 and 56 degrees) and a wall of rock 3 m high: never over a back's
  length; with the rule out the same runs draw 1.19, 1.99, 2.09 and 4.45, and the check says so.
- A first try (both ends held to within a pitch of the ground under the middle) sank the uphill end into
  the hill and sat the deer down: seen in a recording, not kept.

## 4. A herd is put down only where a deer can walk off (086478f, 96fd1af, 3333aa2)

- **Reproduced by a count** (`colony_run --seed 1 --stake 1178 1078 --herd-scan 200 20`, new: a colony
  founded at each of 441 places 20 m apart, 400 of them on land, its herds looked at where they are put and
  a game hour on; the land's height taken from the generator, not from the walking map): of 800 herds, 14
  were put on the top of a tree's trunk, 3.6 to 6.4 m up, and one on a boulder; their deer were still there
  an hour later. **No still of it**: three tries at three of those trees showed leaves and no deer (they
  are inside the crown).
- **Cause** (read from the code; the count's "on LOG" bears it out): a herd was put on the highest floor
  the walking map has at the place drawn for it, and a trunk two blocks thick has a floor on its top (leaves
  are not solid). All five deer are put down at the herd's node; a deer steps down a metre at the most. His
  guess was right.
- **Now** (`Castle.Herds.Set_Walk_Off`; `--herds-anywhere`: as it was): a place is taken only if, stepping
  as a deer steps, ground 6 m away can be got to from it. One that fails is passed over for the next drawn.
- **The same count after**: 800 herds put down, none on a trunk, none where a deer cannot walk off.
- **Nothing else moved**: the rule asks nothing of the planner and draws no number, so a herd that was put
  on good ground is put on the very same ground. The eight reference logs and the log of the game as it is
  played: line for line, none recorded again.
- `tools/herd_places.sh` (new, in the gate): both counts; fails on a herd on a trunk with the rule, and on a
  count with the rule off that finds none. `colony_check`: the rule both ways on the made-up meadow.
- **A colony saved with a herd up a tree keeps it there**: the rule is for where a herd is put down, once.

## 5. A sleeper's cloak lies over all the sleeper is dressed in (a859921)

- **Seen first**: the thirteen asleep on the square of the played game, its second night (a save at
  23:30): a chest and an arm through the cloak of everyone.
- **Cause** (read from the code): the cloth is kept out of capsules; the ten it was kept out of are a
  body's middle lines with radii of their own. None lies along the ribs (the first runs from the hips to
  the waist), and a sleeve or a skirt is wider than the one it hangs on.
- **Now** (`Cloak_Fit`, the game's `Dressed`; `--no-cloak-fit`: as it was): laid over a sleeper, the cloth
  is kept out of every box of the sleeper's own rig as its bones lie. **A worn cloak is kept off the ten as
  before**: it hangs as it did.
- **The same sleepers after**, frame by frame as the cloaks settle and all thirteen at the three hundredth
  frame: covered from the shoulders to the knees, nothing through; the head and the feet out, as the
  cloak's length has it. The same night in winter dress (`--winter`: hoods on): likewise. The new build
  with `--no-cloak-fit`: a shoulder through the cloak, as in the build before.

## 6. Clothes of cloth: tried, dropped

In a scratch tree; nothing of it is in the repository. The tunic's skirt and the dress as a tube of the
cloaks' cloth hung from a ring round the belt.

- **Cost**: 0.88, 0.91 and 1.02 ms a frame for thirteen skirts in three recorded runs, the gate running
  beside them on the same machine (thirteen worn cloaks in one of the same runs: 0.89). A skirt is worn all
  day by everyone; a cloak costs only while worn.
- **Look**: standing and walking, a skirt of six flat sides, without its belt, its hem's trim or a
  gatherer's apron (painted on the rigid skirt; a cloth panel is one colour). On a woman turning by the
  fire it swung out into a skewed cone. Asleep, a barrel round the legs of everyone, cut through by the
  cloak (cloth is kept out of capsules, not out of other cloth).
- **Dropped.** The patch, six stills (each beside the game as it is) and the figures are in
  `~/CASTLE_GAME/releases/wip/cloth_skirts_trial_2026_11_22/`.

## 7. The serfs with more form (14bb325)

First values of mine, his to judge. `Castle.Bodies.More_Form`; **`--no-form` gives the serfs as they were,
to the box**.

- A **neck**: a pixel of the trunk's height, out of the chest. The head is where it was and a serf as tall
  as its genome says; the shoulders, and all that hangs from them, are a pixel (5 cm) lower.
- A **nose**.
- **The hair as a cap** over the crown, the back and the sides of the head (a kerchief likewise).
- **Limbs** all but round, narrowing more to the wrist and the ankle; the trunk a little more to the waist,
  the head to the jaw.
- Two or three boxes more a serf: 25 at the most of the 28 a look may have.
- **Tried and left out, as they looked in a row of seven**: a shoulder round the top of each arm (puffed
  sleeves); a belt proud of the tunic (a platter round the waist of anyone chopping); the hair as a cap
  over the whole crown (a flat hat); the head stood a pixel higher (`serf_check` failed: a serf 5 cm taller
  than its genome says).
- **Looked at**: standing from the front and from behind, in winter dress, chopping, eating seated, the
  band setting off with its cloaks and packs, the thirteen asleep under their cloaks, and from 22 m, where
  it changes little: it is for a close look.
- The body pixel is 5 cm still, the world's texel: "higher detail" was not read as a finer skin.
- **`--no-form` is the serfs as they were, to the box**: every box, joint and skin of 500 people in every
  outfit (12,000 rigs, 408,216 lines) dumped from the tree of `main` and from the new tree with the look
  off: the same, byte for byte. (A comparison of pictures said nothing: a row of seven drawn twice by the
  build before differs from itself in 48,840 of 921,600 pixels, the grass and the row's own stirring.)
- **What it costs was not measured** (two or three boxes more of some twenty a serf), nor what the
  sleeper's fit costs while a cloak settles.

## What was run, and what could not show

- **The window's code** (the poses, the deer's drawing, the cloak, the new look) is run by no part of the
  gate. It was run by hand: the debug game, every check on, through eighteen recorded scenes (the meal, the
  night, the band setting off, a row at each of twelve motions and in winter dress, the deer's walk up the
  hillside, a row of deer): no scene raised. That was before the last two changes to the look (the neck
  out of the chest, the belt off); after them the release build was looked at in stills, and `serf_check`
  run in debug.
- **Not looked at since the shoulders came down a pixel**: a log, a sheaf or a deer carried on the
  shoulders. Each is placed from the solved shoulder, so by the code it comes down with it.
- **The four drawing switches off together on the new build** (`--no-form --no-chest-hands --no-whole-back
  --no-cloak-fit`), a seated row from behind: the arms behind the backs and the look of before, as in the
  build before beside it. (By eye: the two pictures differ in the grass.)
- **The pointer's real input** (a mouse) cannot be driven headless; the menu was clicked by the scripted
  pointer.
- **The form was judged by me, in stills.** Whether it is what his playtester meant is his to say.

## The gate

Two, each from a clean copy by `tools/gate.sh`, each 59 minutes; their logs are kept in
`~/CASTLE_GAME/releases/wip/logs_2026_11_23_playtest_notes/`.

- **On 086478f** (the first four pieces): "gate done: passed". Set beside the inspection's kept summary
  (d0e9694), timings aside, it differs in `colony_check` (1,069 ok for 1,059) and `deer_check` (19 for 14),
  and in the order of two site lines (the sites run side by side). Every site line, every stress state and
  the flora hash are the same. **Its own last line did not run**: I edited `tools/gate.sh` while it was
  running (to add the part below), and the shell read what was left of the script from the wrong place
  ("syntax error", exit 2). Its summary had been written by then and says passed; the summary's lines are
  what is quoted here.
- **On 3333aa2** (all of the code, the checks and the gate's new part): **passed**. Both builds from nothing
  with the six known warnings and no other. The nine checks: `water_sim_check` 77, `edit_check` 41,
  `ui_check` 112, `dynamics_check` 18, `serf_check` 21 (19), `path_check` 88, `colony_check` 1,073 (1,059),
  `deer_check` 19 (14), `pick_check` 78. The eight reference logs line for line; the game as it is played
  line for line and to its state (23dd6f090cfd96b1); the stockyards, the turned streets and the squares in
  release and in debug; **the herds' places** (new): with the rule 800 herds put down at 400 stakes, none
  on a tree's trunk, none where a deer cannot walk off; as it was, 14 on a trunk and 17 where a deer cannot
  walk off. The stress runner: nothing died, nothing dropped. The flora hash the same in both builds. Set
  beside the inspection's summary, sorted, it differs in the three checks' counts and the new part's lines
  and in nothing else: **no site line, no stress state and no hash moved.**
- After 3333aa2: documents alone (this handoff, the state page, the logs, the switch page, the conventions).
- Each earlier commit was built alone in debug from a clean copy, with no new warning, and a check run on
  it: 0355c15 `colony_check` 1,069; 01deb5c `serf_check` 19; b6942dc `deer_check` 19; a859921 `serf_check`
  19; 14bb325 `serf_check` 21; 96fd1af `deer_check` 19.

## Found on the way, not mended

0. **A builder in a pocket of ground at its hovel's lot, starving to death**: "First", above.
1. **Deer on mountain ledges.** In the count of 4 (with the rule) 17 of 4,000 deer stood, a game hour on,
   where they could not walk 6 m off: every one on a mountainside (62 to 139 m up), on a ledge it had
   stepped down to; five of them one herd's. A deer goes down a metre and up half of one. As it was: the
   same deer (they are in that column's 98 with the 81 up trees). Mending it changes what a herd does
   (a calm deer stepping down no further than it can step back up), so the kept logs would be recorded
   again: his call.
2. **This compiler reads a two-dimensional array with negative lower bounds wrongly** where it can work an
   index out beforehand (GNAT 16.2.1 20260810, `-O1` and up: debug and release alike). Fifteen lines that
   show it: `~/CASTLE_GAME/releases/wip/gnat16_negative_bounds/t5.adb`. It made the first version of the
   rule of 4 refuse every place. Seven arrays of the tree are declared so (`castle-chunks.adb:143`,
   `Castle.Water.View_Grid`, five in `tools/`): whether any is read wrongly was not looked into, nothing
   was changed, and the gate's two builds agree and pass with them. `docs/conventions/how_we_work.md`.
3. **The highest floor at a place is a trunk's top** wherever a trunk two blocks thick stands, and some
   thirty other places in the colony and the game ask the walking map for it (`Castle.Nav.Surface_Z`: a
   scripted stake, a zone's corner, where an arrow lands). None was looked into.

## His calls

Nothing here is done on silence.

1. **Merge `playtest-notes`?**
2. **The builder in a pocket of ground** (found 0): mend it before the arrival? It wants its own round: the
   pocket made by the player's own start and found by a count over lots, the digging mended, the log of the
   game as it is played recorded again with nobody dying. Default: not begun.
3. **The serfs' new look**: keep it, change it, or switch it off (`--no-form` shows the old). First values.
4. **The deer on mountain ledges** (found 1): mend, at the cost of every kept log recorded again, or leave.
   Default: left.

And one that needs no answer to stand: **the seven arrays this compiler may read wrongly** (found 2) are
left as they are unless he says to look into them.

Numbers of mine, his to tune: a deer's back pitched no steeper than 45 degrees (`Back_Pitch_Tan`); a herd
must be able to walk 6 m off (`Leave_M`); the form's values (`Form_Limb_Taper` 0.26, `Form_Waist_Taper`
0.12, `Form_Jaw_Taper` 0.16, `Form_Limb_Round` 0.38, a neck of one pixel); the sleeper's cloak laid 15 cm
higher.

## Not done

- The horses for the cart and how the colony arrives: his to open, with its four calls (`State.md`).
- The cart, the logistics passes, the design document's mechanics: on hold, in his words (`State.md`).
- Old saves: a colony saved before today keeps a herd up a tree if it has one.

## Next

His to say. By his words of 2026-11-22 these notes came "before we get to the next step": the horses for
the cart and how the colony arrives.
