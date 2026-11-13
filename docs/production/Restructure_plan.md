# Restructure plan

Nov 9, 2026 · @John

This is a work order for Claude Code: bring the production folder in line with the Production Framework before stage 5 starts. Pass 1 moves and splits documents and touches no code. Pass 2 restructures code and waits for John's go.

## Rules for the work

Nothing in pass 1 changes how the game builds or behaves, and every step can be undone from the tag.

- Tag the start and work on a branch: `git tag pre-restructure`, then `git switch -c restructure`.
- Pass 1 touches nothing under `src/`, `game/` or `tools/`, and does not touch `castle.gpr`.
- Nothing is deleted. Tracked files move with `git mv`. Files outside the repo are copied in, and the originals stay until John removes them.
- Text moves exactly. Corrections go in a separate commit after the move, so the move can be checked line for line.
- One commit per step, with a message that starts `restructure:`.
- A file the inventory does not map stops the work. Ask John.

## The tree as it is (Claude Code, 2026-11-09)

This plan was written from castle\_game\_stage4.zip, which holds only the repo. What is really on disk, and what follows for the steps below:

```text
CASTLE_GAME/
  castle_game_latest.zip, castle_game_stage2.zip .. stage4.zip    -> releases/
  color_palette.txt, color_palette.jpg     the palette's source: copy the .txt to docs/design/, the .jpg to releases/ or docs/design/ (420 KB; John's call)
  DOCUMENTATION/                           plans, handoffs, design docs; also 5 PDFs (27 MB), 4 videos (28 MB),
                                           2 PNGs, reference_run_stage4.txt
  GAME_alpha_1_3/compiled/                 the repo; also untracked and ignored: bin/, obj/, saves/, preview/, screenshot.png
  GAME_alpha_1_3/source/                   an unzip of castle_game_latest.zip
~/.claude/projects/-home-bythergig/memory/ Claude Code's memory, which names DOCUMENTATION and the repo path
```

- Handoffs on disk are named `Handoff 2026 11 08 stage 3.md` (spaces); step 2 renames them.
- The two framework files are `Production Framework TAB 1.md` and `Restructure plan TAB 2.md`; they become `Production_Framework.md` and `Restructure_plan.md`.
- `tools/colony_v7.bin` (a version 7 colony blob the check loads) and `tools/reference_run.sh` are tracked files under tools/ and stay there.
- README.txt is deleted (John, 2026-11-09), so step 0's clean tree holds.
- Stage 4R (the runner) landed before this restructure: `src/castle-scenario.*` and `tools/colony_run.adb` exist, and the README has a colony\_run section, which goes to colony.md.
- `wild_vegetables.png` and `Color Palette 70594.png` in DOCUMENTATION: to docs/design/ (small) unless John says otherwise.

## Target layout

The repo stays where it is and gains a `docs/` folder, so one root holds the code and every document a session reads. Zips, videos and papers stay outside git.

```text
CASTLE_GAME/
  GAME_alpha_1_3/compiled/      the repo: same name, branch main
    README.md                   the project in perspective
    CLAUDE.md                   standing rules, pointing into docs/
    castle.gpr  alire.toml
    src/  game/  tools/         untouched in pass 1
    docs/
      production/               Production_Framework.md, Production_plan.md,
                                Restructure_plan.md, Stage_log.md
      systems/                  one README per system
      handoffs/                 Handoff_YYYY_MM_DD_topic.md
      design/                   design report, organized design, jobs, asset guide,
                                generation spec, design conversations, color_palette.txt
      reference/                REFERENCES.md, the .kkrieger notes
  GAME_alpha_1_3/source/        left as it is
  DOCUMENTATION/                left in place, with a pointer file
  releases/                     stage zips and demo videos, outside git
  papers/                       the reference PDFs, outside git
```

Documents go inside the repo for two reasons. A system README has to change in the same commit as the code it describes. And a stage zip then carries its own plan, handoffs and design.

## System READMEs

Today's README is split by system into `docs/systems/`. The main README keeps the whole project in view; a session loads it, plus only the system files its stage touches.

