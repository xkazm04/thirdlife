#!/bin/bash
# N6: the designer panel's stand-alone host (engine/ui/). The panel reads job directories (contracts/JOB.md) and
# starts the Foreman's command line; this script only opens, captures and checks it.
#
#   ui.sh open     --jobs=<dir> [--flags=<json>] [--readonly] [--select=<job>] [--res=1920x1080]
#                    a window with the panel. --flags names the Foreman settings per command (ui/flags/*.json);
#                    without it the panel shows the jobs and says that it can start nothing.
#   ui.sh shot     --jobs=<dir> [--select=<job>] [--section=brief|build|change|tune|notes|all|none]
#                  --out=<abs png> [--res=1920x1080] [--new-open] [--picture=<n>] [--bg=<png>|none]
#                    one capture; read only (no Foreman command is started, no file is written but the png)
#   ui.sh selftest   headless checks of the model behind the panel (the real marble job, a half-written log,
#                    a missing Foreman, a slider's write to a copy of a pack's data file)
#   ui.sh fixtures --out=<dir>   scratch jobs root with the display states, cut from the real marble job (read only)
#   ui.sh fake     --out=<dir>   fake-adapter script and flags for the live path (no model is called)
#   ui.sh live     --jobs=<scratch dir> --flags=<json> --shots=<dir>   the scripted live session (ui/drive.gd)
#   ui.sh sheet    --dir=<captures dir> --out=<abs png>   contact sheet of the captures
#   ui.sh editor   --jobs=<scratch dir> --flags=<json> --shots=<dir>   the workbench session (E1, ui/editor/;
#                    ui/drive.gd _editor): idea -> recipe -> answers -> place -> Build it, input events only
#   ui.sh rank     --ask=<json> --answer=<json>   score saved places headlessly
#   ui.sh place    --jobs=<scratch dir> --flags=<json> --shots=<dir>   rank suggestions, choose a lot, build
#   ui.sh home     --jobs=<scratch dir> --flags=<json> --shots=<dir>   the village board session (E5): New game,
#                    Build it, approve, the game on its lot while it is built, open it from the map, jobs list
#   ui.sh chips    --jobs=<scratch dir> --shots=<dir> [--n=60]   retype the idea and click a chip N times; FAIL on a lost click
#   ui.sh open ... --home   the village board as the home screen
#   ui.sh shot ... --editor [--sentence=<text>] [--recipe=<name>] [--place=<x>,<z>] [--turn=<n>] [--take]
#                    a capture of the workbench filled as given
#
# `open` stays until Esc or the window is closed; TL_UI_QUIT_AFTER=<frames> makes any window close by itself.
# Env: TL_GODOT (Godot console exe). TL_ENGINE_DIR is NOT read here: the panel runs from this engine copy; the
# Foreman it starts reads TL_ENGINE_DIR and TL_GODOT from the environment as usual.
G="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
E="$(cd "$(dirname "$0")/.." && pwd)"
REPO="$(cd "$E" && while [ ! -f foreman/dist/cli.js ] && [ "$PWD" != "/" ]; do cd ..; done; pwd)"
if command -v cygpath >/dev/null 2>&1; then
  E="$(cygpath -m "$E")"; G="$(cygpath -m "$G")"; REPO="$(cygpath -m "$REPO")"
fi

