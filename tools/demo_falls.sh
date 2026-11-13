#!/bin/bash
# The demo of falls drawn as sheets thrown from the lip (falls.mp4), seed 1,
# the mountain lake at 1203 1374, about half a minute.  Two cuts out of the
# lake, each with its flow established (700 water ticks run before the first
# frame), each as it was drawn before (--nofalls) and as it is now:
#   1. a cut 3 m wide onto the hillside as it lies: the stream down the
#      slope, a film on every step before, a body of water standing off the
#      slope and rolling over itself now (4 s and 6 s);
#   2. the same cut onto a cliff 3 m high, cut into the hillside: the
#      curtain flat against the wall before, the arch standing clear of it
#      and going into its pool now (3 s and 5 s);
#   3. the arch from the side, where the curtain could not be seen at all
#      (before and after, 2 s and 4 s), and from low down, the eye below the
#      lip (4 s).
#   tools/demo_falls.sh [OUT.mp4]   needs ffmpeg; writes about 850 frames (2.5 GB)
#                                   to a temporary folder, a part at a time, and deletes them
cd "$(dirname "$0")/.." || exit 1
OUT=${1:-falls.mp4}
TMP=$(mktemp -d)
LOOK="--float --size 1280 720 --novsync --seed 1 --hud none --mouse 2 2 --view 96 --day 20 --time 13 --weather clear"
CUT="--dig 1190 1372.5 86.0 1206 1375.5 97"
CLIFF="--dig 1184 1366 83.5 1190 1382 97"
# Not in the demo, kept for looking at a slope like the one in John's pictures: a stair of one in one,
# half-metre steps, cut under the same slot down to a floor (seven boxes; with the cut, the eight a run takes):
#   ./bin/castle_game $LOOK $STAIR $CUT --late --simticks 700 --at 1187.5 1374 --cam 3.14 0.28 8 --frames 60 --shot stair.png
STAIR="--dig 1189.5 1371 85.5 1190 1377 97 --dig 1189 1371 85.0 1189.5 1377 97 --dig 1188.5 1371 84.5 1189 1377 97
       --dig 1188 1371 84.0 1188.5 1377 97 --dig 1187.5 1371 83.5 1188 1377 97 --dig 1187 1371 83.0 1187.5 1377 97
       --dig 1183 1371 82.5 1187 1377 97"

part() {  # NAME FRAMES OPTIONS...: frames 3 .. FRAMES + 2 of the run (the first is before the cut)
  local name=$1 n=$2; shift 2
  mkdir -p "$TMP/$name"
  ./bin/castle_game $LOOK "$@" --late --simticks 700 --record "$TMP/$name" $((n + 2)) > "$TMP/$name.log" 2>&1 \
    || { tail -5 "$TMP/$name.log"; exit 1; }
  ffmpeg -y -loglevel error -framerate 30 -start_number 3 -i "$TMP/$name/frame_%04d.png" \
    -c:v libx264 -preset slow -crf 22 -pix_fmt yuv420p "$TMP/$name.mp4" || exit 1
  rm -rf "$TMP/$name"
  printf "file '%s'\n" "$TMP/$name.mp4" >> "$TMP/list.txt"
}

part a0 120 $CUT --at 1187 1374 --cam 3.14 0.3 9 --nofalls
part a  180 $CUT --at 1187 1374 --cam 3.14 0.3 9
part b0  90 $CLIFF $CUT --at 1188 1374 --cam 3.4 0.22 8 --nofalls
part b  150 $CLIFF $CUT --at 1188 1374 --cam 3.4 0.22 8
part c0  60 $CLIFF $CUT --at 1188.5 1374 --cam 1.57 0.22 7 --nofalls
part c  120 $CLIFF $CUT --at 1188.5 1374 --cam 1.57 0.22 7
part d  120 $CLIFF $CUT --at 1186.5 1374 --cam 3.14 0.13 6 --pan 0.3 0.6

ffmpeg -y -loglevel error -f concat -safe 0 -i "$TMP/list.txt" -c copy -movflags +faststart "$OUT"
rm -rf "$TMP"
echo "wrote $OUT"
