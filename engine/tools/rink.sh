#!/usr/bin/env bash
# Third Life rink core (engine/cores/rink): build, trace and prove against thirdjam's Unreal build.
#
#   engine/tools/rink.sh build [tree] [target]       godot-cpp (fetched into .tl/godot-cpp at a pinned commit) + the extension
#                                                    + the CLI; tree = thirdjam (HEAD, default) | thirdjam-t5 | all (HEAD debug + release,
#                                                    t5 debug); target = template_debug (default) | template_release
#   engine/tools/rink.sh trace <tree> <args...>      thirdjam's tournament commandlet run natively (rinkcli), its LogJamAI lines on stdout
#   engine/tools/rink.sh gdtrace <tree> <args...>    the same commandlet run inside Godot through the RinkCore extension (headless;
#                                                    thirdjam = the engine project, thirdjam-t5 = a scratch project in .tl/rink-t5-proj)
#   engine/tools/rink.sh ue <name> <args...>         the Unreal build's commandlet (one process; .tl/ue/<name>.txt = its LogJamAI lines)
#   engine/tools/rink.sh compare <a.txt> <b.txt>     PASS when equal line for line; else the first differing line (frame) and the count
#
# Args are thirdjam's: -cartridge=hockey.regular -seeds=1-10 -mode=playerbot -difficulty=pro [-player=regular -playersprint] -trace=1
# Env: TL_GODOT (Godot console exe; else .tl/local.json via tl doctor), TL_UE (UnrealEditor-Cmd.exe), TL_THIRDJAM_RUN (the runnable
# Unreal project dir), TL_THIRDJAM_CONTENT (Content dir holding Cartridges/ for the native runs).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
NATIVE="$ROOT/engine/cores/rink/native"
BIN="$ROOT/engine/cores/rink/bin"
TL="$ROOT/.tl"
GODOT_CPP_COMMIT="7fd5c4bc3efda6487fd6e6486c50016faa622f92"   # godot-cpp master, 19 Nov 2026 (api 4.3..4.8)
UE="${TL_UE:-C:/Program Files/Epic Games/UE_5.9/Engine/Binaries/Win64/UnrealEditor-Cmd.exe}"
TJ_RUN="${TL_THIRDJAM_RUN:-C:/Users/kazda/kiro/third-life/.claude/worktrees/n23-teardown/.tl/tj-run/Game}"

godot_exe() {
  if [ -n "${TL_GODOT:-}" ]; then echo "$TL_GODOT"; return; fi
  { node "$ROOT/devx/bin/tl.mjs" doctor 2>/dev/null || true; } | sed -n 's/^PASS  godot .*ms  //p' | head -1 || true
}

content_for() {   # the cartridges the tree was written against
  if [ -n "${TL_THIRDJAM_CONTENT:-}" ]; then echo "$TL_THIRDJAM_CONTENT"; return; fi
  if [ "$1" = "thirdjam-t5" ]; then echo "$NATIVE/content-t5"; else echo "$NATIVE/content"; fi
}

