# python docs/reports/astra-trial/d5/repro/r_boil.py
"""Measure a lossless, static horizontal stripe pattern at look.sh's default clip resolution."""
from pathlib import Path
import subprocess
import sys
import tempfile

with tempfile.TemporaryDirectory(prefix="r_boil_", dir=Path(__file__).parent) as workspace:
    clip = Path(workspace) / "still.mkv"
    subprocess.run(["ffmpeg", "-nostdin", "-v", "error", "-f", "lavfi", "-i",
                    "nullsrc=size=1280x720,geq=lum='if(mod(Y,2),220,30)':cb=128:cr=128",
                    "-frames:v", "12", "-pix_fmt", "yuv420p", "-c:v", "ffv1", str(clip)], check=True)
    meter = [sys.executable, "engine/rigs/review/boil.py", str(clip), "0", "11"]
    control = subprocess.run(meter + ["0", "1080"], capture_output=True, text=True, check=True)
    assert "frames=12" in control.stdout and "mean=0.000 flips_pct=0.000" in control.stdout
    print(control.stdout.strip())
    result = subprocess.run(meter,
                            capture_output=True, text=True, check=True)
    print(result.stdout.strip())
    expected = "frames=12" in result.stdout and "mean=0.000 flips_pct=0.000" in result.stdout
    print("REPRO boil: %s expected 12 identical frames, zero mean change and zero flips" %
          ("PASS" if expected else "FAIL"))
