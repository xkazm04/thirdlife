"""Structure kit (arena, crane, scaffold, house, props). Parametric functions in metres; seeds for variation."""
import math

import numpy as np

from vox import Grid, MATS

SPAN = 22.0     # half span of an arena rib (z)
SPRING = 6.0    # arch springing height
APEX = 14.0


# ------------------------------------------------------------------------------------------ arena
def rib_arch_params(span=SPAN, spring=SPRING, apex=APEX, th=1.2):
    rise = apex - spring
    R = (span ** 2 + rise ** 2) / (2 * rise)
    return R, apex - R, th  # radius (outer), centre y, thickness


def rib(vs=0.25, span=SPAN, spring=SPRING, apex=APEX, w=1.0, th=1.2):
    """Pre-cast concrete arch rib on two columns; local frame: x across width, z across span, y up (0 = floor)."""
    R, cy, th = rib_arch_params(span, spring, apex, th)
    g = Grid(vs, (-w / 2 - 0.5, 0, -span - 1.2), (w / 2 + 0.5, apex + 0.5, span + 1.2))

    def arch(X, Y, Z):
        d = np.sqrt(Z ** 2 + (Y - cy) ** 2)
        return (d <= R) & (d >= R - th) & (Y >= spring - 0.3) & (np.abs(Z) <= span + 0.6)
    g.fn("concrete", arch, (-w / 2, spring - 0.3, -span - 0.6, w / 2, apex + 0.1, span + 0.6))
    # precast joints: alternate segment tone along the arc, plus a steel flange band on the underside every 4 segments
    ang = lambda X, Y, Z: np.arctan2(Z, Y - cy)
    seg = lambda X, Y, Z: (np.floor((ang(X, Y, Z) + 1.5) / 0.11)).astype(int) % 2 == 0

    def dark_seg(X, Y, Z):
        return arch(X, Y, Z) & seg(X, Y, Z) & (g_a_is_concrete(X, Y, Z))
    cid = MATS("concrete")

    def g_a_is_concrete(X, Y, Z):
        return True
    g.fn("concrete_dark", lambda X, Y, Z: arch(X, Y, Z) & seg(X, Y, Z), (-w / 2, spring - 0.3, -span - 0.6, w / 2, apex + 0.1, span + 0.6))
    # steel edge flanges (top/bottom of the section)
    def flange(X, Y, Z):
        d = np.sqrt(Z ** 2 + (Y - cy) ** 2)
        return ((d <= R) & (d > R - 0.3) | (d >= R - th) & (d < R - th + 0.3)) & (Y >= spring - 0.3) & (np.abs(Z) <= span + 0.6) & \
            (np.abs(X) > w / 2 - 0.26)
    g.fn("metal_grey", flange, (-w / 2, spring - 0.3, -span - 0.6, w / 2, apex + 0.1, span + 0.6))
    # columns + footings + haunch gusset
    for sgn in (-1, 1):
        zc = sgn * (span - 0.4)
        g.box("concrete", -w / 2 - 0.1, 0.5, zc - 0.55, w / 2 + 0.1, spring, zc + 0.55)
        g.box("concrete_dark", -w / 2 - 0.4, 0, zc - 0.9, w / 2 + 0.4, 0.55, zc + 0.9)
        for k in range(1, 4):  # joint grooves
            g.box("concrete_dark", -w / 2 - 0.1, 0.5 + k * 1.4, zc - 0.55, w / 2 + 0.1, 0.5 + k * 1.4 + vs, zc + 0.55)
        for t in np.linspace(0, 1, 5):  # gusset
            g.box("concrete", -w / 2, spring - 1.0 + t * 0.8, zc - sgn * (0.6 + t * 0.9) - 0.4, w / 2, spring - 0.2, zc - sgn * (0.6 + t * 0.9) + 0.4)
    # rebar stubs at the crown (building site look)
    return g


def arch_point(t, span=SPAN, spring=SPRING, apex=APEX, inset=0.0):
    """Point on the arch centre-line (z,y) for t in [-1,1]."""
    R, cy, th = rib_arch_params(span, spring, apex)
    Rm = R - th / 2 - inset
    ang_max = math.asin(span / R)
    a = t * ang_max
    return Rm * math.sin(a), cy + Rm * math.cos(a), a


def rib_holo(vs=0.125, span=SPAN, spring=SPRING, apex=APEX, w=1.0, th=1.2, bays=None):
    """Blueprint ghost of a rib: voxel wireframe (emissive) + faint translucent skin (hologlass)."""
    R, cy, th = rib_arch_params(span, spring, apex, th)
    g = Grid(vs, (-w / 2 - 0.3, 0, -span - 1.4), (w / 2 + 0.3, apex + 0.6, span + 1.4))
    n = 90
    prev = None
    for i in range(n + 1):
        t = -1 + 2 * i / n
        for off, xx in ((0.0, -w / 2), (0.0, w / 2), (th, -w / 2), (th, w / 2)):
            z, y, a = arch_point(t, span, spring, apex)
            Rm = R - th / 2
            rr = R - off
            p = (xx, cy + rr * math.cos(a), rr * math.sin(a))
            g.box("holo_cyan", p[0] - vs, p[1] - vs, p[2] - vs, p[0] + vs, p[1] + vs, p[2] + vs)
    # cross ties every ~1.4 m of arc
    for i in range(0, n + 1, 3):
        t = -1 + 2 * i / n
        z, y, a = arch_point(t, span, spring, apex)
        for (rr_a, rr_b) in ((R, R - th),):
            pa = (-w / 2, cy + rr_a * math.cos(a), rr_a * math.sin(a))
            pb = (w / 2, cy + rr_b * math.cos(a), rr_b * math.sin(a))
            g.beam("holo_cyan", pa, pb, vs * 0.9)
            pa = (w / 2, cy + rr_a * math.cos(a), rr_a * math.sin(a))
            pb = (-w / 2, cy + rr_b * math.cos(a), rr_b * math.sin(a))
            g.beam("holo_cyan", pa, pb, vs * 0.9)
    # columns
    for sgn in (-1, 1):
        zc = sgn * (span - 0.4)
        for xx in (-w / 2 - 0.1, w / 2 + 0.1):
            for zz in (zc - 0.55, zc + 0.55):
                g.beam("holo_cyan", (xx, 0, zz), (xx, spring, zz), vs)
        for k in range(0, 5):
            y = k * spring / 4
            g.beam("holo_cyan", (-w / 2 - 0.1, y, zc - 0.55), (-w / 2 - 0.1, y, zc + 0.55), vs * 0.9)
            g.beam("holo_cyan", (w / 2 + 0.1, y, zc - 0.55), (w / 2 + 0.1, y, zc + 0.55), vs * 0.9)
    return g


