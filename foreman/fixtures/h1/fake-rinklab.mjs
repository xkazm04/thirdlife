#!/usr/bin/env node
// H1 of 25 Nov: a stand-in for rinklab.exe (TL_RINKLAB_EXE) in the Foreman's tests of engine/cores/rink/lab/check_cartridge.mjs.
//   node fake-rinklab.mjs match <content> -cartridge=tlcheck -seeds=A-B -difficulty=<lv> [the hand's flags]
// Prints, per seed, a thirdjam.playtest/1 line and a rinklab.cell/1 line made only from (the cartridge's bytes, the
// difficulty, the hand's flags, the seed), as the real lab plays each match from its own seed. Each seed takes about 40 ms.
// TL_FAKE_LAB_LOG=<file>: one JSON line per process at its start and its end (the tests read the groups and the overlap).
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";

const args = process.argv.slice(2);
const log = process.env.TL_FAKE_LAB_LOG;
const note = (what) => { if (log) fs.appendFileSync(log, JSON.stringify({ what, pid: process.pid, t: Date.now(), args: args.slice(2) }) + "\n"); };
note("start");
const opt = (k) => args.find((a) => a.startsWith(`-${k}=`))?.slice(k.length + 2);
const [a, b] = (opt("seeds") ?? "1-1").split("-").map(Number);
const cart = fs.readFileSync(path.join(args[1], "Cartridges", `${opt("cartridge")}.cartridge.json`));
// H1c: like the shield of lane G1's Arsenal job, the F ability changes no match here: -remove=ability plays the same matches.
const hand = args.slice(2).filter((x) => !x.startsWith("-seeds=") && !x.startsWith("-cartridge=") && x !== "-remove=ability").join(" ");
const wait = (ms) => { const end = Date.now() + ms; while (Date.now() < end) { /* a match being played */ } };
for (let seed = a; seed <= b; seed++) {
  const h = crypto.createHash("sha256").update(cart).update(hand).update(String(seed)).digest();
  const n = (i, m) => h[i % 32] % m;
  wait(40);
  // the hand that never moves and the hand that only skates lose, as on a game worth playing
  const g = hand.includes("-remove=idle") || hand.includes("-only=none") ? [0, 1 + n(1, 5)] : [n(0, 6), n(1, 6)];
  console.log(JSON.stringify({ tool: "thirdjam.playtest/1", seed, result: g[0] > g[1] ? "win" : g[0] < g[1] ? "loss" : "draw", over: true, goals: g, frames: 3600 + n(3, 200) * 60, knockdowns_all: n(4, 30), touches_per_min: 5 + n(5, 15), max_no_touch: 600 + n(6, 900) }));
  console.log(JSON.stringify({ tool: "rinklab.cell/1", seed, stats: { shots: [n(7, 20), n(8, 20)], carries: 1 + n(9, 40), carry_frames: 60 * (1 + n(10, 80)), play_frames: 3000 + n(11, 300) * 10, loose_frames: 600 + n(12, 400), passes_completed: n(13, 6), human_mean: 7 + n(14, 4), human_max: 15 + n(15, 6), changes: 20 + n(16, 60), goals_walk: [n(17, 2), 0], press: { ability: hand.includes("-player=regular") ? 1 + n(19, 2) : 0 } }, ...(hand.includes("-plancheck") ? { planstats: { clone_checked: 100 + n(18, 50), clone_mismatch: 0 } } : {}) }));
}
note("end");
