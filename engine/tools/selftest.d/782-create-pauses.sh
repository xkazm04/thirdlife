# Night of 24-25 Nov 2026, lane E4b (pauses): the two pauses E5 found a person stuck at, answered on the Create page with a
# real Foreman (fake adapter, fake runner, no model called): the phases fixture of foreman/dist/testing/grow-steps.js
# --pauses (the rival's builder asks a question; the critic finds every look weak). ui/create/stage_pauses.gd: the quality
# card's Fix it, It's fine, Change it; the question card's option + Answer; Pass; until done, the door in the exe's layout.
#   create.pause.path      (needs foreman/dist: npm --prefix foreman ci && npm --prefix foreman run build)
cp_name="create.pause.path"
if [ -z "$FILTER" ] || [[ "$cp_name" == *"$FILTER"* ]]; then
  cp_godot="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  cp_engine="$(cd "$HERE/.." && pwd)"
  cp_repo="$(cd "$HERE/../.." && pwd)"
  cp_dir="$OUT/create-pauses"
  rm -rf "$cp_dir"
  mkdir -p "$cp_dir/jobs"
  if command -v cygpath >/dev/null 2>&1; then
    cp_engine="$(cygpath -m "$cp_engine")"; cp_repo="$(cygpath -m "$cp_repo")"; cp_dir="$(cygpath -m "$cp_dir")"
  fi
  cp_why=""
  cp_job="$cp_dir/jobs/paddle-court-crazy-20261121-1"
  cp_made="$(node "$cp_repo/foreman/dist/testing/grow-steps.js" "$cp_job" --pauses 2>&1)" || cp_why="no pauses job: $cp_made (build the Foreman first)"
  printf '%s\n' '{"name": "fake adapter (fixture script)", "flags": {"new": ["--adapter","fake"], "plan": ["--adapter","fake"], "run": ["--adapter","fake","--parallel","1"], "resume": ["--adapter","fake","--parallel","1"], "change": ["--adapter","fake","--parallel","1"]}}' > "$cp_dir/flags.json"
  cp_out=""
  if [ -z "$cp_why" ]; then
    cp_out="$(TL_USER_DUNGEONS="$cp_dir/dungeons.user.json" MSYS_NO_PATHCONV=1 timeout 600 "$cp_godot" --headless --fixed-fps 60 --path "$cp_engine" \
      res://ui/create/stage.tscn -- --mode=pauses "--repo=$cp_repo" "--job=$cp_job" "--flags=$cp_dir/flags.json" "--jobs=$cp_dir/jobs" 2>&1 | tr -d '\015')"
    echo "$cp_out" > "$cp_dir/create-pauses.log"
  fi
  if [ -z "$cp_why" ]; then
    cp_fail="$(echo "$cp_out" | grep -a '^\[create\] pauses FAIL' | head -1)"
    cp_pass="$(echo "$cp_out" | grep -ac '^\[create\] pauses PASS')"
    if [ -n "$cp_fail" ]; then cp_why="${cp_fail#\[create\] pauses }"
    elif echo "$cp_out" | grep -aq 'SCRIPT ERROR'; then cp_why="script error: $(echo "$cp_out" | grep -a 'SCRIPT ERROR' | head -1)"
    elif ! echo "$cp_out" | grep -aq '^\[create\] pauses all held'; then cp_why="no end line: the run stopped after $cp_pass steps ($cp_dir/create-pauses.log)"
    elif [ "$cp_pass" -lt 10 ]; then cp_why="$cp_pass of 10 steps passed: a stopped run is never a pass"
    fi
  fi
  verdict "$cp_name" "$cp_why" "10 steps: quality card, the run clock, Fix it, It's fine, question card + option + Answer, Change it, done"
fi
