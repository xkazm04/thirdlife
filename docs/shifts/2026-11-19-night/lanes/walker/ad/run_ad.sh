#!/bin/bash
# Lane walker item 4: one windowed visit per TL_AD_KEYS value with the same device script; a movie each (60 fps, ticks).
W="$(cd "$(dirname "$0")/../../../../../.." && pwd)"
D="$W/docs/shifts/2026-11-19-night/lanes/walker/ad"
DW="$(cygpath -m "$D")"
for m in face sidestep turn; do
  rm -f "$D/ad_$m.avi"
  TL_AD_KEYS="$m" TL_WINDOW_ARGS="--write-movie $DW/ad_$m.avi" bash "$W/engine/tools/world.sh" visit-test tour "--devices=$DW/ad.devices.json" "--record=$DW/ad_$m.record.json" > "$D/ad_$m.log" 2>&1
  echo "$m exit $?"
  ffmpeg -loglevel error -y -i "$D/ad_$m.avi" -vf "scale=960:540,drawtext=text='TL_AD_KEYS=$m':x=20:y=20:fontsize=28:fontcolor=white:box=1:boxcolor=black@0.5" -c:v libx264 -crf 24 -pix_fmt yuv420p "$D/ad_$m.mp4" && rm -f "$D/ad_$m.avi"
done
