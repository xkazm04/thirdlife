extends Node
## Deliberately bad: this bot is never done, so the frame budget stops it (exit code 3, outcome "watchdog").


func _bot_setup(_ctx) -> void:
	pass


func _bot_tick(_frame: int) -> void:
	pass


func _bot_done() -> bool:
	return false


func _bot_result() -> Dictionary:
	return {"ok": false, "summary": "never done"}
