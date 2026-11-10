// The reference copy <job>/ref/: what a builder may read of the engine (JOB.md, amendments of the second round).
// Built from TL_ENGINE_DIR once per job. An engine without a kit, rigs, a style or seeds (the 20:00 snapshot) gives
// a smaller copy; nothing here fails because a file is absent.
import fs from "node:fs";
import path from "node:path";
import { copyDir } from "./scope.js";
import { toPosix } from "./paths.js";

export interface Reference {
  /** kernel/API.md -> ref/API.md */
  apiDoc?: string;
  /** Example pack directories -> ref/examples/<name>/ */
  examples?: string[];
  /** The kernel's law tables -> ref/data/<name> */
  data?: string[];
  /** The engine's seeds/ directory: README.md and every seed pack in it -> ref/seeds/ (captures are not copied). */
  seedsDir?: string;
  /** Single documents, with their place under ref/ (kits/KIT.md, kits/LAYOUT.md, rigs/RIGS.md, style/STYLE.md). */
  docs?: { src: string; dest: string }[];
}

/** Engine-relative documents copied to the same relative path under ref/, when the engine has them. */
export const REFERENCE_DOCS = ["kits/KIT.md", "kits/LAYOUT.md", "rigs/RIGS.md", "style/STYLE.md"] as const;

/** What an engine directory offers as reference. Reads the directory; never writes there. */
export function referenceOf(engineDir: string): Reference {
  const apiDoc = path.join(engineDir, "kernel", "API.md");
  const examples = ["pack_min", "ex_slide"].map((e) => path.join(engineDir, "kernel", "examples", e)).filter((e) => fs.existsSync(e));
  const data = ["materials.json", "surfaces.json"].map((f) => path.join(engineDir, "kernel", "data", f)).filter((f) => fs.existsSync(f));
  const seedsDir = path.join(engineDir, "seeds");
  const docs = REFERENCE_DOCS.map((d) => ({ src: path.join(engineDir, ...d.split("/")), dest: d })).filter((d) => fs.existsSync(d.src));
  return {
    ...(fs.existsSync(apiDoc) ? { apiDoc } : {}),
    ...(examples.length > 0 ? { examples } : {}),
    ...(data.length > 0 ? { data } : {}),
    ...(fs.existsSync(path.join(seedsDir, "README.md")) || seedPacks(seedsDir).length > 0 ? { seedsDir } : {}),
    ...(docs.length > 0 ? { docs } : {}),
  };
}

export function isEmptyReference(ref: Reference): boolean {
  return !ref.apiDoc && !ref.examples?.length && !ref.data?.length && !ref.seedsDir && !ref.docs?.length;
}

/** Directories directly under seeds/ that hold a pack.json. */
function seedPacks(seedsDir: string): string[] {
  if (!fs.existsSync(seedsDir)) return [];
  return fs
    .readdirSync(seedsDir, { withFileTypes: true })
    .filter((e) => e.isDirectory() && fs.existsSync(path.join(seedsDir, e.name, "pack.json")))
    .map((e) => e.name)
    .sort();
}

/** Copies the reference into `refDir` (once: an existing directory is left alone). */
export function prepareReference(refDir: string, ref: Reference | undefined): void {
  if (!ref || isEmptyReference(ref) || fs.existsSync(refDir)) return;
  fs.mkdirSync(refDir, { recursive: true });
  if (ref.apiDoc && fs.existsSync(ref.apiDoc)) fs.copyFileSync(ref.apiDoc, path.join(refDir, "API.md"));
  for (const ex of ref.examples ?? []) {
    if (fs.existsSync(ex)) copyDir(ex, path.join(refDir, "examples", path.basename(ex)));
  }
  // The law tables API.md points at (materials, surface pairs). The first real builder tried to read them from
  // the engine directory and was refused, so they travel with the reference copy.
  for (const file of ref.data ?? []) {
    if (!fs.existsSync(file)) continue;
    fs.mkdirSync(path.join(refDir, "data"), { recursive: true });
    fs.copyFileSync(file, path.join(refDir, "data", path.basename(file)));
  }
  if (ref.seedsDir && fs.existsSync(ref.seedsDir)) {
    const readme = path.join(ref.seedsDir, "README.md");
    if (fs.existsSync(readme)) {
      fs.mkdirSync(path.join(refDir, "seeds"), { recursive: true });
      fs.copyFileSync(readme, path.join(refDir, "seeds", "README.md"));
    }
    for (const seed of seedPacks(ref.seedsDir)) copyDir(path.join(ref.seedsDir, seed), path.join(refDir, "seeds", seed));
  }
  for (const d of ref.docs ?? []) {
    if (!fs.existsSync(d.src)) continue;
    const dest = path.join(refDir, ...d.dest.split("/"));
    fs.mkdirSync(path.dirname(dest), { recursive: true });
    fs.copyFileSync(d.src, dest);
  }
}

