extends RefCounted
## P1. The watchdog of the world host (kernel/world/world.gd), the counterpart of the worker's watchdog.
##
## One world process holds many packs; a runaway `_pack_tick` blocks its only thread and GDScript cannot be interrupted
## from outside, so the world used to hang forever. This guard watches from its own thread, counting PROCESSOR time (see
## cpuclock.gd): a guarded call that has used `limit_ms` of processor time is a runaway; one that was only starved by
## the machine is let go on. On a runaway the guard writes a trip record (`trip_path`, JSON) and ends the process. The
## supervisor in host.gd reads the record, marks that pack as tripped and runs the world again without it, so the
## others go on and their hashes are what they are alone (the packs share nothing).
##
## No global class name is used here.

const CpuClock: GDScript = preload("res://kernel/host/cpuclock.gd")
const POLL_MS: int = 20
const CPU_WAIT_USEC: int = 10000000    # how long past its limit a call waits for the process-time helper to start
const WALL_CAP_MS: int = 90000         # a call the machine starved for this long is given up (reason: starved)

var cpu: RefCounted
var limit_us: int = 250000
var trip_path: String = ""
var stalls: int = 0                    # guarded calls that ran over the limit in wall time and not in processor time
var stall_wall_ms: float = 0.0
var _thread: Thread
var _mutex: Mutex = Mutex.new()
var _start_usec: int = 0
var _info: Dictionary = {}
var _stop: bool = false
var _tripped: bool = false


func start(limit_ms: int, path: String) -> void:
	limit_us = limit_ms * 1000
	trip_path = path
	cpu = CpuClock.new()
	cpu.call("start", OS.get_process_id())
	_thread = Thread.new()
	_thread.start(_run)


## One pack's tick under the guard: `p.tick(world_tick)`, watched for processor time.
func tick(p: Node, i: int, world_tick: int) -> void:
	begin({"pack": i, "world_tick": world_tick, "frame": int(p.get("frames_done"))})
	p.call("tick", world_tick)
	end()


## A guarded call begins. `info` is kept for the trip record: {pack, plot, frame, world_tick}.
func begin(info: Dictionary) -> void:
	_mutex.lock()
	_info = info
	_start_usec = Time.get_ticks_usec()
	_mutex.unlock()


## The call returned. A call that ran over the limit in wall time and used less processor time was starved: counted.
func end() -> void:
	var now: int = Time.get_ticks_usec()
	_mutex.lock()
	var s: int = _start_usec
	_start_usec = 0
	var tripped: bool = _tripped
	_mutex.unlock()
	if tripped:
		while true:                    # the guard thread is writing the record and ending the process
			OS.delay_msec(50)
	if s != 0 and now - s > limit_us:
		stalls += 1
		stall_wall_ms += float(now - s) / 1000.0


func stop() -> void:
	_mutex.lock()
	_stop = true
	_mutex.unlock()
	if _thread != null:
		_thread.wait_to_finish()
		_thread = null
	cpu.call("stop")


func _run() -> void:
	while true:
		OS.delay_msec(POLL_MS)
		_mutex.lock()
		var stop: bool = _stop
		var s: int = _start_usec
		var info: Dictionary = _info
		_mutex.unlock()
		if stop:
			return
		if s == 0:
			continue
		var now: int = Time.get_ticks_usec()
		var wall: int = now - s
		var used: float = float(cpu.call("used_ms", s, now))
		var reason: String = ""
		if used >= 0.0:
			if used * 1000.0 >= float(limit_us):
				reason = "tick_timeout"
		elif wall > limit_us and (bool(cpu.get("gave_up")) or wall > limit_us + CPU_WAIT_USEC):
			reason = "tick_timeout"
		if reason.is_empty() and wall > WALL_CAP_MS * 1000:
			reason = "starved"
		if reason.is_empty():
			continue
		_mutex.lock()
		if _start_usec == s:
			_tripped = true
		else:
			reason = ""
		_mutex.unlock()
		if reason.is_empty():
			continue
		var rec: Dictionary = {"reason": reason, "wall_ms": wall / 1000, "limit_ms": limit_us / 1000, "info": info}
		if used >= 0.0:
			rec["cpu_ms"] = int(used)
		var text: String = JSON.stringify(rec, "", false)
		if not trip_path.is_empty():
			var f: FileAccess = FileAccess.open(trip_path, FileAccess.WRITE)
			if f != null:
				f.store_string(text)
				f.close()
		else:
			print(JSON.stringify({"schema": "tl.world/1", "kind": "event", "e": "runaway", "record": rec}, "", false))
		cpu.call("stop")
		OS.kill(OS.get_process_id())
		return
