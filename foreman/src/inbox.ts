// P10: the inbox. `foreman answer` and `foreman change` on a job that another Foreman process is running do not
// touch job.jsonl (it has ONE writer): they append one line to <job>/inbox.jsonl. The running Foreman reads the file
// at its safe points and writes each entry into the log as the event it would have been (`answer`,
// `change_requested`), with the entry's id in the event's `inbox` field. That id is the only record of "taken":
// a kill between two lines of the log never loses an entry and never logs one twice.
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import type { EventBody, JobEvent } from "./events.js";
import type { JobState } from "./joblog.js";

export const INBOX_FILE = "inbox.jsonl";
export const INBOX_REJECTED_FILE = "inbox.rejected.jsonl";

export type InboxEntry =
  | { id: string; ts: string; kind: "answer"; package: string; text: string; by: string; change?: string }
  | { id: string; ts: string; kind: "change"; text: string; package?: string };

/** Every key of an entry, by kind: unknown keys are errors here as everywhere. */
const KEYS: Record<InboxEntry["kind"], { required: string[]; optional: string[] }> = {
  answer: { required: ["id", "ts", "kind", "package", "text", "by"], optional: ["change"] },
  change: { required: ["id", "ts", "kind", "text"], optional: ["package"] },
};

export function parseInboxLine(line: string): InboxEntry | string {
  let v: unknown;
  try {
    v = JSON.parse(line);
  } catch {
    return "not valid JSON";
  }
  if (v === null || typeof v !== "object" || Array.isArray(v)) return "not a JSON object";
  const o = v as Record<string, unknown>;
  const kind = o["kind"];
  if (kind !== "answer" && kind !== "change") return `unknown kind ${JSON.stringify(kind)}`;
  const spec = KEYS[kind];
  for (const k of spec.required) if (typeof o[k] !== "string" || (o[k] as string).length === 0) return `"${k}" is missing or empty`;
  for (const k of Object.keys(o)) {
    if (!spec.required.includes(k) && !spec.optional.includes(k)) return `unknown key "${k}"`;
    if (typeof o[k] !== "string" || (o[k] as string).length === 0) return `"${k}" is not a non-empty string`;
  }
  return o as unknown as InboxEntry;
}

/**
 * Appends one entry: ONE write call of one complete line to a file opened for append, then fsync. The operating
 * system places an append at the end of the file whoever else appends, so two writers never interleave inside a line.
 */
export function writeInbox(jobDir: string, entry: Omit<Extract<InboxEntry, { kind: "answer" }>, "id" | "ts"> | Omit<Extract<InboxEntry, { kind: "change" }>, "id" | "ts">, now: () => Date = () => new Date()): InboxEntry {
  const full = { id: crypto.randomUUID(), ts: now().toISOString(), ...entry } as InboxEntry;
  const problem = parseInboxLine(JSON.stringify(full));
  if (typeof problem === "string") throw new Error(`inbox entry refused: ${problem}`);
  const fd = fs.openSync(path.join(jobDir, INBOX_FILE), "a");
  try {
    fs.writeSync(fd, JSON.stringify(full) + "\n");
    fs.fsyncSync(fd);
  } finally {
    fs.closeSync(fd);
  }
  return full;
}

/** The complete lines of the inbox, oldest first. A last line without its newline is a write in progress: not read yet. */
export function readInbox(jobDir: string): { entries: InboxEntry[]; bad: { line: number; problem: string }[] } {
  const file = path.join(jobDir, INBOX_FILE);
  const entries: InboxEntry[] = [];
  const bad: { line: number; problem: string }[] = [];
  let text: string;
  try {
    text = fs.readFileSync(file, "utf8");
  } catch {
    return { entries, bad };
  }
  const end = text.lastIndexOf("\n");
  if (end < 0) return { entries, bad };
  text
    .slice(0, end)
    .split("\n")
    .forEach((raw, i) => {
      const line = raw.endsWith("\r") ? raw.slice(0, -1) : raw;
      if (line.trim() === "") return;
      const e = parseInboxLine(line);
      if (typeof e === "string") bad.push({ line: i + 1, problem: e });
      else entries.push(e);
    });
  return { entries, bad };
}

