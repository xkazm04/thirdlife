# Hockey campaign, lane K6 (24 Nov 2026): thirdjam's sound in our engine (engine/cores/rink/audio, kernel TLSound;
# headless: cores/rink/audio/review/audio_case.gd). core.rink.audio.table: the sound table names only files that exist,
# every Variant has its Strength steps, the files stay under 60 MB. .kernel: TLSound records a play, a loop, a say and
# a stop headless and refuses a bad option, channel and path. .match: a whole match of the bare core: every event that
# sounds in thirdjam has its row at its frame with thirdjam's Variant, two runs agree. .tj: thirdjam's own event log of
# a played match through the same rules; a goal's Variant is the one thirdjam's binder logged. .loops: the music's
# levels, the crowd bed, the skate loop's numbers.

if [ -z "$FILTER" ] || [[ "core.rink.audio.table core.rink.audio.kernel core.rink.audio.match core.rink.audio.tj core.rink.audio.loops" == *"$FILTER"* ]]; then
  au_godot="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  au_engine="$(cd "$HERE/.." && pwd)"; command -v cygpath >/dev/null 2>&1 && au_engine="$(cygpath -m "$au_engine")"
  au_out="$(MSYS_NO_PATHCONV=1 timeout 300 "$au_godot" --headless --fixed-fps 60 --path "$au_engine" \
    --script res://cores/rink/audio/review/audio_case.gd 2>&1 | tr -d '\015' | grep -a '^AUDIO \|SCRIPT ERROR')"
  for au_case in table kernel match tj loops; do
    if [ -z "$FILTER" ] || [[ "core.rink.audio.$au_case" == *"$FILTER"* ]]; then
      au_line="$(echo "$au_out" | grep -a "^AUDIO $au_case " | head -1)"
      why=""
      if [ -z "$au_line" ]; then why="no AUDIO $au_case line (${au_out:0:160})"
      elif echo "$au_out" | grep -aq 'SCRIPT ERROR'; then why="script error: $(echo "$au_out" | grep -a 'SCRIPT ERROR' | head -1)"
      elif [[ "$au_line" != "AUDIO $au_case ok=true"* ]]; then why="${au_line:0:300}"; fi
      verdict "core.rink.audio.$au_case" "$why" "${au_line#AUDIO $au_case ok=true }"
    fi
  done
fi
