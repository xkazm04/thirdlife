#!/bin/bash
# lotsheet.sh <visits root> <out.jpg>: one row per lot (shots 01..05: walk in, at edge, along edge, air over road, air approach)
root="$(cd "$1" && pwd)"; out="$(cd "$(dirname "$2")" && pwd)/$(basename "$2")"; here="$(cd "$(dirname "$0")" && pwd)"; tmp="$(mktemp -d)"; rows=()
for d in "$root"/*/; do
  n=$(basename "$d"); k=0
  for f in "$d"/0[1-5]_*.png; do
    (cd "$here" && ffmpeg -loglevel error -y -i "$f" -vf "scale=480:270,drawtext=fontfile=arial.ttf:text='$n $(basename "$f" .png | cut -c4-)':x=6:y=6:fontsize=18:fontcolor=white:box=1:boxcolor=black@0.6" "$tmp/${n}_$k.png" 2>&1 | grep -v Fontconfig); k=$((k+1))
  done
  ffmpeg -loglevel error -y -i "$tmp/${n}_0.png" -i "$tmp/${n}_1.png" -i "$tmp/${n}_2.png" -i "$tmp/${n}_3.png" -i "$tmp/${n}_4.png" -filter_complex hstack=inputs=5 "$tmp/row_$n.png"
  rows+=("-i" "$tmp/row_$n.png")
done
ffmpeg -loglevel error -y "${rows[@]}" -filter_complex vstack=inputs=$(( ${#rows[@]} / 2 )) -q:v 4 "$out"
rm -rf "$tmp"; echo "$out"
