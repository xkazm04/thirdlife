// What the Designer is told about the engine (L2 of 21 Nov, the feasibility guard): every aspect it proposes must be
// something the kernel and the kit can do. Read from an engine directory, never written. A missing file gives a
// shorter text, not an error: the Designer of an engine without API.md still answers (and says less).
import fs from "node:fs";
import path from "node:path";
import { readCards } from "./cards.js";
import { stripBom } from "./paths.js";

/** The sections of kernel/API.md the Designer reads whole: start here, cameras, the helpers (juice), what is not there yet. */
const API_SECTIONS = [/^## 0\. /, /^## 12\. /, /^## 13\. /, /^## 17\. /];

function sections(text: string, wanted: RegExp[]): { headings: string[]; picked: string } {
  const lines = text.split(/\r?\n/);
  const headings = lines.filter((l) => /^## \d+\. /.test(l)).map((l) => l.replace(/^## /, ""));
  const out: string[] = [];
  let on = false;
  for (const l of lines) {
    if (/^## /.test(l)) on = wanted.some((re) => re.test(l));
    if (on) out.push(l);
  }
  return { headings, picked: out.join("\n").trim() };
}

/** The kit's part list (kits/KIT.md "Parts" table): kind and what it is, one line each. */
function kitParts(kitMd: string): string[] {
  const out: string[] = [];
  for (const l of kitMd.split(/\r?\n/)) {
    const m = /^\| `([a-z_]+)` \|[^|]*\|[^|]*\|[^|]*\|[^|]*\| (.+?) \|$/.exec(l);
    if (m) out.push(`${m[1]}: ${(m[2] as string).split(". ")[0]}`);
  }
  return out;
}

/** The engine as the Designer reads it: the map of the kernel API, the parts of the kit, the four sections above. */
export function designerEngineText(engineDir: string | undefined): string {
  if (engineDir === undefined) return "(no engine directory was given: design with bipeds, vehicles, balls, cameras, effects, sound, a HUD and simple kit parts only)";
  const parts: string[] = [];
  const api = path.join(engineDir, "kernel", "API.md");
  if (fs.existsSync(api)) {
    const { headings, picked } = sections(stripBom(fs.readFileSync(api, "utf8")), API_SECTIONS);
    parts.push("## The kernel API, section by section (what exists)", ...headings.map((h) => `- ${h}`), "", picked);
  }
  const kit = path.join(engineDir, "kits", "KIT.md");
  if (fs.existsSync(kit)) {
    const list = kitParts(stripBom(fs.readFileSync(kit, "utf8")));
    if (list.length > 0) parts.push("", "## Kit parts (`TLKit.build(kind, params)`): every object in a venue is one of these or a plain body", ...list.map((l) => `- ${l}`));
  }
  return parts.length > 0 ? parts.join("\n") : "(the engine directory has no kernel/API.md and no kits/KIT.md)";
}

/** The recipe cards as the Designer reads them: the kind of game, when it applies, and the `fun` block (CARDS.md 2026-11-20). */
export function designerCardsText(engineDir: string | undefined): string {
  if (engineDir === undefined) return "(no recipe cards)";
  const cards = readCards(path.join(engineDir, "cards")).map((c) => c.card as unknown as {
    id: string;
    title: string;
    summary: string;
    fun?: Record<string, string[]>;
  });
  if (cards.length === 0) return "(no recipe cards)";
  const out: string[] = [];
  for (const c of cards) {
    out.push(`- ${c.id}: ${c.title}. ${c.summary}`);
    for (const [k, v] of Object.entries(c.fun ?? {})) out.push(`  - fun, ${k.replace(/_/g, " ")}: ${v.join("; ")}`);
  }
  return out.join("\n");
}
