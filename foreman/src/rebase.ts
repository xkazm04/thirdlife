// H2 of 25 Nov (day run): a finished game on a core moves to the NEWEST base. A game made on the rink core is the base
// (engine/templates/rink_game, copied whole by the base package) plus its own data: the cartridge, an optional rules
// sidecar, the skin, the match, and whatever its packages added. When the base gets better after the game was made (the
// toys drawn, the top view without the hall's roof, pickups seen), the game keeps the base it was made with: nothing
// carried the base's later work to it. `foreman rebase` re-copies the base under the game:
//   - the game's own files are kept byte for byte: data/skin.json, data/match.json, every data/*.rules.json, the game's
//     cartridge (the one match.json or skin.json names), every file the base does not have (its own tests, cartridges,
//     banks), and every data file the game changed (a file under data/ that is no version the base ever had: E5's pond
//     rewrote data/hud_barks.json as its own banter);
//   - a file that is some version of the base (the job's reference copy ref/base/<base>/, or any version of
//     engine/templates/<base>/ in git history) is replaced by the newest base's; a base file the game lacks is added; a
//     file an older base had and the newest dropped is removed when the game still holds the old base's version;
//   - a script, test, generator or asset the game CHANGED (no version of the base) is three-way (H2b, from G1's real job: its
//     drawing package added seven lines to main.gd, and the newest base had not touched main.gd, yet the move was refused):
//     when the newest base did not change that file since the game's base (the job's ref/base copy equals the newest; for a
//     bare pack: the base's history holds only the newest version of it), the game's version is kept; only when both the
//     game and the newer base changed it is it a conflict: the move is refused and each such file is named with what each
//     side changed (lines added and removed);
//   - pack.json: the game's own, with the newest base's tests first (then the game's own tests), the union of the
//     capabilities, assets and cameras, the newer kernel API, and the next version.
// Then the Foreman verifies the result as a final verification does (lint, smoke, every bot of the manifest; a bot that
// fails is run on the game as it was, and one that fails there too is the game's own, kept and named: the proof pond's
// bot_crease_policy fails word for word the same on v0.1.4) and only then makes it the game: for a job, a new promotion beside the earlier ones (promoted/<id>@<version>/), pack/ and the
// job's reference copy of the base follow; for a bare pack (--pack), the result is written to --out.
import { execFileSync } from "node:child_process";
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { copyDir, listFiles } from "./scope.js";
import { REPO_ROOT, stripBom } from "./paths.js";

/** Files of a pack that are never moved by a rebase: the manifest (merged, below), engine caches, documents at the top. */
const outside = (rel: string): boolean =>
  rel === "pack.json" || (!rel.includes("/") && /\.(md|txt)$/i.test(rel)) || rel.split("/").includes(".godot") || rel.endsWith(".import") || rel.endsWith(".uid");

/** The game's data a rebase never touches (CORE_DATA_RE's files plus the match). */
const GAME_DATA_RE = /^data\/(?:skin\.json|match\.json|[^/]+\.rules\.json)$/;

const readJson = (file: string): Record<string, unknown> => JSON.parse(stripBom(fs.readFileSync(file, "utf8"))) as Record<string, unknown>;

/** Git's blob id of some bytes (sha1 of "blob <n>\0" + bytes). */
export function blobId(bytes: Buffer): string {
  return crypto.createHash("sha1").update(`blob ${bytes.length}\0`).update(bytes).digest("hex");
}

/** The ids a file counts as: its bytes, and its bytes with CRLF made LF (a checkout with autocrlf). */
function idsOf(abs: string): string[] {
  return idsOfBytes(fs.readFileSync(abs));
}
function idsOfBytes(b: Buffer): string[] {
  const lf = Buffer.from(b.toString("latin1").replace(/\r\n/g, "\n"), "latin1");
  return lf.length === b.length ? [blobId(b)] : [blobId(b), blobId(lf)];
}

