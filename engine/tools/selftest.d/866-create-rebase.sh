# A finished game moves to the newest base from My games (lane H2, 25 Nov): ui/create/create_rebase_case.gd, headless, the
# door dry (nothing is started). The Foreman's side (foreman rebase: what moves, what stays, verified, promoted) is
# foreman/src/test/h2_rebase.test.ts.
#   create.rebase.model  a game on an older base counts the base files it lacks or holds older; current and non-base games 0
#   create.rebase.word   a job the Foreman is moving reads "Moving to the newest base"
#   create.rebase.row    My games draws "Newest base" on that game's row only
#   create.rebase.send   the control sends exactly `foreman rebase <job>` and says so in words
crb_names="create.rebase.model create.rebase.word create.rebase.row create.rebase.send"
crb_wanted=0
for crb_n in $crb_names; do if [ -z "$FILTER" ] || [[ "$crb_n" == *"$FILTER"* ]]; then crb_wanted=1; fi; done
if [ "$crb_wanted" = 1 ]; then
  crb_godot="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  crb_engine="$(cd "$HERE/.." && pwd)"
  command -v cygpath >/dev/null 2>&1 && crb_engine="$(cygpath -m "$crb_engine")"
  crb_out="$(MSYS_NO_PATHCONV=1 timeout 180 "$crb_godot" --headless --path "$crb_engine" --script res://ui/create/create_rebase_case.gd 2>&1 | tr -d '\015')"
  crb_trailer="$(echo "$crb_out" | grep -a '^\[create-rebase\] [0-9]* passed, [0-9]* failed' | tail -1)"
  for crb_n in $crb_names; do
    if [ -n "$FILTER" ] && [[ "$crb_n" != *"$FILTER"* ]]; then continue; fi
    crb_fail="$(echo "$crb_out" | grep -a "^FAIL $crb_n" | head -1)"
    crb_why=""
    if [ -n "$crb_fail" ]; then crb_why="${crb_fail#FAIL }"
    elif ! echo "$crb_out" | grep -aq "^PASS $crb_n"; then crb_why="no PASS $crb_n line (${crb_trailer:-no trailer: the run stopped})"
    elif echo "$crb_out" | grep -aq 'SCRIPT ERROR'; then crb_why="script error: $(echo "$crb_out" | grep -a 'SCRIPT ERROR' | head -1)"
    elif [ -z "$crb_trailer" ]; then crb_why="no trailer line: the run stopped"
    fi
    verdict "$crb_n" "$crb_why"
  done
fi
