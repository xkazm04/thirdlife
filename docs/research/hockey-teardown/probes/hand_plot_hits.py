"""H1 hand, round 2: the area-2 sheet (beh_hits.jpg).   python hand_plot_hits.py <h1 dir (.tl/h1)> <media dir>"""
import json, os, sys
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

H1, MEDIA = sys.argv[1], sys.argv[2]
TJ_C, OUR_C = "#2b6cb0", "#c05621"


def hits_sheet():
    """Area 2: frame timelines. Ours from hits_ours.jsonl / pokes_ours.jsonl [O-drill]; thirdjam from its build's test lines
    (auto/auto1.log: JAMSTAND 'the rule', JAMBRACE, JAMHIT, POKEDRILL) and its code constants where a line has no frame."""
    o = {json.loads(l)["scene"]: json.loads(l) for l in open(os.path.join(H1, "hits_ours.jsonl"))}
    pk = [json.loads(l) for l in open(os.path.join(H1, "pokes_ours.jsonl"))]
    pk_take = [p["frames_to_take"] for p in pk if p["took"]][0]
    pk_ready = min(p["poke_ready_again"] for p in pk if p["poke_ready_again"])   # after a miss: the cooldown
    # rows: (label, game, windup (from, to), contact frame, hit-stop (from, to, whole game?), victim out (from, to), ready-again frame)
    c, b, x, v = o["check_front_v9"], o["check_behind_v9"], o["crosse_front_v9"], o["victim_front_v9"]
    rows = [
        ("Body check, his front, 9 m/s", "thirdjam", (1, 8), 3, (3, 6, False), (3, 70), 3),
        ("", "ours", (1, 12), c["contact_frame"], (c["contact_frame"], c["contact_frame"] + c["stop_frames"], True), (c["contact_frame"], c["victim_free_frame"]), c["check_ready_again"]),
        ("Body check, his back, 9 m/s", "thirdjam", (1, 8), 3, (3, 6, False), (3, 116), 3),
        ("", "ours", (1, 12), b["contact_frame"], (b["contact_frame"], b["contact_frame"] + b["stop_frames"], True), (b["contact_frame"], b["victim_free_frame"]), b["check_ready_again"]),
        ("Cross-check, timed, his front\n(thirdjam 8 m/s, ours 9 m/s)", "thirdjam", (1, 8), 8, (8, 11, False), (8, 105), 30),
        ("", "ours", (1, 10), x["contact_frame"], (x["contact_frame"], x["contact_frame"] + x["stop_frames"], True), (x["contact_frame"], x["victim_free_frame"]), 46),
        ("Poke at a carrier in reach", "thirdjam", (1, 8), 1, None, None, 14),
        ("", "ours", (7, 13), pk_take, None, None, pk_ready),
        ("YOU are hit: front, 9 m/s\n(until your keys move you)", "thirdjam", None, 3, (3, 6, False), (3, 70), None),
        ("", "ours", None, v["contact_frame"], (v["contact_frame"], v["contact_frame"] + v["stop_frames"], True), (v["contact_frame"], v["hand_back_frame"]), None),
    ]
    fig, ax = plt.subplots(figsize=(13, 7.2), dpi=80)
    y = 0
    ticks, labels = [], []
    for lab, game, wu, contact, stop, out, ready in rows:
        col = TJ_C if game == "thirdjam" else OUR_C
        if wu:
            ax.barh(y, wu[1] - wu[0] + 1, left=wu[0] - 0.5, height=0.5, color=col, alpha=0.35)
        if out:
            ax.barh(y, out[1] - out[0], left=out[0], height=0.22, color="#e53e3e", alpha=0.85)
        if stop:
            ax.barh(y + 0.3, stop[1] - stop[0], left=stop[0], height=0.18, color="#1a202c" if stop[2] else "#a0aec0")
        ax.plot([contact], [y], marker="v", color="black", ms=9)
        if ready:
            ax.plot([ready], [y], marker="|", color=col, ms=18, mew=3)
        ticks.append(y)
        labels.append(f"{lab}  {game}" if lab else game)
        y -= 0.8 if game == "thirdjam" else 1.3
    ax.set_yticks(ticks, labels, fontsize=9)
    ax.set_xlim(0, 160)
    ax.set_xlabel("frames after the press (60 a second)")
    ax.grid(axis="x", alpha=0.3)
    from matplotlib.patches import Patch
    from matplotlib.lines import Line2D
    ax.legend(handles=[Patch(color=TJ_C, alpha=0.35, label="wind-up / active window (thirdjam)"), Patch(color=OUR_C, alpha=0.35, label="wind-up / active window (ours)"),
                       Line2D([], [], marker="v", color="black", ls="", label="contact (or the poke's take)"),
                       Patch(color="#e53e3e", label="victim without his keys (down, rising, stumbling)"),
                       Patch(color="#1a202c", label="hit-stop: the whole game frozen (ours)"), Patch(color="#a0aec0", label="hit-stop: picture only, play runs (thirdjam)"),
                       Line2D([], [], marker="|", color="#4a5568", ls="", ms=12, mew=3, label="the same press works again")], fontsize=8, loc="lower right")
    ax.set_title("Hits and pokes, frame by frame: thirdjam (its build's tests and code) and ours (drills through the keys)", fontsize=12)
    fig.tight_layout()
    fig.savefig(os.path.join(MEDIA, "beh_hits.jpg"), pil_kwargs={"quality": 82})


hits_sheet()
print("beh_hits.jpg", os.path.getsize(os.path.join(MEDIA, "beh_hits.jpg")))
