#!/bin/bash
# The colony with its newer systems switched off must still be the colony of
# the stage before them: the 41-day reference run, line for line but for the
# lines that time the run, the state hash (the save blob has grown since) and
# the lines that say how the paths were laid.
#   --no-beds --pace 1 --no-cook-hold --no-curing --no-path-holes                      is the herds' flight log (the herds fleeing together, out of water)
#   --deer-scatter                          is the hands and levelling log (the herds as they were: each
#                                           deer bolting on its own and trotting back, wading)
#   ... --all-hands --no-level              is the paths and reach log (extra tasks before they were limited,
#                                           paths before stretches, the camp's floor left as it lies)
#   ... --all-hands --no-level --paths-built    is the camp and zones log (paths laid as they were marked)
#   ... --no-labour                         is stage 5c's (the camp and the paths before they took labour)
#   ... --no-labour --no-demand             is stage 5b's (skills on, no demand chain)
#   ... --no-labour --no-demand --no-skills is stage 5a's
# All seven with --no-beds: since the pass after stage 6a each of the band
# makes itself a bed of straw once the camp is built, which none of them had.
# And all seven with --pace 1: since the same pass the band works and walks
# half as fast again (Castle.Colony.Serf_Pace), and these are the band as it
# was.
# And all seven with --no-cook-hold: since the same pass's fourth round the
# cook keeps a pot's fill of greens in the stores from being eaten raw.
# And all seven with --no-curing: since that round the band comes with the
# lord's cart of salt and meat is counted in pounds, a doe's sixty; these
# are the band with no cart and a doe's eight joints.
# And one with housing and beds, which none of the seven has (stage 6: the
# reference site with a path west over the level ground, housing marked on
# both sides of it, and a porter in the second hunter's place, since thatch
# is straw):
#   --path 1176 1076 1140 1076 --housing ... --housing ... --porters 1 --hunters 1   is stage 6's
# (with a second stockpile south of the path since 2026-11-12: at the pace the
# band works at now it fills one of 48 places by the thirty-seventh day, and
# gatherers with nowhere to put their berries stand awake with them, which is
# no finding about housing)
# (and since the pass's fourth round that eighth run is the band with all of
# that round on: the cook's hold, the lord's cart and meat by the pound, a
# ladder for the roofs.  With --no-cook-hold --no-curing --no-ladders it is
# the log kept before that round, line for line: proved when it was recorded
# again, 2026-11-12.)
# All eight were recorded again on 2026-11-13, when a load in a serf's arms
# came to be taken where it was going before it eats (a fault John found: a
# forester ate at the fire with a log on its shoulder).  Every one of them
# moved: whose winter it is in the seven older runs went both ways (deaths in
# them 27 all told before, 17 after), and in the eighth all six live, as
# before.
# And all seven with --no-path-holes: since the fifth round a hole in the
# ground under a metre of path is filled as it is laid (none lies under the
# reference paths: on or off, all eight are the same).
# The eighth recorded again on 2026-11-13 with the lord's cart pulled into the
# nearest stockpile (its first morning); with --no-cart-pull it is the log kept
# before, line for line (proved when it was recorded again).  The seven older
# runs have no cart (--no-curing).
# The first and the eighth recorded again on 2026-11-13 with a herd's flight in a
# chain (John: "lock them to the node and they run with the node, from the
# closest to the hunter in a chain reaction"): they are the two with the herds
# fleeing together.  The six between run with --deer-scatter and did not move.
# The same two recorded again twice on 2026-11-14, once for each rule of his
# answer (John: "a person standing still doesn't frighten a herd, and let them
# know that water blocks them"): first with a herd's ways refused where water
# blocks them, then with one who stands still frightening no herd.  The six
# between did not move either time.
# All eight recorded again on 2026-11-14 for generator 14 (a fifth of the
# mountains' boulders, three in ten more on open land): each run's scene is set
# as it was, to the line; how each ends moved.
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
same reference_run_herds_flight.txt "without beds is the herds' flight log" --no-beds --pace 1 --no-cook-hold --no-curing --no-path-holes
same reference_run_hands_level.txt "with the herds as they were is the hands and levelling log" --no-beds --pace 1 --no-cook-hold --no-curing --no-path-holes --deer-scatter
same reference_run_paths_reach.txt "with all hands at extra tasks and no levelling is the paths and reach log" --no-beds --pace 1 --no-cook-hold --no-curing --no-path-holes --deer-scatter --all-hands --no-level
same reference_run_camp_zones.txt "and with the paths laid as they were marked is the camp and zones log" --no-beds --pace 1 --no-cook-hold --no-curing --no-path-holes --deer-scatter --all-hands --no-level --paths-built
same reference_run_stage5c.txt "with the band's labour off is stage 5c's" --no-beds --pace 1 --no-cook-hold --no-curing --no-path-holes --deer-scatter --no-labour
same reference_run_stage5b.txt "and without the demand chain is stage 5b's" --no-beds --pace 1 --no-cook-hold --no-curing --no-path-holes --deer-scatter --no-labour --no-demand
same reference_run_stage5a.txt "and without skills either is stage 5a's" --no-beds --pace 1 --no-cook-hold --no-curing --no-path-holes --deer-scatter --no-labour --no-demand --no-skills
same reference_run_stage6.txt "with housing marked along a path west, and a porter for a hunter, is stage 6's" --path 1176 1076 1140 1076 --housing 1141 1077 1167 1087 --housing 1141 1075 1175 1065 --porters 1 --hunters 1 --stockpile 1180 1077 1190 1082
exit $FAIL
