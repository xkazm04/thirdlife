"""Side-by-side sheets of the verb gym's run, one a verb: thirdjam's own figure (tools/skater/driver_oracle.py's
stills) over ours (cores/rink/view/verb_gym.gd --stills), the same frames from the same camera, for the followed
skater ("who" of calls.json).
  python verb_sheets.py <oracle dir> <ours dir> <calls.json> <out dir> [cam] [prefix]
A verb's moment is read from the skater's own calls: PlayShoot (tap / slap by its charge, from where the charge
began), PlayPass (held when a pass charge came before), PlayPoke, PlayLift, PlayStickHit, PlayReceive,
PlayCallForPass, a deke (its bus event), a spin (the turn rate of UpdateMotion), and the contact: PlayCheck,
PlayCrossCheck, the hold, PlayWhiff, SetKnockedDown, PlayHitReaction, PlayStumble, PlayBoardHit, the pin. A sheet runs
from 6 frames before the moment to 36 after, every still (every third frame; a knockdown: 150 frames, every ninth):
thirdjam above, ours below; at most three sheets a verb. Also <prefix>_run_<cam>.mp4
(every still, 20 a second = real time). Prints `tl.skater.verb_sheets/1 {...}`."""
import json
import os
import shutil
import subprocess
import sys

from PIL import Image, ImageDraw

oracle_dir, ours_dir, calls_path, out_dir = sys.argv[1:5]
cam = sys.argv[5] if len(sys.argv) > 5 else "three"
prefix = sys.argv[6] if len(sys.argv) > 6 else "r3"
os.makedirs(out_dir, exist_ok=True)
data = json.load(open(calls_path, encoding="utf-8"))
who = int(data.get("who", 0))
frames = data["frames"]
have = sorted(int(n[len(cam) + 2:-4]) for n in os.listdir(oracle_dir) if n.startswith(cam + "_f") and n.endswith(".png")
              and os.path.isfile(os.path.join(ours_dir, n)))
marks = []          # [frame, verb, first frame of the sheet]
charge_from = None
pass_from = None
spin_until = -1
for fr in frames:
    f = fr["f"]
    for name, a in fr["sk"][who]["calls"]:
        if name == "SetShotCharge":
            if a[0] > 0 and charge_from is None:
                charge_from = f
            if a[0] <= 0:
                charge_from = None if charge_from is not None and f - charge_from > 90 else charge_from
        elif name == "SetPassCharge":
            if a[0] > 0 and pass_from is None:
                pass_from = f
        elif name == "PlayShoot":
            marks.append([f, "shot_slap" if a[0] > 0 else "shot_tap", charge_from if (a[0] > 0 and charge_from is not None) else f])
            charge_from = None
        elif name == "PlayPass":
            marks.append([f, "pass_held" if pass_from is not None else "pass_tap", pass_from if pass_from is not None else f])
            pass_from = None
        elif name == "PlayPoke":
            marks.append([f, "poke_clean" if a[0] else "poke_miss", f])
        elif name == "PlayLift":
            marks.append([f, "lift", f])
        elif name == "PlayStickHit":
            marks.append([f, "stickhit_lifted" if a[0] else "stickhit_poked", f])
        elif name == "PlayReceive":
            marks.append([f, "receive", f])
        elif name == "PlayCallForPass":
            marks.append([f, "call_for_pass", f])
        elif name == "OnBusEvent" and a[0] == "deke" and a[1]:
            marks.append([f, "deke_" + (a[5] or "left"), f])
        elif name == "PlayCheck":
            marks.append([f, "check", f])
        elif name == "PlayCrossCheck":
            marks.append([f, "crosscheck", f])
        elif name == "SetCrossCheckHold" and a[0]:
            marks.append([f, "crosscheck_hold", f])
        elif name == "PlayWhiff":
            marks.append([f, "whiff_cross" if a[0] == 1 else "whiff_check", f])
        elif name == "SetKnockedDown" and a[0]:
            marks.append([f, "knockdown", f])
        elif name == "PlayHitReaction":
            marks.append([f, "hit_reaction", f])
        elif name == "PlayStumble":
            marks.append([f, "stumble", f])
        elif name == "PlayBoardHit":
            marks.append([f, "board_hit", f])
        elif name == "SetBoardPin" and a[0]:
            marks.append([f, "board_pin", f])
        elif name == "UpdateMotion" and abs(a[1]) > 8.0 and f > spin_until:
            marks.append([f, "spin", f])
            spin_until = f + 60
