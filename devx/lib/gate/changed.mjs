// `--changed`: map changed paths to steps. `git` is injectable: (argsArray) -> stdout string.
import { matchAny } from "./glob.mjs";

export function changedPaths(git, base = "HEAD") {
  const lines = (s) => String(s).split(/\r?\n/).map((l) => l.trim()).filter(Boolean);
  const tracked = lines(git(["diff", "--name-only", base]));
  const untracked = lines(git(["ls-files", "--others", "--exclude-standard"]));
  return [...new Set([...tracked, ...untracked])].sort();
}

/** allSteps: every discovered step (the "matched by no step" test is against all of them, not just the tier's).
 *  -> {ids:Set of step ids to run, unmatched:[paths], all:boolean}. A path no step claims makes the run "all". */
export function mapChanged(paths, allSteps) {
  const ids = new Set(), unmatched = [];
  for (const p of paths) {
    const hit = allSteps.filter((s) => matchAny(s.paths, p));
    if (!hit.length) unmatched.push(p);
    for (const s of hit) ids.add(s.id);
  }
  return { ids, unmatched, all: unmatched.length > 0 };
}
