# python -B docs/reports/astra-trial/d5/repro/a_capture_resize.py
import json
import subprocess
import sys
from pathlib import Path
from tempfile import TemporaryDirectory


def main():
    with TemporaryDirectory(prefix="a_resize_", dir=Path(__file__).parent) as folder:
        frames = Path(folder)
        rows = []
        for n, width in enumerate((960, 960, 800)):
            (frames / f"f{n:05}.raw").write_bytes(bytes(width * 540 * 3))
            rows.append({"n": n, "frame": n + 1, "size": [width, 540],
                         "look": [0, 0, -1], "fov": 60})
        (frames / "frames.jsonl").write_text("".join(json.dumps(row) + "\n" for row in rows))
        result = subprocess.run([sys.executable, "-B", "engine/kernel/world/walks/blink_detect.py",
                                 str(frames), "--json"], capture_output=True, text=True, check=False)
        if result.stderr:
            print(result.stderr.splitlines()[-1])
        reported = any('"report": "blinks"' in line for line in result.stdout.splitlines())
        print(f"REPRO capture_resize: {'PASS' if reported else 'FAIL'} 3 indexed RGB8 frames, "
              f"exit={result.returncode}, totals printed={reported}")


if __name__ == "__main__":
    main()
