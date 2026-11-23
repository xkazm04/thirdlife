#!/bin/bash
# H2: as game.sh, with the scripted hand's seed (jam.ScriptHumanSeed) so a second and third match differ. game2.sh <level> <seed> [seconds]
D=C:/Users/kazda/kiro/third-life/.claude/worktrees/d23-bots/.tl/tj-run; L="$1"; S="$2"; T="${3:-330}"; O=$D/out/game_${L}_s$S; mkdir -p $O
UE="C:/Program Files/Epic Games/UE_5.9/Engine/Binaries/Win64/UnrealEditor.exe"
MSYS_NO_PATHCONV=1 timeout $T "$UE" "$D/Game/ThirdJam.uproject" "/Game/Maps/Rink?level=$L" -game -windowed -ResX=640 -ResY=360 -nosound -Multiprocess \
  -ExecCmds="jam.ScriptHumanSeed $S, jam.ScriptHuman 2" "-abslog=$O/game.log" > /dev/null 2>&1
grep -c "JAMEVENT" $O/game.log
