# Restructure inventory (pass 1, step 0)

2026-11-09, Claude Code. Tag `pre-restructure` is at 85daabf; the work is on branch `restructure`.
Every file outside `src/`, `game/` and `tools/`, with where it goes. **ask** means John decides; nothing
marked ask moves until he has. Nothing is deleted: files outside the repo are copied in and the
originals stay.

## In the repo (tracked)

| File | Goes to |
|---|---|
| README.md | stays; split into docs/systems/*.md at step 3, the main README kept |
| CLAUDE.md | stays; pointers changed at step 6 |
| castle.gpr, alire.toml, .gitignore | stay, untouched |

## In the repo folder, not tracked

| File | Goes to |
|---|---|
| bin/, obj/ | stay (build output, ignored) |
| screenshot.png (1.3 MB, ignored) | stays where the game writes it |

## CASTLE_GAME/ (the base folder)

| File | Goes to |
|---|---|
| castle_game_latest.zip, castle_game_stage2.zip, _stage3.zip, _stage4.zip | CASTLE_GAME/releases/ (moved, step 8) |
| color_palette.txt | docs/design/color_palette.txt (copy; the original stays, since CLAUDE.md and a source comment name it until pass 2) |
| color_palette.jpg (420 KB) | **ask**: docs/design/ (tracked) or releases/ (not tracked). I'd track it: it is the picture of the palette. |

## CASTLE_GAME/DOCUMENTATION/

| File | Goes to |
|---|---|
| Production Framework TAB 1.md | docs/production/Production_Framework.md |
| Production plan.md | docs/production/Production_plan.md |
| Restructure plan TAB 2.md | docs/production/Restructure_plan.md |
| Handoff 2026 11 07 ui.md | docs/handoffs/Handoff_2026_11_07_ui.md |
| Handoff 2026 11 08 stage 2.md | docs/handoffs/Handoff_2026_11_08_stage_2.md |
| Handoff 2026 11 08 stage 3.md | docs/handoffs/Handoff_2026_11_08_stage_3.md |
| Handoff 2026 11 08 world look.md | docs/handoffs/Handoff_2026_11_08_world_look.md |
| Handoff 2026 11 09 stage 4 camp and food.md | docs/handoffs/Handoff_2026_11_09_stage_4_camp_and_food.md |
| Handoff 2026 11 09 stage 4R runner.md | docs/handoffs/Handoff_2026_11_09_stage_4R_runner.md |
| Castle Game — Preliminary Design Report.md | docs/design/Preliminary_Design_Report.md |
| Castle_Game_Organized_Design.md | docs/design/Castle_Game_Organized_Design.md |
| jobs.txt | docs/design/jobs.txt |
| asset_generation_guide.txt | docs/design/asset_generation_guide.txt |
| preliminary_PROCEEDURAL_GENERATION.txt | docs/design/preliminary_PROCEEDURAL_GENERATION.txt (the generation spec) |
| Color Palette 70594.png (19 KB) | docs/design/ |
| reference_run_stage4.txt (16 KB) | docs/production/reference_runs/reference_run_stage4.txt (a folder the plan does not name; **ask** if you'd rather it sat elsewhere) |
| wild_vegetables.png (1.5 MB) | CASTLE_GAME/releases/ (a screenshot; too large to track for what it is) |
| colony_stage1_berries.mp4, colony_stage3_hunt.mp4, colony_stage4_camp.mp4 | CASTLE_GAME/releases/ |
| m2-res_464p.mp4 (9.7 MB) | **ask**: I don't know what this video is. Reference material (papers/) or a demo (releases/)? |
| StamFluidforGames.pdf, Vlachos-Waterflow(...).pdf, gdc_2011_grimes_nonstandard_textures.pdf, roomvoxelgeneration.pdf, ecp083410.pdf, 2006-SG-SM-RP-Futureplay.pdf | CASTLE_GAME/papers/, each listed in docs/reference/REFERENCES.md (I will read each title page for its title and author) |

## GAME_alpha_1_3/source/

121 files: an unzip of castle_game_latest.zip. Left as it is (the plan's assumption).

## Named by the plan but not on disk

| The plan expects | What I found |
|---|---|
| The .kkrieger notes (docs/reference/) | Not in CASTLE_GAME. **ask**: is it only in the Project? |
| "Design conversations" and "the building conversations" (docs/design/) | Not on disk. **ask**: only in the Project? |
| claude_production-plan.md, claude_handoff-2026-11-07-ui | Project-side names; on disk they are Production plan.md and Handoff 2026 11 07 ui.md |
| A demo for stage 2 | None was recorded (Stage_log.md will say so) |

## Outside CASTLE_GAME

| File | What happens |
|---|---|
| ~/.claude/projects/-home-bythergig/memory/castle-game-autonomy.md | Claude Code's memory; I update its paths at step 9 |

## Calls for John (from the plan, plus what the inventory raised)

1. Documents inside the repo under docs/ (assumed), or kept in DOCUMENTATION?
2. GAME_alpha_1_3/source/ left as it is (assumed), or moved to releases/?
3. PDFs outside git (assumed), or tracked (27 MB)?
4. color_palette.jpg: tracked in docs/design/ (my suggestion) or in releases/?
5. m2-res_464p.mp4: what is it, and where does it go?
6. reference_run_stage4.txt in docs/production/reference_runs/: all right?
7. The .kkrieger notes and the design conversations: are they only in the Project? If so I leave them out and say so in REFERENCES.md.

## John's answers (2026-11-09)

1 to 3 as assumed: documents in the repo under docs/, source/ left as it is, PDFs outside git.
4. color_palette.jpg tracked in docs/design/.
5. m2-res_464p.mp4 is a tech demo of voxel water (a pond, a broken cliff, a waterfall, the pond settling):
   reference material, so it goes to papers/ and is described in REFERENCES.md.
6. reference_run_stage4.txt in docs/production/reference_runs/.
7. John added `kkrieger notes.md` and `design conversations.txt` to DOCUMENTATION. Both are worth keeping:
   the first is the basis of the serf stepper and the textures (docs/reference/kkrieger_notes.md); the
   second is the source of the settlement-generation rule and several pillars, and stage 6 needs it
   (docs/design/design_conversations.txt).

## Baseline (step 1)

At 85daabf (the tag), debug build: ui, dynamics, edit, serf, colony, deer, path and water_sim checks all
pass; six known warnings, all in water_sim_check.