/** Every version a base's files ever had: pack-relative path -> blob ids (git history of the base, plus extra dirs). */
export type KnownBase = Map<string, Set<string>>;

export function knownBase(baseRel: string, extraDirs: string[] = [], repo = REPO_ROOT): { known: KnownBase; sources: string[] } {
  const known: KnownBase = new Map();
  const add = (rel: string, id: string): void => {
    if (!known.has(rel)) known.set(rel, new Set());
    (known.get(rel) as Set<string>).add(id);
  };
  const sources: string[] = [];
  try {
    const out = execFileSync("git", ["-C", repo, "log", "--raw", "--no-abbrev", "--no-renames", "--format=", "--", baseRel], { encoding: "utf8", maxBuffer: 64 * 1024 * 1024, stdio: ["ignore", "pipe", "ignore"] });
    const prefix = `${baseRel.replace(/\\/g, "/").replace(/\/$/, "")}/`;
    let n = 0;
    for (const line of out.split(/\r?\n/)) {
      const m = /^:\d+ \d+ ([0-9a-f]{40}) ([0-9a-f]{40}) \w+\t(.+)$/.exec(line);
      if (!m || !(m[3] as string).startsWith(prefix)) continue;
      const rel = (m[3] as string).slice(prefix.length);
      for (const id of [m[1], m[2]] as string[]) if (!/^0+$/.test(id)) add(rel, id);
      n += 1;
    }
    sources.push(`git history of ${baseRel} (${n} file versions)`);
  } catch {
    sources.push(`git history of ${baseRel}: not readable`);
  }
  for (const d of extraDirs) {
    if (!fs.existsSync(d)) continue;
    for (const f of listFiles(d)) if (!outside(f)) for (const id of idsOf(path.join(d, f))) add(f, id);
    sources.push(d.replace(/\\/g, "/"));
  }
  return { known, sources };
}

export interface RebasePlan {
  /** Base files whose game copy was an older base's: the newest base's copy goes in. */
  replaced: string[];
  /** Base files the game did not have. */
  added: string[];
  /** Files an older base had and the newest dropped, still the old base's in the game: removed. */
  removed: string[];
  /** Already the newest base's. */
  same: string[];
  /** The game's own: kept byte for byte (its data, its cartridge, its own files, the data it changed). */
  kept: string[];
  /** Base files the game changed and the newest base did not (since the game's base): the game's version is kept. */
  edited: string[];
  /** Files both the game and the newer base changed: the move would lose one side. */
  conflicts: string[];
  /** Per conflict: what each side changed, in words. */
  why: Record<string, string>;
  /** The game's cartridge (data/<name>.cartridge.json), when its data names one. */
  cartridge?: string;
  manifest: Record<string, unknown>;
}

/** The game's cartridge: match.json's `cartridge` (else skin.json's), as data/<file>. */
function gameCartridge(gameDir: string): string | undefined {
  for (const f of ["data/match.json", "data/skin.json"]) {
    try {
      const c = readJson(path.join(gameDir, f))["cartridge"];
      if (typeof c === "string" && c !== "") return `data/${c}`;
    } catch {
      /* not there */
    }
  }
  return undefined;
}

const list = (v: unknown): string[] => (Array.isArray(v) ? v.filter((x): x is string => typeof x === "string") : []);
const union = (a: string[], b: string[]): string[] => [...new Set([...a, ...b])];
const apiNum = (v: unknown): number[] => (typeof v === "string" ? v.split(".").map((x) => Number(x) || 0) : [0]);
const newerApi = (a: unknown, b: unknown): unknown => {
  const x = apiNum(a);
  const y = apiNum(b);
  for (let i = 0; i < Math.max(x.length, y.length); i++) if ((x[i] ?? 0) !== (y[i] ?? 0)) return (x[i] ?? 0) > (y[i] ?? 0) ? a : b;
  return a ?? b;
};
/** The next version: the last number plus one ("0.1.4" -> "0.1.5"). */
export const nextVersion = (v: unknown): string => (typeof v === "string" && /\d+$/.test(v) ? v.replace(/\d+$/, (d) => String(Number(d) + 1)) : "0.1.1");

