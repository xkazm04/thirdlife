// D3 of 22 Nov (day): a bot's `metrics` and `moments` are claims (PACK.md 2026-11-22); the film is the evidence. The
// Foreman measures motion from the strips it already took (frame differences between a strip's tiles: deterministic,
// no model, about 50 ms a strip) and sets two kinds of finding beside the claims:
//   - idle: no tile of a strip changes for 50 frames or more while the bot's `idle_max_f` claims fewer frames than
//     that (proof fight-colosseum-20261122-3: idle_max_f 37, its side strip f9550 still over all 12 tiles, 55 frames);
//   - contact: a dense CONTACT strip around a moment the bot reported in which nothing moves at all (no wind-up, no
//     hit, no reaction over its 22 frames): the claimed contact is not on film.
// The checks are one-sided on purpose. A tile that changes may be the camera, a particle or a cloud, so motion proves
// nothing; a strip in which NOTHING changes proves the bodies did not move. A strip that could not be read is said as
// unmeasured, never as still. Pure apart from reading the PNG files.
import fs from "node:fs";
import path from "node:path";
import zlib from "node:zlib";
import type { JobEvent } from "./events.js";
import { resultMoments } from "./shots.js";

// ---------- a small PNG reader (8-bit grey, grey+alpha, RGB, RGBA; not interlaced): what Godot's capture writes ----------

export interface Raster {
  width: number;
  height: number;
  /** Bytes per pixel: 1 grey, 2 grey+alpha, 3 RGB, 4 RGBA. */
  channels: number;
  data: Uint8Array;
}

const CHANNELS: Record<number, number> = { 0: 1, 2: 3, 4: 2, 6: 4 };

/** Decodes a PNG. Throws on what it does not read (palette, 16-bit, interlaced), so a caller says "unmeasured". */
export function decodePng(buf: Buffer): Raster {
  if (buf.length < 33 || buf.readUInt32BE(0) !== 0x89504e47 || buf.readUInt32BE(4) !== 0x0d0a1a0a) throw new Error("not a PNG");
  let pos = 8;
  let width = 0, height = 0, depth = 0, type = -1, interlace = 0;
  const idat: Buffer[] = [];
  while (pos + 8 <= buf.length) {
    const len = buf.readUInt32BE(pos);
    const kind = buf.toString("latin1", pos + 4, pos + 8);
    const body = buf.subarray(pos + 8, pos + 8 + len);
    if (kind === "IHDR") {
      width = body.readUInt32BE(0); height = body.readUInt32BE(4); depth = body[8] as number; type = body[9] as number; interlace = body[12] as number;
    } else if (kind === "IDAT") idat.push(body);
    else if (kind === "IEND") break;
    pos += 12 + len;
  }
  const channels = CHANNELS[type];
  if (channels === undefined || depth !== 8 || interlace !== 0 || width === 0 || height === 0) throw new Error(`unsupported PNG (colour type ${type}, depth ${depth}, interlace ${interlace})`);
  const raw = zlib.inflateSync(Buffer.concat(idat));
  const stride = width * channels;
  if (raw.length < (stride + 1) * height) throw new Error("PNG data is short");
  const out = new Uint8Array(stride * height);
  for (let y = 0; y < height; y++) {
    const f = raw[y * (stride + 1)] as number;
    const src = y * (stride + 1) + 1;
    const row = y * stride;
    const up = row - stride;
    for (let x = 0; x < stride; x++) {
      const v = raw[src + x] as number;
      const a = x >= channels ? (out[row + x - channels] as number) : 0;
      const b = y > 0 ? (out[up + x] as number) : 0;
      const c = x >= channels && y > 0 ? (out[up + x - channels] as number) : 0;
      let p: number;
      switch (f) {
        case 0: p = v; break;
        case 1: p = v + a; break;
        case 2: p = v + b; break;
        case 3: p = v + ((a + b) >> 1); break;
        case 4: { const q = a + b - c; const pa = Math.abs(q - a), pb = Math.abs(q - b), pc = Math.abs(q - c); p = v + (pa <= pb && pa <= pc ? a : pb <= pc ? b : c); break; }
        default: throw new Error(`PNG filter ${f} is not a filter`);
      }
      out[row + x] = p & 0xff;
    }
  }
  return { width, height, channels, data: out };
}

// ---------- motion between the tiles of a strip ----------

/** Block size in pixels: each tile is reduced to the mean brightness of BLOCK x BLOCK squares before it is compared. */
export const BLOCK = 8;
/** A block changed when its mean brightness moved by more than this (0..255). */
export const BLOCK_DELTA = 12;
/**
 * Two tiles differ (something moved) when at least this many blocks changed. Calibrated on the proofs of 22 Nov (1280x720
 * strips, 640x360 tiles, 3600 blocks): the strips the critic read as "both frozen for all 12 tiles" change 0-3 blocks a
 * step (an idle flicker, dust), a step of a fighter moving changes 26 to 1000.
 */
