#!/bin/bash
# P9: the executable. Makes dist/ThirdLife/ (ThirdLife.exe, ThirdLife.pck, games/, BUILD.txt, README.txt) from the
# current tree, unattended, and proves the result (docs/EXE.md).
#
#   export.sh [--commit <text> | --commit-file <file>] [--out <dir>]
#       exports the preset "ThirdLife" of engine/export_presets.cfg, copies the games of engine/boot/games.json into
#       games/ as plain folders, writes BUILD.txt and README.txt, puts the build in place of the one before it and
#       prints the full path of the exe. It builds beside the old build and swaps at the end, so a failed export
#       leaves the old build as it was. It refuses to replace a folder it did not make (no BUILD.txt of its own in
#       it) and a build whose exe is running. The commit is text you give (this tool runs no git): --commit <text>,
#       or the first line of --commit-file <file>, or $TL_COMMIT, else "unknown".
#   export.sh check [--out <dir>]
#       1. the scripted tour of the village, headless, 4000 ticks: the editor binary, the built exe, and a copy of
#          the build in a folder with a space in its name outside the repository; PASS when every pack's state hash
#          and tick count are the same in all three (the difference is printed when they are not);
#       2. the exe with no arguments: a window, one picture after 120 frames (dist/ThirdLife-check/village.png), a
#          clean end on request, exit code 0;
#       3. the keys, pressed by a script through the engine's own input state: W walks the visitor, Esc ends the
#          process by itself (these two decide); E enters the kit court and Q leaves it (shown, not counted);
#          P11: the turn south is 600 pixels of mouse (A and D step aside since P11)
#       4. no process of the build is left.
#   export.sh probe [--out <dir>]
#       what works inside the build and what needs files on disk, measured in the editor binary and in the exe
#       (the table of docs/EXE.md).
#
# Exit code: 0 done / PASS, 1 the export or the check failed (the reason is the last lines), 2 could not run (no
# Godot, no export templates, no node, bad arguments), 3 refused to replace a folder it did not make.
# Env: TL_GODOT (Godot console exe), TL_ENGINE_DIR, TL_WINDOW_POS (default 0,1440: where the check's windows open),
#      TL_EXPORT_TIMEOUT (seconds for one Godot run, default 600).

MARK="Third Life build (made by engine/tools/export.sh)"
G="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
E="${TL_ENGINE_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
REPO="$(cd "$E/.." && pwd)"
win() { if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else echo "$1"; fi; }
E="$(win "$E")"; G="$(win "$G")"; REPO="$(win "$REPO")"
LIMIT="${TL_EXPORT_TIMEOUT:-600}"
POS="${TL_WINDOW_POS:-0,1440}"

die() { echo "export.sh: $2" >&2; exit "$1"; }
limited() {   # limited <seconds> <command...>: the command, ended by this tool when it runs longer (exit code 124)
  local s="$1"; shift
  if command -v timeout >/dev/null 2>&1; then MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' timeout -k 10 "$s" "$@"
  else MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' "$@"; fi
}
running_from() {   # pids of processes whose executable is under the folder $1 (this build's own exe, nobody else's)
  local d; d="$(cygpath -w "$1" 2>/dev/null || echo "$1")"
  powershell -NoProfile -NonInteractive -Command "\$d='$d'; Get-CimInstance Win32_Process -Filter \"Name='ThirdLife.exe'\" | Where-Object { \$_.ExecutablePath -and \$_.ExecutablePath.StartsWith(\$d, [System.StringComparison]::OrdinalIgnoreCase) } | ForEach-Object { \$_.ProcessId }" 2>/dev/null | tr -d '\r' | tr '\n' ' '
}
is_ours() { [ -f "$1/BUILD.txt" ] && [ "$(head -1 "$1/BUILD.txt" | tr -d '\r')" = "$MARK" ]; }
need_tools() {
  [ -f "$G" ] || die 2 "the Godot console executable was not found: $G (set TL_GODOT)"
  command -v node >/dev/null 2>&1 || die 2 "node was not found on PATH (it reads the games list and compares the hashes)"
  [ -f "$E/export_presets.cfg" ] || die 2 "engine/export_presets.cfg is missing"
  [ -f "$E/boot/boot.tscn" ] || die 2 "engine/boot/boot.tscn is missing"
}
refresh_classes() {   # the class cache (TL* by name) must know every script of the tree as it is now
  limited "$LIMIT" "$G" --headless --path "$E" --import >"$1" 2>&1
  [ -f "$E/.godot/global_script_class_cache.cfg" ] || { tail -20 "$1" >&2; die 1 "godot --import did not write the class cache (.godot/global_script_class_cache.cfg); its output is in $1"; }
}

