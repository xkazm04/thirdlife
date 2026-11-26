extends "res://kernel/world/build/tools/stub_tool.gd"
## SEAM stub of build mode's command tool (M4 fills this file: the LLM command bar, contracts/BUILD.md "The LLM
## command bar"). Enter is reserved for it: build mode picks this tool and hands it the Enter key. The stub shows a
## disabled line in the hotbar and does nothing. M4's bar takes the keyboard while it is open: `blocks_input()` true
## (build mode then reads no key of its own), Esc and Enter are the bar's. The tool interface is BUILD.md "Tools".

var opened := false                     # Enter was pressed (the stub shows its disabled line)


func _init() -> void:
	id = "command"
	title = "Command"
	milestone = "M4"


func polled() -> Array:
	return [KEY_ENTER, KEY_KP_ENTER]


func selected(on: bool) -> void:
	if not on:
		opened = false


func key(e: InputEvent) -> bool:
	var k := e as InputEventKey
	if k != null and k.pressed and (k.physical_keycode == KEY_ENTER or k.physical_keycode == KEY_KP_ENTER):
		opened = true
		return true
	return false


func status() -> Dictionary:
	if opened:
		return {"info": "> describe what to build (the command bar is coming in M4)", "dim": true, "reason": ""}
	return super.status()
