// E3g (25 Nov 2026), after lane E5's real job 3 (docs/shifts/2026-11-24-night/lanes/E5-proof/PROOF-E5c.md):
//   1 the rink_game base is 5,943 of lint's 6,000 game-script lines, so job 3's `banks` script package overflowed and
//     asked the person whether the limit may be raised: a pack that declares its base counts only its own lines;
//   2 the person answered "No. Leave the base alone and skip the bank-shot extras", yet the critic judged the stars and
//     DOUBLE banners: a "no" to a builder's question reaches the critic as a drop;
//   3 two starts failed after three Designer attempts each, a different small check each time: every failing check is
//     fed to the next attempt, and exact ones (a 14-word line, "75 widths", a SKIN field's spelling) are fixed without
//     the model. The answers are the real ones (foreman/fixtures/e5c/, from hk-proof's .tl/proof-jobs-c/);
//   4 "hockey where the ice has slow and fast patches and bumpers in the corners" names its own twist; job 1's concept
//     chose "score goals worth double" on top: a sentence that names its own twist gets no other twist.
// Each test failed on hokej 4d6b5ad and passes now.
import { test, after } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { PKG_ROOT, REPO_ROOT } from "../paths.js";
import { fakeRunner } from "../testing/fake-runner-core.js";
import { composeManifest, engineKnowsBase } from "../manifest.js";
import { foldEvents, type JobState } from "../joblog.js";
import type { JobEvent, PackageSpec } from "../events.js";
import { criticRubric, isRefusal, refusalsText } from "../phases.js";
import { designBrief, designerProblems, generate, type DesignerOutput } from "../designer.js";
import { retryFeedback } from "../generate.js";
import { worldUnitFix, skinFieldFix } from "../designfix.js";
import { skinFields } from "../coreroute.js";
import { methodProblems, WORLD_UNITS } from "../method.js";
import { BRIEF_LIMITS, lengthViolations, trimWords } from "../repair.js";
import { faithfulProblems, leavesTwistOpen } from "../concepts.js";
import type { Concept } from "../room_wire.js";
import { FakeBuilder } from "../builder/fake.js";
import { cleanup, tempDir } from "./helpers.js";

after(cleanup);

const ENGINE = path.join(REPO_ROOT, "engine");
const BASE = path.join(ENGINE, "templates", "rink_game");
const E5C = path.join(PKG_ROOT, "fixtures", "e5c");
const fixture = <T>(f: string): T => JSON.parse(fs.readFileSync(path.join(E5C, f), "utf8")) as T;
const SENTENCE = "hockey where the ice has slow and fast patches and bumpers in the corners";

// ---------------------------------------------------------------- 1. the base's lines are not the game's own

/** An engine directory holding only the base (templates/rink_game), and a pack copied from it. */
function basePack(declare: boolean): { engine: string; pack: string } {
  const root = tempDir("e3g-base");
  const engine = path.join(root, "engine");
  fs.cpSync(BASE, path.join(engine, "templates", "rink_game"), { recursive: true });
  const pack = path.join(root, "pack");
  fs.cpSync(BASE, pack, { recursive: true, filter: (s) => !s.endsWith(".uid") && path.basename(s) !== "README.md" }); // a job copies no README
  const m = JSON.parse(fs.readFileSync(path.join(pack, "pack.json"), "utf8")) as Record<string, unknown>;
  m["id"] = "game.e3g_banks";
  if (declare) m["base"] = "rink_game";
  fs.writeFileSync(path.join(pack, "pack.json"), JSON.stringify(m, null, 2) + "\n");
  return { engine, pack };
}
/** `total` own lines in new scripts/own_<k>.gd files of at most 550 lines each. */
function ownLines(pack: string, total: number): void {
  for (const f of fs.readdirSync(path.join(pack, "scripts"))) if (f.startsWith("own_")) fs.rmSync(path.join(pack, "scripts", f));
  for (let k = 0, n = total; n > 0; k++, n -= 550) {
    const c = Math.min(550, n);
    fs.writeFileSync(path.join(pack, "scripts", `own_${k}.gd`), ["extends RefCounted", ...Array.from({ length: c - 1 }, (_, i) => `# own line ${k}.${i}`)].join("\n") + "\n");
  }
}
function lint(engine: string, pack: string): { exit: number; size: { ok: boolean; detail: string }; layout: { ok: boolean }; errors: { kind: string; message: string }[] } {
  const report = path.join(path.dirname(pack), `lint-${Math.random().toString(36).slice(2)}.json`);
  const out = fakeRunner(["--headless", "--path", engine, "res://kernel/host/host.tscn", "--", "lint", `--pack=${pack}`, `--report=${report}`]);
  const r = JSON.parse(fs.readFileSync(report, "utf8")) as { checks: { id: string; ok: boolean; detail: string }[]; errors: { kind: string; message: string }[] };
  const size = r.checks.find((c) => c.id === "lint.size") as { ok: boolean; detail: string };
  return { exit: out.exitCode, size, layout: r.checks.find((c) => c.id === "lint.layout") as { ok: boolean }, errors: r.errors };
}

