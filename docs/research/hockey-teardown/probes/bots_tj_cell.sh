#!/bin/bash
# H2: one thirdjam cell through its own headless commandlet (JamTournament, sim jam, hockey.regular), trace every frame.
#   cell.sh <rookie|pro|all_star> <brain|novice|regular> [seeds]
D=C:/Users/kazda/kiro/third-life/.claude/worktrees/d23-bots/.tl/tj-run; L="$1"; H="$2"; S="${3:-1-20}"
UE="C:/Program Files/Epic Games/UE_5.9/Engine/Binaries/Win64/UnrealEditor-Cmd.exe"
if [ "$H" = brain ]; then who=(-mode=brain); else who=("-player=$H"); fi
O=$D/out/${L}_${H}; mkdir -p $O
MSYS_NO_PATHCONV=1 "$UE" "$D/Game/ThirdJam.uproject" -run=JamTournament -sim=jam -cartridge=hockey.regular -difficulty=$L "${who[@]}" -seeds=$S -maxframes=36000 -trace=1 \
  -nullrhi -Multiprocess -unattended -nopause -nosplash -stdout -FullStdOutLogOutput "-abslog=$O/ue.log" 2>&1 | grep -E "TRACE|\"tool\"" > $O/trace.txt
grep -c '"tool"' $O/trace.txt
