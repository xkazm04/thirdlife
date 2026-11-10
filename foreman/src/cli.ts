#!/usr/bin/env node
// foreman: probe | new | approve | plan | run | resume | status | verify | answer | cancel | init-fixture
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { pathToFileURL } from "node:url";
import { ADAPTERS, BUDGET_KINDS, EventError, VERBS, type AdapterName, type BudgetPolicy, type JobEvent, type Milestone, type PackageSpec, type Verb } from "./events.js";
import { JobLog, LogError, rebuildState, type JobState } from "./joblog.js";
import type { Builder, ProbeResult } from "./builder/types.js";
import { FakeBuilder } from "./builder/fake.js";
import { ClaudeCliBuilder } from "./builder/claude-cli.js";
import { MessagesApiBuilder } from "./builder/messages-api.js";
import { Verifier, resolveRunner } from "./verifier.js";
import { Foreman, ForemanError, restsOnAClock } from "./foreman.js";
import { designBrief, planCheck, planPackages, renderPlannerPrompt, type GenerateCall } from "./designer.js";
import { existingText, isEmptyReference, prepareReference, referenceOf } from "./reference.js";
import { schemaErrors } from "./builder/json.js";
import { killAllChildren, type SpawnFn } from "./proc.js";
import { LEDGER_FILE, ledgerSpawn, reapOrphans } from "./orphans.js";
import { FAKE_RUNNER, PKG_ROOT, REPO_ROOT, toPosix } from "./paths.js";

export class UsageError extends Error {}

interface Args {
  cmd: string;
  pos: string[];
  flags: Record<string, string | true>;
}

const BOOLEAN_FLAGS = new Set(["auto-approve", "allow-edit", "no-promote", "retry-failed", "quiet", "json", "force-subscription", "help", "no-critic", "no-reference", "planner-only", "builder-only"]);

export function parseArgs(argv: string[]): Args {
  const pos: string[] = [];
  const flags: Record<string, string | true> = {};
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i] as string;
    if (a.startsWith("--")) {
      const eq = a.indexOf("=");
      const name = eq === -1 ? a.slice(2) : a.slice(2, eq);
      if (eq !== -1) flags[name] = a.slice(eq + 1);
      else if (BOOLEAN_FLAGS.has(name)) flags[name] = true;
      else {
        const v = argv[i + 1];
        if (v === undefined) throw new UsageError(`--${name} needs a value`);
        flags[name] = v;
        i += 1;
      }
    } else pos.push(a);
  }
  return { cmd: pos[0] ?? "help", pos: pos.slice(1), flags };
}

const str = (a: Args, name: string): string | undefined => (typeof a.flags[name] === "string" ? (a.flags[name] as string) : undefined);
const num = (a: Args, name: string): number | undefined => {
  const v = str(a, name);
  if (v === undefined) return undefined;
  const n = Number(v);
  if (!Number.isFinite(n)) throw new UsageError(`--${name} must be a number`);
  return n;
};

const HELP = `foreman <command>

  probe [--adapter claude-cli|messages-api|fake] [--api-key-var NAME] [--json]
        adapter, version, authorization and billing mode; spends no tokens
  new "<sentence>" [--site DIR] [--adapter A] [--auto-approve] [--model M]
        creates site/<job_id>/ and asks the Designer for a brief
  approve <job>                      the player approves the brief
  plan <job> [--from plan.json] [--adapter A] [--model M] [--max-packages N] [--builder-timeout-ms N]
        asks the Planner for packages, or takes a hand-written plan; a plan over the limit is sent back once.
        --builder-timeout-ms is the time limit of one builder run that the Planner sizes packages for (give the
        same number as run's --timeout-ms; default 1800000). Prepares <job>/ref/ from the engine directory.
  prompts <job> [--max-packages N] [--timeout-ms N] [--round-limit N] [--package ID] [--planner-only|--builder-only]
        dry check: prints the assembled Planner prompt and every package's builder prompt; calls no model
  run <job> [--adapter fake|claude-cli] [--parallel N] [--runner fake] [--fake-script FILE] [--allow-edit]
            [--budget tokens_per_hour:N|only_while_playing|overnight:HH:MM-HH:MM] [--round-limit N]
            [--timeout-ms N] [--model M] [--no-promote] [--retry-failed] [--force-subscription] [--quiet]
            [--promote-to job|engine]   job (default): <job>/promoted/<pack id>/; engine: <engine>/packs/<pack id>/,
                                        falling back to the job directory when the engine is not writable
            [--hide-env NAME,PREFIX_*]   more variables the claude CLI must not see (also TL_HIDE_ENV); edit runs
                                         never inherit names containing KEY, TOKEN, SECRET or PASSWORD
            [--max-replans N] [--max-packages N]   re-plans per job (default 3), packages a re-plan may leave
            [--no-critic] [--capture-res WxH] [--no-reference] [--planner-model M] [--critic-model M]
  resume <job> [same options as run]  continues from job.jsonl; promoted packages are never rebuilt
  status <job> [--json]              one row per package: state, round, last cause
  verify <pack dir> [--verbs all|lint,smoke,...] [--runner fake] [--reports DIR] [--<verb>-args "..."]
        default: all five verbs (every manifest test as a bot, every manifest camera as a capture)
  answer <job> <package> "<text>"    answers a builder's question
  comment <job> <milestone> "<text>" the player's comment on a milestone the job has reached (a comment event)
  cancel <job> [--reason TEXT]       marks every unfinished package failed (cause cancelled) and the job cancelled
  init-fixture <dest dir>            copies the three-package fixture job to a fresh directory

<job> is a job directory or a job id under --site (default: <repo>/site).
Environment: TL_GODOT (runner executable; a .js file is run with node), TL_ENGINE_DIR, TL_CLAUDE_BIN,
TL_PLAYING_FILE (only_while_playing: the player is in the world while this file exists).`;

