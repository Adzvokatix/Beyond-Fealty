#!/bin/bash
# The colony with its newer systems switched off must still be the colony of
# the stage before them: the 41-day reference run, line for line but for the
# lines that time the run, the state hash (the save blob has grown since) and
# the lines that say how the paths were laid.
#   (everything on)                         is the herds' flight log (the herds fleeing together, out of water)
#   --deer-scatter                          is the hands and levelling log (the herds as they were: each
#                                           deer bolting on its own and trotting back, wading)
#   ... --all-hands --no-level              is the paths and reach log (extra tasks before they were limited,
#                                           paths before stretches, the camp's floor left as it lies)
#   ... --all-hands --no-level --paths-built    is the camp and zones log (paths laid as they were marked)
#   ... --no-labour                         is stage 5c's (the camp and the paths before they took labour)
#   ... --no-labour --no-demand             is stage 5b's (skills on, no demand chain)
#   ... --no-labour --no-demand --no-skills is stage 5a's
# And one with housing, which none of the seven has (stage 6: the reference
# site with a path west over the level ground, housing marked on both sides
# of it, and a porter in the second hunter's place, since thatch is straw):
#   ... --path 1176 1076 1140 1076 --housing ... --housing ... --porters 1 --hunters 1   is stage 6's
# A change that is not about the colony's behaviour must leave all eight passing.
#   tools/reference_check.sh      (about ninety seconds; exits 1 on any difference)
cd "$(dirname "$0")/.." || exit 1
strip() { grep -v '^ran \|^state: \|^world \|^path \|^the paths laid'; }
R=docs/production/reference_runs
FAIL=0
same() {  # LOG WHAT OPTIONS...
  local log=$1 what=$2; shift 2
  if diff <(strip < "$R/$log") <(tools/reference_run.sh 41 --winter-store 10 --reserve meat 60 "$@" | strip) > /dev/null; then
    echo "the reference run $what, line for line"
  else
    echo "FAIL: the reference run differs: $what"; FAIL=1
  fi
}
same reference_run_herds_flight.txt "with everything on is the herds' flight log"
same reference_run_hands_level.txt "with the herds as they were is the hands and levelling log" --deer-scatter
same reference_run_paths_reach.txt "with all hands at extra tasks and no levelling is the paths and reach log" --deer-scatter --all-hands --no-level
same reference_run_camp_zones.txt "and with the paths laid as they were marked is the camp and zones log" --deer-scatter --all-hands --no-level --paths-built
same reference_run_stage5c.txt "with the band's labour off is stage 5c's" --deer-scatter --no-labour
same reference_run_stage5b.txt "and without the demand chain is stage 5b's" --deer-scatter --no-labour --no-demand
same reference_run_stage5a.txt "and without skills either is stage 5a's" --deer-scatter --no-labour --no-demand --no-skills
same reference_run_stage6.txt "with housing marked along a path west, and a porter for a hunter, is stage 6's" --path 1176 1076 1140 1076 --housing 1141 1077 1167 1087 --housing 1141 1075 1175 1065 --porters 1 --hunters 1
exit $FAIL
