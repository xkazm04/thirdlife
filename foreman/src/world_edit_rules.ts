// M6 lane C (27 Nov 2026): the checks of the M6 ops `zone`, `unzone`, `rule` and `unrule` in an LLM answer
// (contracts/BUILD.md "Milestone 6: rules and runs" and "The LLM command bar, M6 additions"), word for word as the exe's
// rules layer holds them (engine/kernel/world/build/rules_check.gd shapes, rules_layer.gd `can_apply`), so a refusal is
// fed back to the model (world_edit.ts, 2 attempts) instead of being counted refused in the ghost. Ids are the answer's
// own: the exe gives each new zone and rule the next free id (rules_layer.gd `renumber`), so a reference resolves as
// renumber does: an id some `zone` op of the answer makes names that zone (which must come before the rule naming it,
// as ops apply in order); any other id names a zone of the ask's `zones` (the Home's, in the region). `unzone` and
// `unrule` name what is there and carry it whole. The space checks (floating blocks, a pad with no floor, a finish out
// of reach) are the exe's, shown with the ghost: they never refuse (command_space.gd).
import type { Ask, ModelOp } from "./world_edit_check.js";

export const LOOKS = ["none", "pad", "coin", "flag"];
export const LIMITS = { side: 64, yMin: -16, yMax: 111, name: 24, text: 60, counters: 8, counter: 999, do: 8, if: 8, zones: 512, rules: 512 };
/** Each trigger's keys besides "on" and each effect's keys besides "do", in the contract's order (rules_check.gd). */
export const TRIGGERS: Record<string, string[]> = { enter: ["zone"], leave: ["zone"], use: ["zone"], every: ["frames"], count: ["counter", "at"], start: [], finish: [] };
export const EFFECTS: Record<string, string[]> = {
  start: ["run"], checkpoint: ["zone"], finish: [], respawn: [], add: ["counter", "by"], take: ["zone"], open: ["zone"],
  close: ["zone"], toggle: ["zone"], launch: ["up_cm", "fwd_cm"], teleport: ["zone"], say: ["text", "frames"],
};

type Obj = Record<string, unknown>;
type Box = [[number, number, number], [number, number, number]];
const isInt = (v: unknown): v is number => typeof v === "number" && Number.isInteger(v);
const isObj = (v: unknown): v is Obj => typeof v === "object" && v !== null && !Array.isArray(v);
const inRange = (v: unknown, lo: number, hi: number) => isInt(v) && v >= lo && v <= hi;
export const counterOk = (c: unknown) => typeof c === "string" && /^[a-z_]{1,16}$/.test(c);
/** 1-`most` characters, none a control character (C0, DEL, C1): rules_check.gd `printable`. */
export const printable = (s: unknown, most: number) =>
  typeof s === "string" && s.length >= 1 && s.length <= most && ![...s].some((ch) => { const u = ch.codePointAt(0) as number; return u < 32 || (u >= 127 && u < 160); });

/** A zone or rule in its saved form with keys in the contract's order (rules_check.gd `zone_of`, `rule_of`), as text. */
export function canonZone(z: Obj): string {
  return JSON.stringify({ id: z.id, box: z.box, look: z.look, ...(z.name !== undefined ? { name: z.name } : {}) });
}
export function canonRule(r: Obj): string {
  const order = (o: Obj, keys: string[], head: string) => Object.fromEntries([head, ...keys].filter((k) => o[k] !== undefined).map((k) => [k, o[k]]));
  const w = r.when as Obj;
  const conds = Array.isArray(r.if) ? (r.if as Obj[]).map((c) => (c.running !== undefined ? { running: c.running } : order(c, ["min", "max"], "counter"))) : undefined;
  return JSON.stringify({ id: r.id, when: order(w, TRIGGERS[w.on as string] ?? [], "on"), ...(conds ? { if: conds } : {}),
    do: (r.do as Obj[]).map((e) => order(e, EFFECTS[e.do as string] ?? [], "do")) });
}

