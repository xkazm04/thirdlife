// A disk floor that says, not stops. `tl doctor` and the start of `tl check` print the free space on the repo's drive and warn
// under a floor (default 20 GB; TL_DISK_FLOOR_GB overrides). Nothing is ever killed or stopped for it: the jam's last day had a
// watcher stop a test run at a disk floor and the script then counted what had passed as green (docs/GATE-HONESTY.md).
import fs from "node:fs";
import path from "node:path";

export const DEFAULT_FLOOR_GB = 20;

/** The floor in GB: TL_DISK_FLOOR_GB when it is a non-negative number, else the default. */
export function floorGB(env = process.env) {
  const v = Number(env.TL_DISK_FLOOR_GB);
  return env.TL_DISK_FLOOR_GB !== undefined && env.TL_DISK_FLOOR_GB !== "" && Number.isFinite(v) && v >= 0 ? v : DEFAULT_FLOOR_GB;
}

/** -> {free_gb, floor_gb, low, drive, line} or {error, line} when the free space cannot be read. statfs is injectable. */
export function diskReport(dir, { env = process.env, statfs = fs.statfsSync } = {}) {
  const floor = floorGB(env);
  const drive = path.parse(path.resolve(dir)).root || "/";
  let s;
  try { s = statfs(dir); } catch (e) { return { error: String(e?.message ?? e), floor_gb: floor, line: `disk: free space on ${drive} could not be read (${String(e?.message ?? e).split("\n")[0]})` }; }
  const free = Math.round((Number(s.bavail) * Number(s.bsize)) / 1e8) / 10;
  const low = free < floor;
  return { free_gb: free, floor_gb: floor, low, drive,
    line: low ? `disk: WARN ${free} GB free on ${drive}, under the floor of ${floor} GB (TL_DISK_FLOOR_GB): nothing is stopped for it; free space before a long run`
              : `disk: ${free} GB free on ${drive} (floor ${floor} GB)` };
}
