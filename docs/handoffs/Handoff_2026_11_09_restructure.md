# Castle Game handoff (2026-11-09: restructure, pass 1; Claude Code)

- Code: GAME_alpha_1_3/compiled, branch `restructure` (not merged yet: it waits for John's review), tag
  `pre-restructure` at 85daabf. No file under src/, game/ or tools/ changed, nor castle.gpr.
- Checks: all eight pass in debug at the tag (the baseline); six known warnings. Nothing since then
  touches code, so they were not run again.
- Versions: unchanged (Generator_Version 11, save format 5, colony blob 10).

## Rules agreed with John (2026-11-09)
- Documents live in the repo under docs/. GAME_alpha_1_3/source/ is left as it is. PDFs stay outside git.
- color_palette.jpg is tracked in docs/design/. Reference runs go in docs/production/reference_runs/.
- m2-res_464p.mp4 is a voxel water tech demo: reference material (papers/, described in REFERENCES.md).
- kkrieger notes and the design conversations are kept (docs/reference/, docs/design/).

## Built
- docs/production/: the framework, the plan, the restructure plan and its inventory, Stage_log.md,
  reference_runs/reference_run_stage4.txt.
- docs/systems/: twelve system READMEs split out of README.md, each opening with its packages, check,
  saves and stage. The text was moved unchanged, then corrected in a separate commit.
- docs/handoffs/: the six handoffs, renamed Handoff_YYYY_MM_DD_topic.md. docs/design/, docs/reference/.
- README.md: now 12 KB: the project, where to read, the systems map, build and run, the game window,
  the layout (docs/ included).
- CLAUDE.md: the reading order, docs/ paths, and the rule that a behaviour change updates its system
  README in the same commit.
- Outside the repo: CASTLE_GAME/releases/ (zips, demo videos), CASTLE_GAME/papers/ (PDFs, the water
  video), DOCUMENTATION/MOVED.txt. The originals of the copied documents are still in DOCUMENTATION.

## Corrections made (step 4)
- edits_and_saves.md: the save layout said format 3; it is 5, with the format 4 and 5 fields added.
- colony.md: "Not there yet" listed the winter reserve order and firewood, both built.

## Proof
- `git diff --stat pre-restructure -- src game tools castle.gpr` prints nothing.
- The lost-lines check prints only the four lines step 4 corrected.
- Every docs/ path named in README.md and CLAUDE.md exists.

## Known limits
- Handoffs are left as written, so the older ones still name DOCUMENTATION and the old file names.
- For pass 2 (source comments): castle-colors.ads says color_palette.txt is "beside the game folder";
  castle-colony.ads and tools/flora_stats.adb say "the README" where a system README is meant.
- castle_game_stage4.zip predates docs/; the next stage zip will carry the documents.

## Not done
- The merge of `restructure` into main (after John's review).
- The upload to the Project (John's step: /send-to-project).
- Pass 2: the enum move, the colony split, body tunables to specs, source comments. It waits for John's go.

## Next
- John reviews and says merge. Then pass 2, starting with the Castle.Animals.Mode move (small) and the
  first commit of the colony split (state and forward declarations to the top), then stage 5a.
