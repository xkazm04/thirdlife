# Runs INSIDE the Unreal editor (UE 5.9, with a GPU) on a copy of the thirdjam project whose .uproject enables
# PythonScriptPlugin and GLTFExporter. It needs editor ticks and a running game world, so it is started by the copy's own
# start-up script (the way engine/tools/skater/reference_capture.py is): <copy>/Content/Python/init_unreal.py holding
#   import os
#   if os.environ.get("TL_REF_SCRIPT"): exec(open(os.environ["TL_REF_SCRIPT"], encoding="utf-8").read())
# and then   UnrealEditor.exe <copy>/ThirdJam.uproject /Game/Maps/Rink -unattended -nosplash -nosound -Multiprocess
# Environment: TL_ARENA_OUT = output folder; TL_ARENA_SHOTS = optional JSON file of camera poses
#   [{"name": "centre", "pos_m": [x, y, h], "pitch": deg, "yaw": deg, "hfov": deg}, ...]   (thirdjam's rink axes)
#
# What it does: plays thirdjam's own map in the editor (PIE), so ARinkActor::Build has built the rink and its arena
# pieces and ULookTierSwitcher has streamed the cut's light rig (LR_P3_Clay for hockey.regular), waits for both, then
# writes down THE WORLD THE GAME DRAWS, not the assets on disk:
#   world.json     every actor and component: static meshes and their instances with world transforms and materials,
#                  every light with every exposed property, sky light, fog, post-process settings that are overridden
#   materials.json every material seen: its parent chain, blend and shading model, every scalar, vector and texture
#                  parameter as the game has it at that moment (dynamic instances included)
#   meshes/*.glb   every static mesh seen, as glTF in metres (no textures: the materials are ported by parameter)
#   textures/*.png every texture a material parameter names
#   masters/*.t3d  the master materials as Unreal's own text (to read what a parameter does)
#   shots/*.png    the game world seen by a scene capture from each asked camera pose (no HUD)
# Nothing in the Unreal project is saved; the editor quits itself when the list is done.
import json
import os
import traceback

import unreal

OUT = os.environ["TL_ARENA_OUT"]
SHOTS = json.load(open(os.environ["TL_ARENA_SHOTS"], encoding="utf-8")) if os.environ.get("TL_ARENA_SHOTS") else []
PX_W, PX_H = 1280, 720
PLAY_TICKS = 900       # editor ticks of play before the dump: the light hold (at most 2 s), the rig, the first faceoff
SHOT_WAIT = 6          # ticks between moving the capture and reading it

for d in ("meshes", "textures", "masters", "shots"):
    os.makedirs(os.path.join(OUT, d), exist_ok=True)
LOG = open(os.path.join(OUT, "export.log"), "a", encoding="utf-8")
notes = []


def log(msg):
    LOG.write(msg + "\n")
    LOG.flush()
    unreal.log("TLARENA " + msg)


def note(msg):
    notes.append(msg)
    log(msg)


def attempt(label, fn, default=None):
    try:
        return fn()
    except Exception as e:  # noqa: BLE001 (an exporter says what failed and goes on)
        note("FAIL %s: %s" % (label, "".join(traceback.format_exception_only(type(e), e)).strip()[:400]))
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
    if isinstance(v, unreal.Vector):
        return [round(v.x, 4), round(v.y, 4), round(v.z, 4)]
    if isinstance(v, unreal.Vector2D):
        return [round(v.x, 5), round(v.y, 5)]
    if isinstance(v, unreal.Vector4):
        return [round(v.x, 5), round(v.y, 5), round(v.z, 5), round(v.w, 5)]
    if isinstance(v, unreal.Rotator):
        return {"pitch": round(v.pitch, 5), "yaw": round(v.yaw, 5), "roll": round(v.roll, 5)}
    if isinstance(v, unreal.Quat):
        return [round(v.x, 7), round(v.y, 7), round(v.z, 7), round(v.w, 7)]
    if isinstance(v, unreal.LinearColor):
        return [round(v.r, 6), round(v.g, 6), round(v.b, 6), round(v.a, 6)]
    if isinstance(v, unreal.Color):
        return {"srgb8": [v.r, v.g, v.b, v.a]}
    if isinstance(v, unreal.Transform):
        return xform(v)
    if isinstance(v, (unreal.Name, unreal.Text)):
        return str(v)
    if isinstance(v, unreal.EnumBase):
        return str(v).split(".")[-1].split(":")[0].strip("<> ")
    if isinstance(v, unreal.Object):
        return quiet(lambda: v.get_path_name(), str(v))
    if isinstance(v, (unreal.Array, list, tuple, unreal.Set)):
        return [conv(x, depth + 1) for x in list(v)[:64]]
    if isinstance(v, unreal.StructBase) and depth < 2:
        return props(v, depth + 1)
    return str(v)[:200]


