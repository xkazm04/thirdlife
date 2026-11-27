# M6 lane C (27 Nov 2026): the LLM command bar's M6 part (kernel/world/build/COMMAND.md "M6"). In the landscape of
# boot/village.json a headless case (kernel/world/build/command_m6_case.gd) drives build mode as a person does, with a
# DRY Foreman door and the answer files a FAKE Foreman would write, on a hand-laid stone platform: the ask carries
# `zones`, `rules` and `rules_room` at the top level (and the Foreman's own reader, foreman/dist/world_edit.js
# `readAsk`, reads it; the prompt it renders is measured with and without the zones-and-rules section); an answer with
# a floating block, a pad over nothing and a coin in a cube shows the space check's line and red marks; the
# reachability estimate on three courses (reachable, a gap too wide, a wall too high); a course answer counts its
# zones and rules, keeps as ONE batch with renumbered ids, and a headless replay of its run over the check's walk
# takes every coin and finishes. No model is called. Frames, not wall clock; the final marker is required. Runs on its
# own too: `bash engine/tools/selftest.d/785-home-command-m6.sh` prints `HOME command-m6 ok` when it passes.
home_command_m6_cases=(home.command-m6.ask home.command-m6.floating home.command-m6.reach home.command-m6.course home.command-m6.replay home.command-m6.ask_foreman)
if ! declare -F verdict >/dev/null; then
  HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  OUT="${TL_SELFTEST_DIR:-$(mktemp -d)}"
  pass=0; fail=0; FILTER=""
  verdict() { if [ -z "$2" ]; then echo "PASS $1${3:+  ($3)}"; pass=$((pass+1)); else echo "FAIL $1: $2"; fail=$((fail+1)); fi; }
  home_command_m6_alone=1
fi
if [ -z "$FILTER" ] || [[ "${home_command_m6_cases[*]}" == *"$FILTER"* ]]; then
  home_cm6_engine="$(cd "$HERE/.." && pwd)"
  home_cm6_repo="$(cd "$HERE/../.." && pwd)"
  home_cm6_ask="$OUT/home-command-m6-ask.json"
  command -v cygpath >/dev/null 2>&1 && home_cm6_engine="$(cygpath -am "$home_cm6_engine")" && home_cm6_repo="$(cygpath -am "$home_cm6_repo")" && home_cm6_ask="$(cygpath -am "$home_cm6_ask")"
  home_cm6_log="$OUT/home-command-m6.log"
  rm -f "$home_cm6_ask"
  home_cm6_rc=0
  TL_HOME= TL_STYLE=crisp TL_COMMAND_DEVICES= MSYS_NO_PATHCONV=1 "${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}" \
    --headless --fixed-fps 60 --quit-after 3000 --path "$home_cm6_engine" \
    --script res://kernel/world/build/command_m6_case.gd -- "$home_cm6_ask" >"$home_cm6_log" 2>&1 || home_cm6_rc=$?
  for home_cm6_case in "${home_command_m6_cases[@]}"; do
    [ "$home_cm6_case" = home.command-m6.ask_foreman ] && continue
    home_cm6_name="${home_cm6_case#home.}"
    home_cm6_line="$(tr -d '\r' <"$home_cm6_log" | grep -F "HOME $home_cm6_name " | head -1)"
    why=""
    if [ "$home_cm6_rc" != 0 ] || ! grep -q '^HOME DONE' "$home_cm6_log"; then
      why="stopped run (Godot exit $home_cm6_rc), ${home_cm6_line:-missing $home_cm6_case}; see $home_cm6_log"
    elif grep -qE '^SCRIPT ERROR|^ERROR:' "$home_cm6_log"; then
      why="$(grep -m1 -E '^SCRIPT ERROR|^ERROR:' "$home_cm6_log")"
    elif [[ "$home_cm6_line" != "HOME $home_cm6_name ok "* ]]; then
      why="${home_cm6_line:-missing HOME $home_cm6_name verdict}"
    fi
    verdict "$home_cm6_case" "$why" "${home_cm6_line#HOME "$home_cm6_name" ok }"
  done
  why=""; home_cm6_said=""
  home_cm6_js="$home_cm6_repo/foreman/dist/world_edit.js"
  if ! command -v node >/dev/null 2>&1; then
    why="could not run: node is not on PATH"
  elif [ ! -f "$home_cm6_js" ]; then
    why="could not run: no $home_cm6_js (npm run build in foreman/)"
  elif [ ! -f "$home_cm6_ask" ]; then
    why="no ask was written (see $home_cm6_log)"
  else
    home_cm6_said="$(node --input-type=module -e "
      const fs = await import('node:fs');
      const path = await import('node:path');
      const js = process.argv[1].replace(/^\/+/, '');
      const m = await import('file:///' + js);
      const g = await import('file:///' + path.join(path.dirname(js), 'generate.js'));
      const a = m.readAsk(process.argv[2]);
      if (!a.zones || !a.rules || !a.rules_room || (a.layers && (a.layers.zones || a.layers.rules))) throw new Error('the M6 keys are not top level');
      const f = m.facts(a);
      const tpl = fs.readFileSync(path.join(path.dirname(js), '..', 'prompts', 'world_edit.md'), 'utf8');
      const schema = JSON.stringify(JSON.parse(fs.readFileSync(path.join(path.dirname(js), '..', 'prompts', 'world_edit.schema.json'), 'utf8')), null, 1);
      const full = g.render(tpl, { ...f, schema, feedback: '' }).length, bare = g.render(tpl, { ...f, rules: '', schema, feedback: '' }).length;
      if (full - bare > 4096) throw new Error('the zones-and-rules section adds ' + (full - bare) + ' bytes (at most 4096)');
      console.log('read: ' + a.zones.length + ' zone, ' + a.rules.length + ' rule, room ' + JSON.stringify(a.rules_room) + '; prompt ' + full + ' bytes, ' + (full - bare) + ' of them the zones-and-rules section');
    " "$home_cm6_js" "$home_cm6_ask" 2>&1)" || why="the Foreman refused the ask: $home_cm6_said"
  fi
  verdict home.command-m6.ask_foreman "$why" "$home_cm6_said"
  if [ -n "${home_command_m6_alone:-}" ]; then
    if [ "$fail" = 0 ] && [ "$pass" = "${#home_command_m6_cases[@]}" ] && tr -d '\r' <"$home_cm6_log" | grep -qx 'HOME command-m6 ok'; then
      echo "HOME command-m6 ok"
    else
      echo "HOME command-m6 fail ($pass passed, $fail failed; see $home_cm6_log)"
    fi
  fi
fi
