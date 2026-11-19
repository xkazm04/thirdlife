# python docs/shifts/2026-11-19-night/lanes/hunt2/repro/B8.py
import json
import os
from pathlib import Path
import shutil
import subprocess
from tempfile import TemporaryDirectory

bash = "C:/Program Files/Git/bin/bash.exe"
root = Path.cwd()
godot = os.getenv("TL_GODOT", "C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe")
with TemporaryDirectory(dir=Path(__file__).resolve().parent) as tmp:
    base = Path(tmp)
    pack = base / "pack"
    shutil.copytree(root / "engine/kernel/examples/pack_min", pack)
    bot = "tests/bot_ladder_probe_regular.gd"
    manifest = json.loads((pack / "pack.json").read_text())
    manifest["tests"].append(bot)
    (pack / "pack.json").write_text(json.dumps(manifest))
    (pack / bot).write_text("""extends Node
func _bot_setup(_ctx) -> void:
    pass
func _bot_tick(_frame: int) -> void:
    push_error("QA measurement failed")
func _bot_done() -> bool:
    return true
func _bot_result() -> Dictionary:
    return {"ok": true, "won": false, "summary": "QA measurement failed"}
""")
    env = dict(os.environ, TL_GODOT=godot, TL_QUIET="1", TMPDIR=tmp, APPDATA=tmp)
    def run(argv):
        p = subprocess.run(argv, capture_output=True, text=True, env=env, timeout=180)
        reports = [json.loads(s) for s in p.stdout.splitlines() if s.startswith("{")]
        if not reports:
            raise RuntimeError(p.stdout + p.stderr)
        return p.returncode, reports[-1]
    code, report = run([bash, "engine/tools/tl.sh", "bot", "--pack=" + pack.as_posix(), "--test=" + bot])
    checks = {c["id"]: c["ok"] for c in report["checks"]}
    assert code == 1 and not report["ok"] and checks["bot.completed"] and checks["bot.ok"] and not checks["smoke.no_script_errors"]
    code, ladder = run(["node", "devx/bin/tl.mjs", "ladder", "--pack", pack.as_posix(), "--seeds", "1"])
    step = ladder["steps"][0]
    if code not in (0, 1) or step["found"] != 1:
        raise RuntimeError(f"unexpected ladder result: {code} {step}")
    failed = code == 0 and step["ok"] and step["completed"] == 1
    if not failed and (code != 1 or step["ok"]):
        raise RuntimeError(f"inconsistent ladder verdict: {code} {step}")
    print("REPRO B8: FAIL bot exited 1 with smoke.no_script_errors=false; ladder credited 1/1 and exited 0" if failed else "REPRO B8: PASS")
    raise SystemExit(int(failed))
