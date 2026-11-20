#!/bin/bash
# Lane cel-astra (20 Nov day): the fixed shot set of COMMON.md under one style (after the night's surfaces-fable shotset.sh).
#   bash docs/shifts/2026-11-20-day/lanes/cel-astra/shotset.sh <style> <out dir under .tl> [root of the tree to shoot]
# 01..16 village tour (07 = board shot), 21..26 flight over the bluff, 31 parkour f520, 32 hockey f1500,
# 41 figure close-up back (vclose), 42 figure front (vfront), 51 the village road as the visitor sees it (beside board 2).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="${3:-$(cd "$HERE/../../../../.." && pwd)}"
cd "$ROOT" || exit 2
style="${1:?style}"; out="${2:?out dir}"
mkdir -p "$out"; out="$(cd "$out" && pwd)"
if command -v cygpath >/dev/null 2>&1; then out="$(cygpath -m "$out")"; ROOT="$(cygpath -m "$ROOT")"; HERE="$(cygpath -m "$HERE")"; fi
export TL_GODOT="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
export TL_CACHE_DIR="${TL_CACHE_DIR:-$ROOT/.tl/cache}"
export TL_STYLE="$style"
only="${ONLY:-headless tour flight road}"
if [[ " $only " == *" headless "* ]]; then
TL_QUIET=1 bash engine/tools/tl.sh capture --pack=engine/packs/parkour --cam=orbit --frame=520 --test=tests/bot_course.gd --hud=on --res=1920x1080 "--out=$out/31_parkour_run.png" > "$out/parkour.log" 2>&1
TL_QUIET=1 bash engine/tools/tl.sh capture --pack=engine/packs/hockey --cam=arena --frame=1500 --test=tests/bot_hockey.gd --hud=on --res=1920x1080 "--out=$out/32_hockey_rink.png" > "$out/hockey.log" 2>&1
for v in vclose:41_figure_back vfront:42_figure_front; do
  CLIP_RES=1920x1080 bash engine/tools/look.sh clip "rig:idle:0:0:${v%%:*}" "$out/cu.mp4" 60 > "$out/${v##*:}.log" 2>&1
  ffmpeg -v error -y -i "$out/cu.mp4" -vf "select=eq(n\,45)" -frames:v 1 -update 1 "$out/${v##*:}.png"
  rm -f "$out/cu.mp4" "$out/cu_strip.png"
done
fi
if [[ " $only " == *" tour "* ]]; then
bash engine/tools/world.sh tour docs/shifts/2026-11-19-day/lanes/blend/blend_views.walk.json --pictures-only --load=block "--out-dir=$out" > "$out/tour.log" 2>&1
grep -a "^window:" "$out/tour.log"
fi
if [[ " $only " == *" flight "* ]]; then
mkdir -p "$out/flight"
bash engine/tools/world.sh visit-test docs/shifts/2026-11-19-day/lanes/flight/wf_flight.json "--devices=$HERE/flight_shots.devices.json" "--out-dir=$out/flight" > "$out/flight.log" 2>&1
for f in "$out"/flight/*.png; do b="$(basename "$f")"; [ -f "$f" ] && mv -f "$f" "$out/2${b#0}"; done
rmdir "$out/flight" 2>/dev/null
fi
if [[ " $only " == *" road "* ]]; then
mkdir -p "$out/road"
bash engine/tools/world.sh visit-test "$HERE/road.walk.json" "--devices=$HERE/road.devices.json" --load=block "--out-dir=$out/road" > "$out/road.log" 2>&1
for f in "$out"/road/*.png; do [ -f "$f" ] && mv -f "$f" "$out/51_road_visitor.png"; done
rmdir "$out/road" 2>/dev/null
fi
echo "shots: $(ls "$out"/*.png 2>/dev/null | wc -l) pictures in $out"
