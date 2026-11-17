#!/bin/bash
# The water demo (water_drawdown.mp4): source water that drops beside a cut
# and comes back.  The mountain lake of seed 1 at its west rim, at dusk.
#   1. the lake as it lies (2 s);
#   2. a cut 2 m wide and 1.7 m deep dug through the rim: the lake drops
#      beside it and runs out, the drop fading into the lake (18 s);
#   3. the cut closed with planks: nothing climbs onto them, the lake comes
#      back to its level, what is out runs off (15 s);
#   4. the same cut from outside the rim, the water coming down it (18 s);
#   5. the hollow at 1311, 1465 that was a dry lake bed, now a tarn (4 s).
#   tools/demo_water.sh [OUT.mp4]     needs ffmpeg; writes 1,710 frames (about 5 GB)
#                                     to a temporary folder and deletes them after
cd "$(dirname "$0")/.." || exit 1
OUT=${1:-water_drawdown.mp4}
TMP=$(mktemp -d)
LOOK="--float --size 1280 720 --view 128 --hud none --time 17.5 --clouds 0.2 --novsync"
LAKE="--at 1203 1374 --cam 0.7 0.55 16"
CUT="--dig 1186 1373 85.5 1206 1375 94 --late"

./bin/castle_game $LOOK $LAKE --record "$TMP/a" 60 > /dev/null || exit 1
./bin/castle_game $LOOK $LAKE $CUT --record "$TMP/b" 540 --save "$TMP/cut.castle" > /dev/null || exit 1
./bin/castle_game $LOOK --load "$TMP/cut.castle" --fill 1202 1373 85.5 1204 1375 88.5 \
  --record "$TMP/c" 450 > /dev/null || exit 1
./bin/castle_game $LOOK --time 16.5 --at 1188 1374 --cam 2.5 0.5 20 $CUT --record "$TMP/d" 540 > /dev/null || exit 1
./bin/castle_game $LOOK --at 1311 1465 --cam 2.6 0.45 70 --time 16 --record "$TMP/e" 120 > /dev/null || exit 1

for c in a b c d e; do
  ffmpeg -y -loglevel error -framerate 30 -start_number 1 -i "$TMP/$c/frame_%04d.png" \
    -c:v libx264 -preset slow -crf 22 -pix_fmt yuv420p "$TMP/$c.mp4" || exit 1
  rm -rf "$TMP/$c"
  printf "file '%s'\n" "$TMP/$c.mp4" >> "$TMP/list.txt"
done
ffmpeg -y -loglevel error -f concat -safe 0 -i "$TMP/list.txt" -c copy -movflags +faststart "$OUT"
rm -rf "$TMP"
echo "wrote $OUT"
