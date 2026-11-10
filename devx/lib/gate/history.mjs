// Timing trend: one JSON line per run in .tl/gate-history.jsonl (gitignored via .tl/).
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

/** posix: 1-minute load average. Windows has none: a 200 ms cpu-times sample, as busy-percent * logical cores. */
export async function loadFigure() {
  if (process.platform !== "win32") return Math.round(os.loadavg()[0] * 100) / 100;
  const snap = () => os.cpus().reduce((a, c) => { const t = Object.values(c.times).reduce((x, y) => x + y, 0); return [a[0] + t, a[1] + c.times.idle]; }, [0, 0]);
  const [t0, i0] = snap(); await new Promise((r) => setTimeout(r, 200)); const [t1, i1] = snap();
  const busy = t1 - t0 > 0 ? 1 - (i1 - i0) / (t1 - t0) : 0;
  return Math.round(busy * os.cpus().length * 100) / 100;
}

export function appendHistory(file, entry) {
  try { fs.mkdirSync(path.dirname(file), { recursive: true }); fs.appendFileSync(file, JSON.stringify(entry) + "\n"); return true; } catch { return false; }
}
export function readHistory(file) {
  try { return fs.readFileSync(file, "utf8").split(/\n/).filter(Boolean).map((l) => { try { return JSON.parse(l); } catch { return null; } }).filter(Boolean); } catch { return []; }
}
export const median = (xs) => { if (!xs.length) return 0; const s = [...xs].sort((a, b) => a - b), m = s.length >> 1; return s.length % 2 ? s[m] : Math.round((s[m - 1] + s[m]) / 2); };

/** -> [{id, n, median, last, slow}] over the last 10 appearances of each step; slow = last > 1.5x median and > 2 s. */
export function trend(entries, window = 10) {
  const per = new Map();
  for (const e of entries) for (const s of e.steps ?? []) { if (!per.has(s.id)) per.set(s.id, []); per.get(s.id).push(s.ms); }
  return [...per].sort(([a], [b]) => a.localeCompare(b)).map(([id, all]) => {
    const w = all.slice(-window), med = median(w), last = w[w.length - 1];
    return { id, n: w.length, median: med, last, slow: w.length >= 3 && last > med * 1.5 && last > 2000 };
  });
}
