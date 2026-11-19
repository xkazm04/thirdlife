# python docs/shifts/2026-11-19-night/lanes/hunt2/repro/C9.py
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

root = Path.cwd()
bash = "C:/Program Files/Git/bin/bash.exe"
source = Path(os.getenv("TL_GODOT", "C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe"))
with tempfile.TemporaryDirectory(dir=Path(__file__).resolve().parent) as tmp:
    base = Path(tmp)
    # The probe tests writing beside its executable. Run a lane-local copy.
    binaries = [source]
    if source.name.endswith("_console.exe"):
        binaries.append(source.with_name(source.name.replace("_console.exe", ".exe")))
    for binary in binaries:
        try:
            os.link(binary, base / binary.name)
        except OSError:
            shutil.copy2(binary, base / binary.name)
    env = dict(os.environ, APPDATA=tmp, TEMP=tmp, TMP=tmp, TL_CACHE_DIR=tmp, MSYS_NO_PATHCONV="1")
    games = base / "games"
    shutil.copytree(root / "engine/seeds/seed_paddle", games / "seed_paddle")

    def boot(*args):
        return subprocess.run([bash, "-c", 'exec timeout 180 "$@"', "qa", (base / source.name).as_posix(),
                               "--headless", "--fixed-fps", "60", "--log-file", (base / "engine.log").as_posix(),
                               "--path", (root / "engine").as_posix(), "res://boot/boot.tscn", "--", *args],
                              env=env, capture_output=True, text=True)

    tag = boot("tag")
    assert tag.returncode == 0 and "[boot] build: dev" in tag.stdout, tag
    failures = []
    for verb in ("probe", "check"):
        for blocked in (False, True):
            out = base / (verb + str(int(blocked)) + ".json")
            promised = out if verb == "probe" else Path(str(out) + ".boot.json")
            if blocked:
                promised.mkdir()
            args = ["--out=" + out.as_posix()]
            if verb == "check":
                args += ["--games=" + games.as_posix(), "--ticks=12"]
            p = boot(verb, *args)
            if p.returncode != 0:
                if blocked and p.returncode in (1, 2):
                    continue
                raise RuntimeError(p.stdout + p.stderr)
            if verb == "check":
                rows = [json.loads(line) for line in out.read_text().splitlines()]
                assert any(r.get("kind") == "world" and r["world_ticks"] == 12 and r["packs"] == 1 for r in rows), rows
            else:
                assert '"kind": "probe"' in p.stdout and "outside .gd: runs" in p.stdout, p.stdout
            if blocked:
                assert not promised.is_file()
                failures.append(verb)
            else:
                evidence = json.loads(promised.read_text())
                assert evidence["kind"] == ("boot" if verb == "check" else "probe"), evidence
    print(f"REPRO C9: FAIL {len(failures)}/2 blocked reports returned exit 0 ({', '.join(failures)}); writable controls 2/2" if failures else "REPRO C9: PASS")
    raise SystemExit(int(bool(failures)))
