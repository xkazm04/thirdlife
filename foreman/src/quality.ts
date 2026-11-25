// The quality loop and motion strips (JOB.md "Added 2026-11-21"), acted out: film a milestone's look (stills and
// strips), have the critic judge it, compare a revise round with the version before and keep the better (restoring
// the snapshot when the previous one wins), send a NOT ok look back for a revise round, or leave it for the owner's
// hold. quality_state.ts decides from the log; these functions write. Kept out of foreman.ts (its line ratchet),
// over the Foreman's gate host as p10gate.ts is.
import fs from "node:fs";
import path from "node:path";
import type { Milestone, Strip } from "./events.js";
import type { GateHost } from "./p10gate.js";
import { critic, generate, type RubricItem } from "./designer.js";
import { NOTE_NOT_KEPT, criticRubric, packageLinesOf } from "./phases.js";
import { CRITIC_ROUND, criticReopenFor } from "./rounds.js";
import { QUALITY_ROUNDS, type Look } from "./quality_state.js";
import { CONTACT_STRIP, STRIP, botMoments, shotLabel, stripFile, stripFrom, stripLabel, type Shot } from "./shots.js";
import { foldEvents } from "./joblog.js";
import { copyDir } from "./scope.js";
import { FOREMAN_NOTE, clip } from "./conduct.js";
import { PKG_ROOT, toPosix } from "./paths.js";
import { slopIds } from "./roomtext.js";
import type { RunnerVerbs } from "./verbs.js";
import type { CritiqueResult } from "./verifier.js";
import { courtOf, judgeTofu, readTofuMetrics, tofuMetricsFor, tofuOf, type TofuResult } from "./tofu.js";
import { HOUSE_BOTS, contactMoment, houseBaseline, houseCompare, saveBaseline, type HouseBaseline } from "./house.js";
import { botClaims, crossCheckFilm, filmCheckText, type FilmCheck } from "./filmcheck.js";
import { revisePair, sameKind } from "./revisepair.js";
import { killItem, methodBlock } from "./method.js";
import { templateOf } from "./templates.js";
import { coreLook, jobCore } from "./coregate.js";
import { BODY, foreignWords, gameHasVerb, gameWords } from "./gamewords.js";
import { sayLookNotPlay } from "./playsame.js";
import { cameraNotesMissed } from "./camnote.js";
import { withLifts } from "./boundlift.js"; // H1e: judged by the game's own design
import { HOUSE_CONTACTS, numberLeaves } from "./revisepair.js"; // E3 of 24 Nov: the measured check of a game on a core

/** True when the engine's runner can film a strip in one capture run (`--strip` in its verbs.json). */
export function stripsOn(verbs: RunnerVerbs | undefined): boolean {
  const opts = (verbs?.verbs["capture"] as { options?: Record<string, unknown> } | undefined)?.options ?? {};
  return Object.prototype.hasOwnProperty.call(opts, "strip");
}

/**
 * H1 of 25 Nov (E5e defect 1: the critic's reasons said "no ring, no score, no clock" on a game whose HUD draws all
 * three, because its captures were filmed with the capture verb's default, the HUD hidden): every capture a critic or a
 * person judges is filmed as a person sees the game, HUD on, when the engine's runner can keep it (`hud` in its
 * verbs.json, K2). A runner that cannot gets its captures labelled with exactly what is hidden.
 */
export function hudOn(verbs: RunnerVerbs | undefined): boolean {
  const opts = (verbs?.verbs["capture"] as { options?: Record<string, unknown> } | undefined)?.options ?? {};
  return Object.prototype.hasOwnProperty.call(opts, "hud");
}

/** The capture argument that keeps the HUD, [] when the runner cannot. */
export const hudArgs = (hud: boolean): string[] => (hud ? ["--hud=on"] : []);

/** What a capture's label adds about the HUD: drawn as a person sees it, or exactly what is hidden. */
export const HUD_SHOWN = "HUD ON: as a person sees the game (score, clock, rings and arrows under players, hints, banners are drawn when the game has them)";
export const HUD_HIDDEN = "HUD OFF: this capture hides the pack's whole HUD layer (score, clock, rings and arrows under players, hints, banners, radar), so their absence here says nothing about the game: do not judge the HUD from it";
export const hudLabel = (label: string, hud: boolean): string => `${label}; ${hud ? HUD_SHOWN : HUD_HIDDEN}`;

/** The rubric items a look with strips adds: feel (seen in motion) and slop (any slop-list item seen fails). */
export function feelItems(): RubricItem[] {
  const ids = slopIds();
  return [
    { id: "feel", text: "In the MOTION STRIPS: an attack shows its anticipation (a wind-up), its impact (a hit-stop: the two bodies held for a few frames) and the victim's body reacting away from the blow (a flinch, a stumble, a fall); a miss reads as a miss; a dodge or block shows in the body. 0 when hits are a shove, a squash or nothing; 0 when no exchange is filmed at all." },
    { id: "slop", text: `1.0 when you see NO item of the slop list, 0.0 when you see ANY (name its id and the image in \`notes\`). The slop list: ${ids.join(", ") || "one_attack_button, recoloured_rivals, borrowed_clips, hit_without_reaction, camera_behind_scenery, hud_only_twist, skill_removing_autoaim, every_hit_floors, fighters_overlap, placeholder_in_clip_moment"}. Strong signs: every fighter has the same body in another colour; a figure plays a clip that is not its action; a wall or pillar hides the fighters; two bodies merge into one blob on a SIDE view. On an over-the-shoulder view a body covering the other is \`camera_hides_exchange\` (check the side strip of the same moment before you call \`fighters_overlap\`).` },
  ];
}

export interface Film {
  captures: string[];
  labels: string[];
  strips: Strip[];
  notes: string[];
  /** H1: filmed with the HUD on (as a person sees it); the house strips are filmed the same way. */
  hud?: boolean;
}

const reportPath = (h: GateHost, stem: string): string => h.dir("reports", `${stem}-s${h.s.lastSeq + 1}.json`);

