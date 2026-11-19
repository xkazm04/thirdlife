# python docs/shifts/2026-11-19-night/lanes/hunt2/repro/C8.py
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

root = Path.cwd()
godot = os.getenv("TL_GODOT", "C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe")
bash = "C:/Program Files/Git/bin/bash.exe"
accepted = []
with tempfile.TemporaryDirectory(dir=Path(__file__).resolve().parent) as tmp:
    base = Path(tmp)
    project = base / "engine"
    shutil.copytree(root / "engine", project)
    env = dict(os.environ, APPDATA=tmp, TMP=tmp, TEMP=tmp, MSYS_NO_PATHCONV="1")
    for name, section, key in [("drive", "cones", "mass"), ("paddle", "rival", "speed"), ("wall", "wall", "hp")]:
        pack = base / name
        shutil.copytree(root / "engine/seeds" / ("seed_" + name), pack)
        path = pack / "data/tuning.json"
        tune = json.loads(path.read_text())
        typo = key + "_typo"
        tune[section][typo] = tune[section][key]
        path.write_text(json.dumps(tune))
        report = base / (name + ".json")
        p = subprocess.run([bash, "-c", 'exec timeout 180 "$@"', "qa", godot, "--headless",
                            "--fixed-fps", "60", "--log-file", (base / "host.log").as_posix(),
                            "--path", project.as_posix(), "res://kernel/host/host.tscn",
                            "--", "smoke", "--frames=20", "--pack=" + pack.as_posix(),
                            "--report=" + report.as_posix()], env=env, capture_output=True, text=True)
        if p.returncode not in (0, 1) or not report.is_file():
            raise RuntimeError(p.stdout + p.stderr)
        r = json.loads(report.read_text())
        if p.returncode == 0:
            assert r["frames"] == 20 and r["ok"] and r["checks"] and all(c["ok"] for c in r["checks"]), r
            accepted.append(name + "." + section + "." + typo)
        elif not any(typo in str(error) for error in r["errors"]):
            raise RuntimeError(r)
print(f"REPRO C8: FAIL {len(accepted)}/3 unknown tuning keys passed 20-frame smoke: " + ", ".join(accepted) if accepted else "REPRO C8: PASS")
raise SystemExit(int(bool(accepted)))
