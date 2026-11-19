"""Run from the worktree root, e.g. python .../capture.py before behind bluff."""
import os
from pathlib import Path
import subprocess
import sys

here = Path(__file__).resolve().parent
stage, *places = sys.argv[1:]
places = places or ["behind", "behind_wall", "three", "three_wall", "side", "side_wall", "bluff", "bank", "grazing", "frozen"]
out = here / stage
out.mkdir(exist_ok=True)
godot = os.environ.get("TL_GODOT", "C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe")
scratch = here / "captures"
scratch.mkdir(exist_ok=True)
script = scratch / f"probe-{os.getpid()}.gd"
script.write_bytes((here / "probe.gd.txt").read_bytes())
baseline = out / f"baseline-{os.getpid()}.txt"
try:
    if stage == "before":
        ref = "c8b88fc683b057c5523c883efd07ffc84c95ae2e:engine/style/shaders/ink_post.gdshader"
        baseline.write_bytes(subprocess.check_output(["git", "show", ref]))
    for place in places:
        args = ["--speed=4.5", "--view=" + place.split("_")[0]]
        if place == "frozen":
            args = ["--speed=4.5", "--view=behind", "--freeze-at=90"]
        if place in ("bluff", "bank"):
            walk = "wf_bluff" if place == "bluff" else "wf_feel"
            args = ["world-view", f"--walk=res://kernel/world/walks/{walk}.json", "--live",
                    f"--devices={here.as_posix()}/{place}.devices.json", "--ticks=" + ("312" if place == "bank" else "122"), "--cost=model", "--load=block",
                    "--out-dir=" + out.as_posix()]
        cmd = [godot, "--path", "engine", "--fixed-fps", "60", "--position", "0,1440", "--resolution", "1920x1080",
               "--rendering-driver", "d3d12", "--audio-driver", "Dummy", "--quit-after", "390",
               "--script", str(script), *(["res://kernel/host/host.tscn"] if place in ("bluff", "bank") else []), "--", *args]
        env = dict(os.environ, TL_LAND_NOW="1", INK_PLACE=place, INK_OUTPUT=out.as_posix())
        if stage == "before":
            env["INK_BASELINE"] = baseline.as_posix()
        if stage == "plane":
            env["INK_PLANE"] = (here / "plane.gdshader.txt").as_posix()
        with (out / (place + ".log")).open("w") as log:
            subprocess.run(cmd, stdout=log, stderr=subprocess.STDOUT, check=True,
                           env=env)
        result = (out / (place + ".log")).read_text(errors="replace")
        if "INK_SAMPLE_DONE " + place not in result or "ERROR:" in result:
            raise SystemExit(result[-4000:])
        print(stage, place, "captured", flush=True)
finally:
    baseline.unlink(missing_ok=True)
    script.unlink(missing_ok=True)
