#!/bin/bash
# The game as it is played today must be the game of the kept log: 41 days of tools/today_run.sh,
# line for line with docs/production/reference_runs/today_41_days.txt.
#
#   tools/today_check.sh [extra colony_run options]      (about a minute; exits 1 on a difference)
#   tools/today_check.sh --record                        writes the kept log anew
#
# What it is for.  The eight reference logs (tools/reference_check.sh) prove that the game with
# its newer rules switched off is still the game of each older stage; none of them founds a
# square, puts down a stockyard or runs a rule made since 2026-11-17 (docs/systems/switches.md).
# This one log is every rule on.  So:
#   a change that is not about what the game does leaves it passing, with nothing recorded again;
#   a new rule, on by default, makes it fail: first show that with the new rule's switch off it
#     passes (tools/today_check.sh --no-the-new-rule), then record it again in the rule's own
#     commit (--record) and say in the commit what moved.
# Then the same game saved on its twentieth day, loaded and run on: it must end in the state of
# the straight run (a save of the game as it is played loads in the build that made it).
# The lines that time the run are left out.  The state's hash is compared apart: a change to the
# colony's blob moves it and nothing else, and the script says which of the two it found.
cd "$(dirname "$0")/.." || exit 1
KEPT=docs/production/reference_runs/today_41_days.txt
strip() { grep -v '^ran \|^world \|^state: '; }
if [ "$1" = "--record" ]; then
  shift
  tools/today_run.sh 41 "$@" > "$KEPT" || { echo "the run failed: nothing kept"; exit 1; }
  echo "recorded: $KEPT ($(wc -l < "$KEPT") lines; $(grep '^state: ' "$KEPT"))"
  exit 0
fi
NOW=$(mktemp)
tools/today_run.sh 41 "$@" > "$NOW" 2>&1 || { echo "FAIL: the run of the game as it is played did not end well"; tail -n 3 "$NOW"; rm -f "$NOW"; exit 1; }
if diff <(strip < "$KEPT") <(strip < "$NOW") > /dev/null; then
  if [ "$(grep '^state: ' "$KEPT")" = "$(grep '^state: ' "$NOW")" ]; then
    echo "the game as it is played, 41 days: the kept log line for line, and its state ($(grep '^state: ' "$NOW" | cut -d' ' -f2))"
  else
    echo "the game as it is played, 41 days: the kept log line for line; the state's hash is another ($(grep '^state: ' "$NOW" | cut -d' ' -f2) for $(grep '^state: ' "$KEPT" | cut -d' ' -f2): the blob has moved)"
  fi
  # A save of it loads, and runs on to the same end (since 2026-11-23, when every save in which a
  # hovel with the fuller truss stood was refused by the build that made it, and nothing of the
  # gate had saved one).  Saved on its twentieth day, hovels standing and the storehouse too,
  # loaded, run on to the forty-first: the state of the straight run just made.
  SAVE=$(mktemp --suffix=.castle); ON=$(mktemp)
  tools/today_run.sh 20 "$@" --save "$SAVE" > /dev/null 2>&1 \
    && "${BIN:-./bin}/colony_run" --seed 1 --load "$SAVE" --days 21 --log-hours 24 "$@" > "$ON" 2>&1
  if [ -n "$(grep '^state: ' "$ON")" ] && [ "$(grep '^state: ' "$ON")" = "$(grep '^state: ' "$NOW")" ]; then
    echo "saved on its twentieth day, loaded and run on to the forty-first: the straight run's state"
    rm -f "$NOW" "$SAVE" "$ON"; exit 0
  fi
  echo "FAIL: saved on its twentieth day and loaded, it does not run on to the straight run's state: $(grep 'load failed\|^state: ' "$ON" | head -n 1 | cut -c1-120)"
  rm -f "$NOW" "$SAVE" "$ON"; exit 1
fi
echo "FAIL: the game as it is played differs from the kept log; the first lines that do:"
diff <(strip < "$KEPT") <(strip < "$NOW") | head -n 6 | cut -c1-220
rm -f "$NOW"; exit 1
