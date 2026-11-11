export const summary = "static architecture checks (walls, prefixes, uids, verbs, schemas, size ratchet, API index, API v1 contract); no Godot";
import fs from "node:fs";
import path from "node:path";
import { REPO, printVerdict, step } from "../ctx.mjs";
import { runRules, computeBaseline, diffBaseline, loadRules, BASELINE_REL } from "../arch/core.mjs";
import { generateIndex, INDEX_FILE } from "../arch/apiindex.mjs";
import { writeApi, makeBrokenTree, API_FILE } from "../arch/apicontract.mjs";
import { makeIo } from "../arch/util.mjs";

const USAGE = "tl arch [--rule <id>[,<id>]] [--verbose] [--root <dir>] | --index [--freeze] | --broken-demo <empty dir> | --update-baseline | --list";

export async function run(args, ctx = {}, root = REPO) {
  if (args.includes("--help")) { console.log(USAGE); return 0; }
  const rooti = args.indexOf("--root");            // P7: judge another tree (a test tree, a merge candidate)
  if (rooti >= 0) { root = path.resolve(args[rooti + 1] ?? ""); args = args.filter((_, i) => i !== rooti && i !== rooti + 1); if (!fs.existsSync(root)) { console.error(`tl arch: --root ${root} does not exist`); return 2; } }
  const demo = args.indexOf("--broken-demo");      // P7: a copy of the API sources in which TLBall.shoot lost its parameter
  if (demo >= 0) {
    const dir = path.resolve(args[demo + 1] ?? "");
    if (!args[demo + 1] || (fs.existsSync(dir) && fs.readdirSync(dir).length)) { console.error("tl arch --broken-demo <dir>: give a directory that is empty or does not exist"); return 2; }
    const b = makeBrokenTree(makeIo(root), root, dir);
    console.log(`test tree: ${dir}\nchanged ${b.victim}: \`${b.was}\` -> \`${b.now}\`\nnow: tl arch --root ${dir} --rule api-v1`);
    return run(["--rule", "api-v1", "--verbose"], ctx, dir);
  }
  const rules = loadRules();
  if (args.includes("--list")) { for (const r of rules) console.log(`${r.id.padEnd(16)} ${r.severity.padEnd(8)} ${r.description}`); return 0; }
  if (args.includes("--index")) {
    const text = generateIndex(makeIo(root));
    const f = path.join(root, INDEX_FILE);
    fs.mkdirSync(path.dirname(f), { recursive: true });
    const before = fs.existsSync(f) ? fs.readFileSync(f, "utf8") : null;
    fs.writeFileSync(f, text);
    console.log(`${before === text ? "unchanged" : "wrote"} ${INDEX_FILE} (${text.split("\n").length - 1} lines)`);
    const api = writeApi(makeIo(root), root, { freeze: args.includes("--freeze") });
    for (const l of api.lines) console.log(l);
    return api.ok ? 0 : 1;
  }
  if (args.includes("--update-baseline")) {
    const { next, old } = computeBaseline({ root, rules });
    const diff = diffBaseline(old, next);
    fs.mkdirSync(path.join(root, "devx"), { recursive: true });
    fs.writeFileSync(path.join(root, BASELINE_REL), JSON.stringify(next, null, 2) + "\n");
    console.log(diff.length ? diff.join("\n") : "baseline unchanged");
    console.log(`wrote ${BASELINE_REL}`);
    return 0;
  }
  const ri = args.indexOf("--rule");
  const only = ri >= 0 ? (args[ri + 1] ?? "").split(",").filter(Boolean) : null;
  if (only) {
    const bad = only.filter((id) => !rules.some((r) => r.id === id));
    if (bad.length) { console.error(`tl arch: unknown rule ${bad.join(", ")}`); return 2; }
  }
  const verbose = args.includes("--verbose");
  const t0 = Date.now();
  const { results } = runRules({ root, rules, only });
  const steps = results.map((r) => {
    const parts = [];
    if (r.findings.length) parts.push(`${r.findings.length} finding(s): ${r.findings.slice(0, 2).map((f) => `${f.file}${f.line ? ":" + f.line : ""} ${f.message}`).join(" | ")}${r.findings.length > 2 ? " | ..." : ""}`);
    if (r.grandfathered.length) parts.push(`${r.grandfathered.length} grandfathered`);
    if (!r.findings.length && r.notes.length) parts.push(r.notes[0].slice(0, 100));
    return step(r.rule.id, r.ok, r.ms, parts.join("; "));
  });
  if (verbose) {
    for (const r of results) {
      for (const [tag, f] of [...r.findings.map((x) => ["NEW ", x]), ...r.grandfathered.map((x) => ["HELD", x])]) {
        console.log(`  ${tag} ${r.rule.id}: ${f.file}${f.line ? ":" + f.line : ""} ${f.message}`);
      }
    }
  }
  return printVerdict("arch", steps, {
    ms: Date.now() - t0,
    findings: results.flatMap((r) => r.findings.map((f) => ({ rule: r.rule.id, ...f }))),
    grandfathered: Object.fromEntries(results.filter((r) => r.grandfathered.length).map((r) => [r.rule.id, r.grandfathered.length])),
  });
}