/** What moving `gameDir` onto `baseDir` would do (nothing is written). */
/** Lines added and removed from `a` to `b` (as multisets of lines: a count, not a diff to apply). */
export function lineDelta(a: string, b: string): { added: number; removed: number } {
  const count = (t: string): Map<string, number> => {
    const m = new Map<string, number>();
    for (const l of t.replace(/\r\n/g, "\n").split("\n")) m.set(l, (m.get(l) ?? 0) + 1);
    return m;
  };
  const ma = count(a);
  const mb = count(b);
  let added = 0;
  let removed = 0;
  for (const [l, n] of mb) added += Math.max(0, n - (ma.get(l) ?? 0));
  for (const [l, n] of ma) removed += Math.max(0, n - (mb.get(l) ?? 0));
  return { added, removed };
}

/**
 * What moving `gameDir` onto `baseDir` would do (nothing is written). `was`: the base the game was made from (a job's
 * ref/base/<base>/), for the three-way rule; without it a file counts as unchanged by the base when its history holds only
 * the newest version.
 */
export function planRebase(gameDir: string, baseDir: string, known: KnownBase, version?: string, was?: string): RebasePlan {
  const game = new Set(listFiles(gameDir).filter((f) => !outside(f)));
  const base = new Set(listFiles(baseDir).filter((f) => !outside(f)));
  const cartridge = gameCartridge(gameDir);
  const plan: RebasePlan = { replaced: [], added: [], removed: [], same: [], kept: [], edited: [], conflicts: [], why: {}, manifest: {}, ...(cartridge !== undefined ? { cartridge } : {}) };
  const isOld = (rel: string): boolean => idsOf(path.join(gameDir, rel)).some((id) => known.get(rel)?.has(id) ?? false);
  for (const rel of [...new Set([...game, ...base])].sort()) {
    const inGame = game.has(rel);
    const inBase = base.has(rel);
    if (inGame && (GAME_DATA_RE.test(rel) || rel === cartridge)) {
      plan.kept.push(rel);
      continue;
    }
    if (!inGame) {
      plan.added.push(rel);
      continue;
    }
    if (!inBase) {
      if (known.has(rel) && isOld(rel)) plan.removed.push(rel);
      else plan.kept.push(rel);
      continue;
    }
    if (fs.readFileSync(path.join(gameDir, rel)).equals(fs.readFileSync(path.join(baseDir, rel)))) plan.same.push(rel);
    else if (isOld(rel)) plan.replaced.push(rel);
    else if (rel.startsWith("data/")) plan.kept.push(rel);
    else {
      // three-way: did the newest base change this file since the game's base?
      const newest = fs.readFileSync(path.join(baseDir, rel));
      const wasFile = was !== undefined ? path.join(was, rel) : undefined;
      const o = wasFile !== undefined && fs.existsSync(wasFile) ? fs.readFileSync(wasFile) : undefined;
      const ids = new Set(idsOfBytes(newest));
      const baseUnchanged = o !== undefined ? o.equals(newest) : was === undefined && (known.get(rel)?.size ?? 0) > 0 && [...(known.get(rel) ?? [])].every((id) => ids.has(id));
      if (baseUnchanged) plan.edited.push(rel);
      else {
        plan.conflicts.push(rel);
        const g = fs.readFileSync(path.join(gameDir, rel), "utf8");
        const b = newest.toString("utf8");
        const dg = lineDelta(o !== undefined ? o.toString("utf8") : b, g);
        const db = o !== undefined ? lineDelta(o.toString("utf8"), b) : undefined;
        plan.why[rel] = db !== undefined
          ? `the game +${dg.added} -${dg.removed} lines and the newest base +${db.added} -${db.removed} lines since the game's base`
          : `the game's copy is +${dg.added} -${dg.removed} lines from the newest base, which has changed this file over its history (${known.get(rel)?.size ?? 0} versions; a bare pack's own base is not known)`;
      }
    }
  }
  // the manifest: the game's own, the newest base's registers merged in
  const gm = fs.existsSync(path.join(gameDir, "pack.json")) ? readJson(path.join(gameDir, "pack.json")) : {};
  const bm = readJson(path.join(baseDir, "pack.json"));
  const present = (t: string): boolean => (game.has(t) && !plan.removed.includes(t)) || base.has(t);
  const baseTests = list(bm["tests"]).filter(present);
  const m: Record<string, unknown> = { ...gm };
  for (const [k, v] of Object.entries(bm)) if (!(k in m) && !["id", "title", "version"].includes(k)) m[k] = v;
  m["kernelApi"] = newerApi(gm["kernelApi"], bm["kernelApi"]);
  m["capabilities"] = union(list(gm["capabilities"]), list(bm["capabilities"]));
  m["assets"] = union(list(bm["assets"]), list(gm["assets"]).filter(present));
  m["tests"] = union(baseTests, list(gm["tests"]).filter(present));
  m["cameras"] = union(list(gm["cameras"]), list(bm["cameras"]));
  for (const k of ["capabilities", "assets", "tests", "cameras"]) if ((m[k] as string[]).length === 0) delete m[k];
  m["version"] = version ?? nextVersion(gm["version"]);
  plan.manifest = m;
  return plan;
}

