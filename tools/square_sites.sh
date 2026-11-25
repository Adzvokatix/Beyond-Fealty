#!/bin/bash
# The square a colony is founded on (the homestake and the campfire one,
# 2026-11-20), at real places of seed 1.  Three things, each of which caught a
# fault the checks had not:
#
# 1. Squares founded and made on the spot, their walls and stairs too, over a
#    20 m grid within 100 m of each of ten places, squarely and aslant by turns
#    (colony_run --square-scan; 16 m and 96 until 2026-11-21: a square of
#    eleven metres aslant reaches 9.2 m from its middle, and the next one's
#    side is 6.5 from its own):
#    of every spot within 9 m of a square's middle that can be got to from its
#    fire, the fire can be got to (one from which it cannot is a pit: a serf
#    sent there starves); and its fire can be got to and from the land 14 m off
#    on one side at the least.  It fails on a pit, on a fire out of reach, on a
#    camp that did not come to stand, on logs of a tree felled for a square
#    that do not lie on the ground, or if fewer than 280 squares were founded
#    in all (323 of 1,210 places take one of eleven metres; a square's trees
#    are felled for it: 2026-11-20, "felled and removed anywhere else"); or if
#    anything of a square's walls is left to lay once they are built (what
#    cannot be laid must not be counted), or fewer than 45 have any stone, 14
#    have a wall set back or 24 a stair (2026-11-20, "stone wall and stair,
#    also step the stone walls towards the higher ground if over 1m").
#    Since 2026-11-21 their walls stand outside their floors ("the area of a
#    special zone ... takes precedent"): it fails too if any column of a
#    floor is stone and no stair's, if the strips kept at the founding are
#    too narrow, or wanting, on more than three sides in all, or if any
#    square is founded at another level than its plan said (the strips are
#    judged against the plan's: three were, a block lower, where trees stand
#    on the floor, until the gate of 2026-11-21 raised on it in debug), if
#    any square is planned and then not founded, or founded with its fire's
#    place more than 2 m off its floor's level (under a tree the stake was
#    put on a bough, or no ground found for it: 14 of 323, until 2026-11-21).
#    As it stands: 323 squares; 70 with any stone, 23 with a wall set back (one
#    of them twice: a bank of 2.25 m), 35 with a stair, no side too high for
#    one; 212 sides have a strip, none of them is asked a ring more by its
#    path as laid, and no side with none is asked for a wall.  (With their
#    walls inside, --square-walls-inside: 324, 64, 21, 34; of ten metres too,
#    --square-10: 330, 63, 22, 32 as last counted, before the three squares
#    under trees were founded.)
#    **A square's stair stands at the middle of its side** (55 of them at 35
#    squares): it fails too if any stands at an end of a side, or if the scan
#    does not say where they stand.  (For some hours of 2026-11-21 they stood
#    in the corners, 52 of them, on his "if a stair is to be had it's to be at
#    the corner of the zone", which he then said was of the stockyard's: that
#    rule is behind --square-stair-corner, off.)
#    A scan that raises fails it: colony_run says what it raised and leaves
#    with 1 (it used to stand for ever, waiting for its workers' tasks).
#    **Since 2026-11-22 the squares' paths are stepped with stone** (his "we
#    need to do something about having the .5m jumps in the path around the
#    square too", and of the ways put to him "Steps of stone"): where a
#    levelled stretch of a path ends, the path goes on a block a quarter
#    metre, each step a tread of stone, laid with the walls.  It fails too if
#    the path stands two blocks or more off the next quarter metre at the end
#    of a levelled stretch anywhere but where the runner says why (where two
#    sides' paths cross; before a stair; a boulder or a tree on the path), if
#    a step is not all of stone at one row, or if fewer than 400 quarter
#    metres are stepped.  As it stands: 460 quarter metres stepped; of 272
#    such steps 50 are left, 31 of them at a levelled stretch's end (25 where
#    two sides' paths cross, 2 before a stair, 4 at a boulder), 12 others by
#    a side's end and 7 the land's own along a side that is not levelled.
#    **Since 2026-11-22, later, the square metre where two sides' paths cross
#    is laid as one** (his "stick with whatever you think is best", of the
#    corners; Castle.Colony.Set_Corner_Whole): all of it at the floor's level
#    or all of it as the land lies, by its own columns, whichever side's metre
#    comes first.  The scans of two of the ten places (800 900 and 1178 1078,
#    where 17 of the 26 squares stood that stood otherwise with their paths
#    laid last metre first) are made again with --paths-backward: it fails if
#    any square stands otherwise than laid first metre first (a hash of every
#    block column within eleven metres of its middle), or if either scan does
#    not say.  As it stands with that rule alone (--no-corner-steps): none of
#    98 does; 55 jumps are left for 50 (35 where two sides' paths cross for
#    25: a corner with one column out of reach of the level is left whole as
#    the land lies) and 43 quarter metres fewer lie at the floor's level, of
#    57,540.
#    **And the steps run into the corners and through them** (the second half
#    of the same default; Castle.Colony.Set_Corner_Steps): the square metre
#    where two sides' paths cross is a landing of a flight, all its columns
#    of stone at one row, and the flight goes on from it along the other
#    side.  It fails too if a jump at a levelled stretch's end is said to be
#    where two sides' paths cross, or if fewer than 600 quarter metres are
#    stepped.  As it stands: 691 quarter metres stepped; **16 jumps left of
#    the 272**: 7 at a levelled stretch's end (2 before a stair, 5 at a
#    boulder on the path), 2 others by a side's end, 7 the land's own along a
#    side that is not levelled; none of the 98 squares stands otherwise with
#    its path laid last metre first.
#    **A strip's column waits for the path it is planned against** (found
#    2026-11-22, his "Mend the issues you found"; Castle.Colony.Set_Strip_Wait):
#    the same two places are scanned a third time with their walls built when
#    half their paths' metres are laid (--walls-between), and it fails if any
#    square stands otherwise than built in order.  (Before: 25 of the 323, 14
#    of them at these two places.)
# 2. Fourteen awkward sites (rising ground, trees and bushes by; two in the
#    wood, ten trees on each), a stockpile put down against each of the four
#    sides of the square's path (all fifty-six go down, each along that
#    side's own path, none of its path new: with strips an odd number of
#    rings apart on an angled square a box was refused, or laid a path of its
#    own beside the square's), the band of thirteen, twelve days: founded,
#    its fire burning, nobody starved, no tree left to fell on it, and of
#    its walls (six of them have banks to wall) nothing left to lay.
# 2b. Four squares whose middle lies under a tree (three whose stake was put
#    on a bough, 4 to 7 m up, where the band arrived in the crowns and
#    somebody starved; one that was refused after its plan said yes), the
#    band of thirteen with a stockpile, twelve days: founded, nobody starved,
#    no pit, and nobody's feet more than a step off the ground under them for
#    more than two minutes in all (colony_run --feet-stats).
# 3. A colony saved half built and run on from the save ends as the straight
#    run does (the state's hash): a square on sloping ground with a tree on its
#    floor and a stockpile against its west side, saved after 90 colony seconds
#    (its floor half dug), in the middle of the hours its walls are laid in
#    (begun after eleven and a half game hours and done after thirteen, of a
#    square of eleven metres: read from the straight run) and after a day,
#    run on to three days.
# 4. A square founded round its trees (--no-square-fell, as squares first
#    were), saved, and run on twelve days as trees are felled for squares: the
#    tree on its floor stands still (the foresters spare it: felled, it would
#    leave a hole in a floor filled up round it) and no spot round it is a pit.
# 5. A square with four stockpiles put down against it, trees standing in two
#    of them (2026-11-20: "fell the tree in the stockpile"), saved after 90
#    colony seconds, while they stand, and run on: the straight run's state,
#    and no tree left in them.  (How many stand is counted at most once a
#    colony second and decides whether anyone turns to the band's building:
#    a count that a load made differ from the straight run's would show here.)
# 6. Three walled squares saved on each of eleven half minutes round the
#    lighting of their fire and run on: the straight run's state.  (The walls
#    are wanted from when the fire is lit; nothing of them is kept, a load
#    counts them at its first step, and the straight run must have counted
#    them by then too: counted at the minute's turn, the square of ten metres
#    at 1178 1094 saved after 810 colony seconds ran on otherwise.  The three
#    are 1238 1058, 1258 1058 and 1320 980 since 2026-11-21: the three before
#    them do not take a square of eleven metres.)
# 7. A stockpile put down on the third day over the standing lord's cart, at
#    three squares (2026-11-23: a stockpile is made one level where it is put
#    down, "flatten the stockpile"; the ground under the cart and a metre round
#    it waits for the cart to go, and no place is planned there): the ground
#    did wait (some block columns were left); on the fourth day every block
#    column of the stockpile lies at its level but what the cart stands on
#    now (colony_run --flat-scan: none "to move still"; left as the land lay
#    where the cart had stood, it was a hollow as deep as the fill round it,
#    which a serf drops into and does not climb out of); nobody died; and the
#    same run saved half a minute after the stockpile was put down and run on
#    ends in the straight run's state.
# Every run of a band here prints each member's state each hour (--who,
# --log-hours 1: since 2026-11-21 noon).  Until then these runs printed no
# states, and "nobody starved" could only have failed on a death or on
# someone starving without a bed (the food line names the bedless with what
# they are doing): a starving state is on a "who:" line, a death is "NAME has
# died of hunger" (the old pattern "dead, of hunger" matched nothing).
# **What fails a run is a death or a state worded "starving"** (the game words
# it so only of someone at work with an empty belly).  An empty belly itself
# (whoever is at 0 % fed: the runner prints its place) is counted and said,
# not failed on: it is ordinary for an hour before a meal, in every build.
#   tools/square_sites.sh       (about four minutes, release; exits 1 on a failure)
#   BIN=dir   another build's bin directory
cd "$(dirname "$0")/.." || exit 1
BIN=${BIN:-./bin}
TMP=$(mktemp -d)
FAIL=0

