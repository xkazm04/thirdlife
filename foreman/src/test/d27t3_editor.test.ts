// D27 lane T3 (night of 27-28 Nov 2026): the last editor findings of the juice day. Each test is built on the real
// events of the job where the finding was seen (fixtures/d27t3) and fails on main f6592f87's code: the assertion named
// "main" in each test is what main's code does with the same input.
import { test, after } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { cleanup, tempDir } from "./helpers.js";
import type { JobEvent, PackageSpec } from "../events.js";
import type { GateHost } from "../p10gate.js";
import type { VerifyResult } from "../verifier.js";
import { REPO_ROOT } from "../paths.js";
import { personWords } from "../personwords.js";
import { unseenChange } from "../rinkjudge.js";
import { catalogFor, catalogRows, keyHint, keysFor } from "../keyfind.js";
import { afterMerge, coreHintOf } from "../halfmade.js";
import { coreChangeOwner } from "../coreowner.js";
import { drawPartHead, drawnElsewhere, drawnHandoffs, playSentences, playSplit, playWhy } from "../playsplit.js";
import { diffLeavesUnmade } from "../coregate.js";
import { askedFragments, copiedTextEvents, quotedFragments, textCopies, textSplit } from "../textowner.js";
import { newMovesOf } from "../landcheck.js";
import { NARROWED, narrowedNotes, narrowings } from "../narrowed.js";
import { botsDone, ownerMadeBots } from "../botsdone.js";
import { rivalSentences } from "../rivals.js";
import { RINK_ROUTE } from "../coreroute.js";
import { longerMatch } from "../tofugate.js";
import { JUDGED_LONGER, LONGER_BEFORE } from "../longernote.js";
import { BALANCE_MOVED } from "../boundlift.js";

after(cleanup);

const fixture = <T>(name: string): T => JSON.parse(fs.readFileSync(path.join(REPO_ROOT, "foreman", "fixtures", "d27t3", name), "utf8")) as T;
const ARS = fixture<{ plan: PackageSpec[]; events: JobEvent[] }>("j2b-ars-mega-1255-1350.json");
const ev = (L: readonly JobEvent[], seq: number): JobEvent & { text: string } => L.find((e) => e.seq === seq) as JobEvent & { text: string };
const MD = fs.readFileSync(path.join(REPO_ROOT, "engine", "cores", "rink", "CARTRIDGE.md"), "utf8");

// ---------------------------------------------------------------- 38. a question comes only from the person's words

test("D27 T3 38 (J2b's Arsenal copy, events 1278-1285: the cartridge's pre-check read the Foreman's hand-off, whose catalog row said \"easier to land\", and asked \"should the bots be weaker still?\"): the pre-checks judge only the person's words", () => {
  const handoff = ev(ARS.events, 1278).text;
  // the measured figures the pre-check had (event 1347's "measured before", the same cartridge at v0.1.28: 10 of 10 everywhere)
  const figures = { rookie_wins_of_10: 10, pro_wins_of_10: 10, all_star_wins_of_10: 10 };
  const asked = ev(ARS.events, 1283).text;
  // main: coregate.ts judged the hand-off's whole text, and the Foreman's own catalog words asked the person a question
  assert.equal(unseenChange(handoff, figures), asked, "main's call on the real hand-off gives the real question of event 1283");
  assert.match(handoff, /easier to land/, "the words that did it are the Foreman's (a catalog row), not the person's");
  // now: the words judged are the person's change (event 1255), which asks for nothing easier
  const before = ARS.events.filter((e) => e.seq < 1278);
  const words = personWords(before, handoff);
  assert.equal(words, ev(ARS.events, 1255).text);
  assert.equal(unseenChange(words, figures), undefined, "no question: the person never asked for weaker bots");
  // a person's own words still ask back as before, and a Foreman request outside a person's change asks nothing
  assert.equal(personWords(before, "the orange team is too strong"), "the orange team is too strong");
  assert.equal(personWords([], handoff), "");
});

// ---------------------------------------------------------------- 39. keyfind reads list entries and their values

