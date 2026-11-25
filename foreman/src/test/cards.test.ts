// Lane C (engine-world-next, 2026-11-17): recipe cards in a job (JOB.md "Added 2026-11-17", contracts/CARDS.md).
//   ref/cards/ and INDEX.md      the plan's `card` (kept, refused, omitted)      the builder brief carries the card
//   exactly as `tl cards brief` prints it      the Planner prompt names the cards and how to choose
import { test, after } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { cleanup, tempDir, tempJob, foremanFor, readEvents, fixturePhases, fixturePlan, VERBS, type TempJob } from "./helpers.js";
import { FakeBuilder } from "../builder/fake.js";
import { planCheck, planPackages, renderPlannerPrompt } from "../designer.js";
import { validateEvent, EventError, type JobEvent, type PackageSpec } from "../events.js";
import { foldEvents } from "../joblog.js";
import { prepareReference, refContents, referenceOf } from "../reference.js";
import { cardBriefSection, cardIds, cardsIndexText, cardsPlannerText, readCards } from "../cards.js";
import { runProcess } from "../proc.js";
import { listFiles } from "../scope.js";
import { FAKE_KERNEL_API_FILE, KernelApiError, kernelApiFor, kernelApiIn } from "../manifest.js";
import { FAKE_RUNNER } from "./helpers.js";
import { PKG_ROOT, REPO_ROOT, toPosix } from "../paths.js";

after(cleanup);

const CARDS = path.join(REPO_ROOT, "engine", "cards");
const TL = path.join(REPO_ROOT, "devx", "bin", "tl.mjs");
const CLI = path.join(PKG_ROOT, "dist", "cli.js");
const node = (args: string[], env: NodeJS.ProcessEnv = {}): ReturnType<typeof runProcess> =>
  runProcess({ exe: process.execPath, args, env: { ...process.env, ...env }, timeoutMs: 120_000 });