# ---- 1. the scan
for st in "1178 1078" "1000 900" "1186 1086" "1008 908" "1100 1000" "1300 1200" "800 900" "1200 800" "950 1250" "1400 1000"; do
  n=$(echo $st | tr ' ' '_')
  ( $BIN/colony_run --seed 1 --stake $st --square-scan 100 20 --square-scan-list > "$TMP/scan_$n.log" 2>&1 || echo "exit $?" >> "$TMP/scan_$n.log" ) &
done
# (1b: two of the places again, their paths laid first metre first and last metre first)
for st in "800 900" "1178 1078"; do
  n=$(echo $st | tr ' ' '_')
  ( $BIN/colony_run --seed 1 --stake $st --square-scan 100 20 --square-path > "$TMP/fwd_$n.log" 2>&1 || echo "exit $?" >> "$TMP/fwd_$n.log" ) &
  ( $BIN/colony_run --seed 1 --stake $st --square-scan 100 20 --square-path --paths-backward > "$TMP/back_$n.log" 2>&1 || echo "exit $?" >> "$TMP/back_$n.log" ) &
  ( $BIN/colony_run --seed 1 --stake $st --square-scan 100 20 --square-path --walls-between > "$TMP/between_$n.log" 2>&1 || echo "exit $?" >> "$TMP/between_$n.log" ) &
