# Lane flight round 2 (19 Nov 2026): the take-off and landing dust (kernel/world/flight_wings.gd `dust`, the style's
# `dust` preset). WINDOWED (a puff draws nothing headless), under the machine-wide test-window lock of world.sh / view.sh
# (thirdlife_window.lock in the temporary folder): one puff on the take-off tick and one on the landing tick, at the
# feet, emitting, each freed by DUST_FRAMES + 10 frames later, nothing else (kernel/world/flight_dust_case.gd).

if [ -z "$FILTER" ] || [[ "flight.dust" == *"$FILTER"* ]]; then
  fd_run() {
    local godot engine d lock holder waited=0 out
    godot="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
    engine="$(cd "$HERE/.." && pwd)"; command -v cygpath >/dev/null 2>&1 && engine="$(cygpath -m "$engine")"
    d="${TEMP:-${TMP:-/tmp}}"; command -v cygpath >/dev/null 2>&1 && d="$(cygpath -u "$d")"
    lock="$d/thirdlife_window.lock"
    if [ "${TL_WINDOW_LOCK:-on}" != off ]; then
      while ! mkdir "$lock" 2>/dev/null; do
        holder="$(cat "$lock/pid" 2>/dev/null)"
        if [ -n "$holder" ] && [[ "$holder" != win:* ]] && ! kill -0 "$holder" 2>/dev/null; then rm -rf "$lock"; continue; fi
        [ $waited -ge 900 ] && { echo "WINDOWLOCK timeout after ${waited}s (holder ${holder:-?})"; return; }
        sleep 2; waited=$((waited + 2))
      done
      echo "$BASHPID" > "$lock/pid"
    fi
    out="$(MSYS_NO_PATHCONV=1 timeout 120 "$godot" --fixed-fps 60 --resolution 640x360 --audio-driver Dummy --path "$engine" \
      --script res://kernel/world/flight_dust_case.gd 2>&1 | tr -d '\015' | grep -a '^FLIGHTDUST\|SCRIPT ERROR')"
    [ "${TL_WINDOW_LOCK:-on}" != off ] && rm -rf "$lock"
    echo "$out"
  }
  fd_out="$(fd_run)"
  fd_line="$(echo "$fd_out" | grep -a '^FLIGHTDUST ' | head -1)"
  why=""
  if [ -z "$fd_line" ]; then why="no FLIGHTDUST line (${fd_out:0:160})"
  elif echo "$fd_out" | grep -aq 'SCRIPT ERROR'; then why="script error: $(echo "$fd_out" | grep -a 'SCRIPT ERROR' | head -1)"
  elif [[ "$fd_line" != "FLIGHTDUST ok=true "* ]]; then why="$fd_line"; fi
  verdict flight.dust "$why" "${fd_line#FLIGHTDUST ok=true }"
fi
