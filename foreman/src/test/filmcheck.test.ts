// D3 of 22 Nov: the film cross-check. A bot's metrics and moments are claims; the strips the look already took are the
// evidence. A strip in which nothing moves for 50+ frames contradicts an idle_max_f under that; a contact strip in which
// nothing moves contradicts the contact moment it was filmed for. A contradicted claim fails the tofu row and the house
// compare. Strips are drawn here as real PNG files (every PNG row filter used), so the decoder is tested too.
import { test, after } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import zlib from "node:zlib";
import { cleanup, tempDir } from "./helpers.js";
import { BLOCK, STILL_MIN_F, botClaims, claimsOfResult, crossCheckFilm, decodePng, filmCheckText, stripInfo, stripMotion } from "../filmcheck.js";
import { judgeTofu, tofuMetricsFor } from "../tofu.js";
import { claimsLine, filmCheckOf, tofuLook } from "../quality.js";
import { contactFrame, houseCompare, type HouseBaseline } from "../house.js";
import { CONTACT_STRIP, STRIP, resultMoments, stripLabel, type Shot } from "../shots.js";
import { designTemplateProblems, templateOf } from "../templates.js";
import type { GateHost } from "../p10gate.js";
import type { DesignDoc, JobEvent, PackageSpec } from "../events.js";

after(cleanup);

// ---------- a PNG writer for the fixtures: RGB, rows filtered None, Sub, Up, Average, Paeth in turn ----------

function encodePng(width: number, height: number, rgb: Uint8Array): Buffer {
  const stride = width * 3;
  const raw = Buffer.alloc((stride + 1) * height);
  for (let y = 0; y < height; y++) {
    const f = y % 5;
    raw[y * (stride + 1)] = f;
    for (let x = 0; x < stride; x++) {
      const v = rgb[y * stride + x] as number;
      const a = x >= 3 ? (rgb[y * stride + x - 3] as number) : 0;
      const b = y > 0 ? (rgb[(y - 1) * stride + x] as number) : 0;
      const c = x >= 3 && y > 0 ? (rgb[(y - 1) * stride + x - 3] as number) : 0;
      const q = a + b - c;
      const pa = Math.abs(q - a), pb = Math.abs(q - b), pc = Math.abs(q - c);
      const pred = [0, a, b, (a + b) >> 1, pa <= pb && pa <= pc ? a : pb <= pc ? b : c][f] as number;
      raw[y * (stride + 1) + 1 + x] = (v - pred) & 0xff;
    }
  }
  const chunk = (kind: string, body: Buffer): Buffer => {
    const len = Buffer.alloc(4);
    len.writeUInt32BE(body.length);
    const kb = Buffer.from(kind, "latin1");
    const crc = Buffer.alloc(4);
    crc.writeUInt32BE(zlib.crc32(Buffer.concat([kb, body])) >>> 0);
    return Buffer.concat([len, kb, body, crc]);
  };
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(width, 0);
  ihdr.writeUInt32BE(height, 4);
  ihdr[8] = 8; ihdr[9] = 2; ihdr[10] = 0; ihdr[11] = 0; ihdr[12] = 0;
  return Buffer.concat([Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]), chunk("IHDR", ihdr), chunk("IDAT", zlib.deflateSync(raw)), chunk("IEND", Buffer.alloc(0))]);
}

const TW = 160, TH = 90; // a tile: 20 x 11 blocks of 8 px

/**
 * A 4x3 strip on sand: two bodies (dark boxes) per tile. `bodyX(i)` gives the left body's x in tile i; the right body
 * stands 60 px to its right (bodyX stays within 0..76 so both fit the 160 px tile). A body that moves between tiles changes a dozen or more blocks; a still one none.
 */
function drawStrip(file: string, bodyX: (tile: number) => number): void {
  const w = TW * 4, h = TH * 3;
  const rgb = new Uint8Array(w * h * 3);
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    const i = (y * w + x) * 3;
    rgb[i] = 230; rgb[i + 1] = 150 + (((x % TW) * 7 + (y % TH) * 3) % 9); rgb[i + 2] = 80; // sand with a fine texture (the same in every tile)
  }
  for (let t = 0; t < 12; t++) {
    const ox = (t % 4) * TW, oy = Math.floor(t / 4) * TH;
    for (const bx of [bodyX(t), bodyX(t) + 60]) for (let y = 30; y < 78; y++) for (let x = bx; x < bx + 24; x++) {
      const i = ((oy + y) * w + ox + x) * 3;
      rgb[i] = 40; rgb[i + 1] = 60; rgb[i + 2] = 200;
    }
  }
  fs.writeFileSync(file, encodePng(w, h, rgb));
}

