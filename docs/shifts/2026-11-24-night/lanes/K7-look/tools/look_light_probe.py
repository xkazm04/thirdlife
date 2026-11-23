# Runs INSIDE the Unreal editor (UE 5.9, with a GPU) on a copy of the thirdjam project, started as look_reference.py is
# (the copy's Content/Python/init_unreal.py executes the file named by TL_REF_SCRIPT). Lane K7, round 2: WHERE DOES THE
# LIGHT ON THIRDJAM'S FIGURE COME FROM? thirdjam's own figure under its clay rig LR_P3_Clay, one pose, seen by the gym's
# cameras, drawn several times with parts of the light switched off in the scene, and read in
# scene-linear units (the HDR scene colour, before exposure and the film curve):
#   A  as the rig lights it          B  no sky light            C  no Lumen global illumination
#   D  neither                       E  neither, and no shadows (the spots alone, unshadowed: what our shader sums)
# Two grey cards (albedo 0.5, facing up, 2 cm over the ice, 0.9 m to either side of the figure) calibrate the units:
# under E a card must read 0.5 * lux / pi of the rig's spots.
# Environment: TL_REF_OUT = output folder, TL_REF_SHOTS = a JSON file:
#   [{"clip": "Stride", "key": 0, "cam": "back", "team": 0, "number": 7, "boxes": {"jersey": [x0, y0, x1, y1], ...}}, ...]
# (boxes in the capture's pixels: 720 x 720). Writes probe.json (per shot, per variant, per box the median linear RGB;
# the cards' boxes are found by projection) and an LDR PNG per shot and variant. Nothing is saved to the project.
import json
import math
import os
import statistics
import traceback

import unreal

OUT = os.environ["TL_REF_OUT"]
SHOTS = json.load(open(os.environ["TL_REF_SHOTS"], encoding="utf-8"))
PKG = "/JamAssets/Skaters/"
PREFIX = "AS_SkaterTB1_P3_"
PX = 720
CAMS = {
    "side": [[0.45, 4.6, 1.0], [0.45, 0.0, 0.8], 30.0],
    "three": [[3.6, 2.8, 1.5], [0.35, 0.0, 0.8], 30.0],
    "front": [[5.0, 0.0, 1.0], [0.0, 0.0, 0.8], 30.0],
    "back": [[-3.6, -2.4, 2.0], [0.4, 0.0, 0.8], 30.0],
    "top": [[-0.6, 0.0, 6.0], [0.3, 0.0, 0.0], 30.0],
}
# [name, sky light on, Lumen on, the spots' shadows on]
VARIANTS = [
    ["A", True, True, True],
    ["B", False, True, True],
    ["C", True, False, True],
    ["D", False, False, True],
    ["E", False, False, False],
]
CARDS = {"card_left": [60.0, -90.0, 2.0], "card_right": [60.0, 90.0, 2.0]}      # centimetres, Unreal's axes
CARD_ALBEDO = 0.5
HELMET_K = 0.75
SETTLE_TICKS = 40     # captures of a variant before it is read (Lumen gathers over frames)
WARM_TICKS = 240
FRESH_CM = 0.1
FRESH_BONES = ("pelvis", "hand_l", "hand_r", "foot_l", "foot_r", "stick_socket")


def lin(hex6):
    out = []
    for i in (0, 2, 4):
        c = int(hex6[i:i + 2], 16) / 255.0
        out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    return out


TEAMS = [lin("1D4ED8"), lin("E8651A")]
os.makedirs(OUT, exist_ok=True)
LOG = open(os.path.join(OUT, "probe.log"), "a", encoding="utf-8")
rep = {"schema": "tl.skater.light_probe/1", "variants": VARIANTS, "card_albedo": CARD_ALBEDO, "shots": [], "notes": []}


def log(msg):
    LOG.write(msg + "\n")
    LOG.flush()
    unreal.log("TLPROBE " + msg)


def note(msg):
    rep["notes"].append(msg)
    log(msg)


def attempt(label, fn, default=None):
    try:
        return fn()
    except Exception as e:  # noqa: BLE001
        note("FAIL %s: %s" % (label, "".join(traceback.format_exception_only(type(e), e)).strip()))
        return default