def props(obj, depth=0, only=None):
    out = {}
    for name in dir(type(obj)):
        if name.startswith("_") or (only is not None and name not in only):
            continue
        try:
            v = obj.get_editor_property(name)
        except Exception:  # noqa: BLE001 (not a property, or not readable)
            continue
        out[name] = conv(v, depth)
    return out


def xform(t):
    return {"t_cm": conv(t.translation), "q": conv(t.rotation), "s": conv(t.scale3d)}


materials = {}
meshes = {}
mesh_objs = {}
textures = {}
masters = {}
MEL = unreal.MaterialEditingLibrary


def material_row(mi):
    if mi is None:
        return ""
    path = mi.get_path_name()
    if path in materials:
        return path
    row = {"class": mi.get_class().get_name()}
    materials[path] = row
    parent = quiet(lambda: mi.get_editor_property("parent"))
    if parent is not None:
        row["parent"] = material_row(parent)
    base = quiet(lambda: mi.get_base_material())
    if base is not None:
        row["base"] = base.get_path_name()
        masters[base.get_path_name()] = base
        for k in ("blend_mode", "shading_model", "two_sided", "opacity_mask_clip_value", "material_domain"):
            v = quiet(lambda k=k: base.get_editor_property(k))
            if v is not None:
                row[k] = conv(v)
    is_mid = isinstance(mi, unreal.MaterialInstanceDynamic)
    is_mic = isinstance(mi, unreal.MaterialInstanceConstant)

    def scalars():
        out = {}
        for n in MEL.get_scalar_parameter_names(mi):
            if is_mid:
                out[str(n)] = round(mi.get_scalar_parameter_value(n), 6)
            elif is_mic:
                out[str(n)] = round(MEL.get_material_instance_scalar_parameter_value(mi, n), 6)
            else:
                out[str(n)] = round(MEL.get_material_default_scalar_parameter_value(mi, n), 6)
        return out

    def vectors():
        out = {}
        for n in MEL.get_vector_parameter_names(mi):
            if is_mid:
                out[str(n)] = conv(mi.get_vector_parameter_value(n))
            elif is_mic:
                out[str(n)] = conv(MEL.get_material_instance_vector_parameter_value(mi, n))
            else:
                out[str(n)] = conv(MEL.get_material_default_vector_parameter_value(mi, n))
        return out

    def texs():
        out = {}
        for n in MEL.get_texture_parameter_names(mi):
            if is_mid:
                t = mi.get_texture_parameter_value(n)
            elif is_mic:
                t = MEL.get_material_instance_texture_parameter_value(mi, n)
            else:
                t = MEL.get_material_default_texture_parameter_value(mi, n)
            out[str(n)] = t.get_path_name() if t else ""
            if t is not None:
                textures[t.get_path_name()] = t
        return out

    def switches():
        out = {}
        for n in MEL.get_static_switch_parameter_names(mi):
            if is_mic:
                out[str(n)] = bool(MEL.get_material_instance_static_switch_parameter_value(mi, n))
            elif not is_mid:
                out[str(n)] = bool(MEL.get_material_default_static_switch_parameter_value(mi, n))
        return out
    row["scalars"] = attempt("scalars " + path, scalars, {})
    row["vectors"] = attempt("vectors " + path, vectors, {})
    row["textures"] = attempt("textures " + path, texs, {})
    row["switches"] = attempt("switches " + path, switches, {})
    return path


