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
  seed: [STR, true], capabilities: [LIST, true], kit_parts: [LIST, true], swap_parts: [LIST, false],
  api: [LIST, true], rules_keys: [LIST, true], data_files: [LIST, true],
  do: [LIST, true], dont: [LIST, true], bot: ["object", true], acceptance: [LIST, true], variants: [LIST, false],
};
const BOT_SHAPE = { template: [STR, true], plays_by: [STR, true], wins_when: [STR, true] };
const VARIANT_SHAPE = { ask: [STR, true], change: [STR, true] };
const DATA_FILE_SHAPE = { file: [STR, true], role: [STR, true] };

function shapeErrors(obj, shape, where) {
  const errs = [];
  if (obj === null || typeof obj !== "object" || Array.isArray(obj)) return [`${where}: must be an object`];
  for (const k of Object.keys(obj)) if (!(k in shape)) errs.push(`${where}: unknown key '${k}'`);
  for (const [k, [type, required]] of Object.entries(shape)) {
    if (!(k in obj)) { if (required) errs.push(`${where}: missing '${k}'`); continue; }
    const v = obj[k];
    if (v === null) errs.push(`${where}: '${k}' is null (omit the key instead)`);
    else if (type === STR && (typeof v !== "string" || !v.trim())) errs.push(`${where}: '${k}' must be a non-empty string`);
    else if (type === LIST && (!Array.isArray(v) || v.length === 0)) errs.push(`${where}: '${k}' must be a non-empty list`);
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

/** Structure only: no file system. Returns readable errors; empty = valid. */
export function validateCard(card, where = "card") {
  const errs = shapeErrors(card, SHAPE, where);
  if (errs.length) return errs;
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

/** What one seed really shows. null when the seed directory or its manifest is missing. */
export function seedFacts(root, seed) {
  const dir = path.join(root, "engine", "seeds", seed);
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
  return { dir, manifest, files: new Set(files), code, parts, rulesKeys };
}

/** One card against the tree. Returns readable errors. */
export function checkCardAgainstTree(card, root, facts = engineFacts(root)) {
  const w = card.id, errs = [];
  const seed = seedFacts(root, card.seed);
  if (!seed) return [`${w}: seed '${card.seed}' has no engine/seeds/${card.seed}/pack.json`];

  for (const c of card.capabilities) {
    if (facts.capabilities && !facts.capabilities.has(c)) errs.push(`${w}: capability '${c}' is not in contracts/pack.schema.json`);
    else if (!(seed.manifest.capabilities ?? []).includes(c)) errs.push(`${w}: capability '${c}' is not declared by ${card.seed} (a card promises only what its seed shows)`);
  }
  if (!facts.kitParts) errs.push(`${w}: ${facts.kitWhy}`);
  for (const p of card.kit_parts) {
    if (facts.kitParts && !facts.kitParts.has(p)) errs.push(`${w}: kit part '${p}' does not exist in the kit (assets/manifest.json)`);
    else if (!seed.parts.has(p)) errs.push(`${w}: kit part '${p}' is not used by ${card.seed}; move it to swap_parts or drop it`);
  }
  for (const p of card.swap_parts ?? []) if (facts.kitParts && !facts.kitParts.has(p)) errs.push(`${w}: swap part '${p}' does not exist in the kit (assets/manifest.json)`);
  for (const a of card.api) {
    const [cls, member] = a.split(".");
    const members = facts.classes.get(cls);
    if (!members) errs.push(`${w}: api '${a}': no class ${cls} in engine/`);
    else if (!members.has(member)) errs.push(`${w}: api '${a}': ${cls} has no func, signal or var '${member}'`);
    else if (!new RegExp(`\\.${member}\\b`).test(seed.code)) errs.push(`${w}: api '${a}' is never used in ${card.seed}'s scripts or tests`);
  }
  for (const k of card.rules_keys) if (!seed.rulesKeys.has(k)) errs.push(`${w}: rules key '${k}' is not set in ${card.seed}/data/rules.json`);
  for (const d of card.data_files) if (!seed.files.has(d.file)) errs.push(`${w}: data file '${d.file}' does not exist in ${card.seed}`);
  if (!seed.files.has(card.bot.template)) errs.push(`${w}: bot template '${card.bot.template}' does not exist in ${card.seed}`);
  else if (!(seed.manifest.tests ?? []).includes(card.bot.template)) errs.push(`${w}: bot template '${card.bot.template}' is not in ${card.seed}'s manifest tests`);
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
      { id: "cards.references", ok: tree.length === 0, ms: 0, detail: tree.length ? line(tree) : "every seed, kit part, API member, rules key and bot a card names exists and is shown by its seed" },
      { id: "cards.coverage", ok: uncovered.length === 0, ms: 0, detail: uncovered.length ? `seeds with no card: ${uncovered.join(", ")}` : `${seeds.length} seeds, each has a card` },
    ],
  };
}
