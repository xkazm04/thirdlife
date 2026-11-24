// Cartridge validator for Third Jam. Zero dependencies, Node 24.
//
// Usage
//   node schema/validate.mjs file.json                 exit 0 valid, 1 invalid, 2 could not run
//   node schema/validate.mjs out.json --base in.json   also check that only Designer-editable parts changed
//   import { validateCartridge } from './validate.mjs' // -> { ok, errors: string[] }
//
// JSON Schema subset implemented here (anything else in a schema file is a loud error, never ignored):
//   type (a name or a list of names: object array string number integer boolean null)
//   required, properties, additionalProperties (false, true or a schema), items (one schema)
//   enum, const, pattern, minimum, maximum, minLength, maxLength, minItems, maxItems
//   $ref to "#/$defs/name" in the same file, or to a local file "other.json" (optionally "other.json#/$defs/name"),
//   a $ref must stand alone except for annotations
//   annotations that are read and ignored: $schema $id $comment title description default examples $defs
//   `description` on a node that has `pattern` is appended to the pattern error, so keep it a plain-English rule.
// Number keywords apply only to numbers, string keywords only to strings, array keywords only to arrays, so a
// node with type ["number","string"] can carry both minimum and maxLength.
//
// On top of the schema there are engine checks (see checkEngine): list lengths from limits.json, unique ids,
// `values` keys exist in `tunables` and sit inside their declared type/range/options, tunable bounds are sane,
// durations are physics frames (names ending in *_frames, never *_seconds/*_ms), ai.applies_to points at real
// entities, optional blocked_terms. Errors are sentences that start with a JSON pointer, because a model reads
// them to repair its own output.

import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { parseStrict } from './strict-json.mjs';

const HERE = dirname(fileURLToPath(import.meta.url));
const SCHEMA_FILE = resolve(HERE, 'cartridge.schema.json');
const LIMITS_FILE = resolve(HERE, 'limits.json');

const ANNOTATIONS = new Set(['$schema', '$id', '$comment', 'title', 'description', 'default', 'examples', '$defs']);
const KEYWORDS = new Set([
  'type', 'required', 'properties', 'additionalProperties', 'items', 'enum', 'const', 'pattern',
  'minimum', 'maximum', 'minLength', 'maxLength', 'minItems', 'maxItems', '$ref',
]);

const fileCache = new Map();
export function loadJsonFile(path) {
  const abs = resolve(path);
  if (!fileCache.has(abs)) fileCache.set(abs, JSON.parse(readFileSync(abs, 'utf8')));
  return fileCache.get(abs);
}

export function loadLimits() {
  return loadJsonFile(LIMITS_FILE);
}

// ---------- helpers that build readable text ----------

