# Runs INSIDE the Unreal editor (UE 5.9, with a GPU) on a copy of the thirdjam project, started by the copy's own
# start-up script (see reference_capture.py):   TL_REF_SCRIPT=<this file>  UnrealEditor.exe <copy>/ThirdJam.uproject
#   -unattended -nosplash -nosound -Multiprocess
# Environment: TL_ORACLE_CALLS = a call list (JSON, written by a gym: engine/cores/rink/view/figure_gym.gd writes
#              schema tl.skater.calls/1, one skater; verb_gym.gd writes /2, every skater of the match),
#              TL_ORACLE_OUT = folder, TL_ORACLE_STILLS = "cam:every[,cam:every]" (default "three:3"),
#              TL_ORACLE_WHO = the skater the cameras follow and the variables are read from (default the file's "who"),
#              TL_ORACLE_VARS = "Var,Var" of the visual, TL_ORACLE_ANIMVARS = "Var,Var" of its animation instance.
# The ORACLE of our driver port: thirdjam's shipped figure driver itself (the actor BP_SkaterVisual_TB1_P3 with its
# animation blueprint ABP_SkaterTB1_P3, its materials, under the game's clay light rig), one actor a skater, is given
# the same calls, frame by frame, that our pawns gave our figures, in a Simulate session at a fixed 60 Hz. One world
# tick a frame:
#   after tick n-1 has run: read where the figures stand (the pose that the calls of frame n-1 made), take the stills,
#   make the calls of frame n, move the actors to frame n's place (the game calls, then places: HokejGameMode.cpp:1695, :1733).
# A call "OnBusEvent" [name, me, where_x_cm, where_y_cm, strength, kind] is thirdjam's event bus: the Blueprint's own
# OnBusEvent is called with a payload whose Who is the figure's pawn's sim index when `me` (each figure hangs under a
# plain AJamSkater here, whose index is -1) and 99 otherwise.
# Writes oracle.json (schema tl.skater.oracle/2): "points" and per frame, per skater, a flat row of the points in the
# actor's own frame (centimetres, x forward, y right, z up); "debug": the asked variables of the followed skater.
# Stills <cam>_f<frame>.png (720 x 720), the gym's cameras, carried with the followed skater.
import json
import math
import os
import re
import traceback

import unreal

OUT = os.environ["TL_ORACLE_OUT"]
DATA = json.load(open(os.environ["TL_ORACLE_CALLS"], encoding="utf-8"))
FRAMES = DATA["frames"]
if "sk" not in FRAMES[0]:      # schema /1: one skater
    FRAMES = [{"f": fr["f"], "sk": [{"pos": fr["pos"], "yaw": fr["yaw"], "calls": fr["calls"]}]} for fr in FRAMES]