done
wait
founded=0; pits=0; cut_off=0; unbuilt=0; left_out=0; broken=0; off_piles=0; trees=0
walled=0; set_back=0; staired=0; stairs=0; wall_left=0; stairs_mid=0; stairs_end=0; stairs_lost=0; stairs_shared=0; stairs_level=0; no_stair_line=0
stripped=0; strip_sides=0; short_sides=0; spare_sides=0; bare_sides=0; floor_stone=0; level_off=0; plan_only=0; fire_off=0
jumps=0; jumps_end=0; stone_sl=0; stone_part=0; bar_cross=0; bar_stair=0; bar_uneven=0; bar_unread=0; no_path_line=0
for f in "$TMP"/scan_*.log; do
  line=$(grep 'square scan, within' "$f")
  wline=$(grep 'square scan, walls' "$f" | grep -v 'outside the floor')
  if [ -z "$line" ] || [ -z "$wline" ] || grep -q '^exit\|raised ' "$f"; then
    broken=$((broken + 1)); echo "FAIL: $(basename "$f" .log): the scan did not finish: $(tail -n 2 "$f" | tr '\n' ' ' | cut -c1-160)"
    continue
  fi
  founded=$((founded + $(echo "$line" | sed 's/.* places, \([0-9]*\) founded and made.*/\1/')))
  pits=$((pits + $(echo "$line" | sed 's/.*made; \([0-9]*\) with a pit by them.*/\1/')))
  cut_off=$((cut_off + $(echo "$line" | sed 's/.*in all), \([0-9]*\) whose fire cannot.*/\1/')))
  left_out=$((left_out + $(echo "$line" | sed 's/.*any side; \([0-9]*\) block columns left out.*/\1/')))
  unbuilt=$((unbuilt + $(grep -c 'ITS CAMP NOT BUILT' "$f")))
  grep 'square scan: at' "$f" | grep -v ' 0 pits; the fire got to and from [1-4] of the four sides; walls:.*; 0 blocks left after building;' | cut -c1-520
  off_piles=$((off_piles + $(echo "$line" | sed 's/.* at the most, \([0-9]*\) piles of logs not lying.*/\1/')))
  trees=$((trees + $(echo "$line" | sed 's/.*(trees. feet); \([0-9]*\) trees felled for.*/\1/')))
  walled=$((walled + $(echo "$wline" | sed 's/.*walls[^:]*: \([0-9]*\) of them walled.*/\1/')))
  set_back=$((set_back + $(echo "$wline" | sed 's/.*walled, \([0-9]*\) with a wall set back.*/\1/')))
  staired=$((staired + $(echo "$wline" | sed 's/.*twice), \([0-9]*\) with a stair (.*/\1/')))
  stairs=$((stairs + $(echo "$wline" | sed 's/.*with a stair (\([0-9]*\) stairs in all).*/\1/')))
  wall_left=$((wall_left + $(echo "$wline" | sed 's/.*laid by them; \([0-9]*\) blocks left after building.*/\1/')))
  sline=$(grep "square scan, a stair's place" "$f")
  if [ -n "$sline" ]; then
    stairs_mid=$((stairs_mid + $(echo "$sline" | sed 's/.*low end, middle, high end *[0-9]*, *\([0-9]*\), *[0-9]* (.*/\1/')))
    stairs_end=$((stairs_end + $(echo "$sline" | sed 's/.*low end, middle, high end *\([0-9]*\), *[0-9]*, *\([0-9]*\) (.*/\1 + \2/')))
    stairs_lost=$((stairs_lost + $(echo "$sline" | sed 's/.*in all); *\([0-9]*\) sides that would have one.*/\1/')))
    stairs_shared=$((stairs_shared + $(echo "$sline" | sed 's/.*at either end, *\([0-9]*\) sides. stairs are another.*/\1/')))
    stairs_level=$((stairs_level + $(echo "$sline" | sed 's/.*they meet at; *\([0-9]*\) stairs stand in a corner where.*/\1/')))
  else
    no_stair_line=$((no_stair_line + 1))
  fi
  pline=$(grep 'square scan, how their paths step' "$f")
  if echo "$pline" | grep -q 'quarter metres with a tread of stone'; then
    jumps=$((jumps + $(echo "$pline" | sed 's/.*a block *[0-9]*, two blocks *\([0-9]*\), three *\([0-9]*\), four or more *\([0-9]*\) (the most.*/\1 + \2 + \3/')))
    jumps_end=$((jumps_end + $(echo "$pline" | sed "s/.*meets one that is not: *\\([0-9]*\\) of two blocks, *\\([0-9]*\\) of three, *\\([0-9]*\\) of four or more; within.*/\\1 + \\2 + \\3/")))
    stone_sl=$((stone_sl + $(echo "$pline" | sed 's/.*quarter metres with a tread of stone: *\([0-9]*\) (.*/\1/')))
    stone_part=$((stone_part + $(echo "$pline" | sed 's/.*block columns of stone; \([0-9]*\) of them not all stone.*/\1/')))
    bar_cross=$((bar_cross + $(echo "$pline" | sed "s/.*where two sides' paths cross *\\([0-9]*\\), before a stair.*/\\1/")))
    bar_stair=$((bar_stair + $(echo "$pline" | sed 's/.*before a stair *\([0-9]*\), their columns.*/\1/')))
    bar_uneven=$((bar_uneven + $(echo "$pline" | sed 's/.*too far apart for one row *\([0-9]*\), a column.*/\1/')))
    bar_unread=$((bar_unread + $(echo "$pline" | sed 's/.*a column with no laid path to read *\([0-9]*\).*/\1/')))
  else
    no_path_line=$((no_path_line + 1))
  fi
  oline=$(grep 'square scan, walls outside the floor' "$f")
  if [ -n "$oline" ]; then
    stripped=$((stripped + $(echo "$oline" | sed 's/.*founded so; \([0-9]*\) with a strip kept.*/\1/')))
    strip_sides=$((strip_sides + $(echo "$oline" | sed 's/.*strip kept, \([0-9]*\) sides,.*/\1/')))
    short_sides=$((short_sides + $(echo "$oline" | sed 's/.*of those sides \([0-9]*\) are asked more rings.*/\1/')))
    spare_sides=$((spare_sides + $(echo "$oline" | sed 's/.*than were kept and \([0-9]*\) fewer;.*/\1/')))
    bare_sides=$((bare_sides + $(echo "$oline" | sed 's/.*fewer; \([0-9]*\) sides with none kept are asked for a wall.*/\1/')))
    floor_stone=$((floor_stone + $(echo "$oline" | sed 's/.*earth bank; \([0-9]*\) columns of floor of stone that are no stair.s.*/\1/')))
    level_off=$((level_off + $(echo "$oline" | sed 's/.*at the most); \([0-9]*\) founded at another level than they were planned at.*/\1/')))
    plan_only=$((plan_only + $(echo "$oline" | sed 's/.*planned at; \([0-9]*\) planned and not founded.*/\1/')))
    fire_off=$((fire_off + $(echo "$oline" | sed 's/.*not founded; \([0-9]*\) with the fire.s place more than 2 m off.*/\1/')))
  fi
