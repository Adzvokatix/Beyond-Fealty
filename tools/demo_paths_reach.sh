#!/bin/bash
# The paths and reach demo (paths_and_reach.mp4), seed 1 at the reference
# stake, about forty seconds:
#   1. a path planned with a scripted pointer, two stretches from the stake,
#      and a stockpile zoned along it while it is still only planned; the
#      band lays the path a metre at a time, the clock at four times (15 s);
#   2. the first morning from high above, the clock at thirty times: a path
#      planned 150 m out to the east, the camp built first, then the path
#      laid outward from the stake (the colony's ground reaching as far as
#      the path does) (14 s);
#   3. the same morning with no stone taken from within 150 m of the stake
#      (--stone-from 150): the band looks further, ring by ring, and two
#      walk out for it; the camp's sheet says how far they are looking (12 s).
#   tools/demo_paths_reach.sh [OUT.mp4]   needs ffmpeg; writes 1,230 frames (about 3 GB)
#                                         to a temporary folder, a part at a time, and deletes them
cd "$(dirname "$0")/.." || exit 1
OUT=${1:-paths_and_reach.mp4}
TMP=$(mktemp -d)
LOOK="--float --size 1280 720 --novsync --seed 1 --day 20 --weather clear"
BAND="--stake 1178 1078 --path 1176 1076 1194 1076 --stockpile 1180 1070 1190 1075 --camp 1172 1082
      --gatherers 2 --foresters 1 --hunters 2 --cooks 1 --all-hands --no-level"

part() {  # NAME FRAMES OPTIONS...
  local name=$1 n=$2; shift 2
  mkdir -p "$TMP/$name"
  ./bin/castle_game $LOOK "$@" --record "$TMP/$name" "$n" > "$TMP/$name.log" 2>&1 || { tail -5 "$TMP/$name.log"; exit 1; }
  ffmpeg -y -loglevel error -framerate 30 -start_number 1 -i "$TMP/$name/frame_%04d.png" \
    -c:v libx264 -preset slow -crf 23 -pix_fmt yuv420p "$TMP/$name.mp4" || exit 1
  rm -rf "$TMP/$name"
  printf "file '%s'\n" "$TMP/$name.mp4" >> "$TMP/list.txt"
}

part a 450 --stake 1178 1078 --all-hands --hud noband --time 9 --speed 4 --at 1184 1074 --cam 0.0 1.1 26 \
  --pointer "20:ground 1176 1076, 50:rclick, 51:rel 150 54, 80:click, 90:ground 1188 1076, 130:click, 140:ground 1195 1071, 180:click, 200:esc, 220:ground 1180 1074.5, 250:rclick, 251:rel 150 79, 280:click, 290:ground 1186 1071, 340:click, 360:move 640 120"
part b 420 $BAND --path 1194 1076 1330 1076 --hud none --time 7 --speed 30 --at 1235 1076 --cam 0.0 1.2 95 --mouse 2 2
part c 360 $BAND --stone-from 150 --hud none --time 7 --speed 30 --at 1172 1082 --cam 0.5 0.75 15 --pointer "20:ground 1174.8 1084.8"

ffmpeg -y -loglevel error -f concat -safe 0 -i "$TMP/list.txt" -c copy -movflags +faststart "$OUT"
rm -rf "$TMP"
echo "wrote $OUT"