test("D27 T3 39 (J2b's Arsenal copy, event 1277: harbour \"found no cartridge key for a modifier that starts on a check\"; the hint offered bump_ratio, cross_any_man, turn_rate ... and missed game.effects[] with trigger check_landed): the catalog's list entries and their values are searched", () => {
  const rows = catalogRows(MD);
  const note = ev(ARS.events, 1262).text;
  const line = note.split("\n").find((l) => /NOT DONE/.test(l)) as string;
  // main read no `[]` key at all: not one row of game.effects[] was a candidate
  assert.ok(!ev(ARS.events, 1277).text.includes("game.effects"), "the real hint of event 1277 named no effect key");
  const keys = keysFor(rows, line).flatMap((r) => r.keys);
  for (const k of ["game.effects", "game.effects[].trigger", "game.effects[].stats[].stat"]) assert.ok(keys.includes(k), `${k} in ${keys.join(", ")}`);
  const hint = keyHint(rows, line, "ref/cores/rink/CARTRIDGE.md");
  assert.match(hint, /game\.effects\[\]\.trigger = check_landed \(/, "the hint names the trigger value the words meet");
  assert.match(hint, /game\.effects\[\]\.stats\[\]\.stat = [a-z_| ]*skater_mass/);
  assert.match(hint, /skater_turn_rate/);
  // through afterMerge, as the Foreman carries it to the cartridge
  const dir = tempDir("d27t3-keys");
  fs.mkdirSync(path.join(dir, "ref", "cores", "rink"), { recursive: true });
  fs.writeFileSync(path.join(dir, "ref", "cores", "rink", "CARTRIDGE.md"), MD);
  const core = coreHintOf(ARS.plan, { core: "rink" }, (...p: string[]) => path.join(dir, ...p));
  const out = afterMerge(ARS.plan, ARS.events.filter((e) => e.seq <= 1276), "harbour", 20, ["data/tuning.json", "scripts/harbour.gd", "scripts/harbour_toys.gd"], ev(ARS.events, 1255).text, core);
  const carried = String(out.find((e) => e["type"] === "change_requested")?.["text"]);
  assert.match(carried, /game\.effects\[\]\.trigger = check_landed/);
  // the quick cartridge diff reads the full-list rows its words meet, the whole list of an effect with them
  const found = catalogFor(MD, ev(ARS.events, 1278).text);
  assert.match(found, /- game\.effects\[\]\.trigger \(your words name: check_landed\): pickup \| goal_for \| goal_against \| check_landed/);
  for (const k of ["game.effects[].id", "game.effects[].target", "game.effects[].duration_frames", "game.effects[].stats[].multiply"]) assert.ok(found.includes(`- ${k}`), k);
  assert.equal(catalogFor(MD, "Make the words bigger."), "");
});

// ---------------------------------------------------------------- 37. on a core, play goes to the cartridge's owner first

test("D27 T3 37 (J2b's Arsenal copy, events 1258 and 1319-1342: the Planner gave MEGA's stats, and the bots' check rate \"in scripts/main.gd\", to harbour, the drawing package): on a core the play goes to the cartridge's owner first, and the drawing package gets the drawing after its merge", () => {
  const core = RINK_ROUTE;
  for (const seq of [1255, 1319]) {
    const text = ev(ARS.events, seq).text;
    // main: the Planner's harbour stays (coreowner.ts keeps the owner when the words also name a picture)
    assert.equal(coreChangeOwner(ARS.plan, core, "harbour", text).owner, "harbour", `main keeps harbour for ${seq}`);
    const split = playSplit(ARS.plan, core, "harbour", seq, text);
    assert.equal(split?.owner, "cartridge", `${seq}`);
    assert.equal(split?.draw?.package, "harbour");
    assert.ok(split?.draw?.text.startsWith(drawPartHead(seq)));
    assert.match(split?.draw?.text ?? "", /and your package runs after its merge/, "harbour depends on cartridge: it draws what the cartridge made");
    assert.match(split?.draw?.text ?? "", /The whole change: "/);
  }
  assert.match(playSentences(ev(ARS.events, 1255).text), /^Add a Mario Kart Mega Mushroom .* lands a body check goes MEGA for five seconds\. While mega he is twice as heavy .* turns wide, .* The rival bots go mega whenever they land a check/);
  assert.equal(playSentences(ev(ARS.events, 1319).text), "And the rival bots go mega only about once a minute: I want to face their giants about twice as often, so they should land their body checks on me and my mates more often.");
  // what is drawing only stays the Planner's: every other ask of the job that the Planner gave harbour (the edge arrow,
  // the HOME card's words, YOUR CHECK MADE YOU MEGA), and a Foreman request, and a game off a core
  const asks = fixture<{ asks: { seq: number; text: string; planner: string }[] }>("arsenal-person-asks-923-1489.json").asks;
  for (const a of asks.filter((x) => x.planner === "harbour" && ![1005, 1255, 1319].includes(x.seq))) assert.equal(playSplit(ARS.plan, core, "harbour", a.seq, a.text), undefined, `${a.seq}: ${a.text.slice(0, 80)}`);
  assert.equal(playSplit(ARS.plan, core, "harbour", 1, ev(ARS.events, 1278).text), undefined, "a Foreman request is never split again");
  assert.equal(playSplit(ARS.plan, undefined, "harbour", 1255, ev(ARS.events, 1255).text), undefined);
  assert.equal(playSplit(ARS.plan, core, "cartridge", 1255, ev(ARS.events, 1255).text), undefined, "already the cartridge's");
  // the meteor of J1 (event 1005: "the longer I hold, the harder it flies ... easy to knock over") is play too: lane T's
  // round 1 needed the hand-off to reach the cartridge's shotgun mode and charge keys
  assert.equal(playSplit(ARS.plan, core, "harbour", 1005, asks.find((a) => a.seq === 1005)?.text ?? "")?.owner, "cartridge");
});

// ---------------------------------------------------------------- 43 and 35. longer matches, told as they are

interface Runs { plan: PackageSpec[]; events: JobEvent[]; longerRuns: Record<string, unknown> }
/** A job directory holding the fixture's reports, and a host for longerMatch over the events before `seq`. */
function host(runs: Runs, name: string, upTo: number, rounds: Record<string, number>) {
  const dir = tempDir(name);
  for (const [rel, r] of Object.entries(runs.longerRuns)) {
    fs.mkdirSync(path.dirname(path.join(dir, rel)), { recursive: true });
    fs.writeFileSync(path.join(dir, rel), JSON.stringify(r));
  }
  const events = runs.events.filter((e) => e.seq < upTo);
  const appended: (JobEvent & { text: string; package: string; round: number })[] = [];
  let seq = 100000;
  const h = { s: { plan: runs.plan, packages: Object.fromEntries(Object.entries(rounds).map(([k, v]) => [k, { round: v }])) }, events, dir: (...p: string[]) => path.join(dir, ...p), append: (e: Record<string, unknown>) => { const x = { ...e, seq: seq++ } as unknown as JobEvent & { text: string; package: string; round: number }; appended.push(x); events.push(x); return x; } } as unknown as GateHost;
  return { h, appended, events };
}
const vr = (runs: Runs, rel: string): VerifyResult => {
  const r = runs.longerRuns[rel] as { ok: boolean };
  return { verb: "bot", level: "V4", ok: r.ok, report: r, summary: r.ok ? "bot passed" : "bot failed: failed checks [bot.completed, bot.ok]", reportFile: rel, verdictFile: rel, flags: [], durationMs: 1 } as unknown as VerifyResult;
};
const TOFU = { verb: "bot" as const, args: ["--test=tests/bot_tofu.gd"] };

test("D27 T3 43 (N-newcomer's robots copy, event 1828: a change that only draws was told \"balance moved by your change: matches now run longer\"; the tofu bot needed 41149 frames before it too, event 1733, with the same state hash): matches that ran as long before the change are not the change's", async () => {
  const runs = fixture<Runs>("n-robot-q-cue-1590-1828.json");
  const real = ev(runs.events, 1828).text;
  assert.ok(real.startsWith(BALANCE_MOVED) && real.includes("matches now run longer"), "main's note (the real event 1828)");
  const { h, appended } = host(runs, "d27t3-43", 1826, { core: 24 });
  const r = await longerMatch(h, TOFU, vr(runs, "reports/final-bot-bot_tofu-s1826.json"), { round: 1 }, async () => vr(runs, "reports/final-bot-bot_tofu-longer-s1827.json"));
  assert.equal(r?.ok, true, "the run still counts: the frames are given as before");
  assert.equal(appended.length, 1, JSON.stringify(appended.map((e) => e.text)));
  const t = appended[0]?.text ?? "";
  assert.ok(!t.startsWith(BALANCE_MOVED), t);
  assert.ok(t.startsWith(`[foreman] ${LONGER_BEFORE} than tests/bot_tofu.gd plans (36000 frames) before your change too: it needed 41149 frames then (reports/final-bot-bot_tofu-longer-s1733.json) and 41149 now, the same play to the frame (the same state hash). Your change did not make them longer.`), t);
  assert.equal(appended[0]?.package, "core");
  // a change that did make them longer is still told so, with the frames before it
  const longer = { ...(runs.longerRuns["reports/final-bot-bot_tofu-longer-s1827.json"] as Record<string, unknown>), bot: { test: "tests/bot_tofu.gd", done: true, frames: 60000 } };
  const two = host({ ...runs, longerRuns: { ...runs.longerRuns, "reports/x-longer-s1.json": longer } }, "d27t3-43b", 1826, { core: 24 });
  await longerMatch(two.h, TOFU, vr(runs, "reports/final-bot-bot_tofu-s1826.json"), { round: 1 }, async () => ({ ...vr(runs, "reports/final-bot-bot_tofu-longer-s1827.json"), report: longer }) as unknown as VerifyResult);
  assert.match(two.appended[0]?.text ?? "", /^\[foreman\] balance moved by your change: built as you asked; matches now run longer \(the Foreman's test needed about 1\.7 times the frames it planned; 41149 before your change\)/);
});

test("D27 T3 35 (J2b's robots copy, events 1700-1733: brain r4's and show r8's pack checks and the final each ran the tofu bot, not done within 36000 frames, and passed with more; only the first got a line, so show r8's read as a failed check): every round the longer run decided says so", async () => {
  const runs = fixture<Runs>("j2b-robot-magnet-1651-1727.json");
  // main: between show r8's failed tofu run (1720) and its merge (1726) the log has no word on it
  assert.ok(!runs.events.some((e) => e.type === "note" && e.package === "show" && e.seq > 1720 && e.seq < 1727), "main said nothing on show r8");
  const { h, appended } = host(runs, "d27t3-35", 1700, { core: 23, brain: 4, show: 8 });
  const rerun = (rel: string) => async () => vr(runs, rel);
  await longerMatch(h, TOFU, vr(runs, "reports/brain-r4-pack-bot-bot_tofu-s1700.json"), { round: 4, after: "brain" }, rerun("reports/brain-r4-pack-bot-bot_tofu-longer-s1701.json"));
  await longerMatch(h, TOFU, vr(runs, "reports/show-r8-pack-bot-bot_tofu-s1720.json"), { round: 8, after: "show" }, rerun("reports/show-r8-pack-bot-bot_tofu-longer-s1721.json"));
  await longerMatch(h, TOFU, vr(runs, "reports/show-r8-pack-bot-bot_tofu-s1720.json"), { round: 8, after: "show" }, rerun("reports/show-r8-pack-bot-bot_tofu-longer-s1721.json"));
  assert.deepEqual(appended.map((e) => `${e.package} r${e.round}`), ["brain r4", "show r8"], "one line a round, the second run of the same round adds none");
  // the matches were longer before the change (the v0.1.10 final needed 57217 frames, event 1598): not the change's
  assert.ok(appended[0]?.text.startsWith(`[foreman] ${LONGER_BEFORE}`), appended[0]?.text);
  assert.ok(appended[1]?.text.startsWith(`[foreman] ${JUDGED_LONGER}: tests/bot_tofu.gd was not done within 36000 frames, so it ran again with 108000 and passed (41149 used), as told for this change; this is not a failed check of this round`), appended[1]?.text);
});

test("D27 T3 37b (this lane's live copy, event 1262: the quick diff made exactly the play, the `mega` effect with trigger check_landed, and said \"No key can say the white flash ... so a builder has to add those\"; item 29's check then gave the whole change to the cartridge's builder): when the drawing went to another package, the diff's words about the drawing leave nothing unmade", () => {
  const live = fixture<{ diff: { changes: Record<string, unknown>; why: string }; events: JobEvent[] }>("t3-live-ars-diff-1261.json");
  const changed = ["game.effects[5]: (absent) -> {mega}"];
  // main (and this lane before this fix): the diff is refused for what harbour draws
  assert.match(diffLeavesUnmade(live.diff.why, changed) ?? "", /^it leaves part of the ask unmade/);
  const before = [...ARS.events.filter((e) => e.seq < 1255 && e.type === "promoted"), ...live.events];
  assert.equal(drawnElsewhere(before, "cartridge"), true, "event 1258 sent the drawing to harbour");
  assert.equal(diffLeavesUnmade(playWhy(live.diff.why), changed), undefined, "the play is made: the diff stands");
  assert.equal(drawnElsewhere(before, "harbour"), false);
  // a play part the diff says it could not make still goes to the builder
  assert.match(diffLeavesUnmade(playWhy("The mega effect is set. No key can make every bump knock a man flat, so a builder needs to add it."), changed) ?? "", /a builder needs to add it/);
});

// ---------------------------------------------------------------- 45. one owner per text the person reads

test("D27 T3 45 (N-newcomer's Arsenal copy, events 1489-1496: \"Make every line of the ONE MATCH card fit\" went to harbour, which drew its own harbour.about_lines over the skin's `about`; the skin's text is dead): words the person quotes from another package's file go to that package first, and the drawing package is told never to keep a copy", () => {
  const asks = fixture<{ asks: { seq: number; text: string; planner: string }[] }>("arsenal-person-asks-923-1489.json").asks;
  const ask = asks.find((a) => a.seq === 1489) as { text: string; planner: string };
  assert.equal(ask.planner, "harbour", "main: the Planner's harbour took it");
  const data = path.join(REPO_ROOT, "foreman", "fixtures", "d27t3", "n-ars-v0131-data");
  const read = (rel: string): string | undefined => { try { return fs.readFileSync(path.join(data, path.basename(rel)), "utf8"); } catch { return undefined; } };
  assert.deepEqual(quotedFragments(ask.text).slice(0, 3), ["your check made you mega", "rmb check go mega", "your shot floors everyone"]);
  const split = textSplit(ARS.plan, read, "harbour", 1489, ask.text);
  assert.equal(split?.owner, "skin");
  assert.match(split?.why ?? "", /^the words the person quotes \("your shot floors everyone"\) are held in data\/skin\.json, which "skin" owns/);
  // a quote given only as a reference is not an ask about the words (N's shield sentence 1506: "the G key keeps saying
  // "after your Q call"" is about rally's Q press, not volley's label)
  assert.deepEqual(askedFragments("and the G key keeps saying \"after your Q call\". Keep my Q press."), []);
  assert.deepEqual(askedFragments("The HOME screen still says \"F pops your bubble: checks bounce off\", but F is the METEOR now."), ["f pops your bubble checks bounce off"]);
  assert.equal(split?.draw.package, "harbour");
  assert.match(split?.draw.text ?? "", /never keep a copy of them in your own files, and never draw your own text over theirs/);
  // words only the Planner's own package holds, or nobody, or a Foreman request: no split
  assert.equal(textSplit(ARS.plan, read, "harbour", 1, "Make \"Your next shot floors everyone\" bigger."), undefined, "harbour's own trick prompt");
  assert.equal(textSplit(ARS.plan, read, "harbour", 1, "Show \"nothing like this anywhere\" on the plate."), undefined);
  assert.equal(textSplit(ARS.plan, read, "harbour", 1, `[foreman] ${ask.text}`), undefined);
  assert.equal(textSplit(ARS.plan, read, "skin", 1489, "Make \"twice the size, bump them flat\" fit."), undefined, "already the holder's");
});

// ---------------------------------------------------------------- 44. a narrowed ask is part of the change NOT made

test("D27 T3 44 (N-newcomer's shield copy, events 1506-1524: \"if I press Q while I am down, stunned or mid-move ... blow the horn the moment I am free\"; rally: \"The kept press is dropped if ... the captain falls\", said only among its notes): a builder line that drops the input in a state the person named is \"part of your change was NOT made\"", () => {
  const sh = fixture<{ events: JobEvent[] }>("n-shield-call-1500-1530.json");
  const merged = sh.events.filter((e) => e.seq <= 1524);
  // main: the only NOT made line of the change is the Q key's label, which went on to core
  assert.ok(!sh.events.some((e) => e.type === "note" && e.text.includes("fewer cases")), "main told nothing of the narrowing");
  const out = narrowedNotes(merged, "rally", 4);
  assert.equal(out.length, 1, JSON.stringify(out));
  assert.equal(out[0]?.text, `[foreman] ${NARROWED}rally made it for fewer cases than you asked: you asked "if I press Q while I am down, stunned or mid-move, light the Q key with "CALL WHEN UP" and blow the horn the moment I am free again (the call bar must still be ready)", and rally says (down): "The kept press is dropped if the bar is no longer full, the captain falls, or a call is already running."`);
  assert.ok(out[0]?.text.startsWith("[foreman] part of your change was NOT made: "), "Create's not_made_note and the card's NOT made lines read it");
  assert.deepEqual(narrowedNotes([...merged, ...out.map((n, i) => ({ ...n, seq: 9000 + i }) as unknown as JobEvent)], "rally", 4), [], "once");
  // a drop in a case the person did not name is the builder's to choose (the bar no longer full)
  assert.deepEqual(narrowings("If I press Q while I am down, keep it.", "The kept press is dropped if the bar is no longer full."), []);
  assert.deepEqual(narrowings("Make the horn louder.", "The kept press is dropped if the captain falls."), [], "no condition of the person's");
});

// ---------------------------------------------------------------- 34. a rivals' part the owner made needs no round

test("D27 T3 34 (J2b's robots copy, events 1653-1706: \"And my own bot teammates should use the magnet too.\" went to brain as the rivals' part; core r23 made it, \"the magnet bot logic now runs for team 0 mates ... as well as rivals\", and brain r4 then found nothing to do, 0.6M tokens): after the owner's merge, a package that waits only for a rivals' part the owner made is not opened", () => {
  const rb = fixture<{ events: JobEvent[] }>("j2b-robot-magnet-1651-1727.json");
  const atMerge = rb.events.filter((e) => e.seq <= 1673);
  // main: brain ran a builder round for it (event 1686)
  assert.ok(rb.events.some((e) => e.type === "builder_run" && e.package === "brain" && e.seq === 1686));
  const out = botsDone(atMerge, "core", 23);
  assert.deepEqual(out.map((e) => `${e["type"]} ${e["package"]} ${e["state"] ?? ""}`), ["note brain ", "package_state brain promoted"]);
  assert.match(String(out[0]?.["text"]), /^\[foreman\] the rivals' part of change request 1653 needs no round of brain: core made those bots do it in its own files, in its words: ".*magnet bot logic now runs for team 0 mates \(ids 1 and 2\) as well as rivals/);
  assert.equal(out[1]?.["round"], 4);
  // J19's core r14 note (its brain.gd drives Bram, crew's mind.gd the other four) says nothing that covers crew's bots
  const j19 = JSON.parse(fs.readFileSync(path.join(REPO_ROOT, "foreman", "fixtures", "d27", "j19-d27r3-core-r14-note.json"), "utf8")) as { event: { text: string } };
  assert.equal(ownerMadeBots(rivalSentences("The rivals charge an open line, raise shields when charged, slam a crowd and run out of the ring."), j19.event.text), undefined);
  // once brain has started, or more work came for it, nothing is taken back
  assert.deepEqual(botsDone([...atMerge, { seq: 1674, type: "builder_run", package: "brain", round: 4 } as unknown as JobEvent], "core", 23), []);
});

test("D27 T3 44b (this lane's live copy, event 1371: \"When a rival knocks me down, YOU ARE MEGA! stays on screen ...: take it away the moment I fall\"; harbour: \"it is cleared the moment the player is down\", and item 44's first version called that NOT made): a builder that takes away what the person asked taken away has made it", () => {
  const live = fixture<{ events: JobEvent[] }>("t3-live-ars-follow-1334-1371.json");
  const person = ev(live.events, 1334).text;
  const note = ev(live.events, 1356).text;
  assert.match(ev(live.events, 1371).text, /^\[foreman\] part of your change was NOT made: harbour made it for fewer cases/, "the first version's false note (live)");
  assert.deepEqual(narrowings(person, note), []);
  // N's shield narrowing is still found
  const sh = fixture<{ events: JobEvent[] }>("n-shield-call-1500-1530.json");
  assert.equal(narrowedNotes(sh.events.filter((e) => e.seq <= 1524), "rally", 4).length, 1);
});

// ---------------------------------------------------------------- round 2 (Director's rulings after the landing)

test("D27 T3 R2 none (this lane's live Arsenal copy, events 1286-1301: harbour r21 wrote \"NEW MOVE: none (MEGA is a timed effect ...)\"; the land gate asked for a move called \"none\" and harbour r23 counted one): \"none\" says there is no new move", () => {
  const live = fixture<{ events: JobEvent[]; refusal: { message: string }[] }>("t3-live-ars-none-1286-1298.json");
  const note = ev(live.events, 1286).text;
  assert.match(live.refusal[0]?.message ?? "", /no bot test of your package reports moves\.none/, "main's real refusal (event 1298)");
  assert.deepEqual(newMovesOf(note), []);
  assert.deepEqual(newMovesOf("- NEW MOVE: nothing new here."), []);
  assert.deepEqual(newMovesOf("- NEW MOVE: none\n- New moves `rush` and `slam` were the core's."), [], "an explicit NEW MOVE line is the builder's word, over a loose line");
  assert.deepEqual(newMovesOf("- NEW MOVE: rush, slam"), ["rush", "slam"]);
});

test("D27 T3 R2 copies (N's Arsenal copy, event 1496: harbour drew its own harbour.about_lines over the skin's `about`; S4's base Arsenal, event 808: the skin's builder found \"scripts/main.gd overrides the skin's tagline with harbour.tagline\"): the package that draws its own copy of another package's text goes back once, with the owner named", () => {
  const j = fixture<{ n: { plan: PackageSpec[]; events: JobEvent[] }; s4: { plan: PackageSpec[]; events: JobEvent[] } }>("text-copies-n1496-s4808.json");
  // N: harbour's own note, at harbour's merge
  const n = copiedTextEvents(j.n.plan, j.n.events, "harbour", 25);
  assert.deepEqual(n.map((e) => `${e["type"]} ${e["package"]}`), ["change_requested harbour"]);
  assert.match(String(n[0]?.["text"]), /^\[foreman\] one owner per text: harbour's files draw their own copy of a text that skin owns \(data\/skin\.json, data\/harbour_commentary\.json\), in harbour's words: "The HOME card's lines now come from/);
  assert.match(String(n[0]?.["text"]), /a word that must change is skin's, so write it as a NOT DONE line naming data\/skin\.json/);
  // S4: the skin's note names harbour's copy; harbour goes back
  const s = copiedTextEvents(j.s4.plan, j.s4.events.filter((e) => e.seq <= 812), "skin", 3);
  assert.deepEqual(s.map((e) => `${e["type"]} ${e["package"]}`), ["change_requested harbour"]);
  assert.match(String(s[0]?.["text"]), /in skin's words: "The title screen already showed the new line before this edit: `scripts\/main\.gd` overrides the skin's tagline/);
  // once: a second report in the same change is the person's note
  const again = copiedTextEvents(j.n.plan, [...j.n.events, { ...(n[0] as object), seq: 9001 } as unknown as JobEvent], "harbour", 26);
  assert.deepEqual(again.map((e) => e["type"]), ["note"]);
  // "it never replaces the core's ... lines" is not a copy
  assert.deepEqual(textCopies(j.n.plan, "harbour", "It reads `data/tuning.json` and never replaces the skin's tagline lines."), []);
});

test("D27 T3 R2 edge (this lane's v0.1.29 film, stills/t3_v029_mate_mega_f756-864_sheet.jpg: FLATTENED! over a man near the screen's edge read \"ATTENED!\"): every builder, and every card's juice line, is told to clamp a word over a body inside the safe area", () => {
  const builder = fs.readFileSync(path.join(REPO_ROOT, "foreman", "prompts", "builder.md"), "utf8");
  assert.match(builder, /A word over a body stays whole on the screen:\*\* a word drawn at a body's\s+screen point \(`lay\.project`\) is measured \(`lay\.measure`\) and its box is clamped inside the safe area/);
  assert.match(builder, /behind the camera \(z <= 0\) gets no word over it/);
  for (const card of fs.readdirSync(path.join(REPO_ROOT, "engine", "cards")).filter((f) => f.endsWith(".json"))) {
    const juice = JSON.stringify((JSON.parse(fs.readFileSync(path.join(REPO_ROOT, "engine", "cards", card), "utf8")) as Record<string, unknown>));
    assert.match(juice, /a word over a body is clamped whole inside the screen's safe area \(5 % in from each edge\), never cut by the edge/, card);
  }
});

test("D27 T3 R2 drawn (this lane's l3 copy, events 1355-1381: the drawing had gone to harbour, and the cartridge's NOT DONE lines for the camera and FLATTENED! went on to harbour and BACK to the cartridge, which spent r16 saying it cannot): a drawing-only hand-off of the cartridge's owner is dropped when the drawing already went to another package", () => {
  const l3 = fixture<{ plan: PackageSpec[]; events: JobEvent[] }>("t3-live-l3-handoffs-1334-1365.json");
  const atMerge = l3.events.filter((e) => e.seq <= 1355);
  // main: the real log sent both on (events 1357 to harbour, 1359 back to the cartridge)
  assert.deepEqual(l3.events.filter((e) => e.type === "change_requested" && e.seq > 1355).map((e) => e.type === "change_requested" ? e.package : ""), ["harbour", "cartridge"]);
  const dir = tempDir("d27t3-drawn");
  fs.mkdirSync(path.join(dir, "ref", "cores", "rink"), { recursive: true });
  fs.writeFileSync(path.join(dir, "ref", "cores", "rink", "CARTRIDGE.md"), MD);
  const core = coreHintOf(l3.plan, { core: "rink" }, (...p: string[]) => path.join(dir, ...p));
  const raw = afterMerge(l3.plan, atMerge, "cartridge", 15, ["data/harbour.cartridge.json"], ev(l3.events, 1334).text, core);
  assert.deepEqual(raw.filter((e) => e["type"] === "change_requested").map((e) => e["package"]), ["harbour", "cartridge"], "afterMerge alone does what the live run did");
  const out = drawnHandoffs(atMerge, "cartridge", raw);
  assert.deepEqual(out.filter((e) => e["type"] === "change_requested"), []);
  assert.ok(out.filter((e) => e["type"] === "note").every((e) => !String(e["text"]).startsWith("[foreman] part of your change was NOT made")), JSON.stringify(out));
  assert.match(String(out[0]?.["text"]), /^\[foreman\] the drawing part already went to harbour in this change, so this is not sent on: /);
  // without a drawing part in the change, afterMerge's hand-offs pass as they are
  assert.deepEqual(drawnHandoffs(atMerge.filter((e) => e.seq !== 1337), "cartridge", raw), raw);
});
