# 26 Nov 2026 (the owner: the Dungeons list cannot be browsed past one screen, and one game shows once per version): the
# main menu's Dungeons list in pages, and one row per game (boot/menu_case.gd). Headless; nothing is started.
#   menu.pages     12 rows show 5 a page; Next / Previous turn and switch off at the ends; a row emits its whole-list index
#   menu.versions  read_menu keeps one row per game (the highest pack.json version), the person's newest game first
mp_names="menu.pages menu.versions"
mp_wanted=0
for mp_n in $mp_names; do if [ -z "$FILTER" ] || [[ "$mp_n" == *"$FILTER"* ]]; then mp_wanted=1; fi; done
if [ "$mp_wanted" = 1 ]; then
  mp_godot="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  mp_engine="$(cd "$HERE/.." && pwd)"
  command -v cygpath >/dev/null 2>&1 && mp_engine="$(cygpath -m "$mp_engine")"
  mp_out="$(MSYS_NO_PATHCONV=1 timeout 120 "$mp_godot" --headless --path "$mp_engine" --script res://boot/menu_case.gd 2>&1 | tr -d '\015')"
  mp_trailer="$(echo "$mp_out" | grep -a '^\[menu\] [0-9]* passed, [0-9]* failed' | tail -1)"
  for mp_n in $mp_names; do
    if [ -n "$FILTER" ] && [[ "$mp_n" != *"$FILTER"* ]]; then continue; fi
    mp_fail="$(echo "$mp_out" | grep -a "^FAIL $mp_n" | head -1)"
    mp_why=""
    if [ -n "$mp_fail" ]; then mp_why="${mp_fail#FAIL }"
    elif ! echo "$mp_out" | grep -aq "^PASS $mp_n"; then mp_why="no PASS $mp_n line (${mp_trailer:-no trailer: the run stopped})"
    elif echo "$mp_out" | grep -aq 'SCRIPT ERROR'; then mp_why="script error: $(echo "$mp_out" | grep -a 'SCRIPT ERROR' | head -1)"
    fi
    verdict "$mp_n" "$mp_why" "1 check"
  done
fi
