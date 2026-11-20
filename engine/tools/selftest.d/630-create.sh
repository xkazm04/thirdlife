# Night of 21 Nov 2026, lane L3 (create-screen): the designer v2 readers and the Create page, from the fixture job logs
# in engine/ui/fixtures/create/ (written against contracts/JOB.md "Added 2026-11-20"). Headless; nothing is started.
#   create.schema   site/event_schema.gd (the village site's strict reader) takes every fixture event, refuses 21 broken
#                   copies of the new events, and the every-key fixtures hold all 29 new keys
#   create.model    job_model.gd + ui/create/create_model.gd: screens, reactions, the phase strip, a v1 job
#   create.door     the Foreman command lines the page writes, word for word as JOB.md gives them; the try-it process
#   create.page     ui/create/create.tscn driven from the fixtures: every screen, tap tap Build it, Tell me more,
#                   Try it / Pass / Hold + note, words on each screen
#   create.site     kernel/world/site.gd `phase_of`: the sign's "phase n of m: <title>"
# Each is one or more PASS lines of ui/create/create_case.gd; a missing line or a stopped run is a FAIL.
cr_names="create.schema create.model create.door create.page create.site create.complete"
cr_wanted=0
for cr_n in $cr_names; do if [ -z "$FILTER" ] || [[ "$cr_n" == *"$FILTER"* ]]; then cr_wanted=1; fi; done
if [ "$cr_wanted" = 1 ]; then
  cr_godot="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  cr_engine="$(cd "$HERE/.." && pwd)"
  command -v cygpath >/dev/null 2>&1 && cr_engine="$(cygpath -m "$cr_engine")"
  cr_out="$(MSYS_NO_PATHCONV=1 timeout 180 "$cr_godot" --headless --path "$cr_engine" --script res://ui/create/create_case.gd 2>&1 | tr -d '\015')"
  cr_trailer="$(echo "$cr_out" | grep -a '^\[create\] [0-9]* passed, [0-9]* failed' | tail -1)"
  for cr_n in $cr_names; do
    if [ -n "$FILTER" ] && [[ "$cr_n" != *"$FILTER"* ]]; then continue; fi
    cr_pass="$(echo "$cr_out" | grep -ac "^PASS $cr_n")"
    cr_fail="$(echo "$cr_out" | grep -a "^FAIL $cr_n" | head -1)"
    cr_why=""
    if [ -n "$cr_fail" ]; then cr_why="${cr_fail#FAIL }"
    elif [ "$cr_pass" = 0 ]; then cr_why="no PASS $cr_n line (${cr_trailer:-no trailer: the run stopped})"
    elif echo "$cr_out" | grep -aq 'SCRIPT ERROR'; then cr_why="script error: $(echo "$cr_out" | grep -a 'SCRIPT ERROR' | head -1)"
    elif [ -z "$cr_trailer" ]; then cr_why="no trailer line: the run stopped"
    fi
    verdict "$cr_n" "$cr_why" "$cr_pass checks"
  done
fi
