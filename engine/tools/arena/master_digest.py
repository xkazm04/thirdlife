#!/usr/bin/env python3
"""A first reader for the master materials export_arena.py writes as Unreal text (masters/*.t3d): prints every Custom
node (its description, its inputs, its HLSL) and every parameter with its default, so a material can be ported from
what it computes and not from its name.
usage: python master_digest.py <masters folder> <M_Name> [more names] [--only=<substring of a description>]"""
import os
import re
import sys

BS = chr(92)
CODE = re.compile('Code="((?:[^"' + BS + BS + ']|' + BS + BS + '.)*)"')


def digest(path, only):
    s = open(path, encoding="utf-8", errors="replace").read()
    seen = set()
    print("#", os.path.basename(path), len(s), "chars")
    for m in re.finditer(r'Begin Object Name="(MaterialExpression(\w+?)_\d+)"[^\n]*\n(.*?)End Object', s, re.S):
        name, kind, body = m.groups()
        if name in seen or "=" not in body:
            continue
        if kind in ("ScalarParameter", "VectorParameter", "StaticSwitchParameter", "TextureSampleParameter2D", "TextureObjectParameter"):
            pn = re.search(r'ParameterName="([^"]*)"', body)
            dv = re.search(r'DefaultValue=([^\n]*)', body)
            if pn:
                seen.add(name)
                print("  param %-22s %s %s" % (pn.group(1), kind, dv.group(1).strip() if dv else ""))
        if kind != "Custom":
            continue
        code = CODE.search(body)
        if not code:
            continue
        seen.add(name)
        desc = re.search(r'Description="([^"]*)"', body)
        d = desc.group(1) if desc else ""
        ins = re.findall(r'InputName="(\w+)"', body)
        text = code.group(1).replace(BS + "n", "\n").replace(BS + "'", "'").replace(BS + '"', '"').replace(BS + "r", "")
        if only and only not in d:
            print("== %s %s (%d chars, skipped)" % (name, d, len(text)))
            continue
        print("== %s %s inputs %s" % (name, d, ins))
        print(text)


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    only = next((a.split("=", 1)[1] for a in sys.argv[1:] if a.startswith("--only=")), "")
    for n in args[1:]:
        digest(os.path.join(args[0], n + ".t3d"), only)
