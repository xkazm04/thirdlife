// N4 of 22 Nov (GAME-QUALITY.md v2 section 11): genre templates. The owner, 21 Nov: "there are hundreds of duel games
// (souls like, for honor duels) with well known game design paths we can mimic". Every core loop copies ONE proven
// design: the concept step names it (`concept.template`), the design step copies its move frames exactly (a verb's
// `move`), and the design step, the Planner and the builders read the template's research excerpt from docs/research,
// the relevant one only. Pure apart from reading the research files (a missing file gives a one-line note).
import fs from "node:fs";
import path from "node:path";
import { REPO_ROOT, stripBom } from "./paths.js";
import type { Concept, ConceptTemplate, DesignDoc, TemplateId } from "./room_wire.js";

/** One move of a template's frame table: the frames a verb that names it must carry (active absent = held, not checked). */
export interface TemplateMove {
  anticipation_f: number;
  active_f?: number;
  recovery_f: number;
  clip: string;
  kind: "attack" | "defence" | "other";
}

/** A tofu metric a template adds (GAME-QUALITY.md section 12): passes when min <= value <= max. */
export interface TemplateMetric {
  id: string;
  min?: number;
  max?: number;
  item: string;
}

export interface Template {
  id: Exclude<TemplateId, "own">;
  title: string;
  /** The sentence words that make this the template (a melee fight is a duel). */
  sentence: RegExp;
  reference: string;
  /** The research file, relative to the repository. */
  file: string;
  /** Headings ("## 2.", "### 6.3") of the file the design step and the Planner read; the builders read `builder`. */
  design: string[];
  builder: string[];
  /** What `concept.template.copies` must name, each with a pattern that finds it. */
  must: { what: string; re: RegExp }[];
  moves: Record<string, TemplateMove>;
  /** At least this many verbs name a move; one of them an attack and one a defence when > 0. */
  movesMin: number;
  metrics: TemplateMetric[];
  /** The recipe card that is the default for this template when the job offers it. */
  card?: string;
}

export const TEMPLATES: Template[] = [
  {
    id: "duel",
    title: "a melee duel",
    sentence: /\b(fight|fighting|fighter|duel|sword|swords|gladiator|gladiators|colosseum|coliseum|boxing|boxer|knight|knights|samurai|brawl|brawler|fencing|melee)\b/i,
    reference: "Dark Souls / Sekiro / For Honor, as docs/research/DUEL-PLAYBOOK.md",
    file: "docs/research/DUEL-PLAYBOOK.md",
    design: ["## 1.", "## 2.", "## 3.", "## 4.", "## 5.", "## 6."],
    builder: ["## 2.", "## 6."],
    must: [
      { what: "the state machine (DUEL-PLAYBOOK 6.4)", re: /state machine|states?\b.*(windup|recovery|hitstun|blockstun)/i },
      { what: "the mutual reactions: every contact changes both fighters (DUEL-PLAYBOOK 2 and 6.3)", re: /mutual|both fighters|both bodies|contact (results|table)|every contact/i },
      { what: "the three rival archetypes by their defence (DUEL-PLAYBOOK 6.7: the Wall absorbs, the Duelist parries, the Dancer avoids)", re: /archetype|\bwall\b.*duelist|duelist|dancer|absorb.*parr|parr.*avoid/i },
    ],
    moves: {
      light: { anticipation_f: 18, active_f: 4, recovery_f: 16, clip: "strike", kind: "attack" },
      heavy: { anticipation_f: 32, active_f: 5, recovery_f: 28, clip: "strike_heavy", kind: "attack" },
      charged: { anticipation_f: 54, active_f: 6, recovery_f: 36, clip: "strike_heavy", kind: "attack" },
      bash: { anticipation_f: 14, active_f: 6, recovery_f: 24, clip: "body_check", kind: "attack" },
      block: { anticipation_f: 4, recovery_f: 6, clip: "block", kind: "defence" },
      parry: { anticipation_f: 1, active_f: 12, recovery_f: 20, clip: "block", kind: "defence" },
      roll: { anticipation_f: 3, active_f: 18, recovery_f: 15, clip: "roll", kind: "defence" },
      dodge: { anticipation_f: 2, active_f: 8, recovery_f: 12, clip: "dodge", kind: "defence" },
      taunt: { anticipation_f: 0, active_f: 0, recovery_f: 60, clip: "taunt", kind: "other" },
    },
    movesMin: 3,
    metrics: [
      { id: "contact_types", min: 3, item: "DUEL-PLAYBOOK 6.3: at least 3 kinds of contact met (hit, block, parry, bash, clash, whiff)" },
      { id: "one_sided_contacts", max: 0, item: "DUEL-PLAYBOOK acceptance: no contact leaves one fighter's state unchanged" },
    ],
    card: "card.duel",
  },
  {
    id: "arcade_sport",
    title: "an arcade team sport with a ball or puck",
    sentence: /\b(hockey|football|soccer|basketball|handball|rugby|puck|ball game|lacrosse|polo)\b/i,
    reference: "NHL '94 / Rocket League / Buckland's Simple Soccer, as docs/research/HOCKEY-ARCADE.md",
    file: "docs/research/HOCKEY-ARCADE.md",
    design: ["## 0.", "## 1.", "## 5."],
    builder: ["## 0.", "## 5."],
    must: [
      { what: "possession as a state with readable loss causes (HOCKEY-ARCADE 5.1)", re: /possession|carr(y|ied|ier)/i },
      { what: "the utility AI for shoot, pass and carry (HOCKEY-ARCADE 5.3)", re: /utility|scored options|decid|vetoes/i },
      { what: "the roles re-sorted by time to the ball (HOCKEY-ARCADE 5.4)", re: /\broles?\b|first man|support/i },
    ],
    moves: {
      poke: { anticipation_f: 5, active_f: 7, recovery_f: 12, clip: "cross_check", kind: "attack" },
    },
    movesMin: 0,
    metrics: [{ id: "possession_median_f", min: 240, max: 600, item: "HOCKEY-ARCADE 5.5: possession median 4-10 s (over 15 s glued, under 2 s random)" }],
  },
];