PX = 300
sheets = []
seen = {}
for f, verb, start in marks:
    seen[verb] = seen.get(verb, 0) + 1
    if seen[verb] > 3:
        continue                # three sheets a verb at most
    if verb == "knockdown":
        fl = [x for x in have if start - 9 <= x <= f + 150][::3]       # the fall, the lie, the get-up: every ninth frame
    else:
        fl = [x for x in have if start - 6 <= x <= f + 36]
    if not fl:
        continue
    fl = fl[:18]
    sheet = Image.new("RGB", (len(fl) * PX, 2 * PX), (20, 20, 24))
    d = ImageDraw.Draw(sheet)
    for i, x in enumerate(fl):
        name = "%s_f%04d.png" % (cam, x)
        sheet.paste(Image.open(os.path.join(oracle_dir, name)).convert("RGB").resize((PX, PX), Image.LANCZOS), (i * PX, 0))
        sheet.paste(Image.open(os.path.join(ours_dir, name)).convert("RGB").resize((PX, PX), Image.LANCZOS), (i * PX, PX))
        for yy, label in ((0, "thirdjam"), (PX, "ours")):
            text = "%s f%d%s" % (label, x, "  << " + verb if x <= f < x + 3 else "")
            d.rectangle([i * PX, yy, i * PX + 8 + 6 * len(text), yy + 13], fill=(0, 0, 0))
            d.text((i * PX + 3, yy + 1), text, fill=(255, 255, 255))
    out = os.path.join(out_dir, "%s_%s_f%04d_%s.jpg" % (prefix, verb, f, cam))
    sheet.save(out, quality=86)
    sheets.append(os.path.basename(out))
film = ""
if shutil.which("ffmpeg") and have:
    tmp = os.path.join(out_dir, "_film")
    os.makedirs(tmp, exist_ok=True)
    mark_at = {}
    for f, verb, _s in marks:
        for x in range(f, f + 30):
            mark_at[x] = verb
    for i, x in enumerate(have):
        name = "%s_f%04d.png" % (cam, x)
        pair = Image.new("RGB", (900, 450), (0, 0, 0))
        pair.paste(Image.open(os.path.join(oracle_dir, name)).convert("RGB").resize((450, 450), Image.LANCZOS), (0, 0))
        pair.paste(Image.open(os.path.join(ours_dir, name)).convert("RGB").resize((450, 450), Image.LANCZOS), (450, 0))
        d = ImageDraw.Draw(pair)
        for xx, label in ((0, "thirdjam's own figure (Unreal)"), (450, "ours (Godot)")):
            text = "%s  frame %d  %s" % (label, x, mark_at.get(x, ""))
            d.rectangle([xx, 0, xx + 10 + 6 * len(text), 15], fill=(0, 0, 0))
            d.text((xx + 4, 2), text, fill=(255, 255, 255))
        pair.save(os.path.join(tmp, "p_%05d.jpg" % i), quality=88)
    film = os.path.join(out_dir, "%s_run_%s.mp4" % (prefix, cam))
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-framerate", "20", "-i", os.path.join(tmp, "p_%05d.jpg"), "-c:v", "libx264", "-pix_fmt", "yuv420p",
                    "-crf", "27", film], check=False)
    shutil.rmtree(tmp, ignore_errors=True)
print("tl.skater.verb_sheets/1 " + json.dumps({"who": who, "stills": len(have), "verbs": seen, "sheets": sheets, "film": os.path.basename(film)}))