const esc = (s) => String(s).replace(/~/g, '~0').replace(/\//g, '~1');
const child = (ptr, key) => `${ptr}/${esc(key)}`;
const show = (p) => (p === '' ? '/' : p);

function describe(v) {
  if (v === null) return 'null (omit the key instead of writing null)';
  if (Array.isArray(v)) return `an array of ${v.length} item${v.length === 1 ? '' : 's'}`;
  if (typeof v === 'string') return `a string (${JSON.stringify(v.length > 40 ? v.slice(0, 40) + '...' : v)})`;
  if (typeof v === 'number') return `${Number.isInteger(v) ? 'a whole number' : 'a number'} (${v})`;
  if (typeof v === 'boolean') return `a boolean (${v})`;
  return 'an object';
}

const article = (word) => (word === 'array' || word === 'object' || word === 'integer' ? `an ${word}` : `a ${word}`);

function matchesType(v, t) {
  switch (t) {
    case 'object': return v !== null && typeof v === 'object' && !Array.isArray(v);
    case 'array': return Array.isArray(v);
    case 'string': return typeof v === 'string';
    case 'number': return typeof v === 'number' && Number.isFinite(v);
    case 'integer': return typeof v === 'number' && Number.isInteger(v);
    case 'boolean': return typeof v === 'boolean';
    case 'null': return v === null;
    default: throw new Error(`schema uses unsupported type "${t}"`);
  }
}

function sortKeys(v) {
  if (Array.isArray(v)) return v.map(sortKeys);
  if (v && typeof v === 'object') return Object.fromEntries(Object.keys(v).sort().map((k) => [k, sortKeys(v[k])]));
  return v;
}
function deepEqual(a, b) {
  return JSON.stringify(sortKeys(a)) === JSON.stringify(sortKeys(b));
}

// ---------- the schema walker ----------

function resolveRef(ref, ctx) {
  const [file, frag] = ref.split('#');
  let root = ctx.root;
  let dir = ctx.dir;
  if (file) {
    const abs = resolve(ctx.dir, file);
    root = loadJsonFile(abs);
    dir = dirname(abs);
  }
  let node = root;
  if (frag) {
    for (const part of frag.split('/').slice(1)) {
      node = node?.[part.replace(/~1/g, '/').replace(/~0/g, '~')];
    }
  }
  if (node === undefined) throw new Error(`schema $ref "${ref}" does not resolve`);
  return { schema: node, ctx: { root, dir } };
}

function walk(schema, value, ptr, ctx, errors) {
  if (schema === true) return;
  if (schema === false) { errors.push(`at ${show(ptr)}: no value is allowed here.`); return; }
  for (const k of Object.keys(schema)) {
    if (!KEYWORDS.has(k) && !ANNOTATIONS.has(k)) {
      throw new Error(`schema keyword "${k}" is not in the supported subset (see the top of validate.mjs)`);
    }
  }
  if (schema.$ref !== undefined) {
    for (const k of Object.keys(schema)) {
      if (k !== '$ref' && !ANNOTATIONS.has(k)) throw new Error(`schema node with $ref may only carry annotations, found "${k}"`);
    }
    const r = resolveRef(schema.$ref, ctx);
    walk(r.schema, value, ptr, r.ctx, errors);
    return;
  }
  const at = `at ${show(ptr)}:`;

  if (schema.type !== undefined) {
    const types = Array.isArray(schema.type) ? schema.type : [schema.type];
    if (!types.some((t) => matchesType(value, t))) {
      const names = types.map(article);
      const want = names.length > 1 ? names.slice(0, -1).join(', ') + ' or ' + names[names.length - 1] : names[0];
      errors.push(`${at} expected ${want} but found ${describe(value)}.`);
      return;
    }
  }
  if (schema.const !== undefined && !deepEqual(value, schema.const)) {
    errors.push(`${at} must be exactly ${JSON.stringify(schema.const)} but found ${JSON.stringify(value)}.`);
  }
  if (schema.enum !== undefined && !schema.enum.some((e) => deepEqual(e, value))) {
    errors.push(`${at} ${JSON.stringify(value)} is not allowed; use one of ${schema.enum.map((e) => JSON.stringify(e)).join(', ')}.`);
    return;
  }
  if (typeof value === 'number') {
    if (schema.minimum !== undefined && value < schema.minimum) errors.push(`${at} ${value} is below the minimum ${schema.minimum}.`);
    if (schema.maximum !== undefined && value > schema.maximum) errors.push(`${at} ${value} is above the maximum ${schema.maximum}.`);
  }
  if (typeof value === 'string') {
    if (schema.minLength !== undefined && value.length < schema.minLength) errors.push(`${at} the string is ${value.length} characters long; it needs at least ${schema.minLength}.`);
    if (schema.maxLength !== undefined && value.length > schema.maxLength) errors.push(`${at} the string is ${value.length} characters long; the limit is ${schema.maxLength}.`);
    if (schema.pattern !== undefined && !new RegExp(schema.pattern).test(value)) {
      const why = schema.description ? `: ${schema.description}` : ` (pattern ${schema.pattern})`;
      errors.push(`${at} ${JSON.stringify(value)} is not valid${why}.`);
    }
  }
  if (Array.isArray(value)) {
    if (schema.minItems !== undefined && value.length < schema.minItems) errors.push(`${at} the list has ${value.length} item${value.length === 1 ? '' : 's'}; it needs at least ${schema.minItems}.`);
    if (schema.maxItems !== undefined && value.length > schema.maxItems) errors.push(`${at} the list has ${value.length} items; the limit is ${schema.maxItems}.`);
    if (schema.items !== undefined) value.forEach((item, i) => walk(schema.items, item, child(ptr, i), ctx, errors));
  }
  if (value !== null && typeof value === 'object' && !Array.isArray(value)) {
    const props = schema.properties ?? {};
    for (const req of schema.required ?? []) {
      if (!(req in value)) errors.push(`at ${show(child(ptr, req))}: required key "${req}" is missing.`);
    }
    for (const [k, v] of Object.entries(value)) {
      if (k in props) {
        walk(props[k], v, child(ptr, k), ctx, errors);
      } else if (schema.additionalProperties === false) {
        const allowed = Object.keys(props);
        errors.push(`at ${show(child(ptr, k))}: unknown key "${k}" is not allowed here; remove it.${allowed.length ? ` Allowed keys: ${allowed.join(', ')}.` : ' No keys are allowed in this object.'}`);
      } else if (schema.additionalProperties && schema.additionalProperties !== true) {
        walk(schema.additionalProperties, v, child(ptr, k), ctx, errors);
      }
    }
  }
}

export function validateAgainstSchema(schema, value, { dir = HERE } = {}) {
  const errors = [];
  walk(schema, value, '', { root: schema, dir }, errors);
  return errors;
}

// ---------- engine checks beyond the schema ----------

const isObj = (v) => v !== null && typeof v === 'object' && !Array.isArray(v);
const WALL_CLOCK = /_(seconds?|secs?|ms|millis|milliseconds|minutes?|mins?|hours?)$/;

function checkParams(params, ptr, limits, errors) {
  if (!isObj(params)) return;
  const keys = Object.keys(params);
  if (keys.length > limits.max_param_keys) {
    errors.push(`at ${show(ptr)}: ${keys.length} parameters; the engine allows at most ${limits.max_param_keys}.`);
  }
  for (const k of keys) {
    const p = child(ptr, k);
    if (!/^[a-z][a-z0-9]*(_[a-z0-9]+)*$/.test(k) || k.length > 40) {
      errors.push(`at ${show(p)}: the parameter name ${JSON.stringify(k)} must be snake_case (lowercase letters and digits separated by single underscores, starting with a letter, at most 40 characters).`);
    } else if (WALL_CLOCK.test(k)) {
      errors.push(`at ${show(p)}: "${k}" counts wall-clock time. Time is physics frames (60 per second): rename it to "${k.replace(WALL_CLOCK, '_frames')}" and convert the number.`);
    } else if (k.endsWith('_frames') && !(Number.isInteger(params[k]) && params[k] >= 0)) {
      errors.push(`at ${show(p)}: "${k}" is a duration in frames and must be a whole number of 0 or more, found ${JSON.stringify(params[k])}.`);
    }
  }
}

// Returns a Map id -> index of first use (also reports duplicates).
function checkUniqueIds(list, ptr, what, errors, idKey = 'id') {
  if (!Array.isArray(list)) return undefined;
  const seen = new Map();
  list.forEach((item, i) => {
    const id = isObj(item) ? item[idKey] : undefined;
    if (typeof id !== 'string') return;
    if (seen.has(id)) {
      errors.push(`at ${show(child(child(ptr, i), idKey))}: duplicate ${what} ${idKey} "${id}"; it is already used at ${show(child(child(ptr, seen.get(id)), idKey))}. The ${idKey}s in this list must be unique.`);
    } else seen.set(id, i);
  });
  return seen;
}

function checkCount(list, max, ptr, what, errors) {
  if (Array.isArray(list) && list.length > max) {
    errors.push(`at ${show(ptr)}: ${list.length} ${what}; the engine allows at most ${max}. Remove ${list.length - max}.`);
  }
}

function checkTunables(tunables, limits, errors) {
  checkCount(tunables, limits.max_tunables, '/tunables', 'tunables', errors);
  checkUniqueIds(tunables, '/tunables', 'tunable', errors, 'key');
  if (!Array.isArray(tunables)) return;
  tunables.forEach((t, i) => {
    if (!isObj(t)) return;
    const p = `/tunables/${i}`;
    const name = typeof t.key === 'string' ? t.key : `#${i}`;
    if (typeof t.key === 'string') {
      if (WALL_CLOCK.test(t.key)) {
        errors.push(`at ${show(child(p, 'key'))}: "${t.key}" counts wall-clock time. Time is physics frames (60 per second): name it "${t.key.replace(WALL_CLOCK, '_frames')}".`);
      } else if (t.key.endsWith('_frames') && t.type !== 'integer') {
        errors.push(`at ${show(child(p, 'type'))}: tunable "${t.key}" is a duration in frames, so its type must be "integer".`);
      }
    }
    const has = (k) => t[k] !== undefined;
    if (t.type === 'number' || t.type === 'integer') {
      if (has('options')) errors.push(`at ${show(child(p, 'options'))}: only enum tunables have options; remove it from "${name}".`);
      for (const k of ['min', 'max']) {
        if (!has(k)) errors.push(`at ${show(child(p, k))}: ${t.type} tunable "${name}" must declare "${k}" so its range is bounded.`);
      }
      if (typeof t.min === 'number' && typeof t.max === 'number' && t.min > t.max) {
        errors.push(`at ${show(child(p, 'min'))}: min ${t.min} is above max ${t.max} for tunable "${name}".`);
      }
      if (t.type === 'integer') {
        for (const k of ['min', 'max']) {
          if (typeof t[k] === 'number' && !Number.isInteger(t[k])) errors.push(`at ${show(child(p, k))}: integer tunable "${name}" needs a whole-number ${k}, found ${t[k]}.`);
        }
      }
      if (has('default')) checkValueAgainst(t, t.default, child(p, 'default'), `the default of tunable "${name}"`, errors);
    } else if (t.type === 'boolean') {
      for (const k of ['min', 'max', 'options']) {
        if (has(k)) errors.push(`at ${show(child(p, k))}: boolean tunable "${name}" must not have "${k}"; remove it.`);
      }
      if (has('default') && typeof t.default !== 'boolean') errors.push(`at ${show(child(p, 'default'))}: the default of boolean tunable "${name}" must be true or false, found ${describe(t.default)}.`);
    } else if (t.type === 'enum') {
      for (const k of ['min', 'max']) {
        if (has(k)) errors.push(`at ${show(child(p, k))}: enum tunable "${name}" must not have "${k}"; remove it.`);
      }
      if (!has('options')) errors.push(`at ${show(child(p, 'options'))}: enum tunable "${name}" must list its options.`);
      else if (Array.isArray(t.options)) {
        if (new Set(t.options).size !== t.options.length) errors.push(`at ${show(child(p, 'options'))}: the options of "${name}" contain a duplicate.`);
        if (has('default') && !t.options.includes(t.default)) errors.push(`at ${show(child(p, 'default'))}: the default ${JSON.stringify(t.default)} of "${name}" is not one of its options (${t.options.join(', ')}).`);
      }
    }
  });
}

// Check one value against a tunable declaration. `label` names the value in the sentence.
function checkValueAgainst(t, v, ptr, label, errors) {
  const name = typeof t.key === 'string' ? t.key : '?';
  if (t.type === 'number' || t.type === 'integer') {
    if (typeof v !== 'number' || !Number.isFinite(v)) {
      errors.push(`at ${show(ptr)}: ${label} must be a ${t.type} but is ${describe(v)}.`);
      return;
    }
    if (t.type === 'integer' && !Number.isInteger(v)) {
      errors.push(`at ${show(ptr)}: ${label} must be a whole number but is ${v}.`);
      return;
    }
    if (typeof t.min === 'number' && typeof t.max === 'number' && t.min > t.max) return; // bad bounds are reported on the tunable itself
    const range = typeof t.min === 'number' && typeof t.max === 'number' ? ` (allowed range ${t.min} to ${t.max})` : '';
    if (typeof t.min === 'number' && v < t.min) errors.push(`at ${show(ptr)}: ${label} is ${v}, below the minimum ${t.min}${range}.`);
    else if (typeof t.max === 'number' && v > t.max) errors.push(`at ${show(ptr)}: ${label} is ${v}, above the maximum ${t.max}${range}.`);
  } else if (t.type === 'boolean') {
    if (typeof v !== 'boolean') errors.push(`at ${show(ptr)}: ${label} must be true or false but is ${describe(v)}.`);
  } else if (t.type === 'enum') {
    if (!Array.isArray(t.options)) return;
    if (typeof v !== 'string' || !t.options.includes(v)) errors.push(`at ${show(ptr)}: ${label} is ${JSON.stringify(v)}, which is not an option of "${name}"; use one of ${t.options.join(', ')}.`);
  }
}

function checkValues(obj, errors) {
  const { values, tunables } = obj;
  if (!isObj(values)) return;
  const byKey = new Map();
  if (Array.isArray(tunables)) for (const t of tunables) if (isObj(t) && typeof t.key === 'string') byKey.set(t.key, t);
  for (const [k, v] of Object.entries(values)) {
    const p = child('/values', k);
    const t = byKey.get(k);
    if (v === null) continue; // the schema check already says null is not allowed
    if (!t) {
      errors.push(`at ${show(p)}: "${k}" is not a declared tunable, so it cannot have a value. Tunable keys are: ${[...byKey.keys()].join(', ') || '(none)'}.`);
      continue;
    }
    checkValueAgainst(t, v, p, `the value of tunable "${k}"`, errors);
  }
}

function collectStrings(v, ptr, out) {
  if (typeof v === 'string') out.push([ptr, v]);
  else if (Array.isArray(v)) v.forEach((x, i) => collectStrings(x, child(ptr, i), out));
  else if (isObj(v)) for (const [k, x] of Object.entries(v)) collectStrings(x, child(ptr, k), out);
}


// ---------- hockey game object checks (cross-field; ranges and enums are in game.schema.json) ----------

// The engine applies the defaults for absent keys (schema/DEFAULTS.md). This validator only checks what is written.
const SPAWN_MARGIN_M = 0.5; // a skater stands at least this far from the boards
const DEFAULT_CORNER_M = 5; // used only to check positions when corner_radius_m is absent (see DEFAULTS.md)

function insideRink(x, z, length, width, corner) {
  const hx = length / 2 - SPAWN_MARGIN_M;
  const hz = width / 2 - SPAWN_MARGIN_M;
  if (Math.abs(x) > hx || Math.abs(z) > hz) return false;
  const r = Math.max(0, Math.min(corner - SPAWN_MARGIN_M, hx, hz));
  const dx = Math.abs(x) - (hx - r);
  const dz = Math.abs(z) - (hz - r);
  return !(dx > 0 && dz > 0 && dx * dx + dz * dz > r * r);
}

// C-0005 section 4 (lane A14). The five built-in pickup kinds are shipped effect definitions (Game/Content/Designer/builtin-effects.json).
export const BUILTIN_EFFECTS = ['speed', 'precision', 'heavy_puck', 'big_puck', 'reverse_other'];
// EJamStat (snake_case) -> the game field whose schema range clamps it; add must stay within the range width. Mirrored in C++ (JamCartridge.cpp CheckGame and JamCore/Effects).
export const EFFECT_STAT_FIELD = {
  skater_speed: 'skater.speed', skater_accel: 'skater.accel', skater_turn_rate: 'skater.turn_rate', skater_grip: 'skater.lateral_grip', skater_mass: 'skater.mass',
  shot_speed: 'shot.speed', shot_aim_cone_deg: 'shot.aim_cone_deg', shot_reach: 'shot.reach_m', check_speed_min: 'skater.check_speed_min', knockdown_frames: 'skater.knockdown_frames',
  puck_drag: 'puck.drag', puck_max_speed: 'puck.max_speed', puck_radius: 'puck.radius_m', ice_friction: 'rink.ice_friction', board_restitution: 'rink.board_restitution',
};
// shot_aim_cone_deg: the seam (JamModifiers.h JamStats::Range) clamps to 0..45 because absent = 0 = no aim help; the field's own range starts at 1.
const EFFECT_STAT_RANGE = Object.fromEntries(Object.entries(EFFECT_STAT_FIELD).map(([stat, field]) => [stat, stat === 'shot_aim_cone_deg' ? [0, 45] : String(loadLimits().game_ranges[field]).split('..').map(Number)]));

function checkGame(game, errors) {
  if (!isObj(game)) return;
  const rink = isObj(game.rink) ? game.rink : {};
  const L = rink.length_m;
  const W = rink.width_m;
  const haveSize = typeof L === 'number' && typeof W === 'number';
  const corner = typeof rink.corner_radius_m === 'number' ? rink.corner_radius_m : DEFAULT_CORNER_M;

  if (haveSize && typeof rink.corner_radius_m === 'number' && rink.corner_radius_m > Math.min(L, W) / 2) {
    errors.push(`at /game/rink/corner_radius_m: ${rink.corner_radius_m} is more than half of the shorter rink side (${Math.min(L, W) / 2}); lower it.`);
  }
  if (haveSize && typeof rink.goal_width_m === 'number' && rink.goal_width_m >= W) {
    errors.push(`at /game/rink/goal_width_m: the net (${rink.goal_width_m} m) must be narrower than the rink (${W} m).`);
  }
  if (haveSize && Array.isArray(rink.obstacles)) {
    rink.obstacles.forEach((o, i) => {
      if (isObj(o) && typeof o.x === 'number' && typeof o.z === 'number' && !insideRink(o.x, o.z, L, W, corner)) {
        errors.push(`at /game/rink/obstacles/${i}: the obstacle at [${o.x}, ${o.z}] is outside the rink (x within ${-L / 2} to ${L / 2}, z within ${-W / 2} to ${W / 2}, allowing ${SPAWN_MARGIN_M} m for the boards and the rounded corners).`);
      }
    });
  }

  // C-0005 (lane A15): zones sit inside the rink and carry the size their shape needs.
  if (Array.isArray(rink.zones)) {
    checkUniqueIds(rink.zones, '/game/rink/zones', 'zone', errors);
    rink.zones.forEach((z, i) => {
      if (!isObj(z)) return;
      const p = `/game/rink/zones/${i}`;
      if (haveSize && typeof z.x === 'number' && typeof z.z === 'number' && !insideRink(z.x, z.z, L, W, corner)) {
        errors.push(`at ${p}: the zone centre [${z.x}, ${z.z}] is outside the rink (x within ${-L / 2} to ${L / 2}, z within ${-W / 2} to ${W / 2}, allowing ${SPAWN_MARGIN_M} m for the boards and the rounded corners).`);
      }
      if (z.shape === 'rect') {
        if (z.w === undefined) errors.push(`at ${p}/w: a rect zone needs w (its length along the rink, 1 to 160 m).`);
        if (z.d === undefined) errors.push(`at ${p}/d: a rect zone needs d (its depth across the rink, 1 to 80 m).`);
        if (z.r !== undefined) errors.push(`at ${p}/r: a rect zone has no radius; remove r or make the shape circle.`);
      } else if (z.shape === 'circle') {
        if (z.r === undefined) errors.push(`at ${p}/r: a circle zone needs r (its radius, 0.5 to 40 m).`);
        if (z.w !== undefined || z.d !== undefined) errors.push(`at ${p}: a circle zone has no w or d; remove them or make the shape rect.`);
      }
    });
  }

  const rules = isObj(game.rules) ? game.rules : {};
  if (Array.isArray(rules.hooks)) {
    checkUniqueIds(rules.hooks, '/game/rules/hooks', 'hook', errors);
    rules.hooks.forEach((h, i) => isObj(h) && checkHook(h, `/game/rules/hooks/${i}`, errors));
  }
  if (rules.mode === 'first_to' && rules.score_to_win === undefined) {
    errors.push('at /game/rules/score_to_win: mode "first_to" needs score_to_win (1 to 9).');
  }
  if (rules.mode === 'timer' && rules.timer_frames === undefined) {
    errors.push('at /game/rules/timer_frames: mode "timer" needs timer_frames (600 to 28800 frames, 60 per second).');
  }

  const sk = isObj(game.skater) ? game.skater : {};
  if (typeof sk.check_speed_min === 'number' && typeof sk.speed === 'number' && sk.check_speed_min > sk.speed) {
    errors.push(`at /game/skater/check_speed_min: ${sk.check_speed_min} is above the skater's top speed ${sk.speed}, so no check could ever land; lower it.`);
  }

  // C-0005 (lane A14): effects reference known stats only (the enum does that), ids are unique and never a built-in kind,
  // an add stays within the width of its stat's range, zone refers to a rink.zones id; a pickup names a built-in or a declared effect.
  const zoneIds = new Set(Array.isArray(rink.zones) ? rink.zones.filter((z) => isObj(z) && typeof z.id === 'string').map((z) => z.id) : []);
  const zoneList = () => (zoneIds.size ? `Zones are: ${[...zoneIds].join(', ')}.` : 'There are no zones in game.rink.zones.');
  const effectIds = new Set();
  if (Array.isArray(game.effects)) {
    checkUniqueIds(game.effects, '/game/effects', 'effect', errors);
    game.effects.forEach((e, i) => {
      if (!isObj(e)) return;
      if (typeof e.id === 'string') {
        if (BUILTIN_EFFECTS.includes(e.id)) errors.push(`at /game/effects/${i}/id: "${e.id}" is a built-in effect; a custom effect needs another id (the built-ins are ${BUILTIN_EFFECTS.map((b) => `"${b}"`).join(', ')}).`);
        else effectIds.add(e.id);
      }
      if (Array.isArray(e.stats)) {
        e.stats.forEach((st, j) => {
          if (!isObj(st) || typeof st.add !== 'number' || !(st.stat in EFFECT_STAT_RANGE)) return;
          const [lo, hi] = EFFECT_STAT_RANGE[st.stat];
          if (Math.abs(st.add) > hi - lo) errors.push(`at /game/effects/${i}/stats/${j}/add: ${st.add} is more than the width of the ${st.stat} range (${lo} to ${hi}, width ${hi - lo}); keep add within ${-(hi - lo)} to ${hi - lo}.`);
        });
      }
      if (typeof e.zone === 'string' && !zoneIds.has(e.zone)) errors.push(`at /game/effects/${i}/zone: "${e.zone}" is not the id of any zone. ${zoneList()}`);
      if (typeof e.zone === 'string' && e.trigger !== undefined && e.trigger !== 'zone_enter' && e.trigger !== 'zone_exit') errors.push(`at /game/effects/${i}/zone: zone only applies to the triggers "zone_enter" and "zone_exit", not "${e.trigger}"; remove it or change the trigger.`);
    });
  }
  if (Array.isArray(game.pickups)) {
    game.pickups.forEach((p, i) => {
      if (!isObj(p)) return;
      if (typeof p.duration_frames === 'number' && !(p.duration_frames > 0)) {
        errors.push(`at /game/pickups/${i}/duration_frames: a pickup effect must last at least 1 frame, found ${p.duration_frames}.`);
      }
      if (typeof p.kind === 'string' && !BUILTIN_EFFECTS.includes(p.kind) && !effectIds.has(p.kind)) {
        errors.push(`at /game/pickups/${i}/kind: "${p.kind}" is not allowed: use a built-in (${BUILTIN_EFFECTS.map((b) => `"${b}"`).join(', ')}) or the id of an effect declared in game.effects (declared: ${effectIds.size ? [...effectIds].join(', ') : 'none'}).`);
      }
      if (typeof p.zone === 'string' && !zoneIds.has(p.zone)) errors.push(`at /game/pickups/${i}/zone: "${p.zone}" is not the id of any zone. ${zoneList()}`);
    });
  }

  // Lane A84 (R-0041 point 3): one mode ability at most (F is one key); a pickup ability needs pickups to arrive by.
  if (Array.isArray(game.abilities)) {
    let modes = 0;
    game.abilities.forEach((a, i) => {
      if (!isObj(a)) return;
      if (a.trigger === 'mode' && ++modes > 1) errors.push(`at /game/abilities/${i}/trigger: only one ability may have trigger "mode" (F is one key); make this one "pickup" or remove it.`);
      if (a.trigger === 'pickup' && !(Array.isArray(game.pickups) && game.pickups.length > 0)) errors.push(`at /game/abilities/${i}/trigger: a "pickup" ability is granted by a boost take, but game.pickups is empty; add a pickup or use trigger "mode".`);
    });
  }

  if (Array.isArray(game.teams)) {
    checkUniqueIds(game.teams, '/game/teams', 'team', errors);
    const colours = game.teams.map((t) => (isObj(t) && typeof t.colour_hex === 'string' ? t.colour_hex.toLowerCase() : undefined));
    if (colours.length === 2 && colours[0] && colours[0] === colours[1]) {
      errors.push('at /game/teams/1/colour_hex: both teams have the same jersey colour; players could not tell them apart.');
    }
    const players = [];
    const spawns = [];
    game.teams.forEach((t, ti) => {
      if (!isObj(t) || !Array.isArray(t.skaters)) return;
      t.skaters.forEach((s, si) => {
        if (!isObj(s)) return;
        const p = `/game/teams/${ti}/skaters/${si}`;
        if (s.role === 'player') players.push(`${p}/role`);
        if (Array.isArray(s.spawn) && s.spawn.length === 2 && s.spawn.every((n) => typeof n === 'number')) {
          const [x, z] = s.spawn;
          if (haveSize && !insideRink(x, z, L, W, corner)) {
            errors.push(`at ${p}/spawn: the spawn [${x}, ${z}] is outside the rink (x within ${-(L / 2 - SPAWN_MARGIN_M)} to ${L / 2 - SPAWN_MARGIN_M}, z within ${-(W / 2 - SPAWN_MARGIN_M)} to ${W / 2 - SPAWN_MARGIN_M}, and inside the rounded corners). Move it toward the centre or enlarge the rink.`);
          }
          for (const o of spawns) {
            if (Math.hypot(o.x - x, o.z - z) < 1) errors.push(`at ${p}/spawn: the spawn [${x}, ${z}] is less than 1 m from the spawn at ${o.p}; skaters would start inside each other.`);
          }
          spawns.push({ x, z, p: `${p}/spawn` });
        }
      });
    });
    if (players.length !== 1) {
      const where = players.length ? ` (found at ${players.join(', ')})` : '';
      errors.push(`at /game/teams: exactly one skater across both teams must have role "player", found ${players.length}${where}.`);
    }
  }
}

// C-0005 (lane A15): what each trigger and action needs beyond the schema. Mirrored by JamValidate::CheckHook in JamCartridge.cpp.
const ACTION_NEEDS = {
  add_score: ['value'], set_score_multiplier: ['value'], shrink_rink: ['value'], grow_rink: ['value'],
  set_param: ['param', 'value'], spawn_pickup: ['kind'], apply_modifier: ['kind', 'frames'], announce: ['text'],
};
// Lane A118 (track S3): the tunables a hook's set_param may name and the game field whose schema range (limits.json game_ranges) bounds its value.
// The eight keys (nine before lane A141) of the loader's `values` map onto game fields (README "Tunables"; C++ UJamCartridge::ApplyValueKey and SetParamRange). A name outside this
// list, or a value outside the field's range, is an error in both validators; the sim clamps as well (UJamSim::SetParam), for callers that bypass the validator.
export const SET_PARAM_FIELD = {
  skater_speed: 'skater.speed', skater_turn_rate: 'skater.turn_rate', shot_speed: 'shot.speed', puck_max_speed: 'puck.max_speed',
  ice_friction: 'rink.ice_friction', board_restitution: 'rink.board_restitution', ai_speed_scale: 'ai.speed_scale', ai_red_skill: 'ai.red_skill',
};
// Lane A141: goal_pause_frames (30..600) is no set_param tunable: a hook value is -20..20, so no value could ever be valid; the validators name eight tunables. The sim still clamps it (UJamCartridge::SetParamRange) for callers that bypass them.
export function setParamRange(param) {
  const field = Object.hasOwn(SET_PARAM_FIELD, param) ? SET_PARAM_FIELD[param] : undefined;
  return field ? String(loadLimits().game_ranges[field]).split('..').map(Number) : undefined;
}
function checkHook(h, ptr, errors) {
  if (h.when === 'on_frame' && h.every_frames === undefined) errors.push(`at ${ptr}/every_frames: a hook with when "on_frame" needs every_frames (60 to 18000 frames, 60 per second).`);
  if (typeof h.when === 'string' && h.when !== 'on_frame' && h.every_frames !== undefined) errors.push(`at ${ptr}/every_frames: every_frames only applies to when "on_frame"; remove it.`);
  if (h.when === 'on_score_reached' && !(isObj(h.score) && h.score.at_least !== undefined)) errors.push(`at ${ptr}/score: a hook with when "on_score_reached" needs score.at_least (the score that triggers it).`);
  if (isObj(h.score) && typeof h.score.at_least === 'number' && typeof h.score.at_most === 'number' && h.score.at_least > h.score.at_most) {
    errors.push(`at ${ptr}/score/at_least: at_least ${h.score.at_least} is above at_most ${h.score.at_most}; no score could ever match.`);
  }
  if (!Array.isArray(h.then)) return;
  h.then.forEach((a, j) => {
    if (!isObj(a) || typeof a.do !== 'string') return;
    const p = `${ptr}/then/${j}`;
    for (const k of ACTION_NEEDS[a.do] ?? []) {
      if (a[k] === undefined) errors.push(`at ${p}/${k}: the action "${a.do}" needs ${k}.`);
    }
    if (typeof a.value === 'number') {
      if (a.do === 'add_score' && !Number.isInteger(a.value)) errors.push(`at ${p}/value: add_score adds whole goals; ${a.value} is not a whole number.`);
      if (a.do === 'set_score_multiplier' && (a.value < 1 || a.value > 5)) errors.push(`at ${p}/value: a score multiplier is 1 to 5, found ${a.value}.`);
      if ((a.do === 'shrink_rink' || a.do === 'grow_rink') && (a.value < 0.05 || a.value > 0.5)) errors.push(`at ${p}/value: ${a.do} takes the fraction to change the rink by, 0.05 to 0.5 (0.1 is 10 percent), found ${a.value}.`);
    }
    // Lane A118: set_param names one of the nine tunables and stays inside its field's range.
    if (a.do === 'set_param' && typeof a.param === 'string') {
      const range = setParamRange(a.param);
      if (!range) errors.push(`at ${p}/param: set_param can change ${Object.keys(SET_PARAM_FIELD).join(', ')}; "${a.param}" is none of them.`);
      else if (typeof a.value === 'number' && (a.value < range[0] || a.value > range[1])) errors.push(`at ${p}/value: ${a.param} lies within ${range[0]} to ${range[1]} (the range of game.${SET_PARAM_FIELD[a.param]}), found ${a.value}.`);
    }
  });
}

// True when a hook can end the match before physics frame 600 (10 seconds): the Designer may not write such a hook.
// A hook is safe when it is armed after frame 600, fires on a frame cadence of at least 600, waits for a period to end,
// or needs a second goal (at_least or lead_at_least of 2 or more).
export function hookEndsMatchEarly(h) {
  if (!isObj(h) || !Array.isArray(h.then) || !h.then.some((a) => isObj(a) && a.do === 'end_match')) return false;
  if (typeof h.after_frame === 'number' && h.after_frame >= 600) return false;
  if (h.when === 'on_frame' && typeof h.every_frames === 'number' && h.every_frames >= 600) return false;
  if (h.when === 'on_period_end') return false;
  const s = isObj(h.score) ? h.score : {};
  if ((typeof s.at_least === 'number' && s.at_least >= 2) || (typeof s.lead_at_least === 'number' && s.lead_at_least >= 2)) return false;
  return true;
}

// The loader's expansion of game.rules.variants into hooks (the C++ mirror is ExpandVariants in JamCartridge.cpp; the
// test rules.test.mjs keeps the two in step through the hockey.chaos preset). Returns the hooks the variants add, in order.
export function expandVariants(game) {
  const out = [];
  if (!isObj(game) || !isObj(game.rules) || !isObj(game.rules.variants)) return out;
  const v = game.rules.variants;
  const rules = game.rules;
  if (v.sudden_death === true) {
    out.push({ id: 'variant-sudden-death', when: 'on_goal', after_frame: 600, team: 'scoring',
      then: [{ do: 'end_match', team: 'scoring' }, { do: 'announce', text: 'SUDDEN DEATH: that goal wins it' }] });
  }
  if (v.last_goal_double === true && rules.mode === 'first_to' && Number.isInteger(rules.score_to_win)) {
    out.push({ id: 'variant-last-goal-double', when: 'on_goal', team: 'scoring', score: { at_least: rules.score_to_win },
      then: [{ do: 'add_score', team: 'scoring', value: 1 }, { do: 'announce', text: 'LAST GOAL COUNTS DOUBLE' }] });
  }
  if (Number.isInteger(v.mercy_goals)) {
    out.push({ id: 'variant-mercy', when: 'on_goal', team: 'scoring', score: { lead_at_least: v.mercy_goals },
      then: [{ do: 'end_match', team: 'scoring' }, { do: 'announce', text: `MERCY: a lead of ${v.mercy_goals} ends it` }] });
  }
  if (Number.isInteger(v.period_count) && v.period_count > 1) {
    const every = rules.mode === 'timer' && Number.isInteger(rules.timer_frames) ? Math.max(60, Math.floor(rules.timer_frames / v.period_count)) : 3600;
    out.push({ id: 'variant-periods', when: 'on_frame', every_frames: every, team: 'any', then: [{ do: 'end_period' }] });
  }
  if (typeof v.shrink_per_goal === 'number') {
    out.push({ id: 'variant-shrink-per-goal', when: 'on_goal', team: 'any',
      then: [{ do: 'shrink_rink', value: v.shrink_per_goal }, { do: 'announce', text: `THE RINK SHRINKS ${Math.round(v.shrink_per_goal * 100)}%` }] });
  }
  return out;
}

function checkEngine(obj, limits, errors) {
  if (!isObj(obj)) return;
  checkGame(obj.game, errors);
  const size = JSON.stringify(obj).length;
  if (size > limits.max_json_bytes) errors.push(`at /: the cartridge is ${size} characters; the engine allows at most ${limits.max_json_bytes}. Shorten lists and text.`);

  checkTunables(obj.tunables, limits, errors);
  checkValues(obj, errors);

  checkCount(obj.rules, limits.max_rules, '/rules', 'rules', errors);
  checkUniqueIds(obj.rules, '/rules', 'rule', errors);
  if (Array.isArray(obj.rules)) obj.rules.forEach((r, i) => isObj(r) && checkParams(r.params, `/rules/${i}/params`, limits, errors));

  checkCount(obj.entities, limits.max_entities, '/entities', 'entities', errors);
  const entityIds = checkUniqueIds(obj.entities, '/entities', 'entity', errors);
  if (Array.isArray(obj.entities)) {
    let total = 0;
    obj.entities.forEach((e, i) => {
      if (!isObj(e)) return;
      total += Number.isInteger(e.count) ? e.count : 1;
      checkParams(e.params, `/entities/${i}/params`, limits, errors);
    });
    if (total > limits.max_total_entity_instances) {
      errors.push(`at /entities: the counts add up to ${total} entity instances; the engine allows at most ${limits.max_total_entity_instances}. Lower some "count" values or remove entities.`);
    }
  }

  checkCount(obj.ai, limits.max_ai, '/ai', 'ai behaviours', errors);
  checkUniqueIds(obj.ai, '/ai', 'ai behaviour', errors);
  if (Array.isArray(obj.ai)) {
    obj.ai.forEach((a, i) => {
      if (!isObj(a)) return;
      checkParams(a.params, `/ai/${i}/params`, limits, errors);
      if (Array.isArray(a.applies_to) && entityIds) {
        a.applies_to.forEach((ref, j) => {
          if (typeof ref === 'string' && !entityIds.has(ref)) {
            errors.push(`at /ai/${i}/applies_to/${j}: "${ref}" is not the id of any entity. Entity ids are: ${[...entityIds.keys()].join(', ') || '(none)'}.`);
          }
        });
      }
    });
  }

  if (isObj(obj.theme)) {
    checkCount(obj.theme.palette, limits.max_palette, '/theme/palette', 'palette colours', errors);
    checkCount(obj.theme.mood_words, limits.max_mood_words, '/theme/mood_words', 'mood words', errors);
    checkUniqueIds(obj.theme.palette, '/theme/palette', 'palette colour', errors, 'name');
  }

  if (Array.isArray(limits.blocked_terms) && limits.blocked_terms.length) {
    const strings = [];
    collectStrings(obj, '', strings);
    for (const [p, s] of strings) {
      const low = s.toLowerCase();
      const hit = limits.blocked_terms.find((t) => low.includes(String(t).toLowerCase()));
      if (hit) errors.push(`at ${show(p)}: the text contains a term that is not allowed in this game ("${hit}"). Reword it.`);
    }
  }
}

// ---------- public API ----------

// Lane A118: a cartridge's text, parsed as the C++ loader parses it (UJamCartridge::Validate / LoadFromString), then validated.
export function validateCartridgeText(text, opts = {}) {
  const strict = parseStrict(text);
  if (strict.error) return { ok: false, errors: [strict.error] };
  return validateCartridge(strict.value, opts);
}

export function validateCartridge(obj, opts = {}) {
  const limits = opts.limits ?? loadLimits();
  const schema = opts.schema ?? loadJsonFile(SCHEMA_FILE);
  const errors = validateAgainstSchema(schema, obj, { dir: opts.dir ?? HERE });
  checkEngine(obj, limits, errors);
  return { ok: errors.length === 0, errors: [...new Set(errors)] };
}

// What the Designer must leave exactly as the host gave it. `game` is compared separately, see below.
export const DESIGNER_IMMUTABLE = ['schema', 'id', 'title', 'seed', 'tunables', 'game'];
// What it may edit: values, theme, the contents of rules, entities and ai, and the game paths listed below.
export const DESIGNER_EDITABLE = ['values', 'theme', 'rules', 'entities', 'ai'];
// Paths inside `game` the Designer may change (HOCKEY.md section 4). Everything else in `game`, notably
// teams[].skaters[].role and camera.mode, stays exactly as the host gave it.
export const DESIGNER_GAME_EDITABLE = [
  'rink.length_m', 'rink.width_m', 'rink.corner_radius_m', 'rink.board_restitution', 'rink.ice_friction',
  'rink.goal_width_m', 'rink.goal_height_m', 'rink.obstacles',
  'pickups', 'effects',
  'rules.mode', 'rules.score_to_win', 'rules.timer_frames',
  // C-0005 (lane A15): rule hooks, variants and zones are the Designer's parts too, within the limits and the frame-600 guard
  'rules.hooks', 'rules.variants', 'rink.zones',
  'look.tier',
  'ai.difficulty',
  'barks',
  // Lane A44 (tonight's keys): the three payoffs as whole objects (A39, PAYOFFS.md section 2), the foul grace (A16, R-0029 point 3), the booth (A32),
  // the board trim glow and the broadcast tier (A21 / A31, through look.tier), the three chase-camera numbers (A40). camera.mode and the rest of
  // camera, skater, shot and stick stay the host's.
  'shot.one_timer', 'skater.breakaway', 'stick.deke', 'stick.foul_grace_frames',
  'commentary',
  'look.trim_emissive',
  'camera.boards_margin_m', 'camera.end_height_m', 'camera.far_net_bias',
];

function withoutPaths(game, paths) {
  const copy = JSON.parse(JSON.stringify(game));
  for (const path of paths) {
    const parts = path.split('.');
    let node = copy;
    for (const p of parts.slice(0, -1)) node = isObj(node) ? node[p] : undefined;
    if (isObj(node)) delete node[parts.at(-1)];
    // lane A3: an object emptied by the removal counts as absent, so adding or removing `ai` around `difficulty` is not a change
    if (parts.length === 2 && isObj(copy[parts[0]]) && Object.keys(copy[parts[0]]).length === 0) delete copy[parts[0]];
  }
  return copy;
}

export function validateDesignerOutput(base, out, opts = {}) {
  const res = validateCartridge(out, opts);
  const errors = [...res.errors];
  if (isObj(base) && isObj(out)) {
    for (const k of DESIGNER_IMMUTABLE) {
      if (k === 'game') continue;
      if (k in base && k in out && !deepEqual(base[k], out[k])) {
        errors.push(`at ${show(child('', k))}: the Designer may not change "${k}". Restore it exactly as it was in the current cartridge. Only ${DESIGNER_EDITABLE.join(', ')} (and some of "game") may change.`);
      }
    }
    if (isObj(base.game) && isObj(out.game)) {
      const a = withoutPaths(base.game, DESIGNER_GAME_EDITABLE);
      const b = withoutPaths(out.game, DESIGNER_GAME_EDITABLE);
      if (!deepEqual(a, b)) {
        const diff = [];
        const find = (x, y, ptr) => {
          if ((isObj(x) && isObj(y)) || (Array.isArray(x) && Array.isArray(y) && x.length === y.length)) for (const k of new Set([...Object.keys(x), ...Object.keys(y)])) find(x[k], y[k], child(ptr, k));
          else if (!deepEqual(x, y)) diff.push(ptr);
        };
        find(a, b, '/game');
        for (const ptr of diff) errors.push(`at ${ptr}: the Designer may not change this part of "game". Restore it exactly as it was. In "game" only these may change: ${DESIGNER_GAME_EDITABLE.join(', ')}.`);
      }
    } else if ('game' in base && !deepEqual(base.game, out.game)) {
      errors.push('at /game: the Designer may not change "game" as a whole. Restore it exactly as it was.');
    }
    // C-0005 (lane A15): the Designer may not create a hook that ends the match before frame 600 (10 seconds).
    const hooks = isObj(out.game) && isObj(out.game.rules) && Array.isArray(out.game.rules.hooks) ? out.game.rules.hooks : [];
    hooks.forEach((h, i) => {
      if (hookEndsMatchEarly(h)) errors.push(`at /game/rules/hooks/${i}: this hook could end the match before frame 600 (10 seconds). Add "after_frame": 600, make it wait for a second goal (score.at_least or lead_at_least of 2), or fire it on_period_end.`);
    });
  }
  return { ok: errors.length === 0, errors: [...new Set(errors)] };
}

// Turn the model's raw reply text into one of: a cartridge, a refusal, or a list of errors.
// Strict on purpose: JSON only, no prose, no markdown fence.
export function parseDesignerReply(text, base, opts = {}) {
  const limits = opts.limits ?? loadLimits();
  const raw = typeof text === 'string' ? text : '';
  const trimmed = raw.trim();
  if (!trimmed) return { kind: 'invalid', errors: ['at /: the reply is empty. Return a JSON object: the full cartridge, or {"refusal": "<reason>"}.'] };
  // Lane A141: the strict parser the C++ mirror uses (FJamJson::Parse): a duplicate key, a number past double range, nesting past 64 or text after the
  // object is refused with the same words, and the message nests the parser's own error exactly as JamDesignerPrompt.cpp ParseReply does.
  const strict = parseStrict(trimmed);
  if (strict.error) {
    const head = trimmed.length > 40 ? `${trimmed.slice(0, 40)}...` : trimmed;
    const wrapped = !trimmed.startsWith('{') && trimmed.includes('{');
    return {
      kind: 'invalid',
      errors: [wrapped
        ? `at /: the reply has text outside the JSON object (it starts with ${JSON.stringify(head)}). Return only the JSON object: no sentence before or after it and no markdown fence.`
        : `at /: the reply is not valid JSON (${strict.error}). Return only one complete JSON object.`],
    };
  }
  const parsed = strict.value;
  if (!isObj(parsed)) return { kind: 'invalid', errors: [`at /: the reply must be a JSON object but is ${describe(parsed)}.`] };
  if ('refusal' in parsed) {
    const errors = [];
    if (Object.keys(parsed).length !== 1) errors.push('at /: a refusal must be exactly {"refusal": "<reason>"} with no other keys.');
    if (typeof parsed.refusal !== 'string' || parsed.refusal.trim() === '') errors.push('at /refusal: the reason must be a non-empty string.');
    else if (parsed.refusal.length > limits.max_refusal_chars) errors.push(`at /refusal: the reason is ${parsed.refusal.length} characters; the limit is ${limits.max_refusal_chars}.`);
    return errors.length ? { kind: 'invalid', errors } : { kind: 'refusal', refusal: parsed.refusal };
  }
  const res = base ? validateDesignerOutput(base, parsed, opts) : validateCartridge(parsed, opts);
  return res.ok ? { kind: 'cartridge', cartridge: parsed } : { kind: 'invalid', errors: res.errors };
}

// ---------- CLI ----------

function cli(argv) {
  const args = argv.slice(2);
  const baseIdx = args.indexOf('--base');
  let basePath;
  if (baseIdx !== -1) { basePath = args[baseIdx + 1]; args.splice(baseIdx, 2); }
  const file = args[0];
  if (!file) {
    console.error('usage: node schema/validate.mjs file.json [--base current.json]');
    return 2;
  }
  let text;
  let base;
  try {
    text = readFileSync(file, 'utf8');
    if (basePath) base = JSON.parse(readFileSync(basePath, 'utf8'));
  } catch (e) {
    console.error(`cannot read input: ${e.message}`);
    return 2;
  }
  let errors;
  try {
    // Lane A118: the strict parser both sides share (duplicate keys refused, a byte order mark tolerated, the C++ loader's pointers).
    const strict = parseStrict(text);
    if (strict.error) throw Object.assign(new SyntaxError(strict.error), { strict: true });
    const parsed = strict.value;
    errors = (base ? validateDesignerOutput(base, parsed) : validateCartridge(parsed)).errors;
  } catch (e) {
    if (e instanceof SyntaxError) errors = [e.strict ? e.message : `at /: the file is not valid JSON (${e.message}).`];
    else { console.error(`validator could not run: ${e.message}`); return 2; }
  }
  if (errors.length === 0) console.log(`PASS ${file}`);
  else { console.log(`FAIL ${file}`); for (const e of errors) console.log(`  ${e}`); }
  console.log(JSON.stringify({ tool: 'validate', file, ok: errors.length === 0, errors: errors.length }));
  return errors.length === 0 ? 0 : 1;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  // A *.ladder.json file is a season (lane A17, C-0005 game.ladder): schema/ladder.mjs validates it and its take cartridges.
  if (/\.ladder\.json$/.test(process.argv[2] ?? '')) import('./ladder.mjs').then((m) => { process.exitCode = m.ladderCli(process.argv); });
  else process.exitCode = cli(process.argv);
}
