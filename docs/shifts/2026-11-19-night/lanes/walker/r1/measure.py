"""Run from the worktree root with a phase (before, submitted, after) and a case.
The sweep, pitch, wf_canopy and tour cases use the drawn-foliage oracle. The build
case runs three fresh villages on submitted/after. Set TL_CROWN_QUIET=1 to hold
each crown lap until other Godot processes have exited. Only crowns_ms excludes
that scheduling wait. Every reconstruction and measurement lives in the worktree.
"""
import io
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time
import tempfile
import zipfile

BASE = "c8b88fc683b057c5523c883efd07ffc84c95ae2e"
ROOT = Path.cwd()
CACHE = ROOT / ".tl" / "walker" / "review"
EVIDENCE = Path(__file__).resolve().parent
WALKS = Path("kernel/world/walks")


def project(work, phase):
    engine = work / "engine"
    if phase == "before":
        archive = subprocess.check_output(["git", "--no-optional-locks", "archive", "--format=zip", BASE, "engine"])
        with zipfile.ZipFile(io.BytesIO(archive)) as files:
            files.extractall(work)
        shutil.copytree(ROOT / "engine/.godot", engine / ".godot")
    else:
        shutil.copytree(ROOT / "engine", engine)
        if phase == "submitted":
            # The only review changes affecting village runs are these production files.
            for name in ("landscape.gd", "terrain/crown_camera.gd"):
                shutil.copy2(EVIDENCE / "submitted" / (Path(name).name + ".txt"), engine / "kernel/world" / name)
    shutil.copy2(ROOT / "engine" / WALKS / "crown_oracle.gd", engine / WALKS / "crown_oracle.gd")
    shutil.copy2(EVIDENCE / "village.gd.txt", engine / WALKS / "crown_village_evidence.gd")
    return engine


def time_avoid(engine, phase):
    source = engine / ("kernel/api/tl_chase_cam.gd" if phase == "before" else "kernel/world/terrain/crown_camera.gd")
    s = source.read_text()
    decl = "func _avoid(now: bool) -> void:"
    assert s.count(decl) == 1
    s = s.replace("super(now)", "super._avoid(now)")
    wrapper = """var review_calls := 0
var review_total := 0
var review_worst := 0
var review_arm := Vector3.ZERO
var review_head := Vector3.ZERO

func _avoid(now: bool) -> void:
	review_head = _frame().affine_inverse() * _look
	review_arm = position - review_head
	var begin := Time.get_ticks_usec()
	_review_original_avoid(now)
	var elapsed := Time.get_ticks_usec() - begin
	review_calls += 1
	review_total += elapsed
	review_worst = maxi(review_worst, elapsed)

func _review_original_avoid(now: bool) -> void:"""
    source.write_bytes(s.replace(decl, wrapper).encode())