N = len(FRAMES[0]["sk"])
WHO = int(os.environ.get("TL_ORACLE_WHO", DATA.get("who", 0)))
DBG = int(os.environ.get("TL_ORACLE_DEBUG_WHO", WHO))      # the skater whose variables are read (default: the followed one)
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
rep = {"schema": "tl.skater.oracle/2", "visual": VISUAL, "points": list(BONES), "skaters": N, "who": WHO, "frames": [], "debug": [], "notes": [], "failed_calls": {}}


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
        pawn_cls = attempt("AJamSkater class", lambda: unreal.JamSkater)
        attached = 0
        for i in range(N):
            vis = eas.spawn_actor_from_class(cls, unreal.Vector(300.0 * i, 0, 0), unreal.Rotator(0, 0, 0))
            vis.set_actor_label("TLOracle_Visual_%02d" % i)
            # In the game the figure is on screen and its pose is ticked every frame; here only the captures see it. Set on
            # the editor world's actor, before the session: a property edit on a Blueprint actor's component rebuilds the
            # components, and done after BeginPlay that would throw away what the Blueprint set up there.
            attempt("always tick the pose", lambda: vis.get_component_by_class(unreal.SkeletalMeshComponent).set_editor_property(
                "visibility_based_anim_tick_option", unreal.VisibilityBasedAnimTickOption.ALWAYS_TICK_POSE_AND_REFRESH_BONES))
            if pawn_cls is not None:
                # the Blueprint's OnBusEvent asks its attach parent, an AJamSkater, for its sim index
                pawn = attempt("spawn AJamSkater", lambda: eas.spawn_actor_from_class(pawn_cls, unreal.Vector(300.0 * i, 0, -2000.0), unreal.Rotator(0, 0, 0)))
                if pawn is not None:
                    pawn.set_actor_label("TLOracle_Pawn_%02d" % i)
                    attempt("hide pawn", lambda: pawn.set_actor_hidden_in_game(True))
                    ok = attempt("attach", lambda: vis.attach_to_actor(pawn, "", unreal.AttachmentRule.KEEP_WORLD, unreal.AttachmentRule.KEEP_WORLD, unreal.AttachmentRule.KEEP_WORLD, False))
                    attached += 1 if ok is not None else 0
        note("figures %d, under an AJamSkater %d" % (N, attached))
        for cam, _every in STILLS:
            a = eas.spawn_actor_from_class(unreal.SceneCapture2D, unreal.Vector(0, 460, 100), unreal.Rotator(0, 0, 0))
            a.set_actor_label("TLOracle_Cam_" + cam)
        # every figure is seen every tick, as on the game's screen: SK3Fix drops the stick's correction of a figure that
        # was not rendered in the last 0.2 s (WasRecentlyRendered). Measured: without this the far skaters' sticks jump.
        a = eas.spawn_actor_from_class(unreal.SceneCapture2D, unreal.Vector(0, 0, 4500), unreal.Rotator(0, -90, 0))
        a.set_actor_label("TLOracle_Seer")
        if DATA.get("rink"):
            # thirdjam's rink actor, for the falls' wall rules ([FindRink] reads the bounds of its "Ice" mesh)
            rk = attempt("spawn ARinkActor", lambda: eas.spawn_actor_from_class(unreal.RinkActor, unreal.Vector(0, 0, 0), unreal.Rotator(0, 0, 0)))
            if rk is not None:
                rk.set_actor_label("TLOracle_Rink")
        if "puck" in FRAMES[0]:
            # thirdjam's puck actor, put where its game mode's puck show draws it: the figures look at it ([LookTick])
            pk = attempt("spawn AJamPuck", lambda: eas.spawn_actor_from_class(unreal.JamPuck, unreal.Vector(0, 0, 4), unreal.Rotator(0, 0, 0)))
            if pk is not None:
                pk.set_actor_label("TLOracle_Puck")
                pk.set_actor_scale3d(unreal.Vector(0.24, 0.24, 0.08))      # AJamPuck::InitPuck(0.12 m): the cylinder 2r across, 0.08 m tall
                attempt("puck material", lambda: pk.get_component_by_class(unreal.StaticMeshComponent).set_material(0, unreal.load_asset("/JamAssets/Look/MI_Toon_Puck")))

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
        found = {}
        self.puck = None
        for a in unreal.GameplayStatics.get_all_actors_of_class(gw, unreal.Actor):
            lab = a.get_actor_label()
            if lab.startswith("TLOracle_Visual_"):
                found[int(lab[-2:])] = a
            if lab == "TLOracle_Puck":
                self.puck = a
            if lab == "TLOracle_Rink":
                # its "Ice" mesh as a plain sheet of the rink's size: ARinkActor::Build wants a cartridge's game config,
                # which Python cannot make; the Blueprint reads only the mesh's bounds (and takes width / 12 as the corner
                # radius when the ice's material gives none)
                def ice():
                    hx, hy = DATA["rink"][0], DATA["rink"][1]
                    for c in a.get_components_by_class(unreal.ProceduralMeshComponent):
                        if c.get_name() == "Ice":
                            c.create_mesh_section_linear_color(0, [unreal.Vector(-hx, -hy, -0.2), unreal.Vector(hx, -hy, -0.2), unreal.Vector(hx, hy, -0.2), unreal.Vector(-hx, hy, -0.2)],
                                                               [0, 2, 1, 0, 3, 2], [unreal.Vector(0, 0, 1)] * 4, [], [], [], [], [], [], False)
                            b = unreal.SystemLibrary.get_component_bounds(c)
                            return [round(b[1].x, 2), round(b[1].y, 2)]
                    return None
                rep["rink_ice_extent"] = attempt("rink ice", ice)
        if len(found) < N:
            return False
        self.world = gw
        self.vis = [found[i] for i in range(N)]
        self.mesh = [v.get_component_by_class(unreal.SkeletalMeshComponent) for v in self.vis]
        self.parent_ok = [attempt("parent", lambda v=v: v.get_attach_parent_actor() is not None, False) for v in self.vis]
        self.cams = {}
        for a in unreal.GameplayStatics.get_all_actors_of_class(gw, unreal.SceneCapture2D):
            lab = a.get_actor_label()
            if lab == "TLOracle_Seer":
                cc = a.capture_component2d
                cc.set_editor_property("capture_every_frame", False)
                cc.set_editor_property("capture_on_movement", False)
                cc.set_editor_property("fov_angle", 110.0)
                cc.set_editor_property("texture_target", unreal.RenderingLibrary.create_render_target2d(gw, 128, 128, unreal.TextureRenderTargetFormat.RTF_RGBA8))
                self.seer = a
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
        note("bound: %d visuals, with a parent pawn %d, cameras %s" % (len(self.vis), sum(1 for x in self.parent_ok if x), sorted(self.cams)))
        def sock(name):
            t = self.mesh[WHO].get_socket_transform(name, unreal.RelativeTransformSpace.RTS_PARENT_BONE_SPACE)
            return {"bone": str(self.mesh[WHO].get_socket_bone_name(name)), "loc": [round(t.translation.x, 5), round(t.translation.y, 5), round(t.translation.z, 5)],
                    "quat": [round(t.rotation.x, 6), round(t.rotation.y, 6), round(t.rotation.z, 6), round(t.rotation.w, 6)]}
        rep["sockets"] = {n: attempt("socket " + n, lambda n=n: sock(n)) for n in ("head_socket", "puck_socket")}
        self.place(FRAMES[0])
        self.ready = True
        return True

    def place(self, fr):
        for i, s in enumerate(fr["sk"]):
            loc = unreal.Vector(s["pos"][0] * 100.0, s["pos"][1] * 100.0, 0.0)
            self.vis[i].set_actor_location_and_rotation(loc, unreal.Rotator(0, 0, math.degrees(s["yaw"])), False, True)
        if self.puck is not None and "puck" in fr:
            self.puck.set_actor_location(unreal.Vector(fr["puck"][0] * 100.0, fr["puck"][2] * 100.0, fr["puck"][1] * 100.0), False, True)
        s = fr["sk"][WHO]
        loc = unreal.Vector(s["pos"][0] * 100.0, s["pos"][1] * 100.0, 0.0)
        for cam, (a, _rt) in self.cams.items():
            c = CAMS[cam]
            cy, sy = math.cos(s["yaw"]), math.sin(s["yaw"])

            def world(p):
                f, r, u = p[0] * 100.0, p[1] * 100.0, p[2] * 100.0
                return unreal.Vector(loc.x + f * cy - r * sy, loc.y + f * sy + r * cy, u)
            eye, tgt = world(c[0]), world(c[1])
            a.set_actor_location(eye, False, True)
            a.set_actor_rotation(unreal.MathLibrary.find_look_at_rotation(eye, tgt), True)

    def call(self, i, name, args):
        vis = self.vis[i]
        if name == "set_time_dilation":      # the pawn's hit-stop: AJamSkater::SetVisualTimeDilation (JamPawns.cpp:234)
            # by plain assignment: set_editor_property is an editor's edit, and on a Blueprint actor that rebuilds the
            # components (the mesh loses its animation instance: measured, 920 frames of a dead figure)
            def dilate():
                vis.custom_time_dilation = float(args[0])
            attempt("dilation", dilate)
            return
        if name == "SetTeam":
            args = [args[0], unreal.LinearColor(args[1][0], args[1][1], args[1][2], 1.0)]
        elif name == "UpdateMotion":
            args = [args[0], args[1], unreal.Rotator(0, 0, args[2])]
        elif name == "SetBoost":
            args = [unreal.Name(args[0]) if args[0] else unreal.Name("None")]
        elif name == "OnBusEvent":
            pl = unreal.JamEventPayload()
            pl.set_editor_property("Who", -1 if args[1] else 99)
            pl.set_editor_property("Where", unreal.Vector(args[2], args[3], 0.0))
            pl.set_editor_property("Strength", args[4])
            pl.set_editor_property("Kind", unreal.Name(args[5]) if args[5] else unreal.Name("None"))
            args = [unreal.Name(args[0]), pl]
        fn = getattr(vis, snake(name), None)
        try:
            if fn is None:
                raise AttributeError("no function " + snake(name))
            fn(*args)
        except Exception as e:  # noqa: BLE001
            if name not in rep["failed_calls"]:
                rep["failed_calls"][name] = "".join(traceback.format_exception_only(type(e), e)).strip()[:300]
                log("FAIL call %s: %s" % (name, rep["failed_calls"][name]))

    def read(self, n):
        rows = []
        for i in range(N):
            t = self.vis[i].get_actor_transform()
            flat = []
            for b in BONES:
                p = unreal.MathLibrary.inverse_transform_location(t, self.mesh[i].get_socket_location(b))
                flat += [round(p.x, 3), round(p.y, 3), round(p.z, 3)]
            rows.append(flat)
        rep["frames"].append(rows)
        if VARS or ANIMVARS:
            row = {"f": n}
            if VARS:
                row["v"] = {v: attempt("var " + v, lambda v=v: value(self.vis[DBG].get_editor_property(v))) for v in VARS}
            if ANIMVARS:
                anim = self.mesh[DBG].get_anim_instance()
                if anim is None and "no animation instance" not in rep:
                    rep["no animation instance"] = n
                    note("FAIL the followed figure has no animation instance at frame %d" % n)
                if anim is not None:
                    row["a"] = {v: attempt("animvar " + v, lambda v=v: value(anim.get_editor_property(v))) for v in ANIMVARS}
            rep["debug"].append(row)
        for cam, every in STILLS:
            if n % every == 0 and cam in self.cams:
                unreal.RenderingLibrary.export_render_target(self.world, self.cams[cam][1], OUT, "%s_f%04d.png" % (cam, n))

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
            if self.puck is not None and self.n >= 0 and FRAMES[self.n].get("puck_on", -1) >= 0:
                # AJamPuck::Tick: after the frame's animation a carried puck sits on the carrier's socket again
                sl = self.mesh[FRAMES[self.n]["puck_on"]].get_socket_location("puck_socket")
                self.puck.set_actor_location(unreal.Vector(sl.x, sl.y, FRAMES[self.n]["puck"][1] * 100.0), False, True)
            for cam, (a, _rt) in self.cams.items():
                a.capture_component2d.capture_scene()
            if getattr(self, "seer", None) is not None:
                self.seer.capture_component2d.capture_scene()
            if self.tick < WARM_TICKS:
                return
            # one frame of ours is one tick of this world. Slate can tick while the world does not (a blocking load:
            # measured, two such ticks when the first knockdown's effects came in): such a tick is not a frame.
            now = unreal.GameplayStatics.get_time_seconds(self.world)
            last = getattr(self, "last_now", None)
            if last is not None:
                steps = (now - last) * 60.0
                if steps < 0.5:
                    rep["world_stood"] = rep.get("world_stood", 0) + 1
                    return
                if steps > 1.5 and "world_jumped" not in rep:
                    rep["world_jumped"] = self.n
                    note("FAIL the world ticked %.2f frames between two of ours at frame %d" % (steps, self.n))
            self.last_now = now
            if self.n >= 0:
                self.read(self.n)
            self.n += 1
            if self.n >= len(FRAMES):
                self.finish()
                return
            fr = FRAMES[self.n]
            for i, s in enumerate(fr["sk"]):
                for name, args in s["calls"]:
                    self.call(i, name, list(args))
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
log("registered, %d frames, %d skaters" % (len(FRAMES), N))
