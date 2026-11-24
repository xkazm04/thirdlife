// E4 (night of 24-25 Nov 2026): a change request may grow the game (grow.ts). The phases fixture is built to done
// (three passes), then two change rounds as a person makes them in Create: "add rocket skates" (the owner question
// answers "new": the Planner adds the package rocket and wires it into core) and "the rallies are too slow" (the owner
// question names court: the old path). Each round ends with a new promotion; earlier promotions are kept.
import { test, after } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { main } from "../cli.js";
import { rebuildState } from "../joblog.js";
import { growProblems, ownerOrNew, wireWaits, NEW_PACKAGE } from "../grow.js";
import { FakeBuilder } from "../builder/fake.js";
import { iterateJob, GROW_TEXT, CHANGE_TEXT } from "../testing/grow-steps.js";
import { cleanup, tempDir, readEvents, VERBS } from "./helpers.js";
import type { JobEvent, PackageSpec } from "../events.js";

after(cleanup);

const run = async (argv: string[]): Promise<{ code: number; text: string }> => {
  const lines: string[] = [];
  const code = await main(argv, (s) => lines.push(s));
  return { code, text: lines.join("\n") };
};
const FLAGS = ["--adapter", "fake", "--quiet", "--parallel", "1"];

async function doneJob(label: string): Promise<string> {
  const jobDir = path.join(tempDir(label), "site", "paddle-court-crazy-20261121-1");
  iterateJob(jobDir);
  assert.equal((await run(["run", jobDir, ...FLAGS])).code, 3);
  for (let i = 0; i < 3; i++) await run(["phase", jobDir, "pass", ...FLAGS]);
  const s = rebuildState(jobDir, { write: false });
  assert.equal(s.jobState?.state, "done");
  return jobDir;
}

const since = (evs: JobEvent[], seq: number): JobEvent[] => evs.filter((e) => e.seq > seq);

