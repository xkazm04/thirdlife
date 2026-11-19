# Headless single-axis silhouette decision. The D3D12 coverage/boil measurements require a window.
if [ -z "$FILTER" ] || [[ "style.walker.ink" == *"$FILTER"* ]]; then
  ink_godot="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  ink_engine="$(cd "$HERE/.." && pwd)"
  command -v cygpath >/dev/null 2>&1 && ink_engine="$(cygpath -m "$ink_engine")"
  ink_log="$OUT/walker-ink.log"
  ink_error=""
  MSYS_NO_PATHCONV=1 "$ink_godot" --headless --path "$ink_engine" --quit-after 4 \
    --script res://rigs/review/walker_ink_case.gd >"$ink_log" 2>&1 || ink_error="Godot exit $?"
  if ! tr -d '\r' <"$ink_log" | grep -Fxq 'INK_CORE completed=11 failed=0'; then
    ink_error="${ink_error:+$ink_error, }$(grep -aE 'ink case |INK_CORE|ERROR' "$ink_log" | head -1)"
    ink_error="${ink_error:-missing completion line}"
  fi
  if grep -aqE 'SCRIPT ERROR|^ERROR:' "$ink_log"; then ink_error="engine error in $ink_log"; fi
  verdict style.walker.ink "$ink_error" "7 body/depth cases, 3 terrain tap profiles and 1 strong silhouette"
fi
