#!/bin/bash
# The demo of the pass on building and zoning after stage 6a
# (colony_housing_pass.mp4), seed 1 by the reference stake, about two
# minutes and a half, the band at the pace of 2026-11-12 and with all of
# that pass's fourth and fifth rounds on (the lord's cart by the stake in
# every part with a band, roofs thatched from ladders):
#   o. a hovel's lot of level ground with two holes dug in it (--dig): its
#      builder fills them and levels the lot where it lies, then beats the
#      floor and raises the frame; four game hours at 30 times (8 s);
#   p, q. a path laid over holes dug under its line (one column, two, two
#      by two, and a ditch across it running on into the grass either
#      side): first as it was, down into each (--no-path-holes), then with
#      them filled (4 s each);
#   l. the lord's cart: what its tooltip says, then a hunter fetching a
#      sackful of salt from it to the stockpile (11 s);
#   m, n. a roof thatched from a ladder: bout after bout laid from under
#      the front eave, seen from above the path; then, from behind the
#      house, the ladder carried round and the back slope begun; five game
#      hours at 30 times (12 s);
#   a. housing pulled along a path with a scripted pointer: begun beside the
#      path from the ground's menu, the strip shown as it is pulled, the
#      click ("housing zoned: room for N"); then begun again inside it and
#      pulled on to the path's end ("housing extended: ... now"); the zone's
#      tooltip, which says so (15 s);
#   j. four paths round a block: a strip pulled up the inside of the west
#      one and far past its turn (it ends at the road that leads off: none
#      of it across), then "Housing inside these paths" from the ground's
#      menu, which takes the rest of the block round the camp (10 s);
#   k. a path line drawn over the hillside's terraces from the ground's
#      menu, and the paths planned there: each lies on its ground (8 s);
#   b. two foresters building below the hillside path east of the stake,
#      with wood, straw and stone supplied: the ground dug from the path
#      back, the stair to each door, the walls of stone that hold the
#      terraces, the ground between two neighbours made one; then floor,
#      frame, daub and thatch; three game days at 120 times (30 s);
#   c. a roof trimmed: a save from the runner with one roof all but thatched
#      and one half thatched, then five game hours at 30 times (10 s);
#   d, e. the hillside built on both sides of its path (--homes-built), seen
#      from above and, close, the wall that holds a terrace below it (10 s);
#   f. the row above the path from behind: one wall behind three hovels,
#      turning where their backs differ, and the fourth apart, a tree
#      standing between (5 s);
#   g. the band's first morning at a camp on sloping ground: each takes or
#      cuts its straw and makes its bed on a level place of its own, across
#      the way to the fire, its cloak folded beside it; five game hours at
#      30 times (10 s);
#   h. that evening by firelight: they come in and lie down on their beds,
#      on their sides, their faces to the fire, each under its cloak (10 s);
#   i. a row put to sleep in daylight, to be looked at: the pose and the
#      cloaks (4 s).
#   tools/demo_housing_pass.sh [OUT.mp4]   needs ffmpeg; writes about 4,900 frames (some 12 GB)
#                                          to a temporary folder, a part at a time, and deletes them
cd "$(dirname "$0")/.." || exit 1
OUT=${1:-colony_housing_pass.mp4}
TMP=$(mktemp -d)
LOOK="--float --size 1280 720 --novsync --seed 1 --day 20"
WEST="--stake 1178 1078 --path 1176 1076 1194 1076 --path 1176 1076 1140 1076 --stockpile 1180 1070 1190 1075
      --camp 1172 1082 --camp-built --paths-built"
EAST="--stake 1178 1078 --path 1176 1076 1194 1076 --path 1194 1076 1212 1076 --path 1212 1076 1232 1076
      --stockpile 1180 1070 1190 1075 --camp 1172 1082 --camp-built --paths-built"
ROUND="--stake 1178 1078 --path 1176 1076 1140 1076 --path 1140 1076 1140 1100 --path 1140 1100 1176 1100
       --path 1176 1100 1176 1076 --camp 1172 1082 --camp-built --paths-built"
SLOPE="--stake 1178 1078 --path 1176 1076 1194 1076 --stockpile 1180 1070 1190 1075 --camp 1196 1080 --camp-built
       --paths-built"

