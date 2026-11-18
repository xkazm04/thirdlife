# python -B docs/reports/astra-trial/d5/repro/a_blink_erosion.py
import json
import subprocess
import sys
from pathlib import Path
from tempfile import TemporaryDirectory

import numpy as np


def main():
    mask = np.zeros((20, 50), dtype=bool)
    for y in (5, 12):
        for x in range(4, 41, 6):
            mask[y - 1:y + 2, x] = True
            mask[y, x - 1:x + 2] = True
    full_blocks = np.lib.stride_tricks.sliding_window_view(mask, (3, 3)).all(axis=(-2, -1))
    with TemporaryDirectory(prefix="a_erosion_", dir=Path(__file__).parent) as folder:
        frames = Path(folder)
        rows = []
        for n in range(3):
            frame = np.zeros((20, 50, 3), dtype=np.uint8)
            if n == 1:
                frame[mask] = (255, 0, 0)
            frame.tofile(frames / f"f{n:05}.raw")
            rows.append({"n": n, "frame": n + 1, "size": [50, 20]})
        (frames / "frames.jsonl").write_text("".join(json.dumps(row) + "\n" for row in rows))
        result = subprocess.run([sys.executable, "-B", "engine/kernel/world/walks/blink_detect.py",
                                 str(frames), "--json"], capture_output=True, text=True, check=True)
    events = [json.loads(line) for line in result.stdout.splitlines()]
    survivors = sum(event.get("px", 0) for event in events)
    print(f"full 3x3 foreground neighbourhoods={int(full_blocks.sum())}")
    verdict = "FAIL" if survivors != int(full_blocks.sum()) else "PASS"
    print(f"REPRO blink_erosion: {verdict} expected 0 surviving pixels, got {survivors} (default event threshold 12)")


if __name__ == "__main__":
    main()
