// A stand-in for TL_GODOT that obeys contracts/RUNNER.md: verbs, exit codes, last-line JSON, report file.
// Brought into line with the real runner (site/_engine_snapshot, observed 2026-11-10) by WP3b: see the list at the
// end of this comment. It judges a pack by simple, deterministic rules, and can be told to hang, print garbage or
// contradict itself:
//   - by a marker string anywhere in the pack's files (so a scripted builder can cause it), or
//   - by the environment variable FAKE_RUNNER_MODE = hang | garbage | disagree | noreport.
// Markers: FAKE_BYPASS (one lint bypass per line that holds it), FAKE_BOT_NEEDS(x)/FAKE_HAS(x) (the bot fails until some
// file holds FAKE_HAS(x)), FAKE_SCRIPT_ERROR (smoke fails), FAKE_WATCHDOG (exit 3), FAKE_NONDETERMINISTIC (invariants fail),
// FAKE_BOT_FAIL (bot reports ok=false), FAKE_BOT_NEVER_DONE (the bot does not finish), FAKE_CAPTURE_FAIL (no image),
// FAKE_RUNNER_HANG, FAKE_RUNNER_GARBAGE, FAKE_RUNNER_DISAGREE, FAKE_RUNNER_NOREPORT.
// FAKE_RUNNER_BOT_TIMEOUT=watchdog makes an unfinished bot end as the snapshot engine does (exit 3, outcome
// watchdog) instead of as the amended contract says (exit 1, outcome failed).
// FAKE_RUNNER_CAPTURE_FAILS=<n> makes the first n capture calls (counted in a file beside the report) fail.
// FAKE_RUNNER_LOAD_TRIPS=<n> makes the first n runs of pack code end as a false watchdog stop (tick_timeout), as
// the real runner was seen to do under CPU load.
//
// What the real runner does and this fake now does too:
//   - an invalid manifest: `lint` exit 1 with `schema` errors carrying file (and line); every other verb exit 2,
//     outcome not_run, errors kind schema + load, no checks;
//   - an unknown option: exit 2, "unknown option --x for '<verb>' (allowed: ...)";
//   - smoke, invariants, bot and capture all carry the smoke.* checks, including smoke.no_engine_errors, and metrics
//     (64-hex state_hash, tick_ms_max);
//   - `bot --test` must be one of the manifest's tests (exit 1, smoke.loads false); without --test the first is run;
//   - `capture` needs an absolute --out (exit 2 without) and a --cam the pack declares (exit 1, smoke.loads false),
//     takes --test, --frame, --res, and reports width and height;
//   - layout and fence errors carry `file`; the fence list has the extra doors (randf_range( and friends).
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import zlib from "node:zlib";
import { Ajv2020 } from "ajv/dist/2020.js";
import type { RunProcessRequest, RunProcessResult, SpawnFn } from "../proc.js";
import { REPO_ROOT } from "../paths.js";
import { FAKE_VERBS_FILE, VERBS_FILE, readVerbsFile } from "../verbs.js";

export interface FakeRunnerOutput {
  exitCode: number;
  stdout: string;
  hang: boolean;
}

const VERB_LEVEL: Record<string, string> = { lint: "V1", smoke: "V2", invariants: "V3", bot: "V4", capture: "V5" };
const EXIT: Record<string, number> = { passed: 0, failed: 1, not_run: 2, watchdog: 3 };
/**
 * The options each verb takes: read from the verbs file (tl.verbs/1) of the engine directory the runner was started
 * with (`--path`), or, when that directory has none, from the fake engine's own file
 * (fixtures/engine/kernel/runner/verbs.json). No list is kept in code (N3 item 4).
 */
