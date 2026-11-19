# bash docs/shifts/2026-11-19-night/lanes/hunt2/repro/A12.sh
set -eu
node --input-type=module <<'JS'
import fs from "node:fs";
import path from "node:path";
import {readGames} from "./devx/lib/gate/steps/world.mjs";
const repro = "docs/shifts/2026-11-19-night/lanes/hunt2/repro";
const repo = fs.mkdtempSync(path.join(repro, "A12."));
try {
  const boot = path.join(repo, "engine/boot");
  const game = {name: "parkour", from: "engine/packs/parkour"};
  fs.mkdirSync(boot, {recursive: true});
  fs.mkdirSync(path.join(repo, game.from), {recursive: true});
  fs.copyFileSync(path.join(game.from, "pack.json"), path.join(repo, game.from, "pack.json"));
  const catalog = {schema: "thirdlife.exe.games/1", games: [game]};
  function read(data) {
    fs.writeFileSync(path.join(boot, "games.json"), JSON.stringify(data));
    return readGames(repo);
  }
  if (read(catalog).games?.length !== 1) throw Error("valid catalog control failed");
  const bad = [
    {...catalog, gamse: []},
    {...catalog, games: [{...game, optionall: true}]},
    {...catalog, games: [{...game, optional: null}]},
  ];
  const accepted = bad.filter(data => read(data).games?.length === 1).length;
  if (accepted) {
    console.log(`REPRO A12: FAIL catalog reader accepted ${accepted}/3 invalid catalogs (extra root key, extra game key, null optional)`);
    process.exitCode = 1;
  } else {
    console.log("REPRO A12: PASS");
  }
} finally {
  fs.rmSync(repo, {recursive: true, force: true});
}
JS
