# H1h of 25 Nov 2026 (the Director's answer to H1g; create.pause.path's run 2 of 3): a quality hold's card waits while the
# Foreman that wrote the hold still holds the job, as Pass waits for `settling` (create.gd, create_pause.gd). Headless;
# nothing is started (ui/create/create_settle_case.gd).
#   create.settle.wait   a lock held by a live process: no Fix it / It's fine / Change it, the page says building
#   create.settle.card   the lock gone: the card shows its three answers
cs_names="create.settle.wait create.settle.card"
cs_wanted=0
for cs_n in $cs_names; do if [ -z "$FILTER" ] || [[ "$cs_n" == *"$FILTER"* ]]; then cs_wanted=1; fi; done
if [ "$cs_wanted" = 1 ]; then
  cs_godot="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  cs_engine="$(cd "$HERE/.." && pwd)"
  command -v cygpath >/dev/null 2>&1 && cs_engine="$(cygpath -m "$cs_engine")"
  cs_out="$(MSYS_NO_PATHCONV=1 timeout 120 "$cs_godot" --headless --path "$cs_engine" --script res://ui/create/create_settle_case.gd 2>&1 | tr -d '\015')"
  cs_trailer="$(echo "$cs_out" | grep -a '^\[settle\] [0-9]* passed, [0-9]* failed' | tail -1)"
  for cs_n in $cs_names; do
    if [ -n "$FILTER" ] && [[ "$cs_n" != *"$FILTER"* ]]; then continue; fi
    cs_pass="$(echo "$cs_out" | grep -ac "^PASS $cs_n")"
    cs_fail="$(echo "$cs_out" | grep -a "^FAIL $cs_n" | head -1)"
    cs_why=""
    if [ -n "$cs_fail" ]; then cs_why="${cs_fail#FAIL }"
    elif [ "$cs_pass" = 0 ]; then cs_why="no PASS $cs_n line (${cs_trailer:-no trailer: the run stopped})"
    elif echo "$cs_out" | grep -aq 'SCRIPT ERROR'; then cs_why="script error: $(echo "$cs_out" | grep -a 'SCRIPT ERROR' | head -1)"
    elif [ -z "$cs_trailer" ]; then cs_why="no trailer line: the run stopped"
    fi
    verdict "$cs_n" "$cs_why" "$cs_pass checks"
  done
fi
