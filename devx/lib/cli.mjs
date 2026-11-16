// `tl` dispatch: finds the command file, runs it, and guarantees the protocol's last line (devx/lib/verdict.mjs).
// Commands are auto-discovered from <commandsDir>/*.mjs; each exports
//   export const summary = "one line";  export async function run(args /* string[] */, ctx) -> exit code (number)
// A command that ends without a tl.devx/1 last line whose exit is its own (a listing, a usage error on stderr, a throw)
// gets one here, so a reader can rely on "no JSON last line = the run was killed".
import fs from "node:fs";
import path from "node:path";
import { pathToFileURL } from "node:url";
import * as ctx from "./ctx.mjs";
import { emit, parseLine } from "./verdict.mjs";

const STDERR_KEEP = 2000;

/** Watches what goes to stdout (the last complete line) and stderr (its tail) while `fn` runs. */
async function watched(fn) {
  const seen = { last: "", partial: "", err: "" };
  const out = process.stdout.write, err = process.stderr.write;
  process.stdout.write = function (chunk, ...rest) {
    const lines = (seen.partial + String(chunk)).split("\n");
    seen.partial = lines.pop();
    for (const l of lines) if (l.trim()) seen.last = l.trim();
    return out.call(this, chunk, ...rest);
  };
  process.stderr.write = function (chunk, ...rest) {
    seen.err = (seen.err + String(chunk)).slice(-STDERR_KEEP);
    return err.call(this, chunk, ...rest);
  };
  try { return { value: await fn(), seen }; } finally { process.stdout.write = out; process.stderr.write = err; }
}

/** Runs `tl <argv>`; returns the exit code (the caller exits with it). */
export async function main(argv, { commandsDir }) {
  const names = fs.readdirSync(commandsDir).filter((f) => f.endsWith(".mjs")).map((f) => f.slice(0, -4)).sort();
  const load = (n) => import(pathToFileURL(path.join(commandsDir, n + ".mjs")).href);
  const [cmd, ...args] = argv;
  if (!cmd || cmd === "help" || cmd === "--help") {
    console.log("tl <command> [args]\n");
    for (const n of names) console.log(`  ${n.padEnd(10)} ${(await load(n)).summary ?? ""}`);
    return emit("help", cmd ? 0 : 2, { commands: names, ...(cmd ? {} : { error: "no command given" }) });
  }
  if (!names.includes(cmd)) {
    const error = `tl: unknown command '${cmd}'. Try: tl help`;
    console.error(error);
    return emit(cmd, 2, { error });
  }
  let code, seen;
  try {
    const mod = await load(cmd);
    ({ value: code, seen } = await watched(() => mod.run(args, ctx)));
    code = code ?? 0;
  } catch (e) {
    console.error(e?.stack ?? String(e));
    return emit(cmd, 1, { error: `${cmd} threw: ${String(e?.message ?? e).split("\n")[0]}` });
  }
  const own = parseLine(seen.last);
  if (own && own.exit === code && seen.partial.trim() === "") return code;
  const said = own ? { said_exit: own.exit } : {};
  const error = seen.err.trim().split(/\r?\n/).slice(-5).join("\n");
  return emit(cmd, code, { ...(code !== 0 ? { error: error || `tl ${cmd} exited ${code}` } : {}), ...said });
}
