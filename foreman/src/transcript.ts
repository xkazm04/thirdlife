// The job-level generate calls (Designer, Planner, critic, the owner question) as transcripts and `builder_run`
// events: reports/<role>-a<attempt>-s<seq>.json, then one builder_run per call (no package, no round). One
// implementation for the Foreman (foreman.ts) and the CLI (new, plan, redesign); they were two identical copies.
import fs from "node:fs";
import path from "node:path";
import type { AdapterName, EventBody, JobEvent } from "./events.js";
import type { GenerateCall } from "./designer.js";
import { toPosix } from "./paths.js";

/** Where the calls go: the job directory, the adapter's name, the log's last seq now, and the append that writes an event. */
export interface TranscriptSink {
  jobDir: string;
  adapter: AdapterName;
  lastSeq(): number;
  append(body: EventBody): JobEvent;
}

export function writeGenerateCalls(sink: TranscriptSink, calls: GenerateCall[], model: string | undefined): void {
  for (const c of calls) {
    const file = path.join(sink.jobDir, "reports", `${c.role}-a${c.attempt}-s${sink.lastSeq() + 1}.json`);
    fs.mkdirSync(path.dirname(file), { recursive: true });
    fs.writeFileSync(
      file,
      JSON.stringify(
        {
          schema: "tl.foreman.transcript/1",
          adapter: sink.adapter,
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
    sink.append({
      type: "builder_run",
      adapter: sink.adapter,
      mode: "generate",
      model: c.result.model ?? model ?? "default",
      outcome: c.result.outcome,
      durationMs: Math.max(0, Math.round(c.result.durationMs)),
      ...(c.result.tokensIn !== undefined ? { tokensIn: c.result.tokensIn } : {}),
      ...(c.result.tokensOut !== undefined ? { tokensOut: c.result.tokensOut } : {}),
      ...(c.result.tokensCacheRead !== undefined ? { tokensCacheRead: c.result.tokensCacheRead } : {}),
      transcript: toPosix(path.relative(sink.jobDir, file)),
    });
  }
}