def rib_holo_skin(vs=0.25, span=SPAN, spring=SPRING, apex=APEX, w=1.0, th=1.2):
    """Translucent hologram skin = same volume as the built rib (hologlass => surface 1)."""
    R, cy, th = rib_arch_params(span, spring, apex, th)
    g = Grid(vs, (-w / 2 - 0.5, 0, -span - 1.2), (w / 2 + 0.5, apex + 0.5, span + 1.2))

    def arch(X, Y, Z):
        d = np.sqrt(Z ** 2 + (Y - cy) ** 2)
        return (d <= R) & (d >= R - th) & (Y >= spring - 0.3) & (np.abs(Z) <= span + 0.6)
    g.fn("hologlass", arch, (-w / 2, spring - 0.3, -span - 0.6, w / 2, apex + 0.1, span + 0.6))
    for sgn in (-1, 1):
        zc = sgn * (span - 0.4)
        g.box("hologlass", -w / 2 - 0.1, 0.5, zc - 0.55, w / 2 + 0.1, spring, zc + 0.55)
    return g


def purlin(length=8.5 - 1.0, vs=0.125):
    g = Grid(vs, (0, -0.3, -0.3), (length, 0.3, 0.3))
    g.box("metal_grey", 0, -0.15, -0.15, length, 0.15, 0.15)
    g.box("metal_dark", 0, -0.15, -0.15, length, -0.15 + vs, 0.15)
    return g


def rink_sdf(X, Z, half=(30.0, 13.0), r=8.5):
    qx = np.abs(X) - (half[0] - r)
    qz = np.abs(Z) - (half[1] - r)
    return np.sqrt(np.maximum(qx, 0) ** 2 + np.maximum(qz, 0) ** 2) + np.minimum(np.maximum(qx, qz), 0) - r


def boards(vs=0.1, half=(30.0, 13.0), r=8.5):
    """Rink boards (white, kick plate, red cap), glass panels with steel posts. Origin = rink centre at floor level."""
    g = Grid(vs, (-half[0] - 1, 0, -half[1] - 1), (half[0] + 1, 3.2, half[1] + 1))

    def wall(t0, t1, y0, y1):
        return lambda X, Y, Z: (rink_sdf(X, Z, half, r) > -t1) & (rink_sdf(X, Z, half, r) <= -t0) & (Y >= y0) & (Y < y1)
    bb = (-half[0] - 1, 0, -half[1] - 1, half[0] + 1, 3.2, half[1] + 1)
    g.fn("boards_white", wall(0.0, 0.2, 0.0, 1.07), bb)
    g.fn("curb_white", wall(0.0, 0.2, 0.0, 0.25), bb)
    g.fn("metal_grey", wall(0.0, 0.1, 0.0, 0.1), bb)
    g.fn("line_red", wall(-0.02, 0.26, 1.07, 1.17), bb)
    # glass above boards, posts every ~2.4 m along the perimeter
    g.fn("glass", wall(0.05, 0.15, 1.17, 2.85), bb)
    # posts: sample the perimeter densely, place a post where arc-length crosses multiples of 2.4
    per = 2 * (2 * (half[0] - r) + 2 * (half[1] - r)) + 2 * math.pi * r
    n = int(per / 2.4)
    pts = []
    sx, sz = half[0] - r, half[1] - r
    segs = [("s", (sx, -half[1]), (-sx, -half[1])), ("a", (-sx, -sz), math.pi * 1.5, math.pi),
            ("s", (-half[0], -sz), (-half[0], sz)), ("a", (-sx, sz), math.pi, math.pi * 0.5),
            ("s", (-sx, half[1]), (sx, half[1])), ("a", (sx, sz), math.pi * 0.5, 0.0),
            ("s", (half[0], sz), (half[0], -sz)), ("a", (sx, -sz), 0.0, -math.pi * 0.5)]
    acc = 0.0
    step = per / n
    nxt = 0.0
    pos = []
    for sg in segs:
        if sg[0] == "s":
            (x0, z0), (x1, z1) = sg[1], sg[2]
            L = math.hypot(x1 - x0, z1 - z0)
            while nxt <= acc + L:
                t = (nxt - acc) / L
                pos.append((x0 + (x1 - x0) * t, z0 + (z1 - z0) * t))
                nxt += step
            acc += L
        else:
            (cx, cz), a0, a1 = sg[1], sg[2], sg[3]
            L = r * abs(a1 - a0)
            while nxt <= acc + L:
                t = (nxt - acc) / L
                a = a0 + (a1 - a0) * t
                pos.append((cx + r * math.cos(a), cz + r * math.sin(a)))
                nxt += step
            acc += L
    for (x, z) in pos:
        g.box("metal_grey", x - 0.08, 1.07, z - 0.08, x + 0.08, 2.9, z + 0.08)
    return g


