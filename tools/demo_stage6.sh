#!/bin/bash
# The stage 6a demo (colony_stage6a_habitation.mp4), seed 1 at the
# reference stake with a path laid west over the level ground, about a
# minute:
#   1. housing marked with a scripted pointer: the ground's menu, "Housing
#      from here", the lot shown as it would be taken while its far corner
#      is chosen, the click ("room for 3 hovels"); then the tooltip of the
#      first hovel begun and of the zone (15 s);
#   2. three foresters raising three hovels from wood and straw supplied:
#      the ground levelled, the floors beaten, the frames raised post by
#      post, the daub course by course round the walls, the gables, the
#      thatch; two and a half game days at 120 times, two nights among
#      them (30 s);
#   3. the hamlet built (--homes-built) and slept in: a save from the
#      runner at half past four, then dawn, and each owner out at its own
#      door to the fire (10 s);
#   4. the same hamlet in rain at dusk, and in snow (10 s).
#   tools/demo_stage6.sh [OUT.mp4]   needs ffmpeg; writes about 2,100 frames (some 5 GB)
#                                    to a temporary folder, a part at a time, and deletes them
# (A part begun with --homes-built is recorded sixty frames longer and those
# sixty dropped: the houses' stacks are meshed a moment after the first frame.)
cd "$(dirname "$0")/.." || exit 1
OUT=${1:-colony_stage6a_habitation.mp4}
TMP=$(mktemp -d)
LOOK="--float --size 1280 720 --novsync --seed 1 --day 20"
SITE="--stake 1178 1078 --path 1176 1076 1194 1076 --path 1176 1076 1140 1076 --stockpile 1180 1070 1190 1075
      --camp 1172 1082 --camp-built --paths-built"
ZONES="--housing 1141 1077 1167 1087 --housing 1141 1075 1175 1065"

part() {  # NAME FRAMES SKIP OPTIONS...
  local name=$1 n=$2 skip=$3; shift 3
  mkdir -p "$TMP/$name"
  ./bin/castle_game $LOOK "$@" --record "$TMP/$name" $((n + skip)) > "$TMP/$name.log" 2>&1 || { tail -5 "$TMP/$name.log"; exit 1; }
  ffmpeg -y -loglevel error -framerate 30 -start_number $((skip + 1)) -i "$TMP/$name/frame_%04d.png" \
    -c:v libx264 -preset slow -crf 23 -pix_fmt yuv420p "$TMP/$name.mp4" || exit 1
  rm -rf "$TMP/$name"
  printf "file '%s'\n" "$TMP/$name.mp4" >> "$TMP/list.txt"
}

part a 450 0 $SITE --gatherers 2 --foresters 1 --porters 1 --hunters 1 --cooks 1 --supply wood 30 \
  --weather clear --time 9 --speed 6 --hud noband --at 1158 1080 --cam 4.71 0.9 34 \
  --pointer "20:ground 1166.5 1077.3, 50:rclick, 51:rel 150 118, 80:click, 90:ground 1150 1082, 130:ground 1142 1087, 170:click, 200:ground 1162 1081, 330:ground 1150 1085"
part b 900 0 $SITE --housing 1141 1077 1167 1087 --band 8 --gatherers 2 --foresters 3 --porters 1 --hunters 1 --cooks 1 \
  --supply wood 24 --supply straw 110 --supply berries 400 --supply meat 20 \
  --weather clear --time 5.5 --speed 120 --hud none --mouse 2 2 --at 1155 1080 --cam 4.71 0.62 27
./bin/colony_run --seed 1 $SITE $ZONES --homes-built --gatherers 2 --foresters 1 --porters 1 --hunters 1 --cooks 1 \
  --supply berries 400 --supply meat 20 --supply wood 20 --stoke 6 --day 20 --time 20 --days 0.354166667 \
  --save "$TMP/night.castle" > "$TMP/night.log" 2>&1 || { tail -5 "$TMP/night.log"; exit 1; }
part c 300 30 --load "$TMP/night.castle" --weather clear --speed 12 --hud none --mouse 2 2 --at 1160 1077 --cam 4.71 0.5 24
part d 150 60 $SITE $ZONES --homes-built --gatherers 2 --foresters 1 --porters 1 --hunters 1 --cooks 1 --stoke 6 \
  --weather rain --time 18.6 --speed 2 --hud none --mouse 2 2 --at 1160 1076 --cam 4.4 0.45 30 --pan 6 0
part e 150 60 $SITE $ZONES --homes-built --gatherers 2 --foresters 1 --porters 1 --hunters 1 --cooks 1 --stoke 6 \
  --day 50 --weather snow --snow 0.6 --time 10 --speed 2 --hud none --mouse 2 2 --at 1160 1076 --cam 5.0 0.45 30 --pan -6 0

ffmpeg -y -loglevel error -f concat -safe 0 -i "$TMP/list.txt" -c copy -movflags +faststart "$OUT"
rm -rf "$TMP"
echo "wrote $OUT"
