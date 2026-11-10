// Change detection by polling mtimes (fs.watch is unreliable on Windows). Pure: the clock and the scan are injected,
// so a test drives it with a fake clock.
import fs from "node:fs";
import path from "node:path";

/** Recursively scans `roots`, returns Map(path -> mtimeMs) of files whose extension is in `exts` (or any when null). */
export function scanFiles(roots, exts = null, skipDirs = [".godot", "node_modules", ".git"]) {
  const out = new Map();
  const walk = (dir) => {
    let ents;
    try { ents = fs.readdirSync(dir, { withFileTypes: true }); } catch { return; }
    for (const e of ents) {
      const p = path.join(dir, e.name);
      if (e.isDirectory()) { if (!skipDirs.includes(e.name)) walk(p); continue; }
      if (exts && !exts.includes(path.extname(e.name))) continue;
      try { out.set(p, fs.statSync(p).mtimeMs); } catch { /* vanished between readdir and stat */ }
    }
  };
  for (const r of roots) walk(r);
  return out;
}

/** Files that differ between two scans (added, removed, or a new mtime). */
export function diffScans(a, b) {
  const changed = [];
  for (const [p, m] of b) if (a.get(p) !== m) changed.push(p);
  for (const p of a.keys()) if (!b.has(p)) changed.push(p);
  return changed;
}

/**
 * poll() returns null until a change has been quiet for `debounceMs`, then the list of changed files (once).
 * A new change inside the window restarts the window.
 */
export function createDetector({ scan, now = Date.now, debounceMs = 500 }) {
  let last = scan();
  let pending = new Set();
  let lastChangeAt = 0;
  return {
    poll() {
      const cur = scan();
      const ch = diffScans(last, cur);
      last = cur;
      if (ch.length) { for (const p of ch) pending.add(p); lastChangeAt = now(); }
      if (pending.size && now() - lastChangeAt >= debounceMs) {
        const out = [...pending].sort();
        pending = new Set();
        return out;
      }
      return null;
    },
  };
}
