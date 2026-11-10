"""Characters on shared rigs. Rigid voxel parts per bone; part pivots = joint positions (rest pose, identity rotations).
Facing is -Z. Character right is +X."""
import math

import numpy as np

from vox import Grid, MATS

# ---------------------------------------------------------------------------------------------- biped
# (bone, parent, rest joint position in avatar space)
BIPED = [
    ("Hips", None, (0.0, 0.80, 0.0)),
    ("Spine", "Hips", (0.0, 0.90, 0.0)),
    ("Chest", "Spine", (0.0, 1.12, 0.0)),
    ("Neck", "Chest", (0.0, 1.34, 0.0)),
    ("Head", "Neck", (0.0, 1.38, 0.0)),
    ("LeftUpperArm", "Chest", (-0.31, 1.30, 0.0)),
    ("LeftLowerArm", "LeftUpperArm", (-0.31, 1.00, 0.0)),
    ("LeftHand", "LeftLowerArm", (-0.31, 0.72, 0.0)),
    ("RightUpperArm", "Chest", (0.31, 1.30, 0.0)),
    ("RightLowerArm", "RightUpperArm", (0.31, 1.00, 0.0)),
    ("RightHand", "RightLowerArm", (0.31, 0.72, 0.0)),
    ("LeftUpperLeg", "Hips", (-0.11, 0.80, 0.0)),
    ("LeftLowerLeg", "LeftUpperLeg", (-0.11, 0.46, 0.0)),
    ("LeftFoot", "LeftLowerLeg", (-0.11, 0.18, 0.0)),
    ("RightUpperLeg", "Hips", (0.11, 0.80, 0.0)),
    ("RightLowerLeg", "RightUpperLeg", (0.11, 0.46, 0.0)),
    ("RightFoot", "RightLowerLeg", (0.11, 0.18, 0.0)),
]