def ice(vs=0.1, half=(30.0, 13.0), r=8.5):
    g = Grid(vs, (-half[0] - 0.4, -0.3, -half[1] - 0.4), (half[0] + 0.4, 0.0, half[1] + 0.4))
    bb = (-half[0] - 0.4, -0.3, -half[1] - 0.4, half[0] + 0.4, 0.0, half[1] + 0.4)
    inside = lambda X, Y, Z: rink_sdf(X, Z, half, r) <= -0.0
    g.fn("ice", inside, bb)
    ring = lambda cx, cz, rr, t: (lambda X, Y, Z: (np.abs(np.sqrt((X - cx) ** 2 + (Z - cz) ** 2) - rr) < t) & inside(X, Y, Z))
    # centre red line (dashed look through alternate tone is done by the shader ramp; keep solid), blue lines, goal lines
    g.fn("line_red", lambda X, Y, Z: (np.abs(X) < 0.15) & inside(X, Y, Z), bb)
    for sx in (-1, 1):
        g.fn("line_blue", lambda X, Y, Z, sx=sx: (np.abs(X - sx * 7.8) < 0.3) & inside(X, Y, Z), bb)
        g.fn("line_red", lambda X, Y, Z, sx=sx: (np.abs(X - sx * 26.0) < 0.1) & inside(X, Y, Z), bb)
        # face-off circles + dots
        for sz in (-1, 1):
            g.fn("line_red", ring(sx * 17.0, sz * 6.5, 4.5, 0.08), bb)
            g.fn("line_red", lambda X, Y, Z, sx=sx, sz=sz: (np.sqrt((X - sx * 17.0) ** 2 + (Z - sz * 6.5) ** 2) < 0.55), bb)
        # crease
        g.fn("line_blue", lambda X, Y, Z, sx=sx: (np.abs(np.sqrt((X - sx * 26.0) ** 2 + Z ** 2) - 1.9) < 0.07) & (np.abs(X) < np.abs(sx * 26.0)), bb)
    g.fn("line_blue", ring(0, 0, 4.5, 0.1), bb)
    g.fn("line_blue", lambda X, Y, Z: (np.sqrt(X ** 2 + Z ** 2) < 0.4), bb)
    return g


def goal(vs=0.05):
    g = Grid(vs, (-1.0, 0, -0.2), (1.0, 1.4, 1.2))
    for sx in (-0.9, 0.9):
        g.box("line_red", sx - 0.05, 0, -0.05, sx + 0.05, 1.22, 0.05)
        g.box("line_red", sx - 0.05, 0, 0.9, sx + 0.05, 0.1, 1.0)
    g.box("line_red", -0.95, 1.17, -0.05, 0.95, 1.27, 0.05)
    g.box("line_red", -0.95, 0.0, 0.92, 0.95, 0.1, 1.0)
    g.box("line_red", -0.95, 1.17, 0.45, 0.95, 1.22, 0.5)
    # net as a thin checker lattice on back and sides
    def net(X, Y, Z):
        lat = (np.floor(X / vs).astype(int) + np.floor(Y / vs).astype(int) + np.floor(Z / vs).astype(int)) % 4 == 0
        back = (Z > 0.93) & (Z < 0.93 + vs) & (np.abs(X) < 0.9) & (Y < 1.2)
        sidew = ((np.abs(X) > 0.88) & (np.abs(X) < 0.88 + vs)) & (Z > 0.0) & (Z < 0.93) & (Y < 1.2 - 0.9 * np.clip((0.93 - Z) / 0.93, 0, 1) * 0.0)
        top = (Y > 1.15) & (Y < 1.15 + vs) & (np.abs(X) < 0.9) & (Z > 0) & (Z < 0.93)
        return (back | sidew | top) & lat
    g.fn("net", net, (-1.0, 0, -0.2, 1.0, 1.4, 1.2))
    return g


def stands(vs=0.25, length=56.0, rows=9, tread=0.95, rise=0.5, seed=3):
    """Raked seating, seats in red/grey blocks; origin at front-centre at floor (row 0 front edge z=0, rising towards +z)."""
    rng = np.random.default_rng(seed)
    depth = rows * tread + 1.0
    g = Grid(vs, (-length / 2, 0, 0), (length / 2, rows * rise + 1.2, depth))
    for r_ in range(rows):
        z0 = r_ * tread
        y1 = (r_ + 1) * rise
        g.box("concrete", -length / 2, 0, z0, length / 2, y1, z0 + tread)
        g.box("concrete_dark", -length / 2, y1 - vs, z0, length / 2, y1, z0 + vs)
        # seats
        x = -length / 2 + 1.0
        cur = "seat_red" if rng.random() < 0.5 else "seat_grey"
        while x < length / 2 - 1.0:
            wlen = rng.integers(3, 9) * 0.5
            cur = "seat_red" if cur == "seat_grey" else "seat_grey"
            x1 = min(x + wlen, length / 2 - 1.0)
            if not (abs(((x + length / 2) % 12.0) - 6.0) < 0.9):  # aisle gaps every 12 m
                g.box(cur, x, y1, z0 + 0.05, x1, y1 + 0.35, z0 + 0.35)       # seat
                g.box(cur, x, y1 + 0.3, z0 + 0.05, x1, y1 + 0.8, z0 + 0.15)  # back
            x = x1
    g.box("concrete", -length / 2, 0, depth - 1.0, length / 2, rows * rise + 0.9, depth)
    # front wall rail
    g.box("metal_grey", -length / 2, 0.5 + 0.0, -0.0, length / 2, 0.5 + vs, 0.0 + vs)
    return g


