// Scope globs and workspace file bookkeeping.
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";

/** `**` crosses directories, `*` and `?` stay inside one path segment, a trailing `/` means everything below. */
export function globToRegExp(glob: string): RegExp {
  let g = glob.replace(/\\/g, "/").replace(/^\.\//, "");
  if (g.endsWith("/")) g += "**";
  let re = "";
  for (let i = 0; i < g.length; i++) {
    const c = g[i] as string;
    if (c === "*") {
      if (g[i + 1] === "*") {
        const slashAfter = g[i + 2] === "/";
        const atStart = i === 0 || g[i - 1] === "/";
        if (atStart && slashAfter) {
          re += "(?:.*/)?";
          i += 2;
        } else {
          re += ".*";
          i += 1;
        }
      } else re += "[^/]*";
    } else if (c === "?") re += "[^/]";
    else re += c.replace(/[.+^${}()|[\]\\]/g, "\\$&");
  }
  return new RegExp(`^${re}$`);
}

export function scopeProblems(globs: string[]): string[] {
  const out: string[] = [];
  for (const g of globs) {
    if (g.startsWith("/") || /^[A-Za-z]:/.test(g)) out.push(`scope "${g}" is absolute`);
    if (g.split(/[\\/]/).includes("..")) out.push(`scope "${g}" leaves the pack`);
  }
  return out;
}

export function matchesAny(globs: string[], rel: string): boolean {
  return globs.some((g) => globToRegExp(g).test(rel));
}

/** All files under `dir`, as sorted forward-slash relative paths. A missing directory is an empty list. */
export function listFiles(dir: string): string[] {
  const out: string[] = [];
  const walk = (rel: string): void => {
    let entries: fs.Dirent[];
    try {
      entries = fs.readdirSync(path.join(dir, rel), { withFileTypes: true });
    } catch {
      return;
    }
    for (const e of entries) {
      const r = rel ? `${rel}/${e.name}` : e.name;
      if (e.isDirectory()) walk(r);
      else if (e.isFile()) out.push(r);
    }
  };
  walk("");
  return out.sort();
}

export function hashFile(abs: string): string {
  return crypto.createHash("sha1").update(fs.readFileSync(abs)).digest("hex");
}

export function snapshot(dir: string): Record<string, string> {
  const out: Record<string, string> = {};
  for (const f of listFiles(dir)) out[f] = hashFile(path.join(dir, f));
  return out;
}

export function copyDir(from: string, to: string): void {
  fs.mkdirSync(to, { recursive: true });
  for (const f of listFiles(from)) {
    const dest = path.join(to, f);
    fs.mkdirSync(path.dirname(dest), { recursive: true });
    fs.copyFileSync(path.join(from, f), dest);
  }
}

/** Removes directories left empty under `dir` (never `dir` itself). */
export function pruneEmptyDirs(dir: string): void {
  const walk = (d: string, top: boolean): boolean => {
    let empty = true;
    for (const e of fs.readdirSync(d, { withFileTypes: true })) {
      const p = path.join(d, e.name);
      if (e.isDirectory()) {
        if (!walk(p, false)) empty = false;
      } else empty = false;
    }
    if (empty && !top) fs.rmdirSync(d);
    return empty;
  };
  if (fs.existsSync(dir)) walk(dir, true);
}
