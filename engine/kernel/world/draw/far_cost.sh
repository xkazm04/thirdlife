#!/bin/bash
# P6, item 5: what each picture of a game costs to draw. N packs on a 140 m grid (the six of N5b's cost table,
# cycled), every pack played by its bot, the crane over the whole grid, 1920x1080, one picture per run:
#   near   every pack drawn in full
#   still  N5b's stand-in for every pack but the stage pack (TL_DRAW_PICTURE=still)
#   mid    the middle picture for every pack but the stage pack
#   far    the far picture for every pack but the stage pack
# Pack 0 is the stage pack and is always drawn in full. One line per run:
#   <packs> <picture> draw_calls primitives objects frame_ms render_cpu_ms render_gpu_ms draw_layer_ms marks
# A run whose frame time is above 60 ms was throttled by another window on this machine: its times are not valid
# (draw calls and primitives are).
#   bash far_cost.sh <abs out dir> [sizes, default "6 12 30"] [pictures, default "near still mid far"]
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$1"; SIZES="${2:-6 12 30}"; PICS="${3:-near still mid far}"
[ -z "$OUT" ] && { sed -n '2,13p' "$0"; exit 2; }
mkdir -p "$OUT"
NAMES=(seed_drive seed_paddle seed_wall ex_kit ex_walker ex_car)
RADII=(64 40 38 40 30 40)
num() { grep -o "\"$1\":[0-9.]*" | head -1 | cut -d: -f2; }
for n in $SIZES; do
  packs=""; radii=""
  for ((i = 0; i < n; i++)); do
    packs="${packs:+$packs,}${NAMES[$((i % 6))]}"; radii="${radii:+$radii,}${RADII[$((i % 6))]}"
  done
  for pic in $PICS; do
    if [ "$pic" = near ]; then mode=off; force=""; else mode=all; force="$pic"; fi
    line="$(TL_DRAW_PICTURE="$force" TL_VIEW_TIMEOUT=240 bash "$HERE/../../../tools/view.sh" shot "--packs=$packs" --spacing=140 "--radius=$radii" \
      --stage=0 --cam=overview --frame=240 --measure=120 "--standins=$mode" "--out=$OUT/cost_${n}_${pic}.png" | grep '"schema":"tl.view/1"' | head -1)"
    echo "$line" > "$OUT/cost_${n}_${pic}.json"
    echo "$n $pic $(echo "$line" | num draw_calls) $(echo "$line" | num primitives) $(echo "$line" | num objects) $(echo "$line" | num frame_ms_p50) $(echo "$line" | num render_cpu_ms_p50) $(echo "$line" | num render_gpu_ms_p50) $(echo "$line" | num sync_ms_p50) $(echo "$line" | num marks)"
  done
done
