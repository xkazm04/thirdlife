# H1c of 25 Nov 2026 (lane H1, lane G1's Arsenal job: the shield changed no match, pro 8 of 20 with and without it): at a
# phase pause of a game on a core, the measured card says which toy is worth about nothing, in the check's words
# (check_cartridge.mjs --toys -> coreroute.ts toyLines -> the report's run.toys -> create_model.gd measured_view ->
# create_pause.gd). Headless; nothing is started.
#   create.toys.model   the measured view carries the toy lines of the report
#   create.toys.card    the card shows them (Toy0, Toy1) inside it, beside Try it
# Each is a PASS line of ui/create/create_toys_case.gd; a missing line or a stopped run is a FAIL.
ct_names="create.toys.model create.toys.card"
ct_wanted=0
for ct_n in $ct_names; do if [ -z "$FILTER" ] || [[ "$ct_n" == *"$FILTER"* ]]; then ct_wanted=1; fi; done
if [ "$ct_wanted" = 1 ]; then
  ct_godot="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  ct_engine="$(cd "$HERE/.." && pwd)"
  command -v cygpath >/dev/null 2>&1 && ct_engine="$(cygpath -m "$ct_engine")"
  ct_out="$(MSYS_NO_PATHCONV=1 timeout 120 "$ct_godot" --headless --path "$ct_engine" --script res://ui/create/create_toys_case.gd 2>&1 | tr -d '\015')"
  ct_trailer="$(echo "$ct_out" | grep -a '^\[toys\] [0-9]* passed, [0-9]* failed' | tail -1)"
  for ct_n in $ct_names; do
    if [ -n "$FILTER" ] && [[ "$ct_n" != *"$FILTER"* ]]; then continue; fi
    ct_pass="$(echo "$ct_out" | grep -ac "^PASS $ct_n")"
    ct_fail="$(echo "$ct_out" | grep -a "^FAIL $ct_n" | head -1)"
    ct_why=""
    if [ -n "$ct_fail" ]; then ct_why="${ct_fail#FAIL }"
    elif [ "$ct_pass" = 0 ]; then ct_why="no PASS $ct_n line (${ct_trailer:-no trailer: the run stopped})"
    elif echo "$ct_out" | grep -aq 'SCRIPT ERROR'; then ct_why="script error: $(echo "$ct_out" | grep -a 'SCRIPT ERROR' | head -1)"
    elif [ -z "$ct_trailer" ]; then ct_why="no trailer line: the run stopped"
    fi
    verdict "$ct_n" "$ct_why" "$ct_pass checks"
  done
fi
