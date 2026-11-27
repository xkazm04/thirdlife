# M6 round 3, lane A6 (27 Nov 2026): assemblies (contracts/BUILD.md "Assemblies (M6, round 3)"; kernel/world/build/
# assembly.gd, assembly_kinds.gd, blocks_layer.gd `expand_input`, tools/assembly_tool.gd). A headless case
# (kernel/world/build/assembly_case.gd, no landscape): every kind at 3 sizes x 4 rots gives the same op list twice and
# rot 0's shape turned, no floating block, and is walkable where it says so by command_space.gd's estimate AND by a
# walker that never jumps; a stair meets a platform; bad assemblies refused with the reason; protected and occupied
# cells left out with the place ops' reasons; home_build.gd `expand_input` expands it; the Shapes tool builds ONE batch
# equal to the same assemble's expansion. No model is called. Frames, not wall clock. Runs on its own:
# `bash engine/tools/selftest.d/794-home-assembly.sh` prints `HOME assembly ok` when it passes.
home_assembly_cases=(home.assembly.kinds home.assembly.compose home.assembly.refusals home.assembly.protect home.assembly.input home.assembly.tool)
if ! declare -F verdict >/dev/null; then
  HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  OUT="${TL_SELFTEST_DIR:-$(mktemp -d)}"
  pass=0; fail=0; FILTER=""
  verdict() { if [ -z "$2" ]; then echo "PASS $1${3:+  ($3)}"; pass=$((pass+1)); else echo "FAIL $1: $2"; fail=$((fail+1)); fi; }
  home_assembly_alone=1
fi
if [ -z "$FILTER" ] || [[ "${home_assembly_cases[*]}" == *"$FILTER"* ]]; then
  home_asm_engine="$(cd "$HERE/.." && pwd)"
  command -v cygpath >/dev/null 2>&1 && home_asm_engine="$(cygpath -am "$home_asm_engine")"
  home_asm_log="$OUT/home-assembly.log"
  home_asm_rc=0
  TL_HOME= TL_STYLE=crisp TL_COMMAND_DEVICES= MSYS_NO_PATHCONV=1 "${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}" \
    --headless --fixed-fps 60 --quit-after 3000 --path "$home_asm_engine" \
    --script res://kernel/world/build/assembly_case.gd >"$home_asm_log" 2>&1 || home_asm_rc=$?
  for home_asm_case in "${home_assembly_cases[@]}"; do
    home_asm_name="${home_asm_case#home.}"
    home_asm_line="$(tr -d '\r' <"$home_asm_log" | grep -F "HOME $home_asm_name " | head -1)"
    why=""
    if [ "$home_asm_rc" != 0 ] || ! grep -q '^HOME DONE' "$home_asm_log"; then
      why="stopped run (Godot exit $home_asm_rc), ${home_asm_line:-missing $home_asm_case}; see $home_asm_log"
    elif grep -qE '^SCRIPT ERROR|^ERROR:' "$home_asm_log"; then
      why="$(grep -m1 -E '^SCRIPT ERROR|^ERROR:' "$home_asm_log")"
    elif [[ "$home_asm_line" != "HOME $home_asm_name ok "* ]]; then
      why="${home_asm_line:-missing HOME $home_asm_name verdict}"
    fi
    verdict "$home_asm_case" "$why" "${home_asm_line#HOME "$home_asm_name" ok }"
  done
  if [ -n "${home_assembly_alone:-}" ]; then
    if [ "$fail" = 0 ] && [ "$pass" = "${#home_assembly_cases[@]}" ] && tr -d '\r' <"$home_asm_log" | grep -qx 'HOME assembly ok'; then
      echo "HOME assembly ok"
    else
      echo "HOME assembly fail ($pass passed, $fail failed; see $home_asm_log)"
    fi
  fi
fi
