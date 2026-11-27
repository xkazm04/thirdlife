// D27b item 23 (lane T2-editor; J2nd's biplane copy, events 743-778): the person asked for a harpoon; core's builder made
// it, and it hooks her (J2nd's own count after r24: 1 hook in 3 tries). The land check (landcheck.ts) wants the new move
// counted in a bot test the package's acceptance runs, but core's acceptance runs only the plan's tofu bot, which the
// Foreman freezes as its measure: r25 and r26 put the count in the tofu bot, the freeze undid it (events 761, 772), and
// after three rounds the card said "part of your change was NOT made by core: the new move harpoon does not land".
// A package whose acceptance runs no bot test of its own may write one for the count: tests/moves_<package>.gd, in its
// scope for a person's play change. The Foreman runs it in the land check (landcheck.ts movesRun) on a copy of the
// workspace whose manifest lists it; the pack's manifest does not, so the final verification and the other packages'
// checks never run it.
import type { JobEvent, PackageSpec } from "./events.js";
import { askedChange } from "./boundlift.js";
import { tofuOf } from "./tofu.js";

/** The bot test a package may write to count its new moves. */
export const movesTestPath = (id: string): string => `tests/moves_${id}.gd`;

/** The bot tests the package's acceptance runs, other than the plan's tofu bot. */
export function ownBotTests(plan: readonly PackageSpec[], spec: PackageSpec): string[] {
  const tofu = tofuOf(plan as PackageSpec[])?.test;
  return [...new Set(spec.acceptance.flatMap((a) => (a.verb === "bot" ? a.args.flatMap((x) => (x.startsWith("--test=") ? [x.slice(7)] : [])) : [])).filter((t) => t !== tofu))];
}

/** The moves test `spec` may write in the person's change in flight, or undefined (no play change; a test of its own already). */
export function movesTestFor(plan: readonly PackageSpec[], spec: PackageSpec, events: readonly JobEvent[]): string | undefined {
  if (spec.kind === "base") return undefined;
  const asked = askedChange(events);
  if (asked === undefined || asked.kind !== "play") return undefined;
  return ownBotTests(plan, spec).length === 0 ? movesTestPath(spec.id) : undefined;
}
