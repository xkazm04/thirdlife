"""Matched, unencoded bluff-band control for the small difference between the x264 clips."""
from pathlib import Path
import os
import subprocess
import numpy as np

here = Path(__file__).resolve().parent
out = here / "paired"
out.mkdir(exist_ok=True)
scratch = here / "captures"
scratch.mkdir(exist_ok=True)
script = scratch / f"paired-{os.getpid()}.gd"
script.write_bytes((here / "paired.gd.txt").read_bytes())
baseline = out / "previous.txt"
baseline_ref = "c8b88fc683b057c5523c883efd07ffc84c95ae2e:engine/style/shaders/ink_post.gdshader"
baseline.write_bytes(subprocess.check_output(["git", "show", baseline_ref]))
godot = os.environ.get("TL_GODOT", "C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe")
try:
    with (out / "world.log").open("w") as log:
        subprocess.run([godot, "--path", "engine", "--fixed-fps", "60", "--position", "0,1440", "--resolution", "1920x1080",
                        "--rendering-driver", "d3d12", "--audio-driver", "Dummy", "--quit-after", "200",
                        "--script", str(script), "res://kernel/host/host.tscn", "--", "world-view",
                        "--walk=res://kernel/world/walks/wf_bluff.json", "--live", "--ticks=155",
                        f"--devices={here.as_posix()}/bluff.devices.json", "--cost=model", "--load=block",
                        "--out-dir=" + out.as_posix()], check=True, stdout=log, stderr=subprocess.STDOUT,
                       env=dict(os.environ, INK_OUTPUT=out.as_posix(), TL_LAND_NOW="1"))
    lines = (out / "world.log").read_text(errors="replace").splitlines()
    marker, = [line for line in lines if line.startswith("PAIRED frames=106 ")]
    if int(marker.split("=")[-1]) == 0 or any("ERROR:" in line for line in lines):
        raise ValueError("invalid control or capture error")
    print(marker)
    paths = [out / "before.rgb", out / "after.rgb"]
    arrays = [np.memmap(p, np.uint8, "r").reshape(106, 220, 1920, 3) for p in paths]
    changed = sum(np.any(a != b, axis=-1).sum() for a, b in zip(*arrays))
    print(f"band pixels different before/after = {changed} of {106*220*1920}")
    for label, frames in zip(["before", "after"], arrays):
        total = flips = 0
        previous = None
        for rgb in frames:
            grey = np.rint(rgb @ np.array([0.299, 0.587, 0.114])).astype(np.int16)
            if previous is not None:
                delta = np.abs(grey - previous)
                total += delta.sum()
                flips += (delta > 24).sum()
            previous = grey
        n = 105 * 220 * 1920
        print(f"{label} mean={total/n:.6f} flips_pct={100*flips/n:.6f}")
    for frames in arrays:
        frames._mmap.close()
    for p in paths:
        p.unlink()
finally:
    script.unlink(missing_ok=True)
    baseline.unlink(missing_ok=True)