function rejectedIds(jobDir: string): Set<string> {
  const out = new Set<string>();
  try {
    for (const line of fs.readFileSync(path.join(jobDir, INBOX_REJECTED_FILE), "utf8").split("\n")) {
      if (line.trim() === "") continue;
      try {
        const id = (JSON.parse(line) as { id?: unknown }).id;
        if (typeof id === "string") out.add(id);
      } catch {
        /* a torn line names nothing */
      }
    }
  } catch {
    /* no file: nothing was refused */
  }
  return out;
}

/** Whether a change request can be recorded on this job now; the words when it cannot (the same as the CLI's). */
export function changeProblem(s: JobState, pkg: string | undefined): string | undefined {
  if (pkg !== undefined && !s.packages[pkg]) return `unknown package ${pkg} (the plan has: ${s.order.join(", ")})`;
  if (!s.order.some((id) => (s.packages[id]?.mergedFiles ?? []).length > 0)) return "this job has no merged package yet: a change request needs something finished to change";
  if (s.jobState?.state === "cancelled") return "this job is cancelled; a change request cannot re-open it";
  return undefined;
}

/** Whether an answer can be recorded now; the words when it cannot. */
export function answerProblem(s: JobState, pkg: string, change: string | undefined): string | undefined {
  const p = s.packages[pkg];
  if (!p) return `unknown package ${pkg}`;
  if (p.openQuestion === undefined) return `package ${pkg} has no open question`;
  if (change !== undefined && !s.packages[change]) return `--change: unknown package ${change} (the plan has: ${s.order.join(", ")})`;
  return undefined;
}

export interface DrainResult {
  /** Events written to the log by this call. */
  appended: JobEvent[];
  /** Entries that could not become an event, with the reason; they are listed in inbox.rejected.jsonl and never tried again. */
  rejected: { id: string; reason: string }[];
}

/**
 * Writes every inbox entry the log does not hold yet into the log, in the order of the file. Called only by the
 * process that holds the job's lock. `state` is read again before each entry, so an answer and a change in one
 * drain see each other's effect exactly as two command lines would have.
 */
export function drainInbox(jobDir: string, events: () => readonly JobEvent[], state: () => JobState, append: (body: EventBody) => JobEvent): DrainResult {
  const out: DrainResult = { appended: [], rejected: [] };
  const { entries } = readInbox(jobDir);
  if (entries.length === 0) return out;
  const answered = new Set<string>();
  const changed = new Set<string>();
  for (const e of events()) {
    if (e.type === "answer" && e.inbox !== undefined) answered.add(e.inbox);
    if (e.type === "change_requested" && e.inbox !== undefined) changed.add(e.inbox);
  }
  const refused = rejectedIds(jobDir);
  const reject = (id: string, reason: string, entry: InboxEntry): void => {
    refused.add(id);
    out.rejected.push({ id, reason });
    fs.appendFileSync(path.join(jobDir, INBOX_REJECTED_FILE), JSON.stringify({ id, reason, entry }) + "\n");
  };
  for (const e of entries) {
    if (refused.has(e.id)) continue;
    if (e.kind === "answer") {
      if (!answered.has(e.id)) {
        const problem = answerProblem(state(), e.package, e.change);
        if (problem !== undefined) {
          reject(e.id, problem, e);
          continue;
        }
        out.appended.push(append({ type: "answer", package: e.package, text: e.text, by: e.by, inbox: e.id }));
        answered.add(e.id);
      }
      // "Yes, that package may be changed": the second half of the same entry (a kill may have fallen between the two).
      if (e.change !== undefined && !changed.has(e.id)) {
        if (state().packages[e.change]) {
          out.appended.push(append({ type: "change_requested", text: e.text, package: e.change, inbox: e.id }));
          changed.add(e.id);
        }
      }
    } else if (!changed.has(e.id)) {
      const problem = changeProblem(state(), e.package);
      if (problem !== undefined) {
        reject(e.id, problem, e);
        continue;
      }
      out.appended.push(append({ type: "change_requested", text: e.text, ...(e.package !== undefined ? { package: e.package } : {}), inbox: e.id }));
      changed.add(e.id);
    }
  }
  return out;
}
