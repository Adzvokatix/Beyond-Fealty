#!/bin/bash
# The stress test: the colony and the game pushed past what a session of
# play asks of them, to find where they break before a player does.  It
# measures and reports; the only things it fails on are a run that dies, a
# colony that does not repeat itself, and a line the renderer prints when
# it has had to drop something ("render: ...").
#   tools/stress.sh [runner] [game] [debug]     (no part named: all three)
#     runner  colony_run, no window: the reference band with the reference
#             run's standing orders (a winter store of ten days, a meat
#             reserve of sixty) through four years, and again on two
#             workers (the state must be the same); a band of forty-eight
#             through a year the same way (the land cannot feed it: the
#             heaviest the colony gets), and through a year with no needs
#             and no demand chain, so that all of it works on, twice;
#             and the reference run with the walking map read whole and
#             no source memos (the state must be the same: both only save
#             work)
#     game    the game on the real GPU: wider and wider views, a long pan,
#             the largest window the screen takes with 8x MSAA, a crowd of
#             figures, sixty-four lights, a storm at the lowest tilt, mist,
#             a band of forty-eight at the top speed in a storm and by night
#     debug   the debug build (range, overflow and validity checks): the
#             reference band through a year in the runner, and through a
#             year of weather in the game at the top speed
#   BIN=dir   another build's bin directory (a worktree of main)
# Needs a window for "game" and "debug" (it opens floating windows on the
# desktop), python3 for the clock and the peak memory.  About twenty
# minutes for all of it.  As measured: docs/production/Stress_test.md.
cd "$(dirname "$0")/.." || exit 1
BIN=${BIN:-./bin}
TMP=$(mktemp -d)
FAILED=0
PARTS=${*:-runner game debug}

SITE="--seed 1 --stake 1178 1078 --path 1176 1076 1194 1076 --stockpile-least 0 --no-overflow --last-places 0 --one-to-a-bush --no-storehouse --no-path-level --no-roof-timbers --no-window-timber --no-reach-out --no-zigzag --no-paths-meet --no-door-meet --no-build-help --no-place-level --no-cart-room --no-step-at-edge --no-steep-refuse --no-wood-reach --no-house-turn --stockpile 1180 1070 1190 1075 --camp 1172 1082"
SIX="--band 6 --gatherers 2 --foresters 1 --hunters 2 --cooks 1"   # (six: thirteen arrive unless told, since 2026-11-17)
ORDERS="--winter-store 10 --reserve meat 60"     # the reference run's (tools/reference_check.sh): without a
                                                 # winter store the band starves a week into its first winter
CROWD="--band 48 --gatherers 14 --foresters 6 --porters 8 --hunters 8 --cooks 2"