done
if [ $broken = 0 ] && [ $pits = 0 ] && [ $cut_off = 0 ] && [ $unbuilt = 0 ] && [ $off_piles = 0 ] && [ $left_out = 0 ] && [ $founded -ge 280 ] \
   && [ $wall_left = 0 ] && [ $walled -ge 45 ] && [ $set_back -ge 14 ] && [ $staired -ge 24 ] \
   && [ $stairs_end = 0 ] && [ $stairs_mid = $stairs ] && [ $stairs_lost = 0 ] && [ $no_stair_line = 0 ] \
   && [ $floor_stone = 0 ] && [ $((short_sides + bare_sides)) -le 3 ] && [ $level_off = 0 ] && [ $plan_only = 0 ] && [ $fire_off = 0 ] \
   && [ $no_path_line = 0 ] && [ $stone_part = 0 ] && [ $stone_sl -ge 600 ] && [ $bar_cross = 0 ] \
   && [ $jumps_end -le $((bar_cross + bar_stair + bar_uneven + bar_unread)) ]; then
  echo "squares founded and made at ten places, their walls and stairs with them: $founded, none with a pit by it, none whose fire cannot be got to; $trees trees felled for them, their logs lying on the ground; $walled walled ($set_back with a wall set back, $staired with a stair, $stairs stairs, each at the middle of its side), nothing of them left to lay"
  echo "their paths stepped with stone: $stone_sl quarter metres are steps, each all of stone at one row; the path stands two blocks or more off the next quarter metre at $jumps places still, $jumps_end of them where a levelled stretch ends ($bar_cross where two sides' paths cross, $bar_stair before a stair, $bar_unread at a boulder or a tree on the path, $bar_uneven too uneven for one row)"
  echo "their walls stand outside their floors: $stripped of them have a strip kept for a wall, on $strip_sides sides; the path as laid asks more rings than were kept on $short_sides of those sides and fewer on $spare_sides, and a wall on $bare_sides sides with none kept; no column of any floor is stone but a stair's; every one founded at the level it was planned at, none planned and not founded, every fire's place on the ground"
else
  [ $level_off = 0 ] || echo "FAIL: $level_off squares were founded at another level than their plan said (their strips are judged against the plan's)"
  [ $plan_only = 0 ] || echo "FAIL: $plan_only squares were planned and then not founded (the ghost says yes, the click no)"
  [ $fire_off = 0 ] || echo "FAIL: $fire_off squares were founded with the fire's place more than 2 m off the floor's level (on a tree)"
  [ $floor_stone = 0 ] || echo "FAIL: $floor_stone block columns of the squares' floors are stone and no stair's (a floor is kept whole)"
  [ $stairs_end = 0 ] || echo "FAIL: $stairs_end stairs stand at an end of a side (a square's stair stands at the middle of its side)"
  [ $stairs_mid = $stairs ] || echo "FAIL: $stairs_mid of the $stairs stairs stand at the middle of a side"
  [ $stairs_lost = 0 ] || echo "FAIL: $stairs_lost sides that would have a stair at their middle have none"
  [ $no_stair_line = 0 ] || echo "FAIL: $no_stair_line scans did not say where the stairs stand"
  [ $((short_sides + bare_sides)) -le 3 ] || echo "FAIL: the strips kept at the founding are too narrow on $short_sides sides and wanting on $bare_sides (three in all at the most: none is)"
  [ $no_path_line = 0 ] || echo "FAIL: $no_path_line scans did not say how their paths step and what of them is stone"
  [ $stone_part = 0 ] || echo "FAIL: $stone_part quarter metres of path have a tread of stone and are not all stone at one row (a step is laid whole)"
  [ $stone_sl -ge 600 ] || echo "FAIL: $stone_sl quarter metres of the squares' paths are stepped with stone (600 at the least: are the steps, or the corners' steps, off?)"
  [ $bar_cross = 0 ] || echo "FAIL: $bar_cross jumps at a levelled stretch's end are said to be where two sides' paths cross (the corners are landings of the flights: none should be)"
  [ $jumps_end -le $((bar_cross + bar_stair + bar_uneven + bar_unread)) ] || echo "FAIL: the path stands two blocks or more off a levelled stretch's end at $jumps_end places, and the runner says why of $((bar_cross + bar_stair + bar_uneven + bar_unread)) ($bar_cross where two sides' paths cross, $bar_stair before a stair, $bar_uneven too uneven, $bar_unread unread)"
  echo "FAIL: squares founded and made at ten places: $founded (280 at the least), $pits with a pit by them, $cut_off whose fire cannot be got to, $unbuilt whose camp did not come to stand, $off_piles piles of logs not lying on the ground, $left_out block columns left out of their floors; $walled walled (45 at the least), $set_back with a wall set back (14), $staired with a stair (24), $wall_left blocks of their walls left after building"
  FAIL=1
