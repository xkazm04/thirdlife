"""Check paired geometry, continuous plane opacity and sample counts for all three shaders."""
from pathlib import Path
import re
import subprocess
import sys

import numpy as np
from PIL import Image

sys.argv = [sys.argv[0], "after"]
import measure

p = measure.here
old = p / "captures" / "head"
for stage in ("r3b", "after"):
    for kind in ("depth", "removed"):
        files = sorted(old.glob(f"*-{kind}.png"))
        equal = sum(path.read_bytes() == (p/"captures"/stage/path.name).read_bytes() for path in files)
        print(f"HEAD vs {stage} {kind}: {equal}/{len(files)} byte-identical")
        if equal != 66 or len(files) != 66:
            raise ValueError("unmatched depth capture")
g, _, _, ink, z = measure.masks("plane")
sel = g & (z >= 8) & (z <= 80) & ink[:, :, 2]
sel[:, :10] = sel[:, -10:] = False
for version in ("head", "r3b", "after"):
    weight = np.asarray(Image.open(p/"captures"/version/"plane-live-weight.png"))[:, :, 0][sel]
    print(f"flat {version}: nonzero opacity codes={(weight>0).sum()}/{len(weight)} max={weight.max()}/255")
source_file = "engine/style/shaders/ink_post.gdshader"
sources = [("head", subprocess.check_output(["git", "show", "HEAD:"+source_file], text=True)),
           ("r3b", (p/"r3b-reviewed.gdshader.txt").read_text()), ("after", Path(source_file).read_text())]
for label, source in sources:
    frag = source.split("void fragment() {")[1].split("if (body_dbg")[0]
    setup, rest = frag.split("for (int i = 0; i < 4; i++)")
    ring, tail = rest.split("// full weight where the core ring")
    optional, ao = tail.split("if (ao_k > 0.0 && d0 < ao_far)")
    ao_setup, ao_loop = ao.split("for (int i = 0; i < 8; i++)")
    def count(s):
        return len(re.findall(r"\b(?:lin_depth|view_pos|texture)\(", s))
    base = count(setup) + 4*count(ring)
    contact = base + count(ao_setup) + 8*count(ao_loop)
    extra = count(optional)
    print(f"{label} taps {base} without AO, {contact} with AO, +{extra} on crest refetch")
    if extra:
        for view in ("bank_310", "bluff_120", "shoulder"):
            img = np.asarray(Image.open(p/"captures"/"after"/f"{view}-live-weight.png"))
            share = (img[:, :, 2] > 127).mean()
            print(f"  {view} refetch={share:.2%} average_extra={extra*share:.3f} taps/pixel")
