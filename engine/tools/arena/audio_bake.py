#!/usr/bin/env python3
"""Step 3 of the audio bake: thirdjam's rendered event sounds and its source waves -> the core's sound files and table.
usage: python audio_bake.py <renders folder> <render.json> <export folder> <engine/cores/rink/audio>

  <renders folder>  render_audio.py's wav files (Unreal's own render of each MetaSound at a Variant and a Strength)
  <export folder>   export_audio.py's output (wav/ the source waves, audio.json, graphs.json from audio_digest.py)

Writes <out>/sfx/*.ogg (one-shots), music/, crowd/, skate/ (the held sounds' sources) and <out>/audio.json.
What is done to a render: the lead before the spawn is cut (render.json), the silent tail is cut, two equal channels
become one. Nothing else: no gain, no normalising. Then, per event and Variant, the Strength steps are compared: where
a step is the top step times a constant (the graph only scales with Strength) the step keeps no file, only that
constant ("gain": the law between steps is then a straight line and Strength stays continuous); where it is not (a
gate, a random draw, noise) it keeps its own file ("steps": the game takes the step at or below its Strength).
The held sounds are not rendered: their rules are short and are ported as rules (rink_audio.gd), their sources are:
the music loop as it is; the crowd bed through MS_crowd_bed's own low-pass at its resting cutoff (Excite 0: 3000 Hz,
Unreal's biquad, bandwidth 1 octave; thirdjam never sets Excite); the skate stride loop and carve as they are; and the
skate loop's noise layer made here as MS_skate_loop makes it (Unreal's pink noise filter over uniform white noise, its
band-pass at a reference cutoff, bandwidth 1.5 octaves; the game moves the cutoff by playing it faster or slower)."""
import json
import math
import os
import subprocess
import sys
import wave

import numpy as np

REN, RJSON, EXP, OUT = sys.argv[1:5]
SR = 48000
SILENT = 10 ** (-66 / 20.0)
NOISE_REF_HZ = 2450.0          # MS_skate_loop: cutoff 1200 + 2500 * Speed, at Speed 0.5
render = json.load(open(RJSON, encoding="utf-8"))
# a render run that was cut short and taken up again wrote its files but not all of their rows: the job list has them
# (in ticks mode the lead is the same LEAD for every file)
if os.path.isfile(os.path.join(EXP, "jobs.json")):
    for j in json.load(open(os.path.join(EXP, "jobs.json"), encoding="utf-8")):
        if j["file"] not in render["files"] and os.path.isfile(os.path.join(REN, j["file"] + ".wav")):
            render["files"][j["file"]] = dict(j, lead_s=render["lead_s"])
graphs = json.load(open(os.path.join(EXP, "graphs.json"), encoding="utf-8"))
for d in ("sfx", "music", "crowd", "skate"):
    os.makedirs(os.path.join(OUT, d), exist_ok=True)


def read(path):
    w = wave.open(path)
    assert w.getsampwidth() == 2, path
    a = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(np.float64) / 32768.0
    return a.reshape(-1, w.getnchannels()), w.getframerate()


def ogg(a, sr, rel, quality=5):
    """Float samples (frames x channels) -> an Ogg Vorbis file through ffmpeg; returns its size."""
    path = os.path.join(OUT, rel)
    pcm = (np.clip(a, -1.0, 1.0) * 32767.0).round().astype("<i2").tobytes()
    p = subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-f", "s16le", "-ar", str(sr), "-ac", str(a.shape[1]), "-i", "-",
                        "-c:a", "libvorbis", "-q:a", str(quality), path], input=pcm, capture_output=True)
    if p.returncode != 0:
        raise RuntimeError("ffmpeg: " + p.stderr.decode("utf-8", "replace")[:300])
    return os.path.getsize(path)


