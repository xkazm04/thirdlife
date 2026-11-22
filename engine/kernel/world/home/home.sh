#!/usr/bin/env bash
# Run one paired capture. Big evidence stays in this worktree. The lock is identical to world.sh.
set -e
ROOT="$(cygpath -m "$(dirname "$(realpath "$0")")/../../../..")"
ROOT="$(cygpath -m "$(realpath "$ROOT")")"
E="$ROOT/engine"
G="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
H="$E/kernel/world/home"
round="${1:?home.sh ROUND}"
[[ "$round" =~ ^[1-9][0-9]*$ ]]
archive="$ROOT/docs/shifts/2026-11-22-night/lanes/N6-world/arm-a/round-$round"
if [[ -f "$archive/figures.json" || -f "$archive/SCORES.md" ]]; then
  echo "Round $round already has evidence. Use a fresh round number to preserve it." >&2
  exit 2
fi
export TL_STYLE=crisp MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*'
export TL_HOME_RAW="$ROOT/.tl/home-a/round-$round"
mkdir -p "$TL_HOME_RAW"
export TL_HOME_CAPTURE_ID="window-$round-$-$RANDOM"
if (( round >= 5 )); then export TL_HOME_LONG=1; else export TL_HOME_LONG=0; fi
lock_alive() {
  case "$1" in
    win:*) tasklist //FI "PID eq ${1#win:}" //NH 2>/dev/null | grep -q " ${1#win:} ";;
    *) kill -0 "$1" 2>/dev/null;;
  esac
}
win_lock() {
  [ "${TL_WINDOW_LOCK:-on}" = off ] && return 0
  local d="${TEMP:-${TMP:-/tmp}}" waited=0 holder
  command -v cygpath >/dev/null 2>&1 && d="$(cygpath -u "$d")"
  TL_LOCK_DIR="$d/thirdlife_window.lock"
  while ! mkdir "$TL_LOCK_DIR" 2>/dev/null; do
    holder="$(cat "$TL_LOCK_DIR/pid" 2>/dev/null)"
    if [ -n "$holder" ] && ! lock_alive "$holder"; then
      echo "[lock] the holder ($holder) is gone: the window lock is taken over" >&2
      rm -rf "$TL_LOCK_DIR"; continue
    fi
    [ $waited -eq 0 ] && echo "[lock] another test window is open (process ${holder:-?}): waiting for it" >&2
    sleep 2; waited=$((waited + 2))
  done
  echo "$TL_LOCK_PID" > "$TL_LOCK_DIR/pid"; TL_LOCK_HELD=1
  echo "[lock] window lock taken by $TL_LOCK_PID after ${waited}s" >&2
  trap win_unlock EXIT
}
win_unlock() { [ -n "$TL_LOCK_HELD" ] && rm -rf "$TL_LOCK_DIR"; TL_LOCK_HELD=""; return 0; }
TL_LOCK_PID=$$
unset TL_WINDOW_LOCK
# A releasing holder can remove pid between mkdir and cat. world.sh permits that retry.
win_lock || exit 1
for paired in 1 0 2; do
  case "$paired" in 1) export TL_HOME_PASS=baseline;; 0) export TL_HOME_PASS=growth;; 2) export TL_HOME_PASS=clean;; esac
  "$G" --position 0,1440 --resolution 1920x1080 --rendering-driver d3d12 --audio-driver Dummy --fixed-fps 60 --quit-after 4500 --log-file "$TL_HOME_RAW/godot-$paired.log" --path "$E" res://kernel/world/home/tour.tscn > "$TL_HOME_RAW/window-$paired.log" 2>&1
  if grep -Eq '^SCRIPT ERROR|^ERROR:' "$TL_HOME_RAW/window-$paired.log"; then
    cat "$TL_HOME_RAW/window-$paired.log" >&2
    exit 1
  fi
done
win_unlock
python "$H/evidence.py" "$ROOT" "$round"