function siteDir(a: Args): string {
  return path.resolve(str(a, "site") ?? path.join(REPO_ROOT, "site"));
}

function jobDirOf(a: Args, idx = 0): string {
  const j = a.pos[idx];
  if (!j) throw new UsageError("missing <job>");
  const direct = path.resolve(j);
  if (fs.existsSync(path.join(direct, "job.jsonl"))) return direct;
  const inSite = path.join(siteDir(a), j);
  if (fs.existsSync(path.join(inSite, "job.jsonl"))) return inSite;
  throw new UsageError(`no job.jsonl in ${direct} or ${inSite}`);
}

function makeBuilder(a: Args, jobDir?: string, fallback: AdapterName = "claude-cli", spawn?: SpawnFn): Builder {
  const name = (str(a, "adapter") ?? fallback) as AdapterName;
  if (!(ADAPTERS as readonly string[]).includes(name)) throw new UsageError(`unknown adapter "${name}" (${ADAPTERS.join(", ")})`);
  if (name === "fake") {
    const script = str(a, "fake-script") ?? (jobDir ? path.join(jobDir, "fake-builder.json") : undefined);
    if (!script || !fs.existsSync(script)) throw new UsageError(`the fake adapter needs a script: --fake-script FILE (looked for ${script ?? "nothing"})`);
    return FakeBuilder.fromFile(script);
  }
  if (name === "messages-api") {
    const keyVar = str(a, "api-key-var");
    return new MessagesApiBuilder(keyVar !== undefined ? { keyVar } : {});
  }
  return new ClaudeCliBuilder({
    allowEdit: a.flags["allow-edit"] === true,
    billing: a.flags["force-subscription"] === true ? "subscription" : "inherit",
    hideEnv: (str(a, "hide-env") ?? process.env["TL_HIDE_ENV"] ?? "").split(",").map((s) => s.trim()).filter(Boolean),
    ...(spawn ? { spawn } : {}),
  });
}

/** Who holds the job's single-writer lock, and whether that process still exists. */
export function lockHolder(jobDir: string): { pid?: number; alive: boolean } {
  const lockFile = path.join(jobDir, "foreman.lock");
  if (!fs.existsSync(lockFile)) return { alive: false };
  const pid = Number(fs.readFileSync(lockFile, "utf8").trim());
  if (!Number.isInteger(pid)) return { alive: false };
  if (pid === process.pid) return { pid, alive: false };
  try {
    process.kill(pid, 0);
    return { pid, alive: true };
  } catch (e) {
    return { pid, alive: (e as NodeJS.ErrnoException).code === "EPERM" };
  }
}

/** Optional per-job settings in <job>/foreman.config.json. Unknown keys are errors. */
export interface JobConfig {
  /** Runner executable for this job; "@fake" is the bundled fake runner. Beats TL_GODOT, loses to --runner. */
  godot?: string;
  /** Engine directory for this job (relative to the job directory). Beats TL_ENGINE_DIR, loses to --engine-dir. */
  engineDir?: string;
}
export const JOB_CONFIG_FILE = "foreman.config.json";

export function readJobConfig(jobDir: string): JobConfig {
  const file = path.join(jobDir, JOB_CONFIG_FILE);
  if (!fs.existsSync(file)) return {};
  const raw = JSON.parse(fs.readFileSync(file, "utf8")) as Record<string, unknown>;
  const errs = schemaErrors(
    { type: "object", additionalProperties: false, properties: { godot: { type: "string", minLength: 1 }, engineDir: { type: "string", minLength: 1 } } },
    raw,
  );
  if (errs.length > 0) throw new UsageError(`${file}: ${errs.join("; ")}`);
  const cfg: JobConfig = {};
  if (typeof raw["godot"] === "string") cfg.godot = raw["godot"] === "@fake" ? FAKE_RUNNER : path.resolve(jobDir, raw["godot"]);
  if (typeof raw["engineDir"] === "string") cfg.engineDir = path.resolve(jobDir, raw["engineDir"]);
  return cfg;
}

/** Runner choice, strongest first: command-line flags, the job's own config file, the environment, the defaults. */
function makeVerifier(a: Args, spawn?: SpawnFn, cfg: JobConfig = {}): Verifier {
  const flagEngine = str(a, "engine-dir");
  const env: NodeJS.ProcessEnv = { ...process.env };
  if (cfg.godot) env["TL_GODOT"] = cfg.godot;
  if (cfg.engineDir) env["TL_ENGINE_DIR"] = cfg.engineDir;
  const r = resolveRunner(env, { fake: str(a, "runner") === "fake", ...(flagEngine ? { engineDir: flagEngine } : {}) });
  const t = num(a, "verify-timeout-ms");
  return new Verifier({ godot: r.godot, engineDir: r.engineDir, ...(t !== undefined ? { timeoutMs: t } : {}), ...(spawn ? { spawn } : {}) });
}

