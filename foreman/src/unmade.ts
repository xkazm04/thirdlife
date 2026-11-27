// "Change not made" (JOB.md, "Added 2026-11-17"; the P10 decision): a change request that ends without a promotion
// puts pack/ back to the last promoted pack before the job's state event. The unpromoted files stay only in the
// reports. Kept out of foreman.ts, which has a line ratchet; the Foreman calls these at each such ending.
import fs from "node:fs";
import path from "node:path";
import { foldEvents } from "./joblog.js";
import { MANIFEST_FILE } from "./manifest.js";
import type { GateHost } from "./p10gate.js";
import { toPosix } from "./paths.js";
import { copyDir, hashFile, listFiles } from "./scope.js";
import type { JobEvent } from "./events.js";
import { FOREMAN_NOTE, clip } from "./conduct.js";
import { NOT_MADE } from "./halfmade.js";

/** What of the Foreman these need: its gate host (p10gate.ts), state and log read live. */
export type UnmadeHost = Pick<GateHost, "o" | "s" | "events" | "dir" | "append">;

/** Where the `dest` of a `promoted` event is: promoted/... under the job, packs/... under the engine (--promote-to engine). */
export function promotedDir(h: UnmadeHost, dest: string): string {
  return dest.startsWith("packs/") ? path.join(h.o.verifier.location.engineDir, ...dest.split("/")) : h.dir(...dest.split("/"));
}

/** True when pack/ holds exactly the files of the last promotion, byte for byte (nothing to verify or promote). */
export function packIsLastPromotion(h: UnmadeHost): boolean {
  const p = h.s.promoted;
  if (!p) return false;
  const a = h.dir("pack");
  const b = promotedDir(h, p.dest);
  if (!fs.existsSync(a) || !fs.existsSync(b)) return false;
  const fa = listFiles(a).sort();
  const fb = listFiles(b).sort();
  return JSON.stringify(fa) === JSON.stringify(fb) && fa.every((f) => hashFile(path.join(a, f)) === hashFile(path.join(b, f)));
}

/**
 * Puts pack/ back to the last promotion when files were merged after it (a change that is ending unmade). The
 * unpromoted pack/ is kept in reports/change-not-made-s<seq>/pack/; `merge` events bring each package's merged-file
 * list back to what it was at that promotion, so the log and pack/ agree again (a resume checks that every merged
 * file is in pack/). Returns the sentence for the job's reason; "" when there was nothing to put back.
 */
export function restoreLastPromotion(h: UnmadeHost): string {
  const p = h.s.promoted;
  // D27b item 41: a change that was not made leaves no trace in any workspace either (they are cut again from pack/)
  if (p !== undefined) dropWorkspaces(h, h.s.order);
  if (!p || !h.s.mergedSincePromotion || packIsLastPromotion(h)) return "";
  const src = promotedDir(h, p.dest);
  if (!fs.existsSync(path.join(src, MANIFEST_FILE))) return ` pack/ could NOT be put back: the last promoted pack ${p.dest} is missing, so pack/ still holds the unpromoted files.`;
  const packDir = h.dir("pack");
  const keepRel = `reports/change-not-made-s${h.s.lastSeq + 1}/pack`;
  const keep = h.dir(...keepRel.split("/"));
  fs.rmSync(keep, { recursive: true, force: true });
  if (fs.existsSync(packDir)) copyDir(packDir, keep);
  const tmp = h.dir(`.pack-restore-${process.pid}`);
  fs.rmSync(tmp, { recursive: true, force: true });
  copyDir(src, tmp);
  fs.rmSync(packDir, { recursive: true, force: true, maxRetries: 5, retryDelay: 100 });
  fs.renameSync(tmp, packDir);
  // The merged files of every package as they were when that promotion was written.
  let at = -1;
  for (let i = h.events.length - 1; i >= 0; i--) {
    if (h.events[i]?.type === "promoted") {
      at = i;
      break;
    }
  }
  const then = foldEvents(h.s.job, h.events.slice(0, at + 1));
  for (const id of h.s.order) {
    const now = h.s.packages[id]?.mergedFiles ?? [];
    const was = then.packages[id]?.mergedFiles ?? [];
    const removed = now.filter((f) => !was.includes(f));
    const files = was.filter((f) => !now.includes(f));
    if (removed.length > 0 || files.length > 0) h.append({ type: "merge", package: id, files, ...(removed.length > 0 ? { removed } : {}) });
  }
  return ` pack/ was put back to the last promotion ${p.packId} ${p.version} (${toPosix(p.dest)}); the unpromoted files of the change are kept only in ${keepRel}/.`;
}

