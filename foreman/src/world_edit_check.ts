// M4 (spark world-sandbox, 26 Nov 2026): the checks of `foreman world-edit` (world_edit.ts). The model's answer is a
// list of ops over the region the exe measured (tl.world-edit-ask/1); this file replays it on a copy of that region's
// blocks, the way the exe's edit log (engine/kernel/world/build/blocks_layer.gd, op_util.gd) would, and reports every
// problem in words the model can act on. A good answer is EXPANDED into the contract's ops (contracts/BUILD.md
// "The LLM command bar"): `fill` and `clear` boxes become place and remove ops, a remove names what it removes, and the
// count of expanded ops is capped (MAX_OPS). The answer file never holds a box: only tl.edit/1 ops without v, author
// and batch. M5 (lane C): a place may name only a material of the ask's table and a put only a part of its parts table
// (the ask lists what play has unlocked); paint, path and plant names, a path's points and width are held to the
// contract's lists and ranges (contracts/BUILD.md "Milestone 5"). M6 (lane C): zone, unzone, rule and unrule are checked
// in order with every limit and refusal of the contract (world_edit_rules.ts), so the model hears them.
import { rulesChecker } from "./world_edit_rules.js";

export const MAX_OPS = 4000;
export const SHAPES = 8;
export const FLIPPABLE = [3, 4, 7];      // stair, ramp, roof
export const PAINTS = ["grass", "grass_dark", "grass_dry", "dirt", "sand", "stone", "rock_warm", "cliff", "valley"];
export const PATH_PAINTS = ["dirt", "sand", "stone", "rock_warm", "grass_dry", "plank"];
export const PLANTS = ["meadow", "flowers", "tall_grass", "valley"];
export const PATH = { ptsMin: 2, ptsMax: 64, stepMin: 100, stepMax: 4800, widthMin: 150, widthMax: 800 };   // cm
const LATTICE = 3;
const M6 = ["zone", "unzone", "rule", "unrule"];
/** Every op kind an ask's `ops` may name (tl.world-edit-ask/1): the layers' kinds and `pour`, which the exe expands. */
export const ASK_OPS = ["place", "remove", "land", "paint", "put", "lift", "flood", "pour", "drain", "path", "unpath", "plant",
  "zone", "unzone", "rule", "unrule"];
/** The kinds besides blocks that pass through with shape checks only (their rules are the exe's layers'), and their keys. */
const OTHER: Record<string, string[]> = {
  land: ["verts"], paint: ["cells"], put: ["at", "part", "params", "rot", "seed"], lift: ["at", "part", "params", "rot", "seed"],
  flood: ["cells"], drain: ["cells"], plant: ["cells"], pour: ["at"],
  path: ["id", "pts", "width_cm", "paint"], unpath: ["id", "pts", "width_cm", "paint"],
  zone: ["id", "box", "look", "name"], unzone: ["id", "box", "look", "name"],          // M6: world_edit_rules.ts checks them
  rule: ["id", "when", "if", "do"], unrule: ["id", "when", "if", "do"],
};

export type Cell = [number, number, number];
export interface AskTables { id: number; name: string; note: string }
export interface Ask {
  schema: "tl.world-edit-ask/1";
  sentence: string;
  cursor: Cell;
  facing: number;
  region: { min: Cell; max: Cell };
  ops: string[];
  blocks: number[][];
  ground: { min: [number, number]; rows: number[][] };
  refused?: { reason: string; runs: [number, number, number][] }[];
  shapes: AskTables[];
  mats: AskTables[];
  paints?: string[];
  parts?: { kind: string; note: string }[];
  layers?: Record<string, unknown>;
  water?: { y: number; runs: [number, number, number][] }[];
  zones?: Record<string, unknown>[];
  rules?: Record<string, unknown>[];
  rules_room?: { zones_left: number; rules_left: number; counters: string[] };
  caps: { ops: number; blocks_left: number };
}

/** One op as the model may write it (world_edit.schema.json): the contract's ops plus the boxes `fill` and `clear`. */
export interface ModelOp {
  op: string;
  at?: number[]; from?: number[]; to?: number[];
  shape?: number; mat?: number; rot?: number; flip?: boolean; walls?: boolean;
  verts?: unknown[]; cells?: unknown[]; part?: string; params?: Record<string, unknown>; seed?: number;
  id?: number; pts?: unknown[]; width_cm?: number; paint?: string;
  box?: unknown[]; look?: string; name?: string; when?: Record<string, unknown>; if?: unknown[]; do?: unknown[];
}
export type EditOp = Record<string, unknown>;
type Block = [number, number, number, boolean];   // shape, mat, rot, flip

