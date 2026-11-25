// L2b of 21 Nov: `foreman critique <job> <milestone> --out DIR`: the milestone's captures and the V5 critic once more,
// on pack/ as it is, as a dry run: nothing is written to the job (no event, no file under the job directory). The
// captures, the runner's reports and critique.json go to --out. One critic call; the builder is not run.
// It proves a capture rule on a finished job without a rebuild (the crazy proof job's tuned milestone).
import fs from "node:fs";
import path from "node:path";
import type { Builder } from "./builder/types.js";
import type { Verifier } from "./verifier.js";
import type { Milestone } from "./events.js";
import { MILESTONES } from "./events.js";
import { foldEvents, readLog } from "./joblog.js";
import { readManifest } from "./promoter.js";
import { critic } from "./designer.js";
import { criticRubric, packageLinesOf } from "./phases.js";
import { STRIP, botFinish, planShots, shotFile, shotLabel, stripFile, stripFrom, stripLabel } from "./shots.js";
import { feelItems, hudArgs, hudLabel, hudOn, stripsOn } from "./quality.js";
import { verbsFor } from "./verbs.js";
import { UsageError, str, type Args } from "./cli_args.js";
import { toPosix } from "./paths.js";

export const CRITIQUE_HELP = `  critique <job> <milestone> --out DIR [--adapter A] [--model M] [--capture-res WxH] [--engine-dir DIR] [--no-strips]
        dry run: the milestone's captures (the first test, plus the newest package's own acceptance bot) and one V5
        critic call on pack/ as it is now; writes only into DIR (captures, reports, critique.json), never the job`;

