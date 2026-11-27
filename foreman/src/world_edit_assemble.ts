// M6 round 3, lane A6 (27 Nov 2026): the Foreman's checks of an `assemble` op (contracts/BUILD.md "Assemblies (M6,
// round 3)"), word for word the exe's (engine/kernel/world/build/assembly.gd `malformed`), plus the ask's own facts:
// its material table (what play has unlocked) and its region (the shape's core footprint, turned, must lie inside it).
// The exe expands an assemble into place ops when it shows the answer; the answer file keeps the assemble as written.
import type { Ask, ModelOp } from "./world_edit_check.js";

export const KINDS = ["wall", "tower", "house", "stair", "bridge", "platform"];
export const ASSEMBLE_KEYS = ["kind", "at", "size", "rot", "mat", "trim", "opts"];
const OPTS: Record<string, string[]> = {
  wall: ["door", "windows", "crenels"], tower: ["door", "windows", "crenels", "stairs"],
  house: ["windows"], stair: [], bridge: [], platform: [],
};
export const SIZE_NOTES: Record<string, string> = {
  wall: "[length, height, unused]", tower: "[side, height, unused]", house: "[width, height, depth]",
  stair: "[width, steps, unused]", bridge: "[width, unused, length]", platform: "[width, unused, depth]",
};
export const SIZE_MAX = 48, WINDOWS = { min: 2, max: 16 }, LANDING_EVERY = 6;
const isInt = (v: unknown): v is number => typeof v === "number" && Number.isInteger(v);

/** The shape's core footprint in world cells (x0, z0, x1, z1), turned by `rot` about the centre of the `at` cell
 *  (assembly.gd `turn`: rot 1 takes local +x to world -z, local +z to world +x). Steps, stairs and piers outside it
 *  (a bridge's ends, a tower's outside stairs, a door's step) are not in it. */
export function footprint(o: { kind: string; at: number[]; size: number[]; rot: number }): [number, number, number, number] {
  const [w, h, d] = o.size as [number, number, number];
  const len: Record<string, [number, number]> = {
    wall: [w, 1], tower: [w, w], house: [w, d], stair: [w, h + Math.floor((h - 1) / LANDING_EVERY)], bridge: [w, d], platform: [w, d],
  };
  const [lw, ld] = len[o.kind] as [number, number];
  const turn = (x: number, z: number): [number, number] => {
    let p: [number, number] = [x, z];
    for (let i = 0; i < o.rot; i++) p = [p[1], -p[0]];
    return [(o.at[0] as number) + p[0], (o.at[2] as number) + p[1]];
  };
  const a = turn(0, 0), b = turn(lw - 1, ld - 1);
  return [Math.min(a[0], b[0]), Math.min(a[1], b[1]), Math.max(a[0], b[0]), Math.max(a[1], b[1])];
}

