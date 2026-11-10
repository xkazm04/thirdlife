// Asset hygiene: the rules every FOREIGN file must pass before it is allowed near a build or a player's machine.
// Reusable and dependency-free: the asset spine (`tl assets check`) uses it today; a pack installer can use the same
// three functions on an unpacked archive tomorrow.
//   checkPath(rel, {ownerDir})        a manifest/archive path: relative, no "..", no drive, no backslash, inside ownerDir
//   checkFile(abs, {kind, maxBytes})  one file: not a link, extension allowed for its kind, not executable, size cap
//   checkTree(dirAbs, {maxBytes})     a whole directory: every file passes the kind-independent rules
// All three return arrays of human-readable problems (empty = clean); none throws on bad input.
import fs from "node:fs";
import path from "node:path";

/** Extensions an imported file of each kind may have. Resource formats that can embed scripts (.tres .tscn .res) are absent on purpose. */
export const EXT_ALLOW = {
  kit_part: [],
  mesh: [".glb", ".gltf", ".obj", ".vox", ".vxm"],
  texture: [".png", ".jpg", ".jpeg", ".webp", ".ktx2"],
  audio: [".ogg", ".wav", ".mp3"],
  material: [".json"],
  rig: [".json"],
  data: [".json"],
};

/** Never acceptable in an asset directory, whatever the kind: code, binaries, installers, scene/resource files that can carry scripts. */
export const EXT_DENY = [".gd", ".dll", ".exe", ".sh", ".bat", ".so", ".cmd", ".ps1", ".dylib", ".com", ".msi", ".vbs", ".js", ".mjs", ".py",
  ".jar", ".apk", ".gdextension", ".tscn", ".tres", ".res", ".scn", ".pck"];

/** Hard ceiling for any single file, independent of budgets (a budget can only be stricter). */
export const HARD_MAX_FILE_BYTES = 64 * 1024 * 1024;

const MAGIC = [
  [[0x4d, 0x5a], "Windows executable (MZ)"],
  [[0x7f, 0x45, 0x4c, 0x46], "ELF executable"],
  [[0x23, 0x21], "script with a shebang"],
  [[0xcf, 0xfa, 0xed, 0xfe], "Mach-O executable"],
  [[0xce, 0xfa, 0xed, 0xfe], "Mach-O executable"],
  [[0xca, 0xfe, 0xba, 0xbe], "Mach-O / Java class"],
];

export const extOf = (p) => path.posix.extname(String(p).replace(/\\/g, "/")).toLowerCase();

/** `ownerDir` is a repo-relative directory with a trailing slash, e.g. "assets/engine/". Pass null to skip the containment rule. */
export function checkPath(rel, { ownerDir = null } = {}) {
  const out = [];
  if (typeof rel !== "string" || rel === "") return ["path is empty or not a string"];
  if (/[\u0000-\u001f]/.test(rel)) out.push(`path ${JSON.stringify(rel)} has a control character`);
  if (rel.includes("\\")) out.push(`path '${rel}' uses a backslash`);
  if (rel.startsWith("/") || /^[A-Za-z]:/.test(rel) || rel.startsWith("\\\\")) out.push(`path '${rel}' is absolute`);
  if (rel.split(/[\\/]/).includes("..")) out.push(`path '${rel}' contains '..'`);
  if (/^[a-z]+:\/\//i.test(rel)) out.push(`path '${rel}' is a URL, not a file path`);
  if (out.length === 0 && ownerDir) {
    const norm = path.posix.normalize(rel);
    if (!norm.startsWith(ownerDir) || norm.length === ownerDir.length) out.push(`path '${rel}' is outside the owner's directory '${ownerDir}'`);
  }
  return out;
}

/** One file on disk. `kind` (optional) adds the per-kind extension allowlist. */
export function checkFile(abs, { kind = null, maxBytes = HARD_MAX_FILE_BYTES } = {}) {
  const out = [];
  const name = path.basename(abs);
  let st;
  try { st = fs.lstatSync(abs); } catch { return [`${name}: file does not exist`]; }
  if (st.isSymbolicLink()) return [`${name}: is a symbolic link`];
  if (!st.isFile()) return [`${name}: is not a regular file`];
  const ext = extOf(name);
  if (EXT_DENY.includes(ext)) out.push(`${name}: extension '${ext}' is executable or script content and never allowed in an asset directory`);
  else if (kind) {
    const allow = EXT_ALLOW[kind];
    if (!allow) out.push(`${name}: unknown kind '${kind}'`);
    else if (!allow.includes(ext)) out.push(`${name}: extension '${ext || "(none)"}' is not allowed for kind '${kind}' (allowed: ${allow.join(" ") || "none, procedural only"})`);
  }
  const cap = Math.min(maxBytes, HARD_MAX_FILE_BYTES);
  if (st.size > cap) out.push(`${name}: ${st.size} bytes exceeds the single-file limit of ${cap}`);
  try {
    const fd = fs.openSync(abs, "r");
    const buf = Buffer.alloc(4);
    const n = fs.readSync(fd, buf, 0, 4, 0);
    fs.closeSync(fd);
    for (const [sig, label] of MAGIC) if (n >= sig.length && sig.every((b, i) => buf[i] === b)) out.push(`${name}: content is a ${label}, whatever its extension says`);
  } catch (e) { out.push(`${name}: unreadable (${e.message})`); }
  return out;
}

/** Every file below dirAbs. Returns {files: [path relative to dirAbs, posix], problems}. Links are reported, never followed. */
export function checkTree(dirAbs, { maxBytes = HARD_MAX_FILE_BYTES } = {}) {
  const files = [];
  const problems = [];
  const walk = (d, relDir) => {
    let ents;
    try { ents = fs.readdirSync(d, { withFileTypes: true }); } catch (e) { problems.push(`${relDir || "."}: unreadable directory (${e.message})`); return; }
    ents.sort((a, b) => (a.name < b.name ? -1 : 1));
    for (const e of ents) {
      const abs = path.join(d, e.name);
      const rel = relDir ? `${relDir}/${e.name}` : e.name;
      if (e.isSymbolicLink()) { problems.push(`${rel}: is a symbolic link`); continue; }
      if (e.isDirectory()) { walk(abs, rel); continue; }
      files.push(rel);
      for (const p of checkFile(abs, { maxBytes })) problems.push(`${rel}: ${p.replace(/^[^:]*: /, "")}`);
    }
  };
  walk(dirAbs, "");
  return { files, problems };
}