/** One capture run with one retry (the window can die in the graphics driver under GPU load), logged as `verify`. */
async function captureOnce(h: GateHost, args: string[], out: string, stem: string, after: string, notes: string[], what: string, packDir = h.dir("pack")): Promise<boolean> {
  let ok = false;
  for (let attempt = 1; attempt <= 2 && !ok; attempt++) {
    fs.mkdirSync(path.dirname(out), { recursive: true });
    fs.rmSync(out, { force: true });
    const vr = await h.o.verifier.run({ verb: "capture", args: [...args, `--out=${toPosix(out)}`], packDir, reportFile: reportPath(h, stem) });
    ok = vr.ok && fs.existsSync(out);
    h.append({ type: "verify", round: 1, level: vr.level, verb: vr.verb, ok, report: h.rel(vr.reportFile), ...(vr.exitCode !== undefined ? { exitCode: vr.exitCode } : {}), after });
    if (!ok) notes.push(`${what}, attempt ${attempt} of 2, failed: ${clip(vr.summary, 160)}`);
  }
  return ok;
}

/**
 * N4 loop round 2: the house game's own exchange as a motion strip, filmed once per job beside the build's strips (a
 * drill bot of ref/packs/<pack> finds the contact frame, then one capture with --strip from 15 frames before it). The
 * strips are kept in the house baseline; [] when the pack, the bot or the capture failed (said in `notes`).
 */
export async function houseStrips(h: GateHost, base: HouseBaseline, template: string, after: string, notes: string[], buildKinds: string[] = [], hud = false): Promise<{ capture: string; label: string }[]> {
  if (base.strips !== undefined) return base.strips;
  const s = HOUSE_BOTS[template]?.strip;
  const packDir = h.dir("ref", "packs", base.pack);
  let strips: { capture: string; label: string }[] = [];
  if (s !== undefined && fs.existsSync(packDir)) {
    const vr = await h.verifyLogged({ verb: "bot", args: [`--test=${s.test}`, ...s.args] }, packDir, `house-${base.pack}-drill`, { round: 1 });
    // D3 of 22 Nov: a kind this build's bots also reported is filmed first (poked for a build's poke_free), so the revise pair compares like with like.
    // H1e: the house game's moments this game's design has come first (a basketball game is shown a poke, not a one-timer)
    const words = gameWords(h.s.brief);
    const mine = (s.moments ?? []).filter((k) => gameHasVerb(words, k));
    const moments = [...mine, ...(s.moments ?? []).filter((k) => !mine.includes(k))];
    const order = [...moments.filter((k) => buildKinds.some((b) => sameKind(k, b))), ...moments.filter((k) => !buildKinds.some((b) => sameKind(k, b)))];
    const cm = contactMoment(vr.report, order);
    const f = cm?.frame;
    if (f !== undefined) {
      // Round 9: the house strip is a CONTACT strip too (2 frames apart from 10 before), so the bar and the build compare like with like.
      const from = Math.max(1, f - CONTACT_STRIP.before);
      const st = CONTACT_STRIP.step;
      const out = h.dir("reports", `house-${base.pack}`, `strip-${s.cam}-f${from}.png`);
      const res = `--res=${h.o.captureRes ?? "1280x720"}`;
      if (await captureOnce(h, [`--cam=${s.cam}`, `--frame=${from}`, `--strip=${STRIP.count}x${st}`, res, `--test=${s.test}`, ...hudArgs(hud)], out, `house-${base.pack}-strip`, after, notes, `house strip ${s.cam} from frame ${from}`, packDir)) {
        // D3 of 22 Nov: the strip keeps its contact kind (the revise pair matches the build's strip to it); a fallback frame has none.
        strips = [{ capture: h.rel(out), label: hudLabel(`HOUSE GAME engine/packs/${base.pack} (a floor, not the bar, not this build): CONTACT MOTION STRIP (4 columns x 3 rows, frames ${from}, ${from + st}, ... ${from + st * (STRIP.count - 1)}, ${st} frames apart; the contact at frame ${f}${cm?.kind !== undefined ? `, ${cm.kind}` : ""}), ${s.test} on camera ${s.cam}: ${s.label}`, hud), ...(cm?.kind !== undefined ? { kind: cm.kind } : {}) }];
      }
    } else notes.push(`house strip: ${s.test} on ref/packs/${base.pack} gave no contact frame (${clip(vr.summary, 160)})`);
  }
  const kept = { ...base, strips };
  saveBaseline(h, kept);
  return strips;
}

/** The stills of every shot and camera (JOB.md second round), and with `withStrips` one strip per filmed point. */
export async function filmLook(h: GateHost, m: Milestone, shots: Shot[], cameras: string[], after: string, withStrips: boolean, hud = false): Promise<Film> {
  const film: Film = { captures: [], labels: [], strips: [], notes: [], hud };
  const res = `--res=${h.o.captureRes ?? "1280x720"}`;
  for (const [si, shot] of shots.entries()) for (const cam of cameras) {
    const bot = shot.bot !== undefined ? [`--test=${shot.bot}`] : [];
    for (const frame of shot.frames) {
      const out = h.dir("captures", si === 0 ? `${m}-${cam}-f${frame}.png` : `${m}-${cam}-${path.basename(shot.bot ?? "nobot", ".gd")}-f${frame}.png`);
      if (await captureOnce(h, [`--cam=${cam}`, `--frame=${frame}`, res, ...bot, ...hudArgs(hud)], out, `milestone-${m}-capture-${cam}-f${frame}`, after, film.notes, `capture ${cam} frame ${frame}`)) {
        film.captures.push(h.rel(out));
        film.labels.push(hudLabel(shotLabel(cam, frame, shot), hud));
      }
      if (!withStrips) continue;
      const contact = shot.moments?.includes(frame) === true; // round 9: a contact moment gets a dense strip
      const from = contact ? Math.max(1, frame - CONTACT_STRIP.before) : stripFrom(frame);
      const step = contact ? CONTACT_STRIP.step : STRIP.step;
      const strip = h.dir("captures", stripFile(m, cam, shot, from));
      if (await captureOnce(h, [`--cam=${cam}`, `--frame=${from}`, `--strip=${STRIP.count}x${step}`, res, ...bot, ...hudArgs(hud)], strip, `milestone-${m}-strip-${cam}-f${from}`, after, film.notes, `strip ${cam} from frame ${from}`)) {
        film.strips.push({ capture: h.rel(strip), label: hudLabel(stripLabel(cam, from, shot, step), hud) });
      }
    }
  }
  if (cameras.length === 0) film.notes.push("the pack declares no camera, so there is nothing to capture");
  return film;
}