/** "" or what is wrong with an assemble op, in the exe's words (assembly.gd `malformed`), then the ask's table and region. */
export function assembleError(o: ModelOp, ask: Ask, inside: (c: number[]) => boolean): string {
  const extra = Object.keys(o).filter((k) => k !== "op" && !ASSEMBLE_KEYS.includes(k));
  if (extra.length) return `assemble takes no ${extra.map((k) => `"${k}"`).join(", ")} (only ${ASSEMBLE_KEYS.join(", ")})`;
  for (const k of ["kind", "at", "size", "rot", "mat"] as const) if (o[k] === undefined) return `${k} is missing`;
  if (typeof o.kind !== "string" || !KINDS.includes(o.kind)) return `unknown kind '${String(o.kind)}': one of ${KINDS.join(", ")}`;
  if (!Array.isArray(o.at) || o.at.length !== 3 || !o.at.every(isInt)) return "at must be [x, y, z] of integers";
  if (!Array.isArray(o.size) || o.size.length !== 3 || !o.size.every((v) => isInt(v) && v >= 1 && v <= SIZE_MAX))
    return `size must be [w, h, d] of whole cells, each 1-${SIZE_MAX} (${o.kind}: ${SIZE_NOTES[o.kind]})`;
  if (!isInt(o.rot) || o.rot < 0 || o.rot > 3) return "rot must be 0..3";
  const mats = ask.mats.map((m) => m.id);
  for (const k of ["mat", "trim"] as const) {
    if (o[k] === undefined) continue;
    const m = o[k];
    if (!isInt(m)) return `${k} must be an integer`;
    if (m === 10) return `${k} 10 (glass) is only a window's pane`;
    if (!mats.includes(m)) return `${k} ${m} is not in the material table (unknown, or not unlocked yet): use one of ${mats.join(", ")}`;
  }
  const [w, h, d] = o.size as [number, number, number];
  let opts: Record<string, unknown> = {};
  if (o.opts !== undefined) {
    if (typeof o.opts !== "object" || o.opts === null || Array.isArray(o.opts)) return "opts must be an object";
    opts = o.opts as Record<string, unknown>;
    if (Object.keys(opts).length === 0) return "opts is written only when it holds an option (leave it out)";
  }
  const allowed = OPTS[o.kind] as string[];
  for (const k of Object.keys(opts)) {
    if (!allowed.includes(k)) return allowed.length ? `a ${o.kind} takes no opt '${k}' (only ${allowed.join(", ")})` : `a ${o.kind} takes no opts`;
  }
  if (opts.door !== undefined) {
    const [lo, hi] = o.kind === "tower" ? [1, w - 2] : [0, w - 1];
    if (!isInt(opts.door) || opts.door < lo || opts.door > hi) return `opts.door is the door's cell along the ${o.kind}'s front, ${lo}..${hi}`;
  }
  if (opts.windows !== undefined && o.kind === "house") {       // round 4 (Q-A8): a count on the front, beside the door
    const max = Math.max(0, w - 3);
    if (!isInt(opts.windows) || opts.windows < 0 || opts.windows > max)
      return `opts.windows is how many windows on the house's front beside the door, 0..${max} for ${w} wide`;
  } else if (opts.windows !== undefined && (!isInt(opts.windows) || opts.windows < WINDOWS.min || opts.windows > WINDOWS.max))
    return `opts.windows is a window every N cells, N ${WINDOWS.min}..${WINDOWS.max}`;
  if (opts.crenels !== undefined && opts.crenels !== true) return "opts.crenels is written only when true";
  if (opts.stairs !== undefined && opts.stairs !== "inside" && opts.stairs !== "outside") return "opts.stairs is \"inside\" or \"outside\"";
  if (o.kind === "wall") {
    if (opts.door !== undefined && h < 3) return "a wall with a door is at least 3 high (a sill, then a 2-cell opening)";
    if (opts.windows !== undefined && h < 2) return "a wall with windows is at least 2 high";
  }
  if (o.kind === "tower") {
    if (w < 3) return "a tower is at least 3 wide (walls round a hollow)";
    if (h < 4) return "a tower is at least 4 high (a floor, a 2-cell door, a top)";
    if (opts.stairs === "inside" && w < 5) return "a tower with inside stairs is at least 5 wide (stairs round a 1-cell well)";
  }
  if (o.kind === "house") {
    if (w < 3 || d < 3) return "a house is at least 3 x 3";
    if (h < 3) return "a house is at least 3 high (a floor and a 2-cell door)";
  }
  if (!inside(o.at)) return `at ${JSON.stringify(o.at)} is outside the region`;
  const [x0, z0, x1, z1] = footprint(o as { kind: string; at: number[]; size: number[]; rot: number });
  const y = o.at[1] as number;
  if (!inside([x0, y, z0]) || !inside([x1, y, z1]))
    return `the ${o.kind}'s footprint x ${x0}..${x1}, z ${z0}..${z1} (turned by rot ${o.rot}) leaves the region: move it or make it smaller`;
  return "";
}
