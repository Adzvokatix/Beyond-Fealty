#!/bin/bash
# Do the shadows hold still?  A still view of the meadow by the reference
# stake (seed 1, 1190 1085, trees and a terraced slope), in clear weather at
# nine in the morning with the clock running: 200 frames a thirtieth of a
# second apart, and how much the last 60 change from one to the next
# (tools/frame_change.py).  Nothing in the view moves but the sun, so what
# changes is the shadows.
#   tools/shadow_still.sh [extra game options]
#     --timescale 0.05   three game minutes a second (the default is one)
#     --time 18.5        dusk, the sun low
#     --timescale 0      the clock stopped: nothing may change at all
#     --noshadows        the floor: only the light itself changes
# With HEAT=file.png it also writes where the picture changed, with
# VERBOSE=-v every frame's change, with BIN=path it runs another build.  As measured
# on 2026-11-10 (RX 6900 XT, 1280 x 720): before the maps were held, mean
# step 0.30 and 5.8 % of pixels stepping by more than 6 levels between two
# frames at least once in the 60; after, 0.017 and none; with no shadows
# 0.006.  A measurement, not a pass/fail check: it
# needs a window, ffmpeg is not used, python3 needs numpy and Pillow.
cd "$(dirname "$0")/.." || exit 1
BIN=${BIN:-./bin/castle_game}
TMP=$(mktemp -d)
"$BIN" --float --size 1280 720 --hud none --novsync --seed 1 --day 20 --time 9 --weather clear \
  --at 1190 1085 --cam 2.5 0.7 30 --mouse 2 2 --record "$TMP" 200 "$@" > "$TMP/log.txt" 2>&1 \
  || { tail -5 "$TMP/log.txt"; rm -rf "$TMP"; exit 1; }
python3 tools/frame_change.py "$TMP" $HEAT $VERBOSE
rm -rf "$TMP"
