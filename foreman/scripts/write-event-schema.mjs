// Writes data/job-events.schema.json from the schemas the reader enforces (src/events.ts).
// Run after `npm run build` whenever an event changes: node scripts/write-event-schema.mjs
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { eventSchemas } from "../dist/events.js";

const file = path.join(path.dirname(fileURLToPath(import.meta.url)), "..", "data", "job-events.schema.json");
const doc = {
  schema: "tl.job/1",
  note: "Generated from foreman/src/events.ts by scripts/write-event-schema.mjs. One JSON schema per event type; a line of job.jsonl must match the schema of its `type`. Rules a schema cannot say (seq = line number, one job id per file, cause only with failed or blocked, plan graph checks, the phases as a partition of the packages, the word limits of a pitch and its aspects, a hold with its note, a reaction to an aspect of the latest brief) are in src/events.ts, src/v2.ts and src/joblog.ts.",
  events: eventSchemas(),
};
fs.writeFileSync(file, JSON.stringify(doc, null, 1) + "\n");
console.log(`written ${file}`);
