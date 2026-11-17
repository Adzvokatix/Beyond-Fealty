#!/bin/bash
# What a frame costs: GPU milliseconds at fixed views of seed 1, 1280 x 720,
# the default view radius, averaged over the frames after the view has
# filled (the game's own "after the fill" line).  The first four are like
# the views every look has been costed at since 2026-11-10 (their command
# lines were never kept: these are fixed from 2026-11-11, and read within
# a tenth of a millisecond of the figures then written down); the rest
# look at the sky, at water and at weather, which the first four never
# see (at the default tilt no sky is on screen).
#   tools/look_cost.sh [extra game options]      e.g. --msaa 0, --flatclouds
#     BIN=path       another build (a worktree of main, for before and after)
#     SHOTS=dir      keep each view's last frame there
#     ONLY=name      one view
# A measurement, not a pass/fail check: it needs a window.  Figures move
# by a few hundredths of a millisecond from run to run.
cd "$(dirname "$0")/.." || exit 1
BIN=${BIN:-./bin/castle_game}
TMP=$(mktemp -d)
BASE="--float --size 1280 720 --hud none --novsync --seed 1 --mouse 2 2 --frames 2500"
BAND="--stake 1178 1078 --path 1176 1076 1194 1076 --stockpile 1180 1070 1190 1075
      --gatherers 2 --foresters 1 --hunters 2 --cooks 1 --camp 1172 1082 --camp-built --paths-built"
EXTRA=("$@")

view() {  # NAME OPTIONS...
  local name=$1; shift
  [ -n "$ONLY" ] && [ "$ONLY" != "$name" ] && return
  "$BIN" $BASE "$@" "${EXTRA[@]}" --shot "$TMP/$name.png" > "$TMP/$name.log" 2>&1 \
    || { echo "$name: failed"; tail -3 "$TMP/$name.log"; return; }
  local gpu quads
  # (once nothing more is coming in, where the build says so: the whole map held, the far view whole)
  gpu=$(sed -n 's/^settled .*frames, gpu \([0-9.]*\) ms.*/\1/p' "$TMP/$name.log")
  [ -z "$gpu" ] && gpu=$(sed -n 's/^after the fill:.* gpu \([0-9.]*\) ms.*/\1/p' "$TMP/$name.log")
  quads=$(sed -n 's/^view filled.* stacks, *\([0-9]*\) quads.*/\1/p' "$TMP/$name.log")
  printf "%-16s %6s ms   %9s quads\n" "$name" "$gpu" "$quads"
  grep -i "render:" "$TMP/$name.log"
  [ -n "$SHOTS" ] && mkdir -p "$SHOTS" && cp "$TMP/$name.png" "$SHOTS/$name.png"
}

DAYLIGHT="--day 20 --time 11 --weather clear"
view meadow       $DAYLIGHT --at 1190 1085
view forest       $DAYLIGHT --at 1139 1027 --cam 1.2 1.2 26
view camp_day     $DAYLIGHT $BAND --at 1176 1080
view camp_night   --day 20 --time 23 --weather clear $BAND --stoke 8 --at 1176 1080
view horizon      --day 20 --time 15 --weather cloudy --at 1197 1063 --cam 2.4 0.14 20
view horizon_dusk --day 20 --time 19.6 --weather cloudy --at 1197 1063 --cam 0.2 0.14 20
view horizon_night --day 20 --time 1 --weather clear --at 1197 1063 --cam 2.4 0.14 20
view lake         --day 20 --time 16 --weather cloudy --at 1203 1374 --cam 0.7 0.3 24
view rain         --day 20 --time 11 --weather rain $BAND --at 1176 1080
view rain_low     --day 20 --time 11 --weather rain $BAND --at 1176 1080 --cam 2.4 0.2 14
view snow_low     --day 52 --time 14.5 --weather snow --at 1184 1040 --cam 0.963 0.12 12
view overcast     --day 20 --time 11 --weather storm --at 1197 1063 --cam 2.4 0.14 20
rm -rf "$TMP"
