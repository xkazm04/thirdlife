// What a step's underlying run found and what it completed (docs/GATE-HONESTY.md). A step that has a count reports
//   {found, completed}; the engine fails it on found == 0 or completed != found, whatever `ok` it claims.
// A run cut short (our timeout, anyone's kill, a missing summary line) is never a pass.

/** The child's end as words, or "" when it simply exited. r = ctx.run result. */
export function cutShort(r, timeoutMs) {
  if (r.timedOut) return `timed out after ${Math.round((timeoutMs ?? 0) / 1000)} s and was killed`;
  if (r.signal) return `killed by ${r.signal}`;
  return "";
}

/** node --test (spec or tap reporter) summary -> {summary, found, completed, pass, fail, cancelled, skipped, todo}.
 *  found = tests the runner reported; completed = those that reached a verdict (pass, fail, skipped, todo; NOT cancelled).
 *  summary:false means the run never printed its totals: it was stopped before the end. */
export function nodeTestCounts(stdout) {
  const num = (k) => { const m = String(stdout).match(new RegExp(`^(?:#|ℹ) ${k} (\\d+)\\s*$`, "m")); return m ? Number(m[1]) : null; };
  const c = { tests: num("tests"), pass: num("pass"), fail: num("fail"), cancelled: num("cancelled"), skipped: num("skipped"), todo: num("todo") };
  if (c.tests === null || c.pass === null || c.fail === null) return { summary: false, found: 0, completed: 0, pass: 0, fail: 0, cancelled: 0, skipped: 0, todo: 0 };
  const z = (v) => v ?? 0;
  return { summary: true, found: c.tests, completed: c.pass + c.fail + z(c.skipped) + z(c.todo), pass: c.pass, fail: c.fail,
    cancelled: z(c.cancelled), skipped: z(c.skipped), todo: z(c.todo) };
}

/** The names (and places) of the failing tests in node --test output: the spec reporter's "failing tests:" block, else every
 *  ✖ / "not ok" line. -> ["name (dist/test/x.test.js:12:3)", ...], de-duplicated, parents of a failing subtest left out. */
export function failingTests(stdout) {
  const lines = String(stdout).split(/\r?\n/);
  const start = lines.findIndex((l) => /^✖ failing tests:/.test(l.trim()));
  const pool = start >= 0 ? lines.slice(start + 1) : lines;
  const out = [];
  for (let i = 0; i < pool.length; i++) {
    const l = pool[i].trim();
    const m = l.match(/^(?:✖|not ok \d+ -) (.+?)(?:\s*\(\d[\d.]*ms\))?(?:\s*#.*)?$/);
    if (!m || /^failing tests:/.test(m[1])) continue;
    const at = (pool[i - 1] ?? "").trim().match(/^test at (.+)$/) ?? (pool[i + 1] ?? "").trim().match(/^(?:test at |location: ')(.+?)'?$/);
    out.push(at ? `${m[1]} (${at[1]})` : m[1]);
  }
  return [...new Set(out)];
}

/** A shell selftest (selftest.sh, seeds.sh, k.sh, item.sh, ui.sh) prints one "PASS <case>" / "FAIL <case>: why" line per case
 *  and, as its very last act, a trailer "<label> N passed, M failed". -> {trailer, found, completed, passed, failed}.
 *  found = N + M from the trailer (what the script itself ran); completed = the case lines we saw. No trailer: the script was
 *  stopped before its end, so found is what we saw plus one unknown (completed < found always fails). */
export function scriptCounts(stdout, trailerRe) {
  const s = String(stdout);
  const passed = (s.match(/^PASS /gm) ?? []).length, failed = (s.match(/^FAIL /gm) ?? []).length;
  const m = s.match(trailerRe);
  if (!m) return { trailer: false, found: passed + failed + 1, completed: passed + failed, passed, failed };
  return { trailer: true, found: Number(m[1]) + Number(m[2]), completed: passed + failed, passed, failed };
}

/** The engine's rule over a step's claim. -> null (the claim stands) or the reason it is a FAIL. */
export function countProblem(r) {
  const has = (k) => r[k] !== undefined;
  if (!has("found") && !has("completed")) return null;
  if (!Number.isInteger(r.found) || !Number.isInteger(r.completed) || r.found < 0 || r.completed < 0) return `counts must be whole numbers (found ${r.found}, completed ${r.completed})`;
  if (r.found === 0) return "found 0 units: nothing was checked";
  if (r.completed !== r.found) return `completed ${r.completed} of ${r.found} units found`;
  return null;
}
