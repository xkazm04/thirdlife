#!/bin/bash
# Lane dio-fable (day of 20 Nov 2026): are the surfaces calm in motion? Last night's measure, on today's textures.
#   bash docs/shifts/2026-11-20-day/lanes/dio-fable/crawl.sh <style> <out dir under .tl>
# The visitor stands on the village road by the parkour yard and the view turns one mouse pixel (0.15 degrees) every
# 11 ticks (last night's surf_pan.walk.json + surf_pan.devices.json). engine/rigs/review/boil.py: mean change per frame
# in grey levels / share of pixels that change by more than 24 in one frame, in two bands: far land and yard
# (rows 380..640), near land (rows 700..1040). 1920x1080, x264 crf 4.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(cd "$HERE/../../../../.." && pwd)"; cd "$ROOT" || exit 2
style="${1:?style}"; out="${2:?out dir}"; mkdir -p "$out"; out="$(cd "$out" && pwd)"
if command -v cygpath >/dev/null 2>&1; then out="$(cygpath -m "$out")"; ROOT="$(cygpath -m "$ROOT")"; fi
PAN="$ROOT/docs/shifts/2026-11-20-night/lanes/surfaces-fable"
export TL_GODOT="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
export TL_CACHE_DIR="${TL_CACHE_DIR:-$ROOT/.tl/cache}" TL_STYLE="$style"
rm -f "$out/land_$style.avi"
TL_WINDOW_ARGS="--write-movie $out/land_$style.avi" bash engine/tools/world.sh visit-test "$PAN/surf_pan.walk.json" "--devices=$PAN/surf_pan.devices.json" --load=block > "$out/land_$style.log" 2>&1
ffmpeg -v error -y -i "$out/land_$style.avi" -an -c:v libx264 -crf 4 -pix_fmt yuv420p "$out/land_$style.mp4" && rm -f "$out/land_$style.avi" "$out/land_$style.wav"
echo "$style land far:  $(python engine/rigs/review/boil.py "$out/land_$style.mp4" 80 370 380 640)"
echo "$style land near: $(python engine/rigs/review/boil.py "$out/land_$style.mp4" 80 370 700 1040)"
