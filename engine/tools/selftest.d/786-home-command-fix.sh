# Round 2 lane C (27 Nov 2026): "fix it" (kernel/world/build/COMMAND.md "Fix it"). A headless case
# (kernel/world/build/command_fix_case.gd -- fix) on a hand-laid stone platform, with a DRY Foreman door and the answer
# files a FAKE Foreman would write: a floating-block answer offers R in its note and hint (a clean one does not, and R
# there sends nothing); R sends ONE fix ask with the answer's ops and the space check's findings, the ghost stays while
# it waits, the corrected answer replaces it with no warning and only Enter keeps it; the fix is a call (the day's
# count, the calls log), and `tl ledger --home` reads both calls. No model is called. Frames, not wall clock. Runs on
# its own: `bash engine/tools/selftest.d/786-home-command-fix.sh` prints `HOME command-fix ok` when it passes.
home_command_fix_cases=(home.command-fix.offer home.command-fix.flow home.command-fix.calls home.command-fix.ledger)
if ! declare -F verdict >/dev/null; then
  HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  OUT="${TL_SELFTEST_DIR:-$(mktemp -d)}"
  pass=0; fail=0; FILTER=""
  verdict() { if [ -z "$2" ]; then echo "PASS $1${3:+  ($3)}"; pass=$((pass+1)); else echo "FAIL $1: $2"; fail=$((fail+1)); fi; }
  home_command_fix_alone=1
fi
if [ -z "$FILTER" ] || [[ "${home_command_fix_cases[*]}" == *"$FILTER"* ]]; then
  home_cfx_engine="$(cd "$HERE/.." && pwd)"
  home_cfx_repo="$(cd "$HERE/../.." && pwd)"
  home_cfx_calls="$OUT/home-command-fix-calls"
  command -v cygpath >/dev/null 2>&1 && home_cfx_engine="$(cygpath -am "$home_cfx_engine")" && home_cfx_repo="$(cygpath -am "$home_cfx_repo")" && home_cfx_calls="$(cygpath -am "$home_cfx_calls")"
  home_cfx_log="$OUT/home-command-fix.log"
  rm -rf "$home_cfx_calls"
  home_cfx_rc=0
  TL_HOME= TL_STYLE=crisp TL_COMMAND_DEVICES= MSYS_NO_PATHCONV=1 "${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}" \
    --headless --fixed-fps 60 --quit-after 3000 --path "$home_cfx_engine" \
    --script res://kernel/world/build/command_fix_case.gd -- fix "$home_cfx_calls" >"$home_cfx_log" 2>&1 || home_cfx_rc=$?
  for home_cfx_case in "${home_command_fix_cases[@]}"; do
    [ "$home_cfx_case" = home.command-fix.ledger ] && continue
    home_cfx_name="${home_cfx_case#home.}"
    home_cfx_line="$(tr -d '\r' <"$home_cfx_log" | grep -F "HOME $home_cfx_name " | head -1)"
    why=""
    if [ "$home_cfx_rc" != 0 ] || ! grep -q '^HOME DONE' "$home_cfx_log"; then
      why="stopped run (Godot exit $home_cfx_rc), ${home_cfx_line:-missing $home_cfx_case}; see $home_cfx_log"
    elif grep -qE '^SCRIPT ERROR|^ERROR:' "$home_cfx_log"; then
      why="$(grep -m1 -E '^SCRIPT ERROR|^ERROR:' "$home_cfx_log")"
    elif [[ "$home_cfx_line" != "HOME $home_cfx_name ok "* ]]; then
      why="${home_cfx_line:-missing HOME $home_cfx_name verdict}"
    fi
    verdict "$home_cfx_case" "$why" "${home_cfx_line#HOME "$home_cfx_name" ok }"
  done
  why=""; home_cfx_said=""
  if ! command -v node >/dev/null 2>&1; then
    why="could not run: node is not on PATH"
  elif [ ! -f "$home_cfx_calls/llm_calls.jsonl" ]; then
    why="no calls log was copied (see $home_cfx_log)"
  else
    home_cfx_said="$(node "$home_cfx_repo/devx/bin/tl.mjs" ledger --home "$home_cfx_calls" --json 2>&1 | grep '"calls":{"calls"' | node -e '
      let s = ""; process.stdin.on("data", (d) => (s += d)).on("end", () => {
        const j = JSON.parse(s), c = j.calls?.calls ?? [], fix = c.filter((x) => String(x.sentence).startsWith("fix: "));
        if (fix.length !== 1 || fix[0].accepted !== true) throw new Error("the ledger has no kept fix call: " + JSON.stringify(c));
        if (!c.some((x) => x.accepted === false && "fix: " + x.sentence === fix[0].sentence)) throw new Error("the replaced call is not reverted: " + JSON.stringify(c));
        const t = j.calls.totals; console.log("ledger: " + t.calls + " calls, " + t.kept + " kept, " + t.reverted + " reverted; the fix: " + JSON.stringify(fix[0].sentence));
      });' 2>&1)" || why="tl ledger did not read the calls: $home_cfx_said"
  fi
  verdict home.command-fix.ledger "$why" "$home_cfx_said"
  if [ -n "${home_command_fix_alone:-}" ]; then
    if [ "$fail" = 0 ] && [ "$pass" = "${#home_command_fix_cases[@]}" ] && tr -d '\r' <"$home_cfx_log" | grep -qx 'HOME command-fix ok'; then
      echo "HOME command-fix ok"
    else
      echo "HOME command-fix fail ($pass passed, $fail failed; see $home_cfx_log)"
    fi
  fi
fi
