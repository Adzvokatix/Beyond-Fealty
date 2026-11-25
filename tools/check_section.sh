#!/bin/bash
# One section of colony_check alone.
#
#   tools/check_section.sh DIR "HEADING" ["NEXT HEADING"]
#   MODE=debug tools/check_section.sh ...          (the debug build: range and index checks, assertions)
#
# The whole check is a quarter of an hour in debug.  This cuts a copy of tools/colony_check.adb
# down to its declarations, its first statements, and its sections from the one whose heading
# holds HEADING to the one whose heading holds NEXT HEADING (to the end if none is given),
# builds that in DIR (a scratch copy of the working tree, made by tools/scratch_build.sh) and
# runs it.  A heading is a line the check prints that ends in a colon, as
#   Put_Line ("the square's walls and stairs:");
# and one inside a declare block cannot be cut at: give the section's own.
#
# It says NOT BUILT, and leaves with 2, when no heading matches or the cut does not compile:
# it never runs the program of the time before.  The log is DIR/section.log.
#
# A section run alone has only what the check's first statements set up.  One that goes on from
# the section before it fails alone ("growing back" wants the bushes the two sections before it
# picked): begin the cut at the earlier heading.  One that needs trees calls Set_Trees itself
# (the whole check sets them once, early).  So a failure here is read against the whole check
# before it is believed.
REPO=$(cd "$(dirname "$0")/.." && pwd) || exit 1
DIR=$1; MARK=$2; ENDM=$3; MODE=${MODE:-release}
[ -n "$DIR" ] && [ -n "$MARK" ] || { echo 'check_section.sh DIR "HEADING" ["NEXT HEADING"]'; exit 2; }
mkdir -p "$DIR" || exit 1
# DIR is overwritten: it must be empty, or a scratch copy made here before (a castle.gpr and no .git)
if [ -e "$DIR/.git" ] || { [ -n "$(ls -A "$DIR")" ] && [ ! -e "$DIR/castle.gpr" ]; }; then
  echo "$DIR is not empty and is not a scratch copy of this tree (or it holds a .git): not touched"; exit 2
fi
rsync -a --delete --exclude obj --exclude bin --exclude .git --exclude saves "$REPO/" "$DIR/" || exit 1
B=$DIR/bin; [ "$MODE" = debug ] && B=$DIR/bin/debug
rm -f "$DIR/tools/section_only.adb" "$B/section_only" "$DIR/section.log"
DIR="$DIR" MARK="$MARK" ENDM="$ENDM" python3 - <<'PY'
import os, sys
d = os.environ['DIR']
lines = open(d + '/tools/colony_check.adb').read().split('\n')
begin = [i for i, l in enumerate(lines) if l == 'begin'][0]
def head(mark):
    found = [i for i, l in enumerate(lines)
             if i > begin and 'Put_Line ("' in l and mark in l and l.rstrip().endswith(':");')]
    if not found:
        sys.exit(0)                       # no such heading: nothing is written, and the script says NOT BUILT
    start = found[0]
    while lines[start - 1].startswith('   --') or lines[start - 1].strip() == '':
        start -= 1
    return start
start = head(os.environ['MARK'])
tail = [i for i, l in enumerate(lines) if l.strip() == 'New_Line;' and i > start and 'all checks passed' in lines[i + 2]][0]
end = head(os.environ['ENDM']) if os.environ.get('ENDM') else tail
first = [i for i, l in enumerate(lines) if i > begin and l.strip().startswith('Put_Line (')][0]
out = '\n'.join(lines[:begin + 1] + lines[begin + 1:first] + lines[start:end] + lines[tail:])
out = out.replace('procedure Colony_Check is', 'procedure Section_Only is').replace('end Colony_Check;', 'end Section_Only;')
open(d + '/tools/section_only.adb', 'w').write(out)
PY
[ -e "$DIR/tools/section_only.adb" ] || { echo "NOT BUILT: no section's heading holds \"$MARK\"${ENDM:+ (or \"$ENDM\")}"; exit 2; }
( cd "$DIR" && gprbuild -P castle.gpr -XCASTLE_MODE="$MODE" -j0 section_only.adb 2>&1 | grep -E "error" | head -n 20 )
[ -x "$B/section_only" ] || { echo "NOT BUILT"; exit 2; }
( cd "$DIR" && timeout 2400 "$B/section_only" > section.log 2>&1 ); E=$?
echo "exit $E; ok lines $(grep -c '^  ok' "$DIR/section.log")"
grep -E "FAIL|passed|FAILED" "$DIR/section.log" | cut -c1-300 | head -n 20
exit $E