cmd="build"; commit="${TL_COMMIT:-unknown}"; OUT=""
while [ $# -gt 0 ]; do
  case "$1" in
    check|probe|build) cmd="$1";;
    --commit) [ $# -ge 2 ] || die 2 "--commit wants a text"; commit="$2"; shift;;
    --commit=*) commit="${1#*=}";;
    --commit-file) [ $# -ge 2 ] && [ -f "$2" ] || die 2 "--commit-file wants a file that exists"; commit="$(head -1 "$2" | tr -d '\r')"; shift;;
    --out) [ $# -ge 2 ] || die 2 "--out wants a folder"; case "$2" in /*|[A-Za-z]:*) OUT="$(win "$2")";; *) OUT="$(win "$PWD/$2")";; esac; shift;;
    -h|--help) sed -n '2,30p' "$0"; exit 0;;
    *) sed -n '2,30p' "$0"; die 2 "unknown argument '$1'";;
  esac
  shift
done
[ -z "$commit" ] && commit="unknown"
[ -z "$OUT" ] && OUT="$REPO/dist/ThirdLife"
DIST="$(dirname "$OUT")"
need_tools

# ------------------------------------------------------------------------------------------------------- build
if [ "$cmd" = build ]; then
  t0=$(date +%s)
  version="$("$G" --version 2>/dev/null | tr -d '\r' | head -1)"
  [ -n "$version" ] || die 2 "$G --version printed nothing"
  tdir="$(win "${APPDATA:-$HOME/AppData/Roaming}")/Godot/export_templates/$(echo "$version" | cut -d. -f1-4 | sed -E 's/\.(official|custom_build).*//')"
  [ -f "$tdir/windows_release_x86_64.exe" ] || die 2 "the export template is not installed: $tdir/windows_release_x86_64.exe (Godot $version)"
  if [ -e "$OUT" ] && [ -n "$(ls -A "$OUT" 2>/dev/null)" ] && ! is_ours "$OUT"; then
    die 3 "refused: $OUT exists and was not made by this tool (its BUILD.txt does not begin with '$MARK'). Move it away or name another folder with --out."
  fi
  pids="$(running_from "$OUT")"
  [ -n "${pids// /}" ] && die 1 "ThirdLife.exe of $OUT is running (process $pids): close it, then export again. Nothing was changed."
  mkdir -p "$DIST" || die 1 "cannot make $DIST"
  STAGE="$DIST/.ThirdLife.new.$$"; LOG="$DIST/ThirdLife-export.log"
  rm -rf "$STAGE"; mkdir -p "$STAGE/games" || die 1 "cannot make $STAGE"
  trap 'rm -rf "$STAGE"' EXIT
  echo "export.sh: Godot $version, commit '$commit'"
  refresh_classes "$LOG"
  limited "$LIMIT" "$G" --headless --path "$E" --export-release ThirdLife "$STAGE/ThirdLife.exe" >>"$LOG" 2>&1; code=$?
  reason=""
  [ $code -eq 124 ] && reason="the export did not end within $LIMIT s and was stopped"
  [ -z "$reason" ] && [ $code -ne 0 ] && reason="godot --export-release ended with exit code $code"
  [ -z "$reason" ] && [ ! -s "$STAGE/ThirdLife.exe" ] && reason="the export wrote no ThirdLife.exe"
  [ -z "$reason" ] && [ ! -s "$STAGE/ThirdLife.pck" ] && reason="the export wrote no ThirdLife.pck"
  [ -z "$reason" ] && grep -qE "SCRIPT ERROR|Parse Error|Failed to load script" "$LOG" && reason="a script of the engine does not compile"
  if [ -n "$reason" ]; then
    echo "export.sh: FAILED: $reason. The lines of the export that say why:" >&2
    grep -nE "ERROR|Parse Error|Failed|Cannot|not found|   at: " "$LOG" | head -40 >&2
    die 1 "the build was not made; the old build (if any) is untouched; the whole output is in $LOG"
  fi
  grep -E "^(ERROR|WARNING)" "$LOG" | head -10 | sed 's/^/export.sh: the export printed: /'
  # the games: plain folders beside the exe
  MAIN=""; case "$REPO" in */.claude/worktrees/*) MAIN="${REPO%%/.claude/worktrees/*}";; esac
  node - "$E/boot/games.json" "$E/boot/village.json" "$REPO" "$MAIN" "$STAGE" <<'NODE' || die 1 "the games could not be copied (the reason is above); the old build (if any) is untouched"
const fs = require("fs"), path = require("path");
const [gamesFile, walkFile, repo, main, stage] = process.argv.slice(2);
const games = JSON.parse(fs.readFileSync(gamesFile, "utf8")).games;
const walk = JSON.parse(fs.readFileSync(walkFile, "utf8"));
const lines = [], missing = [];
for (const g of games) {
  let src = [path.join(repo, g.from), main ? path.join(main, g.from) : ""].find(p => p && fs.existsSync(path.join(p, "pack.json")));
  const plots = walk.plots.filter(p => p.pack === g.name).map(p => p.id);
  if (!src) {
    if (!g.optional) { console.error(`export.sh: the game '${g.name}' was not found at ${g.from} (no pack.json there)`); process.exit(1); }
    console.error(`export.sh: WARNING: the optional game '${g.name}' was not found at ${g.from}; the build is made without it (plot ${plots.join(", ") || "none"} is left out)`);
    missing.push(`  ${g.name}: not found at ${g.from} when the build was made (plot ${plots.join(", ") || "none"} is left out)`);
    continue;
  }
  fs.cpSync(src, path.join(stage, "games", g.name), { recursive: true, filter: s => !/\.(uid|import)$/.test(s) });
  const m = JSON.parse(fs.readFileSync(path.join(src, "pack.json"), "utf8"));
  lines.push(`  ${g.name}: ${m.id} ${m.version}, "${m.title || ""}", plot ${plots.join(", ") || "none (not in the village)"}, from ${g.from}`);
}
for (const p of walk.plots) if (!games.some(g => g.name === p.pack)) { console.error(`export.sh: plot '${p.id}' of boot/village.json names the game '${p.pack}', which boot/games.json does not list`); process.exit(1); }
fs.writeFileSync(path.join(stage, ".games.txt"), lines.join("\n") + "\n" + (missing.length ? "not in this build:\n" + missing.join("\n") + "\n" : ""));
NODE
  # P14: the caches of these games (rims, far pictures, rig recipes; keyed by each game's content), computed by the
  # new exe itself: its window runs the village's scripted tour once with TL_CACHE_DIR=<build>/cache. The exe copies
  # what a user's cache lacks from there on every start (boot.gd), so the first start on a machine finds them.
  echo "export.sh: filling the build's cache (the scripted village in a window, about 80 s)"
  rm -rf "$STAGE/cache"
  TL_CACHE_DIR="$STAGE/cache" TL_EXE_WARM=1 TL_EXE_WINDOW_POS="$POS" limited 300 "$STAGE/ThirdLife.exe" >"$DIST/ThirdLife-warm.log" 2>&1; wcode=$?
  rm -f "$STAGE/ThirdLife-last-run.log"
  cache_files="$(find "$STAGE/cache" -type f 2>/dev/null | wc -l)"
  [ $wcode -ne 0 ] && echo "export.sh: WARNING: the cache run ended with exit code $wcode ($DIST/ThirdLife-warm.log); the build ships $cache_files cache files"
  api="$(grep -oE 'KERNEL_API: String = "[^"]*"' "$E/kernel/runner/manifest.gd" | head -1 | cut -d'"' -f2)"
  size_kb="$(du -sk "$STAGE" | cut -f1)"
  {
    echo "$MARK"
    echo "commit: $commit"
    echo "built: $(date '+%Y-%m-%d %H:%M:%S %z') in $(( $(date +%s) - t0 )) s"
    echo "engine: Godot $version, kernelApi ${api:-unknown}, release export template, Windows x86_64"
    echo "what it opens: res://boot/boot.tscn (engine/boot/boot.gd), the walk res://boot/village.json"
    echo "size: $(( size_kb / 1024 )) MB (ThirdLife.exe $(( $(stat -c %s "$STAGE/ThirdLife.exe") / 1048576 )) MB, ThirdLife.pck $(( $(stat -c %s "$STAGE/ThirdLife.pck") / 1024 )) KB, games $(du -sk "$STAGE/games" | cut -f1) KB)"
    echo "cache: $cache_files files, $(du -sk "$STAGE/cache" 2>/dev/null | cut -f1) KB (rims, far pictures, rig recipes of these games; copied to the user's cache on start)"
    echo "games (folder in games/: id version, title, plot, where it came from):"
    cat "$STAGE/.games.txt"
  } > "$STAGE/BUILD.txt"
  rm -f "$STAGE/.games.txt"
  cat > "$STAGE/README.txt" <<'TXT'
Third Life

Start: double click ThirdLife.exe. Keep ThirdLife.pck and the folder "games" beside it.

Keys while you walk:   W A S D  walk      Shift  run      E  enter the game whose plot you stand in      Esc  quit
Keys inside a game:    Q or Esc  leave the game (the game's own keys are its own)

The games are the folders in "games". BUILD.txt says what this build was made from.
ThirdLife-last-run.log (written beside the exe on every start) holds what the last run printed and why it stopped.
TXT
  if [ -e "$OUT" ]; then
    rm -rf "$OUT" 2>/dev/null
    [ -e "$OUT" ] && die 1 "the old build $OUT could not be removed (a file in it is open?). It may be incomplete now; close what holds it and export again."
  fi
  # P14: the cache run has just ended: Windows may hold the folder for a moment after the exe exits
  for try in 1 2 3 4 5 6 7 8 9 10; do mv "$STAGE" "$OUT" 2>/dev/null && break; sleep 2; done
  [ -e "$OUT" ] || die 1 "could not move the new build to $OUT"
  trap - EXIT
  sed -n '2,40p' "$OUT/BUILD.txt"
  echo "export.sh: built in $(( $(date +%s) - t0 )) s: $(cygpath -w "$OUT/ThirdLife.exe" 2>/dev/null || echo "$OUT/ThirdLife.exe")"
  exit 0
fi

# ------------------------------------------------------------------------------------------- check and probe
[ -s "$OUT/ThirdLife.exe" ] && is_ours "$OUT" || die 2 "there is no build of this tool at $OUT (run export.sh first)"
W="$DIST/ThirdLife-check"
if [ -e "$W" ] && [ ! -f "$W/.made-by-export-sh" ]; then die 3 "refused: $W exists and was not made by this tool"; fi
rm -rf "$W"; mkdir -p "$W" && : > "$W/.made-by-export-sh" || die 1 "cannot make $W"
refresh_classes "$W/import.log"

if [ "$cmd" = probe ]; then
  limited 180 "$G" --headless --path "$E" res://boot/boot.tscn -- probe "--out=$W/probe_editor.json" "--games=$OUT/games" >"$W/probe_editor.log" 2>&1 || die 1 "the probe in the editor binary failed; see $W/probe_editor.log"
  limited 180 "$OUT/ThirdLife.exe" --headless --log-file "$W/probe_exe.log" -- probe "--out=$W/probe_exe.json" >/dev/null 2>&1 || die 1 "the probe in the exe failed; see $W/probe_exe.log"
  node -e '
    const fs = require("fs"), rd = f => JSON.parse(fs.readFileSync(f, "utf8")).rows;
    const a = rd(process.argv[1]), b = new Map(rd(process.argv[2]).map(r => [r.id, r]));
    console.log("| what | editor binary | exported exe |\n|---|---|---|");
    for (const r of a) { const o = b.get(r.id); const f = x => x === undefined ? "-" : JSON.stringify(x.value) + (x.note ? " (" + x.note + ")" : "");
      console.log(`| ${r.id} | ${f(r)} | ${f(o)} |`); }' "$W/probe_editor.json" "$W/probe_exe.json"
  echo "export.sh: the answers are in $W/probe_editor.json and $W/probe_exe.json"
  exit 0
fi

fail=0
note() { echo "export.sh check: $1"; }
# 1. the scripted tour, three times
note "1. the scripted tour of the village, headless (editor binary, the exe, the exe copied to a folder with a space in its name)"
limited 600 "$G" --headless --fixed-fps 60 --path "$E" res://boot/boot.tscn -- check "--out=$W/editor.jsonl" "--games=$OUT/games" >"$W/editor.log" 2>&1; ce=$?
limited 600 "$OUT/ThirdLife.exe" --headless --fixed-fps 60 --log-file "$W/exe.log" -- check "--out=$W/exe.jsonl" >/dev/null 2>&1; cx=$?
COPY="$(win "${TEMP:-/tmp}")/tl exe copy $$"
mkdir -p "$COPY" && cp -R "$OUT" "$COPY/Third Life" || { note "could not copy the build to $COPY"; fail=1; }
cm=1
if [ -s "$COPY/Third Life/ThirdLife.exe" ]; then
  limited 600 "$COPY/Third Life/ThirdLife.exe" --headless --fixed-fps 60 --log-file "$W/moved.log" -- check "--out=$W/moved.jsonl" >/dev/null 2>&1; cm=$?
fi
left="$(running_from "$COPY")"
rm -rf "$COPY" 2>/dev/null
[ $ce -ne 0 ] && { note "the editor run ended with exit code $ce (see $W/editor.log)"; fail=1; }
[ $cx -ne 0 ] && { note "the exe's run ended with exit code $cx (see $W/exe.log)"; fail=1; }
[ $cm -ne 0 ] && { note "the copied exe's run ended with exit code $cm (see $W/moved.log)"; fail=1; }
node -e '
  const fs = require("fs");
  const rd = f => { try { return fs.readFileSync(f, "utf8").split("\n").filter(l => l.startsWith("{")).map(l => JSON.parse(l)); } catch (e) { return []; } };
  const runs = ["editor", "exe", "moved"].map(n => rd(process.argv[1] + "/" + n + ".jsonl"));
  const packs = r => r.filter(l => l.kind === "pack"), world = r => r.find(l => l.kind === "world" && l.world_ticks !== undefined) || {};
  let bad = 0;
  if (!packs(runs[0]).length) { console.log("the editor run printed no pack line"); bad = 1; }
  console.log("plot | game | own ticks | tiers seen | hash, editor binary | hash, exe | hash, exe copied elsewhere | verdict");
  for (const p of packs(runs[0])) {
    const o = runs.slice(1).map(r => packs(r).find(q => q.plot === p.plot));
    const same = !!p.state_hash && o.every(q => q && q.state_hash === p.state_hash && q.frames === p.frames) && p.script_errors === 0 && p.engine_errors === 0 && o.every(q => q.script_errors === 0 && q.engine_errors === 0);
    if (!same) bad = 1;
    const h = q => q ? (q.state_hash || "NO HASH").slice(0, 16) + (q.frames !== p.frames ? " (" + q.frames + " ticks)" : "") + (q.script_errors || q.engine_errors ? " (" + q.script_errors + " script errors, " + q.engine_errors + " engine errors)" : "") : "NOT THERE";
    console.log(`${p.plot} | ${p.pack} | ${p.frames} | ${(p.tiers_seen || []).join(",")} | ${h(p)} | ${h(o[0])} | ${h(o[1])} | ${same ? "same" : "DIFFERENT"}`);
  }
  for (const [i, n] of ["exe", "exe copied elsewhere"].entries()) if (packs(runs[i + 1]).length !== packs(runs[0]).length) { console.log(`the ${n} ran ${packs(runs[i + 1]).length} games, the editor binary ${packs(runs[0]).length}`); bad = 1; }
  const names = ["editor binary", "exe", "exe copied elsewhere"];
  runs.forEach((r, i) => { const w = world(r); console.log(`${names[i]}: ${w.world_ticks} world ticks, ${w.packs} games, tick p50 ${w.iter_ms_p50} ms, loaded in ${w.load_ms} ms, ${w.script_errors} script errors, ${w.engine_errors} engine errors, on stage: ${r.filter(l => l.kind === "event" && l.e === "tier" && l.to === "stage").map(l => l.plot + "@" + l.t).join(" ")}${(w.errors || []).length ? ", errors: " + w.errors.join("; ") : ""}`); });
  const b = rd(process.argv[1] + "/exe.jsonl.boot.json")[0] || {};
  if ((b.left_out || []).length) console.log("left out of the village: " + b.left_out.map(d => d.id + " (" + d.why + ")").join("; "));
  process.exit(bad);' "$W" || { note "the hashes are NOT the same in the three runs (table above)"; fail=1; }

# 2. no arguments: a window, one picture, a clean end
note "2. the exe with no arguments: one picture after 120 frames, then a clean end on request"
TL_EXE_CAPTURE="$W/village.png" TL_EXE_QUIT_AT=240 TL_EXE_WINDOW_POS="$POS" limited 180 "$OUT/ThirdLife.exe" >"$W/window.log" 2>&1; cw=$?
if [ $cw -eq 0 ] && [ -s "$W/village.png" ] && grep -q '"kind":"capture".*"saved":true' "$W/window.log"; then
  note "   picture: $(cygpath -w "$W/village.png" 2>/dev/null || echo "$W/village.png") ($(stat -c %s "$W/village.png") bytes; $(grep -o '"driver":"[^"]*","adapter":"[^"]*"' "$W/window.log" | head -1 | tr -d '"')), exit code 0"
else
  note "   FAILED: exit code $cw, picture $( [ -s "$W/village.png" ] && echo written || echo missing ) (see $W/window.log)"; fail=1
  grep -E "^\[boot\]|^\[view\]|ERROR" "$W/window.log" | head -8
fi

# 3. the keys (pressed by boot.gd through the engine's input state; no person): Shift+W along the road, 600 pixels of
#    mouse turn him south (P11), W into the kit court (P14: the compact village), E, Q, Esc. W and Esc decide the check; E and Q are shown and not
#    counted (the route depends on where the landscape puts the court's gate).
note "3. the keys: Shift+W east along the road, the mouse turns him south, W into the kit court, E at frame 720, Q at 1000, Esc at 1100 (nothing else ends this run)"
TL_EXE_KEYS="30:+Shift;30:+W;263:-Shift;263:-W;270:~600,0;280:+W;700:-W;720:+E;722:-E;1000:+Q;1002:-Q;1100:+Escape;1102:-Escape" TL_EXE_TRACE="$W/keys_trace.jsonl" TL_EXE_CAPTURE="$W/on_stage.png" TL_EXE_CAPTURE_AT=900 TL_EXE_WINDOW_POS="$POS" limited 240 "$OUT/ThirdLife.exe" >"$W/keys.log" 2>&1; ck=$?
node -e '
  const fs = require("fs"); let rows = [];
  try { rows = fs.readFileSync(process.argv[1], "utf8").split("\n").filter(l => l.startsWith("{")).map(l => JSON.parse(l)); } catch (e) {}
  const a = rows.find(r => r.frame === 30), b = rows.find(r => r.frame === 240), last = rows[rows.length - 1];
  if (!a || !b) { console.log("   no trace of the visitor (frames 30 and 240 are missing)"); process.exit(1); }
  const d = Math.hypot(b.feet[0] - a.feet[0], b.feet[2] - a.feet[2]);
  console.log(`   W: the visitor ran ${d.toFixed(2)} m in 210 frames of Shift+W (9 m/s would be 31.5 m), from [${a.feet}] to [${b.feet}]`);
  const on = rows.filter(r => r.stage >= 0), end = rows.find(r => r.frame === 1080);
  console.log(on.length ? `   E: a game was on stage from frame ${on[0].frame} to ${on[on.length - 1].frame} (plot index ${on[0].stage}; he stood at [${on[0].feet}]); Q: ${end && end.stage < 0 ? "he was walking again at frame 1080" : "NOT SHOWN, a game was still on stage at frame 1080"}`
    : `   E and Q: NOT SHOWN (no game came on stage; he stood at [${(rows.find(r => r.frame === 720) || last).feet}] when E was pressed). Not counted.`);
  process.exit(d > 5 && last.frame <= 1110 ? 0 : 1);' "$W/keys_trace.jsonl" || { note "   FAILED: W did not walk the visitor, or the run went on after Esc"; fail=1; }
if [ $ck -eq 0 ] && grep -q "^\[visit\] the visitor quit at tick 110[0-9]" "$W/keys.log"; then note "   Esc ended the process by itself at $(grep -o "tick 110[0-9]" "$W/keys.log" | head -1), exit code 0"
else note "   FAILED: Esc did not end the process cleanly (exit code $ck; see $W/keys.log)"; fail=1; fi
[ -s "$W/on_stage.png" ] && note "   picture at frame 900: $(cygpath -w "$W/on_stage.png" 2>/dev/null || echo "$W/on_stage.png")"

# 4. nothing left behind
left="$left$(running_from "$OUT")"
if [ -n "${left// /}" ]; then note "4. FAILED: a process of the build is still running: $left"; fail=1; else note "4. no process of the build is left"; fi
if [ $fail -eq 0 ]; then echo "PASS export.check: the exe runs the same games to the same hashes as the editor binary, shows the village, obeys W and Esc, and leaves nothing behind ($W)"
else echo "FAIL export.check (the files of the runs are in $W)"; fi
exit $fail
