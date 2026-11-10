// The job log: append-only writer, strict reader, and state derived from the log alone.
import fs from "node:fs";
import path from "node:path";
import {
  validateEvent,
  EventError,
  type JobEvent,
  type EventBody,
  type PackageSpec,
  type PackageState,
  type Cause,
  type Brief,
  type Estimate,
  type BudgetPolicy,
  type Level,
  type Verb,
  type BuilderOutcome,
  type JobRunState,
} from "./events.js";

export const LOG_FILE = "job.jsonl";
export const STATE_FILE = "state.json";
export const LOCK_FILE = "foreman.lock";

export class LogError extends Error {
  constructor(
    message: string,
    public readonly line?: number,
  ) {
    super(line === undefined ? message : `job.jsonl line ${line}: ${message}`);
    this.name = "LogError";
  }
}

export interface ReadResult {
  events: JobEvent[];
  /** True when the file ends in an unterminated line that does not parse: a write cut by a kill. */
  tornTail: boolean;
  /** Byte length of the valid part of the file (everything before a torn tail). */
  validBytes: number;
}

/**
 * Strict reader. Every complete line must be a valid event with seq = line number and the same job id.
 * The only tolerated damage is a torn final line (no trailing newline, invalid JSON): a kill mid-write. It is
 * reported, never silently accepted, and `tolerateTornTail: false` turns it into an error as well.
 */
export function readLogText(text: string, opts: { tolerateTornTail?: boolean } = {}): ReadResult {
  const tolerate = opts.tolerateTornTail ?? true;
  const events: JobEvent[] = [];
  let tornTail = false;
  let validBytes = 0;
  let pos = 0;
  let lineNo = 0;
  let job: string | undefined;
  while (pos < text.length) {
    lineNo += 1;
    const nl = text.indexOf("\n", pos);
    const terminated = nl !== -1;
    const raw = terminated ? text.slice(pos, nl) : text.slice(pos);
    const next = terminated ? nl + 1 : text.length;
    const line = raw.endsWith("\r") ? raw.slice(0, -1) : raw;
    let parsed: unknown;
    try {
      parsed = JSON.parse(line);
    } catch {
      if (!terminated && tolerate) {
        tornTail = true;
        break;
      }
      throw new LogError(terminated ? "not valid JSON" : "torn final line (not valid JSON, no newline)", lineNo);
    }
    if (!terminated && !tolerate) throw new LogError("final line has no newline", lineNo);
    let ev: JobEvent;
    try {
      ev = validateEvent(parsed);
    } catch (e) {
      if (e instanceof EventError) throw new LogError(e.message, lineNo);
      throw e;
    }
    if (ev.seq !== lineNo) throw new LogError(`seq is ${ev.seq}, expected ${lineNo}`, lineNo);
    if (job === undefined) job = ev.job;
    else if (ev.job !== job) throw new LogError(`job is "${ev.job}", expected "${job}"`, lineNo);
    events.push(ev);
    validBytes = Buffer.byteLength(text.slice(0, next), "utf8");
    pos = next;
    if (!terminated) {
      // A complete, valid event without its newline: accepted, the writer adds the newline on open.
      break;
    }
  }
  return { events, tornTail, validBytes };
}

export function readLog(jobDir: string, opts: { tolerateTornTail?: boolean } = {}): ReadResult {
  const file = path.join(jobDir, LOG_FILE);
  if (!fs.existsSync(file)) return { events: [], tornTail: false, validBytes: 0 };
  return readLogText(fs.readFileSync(file, "utf8"), opts);
}

// ---------- derived state ----------

export interface PackageView {
  id: string;
  title: string;
  milestone: string;
  deps: string[];
  state: PackageState;
  /** False until the log holds a package_state event for this package. */
  announced: boolean;
  round: number;
  cause?: Cause;
  detail?: string;
  /** Rounds for which a builder_run with outcome ok is in the log. */
  builtRounds: number[];
  builderRuns: number;
  lastOutcome?: BuilderOutcome;
  lastVerify?: { round: number; level: Level; verb: Verb; ok: boolean; report: string; exitCode?: number };
  mergedFiles?: string[];
  tokensIn: number;
  tokensOut: number;
  openQuestion?: string;
  lastAnswer?: string;
}

