# thirdjam's own log of a played match -> the review files of round 3 (K6):
#   python engine/tools/arena/tj_react_log.py <game.log> <react json> <booth json>
# react: every JAMEVENT goal / board (rink metres) and every JAMRINK react line (the cap, its tilt and hop, the distance,
# the rattled piece and its roll), as ARinkActor::ReactToEvent logged them (RinkActor.cpp:1756, 1793, 1833);
# booth: every JAMVO line started (id, event, frame, dur), JAMVO_CUT and JAMBARK (CommentarySystem.cpp:833, 846;
# BarkSystem.cpp:518), to set our booth's rates beside thirdjam's.
import json
import re
import sys

EV = re.compile(r"JAMEVENT (\w+) who=(-?\d+) where=\((-?[\d.]+),(-?[\d.]+),(-?[\d.]+)\) strength=([\d.]+) frame=(\d+) kind=(\w+)")
CAP = re.compile(r"JAMRINK react board cap=(\d+) of (\d+) strength=([\d.]+) frame=(\d+) tilt ([-\d.]+) deg hop ([-\d.]+) cm, ([\d.]+) m from the hit")
GOAL = re.compile(r"JAMRINK react goal end=([+-]x) frame=(\d+)")
RAT = re.compile(r"JAMRINK react rattle piece=(\w+) strength=([\d.]+) frame=(\d+) roll ([-\d.]+) deg")
VO = re.compile(r"JAMVO id=(\S+) event=(\w+) frame=(\d+) dur=(\d+)")
CUT = re.compile(r"JAMVO_CUT id=(\S+) frame=(\d+) reason=(\w+)")
BARK = re.compile(r"JAMBARK who=(-?\d+) situation=(\w+) tone=(\w+) id=(\S+) frame=(\d+)")
STILL = re.compile(r"u1-\w+-f(\d+)")


def main():
    log, out_react, out_booth = sys.argv[1:4]
    events, reacts, lines, cuts, barks = [], [], [], [], []
    last = 0
    for ln in open(log, encoding="utf-8", errors="replace"):
        m = EV.search(ln)
        if m:
            last = max(last, int(m.group(7)))
            if m.group(1) in ("goal", "board"):
                events.append([int(m.group(7)), m.group(1), m.group(8), round(float(m.group(3)) / 100, 4), round(float(m.group(4)) / 100, 4),
                               float(m.group(6)), int(m.group(2))])
            continue
        m = CAP.search(ln)
        if m:
            reacts.append({"frame": int(m.group(4)), "what": "cap", "cap": int(m.group(1)), "of": int(m.group(2)), "strength": float(m.group(3)),
                           "tilt": float(m.group(5)), "hop": float(m.group(6)), "dist": float(m.group(7))})
            continue
        m = GOAL.search(ln)
        if m:
            reacts.append({"frame": int(m.group(2)), "what": "goal", "end": m.group(1)})
            continue
        m = RAT.search(ln)
        if m:
            reacts.append({"frame": int(m.group(3)), "what": "rattle", "piece": m.group(1), "strength": float(m.group(2)), "roll": float(m.group(4))})
            continue
        m = VO.search(ln)
        if m:
            lines.append([int(m.group(3)), m.group(1), m.group(2), int(m.group(4))])
            continue
        m = CUT.search(ln)
        if m:
            cuts.append([int(m.group(2)), m.group(1), m.group(3)])
            continue
        m = BARK.search(ln)
        if m:
            barks.append([int(m.group(5)), int(m.group(1)), m.group(2), m.group(4)])
            continue
        m = STILL.search(ln)
        if m:
            last = max(last, int(m.group(1)))
    src = "thirdjam HEAD 8dc713c6 content on the 15 Nov binaries, -cut=hockey.regular ?level=pro, jam.ScriptHuman 2 (K6 round 1's reference run)"
    json.dump({"schema": "tl.rink.react_log/1", "source": src, "frames": last, "events": events, "reacts": reacts},
              open(out_react, "w", encoding="utf-8"), indent=0)
    json.dump({"schema": "tl.rink.booth_log/1", "source": src, "frames": last, "lines": lines, "cuts": cuts, "barks": barks},
              open(out_booth, "w", encoding="utf-8"), indent=0)
    print("frames %d: %d events, %d reactions; %d lines, %d cuts, %d barks" % (last, len(events), len(reacts), len(lines), len(cuts), len(barks)))


if __name__ == "__main__":
    main()