export const MOVED_BLOCKS = 6;
/** The shortest still run that is a finding: 50 frames (the brief: "no body moves for 50 frames"). A hit-stop is 6-12. */
export const STILL_MIN_F = 50;

/** The mean brightness of each BLOCK x BLOCK square of one tile (x0, y0, w, h in pixels). */
export function tileBlocks(r: Raster, x0: number, y0: number, w: number, h: number): Float64Array {
  const gw = Math.floor(w / BLOCK), gh = Math.floor(h / BLOCK);
  const out = new Float64Array(gw * gh);
  const ch = r.channels;
  for (let by = 0; by < gh; by++) for (let bx = 0; bx < gw; bx++) {
    let sum = 0;
    for (let y = 0; y < BLOCK; y++) {
      let i = ((y0 + by * BLOCK + y) * r.width + x0 + bx * BLOCK) * ch;
      for (let x = 0; x < BLOCK; x++, i += ch) sum += ch >= 3 ? 0.299 * (r.data[i] as number) + 0.587 * (r.data[i + 1] as number) + 0.114 * (r.data[i + 2] as number) : (r.data[i] as number);
    }
    out[by * gw + bx] = sum / (BLOCK * BLOCK);
  }
  return out;
}

/** How many blocks differ by more than BLOCK_DELTA between two tiles. */
export function changedBlocks(a: Float64Array, b: Float64Array): number {
  let n = 0;
  for (let i = 0; i < a.length && i < b.length; i++) if (Math.abs((a[i] as number) - (b[i] as number)) > BLOCK_DELTA) n++;
  return n;
}

/** Where a strip sits in the run: its first frame, the frames between tiles, the tile grid, and (contact strips) the moment. */
export interface StripInfo {
  capture: string;
  from: number;
  step: number;
  count: number;
  cols: number;
  rows: number;
  bot?: string;
  cam?: string;
  /** A CONTACT strip: the moment the bot reported, which the strip was filmed around. */
  contact?: number;
  house?: boolean;
}

/**
 * What a strip is, read from its label (the words shots.ts and quality.ts write: "4 columns x 3 rows", "frames 3163,
 * 3168, ... 3218, 5 frames apart", "while tests/bot_tofu.gd", "CONTACT (a moment the bot reported, frame 2269;"), with the
 * capture's file name as a fallback for the first frame. Undefined when the label does not say where the tiles are.
 */
export function stripInfo(capture: string, label: string): StripInfo | undefined {
  const grid = /(\d+) columns x (\d+) rows/.exec(label);
  const frames = /frames (\d+), (\d+), \.\.\. (\d+)(?:, (\d+) frames apart)?/.exec(label);
  if (frames === null) return undefined;
  const from = Number(frames[1]);
  const step = frames[4] !== undefined ? Number(frames[4]) : Number(frames[2]) - from;
  const last = Number(frames[3]);
  if (!(step > 0)) return undefined;
  const count = Math.round((last - from) / step) + 1;
  const cols = grid ? Number(grid[1]) : 4;
  const rows = grid ? Number(grid[2]) : 3;
  const bot = /while (tests\/[A-Za-z0-9_\/.-]+\.gd)/.exec(label)?.[1] ?? /(tests\/[A-Za-z0-9_\/.-]+\.gd) on camera/.exec(label)?.[1];
  const cam = /camera ([A-Za-z0-9_-]+)/.exec(label)?.[1];
  const contact = /a moment the bot reported, frame (\d+)/.exec(label)?.[1] ?? /the contact at frame (\d+)/.exec(label)?.[1];
  return { capture, from, step, count: Math.min(count, cols * rows), cols, rows, ...(bot !== undefined ? { bot } : {}), ...(cam !== undefined ? { cam } : {}), ...(contact !== undefined ? { contact: Number(contact) } : {}), ...(label.startsWith("HOUSE GAME") ? { house: true } : {}) };
}

export interface StripMotion {
  info: StripInfo;
  /** Changed blocks between tile i and tile i+1 (count - 1 entries). */
  changed: number[];
  /** Per tile pair: true when something moved. */
  moved: boolean[];
  /** The longest run of tiles that all hold still: first and last tile (1-based), and the frames it covers at least. */
  longestStill?: { firstTile: number; lastTile: number; fromFrame: number; toFrame: number; frames: number };
}