/** The engine directory a job-level command (plan, prompts) reads its reference from: flag, job config, environment, default. */
function engineDirFor(a: Args, jobDir: string): string {
  const cfg = readJobConfig(jobDir);
  const env: NodeJS.ProcessEnv = { ...process.env, ...(cfg.engineDir ? { TL_ENGINE_DIR: cfg.engineDir } : {}) };
  const flagEngine = str(a, "engine-dir");
  return resolveRunner(env, flagEngine ? { engineDir: flagEngine } : {}).engineDir;
}

/**
 * What the Planner is told beyond the brief: the kernel API text, what exists (read from <job>/ref, which is
 * prepared here from the engine directory if the job has none yet) and the builder time limit.
 */
function plannerContext(a: Args, jobDir: string): { kernelApi?: string; existing: string; builderTimeoutMs?: number } {
  const refDir = path.join(jobDir, "ref");
  if (a.flags["no-reference"] !== true) prepareReference(refDir, referenceOf(engineDirFor(a, jobDir)));
  const api = path.join(refDir, "API.md");
  const t = num(a, "builder-timeout-ms");
  return { ...(fs.existsSync(api) ? { kernelApi: fs.readFileSync(api, "utf8") } : {}), existing: existingText(refDir), ...(t !== undefined ? { builderTimeoutMs: t } : {}) };
}

function printProbe(p: ProbeResult, out: (s: string) => void): void {
  out(`adapter     ${p.adapter}`);
  out(`available   ${p.ok ? "yes" : "no"}`);
  out(`installed   ${p.installed ? "yes" : "no"}${p.executable ? `  (${toPosix(p.executable)})` : ""}`);
  out(`version     ${p.version ?? "unknown"}`);
  out(`auth        ${p.auth}`);
  out(`billing     ${p.billing.mode}`);
  out(`evidence    ${p.billing.evidence}`);
  out(`probe cost  ${p.zeroCost ? "0 tokens" : "spends tokens"}`);
  for (const n of p.notes) out(`note        ${n}`);
}

function slugify(sentence: string): string {
  const words = sentence
    .toLowerCase()
    .normalize("NFKD")
    .replace(/[^a-z0-9]+/g, " ")
    .trim()
    .split(/\s+/)
    .filter((w) => w.length > 0 && !["a", "an", "the", "in", "on", "of", "and", "with", "game"].includes(w))
    .slice(0, 4);
  const slug = words.join("-").replace(/^[^a-z]+/, "");
  return slug.length > 0 ? slug.slice(0, 40) : "game";
}

function writeGenerateCalls(log: JobLog, builder: Builder, calls: GenerateCall[], model: string | undefined): void {
  for (const c of calls) {
    const file = path.join(log.jobDir, "reports", `${c.role}-a${c.attempt}-s${log.state.lastSeq + 1}.json`);
    fs.mkdirSync(path.dirname(file), { recursive: true });
    fs.writeFileSync(
      file,
      JSON.stringify(
        {
          schema: "tl.foreman.transcript/1",
          adapter: builder.name,
          role: c.role,
          attempt: c.attempt,
          mode: "generate",
          prompt: c.prompt,
          problems: c.problems,
          result: { ok: c.result.ok, outcome: c.result.outcome, text: c.result.text, json: c.result.json, error: c.result.error, tokensIn: c.result.tokensIn, tokensOut: c.result.tokensOut, durationMs: c.result.durationMs, observed: c.result.observed },
          raw: c.result.raw,
        },
        null,
        1,
      ) + "\n",
    );
    log.append({
      type: "builder_run",
      adapter: builder.name,
      mode: "generate",
      model: c.result.model ?? model ?? "default",
      outcome: c.result.outcome,
      durationMs: Math.max(0, Math.round(c.result.durationMs)),
      ...(c.result.tokensIn !== undefined ? { tokensIn: c.result.tokensIn } : {}),
      ...(c.result.tokensOut !== undefined ? { tokensOut: c.result.tokensOut } : {}),
      ...(c.result.tokensCacheRead !== undefined ? { tokensCacheRead: c.result.tokensCacheRead } : {}),
      transcript: toPosix(path.relative(log.jobDir, file)),
    });
  }
}

async function ensureBilling(log: JobLog, builder: Builder): Promise<ProbeResult> {
  const probe = await builder.probe();
  const b = log.state.billing;
  if (!b || b.adapter !== probe.adapter || b.mode !== probe.billing.mode || b.evidence !== probe.billing.evidence) {
    log.append({ type: "billing", adapter: probe.adapter, mode: probe.billing.mode, evidence: probe.billing.evidence });
  }
  return probe;
}

function eventLine(ev: JobEvent): string {
  const head = `${String(ev.seq).padStart(4)} ${ev.ts.slice(11, 19)} ${ev.type.padEnd(13)}`;
  switch (ev.type) {
    case "package_state":
      return `${head} ${ev.package} ${ev.state} r${ev.round}${ev.cause ? ` cause=${ev.cause}` : ""}${ev.detail ? ` (${ev.detail})` : ""}`;
    case "builder_run":
      return `${head} ${ev.package ?? "(job)"} ${ev.adapter}/${ev.mode} ${ev.outcome} ${ev.durationMs}ms${ev.tokensIn !== undefined ? ` in=${ev.tokensIn} out=${ev.tokensOut ?? 0}` : ""}${ev.tokensCacheRead !== undefined ? ` cacheRead=${ev.tokensCacheRead}` : ""}`;
    case "verify":
      return `${head} ${ev.package ?? "(pack)"} ${ev.verb} ${ev.level} ${ev.ok ? "ok" : "FAILED"}${ev.exitCode !== undefined ? ` exit=${ev.exitCode}` : ""} ${ev.report}`;
    case "merge":
      return `${head} ${ev.package} ${ev.files.length} files`;
    case "billing":
      return `${head} ${ev.adapter} ${ev.mode}: ${ev.evidence}`;
    case "budget":
      return `${head} ${ev.state}: ${ev.reason}`;
    case "job_state":
      return `${head} ${ev.state}${ev.reason ? `: ${ev.reason}` : ""}`;
    case "promoted":
      return `${head} ${ev.packId} ${ev.version} -> ${ev.dest}`;
    case "milestone":
      return `${head} ${ev.milestone}: ${ev.summary}`;
    case "question":
      return `${head} ${ev.package}: ${ev.text}`;
    case "note":
      return `${head} ${ev.package} r${ev.round} deviations: ${ev.text.replace(/\s+/g, " ").slice(0, 300)}`;
    default:
      return head;
  }
}

