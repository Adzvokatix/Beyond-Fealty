# Castle Game handoff (2026-11-22, a structural inspection: the design document brought in, the files checked against each other, the code looked over, the project made easier to work in)

Branch `inspection`, from `main` at b77d6db. Nothing merged. No rule of the game changed.
(Merged later the same day, on his word: "His answer", at the end.)

## His words (whole)

> ok we will stay here then, no housecleaning I am going to leave to you, so we have the new detailed
> mechanics.json file, that is pretty comprehensive, and apart from some of the more technical
> integreations, the framework is pretty much complete for the content side, so here is what we need to
> do. 1. We need to integrate the detailed mechanics.json 2. we need to go through all our files and do an
> alignment check, just make sure everything is meshing together 3. Take a pass of all the code and try and
> find anything that could use some attention we have a TON of code now so it's important that we get
> everything on the same page that we can, 4. Do whatever else you think needs to be done to make this
> project more streamlined and easier for you to do your job, if you want. I am leaving this all up to you,
> so you can decide how you want to tackle it and if anything needs to be done or not. We aren't polishing
> anything this is just a structural inspection.

## How it was read

- **"Integrate" (1)**: the document is brought into the project: committed as it came, checked against
  itself, mapped to the build, and made the thing the plan is read against. **None of its mechanics is
  built.** His hold on the logistics passes (2026-11-19) and "leave the cart" (2026-11-22) stand. The
  reading is mine; it is the first line of the report to him.
- **One test for every change to the code**: it is housekeeping only if the eight reference logs hold line
  for line with none recorded again, and the checks' counts and the stress states are the baseline's.
  Anything that would fail that (a job's name that prints in a log, a list put in another order, a switch
  taken out) is a finding for him and was not done.
- Nothing is deleted or retired: switches, loaders, kept blobs, demo scripts, files outside the repository
  are listed with counts as his calls.
- His stages are not put in another order. Documents are not rewritten shorter; where one is split, every
  line of it is moved whole.

## 1. The design document

- `docs/design/detailed_mechanics.json` committed as it came (77f4244): version 0.14, the head had 0.6.
- `tools/mechanics_check.py` with `tools/mechanics_map.json`: the document against itself (2,155
  cross-references followed) and against the code's lists of jobs, trades, skills, things carried, zones,
  buildings, materials and deposits. It fails when the map is out of date, so a new version of his file or
  a new literal in the code is noticed. Run it when either changes.
- `docs/design/Mechanics_crosswalk.md`: the document, his words since its date, and the build, side by
  side, section by section; fourteen places where the three differ, listed for him, none settled; how the
  document could become data the game reads (not built, and why).
- The document against itself is in good order: one building not listed by its zone (the infirmary), one
  resource nothing makes or uses (dirt, by its own note), eleven research topics named with no section
  that says what research is.
- How much of it the build has a counterpart for: jobs 8 of 65, skills 11 of 18, resources 17 of 131,
  zones 5 of 18, buildings 4 of 55, flora 6 of 9, fauna 1 of 11, deposits 3 of 10, recipes 15 of 166.

## 2. The files checked against each other

**The instrument**: `tools/docs_check.py`. Whatever a living document says in backticks is taken for a
name: an option must be a string in the Ada sources, a path must exist, an identifier must be one somewhere
in the sources; and the other way, every option the sources take should be named by some document. The
living documents are `CLAUDE.md`, `README.md`, `docs/systems/`, `docs/production/` with its briefs,
`docs/conventions/` and the crosswalk: 39 files. It knows 254 options and 13,152 identifiers from 218 Ada
files. The handoffs (53 files, a megabyte) are records of their day and were not checked.

**What it found, and what was done** (commits 01b3cd1 and bc7b56d):