fix() {  # --name=/c/path -> --name=C:/path for the options that hold a path
  local a="$1"
  case "$a" in
    --jobs=*|--out=*|--flags=*|--shots=*|--bg=*|--dir=*|--foreman=*|--ask=*|--answer=*)
      local k="${a%%=*}" v="${a#*=}"
      if [ "$v" != "none" ] && command -v cygpath >/dev/null 2>&1; then
        case "$v" in /*|[A-Za-z]:*) v="$(cygpath -m "$v")";; *) v="$(cygpath -m "$PWD/$v")";; esac
      fi
      echo "$k=$v";;
    *) echo "$a";;
  esac
}

verb="$1"; shift
args=(); res="1920x1080"; out=""; dir=""
for a in "$@"; do
  case "$a" in
    --res=*) res="${a#*=}";;
    *) f="$(fix "$a")"; args+=("$f")
       case "$f" in --out=*) out="${f#*=}";; --dir=*) dir="${f#*=}";; esac;;
  esac
done

windowed() {  # like tools/tl.sh capture: a window below the desktop, Direct3D 12
  local quit=()
  [ -n "$TL_UI_QUIT_AFTER" ] && quit=(--quit-after "$TL_UI_QUIT_AFTER")
  MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' "$G" "${quit[@]}" --position "${TL_WINDOW_POS:-0,1440}" --resolution "$res" \
    --rendering-driver d3d12 --path "$E" "$@"
}

case "$verb" in
  ""|help|-h|--help) sed -n '2,28p' "$0"; exit 2;;
  open)   # E5: the village board is the home screen; --panel opens the designer panel as before
    home=(--home); for a in "${args[@]}"; do [ "$a" = "--panel" ] && home=(); done
    windowed res://ui/host.tscn -- "${home[@]}" "${args[@]}"; exit $?;;
  shot)
    [ -z "$out" ] && { echo "ui.sh shot needs --out=<abs png>"; exit 2; }
    for attempt in 1 2 3; do   # a window can die in the driver while it opens under GPU load (see RUNNER.md)
      rm -f "$out"
      windowed res://ui/host.tscn -- "${args[@]}" 2>&1 | grep -E "^\[ui\]|SCRIPT ERROR|ERROR:|Parse Error|   at:" | head -20
      [ -s "$out" ] && exit 0
      echo "[ui] no picture on attempt $attempt"
    done
    exit 1;;
  chips)  # the lost-click check: --n=<clicks> retype-then-click rounds on the workbench's chips (E5)
    windowed res://ui/host.tscn -- --drive=chips "${args[@]}" 2>&1 | grep -E "^\[drive\].*(LOST|chips:)|SCRIPT ERROR|Parse Error"
    exit "${PIPESTATUS[0]}";;
  home)
    windowed res://ui/host.tscn -- --drive=home --home "${args[@]}" 2>&1 | grep -E "^\[ui\]|^\[drive\]|SCRIPT ERROR|ERROR:|Parse Error|   at:"
    exit "${PIPESTATUS[0]}";;
  rank)
    MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' "$G" --headless --path "$E" --script res://ui/editor/rank_places.gd -- "${args[@]}"
    exit $?;;
  place)
    windowed res://ui/host.tscn -- --drive=place "${args[@]}" 2>&1 | grep -E "^\[ui\]|^\[drive\]|SCRIPT ERROR|ERROR:|Parse Error|   at:"
    exit "${PIPESTATUS[0]}";;
  editor)
    windowed res://ui/host.tscn -- --drive=editor "${args[@]}" 2>&1 | grep -E "^\[ui\]|^\[drive\]|SCRIPT ERROR|ERROR:|Parse Error|   at:"
    exit "${PIPESTATUS[0]}";;
  live)
    windowed res://ui/host.tscn -- --drive=live "${args[@]}" 2>&1 | grep -E "^\[ui\]|^\[drive\]|SCRIPT ERROR|ERROR:|Parse Error|   at:"
    exit "${PIPESTATUS[0]}";;
  selftest)
    MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' "$G" --headless --path "$E" --script res://ui/selftest.gd -- "--repo=$REPO" "${args[@]}" 2>&1 \
      | grep -E "^(PASS|FAIL|\[selftest\])|SCRIPT ERROR|ERROR:|Parse Error|   at:"
    exit "${PIPESTATUS[0]}";;
  fixtures)
    [ -z "$out" ] && { echo "ui.sh fixtures needs --out=<dir>"; exit 2; }
    node "$E/ui/fixtures/make_fixtures.mjs" "$REPO/site/marble-run-three-marbles-20261110-2" "$out"; exit $?;;
  fake)
    [ -z "$out" ] && { echo "ui.sh fake needs --out=<dir>"; exit 2; }
    node "$E/ui/fixtures/make_fake.mjs" "${TL_ENGINE_DIR:-$REPO/site/_engine_snapshot4}" "$out"; exit $?;;
  sheet)
    [ -z "$out" ] || [ -z "$dir" ] && { echo "ui.sh sheet needs --dir=<captures dir> --out=<abs png>"; exit 2; }
    res="1920x1080"
    windowed res://ui/sheet.tscn -- "${args[@]}" 2>&1 | grep -E "^\[ui\]|SCRIPT ERROR|ERROR:|Parse Error|   at:"
    [ -s "$out" ]; exit $?;;
  *) echo "ui.sh: unknown verb $verb"; sed -n '5,25p' "$0"; exit 2;;
esac
