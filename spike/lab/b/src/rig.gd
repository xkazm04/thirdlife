class_name Rig
extends RefCounted
## Shared rig helpers: a Skeleton3D from a bone table, and Animation clips sampled from a pose function.
## Bones have identity rest rotation (only offsets), so a pose is just per-bone euler degrees:
##   +x swings a hanging limb FORWARD (-Z), -x backward / bends a knee; +y turns left... (right-hand rule, Y up).
## A pose function returns {BoneName: Vector3(deg)} plus optional "_hips": Vector3 offset (metres) for the root bone.


static func skeleton(bones: Array) -> Skeleton3D:
	# bones: [name, parent name or "", global rest position]
	var sk: Skeleton3D = Skeleton3D.new()
	sk.name = "Skeleton3D"
	var gpos: Dictionary = {}
	for b: Array in bones:
		var i: int = sk.add_bone(String(b[0]))
		var parent: String = String(b[1])
		var p: Vector3 = b[2]
		gpos[b[0]] = p
		if parent != "":
			sk.set_bone_parent(i, sk.find_bone(parent))
			sk.set_bone_rest(i, Transform3D(Basis.IDENTITY, p - (gpos[parent] as Vector3)))
		else:
			sk.set_bone_rest(i, Transform3D(Basis.IDENTITY, p))
	sk.reset_bone_poses()
	return sk


static func clip(sk: Skeleton3D, dur: float, fn: Callable, root_bone: String = "Hips", loop: bool = true, fps: int = 30) -> Animation:
	var a: Animation = Animation.new()
	a.length = dur
	a.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	var tracks: Dictionary = {}
	var n: int = maxi(2, int(dur * fps))
	var root_rest: Vector3 = sk.get_bone_rest(sk.find_bone(root_bone)).origin
	for k: int in n + 1:
		var t: float = dur * float(k) / float(n)
		var pose: Dictionary = fn.call(t)
		for key: String in pose:
			if key == "_hips":
				if not tracks.has(key):
					var tr: int = a.add_track(Animation.TYPE_POSITION_3D)
					a.track_set_path(tr, NodePath("Skeleton3D:" + root_bone))
					tracks[key] = tr
				a.position_track_insert_key(tracks[key], t, root_rest + (pose[key] as Vector3))
			else:
				if not tracks.has(key):
					var tr2: int = a.add_track(Animation.TYPE_ROTATION_3D)
					a.track_set_path(tr2, NodePath("Skeleton3D:" + key))
					tracks[key] = tr2
				var e: Vector3 = pose[key]
				a.rotation_track_insert_key(tracks[key], t, Quaternion.from_euler(Vector3(deg_to_rad(e.x), deg_to_rad(e.y), deg_to_rad(e.z))))
	return a


## Wrap a skinned MK mesh + skeleton + clips into one node: Root(Node3D) / Skeleton3D / Mesh, Root / AnimationPlayer.
static func assemble(root_name: String, sk: Skeleton3D, mk: MK, clips: Dictionary) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = root_name
	root.add_child(sk)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = mk.build(root_name.to_lower())
	sk.add_child(mi)
	mi.skin = sk.create_skin_from_rest_transforms()
	mi.skeleton = NodePath("..")
	mi.extra_cull_margin = 2.0
	var ap: AnimationPlayer = AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	root.add_child(ap)
	var lib: AnimationLibrary = AnimationLibrary.new()
	for cn: String in clips:
		lib.add_animation(cn, clips[cn])
	ap.add_animation_library("", lib)
	return root


static func attach(sk: Skeleton3D, bone: String, node: Node3D) -> BoneAttachment3D:
	var ba: BoneAttachment3D = BoneAttachment3D.new()
	ba.name = "At" + bone
	sk.add_child(ba)
	ba.bone_name = bone
	ba.add_child(node)
	return ba
