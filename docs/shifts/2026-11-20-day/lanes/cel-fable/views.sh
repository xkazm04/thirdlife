#!/bin/bash
# Lane cel-fable: the lane's own eight views (cel_views.walk.json) under one style.
#   bash docs/shifts/2026-11-20-day/lanes/cel-fable/views.sh <style> <out dir under .tl>
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(cd "$HERE/../../../../.." && pwd)"; cd "$ROOT" || exit 2
style="${1:?style}"; out="${2:?out dir}"; mkdir -p "$out"; out="$(cd "$out" && pwd)"
if command -v cygpath >/dev/null 2>&1; then out="$(cygpath -m "$out")"; ROOT="$(cygpath -m "$ROOT")"; HERE="$(cygpath -m "$HERE")"; fi
export TL_GODOT="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
export TL_CACHE_DIR="${TL_CACHE_DIR:-$ROOT/.tl/cache}" TL_STYLE="$style"
bash engine/tools/world.sh tour "$HERE/cel_views.walk.json" --pictures-only --load=block "--out-dir=$out" > "$out/views.log" 2>&1
grep -a "^window:" "$out/views.log" | cut -c1-140
