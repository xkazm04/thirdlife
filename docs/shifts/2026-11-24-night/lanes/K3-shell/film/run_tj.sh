#!/bin/bash
# K3 round 2: thirdjam's rendered build (t5 tree, in place, read-only except its Saved/), regular cut, pro, its own measured hand,
# one JAMCAM line a sim frame, a still every 30 sim frames. 1280x720 (16:9, the camera's KeepAspect).
D=C:/Users/kazda/kiro/third-life/.claude/worktrees/n23-teardown/.tl/tj-run; O=C:/Users/kazda/kiro/third-life/.claude/worktrees/hk-shell/.tl/tj; T="${1:-200}"
UE="C:/Program Files/Epic Games/UE_5.9/Engine/Binaries/Win64/UnrealEditor.exe"
date +%s > $O/start.txt
MSYS_NO_PATHCONV=1 timeout $T "$UE" "$D/Game/ThirdJam.uproject" "/Game/Maps/Rink?level=pro" -game -windowed -ResX=1280 -ResY=720 -WinX=0 -WinY=1440 -nosound -Multiprocess -cut=hockey.regular \
  -ExecCmds="jam.ScriptHuman 2, jam.screen.StillEvery 30, jam.camera.Log 1" "-abslog=$O/game.log" > /dev/null 2>&1
echo "exit $?" > $O/done.txt