def avatar(vs=0.06, seed=7):
    rng = np.random.default_rng(seed)
    g = Grid(vs, (-0.6, 0.0, -0.5), (0.6, 1.95, 0.6))
    # ---- legs (pants) + boots
    for side, sx in (("Left", -1), ("Right", 1)):
        cx = sx * 0.11
        g.use_part(f"{side}UpperLeg")
        g.box("cloth_dark", cx - 0.085, 0.46, -0.10, cx + 0.085, 0.80, 0.10)
        g.use_part(f"{side}LowerLeg")
        g.box("cloth_dark", cx - 0.08, 0.20, -0.095, cx + 0.08, 0.46, 0.095)
        g.use_part(f"{side}Foot")
        g.box("boots", cx - 0.09, 0.0, -0.10, cx + 0.09, 0.22, 0.11)
        g.box("boots", cx - 0.085, 0.0, -0.20, cx + 0.085, 0.10, -0.08)       # toe
        g.box("stone_dark", cx - 0.09, 0.0, -0.205, cx + 0.09, 0.03, 0.11)     # sole
    # ---- hips: belt + pelvis
    g.use_part("Hips")
    g.box("cloth_dark", -0.21, 0.74, -0.12, 0.21, 0.90, 0.12)
    g.box("boots", -0.215, 0.84, -0.125, 0.215, 0.89, 0.125)
    g.box("gold", -0.04, 0.84, -0.13, 0.04, 0.89, -0.115)   # buckle
    # ---- spine / chest: shirt
    g.use_part("Spine")
    g.box("cloth_red", -0.22, 0.90, -0.125, 0.22, 1.12, 0.125)
    g.use_part("Chest")
    g.box("cloth_red", -0.245, 1.12, -0.135, 0.245, 1.34, 0.135)
    g.box("shirt_dark", -0.245, 1.12, -0.136, 0.245, 1.17, -0.134 + 0.0)
    # shirt tone variation (checks)
    a = g.a
    p = g.p
    mred = MATS("cloth_red")
    ci = (np.indices(a.shape).sum(0) % 5 == 0) & (a == mred)
    a[ci] = MATS("shirt_dark")
    # ---- backpack (on Chest, +z side)
    g.box("pack_tan", -0.19, 0.92, 0.135, 0.19, 1.36, 0.36)
    g.box("pack_tan", -0.17, 1.36, 0.16, 0.17, 1.40, 0.34)
    g.box("brick", -0.12, 1.04, 0.36, 0.12, 1.20, 0.40)           # flap pocket
    g.box("cloth_dark", -0.19, 0.92, 0.13, -0.13, 1.34, 0.14)     # straps (visible bits at the sides)
    g.box("cloth_dark", 0.13, 0.92, 0.13, 0.19, 1.34, 0.14)
    g.box("cloth_dark", -0.19, 1.28, -0.14, -0.13, 1.35, 0.14)
    g.box("cloth_dark", 0.13, 1.28, -0.14, 0.19, 1.35, 0.14)
    g.box("holo_cyan", 0.10, 1.40, 0.22, 0.16, 1.46, 0.28)        # the small glowing light
    g.box("metal_grey", 0.12, 1.36, 0.24, 0.14, 1.40, 0.26)
    # ---- neck + head
    g.use_part("Neck")
    g.box("skin", -0.06, 1.34, -0.06, 0.06, 1.40, 0.06)
    g.use_part("Head")
    hw = 0.21
    g.box("skin", -hw, 1.38, -0.20, hw, 1.78, 0.20)
    # ears
    g.box("skin", -hw - 0.05, 1.52, -0.04, -hw, 1.62, 0.06)
    g.box("skin", hw, 1.52, -0.04, hw + 0.05, 1.62, 0.06)
    # eyes (white + dark pupil), brows, mouth
    for sx in (-1, 1):
        g.box("boards_white", sx * 0.105 - 0.055, 1.56, -0.205, sx * 0.105 + 0.055, 1.66, -0.19)
        g.box("metal_dark", sx * 0.105 + (0.0 if sx < 0 else -0.0) - 0.03, 1.56, -0.21, sx * 0.105 + 0.03, 1.64, -0.19)
        g.box("hair", sx * 0.105 - 0.065, 1.69, -0.205, sx * 0.105 + 0.065, 1.72, -0.19)
    g.box("brick", -0.05, 1.44, -0.205, 0.05, 1.47, -0.19)        # mouth
    g.box("rust", -0.02, 1.50, -0.215, 0.02, 1.54, -0.2)          # nose
    # hair: cap + fringe + messy tufts
    g.box("hair", -hw - 0.01, 1.74, -0.21, hw + 0.01, 1.82, 0.21)
    g.box("hair", -hw - 0.01, 1.60, 0.12, hw + 0.01, 1.78, 0.21)   # back
    g.box("hair", -hw - 0.01, 1.62, -0.20, -hw + 0.03, 1.78, 0.2)
    g.box("hair", hw - 0.03, 1.62, -0.20, hw + 0.01, 1.78, 0.2)
    g.box("hair", -hw - 0.01, 1.70, -0.215, hw + 0.01, 1.76, -0.19)  # fringe
    for _ in range(16):
        x, z = rng.uniform(-0.2, 0.2), rng.uniform(-0.19, 0.19)
        g.box("hair", x - vs / 2, 1.80, z - vs / 2, x + vs / 2, 1.80 + vs * rng.integers(1, 3), z + vs / 2)
    for _ in range(10):
        x = rng.choice([-hw - 0.03, hw + 0.03])
        z = rng.uniform(-0.1, 0.18)
        y = rng.uniform(1.6, 1.78)
        g.box("hair", x - vs / 2, y, z - vs / 2, x + vs / 2, y + vs, z + vs / 2)
    # ---- arms (shirt sleeves + skin hands)
    for side, sx in (("Left", -1), ("Right", 1)):
        cx = sx * 0.31
        g.use_part(f"{side}UpperArm")
        g.box("cloth_red", cx - 0.07, 1.00, -0.075, cx + 0.07, 1.33, 0.075)
        g.use_part(f"{side}LowerArm")
        g.box("skin", cx - 0.065, 0.72, -0.065, cx + 0.065, 1.00, 0.065)
        g.box("cloth_dark", cx - 0.068, 0.72, -0.068, cx + 0.068, 0.80, 0.068)   # wrist band
        g.use_part(f"{side}Hand")
        g.box("skin", cx - 0.06, 0.60, -0.07, cx + 0.06, 0.72, 0.07)
    g.use_part(None)
    # jacket variation on the pants: darker knees
    return g


def tablet(vs=0.025):
    """Holo tablet: dark frame, glowing screen, blueprint glyph; pivot = hand grip (0,0,0), screen faces +y in local space."""
    g = Grid(vs, (-0.2, -0.04, -0.17), (0.2, 0.06, 0.17))
    g.box("metal_dark", -0.19, -0.02, -0.15, 0.19, 0.01, 0.15)
    g.box("hologlass", -0.17, 0.01, -0.13, 0.17, 0.02, 0.13)
    g.box("holo_cyan", -0.17, 0.01, -0.13, 0.17, 0.035, -0.115)
    g.box("holo_cyan", -0.17, 0.01, 0.115, 0.17, 0.035, 0.13)
    g.box("holo_cyan", -0.17, 0.01, -0.13, -0.155, 0.035, 0.13)
    g.box("holo_cyan", 0.155, 0.01, -0.13, 0.17, 0.035, 0.13)
    # tiny arena glyph: arch + base
    for t in np.linspace(-1, 1, 24):
        x = t * 0.11
        y = (1 - t * t) * 0.06
        g.box("holo_cyan", x - vs / 2, 0.01, -0.01 - y - vs / 2, x + vs / 2, 0.035, -0.01 - y + vs / 2)
    g.box("holo_cyan", -0.11, 0.01, 0.0, 0.11, 0.035, 0.0 + vs)
    for x in np.linspace(-0.1, 0.1, 5):
        g.box("hologrid", x - vs / 2, 0.01, -0.07, x + vs / 2, 0.03, 0.0)
    return g


