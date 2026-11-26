extends RefCounted
## SEAM (spark world-sandbox): what a build-mode tool that is not built yet does: nothing. It names its milestone in
## the hotbar ("<Title>: coming in M2") and takes no key or button. The stubs (sculpt, paint, piece, stamp, command)
## extend this; a lane replaces its stub's file with the real tool (BUILD.md "Tools", LANES.md) and drops the extends.

const KEY_HELP := "T next tool   Shift+T previous tool   Ctrl+Z undo   Ctrl+Y redo   hold MMB or Alt look   B or Esc leave"

var id := "stub"
var title := "Stub"
var milestone := "M?"
var host: Node = null                   # build_mode.gd


func setup(h: Node) -> void:
	host = h


func polled() -> Array:
	return []


func selected(_on: bool) -> void:
	pass


func slots() -> Array:
	return []


func status() -> Dictionary:
	return {"info": "%s: coming in %s" % [title, milestone], "dim": true, "reason": ""}


func hint() -> String:
	return KEY_HELP


func blocks_input() -> bool:
	return false


func key(_e: InputEvent) -> bool:
	return false


func aim(_h: Dictionary, _mode: Dictionary) -> void:
	pass


func ghost_state() -> Dictionary:
	return {}


func press(_button: int, _mods: Dictionary) -> bool:
	return false


func drag(_h: Dictionary) -> void:
	pass


func release(_button: int) -> void:
	pass


func dragging() -> bool:
	return false


func tick(_frame: int) -> void:
	pass
