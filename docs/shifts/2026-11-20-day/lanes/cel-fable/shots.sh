#!/bin/bash
# Lane cel-fable (day of 20 Nov 2026): the shot set of COMMON.md under one style.
#   bash docs/shifts/2026-11-20-day/lanes/cel-fable/shots.sh <style> <out dir under .tl> [tour|flight|all]
# tour: the 16 village pictures (blend_views.walk.json, --load=block so two runs show the same landscape).
# flight: the flight over the bluff with shot events (last night's flight_shots.devices.json), pictures 21..26.
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
if [ "$what" = tour ] || [ "$what" = all ]; then
  bash engine/tools/world.sh tour docs/shifts/2026-11-19-day/lanes/blend/blend_views.walk.json --pictures-only --load=block "--out-dir=$out" > "$out/tour.log" 2>&1
  grep -a "^window:" "$out/tour.log"
fi
if [ "$what" = flight ] || [ "$what" = all ]; then
  mkdir -p "$out/flight"
  bash engine/tools/world.sh visit-test docs/shifts/2026-11-19-day/lanes/flight/wf_flight.json "--devices=$ROOT/docs/shifts/2026-11-20-night/lanes/surfaces-fable/flight_shots.devices.json" "--out-dir=$out/flight" > "$out/flight.log" 2>&1
  for f in "$out"/flight/*.png; do b="$(basename "$f")"; [ -f "$f" ] && mv -f "$f" "$out/2${b#0}"; done
  rmdir "$out/flight" 2>/dev/null
fi
echo "shots: $(ls "$out"/*.png 2>/dev/null | wc -l) pictures in $out"