test("E3g 1: a pack that declares its base counts only its own game lines (the fake runner as lint_base.gd): base + 500 own passes, 6001 own fails, an edited base file counts its changed lines, an unknown base is a layout error", () => {
  const baseLines = fs.readdirSync(BASE, { recursive: true }).map(String).filter((f) => f.endsWith(".gd") && !f.replace(/\\/g, "/").startsWith("tests/")).reduce((a, f) => a + fs.readFileSync(path.join(BASE, f), "utf8").replace(/\r\n/g, "\n").split("\n").length - 1, 0);
  assert.ok(baseLines > 5900 && baseLines <= 6000, `the base alone is ${baseLines} of the 6000 (E5c: 5943)`);
  const without = basePack(false);
  ownLines(without.pack, 500);
  const before = lint(without.engine, without.pack);
  assert.equal(before.size.ok, false, "undeclared: the base's lines count, so 500 own lines overflow (the rule before E3g)");
  assert.ok(before.errors.some((e) => e.message.startsWith(`${baseLines + 500} lines of game GDScript (scripts/, gen/; at most 6000)`)), JSON.stringify(before.errors));

  const { engine, pack } = basePack(true);
  ownLines(pack, 500);
  const ok = lint(engine, pack);
  assert.equal(ok.exit, 0, JSON.stringify(ok.errors));
  assert.match(ok.size.detail, /\(500 game lines of its own over the base rink_game\)/);
  ownLines(pack, 6001);
  const over = lint(engine, pack);
  assert.equal(over.size.ok, false);
  assert.ok(over.errors.some((e) => e.message === `6001 lines of game GDScript of its own (scripts/, gen/; at most 6000; ${baseLines} more are the base templates/rink_game/ unchanged, not counted), 334 lines in tests/ (at most 4000)` || e.message.startsWith("6001 lines of game GDScript of its own")), JSON.stringify(over.errors));
  ownLines(pack, 5995);
  assert.equal(lint(engine, pack).size.ok, true, "5995 own lines fit");
  const main = path.join(pack, "scripts", "main.gd");
  let k = 0;
  fs.writeFileSync(main, fs.readFileSync(main, "utf8").replace(/\r\n/g, "\n").split("\n").map((l) => (k < 10 && l.startsWith("var ") ? (k++, `${l}  # edited`) : l)).join("\n"));
  const edited = lint(engine, pack);
  assert.equal(edited.size.ok, false, "ten changed lines of a base file are the pack's own");
  assert.ok(edited.errors.some((e) => e.message.startsWith("6005 lines of game GDScript of its own")), JSON.stringify(edited.errors));

  const m = JSON.parse(fs.readFileSync(path.join(pack, "pack.json"), "utf8")) as Record<string, unknown>;
  fs.writeFileSync(path.join(pack, "pack.json"), JSON.stringify({ ...m, base: "no_such_base" }, null, 2));
  const unknown = lint(engine, pack);
  assert.equal(unknown.layout.ok, false);
  assert.ok(unknown.errors.some((e) => e.kind === "layout" && e.message.startsWith("declares the base 'no_such_base', but the engine has no templates/no_such_base/")));
  fs.writeFileSync(path.join(pack, "pack.json"), JSON.stringify({ ...m, base: "../kernel" }, null, 2));
  assert.ok(lint(engine, pack).errors.some((e) => e.kind === "schema" && e.message.includes("'base'")), "a base is a plain name, never a path");
});

