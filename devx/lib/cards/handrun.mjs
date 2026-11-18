// `tl cards hands <pack dir> --card <id> [--seeds N] [--tests <dir>] [--par N]` (lane C2, 18 Nov): runs a card's hand
// checks on any pack directory, the rows the Foreman judges before it promotes (the verdict is hands.mjs judgeHand, the
// same code foreman/src/handcheck.ts imports). For every check the pack's tests/bot_hand_<hand>.gd runs on seeds 1..N
// through engine/tools/tl.sh bot; a run counts as finished when the verify line says bot.completed, and as won when its
// bot result says `won: true`. `--tests <dir>` lays the .gd (and .gd.txt, as .gd) files of <dir> over tests/ of a temporary copy of the pack
// (and lists every bot_hand_<hand>.gd it brings in the copy's manifest), so a pack built before cards had hands can be
// measured without touching it. A run that does not finish is never a pass (docs/GATE-HONESTY.md).
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawn } from "node:child_process";
import { loadCards } from "./check.mjs";
import { handTest, judgeHand, wilson } from "./hands.mjs";

export const USAGE = "usage: tl cards hands <pack dir> --card <id> [--seeds N] [--tests <dir>] [--par N]";

export function parseHandArgs(args) {
  const o = { pack: null, card: null, seeds: null, tests: null, par: 4 };
  for (let i = 0; i < args.length; i++) {
    const a = args[i], val = () => { const v = args[++i]; if (v === undefined) throw new Error(`${a} needs a value`); return v; };
    if (a === "--card") o.card = val();
    else if (a === "--seeds") o.seeds = Number(val());
    else if (a === "--tests") o.tests = val();
    else if (a === "--par") o.par = Number(val());
    else if (a.startsWith("--")) throw new Error(`unknown option ${a}`);
    else if (!o.pack) o.pack = a;
    else throw new Error(`unexpected argument ${a}`);
  }
  if (!o.pack) throw new Error("the pack directory is required");
  if (!o.card) throw new Error("--card is required");
  if (o.seeds !== null && !(Number.isInteger(o.seeds) && o.seeds >= 1)) throw new Error("--seeds must be a whole number of at least 1");
  if (!(o.par >= 1)) throw new Error("--par must be at least 1");
  return o;
}

/** A temporary copy of the pack with the .gd files of `testsDir` laid over tests/; every bot_hand_*.gd brought in is listed. */
export function overlayPack(packDir, testsDir) {
  const out = fs.mkdtempSync(path.join(os.tmpdir(), "tl-hands-"));
  fs.cpSync(packDir, out, { recursive: true, filter: (p) => !p.split(path.sep).includes(".godot") });
  fs.mkdirSync(path.join(out, "tests"), { recursive: true });
  const man = JSON.parse(fs.readFileSync(path.join(out, "pack.json"), "utf8"));
  // .gd.txt is a script kept outside a pack as text (no Godot uid needed in the repository); it is laid over as .gd.
  for (const n of fs.readdirSync(testsDir).filter((x) => x.endsWith(".gd") || x.endsWith(".gd.txt")).sort()) {
    const f = n.replace(/\.txt$/, "");
    fs.copyFileSync(path.join(testsDir, n), path.join(out, "tests", f));
    if (/^bot_hand_[a-z]+\.gd$/.test(f) && !man.tests.includes(`tests/${f}`)) man.tests.push(`tests/${f}`);
  }
  fs.writeFileSync(path.join(out, "pack.json"), JSON.stringify(man, null, 2) + "\n");
  return out;
}

/** Lane C4: the sentence that refuses a seed count below the card's, or "" when the count is the card's or more. */
export function seedsBelow(hands, seeds) {
  if (seeds >= hands.seeds) return "";
  return `--seeds ${seeds} is below the ${hands.seeds} seeds this card's bounds were measured on: a bound like "at least ${hands.checks.find((c) => c.wins_min !== undefined)?.wins_min ?? 0} of ${hands.seeds}" cannot be judged on fewer runs. Use --seeds ${hands.seeds} or more.`;
}

/** Lane C4: the card's checks for `seeds` runs: each bound keeps its share (wins_min rounded up, wins_max down; 0 stays 0). */
export function scaleHands(hands, seeds) {
  if (seeds === hands.seeds) return hands;
  const k = seeds / hands.seeds;
  return { ...hands, seeds, checks: hands.checks.map((c) => ({ ...c, ...(c.wins_min !== undefined ? { wins_min: Math.ceil(c.wins_min * k) } : {}), ...(c.wins_max !== undefined ? { wins_max: Math.floor(c.wins_max * k) } : {}) })) };
}

/** One run's stdout -> {done, won} where won is true, false or undefined (no boolean `won` in the bot result). */
export function readHandRun(stdout) {
  const line = String(stdout).split(/\r?\n/).filter((l) => l.startsWith("{")).reverse().find((l) => { try { return JSON.parse(l).schema === "tl.verify/1"; } catch { return false; } });
  if (!line) return { done: false, won: undefined };
  const v = JSON.parse(line);
  const done = (v.checks ?? []).some((c) => c.id === "bot.completed" && c.ok === true);
  const won = v.bot?.result?.won;
  return { done, won: typeof won === "boolean" ? won : undefined };
}