export interface JobState {
  schema: "tl.state/1";
  job: string;
  lastSeq: number;
  lastTs?: string;
  tornTail: boolean;
  sentence?: string;
  packId?: string;
  title?: string;
  brief?: Brief;
  estimate?: Estimate;
  briefApprovedBy?: "player" | "auto";
  planRevision: number;
  plan: PackageSpec[];
  /** Package ids in plan order. */
  order: string[];
  packages: Record<string, PackageView>;
  packVerify?: { round: number; level: Level; verb: Verb; ok: boolean; report: string; exitCode?: number };
  /**
   * The last `budget` event. When the job has ended (done, failed, cancelled) the state is `closed`: nothing is
   * running or waiting any more. `open` keeps what the last event said, and comes back if the job is resumed.
   */
  budget?: { policy: BudgetPolicy; state: "running" | "paused" | "closed"; reason: string; open?: { state: "running" | "paused"; reason: string } };
  billing?: { adapter: string; mode: "subscription" | "api_key" | "none"; evidence: string };
  promoted?: { packId: string; version: string; dest: string };
  jobState?: { state: JobRunState; reason?: string };
  /** `cacheRead` is the part of `in` that came from the prompt cache (raw figure). */
  tokens: { in: number; out: number; cacheRead: number; unreportedRuns: number };
  /**
   * One entry per builder_run that reported tokens: the ledger the tokens_per_hour policy reads. `tokens` is the
   * WEIGHTED figure (JOB.md: cache-read tokens count at 0.1); the raw figures stay in the events.
   */
  tokenLedger: { ts: string; tokens: number }[];
  milestones: { milestone: string; captures: string[]; summary: string }[];
  /** Deviations builders stated (`note` events), in log order. */
  notes: { package: string; round: number; text: string }[];
  /** Number of `replan` events so far (JOB.md: at most three per job). */
  replans: number;
  /** Package ids that a replan has already covered: a package goes back to the Planner once. */
  replanned: string[];
  /** A `replan` event whose `plan_set` has not been written yet (a kill between the two). */
  pendingReplan?: { reason: string; added: string[]; removed: string[]; changed: string[] };
}

export function emptyState(job: string): JobState {
  return {
    schema: "tl.state/1",
    job,
    lastSeq: 0,
    tornTail: false,
    planRevision: 0,
    plan: [],
    order: [],
    packages: {},
    tokens: { in: 0, out: 0, cacheRead: 0, unreportedRuns: 0 },
    tokenLedger: [],
    milestones: [],
    notes: [],
    replans: 0,
    replanned: [],
  };
}

/** JOB.md (second round): cache-read tokens count at this weight against a token policy. */
export const CACHE_READ_WEIGHT = 0.1;

/** Tokens of one run as a token policy counts them: input that was not a cache read, plus 0.1 of the cache reads, plus output. */
export function weightedTokens(tokensIn: number, tokensOut: number, cacheRead = 0): number {
  const cr = Math.max(0, Math.min(tokensIn, cacheRead));
  return Math.round(tokensIn - cr + cr * CACHE_READ_WEIGHT + tokensOut);
}

