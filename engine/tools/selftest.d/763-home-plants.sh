# M5 lane L (spark world-sandbox, 27 Nov 2026): plants in the Home (kernel/world/build/plant_case.gd, headless, the
# landscape of boot/village.json, the plant tool driven as a person does): meadow, flowers and tall grass painted on 3 m
# cells as ONE plant op per stroke with undo, refusals, the density in the land mesh's UV and the green it draws, the
# valley's mesh and other chunks untouched, tl.build/3 `plants` save -> load -> save, the tree and bush slots calling
# plant_scatter.gd, and the plants layer's ghost. Frames, not wall clock; the final marker is required.
# Runs on its own too: `bash engine/tools/selftest.d/763-home-plants.sh` prints `HOME plants ok` when it passes.
home_plants_cases=(home.plants.tool home.plants.op home.plants.uv home.plants.unedited home.plants.files home.plants.scatter home.plants.ghost)
if ! declare -F verdict >/dev/null; then
  HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  OUT="${TL_SELFTEST_DIR:-$(mktemp -d)}"
  pass=0; fail=0; FILTER=""
  verdict() { if [ -z "$2" ]; then echo "PASS $1${3:+  ($3)}"; pass=$((pass+1)); else echo "FAIL $1: $2"; fail=$((fail+1)); fi; }
  home_plants_alone=1
fi
if [ -z "$FILTER" ] || [[ "${home_plants_cases[*]}" == *"$FILTER"* ]]; then
  home_plants_engine="$(cd "$HERE/.." && pwd)"
  command -v cygpath >/dev/null 2>&1 && home_plants_engine="$(cygpath -am "$home_plants_engine")"
  home_plants_log="$OUT/home-plants.log"
  home_plants_rc=0
  TL_HOME= TL_STYLE=crisp MSYS_NO_PATHCONV=1 "${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}" \
    --headless --fixed-fps 60 --quit-after 6000 --path "$home_plants_engine" \
    --script res://kernel/world/build/plant_case.gd >"$home_plants_log" 2>&1 || home_plants_rc=$?
  for home_plants_case in "${home_plants_cases[@]}"; do
    home_plants_name="${home_plants_case#home.}"
    home_plants_line="$(tr -d '\r' <"$home_plants_log" | grep -F "HOME $home_plants_name " | head -1)"
    why=""
    if [ "$home_plants_rc" != 0 ] || ! grep -q '^HOME DONE' "$home_plants_log"; then
      why="stopped run (Godot exit $home_plants_rc), ${home_plants_line:-missing $home_plants_case}; see $home_plants_log"
    elif grep -qE '^SCRIPT ERROR|^ERROR:' "$home_plants_log"; then
      why="$(grep -m1 -E '^SCRIPT ERROR|^ERROR:' "$home_plants_log")"
    elif [[ "$home_plants_line" != "HOME $home_plants_name ok "* ]]; then
      why="${home_plants_line:-missing HOME $home_plants_name verdict}"
    fi
    verdict "$home_plants_case" "$why" "${home_plants_line#HOME "$home_plants_name" ok }"
  done
  if [ -n "${home_plants_alone:-}" ]; then
    if [ "$fail" = 0 ] && [ "$pass" = "${#home_plants_cases[@]}" ] && tr -d '\r' <"$home_plants_log" | grep -qx 'HOME plants ok'; then
      echo "HOME plants ok"
    else
      echo "HOME plants fail ($pass passed, $fail failed; see $home_plants_log)"
    fi
  fi
fi
