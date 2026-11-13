#!/bin/bash
# The hands and levelling demo (hands_and_level.mp4), seed 1 at the reference
# stake, about forty seconds:
#   1. 58 m of path planned with everyone at a job (the reference band, its
#      camp standing): three stretches, and two hands at most at extra
#      tasks, so two lay a stretch each while the rest go on with their
#      work, and the third stretch waits for one of them; the band's panel
#      says who is at what; the clock at twelve times (15 s);
#   2. the camp marked on a slope of one in eight (1156 1099): its floor
#      levelled as its ground is made ready, the high side dug off and
#      carried into the low, then the hearth and the seats; the clock at
#      thirty times, from seven till three in the afternoon (16 s);
#   3. that camp in the afternoon from the other side, level on the slope,
#      its seat logs laid (5 s); and the stockpile of a camp marked where
#      there was only earth to dig off (1158 1090, 97 blocks): heaped there
#      as earth (5 s).
#   tools/demo_hands_level.sh [OUT.mp4]   needs ffmpeg; writes 1,230 frames (about 3 GB)
#                                         to a temporary folder, a part at a time, and deletes them
cd "$(dirname "$0")/.." || exit 1
OUT=${1:-hands_and_level.mp4}
TMP=$(mktemp -d)
LOOK="--float --size 1280 720 --novsync --seed 1 --day 20 --weather clear"
BAND="--stake 1178 1078 --path 1176 1076 1194 1076 --stockpile 1180 1070 1190 1075
      --gatherers 2 --foresters 1 --hunters 2 --cooks 1"

part() {  # NAME FRAMES OPTIONS...
  local name=$1 n=$2; shift 2
  mkdir -p "$TMP/$name"
  ./bin/castle_game $LOOK "$@" --record "$TMP/$name" "$n" > "$TMP/$name.log" 2>&1 || { tail -5 "$TMP/$name.log"; exit 1; }
  ffmpeg -y -loglevel error -framerate 30 -start_number 1 -i "$TMP/$name/frame_%04d.png" \
    -c:v libx264 -preset slow -crf 23 -pix_fmt yuv420p "$TMP/$name.mp4" || exit 1
  rm -rf "$TMP/$name"
  printf "file '%s'\n" "$TMP/$name.mp4" >> "$TMP/list.txt"
}

part a 450 $BAND --camp 1172 1082 --camp-built --path 1194 1076 1234 1076 --time 9 --speed 12 \
  --at 1206 1076 --cam 0.0 1.05 44 --mouse 2 2
part b 480 $BAND --camp 1156 1099 --hud none --time 7 --speed 30 --at 1156 1099 --cam 2.2 0.38 11 --mouse 2 2
./bin/colony_run --seed 1 $BAND --camp 1156 1099 --supply wood 8 --day 20 --time 7 --days 0.4 \
  --save "$TMP/slope.castle" > "$TMP/slope.log" 2>&1 || { tail -5 "$TMP/slope.log"; exit 1; }
part c 150 --load "$TMP/slope.castle" --hud none --speed 2 --at 1156 1099 --cam 0.6 0.5 9 --pointer "20:ground 1157.5 1100.5"
./bin/colony_run --seed 1 $BAND --camp 1158 1090 --day 20 --time 7 --days 0.4 \
  --save "$TMP/earth.castle" > "$TMP/earth.log" 2>&1 || { tail -5 "$TMP/earth.log"; exit 1; }
part d 150 --load "$TMP/earth.castle" --hud none --speed 2 --at 1184 1072.5 --cam 0.5 0.75 6 --pointer "20:ground 1183.5 1073.5"

ffmpeg -y -loglevel error -f concat -safe 0 -i "$TMP/list.txt" -c copy -movflags +faststart "$OUT"
rm -rf "$TMP"
echo "wrote $OUT"
