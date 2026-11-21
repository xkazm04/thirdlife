extends RefCounted
## K8 feel kit (lane N1, night of 22 Nov 2026): the play camera's occluder fade, owned by TLCameras (ctx.cameras), on
## with `ctx.cameras.fade_occluders(true, opts)`. Every physics frame it casts rays in the pack's own physics space from
## the camera to three points on each subject (feet + 0.3 m, middle, head); a static or dynamic body in the way (not a
## biped, not a ball) is an occluder, and the meshes of its kit part fade to `alpha` over `frames` frames through
## GeometryInstance3D.transparency (the style's own material, drawn in the transparent pass; shadows stay). When it no
## longer blocks, they come back over the same frames. A mesh larger than `max_size` (the ground, a layout's merged
## statics, a terrain sheet) never fades. Drawing only: no simulation state is read back or written, no clock, no random
## numbers, so the state hash is the same with the fade on or off.

const OPTIONS: Array = ["view", "subjects", "alpha", "frames", "max_size"]
const RAYS: int = 4                    # occluders found per ray at most

var on: bool = false
var view: StringName = &""             # &"" = the active view
var subjects: Array = []               # [] = the view's subject (ctx.cameras.frame / set_subject)
var alpha: float = 0.3                 # what remains of a faded mesh (0 = gone, 1 = no fade)
var frames: int = 8
var max_size: float = 12.0
var _fading: Dictionary = {}           # GeometryInstance3D -> [its own transparency, the fade now 0..1]
var _blocking: Array = []              # the occluding bodies found in the last frame


func configure(on_: bool, opts: Dictionary) -> void:
	for k: Variant in opts.keys():
		if not OPTIONS.has(str(k)):
			push_error("ctx.cameras.fade_occluders: unknown option '%s' (options: %s)" % [k, ", ".join(PackedStringArray(OPTIONS))])
	on = on_
	view = StringName(str(opts.get("view", "")))
	subjects = (opts["subjects"] as Array).duplicate() if opts.get("subjects") is Array else []
	alpha = clampf(float(opts.get("alpha", 0.3)), 0.0, 1.0)
	frames = maxi(1, int(opts.get("frames", 8)))
	max_size = maxf(0.5, float(opts.get("max_size", 12.0)))


func blocking() -> Array:
	return _blocking.duplicate()


func tick(cam: Camera3D, fallback: Node3D, ctx: TLContext) -> void:
	var want: Dictionary = {}
	_blocking.clear()
	if on and cam != null and cam.is_inside_tree():
		var list: Array = subjects if not subjects.is_empty() else ([fallback] if fallback != null else [])
		for s: Variant in list:
			if s is Node3D and is_instance_valid(s) and (s as Node3D).is_inside_tree():
				_cast(cam, s as Node3D, ctx, want)
	var step := 1.0 / float(frames)
	for g: Variant in want.keys():
		if not _fading.has(g):
			_fading[g] = [(g as GeometryInstance3D).transparency, 0.0]
	for g: Variant in _fading.keys():
		var e: Array = _fading[g]
		if not is_instance_valid(g):
			_fading.erase(g)
			continue
		e[1] = minf(1.0, float(e[1]) + step) if want.has(g) else maxf(0.0, float(e[1]) - step)
		var gi: GeometryInstance3D = g
		gi.transparency = lerpf(float(e[0]), maxf(float(e[0]), 1.0 - alpha), smoothstep(0.0, 1.0, float(e[1])))
		if float(e[1]) <= 0.0:
			gi.transparency = float(e[0])
			_fading.erase(g)


func _cast(cam: Camera3D, subject: Node3D, ctx: TLContext, want: Dictionary) -> void:
	var space := TLContext.space_state_of(subject, ctx)
	var from := cam.global_position
	var tall := 1.8
	if subject is TLBiped:
		tall = (subject as TLBiped).body_radius() * 6.0
	var skip: Array[RID] = []
	if subject is CollisionObject3D:
		skip.append((subject as CollisionObject3D).get_rid())
	for h: float in [0.3, tall * 0.55, tall * 0.92]:
		var to := subject.global_position + Vector3.UP * h
		var ex: Array[RID] = skip.duplicate()
		for i: int in RAYS:
			var q := PhysicsRayQueryParameters3D.create(from, to)
			q.exclude = ex
			var hit: Dictionary = space.intersect_ray(q)
			if hit.is_empty():
				break
			var body: Object = hit.get("collider")
			ex.append(hit.get("rid"))
			if body is CharacterBody3D or body is TLBall or not (body is StaticBody3D or body is RigidBody3D):
				continue
			if not _blocking.has(body):
				_blocking.append(body)
			for g: GeometryInstance3D in _meshes(body as Node3D, ctx):
				want[g] = true


## The meshes of a body's kit part: its own (TLBodies.make puts the mesh under the body), else those beside it under its
## part (a kit part keeps MeshInstance3D and StaticBody3D children side by side). Never the pack's root, never a mesh
## larger than max_size, never a mesh under another physics body (a biped, a ball).
func _meshes(body: Node3D, ctx: TLContext) -> Array:
	var out: Array = []
	_gather(body, out, body)
	if out.is_empty():
		var part := body.get_parent() as Node3D
		if part != null and (ctx == null or part != ctx.root) and not part.has_meta(&"tl_ctx"):
			_gather(part, out, part)
	return out


func _gather(n: Node, out: Array, top: Node) -> void:
	if n != top and (n is CharacterBody3D or n is TLBall):
		return
	if n is GeometryInstance3D and (n as GeometryInstance3D).visible:
		var bb: AABB = (n as GeometryInstance3D).get_aabb()
		var size := ((n as Node3D).global_transform.basis * bb.size).abs()
		if maxf(size.x, maxf(size.y, size.z)) <= max_size:
			out.append(n)
	for c: Node in n.get_children():
		_gather(c, out, top)
