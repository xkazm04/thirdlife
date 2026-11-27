// M6 round 3, lane A6 round 4 (27 Nov 2026, the Director's Q-A7): the ask's `land_refused` (tl.world-edit-ask/1): the
// columns where the ground ops (land, paint, path, plant, flood, pour) are refused, in `refused`'s shape, separate from
// the blocks' refused columns (engine/kernel/world/build/command_ask.gd `land_refused`: a column answers for its 3 m
// ground cell). The prompt says it in one line; this file feeds back a ground op that touches such a column, so the
// model moves it before the person sees an answer whose path silently went missing ("1 refused: village").
import type { Ask, ModelOp } from "./world_edit_check.js";

const LATTICE = 3;
type Run = { reason: string; z: number; x0: number; x1: number };

/** "" or why ground op `o` is refused by the ask's land_refused columns (the first column it meets). */
export function landChecker(ask: Ask): (o: ModelOp) => string {
  const runs: Run[] = (ask.land_refused ?? []).flatMap((r) => r.runs.map(([z, x0, x1]) => ({ reason: r.reason, z, x0, x1 })));
  if (!runs.length) return () => "";
  const at = (x: number, z: number) => runs.find((r) => r.z === z && x >= r.x0 && x <= r.x1);
  const box = (x0: number, z0: number, x1: number, z1: number) => runs.find((r) => r.z >= z0 && r.z <= z1 && r.x1 >= x0 && r.x0 <= x1);
  const said = (r: Run, what: string) => `${what} meets ground the Home refuses for land, paths, paint, plants and water (${r.reason}, x ${r.x0}..${r.x1}, z ${r.z}): move it off those columns (blocks may still go there)`;
  return (o) => {
    if (o.op === "path" && Array.isArray(o.pts)) {
      const pts = o.pts as number[][];
      for (let k = 0; k + 1 < pts.length; k++) {
        const [ax, az] = pts[k] as [number, number], [bx, bz] = pts[k + 1] as [number, number];
        const n = Math.max(1, Math.ceil(Math.hypot(bx - ax, bz - az) / 50));
        for (let s = 0; s <= n; s++) {
          const x = Math.floor((ax + (bx - ax) * s / n) / 100), z = Math.floor((az + (bz - az) * s / n) / 100);
          const r = at(x, z);
          if (r) return said(r, `the path's line at (${x}, ${z})`);
        }
      }
      return "";
    }
    if (o.op === "pour" && Array.isArray(o.at)) {
      const r = at(o.at[0] as number, o.at[2] as number);
      return r ? said(r, `the pour at ${JSON.stringify(o.at)}`) : "";
    }
    const list = o.op === "land" ? o.verts : (["paint", "plant", "flood"].includes(o.op) ? o.cells : undefined);
    if (!Array.isArray(list)) return "";
    for (const e of list as number[][]) {
      const [i, j] = [e[0] as number, e[1] as number];
      const r = o.op === "land" ? box(i * LATTICE - LATTICE, j * LATTICE - LATTICE, i * LATTICE + LATTICE - 1, j * LATTICE + LATTICE - 1)
        : box(i * LATTICE, j * LATTICE, i * LATTICE + LATTICE - 1, j * LATTICE + LATTICE - 1);
      if (r) return said(r, `${o.op} [${i}, ${j}]`);
    }
    return "";
  };
}
