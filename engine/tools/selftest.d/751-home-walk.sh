# D1 (day of 22 Nov 2026): the Home (arm A, Wren Valley) is walkable in the normal World. The landscape of
# boot/village.json is built (landscape.home "wren", kernel/world/home/hook.gd) and the visitor's own body walks out of
# the village over the mill bridge to Mill Green, runs at five valley trunks, then is dropped at five far places (kernel/world/home/walk_case.gd).
# Frames, not wall clock: one body step per physics frame. The final marker is required even on a clean exit.
home_walk_cases=(home.walk home.bridge home.trees home.drops)
if [ -z "$FILTER" ] || [[ "${home_walk_cases[*]}" == *"$FILTER"* ]]; then
  home_walk_engine="$(cd "$HERE/.." && pwd)"
  command -v cygpath >/dev/null 2>&1 && home_walk_engine="$(cygpath -am "$home_walk_engine")"
  home_walk_log="$OUT/home-walk.log"
  home_walk_rc=0
  TL_HOME= TL_STYLE=crisp MSYS_NO_PATHCONV=1 "${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}" \
    --headless --fixed-fps 60 --quit-after 2000 --path "$home_walk_engine" \
    --script res://kernel/world/home/walk_case.gd >"$home_walk_log" 2>&1 || home_walk_rc=$?
  for home_walk_case in "${home_walk_cases[@]}"; do
    home_walk_name="${home_walk_case#home.}"
    home_walk_line="$(tr -d '\r' <"$home_walk_log" | grep -F "HOME $home_walk_name " | head -1)"
    why=""
    if [ "$home_walk_rc" != 0 ] || ! grep -q '^HOME DONE' "$home_walk_log"; then
      why="stopped run (Godot exit $home_walk_rc), ${home_walk_line:-missing $home_walk_case}; see $home_walk_log"
    elif grep -qE '^SCRIPT ERROR|^ERROR:' "$home_walk_log"; then
      why="$(grep -m1 -E '^SCRIPT ERROR|^ERROR:' "$home_walk_log")"
    elif [[ "$home_walk_line" != "HOME $home_walk_name ok "* ]]; then
      why="${home_walk_line:-missing HOME $home_walk_name verdict}"
    fi
    verdict "$home_walk_case" "$why" "${home_walk_line#HOME "$home_walk_name" ok }"
  done
fi
