"""Voxel grid, metre-space primitives, greedy mesher with vertex AO, .vxm writer.

Everything an asset script does is in METRES in the asset's local frame; voxel size is a parameter, so the same
script can be re-run at 0.05 / 0.1 / 0.25 and the voxel-size experiment is free.
A voxel stores a uint8 material id (data/materials.json). That id is the "material tag" the future law tables use.
"""
import json
import math
import os
import struct

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
PAD = 2


class Mats:
    def __init__(self, path=None):
        path = path or os.path.join(ROOT, "data", "materials.json")
        with open(path) as f:
            self.list = json.load(f)["materials"]
        self.byname = {m["name"]: i + 1 for i, m in enumerate(self.list)}
        self.trans = np.zeros(256, bool)
        for i, m in enumerate(self.list):
            self.trans[i + 1] = m.get("cls", "opaque") != "opaque"

    def __call__(self, name):
        return self.byname[name]


MATS = Mats()


def M(name):
    return MATS.byname[name]


class Grid:
    """Dense uint8 voxel grid. lo/hi are metre bounds in asset-local space. Voxel i covers
    [lo + i*vs, lo + (i+1)*vs); a primitive sets a voxel when its CENTRE is inside the shape."""

    def __init__(self, vs, lo, hi):
        self.vs = float(vs)
        self.lo = np.array(lo, float)
        n = np.ceil((np.array(hi, float) - self.lo) / self.vs - 1e-6).astype(int)
        self.a = np.zeros(tuple(n), np.uint8)
        self.part_names = []
        self.p = None
        self.cur = None

    # ---- indexing helpers
    @property
    def shape(self):
        return self.a.shape

    def centres(self, axis, i0=0, i1=None):
        i1 = self.a.shape[axis] if i1 is None else i1
        return self.lo[axis] + (np.arange(i0, i1) + 0.5) * self.vs

    def _rng(self, axis, x0, x1):
        i0 = int(math.ceil((x0 - self.lo[axis]) / self.vs - 0.5))
        i1 = int(math.ceil((x1 - self.lo[axis]) / self.vs - 0.5))
        return max(i0, 0), min(i1, self.a.shape[axis])

    def use_part(self, name):
        if self.p is None:
            self.p = np.zeros(self.a.shape, np.uint8)
        if name is None:
            self.cur = None
            return
        if name not in self.part_names:
            self.part_names.append(name)
        self.cur = self.part_names.index(name) + 1

    def _apply(self, sl, mask, mat, only_empty=False):
        sub = self.a[sl]
        m = mask
        if only_empty:
            m = m & (sub == 0)
        if mat is None:  # carve
            sub[m] = 0
        else:
            sub[m] = mat if isinstance(mat, (int, np.integer)) else MATS(mat)
        if self.cur is not None and self.p is not None:
            self.p[sl][m] = self.cur if mat is not None else 0

    # ---- primitives (metres)
    def box(self, mat, x0, y0, z0, x1, y1, z1, only_empty=False):
        (a0, a1), (b0, b1), (c0, c1) = self._rng(0, x0, x1), self._rng(1, y0, y1), self._rng(2, z0, z1)
        if a1 <= a0 or b1 <= b0 or c1 <= c0:
            return
        sl = (slice(a0, a1), slice(b0, b1), slice(c0, c1))
        self._apply(sl, np.ones((a1 - a0, b1 - b0, c1 - c0), bool), mat, only_empty)

    def fn(self, mat, f, bbox, only_empty=False):
        """f(X,Y,Z) -> bool mask over voxel centres inside bbox=(x0,y0,z0,x1,y1,z1)."""
        x0, y0, z0, x1, y1, z1 = bbox
        (a0, a1), (b0, b1), (c0, c1) = self._rng(0, x0, x1), self._rng(1, y0, y1), self._rng(2, z0, z1)
        if a1 <= a0 or b1 <= b0 or c1 <= c0:
            return
        X = self.centres(0, a0, a1)[:, None, None]
        Y = self.centres(1, b0, b1)[None, :, None]
        Z = self.centres(2, c0, c1)[None, None, :]
        mask = np.broadcast_to(f(X, Y, Z), (a1 - a0, b1 - b0, c1 - c0))
        self._apply((slice(a0, a1), slice(b0, b1), slice(c0, c1)), mask, mat, only_empty)

    def ellipsoid(self, mat, c, r, only_empty=False):
        r = (r, r, r) if np.isscalar(r) else r
        bb = (c[0] - r[0], c[1] - r[1], c[2] - r[2], c[0] + r[0], c[1] + r[1], c[2] + r[2])
        self.fn(mat, lambda X, Y, Z: ((X - c[0]) / r[0]) ** 2 + ((Y - c[1]) / r[1]) ** 2 + ((Z - c[2]) / r[2]) ** 2 <= 1.0,
                bb, only_empty)

    def cyl(self, mat, axis, c, r, h0, h1, only_empty=False):
        """Cylinder along axis (0,1,2), centre c=(a,b) in the two other axes (in order), from h0 to h1."""
        o = [i for i in range(3) if i != axis]
        lo = [0, 0, 0]
        hi = [0, 0, 0]
        lo[axis], hi[axis] = h0, h1
        lo[o[0]], hi[o[0]] = c[0] - r, c[0] + r
        lo[o[1]], hi[o[1]] = c[1] - r, c[1] + r

        def f(X, Y, Z):
            V = (X, Y, Z)
            return (V[o[0]] - c[0]) ** 2 + (V[o[1]] - c[1]) ** 2 <= r * r
        self.fn(mat, f, tuple(lo + hi), only_empty)

    def beam(self, mat, p0, p1, t, only_empty=False, cheb=True):
        """Capsule-ish beam from p0 to p1, half-thickness t (Chebyshev -> square section, else round)."""
        p0 = np.array(p0, float)
        p1 = np.array(p1, float)
        d = p1 - p0
        L2 = float(d @ d) or 1e-9
        lo = np.minimum(p0, p1) - t
        hi = np.maximum(p0, p1) + t

        def f(X, Y, Z):
            Xb, Yb, Zb = np.broadcast_arrays(X, Y, Z)
            P = np.stack([Xb, Yb, Zb], -1)
            s = np.clip(((P - p0) @ d) / L2, 0, 1)
            q = p0 + s[..., None] * d
            diff = np.abs(P - q)
            dist = diff.max(-1) if cheb else np.sqrt((diff ** 2).sum(-1))
            return dist <= t
        self.fn(mat, f, tuple(lo) + tuple(hi), only_empty)

    def stamp(self, other, at=(0, 0, 0), only_nonzero=True):
        """Copy another grid (same vs) in at metre offset `at` (added to other's lo)."""
        assert abs(other.vs - self.vs) < 1e-9
        off = np.round((other.lo + np.array(at) - self.lo) / self.vs).astype(int)
        src = other.a
        lo = np.maximum(off, 0)
        hi = np.minimum(off + src.shape, self.a.shape)
        if np.any(hi <= lo):
            return
        s = tuple(slice(l - o, h - o) for l, h, o in zip(lo, hi, off))
        d = tuple(slice(l, h) for l, h in zip(lo, hi))
        sub = src[s]
        m = sub > 0 if only_nonzero else np.ones_like(sub, bool)
        self.a[d][m] = sub[m]

    def get(self, x, y, z):
        i = [int(math.floor((v - self.lo[k]) / self.vs)) for k, v in enumerate((x, y, z))]
        if any(i[k] < 0 or i[k] >= self.a.shape[k] for k in range(3)):
            return 0
        return int(self.a[tuple(i)])

    def count(self):
        return int((self.a > 0).sum())

    def rot90y(self, k=1):
        """Rotate k*90 degrees about the grid-centre y axis (grid must be square in xz for exactness)."""
        g = Grid.__new__(Grid)
        g.vs = self.vs
        g.part_names, g.p, g.cur = list(self.part_names), None, None
        g.a = np.rot90(self.a, k, axes=(0, 2)).copy()
        c = self.lo + np.array(self.a.shape) * self.vs / 2
        ext = np.array(g.a.shape) * self.vs
        g.lo = c - ext / 2
        return g


