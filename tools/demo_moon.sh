#!/bin/bash
# The demo of the moon's light, its phases and the stars (moon_and_stars.mp4),
# seed 1, about half a minute:
#   1. a night with no moon from a rise over the forest, the clock at twelve
#      game minutes a second: the stars turning about the pole (5 s);
#   2. the full moon climbing over the same forest, fewer stars by it (4 s);
#   3. a half moon low over the forest, lit from the side the sun went
#      down on; then a waxing moon pale in the afternoon's blue (6 s);
#   4. the winter meadow at ten at night from the usual view, under a full
#      moon and then under none: the snow bright and the trees' shadows on
#      it, and the night as it always was (6 s);
#   5. the same snow from low down, the camera gliding (4 s);
#   6. the band's camp under the full moon, the fire burning: on a summer
#      night, when the moon stands low and the land stays dim, and on a
#      winter one, firelight and moonlight on the snow together (6.5 s).
#   tools/demo_moon.sh [OUT.mp4]   needs ffmpeg; writes about 950 frames (2.5 GB)
#                                  to a temporary folder, a part at a time, and deletes them
cd "$(dirname "$0")/.." || exit 1
OUT=${1:-moon_and_stars.mp4}
TMP=$(mktemp -d)
LOOK="--float --size 1280 720 --novsync --seed 1 --hud none --mouse 2 2"
BAND="--stake 1178 1078 --path 1176 1076 1194 1076 --stockpile 1180 1070 1190 1075
      --gatherers 2 --foresters 1 --hunters 2 --cooks 1 --camp 1172 1082 --camp-built --paths-built"
RISE="--at 1100 1000"

part() {  # NAME FIRST FRAMES OPTIONS...: frames FIRST .. FIRST + FRAMES - 1 of the run
  local name=$1 first=$2 n=$3; shift 3
  mkdir -p "$TMP/$name"
  ./bin/castle_game $LOOK "$@" --record "$TMP/$name" $((first + n - 1)) > "$TMP/$name.log" 2>&1 \
    || { tail -5 "$TMP/$name.log"; exit 1; }
  ffmpeg -y -loglevel error -framerate 30 -start_number "$first" -i "$TMP/$name/frame_%04d.png" \
    -c:v libx264 -preset slow -crf 22 -pix_fmt yuv420p "$TMP/$name.mp4" || exit 1
  rm -rf "$TMP/$name"
  printf "file '%s'\n" "$TMP/$name.mp4" >> "$TMP/list.txt"
}

part a 1 150 $RISE --cam 1.5708 0.12 80 --day 20 --time 23 --weather clear --moon 0 --timescale 0.2
part b 1 120 $RISE --cam 2.2 0.12 80 --day 20 --time 21.2 --weather clear --moon 0.5 --timescale 0.2
part c 1 90 $RISE --cam 0.13 0.12 80 --day 20 --time 23 --weather clear --moon 0.25 --pan 6 4
part c2 1 90 $RISE --cam 2.72 0.12 80 --day 20 --time 15.5 --clouds 0.2 --moon 0.32 --pan 6 4
part d 1 90 --at 1190 1085 --day 52 --time 22 --weather clear --moon 0.5 --timescale 0.05
part d2 1 90 --at 1190 1085 --day 52 --time 22 --weather clear --moon 0
part e 1 120 --at 1197 1063 --cam 2.4 0.14 20 --day 52 --time 22 --weather clear --moon 0.5 --pan 5 3
part f 30 75 $BAND --stoke 8 --day 20 --time 23.6 --weather clear --moon 0.5 --at 1174 1081 --cam 1.2 0.4 14
part f2 30 120 $BAND --stoke 8 --day 50 --time 23 --weather clear --moon 0.5 --at 1174 1081 --cam 1.2 0.4 14

ffmpeg -y -loglevel error -f concat -safe 0 -i "$TMP/list.txt" -c copy -movflags +faststart "$OUT"
rm -rf "$TMP"
echo "wrote $OUT"
