// H1h of the day run of 25 Nov 2026 (editor hardening, round 8), from lane G1's rounds 5 and 6 (PROOF-G1.md sections
// 23-26) and the Director's answers to H1g. Each test failed on main 67e6e1e and passes now.
import { test, after } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { cleanup, foremanFor, readEvents, scriptWith, tempDir, tempJob } from "./helpers.js";
import type { FakeStep } from "../builder/fake.js";
import type { Brief, JobEvent, PackageSpec } from "../events.js";
import type { GateHost } from "../p10gate.js";
import type { VerifyResult } from "../verifier.js";
import { tofuGate } from "../tofugate.js";
import { tofuMetricsFor, tofuOf } from "../tofu.js";
import { liftedBounds } from "../boundlift.js";
import { qualityNext } from "../quality_state.js";
import { ClaudeCliBuilder } from "../builder/claude-cli.js";
import { JobLog } from "../joblog.js";
import { askedFigureMiss } from "../rinkjudge.js";
import { skinSplit } from "../coreowner.js";
import { figuresOf } from "../coreroute.js";
import { houseKeepProblems } from "../templates.js";
import { REPO_ROOT } from "../paths.js";

after(cleanup);

// ---------------------------------------------------------------- 1. the named figure: which minutes, which way

test("H1h 1 (G1 v0.1.10, event 558: \"Play to a three-minute clock\" read against 3.9 match minutes with the pauses after fifteen goals, and called \"falls short\"): a person's minutes are minutes of play; the check compares them with the live play minutes and says over or short truthfully", () => {
  const words = "Play to a three-minute clock instead of first to five. The MATCH POINT call can go.";
  // G1's figures after v0.1.10: 3.9 minutes a match with the pauses, 3.0 minutes of play (the lab, 80 seeds)
  assert.equal(askedFigureMiss(words, { pro_minutes: 3.9, pro_play_minutes: 3.0 }), undefined, "three minutes of play: what was asked");
  assert.equal(askedFigureMiss(words, { pro_minutes: 5.2, pro_play_minutes: 4.1 }), "you asked for matches of about 3 minutes; they last 4.1 minutes of play at pro now (5.2 with the pauses after goals), longer than you asked (thirdjam's regular playtester, measured after the change): the change goes past what you asked");
  assert.match(askedFigureMiss("make a match last about five minutes", { pro_minutes: 3.9, pro_play_minutes: 3.0 }) ?? "", /3 minutes of play at pro now \(3\.9 with the pauses after goals\), shorter than you asked [^:]*: the change falls short of what you asked$/);
  // the check reports the play minutes, and the Foreman reads them
  const line = { tool: "tl.rink.check/1", levels: { pro: { playtester: { matches: 10, wins: 6, goals_for: 3.8, goals_against: 3, minutes: 3.9, play_minutes: 3.0 } } } };
  assert.equal(figuresOf(line as never)["pro_play_minutes"], 3.0);
  const src = fs.readFileSync(path.join(path.dirname(new URL(import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, "$1")), "..", "..", "..", "engine", "cores", "rink", "lab", "check_cartridge.mjs"), "utf8");
  assert.match(src, /play_minutes: r1\(mean\(cell\.map\(\(c\) => \(c\.play_frames \?\? 0\) \/ 3600\)\)\)/, "the check's level figures carry the live play minutes");
});

// ---------------------------------------------------------------- 2. the game's text goes to the skin's owner

const G1_PLAN = [
  { id: "base", kind: "base", scope: ["assets/**", "data/**", "gen/**", "scripts/**", "tests/**"] },
  { id: "cartridge", scope: ["data/harbour.cartridge.json", "data/match.json"] },
  { id: "harbour", scope: ["scripts/main.gd", "scripts/harbour.gd", "scripts/harbour_toys.gd", "data/tuning.json", "data/harbour_venue.json", "data/drill_slush100.cartridge.json", "tests/bot_harbour.gd"] },
  { id: "skin", scope: ["data/skin.json", "data/harbour_commentary.json"] },
] as unknown as PackageSpec[];

