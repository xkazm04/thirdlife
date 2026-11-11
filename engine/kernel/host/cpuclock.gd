extends RefCounted
## P1. Processor time of this process, for the watchdogs.
##
## Godot gives a script no process-time clock, and every limit that counts wall time fails healthy code when the
## machine is busy (JOB3-HOCKEY findings 5 and 6). This asks the operating system instead: one long-lived PowerShell
## helper per process reads `TotalProcessorTime` of the target process on request (0.1 ms per answer once it runs,
## 0.25 s to start on a quiet machine, 1.7 s with sixteen busy processes; granularity 15.6 ms). It is asked only while
## a guarded call is already slow, never per frame.
##
## A guarded call that has used less processor time than its limit and still ran over it in wall time was STARVED: the
## machine did not give it the processor. A guarded call that used its limit in processor time is a runaway script.
## Where the helper cannot run (not Windows, no PowerShell) `used_ms` returns -1 and callers keep the wall-time limit.
##
## No global class name is used here (the supervisor works before the class cache exists).

const SUSPECT_MS: float = 40.0         # a guarded call younger than this is not asked about
const START_WAIT_MS: int = 4000
const PREFIX_CAP_MS: float = 80.0      # the unseen part of a call (before the first look) is counted as used up to this much, never more:
									   # a call that the machine starved until the helper was ready must not look like a runaway

var available: bool = false
var gave_up: bool = false
var cpu_ms_last: float = -1.0
var queries: int = 0
const CPU_WAIT_USEC: int = 10000000    # how long past its limit a call waits for the helper to start before the wall-time limit applies
const WALL_CAP_MS: int = 90000         # a guarded call the machine starved for this long is given up (reason: starved)
var stalls: Array = []                 # guarded calls that ran over their limit in wall time and not in processor time (the first 12)
var stalls_total: int = 0
var stall_wall_ms: float = 0.0
var stall_worst_ms: float = 0.0
var _pipe: FileAccess = null
var _helper_pid: int = -1
var _boot: Thread = null
var _mutex: Mutex = Mutex.new()
# the guard being observed: its start (usec), the helper's reading at the first look and the wall time of that look
var _g_start: int = 0
var _base_cpu: float = 0.0
var _base_wall: float = 0.0


func start(target_pid: int) -> void:
	if OS.get_name() != "Windows" or OS.has_environment("TL_NO_CPUCLOCK"):
		gave_up = true
		return
	_boot = Thread.new()
	_boot.start(_boot_run.bind(target_pid))


func _boot_run(target_pid: int) -> void:
	var ps: String = ("$t=[System.Diagnostics.Process]::GetProcessById(%d);[Console]::Out.WriteLine('ready');"
		+ "while($true){$l=[Console]::In.ReadLine();if($l -eq $null){break};$t.Refresh();"
		+ "[Console]::Out.WriteLine([string]$t.TotalProcessorTime.TotalMilliseconds)}") % target_pid
	var h: Dictionary = OS.execute_with_pipe("powershell", PackedStringArray(["-NoProfile", "-NonInteractive", "-Command", ps]))
	if h.is_empty() or not h.has("stdio"):
		gave_up = true
		return
	_helper_pid = int(h["pid"])
	var pipe: FileAccess = h["stdio"]
	var line: String = pipe.get_line().strip_edges()
	_mutex.lock()
	if line == "ready":
		_pipe = pipe
		available = true
	else:
		gave_up = true
	_mutex.unlock()


## True once the helper runs or it is known that none will.
func settled() -> bool:
	return available or gave_up


## Waits (bounded) until `settled()`. Called once, before the first frame.
func wait_settled(max_ms: int = START_WAIT_MS) -> void:
	var t0: int = Time.get_ticks_msec()
	while not settled() and Time.get_ticks_msec() - t0 < max_ms:
		OS.delay_msec(5)