/** "" or why `w` is not one trigger (rules_check.gd `trigger_error`); `zone` checks a zone reference. */
function triggerError(w: unknown, zone: (z: unknown) => string): string {
  if (!isObj(w)) return 'when must be one trigger {"on": ...}';
  const on = w.on;
  if (typeof on !== "string" || !Object.hasOwn(TRIGGERS, on)) return `when: on must be one of ${Object.keys(TRIGGERS).join(", ")}`;
  const keys = TRIGGERS[on] as string[];
  const extra = Object.keys(w).filter((k) => k !== "on" && !keys.includes(k));
  if (extra.length) return `when: "${on}" takes no "${extra[0]}" (it takes ${keys.length ? keys.join(", ") : "nothing else"})`;
  const missing = keys.find((k) => w[k] === undefined);
  if (missing) return `when: "${on}" needs ${missing}`;
  if (on === "enter" || on === "leave" || on === "use") return zone(w.zone) ? "when: " + zone(w.zone) : "";
  if (on === "every" && !inRange(w.frames, 60, 36000)) return "when: every's frames must be an integer 60..36000 (60 frames are 1 s)";
  if (on === "count") {
    if (!counterOk(w.counter)) return "when: counter must be 1-16 of a-z and _";
    if (!inRange(w.at, 1, LIMITS.counter)) return `when: at must be an integer 1..${LIMITS.counter}`;
  }
  return "";
}

function conditionsError(list: unknown): string {
  if (!Array.isArray(list) || list.length === 0) return "if must be a non-empty list (leave it out when there are no conditions)";
  if (list.length > LIMITS.if) return `if: at most ${LIMITS.if} conditions`;
  for (const c of list) {
    if (!isObj(c)) return "if: every condition is an object";
    if (c.running !== undefined) {
      if (Object.keys(c).length !== 1) return 'if: {"running": true|false} stands alone';
      if (typeof c.running !== "boolean") return "if: running must be true or false";
      continue;
    }
    const extra = Object.keys(c).filter((k) => !["counter", "min", "max"].includes(k));
    if (extra.length) return `if: unknown key "${extra[0]}"`;
    if (c.counter === undefined) return 'if: a condition is {"running": ...} or {"counter": ..., "min" and/or "max"}';
    if (!counterOk(c.counter)) return "if: counter must be 1-16 of a-z and _";
    if (c.min === undefined && c.max === undefined) return `if: counter ${c.counter} needs min or max`;
    for (const k of ["min", "max"]) if (c[k] !== undefined && !inRange(c[k], 0, LIMITS.counter)) return `if: ${k} must be an integer 0..${LIMITS.counter}`;
    if (isInt(c.min) && isInt(c.max) && c.min > c.max) return "if: min is above max (it never holds)";
  }
  return "";
}

function effectsError(list: unknown, zone: (z: unknown) => string): string {
  if (!Array.isArray(list) || list.length === 0) return "do must be a non-empty list of effects";
  if (list.length > LIMITS.do) return `do must be 1-${LIMITS.do} effects`;
  for (let i = 0; i < list.length; i++) {
    const e = list[i];
    if (!isObj(e)) return 'do: every effect is an object {"do": ...}';
    const kind = e.do;
    if (typeof kind !== "string" || !Object.hasOwn(EFFECTS, kind)) return `do[${i}]: "${String(kind)}" is not an effect (${Object.keys(EFFECTS).join(", ")})`;
    const keys = EFFECTS[kind] as string[];
    const extra = Object.keys(e).filter((k) => k !== "do" && !keys.includes(k));
    const at = `do[${i}] ${kind}`;
    if (extra.length) return `${at}: takes no "${extra[0]}" (it takes ${keys.length ? keys.join(", ") : "nothing else"})`;
    const missing = keys.find((k) => e[k] === undefined);
    if (missing) return `${at}: needs ${missing}`;
    if (kind === "start" && !printable(e.run, LIMITS.name)) return `${at}: run must be 1-${LIMITS.name} printable characters`;
    if (keys.includes("zone") && zone(e.zone)) return `${at}: ${zone(e.zone)}`;
    if (kind === "add") {
      if (!counterOk(e.counter)) return `${at}: counter must be 1-16 of a-z and _`;
      if (!inRange(e.by, -99, 99) || e.by === 0) return `${at}: by must be an integer -99..99, not 0`;
    }
    if (kind === "launch") for (const k of ["up_cm", "fwd_cm"]) if (!inRange(e[k], 0, 3000)) return `${at}: ${k} must be an integer 0..3000 (cm per second)`;
    if (kind === "say") {
      if (!printable(e.text, LIMITS.text)) return `${at}: text must be 1-${LIMITS.text} printable characters`;
      if (!inRange(e.frames, 30, 600)) return `${at}: frames must be an integer 30..600 (60 frames are 1 s)`;
    }
  }
  return "";
}

