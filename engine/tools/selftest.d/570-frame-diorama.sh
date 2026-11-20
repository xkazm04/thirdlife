# Diorama night (20 Nov), frame pillar: the style keys of the frame, the lens rule, the installed rig and the sky's seam
# (engine/style/cases/frame_case.gd). keys and lens run headless; rig and seam need a picture: a small window, taken
# under the machine's window lock. A missing FRAME line is a FAIL, never a pass.

frame_wanted=0
for frame_n in keys lens rig seam; do
  if [ -z "$FILTER" ] || [[ "style.frame_$frame_n" == *"$FILTER"* ]]; then frame_wanted=1; fi
done
if [ $frame_wanted -eq 1 ]; then
  frame_godot="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  frame_engine="$(cd "$HERE/.." && pwd)"
  command -v cygpath >/dev/null 2>&1 && frame_engine="$(cygpath -m "$frame_engine")"
  frame_head="$(MSYS_NO_PATHCONV=1 timeout 120 "$frame_godot" --headless --fixed-fps 60 --path "$frame_engine" --script res://style/cases/frame_case.gd 2>&1 | tr -d '\r' | grep -a '^FRAME \|SCRIPT ERROR')"
  frame_win=""
  if [ -z "$FILTER" ] || [[ "style.frame_rig" == *"$FILTER"* ]] || [[ "style.frame_seam" == *"$FILTER"* ]]; then
    # the window lock of world.sh (one test window at a time on this machine), taken the same way
    frame_lock="${TEMP:-${TMP:-/tmp}}"; command -v cygpath >/dev/null 2>&1 && frame_lock="$(cygpath -u "$frame_lock")"
    frame_lock="$frame_lock/thirdlife_window.lock"; frame_waited=0; frame_held=0
    while [ $frame_waited -lt 900 ]; do
      if mkdir "$frame_lock" 2>/dev/null; then echo $$ > "$frame_lock/pid"; frame_held=1; break; fi
      frame_holder="$(cat "$frame_lock/pid" 2>/dev/null)"      # a holder that is gone: the lock is taken over
      case "$frame_holder" in
        "") ;;
        win:*) tasklist //FI "PID eq ${frame_holder#win:}" //NH 2>/dev/null | grep -q " ${frame_holder#win:} " || { rm -rf "$frame_lock"; continue; };;
        *) kill -0 "$frame_holder" 2>/dev/null || { rm -rf "$frame_lock"; continue; };;
      esac
      sleep 2; frame_waited=$((frame_waited + 2))
    done
    if [ $frame_held -eq 1 ]; then
      frame_win="$(MSYS_NO_PATHCONV=1 timeout 180 "$frame_godot" --position "${TL_WINDOW_POS:-0,1440}" --resolution 640x360 --rendering-driver d3d12 --audio-driver Dummy --fixed-fps 60 --path "$frame_engine" --script res://style/cases/frame_case.gd 2>&1 | tr -d '\r' | grep -a '^FRAME \|SCRIPT ERROR\|SHADER ERROR')"
      rm -rf "$frame_lock"
    else
      frame_win="FRAME rig fail the window lock was not free after ${frame_waited}s"$'\n'"FRAME seam fail the window lock was not free after ${frame_waited}s"
    fi
  fi
  for frame_n in keys lens rig seam; do
    case "$frame_n" in keys|lens) frame_src="$frame_head";; *) frame_src="$frame_win";; esac
    frame_line="$(echo "$frame_src" | grep -a "^FRAME $frame_n " | head -1)"
    frame_why=""
    if [ -z "$frame_line" ]; then frame_why="no FRAME $frame_n line ($(echo "$frame_src" | grep -a 'ERROR' | head -1 | cut -c1-160))"
    elif [[ "$frame_line" != "FRAME $frame_n ok "* ]]; then frame_why="${frame_line#FRAME $frame_n fail }"
    elif echo "$frame_src" | grep -aq 'SCRIPT ERROR\|SHADER ERROR'; then frame_why="$(echo "$frame_src" | grep -a 'SCRIPT ERROR\|SHADER ERROR' | head -1 | cut -c1-200)"; fi
    verdict "style.frame_$frame_n" "$frame_why" "${frame_line#FRAME $frame_n ok }"
  done
fi