/** What a look's critic said, as the loop and a revise round's feedback read it. */
export interface Verdict {
  ok: boolean;
  scores: Record<string, number>;
  notes: string[];
  package?: string;
  report: string;
  /** N4 of 22 Nov: who judged: the critic (absent), the tofu stage alone, or both. */
  by?: "tofu stage" | "critic (V5) and tofu stage" | "core check" | "critic (V5) and core check";
}

const scoresText = (v: Pick<Verdict, "scores">): string => Object.entries(v.scores).map(([k, x]) => `${k} ${x}`).join(", ");

/** The critic on a look: stills and strips together, the strips labelled as such. Undefined when it gave no usable answer or did not run. */
export async function judge(h: GateHost, m: Milestone, film: Film, shots: Shot[], lastPackage: string, round: number, house?: { line: string; pack: string; strips?: { capture: string; label: string }[] }, claims?: string): Promise<{ verdict?: Verdict; line: string }> {
  if (film.captures.length + film.strips.length === 0 || h.o.critic === false) return { line: "critic not run" };
  const model = h.o.criticModel ?? h.o.model;
  const kill = killItem(h.s.brief); // N2 of 23 Nov: the design's KILL IF lines (docs/design/METHOD.md section 11)
  const rubric = [...criticRubric(h.s, lastPackage), ...(film.strips.length > 0 ? feelItems() : []), ...(house !== undefined ? [houseItem(house.pack, houseForeign(h, house.pack))] : []), ...(kill !== undefined ? [kill] : [])];
  // L1b: the strips of the named clip moments first, then the stills, then the other strips.
  const clipFirst = [...film.strips.filter((x) => x.label.startsWith("CLIP MOMENT")), ...film.captures.map((c, i) => ({ capture: c, label: film.labels[i] ?? "" })), ...film.strips.filter((x) => !x.label.startsWith("CLIP MOMENT"))];
  // N4 loop round 2: the house game's strip last, labelled as the bar.
  const all = [...clipFirst, ...(house?.strips ?? []).filter((x) => fs.existsSync(h.dir(x.capture)))];
  const images = all.map((x) => x.capture);
  const labels = all.map((x) => x.label);
  const res = await critic(h.o.builder, images.map((c) => h.dir(c)), rubric, {
    ...(model ? { model } : {}),
    context: [`Game: ${h.s.title ?? ""} (${h.s.sentence ?? ""})`, `Mood asked for: ${h.s.brief?.mood ?? "(none)"}`, methodBlock(h.s.brief) !== "" ? `The design's method lines (what the player should feel, and what would kill the game):\n${methodBlock(h.s.brief)}` : "", h.s.brief?.design ? `The design's clip moments: ${h.s.brief.design.clips.map((c) => `${c.id}: ${c.moment}`).join("; ")}` : "", `Bots playing while the frames were taken: ${shots.map((x) => (x.bot ? `${x.bot}${x.package ? ` (package ${x.package})` : ""}` : "none")).join("; ")}. Each capture above names its bot and frame.`, claims !== undefined ? claims : "", barContext(h.s.brief?.concept?.template), house !== undefined ? `The house game of this game's template, engine/packs/${house.pack}, is a floor, not the bar: a working base the owner called slop and no person has accepted (README and clips in the engine). The bot figures, this build against it: ${house.line}` : ""].filter(Boolean).join("\n"),
    packages: packageLinesOf(h.s, h.s.plan.map((p) => p.id)),
    labels,
  });
  h.logGenerateCalls(res.calls, model);
  const file = reportPath(h, `critic-${m}`);
  fs.mkdirSync(path.dirname(file), { recursive: true });
  const body = res.ok ? { ok: res.value.ok, scores: res.value.scores, notes: res.value.notes, ...(res.value.package !== undefined ? { package: res.value.package } : {}) } : { error: res.reason };
  fs.writeFileSync(file, JSON.stringify({ schema: "tl.foreman.critique/1", milestone: m, ...(round > 0 ? { round } : {}), captures: film.captures, shots: film.captures.map((c, i) => ({ capture: c, label: film.labels[i] ?? "" })), strips: film.strips, rubric, ...body }, null, 1) + "\n");
  if (!res.ok) return { line: `critic (V5) gave no usable answer: ${clip(res.reason, 200)} [${h.rel(file)}]` };
  const verdict: Verdict = { ok: res.value.ok, scores: res.value.scores, notes: res.value.notes, ...(res.value.package !== undefined ? { package: res.value.package } : {}), report: h.rel(file) };
  return { verdict, line: verdictText(verdict) };
}

/**
 * N4 loop round 12: the tofu bot's figures are its own claims. The critic gets them and checks them against the strips
 * (proof -3: the bot reported idle_max_f 37 while two of its strips held both fighters still for 55+ frames).
 */
export function claimsLine(built: TofuResult | undefined, film?: FilmCheck): string | undefined {
  const rows = (built?.rows ?? []).filter((r) => r.value !== undefined && r.id !== "moments_on_film");
  const measured = filmCheckText(film); // D3 of 22 Nov: the claims and what the Foreman measured from the frames
  if (rows.length === 0) return measured;
  return `${measured !== undefined ? `${measured}\n` : ""}The tofu bot's own figures (claims, counted by the build's bot, not by the Foreman): ${rows.map((r) => `${r.id} ${r.value}`).join(", ")}. Where a strip contradicts one (a fighter standing still for more than 120 frames against idle_max_f, no parry or roll in any strip against verbs_used, no held tiles on a contact strip against the hit-stop), write a note that starts "claim contradicted:" with the figure and the image.`;
}

