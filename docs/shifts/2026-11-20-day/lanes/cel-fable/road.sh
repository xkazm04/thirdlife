#!/bin/bash
# Lane cel-fable: the village road as the visitor sees it (cel-astra's walk and devices: the frame beside board 2).
#   bash docs/shifts/2026-11-20-day/lanes/cel-fable/road.sh <style> <out.png under .tl>
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(cd "$HERE/../../../../.." && pwd)"; cd "$ROOT" || exit 2
style="${1:?style}"; out="${2:?out.png}"; mkdir -p "$(dirname "$out")"; outd="$(cd "$(dirname "$out")" && pwd)"
if command -v cygpath >/dev/null 2>&1; then outd="$(cygpath -m "$outd")"; ROOT="$(cygpath -m "$ROOT")"; fi
A="$ROOT/docs/shifts/2026-11-20-day/lanes/cel-astra"
export TL_GODOT="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
export TL_CACHE_DIR="${TL_CACHE_DIR:-$ROOT/.tl/cache}" TL_STYLE="$style"
tmp="$outd/road_$$"; mkdir -p "$tmp"
bash engine/tools/world.sh visit-test "$A/road.walk.json" "--devices=$A/road.devices.json" --load=block "--out-dir=$tmp" > "$outd/road.log" 2>&1
for f in "$tmp"/*.png; do [ -f "$f" ] && mv -f "$f" "$outd/$(basename "$out")"; done
rmdir "$tmp" 2>/dev/null; ls "$outd/$(basename "$out")"