/** The motion of one strip image: tile against next tile, in reading order. Undefined (with why) when it cannot be read. */
export function stripMotion(file: string, info: StripInfo): StripMotion | { unmeasured: string } {
  let r: Raster;
  try {
    r = decodePng(fs.readFileSync(file));
  } catch (e) {
    return { unmeasured: `${path.basename(file)}: ${(e as Error).message}` };
  }
  const tw = Math.floor(r.width / info.cols), th = Math.floor(r.height / info.rows);
  if (tw < BLOCK * 4 || th < BLOCK * 4) return { unmeasured: `${path.basename(file)}: ${r.width}x${r.height} is too small for ${info.cols}x${info.rows} tiles` };
  const tiles: Float64Array[] = [];
  for (let i = 0; i < info.count; i++) tiles.push(tileBlocks(r, (i % info.cols) * tw, Math.floor(i / info.cols) * th, tw, th));
  const changed: number[] = [];
  for (let i = 0; i + 1 < tiles.length; i++) changed.push(changedBlocks(tiles[i] as Float64Array, tiles[i + 1] as Float64Array));
  const moved = changed.map((n) => n >= MOVED_BLOCKS);
  let best: StripMotion["longestStill"];
  for (let i = 0; i < moved.length; ) {
    if (moved[i]) { i++; continue; }
    let j = i;
    while (j < moved.length && !moved[j]) j++;
    // pairs i..j-1 still: tiles i..j (0-based) identical; the frames between them are still at least (j - i) * step.
    const frames = (j - i) * info.step;
    if (best === undefined || frames > best.frames) best = { firstTile: i + 1, lastTile: j + 1, fromFrame: info.from + i * info.step, toFrame: info.from + j * info.step, frames };
    i = j;
  }
  return { info, changed, moved, ...(best !== undefined ? { longestStill: best } : {}) };
}

// ---------- the cross-check ----------

export interface FilmFinding {
  kind: "idle" | "contact";
  /** The bot whose claim the film contradicts. */
  bot: string;
  /** The claim: `idle_max_f 37`, or `parried at frame 2269`. */
  claim: string;
  /** The metric contradicted (idle) or the moment kind (contact). */
  metric?: string;
  moment?: string;
  /** What the frames show, in words. */
  measured: string;
  capture: string;
}

export interface FilmCheck {
  /** Strips read and measured. */
  measured: number;
  /** Strips that could not be read, with why (never counted as still). */
  unmeasured: string[];
  findings: FilmFinding[];
  /** Per strip, one line: the longest still run, or that every tile moved. */
  strips: { capture: string; bot?: string; house?: true; contact?: number; still_f?: number; moved: string }[];
  line: string;
}

/** A bot's claims as the cross-check reads them: its `metrics` and its `moments` (kind -> frames). */
export interface BotClaims {
  metrics?: Record<string, unknown>;
  moments?: { kind: string; frame: number }[];
}

/**
 * Sets each strip's motion beside the claims of the bot that was playing it. `claimsOf(bot)` gives the bot's metrics
 * and moments; `resolve(capture)` the image's path. House strips are measured and listed, never judged as claims of
 * this build.
 */
export function crossCheckFilm(strips: { capture: string; label: string }[], claimsOf: (bot: string, house: boolean) => BotClaims, resolve: (capture: string) => string): FilmCheck {
  const out: FilmCheck = { measured: 0, unmeasured: [], findings: [], strips: [], line: "" };
  for (const s of strips) {
    const info = stripInfo(s.capture, s.label);
    if (info === undefined) { out.unmeasured.push(`${s.capture}: its label does not say where its tiles are`); continue; }
    const m = stripMotion(resolve(s.capture), info);
    if ("unmeasured" in m) { out.unmeasured.push(m.unmeasured); continue; }
    out.measured++;
    const still = m.longestStill;
    const movedPairs = m.moved.filter(Boolean).length;
    out.strips.push({ capture: s.capture, ...(info.bot !== undefined ? { bot: info.bot } : {}), ...(info.house === true ? { house: true as const } : {}), ...(info.contact !== undefined ? { contact: info.contact } : {}), ...(still !== undefined ? { still_f: still.frames } : {}), moved: `${movedPairs} of ${m.moved.length} tile steps moved` });
    if (info.bot === undefined) continue;
    const claims = claimsOf(info.bot, info.house === true);
    const idle = claims.metrics?.["idle_max_f"];
    if (still !== undefined && still.frames >= STILL_MIN_F && typeof idle === "number" && Number.isFinite(idle) && idle < still.frames) {
      out.findings.push({ kind: "idle", bot: info.bot, metric: "idle_max_f", claim: `idle_max_f ${idle}`, measured: `tiles ${still.firstTile}-${still.lastTile} of ${path.basename(s.capture)} (frames ${still.fromFrame}-${still.toFrame}) do not change: nothing on screen moves for at least ${still.frames} frames`, capture: s.capture });
    }
    if (info.contact !== undefined && movedPairs === 0) {
      const kinds = (claims.moments ?? []).filter((x) => x.frame === info.contact).map((x) => x.kind);
      const what = kinds.length > 0 ? kinds.join("/") : "a contact";
      out.findings.push({ kind: "contact", bot: info.bot, moment: kinds[0] ?? "contact", claim: `${what} at frame ${info.contact}`, measured: `no tile of the contact strip ${path.basename(s.capture)} (frames ${info.from}-${info.from + info.step * (info.count - 1)}) differs from the one before: no wind-up, no hit, no reaction on film`, capture: s.capture });
    }
  }
  const head = `film check (frame differences of ${out.measured} strip(s)${out.unmeasured.length > 0 ? `; ${out.unmeasured.length} unmeasured` : ""})`;
  out.line = out.findings.length === 0
    ? `${head}: no claim contradicted`
    : `${head}: ${out.findings.length} claim(s) CONTRADICTED by the film: ${out.findings.map((f) => `${f.bot} claims ${f.claim}, but ${f.measured}`).join("; ")}`;
  return out;
}

