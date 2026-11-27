# S2-juice arm A (juice day, 27 Nov 2026): the juice pass is automatic on a change that adds a move (foreman/src/juicepass.ts,
# JUICE_MODE "auto"); the done screen says it ran and that "keep it plain" leaves it out (ui/create/create_juice_case.gd,
# headless, nothing started).
#   create.juice.note    the pass ran: the done screen says so and how to leave it out; no card, no follow-up
#   create.juice.plain   no note when it did not run; the words go out as typed
cj_names="create.juice.note create.juice.plain"
cj_wanted=0
for cj_n in $cj_names; do if [ -z "$FILTER" ] || [[ "$cj_n" == *"$FILTER"* ]]; then cj_wanted=1; fi; done
if [ "$cj_wanted" = 1 ]; then
  cj_godot="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  cj_engine="$(cd "$HERE/.." && pwd)"
  command -v cygpath >/dev/null 2>&1 && cj_engine="$(cygpath -m "$cj_engine")"
  cj_out="$(MSYS_NO_PATHCONV=1 timeout 120 "$cj_godot" --headless --path "$cj_engine" --script res://ui/create/create_juice_case.gd 2>&1 | tr -d '\015')"
  cj_trailer="$(echo "$cj_out" | grep -a '^\[juice\] [0-9]* passed, [0-9]* failed' | tail -1)"
  for cj_n in $cj_names; do
    if [ -n "$FILTER" ] && [[ "$cj_n" != *"$FILTER"* ]]; then continue; fi
    cj_pass="$(echo "$cj_out" | grep -ac "^PASS $cj_n")"
    cj_fail="$(echo "$cj_out" | grep -a "^FAIL $cj_n" | head -1)"
    cj_why=""
    if [ -n "$cj_fail" ]; then cj_why="${cj_fail#FAIL }"
    elif [ "$cj_pass" = 0 ]; then cj_why="no PASS $cj_n line (${cj_trailer:-no trailer: the run stopped})"
    elif echo "$cj_out" | grep -aq 'SCRIPT ERROR'; then cj_why="script error: $(echo "$cj_out" | grep -a 'SCRIPT ERROR' | head -1)"
    elif [ -z "$cj_trailer" ]; then cj_why="no trailer line: the run stopped"
    fi
    verdict "$cj_n" "$cj_why" "$cj_pass checks"
  done
fi
