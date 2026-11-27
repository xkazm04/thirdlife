extends SceneTree
## Lane LP (27 Nov, the Home look polished): what the polished looks hand the shaders, headless, in the landscape of
## res://boot/village.json with the tools and the layers' own ops (land_drive.gd). Prints `HOME look2.<case> ok|fail
## <detail>`, then `HOME look2 ok` (or fail) and `HOME DONE`; engine/tools/selftest.d/768-home-look2.sh reads them.
##   look2.growth  three bands planted (meadow, flowers, tall grass): at each band's middle the land mesh's UV carries a
##                 density the cel shader shows (max(2.2 tufts, flowers) over 0.5) and a flowers / tufts ratio it cuts
##                 into its own kind (toon_cel.gdshader: tall under 0.31, flowers over 1.6, the meadow between)
##   look2.stone   a stone path and a dirt path on the same curve: every vertex of the stone ribbon carries its own
##                 coordinates in UV2 (y under -500; along growing from the first point; across within the ribbon), the
##                 dirt ribbon none; both draw the same earth field (the width where the colour is half way to the earth
##                 paint, section by section, within 0.15 m), and past the first point it rounds off: each section's width
##                 within 0.2 m of the half disc's chord (a square end would keep the whole width)
##   look2.shore   a pond poured in a hollow: every vertex carries a bank depth (UV.x - (-10), -2..2 m); the triangles
##                 the waterline (bank depth 0) runs through have no side over 1.1 m (squares of 0.75 m) (the land's polygon: 3-4.2 m); where
##                 the bank depth is over 0 the drawn land is under the water (the curve lies inside: the land hides
##                 nothing it should not), at least 97 % of such vertices; the chunk mesh's time

const Drive := preload("res://kernel/world/build/land_drive.gd")
const PathGrade := preload("res://kernel/world/build/path_grade.gd")
const TMP := "user://tl_look2_case"

var d: RefCounted = Drive.new()
var ok_all := true


func _initialize() -> void:
	call_deferred("run")


func say(name: String, ok: bool, detail: String) -> void:
	ok_all = ok_all and ok
	print("HOME look2.%s %s %s" % [name, "ok" if ok else "fail", detail])


func run() -> void:
	var why: String = d.setup(self, TMP)
	if why != "":
		say("growth", false, why)
		finish()
		return
	await d.wait(3)
	await d.tap(KEY_B)
	growth_case()
	stone_case()
	await shore_case()
	finish()


func finish() -> void:
	Drive.CaseUtil.remove_dir(ProjectSettings.globalize_path(TMP))
	d.release()
	print("HOME look2 %s" % ("ok" if ok_all else "fail"))
	print("HOME DONE")
	quit(0)


func growth_case() -> void:
	var b: RefCounted = d.b
	var land: RefCounted = d.land
	var site: Vector2 = d.free_site(Vector2(420, -560), 30.0)
	var c0: Vector2i = d.vtx(site)
	var cells := []
	var kinds := ["meadow", "flowers", "tall_grass"]
	for j: int in range(-6, 6):
		for i: int in range(-7, 8):
			cells.append([c0.x + i, c0.y + j, "valley", kinds[clampi((i + 7) / 5, 0, 2)]])
	var r: Dictionary = b.apply({"op": "plant", "cells": cells, "author": "hand"})
	b.flush()
	var parts := []
	var ok: bool = bool(r.ok)
	for k: int in 3:
		var mid := Vector2((c0.x - 5 + 5 * k) * 3.0, (c0.y - 0.5) * 3.0)
		var sum := Vector2.ZERO
		var n := 0
		for id: Vector2i in land.mesh.chunks:
			var s: Dictionary = land.mesh.chunks[id]
			var pos: PackedVector3Array = s.pos
			var uv: PackedVector2Array = s.uv
			for vi: int in pos.size():
				if absf(pos[vi].x - mid.x) <= 3.1 and absf(pos[vi].z - mid.y) <= 6.1:
					sum += Vector2(clampf(uv[vi].x, 0.0, 1.0), clampf(-8.0 - uv[vi].y, 0.0, 1.0)) if uv[vi].y < -7.5 else Vector2.ZERO
					n += 1
		var t := sum.x / maxf(n, 1)
		var f := sum.y / maxf(n, 1)
		var gv := maxf(t * 2.2, f)
		var ratio := f / maxf(t, 1e-3)
		var cut := "tall" if ratio < 0.31 else ("flowers" if ratio > 1.6 else "meadow")
		var want: String = ["meadow", "flowers", "tall"][k]
		ok = ok and n >= 9 and gv > 0.5 and cut == want
		parts.append("%s: %d vertices, tufts %.2f flowers %.2f, shown %.2f, ratio %.2f -> %s" % [kinds[k], n, t, f, gv, ratio, cut])
	say("growth", ok, "a plant op of %d cells ('%s'): %s" % [cells.size(), str(r.get("reason", "")), "; ".join(parts)])
	b.undo()
	b.flush()


