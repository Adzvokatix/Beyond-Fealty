#!/bin/bash
# A stockyard on rising ground must never leave its builder in a pit: the band
# of thirteen with housing, the stockpile and a stockyard on two sites of seed 1
# where one dug by rows from the path starved its builder (2026-11-18: beside a
# path aslant up the hillside east of the reference stake; and the largest
# stockyard, 25 m a side, on the same hillside), eighteen days each.  It fails
# if the storehouse does not stand by then or anyone has starved or died.
# And a third site since 2026-11-19, when paths came to be ordered straight or
# at 45 degrees: a stockyard beside a path at 45 degrees, on the flat south-west
# of the stake (one corner of its box at the path).  On the hillside no box of
# ten tried beside the 45-degree line is taken (the storehouse would stand more
# than 2 m off its path, or the ground falls too far): that site's slant is
# kept as it was found, with --no-path-snap.
# Since 2026-11-20 (his word: "go on with the second way for the stockyard") a
# stockyard beside a path at 45 degrees is laid out along the path, its
# storehouse drawn turned and walked where it is drawn: the third site is as
# it was with --no-yard-turn, and three more are laid out along their paths:
# on the flat; the least there is (15 m by 15 m) on ground that falls 3 m, with
# a stair to its way in; and the largest (25 m by 25 m).  Those three fail too
# if any block column of the yard's ground is off its level or grown over, if
# anyone stood in a wall as the storehouse is drawn, or if nobody was within
# it or walked where its blocks stand (colony_run --turn-stats).
# Since 2026-11-21 (his "For the stockyard, lets expand the zones to 20x20")
# the player's stockyard is put down whole, twenty metres square with its path
# (--stockyard-box X Y WAY): three more sites, each held along a path that is
# there: on the hillside (the storehouse takes thirteen days of the eighteen);
# along the path at 45 degrees on the flat; and along the one that falls,
# on its other side (on the side the least stockyard lies, no box of twenty
# metres is taken: its ground falls more than a storehouse's may).  Those
# fail too unless all four hundred places are taken and the storehouse fronts
# the stockyard's own path (colony_run --box-stats).
# Since the storehouse is 12 m by 8 m and stands a metre and a half from its
# path (his "8x12", the same day; 3.5 m beside a path at 45 degrees, where its
# own blocks would otherwise stand on the path): the first six sites, and the
# box on the hillside, keep the storehouse of before (--storehouse 10 5 4.5:
# they are tests of ground that the new one is refused on, its floor too far
# off its path's level for the three steps a metre and a half leaves; the two
# least stockyards along a path at 45 degrees are too small for it); the two
# boxes along the paths at 45 degrees have the new one, and two more sites
# with it: a box south of the west path, squarely, and the largest stockyard
# of two corners along the path at 45 degrees.  Every site fails now too
# unless the lord's cart is brought before the storehouse and its salt
# carried in (it was not, at four of the nine, until its place was looked
# for), and unless every block column the storehouse's own blocks stand in
# is its stockyard's ground.
# Each member's state is printed each hour (--who --log-hours 1; twice a day
# until 2026-11-21 noon, which an hour at nothing could fall between).
# Since the evening of 2026-11-21 (his "I was talking about the stockyard
# having the stair in the corner rather than the middle"): a stockyard whose
# way in across the staging would have steps has its way in at an end of its
# front instead, in a corner of the zone.  Every site fails now if a stair
# stands at the middle of its storehouse's front, if any spot on its ground
# or within 2 m of it can be got to from the fire and not back (a pit:
# colony_run --yard-pits), or if there is no way from the fire to the middle
# of the storehouse's floor and back.  The hillside sites of before (the
# storehouse of before, 4.5 m of staging) have the path level at one end of
# their front and over two metres off the floor at the other, or no path
# there: they have no stair now, and their way in is the level end.  Three
# more sites, each a square with a stockyard put down whole against a side
# where the storehouse of 12 m by 8 m had steps before it: seven steps down
# in the far corner from a level one (squarely, and along a path at 45
# degrees), and five steps up from a path under the floor; they fail unless
# the stair is as long as that and at an end of the front.
# Since 2026-11-22 (his "Set the floors level of the stockyard to the path
# level at the lower corner, the higher corner along the path gets the
# stairs", and "After 2m no stair built"): a levelled stockyard's floor lies
# at its path's level at the lower corner of its front, whatever the land
# does under the rest of it, and its stair stands at the higher corner.  The
# three sites with a stair have other stairs for it (the floor a block lower
# south of the square at 1238 1058: eight steps for seven; west of the one
# at 860 880 the floor is the lower corner's now, five blocks down, and the
# stair comes down three steps at the other corner where it went up five).
# Three more sites: the box on the hillside with the storehouse of 12 m by
# 8 m, which was refused until then (its floor at the path's level at the
# low corner, the other corner two and a half metres over it: no stair);
# east of a square at 820 960, refused until then too (five steps); and
# north of one at 840 820, its floor six blocks lower than the land chose,
# the far corner over two metres: no stair.  **At those three no place
# before the storehouse takes the lord's cart** (the staging is a metre and
# a half, its rim a wall where the path stands over it, and the cart's bed
# wants a block clear of anything higher on every side): it stays where it
# stood, the runner says so, and a site told --no-cart-place fails unless
# it does; every other site still fails unless the cart is brought before
# the storehouse and its salt carried in.
#   tools/stockyard_sites.sh      (about three minutes, release; exits 1 on a failure)
#   BIN=dir   another build's bin directory
cd "$(dirname "$0")/.." || exit 1
BIN=${BIN:-./bin}
TMP=$(mktemp -d)
FAIL=0
BAND="--seed 1 --stake 1178 1078 --path 1176 1076 1194 1076 --camp 1172 1082 --day 20 --time 7 --winter-store 10 --reserve meat 60 --band 13 --gatherers 4 --foresters 3 --porters 2 --hunters 3 --cooks 1 --path 1176 1076 1140 1076 --housing 1141 1077 1167 1087 --housing 1141 1075 1175 1065 --stockpile 1180 1075 1190 1065"
# (the same band without the housing south of the west path, which the third site's path runs through)
BAND_SW="--seed 1 --stake 1178 1078 --path 1176 1076 1194 1076 --camp 1172 1082 --day 20 --time 7 --winter-store 10 --reserve meat 60 --band 13 --gatherers 4 --foresters 3 --porters 2 --hunters 3 --cooks 1 --path 1176 1076 1140 1076 --housing 1141 1077 1167 1087 --stockpile 1180 1075 1190 1065"
# (a band of thirteen with no stake of its own: for a site that founds its colony on a square)
BAND_SQ="--seed 1 --day 20 --time 7 --winter-store 10 --reserve meat 60 --band 13 --gatherers 4 --foresters 3 --porters 2 --hunters 3 --cooks 1"
site() {  # NAME OPTIONS...
  local name=$1; shift
  local band=$BAND
  if [ "$1" = "--band-sw" ]; then band=$BAND_SW; shift; fi
  if [ "$1" = "--band-sq" ]; then band=$BAND_SQ; shift; fi
  local steps=""                       # (--steps N: its stair is to have N block columns of steps, at an end of its front)
  if [ "$1" = "--steps" ]; then steps=$2; shift 2; fi
  local nocart=0                       # (--no-cart-place: no place before its storehouse takes the lord's cart, and it says so)
  if [ "$1" = "--no-cart-place" ]; then nocart=1; shift; fi
  local along=0 box=0 walls="40 by 20"
  if [ "$1" = "--along" ]; then along=1; shift; fi
  if [ "$1" = "--box" ]; then box=1; shift; fi
  if [ "$1" = "--new" ]; then walls="48 by 32"; shift; else set -- "$@" --storehouse 10 5 4.5; fi
  $BIN/colony_run $band "$@" --days 18 --log-hours 1 --who --turn-stats --box-stats --yard-walls --yard-pits > "$TMP/$name.log" 2>&1
  local starving living standing
  starving=$(grep -c 'starving\|has died of hunger' "$TMP/$name.log")
  local empty        # (member-hours with an empty belly: counted and said, not failed on)
  empty=$(grep -c '^  who: [A-Za-z]*, *-\{0,1\}0 % fed: .*(at [-0-9.]* [-0-9.]* [-0-9.]*)$' "$TMP/$name.log")
  living=$(grep '^colony:' "$TMP/$name.log" | tail -n 1 | grep -o '[0-9]* living')
  standing=$(grep -c 'storehouse: on the stockyard, standing' "$TMP/$name.log")
  # (laid out along its path: its ground, and who walked where)
  local turned line off grown within blocks wall
  line=$(grep '^  the storehouse, drawn turned' "$TMP/$name.log")
  turned=$(echo "$line" | grep -c 'STANDING')
  off=$(echo "$line" | sed -n 's/.* \([0-9]*\) not at their level.*/\1/p')
  grown=$(echo "$line" | sed -n 's/.* \([0-9]*\) with something growing over.*/\1/p')
  within=$(echo "$line" | sed -n 's/.*within it \([0-9]*\),.*/\1/p')
  blocks=$(echo "$line" | sed -n 's/.*where its blocks stand \([0-9]*\),.*/\1/p')
  wall=$(echo "$line" | sed -n 's/.*in a wall as drawn \([0-9]*\);.*/\1/p')
  # (put down whole: all of its places, and its storehouse before its own path)
  local whole fronts
  whole=$(grep -c 'stockyard put down: 400 places' "$TMP/$name.log")
  fronts=$(grep -c '^storehouse at the end: .*it fronts its stockyard.s own path' "$TMP/$name.log")
  # (its walls as asked, its own blocks all on its own ground; the cart before it, its salt inside)
  local size own cart salt
  size=$(grep -c "^storehouse at the end: walls $walls blocks" "$TMP/$name.log")
  own=$(grep '^storehouse at the end' "$TMP/$name.log" | sed -n 's/.*; \([0-9]*\) block columns its own blocks stand in are not.*/\1/p')
  cart=$(grep -c '^cart at the end: .*before the storehouse' "$TMP/$name.log")
  local noplace                        # (no place before the storehouse takes it: it stays where it is, said and not failed)
  noplace=$(grep -c "^cart at the end: .*no place by its storehouse's front takes it" "$TMP/$name.log")
  salt=$(grep '^salt' "$TMP/$name.log" | tail -n 1 | sed -n 's/^salt: \([0-9]*\) lb in the cart.*/\1/p')
  # (where its way in is, its stair, pits on its ground, the way from the fire into the storehouse)
  local stone way cols pits inout wayword
  stone=$(grep "^stockyard's stone at the end" "$TMP/$name.log")
  way=$(echo "$stone" | sed -n "s/.*its way in at \(the middle of the storehouse's front\|its front's low end\|its front's high end\),.*/\1/p")
  cols=$(echo "$stone" | sed -n 's/.*of *\([0-9]*\) columns of steps.*/\1/p')
  pits=$(grep '^yard pits: of' "$TMP/$name.log" | sed -n 's/.*from the fire, *\([0-9]*\) cannot be got back from.*/\1/p')
  inout=$(grep '^yard pits: of' "$TMP/$name.log" | grep -c 'no way')
  wayword="its way in at $way, $( [ "${cols:-0}" = 0 ] && echo "no stair" || echo "$cols block columns of steps" ), no pit$( [ "$noplace" = 1 ] && echo "; no place before the storehouse takes the lord's cart" )"
  if [ -z "$way" ] || [ -z "$cols" ] || [ "${pits:-9}" != 0 ] || [ "$inout" != 0 ]; then
    echo "FAIL: $name: its way in '${way:-not said}', ${cols:-?} block columns of steps; ${pits:-?} spots on its ground or by it that can be got to from the fire and not back; $(grep '^yard pits: of' "$TMP/$name.log" | sed 's/.*; from the fire/from the fire/')"
    touch "$TMP/failed"
  elif [ "$way" = "the middle of the storehouse's front" ] && [ "$cols" != 0 ]; then
    echo "FAIL: $name: a stair of $cols block columns stands at the middle of its storehouse's front (a stockyard's stair stands in a corner of the zone)"
    touch "$TMP/failed"
  elif [ -n "$steps" ] && { [ "$cols" != "$steps" ] || [ "$way" = "the middle of the storehouse's front" ]; }; then
    echo "FAIL: $name: its stair has $cols block columns of steps at $way ($steps wanted, at an end of its front)"
    touch "$TMP/failed"
  elif [ "$starving" != 0 ] || [ "$living" != "13 living" ] || [ "$standing" -le 0 ]; then
    echo "FAIL: $name: $starving lines of someone starving, $living, storehouse standing in $standing lines"
    touch "$TMP/failed"            # (each site runs in a shell of its own)
  elif [ $box = 1 ] && { [ "$whole" != 1 ] || [ "$fronts" != 1 ]; }; then
    echo "FAIL: $name: put down whole with its four hundred places $whole (wanted 1), its storehouse fronting its own path $fronts (wanted 1): $(grep -E 'stockyard (put down|refused)|^storehouse at the end' "$TMP/$name.log" | cut -c1-200 | tr '\n' ' ')"
    touch "$TMP/failed"
  elif [ "$size" != 1 ] || [ "${own:-9}" != 0 ]; then
    echo "FAIL: $name: its storehouse's walls $walls: $size (wanted 1); block columns of its own that are not its stockyard's ground: ${own:-?}"
    touch "$TMP/failed"
  elif [ "$noplace" != 1 ] && { [ "$cart" != 1 ] || [ "${salt:-9}" != 0 ]; }; then
    echo "FAIL: $name: the lord's cart before the storehouse $cart (wanted 1), ${salt:-?} lb of salt still in it: $(grep '^cart at the end' "$TMP/$name.log" | cut -c1-120)"
    touch "$TMP/failed"
  elif [ "$noplace" = 1 ] && [ "$nocart" != 1 ]; then
    echo "FAIL: $name: no place before its storehouse takes the lord's cart (one was to be found here): $(grep '^cart at the end' "$TMP/$name.log" | cut -c1-160)"
    touch "$TMP/failed"
  elif [ $along = 0 ] && [ "$turned" = 0 ]; then
    echo "$name: the storehouse stands, nobody died or was said to be starving ($empty member-hours with an empty belly); $wayword"
  elif [ $along = 1 ] && [ "$turned" = 1 ] && [ "$off" = 0 ] && [ "$grown" = 0 ] && [ "$wall" = 0 ] \
       && [ "${within:-0}" -gt 0 ] && [ "${blocks:-0}" -gt 0 ]; then
    echo "$name: the storehouse stands drawn turned, nobody died or was said to be starving ($empty member-hours with an empty belly); its ground all at its level; in serf-seconds, within it as drawn $within, where its blocks stand $blocks, in a wall as drawn $wall; $wayword"
  else
    echo "FAIL: $name: the storehouse stands, but: laid out along its path $turned (wanted $along), ground off its level ${off:-?}, grown over ${grown:-?}, in a wall as drawn ${wall:-?}, within it ${within:-?}, where its blocks stand ${blocks:-?}"
    touch "$TMP/failed"
  fi
}
# (the first is the slant it was found on, 35 degrees: laid as it is given, --no-path-snap)
site "beside a path aslant up the hillside" --no-path-snap --path 1194 1076 1214 1090 --stockyard 1196 1076 1212 1060 &
site "beside a path at 45 degrees on the flat, square to the grid (--no-yard-turn)" --band-sw --no-yard-turn --path 1176 1076 1146 1046 --stockyard 1162 1061 1178 1045 &
site "the largest stockyard on the hillside" --path 1194 1076 1224 1076 --stockyard 1196 1075 1221 1050 &
# (laid out along the path: the two corners given span whole metres along and across the path's way; tools/yard_corners.py works them out)
site "along a path at 45 degrees on the flat" --band-sw --along --path 1176 1076 1146 1046 --stockyard 1154.42 1052.17 1176.20 1052.17 &
site "along a path at 45 degrees on ground that falls 3 m, the least there is" --along --path 1194 1076 1224 1046 --stockyard 1206.04 1065.61 1226.41 1065.61 &
wait
site "along a path at 45 degrees on the flat, the largest there is" --band-sw --along --path 1176 1076 1146 1046 --stockyard 1147.35 1045.10 1181.86 1045.10 &
# (put down whole, twenty metres square, held along the path that is there)
site "put down whole on the hillside" --box --path 1194 1076 1224 1076 --stockyard-box 1209 1065.5 4 &
site "put down whole along a path at 45 degrees on the flat, the storehouse 12 m by 8 m" --band-sw --along --box --new --path 1176 1076 1146 1046 --stockyard-box 1168.4 1053.6 5 &
site "put down whole along a path at 45 degrees that falls, the storehouse 12 m by 8 m" --along --box --new --path 1194 1076 1224 1046 --stockyard-box 1207.8 1047.4 3 &
wait
site "put down whole south of the west path, the storehouse 12 m by 8 m" --band-sw --box --new --stockyard-box 1158 1065.5 4 &
site "the largest along a path at 45 degrees on the flat, the storehouse 12 m by 8 m" --band-sw --along --new --path 1176 1076 1146 1046 --stockyard 1147.35 1045.10 1181.86 1045.10 &
wait
# (its stair in a corner of the zone: a square, a stockpile on another side of it, the stockyard against a side where
# the path lies level at one end of its front and far off its floor at the other)
site "south of a square, its path level at one corner and eight blocks over its floor at the other" --band-sq --steps 64 --box --new --square 1238 1058 0 --stockpile-box 1238.4 1070.4 0 --stockyard-box 1238 1041 4 &
site "west of a square, its path level at one corner and three blocks over its floor at the other" --band-sq --steps 24 --box --new --square 860 880 0 --stockpile-box 860.4 892.4 0 --stockyard-box 843.25 880 2 &
site "along a square's path at 45 degrees, level at one corner and eight blocks over its floor at the other" --band-sq --steps 66 --along --box --new --square 840 840 1 --stockpile-box 831.4 831.4 3 --stockyard-box 851.92 851.92 7 &
wait
# (its floor at its path's level at the lower corner of its front, 2026-11-22: ground the rule before refused, and a far
# corner over two metres)
site "put down whole on the hillside, the storehouse 12 m by 8 m (refused until 2026-11-22): no stair, its far corner over two metres" --no-cart-place --box --new --path 1194 1076 1224 1076 --stockyard-box 1209 1065.5 4 &
site "east of a square, refused until 2026-11-22: its path level at one corner and five blocks over its floor at the other" --band-sq --steps 40 --no-cart-place --box --new --square 820 960 0 --stockpile-box 820.4 972.4 0 --stockyard-box 836.75 960 6 &
site "north of a square, its floor six blocks under the land's own choice, its far corner over two metres: no stair" --band-sq --no-cart-place --box --new --square 840 820 0 --stockpile-box 839.6 807.6 4 --stockyard-box 840 836.75 0 &
wait
[ -e "$TMP/failed" ] && FAIL=1
rm -rf "$TMP"
exit $FAIL
