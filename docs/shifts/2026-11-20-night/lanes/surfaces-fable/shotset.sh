#!/bin/bash
# Lane surfaces-fable (night of 20 Nov 2026): the fixed shot set of COMMON.md under one style.
#   bash docs/shifts/2026-11-20-night/lanes/surfaces-fable/shotset.sh <style> <out dir>
#     <style>   classic | diorama | any N with engine/style/style_N.json (TL_STYLE; `surfaces` = the preview)
#     <out dir> gets the PNG captures (raw: keep it under .tl/) and logs
# The shots:
#   01..16  the village tour: each lot from the road and from above (blend_views.walk.json, the command of COMMON.md
#           plus --load=block: with the queue the packs arrive when the machine lets them, and on a busy night two
#           runs of one tree showed different mesas and bushes, so the three styles could not be compared)
#   21..26  the flight over the bluff: the flight lane's walk and devices with `shot` events added
#           (flight_shots.devices.json; 23_flight_bluff is the frame of target/ref/r2_flight_bluff.jpg)
#   31, 32  the parkour run at frame 520 and the hockey rink at frame 1500: the real bots, seed 1, HUD on, as the
#           hud lane took them (the frames of target/ref/r3 and r4)
#   41      the figure close up: engine/rigs/review/review.tscn, frame 45 of an idle clip, view vclose
# One more, beyond the fixed set, is taken by crawl.sh and not here: 51_road_visitor, the village road as the visitor
# sees it (frame 200 of the land clip), the frame that stands beside the target board on the contact sheet.
# The two windowed world runs wait for the machine's window lock (minutes each on a night with six arms).
# The picture cache is kept in this worktree (.tl/cache): the machine's cache is shared by every checkout.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../../../.." && pwd)"
cd "$ROOT" || exit 2
style="${1:?style}"; out="${2:?out dir}"
mkdir -p "$out"; out="$(cd "$out" && pwd)"
if command -v cygpath >/dev/null 2>&1; then out="$(cygpath -m "$out")"; ROOT="$(cygpath -m "$ROOT")"; HERE="$(cygpath -m "$HERE")"; fi
export TL_GODOT="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
export TL_CACHE_DIR="${TL_CACHE_DIR:-$ROOT/.tl/cache}"
export TL_STYLE="$style"
TL_QUIET=1 bash engine/tools/tl.sh capture --pack=engine/packs/parkour --cam=orbit --frame=520 --test=tests/bot_course.gd --hud=on --res=1920x1080 "--out=$out/31_parkour_run.png" > "$out/parkour.log" 2>&1
TL_QUIET=1 bash engine/tools/tl.sh capture --pack=engine/packs/hockey --cam=arena --frame=1500 --test=tests/bot_hockey.gd --hud=on --res=1920x1080 "--out=$out/32_hockey_rink.png" > "$out/hockey.log" 2>&1
CLIP_RES=1920x1080 bash engine/tools/look.sh clip rig:idle:0:0:vclose "$out/closeup.mp4" 60 > "$out/closeup.log" 2>&1
ffmpeg -v error -y -i "$out/closeup.mp4" -vf "select=eq(n\,45)" -frames:v 1 -update 1 "$out/41_figure_closeup.png"
rm -f "$out/closeup.mp4" "$out/closeup_strip.png"
bash engine/tools/world.sh tour docs/shifts/2026-11-19-day/lanes/blend/blend_views.walk.json --pictures-only --load=block "--out-dir=$out" > "$out/tour.log" 2>&1
grep -a "^window:" "$out/tour.log"
mkdir -p "$out/flight"
bash engine/tools/world.sh visit-test docs/shifts/2026-11-19-day/lanes/flight/wf_flight.json "--devices=$HERE/flight_shots.devices.json" "--out-dir=$out/flight" > "$out/flight.log" 2>&1
for f in "$out"/flight/*.png; do b="$(basename "$f")"; [ -f "$f" ] && mv -f "$f" "$out/2${b#0}"; done
rmdir "$out/flight" 2>/dev/null
echo "shots: $(ls "$out"/*.png 2>/dev/null | wc -l) pictures in $out"
