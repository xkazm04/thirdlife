// Rules 4 and 5: the verb list agrees everywhere it is written down; every schema string is declared in contracts/.
import { stripGd, lineAt } from "./util.mjs";

/** Parses `const NAME: Dictionary = { "key": ["a", "b"], ... }` from GDScript. Exact for the flat one-line-per-key shape
 *  host.gd uses; anything else inside the braces (a multi-line array, a nested dict, an expression) is returned in
 *  `unparsed` rather than guessed at. Comments are stripped first, so a `#` note after a row is fine. */
export function parseGdArrayDict(src, name) {
  const lines = src.replace(/\r\n/g, "\n").split("\n");
  const start = lines.findIndex((l) => new RegExp(`^const\\s+${name}\\b[^=]*=\\s*\\{`).test(l));
  if (start < 0) return { found: false, map: {}, unparsed: [] };
  const map = {}, unparsed = [];
  for (let i = start + 1; i < lines.length; i++) {
    const code = stripGd(lines[i], true).trim();
    if (code === "}") return { found: true, map, unparsed, line: start + 1 };
    if (!code) continue;
    const m = /^"([\w-]+)"\s*:\s*\[([^\]]*)\]\s*,?$/.exec(code) ?? /^"([\w-]+)"\s*:\s*"([^"]*)"\s*,?$/.exec(code);
    if (!m) { unparsed.push({ line: i + 1, text: code }); continue; }
    map[m[1]] = code.includes("[") ? [...m[2].matchAll(/"([^"]*)"/g)].map((x) => x[1]) : m[2];
  }
  return { found: true, map, unparsed: [...unparsed, { line: start + 1, text: "dictionary never closes" }] };
}

/** Rule 4. verbs.json vs host.gd OPTIONS and LEVELS, RUNNER.md, and the tl.sh usage header. */
export function verbsContract(io, rule) {
  const p = { verbs: "engine/kernel/runner/verbs.json", host: "engine/kernel/host/host.gd", doc: "contracts/RUNNER.md", sh: "engine/tools/tl.sh", ...(rule.params ?? {}) };
  const findings = [];
  const add = (file, message, key, line) => findings.push({ file, line, key: key ?? `${file}:${message}`, message });
  let verbs;
  try { verbs = JSON.parse(io.read(p.verbs)).verbs; } catch (e) { return { findings: [{ file: p.verbs, key: "verbs.json", message: `cannot read verbs.json: ${e.message}` }] }; }
  const host = io.has(p.host) ? io.read(p.host) : "";
  const opts = parseGdArrayDict(host, "OPTIONS");
  if (!opts.found) add(p.host, "const OPTIONS dictionary not found", "options-missing");
  for (const u of opts.unparsed) add(p.host, `OPTIONS row not parseable as one-line "verb": [options] (${u.text}); the static check cannot vouch for it`, `unparsed:${u.line}`, u.line);
  const levels = parseGdArrayDict(host.replace(/^const LEVELS: Dictionary = \{(.*)\}\s*$/m, (_, b) => `const LEVELS: Dictionary = {\n${b.split(",").join(",\n")}\n}`), "LEVELS");
  if (opts.found && !opts.unparsed.length) {
    for (const [v, spec] of Object.entries(verbs)) {
      const want = Object.keys(spec.options ?? {}).sort();
      if (!(v in opts.map)) { add(p.host, `verb '${v}' is in verbs.json but not in host.gd OPTIONS`, `host-missing:${v}`, opts.line); continue; }
      const got = [...opts.map[v]].sort();
      for (const o of want) if (!got.includes(o)) add(p.host, `verb '${v}': option --${o} is in verbs.json but not in host.gd OPTIONS`, `host-opt:${v}:${o}`, opts.line);
      for (const o of got) if (!want.includes(o)) add(p.host, `verb '${v}': option --${o} is in host.gd OPTIONS but not in verbs.json`, `host-extra:${v}:${o}`, opts.line);
    }
    for (const v of Object.keys(opts.map)) if (!(v in verbs)) add(p.host, `verb '${v}' is in host.gd OPTIONS but not in verbs.json`, `host-extra-verb:${v}`, opts.line);
  }
  if (levels.found) {
    for (const [v, spec] of Object.entries(verbs)) if (levels.map[v] !== undefined && levels.map[v] !== spec.level) add(p.host, `verb '${v}': LEVELS says ${levels.map[v]}, verbs.json says ${spec.level}`, `level:${v}`, levels.line);
  }
  const doc = io.has(p.doc) ? io.read(p.doc) : "";
  const sh = io.has(p.sh) ? io.read(p.sh) : "";
  const shVerbs = new Set([...sh.matchAll(/^#\s+tl\.sh\s+([a-z-]+)/gm)].map((m) => m[1]));
  const shHeader = sh.split("\n").filter((l) => l.startsWith("#")).join("\n");
  for (const [v, spec] of Object.entries(verbs)) {
    if (!new RegExp("`" + v + "`").test(doc)) add(p.doc, `verb '${v}' is not documented in ${p.doc}`, `doc-verb:${v}`);
    for (const o of Object.keys(spec.options ?? {})) {
      if (o === "pack" || o === "report") continue;       // common to every verb, documented once at the top
      if (!doc.includes(`--${o}`)) add(p.doc, `verb '${v}': option --${o} is not documented in ${p.doc}`, `doc-opt:${o}`);
    }
    if (!shVerbs.has(v)) add(p.sh, `verb '${v}' is missing from the usage header of ${p.sh}`, `sh-verb:${v}`);
    else for (const o of Object.keys(spec.options ?? {})) {
      if (o === "report") continue;                       // the header says once that every verb takes --report
      if (!shHeader.includes(`--${o}`)) add(p.sh, `option --${o} (verb '${v}') is missing from the usage header of ${p.sh}`, `sh-opt:${o}`);
    }
  }
  return { findings, notes: [`${Object.keys(verbs).length} verbs`] };
}

const TEXT_EXT = /\.(gd|ts|mjs|js|json|md|sh|py|tscn|tres|cfg)$/;

/** Rule 5. Every `tl.<name>/<n>` in params.scan must also appear in a file under params.declared (contracts/). */
export function schemaVersions(io, rule) {
  const p = { scan: ["engine/", "foreman/src/", "contracts/"], declared: "contracts/", ...(rule.params ?? {}) };
  const re = /\btl\.([a-z][a-z0-9_]*)\/(\d+)\b/g;
  const declared = new Set();
  for (const f of io.files) if (f.startsWith(p.declared) && TEXT_EXT.test(f)) for (const m of io.read(f).matchAll(re)) declared.add(m[0]);
  const used = new Map();
  for (const f of io.files) {
    if (!TEXT_EXT.test(f) || !p.scan.some((d) => f.startsWith(d))) continue;
    const src = io.read(f);
    for (const m of src.matchAll(re)) {
      if (!used.has(m[0])) used.set(m[0], []);
      used.get(m[0]).push(`${f}:${lineAt(src, m.index)}`);
    }
  }
  const findings = [];
  for (const [s, where] of [...used].sort()) {
    if (declared.has(s)) continue;
    const [file, line] = [where[0].replace(/:\d+$/, ""), Number(where[0].replace(/^.*:/, ""))];
    findings.push({ file, line, key: s, message: `schema '${s}' is used (${where.length} place(s)) but declared in no ${p.declared} doc` });
  }
  return { findings, notes: [`used: ${[...used.keys()].sort().join(", ")}`] };
}
