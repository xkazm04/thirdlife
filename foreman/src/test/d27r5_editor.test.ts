// D27 round 5 of the juice day of 27 Nov 2026 (lane T-editor): split out of d27_editor.test.ts (its 600-line budget).
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
import { NOT_DONE, NOT_MADE, OWN_FILES, REST_OF, afterMerge, coreHintOf } from "../halfmade.js";
import { catalogRows, keyHint, keysFor } from "../keyfind.js";
import { coreExcerpt, RINK_ROUTE } from "../coreroute.js";
import { longerMatch, onlyOutOfFrames, tofuTooShort } from "../tofugate.js";
import { runHandChecks } from "../handcheck.js";
import type { VerifyResult } from "../verifier.js";
import { MOVES_LAND, finalLandNotes, judgeLanding, landGate, newMovesOf } from "../landcheck.js";
import { BALANCE_MOVED, askedChange, balanceLines, changeKind } from "../boundlift.js";
import { restoreLastPromotion } from "../unmade.js";
import { diffLeavesUnmade } from "../coregate.js";
import { testsChanged } from "../fastchange.js";
import { NOT_ASKED, UNASKED_RULE, changedFiles, measureKeptWords, removedInRound, whatChangedNote } from "../fastchange.js";

after(cleanup);

const fixture = <T>(name: string): T => JSON.parse(fs.readFileSync(path.join(REPO_ROOT, "foreman", "fixtures", "d27", name), "utf8")) as T;

test("D27 R5 25 (J2nd's court copy, report final-hand-perfect-seed7-s1417: a seed the engine never began made \"19 of 20 finished\" a failed card, and crews_stakes was sent to change a rule): a hand-check seed the engine never began is not counted; the next seed runs in its place", async () => {
  const dir = tempDir("d27-hands-start");
  for (const d of [path.join(dir, "pack"), path.join(dir, "ref", "cards"), path.join(dir, "reports")]) fs.mkdirSync(d, { recursive: true });
  fs.copyFileSync(path.join(REPO_ROOT, "engine", "cards", "team_possession.json"), path.join(dir, "ref", "cards", "team_possession.json"));
  fs.writeFileSync(path.join(dir, "pack", "pack.json"), JSON.stringify({ id: "game.x", version: "0.1.1", kernelApi: "1.0", tests: ["tests/bot_hand_newcomer.gd", "tests/bot_hand_perfect.gd"] }));
  const asked: string[] = [];
  const h = {
    s: { plan: [{ id: "crews_stakes", registers: { tests: ["tests/bot_hand_newcomer.gd", "tests/bot_hand_perfect.gd"] } }], packages: {}, card: "card.team_possession", lastSeq: 40 },
    events: [],
    dir: (...p: string[]) => path.join(dir, ...p),
    append: (e: Record<string, unknown>) => e,
    verifyLogged: async (a: { args: string[] }) => {
      asked.push(a.args.join(" "));
      const seed = Number(/--seed=(\d+)/.exec(a.args[1] ?? "")?.[1]);
      if (/perfect/.test(a.args[0] ?? "") && seed === 7) return { ok: false, flags: ["stdout_not_json", "report_missing", "never_started"], inconclusive: "inconclusive: the engine never began this check", summary: "" };
      return { ok: true, flags: [], report: { bot: { done: true, result: { won: true } } } };
    },
  } as unknown as GateHost;
  const r = await runHandChecks(h, path.join(dir, "pack"));
  assert.equal(r.failure, "", r.failure);
  const perfect = r.rows.find((x) => x.hand === "perfect");
  assert.equal(perfect?.completed, 20, "20 finished runs: seed 21 ran in seed 7's place");
  assert.ok(asked.includes("--test=tests/bot_hand_perfect.gd --seed=21"));
});

