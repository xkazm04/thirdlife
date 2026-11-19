#!/bin/bash
# Run from the worktree root. Read each runner's actual exit and its final verification report.
set -eu
mkdir -p .tl/walker-r2
for verb in lint smoke 'bot --test=tests/bot_course.gd' 'bot --test=tests/bot_geometry.gd' 'bot --test=tests/bot_obstacles.gd' invariants; do
  read -ra args <<< "$verb"
  log=".tl/walker-r2/parkour-verb.txt"
  rc=0
  bash engine/tools/tl.sh "${args[@]}" "--pack=$PWD/engine/packs/parkour" > "$log" 2>&1 || rc=$?
  node -e '
    const fs = require("fs");
    const [file, verb, rc] = process.argv.slice(1);
    const r = JSON.parse(fs.readFileSync(file, "utf8").trim().split(/\r?\n/).pop());
    console.log("PARKOUR", verb, "exit=" + rc, "ok=" + r.ok, "frames=" + (r.frames ?? "-"), "hash=" + (r.metrics?.state_hash ?? "-"));
    if (+rc || r.schema !== "tl.verify/1" || !r.ok || r.outcome !== "passed" ||
        (verb !== "lint" && (!r.metrics?.state_hash || !(r.frames > 0)))) process.exit(1);
  ' "$log" "$verb" "$rc"
done
