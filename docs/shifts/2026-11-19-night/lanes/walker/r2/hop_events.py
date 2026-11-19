"""Run bugfix-37's unchanged hop schedule and count same-tick land/jump events as well as final modes."""
import os
import subprocess
import sys
from pathlib import Path

root = Path.cwd()
source = (root / "docs/reports/bugfix-37/walker/hop_probe.gd.txt").read_text()
changes = {
    "var mset: Dictionary = {}": "var mset: Dictionary = {}\n\t\t\tvar lands := 0\n\t\t\tvar jumps := 0",
    'f = r2["pos"]': 'f = r2["pos"]\n\t\t\t\tlands += int(r2.events.has("land"))\n\t\t\t\tjumps += int(r2.events.has("jump"))',
    "line2.append(": 'print("EVENTS wall=%d every=%d land=%d jump=%d top=%.2f out=%d" % [deg, every, lands, jumps, top2, out])\n\t\t\tline2.append(',
}
for old, new in changes.items():
    assert source.count(old) == 1, old
    source = source.replace(old, new)
script = root / ".tl/walker-r2/hop_events.gd"
script.parent.mkdir(parents=True, exist_ok=True)
script.write_text(source, encoding="utf-8")
godot = os.environ.get("TL_GODOT", "C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe")
run = subprocess.run([godot, "--headless", "--path", root / "engine", "--script", script],
                     stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, env=dict(os.environ, HOP_OLD="0"))
print(run.stdout, end="")
sys.exit(run.returncode or int(run.stdout.count("EVENTS wall=") != 8 or "ERROR:" in run.stdout))
