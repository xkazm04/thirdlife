extends SceneTree
## Lane H2b (25 Nov): the effect boost's glow reaches the figure (boost_look.gd sync, IJamSkaterVisual::SetBoost from
## UJamEffectSystem::GetBoostKindFor, HokejGameMode.cpp:1696-1703), from the snapshot's `Boosts` (RinkCore 1.4).
##   godot --headless --path engine --script res://cores/rink/view/boost_glow_case.gd
## Two pawns that record their figure calls, five frames of Boosts: none, speed on 0, still speed on 0, precision on 1 and
## nothing on 0, then a snapshot without the key (a core before 1.4). The figure is told on a change only:
## [0 speed], [], [0 "", 1 precision], [1 ""]; a skater never boosted is never called. Prints `BOOSTGLOW ok=true|false ...`.

const Boost := preload("res://cores/rink/view/boost_look.gd")


class Pawn:
	extends RefCounted
	var sim_index: int = 0
	var calls: Array = []
	func call_figure(fname: StringName, args: Array) -> bool:
		calls.append("%d %s %s" % [sim_index, String(fname), String(args[0]) if not args.is_empty() else ""])
		return true


func _initialize() -> void:
	var b := Boost.new()
	var pawns: Array = []
	for i: int in 2:
		var p := Pawn.new()
		p.sim_index = i
		pawns.append(p)
	var sk: Array = []
	for i: int in 2:
		sk.append({"AbilitySlot": -1, "AbilityArmed": "", "ShieldFrames": 0})
	var frames: Array = [["", ""], ["speed", ""], ["speed", ""], ["", "precision"], null]
	var got: Array = []
	for fr: Variant in frames:
		var snap: Dictionary = {"Skaters": sk, "Frame": got.size()}
		if fr != null:
			snap["Boosts"] = fr
		for p: Pawn in pawns:
			p.calls.clear()
		b.sync(snap, pawns)
		var c: Array = []
		for p: Pawn in pawns:
			c.append_array(p.calls)
		got.append("[" + ", ".join(c) + "]")
	var want: Array = ["[]", "[0 SetBoost speed]", "[]", "[0 SetBoost , 1 SetBoost precision]", "[1 SetBoost ]"]
	var ok: bool = got == want
	print("BOOSTGLOW ok=%s calls %s (want %s)" % [str(ok), " ".join(got), " ".join(want)])
	quit(0 if ok else 1)
