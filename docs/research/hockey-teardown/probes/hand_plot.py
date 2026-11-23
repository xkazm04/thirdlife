"""H1 hand: the two sheets of BEHAVIOUR-HAND.md from the probes' CSV and JSON (run with Python 3 + matplotlib).
   python hand_plot.py <h1 dir (.tl/h1)> <media dir>  -> beh_move.jpg (area 1), beh_puck.jpg (area 3)"""
import csv, json, os, re, sys
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

H1, MEDIA = sys.argv[1], sys.argv[2]
TJ_C, OUR_C = "#2b6cb0", "#c05621"
R_TJ, R_OURS = 0.40, 0.879   # body radius (m): thirdjam's skater, our contact body (TEARDOWN 2.2)


def rows(d, name):
    with open(os.path.join(H1, d, name + ".csv")) as f:
        return [{k: (v if k == "holder" else float(v)) for k, v in r.items()} for r in csv.DictReader(f)]


def series(d, name, key="speed", t0=0):
    r = rows(d, name)
    return [(x["age"] - t0) / 60 for x in r], [x[key] for x in r]


def move_sheet():
    fig, ax = plt.subplots(2, 3, figsize=(13, 7.2), dpi=80)
    panels = [("start", "From rest, full stick", 0, 3.3), ("reverse", "At top speed: stick reversed (the 180)", 150, 2.5),
              ("release", "At top speed: stick released", 150, 2.5), ("turn90", "At top speed: stick 90 degrees", 150, 2.0),
              ("tap6", "Taps from rest: 3, 6, 12 frames", 0, 1.5), ("carry_start", "Carrying the puck, from rest", 0, 3.3)]
    for a, (name, title, t0, tmax) in zip(ax.flat, panels):
        names = ["tap3", "tap6", "tap12"] if name == "tap6" else [name]
        for n in names:
            for d, c, lab in (("tj_move", TJ_C, "thirdjam (its sim law)"), ("ours_move", OUR_C, "ours (the pack, headless)")):
                t, v = series(d, n, t0=t0)
                keep = [(x, y) for x, y in zip(t, v) if -0.3 <= x <= tmax]
                a.plot([k[0] for k in keep], [k[1] for k in keep], color=c, lw=1.8, label=lab if n == names[0] else None,
                       alpha=1.0 if n != "tap3" else 0.6, ls="-" if n != "tap12" else "--")
        if name == "turn90":
            for d, c in (("tj_move", TJ_C), ("ours_move", OUR_C)):
                r = rows(d, "turn90")
        a.axvline(0, color="#999", lw=0.8)
        a.set_title(title, fontsize=11)
        a.set_xlabel("seconds after the keys changed" if t0 else "seconds")
        a.set_ylabel("speed, m/s")
        a.grid(alpha=0.3)
    ax[0][0].legend(loc="lower right", fontsize=9)
    fig.suptitle("Speed over time: thirdjam (blue) and ours (orange), the same keys frame by frame", fontsize=13)
    fig.tight_layout()
    fig.savefig(os.path.join(MEDIA, "beh_move.jpg"), pil_kwargs={"quality": 82})


