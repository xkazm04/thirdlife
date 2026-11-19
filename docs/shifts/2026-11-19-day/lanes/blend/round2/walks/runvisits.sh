#!/bin/bash
# runvisits.sh <outroot> [names...]: one windowed person-visit per lot, shots into <outroot>/<name>/
cd "$(dirname "$0")/.."; W=$(cygpath -m "$PWD"); out="$1"; shift
names="${@:-walker drive wall paddle kit car hockey parkour site_crates site_hockey}"
for n in $names; do
  mkdir -p "$out/$n"; rm -f "$out/$n"/*.png
  bash engine/tools/world.sh visit-test "$W/.tl/visits/$n.json" "--devices=$W/.tl/visits/devices.json" "--record=$(cygpath -m "$out")/$n/record.json" "--out-dir=$(cygpath -m "$out")/$n" > "$out/$n/log.txt" 2>&1
  echo "$n: exit $? pictures $(ls "$out/$n"/*.png 2>/dev/null | wc -l) $(grep -c SCRIPT "$out/$n/log.txt") script errors"
done
