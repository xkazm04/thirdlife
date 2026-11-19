"""Validate ownership at every tick, then run the repository's boil meter on the lossless terrain crop."""
import subprocess
import sys
import measure

for place, last, x in [("bank", 310, 240), ("bluff", 120, 0)]:
    frames = []
    for tick in range(last-31, last+1):
        name = f"{place}_{tick}"
        box = (slice(60, 150), slice(x, x+240))
        ground = measure.masks(name, True)[0][box]
        if not ground.all():
            raise ValueError(f"{name}: band contains non-terrain pixels")
        frames.append(measure.read(name, "beauty", True)[box].tobytes())
    dest = measure.here / f"{measure.stage}-{place}-band.mkv"
    subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgb24",
                    "-s", "240x90", "-r", "60", "-i", "-", "-an", "-c:v", "ffv1", "-pix_fmt", "bgr0", str(dest)],
                   input=b"".join(frames), check=True)
    result = subprocess.check_output([sys.executable, "engine/rigs/review/boil.py", str(dest), "0", "31", "0", "1080"], text=True)
    if "boil frames=32 " not in result:
        raise ValueError(result)
    print(place, result.strip())
