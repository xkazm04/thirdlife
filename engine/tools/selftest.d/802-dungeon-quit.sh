# K1 round 4: quitting the game while a dungeon is open never crashes. The engine's own quit (--quit-after; any quit that tears
# the tree down without the dungeon's close) left the dungeon's watchdog thread running and its script logger registered: exit
# 139 on every dungeon, 4 of 4 runs. kernel/dungeon/dungeon.gd now stops and frees them in _exit_tree.
#   dungeon.quit_after   parkour, duel and hockey as dungeons in a real window (boot.tscn, the exe's scene), quit by the engine
#                        after 240 frames: every process exits 0
if [ -z "$FILTER" ] || [[ "dungeon.quit_after" == *"$FILTER"* ]]; then
  why=""; note=""
  dq_g="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  dq_e="$(cd "$HERE/.." && pwd)"; command -v cygpath >/dev/null 2>&1 && dq_e="$(cygpath -am "$dq_e")"
  dq_ok=0
  for dq_p in parkour duel hockey; do
    MSYS_NO_PATHCONV=1 timeout 180 "$dq_g" --path "$dq_e" --resolution 640x360 --quit-after 240 res://boot/boot.tscn -- "--dungeon=$dq_e/packs/$dq_p" > "$OUT/dungeon_quit_$dq_p.log" 2>&1
    dq_rc=$?
    if [ "$dq_rc" = 0 ]; then dq_ok=$((dq_ok + 1)); else why="${why:+$why; }$dq_p exit $dq_rc"; fi
    grep -q '\[dungeon\].* runs:' "$OUT/dungeon_quit_$dq_p.log" || why="${why:+$why; }$dq_p never opened (see $OUT/dungeon_quit_$dq_p.log)"
  done
  [ -z "$why" ] && note="$dq_ok of 3 dungeons quit with exit 0"
  verdict dungeon.quit_after "$why" "$note"
fi
