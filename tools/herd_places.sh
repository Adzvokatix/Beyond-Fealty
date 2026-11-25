#!/bin/bash
# Where herds are put down, counted on real ground.
#
#   tools/herd_places.sh            (release; BIN=./bin/debug for the debug build)
#
# colony_run --herd-scan founds a colony at each of 441 places 20 m apart round the reference
# stake (seed 1; 400 of them are on land) and looks at its two herds where they are put and a
# game hour on.  A herd is put down only where a deer can walk off (Castle.Herds.Set_Walk_Off,
# 2026-11-22: before it 14 of the 800 were put on the top of a tree's trunk, 3.6 to 6.4 m up,
# their deer with them).  This fails if, with the rule, any herd is put on a trunk or where a
# deer cannot walk 6 m off, or if fewer than 700 herds are put down at all; and it fails if the
# same count with the rule off (--herds-anywhere) finds no herd on a trunk: the count would
# then have stopped seeing what the rule is for.  About a minute, the two counts side by side.
cd "$(dirname "$0")/.." || exit 1
BIN=${BIN:-./bin}
TMP=$(mktemp -d)
SCAN="--seed 1 --stake 1178 1078 --herd-scan 200 20"
( "$BIN/colony_run" $SCAN > "$TMP/rule.log" 2>&1 || echo "exit $?" >> "$TMP/rule.log" ) &
( "$BIN/colony_run" $SCAN --herds-anywhere > "$TMP/free.log" 2>&1 || echo "exit $?" >> "$TMP/free.log" ) &
wait
FAIL=0
num () { sed -n "s/$2/\\1/p" "$1" | tail -n 1; }    #  num LOG 'sed pattern with one group'
for W in rule free; do
  L=$TMP/$W.log
  PUT=$(num $L '.*; \([0-9]*\) herds put down,.*')
  TRUNK=$(num $L '.*(\([0-9]*\) on a trunk.*')
  HELD=$(num $L '.*water): \([0-9]*\) herds put down.*')
  LEFT=$(num $L '.*and \([0-9]*\) deer a game hour on.*')
  if grep -q '^exit ' $L || [ -z "$PUT" ] || [ -z "$TRUNK" ] || [ -z "$HELD" ]; then
    echo "FAIL: the count ($W) did not end, or its lines are not as this script reads them"; tail -n 3 $L; FAIL=1; continue
  fi
  if [ $W = rule ]; then
    echo "with the rule: $PUT herds put down at 400 stakes; $TRUNK on a tree's trunk; $HELD where a deer cannot walk off ($LEFT deer cannot, a game hour on: the mountain ledges, found 2026-11-22 and left)"
    if [ "$PUT" -lt 700 ] || [ "$TRUNK" -ne 0 ] || [ "$HELD" -ne 0 ]; then echo "FAIL: a herd put where a deer cannot walk off, or too few put down"; FAIL=1; fi
  else
    echo "as it was (--herds-anywhere): $PUT herds put down; $TRUNK on a tree's trunk; $HELD where a deer cannot walk off"
    if [ "$TRUNK" -lt 1 ] || [ "$HELD" -lt 1 ]; then echo "FAIL: the count with the rule off finds no herd up a tree: it no longer sees what the rule is for"; FAIL=1; fi
  fi
done
rm -rf "$TMP"
exit $FAIL
