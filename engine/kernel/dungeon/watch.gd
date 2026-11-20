extends RefCounted
## L4b (night of 21 Nov): the dungeon's watchdog. The runner's own rule, reused: the worker's watchdog thread
## (kernel/runner/worker.gd `_wd_run`) asks kernel/host/cpuclock.gd `verdict` about the call into pack code that is
## running now, with the worker's limits (a tick 250 ms, a setup call 10 s, both of PROCESSOR time). No class_name.
##
## A runaway (an endless loop in one step, a step that never returns) blocks the only thread, and GDScript cannot be
## interrupted from outside: the worker and the world's guard (kernel/host/guard.gd) end their process for it. So does
## this one, but first it writes a trip record and starts the same executable again on that record, which shows the card
## "<title> was stopped" with Leave (boot.gd --tripped, kernel/dungeon/dungeon.gd `open_tripped`): the person meets a
## card, not a frozen window. "starved" (the machine, not the pack: 90 s of wall time with little processor time) stops
## nothing here: a person's game waits.
##
## Nothing here reaches a hash or a game's result: the watch only reads clocks from its own thread and ends the process.
##
##   var w = Watch.new(); w.start(record_path, relaunch_args)     the thread and the processor-time helper
##   w.begin(phase, frame) ... w.finish()                          around every call into pack code (PackLife hooks)
##   w.stop()

const CpuClock: GDScript = preload("res://kernel/host/cpuclock.gd")
const TICK_LIMIT_MS: int = 250          # the worker's (RUNNER.md: one _pack_tick)
const SETUP_LIMIT_MS: int = 10000       # the worker's: generators, _pack_setup, _pack_start, teardown
const POLL_MS: int = 20

var cpu: RefCounted
var record_path: String = ""
var relaunch: PackedStringArray = PackedStringArray()   # the arguments of the card process; empty: none is started
var info: Dictionary = {}               # what the record says about the dungeon: {pack, title}
var _thread: Thread
var _mutex: Mutex = Mutex.new()
var _start: int = 0
var _limit: int = 0
var _phase: String = ""
var _frame: int = -1
var _stop: bool = false
var _tripped: bool = false


func start(path: String, args: PackedStringArray, about: Dictionary) -> void:
	record_path = path
	relaunch = args
	info = about
	cpu = CpuClock.new()
	cpu.call("start", OS.get_process_id())
	_thread = Thread.new()
	_thread.start(_run)


func begin(phase: String, frame: int) -> void:
	_mutex.lock()
	_phase = phase
	_frame = frame
	_limit = (TICK_LIMIT_MS if phase.ends_with("_tick") else SETUP_LIMIT_MS) * 1000
	_start = Time.get_ticks_usec()
	_mutex.unlock()


## The call returned. Always true: a call caught over its limit never returns here (the thread ends the process).
func finish() -> bool:
	_mutex.lock()
	_start = 0
	var tripped: bool = _tripped
	_mutex.unlock()
	while tripped:                      # the thread is writing the record and ending the process
		OS.delay_msec(50)
	return true


func stop() -> void:
	_mutex.lock()
	_stop = true
	_mutex.unlock()
	if _thread != null:
		_thread.wait_to_finish()
		_thread = null
	if cpu != null:
		cpu.call("stop")


func _run() -> void:
	while true:
		OS.delay_msec(POLL_MS)
		_mutex.lock()
		var stop_now: bool = _stop
		var s: int = _start
		var limit: int = _limit
		var phase: String = _phase
		var frame: int = _frame
		_mutex.unlock()
		if stop_now:
			return
		if s == 0:
			continue
		var v: Dictionary = cpu.call("verdict", s, Time.get_ticks_usec(), limit, phase)
		if v.is_empty() or str(v["reason"]) == "starved":
			continue                    # a person's game waits for a machine that starves it
		_mutex.lock()
		var still: bool = _start == s
		if still:
			_tripped = true
		_mutex.unlock()
		if not still:
			continue
		var rec: Dictionary = info.duplicate()
		rec["schema"] = "thirdlife.dungeon/1"
		rec["kind"] = "trip"
		rec["reason"] = str(v["reason"])
		rec["phase"] = phase
		rec["frame"] = frame
		rec["detail"] = str(v["detail"])
		var text: String = JSON.stringify(rec, "", false)
		print("[dungeon] the game was stopped by the watchdog: " + text)
		var f: FileAccess = FileAccess.open(record_path, FileAccess.WRITE)
		if f != null:
			f.store_string(text + "\n")
			f.close()
		if not relaunch.is_empty():
			var pid: int = OS.create_process(OS.get_executable_path(), relaunch)
			print("[dungeon] the card process is %d" % pid)
		cpu.call("stop")
		OS.kill(OS.get_process_id())
		return
