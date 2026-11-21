// P10 item 6: the player check a plan names in a contract (moved out of designer.ts, its line rule; re-exported there).
import type { PackageSpec } from "./events.js";

/** P10 item 6: the line a contract names the player's check with. */
export const PLAYER_CHECK_RE = /^[ \t>*-]*PLAYER CHECK:[ \t]*`?(tests\/[A-Za-z0-9_\/.-]+\.gd)`?[ \t]*(.*)$/m;

/** The player checks a plan names: the bot, the package whose contract names it, and what the line says it fails on. */
export function playerChecks(packages: PackageSpec[]): { package: string; test: string; what: string }[] {
  const out: { package: string; test: string; what: string }[] = [];
  for (const p of packages) {
    for (const m of p.contract.matchAll(new RegExp(PLAYER_CHECK_RE.source, "gm"))) out.push({ package: p.id, test: m[1] as string, what: (m[2] ?? "").trim() });
  }
  return out;
}

/**
 * P10 item 6 (the real hockey job, finding 7): a game the player takes part in needs a bot that FAILS when the
 * human-controlled side has nothing to do. A plan "has player input" when a package registers the capability
 * `input`. Such a plan must name the check in a contract, in one line a builder reads too:
 *   PLAYER CHECK: tests/<bot>.gd fails when <what the player's side can no longer do>
 * The bot must be registered by a package of the plan (the final verification runs every registered bot, whatever
 * the acceptance lists say), and the line must say what it fails on. Whether the bot really fails then is the
 * builder's work and the Verifier's: a plan check reads words.
 */
export function playerCheckProblems(packages: PackageSpec[]): string[] {
  const withInput = packages.filter((p) => (p.registers?.capabilities ?? []).includes("input"));
  if (withInput.length === 0) return [];
  const checks = playerChecks(packages);
  const example = 'PLAYER CHECK: tests/<bot>.gd fails when <what the human-controlled side can no longer do>';
  if (checks.length === 0) {
    return [
      `the game has player input (package "${withInput[0]?.id ?? ""}" registers the capability "input") but no contract names a player check. Add ONE line to the contract of the package that owns the bot: "${example}" (for example: "fails when the player's skater took no shot", "fails when the result is the same with and without the player's inputs", "fails when the player's side never touched the ball"). The bot drives the player's input actions, and its \`ok\` must depend on what the player's side did, not only on the game reaching its end`,
    ];
  }
  const out: string[] = [];
  const registered = new Set(packages.flatMap((p) => p.registers?.tests ?? []));
  for (const c of checks) {
    if (!registered.has(c.test)) out.push(`package "${c.package}": the PLAYER CHECK line names ${c.test}, which no package registers in registers.tests`);
    if (c.what.replace(/[^A-Za-z]/g, "").length < 12) out.push(`package "${c.package}": the PLAYER CHECK line for ${c.test} must say what the bot fails on ("${example}")`);
  }
  return out;
}
