extends SceneTree
## L3 (night of 21 Nov 2026): the kernel selftest block 630 (tools/selftest.d/630-create.sh) runs the Create page's
## checks (ui/create/create_checks.gd) headless and prints one "PASS <name>" or "FAIL <name>  -> <why>" line each,
## then "[create] <n> passed, <m> failed".

const CreateChecks = preload("res://ui/create/create_checks.gd")

var passed: int = 0
var failed: int = 0


func _initialize() -> void:
	var tmp: String = OS.get_user_data_dir().path_join("tl_create_case_%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(tmp)
	var done: Variant = await CreateChecks.run(self, _check, tmp)
	if done != true:
		_check("create.complete: the checks ran to their end", false, "stopped half way (a script error above)")
	DirAccess.remove_absolute(tmp)
	print("[create] %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 and passed > 0 else 1)


func _check(name: String, ok: bool, detail: String = "") -> void:
	if ok:
		passed += 1
		print("PASS %s" % name)
	else:
		failed += 1
		print("FAIL %s%s" % [name, ("  -> " + detail) if not detail.is_empty() else ""])
