#!/bin/bash
# The reference run: seed 1, the reference stake and camp, the standard band
# (two gatherers, a forester, two hunters, a cook), nothing stored, from
# summer's fifth day at seven.  reference_run.sh [DAYS] [extra colony_run options]
cd "$(dirname "$0")/.." || exit 1
DAYS=${1:-5}; shift
exec ./bin/colony_run --seed 1 --stake 1178 1078 --path 1176 1076 1194 1076 \
  --stockpile 1180 1070 1190 1075 --camp 1172 1082 \
  --gatherers 2 --foresters 1 --hunters 2 --cooks 1 \
  --day 20 --time 7 --days "$DAYS" --log-hours 24 "$@"
