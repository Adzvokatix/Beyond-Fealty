#!/bin/bash
# The demo of the lord's cart pulled into a stockpile, the cloaks of cloth
# and roofs cleared on the camera's ray (colony_cart_and_cloaks.mp4), seed 1
# by the reference stake, about a minute:
#   a. the cart pulled from beside the stake across the path into the
#      stockpile, set down on two of its places; twenty game minutes at four
#      times (11 s);
#   b. the band's first minutes close up: each in its cloak of cloth, swinging
#      as it walks and carries (7 s);
#   c. the first beds made: the cloak taken off and let fall by the bed, its
#      owner gone on without it; ten game minutes at twice (10 s);
#   d. that night, the cloaks laid over the sleepers by the fire (10 s);
#   e. the same night with --no-cloth: the cloaks as they were (5 s);
#   f. six hovels by day, the camera on one: its roof cleared, open in the
#      middle and half drawn where it meets its walls (5 s);
#   g. the same at the default view (4 s);
#   h. that night, its owner asleep inside under its cloak, seen through
#      the cleared roof by the moon (5 s; brightened threefold here: on the
#      screen the inside of a hovel at night is that much darker);
#   i. the pointer taken along six hovels, the camera looking at none: each
#      roof clears under it and comes back (8 s);
#   j. three streets, 26 hovels, every house open (the H key's second
#      view; --all-roofs here) (4 s);
#   k. from low down before a hovel, the camera looking at the ground
#      before it: the pointer put on its near wall, the wall fades and the
#      room is seen through it (5 s);
#   l. a hovel looked at from low down and from its corner: the two walls
#      on the camera's side gone with the roof (4 s).
#   tools/demo_cart_and_cloaks.sh [OUT.mp4]   needs ffmpeg; writes about 2,600 frames (some 6 GB)
#                                             to a temporary folder, a part at a time, and deletes them
cd "$(dirname "$0")/.." || exit 1
OUT=${1:-colony_cart_and_cloaks.mp4}
TMP=$(mktemp -d)
LOOK="--float --size 1280 720 --novsync --seed 1 --day 20"
WEST="--stake 1178 1078 --path 1176 1076 1194 1076 --path 1176 1076 1140 1076 --stockpile 1180 1070 1190 1075
      --camp 1172 1082 --camp-built --paths-built"
BAND="--band 6 --gatherers 2 --foresters 1 --porters 1 --hunters 1 --cooks 1"
HOMES="--stake 1178 1078 --path 1176 1076 1194 1076 --path 1176 1076 1140 1076 --housing 1141 1077 1167 1087
       --housing 1141 1075 1175 1065 --stockpile 1180 1070 1190 1075 --stockpile 1180 1077 1190 1082
       --camp 1172 1082 --camp-built --paths-built --homes-built"

part() {  # NAME FRAMES SKIP OPTIONS...
  local name=$1 n=$2 skip=$3; shift 3
  mkdir -p "$TMP/$name"
  ./bin/castle_game $LOOK "$@" --record "$TMP/$name" $((n + skip)) > "$TMP/$name.log" 2>&1 || { tail -5 "$TMP/$name.log"; exit 1; }
  ffmpeg -y -loglevel error -framerate 30 -start_number $((skip + 1)) -i "$TMP/$name/frame_%04d.png" \
    ${VF:+-vf "$VF"} -c:v libx264 -preset slow -crf 23 -pix_fmt yuv420p "$TMP/$name.mp4" || exit 1
  rm -rf "$TMP/$name"
  printf "file '%s'\n" "$TMP/$name.mp4" >> "$TMP/list.txt"
}

part a 330 0 $WEST $BAND --weather clear --time 7 --speed 4 --hud none --mouse 2 715 --at 1181 1078 --cam 4.4 0.8 14
part b 210 0 $WEST $BAND --weather clear --time 7 --speed 1 --hud none --mouse 2 715 --at 1176 1080 --cam 4.4 0.45 6
part c 300 0 $WEST $BAND --weather clear --time 7.1 --speed 2 --hud none --mouse 2 715 --at 1172 1082 --cam 4.4 0.6 9
./bin/colony_run --seed 1 $WEST $BAND --day 20 --time 7 --days 0.666667 --save "$TMP/night.castle" > "$TMP/night.log" 2>&1 \
  || { tail -5 "$TMP/night.log"; exit 1; }
part d 300 600 --load "$TMP/night.castle" --weather clear --speed 1 --moon 1 --hud none --mouse 2 715 --at 1172 1082 --cam 4.4 0.7 8
part e 150 600 --load "$TMP/night.castle" --no-cloth --weather clear --speed 1 --moon 1 --hud none --mouse 2 715 \
  --at 1172 1082 --cam 4.4 0.7 8
part f 150 0 $HOMES --weather clear --time 10 --speed 1 --hud none --mouse 2 715 --at 1150 1071 --cam 4.4 1.05 14
part g 120 0 $HOMES --weather clear --time 10 --speed 1 --hud none --mouse 2 715 --at 1150 1071
./bin/colony_run --seed 1 $HOMES --supply berries 400 --supply straw 12 --day 20 --time 7 --days 0.666667 \
  --save "$TMP/homes.castle" > "$TMP/homes.log" 2>&1 || { tail -5 "$TMP/homes.log"; exit 1; }
VF="colorlevels=rimax=0.33:gimax=0.33:bimax=0.33" \
part h 150 450 --load "$TMP/homes.castle" --weather clear --speed 1 --moon 1 --hud none --mouse 1270 710 \
  --at 1150 1071 --cam 4.4 1.2 7
part i 240 0 $HOMES --weather clear --time 10 --speed 1 --hud none --mouse 2 715 --at 1154 1066 --cam 4.4 1.0 34 \
  --pointer "20:move 490 150, 50:move 610 130, 80:move 725 105, 110:move 810 195, 140:move 690 235, 170:move 540 255, 205:move 900 450"
STREETS="--stake 1178 1078 --path 1176 1076 1194 1076 --path 1176 1076 1140 1076 --housing 1141 1077 1167 1087
         --housing 1141 1075 1175 1065 --path 1196 1104 1120 1104 --housing 1121 1105 1195 1115
         --housing 1121 1103 1195 1093 --path 1196 1050 1120 1050 --housing 1121 1051 1195 1061
         --housing 1121 1049 1195 1039 --stockpile 1180 1070 1190 1075 --camp 1172 1082 --camp-built --paths-built
         --homes-built --band 40"
part j 120 0 $STREETS --all-roofs --weather clear --time 10 --speed 1 --hud none --mouse 2 715 --at 1158 1078 --cam 4.4 1.0 75
part k 150 0 $HOMES --weather clear --time 10 --speed 1 --hud none --mouse 1270 710 --at 1150 1062 --cam 4.71 0.3 14 \
  --pointer "45:move 660 224"
part l 120 0 $HOMES --weather clear --time 10 --speed 1 --hud none --mouse 2 715 --at 1150 1071 --cam 4.4 0.45 12

ffmpeg -y -loglevel error -f concat -safe 0 -i "$TMP/list.txt" -c copy -movflags +faststart "$OUT"
rm -rf "$TMP"
echo "wrote $OUT"