def cold_build(args, env, work):
    # Snapshot other Godot process lifetimes across the actual lap. Never change a process.
    import psutil
    landscape = work / "engine/kernel/world/landscape.gd"
    source = landscape.read_text()
    begin = '\tws.call("finish")'
    end = '\t_lap(stats, "crowns")'
    assert source.count(begin) == source.count(end) == 1
    quiet = env.get("TL_CROWN_QUIET") == "1"
    ready = work / "lap-ready"
    pause = ""
    if quiet:
        pause = (f'\tFileAccess.open("{ready.as_posix()}", FileAccess.WRITE).close()\n'
                 '\tOS.read_buffer_from_stdin(1)\n\tstats["_lap"] = Time.get_ticks_usec()\n')
    landscape.write_bytes(source.replace(begin, pause + '\tvar review_start := Time.get_unix_time_from_system()\n' + begin)
        .replace(end, end + '\n\tprint("CROWN clock %.6f %.6f" % [review_start, Time.get_unix_time_from_system()])').encode())
    samples = []
    with (work / "console.log").open("wb") as output:
        proc = subprocess.Popen(args, stdin=subprocess.PIPE, stdout=output, stderr=subprocess.STDOUT, env=env)
        while proc.poll() is None:
            snapshot = {}
            for other in psutil.process_iter(["name"]):
                if "godot" in (other.info["name"] or "").lower() and other.pid != proc.pid:
                    try:
                        if other.ppid() != proc.pid:
                            snapshot[other.pid] = other.create_time()
                    except psutil.NoSuchProcess:
                        continue
            if quiet and ready.exists() and not snapshot and not proc.stdin.closed:
                proc.stdin.write(b"g")
                proc.stdin.close()
            samples.append((time.time(), snapshot))
            time.sleep(0.05 if quiet and not proc.stdin.closed and snapshot else 0.01)
    log = (work / "console.log").read_bytes()
    clocks = [l for l in log.decode(errors="replace").splitlines() if l.startswith("CROWN clock ")]
    if clocks:
        start, end = map(float, clocks[0].split()[2:])
        foreign = set()
        observed = sum(start <= t <= end for t, _ in samples)
        for timepoint, snapshot in samples:
            if timepoint >= start:
                foreign.update(pid for pid, born in snapshot.items() if born <= end)
                if timepoint >= end:
                    break
        log += f"REVIEW build process_samples_during_lap={observed} concurrent_godot_pids={sorted(foreign)}\n".encode()
        if quiet and (foreign or observed < 2):
            return subprocess.CompletedProcess(args, 3, log)
    return subprocess.CompletedProcess(args, proc.returncode if clocks else 2, log)


def run(phase, case, label=None):
    CACHE.mkdir(parents=True, exist_ok=True)
    godot = os.environ.get("TL_GODOT", "C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe")
    env = dict(os.environ, APPDATA=str(CACHE), LOCALAPPDATA=str(CACHE))
    with tempfile.TemporaryDirectory(dir=CACHE) as tmp:
        work = Path(tmp)
        engine = project(work, phase)
        time_avoid(engine, phase)
        script = "res://kernel/world/walks/crown_village_evidence.gd"
        mode = case
        if case in ("pitch", "build"):
            script = work / (case + ".gd")
            shutil.copy2(EVIDENCE / (case + ".gd.txt"), script)
            mode = "sweep"
        args = [godot, "--position", "0,1440", "--resolution", "320x180", "--audio-driver", "Dummy",
                "--fixed-fps", "60", "--disable-render-loop", "--quit-after", "3200", "--path", str(engine),
                "--log-file", str(work / "godot.log"), "--script", str(script), "--", mode]
        result = cold_build(args, env, work) if case == "build" else subprocess.run(
            args, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, env=env)
    log = result.stdout.decode("utf-8", errors="replace").replace("\r", "")
    (EVIDENCE / f"review-{phase}-{label or case}.log").write_text(log, encoding="utf-8")
    lines = [l for l in log.splitlines() if l.startswith(("REVIEW", "CROWNCASE", "SCRIPT ERROR", "ERROR:"))]
    print("\n".join(lines), flush=True)
    if ("SCRIPT ERROR" in log or "\nERROR:" in log or not any(l.startswith("CROWNCASE ") for l in lines)):
        return 2
    return result.returncode


if __name__ == "__main__":
    if len(sys.argv) != 3 or sys.argv[1] not in ("before","submitted","after") or sys.argv[2] not in ("sweep","wf_canopy","tour","pitch","build"):
        sys.exit(2)
    phase, case = sys.argv[1:]
    if case == "build":
        if phase == "before":
            print("The cylinder baseline has no crown build lap", file=sys.stderr)
            sys.exit(2)
        for number in range(1, 4):
            label = ("quiet-" if os.environ.get("TL_CROWN_QUIET") == "1" else "") + f"build-{number}"
            result = run(phase, case, label)
            while result == 3 and os.environ.get("TL_CROWN_QUIET") == "1":
                result = run(phase, case, label)
            if result:
                sys.exit(result)
    else:
        sys.exit(run(phase, case))