def bench(vs=0.1):
    g = Grid(vs, (-2.2, 0, -0.5), (2.2, 1.6, 0.9))
    g.box("wood_plank", -2.0, 0.4, 0.0, 2.0, 0.5, 0.5)
    g.box("metal_dark", -2.0, 0, 0.0, -1.9, 0.4, 0.5)
    g.box("metal_dark", 1.9, 0, 0.0, 2.0, 0.4, 0.5)
    g.box("wood_plank", -2.0, 0.5, 0.45, 2.0, 1.0, 0.55)
    return g


# ------------------------------------------------------------------------------------------ site
def scaffold(w=3.0, h=6.0, d=1.5, vs=0.1, bays=1):
    g = Grid(vs, (-0.2, 0, -0.2), (w + 0.2, h + 1.2, d + 0.2))
    t = vs * 0.5
    xs = [w * i / bays for i in range(bays + 1)]
    levels = [0.0] + [2.0 * k for k in range(1, int(h / 2.0) + 1)]
    for x in xs:
        for z in (0, d):
            g.box("metal_yellow", x - t, 0, z - t, x + t, h + 1.0, z + t)
    for y in levels[1:] + [h + 1.0 - 0.1]:
        for z in (0, d):
            g.box("metal_yellow", 0 - t, y - t, z - t, w + t, y + t, z + t)
        for x in xs:
            g.box("metal_yellow", x - t, y - t, 0 - t, x + t, y + t, d + t)
    # planks at levels 2 and top-ish
    for y in (levels[1], levels[min(len(levels) - 1, 2)] if len(levels) > 2 else levels[1]):
        g.box("wood_plank", 0.0, y, 0.05, w, y + vs, d - 0.05)
    # diagonals on back face and side faces
    for i in range(bays):
        for k in range(len(levels) - 1):
            a, b = levels[k], levels[k + 1]
            if (i + k) % 2 == 0:
                g.beam("metal_yellow", (xs[i], a, 0), (xs[i + 1], b, 0), t)
            else:
                g.beam("metal_yellow", (xs[i + 1], a, 0), (xs[i], b, 0), t)
    for k in range(len(levels) - 1):
        g.beam("metal_yellow", (0, levels[k], 0), (0, levels[k + 1], d), t)
    # handrail
    for z in (0, d):
        g.box("metal_yellow", 0, h + 0.5, z - t, w, h + 0.5 + vs, z + t)
    return g


def crane_mast(h=30.0, vs=0.2, wd=2.0):
    g = Grid(vs, (-wd / 2 - 3.0, 0, -wd / 2 - 3.0), (wd / 2 + 3.0, h + 0.6, wd / 2 + 3.0))
    t = vs * 1.1
    # ballast + base
    g.box("concrete_dark", -2.6, 0, -2.6, 2.6, 0.8, 2.6)
    g.box("concrete", -2.2, 0.8, -2.2, 2.2, 1.4, 2.2)
    for sx in (-1, 1):
        for sz in (-1, 1):
            g.box("metal_yellow", sx * wd / 2 - t, 1.4, sz * wd / 2 - t, sx * wd / 2 + t, h, sz * wd / 2 + t)
    step = 2.0
    k = 0
    y = 1.4
    while y + step <= h:
        for z in (-wd / 2, wd / 2):
            g.beam("metal_yellow", (-wd / 2, y + step, z), (wd / 2, y + step, z), vs * 0.55)
            g.beam("metal_yellow", (-wd / 2, y, z), (wd / 2, y + step, z) if k % 2 == 0 else (wd / 2, y + step, z), vs * 0.55)
        for x in (-wd / 2, wd / 2):
            g.beam("metal_yellow", (x, y + step, -wd / 2), (x, y + step, wd / 2), vs * 0.55)
            g.beam("metal_yellow", (x, y, -wd / 2) if k % 2 == 0 else (x, y, wd / 2), (x, y + step, wd / 2) if k % 2 == 0 else (x, y + step, -wd / 2), vs * 0.55)
        y += step
        k += 1
    g.box("metal_yellow", -wd / 2 - 0.3, h - 0.4, -wd / 2 - 0.3, wd / 2 + 0.3, h + 0.5, wd / 2 + 0.3)
    return g