test("H1h 2 (G1 v0.1.11, events 577-584: \"... Change the line under the title to: Grab a trick at the green spots. F uses it.\" went with two drawing asks to `harbour`, which overrode the line from its own file while the skin still said the old one): the sentences that set the game's text go to the skin's owner, the rest stays", async () => {
  const g1 = "Take the black boxes, the drum and the visor off the rival skaters, and take away the big names floating above them. Show the F hint in the game's own hint place, not on the commentator's line. Change the line under the title to: Grab a trick at the green spots. F uses it.";
  const s = skinSplit(G1_PLAN, "harbour", g1);
  assert.equal(s?.to, "skin");
  assert.equal(s?.skinText, "Change the line under the title to: Grab a trick at the green spots. F uses it.");
  assert.equal(s?.rest, "Take the black boxes, the drum and the visor off the rival skaters, and take away the big names floating above them. Show the F hint in the game's own hint place, not on the commentator's line.");
  assert.equal(skinSplit(G1_PLAN, "skin", g1), undefined, "already the skin's");
  assert.equal(skinSplit(G1_PLAN, "harbour", "Draw the bubble as one smooth see-through ball."), undefined, "a picture stays");
  assert.equal(skinSplit(G1_PLAN, "harbour", "Rename the teams to Gulls and Tides.")?.rest, "", "all of it is the skin's");
  // in a run: the paddle job with a skin file (court owns it); the person's change goes to paddle_ai
  const job = tempJob("h1h-skin");
  const file = path.join(job.jobDir, "job.jsonl");
  const lines = fs.readFileSync(file, "utf8").split("\n").filter(Boolean);
  const plan = JSON.parse(lines[3] as string) as { packages: PackageSpec[] };
  for (const p of plan.packages) if (p.id === "court") p.scope = [...p.scope, "data/skin.json"];
  lines[3] = JSON.stringify(plan);
  fs.writeFileSync(file, lines.map((l) => l + "\n").join(""));
  assert.equal((await foremanFor(job, { promoteTo: "job" }).foreman.run()).jobState?.state, "done");
  const log = JobLog.open(job.jobDir);
  log.append({ type: "change_requested", text: "Make the rival twice as fast. Change the title to: Paddle Kings.", package: "paddle_ai" });
  log.close();
  const from = readEvents(job.jobDir).at(-1)?.seq ?? 0;
  const steps: FakeStep[] = [
    { match: { role: "builder", package: "paddle_ai" }, write: { "data/ai.json": "{\"speed\": 2.0}\n" }, text: "Done.\nDEVIATIONS: none" },
    { match: { role: "builder", package: "court" }, write: { "data/skin.json": "{\"title\": \"Paddle Kings\"}\n" }, text: "Done.\nDEVIATIONS: none" },
  ];
  const { foreman, builder } = foremanFor(job, { promoteTo: "job", script: scriptWith(steps) });
  assert.equal((await foreman.run()).jobState?.state, "done");
  const later = readEvents(job.jobDir).filter((e) => e.seq > from);
  const toSkin = later.find((e) => e.type === "change_requested" && e.package === "court");
  assert.match(toSkin?.type === "change_requested" ? toSkin.text : "", /^\[foreman\] the game's text from change request \d+, the words "Change the title to: Paddle Kings\." set the game's text [^"]*"court"[^:]*: "Change the title to: Paddle Kings\."$/);
  const ai = builder.calls.filter((c) => c.req.meta?.package === "paddle_ai").at(-1)?.req.prompt ?? "";
  assert.match(ai, /Make the rival twice as fast\./);
  // (it may read the skin as another package's file; it is not asked to set it)
  assert.deepEqual(ai.split("\n").filter((l) => l.includes("Paddle Kings") && !l.includes("another package's: read only")), [], "the drawing package is not asked for the skin's words");
  assert.ok(ai.split("\n").includes("1. Make the rival twice as fast."), "its change is the rest");
  assert.match(fs.readFileSync(path.join(job.jobDir, "pack", "data", "skin.json"), "utf8"), /Paddle Kings/);
});

// ---------------------------------------------------------------- 4. the stray character in templates.ts

test("H1h 4 (H1g found it: templates.ts held three backspace characters where the readable-puck rule meant word boundaries, so a brief that drew the puck bigger with a hot rim but no ring was told it lacked a readable puck): the rule reads a puck described in words", () => {
  const src = fs.readFileSync(path.join(REPO_ROOT, "foreman", "src", "templates.ts"), "utf8");
  assert.equal(src.split(String.fromCharCode(8)).length - 1, 0, "no backspace character in the source");
  const tpl = { id: "arcade_sport" as const, reference: "r", copies: [] };
  const puckOnly = "The puck is drawn bigger than life with a hot outline. A broadcast camera looks down at 50 degrees from the near side and follows the puck. The puck sticks to the blade on a spring. Passing beats skating: the carrier is slower (x0.88). The AI scores SHOOT, PASS and CARRY every 15 frames with vetoes.";
  assert.deepEqual(houseKeepProblems(puckOnly, tpl).filter((p) => p.includes("readable at a glance")), []);
});

// ---------------------------------------------------------------- 6. a person's card choice or answer lifts a plan bound

test("H1h 6 (G5 events 14, 214-216 and 241-242: the ball chosen \"Never Held\" on a card, the person's answer \"C. ... Drop the 4-second possession target\", and the Foreman threw core r9 away for possession_median_f 30 against 240-600): a card choice or a direct answer lifts the bound; the round passes and the note says which bound, on whose word", () => {
  const FX = path.join(REPO_ROOT, "foreman", "fixtures");
  const plan = JSON.parse(fs.readFileSync(path.join(FX, "h1h", "g5-plan.json"), "utf8")) as PackageSpec[];
  const brief = JSON.parse(fs.readFileSync(path.join(FX, "h1g", "g5-brief.json"), "utf8")) as Brief;
  const events = fs.readFileSync(path.join(FX, "h1h", "g5-events.jsonl"), "utf8").split("\n").filter(Boolean).map((l) => JSON.parse(l) as JobEvent);
  const report = JSON.parse(fs.readFileSync(path.join(FX, "h1h", "g5-core-r9-bot-s241.json"), "utf8")) as VerifyResult["report"];
  const t = tofuOf(plan);
  assert.ok(t !== undefined, "G5's plan has a tofu check");
  const card = events.find((e) => e.type === "aspect_reacted");
  const reactions = card?.type === "aspect_reacted" ? { [card.aspect]: { choice: card.choice, ...(card.note !== undefined ? { note: card.note } : {}), seq: card.seq } } : {};
  const dir = tempDir("h1h-lift");
  const host = (evs: JobEvent[], rx: Record<string, unknown>) => {
    const appended: Record<string, unknown>[] = [];
    const h = {
      s: { plan, brief, reactions: rx, lastSeq: 241 },
      events: evs,
      pkg: () => ({ round: 9, roundBase: 8 }),
      dir: (...p: string[]) => path.join(dir, ...p),
      rel: (abs: string) => path.relative(dir, abs).split(path.sep).join("/"),
      append: (e: Record<string, unknown>) => (appended.push(e), e as unknown as JobEvent),
    } as unknown as GateHost;
    return { h, appended };
  };
  const vr = { verb: "bot", level: "V4", ok: true, report, reportFile: path.join(dir, "reports", "core-r9-bot-s241.json"), verdictFile: "", flags: [], summary: "bot passed", durationMs: 1 } as unknown as VerifyResult;
  const a = { verb: "bot" as const, args: [`--test=${t?.test ?? ""}`] };
  // as on main: neither the card nor the answer counts, the round is thrown away
  const none = host([], {});
  assert.match(tofuGate(none.h, "core", a, vr)?.summary ?? "", /possession_median_f 30 \(the plan's bound: 240 to 600\)/);
  // the answer alone lifts it
  const answered = host(events.filter((e) => e.type !== "aspect_reacted"), {});
  assert.equal(tofuGate(answered.h, "core", a, vr), undefined, "the answer lifted the bound: the round passes");
  const note = answered.appended.find((e) => e["type"] === "note");
  assert.match(String(note?.["text"]), /^\[foreman\] plan bound lifted, not judged: possession_median_f \(the plan's bound: >= 240 and <= 600\), on your answer to core's question \(event 216\): "C\. Keep the ball fully loose/);
  // the card alone lifts it
  const chosen = host([], reactions);
  assert.equal(tofuGate(chosen.h, "core", a, vr), undefined, "the card lifted the bound");
  assert.match(String(chosen.appended.find((e) => e["type"] === "note")?.["text"]), /possession_median_f [^,]*, on your card "Never Held" \(a ball nobody holds: "a huge heavy ball that rolls and bounces off the karts; you steer it by pushing and bumping it, never carry it"\)/);
  // a bound nobody lifted is still judged
  assert.equal(liftedBounds({ brief, reactions: {} } as never, [], tofuMetricsFor({ id: "arcade_sport" } as never, 3)).size, 0);
});

// ---------------------------------------------------------------- 7. a passed phase closes its milestone's critic loop

test("H1h 7 (G5 events 184-209: greybox revise round 1 was sent to core, the show phase paused and the person passed it, and the Foreman judged greybox again and sent revise round 2): a phase the person passed after a milestone's last look or round closes that milestone", () => {
  const evs = fs.readFileSync(path.join(REPO_ROOT, "foreman", "fixtures", "h1h", "g5-to-207.jsonl"), "utf8").split("\n").filter(Boolean).map((l) => JSON.parse(l) as JobEvent);
  assert.deepEqual(qualityNext(evs, "greybox", ["teams", "show"]), { next: "closed" }, "passed at event 196: not judged again");
  assert.deepEqual(qualityNext(evs.filter((e) => e.seq < 196), "greybox", ["teams", "show"]), { next: "look", round: 1 }, "before the pass the round's look is due, as before");
});

// ---------------------------------------------------------------- 8. every result segment counts in the ledger

test("H1h 8 (G5 core r8: a claude session that ended with a second result after a background-task notification was logged as 365 tokens out against 30,705 used, and the builder's report in the first result was lost): the adapter sums every result segment and keeps every segment's text", () => {
  const b = new ClaudeCliBuilder({ bin: process.execPath, env: {} });
  const stdout = fs.readFileSync(path.join(REPO_ROOT, "foreman", "fixtures", "h1h", "g5-core-r8-results.ndjson"), "utf8");
  const r = b.normalize({ exitCode: 0, stdout, stderr: "", timedOut: false, outputCapped: false, durationMs: 1 }, [], "", { prompt: "p", mode: "edit", cwd: "", timeoutMs: 1000 }, 1000);
  assert.equal(r.ok, true);
  assert.equal(r.tokensOut, 30705, "30,340 + 365");
  assert.equal(r.tokensIn, 30 + 133759 + 1485561 + 6 + 3281 + 282483);
  assert.match(r.text ?? "", /^I made hits show much more in both bodies[^]*DEVIATIONS[^]*\n\nInvariants have now finished and \*\*passed\*\*/, "the first segment's report (with its DEVIATIONS) and the second's");
});