test("E3g 1: the Foreman writes `base` into a core game's pack.json when a base package is among its packages and the engine's lint knows the key", () => {
  const pkg = (id: string, kind?: "base"): PackageSpec => ({ id, ...(kind ? { kind } : {}), title: id, milestone: "greybox", deps: [], scope: ["scripts/**"], contract: id, acceptance: [] });
  const job = { packId: "game.pond", title: "Pond", kernelApi: "1.30", base: "rink_game" };
  assert.equal(composeManifest(job, [pkg("base", "base"), pkg("banks")]).base, "rink_game");
  assert.equal(composeManifest(job, [pkg("banks")]).base, undefined, "no base package among them: no base");
  assert.equal(composeManifest({ ...job, base: undefined }, [pkg("base", "base")]).base, undefined);
  assert.equal(engineKnowsBase(ENGINE), true, "this engine's manifest.gd knows `base`");
  const old = tempDir("e3g-old-engine");
  fs.mkdirSync(path.join(old, "kernel", "runner"), { recursive: true });
  fs.writeFileSync(path.join(old, "kernel", "runner", "manifest.gd"), 'const KEYS: Dictionary = {\n\t"moments": {"type": "shape"},\n}\n');
  assert.equal(engineKnowsBase(old), false, "an older engine would refuse the key: the Foreman leaves it out");
});

// ---------------------------------------------------------------- 2. the person's "no" reaches the critic

test("E3g 2: job 3's answer \"No. Leave the base alone and skip the bank-shot extras\" reaches the critic as a drop; a yes does not", () => {
  const ev = (seq: number, body: Record<string, unknown>): JobEvent => ({ v: 1, seq, ts: "2026-11-25T08:12:26.288Z", job: "j3", ...body }) as unknown as JobEvent;
  const question = "The pack is at 6228 of 6000 script lines with the drill, level check and end card still to write. May the limit be raised, or may a package remove comments or code from the base HUD files (scripts/hud/**) to make room?";
  const answer = "No. Leave the base alone and skip the bank-shot extras; the patches and the bumpers are what I asked for.";
  const events = [
    ev(1, { type: "job_created", sentence: SENTENCE, packId: "game.j3", title: "j3" }),
    ev(2, { type: "plan_set", packages: [{ id: "banks", title: "Bank shots count double", milestone: "greybox", deps: [], scope: ["scripts/banks.gd"], contract: "banked goals count double: a star, arrows, a red hot puck, DOUBLE", acceptance: [] }] }),
    ev(3, { type: "question", package: "banks", text: question }),
    ev(4, { type: "answer", package: "banks", text: answer, by: "player" }),
  ];
  const s = foldEvents("j3", events);
  assert.deepEqual(s.packages["banks"]?.answered, [{ question, answer }]);
  const withPitch = { ...s, brief: { pitch: "Bank it off the corner bumpers: a banked goal counts double." } } as unknown as JobState;
  const item = criticRubric(withPitch, "banks").find((r) => r.id === "fun_promise");
  assert.ok(item !== undefined);
  assert.match(item.text, /THE PERSON REFUSED, answering a builder during the build/);
  assert.ok(item.text.includes(`"${answer}"`), item.text);
  assert.match(item.text, /is DROPPED: it is not in this game, do not look for it, never score any item down or call the look NOT ok because it is missing/);
  for (const no of [answer, "no", "Skip it.", "don't add the stars", "leave them out please"]) assert.equal(isRefusal(no), true, no);
  for (const yes of ["Yes, raise it.", "Use the HUD's spare row.", "make it blue"]) assert.equal(isRefusal(yes), false, yes);
  const yes = foldEvents("j3", [...events.slice(0, 3), ev(4, { type: "answer", package: "banks", text: "Yes, raise it.", by: "player" })]);
  assert.equal(refusalsText(yes), "", "a yes is not a drop");
});

// ---------------------------------------------------------------- 3. the Designer's retries fix every check at once

const conceptJ1 = fixture<{ concept: Concept }>("concept-j1.json").concept;
const answer = (j: number, a: number): DesignerOutput => fixture<{ json: DesignerOutput }>(`designer-j${j}-a${a}.json`).json;

test("E3g 3: the real failing WORLD lines (\"75 widths long\", \"75 by 37 widths\") and a SKIN field's other spelling are fixed exactly, without the model", () => {
  for (const [j, a] of [[1, 2], [2, 2]] as const) {
    const rules = answer(j, a).brief.rules;
    assert.ok(methodProblems({ rules }).some((p) => p.startsWith("brief.rules WORLD line names no size in the player's units")), `job ${j} attempt ${a} failed on its WORLD line`);
    const fx = worldUnitFix(rules);
    assert.ok(fx !== undefined && methodProblems({ rules: fx.rules }).length === 0, fx?.rules);
    assert.ok(WORLD_UNITS.test(fx.rules));
  }
  const skin = skinFields(BASE);
  assert.ok(skin !== undefined);
  const fixed = skinFieldFix("SKIN: Team_Name = Sharks and Walruses\nSKIN: Title = Bank Shark Pond\nSKIN: nonsense = x", skin);
  assert.deepEqual(fixed?.rules.split("\n"), ["SKIN: team_names = Sharks and Walruses", "SKIN: title = Bank Shark Pond", "SKIN: nonsense = x"], "a field the base does not have stays for the model");
});