def mesh_row(sm):
    if sm is None:
        return ""
    path = sm.get_path_name()
    if path in meshes:
        return path
    row = {"name": sm.get_name()}
    meshes[path] = row
    b = quiet(lambda: sm.get_bounds())
    if b is not None:
        row["bounds_cm"] = {"origin": conv(b.origin), "extent": conv(b.box_extent)}
    row["triangles"] = quiet(lambda: int(sm.get_num_triangles(0)))
    row["lods"] = quiet(lambda: int(sm.get_num_lods()))
    row["slots"] = quiet(lambda: [{"slot": str(m.material_slot_name), "material": material_row(m.material_interface)} for m in sm.static_materials], [])
    mesh_objs[path] = sm
    return path


LIGHT_SKIP = {"asset_user_data", "asset_user_data_editor_only", "component_tags", "physics_volume_changed_delegate",
              "on_component_activated", "on_component_deactivated"}


def component_row(c):
    row = {"class": c.get_class().get_name(), "name": c.get_name()}
    if isinstance(c, unreal.SceneComponent):
        row["world"] = xform(c.get_world_transform())
        row["visible"] = bool(quiet(lambda: c.is_visible(), True))
        row["hidden_in_game"] = bool(quiet(lambda: c.get_editor_property("hidden_in_game"), False))
        par = quiet(lambda: c.get_attach_parent())
        if par is not None:
            row["attach"] = par.get_name()
            sock = quiet(lambda: c.get_attach_socket_name())
            if sock is not None and str(sock) != "None":
                row["attach_socket"] = str(sock)
    if isinstance(c, unreal.StaticMeshComponent):
        sm = quiet(lambda: c.static_mesh)
        row["mesh"] = mesh_row(sm)
        row["materials"] = attempt("materials " + c.get_name(), lambda: [material_row(m) for m in c.get_materials()], [])
        for k in ("cast_shadow", "render_custom_depth", "custom_depth_stencil_value", "translucency_sort_priority",
                  "bounds_scale", "affect_distance_field_lighting", "visible_in_ray_tracing"):
            v = quiet(lambda k=k: c.get_editor_property(k))
            if v is not None:
                row[k] = conv(v)
        if isinstance(c, unreal.InstancedStaticMeshComponent):
            n = int(quiet(lambda: c.get_instance_count(), 0))
            inst = []
            for i in range(n):
                t = c.get_instance_transform(i, True)
                if isinstance(t, tuple):
                    t = [x for x in t if isinstance(x, unreal.Transform)][0]
                inst.append(xform(t))
            row["instances"] = inst
            row["custom_floats"] = quiet(lambda: int(c.get_editor_property("num_custom_data_floats")), 0)
            if row["custom_floats"]:
                row["custom_data"] = quiet(lambda: [round(x, 5) for x in c.get_editor_property("per_instance_sm_custom_data")], [])
    elif isinstance(c, unreal.PrimitiveComponent) and not isinstance(c, unreal.ShapeComponent):
        # procedural meshes (the ice, the boards, the glass), skeletal meshes, text, niagara: what they wear and how big
        row["materials"] = quiet(lambda: [material_row(c.get_material(i)) for i in range(c.get_num_materials())], [])
        b = quiet(lambda: unreal.SystemLibrary.get_component_bounds(c))
        if b is not None:
            row["bounds_cm"] = {"origin": conv(b[0]), "extent": conv(b[1])}
        for k in ("cast_shadow", "render_custom_depth", "custom_depth_stencil_value", "translucency_sort_priority"):
            v = quiet(lambda k=k: c.get_editor_property(k))
            if v is not None:
                row[k] = conv(v)
        if isinstance(c, unreal.SkeletalMeshComponent):
            row["skeletal_mesh"] = quiet(lambda: c.get_skeletal_mesh_asset().get_path_name(), "")
    if isinstance(c, (unreal.LightComponentBase, unreal.ExponentialHeightFogComponent, unreal.DecalComponent,
                      unreal.SkyAtmosphereComponent)):
        p = props(c)
        for k in LIGHT_SKIP:
            p.pop(k, None)
        row["props"] = p
    if isinstance(c, unreal.PostProcessComponent):
        row["post"] = post_row(c.get_editor_property("settings"))
        for k in ("blend_weight", "priority", "unbound", "enabled", "blend_radius"):
            row[k] = conv(quiet(lambda k=k: c.get_editor_property(k)))
    return row