fi

# ---- 1b. laid first metre first and last metre first
order_n=0; order_diff=0; order_broken=0; between_diff=0
for st in 800_900 1178_1078; do
  if grep -q '^exit\|raised ' "$TMP/fwd_$st.log" "$TMP/back_$st.log" "$TMP/between_$st.log"; then order_broken=$((order_broken + 1)); fi
  grep '^square ground at' "$TMP/fwd_$st.log" > "$TMP/fwd_$st.txt"
  grep '^square ground at' "$TMP/back_$st.log" > "$TMP/back_$st.txt"
  grep '^square ground at' "$TMP/between_$st.log" > "$TMP/between_$st.txt"
  [ "$(wc -l < "$TMP/fwd_$st.txt")" = "$(wc -l < "$TMP/back_$st.txt")" ] || order_broken=$((order_broken + 1))
  [ "$(wc -l < "$TMP/fwd_$st.txt")" = "$(wc -l < "$TMP/between_$st.txt")" ] || order_broken=$((order_broken + 1))
  order_n=$((order_n + $(wc -l < "$TMP/fwd_$st.txt")))
  order_diff=$((order_diff + $(diff "$TMP/fwd_$st.txt" "$TMP/back_$st.txt" | grep -c '^<')))
  between_diff=$((between_diff + $(diff "$TMP/fwd_$st.txt" "$TMP/between_$st.txt" | grep -c '^<')))
done
if [ $order_broken = 0 ] && [ $order_n -ge 50 ] && [ $order_diff = 0 ] && [ $between_diff = 0 ]; then
  echo "their paths laid last metre first, at two of the places: of $order_n squares none stands otherwise than laid first metre first (the square metre where two sides' paths cross is laid as one, and stepped as one); nor with their walls built when half their paths are laid (a strip's column waits for the path it is planned against)"
else
  echo "FAIL: their paths laid last metre first, at two of the places: of $order_n squares (50 at the least) $order_diff stand otherwise than laid first metre first, $between_diff with their walls built when half their paths are laid; $order_broken scans did not finish or did not say"
  FAIL=1
fi

# ---- 2. the awkward sites
J13="--band 13 --gatherers 4 --foresters 3 --porters 2 --hunters 3 --cooks 1"
COMMON="--day 20 --time 7 --log-hours 1 --who --winter-store 10 --reserve meat 60"
site() {  # X Y WAY
  local L="$TMP/site_$1_$2_$3.log" X=$1 Y=$2 BOXES
  if [ $3 = 0 ]; then
    BOXES="--stockpile-box $(echo "$X + 11.7" | bc) $(echo "$Y + 0.4" | bc) 6 --stockpile-box $(echo "$X - 11.7" | bc) $(echo "$Y + 0.4" | bc) 2 --stockpile-box $(echo "$X + 0.4" | bc) $(echo "$Y + 11.7" | bc) 0 --stockpile-box $(echo "$X + 0.4" | bc) $(echo "$Y - 11.7" | bc) 4"
  else
    BOXES="--stockpile-box $(echo "$X - 7.76" | bc) $(echo "$Y + 7.76" | bc) 1 --stockpile-box $(echo "$X + 7.76" | bc) $(echo "$Y - 7.76" | bc) 5 --stockpile-box $(echo "$X + 7.76" | bc) $(echo "$Y + 7.76" | bc) 7 --stockpile-box $(echo "$X - 7.76" | bc) $(echo "$Y - 7.76" | bc) 3"
  fi
  $BIN/colony_run --seed 1 --square $1 $2 $3 $COMMON $J13 $BOXES --days 12 --square-pits --box-stats > "$L" 2>&1
  local f piles burnt living starving to_fell pits wall_left
  f=$(grep -c 'founded on a square' "$L")
  piles=$(grep -c 'stockpile put down' "$L")
  # (since 2026-11-23 a stockpile is refused where its ground is too steep, "over 1/2 slope": one so
  # refused is counted with those put down, and how many there were is said: two, at 1010 890)
  steep=$(grep -c 'stockpile refused: the ground is too steep' "$L")
  echo "$steep" > "$TMP/steep_$1_$2_$3"
  piles=$((piles + steep))
  newp=$(grep 'stockpile put down' "$L" | grep -c -v ', 0.00 m of it new')      # (a box's path that is not the square's own)
  burnt=$(grep '^food' "$L" | tail -n 1 | grep -o 'burnt [0-9]*' | grep -o '[0-9]*')
  living=$(grep '^colony:' "$L" | tail -n 1 | grep -o '[0-9]* living')
  starving=$(grep -c 'starving\|has died of hunger' "$L")
  grep -c '^  who: [A-Za-z]*, *-\{0,1\}0 % fed: .*(at [-0-9.]* [-0-9.]* [-0-9.]*)$' "$L" > "$TMP/empty_$1_$2_$3"      # (member-hours with an empty belly)
  to_fell=$(grep '^square pits' "$L" | sed 's/.*north, \([0-9]*\) still to fell for it.*/\1/')
  pits=$(grep '^square pits' "$L" | sed 's/.*from its fire, \([0-9]*\) cannot be got back from.*/\1/')
  wall_left=$(grep 'at the end: its walls:' "$L" | sed 's/.*its walls: \([0-9]*\) blocks of stone still to lay, \([0-9]*\) of earth.*/\1 \2/')
  if [ "$f" != 1 ] || [ "$piles" != 4 ] || [ "$newp" != 0 ] || [ "${burnt:-0}" -lt 10 ] || [ "$living" != "13 living" ] || [ "$starving" != 0 ] \
     || [ "${to_fell:-9}" != 0 ] || [ "${pits:-9}" != 0 ] || [ "${wall_left:-9}" != "0 0" ]; then
    echo "FAIL: a square at $1 $2 turned $3: founded $f, $piles stockpiles of four put down or refused as too steep ($steep) ($newp of them along a path of their own), ${burnt:-0} logs burnt, $living, $starving lines of someone starving, ${to_fell:-?} trees still to fell on it, ${pits:-?} pits by it, of its walls (stone, earth) ${wall_left:-?} blocks left: $(grep 'square refused' "$L" | cut -c1-120)"
    touch "$TMP/failed"
  fi
  grep 'at the end: its walls:' "$L" | grep -q -v '; 0 block columns of wall' && touch "$TMP/walled_$1_$2_$3"
}
for s in "1172 1092" "1160 1090" "1186 1068" "1150 1062" "1000 912" "1010 890"; do for w in 0 1; do site $s $w & done; done
site 816 964 1 &       # (in the wood: ten trees on each)
site 832 964 0 &
wait
if [ -e "$TMP/failed" ]; then
  FAIL=1
