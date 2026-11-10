// Rules 1 and 2: module walls and class-name prefixes. Both read GDScript with comments and strings blanked, so a
// word in a comment or a quoted label is never a finding.
import { stripGd, classNames, lineAt, under } from "./util.mjs";

const gdIn = (io, dirs) => io.files.filter((f) => f.endsWith(".gd") && dirs.some((d) => under(f, d)));
const classesIn = (io, dirs) => new Set(gdIn(io, dirs).flatMap((f) => classNames(io.read(f)).map((c) => c.name)));

/** Pack-side directories: seeds, runtime packs, and the non-`bad_` examples (the bad_* ones are deliberate negatives). */
export function isPackFile(f, p) {
  if (!f.endsWith(".gd")) return false;
  if (p.packGlobs.seeds && /^engine\/seeds\/[^/]+\//.test(f)) return true;
  if (/^engine\/packs\/[^/]+\//.test(f)) return true;
  const m = /^engine\/kernel\/examples\/([^/]+)\//.exec(f);
  return !!m && !m[1].startsWith("bad_");
}

// Mirrors BYPASS_STYLE in engine/kernel/runner/lint.gd (the runner stays the authority; this catches it at commit time).
const STYLE_BYPASS = /\b(StandardMaterial3D|ShaderMaterial|ORMMaterial3D|DirectionalLight3D|OmniLight3D|SpotLight3D|WorldEnvironment|Environment)\s*\.\s*new\s*\(/g;

export function moduleWalls(io, rule) {
  const p = { selfContained: ["engine/kits", "engine/rigs", "engine/style"], publicDirs: ["engine/kernel/api", "engine/kernel/standin", "engine/kits", "engine/rigs", "engine/style"], packGlobs: { seeds: true }, ...(rule.params ?? {}) };
  const findings = [];
  const own = classesIn(io, p.selfContained);
  // A: kits, rigs and style reference nothing outside themselves
  for (const f of gdIn(io, p.selfContained)) {
    const src = io.read(f);
    const code = stripGd(src);
    for (const m of code.matchAll(/\bTL[A-Za-z0-9_]*/g)) {
      if (!own.has(m[0])) findings.push({ file: f, line: lineAt(code, m.index), key: `${f}:${m[0]}`, message: `${m[0]} is outside kits/rigs/style (KIT.md: these three reference nothing outside themselves)` });
    }
    const withStrings = stripGd(src, true);
    for (const m of withStrings.matchAll(/res:\/\/([^"'\s)]*)/g)) {
      if (!/^(kits|rigs|style)(\/|$)/.test(m[1])) findings.push({ file: f, line: lineAt(withStrings, m.index), key: `${f}:res://${m[1]}`, message: `res://${m[1]} points outside kits/rigs/style` });
    }
    for (const m of withStrings.matchAll(/\b(?:load|preload)\s*\(\s*["'][^"']*\.\.\//g)) {
      findings.push({ file: f, line: lineAt(withStrings, m.index), key: `${f}:..`, message: "relative ../ load leaves the module" });
    }
  }
  // B: packs and seeds use public TL classes only, never declare a class_name, never make materials, lights or environments
  const pub = classesIn(io, p.publicDirs);
  for (const f of io.files.filter((x) => isPackFile(x, p))) {
    const code = stripGd(io.read(f));
    for (const c of classNames(io.read(f))) findings.push({ file: f, line: c.line, key: `${f}:class_name`, message: `pack script declares class_name ${c.name} (contracts/README.md: pack scripts never use class_name)` });
    for (const m of code.matchAll(/\bTL[A-Za-z0-9_]*/g)) {
      if (!pub.has(m[0])) findings.push({ file: f, line: lineAt(code, m.index), key: `${f}:${m[0]}`, message: `${m[0]} is not a public TL class (kernel/api, kits, rigs, style)` });
    }
    for (const m of code.matchAll(STYLE_BYPASS)) {
      findings.push({ file: f, line: lineAt(code, m.index), key: `${f}:${m[1]}`, message: `${m[1]}.new(): packs get materials, light and environment from the style layer (lint bypass 'style')` });
    }
  }
  return { findings };
}

/** Rule 2. params.allocation: [{dir, prefixes}] gives a directory the prefixes only it may use; everything else under
 *  params.scan must start with `base` and with none of the reserved prefixes. */
export function classPrefixes(io, rule) {
  const p = {
    scan: ["engine"], skip: ["engine/seeds", "engine/packs", "engine/kernel/examples"], base: "TL",
    allocation: [{ dir: "engine/kits", prefixes: ["TLKit", "TLMesh"] }, { dir: "engine/rigs", prefixes: ["TLRig"] }, { dir: "engine/style", prefixes: ["TLStyle"] }],
    ...(rule.params ?? {}),
  };
  const reserved = p.allocation.flatMap((a) => a.prefixes);
  const findings = [];
  const seen = new Map();
  for (const f of gdIn(io, p.scan)) {
    for (const c of classNames(io.read(f))) {
      if (seen.has(c.name)) findings.push({ file: f, line: c.line, key: `dup:${c.name}`, message: `duplicate class_name ${c.name} (also ${seen.get(c.name)})` });
      else seen.set(c.name, `${f}:${c.line}`);
      if (p.skip.some((d) => under(f, d))) continue;
      const owner = p.allocation.find((a) => under(f, a.dir));
      if (owner) {
        if (!owner.prefixes.some((x) => c.name.startsWith(x))) findings.push({ file: f, line: c.line, key: `${f}:${c.name}`, message: `${c.name} in ${owner.dir} must start with ${owner.prefixes.join(" or ")}` });
      } else if (!c.name.startsWith(p.base)) {
        findings.push({ file: f, line: c.line, key: `${f}:${c.name}`, message: `${c.name} must start with ${p.base}` });
      } else if (reserved.some((x) => c.name.startsWith(x))) {
        findings.push({ file: f, line: c.line, key: `${f}:${c.name}`, message: `${c.name} uses a prefix reserved for kits/rigs/style (contracts/README.md)` });
      }
    }
  }
  // duplicates inside skipped dirs are still duplicates; the loop above already recorded them
  return { findings };
}
