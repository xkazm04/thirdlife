# Runs INSIDE Unreal (UE 5.9, PythonScriptPlugin + GLTFExporter enabled) on a copy of the thirdjam project:
#   UnrealEditor-Cmd.exe <copy>/ThirdJam.uproject -run=pythonscript -script=<this file> -unattended -nullrhi
# Environment: TL_SKATER_OUT = output folder, TL_SKATER_CONTENT = <copy>/Plugins/JamAssets/Content/Skaters,
#              TL_SKATER_STEPS = comma list of meta,mesh,clips,tracks,blend (default all)
# Exports thirdjam's shipped skater (SK_SkaterTB1_P3): the mesh as glTF, every AS_SkaterTB1_P3_* clip as glTF,
# every clip's bone tracks sampled per key as JSON (the truth the Godot import is checked against), the blend
# spaces' sample tables, the sockets and the material slots. Nothing in the Unreal project is saved.
import json
import os
import traceback

import unreal

OUT = os.environ["TL_SKATER_OUT"]
CONTENT = os.environ["TL_SKATER_CONTENT"]
STEPS = set(os.environ.get("TL_SKATER_STEPS", "meta,mesh,clips,tracks,blend").split(","))
PKG = "/JamAssets/Skaters/"
MESH = "SK_SkaterTB1_P3"
CLIP_PREFIX = "AS_SkaterTB1_P3_"
BLEND = ["BS_SkaterTB1_P3_Aim", "BS_SkaterTB1_P3_Skate", "BS_SkaterTB1_P3_SkateReady"]

os.makedirs(os.path.join(OUT, "clips"), exist_ok=True)
os.makedirs(os.path.join(OUT, "tracks"), exist_ok=True)
LOG = open(os.path.join(OUT, "export.log"), "a", encoding="utf-8")


def log(msg):
    LOG.write(msg + "\n")
    LOG.flush()
    unreal.log("TLSKATER " + msg)


def attempt(label, fn, default=None):
    try:
        return fn()
    except Exception as e:  # noqa: BLE001 (an exporter must say what failed and go on)
        log("FAIL %s: %s" % (label, "".join(traceback.format_exception_only(type(e), e)).strip()))
        return default


def vec(v):
    return [round(v.x, 6), round(v.y, 6), round(v.z, 6)]


def quat(q):
    return [round(q.x, 7), round(q.y, 7), round(q.z, 7), round(q.w, 7)]


def rot(r):
    return {"roll": round(r.roll, 5), "pitch": round(r.pitch, 5), "yaw": round(r.yaw, 5)}


def write_json(name, data):
    with open(os.path.join(OUT, name), "w", encoding="utf-8") as f:
        json.dump(data, f, separators=(",", ":"))


def gltf_options():
    o = unreal.GLTFExportOptions()
    sets = {
        "export_uniform_scale": 0.01,          # centimetres to metres
        "export_preview_mesh": True,
        "export_vertex_colors": True,          # the jersey material mixes vertex colour (MI_SkaterTB1_P3_JerseyDeco: VColMix 1)
        "export_vertex_skin_weights": True,
        "export_animation_sequences": True,
        "export_level_sequences": False,
        "bake_material_inputs": unreal.GLTFMaterialBakeMode.DISABLED,
        "texture_image_format": unreal.GLTFTextureImageFormat.NONE,
        "export_proxy_materials": False,
        "export_unlit_materials": False,
        "export_clear_coat_materials": False,
        "export_cloth_materials": False,
        "export_thin_translucent_materials": False,
        "export_specular_glossiness_materials": False,
        "export_emissive_strength": False,
        "use_mesh_quantization": False,
        "export_cameras": False,
        "export_lights": False,
        "default_level_of_detail": 0,
    }
    for k, v in sets.items():
        try:
            o.set_editor_property(k, v)
        except Exception as e:  # noqa: BLE001
            log("option %s not set: %s" % (k, e))
    return o


def export_gltf(obj, path):
    msgs = unreal.GLTFExporter.export_to_gltf(obj, path, gltf_options(), set())
    ok = os.path.isfile(path)
    extra = ""
    for field in ("errors", "warnings", "suggestions"):
        try:
            lst = list(msgs.get_editor_property(field))
            if lst:
                extra += " %s=%s" % (field, lst[:4])
        except Exception:  # noqa: BLE001
            pass
    return ok, extra


for _mod in ("AnimationBlueprintLibrary", "GLTFExporter", "MaterialEditor"):
    attempt("load module " + _mod, lambda: unreal.load_module(_mod))

