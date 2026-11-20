#!/bin/bash
# Lane surfaces-fable (night of 20 Nov 2026): does the detail crawl? Two slow-pan clips per style, measured with
# engine/rigs/review/boil.py (mean change per frame, share of pixels that change by more than 24 grey levels).
#   bash docs/shifts/2026-11-20-night/lanes/surfaces-fable/crawl.sh <style> <out dir under .tl>
#   review  look.sh clip rig:idle:0:0.83:behind with --thin=1 (the walker-feel measure: a quarter of a pixel a frame over
#           thin members and a kit floor), bands: horizon (rows 200..420) and floor (rows 620..1000)
#   land    the visitor stands on the village road by the parkour yard and the view turns one mouse pixel (0.15 degrees)
#           every 11 ticks (surf_pan.walk.json + surf_pan.devices.json), bands: far land and yard (rows 380..640)
#           and near land (rows 700..1040)
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(cd "$HERE/../../../../.." && pwd)"; cd "$ROOT" || exit 2
style="${1:?style}"; out="${2:?out dir}"; mkdir -p "$out"; out="$(cd "$out" && pwd)"
if command -v cygpath >/dev/null 2>&1; then out="$(cygpath -m "$out")"; ROOT="$(cygpath -m "$ROOT")"; HERE="$(cygpath -m "$HERE")"; fi
export TL_GODOT="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
export TL_CACHE_DIR="${TL_CACHE_DIR:-$ROOT/.tl/cache}" TL_STYLE="$style"
CLIP_RES=1920x1080 CLIP_CRF=4 RIG_ARGS="--thin=1" bash engine/tools/look.sh clip rig:idle:0:0.83:behind "$out/review_$style.mp4" 150 >/dev/null 2>&1
echo "$style review horizon: $(python engine/rigs/review/boil.py "$out/review_$style.mp4" 40 145 200 420)"
echo "$style review floor:   $(python engine/rigs/review/boil.py "$out/review_$style.mp4" 40 145 620 1000)"
rm -f "$out/land_$style.avi"
TL_WINDOW_ARGS="--write-movie $out/land_$style.avi" bash engine/tools/world.sh visit-test "$HERE/surf_pan.walk.json" "--devices=$HERE/surf_pan.devices.json" --load=block > "$out/land_$style.log" 2>&1
ffmpeg -v error -y -i "$out/land_$style.avi" -an -c:v libx264 -crf 4 -pix_fmt yuv420p "$out/land_$style.mp4" && rm -f "$out/land_$style.avi" "$out/land_$style.wav"
echo "$style land far:  $(python engine/rigs/review/boil.py "$out/land_$style.mp4" 80 370 380 640)"
echo "$style land near: $(python engine/rigs/review/boil.py "$out/land_$style.mp4" 80 370 700 1040)"
