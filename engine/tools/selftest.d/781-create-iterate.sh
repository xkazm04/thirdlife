# Night of 24-25 Nov 2026, lane E4 (iterate): the person's path through iterations on a real Foreman with the fake
# adapter and the fake runner (no model is called): the phases fixture (foreman/dist/testing/grow-steps.js) reopened,
# Continue, Pass x3, done; a change that grows the game (a new package) -> version 2; a change to a package -> version 3;
# Play opens @0.1.2; Add to menu; My games reopens it; the main menu's Dungeons lists it (ui/create/stage.gd --mode=iterate,
# the door with the exe's layout as in 780). The person's dungeon list is a file of this block (TL_USER_DUNGEONS).
#   create.iterate.path      (needs foreman/dist: npm --prefix foreman ci && npm --prefix foreman run build)
ci_name="create.iterate.path"
if [ -z "$FILTER" ] || [[ "$ci_name" == *"$FILTER"* ]]; then
  ci_godot="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  ci_engine="$(cd "$HERE/.." && pwd)"
  ci_repo="$(cd "$HERE/../.." && pwd)"
  ci_dir="$OUT/create-iterate"
  rm -rf "$ci_dir"
  mkdir -p "$ci_dir/jobs"
  if command -v cygpath >/dev/null 2>&1; then
    ci_engine="$(cygpath -m "$ci_engine")"; ci_repo="$(cygpath -m "$ci_repo")"; ci_dir="$(cygpath -m "$ci_dir")"
  fi
  ci_why=""
  ci_job="$ci_dir/jobs/paddle-court-crazy-20261121-1"
  ci_made="$(node "$ci_repo/foreman/dist/testing/grow-steps.js" "$ci_job" 2>&1)" || ci_why="no iterate job: $ci_made (build the Foreman first)"
  printf '%s\n' '{"name": "fake adapter (fixture script)", "flags": {"new": ["--adapter","fake"], "plan": ["--adapter","fake"], "run": ["--adapter","fake","--parallel","1"], "resume": ["--adapter","fake","--parallel","1"], "change": ["--adapter","fake","--parallel","1"]}}' > "$ci_dir/flags.json"
  ci_out=""
  if [ -z "$ci_why" ]; then
    ci_out="$(TL_USER_DUNGEONS="$ci_dir/dungeons.user.json" MSYS_NO_PATHCONV=1 timeout 600 "$ci_godot" --headless --fixed-fps 60 --path "$ci_engine" \
      res://ui/create/stage.tscn -- --mode=iterate --menu "--repo=$ci_repo" "--job=$ci_job" "--flags=$ci_dir/flags.json" "--jobs=$ci_dir/jobs" 2>&1 | tr -d '\015')"
    echo "$ci_out" > "$ci_dir/create-iterate.log"
  fi
  if [ -z "$ci_why" ]; then
    ci_fail="$(echo "$ci_out" | grep -a '^\[create\] iterate FAIL' | head -1)"
    ci_pass="$(echo "$ci_out" | grep -ac '^\[create\] iterate PASS')"
    if [ -n "$ci_fail" ]; then ci_why="${ci_fail#\[create\] iterate }"
    elif echo "$ci_out" | grep -aq 'SCRIPT ERROR'; then ci_why="script error: $(echo "$ci_out" | grep -a 'SCRIPT ERROR' | head -1)"
    elif ! echo "$ci_out" | grep -aq '^\[create\] iterate all held'; then ci_why="no end line: the run stopped after $ci_pass steps ($ci_dir/create-iterate.log)"
    elif [ "$ci_pass" -lt 15 ]; then ci_why="$ci_pass of 15 steps passed: a stopped run is never a pass"
    fi
  fi
  verdict "$ci_name" "$ci_why" "15 steps: continue, 3 phases, v1, grow -> v2, change -> v3, Play @0.1.2, menu, My games, Dungeons"
fi
