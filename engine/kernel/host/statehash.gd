extends RefCounted
## The state hash of a pack (moved out of runner/worker.gd, which may not grow): SHA-256 over every physics body under the pack
## (position, rotation, velocities; quantised to 0.001) in tree order, followed by the canonical form of entry._pack_state().
## P7: the hash covers what can differ. After those bytes come the seeded generator (its seed and its state) and the
## input state (every action's value in this frame and in the one before, by name). Two runs that agree on every body
## and on `_pack_state()` and still differ in the next random number or in a held key no longer hash alike. This
## changed every hash once (2026-11-11); the old and new values are in the P7 report (docs/reports) and API.md section 22
## says what the hash covers. Input values are hashed as whole thousandths (TLInput.STEP), action names as sorted text.


static func _q(v: float) -> int:
	return int(round(v * 1000.0))


static func _put_v3(buf: StreamPeerBuffer, v: Vector3) -> void:
	buf.put_64(_q(v.x))
	buf.put_64(_q(v.y))
	buf.put_64(_q(v.z))


static func _hash_node(n: Node, buf: StreamPeerBuffer, origin: Vector3) -> void:
	if n is PhysicsBody3D:
		var t: Transform3D = (n as PhysicsBody3D).global_transform
		_put_v3(buf, t.origin if origin == Vector3.ZERO else t.origin - origin)   # pack-local: the same pack hashes alike anywhere
		var qt: Quaternion = t.basis.orthonormalized().get_rotation_quaternion()
		if qt.w < 0.0:
			qt = -qt
		buf.put_64(_q(qt.x))
		buf.put_64(_q(qt.y))
		buf.put_64(_q(qt.z))
		buf.put_64(_q(qt.w))
		if n is RigidBody3D:
			_put_v3(buf, (n as RigidBody3D).linear_velocity)
			_put_v3(buf, (n as RigidBody3D).angular_velocity)
		elif n is CharacterBody3D:
			_put_v3(buf, (n as CharacterBody3D).velocity)
	for c: Node in n.get_children():
		_hash_node(c, buf, origin)


## `state_text`: the canonical form of entry._pack_state() ("" when the pack has none). `rng`: the pack's seeded
## generator, `input`: its TLInput (either may be null: a kernel tool that has none). `origin`: where the pack stands
## in a world (body positions are hashed relative to it).
static func hash(pack_node: Node, state_text: String, rng: RandomNumberGenerator = null, input: Node = null, origin: Vector3 = Vector3.ZERO) -> String:
	var buf: StreamPeerBuffer = StreamPeerBuffer.new()
	if pack_node != null:
		_hash_node(pack_node, buf, origin)
	if not state_text.is_empty():
		buf.put_data(state_text.to_utf8_buffer())
	if rng != null:
		buf.put_data("|rng".to_utf8_buffer())
		buf.put_64(rng.seed)
		buf.put_64(rng.state)
	if input != null:
		buf.put_data("|input".to_utf8_buffer())
		input.call("_hash_into", buf)
	var hc: HashingContext = HashingContext.new()
	hc.start(HashingContext.HASH_SHA256)
	if buf.get_size() > 0:
		hc.update(buf.data_array)
	return hc.finish().hex_encode()


## The canonical text of a pack-provided value (sorted keys, floats to four places): what the hash reads of `_pack_state()`.
static func canon(v: Variant) -> String:
	match typeof(v):
		TYPE_NIL:
			return "null"
		TYPE_BOOL:
			return "true" if v else "false"
		TYPE_INT:
			return str(v)
		TYPE_FLOAT:
			return "%.4f" % float(v)
		TYPE_STRING, TYPE_STRING_NAME, TYPE_NODE_PATH:
			return "\"" + str(v) + "\""
		TYPE_VECTOR2:
			return "[%.4f,%.4f]" % [v.x, v.y]
		TYPE_VECTOR3:
			return "[%.4f,%.4f,%.4f]" % [v.x, v.y, v.z]
		TYPE_DICTIONARY:
			var keys: Array = []
			for k: Variant in (v as Dictionary).keys():
				keys.append(str(k))
			keys.sort()
			var by_name: Dictionary = {}
			for k: Variant in (v as Dictionary).keys():
				by_name[str(k)] = (v as Dictionary)[k]
			var parts: PackedStringArray = PackedStringArray()
			for k: String in keys:
				parts.append("\"" + k + "\":" + canon(by_name[k]))
			return "{" + ",".join(parts) + "}"
		TYPE_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, \
		TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY:
			var items: PackedStringArray = PackedStringArray()
			for item: Variant in v:
				items.append(canon(item))
			return "[" + ",".join(items) + "]"
	return "\"<" + type_string(typeof(v)) + ">\""


## A JSON-safe copy of a pack-provided value (vectors become arrays, objects become their type name).
static func plain(v: Variant) -> Variant:
	match typeof(v):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING:
			return v
		TYPE_FLOAT:
			return snappedf(float(v), 0.0001)
		TYPE_STRING_NAME, TYPE_NODE_PATH:
			return str(v)
		TYPE_VECTOR2:
			return [snappedf(v.x, 0.0001), snappedf(v.y, 0.0001)]
		TYPE_VECTOR3:
			return [snappedf(v.x, 0.0001), snappedf(v.y, 0.0001), snappedf(v.z, 0.0001)]
		TYPE_DICTIONARY:
			var d: Dictionary = {}
			for k: Variant in (v as Dictionary).keys():
				d[str(k)] = plain((v as Dictionary)[k])
			return d
		TYPE_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, \
		TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY:
			var a: Array = []
			for item: Variant in v:
				a.append(plain(item))
			return a
	return "<" + type_string(typeof(v)) + ">"
