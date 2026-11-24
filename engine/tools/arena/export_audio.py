# Runs INSIDE Unreal (UE 5.9, commandlet, as engine/tools/skater/export_skater.py) on a copy of the thirdjam project:
#   UnrealEditor-Cmd.exe <copy>/ThirdJam.uproject -run=pythonscript -script=<this file> -unattended -nullrhi
# Environment: TL_AUDIO_OUT = output folder; TL_AUDIO_WAV=0 skips the waves (graphs and table only).
# Writes thirdjam's audio as its game holds it:
#   wav/<name>.wav       every SoundWave under /JamAssets/Audio (the effects, the crowd, the music, the commentator)
#   graphs/<name>.txt    every MetaSound source's document as Unreal's own struct text (nodes, edges, literals, the
#                        waves an input names): what audio_digest.py reads the rules from
#   audio.json           per asset: class, and for a wave its seconds, channels, sample rate, looping, sound class,
#                        volume, pitch; for a sound class and a mix their properties
# Nothing in the Unreal project is saved.
import json
import os
import traceback

import unreal

OUT = os.environ["TL_AUDIO_OUT"]
ROOT = "/JamAssets/Audio"
for d in ("wav", "graphs"):
    os.makedirs(os.path.join(OUT, d), exist_ok=True)
LOG = open(os.path.join(OUT, "export.log"), "a", encoding="utf-8")
notes = []


def log(msg):
    LOG.write(msg + "\n")
    LOG.flush()
    unreal.log("TLAUDIO " + msg)


def attempt(label, fn, default=None):
    try:
        return fn()
    except Exception as e:  # noqa: BLE001
        notes.append("FAIL %s: %s" % (label, "".join(traceback.format_exception_only(type(e), e)).strip()[:300]))
        log(notes[-1])
        return default


def quiet(fn, default=None):
    try:
        return fn()
    except Exception:  # noqa: BLE001
        return default


def conv(v, depth=0):
    if v is None or isinstance(v, (bool, int, str)):
        return v
    if isinstance(v, float):
        return round(v, 6)
    if isinstance(v, (unreal.Name, unreal.Text)):
        return str(v)
    if isinstance(v, unreal.EnumBase):
        return str(v).split(".")[-1].split(":")[0].strip("<> ")
    if isinstance(v, unreal.Object):
        return quiet(lambda: v.get_path_name(), str(v))
    if isinstance(v, (unreal.Array, list, tuple)):
        return [conv(x, depth + 1) for x in list(v)[:64]]
    if isinstance(v, unreal.StructBase) and depth < 3:
        return props(v, depth + 1)
    return str(v)[:200]


def props(obj, depth=0):
    out = {}
    for name in dir(type(obj)):
        if name.startswith("_"):
            continue
        try:
            v = obj.get_editor_property(name)
        except Exception:  # noqa: BLE001
            continue
        out[name] = conv(v, depth)
    return out


def export(obj, fn):
    task = unreal.AssetExportTask()
    task.object = obj
    task.filename = fn
    task.automated = True
    task.replace_identical = True
    task.prompt = False
    return unreal.Exporter.run_asset_export_task(task)


reg = unreal.AssetRegistryHelpers.get_asset_registry()
reg.scan_paths_synchronous([ROOT], True)      # a commandlet starts with an empty registry
assets = reg.get_assets_by_path(ROOT, recursive=True)
log("assets %d" % len(assets))
rows = {}
counts = {}
for ad in assets:
    path = "%s.%s" % (ad.package_name, ad.asset_name)
    cls = str(ad.asset_class_path.asset_name)
    counts[cls] = counts.get(cls, 0) + 1
    obj = attempt("load " + path, lambda: unreal.load_asset(path))
    if obj is None:
        continue
    name = str(ad.asset_name)
    row = {"class": cls, "folder": str(ad.package_path)}
    rows[path] = row
    if isinstance(obj, unreal.SoundWave) and cls == "SoundWave":       # a MetaSound source is a SoundWave too
        fn = os.path.join(OUT, "wav", name + ".wav")
        ok = os.path.isfile(fn) if os.environ.get("TL_AUDIO_WAV") == "0" else attempt("wav " + name, lambda: export(obj, fn), False)
        row["wav"] = bool(ok) and os.path.isfile(fn)
        row["bytes"] = os.path.getsize(fn) if row["wav"] else 0
        for k in ("duration", "num_channels", "sample_rate", "looping", "sound_class_object", "volume", "pitch",
                  "sound_group", "attenuation_settings", "total_samples"):
            v = quiet(lambda k=k: obj.get_editor_property(k))
            if v is not None:
                row[k] = conv(v)
        row["seconds"] = quiet(lambda: round(obj.get_duration(), 4))
    elif cls in ("MetaSoundSource", "MetaSoundPatch"):
        # the document as Unreal's own struct text (nodes with their classes, pins and literals, edges, graph inputs
        # with their defaults): the asset exporters write nothing for a MetaSound, the struct's export_text does
        fn = os.path.join(OUT, "graphs", name + ".txt")

        def doc(obj=obj, fn=fn):
            t = obj.get_editor_property("root_metasound_document").export_text()
            with open(fn, "w", encoding="utf-8") as f:
                f.write(t)
            return len(t)
        row["graph_chars"] = attempt("graph " + name, doc, 0)
        row["t3d"] = bool(row["graph_chars"])
        for k in ("sound_class_object", "attenuation_settings", "output_format", "looping", "duration", "volume", "pitch"):
            v = quiet(lambda k=k: obj.get_editor_property(k))
            if v is not None:
                row[k] = conv(v)
        att = quiet(lambda: obj.get_editor_property("attenuation_settings"))
        if att is not None:
            row["attenuation"] = attempt("attenuation " + name, lambda: props(att.get_editor_property("attenuation")))
    else:
        row["props"] = attempt("props " + name, lambda: props(obj))
with open(os.path.join(OUT, "audio.json"), "w", encoding="utf-8") as f:
    json.dump({"schema": "tl.arena.audio/1", "counts": counts, "assets": rows, "notes": notes}, f, indent=1)
log("TLAUDIO_END assets=%d waves=%d graphs=%d %s" % (
    len(rows), sum(1 for r in rows.values() if r.get("wav")), sum(1 for r in rows.values() if r.get("t3d")), json.dumps(counts)))
LOG.close()
