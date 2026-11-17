#!/bin/bash
# The stage 5a demo (colony_stage5a_scaffold.mp4): a minute in the development
# view with a scripted pointer.  Tooltips on a person, the stockpile and the
# camp; a job changed from a person's menu; a reserve stepped from the
# stockpile's; a path laid from the ground's; the band panel's tabs; its list
# scrolled, a line's tooltip and menu.
#   tools/demo_stage5a.sh [OUT.mp4]     needs ffmpeg; writes 1,800 frames (4.5 GB) to a
#                                       temporary folder and deletes them after
cd "$(dirname "$0")/.." || exit 1
OUT=${1:-colony_stage5a_scaffold.mp4}
FRAMES=$(mktemp -d)
POINTER=$(cat <<'END' | grep -v '^ *#' | tr -d '\n"'
  # a person's tooltip (the forester)
  "30:member 3,"
  # her menu: make her a gatherer
  "150:rclick, 151:rel 96 86, 185:click,"
  # away, then back on her once she is clear of the crowd at the stake
  "200:move 250 250, 270:member 3,"
  # the stockpile: its tooltip
  "345:ground 1185.5 1072.5,"
  # its menu: the meat reserve up twice, then Esc
  "455:rclick, 456:rel 56 118, 485:click, 515:click, 555:esc,"
  # the camp's tooltip
  "575:ground 1172 1082,"
  # the ground's menu: a path from here, two legs, Esc ends the line
  "705:move 250 470, 735:rclick, 736:rel 150 54, 765:click, 780:move 330 600, 825:click, 835:move 200 640, 875:click, 895:esc,"
  # the band panel's tabs: Stores, Camp, Orders (the winter store up twice), Band
  "915:move 788 359, 945:click, 1025:move 865 359, 1055:click, 1125:move 941 359, 1155:click, 1185:move 724 545, 1215:click, 1235:click, 1275:move 712 359, 1305:click,"
  # the list: scroll to its end, a line's tooltip, its menu, a job
  "1335:move 950 540, 1365:wheel -1, 1395:wheel -1, 1425:wheel -1, 1445:move 740 600, 1545:rclick, 1546:move 836 530, 1585:click,"
  # and that person in the world
  "1625:member 13,"
END
)
./bin/castle_game --float --size 1280 720 --at 1175 1071.5 --cam 2.5 0.8 30 --seed 1 \
  --stake 1178 1078 --path 1176 1076 1194 1076 --stockpile 1180 1070 1190 1075 --camp 1172 1082 --camp-built --paths-built \
  --band 16 --gatherers 2 --foresters 1 --hunters 2 --cooks 1 \
  --supply meat 16 --supply wood 8 --supply berries 120 --day 20 --time 7 --speed 1 \
  --record "$FRAMES" 1800 --pointer "$POINTER" || exit 1
ffmpeg -y -loglevel error -framerate 30 -start_number 1 -i "$FRAMES/frame_%04d.png" \
  -c:v libx264 -preset slow -crf 20 -pix_fmt yuv420p -movflags +faststart "$OUT"
rm -rf "$FRAMES"
echo "wrote $OUT"
