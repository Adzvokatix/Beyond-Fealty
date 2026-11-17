#!/bin/bash
# The stage 5b demo (colony_stage5b_skills.mp4): skills, with a scripted pointer.
# First a band of twelve as it arrives: a forester's tooltip with its skills;
# the Skills tab (everyone's level in each working skill, bright where they
# learn it fast, boxed where it is their job's); the one with no job given
# one from its menu, which shows its level and aptitude beside each job.
# Then the same band twenty days on, from a windowless run: the levels risen.
#   tools/demo_stage5b.sh [OUT.mp4]     needs ffmpeg; writes 1,260 frames (3 GB) to a
#                                       temporary folder and deletes them after
cd "$(dirname "$0")/.." || exit 1
OUT=${1:-colony_stage5b_skills.mp4}
TMP=$(mktemp -d)
BAND="--seed 1 --stake 1178 1078 --path 1176 1076 1194 1076 --stockpile 1180 1070 1190 1075 --camp 1172 1082 --camp-built --paths-built
  --band 12 --gatherers 6 --foresters 1 --hunters 3 --cooks 1 --reserve meat 60
  --supply meat 16 --supply wood 8 --supply berries 120 --day 20 --time 7"

# as they arrive: member 7 is the forester, member 12 has no job
./bin/castle_game --float --size 1280 720 --at 1175 1071.5 --cam 2.5 0.8 30 $BAND --speed 1 \
  --record "$TMP/a" 720 --pointer "20:member 7, 150:move 1018 315, 180:click, 200:move 560 640, \
330:move 720 660, 400:rclick, 401:move 856 594, 440:click, 460:move 560 640, 560:member 12" > /dev/null || exit 1

# twenty days on (the twelfth a hunter, as the menu made it)
./bin/colony_run $BAND --job 12 hunter --days 20 --save "$TMP/twenty_days.castle" > /dev/null || exit 1
./bin/castle_game --float --size 1280 720 --load "$TMP/twenty_days.castle" --hud skills --speed 1 \
  --record "$TMP/b" 540 --pointer "30:move 560 640, 180:move 720 374, 330:move 720 660, 480:move 560 640" \
  > /dev/null || exit 1

for c in a b; do
  ffmpeg -y -loglevel error -framerate 30 -start_number 1 -i "$TMP/$c/frame_%04d.png" \
    -c:v libx264 -preset slow -crf 20 -pix_fmt yuv420p "$TMP/$c.mp4" || exit 1
done
printf "file '%s'\nfile '%s'\n" "$TMP/a.mp4" "$TMP/b.mp4" > "$TMP/list.txt"
ffmpeg -y -loglevel error -f concat -safe 0 -i "$TMP/list.txt" -c copy -movflags +faststart "$OUT"
rm -rf "$TMP"
echo "wrote $OUT"
