#!/bin/bash
# Lane C tool wrapper. Usage:
#   g.sh bake                      regenerate every voxel asset (python gen/build.py) -> assets/*.vxm, data/layout.json
#   g.sh import                    headless godot import
#   g.sh shot <args>               asset viewer (src/shot.gd): --vxm=a,b --yaw --pitch --dist --h --out
#   g.sh cap <cam> [extra args]    capture hero|site|track|crumble|avatar -> captures/c_<cam>.png
#   g.sh run [args]                run the scene interactively (WASD, mouse orbit, B crumble, N nitro, H site, R reset)
#   g.sh stats [extra args]        --stats (15 s of hero view, one JSON line)
#   g.sh movie [name]              20 s movie -> captures/c_<name>.mp4
#   g.sh all                       the five captures + overcast hero + stats
G="${GODOT:-/c/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
cd "$(dirname "$0")/.."
RES=${RES:-1920x1080}
GPOS=${GPOS:-0,1440}
case "$1" in
 bake) shift; python gen/build.py "$@";;
 import) timeout 300 "$G" --headless --path . --import 2>&1 | grep -i -E "error|fail" | head -30;;
 shot) shift; timeout 180 "$G" --path . --position $GPOS --resolution ${SRES:-1200x800} res://shot.tscn -- "$@" 2>&1 | grep -i -E "error|tris|warn" | head -20;;
 cap) shift; cam=$1; shift; mkdir -p captures
   timeout 300 "$G" --path . --position $GPOS --resolution $RES res://look.tscn -- --capture=$cam "$@" 2>&1 | grep -i -E "error|captured|warn" | head -20;;
 run) shift; "$G" --path . --position $GPOS --resolution $RES res://look.tscn -- "$@" 2>&1 | grep -v -E "^$|^Godot Engine|^D3D12|^Vulkan" | tail -30;;
 stats) shift; timeout 120 "$G" --path . --position $GPOS --resolution ${STATRES:-2560x1440} res://look.tscn -- --stats "$@" 2>/dev/null | grep '^{';;
 movie) shift; n=${1:-flythrough}; shift; mkdir -p captures
   timeout 1500 "$G" --path . --position $GPOS --resolution $RES --fixed-fps 60 --write-movie captures/c_$n.avi res://look.tscn -- --movie=$n "$@" 2>&1 | grep -i -E "error" | head
   ffmpeg -y -loglevel error -i captures/c_$n.avi -c:v libx264 -crf 20 -pix_fmt yuv420p captures/c_$n.mp4 && rm -f captures/c_$n.avi && ls -la captures/c_$n.mp4;;
 all) for c in hero site track crumble avatar; do "$0" cap $c; done; "$0" cap hero --style=overcast --out=hero_overcast; "$0" stats;;
esac