def project(cam, p_cm):
    # where a point (centimetres) lands in the square capture: Unreal's x forward, y right, z up
    eye = [c * 100.0 for c in cam[0]]
    tgt = [c * 100.0 for c in cam[1]]
    f = [tgt[i] - eye[i] for i in range(3)]
    n = math.sqrt(sum(v * v for v in f))
    f = [v / n for v in f]
    r = [-f[1], f[0], 0.0]                      # up x forward
    n = math.sqrt(sum(v * v for v in r))
    r = [v / n for v in r]
    u = [f[1] * r[2] - f[2] * r[1], f[2] * r[0] - f[0] * r[2], f[0] * r[1] - f[1] * r[0]]
    d = [p_cm[i] - eye[i] for i in range(3)]
    z = sum(d[i] * f[i] for i in range(3))
    t = math.tan(math.radians(cam[2] * 0.5))
    x = sum(d[i] * r[i] for i in range(3)) / z / t
    y = sum(d[i] * u[i] for i in range(3)) / z / t
    return [PX * 0.5 + PX * 0.5 * x, PX * 0.5 - PX * 0.5 * y]


class Run:
    def __init__(self):
        self.tick = 0
        self.i = -1
        self.v = 0
        self.settle = 0
        self.stage = "next"
        self.handle = None
        self.ready = False
        self.setup_done = False
        self.done = False
        self.want = None
        self.waited = 0
        self.row = None

    def setup(self):
        les = unreal.get_editor_subsystem(unreal.LevelEditorSubsystem)
        eas = unreal.get_editor_subsystem(unreal.EditorActorSubsystem)
        note("level LR_P3_Clay loaded=%s" % attempt("load LR_P3_Clay", lambda: les.load_level("/JamAssets/Rigs/LR_P3_Clay"), False))
        attempt("realtime", lambda: les.editor_set_viewport_realtime(True))
        self.world = unreal.get_editor_subsystem(unreal.UnrealEditorSubsystem).get_editor_world()
        floor = eas.spawn_actor_from_class(unreal.StaticMeshActor, unreal.Vector(0, 0, -0.5), unreal.Rotator(0, 0, 0))
        floor.static_mesh_component.set_static_mesh(unreal.load_asset("/Engine/BasicShapes/Plane"))
        floor.set_actor_scale3d(unreal.Vector(60, 60, 1))
        attempt("floor material", lambda: floor.static_mesh_component.set_material(0, unreal.load_asset("/JamAssets/Look/M_Ice")))
        for name, p in CARDS.items():
            card = eas.spawn_actor_from_class(unreal.StaticMeshActor, unreal.Vector(p[0], p[1], p[2]), unreal.Rotator(0, 0, 0))
            card.static_mesh_component.set_static_mesh(unreal.load_asset("/Engine/BasicShapes/Plane"))
            card.set_actor_scale3d(unreal.Vector(0.4, 0.4, 1))          # the engine's plane is 1 m: 40 cm
            card.set_actor_label("TLProbe_" + name)
            card.static_mesh_component.set_editor_property("cast_shadow", False)
        self.actor = eas.spawn_actor_from_class(unreal.SkeletalMeshActor, unreal.Vector(0, 0, 0), unreal.Rotator(0, 0, 0))
        c = self.actor.skeletal_mesh_component
        c.set_skeletal_mesh_asset(unreal.load_asset(PKG + "SK_SkaterTB1_P3"))
        c.set_editor_property("visibility_based_anim_tick_option", unreal.VisibilityBasedAnimTickOption.ALWAYS_TICK_POSE_AND_REFRESH_BONES)
        attempt("update in editor", lambda: c.set_update_animation_in_editor(True))
        c.set_animation_mode(unreal.AnimationMode.ANIMATION_SINGLE_NODE)
        self.cam = eas.spawn_actor_from_class(unreal.SceneCapture2D, unreal.Vector(0, 460, 100), unreal.Rotator(0, 0, 0))
        self.actor.set_actor_label("TLRef_Skater")
        self.cam.set_actor_label("TLRef_Cam")

        def fixed():
            eng = unreal.find_object(None, "/Engine/Transient.UnrealEdEngine_0")
            eng.set_editor_property("bUseFixedFrameRate", True)
            eng.set_editor_property("FixedFrameRate", 60.0)
        attempt("fixed frame rate", fixed)
        attempt("plain game mode", lambda: self.world.get_world_settings().set_editor_property("default_game_mode", unreal.GameModeBase))
        les.editor_play_simulate()
        self.setup_done = True

    def bind(self):
        gw = unreal.get_editor_subsystem(unreal.UnrealEditorSubsystem).get_game_world()
        if gw is None:
            return False
        actor = cam = None
        for a in unreal.GameplayStatics.get_all_actors_of_class(gw, unreal.SkeletalMeshActor):
            if a.get_actor_label() == "TLRef_Skater":
                actor = a
        for a in unreal.GameplayStatics.get_all_actors_of_class(gw, unreal.SceneCapture2D):
            if a.get_actor_label() == "TLRef_Cam":
                cam = a
        if actor is None or cam is None:
            return False
        self.world = gw
        self.actor = actor
        self.cam = cam
        c = actor.skeletal_mesh_component
        self.comp = c
        c.set_editor_property("visibility_based_anim_tick_option", unreal.VisibilityBasedAnimTickOption.ALWAYS_TICK_POSE_AND_REFRESH_BONES)
        c.set_animation_mode(unreal.AnimationMode.ANIMATION_SINGLE_NODE)
        mesh = c.get_skeletal_mesh_asset()
        slots = [str(m.material_slot_name) for m in mesh.materials]
        self.jm = c.create_dynamic_material_instance(slots.index("Jersey"))
        self.hm = c.create_dynamic_material_instance(slots.index("Helmet"))
        self.tm = c.create_dynamic_material_instance(slots.index("Trim"))

        def cards():
            n = 0
            for a in unreal.GameplayStatics.get_all_actors_of_class(gw, unreal.StaticMeshActor):
                if a.get_actor_label().startswith("TLProbe_"):
                    m = a.static_mesh_component.create_dynamic_material_instance(0, unreal.load_asset("/Engine/BasicShapes/BasicShapeMaterial"))
                    m.set_vector_parameter_value("Color", unreal.LinearColor(CARD_ALBEDO, CARD_ALBEDO, CARD_ALBEDO, 1.0))
                    m.set_scalar_parameter_value("Roughness", 1.0)
                    n += 1
            return n
        note("cards dressed %s" % attempt("cards", cards))

        def lights():
            out = {}
            for cls in (unreal.SkyLight, unreal.SpotLight, unreal.PointLight, unreal.DirectionalLight, unreal.PostProcessVolume):
                out[cls.__name__] = len(unreal.GameplayStatics.get_all_actors_of_class(gw, cls))
            return out
        note("actors %s" % attempt("lights", lights))
        cc = cam.capture_component2d
        cc.set_editor_property("capture_every_frame", False)
        cc.set_editor_property("capture_on_movement", False)
        attempt("persist", lambda: cc.set_editor_property("always_persist_rendering_state", True))
        self.rt = unreal.RenderingLibrary.create_render_target2d(self.world, PX, PX, unreal.TextureRenderTargetFormat.RTF_RGBA8)
        self.rt_hdr = unreal.RenderingLibrary.create_render_target2d(self.world, PX, PX, unreal.TextureRenderTargetFormat.RTF_RGBA16F)
        note("bound in the Simulate world %s" % gw.get_path_name())
        self.ready = True
        return True

    def flags(self):
        out = []
        for name in ["DepthOfField", "MotionBlur", "Bloom"]:
            f = unreal.EngineShowFlagsSetting()
            f.set_editor_property("show_flag_name", name)
            f.set_editor_property("enabled", False)
            out.append(f)
        self.cam.capture_component2d.set_editor_property("show_flag_settings", out)

    def light(self, variant):
        # the scene itself is changed (a show flag on the capture did not take the shadows away): the sky light's
        # intensity, the project's global illumination method (1 = Lumen, 0 = none), every spot's shadow
        name, sky, lumen, shadows = variant
        for a in unreal.GameplayStatics.get_all_actors_of_class(self.world, unreal.SkyLight):
            comp = a.get_component_by_class(unreal.SkyLightComponent)
            if not hasattr(self, "sky0"):
                self.sky0 = comp.get_editor_property("intensity")
            comp.set_intensity(self.sky0 if sky else 0.0)
        unreal.SystemLibrary.execute_console_command(self.world, "r.DynamicGlobalIlluminationMethod %d" % (1 if lumen else 0))
        n = 0
        for a in unreal.GameplayStatics.get_all_actors_of_class(self.world, unreal.SpotLight):
            comp = a.get_component_by_class(unreal.SpotLightComponent)
            if not hasattr(self, "shadow0"):
                self.shadow0 = {}
            key = a.get_path_name()
            if key not in self.shadow0:
                self.shadow0[key] = comp.get_editor_property("cast_shadows")
            comp.set_cast_shadows(bool(self.shadow0[key]) and shadows)
            n += 1 if self.shadow0[key] else 0
        log("light %s sky=%s lumen=%s shadows=%s (sky intensity %s, %d spots with shadows)" % (name, sky, lumen, shadows, getattr(self, "sky0", None), n))

    def source(self, hdr):
        cc = self.cam.capture_component2d
        cc.set_editor_property("capture_source", unreal.SceneCaptureSource.SCS_SCENE_COLOR_HDR if hdr else unreal.SceneCaptureSource.SCS_FINAL_COLOR_LDR)
        cc.set_editor_property("texture_target", self.rt_hdr if hdr else self.rt)

    def dress(self, team, number):
        t = TEAMS[max(0, min(1, team))]
        n = max(0, min(99, number))
        self.jm.set_vector_parameter_value("TeamColour", unreal.LinearColor(t[0], t[1], t[2], 1.0))
        self.hm.set_vector_parameter_value("TeamColour", unreal.LinearColor(t[0] * HELMET_K, t[1] * HELMET_K, t[2] * HELMET_K, 1.0))
        self.jm.set_scalar_parameter_value("CrestTeam", float(max(0, min(1, team))))
        for m in (self.jm, self.tm):
            m.set_scalar_parameter_value("NumberTens", float(n // 10))
            m.set_scalar_parameter_value("NumberOnes", float(n % 10))
        self.jm.set_scalar_parameter_value("NumberOn", 1.0)

    def pose(self, shot):
        c = self.comp
        self.dress(int(shot.get("team", 0)), int(shot.get("number", 7)))
        anim = unreal.load_asset(PKG + PREFIX + shot["clip"])
        c.set_animation_mode(unreal.AnimationMode.ANIMATION_SINGLE_NODE)
        c.set_animation(anim)
        c.set_play_rate(0.0)
        c.set_position(float(shot["key"]) / 60.0, False)
        cam = CAMS[shot["cam"]]
        eye = unreal.Vector(cam[0][0] * 100.0, cam[0][1] * 100.0, cam[0][2] * 100.0)
        tgt = unreal.Vector(cam[1][0] * 100.0, cam[1][1] * 100.0, cam[1][2] * 100.0)
        self.cam.set_actor_location(eye, False, False)
        self.cam.set_actor_rotation(unreal.MathLibrary.find_look_at_rotation(eye, tgt), False)
        self.cam.capture_component2d.set_editor_property("fov_angle", cam[2])
        pose = unreal.AnimPoseExtensions.get_anim_pose_at_frame(anim, int(shot["key"]), unreal.AnimPoseEvaluationOptions())
        self.want = {b: unreal.AnimPoseExtensions.get_bone_pose(pose, b, unreal.AnimPoseSpaces.WORLD).translation for b in FRESH_BONES}

    def fresh(self):
        worst = 0.0
        for b, v in self.want.items():
            p = self.comp.get_socket_location(b)
            worst = max(worst, ((p.x - v.x) ** 2 + (p.y - v.y) ** 2 + (p.z - v.z) ** 2) ** 0.5)
        return worst

    def read(self, shot, vname):
        boxes = dict(shot.get("boxes", {}))
        cam = CAMS[shot["cam"]]
        for name, p in CARDS.items():
            c = project(cam, p)
            if 12 <= c[0] <= PX - 12 and 12 <= c[1] <= PX - 12:
                boxes[name] = [int(c[0]) - 4, int(c[1]) - 2, int(c[0]) + 4, int(c[1]) + 2]
        for bone in ("head", "spine_03", "pelvis", "hand_l", "calf_l"):
            v = self.comp.get_socket_location(bone)
            c = project(cam, [v.x, v.y, v.z])
            if 12 <= c[0] <= PX - 12 and 12 <= c[1] <= PX - 12:
                boxes["bone_" + bone] = [int(c[0]) - 5, int(c[1]) - 5, int(c[0]) + 5, int(c[1]) + 5]
        self.row.setdefault("boxes_px", {})[vname] = boxes
        out = {}
        for name, b in boxes.items():
            px = unreal.RenderingLibrary.read_render_target_raw_pixel_area(self.world, self.rt_hdr, int(b[0]), int(b[1]), int(b[2]), int(b[3]))
            if px:
                out[name] = [round(statistics.median([p.r for p in px]), 5), round(statistics.median([p.g for p in px]), 5),
                             round(statistics.median([p.b for p in px]), 5), len(px)]
        log("read %s %s %s" % (shot["cam"], vname, out))
        return out

    def on_tick(self, dt):
        if self.done:
            return
        try:
            self.tick += 1
            if not self.setup_done:
                if self.tick >= 120 and self.tick % 30 == 0:
                    ues = unreal.get_editor_subsystem(unreal.UnrealEditorSubsystem)
                    if ues is not None and ues.get_editor_world() is not None:
                        self.setup()
                        self.tick = 0
                return
            if not self.ready:
                if self.tick % 30 == 0 and self.bind():
                    self.tick = 0
                elif self.tick > 3000:
                    note("FAIL no Simulate world after 3000 ticks")
                    self.finish()
                return
            if self.tick < WARM_TICKS:
                if self.tick == 10:
                    self.pose(SHOTS[0])
                return
            if self.stage == "next":
                self.i += 1
                if self.i >= len(SHOTS):
                    self.finish()
                    return
                self.pose(SHOTS[self.i])
                self.waited = 0
                self.stage = "pose"
                return
            shot = SHOTS[self.i]
            if self.stage == "pose":
                self.waited += 1
                if self.waited < 4 or (self.fresh() > FRESH_CM and self.waited < 240):
                    return
                self.row = dict(shot)
                self.row["off_clip_cm"] = round(self.fresh(), 4)
                self.row["stale"] = self.row["off_clip_cm"] > FRESH_CM
                self.row["linear"] = {}
                self.v = 0
                self.settle = 0
                self.flags()
                self.light(VARIANTS[0])
                self.source(True)
                self.stage = "settle"
                return
            if self.stage == "settle":
                self.cam.capture_component2d.capture_scene()
                self.settle += 1
                if self.settle < SETTLE_TICKS:
                    return
                vname = VARIANTS[self.v][0]
                self.row["linear"][vname] = self.read(shot, vname)
                unreal.RenderingLibrary.export_render_target(self.world, self.rt_hdr, OUT, "%s_k%03d_%s_t%d_%s.hdr" % (
                    shot["clip"], int(shot["key"]), shot["cam"], int(shot.get("team", 0)), vname))
                self.source(False)
                self.cam.capture_component2d.capture_scene()
                unreal.RenderingLibrary.export_render_target(self.world, self.rt, OUT, "%s_k%03d_%s_t%d_%s.png" % (
                    shot["clip"], int(shot["key"]), shot["cam"], int(shot.get("team", 0)), vname))
                self.v += 1
                if self.v >= len(VARIANTS):
                    rep["shots"].append(self.row)
                    self.light(VARIANTS[0])
                    self.stage = "next"
                    return
                self.light(VARIANTS[self.v])
                self.source(True)
                self.settle = 0
        except Exception:  # noqa: BLE001
            note("FAIL tick: " + traceback.format_exc())
            self.finish()

    def finish(self):
        self.done = True
        rep["shots_asked"] = len(SHOTS)
        rep["shots_done"] = len(rep["shots"])
        rep["stale"] = sum(1 for r in rep["shots"] if r.get("stale"))
        with open(os.path.join(OUT, "probe.json"), "w", encoding="utf-8") as f:
            json.dump(rep, f, indent=1)
        log("TLPROBE_END asked=%d done=%d stale=%d" % (len(SHOTS), len(rep["shots"]), rep["stale"]))
        LOG.close()
        unreal.unregister_slate_post_tick_callback(self.handle)
        attempt("end simulate", lambda: unreal.get_editor_subsystem(unreal.LevelEditorSubsystem).editor_request_end_play())
        unreal.SystemLibrary.quit_editor()


RUN = Run()
RUN.handle = unreal.register_slate_post_tick_callback(RUN.on_tick)
log("registered, %d shots" % len(SHOTS))
