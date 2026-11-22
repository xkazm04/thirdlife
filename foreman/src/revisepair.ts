// D3 of 22 Nov (N4's next-three item 2): a revise round works from a PAIR, not from words alone. The proofs stalled at
// house_game 0.45-0.5 after two rounds of the critic's notes. When a look is sent back and the job has a house game,
// the builder gets (1) the build's own contact strip beside the house game's strip at the same contact kind, copied
// into ref/look/ (builders read ref/), and (2) the diff of the build's contact numbers against the house game's file
// (the duel: data/contacts.json; the hockey: data/tuning.json `hits` and `fun`). Pure apart from reading and copying.
import fs from "node:fs";
import path from "node:path";
import type { GateHost } from "./p10gate.js";
import type { JobEvent } from "./events.js";
import { botMoments } from "./shots.js";
import { stripInfo, claimsOfResult } from "./filmcheck.js";

/** Where a template's house game keeps the numbers of its contacts (a file, optionally only some of its keys). */
export const HOUSE_CONTACTS: Record<string, { file: string; keys?: string[] }[]> = {
  duel: [{ file: "data/contacts.json" }],
  arcade_sport: [{ file: "data/tuning.json", keys: ["hits", "fun"] }],
};

/** Every number of a JSON value by its dotted path (arrays by index); `_about` and other strings are left out. */
export function numberLeaves(o: unknown, prefix = "", out = new Map<string, number>()): Map<string, number> {
  if (typeof o === "number" && Number.isFinite(o)) out.set(prefix, o);
  else if (o !== null && typeof o === "object") for (const [k, v] of Object.entries(o as Record<string, unknown>)) numberLeaves(v, prefix === "" ? k : `${prefix}.${k}`, out);
  return out;
}

const readJson = (file: string): unknown => {
  try {
    return JSON.parse(fs.readFileSync(file, "utf8").replace(/^﻿/, ""));
  } catch {
    return undefined;
  }
};

const pick = (o: unknown, keys?: string[]): unknown => (keys === undefined || o === null || typeof o !== "object" ? o : Object.fromEntries(keys.filter((k) => k in (o as object)).map((k) => [k, (o as Record<string, unknown>)[k]])));

/** The build's contact numbers against the house game's, row by row: differing, missing in the build. */
export function contactDiff(buildPack: string, housePack: string, template: string, pack: string, max = 14): { differ: string[]; missing: string[]; line: string } | undefined {
  const sources = HOUSE_CONTACTS[template];
  if (sources === undefined) return undefined;
  const differ: string[] = [];
  const missing: string[] = [];
  const notes: string[] = [];
  for (const s of sources) {
    const house = readJson(path.join(housePack, ...s.file.split("/")));
    if (house === undefined) continue;
    const built = readJson(path.join(buildPack, ...s.file.split("/")));
    const hl = numberLeaves(pick(house, s.keys));
    if (built === undefined) {
      notes.push(`the build has no ${s.file}: the house game keeps ${hl.size} contact numbers there${s.keys ? ` (${s.keys.join(", ")})` : ""}`);
      continue;
    }
    const bl = numberLeaves(pick(built, s.keys));
    for (const [k, v] of hl) {
      const b = bl.get(k);
      if (b === undefined) missing.push(`${s.file} ${k} (house ${v})`);
      else if (b !== v) differ.push(`${s.file} ${k}: yours ${b}, house ${v}`);
    }
  }
  if (differ.length + missing.length + notes.length === 0) return { differ, missing, line: `contact numbers: yours match engine/packs/${pack} on every row of ${sources.map((s) => s.file).join(", ")}` };
  const cut = (xs: string[]): string => `${xs.slice(0, max).join("; ")}${xs.length > max ? `; and ${xs.length - max} more` : ""}`;
  const line = [
    ...notes,
    differ.length > 0 ? `${differ.length} contact number(s) differ from engine/packs/${pack}: ${cut(differ)}` : "",
    missing.length > 0 ? `${missing.length} house contact row(s) your pack does not have: ${cut(missing)}` : "",
  ].filter(Boolean).join(". ");
  return { differ, missing, line };
}

/** Two moment kinds of one family: the same word up to its ending (poke/poked, parry/parried, one_timer). */
export const sameKind = (a: string, b: string): boolean => a === b || (a.length >= 4 && b.length >= 4 && a.slice(0, 4).toLowerCase() === b.slice(0, 4).toLowerCase());

