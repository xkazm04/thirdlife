# Exercise the exported boot's frame-two decision without opening a second game window.
if [ -z "$FILTER" ] || [[ "style.cel.exe_aa" == *"$FILTER"* ]]; then
  cel_engine="$(cd "$HERE/.." && pwd)"
  cel_probe="$OUT/cel-exe-aa.gd"
  cat > "$cel_probe" <<'GDSCRIPT'
extends SceneTree

class ViewStub extends Node:
	var stage := -1

class BootProbe extends "res://boot/boot.gd":
	var selected := ""
	func _ready() -> void:
		set_physics_process(false)
	func _set_aa(spec: String) -> void:
		selected = spec

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var boot := BootProbe.new()
	root.add_child(boot)
	boot.view = ViewStub.new()
	boot.add_child(boot.view)
	OS.unset_environment("TL_EXE_AA")
	var ok := TLStyle.load_style(TLStyle.DEFAULT_PATH).is_empty()
	boot._frame = 1
	boot._physics_process(1.0/60.0)
	var fallback := boot.selected
	ok = ok and TLStyle.load_style("res://style/style_crisp.json").is_empty()
	boot._frame = 1
	boot._physics_process(1.0/60.0)
	var crisp := boot.selected
	OS.set_environment("TL_EXE_AA","ss=off,msaa=8")
	boot._frame = 1
	boot._physics_process(1.0/60.0)
	var override := boot.selected
	ok = ok and fallback=="msaa=2,taa=1" and crisp=="msaa=4,ss=fxaa,taa=0" and override=="ss=off,msaa=8"
	for bad: Variant in [true,"msaa=3","taa=1,taa=0","fx=off",""]:
		var settings := TLStyle.data.duplicate(true)
		settings.env.exe_aa = bad
		if TLStyle.check(settings).is_empty():
			ok = false
	print("CEL_EXE_AA ok=",ok," fallback=",fallback," crisp=",crisp," override=",override)
	boot.free()
	quit(0 if ok else 1)
GDSCRIPT
  if command -v cygpath >/dev/null 2>&1; then
    cel_engine="$(cygpath -m "$cel_engine")"; cel_probe="$(cygpath -m "$cel_probe")"
  fi
  cel_log="$OUT/cel-exe-aa.log"
  cel_why=""
  MSYS_NO_PATHCONV=1 timeout 60 "${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}" \
    --headless --path "$cel_engine" --script "$cel_probe" > "$cel_log" 2>&1 || cel_why="exit $?"
  cel_line="$(grep -a '^CEL_EXE_AA ok=true' "$cel_log" | tr -d '\r')"
  if [ -z "$cel_line" ] || grep -aEq 'SCRIPT ERROR|^ERROR:' "$cel_log"; then cel_why="see $cel_log"; fi
  verdict style.cel.exe_aa "$cel_why" "${cel_line#CEL_EXE_AA ok=true }"
fi
