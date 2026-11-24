"""Which film curve gives the game's hues? (lane K7, round 3)
Scene-linear colours of thirdjam's own figure (tools/look_light_probe.py, variant A at the rink's centre) are shown
two ways and held against the running game's still:
  (a) as the hall shaders show them today (engine/style/shaders/hall_rig.gdshaderinc `hall_tone`: the post volume's
      gains, Unreal's film curve per channel on sRGB primaries, pre- and post-desaturation), then the screen grade's
      saturation and contrast are NOT applied here;
  (b) as Unreal 5.9 shows them (PostProcessCombineLUTs.usf:372-403 and :160-190, TonemapCommon.ush FilmToneMap): to
      ACEScg (AP1), gamut expansion, the post volume's saturation, contrast and gains in AP1, blue correction 0.6, the
      glow and red modifier, the film curve per channel in AP1, blue correction back, to sRGB.
  python look_tone_check.py [exposure]      (default 0.272 = 1 / (1.2 * 2^4.2) x lane K6's tone gain 6.0)
Prints both as sRGB hex with the red : green : blue of each."""
import math
import sys

EXPO = float(sys.argv[1]) if len(sys.argv) > 1 else 0.272


def mul(m, v):
    return [sum(m[i][j] * v[j] for j in range(3)) for i in range(3)]


def mm(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]


AP0_2_XYZ = [[0.9525523959, 0.0, 0.0000936786], [0.3439664498, 0.7281660966, -0.0721325464], [0.0, 0.0, 1.0088251844]]
XYZ_2_AP0 = [[1.0498110175, 0.0, -0.0000974845], [-0.4959030231, 1.3733130458, 0.0982400361], [0.0, 0.0, 0.9912520182]]
AP1_2_XYZ = [[0.6624541811, 0.1340042065, 0.1561876870], [0.2722287168, 0.6740817658, 0.0536895174], [-0.0055746495, 0.0040607335, 1.0103391003]]
XYZ_2_AP1 = [[1.6410233797, -0.3248032942, -0.2364246952], [-0.6636628587, 1.6153315917, 0.0167563477], [0.0117218943, -0.0082844420, 0.9883948585]]
AP0_2_AP1 = [[1.4514393161, -0.2365107469, -0.2149285693], [-0.0765537734, 1.1762296998, -0.0996759264], [0.0083161484, -0.0060324498, 0.9977163014]]
AP1_2_AP0 = [[0.6954522414, 0.1406786965, 0.1638690622], [0.0447945634, 0.8596711185, 0.0955343182], [-0.0055258826, 0.0040252103, 1.0015006723]]
XYZ_2_sRGB = [[3.2409699419, -1.5373831776, -0.4986107603], [-0.9692436363, 1.8759675015, 0.0415550574], [0.0556300797, -0.2039769589, 1.0569715142]]
sRGB_2_XYZ = [[0.4123907993, 0.3575843394, 0.1804807884], [0.2126390059, 0.7151686788, 0.0721923154], [0.0193308187, 0.1191947798, 0.9505321522]]
D65_2_D60 = [[1.0130349146, 0.0061052578, -0.0149709436], [0.0076982301, 0.9981633521, -0.0050320385], [-0.0028413174, 0.0046851567, 0.9245061375]]
D60_2_D65 = [[0.9872240087, -0.0061132286, 0.0159532883], [-0.0075983718, 1.0018614847, 0.0053300358], [0.0030725771, -0.0050959615, 1.0816806031]]
WIDE_2_XYZ = [[0.5441691, 0.2395926, 0.1666943], [0.2394656, 0.7021530, 0.0583814], [-0.0023439, 0.0361834, 1.0552183]]
BLUE = [[0.9404372683, -0.0183068787, 0.0778696104], [0.0083786969, 0.8286599939, 0.1629613092], [0.0005471261, -0.0008833746, 1.0003362486]]
BLUE_INV = [[1.06318, 0.0233956, -0.0865726], [-0.0106337, 1.20632, -0.19569], [-0.000590887, 0.00105248, 0.999538]]
sRGB_2_AP1 = mm(XYZ_2_AP1, mm(D65_2_D60, sRGB_2_XYZ))
AP1_2_sRGB = mm(XYZ_2_sRGB, mm(D60_2_D65, AP1_2_XYZ))
Y_AP1 = [0.2722287168, 0.6740817658, 0.0536895174]
Y_709 = [0.2126, 0.7152, 0.0722]
# the rig's post volume (arena.json "post"): saturation 0.95, contrast 0.95, gain, gain of the shadows (below 0.09)
SAT, CON, GAIN, GAIN_SH = 0.95, 0.95, [1.04, 1.0, 0.92], [1.08, 0.98, 0.9]
SLOPE, TOE_S, SH_S, TOE_M, STR_M, SH_M = 0.88, 0.45, 0.78, -0.390283, 0.901647, -0.606192


def dot(a, b):
    return sum(a[i] * b[i] for i in range(3))


def lerp(a, b, t):
    return [a[i] + (b[i] - a[i]) * t for i in range(3)]


