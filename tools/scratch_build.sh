#!/bin/bash
# The working copy built somewhere else: nothing is compiled or linked in the working copy.
#
#   tools/scratch_build.sh DIR [release|debug] [MAIN.adb ...]
#
# Copies the working tree as it stands (uncommitted work too; not obj/, bin/, saves/ or .git)
# over DIR and builds it there, all of it or the mains named.  For when John's game is running
# or he says he is playing (a build in the working copy would relink bin/castle_game under
# him), and for trying something beside the working copy.  DIR/bin (DIR/bin/debug) has the
# programs.  DIR is overwritten by the next call: a print put into its sources is gone then,
# and nothing that runs from it should be running.
#
# It prints the errors and the warnings that are not the six known ones of
# tools/water_sim_check.adb, then "built MODE (exit N)".
REPO=$(cd "$(dirname "$0")/.." && pwd) || exit 1
DIR=$1; MODE=${2:-release}
[ -n "$DIR" ] || { echo "scratch_build.sh DIR [release|debug] [MAIN.adb ...]"; exit 2; }
shift; [ $# -gt 0 ] && shift
mkdir -p "$DIR" || exit 1
# DIR is overwritten: it must be empty, or a scratch copy made here before (a castle.gpr and no .git)
if [ -e "$DIR/.git" ] || { [ -n "$(ls -A "$DIR")" ] && [ ! -e "$DIR/castle.gpr" ]; }; then
  echo "$DIR is not empty and is not a scratch copy of this tree (or it holds a .git): not touched"; exit 2
fi
rsync -a --delete --exclude obj --exclude bin --exclude .git --exclude saves "$REPO/" "$DIR/" || exit 1
cd "$DIR" || exit 1
gprbuild -P castle.gpr -XCASTLE_MODE="$MODE" -j0 "$@" > build_$MODE.log 2>&1; E=$?
grep -E "error|warning" build_$MODE.log | grep -v water_sim_check | head -n 30
echo "built $MODE $* (exit $E)"
exit $E
