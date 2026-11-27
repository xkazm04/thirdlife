// D27 of the juice day of 27 Nov 2026 (lane T-editor): what the night's juice lanes met in the editor. Each test failed
// on main 8be26d61 and passes now. Sentences and builder notes are the night's own (fixtures/d27: lanes J19 and J1).
import { test, after } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { cleanup, foremanFor, readEvents, scriptWith, tempDir, tempJob } from "./helpers.js";
import type { FakeStep } from "../builder/fake.js";
import type { JobEvent, PackageSpec } from "../events.js";
import type { GateHost } from "../p10gate.js";
import { JobLog } from "../joblog.js";
import { REPO_ROOT } from "../paths.js";
import { grantedScope, sidecarOf, widenedNote, withGrants } from "../scopegrant.js";
import { mindFiles, rivalSentences, rivalSplit } from "../rivals.js";
import { NOT_DONE, NOT_MADE, REST_OF, afterMerge, coreHintOf } from "../halfmade.js";
import { catalogRows, keyHint, keysFor } from "../keyfind.js";
import { coreExcerpt, RINK_ROUTE } from "../coreroute.js";
import { MOVES_LAND, finalLandNotes, judgeLanding, landGate, newMovesOf } from "../landcheck.js";
import { BALANCE_MOVED, balanceLines, changeKind } from "../boundlift.js";
import { NOT_ASKED, UNASKED_RULE, changedFiles, measureKeptWords, removedInRound, whatChangedNote } from "../fastchange.js";

after(cleanup);

const fixture = <T>(name: string): T => JSON.parse(fs.readFileSync(path.join(REPO_ROOT, "foreman", "fixtures", "d27", name), "utf8")) as T;
const J19 = fixture<{ plan: PackageSpec[]; merged: Record<string, string[]>; events: JobEvent[] }>("j19-core-r14.json");
const J1 = fixture<{ plan: PackageSpec[]; events: JobEvent[] }>("j1-harbour-r15.json");
const J19_SENTENCE = (J19.events[0] as { text: string }).text;
const J19_NOTE = (J19.events[1] as { text: string }).text;
const J1_REQUEST = (J1.events[0] as { text: string }).text;

// ---------------------------------------------------------------- 1. the rivals' words reach every bot package

