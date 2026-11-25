#!/bin/bash
# The reference run: seed 1, the reference stake and camp, the standard band
# (two gatherers, a forester, two hunters, a cook: six, where thirteen arrive
# in the game since 2026-11-17), nothing stored, from summer's fifth day at
# seven.  reference_run.sh [DAYS] [extra colony_run options]
cd "$(dirname "$0")/.." || exit 1
DAYS=${1:-5}; shift
exec ./bin/colony_run --seed 1 --stake 1178 1078 --path 1176 1076 1194 1076 \
  --stockpile-least 0 --no-overflow --last-places 0 --one-to-a-bush --no-storehouse --no-path-level --no-roof-timbers --no-window-timber --no-reach-out --no-zigzag --no-paths-meet --no-door-meet --no-build-help --no-place-level --no-cart-room --no-step-at-edge --no-steep-refuse --no-wood-reach --no-house-turn --stockpile 1180 1070 1190 1075 --camp 1172 1082 \
  --band 6 --gatherers 2 --foresters 1 --hunters 2 --cooks 1 \
  --day 20 --time 7 --days "$DAYS" --log-hours 24 "$@"
