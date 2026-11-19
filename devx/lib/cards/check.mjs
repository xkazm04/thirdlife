// Recipe cards (tl.card/1, contracts/CARDS.md): the checks that keep a card honest.
// A card is advice a builder is made to follow, so everything it names must exist AND be shown by the seed it points
// at. A card that names a vanished kit part, an API call the seed never makes, or a rules key the seed never sets
// fails here, before a builder is sent to copy something that is not there.
import fs from "node:fs";
import path from "node:path";

export const SCHEMA = "tl.card/1";
export const CARDS_DIR = "engine/cards";
const ID_RE = /^card\.[a-z][a-z0-9_]*$/;
const SEMVER_RE = /^\d+\.\d+\.\d+$/;

const STR = "string", LIST = "list";
/** key -> [type, required]. Unknown keys are errors; an absent optional key is omitted, never null. */
const SHAPE = {
  schema: [STR, true], id: [STR, true], version: [STR, true], title: [STR, true], summary: [STR, true],
  applies_when: [LIST, true], not_when: [LIST, false],
  seed: [STR, false], pack: [STR, false], capabilities: [LIST, true], kit_parts: [LIST, true], swap_parts: [LIST, false],
  api: [LIST, true], rules_keys: [LIST, true], data_files: [LIST, true],
  do: [LIST, true], dont: [LIST, true], bot: ["object", true], acceptance: [LIST, true], variants: [LIST, false], hands: ["object", false],
  interview: ["object", false], footprint: ["object", false],
};
const BOT_SHAPE = { template: [STR, true], plays_by: [STR, true], wins_when: [STR, true] };
const VARIANT_SHAPE = { ask: [STR, true], change: [STR, true] };
/** Lane C2 (18 Nov): what a person's hand must find in a game of this kind; TLHand's profiles plus idle (presses nothing). */
export const HANDS = ["idle", "newcomer", "regular", "sharp", "perfect"];
const HANDS_SHAPE = { seeds: ["number", true], checks: [LIST, true] };
const HAND_CHECK_SHAPE = { hand: [STR, true], wins_min: ["number", false], wins_max: ["number", false], measured: [STR, true] };

/** The hands block of a card: shape and bounds. Returns readable errors. */
export function handsErrors(h, where) {
  const errs = shapeErrors(h, HANDS_SHAPE, where);
  if (errs.length) return errs;
  if (!Number.isInteger(h.seeds) || h.seeds < 1 || h.seeds > 40) errs.push(`${where}: seeds must be an integer 1..40`);
  const seen = new Set();
  h.checks.forEach((c, i) => {
    const w = `${where}.checks[${i}]`, e = shapeErrors(c, HAND_CHECK_SHAPE, w);
    if (e.length) { errs.push(...e); return; }
    if (!HANDS.includes(c.hand)) errs.push(`${w}: hand '${c.hand}' must be one of ${HANDS.join(", ")}`);
    if (seen.has(c.hand)) errs.push(`${w}: hand '${c.hand}' is checked twice`);
    seen.add(c.hand);
    if (c.wins_min === undefined && c.wins_max === undefined) errs.push(`${w}: give wins_min, wins_max or both`);
    for (const k of ["wins_min", "wins_max"]) if (c[k] !== undefined && (!Number.isInteger(c[k]) || c[k] < 0 || c[k] > h.seeds)) errs.push(`${w}: ${k} must be an integer 0..${h.seeds}`);
    if (c.wins_min !== undefined && c.wins_max !== undefined && c.wins_min > c.wins_max) errs.push(`${w}: wins_min is above wins_max`);
  });
  return errs;
}
const DATA_FILE_SHAPE = { file: [STR, true], role: [STR, true] };

