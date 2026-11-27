extends SceneTree
## S2-juice arm B (juice day, 27 Nov 2026): "make it juicy" is a choice in Create. The done screen's change row has a
## card; picked, the change carries "Make it juicy." and the Foreman runs the standard juice pass on it
## (foreman/src/juicepass.ts, JUICE_MODE "choice"). A move built plain gets the Foreman's "juice pass offered" note, and
## the done screen offers a one-click follow-up. The selftest block 812 runs this headless (the door dry, nothing is
## started); one "PASS <name>" / "FAIL <name>  -> <why>" line each, then "[juice] <n> passed, <m> failed".

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
	var offered: String = _made(tmp.path_join("offered"), "[foreman] juice pass offered: your change adds a move and was built plain, as you asked.")
	var ran: String = _made(tmp.path_join("ran"), "[foreman] juice pass: you picked \"make it juicy\", so penguin_moves also gets the standard juice pass.")
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

	# 1. the card: off by default (the change goes as typed); picked, the change carries "Make it juicy."
	page.call("show_job", plain)
	await process_frame
	var shown: bool = has.call("JuicyCard") and has.call("ChangeBox") and has.call("SendChange") and not has.call("JuicyFollowUp")
	var base: int = (door.get("dry_steps") as Array).size()
	(page.find_child("ChangeBox", true, false) as LineEdit).text = "make the penguins faster"
	press.call("SendChange")
	var sent_plain: Array = (door.get("dry_steps") as Array).slice(base)
	page.call("show_job", plain)
	await process_frame
	press.call("JuicyCard")
	var picked: bool = bool(page.get("juicy")) and has.call("JuicyCard")
	(page.find_child("ChangeBox", true, false) as LineEdit).text = MOVE
	base = (door.get("dry_steps") as Array).size()
	press.call("SendChange")
	var sent_juicy: Array = (door.get("dry_steps") as Array).slice(base)
	_check("create.juice.card: the change row has a 'Make it juicy' card, off until picked; unpicked the change goes as typed, picked it ends 'Make it juicy.' (and the pick clears after the send)",
		shown and picked and str(sent_plain) == str([[["change", plain, "make the penguins faster"] + fake]]) and str(sent_juicy) == str([[["change", plain, MOVE + " Make it juicy."] + fake]]) and not bool(page.get("juicy")),
		"shown %s picked %s plain %s juicy %s" % [str(shown), str(picked), str(sent_plain), str(sent_juicy)])

	# 2. the follow-up: a move built plain (the Foreman's offer note) gets one click that makes it juicy
	page.call("show_job", offered)
	await process_frame
	var offer_shown: bool = has.call("JuicyFollowUp") and has.call("Play") and has.call("AddMenu") and Model.juice_of(page.get("job")) == "offered"
	base = (door.get("dry_steps") as Array).size()
	press.call("JuicyFollowUp")
	var follow: Array = (door.get("dry_steps") as Array).slice(base)
	var want: String = "Make it juicy: the move I just added (\u201c%s\u201d). Keep its rules as they are." % MOVE
	_check("create.juice.follow: a move built plain shows a 'Make it juicy' follow-up beside Play; one click sends foreman change <job> \"Make it juicy: the move I just added (...)\"",
		offer_shown and str(follow) == str([[["change", offered, want] + fake]]) and str(page.call("shown_screen")) == "building",
		"shown %s sent %s screen %s" % [str(offer_shown), str(follow), str(page.call("shown_screen"))])

	# 3. no follow-up once the pass ran, nor after a change that adds no move (no note)
	page.call("show_job", ran)
	await process_frame
	var none_ran: bool = not has.call("JuicyFollowUp") and Model.juice_of(page.get("job")) == "ran"
	page.call("show_job", plain)
	await process_frame
	var none_plain: bool = not has.call("JuicyFollowUp") and Model.juice_of(page.get("job")).is_empty()
	_check("create.juice.none: no follow-up when the pass ran, or for a change the Foreman did not offer it on", none_ran and none_plain, "ran %s plain %s" % [str(none_ran), str(none_plain)])
	print("[juice] %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)


func _check(name: String, ok: bool, why: String) -> void:
	if ok:
		passed += 1
		print("PASS " + name)
	else:
		failed += 1
		print("FAIL %s  -> %s" % [name, why])