def biquad(x, kind, hz, bw, sr):
    """Unreal's FBiquadFilter (Engine/Source/Runtime/SignalProcessing/Private/Filter.cpp:281-330): RBJ's forms with the
    bandwidth in octaves."""
    om = 2.0 * math.pi * hz / sr
    sn, cs = math.sin(om), math.cos(om)
    al = sn * math.sinh(0.5 * math.log(2.0) * bw * om / sn)
    if kind == "low":
        b = [(1 - cs) / 2, 1 - cs, (1 - cs) / 2]
    elif kind == "high":
        b = [(1 + cs) / 2, -(1 + cs), (1 + cs) / 2]
    else:
        b = [al, 0.0, -al]
    a = [1 + al, -2 * cs, 1 - al]
    b = [v / a[0] for v in b]
    a = [v / a[0] for v in a]
    y = np.zeros_like(x)
    x1 = x2 = y1 = y2 = 0.0
    for i in range(len(x)):
        v = b[0] * x[i] + b[1] * x1 + b[2] * x2 - a[1] * y1 - a[2] * y2
        x2, x1, y2, y1 = x1, x[i], y1, v
        y[i] = v
    return y


def pink(n, seed):
    """Unreal's FPinkNoise (SignalProcessing/Private/Noise.cpp:31-62): uniform white noise in -1..1 through the 1/f
    filter of J. O. Smith's example."""
    A = (-2.494956002, 2.017265875, -0.522189400)
    B = (0.049922035, -0.095993537, 0.050612699, -0.004408786)
    x = np.random.default_rng(seed).uniform(-1.0, 1.0, n)
    y = np.zeros(n)
    xz = [0.0, 0.0, 0.0, 0.0]
    yz = [0.0, 0.0, 0.0]
    for i in range(n):
        xz = [x[i], xz[0], xz[1], xz[2]]
        v = xz[0] * B[0] + xz[1] * B[1] + xz[2] * B[2] + xz[3] * B[3] - yz[0] * A[0] - yz[1] * A[1] - yz[2] * A[2]
        yz = [v, yz[0], yz[1]]
        y[i] = v
    return y


def trim(a, sr, lead):
    a = a[int(round(lead * sr)):]
    env = np.abs(a).max(axis=1) if len(a) else np.zeros(0)
    nz = np.nonzero(env > SILENT)[0]
    if len(nz) == 0:
        return a[:0]
    a = a[:min(len(a), nz[-1] + int(0.03 * sr))]
    if a.shape[1] == 2 and np.abs(a[:, 0] - a[:, 1]).max() < 2e-4:
        a = a[:, :1]
    return a


# ---------------------------------------------------------------- the one-shots
events = {}
sizes = {"sfx": 0, "music": 0, "crowd": 0, "skate": 0}
kept = scaled = silent = 0
cut_tail = []
groups = {}
for name, row in render["files"].items():
    groups.setdefault((row["event"], int(row["variant"]), int(row["take"])), []).append(row)
