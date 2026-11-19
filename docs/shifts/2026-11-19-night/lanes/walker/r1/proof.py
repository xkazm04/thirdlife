"""Run block 360 headless with just the historical WorldSpace and visitor, then restore both."""
from pathlib import Path
import hashlib
import os
import re
import shutil
import subprocess
import tempfile
import time

root = Path.cwd()
base = "c8b88fc683b057c5523c883efd07ffc84c95ae2e"
paths = ("engine/kernel/world/terrain/world_space.gd", "engine/kernel/world/visitor.gd")
evidence = Path(__file__).resolve().parent
cache = root / ".tl/walker/review"
cache.mkdir(parents=True, exist_ok=True)
old = [subprocess.check_output(["git", "--no-optional-locks", "show", f"{base}:{path}"]) for path in paths]
fixed = [(root / path).read_bytes() for path in paths]

with tempfile.TemporaryDirectory(dir=cache) as tmp:
    work = Path(tmp)
    shutil.copytree(root / "engine", work / "engine")
    for label, sources, expected in [("old", old, 1), ("restored", fixed, 0)]:
        hashes = []
        for path, data in zip(paths, sources):
            (work / path).write_bytes(data)
            hashes.append(f"{path} sha256={hashlib.sha256(data).hexdigest()}")
        out = work / label
        env = dict(os.environ, APPDATA=tmp, LOCALAPPDATA=tmp, TL_SELFTEST_DIR=out.as_posix())
        start = time.perf_counter()
        run = subprocess.run([shutil.which("bash"), "engine/tools/selftest.sh", "walker.crown"], cwd=work, env=env,
                             stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        elapsed = time.perf_counter() - start
        message = run.stdout.decode(errors="replace").replace("\r", "")
        proof = "\n".join(hashes) + f"\n{message}exit={run.returncode} seconds={elapsed:.3f}\n"
        (evidence / f"review-proof-{label}.log").write_text(proof, encoding="utf-8")
        log = (out / "walker-crown.log").read_text(encoding="utf-8", errors="replace")
        (evidence / f"review-proof-{label}-godot.log").write_text(log, encoding="utf-8")
        print(proof, flush=True)
        verdict = "FAIL" if label == "old" else "ok"
        match = re.search(rf"^CROWNCASE regression {verdict} frames=34560 poses=2880 head_out=\[(\d+), (\d+), (\d+)\]", log, re.M)
        if (not match or int(match[1]) == 0 or (int(match[3]) > 0) != (label == "old") or
                run.returncode != expected or "SCRIPT ERROR" in log or "\nERROR:" in log):
            raise SystemExit("Regression proof failed")