/**
 * The claims of `bot` (this build's, not the house game's) that the film contradicts: by metric id (idle), the contact
 * moments contradicted, and how many of its contact strips were measured.
 */
export function contradictionsOf(check: FilmCheck | undefined, bot: string): { metrics: Map<string, FilmFinding>; contacts: FilmFinding[]; contactStrips: number } {
  const metrics = new Map<string, FilmFinding>();
  const contacts: FilmFinding[] = [];
  const house = new Set((check?.strips ?? []).filter((x) => x.house === true).map((x) => x.capture));
  for (const f of check?.findings ?? []) {
    if (f.bot !== bot || house.has(f.capture)) continue;
    if (f.kind === "idle" && f.metric !== undefined && !metrics.has(f.metric)) metrics.set(f.metric, f);
    if (f.kind === "contact") contacts.push(f);
  }
  const contactStrips = (check?.strips ?? []).filter((x) => x.bot === bot && x.house !== true && x.contact !== undefined).length;
  return { metrics, contacts, contactStrips };
}

/**
 * A bot's claims from its newest finished report in the log (`before`: only events before that seq, so an old critique
 * is checked against the claims it was judged with): `metrics` and `moments` (top level or `metrics.moments`).
 */
export function botClaims(jobDir: string, events: readonly JobEvent[], bot: string, before = Infinity): BotClaims & { from?: string } {
  for (const e of [...events].reverse()) {
    if (e.seq >= before || e.type !== "verify" || e.verb !== "bot") continue;
    try {
      const r = JSON.parse(fs.readFileSync(path.join(jobDir, e.report), "utf8")) as { bot?: { test?: unknown; done?: unknown; result?: { metrics?: unknown; moments?: unknown } } };
      if (r.bot?.test !== bot || r.bot.done !== true) continue;
      return { ...claimsOfResult(r.bot.result), from: e.report };
    } catch {
      /* an unreadable report is not a claim */
    }
  }
  return {};
}

/** The claims in one bot result object (`bot.result` of a verify report). */
export function claimsOfResult(result: { metrics?: unknown; moments?: unknown } | undefined): BotClaims {
  const m = result?.metrics;
  const metrics = m !== null && typeof m === "object" && !Array.isArray(m) ? (m as Record<string, unknown>) : undefined;
  const raw = resultMoments(result);
  const moments: { kind: string; frame: number }[] = [];
  if (raw !== null && typeof raw === "object" && !Array.isArray(raw)) for (const [kind, v] of Object.entries(raw as Record<string, unknown>)) for (const f of Array.isArray(v) ? v : []) if (typeof f === "number" && Number.isFinite(f)) moments.push({ kind, frame: Math.round(f) });
  return { ...(metrics !== undefined ? { metrics } : {}), ...(moments.length > 0 ? { moments } : {}) };
}

/** What the critic is told: the claims, then what the frames measured, finding by finding. */
export function filmCheckText(check: FilmCheck | undefined): string | undefined {
  if (check === undefined || check.measured === 0) return undefined;
  if (check.findings.length === 0) return `MEASURED FROM THE FILM by the Foreman (frame differences between tiles, ${check.measured} strip(s)): no bot claim is contradicted.`;
  return `MEASURED FROM THE FILM by the Foreman (frame differences between tiles, not a model): ${check.findings.map((f) => `CLAIM CONTRADICTED: ${f.bot} claims ${f.claim}; ${f.measured}`).join(" | ")}. These fail the tofu check and the house compare; say in your notes what the strip shows instead.`;
}