/** What a reference copy holds, by name. */
export interface RefContents {
  api: boolean;
  examples: string[];
  data: string[];
  seedsReadme: boolean;
  seeds: string[];
  /** Present documents among REFERENCE_DOCS. */
  docs: string[];
}

export function refContents(refDir: string): RefContents {
  const ls = (d: string): string[] => (fs.existsSync(d) ? fs.readdirSync(d).sort() : []);
  return {
    api: fs.existsSync(path.join(refDir, "API.md")),
    examples: ls(path.join(refDir, "examples")),
    data: ls(path.join(refDir, "data")),
    seedsReadme: fs.existsSync(path.join(refDir, "seeds", "README.md")),
    seeds: seedPacks(path.join(refDir, "seeds")),
    docs: REFERENCE_DOCS.filter((d) => fs.existsSync(path.join(refDir, ...d.split("/")))),
  };
}

const DOC_LINE: Record<string, string> = {
  "kits/KIT.md": "The kit (`TLKit`): every venue part that already exists, with its params. API.md and the seeds call it res://kits/KIT.md",
  "kits/LAYOUT.md": "The layout contract `tl.layout/1`: a whole venue as one JSON file that one kit call builds (res://kits/LAYOUT.md)",
  "rigs/RIGS.md": "The rigs (`TLRigs`): the animated biped, the vehicle and the bot bodies (res://rigs/RIGS.md)",
  "style/STYLE.md": "The style layer (`TLStyle`): materials, light and the look every pack shares (res://style/STYLE.md)",
};

/** The "Reference material" section of the builder prompt: names what is in ref/ and in which order to read it. */
export function referenceText(refDir: string): string {
  if (!fs.existsSync(refDir)) return "(no reference material was provided for this job)";
  const c = refContents(refDir);
  const at = (...parts: string[]): string => toPosix(path.join(refDir, ...parts));
  const lines: string[] = [];
  const hasKit = c.docs.includes("kits/KIT.md");
  if (c.seedsReadme || c.seeds.length > 0) {
    lines.push("Work in this order:");
    if (c.seedsReadme) lines.push(`1. READ ${at("seeds", "README.md")} FIRST: how a pack is written, and which seed game shows what.`);
    if (c.seeds.length > 0) {
      lines.push(
        `${c.seedsReadme ? "2" : "1"}. COPY THE NEAREST SEED: find the seed game closest to yours (${c.seeds.join(", ")}), read its README.md, data/ and scripts/, and build yours by analogy. Do not start from an empty file.`,
      );
    }
    if (hasKit) {
      lines.push(
        `${c.seedsReadme && c.seeds.length > 0 ? "3" : "2"}. BUILD THE VENUE FROM THE KIT BEFORE MAKING BOXES: write the venue as a layout file (data/*.json, ${at("kits", "LAYOUT.md")}) out of the parts in ${at("kits", "KIT.md")}. Hand-made box meshes are the last resort, for what no kit part covers.`,
      );
    }
    lines.push("");
  }
  lines.push("What is in the reference copy:");
  if (c.seedsReadme) lines.push(`- How to write a pack (start here): ${at("seeds", "README.md")}`);
  for (const s of c.seeds) lines.push(`- Seed game (a complete pack that passes every verifier level): ${at("seeds", s)}/`);
  for (const d of c.docs) lines.push(`- ${DOC_LINE[d] ?? d}: ${at(...d.split("/"))}`);
  if (c.api) lines.push(`- Kernel API (everything a pack script may call, with examples${c.seedsReadme ? "" : "; READ IT FIRST"}): ${at("API.md")}`);
  for (const e of c.examples) lines.push(`- Example pack that passes every verifier level: ${at("examples", e)}/ (pack.json, scripts/, tests/, data/)`);
  if (c.data.length > 0) lines.push(`- The kernel's law tables that API.md calls res://kernel/data/ (${c.data.join(", ")}): ${at("data")}/`);
  if (!hasKit && c.seeds.length === 0) lines.push("This engine has no kit, no rigs, no style layer and no seed games: build from kernel primitives as the example packs do.");
  lines.push("These are read-only reference copies outside your working directory. Read them with your file tools; do not write there.");
  lines.push("The engine directory itself is not readable from here: everything you may use is in these copies. A `res://kits/...`, `res://rigs/...`, `res://style/...` or `res://kernel/...` path in a document is a path your SCRIPTS may load at run time, not a file you can open.");
  return lines.join("\n");
}

