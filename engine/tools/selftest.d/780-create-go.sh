# Night of 22-23 Nov 2026, lane N4 (create): Create's GO as an exported build meets it (ui/create/create_go_case.gd).
# The door is set up with the exe's layout (res:// globalizes to "", the executable in <repo>/dist/ThirdLife); a chip and
# GO run `foreman new` for real with the fake adapter (no model is called) until the Designer's pitch is on the page.
#   create.go.door  create.go.started  create.go.pitch      (needs foreman/dist: npm --prefix foreman ci && ... run build)
cg_names="create.go.door create.go.started create.go.pitch"
cg_wanted=0
for cg_n in $cg_names; do if [ -z "$FILTER" ] || [[ "$cg_n" == *"$FILTER"* ]]; then cg_wanted=1; fi; done
if [ "$cg_wanted" = 1 ]; then
  cg_godot="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  cg_engine="$(cd "$HERE/.." && pwd)"
  cg_repo="$(cd "$HERE/../.." && pwd)"
  cg_dir="$OUT/create-go"
  rm -rf "$cg_dir"
  mkdir -p "$cg_dir/jobs"
  if command -v cygpath >/dev/null 2>&1; then
    cg_engine="$(cygpath -m "$cg_engine")"; cg_repo="$(cygpath -m "$cg_repo")"; cg_dir="$(cygpath -m "$cg_dir")"
  fi
  cg_why=""
  cg_fake="$(node "$cg_engine/ui/fixtures/make_designer_fake.mjs" "$cg_repo" "$cg_dir" 2>&1)" || cg_why="no fake Designer script: $cg_fake"
  cg_out=""
  if [ -z "$cg_why" ]; then
    cg_out="$(MSYS_NO_PATHCONV=1 timeout 180 "$cg_godot" --headless --fixed-fps 60 --path "$cg_engine" \
      --script res://ui/create/create_go_case.gd -- "--repo=$cg_repo" "--flags=$cg_dir/flags.fake-designer.json" "--jobs=$cg_dir/jobs" 2>&1 | tr -d '\015')"
    echo "$cg_out" > "$cg_dir/create-go.log"
  fi
  cg_trailer="$(echo "$cg_out" | grep -a '^\[create-go\] [0-9]* passed, [0-9]* failed' | tail -1)"
  for cg_n in $cg_names; do
    if [ -n "$FILTER" ] && [[ "$cg_n" != *"$FILTER"* ]]; then continue; fi
    cg_fail="$(echo "$cg_out" | grep -a "^FAIL $cg_n" | head -1)"
    cg_r="$cg_why"
    if [ -z "$cg_r" ]; then
      if [ -n "$cg_fail" ]; then cg_r="${cg_fail#FAIL }"
      elif ! echo "$cg_out" | grep -aq "^PASS $cg_n"; then cg_r="no PASS $cg_n line (${cg_trailer:-no trailer: the run stopped}; $cg_dir/create-go.log)"
      elif echo "$cg_out" | grep -aq 'SCRIPT ERROR'; then cg_r="script error: $(echo "$cg_out" | grep -a 'SCRIPT ERROR' | head -1)"
      elif [ -z "$cg_trailer" ]; then cg_r="no trailer line: the run stopped"
      fi
    fi
    verdict "$cg_n" "$cg_r"
  done
fi
