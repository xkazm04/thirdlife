// S1-bots arm A (juice day, 27 Nov 2026): a new move tells the bots by default (botsdefault.ts). The phases fixture is
// built to done, then a person's change adds a move and says nothing about the bots: the owner (court) gets the
// Foreman's "bots by default" lines in its brief, the bot package (paddle_ai) gets a wire request that waits for court's
// merge, and the what-changed card says so. "Only I can do it" turns the use off. A change with no move is as before.
import { test, after } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { main } from "../cli.js";
import { rebuildState } from "../joblog.js";
import { copyFixture } from "../cli.js";
import { BOTS_NOTE, botHints, botsCardLines, botsEvents, botsPlanOf, botsProblems } from "../botsdefault.js";
import type { FakeScript } from "../builder/fake.js";
import { cleanup, tempDir, readEvents } from "./helpers.js";
import type { JobEvent } from "../events.js";

after(cleanup);

const run = async (argv: string[]): Promise<{ code: number; text: string }> => {
  const lines: string[] = [];
  const code = await main(argv, (s) => lines.push(s));
  return { code, text: lines.join("\n") };
};
const FLAGS = ["--adapter", "fake", "--quiet", "--parallel", "1"];
const LOB = "add a lob shot on L: the paddle dips and scoops the ball high over the other paddle";

async function doneJob(label: string, owner: Record<string, unknown>): Promise<string> {
  const jobDir = path.join(tempDir(label), "site", "paddle-court-crazy-20261121-1");
  copyFixture(jobDir, true);
  const file = path.join(jobDir, "fake-builder.json");
  const base = JSON.parse(fs.readFileSync(file, "utf8")) as FakeScript;
  const ask = { match: { role: "planner", promptIncludes: "add a lob shot" }, tokensIn: 800, tokensOut: 60, json: owner };
  fs.writeFileSync(file, JSON.stringify({ ...base, steps: [ask, ...base.steps] }, null, 1));
  assert.equal((await run(["run", jobDir, ...FLAGS])).code, 3);
  for (let i = 0; i < 3; i++) await run(["phase", jobDir, "pass", ...FLAGS]);
  assert.equal(rebuildState(jobDir, { write: false }).jobState?.state, "done");
  return jobDir;
}
const since = (evs: JobEvent[], seq: number): JobEvent[] => evs.filter((e) => e.seq > seq);
const kindOf = (e: JobEvent): string => (e.type === "package_state" ? `${e.package}:${e.state}` : e.type === "reopened" || e.type === "change_requested" ? `${e.type}:${e.package ?? "-"}` : e.type);
const promptOf = (jobDir: string, pkg: string): string => {
  const t = readEvents(jobDir).filter((e) => e.type === "builder_run" && e.package === pkg).at(-1);
  return (JSON.parse(fs.readFileSync(path.join(jobDir, t?.type === "builder_run" ? t.transcript ?? "" : ""), "utf8")) as { prompt: string }).prompt;
};

