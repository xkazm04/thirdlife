# SEAM (spark world-sandbox, 26 Nov 2026): the seam M2 (land), M3 (pieces, stamps) and M4 (the LLM bar) build on
# (kernel/world/build/, LANES.md). Headless, no landscape: the layer registry of the edit log and its stub layers'
# refusals, tl.build/1 bytes as M1 wrote them and tl.build/2, build.json made v2 before the first op v1 cannot read is
# journaled, the build-mode tools (T, Shift+T, Enter) and their hotbar lines, a dry run that leaves the Home untouched,
# read_region, protection rules, and since M5 tl.build/3 with per-op-kind versions and the M5 layer interface
# (offers, expand_input, preview_nodes, water_runs, the plant scatter: kernel/world/build/seam_case.gd, seam_v3.gd).
# Frames, not wall clock; the final marker is required.
# Runs on its own too: `bash engine/tools/selftest.d/754-home-build-seam.sh` prints `HOME seam ok`.
home_seam_cases=(home.seam.registry home.seam.stubs home.seam.files home.seam.mark home.seam.tools home.seam.preview home.seam.region home.seam.protect home.seam.v3 home.seam.m5)
if ! declare -F verdict >/dev/null; then
  HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  OUT="${TL_SELFTEST_DIR:-$(mktemp -d)}"
  pass=0; fail=0; FILTER=""
  verdict() { if [ -z "$2" ]; then echo "PASS $1${3:+  ($3)}"; pass=$((pass+1)); else echo "FAIL $1: $2"; fail=$((fail+1)); fi; }
  home_seam_alone=1
fi
if [ -z "$FILTER" ] || [[ "${home_seam_cases[*]}" == *"$FILTER"* ]]; then
  home_seam_engine="$(cd "$HERE/.." && pwd)"
  command -v cygpath >/dev/null 2>&1 && home_seam_engine="$(cygpath -am "$home_seam_engine")"
  home_seam_log="$OUT/home-build-seam.log"
  home_seam_rc=0
  TL_HOME= TL_STYLE=crisp MSYS_NO_PATHCONV=1 "${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}" \
    --headless --fixed-fps 60 --quit-after 1200 --path "$home_seam_engine" \
    --script res://kernel/world/build/seam_case.gd >"$home_seam_log" 2>&1 || home_seam_rc=$?
  for home_seam_case in "${home_seam_cases[@]}"; do
    home_seam_name="${home_seam_case#home.}"
    home_seam_line="$(tr -d '\r' <"$home_seam_log" | grep -F "HOME $home_seam_name " | head -1)"
    why=""
    if [ "$home_seam_rc" != 0 ] || ! grep -q '^HOME DONE' "$home_seam_log"; then
      why="stopped run (Godot exit $home_seam_rc), ${home_seam_line:-missing $home_seam_case}; see $home_seam_log"
    elif grep -qE '^SCRIPT ERROR|^ERROR:' "$home_seam_log"; then
      why="$(grep -m1 -E '^SCRIPT ERROR|^ERROR:' "$home_seam_log")"
    elif [[ "$home_seam_line" != "HOME $home_seam_name ok "* ]]; then
      why="${home_seam_line:-missing HOME $home_seam_name verdict}"
    fi
    verdict "$home_seam_case" "$why" "${home_seam_line#HOME "$home_seam_name" ok }"
  done
  if [ -n "${home_seam_alone:-}" ]; then
    if [ "$fail" = 0 ] && [ "$pass" = "${#home_seam_cases[@]}" ] && tr -d '\r' <"$home_seam_log" | grep -qx 'HOME seam ok'; then
      echo "HOME seam ok"
    else
      echo "HOME seam fail ($pass passed, $fail failed; see $home_seam_log)"
    fi
  fi
fi