const key = (c: number[]) => `${c[0]},${c[1]},${c[2]}`;
const isInt = (v: unknown): v is number => typeof v === "number" && Number.isInteger(v);
const isCell = (v: unknown): v is Cell => Array.isArray(v) && v.length === 3 && v.every(isInt);

/** The model's answer replayed on the ask's blocks. `problems` empty: `ops` is the expanded answer. */
export function expand(ask: Ask, given: ModelOp[]): { ops: EditOp[]; problems: string[]; placed: number; removed: number } {
  const world = new Map<string, Block>();
  for (const b of ask.blocks) world.set(key(b), [b[3] as number, b[4] as number, b[5] as number, b[6] === 1]);
  const [lo, hi] = [ask.region.min, ask.region.max];
  const inside = (c: number[]) => c.every((v, i) => v >= (lo[i] as number) && v <= (hi[i] as number));
  const kinds = new Set(ask.ops);
  const mats = ask.mats.map((m) => m.id), parts = new Set((ask.parts ?? []).map((p) => p.kind));
  const problems: string[] = [];
  const ops: EditOp[] = [];
  let placed = 0, removed = 0;
  const say = (i: number, text: string) => problems.push(`ops[${i}] (${given[i]?.op}): ${text}`);
  const rules = rulesChecker(ask, given);
  const record = (op: "place" | "remove", c: number[], b: Block): EditOp => {
    const r: EditOp = { op, at: [c[0], c[1], c[2]], shape: b[0], mat: b[1], rot: b[2] };
    if (b[3]) r.flip = true;
    return r;
  };
  const blockOf = (i: number, o: ModelOp): Block | undefined => {
    for (const k of ["shape", "mat", "rot"] as const) if (!isInt(o[k])) { say(i, `${k} must be an integer`); return undefined; }
    const [s, m, r] = [o.shape as number, o.mat as number, o.rot as number];
    if (s < 1 || s > SHAPES) { say(i, `unknown shape ${s}: use an id from the shape table (1-${SHAPES})`); return undefined; }
    if (m === 10) { say(i, "mat 10 (glass) is only a window's pane: give a window (shape 6) its frame's material, the pane is glass by itself"); return undefined; }
    if (!mats.includes(m)) { say(i, `mat ${m} is not in the material table (unknown, or not unlocked yet): use one of ${mats.join(", ")}`); return undefined; }
    if (r < 0 || r > 3) { say(i, "rot must be 0, 1, 2 or 3"); return undefined; }
    if (o.flip !== undefined && o.flip !== true) { say(i, "flip is written only when true (leave it out otherwise)"); return undefined; }
    if (o.flip === true && !FLIPPABLE.includes(s)) { say(i, "flip is for stair, ramp and roof (shapes 3, 4, 7) only"); return undefined; }
    return [s, m, r, o.flip === true];
  };
  const only = (i: number, o: ModelOp, allowed: string[]): boolean => {
    const extra = Object.keys(o).filter((k) => k !== "op" && !allowed.includes(k));
    if (extra.length) say(i, `${o.op} takes no ${extra.map((k) => `"${k}"`).join(", ")}`);
    return extra.length === 0;
  };
  const box = (i: number, o: ModelOp): [Cell, Cell] | undefined => {
    if (!isCell(o.from) || !isCell(o.to)) { say(i, "from and to must be cells [x, y, z] of integers"); return undefined; }
    const a = o.from.map((v, k) => Math.min(v, (o.to as Cell)[k] as number)) as Cell;
    const b = o.from.map((v, k) => Math.max(v, (o.to as Cell)[k] as number)) as Cell;
    if (!inside(a) || !inside(b)) { say(i, `the box ${JSON.stringify(o.from)}..${JSON.stringify(o.to)} leaves the region ${JSON.stringify(lo)}..${JSON.stringify(hi)}`); return undefined; }
    return [a, b];
  };
  given.forEach((o, i) => {
    if (typeof o !== "object" || o === null || typeof o.op !== "string") { say(i, "an op is an object with \"op\""); return; }
    const blockOps = kinds.has("place");
    if (o.op === "place" || o.op === "remove") {
      if (!blockOps) { say(i, "the Home takes no block ops here"); return; }
      if (!only(i, o, o.op === "place" ? ["at", "shape", "mat", "rot", "flip"] : ["at"])) return;
      if (!isCell(o.at)) { say(i, "at must be a cell [x, y, z] of integers"); return; }
      if (!inside(o.at)) { say(i, `at ${JSON.stringify(o.at)} is outside the region ${JSON.stringify(lo)}..${JSON.stringify(hi)}`); return; }
      const was = world.get(key(o.at));
      if (o.op === "remove") {
        if (!was) { say(i, `the cell ${JSON.stringify(o.at)} is empty: there is nothing to remove`); return; }
        ops.push(record("remove", o.at, was)); world.delete(key(o.at)); removed++;
        return;
      }
      const b = blockOf(i, o);
      if (!b) return;
      if (was) { say(i, `the cell ${JSON.stringify(o.at)} already holds a block: remove it first, or use fill, which replaces`); return; }
      ops.push(record("place", o.at, b)); world.set(key(o.at), b); placed++;
      return;
    }
    if (o.op === "fill" || o.op === "clear") {
      if (!blockOps) { say(i, "the Home takes no block ops here"); return; }
      if (!only(i, o, o.op === "fill" ? ["from", "to", "shape", "mat", "rot", "flip", "walls"] : ["from", "to"])) return;
      if (o.walls !== undefined && o.walls !== true) { say(i, "walls is written only when true"); return; }
      const bx = box(i, o);
      const b = o.op === "fill" ? blockOf(i, o) : undefined;
      if (!bx || (o.op === "fill" && !b)) return;
      const [a, z] = bx;
      for (let y = a[1]; y <= z[1]; y++) for (let zz = a[2]; zz <= z[2]; zz++) for (let x = a[0]; x <= z[0]; x++) {
        if (o.walls && x !== a[0] && x !== z[0] && zz !== a[2] && zz !== z[2]) continue;
        const c: Cell = [x, y, zz], was = world.get(key(c));
        if (o.op === "clear") {
          if (was) { ops.push(record("remove", c, was)); world.delete(key(c)); removed++; }
          continue;
        }
        if (was && was.every((v, k) => v === (b as Block)[k])) continue;
        if (was) { ops.push(record("remove", c, was)); removed++; }
        ops.push(record("place", c, b as Block)); world.set(key(c), b as Block); placed++;
      }
      return;
    }
    if (Object.hasOwn(OTHER, o.op)) {
      if (!kinds.has(o.op)) { say(i, `the Home does not take "${o.op}" yet: use only ${[...kinds].join(", ")}${blockOps ? ", fill, clear" : ""}`); return; }
      if (M6.includes(o.op) && !only(i, o, OTHER[o.op] as string[])) return;
      const why = M6.includes(o.op) ? rules(i, o) : otherOp(o, inside, lo, hi, ask, parts);
      if (why) { say(i, why); return; }
      const { op, ...rest } = o;
      ops.push({ op, ...rest });
      return;
    }
    say(i, `unknown op "${o.op}": use ${[...kinds, ...(blockOps ? ["fill", "clear"] : [])].join(", ")}`);
  });
  if (ops.length > MAX_OPS) problems.push(`the answer expands to ${ops.length} operations; at most ${MAX_OPS}: build less, or use fewer cells`);
  if (problems.length === 0 && ops.length === 0) problems.push("the answer changes nothing in the region");
  if (placed - removed > ask.caps.blocks_left) problems.push(`the answer adds ${placed - removed} blocks; the Home has room for ${ask.caps.blocks_left}`);
  return { ops, problems: cut(problems), placed, removed };
}

