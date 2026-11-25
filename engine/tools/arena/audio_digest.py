#!/usr/bin/env python3
"""Reads thirdjam's MetaSound documents (export_audio.py: graphs/<name>.txt, Unreal's struct text) into plain graphs and
prints, per sound, what it is made of: its inputs with their defaults (the waves it names), its nodes with the values
set on their pins, and for every node what feeds each pin. The rules of a sound (which clip, when, how loud, what
Strength and Variant change) are read off this, not off a description.

usage: python audio_digest.py <graphs folder> <out json> [name ...]     (names without MS_: print those in full)

The json: {sound: {inputs: {name: {type, default}}, nodes: [{id, name, class, literals: {pin: value}, feeds: {pin:
"<node>.<pin>"}}], waves: [short names], uses: {strength, variant, synth: [oscillator classes]}}}."""
import json
import os
import re
import sys


def parse(text):
    """Unreal's struct text -> nested Python: (A=1,B=(..),C=((..),(..))) ; a list is a parenthesis of unnamed items."""
    pos = 0
    n = len(text)

    def value():
        nonlocal pos
        if pos < n and text[pos] == '"':
            j = pos + 1
            out = []
            while text[j] != '"':
                if text[j] == "\\":
                    j += 1
                out.append(text[j])
                j += 1
            pos = j + 1
            return "".join(out)
        if pos < n and text[pos] == "(":
            pos += 1
            items = []
            named = {}
            is_named = None
            while pos < n and text[pos] != ")":
                if text[pos] in ", ":
                    pos += 1
                    continue
                m = re.match(r"[A-Za-z_][A-Za-z0-9_]*(?:\(\d+\))?=", text[pos:])
                if m and is_named is not False:
                    is_named = True
                    key = m.group(0)[:-1]
                    pos += len(m.group(0))
                    named[key] = value() if pos < n and text[pos] not in ",)" else ""
                else:
                    is_named = False
                    items.append(value())
            pos += 1
            return named if is_named else items
        j = pos
        depth = 0
        while j < n and not (depth == 0 and text[j] in ",)"):
            if text[j] == "(":
                depth += 1
            elif text[j] == ")":
                depth -= 1
            j += 1
        tok = text[pos:j]
        pos = j
        return tok
    return value()


def literal(v):
    if not isinstance(v, dict):
        return v
    t = v.get("Type", "")
    for k in ("AsFloat", "AsInteger", "AsBoolean", "AsString", "AsUObject"):
        if k in v:
            x = v[k]
            x = x if isinstance(x, list) else [x]
            if k == "AsFloat":
                x = [float(a) for a in x]
            elif k == "AsInteger":
                x = [int(a) for a in x]
            elif k == "AsBoolean":
                x = [str(a) == "True" for a in x]
            elif k == "AsUObject":
                x = [str(a).split(".")[-1].rstrip("'") if a not in ("None", "") else "" for a in x]
            return x if "Array" in t else (x[0] if x else None)
    return None


def default_of(dv):
    if not dv or not isinstance(dv, list) or not isinstance(dv[0], dict):
        return None
    lit = dv[0].get("Literal", {})
    return literal(lit) if isinstance(lit, dict) else None


