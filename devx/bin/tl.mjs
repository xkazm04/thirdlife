#!/usr/bin/env node
// `tl` developer entry point. Commands are auto-discovered from devx/lib/commands/*.mjs; each exports
//   export const summary = "one line";  export async function run(args /* string[] */, ctx) -> exit code (number)
// Adding a command = adding a file. No registry to edit, so parallel sessions never collide here.
// devx/lib/cli.mjs runs it and guarantees the tl.devx/1 last line (devx/lib/verdict.mjs).
import path from "node:path";
import { fileURLToPath } from "node:url";
import { main } from "../lib/cli.mjs";

process.exit(await main(process.argv.slice(2), { commandsDir: path.join(path.dirname(fileURLToPath(import.meta.url)), "..", "lib", "commands") }));