export async function critiqueCommand(a: Args, out: (s: string) => void, d: { jobDir: string; builder: Builder; verifier: Verifier }): Promise<number> {
  const m = a.pos[1] as Milestone | undefined;
  if (m === undefined || !(MILESTONES as readonly string[]).includes(m)) throw new UsageError(`usage: foreman critique <job> <milestone> --out DIR   (milestone: ${MILESTONES.join(", ")})`);
  const outDir = str(a, "out");
  if (outDir === undefined) throw new UsageError("critique writes only into --out DIR (a directory outside the job)");
  const dest = path.resolve(outDir);
  if (dest === d.jobDir || dest.startsWith(d.jobDir + path.sep)) throw new UsageError("--out must be outside the job directory: a critique writes nothing into the job");
  const { events } = readLog(d.jobDir);
  const s = foldEvents(path.basename(d.jobDir), events);
  const members = s.plan.filter((p) => p.milestone === m).map((p) => p.id);
  if (members.length === 0) throw new UsageError(`the plan has no package of milestone ${m}`);
  const packDir = path.join(d.jobDir, "pack");
  const mf = readManifest(packDir);
  const shots = planShots(s.plan, events, members, mf.tests, (b) => botFinish(d.jobDir, events, b));
  fs.mkdirSync(dest, { recursive: true });
  const captures: string[] = [];
  const labels: string[] = [];
  // JOB.md 2026-11-21: one motion strip per filmed point when the engine's runner can film one (--no-strips: stills only).
  const strips: { capture: string; label: string }[] = [];
  const withStrips = a.flags["no-strips"] !== true && stripsOn(verbsFor(d.verifier.location));
  const hud = hudOn(verbsFor(d.verifier.location)); // H1: judged as a person sees it, HUD on
  for (const [si, shot] of shots.entries()) {
    out(`shot ${si + 1}: ${shot.bot ?? "no bot"}${shot.package ? ` (package ${shot.package})` : ""}, finish ${shot.finish ?? "unknown"}, frames ${shot.frames.join(", ")}`);
    for (const cam of mf.cameras) {
      for (const frame of shot.frames) {
        const file = path.join(dest, shotFile(m, cam, frame, shot, si));
        const vr = await d.verifier.run({
          verb: "capture",
          args: [`--cam=${cam}`, `--frame=${frame}`, `--out=${toPosix(file)}`, `--res=${str(a, "capture-res") ?? "1280x720"}`, ...(shot.bot !== undefined ? [`--test=${shot.bot}`] : []), ...hudArgs(hud)],
          packDir,
          reportFile: path.join(dest, `${path.basename(file, ".png")}.json`),
        });
        const ok = vr.ok && fs.existsSync(file);
        out(`  capture ${path.basename(file)} ${ok ? "ok" : `FAILED: ${vr.summary}`}`);
        if (ok) {
          captures.push(file);
          labels.push(hudLabel(shotLabel(cam, frame, shot), hud));
        }
        if (!withStrips) continue;
        const from = stripFrom(frame);
        const sf = path.join(dest, stripFile(m, cam, shot, from));
        const sr = await d.verifier.run({
          verb: "capture",
          args: [`--cam=${cam}`, `--frame=${from}`, `--strip=${STRIP.count}x${STRIP.step}`, `--out=${toPosix(sf)}`, `--res=${str(a, "capture-res") ?? "1280x720"}`, ...(shot.bot !== undefined ? [`--test=${shot.bot}`] : []), ...hudArgs(hud)],
          packDir,
          reportFile: path.join(dest, `${path.basename(sf, ".png")}.json`),
        });
        const sok = sr.ok && fs.existsSync(sf);
        out(`  strip ${path.basename(sf)} ${sok ? "ok" : `FAILED: ${sr.summary}`}`);
        if (sok) strips.push({ capture: sf, label: hudLabel(stripLabel(cam, from, shot), hud) });
      }
    }
  }
  const last = [...members].sort((x, y) => (events.filter((e) => e.type === "merge" && e.package === y).at(-1)?.seq ?? 0) - (events.filter((e) => e.type === "merge" && e.package === x).at(-1)?.seq ?? 0))[0] as string;
  const rubric = [...criticRubric(s, last), ...(strips.length > 0 ? feelItems() : [])];
  const model = str(a, "model");
  const res = await critic(d.builder, [...captures, ...strips.map((x) => x.capture)], rubric, {
    ...(model ? { model } : {}),
    context: [`Game: ${s.title ?? ""} (${s.sentence ?? ""})`, `Mood asked for: ${s.brief?.mood ?? "(none)"}`, `Bots playing while the frames were taken: ${shots.map((x) => (x.bot ? `${x.bot}${x.package ? ` (package ${x.package})` : ""}` : "none")).join("; ")}. Each capture above names its bot and frame.`].join("\n"),
    packages: packageLinesOf(s, s.plan.map((p) => p.id)),
    labels: [...labels, ...strips.map((x) => x.label)],
  });
  const verdict = {
    schema: "tl.foreman.critique/1",
    dry: true,
    job: s.job,
    milestone: m,
    captures: captures.map((c) => path.basename(c)),
    shots: captures.map((c, i) => ({ capture: path.basename(c), label: labels[i] ?? "" })),
    strips: strips.map((x) => ({ capture: path.basename(x.capture), label: x.label })),
    rubric,
    ...(res.ok ? { ok: res.value.ok, scores: res.value.scores, notes: res.value.notes, ...(res.value.package !== undefined ? { package: res.value.package } : {}) } : { error: res.reason }),
    calls: res.calls.map((c) => ({ attempt: c.attempt, outcome: c.result.outcome, tokensIn: c.result.tokensIn, tokensOut: c.result.tokensOut, durationMs: c.result.durationMs, problems: c.problems })),
  };
  fs.writeFileSync(path.join(dest, "critique.json"), JSON.stringify(verdict, null, 1) + "\n");
  out(res.ok ? `critic (V5) ${res.value.ok ? "ok" : "NOT ok"}: ${Object.entries(res.value.scores).map(([k, v]) => `${k} ${v}`).join(", ")}` : `critic gave no usable answer: ${res.reason}`);
  for (const n of res.ok ? res.value.notes : []) out(`  note: ${n}`);
  out(`written: ${toPosix(path.join(dest, "critique.json"))}`);
  return res.ok ? 0 : 1;
}
