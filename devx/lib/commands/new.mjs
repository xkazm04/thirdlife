export const summary = "scaffold: `tl new pack <name> [--out dir]`, `tl new bot <name> [--pack dir]`, `tl new kitpart <kind>` (prints the recipe)";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { ENGINE, posix } from "../ctx.mjs";

const TEMPLATES = path.join(path.dirname(fileURLToPath(import.meta.url)), "..", "..", "templates");
const NAME_RE = /^[a-z][a-z0-9_]*$/;

const fill = (text, vars) => text.replace(/\{\{(\w+)\}\}/g, (_, k) => vars[k] ?? `{{${k}}}`);
const titleCase = (n) => n.split("_").map((w) => w[0].toUpperCase() + w.slice(1)).join(" ");

/** Copies the template tree into dest, substituting {{vars}}; tests/bot.gd becomes tests/bot_<name>.gd. */
export function scaffoldPack(name, dest) {
  const vars = { name, title: titleCase(name) };
  const src = path.join(TEMPLATES, "pack");
  const written = [];
  const walk = (d, rel = "") => {
    for (const e of fs.readdirSync(path.join(d, rel), { withFileTypes: true })) {
      const r = path.join(rel, e.name);
      if (e.isDirectory()) { walk(d, r); continue; }
      const outRel = r === path.join("tests", "bot.gd") ? path.join("tests", `bot_${name}.gd`) : r;
      const out = path.join(dest, outRel);
      fs.mkdirSync(path.dirname(out), { recursive: true });
      fs.writeFileSync(out, fill(fs.readFileSync(path.join(d, r), "utf8"), vars));
      written.push(posix(outRel));
    }
  };
  walk(src);
  return written;
}

/** Adds tests/bot_<name>.gd to an existing pack and registers it in the manifest `tests`. */
export function scaffoldBot(name, packDir) {
  const manifestPath = path.join(packDir, "pack.json");
  const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
  const relTest = `tests/bot_${name}.gd`;
  const out = path.join(packDir, relTest);
  if (fs.existsSync(out)) throw new Error(`${posix(out)} already exists`);
  fs.mkdirSync(path.dirname(out), { recursive: true });
  fs.writeFileSync(out, fill(fs.readFileSync(path.join(TEMPLATES, "bot", "bot.gd"), "utf8"), { name }));
  manifest.tests = [...(manifest.tests ?? []), relTest];
  fs.writeFileSync(manifestPath, JSON.stringify(manifest, null, 2) + "\n");
  return relTest;
}

/** The recipe of engine/kits/KIT.md "Adding a part", as a checklist. Reads the numbered steps from the file so it cannot drift. */
export function kitpartRecipe(kind) {
  const kit = path.join(ENGINE, "kits", "KIT.md");
  const text = fs.existsSync(kit) ? fs.readFileSync(kit, "utf8") : "";
  const m = text.replace(/\r/g, "").match(/## Adding a part\n([\s\S]*?)(?=\n## )/);
  const body = m ? m[1].trim().split(/\nThe part /)[0] : "";
  const steps = body ? body.split(/\n(?=\d+\. )/).map((s) => s.replace(/^\d+\.\s*/, "").replace(/\s*\n\s+/g, " ")) : [];
  const lines = [`Recipe for a new kit part '${kind}' (source: engine/kits/KIT.md, "Adding a part"). This command edits nothing.`, ""];
  if (!steps.length) lines.push("[ ] (could not read the recipe from engine/kits/KIT.md; open it)");
  for (const s of steps) lines.push(`[ ] ${s}`);
  lines.push(`[ ] kind name: '${kind}' (lower snake case, unique in TLKit.PARTS)`, "[ ] tools/k.sh docs regenerates the generated tables in KIT.md; commit that too");
  return lines.join("\n");
}

export async function run(args) {
  const rest = [];
  let out = null, packOpt = null;
  for (let i = 0; i < args.length; i++) {
    const a = args[i];
    if (a === "--out") out = args[++i]; else if (a.startsWith("--out=")) out = a.slice(6);
    else if (a === "--pack") packOpt = args[++i]; else if (a.startsWith("--pack=")) packOpt = a.slice(7);
    else rest.push(a);
  }
  const [kind, name] = rest;
  const usage = "usage: tl new pack <name> [--out <dir>] | tl new bot <name> [--pack <dir>] | tl new kitpart <kind>";
  if (!kind || !name) { console.error(usage); return 2; }
  if (!NAME_RE.test(name)) { console.error(`tl new: '${name}' must match ${NAME_RE} (lower snake case)`); return 2; }
  try {
    if (kind === "pack") {
      const dest = path.resolve(out ?? path.join(ENGINE, "packs", name));
      if (fs.existsSync(dest) && fs.readdirSync(dest).length) { console.error(`tl new: ${posix(dest)} exists and is not empty`); return 2; }
      const files = scaffoldPack(name, dest);
      console.log(`created pack game.${name} at ${posix(dest)}\n  ${files.join("\n  ")}\nnext: node devx/bin/tl.mjs watch --pack ${posix(dest)}`);
      return 0;
    }
    if (kind === "bot") {
      const packDir = path.resolve(packOpt ?? ".");
      if (!fs.existsSync(path.join(packDir, "pack.json"))) { console.error(`tl new bot: no pack.json in ${posix(packDir)}; pass --pack <dir>`); return 2; }
      const t = scaffoldBot(name, packDir);
      console.log(`created ${t} and registered it in ${posix(path.join(packDir, "pack.json"))} (tests)\nrun it: bash engine/tools/tl.sh bot --pack=${posix(packDir)} --test=${t}`);
      return 0;
    }
    if (kind === "kitpart") { console.log(kitpartRecipe(name)); return 0; }
  } catch (e) { console.error(`tl new: ${e.message}`); return 2; }
  console.error(`tl new: unknown kind '${kind}'. ${usage}`);
  return 2;
}