/** The reducer: the only place where the meaning of an event is decided. Pure. */
export function applyEvent(s: JobState, ev: JobEvent): void {
  s.lastSeq = ev.seq;
  s.lastTs = ev.ts;
  switch (ev.type) {
    case "job_created":
      s.sentence = ev.sentence;
      s.packId = ev.packId;
      s.title = ev.title;
      break;
    case "brief_set":
      s.brief = ev.brief;
      s.estimate = ev.estimate;
      break;
    case "brief_approved":
      s.briefApprovedBy = ev.by;
      break;
    case "plan_set": {
      s.planRevision += 1;
      s.plan = ev.packages;
      s.order = ev.packages.map((p) => p.id);
      const next: Record<string, PackageView> = {};
      // Packages a replan re-cut start again from nothing; their token and run counters stay (they were spent).
      const recut = new Set(s.pendingReplan ? [...s.pendingReplan.added, ...s.pendingReplan.changed] : []);
      delete s.pendingReplan;
      for (const p of ev.packages) {
        const old = s.packages[p.id];
        const prev = old && recut.has(p.id) && old.state !== "promoted" ? undefined : old;
        if (old && !prev) {
          next[p.id] = { id: p.id, title: p.title, milestone: p.milestone, deps: p.deps, state: "queued", announced: false, round: 1, builtRounds: [], builderRuns: old.builderRuns, tokensIn: old.tokensIn, tokensOut: old.tokensOut };
          continue;
        }
        // A replan keeps what the log already says about a surviving package (a promoted one stays promoted).
        next[p.id] = prev
          ? { ...prev, title: p.title, milestone: p.milestone, deps: p.deps }
          : {
              id: p.id,
              title: p.title,
              milestone: p.milestone,
              deps: p.deps,
              state: "queued",
              announced: false,
              round: 1,
              builtRounds: [],
              builderRuns: 0,
              tokensIn: 0,
              tokensOut: 0,
            };
      }
      s.packages = next;
      break;
    }
    case "package_state": {
      const p = need(s, ev.package, ev);
      p.state = ev.state;
      p.announced = true;
      p.round = ev.round;
      if (ev.cause !== undefined) p.cause = ev.cause;
      else delete p.cause;
      if (ev.detail !== undefined) p.detail = ev.detail;
      else delete p.detail;
      break;
    }
    case "builder_run": {
      const tin = ev.tokensIn ?? 0;
      const tout = ev.tokensOut ?? 0;
      s.tokens.in += tin;
      s.tokens.out += tout;
      if (ev.tokensIn === undefined && ev.tokensOut === undefined) s.tokens.unreportedRuns += 1;
      else s.tokenLedger.push({ ts: ev.ts, tokens: weightedTokens(tin, tout, ev.tokensCacheRead) });
      s.tokens.cacheRead += Math.min(tin, ev.tokensCacheRead ?? 0);
      if (ev.package !== undefined) {
        const p = need(s, ev.package, ev);
        p.builderRuns += 1;
        p.lastOutcome = ev.outcome;
        p.tokensIn += tin;
        p.tokensOut += tout;
        if (ev.outcome === "ok" && ev.round !== undefined && !p.builtRounds.includes(ev.round)) {
          p.builtRounds.push(ev.round);
        }
      }
      break;
    }
    case "verify": {
      const v = {
        round: ev.round,
        level: ev.level,
        verb: ev.verb,
        ok: ev.ok,
        report: ev.report,
        ...(ev.exitCode !== undefined ? { exitCode: ev.exitCode } : {}),
      };
      if (ev.package !== undefined) need(s, ev.package, ev).lastVerify = v;
      else s.packVerify = v;
      break;
    }
    case "merge": {
      const p = need(s, ev.package, ev);
      // A resumed merge may log a second, smaller list: what counts is everything merged so far.
      const gone = new Set(ev.removed ?? []);
      p.mergedFiles = [...new Set([...(p.mergedFiles ?? []), ...ev.files])].filter((f) => !gone.has(f)).sort();
      break;
    }
    case "note":
      need(s, ev.package, ev);
      s.notes.push({ package: ev.package, round: ev.round, text: ev.text });
      break;
    case "question":
      need(s, ev.package, ev).openQuestion = ev.text;
      break;
    case "answer": {
      const p = need(s, ev.package, ev);
      delete p.openQuestion;
      p.lastAnswer = ev.text;
      break;
    }
    case "milestone":
      s.milestones.push({ milestone: ev.milestone, captures: ev.captures, summary: ev.summary });
      break;
    case "comment":
      break;
    case "replan":
      s.replans += 1;
      s.replanned = [...new Set([...s.replanned, ...ev.changed, ...ev.removed])];
      s.pendingReplan = { reason: ev.reason, added: ev.added, removed: ev.removed, changed: ev.changed };
      break;
    case "budget":
      s.budget = { policy: ev.policy, state: ev.state, reason: ev.reason };
      break;
    case "billing":
      s.billing = { adapter: ev.adapter, mode: ev.mode, evidence: ev.evidence };
      break;
    case "promoted":
      s.promoted = { packId: ev.packId, version: ev.version, dest: ev.dest };
      break;
    case "job_state":
      s.jobState = ev.reason !== undefined ? { state: ev.state, reason: ev.reason } : { state: ev.state };
      if (s.budget) {
        const ended = ev.state === "done" || ev.state === "failed" || ev.state === "cancelled";
        if (ended && s.budget.state !== "closed") {
          s.budget = { policy: s.budget.policy, state: "closed", reason: `job ended (${ev.state})`, open: { state: s.budget.state, reason: s.budget.reason } };
        } else if (!ended && s.budget.state === "closed" && s.budget.open) {
          s.budget = { policy: s.budget.policy, state: s.budget.open.state, reason: s.budget.open.reason };
        }
      }
      break;
  }
}

function need(s: JobState, id: string, ev: JobEvent): PackageView {
  const p = s.packages[id];
  if (!p) throw new LogError(`${ev.type} names package "${id}" that no plan_set before it declares`, ev.seq);
  return p;
}

export function foldEvents(job: string, events: JobEvent[], tornTail = false): JobState {
  const s = emptyState(events[0]?.job ?? job);
  s.tornTail = tornTail;
  for (const ev of events) {
    if (ev.seq === 1 && ev.type !== "job_created") throw new LogError("the first event must be job_created", 1);
    applyEvent(s, ev);
  }
  return s;
}

export function writeState(jobDir: string, state: JobState): void {
  const file = path.join(jobDir, STATE_FILE);
  const tmp = `${file}.${process.pid}.tmp`;
  fs.writeFileSync(tmp, JSON.stringify(state, null, 1) + "\n");
  try {
    fs.renameSync(tmp, file);
  } catch {
    // Windows refuses a rename over a file somebody has open; state.json is derived, so a plain write is fine.
    fs.writeFileSync(file, JSON.stringify(state, null, 1) + "\n");
    fs.rmSync(tmp, { force: true });
  }
}

