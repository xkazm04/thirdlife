extends Node
## The two cuts open their own cores (K3 round 11). data/match.json `cartridge` picks the cut; ctx.cores.open opens the plain
## core (thirdjam's, RinkCore) for hockey.regular and the rule-patched one (RinkCoreThirdlife, lane K8) for hockey.thirdlife,
## whose data/hockey.thirdlife.rules.json lies beside it (kernel 1.27). This bot opens both beside the pack's own core and
## checks the class each opened, that each plays a whole match of bots alone (human mode "brain") from the same seed, and
## that the two matches part (the Third Life rules change the game). The pack's own core and its hash are not touched.

const FRAMES: int = 36000
var ctx
var done: bool = false
var rows: Array = []
var ok: bool = false


func _bot_setup(c) -> void:
	ctx = c


var cores: Array = []            # [cut, core, frames, over]
const SLICE: int = 200           # frames a tick per core (the runner's watchdog holds a tick to 250 ms)


func _bot_tick(frame: int) -> void:
	if frame == 1:
		for cut: String in ["hockey.regular.cartridge.json", "hockey.thirdlife.cartridge.json"]:
			var core = ctx.cores.open("rink", cut)
			if core == null:
				rows.append("%s: did not open" % cut)
				done = true
				return
			core.set_difficulty("pro")
			core.set_human_mode("brain")
			core.reset(1)
			cores.append([cut, core, 0, false])
		return
	if frame < 2 or done:
		return
	var all_over: bool = true
	for e: Array in cores:
		var k: int = 0
		while not bool(e[3]) and k < SLICE and int(e[2]) < FRAMES:
			if not e[1].step():
				e[3] = true
			e[2] = int(e[2]) + 1
			k += 1
		if not bool(e[3]) and int(e[2]) < FRAMES:
			all_over = false
	if not all_over:
		return
	var out: Dictionary = {}
	for e: Array in cores:
		var sc: Array = e[1].get_score()
		out[e[0]] = [e[1].get_class(), e[1].state_hash_hex(), bool(e[3])]
		rows.append("%s: %s, %d frames, %d:%d, hash %s" % [e[0], e[1].get_class(), int(e[2]), int(sc[0]), int(sc[1]), e[1].state_hash_hex()])
	var r: Array = out["hockey.regular.cartridge.json"]
	var t: Array = out["hockey.thirdlife.cartridge.json"]
	ok = String(r[0]) == "RinkCore" and String(t[0]) == "RinkCoreThirdlife" and bool(r[2]) and bool(t[2]) and String(r[1]) != String(t[1])
	done = true


func _bot_done() -> bool:
	return done


func _bot_result() -> Dictionary:
	return {"ok": ok, "summary": "; ".join(rows), "frames": ctx.frame}
