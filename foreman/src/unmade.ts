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
  // D27 (J2nd finding 11): the workspaces still held the unmade change's edits, and the next change merged them back
  // without a word: every workspace is cut again from the restored pack/ at its next round
  for (const id of h.s.order) {
    fs.rmSync(h.dir("ws", id), { recursive: true, force: true, maxRetries: 5, retryDelay: 100 });
    fs.rmSync(h.dir("ws", `${id}.baseline.json`), { force: true });
  }
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