func stone_case() -> void:
	var b: RefCounted = d.b
	var paths: RefCounted = b.layer("paths")
	var site: Vector2 = d.free_site(Vector2(330, -470), 30.0)
	var ids := []
	var firsts := []
	for k: int in 2:
		var o := site + Vector2(-7.0 + 14.0 * k, 0.0)
		var pts := [o, o + Vector2(-3, -12), o + Vector2(1, -24), o + Vector2(6, -34)]
		var cm := []
		for q: Vector2 in pts:
			cm.append([roundi(q.x * 100.0), roundi(q.y * 100.0)])
		var op := {"op": "path", "id": paths.next_id(), "pts": cm, "width_cm": 300, "paint": ["stone", "dirt"][k]}
		var r: Dictionary = PathGrade.lay(b, op)
		if not bool(r.ok):
			say("stone", false, "laying the %s path: '%s'" % [op.paint, str(r.reason)])
			return
		ids.append(int(op.id))
		firsts.append([pts[0], ((pts[1] as Vector2) - (pts[0] as Vector2)).normalized()])
	b.flush()
	var mesher: RefCounted = paths._mesher()
	var prof := []                           # per path: {along (dm, rounded) -> width}
	var uv2_ok := [true, true]
	var uv2_n := [0, 0]
	var along_up := true
	var across_max := 0.0
	var mid_w := [0.0, 0.0]
	for k: int in 2:
		var id: int = ids[k]
		var inf: Dictionary = paths.info[id]
		var nr := (inf.rows as PackedFloat32Array).size()
		var o: Vector2 = firsts[k][0]
		var dir: Vector2 = firsts[k][1]
		var widths := {}
		var mids := []
		for c: Vector2i in paths.by_chunk:
			if not (paths.by_chunk[c] as Dictionary).has(id):
				continue
			var a: Dictionary = mesher.chunk_arrays(c, [id], paths.info, paths.index)
			var t: Dictionary = a.terrain
			if t.is_empty():
				continue
			var pos: PackedVector3Array = t.pos
			var col: PackedColorArray = t.col
			var uv2: PackedVector2Array = t.uv2
			for s0: int in range(0, pos.size() - nr + 1, nr):
				var fs := PackedFloat32Array()
				for rr: int in nr:
					var p := pos[s0 + rr]
					var ga: Array = mesher.ground_at(p.x, p.z)
					var gc: Color = ga[1]
					var ec: Color = mesher.g.pigment("dirt", p.x, p.z)
					var dv := Vector3(ec.r - gc.r, ec.g - gc.g, ec.b - gc.b)
					fs.append(Vector3(col[s0 + rr].r - gc.r, col[s0 + rr].g - gc.g, col[s0 + rr].b - gc.b).dot(dv) / maxf(dv.length_squared(), 1e-6))
					uv2_n[k] += 1
					if k == 0:
						uv2_ok[0] = uv2_ok[0] and uv2[s0 + rr].y < -500.0
						across_max = maxf(across_max, absf(-1000.0 - uv2[s0 + rr].y))
						if rr > 0:
							along_up = along_up and absf(uv2[s0 + rr].x - uv2[s0].x) < 1e-4
					else:
						uv2_ok[1] = uv2_ok[1] and uv2[s0 + rr] == Vector2.ZERO
				# the width where f crosses 0.5, from the rows (linear between two rows)
				var cross := []
				for rr: int in nr - 1:
					if (fs[rr] - 0.5) * (fs[rr + 1] - 0.5) < 0.0:
						var u := (0.5 - fs[rr]) / (fs[rr + 1] - fs[rr])
						cross.append(pos[s0 + rr].lerp(pos[s0 + rr + 1], u))
				var centre := (pos[s0] + pos[s0 + nr - 1]) * 0.5
				var al := (Vector2(centre.x, centre.z) - o).dot(dir)
				var w := 0.0
				if cross.size() >= 2:
					w = Vector2((cross[0] as Vector3).x - (cross[-1] as Vector3).x, (cross[0] as Vector3).z - (cross[-1] as Vector3).z).length()
				widths[roundi(al * 10.0)] = w
				if al > 8.0 and al < 20.0:
					mids.append(w)
		mids.sort()
		mid_w[k] = mids[mids.size() / 2] if not mids.is_empty() else 0.0
		prof.append(widths)
	var half: float = mid_w[0] * 0.5
	# past the first point (along < 0) the field is a half disc of the half-width: each section's width is the chord
	# 2 sqrt(half^2 - d^2) (a square end would keep the whole width)
	var round_n := 0
	var round_worst := 0.0
	for key: int in prof[0]:
		var dd := -key / 10.0
		if dd < 0.3 * half:
			continue
		var chord := 2.0 * sqrt(maxf(half * half - dd * dd, 0.0))
		round_worst = maxf(round_worst, absf(float(prof[0][key]) - chord))
		round_n += 1
	var worst := 0.0
	var same_n := 0
	for key: int in prof[0]:
		if (prof[1] as Dictionary).has(key):
			worst = maxf(worst, absf(float(prof[0][key]) - float(prof[1][key])))
			same_n += 1
	var ok: bool = uv2_ok[0] and uv2_ok[1] and along_up and uv2_n[0] > 0 and across_max <= half + 2.0 and mid_w[0] > 2.0 \
		and round_n >= 1 and round_worst <= 0.2 \
		and same_n >= 10 and worst <= 0.15
	var ends := []
	var ks: Array = (prof[0] as Dictionary).keys()
	ks.sort()
	for key: int in ks:
		if key < 5:
			ends.append("%.1f:%.2f" % [key / 10.0, prof[0][key]])
	say("stone", ok, "the stone end's sections (along: width) %s; stone ribbon: %d vertices, UV2 the path's own %s (across up to %.2f m; one along per section %s), dirt ribbon %d vertices UV2 zero %s; the earth field's width at the middle %.2f m (dirt %.2f); past the first point %d section(s) 0.3 of the half-width or more out, off the half disc's chord by at most %.2f m; stone vs dirt over %d sections: worst %.3f m" % [
		" ".join(ends), uv2_n[0], uv2_ok[0], across_max, along_up, uv2_n[1], uv2_ok[1], mid_w[0], mid_w[1], round_n, round_worst, same_n, worst])


