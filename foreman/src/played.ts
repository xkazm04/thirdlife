// H1c of 25 Nov: which cartridge a game plays (kept out of coreroute.ts, at its 600-line budget).
import fs from "node:fs";
import path from "node:path";
import { stripBom } from "./paths.js";

const readJson = (file: string): unknown => JSON.parse(stripBom(fs.readFileSync(file, "utf8")));

/**
 * H1c (lane G1's Arsenal job: the measured check refused a package on its own drill cartridge while the game's passed): the
 * cartridges the GAME plays, the ones data/match.json and data/skin.json name (`cartridge`); [] when neither names one.
 * A drill or test cartridge a package adds beside it is validated, never measured as the game.
 */
export function playedCartridges(dir: string): { files: string[]; by: string[] } {
  const files: string[] = [];
  const by: string[] = [];
  for (const f of ["data/match.json", "data/skin.json"]) {
    try {
      const c = (readJson(path.join(dir, ...f.split("/"))) as { cartridge?: unknown }).cartridge;
      if (typeof c !== "string" || !fs.existsSync(path.join(dir, "data", c))) continue;
      by.push(f);
      if (!files.includes(`data/${c}`)) files.push(`data/${c}`);
    } catch {
      /* not there */
    }
  }
  return { files, by };
}
