"""Run one D5 observation from the worktree root with the project's own Godot."""

import os
import subprocess
import sys
import tempfile
from pathlib import Path


CASES = ("record", "coldpad", "cover", "canopy", "bank", "gate", "flatpad", "option", "filter")


def run_case(base, cache, env, name):
    args = list(base)
    script = Path(__file__).with_name("cases.gd").resolve()
    if name in {"flatpad", "coldpad"}:
        # Landscape.build skips the terrain and its physics space in headless mode.
        args[1:2] = ["--position", "0,1440", "--resolution", "320x180", "--audio-driver", "Dummy"]
        script = script.with_name("pad.gd")
    args.extend(["--fixed-fps", "60", "--quit-after", "500"])
    if name == "filter":
        args.extend(["--script", "res://kernel/world/walks/walk_case.gd", "--", "walk.jump"])
    else:
        args.extend(["--script", str(script), "--", name])
    with tempfile.TemporaryDirectory(dir=cache) as directory:
        result = subprocess.run(args, env=dict(env, D5_OUTPUT=directory), stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT)
    lines = result.stdout.decode("utf-8", errors="replace").replace("\r", "").splitlines()
    for line in lines:
        print(line)
    if name == "filter":
        print(f"godot_exit={result.returncode}")
        return "WALKCASE done 0 0" in lines and result.returncode == 0
    # The avoid_min case deliberately exercises one rejected public option.
    errors = [line for line in lines if "ERROR:" in line and
              not (name == "option" and "unknown option 'avoid_min'" in line)]
    return result.returncode == 0 and not errors and f"REPRODUCED {name}" in lines


def main():
    root = Path.cwd()
    engine = root / "engine"
    if (not (engine / "project.godot").is_file() or len(sys.argv) != 2
            or sys.argv[1] not in (*CASES, "all")):
        sys.exit(f"Run from the worktree root. Choose all or one of: {', '.join(CASES)}")
    gd = os.environ.get("TL_GODOT") or "C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe"
    cache = root / ".tl" / "astra-b"
    cache.mkdir(parents=True, exist_ok=True)
    env = dict(os.environ, APPDATA=str(cache), LOCALAPPDATA=str(cache))
    base = [gd, "--headless", "--path", str(engine), "--log-file", str(cache / "godot.log")]
    if not (engine / ".godot/global_script_class_cache.cfg").is_file():
        subprocess.run(base + ["--import"], env=env, check=True)
    selected = CASES if sys.argv[1] == "all" else [sys.argv[1]]
    observed = sum(run_case(base, cache, env, name) for name in selected)
    print(f"D5 reproduced {observed}/{len(selected)}")
    return int(observed != len(selected))


if __name__ == "__main__":
    sys.exit(main())
