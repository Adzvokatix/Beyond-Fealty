#!/bin/bash
# What the gate never runs: the gate's parts run in a build that counts every line executed.
#
#   tools/gate_coverage.sh [COMMIT [DIR]]
#
#   COMMIT   what is measured (HEAD unless given), taken by `git archive` as the gate takes it
#   DIR      where it is built and run (a new directory under ${TMPDIR:-/tmp} unless given)
#
# It builds the debug build with gcc's line counting (--coverage), copies it over the release
# build's place too (so every script runs the counted programs), and runs what the gate runs:
# the nine checks, the reference check, the game as it is played and the three site scripts
# (with STRESS=1 the stress runner too: hours in this build, and it runs little the others do
# not).  Then `gcov` and tools/coverage_report.py say, for every source file of src/ and game/,
# how many of its lines that can run were run, and list the subprograms of which no line was.
#
# It is a measure, not a gate: it always goes to the end and its exit says nothing.  It takes
# about two hours beside a gate (the counted debug build is slow) and it leaves DIR for
# reading: DIR/coverage.txt is the report.  A line the gate never runs is not a wrong line: it
# is a line nothing proves.  What only a window can run (the game's own procedure, the
# renderer, the interface) shows as not run here.  gcov is given every object's notes, so a
# file no program of the gate loads counts as not run and is not left out.

REPO=$(cd "$(dirname "$0")/.." && pwd) || exit 1
COMMIT=${1:-HEAD}
HASH=$(git -C "$REPO" rev-parse --short "$COMMIT") || exit 1
DIR=${2:-$(mktemp -d "${TMPDIR:-/tmp}/castle_coverage_${HASH}_XXXX")}
mkdir -p "$DIR" || exit 1
git -C "$REPO" archive "$COMMIT" | tar -x -C "$DIR" || exit 1
cp "$REPO/tools/coverage_report.py" "$DIR/tools/" 2>/dev/null   # (when the commit measured is older than the report script)
cd "$DIR" || exit 1
T0=$(date +%s)
echo "commit: $HASH; in $DIR"
gprbuild -P castle.gpr -XCASTLE_MODE=debug -j0 -cargs --coverage -largs --coverage > build_coverage.log 2>&1
echo "build exit $?; errors: $(grep -c 'error:' build_coverage.log)"
cp -a bin/debug/. bin/                 # the scripts' ./bin is the counted build too
for C in water_sim_check edit_check ui_check dynamics_check serf_check path_check colony_check deer_check pick_check; do
  ./bin/debug/$C > check_$C.log 2>&1; echo "$C: exit $?"
done
tools/reference_check.sh > part_reference.log 2>&1; echo "reference check: exit $?"
[ -x tools/today_check.sh ] && { tools/today_check.sh > part_today.log 2>&1; echo "the game as it is played: exit $?"; }
tools/stockyard_sites.sh > part_yard.log 2>&1; echo "stockyard sites: exit $?"
tools/turned_streets.sh > part_turned.log 2>&1; echo "turned streets: exit $?"
tools/square_sites.sh > part_square.log 2>&1; echo "the square's sites: exit $?"
[ "$STRESS" = 1 ] && { tools/stress.sh runner > part_stress.log 2>&1; echo "stress runner: exit $?"; }
./bin/flora_stats > part_flora.log 2>&1; echo "flora: exit $?"
echo "ran in $(( ($(date +%s) - T0) / 60 )) minutes; counting"
( cd obj/debug && gcov -b -f *.gcno > ../../gcov_all.txt 2>&1 )
python3 tools/coverage_report.py obj/debug > coverage.txt 2>&1
head -n 40 coverage.txt
echo "coverage done: $DIR/coverage.txt"
