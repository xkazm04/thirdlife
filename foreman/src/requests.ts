// P10 item 4: the two commands that hand a request to a job, `foreman change` and `foreman answer`. A job has ONE
// writer of its log. When no Foreman runs the job, the command is that writer for a moment (as before P10). When one
// does, the command appends a line to <job>/inbox.jsonl and the running Foreman writes the event (inbox.ts).
import fs from "node:fs";
import path from "node:path";
import { JobLog, LogError, rebuildState } from "./joblog.js";
import { INBOX_FILE, answerProblem, changeProblem, drainInbox, writeInbox } from "./inbox.js";

/** A request that cannot be recorded (an unknown package, no open question): the CLI reports it as a usage error. */
export class RequestError extends Error {}

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

/**
 * Opens the job's log for one command that writes an event itself. When another Foreman holds the job, the answer is
 * `undefined`: the caller writes to the inbox instead. What an earlier command left in the inbox (a Foreman that
 * ended a moment before it could take it) is written into the log first, so the order of the file is the order of
 * the log.
 */
function openForRequest(jobDir: string): JobLog | undefined {
  if (lockHolder(jobDir).alive) return undefined;
  let log: JobLog;
  try {
    log = JobLog.open(jobDir);
  } catch (e) {
    // A Foreman started between the look at the lock and the open: the inbox is the door.
    if (e instanceof LogError && /another Foreman/.test(e.message)) return undefined;
    throw e;
  }
  try {
    drainInbox(jobDir, () => log.events, () => log.state, (body) => log.append(body));
  } catch (e) {
    log.close();
    throw e;
  }
  return log;
}

/**
 * Records a change request (N3 item 1). Returns "inbox" when it was handed to a running Foreman (nothing is run by
 * the caller then) and "log" when it was written into job.jsonl here (the caller continues the job as `resume` would).
 */
export function requestChange(jobDir: string, text: string, pkgId: string | undefined, out: (s: string) => void): "inbox" | "log" {
  const about = pkgId !== undefined ? ` for package ${pkgId}` : " (the Planner will be asked which package owns it)";
  const log = openForRequest(jobDir);
  if (log === undefined) {
    const problem = changeProblem(rebuildState(jobDir, { write: false }), pkgId);
    if (problem !== undefined) throw new RequestError(problem);
    const entry = writeInbox(jobDir, { kind: "change", text, ...(pkgId !== undefined ? { package: pkgId } : {}) });
    out(`change request handed to the running Foreman (pid ${lockHolder(jobDir).pid ?? "?"}) through ${INBOX_FILE} as entry ${entry.id}${about}; it is logged and acted on at that Foreman's next safe point`);
    return "inbox";
  }
  try {
    const problem = changeProblem(log.state, pkgId);
    if (problem !== undefined) throw new RequestError(problem);
    const ev = log.append({ type: "change_requested", text, ...(pkgId !== undefined ? { package: pkgId } : {}) });
    out(`change request recorded as event ${ev.seq}${about}`);
    return "log";
  } finally {
    log.close();
  }
}

/**
 * Records the answer to a builder's question. `change` turns it into a change request for that package as well
 * (N3: "yes, that package may be changed"). While another Foreman runs the job the answer goes into its inbox; it
 * logs the same `answer` event (and the `change_requested`) and starts the asking package again.
 */
export function requestAnswer(jobDir: string, pkgId: string, text: string, change: string | undefined, out: (s: string) => void): void {
  const log = openForRequest(jobDir);
  if (log === undefined) {
    const problem = answerProblem(rebuildState(jobDir, { write: false }), pkgId, change);
    if (problem !== undefined) throw new RequestError(problem);
    const entry = writeInbox(jobDir, { kind: "answer", package: pkgId, text, by: "player", ...(change !== undefined ? { change } : {}) });
    out(`answer handed to the running Foreman (pid ${lockHolder(jobDir).pid ?? "?"}) through ${INBOX_FILE} as entry ${entry.id}${change !== undefined ? `, with a change request for ${change}` : ""}; it continues without a resume`);
    return;
  }
  try {
    const problem = answerProblem(log.state, pkgId, change);
    if (problem !== undefined) throw new RequestError(problem);
    log.append({ type: "answer", package: pkgId, text, by: "player" });
    if (change !== undefined) {
      const ev = log.append({ type: "change_requested", text, package: change });
      out(`change request for ${change} recorded as event ${ev.seq}: it is re-opened with this text when the job is resumed`);
    }
    out(`answered; continue with: foreman resume ${log.job}`);
  } finally {
    log.close();
  }
}
