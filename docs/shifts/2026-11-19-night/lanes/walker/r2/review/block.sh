#!/bin/bash
# Run block 380 through the normal selftest filters, including its group of four V cases.
set -eu
for selection in walk.v_ walk.single_face walk.step_edge walk.pad_swap; do
  out="$(bash engine/tools/selftest.sh "$selection")" || { echo "$out"; exit 1; }
  echo "$out"
  expected=1
  if [[ "$selection" == walk.v_ ]]; then expected=4; fi
  grep -Fq "selftest: $expected passed, 0 failed" <<< "$out"
done
echo "block 380: 7 passed, 0 failed"