function shapeErrors(obj, shape, where) {
  const errs = [];
  if (obj === null || typeof obj !== "object" || Array.isArray(obj)) return [`${where}: must be an object`];
  for (const k of Object.keys(obj)) if (!Object.hasOwn(shape, k)) errs.push(`${where}: unknown key '${k}'`);
  for (const [k, [type, required]] of Object.entries(shape)) {
    if (!Object.hasOwn(obj, k)) { if (required) errs.push(`${where}: missing '${k}'`); continue; }
    const v = obj[k];
    if (v === null) errs.push(`${where}: '${k}' is null (omit the key instead)`);
    else if (type === STR && (typeof v !== "string" || !v.trim())) errs.push(`${where}: '${k}' must be a non-empty string`);
    else if (type === LIST && (!Array.isArray(v) || v.length === 0)) errs.push(`${where}: '${k}' must be a non-empty list`);
    else if (type === "array" && !Array.isArray(v)) errs.push(`${where}: '${k}' must be a list`);
    else if (type === "number" && !Number.isFinite(v)) errs.push(`${where}: '${k}' must be a finite number`);
    else if (type === "true" && v !== true) errs.push(`${where}: '${k}' must be true`);
    else if (type === "object" && (typeof v !== "object" || Array.isArray(v))) errs.push(`${where}: '${k}' must be an object`);
  }
  return errs;
}
const stringsOnly = (list, where, key) =>
  Array.isArray(list) && list.some((s) => typeof s !== "string" || !s.trim()) ? [`${where}: '${key}' holds a non-string or empty entry`] : [];
const duplicates = (list, where, key) => {
  if (!Array.isArray(list)) return [];
  const seen = new Set(), errs = [];
  for (const s of list) { if (seen.has(s)) errs.push(`${where}: '${key}' lists '${s}' twice`); seen.add(s); }
  return errs;
};

// CARDS.md "Interview and footprint": size.add, option stands, interview.variants (accepted 19 Nov)
const EDITOR_EXTENSIONS = {
  interview: { variants: ["array", false] },
  option: { stands: ["true", false] },
  size: { add: ["array", false] },
};
const FOOTPRINT_SHAPES = ["rink", "pitch", "court", "track", "slalom", "course", "arena", "yard"];
const requiredText = [STR, true];
const footprintShape = {
  size_m: ["array", true], height_m: ["number", true], shape: requiredText, source: requiredText,
};
const interviewShape = {
  kind: requiredText, example: requiredText, match: [LIST, true], estimate: ["object", true],
  questions: [LIST, true], ...EDITOR_EXTENSIONS.interview,
};
const questionShape = {
  key: requiredText, group: requiredText, ask: requiredText, options: [LIST, true], propose: requiredText, reason: requiredText,
};
const optionShape = {
  id: requiredText, label: requiredText, say: requiredText, from_words: [LIST, false],
  size: ["object", false], shape: [STR, false], ...EDITOR_EXTENSIONS.option,
};
const vector = (v, length, positive) => Array.isArray(v) && v.length === length
  && v.every((n) => Number.isFinite(n) && (!positive || n > 0));

function footprintErrors(f, where) {
  const errs = shapeErrors(f, footprintShape, where);
  if (errs.length) return errs;
  if (!vector(f.size_m, 2, true)) errs.push(`${where}: size_m must hold two positive numbers`);
  if (f.height_m <= 0) errs.push(`${where}: height_m must be positive`);
  if (!FOOTPRINT_SHAPES.includes(f.shape)) errs.push(`${where}: unknown footprint shape '${f.shape}'`);
  return errs;
}

function optionErrors(o, where) {
  const errs = shapeErrors(o, optionShape, where);
  if (errs.length) return errs;
  errs.push(...stringsOnly(o.from_words, where, "from_words"));
  if (o.shape !== undefined && !FOOTPRINT_SHAPES.includes(o.shape)) errs.push(`${where}: unknown shape '${o.shape}'`);
  if (o.size !== undefined) {
    const size = o.size, path = where + ".size";
    errs.push(...shapeErrors(size, { set: ["array", false], scale: ["number", false], ...EDITOR_EXTENSIONS.size }, path));
    if (Object.keys(size).length !== 1) errs.push(`${path}: give exactly one of set, scale, add`);
    if (size.set !== undefined && !vector(size.set, 3, true)) errs.push(`${path}: set must hold three positive numbers`);
    if (size.add !== undefined && !vector(size.add, 3, false)) errs.push(`${path}: add must hold three numbers`);
    if (Number.isFinite(size.scale) && size.scale <= 0) errs.push(`${path}: scale must be positive`);
  }
  return errs;
}

