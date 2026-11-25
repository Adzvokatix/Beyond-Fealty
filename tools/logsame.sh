#!/bin/bash
# logsame.sh A B: two runs' logs line for line, apart from the state's hash (a blob bump moves it), the timings, and
# what the newer runner adds to the storehouse's line and says of the cart
f() { grep -v -E "^state:|^ran |ground in,|^cart (at|as)" "$1" | sed -E 's/;[ 0-9]+ block columns its own blocks stand in.*//; s/ blocks \([0-9]+ blocks in its blueprint, [0-9]+ logs, [0-9]+ sheaves, [0-9]+ stones\);/ blocks;/'; }
if [ "$(f "$1" | md5sum)" = "$(f "$2" | md5sum)" ]; then echo "the same, $(f "$1" | wc -l) lines"; else echo "DIFFER: $(diff <(f "$1") <(f "$2") | head -n 4 | cut -c1-160 | tr '\n' '|')"; fi
