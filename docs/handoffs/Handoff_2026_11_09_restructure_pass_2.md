# Castle Game handoff (2026-11-09: restructure, pass 2, code structure; Claude Code)

- Code: GAME_alpha_1_3/compiled, main. Pass 1 merged at 0d49c44; pass 2 is the commits after it.
- Checks: all eight pass in debug; six known warnings.
- Versions: unchanged (Generator_Version 11, save format 5, colony blob 10). No behaviour changed.

## Rules agreed with John (2026-11-09)
- Pass 1 reviewed and merged. DOCUMENTATION moved out of the tree by John (a backup); docs/ is the only copy.

## Built
- Castle.Deer.Standing_Mode replaces Castle.Animals.Mode (now a subtype of it); Castle.Herds no longer
  withs Castle.Animals.
- The colony's body: 44 subprograms of 25 lines or more are subunits (src/castle-colony-<name>.adb), and
  Step_Member is six procedures by group of states (Step_Needs, Step_Camp, Step_Gather, Step_Wood,
  Step_Fetch, Step_Hunt). castle-colony.adb went from 5,157 lines to 1,751: state, helpers, stubs.
- To the colony's spec: Raw_Order, Greens_Order, Keep_Order, Fetch_Order, Free_Day, Eat_Base_S,
  Eat_Per_Point_S and the eight Max_ capacities.
- Three source comments repointed at docs/.

## Changed from the plan
- Subprogram subunits, not nested packages (why: Restructure_plan.md, "Pass 2 as done").

## Measured
- The reference runs give the same state hashes as before pass 2: 3 days 384f3e0921552152; 41 days with
  --winter-store 10 --reserve meat 60, 62d6f6a8b154dc57.

## Known limits
- A subunit sees only what is declared above its stub: new state and helpers go above the stubs.
- Short work times are still literals in the step procedures (storing 1.0 s, lifting 1.2 s, ...).
- game/castle_game.adb is still about 2,500 lines.

## Not done
- No zip for 4R or the restructure (the next stage zip will carry docs/).
- The upload to the Project (John's step).

## Next
- Stage 5a kickoff: the brief from the framework's template (tabs, scroll lists, windows, tooltips,
  proven on the band panel), rules agreed with John before code.
