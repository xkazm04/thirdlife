"""Count shader-source fetches on the shipped style's normal and contact-shade paths."""
import json
from pathlib import Path
import re
import subprocess

path = "engine/style/shaders/ink_post.gdshader"
rev = "c8b88fc683b057c5523c883efd07ffc84c95ae2e"
ink = json.loads(Path("engine/style/style.json").read_text())["ink"]
assert ink["thin_rings"] > 0.5 and ink["ao_k"] > 0


def count(source):
    # lin_depth and view_pos each issue one depth fetch.
    return (len(re.findall(r"\b(?:lin_depth|view_pos)\(", source)),
            len(re.findall(r"\btexture\(nr_tex,", source)))


for label, code in [("before", subprocess.check_output(["git", "show", f"{rev}:{path}"], text=True)),
                    ("after", Path(path).read_text())]:
    fragment = code.split("void fragment() {")[1].split("if (body_dbg")[0]
    setup, loop = fragment.split("for (int i = 0; i < 4; i++)")
    ring, ao = loop.split("if (ao_k > 0.0 && d0 < ao_far)")
    ao_setup, ao_loop = ao.split("for (int i = 0; i < 8; i++)")
    centre, edges = count(setup), count(ring)
    depth = centre[0] + 4 * edges[0]
    normals = centre[1] + 4 * edges[1]
    extra = count(ao_setup)[0] + 8 * count(ao_loop)[0]
    print(f"{label} depth={depth} normal_roughness={normals} total={depth+normals} "
          f"AO_extra={extra} total_with_AO={depth+normals+extra}")
