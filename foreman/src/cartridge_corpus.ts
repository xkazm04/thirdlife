// The parity corpus for src/cartridge.ts: every cartridge thirdjam ships, and broken (and harmless) copies of hockey.regular and
// Pond made by small change sets, plus rules sidecars. Deterministic: the same list every run, so the C++ verdicts recorded once
// from the built core (engine/cores/rink/tools/rink_validate.gd, written to src/test/fixtures/cartridge-cpp-verdicts.json) can be
// compared case by case, with each case's text hash to prove it is the same text.
//   node dist/cartridge_corpus.js --write <dir>    writes <dir>/<n>.json and <dir>/manifest.json for the engine side
import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";
import { parsePath, shippedCartridges, RINK_CONTENT_DIR } from "./cartridge.js";

export interface CorpusCase {
  name: string;
  kind: "cartridge" | "rules";
  text: string;
  sha1: string;
}

function setPath(obj: any, p: string, value: unknown): void {
  const keys = parsePath(p);
  let node = obj;
  for (let i = 0; i < keys.length - 1; i++) {
    const k = keys[i]!;
    if (node[k] === undefined) node[k] = typeof keys[i + 1] === "number" ? [] : {};
    node = node[k];
  }
  const last = keys[keys.length - 1]!;
  if (value === undefined) delete node[last];
  else node[last] = value;
}

// key path -> value (undefined = remove). Names say what a person (or a model) would have done.
const EDITS: [string, Record<string, unknown>][] = [
  ["faster skaters (speed 13)", { "game.skater.speed": 13 }],
  ["small rink 60 x 30", { "game.rink.length_m": 60, "game.rink.width_m": 30 }],
  ["first to 5", { "game.rules.score_to_win": 5 }],
  ["speed x3 (33)", { "game.skater.speed": 33 }],
  ["accel x3 (36)", { "game.skater.accel": 36 }],
  ["puck max speed x3 (90)", { "game.puck.max_speed": 90 }],
  ["ice friction at the top (0.1)", { "game.rink.ice_friction": 0.1 }],
  ["ice friction past the top (0.1001)", { "game.rink.ice_friction": 0.1001 }],
  ["rink too short (10 m)", { "game.rink.length_m": 10 }],
  ["rink length as a string", { "game.rink.length_m": "90" }],
  ["a fractional score to win (2.5)", { "game.rules.score_to_win": 2.5 }],
  ["an unknown rules mode (golf)", { "game.rules.mode": "golf" }],
  ["an unknown top-level key", { colour: 1 }],
  ["an unknown key in game.skater", { "game.skater.speedy": 3 }],
  ["an unknown block in game", { "game.ball": { size: 1 } }],
  ["no schema", { schema: undefined }],
  ["the wrong schema", { schema: "tj.cartridge/2" }],
  ["no game", { game: undefined }],
  ["a null value (puck drag)", { "game.puck.drag": null }],
  ["a value for no tunable", { "values.nope": 1 }],
  ["a duration in seconds", { "game.rules.goal_pause_seconds": 2 }],
  ["no teams", { "game.teams": [] }],
  ["one team only", { "game.teams": "__one_team__" }],
  ["13 obstacles (limit 12)", { "game.rink.obstacles": "__13_obstacles__" }],
  ["2 obstacles", { "game.rink.obstacles": "__2_obstacles__" }],
  ["a negative mass", { "game.skater.mass": -80 }],
  ["a bad colour", { "game.teams[0].colour_hex": "blue" }],
  ["a very long title", { title: "x".repeat(400) }],
];

