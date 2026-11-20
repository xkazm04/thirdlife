# Diorama day (20 Nov 2026), surfaces: the six material textures of the toy-diorama model, made here and nowhere else.
#   python engine/style/dio/make_tex.py <out dir>          writes felt.png clay.png wood.png cast.png soil.png wool.png (RGBA, tileable)
#   then engine/style/dio/bake_tex.gd turns them into engine/style/dio/tex/*.res (mipmaps inside, no import step).
# One texture = one handmade material seen from above, as HEIGHTS:
#   R, G = the slope of the height along u and v (0.5 = flat), B = tone (0.5 = the key's own colour), A = height.
# The shader lights the slope and multiplies the tone; mipmaps average both, so far away a surface goes calm and flat
# instead of boiling or smearing. Deterministic: one seed per texture.
import sys, os
import numpy as np
import cv2

def fnoise(n, lo, hi, rng, aniso=(1.0, 1.0)):
    """periodic band noise: wavelengths between lo and hi texels (aniso > 1 stretches it along x, y). mean 0, std 1"""
    w = rng.standard_normal((n, n))
    fy = np.fft.fftfreq(n)[:, None] * aniso[1]
    fx = np.fft.fftfreq(n)[None, :] * aniso[0]
    f = np.sqrt(fx * fx + fy * fy)
    f[0, 0] = 1.0
    band = np.exp(-(f * hi) ** -2.0 * 0.5) * np.exp(-(f * lo) ** 2 * 0.5)
    band[0, 0] = 0.0
    out = np.fft.ifft2(np.fft.fft2(w) * band).real
    return out / (out.std() + 1e-9)

def blur(a, sigma):
    n = a.shape[0]
    fy = np.fft.fftfreq(n)[:, None]; fx = np.fft.fftfreq(a.shape[1])[None, :]
    g = np.exp(-2.0 * (np.pi * sigma) ** 2 * (fx * fx + fy * fy))
    return np.fft.ifft2(np.fft.fft2(a) * g).real

def down2(a):
    return (a[0::2, 0::2] + a[1::2, 0::2] + a[0::2, 1::2] + a[1::2, 1::2]) * 0.25

def pack(h, tone, path, slope_k=None):
    """h any range, tone around 0 (about -1..1). Slopes are scaled so nearly all of them fit; returns the scale."""
    h = h - h.min(); h = h / (h.max() + 1e-9)
    sx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5
    sy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 0.5
    if slope_k is None:
        slope_k = 0.92 / np.percentile(np.abs(np.concatenate([sx.ravel(), sy.ravel()])), 99.7)
    r = np.clip(0.5 + 0.5 * sx * slope_k, 0, 1)
    g = np.clip(0.5 + 0.5 * sy * slope_k, 0, 1)
    b = np.clip(0.5 + 0.5 * tone, 0, 1)
    img = np.stack([b, g, r, h], axis=-1)   # cv2 writes BGRA
    cv2.imwrite(path, np.round(img * 255.0).astype(np.uint8))
    print("%s: %dx%d slope_k %.2f tone mean %.3f std %.3f" % (os.path.basename(path), h.shape[1], h.shape[0], slope_k, b.mean(), b.std()))

def wrap_draw(draw, x, y, reach, S):
    """call draw(dx, dy) for every wrapped copy of something at (x, y) that reaches `reach` texels"""
    for dx in (-S, 0, S):
        if x + dx < -reach or x + dx > S + reach: continue
        for dy in (-S, 0, S):
            if y + dy < -reach or y + dy > S + reach: continue
            draw(dx, dy)

