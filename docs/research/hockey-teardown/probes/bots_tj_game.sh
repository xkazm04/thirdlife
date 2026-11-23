#!/bin/bash
# H2: thirdjam's rendered game at one level, its own measured hand on the human (jam.ScriptHuman 2), stills every 30 sim frames.
#   game.sh <rookie|pro|all_star> [seconds]
D=C:/Users/kazda/kiro/third-life/.claude/worktrees/d23-bots/.tl/tj-run; L="$1"; T="${2:-330}"; O=$D/out/game_$L; mkdir -p $O
UE="C:/Program Files/Epic Games/UE_5.9/Engine/Binaries/Win64/UnrealEditor.exe"
MSYS_NO_PATHCONV=1 timeout $T "$UE" "$D/Game/ThirdJam.uproject" "/Game/Maps/Rink?level=$L" -game -windowed -ResX=960 -ResY=540 -nosound -Multiprocess \
  -ExecCmds="jam.ScriptHuman 2, jam.screen.StillEvery 30" "-abslog=$O/game.log" > /dev/null 2>&1
grep -c "JAMEVENT" $O/game.log