test("bots by default: a new move the words say nothing about goes to its owner with the bots' use and answer in its brief, to every other bot package after the owner's merge, and onto the card", async () => {
  const jobDir = await doneJob("bots-unsaid", { package: "court", reason: "the court owns the shots", move: "lob shot", bots: "unsaid", bot_packages: ["paddle_ai"], use: "Rex lobs when the other paddle is close to the net.", answer: "Rex backs off to the baseline when he sees the dip." });
  const before = readEvents(jobDir).at(-1)?.seq ?? 0;
  const r = await run(["change", jobDir, LOB, ...FLAGS]);
  assert.equal(r.code, 0, r.text);
  const evs = since(readEvents(jobDir), before);
  const kinds = evs.map(kindOf);
  const note = evs.find((e) => e.type === "note" && e.text.startsWith(BOTS_NOTE));
  assert.ok(note?.type === "note" && note.package === "court", JSON.stringify(note));
  assert.match(note.text, /said nothing about the bots, so by default the bots use "lob shot" at sensible moments \(Rex lobs when the other paddle is close to the net\)/);
  assert.match(note.text, /answers it \(Rex backs off to the baseline when he sees the dip\)/);
  const wire = evs.find((e) => e.type === "change_requested" && e.package === "paddle_ai");
  assert.match(wire?.type === "change_requested" ? wire.text : "", /^\[foreman\] wire in court \(bots by default, change request event \d+\)/);
  // the wire waits for court: paddle_ai is re-opened only after court was promoted again
  const courtDone = kinds.lastIndexOf("court:promoted");
  const aiOpen = kinds.indexOf("reopened:paddle_ai");
  assert.ok(courtDone >= 0 && aiOpen > courtDone, kinds.join(" "));
  assert.match(promptOf(jobDir, "court"), /## The bots and the new move \(the Foreman adds this by default/);
  assert.match(promptOf(jobDir, "paddle_ai"), /wire in court \(bots by default/);
  const card = evs.find((e) => e.type === "note" && e.text.includes("[foreman] what changed in v"));
  assert.match(card?.type === "note" ? card.text : "", /\nbots by default: you said nothing about the bots, so the Foreman told them to use "lob shot" at good moments and to answer it .*\(in paddle_ai\); say "only I can do it" to keep it yours/);
  const s = rebuildState(jobDir, { write: false });
  assert.equal(s.jobState?.state, "done");
  assert.equal(s.promoted?.version, "0.1.1");
  assert.ok(s.changes.every((c) => c.state === "reopened"), JSON.stringify(s.changes));
});

test("bots by default: \"only I can do it\" turns the use off (the brief and the card say so); words that name the bots add nothing but still reach every bot package; no move, nothing added", async () => {
  const off = await doneJob("bots-off", { package: "court", reason: "the court owns the shots", move: "lob shot", bots: "only_me", bot_packages: ["paddle_ai"], answer: "Rex backs off." });
  const b0 = readEvents(off).at(-1)?.seq ?? 0;
  assert.equal((await run(["change", off, `${LOB}. Only I can do it.`, ...FLAGS])).code, 0);
  const e0 = since(readEvents(off), b0);
  const n0 = e0.find((e) => e.type === "note" && e.text.startsWith(BOTS_NOTE));
  assert.match(n0?.type === "note" ? n0.text : "", /OFF, the person said only they use "lob shot": no bot ever uses it/);
  const card = e0.find((e) => e.type === "note" && e.text.includes("[foreman] what changed in v"));
  assert.match(card?.type === "note" ? card.text : "", /\nbots by default: off, as you said: no bot uses "lob shot"/);

  const plan = (bots: string) => botsPlanOf({ move: "lob shot", bots, bot_packages: ["court", "paddle_ai"] }, [
    { id: "court", title: "", milestone: "", deps: [], files: ["data/court.json"] },
    { id: "paddle_ai", title: "", milestone: "", deps: [], files: ["data/ai.json"] },
  ]);
  const said = plan("said");
  assert.ok(said !== undefined);
  const ev = botsEvents(said, "court", 7, "the rivals lob too");
  assert.equal(ev.note, undefined, "the words already say what the bots do");
  assert.deepEqual(ev.wires.map((w) => w.package), ["paddle_ai"]);
  assert.match(ev.wires[0]?.text ?? "", /The person's words about the bots are for every package that drives a bot/);
  assert.equal(botsPlanOf({ bots: "unsaid" }, []), undefined, "no move: nothing added");
  assert.equal(botsPlanOf({ move: "lob" }, []), undefined, "no bots key: nothing added");
  assert.deepEqual(botsProblems({ bot_packages: ["ghost"] }, ["court"]).length, 1);
  assert.deepEqual(botsCardLines([{ type: "note", text: "[foreman] what changed" }]), []);
});

test("bots by default: the file-name hint finds the bot brains of the three spike games (karts, half-court, shield wall)", () => {
  const line = (id: string, files: string[]) => ({ id, title: id, milestone: "", deps: [], files });
  assert.deepEqual(botHints([line("core", ["scripts/core/brain_core.gd", "scripts/core/hop.gd"]), line("teams", ["data/ai.json", "scripts/teams/brain.gd"]), line("show", ["scripts/show/show.gd"]), line("look", ["scripts/look/hits.gd"])]), ["core", "teams"]);
  assert.deepEqual(botHints([line("court_exchange", ["scripts/core/ai.gd"]), line("bodies_first_minute", ["scripts/bodies/poses.gd"]), line("crews_stakes", ["scripts/crews/brain.gd"]), line("viaduct_art", ["scripts/arena/mod.gd"])]), ["court_exchange", "crews_stakes"]);
  assert.deepEqual(botHints([line("core", ["scripts/brain.gd", "data/ai.json"]), line("crew", ["scripts/crew/mind.gd"]), line("rally", ["scripts/rally/call.gd"]), line("harbour", ["gen/sailors.gd"])]), ["core", "crew"]);
  assert.deepEqual(botHints([line("x", ["tests/bot_ai.gd"])]), [], "tests are not brains");
});
