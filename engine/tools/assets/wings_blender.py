# The walker's mechanical wings: the Blender build script (lane flight, day of 19 Nov 2026).
#
#   "C:/Program Files/Blender Foundation/Blender 4.2/blender.exe" --background --factory-startup \
#       --python engine/tools/assets/wings_blender.py -- <repo>/assets/engine/wings.glb [<out.blend>]
#
# Rebuilds the model from nothing and writes one .glb, in the conventions of pip_blender.py (TLKitAsset):
#   - every MATERIAL is named after a palette key of engine/style/style.json (the engine draws the faces with the house
#     toon material; the file's colours are only for other viewers);
#   - every OBJECT is a named part whose origin is its joint, so the kernel can fold it (kernel/world/flight_wings.gd):
#       wings > wing_l > wing_l_fore > wing_l_f1..f3, wing_l_f4..f6 hang from wing_l (inner panels) / wing_l_fore (outer)
#   - the model is drawn in the coordinates of the biped rig's `back` socket (UpperChest, rig (0, 1.35, 0.2)), in
#     Godot terms: +x the figure's right... see G() below; the figure faces -Z in Godot, so its back is +Z.
#   - modelled SPREAD (the flight pose); every joint rotates about the socket's Z axis (the axis out of his back), so
#     folding moves the parts in planes parallel to his back and depth keeps them apart.
import math
import sys

import bmesh
import bpy
from mathutils import Vector

PALETTE = {
    "steel_dark": "#4f4a60", "steel": "#8a85a0", "rib_steel": "#6d6a85", "yellow": "#f2b230", "yellow_dark": "#c98720",
    "curb_white": "#f3e8dc", "orange": "#e8742c", "black": "#2b2532", "hot": "#ff9a3a", "flag_a": "#e8483a",
}


def G(x, y, z):
    """Godot socket coordinates (x right of the figure as seen from behind is +x, y up, z out of his back) to Blender
    (glTF export with +Y up maps Blender (x, y, z) to glTF/Godot (x, z, -y))."""
    return Vector((x, -z, y))


def _srgb(h):
    c = [int(h[i:i + 2], 16) / 255.0 for i in (1, 3, 5)]
    return [((x + 0.055) / 1.055) ** 2.4 if x > 0.04045 else x / 12.92 for x in c] + [1.0]


def material(key):
    m = bpy.data.materials.get(key)
    if m is None:
        m = bpy.data.materials.new(key)
        m.use_nodes = True
        bsdf = m.node_tree.nodes.get("Principled BSDF")
        bsdf.inputs["Base Color"].default_value = _srgb(PALETTE[key])
        bsdf.inputs["Roughness"].default_value = 1.0
        m.diffuse_color = _srgb(PALETTE[key])
    return m


