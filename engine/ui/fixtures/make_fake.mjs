// N6: the fake-adapter script and the Foreman settings for the panel's live path. No model is called: the "builder"
// writes the kernel's minimal example pack (pack_min, read from the engine snapshot) file for file, in two packages,
// and the real runner verifies and photographs it.
//
//   node make_fake.mjs <engine dir with kernel/examples/pack_min> <out dir>
// writes <out>/fake-builder.json and <out>/flags.fake.json
import fs from "node:fs";
import path from "node:path";

const [engine, out] = process.argv.slice(2);
if (!engine || !out) {
  console.error("usage: make_fake.mjs <engine dir> <out dir>");
  process.exit(2);
}
const src = path.join(engine, "kernel", "examples", "pack_min");
const read = (f) => fs.readFileSync(path.join(src, f), "utf8");
const files = {};
for (const f of ["scripts/main.gd", "data/tuning.json", "gen/layout.gd", "tests/bot_roll.gd"]) files[f] = read(f);
const manifest = JSON.parse(read("pack.json"));
manifest.params = [
  { name: "balls", file: "data/tuning.json", path: "balls", min: 1, max: 12, step: 1, label: "Number of balls" },
  { name: "ramp_angle", file: "data/tuning.json", path: "ramp_angle_degrees", min: 8, max: 30, step: 0.5, label: "Ramp angle (degrees)" },
  { name: "ball_radius", file: "data/tuning.json", path: "ball_radius", min: 0.15, max: 0.6, step: 0.05, label: "Ball radius (m)" },
];
const tuningChanged = JSON.stringify({ ...JSON.parse(files["data/tuning.json"]), balls: 9 }, null, 2) + "\n";

const plan = {
  packages: [
    {
      id: "core",
      title: "Ramp, balls, finish line, bot",
      milestone: "blockout",
      deps: [],
      scope: ["scripts/**", "data/tuning.json", "gen/**", "tests/**"],
      contract: "The kernel example pack_min, file for file: balls roll down a ramp and cross a finish line.",
      registers: { capabilities: ["physics", "camera", "input"], assets: ["gen/layout.gd"], tests: ["tests/bot_roll.gd"], cameras: ["hero"] },
      acceptance: [
        { level: "V1", verb: "lint", args: [] },
        { level: "V2", verb: "smoke", args: ["--seed=1", "--frames=300"] },
        { level: "V3", verb: "invariants", args: ["--seed=1", "--frames=300", "--bot-frames=3000"] },
        { level: "V4", verb: "bot", args: ["--test=tests/bot_roll.gd", "--frames=3000"] },
      ],
    },
    {
      id: "feel",
      title: "Feel values for a later pass",
      milestone: "tuned",
      deps: ["core"],
      scope: ["data/feel.json"],
      contract: "data/feel.json: {bounce_sound, finish_flash}. Inert data; core does not read it yet.",
      acceptance: [
        { level: "V1", verb: "lint", args: [] },
        { level: "V2", verb: "smoke", args: ["--seed=1", "--frames=300"] },
      ],
    },
  ],
};

