#!/bin/bash
# H2 bots probe: run tests/bots_probe.gd over seeds for one cell, J at a time. run.sh <level> <hand> <seeds> [jobs]
W=C:/Users/kazda/kiro/third-life/.claude/worktrees/d23-bots
G=C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe
L="$1"; H="$2"; N="${3:-20}"; J="${4:-4}"; O=$W/.tl/probe/out/${L}_${H}; mkdir -p $O
for s in $(seq 1 $N); do
  ( PROBE_LEVEL=$L PROBE_HAND=$H MSYS_NO_PATHCONV=1 timeout 900 "$G" --headless --fixed-fps 60 --path "$W/engine" res://kernel/host/host.tscn -- worker --mode=bot "--pack=$W/.tl/probe/hockey" --test=tests/bots_probe.gd --seed=$s --frames=40000 "--result=$O/s$s.json" > $O/s$s.log 2>&1 ) &
  if (( s % J == 0 )); then wait; fi
done
wait
ls $O/*.json 2>/dev/null | wc -l