function optionsOf(argv: string[]): Record<string, string[]> {
  const at = argv.indexOf("--path");
  const engine = at >= 0 ? argv[at + 1] : undefined;
  const own = engine !== undefined ? path.join(engine, ...VERBS_FILE.split("/")) : undefined;
  const verbs = readVerbsFile(own !== undefined && fs.existsSync(own) ? own : FAKE_VERBS_FILE).verbs;
  return Object.fromEntries(Object.entries(verbs).map(([v, spec]) => [v, Object.keys(spec.options)]));
}
/** The optional manifest fields of PACK.md's last section: the real runner accepts them (manifest.gd), so does this one. */
const OPTIONAL_MANIFEST_FIELDS = ["footprint", "params", "on_leave", "subject", "moments"];
const LAYOUT = new Set(["pack.json", "scripts", "data", "gen", "assets", "tests", "examples"]);
const FENCE = [
  "class_name", "@tool", "OS.", "FileAccess", "DirAccess", "ResourceSaver", "ProjectSettings.", "Engine.get_singleton",
  "ClassDB.", "HTTPRequest", "HTTPClient", "StreamPeer", "TCPServer", "UDPServer", "PacketPeer", "WebSocketPeer",
  "ENetConnection", "Thread", "Mutex", "Semaphore", "JavaScriptBridge", "Expression", "GDScript.new", "str_to_var",
  "bytes_to_var", "get_tree().root", "change_scene", "get_tree().quit", "Time.get_ticks", "Time.get_unix", "randf(",
  "randi(", "randomize(", "randf_range(", "randi_range(", "randfn(", ".shuffle(", ".pick_random(", "WorkerThreadPool",
];

let schemaCache: object | undefined;
function packSchema(): object {
  if (!schemaCache) {
    const raw = JSON.parse(fs.readFileSync(path.join(REPO_ROOT, "contracts", "pack.schema.json"), "utf8")) as Record<string, unknown>;
    delete raw["$id"];
    schemaCache = raw;
  }
  return schemaCache;
}

function walk(dir: string, rel = ""): string[] {
  const out: string[] = [];
  for (const e of fs.readdirSync(path.join(dir, rel), { withFileTypes: true })) {
    const r = rel ? `${rel}/${e.name}` : e.name;
    if (e.isDirectory()) out.push(...walk(dir, r));
    else out.push(r);
  }
  return out.sort();
}

interface Check {
  id: string;
  ok: boolean;
  detail: string;
}
interface Err {
  kind: string;
  file?: string;
  line?: number;
  message: string;
}