else
  echo "fourteen awkward sites, twelve days, a stockpile put down against each of the four sides of every one, along that side's own path ($(cat "$TMP"/steep_* | paste -sd+ | bc) of the 56 refused, their ground too steep): all founded, the fire burning, nobody died or was said to be starving ($(cat "$TMP"/empty_* | paste -sd+ | bc) member-hours with an empty belly at an hourly look), no tree left to fell on them, no pit by them; $(ls "$TMP" | grep -c '^walled_') of them walled by the band, nothing of their walls left to lay"
fi

# ---- 2b. squares whose middle lies under a tree
under() {  # X Y WAY
  local L="$TMP/under_$1_$2_$3.log" X=$1 Y=$2 BOX
  if [ $3 = 0 ]; then BOX="--stockpile-box $(echo "$X + 0.4" | bc) $(echo "$Y + 12.4" | bc) 0"; else BOX="--stockpile-box $(echo "$X + 8.6" | bc) $(echo "$Y + 8.6" | bc) 7"; fi
  $BIN/colony_run --seed 1 --square $1 $2 $3 $COMMON $J13 $BOX --days 12 --square-pits --box-stats --feet-stats > "$L" 2>&1
  local f piles living starving pits air worst
  f=$(grep -c 'square at the end: its floor' "$L")
  piles=$(grep -c 'stockpile put down' "$L")
  living=$(grep '^colony:' "$L" | tail -n 1 | grep -o '[0-9]* living')
  starving=$(grep -c 'starving\|has died of hunger' "$L")
  grep -c '^  who: [A-Za-z]*, *-\{0,1\}0 % fed: .*(at [-0-9.]* [-0-9.]* [-0-9.]*)$' "$L" > "$TMP/uempty_$1_$2_$3"
  pits=$(grep '^square pits' "$L" | sed 's/.*from its fire, \([0-9]*\) cannot be got back from.*/\1/')
  air=$(grep '^feet' "$L" | tail -n 1 | sed 's/.* and \([0-9]*\) more than a step.*/\1/')
  worst=$(grep '^feet' "$L" | tail -n 1 | sed 's/.*the worst \([0-9.]*\) m.*/\1/')
  if [ "$f" != 1 ] || [ "$piles" != 1 ] || [ "$living" != "13 living" ] || [ "$starving" != 0 ] || [ "${pits:-9}" != 0 ] \
     || [ "${air:-9999}" -gt 120 ]; then
    echo "FAIL: a square at $1 $2 turned $3, its middle under a tree: founded $f, $piles stockpile, $living, $starving lines of someone starving, ${pits:-?} pits, feet more than a step off the ground for ${air:-?} serf-seconds (the worst ${worst:-?} m)"
    touch "$TMP/failed_under"
  fi
}
for s in "1118 1058 0" "1098 1058 1" "1140 920 0" "1178 1038 0"; do under $s & done
wait
if [ -e "$TMP/failed_under" ]; then
  FAIL=1
else
  echo "four squares whose middle lies under a tree (three whose stake was put on a bough, one that was refused after its plan), twelve days: founded on the ground, nobody died or was said to be starving ($(cat "$TMP"/uempty_* | paste -sd+ | bc) member-hours with an empty belly), no pit, nobody's feet more than a step off the ground under them for two minutes in all"
fi

# ---- 3. saved half built, run on
ARGS="--square 1146 1110 0 --stockpile-box 1134.3 1110.4 2"
$BIN/colony_run --seed 1 $ARGS $COMMON $J13 --days 3 --box-stats > "$TMP/straight.log" 2>&1
want=$(grep '^state:' "$TMP/straight.log" | awk '{print $2}')
# (and its stockpile was put down: held where a square's path was when this was written, it is drawn
# to where the path is now, or it is refused and this part is of a square without one)
if [ "$(grep -c 'stockpile put down.*, 0.00 m of it new' "$TMP/straight.log")" != 1 ]; then
  echo "FAIL: the stockpile against the sloping square's west side was not put down along the square's own path: $(grep 'stockpile' "$TMP/straight.log" | head -n 1 | cut -c1-160)"
  FAIL=1