for (ev, variant, take), rows in sorted(groups.items()):
    rows.sort(key=lambda r: r["strength"])
    data = {}
    for r in rows:
        path = os.path.join(REN, r["file"] + ".wav")
        if not os.path.isfile(path):
            continue
        raw, sr = read(path)
        assert sr == SR, path
        if len(raw) and np.abs(raw[-int(0.02 * sr):]).max() > 4 * SILENT:
            cut_tail.append(r["file"])
        data[r["strength"]] = trim(raw, sr, float(r.get("lead_s", render["lead_s"])))
    if not data:
        continue
    top = max(s for s in data)
    ref = data[top]
    proportional = len(ref) > 0
    gains = {}
    for s, a in data.items():
        if len(a) == 0:
            gains[s] = 0.0
            continue
        if len(ref) == 0 or a.shape[1] != ref.shape[1]:
            proportional = False
            break
        n = min(len(a), len(ref))
        x, y = ref[:n].reshape(-1), a[:n].reshape(-1)
        g = float(np.dot(x, y) / max(np.dot(x, x), 1e-20))
        resid = float(np.sum((y - g * x) ** 2) + np.sum(a[n:] ** 2)) / max(float(np.sum(a ** 2)), 1e-20)
        if resid > 1e-3 or g < 0.0:
            proportional = False
            break
        gains[s] = g
    v = events.setdefault(ev, {"variants": {}})["variants"].setdefault(str(variant), {"law": "gain" if proportional else "steps", "steps": {}})
    if not proportional:
        v["law"] = "steps"
    for s, a in sorted(data.items()):
        step = v["steps"].setdefault("%.2f" % s, [])
        if len(a) == 0:
            step.append({"file": "", "gain": 0.0})
            silent += 1
        elif proportional and s != top:
            step.append({"file": "sfx/%s_v%d_s%03d_t%d.ogg" % (ev, variant, round(top * 100), take), "gain": round(gains[s], 5)})
            scaled += 1
        else:
            rel = "sfx/%s_v%d_s%03d_t%d.ogg" % (ev, variant, round(s * 100), take)
            sizes["sfx"] += ogg(a, SR, rel)
            step.append({"file": rel, "gain": 1.0, "seconds": round(len(a) / SR, 3), "channels": int(a.shape[1]),
                         "peak": round(float(np.abs(a).max()), 4)})
            kept += 1
# a variant whose takes disagree about the law keeps files everywhere: checked by the selftest, not repaired here
for ev, e in events.items():
    g = graphs.get("MS_" + ev, {})
    e["waves"] = g.get("waves", [])
    e["inputs"] = {k: v["default"] for k, v in g.get("inputs", {}).items() if not k.startswith("UE.")}
    e["synth"] = g.get("uses", {}).get("synth", [])

# ---------------------------------------------------------------- the held sounds' sources
def source(name):
    a, sr = read(os.path.join(EXP, "wav", name + ".wav"))
    return a, sr


loops = {}
a, sr = source("MUS_MatchLoop_01")
sizes["music"] += ogg(a, sr, "music/MUS_MatchLoop_01.ogg", 6)
loops["music"] = {"file": "music/MUS_MatchLoop_01.ogg", "seconds": round(len(a) / sr, 3), "level_play": 0.35, "level_pause": 0.6, "interp_s": 0.5,
                  "source": "MS_music_match: Wave Player (loop) x InterpTo(clamp(Level, 0, 1), 0.5 s); CommentarySystem.h:46-47, CommentarySystem.cpp:938-943"}
bed = graphs["MS_crowd_bed"]["inputs"]
a, sr = source(str(bed["BedLoop"]["default"]))
cutoff = 3000.0 + 6000.0 * float(bed["Excite"]["default"])
lp = np.stack([biquad(a[:, c], "low", cutoff, 1.0, sr) for c in range(a.shape[1])], axis=1)
gain = float(bed["Level"]["default"]) * 2.0 * (float(bed["Excite"]["default"]) + 1.0)
sizes["crowd"] += ogg(lp, sr, "crowd/%s_lp%d.ogg" % (bed["BedLoop"]["default"], round(cutoff)), 5)
loops["crowd_bed"] = {"file": "crowd/%s_lp%d.ogg" % (bed["BedLoop"]["default"], round(cutoff)), "seconds": round(len(a) / sr, 3), "gain": gain,
                      "lowpass_hz": cutoff, "level": bed["Level"]["default"], "excite": bed["Excite"]["default"],
                      "source": "MS_crowd_bed: Wave Player (loop) -> Biquad low-pass (3000 + 6000 x Excite Hz, bandwidth 1) x Level x 2 x (Excite + 1); "
                                "thirdjam starts it and never sets Level or Excite (CommentarySystem.cpp:922-930)"}
