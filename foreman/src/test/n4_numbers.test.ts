// N4 loop round 6 (22 Nov): builders get the house game's own numbers, read live from the pack: the camera, the pushbox
// and the never-idle limit, the three faults the critic named in the crazy colosseum proof -3.
import { test, after } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { cleanup, tempDir } from "./helpers.js";
import { houseExcerpt, templateOf, type Template } from "../templates.js";
import { REPO_ROOT } from "../paths.js";

after(cleanup);
const duel = templateOf("duel") as Template;

test("round 6: the builder excerpt carries the duel's camera, pushbox and never-idle numbers, read from the pack now (a retuned camera follows)", () => {
  const text = houseExcerpt(duel, "builder");
  const camera = JSON.stringify((JSON.parse(fs.readFileSync(path.join(REPO_ROOT, "engine", "packs", "duel", "data", "tuning.json"), "utf8")) as { camera: unknown }).camera);
  assert.ok(text.includes(`never low behind the player): ${camera}`), "the camera object as the pack has it now");
  assert.match(text, /pushbox per duellist at scale 1[^\n]*: 0\.45\n/);
  assert.match(text, /never idle \(scripts\/brain\.gd last_action\)[^\n]*: 120 frames at most/);
  assert.doesNotMatch(text, /back 4\.6 m/, "no stale camera numbers in the text");
  // A pack whose camera moved: the excerpt follows it; a pack without the files says nothing it cannot read.
  const engine = tempDir("numbers");
  const pack = path.join(engine, "packs", "duel");
  fs.mkdirSync(path.join(pack, "data"), { recursive: true });
  fs.mkdirSync(path.join(pack, "scripts"), { recursive: true });
  fs.writeFileSync(path.join(pack, "README.md"), "# Duel\n");
  fs.writeFileSync(path.join(pack, "data", "tuning.json"), JSON.stringify({ camera: { angle: 40, dist: 5 } }));
  fs.writeFileSync(path.join(pack, "scripts", "feel.gd"), "const DT: float = 1.0 / 60.0\nconst PUSHBOX: float = 0.5   # retuned\n");
  const moved = houseExcerpt(duel, "builder", engine);
  assert.match(moved, /never low behind the player\): \{"angle":40,"dist":5\}/);
  assert.match(moved, /pushbox per duellist at scale 1[^\n]*: 0\.5\n/);
  fs.rmSync(path.join(pack, "scripts", "feel.gd"));
  assert.doesNotMatch(houseExcerpt(duel, "builder", engine), /pushbox per duellist/);
});

test("round 7: an arcade-sport brief keeps the owner's three hockey words; the real 22 Nov hockey room wrote no speed ratio and is sent back; builders get the house hockey's tuning", async () => {
  const { houseKeepProblems } = await import("../templates.js");
  const sport = { id: "arcade_sport" as const, reference: "NHL 94", copies: ["possession", "utility", "roles"] };
  const room = JSON.parse(fs.readFileSync(path.join(REPO_ROOT, "foreman", "fixtures", "room-hockey-22nov.json"), "utf8")) as { brief: { rules: string; ai: string; controls: string; arena: string } };
  const real = `${room.brief.rules} ${room.brief.controls} ${room.brief.arena} ${room.brief.ai}`;
  const p = houseKeepProblems(real, sport);
  assert.deepEqual(p.map((x) => /keeps the (\w+ \w+)/.exec(x)?.[1]), ["speed ratios"], "the carry and the utility AI were copied; the speed ratio was not");
  assert.deepEqual(houseKeepProblems(`${real} The carrier is slower than a free skater (x0.88) and a pass beats skating.`, sport), []);
  const hockey = houseExcerpt(templateOf("arcade_sport") as Template, "builder");
  assert.match(hockey, /skating and the carrier's handicap[^\n]*: \{"free_speed_mult":/);
  assert.match(hockey, /the carry, the stickiness[^\n]*"spring_k":400/);
});

test("round 7: the keeps read the brief's ai text too (the real hockey room put its utility AI there)", async () => {
  const { briefTemplateProblems } = await import("../templates.js");
  const sport = { id: "arcade_sport" as const, reference: "NHL 94", copies: ["possession", "utility", "roles"] };
  const room = JSON.parse(fs.readFileSync(path.join(REPO_ROOT, "foreman", "fixtures", "room-hockey-22nov.json"), "utf8")) as { brief: { rules: string; ai: string; controls: string; arena: string } };
  const design = { verbs: [], feel: { camera: "chase" } } as unknown as Parameters<typeof briefTemplateProblems>[0]["design"];
  const p = briefTemplateProblems({ ...room.brief, design }, sport).join(" | ");
  assert.match(p, /keeps the speed ratios/);
  assert.doesNotMatch(p, /keeps the AI decides/, "its utility AI is in `ai`");
});
