extends SceneTree
## Lane LP (27 Nov, the Home look polished): the scene of the look captures, made headless with the real tools as a
## person drives them (land_drive.gd: B, T, the keys, the pointer, LMB held for frames) and the layers' own ops where a
## tool has no pointer path (a plant op of three big bands, two paths through path_grade.gd `lay`, a pour through
## water_layer.gd `pour_ops`), then saved as a Home build file that a windowed run loads (TL_HOME_BUILD_DIR). The build
## file holds the edits, not the drawing: the same file drawn by the code before and after a change gives before/after
## pictures from the same camera. Not a selftest: a capture helper.
##   godot --headless --fixed-fps 60 --path engine --script res://kernel/world/build/look_shots.gd -- --out=<abs dir>
## Prints `SHOT <name> start x,z,x2,z2 ...` (the TL_EXE_START of its picture: the visitor stands at x2,z2 looking away
## from x,z) and `SHOTS DONE`.
##   terrace   flatten (3), brush 5, 70 frames on the steepest free slope near (630, -430); seen from downhill, 18 m
##   growth    meadow | flowers | tall grass, three bands 15 m wide and 36 m deep, plain grass round them; seen from
##             10, 25 and 50 m before the bands' near edge
##   path      a stone path and a dirt path 14 m apart, the same curve, 3 m wide; seen from 7 m off their ends
##   shore     a hollow lowered (2), brush 4, 70 frames, then poured; seen from 14 m

const LandDrive := preload("res://kernel/world/build/land_drive.gd")
const CaseUtil := preload("res://kernel/world/build/case_util.gd")
const PathGrade := preload("res://kernel/world/build/path_grade.gd")

var d: RefCounted
var out := ""


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	call_deferred("run")


func run() -> void:
	if out == "":
		print("SHOTS fail: --out=<abs dir> is missing")
		quit(1)
		return
	d = LandDrive.new()
	var why: String = d.setup(self, "user://tl_look_shots")
	if why != "":
		print("SHOTS fail: " + why)
		quit(1)
		return
	var land: RefCounted = d.land
	var b: RefCounted = d.b
	var terrace: Vector2 = steep_site(Vector2(510, -574), 24.0)
	var growth: Vector2 = view_site(Vector2(420, -560))
	var path: Vector2 = d.free_site(Vector2(330, -470), 30.0)
	var shore: Vector2 = d.free_site(Vector2(520, -360), 18.0)
	await d.wait(3)
	await d.tap(KEY_B)
	# the terrace: flatten on a slope, brush 5
	await d.to_tool("sculpt")
	await d.set_radius(5)
	await d.tap(KEY_3)
	var gr := grad(terrace)
	var up := gr.normalized() if gr.length() > 0.001 else Vector2(0, -1)
	var h0 := [land.height_at(terrace.x, terrace.y), land.height_at(terrace.x + up.x * 12, terrace.y + up.y * 12), land.height_at(terrace.x - up.x * 12, terrace.y - up.y * 12)]
	await d.stroke(terrace, 70)
	print("SHOT terrace_heights tool %s reason %s before %s after %s" % [str(d.bm.call("tool").get("id")), str(d.bm.call("tool").get("reason")), str(h0), str([land.height_at(terrace.x, terrace.y), land.height_at(terrace.x + up.x * 12, terrace.y + up.y * 12), land.height_at(terrace.x - up.x * 12, terrace.y - up.y * 12)])])
	shot("terrace", terrace, up, 18.0)
	print("SHOT terrace_site at %s slope %.2f" % [str(terrace), gr.length()])
	# the shore: a hollow, then a pour into its middle
	await d.set_radius(4)
	await d.tap(KEY_2)
	await d.stroke(shore, 70)
	var w: RefCounted = b.layer("water")
	var po: Dictionary = w.pour_ops(d.vtx(shore))
	var pr: Dictionary = b.apply(po.ops) if str(po.reason) == "" else {"ok": false, "reason": po.reason}
	print("SHOT shore_pour %s cells %d reason '%s'" % [str(shore), w.size(), str(pr.get("reason", ""))])
	shot("shore", shore, Vector2(0.55, 0.83).normalized() * -1.0, 14.0)
	await d.tap(KEY_B)
	b.flush()
	# growth: three bands (meadow, flowers, tall grass), x across, z away from the camera (which looks north, -z)
	var c0: Vector2i = d.vtx(growth)
	var cells := []
	for j: int in range(-6, 6):
		for i: int in range(-7, 8):
			var kind: String = ["meadow", "flowers", "tall_grass"][clampi((i + 7) / 5, 0, 2)]
			cells.append([c0.x + i, c0.y + j, "valley", kind])
	var rg: Dictionary = b.apply({"op": "plant", "cells": cells, "author": "hand"})
	print("SHOT growth_op %s cells %d reason '%s'" % [str(growth), cells.size(), str(rg.reason)])
	var near_z: float = (c0.y + 6) * 3.0
	for dist: int in [10, 25, 50]:
		var a := Vector2(c0.x * 3.0 + 1.5, near_z + dist + 1.0)
		var bb := Vector2(c0.x * 3.0 + 1.5, near_z + dist)
		print("SHOT growth-%dm start %.1f,%.1f,%.1f,%.1f ground %.2f" % [dist, a.x, a.y, bb.x, bb.y, land.height_at(bb.x, bb.y)])
	# paths: stone and dirt, the same curve 14 m apart, running north from the camera
	var paths: RefCounted = b.layer("paths")
	for k: int in 2:
		var o := path + Vector2(-7.0 + 14.0 * k, 0.0)
		var pts := [o + Vector2(0, 0), o + Vector2(-3, -12), o + Vector2(1, -24), o + Vector2(6, -34)]
		var cm := []
		for q: Vector2 in pts:
			cm.append([roundi(q.x * 100.0), roundi(q.y * 100.0)])
		var op := {"op": "path", "id": paths.next_id(), "pts": cm, "width_cm": 300, "paint": ["stone", "dirt"][k]}
		var r: Dictionary = PathGrade.lay(b, op)
		print("SHOT path_%s ok %s reason '%s' graded %d" % [op.paint, str(r.ok), str(r.reason), int(r.graded)])
	var pa := path + Vector2(-7.0, 0.0)
	shot("path", pa, Vector2(-0.11, -1.0), 9.0)
	b.flush()
	var saved: String = b.save(out)
	print("SHOTS saved %s '%s' (%d land, %d paint, %d water)" % [out, saved, land.store.heights.size(), land.store.paints.size(), w.size()])
	d.release()
	CaseUtil.remove_dir(ProjectSettings.globalize_path("user://tl_look_shots"))
	print("SHOTS DONE")
	quit(0)