/**
 * D27b item 41 (J2nd's court copy j2nd3, events 1858-1925: after "The change was NOT made" only pack/ was put back; the
 * workspaces kept the failed "make it fairer" tuning, and the next change's crews_stakes round, which wrote "No game
 * script or data changed this round", merged data/crews.json with the failed values). A workspace that holds a round
 * that was not made is removed with its baseline; the package's next round cuts it again from pack/. Returns the ids
 * whose workspace was there.
 */
export function dropWorkspaces(h: Pick<GateHost, "dir">, ids: readonly string[]): string[] {
  const out: string[] = [];
  for (const id of ids) {
    const ws = h.dir("ws", id);
    if (fs.existsSync(ws)) out.push(id);
    fs.rmSync(ws, { recursive: true, force: true, maxRetries: 5, retryDelay: 100 });
    for (const f of ["baseline", "carried", "members"]) fs.rmSync(h.dir("ws", `${id}.${f}.json`), { force: true });
  }
  return out;
}

/** A job's reason when a change ended without a promotion (endJob, the final verification's last send-back). */
export const UNMADE_END = /\bThe change was NOT made\b|^the change was NOT made\b/;

/** The seq of the last "change NOT made" ending among `events` (-1 when none). */
export function lastUnmadeEnd(events: readonly JobEvent[]): number {
  return events.reduce((n, e) => (e.type === "job_state" && e.reason !== undefined && UNMADE_END.test(e.reason) ? e.seq : n), -1);
}

/**
 * D27b item 42 (J2nd's court copy j2nd3, v0.1.9, event 2063: the C: ALLEY-OOP cue was made only in a change that ended
 * "NOT made" (event 2046); the next change's builder wrote "The C: ALLEY-OOP cue, your mate's glow and the steal hint are
 * unchanged", true of v0.1.8, read by a person as "it is in the game"). At a promotion, every change since the last
 * promotion that ended NOT made is told as not in this version, in the person's words, with why.
 */
export function earlierUnmade(events: readonly JobEvent[], pkg: string, round: number): { type: "note"; package: string; round: number; text: string }[] {
  const last = events.reduce((n, e) => (e.type === "promoted" ? e.seq : n), -1);
  const out: { type: "note"; package: string; round: number; text: string }[] = [];
  let from = last;
  for (const end of events) {
    if (end.seq <= last || end.type !== "job_state" || end.reason === undefined || !UNMADE_END.test(end.reason)) continue;
    const asks = events.filter((e) => e.type === "change_requested" && e.seq > from && e.seq < end.seq && !e.text.startsWith(FOREMAN_NOTE)).map((e) => (e.type === "change_requested" ? `"${clip(e.text, 300)}"` : ""));
    const why = clip(end.reason.split(/ ?The change was NOT made/)[0]?.replace(/^the change was NOT made: /, "") ?? "", 240);
    if (asks.length > 0) out.push({ type: "note", package: pkg, round, text: `${FOREMAN_NOTE}${NOT_MADE}: your earlier change ${asks.join(" / ")} ended NOT made (${why}); nothing of it is in this version unless this change made it again` });
    from = end.seq;
  }
  return out;
}
