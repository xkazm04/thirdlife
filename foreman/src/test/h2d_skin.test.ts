// H2d (25 Nov 2026): one trick, two names on one screen. G1's Arsenal called its shotgun a CANNON in its own words while the
// base's ability plate said SHOTGUN. The base's skin now has ability_names (scripts/hud/skin.gd, a TYPE_DICTIONARY by the
// core's kind), and the Foreman's design check knows it: a Designer's "SKIN: ability_names.shotgun = cannon" is a field of
// the base's skin, as "SKIN: ability_names = {...}" is; a misspelt field is still refused.
import { test } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { REPO_ROOT } from "../paths.js";
import { RINK_ROUTE, coreBriefProblems, skinFields } from "../coreroute.js";

const ENGINE = path.join(REPO_ROOT, "engine");
const BASE = path.join(ENGINE, "templates", "rink_game");

test("H2d: the base's skin names its tricks (ability_names), and the design check takes a field under it", () => {
  if (!fs.existsSync(path.join(BASE, "scripts", "hud", "skin.gd"))) return;
  const f = skinFields(BASE);
  assert.ok(f?.has("ability_names") && f.has("ability_names.*"), [...(f ?? [])].join(", "));
  const skinProblems = (rules: string): string[] => coreBriefProblems(`CARTRIDGE: game.rink.length_m = 60\n${rules}`, RINK_ROUTE, ENGINE).filter((p) => p.includes("SKIN line"));
  assert.deepEqual(skinProblems("SKIN: ability_names.shotgun = cannon\nSKIN: ability_names.shield = bubble"), []);
  assert.deepEqual(skinProblems('SKIN: ability_names = {"shotgun": "cannon"}'), []);
  assert.ok(skinProblems("SKIN: ability_name = cannon").some((p) => p.includes('"ability_name", which is not a field')), "a misspelt field is refused");
  assert.ok(skinProblems("SKIN: ability_names. = x\nSKIN: title_names.x = y").length >= 1, "only a real dictionary field takes keys");
});
