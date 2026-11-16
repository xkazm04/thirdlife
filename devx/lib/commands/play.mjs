export const summary = "play a seed, a house game or a pack interactively: `tl play [<seed-name>|<house-game>|<path>] [--record=<file>] [--seed=<n>]` (no argument lists the seeds and the house games; --record writes the session's input, tl.input/1, for `tl.sh replay`)";
import fs from "node:fs";
import path from "node:path";
import { spawn } from "node:child_process";
import { REPO, ENGINE, resolveGodot } from "../ctx.mjs";
import { listPacks, resolveSeed } from "../loop/pack.mjs";
import { bashExe } from "../loop/exec.mjs";

const titleOf = (p) => { try { return JSON.parse(fs.readFileSync(path.join(p, "pack.json"), "utf8")).title ?? ""; } catch { return ""; } };

export async function run(args) {
  const seeds = path.join(ENGINE, "seeds");
  const house = path.join(ENGINE, "packs");     // H0: house games, finished games the repo keeps and gates (engine/packs/README.md)
  const [spec] = args;
  if (!spec) {
    console.log("seeds (tl play <name>):");
    for (const p of listPacks([seeds])) console.log(`  ${path.basename(p).replace(/^seed_/, "").padEnd(10)} ${titleOf(p)}`);
    console.log("house games (tl play <name>):");
    for (const p of listPacks([house])) console.log(`  ${path.basename(p).padEnd(10)} ${titleOf(p)}`);
    return 0;
  }
  const pack = resolveSeed(spec, seeds) ?? resolveSeed(spec, house);
  if (!pack) { console.error(`tl play: no pack '${spec}' (looked for a path, engine/seeds/${spec}, engine/seeds/seed_${spec}, engine/packs/${spec}). Run \`tl play\` to list seeds and house games.`); return 2; }
  const godot = resolveGodot();
  if (!godot) { console.error("tl play: Godot not found. Run `tl doctor`."); return 2; }
  const extra = args.slice(1).filter((a) => /^--(record|seed)=/.test(a));     // P7: the session's input record
  const child = spawn(bashExe(), [path.join(REPO, "engine", "tools", "tl.sh"), "play", `--pack=${pack}`, ...extra], {
    cwd: REPO, stdio: "inherit", env: { ...process.env, TL_GODOT: godot },
  });
  return await new Promise((resolve) => { child.on("error", () => resolve(2)); child.on("close", (c) => resolve(c ?? 2)); });
}
