#!/bin/bash
# H2: thirdjam's own instrument Bar.Brain.Interest (lane A206), 3 levels x 20 seeds, the playtester hand $1 (novice|regular)
D=C:/Users/kazda/kiro/third-life/.claude/worktrees/d23-bots/.tl/tj-run; P="$1"; O=$D/out/interest_$P; mkdir -p $O
UE="C:/Program Files/Epic Games/UE_5.9/Engine/Binaries/Win64/UnrealEditor-Cmd.exe"
JAM_PLAYTESTER_CHECK=closing JAM_BRAIN_INTEREST="levels=rookie,pro,all_star;carts=hockey.regular;seeds=20;from=1;player=$P" MSYS_NO_PATHCONV=1 "$UE" "$D/Game/ThirdJam.uproject" \
  -ExecCmds="Automation RunTests Bar.Brain.Interest; Quit" -nullrhi -Multiprocess -unattended -nopause -nosplash -log "-ABSLOG=$O/ue.log" > /dev/null 2>&1
grep -o "INTEREST .*" $O/ue.log > $O/rows.txt; wc -l < $O/rows.txt