test("grow: a change that adds something new adds a package (plan_set, reopened, queued round 1), wires it into core after its merge, and promotes 0.1.1; a later change takes the old path to court and promotes 0.1.2", async () => {
  const jobDir = await doneJob("grow-walk");
  const before = readEvents(jobDir).at(-1)?.seq ?? 0;
  const r1 = await run(["change", jobDir, GROW_TEXT, ...FLAGS]);
  assert.equal(r1.code, 0, r1.text);
  const evs = since(readEvents(jobDir), before);
  const kinds = evs.map((e) => (e.type === "package_state" ? `${e.package}:${e.state}:${e.round}` : e.type === "reopened" || e.type === "change_requested" ? `${e.type}:${e.package ?? "-"}` : e.type));
  const plan = evs.find((e) => e.type === "plan_set");
  assert.ok(plan?.type === "plan_set");
  assert.deepEqual(plan.packages.map((p) => p.id), ["core", "court", "paddle_ai", "fx", "rocket"]);
  assert.deepEqual(plan.phases?.map((p) => [p.id, p.packages]), [["court_plays", ["core", "court"]], ["rival", ["paddle_ai"]], ["magnet", ["fx", "rocket"]]], "the new package joins the last phase");
  const req = evs.find((e) => e.type === "change_requested");
  const opened = evs.find((e) => e.type === "reopened" && e.package === "rocket");
  assert.ok((opened?.type === "reopened" ? opened.reason : "").startsWith(`change request (event ${req?.seq}); the Planner adds a package for it`), JSON.stringify(opened));
  assert.ok(kinds.indexOf("rocket:queued:1") > kinds.indexOf("reopened:rocket"), kinds.join(" "));
  const wire = evs.find((e) => e.type === "change_requested" && e.package === "core");
  assert.match(wire?.type === "change_requested" ? wire.text : "", /^\[foreman\] wire in rocket \(added for change request event \d+/);
  // the wire waits for rocket: core is re-opened only after rocket was promoted
  const rocketDone = kinds.indexOf("rocket:promoted:1");
  const coreOpen = kinds.indexOf("reopened:core");
  assert.ok(rocketDone >= 0 && coreOpen > rocketDone, kinds.join(" "));
  const s = rebuildState(jobDir, { write: false });
  assert.equal(s.jobState?.state, "done");
  assert.equal(s.promoted?.version, "0.1.1");
  assert.ok(s.changes.every((c) => c.state === "reopened"), JSON.stringify(s.changes));
  assert.match(fs.readFileSync(path.join(jobDir, "promoted", "game.paddle_court_crazy@0.1.1", "scripts", "main.gd"), "utf8"), /rocket skates/);
  assert.ok(fs.existsSync(path.join(jobDir, "promoted", "game.paddle_court_crazy@0.1.1", "scripts", "rocket.gd")));
  assert.ok(fs.existsSync(path.join(jobDir, "promoted", "game.paddle_court_crazy", "pack.json")), "the first promotion is kept");
  const transcript = readEvents(jobDir).filter((e) => e.type === "builder_run" && e.package === "rocket").at(-1);
  const prompt = (JSON.parse(fs.readFileSync(path.join(jobDir, transcript?.type === "builder_run" ? transcript.transcript ?? "" : ""), "utf8")) as { prompt: string }).prompt;
  assert.match(prompt, /add rocket skates/, "the player's words are in the new package's brief");

  // the old path: the owner question names court
  const mid = readEvents(jobDir).at(-1)?.seq ?? 0;
  const r2 = await run(["change", jobDir, CHANGE_TEXT, ...FLAGS]);
  assert.equal(r2.code, 0, r2.text);
  const e2 = since(readEvents(jobDir), mid);
  assert.ok(!e2.some((e) => e.type === "plan_set"), "no growth for a change a package owns");
  assert.ok(e2.some((e) => e.type === "reopened" && e.package === "court"));
  const s2 = rebuildState(jobDir, { write: false });
  assert.equal(s2.promoted?.version, "0.1.2");
  assert.equal(s2.jobState?.state, "done");
});

test("grow: the owner question takes a package id or \"new\" and nothing else; a growth answer may not reuse a kept id or wire a package that does not exist; a wire request waits while its package is not promoted", async () => {
  const lines = [{ id: "core", title: "Core", milestone: "blockout", deps: [], files: ["scripts/main.gd"] }];
  const b = new FakeBuilder({ steps: [{ match: { attempt: 1 }, json: { package: "boots", reason: "x" } }, { json: { package: NEW_PACKAGE, reason: "a new mechanic" } }] });
  const r = await ownerOrNew(b, { sentence: "s", title: "t", text: "add boots", packages: lines });
  assert.ok(r.ok && r.value.package === NEW_PACKAGE, JSON.stringify(r));
  assert.match(r.calls[0]?.problems.join(" ") ?? "", /must be one of: core, or "new"/);
  assert.match(r.calls[0]?.prompt ?? "", /Decide which ONE package owns/);
  const kept: PackageSpec[] = [{ id: "core", title: "Core", milestone: "blockout", deps: [], scope: ["scripts/main.gd"], contract: "c", acceptance: [{ level: "V1", verb: "lint", args: [] }] }];
  const fresh: PackageSpec = { id: "core", title: "Again", milestone: "tuned", deps: ["core"], scope: ["data/x.json"], contract: "c", acceptance: [{ level: "V1", verb: "lint", args: [] }] };
  const p = growProblems({ packages: [fresh], wire: ["ghost"] }, kept, { verbs: VERBS });
  assert.ok(p.some((x) => x.includes('belongs to a kept package')) && p.some((x) => x.includes('wire names "ghost"')), p.join("; "));
  const st = { packages: { rocket: { state: "running" } } } as unknown as Parameters<typeof wireWaits>[0];
  assert.equal(wireWaits(st, "[foreman] wire in rocket (added for change request event 9; new: rocket): call it"), true);
  assert.equal(wireWaits({ packages: { rocket: { state: "promoted" } } } as unknown as Parameters<typeof wireWaits>[0], "[foreman] wire in rocket (x)"), false);
  assert.equal(wireWaits(st, "make it faster"), false);
});
