# Pip, the photo-finish judge: the Blender build script (Astra trial D2).
#
#   "C:/Program Files/Blender Foundation/Blender 4.2/blender.exe" --background --factory-startup \
#       --python engine/tools/assets/pip_blender.py -- <repo>/assets/engine/pip.glb [<out.blend>]
#
# Rebuilds the whole model from nothing (factory scene emptied first) and writes one .glb.
# Conventions the engine relies on (engine/kits/tl_kit_asset.gd, TLKit.asset):
#   - every MATERIAL is named after a palette key of engine/style/style.json; the engine reads only the name and
#     draws the faces with the house toon material (bands, ink, palette); the base colour here is for other viewers;
#   - every OBJECT is a named part; moving pieces have their pivot at the joint (wing hinge, hip, knee, ankle,
#     lens) so they can be animated later; the chain is pip > leg_l > leg_l_shin > leg_l_foot;
#   - flat faces, metres, Blender Z up, the lens looks along -Y (glTF +Z, Godot +Z); the soles stand on z = 0.
# Figures from the concept (docs/reports/astra-trial/d2/concept/boss.md): 4.5 m sole to pennant tip, housing
# underside 1.8 m and roof 3.7 m, housing about 2.1 m wide, daylight between the shins.
import math
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

PALETTE = {   # the golden style's colours (engine/style/style.json) of the keys used
    "yellow": "#f2b230", "yellow_dark": "#c98720", "flag_a": "#e8483a", "curb_white": "#f3e8dc",
    "orange": "#e8742c", "steel_dark": "#4f4a60", "roof_slate": "#5c4c6c", "cliff": "#8c7088",
    "beacon": "#ffb030", "black": "#2b2532",
}


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
    """One named object: faces are added in WORLD metres; the object's origin is its pivot."""

    def __init__(self, name, pivot=(0, 0, 0), parent=None):
        self.name = name
        self.pivot = Vector(pivot)
        self.parent = parent
        self.bm = bmesh.new()
        self.keys = []

    def _mi(self, key):
        if key not in self.keys:
            self.keys.append(key)
        return self.keys.index(key)

    def face(self, pts, key, out):
        """A face whose normal points along `out` (the outside is decided here, never guessed afterwards: an open
        piece such as the lens glass has no inside a normal recalculation could find)."""
        pts = [Vector(p) for p in pts]
        nrm = (pts[1] - pts[0]).cross(pts[2] - pts[0])
        if nrm.dot(Vector(out)) < 0.0:
            pts.reverse()
        vs = [self.bm.verts.new(p - self.pivot) for p in pts]
        f = self.bm.faces.new(vs)
        f.material_index = self._mi(key)
        return f

    def loft(self, rings, keys, cap0=True, cap1=True, cap_keys=None, outs=None):
        """rings: lists of points (same count, same winding); keys[i] colours the band between ring i and i+1.
        outs[i]: 'r' (default) the band faces away from the line through the ring centres, '-r' towards it (the
        inner wall of a hole), or a vector. Caps face away from the neighbouring ring."""
        n = len(rings[0])
        cs = [sum((Vector(p) for p in r), Vector()) / n for r in rings]
        for i in range(len(rings) - 1):
            a, b = rings[i], rings[i + 1]
            o = (outs[i] if outs else None) or 'r'
            ax = cs[i + 1] - cs[i]
            for j in range(n):
                k = (j + 1) % n
                q = [Vector(a[j]), Vector(a[k]), Vector(b[k]), Vector(b[j])]
                if isinstance(o, str):
                    qc = sum(q, Vector()) / 4.0
                    if ax.length > 1e-6:
                        t = (qc - cs[i]).dot(ax) / ax.length_squared
                        foot = cs[i] + ax * t
                    else:
                        foot = cs[i]
                    v = qc - foot
                    ov = v if o == 'r' else -v
                else:
                    ov = Vector(o)
                self.face(q, keys[i], ov)
        ck = cap_keys or (keys[0], keys[-1])
        if cap0:
            self.face(rings[0], ck[0], cs[0] - cs[1])
        if cap1:
            self.face(rings[-1], ck[1], cs[-1] - cs[-2])

    def box(self, c, size, key, bevel=0.0):
        tmp = bmesh.new()
        bmesh.ops.create_cube(tmp, size=1.0)
        bmesh.ops.scale(tmp, vec=Vector(size), verts=tmp.verts)
        if bevel > 0.0:
            bmesh.ops.bevel(tmp, geom=list(tmp.edges), offset=bevel, segments=1, affect='EDGES', profile=0.5)
        bmesh.ops.translate(tmp, vec=Vector(c), verts=tmp.verts)
        self._merge(tmp, key)

    def ico(self, c, r, key):
        tmp = bmesh.new()
        bmesh.ops.create_icosphere(tmp, subdivisions=1, radius=r)
        bmesh.ops.translate(tmp, vec=Vector(c), verts=tmp.verts)
        self._merge(tmp, key)

    def _merge(self, tmp, key):
        mi = self._mi(key)
        vmap = {}
        for v in tmp.verts:
            vmap[v] = self.bm.verts.new(v.co - self.pivot)
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