test("D27 1 (J19 events 593-619: \"The rivals charge an open line, raise shields when charged, slam a crowd and run out of the ring\" went to core only, and 4 of 5 bots think in crew's scripts/crew/mind.gd): the rivals' sentence also goes to every other package whose files drive a bot", () => {
  assert.equal(rivalSentences(J19_SENTENCE), "The rivals charge an open line, raise shields when charged, slam a crowd and run out of the ring.");
  const merged = (id: string) => J19.merged[id];
  assert.deepEqual(mindFiles(J19.plan.find((p) => p.id === "crew") as PackageSpec, merged("crew")), ["scripts/crew/mind.gd"]);
  assert.deepEqual(mindFiles(J19.plan.find((p) => p.id === "core") as PackageSpec, merged("core")), ["data/ai.json", "scripts/brain.gd"]);
  const split = rivalSplit(J19.plan, merged, "core", 593, J19_SENTENCE);
  assert.deepEqual(split.map((r) => r.package), ["crew"], "rally and harbour drive no bot");
  assert.match(split[0]?.text ?? "", /^\[foreman\] the rivals' part of change request 593, for the bots your files drive \(scripts\/crew\/mind\.gd\): "The rivals charge an open line/);
  assert.match(split[0]?.text ?? "", /your package runs after its merge/, "crew depends on core: it builds on core's new moves");
  // the other way round: a change crew owns still reaches Bram's brain in core
  assert.deepEqual(rivalSplit(J19.plan, merged, "crew", 700, "The rivals must slam a crowd too.").map((r) => r.package), ["core"]);
  // nothing nobody asked for: no rival sentence, or one about their look only
  assert.deepEqual(rivalSplit(J19.plan, merged, "core", 1, "Give every fighter a shield charge on F and a leaping slam on C."), []);
  assert.deepEqual(rivalSplit(J19.plan, merged, "core", 1, "The rivals wear mustard-gold jackets."), []);
  // what happens TO the rivals is not a bot's line; what they do is (J1's and J4's sentences)
  assert.equal(rivalSentences(J1_REQUEST), "The rival bots should try a meteor of their own from distance, and dive in front of mine to block it.");
  assert.equal(rivalSentences("Add NBA Jam's on fire: a player who scores twice in a row catches fire until the other side scores: the ball trails flames, the player glows, the screen says ON FIRE, their jumps go even higher and their shots fall more easily. Defenders double-team whoever is on fire."), "Defenders double-team whoever is on fire.", "J4's A3: \"until the other side scores\" says nothing a bot does");
});

test("D27 1b: through the Foreman, a change the Planner gives to core re-opens the rival paddle's package with the rivals' words, and it merges after core", async () => {
  const job = tempJob("d27-rivals");
  assert.equal((await foremanFor(job, { promoteTo: "job" }).foreman.run()).jobState?.state, "done");
  const log = JobLog.open(job.jobDir);
  log.append({ type: "change_requested", text: "Make the ball fly twice as fast off a paddle. The rival paddle charges the ball and slams it back at my goal." });
  log.close();
  const from = readEvents(job.jobDir).at(-1)?.seq ?? 0;
  const steps: FakeStep[] = [
    { match: { role: "planner", promptIncludes: "Decide which ONE package owns" }, json: { package: "core", reason: "the ball's speed off a paddle is the core's" } },
    { match: { role: "builder", package: "core" }, write: { "scripts/main.gd": "extends Node\n# ball x2\n" }, text: "Done.\nDEVIATIONS: none" },
    { match: { role: "builder", package: "paddle_ai" }, write: { "data/ai.json": "{\"speed\": 1.0, \"charge\": true}\n" }, text: "Done.\nDEVIATIONS: none" },
  ];
  const s = await foremanFor(job, { promoteTo: "job", script: scriptWith(steps) }).foreman.run();
  assert.equal(s.jobState?.state, "done", JSON.stringify(s.jobState));
  const later = readEvents(job.jobDir).filter((e) => e.seq > from);
  const part = later.find((e) => e.type === "change_requested" && e.package === "paddle_ai");
  assert.match(part?.type === "change_requested" ? part.text : "", /^\[foreman\] the rivals' part of change request \d+, for the bots your files drive \(data\/ai\.json, scripts\/paddle_ai\.gd\): "The rival paddle charges the ball and slams it back at my goal\."/);
  assert.ok(later.some((e) => e.type === "reopened" && e.package === "paddle_ai"), "the rival paddle's package was asked");
  const coreMerge = later.find((e) => e.type === "merge" && e.package === "core")?.seq ?? Infinity;
  const aiMerge = later.find((e) => e.type === "merge" && e.package === "paddle_ai")?.seq ?? -1;
  assert.ok(aiMerge > coreMerge, `paddle_ai merged after core (${aiMerge} > ${coreMerge})`);
  const reason = later.find((e) => e.type === "reopened" && e.package === "core");
  assert.match(reason?.type === "reopened" ? reason.reason : "", /drives bots too \(data\/ai\.json, scripts\/paddle_ai\.gd\), so they go to it as well/);
  // the person's words appear once in what changed: the Foreman's part is not a second ask
  const wc = later.filter((e) => e.type === "note" && e.text.startsWith("[foreman] what changed in")).at(-1);
  assert.equal(((wc?.type === "note" ? wc.text : "").match(/The rival paddle charges/g) ?? []).length, 1);
});

// ---------------------------------------------------------------- 2. a hand-off is carried to the cartridge's owner

const reopened = J1.events[1] as JobEvent;
const note = J1.events[2] as JobEvent & { text: string };

test("D27 2 (J1 events 1008, 1012, 1039-1042: the drawing package's builder wrote \"RULE: not done ... It needs `data/harbour.cartridge.json`, which is outside my scope\" with the exact edit, and v0.1.22 was promoted without it): the line is read as not done and goes on to the cartridge's owner, never the base", () => {
  const lines = note.text.split("\n").map((l) => l.replace(/^\s*-\s*/, ""));
  assert.ok(NOT_DONE.test(lines[0] as string) && NOT_DONE.test(lines[1] as string) && NOT_DONE.test(lines[2] as string), "the three RULE: not done lines");
  assert.ok(!NOT_DONE.test("The bot is not done inside its frame budget unless the match ends."), "a sentence that merely contains the words is not a hand-off");
  const out = afterMerge(J1.plan, J1.events, "harbour", 15, ["data/tuning.json", "scripts/harbour_toys.gd"], J1_REQUEST);
  const asked = out.filter((e) => e["type"] === "change_requested");
  assert.deepEqual(asked.map((e) => e["package"]), ["cartridge"], "the cartridge package owns data/harbour.cartridge.json; the base's data/** does not take it");
  assert.match(String(asked[0]?.["text"]), new RegExp(`^\\[foreman\\] ${REST_OF}, which harbour did not make \\("RULE: not done\\. This is the part that changes how the match plays`));
  assert.ok(String(asked[0]?.["text"]).includes(J1_REQUEST), "with the person's words whole");
  assert.match(String(out.find((e) => e["type"] === "note")?.["text"]), new RegExp(`^\\[foreman\\] ${NOT_MADE} by harbour; it goes on to cartridge`));
});

test("D27 2b: the what-changed card no longer lists a builder's \"RULE: not done\" line as an unasked rule or as what you will see", () => {
  const events = [
    { seq: 1003, type: "promoted", packId: "game.x", version: "0.1.21", dest: "promoted/game.x@0.1.21" },
    ...J1.events,
    ...afterMerge(J1.plan, J1.events, "harbour", 15, ["data/tuning.json"], J1_REQUEST).map((e, i) => ({ seq: 1027 + i, ...e })),
  ] as unknown as JobEvent[];
  const card = whatChangedNote(events, "0.1.22");
  const first = card.split("\n")[0] ?? "";
  assert.doesNotMatch(first, /not done/i, first);
  assert.ok(!card.split("\n").some((l) => l.startsWith(UNASKED_RULE) && /not done/i.test(l)), card);
  assert.match(card, /\npart of your change was NOT made by harbour; it goes on to cartridge/);
});

// ---------------------------------------------------------------- 3. "no key" is checked against the catalog

test("D27 3 (J1 event 1012: \"RULE: not done, and the cartridge has no key for it ... winding up longer for a harder shot, being easier to knock over while winding up\"; CARTRIDGE.md:109-110 and :394 have both): the catalog's rows go with the carried request, and the builder is told to read the catalog first", () => {
  const md = fs.readFileSync(path.join(REPO_ROOT, "engine", "cores", "rink", "CARTRIDGE.md"), "utf8");
  const rows = catalogRows(md);
  const line = note.text.split("\n")[1] as string;
  const keys = keysFor(rows, line).flatMap((r) => r.keys);
  assert.ok(keys.includes("shot.charge_frames_max") || keys.includes("game.shot.charge_frames_max"), keys.join(", "));
  assert.ok(keys.includes("game.contact.spin_stability"), keys.join(", "));
  assert.equal(keyHint(rows, "The flash is drawn at the puck.", "x"), "", "a line that claims no missing key gets no hint");
  // through afterMerge, with the job's reference copy of the catalog
  const dir = tempDir("d27-keys");
  fs.mkdirSync(path.join(dir, "ref", "cores", "rink"), { recursive: true });
  fs.writeFileSync(path.join(dir, "ref", "cores", "rink", "CARTRIDGE.md"), md);
  const hint = coreHintOf(J1.plan, { core: "rink" }, (...p: string[]) => path.join(dir, ...p));
  assert.equal(hint?.cartridgeOwner, "cartridge");
  const text = String(afterMerge(J1.plan, J1.events, "harbour", 15, ["data/tuning.json"], J1_REQUEST, hint).find((e) => e["type"] === "change_requested")?.["text"]);
  assert.match(text, /harbour said the cartridge has no key for part of it, but the catalog \(ref\/cores\/rink\/CARTRIDGE\.md\) has keys that may be exactly that: [^"]*spin_stability/);
  assert.ok(text.length <= 3000);
  // the builder of every package on the core reads it in its prompt
  const builder = coreExcerpt({ id: "rink_game", title: "rink" }, RINK_ROUTE, "builder");
  assert.match(builder, /Read the catalog before you say a key is missing/);
  assert.match(builder, /NOT DONE: <what the person asked> needs <that file>, which is outside my scope/);
});

// ---------------------------------------------------------------- 4. a new attack must land in the bot run

function landHost(change: string, counts: Record<string, unknown> | undefined, round = 14, roundBase = 14) {
  const dir = tempDir("d27-land");
  fs.mkdirSync(path.join(dir, "reports"), { recursive: true });
  fs.writeFileSync(path.join(dir, "reports", "core-r14-bot-s614.json"), JSON.stringify({ bot: { test: "tests/bot_tofu.gd", done: true, result: { ok: true, metrics: { tells: 80 } } } }));
  fs.writeFileSync(path.join(dir, "reports", "core-r14-bot-s615.json"), JSON.stringify({ bot: { test: "tests/bot_player.gd", done: true, result: { ok: true, ...(counts !== undefined ? { metrics: { moves: counts } } : {}) } } }));
  const events = [
    { seq: 591, type: "promoted", packId: "game.shield_wall_3_v", version: "0.1.4", dest: "promoted/game.shield_wall_3_v@0.1.4" },
    { seq: 593, type: "change_requested", text: change },
    { seq: 600, type: "note", package: "core", round: 14, text: J19_NOTE },
    { seq: 614, type: "verify", package: "core", round, level: "V4", verb: "bot", ok: true, report: "reports/core-r14-bot-s614.json" },
    { seq: 615, type: "verify", package: "core", round, level: "V4", verb: "bot", ok: true, report: "reports/core-r14-bot-s615.json" },
  ] as unknown as JobEvent[];
  const appended: Record<string, unknown>[] = [];
  const h = {
    s: { plan: J19.plan.map((p) => (p.id === "core" ? { ...p, contract: "TOFU CHECK: tests/bot_tofu.gd reports metrics feedback_f" } : p)), lastSeq: 615 },
    events,
    pkg: () => ({ round, roundBase }),
    dir: (...p: string[]) => path.join(dir, ...p),
    rel: (abs: string) => path.relative(dir, abs).split(path.sep).join("/"),
    append: (e: Record<string, unknown>) => (appended.push(e), events.push({ seq: 700 + appended.length, ...e } as unknown as JobEvent), e as unknown as JobEvent),
  } as unknown as GateHost;
  return { h, appended };
}

test("D27 4 (J19: the charge's reach 1.15 m against a 1.4 m pushbox gap, 0 knockdowns from 15 rushes, and v0.1.5 promoted): a new attack the person asked for must land at least once in the Foreman's bot run, or the round goes back to the builder", () => {
  assert.deepEqual(newMovesOf(J19_NOTE), ["rush", "slam"], "the clip names in brackets are not moves");
  assert.deepEqual(newMovesOf("Done.\nDEVIATIONS:\n- NEW MOVE: meteor (F, a shotgun shot)\n- NEW MOVE: `dive`"), ["meteor", "dive"]);
  // J19's case: the charge is used and never lands
  const never = landHost(J19_SENTENCE, { rush: { started: 15, landed: 0, last_f: 8900 }, slam: { started: 4, landed: 3, last_f: 8800 } });
  const r = landGate(never.h, "core", 14);
  assert.equal(r?.ok, false);
  assert.match(r?.summary ?? "", /rush landed 0 of 15 \(0 %\): a move that never lands is not made\. Find why it misses in the game \(its reach against how close the bodies can get/);
  assert.doesNotMatch(r?.summary ?? "", /slam landed/, "the slam lands: only the charge is sent back");
  assert.ok(never.appended.some((e) => e["type"] === "verify" && e["ok"] === false && String(e["report"]).includes("core-r14-move-lands")), "a failed check of its own: the next round's feedback reads it");
  // not counted at all: the builder is told how to count it, in a test its acceptance runs (not the tofu bot)
  const none = landGate(landHost(J19_SENTENCE, undefined).h, "core", 14);
  assert.match(none?.summary ?? "", /no bot test of your package reports moves\.rush, moves\.slam: add `"moves": \{"rush": \{"started": <n>, "landed": <n>\}\}` to the metrics of a bot test your acceptance runs \(tests\/bot_player\.gd\)/);
  // it lands: the round goes on, and the person's note has the figures
  const lands = landHost(J19_SENTENCE, { rush: { started: 9, landed: 4, last_f: 8900 }, slam: { started: 5, landed: 3, last_f: 8700 } });
  assert.equal(landGate(lands.h, "core", 14), undefined);
  assert.equal(lands.appended[0]?.["text"], `${MOVES_LAND}: rush landed 4 of 9 (44 %), slam landed 3 of 5 (60 %) (tests/bot_tofu.gd, tests/bot_player.gd)`);
  // after the revise budget the round merges and the person is told it was not made
  const spent = landHost(J19_SENTENCE, { rush: { started: 15, landed: 0, last_f: 8900 }, slam: { started: 4, landed: 5, last_f: 8800 } }, 16, 14);
  assert.equal(landGate(spent.h, "core", 16), undefined);
  assert.match(String(spent.appended[0]?.["text"]), new RegExp(`^\\[foreman\\] ${NOT_MADE} by core: the new move rush does not land in the Foreman's bot run \\(rush landed 0 of 15 \\(0 %\\), slam landed 4 of 4 \\(100 %\\)\\) after 3 rounds`));
  // nothing asked of a change that names no attack, or of a look change
  assert.equal(landGate(landHost("Quilted jackets for the sailors and gold shields.", undefined).h, "core", 14), undefined);
  // a move counted without `landed` is a move that does not hit (a brace): used, not judged on landing
  assert.equal(judgeLanding(["brace"], [{ test: "t", report: { bot: { result: { metrics: { moves: { brace: { started: 3 } } } } } } }]).ok, true);
});

// ---------------------------------------------------------------- 5. words on the screen

test("D27 5 (J4: the ON FIRE tag ran into the clock in the score line; v0.1.6's banner sat on a tall black slab of blank lines): every builder is told where an impact word goes, and every card's juice says it", () => {
  const prompt = fs.readFileSync(path.join(REPO_ROOT, "foreman", "prompts", "builder.md"), "utf8");
  assert.match(prompt, /\*\*Words on the screen\.\*\* An impact word or a banner \(SLAM!, ON FIRE, REJECTED!, GOAL!\) goes in big letters in the\s+middle of the screen, apart from the score and the clock/);
  assert.match(prompt, /never pad a label with blank lines or spaces/);
  const cards = path.join(REPO_ROOT, "engine", "cards");
  for (const f of fs.readdirSync(cards).filter((x) => x.endsWith(".json"))) {
    const card = JSON.parse(fs.readFileSync(path.join(cards, f), "utf8")) as { fun?: { juice?: string[] } };
    const juice = card.fun?.juice ?? [];
    assert.ok(juice.some((l) => /middle of the screen, apart from the score and the clock/.test(l)), `${f}: ${juice.join(" | ")}`);
  }
});

// ---------------------------------------------------------------- 6. every balance note of a change

test("D27 6 (T2's robot job: \"matches now run longer\" (event 1203) was lost behind the newer hand-check line (event 1260) on the card): every thing a change moved is told, the newest line of each", () => {
  const longer = `${BALANCE_MOVED}: built as you asked; matches now run longer (the Foreman's test needed about 2 times the frames it planned). Say "make matches shorter" to tune it.\nfigures (...)`;
  const hand1 = `${BALANCE_MOVED}: built as you asked; a newcomer player now wins 9 of 20 (was 17 of 20). Say "make it fairer" to tune it.\nfigures (...)`;
  const hand2 = `${BALANCE_MOVED}: built as you asked; a newcomer player now wins 11 of 20 (was 17 of 20). Say "make it fairer" to tune it.\nfigures (...)`;
  const events = [
    { seq: 1, type: "promoted", packId: "game.x", version: "0.1.5", dest: "promoted/game.x@0.1.5" },
    { seq: 2, type: "change_requested", text: "Give every robot a double-sledged hammer." },
    { seq: 3, type: "note", package: "show", round: 7, text: longer },
    { seq: 4, type: "note", package: "core", round: 18, text: hand1 },
    { seq: 5, type: "note", package: "core", round: 18, text: hand2 },
    { seq: 6, type: "merge", package: "core", files: ["scripts/hammer.gd"] },
  ] as unknown as JobEvent[];
  const lines = whatChangedNote(events, "0.1.6").split("\n").filter((l) => l.startsWith("balance moved"));
  assert.deepEqual(lines, [
    "balance moved by your change: built as you asked; matches now run longer (the Foreman's test needed about 2 times the frames it planned). Say \"make matches shorter\" to tune it.",
    "balance moved by your change: built as you asked; a newcomer player now wins 11 of 20 (was 17 of 20). Say \"make it fairer\" to tune it.",
  ]);
  assert.deepEqual(balanceLines(["a now 1", "b now 2", "a now 3"]), ["a now 3", "b now 2"]);
});

test("D27 4b (the d27 copy of J1, harbour r15: \"NEW MOVE: cannon_shot\" beside NOT DONE lines for the cartridge, which makes the meteor): a round that hands part of the change on is not sent back for its move; the final bot run judges it and the person is told", () => {
  const live = fixture<{ event: JobEvent & { text: string } }>("j1-d27-harbour-r15-note.json").event;
  assert.deepEqual(newMovesOf(live.text), ["cannon_shot"]);
  const dir = tempDir("d27-final");
  fs.mkdirSync(path.join(dir, "reports"), { recursive: true });
  const report = (name: string, moves?: Record<string, unknown>) => (fs.writeFileSync(path.join(dir, "reports", name), JSON.stringify({ bot: { test: `tests/${name}`, done: true, result: { ok: true, ...(moves ? { metrics: { moves } } : {}) } } })), `reports/${name}`);
  const events = [
    { seq: 1003, type: "promoted", packId: "game.x", version: "0.1.21", dest: "promoted/game.x@0.1.21" },
    J1.events[0], { ...(J1.events[1] as object) }, live,
    { seq: 1016, type: "verify", package: "harbour", round: 15, level: "V4", verb: "bot", ok: true, report: report("harbour-r15.json") },
  ] as unknown as JobEvent[];
  const appended: Record<string, unknown>[] = [];
  const h = { s: { plan: J1.plan, lastSeq: 1016 }, events, pkg: () => ({ round: 15, roundBase: 15 }), dir: (...p: string[]) => path.join(dir, ...p), rel: (a: string) => a, append: (e: Record<string, unknown>) => (appended.push(e), events.push({ seq: 1100 + appended.length, ...e } as unknown as JobEvent), e as unknown as JobEvent) } as unknown as GateHost;
  assert.equal(landGate(h, "harbour", 15), undefined, "not sent back: the cartridge makes the meteor");
  assert.match(String(appended[0]?.["text"]), /^\[foreman\] new move judged at the end: cannon_shot of harbour waits for the part of the change harbour handed on/);
  // the final verification's bot run, after the cartridge made it
  events.push({ seq: 1060, type: "verify", round: 1, level: "V4", verb: "bot", ok: true, report: report("final-bot_harbour.json", { cannon_shot: { started: 4, landed: 0, last_f: 5000 } }) } as unknown as JobEvent);
  const never = finalLandNotes(h);
  assert.equal(never.length, 1);
  assert.ok((never[0]?.text ?? "").startsWith(`[foreman] ${NOT_MADE} by harbour: the new move cannon_shot never landed in the Foreman's final bot run (cannon_shot landed 0 of 4 (0 %))`), never[0]?.text);
  events.push({ seq: 1061, type: "verify", round: 2, level: "V4", verb: "bot", ok: true, report: report("final2-bot_harbour.json", { cannon_shot: { started: 4, landed: 2, last_f: 5000 } }) } as unknown as JobEvent);
  assert.match(finalLandNotes(h)[0]?.text ?? "", /^\[foreman\] new move lands in the Foreman's bot run: cannon_shot landed 2 of 4 \(50 %\) \(the final run/, "the newest final round decides");
  // a move its own round saw land is not judged again
  events.push({ seq: 1062, type: "note", package: "harbour", round: 16, text: `${MOVES_LAND}: cannon_shot landed 1 of 2 (tests/bot_harbour.gd)` } as unknown as JobEvent);
  assert.deepEqual(finalLandNotes(h), []);
});

test("D27 2c (the d27 copy of J1, events 1044-1108: the cartridge's meteor diff removed the bubble and the spot tricks, the data-only path skipped harbour's re-verification, harbour's test of the old bubble failed only in the final, and the cartridge's builder put the bubble back): a data-only round that removed something re-verifies its dependants", () => {
  const evs = fixture<{ events: JobEvent[] }>("j1-d27-cartridge-r12.json").events;
  assert.equal(removedInRound(evs, "cartridge", 12), true, "the diff's removed: notes of round 12");
  assert.equal(removedInRound(evs, "cartridge", 11), false);
  assert.equal(removedInRound(evs.filter((e) => !(e.type === "note" && e.text.startsWith("[foreman] removed: "))), "cartridge", 12), false, "a diff that only changes values keeps the fast path");
  const src = fs.readFileSync(path.join(REPO_ROOT, "foreman", "src", "foreman.ts"), "utf8");
  assert.match(src, /if \(hadMerged && fastMerge\(this\.s, files\) && !removedInRound\(this\.log\.events, id, round\)\)/, "the fast path's skip of reverifyDependants asks it");
});

test("D27 2d (the d27 copy of J1, events 1029-1078: the skin, handed only the tagline, said the meteor needs the cartridge, and the request went back to the cartridge, which had made it already): a round that was itself handed the rest of a change sends nothing on; the person is told", () => {
  const hop = `[foreman] ${REST_OF}, which harbour did not make ("NOT DONE: the tagline ..."): "${J1_REQUEST}"`;
  const events = [J1.events[0], { ...(J1.events[1] as object), package: "skin", reason: `change request (event 1032); the request names the package: ${hop.slice(0, 200)}` }, { seq: 1059, type: "note", package: "skin", round: 3, text: "- Tagline is now \"F: METEOR.\"\n- NOT DONE: the meteor itself needs the cartridge (`data/harbour.cartridge.json`), which is outside my scope." }] as unknown as JobEvent[];
  events.splice(2, 0, { seq: 1049, type: "merge", package: "cartridge", files: ["data/harbour.cartridge.json"] } as unknown as JobEvent); // the cartridge made its part first (live event 1049)
  const out = afterMerge(J1.plan, events, "skin", 3, ["data/skin.json"], hop);
  assert.equal(out.filter((e) => e["type"] === "change_requested").length, 0, "one hop: not sent back to the cartridge");
  assert.match(String(out[0]?.["text"]), /^\[foreman\] part of your change was NOT made: skin made the part handed to it and says: NOT DONE: the meteor itself needs the cartridge .* It was already handed on once, so the Foreman does not send it to cartridge again$/);
  // D27 item 14: a package that has not merged in this change is still sent the line (it has not made its part yet)
  const fresh = afterMerge(J1.plan, events.filter((e) => e.type !== "merge"), "skin", 3, ["data/skin.json"], hop);
  assert.deepEqual(fresh.filter((e) => e["type"] === "change_requested").map((e) => e["package"]), ["cartridge"]);
  // the person's own change still goes on (D27 2): one hop is allowed
  assert.equal(afterMerge(J1.plan, J1.events, "harbour", 15, ["data/tuning.json"], J1_REQUEST).filter((e) => e["type"] === "change_requested").length, 1);
});

test("D27 4c (the d27 copy of J1, event 1163: harbour named \"NEW MOVE: shotgun\" in r15 and \"NEW MOVE: meteor\" in r16, and the card said the shotgun was not made while the meteor landed 2 of 3): the newest note that names moves is the builder's word on them", () => {
  const dir = tempDir("d27-alias");
  fs.mkdirSync(path.join(dir, "reports"), { recursive: true });
  fs.writeFileSync(path.join(dir, "reports", "final-bot_harbour.json"), JSON.stringify({ bot: { test: "tests/bot_harbour.gd", done: true, result: { ok: true, metrics: { moves: { meteor: { started: 3, landed: 2, last_f: 5000 } } } } } }));
  const events = [
    { seq: 1003, type: "promoted", packId: "game.x", version: "0.1.21", dest: "x" },
    J1.events[0],
    { seq: 1012, type: "note", package: "harbour", round: 15, text: "- NOT DONE: the meteor needs `data/harbour.cartridge.json`, which is outside my scope: one shotgun mode entry.\n- NEW MOVE: shotgun. The core's shot." },
    { seq: 1064, type: "note", package: "harbour", round: 16, text: "- NEW MOVE: meteor. It's counted in `tests/bot_harbour.gd` as `metrics.moves.meteor`." },
    { seq: 1162, type: "verify", round: 3, level: "V4", verb: "bot", ok: true, report: "reports/final-bot_harbour.json" },
  ] as unknown as JobEvent[];
  const h = { s: { plan: J1.plan }, events, dir: (...p: string[]) => path.join(dir, ...p) } as unknown as GateHost;
  const notes = finalLandNotes(h);
  assert.equal(notes.length, 1);
  assert.equal(notes[0]?.text, `${MOVES_LAND}: meteor landed 2 of 3 (67 %) (the final run: tests/bot_harbour.gd)`);
});

// ---------------------------------------------------------------- 7. the rules sidecar in a person's change

test("D27 7 (S4's Arsenal copy, events 1082-1095: the cartridge builder named bot_ability_share and dive_shot_share and marked them NOT BUILT because data/harbour.rules.json was outside its scope; the person's \"Yes, add that file\" granted nothing): in a person's change on a core, the cartridge's owner owns its rules sidecar", () => {
  const S4 = fixture<{ plan: PackageSpec[]; events: JobEvent[] }>("s4a-cartridge-r13-14.json");
  const spec = (id: string) => S4.plan.find((p) => p.id === id) as PackageSpec;
  assert.equal(grantedScope(S4.events, "cartridge").length, 0, "the yes granted nothing: the question named no file");
  assert.equal(sidecarOf(S4.plan, spec("cartridge"), S4.events), "data/harbour.rules.json");
  assert.ok(withGrants(spec("cartridge"), S4.events, S4.plan).scope.includes("data/harbour.rules.json"));
  for (const other of ["base", "harbour", "skin"]) assert.ok(!withGrants(spec(other), S4.events, S4.plan).scope.includes("data/harbour.rules.json"), other);
  // only in a person's change: before it (the promotion is the last event) the plan's scope stands
  const before = S4.events.filter((e) => e.seq <= 1071);
  assert.equal(sidecarOf(S4.plan, spec("cartridge"), before), undefined);
  // another package that lists the file keeps it
  const listed = S4.plan.map((p) => (p.id === "skin" ? { ...p, scope: [...p.scope, "data/harbour.rules.json"] } : p));
  assert.equal(sidecarOf(listed, spec("cartridge"), S4.events), undefined);
  assert.match(widenedNote(S4.plan, S4.events, "cartridge", ["data/harbour.cartridge.json", "data/harbour.rules.json"]) ?? "", /^\[foreman\] scope widened for this change: cartridge owns the game's cartridge, so it may write its rules sidecar data\/harbour\.rules\.json/);
  assert.match(coreExcerpt({ id: "rink_game", title: "rink" }, RINK_ROUTE, "builder"), /\*\*The rules sidecar in a person's change\*\*.*do not mark the rule NOT BUILT for want of the file/);
});

// ---------------------------------------------------------------- 9-11. S35: a fairness ask, every package on the card, nothing changed

test("D27 10 (S35's kart copy s35-3A, events 1295-1442: \"Take out two things the old balance check added ...\" read as a fairness ask; the tofu gate refused the clean-up three times and teams changed the bots unasked): only a real fairness ask is one", () => {
  const kart = fixture<{ events: JobEvent[] }>("s35-kart-3A.json").events.find((e) => e.type === "change_requested") as JobEvent & { text: string };
  const biplane = fixture<{ events: JobEvent[] }>("s35-biplane-3A.json").events.find((e) => e.type === "change_requested") as JobEvent & { text: string };
  assert.equal(changeKind(kart.text), "play", "naming the old balance check is not asking for balance");
  assert.notEqual(changeKind(biplane.text), "fair");
  for (const ask of ["Make it fairer.", "Balance the teams: the reds win every match.", "Rebalance it so the rookie can win.", "Make the sides more even.", "The hammer is overpowered.", "The gulls are too strong.", "I want a more balanced game."]) assert.equal(changeKind(ask), "fair", ask);
});

test("D27 11a (S35's kart copy, event 1440: the card quoted only core's words; teams changed the bots' shooting range, angle and blocking when the Foreman's checks sent it back, and the person never saw it): every package's change reaches the card, the unasked ones on their own line", () => {
  const events = fixture<{ events: JobEvent[] }>("s35-kart-3A.json").events;
  const card = whatChangedNote(events, "0.1.8");
  const lines = card.split("\n");
  assert.match(lines[0] ?? "", /what you will see, in the builder's words: `main\.gd` no longer has the per-bot override/);
  const teams = lines.find((l) => l.startsWith(`${NOT_ASKED} teams changed it when the Foreman's checks sent it back`));
  assert.ok(teams !== undefined, card);
  assert.match(teams ?? "", /\(its dependency core was changed and merged again, and invariants \(V3\) now fails/);
  assert.match(teams ?? "", /`shoot\.range_max` changed from 40 to 30/);
  assert.ok(lines.some((l) => l.startsWith(`${NOT_ASKED} show changed it`)), "show's round too");
});

test("D27 11b (S35's biplane copy, events 750-787: the freeze undid the person's restore of the test pilot, v0.1.5 was v0.1.4 byte for byte, and the card said \"none ...; files: <16 files>\"): a promotion that changed nothing says so, and why", () => {
  const events = fixture<{ events: JobEvent[] }>("s35-biplane-3A.json").events;
  const card = whatChangedNote(events, "0.1.5", [], []);
  assert.match(card, /; nothing changed in the game: the Foreman kept tests\/support\/pilot\.gd as merged: it judges the game by it, so a change cannot rewrite it, and the change to it was undone$/);
  assert.doesNotMatch(card, /files:/);
  // the d27 copy of the same job merged 0 files (a fresh workspace): the card still says why, not "the change was NOT made" alone
  assert.match(whatChangedNote(events.filter((e) => e.type !== "merge"), "0.1.5"), /; nothing changed in the game: the Foreman kept tests\/support\/pilot\.gd as merged/);
  assert.match(whatChangedNote(events, "0.1.5"), /files: data\/moves\.json/, "without the comparison the merge's list is named, as before");
  // the comparison itself: pack.json is the Foreman's; a byte-equal file is not a change
  const dir = tempDir("d27-changed");
  for (const [d, v] of [["a", "1"], ["b", "1"]] as const) {
    fs.mkdirSync(path.join(dir, d, "data"), { recursive: true });
    fs.writeFileSync(path.join(dir, d, "pack.json"), d);
    fs.writeFileSync(path.join(dir, d, "data", "same.json"), v);
    fs.writeFileSync(path.join(dir, d, "data", "moved.json"), d);
  }
  fs.writeFileSync(path.join(dir, "b", "data", "new.json"), "x");
  assert.deepEqual(changedFiles(path.join(dir, "a"), path.join(dir, "b"))?.sort(), ["data/moved.json", "data/new.json"]);
  assert.match(measureKeptWords("[foreman] measure kept: tests/bot_tofu.gd, tests/support/pilot.gd are measures the Foreman judges by (merged before this round)"), /kept tests\/bot_tofu\.gd, tests\/support\/pilot\.gd as merged: it judges the game by them/);
});

test("D27 12 (J19's d27 copy, event 611: \"rush landed 1 of 13\" passed, because core's tests/bot_player.gd pressed the rush only until it had landed once; a hand that kept charging saw 0 of 11): the land count is judged only when its bot kept using the move into the last third of its run, and the share is told", () => {
  const run = (rush: Record<string, unknown>, frames = 9001) => judgeLanding(["rush"], [{ test: "tests/bot_player.gd", report: { bot: { test: "tests/bot_player.gd", frames, result: { ok: true, metrics: { moves: { rush } } } } } }]);
  // the round-1 test: it stopped pressing at its first landing, early in the run
  const early = run({ started: 13, landed: 1, last_f: 2100 });
  assert.deepEqual(early.stopped, ["rush"]);
  assert.equal(early.ok, false);
  // no last_f at all: not a measure either
  assert.deepEqual(run({ started: 13, landed: 1 }).stopped, ["rush"]);
  // a bot that keeps charging to the end: "at least once" still passes (the share is the owner's question), and is told
  const kept = run({ started: 31, landed: 2, last_f: 8890 });
  assert.equal(kept.ok, true);
  assert.equal(kept.counts["rush"]?.landed, 2);
  // through the gate: the builder is told to keep using it and report last_f
  const stopped = landHost(J19_SENTENCE, { rush: { started: 13, landed: 1 }, slam: { started: 4, landed: 3, last_f: 8800 } });
  const r = landGate(stopped.h, "core", 14);
  assert.match(r?.summary ?? "", /rush's last use was not reported \(no last_f\): the count must come from a bot that keeps using the move to the end of its run, wherever it can land, and never stops once it has landed/);
  const told = landHost(J19_SENTENCE, { rush: { started: 31, landed: 2, last_f: 8890 }, slam: { started: 4, landed: 3, last_f: 8800 } });
  assert.equal(landGate(told.h, "core", 14), undefined);
  assert.match(String(told.appended[0]?.["text"]), /rush landed 2 of 31 \(6 %\)/);
  // builders are asked for it
  assert.match(fs.readFileSync(path.join(REPO_ROOT, "foreman", "prompts", "builder.md"), "utf8"), /"last_f": <the frame of its last use>/);
});

test("D27 15 (J4's d27 copy, v0.1.5: the banner read \"YOU IS ON FIRE!\", the player's id pasted into a third-person line): every builder is told that words read as a person says them, and every card's juice says it", () => {
  const prompt = fs.readFileSync(path.join(REPO_ROOT, "foreman", "prompts", "builder.md"), "utf8");
  assert.match(prompt, /\*\*Words read as a person says them:\*\* the player is YOU, with "are" and "your" \("YOU ARE ON FIRE!",/);
  assert.match(prompt, /never put an internal id\s+\(`you`, `bot_2`, `crew_a`\) into a sentence \(no "YOU IS"\)/);
  const cards = path.join(REPO_ROOT, "engine", "cards");
  for (const f of fs.readdirSync(cards).filter((x) => x.endsWith(".json"))) {
    const juice = (JSON.parse(fs.readFileSync(path.join(cards, f), "utf8")) as { fun?: { juice?: string[] } }).fun?.juice ?? [];
    assert.ok(juice.some((l) => /YOU ARE \(never YOU IS\)/.test(l)), f);
  }
});

test("D27 12b (J19's round-3 copy, core r14, event 603: \"Fighter: new `cd` dictionary and `ready(m)` method. The 8-frame buffer takes the new moves ...\" made the Foreman judge moves cd and ready): explicit NEW MOVE lines win over loose backticks", () => {
  const note = fixture<{ event: { text: string } }>("j19-d27r3-core-r14-note.json").event.text;
  assert.deepEqual(newMovesOf(note), ["rush", "slam"]);
  assert.deepEqual(newMovesOf("- New moves `rush` (F, `body_check` clip) and `slam`.\n- Fighter: new `cd` dictionary; the new moves use it."), ["rush", "slam"], "without NEW MOVE lines, only a line that starts with New moves");
});

test("D27 14b (JB-back's shield copy, events 869-960: crew, queued for the rivals' part, was handed core's NOT DONE lines too, built the rivals' part in r8, and was re-opened for a duplicate r9): a hand-off to a package that has not built its queued round yet joins that round", async () => {
  const job = tempJob("d27-fold");
  assert.equal((await foremanFor(job, { promoteTo: "job" }).foreman.run()).jobState?.state, "done");
  const log = JobLog.open(job.jobDir);
  log.append({ type: "change_requested", text: "Make the ball fly twice as fast off a paddle. The rival paddle charges the ball and slams it back at my goal." });
  log.close();
  const from = readEvents(job.jobDir).at(-1)?.seq ?? 0;
  const steps: FakeStep[] = [
    { match: { role: "planner", promptIncludes: "Decide which ONE package owns" }, json: { package: "core", reason: "the ball's speed off a paddle is the core's" } },
    { match: { role: "builder", package: "core" }, write: { "scripts/main.gd": "extends Node\n# ball x2\n" }, text: "Done.\nDEVIATIONS:\n- NOT DONE: the rival's slam back needs `data/ai.json`, which is outside my scope: set slam 1." },
    { match: { role: "builder", package: "paddle_ai" }, write: { "data/ai.json": "{\"speed\": 1.0, \"charge\": true, \"slam\": 1}\n" }, text: "Done.\nDEVIATIONS: none" },
  ];
  const s = await foremanFor(job, { promoteTo: "job", script: scriptWith(steps) }).foreman.run();
  assert.equal(s.jobState?.state, "done", JSON.stringify(s.jobState));
  const later = readEvents(job.jobDir).filter((e) => e.seq > from);
  assert.ok(later.some((e) => e.type === "change_requested" && e.package === "paddle_ai" && e.text.startsWith(`[foreman] ${REST_OF}`)), "core's hand-off was written");
  assert.equal(later.filter((e) => e.type === "reopened" && e.package === "paddle_ai").length, 2, "the rivals' part and the hand-off both re-opened it");
  assert.equal(later.filter((e) => e.type === "builder_run" && e.package === "paddle_ai").length, 1, "one round built both: no duplicate round");
  assert.equal(s.packages["paddle_ai"]?.changes?.length, 2);
});

test("D27 12c (J19's round-3 copy, event 659: \"rush landed 9 of 8 (113 %)\": tests/bot_crew.gd counts victims, not uses): a landing is a use that hit somebody, so each test's landings are held to its uses", () => {
  // the two final runs of that promotion, as their reports say (events 651, 652)
  const v = judgeLanding(["rush"], [
    { test: "tests/bot_player.gd", report: { bot: { test: "tests/bot_player.gd", frames: 6000, result: { ok: true, metrics: { moves: { rush: { started: 2, landed: 1, last_f: 4653 } } } } } } },
    { test: "tests/bot_crew.gd", report: { bot: { test: "tests/bot_crew.gd", frames: 6399, result: { ok: true, metrics: { moves: { rush: { started: 6, landed: 8, last_f: 4063 } } } } } } },
  ]);
  assert.equal(v.counts["rush"]?.started, 8);
  assert.equal(v.counts["rush"]?.landed, 7, "1 + min(8, 6)");
  assert.equal(v.ok, true, "the player's run used it at frame 4653 of 6000: kept to the end");
});
