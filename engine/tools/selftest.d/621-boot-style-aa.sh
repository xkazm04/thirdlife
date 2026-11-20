# Exercise the boot window's frame-two AA choice with the actual style data.
if [[ -z "$FILTER" || "style.boot.aa" == *"$FILTER"* ]]; then
  boot_aa_case="$OUT/boot_aa_621.gd"
  cat > "$boot_aa_case" <<'GDSCRIPT'
extends SceneTree

class Boot extends "res://boot/boot.gd":
	var stage := -1
	func _ready() -> void:
		view = self
		set_physics_process(false)

func _initialize() -> void:
	call_deferred("check")

func sample(override_spec: String) -> Array:
	OS.set_environment("TL_EXE_AA", override_spec)
	root.msaa_3d = Viewport.MSAA_DISABLED
	root.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	root.use_taa = false
	var boot := Boot.new()
	root.add_child(boot)
	boot._physics_process(1.0 / 60.0)
	boot._physics_process(1.0 / 60.0)
	boot.free()
	return [root.msaa_3d, root.screen_space_aa, root.use_taa]

func check() -> void:
	var diorama := sample("")
	var explicit := sample("msaa=8,ss=off,taa=1")
	var issues := TLStyle.load_style("res://style/style.json")
	var classic := sample("")
	var ok := issues.is_empty() and diorama == [Viewport.MSAA_4X, Viewport.SCREEN_SPACE_AA_SMAA, false]
	ok = ok and explicit == [Viewport.MSAA_8X, Viewport.SCREEN_SPACE_AA_DISABLED, true]
	# The historic fallback only sets MSAA and TAA. It preserves the installed screen-space mode.
	ok = ok and classic == [Viewport.MSAA_2X, Viewport.SCREEN_SPACE_AA_FXAA, true]
	print("BOOT_AA_621 ", "ok" if ok else "FAIL", " diorama=", diorama, " override=", explicit, " classic=", classic)
	quit(0 if ok else 1)
GDSCRIPT
  boot_aa_engine="$(cd "$HERE/.." && pwd)"
  if command -v cygpath >/dev/null 2>&1; then
    boot_aa_engine="$(cygpath -m "$boot_aa_engine")"
    boot_aa_case="$(cygpath -m "$boot_aa_case")"
  fi
  boot_aa_log="$OUT/boot_aa_621.log"
  boot_aa_error=""
  boot_aa_godot="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  MSYS_NO_PATHCONV=1 TL_STYLE=diorama "$boot_aa_godot" --headless --path "$boot_aa_engine" \
    --script "$boot_aa_case" --quit-after 120 > "$boot_aa_log" 2>&1 || boot_aa_error="engine run failed"
  boot_aa_line="$(grep -a '^BOOT_AA_621 ok ' "$boot_aa_log" | tr -d '\r')"
  if [ -z "$boot_aa_line" ] || grep -aqE 'SCRIPT ERROR|^ERROR:' "$boot_aa_log"; then boot_aa_error="see $boot_aa_log"; fi
  verdict style.boot.aa "$boot_aa_error" "${boot_aa_line#BOOT_AA_621 ok }"
fi
