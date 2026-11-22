// N4 of 22 Nov (GAME-QUALITY.md v2 section 11): genre templates. The owner, 21 Nov: "there are hundreds of duel games
// (souls like, for honor duels) with well known game design paths we can mimic". Every core loop copies ONE proven
// design: the concept step names it (`concept.template`), the design step copies its move frames exactly (a verb's
// `move`), and the design step, the Planner and the builders read the template's research excerpt from docs/research,
// the relevant one only. Pure apart from reading the research files (a missing file gives a one-line note).
// N4 loop round 1 (22 Nov, 01:00): the owner's extension makes engine/packs/duel and engine/packs/hockey the reference
// games. A template now names its HOUSE GAME: the pack is the reference implementation, its README's rules are what the
// design step and the Planner copy, its files are what the builders read (every job's ref/packs/<pack>/ holds a copy),
// and its own data (the duel's data/moves.json) is the frame table the Foreman checks against: the house numbers are
// tuned on the kernel, so where they differ from the research, the house game wins.
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
  /** The house game: the reference implementation the editor copies (N4 loop round 1). */
  house?: House;
}

/** A house game (engine/packs/<pack>): what to copy and where. */
export interface House {
  pack: string;
  game: string;
  /** README headings the design step and the Planner read whole. */
  readme: string[];
  /** The files a builder reads, with what each holds. */
  files: { file: string; role: string }[];
  /** The pack's own frame table (a moves.json in the shape of engine/packs/duel/data/moves.json), when it has one. */
  moves?: string;
  /** Rules of the house game a design must keep, each with a pattern over the brief's rules and controls text. */
  keeps?: { what: string; re: RegExp }[];
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
    house: {
      pack: "duel",
      game: "game.duel",
      readme: ["## How to play", "## What you see", "## The rules", "## The rivals", "## What changed from the playbook"],
      files: [
        { file: "data/moves.json", role: "the frame table (6.2), the source of truth: windup / active / recovery, damage, stamina, poise, reach, arc, armour, and the [move frame, clip frame] map that stretches a fight clip over a readable wind-up" },
        { file: "data/contacts.json", role: "the contact table (6.3): hit-stop on both, the defender's stun and push, the attacker's recoil or rebound, the poise tiers, the pose each stun shows" },
        { file: "scripts/contact.gd", role: "the interaction matrix (6.5): which contact an active move makes against each defender state, and what it does to BOTH fighters" },
        { file: "scripts/feel.gd", role: "the one adapter over the kernel feel kit: TLHit.impact hit-stop on both, the six contact reactions, knockdown, pushbox, occluder fade, the rig clocks" },
        { file: "scripts/fighter.gd", role: "one fighter's state machine (6.4), the resources, the 8-frame buffer, the lock-on facing (the pack turns the body), the clip clocks" },
        { file: "scripts/brain.gd", role: "the rival's mind (6.6): sees only the player's animation react frames late, defends in its archetype's way, reads chains, never a string three times, a return window after each" },
        { file: "data/rivals.json", role: "the AI tiers and the three archetypes (Wall, Duelist, Dancer): hp, poise, defence weights, strings with fixed delays, phase 2" },
        { file: "scripts/show.gd", role: "HUD bars (health, stamina, posture), banners (PARRY!, WALL SPLAT!), cues, the three cameras" },
        { file: "tests/support/pilot.gd", role: "the bot that plays the player's side through a TLHand; tests/bot_contact_<type>.gd: one drill per contact, passing when BOTH fighters changed" },
      ],
      moves: "data/moves.json",
      keeps: [
        { what: "the lock-on: each fighter always faces his rival (the house game turns the body; facing never follows the walk), so the 120-degree guard holds while circling", re: /lock[- ]?on|always faces?|faces? (his|her|their|the) (rival|opponent|foe)|face each other/i },
        { what: "the camera over the shoulder, offset to the side, looking between the two fighters (back 4.6 m, up 2.6 m, side 2.6 m), over a ring wall low enough to see over", re: /shoulder|offset to the side|side[- ]on|between (the|both) fighters|between them/i },
      ],
    },
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
    house: {
      pack: "hockey",
      game: "game.ice_hockey_three_against",
      readme: ["## How to play", "## Contact and skating", "## What the game is"],
      files: [
        { file: "scripts/skate.gd", role: "skating: thrust, sprint and stamina, the carrier slower than a free skater, the reverse cut and first step" },
        { file: "scripts/player.gd", role: "possession by reach (the 1.45 m ring), the carry on the blade, the shot on release, the pass to the mate where the stick points" },
        { file: "scripts/hits.gd", role: "body contact: wind-up, impulse against stability, bump / stumble / down, the puck freed above a threshold, nobody stands in a man who is down" },
        { file: "scripts/ai/", role: "the skaters' and the goalie's decisions" },
        { file: "scripts/keeper.gd", role: "the goalie" },
        { file: "data/tuning.json", role: "the numbers of the rink, the speeds, the periods" },
        { file: "data/levels/", role: "the opponent levels: reaction frames and speed share, never hidden help" },
      ],
    },
  },
];

