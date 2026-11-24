# thirdjam's commentator into the rink core (K6 round 3): the 415 lines of its three commentary banks as Ogg Vorbis, and
# the booth's sound rules as engine/cores/rink/audio/voice.json.
#   python engine/tools/arena/vo_bake.py <wav folder of export_audio.py> <commentary_lines.gd> <out: engine/cores/rink/audio>
# The waves are export_audio.py's (Unreal's own SoundWave data, mono 24 kHz, as /JamAssets/Audio/VO/VO_Commentator_<id>
# holds them: commentary.json "sound", JamCommentaryData.cpp:98). Each is encoded as it is: no gain, no trim, no filter.
# A line's id is K5's (engine/packs/hokej/scripts/hud/commentary_lines.gd, generated from the same three banks), so the
# caption's picker and this voice name the same line.
import json
import os
import re
import subprocess
import sys

QUALITY = 3          # libvorbis -q:a for 24 kHz mono speech (about 45 kbit/s)


def main():
    wav_dir, lines_gd, out = sys.argv[1], sys.argv[2], sys.argv[3]
    ids = re.findall(r'^\t\["([^"]+)"', open(lines_gd, encoding="utf-8").read(), re.M)
    os.makedirs(os.path.join(out, "vo"), exist_ok=True)
    lines = {}
    total = 0
    for i in ids:
        name = "VO_Commentator_" + i.replace(".", "_")
        src = os.path.join(wav_dir, name + ".wav")
        if not os.path.exists(src):
            raise SystemExit("no wave for line %s (%s)" % (i, src))
        rel = "vo/%s.ogg" % name
        dst = os.path.join(out, rel)
        p = subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", src, "-c:a", "libvorbis", "-q:a", str(QUALITY), dst],
                           capture_output=True)
        if p.returncode != 0:
            raise SystemExit("ffmpeg: " + p.stderr.decode("utf-8", "replace")[:300])
        total += os.path.getsize(dst)
        lines[i] = rel
    doc = {
        "schema": "tl.rink.voice/1",
        "note": ("thirdjam's commentator (UJamCommentarySystem::Play, CommentarySystem.cpp:842-878): the line the booth picked plays through "
                 "/JamAssets/Audio/MS_commentary (a mono Wave Player x Volume 1, sound class SC_VO); SC_VO's passive mix SCM_DuckMusic sets "
                 "SC_Music's volume to 0.45 while a voice plays (Unreal's default mix fades: 0.2 s in, 0.2 s out); a line is cut by "
                 "FadeOut(0.15 s) (CutLine cpp:827-835) and a new line stops the one playing (cpp:860). Files: export_audio.py's waves, "
                 "encoded by vo_bake.py."),
        "volume": 1.0,
        "out_gain": 0.345,
        "out_gain_note": ("What Unreal's output does to a line through MS_commentary, measured on thirdjam's own match recorded with its "
                          "voice on (render_match.py, TL_MATCH_VOICE=1, 90 s): each line's wave found in the recording by "
                          "cross-correlation, least-squares gain 0.338 to 0.356 over 17 lines, median 0.345 (-9.24 dB). Not the "
                          "0.5 a mono MetaSound like MS_skate_loop comes out at."),
        "duck_music": 0.45,
        "duck_frames": 12,
        "cut_frames": 9,
        "bark": {"event": "bark", "variant": 0, "strength": 0.0,
                 "source": "UJamBarkSystem::Show broadcasts `bark` (Strength 0, Kind = situation; BarkSystem.cpp:538-548); the binder plays MS_bark (EffectsBinder.cpp:146-149, 2D: cpp:249-253)"},
        "lines": lines,
        "bytes": total,
    }
    with open(os.path.join(out, "voice.json"), "w", encoding="utf-8") as f:
        json.dump(doc, f, indent=1, sort_keys=False)
        f.write("\n")
    print("%d lines, %.2f MB" % (len(lines), total / 1e6))


if __name__ == "__main__":
    main()
