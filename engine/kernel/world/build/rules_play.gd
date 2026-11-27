extends RefCounted
## SEAM M6 (rules and runs): the Home's rules in the visit. build_mode.gd makes one (`play`) and calls `tick(frames)`
## once per physics frame after `build.step()` (priority 150000: after the visit's sample and steer and the visitor's
## step at 100000, so the feet and E are this frame's). Lane P OWNS this file (LANES.md "M6"): it replaces `facade`
## with the real one (blocks hidden through the blocks layer's mask, launch / teleport on the walker body, the say
## line, the run clock HUD, the finish card, the zones' looks, falling out of the world) and gives `records` a
## home_records.gd on the Home's folder. The seam's version runs the rules over the no-op facade (rules_facade.gd),
## so the wiring and the resets are in place and nothing in the world changes.
##
## When the rules run (contracts/BUILD.md "Running"): build mode is off, no game is on stage, and the visitor's feet
## are known. Turning on (a visit starts, build mode goes off, a game leaves the stage) calls rules_run.gd `begin`
## (counters 0, no run, every zone closed, every coin back, the feet now are "where the visit began"); turning off
## (build mode comes on, a game takes the stage, the Home is left) calls `stop` (a run going is dropped, unrecorded).
## E is read from the visit's own TLInput (`just_pressed(&"enter")`), never from the keyboard, so a replayed visit
## replays the rules. Never in a pack's space or state hash: only the Home's build mode makes this.

const RulesRun := preload("res://kernel/world/build/rules_run.gd")
const RulesFacade := preload("res://kernel/world/build/rules_facade.gd")

var host: Node = null                    # build_mode.gd
var run: RefCounted = null               # rules_run.gd
var facade: RefCounted = null            # rules_facade.gd (lane P: its own, extending it)
var records: RefCounted = null           # home_records.gd (lane P: made on the Home's folder once it is opened)
var running := false                     # the rules run now (begin called, no stop since)
var why_off := "build"                   # why they last stopped
var ticks := 0                           # frames stepped (figures)


func _init(h: Node) -> void:
	host = h
	facade = RulesFacade.new()
	run = RulesRun.new(_rules(), facade, records)


func _rules() -> RefCounted:
	var b: Variant = host.get("build") if host != null else null
	return (b as RefCounted).call("layer", "rules") if b is RefCounted else null


## One physics frame (build_mode.gd `_physics_process`).
func tick(frame: int) -> void:
	var feet: Variant = feet_now()
	var off := _off_reason(feet)
	if off != "":
		if running:
			stop(off)
		return
	if not running:
		run.layer = _rules()
		run.facade = facade
		run.records = records
		run.begin(frame, feet as Vector3)
		running = true
	run.step(frame, RulesRun.feet_cell(feet as Vector3), use_down())
	ticks += 1


## "" while the rules may run, else why not: "build" (build mode is on), "stage" (a game is on stage), "nobody" (no
## visitor's feet are known).
func _off_reason(feet: Variant) -> String:
	if host == null or bool(host.get("active")):
		return "build"
	if int(host.call("_stage")) >= 0:
		return "stage"
	if not (feet is Vector3):
		return "nobody"
	return ""


func stop(why: String) -> void:
	if running:
		run.stop(why)
	running = false
	why_off = why


## The visitor's feet (build_mode.gd `feet_at` in a case, else the view's visitor), or null.
func feet_now() -> Variant:
	var fa: Callable = host.get("feet_at")
	if fa.is_valid():
		return fa.call()
	var v: Node3D = host.call("_visitor")
	return v.get("feet") if v != null else null


## E went down this frame: the visit's TLInput (kernel/runner/visit.gd ACTIONS `enter`), sampled before this frame.
func use_down() -> bool:
	var view: Variant = host.get("_view")
	var visit: Variant = (view as Node).get("visit") if view is Node else null
	var input: Variant = (visit as Node).get("input") if visit is Node else null
	return input is TLInput and (input as TLInput).just_pressed(&"enter")
