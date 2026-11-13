# Castle Game handoff (2026-11-10: stage 5c, the demand chain; closed; Claude Code)

- Code: GAME_alpha_1_3/compiled, `main` (built on branch `stage-5c` from ac56903, tag `pre-stage-5c`, and
  fast-forwarded). Zip: CASTLE_GAME/releases/castle_game_stage5c.zip. John then cleared the session to
  work on the engine for a while before coming back to the colony.
- Checks: all nine pass in debug; six known warnings. colony_check 282 (was 243), ui_check 112 (was 63).
  `tools/reference_check.sh` passes (both runs).
- Versions: Generator_Version 11, save format 5. Colony blob 13.

## Before this stage, on main
- Stage 5b closed (Handoff_2026_11_10_stage_5b_skills.md).
- The interface's scale (ac56903): F10 and F11, a quarter at a time, 1 to 8; `--uiscale 2.5`;
  `saves/settings.txt` (Castle.Settings; a scripted run reads none unless `--settings FILE`). Whole
  scales lay out the same quads as before (hashed, at 1, 2, 3, 5). The two keys were not pressed by hand.

## How the rules stand (2026-11-10)
Put to John as an ADR with the three first-launch changes at its head. His answer, after trying the
build: "those mechanics work well and we will polish them up later". So, as with 5b, the stage is closed with the
rules standing as built: first values, his to tune, not ruled on line by line.

The brief's nine (docs/production/briefs/Stage_5c_brief.md). The three that change what he sees: with no
winter store ordered the band keeps one to two days of food and dies in winter; hunters hunt whenever
food is asked for; wood is a surplus of 20, not "no limit".

## Built
- Castle.Colony: `Demand_Row` (asker, kind of ask, what, how much), `Good_View`, `Demand_For`,
  `Food_Demand`, `Asked_For`, `Take_Stock` (once a colony second), `Set_Demand_Chain`, `Rest`.
  Gates: `Go_Fell`, the hunter's and the porter's and the gatherer's branches of `Think`;
  `Go_Forage (Asked_Only)`. `Person_View.Resting`. Why_Idle gained `Enough_Food`.
- Castle.Views.Demand and Asked_List; the Stores tab; the zone sheets.
- Castle.Scenario: `--no-demand`, `--reserve wood|vegetables N`, the `demand:` line, "asked:" on the
  food lines.

## Measured (seed 1, the reference setup, colony_run)
- Chain off: 41 days is stage 5b's log line for line; with skills off too, stage 5a's. In the older blob
  layouts the states are 1bc8acb9221efb47, e7544f4f15a0096c, 9609e60367c60fff, d3f9abae3bb7efce.
- Chain on (blob 13): 3 days f6826f1e6e5e87a6 (the same with 3 workers); 41 days (--winter-store 10
  --reserve meat 60) b311396272a41fad; the log is reference_runs/reference_run_stage5c.txt.
- Winter store 10: 141 meat and 6.6 days of food on day 45 (63 and 5.2 in 5b); the last food on day 57;
  six alive on day 59, two at spring. The meat reserve (20 or 60) makes no difference: the store is never
  full, so the hunters never stop. Deer stay at 6 to 8 in reach: prey is the limit.
- No winter store: food between about 1 and 2 days, up to four at rest at once; all six dead by day 52.

## Saves
Blob 13 appends the switch, food's latch, the count of kinds, each kind's latch. Before 13: chain on,
wood reserve of none becomes 20, stock taken at the first step. tools/colony_v12.bin.

## Known limits
- A gatherer mid-bush fills its basket before it stops.
- A resting producer thinks again only after its stroll (8 to 28 s and the walk).
- The camp asks for its fire's logs whether or not there is a cook to tend it.
- `--no-demand` does nothing for a colony loaded from a save.
- Not looked at in the window: the Stores tab's new table, at any scale.

## Not done
- **No demo video was recorded for this stage**, and the Stores tab's table was not looked at by me in
  the window (John tried the build).
- John's polish of 5a, 5b and 5c, when he lists it.

## Next
- Engine work first (John's call; not yet specified). Then stage 6, habitation: its rows are
  `Who => A_Zone` in `Build_Rows`.
