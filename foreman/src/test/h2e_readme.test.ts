// H2e (25 Nov 2026): the base README now carries the base code's long comments ("The code, explained", moved out of the
// scripts to keep room under the 6,000-line budget). They are for people reading the code: the Foreman quotes the README
// into a rink-core job's design and plan context only up to that heading.
import { test } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { REPO_ROOT } from "../paths.js";
import { RINK_ROUTE, coreExcerpt, readmeForDesign } from "../coreroute.js";

const README = path.join(REPO_ROOT, "engine", "templates", "rink_game", "README.md");

test("H2e: the Designer and the Planner read the base README up to 'The code, explained', never the code's comments", () => {
  assert.equal(readmeForDesign("# Base\nwords\n\n## The code, explained (moved)\n\n### scripts/x.gd\nlong\n"), "# Base\nwords");
  assert.equal(readmeForDesign("# Base\r\nwords\r\n## The code, explained\r\nlong"), "# Base\r\nwords");
  assert.equal(readmeForDesign("# Base\nno such section\n"), "# Base\nno such section", "a README without the section is quoted whole");
  if (!fs.existsSync(README)) return;
  const full = fs.readFileSync(README, "utf8");
  assert.ok(full.includes("## The code, explained"), "the base README carries the section");
  for (const part of ["design", "planner"] as const) {
    const text = coreExcerpt({ id: "rink_sport", title: "Rink sport" }, RINK_ROUTE, part);
    assert.ok(text.includes("## The base and its skin"), `${part}: the base README is quoted`);
    assert.ok(text.includes("## Known limits of the base"), `${part}: up to and with its own sections`);
    assert.ok(!text.includes("The code, explained") && !text.includes("[base README:") && !text.includes("```text"), `${part}: none of the code's comments`);
  }
});
