#!/bin/bash
# Lane walker round 3: wf_canopy (run among the trees, then a slow full turn under them) once per TL_CROWN_SWING value in
# a window, a movie each; prints the visitor_cam line (sideways ticks). Runs Godot as world.sh visit-test does, unfiltered.
W="$(cd "$(dirname "$0")/../../../../../.." && pwd)"
D="$W/docs/shifts/2026-11-19-night/lanes/walker/swing"; DW="$(cygpath -m "$D")"; E="$(cygpath -m "$W/engine")"
G="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
for m in sideways behind; do
  rm -f "$D/swing_$m.avi"
  MSYS_NO_PATHCONV=1 TL_CROWN_SWING="$m" timeout 300 "$G" --position 0,1440 --resolution 1920x1080 --rendering-driver d3d12 --audio-driver Dummy \
    --fixed-fps 60 --write-movie "$DW/swing_$m.avi" --path "$E" res://kernel/host/host.tscn -- world-view "--walk=$E/kernel/world/walks/wf_canopy.json" \
    --live "--devices=$E/kernel/world/walks/wf_canopy.devices.json" "--record=$DW/swing_$m.record.json" > "$D/swing_$m.log" 2>&1
  echo "$m exit $? $(tr -d '\r' < "$D/swing_$m.log" | grep -ao '"kind":"visitor_cam"[^}]*' | tail -1)"
  ffmpeg -loglevel error -y -i "$D/swing_$m.avi" -vf "scale=960:540" -c:v libx264 -crf 24 -pix_fmt yuv420p "$D/swing_$m.mp4" && rm -f "$D/swing_$m.avi"
done
