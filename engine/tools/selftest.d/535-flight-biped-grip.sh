# Lane flight round 3 (19 Nov 2026): a PACK biped (TLBiped, moves ledge + bar) is posed on a grip: hangs 0.4 m low with hands within 0.35 m of the lip, mantles and stands upright, swings with hands within 0.30 m of the bar facing across it, upright 15 frames after release; a pack chase camera does not avoid a marked bar (control: lifts 60 deg, pulls 6.1 m).
# Headless (kernel/runner/biped_grip_case.gd); prints one `BIPEDGRIP ok=<bool> ...` line.

if [ -z "$FILTER" ] || [[ "moves.biped_grip" == *"$FILTER"* ]]; then
  b_godot="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  b_engine="$(cd "$HERE/.." && pwd)"; command -v cygpath >/dev/null 2>&1 && b_engine="$(cygpath -m "$b_engine")"
  b_out="$(MSYS_NO_PATHCONV=1 timeout 180 "$b_godot" --headless --fixed-fps 60 --path "$b_engine" --script res://kernel/runner/biped_grip_case.gd 2>&1 | tr -d '\015' | grep -a '^BIPEDGRIP\|SCRIPT ERROR')"
  b_line="$(echo "$b_out" | grep -a '^BIPEDGRIP ' | head -1)"
  why=""
  if [ -z "$b_line" ]; then why="no BIPEDGRIP line (${b_out:0:160})"
  elif echo "$b_out" | grep -aq 'SCRIPT ERROR'; then why="script error: $(echo "$b_out" | grep -a 'SCRIPT ERROR' | head -1)"
  elif [[ "$b_line" != "BIPEDGRIP ok=true "* ]]; then why="$b_line"; fi
  verdict moves.biped_grip "$why" "${b_line#BIPEDGRIP ok=true }"
fi