/** Pure core: the card's checks on a pack whose manifest lists `tests`, runs through runBot(test, seed) -> stdout. */
export async function handRows(hands, seeds, tests, par, runBot) {
  const rows = [];
  for (const c of hands.checks) {
    const test = handTest(c.hand);
    if (!tests.includes(test)) { rows.push({ hand: c.hand, test, found: seeds, completed: 0, wins: 0, ok: false, why: `the pack's manifest does not list ${test}` }); continue; }
    const runs = [];
    let next = 1;
    await Promise.all(Array.from({ length: Math.min(par, seeds) }, async () => {
      while (next <= seeds) { const s = next++; runs.push(readHandRun(await runBot(test, s))); }
    }));
    const done = runs.filter((r) => r.done), wins = done.filter((r) => r.won === true).length, unread = done.filter((r) => r.won === undefined).length;
    rows.push({ hand: c.hand, test, found: seeds, completed: done.length, wins, ...wilson(wins, done.length), ...judgeHand(c, seeds, done.length, wins, unread) });
  }
  return rows;
}

function realRunBot(ctx, packDir) {
  const sh = process.platform === "win32" && fs.existsSync("C:/Program Files/Git/bin/bash.exe") ? "C:/Program Files/Git/bin/bash.exe" : "bash";
  const godot = ctx.resolveGodot();
  return (test, seed) => new Promise((res) => {
    const p = spawn(sh, [path.join(ctx.ENGINE, "tools", "tl.sh"), "bot", `--pack=${packDir}`, `--test=${test}`, `--seed=${seed}`],
      { cwd: ctx.REPO, env: { ...process.env, TL_QUIET: "1", ...(godot ? { TL_GODOT: godot } : {}) } });
    let out = "";
    p.stdout.on("data", (d) => (out += d));
    p.stderr.on("data", () => {});
    p.on("error", () => res(""));
    p.on("close", () => res(out));
  });
}

/** deps = {runBot}: the test seam. Returns the exit code. */
export async function runHands(args, ctx, deps = {}) {
  let o;
  try { o = parseHandArgs(args); } catch (e) { console.error(`tl cards hands: ${e.message}\n${USAGE}`); return 2; }
  const hit = loadCards(ctx.REPO).cards.find((c) => c.card.id === o.card || c.card.id === `card.${o.card}`);
  if (!hit) { console.error(`tl cards hands: no card '${o.card}'`); return 2; }
  const hands = hit.card.hands;
  if (!hands?.checks?.length) { console.error(`tl cards hands: ${hit.card.id} has no hand checks (key "hands")`); return 2; }
  const src = path.resolve(o.pack);
  if (!fs.existsSync(path.join(src, "pack.json"))) { console.error(`tl cards hands: no pack.json in ${src}`); return 2; }
  if (!deps.runBot && !ctx.resolveGodot()) { console.error("tl cards hands: Godot not found (tl doctor)"); return 2; }
  const seeds = o.seeds ?? hands.seeds;
  // Lane C4: a bound holds for the number of seeds it was measured on. Fewer seeds cannot test it (at least 16 of 20
  // says nothing about 3 runs), so fewer is refused; more seeds scale each bound by the same share (scaleHands).
  const below = seedsBelow(hands, seeds);
  if (below) { console.error(`tl cards hands: ${below}`); return 2; }
  const scaled = scaleHands(hands, seeds);
  const packDir = o.tests ? overlayPack(src, path.resolve(o.tests)) : src;
  try {
    const tests = JSON.parse(fs.readFileSync(path.join(packDir, "pack.json"), "utf8")).tests ?? [];
    const t0 = Date.now();
    const rows = await handRows(scaled, seeds, tests, o.par, deps.runBot ?? realRunBot(ctx, packDir));
    console.log(`card ${hit.card.id} v${hit.card.version} on ${src}${o.tests ? ` (tests laid over from ${o.tests})` : ""}, seeds 1..${seeds}${seeds !== hands.seeds ? ` (bounds scaled from the card's ${hands.seeds} seeds)` : ""}`);
    console.log("hand       wins          Wilson 95 %   card");
    for (const r of rows) {
      const c = scaled.checks.find((x) => x.hand === r.hand);
      console.log(`${r.hand.padEnd(10)} ${String(r.wins).padStart(3)} of ${String(r.completed).padEnd(4)}  ${`${r.lo ?? 0}..${r.hi ?? 0}`.padEnd(12)}  ${[c.wins_min !== undefined ? `>= ${c.wins_min}` : "", c.wins_max !== undefined ? `<= ${c.wins_max}` : ""].filter(Boolean).join(", ")}  ${r.ok ? "holds" : "FAILS"}`);
    }
    const steps = rows.map((r) => ({ id: `hand:${r.hand}`, ok: r.ok, ms: 0, found: r.found, completed: r.completed, detail: r.why }));
    return ctx.printVerdict("cards hands", steps, { card: hit.card.id, pack: src, seeds, ms: Date.now() - t0, rows: rows.map(({ test, ...r }) => r) });
  } finally {
    if (packDir !== src) fs.rmSync(packDir, { recursive: true, force: true });
  }
}