| File | Takes from today's README | Packages |
| --- | --- | --- |
| world.md | The world model; Storage; the probe tools and preview outputs | Terrain, Geology, Deposits, Hydrology, Flora, Chunks, Worldgen, Maps, Channels, Stacks |
| climate.md | Seasons and weather, and what the seasons do to the picture | Climate |
| rendering.md | How the view works, colours, light and sky, shimmer | Streaming, Mesher, Textures, Render, Camera, Colors, Currents |
| interface.md | The interface | Font, UI, HUD, Input |
| edits\_and\_saves.md | Editing and saves | Edits, World\_Blocks, Saves |
| water.md | Live water | Water |
| people.md | People | Bodies, Poses, Second\_Order, Figures, Serfs, Props |
| deer.md | Deer, with herds | Deer, Animals, Herds |
| routes.md | Routes | Nav, Marks |
| colony.md | The colony, from the homestake to standing orders; then the clock, its ground, saves, scripted options and colony\_check | Colony |
| needs.md | The colony, from eating and sleeping to how it was tuned | Colony |
| habitation.md | village\_preview | Buildings, Iso |

The main README keeps the title, build and run, the game window's options and keys, headless running, and the layout. It gains a short account of the project and a systems map: one row per system with its README, its packages and its check.

Each system README opens with the same four lines, then the moved text unchanged:

```markdown
# System name

- Packages: Castle.X, Castle.Y
- Check: x_check (what it covers, how long it takes)
- Saves: which blob and version carry its state
- Stage: where it was built, and the handoff that records it
```

## Pass 1: folders and documents

Ten steps, each ending in a commit or a check. The work stops after step 0 until John approves the inventory.

### Step 0: tag and inventory

```sh
cd CASTLE_GAME/GAME_alpha_1_3/compiled
git status --short            # must be clean (README.txt, an untracked copy of the README, needs John's call first)
git tag pre-restructure && git switch -c restructure
(cd ../.. && find . -maxdepth 3 -not -path '*/obj/*' -not -path '*/bin/*' -not -path '*/.git/*' | sort) > /tmp/castle_tree.txt
```

List every file outside `src/`, `game/` and `tools/` in `docs/production/Restructure_inventory.md`, each with its destination from the layout above, or the word ask. Stop here until John approves it.

### Step 1: baseline

```sh
gprbuild -P castle.gpr -XCASTLE_MODE=debug -j0
for c in water_sim edit ui dynamics serf path colony deer; do ./bin/debug/${c}_check || break; done
```

All eight must pass with only the six known warnings. Record the result in the inventory file.

### Step 2: bring the documents in

Create the `docs/` folders. Copy in the plan, the handoffs, the design documents, the palette and the notes, renaming handoffs to `Handoff_YYYY_MM_DD_topic.md`.

Write `docs/reference/REFERENCES.md`: each paper's title, author, file name and where it is kept. Write `docs/production/Stage_log.md`: one row per closed stage with its date, commit, zip, demo and handoff. Commit.

### Step 3: split the README, text unchanged

Copy each part of the README into its system file by the table above, add the four opening lines, and cut the main README down to what it keeps. Do not re-wrap or reword a moved line. Then prove nothing was lost:

```sh
git show pre-restructure:README.md | grep -v '^[[:space:]]*$' | sort > /tmp/before.txt
cat README.md docs/systems/*.md | grep -v '^[[:space:]]*$' | sort > /tmp/after.txt
comm -23 /tmp/before.txt /tmp/after.txt     # lines lost: only headings may appear
```

Commit as `restructure: split README into system READMEs (text unchanged)`.

### Step 4: corrections

In a separate commit, fix what the move carried over. The Saves paragraph still describes format 3 while the format is 5. The "Not there yet" line lists the winter store and the winter fire as missing. Fix any other statement the code contradicts, and list each fix in the commit message.

### Step 5: the main README

Write the short account of the project and the systems map. Point to the framework, the plan and the latest handoff. Update the layout listing to include `docs/`. Commit.

### Step 6: CLAUDE.md

Replace the `../../DOCUMENTATION/` pointers with `docs/` paths. Add the reading order from the framework, and the rule that a change in behaviour updates its system README in the same commit. Commit.

### Step 7: stale references

```sh
grep -rn "DOCUMENTATION\|Handoff 20\|claude_handoff\|production-plan\|color_palette\|castle_game_latest" README.md CLAUDE.md docs
grep -rn "DOCUMENTATION\|color_palette" src game tools     # list these for pass 2; change nothing
```

Fix every hit in the documents. Commit.

### Step 8: outside the repo

Move the stage zips and demo videos into `CASTLE_GAME/releases/` and the PDFs into `CASTLE_GAME/papers/`. Put a `MOVED.txt` in `CASTLE_GAME/DOCUMENTATION/` saying where its contents now live. None of this is tracked, so there is no commit.

### Step 9: verify, hand off, merge

