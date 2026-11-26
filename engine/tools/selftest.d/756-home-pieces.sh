# M3 (spark world-sandbox, 26 Nov 2026): pieces and stamps in the Home (kernel/world/build/, PIECES.md). Headless:
# every catalogue part put, drawn, lifted, undone; footprint refusals (blocks, pieces, land and paint under a piece, a
# game lot); same ops -> same hash; tl.build/2 `pieces` saved, loaded and saved byte for byte, the journal replayed;
# read_region and a dry run; 500 fences + 200 trees drawn; a walker stopped by a placed cabin, counted in frames
# (pieces_case.gd); stamps saved from a box, placed turned 0-3 with exact cells and rots as one batch (one undo),
# exported as a .tlitem that item.gd checks as kind stamp, tier data, and imported back identical (stamp_case.gd).
# Frames, not wall clock; the final markers are required. Alone: `bash engine/tools/selftest.d/756-home-pieces.sh`
# prints `HOME pieces ok`.
home_pieces_cases=(home.pieces.each home.pieces.refuse home.pieces.hash home.pieces.files home.pieces.region home.pieces.draw home.pieces.walk
  home.stamp.save home.stamp.turns home.stamp.item home.stamp.tool)
if ! declare -F verdict >/dev/null; then
  HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  OUT="${TL_SELFTEST_DIR:-$(mktemp -d)}"
  pass=0; fail=0; FILTER=""
  verdict() { if [ -z "$2" ]; then echo "PASS $1${3:+  ($3)}"; pass=$((pass+1)); else echo "FAIL $1: $2"; fail=$((fail+1)); fi; }
  home_pieces_alone=1
fi
if [ -z "$FILTER" ] || [[ "${home_pieces_cases[*]}" == *"$FILTER"* ]]; then
  home_pieces_engine="$(cd "$HERE/.." && pwd)"
  command -v cygpath >/dev/null 2>&1 && home_pieces_engine="$(cygpath -am "$home_pieces_engine")"
  home_pieces_rc=0
  home_stamp_rc=0
  TL_HOME= TL_STYLE=crisp MSYS_NO_PATHCONV=1 "${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}" \
    --headless --fixed-fps 60 --quit-after 3000 --path "$home_pieces_engine" \
    --script res://kernel/world/build/pieces_case.gd >"$OUT/home-pieces.log" 2>&1 || home_pieces_rc=$?
  TL_HOME= TL_STYLE=crisp MSYS_NO_PATHCONV=1 "${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}" \
    --headless --fixed-fps 60 --quit-after 1200 --path "$home_pieces_engine" \
    --script res://kernel/world/build/stamp_case.gd >"$OUT/home-stamp.log" 2>&1 || home_stamp_rc=$?
  for home_pieces_case in "${home_pieces_cases[@]}"; do
    home_pieces_name="${home_pieces_case#home.}"
    if [[ "$home_pieces_name" == stamp.* ]]; then hp_log="$OUT/home-stamp.log"; hp_rc=$home_stamp_rc; hp_tag="stamp"; else hp_log="$OUT/home-pieces.log"; hp_rc=$home_pieces_rc; hp_tag="pieces"; fi
    home_pieces_line="$(tr -d '\r' <"$hp_log" | grep -F "HOME $home_pieces_name " | head -1)"
    why=""
    if [ "$hp_rc" != 0 ] || ! grep -q '^HOME DONE' "$hp_log"; then
      why="stopped run (Godot exit $hp_rc), ${home_pieces_line:-missing $home_pieces_case}; see $hp_log"
    elif grep -qE '^SCRIPT ERROR|^ERROR:' "$hp_log"; then
      why="$(grep -m1 -E '^SCRIPT ERROR|^ERROR:' "$hp_log")"
    elif [[ "$home_pieces_line" != "HOME $home_pieces_name ok "* ]]; then
      why="${home_pieces_line:-missing HOME $home_pieces_name verdict}"
    fi
    verdict "$home_pieces_case" "$why" "${home_pieces_line#HOME "$home_pieces_name" ok }"
  done
  if [ -n "${home_pieces_alone:-}" ]; then
    if [ "$fail" = 0 ] && [ "$pass" = "${#home_pieces_cases[@]}" ] && tr -d '\r' <"$OUT/home-pieces.log" | grep -qx 'HOME pieces ok' \
      && tr -d '\r' <"$OUT/home-stamp.log" | grep -qx 'HOME stamp ok'; then
      echo "HOME pieces ok"
    else
      echo "HOME pieces fail ($pass passed, $fail failed; see $OUT/home-pieces.log, $OUT/home-stamp.log)"
    fi
  fi
fi