/** stdout of a `tl` command without its last line, the tl.devx/1 verdict. */
const tlText = async (args: string[]): Promise<string> => {
  const r = await node([TL, ...args]);
  assert.equal(r.exitCode, 0, r.stderr + r.stdout);
  const lines = r.stdout.replace(/\r\n/g, "\n").split("\n");
  while (lines.length > 0 && lines[lines.length - 1] === "") lines.pop();
  assert.match(lines[lines.length - 1] ?? "", /^\{"schema":"tl\.devx\/1"/);
  return lines.slice(0, -1).join("\n");
};
/** A job directory whose reference copy holds the repository's cards (and nothing else). */
function jobWithCards(label: string): TempJob {
  const job = tempJob(label);
  prepareReference(path.join(job.jobDir, "ref"), { cardsDir: CARDS });
  return job;
}
function setPlanCard(job: TempJob, card: string | undefined): void {
  const file = path.join(job.jobDir, "job.jsonl");
  const lines = fs.readFileSync(file, "utf8").split("\n").filter((l) => l.length > 0);
  const out = lines.map((l) => {
    const ev = JSON.parse(l) as JobEvent;
    if (ev.type !== "plan_set") return l;
    const next = { ...ev, ...(card !== undefined ? { card } : {}) };
    return JSON.stringify(validateEvent(next));
  });
  fs.writeFileSync(file, out.join("\n") + "\n");
}
const ids = (): string[] => readCards(CARDS).map((c) => c.card.id);

test("cards 1 ref/cards: the engine's cards are copied byte for byte, INDEX.md is the `tl cards list` table, the Planner is told they exist", async () => {
  const live = referenceOf(path.join(REPO_ROOT, "engine"));
  assert.equal(live.cardsDir, CARDS, "the live engine offers its cards");
  const ref = path.join(tempDir("cards-ref"), "ref");
  prepareReference(ref, { cardsDir: CARDS });
  const names = fs.readdirSync(CARDS).filter((n) => n.endsWith(".json")).sort();
  assert.ok(names.length >= 3);
  assert.deepEqual(fs.readdirSync(path.join(ref, "cards")).sort(), [...names, "INDEX.md"].sort());
  for (const n of names) assert.ok(fs.readFileSync(path.join(ref, "cards", n)).equals(fs.readFileSync(path.join(CARDS, n))), `${n} is a byte copy`);
  const index = fs.readFileSync(path.join(ref, "cards", "INDEX.md"), "utf8");
  assert.equal(index, cardsIndexText(readCards(CARDS).map((c) => c.card)));
  const list = await tlText(["cards", "list"]);
  assert.ok(index.includes(`\`\`\`\n${list}\n\`\`\``), `INDEX.md holds exactly the lines of \`tl cards list\`:\n${list}\n---\n${index}`);
  assert.deepEqual(refContents(ref).cards, ids());
  assert.deepEqual(cardIds(ref), ids());
  // An engine without cards gives no ref/cards/ and the Planner is told to omit `card`.
  const bare = path.join(tempDir("cards-none"), "ref");
  prepareReference(bare, { apiDoc: path.join(REPO_ROOT, "engine", "kernel", "API.md") });
  assert.equal(fs.existsSync(path.join(bare, "cards")), false);
  assert.deepEqual(cardIds(bare), []);
  assert.match(cardsPlannerText(bare), /no recipe cards: omit `card`/);
});

test("cards 2 plan check: a known card is kept, an unknown one is refused like an unknown key, an absent one is fine; the plan_set event carries it or omits it", async () => {
  const plan = fixturePlan();
  const known = { verbs: VERBS, cards: ids() };
  assert.deepEqual(planCheck(plan, known, "card.knock_down"), []);
  assert.deepEqual(planCheck(plan, known), [], "absent: no card is a valid answer");
  assert.match(planCheck(plan, known, "card.topple_tower").join("\n"), /"card": "card\.topple_tower" is not a card of this job \(ref\/cards\/ holds card\.duel, card\.knock_down/); // N2 of 22 Nov added card.duel
  assert.match(planCheck(plan, { verbs: VERBS }, "card.knock_down").join("\n"), /this job's reference copy has no cards; omit "card"/);
  assert.match(planCheck(plan, known, "").join("\n"), /must be a card id/);

  // The event: a card id is accepted, null and a malformed id are refused, absent stays absent in the state.
  const base = { v: 1, seq: 4, ts: "2026-11-17T23:00:00.000Z", job: "j", type: "plan_set", packages: plan };
  assert.equal((validateEvent({ ...base, card: "card.knock_down" }) as { card?: string }).card, "card.knock_down");
  assert.throws(() => validateEvent({ ...base, card: null }), EventError);
  assert.throws(() => validateEvent({ ...base, card: "knock_down" }), EventError);
  const created = { v: 1, seq: 1, ts: base.ts, job: "j", type: "job_created", sentence: "s", packId: "game.s", title: "S" };
  const withCard = foldEvents("j", [created, { ...base, seq: 2, card: "card.knock_down" }].map((e) => validateEvent(e)));
  assert.equal(withCard.card, "card.knock_down");
  const thenNone = foldEvents("j", [created, { ...base, seq: 2, card: "card.knock_down" }, { ...base, seq: 3 }].map((e) => validateEvent(e)));
  assert.equal(thenNone.card, undefined, "a later plan_set without card means no card");
  assert.equal("card" in thenNone, false, "absent is an omitted key, never null");
});

test("cards 3 Planner: the prompt lists every card with its applies-when and NOT-when lines and the rule to omit; an answer naming a card is kept, an unknown card is sent back with the reason", async () => {
  const ref = path.join(tempDir("cards-planner"), "ref");
  prepareReference(ref, { cardsDir: CARDS });
  const input = { sentence: "topple a tower of crates with three throws", packId: "game.topple", title: "Topple", brief: { rules: "r", arena: "a", ai: "none", controls: "throw", mood: "m" }, cards: cardsPlannerText(ref) };
  const text = renderPlannerPrompt(input, { verbs: VERBS });
  for (const { card } of readCards(CARDS)) {
    assert.ok(text.includes(`\`${card.id}\``), `${card.id} named`);
    for (const w of card.applies_when) assert.ok(text.includes(`applies when: ${w}`));
    for (const w of card.not_when ?? []) assert.ok(text.includes(`NOT when: ${w}`));
  }
  assert.match(text, /If no card fits, OMIT the `card` key/);
  assert.match(text, /"card": \{\n\s*"type": "string"/, "the schema the Planner answers with has `card`");

  const plan = fixturePlan();
  const phases = fixturePhases(); // JOB.md 2026-11-20: the Planner writes phases
  const good = new FakeBuilder({ steps: [{ match: { role: "planner" }, json: { card: "card.knock_down", packages: plan, phases } }] });
  const r = await planPackages(good, input, { verbs: VERBS, cards: cardIds(ref) });
  assert.ok(r.ok, r.ok ? "" : r.reason);
  assert.equal(r.value.card, "card.knock_down");
  const none = new FakeBuilder({ steps: [{ match: { role: "planner" }, json: { packages: plan, phases } }] });
  const n = await planPackages(none, input, { verbs: VERBS, cards: cardIds(ref) });
  assert.ok(n.ok);
  assert.equal("card" in n.value, false);
  const wrong = new FakeBuilder({
    steps: [
      { match: { role: "planner", attempt: 1 }, json: { card: "card.topple_tower", packages: plan, phases } },
      { match: { role: "planner", attempt: 2 }, json: { card: "card.knock_down", packages: plan, phases } },
    ],
  });
  const w = await planPackages(wrong, input, { verbs: VERBS, cards: cardIds(ref) });
  assert.ok(w.ok);
  assert.equal(w.calls.length, 2);
  assert.match(wrong.calls[1]?.req.prompt ?? "", /Your previous answer was rejected\n- "card": "card\.topple_tower" is not a card of this job/);
});

test("cards 4 builder brief: every builder prompt of a job whose plan names a card carries the card text byte-identical to `tl cards brief <id>`; without a card there is no card section", async () => {
  const job = jobWithCards("cards-brief");
  setPlanCard(job, "card.knock_down");
  const { foreman } = foremanFor(job, { reference: { cardsDir: CARDS } });
  const prompts = foreman.previewBuilderPrompts();
  assert.equal(prompts.length, fixturePlan().length);
  const want = await tlText(["cards", "brief", "card.knock_down"]);
  assert.match(want, /^RECIPE card\.knock_down v\d+\.\d+\.\d+: /);
  for (const p of prompts) {
    assert.ok(p.prompt.includes(`## Recipe card (the Planner chose card.knock_down for this whole job: follow it; your contract wins where the two disagree)\nPaths in the card are the engine's; read them in your reference copy: engine/seeds/seed_wall/ is ${toPosix(path.join(job.jobDir, "ref", "seeds", "seed_wall"))}/.\n${want}\n`), `package ${p.package}: the card block is byte-identical to tl cards brief`);
    assert.ok(p.prompt.indexOf("## Recipe card") < p.prompt.indexOf("## Reference material"), "the card comes before the reference list");
  }
  assert.equal(cardBriefSection(path.join(job.jobDir, "ref"), "card.knock_down").trim().split("\n").slice(2).join("\n"), want);

  const plain = jobWithCards("cards-none");
  const p2 = foremanFor(plain, { reference: { cardsDir: CARDS } }).foreman.previewBuilderPrompts();
  for (const p of p2) assert.equal(p.prompt.includes("## Recipe card"), false);
});

test("cards 5 cli: `foreman plan --from` keeps a known card in plan_set and names it; an unknown card is refused and nothing is written", async () => {
  const job = jobWithCards("cards-cli");
  const file = path.join(job.jobDir, "job.jsonl");
  // The fixture already has a plan: cut the log back to the approved brief so `plan` writes the first plan_set.
  const lines = fs.readFileSync(file, "utf8").split("\n").filter((l) => l.length > 0);
  const upTo = lines.findIndex((l) => (JSON.parse(l) as JobEvent).type === "plan_set");
  fs.writeFileSync(file, lines.slice(0, upTo).join("\n") + "\n");
  const planFile = path.join(job.root, "plan.json");
  const bad = path.join(job.root, "bad.json");
  // Since C3 a plan naming a card with hand checks registers the hand tests the card needs (court owns them here).
  const withHands = fixturePlan().map((p) => (p.id === "court" ? { ...p, scope: [...p.scope, "tests/bot_hand_idle.gd", "tests/bot_hand_perfect.gd"], registers: { tests: ["tests/bot_hand_idle.gd", "tests/bot_hand_perfect.gd"] } } : p));
  fs.writeFileSync(planFile, JSON.stringify({ card: "card.knock_down", packages: withHands }));
  fs.writeFileSync(bad, JSON.stringify({ card: "card.topple_tower", packages: fixturePlan() }));
  const before = fs.readFileSync(file, "utf8");
  const r1 = await node([CLI, "plan", job.jobDir, "--from", bad, "--no-reference"]);
  assert.equal(r1.exitCode, 1, r1.stdout + r1.stderr);
  assert.match(r1.stdout, /plan rejected:\n\s+- "card": "card\.topple_tower" is not a card of this job/);
  assert.equal(fs.readFileSync(file, "utf8"), before, "a refused plan writes nothing");
  const r2 = await node([CLI, "plan", job.jobDir, "--from", planFile, "--no-reference"]);
  assert.equal(r2.exitCode, 0, r2.stdout + r2.stderr);
  assert.match(r2.stdout, /plan set \(card card\.knock_down\): /);
  const ev = readEvents(job.jobDir).find((e) => e.type === "plan_set") as Extract<JobEvent, { type: "plan_set" }>;
  assert.equal(ev.card, "card.knock_down");
  assert.ok(fs.readFileSync(file, "utf8").includes('"card":"card.knock_down"'), "the log line records the card");
});

test("cards 6 replan: the fresh plan_set of a re-plan repeats the job's card", async () => {
  const job = jobWithCards("cards-replan");
  setPlanCard(job, "card.knock_down");
  const plan = fixturePlan();
  const brokenMain = "extends Node\nfunc _pack_tick(frame):\n\tFAKE_SCRIPT_ERROR()\n";
  const builder = new FakeBuilder({ steps: [{ match: { role: "builder" }, write: { "scripts/main.gd": brokenMain, "tests/bot_rally.gd": "extends Node\n" }, text: "Done." }] });
  const { foreman } = foremanFor(job, {
    builder,
    reference: { cardsDir: CARDS },
    roundLimit: 1,
    maxReplans: 1,
    replanner: async (input) => {
      const root = { ...(JSON.parse(JSON.stringify(plan[0])) as PackageSpec), id: "core2" };
      return { ok: true, value: { packages: [root, ...input.dependants.map((d) => ({ ...d, deps: ["core2"] }))] }, calls: [] };
    },
  });
  await foreman.run();
  const sets = readEvents(job.jobDir).filter((e) => e.type === "plan_set") as Extract<JobEvent, { type: "plan_set" }>[];
  assert.equal(sets.length, 2, "the job was re-planned once");
  for (const s of sets) assert.equal(s.card, "card.knock_down");
});

test("cards 7 kernel version: every pack.json declares the KERNEL_API of the engine it was built against, read from <engine>/kernel/runner/manifest.gd; no constant in the Foreman", async () => {
  // The repository's engine: the value is whatever its manifest.gd says (1.5 tonight), read the same way here.
  const liveSrc = fs.readFileSync(path.join(REPO_ROOT, "engine", "kernel", "runner", "manifest.gd"), "utf8");
  const liveWant = /^const KERNEL_API: String = "(\d+\.\d+)"/m.exec(liveSrc)?.[1];
  assert.ok(liveWant, "engine/kernel/runner/manifest.gd declares KERNEL_API");
  assert.equal(kernelApiFor({ exe: "godot.exe", preArgs: [], engineDir: path.join(REPO_ROOT, "engine") }), liveWant);
  assert.equal(kernelApiIn('const KERNEL_API: String = "0.1"\n'), "0.1", "an old snapshot says what it offered");
  assert.equal(kernelApiIn("# KERNEL_API is not declared here\n"), undefined);
  // A real runner on an engine without the file (or without the constant) cannot build: the version is unknown.
  const bare = tempDir("api-bare");
  assert.throws(() => kernelApiFor({ exe: "godot.exe", preArgs: [], engineDir: bare }), (e: unknown) => e instanceof KernelApiError && /no .*kernel\/runner\/manifest\.gd/.test(e.message));
  fs.mkdirSync(path.join(bare, "kernel", "runner"), { recursive: true });
  fs.writeFileSync(path.join(bare, "kernel", "runner", "manifest.gd"), "extends RefCounted\n");
  assert.throws(() => kernelApiFor({ exe: "godot.exe", preArgs: [], engineDir: bare }), /declares no `const KERNEL_API/);
  // The Foreman's source holds no version of its own.
  assert.doesNotMatch(fs.readFileSync(path.join(PKG_ROOT, "src", "manifest.ts"), "utf8"), /KERNEL_API\s*=\s*"\d/);

  // A whole fake job against an engine that says 1.7: pack/pack.json and the promoted manifest say 1.7.
  const job = tempJob("api-engine");
  fs.mkdirSync(path.join(job.engineDir, "kernel", "runner"), { recursive: true });
  fs.writeFileSync(path.join(job.engineDir, "kernel", "runner", "manifest.gd"), 'extends RefCounted\nconst KERNEL_API: String = "1.7"\n');
  const s = await foremanFor(job, { promoteTo: "job" }).foreman.run();
  assert.equal(s.jobState?.state, "done", s.jobState?.reason);
  const packJson = JSON.parse(fs.readFileSync(path.join(job.jobDir, "pack", "pack.json"), "utf8")) as { kernelApi: string };
  assert.equal(packJson.kernelApi, "1.7");
  const promoted = s.promotions[s.promotions.length - 1];
  assert.ok(promoted);
  const promotedJson = JSON.parse(fs.readFileSync(path.join(job.jobDir, "promoted", "game.paddle_court", "pack.json"), "utf8")) as { kernelApi: string };
  assert.equal(promotedJson.kernelApi, "1.7");
  // The bundled fake runner with an empty engine directory reads the fake engine's own file.
  assert.equal(kernelApiFor({ exe: process.execPath, preArgs: [FAKE_RUNNER], engineDir: tempDir("api-empty") }), kernelApiIn(fs.readFileSync(FAKE_KERNEL_API_FILE, "utf8")));
});

test("cards 8 house pack: the reference copies a house game a card names (hockey for card.team_possession) whole to ref/packs/<name>/, and that card's brief points there", async () => {
  const live = referenceOf(path.join(REPO_ROOT, "engine"));
  const hockey = path.join(REPO_ROOT, "engine", "packs", "hockey");
  // N2 of 22 Nov: card.duel names the duel house game, so it travels too.
  // E3 of 24 Nov: card.rink_core names hokej, the rink core's house game.
  assert.deepEqual(live.housePacks, [path.join(REPO_ROOT, "engine", "packs", "duel"), hockey, path.join(REPO_ROOT, "engine", "packs", "hokej")], "only the house games a card names");
  const ref = path.join(tempDir("cards-house"), "ref");
  prepareReference(ref, { cardsDir: CARDS, housePacks: [hockey] });
  const want = listFiles(hockey).sort();
  assert.deepEqual(listFiles(path.join(ref, "packs", "hockey")).sort(), want, "the whole pack, file for file");
  for (const f of want) assert.ok(fs.readFileSync(path.join(ref, "packs", "hockey", f)).equals(fs.readFileSync(path.join(hockey, f))), f);
  assert.deepEqual(refContents(ref).packs, ["hockey"]);
  const bytes = want.reduce((n, f) => n + fs.statSync(path.join(hockey, f)).size, 0);
  assert.ok(bytes < 1_000_000, `hockey is ${bytes} bytes in ${want.length} files: small enough to copy whole`);
  const section = cardBriefSection(ref, "card.team_possession");
  assert.ok(section.includes(`engine/packs/hockey/ is ${toPosix(path.join(ref, "packs", "hockey"))}/.`), section.slice(0, 400));
  assert.ok(section.includes("Start from: engine/packs/hockey/ (copy its shape"));
});
