"""From the repo root: python .../terrain/capture.py head|r3b|after bank|bluff."""
import os
from pathlib import Path
import subprocess
import sys

here = Path(__file__).resolve().parent
stage, place = sys.argv[1:]
if stage not in ("head", "before", "r3b", "after"):
    raise SystemExit("choose head, before (R3), r3b, or after")
walk, last = {"bank": ("wf_feel", 310), "bluff": ("wf_bluff", 120)}[place]
scratch = here / "captures"
scratch.mkdir(exist_ok=True)
out = scratch / stage
out.mkdir(exist_ok=True)
script = scratch / f"terrain-{os.getpid()}.gd"
script.write_bytes((here / "sample.gd.txt").read_bytes())
godot = os.environ.get("TL_GODOT", "C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe")
log = here / f"{stage}-{place}.log"
cmd = [godot, "--path", "engine", "--fixed-fps", "60", "--position", "0,1440", "--resolution", "1920x1080",
       "--rendering-driver", "d3d12", "--audio-driver", "Dummy", "--quit-after", str(last + 12),
       "--script", str(script), "res://kernel/host/host.tscn", "--", "world-view",
       f"--walk=res://kernel/world/walks/{walk}.json", "--live", f"--ticks={last + 2}",
       f"--devices={here.parent.as_posix()}/{place}.devices.json", "--cost=model", "--load=block",
       "--out-dir=" + out.as_posix()]
try:
    override = {}
    if stage == "head":
        for name in ("toon", "ink_post"):
            source = subprocess.check_output(["git", "show", f"HEAD:engine/style/shaders/{name}.gdshader"])
            path = scratch / f"{script.stem}-{name}.txt"
            path.write_bytes(source)
            override["TERRAIN_" + name.upper()] = path.as_posix()
    elif stage == "r3b":
        override["TERRAIN_INK_POST"] = (here / "r3b-reviewed.gdshader.txt").as_posix()
    with log.open("w") as f:
        subprocess.run(cmd, stdout=f, stderr=subprocess.STDOUT, check=True,
                       env=dict(os.environ, TL_LAND_NOW="1", TERRAIN_PLACE=place, TERRAIN_STAGE=stage, TERRAIN_OUT=out.as_posix(),
                                TERRAIN_BASE=(here / "r3-before.gdshader.txt").as_posix(), **override))
    result = log.read_text(errors="replace")
    if f"TERRAIN_DONE {place} frames=32" not in result or "ERROR:" in result:
        raise ValueError(result[-2500:])
    print(stage, place, "complete")
finally:
    script.unlink()
    for name in ("toon", "ink_post"):
        (scratch / f"{script.stem}-{name}.txt").unlink(missing_ok=True)