export const templateOf = (id: string | undefined): Template | undefined => TEMPLATES.find((t) => t.id === id);

/** The engine the house games are read from (the repository's; a test passes its own). */
export const HOUSE_ENGINE = path.join(REPO_ROOT, "engine");

type HouseMovesFile = Record<string, { windup?: number; active?: number; recovery?: number; up?: number; from?: number; to?: number; whiff?: number; frames?: number; iframes?: [number, number]; clip?: string }>;

/**
 * The house game's frame table as template moves, read from its moves file (`undefined` without a house game or file).
 * Attacks are windup / active / recovery; block is up / held / the playbook's 6 down; the parry window f`from`-f`to`
 * is (from - 1) / (to - from + 1) / whiff; roll and dodge are i-frames start - 1 / their length / the frames after.
 */
export function houseMoves(t: Template, engine = HOUSE_ENGINE): Record<string, TemplateMove> | undefined {
  if (t.house?.moves === undefined) return undefined;
  const file = path.join(engine, "packs", t.house.pack, ...t.house.moves.split("/"));
  if (!fs.existsSync(file)) return undefined;
  let m: HouseMovesFile;
  try {
    m = JSON.parse(stripBom(fs.readFileSync(file, "utf8"))) as HouseMovesFile;
  } catch {
    return undefined;
  }
  const out: Record<string, TemplateMove> = {};
  for (const [id, base] of Object.entries(t.moves)) {
    const h = m[id];
    if (h === undefined) {
      out[id] = base;
      continue;
    }
    const clip = h.clip ?? base.clip;
    if (h.windup !== undefined && h.recovery !== undefined) out[id] = { ...base, anticipation_f: h.windup, ...(h.active !== undefined ? { active_f: h.active } : {}), recovery_f: h.recovery, clip };
    else if (id === "block" && h.up !== undefined) out[id] = { ...base, anticipation_f: h.up };
    else if (id === "parry" && h.from !== undefined && h.to !== undefined) out[id] = { ...base, anticipation_f: h.from - 1, active_f: h.to - h.from + 1, recovery_f: h.whiff ?? base.recovery_f };
    else if (h.iframes !== undefined && h.frames !== undefined) out[id] = { ...base, anticipation_f: h.iframes[0] - 1, active_f: h.iframes[1] - h.iframes[0] + 1, recovery_f: h.frames - h.iframes[1], clip };
    else if (h.frames !== undefined) out[id] = { ...base, anticipation_f: 0, active_f: 0, recovery_f: h.frames, clip };
    else out[id] = base;
  }
  return out;
}

/** The frame table the Foreman checks: the house game's when it can be read, else the research's. */
export const movesOf = (t: Template, engine = HOUSE_ENGINE): Record<string, TemplateMove> => houseMoves(t, engine) ?? t.moves;

/** Where the house game's frame table differs from the research's, one line per move ([] when they agree or no house table). */
export function houseFrameDiff(t: Template, engine = HOUSE_ENGINE): string[] {
  const h = houseMoves(t, engine);
  if (h === undefined) return [];
  const f = (m: TemplateMove): string => `${m.anticipation_f}/${m.active_f ?? "held"}/${m.recovery_f}`;
  return Object.entries(t.moves).filter(([id, m]) => h[id] !== undefined && f(h[id] as TemplateMove) !== f(m)).map(([id, m]) => `${id}: research ${f(m)}, house game ${f(h[id] as TemplateMove)}`);
}

/** The house game's README sections and the files to read, for the design step and the Planner ("design") or a builder ("builder"). */
export function houseExcerpt(t: Template, part: "design" | "builder", engine = HOUSE_ENGINE): string {
  const h = t.house;
  if (h === undefined) return "";
  const dir = path.join(engine, "packs", h.pack);
  if (!fs.existsSync(path.join(dir, "README.md"))) return "";
  const files = h.files.map((f) => `- engine/packs/${h.pack}/${f.file}: ${f.role}`);
  const keeps = (h.keeps ?? []).map((k) => `- keep ${k.what}`);
  const head = `# The house game: engine/packs/${h.pack} (${h.game}), the reference implementation of this template
It is a tracked game of this engine that plays the template on the kernel, tuned there. Copy its rules, its numbers and
its structure; where its numbers differ from the research, the house game's win (they are measured on this kernel).${part === "builder" ? `
Your reference copy holds it whole: ref/packs/${h.pack}/ (read the files below before you write yours).` : ""}`;
  const body = part === "design" ? researchSections(`engine/packs/${h.pack}/README.md`, h.readme, path.dirname(engine)) : "";
  return [head, "", "The files that carry it:", ...files, ...(keeps.length > 0 ? ["", "What a design of this template keeps from it:", ...keeps] : []), ...(body !== "" ? ["", body] : [])].join("\n") + "\n";
}