cmd="${1:-}"; shift || true
case "$cmd" in
  build)
    tree="${1:-thirdjam}"; target="${2:-template_debug}"
    if [ "$tree" = all ]; then
      "$0" build thirdjam template_debug && "$0" build thirdjam template_release && "$0" build thirdjam-t5 template_debug || exit $?
      # round 5: the thirdlife core (thirdjam + native/patches-thirdlife, lane K8) when its patches are there
      if ls "${TL_RINK_PATCHES:-$NATIVE/patches-thirdlife}"/*.patch >/dev/null 2>&1; then
        "$0" build thirdlife template_debug && "$0" build thirdlife template_release || exit $?
      else
        echo "NOT BUILT  rink build thirdlife: no patches in native/patches-thirdlife (the variant waits for lane K8)"
      fi
      exit 0
    fi
    mkdir -p "$TL"
    if [ ! -d "$TL/godot-cpp/.git" ]; then
      git clone --quiet https://github.com/godotengine/godot-cpp "$TL/godot-cpp" || { echo "NOT RUN  rink build: godot-cpp could not be fetched"; exit 2; }
    fi
    if [ "$(git -C "$TL/godot-cpp" rev-parse HEAD)" != "$GODOT_CPP_COMMIT" ]; then
      git -C "$TL/godot-cpp" fetch --quiet origin "$GODOT_CPP_COMMIT" || git -C "$TL/godot-cpp" fetch --quiet --unshallow origin || true
      git -C "$TL/godot-cpp" checkout --quiet "$GODOT_CPP_COMMIT" || { echo "NOT RUN  rink build: godot-cpp $GODOT_CPP_COMMIT not available"; exit 2; }
    fi
    G="$(godot_exe)"
    [ -n "$G" ] || { echo "NOT RUN  rink build: no Godot console exe (tl doctor)"; exit 2; }
    API="$TL/rink-api/extension_api.json"
    if [ ! -f "$API" ]; then mkdir -p "$TL/rink-api"; (cd "$TL/rink-api" && "$G" --headless --dump-extension-api >/dev/null 2>&1); fi
    (cd "$NATIVE" && scons -j"$(nproc)" platform=windows target="$target" custom_api_file="$(cygpath -m "$API" 2>/dev/null || echo "$API")" tree="$tree" cli=yes ${TL_RINK_PATCHES:+patches="$(cygpath -m "$TL_RINK_PATCHES" 2>/dev/null || echo "$TL_RINK_PATCHES")"})       || { echo "FAIL  rink build $tree $target"; exit 1; }
    # Godot 4.7.2 segfaults at exit when a filesystem scan discovers a GDExtension for the first time (any extension, a hello
    # world too); listing it in .godot/extension_list.cfg before the first import loads it at startup instead.
    if [ "$tree" = thirdjam ]; then
      mkdir -p "$ROOT/engine/.godot"
      grep -qx "res://cores/rink/rink_core.gdextension" "$ROOT/engine/.godot/extension_list.cfg" 2>/dev/null         || echo "res://cores/rink/rink_core.gdextension" >> "$ROOT/engine/.godot/extension_list.cfg"
    fi
    # round 5: the thirdlife core's .gdextension is written beside its library (never before it: a .gdextension without its library
    # errors on every engine start); the kernel opens RinkCoreThirdlife for a cartridge with a rules sidecar (TLCores.open, 1.29).
    if [ "$tree" = thirdlife ]; then
      printf '[configuration]
entry_symbol = "rink_core_thirdlife_init"
compatibility_minimum = "4.7"

[libraries]
windows.debug.x86_64 = "res://cores/rink/bin/rink_core_thirdlife.windows.template_debug.x86_64.dll"
windows.release.x86_64 = "res://cores/rink/bin/rink_core_thirdlife.windows.template_release.x86_64.dll"
' > "$ROOT/engine/cores/rink/rink_core_thirdlife.gdextension"
      mkdir -p "$ROOT/engine/.godot"
      grep -qx "res://cores/rink/rink_core_thirdlife.gdextension" "$ROOT/engine/.godot/extension_list.cfg" 2>/dev/null         || echo "res://cores/rink/rink_core_thirdlife.gdextension" >> "$ROOT/engine/.godot/extension_list.cfg"
    fi
    echo "PASS  rink build $tree $target"
    ;;
  tests)   # round 5: thirdjam's own tests (Jam.*, Bar.*) and our re-typed JamGame button rules (TL.Controls.*) natively; args = name filters
    G="$(godot_exe)"; API="$TL/rink-api/extension_api.json"
    [ -f "$API" ] || { echo "NOT RUN  rink tests: run bash engine/tools/rink.sh build first (no extension api dump)"; exit 2; }
    (cd "$NATIVE" && scons -j"$(nproc)" platform=windows target=template_debug custom_api_file="$(cygpath -m "$API" 2>/dev/null || echo "$API")" tree=thirdjam tests=yes skip_tests=VisualSwapTests.cpp) >"$TL/rink-tests-build.log" 2>&1 || { echo "FAIL  rink tests: the build failed ($TL/rink-tests-build.log)"; exit 1; }
    out="$("$BIN/rinktest-thirdjam.exe" "$(cygpath -m "$NATIVE/content" 2>/dev/null || echo "$NATIVE/content")" "$@" 2>&1 | tr -d '\r' || true)"
    echo "$out" | grep '^FAIL' || true
    last="$(echo "$out" | grep '^RINKTEST' | tail -1 || true)"
    p="$(echo "$last" | sed -n 's/.*passed=\([0-9]*\).*/\1/p')"; t="$(echo "$last" | sed -n 's/.*total=\([0-9]*\).*/\1/p')"
    if [ -n "$t" ] && [ "$t" -gt 0 ] && [ "$p" = "$t" ]; then echo "PASS  rink tests: $p of $t"; exit 0; fi
    echo "FAIL  rink tests: ${last:-no RINKTEST line (the run stopped)}"; exit 1
    ;;
  trace)
    tree="${1:-thirdjam}"; shift || true
    "$BIN/rinkcli-$tree.exe" "$(content_for "$tree")" "$@" | grep "LogJamAI: Display:" | sed 's/^.*LogJamAI: Display: //' | tr -d '\r'
    ;;
  gdtrace)
    tree="${1:-thirdjam}"; shift || true
    G="$(godot_exe)"
    out="$TL/gdtrace.$$.txt"
    if [ "$tree" = thirdjam ]; then
      proj="$ROOT/engine"; script="res://cores/rink/tools/rink_trace.gd"
    else
      proj="$TL/rink-t5-proj"; script="res://tools/rink_trace.gd"
      mkdir -p "$proj/bin" "$proj/tools" "$proj/.godot"
      cp "$BIN/rink_core_t5.windows.template_debug.x86_64.dll" "$proj/bin/"
      cp "$ROOT/engine/cores/rink/tools/rink_trace.gd" "$proj/tools/"
      printf 'config_version=5

