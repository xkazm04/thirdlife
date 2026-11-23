# Runs INSIDE the Unreal editor (UE 5.9, with a GPU) on a copy of the thirdjam project, started by the copy's own
# start-up script (see reference_capture.py):   TL_REF_SCRIPT=<this file>  UnrealEditor.exe <copy>/ThirdJam.uproject
#   -unattended -nosplash -nosound -Multiprocess
# Environment: TL_ORACLE_CALLS = a call list (JSON, written by the gym: engine/rigs/skater/gym), TL_ORACLE_OUT = folder,
#              TL_ORACLE_STILLS = "cam:every[,cam:every]" (default "three:3"), TL_ORACLE_VARS = "Var,Var" of the visual,
#              TL_ORACLE_ANIMVARS = "Var,Var" of its animation instance.
# The ORACLE of our driver port: thirdjam's shipped figure driver itself (the actor BP_SkaterVisual_TB1_P3 with its
# animation blueprint ABP_SkaterTB1_P3, its materials, under the game's clay light rig) is given the same calls, frame
# by frame, that our pawn gave our figure, in a Simulate session at a fixed 60 Hz. One world tick a frame:
#   after tick n-1 has run: read where the figure stands (the pose that the calls of frame n-1 made), take the stills,
#   make the calls of frame n, move the actor to frame n's place (the game calls, then places: HokejGameMode.cpp:1695, :1733).
# Writes oracle.json: per frame the actor's place and, in the actor's own frame (centimetres, x forward, y right, z up),
# the bones pelvis, head, hands, feet, stick_socket, the socket puck_socket, the mesh component's relative yaw, and the
# asked variables. Stills <cam>_f<frame>.png (720 x 720), the gym's cameras, carried with the actor.
import json
import math
import os
import re
import traceback

import unreal

OUT = os.environ["TL_ORACLE_OUT"]
DATA = json.load(open(os.environ["TL_ORACLE_CALLS"], encoding="utf-8"))
FRAMES = DATA["frames"]
STILLS = [(x.split(":")[0], int(x.split(":")[1])) for x in os.environ.get("TL_ORACLE_STILLS", "three:3").split(",") if x]
VARS = [v for v in os.environ.get("TL_ORACLE_VARS", "").split(",") if v]
ANIMVARS = [v for v in os.environ.get("TL_ORACLE_ANIMVARS", "").split(",") if v]
VISUAL = "/JamAssets/Skaters/BP_SkaterVisual_TB1_P3"
PX = 720
BONES = ("pelvis", "head", "hand_l", "hand_r", "foot_l", "foot_r", "stick_socket", "puck_socket", "head_socket", "spine_03", "calf_l", "calf_r")
CAMS = {   # [forward, right, up] metres of the eye, of the target, field of view: skater_gym.gd CAMS
    "side": [[0.45, 4.6, 1.0], [0.45, 0.0, 0.8], 30.0],
    "three": [[3.6, 2.8, 1.5], [0.35, 0.0, 0.8], 30.0],
    "front": [[5.0, 0.0, 1.0], [0.0, 0.0, 0.8], 30.0],
    "back": [[-3.6, -2.4, 2.0], [0.4, 0.0, 0.8], 30.0],
}
WARM_TICKS = 180

os.makedirs(OUT, exist_ok=True)
LOG = open(os.path.join(OUT, "oracle.log"), "a", encoding="utf-8")
rep = {"schema": "tl.skater.oracle/1", "visual": VISUAL, "frames": [], "notes": [], "failed_calls": {}}


def log(msg):
    LOG.write(msg + "\n")
    LOG.flush()
    unreal.log("TLORACLE " + msg)


def note(msg):
    rep["notes"].append(msg)
    log(msg)


def attempt(label, fn, default=None):
    try:
        return fn()
    except Exception as e:  # noqa: BLE001
        note("FAIL %s: %s" % (label, "".join(traceback.format_exception_only(type(e), e)).strip()[:400]))
        return default


def snake(name):
    return re.sub(r"(?<!^)(?=[A-Z])", "_", name).lower()


def value(v):
    if isinstance(v, bool) or isinstance(v, int):
        return v
    if isinstance(v, float):
        return round(v, 5)
    if isinstance(v, unreal.Rotator):
        return [round(v.roll, 4), round(v.pitch, 4), round(v.yaw, 4)]
    if isinstance(v, unreal.Vector):
        return [round(v.x, 4), round(v.y, 4), round(v.z, 4)]
    return str(v)


