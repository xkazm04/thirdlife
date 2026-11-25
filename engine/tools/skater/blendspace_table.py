"""Writes engine/rigs/skater/skater_blendspaces.json from Unreal's own data of thirdjam's three blend spaces:
  python blendspace_table.py <dir of BS_*.t3d (export_driver_text.py)> <blendspaces.json (export_skater.py)> <out.json>
Per blend space: the two axes (min, max, the input smoothing time), the samples (clip, x, y, rate scale) in Unreal's
order, and the runtime triangulation Unreal stored (BlendSpaceData.Triangles: three sample indices each). The
triangles' vertices are not copied: they are the samples' own values, normalised (the T3D prints them to 6 decimals)."""
import json
import os
import re
import sys

t3d_dir, samples_path, out_path = sys.argv[1:4]
src = json.load(open(samples_path, encoding="utf-8"))
out = {"schema": "tl.skater.blendspaces/1", "source": "thirdjam BS_SkaterTB1_P3_* (UE 5.9): sample tables read by export_skater.py, triangulation and smoothing times from the assets' T3D text", "spaces": {}}
for sp in src["spaces"]:
    name = sp["name"]
    text = open(os.path.join(t3d_dir, name + ".t3d"), encoding="utf-8", errors="replace").read()
    tris = [[int(a), int(b), int(c)] for a, b, c in re.findall(r"SampleIndices\[0\]=(\d+),SampleIndices\[1\]=(\d+),SampleIndices\[2\]=(\d+)", text)]
    # an index that is 0 is left out of the text (the type's zero)
    raw = re.findall(r"\((SampleIndices[^V]*?)(?:,Vertices|,EdgeInfo)", text)
    tris = []
    for chunk in raw:
        idx = [0, 0, 0]
        for k, v in re.findall(r"SampleIndices\[(\d)\]=(\d+)", chunk):
            idx[int(k)] = int(v)
        tris.append(idx)
    times = [0.0, 0.0]
    for k, v in re.findall(r"InterpolationParam\((\d)\)=\(InterpolationTime=([0-9.]+)", text):
        times[int(k)] = float(v)
    axes = []
    for i in range(2):
        a = sp["axes"][i]
        axes.append({"name": a["display_name"], "min": a["min"], "max": round(a["max"], 6), "smooth_s": times[i]})
    samples = [{"clip": s["clip"].replace("AS_SkaterTB1_P3_", ""), "x": s["value"][0], "y": s["value"][1], "rate": s["rate_scale"]} for s in sp["samples"]]
    used = sorted({i for t in tris for i in t})
    out["spaces"][name.replace("BS_SkaterTB1_P3_", "")] = {"axes": axes, "samples": samples, "triangles": tris}
    print(name, "samples", len(samples), "triangles", len(tris), "samples used", len(used), "smooth", times)
json.dump(out, open(out_path, "w", encoding="utf-8", newline="\n"), indent=1)
