#!/bin/bash
# Lane walker: the parkour house game (TLBiped walker feel runs on world_body.gd) through the gate's verbs:
# lint, smoke, its three bots, invariants. Prints one line per verb with ok, state_hash and frames.
#   bash docs/reports/bugfix-37/walker/parkour_check.sh   (from the worktree root)
W="$(cd "$(dirname "$0")/../../../.." && pwd)"
P="$W/engine/packs/parkour"
for v in "lint" "smoke" "bot --test=tests/bot_course.gd" "bot --test=tests/bot_geometry.gd" "bot --test=tests/bot_obstacles.gd" "invariants"; do
  set -- $v
  out="$(timeout 600 bash "$W/engine/tools/tl.sh" "$1" "--pack=$P" "${@:2}" 2>&1 | tr -d '\015')"
  code=$?
  line="$(echo "$out" | grep '"schema":"tl.verify/1"' | tail -1)"
  ok="$(echo "$line" | grep -o '"ok":[a-z]*' | head -1)"
  hash="$(echo "$line" | grep -o '"state_hash":"[0-9a-f]*"' | head -1)"
  frames="$(echo "$line" | grep -o '"frames":[0-9]*' | head -1)"
  echo "PARKOUR $v: exit $code $ok $hash $frames"
  [ -z "$line" ] && echo "$out" | tail -5
done
