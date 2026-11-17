# Castle Game handoff (2026-11-14: what the ground costs to keep. A stack's ground summary and its fine bricks kept small, nothing lost; the mountains' boulders thinned, generator 14; the buried skin tried thinner and not taken. Branch `ground-memory` from `main`; Claude Code)

- **Accepted 2026-11-14 ("I accept ground-memory, what do you mean by is the whole-map-solid work?"): on `main`.** It was branch `ground-memory`,
  from `main` at c399ee8 (the herds' search, accepted the same day:
  `Handoff_2026_11_13_herds_search.md`); `git checkout ground-memory && git branch -f main c399ee8`
  puts `main` back where it was. The last commit that changes code is d274934, gated from a clean
  copy; what follows it is documents and a comment. **`main` is generator 14 now: saves of 13 are
  refused.** His calls (below) he did not speak of: they stand as built, first values still.
- Four commits of work: 8628ff7 (the runner measures what the ground costs to keep), 8693f7c (a
  stack's ground summary kept small), db81448 (a chunk's fine bricks kept small), d274934 (the
  boulders: generator 14). The first three change no run; the fourth changes the world.
- Checks, from a clean copy (`git archive`) built from nothing, on 8693f7c, db81448 and d274934: both
  builds with the six known warnings only; all nine checks in debug (edit_check 24 -> 30 -> 32; the
  rest as they were: path_check 69, colony_check 635); `tools/reference_check.sh` eight logs line for
  line (on 8693f7c and db81448 the logs of generator 13, untouched: storage changes no run; on d274934
  all eight recorded again); `tools/stress.sh runner` "nothing died, nothing dropped", with two new
  lines (the crowd's sixty days with every summary kept whole, and with every fine brick written
  whole, end in the same state); on 8693f7c and db81448 the stress runner's states are those of
  `main` (crowd_at_work 65f6a73c7070c7b9, crowd_as_it_is 0f0371c4b9e6f833, housing_2_workers
  a8985757556bec7f); the flora's hash the same in both builds.
- Versions: **`Generator_Version` 14** (13 is refused: the boulders). Save format 6, colony blob 25,
  the herds' blob 2: as they were. Nothing of how the ground is kept is saved.
