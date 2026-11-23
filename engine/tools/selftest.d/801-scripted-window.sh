# K1 round 4: a scripted session in a real window samples its keys on their frames, even when another window takes the focus.
# The OS layer releases held keys when a window loses focus; kernel/runner/session.gd now presses again what the script holds.
#   window.scripted_focus  the rink probe pack's hand as raw key events (--devices) in a real window, twice, with a small window of
#                          our own opening over it 20 s into the first run: both windows' input records equal the headless run's
#                          sample for sample (tl.input/1 frames)
# needs: the rink core built (engine/tools/rink.sh build); the probe pack engine/cores/rink/test_pack.
if [ -z "$FILTER" ] || [[ "window.scripted_focus" == *"$FILTER"* ]]; then
  why=""; note=""
  sw_g="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  sw_pack="$HERE/../cores/rink/test_pack"
  sw_dev="$sw_pack/data/hand.devices.json"
  sw_o="$OUT/scripted_window"; rm -rf "$sw_o"; mkdir -p "$sw_o/thief"
  sw_ow="$sw_o"
  if command -v cygpath >/dev/null 2>&1; then sw_ow="$(cygpath -am "$sw_o")"; sw_dev="$(cygpath -am "$sw_dev")"; fi
  if [ ! -f "$HERE/../cores/rink/bin/rink_core.windows.template_debug.x86_64.dll" ]; then
    why="the rink core is not built (run: bash engine/tools/rink.sh build)"
  else
    # the focus thief: a tiny project whose scene quits itself after 120 frames
    printf 'config_version=5\n\n[application]\nconfig/name="focus-thief"\nrun/main_scene="res://main.tscn"\n' > "$sw_o/thief/project.godot"
    printf 'extends Node\nvar n := 0\nfunc _process(_d: float) -> void:\n\tn += 1\n\tif n > 120:\n\t\tget_tree().quit(0)\n' > "$sw_o/thief/main.gd"
    printf '[gd_scene format=3]\n\n[ext_resource type="Script" path="res://main.gd" id="1"]\n\n[node name="Main" type="Node"]\nscript = ExtResource("1")\n' > "$sw_o/thief/main.tscn"
    timeout 300 bash "$TL" play "--pack=$sw_pack" --seed=3 --headless --frames=3001 "--devices=$sw_dev" "--record=$sw_ow/hl.json" >/dev/null 2>&1
    ( timeout 300 bash "$TL" play "--pack=$sw_pack" --seed=3 --frames=3001 "--devices=$sw_dev" "--record=$sw_ow/win1.json" > "$sw_o/win1.log" 2>&1 ) &
    sw_pid=$!
    sleep 20
    MSYS_NO_PATHCONV=1 timeout 60 "$sw_g" --path "$sw_ow/thief" --resolution 320x240 >/dev/null 2>&1
    wait "$sw_pid"
    timeout 300 bash "$TL" play "--pack=$sw_pack" --seed=3 --frames=3001 "--devices=$sw_dev" "--record=$sw_ow/win2.json" > "$sw_o/win2.log" 2>&1
    for f in hl win1 win2; do [ -s "$sw_o/$f.json" ] || why="${why:+$why; }no input record from the $f run (a stopped run)"; done
    if [ -z "$why" ]; then
      sw_cmp="$(python -I - "$sw_o/hl.json" "$sw_o/win1.json" "$sw_o/win2.json" <<'PYEOF'
import json, sys
recs = [json.load(open(p)) for p in sys.argv[1:]]
base = recs[0]["frames"]
out = []
for name, r in zip(("window 1 (focus stolen)", "window 2"), recs[1:]):
    fr = r["frames"]
    if fr == base:
        out.append("%s: %d of %d samples equal" % (name, len(fr), len(base)))
    else:
        first = next((i for i, (a, b) in enumerate(zip(base, fr)) if a != b), min(len(base), len(fr)))
        out.append("DIFF %s: %d vs %d samples, first differing sample %d (%s vs %s)" % (name, len(fr), len(base), first,
            base[first] if first < len(base) else "-", fr[first] if first < len(fr) else "-"))
print("; ".join(out))
PYEOF
)"
      case "$sw_cmp" in *DIFF*) why="$sw_cmp";; *) note="$sw_cmp";; esac
    fi
  fi
  verdict window.scripted_focus "$why" "$note"
fi
