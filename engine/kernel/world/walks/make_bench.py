# N5a item 4: writes the bench walks into this directory. Run from anywhere: `python make_bench.py`.
# A world of N plots on a square grid 60 m apart (footprints 40 x 40 m), packs in the order
# seed_paddle, seed_drive, seed_wall, w_pile (alternately 60 boxes KEPT AWAKE, a busy scene, and 60 boxes left alone,
# which settle and fall asleep); the seeds are played by their bots. "scenery": "plot": no far terrain, no forest.
# The player stands still in the middle of an inner plot.
#   bench_all_N.json  everything every world tick: the stage plot and N-1 sideline (sideline_m and the budgets are set
#                     out of reach, so the valve does nothing).
#   bench_mix_N.json  the realistic mix: 1 stage, the 4 plots across a road at sideline (sideline_m 50), the rest
#                     backdrop; budgets as in tiers.json; costs MEASURED, so the slice is what this machine needs.
import json, math, os

HERE = os.path.dirname(os.path.abspath(__file__))
PACKS = [("seed_paddle", 1), ("seed_drive", 1), ("seed_wall", 1), ("w_pile", 60),
         ("seed_paddle", 1), ("seed_drive", 1), ("seed_wall", 1), ("w_pile", 10060)]


def world(n, kind):
    cols = int(math.ceil(math.sqrt(n)))
    plots = []
    for i in range(n):
        pack, seed = PACKS[i % len(PACKS)]
        plot = {"id": "p%02d" % i, "pack": pack, "origin": [60 * (i % cols), 0, 60 * (i // cols)], "seed": seed}
        if pack == "w_pile":
            plot["mode"] = "smoke"      # its bot ends the game after 600 ticks; left alone it just lies there
        plots.append(plot)
    home = plots[cols + 1]["origin"]
    doc = {"schema": "tl.walk/1", "name": "bench_%s_%d" % (kind, n), "ticks": 600 if kind == "all" else 1200, "mode": "bot",
           "scenery": "plot",
           "plots": plots, "player": [[0, home]]}
    if kind == "all":
        doc["tiers"] = {"sideline_m": 100000, "budget_ms": {"front": 100000, "backdrop": 100000}}
    else:
        doc["tiers"] = {"sideline_m": 50, "cost": "measured"}
    with open(os.path.join(HERE, "bench_%s_%d.json" % (kind, n)), "w", newline="\n") as f:
        json.dump(doc, f, indent=1)
        f.write("\n")


for n in (12, 30, 60):
    world(n, "all")
    world(n, "mix")
print("wrote 6 walks")