/** Names in backticks from the headings of a document (`### \`rink\`` -> rink), in order, without repeats. */
function headingNames(file: string, level: string): string[] {
  if (!fs.existsSync(file)) return [];
  const re = new RegExp(`^${level} \`([^\`]+)\`\\s*$`);
  const out: string[] = [];
  for (const line of fs.readFileSync(file, "utf8").split(/\r?\n/)) {
    const m = re.exec(line);
    if (m && m[1] !== undefined && !out.includes(m[1])) out.push(m[1]);
  }
  return out;
}

/**
 * The Planner's "what already exists" section, read from the reference copy: the kit parts, the layout sections,
 * the rigs, the style and the seed games BY NAME, plus the seeds' own guide. Without a kit and seeds it says so.
 */
export function existingText(refDir: string): string {
  if (!fs.existsSync(refDir)) return "Nothing but the kernel API below: this engine has no kit, no rigs, no style layer and no seed games.";
  const c = refContents(refDir);
  const lines: string[] = [];
  if (c.docs.includes("kits/KIT.md")) {
    const parts = headingNames(path.join(refDir, "kits", "KIT.md"), "###");
    lines.push(`- **The kit** (\`TLKit\`, document \`ref/kits/KIT.md\`): ${parts.length} ready-made venue parts${parts.length > 0 ? `: ${parts.join(", ")}` : ""}.`);
  }
  if (c.docs.includes("kits/LAYOUT.md")) {
    const sections = headingNames(path.join(refDir, "kits", "LAYOUT.md"), "##");
    lines.push(
      `- **The layout contract** (\`tl.layout/1\`, document \`ref/kits/LAYOUT.md\`): a whole venue is ONE JSON file under \`data/\`${sections.length > 0 ? ` (sections: ${sections.join(", ")})` : ""} that one call, \`TLKit.build_layout\`, builds. A venue is data, not script.`,
    );
  }
  if (c.docs.includes("rigs/RIGS.md")) {
    const rigs = headingNames(path.join(refDir, "rigs", "RIGS.md"), "##");
    lines.push(`- **The rigs** (\`TLRigs\`, document \`ref/rigs/RIGS.md\`)${rigs.length > 0 ? `: ${rigs.join(", ")}` : ""}. Animated bodies: nobody models a character or a car from boxes.`);
  }
  if (c.docs.includes("style/STYLE.md")) lines.push("- **The style layer** (`TLStyle`, document `ref/style/STYLE.md`): materials, light and sky that every pack shares; kit parts and rigs already wear it.");
  if (c.seeds.length > 0) {
    lines.push(`- **Seed games** (complete packs that pass every verifier level, under \`ref/seeds/\`): ${c.seeds.join(", ")}. Every builder is told to copy the nearest one.`);
  }
  for (const e of c.examples) lines.push(`- Small example pack: \`ref/examples/${e}/\`.`);
  if (lines.length === 0 || (c.docs.length === 0 && c.seeds.length === 0)) {
    lines.push("This engine has no kit, no rigs, no style layer and no seed games: builders work from the kernel API and the example packs alone.");
  } else {
    lines.push("Write contracts that NAME these: which seed a package starts from, which kit parts and layout sections make the venue, which rig the player is. A contract that asks for hand-built geometry where a kit part exists is a defect of the plan.");
  }
  const readme = path.join(refDir, "seeds", "README.md");
  if (fs.existsSync(readme)) lines.push("", "## The seeds' guide (`ref/seeds/README.md`, the first thing every builder reads)", fs.readFileSync(readme, "utf8").trimEnd());
  return lines.join("\n");
}