/** Derives state.json from job.jsonl alone and writes it. Works on any prefix of a log. */
export function rebuildState(jobDir: string, opts: { write?: boolean } = {}): JobState {
  const { events, tornTail } = readLog(jobDir);
  const state = foldEvents(path.basename(path.resolve(jobDir)), events, tornTail);
  if (opts.write ?? true) writeState(jobDir, state);
  return state;
}

// ---------- writer ----------

export type NewEvent = EventBody;

export interface JobLogOptions {
  now?: () => Date;
  /** Called after an event is durably written. Tests use it to simulate a kill at an exact point. */
  afterAppend?: (ev: JobEvent) => void;
  /** Skip the single-writer lock (read-mostly tools such as `status` do not open a writer at all). */
  noLock?: boolean;
}

function pidAlive(pid: number): boolean {
  try {
    process.kill(pid, 0);
    return true;
  } catch (e) {
    return (e as NodeJS.ErrnoException).code === "EPERM";
  }
}

/**
 * Append-only writer. One event = one line = one write call followed by fsync. Holds the derived state in step
 * with the file by running the same reducer the reader uses, so nothing about progress lives only in memory.
 */
export class JobLog {
  readonly jobDir: string;
  readonly job: string;
  private fd: number | undefined;
  private seq: number;
  private readonly now: () => Date;
  private readonly afterAppend: ((ev: JobEvent) => void) | undefined;
  private lockHeld = false;
  private dead: Error | undefined;
  state: JobState;
  events: JobEvent[];
  /** True when a torn final line was cut off while opening. */
  repairedTornTail = false;

  private constructor(jobDir: string, job: string, read: ReadResult, opts: JobLogOptions) {
    this.jobDir = jobDir;
    this.job = job;
    this.now = opts.now ?? (() => new Date());
    this.afterAppend = opts.afterAppend;
    this.events = read.events;
    this.seq = read.events.length;
    this.state = foldEvents(job, read.events, false);
  }

  /** Opens (creating the directory and file if needed) the log of the job in `jobDir`. */
  static open(jobDir: string, opts: JobLogOptions = {}): JobLog {
    const dir = path.resolve(jobDir);
    fs.mkdirSync(dir, { recursive: true });
    const file = path.join(dir, LOG_FILE);
    const lock = path.join(dir, LOCK_FILE);
    if (!opts.noLock) {
      if (fs.existsSync(lock)) {
        const pid = Number(fs.readFileSync(lock, "utf8").trim());
        if (Number.isInteger(pid) && pid !== process.pid && pidAlive(pid)) {
          throw new LogError(`another Foreman (pid ${pid}) holds ${lock}`);
        }
      }
      fs.writeFileSync(lock, String(process.pid));
    }
    try {
      const read = readLog(dir);
      const job = read.events[0]?.job ?? path.basename(dir);
      const log = new JobLog(dir, job, read, opts);
      log.lockHeld = !opts.noLock;
      if (fs.existsSync(file)) {
        const size = fs.statSync(file).size;
        if (read.tornTail) {
          fs.truncateSync(file, read.validBytes);
          log.repairedTornTail = true;
        } else if (size > 0) {
          // A complete last event that lost only its newline.
          const buf = fs.readFileSync(file);
          if (buf[buf.length - 1] !== 0x0a) fs.appendFileSync(file, "\n");
        }
      }
      log.fd = fs.openSync(file, "a");
      writeState(dir, log.state);
      return log;
    } catch (e) {
      if (!opts.noLock) fs.rmSync(lock, { force: true });
      throw e;
    }
  }

  append<T extends NewEvent>(body: T): JobEvent {
    if (this.dead) throw this.dead;
    if (this.fd === undefined) throw new LogError("log is closed");
    const ev = validateEvent({ v: 1, seq: this.seq + 1, ts: this.now().toISOString(), job: this.job, ...body });
    // Fold first on a copy-free path: a reducer error (unknown package) must not leave a bad line in the file.
    const probe = structuredClone(this.state);
    applyEvent(probe, ev);
    const line = JSON.stringify(ev) + "\n";
    fs.writeSync(this.fd, line);
    fs.fsyncSync(this.fd);
    this.seq += 1;
    this.state = probe;
    this.events.push(ev);
    writeState(this.jobDir, this.state);
    if (this.afterAppend) {
      try {
        this.afterAppend(ev);
      } catch (e) {
        // A simulated kill: from now on this writer is a dead process.
        this.dead = e instanceof Error ? e : new Error(String(e));
        this.closeFd();
        throw this.dead;
      }
    }
    return ev;
  }

  private closeFd(): void {
    if (this.fd !== undefined) {
      fs.closeSync(this.fd);
      this.fd = undefined;
    }
  }

  close(): void {
    this.closeFd();
    if (this.lockHeld) {
      fs.rmSync(path.join(this.jobDir, LOCK_FILE), { force: true });
      this.lockHeld = false;
    }
  }
}
