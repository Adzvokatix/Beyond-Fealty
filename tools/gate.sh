#!/bin/bash
# The gate: a commit proved from a clean copy of it.
#
#   tools/gate.sh [COMMIT [DIR]]
#
#   COMMIT   what is gated (HEAD unless given); it is taken by `git archive`, so nothing
#            uncommitted in the working copy is in it and nothing is built in the working copy
#   DIR      where the clean copy is made and every log is left (a new directory under
#            ${TMPDIR:-/tmp} unless given; it must be empty or not there)
#
# What it runs, in this order:
#   both builds from nothing (release, debug): no error, and no warning but the known ones of
#     tools/water_sim_check.adb
#   the nine checks in the debug build, each by its exit code
#   tools/reference_check.sh               the eight kept logs, line for line
#   tools/today_check.sh                   the game as it is played, against its kept log and state
#   tools/stockyard_sites.sh               release, then debug
#   tools/turned_streets.sh                release, then debug
#   tools/square_sites.sh                  release, then debug
#   tools/herd_places.sh                   release: where herds are put down, counted over 400 stakes
#   tools/stress.sh runner                 its states are printed, to set beside the gate before
#   flora_stats                            the two builds must agree on the hash of the trees' shapes
#
# It prints one line a part (what the handoffs quote), says at the end which parts failed, and
# leaves with 1 if any did.  The whole summary is also in DIR/gate.log; DIR is kept (read
# DIR/stress.log and the check_*.log files there, then remove it).
#
# About three quarters of an hour on 32 cores.  Start it in the background.  It needs no window.
# Two gates can run at once (each has its own DIR; the scripts it calls make their own temp
# directories).  Before a gate of a rule that sets a stockyard's floor, way or stair, the
# stockyard census is run in debug as well: the gate's debug half does not scan the stockyards.

REPO=$(cd "$(dirname "$0")/.." && pwd) || exit 1
COMMIT=${1:-HEAD}
HASH=$(git -C "$REPO" rev-parse --short "$COMMIT") || { echo "gate: no such commit: $COMMIT"; exit 1; }
DIR=${2:-$(mktemp -d "${TMPDIR:-/tmp}/castle_gate_${HASH}_XXXX")}
mkdir -p "$DIR" || exit 1
if [ -n "$(command ls -A "$DIR")" ]; then echo "gate: $DIR is not empty"; exit 1; fi
git -C "$REPO" archive "$COMMIT" | tar -x -C "$DIR" || { echo "gate: could not make the clean copy"; exit 1; }
cd "$DIR" || exit 1

FAILED=""
fail () { FAILED="$FAILED; $1"; }
T0=$(date +%s)

{
echo "commit: $HASH ($(git -C "$REPO" log -1 --format=%s "$COMMIT" | cut -c1-90))"
echo "clean copy: $DIR"

for MODE in release debug; do
  echo "--- $MODE build"
  gprbuild -P castle.gpr -XCASTLE_MODE=$MODE -j0 > build_$MODE.log 2>&1; E=$?
  W=$(grep -c 'warning:' build_$MODE.log); O=$(grep 'warning:' build_$MODE.log | grep -vc water_sim_check); X=$(grep -c 'error:' build_$MODE.log)
  echo "exit $E; warnings: $W; not of water_sim_check: $O; errors: $X"
  if [ $E -ne 0 ] || [ "$O" -ne 0 ] || [ "$X" -ne 0 ]; then fail "$MODE build"; fi
done

for C in water_sim_check edit_check ui_check dynamics_check serf_check path_check colony_check deer_check pick_check; do
  ./bin/debug/$C > check_$C.log 2>&1; E=$?
  echo "$C: exit $E; ok lines $(grep -c '^  ok' check_$C.log); FAIL lines $(grep -c 'FAIL' check_$C.log); last: $(tail -n 1 check_$C.log | cut -c1-80)"
  [ $E -eq 0 ] || fail "$C"
done

part () {    #  part "heading" "name for the list of failures" command...
  local HEAD=$1 NAME=$2; shift 2
  echo "--- $HEAD"; "$@"; local E=$?; echo "exit $E"
  [ $E -eq 0 ] || fail "$NAME"
}
part "reference check" "reference check" tools/reference_check.sh
part "the game as it is played" "the game as it is played" tools/today_check.sh
part "stockyard sites" "stockyard sites" tools/stockyard_sites.sh
part "stockyard sites, debug (the walking map mended against read whole)" "stockyard sites in debug" env BIN=./bin/debug tools/stockyard_sites.sh
part "turned streets" "turned streets" tools/turned_streets.sh
part "turned streets, debug (the walking map mended against read whole)" "turned streets in debug" env BIN=./bin/debug tools/turned_streets.sh
part "the square's sites" "the square's sites" tools/square_sites.sh
part "the square's sites, debug" "the square's sites in debug" env BIN=./bin/debug tools/square_sites.sh
part "the herds' places" "the herds' places" tools/herd_places.sh

echo "--- stress runner"
tools/stress.sh runner > stress.log 2>&1; E=$?; echo "exit $E"
[ $E -eq 0 ] || fail "stress runner"
grep -E "state:" stress.log | awk '{print $1, $(NF-2)}' | tr '\n' ';'; echo
tail -n 3 stress.log

echo "--- flora"
./bin/flora_stats > flora_r.log 2>&1; ER=$?; echo "release exit $ER"
./bin/debug/flora_stats > flora_d.log 2>&1; ED=$?; echo "debug exit $ED"
grep -i "hash" flora_r.log flora_d.log | head -4
HR=$(grep -i "hash" flora_r.log | head -1 | awk '{print $NF}'); HD=$(grep -i "hash" flora_d.log | head -1 | awk '{print $NF}')
if [ $ER -ne 0 ] || [ $ED -ne 0 ] || [ -z "$HR" ] || [ "$HR" != "$HD" ]; then fail "flora"; fi

echo "took $(( ($(date +%s) - T0) / 60 )) minutes"
if [ -z "$FAILED" ]; then echo "gate done: passed"; else echo "gate done: FAILED (${FAILED#; })"; fi
} 2>&1 | tee gate.log

grep -q '^gate done: passed$' gate.log
