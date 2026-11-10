"""Writes data/style.json (golden hour) and data/style_overcast.json. The JSON files are the artifact; this
script is only an authoring convenience (ramps from a base colour). Nothing in Godot reads this script."""
import colorsys
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def hx(c):
    c = c.lstrip("#")
    return [int(c[i:i + 2], 16) / 255 for i in (0, 2, 4)]


def tohex(rgb):
    return "#%02x%02x%02x" % tuple(max(0, min(255, int(round(v * 255)))) for v in rgb)


def ramp(base, n=5, dv=0.07, ds=0.03, dh=0.012):
    """n shades around base: darker/more saturated ... lighter/less saturated, slight hue drift."""
    h, s, v = colorsys.rgb_to_hsv(*hx(base))
    out = []
    for i in range(n):
        t = (i - (n - 1) / 2) / ((n - 1) / 2 or 1)
        out.append(tohex(colorsys.hsv_to_rgb((h + t * dh) % 1, max(0, min(1, s - t * ds)), max(0, min(1, v + t * dv)))))
    return out


def mat(base, rough=0.85, emit=0.0, alpha=1.0, metal=0.0, n=5, dv=0.07, ds=0.03, dh=0.012, tex=1.0):
    return {"ramp": ramp(base, n, dv, ds, dh), "rough": rough, "metal": metal, "emit": emit, "alpha": alpha, "tex": tex}


def golden():
    m = {
        "grass": mat("#6aa22e", 0.92, dv=0.08, ds=0.05, dh=0.02),
        "grass_dark": mat("#4a7a24", 0.92, dv=0.08, ds=0.05, dh=0.02),
        "dirt": mat("#7a5638", 0.95, dv=0.08, ds=0.04),
        "stone": mat("#8d8a86", 0.9, dv=0.09, ds=0.02),
        "stone_dark": mat("#6c6764", 0.92, dv=0.09, ds=0.02),
        "sand": mat("#c9b17a", 0.95),
        "snow": mat("#f1f3f8", 0.8, dv=0.03, ds=0.02),
        "leaves": mat("#5f9a2f", 0.9, dv=0.10, ds=0.06, dh=0.02),
        "leaves_pine": mat("#2f6a34", 0.9, dv=0.09, ds=0.05, dh=0.02),
        "bark": mat("#6a4527", 0.95, dv=0.07),
        "wood_plank": mat("#a6743e", 0.85, dv=0.07),
        "wood_log": mat("#8a5a30", 0.9, dv=0.08),
        "wood_frame": mat("#d3a463", 0.85, dv=0.06),
        "wood_dark": mat("#5b3a20", 0.9, dv=0.06),
        "concrete": mat("#a9a6a1", 0.9, dv=0.06, ds=0.01),
        "concrete_dark": mat("#85827e", 0.92, dv=0.06, ds=0.01),
        "asphalt": mat("#4a4a50", 0.7, dv=0.04, ds=0.01),
        "curb_red": mat("#c8352b", 0.7, dv=0.05),
        "curb_white": mat("#ece8e0", 0.7, dv=0.03, ds=0.01),
        "ice": mat("#dcecf6", 0.08, metal=0.0, dv=0.025, ds=0.02, dh=0.005),
        "line_red": mat("#d0362e", 0.15, dv=0.02),
        "line_blue": mat("#2f62c8", 0.15, dv=0.02),
        "boards_white": mat("#f0eeea", 0.45, dv=0.03, ds=0.01),
        "glass": mat("#bfe4f2", 0.05, alpha=0.30, dv=0.02),
        "metal_yellow": mat("#e6a82a", 0.5, metal=0.2, dv=0.06),
        "metal_grey": mat("#9aa0a6", 0.45, metal=0.45, dv=0.05, ds=0.01),
        "metal_dark": mat("#4a4f56", 0.5, metal=0.4, dv=0.04, ds=0.01),
        "shingle": mat("#72707a", 0.85, dv=0.09, ds=0.02),
        "brick": mat("#a2503a", 0.9, dv=0.08, ds=0.04),
        "window_glow": mat("#ffcf70", 0.3, emit=2.6, dv=0.05),
        "cloth_red": mat("#b3302e", 0.9, dv=0.07, ds=0.04),
        "cloth_dark": mat("#3d4658", 0.9, dv=0.06),
        "skin": mat("#e8b48f", 0.8, dv=0.04, ds=0.03),
        "hair": mat("#6a3a22", 0.9, dv=0.10, ds=0.04),
        "pack_tan": mat("#cdb084", 0.9, dv=0.06),
        "holo_cyan": mat("#38e8ff", 0.2, emit=3.2, dv=0.05, ds=0.04),
        "water": mat("#3f8fc8", 0.04, alpha=0.78, dv=0.05, ds=0.04, dh=0.01),
        "car_red": mat("#d02a22", 0.28, metal=0.3, dv=0.04),
        "car_blue": mat("#2352b8", 0.28, metal=0.3, dv=0.04),
        "car_white": mat("#ececf0", 0.3, metal=0.25, dv=0.02),
        "lamp_glow": mat("#ffd890", 0.3, emit=3.0, dv=0.03),
        "bot_white": mat("#ece9e2", 0.5, dv=0.03, ds=0.01),
        "bot_screen": mat("#3beaff", 0.2, emit=3.4, dv=0.03),
        "flame": mat("#ff9a2a", 0.3, emit=4.5, dv=0.15, ds=0.05, dh=0.03),
        "seat_red": mat("#a82a2c", 0.8, dv=0.06),
        "seat_grey": mat("#6d727c", 0.8, dv=0.05),
        "rust": mat("#9a5a38", 0.8, dv=0.07),
        "cloud": mat("#ffe0d0", 0.9, emit=0.9, dv=0.04, ds=0.02),
        "grass_tuft": mat("#84b83a", 0.9, dv=0.10, ds=0.05, dh=0.02),
        "moss": mat("#5f8a3a", 0.95),
        "road_line": mat("#e8e4dc", 0.6, dv=0.02),
        "net": mat("#e8ecf0", 0.8, dv=0.02),
        "tire": mat("#222428", 0.8, dv=0.03),
        "headlight": mat("#fff2c0", 0.2, emit=3.0, dv=0.02),
        "gold": mat("#e3b53a", 0.35, metal=0.5, dv=0.05),
        "mountain": mat("#7f7580", 0.95, dv=0.08, ds=0.02),
        "hologlass": mat("#38e8ff", 0.1, emit=1.4, alpha=0.18, dv=0.02),
        "shirt_dark": mat("#7a2424", 0.9, dv=0.06),
        "boots": mat("#4a3426", 0.9, dv=0.05),
        "pole": mat("#3a3e46", 0.5, metal=0.4, dv=0.03),
        "car_glass": mat("#26364a", 0.06, metal=0.1, dv=0.03),
        "bot_dark": mat("#33363e", 0.5, dv=0.03),
        "bot_yellow": mat("#f0b428", 0.5, dv=0.04),
        "smoke": mat("#d6d2cc", 0.95, dv=0.05, ds=0.01),
        "plank_light": mat("#c79a5c", 0.85, dv=0.07),
        "hologrid": mat("#38e8ff", 0.2, emit=2.6, dv=0.03),
    }
    return {
        "name": "golden_hour",
        "sun": {"color": "#ffb064", "energy": 3.1, "elev_deg": 11.0, "azim_deg": 0.0, "dir_from": [-0.55, 0.20, -0.81],
                "shadow_max": 260.0, "shadow_blur": 1.6},
        "sky": {"top": "#4a68b0", "horizon": "#ff9d6b", "ground": "#6a5658", "curve": 0.12, "sun_angle_max": 22.0,
                "energy": 1.0},
        "ambient": {"energy": 0.85, "sky_contribution": 1.0, "color": "#a8b8e8"},
        "fog": {"color": "#f0a47c", "density": 0.0016, "sun_scatter": 0.35, "aerial": 0.7,
                "vol_density": 0.010, "vol_albedo": "#ffc8a0", "vol_anisotropy": 0.78, "vol_length": 220.0,
                "vol_emission": 0.0},
        "post": {"exposure": 1.0, "white": 5.5, "tonemap": "aces", "glow": 0.55, "glow_threshold": 1.0,
                 "saturation": 1.12, "contrast": 1.05, "ssao_radius": 1.1, "ssao_intensity": 2.0,
                 "ssil": 0.0, "sdfgi_energy": 1.0},
        "voxel": {"edge": 0.11, "tex": 0.045, "ao_strength": 0.62, "bevel": 0.16},
        "holo": {"color": "#38e8ff", "edge": 2.4, "fill": 0.10, "scan": 0.35},
        "clouds": {"material": "cloud", "count": 14},
        "materials": m,
    }


