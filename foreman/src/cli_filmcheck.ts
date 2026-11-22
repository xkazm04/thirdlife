// D3 of 22 Nov: `foreman filmcheck <job>`: the film cross-check (filmcheck.ts) over a job's existing looks, read-only.
// Every critique report's strips are measured against the claims of the bots that played them, as the log stood when
// that look was judged; the house baseline's strips against the house bot's own report. Nothing is written.
// `foreman filmcheck --strip FILE --label TEXT --report FILE` measures one strip against one bot report (a house ladder
// run made outside a job). Exit 0: no claim contradicted; 1: a contradiction; 2: nothing could be measured.
import fs from "node:fs";
import path from "node:path";
import { readLog } from "./joblog.js";
import { botClaims, claimsOfResult, crossCheckFilm, type BotClaims, type FilmCheck } from "./filmcheck.js";
import { UsageError, str, type Args } from "./cli_args.js";

export const FILMCHECK_HELP = `  filmcheck <job> [--json]           read-only: each look's strips measured (frame differences between tiles) against
        the claims of the bot that played them (metrics.idle_max_f, moments); exit 1 when the film contradicts a claim
  filmcheck --strip FILE --label TEXT --report FILE [--json]   one strip against one bot report`;

interface Checked { report: string; check: FilmCheck; refilmed: string[] }

const readJson = (file: string): unknown => JSON.parse(fs.readFileSync(file, "utf8"));
const seqOf = (file: string): number => Number(/-s(\d+)\.json$/.exec(file)?.[1] ?? Infinity);

/** The house bot's claims: the newest drill report of the pack (the run its strip was filmed from), else the baseline's own. */
function houseClaims(jobDir: string, pack: string, from: string | undefined): BotClaims {
  const reports = fs.readdirSync(path.join(jobDir, "reports")).filter((f) => new RegExp(`^house-${pack}-drill-s\\d+\\.json$`).test(f)).sort((a, b) => seqOf(b) - seqOf(a));
  for (const f of [...reports.map((x) => `reports/${x}`), ...(from !== undefined ? [from] : [])]) {
    try {
      return claimsOfResult((readJson(path.join(jobDir, f)) as { bot?: { result?: { metrics?: unknown; moments?: unknown } } }).bot?.result);
    } catch {
      /* the next one */
    }
  }
  return {};
}

export function filmcheckJob(jobDir: string): Checked[] {
  const { events } = readLog(jobDir);
  const dir = path.join(jobDir, "reports");
  const out: Checked[] = [];
  const critiques = fs.readdirSync(dir).filter((f) => /^critic-.*-s\d+\.json$/.test(f) && !f.startsWith("critic_compare")).sort((a, b) => seqOf(a) - seqOf(b));
  for (const f of critiques) {
    const r = readJson(path.join(dir, f)) as { strips?: { capture: string; label: string }[] };
    const strips = r.strips ?? [];
    if (strips.length === 0) continue;
    const seq = seqOf(f);
    const when = fs.statSync(path.join(dir, f)).mtimeMs;
    // A later look at the same frame overwrites the capture: say so (the image is then the later build's).
    const refilmed = strips.filter((s) => { try { return fs.statSync(path.join(jobDir, s.capture)).mtimeMs > when + 60_000; } catch { return false; } }).map((s) => s.capture);
    out.push({ report: `reports/${f}`, check: crossCheckFilm(strips, (bot) => botClaims(jobDir, events, bot, seq), (c) => path.join(jobDir, c)), refilmed });
  }
  for (const f of fs.readdirSync(dir).filter((x) => /^house-[a-z_]+\.json$/.test(x))) {
    const b = readJson(path.join(dir, f)) as { pack?: string; from?: string; strips?: { capture: string; label: string }[] };
    if (!b.strips?.length || b.pack === undefined) continue;
    const claims = houseClaims(jobDir, b.pack, b.from);
    out.push({ report: `reports/${f}`, check: crossCheckFilm(b.strips, () => claims, (c) => path.join(jobDir, c)), refilmed: [] });
  }
  return out;
}

export function filmcheckCommand(a: Args, out: (s: string) => void, jobDirOf: (a: Args) => string): number {
  const strip = str(a, "strip");
  let checked: Checked[];
  if (strip !== undefined) {
    const label = str(a, "label"), report = str(a, "report");
    if (label === undefined || report === undefined) throw new UsageError("filmcheck --strip FILE needs --label TEXT (its tiles: \"frames A, B, ... Z\" and \"while tests/<bot>.gd\") and --report FILE (the bot's verify report)");
    const claims = claimsOfResult((readJson(path.resolve(report)) as { bot?: { result?: { metrics?: unknown; moments?: unknown } } }).bot?.result);
    checked = [{ report: path.basename(report), check: crossCheckFilm([{ capture: path.resolve(strip), label }], () => claims, (c) => c), refilmed: [] }];
  } else checked = filmcheckJob(jobDirOf(a));
  const measured = checked.reduce((n, c) => n + c.check.measured, 0);
  const findings = checked.reduce((n, c) => n + c.check.findings.length, 0);
  if (a.flags["json"] === true) out(JSON.stringify(checked.map((c) => ({ report: c.report, refilmed: c.refilmed, ...c.check })), null, 1));
  else {
    for (const c of checked) {
      out(`${c.report}: ${c.check.line}`);
      for (const s of c.check.strips) out(`  ${path.basename(s.capture)}${s.bot ? ` (${s.bot}${s.house ? ", house" : ""})` : ""}: ${s.moved}${s.still_f !== undefined ? `, longest still run >= ${s.still_f} f` : ""}${s.contact !== undefined ? `, contact strip at frame ${s.contact}` : ""}${c.refilmed.includes(s.capture) ? " [refilmed after this report]" : ""}`);
      for (const u of c.check.unmeasured) out(`  unmeasured: ${u}`);
    }
    out(`filmcheck: ${checked.length} look(s), ${measured} strip(s) measured, ${findings} claim(s) contradicted`);
  }
  return measured === 0 ? 2 : findings > 0 ? 1 : 0;
}