test("D27 R5 33/40 (J2nd's court copy, events 1629-1863 and 1981: the change with \"Make it fairer\" ended NOT made at 1858, and the cue-only change sent after it was still judged as a fairness change; the newcomer card guarded it): a change that ended without a promotion no longer colours the next", () => {
  const events = fixture<{ events: JobEvent[] }>("j2nd-court-fair-failed.json").events;
  const during = askedChange(events.filter((e) => e.seq < 1858));
  assert.equal(during?.kind, "fair", "while the fairness ask was in flight it was a fair change");
  const after = askedChange(events);
  assert.equal(after?.seq, 1859, "only the cue sentence sent after the failed change");
  assert.notEqual(after?.kind, "fair");
  assert.doesNotMatch(after?.text ?? "", /Make it fairer/);
});

test("D27 R5 J2nd finding 11 (the failed change's tuning rode back in through the workspaces): a change that ends unmade puts pack/ back AND cuts every workspace again", () => {
  const dir = tempDir("d27-unmade-ws");
  const pd = path.join(dir, "promoted", "game.x");
  for (const d of [pd, path.join(dir, "pack"), path.join(dir, "ws", "crews_stakes", "data")]) fs.mkdirSync(d, { recursive: true });
  fs.writeFileSync(path.join(pd, "pack.json"), "{}");
  fs.writeFileSync(path.join(dir, "pack", "pack.json"), "{}");
  fs.writeFileSync(path.join(dir, "pack", "x.json"), "unmade");
  fs.writeFileSync(path.join(dir, "ws", "crews_stakes", "data", "crews.json"), "{\"rival_error_f\": [24]}");
  fs.writeFileSync(path.join(dir, "ws", "crews_stakes.baseline.json"), "{}");
  const events = [{ v: 1, seq: 1, ts: "2026-11-27T12:00:00.000Z", job: "j", type: "job_created", sentence: "x", packId: "game.x", title: "x" }, { v: 1, seq: 2, ts: "2026-11-27T12:00:00.000Z", job: "j", type: "promoted", packId: "game.x", version: "0.1.8", dest: "promoted/game.x" }] as unknown as JobEvent[];
  const h = { o: { verifier: { location: { engineDir: dir } } }, s: { job: "j", promoted: { packId: "game.x", version: "0.1.8", dest: "promoted/game.x" }, mergedSincePromotion: true, lastSeq: 5, order: ["crews_stakes"], packages: { crews_stakes: { mergedFiles: [] } } }, events, dir: (...p: string[]) => path.join(dir, ...p), append: (e: Record<string, unknown>) => e } as unknown as Parameters<typeof restoreLastPromotion>[0];
  assert.match(restoreLastPromotion(h), /pack\/ was put back to the last promotion/);
  assert.equal(fs.existsSync(path.join(dir, "ws", "crews_stakes")), false, "the workspace with the unmade tuning is gone");
  assert.equal(fs.existsSync(path.join(dir, "ws", "crews_stakes.baseline.json")), false);
});

test("D27 R5 29 (S4's Arsenal re-run, s4a2 events 1076-1131: the quick cartridge edit said \"a builder needs to add both\" and set game.ai.body_check 1 -> 1 for the rivals' hip check, and v0.1.24 was promoted without a builder): a diff that leaves part of the ask unmade, or sets a key to the value it had, goes to the builder", () => {
  const d = fixture<{ why: string; changed: string[] }>("s4a2-cartridge-r13-diff.json");
  assert.match(diffLeavesUnmade(d.why, d.changed) ?? "", /^it leaves part of the ask unmade, in its own words: "F is now a hip check/);
  assert.match(diffLeavesUnmade("F is now a hip check.", d.changed) ?? "", /^it sets game\.ai\.body_check: 1 -> 1 \(the value it already had\)/);
  assert.equal(diffLeavesUnmade("Wider goals, as asked.", ["game.rink.goal_width_m: 2.8 -> 3.2"]), undefined, "a whole diff stands");
});
