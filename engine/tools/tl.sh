#!/bin/bash
# Third Life runner wrapper (contracts/RUNNER.md). A thin convenience for humans; the Foreman spawns Godot directly.
#
#   tl.sh lint       --pack=<dir>
#   tl.sh smoke      --pack=<dir> [--seed=1] [--frames=3600]
#   tl.sh invariants --pack=<dir> [--seed=1] [--frames=3600] [--bot-frames=36000]
#   tl.sh bot        --pack=<dir> [--test=tests/x.gd] [--seed=1] [--frames=36000]
#   tl.sh capture    --pack=<dir> --cam=<name> --out=<file.png> [--frame=120] [--res=1920x1080]
#   tl.sh play       --pack=<dir> [--seed=1]   interactive: a window, real keys, Esc to quit (not a verify verb);
#                                              lints first and refuses a pack that fails (items: tools/item.sh)
#   tl.sh selftest   every verb on the good example pack and each bad pack: one PASS/FAIL line per case
#   tl.sh seeds      every verb on the three seed packs (tools/seeds.sh; `seeds sheet` rebuilds the contact sheet)
#   tl.sh import     rebuild the class cache (the runner also does this by itself when scripts changed)
#
# Every verb takes --report=<file.json>; without it the report goes to a temporary file. The JSON report is the last
# line of stdout and the exit code is 0 passed, 1 failed, 2 could not run, 3 watchdog.
# Env: TL_GODOT (Godot console exe), TL_ENGINE_DIR (this engine/ directory), TL_QUIET=1 (print only the report line).
G="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
E="${TL_ENGINE_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
if command -v cygpath >/dev/null 2>&1; then
  E="$(cygpath -m "$E")"
  G="$(cygpath -m "$G")"
fi

# --name=/c/path -> --name=C:/path (res:// and plain values are left alone)
fix_arg() {
  local a="$1"
  case "$a" in
    --pack=*|--report=*|--out=*)
      local k="${a%%=*}" v="${a#*=}"
      case "$v" in
        res://*) ;;
        *) if command -v cygpath >/dev/null 2>&1; then
             case "$v" in /*|[A-Za-z]:*) v="$(cygpath -m "$v")";; *) v="$(cygpath -m "$PWD/$v")";; esac
           fi;;
      esac
      echo "$k=$v";;
    *) echo "$a";;
  esac
}

run_verb() {
  local args=() has_report=0
  for a in "$@"; do
    args+=("$(fix_arg "$a")")
    case "$a" in --report=*) has_report=1;; esac
  done
  if [ $has_report -eq 0 ]; then
    local tmp="${TMPDIR:-${TEMP:-/tmp}}"
    command -v cygpath >/dev/null 2>&1 && tmp="$(cygpath -m "$tmp")"
    args+=("--report=$tmp/tl_report_$$.json")
  fi
  MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' "$G" --headless --path "$E" res://kernel/host/host.tscn -- "${args[@]}"
}

case "$1" in
  ""|help|-h|--help)
    sed -n '2,18p' "$0"; exit 2;;
  play)
    # interactive play: the worker directly, windowed, in real time, with devices on; no report
    shift; pargs=(); pack_arg=""
    for a in "$@"; do pargs+=("$(fix_arg "$a")"); case "$a" in --pack=*) pack_arg="$a";; esac; done
    # N4: the fence is a lint check and nothing else, so play lints first and refuses a pack that fails it
    ptmp="${TMPDIR:-${TEMP:-/tmp}}"; command -v cygpath >/dev/null 2>&1 && ptmp="$(cygpath -m "$ptmp")"
    prep="$ptmp/tl_play_lint_$$.json"
    run_verb lint "$pack_arg" "--report=$prep" >/dev/null 2>&1; lint_code=$?
    if [ $lint_code -ne 0 ]; then
      echo "[tl] play refused: lint did not pass (exit $lint_code). A pack is played only inside the fence."
      grep -o '"kind":"[a-z_]*","file":"[^"]*"\(,"line":[0-9]*\)\?,"message":"[^"]*"' "$prep" 2>/dev/null | head -12 | sed 's/^/[tl]   /'
      echo "[tl] all findings: tl.sh lint $pack_arg"
      rm -f "$prep"; exit $lint_code
    fi
    rm -f "$prep"
    MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' "$G" --position "${TL_WINDOW_POS:-0,1440}" --path "$E" res://kernel/host/host.tscn -- worker --mode=play "${pargs[@]}"
    exit $?;;
  import)
    "$G" --headless --path "$E" --import 2>&1 | grep -i -E "error|fail" | head -30; exit 0;;
  selftest)
    shift; exec bash "$(dirname "$0")/selftest.sh" "$@";;
  seeds)
    shift; exec bash "$(dirname "$0")/seeds.sh" "$@";;
  *)
    # every other word goes to the host, which answers an unknown verb with a not_run report and exit code 2
    if [ -n "$TL_QUIET" ]; then run_verb "$@" 2>/dev/null | tail -n 1; exit "${PIPESTATUS[0]}"; fi
    run_verb "$@"; exit $?;;
esac