/** N4 loop round 2: the rubric item of a job whose template has a house game: this build against the house game. */
export function houseItem(pack: string, foreign: string[] = []): RubricItem {
  // H1e (lanes G2, G4): the house game's verbs and rows this game's design does not have are never missing
  const not = foreign.length > 0 ? ` This game's design does not have the house game's ${foreign.join(", ")}: never call them missing and never ask for them; set beside it only what the two games share (${foreign.some((w) => BODY.includes(w)) ? "" : "the bodies, "}how they take contact, the team's play).${foreign.some((w) => BODY.includes(w)) ? " This game has no bodies that stumble or fall (H1g): judge its own contact, the bumps, the pushes and the ball, never a body's stand, brace or stumble." : ""}` : "";
  return { id: "house_game", text: `Against the house game engine/packs/${pack} (a working base of this game's template on this engine, a FLOOR and not the bar: the owner called it slop; its figures in the context above): do the frames show its exchange as clearly (wind-up, hit-stop on both, each body's own reaction, the guard and the roll in the body)? When an image is labelled HOUSE GAME, set this build's strips beside it: the same moment of the exchange, is it as readable in the bodies? Name in \`notes\` each place this build falls short of the house game, by what you see and by the SHORT figures. 1.0 at least as readable as the house game, 0.5 its core with gaps, 0 none of it. Reaching the house game is not reaching the bar: a build that copies one of the teardown's "do not copy" lines (context) is named for it.${not}` };
}

/** N2 round 5: the template's quality bar for the critic: the teardown's "do not copy" lines ("" without a bar). */
export function barContext(template: { id: string } | undefined): string {
  const b = templateOf(template?.id)?.bar;
  return b === undefined ? "" : `The bar is the reference games, not the house game (${b.teardown}). What the house game does that a build must NOT copy (name any you see, with the image): ${b.dont.join("; ")}.`;
}

export const verdictText = (v: Verdict): string => `${v.by ?? "critic (V5)"} ${v.ok ? "ok" : "NOT ok"}: ${scoresText(v)}; ${clip(v.notes.join(" | "), 500)} [${v.report}]`;

// ---------- N4 of 22 Nov: the tofu stage (tofu.ts) judged with the look ----------

/** The tofu check of milestone `m`: undefined unless the plan has a TOFU CHECK line and `m` is its package's milestone. */
export function tofuLook(h: GateHost, m: Milestone, film?: FilmCheck): (TofuResult & { package: string; report: string }) | undefined {
  const t = tofuOf(h.s.plan);
  if (t === undefined || h.s.plan.find((p) => p.id === t.package)?.milestone !== m) return undefined;
  const read = readTofuMetrics(h.dir(), h.events, t.test);
  const res = judgeTofu(read.metrics, withLifts(h.s, h.events, tofuMetricsFor(h.s.brief?.concept?.template, h.s.brief?.design?.verbs.length, courtOf(h.s.brief))).rows, t.test, read.hand, read.from, film); // H1h: lifted bounds are not judged
  const file = reportPath(h, `tofu-${m}`);
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, JSON.stringify({ schema: "tl.foreman.tofu/1", milestone: m, test: t.test, package: t.package, ...res, ...(film !== undefined && film.measured + film.unmeasured.length > 0 ? { film: filmReport(film) } : {}) }, null, 1) + "\n");
  return { ...res, package: t.package, report: h.rel(file) };
}

/**
 * The critic's verdict with the tofu stage's: a failed tofu check makes the look NOT ok and names the tofu package
 * (the core verb is its), whatever the critic said; a passed one adds the score `tofu` 1. The merged verdict is written
 * over the tofu report (shape of a critique), so a revise round sent from the log reads it back (verdictOfLook).
 */
export function withTofu(h: GateHost, judged: { verdict?: Verdict; line: string }, tofu: (TofuResult & { package: string; report: string }) | undefined): { verdict?: Verdict; line: string } {
  return withStage(h, judged, tofu, "tofu");
}

/**
 * The critic's verdict with a measured stage's: the tofu stage (`tofu`) or, E3 of 24 Nov, a core game's measured check
 * (`core`, coregate.ts). A failed stage makes the look NOT ok and names the stage's package; a passed one adds score 1.
 */
export function withStage(h: GateHost, judged: { verdict?: Verdict; line: string }, tofu: (TofuResult & { package: string; report: string }) | undefined, stage: "tofu" | "core"): { verdict?: Verdict; line: string } {
  if (tofu === undefined) return judged;
  const v = judged.verdict;
  if (tofu.ok && v === undefined) return { line: `${judged.line}; ${tofu.line} [${tofu.report}]` };
  const by: Verdict["by"] = stage === "tofu" ? (v ? "critic (V5) and tofu stage" : "tofu stage") : v ? "critic (V5) and core check" : "core check";
  const merged: Verdict = tofu.ok
    ? { ...(v as Verdict), scores: { ...(v as Verdict).scores, [stage]: 1 }, notes: [...(v as Verdict).notes, tofu.line] }
    : { ok: false, scores: { ...(v?.scores ?? {}), [stage]: 0 }, notes: [tofu.line, ...(v?.notes ?? [])], package: tofu.package, report: tofu.report, by };
  if (!tofu.ok) {
    const file = h.dir(...tofu.report.split("/"));
    const body = JSON.parse(fs.readFileSync(file, "utf8")) as Record<string, unknown>;
    fs.writeFileSync(file, JSON.stringify({ ...body, ok: false, scores: merged.scores, notes: merged.notes, package: merged.package, by: merged.by, ...(v ? { critic: v.report } : {}) }, null, 1) + "\n");
  }
  return { verdict: merged, line: verdictText(merged) };
}

/** What a report keeps of a film check (no line: the rows and findings say it). */
const filmReport = (c: FilmCheck): Omit<FilmCheck, "line"> => ({ measured: c.measured, unmeasured: c.unmeasured, findings: c.findings, strips: c.strips });