class Part:
    """One named object; geometry is given in Godot socket coordinates (G); the object's origin is its pivot."""

    def __init__(self, name, pivot_g, parent=None):
        self.name = name
        self.pivot = G(*pivot_g)
        self.parent = parent
        self.bm = bmesh.new()
        self.keys = []

    def _mi(self, key):
        if key not in self.keys:
            self.keys.append(key)
        return self.keys.index(key)

    def face(self, pts, key, out):
        pts = [Vector(p) for p in pts]
        nrm = (pts[1] - pts[0]).cross(pts[2] - pts[0])
        if nrm.dot(Vector(out)) < 0.0:
            pts.reverse()
        vs = [self.bm.verts.new(p - self.pivot) for p in pts]
        f = self.bm.faces.new(vs)
        f.material_index = self._mi(key)

    def loft(self, rings, keys, cap_keys=None):
        """rings in Blender coordinates; bands face away from the line through the ring centres; caps outward."""
        n = len(rings[0])
        cs = [sum((Vector(p) for p in r), Vector()) / n for r in rings]
        for i in range(len(rings) - 1):
            a, b = rings[i], rings[i + 1]
            ax = cs[i + 1] - cs[i]
            for j in range(n):
                k = (j + 1) % n
                q = [Vector(a[j]), Vector(a[k]), Vector(b[k]), Vector(b[j])]
                qc = sum(q, Vector()) / 4.0
                t = (qc - cs[i]).dot(ax) / ax.length_squared if ax.length > 1e-6 else 0.0
                self.face(q, keys[i], qc - (cs[i] + ax * t))
        ck = cap_keys or (keys[0], keys[-1])
        self.face(rings[0], ck[0], cs[0] - cs[1])
        self.face(rings[-1], ck[1], cs[-1] - cs[-2])

    def box(self, c_g, size_g, key, bevel=0.0):
        tmp = bmesh.new()
        bmesh.ops.create_cube(tmp, size=1.0)
        sx, sy, sz = size_g
        bmesh.ops.scale(tmp, vec=Vector((sx, sz, sy)), verts=tmp.verts)
        if bevel > 0.0:
            bmesh.ops.bevel(tmp, geom=list(tmp.edges), offset=bevel, segments=1, affect='EDGES', profile=0.5)
        bmesh.ops.translate(tmp, vec=G(*c_g), verts=tmp.verts)
        self._merge(tmp, key)

    def _merge(self, tmp, key):
        mi = self._mi(key)
        vmap = {v: self.bm.verts.new(v.co - self.pivot) for v in tmp.verts}
        for f in tmp.faces:
            nf = self.bm.faces.new([vmap[v] for v in f.verts])
            nf.material_index = mi
        tmp.free()

    def finish(self, objs):
        me = bpy.data.meshes.new(self.name)
        self.bm.to_mesh(me)
        self.bm.free()
        for k in self.keys:
            me.materials.append(material(k))
        for p in me.polygons:
            p.use_smooth = False
        ob = bpy.data.objects.new(self.name, me)
        bpy.context.scene.collection.objects.link(ob)
        par = objs[self.parent] if self.parent else None
        ob.location = self.pivot - (Vector(par["pivot"]) if par else Vector())
        if par:
            ob.parent = par
        ob["pivot"] = list(self.pivot)
        objs[self.name] = ob
        return ob


def seg_g(p0, p1, r0, r1, n=6, rot=0.0):
    """A tapered n-sided rod between two Godot points (rings in Blender coordinates)."""
    p0, p1 = G(*p0), G(*p1)
    d = (p1 - p0).normalized()
    ref = Vector((0, 0, 1)) if abs(d.z) < 0.9 else Vector((1, 0, 0))
    u = d.cross(ref).normalized()
    v = d.cross(u).normalized()
    out = []
    for c, r in ((p0, r0), (p1, r1)):
        out.append([c + (u * math.cos(rot + 2 * math.pi * i / n) + v * math.sin(rot + 2 * math.pi * i / n)) * r for i in range(n)])
    return out


def barrel_g(c, r, half, n=8):
    """A hinge barrel along Godot z (out of his back), centred at c."""
    cz = G(*c)
    rings = []
    for dz in (-half, half):
        rings.append([cz + Vector((math.cos(2 * math.pi * i / n + math.pi / n) * r, -dz, math.sin(2 * math.pi * i / n + math.pi / n) * r)) for i in range(n)])
    return rings


def panel_g(root, ang_deg, length, w0, w1, z, th=0.022):
    """A flat tapered panel in the plane z = const (Godot), from `root` along the in-plane direction `ang_deg`
    (0 = +x, -90 = straight down), root width w0, tip width w1; a hexagon outline with a pointed tip."""
    a = math.radians(ang_deg)
    d = (math.cos(a), math.sin(a))
    s = (-d[1], d[0])
    rx, ry = root
    # a slat: straight sides, the tip cut on a slant (the leading side, +s, is the long one), a small chamfer
    pts2 = [
        (rx - s[0] * w0 * 0.5, ry - s[1] * w0 * 0.5),
        (rx + d[0] * length * 0.80 - s[0] * w1 * 0.5, ry + d[1] * length * 0.80 - s[1] * w1 * 0.5),
        (rx + d[0] * length + s[0] * w1 * 0.25, ry + d[1] * length + s[1] * w1 * 0.25),
        (rx + d[0] * length * 0.96 + s[0] * w1 * 0.5, ry + d[1] * length * 0.96 + s[1] * w1 * 0.5),
        (rx + s[0] * w0 * 0.5, ry + s[1] * w0 * 0.5),
    ]
    return [[G(px, py, z - th * 0.5) for (px, py) in pts2], [G(px, py, z + th * 0.5) for (px, py) in pts2]]