def post_row(settings):
    out = {}
    for name in dir(type(settings)):
        if not name.startswith("override_"):
            continue
        try:
            on = settings.get_editor_property(name)
        except Exception:  # noqa: BLE001
            continue
        if on:
            key = name[len("override_"):]
            out[key] = conv(quiet(lambda key=key: settings.get_editor_property(key)))
    out["weighted_blendables"] = conv(quiet(lambda: settings.get_editor_property("weighted_blendables")))
    return out


def dump_world(gw):
    world = {"schema": "tl.arena.world/1", "world": gw.get_path_name(), "actors": []}
    actors = unreal.GameplayStatics.get_all_actors_of_class(gw, unreal.Actor)
    log("actors %d" % len(actors))
    def actor_row(a):
        row = {"class": a.get_class().get_name(), "name": a.get_name(),
               "label": quiet(lambda: a.get_actor_label(), ""), "package": a.get_outermost().get_path_name(),
               "world": xform(a.get_actor_transform()), "hidden": bool(quiet(lambda: a.is_hidden(), False))}
        comps = attempt("components " + a.get_name(), lambda: list(a.get_components_by_class(unreal.ActorComponent)), [])
        rows = []
        for c in comps:
            r = attempt("component %s.%s" % (a.get_name(), c.get_name()), lambda c=c: component_row(c))
            if r is not None:
                rows.append(r)
        row["components"] = rows
        if isinstance(a, unreal.PostProcessVolume):
            row["post"] = attempt("post volume", lambda: post_row(a.get_editor_property("settings")))
            for k in ("blend_weight", "priority", "unbound", "enabled", "blend_radius"):
                row[k] = conv(quiet(lambda k=k: a.get_editor_property(k)))
        return row
    for a in actors:
        r = attempt("actor " + a.get_name(), lambda a=a: actor_row(a))
        if r is not None:
            world["actors"].append(r)
    # the blendable materials of the post-process chains, and the parameter collections the look reads
    for path in ("/JamAssets/Arena/MPC_Crowd", "/JamAssets/Look/MPC_Look"):
        mpc = quiet(lambda: unreal.load_asset(path))
        if mpc is None:
            continue

        def mpc_row(mpc=mpc):
            out = {"scalars": {}, "vectors": {}}
            for p in mpc.get_editor_property("scalar_parameters"):
                n = p.get_editor_property("parameter_name")
                out["scalars"][str(n)] = {"default": round(p.get_editor_property("default_value"), 6),
                                          "now": round(unreal.MaterialLibrary.get_scalar_parameter_value(gw, mpc, n), 6)}
            for p in mpc.get_editor_property("vector_parameters"):
                n = p.get_editor_property("parameter_name")
                out["vectors"][str(n)] = {"default": conv(p.get_editor_property("default_value")),
                                          "now": conv(unreal.MaterialLibrary.get_vector_parameter_value(gw, mpc, n))}
            return out
        world.setdefault("collections", {})[path] = attempt("mpc " + path, mpc_row)
    return world


