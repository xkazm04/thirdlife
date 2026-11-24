# Runs INSIDE the Unreal editor (UE 5.9, with sound: no -nosound) on a copy of the thirdjam project, started by the
# copy's start-up script as export_arena.py is (Content/Python/init_unreal.py runs $TL_REF_SCRIPT):
#   UnrealEditor.exe <copy>/ThirdJam.uproject -unattended -nosplash -Multiprocess
# Environment: TL_RENDER_OUT = output folder, TL_RENDER_JOBS = a JSON list from audio_jobs.py:
#   [{"file": "goal_v0_s100_t0", "sound": "/JamAssets/Audio/MS_goal", "strength": 1.0, "variant": 0, "seconds": 5.2}, ...]
# thirdjam's event sounds are MetaSound graphs, more than half of them synthesised (oscillators, noise, envelopes,
# filters): the sound of an event is what Unreal's audio engine renders for it. This plays each one alone in a quiet
# level exactly as UJamEffectsBinder::HandleEvent does (EffectsBinder.cpp:474-489: spawn, then the float parameters
# Strength and Variant before the first render) and records the main submix to
# <project>/Saved/BouncedWavFiles/tlrender/<file>.wav
# (UAudioMixerBlueprintLibrary::StartRecordingOutput / StopRecordingOutput). Real time: a render takes its seconds.
# The recording starts LEAD seconds before the sound is spawned; render.json keeps, per file, the lead measured on
# the wall clock (the audio thread adds some milliseconds of its own: a file's onset is good to about a frame).
# Nothing is saved to the project; the editor quits itself when the list is done.
import json
import os
import time
import traceback

import unreal

OUT = os.environ["TL_RENDER_OUT"]
JOBS = json.load(open(os.environ["TL_RENDER_JOBS"], encoding="utf-8"))
LEAD = 0.25
# TL_RENDER_CLOCK=ticks: the editor runs with -deterministicaudio (Unreal's non-realtime audio renderer: nothing goes to
# the sound card, the audio is rendered with the engine's ticks) at a fixed 60 ticks a second, and time is counted in
# ticks. Default: the wall clock, real time, through the sound card.
TICKS = os.environ.get("TL_RENDER_CLOCK", "wall") == "ticks"
# Unreal writes a recording only under its own bounce folder: <project>/Saved/BouncedWavFiles/<BOUNCE>/<file>.wav
BOUNCE = os.environ.get("TL_RENDER_BOUNCE", "tlrender")
BOUNCE_DIR = os.path.join(unreal.Paths.convert_relative_path_to_full(unreal.Paths.project_saved_dir()), "BouncedWavFiles", BOUNCE)
MIXER = getattr(unreal, "AudioMixerLibrary", None) or getattr(unreal, "AudioMixerBlueprintLibrary")
os.makedirs(OUT, exist_ok=True)
LOG = open(os.path.join(OUT, "render.log"), "a", encoding="utf-8")
rep = {"schema": "tl.arena.render/1", "lead_s": LEAD, "files": {}, "notes": []}
if os.path.isfile(os.path.join(OUT, "render.json")):          # a run that was cut short keeps what it had
    rep["files"] = json.load(open(os.path.join(OUT, "render.json"), encoding="utf-8")).get("files", {})


def log(msg):
    LOG.write(msg + "\n")
    LOG.flush()
    unreal.log("TLRENDER " + msg)


def note(msg):
    rep["notes"].append(msg)
    log(msg)


def attempt(label, fn, default=None):
    try:
        return fn()
    except Exception as e:  # noqa: BLE001
        note("FAIL %s: %s" % (label, "".join(traceback.format_exception_only(type(e), e)).strip()[:300]))
        return default