a, sr = source("SFX_SkateStrideLoop_01")
sizes["skate"] += ogg(a, sr, "skate/SFX_SkateStrideLoop_01.ogg", 5)
c, sr2 = source("SFX_SkateCarve_02")
sizes["skate"] += ogg(c, sr2, "skate/SFX_SkateCarve_02.ogg", 5)
n = 4 * SR
fade = int(0.25 * SR)
noise = biquad(pink(n + fade + SR, 20261124), "band", NOISE_REF_HZ, 1.5, SR)[SR:]      # the first second settles the filters
t = np.linspace(0.0, 1.0, fade)
noise[:fade] = noise[:fade] * np.sqrt(t) + noise[n:n + fade] * np.sqrt(1.0 - t)          # the end runs into the start: a seamless loop
noise = noise[:n].reshape(-1, 1)
sizes["skate"] += ogg(noise, SR, "skate/noise_pink_bp%d.ogg" % round(NOISE_REF_HZ), 5)
fx = float(graphs["MS_skate_loop"]["inputs"]["FxTrim"]["default"])
loops["skate"] = {"stride": "skate/SFX_SkateStrideLoop_01.ogg", "carve": "skate/SFX_SkateCarve_02.ogg", "noise": "skate/noise_pink_bp%d.ogg" % round(NOISE_REF_HZ),
                  "noise_ref_hz": NOISE_REF_HZ, "noise_rms": round(float(np.sqrt((noise ** 2).mean())), 5), "fx_trim": fx,
                  "stride_gain": 1.4, "stride_semitones": [4.0, -2.0], "noise_gain": [1.0, 0.25, 3.0], "noise_hz": [1200.0, 2500.0], "carve_gain": 0.8,
                  "turn_rad_s": 3.0, "turn_gap_frames": 15, "turn_min_speed": 1.0,
                  "source": "MS_skate_loop: mixer(1.0 x [0.25 x band-pass(pink noise, 1200 + 2500 x Speed Hz, bandwidth 1.5) x 3 x Speed], 1.4 x stride loop "
                            "pitched 4 x Speed - 2 semitones x Speed, 0.8 x carve on Turn) x FxTrim; Speed and Turn: CommentarySystem.cpp:945-968, "
                            "CommentarySystem.h:48-49"}
table = {
    "schema": "tl.rink.audio/1",
    "note": "thirdjam's sound in our engine (lane K6). 'events': per event name and Variant, per Strength step, the takes: {file, gain}. law 'gain': the "
            "sound only scales with Strength (one file; the gain between steps is a straight line). law 'steps': the step at or below the Strength is "
            "played. A file is Unreal's own render of the event's MetaSound (engine/tools/arena/render_audio.py), cut to its sound, nothing else. "
            "'loops': the held sounds' sources and the numbers of their rules (rink_audio.gd).",
    "out_gain": {"stereo": 0.7071, "mono": 0.5,
                 "note": "What Unreal's output does to a 2D sound, measured on its own render of the held sounds (render_audio.py, jobs_cal.json): "
                         "MS_music_match at Level 1 comes out at 0.706 of its wave, MS_crowd_bed at 0.721 of this bake's low-passed bed (residual "
                         "5.8 %), the mono MS_skate_loop at 0.52 (Speed 1) and 0.51 (Speed 0.5) of this port's model. The one-shots' files are "
                         "Unreal's output already; the held sounds' gains are multiplied by these."},
    "strength_steps": sorted({float(r["strength"]) for r in render["files"].values()}),
    "events": events, "loops": loops,
    "sizes_bytes": sizes, "counts": {"renders": len(render["files"]), "files": kept, "scaled": scaled, "silent": silent, "tail_cut": cut_tail},
}
with open(os.path.join(OUT, "audio.json"), "w", encoding="utf-8") as f:
    json.dump(table, f, indent=1)
    f.write("\n")
print(json.dumps({"events": len(events), "renders": len(render["files"]), "files": kept, "scaled": scaled, "silent": silent, "tail_cut": len(cut_tail),
                  "mb": {k: round(v / 1e6, 2) for k, v in sizes.items()}}))
