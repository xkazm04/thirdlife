// K7: "a house game in a world plays as it does alone", in the gate (it lived on a list a person had to remember).
// For the games of the exe (engine/boot/games.json) it runs `bash engine/tools/world.sh alone --packs=<their paths> --mode=bot
// --frames=20000` once (all games in one world, then each alone through the runner) and reads the verdict table. A unit is
// one game: found = the games of games.json, completed = the games whose row says "same". Fewer rows than games, a missing
// trailer line ("PASS world.alone" / "FAIL world.alone"), our timeout: FAIL; a kill from outside: could not run. Never a pass
// for what was not judged (docs/GATE-HONESTY.md). The whole output is kept in .tl/gate-world.log (gitignored).
import fs from "node:fs";
import path from "node:path";

export const id = "world";
export const tiers = ["full"];
export const paths = ["engine/kernel/**", "engine/kits/**", "engine/rigs/**", "engine/style/**", "engine/packs/**", "engine/seeds/**",
  "engine/boot/games.json", "engine/tools/world.sh", "engine/tools/tl.sh", "engine/project.godot"];
export const FRAMES = 20000;
const TIMEOUT_MS = 40 * 60 * 1000;

/** The exe's games: [{name, from}] from games.json, or {error}. A game that is not found is an error unless `optional`. */
export function readGames(repo) {
  const file = path.join(repo, "engine", "boot", "games.json");
  let j;
  try { j = JSON.parse(fs.readFileSync(file, "utf8")); } catch (e) { return { error: `engine/boot/games.json does not parse: ${String(e.message).split("\n")[0]}` }; }
  const games = [], missing = [], skipped = [];
  for (const g of j.games ?? []) {
    if (fs.existsSync(path.join(repo, g.from, "pack.json"))) games.push({ name: g.name, from: g.from });
    else if (g.optional) skipped.push(g.name);
    else missing.push(`${g.name} (${g.from})`);
  }
  return missing.length ? { error: `games.json names games that are not here: ${missing.join(", ")}` } : { games, skipped };
}

/** The rows of world.sh alone's table: {pack, mode, ticks, world, alone, aloneFrames, verdict}, and its trailer. */
export function parseAlone(stdout) {
  const rows = [];
  let trailer = null;
  for (const l of String(stdout).split(/\r?\n/)) {
    const m = /^(\S+) \| (\w+) \| (\d+) \| ([0-9a-f]*) \| ([0-9a-f]*) \((\d*) frames\) \| (.+)$/.exec(l.trim());
    if (m) rows.push({ pack: m[1], mode: m[2], ticks: +m[3], world: m[4], alone: m[5], aloneFrames: m[6] === "" ? null : +m[6], verdict: m[7].trim() });
    const t = /^(PASS|FAIL) world\.alone/.exec(l.trim());
    if (t) trailer = t[1];
  }
  return { rows, trailer };
}

/** Pure verdict over one finished run. r = ctx.run result {code, stdout, stderr, timedOut?, signal?}; nGames = games asked. */
export function judgeWorld(r, nGames) {
  const { rows, trailer } = parseAlone(r.stdout);
  const same = rows.filter((x) => x.verdict === "same");
  const counts = { found: nGames, completed: Math.min(same.length, nGames) };
  if (r.signal && !r.timedOut) return { ok: false, notRun: true, ...counts, detail: `world.sh alone was stopped from outside (${r.signal}) after ${rows.length} of ${nGames} rows` };
  const problems = [];
  if (r.timedOut) problems.push(`timed out after ${Math.round(TIMEOUT_MS / 60000)} min`);
  if (rows.length < nGames) problems.push(`the tool printed ${rows.length} rows for ${nGames} games`);
  if (!trailer) problems.push(`stopped before its trailer line (exit ${r.code})`);
  for (const x of rows.filter((y) => y.verdict !== "same"))
    problems.push(`${x.pack} differs: ${x.ticks} own ticks, world ${x.world || "no hash"}, alone ${x.alone || "no hash"} (${x.aloneFrames ?? "?"} frames)`);
  if (trailer === "FAIL" && !problems.length) problems.push(`world.alone FAIL: ${String(r.stdout).split(/\r?\n/).filter((l) => /not every|ended with exit/.test(l)).join("; ").slice(0, 200)}`);
  const ok = !problems.length && r.code === 0 && trailer === "PASS" && same.length === nGames && rows.length === nGames;
  const table = rows.map((x) => `${x.pack} ${x.world}@${x.ticks}`).join(", ");
  return ok ? { ok: true, ...counts, detail: `${nGames} games: world = alone: ${table}` }
    : { ok: false, ...counts, detail: `${problems.length ? problems.join("; ") : `exit ${r.code}`}; rows: ${table || "none"}` };
}

export async function run(ctx) {
  const rg = readGames(ctx.REPO);
  if (rg.error) return { ok: false, found: 0, completed: 0, detail: rg.error };
  if (!rg.games.length) return { ok: false, found: 0, completed: 0, detail: "found 0 games in engine/boot/games.json: nothing gated is not a pass" };
  if (!ctx.resolveGodot()) return { ok: false, notRun: true, found: rg.games.length, completed: 0, detail: "no Godot found: set TL_GODOT or .tl/local.json (tl doctor)" };
  const r = ctx.bash(path.join(ctx.ENGINE, "tools", "world.sh"),
    ["alone", `--packs=${rg.games.map((g) => g.from).join(",")}`, "--mode=bot", `--frames=${FRAMES}`], { cwd: ctx.REPO, timeout: TIMEOUT_MS });
  const log = path.join(ctx.REPO, ".tl", "gate-world.log");
  fs.mkdirSync(path.dirname(log), { recursive: true });
  fs.writeFileSync(log, `# exit ${r.code}${r.timedOut ? " (timed out)" : ""}${r.signal ? ` (${r.signal})` : ""}\n${r.stdout}\n--- stderr\n${r.stderr}`);
  const v = judgeWorld(r, rg.games.length);
  return { ...v, detail: `${v.detail}${rg.skipped.length ? `; optional games not here: ${rg.skipped.join(", ")}` : ""}; output: .tl/gate-world.log` };
}
