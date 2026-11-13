# Castle Game: the stress test (2026-11-11, before stage 6)

John, 2026-11-11: "we are doing some final touch-ups and a stress test before we move to stage 6".

`tools/stress.sh` pushes the colony and the game past what a session of play asks of them, to find where
they break before a player does. It measures and reports; it fails only on a run that dies, a colony
that does not repeat itself, and a line the renderer prints when it has had to drop something. It was
written first and run on `main` (bc0204e) before anything of this session was built, then run again on
the finished branch, so what was already so can be told from what the session changed. Seed 1, the
reference site (stake 1178 1078, camp 1172 1082), RX 6900 XT, 32 threads, 62 GB.

## What it found

1. **Nothing died.** No exception, no failed check, in release or with the debug build's range,
   overflow and validity checks on, through four years of the colony or a year of weather in the game.
2. **The colony repeats itself.** Four years end in the same state on two workers as on all of them; a
   band of forty-eight's year the same on three; a year in the debug build ends in the release build's
   state. The states of the runs with the game's own rules are `main`'s to the bit (built beside it and
   run the same): nothing of this session touched the colony.
3. **Memory does not grow.** The runner peaks at 460 MB after one year and after four. The game holds
   about 510 MB at the default view.
4. **The reference band lives.** With the reference run's standing orders (a winter store of ten days,
   a meat reserve of sixty: what `tools/reference_check.sh` gives it) five of the six are living after
   four years, the one lost in the first winter, as the handoff of the last pass has it; 175 deer taken,
   10,050 stacks rebuilt (since the pathing work all six: below). A band of forty-eight under the same orders is dead within the year: the land
   by the reference stake was never meant to feed forty-eight, and that run is here as the heaviest the
   colony gets (everyone starving and fending at once). `--no-needs --no-demand` (the first is new)
   keeps the forty-eight at work for a year instead. (Asked for no winter store, the reference band
   starves on the seventh day of its first winter. That is the design, the surplus being the player's
   to require, and not a finding; the script gives the orders for that reason.)
5. **A view of 512 m does not fit** (already so). The quad arena is 256 MB; it is full at 9,676 stacks,
   and the 3,176 stacks after that are not drawn, each with a line on standard error. 384 m fits (183 MB,
   8.6 ms of GPU a frame). `--view` is only a command-line option and the default is 160 m, so play does
   not reach it; the on-foot view of stage 7 might. Changed here: it says so once, and the run's last
   lines give the count.
6. **At 240 times speed the colony's steps can hold a frame for a second or more** (already so). A
   band of forty-eight in release: 3.2 s was seen on `main`, 4.0 and 6.9 s on the branch, 0.16 to 1.3 s in
   other runs of each. The reference band in the debug build: 0.3 to 1.5 s several times in a year, 6.3 s
   once. Every such frame is the colony's steps, up to 480 of them taken in one frame (`--hitch MS`,
   new, says where a long frame's time went); with forty-eight they come on the day the band begins to
   starve and everyone plans a way to food at once. At 24 times speed the forty-eight's worst frame is
   45 ms; the panel's speeds go to 3. Not changed: the cure is a budget of time for the colony's steps
   in a frame, with the clock held back to match, and it is wanted when a village of that size is, or
   when play is given speeds like these, not before. (John, on reading this: "Time budget we will leave
   out for now, so we don't interfere with production." Since the pathing work the worst of these frames is
   0.2 s: "Run again after the pathing work", below.)
7. **A band of forty-eight set out at once takes a frame of about 100 ms** (already so): its people and
   their looks are all made in the frame the stake is raised. Once.
8. **Draws can run out before the arena does**: `Max_Draws` is 32,768 a frame, and a frame that draws
   both of the sun's maps and the snow's anew over ten thousand stacks wants more. Nothing in these runs
   reached it (the arena fills first); it used to drop the last draws without a word and now says so,
   once.

## As measured

### The runner (release, no window)