test("E3g 3: job 1's real attempts replayed: attempt 1 (three 14-word playstyle lines) passes with no repair call and attempt 2 (\"75 widths\") passes at once; before, each cost the model a call", async () => {
  const input = { sentence: SENTENCE, concept: conceptJ1 };
  const a1 = answer(1, 1);
  assert.ok(lengthViolations(a1, BRIEF_LIMITS).length === 3, "three playstyle lines over 12 words");
  const b1 = new FakeBuilder({ steps: [{ match: { role: "designer" }, json: a1 }] });
  const r1 = await designBrief(b1, input, { attempts: 3, limits: BRIEF_LIMITS });
  assert.equal(r1.ok, true, r1.ok ? "" : r1.reason);
  assert.equal(b1.calls.length, 1, `one model call, no repair: ${b1.calls.map((c) => c.req.meta?.role).join(", ")}`);
  if (r1.ok) assert.deepEqual(designerProblems(r1.value.brief, input), []);
  assert.ok(r1.calls[0]?.problems.some((p) => p.startsWith("[foreman] exact fix: brief.design.playstyles[")));
  assert.equal(trimWords("Ride the fast lane, bank early, and race your own rebound into the slot.", 12), "Ride fast lane, bank early, and race your own rebound into slot.");

  const b2 = new FakeBuilder({ steps: [{ match: { role: "designer" }, json: answer(1, 2) }] });
  const r2 = await designBrief(b2, input, { attempts: 3, limits: BRIEF_LIMITS });
  assert.equal(r2.ok, true, r2.ok ? "" : r2.reason);
  assert.equal(b2.calls.length, 1);
});

test("E3g 3: a retry hears every failing check of the attempt (schema and content together) and every check an earlier attempt failed", async () => {
  const schema = { type: "object", required: ["a", "b"], properties: { a: { type: "string" }, b: { type: "string" } } };
  const check = (v: unknown): string[] => {
    const x = v as { a?: string; b?: string; c?: string };
    return [...(x.a === "bad" ? ["a is bad"] : []), ...(x.c === "bad" ? ["c is bad"] : [])];
  };
  const b = new FakeBuilder({ steps: [
    { match: { role: "designer", attempt: 1 }, json: { a: "bad" } },
    { match: { role: "designer", attempt: 2 }, json: { a: "ok", b: "ok", c: "bad" } },
    { match: { role: "designer", attempt: 3 }, json: { a: "ok", b: "ok" } },
  ] });
  const r = await generate(b, "designer", "PROMPT{{feedback}}", {}, schema, check, { attempts: 3 });
  assert.equal(r.ok, true);
  const p2 = b.calls[1]?.req.prompt ?? "";
  assert.match(p2, /- \/ must have required property 'b'|required property 'b'/, "the schema's problem");
  assert.match(p2, /- a is bad/, "and the content check's, in the same attempt");
  const p3 = b.calls[2]?.req.prompt ?? "";
  assert.match(p3, /- c is bad/);
  assert.match(p3, /# Earlier answers were refused for these too[^]*- a is bad/, "an earlier attempt's problem stays in view");
  assert.equal(retryFeedback(["x"], ["x"]).includes("Earlier answers"), false);
});

// ---------------------------------------------------------------- 4. a sentence that names its own twist

test("E3g 4: \"hockey where the ice has slow and fast patches and bumpers\" names its own twist: job 1's concept choosing \"goals worth double\" on top is refused; an open twist stays free", () => {
  assert.equal(conceptJ1.chosen, 1, "the real concept chose candidate 2");
  const p = faithfulProblems(conceptJ1, SENTENCE, undefined, "rink_sport");
  assert.ok(p.some((x) => x.includes("name their own twist, so they ask for no other") && x.includes('"chosen": 0, not candidate 2')), p.join("\n"));
  assert.deepEqual(faithfulProblems({ ...conceptJ1, chosen: 0 }, SENTENCE, undefined, "rink_sport"), []);
  assert.equal(leavesTwistOpen(SENTENCE), false);
  for (const open of ["hockey with a twist", "crazy hockey on a pond", "a weird rink game"]) {
    assert.equal(leavesTwistOpen(open), true, open);
    assert.deepEqual(faithfulProblems(conceptJ1, open, undefined, "rink_sport"), [], open);
  }
  assert.deepEqual(faithfulProblems(conceptJ1, SENTENCE, "crazy", "rink_sport"), [], "a crazy job stays free");
});
