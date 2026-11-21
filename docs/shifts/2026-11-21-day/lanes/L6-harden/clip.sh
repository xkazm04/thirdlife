#!/bin/bash
# Lane L6 (day of 21 Nov 2026; L1's clip.sh of the night): a windowed clip of the visitor walking into things (world.sh visit-test with the engine's
# movie writer, as cel-fable's clip.sh of 20 Nov).
#   bash docs/shifts/2026-11-21-day/lanes/L6-harden/clip.sh <name: lot_clip | road_clip> <out.mp4> [crf]
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(cd "$HERE/../../../../.." && pwd)"; cd "$ROOT" || exit 2
name="${1:?name}"; out="${2:?out.mp4}"; crf="${3:-20}"
mkdir -p "$(dirname "$out")"; outd="$(cd "$(dirname "$out")" && pwd)"; out="$outd/$(basename "$out")"
H="$HERE"
if command -v cygpath >/dev/null 2>&1; then out="$(cygpath -m "$out")"; H="$(cygpath -m "$H")"; fi
export TL_GODOT="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
avi="${out%.mp4}.avi"; rm -f "$avi"
TL_WINDOW_ARGS="--write-movie $avi" bash engine/tools/world.sh visit-test "$H/$name.walk.json" "--devices=$H/$name.devices.json" --load=block > "${out%.mp4}.log" 2>&1
ffmpeg -v error -y -i "$avi" -an -c:v libx264 -crf "$crf" -pix_fmt yuv420p -vf scale=1280:720 "$out" && rm -f "$avi" "${avi%.avi}.wav"
ffprobe -v error -show_entries format=duration -of csv=p=0 "$out"
