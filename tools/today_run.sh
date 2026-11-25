#!/bin/bash
# The game as it is played today, as one run of the runner: every rule at its default.
#
#   tools/today_run.sh [DAYS] [extra colony_run options]        BIN=dir for another build's programs
#
# Seed 1.  The thirteen who arrive, with jobs (four gatherers, three foresters, two porters, three
# hunters, a cook), founded on a square (1238 1058, squarely: a place with banks, so its walls,
# stair and stepped path are built), a stockpile put down whole against its north side, the
# stockyard put down whole to the south (its storehouse 12 m by 8 m), and housing pulled with its
# path eastward.  No option turns a rule off: where the eight reference runs are a band of six with
# everything since 2026-11-17 held off (tools/reference_run.sh), this is what John plays.
# The day's state each midnight, everyone's doing with it (--who), and how the square, the
# stockyard and the cart stand at the end (--box-stats).
#
# (The housing lies east of the square because of what two trials showed, 2026-11-22: with the
# housing pulled westward from 1231 1058 in its place the colony had no cart at all at the end of
# 41 days (35 deer unsalted, 1,510 lb of meat lost), and likewise from 1224 1050 after two days;
# with four other pulls, and with none, it had its cart.  Why was not looked into: nothing of the
# cart is touched, by John's word of that day.  A run with no cart would leave the cart, the salt
# and the curing out of this log.)
cd "$(dirname "$0")/.." || exit 1
BIN=${BIN:-./bin}
DAYS=${1:-5}; shift
exec "$BIN/colony_run" --seed 1 --day 20 --time 7 --winter-store 10 --reserve meat 60 \
  --band 13 --gatherers 4 --foresters 3 --porters 2 --hunters 3 --cooks 1 \
  --square 1238 1058 0 --stockpile-box 1238.4 1070.4 0 --stockyard-box 1238 1041 4 \
  --housing-pull 1250 1058 1284 1058 2 \
  --days "$DAYS" --log-hours 24 --who --box-stats "$@"