def felt(n, rng):
    """flocking / felt: short thick fibres lying every way, pile on pile; the gaps between them are dark"""
    S = n * 2
    H = np.zeros((S, S), np.uint8); T = np.full((S, S), 128, np.uint8)
    N = 46000
    z = np.sort(rng.random(N))
    for i in range(N):
        x, y = rng.random(2) * S
        a = rng.random() * np.pi * 2.0
        L = rng.uniform(22.0, 56.0)
        bend = rng.normal(0.0, 0.22) * L
        d = np.array([np.cos(a), np.sin(a)]); nrm = np.array([-d[1], d[0]])
        p0 = np.array([x, y]) - d * L * 0.5; p2 = np.array([x, y]) + d * L * 0.5; p1 = np.array([x, y]) + nrm * bend
        ts = np.linspace(0.0, 1.0, 7)[:, None]
        pts = (1 - ts) ** 2 * p0 + 2 * ts * (1 - ts) * p1 + ts ** 2 * p2
        hv = int(40 + 175 * z[i]); tv = int(np.clip(128 + rng.normal(0.0, 46.0), 10, 245))
        wd = int(rng.integers(4, 7))
        def draw(dx, dy):
            q = np.round((pts + [dx, dy]) * 16).astype(np.int32).reshape(-1, 1, 2)
            cv2.polylines(H, [q], False, max(hv - 34, 1), wd, cv2.LINE_AA, 4)
            cv2.polylines(H, [q], False, hv, max(wd - 3, 1), cv2.LINE_AA, 4)
            cv2.polylines(T, [q], False, tv, wd, cv2.LINE_AA, 4)
        wrap_draw(draw, x, y, L, S)
    h = down2(blur(H.astype(np.float64) / 255.0, 1.1))
    t = down2(blur(T.astype(np.float64) / 255.0, 0.8)) - 0.5
    hp = h - blur(h, 6.0)                        # a fibre on top is lighter, the gap under it is in shade
    tone = t * 1.5 + hp * 1.9 + fnoise(n, 30.0, 160.0, rng) * 0.05
    return h + fnoise(n, 40.0, 220.0, rng) * 0.05, tone

def clay(n, rng):
    """modelling clay pressed by hand: lumps, thumb dents, fingerprints, knife drags, crumbs and pits"""
    S = n
    yy, xx = np.mgrid[0:S, 0:S].astype(np.float64)
    h = fnoise(S, 90.0, 420.0, rng) * 0.50 + fnoise(S, 24.0, 90.0, rng) * 0.10
    tone = fnoise(S, 120.0, 600.0, rng) * 0.10
    def wd(a, c):   # wrapped distance along one axis
        d = np.abs(a - c); return np.minimum(d, S - d)
    for _ in range(46):          # thumb dents
        cx, cy = rng.random(2) * S; r = rng.uniform(26.0, 62.0); a = rng.random() * np.pi; e = rng.uniform(1.0, 1.7)
        dx = (xx - cx + S / 2) % S - S / 2; dy = (yy - cy + S / 2) % S - S / 2
        u = (dx * np.cos(a) + dy * np.sin(a)) / (r * e); v = (-dx * np.sin(a) + dy * np.cos(a)) / r
        d2 = u * u + v * v
        dent = np.exp(-d2 * 1.6)
        h -= dent * rng.uniform(0.25, 0.55)
        h += np.exp(-(np.sqrt(d2) - 1.15) ** 2 * 9.0) * 0.07     # the clay pushed up around the thumb
        if rng.random() < 0.75:      # the print the thumb left: ridges 5 texels apart, loops around an off-centre core
            ox, oy = rng.normal(0.0, 0.25, 2)
            rr = np.sqrt((u - ox) ** 2 * 0.55 + (v - oy) ** 2) * r
            ridge = np.sin(rr / 5.2 * 2.0 * np.pi + np.arctan2(v - oy, u - ox) * rng.integers(0, 2))
            m = np.exp(-d2 * 2.6)
            h += ridge * m * 0.030
            tone += ridge * m * 0.10
    G = np.zeros((S, S), np.uint8)
    for _ in range(34):          # knife and tool drags: long, shallow, nearly straight
        x, y = rng.random(2) * S; a = rng.random() * np.pi * 2.0; L = rng.uniform(160.0, 620.0)
        p0 = np.array([x, y]); p1 = p0 + np.array([np.cos(a), np.sin(a)]) * L
        v = int(rng.integers(90, 255)); w = int(rng.integers(2, 5))
        def draw(dx, dy):
            cv2.line(G, tuple(np.round((p0 + [dx, dy]) * 16).astype(int)), tuple(np.round((p1 + [dx, dy]) * 16).astype(int)), v, w, cv2.LINE_AA, 4)
        wrap_draw(draw, x + np.cos(a) * L / 2, y + np.sin(a) * L / 2, L, S)
    g = blur(G.astype(np.float64) / 255.0, 1.0)
    h -= g * 0.11; tone -= g * 0.16
    C = np.zeros((S, S), np.float64)
    for _ in range(2600):        # crumbs (up) and pits (down)
        x, y = rng.random(2) * S; r = rng.uniform(1.2, 4.6); s = 1.0 if rng.random() < 0.6 else -1.0
        x0 = int(x) - 12; y0 = int(y) - 12
        ys = np.arange(y0, y0 + 25); xs = np.arange(x0, x0 + 25)
        b = np.exp(-(((xs[None, :] - x) ** 2 + (ys[:, None] - y) ** 2) / (r * r)) ** 1.6) * s * rng.uniform(0.4, 1.0)
        C[np.ix_(ys % S, xs % S)] += b
    h += C * 0.055; tone += C * 0.14
    h += fnoise(S, 2.2, 7.0, rng) * 0.010
    tone += fnoise(S, 2.5, 9.0, rng) * 0.035
    return h, tone

