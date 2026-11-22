// D3 of 22 Nov (N4's next-three item 2): a revise round works from a pair. The builder gets its own contact strip beside
// the house game's at the same contact kind (copied into ref/look/, which builders read), and the diff of its contact
// numbers against the house game's file. The proofs stalled at house_game 0.45-0.5 after two rounds of notes alone.
import { test, after } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { cleanup, tempDir } from "./helpers.js";
import { contactDiff, numberLeaves, pairStrips, revisePair, sameKind } from "../revisepair.js";
import { sendBack } from "../quality.js";
import { CONTACT_STRIP, stripLabel, type Shot } from "../shots.js";
import type { GateHost } from "../p10gate.js";
import type { JobEvent } from "../events.js";

after(cleanup);

const shot: Shot = { bot: "tests/bot_tofu.gd", package: "core", frames: [], kind: "own" };
const contact = (moment: number, cam = "side"): string => stripLabel(cam, moment - CONTACT_STRIP.before, shot, CONTACT_STRIP.step);
const houseLabel = (moment: number): string => `HOUSE GAME engine/packs/duel (the bar, not this build): CONTACT MOTION STRIP (4 columns x 3 rows, frames ${moment - 10}, ${moment - 8}, ... ${moment + 12}, 2 frames apart; the contact at frame ${moment}), tests/bot_checklist_wall.gd on camera side: a moment`;

/** A job folder: a bot report with moments, the house drill report, both strips, pack/ and ref/packs/duel contacts. */
function job(buildContacts: unknown | undefined): { dir: string; events: JobEvent[] } {
  const dir = tempDir("pair");
  for (const d of ["reports/house-duel", "captures", "pack/data", "ref/packs/duel/data"]) fs.mkdirSync(path.join(dir, ...d.split("/")), { recursive: true });
  fs.writeFileSync(path.join(dir, "reports", "core-r1-bot-s4.json"), JSON.stringify({ bot: { test: "tests/bot_tofu.gd", done: true, frames: 3000, result: { ok: true, moments: { hit: [400], parried: [900] } } } }));
  fs.writeFileSync(path.join(dir, "reports", "house-duel-drill-s2.json"), JSON.stringify({ bot: { test: "tests/bot_checklist_wall.gd", done: true, frames: 9000, result: { ok: true, moments: { parried: [2269], hit: [2400] } } } }));
  for (const f of ["captures/blockout-side-bot_tofu-strip-f390.png", "captures/blockout-side-bot_tofu-strip-f890.png", "reports/house-duel/strip-side-f2259.png"]) fs.writeFileSync(path.join(dir, ...f.split("/")), f);
  fs.writeFileSync(path.join(dir, "ref", "packs", "duel", "data", "contacts.json"), JSON.stringify({ _about: "x", heavy_block: { hitstop: 6, blockstun: 18, push: 0.35 }, light_parried: { hitstop: 10, parried: 52 }, poses: { HITSTUN: { anim: [[0, 0], [3, 3.2]] } } }));
  if (buildContacts !== undefined) fs.writeFileSync(path.join(dir, "pack", "data", "contacts.json"), JSON.stringify(buildContacts));
  const events = [{ v: 1, seq: 4, ts: "t", job: "j", type: "verify", round: 1, level: "V4", verb: "bot", ok: true, report: "reports/core-r1-bot-s4.json" }] as unknown as JobEvent[];
  return { dir, events };
}

const strips = [{ capture: "captures/blockout-side-bot_tofu-strip-f390.png", label: contact(400) }, { capture: "captures/blockout-side-bot_tofu-strip-f890.png", label: contact(900) }];
const house = { capture: "reports/house-duel/strip-side-f2259.png", label: houseLabel(2269) };

test("numbers by path, kinds by family", () => {
  assert.deepEqual([...numberLeaves({ _about: "s", a: { b: 1, c: [2, 3] }, d: "x" })], [["a.b", 1], ["a.c.0", 2], ["a.c.1", 3]]);
  assert.ok(sameKind("poke", "poked") && sameKind("parry", "parried") && sameKind("one_timer", "one_timer"));
  assert.ok(!sameKind("hit", "hit_heavy"), "words under 4 letters match only exactly");
  assert.ok(!sameKind("parried", "poked"));
});