clip_names = sorted(f[:-7] for f in os.listdir(CONTENT) if f.startswith(CLIP_PREFIX) and f.endswith(".uasset"))
log("clips on disk: %d" % len(clip_names))

mesh = unreal.load_asset(PKG + MESH)
log("mesh loaded: %s" % mesh)

if "meta" in STEPS:
    meta = {"mesh": MESH, "clips_on_disk": len(clip_names)}
    socks = []
    for i in range(mesh.num_sockets()):
        s = mesh.get_socket_by_index(i)
        socks.append({
            "name": str(s.socket_name), "bone": str(s.bone_name),
            "location_cm": vec(s.relative_location), "rotation_deg": rot(s.relative_rotation),
            "scale": vec(s.relative_scale),
        })
    meta["sockets"] = socks
    mats = []
    for m in mesh.materials:
        mi = m.material_interface
        row = {"slot": str(m.material_slot_name), "material": mi.get_path_name() if mi else ""}

        def params(mi=mi, row=row):
            if not isinstance(mi, unreal.MaterialInstanceConstant):
                return
            row["parent"] = mi.parent.get_path_name() if mi.parent else ""
            MEL = unreal.MaterialEditingLibrary
            row["vectors"] = {str(n): [round(c, 5) for c in MEL.get_material_instance_vector_parameter_value(mi, n).to_tuple()]
                              for n in MEL.get_vector_parameter_names(mi)}
            row["scalars"] = {str(n): round(MEL.get_material_instance_scalar_parameter_value(mi, n), 5)
                              for n in MEL.get_scalar_parameter_names(mi)}
        attempt("material params " + row["slot"], params)
        mats.append(row)
    meta["materials"] = mats
    b = mesh.get_bounds()
    meta["bounds_cm"] = {"origin": vec(b.origin), "extent": vec(b.box_extent), "radius": round(b.sphere_radius, 4)}
    meta["skeleton"] = mesh.skeleton.get_path_name() if mesh.skeleton else ""
    write_json("meta.json", meta)
    log("meta written: %d sockets, %d material slots" % (len(socks), len(mats)))

if "mesh" in STEPS:
    ok, extra = attempt("mesh gltf", lambda: export_gltf(mesh, os.path.join(OUT, MESH + ".glb")), (False, ""))
    log("mesh gltf ok=%s%s" % (ok, extra))

    def fbx():
        task = unreal.AssetExportTask()
        task.object = mesh
        task.filename = os.path.join(OUT, MESH + ".fbx")
        task.automated = True
        task.replace_identical = True
        task.prompt = False
        opt = unreal.FbxExportOption()
        opt.set_editor_property("ascii", False)
        opt.set_editor_property("vertex_color", True)
        opt.set_editor_property("level_of_detail", False)
        task.options = opt
        return unreal.Exporter.run_asset_export_task(task)
    log("mesh fbx ok=%s" % attempt("mesh fbx", fbx, False))