def export_assets():
    def gltf_options():
        o = unreal.GLTFExportOptions()
        sets = {
            "export_uniform_scale": 0.01, "export_preview_mesh": False, "export_vertex_colors": True,
            "export_vertex_skin_weights": False, "export_animation_sequences": False, "export_level_sequences": False,
            "bake_material_inputs": unreal.GLTFMaterialBakeMode.DISABLED,
            "texture_image_format": unreal.GLTFTextureImageFormat.NONE,
            "export_proxy_materials": False, "export_unlit_materials": False, "export_clear_coat_materials": False,
            "export_cloth_materials": False, "export_thin_translucent_materials": False,
            "export_specular_glossiness_materials": False, "export_emissive_strength": False,
            "use_mesh_quantization": False, "export_cameras": False, "export_lights": False, "default_level_of_detail": 0,
        }
        for k, v in sets.items():
            try:
                o.set_editor_property(k, v)
            except Exception as e:  # noqa: BLE001
                log("option %s not set: %s" % (k, e))
        return o
    done = 0
    for path, row in meshes.items():
        sm = mesh_objs[path]
        fn = os.path.join(OUT, "meshes", row["name"] + ".glb")
        attempt("gltf " + path, lambda: unreal.GLTFExporter.export_to_gltf(sm, fn, gltf_options(), set()))
        row["glb"] = os.path.isfile(fn)
        done += 1 if row["glb"] else 0
    note("meshes %d seen, %d written" % (len(meshes), done))

    def export(obj, fn):
        task = unreal.AssetExportTask()
        task.object = obj
        task.filename = fn
        task.automated = True
        task.replace_identical = True
        task.prompt = False
        return unreal.Exporter.run_asset_export_task(task)
    tex_rows = {}
    for path, t in textures.items():
        fn = os.path.join(OUT, "textures", t.get_name() + ".png")
        ok = attempt("texture " + path, lambda: export(t, fn), False)
        tex_rows[path] = {"class": t.get_class().get_name(), "png": bool(ok) and os.path.isfile(fn),
                          "size": [quiet(lambda: t.blueprint_get_size_x(), 0), quiet(lambda: t.blueprint_get_size_y(), 0)],
                          "srgb": conv(quiet(lambda: t.get_editor_property("srgb")))}
    note("textures %d seen, %d written" % (len(textures), sum(1 for r in tex_rows.values() if r["png"])))
    for path, m in masters.items():
        fn = os.path.join(OUT, "masters", m.get_name() + ".t3d")
        attempt("master " + path, lambda: export(m, fn), False)
    note("masters %d seen, %d written" % (len(masters), len([f for f in os.listdir(os.path.join(OUT, "masters"))])))
    return tex_rows


