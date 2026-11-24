#!/usr/bin/env python3
"""Rink core: the generated parts of engine/cores/rink/CARTRIDGE.md, from thirdjam's own files (never typed by hand):
  <!-- generated:keys -->   every key of the cartridge (cartridge.schema.json envelope + game.schema.json), its range, thirdjam's
                            one-line meaning, and hockey.regular's value
  <!-- generated:modes -->  the twelve modes (+ two parked): exactly which keys each changes from hockey.regular
  <!-- generated:cuts -->   thirdjam's sentence-to-cartridge cache (content/Designer/cached-cuts.json): the words, and the keys they moved
Each part is replaced between its marker and the matching <!-- /generated:... --> marker.
usage: python -I catalog.py [--check]    (--check: exit 1 when CARTRIDGE.md is not what this would write)"""
import json, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
RINK = os.path.dirname(HERE)
CONTENT = os.path.join(RINK, "native", "content")
DOC = os.path.join(RINK, "CARTRIDGE.md")


def load(p):
    return json.load(open(p, encoding="utf-8"))


def walk_schema(node, path, out, defs):
    if "$ref" in node:
        ref = node["$ref"]
        if ref.startswith("#/$defs/"):
            node = defs[ref.split("/")[-1]]
        else:
            out.append((path, "see " + ref, "", ""))
            return
    t = node.get("type")
    if t == "object" and "properties" in node:
        for k, v in node["properties"].items():
            walk_schema(v, path + [k], out, defs)
        return
    if t == "array" and isinstance(node.get("items"), dict) and node["items"].get("type") == "object" and "properties" in node["items"]:
        lim = []
        if "minItems" in node: lim.append("min %s" % node["minItems"])
        if "maxItems" in node: lim.append("max %s" % node["maxItems"])
        out.append((path, "list" + (" (%s)" % ", ".join(lim) if lim else ""), node.get("description", ""), ""))
        for k, v in node["items"]["properties"].items():
            walk_schema(v, path + ["[]", k], out, defs)
        return
    rng = ""
    if "enum" in node: rng = " \\| ".join(str(x) for x in node["enum"])
    elif "const" in node: rng = "= %s" % json.dumps(node["const"])
    elif "minimum" in node or "maximum" in node: rng = "%s..%s" % (node.get("minimum", ""), node.get("maximum", ""))
    elif "maxLength" in node: rng = "text up to %s" % node["maxLength"]
    elif "pattern" in node: rng = "text (pattern)"
    if t == "array":
        it = node.get("items", {})
        rng = "list of %s%s" % (it.get("type", "?"), (" " + "%s..%s" % (it.get("minimum", ""), it.get("maximum", ""))) if "minimum" in it else "")
        if "maxItems" in node: rng += ", max %s" % node["maxItems"]
    tt = t if isinstance(t, str) else "/".join(t) if isinstance(t, list) else ""
    out.append((path, (tt + " " + rng).strip(), node.get("description", ""), ""))


def get(obj, path):
    for k in path:
        if k == "[]":
            return None
        if not isinstance(obj, dict) or k not in obj:
            return None
        obj = obj[k]
    return obj


def flat(obj, path=""):
    out = {}
    if isinstance(obj, dict):
        for k, v in obj.items():
            out.update(flat(v, path + "." + k if path else k))
    else:
        out[path] = obj
    return out


def teams_word(t):
    try:
        return " v ".join(str(len(x.get("skaters", []))) for x in t)
    except Exception:
        return "?"


def diff(base, cut, skip=("game.meta", "title", "id", "theme", "tunables")):
    a, b = flat(base), flat(cut)
    rows = []
    for k in sorted(set(a) | set(b)):
        if any(k == s or k.startswith(s + ".") for s in skip):
            continue
        if a.get(k, "<absent>") != b.get(k, "<absent>"):
            v = b.get(k, "<absent>")
            if k == "game.teams" and isinstance(v, list):
                rows.append("`game.teams` %s" % teams_word(v))
            elif isinstance(v, list):
                rows.append("`%s` (a list of %d)" % (k, len(v)))
            else:
                rows.append("`%s` %s" % (k, "absent" if v == "<absent>" else json.dumps(v)))
    return rows


def cell(s):
    return str(s).replace("|", "\\|").replace("\n", " ")