const shot = (bot: string): Shot => ({ bot, package: "core", frames: [], kind: "own" });
const motionLabel = (from: number, bot = "tests/bot_tofu.gd"): string => stripLabel("side", from, shot(bot));
const contactLabel = (moment: number, bot = "tests/bot_tofu.gd"): string => stripLabel("side", moment - CONTACT_STRIP.before, shot(bot), CONTACT_STRIP.step);

test("decodePng reads what it is given, every row filter, and refuses what it cannot read", () => {
  const dir = tempDir("film-png");
  const rgb = new Uint8Array(37 * 11 * 3).map((_, i) => (i * 31 + (i >> 5) * 7) & 0xff);
  const file = path.join(dir, "a.png");
  fs.writeFileSync(file, encodePng(37, 11, rgb));
  const r = decodePng(fs.readFileSync(file));
  assert.deepEqual([r.width, r.height, r.channels], [37, 11, 3]);
  assert.deepEqual(Buffer.from(r.data), Buffer.from(rgb), "None, Sub, Up, Average and Paeth rows all decode to the pixels");
  assert.throws(() => decodePng(Buffer.from("not a png at all, not at all")), /not a PNG/);
});

test("stripInfo reads the labels the look writes: motion strips, contact strips, the house strip", () => {
  assert.deepEqual(stripInfo("captures/x.png", motionLabel(9550)), { capture: "captures/x.png", from: 9550, step: STRIP.step, count: 12, cols: 4, rows: 3, bot: "tests/bot_tofu.gd", cam: "side" });
  const c = stripInfo("captures/y.png", contactLabel(2269));
  assert.deepEqual([c?.from, c?.step, c?.contact], [2259, 2, 2269]);
  const house = stripInfo("reports/house-duel/strip-side-f2259.png", "HOUSE GAME engine/packs/duel (the bar, not this build): CONTACT MOTION STRIP (4 columns x 3 rows, frames 2259, 2261, ... 2281, 2 frames apart; the contact at frame 2269), tests/bot_checklist_wall.gd on camera side: a moment");
  assert.deepEqual([house?.from, house?.step, house?.contact, house?.bot, house?.house], [2259, 2, 2269, "tests/bot_checklist_wall.gd", true]);
  assert.equal(stripInfo("z.png", "a still of camera side"), undefined, "no frames in the label: not a strip it can place");
});