/** The zone ids a rule names (its trigger's, then its effects'), each once (rules_check.gd `zones_named`). */
export function zonesNamed(r: Obj): number[] {
  const out: number[] = [];
  const w = isObj(r.when) ? r.when : {};
  if (isInt(w.zone)) out.push(w.zone);
  for (const e of Array.isArray(r.do) ? r.do : []) if (isObj(e) && isInt(e.zone) && !out.includes(e.zone)) out.push(e.zone);
  return out;
}
/** The counters a rule uses (trigger, conditions, effects), each once (rules_check.gd `counters_of`). */
export function countersOf(r: Obj): string[] {
  const out = new Set<string>();
  const w = isObj(r.when) ? r.when : {};
  if (typeof w.counter === "string") out.add(w.counter);
  for (const c of Array.isArray(r.if) ? r.if : []) if (isObj(c) && typeof c.counter === "string") out.add(c.counter);
  for (const e of Array.isArray(r.do) ? r.do : []) if (isObj(e) && typeof e.counter === "string") out.add(e.counter);
  return [...out];
}

/** The answer's M6 ops checked in order against the ask (`zones`, `rules`, `rules_room`, the region, the refused
 *  columns). Returns a checker: `check(i, op)` is "" or why op i is refused; it keeps the answer's state as it goes. */