- Driven only by script: nothing of the interface or the pointer is touched.
- **Test windows of mine on his desktop**: four glides of 520 m and back over the river (about 600
  frames each: the summary's one reader in the game); three stills of a mountain (240 frames each)
  and one of the open land (200); the two herd demos filmed again (900 and 480 frames); and **four
  more of 4,000 frames each opened while his own game was running**, before I had looked (a
  measurement of memory that measured the wrong process and gave nothing). The measurement was then
  made in a hidden window. Nothing was built in the working copy while his game ran.
- Zip: CASTLE_GAME/releases/castle_game_ground_memory.zip (a `git archive` of the branch). Pictures
  and demos: CASTLE_GAME/releases/boulders_before_after.png (the same mountainside on generator 13
  and 14); colony_herd_chain_gen14.mp4 and colony_herds_still_gen14.mp4, the two herd demos filmed
  again on the new world (the moments they filmed were of the old world's days; the recordings of
  `main`'s world are left beside them under their own names).

## John's words

2026-11-14, after the herds' search was merged, in four questions and then a request. Whole:

"So when, we shift to the players limited view, we can stream less ground around them, and have NPCs
and animals draw their own ground?"

"Let me ask you, something we build the world with a couple of meteres already drawn right? and then
surrounding blocks are created when dug into right? Does that generated ground below the surface cost
anything for streaming? can we remove the buffer underground that we have and extand the loaded ground
to the entire map?"

"can make the whole map solid and stream only the mesh?"

"Right the inhabitants don't care what texture the objects are only the player does, so let's find
out what the 68kb is, 4.7 GB isn't going to be acceptable, so we need to be smart about this"

"we are generating textures, is each block still holding it's values individually even though we
removed the mesh?"

"Sure build the compact summary. Additonally, I read the steam hardware survey, 98% of PC's that took
the survey have 8gb of memory or more, 90% have 12gb or more, the 87% have 16gb or more, so we want to
be comfortable on 8gb of ram, that means consuming 4gb is our ceiling, I propose we scale back boulders
on mountainous terrain by about 80%, let's compensate with increasing boulders on open terrain by 30%,
I am looking at the mountains right now and they are littered with boulders, and the player probably
won't be accessing a majority of them. Let's see if we can cut the burried skin down to 4kb a stack,
and see what that buys us."

How the last is read:
- **"Sure build the compact summary"**: built (8693f7c). Storage only.
- **"comfortable on 8gb of ram ... consuming 4gb is our ceiling"**: his constraint, written into the
  framework's decisions. It is the game's: the game holds about 510 MB at its default view today.
- **Boulders, 80 % fewer on mountainous terrain, 30 % more on open**: built (d274934), by the
  generator's own mountain mask, counted before and after. A change to the world: generator 14.
- **"Let's see if we can cut the burried skin down to 4kb a stack, and see what that buys us"**: an
  experiment, answered two ways. Thinning the generator's skin does it (3.4 KB) and was not taken;
  keeping fine bricks small does it better (0.9 KB) with nothing changed for any reader, and is built
  (db81448).
- The whole map held for the simulation with only the mesh streamed, which his questions lead to, is
  **not built and not designed: his to open.** What is here is what it would cost.

## Measured: what is kept of a stack, and what it comes to

`colony_run --ground-stacks 400 --no-mesh --mem` (new: 8628ff7) brings the whole map in, 65,536
stacks, and counts what is kept of each from the sizes of the objects and how many are allocated. Seed
1; the runner, which keeps a stack's blocks and its ground summary and no mesh.

| | a stack | the whole map kept | the process holds |
|---|---|---|---|
| as it was (generator 13) | 68.0 KB | 4,355 MB | 4.76 GB |
| the ground summary kept small | 39.8 KB | 2,546 MB | 2.87 GB |
| and the fine bricks | 15.5 KB | 992 MB | 1.28 GB |
| and the boulders thinned (generator 14) | 15.5 KB | 990 MB | 1.27 GB |

Of a stack as it was: the ground summary 32.0 KB (47 %), fine bricks 28.2 (41 %), the brick and ref
grids of its chunks that are not uniform 6.6 (10 %), the array of chunks 1.3. Of a stack now: the
summary 3.7, fine bricks 3.9, the grids 6.6 (the largest part now, not looked into), the array 1.3.

- **The game itself, at its default view (1,257 stacks): 62 MB less, measured.** `main`'s build and
  this one, the same view, each in a hidden window with software drawing (so that nothing opened on
  his desktop: his own game was running): 1,829 MB and 1,767 MB resident once the view had filled.
  Those totals are the software renderer's, not what the game holds on his card (about 510 MB by the
  stress table); the difference is the game's. The whole-map figures are the runner's.
- A stack's blocks come in without a mesh in 1.4 ms of CPU, with one in 8.0 (measured before the
  bricks were kept small): the whole map without meshes in 4.0 s on this machine with them small,
  3.9 s whole (32 threads, the machine otherwise quiet).
- Beside all this, not in the table: the walking map, 14.4 KB for a stack someone has walked and 5.2
  for each kind of dry going asked there; the generator's map-wide fields, some 290 MB, which the
  game holds too.

## As built

### The runner measures (8628ff7)

- `--ground-stacks N`: the ground within N stacks of the stake in, in batches of 512 (asked for all
  at once, 65,536 requests came in on one thread and took ten minutes: not looked into). **A run
  with more ground in is another run**: the colony's index reaches past the ground kept for it by
  rule (a square of 11 stacks each way; the runner keeps a disc of 13, the game of 11), so it knows
  of more bushes and trees. Three days of the reference band were the same in everything it did; the
  state hash is not.
- `--mem`: what is kept, by part; fine bricks by what they hold; the spread from stack to stack;
  block columns by their stretches; what the process holds.
