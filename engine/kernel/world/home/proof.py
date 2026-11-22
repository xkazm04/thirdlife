"""Compare the window's complete 256-bit hashes with fresh runner processes."""
import json
import os
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parents[4]
raw = root / ".tl" / "home-a" / f"round-{int(sys.argv[1])}"
lines = (raw / "window-0.log").read_text(encoding="utf-8").splitlines()
rows = [json.loads(line) for line in lines if line.startswith('{"schema":"tl.world/1"')]
world, = [row for row in rows if row["kind"] == "world"]
assert world["packs"] == 8 and world["world_ticks"] > 0 and not world["errors"]
packs = [row for row in rows if row["kind"] == "pack"]
walk = json.loads((raw / "walk.json").read_text(encoding="utf-8"))
assert {p["plot"] for p in packs} == {p["id"] for p in walk["plots"]} and len(packs) == 8
reports = []
for row in packs:
    directory = Path(row["dir"]).resolve()
    assert directory.is_relative_to(root) and row["frames"] > 0 and row["loaded"]
    assert not row["restored"] and row["script_errors"] == row["engine_errors"] == 0
    path = raw / ("alone-" + row["plot"] + ".json")
    cmd = ["C:/Program Files/Git/bin/bash.exe", str(root / "engine/tools/tl.sh"), row["mode"],
           f"--pack={directory.as_posix()}", f"--seed={row['seed']}", f"--frames={row['frames']}",
           f"--report={path.as_posix()}"]
    result = subprocess.run(cmd, capture_output=True, cwd=root, env={**os.environ, "TL_QUIET":"1"})
    (raw / ("alone-" + row["plot"] + ".log")).write_bytes(result.stdout + result.stderr)
    solo = json.loads(path.read_text(encoding="utf-8"))
    # Bot report may judge a short play horizon insufficient for a win. Require a completed worker,
    # the full requested frame count, and exact state identity independently of the bot's win condition.
    assert result.returncode in (0,1) and solo["outcome"] in ("passed","failed"), solo
    metrics = solo.get("metrics", solo)
    state = metrics.get("state_hash", solo.get("state_hash"))
    ticks = metrics.get("frames", solo.get("frames"))
    ok = (len(row["state_hash"]) == 64 and state == row["state_hash"] and ticks == row["frames"])
    reports.append({"plot":row["plot"],"ticks":row["frames"],"world":row["state_hash"],"alone":state,"alone_ticks":ticks,"ok":ok})
    print(("PASS" if ok else "FAIL"), row["plot"], ticks, state, flush=True)
(raw / "proof.json").write_text(json.dumps(reports, indent=2)+"\n", encoding="utf-8")
passed = sum(r["ok"] for r in reports)
print(f"{'PASS' if passed==8 else 'FAIL'} home.a.alone {passed}/8")
sys.exit(0 if passed==8 else 1)
