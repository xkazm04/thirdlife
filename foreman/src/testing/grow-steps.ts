// E4 (night of 24-25 Nov 2026): the fake-adapter steps of two change rounds on the phases fixture (fixtures/job-phases),
// so a test, Create's iterate selftest and the exe check can walk the person's path with no model called:
//   1. "add rocket skates ..."   the owner question answers "new"; the Planner adds the package `rocket` with a wire to
//                                `core`; rocket is built, then core is re-opened to call it (grow.ts);
//   2. "... rallies ... smaller court"   the owner question names `court` (the fixture's own step); court round 2.
//   node dist/testing/grow-steps.js <job dir> [--pauses]   a fresh copy of the phases fixture there, with these steps
//                                                          first (--pauses: a builder question and a quality hold)
import fs from "node:fs";
import path from "node:path";
import { pathToFileURL } from "node:url";
import type { FakeScript, FakeStep } from "../builder/fake.js";
import { copyFixture } from "../cli.js";

export const GROW_TEXT = "add rocket skates: hold the boost key to fly forward";
export const CHANGE_TEXT = "the rallies are too slow: make the court smaller";

export function growSteps(base: FakeScript): FakeStep[] {
  const core = base.steps.find((s) => s.match?.role === "builder" && s.match.package === "core" && s.write?.["scripts/main.gd"] !== undefined);
  const main = core?.write?.["scripts/main.gd"] ?? "extends RefCounted\n";
  return [
    {
      match: { role: "planner", promptIncludes: "This is a GROWTH" },
      tokensIn: 9000,
      tokensOut: 600,
      json: {
        packages: [
          {
            id: "rocket",
            title: "Rocket skates",
            milestone: "tuned",
            deps: ["core"],
            scope: ["data/rocket.json", "scripts/rocket.gd"],
            contract: "data/rocket.json: {boost_mps: 9, boost_frames: 40, cooldown_frames: 120}.\nscripts/rocket.gd: func boost(held: bool, frame: int, tuning: Dictionary) -> float returns the extra speed in m/s this frame.",
            acceptance: [
              { level: "V1", verb: "lint", args: [] },
              { level: "V2", verb: "smoke", args: ["--seed=1", "--frames=600"] },
            ],
          },
        ],
        wire: ["core"],
      },
    },
    { match: { role: "planner", promptIncludes: "add rocket skates" }, tokensIn: 700, tokensOut: 40, json: { package: "new", reason: "no package has a boost or anything that flies: it is a new mechanic" } },
    {
      match: { role: "builder", package: "rocket" },
      delayMs: 60,
      tokensIn: 3000,
      tokensOut: 300,
      write: {
        "data/rocket.json": '{\n "boost_mps": 9,\n "boost_frames": 40,\n "cooldown_frames": 120\n}\n',
        "scripts/rocket.gd": "extends RefCounted\n\nfunc boost(held: bool, frame: int, tuning: Dictionary) -> float:\n\treturn float(tuning.get(\"boost_mps\", 9)) if held and frame % int(tuning.get(\"cooldown_frames\", 120)) < int(tuning.get(\"boost_frames\", 40)) else 0.0\n",
      },
      text: "Done. Wrote data/rocket.json and scripts/rocket.gd.",
    },
    {
      match: { role: "builder", package: "core", promptIncludes: "wire in rocket" },
      delayMs: 60,
      tokensIn: 3000,
      tokensOut: 200,
      write: { "scripts/main.gd": `${main.trimEnd()}\n# rocket skates: scripts/rocket.gd boost() is called each frame (wired in for the change request)\n` },
      text: "Done. scripts/main.gd calls scripts/rocket.gd.",
    },
  ];
}

/** A fresh phases fixture job in `dest` whose fake script answers both change rounds. */
export function iterateJob(dest: string): void {
  copyFixture(dest, true);
  const file = path.join(dest, "fake-builder.json");
  const base = JSON.parse(fs.readFileSync(file, "utf8")) as FakeScript;
  fs.writeFileSync(file, JSON.stringify({ ...base, steps: [...growSteps(base), ...base.steps] }, null, 1));
}

/**
 * E4b: the phases fixture with the two pauses a person must answer in Create: the rival's builder asks a question
 * before it builds (answered: it builds), and the critic finds every look weak (after the two revise rounds the job
 * holds for the person's quality answer).
 */
export const QUESTION_TEXT = "Should Rival Rex lunge at every ball, or should he wait at the centre and cut the angle?";
export function pausesJob(dest: string): void {
  copyFixture(dest, true);
  const file = path.join(dest, "fake-builder.json");
  const base = JSON.parse(fs.readFileSync(file, "utf8")) as FakeScript;
  const ai1 = base.steps.find((s) => s.match?.package === "paddle_ai" && s.match.round === 1);
  const ai2 = base.steps.find((s) => s.match?.package === "paddle_ai" && s.match.round === undefined);
  const answered: FakeStep = { match: { role: "builder", package: "paddle_ai", promptIncludes: "Answer to your question:" }, delayMs: 60, write: { ...(ai1?.write ?? {}), ...(ai2?.write ?? {}) }, text: "Done: Rex waits at the centre and cuts the angle, as you said." };
  const asks: FakeStep = { match: { role: "builder", package: "paddle_ai" }, delayMs: 60, text: `I have written nothing yet.\nQUESTION: ${QUESTION_TEXT}` };
  const weak: FakeStep = { match: { role: "critic" }, json: { ok: false, scores: { silhouette: 0.6, readability: 0.4, style_consistency: 0.6, shows_play: 0.5, fun_promise: 0.3 }, notes: ["the court is a grey slab with nothing to read", "the ball is hard to find against the floor"] }, tokensIn: 900, tokensOut: 80 };
  fs.writeFileSync(file, JSON.stringify({ ...base, steps: [answered, asks, weak, ...base.steps] }, null, 1));
}

const invoked = process.argv[1] !== undefined && import.meta.url === pathToFileURL(fs.realpathSync(process.argv[1])).href;
if (invoked) {
  const dest = process.argv[2];
  if (!dest) {
    process.stderr.write("usage: node dist/testing/grow-steps.js <job dir>\n");
    process.exit(2);
  }
  if (process.argv[3] === "--pauses") pausesJob(path.resolve(dest));
  else iterateJob(path.resolve(dest));
  process.stdout.write(`${path.resolve(dest).replace(/\\/g, "/")}\n`);
}
