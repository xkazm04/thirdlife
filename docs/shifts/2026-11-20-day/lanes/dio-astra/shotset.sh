#!/bin/bash
# Lane dio-astra (day of 20 Nov 2026): the shot set of COMMON.md under one style (adapted from surfaces-fable's).
#   bash docs/shifts/2026-11-20-day/lanes/dio-astra/shotset.sh <style> <out dir> [parts]
#     <style>  diorama | classic | any N with engine/style/style_N.json (TL_STYLE)
#     [parts]  any of: tour flight figure games (default: all four)
# Shots: 01..16 the village tour (blend_views.walk.json, --load=block); 21..26 the flight over the bluff
# (wf_flight.json + flight_shots.devices.json); 31 parkour f520, 32 hockey f1500 (real bots, HUD on);
# 41 the figure close-up from behind (vclose), 42 from the front (vfront), frame 45 of an idle clip.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../../../.." && pwd)"
cd "$ROOT" || exit 2
style="${1:?style}"; out="${2:?out dir}"; parts="${3:-tour flight figure games}"
mkdir -p "$out"; out="$(cd "$out" && pwd)"
if command -v cygpath >/dev/null 2>&1; then out="$(cygpath -m "$out")"; ROOT="$(cygpath -m "$ROOT")"; HERE="$(cygpath -m "$HERE")"; fi
export TL_GODOT="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
export TL_CACHE_DIR="${TL_CACHE_DIR:-$ROOT/.tl/cache}"
export TL_STYLE="$style"
has() { case " $parts " in *" $1 "*) return 0;; esac; return 1; }
if has figure; then
  for v in vclose:41_figure_closeup vfront:42_figure_front; do
    view="${v%%:*}"; name="${v#*:}"
    CLIP_RES=1920x1080 bash engine/tools/look.sh clip "rig:idle:0:0:$view" "$out/clip_$view.mp4" 60 > "$out/$name.log" 2>&1
    ffmpeg -v error -y -i "$out/clip_$view.mp4" -vf "select=eq(n\,45)" -frames:v 1 -update 1 "$out/$name.png"
    rm -f "$out/clip_$view.mp4" "$out/clip_${view}_strip.png"
  done
fi
if has games; then
  TL_QUIET=1 bash engine/tools/tl.sh capture --pack=engine/packs/parkour --cam=orbit --frame=520 --test=tests/bot_course.gd --hud=on --res=1920x1080 "--out=$out/31_parkour_run.png" > "$out/parkour.log" 2>&1
  TL_QUIET=1 bash engine/tools/tl.sh capture --pack=engine/packs/hockey --cam=arena --frame=1500 --test=tests/bot_hockey.gd --hud=on --res=1920x1080 "--out=$out/32_hockey_rink.png" > "$out/hockey.log" 2>&1
fi
if has tour; then
  bash engine/tools/world.sh tour docs/shifts/2026-11-19-day/lanes/blend/blend_views.walk.json --pictures-only --load=block "--out-dir=$out" > "$out/tour.log" 2>&1
  grep -a "^window:" "$out/tour.log"
fi
if has flight; then
  mkdir -p "$out/flight"
  bash engine/tools/world.sh visit-test docs/shifts/2026-11-19-day/lanes/flight/wf_flight.json "--devices=$HERE/flight_shots.devices.json" "--out-dir=$out/flight" > "$out/flight.log" 2>&1
  for f in "$out"/flight/*.png; do b="$(basename "$f")"; [ -f "$f" ] && mv -f "$f" "$out/2${b#0}"; done
  rmdir "$out/flight" 2>/dev/null
fi
echo "shots: $(ls "$out"/*.png 2>/dev/null | wc -l) pictures in $out"
