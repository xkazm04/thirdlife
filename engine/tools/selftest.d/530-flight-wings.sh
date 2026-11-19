# Lane flight (day of 19 Nov 2026): the walker's mechanical wings (assets/engine/wings.glb, kernel/world/flight_wings.gd).
# Headless: the asset loads through TLKitAsset with its 17 named parts, unfolds in exactly 30 ticks and folds in 36,
# no wing tip moves more than 0.20 m in one tick while unfolding (no pop), folded it is a bundle behind his back inside
# his shoulders, spread it spans at least 3.5 m, and two runs pose the same (determinism).

if [ -z "$FILTER" ] || [[ "flight.wings" == *"$FILTER"* ]]; then
  fw_godot="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  fw_engine="$(cd "$HERE/.." && pwd)"; command -v cygpath >/dev/null 2>&1 && fw_engine="$(cygpath -m "$fw_engine")"
  fw_out="$(MSYS_NO_PATHCONV=1 timeout 120 "$fw_godot" --headless --fixed-fps 60 --path "$fw_engine" \
    --script res://kernel/world/flight_wings_case.gd 2>&1 | tr -d '\015' | grep -a '^WINGSCASE\|SCRIPT ERROR')"
  fw_line="$(echo "$fw_out" | grep -a '^WINGSCASE ' | head -1)"
  why=""
  if [ -z "$fw_line" ]; then why="no WINGSCASE line (${fw_out:0:160})"
  elif echo "$fw_out" | grep -aq 'SCRIPT ERROR'; then why="script error: $(echo "$fw_out" | grep -a 'SCRIPT ERROR' | head -1)"
  elif [[ "$fw_line" != "WINGSCASE ok=true "* ]]; then why="$fw_line"; fi
  verdict flight.wings "$why" "${fw_line#WINGSCASE ok=true }"
fi
