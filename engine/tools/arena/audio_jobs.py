#!/usr/bin/env python3
"""The list of renders for render_audio.py: every one-shot MetaSound of thirdjam at every Variant its event can carry
(UJamEffectsBinder::VariantFor, EffectsBinder.cpp:178-238; goal 0 / 1 GoalVariantFor; shot 0 / 1 ShotVariant;
check 4 = a stumble) and at five Strengths, with more than one take where the graph draws at random.
usage: python audio_jobs.py <graphs.json> <audio.json> <out jobs.json>"""
import json
import sys

graphs = json.load(open(sys.argv[1], encoding="utf-8"))
audio = json.load(open(sys.argv[2], encoding="utf-8"))["assets"]
dur = {k.split(".")[-1]: float(v.get("duration") or 0.0) for k, v in audio.items() if v["class"] == "SoundWave"}
VARIANTS = {"poke": [0, 1], "lift": [0, 1], "faceoff": [0, 1, 2], "foul": [0, 1], "signal": [0, 1, 2, 3], "check": [0, 1, 2, 3, 4],
            "board": [0, 1], "ability": [0, 1, 2, 3], "clock": [0, 1], "possess": [0, 1], "shot_blocked": [0, 1], "goal": [0, 1], "shot": [0, 1]}
LOOPS = {"MS_skate_loop", "MS_crowd_bed", "MS_music_match", "MS_commentary", "MS_arena_room", "MS_dash_loop"}   # held sounds: ported as rules, not rendered
STRENGTHS = [0.0, 0.25, 0.5, 0.75, 1.0]
jobs = []
total = 0.0
for name, g in sorted(graphs.items()):
    if name in LOOPS:
        continue
    ev = name[3:]
    delays = [float(v) for nd in g["nodes"] if nd["class"].startswith("UE.Trigger Delay") for k, v in nd["literals"].items() if k == "Delay Time"]
    decays = [float(v) for nd in g["nodes"] if "AD Envelope" in nd["class"] for k, v in nd["literals"].items() if k == "Decay Time"]
    longest = max([dur.get(w, 0.0) for w in g["waves"]] + [0.0])
    seconds = max(delays + [0.0]) + max(longest, max(decays + [0.0])) + 0.7
    if ev == "clock":
        seconds += 10.0
    seconds = round(min(max(seconds, 1.5), 12.0), 2)
    random = any("Random" in nd["class"] or "Noise" in nd["class"] for nd in g["nodes"])
    takes = 3 if any("Random" in nd["class"] for nd in g["nodes"]) else 1
    for variant in (VARIANTS.get(ev, [0]) if g["uses"]["variant"] else [0]):
        for s in (STRENGTHS if g["uses"]["strength"] else [1.0]):
            for take in range(takes):
                jobs.append({"file": "%s_v%d_s%03d_t%d" % (ev, variant, round(s * 100), take), "sound": "/JamAssets/Audio/" + name,
                             "event": ev, "variant": variant, "strength": s, "take": take, "seconds": seconds, "random": random})
                total += seconds + 0.5
json.dump(jobs, open(sys.argv[3], "w", encoding="utf-8"), indent=0)
print(len(jobs), "renders,", round(total / 60.0, 1), "minutes")