# --------------------------------------------------------------------------------------- mesher
def _greedy(key, flat):
    """2D greedy merge. key (U,V) int32, 0 = no face. Returns list of (u,v,w,h,key)."""
    U, V = key.shape
    kl = key.tolist()
    fl = flat.tolist()
    used = [[False] * V for _ in range(U)]
    out = []
    pts = np.argwhere(key > 0).tolist()
    for u, v in pts:
        if used[u][v]:
            continue
        k = kl[u][v]
        w = h = 1
        if fl[u][v]:
            while u + w < U and kl[u + w][v] == k and not used[u + w][v]:
                w += 1
            while v + h < V:
                row_ok = True
                for x in range(w):
                    if kl[u + x][v + h] != k or used[u + x][v + h]:
                        row_ok = False
                        break
                if not row_ok:
                    break
                h += 1
        for x in range(w):
            ux = used[u + x]
            for y in range(h):
                ux[v + y] = True
        out.append((u, v, w, h, k))
    return out


def _quads_to_verts(quads, vs, lo):
    """quads: array (n,8) [a, s, plane, u0, v0, w, h, key] global voxel indices. Returns pos, nrm, c0, idx."""
    pos_l, nrm_l, c0_l, idx_l = [], [], [], []
    base = 0
    for a in range(3):
        for s in (1, -1):
            q = quads[(quads[:, 0] == a) & (quads[:, 1] == s)]
            n = len(q)
            if n == 0:
                continue
            u_ax, v_ax = (a + 1) % 3, (a + 2) % 3
            plane = q[:, 2].astype(np.float64)
            u0 = q[:, 3].astype(np.float64)
            v0 = q[:, 4].astype(np.float64)
            u1 = u0 + q[:, 5]
            v1 = v0 + q[:, 6]
            key = q[:, 7]
            corners_uv = [(u0, v0), (u1, v0), (u1, v1), (u0, v1)]
            P = np.zeros((n, 4, 3))
            for ci, (cu, cv) in enumerate(corners_uv):
                P[:, ci, a] = plane
                P[:, ci, u_ax] = cu
                P[:, ci, v_ax] = cv
            P = P * vs + lo
            mat = (key & 255).astype(np.uint8)
            ao = np.stack([(key >> 8) & 3, (key >> 10) & 3, (key >> 12) & 3, (key >> 14) & 3], 1)
            nrm = np.zeros(3)
            nrm[a] = s
            if s > 0:  # Godot front faces are CLOCKWISE
                order = [0, 3, 2, 1]
            else:
                order = [0, 1, 2, 3]
            Po = P[:, order, :]
            aoo = ao[:, order]
            c0 = np.zeros((n, 4, 4), np.uint8)
            c0[:, :, 0] = mat[:, None]
            c0[:, :, 1] = (aoo * 85).astype(np.uint8)
            c0[:, :, 3] = 255
            # triangulation flip on AO anisotropy
            flip = (aoo[:, 0] + aoo[:, 2]) < (aoo[:, 1] + aoo[:, 3])
            b = base + np.arange(n) * 4
            i0 = np.where(flip[:, None], np.stack([b + 1, b + 2, b + 3, b + 1, b + 3, b + 0], 1),
                          np.stack([b + 0, b + 1, b + 2, b + 0, b + 2, b + 3], 1))
            pos_l.append(Po.reshape(-1, 3))
            nrm_l.append(np.tile(nrm, (n * 4, 1)))
            c0_l.append(c0.reshape(-1, 4))
            idx_l.append(i0.reshape(-1))
            base += n * 4
    if not pos_l:
        return None
    return (np.concatenate(pos_l).astype(np.float32), np.concatenate(nrm_l).astype(np.float32),
            np.concatenate(c0_l), np.concatenate(idx_l).astype(np.uint32))


