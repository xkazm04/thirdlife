# Reinstall a single look on a live viewport. Each budget switch must remove only its own feature.
if [[ -z "$FILTER" || "style.diorama.frame_switches" == *"$FILTER"* ]]; then
  frame_script="$OUT/frame_switches_624.gd"
  cat > "$frame_script" <<'GDSCRIPT'
extends SceneTree

func _initialize() -> void:
	call_deferred("check")

func check() -> void:
	var host := Node3D.new()
	root.add_child(host)
	root.anisotropic_filtering_level = Viewport.ANISOTROPY_4X
	TLStyle.load_style("res://style/style_diorama.json")
	var authored := TLStyle.data.duplicate(true)
	var ok := true
	for feature: String in ["all", "horizon_aa", "anisotropy_16x", "print_contrast", "quality_sky_bake", "soft_shadows", "all"]:
		TLStyle.data = authored.duplicate(true)
		match feature:
			"horizon_aa", "anisotropy_16x", "quality_sky_bake": TLStyle.data.env[feature] = false
			"soft_shadows": TLStyle.data.sun.soft_shadows = false
			"print_contrast": TLStyle.data.grade.print_contrast = 0.0
		TLStyle.install(host)
		var rig := host.get_node("TLStyleRig")
		var we := rig.get_node("WorldEnvironment") as WorldEnvironment
		var sky := we.environment.sky
		var sun := rig.get_node("Sun") as DirectionalLight3D
		var grade: ShaderMaterial = rig.get_node("Grade/Rect").material
		var checks := [
			(we.compositor != null) == (feature != "horizon_aa"),
			root.anisotropic_filtering_level == (Viewport.ANISOTROPY_4X if feature == "anisotropy_16x" else Viewport.ANISOTROPY_16X),
			(grade.shader == preload("res://style/shaders/grade.gdshader")) == (feature == "print_contrast"),
			sky.radiance_size == (Sky.RADIANCE_SIZE_256 if feature == "quality_sky_bake" else Sky.RADIANCE_SIZE_512),
			sky.process_mode == (Sky.PROCESS_MODE_AUTOMATIC if feature == "quality_sky_bake" else Sky.PROCESS_MODE_QUALITY),
			sky.sky_material.shader == preload("res://style/shaders/sky_cotton.gdshader"),
			sun.shadow_enabled,
			is_equal_approx(sun.light_angular_distance, 0.0 if feature == "soft_shadows" else float(authored.sun.angular_size)),
			is_equal_approx(sun.shadow_blur, 0.0 if feature == "soft_shadows" else float(authored.sun.shadow_blur))]
		if checks.has(false):
			print("FAIL switch ", feature, " ", checks)
			ok = false
	print("FRAME624 ", "ok" if ok else "FAIL")
	host.free()
	quit(0 if ok else 1)
GDSCRIPT
  frame_log="$OUT/frame_switches_624.log"
  frame_error=""
  frame_engine="$(cd "$HERE/.." && pwd)"
  if command -v cygpath >/dev/null 2>&1; then
    frame_engine="$(cygpath -m "$frame_engine")"
    frame_script="$(cygpath -m "$frame_script")"
  fi
  (cd "$HERE/../.." && MSYS_NO_PATHCONV=1 TL_STYLE=diorama TL_EXE_AA= node --input-type=module - "$frame_engine" "$frame_script" <<'NODE'
import { spawnSync } from "node:child_process";
import { withWindowLock } from "./devx/lib/perf/scenarios.mjs";
const [engine, script] = process.argv.slice(2);
const run = () => spawnSync(process.env.TL_GODOT || "C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe",
  ["--windowed", "--position", process.env.TL_WINDOW_POS || "0,1440", "--resolution", "640x360", "--audio-driver", "Dummy",
   "--path", engine, "--script", script, "--quit-after", "120"], {stdio:"inherit", timeout:120000});
const r = process.env.TL_WINDOW_LOCK === "off" ? run() : withWindowLock(run);
process.exitCode = r.status ?? 1;
NODE
  ) > "$frame_log" 2>&1 || frame_error="Godot failed"
  if ! grep -aq '^FRAME624 ok' "$frame_log" || grep -aEq 'SCRIPT ERROR|SHADER ERROR|^ERROR:' "$frame_log"; then frame_error="see $frame_log"; fi
  verdict style.diorama.frame_switches "$frame_error" "five independent switches, including live restoration"
fi