def wood(n, rng):
    """sanded wood, u = along the grain: growth lines that wander slowly, pores as short dashes, a knot or two"""
    S = n
    yy, xx = np.mgrid[0:S, 0:S].astype(np.float64)
    warp = fnoise(S, 60.0, 700.0, rng, (6.0, 1.0)) * 26.0 + fnoise(S, 20.0, 120.0, rng, (4.0, 1.0)) * 3.0
    for _ in range(3):           # knots push the grain around them
        cx, cy = rng.random(2) * S; r = rng.uniform(16.0, 30.0)
        dx = (xx - cx + S / 2) % S - S / 2; dy = (yy - cy + S / 2) % S - S / 2
        d2 = (dx / (r * 3.2)) ** 2 + (dy / r) ** 2
        warp += np.sign(dy) * np.exp(-d2) * r * 1.2
    v = yy + warp
    P = 1024                     # one period of the growth-line profile, in texels across the grain
    prof = np.zeros(P)
    ph = np.arange(P)
    for k, amp in ((9, 1.0), (17, 0.8), (31, 0.6), (57, 0.5), (103, 0.35), (187, 0.22)):
        prof += amp * np.sin(2 * np.pi * (k * ph / P + rng.random())) * (0.7 + 0.3 * np.sin(2 * np.pi * (3 * ph / P + rng.random())))
    prof /= np.abs(prof).max()
    vi = np.mod(v * (P / S), P)
    i0 = np.floor(vi).astype(int) % P; f = vi - np.floor(vi)
    grain = prof[i0] * (1 - f) + prof[(i0 + 1) % P] * f
    late = np.clip(grain, 0.0, 1.0) ** 1.5 - 0.3    # the dark late wood of each year stands up after sanding
    D = np.zeros((S, S), np.uint8)
    for _ in range(5200):        # pores: dark dashes along the grain
        x, y = rng.random(2) * S; L = rng.uniform(8.0, 46.0); vv = int(rng.integers(70, 255))
        def draw(dx, dy):
            cv2.line(D, (int((x + dx - L / 2) * 16), int((y + dy) * 16)), (int((x + dx + L / 2) * 16), int((y + dy + rng.normal(0, 0.6)) * 16)), vv, 1, cv2.LINE_AA, 4)
        wrap_draw(draw, x, y, L, S)
    d = blur(D.astype(np.float64) / 255.0, 0.6)
    fine = fnoise(S, 1.6, 6.0, rng, (14.0, 1.0))
    h = late * 0.5 - d * 0.55 + fine * 0.10 + fnoise(S, 80.0, 400.0, rng) * 0.25
    tone = -late * 0.34 - d * 0.42 + fine * 0.07 + fnoise(S, 100.0, 500.0, rng, (3.0, 1.0)) * 0.06
    return h, tone