index = []
done = failed = 0
AL = unreal.AnimationLibrary
for name in clip_names:
    if not ({"clips", "tracks"} & STEPS):
        break
    anim = attempt("load " + name, lambda: unreal.load_asset(PKG + name))
    if anim is None or not isinstance(anim, unreal.AnimSequence):
        log("FAIL not an AnimSequence: %s" % name)
        failed += 1
        continue
    row = {"name": name}
    row["length_s"] = attempt("len " + name, lambda: round(anim.get_play_length(), 6))
    row["keys"] = attempt("keys " + name, lambda: int(AL.get_num_keys(anim)))
    row["frames"] = attempt("frames " + name, lambda: int(AL.get_num_frames(anim)))
    row["fps"] = attempt("fps " + name, lambda: round((row["frames"] or 0) / row["length_s"], 4) if row["length_s"] else None)
    row["root_motion"] = attempt("rm " + name, lambda: bool(AL.is_root_motion_enabled(anim)))
    row["rate_scale"] = attempt("rate " + name, lambda: round(anim.get_editor_property("rate_scale"), 5))
    row["loop"] = attempt("loop " + name, lambda: bool(anim.get_editor_property("loop")))
    row["additive"] = attempt("additive " + name, lambda: str(anim.get_editor_property("additive_anim_type")))
    row["interpolation"] = attempt("interp " + name, lambda: str(anim.get_editor_property("interpolation")))
    row["skeleton"] = attempt("skel " + name, lambda: anim.get_skeleton().get_name())

    def notifies(anim=anim):
        out = []
        for ev in AL.get_animation_notify_events(anim):
            out.append({"name": str(ev.notify_name), "t": round(ev.get_trigger_time(), 5), "dur": round(ev.get_duration(), 5)})
        return out
    row["notifies"] = attempt("notifies " + name, notifies, [])
    row["curves"] = attempt("curves " + name, lambda: [str(c) for c in AL.get_animation_curve_names(anim, unreal.RawCurveTrackTypes.RCT_FLOAT)], [])

    if "tracks" in STEPS:
        def tracks(anim=anim, name=name, row=row):
            bones = [str(b) for b in AL.get_animation_track_names(anim)]
            n = int(row["keys"] or 0)
            data = {"name": name, "keys": n, "fps": row["fps"], "length_s": row["length_s"], "bones": bones,
                    "space": "ue_local_cm", "t": {}, "q": {}, "s": {}}
            for bname in bones:
                ts, qs, ss = [], [], []
                scale_varies = False
                for k in range(n):
                    tr = AL.get_bone_pose_for_frame(anim, bname, k, False)
                    ts.append(vec(tr.translation))
                    qs.append(quat(tr.rotation))
                    sc = vec(tr.scale3d)
                    ss.append(sc)
                    if abs(sc[0] - 1) > 1e-4 or abs(sc[1] - 1) > 1e-4 or abs(sc[2] - 1) > 1e-4:
                        scale_varies = True
                data["t"][bname] = ts
                data["q"][bname] = qs
                if scale_varies:
                    data["s"][bname] = ss
            write_json("tracks/%s.json" % name, data)
            return len(bones)
        row["track_bones"] = attempt("tracks " + name, tracks)

    if "clips" in STEPS:
        ok, extra = attempt("clip gltf " + name, lambda: export_gltf(anim, os.path.join(OUT, "clips", name + ".glb")), (False, ""))
        row["gltf"] = bool(ok)
        if extra:
            row["gltf_notes"] = extra
        if ok:
            done += 1
        else:
            failed += 1
            log("FAIL clip gltf %s%s" % (name, extra))
    index.append(row)
    if len(index) % 20 == 0:
        log("clips %d / %d" % (len(index), len(clip_names)))

if index:
    write_json("clips.json", {"found": len(clip_names), "gltf_done": done, "failed": failed, "clips": index})
    log("clips found=%d gltf_done=%d failed=%d" % (len(clip_names), done, failed))

if "blend" in STEPS:
    spaces = []
    for bname in BLEND:
        bs = attempt("load " + bname, lambda: unreal.load_asset(PKG + bname))
        if bs is None:
            continue
        row = {"name": bname, "class": bs.get_class().get_name()}

        def samples(bs=bs):
            out = []
            for s in bs.get_editor_property("sample_data"):
                a = s.get_editor_property("animation")
                out.append({"clip": a.get_name() if a else "", "value": vec(s.get_editor_property("sample_value")),
                            "rate_scale": round(s.get_editor_property("rate_scale"), 5)})
            return out
        row["samples"] = attempt("samples " + bname, samples, [])

        def axes(bs=bs):
            out = []
            for p in bs.get_editor_property("blend_parameters"):
                d = {}
                for k in ("display_name", "min", "max", "grid_num", "snap_to_grid", "wrap_input"):
                    try:
                        v = p.get_editor_property(k)
                        d[k] = v if isinstance(v, (int, float, bool)) else str(v)
                    except Exception:  # noqa: BLE001
                        pass
                out.append(d)
            return out
        row["axes"] = attempt("axes " + bname, axes, [])
        for k in ("interpolation_param", "target_weight_interpolation_speed_per_sec", "target_weight_interpolation_ease_in_out",
                  "allow_mesh_space_blending", "loop", "notify_trigger_mode", "axis_to_scale_animation", "per_bone_blend_mode",
                  "allow_marker_based_sync"):
            def prop(bs=bs, k=k):
                v = bs.get_editor_property(k)
                if isinstance(v, (int, float, bool)):
                    return v
                if isinstance(v, unreal.Array):
                    out = []
                    for it in v:
                        d = {}
                        for kk in ("interpolation_time", "damping_ratio", "max_speed", "interpolation_type"):
                            try:
                                vv = it.get_editor_property(kk)
                                d[kk] = vv if isinstance(vv, (int, float, bool)) else str(vv)
                            except Exception:  # noqa: BLE001
                                pass
                        out.append(d)
                    return out
                return str(v)
            val = attempt("%s.%s" % (bname, k), prop)
            if val is not None:
                row[k] = val
        spaces.append(row)
    write_json("blendspaces.json", {"spaces": spaces})
    log("blend spaces written: %d" % len(spaces))

log("TLSKATER_EXPORT_END")
LOG.close()