def keys_part():
    cart = load(os.path.join(HERE, "cartridge.schema.json"))
    game = load(os.path.join(HERE, "game.schema.json"))
    reg = load(os.path.join(CONTENT, "Cartridges", "hockey.regular.cartridge.json"))
    rows = []
    env = []
    for k, v in cart["properties"].items():
        if k == "game":
            continue
        t = v.get("type", "")
        env.append("| `%s` | %s | %s |" % (k, cell(t if isinstance(t, str) else "/".join(t)), cell(v.get("description", ""))))
    out = []
    walk_schema(game, ["game"], out, game.get("$defs", {}))
    for path, rng, desc, _ in out:
        val = get(reg, path)
        shown = "" if val is None or isinstance(val, (dict, list)) else json.dumps(val)
        rows.append("| `%s` | %s | %s | %s |" % (".".join(path).replace(".[]", "[]"), cell(rng), cell(desc), cell(shown)))
    return ("The envelope (cartridge.schema.json):\n\n| key | type | what it is |\n|---|---|---|\n" + "\n".join(env) +
            "\n\nThe game (game.schema.json), %d keys; `[]` = each element of a list; \"regular\" = hockey.regular's value (empty: absent, the "
            "loader's default applies):\n\n| key | range | thirdjam's meaning | regular |\n|---|---|---|---|\n" % len(rows) + "\n".join(rows) + "\n")


def modes_part():
    reg = load(os.path.join(CONTENT, "Cartridges", "hockey.regular.cartridge.json"))
    d = os.path.join(CONTENT, "Cartridges", "modes")
    lines = ["| mode | its words (game.meta.pitch) | keys changed from hockey.regular |", "|---|---|---|"]
    for sub in ["", "parked"]:
        dd = os.path.join(d, sub)
        for f in sorted(x for x in os.listdir(dd) if x.endswith(".cartridge.json")):
            c = load(os.path.join(dd, f))
            pitch = ((c.get("game") or {}).get("meta") or {}).get("pitch", "")
            name = c.get("title", f) + (" (parked)" if sub else "")
            lines.append("| %s | %s | %s |" % (cell(name), cell(pitch), cell("; ".join(diff(reg, c)))))
    return "\n".join(lines) + "\n"


def cuts_part():
    cc = load(os.path.join(CONTENT, "Designer", "cached-cuts.json"))
    reg = load(os.path.join(CONTENT, "Cartridges", "hockey.regular.cartridge.json"))
    lines = ["| the person said | thirdjam's cut | keys moved (the tunable `values` and `game` keys) |", "|---|---|---|"]
    for c in cc["cuts"]:
        cart = c.get("cartridge") or {}
        moved = ["`values.%s` %s" % (k, json.dumps(v)) for k, v in sorted((cart.get("values") or {}).items())]
        moved += [r for r in diff(reg, cart, skip=("game.meta", "title", "id", "theme", "tunables", "values", "rules", "entities", "ai", "seed"))]
        lines.append("| \"%s\" | %s (%s) | %s |" % (cell(c.get("sentence", "")), cell(c.get("name", "")), cell(c.get("outcome", "")), cell("; ".join(moved) or "nothing")))
    return "\n".join(lines) + "\n"


def main():
    check = "--check" in sys.argv[1:]
    doc = open(DOC, encoding="utf-8").read()
    new = doc
    for name, fn in (("keys", keys_part), ("modes", modes_part), ("cuts", cuts_part)):
        pat = re.compile(r"(<!-- generated:%s -->\n).*?(<!-- /generated:%s -->)" % (name, name), re.S)
        if not pat.search(new):
            print("FAIL  rink catalog: CARTRIDGE.md has no generated:%s markers" % name)
            return 1
        part = fn()
        new = pat.sub(lambda m: m.group(1) + part + m.group(2), new)
    if check:
        if new != doc:
            print("FAIL  rink catalog: CARTRIDGE.md is not what catalog.py writes (run: python -I engine/cores/rink/schema/catalog.py)")
            return 1
        print("PASS  rink catalog: CARTRIDGE.md's generated parts are current")
        return 0
    open(DOC, "w", encoding="utf-8", newline="\n").write(new)
    print("PASS  rink catalog: CARTRIDGE.md written (keys, modes, cuts)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
