#!/bin/bash
# From the worktree root. Keep the evidence script outside Godot's resource tree.
set -eu
r2="docs/shifts/2026-11-19-night/lanes/walker/r2"
mkdir -p .tl/walker-r2
cp "$r2/village_scan.gd.txt" .tl/walker-r2/village_scan.gd
root="$(pwd)"
if command -v cygpath >/dev/null; then root="$(cygpath -m "$root")"; fi
gd="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
MSYS_NO_PATHCONV=1 "$gd" --position 0,1440 --resolution 320x180 --audio-driver Dummy --fixed-fps 60 \
  --path "$root/engine" --script "$root/.tl/walker-r2/village_scan.gd"