def crane_head(jib=30.0, counter=11.0, vs=0.2):
    """Rotating top. Local: pivot on mast axis, jib along +x, y=0 at slewing ring."""
    g = Grid(vs, (-counter - 1.5, -0.6, -2.0), (jib + 1.0, 8.0, 2.0))
    t = vs * 0.55
    # slewing ring + cab
    g.box("metal_dark", -1.4, 0.0, -1.4, 1.4, 0.5, 1.4)
    g.box("metal_yellow", -1.2, 0.5, 0.9, 1.6, 2.6, 2.0 - vs)      # cab body on +z side
    g.box("car_glass", 1.0, 1.1, 1.0, 1.6, 2.3, 2.0 - vs)
    g.box("metal_dark", -1.2, 2.6, 0.9, 1.7, 2.8, 2.0 - vs)
    # tower-top A-frame
    g.beam("metal_yellow", (-1.0, 0.5, 0), (0.0, 6.4, 0), t * 1.4)
    g.beam("metal_yellow", (1.0, 0.5, 0), (0.0, 6.4, 0), t * 1.4)
    # jib: triangular lattice (two lower chords, one upper chord)
    def lattice(x0, x1, y_lo, y_hi, half, step):
        x = x0
        k = 0
        g.beam("metal_yellow", (x0, y_lo, -half), (x1, y_lo, -half), t * 1.3)
        g.beam("metal_yellow", (x0, y_lo, half), (x1, y_lo, half), t * 1.3)
        g.beam("metal_yellow", (x0, y_hi, 0), (x1, y_hi, 0), t * 1.3)
        while x + step <= x1 + 1e-6:
            xa, xb = x, x + step
            g.beam("metal_yellow", (xa, y_lo, -half), (xa, y_lo, half), t)
            g.beam("metal_yellow", (xa, y_lo, -half), (xa, y_hi, 0), t)
            g.beam("metal_yellow", (xa, y_lo, half), (xa, y_hi, 0), t)
            ya = y_lo if k % 2 == 0 else y_hi
            yb = y_hi if k % 2 == 0 else y_lo
            g.beam("metal_yellow", (xa, y_lo if k % 2 == 0 else y_hi, -half if k % 2 == 0 else 0), (xb, y_hi if k % 2 == 0 else y_lo, 0 if k % 2 == 0 else -half), t)
            g.beam("metal_yellow", (xa, y_lo, half), (xb, y_hi, 0), t * 0.9)
            x += step
            k += 1
    lattice(0.6, jib, 0.0, 1.5, 0.7, 1.4)
    lattice(-counter, 0.6, 0.0, 1.3, 0.7, 1.4)
    # tie cables (thin chunky voxel lines)
    g.beam("metal_dark", (0.0, 6.4, 0), (jib - 0.5, 1.4, 0), t * 0.7)
    g.beam("metal_dark", (0.0, 6.4, 0), (-counter + 0.5, 1.2, 0), t * 0.7)
    # counterweights
    for i in range(4):
        g.box("concrete_dark", -counter + 0.4 + i * 1.3, -0.5, -0.9, -counter + 1.5 + i * 1.3, 0.3, 0.9)
    # nose + trolley
    g.box("metal_yellow", jib - 0.2, -0.2, -0.5, jib + 0.5, 1.7, 0.5)
    g.box("metal_dark", jib - 4.0, -0.5, -0.5, jib - 3.0, 0.2, 0.5)
    return g


def crane_load(drop=9.0, vs=0.1, kind="slab"):
    """Pendulum: pivot at top (0,0,0) = trolley; hangs down -y."""
    g = Grid(vs, (-1.8, -drop - 1.6, -1.0), (1.8, 0.3, 1.0))
    g.box("metal_dark", -0.25, -0.5, -0.25, 0.25, 0.0, 0.25)      # trolley block
    g.beam("metal_dark", (0, -0.5, 0), (0, -drop + 1.2, 0), 0.05)  # cable
    g.box("metal_yellow", -0.3, -drop + 1.2 - 0.5, -0.3, 0.3, -drop + 1.2, 0.3)  # hook block
    top = -drop + 0.9
    for sx in (-1.2, 1.2):
        g.beam("metal_dark", (0, top, 0), (sx, top - 1.0, 0), 0.04)
    if kind == "slab":
        g.box("concrete", -1.5, top - 1.7, -0.5, 1.5, top - 1.0, 0.5)
        g.box("concrete_dark", -1.5, top - 1.7, -0.5, 1.5, top - 1.65, 0.5)
    else:
        for i in range(3):
            g.box("concrete", -1.4 + i * 0.95, top - 1.7, -0.45, -0.5 + i * 0.95, top - 1.0, 0.45)
    return g


def pallet_blocks(vs=0.1, nx=3, nz=2, ny=2):
    w = 0.9
    g = Grid(vs, (-nx * w / 2 - 0.1, 0, -nz * w / 2 - 0.1), (nx * w / 2 + 0.1, 0.2 + ny * 0.6 + 0.1, nz * w / 2 + 0.1))
    g.box("wood_plank", -nx * w / 2, 0, -nz * w / 2, nx * w / 2, 0.15, nz * w / 2)
    for ix in range(nx):
        for iz in range(nz):
            for iy in range(ny):
                x0 = -nx * w / 2 + ix * w + 0.03
                z0 = -nz * w / 2 + iz * w + 0.03
                y0 = 0.15 + iy * 0.6
                g.box("concrete" if (ix + iz + iy) % 2 == 0 else "concrete_dark", x0, y0, z0, x0 + w - 0.06, y0 + 0.57, z0 + w - 0.06)
    return g


def crate(vs=0.1, s=0.9):
    g = Grid(vs, (-s / 2 - 0.05, 0, -s / 2 - 0.05), (s / 2 + 0.05, s + 0.05, s / 2 + 0.05))
    g.box("wood_plank", -s / 2, 0, -s / 2, s / 2, s, s / 2)
    for sx in (-1, 1):
        for sz in (-1, 1):
            g.box("wood_dark", sx * s / 2 - (0.12 if sx > 0 else 0), 0, sz * s / 2 - (0.12 if sz > 0 else 0),
                  sx * s / 2 + (0 if sx > 0 else 0.12), s, sz * s / 2 + (0 if sz > 0 else 0.12))
    g.box("wood_dark", -s / 2, s - 0.1, -s / 2, s / 2, s, s / 2)
    return g