func grad(p: Vector2) -> Vector2:
	var land: RefCounted = d.land
	return Vector2(land.height_at(p.x + 3, p.y) - land.height_at(p.x - 3, p.y), land.height_at(p.x, p.y + 3) - land.height_at(p.x, p.y - 3)) / 6.0


## A spot for the growth bands seen from the south: the ground rises gently northward over the bands (1-5 m over
## their 36 m), the 60 m of approach south of them lies no higher than their near edge (nothing hides them), and every
## cell of the bands takes plant. The nearest such spot to `want` (sampled every 15 m, within 300 m).
func view_site(want: Vector2) -> Vector2:
	var land: RefCounted = d.land
	var best := want
	var best_d := INF
	for gz: int in range(-20, 21):
		for gx: int in range(-20, 21):
			var p := want + Vector2(gx, gz) * 15.0
			if p.distance_to(want) >= best_d:
				continue
			var near: float = land.height_at(p.x, p.y + 18.0)
			var rise: float = land.height_at(p.x, p.y - 18.0) - near
			if rise < 1.0 or rise > 5.0 or absf(land.height_at(p.x + 21.0, p.y) - land.height_at(p.x - 21.0, p.y)) > 2.0:
				continue
			var ok := true
			for k: int in range(1, 13):
				ok = ok and float(land.height_at(p.x, p.y + 18.0 + k * 5.0)) <= near + 0.3
			for j: int in range(-7, 7):
				for i: int in range(-8, 9):
					ok = ok and land.refusal(d.vtx(p) + Vector2i(i, j), "plant") == ""
			if ok:
				best = p
				best_d = p.distance_to(want)
	d.home.ensure(best)
	print("SHOT growth_site %s rise %.2f" % [str(best), land.height_at(best.x, best.y - 18.0) - land.height_at(best.x, best.y + 18.0)])
	return best


## The free spot nearest to `want` (sampled every 12 m, within 150 m) whose ground slopes 0.28-0.42 (a hillside a
## person would cut a terrace into, under the valley's steep ridge) and whose vertices within `r` m take land.
func steep_site(want: Vector2, r: float) -> Vector2:
	var best := want
	var best_s := INF
	var land: RefCounted = d.land
	for gz: int in range(-12, 13):
		for gx: int in range(-12, 13):
			var p := want + Vector2(gx, gz) * 12.0
			var s := grad(p).length()
			if s < 0.28 or s > 0.42 or p.distance_to(want) >= best_s:
				continue
			var ok := true
			for j: int in range(-ceili(r / 3), ceili(r / 3) + 1):
				for i: int in range(-ceili(r / 3), ceili(r / 3) + 1):
					ok = ok and land.refusal(d.vtx(p) + Vector2i(i, j), "land") == ""
			if ok:
				best = p
				best_s = p.distance_to(want)
	d.home.ensure(best)
	return best


## The TL_EXE_START of a picture of `p` from `dist` m along `dir` (from the spot toward `p`).
func shot(name: String, p: Vector2, dir: Vector2, dist: float) -> void:
	var dd := dir.normalized()
	var a := p - dd * (dist + 1.0)
	var bb := p - dd * dist
	print("SHOT %s start %.1f,%.1f,%.1f,%.1f ground %.2f" % [name, a.x, a.y, bb.x, bb.y, d.land.height_at(p.x, p.y)])