## Process time in ms since the process began, or -1.0. The caller holds `_mutex` or is the only one asking.
func _read() -> float:
	if _pipe == null:
		return -1.0
	_pipe.store_line("c")
	_pipe.flush()
	var l: String = _pipe.get_line()
	if l.is_empty():
		available = false
		gave_up = true
		return -1.0
	queries += 1
	cpu_ms_last = float(l)
	return cpu_ms_last


## Processor time (ms) a guarded call that began at `g_start` (usec) has used up to `now`: what the helper saw it use since
## the first look, plus the unseen part before it counted as used (at most PREFIX_CAP_MS, so a runaway is stopped after about
## 250 ms of its own processor time and a call the machine starved is never taken for one). Never more than the wall time.
## -1.0 when there is no process-time source.
func used_ms(g_start: int, now: int) -> float:
	if not available:
		return -1.0
	var wall_ms: float = float(now - g_start) / 1000.0
	if wall_ms < SUSPECT_MS:
		return wall_ms
	_mutex.lock()
	var out: float = -1.0
	if available:
		var c: float = _read()
		if c >= 0.0:
			if _g_start != g_start:
				_g_start = g_start
				_base_cpu = c
				_base_wall = minf(wall_ms, PREFIX_CAP_MS)
			out = minf(wall_ms, _base_wall + maxf(c - _base_cpu, 0.0))
	_mutex.unlock()
	return out


func stop() -> void:
	if _helper_pid > 0:
		OS.kill(_helper_pid)          # its answer line never comes; a boot thread still waiting for "ready" gets end of file
	if _boot != null:
		_boot.wait_to_finish()
		_boot = null
		if _helper_pid > 0:
			OS.kill(_helper_pid)
	_mutex.lock()
	available = false
	gave_up = true
	if _pipe != null:
		_pipe.close()
		_pipe = null
	_mutex.unlock()
	_helper_pid = -1


## A guarded call ended over its limit in wall time without using it in processor time: the machine's stall, kept for the report.
func note_stall(phase: String, frame: int, wall_ms: float, cpu_ms: float) -> void:
	stalls_total += 1
	stall_wall_ms += wall_ms
	stall_worst_ms = maxf(stall_worst_ms, wall_ms)
	if stalls.size() < 12:
		var e: Dictionary = {"phase": phase, "frame": frame, "wall_ms": snappedf(wall_ms, 0.1)}
		if cpu_ms >= 0.0:
			e["cpu_ms"] = snappedf(cpu_ms, 0.1)
		stalls.append(e)


## `result["starved"]`: empty when nothing stalled.
func starved_summary() -> Dictionary:
	if stalls_total == 0:
		return {}
	return {"count": stalls_total, "wall_ms": snappedf(stall_wall_ms, 0.1), "worst_ms": snappedf(stall_worst_ms, 0.1), "list": stalls}


## What the watchdog thread says about a guarded call that is still running: {} (let it run) or {reason, detail, used}.
## A runaway has used its limit in processor time; a call the machine starved for WALL_CAP_MS is "starved"; without a
## process-time source the wall-time limit applies (once the helper has had CPU_WAIT_USEC to start).
func verdict(g_start: int, now: int, limit_us: int, phase: String) -> Dictionary:
	var wall: int = now - g_start
	var used: float = used_ms(g_start, now)
	if used >= 0.0:
		if used * 1000.0 >= float(limit_us):
			return {"reason": "tick_timeout", "used": used, "detail": "%s did not return within %d ms of processor time (it used %d ms in %d ms of wall time; runaway script); the process was stopped" % [phase, limit_us / 1000, int(used), wall / 1000]}
	elif wall > limit_us and (gave_up or wall > limit_us + CPU_WAIT_USEC):
		return {"reason": "tick_timeout", "used": used, "detail": "%s did not return within %d ms (runaway script; no process-time source on this machine); the process was stopped" % [phase, limit_us / 1000]}
	if wall > WALL_CAP_MS * 1000:
		return {"reason": "starved", "used": used, "detail": "%s ran %d s of wall time and the machine gave it %d ms of processor time (limit %d ms); the machine, not the pack, stopped it" % [phase, wall / 1000000, int(used), limit_us / 1000]}
	return {}
