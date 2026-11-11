extends RefCounted
## P8 spike. The channel between the two processes and the helpers both ends share.
##
## A message is a Variant encoded by the engine (`var_to_bytes`, objects are never decoded) behind a 4-byte length.
## Sending never blocks: what the socket does not take stays in a queue here, so a reader that stopped reading cannot
## stop the writer (`backlog` tells how far behind it is).

# node kinds in the table S sends (bit flags)
const K_3D: int = 1
const K_LABEL: int = 2
const K_SKELETON: int = 4
const K_CAMERA: int = 8
const K_BODY: int = 16
const K_VFX: int = 32
const READ_CAP: int = 32 * 1024 * 1024

var tcp: StreamPeerTCP = null
var bytes_out: int = 0
var bytes_in: int = 0
var msgs_out: int = 0
var msgs_in: int = 0
var backlog_max: int = 0
var lost: bool = false
var _out: PackedByteArray = PackedByteArray()
var _in: PackedByteArray = PackedByteArray()


func attach(peer: StreamPeerTCP) -> void:
	tcp = peer
	tcp.set_no_delay(true)


func connected() -> bool:
	if tcp == null or lost:
		return false
	tcp.poll()
	if tcp.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		lost = true
		return false
	return true


func backlog() -> int:
	return _out.size()


## Queues one message and pushes what the socket takes. Returns the bytes of the message on the wire.
func send(msg: Variant) -> int:
	var body: PackedByteArray = var_to_bytes(msg)
	var head: PackedByteArray = PackedByteArray([0, 0, 0, 0])
	head.encode_u32(0, body.size())
	_out.append_array(head)
	_out.append_array(body)
	msgs_out += 1
	bytes_out += body.size() + 4
	flush()
	return body.size() + 4


func flush() -> void:
	if tcp == null or lost or _out.is_empty():
		return
	var r: Array = tcp.put_partial_data(_out)
	if int(r[0]) != OK:
		lost = true
		return
	var sent: int = int(r[1])
	if sent >= _out.size():
		_out = PackedByteArray()
	elif sent > 0:
		_out = _out.slice(sent)
	backlog_max = maxi(backlog_max, _out.size())


## Every complete message that has arrived.
func recv() -> Array:
	var out: Array = []
	if not connected():
		return out
	var taken: int = 0
	while taken < READ_CAP:          # the socket hands over one buffer at a time: read until it is empty
		var n: int = tcp.get_available_bytes()
		if n <= 0:
			break
		var r: Array = tcp.get_partial_data(n)
		if int(r[0]) != OK:
			lost = true
			return out
		_in.append_array(r[1] as PackedByteArray)
		bytes_in += (r[1] as PackedByteArray).size()
		taken += (r[1] as PackedByteArray).size()
	var pos: int = 0
	while _in.size() - pos >= 4:
		var size: int = _in.decode_u32(pos)
		if _in.size() - pos - 4 < size:
			break
		out.append(bytes_to_var(_in.slice(pos + 4, pos + 4 + size)))
		pos += 4 + size
		msgs_in += 1
	if pos > 0:
		_in = _in.slice(pos)
	return out


func close() -> void:
	if tcp != null:
		tcp.disconnect_from_host()
		tcp = null


# ---------------------------------------------------------------------------------------------------- shared helpers
## The name of every child of `parent` as both processes can agree on it: its own name, or, for a name the engine
## made up ("@Node3D@41": the number is a counter of the process), the class and the ordinal among such siblings.
static func segments(parent: Node) -> Dictionary:
	var counts: Dictionary = {}
	var out: Dictionary = {}
	for c: Node in parent.get_children():
		var nm: String = String(c.name)
		if nm.begins_with("@"):
			var cls: String = c.get_class()
			var k: int = int(counts.get(cls, 0))
			counts[cls] = k + 1
			nm = "@%s#%d" % [cls, k]
		out[c.get_instance_id()] = nm
	return out


static func kind_of(n: Node) -> int:
	var k: int = 0
	if n is Node3D:
		k |= K_3D
		if n is Skeleton3D:
			k |= K_SKELETON
		if n is Camera3D:
			k |= K_CAMERA
		if n is CollisionObject3D:
			k |= K_BODY
		if n is TLVfxNode:
			k |= K_VFX
	elif n is Label:
		k |= K_LABEL
	return k


static func pct(values: Array, p: float) -> float:
	if values.is_empty():
		return 0.0
	var s: Array = values.duplicate()
	s.sort()
	return float(s[clampi(int(ceil(p * float(s.size()))) - 1, 0, s.size() - 1)])


static func mean(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var t: float = 0.0
	for v: Variant in values:
		t += float(v)
	return t / float(values.size())


static func r3(v: float) -> float:
	return snappedf(v, 0.001)


## The args after `--` as a table (the same rule as the host: `--name=value`, `--flag`, and one bare word, the role).
static func parse_args() -> Dictionary:
	var opts: Dictionary = {}
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var eq: int = a.find("=")
			if eq < 0:
				opts[a.substr(2)] = "true"
			else:
				opts[a.substr(2, eq - 2)] = a.substr(eq + 1)
		elif not opts.has("role"):
			opts["role"] = a
	return opts