function interviewErrors(interview, where) {
  const errs = shapeErrors(interview, interviewShape, where);
  if (errs.length) return errs;
  errs.push(...stringsOnly(interview.match, where, "match"));
  const estimate = interview.estimate;
  errs.push(...shapeErrors(estimate, { packages: ["number", true], minutes: ["number", true], source: requiredText }, where + ".estimate"));
  if (!Number.isInteger(estimate.packages) || estimate.packages < 1) errs.push(`${where}.estimate: packages must be a positive integer`);
  if (Number.isFinite(estimate.minutes) && estimate.minutes <= 0) errs.push(`${where}.estimate: minutes must be positive`);
  const optionsByKey = new Map();
  interview.questions.forEach((q, i) => {
    const path = `${where}.questions[${i}]`, problems = shapeErrors(q, questionShape, path);
    if (problems.length) { errs.push(...problems); return; }
    if (!/^[a-z][a-z0-9_]*$/.test(q.key)) errs.push(`${path}: invalid question key '${q.key}'`);
    if (optionsByKey.has(q.key)) errs.push(`${path}: duplicate question key '${q.key}'`);
    if (!["who", "win", "where"].includes(q.group)) errs.push(`${path}: unknown group '${q.group}'`);
    const ids = new Set();
    optionsByKey.set(q.key, ids);
    q.options.forEach((o, j) => {
      errs.push(...optionErrors(o, `${path}.options[${j}]`));
      if (ids.has(o?.id)) errs.push(`${path}: duplicate option id '${o?.id}'`);
      if (typeof o?.id === "string") ids.add(o.id);
    });
    if (!ids.has(q.propose)) errs.push(`${path}: propose '${q.propose}' is not one of its options`);
  });
  (interview.variants ?? []).forEach((v, i) => {
    const path = `${where}.variants[${i}]`, problems = shapeErrors(v, { ask: requiredText, set: ["object", true] }, path);
    if (problems.length) { errs.push(...problems); return; }
    for (const [key, id] of Object.entries(v.set)) {
      if (!optionsByKey.has(key)) errs.push(`${path}.set: unknown question '${key}'`);
      else if (typeof id !== "string") errs.push(`${path}.set: option for '${key}' must be a string`);
      else if (!optionsByKey.get(key).has(id)) errs.push(`${path}.set: '${id}' is not an option for '${key}'`);
    }
  });
  return errs;
}

