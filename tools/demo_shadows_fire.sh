#!/bin/bash
# The shadows and fire demo (shadows_and_fire.mp4), seed 1 at the reference
# stake and camp, a minute and a half:
#   1. the meadow's trees at nine in the morning with the clock at three
#      game minutes a second: the shadows travel and nothing flickers (8 s);
#   2. the band setting out from the stake in the morning, each with a
#      shadow, and the stake's, the baskets', the logs' (12 s);
#   3. the same band from across the camp in the late afternoon, the camera
#      gliding 12 m over the ground: long shadows that hold to the ground as
#      it goes (10 s);
#   4. the fire by day, close: flames, sparks, smoke on the wind (8 s);
#   5. late afternoon into night at the camp, the clock at ten times: the
#      sun's shadows lengthen and fade, the fire's take over (16 s);
#   6. the fire at night, close: the light stirring, the posts' shadows
#      and the people's (10 s);
#   7. the camp at night from further off (8 s).
#   tools/demo_shadows_fire.sh [OUT.mp4]   needs ffmpeg; writes 2,160 frames (about 5.5 GB)
#                                          to a temporary folder, a part at a time, and deletes them
cd "$(dirname "$0")/.." || exit 1
OUT=${1:-shadows_and_fire.mp4}
TMP=$(mktemp -d)
LOOK="--float --size 1280 720 --hud none --novsync --seed 1 --day 20 --weather clear --mouse 2 2"
BAND="--stake 1178 1078 --path 1176 1076 1194 1076 --stockpile 1180 1070 1190 1075 --camp 1172 1082 --camp-built --paths-built
      --band 8 --gatherers 2 --foresters 1 --hunters 2 --cooks 1
      --supply meat 16 --supply wood 12 --supply berries 120"

part() {  # NAME FRAMES OPTIONS...
  local name=$1 n=$2; shift 2
  mkdir -p "$TMP/$name"
  ./bin/castle_game $LOOK "$@" --record "$TMP/$name" "$n" > "$TMP/$name.log" 2>&1 || { tail -5 "$TMP/$name.log"; exit 1; }
  ffmpeg -y -loglevel error -framerate 30 -start_number 1 -i "$TMP/$name/frame_%04d.png" \
    -c:v libx264 -preset slow -crf 23 -pix_fmt yuv420p "$TMP/$name.mp4" || exit 1
  rm -rf "$TMP/$name"
  printf "file '%s'\n" "$TMP/$name.mp4" >> "$TMP/list.txt"
}

part a 240 --time 9 --timescale 0.05 --at 1190 1085 --cam 2.5 0.7 30
part b 360 $BAND --time 8 --at 1178 1077 --cam 2.5 0.6 11
part c 300 $BAND --time 17.3 --at 1170 1074 --cam 0.9 0.55 16 --pan 9 8
part d 240 $BAND --stoke 6 --time 14 --at 1172 1082 --cam 2.5 0.4 4.5
part e 480 $BAND --stoke 6 --time 17.7 --speed 10 --at 1172.5 1081 --cam 2.5 0.6 11
part f 300 $BAND --stoke 6 --time 22 --at 1172 1082 --cam 2.5 0.32 3.2
part g 240 $BAND --stoke 6 --time 22 --at 1173 1081 --cam 0.7 0.6 13

ffmpeg -y -loglevel error -f concat -safe 0 -i "$TMP/list.txt" -c copy -movflags +faststart "$OUT"
rm -rf "$TMP"
echo "wrote $OUT"
