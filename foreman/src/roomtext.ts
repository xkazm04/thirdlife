// The texts of the design room (JOB.md "Added 2026-11-21"): the handbook sections the prompts carry
// (docs/GAME-QUALITY.md), the design step's answer schema, and the concept and design doc as the review, the Planner and
// the builders read them. Pure apart from reading the handbook and the prompt schema; imported by designer.ts and room.ts.
import fs from "node:fs";
import path from "node:path";
import type { Brief, DesignDoc } from "./events.js";
import { PKG_ROOT, REPO_ROOT, stripBom } from "./paths.js";
import { conceptSchema, designProblems, designSchema, reviewScoresSchema, type Concept, type ConceptTemplate, type ReviewScore } from "./room_wire.js";
import { templateExcerpt, templateLines } from "./templates.js";

/** The handbook every room prompt cites. */
export const QUALITY_DOC = path.join(REPO_ROOT, "docs", "GAME-QUALITY.md");

/**
 * Sections of docs/GAME-QUALITY.md by number ("2" is "## 2. Feel numbers at 60 Hz"; "7:Builder" is the Builder rules
 * of section 7). A missing handbook gives a one-line note, not an error.
 */
export function qualityText(wanted: string[], file = QUALITY_DOC): string {
  if (!fs.existsSync(file)) return "(docs/GAME-QUALITY.md was not found: design against the checklist above)";
  const lines = stripBom(fs.readFileSync(file, "utf8")).split(/\r?\n/);
  const out: string[] = [];
  for (const w of wanted) {
    const [num, role] = w.split(":");
    const at = lines.findIndex((l) => l.startsWith(`## ${num}. `));
    if (at < 0) continue;
    let end = lines.findIndex((l, i) => i > at && /^## /.test(l));
    if (end < 0) end = lines.length;
    let body = lines.slice(at, end);
    if (role !== undefined) {
      const from = body.findIndex((l) => l.trim() === `${role}:`);
      if (from < 0) continue;
      const to = body.findIndex((l, i) => i > from && /^[A-Z][a-z]+:$/.test(l.trim()));
      body = [`${lines[at]} (${role})`, ...body.slice(from + 1, to < 0 ? body.length : to)];
    }
    out.push(body.join("\n").trim());
  }
  return out.join("\n\n");
}

/** N4 of 22 Nov: the plays-twice checklist of the handbook (section 10), one row per item: number, criterion, verify. */
export function checklistRows(file = QUALITY_DOC): { n: number; text: string; verify: string }[] {
  return qualityText(["10"], file)
    .split("\n")
    .map((l) => /^\| (\d+) \| (.+?) \| (.+?) \|/.exec(l))
    .filter((m): m is RegExpExecArray => m !== null)
    .map((m) => ({ n: Number(m[1]), text: m[2] as string, verify: (m[3] as string).replace(/\*/g, "") }));
}

/** The line every critic answer ends with (GAME-QUALITY.md section 7, rule 30). */
export const H_LINE = "[H] items not judged: a person must play it";
const H_FALLBACK = [2, 4, 13, 21, 26, 28, 30];
export const hItems = (): number[] => {
  const rows = checklistRows().filter((r) => r.verify.includes("[H]")).map((r) => r.n);
  return rows.length > 0 ? rows : H_FALLBACK;
};

/** The critic's notes with the [H] line last, exactly once, naming the [H] items (the model's own version replaced). */
export function withHLine(notes: string[]): string[] {
  return [...notes.filter((n) => !n.trim().startsWith("[H] items not judged")), `${H_LINE} (items ${hItems().join(", ")})`];
}

/** The critic prompt's checklist block: the [C] items frames can show, and the [H] items no capture can pass. */
export function criticChecklistText(): string {
  const rows = checklistRows();
  if (rows.length === 0) return `(docs/GAME-QUALITY.md has no checklist) End the notes with: ${H_LINE}`;
  const c = rows.filter((r) => r.verify.includes("[C]"));
  const h = rows.filter((r) => r.verify.includes("[H]"));
  return [
    "Judge these from the frames ([C]: a capture can show them); name each one you see failing, by number:",
    ...c.map((r) => `- ${r.n}. ${r.text}`),
    "Never judge these ([H]: only a person playing can); list their numbers in the last note:",
    ...h.map((r) => `- ${r.n}. ${r.text}`),
    `The last note is: ${H_LINE} (items ${h.map((r) => r.n).join(", ")})`,
  ].join("\n");
}

/** The slop ids of the handbook, in order (the lines "- **`<id>`** ..." of section 6). */
export function slopIds(file = QUALITY_DOC): string[] {
  return qualityText(["6"], file)
    .split("\n")
    .map((l) => /^- \*\*`([a-z_]+)`\*\*/.exec(l)?.[1])
    .filter((x): x is string => x !== undefined);
}

const prompt = (name: string): string => fs.readFileSync(path.join(PKG_ROOT, "prompts", name), "utf8");

/** The design step's answer schema: the v2 brief schema with `design` required. */
export function designAnswerSchema(): object {
  const s = JSON.parse(prompt("brief.schema.json")) as { properties: { brief: { required: string[]; properties: Record<string, object> } } };
  s.properties.brief.properties["design"] = designSchema;
  s.properties.brief.required.push("design");
  return s;
}

/** The concept step's answer: the wire's concept with `template` required (N4 of 22 Nov: one proven template per core loop). */
export const conceptAnswerSchema = { type: "object", additionalProperties: false, required: ["concept"], properties: { concept: { ...conceptSchema, required: ["template", ...(conceptSchema as { required: string[] }).required] } } };

/** The producer's answer: scores, the slop ids it found, a verdict and notes (design_reviewed is written from it). */
export const reviewAnswerSchema = {
  type: "object",
  additionalProperties: false,
  required: ["scores", "slop", "verdict", "notes"],
  properties: { scores: reviewScoresSchema, slop: { type: "array", items: { type: "string", pattern: "^[a-z][a-z0-9_]*$" } }, verdict: { enum: ["ok", "revise"] }, notes: { type: "string", minLength: 1 } },
};
export interface ReviewAnswer {
  scores: Record<ReviewScore, number>;
  slop: string[];
  verdict: "ok" | "revise";
  notes: string;
}

/** A score below this, or any slop id, makes the review "revise" whatever the producer's own verdict said. */
export const REVIEW_THRESHOLD = 0.6;

/** The concept as the design and review steps read it: the chosen pitch, why, hook and anchor, references. */
export function conceptText(c: Concept): string {
  const chosen = c.candidates[c.chosen];
  return [
    `- chosen pitch: ${chosen?.pitch ?? "?"} (likelihood ${chosen?.likelihood ?? "?"})`,
    `- why this one: ${c.why}`,
    `- the line: ${c.anchor} where ${c.hook}`,
    ...templateLines(c),
    ...c.references.map((r) => `- borrow from ${r.game}: ${r.borrow}`),
    `- the candidates it beat: ${c.candidates.filter((_, i) => i !== c.chosen).map((x) => `"${x.pitch}" (${x.likelihood})`).join("; ")}`,
  ].join("\n");
}

/** The design doc as text: what the Planner reads whole and every builder reads (verbs, feel, clips). */
export function designText(d: DesignDoc, parts: "all" | "builder" = "all"): string {
  const L: string[] = [];
  const verbs = d.verbs.map((v) => `  - ${v.id}${v.defensive === true ? " (DEFENSIVE)" : ""}${v.move !== undefined ? ` (copies the template move ${v.move})` : ""}: ${v.input}; anticipation ${v.anticipation_f} f, active ${v.active_f} f, recovery ${v.recovery_f} f; cancel: ${v.cancel}`);
  const f = d.feel;
  const feel = [
    `  - hit-stop: ${f.hitstop_f[0]} to ${f.hitstop_f[1]} frames on attacker AND victim, scaled by force`,
    `  - knockback: ${f.knockback}`,
    `  - victim reaction: ${f.reaction}`,
    `  - whiff (a miss): ${f.whiff}`,
    `  - i-frames of the defensive verb: ${f.iframes_f} frames from frame 1`,
    `  - rival telegraph: at least ${f.telegraph_f} frames`,
    `  - shake: ${f.shake}`,
    `  - camera: ${f.camera}`,
  ];
  const clips = d.clips.map((c) => `  - ${c.id}: ${c.moment}`);
  if (parts === "all") {
    L.push("- pillars:", ...d.pillars.map((p) => `  - ${p.line} (rules out: ${p.rules_out})`));
  }
  L.push("- verbs (frames at 60 Hz):", ...verbs, "- feel sheet:", ...feel, "- clip moments (what a viewer would clip; builders aim at them, the critic films them):", ...clips);
  if (parts === "all") {
    L.push(
      "- playstyles:", ...d.playstyles.map((p) => `  - ${p.id}: ${p.title}: ${p.line}`),
      `- loops: 3 s: ${d.loops.s3}; 30 s: ${d.loops.s30}; 3 min: ${d.loops.m3}`,
      `- context changers: ${d.context.join("; ")}`,
      `- skill: floor: ${d.skill.floor}; ceiling: ${d.skill.ceiling.join("; ")}`,
      `- first minute: ${d.first_minute}`,
      `- fail state: ${d.fail_state}`,
      `- out of scope: ${d.out_of_scope.join("; ") || "(none named)"}`,
    );
  }
  return L.join("\n");
}

/** The concept and the design doc of a brief for the Planner and the builders ("" for a brief made before the room). */
export function briefDesignText(brief: Brief, parts: "all" | "builder"): string {
  const out: string[] = [];
  if (brief.concept && parts === "all") out.push("- concept:", ...conceptText(brief.concept).split("\n").map((l) => `  ${l}`));
  if (brief.design) out.push(`- game design doc${parts === "builder" ? " (the part every builder lands for the verbs its package owns)" : ""}:`, ...designText(brief.design, parts).split("\n").map((l) => `  ${l}`));
  return out.join("\n");
}


/** The design step's checks beyond the v2 brief: the design doc's counts, ids and word limits. */
export function roomDesignProblems(brief: Brief): string[] {
  return brief.design === undefined ? ["the brief needs `design`, the game design doc"] : designProblems(brief.design, true);
}


/** The line of a builder's brief that names the clip moments its package serves ("" when it names none). */
export function servesLine(brief: Brief, spec: { serves?: string[] }): string {
  const clips = (spec.serves ?? []).map((id) => brief.design?.clips.find((c) => c.id === id)).filter((c): c is { id: string; moment: string } => c !== undefined);
  return clips.length > 0 ? `\n- your package serves these clip moments (make them happen and look good first): ${clips.map((c) => `${c.id} ("${c.moment}")`).join("; ")}` : "";
}

/** The builder prompt's Feel section for a brief with a design doc ("" otherwise): the rules, then the handbook. */
export function builderFeelSection(template?: ConceptTemplate): string {
  const excerpt = templateExcerpt(template, "builder");
  return feelRules() + (excerpt !== "" ? `\n${excerpt}` : "");
}

function feelRules(): string {
  return "# Feel (docs/GAME-QUALITY.md): this game is designed to be sold, so it must feel good in the hand\nThe brief above carries the game design doc: the verbs with their frames, the feel sheet in numbers and the three clip\nmoments. For every verb, hit and miss your package owns, build what the sheet says, with these rules:\n- Hit-stop on attacker AND victim together, in the sheet's range, scaled by the hit's force (the pack holds both\n  actors still for N physics frames; the engine has no global time freeze).\n- Every hit calls `TLHit.react(victim, from_dir, strength)`; only a big hit calls `TLHit.down(victim, frames, from_dir)`.\n  `from_dir` points from the victim toward the blow. Never a hit without a body reaction, never every hit a floor.\n- Each verb plays its OWN clip: `strike`, `strike_heavy`, `block`, `roll`, `dodge`, `body_check`, `cross_check`,\n  `taunt` (check `rig.has_method(\"clips\") and (rig.call(\"clips\") as PackedStringArray).has(\"strike\")` first; until a\n  clip exists, hold the nearest pose of the right kind and say so under DEVIATIONS; never play `shoot` as a strike,\n  `slide` as a roll or `cheer` as a tell).\n- A whiff plays its recovery and its own sound, no burst, no shake. Shake only on meaningful hits, decaying.\n- Defensive verbs are invulnerable from frame 1 for their frames; rival attacks show a wind-up of at least the sheet's\n  telegraph frames in the body; visible feedback within 3 frames of the press, the full pose by 6.\n- Every contact changes BOTH bodies: a blocked heavy recoils the attacker, a parry stuns him, a clash rebounds both.\n- The camera is never behind scenery and keeps both fighters in frame; bodies never overlap (they push apart).\n- Aim at the clip moments your package serves (the contract names them): they are what the critic films first.\n" + qualityText(["2", "6", "7:Builder"]) + "\n";
}
