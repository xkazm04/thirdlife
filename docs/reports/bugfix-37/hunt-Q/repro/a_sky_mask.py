# python -B docs/reports/astra-trial/d5/repro/a_sky_mask.py
import json
import subprocess
import sys
from pathlib import Path
from tempfile import TemporaryDirectory

import numpy as np


def detect(folder, reference_sky_pixels):
    width, height = 480, 270
    frame = np.zeros((height, width, 3), dtype=np.uint8)
    # No sky below the horizon. The gray court is fully rendered geometry.
    frame[180:220, 100:180] = (190, 190, 190)
    frame[2, :reference_sky_pixels] = (255, 0, 255)
    frame.tofile(folder / "f00000.raw")
    metadata = {"n": 0, "frame": 1, "look": [0, 0, -1], "fov": 60, "size": [width, height]}
    (folder / "frames.jsonl").write_text(json.dumps(metadata) + "\n")
    result = subprocess.run([sys.executable, "-B", "engine/kernel/world/walks/blink_detect.py",
                             str(folder), "--json"], capture_output=True, text=True, check=True)
    return json.loads(result.stdout.splitlines()[-1])


def main():
    with TemporaryDirectory(prefix="a_mask_", dir=Path(__file__).parent) as directory:
        folder = Path(directory)
        for reference_sky_pixels in (51, 50):
            result = detect(folder, reference_sky_pixels)
            print(f"magenta pixels above horizon={reference_sky_pixels}, "
                  f"sky_mask={result['sky_mask']}, reported hole pixels={result['hole_px_max']}")
        verdict = "FAIL" if result["hole_frames"] else "PASS"
        print(f"REPRO sky_mask: {verdict} expected 0 holes below horizon, got {result['hole_frames']}")


if __name__ == "__main__":
    main()