DIRS = [(a, s) for a in range(3) for s in (1, -1)]


def mesh_region(P, Occ, i0, i1, trans_lut, vs, lo, ao_on=True):
    """P: padded id array (PAD on each side). i0,i1: voxel index ranges (3 tuples, in unpadded coords).
    Returns dict cls -> (pos,nrm,c0,idx)."""
    def sl(off=(0, 0, 0)):
        return tuple(slice(PAD + i0[k] + off[k], PAD + i1[k] + off[k]) for k in range(3))

    V = P[sl()]
    if not V.any():
        return {}
    trans = trans_lut
    out = {0: [], 1: []}
    tv = trans[V]
    for (a, s) in DIRS:
        off = [0, 0, 0]
        off[a] = s
        N = P[sl(tuple(off))]
        tn = trans[N]
        emit = (V > 0) & ((N == 0) | (~tv & tn) | (tv & tn & (N != V)))
        if not emit.any():
            continue
        u_ax, v_ax = (a + 1) % 3, (a + 2) % 3

        def occ_at(du, dv):
            o = [0, 0, 0]
            o[a] = s
            o[u_ax] += du
            o[v_ax] += dv
            return Occ[sl(tuple(o))]
        ao = []
        if ao_on:
            for (cu, cv) in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
                s1 = occ_at(cu, 0)
                s2 = occ_at(0, cv)
                c = occ_at(cu, cv)
                val = np.where(s1 & s2, 0, 3 - (s1.astype(np.int8) + s2 + c))
                ao.append(val.astype(np.int32))
        else:
            ao = [np.full(V.shape, 3, np.int32)] * 4
        aoall = np.stack(ao, 0)
        aoflag = np.where(tv, 3, 0)  # transparent: AO off
        a0 = np.where(tv, 3, aoall[0])
        a1 = np.where(tv, 3, aoall[1])
        a2 = np.where(tv, 3, aoall[2])
        a3 = np.where(tv, 3, aoall[3])
        key = (V.astype(np.int32) | (a0 << 8) | (a1 << 10) | (a2 << 12) | (a3 << 14)) * emit
        flat = (a0 == a1) & (a1 == a2) & (a2 == a3)
        for t in range(V.shape[a]):
            k2 = np.take(key, t, axis=a)
            if not k2.any():
                continue
            f2 = np.take(flat, t, axis=a)
            if a == 1:
                k2 = k2.T
                f2 = f2.T
            cls_is_trans = None
            quads = _greedy(k2, f2)
            if not quads:
                continue
            q = np.array(quads, np.int64)
            n = len(q)
            plane = i0[a] + t + (1 if s > 0 else 0)
            full = np.zeros((n, 8), np.int64)
            full[:, 0] = a
            full[:, 1] = s
            full[:, 2] = plane
            full[:, 3] = q[:, 0] + i0[u_ax]
            full[:, 4] = q[:, 1] + i0[v_ax]
            full[:, 5] = q[:, 2]
            full[:, 6] = q[:, 3]
            full[:, 7] = q[:, 4]
            cls = trans[(q[:, 4] & 255).astype(np.int64)]
            for c in (0, 1):
                sel = cls == bool(c)
                if sel.any():
                    out[c].append(full[sel])
    res = {}
    for c in (0, 1):
        if out[c]:
            r = _quads_to_verts(np.concatenate(out[c]), vs, lo)
            if r is not None:
                res[c] = r
    return res


