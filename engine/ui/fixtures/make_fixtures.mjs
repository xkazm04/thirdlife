// N6: a scratch jobs root with the display states the panel must show, cut from the real marble job (which is only
// read). Each fixture is a prefix of the real job.jsonl, some with a short hand-written tail that follows
// contracts/JOB.md; titles are changed so the rows can be told apart. Nothing here runs a Foreman.
//
//   node make_fixtures.mjs <marble job dir> <out jobs root>
import fs from "node:fs";
import path from "node:path";

const [src, out] = process.argv.slice(2);
if (!src || !out) {
  console.error("usage: make_fixtures.mjs <marble job dir> <out jobs root>");
  process.exit(2);
}
const lines = fs.readFileSync(path.join(src, "job.jsonl"), "utf8").split("\n").filter((l) => l.length > 0);
const first = JSON.parse(lines[0]);

function make(name, title, count, tail = [], extra = () => {}) {
  const dir = path.join(out, name);
  fs.rmSync(dir, { recursive: true, force: true });
  fs.mkdirSync(dir, { recursive: true });
  const head = lines.slice(0, count).map((l, i) => (i === 0 ? JSON.stringify({ ...first, title }) : l));
  let seq = count;
  const last = JSON.parse(lines[count - 1]);
  let t = Date.parse(last.ts);
  const more = tail.map((e) => {
    seq += 1;
    t += e.afterMs ?? 1000;
    const { afterMs, ...rest } = e;
    return JSON.stringify({ v: 1, seq, ts: new Date(t).toISOString(), job: first.job, ...rest });
  });
  fs.writeFileSync(path.join(dir, "job.jsonl"), [...head, ...more].map((l) => l + "\n").join(""));
  // the pictures the prefix refers to
  const caps = new Set();
  for (const l of head) {
    const e = JSON.parse(l);
    if (e.type === "milestone") for (const c of e.captures) caps.add(c);
  }
  for (const c of caps) {
    fs.mkdirSync(path.dirname(path.join(dir, c)), { recursive: true });
    fs.copyFileSync(path.join(src, c), path.join(dir, c));
  }
  extra(dir);
  console.log(`${name}: ${head.length} real events + ${more.length} written, ${caps.size} pictures`);
}

fs.mkdirSync(out, { recursive: true });

// waits for approval: the real log up to brief_set
make("fx-1-approve", "Marble run: brief", 4);

// paused on a question: the real log up to the pause
make("fx-2-question", "Marble run: question", 69);

// paused on budget: real up to event 48, then the budget pause
make("fx-3-budget", "Marble run: budget", 48, [
  { type: "budget", policy: { kind: "tokens_per_hour", limit: 3000000 }, state: "paused", reason: "3,000,000 weighted tokens used in the last hour; next run at 23:58" },
  { type: "job_state", state: "paused", reason: "budget: tokens_per_hour limit reached" },
]);

// failed, with a cause
make("fx-4-failed", "Marble run: failed", 48, [
  { type: "builder_run", package: "workshop_look", round: 4, adapter: "claude-cli", mode: "edit", model: "claude-sonnet-5-5", outcome: "ok", durationMs: 41000, tokensIn: 52000, tokensOut: 2100, afterMs: 41000 },
  { type: "package_state", package: "workshop_look", state: "verifying", round: 4 },
  { type: "verify", package: "workshop_look", round: 4, level: "V2", verb: "smoke", ok: false, report: "reports/workshop_look-r4-smoke-s52.json", exitCode: 1 },
  { type: "package_state", package: "workshop_look", state: "failed", round: 4, cause: "verify_failed", detail: "smoke: script error in scripts/look.gd line 41: Invalid call. Nonexistent function 'add_marker' in base 'RefCounted'." },
  { type: "package_state", package: "slide_feel", state: "blocked", round: 1, cause: "dependency", detail: "workshop_look failed" },
  { type: "job_state", state: "failed", reason: "workshop_look failed after 4 rounds; 3 re-plans used" },
]);

// running, but its Foreman is gone: the lock names a process that does not exist
make("fx-5-no-foreman", "Marble run: no Foreman", 31, [], (dir) => fs.writeFileSync(path.join(dir, "foreman.lock"), "999999"));

// the whole job, with its promoted pack and three declared params (the real pack declares none)
make("fx-6-tune", "Marble run: tunable copy", lines.length, [], (dir) => {
  const rel = "promoted/game.marble_run_three_marbles";
  fs.cpSync(path.join(src, rel), path.join(dir, rel), { recursive: true });
  const man = JSON.parse(fs.readFileSync(path.join(dir, rel, "pack.json"), "utf8"));
  man.params = [
    { name: "wood_drag", file: "data/tuning.json", path: "marbles.wood.linear_damp", min: 0.1, max: 2, step: 0.05, label: "Wood marble: drag on ice" },
    { name: "rubber_drag", file: "data/tuning.json", path: "marbles.rubber.linear_damp", min: 0.1, max: 2, step: 0.05, label: "Rubber marble: drag on ice" },
    { name: "steel_drag", file: "data/tuning.json", path: "marbles.steel.linear_damp", min: 0.1, max: 2, step: 0.05, label: "Steel marble: drag on ice" },
    { name: "settle_frames", file: "data/tuning.json", path: "settle_frames", min: 30, max: 240, step: 10, label: "Frames until a marble counts as settled" },
  ];
  fs.writeFileSync(path.join(dir, rel, "pack.json"), JSON.stringify(man, null, 2) + "\n");
});

// a change request in flight on the finished job
make("fx-7-change", "Marble run: change, no Foreman", lines.length, [
  { type: "change_requested", text: "Make the three marbles twice as big and give the steel one a shine." },
  { type: "job_state", state: "running", reason: "reopened by a change request (was done)" },
  { type: "reopened", package: "core_run", reason: "change request (event 127): the Planner names this package: the marbles are created in scripts/main.gd" },
  { type: "package_state", package: "core_run", state: "queued", round: 3, detail: "CHANGE REQUEST: Make the three marbles twice as big and give the steel one a shine." },
  { type: "package_state", package: "core_run", state: "running", round: 3 },
], (dir) => {
  const rel = "promoted/game.marble_run_three_marbles";
  fs.cpSync(path.join(src, rel), path.join(dir, rel), { recursive: true });
  fs.writeFileSync(path.join(dir, "foreman.lock"), "999998"); // its Foreman died mid-change
});