export function rulesChecker(ask: Ask, given: ModelOp[]): (i: number, o: ModelOp) => string {
  const [lo, hi] = [ask.region.min, ask.region.max];
  const askZones = new Map<number, Obj>(), askRules = new Map<number, Obj>();
  for (const z of ask.zones ?? []) if (isInt(z.id)) askZones.set(z.id, z);
  for (const r of ask.rules ?? []) if (isInt(r.id)) askRules.set(r.id, r);
  const room = ask.rules_room ?? { zones_left: LIMITS.zones, rules_left: LIMITS.rules, counters: [] };
  // The ids some zone op of the answer makes (renumber's map): a reference to one of them names the answer's zone.
  const answerZoneIds = new Set(given.filter((o) => isObj(o) && o.op === "zone" && isInt(o.id)).map((o) => o.id as number));
  const madeZones = new Set<number>(), badZones = new Set<number>(), madeRules = new Set<number>(), gone = new Set<number>(), unruled = new Set<number>();
  const answerRules: Obj[] = [];
  const counters = new Set<string>([...room.counters, ...[...askRules.values()].flatMap(countersOf)]);
  let zonesNet = 0, rulesNet = 0;
  const refusedRuns = (ask.refused ?? []).flatMap((r) => r.runs.map(([z, x0, x1]) => ({ reason: r.reason, z, x0, x1 })));
  const zoneRef = (z: unknown): string => {
    if (!isInt(z) || z < 1) return "zone must be a positive integer (a zone's id)";
    if (answerZoneIds.has(z)) return madeZones.has(z) ? "" : badZones.has(z) ? `zone ${z} was refused above (fix it, and this holds)`
      : `zone ${z} is made later in this answer: put the zone op before the rules that name it`;
    if (!askZones.has(z)) return `zone ${z} is neither made by this answer nor listed in the region's zones`;
    return gone.has(z) ? `zone ${z} was removed earlier in this answer` : "";
  };
  const boxError = (box: unknown): string => {
    if (!Array.isArray(box) || box.length !== 2 || !box.every((c) => Array.isArray(c) && c.length === 3 && c.every(isInt)))
      return "box must be [[x0, y0, z0], [x1, y1, z1]] of integers";
    const [a, b] = box as Box;
    if (a.some((v, k) => v > (b[k] as number))) return "box: the low corner comes first (x0 <= x1, y0 <= y1, z0 <= z1)";
    const side = a.map((v, k) => (b[k] as number) - v + 1);
    if (side.some((s) => s > LIMITS.side)) return `box: at most ${LIMITS.side} cells a side (${side.join(" x ")})`;
    if (a[1] < LIMITS.yMin || b[1] > LIMITS.yMax) return `box: out of range (y ${LIMITS.yMin}..${LIMITS.yMax})`;
    if (a.some((v, k) => v < (lo[k] as number)) || b.some((v, k) => v > (hi[k] as number)))
      return `the box ${JSON.stringify(box)} leaves the region ${JSON.stringify(lo)}..${JSON.stringify(hi)}`;
    const hit = refusedRuns.find((r) => r.z >= a[2] && r.z <= b[2] && r.x1 >= a[0] && r.x0 <= b[0]);
    if (hit) return `the box covers columns the Home refuses (${hit.reason}, x ${hit.x0}..${hit.x1}, z ${hit.z}): zones are refused there`;
    return "";
  };
  const zoneWhy = (op: Obj): string => {
    if (!isInt(op.id) || op.id < 1) return "id must be a positive integer";
    const why = boxError(op.box);
    if (why) return why;
    if (typeof op.look !== "string" || !LOOKS.includes(op.look)) return `look must be one of ${LOOKS.join(", ")}`;
    if (op.name !== undefined && !printable(op.name, LIMITS.name)) return `name must be 1-${LIMITS.name} printable characters`;
    if (op.op === "zone") {
      if (madeZones.has(op.id)) return `the answer makes zone ${op.id} twice: give each new zone its own id`;
      if (zonesNet + 1 > room.zones_left) return `the Home has room for ${room.zones_left} more zones`;
      madeZones.add(op.id); zonesNet++;
      return "";
    }
    const there = askZones.get(op.id);
    if (!there || gone.has(op.id)) return `no zone ${op.id} is listed in the region's zones (unzone names one that is there)`;
    if (canonZone(op) !== canonZone(there)) return `zone ${op.id} is listed as ${canonZone(there)}: unzone carries the whole zone as listed`;
    const named = [...[...askRules.values()].filter((r) => !unruled.has(r.id as number)), ...answerRules.filter((r) => !answerZoneIds.has(op.id as number))]
      .find((r) => zonesNamed(r).includes(op.id as number));
    if (named) return `zone ${op.id} is named by rule ${named.id}: remove (unrule) that rule first, earlier in this answer`;
    gone.add(op.id); zonesNet--;
    return "";
  };
  return (_i, o) => {
    const op = o as unknown as Obj;
    if (op.op === "zone" || op.op === "unzone") {
      const why = zoneWhy(op);
      if (why && op.op === "zone" && isInt(op.id)) badZones.add(op.id);
      return why;
    }
    if (!isInt(op.id) || op.id < 1) return "id must be a positive integer";
    const why = triggerError(op.when, zoneRef) || (op.if !== undefined ? conditionsError(op.if) : "") || effectsError(op.do, zoneRef);
    if (why) return why;
    if (op.op === "unrule") {
      const there = askRules.get(op.id);
      if (!there || unruled.has(op.id)) return `no rule ${op.id} is listed in the region's rules (unrule names one that is there)`;
      if (canonRule(op) !== canonRule(there)) return `rule ${op.id} is listed as ${canonRule(there)}: unrule carries the whole rule as listed`;
      unruled.add(op.id); rulesNet--;
      return "";
    }
    if (madeRules.has(op.id)) return `the answer makes rule ${op.id} twice: give each new rule its own id`;
    if (rulesNet + 1 > room.rules_left) return `the Home has room for ${room.rules_left} more rules`;
    const more = countersOf(op).filter((c) => !counters.has(c));
    if (counters.size + more.length > LIMITS.counters)
      return `the Home would use ${counters.size + more.length} counters (${[...counters, ...more].join(", ")}); at most ${LIMITS.counters}`;
    for (const c of more) counters.add(c);
    madeRules.add(op.id); rulesNet++; answerRules.push(op);
    return "";
  };
}
