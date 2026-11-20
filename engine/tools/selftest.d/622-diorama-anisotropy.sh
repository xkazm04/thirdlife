# Exercise the viewport setup used by install(), including two independent live previews.
if [[ -z "$FILTER" || "style.diorama.anisotropy" == *"$FILTER"* ]]; then
  aniso_script="$OUT/aniso_622.gd"
  cat > "$aniso_script" <<'GDSCRIPT'
extends SceneTree

func _initialize() -> void:
	call_deferred("check")

func check() -> void:
	var a := SubViewport.new()
	var b := SubViewport.new()
	root.add_child(a)
	root.add_child(b)
	a.anisotropic_filtering_level = Viewport.ANISOTROPY_2X
	b.anisotropic_filtering_level = Viewport.ANISOTROPY_8X
	var ok := TLStyle.load_style("res://style/style.json").is_empty()
	TLStyle._apply_view(a)
	ok = ok and a.anisotropic_filtering_level == Viewport.ANISOTROPY_2X
	ok = TLStyle.load_style("res://style/style_diorama.json").is_empty() and ok
	TLStyle._apply_view(a)
	TLStyle._apply_view(a)
	ok = ok and a.anisotropic_filtering_level == Viewport.ANISOTROPY_16X
	ok = ok and b.anisotropic_filtering_level == Viewport.ANISOTROPY_8X
	TLStyle._apply_view(b)
	ok = ok and b.anisotropic_filtering_level == Viewport.ANISOTROPY_16X
	ok = TLStyle.load_style("res://style/style.json").is_empty() and ok
	TLStyle._apply_view(b)
	TLStyle._apply_view(a)
	ok = ok and a.anisotropic_filtering_level == Viewport.ANISOTROPY_2X
	ok = ok and b.anisotropic_filtering_level == Viewport.ANISOTROPY_8X
	print("ANISO622 ", "ok" if ok else "FAIL")
	a.free()
	b.free()
	quit(0 if ok else 1)
GDSCRIPT
  aniso_engine="$(cd "$HERE/.." && pwd)"
  if command -v cygpath >/dev/null 2>&1; then
    aniso_engine="$(cygpath -m "$aniso_engine")"
    aniso_script="$(cygpath -m "$aniso_script")"
  fi
  aniso_log="$OUT/aniso_622.log"
  aniso_error=""
  MSYS_NO_PATHCONV=1 "${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}" \
    --headless --path "$aniso_engine" --script "$aniso_script" --quit-after 120 > "$aniso_log" 2>&1 || aniso_error="Godot failed"
  if ! grep -aq '^ANISO622 ok' "$aniso_log" || grep -aEq 'SCRIPT ERROR|^ERROR:' "$aniso_log"; then aniso_error="see $aniso_log"; fi
  verdict style.diorama.anisotropy "$aniso_error" "16x in both diorama views, original 2x and 8x restored"
fi