class Run:
    def __init__(self):
        self.tick = 0
        self.stage = "wait_editor"
        self.handle = None
        self.gw = None
        self.shot = -1
        self.wait = 0
        self.shots = []
        self.done = False

    def start_play(self):
        def fixed():   # fixed 60 Hz, so an editor in the background still steps a frame a tick
            eng = unreal.find_object(None, "/Engine/Transient.UnrealEdEngine_0")
            eng.set_editor_property("bUseFixedFrameRate", True)
            eng.set_editor_property("FixedFrameRate", 60.0)
        attempt("fixed frame rate", fixed)
        ew = unreal.get_editor_subsystem(unreal.UnrealEditorSubsystem).get_editor_world()
        note("editor world %s" % ew.get_path_name())
        # the capture actor is spawned in the editor world and found again, by its label, as the game world's copy
        eas = unreal.get_editor_subsystem(unreal.EditorActorSubsystem)
        cam = eas.spawn_actor_from_class(unreal.SceneCapture2D, unreal.Vector(0, 0, 500), unreal.Rotator(0, 0, 0))
        cam.set_actor_label("TLArena_Cam")
        unreal.get_editor_subsystem(unreal.LevelEditorSubsystem).editor_request_begin_play()

    def setup_capture(self):
        gw = self.gw
        self.cam = None
        for a in unreal.GameplayStatics.get_all_actors_of_class(gw, unreal.SceneCapture2D):
            if a.get_actor_label() == "TLArena_Cam":
                self.cam = a
        cc = self.cam.capture_component2d
        cc.set_editor_property("capture_source", unreal.SceneCaptureSource.SCS_FINAL_COLOR_LDR)
        cc.set_editor_property("capture_every_frame", False)
        cc.set_editor_property("capture_on_movement", False)
        self.rt = unreal.RenderingLibrary.create_render_target2d(gw, PX_W, PX_H, unreal.TextureRenderTargetFormat.RTF_RGBA8)
        cc.set_editor_property("texture_target", self.rt)

    def place(self, shot):
        p = shot["pos_m"]
        self.cam.set_actor_location(unreal.Vector(p[0] * 100.0, p[1] * 100.0, p[2] * 100.0), False, False)
        self.cam.set_actor_rotation(unreal.Rotator(roll=0.0, pitch=float(shot["pitch"]), yaw=float(shot["yaw"])), False)
        self.cam.capture_component2d.set_editor_property("fov_angle", float(shot.get("hfov", 70.0)))

    def grab(self, shot):
        name = shot["name"] + ".png"
        self.cam.capture_component2d.capture_scene()
        unreal.RenderingLibrary.export_render_target(self.gw, self.rt, os.path.join(OUT, "shots"), name)
        row = dict(shot)
        row["file"] = name
        row["cam_world"] = xform(self.cam.get_actor_transform())
        self.shots.append(row)
        log("shot " + name)

    def on_tick(self, dt):
        if self.done:
            return
        try:
            self.tick += 1
            ues = unreal.get_editor_subsystem(unreal.UnrealEditorSubsystem)
            if self.stage == "wait_editor":
                if self.tick >= 180 and self.tick % 30 == 0 and ues is not None and ues.get_editor_world() is not None:
                    self.start_play()
                    self.stage = "wait_game"
                    self.tick = 0
            elif self.stage == "wait_game":
                gw = ues.get_game_world()
                if gw is not None:
                    self.gw = gw
                    note("game world %s" % gw.get_path_name())
                    self.stage = "play"
                    self.tick = 0
                elif self.tick > 3600:
                    note("FAIL no game world after 3600 ticks")
                    self.finish()
            elif self.stage == "play":
                if self.tick >= PLAY_TICKS:
                    world = attempt("dump world", lambda: dump_world(self.gw), {})
                    self.world = world
                    with open(os.path.join(OUT, "world.json"), "w", encoding="utf-8") as f:
                        json.dump(world, f, separators=(",", ":"))
                    note("world written: %d actors" % len(world.get("actors", [])))
                    self.stage = "shots" if SHOTS else "assets"
                    if SHOTS:
                        attempt("capture setup", self.setup_capture)
            elif self.stage == "shots":
                if self.wait > 0:
                    self.wait -= 1
                    if self.wait == 0:
                        attempt("grab", lambda: self.grab(SHOTS[self.shot]))
                    return
                self.shot += 1
                if self.shot >= len(SHOTS):
                    self.stage = "assets"
                    return
                attempt("place", lambda: self.place(SHOTS[self.shot]))
                self.wait = SHOT_WAIT
            elif self.stage == "assets":
                tex_rows = attempt("assets", export_assets, {})
                with open(os.path.join(OUT, "materials.json"), "w", encoding="utf-8") as f:
                    json.dump({"schema": "tl.arena.materials/1", "materials": materials, "meshes": meshes,
                               "textures": tex_rows, "shots": self.shots, "notes": notes}, f, indent=1)
                self.finish()
        except Exception:  # noqa: BLE001
            note("FAIL tick: " + traceback.format_exc())
            self.finish()

    def finish(self):
        self.done = True
        log("TLARENA_END actors=%d meshes=%d materials=%d textures=%d shots=%d" % (
            len(getattr(self, "world", {}).get("actors", [])), len(meshes), len(materials), len(textures), len(self.shots)))
        unreal.unregister_slate_post_tick_callback(self.handle)
        attempt("end play", lambda: unreal.get_editor_subsystem(unreal.LevelEditorSubsystem).editor_request_end_play())
        LOG.close()
        unreal.SystemLibrary.quit_editor()


RUN = Run()
RUN.handle = unreal.register_slate_post_tick_callback(RUN.on_tick)
log("registered, %d shots" % len(SHOTS))
