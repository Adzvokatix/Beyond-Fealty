#!/bin/bash
# The camp and zones demo (camp_and_zones.mp4), seed 1 at the reference
# stake, a little over a minute:
#   1. a stockpile zoned beside a path that runs at an angle, with a scripted
#      pointer: the lot shown as it would be taken while its far corner is
#      chosen (turned to the path, drawn out to its edge, filled in), then
#      taken; a path tried through it is refused (11 s);
#   2. the camp zoned and built by the band, the clock at eight times: the
#      ground made ready from the fire outward, stone and deadwood brought,
#      the hearth standing with its pot, the camp's sheet beside it (18 s);
#   3. the first day from further off, the clock at thirty times: the zones
#      filled in, the stockpile filling, the fire lit (12 s);
#   4. the fire at night burning out and dying down to embers, the clock at
#      thirty times, its sheet counting the hours left to restoke it (10 s);
#   5. the evening of a working day at thirty times: the cook stokes the
#      fire for the night and the band sleeps round it (12 s).
#   tools/demo_camp_zones.sh [OUT.mp4]   needs ffmpeg; writes 1,890 frames (about 5 GB)
#                                        to a temporary folder, a part at a time, and deletes them
cd "$(dirname "$0")/.." || exit 1
OUT=${1:-camp_and_zones.mp4}
TMP=$(mktemp -d)
LOOK="--float --size 1280 720 --novsync --seed 1 --day 20 --weather clear"
SITE="--stake 1178 1078 --path 1176 1076 1194 1076 --path 1176 1076 1166 1070"
BAND="$SITE --stockpile 1180 1070 1190 1075 --stockpile 1170.5 1073.9 1165 1075.3 --camp 1172 1082
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

part a 330 $SITE --hud noband --time 11 --at 1171 1074 --cam 0.0 1.1 26 \
  --pointer "20:ground 1170.5 1073.9, 60:rclick, 61:rel 150 79, 90:click, 100:ground 1165 1075.3, 160:click, 190:ground 1169 1068, 215:rclick, 216:rel 150 54, 240:click, 250:ground 1167 1078, 290:click"
part b 540 $BAND --hud none --time 7 --speed 8 --at 1172 1082 --cam 0.5 0.75 13 --pointer "20:ground 1174.8 1084.8"
part c 360 $BAND --hud none --time 7 --speed 30 --at 1176 1077 --cam 0.4 0.8 30 --mouse 2 2
part d 300 $BAND --hud none --stoke 1.2 --time 21.5 --speed 30 --at 1172 1082 --cam 0.6 0.5 7 --pointer "10:ground 1174.8 1084.2"
part e 360 $BAND --hud none --camp-built --supply wood 12 --supply meat 16 --supply berries 120 \
  --time 16.5 --speed 30 --at 1172.5 1081 --cam 2.5 0.6 11 --mouse 2 2

ffmpeg -y -loglevel error -f concat -safe 0 -i "$TMP/list.txt" -c copy -movflags +faststart "$OUT"
rm -rf "$TMP"
echo "wrote $OUT"