part() {  # NAME FRAMES SKIP OPTIONS...
  local name=$1 n=$2 skip=$3; shift 3
  mkdir -p "$TMP/$name"
  ./bin/castle_game $LOOK "$@" --record "$TMP/$name" $((n + skip)) > "$TMP/$name.log" 2>&1 || { tail -5 "$TMP/$name.log"; exit 1; }
  ffmpeg -y -loglevel error -framerate 30 -start_number $((skip + 1)) -i "$TMP/$name/frame_%04d.png" \
    -c:v libx264 -preset slow -crf 23 -pix_fmt yuv420p "$TMP/$name.mp4" || exit 1
  rm -rf "$TMP/$name"
  printf "file '%s'\n" "$TMP/$name.mp4" >> "$TMP/list.txt"
}

part o 240 60 $WEST --housing 1141 1077 1167 1077 --band 6 --gatherers 2 --foresters 1 --porters 1 --hunters 1 --cooks 1 \
  --supply wood 30 --supply straw 150 --supply stone 60 --supply berries 3000 --supply meat 100 \
  --dig 1159.75 1081.5 16.25 1168.25 1084.0 17.0 --dig 1162.25 1078.5 16.0 1162.75 1079.0 16.75 \
  --dig 1164.0 1080.5 16.0 1164.25 1081.0 16.75 \
  --weather clear --time 6.5 --speed 30 --hud none --mouse 2 715 --at 1163.5 1080 --cam 4.4 0.5 12
HOLES="--dig 1150.0 1076.0 16.0 1150.25 1076.25 16.75 --dig 1151.5 1075.75 16.0 1152.0 1076.0 16.75
       --dig 1153.0 1076.0 16.0 1153.5 1076.5 16.75 --dig 1155.0 1074.75 16.0 1155.25 1077.25 16.75"
part p 120 60 $WEST $HOLES --no-path-holes --weather clear --time 15 --speed 0 --hud none --mouse 2 715 \
  --at 1152.5 1076 --cam 4.71 0.4 6
part q 120 60 $WEST $HOLES --weather clear --time 15 --speed 0 --hud none --mouse 2 715 --at 1152.5 1076 --cam 4.71 0.4 6
part l 330 0 --stake 1178 1078 --path 1176 1076 1194 1076 --stockpile 1180 1070 1190 1075 --camp 1172 1082 --camp-built \
  --paths-built --gatherers 2 --foresters 1 --porters 1 --hunters 1 --cooks 1 --supply berries 400 --supply wood 12 \
  --supply straw 12 --weather clear --time 9 --speed 2 --hud noband --at 1180.5 1077.5 --cam 4.4 0.75 13 \
  --pointer "15:ground 1178 1082.2, 115:ground 1186 1080"
./bin/colony_run --seed 1 $WEST --housing 1141 1077 1167 1077 --band 6 --gatherers 2 --foresters 1 --porters 1 --hunters 1 --cooks 1 \
  --supply wood 30 --supply straw 150 --supply stone 60 --supply berries 3000 --supply meat 100 --day 20 --time 5.5 \
  --days 1.0625 --save "$TMP/roof.castle" > "$TMP/roof.log" 2>&1 || { tail -5 "$TMP/roof.log"; exit 1; }
part m 200 0 --load "$TMP/roof.castle" --weather clear --speed 30 --hud none --mouse 2 715 --at 1162.5 1079.5 --cam 5.05 1.0 11
part n 160 200 --load "$TMP/roof.castle" --weather clear --speed 30 --hud none --mouse 2 715 --at 1162.5 1081 --cam 1.95 0.9 11
part a 450 0 $WEST --gatherers 2 --foresters 1 --porters 1 --hunters 1 --cooks 1 --supply wood 30 \
  --weather clear --time 9 --speed 6 --hud noband --at 1158 1080 --cam 4.71 0.9 34 \
  --pointer "20:ground 1168 1077.3, 50:rclick, 51:rel 150 118, 80:click, 90:ground 1160 1079, 140:ground 1154 1081, 170:click, 215:ground 1156 1078, 235:rclick, 236:rel 150 118, 260:click, 270:ground 1148 1080, 320:ground 1141 1083, 350:click, 390:ground 1150 1083"
