#!/bin/bash
# wcmp.sh <tree> <frames>: world final hash vs runner final hash at the same frames
T="$1"; N="$2"; P="$T/engine/packs/hockey"
w=$(bash "$T/engine/tools/world.sh" run --packs=$P --mode=bot --frames=$N 2>/dev/null | grep '"kind":"pack"' | grep -o '"frames":[0-9]*,"state_hash":"[0-9a-f]\{16\}')
r=$(TL_QUIET=1 bash "$T/engine/tools/tl.sh" bot --pack=$P --test=tests/bot_hockey.gd --seed=1 --frames=$N 2>/dev/null | tail -1 | grep -o '"state_hash":"[0-9a-f]\{16\}')
echo "N=$N world $w | alone $r"