- Seven identifiers the documents named that the sources no longer have. Four were routines gone since
  2026-11-12 and 2026-11-21 (`Target_Row`, `Column_Wants`, `New_House`, `Square_Reach`): each line now says
  what took its place. One was a renamed call (`Castle.Render.Set_Time`: `Set_Look`). Two are right as they
  stand (a patch's name; a sentence about what used to be).
- Six options no document named: three of the runner (`--camp-now`, `--yard-walls`,
  `--yard-census-corners`) and one of the game (`--no-window-trim`) are documented now; two are tools' own
  (`lod_stats --every`, `path_check --no-door-cells`) and were left.
- No source file that no program compiles; no main of `castle.gpr` without its source; no script of
  `tools/` that gives a program an option it does not take.

**Found by reading, and made true** (the same commits):

- `CLAUDE.md` said the generator is version 14; it is 16 since 2026-11-17. It said three old blobs are
  kept; eight are, each read by `colony_check`. It said seven reference logs in one place; there are eight.
- `docs/systems/colony.md` and a comment in `src/castle-colony.ads` said "Water is not fetched yet";
  porters have drawn it into the storehouse's barrels since 2026-11-17. (Nothing takes it out again: by a
  search of the code, not by a run.)
- The framework's table of stages still had the stockpile "Not designed: asked of John", and its table of
  handoffs stopped at 2026-11-20: the row and the four missing handoffs are in. The plan's two closing
  sections of 2026-11-12, overtaken on 2026-11-17, are marked so and left as they stood.
- The README listed eleven stockyards in the site script (seventeen) and six old blobs (eight), and none of
  the new tools or documents.
- The header lines of four system documents: `colony.md` said 801 checks and blob 28 (1,059 and 44),
  `interface.md` 41 checks of `pick_check` (78), `world.md` generator 14 (16), `habitation.md` blob 25.

**Found, and left** (each is listed again under his calls where it is his):

