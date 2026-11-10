"""Nature kit: oak, pine, rock, grass tuft, cloud, bush. All parametric in metres + seed."""
import numpy as np

from vox import Grid


def oak(seed=1, height=6.5, vs=0.25, crown=2.3, trunk=None):
    rng = np.random.default_rng(seed)
    R = crown * 1.9
    g = Grid(vs, (-R, 0, -R), (R, height + crown * 1.6, R))
    th = height * 0.55
    tw = trunk or (0.5 if vs >= 0.2 else 0.4)
    # trunk with a slight lean and two root flares
    lean = rng.uniform(-0.25, 0.25, 2)
    n = int(th / vs)
    for i in range(n):
        y = i * vs
        ox, oz = lean[0] * y / th, lean[1] * y / th
        w = tw + (0.25 if y < 0.5 else 0)
        g.box("bark", ox - w / 2, y, oz - w / 2, ox + w / 2, y + vs, oz + w / 2)
    top = np.array([lean[0], th, lean[1]])
    # branch stubs
    for _ in range(3):
        a = rng.uniform(0, 6.28)
        L = rng.uniform(0.8, 1.4)
        y0 = th * rng.uniform(0.55, 0.85)
        g.beam("bark", (lean[0] * y0 / th, y0, lean[1] * y0 / th),
               (np.cos(a) * L, y0 + L * 0.7, np.sin(a) * L), tw / 2.2)
    # crown: union of lumps, then noise erosion for a ragged silhouette
    lumps = []
    ncl = rng.integers(4, 7)
    for i in range(ncl):
        a = rng.uniform(0, 6.28)
        d = rng.uniform(0.0, crown * 0.75)
        c = (top[0] + np.cos(a) * d, th + crown * 0.55 + rng.uniform(-0.2, 1.1) * crown * 0.6, top[2] + np.sin(a) * d)
        r = rng.uniform(0.62, 0.95) * crown
        lumps.append((c, (r, r * rng.uniform(0.75, 0.95), r)))
    # centre lump
    lumps.append(((top[0], th + crown * 0.9, top[2]), (crown * 1.0, crown * 0.85, crown * 1.0)))
    noise = rng.random(g.shape)
    leaf = np.zeros(g.shape, bool)
    for c, r in lumps:
        bb = (c[0] - r[0], c[1] - r[1], c[2] - r[2], c[0] + r[0], c[1] + r[1], c[2] + r[2])

        def f(X, Y, Z, c=c, r=r):
            return ((X - c[0]) / r[0]) ** 2 + ((Y - c[1]) / r[1]) ** 2 + ((Z - c[2]) / r[2]) ** 2 <= 1.0
        # evaluate into leaf mask directly
        (a0, a1), (b0, b1), (c0, c1) = g._rng(0, bb[0], bb[3]), g._rng(1, bb[1], bb[4]), g._rng(2, bb[2], bb[5])
        if a1 <= a0:
            continue
        X = g.centres(0, a0, a1)[:, None, None]
        Y = g.centres(1, b0, b1)[None, :, None]
        Z = g.centres(2, c0, c1)[None, None, :]
        leaf[a0:a1, b0:b1, c0:c1] |= f(X, Y, Z)
    # erode: distance to nearest empty approx via random drop on exposed voxels (2 passes)
    for _ in range(2):
        pad = np.pad(leaf, 1)
        nb = sum(pad[1 + dx:1 + dx + leaf.shape[0], 1 + dy:1 + dy + leaf.shape[1], 1 + dz:1 + dz + leaf.shape[2]]
                 for dx, dy, dz in ((1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1)))
        exposed = leaf & (nb < 6)
        drop = exposed & (rng.random(leaf.shape) < 0.28)
        leaf &= ~drop
    # keep the trunk top inside the foliage
    mask = leaf & (g.a == 0)
    from vox import MATS
    g.a[mask] = MATS("leaves")
    return g


