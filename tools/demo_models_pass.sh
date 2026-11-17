#!/bin/bash
# The demo of the last pass before stage 6 (models_pass.mp4), seed 1 by the
# reference stake, about seventy seconds:
#   1. a row of seven, every job, rounded and tapered; then three of them
#      from behind: the gatherer's basket, the hunter's bow across his back
#      and his quiver on his hip, the forester's axe at hers (6 s);
#   2. the hunter stalking with the bow in hand, then drawing it, an arrow
#      on the string; the forester's stroke (9 s);
#   3. deer of every class (3 s);
#   4. grass: a meadow close to, its tufts leaning, its long grass in
#      drifts, its steps banks of turf; a stand of wild grain (7 s);
#   5. the trees of generator 13: the forest's edge from the meadow, the
#      canopy from above, the default view, the same in autumn, bare
#      boughs in winter (17 s);
#   6. the reference path and the camp's trodden floor, their edges ragged,
#      the band about its work, the clock at four times (8 s);
#   7. a herd startled by the band going out: it flees together and settles
#      where its node stops; the camera on one of its deer, the clock at
#      twice (15 s).
#   tools/demo_models_pass.sh [OUT.mp4]   needs ffmpeg; writes about 2,100 frames (5 GB)
#                                         to a temporary folder, a part at a time, and deletes them
cd "$(dirname "$0")/.." || exit 1
OUT=${1:-models_pass.mp4}
TMP=$(mktemp -d)
LOOK="--float --size 1280 720 --novsync --seed 1 --day 20 --weather clear --hud none --mouse 2 2"
BAND="--stake 1178 1078 --path 1176 1076 1194 1076 --stockpile 1180 1070 1190 1075
      --gatherers 2 --foresters 1 --hunters 2 --cooks 1 --camp 1172 1082 --camp-built --paths-built"

part() {  # NAME FIRST FRAMES OPTIONS...: frames FIRST .. FIRST + FRAMES - 1 of the run
  local name=$1 first=$2 n=$3; shift 3
  mkdir -p "$TMP/$name"
  ./bin/castle_game $LOOK "$@" --record "$TMP/$name" $((first + n - 1)) > "$TMP/$name.log" 2>&1 \
    || { tail -5 "$TMP/$name.log"; exit 1; }
  ffmpeg -y -loglevel error -framerate 30 -start_number "$first" -i "$TMP/$name/frame_%04d.png" \
    -c:v libx264 -preset slow -crf 26 -pix_fmt yuv420p "$TMP/$name.mp4" || exit 1
  rm -rf "$TMP/$name"
  printf "file '%s'\n" "$TMP/$name.mp4" >> "$TMP/list.txt"
}

part a 1 90 --at 1176 1080 --cam 2.9 0.25 6.5 --lineup 7 --time 11
part b 1 90 --at 1176 1080 --cam 2.9 0.25 3.4 --lineup 3 --lineup-turn 2.7 --time 11
part c 1 90 --at 1176 1080 --cam 2.9 0.2 3.2 --lineup 2 --lineup-turn 1.0 --lineup-does sneak --time 11
part d 1 90 --at 1176 1080 --cam 2.9 0.2 3.2 --lineup 2 --lineup-turn 1.0 --lineup-does aim --time 11
part e 1 90 --at 1176 1080 --cam 2.9 0.2 3.2 --lineup 2 --lineup-turn -1.2 --lineup-does chop --time 11
part f 1 90 --at 1176 1080 --cam 2.9 0.3 6 --deer 6 --time 11
part g 1 110 --at 1190 1085 --cam 2.4 0.25 4 --time 11 --pan 4 3
part g2 1 100 --at 1266 1025 --cam 2.4 0.3 7 --time 11 --pan 4 0
part h 1 130 --at 1197 1063 --cam 2.4 0.16 20 --time 15 --pan 12 0
part h2 1 100 --at 1139 1027 --cam 1.2 0.6 22 --time 15 --pan 6 6
part h3 1 100 --at 1190 1085 --time 11 --pan 12 6
part h4 1 90 --at 1190 1085 --time 11 --day 36 --pan 12 6
part h5 1 90 --at 1197 1063 --cam 2.4 0.16 20 --time 12 --day 55 --pan 8 0
part i 30 120 $BAND --time 8 --speed 4 --at 1186 1077 --cam 1.9 0.8 9
part j 30 120 $BAND --time 8 --speed 4 --at 1172.5 1081.5 --cam 2.6 0.7 8
part k 150 450 $BAND --time 9 --speed 2 --follow-deer --cam 2.4 0.75 17

ffmpeg -y -loglevel error -f concat -safe 0 -i "$TMP/list.txt" -c copy -movflags +faststart "$OUT"
rm -rf "$TMP"
echo "wrote $OUT"