def cast(n, rng):
    """a cast block (plaster, concrete): sandy, with the air holes of the pour and a few scuffs"""
    S = n
    h = fnoise(S, 2.0, 9.0, rng) * 0.045 + fnoise(S, 30.0, 300.0, rng) * 0.22
    tone = fnoise(S, 2.0, 8.0, rng) * 0.07 + fnoise(S, 60.0, 500.0, rng) * 0.09
    C = np.zeros((S, S), np.float64)
    for _ in range(1500):
        x, y = rng.random(2) * S; r = rng.uniform(1.4, 3.6) if rng.random() < 0.86 else rng.uniform(4.0, 9.0)
        m = int(r * 3) + 2
        ys = np.arange(int(y) - m, int(y) + m + 1); xs = np.arange(int(x) - m, int(x) + m + 1)
        e = rng.uniform(0.7, 1.4)
        b = np.exp(-((((xs[None, :] - x) * e) ** 2 + ((ys[:, None] - y) / e) ** 2) / (r * r)) ** 2.2)
        C[np.ix_(ys % S, xs % S)] = np.maximum(C[np.ix_(ys % S, xs % S)], b * rng.uniform(0.5, 1.0))
    h -= C * 0.55; tone -= C * 0.42
    G = np.zeros((S, S), np.uint8)
    for _ in range(22):          # scuffs
        x, y = rng.random(2) * S; a = rng.random() * np.pi * 2.0; L = rng.uniform(60.0, 300.0)
        p0 = np.array([x, y]); p1 = p0 + np.array([np.cos(a), np.sin(a)]) * L
        def draw(dx, dy):
            cv2.line(G, tuple(np.round((p0 + [dx, dy]) * 16).astype(int)), tuple(np.round((p1 + [dx, dy]) * 16).astype(int)), int(rng.integers(80, 220)), 2, cv2.LINE_AA, 4)
        wrap_draw(draw, x + np.cos(a) * L / 2, y + np.sin(a) * L / 2, L, S)
    g = blur(G.astype(np.float64) / 255.0, 1.0)
    h -= g * 0.05; tone += g * 0.10
    return h, tone

def soil(n, rng):
    """the earth of a road: clay rolled out and strewn with crumbs, grit pressed in, a stone here and there"""
    S = n
    h = fnoise(S, 2.0, 7.0, rng) * 0.05 + fnoise(S, 8.0, 40.0, rng) * 0.05 + fnoise(S, 120.0, 500.0, rng) * 0.10
    tone = fnoise(S, 2.0, 6.0, rng) * 0.10 + fnoise(S, 40.0, 300.0, rng) * 0.08
    C = np.zeros((S, S), np.float64); TT = np.zeros((S, S), np.float64)
    def stamp(x, y, r, e, a, amp, tv, sharp):
        m = int(r * 2.2) + 2
        ys = np.arange(int(y) - m, int(y) + m + 1); xs = np.arange(int(x) - m, int(x) + m + 1)
        dx = xs[None, :] - x; dy = ys[:, None] - y
        u = (dx * np.cos(a) + dy * np.sin(a)) * e; v = (-dx * np.sin(a) + dy * np.cos(a)) / e
        b = np.exp(-((u * u + v * v) / (r * r)) ** sharp)
        ix = np.ix_(ys % S, xs % S)
        if amp > 0:
            keep = b * amp > C[ix]
            C[ix] = np.maximum(C[ix], b * amp)
            TT[ix] = np.where(keep, TT[ix] * (1 - b) + tv * b, TT[ix])
        else:
            C[ix] += b * amp; TT[ix] += b * tv
    for _ in range(9000):        # crumbs
        stamp(rng.random() * S, rng.random() * S, rng.uniform(1.2, 4.2), rng.uniform(0.75, 1.3), rng.random() * 3.14, rng.uniform(0.25, 0.7), rng.normal(0.0, 0.5), 1.4)
    for _ in range(900):         # pits where a crumb fell out
        stamp(rng.random() * S, rng.random() * S, rng.uniform(1.2, 3.4), 1.0, 0.0, -rng.uniform(0.2, 0.5), -0.5, 1.6)
    for _ in range(170):         # small stones pressed in: flat on top, lighter
        stamp(rng.random() * S, rng.random() * S, rng.uniform(5.0, 11.0), rng.uniform(0.7, 1.4), rng.random() * 3.14, rng.uniform(0.8, 1.0), rng.uniform(0.3, 1.0), 2.6)
    h += C * 0.30
    tone += TT * 0.34 - np.clip(blur(C, 3.0) - C, 0.0, 1.0) * 0.5      # each crumb sits in a little shade of its own
    return h, tone