/**
 * D3 of 22 Nov: the look's strips measured against the claims of the bots that played them (filmcheck.ts), each bot's
 * newest finished report. Written to reports/film-<m>-s<seq>.json when a strip was there to measure.
 */
export function filmCheckOf(h: GateHost, m: Milestone, film: Film): FilmCheck | undefined {
  if (film.strips.length === 0) return undefined;
  const check = crossCheckFilm(film.strips, (bot) => botClaims(h.dir(), h.events, bot), (c) => h.dir(...c.split("/")));
  const file = reportPath(h, `film-${m}`);
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, JSON.stringify({ schema: "tl.foreman.film/1", milestone: m, ok: check.findings.length === 0, ...filmReport(check) }, null, 1) + "\n");
  return check;
}

// ---------- snapshots ----------

/** What a snapshot keeps besides pack/: the look that was judged before the round (its files copied), and its verdict. */
interface Snapshot {
  atSeq: number;
  round: number;
  captures: string[];
  strips: Strip[];
  verdict?: Verdict;
  summary: string;
}

const snapDir = (m: string, round: number): string => `reports/quality-${m}-r${round}`;

/** Before revise round `round`: pack/ and the judged look's images into reports/quality-<m>-r<round>/. */
export function snapshot(h: GateHost, m: Milestone, round: number, look: { captures: string[]; strips: Strip[]; verdict?: Verdict; summary: string }): void {
  const rel = snapDir(m, round);
  const dir = h.dir(...rel.split("/"));
  fs.rmSync(dir, { recursive: true, force: true });
  copyDir(h.dir("pack"), path.join(dir, "pack"));
  const copy = (c: string): string => {
    const to = `${rel}/captures/${path.basename(c)}`;
    if (fs.existsSync(h.dir(c))) {
      fs.mkdirSync(path.join(dir, "captures"), { recursive: true });
      fs.copyFileSync(h.dir(c), h.dir(...to.split("/")));
    }
    return to;
  };
  const snap: Snapshot = { atSeq: h.s.lastSeq, round, captures: look.captures.map(copy), strips: look.strips.map((x) => ({ capture: copy(x.capture), label: x.label })), ...(look.verdict ? { verdict: look.verdict } : {}), summary: look.summary };
  fs.writeFileSync(path.join(dir, "look.json"), JSON.stringify(snap, null, 1) + "\n");
}

function readSnapshot(h: GateHost, m: string, round: number): Snapshot | undefined {
  try {
    return JSON.parse(fs.readFileSync(h.dir(...snapDir(m, round).split("/"), "look.json"), "utf8")) as Snapshot;
  } catch {
    return undefined;
  }
}

/** kept = "previous": pack/ back to the snapshot, and `merge` events so that each package's merged files agree again. */
function restore(h: GateHost, m: string, snap: Snapshot): void {
  const src = h.dir(...snapDir(m, snap.round).split("/"), "pack");
  const packDir = h.dir("pack");
  const tmp = h.dir(`.pack-quality-${process.pid}`);
  fs.rmSync(tmp, { recursive: true, force: true });
  copyDir(src, tmp);
  fs.rmSync(packDir, { recursive: true, force: true, maxRetries: 5, retryDelay: 100 });
  fs.renameSync(tmp, packDir);
  const then = foldEvents(h.s.job, h.events.filter((e) => e.seq <= snap.atSeq));
  for (const id of h.s.order) {
    const now = h.s.packages[id]?.mergedFiles ?? [];
    const was = then.packages[id]?.mergedFiles ?? [];
    const removed = now.filter((f) => !was.includes(f));
    const files = was.filter((f) => !now.includes(f));
    if (removed.length > 0 || files.length > 0) h.append({ type: "merge", package: id, files, ...(removed.length > 0 ? { removed } : {}) });
  }
}

// ---------- the pairwise compare ----------

const compareSchema = { type: "object", additionalProperties: false, required: ["keep", "why"], properties: { keep: { enum: ["new", "previous"] }, why: { type: "string", minLength: 1 } } };

/** The critic compares the previous version's images with the new ones and keeps the better. Falls back on the scores. */
export async function compareLooks(h: GateHost, prev: Snapshot, film: Film, fresh: Verdict | undefined): Promise<{ kept: "new" | "previous"; why: string }> {
  const side = (stills: string[], strips: Strip[]): string[] => (strips.length > 0 ? strips.map((x) => x.capture) : stills).slice(0, 8);
  const a = side(prev.captures, prev.strips).filter((c) => fs.existsSync(h.dir(c)));
  const b = side(film.captures, film.strips);
  const mean = (v: Verdict | undefined): number => (v ? Object.values(v.scores).reduce((x, y) => x + y, 0) / Math.max(1, Object.values(v.scores).length) : -1);
  const byScores = (why: string): { kept: "new" | "previous"; why: string } => (mean(prev.verdict) > mean(fresh) && fresh !== undefined ? { kept: "previous", why: `${why}; by the critic's mean score (${mean(prev.verdict).toFixed(2)} before, ${mean(fresh).toFixed(2)} now)` } : { kept: "new", why: `${why}; the new version is kept${fresh ? ` (mean score ${mean(fresh).toFixed(2)}, before ${mean(prev.verdict).toFixed(2)})` : ""}` });
  if (a.length === 0 || b.length === 0 || h.o.critic === false) return byScores("no images to compare");
  const model = h.o.criticModel ?? h.o.model;
  const tpl = fs.readFileSync(path.join(PKG_ROOT, "prompts", "critic-compare.md"), "utf8");
  const list = (xs: string[], from: number, tag: string): string => xs.map((c, i) => `- image ${from + i} of ${a.length + b.length}: ${tag}, ${path.basename(c)}`).join("\n");
  const res = await generate<{ keep: "new" | "previous"; why: string }>(
    h.o.builder,
    "critic_compare",
    tpl,
    {
      game: `${h.s.title ?? ""} (${h.s.sentence ?? ""})`,
      method: methodBlock(h.s.brief) || "(the design carries no method lines)",
      previous: list(a, 1, "PREVIOUS version"),
      fresh: list(b, a.length + 1, "NEW version"),
      before: prev.verdict ? `${scoresText(prev.verdict)}; ${clip(prev.verdict.notes.join(" | "), 400)}` : "(no verdict)",
      now: fresh ? `${scoresText(fresh)}; ${clip(fresh.notes.join(" | "), 400)}` : "(no verdict)",
    },
    compareSchema,
    () => [],
    { ...(model ? { model } : {}) },
    "generate",
    "",
    [...a, ...b].map((c) => h.dir(c)),
  );
  h.logGenerateCalls(res.calls, model);
  return res.ok ? { kept: res.value.keep, why: clip(res.value.why, 300) } : byScores(`the compare gave no usable answer (${clip(res.reason, 120)})`);
}

