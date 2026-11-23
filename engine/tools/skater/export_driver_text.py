# Runs INSIDE Unreal (commandlet, as export_skater.py): tries to write thirdjam's shipped figure driver as text.
#   UnrealEditor-Cmd.exe <copy>/ThirdJam.uproject -run=pythonscript -script=<this file> -unattended -nullrhi
# Environment: TL_SKATER_OUT = output folder.
# The driver is two Blueprint assets (ABP_SkaterTB1_P3: the animation graph and state machine; BP_SkaterVisual_TB1_P3:
# the IJamSkaterVisual implementation). Their graphs cannot be read as source; this asks Unreal's own text exporters
# (T3D / COPY) for whatever they give, and lists the variables and functions the generated classes declare.
# Writes <out>/driver/<asset>.<ext> and <out>/driver/driver.json (what was tried and what came out).
import json
import os
import traceback

import unreal

OUT = os.path.join(os.environ["TL_SKATER_OUT"], "driver")
os.makedirs(OUT, exist_ok=True)
PKG = "/JamAssets/Skaters/"
ASSETS = os.environ.get("TL_SKATER_ASSETS", "ABP_SkaterTB1_P3,BP_SkaterVisual_TB1_P3").split(",")
rep = {"schema": "tl.skater.driver_text/1", "assets": []}


def attempt(row, label, fn, default=None):
    try:
        return fn()
    except Exception as e:  # noqa: BLE001
        row.setdefault("failed", []).append("%s: %s" % (label, "".join(traceback.format_exception_only(type(e), e)).strip()[:300]))
        return default


for name in ASSETS:
    row = {"asset": name, "files": {}}
    obj = attempt(row, "load", lambda: unreal.load_asset(PKG + name))
    rep["assets"].append(row)
    if obj is None:
        continue
    row["class"] = obj.get_class().get_name()
    for ext in ("t3d",):
        path = os.path.join(OUT, "%s.%s" % (name, ext))

        def export(path=path):
            task = unreal.AssetExportTask()
            task.object = obj
            task.filename = path
            task.automated = True
            task.replace_identical = True
            task.prompt = False
            return unreal.Exporter.run_asset_export_task(task)
        ok = attempt(row, "export " + ext, export, False)
        row["files"][ext] = {"ok": bool(ok), "bytes": os.path.getsize(path) if os.path.isfile(path) else 0}
    gen = attempt(row, "generated class", lambda: obj.generated_class())
    if gen is not None:
        row["generated_class"] = gen.get_name()
        cdo = attempt(row, "default object", lambda: unreal.get_default_object(gen))
        if cdo is not None:
            names = [n for n in dir(cdo) if not n.startswith("_")]
            row["members"] = names
    for label, fn in (("graphs", lambda: [g.get_name() for g in unreal.BlueprintEditorLibrary.get_all_graphs(obj)] if hasattr(unreal.BlueprintEditorLibrary, "get_all_graphs") else None),
                      ("parent", lambda: obj.get_editor_property("parent_class").get_name())):
        v = attempt(row, label, fn)
        if v is not None:
            row[label] = v

# The variables' default values (the class default object), for the names listed in TL_SKATER_VARNAMES
# (a JSON file {asset: [variable, ...]}): written to <out>/driver/defaults.json.
if os.environ.get("TL_SKATER_VARNAMES"):
    names = json.load(open(os.environ["TL_SKATER_VARNAMES"], encoding="utf-8"))
    defaults = {}
    for asset, vars_ in names.items():
        obj = unreal.load_asset(PKG + asset)
        cdo = unreal.get_default_object(obj.generated_class())
        d = {}
        for v in vars_:
            try:
                val = cdo.get_editor_property(v)
            except Exception as e:  # noqa: BLE001
                d[v] = {"error": str(e)[:120]}
                continue
            if isinstance(val, (bool, int, float, str)):
                d[v] = val
            elif isinstance(val, unreal.Rotator):
                d[v] = {"rotator_roll_pitch_yaw": [val.roll, val.pitch, val.yaw]}
            elif isinstance(val, unreal.Vector):
                d[v] = {"vector": [val.x, val.y, val.z]}
            elif isinstance(val, unreal.LinearColor):
                d[v] = {"colour": [val.r, val.g, val.b, val.a]}
            else:
                d[v] = {"object": str(val)[:160]}
        defaults[asset] = d
    with open(os.path.join(OUT, "defaults.json"), "w", encoding="utf-8") as f:
        json.dump(defaults, f, indent=1, sort_keys=True)

with open(os.path.join(OUT, "driver.json"), "w", encoding="utf-8") as f:
    json.dump(rep, f, indent=1)
unreal.log("TLDRIVER done")
