#!/bin/bash
# Lane walker: the <=20 s clip in a window: walking toward the bank (wf_feel), running among the trees (wf_canopy),
# the slope slide down the bluff (wf_bluff). One windowed visit each with a movie (fixed 60 fps), the end of each cut,
# then joined. Usage: make_clip.sh <out.mp4> [label]
W="$(cd "$(dirname "$0")/../../../../.." && pwd)"
D="$W/docs/shifts/2026-11-19-night/lanes/walker"
DW="$(cygpath -m "$D")"
OUT="${1:-$D/clip.mp4}"; LABEL="${2:-}"
tmp="$D/.clip_tmp"; mkdir -p "$tmp"; TW="$(cygpath -m "$tmp")"
seg() {  # seg <walk> <devices> <seconds from the end> <name>
  rm -f "$tmp/$4.avi"
  TL_WINDOW_ARGS="--write-movie $TW/$4.avi" bash "$W/engine/tools/world.sh" visit-test "$1" "--devices=$2" "--record=$TW/$4.record.json" > "$tmp/$4.log" 2>&1
  echo "$4: world.sh exit $?"
  ffmpeg -loglevel error -y -sseof "-$3" -i "$tmp/$4.avi" -vf "scale=1280:720,drawtext=text='$4 $LABEL':x=24:y=24:fontsize=26:fontcolor=white:box=1:boxcolor=black@0.5" -c:v libx264 -crf 20 -pix_fmt yuv420p -an "$tmp/$4.mp4"
}
seg wf_feel "$DW/clip_feel.devices.json" 5.6 toward_the_bank
seg wf_canopy "$(cygpath -m "$W/engine/kernel/world/walks/wf_canopy.devices.json")" 6.0 among_the_trees
seg wf_bluff "$(cygpath -m "$W/engine/kernel/world/walks/wf_bluff.devices.json")" 6.0 down_the_bluff
printf "file '%s'\n" "$TW/toward_the_bank.mp4" "$TW/among_the_trees.mp4" "$TW/down_the_bluff.mp4" > "$tmp/list.txt"
ffmpeg -loglevel error -y -f concat -safe 0 -i "$tmp/list.txt" -c copy "$OUT"
ffprobe -v error -show_entries format=duration -of csv=p=0 "$OUT"