# ---------------------------------------------------------------------------------------------- bot
BOT = [
    ("Root", None, (0.0, 0.0, 0.0)),
    ("LegL", "Root", (-0.09, 0.22, 0.0)),
    ("LegR", "Root", (0.09, 0.22, 0.0)),
    ("Body", "Root", (0.0, 0.22, 0.0)),
    ("Head", "Body", (0.0, 0.52, 0.0)),
    ("ArmL", "Body", (-0.215, 0.46, 0.0)),
    ("ArmR", "Body", (0.215, 0.46, 0.0)),
    ("Tool", "ArmR", (0.215, 0.24, 0.0)),
]


def bot(vs=0.04):
    g = Grid(vs, (-0.4, 0.0, -0.3), (0.4, 0.92, 0.3))
    for name, sx in (("LegL", -1), ("LegR", 1)):
        g.use_part(name)
        cx = sx * 0.09
        g.box("bot_dark", cx - 0.045, 0.06, -0.045, cx + 0.045, 0.22, 0.045)
        g.box("bot_yellow", cx - 0.07, 0.0, -0.10, cx + 0.07, 0.07, 0.07)
    g.use_part("Body")
    g.box("bot_white", -0.17, 0.22, -0.13, 0.17, 0.52, 0.13)
    g.box("bot_yellow", -0.11, 0.30, -0.14, 0.11, 0.44, -0.13)       # chest plate
    g.box("bot_dark", -0.12, 0.24, 0.13, 0.12, 0.46, 0.18)            # back vent
    g.box("bot_screen", -0.04, 0.36, -0.145, 0.04, 0.40, -0.13)       # status light
    g.use_part("Head")
    g.box("bot_white", -0.15, 0.52, -0.13, 0.15, 0.78, 0.13)
    g.box("bot_dark", -0.115, 0.58, -0.145, 0.115, 0.72, -0.12)        # visor
    g.box("bot_screen", -0.09, 0.63, -0.15, -0.03, 0.69, -0.13)         # eyes
    g.box("bot_screen", 0.03, 0.63, -0.15, 0.09, 0.69, -0.13)
    g.box("bot_yellow", -0.16, 0.60, -0.04, -0.15, 0.70, 0.04)         # ear plates
    g.box("bot_yellow", 0.15, 0.60, -0.04, 0.16, 0.70, 0.04)
    g.box("bot_dark", -0.02, 0.78, -0.02, 0.02, 0.86, 0.02)            # antenna
    g.box("bot_screen", -0.03, 0.86, -0.03, 0.03, 0.90, 0.03)
    for name, sx in (("ArmL", -1), ("ArmR", 1)):
        g.use_part(name)
        cx = sx * 0.215
        g.box("bot_yellow", cx - 0.04, 0.26, -0.04, cx + 0.04, 0.50, 0.04)
        g.box("bot_dark", cx - 0.05, 0.22, -0.05, cx + 0.05, 0.28, 0.05)
    g.use_part("Tool")
    g.box("metal_dark", 0.215 - 0.025, 0.12, -0.14, 0.215 + 0.025, 0.2, -0.04)   # torch handle pointing forward (-z)
    g.box("metal_grey", 0.215 - 0.02, 0.14, -0.20, 0.215 + 0.02, 0.18, -0.14)
    g.box("flame", 0.215 - 0.02, 0.14, -0.22, 0.215 + 0.02, 0.18, -0.20)
    g.use_part(None)
    return g


# ---------------------------------------------------------------------------------------------- car
CAR_TOP = np.array([(-2.30, 0.30), (-2.20, 0.50), (-1.6, 0.66), (-0.9, 0.78), (-0.35, 0.86), (0.10, 1.26),
                    (0.95, 1.30), (1.50, 0.96), (1.85, 0.88), (2.15, 0.82), (2.30, 0.50)])
WHEELS = {"WheelFL": (-0.86, 0.38, -1.38), "WheelFR": (0.86, 0.38, -1.38),
          "WheelRL": (-0.88, 0.38, 1.38), "WheelRR": (0.88, 0.38, 1.38)}
CAR_RIG = [("Root", None, (0, 0, 0))] + [(n, "Root", p) for n, p in WHEELS.items()]


