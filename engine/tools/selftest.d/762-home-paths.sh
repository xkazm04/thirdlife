# M5 (spark world-sandbox, lane P, 27 Nov 2026): paths and the plant scatter in the Home (kernel/world/build/
# paths_layer.gd and its path_*.gd, tools/path_tool.gd, plant_scatter.gd). In the landscape of boot/village.json a
# headless case drives the path tool as a person does (B, T, 1-6, 0, the wheel, the pointer on the ground, LMB, RMB,
# Enter, Backspace, Ctrl+Z / Ctrl+Y), then asks the layer: one batch of path + grading, a mesh per crossed chunk, the
# grading's reach and limit, a refused vertex skipped, undo exact, unpath, unique ids and the refusals, save v3 ->
# load -> save byte-identical, the scatter deterministic, dense as asked and off paths, water and protected cells, and
# the cost (kernel/world/build/path_case.gd). Frames, not wall clock; the final marker is required.
# Runs on its own too: `bash engine/tools/selftest.d/762-home-paths.sh` prints `HOME paths ok` when it passes.
home_paths_cases=(home.paths.lay home.paths.grade home.paths.skip home.paths.undo home.paths.unpath home.paths.ids home.paths.enter home.paths.files home.paths.scatter home.paths.cost)
if ! declare -F verdict >/dev/null; then
  HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  OUT="${TL_SELFTEST_DIR:-$(mktemp -d)}"
  pass=0; fail=0; FILTER=""
  verdict() { if [ -z "$2" ]; then echo "PASS $1${3:+  ($3)}"; pass=$((pass+1)); else echo "FAIL $1: $2"; fail=$((fail+1)); fi; }
  home_paths_alone=1
fi
if [ -z "$FILTER" ] || [[ "${home_paths_cases[*]}" == *"$FILTER"* ]]; then
  home_paths_engine="$(cd "$HERE/.." && pwd)"
  command -v cygpath >/dev/null 2>&1 && home_paths_engine="$(cygpath -am "$home_paths_engine")"
  home_paths_log="$OUT/home-paths.log"
  home_paths_rc=0
  TL_HOME= TL_STYLE=crisp MSYS_NO_PATHCONV=1 "${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}" \
    --headless --fixed-fps 60 --quit-after 6000 --path "$home_paths_engine" \
    --script res://kernel/world/build/path_case.gd >"$home_paths_log" 2>&1 || home_paths_rc=$?
  for home_paths_case in "${home_paths_cases[@]}"; do
    home_paths_name="${home_paths_case#home.}"
    home_paths_line="$(tr -d '\r' <"$home_paths_log" | grep -F "HOME $home_paths_name " | head -1)"
    why=""
    if [ "$home_paths_rc" != 0 ] || ! grep -q '^HOME DONE' "$home_paths_log"; then
      why="stopped run (Godot exit $home_paths_rc), ${home_paths_line:-missing $home_paths_case}; see $home_paths_log"
    elif grep -qE '^SCRIPT ERROR|^ERROR:' "$home_paths_log"; then
      why="$(grep -m1 -E '^SCRIPT ERROR|^ERROR:' "$home_paths_log")"
    elif [[ "$home_paths_line" != "HOME $home_paths_name ok "* ]]; then
      why="${home_paths_line:-missing HOME $home_paths_name verdict}"
    fi
    verdict "$home_paths_case" "$why" "${home_paths_line#HOME "$home_paths_name" ok }"
  done
  if [ -n "${home_paths_alone:-}" ]; then
    if [ "$fail" = 0 ] && [ "$pass" = "${#home_paths_cases[@]}" ] && tr -d '\r' <"$home_paths_log" | grep -qx 'HOME paths ok'; then
      echo "HOME paths ok"
    else
      echo "HOME paths fail ($pass passed, $fail failed; see $home_paths_log)"
    fi
  fi
fi
