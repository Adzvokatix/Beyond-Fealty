#!/bin/bash
# The demo of the sky and the weather's look (sky_and_weather.mp4), seed 1,
# about fifty seconds:
#   1. fair-weather clouds over the forest from a rise, the camera gliding:
#      heaps with flat floors and lit sides, fading into the horizon (4 s);
#   2. a sunset from the same rise, the clock at twelve game minutes a
#      second: the sun's disc orange on the horizon, the clouds lit from
#      below after it has gone (8 s);
#   3. the moon coming up opposite, behind the clouds and out of them (5 s);
#   4. the winter sky in falling snow, the sun a pale patch in the cloud
#      where it was a dark disc; then the low winter sun among broken
#      cloud (6 s);
#   5. rain on the band's camp from the usual view, then close: the earth
#      dark, water standing on the path and the camp's floor (7 s);
#   6. the sun out on wet ground, the pools with the sky in them (4 s);
#   7. mist before dawn at the forest's edge, the sun coming up through it;
#      the same mist from the rise, the crowns standing out of it; and over
#      the mountain lake (11 s);
#   8. sixty-four fires on the meadow at night, from above and from low
#      down (6 s).
#   tools/demo_sky_weather.sh [OUT.mp4]   needs ffmpeg; writes about 1,500 frames (4 GB)
#                                         to a temporary folder, a part at a time, and deletes them
cd "$(dirname "$0")/.." || exit 1
OUT=${1:-sky_and_weather.mp4}
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
    -c:v libx264 -preset slow -crf 24 -pix_fmt yuv420p "$TMP/$name.mp4" || exit 1
  rm -rf "$TMP/$name"
  printf "file '%s'\n" "$TMP/$name.mp4" >> "$TMP/list.txt"
}

part a 1 120 $RISE --cam 5.5 0.12 80 --day 20 --time 15 --clouds 0.35 --pan 10 6
part b 1 240 $RISE --cam -0.7 0.12 80 --day 20 --time 18.7 --clouds 0.4 --timescale 0.2
part c 1 150 $RISE --cam 2.356 0.12 80 --day 20 --time 20.4 --clouds 0.3 --timescale 0.2
part d 1 90 $RISE --cam 0.963 0.12 80 --day 52 --time 14.3 --weather snow
part d2 1 90 $RISE --cam 0.963 0.12 80 --day 52 --time 14.3 --weather cloudy --timescale 0.05
part e 30 90 $BAND --day 20 --time 11 --weather rain --at 1176 1080
part e2 30 120 $BAND --day 20 --time 11 --weather rain --at 1173 1080.5 --cam 1.2 0.4 6 --pan 3 -1
part f 30 120 $BAND --day 20 --time 15 --clouds 0.4 --wet 1 --at 1172.5 1081.5 --cam 1.2 0.28 7 --pan 5 -3
part g 1 150 --at 1197 1063 --cam 2.4 0.14 20 --day 20 --time 4.2 --weather clear --mist 0.9 --timescale 0.25
part g2 1 90 $RISE --cam 5.5 0.12 80 --day 20 --time 6 --weather clear --mist 1 --pan 8 5
part g3 1 90 --at 1311 1465 --cam 2.6 0.2 70 --day 20 --time 6.5 --weather clear --mist 0.7 --pan -6 -6
part h 1 90 --at 1190 1085 --day 20 --time 23 --weather clear --lights 64
part h2 1 90 --at 1190 1085 --cam 2.4 0.2 26 --day 20 --time 23 --weather clear --lights 64 --pan 6 4

ffmpeg -y -loglevel error -f concat -safe 0 -i "$TMP/list.txt" -c copy -movflags +faststart "$OUT"
rm -rf "$TMP"
echo "wrote $OUT"