def barrier_stripe(vs=0.1, length=1.8):
    g = Grid(vs, (-length / 2, 0, -0.2), (length / 2, 1.0, 0.2))
    n = int(length / 0.3)
    for i in range(n):
        g.box("curb_red" if i % 2 == 0 else "curb_white", -length / 2 + i * 0.3, 0.45, -0.1, -length / 2 + (i + 1) * 0.3, 0.75, 0.1)
    g.box("metal_grey", -length / 2 + 0.1, 0, -0.1, -length / 2 + 0.2, 0.45, 0.1)
    g.box("metal_grey", length / 2 - 0.2, 0, -0.1, length / 2 - 0.1, 0.45, 0.1)
    return g


def lumber(vs=0.1, n=5, length=2.4):
    g = Grid(vs, (-length / 2, 0, -0.5), (length / 2, 0.6, 0.5))
    for i in range(n):
        y = (i // 2) * 0.12
        z = -0.3 + (i % 2) * 0.35 + (0.15 if (i // 2) % 2 else 0)
        g.box("plank_light" if i % 2 else "wood_frame", -length / 2 + 0.05 * (i % 3), y, z, length / 2 - 0.1 * (i % 2), y + 0.12, z + 0.3)
    return g


def lamp(vs=0.1, h=4.2):
    g = Grid(vs, (-0.5, 0, -0.5), (0.9, h + 0.5, 0.5))
    g.box("pole", -0.1, 0, -0.1, 0.1, h, 0.1)
    g.box("pole", -0.2, 0, -0.2, 0.2, 0.3, 0.2)
    g.box("pole", -0.1, h - 0.1, -0.1, 0.7, h, 0.1)
    g.box("metal_dark", 0.5, h - 0.3, -0.2, 0.9, h - 0.1, 0.2)
    g.box("lamp_glow", 0.55, h - 0.38, -0.15, 0.85, h - 0.3, 0.15)
    return g


def fence(vs=0.1, length=2.4):
    g = Grid(vs, (-length / 2 - 0.1, 0, -0.1), (length / 2 + 0.1, 1.1, 0.1))
    for x in (-length / 2, 0.0, length / 2):
        g.box("wood_dark", x - 0.06, 0, -0.06, x + 0.06, 1.05, 0.06)
    g.box("wood_plank", -length / 2, 0.4, -0.04, length / 2, 0.55, 0.04)
    g.box("wood_plank", -length / 2, 0.75, -0.04, length / 2, 0.9, 0.04)
    return g


# ------------------------------------------------------------------------------------------ house
def house(vs=0.15, w=9.0, d=6.6, wall_h=3.0, seed=2):
    """Log cabin with stone footing, shingle gable roof along x, chimney, lit windows and door on +z (front)."""
    rng = np.random.default_rng(seed)
    pitch = 0.95
    roof_h = (d / 2 + 0.7) * pitch
    g = Grid(vs, (-w / 2 - 1.2, 0, -d / 2 - 1.6), (w / 2 + 1.2, wall_h + roof_h + 2.6, d / 2 + 2.4))
    fy = 0.6
    # footing: stone, noisy
    g.box("stone", -w / 2 - 0.15, 0, -d / 2 - 0.15, w / 2 + 0.15, fy, d / 2 + 0.15)
    m = (rng.random(g.shape) < 0.25) & (g.a == MATS("stone"))
    g.a[m] = MATS("stone_dark")
    # log walls: alternating rows
    rows = int((wall_h - fy) / 0.3)
    for r in range(rows):
        y0 = fy + r * 0.3
        mat = "wood_log" if r % 2 == 0 else "wood_plank"
        g.box(mat, -w / 2, y0, -d / 2, w / 2, y0 + 0.3, d / 2)
        if r % 2 == 0:  # log ends poke out at corners
            g.box("wood_log", -w / 2 - 0.15, y0, -d / 2 - 0.15, -w / 2 + 0.3, y0 + 0.3, d / 2 + 0.15)
            g.box("wood_log", w / 2 - 0.3, y0, -d / 2 - 0.15, w / 2 + 0.15, y0 + 0.3, d / 2 + 0.15)
        else:
            g.box("wood_plank", -d / 2 - 0.15 + 0.0 - 0.0 - 0.0 + 0.15 - 0.15, y0, -d / 2 - 0.15, -w / 2 + 0.0, y0 + 0.3, -d / 2 + 0.15) if False else None
    # carve interior hollow (so windows glow only on the surface; keeps voxel count honest)
    g.box(None, -w / 2 + 0.45, fy + 0.15, -d / 2 + 0.45, w / 2 - 0.45, wall_h + 0.1, d / 2 - 0.45)
    # corner posts
    for sx in (-1, 1):
        for sz in (-1, 1):
            g.box("wood_dark", sx * w / 2 - (0.0 if sx > 0 else -0.0) - (0.3 if sx > 0 else 0), fy, sz * d / 2 - (0.3 if sz > 0 else 0),
                  sx * w / 2 + (0 if sx > 0 else 0.3), wall_h, sz * d / 2 + (0 if sz > 0 else 0.3))
    # roof: gable along x. rafters surface height above wall plate
    ov = 0.7

    def roof(X, Y, Z):
        zz = np.abs(Z)
        top = wall_h + (d / 2 + ov - zz) * pitch
        return (Y >= top - 0.45) & (Y < top) & (zz <= d / 2 + ov) & (np.abs(X) <= w / 2 + ov)
    g.fn("shingle", roof, (-w / 2 - ov, wall_h - 0.5, -d / 2 - ov, w / 2 + ov, wall_h + roof_h + 0.2, d / 2 + ov))
    # shingle rows: darker every other course
    rowdark = lambda X, Y, Z: (np.floor((np.abs(Z) * pitch + 0.0) / 0.3).astype(int) % 2 == 0)
    sh = MATS("shingle")
    # ridge cap
    g.box("wood_dark", -w / 2 - ov, wall_h + (ov + d / 2) * pitch - 0.0 - 0.0 - (d / 2 + ov) * pitch + (d / 2 + ov) * pitch - 0.15, -0.15,
          w / 2 + ov, wall_h + (d / 2 + ov) * pitch + 0.15, 0.15)
    # gable fill (wood) on both x ends
    def gable(X, Y, Z):
        zz = np.abs(Z)
        top = wall_h + (d / 2 + ov - zz) * pitch - 0.45
        return (Y >= wall_h - 0.1) & (Y < top) & (zz <= d / 2) & (np.abs(X) > w / 2 - 0.45) & (np.abs(X) <= w / 2)
    g.fn("wood_plank", gable, (-w / 2, wall_h - 0.1, -d / 2, w / 2, wall_h + roof_h, d / 2))
    # fascia boards at eaves
    g.box("wood_dark", -w / 2 - ov, wall_h - 0.5 + (d / 2 + ov) * 0.0 + 0.0, d / 2 + ov - 0.15, w / 2 + ov, wall_h - 0.15 + 0.0, d / 2 + ov)
    # chimney (stone + brick) on the left gable
    cx, cz = -w / 2 + 1.1, -0.2
    g.box("brick", cx - 0.5, fy, cz - 0.5, cx + 0.5, wall_h + roof_h + 0.9, cz + 0.5)
    g.box("stone_dark", cx - 0.6, wall_h + roof_h + 0.9, cz - 0.6, cx + 0.6, wall_h + roof_h + 1.15, cz + 0.6)
    # windows (front +z) and door
    zf = d / 2
    def window(x, y, wd, ht):
        g.box("wood_dark", x - wd / 2 - 0.15, y - 0.15, zf - 0.3, x + wd / 2 + 0.15, y + ht + 0.15, zf + 0.12)
        g.box("window_glow", x - wd / 2, y, zf - 0.05, x + wd / 2, y + ht, zf + 0.12 - 0.0)
        g.box("wood_dark", x - 0.05, y, zf - 0.05, x + 0.05, y + ht, zf + 0.15)       # mullion
        g.box("wood_dark", x - wd / 2, y + ht / 2 - 0.05, zf - 0.05, x + wd / 2, y + ht / 2 + 0.05, zf + 0.15)
        g.box("wood_plank", x - wd / 2 - 0.25, y - 0.3, zf, x + wd / 2 + 0.25, y - 0.15, zf + 0.35)  # sill
    window(-w / 2 + 2.6, fy + 0.85, 1.2, 1.2)
    window(w / 2 - 1.9, fy + 0.85, 1.2, 1.2)
    # door
    dx = 0.4
    g.box("wood_dark", dx - 0.55, fy, zf - 0.3, dx + 0.55, fy + 2.0, zf + 0.15)
    g.box("wood_plank", dx - 0.45, fy, zf - 0.1, dx + 0.45, fy + 1.9, zf + 0.2)
    g.box("wood_dark", dx - 0.45, fy + 1.0, zf - 0.1, dx + 0.45, fy + 1.07, zf + 0.22)
    g.box("gold", dx + 0.25, fy + 0.95, zf + 0.2, dx + 0.35, fy + 1.05, zf + 0.3)
    # steps + porch lamp
    g.box("stone", dx - 0.9, 0, zf + 0.1, dx + 0.9, 0.3, zf + 0.9)
    g.box("stone_dark", dx - 0.9, 0.3, zf + 0.1, dx + 0.9, 0.6, zf + 0.5)
    g.box("pole", dx + 0.75, fy + 1.9, zf + 0.1, dx + 0.85, fy + 2.1, zf + 0.4)
    g.box("lamp_glow", dx + 0.7, fy + 1.5, zf + 0.2, dx + 0.9, fy + 1.9, zf + 0.4)
    # side windows on the long back? small ones on -x gable
    return g


def house_frame(vs=0.15, w=6.0, d=5.6, seed=4):
    """Half-built timber frame extension: floor, posts, plates, partial wall boards, partial rafters."""
    rng = np.random.default_rng(seed)
    wall_h = 3.0
    g = Grid(vs, (-w / 2 - 0.5, 0, -d / 2 - 0.5), (w / 2 + 0.5, wall_h + 3.0, d / 2 + 0.7))
    g.box("stone", -w / 2 - 0.1, 0, -d / 2 - 0.1, w / 2 + 0.1, 0.5, d / 2 + 0.1)
    g.box("wood_plank", -w / 2, 0.5, -d / 2, w / 2, 0.65, d / 2)
    post = 0.3
    xs = np.linspace(-w / 2, w / 2, 5)
    zs = np.linspace(-d / 2, d / 2, 5)
    h0 = 0.65
    def p(x, z, h=wall_h):
        g.box("wood_frame", x - post / 2, h0, z - post / 2, x + post / 2, h, z + post / 2)
    for x in xs:
        p(x, -d / 2)
        p(x, d / 2)
    for z in zs[1:-1]:
        p(-w / 2, z)
        p(w / 2, z)
    # plates
    for z in (-d / 2, d / 2):
        g.box("wood_frame", -w / 2 - 0.1, wall_h, z - 0.15, w / 2 + 0.1, wall_h + 0.3, z + 0.15)
    for x in (-w / 2, w / 2):
        g.box("wood_frame", x - 0.15, wall_h, -d / 2, x + 0.15, wall_h + 0.3, d / 2)
    # mid rails
    for z in (-d / 2, d / 2):
        g.box("wood_frame", -w / 2, h0 + 1.25, z - 0.1, w / 2, h0 + 1.45, z + 0.1)
    # braces
    g.beam("wood_frame", (xs[0], h0, d / 2), (xs[1], wall_h, d / 2), 0.1)
    g.beam("wood_frame", (xs[3], wall_h, d / 2), (xs[4], h0, d / 2), 0.1)
    # partial wall boards on back wall (-z), lower half, some missing
    for i in range(4):
        if i != 2:
            g.box("plank_light", xs[i] + 0.15, h0, -d / 2 - 0.12, xs[i + 1] - 0.15, h0 + 1.9 - i * 0.2, -d / 2 + 0.0)
    # partial rafters + ridge beam
    rise = 1.9
    for i, x in enumerate(xs):
        if i in (0, 1, 3):
            g.beam("wood_frame", (x, wall_h + 0.3, -d / 2), (x, wall_h + 0.3 + rise, 0), 0.1)
            g.beam("wood_frame", (x, wall_h + 0.3, d / 2), (x, wall_h + 0.3 + rise, 0), 0.1)
    g.box("wood_frame", xs[0] - 0.1, wall_h + 0.3 + rise - 0.1, -0.12, xs[3] + 0.1, wall_h + 0.3 + rise + 0.1, 0.12)
    # ladder
    g.box("wood_plank", w / 2 + 0.2, 0.0, d / 2 - 0.1, w / 2 + 0.3, 3.3, d / 2 + 0.0)
    g.box("wood_plank", w / 2 + 0.7, 0.0, d / 2 - 0.1, w / 2 + 0.8, 3.3, d / 2 + 0.0)
    for k in range(10):
        g.box("wood_plank", w / 2 + 0.2, 0.3 + k * 0.33, d / 2 - 0.1, w / 2 + 0.8, 0.38 + k * 0.33, d / 2 + 0.0)
    return g


# ------------------------------------------------------------------------------------------ barrier
def wall_block(vs=0.1, size=(2.4, 1.0, 0.8), seed=1):
    """Concrete barrier block (ONE mesh while intact). Grooves + chipped corners; the same grid is Voronoi-split for debris."""
    rng = np.random.default_rng(seed)
    sx, sy, sz = size
    g = Grid(vs, (-sx / 2, 0, -sz / 2), (sx / 2, sy, sz / 2))
    g.box("concrete", -sx / 2, 0, -sz / 2, sx / 2, sy, sz / 2)
    # horizontal groove + cap
    g.box("concrete_dark", -sx / 2, sy * 0.55, -sz / 2, sx / 2, sy * 0.55 + vs, sz / 2, )
    g.box("concrete_dark", -sx / 2, sy - vs, -sz / 2, sx / 2, sy, sz / 2)
    g.box("concrete_dark", -vs / 2, 0, -sz / 2, vs / 2, sy, sz / 2)   # vertical joint mid-block
    # rough noise: speckle of dark voxels on the front/back faces
    a = g.a
    spk = rng.random(a.shape) < 0.07
    a[spk & (a == MATS("concrete"))] = MATS("concrete_dark")
    # chip corners
    for (cx, cy, cz) in ((0, 0, 0), (1, 1, 0), (0, 1, 1), (1, 1, 1)):
        i = cx * (a.shape[0] - 1)
        j = cy * (a.shape[1] - 1)
        k = cz * (a.shape[2] - 1)
        if rng.random() < 0.6:
            a[i, j, k] = 0
    return g


def shard(vs=0.1, seed=1, n=3):
    rng = np.random.default_rng(seed)
    g = Grid(vs, (-0.3, -0.3, -0.3), (0.3, 0.3, 0.3))
    c = np.array([0.0, 0.0, 0.0])
    for _ in range(n + 2):
        p = rng.uniform(-0.1, 0.1, 3)
        g.box("concrete" if rng.random() < 0.7 else "concrete_dark", p[0] - vs, p[1] - vs, p[2] - vs,
              p[0] + vs * rng.integers(1, 3), p[1] + vs * rng.integers(1, 3), p[2] + vs * rng.integers(1, 3))
    return g


def roof_skin(vs=0.25, length=7.5, span=SPAN, spring=SPRING, apex=APEX, th=1.2, seed=3):
    """Cladding panels for one bay between two ribs (some panels missing: work in progress)."""
    rng = np.random.default_rng(seed)
    R, cy, th = rib_arch_params(span, spring, apex, th)
    g = Grid(vs, (0, spring - 0.6, -span - 1.2), (length, apex + 0.8, span + 1.2))
    n = 14
    for i in range(n):
        if rng.random() < 0.28:
            continue
        a0 = -math.asin(span / R) + i * 2 * math.asin(span / R) / n
        a1 = a0 + 2 * math.asin(span / R) / n - 0.012

        def panel(X, Y, Z, a0=a0, a1=a1):
            d = np.sqrt(Z ** 2 + (Y - cy) ** 2)
            ang = np.arctan2(Z, Y - cy)
            return (d <= R + 0.32) & (d >= R + 0.07) & (ang >= a0) & (ang < a1) & (Y >= spring - 0.2)
        g.fn("metal_grey" if i % 3 else "metal_dark", panel, (0.05, spring - 0.3, -span - 1.0, length - 0.05, apex + 0.6, span + 1.0))
    return g
