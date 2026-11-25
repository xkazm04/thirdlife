# H1b of 25 Nov 2026 (lane H1, G2's finding): Create's pitch shows the brief's estimate in a person's words, e.g. "About 8
# hours and 6.5 M tokens to build (9 parts)", beside Build it (ui/create/create_model.gd estimate_words, create_design.gd
# _pitch). Headless; nothing is started.
#   create.estimate.words   the words for the game lanes' real estimates (G2 9/480/6.5M, G4 10/480/8M) and the fixture's
#   create.estimate.pitch   the fixture c2-pitch's page shows its line beside Build it
#   create.estimate.none    no estimate, no line
# Each is a PASS line of ui/create/create_estimate_case.gd; a missing line or a stopped run is a FAIL.
ce_names="create.estimate.words create.estimate.pitch create.estimate.none"
ce_wanted=0
for ce_n in $ce_names; do if [ -z "$FILTER" ] || [[ "$ce_n" == *"$FILTER"* ]]; then ce_wanted=1; fi; done
if [ "$ce_wanted" = 1 ]; then
  ce_godot="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  ce_engine="$(cd "$HERE/.." && pwd)"
  command -v cygpath >/dev/null 2>&1 && ce_engine="$(cygpath -m "$ce_engine")"
  ce_out="$(MSYS_NO_PATHCONV=1 timeout 120 "$ce_godot" --headless --path "$ce_engine" --script res://ui/create/create_estimate_case.gd 2>&1 | tr -d '\015')"
  ce_trailer="$(echo "$ce_out" | grep -a '^\[estimate\] [0-9]* passed, [0-9]* failed' | tail -1)"
  for ce_n in $ce_names; do
    if [ -n "$FILTER" ] && [[ "$ce_n" != *"$FILTER"* ]]; then continue; fi
    ce_pass="$(echo "$ce_out" | grep -ac "^PASS $ce_n")"
    ce_fail="$(echo "$ce_out" | grep -a "^FAIL $ce_n" | head -1)"
    ce_why=""
    if [ -n "$ce_fail" ]; then ce_why="${ce_fail#FAIL }"
    elif [ "$ce_pass" = 0 ]; then ce_why="no PASS $ce_n line (${ce_trailer:-no trailer: the run stopped})"
    elif echo "$ce_out" | grep -aq 'SCRIPT ERROR'; then ce_why="script error: $(echo "$ce_out" | grep -a 'SCRIPT ERROR' | head -1)"
    elif [ -z "$ce_trailer" ]; then ce_why="no trailer line: the run stopped"
    fi
    verdict "$ce_n" "$ce_why" "$ce_pass checks"
  done
fi