// ---------- the loop ----------

/** Sends a NOT ok version back for revise round `round` (snapshot first): the named package, or the milestone's own. */
export function sendBack(h: GateHost, m: Milestone, members: string[], lastPackage: string, round: number, look: { captures: string[]; strips: Strip[]; verdict?: Verdict; summary: string }, note?: string, pair?: string): void {
  const v = look.verdict;
  // E3f: on a core game, what only the base can change goes to the person at once (no revise round; a retry still runs one).
  if (note === undefined && v !== undefined && baseOwned(h, v.package)) return holdForBase(h, m, lastPackage, round, look, v, v.package as string);
  // H1c (lane G1's Arsenal job: "the bubble shows no bounce" made the builder draw the rival 2.3 m from where the core had
  // him, two rounds, the second thrown away): a reason that asks the core's bodies for a reaction goes to the person too.
  const motion = note === undefined && v !== undefined ? coreMotionAsk(h, v) : undefined;
  if (motion !== undefined && v !== undefined) return holdForBase(h, m, lastPackage, round, look, v, "the core", motion);
  snapshot(h, m, round, look);
  const owner = note !== undefined ? ` The owner held the job and asks: ${note}` : "";
  // D3 of 22 Nov: the pair (revisepair.ts) goes first, so the 1500-character clip of the detail never cuts it.
  const truth = jobCore(h) !== undefined ? ` ${DRAW_TRUE}` : "";
  const detail = `${criticReopenFor(m, round, Math.max(QUALITY_ROUNDS, round))}: ${pair !== undefined ? `${pair} ` : ""}${v ? `${scoresText(v)}. Critic's notes: ${v.notes.join(" | ")} [${v.report}]` : clip(look.summary, 600)}.${owner}${truth} The version before this round is kept in ${snapDir(m, round)}/; after the round the critic compares both and keeps the better.`;
  const named = v?.package;
  const target = named !== undefined ? h.s.packages[named] : undefined;
  // E5 (25 Nov, the first real core job): the base package is a copy of the engine's base, never a builder's work. A
  // revise round on it re-copied the same files (and failed lint, the later packages' tests missing), twice, then held
  // the job: the critic's notes go to the milestone's built packages instead.
  const base = (id: string): boolean => h.s.plan.find((p) => p.id === id)?.kind === "base";
  if (named !== undefined && !base(named) && target && target.state === "promoted" && (target.mergedFiles ?? []).length > 0) {
    h.reopen(named, `${criticReopenFor(m, round, Math.max(QUALITY_ROUNDS, round))}: the critic names this package as the cause of what it sees${members.includes(named) ? "" : ` (the milestone's own package(s): ${members.join(", ")})`}`, detail);
    return;
  }
  const why = named === undefined ? "the critic named no package" : !target ? `the critic named "${clip(named, 60)}", which is not a package of this plan` : base(named) ? `the critic named ${named}, the engine's base (copied, no builder revises it)` : `the critic named ${named}, which is not merged (state ${target.state})`;
  const built = members.filter((id) => !base(id));
  const to = built.length > 0 ? built : members;
  h.append({ type: "note", package: lastPackage, round: h.pkg(lastPackage).round, text: `${FOREMAN_NOTE}${why}; revise round ${round} goes to the package(s) of the ${m} milestone: ${to.join(", ")}` });
  for (const id of to) h.append({ type: "package_state", package: id, state: "queued", round: h.pkg(id).round + 1, detail: clip(detail, 1500) });
}

// ---------- E3f of 25 Nov: reasons only the base can answer go to the person, not to revise rounds ----------

/** The start of the Foreman's note (after FOREMAN_NOTE) when a look is held at once because the critic names the base. */
export const BASE_OWNED = "the critic names the base";

/**
 * On a game on a core, the critic's NOT ok names something no package of the job can change: the base package (the
 * engine's copy: the core's skating, contact and bots, the base's camera), or the core or the engine by name. Lane E5's
 * job 1 spent about 89 of 140 min on revise rounds the cartridge, the skin and the trials could not answer.
 */
export function baseOwned(h: Pick<GateHost, "s">, named: string | undefined): boolean {
  const core = jobCore(h);
  if (core === undefined || named === undefined) return false;
  const spec = h.s.plan.find((p) => p.id === named);
  if (spec !== undefined) return spec.kind === "base";
  return named === core.core || named === core.base || /\b(base|core|engine|camera)\b/i.test(named);
}

/**
 * The look is the person's now: a `milestone` event at the hold's round (the job pauses for the quality card), its text
 * first saying what the base does and that no revise round was spent, then the critic's words. `foreman quality retry`
 * still sends one round with the person's note (sendBack with a note never comes here).
 */
function holdForBase(h: GateHost, m: Milestone, lastPackage: string, round: number, look: { captures: string[]; strips: Strip[] }, v: Verdict, named: string, motion?: string): void {
  const core = jobCore(h);
  const what = motion !== undefined
    ? `the critic asks the bodies for a reaction the ${core?.core ?? "?"} core does not do (${motion}); a package could only draw a body away from where the core has it, and the player would then be hit by a body he does not see, so no revise round was spent. Play it and keep it, or ask for the reaction in words (it is a change of the core)`
    : `this is how the base plays (${named}: engine/templates/${core?.base ?? "?"}/ on the ${core?.core ?? "?"} core: the skating, the contact, the bots, the base's camera); no package of this game can change it, so no revise round was spent. Play it and keep it, or say what to change`;
  h.append({ type: "note", package: lastPackage, round: h.pkg(lastPackage).round, text: clip(`${FOREMAN_NOTE}${motion !== undefined ? CORE_MOTION : `${BASE_OWNED} (${named})`} on the ${m} look: ${what}. [${v.report}]`, 1000) });
  h.append({ type: "milestone", milestone: m, captures: look.captures, ...(look.strips.length > 0 ? { strips: look.strips } : {}), round: Math.max(QUALITY_ROUNDS, round), summary: clip(`critic (V5) NOT ok: ${what}. The critic saw: ${clip(v.notes.join(" | "), 700)}; ${scoresText(v)} [${v.report}]`, 1500) });
}

/** H1c: the start of the Foreman's note (after FOREMAN_NOTE) when a look is held because the critic asks the core's bodies for a reaction. */
export const CORE_MOTION = "the critic asks the core for a body reaction";

/** H1c: the line every revise round on a core game carries: a picture never contradicts the simulation. */
export const DRAW_TRUE = "On this core the core decides where every body, the puck and each stick are and when they touch: draw them where the core has them, never away from it (no drawn bounce, recoil or stand-off the core does not do). A reaction the core does not do is the person's call, not a drawing: say so under DEVIATIONS.";

/**
 * H1c: the body reaction a critic's WORST reason (its first note, the one a revise round answers first) asks of a game on
 * a core, when it asks one: a bounce, a recoil, a knock-back, a body thrown or staggering. Those are the core's
 * contact; on a core game no package changes them except by drawing a body where the core does not have it. Undefined
 * off a core, or when the worst reason is a picture a package can draw true (a flash, a ring, a colour, a camera).
 */
export function coreMotionAsk(h: Pick<GateHost, "s">, v: Pick<Verdict, "notes">): string | undefined {
  if (jobCore(h) === undefined) return undefined;
  const worst = v.notes[0] ?? "";
  const hits = [...worst.matchAll(/\b(bounc\w*|recoil\w*|knock(?:ed|s)?[- ]?back|thrown? back|throws? (?:him|her|them|the \w+) back|stagger\w*|stumbl\w*|push(?:ed|es)? (?:back|away|off))\b/gi)].map((x) => (x[1] as string).toLowerCase());
  return hits.length > 0 ? [...new Set(hits)].join(", ") : undefined;
}

/** The verdict a look's summary points at (its critic report), for a revise round sent from the log (resume, retry). */
export function verdictOfLook(h: GateHost, look: Look): Verdict | undefined {
  const rel = /\[(reports\/(?:tofu|critic|core)-[^\]]+\.json)\]/.exec(look.summary)?.[1];
  if (rel === undefined) return undefined;
  try {
    const r = JSON.parse(fs.readFileSync(h.dir(...rel.split("/")), "utf8")) as Partial<CritiqueResult> & { by?: Verdict["by"] };
    return r.scores ? { ok: r.ok === true, scores: r.scores, notes: r.notes ?? [], ...(r.package !== undefined ? { package: r.package } : {}), report: rel, ...(r.by !== undefined ? { by: r.by } : {}) } : undefined;
  } catch {
    return undefined;
  }
}

/**
 * A look was filmed (round 0 = the first): judge it, and for a revise round compare with the snapshot and keep the
 * better. Writes the `milestone` event (not for a NOT ok first look: the milestone is not reached), or sends the
 * version back. A look still NOT ok at the last round is left for the hold (the state reads it from the event).
 */
/**
 * H1f: a critic that names a person's note on a kept card as not kept ("person's note not kept: ...") cannot pass the
 * look, whatever its scores: the verdict is NOT ok, and the note leads, so the milestone and the revise round say it first.
 */
export function notesKept(v: Verdict | undefined): Verdict | undefined {
  if (v === undefined) return v;
  const missed = v.notes.filter((n) => n.trim().toLowerCase().startsWith(NOTE_NOT_KEPT));
  if (missed.length === 0) return v;
  return { ...v, ok: false, notes: [...missed, ...v.notes.filter((n) => !missed.includes(n))] };
}

export async function decideLook(h: GateHost, m: Milestone, members: string[], lastPackage: string, film: Film, shots: Shot[], round: number, notes: string[]): Promise<void> {
  // N4 loop round 2: a job whose template has a house game is set beside it (bot figures by the tofu names, the critic's rubric).
  const template = h.s.brief?.concept?.template;
  const base = h.s.brief?.design !== undefined ? await houseBaseline(h, template) : undefined;
  // D3 of 22 Nov: the bots' claims against motion measured from the strips; a contradicted claim fails its tofu row and the house compare.
  const filmed = filmCheckOf(h, m, film);
  if (filmed !== undefined) notes.push(filmed.line);
  const tofu = tofuLook(h, m, filmed);
  const t = tofuOf(h.s.plan);
  const built = tofu ?? (t !== undefined ? (() => { const r = readTofuMetrics(h.dir(), h.events, t.test); return judgeTofu(r.metrics, withLifts(h.s, h.events, tofuMetricsFor(template, h.s.brief?.design?.verbs.length, courtOf(h.s.brief))).rows, t.test, r.hand, r.from, filmed); })() : undefined);
  const vsHouse = base !== undefined ? houseCompare(built, base, tofuMetricsFor(template, undefined, courtOf(h.s.brief))) : undefined;
  if (vsHouse !== undefined) notes.push(vsHouse.line);
  const strips = base !== undefined && template !== undefined && film.strips.length > 0 ? await houseStrips(h, base, template.id, lastPackage, notes, [...new Set(shots.flatMap((x) => (x.bot !== undefined ? botMoments(h.dir(), h.events, x.bot).map((mm) => mm.kind) : [])))], film.hud === true) : [];
  // E3 of 24 Nov: a game on a core: the measured check (coregate.ts) instead of the tofu rows; not measured is said, never a pass.
  const core = await coreLook(h, m);
  if (core !== undefined && !core.measured) notes.push(core.line);
  const claims = [claimsLine(built, filmed), core !== undefined ? `The core's measured check of this build's cartridge (lane E2's lab, not the build's own claim): ${core.line}` : undefined].filter((x): x is string => x !== undefined).join("\n") || undefined;
  const judged = withStage(h, withTofu(h, await judge(h, m, film, shots, lastPackage, round, vsHouse !== undefined && base !== undefined ? { line: vsHouse.line, pack: base.pack, strips } : undefined, claims), tofu), core?.measured === true ? core : undefined, "core");
  // H1g: a steady-camera note on a kept card, checked against the runner's camera figures (camnote.ts)
  const camMissed = cameraNotesMissed(h);
  if (camMissed.length > 0 && judged.verdict === undefined) notes.push(...camMissed);
  const fresh = notesKept(judged.verdict !== undefined && camMissed.length > 0 ? { ...judged.verdict, notes: [...camMissed, ...judged.verdict.notes] } : judged.verdict); // H1f: a person's note on a kept card the frames do not keep makes the look NOT ok
  const head = `all ${members.length} package(s) of this milestone are merged and verified: ${members.join(", ")}`;
  const counts = `${film.captures.length} capture(s)${film.strips.length > 0 ? `, ${film.strips.length} strip(s)` : ""}`;
  if (round === 0) {
    if (fresh && !fresh.ok) {
      sendBack(h, m, members, lastPackage, 1, { captures: film.captures, strips: film.strips, verdict: fresh, summary: verdictText(fresh) }, undefined, revisePair(h, m, 1, film.strips, base !== undefined ? { pack: base.pack, strips } : undefined, template?.id));
      return;
    }
    h.append({ type: "milestone", milestone: m, captures: film.captures, ...(film.strips.length > 0 ? { strips: film.strips } : {}), summary: clip([head, counts, judged.line, ...notes].join("; "), 1500) });
    return;
  }
  const prev = readSnapshot(h, m, round);
  const same = sayLookNotPlay(h, prev?.atSeq, round, prev?.verdict?.notes, lastPackage); // H1f: a revise round that changed the look, not the play
  if (same !== undefined) notes.push(same);
  // A new version the critic passes beats a version it sent back; otherwise the critic compares the two.
  // N4: a version that passes the tofu stage beats one that fails it, whatever the images say.
  const stagePick = (k: string): "new" | "previous" | undefined => (prev?.verdict?.scores[k] !== undefined && fresh?.scores[k] !== undefined && prev.verdict.scores[k] !== fresh.scores[k] ? ((fresh.scores[k] as number) > (prev.verdict.scores[k] as number) ? "new" : "previous") : undefined);
  const tofuPick: "new" | "previous" | undefined = stagePick("tofu") ?? stagePick("core"); // E3: or the core's measured check
  const cmp = fresh?.ok === true ? { kept: "new" as const, why: "the new version passes the critic" } : tofuPick !== undefined ? { kept: tofuPick, why: `the ${tofuPick} version passes the tofu stage and the other does not` } : prev ? await compareLooks(h, prev, film, fresh) : { kept: "new" as const, why: "no snapshot of the version before this round was found" };
  if (cmp.kept === "previous" && prev) restore(h, m, prev);
  const keptVerdict = cmp.kept === "previous" ? prev?.verdict : fresh;
  const keptFilm = cmp.kept === "previous" && prev ? { captures: prev.captures, strips: prev.strips } : { captures: film.captures, strips: film.strips };
  const loop = `revise round ${round} of ${Math.max(QUALITY_ROUNDS, round)}: kept ${cmp.kept} (${cmp.why})${cmp.kept === "previous" ? `; pack/ was put back to ${snapDir(m, round)}/pack` : ""}${fresh && cmp.kept === "previous" ? `; the new version was ${verdictText(fresh)}` : ""}`;
  const verdict = keptVerdict ? verdictText(keptVerdict) : judged.line;
  h.append({ type: "milestone", milestone: m, captures: keptFilm.captures, summary: clip([head, counts, verdict, loop, ...notes].join("; "), 1500), round, kept: cmp.kept, ...(keptFilm.strips.length > 0 ? { strips: keptFilm.strips } : {}) });
  if (!keptVerdict || keptVerdict.ok) return;
  if (round < QUALITY_ROUNDS) sendBack(h, m, members, lastPackage, round + 1, { captures: keptFilm.captures, strips: keptFilm.strips, verdict: keptVerdict, summary: verdict }, undefined, revisePair(h, m, round + 1, keptFilm.strips, base !== undefined ? { pack: base.pack, strips } : undefined, template?.id));
}

/**
 * H1e: what the house game has and this game's design does not (its strip's moment kinds and the words of its contact
 * rows), for the house_game rubric item. [] without a design or a template.
 */
export function houseForeign(h: Pick<GateHost, "s" | "dir">, pack: string): string[] {
  const words = gameWords(h.s.brief);
  const template = h.s.brief?.concept?.template?.id;
  if (words === undefined || template === undefined) return [];
  const kinds = (HOUSE_BOTS[template]?.strip?.moments ?? []).filter((k) => !gameHasVerb(words, k));
  const rows: string[] = [];
  for (const src of HOUSE_CONTACTS[template] ?? []) {
    try {
      const o = JSON.parse(fs.readFileSync(h.dir("ref", "packs", pack, ...src.file.split("/")), "utf8")) as Record<string, unknown>;
      rows.push(...numberLeaves(src.keys !== undefined ? Object.fromEntries(src.keys.filter((k) => k in o).map((k) => [k, o[k]])) : o).keys());
    } catch {
      /* no house copy: the moments alone */
    }
  }
  return [...new Set([...kinds, ...foreignWords(words, rows)])];
}
