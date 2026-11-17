#!/bin/bash
# The demo of one who stands still frightening no herd (colony_herds_still.mp4),
# seed 1, the stress runner's crowd of forty-eight on its fifth morning, about
# fifteen seconds: a gatherer left standing with its berries (the one stockpile
# is full) 4 m from a herd of five, which grazes on round it.  (Filmed again on
# generator 14: a moment of a history, found with colony_run --who.)  Until
# 2026-11-14 anyone within 15 m frightened a herd again every three seconds,
# walking or not, and no herd was ever seen so.  (John: "a person standing still
# doesn't frighten a herd".)  For a herd frightened by someone who comes on, and
# its flight in a chain: tools/demo_herd_chain.sh.
#   tools/demo_herds_still.sh [OUT.mp4]   needs ffmpeg; writes about 480 frames (some 1.2 GB) to a
#                                         temporary folder and deletes them
cd "$(dirname "$0")/.." || exit 1
OUT=${1:-colony_herds_still.mp4}
TMP=$(mktemp -d)
CROWD="--seed 1 --stake 1178 1078 --path 1176 1076 1194 1076 --stockpile 1180 1070 1190 1075 --camp 1172 1082
       --band 48 --gatherers 14 --foresters 6 --porters 8 --hunters 8 --cooks 2 --no-needs --no-demand"
# (half past ten on the fifth day: 99.5 hours from seven, a save on a rebuild)
./bin/colony_run $CROWD --day 20 --time 7 --days 4.1458333 --log-hours 1440 --save "$TMP/herd.castle" > "$TMP/run.log" 2>&1 \
  || { tail -5 "$TMP/run.log"; exit 1; }
mkdir -p "$TMP/f"
./bin/castle_game --float --size 1280 720 --novsync --load "$TMP/herd.castle" --weather clear --speed 1 --hud none \
  --mouse 2 715 --at 1158.5 1043.7 --cam 4.4 0.9 17 --record "$TMP/f" 480 > "$TMP/game.log" 2>&1 || { tail -5 "$TMP/game.log"; exit 1; }
ffmpeg -y -loglevel error -framerate 30 -start_number 31 -i "$TMP/f/frame_%04d.png" \
  -c:v libx264 -preset slow -crf 23 -pix_fmt yuv420p -movflags +faststart "$OUT" || exit 1
rm -rf "$TMP"
echo "wrote $OUT"