/** Structure only: no file system. Returns readable errors; empty = valid. */
export function validateCard(card, where = "card") {
  const errs = shapeErrors(card, SHAPE, where);
  if (errs.length) return errs;
  // CARDS.md (2026-11-17): the worked example is a seed (engine/seeds/) or a house game (engine/packs/), exactly one.
  if ((card.seed === undefined) === (card.pack === undefined)) errs.push(`${where}: exactly one of 'seed' and 'pack' must be given`);
  if (card.schema !== SCHEMA) errs.push(`${where}: schema must be '${SCHEMA}'`);
  if (!ID_RE.test(card.id)) errs.push(`${where}: id '${card.id}' must look like card.<snake_name>`);
  if (!SEMVER_RE.test(card.version)) errs.push(`${where}: version '${card.version}' must be x.y.z`);
  for (const k of ["applies_when", "not_when", "capabilities", "kit_parts", "swap_parts", "api", "rules_keys", "do", "dont", "acceptance"]) {
    errs.push(...stringsOnly(card[k], where, k), ...duplicates(card[k], where, k));
  }
  errs.push(...shapeErrors(card.bot, BOT_SHAPE, `${where}.bot`));
  card.data_files.forEach((d, i) => errs.push(...shapeErrors(d, DATA_FILE_SHAPE, `${where}.data_files[${i}]`)));
  (card.variants ?? []).forEach((v, i) => errs.push(...shapeErrors(v, VARIANT_SHAPE, `${where}.variants[${i}]`)));
  for (const a of card.api) if (typeof a === "string" && !/^TL[A-Za-z]+\.[a-z_][a-z0-9_]*$/.test(a)) errs.push(`${where}: api '${a}' must look like TLClass.member`);
  if (card.hands !== undefined) errs.push(...handsErrors(card.hands, `${where}.hands`));
  if (card.interview !== undefined) errs.push(...interviewErrors(card.interview, `${where}.interview`));
  if (card.footprint !== undefined) errs.push(...footprintErrors(card.footprint, `${where}.footprint`));
  const both = (card.swap_parts ?? []).filter((p) => card.kit_parts.includes(p));
  for (const p of both) errs.push(`${where}: '${p}' is in both kit_parts and swap_parts`);
  return errs;
}

function walk(dir, out = []) {
  if (!fs.existsSync(dir)) return out;
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) { if (e.name !== ".godot") walk(p, out); } else out.push(p);
  }
  return out;
}
const read = (p) => fs.readFileSync(p, "utf8");
const readJson = (p) => JSON.parse(read(p).replace(/^﻿/, ""));