def mesh_grid(g, chunk=(10 ** 6, 10 ** 6, 10 ** 6), cull_bottom=False, ao_on=True, mask=None):
    """Mesh a Grid into chunks. Returns list of dicts {pivot, bbox, surfaces:{cls:(pos,nrm,c0,idx)}}."""
    a = g.a if mask is None else np.where(mask, g.a, 0).astype(np.uint8)
    P = np.zeros(tuple(s + 2 * PAD for s in a.shape), np.uint8)
    P[PAD:-PAD, PAD:-PAD, PAD:-PAD] = a
    if cull_bottom:
        P[:, :PAD, :] = 1  # solid padding below: bottom faces are never emitted
    Occ = (P > 0) & ~MATS.trans[P]
    chunks = []
    shp = a.shape
    nx, ny, nz = [max(1, int(math.ceil(shp[k] / chunk[k]))) for k in range(3)]
    for cx in range(nx):
        for cy in range(ny):
            for cz in range(nz):
                i0 = (cx * chunk[0], cy * chunk[1], cz * chunk[2])
                i1 = (min(shp[0], i0[0] + chunk[0]), min(shp[1], i0[1] + chunk[1]), min(shp[2], i0[2] + chunk[2]))
                surf = mesh_region(P, Occ, i0, i1, MATS.trans, g.vs, g.lo, ao_on)
                if surf:
                    pos_all = np.concatenate([s[0] for s in surf.values()])
                    bb = list(pos_all.min(0)) + list(pos_all.max(0))
                    chunks.append({"pivot": (0.0, 0.0, 0.0), "bbox": bb, "surfaces": surf})
    return chunks


