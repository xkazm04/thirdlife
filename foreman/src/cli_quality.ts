// JOB.md "Added 2026-11-21": `foreman quality <job> accept|retry [--note "..."]` answers a quality hold (a milestone
// still NOT ok after its revise rounds), and the lines `foreman status` prints for it. Kept out of cli.ts (its line
// ratchet); cli.ts hands in what it owns.
import path from "node:path";
import type { Milestone } from "./events.js";
import { JobLog, type JobState } from "./joblog.js";
import { qualityAnswerText } from "./quality_state.js";
import { lockHolder } from "./requests.js";
import { UsageError, str, type Args } from "./cli_args.js";

export const QUALITY_HELP = `  quality <job> accept|retry [--note "..."] [--no-run] [same options as run]
        the owner's answer to a quality hold (foreman status names it): a milestone the critic still finds NOT ok
        after two revise rounds. accept continues as if it were ok; retry runs one more revise round (with the note,
        the builders read it), then the critic looks again. Then the job continues as resume would.`;

/** The status lines of a quality hold: which milestone, the critic's last word, and the command that answers it. */
export function qualityLines(s: JobState): string[] {
  const h = s.qualityHeld;
  if (h === undefined) return [];
  const look = [...s.milestones].reverse().find((m) => m.milestone === h.milestone);
  const said = /critic \(V5\) NOT ok: ([^\[]*)/.exec(look?.summary ?? "")?.[1]?.trim() ?? "";
  return [
    `HELD     quality: milestone ${h.milestone} is still NOT ok after revise round ${h.round}${s.jobState?.state === "paused" ? "" : " (the job pauses when its builders stop)"}`,
    ...(said !== "" ? [`critic   ${said.replace(/\s+/g, " ").slice(0, 400)}`] : []),
    `answer   foreman quality ${s.job} accept [--note "..."]   or   foreman quality ${s.job} retry --note "<what to change>"`,
  ];
}

/** `quality`: a `comment` on the held milestone (the answer), then the job continues as resume would. */
export async function qualityCommand(a: Args, out: (s: string) => void, d: { jobDirOf(a: Args): string; runJob(a: Args, out: (s: string) => void): Promise<number> }): Promise<number> {
  const jobDir = d.jobDirOf(a);
  const answer = a.pos[1];
  if (answer !== "accept" && answer !== "retry") throw new UsageError('usage: foreman quality <job> accept|retry [--note "..."]');
  const note = str(a, "note")?.trim();
  if (note !== undefined && note.length === 0) throw new UsageError("--note needs text (or leave it out)");
  const holder = lockHolder(jobDir);
  if (holder.alive) throw new UsageError(`a Foreman (pid ${holder.pid ?? "?"}) is running this job; answer the hold when the job waits for it (foreman status)`);
  const log = JobLog.open(jobDir);
  try {
    const h = log.state.qualityHeld;
    if (h === undefined) throw new UsageError("no milestone of this job waits for a quality answer (foreman status)");
    log.append({ type: "comment", milestone: h.milestone as Milestone, text: qualityAnswerText(answer, note), by: "player" });
    out(`quality ${answer} on milestone ${h.milestone}${note !== undefined ? ` (note: ${note})` : ""}`);
  } finally {
    log.close();
  }
  if (a.flags["no-run"] === true) {
    out(`continue with: foreman resume ${path.basename(jobDir)}`);
    return 0;
  }
  return d.runJob({ ...a, cmd: "resume", pos: [a.pos[0] as string] }, out);
}