| run | time | peak | at the end |
|---|---|---|---|
| the reference band with its orders, four years | 62.8 s | 460 MB | five of six living; 175 deer, 74,518 edits, 10,050 stacks rebuilt |
| ... on two workers | 69.7 s | 460 MB | the same state (a59611357580942f), and `main`'s |
| forty-eight with the same orders, a year | 76.6 s | 460 MB | none living (the heaviest the colony gets); `main`'s state (cb9e17f55c6d97f5) |
| forty-eight, a year, `--no-needs --no-demand` | 21.4 s | 460 MB | forty-eight; 88 trees, 155,993 edits |
| ... on three workers | 22.8 s | 459 MB | the same state (00bb251aeeb4e64f) |

### The game (release, 1280 x 720, 4x MSAA unless said; GPU and CPU a frame after the view has filled)

| run | `main` | the branch | |
|---|---|---|---|
| view 160 m (the default) | 1.75 ms GPU | 1.72 | 1,257 stacks, 35 MB of quads, 511 MB in all |
| view 256 m | 4.96 | 4.85 | 3,209 stacks, 75 MB |
| view 384 m | 8.52 | 8.62 | 7,213 stacks, 183 MB, 891 MB in all |
| view 384 m, winter, snowing | 8.37 | 8.46 | |
| view 512 m | 11.38 | 11.67 | the arena full: 9,678 stacks drawn, the rest not |
| a pan of 700 m | CPU 10.7 ms at worst | 9.9 | streaming and unloading on the way |
| 2560 x 1440, 8x MSAA, the lowest tilt, cloudy | 2.25 | 2.38 | the clouds' pass at that size |
| 48 people and 64 deer in a row | 0.98, CPU 3.4 at worst | 0.98, 3.3 | |
| 64 lights at night | | 1.58 | (none: 1.18) |
| a storm from the lowest tilt, the sky a third of the picture | | 2.32 | clouds walked, everything wet |
| thick mist from the same place | | 2.12 | |
| 48 at the camp, 240 times speed, a storm, 30 s | 3.68, CPU 10 to 15 on average | 4.12, 10 to 16 | CPU at worst 0.16 to 6.9 s over the runs of both (6, above) |
| 48 at the camp by night, the fire casting | 1.09, CPU 104 at worst | 1.12, 106 | (7, above) |

The branch's column is from a clean copy of its last commit that changes code, built from nothing, before
the moon's second round. The two night rows are on day 20, which is a full moon since that round, and a
moonlit night draws the shadow maps a day does: they read 2.20 ms (64 lights) and 1.36 (forty-eight by
night) now. The rows by day and under cloud are as they were.

### The debug build

| run | the branch |
|---|---|
| the reference band with its orders, a year, in the runner | 50.2 s; five of six living; the release build's state (014a9cf75b0b11da) |
| the same band through a year of weather in the game, 240 times speed (22,000 frames, about 9 minutes) | no exception; GPU 3.3 ms, CPU 6.3 ms a frame on average and 1.3 s at worst (6, above) |

On `main`, before, with no orders given (so the band was dead by the seventh day of winter): no exception
in either; the game's worst frame 1.5 s.

The nine checks pass in debug on the branch (colony_check 422), `tools/reference_check.sh` holds all seven
kept logs line for line, and `tools/shadow_still.sh` reads 0.00 % at one game minute a second, at
three, at dusk, with everything wet and in mist.

### What John saw while it ran (2026-11-11)

He watched the test's windows: "I am seeing drops into the 40s on fps, gpu ms is staying in single
digits, CPU is getting wild, but that could be a consequence of acceleration." It is: finding 6, and for
the nine minutes of the debug build's year, the debug build as well (three to five times slower than the
one he plays). The same band in the release build, at the default window of 1600 x 900, thirty seconds
at each speed:

| speed | GPU a frame | CPU a frame | worst frame |
|---|---|---|---|
| 1 | 3.3 ms | 0.34 ms | 105 ms, once: the frame the camp and the band are set out by the script |
| 3 (the panel's fastest) | 3.4 | 0.36 | the same one |
| 24 | 3.9 | 0.53 | the same one |
| 240 | 4.0 | 1.14 | 136 ms (that frame), then 78 ms of the colony's steps |

Before that he had written "I think our deferred lighting and MSAA 4x is getting expensive", with a note
on how to drop multisampling (a single-sample G-buffer, SMAA 1x on depth edges, distant leaves drawn
whole). What was measured for it is in `docs/systems/rendering.md`, "What multisampling costs": the
renderer is not a deferred one; 4x multisampling is half of the GPU's frame, about a millisecond; and
the frames that dropped were the CPU's.

## Run again after the pathing work (2026-11-11)

Everything above is the test as run on `main` and on `sky-and-weather`. The pathing work that followed
(`docs/handoffs/Handoff_2026_11_11_pathing.md`; `docs/systems/routes.md`, "What routing costs") went
after what finding 6 is made of, so the whole test was run again with it (on branch `pathing`, which
also had the moon's second round in it). Nothing died; the game's debug year, in which every mended stack of the
walking map is read whole beside it and compared, raised nothing.

### The runner

| run | before | on `pathing` |
|---|---|---|
| the reference band with its orders, four years | 62.8 s; five of six living; 40 trees felled, 175 deer | 58.1 s; all six living; 137 trees felled, 170 deer, 251,207 edits, 11,905 stacks rebuilt (0c40aa82baadfbdb) |
| ... on two workers | 69.7 s, the same state | 66.3 s, the same state |
| the reference band's 41 days, and with the walking map read whole and no source memos | | 11.0 s and 11.4 s, the same state (6a4db8e8394b1806) |
| forty-eight with the same orders, a year | 76.6 s; none living | 25.5 s; none living (6fa38c4b974def68) |
| forty-eight, a year, `--no-needs --no-demand` | 21.4 s | 15.4 s; forty-eight; the same on three workers (a47b51189548187d) |

Peak 462 MB. The states are other than the ones above because one change of the pathing work moves
where some routes end (a goal out of reach); from the first autumn the run goes otherwise, all six see
the spring, and the forester, who was the one lost, goes on felling for three more years, which is where
the edits come from. That nothing else moved them was proved by running the four years, the
forty-eight's year and the forty-eight at work again with `--no-mending --no-memos`: the same three
states.

### The game

| run | before | on `pathing` |
|---|---|---|
| 48 at the camp, 240 times speed, a storm, 30 s | CPU 10 to 16 ms a frame on average; at worst 0.16 to 6.9 s | CPU 2.6 to 2.9 ms on average over three runs; at worst 211 to 237 ms |
| 48 at the camp by night, the fire casting | GPU 1.12 ms; CPU 106 ms at worst | GPU 1.36; CPU 61 at worst |
| 64 lights at night | GPU 1.58 ms | 2.20 |
| the reference band through a year of weather in the debug build, 240 times speed | 530 s for the 22,000 frames; CPU 6.3 ms a frame on average, 1.3 s at worst | 399 s; CPU 1.9 ms on average, 0.21 s at worst |
| the reference band's year in the debug runner | 50.2 s; five of six | 42.8 s; all six; the release build's state (175b84154989a018) |

The two night rows cost more on the GPU because of the moon's second round, not the pathing: day 20
is a full moon, and a moonlit night draws the shadow maps a day does (rendering.md, "The sky"). Every
other row of the game's table above read within a few hundredths of a millisecond of its figure there
(view 160 m 1.72 ms, 256 m 4.90, 384 m 8.63, 512 m 11.65 with the arena full as before, the storm from
the lowest tilt 2.34, mist 2.12).

Of finding 6: the long frames at 240 times speed were the colony's steps, and most of that was a
search of everything in reach for a goal nobody can stand at, and every search for the nearest source
reading the ground again. With those gone the worst frame of the forty-eight in these runs is the half
hour of the third day in which all of them find the stores empty and plan a way to food at once (0.2
s), and of the reference band in the debug build 0.21 s. A budget of time for the colony's steps is
still not built (John: "Time budget we will leave out for now, so we don't interfere with
production").

## Not stressed

- Live water at scale (a flood across a valley): the runner has none, and the game's has its own budget
  of 6 ms a frame and 48 awake stacks.
- Other seeds and other sites: every figure here is seed 1 at the reference stake.
- Hours of real play: the longest game run is seven and a half minutes (a game year at 240 times).
- A window larger than this screen (2560 x 1440).
- Input: scripted runs take none.
