"""Package only complete, real window renders."""
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

root = Path(sys.argv[1]).resolve()
number = int(sys.argv[2])
raw = root / ".tl" / "home-a" / f"round-{number}"
dest = root / "docs/shifts/2026-11-22-night/lanes/N6-world/arm-a" / f"round-{number}"
dest.mkdir(parents=True, exist_ok=True)
labels = ["overview_sw", "village_edge_out", "far_look_back", "venue_approach", "region_seam", "map"]
read = lambda f: json.loads((raw / f).read_text(encoding="utf-8"))
base, grown, clean = [read(name+".json") for name in ("baseline","growth","clean")]
for mode, run, ticks, stride in [(1,base,3058,0),(0,grown,4000,2),(2,clean,3058,0)]:
    assert run["run_id"] == os.environ["TL_HOME_CAPTURE_ID"]
    assert run["map_fog_off"] and run["cameras"] == grown["cameras"]
    lap = run["flyover"]
    assert (lap["samples"],lap["start_tick"],lap["physics_frames"],lap["capture_stride"]) == (1079,1970,1080,stride)
    assert lap["pose_sha256"] == grown["flyover"]["pose_sha256"]
    assert set(run["stills"]) == set(labels)
    events = [json.loads(line) for line in (raw / f"window-{mode}.log").read_text(encoding="utf-8").splitlines() if line.startswith('{"schema":"tl.world/1"')]
    world, = [row for row in events if row["kind"]=="world"]
    assert world["world_ticks"] == ticks and world["packs"] == 8 and not world["errors"]
    assert len({row["plot"] for row in events if row["kind"] == "pack" and row["frames"] > 0}) == 8
count = grown["flyover"]["physics_frames"] // grown["flyover"]["capture_stride"]
frames = [raw / f"frame_{i:04}.jpg" for i in range(count)]
assert all(f.is_file() for f in frames)
assert len(list(raw.glob("frame_*.jpg"))) == count
font = ImageFont.truetype("C:/Windows/Fonts/segoeuib.ttf", 18)

def sheet(paths, names, out):
    canvas = Image.new("RGB", (1440, 604), "#192524")
    draw = ImageDraw.Draw(canvas)
    for i, (path, name) in enumerate(zip(paths, names)):
        x, y = (i % 3) * 480, (i // 3) * 302
        with Image.open(path) as frame:
            canvas.paste(frame.resize((480, 270), Image.Resampling.LANCZOS), (x, y))
        draw.text((x + 12, y + 273), f"Round {number}   /   {name}", fill="#e9e8d4", font=font)
    canvas.save(out, quality=94)

for label in labels:
    p = raw / f"{label}.jpg"
    with Image.open(p) as im:
        assert im.size == (1920, 1080), im.size
    shutil.copyfile(p, dest / p.name)
sheet([dest / f"{l}.jpg" for l in labels], labels[:-1]+["map, haze off"], dest / "sheet.jpg")
samples = [round(i*(count-1)/5) for i in range(6)]
sheet([frames[i] for i in samples], [f"{i/30:.2f} s" for i in samples], raw / "filmstrip.jpg")
subprocess.run(["C:/ffmpeg/bin/ffmpeg.exe", "-loglevel", "error", "-y", "-framerate", "30", "-i",
                str(raw / "frame_%04d.jpg"), "-frames:v", str(count), "-c:v", "libx264", "-crf", "20",
                "-threads", "4", "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(dest / "flyover.mp4")], check=True)
figures = {"round": number, "style": "crisp", "resolution": [1920, 1080], "machine": "busy, shared night shift",
           "method": "Three fresh crisp windows. Stock village and grown village take the same route at identical physics ticks. Growth reads the six stills and alternate flight frames. Clean takes no viewport readbacks and does no encoding. Draw calls are visible viewport passes. Only the map has fog disabled.",
           "baseline": base, "grown": grown, "clean":clean, "growth_build_ms": sum(grown["build_ms"].values()) + grown["data_ms"],
           "added_first_draw_ms": clean["first_draw_ms"]-base["first_draw_ms"],
           "max_draw_ratio": max(clean["stills"][l]["draw_calls"]/max(1,base["stills"][l]["draw_calls"]) for l in labels)}
calls = {key:read(key+"-calls.json") for key in ("baseline","growth","clean")}
assert all(len(v)==1080 and min(v)>0 for v in calls.values())
figures["flight_max_draw_ratio"] = max(a/b for a,b in zip(calls["clean"],calls["baseline"]))
(dest/"draw-calls.json").write_text(json.dumps(calls,separators=(",",":")),encoding="utf-8")
(dest / "figures.json").write_text(json.dumps(figures, indent=2)+"\n", encoding="utf-8")
print(f"CAPTURE round {number}: {len(labels)} stills, {count} flyover frames, {count/30:.2f}s")