const TEXT_EDITS: [string, (t: string) => string][] = [
  ["a trailing comma", (t) => t.replace(/\}\s*$/, ",}")],
  ["a duplicate key (id)", (t) => t.replace(/\{/, '{"id": "dup",')],
  ["a comment", (t) => t.replace(/\{/, "{ // note\n")],
  ["not JSON at all", () => "hockey but faster"],
  ["an empty text", () => ""],
  ["a byte-order mark", (t) => "﻿" + t],
];

function special(base: any, v: unknown): unknown {
  if (v === "__one_team__") return [structuredClone(base.game.teams[0])];
  const ob = (i: number) => ({ kind: "pillar", x: -30 + i * 5, z: 0, size: 1 });
  if (v === "__13_obstacles__") return Array.from({ length: 13 }, (_, i) => ob(i));
  if (v === "__2_obstacles__") return [ob(2), ob(8)];
  return v;
}

const RULES: [string, string][] = [
  ["K8's hockey.thirdlife.rules.json", "__file__"],
  ["the switch off", '{"schema":"tl.rink.rules/1","rules":{"net_carry_wall":false}}'],
  ["a level tune", '{"schema":"tl.rink.rules/1","rules":{"net_carry_wall":true},"levels":{"pro":"speed_scale=0.9"}}'],
  ["an unknown key", '{"schema":"tl.rink.rules/1","colour":"red"}'],
  ["an unknown rule", '{"schema":"tl.rink.rules/1","rules":{"no_such_rule":1}}'],
  ["a rule as a string", '{"schema":"tl.rink.rules/1","rules":{"net_carry_wall":"yes"}}'],
  ["no schema", '{"rules":{"net_carry_wall":true}}'],
  ["the wrong schema", '{"schema":"tl.rink.rules/2"}'],
  ["an unknown level", '{"schema":"tl.rink.rules/1","levels":{"legend":"speed_scale=1"}}'],
  ["a tune without =", '{"schema":"tl.rink.rules/1","levels":{"pro":"speed_scale"}}'],
  ["a tune not a number", '{"schema":"tl.rink.rules/1","levels":{"pro":"speed_scale=fast"}}'],
  ["not JSON", "net carry wall on"],
];

function sha1(t: string): string {
  return crypto.createHash("sha1").update(t, "utf8").digest("hex");
}

export function buildCorpus(contentDir: string = RINK_CONTENT_DIR): CorpusCase[] {
  const out: CorpusCase[] = [];
  const add = (name: string, kind: CorpusCase["kind"], text: string) => out.push({ name, kind, text, sha1: sha1(text) });
  for (const f of shippedCartridges(contentDir)) add(`shipped ${path.basename(f)}`, "cartridge", fs.readFileSync(f, "utf8"));
  for (const baseName of ["hockey.regular", "modes/hockey.mode.pond"]) {
    const baseText = fs.readFileSync(path.join(contentDir, "Cartridges", `${baseName}.cartridge.json`), "utf8");
    const base = JSON.parse(baseText);
    for (const [name, edits] of EDITS) {
      const c = structuredClone(base);
      for (const [p, v] of Object.entries(edits)) setPath(c, p, special(base, v));
      add(`${path.basename(baseName)}: ${name}`, "cartridge", JSON.stringify(c, null, 2) + "\n");
    }
    for (const [name, f] of TEXT_EDITS) add(`${path.basename(baseName)}: ${name}`, "cartridge", f(baseText));
  }
  const k8 = path.join(contentDir, "Cartridges", "hockey.thirdlife.rules.json");
  for (const [name, text] of RULES) {
    if (text === "__file__" && !fs.existsSync(k8)) continue;
    add(`rules: ${name}`, "rules", text === "__file__" ? fs.readFileSync(k8, "utf8") : text);
  }
  return out;
}

function main(argv: string[]): number {
  const i = argv.indexOf("--write");
  if (i < 0 || !argv[i + 1]) {
    console.error("usage: node dist/cartridge_corpus.js --write <dir>");
    return 2;
  }
  const dir = path.resolve(argv[i + 1]!);
  fs.mkdirSync(dir, { recursive: true });
  const cases = buildCorpus();
  cases.forEach((c, n) => fs.writeFileSync(path.join(dir, `${n}.json`), c.text, "utf8"));
  fs.writeFileSync(path.join(dir, "manifest.json"), JSON.stringify(cases.map((c, n) => ({ n, name: c.name, kind: c.kind, sha1: c.sha1 })), null, 1));
  console.log(`PASS  cartridge corpus: ${cases.length} cases in ${dir}`);
  return 0;
}

if (process.argv[1] && path.resolve(process.argv[1]).endsWith(path.join("dist", "cartridge_corpus.js"))) process.exitCode = main(process.argv);