fi
# (the middle of the hours its walls are laid in, by the straight run's own account of them, on a
# half minute of the colony's time: colony_run packs edited ground anew every thirty colony seconds
# of its own run and says so of a save taken between two of those beats; a run on from such a save
# need not keep step with the straight run.  Saved 741 to 745 colony seconds in, of every thirty,
# this square ran on to another state two days later, and from no other second.)
from=$(grep 'its walls were first wanted after' "$TMP/straight.log" | sed 's/.*first wanted after \([0-9.]*\) game hours.*/\1/')
to=$(grep 'its walls were first wanted after' "$TMP/straight.log" | sed 's/.*was left after \([0-9.]*\) game hours.*/\1/')
midsec=$(( $(echo "(${from:-8} + ${to:-10}) * 30 / 30" | bc) * 30 ))
midd=$(echo "scale=7; $midsec / 1440" | bc)
same=0
for d in 0.0625 $midd 1; do
  $BIN/colony_run --seed 1 $ARGS $COMMON $J13 --days $d --box-stats --save "$TMP/half_$d.castle" > "$TMP/half_$d.log" 2>&1
  $BIN/colony_run --seed 1 --load "$TMP/half_$d.castle" --log-hours 1 --who --days $(echo "3 - $d" | bc -l) > "$TMP/on_$d.log" 2>&1
  got=$(grep '^state:' "$TMP/on_$d.log" | awk '{print $2}')
  if [ -n "$want" ] && [ "$got" = "$want" ]; then
    same=$((same + 1))
  else
    echo "FAIL: saved after $d days and run on: state ${got:-none}, the straight run's ${want:-none}"
    FAIL=1
  fi
done
mid=$(grep 'at the end: its walls:' "$TMP/half_$midd.log" | sed 's/.*its walls[^:]*: \([0-9]*\) blocks of stone still to lay.*/\1/')
midh=$(echo "scale=1; $midsec / 60" | bc)
all=$(grep 'its walls were first wanted' "$TMP/straight.log" | sed 's/.*game hours (\([0-9]*\) blocks of stone).*/\1/')
if [ "${mid:-0}" -lt 1 ]; then
  echo "FAIL: saved after $midh game hours (its walls laid from ${from:-?} to ${to:-?}), the square's walls were not half laid (${mid:-?} blocks of stone still to lay)"
  FAIL=1
fi
[ $same = 3 ] && echo "a square saved half built (after 90 colony seconds; after $midh game hours, $mid blocks of its walls' stone still to lay; and after a day) and run on to three days: the straight run's state ($want)"

# ---- 4. a square founded round its trees, run on as trees are felled for squares
$BIN/colony_run --seed 1 $ARGS --no-square-fell $COMMON $J13 --days 2 --save "$TMP/left.castle" > "$TMP/left.log" 2>&1
$BIN/colony_run --seed 1 --load "$TMP/left.castle" --log-hours 1 --who --days 12 --square-pits > "$TMP/left_on.log" 2>&1
standing=$(grep '^square pits' "$TMP/left_on.log" | sed 's/.*back from; \([0-9]*\) trees standing within.*/\1/')
pits=$(grep '^square pits' "$TMP/left_on.log" | sed 's/.*from its fire, \([0-9]*\) cannot be got back from.*/\1/')
felled=$(grep '^colony:' "$TMP/left_on.log" | tail -n 1 | grep -o '[0-9]* of [0-9]* trees felled' | cut -d' ' -f1)
if [ "${standing:-0}" -ge 1 ] && [ "${pits:-9}" = 0 ] && [ "${felled:-0}" -ge 5 ]; then
  echo "a square founded round its tree, saved and run on twelve days: the tree stands still ($felled felled elsewhere), no pit by it"
else
  echo "FAIL: a square founded round its tree and run on: ${standing:-?} trees standing on it, ${pits:-?} pits by it, ${felled:-?} trees felled in all"
  FAIL=1
fi

# ---- 5. trees standing in stockpiles put down whole: saved while they stand, run on
ARGS5="--square 1150 1062 0 --stockpile-box 1161.7 1062.4 6 --stockpile-box 1138.3 1062.4 2 --stockpile-box 1150.4 1073.7 0 --stockpile-box 1150.4 1050.3 4"
$BIN/colony_run --seed 1 $ARGS5 $COMMON $J13 --days 3 --box-stats > "$TMP/trees_straight.log" 2>&1
want=$(grep '^state:' "$TMP/trees_straight.log" | awk '{print $2}')
if [ "$(grep -c 'stockpile put down.*, 0.00 m of it new' "$TMP/trees_straight.log")" != 4 ]; then
  echo "FAIL: of the four stockpiles against the square at 1150 1062, $(grep -c 'stockpile put down.*, 0.00 m of it new' "$TMP/trees_straight.log") were put down along the square's own path: $(grep 'stockpile refused' "$TMP/trees_straight.log" | head -n 1 | cut -c1-120)"
  FAIL=1
fi
$BIN/colony_run --seed 1 $ARGS5 $COMMON $J13 --days 0.0625 --box-stats --save "$TMP/trees_half.castle" > "$TMP/trees_half.log" 2>&1
$BIN/colony_run --seed 1 --load "$TMP/trees_half.castle" --log-hours 1 --who --days 2.9375 --box-stats > "$TMP/trees_on.log" 2>&1
got=$(grep '^state:' "$TMP/trees_on.log" | awk '{print $2}')
standing=$(grep 'still to take out of stockpiles' "$TMP/trees_half.log" | tail -n 1 | sed 's/.*: *\([0-9]*\) trees or stumps still.*/\1/')
left=$(grep 'still to take out of stockpiles' "$TMP/trees_on.log" | tail -n 1 | sed 's/.*: *\([0-9]*\) trees or stumps still.*/\1/')
if [ -n "$want" ] && [ "$got" = "$want" ] && [ "${standing:-0}" -ge 1 ] && [ "${left:-9}" = 0 ]; then
  echo "four stockpiles with trees in them, saved after 90 colony seconds ($standing trees standing in them) and run on to three days: the straight run's state ($want), no tree left in them"
else
  echo "FAIL: stockpiles with trees in them, saved after 90 colony seconds (${standing:-?} standing) and run on: state ${got:-none}, the straight run's ${want:-none}; ${left:-?} trees left in them"
  FAIL=1
fi