part j 300 0 $ROUND --gatherers 2 --foresters 1 --porters 1 --hunters 1 --cooks 1 \
  --weather clear --time 10 --speed 1 --hud noband --at 1158 1087 --cam 4.71 0.95 44 \
  --pointer "15:ground 1141.6 1097, 40:rclick, 41:rel 150 118, 65:click, 75:ground 1141.6 1086, 120:ground 1141.6 1066, 150:click, 185:ground 1160 1090, 205:rclick, 206:rel 150 150, 235:click, 250:ground 1165 1094"
part k 240 0 --stake 1178 1078 --path 1176 1076 1194 1076 --path 1194 1076 1232 1076 --path 1200 1062 1228 1090 \
  --camp 1172 1082 --camp-built --gatherers 2 --foresters 1 --porters 1 --hunters 1 --cooks 1 \
  --weather clear --time 11 --speed 1 --hud noband --at 1214 1076 --cam 4.34 0.4 26 \
  --pointer "15:ground 1204 1086, 40:rclick, 41:rel 150 54, 65:click, 80:ground 1214 1081, 130:ground 1227 1068, 180:ground 1224 1084, 215:click"
part b 900 0 $EAST --housing 1182 1075.4 1232 1075.4 --band 8 --gatherers 2 --foresters 2 --porters 1 --hunters 2 --cooks 1 \
  --supply wood 40 --supply straw 150 --supply stone 80 --supply berries 2000 --supply meat 60 \
  --weather clear --time 5.5 --speed 120 --hud none --mouse 2 2 --at 1196 1071 --cam 1.45 0.7 19
./bin/colony_run --seed 1 $WEST --housing 1141 1077 1167 1077 --band 8 --gatherers 2 --foresters 3 --porters 1 --hunters 1 --cooks 1 \
  --supply wood 24 --supply straw 110 --supply stone 40 --supply berries 400 --supply meat 20 --day 20 --time 5.5 \
  --days 1.375 --save "$TMP/trim.castle" > "$TMP/trim.log" 2>&1 || { tail -5 "$TMP/trim.log"; exit 1; }
part c 300 30 --load "$TMP/trim.castle" --weather clear --speed 30 --hud none --mouse 2 2 --at 1160 1080 --cam 4.4 0.55 13
part d 150 60 $EAST --housing 1182 1075.4 1232 1075.4 --housing 1182 1077 1232 1077 --homes-built --band 10 \
  --gatherers 3 --foresters 1 --hunters 2 --cooks 1 --stoke 6 \
  --weather clear --time 16 --speed 2 --hud none --mouse 2 2 --at 1204 1073 --cam 1.2 0.6 27 --pan 5 0
part e 150 60 $EAST --housing 1182 1075.4 1232 1075.4 --housing 1182 1077 1232 1077 --homes-built --band 10 \
  --gatherers 3 --foresters 1 --hunters 2 --cooks 1 --stoke 6 \
  --weather clear --time 16 --speed 2 --hud none --mouse 2 2 --at 1222 1071 --cam 4.4 0.45 15 --pan -2 0
part f 150 60 $EAST --housing 1182 1077 1232 1077 --homes-built --band 10 \
  --gatherers 3 --foresters 1 --hunters 2 --cooks 1 --stoke 6 \
  --weather clear --time 13 --speed 2 --hud none --mouse 2 2 --at 1203 1084 --cam 1.57 1.0 14 --pan -2 0
BAND6="--gatherers 2 --foresters 1 --porters 1 --hunters 1 --cooks 1 --supply berries 400 --supply wood 12 --supply straw 6"
part g 300 0 $SLOPE $BAND6 --weather clear --time 7 --speed 30 --hud none --mouse 2 2 --at 1196 1080 --cam 3.9 0.6 11
./bin/colony_run --seed 1 $SLOPE $BAND6 --day 20 --time 7 --days 0.5625 --save "$TMP/night.castle" > "$TMP/night.log" 2>&1 \
  || { tail -5 "$TMP/night.log"; exit 1; }
part h 300 60 --load "$TMP/night.castle" --weather clear --speed 10 --moon 1 --hud none --mouse 2 2 --at 1196 1080 --cam 3.9 0.5 8
part i 120 0 --at 1178 1078 --lineup 6 --lineup-does Sleep --weather clear --time 12 --hud none --mouse 2 2 --cam 0.8 0.8 5 --pan 0.3 0

ffmpeg -y -loglevel error -f concat -safe 0 -i "$TMP/list.txt" -c copy -movflags +faststart "$OUT"
rm -rf "$TMP"
echo "wrote $OUT"