test("a strip where nothing moves for 55 frames contradicts idle_max_f 37 (proof -3); the tofu row fails and the house compare is short", () => {
  const dir = tempDir("film-idle");
  drawStrip(path.join(dir, "still.png"), () => 30);
  drawStrip(path.join(dir, "moving.png"), (t) => 10 + t * 6);
  const m = stripMotion(path.join(dir, "still.png"), stripInfo("still.png", motionLabel(9550)) as NonNullable<ReturnType<typeof stripInfo>>);
  assert.ok(!("unmeasured" in m));
  assert.deepEqual(m.longestStill, { firstTile: 1, lastTile: 12, fromFrame: 9550, toFrame: 9605, frames: 55 });
  const metrics = { feedback_f: 1, skill_spread: 0.4, skill_variants: 3, idle_max_f: 37, tell_min_f: 14, tells: 9, pressure_waves: 3, lead_change_share: 0.5, close_rounds: 2, verbs_used: 5 };
  const check = crossCheckFilm([{ capture: "moving.png", label: motionLabel(1571) }, { capture: "still.png", label: motionLabel(9550) }], () => ({ metrics }), (c) => path.join(dir, c));
  assert.equal(check.measured, 2);
  assert.equal(check.findings.length, 1);
  assert.deepEqual([check.findings[0]?.kind, check.findings[0]?.claim, check.findings[0]?.capture], ["idle", "idle_max_f 37", "still.png"]);
  assert.match(check.line, /1 claim\(s\) CONTRADICTED by the film: tests\/bot_tofu\.gd claims idle_max_f 37, but tiles 1-12 of still\.png \(frames 9550-9605\) do not change: nothing on screen moves for at least 55 frames/);
  const rows = tofuMetricsFor(undefined);
  const honest = judgeTofu(metrics, rows, "tests/bot_tofu.gd", "regular", "reports/b.json");
  assert.equal(honest.ok, true, "the same figures pass without the film");
  const t = judgeTofu(metrics, rows, "tests/bot_tofu.gd", "regular", "reports/b.json", check);
  assert.equal(t.ok, false, "a contradicted claim cannot pass the tofu check");
  const row = t.rows.find((r) => r.id === "idle_max_f");
  assert.deepEqual([row?.value, row?.ok], [37, false]);
  assert.match(row?.contradicted ?? "", /at least 55 frames/);
  assert.match(t.line, /TOFU STAGE NOT ok[^]*idle_max_f 37 CONTRADICTED by the film/);
  const base: HouseBaseline = { schema: "tl.foreman.house/1", pack: "duel", test: "tests/bot_checklist_wall.gd", hand: "regular", metrics: { idle_max_f: 64 } };
  assert.deepEqual(houseCompare(honest, base, rows).short, [], "37 against the house game's 64 is not short by the figure alone");
  const vs = houseCompare(t, base, rows);
  assert.deepEqual(vs.short, ["idle_max_f"], "a contradicted claim cannot pass the house compare");
  assert.match(vs.line, /idle_max_f 37 \(CONTRADICTED by the film\) vs 64 SHORT/);
  assert.match(claimsLine(t, check) ?? "", /^MEASURED FROM THE FILM[^]*CLAIM CONTRADICTED: tests\/bot_tofu\.gd claims idle_max_f 37[^]*\nThe tofu bot's own figures/);
});

test("an honest claim passes: bodies moving, or a still run the claim already covers, or a still run under 50 frames", () => {
  const dir = tempDir("film-honest");
  drawStrip(path.join(dir, "moving.png"), (t) => 10 + t * 6);
  drawStrip(path.join(dir, "still.png"), () => 30);
  drawStrip(path.join(dir, "pause.png"), (t) => (t < 4 || t > 11 ? 10 + t * 9 : 46)); // tiles 5-12 still: 35 frames
  const at = (c: string): string => path.join(dir, c);
  const idle = (n: number) => () => ({ metrics: { idle_max_f: n } });
  assert.deepEqual(crossCheckFilm([{ capture: "moving.png", label: motionLabel(100) }], idle(37), at).findings, [], "every tile moves");
  assert.deepEqual(crossCheckFilm([{ capture: "still.png", label: motionLabel(100) }], idle(90), at).findings, [], "55 still frames against a claim of 90: consistent");
  const pause = crossCheckFilm([{ capture: "pause.png", label: motionLabel(100) }], idle(20), at);
  assert.deepEqual(pause.findings, [], `a 35-frame stand (under ${STILL_MIN_F}) is not a finding, even against 20`);
  assert.equal(pause.strips[0]?.still_f, 35);
  assert.deepEqual(crossCheckFilm([{ capture: "still.png", label: motionLabel(100) }], () => ({}), at).findings, [], "no idle_max_f claimed: nothing to contradict (the tofu row fails on its own as not reported)");
  const ok = judgeTofu({ idle_max_f: 37 }, tofuMetricsFor(undefined).filter((m) => m.id === "idle_max_f"), "tests/bot_tofu.gd", undefined, "r.json", crossCheckFilm([{ capture: "moving.png", label: motionLabel(100) }], idle(37), at));
  assert.equal(ok.ok, true);
  assert.equal(ok.rows.some((r) => r.contradicted !== undefined), false);
});

test("a claimed contact whose contact strip shows nothing moving is contradicted; one with motion passes (row moments_on_film)", () => {
  const dir = tempDir("film-contact");
  drawStrip(path.join(dir, "dead.png"), () => 40);
  drawStrip(path.join(dir, "hit.png"), (t) => (t < 5 ? 20 + t * 6 : t < 8 ? 50 : 50 - (t - 7) * 8)); // closes in, holds (hit-stop), knocked back
  const moments = [{ kind: "parried", frame: 2269 }, { kind: "rolled", frame: 3100 }];
  const claims = () => ({ metrics: { idle_max_f: 40 }, moments });
  const at = (c: string): string => path.join(dir, c);
  const bad = crossCheckFilm([{ capture: "dead.png", label: contactLabel(2269) }, { capture: "hit.png", label: contactLabel(3100) }], claims, at);
  assert.equal(bad.findings.length, 1);
  assert.deepEqual([bad.findings[0]?.kind, bad.findings[0]?.claim, bad.findings[0]?.moment], ["contact", "parried at frame 2269", "parried"]);
  assert.match(bad.findings[0]?.measured ?? "", /no tile of the contact strip dead\.png \(frames 2259-2281\) differs/);
  const rows = tofuMetricsFor(undefined).filter((m) => m.id === "idle_max_f");
  const t = judgeTofu({ idle_max_f: 40 }, rows, "tests/bot_tofu.gd", undefined, "r.json", bad);
  const row = t.rows.find((r) => r.id === "moments_on_film");
  assert.deepEqual([row?.value, row?.want, row?.ok, t.ok], [1, "0 of 2 contact strip(s) still", false, false]);
  const base: HouseBaseline = { schema: "tl.foreman.house/1", pack: "duel", test: "t", metrics: { idle_max_f: 64 } };
  const vs = houseCompare(t, base, rows);
  assert.deepEqual(vs.short, ["moments_on_film"]);
  assert.match(vs.line, /The build's own film contradicts its moments_on_film/);
  const good = crossCheckFilm([{ capture: "hit.png", label: contactLabel(3100) }], claims, at);
  assert.deepEqual(good.findings, []);
  const g = judgeTofu({ idle_max_f: 40 }, rows, "tests/bot_tofu.gd", undefined, "r.json", good);
  assert.deepEqual([g.rows.find((r) => r.id === "moments_on_film")?.value, g.ok], [0, true], "a hit-stop of 3 held tiles inside a moving strip is not a dead strip");
  assert.equal(judgeTofu({ idle_max_f: 40 }, rows, "tests/bot_tofu.gd", undefined, "r.json").rows.some((r) => r.id === "moments_on_film"), false, "no contact strip measured: no row (not measured is not zero)");
});

test("another bot's or the house game's still strip never fails this bot's claims; an unreadable strip is unmeasured, never still", () => {
  const dir = tempDir("film-other");
  drawStrip(path.join(dir, "still.png"), () => 30);
  fs.writeFileSync(path.join(dir, "tiny.png"), encodePng(1, 1, new Uint8Array([1, 2, 3])));
  fs.writeFileSync(path.join(dir, "broken.png"), "nope");
  const at = (c: string): string => path.join(dir, c);
  const claims = () => ({ metrics: { idle_max_f: 37 } });
  const other = crossCheckFilm([{ capture: "still.png", label: motionLabel(100, "tests/bot_rally.gd") }], claims, at);
  assert.equal(other.findings[0]?.bot, "tests/bot_rally.gd");
  assert.equal(judgeTofu({ idle_max_f: 37 }, tofuMetricsFor(undefined).filter((m) => m.id === "idle_max_f"), "tests/bot_tofu.gd", undefined, "r.json", other).ok, true, "the rally bot's claim is the rally bot's");
  const house = crossCheckFilm([{ capture: "still.png", label: "HOUSE GAME engine/packs/duel (the bar, not this build): CONTACT MOTION STRIP (4 columns x 3 rows, frames 90, 92, ... 112, 2 frames apart; the contact at frame 100), tests/bot_tofu.gd on camera side: x" }], claims, at);
  assert.equal(house.findings.length, 1, "the house strip is measured and its own claims checked");
  assert.equal(judgeTofu({ idle_max_f: 37 }, tofuMetricsFor(undefined).filter((m) => m.id === "idle_max_f"), "tests/bot_tofu.gd", undefined, "r.json", house).ok, true, "but it never fails this build's tofu bot, even by the same test name");
  const un = crossCheckFilm([{ capture: "tiny.png", label: motionLabel(100) }, { capture: "broken.png", label: motionLabel(100) }, { capture: "gone.png", label: motionLabel(100) }], claims, at);
  assert.deepEqual([un.measured, un.unmeasured.length, un.findings.length], [0, 3, 0]);
  assert.match(un.unmeasured[0] ?? "", new RegExp(`too small for 4x3 tiles`));
  assert.equal(filmCheckText(un), undefined, "nothing measured: the critic is told nothing about the film");
  assert.ok(BLOCK * 4 > 1);
});

test("moments are read where the bots keep them: top level, metrics.moments, metrics.raw.moments (the house hockey today)", () => {
  const hockey = { metrics: { idle_max_f: 70, raw: { moments: { poked: [523], one_timer: [761], bobble: [1395] } } } };
  assert.deepEqual(resultMoments(hockey), { poked: [523], one_timer: [761], bobble: [1395] });
  assert.deepEqual(resultMoments({ moments: { parried: [2269] }, metrics: { moments: { x: [1] } } }), { parried: [2269] }, "the top level first (PACK.md)");
  assert.equal(resultMoments({ metrics: {} }), undefined);
  assert.equal(contactFrame({ bot: { frames: 7079, result: hockey } }, ["one_timer", "poked"]), 761, "the house hockey strip films its one-timer, not its last minute");
  assert.deepEqual(claimsOfResult(hockey).moments?.map((m) => m.kind), ["poked", "one_timer", "bobble"]);
});

test("the look: filmCheckOf writes reports/film-*.json and tofuLook fails a contradicted claim, read from the job's own bot report", () => {
  const dir = tempDir("film-look");
  fs.mkdirSync(path.join(dir, "captures"), { recursive: true });
  fs.mkdirSync(path.join(dir, "reports"), { recursive: true });
  drawStrip(path.join(dir, "captures", "blockout-side-bot_tofu-strip-f9550.png"), () => 30);
  const metrics = { feedback_f: 1, skill_spread: 0.4, skill_variants: 3, idle_max_f: 37, tell_min_f: 14, tells: 9, pressure_waves: 3, lead_change_share: 0.5, close_rounds: 2, verbs_used: 5, hand: "regular" };
  fs.writeFileSync(path.join(dir, "reports", "core-r1-bot-s5.json"), JSON.stringify({ bot: { test: "tests/bot_tofu.gd", done: true, frames: 12000, result: { ok: true, metrics, moments: { hit: [400] } } } }));
  const events = [{ v: 1, seq: 5, ts: "t", job: "j", type: "verify", round: 1, level: "V4", verb: "bot", ok: true, report: "reports/core-r1-bot-s5.json" }] as unknown as JobEvent[];
  const plan: PackageSpec[] = [{ id: "core", title: "c", milestone: "blockout", deps: [], scope: ["scripts/main.gd"], contract: "TOFU CHECK: tests/bot_tofu.gd reports metrics x", acceptance: [{ level: "V4", verb: "bot", args: ["--test=tests/bot_tofu.gd"] }], registers: { tests: ["tests/bot_tofu.gd"] } }];
  const h = { s: { plan, lastSeq: 5, brief: undefined }, events, dir: (...p: string[]) => path.join(dir, ...p), rel: (abs: string) => path.relative(dir, abs).split(path.sep).join("/") } as unknown as GateHost;
  assert.deepEqual(botClaims(dir, events, "tests/bot_tofu.gd").moments, [{ kind: "hit", frame: 400 }]);
  assert.deepEqual(botClaims(dir, events, "tests/bot_tofu.gd", 5), {}, "claims as the log stood before seq 5: none yet");
  const film = { captures: [], labels: [], notes: [], strips: [{ capture: "captures/blockout-side-bot_tofu-strip-f9550.png", label: motionLabel(9550) }] };
  const check = filmCheckOf(h, "blockout", film);
  assert.equal(check?.findings.length, 1);
  const written = JSON.parse(fs.readFileSync(path.join(dir, "reports", "film-blockout-s6.json"), "utf8")) as { schema: string; ok: boolean; findings: unknown[] };
  assert.deepEqual([written.schema, written.ok, written.findings.length], ["tl.foreman.film/1", false, 1]);
  const tofu = tofuLook(h, "blockout", check);
  assert.equal(tofu?.ok, false);
  assert.match(tofu?.line ?? "", /idle_max_f 37 CONTRADICTED by the film/);
  const report = JSON.parse(fs.readFileSync(path.join(dir, "reports", "tofu-blockout-s6.json"), "utf8")) as { film?: { findings: unknown[] }; rows: { id: string; contradicted?: string }[] };
  assert.equal(report.film?.findings.length, 1, "the tofu report keeps the film check");
  assert.ok(report.rows.find((r) => r.id === "idle_max_f")?.contradicted);
  assert.equal(filmCheckOf(h, "blockout", { ...film, strips: [] }), undefined, "no strips: no film check, no report");
});

test("a design verb that names the move's CLIP is told the move id (the first hockey job failed three times on poke/cross_check)", () => {
  const t = templateOf("arcade_sport");
  assert.ok(t);
  const verb = { id: "poke", input: "a quick stick jab", anticipation_f: 5, active_f: 7, recovery_f: 12, move: "cross_check" } as unknown as DesignDoc["verbs"][number];
  const problems = designTemplateProblems({ verbs: [verb] } as unknown as DesignDoc, { id: "arcade_sport", reference: "r", copies: [] });
  assert.match(problems.join(""), /"cross_check" is the CLIP of move "poke"; write "move": "poke"/);
  assert.deepEqual(designTemplateProblems({ verbs: [{ ...verb, move: "poke" }] } as unknown as DesignDoc, { id: "arcade_sport", reference: "r", copies: [] }), []);
});