def overcast(g):
    import copy
    s = copy.deepcopy(g)
    s["name"] = "overcast_morning"
    s["sun"].update({"color": "#dfe6f2", "energy": 0.9, "elev_deg": 32.0, "dir_from": [-0.35, 0.55, -0.76],
                     "shadow_blur": 4.0})
    s["sky"].update({"top": "#8c9bb0", "horizon": "#cfd6de", "ground": "#8a9096", "energy": 0.95})
    s["ambient"].update({"energy": 1.25, "color": "#c4d0e0"})
    s["fog"].update({"color": "#c2ccd6", "density": 0.0034, "vol_density": 0.004, "vol_albedo": "#dfe6ee",
                     "vol_anisotropy": 0.1})
    s["post"].update({"exposure": 1.05, "saturation": 0.82, "glow": 0.35})
    s["voxel"].update({"edge": 0.10})
    s["clouds"]["material"] = "concrete"
    s["clouds"]["count"] = 26

    def cool(c):
        r, g_, b = hx(c)
        l = (r + g_ + b) / 3
        k = 0.55
        return tohex(((r * k + l * (1 - k)) * 0.94, (g_ * k + l * (1 - k)) * 0.99, (b * k + l * (1 - k)) * 1.08))
    for name, mm in s["materials"].items():
        if mm["emit"] == 0:
            mm["ramp"] = [cool(c) for c in mm["ramp"]]
    s["materials"]["cloud"]["emit"] = 0.0
    s["materials"]["cloud"]["ramp"] = ramp("#b8c0c8", 5, 0.04, 0.01)
    return s


if __name__ == "__main__":
    g = golden()
    json.dump(g, open(os.path.join(ROOT, "data", "style.json"), "w"), indent=1)
    json.dump(overcast(g), open(os.path.join(ROOT, "data", "style_overcast.json"), "w"), indent=1)
    print("styles written")