def write_vxm(path, chunks, vs, extra=None):
    nv = nt = 0
    with open(path, "wb") as f:
        f.write(b"VXM1")
        f.write(struct.pack("<fI", vs, len(chunks)))
        for ch in chunks:
            f.write(struct.pack("<3f6f", *ch["pivot"], *ch["bbox"]))
            surfs = sorted(ch["surfaces"].items())
            f.write(struct.pack("<I", len(surfs)))
            for cls, (pos, nrm, c0, idx) in surfs:
                f.write(struct.pack("<III", cls, len(pos), len(idx)))
                f.write(pos.astype("<f4").tobytes())
                f.write(nrm.astype("<f4").tobytes())
                f.write(c0.astype(np.uint8).tobytes())
                f.write(idx.astype("<u4").tobytes())
                nv += len(pos)
                nt += len(idx) // 3
    meta = {"vs": vs, "chunks": len(chunks), "verts": nv, "tris": nt}
    if extra:
        meta.update(extra)
    with open(path[:-4] + ".json", "w") as f:
        json.dump(meta, f)
    return meta


def bake(g, path, chunk=(10 ** 6, 10 ** 6, 10 ** 6), cull_bottom=False, extra=None, ao_on=True):
    chunks = mesh_grid(g, chunk, cull_bottom, ao_on)
    ex = {"voxels": g.count(), "size_m": [round(v, 3) for v in (np.array(g.shape) * g.vs)]}
    if extra:
        ex.update(extra)
    return write_vxm(path, chunks, g.vs, ex)


def bake_parts(g, outpath, pivots, extra=None):
    """Export each named part as one chunk whose vertices are relative to pivots[name]."""
    chunks = []
    names = []
    for i, name in enumerate(g.part_names):
        mask = g.p == (i + 1)
        if not mask.any():
            continue
        piv = np.array(pivots.get(name, (0, 0, 0)), float)
        gg = Grid.__new__(Grid)
        gg.vs, gg.a, gg.lo = g.vs, g.a, g.lo - piv
        gg.part_names, gg.p, gg.cur = [], None, None
        ch = mesh_grid(gg, mask=mask)
        for c in ch:
            c["pivot"] = tuple(piv)
            c["name"] = name
        chunks += ch
        names.append(name)
    ex = {"voxels": g.count(), "parts": names}
    if extra:
        ex.update(extra)
    return write_vxm(outpath, chunks, g.vs, ex)


def voronoi_clusters(g, k, seed=1, jitter=0.0):
    """Assign every solid voxel to one of k seeds (Voronoi in metre space, anisotropy-free). Returns id array 1..k."""
    rng = np.random.default_rng(seed)
    idx = np.argwhere(g.a > 0)
    pts = g.lo + (idx + 0.5) * g.vs
    seeds = pts[rng.choice(len(pts), k, replace=False)]
    # relax a few Lloyd steps for evenly sized chunks
    for _ in range(4):
        d = ((pts[:, None, :] - seeds[None]) ** 2).sum(-1)
        lab = d.argmin(1)
        for j in range(k):
            m = lab == j
            if m.any():
                seeds[j] = pts[m].mean(0)
    d = ((pts[:, None, :] - seeds[None]) ** 2).sum(-1)
    if jitter:
        d = d + rng.normal(0, jitter, d.shape)
    lab = d.argmin(1) + 1
    out = np.zeros(g.a.shape, np.uint8)
    out[tuple(idx.T)] = lab
    return out


def bake_clusters(g, labels, outpath, extra=None):
    """One chunk per cluster, pivot = cluster centroid; vertices relative to pivot."""
    chunks = []
    for j in range(1, int(labels.max()) + 1):
        mask = labels == j
        if not mask.any():
            continue
        idx = np.argwhere(mask)
        piv = g.lo + (idx.mean(0) + 0.5) * g.vs
        gg = Grid.__new__(Grid)
        gg.vs, gg.a, gg.lo = g.vs, g.a, g.lo - piv
        gg.part_names, gg.p, gg.cur = [], None, None
        ch = mesh_grid(gg, mask=mask)
        for c in ch:
            c["pivot"] = tuple(piv)
        chunks += ch
    # merge multi-chunk (none here: chunk size is huge) -> one chunk per cluster
    ex = {"voxels": g.count()}
    if extra:
        ex.update(extra)
    return write_vxm(outpath, chunks, g.vs, ex)
