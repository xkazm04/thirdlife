"""python engine/kernel/world/walks/blink_detect_check.py: blink_detect.py's own check (bugfix-37). Needs numpy and PIL.
Builds tiny synthetic captures (.raw + frames.jsonl, as boot.gd TL_EXE_FRAMES writes them), runs the detector and prints
one PASS/FAIL line per claim; exit 0 only when every claim held.
  erosion.cross   14 five-pixel crosses shown for one frame: no full 3x3 block, so no event (was 14 px with 4 neighbours)
  erosion.block   the control: one 6x6 block shown for one frame is an event of 16 px (its 4x4 core)
  skymask.flag    a mask capture looking down with 50 sky pixels, read with --skymask: the grey court is not sky and
                  there is no hole (was 2964 hole px: the colour guess, with no way to say the mask was on)
  skymask.many    the control: 51 magenta pixels are recognised without the flag, as before
  resize          a capture that changes size mid-run is read to the end with its totals line (was a traceback)"""
import json
import subprocess
import sys
from pathlib import Path
from tempfile import TemporaryDirectory

import numpy as np

DETECT = Path(__file__).with_name("blink_detect.py")


def run(folder: Path, pictures: list, rows: list, extra: tuple = ()) -> dict:
    for n, a in enumerate(pictures):
        a.tofile(folder / ("f%05d.raw" % n))
    (folder / "frames.jsonl").write_text("".join(json.dumps(r) + "\n" for r in rows))
    out = subprocess.run([sys.executable, "-B", str(DETECT), str(folder), "--json", *extra], capture_output=True, text=True)
    lines = [json.loads(x) for x in out.stdout.splitlines() if x.startswith("{")]
    total = next((x for x in lines if x.get("report") == "blinks"), None)
    return {"exit": out.returncode, "total": total, "events": [x for x in lines if "px" in x]}


def flash(mask: np.ndarray) -> list:
    pics = []
    for n in range(3):
        a = np.zeros(mask.shape + (3,), np.uint8)
        if n == 1:
            a[mask] = (255, 0, 0)
        pics.append(a)
    return pics


def court(sky_px: int) -> np.ndarray:
    a = np.zeros((270, 480, 3), np.uint8)
    a[180:220, 100:180] = (190, 190, 190)
    a[2, :sky_px] = (255, 0, 255)
    return a


results = []
with TemporaryDirectory(prefix="blink_check_") as tmp:
    root = Path(tmp)
    rows3 = [{"n": n, "frame": n + 1, "size": [50, 20]} for n in range(3)]
    cross = np.zeros((20, 50), bool)
    for y in (5, 12):
        for x in range(4, 41, 6):
            cross[y - 1:y + 2, x] = True
            cross[y, x - 1:x + 2] = True
    (root / "a").mkdir()
    r = run(root / "a", flash(cross), rows3)
    px = sum(e["px"] for e in r["events"])
    results.append(("erosion.cross", r["exit"] == 0 and px == 0, "surviving px %d" % px))
    block = np.zeros((20, 50), bool)
    block[6:12, 20:26] = True
    (root / "b").mkdir()
    r = run(root / "b", flash(block), rows3)
    px = sum(e["px"] for e in r["events"])
    results.append(("erosion.block", r["exit"] == 0 and px == 16, "event px %d" % px))
    for name, sky_px, extra in (("skymask.flag", 50, ("--skymask",)), ("skymask.many", 51, ())):
        (root / name).mkdir()
        row = {"n": 0, "frame": 1, "look": [0, 0, -1], "fov": 60, "size": [480, 270]}
        r = run(root / name, [court(sky_px)], [row], extra)
        t = r["total"] or {}
        results.append((name, r["exit"] == 0 and t.get("sky_mask") is True and t.get("hole_frames") == 0,
                        "sky_mask %s, hole px %s" % (t.get("sky_mask"), t.get("hole_px_max"))))
    (root / "r").mkdir()
    sizes = (960, 960, 800)
    r = run(root / "r", [np.zeros((540, wd, 3), np.uint8) for wd in sizes],
            [{"n": n, "frame": n + 1, "size": [wd, 540], "look": [0, 0, -1], "fov": 60} for n, wd in enumerate(sizes)])
    t = r["total"] or {}
    results.append(("resize", r["exit"] == 0 and t.get("frames") == 3, "exit %d, frames %s" % (r["exit"], t.get("frames"))))

fails = 0
for name, ok, figs in results:
    fails += 0 if ok else 1
    print("%s blink.%s  (%s)" % ("PASS" if ok else "FAIL", name, figs))
print("blink_detect_check: %d of %d passed" % (len(results) - fails, len(results)))
sys.exit(0 if fails == 0 and len(results) == 5 else 1)