def pine(seed=1, height=9.0, vs=0.25, base_r=2.2):
    rng = np.random.default_rng(seed)
    g = Grid(vs, (-base_r - 0.6, 0, -base_r - 0.6), (base_r + 0.6, height + 0.6, base_r + 0.6))
    g.box("bark", -0.25, 0, -0.25, 0.25, height * 0.45, 0.25)
    ntier = int(height * 0.55 / 0.5)
    y = height * 0.22
    k = 0
    while y < height:
        t = (y - height * 0.22) / (height * 0.78)
        r = base_r * (1 - t) ** 0.9 + 0.3
        # tier of 2 voxel layers, ragged
        for dy in (0.0, vs):
            rr = r * (1.0 if dy == 0 else 0.72)
            g.fn("leaves_pine", lambda X, Y, Z, rr=rr: (X ** 2 + Z ** 2 <= rr * rr),
                 (-rr, y + dy, -rr, rr, y + dy + vs, rr))
        y += vs * 2
        k += 1
    # ragged: drop some outer voxels
    from vox import MATS
    leaf = g.a == MATS("leaves_pine")
    g.a[leaf & (rng.random(g.shape) < 0.12)] = 0
    return g


def rock(seed=1, r=1.0, vs=0.25, moss=True):
    rng = np.random.default_rng(seed)
    rx, ry, rz = r * rng.uniform(0.9, 1.4), r * rng.uniform(0.6, 0.9), r * rng.uniform(0.9, 1.3)
    g = Grid(vs, (-rx - 0.3, 0, -rz - 0.3), (rx + 0.3, ry * 2 + 0.4, rz + 0.3))
    phase = rng.uniform(0, 6.28, 6)

    def f(X, Y, Z):
        d = (X / rx) ** 2 + ((Y - ry * 0.55) / ry) ** 2 + (Z / rz) ** 2
        wob = 0.12 * np.sin(X * 2.1 + phase[0]) * np.sin(Z * 2.3 + phase[1]) + 0.1 * np.sin(Y * 3 + phase[2])
        return (d + wob <= 1.0) & (Y >= 0)
    g.fn("stone", f, (-rx - 0.3, 0, -rz - 0.3, rx + 0.3, ry * 2 + 0.4, rz + 0.3))
    if moss:
        # moss on upward-facing voxels
        a = g.a
        up = np.zeros(a.shape, bool)
        up[:, :-1, :] = (a[:, :-1, :] > 0) & (a[:, 1:, :] == 0)
        up[:, -1, :] = a[:, -1, :] > 0
        m = up & (rng.random(a.shape) < 0.55)
        from vox import MATS
        a[m] = MATS("moss")
    return g


def tuft(seed=1, vs=0.1):
    rng = np.random.default_rng(seed)
    g = Grid(vs, (-0.3, 0, -0.3), (0.3, 0.7, 0.3))
    for _ in range(rng.integers(5, 9)):
        x, z = rng.uniform(-0.2, 0.2, 2)
        h = rng.uniform(0.25, 0.6)
        g.box("grass_tuft", x - vs / 2, 0, z - vs / 2, x + vs / 2, h, z + vs / 2)
    return g


def bush(seed=1, vs=0.2, r=0.9):
    rng = np.random.default_rng(seed)
    g = Grid(vs, (-r - .2, 0, -r - .2), (r + .2, r * 1.5, r + .2))
    for _ in range(3):
        c = (rng.uniform(-r / 2, r / 2), r * 0.55, rng.uniform(-r / 2, r / 2))
        g.ellipsoid("leaves", c, (r * 0.7, r * 0.55, r * 0.7))
    return g


def cloud(seed=1, vs=3.0):
    rng = np.random.default_rng(seed)
    g = Grid(vs, (-40, 0, -14), (40, 12, 14))
    n = rng.integers(4, 8)
    for i in range(n):
        w = rng.uniform(10, 24)
        d = rng.uniform(6, 14)
        x = rng.uniform(-24, 24)
        z = rng.uniform(-5, 5)
        y = rng.uniform(0, 3)
        g.box("cloud", x - w / 2, y, z - d / 2, x + w / 2, y + rng.uniform(3, 6), z + d / 2)
    return g
