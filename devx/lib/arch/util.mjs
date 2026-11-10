// Shared helpers for the architecture checks. Every checker works on a rootDir so tests can use temp-dir fixtures.
import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";

export const posix = (p) => p.split(path.sep).join("/");

/** Tracked files (plus untracked-not-ignored, so a new file is checked before it is committed) under root. Falls back to a
 *  directory walk when root is not a git work tree (test fixtures). Returns sorted posix paths relative to root. */
export function listFiles(root) {
  if (fs.existsSync(path.join(root, ".git"))) {
    const r = spawnSync("git", ["ls-files", "--cached", "--others", "--exclude-standard"], { cwd: root, encoding: "utf8", maxBuffer: 64 * 1024 * 1024 });
    if (r.status === 0) return [...new Set(r.stdout.split("\n").map((s) => s.trim()).filter(Boolean))].filter((f) => fs.existsSync(path.join(root, f))).sort();
  }
  const out = [];
  const walk = (d) => {
    for (const e of fs.readdirSync(path.join(root, d), { withFileTypes: true })) {
      if (e.name === ".git" || e.name === "node_modules" || e.name === ".godot") continue;
      const p = d ? `${d}/${e.name}` : e.name;
      if (e.isDirectory()) walk(p); else out.push(p);
    }
  };
  walk("");
  return out.sort();
}

export const readText = (root, f) => fs.readFileSync(path.join(root, f), "utf8").replace(/\r\n/g, "\n");
export const exists = (root, f) => fs.existsSync(path.join(root, f));

/** A lazily-cached IO object handed to every checker. */
export function makeIo(root, extra = {}) {
  const files = listFiles(root);
  const cache = new Map();
  return {
    root, files, baseline: { sizes: {}, grandfathered: {} }, ...extra,
    read(f) { if (!cache.has(f)) cache.set(f, readText(root, f)); return cache.get(f); },
    has: (f) => exists(root, f),
  };
}

export const lineCount = (text) => (text === "" ? 0 : text.split("\n").length - (text.endsWith("\n") ? 1 : 0));
export const lineAt = (text, idx) => text.slice(0, idx).split("\n").length;

/** Blanks comments and string contents of GDScript, keeping every newline and offset, so a regex on the result matches
 *  code only. `keepStrings` keeps string contents (for res:// paths) but still drops comments. */
export function stripGd(src, keepStrings = false) {
  let out = "";
  const n = src.length;
  let i = 0;
  while (i < n) {
    const c = src[i];
    if (c === "#") { while (i < n && src[i] !== "\n") { out += " "; i++; } continue; }
    if (c === '"' || c === "'") {
      const triple = src.startsWith(c.repeat(3), i);
      const q = triple ? c.repeat(3) : c;
      out += keepStrings ? q : " ".repeat(q.length);
      i += q.length;
      while (i < n && !src.startsWith(q, i)) {
        if (src[i] === "\\" && !triple) { out += keepStrings ? src.slice(i, i + 2) : "  "; i += 2; continue; }
        if (!triple && src[i] === "\n") break;      // unterminated: stop at end of line
        out += src[i] === "\n" ? "\n" : keepStrings ? src[i] : " ";
        i++;
      }
      if (src.startsWith(q, i)) { out += keepStrings ? q : " ".repeat(q.length); i += q.length; }
      continue;
    }
    out += c; i++;
  }
  return out;
}

/** class_name declarations of a GDScript source: [{name, line}]. Only a `class_name` at the start of a line counts. */
export function classNames(src) {
  const code = stripGd(src);
  const out = [];
  for (const m of code.matchAll(/^class_name[ \t]+([A-Za-z_]\w*)/gm)) out.push({ name: m[1], line: lineAt(code, m.index) });
  return out;
}

/** The directory of a file's rule scope: first path segments joined, e.g. dirOf("engine/kits/a.gd", 2) = "engine/kits". */
export const under = (f, prefix) => f === prefix || f.startsWith(prefix.endsWith("/") ? prefix : prefix + "/");

/** Glob -> RegExp. `**` crosses directories, `*` and `?` do not. */
export function globToRe(g) {
  let re = "";
  for (let i = 0; i < g.length; i++) {
    const c = g[i];
    if (c === "*") {
      if (g[i + 1] === "*") { i++; if (g[i + 1] === "/") { i++; re += "(?:.*/)?"; } else re += ".*"; } else re += "[^/]*";
    } else if (c === "?") re += "[^/]";
    else re += c.replace(/[.+^${}()|[\]\\]/g, "\\$&");
  }
  return new RegExp(`^${re}$`);
}