class Run:
    def __init__(self):
        self.tick = 0
        self.stage = "wait_editor"
        self.handle = None
        self.gw = None
        self.i = -1
        self.t0 = 0.0
        self.t_spawn = 0.0
        self.phase = ""
        self.sounds = {}
        self.done = False
        self.comp = None

    def start_play(self):
        if TICKS:
            def fixed():
                eng = unreal.find_object(None, "/Engine/Transient.UnrealEdEngine_0")
                eng.set_editor_property("bUseFixedFrameRate", True)
                eng.set_editor_property("FixedFrameRate", 60.0)
            attempt("fixed frame rate", fixed)
        les = unreal.get_editor_subsystem(unreal.LevelEditorSubsystem)
        ok = attempt("quiet level", lambda: les.load_level("/Engine/Maps/Entry"), False)
        ew = unreal.get_editor_subsystem(unreal.UnrealEditorSubsystem).get_editor_world()
        note("level %s loaded=%s" % (ew.get_path_name(), ok))
        attempt("plain game mode", lambda: ew.get_world_settings().set_editor_property("default_game_mode", unreal.GameModeBase))
        les.editor_request_begin_play()

    def on_tick(self, dt):
        if self.done:
            return
        try:
            self.tick += 1
            ues = unreal.get_editor_subsystem(unreal.UnrealEditorSubsystem)
            now = self.tick / 60.0 if TICKS else time.monotonic()
            if self.stage == "wait_editor":
                if self.tick >= 180 and self.tick % 30 == 0 and ues is not None and ues.get_editor_world() is not None:
                    self.start_play()
                    self.stage = "wait_game"
                    self.t0 = now
            elif self.stage == "wait_game":
                gw = ues.get_game_world()
                if gw is not None and now - self.t0 > 3.0:
                    self.gw = gw
                    note("game world %s" % gw.get_path_name())
                    self.stage = "jobs"
                    self.phase = "next"
                elif now - self.t0 > 120.0:
                    note("FAIL no game world after 120 s")
                    self.finish()
            elif self.stage == "jobs":
                self.job(now)
        except Exception:  # noqa: BLE001
            note("FAIL tick: " + traceback.format_exc())
            self.finish()

    def job(self, now):
        if self.phase == "next":
            self.i += 1
            if self.i >= len(JOBS):
                self.finish()
                return
            j = JOBS[self.i]
            if os.path.isfile(os.path.join(BOUNCE_DIR, j["file"] + ".wav")):
                return                      # a run that was cut short goes on where it stopped
            if j["sound"] not in self.sounds:
                self.sounds[j["sound"]] = attempt("load " + j["sound"], lambda: unreal.load_asset(j["sound"]))
            if self.sounds[j["sound"]] is None:
                return
            MIXER.start_recording_output(self.gw, float(j["seconds"]) + LEAD + 0.5)
            self.t0 = now
            self.phase = "lead"
        elif self.phase == "lead":
            if now - self.t0 >= LEAD:
                j = JOBS[self.i]
                self.comp = unreal.GameplayStatics.spawn_sound2d(self.gw, self.sounds[j["sound"]])
                if self.comp is not None:
                    self.comp.set_float_parameter("Strength", float(j.get("strength", 0.0)))
                    self.comp.set_float_parameter("Variant", float(j.get("variant", 0.0)))
                    for pk, pv in j.get("params", {}).items():      # a held sound's own inputs (Speed, Level), for calibration
                        self.comp.set_float_parameter(pk, float(pv))
                self.t_spawn = now
                self.phase = "play"
        elif self.phase == "play":
            j = JOBS[self.i]
            if now - self.t_spawn >= float(j["seconds"]):
                MIXER.stop_recording_output(self.gw, unreal.AudioRecordingExportType.WAV_FILE, j["file"], BOUNCE)
                if self.comp is not None:
                    attempt("stop", lambda: self.comp.stop())
                row = dict(j)
                row["lead_s"] = round(self.t_spawn - self.t0, 4)
                rep["files"][j["file"]] = row
                if self.i % 20 == 0:
                    log("render %d / %d %s" % (self.i + 1, len(JOBS), j["file"]))
                    self.save()
                self.t0 = now
                self.phase = "gap"
        elif self.phase == "gap":
            if now - self.t0 >= 0.2:            # the file is written and the voice is gone before the next one starts
                self.phase = "next"

    def save(self):
        with open(os.path.join(OUT, "render.json"), "w", encoding="utf-8") as f:
            json.dump(rep, f, indent=0)

    def finish(self):
        self.done = True
        self.save()
        log("TLRENDER_END asked=%d done=%d" % (len(JOBS), len(rep["files"])))
        unreal.unregister_slate_post_tick_callback(self.handle)
        attempt("end play", lambda: unreal.get_editor_subsystem(unreal.LevelEditorSubsystem).editor_request_end_play())
        LOG.close()
        unreal.SystemLibrary.quit_editor()


RUN = Run()
RUN.handle = unreal.register_slate_post_tick_callback(RUN.on_tick)
log("registered, %d jobs" % len(JOBS))