/** The land, paint, put, lift (M2, M3), flood, drain, pour, path, unpath and plant ops (M5) checked against the region
 *  and for the types of their fields; their own rules are the exe's layers'. */
function otherOp(o: ModelOp, inside: (c: number[]) => boolean, lo: Cell, hi: Cell, ask: Ask, parts: Set<string>): string {
  const extra = Object.keys(o).filter((k) => k !== "op" && !(OTHER[o.op] as string[]).includes(k));
  if (extra.length) return `${o.op} takes no ${extra.map((k) => `"${k}"`).join(", ")}`;
  if (o.op === "put" || o.op === "lift" || o.op === "pour") {
    if (!isCell(o.at)) return "at must be a cell [x, y, z] of integers";
    if (!inside(o.at)) return `at ${JSON.stringify(o.at)} is outside the region`;
    if (o.op === "put" && (typeof o.part !== "string" || !isInt(o.rot))) return "put needs part and rot";
    if (o.op === "put" && !parts.has(o.part as string)) return `the part "${o.part}" is not in the parts table (unknown, or not unlocked yet): use one of ${[...parts].join(", ")}`;
    if (o.op === "put" && ((o.rot as number) < 0 || (o.rot as number) > 3)) return "rot must be 0, 1, 2 or 3";
    return "";
  }
  if (o.op === "path" || o.op === "unpath") {
    for (const k of ["id", "pts", "width_cm", "paint"] as const) if (o[k] === undefined) return `${o.op} needs id, pts, width_cm and paint`;
    if (!isInt(o.id) || o.id < 1) return "id must be a positive integer";
    if (!isInt(o.width_cm)) return "width_cm must be an integer (cm)";
    if (o.width_cm < PATH.widthMin || o.width_cm > PATH.widthMax) return `width_cm ${o.width_cm} is outside ${PATH.widthMin}-${PATH.widthMax} (a path is 1.5 to 8 m wide)`;
    if (typeof o.paint !== "string" || !PATH_PAINTS.includes(o.paint)) return `paint must be a path paint: ${PATH_PAINTS.join(", ")}`;
    if (!Array.isArray(o.pts) || o.pts.length < PATH.ptsMin || o.pts.length > PATH.ptsMax) return `pts must hold ${PATH.ptsMin} to ${PATH.ptsMax} points [x_cm, z_cm]`;
    let prev: number[] | undefined;
    for (const p of o.pts) {
      if (!Array.isArray(p) || p.length !== 2 || !p.every(isInt)) return "every point is [x_cm, z_cm] of integers";
      const x = (p[0] as number) / 100, z = (p[1] as number) / 100;
      if (x < lo[0] || x > hi[0] + 1 || z < lo[2] || z > hi[2] + 1) return `the point [${p[0]}, ${p[1]}] (world ${x}, ${z}) is outside the region`;
      if (prev) {
        const d = Math.hypot((p[0] as number) - (prev[0] as number), (p[1] as number) - (prev[1] as number));
        if (d < PATH.stepMin || d > PATH.stepMax) return `the points [${prev[0]}, ${prev[1]}] and [${p[0]}, ${p[1]}] are ${Math.round(d)} cm apart; consecutive points are ${PATH.stepMin} to ${PATH.stepMax} cm apart`;
      }
      prev = p as number[];
    }
    return "";
  }
  const list = o.op === "land" ? o.verts : o.cells;   // land, paint, flood, drain, plant: 3 m lattice entries [i, j, ...]
  if (!Array.isArray(list) || list.length === 0) return `${o.op === "land" ? "verts" : "cells"} must be a non-empty list`;
  for (const e of list) {
    if (!Array.isArray(e) || !isInt(e[0]) || !isInt(e[1])) return "every entry starts with integers i, j";
    const x = (e[0] as number) * LATTICE, z = (e[1] as number) * LATTICE;
    if (x < lo[0] || x > hi[0] + 1 || z < lo[2] || z > hi[2] + 1) return `[${e[0]}, ${e[1]}] (world ${x}, ${z}) is outside the region`;
    if (o.op === "land" && !((e.length === 3 || e.length === 4) && e.slice(2).every(isInt))) return "a land vertex is [i, j, to_cm] (the exe fills from_cm) or [i, j, from_cm, to_cm]";
    const paints = ask.paints ?? PAINTS;
    if (o.op === "paint" && !(e.length === 4 && paints.includes(e[2] as string) && paints.includes(e[3] as string))) return `a paint cell is [i, j, "<from>", "<to>"] with paints from the table (${paints.join(", ")})`;
    if ((o.op === "flood" || o.op === "drain") && !(e.length === 3 && isInt(e[2]))) return `a ${o.op} cell is [i, j, level_cm] of integers`;
    if (o.op === "plant" && !(e.length === 4 && typeof e[2] === "string" && typeof e[3] === "string")) return `a plant cell is [i, j, "<from>", "<to>"]`;
    if (o.op === "plant" && !(PLANTS.includes(e[2] as string) && PLANTS.includes(e[3] as string))) return `a plant cell's growths are ${PLANTS.join(", ")} ("${e[2]}", "${e[3]}" given)`;
  }
  return "";
}

/** At most 24 problems are fed back (and how many more there were): a long list drowns the ones that matter. */
function cut(problems: string[]): string[] {
  const unique = [...new Set(problems)];
  return unique.length <= 24 ? unique : [...unique.slice(0, 24), `(and ${unique.length - 24} more problems like these)`];
}
