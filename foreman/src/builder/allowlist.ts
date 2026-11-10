// The edit seam's shell grants, derived from the package's own acceptance commands. Nothing here is hand-written
// per package: the only commands a builder may run are the runner calls the verifier itself will make.
import type { Acceptance } from "../events.js";

export interface RunnerLocation {
  /** The executable the verifier spawns (TL_GODOT, or node when a script stands in for it). */
  exe: string;
  /** Arguments placed before the Godot ones (the fake runner's script path). */
  preArgs: string[];
  engineDir: string;
  /** Where a capture window opens (Godot --position X,Y). Default 0,1440. */
  windowPosition?: string;
}

export const HOST_SCENE = "res://kernel/host/host.tscn";

/** The argument vector the verifier uses for one acceptance entry. */
export function runnerArgv(loc: RunnerLocation, a: Pick<Acceptance, "verb" | "args">, packDir: string, report: string): string[] {
  return [
    ...loc.preArgs,
    // Always headless, capture included: the process we start is the supervisor, and it opens the capture worker's
    // window itself at --position 0,1440 (kernel API.md section 18). Observed 2026-11-10 on the real engine: a
    // windowed supervisor crashed in the AMD driver (exit 0xC0000005) before writing a report.
    "--headless",
    "--path",
    loc.engineDir,
    HOST_SCENE,
    "--",
    a.verb,
    `--pack=${packDir}`,
    ...a.args,
    `--report=${report}`,
  ];
}

const CONTROL = /[;&|<>`\n\r]|\$\(/;

function quote(arg: string): string {
  return /^[A-Za-z0-9_@%+=:,./\\-]+$/.test(arg) ? arg : `"${arg.replace(/(["\\$`])/g, "\\$1")}"`;
}

/** One command as a builder would type it in a POSIX shell (Git Bash on Windows): forward slashes, quoted. */
export function commandLine(exe: string, argv: string[]): string {
  return [exe, ...argv].map((a) => quote(a.replace(/\\/g, "/"))).join(" ");
}

export interface DerivedAllowlist {
  /** Full example commands, shown to the builder in its prompt. */
  commands: string[];
  /** Permission rules for the CLI: one prefix per acceptance verb, never a bare launcher. */
  allow: string[];
  /** Rules that win over any allow. */
  deny: string[];
  /** Acceptance entries that produced no grant, with the reason. */
  rejected: string[];
}

export const BASH_DENY = [
  "Bash(git:*)",
  "Bash(rm -rf:*)",
  "Bash(curl:*)",
  "Bash(wget:*)",
  "Bash(npm:*)",
  "Bash(npx:*)",
  "Bash(pip:*)",
  "Bash(powershell:*)",
  "Bash(pwsh:*)",
  "Bash(cmd:*)",
  "Bash(taskkill:*)",
  "Bash(sudo:*)",
];

/**
 * Derives the grants for one package. The prefix runs up to and including the verb, so a grant for `lint` does not
 * allow `capture`, and the launcher alone (godot, node) is never granted. Prefix rules do not stop a builder from
 * appending other options to an allowed verb; that is why the pack and report paths stay inside its workspace and
 * the verifier's own run, not the builder's, decides.
 */
export function deriveBashAllowlist(
  loc: RunnerLocation,
  acceptance: Pick<Acceptance, "verb" | "args">[],
  wsDir: string,
  selfReportDir: string,
): DerivedAllowlist {
  const commands: string[] = [];
  const allow: string[] = [];
  const rejected: string[] = [];
  const seen = new Set<string>();
  for (const a of acceptance) {
    const report = `${selfReportDir.replace(/\\/g, "/")}/self-${a.verb}.json`;
    const argv = runnerArgv(loc, a, wsDir, report);
    const all = [loc.exe, ...argv];
    const badArg = all.find((x) => CONTROL.test(x));
    if (badArg !== undefined) {
      rejected.push(`${a.verb}: argument contains a shell control operator: ${JSON.stringify(badArg)}`);
      continue;
    }
    commands.push(commandLine(loc.exe, argv));
    const verbAt = argv.indexOf("--") + 1;
    const prefix = commandLine(loc.exe, argv.slice(0, verbAt + 1));
    if (prefix.includes("(") || prefix.includes(")")) {
      rejected.push(`${a.verb}: command prefix contains parentheses and cannot be written as a rule`);
      commands.pop();
      continue;
    }
    const rule = `Bash(${prefix}:*)`;
    if (!seen.has(rule)) {
      seen.add(rule);
      allow.push(rule);
    }
  }
  return { commands, allow, deny: [...BASH_DENY], rejected };
}