/** What the engine really has: classes with their public members, kit part kinds, capability names. */
export function engineFacts(root) {
  const classes = new Map();   // TLName -> Set(member)
  for (const f of walk(path.join(root, "engine")).filter((f) => f.endsWith(".gd"))) {
    const relp = path.relative(root, f).split(path.sep).join("/");
    if (/^engine\/(seeds|packs|kernel\/examples|cards)\//.test(relp)) continue;
    const src = read(f);
    const cls = (src.match(/^class_name\s+(TL[A-Za-z0-9_]+)/m) ?? [])[1];
    if (!cls) continue;
    const members = classes.get(cls) ?? new Set();
    for (const m of src.matchAll(/^(?:static\s+)?func\s+([a-z][a-z0-9_]*)\s*\(/gm)) members.add(m[1]);
    for (const m of src.matchAll(/^signal\s+([a-z][a-z0-9_]*)/gm)) members.add(m[1]);
    for (const m of src.matchAll(/^(?:@export\s+)?var\s+([a-z][a-z0-9_]*)/gm)) members.add(m[1]);
    classes.set(cls, members);
  }
  let kitParts = null, kitWhy = "";
  try {
    kitParts = new Set(readJson(path.join(root, "assets", "manifest.json")).assets.filter((a) => a.kind === "kit_part").map((a) => a.id.replace(/^kit\./, "")));
  } catch (e) { kitWhy = `assets/manifest.json unreadable (${e.message}); run \`tl assets scan\``; }
  let capabilities = null;
  try { capabilities = new Set(readJson(path.join(root, "contracts", "pack.schema.json")).properties.capabilities.items.enum); } catch { /* checked below */ }
  return { classes, kitParts, kitWhy, capabilities };
}

/** The card's worked example: a seed (engine/seeds/<seed>) or, since 2026-11-17, a house game (engine/packs/<pack>). */
export function exampleOf(card) {
  return card.pack !== undefined ? { kind: "house pack", name: card.pack, rel: `engine/packs/${card.pack}` } : { kind: "seed", name: card.seed, rel: `engine/seeds/${card.seed}` };
}

/**
 * What one example pack really shows. null when the directory or its manifest is missing. `rulesKeys` are the
 * TLRules config keys the pack sets as data: the top level of data/rules.json (the seeds' way) and the `rules`
 * object of any data/*.json (the house game's way: hockey passes data/tuning.json "rules" to TLRules.create).
 */
export function exampleFacts(root, rel) {
  const dir = path.join(root, ...rel.split("/"));
  if (!fs.existsSync(path.join(dir, "pack.json"))) return null;
  const manifest = readJson(path.join(dir, "pack.json"));
  const files = walk(dir).map((f) => path.relative(dir, f).split(path.sep).join("/"));
  const code = files.filter((f) => f.endsWith(".gd")).map((f) => read(path.join(dir, f))).join("\n");
  const data = files.filter((f) => /^data\/.*\.json$/.test(f)).map((f) => read(path.join(dir, f))).join("\n");
  const parts = new Set();
  for (const m of data.matchAll(/"kind"\s*:\s*"([a-z_0-9]+)"/g)) parts.add(m[1]);
  for (const m of code.matchAll(/TLKit\.build\(\s*&?"([a-z_0-9]+)"/g)) parts.add(m[1]);
  let rulesKeys = new Set();
  try { rulesKeys = new Set(Object.keys(readJson(path.join(dir, "data", "rules.json"))).filter((k) => !k.startsWith("_"))); } catch { /* a seed without rules.json shows no rules key */ }
  for (const f of files.filter((f) => /^data\/[^/]+\.json$/.test(f) && f !== "data/rules.json")) {
    let doc;
    try { doc = readJson(path.join(dir, f)); } catch { continue; }
    const r = doc && typeof doc === "object" && !Array.isArray(doc) ? doc.rules : undefined;
    if (r && typeof r === "object" && !Array.isArray(r)) for (const k of Object.keys(r)) if (!k.startsWith("_")) rulesKeys.add(k);
  }
  return { dir, manifest, files: new Set(files), code, parts, rulesKeys };
}

/** What one seed really shows (engine/seeds/<seed>). */
export function seedFacts(root, seed) {
  return exampleFacts(root, `engine/seeds/${seed}`);
}

/** One card against the tree. Returns readable errors. */
export function checkCardAgainstTree(card, root, facts = engineFacts(root)) {
  const w = card.id, errs = [];
  const ex = exampleOf(card);
  const seed = exampleFacts(root, ex.rel);
  if (!seed) return [`${w}: ${ex.kind} '${ex.name}' has no ${ex.rel}/pack.json`];

  for (const c of card.capabilities) {
    if (facts.capabilities && !facts.capabilities.has(c)) errs.push(`${w}: capability '${c}' is not in contracts/pack.schema.json`);
    else if (!(seed.manifest.capabilities ?? []).includes(c)) errs.push(`${w}: capability '${c}' is not declared by ${ex.name} (a card promises only what its example shows)`);
  }
  if (!facts.kitParts) errs.push(`${w}: ${facts.kitWhy}`);
  for (const p of card.kit_parts) {
    if (facts.kitParts && !facts.kitParts.has(p)) errs.push(`${w}: kit part '${p}' does not exist in the kit (assets/manifest.json)`);
    else if (!seed.parts.has(p)) errs.push(`${w}: kit part '${p}' is not used by ${ex.name}; move it to swap_parts or drop it`);
  }
  for (const p of card.swap_parts ?? []) if (facts.kitParts && !facts.kitParts.has(p)) errs.push(`${w}: swap part '${p}' does not exist in the kit (assets/manifest.json)`);
  for (const a of card.api) {
    const [cls, member] = a.split(".");
    const members = facts.classes.get(cls);
    if (!members) errs.push(`${w}: api '${a}': no class ${cls} in engine/`);
    else if (!members.has(member)) errs.push(`${w}: api '${a}': ${cls} has no func, signal or var '${member}'`);
    else if (!new RegExp(`\\.${member}\\b`).test(seed.code)) errs.push(`${w}: api '${a}' is never used in ${ex.name}'s scripts or tests`);
  }
  for (const k of card.rules_keys) if (!seed.rulesKeys.has(k)) errs.push(`${w}: rules key '${k}' is not set in ${ex.name}'s data (data/rules.json, or the "rules" object of a data/*.json)`);
  for (const d of card.data_files) if (!seed.files.has(d.file)) errs.push(`${w}: data file '${d.file}' does not exist in ${ex.name}`);
  if (!seed.files.has(card.bot.template)) errs.push(`${w}: bot template '${card.bot.template}' does not exist in ${ex.name}`);
  else if (!(seed.manifest.tests ?? []).includes(card.bot.template)) errs.push(`${w}: bot template '${card.bot.template}' is not in ${ex.name}'s manifest tests`);
  for (const c of card.hands?.checks ?? []) {
    const t = `tests/bot_hand_${c.hand}.gd`;
    if (!seed.files.has(t)) errs.push(`${w}: hand check '${c.hand}': ${t} does not exist in ${ex.name} (the example a builder copies)`);
    else if (!(seed.manifest.tests ?? []).includes(t)) errs.push(`${w}: hand check '${c.hand}': ${t} is not in ${ex.name}'s manifest tests`);
  }
  return errs;
}

/** Reads every card file. Returns {cards: [{file, card}], errors: [..]}. */
export function loadCards(root) {
  const dir = path.join(root, CARDS_DIR), cards = [], errors = [];
  if (!fs.existsSync(dir)) return { cards, errors: [`${CARDS_DIR}/ does not exist`] };
  for (const name of fs.readdirSync(dir).filter((n) => n.endsWith(".json")).sort()) {
    const file = `${CARDS_DIR}/${name}`;
    try { cards.push({ file, card: readJson(path.join(dir, name)) }); } catch (e) { errors.push(`${file}: not valid JSON (${e.message})`); }
  }
  return { cards, errors };
}

/** The whole check: steps in the tl.devx/1 shape. */
export function checkCards({ root }) {
  const t0 = Date.now();
  const { cards, errors: loadErrors } = loadCards(root);
  const shape = [...loadErrors], tree = [];
  const ids = new Map();
  const facts = engineFacts(root);
  for (const { file, card } of cards) {
    const errs = validateCard(card, file);
    shape.push(...errs);
    if (errs.length) continue;
    if (ids.has(card.id)) shape.push(`${file}: id '${card.id}' is already used by ${ids.get(card.id)}`);
    ids.set(card.id, file);
    const want = `${CARDS_DIR}/${card.id.replace(/^card\./, "")}.json`;
    if (file !== want) shape.push(`${file}: a card with id '${card.id}' lives in ${want}`);
    tree.push(...checkCardAgainstTree(card, root, facts));
  }
  if (!cards.length && !loadErrors.length) shape.push(`${CARDS_DIR}/ holds no card`);
  const seeds = fs.existsSync(path.join(root, "engine", "seeds"))
    ? fs.readdirSync(path.join(root, "engine", "seeds")).filter((n) => fs.existsSync(path.join(root, "engine", "seeds", n, "pack.json"))) : [];
  const covered = new Set(cards.map((c) => c.card?.seed));
  const uncovered = seeds.filter((s) => !covered.has(s));
  const ms = Date.now() - t0;
  const line = (list) => list.slice(0, 6).join(" | ") + (list.length > 6 ? ` | (+${list.length - 6} more)` : "");
  return {
    cards: cards.map((c) => c.card),
    problems: { shape, tree, uncovered },
    steps: [
      { id: "cards.shape", ok: shape.length === 0, ms, detail: shape.length ? line(shape) : `${cards.length} cards, schema ok` },
      { id: "cards.references", ok: tree.length === 0, ms: 0, detail: tree.length ? line(tree) : "every seed or house pack, kit part, API member, rules key and bot a card names exists and is shown by that example" },
      { id: "cards.coverage", ok: uncovered.length === 0, ms: 0, detail: uncovered.length ? `seeds with no card: ${uncovered.join(", ")}` : `${seeds.length} seeds, each has a card` },
    ],
  };
}