timed() {  # LOG CMD...: runs it; prints its seconds, its peak memory and how it ended
  local log=$1; shift
  python3 -c '
import resource, subprocess, sys, time
t = time.time()
with open(sys.argv[1], "w") as f:
    r = subprocess.call(sys.argv[2:], stdout=f, stderr=subprocess.STDOUT)
u = resource.getrusage(resource.RUSAGE_CHILDREN)
print("%6.1f s %6d MB%s" % (time.time() - t, u.ru_maxrss // 1024, "" if r == 0 else "  EXIT %d" % r))
sys.exit(0 if r == 0 else 1)
' "$log" "$@"
}

fail() { echo "  FAILED: $*"; FAILED=$((FAILED + 1)); }

run() {  # NAME COLONY_RUN OPTIONS...: one line: time, memory, the state
  local name=$1; shift
  local t
  t=$(timed "$TMP/$name.log" "$@") || fail "$name died: $(tail -n 2 "$TMP/$name.log" | tr '\n' ' ')"
  printf "%-22s %s  %s\n" "$name" "$t" "$(grep '^state:' "$TMP/$name.log")"
  grep -E "^ran " "$TMP/$name.log" | sed 's/^/                       /'
}

state() { grep '^state:' "$TMP/$1.log"; }
alive() { grep '^colony:' "$TMP/$1.log" | tail -n 1 | sed 's/^colony: \([^,]*, [^,]*\),.*; \([0-9]* of [0-9]* trees felled\).*; \([0-9]* killed\).*/                       at the end: \1; \2; \3/'; }

game() {  # NAME GAME OPTIONS...: one line: time, memory, what was resident, what a frame cost
  local name=$1; shift
  local t
  t=$(timed "$TMP/$name.log" "$@" --float --hud none --seed 1 --mouse 2 2 --shot "$TMP/$name.png") \
    || fail "$name died: $(tail -n 2 "$TMP/$name.log" | tr '\n' ' ')"
  local res cost
  res=$(sed -n 's/^view filled in \([0-9.]*\) s, *\([0-9]*\) stacks, *\([0-9]*\) quads (\([0-9.]*\) MB), *\([0-9]*\) draws.*/filled \1 s, \2 stacks, \4 MB, \5 draws/p' "$TMP/$name.log")
  cost=$(sed -n 's/^after the fill: *\([0-9]*\) frames, gpu \([0-9.]*\) ms, cpu \([0-9.]*\) ms (max \([0-9.]*\))/gpu \2 ms, cpu \3 ms (max \4) over \1 frames/p' "$TMP/$name.log")
  printf "%-22s %s  %s; %s\n" "$name" "$t" "$res" "$cost"
  if grep -q -i -E "render:|raised|exception|error" "$TMP/$name.log"; then
    grep -i -E "render:|raised|exception|error" "$TMP/$name.log" | sort | uniq -c | sed 's/^/                       /'
    fail "$name: see above"
  fi
}

for part in $PARTS; do
  case $part in
  runner)
    echo "-- the runner (release)"
    LONG="--no-needs --no-demand"
    run six_4_years   "$BIN/colony_run" $SITE $SIX $ORDERS --day 20 --time 7 --days 240 --log-hours 1440
    alive six_4_years
    run six_2_workers "$BIN/colony_run" $SITE $SIX $ORDERS --day 20 --time 7 --days 240 --log-hours 1440 --workers 2
    [ "$(state six_4_years)" = "$(state six_2_workers)" ] || fail "four years end otherwise on two workers"
    # (what is only kept to save work must change no run: the walking map mended or read whole, what a
    # search for a source found kept or read again)
    run six_41_days   "$BIN/colony_run" $SITE $SIX $ORDERS --day 20 --time 7 --days 41 --log-hours 1440
    run six_read_anew "$BIN/colony_run" $SITE $SIX $ORDERS --day 20 --time 7 --days 41 --log-hours 1440 --no-mending --no-memos
    [ "$(state six_41_days)" = "$(state six_read_anew)" ] || fail "the run ends otherwise with the map read whole and no memos"
    # (and with houses going up: a blueprint drawn once or every time, a lot looked for again or not)
    HOUSING="--path 1176 1076 1140 1076 --housing 1141 1077 1167 1087 --housing 1141 1075 1175 1065 --porters 1 --hunters 1"
    run housing_41_days   "$BIN/colony_run" $SITE $SIX $HOUSING $ORDERS --day 20 --time 7 --days 41 --log-hours 1440
    run housing_read_anew "$BIN/colony_run" $SITE $SIX $HOUSING $ORDERS --day 20 --time 7 --days 41 --log-hours 1440 --no-mending --no-memos
    [ "$(state housing_41_days)" = "$(state housing_read_anew)" ] || fail "the housing run ends otherwise with the map read whole and no memos"
    run housing_2_workers "$BIN/colony_run" $SITE $SIX $HOUSING $ORDERS --day 20 --time 7 --days 41 --log-hours 1440 --workers 2
    [ "$(state housing_41_days)" = "$(state housing_2_workers)" ] || fail "the housing run ends otherwise on two workers"
    run crowd_as_it_is "$BIN/colony_run" $SITE $CROWD $ORDERS --day 20 --time 7 --days 60 --log-hours 1440
    alive crowd_as_it_is
    run crowd_at_work "$BIN/colony_run" $SITE $CROWD $LONG --day 20 --time 7 --days 60 --log-hours 1440
    alive crowd_at_work
    run crowd_again   "$BIN/colony_run" $SITE $CROWD $LONG --day 20 --time 7 --days 60 --log-hours 1440 --workers 3
    [ "$(state crowd_at_work)" = "$(state crowd_again)" ] || fail "the crowd's year ends otherwise on three workers"
    # (a herd with no dry way out, frightened by one who stands by it, asks the same way every three
    # seconds: a plan that ran out of budget is remembered, and remembering must change no run)
    run crowd_no_memos "$BIN/colony_run" $SITE $CROWD $LONG --day 20 --time 7 --days 60 --log-hours 1440 --no-memos
    [ "$(state crowd_at_work)" = "$(state crowd_no_memos)" ] || fail "the crowd's year ends otherwise with nothing remembered"
    # (a herd's ways are refused where its pieces of ground for dry going say out of reach, and those
    # pieces are kept from one asking to the next: with the proving on, every such answer is searched
    # for whole and every kept piece worked out again beside it; a wrong one stops the run, and the
    # proving must change no run)
    run crowd_prove_dry "$BIN/colony_run" $SITE $CROWD $LONG --day 20 --time 7 --days 60 --log-hours 1440 --prove-dry
    [ "$(state crowd_at_work)" = "$(state crowd_prove_dry)" ] || fail "the crowd's year ends otherwise with every refusal proved"
    # (a stack's ground summary is kept small, nothing lost: with each kept whole, as it always was,
    # the run must end the same)
    run crowd_full_sums "$BIN/colony_run" $SITE $CROWD $LONG --day 20 --time 7 --days 60 --log-hours 1440 --full-summaries
    [ "$(state crowd_at_work)" = "$(state crowd_full_sums)" ] || fail "the crowd's year ends otherwise with the ground summaries kept whole"
    # (and a chunk's fine bricks are kept small, nothing lost: written whole, the same)
    run crowd_whole_bricks "$BIN/colony_run" $SITE $CROWD $LONG --day 20 --time 7 --days 60 --log-hours 1440 --whole-bricks
    [ "$(state crowd_at_work)" = "$(state crowd_whole_bricks)" ] || fail "the crowd's year ends otherwise with the fine bricks written whole"
    # (the game holds the whole map; the colony reads its own ground and nothing beyond, so with
    # every stack of the world in, the run must be the very run it is on the colony's ground alone:
    # this line stands in for the game)
    run crowd_whole_map "$BIN/colony_run" $SITE $CROWD $LONG --day 20 --time 7 --days 60 --log-hours 1440 --ground-stacks 400 --no-mesh
    [ "$(state crowd_at_work)" = "$(state crowd_whole_map)" ] || fail "the crowd's year ends otherwise with the whole map in"
    ;;
  game)
    echo "-- the game (release)"
    G="$BIN/castle_game --novsync --size 1280 720 --day 20 --time 11 --weather clear --at 1190 1085"
    game view_160      $G --frames 2500
    game view_256      $G --frames 2500 --view 256 --cam 2.4 0.5 160
    game view_384      $G --frames 2500 --view 384 --cam 2.4 0.5 240
    game view_512      $G --frames 2500 --view 512 --cam 2.4 0.5 320
    game view_384_snow $G --frames 2500 --view 384 --cam 2.4 0.5 240 --day 52 --weather snow
    game pan_700       $G --frames 600 --pan 600 360
    game big_window    "$BIN/castle_game" --novsync --size 2560 1440 --msaa 8 --day 20 --time 15 --weather cloudy \
                       --at 1197 1063 --cam 2.4 0.14 20 --frames 2500
    game figures       $G --frames 2500 --lineup 48 --deer 64 --cam 2.9 0.5 30
    game lights_64     $G --frames 2500 --time 23 --lights 64
    game storm_low     "$BIN/castle_game" --novsync --size 1280 720 --day 20 --time 15 --weather storm \
                       --at 1100 1000 --cam 5.5 0.12 80 --frames 2500
    game mist_low      "$BIN/castle_game" --novsync --size 1280 720 --day 20 --time 6 --weather clear --mist 1 \
                       --at 1100 1000 --cam 5.5 0.12 80 --frames 2500
    game crowd_storm   "$BIN/castle_game" --size 1280 720 $SITE $CROWD --camp-built --paths-built --stoke 8 \
                       --day 20 --time 17 --weather storm --speed 240 --at 1176 1080 --frames 1800
    game crowd_night   "$BIN/castle_game" --novsync --size 1280 720 $SITE $CROWD --camp-built --paths-built --stoke 8 \
                       --day 20 --time 23 --weather clear --at 1176 1080 --cam 2.4 0.3 14 --frames 2500
    ;;
  debug)
    echo "-- the debug build"
    run debug_six_1_year "$BIN/debug/colony_run" $SITE $SIX $ORDERS --day 20 --time 7 --days 60 --log-hours 1440
    alive debug_six_1_year
    game debug_year      "$BIN/debug/castle_game" --size 1280 720 $SITE $SIX $ORDERS --camp-built --paths-built \
                         --day 20 --time 7 --speed 240 --at 1176 1080 --cam 2.4 0.3 30 --frames 22000
    ;;
  *) echo "no such part: $part (runner, game, debug)"; FAILED=$((FAILED + 1));;
  esac
done
rm -rf "$TMP"
if [ "$FAILED" -gt 0 ]; then echo "stress: $FAILED failed"; exit 1; fi
echo "stress: nothing died, nothing dropped"
