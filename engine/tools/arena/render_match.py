# Runs INSIDE the Unreal editor on a copy of the thirdjam project, started as render_audio.py is, with
# -deterministicaudio (nothing reaches the sound card; the audio is rendered with the engine's ticks):
#   UnrealEditor.exe <copy>/ThirdJam.uproject /Game/Maps/Rink -unattended -nosplash -Multiprocess -deterministicaudio
#       -cut=hockey.regular -abslog=<out>/editor.log
# Environment: TL_MATCH_OUT = output folder, TL_MATCH_SECONDS = seconds to record (default 75),
#              TL_MATCH_VOICE = 0 mutes the commentator's sound class (default 1: as the game ships).
# thirdjam's own match with its own sound: the game is played in the editor by its measured hand (jam.ScriptHuman 2)
# at a fixed 60 ticks a second and the main submix is recorded from the first tick of play to
# <project>/Saved/BouncedWavFiles/tlmatch/match.wav. The editor's log carries the game's own event lines
# (JAMEVENT <name> who= where= strength= frame= kind=), which is the event list the recording is read against.
# match.json keeps the tick the recording started at. Nothing is saved; the editor quits itself.
import json
import os
import traceback

import unreal

OUT = os.environ["TL_MATCH_OUT"]
SECONDS = float(os.environ.get("TL_MATCH_SECONDS", "75"))
VOICE = os.environ.get("TL_MATCH_VOICE", "1") != "0"
MIXER = getattr(unreal, "AudioMixerLibrary", None) or getattr(unreal, "AudioMixerBlueprintLibrary")
os.makedirs(OUT, exist_ok=True)
LOG = open(os.path.join(OUT, "match.log"), "a", encoding="utf-8")
rep = {"schema": "tl.arena.match/1", "seconds": SECONDS, "voice": VOICE, "notes": []}


def log(msg):
    LOG.write(msg + "\n")
    LOG.flush()
    unreal.log("TLMATCH " + msg)


def attempt(label, fn, default=None):
    try:
        return fn()
    except Exception as e:  # noqa: BLE001
        rep["notes"].append("FAIL %s: %s" % (label, "".join(traceback.format_exception_only(type(e), e)).strip()[:300]))
        log(rep["notes"][-1])
        return default


class Run:
    def __init__(self):
        self.tick = 0
        self.stage = "wait_editor"
        self.handle = None
        self.gw = None
        self.t0 = 0
        self.done = False

    def on_tick(self, dt):
        if self.done:
            return
        try:
            self.tick += 1
            ues = unreal.get_editor_subsystem(unreal.UnrealEditorSubsystem)
            if self.stage == "wait_editor":
                if self.tick >= 180 and self.tick % 30 == 0 and ues is not None and ues.get_editor_world() is not None:
                    def fixed():
                        eng = unreal.find_object(None, "/Engine/Transient.UnrealEdEngine_0")
                        eng.set_editor_property("bUseFixedFrameRate", True)
                        eng.set_editor_property("FixedFrameRate", 60.0)
                    attempt("fixed frame rate", fixed)
                    unreal.get_editor_subsystem(unreal.LevelEditorSubsystem).editor_request_begin_play()
                    self.stage = "wait_game"
                    self.t0 = self.tick
            elif self.stage == "wait_game":
                gw = ues.get_game_world()
                if gw is not None:
                    self.gw = gw
                    unreal.SystemLibrary.execute_console_command(gw, "jam.ScriptHuman 2")
                    if not VOICE:
                        def mute():
                            mix = unreal.load_asset("/JamAssets/Audio/SCM_Volume")
                            vo = unreal.load_asset("/JamAssets/Audio/SC_VO")
                            unreal.GameplayStatics.set_sound_mix_class_override(gw, mix, vo, 0.0, 1.0, 0.0, True)
                            unreal.GameplayStatics.push_sound_mix_modifier(gw, mix)
                        attempt("mute the voice class", mute)
                    MIXER.start_recording_output(gw, SECONDS + 1.0)
                    rep["record_start_tick"] = self.tick
                    log("TLMATCH_RECORD_START tick=%d world=%s" % (self.tick, gw.get_path_name()))
                    self.stage = "record"
                    self.t0 = self.tick
                elif self.tick - self.t0 > 3600:
                    log("FAIL no game world")
                    self.finish()
            elif self.stage == "record":
                if self.tick - self.t0 >= int(SECONDS * 60.0):
                    MIXER.stop_recording_output(self.gw, unreal.AudioRecordingExportType.WAV_FILE, "match", "tlmatch")
                    rep["record_ticks"] = self.tick - self.t0
                    log("TLMATCH_RECORD_END ticks=%d" % (self.tick - self.t0))
                    self.stage = "tail"
                    self.t0 = self.tick
            elif self.stage == "tail":
                if self.tick - self.t0 >= 30:
                    self.finish()
        except Exception:  # noqa: BLE001
            log("FAIL tick: " + traceback.format_exc())
            self.finish()

    def finish(self):
        self.done = True
        with open(os.path.join(OUT, "match.json"), "w", encoding="utf-8") as f:
            json.dump(rep, f, indent=1)
        unreal.unregister_slate_post_tick_callback(self.handle)
        attempt("end play", lambda: unreal.get_editor_subsystem(unreal.LevelEditorSubsystem).editor_request_end_play())
        LOG.close()
        unreal.SystemLibrary.quit_editor()


RUN = Run()
RUN.handle = unreal.register_slate_post_tick_callback(RUN.on_tick)
log("registered, %.0f s" % SECONDS)