def graph(text):
    d = parse(text)
    classes = {}
    for dep in (d.get("Dependencies") or []):
        cn = dep["Metadata"]["ClassName"]
        full = ".".join(x for x in (cn.get("Namespace", ""), cn.get("Name", ""), cn.get("Variant", "")) if x)
        defaults = {}
        names = {}
        for vx in ((dep.get("Interface") or dep.get("DefaultInterface") or {}).get("Inputs") or []):
            names[vx["VertexID"]] = vx.get("Name", "")
            dv = vx.get("Defaults")
            if dv:
                defaults[vx.get("Name", "")] = default_of(dv)
        classes[dep["ID"]] = {"name": full, "type": dep["Metadata"].get("Type", ""), "defaults": defaults}
    root = d["RootGraph"]
    inputs = {}
    for vx in ((root.get("Interface") or root.get("DefaultInterface") or {}).get("Inputs") or []):
        dv = vx.get("Defaults")
        inputs[vx["Name"]] = {"type": vx.get("TypeName", ""), "default": default_of(dv)}
    page = root["PagedGraphs"][0]
    nodes = {}
    pin_in = {}
    pin_out = {}
    for nd in page["Nodes"]:
        cls = classes.get(nd["ClassID"], {"name": "?", "type": "", "defaults": {}})
        ins = {vx["VertexID"]: vx["Name"] for vx in (nd["Interface"].get("Inputs") or [])}
        outs = {vx["VertexID"]: vx["Name"] for vx in (nd["Interface"].get("Outputs") or [])}
        lits = {}
        for il in nd.get("InputLiterals", []) or []:
            lits[ins.get(il["VertexID"], il["VertexID"])] = literal(il.get("Value", {}))
        nodes[nd["ID"]] = {"id": nd["ID"][:6], "name": nd["Name"], "class": cls["name"], "kind": cls["type"], "literals": lits,
                           "class_defaults": {k: v for k, v in cls["defaults"].items() if v is not None}, "feeds": {}, "pins_in": list(ins.values()),
                           "pins_out": list(outs.values())}
        pin_in[nd["ID"]] = ins
        pin_out[nd["ID"]] = outs
    for e in page.get("Edges", []) or []:
        f, t = nodes.get(e["FromNodeID"]), nodes.get(e["ToNodeID"])
        if f is None or t is None:
            continue
        t["feeds"][pin_in[e["ToNodeID"]].get(e["ToVertexID"], "?")] = "%s#%s.%s" % (f["name"], f["id"], pin_out[e["FromNodeID"]].get(e["FromVertexID"], "?"))
    waves = sorted({w for v in inputs.values() for w in (v["default"] if isinstance(v["default"], list) else [v["default"]])
                    if isinstance(w, str) and (w.startswith("SFX_") or w.startswith("CRD_") or w.startswith("MUS_") or w.startswith("VO_"))})
    for nd in nodes.values():
        for v in nd["literals"].values():
            for w in (v if isinstance(v, list) else [v]):
                if isinstance(w, str) and re.match(r"(SFX|CRD|MUS|VO)_", w) and w not in waves:
                    waves.append(w)
    names = [nd["class"] for nd in nodes.values()]
    synth = sorted({c for c in names if re.search(r"\b(Sine|Saw|Square|Triangle|Noise|LFO)\b", c)})
    return {"inputs": inputs, "nodes": list(nodes.values()), "waves": waves,
            "uses": {"strength": "Strength" in inputs and any("Strength#" in f for nd in nodes.values() for f in nd["feeds"].values()),
                     "variant": "Variant" in inputs and any("Variant#" in f for nd in nodes.values() for f in nd["feeds"].values()),
                     "synth": synth}}


if __name__ == "__main__":
    folder, out = sys.argv[1], sys.argv[2]
    show = set(sys.argv[3:])
    table = {}
    for fn in sorted(os.listdir(folder)):
        if not fn.endswith(".txt"):
            continue
        name = fn[:-4]
        g = graph(open(os.path.join(folder, fn), encoding="utf-8").read())
        table[name] = g
        print("%-22s nodes %-3d waves %-2d strength=%s variant=%s synth=%s inputs=%s" % (
            name, len(g["nodes"]), len(g["waves"]), g["uses"]["strength"], g["uses"]["variant"], ",".join(c.split(".")[-2] if "." in c else c for c in g["uses"]["synth"]),
            {k: (v["default"] if not isinstance(v["default"], list) else "[%d]" % len(v["default"])) for k, v in g["inputs"].items() if not k.startswith("UE.")}))
        if name[3:] in show or name in show:
            for nd in g["nodes"]:
                print("    %-30s %-44s lit=%s feeds=%s" % (nd["name"] + "#" + nd["id"], nd["class"], nd["literals"], nd["feeds"]))
    with open(out, "w", encoding="utf-8") as f:
        json.dump(table, f, indent=1)