export function statusTable(s: JobState): string {
  const lines: string[] = [];
  lines.push(`job      ${s.job}${s.title ? `  "${s.title}"` : ""}${s.packId ? `  pack ${s.packId}` : ""}`);
  lines.push(`state    ${s.jobState?.state ?? "created"}${s.jobState?.reason ? `  (${s.jobState.reason})` : ""}   events ${s.lastSeq}${s.tornTail ? "   TORN LAST LINE" : ""}`);
  lines.push(`brief    ${s.brief ? (s.briefApprovedBy ? `approved by ${s.briefApprovedBy}` : "set, not approved") : "none"}   plan ${s.plan.length > 0 ? `${s.plan.length} packages (revision ${s.planRevision})` : "none"}`);
  if (s.billing) lines.push(`billing  ${s.billing.adapter} ${s.billing.mode}: ${s.billing.evidence}`);
  if (s.budget) lines.push(`budget   ${s.budget.policy.kind}${s.budget.policy.limit !== undefined ? ` ${s.budget.policy.limit}` : ""} ${s.budget.state}: ${s.budget.reason}`);
  lines.push(`tokens   in ${s.tokens.in}  out ${s.tokens.out}${s.tokens.unreportedRuns > 0 ? `  (${s.tokens.unreportedRuns} runs reported none)` : ""}`);
  if (s.promoted) lines.push(`promoted ${s.promoted.packId} ${s.promoted.version} -> ${s.promoted.dest}`);
  if (s.replans > 0) lines.push(`replans  ${s.replans}${s.pendingReplan ? " (the last one has no plan_set yet)" : ""}`);
  for (const m of s.milestones) lines.push(`milestone ${m.milestone}: ${m.captures.length} capture(s)${m.captures.length > 0 ? ` (${m.captures.join(", ")})` : ""}`);
  const rows = s.order.map((id) => {
    const p = s.packages[id];
    if (!p) return [id, "?", "", "", "", "", ""];
    const last = p.lastVerify ? `${p.lastVerify.verb} ${p.lastVerify.ok ? "ok" : "FAILED"} r${p.lastVerify.round}` : "";
    return [p.id, p.state, String(p.round), p.milestone, String(p.builderRuns), p.cause ?? "", last, p.detail ?? ""];
  });
  const head = ["package", "state", "round", "milestone", "runs", "cause", "last verify", "detail"];
  const widths = head.map((h, i) => Math.min(i === 7 ? 60 : 24, Math.max(h.length, ...rows.map((r) => (r[i] ?? "").length))));
  const fmt = (r: string[]): string => r.map((c, i) => (c.length > (widths[i] ?? 0) ? c.slice(0, (widths[i] ?? 1) - 1) + "~" : c).padEnd(widths[i] ?? 0)).join("  ").trimEnd();
  lines.push("");
  lines.push(fmt(head));
  lines.push(widths.map((w) => "-".repeat(w)).join("  "));
  for (const r of rows) lines.push(fmt(r));
  return lines.join("\n");
}

/**
 * Copies the three-package fixture job in its pristine form: the log up to plan_set, the fake builder's script and
 * the job config. Whatever a run left behind in fixtures/job-paddle (if someone ran it in place) is not copied.
 */
export function copyFixture(dest: string): void {
  const src = path.join(PKG_ROOT, "fixtures", "job-paddle");
  fs.mkdirSync(dest, { recursive: true });
  const head = fs.readFileSync(path.join(src, "job.jsonl"), "utf8").split("\n").filter((l) => l.length > 0).slice(0, 4);
  fs.writeFileSync(path.join(dest, "job.jsonl"), head.map((l) => l + "\n").join(""));
  for (const f of ["fake-builder.json", JOB_CONFIG_FILE]) fs.copyFileSync(path.join(src, f), path.join(dest, f));
}

function parseBudget(v: string | undefined): BudgetPolicy | undefined {
  if (v === undefined) return undefined;
  const i = v.indexOf(":");
  const kind = (i === -1 ? v : v.slice(0, i)) as BudgetPolicy["kind"];
  const rest = i === -1 ? undefined : v.slice(i + 1);
  if (!(BUDGET_KINDS as readonly string[]).includes(kind)) throw new UsageError(`unknown budget kind "${kind}" (${BUDGET_KINDS.join(", ")})`);
  if (kind === "tokens_per_hour") {
    const n = Number(rest);
    if (rest === undefined || !Number.isFinite(n) || n < 1) throw new UsageError("tokens_per_hour needs a limit: --budget tokens_per_hour:200000");
    return { kind, limit: Math.floor(n) };
  }
  if (kind === "overnight") {
    const window = rest ?? "22:00-07:00";
    if (!/^\d{1,2}:\d{2}-\d{1,2}:\d{2}$/.test(window)) throw new UsageError("overnight needs a window: --budget overnight:22:00-07:00");
    return { kind, limit: window };
  }
  return { kind };
}

