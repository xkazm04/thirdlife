"""Render a named shader experiment without modifying the production shader."""
import os
import subprocess
import sys

from probe import HERE, RAW

START = "16534db426880a5ef0f3e24b1248730538dbd7ab"
SHADER = "engine/style/shaders/ink_post.gdshader"
ORIGINAL = "0.65 * smoothstep(0.005, 0.020, crest_jump - 2.0 * crest_slope)"
RAMPS = {
    "wide": "0.65 * smoothstep(0.005, 0.050, crest_jump - 2.0 * crest_slope)",
    "lighter": "0.55 * smoothstep(0.005, 0.020, crest_jump - 2.0 * crest_slope)",
}


def source_for(name):
    source = subprocess.check_output(["git", "show", f"{START}:{SHADER}"], text=True)
    if name == "baseline":
        return source
    if name in RAMPS:
        assert source.count(ORIGINAL) == 1
        return source.replace(ORIGINAL, RAMPS[name])
    if name == "one_tap":
        source = source.replace("vec4 vertical_taps =", "float wide_above = 0.0;\n\tvec4 vertical_taps =")
        read = "lin_depth(juv - dir * px * wo, INV_PROJECTION_MATRIX)"
        source = source.replace(read, "dwm").replace("float em =", f"float dwm = {read};\n\t\tfloat em =")
        source = source.replace("cnt += ep + em;", "if (i == 2) { wide_above = dwm; }\n\t\tcnt += ep + em;")
        return source.replace("outer = max(outer * smoothstep(0.375, 0.6, outer), crest);",
                              "float wide_jump = 1.0 - d0 / wide_above;\n"
                              "\t\t\tfloat wide_crest = smoothstep(0.005, 0.020, wide_jump - 2.0 * crest_slope * wo / round(wi));\n"
                              "\t\t\touter = max(outer * max(smoothstep(0.375, 0.6, outer), wide_crest), crest);")
    if name in ("wide_flank", "wide_wash", "light_flank", "crest_cap"):
        # Keep the two original vertical wide-ring depths. Both already contribute to cnt.
        source = source.replace("vec4 vertical_taps =", "vec2 wide_depth = vec2(0.0);\n\tvec4 vertical_taps =")
        for direction, sign in (("p", "+"), ("m", "-")):
            read = f"lin_depth(juv {sign} dir * px * wo, INV_PROJECTION_MATRIX)"
            line = f"float e{direction} = "
            source = source.replace(read, f"dw{direction}").replace(line, f"float dw{direction} = {read};\n\t\t{line}")
        source = source.replace("cnt += ep + em;", "if (i == 2) { wide_depth = vec2(dwp, dwm); }\n\t\tcnt += ep + em;")
        line = "outer = max(outer * smoothstep(0.375, 0.6, outer), crest);"
        flank = "outer * max(smoothstep(0.375, 0.6, outer), wide_crest)"
        if name == "wide_wash":
            flank = "max(" + flank + ", 0.35 * wide_crest)"
        if name == "light_flank":
            source = source.replace(ORIGINAL, RAMPS["lighter"])
        if name == "crest_cap":
            source = source.replace(ORIGINAL, "min(0.55, " + ORIGINAL + ")")
        return source.replace(line, "float wide_jump = 1.0 - d0 / wide_depth.y;\n"
                              "\t\t\tfloat wide_slope = abs(1.0 - d0 / wide_depth.x);\n"
                              "\t\t\tfloat wide_crest = smoothstep(0.005, 0.020, wide_jump - 2.0 * wide_slope);\n"
                              f"\t\t\touter = max({flank}, crest);")
    raise ValueError(name)


def trial(name):
    RAW.mkdir(exist_ok=True)
    env = os.environ.copy()
    env.pop("TERRAIN_INK_POST", None)
    env.pop("TERRAIN_TOON", None)
    if name not in ("head", "after"):
        path = RAW / (name + ".gdshader.txt")
        path.write_text(source_for(name), newline="\n")
        env["TERRAIN_INK_POST"] = path.as_posix()
    probe = [sys.executable, str(HERE / "probe.py")]
    for place in ("bluff", "bank"):
        subprocess.run([*probe, "capture", name, place], env=env, check=True)
    readings = HERE / "readings"
    readings.mkdir(exist_ok=True)
    tools = ("band", "measure") if name == "head" else ("band", "measure", "strong", "verify")
    with (readings / f"{name}.txt").open("w", newline="\n") as out:
        for tool in tools:
            print(f"--- {tool}.py ---", file=out)
            result = subprocess.check_output([*probe, tool, name], text=True)
            out.write(result)
            if tool == "band":
                print(result, end="", flush=True)


if __name__ == "__main__":
    for name in sys.argv[1:]:
        trial(name)