def car_body(vs=0.1, body="car_red", accent="car_white", lightbar=False):
    g = Grid(vs, (-1.25, 0.0, -2.5), (1.25, 1.6, 2.6))

    def f(X, Y, Z):
        top = np.interp(Z, CAR_TOP[:, 0], CAR_TOP[:, 1])
        hw = 0.93 - np.clip(Y - 0.80, 0, None) * 0.55
        plan = (np.abs(X) / 0.93) ** 6 + (np.abs(Z) / 2.30) ** 8 <= 1.0
        well = False
        for (wx, wy, wz) in WHEELS.values():
            well = well | ((np.abs(X) > 0.62) & ((Y - wy) ** 2 + (Z - wz) ** 2 < 0.47 ** 2))
        return plan & (np.abs(X) <= hw) & (Y >= 0.26) & (Y <= top) & ~well
    g.fn(body, f, (-1.0, 0.2, -2.4, 1.0, 1.4, 2.4))
    a = g.a
    X = g.centres(0)[:, None, None]
    Y = g.centres(1)[None, :, None]
    Z = g.centres(2)[None, None, :]
    solid = a > 0
    top = np.interp(Z, CAR_TOP[:, 0], CAR_TOP[:, 1]) + 0 * Y + 0 * X
    # under-body dark
    a[solid & (Y < 0.34)] = MATS("metal_dark")
    # side skirts accent
    a[solid & (Y >= 0.34) & (Y < 0.44) & (np.abs(X) > 0.78)] = MATS(accent)
    # glass: side windows + windshield + rear window
    cabin = solid & (Y > 0.90) & (Z > -0.25) & (Z < 1.45) & (np.abs(X) > 0.30) & (Y < top - 0.08)
    pillars = (np.abs(Z - 0.62) < 0.07) | (np.abs(Z - 1.40) < 0.05) | (np.abs(Z + 0.18) < 0.05)
    a[cabin & ~pillars] = MATS("car_glass")
    wind = solid & (Z > -0.38) & (Z < 0.08) & (Y > top - 0.13) & (np.abs(X) < 0.66)
    a[wind] = MATS("car_glass")
    rear = solid & (Z > 1.06) & (Z < 1.52) & (Y > top - 0.13) & (np.abs(X) < 0.62)
    a[rear] = MATS("car_glass")
    # racing stripes (hood, roof, trunk)
    stripe = solid & (a == MATS(body)) & ((np.abs(X) < 0.13) | ((np.abs(X) > 0.26) & (np.abs(X) < 0.36))) & (Y > top - 0.11)
    a[stripe] = MATS(accent)
    # lights
    for sx in (-1, 1):
        hl = solid & (Z < -2.0) & (Y > 0.42) & (Y < 0.58) & (X * sx > 0.45) & (X * sx < 0.82)
        a[hl] = MATS("headlight")
        tl = solid & (Z > 2.12) & (Y > 0.52) & (Y < 0.70) & (X * sx > 0.45) & (X * sx < 0.85)
        a[tl] = MATS("curb_red")
    # grille + bumper
    a[solid & (Z < -2.15) & (np.abs(X) < 0.3) & (Y > 0.34) & (Y < 0.5)] = MATS("metal_dark")
    # spoiler
    g.box(accent, -0.88, 1.02, 1.95, 0.88, 1.10, 2.28)
    for sx in (-1, 1):
        g.box("metal_dark", sx * 0.62 - 0.05, 0.82, 2.0, sx * 0.62 + 0.05, 1.02, 2.2)
    # mirrors
    for sx in (-1, 1):
        g.box(body, sx * 0.88, 0.92, -0.15, sx * 1.02, 1.02, 0.08)
    # exhaust
    for sx in (-1, 1):
        g.box("metal_dark", sx * 0.35 - 0.07, 0.38, 2.28, sx * 0.35 + 0.07, 0.52, 2.38)
    if lightbar:
        g.box("curb_red", -0.4, 1.30, 0.3, -0.05, 1.40, 0.6)
        g.box("car_blue", 0.05, 1.30, 0.3, 0.4, 1.40, 0.6)
    return g


def car_wheel(vs=0.05):
    g = Grid(vs, (-0.17, -0.45, -0.45), (0.17, 0.45, 0.45))
    g.cyl("tire", 0, (0.0, 0.0), 0.40, -0.14, 0.14)
    g.cyl("metal_grey", 0, (0.0, 0.0), 0.27, -0.145, 0.145)
    g.cyl("metal_dark", 0, (0.0, 0.0), 0.13, -0.15, 0.15)
    # spokes (asymmetry so the spin reads)
    for k in range(5):
        a = k * 2 * math.pi / 5
        g.beam("metal_dark", (0.15, 0, 0), (0.15, 0.27 * math.sin(a), 0.27 * math.cos(a)), 0.03, cheb=False)
        g.beam("metal_dark", (-0.15, 0, 0), (-0.15, 0.27 * math.sin(a), 0.27 * math.cos(a)), 0.03, cheb=False)
    return g