export async function main(argv: string[], out: (s: string) => void = (s) => process.stdout.write(s + "\n")): Promise<number> {
  const a = parseArgs(argv);
  if (a.flags["help"] === true || a.cmd === "help") {
    out(HELP);
    return 0;
  }
  switch (a.cmd) {
    case "probe": {
      const names = str(a, "adapter") ? [str(a, "adapter") as string] : ["claude-cli", "messages-api"];
      const results: ProbeResult[] = [];
      for (const n of names) {
        const b = n === "fake" ? new FakeBuilder({ steps: [] }) : makeBuilder({ ...a, flags: { ...a.flags, adapter: n } });
        results.push(await b.probe());
      }
      if (a.flags["json"] === true) out(JSON.stringify(results, null, 1));
      else
        results.forEach((p, i) => {
          if (i > 0) out("");
          printProbe(p, out);
        });
      return results.some((p) => p.ok) ? 0 : 1;
    }

    case "new": {
      const sentence = a.pos[0];
      if (!sentence || sentence.trim().length === 0) throw new UsageError('usage: foreman new "<sentence>"');
      const slug = slugify(sentence);
      const d = new Date();
      const ymd = `${d.getFullYear()}${String(d.getMonth() + 1).padStart(2, "0")}${String(d.getDate()).padStart(2, "0")}`;
      const site = siteDir(a);
      let n = 1;
      while (fs.existsSync(path.join(site, `${slug}-${ymd}-${n}`))) n += 1;
      const jobId = `${slug}-${ymd}-${n}`;
      const jobDir = path.join(site, jobId);
      const builder = makeBuilder(a, undefined);
      const log = JobLog.open(jobDir);
      try {
        // At most 80 characters (pack.schema.json), cut at a word boundary; the words before a colon when there is one.
        const whole = sentence.trim().replace(/\s+/g, " ").replace(/^./, (c) => c.toUpperCase());
        const head = whole.includes(":") ? (whole.split(":")[0] as string).trim() : whole;
        const title = (head.length <= 80 ? head : head.slice(0, 80).replace(/\s+\S*$/, "")) || whole.slice(0, 80);
        log.append({ type: "job_created", sentence: sentence.trim(), packId: `game.${slug.replace(/-/g, "_")}`, title });
        out(`job ${jobId} created in ${toPosix(jobDir)}`);
        const probe = await ensureBilling(log, builder);
        out(`billing: ${probe.billing.mode} (${probe.billing.evidence})`);
        if (!probe.ok) {
          log.append({ type: "job_state", state: "failed", reason: `builder ${probe.adapter} is not available: ${probe.notes.join("; ")}` });
          out(`builder not available: ${probe.notes.join("; ")}`);
          return 1;
        }
        const model = str(a, "model");
        const t = num(a, "timeout-ms");
        const res = await designBrief(builder, sentence.trim(), { ...(model ? { model } : {}), ...(t !== undefined ? { timeoutMs: t } : {}) });
        writeGenerateCalls(log, builder, res.calls, model);
        if (!res.ok) {
          log.append({ type: "job_state", state: "failed", reason: res.reason.slice(0, 400) });
          out(`Designer failed: ${res.reason}`);
          return 1;
        }
        log.append({ type: "brief_set", brief: res.value.brief, estimate: res.value.estimate });
        out(JSON.stringify(res.value, null, 1));
        if (a.flags["auto-approve"] === true) {
          log.append({ type: "brief_approved", by: "auto" });
          out("brief approved (auto)");
        } else out(`brief set; approve it with: foreman approve ${jobId}`);
        return 0;
      } finally {
        log.close();
      }
    }

    case "approve": {
      const log = JobLog.open(jobDirOf(a));
      try {
        if (!log.state.brief) throw new UsageError("this job has no brief yet");
        if (log.state.briefApprovedBy) out(`already approved by ${log.state.briefApprovedBy}`);
        else {
          log.append({ type: "brief_approved", by: "player" });
          out("brief approved by player");
        }
        return 0;
      } finally {
        log.close();
      }
    }

    case "plan": {
      const jobDir = jobDirOf(a);
      const from = str(a, "from");
      const log = JobLog.open(jobDir);
      try {
        const s = log.state;
        if (!s.brief || !s.sentence || !s.packId || !s.title) throw new UsageError("this job has no brief yet");
        if (!s.briefApprovedBy) throw new UsageError("the brief is not approved yet (foreman approve <job>)");
        let packages: PackageSpec[];
        const maxPackages = num(a, "max-packages");
        const limits = maxPackages !== undefined ? { maxPackages: Math.max(1, Math.floor(maxPackages)) } : {};
        if (from !== undefined) {
          const doc = JSON.parse(fs.readFileSync(path.resolve(from), "utf8")) as unknown;
          const planSchema = JSON.parse(fs.readFileSync(path.join(PKG_ROOT, "prompts", "plan.schema.json"), "utf8")) as object;
          const errs = schemaErrors(planSchema, doc);
          if (errs.length === 0) errs.push(...planCheck((doc as { packages: PackageSpec[] }).packages, limits));
          if (errs.length > 0) {
            out(`plan rejected:\n${errs.map((e) => `  - ${e}`).join("\n")}`);
            return 1;
          }
          packages = (doc as { packages: PackageSpec[] }).packages;
        } else {
          const builder = makeBuilder(a, jobDir);
          const probe = await ensureBilling(log, builder);
          if (!probe.ok) {
            out(`builder not available: ${probe.notes.join("; ")}`);
            return 1;
          }
          const model = str(a, "model");
          const res = await planPackages(
            builder,
            { sentence: s.sentence, packId: s.packId, title: s.title, brief: s.brief, ...plannerContext(a, jobDir) },
            { ...(model ? { model } : {}), ...limits },
          );
          writeGenerateCalls(log, builder, res.calls, model);
          if (!res.ok) {
            out(`Planner failed: ${res.reason}`);
            return 1;
          }
          packages = res.value.packages;
        }
        if (log.state.plan.length > 0) {
          const old = new Set(log.state.order);
          const next = new Set(packages.map((p) => p.id));
          log.append({
            type: "replan",
            reason: from !== undefined ? `new hand-written plan from ${path.basename(from)}` : "new plan from the Planner",
            added: [...next].filter((x) => !old.has(x)),
            removed: [...old].filter((x) => !next.has(x)),
            changed: [...next].filter((x) => old.has(x) && JSON.stringify(log.state.plan.find((p) => p.id === x)) !== JSON.stringify(packages.find((p) => p.id === x))),
          });
        }
        log.append({ type: "plan_set", packages });
        for (const p of packages) if (!log.state.packages[p.id]?.announced) log.append({ type: "package_state", package: p.id, state: "queued", round: 1 });
        out(`plan set: ${packages.map((p) => `${p.id}${p.deps.length ? `<-${p.deps.join("+")}` : ""}`).join(", ")}`);
        return 0;
      } finally {
        log.close();
      }
    }

    case "prompts": {
      // Dry check: prints the Planner prompt and the builder prompts exactly as they would be sent. No model call.
      const jobDir = jobDirOf(a);
      const s = rebuildState(jobDir);
      if (!s.brief || !s.sentence || !s.packId || !s.title) throw new UsageError("this job has no brief yet");
      const maxPackages = num(a, "max-packages");
      const timeoutMs = num(a, "timeout-ms") ?? num(a, "builder-timeout-ms");
      const ctx = plannerContext(a, jobDir);
      const bar = (title: string): string => `\n==================== ${title} ====================\n`;
      if (a.flags["builder-only"] !== true) {
        out(bar(`PLANNER PROMPT (job ${s.job}, engine ${toPosix(engineDirFor(a, jobDir))})`));
        out(
          renderPlannerPrompt(
            { sentence: s.sentence, packId: s.packId, title: s.title, brief: s.brief, ...ctx, ...(timeoutMs !== undefined ? { builderTimeoutMs: timeoutMs } : {}) },
            maxPackages !== undefined ? { maxPackages: Math.max(1, Math.floor(maxPackages)) } : {},
          ),
        );
      }
      if (a.flags["planner-only"] !== true) {
        if (s.plan.length === 0) {
          out(bar("BUILDER PROMPT: none, this job has no plan yet"));
          return 0;
        }
        const verifier = makeVerifier(a, undefined, readJobConfig(jobDir));
        const roundLimit = num(a, "round-limit");
        const foreman = new Foreman({
          jobDir,
          builder: new FakeBuilder({ steps: [] }),
          verifier,
          ...(timeoutMs !== undefined ? { builderTimeoutMs: timeoutMs } : {}),
          ...(roundLimit !== undefined ? { roundLimit: Math.max(1, Math.floor(roundLimit)) } : {}),
          ...(a.flags["no-reference"] === true ? {} : { reference: referenceOf(verifier.location.engineDir) }),
        });
        for (const p of foreman.previewBuilderPrompts(str(a, "package"))) {
          out(bar(`BUILDER PROMPT: package ${p.package}, round ${p.round}`));
          out(p.prompt);
        }
      }
      return 0;
    }

    case "run":
    case "resume": {
      const jobDir = jobDirOf(a);
      const quiet = a.flags["quiet"] === true;
      // Children of a Foreman that was killed hard may still be running in this job's workspaces: end them first.
      // (Only when no other Foreman holds the job: JobLog.open refuses that case a moment later anyway.)
      const ledger = path.join(jobDir, LEDGER_FILE);
      if (!lockHolder(jobDir).alive) {
        const reaped = reapOrphans(ledger);
        if (!quiet && reaped.killed.length > 0) out(`orphans  killed ${reaped.killed.length} process(es) left by a previous Foreman: ${reaped.killed.join(", ")}`);
      }
      const spawnDoor = ledgerSpawn(ledger);
      const builder = makeBuilder(a, jobDir, "fake", spawnDoor);
      const verifier = makeVerifier(a, spawnDoor, readJobConfig(jobDir));
      const budget = parseBudget(str(a, "budget"));
      const playingFile = process.env["TL_PLAYING_FILE"];
      if (!quiet) {
        out(`runner   ${toPosix(verifier.location.exe)} ${verifier.location.preArgs.map(toPosix).join(" ")}`.trimEnd());
        out(`engine   ${toPosix(verifier.location.engineDir)}`);
        out(`adapter  ${builder.name}`);
      }
      const parallel = num(a, "parallel");
      const roundLimit = num(a, "round-limit");
      const timeoutMs = num(a, "timeout-ms");
      const model = str(a, "model");
      const maxReplans = num(a, "max-replans");
      const maxPackages = num(a, "max-packages");
      const plannerModel = str(a, "planner-model");
      const criticModel = str(a, "critic-model");
      const captureRes = str(a, "capture-res");
      const promoteTo = str(a, "promote-to") ?? "job";
      if (promoteTo !== "job" && promoteTo !== "engine") throw new UsageError(`--promote-to takes "job" (default: <job>/promoted/<pack id>/) or "engine" (<engine>/packs/<pack id>/), got "${promoteTo}"`);
      const reference = a.flags["no-reference"] === true ? {} : referenceOf(verifier.location.engineDir);
      const foreman = new Foreman({
        jobDir,
        builder,
        verifier,
        ...(parallel !== undefined ? { parallel: Math.max(1, Math.floor(parallel)) } : {}),
        ...(roundLimit !== undefined ? { roundLimit: Math.max(1, Math.floor(roundLimit)) } : {}),
        ...(timeoutMs !== undefined ? { builderTimeoutMs: timeoutMs } : {}),
        ...(model ? { model } : {}),
        ...(budget ? { budget } : {}),
        ...(maxReplans !== undefined ? { maxReplans: Math.max(0, Math.floor(maxReplans)) } : {}),
        ...(maxPackages !== undefined ? { maxPackages: Math.max(1, Math.floor(maxPackages)) } : {}),
        ...(plannerModel ? { plannerModel } : {}),
        ...(criticModel ? { criticModel } : {}),
        ...(captureRes ? { captureRes } : {}),
        ...(!isEmptyReference(reference) ? { reference } : {}),
        critic: a.flags["no-critic"] !== true,
        promote: a.flags["no-promote"] !== true,
        promoteTo,
        retryFailed: a.flags["retry-failed"] === true,
        isPlaying: () => (playingFile ? fs.existsSync(playingFile) : false),
        ...(quiet ? {} : { onEvent: (ev: JobEvent) => out(eventLine(ev)) }),
      });
      const state = await foreman.run();
      if (!quiet) out("\n" + statusTable(state));
      return state.jobState?.state === "done" ? 0 : state.jobState?.state === "paused" ? 3 : 1;
    }

    case "status": {
      const jobDir = jobDirOf(a);
      const state = rebuildState(jobDir);
      if (a.flags["json"] === true) out(JSON.stringify(state, null, 1));
      else {
        out(statusTable(state));
        // The log cannot know that its writer died. The lock file can: say which it is.
        const holder = lockHolder(jobDir);
        const open = state.jobState?.state === "running";
        if (holder.alive) out(`\nforeman  running (pid ${holder.pid})`);
        else if (open) out(`\nforeman  NOT running${holder.pid !== undefined ? ` (pid ${holder.pid} is gone: it was killed)` : ""}; the log stops at event ${state.lastSeq}. Continue with: foreman resume ${state.job}`);
      }
      return 0;
    }

    case "verify": {
      const dir = a.pos[0];
      if (!dir || !fs.existsSync(dir)) throw new UsageError("usage: foreman verify <pack dir>");
      const verifier = makeVerifier(a);
      const all = (str(a, "verbs") ?? "all") === "all";
      const verbs = all ? [...VERBS] : (str(a, "verbs") as string).split(",").map((v) => v.trim());
      for (const v of verbs) if (!(VERBS as readonly string[]).includes(v)) throw new UsageError(`unknown verb "${v}" (${VERBS.join(", ")})`);
      const reports = path.resolve(str(a, "reports") ?? fs.mkdtempSync(path.join(os.tmpdir(), "tl-foreman-verify-")));
      const packDir = path.resolve(dir);
      out(`runner   ${toPosix(verifier.location.exe)} ${verifier.location.preArgs.map(toPosix).join(" ")}`.trimEnd());
      out(`engine   ${toPosix(verifier.location.engineDir)}`);
      out(`reports  ${toPosix(reports)}`);
      // Without explicit arguments, bot runs every test of the manifest and capture renders every declared camera.
      let tests: string[] = [];
      let cameras: string[] = [];
      try {
        const m = JSON.parse(fs.readFileSync(path.join(packDir, "pack.json"), "utf8")) as { tests?: unknown; cameras?: unknown };
        if (Array.isArray(m.tests)) tests = m.tests.filter((x): x is string => typeof x === "string");
        if (Array.isArray(m.cameras)) cameras = m.cameras.filter((x): x is string => typeof x === "string");
      } catch {
        /* lint reports a missing or broken manifest */
      }
      const runs: { verb: Verb; args: string[]; name: string }[] = [];
      for (const v of verbs as Verb[]) {
        const given = str(a, `${v}-args`);
        if (given !== undefined) runs.push({ verb: v, args: given.split(" ").filter(Boolean), name: v });
        else if (v === "bot" && tests.length > 0) for (const t of tests) runs.push({ verb: v, args: [`--test=${t}`], name: `bot-${path.basename(t, ".gd")}` });
        else if (v === "capture") {
          if (cameras.length === 0 && all) out(`capture    -   skipped: the manifest declares no camera`);
          else if (cameras.length === 0) runs.push({ verb: v, args: [], name: v });
          for (const cam of cameras) {
            runs.push({ verb: v, args: [`--cam=${cam}`, `--out=${toPosix(path.join(reports, `capture-${cam}.png`))}`, ...(tests[0] !== undefined ? [`--test=${tests[0]}`] : [])], name: `capture-${cam}` });
          }
        } else runs.push({ verb: v, args: [], name: v });
      }
      let allOk = true;
      for (const run of runs) {
        let r = await verifier.run({ verb: run.verb, args: run.args, packDir, reportFile: path.join(reports, `${run.name}.json`) });
        let retried = "";
        if (!r.ok && run.verb === "capture") {
          // The capture window can die in the graphics driver under GPU load: one more try before it is a failure.
          retried = "  (second attempt; the first failed)";
          r = await verifier.run({ verb: run.verb, args: run.args, packDir, reportFile: path.join(reports, `${run.name}.json`) });
        }
        if (!r.ok && restsOnAClock(r)) {
          // JOB.md: a verdict whose only failure is clock-based is run once more; both runs are shown, the second decides.
          out(`${run.name.padEnd(10)} ${r.level}  FAILED  exit=${r.exitCode ?? "-"}  ${r.durationMs}ms  ${r.summary}  (clock-based: running it once more)  [${toPosix(r.reportFile)}]`);
          retried = "  (second run of a clock-based verdict; this one decides)";
          r = await verifier.run({ verb: run.verb, args: run.args, packDir, reportFile: path.join(reports, `${run.name}-again.json`) });
        }
        allOk &&= r.ok;
        out(`${run.name.padEnd(10)} ${r.level}  ${r.ok ? "ok    " : "FAILED"}  exit=${r.exitCode ?? "-"}  ${r.durationMs}ms  ${r.flags.length ? `flags=${r.flags.join(",")}  ` : ""}${r.summary}${retried}  [${toPosix(r.reportFile)}]`);
        if (!r.ok && !all) break;
      }
      return allOk ? 0 : 1;
    }

    case "answer": {
      const pkgId = a.pos[1];
      const text = a.pos[2];
      if (!pkgId || !text) throw new UsageError('usage: foreman answer <job> <package> "<text>"');
      const log = JobLog.open(jobDirOf(a));
      try {
        const p = log.state.packages[pkgId];
        if (!p) throw new UsageError(`unknown package ${pkgId}`);
        if (p.openQuestion === undefined) throw new UsageError(`package ${pkgId} has no open question`);
        log.append({ type: "answer", package: pkgId, text, by: "player" });
        out(`answered; continue with: foreman resume ${log.job}`);
        return 0;
      } finally {
        log.close();
      }
    }

    case "comment": {
      const milestone = a.pos[1];
      const text = a.pos[2];
      if (!milestone || !text) throw new UsageError('usage: foreman comment <job> <milestone> "<text>"');
      const log = JobLog.open(jobDirOf(a));
      try {
        const reached = log.state.milestones.map((m) => m.milestone);
        if (!reached.includes(milestone)) throw new UsageError(`this job has no "${milestone}" milestone yet (reached: ${reached.join(", ") || "none"})`);
        log.append({ type: "comment", milestone: milestone as Milestone, text, by: "player" });
        out(`comment on ${milestone} recorded`);
        return 0;
      } finally {
        log.close();
      }
    }

    case "cancel": {
      // Works on a job no Foreman is running (the log's single-writer lock refuses otherwise): stop that one first.
      const log = JobLog.open(jobDirOf(a));
      try {
        const st = log.state.jobState?.state;
        if (st === "done" || st === "cancelled") {
          out(`job is already ${st}`);
          return 0;
        }
        for (const id of log.state.order) {
          const p = log.state.packages[id];
          if (!p || p.state === "promoted" || p.state === "failed") continue;
          log.append({ type: "package_state", package: id, state: "failed", round: p.round, cause: "cancelled", detail: `cancelled while ${p.state}` });
        }
        log.append({ type: "job_state", state: "cancelled", reason: str(a, "reason") ?? "cancelled by the player" });
        out(`job ${log.job} cancelled; promoted packages stay in pack/`);
        return 0;
      } finally {
        log.close();
      }
    }

    case "init-fixture": {
      const dest = a.pos[0];
      if (!dest) throw new UsageError("usage: foreman init-fixture <dest dir>");
      const abs = path.resolve(dest);
      if (fs.existsSync(abs) && fs.readdirSync(abs).length > 0) throw new UsageError(`${abs} exists and is not empty`);
      copyFixture(abs);
      out(`fixture job copied to ${toPosix(abs)}`);
      out(`next: node dist/cli.js run ${toPosix(abs)} --adapter fake`);
      out(`(its ${JOB_CONFIG_FILE} selects the fake runner; the finished pack is promoted to ${toPosix(path.join(abs, "promoted"))}/<pack id>/)`);
      return 0;
    }

    default:
      throw new UsageError(`unknown command "${a.cmd}"\n\n${HELP}`);
  }
}

const invoked = process.argv[1] !== undefined && import.meta.url === pathToFileURL(fs.realpathSync(process.argv[1])).href;
if (invoked) {
  process.on("exit", killAllChildren);
  for (const sig of ["SIGINT", "SIGTERM", "SIGBREAK"] as const) {
    process.on(sig, () => {
      killAllChildren();
      process.exit(130);
    });
  }
  main(process.argv.slice(2)).then(
    (code) => {
      process.exitCode = code;
    },
    (e: unknown) => {
      // Expected refusals (bad usage, a log that does not read, a job without a plan) are one line, not a stack.
      if (e instanceof UsageError || e instanceof LogError || e instanceof ForemanError || e instanceof EventError) process.stderr.write(`${e.name === "Error" ? "" : `${e.name}: `}${e.message}\n`);
      else process.stderr.write(`${e instanceof Error ? (e.stack ?? e.message) : String(e)}\n`);
      process.exitCode = 2;
    },
  );
}
