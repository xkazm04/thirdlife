# Runs INSIDE the Unreal editor (UE 5.9, with a GPU) on a copy of the thirdjam project. It needs editor ticks, and
# -ExecutePythonScript quits the editor as soon as the script returns, so it is started by the copy's own start-up
# script: <copy>/Content/Python/init_unreal.py holding
#   import os
#   if os.environ.get("TL_REF_SCRIPT"): exec(open(os.environ["TL_REF_SCRIPT"], encoding="utf-8").read())
# and then   UnrealEditor.exe <copy>/ThirdJam.uproject -unattended -nosplash -nosound -Multiprocess
# Environment: TL_REF_OUT = output folder, TL_REF_SHOTS = a JSON file: [{"clip": "Stride" | "rest", "key": 0, "cam": "side"}, ...]
# thirdjam's own skater (SK_SkaterTB1_P3 with its own material instances, under the game's clay light rig LR_P3_Clay),
# posed from one clip at one key, seen by the four cameras of engine/rigs/skater/gym/skater_gym.gd. One PNG a shot
# (<clip>_k<key>_<cam>.png, 720 x 720) and reference.json: per shot where Unreal put the pelvis, the hands, the feet,
# the stick bone and the puck socket (centimetres, Unreal's axes), so the Godot pose can be held to it.
# The figure is posed in a Simulate session (as thirdjam's own lab did, tools/p4/ue_capture.py): the skeletal meshes of
# the editor world are not refreshed on every tick of an editor that is not in front (seen: 21 shots in a row kept the
# pose of the shot before them, and a whole run stayed at the rest pose); those of a game world are.
# Nothing is saved to the project; the editor quits itself when the list is done.
import json
import os
import traceback

import unreal

OUT = os.environ["TL_REF_OUT"]
SHOTS = json.load(open(os.environ["TL_REF_SHOTS"], encoding="utf-8"))
PKG = "/JamAssets/Skaters/"
PREFIX = "AS_SkaterTB1_P3_"
PX = 720
# [forward, right, up] metres of the eye, of the target, field of view in degrees: the same numbers as skater_gym.gd CAMS
CAMS = {
    "side": [[0.45, 4.6, 1.0], [0.45, 0.0, 0.8], 30.0],
    "three": [[3.6, 2.8, 1.5], [0.35, 0.0, 0.8], 30.0],
    "front": [[5.0, 0.0, 1.0], [0.0, 0.0, 0.8], 30.0],
    "back": [[-3.6, -2.4, 2.0], [0.4, 0.0, 0.8], 30.0],
}
TEAM_LINEAR = unreal.LinearColor(0.0123, 0.0762, 0.6867, 1.0)   # #1D4ED8, the blue team (hockey.regular.cartridge.json:155)
HELMET_K = 0.75      # BP_SkaterVisual_TB1_P3 SetTeam: the helmet's TeamColour = Colour * 0.75
WAIT_TICKS = 4       # editor ticks between posing and capturing, at least
MAX_WAIT_TICKS = 240 # ... and at most: a shot is taken only when the component stands where the clip's own pose at
                     # that key says (FRESH_CM), and is marked stale if it never does
FRESH_CM = 0.1
FRESH_BONES = ("pelvis", "hand_l", "hand_r", "foot_l", "foot_r", "stick_socket")
WARM_TICKS = 240     # editor ticks before the first shot (shaders, the light rig)

os.makedirs(OUT, exist_ok=True)
LOG = open(os.path.join(OUT, "reference.log"), "a", encoding="utf-8")
rep = {"schema": "tl.skater.reference/1", "shots": [], "notes": []}


def log(msg):
    LOG.write(msg + "\n")
    LOG.flush()
    unreal.log("TLREF " + msg)


def note(msg):
    rep["notes"].append(msg)
    log(msg)


def attempt(label, fn, default=None):
    try:
        return fn()
    except Exception as e:  # noqa: BLE001
        note("FAIL %s: %s" % (label, "".join(traceback.format_exception_only(type(e), e)).strip()))
        return default


def v3(v):
    return [round(v.x, 3), round(v.y, 3), round(v.z, 3)]