func shore_case() -> void:
	var b: RefCounted = d.b
	var land: RefCounted = d.land
	var w: RefCounted = b.layer("water")
	var site: Vector2 = d.free_site(Vector2(520, -360), 18.0)
	await d.to_tool("sculpt")
	await d.set_radius(4)
	await d.tap(KEY_2)
	await d.stroke(site, 70)
	var po: Dictionary = w.pour_ops(d.vtx(site))
	if str(po.reason) != "":
		say("shore", false, "pour: '%s'" % po.reason)
		return
	b.apply(po.ops)
	b.flush()
	var level := 0.0
	for c: Vector2i in w.store.levels:
		level = int(w.store.levels[c]) / 100.0
	var n_v := 0
	var uv_ok := true
	var line_tris := 0
	var longest := 0.0
	var wet_v := 0
	var wet_under := 0
	var bad := []
	for ch: Vector2i in w.mesh.nodes:
		var mi: MeshInstance3D = w.mesh.nodes[ch]
		for si: int in mi.mesh.get_surface_count():
			var arr: Array = mi.mesh.surface_get_arrays(si)
			var pos: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
			var idx: Variant = arr[Mesh.ARRAY_INDEX]
			var tri_n: int = (idx as PackedInt32Array).size() if idx != null else pos.size()
			for vi: int in pos.size():
				n_v += 1
				uv_ok = uv_ok and uv[vi].x >= -12.0 and uv[vi].x <= -8.0
				if uv[vi].x + 10.0 > 0.0:
					wet_v += 1
					var gy: float = land.drawn_height_at(pos[vi].x, pos[vi].z)
					if gy < pos[vi].y + 0.02:
						wet_under += 1
					elif bad.size() < 3:
						bad.append("%s bank %.2f land %.2f" % [str(pos[vi]), uv[vi].x + 10.0, gy])
			for t: int in range(0, tri_n, 3):
				var ks := [t, t + 1, t + 2]
				if idx != null:
					ks = [(idx as PackedInt32Array)[t], (idx as PackedInt32Array)[t + 1], (idx as PackedInt32Array)[t + 2]]
				var lo := 1e9
				var hi := -1e9
				for k: int in ks:
					lo = minf(lo, uv[k].x + 10.0)
					hi = maxf(hi, uv[k].x + 10.0)
				if lo <= 0.0 and hi > 0.0:
					line_tris += 1
					for e: int in 3:
						longest = maxf(longest, pos[ks[e]].distance_to(pos[ks[(e + 1) % 3]]))
	var usec: Array = w.mesh.stats.usec.duplicate()
	usec.sort()
	var share := float(wet_under) / maxf(wet_v, 1)
	var ok: bool = w.size() > 0 and n_v > 0 and uv_ok and line_tris >= 12 and longest <= 1.1 and share >= 0.97
	say("shore", ok, "a pond of %d cells at %.2f m: %d vertices, bank depth in UV.x %s; %d triangles carry the waterline, their longest side %.2f m (the land's lattice: 3-4.24 m); of %d vertices with water over the bank, %d (%.1f %%) over the drawn land%s; chunk mesh draws %d, median %.2f ms, max %.2f ms" % [
		w.size(), level, n_v, uv_ok, line_tris, longest, wet_v, wet_under, share * 100.0, "" if bad.is_empty() else " (NOT " + "; ".join(bad) + ")",
		usec.size(), (usec[usec.size() / 2] / 1000.0) if not usec.is_empty() else 0.0, (usec[-1] / 1000.0) if not usec.is_empty() else 0.0])
	b.undo()
	b.undo()
	b.flush()