# Spread pose, Godot socket coordinates (metres). The figure is 2.0 m tall; the socket sits at chest height 1.35 m.
SHOULDER = (0.17, 0.16, 0.25)      # the root hinge, on the harness behind the backpack (pack's back face is z ~0.15)
ELBOW = (0.92, 0.34, 0.27)
TIP = (1.72, 0.26, 0.29)
# panels: (attached to "arm" | "fore", fraction along that spar, angle deg (in the plane; -90 hangs down, more
# negative sweeps toward the body), length, root width, tip width, z, palette key of the tip)
PANELS = [
    ("arm", 0.22, -122.0, 0.58, 0.24, 0.30, 0.300, "curb_white"),
    ("arm", 0.55, -106.0, 0.74, 0.26, 0.32, 0.312, "curb_white"),
    ("arm", 0.90, -93.0, 0.88, 0.26, 0.33, 0.324, "curb_white"),
    ("fore", 0.25, -80.0, 0.94, 0.26, 0.32, 0.336, "curb_white"),
    ("fore", 0.60, -64.0, 0.88, 0.24, 0.30, 0.348, "orange"),
    ("fore", 0.95, -44.0, 0.76, 0.22, 0.26, 0.360, "orange"),
]


def build():
    objs = {}
    root = bpy.data.objects.new("wings", None)
    bpy.context.scene.collection.objects.link(root)
    root["pivot"] = [0, 0, 0]
    objs["wings"] = root

    # ---- the harness: a plate strapped over the backpack, a gearbox between the two root hinges, two small nozzles
    h = Part("harness", (0, 0, 0.2), "wings")
    h.box((0, 0.10, 0.19), (0.30, 0.34, 0.06), "steel_dark", bevel=0.02)
    h.box((0, 0.17, 0.235), (0.40, 0.12, 0.07), "yellow", bevel=0.02)
    h.box((0, 0.17, 0.275), (0.20, 0.08, 0.02), "yellow_dark")
    for sx in (-1, 1):
        # nozzle: an eight-sided cone opening downward, a hot ring inside
        h.loft(seg_g((sx * 0.08, 0.02, 0.23), (sx * 0.09, -0.16, 0.24), 0.045, 0.06, 8), ["steel"], cap_keys=("steel", "hot"))
        # straps over the shoulders (to the front edge of the pack)
        h.box((sx * 0.13, 0.26, 0.16), (0.05, 0.10, 0.05), "black")
    h.finish(objs)

    for sx, nm in ((-1, "l"), (1, "r")):
        sh = (sx * SHOULDER[0], SHOULDER[1], SHOULDER[2])
        el = (sx * ELBOW[0], ELBOW[1], ELBOW[2])
        tp = (sx * TIP[0], TIP[1], TIP[2])
        arm = Part("wing_%s" % nm, sh, "wings")
        arm.loft(barrel_g(sh, 0.065, 0.05), ["yellow"])
        arm.loft(seg_g(sh, el, 0.045, 0.035, 6), ["steel_dark"])
        # a second, thinner strut under the main spar (a truss reads as a machine, not a bird)
        a0 = (sh[0] + sx * 0.10, sh[1] - 0.07, sh[2] + 0.01)
        a1 = (el[0] - sx * 0.12, el[1] - 0.05, el[2] + 0.01)
        arm.loft(seg_g(a0, a1, 0.018, 0.018, 4), ["rib_steel"])
        for f in (0.33, 0.66):
            p = (sh[0] + (el[0] - sh[0]) * f, sh[1] + (el[1] - sh[1]) * f, sh[2] + 0.005)
            q = (a0[0] + (a1[0] - a0[0]) * f, a0[1] + (a1[1] - a0[1]) * f, a0[2] + 0.005)
            arm.loft(seg_g(p, q, 0.014, 0.014, 4), ["rib_steel"])
        arm.finish(objs)
        fore = Part("wing_%s_fore" % nm, el, "wing_%s" % nm)
        fore.loft(barrel_g(el, 0.055, 0.045), ["yellow"])
        fore.loft(seg_g(el, tp, 0.035, 0.022, 6), ["steel_dark"])
        tipc = G(*tp)
        fore.box(tp, (0.07, 0.07, 0.07), "orange", bevel=0.015)
        fore.finish(objs)
        for i, (on, f, ang, ln, w0, w1, z, tipkey) in enumerate(PANELS):
            a, b = (sh, el) if on == "arm" else (el, tp)
            rt = (a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f, z)
            # the panel's angle mirrors for the left wing (angles are drawn for the right wing, +x)
            ang_s = ang if sx > 0 else 180.0 - ang
            pn = Part("wing_%s_f%d" % (nm, i + 1), rt, "wing_%s" % nm if on == "arm" else "wing_%s_fore" % nm)
            pn.loft(panel_g((rt[0], rt[1]), ang_s, ln, w0, w1, z), [tipkey if tipkey != "curb_white" else "curb_white"])
            # a rib down the middle of the panel and a brass pin at its root
            ar = math.radians(ang_s)
            sv = (-math.sin(ar), math.cos(ar))
            off = w0 * 0.42
            r0 = (rt[0] + sv[0] * off, rt[1] + sv[1] * off, z + 0.016)
            end = (rt[0] + math.cos(ar) * ln * 0.92 + sv[0] * w1 * 0.42, rt[1] + math.sin(ar) * ln * 0.92 + sv[1] * w1 * 0.42, z + 0.016)
            pn.loft(seg_g(r0, end, 0.014, 0.010, 4), ["rib_steel"])
            pn.loft(barrel_g((rt[0], rt[1], z), 0.03, 0.022, 6), ["yellow_dark"])
            if tipkey == "curb_white":
                # a red band across the panel near its tip (the house's flag colour, legible at distance)
                bc = (rt[0] + math.cos(ar) * ln * 0.10, rt[1] + math.sin(ar) * ln * 0.10)
                band = panel_g(bc, ang_s, ln * 0.10, w0 * 1.06, w0 * 1.08, z, th=0.03)
                pn.loft(band, ["flag_a"])
            pn.finish(objs)
    return objs


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = argv[0] if argv else "wings.glb"
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob, do_unlink=True)
    objs = build()
    tris = 0
    lo = Vector((1e9, 1e9, 1e9))
    hi = -lo
    bpy.context.view_layer.update()
    for ob in objs.values():
        if ob.type != 'MESH':
            continue
        me = ob.data
        me.calc_loop_triangles()
        tris += len(me.loop_triangles)
        for v in me.vertices:
            w = ob.matrix_world @ v.co
            lo = Vector(map(min, lo, w))
            hi = Vector(map(max, hi, w))
    print("WINGS parts=%d tris=%d bounds_min=%s bounds_max=%s" % (
        sum(1 for o in objs.values() if o.type == 'MESH'), tris, tuple(round(x, 3) for x in lo), tuple(round(x, 3) for x in hi)))
    bpy.ops.export_scene.gltf(filepath=out, export_format='GLB', use_selection=False, export_apply=True,
                              export_yup=True, export_materials='EXPORT', export_normals=True,
                              export_texcoords=False, export_extras=False, export_animations=False)
    if len(argv) > 1:
        bpy.ops.wm.save_as_mainfile(filepath=argv[1])
    print("WINGS wrote", out)


main()
