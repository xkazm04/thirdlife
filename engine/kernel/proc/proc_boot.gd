extends Node
## P8 spike: the door of the two-process experiment (kernel/proc/PROCESS.md). Not a verify verb and not on the path
## a game runs on: its own scene, so kernel/host/host.gd is not touched.
##
##   <godot> [--headless] --path <engine> res://kernel/proc/proc.tscn -- <sim|draw|solo> --pack=<dir> [options]
##
## sim: kernel/proc/proc_sim.gd, draw: proc_draw.gd, solo: proc_solo.gd (the one-process comparison).

const Wire: GDScript = preload("res://kernel/proc/proc_wire.gd")
const ROLES: Dictionary = {"sim": "res://kernel/proc/proc_sim.gd", "draw": "res://kernel/proc/proc_draw.gd", "solo": "res://kernel/proc/proc_solo.gd"}


func _ready() -> void:
	var opts: Dictionary = Wire.call("parse_args")
	var role: String = str(opts.get("role", ""))
	if not ROLES.has(role):
		print("[proc] unknown role '%s' (sim, draw, solo)" % role)
		get_tree().quit(2)
		return
	opts.erase("role")
	var w: Node = (load(str(ROLES[role])) as GDScript).new()
	w.name = "Worker"
	add_child(w)
	w.call("start", opts)
