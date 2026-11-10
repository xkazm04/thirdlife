#!/usr/bin/env node
// `tl` developer entry point. Commands are auto-discovered from devx/lib/commands/*.mjs; each exports
//   export const summary = "one line";  export async function run(args /* string[] */, ctx) -> exit code (number)
// Adding a command = adding a file. No registry to edit, so parallel sessions never collide here.
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import * as ctx from "../lib/ctx.mjs";

const dir = path.join(path.dirname(fileURLToPath(import.meta.url)), "..", "lib", "commands");
const names = fs.readdirSync(dir).filter((f) => f.endsWith(".mjs")).map((f) => f.slice(0, -4)).sort();
const [cmd, ...args] = process.argv.slice(2);

if (!cmd || cmd === "help" || cmd === "--help") {
  console.log("tl <command> [args]\n");
  for (const n of names) console.log(`  ${n.padEnd(10)} ${(await import(pathToFileURL(path.join(dir, n + ".mjs")))).summary ?? ""}`);
  process.exit(cmd ? 0 : 2);
}
if (!names.includes(cmd)) { console.error(`tl: unknown command '${cmd}'. Try: tl help`); process.exit(2); }
const mod = await import(pathToFileURL(path.join(dir, cmd + ".mjs")));
process.exit((await mod.run(args, ctx)) ?? 0);