class Run:
    def __init__(self):
        self.tick = 0
        self.handle = None
        self.setup_done = False
        self.ready = False
        self.done = False
        self.n = -1          # the frame whose calls were made last

    def setup(self):
        les = unreal.get_editor_subsystem(unreal.LevelEditorSubsystem)
        eas = unreal.get_editor_subsystem(unreal.EditorActorSubsystem)
        note("level LR_P3_Clay loaded=%s" % attempt("load LR_P3_Clay", lambda: les.load_level("/JamAssets/Rigs/LR_P3_Clay"), False))
        world = unreal.get_editor_subsystem(unreal.UnrealEditorSubsystem).get_editor_world()
        floor = eas.spawn_actor_from_class(unreal.StaticMeshActor, unreal.Vector(0, 0, -0.5), unreal.Rotator(0, 0, 0))
        floor.static_mesh_component.set_static_mesh(unreal.load_asset("/Engine/BasicShapes/Plane"))
        floor.set_actor_scale3d(unreal.Vector(200, 200, 1))
        attempt("floor material", lambda: floor.static_mesh_component.set_material(0, unreal.load_asset("/JamAssets/Look/M_Ice")))
        cls = unreal.load_asset(VISUAL).generated_class()
        vis = eas.spawn_actor_from_class(cls, unreal.Vector(0, 0, 0), unreal.Rotator(0, 0, 0))
        vis.set_actor_label("TLOracle_Visual")
        # In the game the figure is on screen and its pose is ticked every frame; here only the captures see it. Set on
        # the editor world's actor, before the session: a property edit on a Blueprint actor's component rebuilds the
        # components, and done after BeginPlay that would throw away what the Blueprint set up there.
        attempt("always tick the pose", lambda: vis.get_component_by_class(unreal.SkeletalMeshComponent).set_editor_property(
            "visibility_based_anim_tick_option", unreal.VisibilityBasedAnimTickOption.ALWAYS_TICK_POSE_AND_REFRESH_BONES))
        for cam, _every in STILLS:
            a = eas.spawn_actor_from_class(unreal.SceneCapture2D, unreal.Vector(0, 460, 100), unreal.Rotator(0, 0, 0))
            a.set_actor_label("TLOracle_Cam_" + cam)

        def fixed():
            eng = unreal.find_object(None, "/Engine/Transient.UnrealEdEngine_0")
            eng.set_editor_property("bUseFixedFrameRate", True)
            eng.set_editor_property("FixedFrameRate", 60.0)
        attempt("fixed frame rate", fixed)
        attempt("plain game mode", lambda: world.get_world_settings().set_editor_property("default_game_mode", unreal.GameModeBase))
        les.editor_play_simulate()
        self.setup_done = True

    def bind(self):
        gw = unreal.get_editor_subsystem(unreal.UnrealEditorSubsystem).get_game_world()
        if gw is None:
            return False
        self.vis = None
        for a in unreal.GameplayStatics.get_all_actors_of_class(gw, unreal.Actor):
            if a.get_actor_label() == "TLOracle_Visual":
                self.vis = a
        if self.vis is None:
            return False
        self.world = gw
        self.mesh = self.vis.get_component_by_class(unreal.SkeletalMeshComponent)
        self.cams = {}
        for a in unreal.GameplayStatics.get_all_actors_of_class(gw, unreal.SceneCapture2D):
            lab = a.get_actor_label()
            if lab.startswith("TLOracle_Cam_"):
                cam = lab[len("TLOracle_Cam_"):]
                cc = a.capture_component2d
                cc.set_editor_property("capture_source", unreal.SceneCaptureSource.SCS_FINAL_COLOR_LDR)
                cc.set_editor_property("capture_every_frame", False)    # captured by hand every tick (on_tick): the driver asks
                                                                         # WasRecentlyRendered (SK3Fix), and the stills need it
                cc.set_editor_property("capture_on_movement", False)
                cc.set_editor_property("fov_angle", CAMS[cam][2])
                flags = []
                for name in ("DepthOfField", "MotionBlur"):
                    f = unreal.EngineShowFlagsSetting()
                    f.set_editor_property("show_flag_name", name)
                    f.set_editor_property("enabled", False)
                    flags.append(f)
                attempt("sharp", lambda: cc.set_editor_property("show_flag_settings", flags))
                rt = unreal.RenderingLibrary.create_render_target2d(gw, PX, PX, unreal.TextureRenderTargetFormat.RTF_RGBA8)
                cc.set_editor_property("texture_target", rt)
                self.cams[cam] = (a, rt)
        note("bound: visual %s, mesh %s, cameras %s" % (self.vis.get_name(), self.mesh.get_name() if self.mesh else None, sorted(self.cams)))
        self.place(FRAMES[0])
        self.ready = True
        return True

    def place(self, fr):
        loc = unreal.Vector(fr["pos"][0] * 100.0, fr["pos"][1] * 100.0, 0.0)
        yaw = math.degrees(fr["yaw"])
        self.vis.set_actor_location_and_rotation(loc, unreal.Rotator(0, 0, yaw), False, True)
        for cam, (a, _rt) in self.cams.items():
            c = CAMS[cam]
            cy, sy = math.cos(fr["yaw"]), math.sin(fr["yaw"])

            def world(p):
                f, r, u = p[0] * 100.0, p[1] * 100.0, p[2] * 100.0
                return unreal.Vector(loc.x + f * cy - r * sy, loc.y + f * sy + r * cy, u)
            eye, tgt = world(c[0]), world(c[1])
            a.set_actor_location(eye, False, True)
            a.set_actor_rotation(unreal.MathLibrary.find_look_at_rotation(eye, tgt), True)

    def call(self, name, args):
        if name == "SetTeam":
            args = [args[0], unreal.LinearColor(args[1][0], args[1][1], args[1][2], 1.0)]
        elif name == "UpdateMotion":
            args = [args[0], args[1], unreal.Rotator(0, 0, args[2])]
        elif name == "SetBoost":
            args = [unreal.Name(args[0]) if args[0] else unreal.Name("None")]
        fn = getattr(self.vis, snake(name), None)
        try:
            if fn is None:
                raise AttributeError("no function " + snake(name))
            fn(*args)
        except Exception as e:  # noqa: BLE001
            if name not in rep["failed_calls"]:
                rep["failed_calls"][name] = "".join(traceback.format_exception_only(type(e), e)).strip()[:300]
                log("FAIL call %s: %s" % (name, rep["failed_calls"][name]))

    def read(self, n):
        fr = FRAMES[n]
        t = self.vis.get_actor_transform()
        row = {"f": n}
        for b in BONES:
            p = unreal.MathLibrary.inverse_transform_location(t, self.mesh.get_socket_location(b))
            row[b] = [round(p.x, 3), round(p.y, 3), round(p.z, 3)]
        row["mesh_yaw"] = round(self.mesh.get_relative_rotation().yaw if hasattr(self.mesh, "get_relative_rotation") else self.mesh.get_editor_property("relative_rotation").yaw, 4)
        if VARS:
            row["v"] = {v: attempt("var " + v, lambda v=v: value(self.vis.get_editor_property(v))) for v in VARS}
        if ANIMVARS:
            anim = self.mesh.get_anim_instance()
            row["a"] = {v: attempt("animvar " + v, lambda v=v: value(anim.get_editor_property(v))) for v in ANIMVARS}
        rep["frames"].append(row)
        for cam, every in STILLS:
            if n % every == 0 and cam in self.cams:
                unreal.RenderingLibrary.export_render_target(self.world, self.cams[cam][1], OUT, "%s_f%04d.png" % (cam, n))
        del fr

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
                for cam, (a, _rt) in self.cams.items():
                    a.capture_component2d.capture_scene()
                return
            for cam, (a, _rt) in self.cams.items():
                a.capture_component2d.capture_scene()
            if self.n >= 0:
                self.read(self.n)
            self.n += 1
            if self.n >= len(FRAMES):
                self.finish()
                return
            fr = FRAMES[self.n]
            for name, args in fr["calls"]:
                self.call(name, list(args))
            self.place(fr)
        except Exception:  # noqa: BLE001
            note("FAIL tick: " + traceback.format_exc())
            self.finish()

    def finish(self):
        self.done = True
        rep["frames_asked"] = len(FRAMES)
        rep["frames_done"] = len(rep["frames"])
        with open(os.path.join(OUT, "oracle.json"), "w", encoding="utf-8") as f:
            json.dump(rep, f, separators=(",", ":"))
        log("TLORACLE_END asked=%d done=%d failed_calls=%s" % (len(FRAMES), len(rep["frames"]), sorted(rep["failed_calls"])))
        LOG.close()
        unreal.unregister_slate_post_tick_callback(self.handle)
        attempt("end simulate", lambda: unreal.get_editor_subsystem(unreal.LevelEditorSubsystem).editor_request_end_play())
        unreal.SystemLibrary.quit_editor()


RUN = Run()
RUN.handle = unreal.register_slate_post_tick_callback(RUN.on_tick)
log("registered, %d frames" % len(FRAMES))
