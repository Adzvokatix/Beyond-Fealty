# Castle Game handoff (2026-11-09: stage 4R, the windowless runner; Claude Code)

- Code: GAME_alpha_1_3/compiled, main, the commit after 246455d's successors ("Stage 4R: colony_run").
- Checks: all eight pass in debug; six known warnings.
- Versions: unchanged (Generator_Version 11, save format 5, colony blob 10).

## Rules agreed with John (2026-11-09)
- Balance is for later; the swings are wanted now. Don't retune winter survival unasked.
- The runner is built now; stage 5 is split into 5a (widgets) and 5b (skills).
- README.txt deleted. The Restructure plan is adapted to the real tree (its "The tree as it is" section).

## Built
- tools/colony_run.adb: the real world and the colony with no window, on fixed steps. Ground within the
  colony's reach is streamed in and kept; edited stacks are rebuilt every 30 colony seconds, all at once.
- src/castle-scenario: the colony's command-line options, setup and log lines, used by the game and the
  runner. A new colony option is added there once.
- tools/reference_run.sh [DAYS] [options]: the reference run.
- Options: --seed, --day, --time, --days, --log-hours, --workers, --load, --save, --expect HASH.

## Measured (seed 1, reference setup)
- 3 days: state 384f3e0921552152, the same with 3 or 31 workers and in debug and release. 1.4 s.
- 41 days with --winter-store 10 --reserve meat 60: 11 s; state 62d6f6a8b154dc57; food runs out about day
  55 and the first death is on the last day of winter (log: reference_run_stage4.txt). The save opens in
  the game.

## Known limits
- Live water does not move in the runner.
- The game's own --frames runs still follow real frame time; they agree with the runner in kind only.
- The log lines' wording changed a little (they now come from Castle.Scenario).

## Next
- Restructure pass 1 (step 0: tag and inventory, then stop for John), then pass 2 (the colony split), then 5a.