/** Writes the moved game into `outDir` (emptied first): the game, then the base's newer files over it, then pack.json. */
export function writeRebase(gameDir: string, baseDir: string, plan: RebasePlan, outDir: string): void {
  fs.rmSync(outDir, { recursive: true, force: true });
  fs.mkdirSync(outDir, { recursive: true });
  for (const f of listFiles(gameDir)) {
    if (outside(f) || plan.removed.includes(f)) continue;
    fs.mkdirSync(path.dirname(path.join(outDir, f)), { recursive: true });
    fs.copyFileSync(path.join(gameDir, f), path.join(outDir, f));
  }
  for (const f of [...plan.replaced, ...plan.added]) {
    fs.mkdirSync(path.dirname(path.join(outDir, f)), { recursive: true });
    fs.copyFileSync(path.join(baseDir, f), path.join(outDir, f));
  }
  fs.writeFileSync(path.join(outDir, "pack.json"), JSON.stringify(plan.manifest, null, 2) + "\n");
}

/** One line for a person and a log: what the move did. */
export function rebaseSummary(plan: RebasePlan, baseRel: string): string {
  const n = (a: string[]): string => String(a.length);
  return `moved to the newest base (${baseRel}): ${n(plan.replaced)} base file(s) brought up to date, ${n(plan.added)} added (${plan.added.join(", ") || "none"}), ${n(plan.removed)} removed${plan.removed.length > 0 ? ` (${plan.removed.join(", ")})` : ""}, ${n(plan.same)} already current; the game's own kept byte for byte: ${[...plan.kept, ...plan.edited].join(", ") || "none"}${plan.edited.length > 0 ? ` (its own changes to the base's ${plan.edited.join(", ")} kept: the newest base did not change ${plan.edited.length === 1 ? "it" : "them"})` : ""}`;
}

/** True when the move changes nothing (every base file current, nothing to add or remove). */
export const nothingToMove = (p: RebasePlan): boolean => p.replaced.length === 0 && p.added.length === 0 && p.removed.length === 0;

/** Copies a directory in place of another through a temporary sibling (never a half-copied pack). */
export function swapDir(from: string, to: string): void {
  const tmp = `${to}.incoming-${process.pid}`;
  fs.rmSync(tmp, { recursive: true, force: true });
  copyDir(from, tmp);
  fs.rmSync(to, { recursive: true, force: true });
  fs.renameSync(tmp, to);
}
