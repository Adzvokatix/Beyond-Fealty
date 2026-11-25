#!/bin/bash
# Hovels beside a path at 45 degrees stand turned to it, each on ground made
# where it is drawn (2026-11-19): the band of thirteen with the stockpile and
# housing on both sides of such a path, on the flat south-west of the
# reference stake and on the rising ground north-west of it, eleven days each.
# And up the hillside east of it (2026-11-19, his word: "they need to be able to
# place diagonals on hillsides if they want to"), where one hovel has to stand.
# It fails if fewer than four hovels stand by then, if anyone has starved or
# died, if any block column a turned hovel is drawn on (off its walls' own
# place) is not at its pad's level or has something growing over it, or if
# anyone but its builder and its owner stood on that ground for more than
# thirty seconds of the days it stood (colony_run --turn-stats).  Since
# 2026-11-20 a hovel placed turned is walked where it is drawn: it fails too if
# anyone was in a wall of one as it is drawn, or if the way from the stake to
# its bed goes through one (or is not found); with --no-hovel-walk (NO_WALK=1)
# the hovels are walked as they stand, as before.
#   tools/turned_streets.sh       (about half a minute, release; exits 1 on a failure)
#   BIN=dir   another build's bin directory
cd "$(dirname "$0")/.." || exit 1
BIN=${BIN:-./bin}
TMP=$(mktemp -d)
BAND="--seed 1 --stake 1178 1078 --path 1176 1076 1194 1076 --camp 1172 1082 --day 20 --time 7 --winter-store 10 --reserve meat 60 --band 13 --gatherers 4 --foresters 3 --porters 2 --hunters 3 --cooks 1 --stockpile 1180 1075 1190 1065"
site() {  # NAME LEAST OPTIONS...   (LEAST: how many hovels have to stand)
  local name=$1 least=$2; shift 2
  $BIN/colony_run $BAND "$@" ${NO_WALK:+--no-hovel-walk} --days 11.25 --log-hours 1 --who --turn-stats > "$TMP/$name.log" 2>&1
  local starving living standing turned off grown others walls beds
  starving=$(grep -c 'starving\|has died of hunger' "$TMP/$name.log")
  local empty        # (member-hours with an empty belly: counted and said, not failed on)
  empty=$(grep -c '^  who: [A-Za-z]*, *-\{0,1\}0 % fed: .*(at [-0-9.]* [-0-9.]* [-0-9.]*)$' "$TMP/$name.log")
  living=$(grep '^colony:' "$TMP/$name.log" | tail -n 1 | grep -o '[0-9]* living')
  standing=$(grep '^food' "$TMP/$name.log" | tail -n 1 | grep -o 'housing: [0-9]* standing' | grep -o '[0-9]*')
  turned=$(grep -c '^  house .*(STANDING' "$TMP/$name.log")
  off=$(grep '^  house ' "$TMP/$name.log" | grep -vc ' 0 not at its pad.s level .* 0 with something growing over')
  others=$(grep '^  house ' "$TMP/$name.log" | sed 's/.*others [0-9]* ( *\([0-9]*\) of them.*/\1/' | sort -n | tail -n 1)
  walls=$(grep '^  house ' "$TMP/$name.log" | grep 'walked where it is drawn' | grep -vc 'in a wall as drawn 0;')
  beds=$(grep '^  house ' "$TMP/$name.log" | grep -vc 'its bed: FOUND\(, 0 points of it in a wall\)\?$')
  if [ "$starving" = 0 ] && [ "$living" = "13 living" ] && [ "${standing:-0}" -ge "$least" ] && [ "$turned" = "$standing" ] \
     && [ "$off" = 0 ] && [ "${others:-999}" -le 30 ] && [ "$walls" = 0 ] && [ "$beds" = 0 ]; then
    echo "$name: $standing turned hovels stand on ground made where they are drawn, nobody died or was said to be starving ($empty member-hours with an empty belly); others on that ground $others s at the most; $(grep -c 'walked where it is drawn' "$TMP/$name.log") walked where they are drawn, nobody in a wall as drawn, every bed got to by its door"
  else
    echo "FAIL: $name: $starving lines of someone starving, $living, $standing standing ($turned turned), $off with ground off or grown over, others there ${others:-?} s at the most, $walls with someone in a wall as drawn, $beds whose bed is not got to by its door"
    touch "$TMP/failed"            # (each site runs in a shell of its own)
  fi
}
site "a street at 45 degrees on the flat" 4 --path 1176 1076 1146 1046 --housing 1172 1074 1148 1050 --housing 1174 1072 1150 1046 &
site "a street at 45 degrees on rising ground" 4 --path 1166 1090 1136 1120 --housing 1162 1092 1138 1116 --housing 1164 1094 1140 1120 &
# (the hillside east of the stake, 20 to 30 %, with trees by: one lot is taken, as one is for a square hovel;
# before 2026-11-19's evening none was, and when one first was its builder levelled for ever under a bough)
site "a path at 45 degrees up the steep hillside" 1 --path 1194 1076 1230 1112 --housing 1197 1081 1228 1112 --housing 1199 1079 1230 1110 &
wait
FAIL=0
[ -e "$TMP/failed" ] && FAIL=1
rm -rf "$TMP"
exit $FAIL