def wool(n, rng):
    """felted wool (pine tiers, bushes): long curly fibres matted together, pills of fluff here and there"""
    S = n * 2
    H = np.zeros((S, S), np.uint8); T = np.full((S, S), 128, np.uint8)
    N = 15000
    z = np.sort(rng.random(N))
    for i in range(N):
        x, y = rng.random(2) * S
        a = rng.random() * np.pi * 2.0
        L = rng.uniform(70.0, 190.0)
        k = 5
        pts = [np.array([x, y]) - np.array([np.cos(a), np.sin(a)]) * L * 0.5]
        da = rng.normal(0.0, 0.5)
        for j in range(k):
            a += da + rng.normal(0.0, 0.35)
            pts.append(pts[-1] + np.array([np.cos(a), np.sin(a)]) * L / k)
        pts = np.array(pts)
        # smooth the polyline (Chaikin twice)
        for _ in range(2):
            q = []
            for j in range(len(pts) - 1):
                q.append(pts[j] * 0.75 + pts[j + 1] * 0.25); q.append(pts[j] * 0.25 + pts[j + 1] * 0.75)
            pts = np.array(q)
        hv = int(40 + 175 * z[i]); tv = int(np.clip(128 + rng.normal(0.0, 44.0), 10, 245))
        wd = int(rng.integers(6, 11))
        def draw(dx, dy):
            qq = np.round((pts + [dx, dy]) * 16).astype(np.int32).reshape(-1, 1, 2)
            cv2.polylines(H, [qq], False, max(hv - 40, 1), wd, cv2.LINE_AA, 4)
            cv2.polylines(H, [qq], False, hv, max(wd - 4, 2), cv2.LINE_AA, 4)
            cv2.polylines(T, [qq], False, tv, wd, cv2.LINE_AA, 4)
        wrap_draw(draw, x, y, L, S)
    h = down2(blur(H.astype(np.float64) / 255.0, 1.4))
    t = down2(blur(T.astype(np.float64) / 255.0, 1.0)) - 0.5
    C = np.zeros((n, n))
    for _ in range(260):         # pills
        x, y = rng.random(2) * n; r = rng.uniform(5.0, 13.0); m = int(r * 2.5) + 2
        ys = np.arange(int(y) - m, int(y) + m + 1); xs = np.arange(int(x) - m, int(x) + m + 1)
        b = np.exp(-(((xs[None, :] - x) ** 2 + (ys[:, None] - y) ** 2) / (r * r)) ** 1.3)
        C[np.ix_(ys % n, xs % n)] = np.maximum(C[np.ix_(ys % n, xs % n)], b * rng.uniform(0.5, 1.0))
    h = h + C * 0.35 + fnoise(n, 60.0, 300.0, rng) * 0.10
    hp = h - blur(h, 7.0)
    tone = t * 1.4 + hp * 1.7 + C * 0.25 + fnoise(n, 40.0, 200.0, rng) * 0.06
    return h, tone
if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "."
    os.makedirs(out, exist_ok=True)
    n = int(sys.argv[2]) if len(sys.argv) > 2 else 1024
    only = sys.argv[3].split(",") if len(sys.argv) > 3 else ["felt", "clay", "wood", "cast", "soil", "wool"]
    for i, (name, fn) in enumerate((("felt", felt), ("clay", clay), ("wood", wood), ("cast", cast), ("soil", soil), ("wool", wool))):
        if name not in only: continue
        h, tone = fn(n, np.random.default_rng(2011 + i))
        pack(h, tone, os.path.join(out, name + ".png"))
