// "Quiet" is measured, never assumed. A machine is quiet for a perf run when, in a window just before the run and a
// window just after it (nothing of ours running in either), the whole machine's processor use is below QUIET_UTIL and a
// fixed single-thread probe gets at least PROBE_MIN of a processor. Both figures go into the ledger line (`load`).
import os from "node:os";

export const QUIET_UTIL = 0.25;     // share of all logical processors in use by anybody
export const PROBE_MIN = 0.90;      // share of a processor that one busy thread is given

function cpuTimes() {
  let idle = 0, total = 0;
  for (const c of os.cpus()) { for (const v of Object.values(c.times)) total += v; idle += c.times.idle; }
  return { idle, total };
}

/** Samples the machine for `ms`: {util, probe}. The probe spins one thread and compares its processor time to wall time. */
export async function sample(ms = 1500) {
  const a = cpuTimes();
  const c0 = process.cpuUsage(), t0 = process.hrtime.bigint();
  const end = Date.now() + ms;
  let x = 0;
  while (Date.now() < end) { for (let i = 0; i < 20000; i++) x += i % 7; }
  const c1 = process.cpuUsage(c0), t1 = process.hrtime.bigint();
  const b = cpuTimes();
  const wallUs = Number(t1 - t0) / 1000;
  const dTotal = b.total - a.total, dIdle = b.idle - a.idle;
  const util = dTotal > 0 ? 1 - dIdle / dTotal : 0;
  // `x` is read so the loop is not discarded; it is never negative
  return { util: Math.round(util * 1000) / 1000, probe: Math.round(((c1.user + c1.system) / wallUs) * 1000) / 1000, ok: x >= 0 };
}

/** -> {quiet, util, probe}: the worst of the windows given. */
export function judge(samples, { maxUtil = QUIET_UTIL, minProbe = PROBE_MIN } = {}) {
  const util = Math.max(...samples.map((s) => s.util));
  const probe = Math.min(...samples.map((s) => s.probe));
  return { quiet: util <= maxUtil && probe >= minProbe, util: Math.round(util * 1000) / 1000, probe: Math.round(probe * 1000) / 1000 };
}
