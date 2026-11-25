# H1d of 25 Nov 2026 (lane H1; the Director's choice (b) after lane G1's first design ordered a core patch silently):
# a design card that needs new engine code carries needs "core" and hours; Create's pitch shows "+N h engine code"
# on the card and says the cost in words where the hint stands; a tap (the card's data-only alternative) takes it away.
#   create.corecost.schema  the site's strict reader takes the two keys and refuses another needs
#   create.corecost.pitch   the tag on the card and the words under the cards
#   create.corecost.swap    a tap takes the engine code away, the hint is back
# Each is a PASS line of ui/create/create_corecost_case.gd; a missing line or a stopped run is a FAIL.
cc_names="create.corecost.schema create.corecost.pitch create.corecost.swap"
cc_wanted=0
for cc_n in $cc_names; do if [ -z "$FILTER" ] || [[ "$cc_n" == *"$FILTER"* ]]; then cc_wanted=1; fi; done
if [ "$cc_wanted" = 1 ]; then
  cc_godot="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  cc_engine="$(cd "$HERE/.." && pwd)"
  command -v cygpath >/dev/null 2>&1 && cc_engine="$(cygpath -m "$cc_engine")"
  cc_out="$(MSYS_NO_PATHCONV=1 timeout 120 "$cc_godot" --headless --path "$cc_engine" --script res://ui/create/create_corecost_case.gd 2>&1 | tr -d '\015')"
  cc_trailer="$(echo "$cc_out" | grep -a '^\[corecost\] [0-9]* passed, [0-9]* failed' | tail -1)"
  for cc_n in $cc_names; do
    if [ -n "$FILTER" ] && [[ "$cc_n" != *"$FILTER"* ]]; then continue; fi
    cc_pass="$(echo "$cc_out" | grep -ac "^PASS $cc_n")"
    cc_fail="$(echo "$cc_out" | grep -a "^FAIL $cc_n" | head -1)"
    cc_why=""
    if [ -n "$cc_fail" ]; then cc_why="${cc_fail#FAIL }"
    elif [ "$cc_pass" = 0 ]; then cc_why="no PASS $cc_n line (${cc_trailer:-no trailer: the run stopped})"
    elif echo "$cc_out" | grep -aq 'SCRIPT ERROR'; then cc_why="script error: $(echo "$cc_out" | grep -a 'SCRIPT ERROR' | head -1)"
    elif [ -z "$cc_trailer" ]; then cc_why="no trailer line: the run stopped"
    fi
    verdict "$cc_n" "$cc_why" "$cc_pass checks"
  done
fi