def puck_sheet():
    fig, ax = plt.subplots(2, 2, figsize=(13, 8), dpi=80)
    # (a) pick-up in play: share his within 15 frames, by the puck's speed relative to him
    bins = ["0-4", "4-8", "8-12", "12-16", "16-20", "20+"]
    a = ax[0][0]
    for i, (f, c, lab, hatch) in enumerate((("carry_tj.json", TJ_C, "thirdjam, its ring 1.1 m", ""), ("carry_ours.json", OUR_C, "ours, its ring 1.45 m", ""),
                                            ("carry_tj2.0.json", TJ_C, "thirdjam, 2 m disc", "//"), ("carry_ours2.0.json", OUR_C, "ours, 2 m disc", "//"))):
        p = json.load(open(os.path.join(H1, f)))["pickup"]
        xs = [j + (i - 1.5) * 0.2 for j in range(len(bins))]
        ys = [p.get(b, {}).get("his", 0) for b in bins]
        a.bar(xs, ys, width=0.19, color=c, alpha=0.9 if not hatch else 0.45, hatch=hatch, label=lab)
        for x, b in zip(xs, bins):
            n = p.get(b, {}).get("n", 0)
            a.text(x, 0.02, str(n), ha="center", fontsize=7, color="white" if not hatch else "black", rotation=90)
    a.set_xticks(range(len(bins)), bins)
    a.set_xlabel("loose puck's speed relative to him, m/s (numbers: chances)")
    a.set_ylabel("share his within 15 frames")
    a.set_title("(a) A loose puck reaches him in a match: is it his?", fontsize=11)
    a.legend(fontsize=8, loc="upper right")
    a.set_ylim(0, 1.15)
    # (b) loose puck sent at a standing skater: outcome by speed. thirdjam: its own staged test (Jam.Core.Possession.Staged, POSSTAGE
    # lines of the build, "rule" arm: front / side / behind x feet / body / blade); ours: hand_step.gd drills (front / side / behind x centre / 0.8 m off)
    a = ax[0][1]
    tj = {}
    for line in open(os.path.join(H1, "auto", "auto1.log"), errors="ignore"):
        m = re.search(r"POSSTAGE loose\s+(\d+) m/s .*\| rule (\w+)\s+inside\s+\d+ his@\s*(-?\d+)", line)
        if m:
            u, kind, his = int(m.group(1)), m.group(2), int(m.group(3))
            tj.setdefault(u, set()).add((line.split("|")[0], kind, his))
    def share(items):
        n = len(items)
        return [sum(1 for k in items if k == c) / n for c in ("clean", "after", "never")], n
    xs, labels = [], []
    pos = 0
    for game, data in (("thirdjam", {u: ["clean" if k == "his" else ("after" if h >= 0 else "never") for _, k, h in v] for u, v in sorted(tj.items())}),
                       ("ours", None)):
        if game == "ours":
            data = {}
            for u in (8, 12, 16, 20, 24):   # 4 m/s: the scene ended before the puck arrived (it slows 1 m/s each second)
                out = []
                for ang in (0, 90, 180):
                    for off in ("0", "0.8"):
                        r = rows("ours_pick", f"recv_a{ang}_u{u}_o{off}")
                        dd = [((x["px"] - x["x"]) ** 2 + (x["pz"] - x["z"]) ** 2) ** 0.5 for x in r]
                        ring = next((i for i, v in enumerate(dd) if v <= 1.45), None)
                        his = next((i for i, x in enumerate(r) if x["holder"] == "b0"), None)
                        out.append("never" if his is None or ring is None and u > 4 else ("clean" if his - (ring or 0) <= 2 else "after"))
                data[u] = out if u > 4 else [o for o in out]
        for u, items in data.items():
            sh, n = share(items)
            b = 0
            for v, c in zip(sh, ("#38a169", "#d69e2e", "#e53e3e")):
                a.bar(pos, v, bottom=b, color=c, width=0.8, edgecolor=TJ_C if game == "thirdjam" else OUR_C, lw=2)
                b += v
            labels.append(f"{u}"); xs.append(pos); pos += 1
        pos += 0.6
    a.set_xticks(xs, labels)
    a.text(1.5, 1.04, "thirdjam", color=TJ_C, ha="center", fontsize=10)
    a.text(6.6, 1.04, "ours", color=OUR_C, ha="center", fontsize=10)
    a.set_ylim(0, 1.12)
    a.set_xlabel("puck speed, m/s, sent at a standing skater")
    a.set_ylabel("share of scenes")
    a.set_title("(b) Loose puck at a standing skater: his at once (green), after a\nbounce or bobble (yellow), never (red)", fontsize=10)
    # (c) the puck's distance from his centre while he carries through a turn, a stop, a sprint turn (ours), thirdjam's measured carry distances
    a = ax[1][0]
    for n, ls in (("carry_turn90", "-"), ("carry_reverse", "--"), ("carry_sprint_turn90", ":")):
        r = rows("ours_move", n)
        t = [(x["age"] - 150) / 60 for x in r]
        d = [((x["px"] - x["x"]) ** 2 + (x["pz"] - x["z"]) ** 2) ** 0.5 for x in r]
        a.plot(t, d, color=OUR_C, ls=ls, lw=1.6, label="ours: " + n.replace("carry_", "").replace("_", " "))
    a.axhline(1.2, color=TJ_C, lw=1.6, label="thirdjam skating: 1.20 (its test; 1.23 measured)")
    a.axhline(1.6, color=TJ_C, lw=1.6, ls=":", label="thirdjam sprinting: 1.60")
    a.axhspan(0, R_OURS, color=OUR_C, alpha=0.12, label="inside our body (0.88 m)")
    a.axhspan(0, R_TJ, color=TJ_C, alpha=0.18, label="inside thirdjam's body (0.40 m)")
    a.set_xlim(-1, 2)
    a.set_ylim(0, 2.0)
    a.set_xlabel("seconds after the keys changed")
    a.set_ylabel("puck centre to his centre, m")
    a.set_title("(c) Where the puck sits while he carries (it never came off in any drill)", fontsize=11)
    a.legend(fontsize=7.5, loc="lower right")
    # (d) how carries end, per minute of carrying
    a = ax[1][1]
    o = json.load(open(os.path.join(H1, "carry_ours.json")))
    t = json.load(open(os.path.join(H1, "carry_tj.json")))
    cm_o, cm_t = o["carry_min"], 14.3
    ours = {"shot or pass": (o["our_release_kinds"]["shot"] + o["our_release_kinds"]["pass"]) / cm_o, "knocked off by a hit": o["our_release_kinds"]["hit"] / cm_o,
            "poked off / taken": o["our_release_kinds"]["poked"] / cm_o, "lost alone (bobble, rule)": (o["our_release_kinds"].get("?", 0) + o["our_release_kinds"].get("bobble", 0)) / cm_o}
    taken = (t["ends_n"]["taken"] + t["ends_n"]["loose"]) / t["carry_min"]
    tjv = {"shot or pass": (300 + 200) / cm_t, "knocked off by a hit": (31 + 72) / cm_t, "poked off / taken": taken - (31 + 72) / cm_t, "lost alone (bobble, rule)": 0}
    cols = ["#4a5568", "#e53e3e", "#d69e2e", "#805ad5"]
    for i, (lab, vals) in enumerate((("thirdjam\n(playtester)", tjv), ("ours\n(TLHand regular)", ours))):
        b = 0
        for k, c in zip(vals, cols):
            a.bar(i, vals[k], bottom=b, color=c, label=k if i == 0 else None, width=0.55)
            if vals[k] > 1.5:
                a.text(i, b + vals[k] / 2, f"{vals[k]:.1f}", ha="center", va="center", color="white", fontsize=9)
            b += vals[k]
    a.set_ylim(0, 85)
    a.set_xticks([0, 1], ["thirdjam\n(playtester, 30 matches)", "ours\n(TLHand regular, 24 matches)"])
    a.set_ylabel("carry ends per minute of carrying")
    a.set_title("(d) How his carries end (pro level). thirdjam's 'poked off / taken'\nis what is left after its own hit count (trace only)", fontsize=10)
    a.legend(fontsize=8, loc="upper right")
    fig.tight_layout()
    fig.savefig(os.path.join(MEDIA, "beh_puck.jpg"), pil_kwargs={"quality": 82})


move_sheet()
puck_sheet()
for n in ("beh_move.jpg", "beh_puck.jpg"):
    print(n, os.path.getsize(os.path.join(MEDIA, n)))