[application]
config/name="rink-t5-proof"
' > "$proj/project.godot"
      printf '[configuration]
entry_symbol = "rink_core_init"
compatibility_minimum = "4.7"

[libraries]
windows.debug.x86_64 = "res://bin/rink_core_t5.windows.template_debug.x86_64.dll"
' > "$proj/rink_core_t5.gdextension"
      echo "res://rink_core_t5.gdextension" > "$proj/.godot/extension_list.cfg"
    fi
    "$G" --headless --path "$proj" --script "$script" -- "--content=$(cygpath -m "$(content_for "$tree")" 2>/dev/null || content_for "$tree")"       "--out=$(cygpath -m "$out" 2>/dev/null || echo "$out")" "$@" >/dev/null 2>&1 || true
    tr -d '' < "$out" 2>/dev/null; rm -f "$out"
    ;;
  ue)
    name="$1"; shift
    mkdir -p "$TL/ue"
    "$UE" "$TJ_RUN/ThirdJam.uproject" -run=JamTournament "$@" -nullrhi -Multiprocess -unattended -stdout -abslog="$(cygpath -m "$TL/ue/$name.log" 2>/dev/null || echo "$TL/ue/$name.log")" > "$TL/ue/$name.stdout" 2>&1 || true
    grep "LogJamAI: Display:" "$TL/ue/$name.stdout" | sed 's/^.*LogJamAI: Display: //' | tr -d '\r' > "$TL/ue/$name.txt"
    rm -f "$TL/ue/$name.stdout"
    echo "ue $name: $(wc -l < "$TL/ue/$name.txt") lines"
    ;;
  compare)
    a="$1"; b="$2"
    na=$(wc -l < "$a"); nb=$(wc -l < "$b")
    if [ "$na" -eq 0 ]; then echo "FAIL  compare: $a is empty (a stopped run)"; exit 1; fi
    if cmp -s "$a" "$b"; then echo "PASS  compare: $na of $na lines identical ($(basename "$a") = $(basename "$b"))"; exit 0; fi
    ln=$(cmp "$a" "$b" 2>&1 | sed -n 's/.*line \([0-9]*\).*/\1/p' || true)
    nd=$(diff "$a" "$b" 2>/dev/null | grep -c '^<' || true)
    fr=$(sed -n "${ln:-1}p" "$a" | sed -n 's/^TRACE f=\([0-9]*\).*/\1/p')
    echo "FAIL  compare: $na vs $nb lines; $nd lines of $(basename "$a") differ; first difference at line ${ln:-?}${fr:+ (frame $fr)}: $(sed -n "${ln:-1}p" "$a" | cut -c1-100)"
    exit 1
    ;;
  # ---- lane K4 (reference): the lab runner and the balance harness (engine/cores/rink/lab; measurement only) ----
  #   engine/tools/rink.sh lab-build                 rinklab.exe: thirdjam's JamCore (native/thirdjam, unchanged) + the lab's input filter and probes
  #                                                  (MSVC through SCons; godot-cpp is not needed)
  #   engine/tools/rink.sh balance [--update]        the ladder, five ablations and the tempo probes against lab/balance.baseline.json
  #   engine/tools/rink.sh lab <match|gym> <args>    rinklab.exe with the content dir filled in (e.g. lab match -seeds=1-10 -difficulty=pro -player=good -remove=pass)
  lab-build)
    command -v scons >/dev/null 2>&1 || { echo "NOT RUN  rink lab-build: scons not found (pip install scons)"; exit 2; }
    lab_was="$(sha1sum "$ROOT/engine/cores/rink/lab/bin/rinklab.exe" 2>/dev/null | cut -c1-40)"
    scons -C "$ROOT/engine/cores/rink/lab" -j"$(nproc)" -Q >/dev/null || { echo "FAIL  rink lab-build"; exit 1; }
    echo "PASS  rink lab-build: engine/cores/rink/lab/bin/rinklab.exe"
    # H1b: a new lab measures the house and base cartridges once now, so a job's first check reads the cache (check-warm)
    [ "${TL_RINK_WARM:-1}" = 0 ] || [ "$lab_was" = "$(sha1sum "$ROOT/engine/cores/rink/lab/bin/rinklab.exe" | cut -c1-40)" ] || "$0" check-warm
    ;;
  lab)
    [ -f "$ROOT/engine/cores/rink/lab/bin/rinklab.exe" ] || "$0" lab-build >/dev/null || { echo "NOT RUN  rink lab: rinklab.exe could not be built"; exit 2; }
    mode="${1:-match}"; shift || true
    "$ROOT/engine/cores/rink/lab/bin/rinklab.exe" "$mode" "$(cygpath -m "$NATIVE/content" 2>/dev/null || echo "$NATIVE/content")" "$@" | grep -E '^({|TRACE )'
    ;;
  balance)
    [ -f "$ROOT/engine/cores/rink/lab/bin/rinklab.exe" ] || "$0" lab-build || { echo "NOT RUN  rink balance: rinklab.exe could not be built"; exit 2; }
    node "$ROOT/engine/cores/rink/lab/balance.mjs" "$@"
    ;;
  # ---- lane K8 (balance): the thirdlife variant of the lab (native/thirdjam + native/patches-thirdlife, built from a copy; measurement only) ----
  #   engine/tools/rink.sh lab-build-thirdlife            rinklab-thirdlife.exe: the patched copy of thirdjam (lab/thirdlife-tree.sh) + the lab
  #   engine/tools/rink.sh lab-thirdlife <match|gym> ...  rinklab-thirdlife.exe with the content dir filled in (-cartridge=hockey.thirdlife -plan=regular ...)
  #   engine/tools/rink.sh balance-thirdlife --parity     hockey.regular on the patched tree against the REFERENCE baseline: every switch off = thirdjam, hash for hash
  #   engine/tools/rink.sh balance-thirdlife [--update]   hockey.thirdlife against lab/balance.thirdlife.baseline.json (its own change detector)
  lab-build-thirdlife)
    command -v scons >/dev/null 2>&1 || { echo "NOT RUN  rink lab-build-thirdlife: scons not found (pip install scons)"; exit 2; }
    bash "$ROOT/engine/cores/rink/lab/thirdlife-tree.sh" || exit $?
    lab_was="$(sha1sum "$ROOT/engine/cores/rink/lab/bin/rinklab-thirdlife.exe" 2>/dev/null | cut -c1-40)"
    scons -C "$ROOT/engine/cores/rink/lab" variant=thirdlife -j"$(nproc)" -Q >/dev/null || { echo "FAIL  rink lab-build-thirdlife"; exit 1; }
    echo "PASS  rink lab-build-thirdlife: engine/cores/rink/lab/bin/rinklab-thirdlife.exe"
    [ "${TL_RINK_WARM:-1}" = 0 ] || [ "$lab_was" = "$(sha1sum "$ROOT/engine/cores/rink/lab/bin/rinklab-thirdlife.exe" | cut -c1-40)" ] || "$0" check-warm
    ;;
  lab-thirdlife)
    "$0" lab-build-thirdlife >/dev/null || { echo "NOT RUN  rink lab-thirdlife: rinklab-thirdlife.exe could not be built"; exit 2; }
    mode="${1:-match}"; shift || true
    "$ROOT/engine/cores/rink/lab/bin/rinklab-thirdlife.exe" "$mode" "$(cygpath -m "$NATIVE/content" 2>/dev/null || echo "$NATIVE/content")" "$@" | grep -E '^({|TRACE )'
    ;;
  balance-thirdlife)
    "$0" lab-build-thirdlife || { echo "NOT RUN  rink balance-thirdlife: rinklab-thirdlife.exe could not be built"; exit 2; }
    if [ "${1:-}" = "--parity" ]; then
      shift
      node "$ROOT/engine/cores/rink/lab/balance.mjs" --exe engine/cores/rink/lab/bin/rinklab-thirdlife.exe --cartridge hockey.regular "$@"
    else
      node "$ROOT/engine/cores/rink/lab/balance.mjs" --exe engine/cores/rink/lab/bin/rinklab-thirdlife.exe --cartridge hockey.thirdlife         --baseline engine/cores/rink/lab/balance.thirdlife.baseline.json "$@"
    fi
    ;;
  # ---- lane E2 (cartridge): a measured check of a cartridge before a person plays it ----
  #   engine/tools/rink.sh check-cartridge <file.cartridge.json> [--rules <file.rules.json>] [--seeds N] [--plan-seeds M] [--json-only]
  #   thirdjam's validator, then the lab plays it headless (thirdjam's regular playtester with sprint, N seeds a level, and the planning
  #   hand, M seeds a level, at rookie / pro / all_star) and says what a person will meet; a tl.rink.check/1 JSON line last
  check-cartridge)
    if [ -n "${TL_RINKLAB_EXE:-}" ]; then :   # a stand-in lab (the Foreman's tests): nothing to build
    elif [[ " $* " == *" --rules "* ]]; then
      [ -f "$ROOT/engine/cores/rink/lab/bin/rinklab-thirdlife.exe" ] || "$0" lab-build-thirdlife >/dev/null || { echo "NOT RUN  rink check-cartridge: rinklab-thirdlife.exe could not be built"; exit 2; }
    else
      [ -f "$ROOT/engine/cores/rink/lab/bin/rinklab.exe" ] || "$0" lab-build >/dev/null || { echo "NOT RUN  rink check-cartridge: rinklab.exe could not be built"; exit 2; }
    fi
    node "$ROOT/engine/cores/rink/lab/check_cartridge.mjs" "$@"
    ;;
  # ---- H1b of 25 Nov: the check's cache warmed ----
  #   engine/tools/rink.sh check-warm    the measured check, as the Foreman runs it (--defects), of the house game's cartridge
  #   (packs/hokej) and every base's (templates/*/data/*.cartridge.json), each with its rules file when it has one, so their
  #   results are in .tl/check-cartridge-cache/ before a job asks: a job's first lint then waits seconds, not minutes.
  #   lab-build and lab-build-thirdlife run it when the exe they built is new (TL_RINK_WARM=0 skips it).
  check-warm)
    export TL_RINK_WARM=0
    cw_n=0; cw_cached=0; cw_bad=""
    for cw_f in "$ROOT"/engine/packs/hokej/data/hockey.thirdlife.cartridge.json "$ROOT"/engine/templates/*/data/*.cartridge.json; do
      [ -f "$cw_f" ] || continue
      cw_r="${cw_f%.cartridge.json}.rules.json"
      cw_p="$(cygpath -m "$cw_f" 2>/dev/null || echo "$cw_f")"
      if [ -f "$cw_r" ]; then cw_line="$("$0" check-cartridge "$cw_p" --rules "$(cygpath -m "$cw_r" 2>/dev/null || echo "$cw_r")" --defects --json-only | tail -1)"
      else cw_line="$("$0" check-cartridge "$cw_p" --defects --json-only | tail -1)"; fi
      cw_n=$((cw_n + 1))
      case "$cw_line" in
        *'"cached":true'*) cw_cached=$((cw_cached + 1)) ;;
        *'"ran":true'*) ;;
        *) cw_bad="$cw_bad ${cw_f#$ROOT/}" ;;
      esac
    done
    [ "$cw_n" -gt 0 ] || { echo "NOT RUN  rink check-warm: no house or base cartridge found"; exit 2; }
    [ -z "$cw_bad" ] || { echo "FAIL  rink check-warm: not measured:$cw_bad"; exit 1; }
    echo "PASS  rink check-warm: $cw_n cartridge(s) in the cache ($((cw_n - cw_cached)) measured now, $cw_cached already there)"
    ;;
  *)
    sed -n '2,15p' "$0"; exit 2 ;;
esac
