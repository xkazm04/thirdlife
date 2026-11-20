#!/bin/bash
# Lane dio-fable (day of 20 Nov 2026): the clip. Last night's scripted visit (surf_clip.walk.json + devices: along the
# village road into the parkour yard by the river, then up and over the bluff), windowed, written as a movie.
#   bash docs/shifts/2026-11-20-day/lanes/dio-fable/clip.sh <style> <out dir under .tl> [<lane mp4>]
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(cd "$HERE/../../../../.." && pwd)"; cd "$ROOT" || exit 2
style="${1:?style}"; out="${2:?out dir}"; mkdir -p "$out"; out="$(cd "$out" && pwd)"
if command -v cygpath >/dev/null 2>&1; then out="$(cygpath -m "$out")"; ROOT="$(cygpath -m "$ROOT")"; fi
SRC="$ROOT/docs/shifts/2026-11-20-night/lanes/surfaces-fable"
export TL_GODOT="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
export TL_CACHE_DIR="${TL_CACHE_DIR:-$ROOT/.tl/cache}" TL_STYLE="$style"
rm -f "$out/clip_$style.avi"
TL_WINDOW_ARGS="--write-movie $out/clip_$style.avi" bash engine/tools/world.sh visit-test "$SRC/surf_clip.walk.json" "--devices=$SRC/surf_clip.devices.json" --load=block > "$out/clip_$style.log" 2>&1
ffmpeg -v error -y -i "$out/clip_$style.avi" -an -vf scale=1280:720 -c:v libx264 -crf 21 -preset slow -pix_fmt yuv420p -t 29.5 "$out/clip_$style.mp4" && rm -f "$out/clip_$style.avi" "$out/clip_$style.wav"
[ -n "${3:-}" ] && cp "$out/clip_$style.mp4" "$3"
ffprobe -v error -show_entries format=duration,size -of default=nw=1 "$out/clip_$style.mp4"