- `--no-mesh`: the workers make no meshes (`Castle.Streaming.Build_Meshes`). The runner throws every
  mesh away, so its run is the same (the band's 41 days: the same state, 6.1 s for 7.7).

### The ground summary kept small (8693f7c)

- `Castle.Water.Small_Summary`: each of a stack's 1,024 block columns has a place of 16 bits. A
  plain column (one stretch of open space, open to the sky, dry and not source water: 89 in a
  hundred over the map) is the row of its floor; any other's place is where its record begins in a
  pool of 16-bit words (how many stretches and whether it flows, its rest level, three words a
  stretch). 3.7 KB a stack on average where it was 32.8.
- Read a column at a time (`Column_Of`), written the same (`Set_Column`): over itself where a plain
  column stays plain or another keeps its number of stretches; by packing the stack's summary again
  where not (4,353 of the crowd's 151,199 edited columns in sixty days; no time to measure).
- `Castle.World_Blocks` keeps it so. One test of whether a stack's ground is known (`Has_Ground`).
  `Summary_Of`, which the game reads when it writes a kept stack's water texels again, unpacks into
  one buffer.
- `Small_Summaries` off (`--full-summaries`, the runner's and the game's) keeps it whole as it was.

### Fine bricks kept small (db81448)

- Counted first: over the whole map no fine brick holds more than sixteen different blocks, and
  seven in ten hold two. Of the 4.2 million with no air in them (the buried skin), 98 in a hundred
  hold two.
- `Castle.Chunks`: a fine brick is a record of 16-bit words in its chunk's pool: how many different
  blocks, those blocks, and for each of its 64 places which of them, in one bit, two or four: 14, 26
  and 66 bytes; a brick of more than sixteen is written whole. `Block_In` reads a block out of it;
  `Fine_At` gives a brick whole. Nothing else reads a chunk's bricks.
- **It costs a little time**: the band's 41 days 5.5 s for 5.3 to 5.4, the crowd's sixty days 8.9
  for 8.7 (the machine quiet, the switch turned to and fro three times and twice: a block read out
  of a fine brick is a few shifts where it was an index).
- `Small_Bricks` off (`--whole-bricks`) writes every brick whole.

### The buried skin, the other way: tried and not taken

The generator's skin 1 m deep in place of 2 (`Castle.Geology.Skin_Depth_M`; a scratch build, not
committed). The ground with no air in it: 3.4 KB a stack where it was 8.0 (his 4 KB, met); fine
bricks 23.6 for 28.2; the whole map 314 MB less. The reference band's 41 days and the housing run's
ended in the very states they end in at 2 m. **But the housing run read 23 blocks below the skin where
it reads 15** (of 247 million reads; the band's run none either way): with a thinner skin the colony
is told "not made yet" a little more often when it digs. Nothing came of it in those two runs; it
changes what a reader can be told, so it was not committed. With fine bricks kept small the same
ground is 0.9 KB at the full 2 m, and the thinner skin would save a further half a kilobyte.

### The boulders (d274934)

- `Castle.Flora.Boulder_At`: the chance of a boulder at its place is taken 1.3 times where the
  generator's mountain mask is nothing and a fifth from 0.2 of it up, eased between
  (`Boulders_Open`, `Boulders_Mountain`, `Boulder_Foot`, first values of mine for where the foot of
  a mountain is). The roll is the place's: those left on a mountain are of those that were there;
  the open land's are all still there with more among them.
- Counted by `flora_stats`, which counts boulders by the mask now (seed 1):

  | | of the map | generator 13 | generator 14 |
  |---|---|---|---|
  | open land (mask under 0.1) | 79.5 % | 2,217 | 2,828 (+28 %) |
  | the foot of the mountains (0.1 to 0.2) | 3.2 % | 443 | 202 |
  | mountains (0.2 and over) | 17.3 % | 7,275 | 1,447 (-80 %) |
  | the whole map | | 9,935 | 4,477 |
  | within 60 m of the reference stake | | 30 | 16 |

- **Fewer by the reference stake, not more** (16 for 30 within 60 m): it stands at a mountain's
  foot. Probed: the mask is 0.38 to 0.52 on the crag north-east of it, and 0.1 or more at a quarter
  of the places sampled within 60 m (20 of 81). He asked for more on open land; his own site, by
  the generator's reckoning, is not all open land.
- **What it buys is for the eye**: boulders were 0.8 % of the fine bricks, so in memory nothing (990
  MB for 992); in a view of a mountainside from above, 2 % of the quads (8.87 million for 9.04).
- Every reference run's scene is set as it was, to the line (the stockpiles' places, the camp's
  floor, the hovels' room). All eight logs recorded again. How they end moved, both ways, as with
  every change to the world: today's band with housing, all six living as before, 14 deer with 30
  arrows (15 with 32); of the seven older-configured, the first winter is survived by 0, 5, 3, 6, 6,
  4 and 2 where it was 5, 5, 6, 0, 0, 5 and 5.
- Today's reference band, 41 days, on generator 14: all six living, 15 deer with 38 arrows (36), the
  herds frightened 83 times (82), no plan out of budget.

## Proved

- **The summary**: the debug build unpacks every summary it keeps and compares it with the whole,
  and after every column written compares the small summary with the whole summary written the
  same. Six days of the band so (1,038 packings again), and the whole map brought in. `edit_check`:
  four stacks of the world; a made-up summary with columns of every kind; four thousand columns
  written one at a time (plain over plain, over their own words, packed again: each several hundred
  times), never a byte more than the summary packed afresh; a stack kept, dug into and built over by
  the game's own calls, small and whole. Broken six ways, it fails each.
- **The bricks**: the debug build reads back every fine brick it packs, place by place, against the
  blocks it was made of: over the whole map, 14.7 million bricks, none other. `edit_check`: bricks
  made up of 2, 3, 4, 5, 15, 16, 17 and 64 different blocks, small and whole. Broken five ways, it
  fails each.
- **No run moved** (generator 13): the eight reference logs line for line on each of the two
  commits; the stress runner's three states those of `main`; the band's 41 days and the crowd's
  sixty the same with each switch off.
- **The game's own reader of a summary** (no headless check runs it): a scripted glide of 520 m east
  and back over the river south-west of the stake, with summaries small and whole, twice each. The
  river is drawn in all four; two pictures of the same build differ from each other as much as
  small differs from whole (3 % to 14 % of pixels by more than 8: the band, the light).

## Not measured again on generator 14

The system documents quote many figures taken on generator 13 (the needs' winters, what levelling
costs, the deer's tracked days, the looks' costs). They are as they were written: each says its
generator. Measured again on 14: the eight logs, the stress runner (by the gate), today's band's 41
days, the boulders, the whole map kept. `docs/systems/deer.md`'s table of the two herd rules is of 13.

## His calls

1. **Where a mountain's foot is** (`Boulder_Foot` 0.2 of the mask): the 80 % applies from there up,
   and half that between 0.1 and 0.2. The mask is the generator's, not the slope: a steep bank in
   open country has 30 % more.
2. **Fewer boulders by the reference stake** (16 for 30 within 60 m): the crag there counts as
   mountain. The band still finds its stone.
3. **The thinner skin** was not taken. It can be, with the bricks small: half a kilobyte a stack
   more, and the colony told "not made yet" a little more often.
4. **Reading a block costs 2 to 3 % of a run** with the bricks small. `--whole-bricks` is the way
   back.
5. **The grids** (6.6 KB of the 15.5) are the next thing to shrink, if the whole map is to be held.
6. **The whole map held for the simulation**: about 1 GB more than the game holds now (990 MB for
   the map; the generator's fields, which the runner's 1.27 GB includes, the game holds already),
   and the walking map where anyone walks. Worked out from the runner; not run in the game. Under
   his 4 GB. Not built: the game still drops a stack's blocks when its mesh leaves the view.

## Known limits

- The figures for the whole map are the runner's; the game was not run with it.
- The older demo scripts (the stages', the housing pass's, the cart's and the rest) film moments of
  histories too and were not run on generator 14: any of them may no longer show what it says.
- A stack's blocks vary from 4 KB to 22 kept small; forest is heaviest.
- A batch of more than a few hundred stack requests at once crawls (found, not looked into).
- The colony's index reaches past the ground the game keeps for it (found, as it was before).

## Accepted, and a question of his (2026-11-14)

His words, whole: "I accept ground-memory, what do you mean by is the whole-map-solid work?"

- **"I accept ground-memory"**: `main` fast-forwarded to the branch. He did not speak of the calls
  (where a mountain's foot is, the fewer boulders by the reference stake, the thinner skin not taken,
  the 2 to 3 % a block read costs, the grids, the whole map): they stand as built.
- **"what do you mean by is the whole-map-solid work?"**: the report had closed "is the
  whole-map-solid work or the stockpile next?", which named a thing by a label of mine. Answered in
  plain words with the report of the merge: it is his own question of that day ("can make the whole
  map solid and stream only the mesh?") made into a piece of work: the game keeping every stack's
  blocks and ground summary for as long as it runs, so that people, animals and water anywhere stand
  on real ground whatever the camera looks at, and making and dropping only the picture (the mesh)
  as the camera moves. Counted here, not built. The question to him was only which he wants built
  next: that, or the stockpile.

## Next

His to say which: the whole map held for the simulation (above; not designed: what it would take is
in "His calls", 6, and in `docs/systems/world.md`, "What a stack costs to keep"), or the stockpile,
which is live in the plan and his to open (four questions put to him with the merge of the herds'
search: `Handoff_2026_11_13_herds_search.md`, "Next"). **Call a thing by what it does when asking
him, not by a label made up in the work.**
