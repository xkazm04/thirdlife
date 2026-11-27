extends SceneTree
## S2-juice arm A (juice day, 27 Nov 2026): the standard juice pass is automatic. Every change that adds a move runs it
## (foreman/src/juicepass.ts, JUICE_MODE "auto") unless the person says "keep it plain"; Create sends the person's words
## as typed and, on the done screen, says the pass ran and how to leave it out. The selftest block 812 runs this headless
## (the door dry, nothing is started); one "PASS <name>" / "FAIL <name>  -> <why>" line each, then
## "[juice] <n> passed, <m> failed".

const CreateScene = preload("res://ui/create/create.tscn")
const Iterate = preload("res://ui/create/create_iterate_checks.gd")
const Model = preload("res://ui/create/create_model.gd")

const MOVE: String = "Give every penguin a belly slide on F: it shoots forward and bowls over anyone in the way"

var passed: int = 0
var failed: int = 0


func _made(dir: String, note: String) -> String:
	var ev: Array = [{"type": "change_requested", "text": MOVE}, {"type": "job_state", "state": "running", "reason": "change request"},
		{"type": "reopened", "package": "penguin_moves", "reason": "change request (event 76); the Planner names the package"},
		{"type": "package_state", "package": "penguin_moves", "state": "queued", "round": 3, "detail": "CHANGE REQUEST: " + MOVE}]
	if not note.is_empty():
		ev.append({"type": "note", "package": "penguin_moves", "round": 3, "text": note})
	ev.append_array([{"type": "package_state", "package": "penguin_moves", "state": "promoted", "round": 3},
		{"type": "promoted", "packId": "game.penguin_push", "version": "0.1.1", "dest": "promoted/game.penguin_push@0.1.1"},
		{"type": "job_state", "state": "done", "reason": "promoted 0.1.1"}])
	return Iterate._job(dir, ev, ["0.1.0", "0.1.1"])


func _initialize() -> void:
	var tmp: String = OS.get_user_data_dir().path_join("tl_juice_case_%d" % OS.get_process_id())
	var ran: String = _made(tmp.path_join("ran"), "[foreman] juice pass: your change adds a move, so penguin_moves also gets the standard juice pass. Say \"keep it plain\" in a change to leave it out.")
	var plain: String = _made(tmp.path_join("plain"), "")
	var page: Control = CreateScene.instantiate()
	var fake: Array = ["--adapter", "fake"]
	page.call("setup", {"jobs": tmp, "dry": true, "now": 1795289400.0, "flags": {"run": fake, "resume": fake, "change": fake}})
	await process_frame
	root.add_child(page)
	page.call("open")
	var has: Callable = func(name: String) -> bool:
		var n: Node = page.find_child(name, true, false)
		return n != null and (n as CanvasItem).is_visible_in_tree()
	var press: Callable = func(name: String) -> void:
		(page.find_child(name, true, false) as BaseButton).pressed.emit()
	var door: RefCounted = page.get("door")

	# 1. the pass ran on the last move: the done screen says so, and how to leave it out; there is no card to pick
	page.call("show_job", ran)
	await process_frame
	var note: Node = page.find_child("JuiceNote", true, false)
	var said: String = (note as Label).text if note != null else ""
	_check("create.juice.note: after a change the pass ran on, the done screen says the new move got the juice pass and that 'keep it plain' leaves it out (no card, no follow-up)",
		has.call("JuiceNote") and said.contains("keep it plain") and not has.call("JuicyCard") and not has.call("JuicyFollowUp") and Model.juice_of(page.get("job")) == "ran",
		"note '%s' card %s follow %s" % [said, str(has.call("JuicyCard")), str(has.call("JuicyFollowUp"))])

	# 2. a change the pass did not run on: no note; a change goes out as typed (the Foreman decides from the words)
	page.call("show_job", plain)
	await process_frame
	var quiet: bool = not has.call("JuiceNote")
	var base: int = (door.get("dry_steps") as Array).size()
	(page.find_child("ChangeBox", true, false) as LineEdit).text = MOVE + " Keep it plain."
	press.call("SendChange")
	var sent: Array = (door.get("dry_steps") as Array).slice(base)
	_check("create.juice.plain: no juice note after a change the pass did not run on; the person's words go out as typed",
		quiet and str(sent) == str([[["change", plain, MOVE + " Keep it plain."] + fake]]), "quiet %s sent %s" % [str(quiet), str(sent)])
	print("[juice] %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)


func _check(name: String, ok: bool, why: String) -> void:
	if ok:
		passed += 1
		print("PASS " + name)
	else:
		failed += 1
		print("FAIL %s  -> %s" % [name, why])
