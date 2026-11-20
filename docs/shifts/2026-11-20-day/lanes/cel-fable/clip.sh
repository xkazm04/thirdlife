#!/bin/bash
# Lane cel-fable: the clip (30 s or less, windowed): the visitor walks the village road, then flies north and west
# over the river. Last night's scripted visit (surf_clip.walk.json + surf_clip.devices.json), so the two nights compare.
#   bash docs/shifts/2026-11-20-day/lanes/cel-fable/clip.sh <style> <out.mp4 under .tl> [crf, default 18]
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(cd "$HERE/../../../../.." && pwd)"; cd "$ROOT" || exit 2
style="${1:?style}"; out="${2:?out.mp4}"; crf="${3:-18}"
mkdir -p "$(dirname "$out")"; outd="$(cd "$(dirname "$out")" && pwd)"; out="$outd/$(basename "$out")"
if command -v cygpath >/dev/null 2>&1; then out="$(cygpath -m "$out")"; ROOT="$(cygpath -m "$ROOT")"; fi
N="$ROOT/docs/shifts/2026-11-20-night/lanes/surfaces-fable"
export TL_GODOT="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
export TL_CACHE_DIR="${TL_CACHE_DIR:-$ROOT/.tl/cache}" TL_STYLE="$style"
avi="${out%.mp4}.avi"; rm -f "$avi"
TL_WINDOW_ARGS="--write-movie $avi" bash engine/tools/world.sh visit-test "$N/surf_clip.walk.json" "--devices=$N/surf_clip.devices.json" --load=block > "${out%.mp4}.log" 2>&1
ffmpeg -v error -y -i "$avi" -an -c:v libx264 -crf "$crf" -pix_fmt yuv420p -vf scale=1280:720 "$out" && rm -f "$avi" "${avi%.avi}.wav"
ffprobe -v error -show_entries format=duration -of csv=p=0 "$out"