class Run:
    def __init__(self):
        self.tick = 0
        self.i = -1
        self.wait = 0
        self.handle = None
        self.ready = False
        self.setup_done = False
        self.done = False
        self.want = None
        self.waited = 0

    def setup(self):
        les = unreal.get_editor_subsystem(unreal.LevelEditorSubsystem)
        eas = unreal.get_editor_subsystem(unreal.EditorActorSubsystem)
        ok = attempt("load LR_P3_Clay", lambda: les.load_level("/JamAssets/Rigs/LR_P3_Clay"), False)
        note("level LR_P3_Clay loaded=%s" % ok)
        attempt("realtime", lambda: les.editor_set_viewport_realtime(True))
        self.world = unreal.get_editor_subsystem(unreal.UnrealEditorSubsystem).get_editor_world()
        note("world %s" % self.world.get_path_name())
        # a floor to stand on: the ice is the game's rink actor, which is not in the light rig
        floor = eas.spawn_actor_from_class(unreal.StaticMeshActor, unreal.Vector(0, 0, -0.5), unreal.Rotator(0, 0, 0))
        floor.static_mesh_component.set_static_mesh(unreal.load_asset("/Engine/BasicShapes/Plane"))
        floor.set_actor_scale3d(unreal.Vector(60, 60, 1))
        attempt("floor material", lambda: floor.static_mesh_component.set_material(0, unreal.load_asset("/JamAssets/Look/M_Ice")))
        self.actor = eas.spawn_actor_from_class(unreal.SkeletalMeshActor, unreal.Vector(0, 0, 0), unreal.Rotator(0, 0, 0))
        c = self.actor.skeletal_mesh_component
        self.comp = c
        mesh = unreal.load_asset(PKG + "SK_SkaterTB1_P3")
        c.set_skeletal_mesh_asset(mesh)
        c.set_editor_property("visibility_based_anim_tick_option", unreal.VisibilityBasedAnimTickOption.ALWAYS_TICK_POSE_AND_REFRESH_BONES)
        attempt("update in editor", lambda: c.set_update_animation_in_editor(True))
        c.set_animation_mode(unreal.AnimationMode.ANIMATION_SINGLE_NODE)

        self.cam = eas.spawn_actor_from_class(unreal.SceneCapture2D, unreal.Vector(0, 460, 100), unreal.Rotator(0, 0, 0))
        self.actor.set_actor_label("TLRef_Skater")
        self.cam.set_actor_label("TLRef_Cam")
        attempt("raw against compressed", self.eval_types)

        # fixed 60 Hz, so an editor in the background still steps a frame a tick (thirdjam tools/mcp/PHYSICS.md)
        def fixed():
            eng = unreal.find_object(None, "/Engine/Transient.UnrealEdEngine_0")
            eng.set_editor_property("bUseFixedFrameRate", True)
            eng.set_editor_property("FixedFrameRate", 60.0)
        attempt("fixed frame rate", fixed)
        # the light rig alone: no game mode of the project starts a match in it
        attempt("plain game mode", lambda: self.world.get_world_settings().set_editor_property("default_game_mode", unreal.GameModeBase))
        les.editor_play_simulate()
        self.setup_done = True

    def bind(self):
        # the Simulate world's copies of the two actors
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

        def colours():
            slots = [str(m.material_slot_name) for m in mesh.materials]
            jm = c.create_dynamic_material_instance(slots.index("Jersey"))
            jm.set_vector_parameter_value("TeamColour", TEAM_LINEAR)
            hm = c.create_dynamic_material_instance(slots.index("Helmet"))
            hm.set_vector_parameter_value("TeamColour", unreal.LinearColor(TEAM_LINEAR.r * HELMET_K, TEAM_LINEAR.g * HELMET_K, TEAM_LINEAR.b * HELMET_K, 1.0))
            return slots
        note("slots %s" % attempt("team colour", colours))
        cc = cam.capture_component2d
        cc.set_editor_property("capture_source", unreal.SceneCaptureSource.SCS_FINAL_COLOR_LDR)
        cc.set_editor_property("capture_every_frame", False)
        cc.set_editor_property("capture_on_movement", False)

        # the light rig's post-process focuses at the game camera's distance: at 4.6 m the figure is out of focus
        def sharp():
            flags = []
            for name in ("DepthOfField", "MotionBlur"):
                f = unreal.EngineShowFlagsSetting()
                f.set_editor_property("show_flag_name", name)
                f.set_editor_property("enabled", False)
                flags.append(f)
            cc.set_editor_property("show_flag_settings", flags)
        attempt("depth of field off", sharp)
        self.rt = unreal.RenderingLibrary.create_render_target2d(self.world, PX, PX, unreal.TextureRenderTargetFormat.RTF_RGBA8)
        cc.set_editor_property("texture_target", self.rt)
        note("bound in the Simulate world %s" % gw.get_path_name())
        self.ready = True
        return True

    def eval_types(self):
        # the same bone at the same key through the clip's raw keys and through its compressed data
        anim = unreal.load_asset(PKG + PREFIX + "Board_Fall_Back")
        out = {}
        for label in ("RAW", "COMPRESSED", "SOURCE"):
            if not hasattr(unreal.AnimDataEvalType, label):
                continue
            opt = unreal.AnimPoseEvaluationOptions()
            opt.set_editor_property("evaluation_type", getattr(unreal.AnimDataEvalType, label))
            pose = unreal.AnimPoseExtensions.get_anim_pose_at_frame(anim, 19, opt)
            q = unreal.AnimPoseExtensions.get_bone_pose(pose, "foot_l", unreal.AnimPoseSpaces.LOCAL).rotation
            out[label] = [round(q.x, 6), round(q.y, 6), round(q.z, 6), round(q.w, 6)]
        q = unreal.AnimationLibrary.get_bone_pose_for_frame(anim, "foot_l", 19, False).rotation
        out["get_bone_pose_for_frame"] = [round(q.x, 6), round(q.y, 6), round(q.z, 6), round(q.w, 6)]
        rep["board_fall_back_k19_foot_l_local_quat"] = out
        log("eval types %s" % out)

    def pose(self, shot):
        c = self.comp
        if shot["clip"] == "rest":
            c.set_animation(None)
            attempt("ref pose", lambda: c.set_animation_mode(unreal.AnimationMode.ANIMATION_CUSTOM_MODE))
        else:
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

    def expected(self, shot):
        # the clip's own pose at the key, component space (the actor stands at the origin, unturned)
        if shot["clip"] == "rest":
            return None
        anim = unreal.load_asset(PKG + PREFIX + shot["clip"])
        pose = unreal.AnimPoseExtensions.get_anim_pose_at_frame(anim, int(shot["key"]), unreal.AnimPoseEvaluationOptions())
        return {b: unreal.AnimPoseExtensions.get_bone_pose(pose, b, unreal.AnimPoseSpaces.WORLD).translation for b in FRESH_BONES}

    def fresh(self):
        if self.want is None:
            return 0.0
        worst = 0.0
        for b, v in self.want.items():
            p = self.comp.get_socket_location(b)
            worst = max(worst, ((p.x - v.x) ** 2 + (p.y - v.y) ** 2 + (p.z - v.z) ** 2) ** 0.5)
        return worst

    def grab(self, shot):
        c = self.comp
        name = "%s_k%03d_%s.png" % (shot["clip"], int(shot["key"]), shot["cam"])
        self.cam.capture_component2d.capture_scene()
        unreal.RenderingLibrary.export_render_target(self.world, self.rt, OUT, name)
        row = dict(shot)
        row["file"] = name
        row["anim_pos_s"] = attempt("pos", lambda: round(c.get_position(), 5))
        row["waited_ticks"] = self.waited
        row["off_clip_cm"] = round(self.fresh(), 4)
        row["stale"] = row["off_clip_cm"] > FRESH_CM
        if row["stale"]:
            rep["stale"] = rep.get("stale", 0) + 1
        for b in ("pelvis", "head", "hand_l", "hand_r", "foot_l", "foot_r", "stick_socket", "puck_socket", "head_socket"):
            row[b] = attempt("socket " + b, lambda b=b: v3(c.get_socket_location(b)))
        rep["shots"].append(row)
        log("shot %s pelvis %s puck %s" % (name, row.get("pelvis"), row.get("puck_socket")))

    def on_tick(self, dt):
        if self.done:
            return
        try:
            self.tick += 1
            if not self.setup_done:
                # the start-up script runs before the editor has a world: wait for one, then some more
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
            if self.wait > 0:
                self.wait -= 1
                self.waited += 1
                if self.wait == 0:
                    if self.fresh() > FRESH_CM and self.waited < MAX_WAIT_TICKS:
                        self.wait = 1
                        return
                    self.grab(SHOTS[self.i])
                return
            self.i += 1
            if self.i >= len(SHOTS):
                self.finish()
                return
            self.pose(SHOTS[self.i])
            self.want = attempt("expected pose", lambda: self.expected(SHOTS[self.i]))
            self.wait = WAIT_TICKS
            self.waited = 0
        except Exception:  # noqa: BLE001
            note("FAIL tick: " + traceback.format_exc())
            self.finish()

    def finish(self):
        self.done = True
        rep["shots_asked"] = len(SHOTS)
        rep["shots_done"] = len(rep["shots"])
        rep["stale"] = rep.get("stale", 0)
        with open(os.path.join(OUT, "reference.json"), "w", encoding="utf-8") as f:
            json.dump(rep, f, indent=1)
        log("TLREF_END asked=%d done=%d stale=%d" % (len(SHOTS), len(rep["shots"]), rep["stale"]))
        LOG.close()
        unreal.unregister_slate_post_tick_callback(self.handle)
        attempt("end simulate", lambda: unreal.get_editor_subsystem(unreal.LevelEditorSubsystem).editor_request_end_play())
        unreal.SystemLibrary.quit_editor()


RUN = Run()
RUN.handle = unreal.register_slate_post_tick_callback(RUN.on_tick)
log("registered, %d shots" % len(SHOTS))
