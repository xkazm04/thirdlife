extends SceneTree
## P8 spike: the round trip of one message through each channel the engine offers a script, both ends in this
## process, busy polling (so the figure is the channel's own cost, not a frame's). `tools/proc.sh chan` runs it.
## TCP and UDP on 127.0.0.1 only; the named pipe is tried and reported (the engine does not make one for a script).

func _fill(n: int) -> PackedByteArray:
	var p: PackedByteArray = PackedByteArray()
	p.resize(n)
	for i: int in n:
		p[i] = i % 251
	return p

func _read_all(get: Callable, n: int) -> PackedByteArray:
	var got: PackedByteArray = PackedByteArray()
	var spins: int = 0
	while got.size() < n and spins < 2000000:
		var part: PackedByteArray = get.call(n - got.size())
		if part.is_empty():
			spins += 1
		else:
			got.append_array(part)
	return got

func _tcp_get(n: int, peer: StreamPeerTCP) -> PackedByteArray:
	peer.poll()
	var av: int = peer.get_available_bytes()
	if av <= 0:
		return PackedByteArray()
	return peer.get_partial_data(mini(av, n))[1]

func _init() -> void:
	var sizes: Array = [300, 2000, 10000, 60000]
	var rounds: int = 1000
	# ---- TCP loopback
	var srv: TCPServer = TCPServer.new()
	var port: int = 47000 + OS.get_process_id() % 2000
	print("tcp listen ", srv.listen(port, "127.0.0.1"))
	var c: StreamPeerTCP = StreamPeerTCP.new()
	c.connect_to_host("127.0.0.1", port)
	var s: StreamPeerTCP = null
	for i: int in 2000:
		c.poll()
		if s == null and srv.is_connection_available():
			s = srv.take_connection()
		if s != null and c.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			break
		OS.delay_msec(1)
	if s != null:
		c.set_no_delay(true)
		s.set_no_delay(true)
		for size: int in sizes:
			var p: PackedByteArray = _fill(size)
			var t0: int = Time.get_ticks_usec()
			var ok: bool = true
			for i: int in rounds:
				c.put_data(p)
				var a: PackedByteArray = _read_all(_tcp_get.bind(s), size)
				s.put_data(a)
				var b: PackedByteArray = _read_all(_tcp_get.bind(c), size)
				ok = ok and b.size() == size
			print("tcp   %6d B  round trip %.1f us  ok=%s" % [size, float(Time.get_ticks_usec() - t0) / float(rounds), str(ok)])
		c.disconnect_from_host()
		s.disconnect_from_host()
	srv.stop()
	# ---- UDP loopback
	var ua: PacketPeerUDP = PacketPeerUDP.new()
	var ub: PacketPeerUDP = PacketPeerUDP.new()
	print("udp bind ", ua.bind(port, "127.0.0.1"), " ", ub.bind(port + 1, "127.0.0.1"))
	ua.set_dest_address("127.0.0.1", port + 1)
	ub.set_dest_address("127.0.0.1", port)
	for size: int in sizes:
		var p: PackedByteArray = _fill(size)
		var t0: int = Time.get_ticks_usec()
		var ok: bool = true
		var err: int = OK
		for i: int in rounds:
			err = ua.put_packet(p)
			if err != OK:
				ok = false
				break
			var spins: int = 0
			while ub.get_available_packet_count() == 0 and spins < 2000000:
				spins += 1
			ub.put_packet(ub.get_packet())
			spins = 0
			while ua.get_available_packet_count() == 0 and spins < 2000000:
				spins += 1
			ok = ok and ua.get_packet().size() == size
		print("udp   %6d B  round trip %.1f us  ok=%s err=%d" % [size, float(Time.get_ticks_usec() - t0) / float(rounds), str(ok), err])
	ua.close()
	ub.close()
	# ---- a named pipe through FileAccess
	var bs: String = String.chr(92)
	var pname: String = bs + bs + "." + bs + "pipe" + bs + ("tlproc_chan_%d" % OS.get_process_id())
	var pa: FileAccess = FileAccess.open(pname, FileAccess.READ_WRITE)
	print("pipe server open: ", pa != null, " error ", FileAccess.get_open_error())
	var pb: FileAccess = FileAccess.open(pname, FileAccess.READ_WRITE) if pa != null else null
	print("pipe client open: ", pb != null, " error ", FileAccess.get_open_error())
	if pa != null and pb != null:
		for size: int in sizes:
			var p: PackedByteArray = _fill(size)
			var t0: int = Time.get_ticks_usec()
			var ok: bool = true
			for i: int in rounds:
				pb.store_buffer(p)
				pb.flush()
				var a: PackedByteArray = _read_all(func(n: int) -> PackedByteArray: return pa.get_buffer(n), size)
				if a.size() != size:
					ok = false
					break
				pa.store_buffer(a)
				pa.flush()
				var b: PackedByteArray = _read_all(func(n: int) -> PackedByteArray: return pb.get_buffer(n), size)
				ok = ok and b.size() == size
				if not ok:
					break
			print("pipe  %6d B  round trip %.1f us  ok=%s" % [size, float(Time.get_ticks_usec() - t0) / float(rounds), str(ok)])
	if pa != null:
		pa.close()
	if pb != null:
		pb.close()
	quit()