/** The kind of the house strip's contact: the drill report's moment at the strip's contact frame. */
export function houseStripKind(jobDir: string, pack: string, frame: number): string | undefined {
  const dir = path.join(jobDir, "reports");
  const files = fs.existsSync(dir) ? fs.readdirSync(dir).filter((f) => new RegExp(`^house-${pack}-drill-s\\d+\\.json$`).test(f)) : [];
  for (const f of files.sort().reverse()) {
    const r = readJson(path.join(dir, f)) as { bot?: { result?: { metrics?: unknown; moments?: unknown } } } | undefined;
    const kind = claimsOfResult(r?.bot?.result).moments?.find((m) => m.frame === frame)?.kind;
    if (kind !== undefined) return kind;
  }
  return undefined;
}

export interface Pair {
  kind?: string;
  same: boolean;
  build: { capture: string; kind?: string };
  house: { capture: string; kind?: string };
}

/** The build's contact strip to set beside the house strip: the same kind first, else its first contact strip. */
export function pairStrips(jobDir: string, events: readonly JobEvent[], strips: { capture: string; label: string }[], house: { capture: string; label: string }, houseKind: string | undefined): Pair | undefined {
  const contacts = strips.map((s) => ({ s, info: stripInfo(s.capture, s.label) })).filter((x) => x.info?.contact !== undefined && x.info.bot !== undefined);
  if (contacts.length === 0) return undefined;
  const kinded = contacts.map((x) => ({ ...x, kind: botMoments(jobDir, events, x.info?.bot as string).find((m) => m.frame === x.info?.contact)?.kind }));
  const match = houseKind !== undefined ? kinded.find((x) => x.kind !== undefined && sameKind(x.kind, houseKind)) : undefined;
  const chosen = match ?? kinded[0];
  if (chosen === undefined) return undefined;
  return { ...(houseKind !== undefined ? { kind: houseKind } : {}), same: match !== undefined, build: { capture: chosen.s.capture, ...(chosen.kind !== undefined ? { kind: chosen.kind } : {}) }, house: { capture: house.capture, ...(houseKind !== undefined ? { kind: houseKind } : {}) } };
}

/**
 * The pair for revise round `round`: both strips copied into ref/look/<m>-r<round>/ (the builder's readable reference),
 * and the text the round's feedback carries. Undefined when the job has no house strip or no contact strip of its own.
 */
export function revisePair(h: GateHost, m: string, round: number, strips: { capture: string; label: string }[], base: { pack: string; strips?: { capture: string; label: string }[] } | undefined, template: string | undefined): string | undefined {
  if (base === undefined || template === undefined) return undefined;
  const houseStrip = (base.strips ?? []).find((x) => fs.existsSync(h.dir(...x.capture.split("/"))));
  const contactF = houseStrip !== undefined ? stripInfo(houseStrip.capture, houseStrip.label)?.contact : undefined;
  const pair = houseStrip !== undefined ? pairStrips(h.dir(), h.events, strips, houseStrip, contactF !== undefined ? houseStripKind(h.dir(), base.pack, contactF) : undefined) : undefined;
  const diff = contactDiff(h.dir("pack"), h.dir("ref", "packs", base.pack), template, base.pack);
  const parts: string[] = [];
  if (pair !== undefined) {
    const rel = `look/${m}-r${round}`;
    const dest = h.dir("ref", ...rel.split("/"));
    fs.mkdirSync(dest, { recursive: true });
    const name = (who: string, kind: string | undefined): string => `${who}-${(kind ?? "contact").replace(/[^A-Za-z0-9_-]/g, "_")}.png`;
    const yours = name("yours", pair.build.kind), theirs = name("house", pair.house.kind);
    fs.copyFileSync(h.dir(...pair.build.capture.split("/")), path.join(dest, yours));
    fs.copyFileSync(h.dir(...pair.house.capture.split("/")), path.join(dest, theirs));
    parts.push(`THE PAIR (open both with your Read tool before you change code): ref/${rel}/${yours} is YOUR contact strip${pair.build.kind ? ` (${pair.build.kind})` : ""}, ref/${rel}/${theirs} the HOUSE GAME's${pair.house.kind ? ` (${pair.house.kind})` : ""}, both 12 tiles 2 frames apart around the contact, read left to right. ${pair.same ? "Same contact kind: make yours read like the house one (wind-up, hit-stop on both bodies, each body's own reaction)." : `Your bot filmed no ${pair.kind ?? "matching"} contact: this is your nearest; make the house game's kind happen and read like its strip.`}`);
  }
  if (diff !== undefined) parts.push(diff.line);
  return parts.length > 0 ? parts.join(" ") : undefined;
}
