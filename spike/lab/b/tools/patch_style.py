"""Tiny helper: python tools/patch_style.py key=value ... sets palette/mat/section entries in BOTH style files.
Usage examples:
  python tools/patch_style.py palette.water=#4a8ac0 mat.water={"shader":"water"} fog.density=0.002
Only used while authoring; the style files are plain JSON and can be edited by hand."""
import json
import sys

FILES = ("data/style.json", "data/style_overcast.json")


def main() -> None:
    args = sys.argv[1:]
    for fn in FILES:
        d = json.load(open(fn))
        for a in args:
            k, v = a.split("=", 1)
            try:
                v = json.loads(v)
            except Exception:
                pass
            path = k.split(".")
            cur = d
            for p in path[:-1]:
                cur = cur.setdefault(p, {})
            cur[path[-1]] = v
        json.dump(d, open(fn, "w"), indent=1)


main()
