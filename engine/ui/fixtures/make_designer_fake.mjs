// N4 (night of 22-23 Nov 2026): a fake-adapter script whose Designer answers, and the Foreman settings that use it, so
// Create's GO can run `foreman new` for real (selftest 780, an exe's proof) with no model called. The Designer's answer
// is the Foreman's own test helpers' (designerSteps + roomSteps in foreman/dist/test/helpers.js): it moves with the
// Foreman's schema instead of going stale here. Optional: a make_fake.mjs builder script whose build steps follow them.
//
//   node make_designer_fake.mjs <repo> <out dir> [<fake-builder.json of make_fake.mjs>]
// writes <out>/fake-designer.json and <out>/flags.fake-designer.json
import fs from "node:fs";
import path from "node:path";
import { pathToFileURL } from "node:url";

const [repo, out, build] = process.argv.slice(2);
if (!repo || !out) {
  console.error("usage: make_designer_fake.mjs <repo> <out dir> [<fake-builder.json>]");
  process.exit(2);
}
const dist = path.join(repo, "foreman", "dist");
if (!fs.existsSync(path.join(dist, "test", "helpers.js"))) {
  console.error(`no ${path.join(dist, "test", "helpers.js")}: build the Foreman first (npm --prefix foreman ci && npm --prefix foreman run build)`);
  process.exit(2);
}
const h = await import(pathToFileURL(path.join(dist, "test", "helpers.js")).href);
const j = await import(pathToFileURL(path.join(dist, "joblog.js")).href);
const brief = j.readLog(h.FIXTURE).events.find((e) => e.type === "brief_set");
const extra = build ? JSON.parse(fs.readFileSync(build, "utf8")) : { steps: [] };
const script = { ...extra, model: "fake", steps: [...h.designerSteps(brief.estimate), ...h.roomSteps(), ...extra.steps] };
fs.mkdirSync(out, { recursive: true });
const file = path.resolve(out, "fake-designer.json").replace(/\\/g, "/");
fs.writeFileSync(file, JSON.stringify(script, null, 1));
const fake = ["--adapter", "fake", "--fake-script", file];
const run = [...fake, "--parallel", "1", "--round-limit", "3", "--timeout-ms", "120000", "--max-replans", "1"];
const flags = {
  name: "fake adapter (the Designer answers)",
  note: "No model is called. Written by engine/ui/fixtures/make_designer_fake.mjs.",
  flags: { new: fake, redesign: fake, place: fake, plan: [...fake, "--max-packages", "4"], run, resume: run, change: run },
};
fs.writeFileSync(path.join(out, "flags.fake-designer.json"), JSON.stringify(flags, null, 1));
console.log(`wrote ${file} and ${path.join(out, "flags.fake-designer.json").replace(/\\/g, "/")}`);
