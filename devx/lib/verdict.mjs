// The tl.devx/1 protocol in one place. Every `tl` exit path ends in one JSON line on stdout:
//   {"schema":"tl.devx/1","cmd":...,"ok":exit===0,"exit":0|1|2, ...}
// exit 0 pass, 1 fail, 2 could not run (docs/GATE-HONESTY.md). A reader that finds no such last line treats the run as killed.
// Step status: pass | fail | not_run (a step with not_run: true never passes). Absent value = the key is omitted.
export const SCHEMA = "tl.devx/1";

export const statusOf = (s) => (s.not_run ? "not_run" : s.ok ? "pass" : "fail");
const LABEL = { pass: "PASS", fail: "FAIL", not_run: "NOT RUN" };

/** One human line per step: `PASS|FAIL|NOT RUN  id  ms  [completed/found] detail`. */
export function stepLine(s) {
  const counts = s.found !== undefined ? `[${s.completed ?? "?"}/${s.found}] ` : "";
  return `${LABEL[statusOf(s)]}  ${s.id.padEnd(28)} ${String(s.ms).padStart(7)} ms  ${counts}${s.detail ?? ""}`.trimEnd();
}

/** 1 when any step failed; else 2 when any could not run; else 0. No steps at all is a fail: nothing was checked. */
export function exitOf(steps) {
  if (!steps.length) return 1;
  if (steps.some((s) => statusOf(s) === "fail")) return 1;
  return steps.some((s) => statusOf(s) === "not_run") ? 2 : 0;
}

/** Prints the JSON line and returns its exit. */
export function emit(cmd, exit, fields = {}) {
  console.log(JSON.stringify({ schema: SCHEMA, cmd, ok: exit === 0, exit, ...fields }));
  return exit;
}

/** Step lines, then the JSON line. extra.exit, when given, is the caller's own tri-state (the gate engine's) and wins. */
export function verdict(cmd, steps, extra = {}) {
  for (const s of steps) console.log(stepLine(s));
  const { exit: given, ...rest } = extra;
  const exit = given ?? exitOf(steps);
  const notRun = steps.filter((s) => statusOf(s) === "not_run").map((s) => s.id);
  return emit(cmd, exit, { steps, ...(notRun.length ? { not_run: notRun } : {}), ...rest });
}

/** A bad invocation: the text goes to stderr for a person, the line says it; exit 2 (nothing was run). */
export function usage(cmd, text, fields = {}) { console.error(text); return emit(cmd, 2, { error: text, ...fields }); }
/** Something the command needs is missing (no Godot, no pack, no site directory): exit 2. */
export const couldNotRun = usage;
/** The command ran and the answer is no: exit 1. */
export function fail(cmd, text, fields = {}) { console.error(text); return emit(cmd, 1, { error: text, ...fields }); }
/** The command ran and did what it was asked: exit 0. */
export const done = (cmd, fields = {}) => emit(cmd, 0, fields);

/** Parses a line; the tl.devx/1 object or null. */
export function parseLine(line) {
  try { const o = JSON.parse(line); return o && o.schema === SCHEMA ? o : null; } catch { return null; }
}