export const templateOf = (id: string | undefined): Template | undefined => TEMPLATES.find((t) => t.id === id);

/** The template a sentence calls for by its words (a fight is a duel), or undefined. */
export function templateForSentence(sentence: string): Template | undefined {
  return TEMPLATES.find((t) => t.sentence.test(sentence));
}

/** Sections of a research file by heading prefix ("## 2." takes the section to the next "## "; "### 6.3" to the next heading). */
export function researchSections(file: string, headings: string[], root = REPO_ROOT): string {
  const abs = path.join(root, ...file.split("/"));
  if (!fs.existsSync(abs)) return `(${file} was not found: copy the template from its reference games)`;
  const lines = stripBom(fs.readFileSync(abs, "utf8")).split(/\r?\n/);
  const out: string[] = [];
  for (const h of headings) {
    const level = h.startsWith("### ") ? 3 : 2;
    const at = lines.findIndex((l) => l.startsWith(`${h} `) || l === h);
    if (at < 0) continue;
    const stop = level === 3 ? /^#{2,3} / : /^## /;
    let end = lines.findIndex((l, i) => i > at && stop.test(l));
    if (end < 0) end = lines.length;
    out.push(lines.slice(at, end).join("\n").trim());
  }
  return out.join("\n\n");
}

/** The concept step's menu: each template, when it applies, what is copied, and its move ids. */
export function templatesMenuText(): string {
  const out: string[] = [];
  for (const t of TEMPLATES) {
    out.push(`- \`${t.id}\`: ${t.title}. Reference: ${t.reference}.`);
    out.push(`  - copies (name each in \`copies\`): ${t.must.map((m) => m.what).join("; ")}.`);
    if (Object.keys(t.moves).length > 0) out.push(`  - its move table (a verb that copies a move names it as \`move\` and carries these frames exactly): ${movesLine(t)}.`);
  }
  out.push("- `own`: any other genre. Name a real, released game (or a family of them) as `reference`, and in `copies` the exact mechanics with their numbers where the source has them (Mario Kart's item roulette by race position; Celeste's 5-frame coyote time). Never a mood.");
  return out.join("\n");
}

const movesLine = (t: Template): string =>
  Object.entries(t.moves)
    .map(([id, m]) => `${id} ${m.anticipation_f}/${m.active_f ?? "held"}/${m.recovery_f} (\`${m.clip}\`)`)
    .join(", ");

/** The research excerpt of the concept's template for a reader ("" for `own` or a concept without a template). */
export function templateExcerpt(template: ConceptTemplate | undefined, part: "design" | "builder", root = REPO_ROOT): string {
  const t = templateOf(template?.id);
  if (t === undefined) return "";
  const head =
    part === "design"
      ? `# The genre template: ${t.id} (${t.title}), copied from ${t.reference}\nThe core loop is copied from this, not invented: its state machine, its frame tables, its contact results and its rivals. Verbs that copy a move name it as \`move\` with these frames exactly: ${movesLine(t)}. Only the hook and the twist are new.`
      : `# The genre template: ${t.id} (${t.title}), from ${t.file}\nThe design copies this proven design. Build its rules and tables as written; where your contract gives a number, the contract wins.`;
  return `${head}\n\n${researchSections(t.file, part === "design" ? t.design : t.builder, root)}\n`;
}

