#!/bin/bash
# The demo of a herd's flight in a chain (colony_herd_chain.mp4), seed 1, the
# reference band on its second morning, about ten seconds: a herd of five on
# the hillside north-east of the stake at six minutes to eleven, a hunter
# 15 m south of it; the deer nearest him sets off, each next a moment after
# the one before, and they run west with their node, none off on its own.
# (Filmed again on generator 14: the world's boulders changed, and with them
# the band's days.  A moment of a history: after any change to the world or
# to what the band does, find it again with colony_run --who, which says
# where each herd is, whether it is in flight and who is nearest.)
#   tools/demo_herd_chain.sh [OUT.mp4]   needs ffmpeg; writes about 900 frames (some 2 GB) to a
#                                        temporary folder and deletes them
cd "$(dirname "$0")/.." || exit 1
OUT=${1:-colony_herd_chain.mp4}
TMP=$(mktemp -d)
REF="--seed 1 --stake 1178 1078 --path 1176 1076 1194 1076 --stockpile 1180 1070 1190 1075 --camp 1172 1082
     --gatherers 2 --foresters 1 --hunters 2 --cooks 1 --winter-store 10 --reserve meat 60"
# (half past ten the next day: 28.5 hours from six, a save on a rebuild; the flight begins 23 s on)
./bin/colony_run $REF --day 20 --time 6 --days 1.1875 --log-hours 1440 --save "$TMP/herd.castle" > "$TMP/run.log" 2>&1 \
  || { tail -5 "$TMP/run.log"; exit 1; }
mkdir -p "$TMP/f"
./bin/castle_game --float --size 1280 720 --novsync --load "$TMP/herd.castle" --weather clear --speed 1 --hud none \
  --mouse 2 715 --at 1205 1130 --cam 4.4 0.9 27 --record "$TMP/f" 900 > "$TMP/game.log" 2>&1 || { tail -5 "$TMP/game.log"; exit 1; }
ffmpeg -y -loglevel error -framerate 30 -start_number 601 -i "$TMP/f/frame_%04d.png" \
  -c:v libx264 -preset slow -crf 23 -pix_fmt yuv420p -movflags +faststart "$OUT" || exit 1
rm -rf "$TMP"
echo "wrote $OUT"
