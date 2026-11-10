export const summary = "re-run lint -> smoke -> bot on every save (polling); --once = one cycle with the verdict as exit code";
import path from "node:path";
import fs from "node:fs";
import { REPO, ENGINE, posix, step } from "../ctx.mjs";
import { createDetector, scanFiles } from "../loop/detect.mjs";
import { runCycle, orderVerbs, VERB_ORDER } from "../loop/cycle.mjs";
import { formatFinding } from "../loop/findings.mjs";
import { newestPack } from "../loop/pack.mjs";
import { startVerb, killTree } from "../loop/exec.mjs";

const shown = (p) => { const r = path.relative(REPO, p).split(path.sep).join("/"); return r.startsWith("..") ? posix(p) : r; };
const POLL_MS = 300;
const DEBOUNCE_MS = 500;

function parseArgs(args) {
  const o = { pack: null, verbs: VERB_ORDER.slice(), once: false, help: false };
  for (let i = 0; i < args.length; i++) {
    const a = args[i];
    const val = (name) => (a.startsWith(name + "=") ? a.slice(name.length + 1) : args[++i]);
    if (a === "--once") o.once = true;
    else if (a === "--help" || a === "-h") o.help = true;
    else if (a === "--pack" || a.startsWith("--pack=")) o.pack = val("--pack");
    else if (a === "--verbs" || a.startsWith("--verbs=")) o.verbs = String(val("--verbs")).split(",").map((s) => s.trim()).filter(Boolean);
    else throw new Error(`unknown argument '${a}'`);
  }
  return o;
}

export async function run(args) {
  let o;
  try { o = parseArgs(args); o.verbs = orderVerbs(o.verbs); } catch (e) { console.error(`tl watch: ${e.message}`); return 2; }
  if (o.help) { console.log("tl watch [--pack <dir>] [--verbs lint,smoke,bot] [--once]"); return 0; }
  const pack = o.pack ? path.resolve(o.pack) : newestPack([path.join(ENGINE, "seeds"), path.join(ENGINE, "kernel", "examples")]);
  if (!pack || !fs.existsSync(path.join(pack, "pack.json"))) { console.error(`tl watch: no pack.json in '${pack ?? "(none found)"}'; pass --pack <dir>`); return 2; }

  let current = null;       // the running child, so Ctrl-C can kill it
  let cancelled = false;
  const runVerb = (verb) => { const r = startVerb(verb, pack); current = r.child; return r.done.finally(() => { current = null; }); };
  const cycle = () => runCycle(o.verbs, runVerb, () => cancelled);

  if (o.once) {
    const res = await cycle();
    const steps = res.results.map((r) => step(r.verb, r.ok, r.ms, ""));
    for (const r of res.results) {
      console.log(`${r.ok ? "PASS" : "FAIL"}  ${r.verb.padEnd(28)} ${String(r.ms).padStart(7)} ms`);
      for (const f of r.findings) console.log(`      ${formatFinding(f)}`);
    }
    const ok = res.ok;
    console.log(JSON.stringify({ schema: "tl.devx/1", cmd: "watch", ok, steps, pack: posix(pack), findings: res.results.flatMap((r) => r.findings.map((f) => ({ verb: r.verb, ...f }))) }));
    return res.results.length ? (ok ? 0 : 1) : 2;
  }

  const draw = (title, res, changed) => {
    if (process.stdout.isTTY) process.stdout.write("\x1b[2J\x1b[H");
    console.log(`tl watch  ${shown(pack)}  verbs: ${o.verbs.join(" -> ")}   (Ctrl-C quits)`);
    if (changed?.length) console.log(`changed: ${changed.slice(0, 3).map((p) => path.relative(REPO, p).split(path.sep).join("/")).join(", ")}${changed.length > 3 ? ` (+${changed.length - 3})` : ""}`);
    console.log(title);
    if (!res) return;
    for (const r of res.results) {
      console.log(`${r.ok ? "PASS" : "FAIL"}  ${r.verb.padEnd(8)} ${String(r.ms).padStart(6)} ms`);
      for (const f of r.findings) console.log(`        ${formatFinding(f)}`);
    }
    const skipped = o.verbs.filter((v) => !res.results.some((r) => r.verb === v));
    if (skipped.length) console.log(`skipped: ${skipped.join(", ")}`);
    console.log(res.ok ? "ALL GREEN" : "RED");
  };

  const roots = [ENGINE, pack];
  const detector = createDetector({ scan: () => scanFiles(roots, [".gd", ".json"]), debounceMs: DEBOUNCE_MS });
  const onSig = () => { cancelled = true; killTree(current); process.stdout.write("\n"); process.exit(130); };
  process.on("SIGINT", onSig);
  process.on("SIGTERM", onSig);

  // Runs are awaited inline, so two never overlap; saves made during a run are seen by the next poll.
  const go = async (changed) => {
    draw("running...", null, changed);
    draw("", await cycle(), changed);
  };
  await go(null);
  // eslint-disable-next-line no-constant-condition
  while (true) {
    await new Promise((r) => setTimeout(r, POLL_MS));
    const changed = detector.poll();
    if (changed) await go(changed);
  }
}
