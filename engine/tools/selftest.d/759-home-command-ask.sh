# M4 (spark world-sandbox, 26 Nov 2026): the ask of the LLM command bar, tl.world-edit-ask/1 (contracts/BUILD.md
# "The LLM command bar", kernel/world/build/COMMAND.md). A headless case writes the ask for a sentence at a cell 6 m
# beside the first game lot of boot/village.json (kernel/world/build/command_case.gd `-- ask <file>`) and checks its
# contents against the Home (the lot's columns refused as "game lot", the ground = home/hook.gd ground_y, the block
# placed there, the facing, the caps); then the Foreman's own reader (foreman/dist/world_edit.js `readAsk`, the strict
# schema `foreman world-edit` refuses an ask with) reads the same file. Both must pass; a missing foreman/dist or node
# is a FAIL that says so. Runs on its own too: `bash engine/tools/selftest.d/759-home-command-ask.sh` prints
# `HOME command-ask ok` when it passes.
home_cask_cases=(home.command.ask_file home.command.ask_foreman)
if ! declare -F verdict >/dev/null; then
  HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  OUT="${TL_SELFTEST_DIR:-$(mktemp -d)}"
  pass=0; fail=0; FILTER=""
  verdict() { if [ -z "$2" ]; then echo "PASS $1${3:+  ($3)}"; pass=$((pass+1)); else echo "FAIL $1: $2"; fail=$((fail+1)); fi; }
  home_cask_alone=1
fi
if [ -z "$FILTER" ] || [[ "${home_cask_cases[*]}" == *"$FILTER"* ]]; then
  home_cask_engine="$(cd "$HERE/.." && pwd)"
  home_cask_repo="$(cd "$HERE/../.." && pwd)"
  home_cask_file="$OUT/home-command-ask.json"
  command -v cygpath >/dev/null 2>&1 && home_cask_engine="$(cygpath -am "$home_cask_engine")" && home_cask_repo="$(cygpath -am "$home_cask_repo")" && home_cask_file="$(cygpath -am "$home_cask_file")"
  home_cask_log="$OUT/home-command-ask.log"
  rm -f "$home_cask_file"
  home_cask_rc=0
  TL_HOME= TL_STYLE=crisp TL_COMMAND_DEVICES= MSYS_NO_PATHCONV=1 "${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}" \
    --headless --fixed-fps 60 --quit-after 1200 --path "$home_cask_engine" \
    --script res://kernel/world/build/command_case.gd -- ask "$home_cask_file" >"$home_cask_log" 2>&1 || home_cask_rc=$?
  home_cask_line="$(tr -d '\r' <"$home_cask_log" | grep -F "HOME command.ask_file " | head -1)"
  why=""
  if [ "$home_cask_rc" != 0 ] || ! grep -q '^HOME DONE' "$home_cask_log"; then
    why="stopped run (Godot exit $home_cask_rc), ${home_cask_line:-missing home.command.ask_file}; see $home_cask_log"
  elif grep -qE '^SCRIPT ERROR|^ERROR:' "$home_cask_log"; then
    why="$(grep -m1 -E '^SCRIPT ERROR|^ERROR:' "$home_cask_log")"
  elif [[ "$home_cask_line" != "HOME command.ask_file ok "* ]]; then
    why="${home_cask_line:-missing HOME command.ask_file verdict}"
  fi
  verdict home.command.ask_file "$why" "${home_cask_line#HOME command.ask_file ok }"
  why=""; home_cask_said=""
  home_cask_js="$home_cask_repo/foreman/dist/world_edit.js"
  if ! command -v node >/dev/null 2>&1; then
    why="could not run: node is not on PATH"
  elif [ ! -f "$home_cask_js" ]; then
    why="could not run: no $home_cask_js (npm run build in foreman/)"
  elif [ ! -f "$home_cask_file" ]; then
    why="no ask was written (see $home_cask_log)"
  else
    home_cask_said="$(node --input-type=module -e "
      const m = await import('file:///' + process.argv[1].replace(/^\/+/, ''));
      const a = m.readAsk(process.argv[2]);
      const f = m.facts(a);
      console.log('read: region ' + a.region.min + '..' + a.region.max + ', ' + a.blocks.length + ' blocks, ' + (a.refused ?? []).length + ' refusal kinds, prompt facts ' + Object.values(f).join('').length + ' chars');
    " "$home_cask_js" "$home_cask_file" 2>&1)" || why="the Foreman refused the ask: $home_cask_said"
  fi
  verdict home.command.ask_foreman "$why" "$home_cask_said"
  if [ -n "${home_cask_alone:-}" ]; then
    if [ "$fail" = 0 ] && [ "$pass" = "${#home_cask_cases[@]}" ]; then echo "HOME command-ask ok"; else echo "HOME command-ask fail ($pass passed, $fail failed; see $home_cask_log)"; fi
  fi
fi