test("contactDiff: rows that differ, house rows the build lacks, a build without the file, a build that matches", () => {
  const { dir } = job({ heavy_block: { hitstop: 3, blockstun: 18, push: 0.35 }, poses: { HITSTUN: { anim: [[0, 0], [3, 3.2]] } } });
  const d = contactDiff(path.join(dir, "pack"), path.join(dir, "ref", "packs", "duel"), "duel", "duel");
  assert.deepEqual(d?.differ, ["data/contacts.json heavy_block.hitstop: yours 3, house 6"]);
  assert.deepEqual(d?.missing, ["data/contacts.json light_parried.hitstop (house 10)", "data/contacts.json light_parried.parried (house 52)"]);
  assert.match(d?.line ?? "", /^1 contact number\(s\) differ from engine\/packs\/duel: data\/contacts\.json heavy_block\.hitstop: yours 3, house 6\. 2 house contact row\(s\) your pack does not have/);
  const none = job(undefined);
  assert.match(contactDiff(path.join(none.dir, "pack"), path.join(none.dir, "ref", "packs", "duel"), "duel", "duel")?.line ?? "", /the build has no data\/contacts\.json: the house game keeps 9 contact numbers there/);
  const same = job({ _about: "mine", heavy_block: { hitstop: 6, blockstun: 18, push: 0.35 }, light_parried: { hitstop: 10, parried: 52 }, poses: { HITSTUN: { anim: [[0, 0], [3, 3.2]] } } });
  assert.match(contactDiff(path.join(same.dir, "pack"), path.join(same.dir, "ref", "packs", "duel"), "duel", "duel")?.line ?? "", /yours match engine\/packs\/duel on every row/);
  assert.equal(contactDiff(path.join(same.dir, "pack"), path.join(same.dir, "ref", "packs", "duel"), "own", "duel"), undefined, "a template without a house contact file");
});

test("pairStrips: the build's contact strip of the house strip's kind, else its first one, said as such", () => {
  const { dir, events } = job(undefined);
  const p = pairStrips(dir, events, strips, house, "parried");
  assert.deepEqual(p, { kind: "parried", same: true, build: { capture: "captures/blockout-side-bot_tofu-strip-f890.png", kind: "parried" }, house: { capture: house.capture, kind: "parried" } });
  const other = pairStrips(dir, events, strips, house, "wall_splat");
  assert.deepEqual([other?.same, other?.build.kind], [false, "hit"]);
  assert.equal(pairStrips(dir, events, [{ capture: "c.png", label: stripLabel("side", 100, shot) }], house, "parried"), undefined, "no contact strip of its own: no pair");
});

test("revisePair copies both strips into ref/look/ and sendBack puts the pair first in the round's feedback", () => {
  const { dir, events } = job({ heavy_block: { hitstop: 3, blockstun: 18, push: 0.35 } });
  const appended: { type: string; detail?: string }[] = [];
  const h = {
    s: { plan: [], lastSeq: 9, packages: {}, order: [] },
    events,
    dir: (...p: string[]) => path.join(dir, ...p),
    rel: (abs: string) => path.relative(dir, abs).split(path.sep).join("/"),
    pkg: () => ({ round: 1 }),
    append: (e: { type: string; detail?: string }) => { appended.push(e); return e; },
  } as unknown as GateHost;
  const text = revisePair(h, "blockout", 1, strips, { pack: "duel", strips: [house] }, "duel");
  assert.match(text ?? "", /^THE PAIR \(open both with your Read tool before you change code\): ref\/look\/blockout-r1\/yours-parried\.png is YOUR contact strip \(parried\), ref\/look\/blockout-r1\/house-parried\.png the HOUSE GAME's \(parried\)[^]*Same contact kind[^]*data\/contacts\.json heavy_block\.hitstop: yours 3, house 6/);
  assert.equal(fs.readFileSync(path.join(dir, "ref", "look", "blockout-r1", "yours-parried.png"), "utf8"), "captures/blockout-side-bot_tofu-strip-f890.png");
  assert.equal(fs.readFileSync(path.join(dir, "ref", "look", "blockout-r1", "house-parried.png"), "utf8"), "reports/house-duel/strip-side-f2259.png");
  assert.equal(revisePair(h, "blockout", 1, strips, undefined, "duel"), undefined, "no house game: no pair");
  sendBack(h, "blockout", ["core"], "core", 1, { captures: [], strips, verdict: { ok: false, scores: { feel: 0.4 }, notes: ["x".repeat(2000)], report: "reports/critic-blockout-s9.json" }, summary: "s" }, undefined, text);
  const queued = appended.find((e) => e.type === "package_state");
  assert.match(queued?.detail ?? "", /^[^:]+: THE PAIR/, "the pair comes before the critic's notes, so the 1500-character clip never cuts it");
  assert.match(queued?.detail ?? "", /heavy_block\.hitstop: yours 3, house 6/);
});