- `tools/reference_run.sh` calls day 20 "summer's fifth day"; the game's own clock shows the same day as
  "Summer, day 6"; his document says they arrive on the 5th day with the thaw on day 41, which is a day
  earlier than the game starts (the crosswalk's first line).
- The conventions name some twenty scratch scripts by `$S/...`, the scratchpad of whichever session wrote
  them. Five that every round used are in `tools/` now (below, 4); of the rest some are kept in
  `~/CASTLE_GAME/releases/wip/scripts/`, each hard-coding a scratchpad that is gone, and some are nowhere
  (`tools/docs_check.py` prints which).
- **One more start at which the colony has no cart.** Looking for a start for the kept log of the played
  game (4, below): a square at 1238 1058 with a stockpile north of it and the stockyard south, thirteen with
  jobs, and housing pulled westward from 1231 1058: no cart at all at the end of 41 days, 35 deer unsalted,
  1,510 lb of meat lost. The same with the pull from 1224 1050 (two days run). With the pull from 1224 1058,
  from 1231.5 1062, eastward from 1250 1058 or 1246 1066, or with no housing, the cart is there. Why was not
  looked into, and whether a played game comes to it was not tried: the cart is left, by his word. The
  kept log's housing lies east.
- `alire.toml` names one executable (`worldgen_preview`) of twenty-two; nothing reads the file.
- Outside the repository: `GAME_alpha_1_3/source/` and `releases/castle_game_latest.zip` are of 2026-11-07,
  from before the work moved to the terminal, and nothing reads them; `bin/band_skills` is a program of
  2026-11-10 that `castle.gpr` no longer builds; `releases/` holds 124 files, 377 MB.

**What was read and what was not.** By eye: all of `CLAUDE.md`; the framework's "How to use", "Phases",
"Stages" and the table of handoffs; the plan's head and its last sections; the README's lists; the stage
brief's "The logistics network"; the head of `needs.md` and `climate.md`. By the instrument alone: the other
thirty-odd living documents, half a megabyte of `docs/systems/` among them. So a sentence in a system
document that is wrong without naming anything that has since gone (as the one about water was) can still
be there.

## 3. The code looked over

104,600 lines of Ada in 218 files: 69,400 in `src/`, 4,900 the game's one file, 30,300 in `tools/`. It
cannot be read through in a sitting, so instruments chose where to read. Each is kept in `tools/`, reads
only, and says in its header what it cannot see.

| Instrument | What it reads | What it gave |
|---|---|---|
| `tools/switch_census.py` (`docs/systems/switches.md`) | The specifications, the option handlers, the gate's scripts, `colony_check` | 71 switches, 62 on by default; for each, which part of the gate runs it which way |
| `tools/unused_entities.py` | The compiler's cross-references (`.ali`) of a finished build | Of 4,273 public declarations in `src/`, 112 nothing refers to and 28 subprograms only their own package uses |
| `tools/code_shape.py` | The sources as text | Sizes, the longest subprograms, repeats, the constructs worth a look |
| The compiler, asked once more with four kinds of warning the build leaves off (`-gnatwh -gnatw.o -gnatwt -gnatw.w`, in a scratch copy, compiling only) | Every source | 574 lines: 408 are a name that hides another, 153 a value a call hands back that is not read afterwards (72 of them in `colony_check`; in the engine nearly all are a buffer handed to its `Free`, and the one unread "Ok" is a leg's reach in `castle-poses.adb`), two `pragma Warnings (Off)` in checks with no `On` after. The counts are by kind; some forty lines were read, not all 574 |
| `tools/gate_coverage.sh` with `coverage_report.py` | The gate's parts run in a build that counts lines | Of 34,620 lines of `src/` and `game/` that can run, 11,082 were never run (32 %); 9,340 of those are in the game's window, the renderer, the interface and what is only drawn |

**Read by eye**: `src/castle-streaming.adb` whole (the worker pool); the seven handlers that catch every
exception and the two `when others => null`; the places the scans pointed at (`Deep_Brick`, `Trade_From`,
`Place_Cart`, the person's menu in `castle-actions.adb`, the option handlers of `castle-scenario.adb`, the
head of `colony_check`). **Not read**: the rest. Nothing below says a file is sound that only a scan saw.

**What stands out**

1. **The kept logs never run the game he plays.** The eight reference logs are a band of six with every
   rule since 2026-11-17 held off: all eight say `--no-storehouse`, `--no-path-level`, `--no-wood-reach`,
   `--no-house-turn`, `--no-roof-timbers`, `--no-window-timber` and `--one-to-a-bush`, and none founds a
   square, puts down a stockyard or turns a building. Those rules are proved by the three site scripts (by
   what must be true at the end) and by the check's sections, not line for line. So "the eight logs hold"
   said nothing of the played game, and the proof that a switched-off rule leaves the game as it was rested
   each round on saves in a scratchpad that the next clear threw away. **Done about it**: a ninth kept log,
   of the game with every rule on (`tools/today_run.sh`, `tools/today_check.sh`,
   `docs/production/reference_runs/today_41_days.txt`; below, 4).
2. **Three programs are one procedure each.** `colony_check` is one procedure of 19,266 lines (134
   sections, a quarter of an hour in debug), `castle_game` one of 4,754, `colony_run` one of 3,315. The
   colony's package body is 16,824 lines beside its 63 subunits; `Plan_Walls` alone is 1,065, the loader
   1,123. Seven subprograms are over a thousand lines, twenty over five hundred. A section of the check
   cannot be run alone but by cutting the file (`tools/check_section.sh` does that), and a section that
   leans on the one before fails alone.
3. **A stack worker that raises is not noticed.** `Castle.Streaming`'s worker prints one line to the error
   stream and ends; the stack it was making never comes, and whatever waits for it waits for ever (the
   game's colony does not advance until its ground is in; a runner does not end). `Lost` counts dropped
   jobs, nothing counts dead workers. This is read from the code, not made to happen: the runner's
   `Take_All` loops while the count of stacks asked for and not yet come is above nothing. It has not
   happened in any run on record; if it did in a gate, the gate would stand. Not changed (his call 5).
4. **Old saves' loaders.** The colony's loader (1,123 lines) tests the blob's version in fifty-one
   places: it reads version 44, the fourteen layouts before it (30 to 43), and layouts back to version 2 for
   the eight old blobs `colony_check` keeps (versions 7 and 10 to 16); 18 to 29 it refuses. His rule of
   2026-11-11 says none need be kept; they stay "while they work". Not touched (his call 4).
5. **Declared and unused.** Of the 112, most are a switch's "is it on?" function that nothing asks, record
   fields that go to the card whole, and palette colours. Worth a look: `Castle.Geology.Deep_Brick` (named
   by three specifications and by `CLAUDE.md` as how deep ground is made; nothing calls it:
   `Castle.Chunks.Deepen` asks `Brick_At` itself); `Castle.Colony.Trade_From` (the table of which job a
   trade rises from: declared, and the code does not read it); seven constants of `Castle.Channels`; and in
   the colony `Mood_Of`, `Stockpile_Number`, `Bush_Reserved_By`, `House_Has_Sills`, `Zones_Version`,
   `Lot_Drawn_At`, `Storehouse_Lot_M`, `Square_Side_M`, `Lot_M`, `Ladder_M`. `Castle.Far` (the old far land,
   kept by his word) is not on the list: `edit_check` still uses it. Nothing removed.
6. **What is in good order.** No check is suppressed in the source; two warnings are switched off; the six
   known warnings are the only ones. Every handler that catches everything either puts something back and
   raises again or reports and goes on harmlessly. Only 25 runs of twelve lines or more are repeated
   anywhere (421 lines of 104,600). The comments carry no list of things owed. Of the colony's switches,
   the other way of every one is run by the check (for nine of them the census could only see the check
   setting the switch by a variable: those call sites were read, and each is a loop over both ways or a
   call with the other value); the four whose other way nothing runs are drawing or debugging (`--nofalls`,
   `--no-turn-floor`, `--flowmap`, the water's leak). The census is of the on-or-off switches alone: what is
   set by a number (the pace, the band's size, the storehouse's size, the stockpile's least side, the reach)
   is not in it.

**What the gate never runs.** The debug build made to count lines, then the nine checks, the reference
check, the stockyard sites, the turned streets and the square's sites but for its last part (stopped
there, two hours in, beside two gates); the stress runner was not counted. The script was mended after this
run (it now counts a file no program loads as not run, and each source line once however many copies the
compiler made of it): its last two steps were run by hand as they now stand; the whole of it was not run again. Measured on 4d5195a, whose
code is the head's but for one comment.

| Part of the program | Lines that can run | Never run | |
|---|---|---|---|
| The colony (`castle-colony*.adb`, the actions, the scenario, the views) | 14,150 | 1,063 | 7.5 % |
| Routes, herds, animals | 2,336 | 140 | 6.0 % |
| The world, its ground, water, saves, streaming, buildings | 4,889 | 530 | 10.8 % |
| The game's window, the renderer, the interface and what is only drawn | 11,361 | 9,340 | 82.2 % |
| All of `src/` and `game/` | 34,620 | 11,082 | 32.0 % |

(The four rows are the 94 files with any line not run; 48 more files ran whole.)

- **Nothing the window runs is run by the gate**: `game/castle_game.adb` (2,991 lines that can run),
  `castle-render.adb` (2,239), `castle-hud.adb` (782), `castle-props.adb` (885 of 897), the previews. The
  gate has no window, by design. So what the player sees and clicks rests on John's own play and on stills,
  as it always has; the count only says how much code that is: a third of what can run.
- **The simulation is run nearly whole**: the colony's body 488 lines never run of 8,876 (5.5 %), the
  walking map 42 of 1,154, the herds 15 of 695, the loader 70 of 783. What is not run there is mostly an
  option no gate part gives (`castle-scenario.adb`, 185 of 867), a switch's "is it on?" that nothing asks,
  and branches of rare moments (someone who dies on the way to eat, with a kill, or with a ladder: a death
  itself is run 32 times).
- 597 subprograms of 2,543 had no line run; 44 of them in the colony's body, most of them the same
  unused declarations the cross-references list.

The report is kept at `~/CASTLE_GAME/releases/wip/logs_2026_11_22_gate86/coverage_4d5195a.txt`.

## 4. Easier to work in

- **`CLAUDE.md` is 30 KB; it was 227.** Its "Conventions from past sessions" are in `docs/conventions/`,
  twelve files, one a part of the game, every line as it stood (ee3da22: 298 lines, 204,887 characters,
  proved by the script that moved them). `CLAUDE.md` keeps the build, the tests, the architecture, and an
  index of which file to read before touching what, with the rules of every change in a line each.
- **`docs/production/State.md`**: where the project stands, on one page, rewritten at each close: the
  build, what is next in his words with its open calls written out, what is on hold in his words, where the
  older open calls and the things found and not mended are.
- **What a session reads to begin** was the framework (107 KB), the plan (75), `CLAUDE.md` (227), the README
  (28) and the newest handoff: over 450 KB. It is now the state page (6), `CLAUDE.md` (30), the conventions
  of the part being touched (1 to 35 each) and the top of the newest handoff. The framework's pillars and
  rules are read as before; the plan and the stage log are looked things up in.
- **The gate is a script in the repository**, `tools/gate.sh [COMMIT [DIR]]`, where it had been a scratch
  file copied from one session's scratchpad to the next. It leaves with 1 when a part fails and names it.
  Run on `main` (b77d6db) from a clean copy it passed, and its summary is the kept log of gate 86 line for
  line but for the timings: 106 lines, the nine checks' counts, every site's line, the fifteen stress
  states and the flora hash among them.
- **The game as it is played has a kept log** (finding 1): `tools/today_check.sh`, half a minute, in the
  gate. Recorded with `main`'s build; the head's build gives it line for line and to its state
  (23dd6f090cfd96b1); with `--no-path-steps` it fails from the second night, as it should.
- **Five scripts every round used are in `tools/`**, free of scratch paths, each run once after the move:
  `scratch_build.sh` (the working copy built elsewhere), `check_section.sh` (one section of `colony_check`),
  `belly.py` (member-hours with an empty belly), `logsame.sh` (two logs across a blob bump), and the gate.
- **My own notes** (outside the repository, in `~/.claude`): the index every session loads had grown to
  18 KB, two of its lines several thousand words each. The rules in it are now eight short files in the
  Castle Game project's own memory directory (where sessions started in `~/CASTLE_GAME` load them), with a
  1 KB index; the two long records are kept unshortened where they were, and copies of everything as it
  stood are in `~/CASTLE_GAME/releases/wip/memory_archive_2026_11_22/`.

## The gate

`tools/gate.sh` on d0e9694 from a clean copy: **passed** (88 minutes, beside the coverage run). Both builds
with the six known warnings and no other; the nine checks with gate 86's counts (`colony_check` 1,059,
`path_check` 88, `pick_check` 78); the eight reference logs line for line; **the game as it is played: its
kept log line for line, and its state** (the first run of that part inside a gate); every line of the
three site scripts, in release and in debug, word for word gate 86's; the stress runner's fifteen states
gate 86's; the flora hash the same in both builds. Its summary and gate 86's kept log differ by the two
lines of the new part and by timings, nothing else. After d0e9694 only documents and
`tools/gate_coverage.sh` with its report script changed. `bin/` was not touched: it is still `main`'s
build, whose code is this branch's but for the comment.

The logs: `~/CASTLE_GAME/releases/wip/logs_2026_11_22_gate86/gate_main_by_tools_gate_sh.log` (the same gate
run on `main` first) and `gate_inspection_d0e9694.log`.

## His calls

Nothing here is done on silence; each stands as it is until he says.

1. **Merge the inspection?** Branch `inspection` holds his design document as it came, the documents'
   corrections and move, the tools, one kept log, and one changed comment in the code. No rule of the game
   changed. One word puts it on `main`; `git checkout main` is the way back until then.
2. **The fourteen places where his document, his later words and the build differ**
   (`docs/design/Mechanics_crosswalk.md`, "Where they differ"). The ones that touch what is built next: the
   day they arrive (a day apart), who arrives with what, and whether the cook and the development list are
   as he means them.
3. **The four calls on the arrival and the horses** stand as put (`docs/production/State.md`).
4. **The loaders of old saves.** Taking them out (blobs 30 to 43, and the eight kept blobs of `colony_check`
   with their checks) takes fifty-one tests of a version out of the loader and stops every save made
   before 2026-11-21 from loading. Default: kept.
5. **A dead stack worker.** Making it end the run with its message, where today the run stands still.
   Default: not changed.
6. **What is declared and unused** (112, listed by `tools/unused_entities.py`). Default: kept.
7. **Splitting the three one-procedure programs**, `colony_check` first (so a section runs alone). Default:
   not done; it is a week's careful work that changes no rule and wants a gate of its own.
8. **About 15 GB of memory** is held by the scratch files of my two sessions before this one, in `/tmp`,
   which is memory on this machine. They go at the next reboot. Default: left.
9. **Stale things outside the repository**, his to remove or keep: `GAME_alpha_1_3/source/`,
   `releases/castle_game_latest.zip`, `bin/band_skills`.

## Not done

- His open calls of earlier rounds are not gathered into one list (`State.md` says where each round's are).
- The system documents were not read through (2, above).
- The code was not read through (3, above).
- Nothing was deleted, retired or put in another order.

## Next

His to say. By his words of 2026-11-22 the next part is the horses for the cart and how the colony
arrives; `docs/production/State.md` has its four open calls.

## His answer (2026-11-22, after the report), and what was done on it

> Okay, merge the branch. We'll change the day to the 6th and the document. Just so we don't have to change
> the code. The cook is earned by skill, but the development UI is the backend we can assign jobs however
> we want with the development UI, the player won't be able to. You can leave the scratch files I have
> plenty of space. Do whatever else you need to do
>
> I will be back at my PC soon, and I will give you my notes on what we need to fix real quick before we
> get to the next step.

- **Merged** (call 1): `main` is the inspection's branch, by a fast-forward. No new gate was run: between the
  gated commit (d0e9694) and the merged head, of everything the gate builds or runs
  (`git diff --stat d0e9694 HEAD -- src game castle.gpr tools docs/production/reference_runs`) four files
  changed, `tools/coverage_report.py`, `tools/gate_coverage.sh`, `tools/mechanics_check.py` and
  `tools/mechanics_map.json`, and the gate runs none of them. `bin/` was not built again: it is gate 86's
  build, and the code differs from it by one comment.
- **The day they arrive** (the first of the crosswalk's differences): read as "the document is changed to the
  6th, the code is not". His design document is now 0.15, changed by exact strings: `meta.version` and
  `meta.date`; `meta.calendar.start.day` 5 to 6 and its note (autumn day 10, winter day 25, the thaw day 40);
  a changelog entry "0.15"; `game_start` step 3 (the 6th day, 40 days to the thaw); the blame text (day 40
  from arrival); `tuning.thaw_day` 41 to 40. The thaw moved a day with the arrival by the document's own
  arithmetic (ten days of summer are left, not eleven); he did not say "day 40" himself, so it is told to
  him. The 0.14 changelog entry was left as history. No code names a thaw. The checker now reads the start
  day from the document's calendar (it was typed into the map): the document 20, the code 20.0, the same.
  **He keeps the document elsewhere too**: a copy brought in from there without these lines puts the 5th
  back, and `tools/mechanics_check.py` then says so (run on the 0.14 copy with `--doc`: the document 19,
  the code 20.0, DIFFERENT, and exit 1 for the version).
- **The cook and the development list** (differences 4 and 5): no code. His word is in the crosswalk and in
  `docs/conventions/interface.md`: a person's menu today is the development interface, any job may be given
  there, and the player's own interface will not give the cook. He did not ask for the stockman or the
  carpenter to be put on the menu and they were not. One thing follows from his word and was put to him
  as a call, not built: the menu offers Cook with every other `Job_Kind`, so `--no-dev-jobs` (the option
  that stands for the player's menu) still offers it; by his word Cook belongs with the development
  entries, beside Builder, and by his rule of 2026-11-19 ("keep adding new jobs as we work them in to that
  list") the stockman and the carpenter belong there too.
- **The scratch files** (call 8): left, and not to be raised again.
- **"Do whatever else you need to do"**: read as the work that follows from this message (the documents
  above made true, the state page, a waiting shell of the coverage run stopped). Not read as his word on
  calls 4 to 7 and 9, on the other eleven differences or on the arrival's four calls: all stand as put.

**Next, by the same message**: his notes on what is to be fixed, then the horses and the arrival.