```sh
git diff --stat pre-restructure -- src game tools castle.gpr     # must print nothing
gprbuild -P castle.gpr -XCASTLE_MODE=debug -j0
for c in water_sim edit ui dynamics serf path colony deer; do ./bin/debug/${c}_check || break; done
grep -oh 'docs/[A-Za-z0-9_./-]*\.md' README.md CLAUDE.md | sort -u | while read p; do [ -e "$p" ] || echo "missing: $p"; done
```

Write `docs/handoffs/Handoff_YYYY_MM_DD_restructure.md`. After John's review, merge `restructure` into `main`. John uploads the changed documents to the Project (/send-to-project is his to type). Claude Code also fixes its own memory file, which points at DOCUMENTATION.

## Pass 2: code structure

Four changes bring the code in line with the framework's architecture rules. None changes behaviour, and none starts without John's go; the natural time is the stage 5 kickoff.

| Change | Why | Proof that nothing changed |
| --- | --- | --- |
| Move the deer's standing-mode enum from Castle.Animals to Castle.Deer | Castle.Herds then builds without the presentation packages | deer\_check and colony\_check pass, and a herd save loads to the same bytes |
| Split castle-colony.adb along its 23 sections into nested packages with separate bodies. First commit: state and forward declarations gathered at the top (a subunit sees only what is declared above its stub, and the sections call each other both ways). The 711-line Step\_Member is split last, a procedure per group of states. | A session reads one section instead of 5,157 lines | colony\_check passes after each section, including save, load, save to the same bytes; the reference run in colony\_run gives the same log |
| Move behaviour tunables that sit in package bodies up to their specs | The balance pass finds every tunable in one kind of place | The debug build and all eight checks |
| Fix the stale paths in source comments that step 7 listed | Comments should point at files that exist | The debug build, with no new warnings |

The colony split goes one section per commit. State stays in the parent body, so no save format changes.

### Pass 2 as done (2026-11-09)

- The enum is `Castle.Deer.Standing_Mode`; `Castle.Animals.Mode` is a subtype of it. Castle.Herds no longer withs Castle.Animals. (Castle.Deer still withs Castle.Bodies and Castle.Poses, which are data and geometry, not drawing.)
- The colony split uses subprogram subunits, not nested packages: the 44 subprograms of 25 lines or more each became `src/castle-colony-<name>.adb`, and Step\_Member became six procedures by group of states. Nested packages were not used because a subprogram declared in the colony's spec cannot be completed inside a nested package (about a hundred would have needed renamings), and subunits keep declaration order, so nothing needed forward declarations. The parent body (5,157 lines to about 1,750) keeps its section banners and reads as the index.
- Moved to the spec: Raw\_Order, Greens\_Order, Keep\_Order, Fetch\_Order, Free\_Day, Eat\_Base\_S, Eat\_Per\_Point\_S and the eight Max\_ capacities. Still unnamed: the short work times written as literals in the step procedures (storing 1.0 s, lifting 1.2 s, and the like); naming them is left for when they are tuned.
- The three source comments are fixed.
- Proof: all eight checks pass; the 3-day and 41-day reference runs give the same state hashes as before pass 2 (384f3e0921552152, 62d6f6a8b154dc57).

## Done when

- [ ] `git diff --stat pre-restructure -- src game tools castle.gpr` prints nothing
- [ ] The eight checks pass in debug with only the six known warnings
- [ ] The lost-lines check prints nothing but headings
- [ ] Every document is in `docs/` under its kind, named by the convention
- [ ] The main README and CLAUDE.md name only paths that exist
- [ ] The restructure handoff is written and the Project files are refreshed

To start the work in Claude Code, save this plan in the repo folder as `Restructure_plan.md` and send:

```text
Read Restructure_plan.md and CLAUDE.md.
Do pass 1 only. Start with step 0 and stop when the inventory is written: I approve it before anything moves.
Touch nothing under src/, game/ or tools/. One commit per step. Ask before anything the plan does not cover.
```

## Calls for John

Three choices in this plan could fairly go another way. Each is settled at the inventory, before anything moves.

| Call | This plan assumes | The other way |
| --- | --- | --- |
| Where documents live | Inside the repo, under `docs/` | Kept in `CASTLE_GAME/DOCUMENTATION`, with only the system READMEs in the repo |
| `GAME_alpha_1_3/source/` | Left as it is | Moved to `releases/` as the snapshot from the earlier sessions |
| Reference PDFs | Outside git, listed in REFERENCES.md | Tracked in the repo, about 20 MB |
