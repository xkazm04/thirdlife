#!/usr/bin/env bash
# Run from the worktree root. The probe uses the same seeded village and device stream.
set -euo pipefail
stage=${1:?before or after}
r=docs/shifts/2026-11-19-night/lanes/walker/r3
out="$r/$stage"
mkdir -p "$out"
export CLIP_RES=1920x1080 CLIP_CRF=4
export TMPDIR="$(cygpath -m "$(cd "$out" && pwd)")"

g=${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}
case "${2:-all}" in
  all|rig)
    RIG_ARGS=--freeze-at=90 bash engine/tools/look.sh clip rig:run:4.5:0:behind "$out/runner.mp4" 150
    RIG_ARGS=--thin=1 bash engine/tools/look.sh clip rig:idle:0:0.83:behind "$out/thin.mp4" 150
    ;;
esac
case "${2:-all}" in
  all|bluff)
    MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' TL_LAND_NOW=1 "$g" --path engine --position 0,1440 --resolution 1920x1080 --rendering-driver d3d12 --audio-driver Dummy --fixed-fps 60 --write-movie "$TMPDIR/bluff.avi" --quit-after 210 res://kernel/host/host.tscn -- world-view --walk=res://kernel/world/walks/wf_bluff.json --live --ticks=155 --devices="$TMPDIR/../bluff.devices.json" --cost=model --load=block --out-dir="$TMPDIR" >"$out/movie-world.log" 2>&1
    grep -Fq '"world_ticks":155' "$out/movie-world.log"
    if grep -E 'SCRIPT ERROR|^ERROR:' "$out/movie-world.log"; then exit 1; fi
    ffmpeg -y -loglevel error -i "$out/bluff.avi" -frames:v 150 -c:v libx264 -pix_fmt yuv420p -crf 4 -r 60 "$out/bluff.mp4"
    rm "$out/bluff.avi"
    ;;
esac
case "${2:-all}" in
  all|measure) clips=(runner thin bluff);;
  rig) clips=(runner thin);;
  bluff) clips=(bluff);;
  *) echo 'expected all, measure, rig, or bluff' >&2; exit 2;;
esac
for clip in "${clips[@]}"; do
  n=$(ffprobe -v error -count_frames -select_streams v:0 -show_entries stream=nb_read_frames -of csv=p=0 "$out/$clip.mp4")
  [[ "$n" = 150 ]] || { echo "$clip: expected 150 frames, got $n"; exit 1; }
  bash engine/tools/look.sh boil "$out/$clip.mp4" 40 145 | tee "$out/$clip-boil.log"
  grep -q 'boil frames=106 ' "$out/$clip-boil.log"
done