/** A brief's template problems: the design's copied moves, and what the house game keeps (in rules and controls). */
export function briefTemplateProblems(brief: { design?: DesignDoc; rules: string; controls: string; arena: string }, template: ConceptTemplate | undefined): string[] {
  if (brief.design === undefined || template === undefined) return [];
  return [...designTemplateProblems(brief.design, template), ...houseKeepProblems(`${brief.rules} ${brief.controls} ${brief.arena} ${brief.design.feel.camera}`, template)];
}

/** Problems of a brief against its template's house game: the rules it must keep (rules and controls text). */
export function houseKeepProblems(text: string, template: ConceptTemplate | undefined): string[] {
  const t = templateOf(template?.id);
  return (t?.house?.keeps ?? []).filter((k) => !k.re.test(text)).map((k) => `the ${t?.id} house game (engine/packs/${t?.house?.pack}) keeps ${k.what}: say it in \`rules\`, \`controls\`, \`arena\` or \`design.feel.camera\``);
}

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
    const at = lines.findIndex((l) => l.startsWith(h)); // "## What changed from the playbook" heads "..., and why"
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
    out.push(`- \`${t.id}\`: ${t.title}. Reference: ${t.reference}.${t.house ? ` House game (the reference implementation on this engine): engine/packs/${t.house.pack} (${t.house.game}).` : ""}`);
    out.push(`  - copies (name each in \`copies\`): ${t.must.map((m) => m.what).join("; ")}.`);
    if (Object.keys(t.moves).length > 0) out.push(`  - its move table (a verb that copies a move names it as \`move\` and carries these frames exactly): ${movesLine(t)}.`);
  }
  out.push("- `own`: any other genre. Name a real, released game (or a family of them) as `reference`, and in `copies` the exact mechanics with their numbers where the source has them (Mario Kart's item roulette by race position; Celeste's 5-frame coyote time). Never a mood.");
  return out.join("\n");
}

const movesLine = (t: Template): string =>
  Object.entries(movesOf(t))
    .map(([id, m]) => `${id} ${m.anticipation_f}/${m.active_f ?? "held"}/${m.recovery_f} (\`${m.clip}\`)`)
    .join(", ");

/** The research excerpt of the concept's template for a reader ("" for `own` or a concept without a template). */
export function templateExcerpt(template: ConceptTemplate | undefined, part: "design" | "planner" | "builder", root = REPO_ROOT): string {
  const t = templateOf(template?.id);
  if (t === undefined) return "";
  const head =
    part !== "builder"
      ? `# The genre template: ${t.id} (${t.title}), copied from ${t.reference}\nThe core loop is copied from this, not invented: its state machine, its frame tables, its contact results and its rivals. Verbs that copy a move name it as \`move\` with these frames exactly: ${movesLine(t)}. Only the hook and the twist are new.`
      : `# The genre template: ${t.id} (${t.title}), from ${t.file}\nThe design copies this proven design. Build its rules and tables as written; where your contract gives a number, the contract wins.`;
  // The Planner reads the research's implementable spec and the house game's rules (its prompt is long enough).
  const house = houseExcerpt(t, part === "builder" ? "builder" : "design", path.join(root, "engine"));
  return `${head}\n\n${researchSections(t.file, part === "design" ? t.design : t.builder, root)}\n${house !== "" ? `\n${house}` : ""}`;
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
  const table = movesOf(t);
  for (const v of copied) {
    const m = table[v.move as string];
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
    const kinds = new Set(copied.map((v) => table[v.move as string]?.kind));
    if (!kinds.has("attack")) out.push(`the ${t.id} template: one verb copies an attack move (${Object.entries(t.moves).filter(([, m]) => m.kind === "attack").map(([id]) => id).join(", ")})`);
    if (!kinds.has("defence")) out.push(`the ${t.id} template: one verb copies a defence move (${Object.entries(t.moves).filter(([, m]) => m.kind === "defence").map(([id]) => id).join(", ")})`);
  }
  return out;
}