const scores = { silhouette: 0.8, readability: 0.75, style_consistency: 0.8, shows_play: 0.7 };
const script = {
  model: "fake",
  steps: [
    {
      match: { role: "designer" },
      delayMs: 3000,
      tokensIn: 3800,
      tokensOut: 1200,
      json: {
        brief: {
          rules: "Balls are let go at the top of a ramp and roll down; a ball that crosses the finish line counts. The round ends when all have crossed.",
          arena: "One wooden ramp at 18 degrees on a flat floor with kerbs, a finish line 12 m from the start.",
          ai: "None: nothing plays against you.",
          controls: "None in this build: you watch. Space will let the balls go in a later pass.",
          mood: "Plain and bright, like a physics bench.",
        },
        estimate: { packages: 2, wallMinutes: 2, tokens: 30000 },
      },
    },
    {
      match: { role: "planner", promptIncludes: "Decide which ONE package owns" },
      delayMs: 1500,
      tokensIn: 2100,
      tokensOut: 90,
      json: { package: "core", reason: "the number of balls is a value in data/tuning.json, which core owns" },
    },
    { match: { role: "planner" }, delayMs: 3000, tokensIn: 41000, tokensOut: 5200, json: plan },
    { match: { role: "critic" }, delayMs: 1200, tokensIn: 5100, tokensOut: 400, json: { ok: true, scores, notes: ["The ramp and the balls read clearly against the floor."] } },
    {
      match: { role: "builder", package: "core", round: 1 },
      delayMs: 6000,
      tokensIn: 61000,
      tokensOut: 4800,
      write: { ...files, "pack.json": JSON.stringify(manifest, null, 2) + "\n" },
      text: "Done.\nDEVIATIONS:\n- The finish line is at x = 12 m, read from data/tuning.json, not fixed in the script.\n- Three values are declared as params so the player can tune them: balls, ramp_angle_degrees, ball_radius.",
    },
    {
      match: { role: "builder", package: "core" },
      delayMs: 5000,
      tokensIn: 48000,
      tokensOut: 900,
      write: { "data/tuning.json": tuningChanged },
      text: "Done.\nDEVIATIONS:\n- data/tuning.json: balls is now 9 (was 5), as the change request asks.",
    },
    {
      match: { role: "builder", package: "feel" },
      delayMs: 5000,
      tokensIn: 22000,
      tokensOut: 600,
      write: { "data/feel.json": JSON.stringify({ bounce_sound: "soft", finish_flash: 0.4 }, null, 2) + "\n" },
      text: "Done.\nDEVIATIONS: none",
    },
  ],
};

fs.mkdirSync(out, { recursive: true });
const scriptFile = path.resolve(out, "fake-builder.json").replace(/\\/g, "/");
fs.writeFileSync(scriptFile, JSON.stringify(script, null, 1));
const fake = ["--adapter", "fake", "--fake-script", scriptFile];
const run = [...fake, "--parallel", "1", "--round-limit", "3", "--timeout-ms", "120000", "--max-replans", "1"];
const flags = {
  name: "fake adapter",
  note: "No model is called. The runner is the real one (TL_GODOT, TL_ENGINE_DIR from the environment).",
  flags: { new: fake, plan: [...fake, "--max-packages", "4"], run, resume: run, change: run },
};
fs.writeFileSync(path.join(out, "flags.fake.json"), JSON.stringify(flags, null, 1));
// the second script: the package "feel" asks a question first, and builds once the answer is in its prompt
const asks = {
  model: "fake",
  steps: [
    ...script.steps.filter((s) => s.match.package !== "feel"),
    { ...script.steps.find((s) => s.match.package === "feel"), match: { role: "builder", package: "feel", promptIncludes: "Answer to your question:" }, delayMs: 9000 },
    {
      match: { role: "builder", package: "feel" },
      delayMs: 3000,
      tokensIn: 21000,
      tokensOut: 300,
      text: "I have written nothing yet.\nQUESTION: May core be changed so that it reads data/feel.json? Without that these values do nothing in the game.",
    },
  ],
};
const asksFile = path.resolve(out, "fake-builder-question.json").replace(/\\/g, "/");
fs.writeFileSync(asksFile, JSON.stringify(asks, null, 1));
const swap = (list) => list.map((x) => (x === scriptFile ? asksFile : x));
fs.writeFileSync(
  path.join(out, "flags.fake-question.json"),
  JSON.stringify({ ...flags, name: "fake adapter (asks)", flags: Object.fromEntries(Object.entries(flags.flags).map(([k, v]) => [k, swap(v)])) }, null, 1),
);
console.log(`wrote ${scriptFile} and ${path.resolve(out, "flags.fake.json").replace(/\\/g, "/")}`);
