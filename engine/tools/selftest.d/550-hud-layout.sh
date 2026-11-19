# Save on a disposable copy via real workbench input. Read it through TLHud and compare finished runs.
hud550_wanted() { [ -z "$FILTER" ] || [[ "$1" == *"$FILTER"* ]]; }
if hud550_wanted hud550.editor_save || hud550_wanted hud550.strict_data || hud550_wanted hud550.layout_applies || hud550_wanted hud550.village_clearance || hud550_wanted hud550.state_hash || hud550_wanted hud550.bad_key; then
  hud550_out="$(mktemp -d "$OUT/hud550.XXXXXX")"
  hud550_pack="$HERE/../packs/parkour"
  cp -R "$hud550_pack" "$hud550_out/custom"
  hud550_engine="$(cd "$HERE/.." && pwd)"
  hud550_native="$hud550_out/custom"
  if command -v cygpath >/dev/null 2>&1; then
    hud550_engine="$(cygpath -m "$hud550_engine")"
    hud550_native="$(cygpath -m "$hud550_native")"
  fi
  hud550_godot="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' timeout 90 "$hud550_godot" --headless --resolution 1280x720 --path "$hud550_engine" \
    --script res://ui/editor/hud/selftest.gd -- "$hud550_native" > "$hud550_out/editor.log" 2>&1
  hud550_rc=$?
  for hud550_id in editor_save strict_data layout_applies village_clearance; do
    why=""
    if ! grep -q "^HUDCASE $hud550_id PASS" "$hud550_out/editor.log" || [ "$hud550_rc" -ne 0 ] || grep -qE "SCRIPT ERROR|^ERROR:" "$hud550_out/editor.log"; then
      why="workbench run exited $hud550_rc; see $hud550_out/editor.log"
    fi
    verdict "hud550.$hud550_id" "$why"
  done
  if hud550_wanted hud550.state_hash; then
    why=""; hud550_a=""; hud550_b=""
    for hud550_mode in default custom; do
      hud550_dir="$hud550_pack"; [ "$hud550_mode" = custom ] && hud550_dir="$hud550_out/custom"
      TL_QUIET=1 bash "$TL" bot "--pack=$hud550_dir" --seed=1 --test=tests/bot_course.gd "--report=$hud550_out/$hud550_mode.json" > "$hud550_out/$hud550_mode.log" || why="$hud550_mode bot failed"
    done
    hud550_hash() { node -e 'const r = JSON.parse(require("fs").readFileSync(process.argv[1])); if (!r.ok || !r.bot?.done || !r.metrics?.state_hash) process.exit(1); console.log(r.metrics.state_hash + "@" + r.bot.frames)' "$1"; }
    hud550_a="$(hud550_hash "$hud550_out/default.json")" && hud550_b="$(hud550_hash "$hud550_out/custom.json")" || why="missing finished run"
    [ "$hud550_rc" = 0 ] && [ -n "$hud550_a" ] && [ "$hud550_a" = "$hud550_b" ] || why="custom layout did not save or runs differ: $hud550_a / $hud550_b"
    verdict hud550.state_hash "$why" "$hud550_a"
  fi
  if hud550_wanted hud550.bad_key; then
    echo '{"theme":"signal","widgets":[{"id":"next","mystery":true}]}' > "$hud550_out/custom/data/hud.json"
    check hud550.bad_key 1 smoke "--pack=$hud550_out/custom" --frames=20 -- "unknown key 'mystery'"
  fi
fi
