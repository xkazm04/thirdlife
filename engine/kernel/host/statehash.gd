extends RefCounted
## The state hash of a pack (moved out of runner/worker.gd, which may not grow): SHA-256 over every physics body under the pack
## (position, rotation, velocities; quantised to 0.001) in tree order, followed by the canonical form of entry._pack_state().
## The bytes are exactly what the worker computed before the move: hashes do not change.


static func _q(v: float) -> int:
	return int(round(v * 1000.0))


static func _put_v3(buf: StreamPeerBuffer, v: Vector3) -> void:
	buf.put_64(_q(v.x))
	buf.put_64(_q(v.y))
	buf.put_64(_q(v.z))


static func _hash_node(n: Node, buf: StreamPeerBuffer) -> void:
	if n is PhysicsBody3D:
		var t: Transform3D = (n as PhysicsBody3D).global_transform
		_put_v3(buf, t.origin)
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
		_hash_node(c, buf)


## `state_text`: the canonical form of entry._pack_state() ("" when the pack has none).
static func hash(pack_node: Node, state_text: String) -> String:
	var buf: StreamPeerBuffer = StreamPeerBuffer.new()
	if pack_node != null:
		_hash_node(pack_node, buf)
	if not state_text.is_empty():
		buf.put_data(state_text.to_utf8_buffer())
	var hc: HashingContext = HashingContext.new()
	hc.start(HashingContext.HASH_SHA256)
	if buf.get_size() > 0:
		hc.update(buf.data_array)
	return hc.finish().hex_encode()