# ---- 6. walled squares saved on every half minute round the lighting of their fire, run on
window() {  # X Y WAY BX BY BW
  local T="$TMP/win_$1_$2" A="--square $1 $2 $3 --stockpile-box $4 $5 $6"; mkdir -p "$T"
  $BIN/colony_run --seed 1 $A $COMMON $J13 --days 1.5 --box-stats > "$T/straight.log" 2>&1
  local want from base sec d got
  want=$(grep '^state:' "$T/straight.log" | awk '{print $2}')
  from=$(grep 'its walls were first wanted after' "$T/straight.log" | sed 's/.*first wanted after \([0-9.]*\) game hours.*/\1/')
  if [ -z "$want" ] || [ -z "$from" ]; then echo "FAIL: the square at $1 $2 had no walls wanted in a day and a half" > "$T/failed"; return; fi
  if [ "$(grep -c 'stockpile put down.*, 0.00 m of it new' "$T/straight.log")" != 1 ]; then echo "FAIL: the stockpile by the square at $1 $2 was not put down along the square's own path: $(grep 'stockpile refused' "$T/straight.log" | head -n 1 | cut -c1-120)" > "$T/failed"; return; fi
  base=$(echo "($from * 60) / 30" | bc)
  for k in -8 -7 -6 -5 -4 -3 -2 -1 0 1 2; do
    sec=$(( (base + k) * 30 ))
    d=$(echo "scale=7; $sec / 1440" | bc)
    $BIN/colony_run --seed 1 $A $COMMON $J13 --days $d --save "$T/s$sec.castle" > "$T/half$sec.log" 2>&1
    $BIN/colony_run --seed 1 --load "$T/s$sec.castle" --log-hours 1 --who --days $(echo "scale=7; 1.5 - $d" | bc) > "$T/on$sec.log" 2>&1
    got=$(grep '^state:' "$T/on$sec.log" | awk '{print $2}')
    [ "$got" = "$want" ] || echo "FAIL: the square at $1 $2 saved after $sec colony seconds (its walls first wanted after $from game hours) and run on: state ${got:-none}, the straight run's $want" >> "$T/failed"
  done
}
window 1238 1058 0 1238.4 1069.7 0 &
window 1258 1058 1 1265.76 1065.76 7 &
window 1320 980 1 1327.76 987.76 7 &
wait
if cat "$TMP"/win_*/failed 2>/dev/null | grep -q FAIL; then
  cat "$TMP"/win_*/failed | head -n 6
  FAIL=1
else
  echo "three walled squares saved on each of eleven half minutes round the lighting of their fire, when their walls are first wanted, and run on to a day and a half: the straight run's state every time"
fi

# ---- 7. a stockpile put down over the standing cart
overcart() {  # NAME X Y WAY BX BY BW
  local T="$TMP/cart_$1" A="--square $2 $3 $4 --pile-flat --later 48 stockpile-box $5 $6 $7"; mkdir -p "$T"
  $BIN/colony_run --seed 1 $A $COMMON $J13 --days 3 --box-stats --flat-scan > "$T/straight.log" 2>&1
  $BIN/colony_run --seed 1 $A $COMMON $J13 --days 2.0208334 --save "$T/half.castle" > "$T/half.log" 2>&1
  $BIN/colony_run --seed 1 --load "$T/half.castle" --pile-flat --log-hours 1 --who --days 0.9791666 > "$T/on.log" 2>&1     # (the rule is not saved)
  local want got left still dead
  want=$(grep '^state:' "$T/straight.log" | awk '{print $2}')
  got=$(grep '^state:' "$T/on.log" | awk '{print $2}')
  left=$(grep '^later.*stockpile made one level' "$T/straight.log" | sed 's/.*moved, *\([0-9]*\) columns left as they lie.*/\1/')
  still=$(grep "by the rule's own reading" "$T/straight.log" | sed 's/.*at its level, *\([0-9]*\) to move still.*/\1/' | awk '{n+=$1} END {print n+0}')
  dead=$(grep -c 'has died' "$T/straight.log")
  if [ "$(grep -c '^later.*stockpile put down' "$T/straight.log")" = 1 ] && [ "${left:-0}" -ge 32 ] && [ "$still" = 0 ] \
     && [ "$dead" = 0 ] && [ -n "$want" ] && [ "$got" = "$want" ] \
     && [ "$(grep -c "by the rule's own reading" "$T/straight.log")" -ge 1 ]; then
    echo "ok $1: $left block columns waited for the cart" > "$T/result"
  else
    echo "FAIL: a stockpile put down on the third day over the standing cart at the square at $2 $3: $(grep -c '^later.*stockpile put down' "$T/straight.log") put down ($(grep '^later.*refused' "$T/straight.log" | head -n 1 | cut -c1-80)), ${left:-no} block columns waiting for the cart at first, $still to move still a day later, $dead dead; saved half a minute after and run on: state ${got:-none}, the straight run's ${want:-none}" > "$T/result"
  fi
}
overcart a 1238 1058 0 1238.4 1046.3 4 &
overcart b 832 964 0 832.4 979 4 &
overcart c 1172 1092 0 1172.4 1080.3 4 &
wait
if cat "$TMP"/cart_*/result 2>/dev/null | grep -q FAIL || [ "$(cat "$TMP"/cart_*/result 2>/dev/null | grep -c '^ok')" != 3 ]; then
  cat "$TMP"/cart_*/result 2>/dev/null | grep FAIL | head -n 3
  [ "$(cat "$TMP"/cart_*/result 2>/dev/null | wc -l)" = 3 ] || echo "FAIL: a stockpile put down over the standing cart: not all three squares were run"
  FAIL=1
else
  echo "a stockpile put down on the third day over the standing cart at three squares ($(cat "$TMP"/cart_*/result | sed 's/ok [a-c]: \([0-9]*\) block.*/\1/' | tr '\n' ' ' | sed 's/ $//; s/ /, /g') block columns waited for it): a day later none of its ground is off its level but under the cart, nobody dead; saved half a minute after and run on, the straight run's state"
fi

rm -rf "$TMP"
exit $FAIL