/** The template lines of a concept, as the design step, the review and the Planner read them. */
export function templateLines(c: Concept): string[] {
  if (c.template === undefined) return [];
  return [`- genre template: ${c.template.id}, copied from ${c.template.reference}`, ...c.template.copies.map((x) => `  - copies: ${x}`)];
}

/**
 * Problems of a concept's template: it is there, a melee fight copies the duel (and a team ball game the arcade sport),
 * and its `copies` name what the template must copy. `own` needs a reference that is not one of the others' words.
 */
export function conceptTemplateProblems(c: Concept, sentence: string): string[] {
  const out: string[] = [];
  if (c.template === undefined) return ['the concept needs `template`: ONE proven genre template for the core loop ({"id": "duel" | "arcade_sport" | "own", "reference", "copies"})'];
  const wanted = templateForSentence(sentence);
  if (wanted !== undefined && c.template.id !== wanted.id) out.push(`the player's words ask for ${wanted.title}: the template is "${wanted.id}" (${wanted.reference}), not "${c.template.id}"; put the novelty in the hook, not in the core loop`);
  const t = templateOf(c.template.id);
  if (t === undefined) return out;
  const all = c.template.copies.join(" | ");
  for (const m of t.must) if (!m.re.test(all)) out.push(`concept template ${t.id}: \`copies\` must name ${m.what}`);
  return out;
}

/**
 * Problems of a design's verbs against the concept's template (GAME-QUALITY.md section 11): a `move` is a move of the
 * template, its frames are the table's exactly, and at least `movesMin` verbs copy a move, one attack and one defence.
 */
export function designTemplateProblems(d: DesignDoc, template: ConceptTemplate | undefined): string[] {
  const t = templateOf(template?.id);
  const out: string[] = [];
  if (t === undefined) {
    for (const v of d.verbs) if (v.move !== undefined && template?.id !== "own") out.push(`design verb "${v.id}" names move "${v.move}", but the concept has no genre template with moves`);
    return out;
  }
  const copied = d.verbs.filter((v) => v.move !== undefined);
  for (const v of copied) {
    const m = t.moves[v.move as string];
    if (m === undefined) {
      out.push(`design verb "${v.id}" names move "${v.move}", which is not in the ${t.id} move table (${Object.keys(t.moves).join(", ")})`);
      continue;
    }
    const diff: string[] = [];
    if (v.anticipation_f !== m.anticipation_f) diff.push(`anticipation_f ${v.anticipation_f} (the table: ${m.anticipation_f})`);
    if (m.active_f !== undefined && v.active_f !== m.active_f) diff.push(`active_f ${v.active_f} (the table: ${m.active_f})`);
    if (v.recovery_f !== m.recovery_f) diff.push(`recovery_f ${v.recovery_f} (the table: ${m.recovery_f})`);
    if (diff.length > 0) out.push(`design verb "${v.id}" copies the ${t.id} move "${v.move}" but changes its frames: ${diff.join(", ")}. Copy the table, not a paraphrase`);
    if ((m.kind === "defence") !== (v.defensive === true) && m.kind !== "other") out.push(`design verb "${v.id}" copies the ${m.kind} move "${v.move}": mark it ${m.kind === "defence" ? '"defensive": true' : "not defensive"}`);
  }
  if (t.movesMin > 0) {
    if (copied.length < t.movesMin) out.push(`the ${t.id} template: at least ${t.movesMin} verbs copy a move of its table (name it as \`move\`), ${copied.length} do: ${movesLine(t)}`);
    const kinds = new Set(copied.map((v) => t.moves[v.move as string]?.kind));
    if (!kinds.has("attack")) out.push(`the ${t.id} template: one verb copies an attack move (${Object.entries(t.moves).filter(([, m]) => m.kind === "attack").map(([id]) => id).join(", ")})`);
    if (!kinds.has("defence")) out.push(`the ${t.id} template: one verb copies a defence move (${Object.entries(t.moves).filter(([, m]) => m.kind === "defence").map(([id]) => id).join(", ")})`);
  }
  return out;
}