def smooth(e0, e1, x):
    t = min(1.0, max(0.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


def curve(x):
    lc = math.log10(max(x, 1e-10))
    straight = SLOPE * (lc + STR_M)
    toe = (2 * TOE_S) / (1 + math.exp((-2 * SLOPE / TOE_S) * (lc - TOE_M))) if lc < TOE_M else straight
    sh = 1.04 - (2 * SH_S) / (1 + math.exp((2 * SLOPE / SH_S) * (lc - SH_M))) if lc > SH_M else straight
    t = 1 - min(1.0, max(0.0, (lc - TOE_M) / (SH_M - TOE_M)))
    t = (3 - 2 * t) * t * t
    return toe + (sh - toe) * t


def ours(c):
    x = [max(c[i], 0.0) * GAIN[i] for i in range(3)]
    k = smooth(0.0, 0.09, dot(x, Y_709))
    x = [x[i] * (GAIN_SH[i] + (1 - GAIN_SH[i]) * k) for i in range(3)]
    l = dot(x, Y_709)
    x = [l + (v - l) * 0.96 for v in x]
    y = [curve(v) for v in x]
    l = dot(y, Y_709)
    return [min(1.0, max(0.0, l + (v - l) * 0.93)) for v in y]


def cc(c, gain):
    l = dot(c, Y_AP1)
    c = [max(0.0, l + (v - l) * SAT) for v in c]
    c = [((v / 0.18) ** CON) * 0.18 for v in c]
    return [c[i] * gain[i] for i in range(3)]


def film(ap1):
    ap0 = mul(AP1_2_AP0, ap1)
    mn, mx = min(ap0), max(ap0)
    sat = (max(mx, 1e-10) - max(mn, 1e-10)) / max(mx, 1e-2)
    r, g, b = ap0
    yc = (b + g + r + 1.75 * math.sqrt(max(b * (b - g) + g * (g - r) + r * (r - b), 0.0))) / 3.0
    x = (sat - 0.4) / 0.2
    t = max(1 - abs(0.5 * x), 0.0)
    s = 0.5 * (1 + (1 if x > 0 else (-1 if x < 0 else 0)) * (1 - t * t))
    gain_in = 0.05 * s
    glow = gain_in if yc <= 2.0 / 3.0 * 0.08 else (0.0 if yc >= 0.16 else gain_in * (0.08 / yc - 0.5))
    ap0 = [v * (1 + glow) for v in ap0]
    r, g, b = ap0
    hue = 0.0 if (r == g and g == b) else math.degrees(math.atan2(math.sqrt(3.0) * (g - b), 2 * r - g - b))
    if hue < 0:
        hue += 360.0
    ch = hue - 360.0 if hue > 180.0 else hue
    hw = smooth(0.0, 1.0, 1 - abs(2 * ch / 135.0)) ** 2
    ap0[0] += hw * sat * (0.03 - ap0[0]) * (1 - 0.82)
    w = [max(0.0, v) for v in mul(AP0_2_AP1, ap0)]
    l = dot(w, Y_AP1)
    w = [l + (v - l) * 0.96 for v in w]
    y = [curve(v) for v in w]
    l = dot(y, Y_AP1)
    return [max(0.0, l + (v - l) * 0.93) for v in y]


def unreal(c):
    ap1 = mul(sRGB_2_AP1, c)
    l = dot(ap1, Y_AP1)
    chroma = [v / max(l, 1e-10) for v in ap1]
    d2 = sum((v - 1) ** 2 for v in chroma)
    amount = (1 - 2 ** (-4 * d2)) * (1 - 2 ** (-4 * 1.0 * l * l))
    ap1 = lerp(ap1, mul(mm(mm(XYZ_2_AP1, WIDE_2_XYZ), AP1_2_sRGB), ap1), amount)
    l = dot(ap1, Y_AP1)
    w_sh = 1 - smooth(0.0, 0.09, l)
    a = cc(ap1, [GAIN[i] * GAIN_SH[i] for i in range(3)])
    b = cc(ap1, GAIN)
    ap1 = [a[i] * w_sh + b[i] * (1 - w_sh) for i in range(3)]
    bc = mm(AP0_2_AP1, mm(BLUE, AP1_2_AP0))
    bci = mm(AP0_2_AP1, mm(BLUE_INV, AP1_2_AP0))
    ap1 = lerp(ap1, mul(bc, ap1), 0.6)
    ap1 = film(ap1)
    ap1 = lerp(ap1, mul(bci, ap1), 0.6)
    return [min(1.0, max(0.0, v)) for v in mul(AP1_2_sRGB, ap1)]


def hexs(c):
    e = [12.92 * v if v <= 0.0031308 else 1.055 * v ** (1 / 2.4) - 0.055 for v in c]
    return "#%02x%02x%02x" % tuple(int(round(255 * min(1.0, max(0.0, v)))) for v in e)


def ratio(c):
    m = max(max(c), 1e-9)
    return "%.2f : %.2f : %.2f" % (c[0] / m, c[1] / m, c[2] / m)


# thirdjam's own figure, scene-linear (look_light_probe.py, variant A, back and three-quarter cameras), and what the
# running game shows of the same surfaces in its frame 5360 (another place on the ice: hue, not level, is compared)
ROWS = [("jersey, blue", [0.053, 0.094, 0.434], "#121242"), ("helmet, blue", [0.059, 0.096, 0.398], "#181746"),
        ("back patch", [1.852, 1.094, 0.508], "#c5a373"), ("pants", [0.050, 0.038, 0.043], "#0b0505"),
        ("jersey, orange", [1.062, 0.164, 0.039], "(88 and 21: #a94921 .. #c35527)"), ("cheek", [1.074, 0.516, 0.266], "-")]
print("exposure %.4f" % EXPO)
for name, lin, game in ROWS:
    for k in (1.0, 1.6):          # as captured, and with the game window's indirect light on a side face (x 1.6, ROUND-2.md)
        c = [v * EXPO * k for v in lin]
        a, b = ours(c), unreal(c)
        print("%-15s x%.1f  hall_tone %s (%s)   Unreal's %s (%s)   the game %s" % (name, k, hexs(a), ratio(a), hexs(b), ratio(b), game))
