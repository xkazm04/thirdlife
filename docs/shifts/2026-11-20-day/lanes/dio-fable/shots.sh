#!/bin/bash
# Lane dio-fable (day of 20 Nov 2026): the shot set under one style.
#   bash docs/shifts/2026-11-20-day/lanes/dio-fable/shots.sh <style> <out dir> [tour|flight|all]
#     <style>   classic | diorama (TL_STYLE);  <out dir> gets PNG captures (raw: keep under .tl/) and logs
#   01..16 the village tour (blend_views.walk.json, --load=block so two runs show the same world)
#   21..26 the flight over the bluff (the flight lane's walk; flight_shots.devices.json adds the shot events)
# The picture cache is kept in this worktree (.tl/cache): the machine's cache is shared by every checkout.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../../../.." && pwd)"
cd "$ROOT" || exit 2
style="${1:?style}"; out="${2:?out dir}"; what="${3:-all}"
mkdir -p "$out"; out="$(cd "$out" && pwd)"
if command -v cygpath >/dev/null 2>&1; then out="$(cygpath -m "$out")"; ROOT="$(cygpath -m "$ROOT")"; HERE="$(cygpath -m "$HERE")"; fi
export TL_GODOT="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
export TL_CACHE_DIR="${TL_CACHE_DIR:-$ROOT/.tl/cache}"
export TL_STYLE="$style"
if [ "$what" = all ] || [ "$what" = tour ]; then
  bash engine/tools/world.sh tour docs/shifts/2026-11-19-day/lanes/blend/blend_views.walk.json --pictures-only --load=block "--out-dir=$out" > "$out/tour.log" 2>&1
  grep -a "^window:" "$out/tour.log"
fi
if [ "$what" = all ] || [ "$what" = flight ]; then
  mkdir -p "$out/flight"
  bash engine/tools/world.sh visit-test docs/shifts/2026-11-19-day/lanes/flight/wf_flight.json "--devices=$HERE/flight_shots.devices.json" "--out-dir=$out/flight" > "$out/flight.log" 2>&1
  for f in "$out"/flight/*.png; do b="$(basename "$f")"; [ -f "$f" ] && mv -f "$f" "$out/2${b#0}"; done
  rmdir "$out/flight" 2>/dev/null
fi
echo "shots: $(ls "$out"/*.png 2>/dev/null | wc -l) pictures in $out"