def ring(c, axis, r, n=8, rot=0.0, sx=1.0, sy=1.0):
    """An n-gon around point c in the plane normal to axis ('x', 'y' or 'z')."""
    c = Vector(c)
    out = []
    for i in range(n):
        a = rot + 2.0 * math.pi * i / n
        u, v = math.cos(a) * r * sx, math.sin(a) * r * sy
        if axis == 'y':
            out.append(c + Vector((u, 0, v)))
        elif axis == 'x':
            out.append(c + Vector((0, u, v)))
        else:
            out.append(c + Vector((u, v, 0)))
    return out


def seg(p0, p1, r0, r1, n=6):
    """A tapered n-sided segment from p0 to p1 (rings perpendicular to the segment)."""
    p0, p1 = Vector(p0), Vector(p1)
    d = (p1 - p0).normalized()
    ref = Vector((0, 0, 1)) if abs(d.z) < 0.9 else Vector((1, 0, 0))
    u = d.cross(ref).normalized()
    v = d.cross(u).normalized()
    rs = []
    for c, r in ((p0, r0), (p1, r1)):
        rs.append([c + (u * math.cos(2 * math.pi * i / n) + v * math.sin(2 * math.pi * i / n)) * r for i in range(n)])
    return rs


def build():
    objs = {}
    root = bpy.data.objects.new("pip", None)
    bpy.context.scene.collection.objects.link(root)
    root["pivot"] = [0, 0, 0]
    objs["pip"] = root

    # ---- housing: one chamfered box, 2.1 wide, 1.8 deep, from 1.8 to 3.7 m
    body = Part("body", (0, 0, 2.75), "pip")
    body.box((0, 0, 2.75), (2.1, 1.8, 1.9), "yellow", bevel=0.2)
    # hip sockets under the housing
    for sx in (-1, 1):
        body.loft([ring((sx * 0.55, 0, 1.82), 'z', 0.2, 8), ring((sx * 0.55, 0, 1.62), 'z', 0.17, 8)], ["steel_dark"])
    # tail: a small rear wedge
    tl = [(-0.38, 0.88, 2.15), (0.38, 0.88, 2.15), (0.38, 0.88, 2.75), (-0.38, 0.88, 2.75)]
    tip = (0, 1.62, 2.38)
    for i in range(4):
        fc = (Vector(tl[i]) + Vector(tl[(i + 1) % 4]) + Vector(tip)) / 3.0
        body.face([tl[i], tl[(i + 1) % 4], tip], "yellow", fc - Vector((0, 1.05, 2.45)))
    # mast boss on the roof
    body.loft([ring((0.2, 0.25, 3.69), 'z', 0.18, 8), ring((0.2, 0.25, 3.84), 'z', 0.14, 8)], ["steel_dark"])
    body.finish(objs)

    # ---- mast and pennant (one leaning mast; the tip of the knob is the 4.5 m mark)
    mast = Part("mast", (0.2, 0.25, 3.84), "pip")
    top = Vector((0.08, 0.38, 4.40))
    mast.loft(seg((0.2, 0.25, 3.84), top, 0.055, 0.045, 6), ["steel_dark"])
    mast.ico(top + Vector((0, 0, 0.04)), 0.06, "steel_dark")
    mast.finish(objs)
    pen = Part("pennant", tuple(top), "mast")
    th = 0.025
    p0, p1, p2 = Vector((0.1, 0.36, 4.33)), Vector((0.1, 0.36, 4.02)), Vector((0.78, 0.30, 4.20))
    side = Vector((0, th, 0))
    pen.loft([[p0 - side, p1 - side, p2 - side], [p0 + side, p1 + side, p2 + side]], ["flag_a"])
    pen.finish(objs)

    # ---- the brow: fixed to the casing above the lens
    brow = Part("brow", (0, -0.9, 3.3), "body")
    bw = [(-0.84, -0.9, 3.54), (0.84, -0.9, 3.54), (0.76, -1.46, 3.48), (-0.76, -1.46, 3.48)]
    bl = [(-0.88, -0.9, 3.22), (0.88, -0.9, 3.22), (0.8, -1.46, 3.3), (-0.8, -1.46, 3.3)]
    brow.loft([[bl[0], bl[1], bw[1], bw[0]][::-1], [bl[3], bl[2], bw[2], bw[3]][::-1]], ["steel_dark"])
    brow.finish(objs)

    # ---- the lens: eight-sided rings along -Y; two accordion folds (bellows) and the lens itself in front
    lc = (0, 0, 2.62)
    def rr(y, r):
        return ring((0, y, lc[2]), 'y', r, 8, rot=math.pi / 8)
    bel = Part("lens_bellows", (0, -0.9, lc[2]), "body")
    rings = [rr(-0.86, 0.66), rr(-0.96, 0.70), rr(-1.04, 0.56), rr(-1.12, 0.70), rr(-1.20, 0.56), rr(-1.26, 0.64)]
    bel.loft(rings, ["steel_dark", "black", "steel_dark", "black", "steel_dark"], cap0=False, cap1=False)
    bel.finish(objs)
    lens = Part("lens", (0, -1.26, lc[2]), "lens_bellows")
    lens.loft([rr(-1.26, 0.70), rr(-1.40, 0.70), rr(-1.40, 0.50), rr(-1.33, 0.48)],
              ["steel_dark", "steel_dark", "steel_dark"], cap0=True, cap1=False, cap_keys=("steel_dark", "roof_slate"),
              outs=['r', (0, -1, 0), '-r'])
    glass = rr(-1.33, 0.48)
    cg = Vector((0, -1.33, lc[2]))
    for j in range(8):   # the glass: a fan, one facet lighter (a reflection)
        lens.face([cg, glass[(j + 1) % 8], glass[j]], "cliff" if j in (3, 4) else "roof_slate", (0, -1, 0))
    lens.box((0.22, -1.355, lc[2] + 0.22), (0.11, 0.03, 0.11), "beacon")   # the square amber glint
    lens.finish(objs)

    # ---- signal wings: a barrel hinge offset from the casing, a rigid red paddle with one ivory band, tapered tip
    for sx, nm in ((-1, "l"), (1, "r")):
        hx = sx * 1.04
        hinge = Part("wing_%s_hinge" % nm, (hx, 0, 3.1), "body")
        hinge.loft([ring((hx, 0, 3.1), 'x', 0.2, 8), ring((sx * 1.36, 0, 3.1), 'x', 0.2, 8)], ["steel_dark"])
        hinge.loft([ring((sx * 1.36, 0, 3.1), 'x', 0.13, 8), ring((sx * 1.46, 0, 3.1), 'x', 0.13, 8)], ["black"])
        hinge.finish(objs)
        pv = Vector((sx * 1.56, 0, 3.1))
        wing = Part("wing_%s" % nm, tuple(pv), "pip")
        # paddle profile: a flat hexagon (width w, thickness t) at a distance d down the paddle's own axis
        tilt = math.radians(12.0) * sx            # hangs a little outward
        down = Vector((math.sin(tilt), 0, -math.cos(tilt)))
        outw = Vector((math.cos(tilt), 0, math.sin(tilt)))
        fwd = Vector((0, 1, 0))
        def prof(d, w, t, slant=0.0):
            c = pv + down * d
            pts = []
            for (a, b) in ((-0.5, 0), (-0.38, 0.5), (0.38, 0.5), (0.5, 0), (0.38, -0.5), (-0.38, -0.5)):
                pts.append(c + outw * (a * w) + fwd * (b * t) + down * (slant * a * w))
            return pts
        rings = [prof(0.0, 0.26, 0.16), prof(0.14, 0.3, 0.16), prof(0.26, 0.74, 0.15), prof(0.85, 0.8, 0.15, -0.5 * sx),
                 prof(1.22, 0.8, 0.15, -0.5 * sx), prof(1.72, 0.74, 0.15), prof(2.0, 0.24, 0.1)]
        wing.loft(rings, ["steel_dark", "flag_a", "flag_a", "curb_white", "flag_a", "flag_a"],
                  cap_keys=("steel_dark", "flag_a"))
        wing.finish(objs)

    # ---- legs: two tapered orange segments, a faceted knuckle, an ankle block, three wedge toes with dark tips
    for sx, nm in ((-1, "l"), (1, "r")):
        hip = Vector((sx * 0.55, 0, 1.68))
        knee = Vector((sx * 0.6, -0.08, 0.98))
        ankle = Vector((sx * 0.62, 0, 0.26))
        leg = Part("leg_%s" % nm, tuple(hip), "pip")
        leg.loft(seg(hip, knee, 0.15, 0.11, 6), ["orange"])
        leg.finish(objs)
        shin = Part("leg_%s_shin" % nm, tuple(knee), "leg_%s" % nm)
        shin.ico(knee, 0.19, "orange")
        shin.loft(seg(knee, ankle, 0.11, 0.085, 6), ["orange"])
        shin.finish(objs)
        foot = Part("leg_%s_foot" % nm, tuple(ankle), "leg_%s_shin" % nm)
        foot.ico(ankle, 0.14, "orange")
        foot.box((ankle.x, ankle.y + 0.02, 0.13), (0.34, 0.34, 0.2), "orange", bevel=0.05)
        for ang in (-32.0, 0.0, 32.0):
            a = math.radians(ang + 180.0)
            dirv = Vector((math.sin(a), math.cos(a), 0))          # forward is -Y
            base = Vector((ankle.x, ankle.y, 0.13)) + dirv * 0.12
            mid = Vector((ankle.x, ankle.y, 0.06)) + dirv * 0.5
            tipp = Vector((ankle.x, ankle.y, 0.02)) + dirv * 0.68
            side = dirv.cross(Vector((0, 0, 1))).normalized()
            def quad(c, w, h, low):
                return [c + side * w + Vector((0, 0, h)), c - side * w + Vector((0, 0, h)),
                        c - side * w * 0.9 - Vector((0, 0, low)), c + side * w * 0.9 - Vector((0, 0, low))]
            r0, r1 = quad(base, 0.09, 0.07, 0.12), quad(mid, 0.065, 0.05, 0.06)
            r2 = quad(tipp, 0.02, 0.015, 0.02)
            foot.loft([r0, r1, r2], ["orange", "steel_dark"], cap_keys=("orange", "steel_dark"))
        foot.finish(objs)
    return objs


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = argv[0] if argv else "pip.glb"
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
    print("PIP parts=%d tris=%d bounds_min=%s bounds_max=%s" % (
        sum(1 for o in objs.values() if o.type == 'MESH'), tris, tuple(round(x, 3) for x in lo), tuple(round(x, 3) for x in hi)))
    bpy.ops.export_scene.gltf(filepath=out, export_format='GLB', use_selection=False, export_apply=True,
                              export_yup=True, export_materials='EXPORT', export_normals=True,
                              export_texcoords=False, export_extras=False, export_animations=False)
    if len(argv) > 1:
        bpy.ops.wm.save_as_mainfile(filepath=argv[1])
    print("PIP wrote", out)


main()