export function fakeRunner(argv: string[], env: NodeJS.ProcessEnv = {}): FakeRunnerOutput {
  const started = Date.now();
  const dd = argv.indexOf("--");
  const rest = dd === -1 ? [] : argv.slice(dd + 1);
  const verb = rest[0] ?? "";
  const opts: Record<string, string> = {};
  let badOption: string | undefined;
  for (const a of rest.slice(1)) {
    const m = /^--([a-z][a-z0-9-]*)=(.*)$/.exec(a);
    if (m?.[1] !== undefined) opts[m[1]] = m[2] ?? "";
    else badOption ??= a;
  }
  const checks: Check[] = [];
  const errors: Err[] = [];
  const report: Record<string, unknown> = { schema: "tl.verify/1", verb, level: VERB_LEVEL[verb] ?? "V0", kernelApi: "0.1" };
  let outcome: "passed" | "failed" | "not_run" | "watchdog" = "passed";
  let forceExit: number | undefined;
  let hang = false;
  let garbage = false;
  let noReport = false;

  const finish = (): FakeRunnerOutput => {
    report["ok"] = outcome === "passed";
    report["outcome"] = outcome;
    report["durationMs"] = Date.now() - started;
    report["checks"] = checks;
    report["errors"] = errors;
    const json = JSON.stringify(report);
    const reportFile = opts["report"];
    if (reportFile && !noReport && !garbage) {
      fs.mkdirSync(path.dirname(reportFile), { recursive: true });
      fs.writeFileSync(reportFile, json + "\n");
    }
    const banner = "Godot Engine v4.7.2.stable (fake runner) - https://godotengine.org\n\n";
    const stdout = garbage ? `${banner}SCRIPT ERROR: something went sideways\n   at: <native>\n` : `${banner}${json}\n`;
    return { exitCode: forceExit ?? EXIT[outcome] ?? 2, stdout, hang };
  };
  const notRun = (kind: string, message: string): FakeRunnerOutput => {
    outcome = "not_run";
    errors.push({ kind, message });
    return finish();
  };

  const allowed = optionsOf(argv)[verb];
  if (allowed === undefined) return notRun("engine", `unknown verb "${verb}"`);
  if (badOption !== undefined) return notRun("engine", `unknown argument ${badOption} for '${verb}'`);
  const unknown = Object.keys(opts).find((k) => !allowed.includes(k));
  if (unknown !== undefined) return notRun("engine", `unknown option --${unknown} for '${verb}' (allowed: ${allowed.join(", ")})`);
  if (!opts["pack"]) return notRun("engine", "missing --pack");
  if (!opts["report"]) return notRun("engine", "missing --report");
  const packDir = opts["pack"];
  if (!fs.existsSync(packDir) || !fs.statSync(packDir).isDirectory()) return notRun("load", `pack not found: ${packDir}`);

  const files = walk(packDir);
  const text = new Map<string, string>();
  for (const f of files) {
    const abs = path.join(packDir, f);
    if (fs.statSync(abs).size < 512 * 1024) text.set(f, fs.readFileSync(abs, "utf8"));
  }
  const has = (marker: string): string | undefined => [...text.entries()].find(([, t]) => t.includes(marker))?.[0];
  const mode = env["FAKE_RUNNER_MODE"] ?? "";
  if (mode === "hang" || has("FAKE_RUNNER_HANG")) hang = true;
  if (mode === "garbage" || has("FAKE_RUNNER_GARBAGE")) garbage = true;
  if (mode === "noreport" || has("FAKE_RUNNER_NOREPORT")) noReport = true;
  const disagree = mode === "disagree" || has("FAKE_RUNNER_DISAGREE") !== undefined;

  let manifest: Record<string, unknown> | undefined;
  const schemaErrs: Err[] = [];
  if (!text.has("pack.json")) schemaErrs.push({ kind: "schema", file: "pack.json", message: "pack.json is missing" });
  else {
    try {
      manifest = JSON.parse(text.get("pack.json") ?? "") as Record<string, unknown>;
    } catch (e) {
      schemaErrs.push({ kind: "schema", file: "pack.json", message: `pack.json does not parse: ${(e as Error).message}` });
    }
  }
  if (manifest) {
    if (typeof manifest["id"] === "string") report["pack"] = manifest["id"];
    if (typeof manifest["version"] === "string") report["packVersion"] = manifest["version"];
    const ajv = new Ajv2020({ allErrors: true, strict: false });
    const validate = ajv.compile(packSchema());
    const known = Object.fromEntries(Object.entries(manifest).filter(([k]) => !OPTIONAL_MANIFEST_FIELDS.includes(k)));
    for (const k of ["params", "moments"]) {
      if (manifest[k] !== undefined && !Array.isArray(manifest[k])) schemaErrs.push({ kind: "schema", file: "pack.json", message: `'${k}' must be a list` });
    }
    if (!validate(known)) {
      for (const e of validate.errors ?? []) {
        const extra = e.keyword === "additionalProperties" ? `unknown key '${String((e.params as { additionalProperty?: string }).additionalProperty)}' (unknown keys are errors)` : `${e.instancePath || "/"} ${e.message ?? "invalid"}`;
        schemaErrs.push({ kind: "schema", file: "pack.json", message: extra });
      }
    }
  }
  const schemaOk = schemaErrs.length === 0;
  const gd = files.filter((f) => f.endsWith(".gd"));
  const lines = (f: string): number =>
    (text.get(f) ?? "").split(/\r?\n/).filter((l) => l.trim() !== "" && !l.trim().startsWith("#")).length;
  const stateHash = (seed: string, frames: string): string => {
    const h = crypto.createHash("sha256");
    for (const f of files) h.update(f).update("\0").update(text.get(f) ?? "").update("\0");
    return h.update(`${seed}|${frames}`).digest("hex");
  };
  const fail = (): void => {
    if (outcome === "passed") outcome = "failed";
  };
  const tests = schemaOk && manifest ? (manifest["tests"] as string[]) : [];
  const cameras = schemaOk && manifest && Array.isArray(manifest["cameras"]) ? (manifest["cameras"] as string[]) : [];

  if (verb === "lint") {
    errors.push(...schemaErrs);
    checks.push({ id: "lint.schema", ok: schemaOk, detail: schemaOk ? "manifest matches tl.pack/0.1" : `${schemaErrs.length} problem(s); first: ${schemaErrs[0]?.message ?? ""}` });

    const layoutErrs: Err[] = [];
    for (const top of new Set(files.map((f) => f.split("/")[0] ?? f))) {
      if (!LAYOUT.has(top)) layoutErrs.push({ kind: "layout", file: top, message: "unexpected file at the pack root (allowed: pack.json and the directories scripts, data, gen, assets, tests, examples)" });
    }
    if (schemaOk && manifest) {
      const listed = [manifest["entry"], ...(manifest["assets"] as string[]), ...(manifest["tests"] as string[])] as string[];
      for (const f of listed) if (!text.has(f)) layoutErrs.push({ kind: "layout", file: f, message: "the manifest names a file that does not exist" });
    }
    errors.push(...layoutErrs);
    checks.push({ id: "lint.layout", ok: layoutErrs.length === 0, detail: `${layoutErrs.length} layout problems` });

    let fenceHits = 0;
    for (const f of gd) {
      const ls = (text.get(f) ?? "").split(/\r?\n/);
      ls.forEach((l, i) => {
        // As the real lint: string contents and comments are blanked first, and the doors to the global random
        // generator count only as bare calls (`ctx.rng.randf_range(` is the allowed way, `randf_range(` is not).
        const code = l.replace(/"(?:[^"\\]|\\.)*"/g, '""').replace(/'(?:[^'\\]|\\.)*'/g, "''").replace(/#.*$/, "");
        for (const token of FENCE) {
          const bare = /^(randf|randi|randomize|randf_range|randi_range|randfn)\($/.test(token);
          const hit = bare ? new RegExp(`(?<![\\w.])${token.slice(0, -1)}\\s*\\(`).test(code) : code.includes(token);
          if (hit) {
            fenceHits += 1;
            errors.push({ kind: "fence", file: f, line: i + 1, message: `'${token}' is outside the fence` });
          }
        }
      });
    }
    checks.push({ id: "lint.fence", ok: fenceHits === 0, detail: `${fenceHits} fenced patterns` });
    // FAKE_USES(<capability>) in a script stands for a kernel class of that capability: as in the real lint, the
    // manifest must declare it (this is what a workspace manifest without a merged package's registrations trips on).
    const capErrs: Err[] = [];
    const declared = new Set(schemaOk && manifest && Array.isArray(manifest["capabilities"]) ? (manifest["capabilities"] as string[]) : []);
    for (const f of gd) {
      (text.get(f) ?? "").split(/\r?\n/).forEach((l, i) => {
        for (const m of l.matchAll(/FAKE_USES\((\w+)\)/g)) {
          if (!declared.has(m[1] as string)) capErrs.push({ kind: "capability", file: f, line: i + 1, message: `uses a kernel class of '${m[1]}' but the manifest does not declare the capability '${m[1]}'` });
        }
      });
    }
    errors.push(...capErrs);
    checks.push({ id: "lint.capabilities", ok: capErrs.length === 0, detail: capErrs.length === 0 ? "every kernel capability used is declared" : `${capErrs.length} problem(s); first: ${capErrs[0]?.file ?? ""}:${capErrs[0]?.line ?? 0} ${capErrs[0]?.message ?? ""}` });

    const sizeErrs: Err[] = [];
    let total = 0;
    for (const f of gd) {
      const n = (text.get(f) ?? "").split(/\r?\n/).length;
      total += n;
      if (n > 600) sizeErrs.push({ kind: "size", file: f, line: 601, message: `${n} lines (limit 600)` });
    }
    if (total > 6000) sizeErrs.push({ kind: "size", message: `pack has ${total} lines of GDScript (limit 6000)` });
    errors.push(...sizeErrs);
    checks.push({ id: "lint.size", ok: sizeErrs.length === 0, detail: `${total} lines of GDScript` });
    const count = (prefix: string): number => gd.filter((f) => f.startsWith(prefix)).reduce((a, f) => a + lines(f), 0);
    // A line holding the marker FAKE_BYPASS stands for one place where a script does by hand what a primitive exists for.
    const bypasses: { primitive: string; file: string; line: number; pattern: string }[] = [];
    for (const f of gd) {
      (text.get(f) ?? "").split(/\r?\n/).forEach((l, i) => {
        if (l.includes("FAKE_BYPASS")) bypasses.push({ primitive: "TLBodies.make", file: f, line: i + 1, pattern: "RigidBody3D.new()" });
      });
    }
    report["composability"] = {
      gdscript_lines: { scripts: count("scripts/"), gen: count("gen/"), tests: count("tests/") },
      kit_parts_added: 0,
      bypasses,
    };
    if (checks.some((c) => !c.ok)) fail();
  } else {
    // Every verb that runs pack code refuses an invalid manifest before the sim: could not run.
    if (!schemaOk) {
      outcome = "not_run";
      errors.push(...schemaErrs, { kind: "load", message: "the manifest is not valid; run lint" });
      if (disagree) forceExit = 0;
      return finish();
    }
    const seed = opts["seed"] ?? "1";
    const frames = verb === "capture" ? (opts["frame"] ?? "120") : (opts["frames"] ?? (verb === "bot" ? "36000" : "3600"));
    report["seed"] = Number(seed);
    report["frames"] = Number(frames);
    if (verb === "capture") {
      const out = opts["out"];
      if (!out || !path.isAbsolute(out)) return notRun("engine", "--out=<file.png> is required and must be an absolute path");
      if (!opts["cam"]) return notRun("engine", "--cam=<name> is required");
    }
    const entry = manifest?.["entry"] as string;
    let loadProblem: Err | undefined = text.has(entry) ? undefined : { kind: "load", file: entry, message: "the entry script does not exist" };
    let test = opts["test"];
    if (!loadProblem && (verb === "bot" || (verb === "capture" && test !== undefined))) {
      test ??= tests[0];
      if (test === undefined || !tests.includes(test)) loadProblem = { kind: "load", file: test ?? "", message: `--test must be one of the manifest's tests: ${tests.join(", ")}` };
      else if (!text.has(test)) loadProblem = { kind: "load", file: test, message: "the bot script does not exist" };
    }
    if (!loadProblem && verb === "capture" && !cameras.includes(opts["cam"] ?? "")) {
      loadProblem = { kind: "load", file: entry, message: `no camera view '${opts["cam"] ?? ""}'; the pack registered: ${cameras.join(", ")}` };
    }
    let wd = loadProblem ? undefined : has("FAKE_WATCHDOG");
    // N3c: where the stall happened, as the real runner writes it at the end of the error message ("(frame N)").
    // FAKE_STALL_AT(<n>) in a pack file: the pack stalls at frame n in EVERY run (its own code). A load trip
    // (FAKE_RUNNER_LOAD_TRIPS) stalls at a different frame each time when FAKE_RUNNER_LOAD_FRAMES is set.
    let wdFrame: number | undefined;
    const fixed = loadProblem ? undefined : [...text.entries()].map(([f, body]) => [f, /FAKE_STALL_AT\((\d+)\)/.exec(body)?.[1]] as const).find(([, n]) => n !== undefined);
    if (!wd && fixed) {
      wd = fixed[0];
      wdFrame = Number(fixed[1]);
    }
    const loadTrips = Number(env["FAKE_RUNNER_LOAD_TRIPS"] ?? "0");
    if (!loadProblem && !wd && loadTrips > 0) {
      const counter = path.join(path.dirname(opts["report"] as string), ".fake-load-trips");
      const n = fs.existsSync(counter) ? Number(fs.readFileSync(counter, "utf8")) : 0;
      if (n < loadTrips) {
        fs.mkdirSync(path.dirname(counter), { recursive: true });
        fs.writeFileSync(counter, String(n + 1));
        wd = entry;
        if (env["FAKE_RUNNER_LOAD_FRAMES"]) wdFrame = 1307 + 1771 * n;
      }
    }
    const se = loadProblem ? [] : gd.filter((f) => (text.get(f) ?? "").includes("FAKE_SCRIPT_ERROR"));
    checks.push({ id: "smoke.loads", ok: !loadProblem, detail: loadProblem ? `the pack did not load: ${loadProblem.message}` : "pack loaded" });
    if (loadProblem) errors.push(loadProblem);
    for (const f of se) {
      const ln = (text.get(f) ?? "").split(/\r?\n/).findIndex((l) => l.includes("FAKE_SCRIPT_ERROR")) + 1;
      errors.push({ kind: "script_error", file: f, line: ln, message: "Invalid call. Nonexistent function 'FAKE_SCRIPT_ERROR'." });
    }
    checks.push({ id: "smoke.no_script_errors", ok: se.length === 0, detail: `${se.length} errors in ${loadProblem ? 0 : frames} frames` });
    checks.push({ id: "smoke.no_engine_errors", ok: true, detail: "0 engine errors" });
    checks.push({ id: "smoke.watchdog", ok: !wd, detail: wd ? "tick_timeout: _pack_tick did not return within 250 ms (runaway script); the process was stopped" : `no trip in ${loadProblem ? 0 : frames} frames` });
    if (wd) {
      outcome = "watchdog";
      errors.push({ kind: "watchdog", file: wd, message: `tick_timeout: _pack_tick did not return within 250 ms (runaway script); the process was stopped${wdFrame !== undefined ? ` (frame ${wdFrame})` : ""}` });
    }
    if (loadProblem || se.length > 0) fail();
    if (!loadProblem && !wd && verb !== "capture") {
      report["metrics"] = { state_hash: stateHash(seed, frames), frame_ms_p50: 0.2, frame_ms_p99: 0.4, entities_max: 12, bodies_max: 3, tick_ms_max: 0.03 };
    }

    if (verb === "invariants" && !loadProblem && !wd) {
      const nd = has("FAKE_NONDETERMINISTIC");
      checks.push({ id: "invariants.determinism", ok: !nd, detail: nd ? "state_hash differs between two runs" : "two runs agree" });
      checks.push({ id: "invariants.below_ground", ok: true, detail: "no physics body below y = -50" });
      checks.push({ id: "invariants.frame_budget", ok: true, detail: "frame p99 0.400 ms (budget 8 ms)" });
      checks.push({ id: "invariants.entity_budget", ok: true, detail: "12 nodes (budget 5000), 3 physics bodies (budget 600)" });
      // As the engine since WP5 (seen in the second real job's reports and in site/_engine_snapshot3): the first bot
      // is played twice, for at most --bot-frames frames, and both runs must end in the same state.
      if (tests[0] !== undefined) {
        const h = stateHash(seed, opts["bot-frames"] ?? "36000");
        checks.push({ id: "invariants.bot_deterministic", ok: !nd, detail: nd ? `bot ${tests[0]} twice, seed ${seed}: two different states` : `bot ${tests[0]} twice, seed ${seed}: ${h.slice(0, 16)} after 600 frames` });
        Object.assign(report["metrics"] as Record<string, unknown>, { bot_state_hash: h, bot_frames: 600 });
      }
      if (nd) {
        errors.push({ kind: "determinism", file: nd, message: "same seed gave two different state hashes" });
        (report["metrics"] as Record<string, unknown>)["state_hash_b"] = stateHash(`${seed}b`, frames);
        fail();
      }
    } else if (verb === "bot") {
      const ran = !loadProblem && !wd && test !== undefined;
      const body = ran ? (text.get(test as string) ?? "") : "";
      const never = ran && body.includes("FAKE_BOT_NEVER_DONE");
      // FAKE_BOT_NEEDS(<token>) anywhere in the pack: the bot only succeeds when some file holds FAKE_HAS(<token>).
      // This is how a test makes one package's change break another package's bot (and that package able to fix it).
      const all = [...text.values()].join("\n");
      const unmet = [...all.matchAll(/FAKE_BOT_NEEDS\((\w+)\)/g)].map((m) => m[1] as string).filter((t) => !all.includes(`FAKE_HAS(${t})`));
      const botFail = ran && (body.includes("FAKE_BOT_FAIL") || unmet.length > 0);
      const done = ran && !never;
      checks.push({ id: "bot.completed", ok: done, detail: !ran ? "the bot did not run" : done ? "done at frame 600" : `not done within ${frames} frames` });
      checks.push({ id: "bot.ok", ok: done && !botFail, detail: !ran ? "the bot did not run" : never ? "never done" : botFail ? "bot reported ok=false" : "played to full time" });
      if (ran) {
        report["bot"] = {
          test,
          done,
          frames: done ? 600 : Number(frames),
          result: { ok: done && !botFail, summary: never ? "never done" : botFail ? "lost the rally" : "played to full time" },
        };
      }
      if (never) {
        // RUNNER.md as amended: exit 1, outcome failed. The snapshot engine still answers exit 3, outcome watchdog.
        if (env["FAKE_RUNNER_BOT_TIMEOUT"] === "watchdog") {
          outcome = "watchdog";
          const w = checks.find((c) => c.id === "smoke.watchdog");
          if (w) {
            w.ok = false;
            w.detail = `frame_budget: the bot was not done after ${frames} frames`;
          }
          errors.push({ kind: "watchdog", file: test as string, message: `frame_budget: the bot was not done after ${frames} frames` });
        } else {
          errors.push({ kind: "bot", file: test as string, message: `the bot was not done after ${frames} frames` });
          fail();
        }
      }
      if (botFail) {
        errors.push({ kind: "bot", file: test as string, message: "bot result ok=false" });
        fail();
      }
    } else if (verb === "capture" && !wd) {
      const out = opts["out"] as string;
      let planted = !loadProblem && has("FAKE_CAPTURE_FAIL") !== undefined;
      const quota = Number(env["FAKE_RUNNER_CAPTURE_FAILS"] ?? "0");
      if (!loadProblem && quota > 0) {
        // Counted in a file beside the report so that a second process (the retry) sees the first one's failure.
        const counter = path.join(path.dirname(opts["report"] as string), ".fake-capture-fails");
        const n = fs.existsSync(counter) ? Number(fs.readFileSync(counter, "utf8")) : 0;
        if (n < quota) {
          fs.mkdirSync(path.dirname(counter), { recursive: true });
          fs.writeFileSync(counter, String(n + 1));
          planted = true;
        }
      }
      const written = !loadProblem && !planted;
      const [w, h] = /^(\d+)x(\d+)$/.exec(opts["res"] ?? "1920x1080")?.slice(1).map(Number) ?? [1920, 1080];
      if (written) {
        fs.mkdirSync(path.dirname(out), { recursive: true });
        // The smallest valid PNG (one transparent pixel) plus a tEXt chunk that stands for "what the camera sees":
        // a hash of the pack's files, the camera and the frame. A file whose text contains FAKE_INVISIBLE, the
        // tests and the manifest do not count, so a package can change the pack without changing the picture
        // (the first real job's art pass did exactly that) and a test can tell the two cases apart.
        const png = Buffer.from("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=", "base64");
        const seen = crypto.createHash("sha1");
        const visit = (rel: string): void => {
          for (const e of fs.readdirSync(path.join(packDir, rel), { withFileTypes: true }).sort((x, y) => (x.name < y.name ? -1 : 1))) {
            const r = rel ? `${rel}/${e.name}` : e.name;
            if (e.isDirectory()) {
              if (r !== "tests") visit(r);
            } else if (r !== "pack.json") {
              const body = fs.readFileSync(path.join(packDir, r));
              if (!body.includes("FAKE_INVISIBLE")) seen.update(r).update(body);
            }
          }
        };
        visit("");
        const text = Buffer.from(`Comment\0fake view ${opts["cam"] ?? ""} f${frames} ${seen.digest("hex")}`, "latin1");
        const typeAndData = Buffer.concat([Buffer.from("tEXt", "latin1"), text]);
        const chunk = Buffer.alloc(8 + text.length + 4);
        chunk.writeUInt32BE(text.length, 0);
        typeAndData.copy(chunk, 4);
        chunk.writeUInt32BE(zlib.crc32(typeAndData) >>> 0, 8 + text.length);
        // IEND is the last 12 bytes: the text chunk goes in front of it.
        fs.writeFileSync(out, Buffer.concat([png.subarray(0, png.length - 12), chunk, png.subarray(png.length - 12)]));
        report["capture"] = { cam: opts["cam"], frame: Number(frames), file: out, width: w, height: h };
      }
      checks.push({ id: "capture.written", ok: written, detail: written ? `${out}, ${w}x${h} at frame ${frames} (rendering driver: fake)` : "no image was written (rendering driver: fake)" });
      if (!written) {
        if (planted) errors.push({ kind: "engine", message: "the capture worker ended without an image" });
        fail();
      }
    }
  }
  if (disagree) {
    // Says one thing in the report and another with the exit code.
    forceExit = outcome === "passed" ? 1 : 0;
  }
  return finish();
}

const sleep = (ms: number): Promise<void> => new Promise((r) => setTimeout(r, ms));

/** The same runner as an in-process spawn function, for tests that do not want a process per verification. */
export function inProcessFakeRunner(extraEnv: NodeJS.ProcessEnv = {}): SpawnFn {
  return async (req: RunProcessRequest): Promise<RunProcessResult> => {
    const started = Date.now();
    // The verifier puts the runner script first when a script stands in for the engine; skip it.
    const out = fakeRunner(req.args, { ...(req.env ?? {}), ...extraEnv });
    if (out.hang) {
      await sleep(req.timeoutMs);
      return { stdout: "", stderr: "", timedOut: true, outputCapped: false, durationMs: Date.now() - started };
    }
    return { exitCode: out.exitCode, stdout: out.stdout, stderr: "", timedOut: false, outputCapped: false, durationMs: Date.now() - started };
  };
}
