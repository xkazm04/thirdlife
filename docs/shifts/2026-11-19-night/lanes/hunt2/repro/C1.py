# python docs/shifts/2026-11-19-night/lanes/hunt2/repro/C1.py
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

root = Path.cwd()
bash = "C:/Program Files/Git/bin/bash.exe"
godot = os.getenv("TL_GODOT", "C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe")
bad = []
with tempfile.TemporaryDirectory(dir=Path(__file__).resolve().parent) as tmp:
    base = Path(tmp)
    project = base / "engine"
    shutil.copytree(root / "engine", project)
    for name, key, bot, winner in [
        ("paddle", "score_to_win", "bot_win", "player"),
        ("drive", "laps_to_win", "bot_laps", "car"),
    ]:
        pack = base / name
        shutil.copytree(root / "engine/seeds" / ("seed_" + name), pack)
        rules = pack / "data/rules.json"
        data = json.loads(rules.read_text())
        target = 4 if name == "drive" else 1
        data[key] = target
        rules.write_text(json.dumps(data))
        report = base / (name + ".json")
        env = dict(os.environ, APPDATA=tmp, TEMP=tmp, TMP=tmp, TMPDIR=tmp, MSYS_NO_PATHCONV="1")
        res = subprocess.run([bash, "-c", 'exec timeout 180 "$@"', "qa", godot,
                              "--headless", "--fixed-fps", "60", "--log-file", (base / "host.log").as_posix(),
                              "--path", project.as_posix(), "res://kernel/host/host.tscn",
                              "--", "bot", "--pack=" + pack.as_posix(), "--test=tests/" + bot + ".gd",
                              "--seed=1", "--frames=12000", "--report=" + report.as_posix()],
                             env=env, capture_output=True, text=True)
        if res.returncode not in (0, 1) or not report.exists():
            raise RuntimeError(res.stdout + res.stderr)
        r = json.loads(report.read_text())
        checks = {c["id"]: c["ok"] for c in r["checks"]}
        assert checks["bot.completed"] and all(v for k, v in checks.items() if k != "bot.ok"), r
        b = r["bot"]["result"]
        if name == "paddle":
            assert b["winner"] == winner and b["player"] == target, b
        else:
            assert b["laps"] == target and "ended by laps" in b["summary"], b
            assert b["pad_visits"] >= 3 and b["nitro_starts"] >= 1 and b["cones_spawned"] >= 8, b
        assert res.returncode == int(not checks["bot.ok"])
        if not checks["bot.ok"]:
            bad.append(f"{name} target {target} met at frame {r['frames']}, verifier exit {res.returncode}")
print("REPRO C1: FAIL " + " / ".join(bad) if bad else "REPRO C1: PASS")
raise SystemExit(int(bool(bad)))
