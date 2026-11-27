# Lane K (spark world-sandbox M5, 27 Nov 2026): the visitor climbs real steps. Headless, frames only: in world spaces of
# their own the visitor's walkers (world_space.gd `drive` at 4.5 and 9 m/s, `walk`) go up and down two Home stair blocks
# (block_mesh.gd collides them as drawn, eight 0.25 m steps), the same steps from boxes, a 0.5 m slab ledge, a slab in front of a cube and a 0.25 m
# kerb with no dip and no air frame, are stopped by a 1 m block and by a kerb that is not a Home block, and a pack's walker (world_body.gd without
# `step_risers`) walks a byte-identical path to the seam's (kernel/world/terrain/walker_steps_case.gd). The final marker
# is required. Runs on its own too: `bash engine/tools/selftest.d/766-walker-steps.sh` prints `HOME walker-steps ok`.
home_walker_steps_cases=(home.walker-steps.stair home.walker-steps.boxes home.walker-steps.ledge home.walker-steps.halfstep home.walker-steps.kerb home.walker-steps.wall home.walker-steps.bush home.walker-steps.packs)
if ! declare -F verdict >/dev/null; then
  HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  OUT="${TL_SELFTEST_DIR:-$(mktemp -d)}"
  pass=0; fail=0; FILTER=""
  verdict() { if [ -z "$2" ]; then echo "PASS $1${3:+  ($3)}"; pass=$((pass+1)); else echo "FAIL $1: $2"; fail=$((fail+1)); fi; }
  home_walker_steps_alone=1
fi
if [ -z "$FILTER" ] || [[ "${home_walker_steps_cases[*]}" == *"$FILTER"* ]]; then
  home_walker_steps_engine="$(cd "$HERE/.." && pwd)"
  command -v cygpath >/dev/null 2>&1 && home_walker_steps_engine="$(cygpath -am "$home_walker_steps_engine")"
  home_walker_steps_log="$OUT/home-walker-steps.log"
  home_walker_steps_rc=0
  TL_HOME= TL_STYLE=crisp MSYS_NO_PATHCONV=1 "${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}" \
    --headless --fixed-fps 60 --quit-after 600 --path "$home_walker_steps_engine" \
    --script res://kernel/world/terrain/walker_steps_case.gd >"$home_walker_steps_log" 2>&1 || home_walker_steps_rc=$?
  for home_walker_steps_case in "${home_walker_steps_cases[@]}"; do
    home_walker_steps_name="${home_walker_steps_case#home.walker-steps.}"
    home_walker_steps_line="$(tr -d '\r' <"$home_walker_steps_log" | grep -F "WALKSTEP $home_walker_steps_name " | head -1)"
    why=""
    if [ "$home_walker_steps_rc" != 0 ] && ! grep -q '^WALKSTEP DONE' "$home_walker_steps_log"; then
      why="stopped run (Godot exit $home_walker_steps_rc), ${home_walker_steps_line:-missing $home_walker_steps_case}; see $home_walker_steps_log"
    elif ! grep -q '^WALKSTEP DONE' "$home_walker_steps_log"; then
      why="stopped run (no WALKSTEP DONE); see $home_walker_steps_log"
    elif grep -qE '^SCRIPT ERROR|^ERROR:' "$home_walker_steps_log"; then
      why="$(grep -m1 -E '^SCRIPT ERROR|^ERROR:' "$home_walker_steps_log")"
    elif [[ "$home_walker_steps_line" != "WALKSTEP $home_walker_steps_name ok "* ]]; then
      why="${home_walker_steps_line:-missing WALKSTEP $home_walker_steps_name verdict}"
    fi
    verdict "$home_walker_steps_case" "$why" "${home_walker_steps_line#WALKSTEP "$home_walker_steps_name" ok }"
  done
  if [ -n "${home_walker_steps_alone:-}" ]; then
    if [ "$fail" = 0 ] && [ "$pass" = "${#home_walker_steps_cases[@]}" ] && tr -d '\r' <"$home_walker_steps_log" | grep -qx 'WALKSTEP ok'; then
      echo "HOME walker-steps ok"
    else
      echo "HOME walker-steps fail ($pass passed, $fail failed; see $home_walker_steps_log)"
    fi
  fi
fi
