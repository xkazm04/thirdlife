// H1g of 25 Nov (create.pause.path, 2 of 6 runs: "EPERM, Permission denied: ...foreman.lock" in JobLog.close): on Windows
// a reader that opened the lock without delete sharing (the Create page reads its pid every poll) makes the delete fail
// for a moment. JobLog.close deletes the lock with this.
import fs from "node:fs";

/**
 * H1g: delete a file, waiting up to 3 s while another process holds it open without delete sharing (Windows: EPERM or
 * EBUSY; fs.rmSync's own retries do not cover a plain file). Synchronous, as JobLog.close is.
 */
export function removeWaiting(file: string, waitMs = 3000): void {
  const pause = new Int32Array(new SharedArrayBuffer(4));
  for (let waited = 0; ; waited += 25) {
    try {
      fs.rmSync(file, { force: true });
      return;
    } catch (e) {
      const code = (e as NodeJS.ErrnoException).code;
      if ((code !== "EPERM" && code !== "EBUSY") || waited >= waitMs) throw e;
      Atomics.wait(pause, 0, 0, 25);
    }
  }
}
