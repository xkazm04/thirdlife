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
      "$0" build thirdjam template_debug && "$0" build thirdjam template_release && "$0" build thirdjam-t5 template_debug
      exit $?
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
    (cd "$NATIVE" && scons -j"$(nproc)" platform=windows target="$target" custom_api_file="$(cygpath -m "$API" 2>/dev/null || echo "$API")" tree="$tree" cli=yes)       || { echo "FAIL  rink build $tree $target"; exit 1; }
    # Godot 4.7.2 segfaults at exit when a filesystem scan discovers a GDExtension for the first time (any extension, a hello
    # world too); listing it in .godot/extension_list.cfg before the first import loads it at startup instead.
    if [ "$tree" = thirdjam ]; then
      mkdir -p "$ROOT/engine/.godot"
      grep -qx "res://cores/rink/rink_core.gdextension" "$ROOT/engine/.godot/extension_list.cfg" 2>/dev/null         || echo "res://cores/rink/rink_core.gdextension" >> "$ROOT/engine/.godot/extension_list.cfg"
    fi
    echo "PASS  rink build $tree $target"
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
  *)
    sed -n '2,15p' "$0"; exit 2 ;;
esac
