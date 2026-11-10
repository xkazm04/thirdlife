"""Hand-authored composition of the arena site (kit placements, bots, cameras) -> data/site.json.
Separate from layout.json (generated from terrain/track) so a designer-agent could edit this one."""
import json, math, os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ax, az, FT = -40.0, -75.0, -14.0
site = {
 "arena": {"centre": [ax, FT, az]},
 "stands": [{"k": "stands", "pos": [ax, FT, az - 13.6], "yaw": 180}],
 "benches": [{"k": "bench", "pos": [ax - 6, FT, az + 14.3], "yaw": 180}, {"k": "bench", "pos": [ax + 6, FT, az + 14.3], "yaw": 180}],
 "goals": [{"k": "goal", "pos": [ax - 26, FT + 0.1, az], "yaw": -90}, {"k": "goal", "pos": [ax + 26, FT + 0.1, az], "yaw": 90}],
 "scaffolds": [
   {"k": "scaffold", "pos": [-35.5, FT, -51.6], "yaw": 0}, {"k": "scaffold_s", "pos": [-22.2, FT, -51.6], "yaw": 0},
   {"k": "scaffold", "pos": [-63.5, FT, -51.6], "yaw": 0}, {"k": "scaffold", "pos": [-15.5, FT, -98.8], "yaw": 0},
   {"k": "scaffold_s", "pos": [-7.4, FT, -62], "yaw": 90}],
 "cranes": [
   {"id": "A", "pos": [-70, FT, -60], "yaw": 0.46, "jib": 30.0, "trolley": 24.0, "load": "crane_load_a", "sway": 1.0},
   {"id": "B", "pos": [-10, FT, -85], "yaw": 3.47, "jib": 30.0, "trolley": 19.0, "load": "crane_load_b", "sway": 0.6}],
 "props": [
   {"k": "pallet_blocks", "pos": [-50.0, FT, -49.0], "yaw": 12}, {"k": "pallet_blocks", "pos": [-47.4, FT, -48.6], "yaw": -8},
   {"k": "pallet_blocks", "pos": [-56.8, FT, -48.8], "yaw": 20}, {"k": "crate", "pos": [-53.8, FT, -48.3], "yaw": 25},
   {"k": "crate", "pos": [-44.2, FT, -49.2], "yaw": 5}, {"k": "crate", "pos": [-44.2, FT + 0.9, -49.2], "yaw": 40},
   {"k": "barrier_stripe", "pos": [-40.8, FT, -46.8], "yaw": 5}, {"k": "barrier_stripe", "pos": [-38.9, FT, -46.7], "yaw": 3},
   {"k": "barrier_stripe", "pos": [-30.5, FT, -46.0], "yaw": -4}, {"k": "lumber", "pos": [-27.0, FT, -48.0], "yaw": 70},
   {"k": "pallet_blocks", "pos": [-17.5, FT, -49.0], "yaw": -15}, {"k": "crate", "pos": [-12.3, FT, -50.0], "yaw": 14},
   {"k": "lumber", "pos": [-66.0, FT, -100.5], "yaw": 5}, {"k": "pallet_blocks", "pos": [-26.0, FT, -100.5], "yaw": 3},
   {"k": "lumber", "pos": [44.4, -10.0, -9.2], "yaw": 17}, {"k": "lumber", "pos": [46.0, -10.0, -11.0], "yaw": -40},
   {"k": "crate", "pos": [33.6, -10.0, -10.4], "yaw": 10}, {"k": "crate", "pos": [34.6, -10.0, -10.2], "yaw": -20},
   {"k": "pallet_blocks", "pos": [47.0, -10.0, -17.5], "yaw": 70}],
 "fences": [{"k": "fence", "pos": [19.8 + 2.4 * i, -10.0, -8.4], "yaw": 0} for i in range(4)] +
           [{"k": "fence", "pos": [18.6, -10.0, -10.8 - 2.4 * i], "yaw": 90} for i in range(2)] +
           [{"k": "fence", "pos": [37.6 + 2.4 * i, -10.0, -8.5], "yaw": 0} for i in range(0)],
 "bots": [
   {"pos": [-58.0, FT, -49.8], "yaw": 0, "state": "work"}, {"pos": [-40.0, FT, -50.6], "yaw": 20, "state": "idle"},
   {"pos": [-33.0, FT + 2.1, -51.0], "yaw": 0, "state": "work"}, {"pos": [-23.5, FT, -47.4], "yaw": 340, "state": "idle"},
   {"pos": [-14.5, FT, -53.8], "yaw": 10, "state": "work"}, {"pos": [-62.0, FT, -99.8], "yaw": 0, "state": "idle"}],
 "cars": {"A": {"asset": "car_red", "offset": 1.9, "speed": 17.0, "start": 30.0}, "B": {"asset": "car_blue", "offset": -1.9, "speed": 17.0, "start": 10.0}},
 "cams": {
   "hero": {"pos": [3.2, 6.2, 9.0], "look": [8.0, -9.5, -62.0], "fov": 66},
   "site": {"pos": [-9.0, -8.8, -30.0], "look": [-24.0, -9.5, -70.0], "fov": 60},
   "track": {"pos": [41.0, -6.5, -26.0], "look": [20.0, -11.5, -44.0], "fov": 52, "fire": ["nitro_pass"], "wait": 1.0},
   "crumble": {"pos": [41.0, -6.5, -26.0], "look": [20.0, -11.5, -44.0], "fov": 52, "fire": ["nitro_pass"], "wait": 1.0},
   "avatar": {"pos": [1.9, 1.6, -2.6], "look": [0.0, 1.15, 0.0], "fov": 42}}
}
json.dump(site, open(os.path.join(ROOT, "data", "site.json"), "w"), indent=1)
print("site.json written")
