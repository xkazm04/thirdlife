// Lane C4: a fixture job with hand checks on disk (fake model, fake runner): the paddle fixture plan, card knock_down
// with idle <= 0 and perfect >= 3 of 4 seeds; court's first build wins 1 of 4 (missed, one round back), its second 4 of 4.
// usage: node make-hand-job.mjs <worktree> <out jobs root>
import fs from "node:fs";
import path from "node:path";
import { pathToFileURL } from "node:url";
const [wt, outRoot] = process.argv.slice(2);
const d = (p) => pathToFileURL(path.join(wt, "foreman", "dist", p)).href;
const { copyFixture } = await import(d("cli.js"));
const { Foreman } = await import(d("foreman.js"));
const { FakeBuilder } = await import(d("builder/fake.js"));
const { fastVerifier, fixtureScript } = await import(d("test/helpers.js"));
const { prepareReference } = await import(d("reference.js"));
const { validateEvent } = await import(d("events.js"));
const jobDir = path.join(outRoot, "paddle-court-hands-20261118-1");
fs.rmSync(jobDir, { recursive: true, force: true });
copyFixture(jobDir);
const engineDir = path.join(outRoot, "_engine");
fs.mkdirSync(engineDir, { recursive: true });
const cards = path.join(outRoot, "_cards");
fs.mkdirSync(cards, { recursive: true });
const card = JSON.parse(fs.readFileSync(path.join(wt, "engine", "cards", "knock_down.json"), "utf8"));
card.hands = { seeds: 4, checks: [{ hand: "idle", wins_max: 0, measured: "fixture" }, { hand: "perfect", wins_min: 3, measured: "fixture" }] };
fs.writeFileSync(path.join(cards, "knock_down.json"), JSON.stringify(card));
prepareReference(path.join(jobDir, "ref"), { cardsDir: cards });
const T = ["tests/bot_hand_idle.gd", "tests/bot_hand_perfect.gd"];
const file = path.join(jobDir, "job.jsonl");
fs.writeFileSync(file, fs.readFileSync(file, "utf8").split("\n").filter(Boolean).map((l) => {
  const ev = JSON.parse(l);
  if (ev.type !== "plan_set") return l;
  const court = ev.packages.find((p) => p.id === "court");
  court.scope.push(...T);
  court.registers = { tests: T };
  return JSON.stringify(validateEvent({ ...ev, card: "card.knock_down" }));
}).join("\n") + "\n");
const base = fixtureScript();
const c = base.steps.find((s) => s.match?.package === "court");
const w = (n) => ({ ...c.write, "tests/bot_hand_idle.gd": "extends Node\n# FAKE_WON(0)\n", "tests/bot_hand_perfect.gd": `extends Node\n# FAKE_WON(${n})\n` });
const steps = [{ ...c, delayMs: 0, match: { role: "builder", package: "court", round: 2 }, write: w(4) }, { ...c, delayMs: 0, write: w(1) }, ...base.steps.map((s) => ({ ...s, delayMs: 0 }))];
const f = new Foreman({ jobDir, builder: new FakeBuilder({ ...base, steps }), verifier: fastVerifier(engineDir), parallel: 1, builderTimeoutMs: 2000, packContract: "(c)", critic: false, maxReplans: 0, promoteTo: "job" });
const s = await f.run();
console.log(`${jobDir}: ${s.jobState?.state}; ${s.jobState?.reason ?? ""}`);
