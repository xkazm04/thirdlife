extends RefCounted
## M6 round 3, lane A6: the `assembly.tool` case of assembly_case.gd (selftest 794): build mode headless with no
## landscape, driven as the other tool cases drive it (B, T round the strip, the tool's keys, the host's `hit` set to a
## cell as a pick would). The Shapes tool: 2 (tower), ] (inside stairs), the wheel up 3 (height 13), a press at one
## corner, a drag to the other (the ghost a dry run of exactly that assemble), release: ONE batch equal to the expansion
## of the same assemble through home_build.gd `expand_input` (what an LLM's assemble builds); Ctrl+Z empties it.

const HomeBuild := preload("res://kernel/world/build/home_build.gd")
const BuildMode := preload("res://kernel/world/build/build_mode.gd")
const CaseUtil := preload("res://kernel/world/build/case_util.gd")

var tree: SceneTree


func wait(n: int) -> void:
	for i in n:
		await tree.physics_frame


func tap(k: Key, ctrl := false) -> void:
	if ctrl:
		CaseUtil.key(KEY_CTRL, true)
	CaseUtil.key(k, true)
	await wait(2)
	CaseUtil.key(k, false)
	if ctrl:
		CaseUtil.key(KEY_CTRL, false)
	await wait(2)


func hit_at(c: Vector3i) -> Dictionary:
	return {"pos": Vector3(c.x + 0.5, c.y, c.z + 0.5), "normal": Vector3.UP, "block": false, "place": c, "remove": HomeBuild.NO_CELL}


func run(t: SceneTree) -> void:
	tree = t
	var b: RefCounted = HomeBuild.new(null, null, {})
	var bm: Node = BuildMode.new()
	bm.set("build", b)
	t.root.add_child(bm)
	await wait(2)
	await tap(KEY_B)
	var seen := []
	for i in 16:
		if str(bm.call("tool").get("id")) == "shapes":
			break
		await tap(KEY_T)
		seen.append(str(bm.call("tool").get("id")))
	var tool: RefCounted = bm.call("tool")
	var bad := []
	if str(tool.get("id")) != "shapes":
		t.call("say", "tool", false, "no Shapes tool on the strip: %s" % str(seen))
		bm.queue_free()
		return
	await tap(KEY_2)
	await tap(KEY_BRACKETRIGHT)
	for i in 3:
		var w := InputEventMouseButton.new()
		w.button_index = MOUSE_BUTTON_WHEEL_UP
		w.pressed = true
		tool.key(w)
	var info0 := str(tool.call("status").info)
	# hover: the ghost first, nothing built
	var a := Vector3i(10, 0, 10)
	bm.set("hit", hit_at(a))
	tool.aim(hit_at(a), {})
	var ghost_hover: Node3D = tool.get("preview")
	var hover_shown := ghost_hover != null and ghost_hover.visible
	# press, drag to the far corner, the ghost follows; release builds
	var n0: int = (b.edits.history as Array).size()
	tool.press(MOUSE_BUTTON_LEFT, {})
	tool.drag(hit_at(Vector3i(16, 3, 18)))
	var op: Dictionary = tool.call("op_now")
	var ghost_total := 0
	var pv: Node3D = tool.get("preview")
	var want: Dictionary = b.expand_input([op])
	var dry: Dictionary = b.preview(want.ops)
	ghost_total = int((dry.store as RefCounted).get("total"))
	var ghost_drawn: bool = pv != null and pv.visible and int(pv.call("stats").tris) > 0
	var blocks_before: int = int(b.blocks.total)
	tool.release(MOUSE_BUTTON_LEFT)
	await wait(2)
	var batches: int = (b.edits.history as Array).size() - n0
	var built := {}
	for o: Dictionary in want.ops:
		built[Vector3i(int(o.at[0]), int(o.at[1]), int(o.at[2]))] = HomeBuild.code(int(o.shape), int(o.mat), int(o.rot))
	var same := int(b.blocks.total) == built.size()
	for c: Vector3i in built:
		if b.code_at(c) != int(built[c]):
			same = false
			break
	var total := int(b.blocks.total)
	await tap(KEY_Z, true)
	var after_undo := int(b.blocks.total)
	var want_op := {"kind": "tower", "size": [7, 13, 1], "opts": {"stairs": "inside", "crenels": true, "windows": 3}}
	for k: String in want_op:
		if str(op.get(k)) != str(want_op[k]):
			bad.append("%s %s (want %s)" % [k, str(op.get(k)), str(want_op[k])])
	var ok: bool = hover_shown and blocks_before == 0 and ghost_drawn and batches == 1 and same and total == ghost_total and total > 0 \
		and after_undo == 0 and int(tool.get("last").get("refused", -1)) == 0 and bad.is_empty() and info0.contains("tower 7 x 13")
	t.call("say", "tool", ok, "strip %s; '%s'; hover ghost %s; drag (10,0,10)-(16,3,18): %s; ghost %d blocks drawn %s; release: %d batch, %d blocks = the expand_input of the same assemble %s; Ctrl+Z -> %d%s" % [
		" > ".join(PackedStringArray(seen)), info0, hover_shown, JSON.stringify(op), ghost_total, ghost_drawn, batches, total, same, after_undo,
		"" if bad.is_empty() else "; BAD " + "; ".join(PackedStringArray(bad))])
	await tap(KEY_B)
	bm.queue_free()
	await wait(2)
