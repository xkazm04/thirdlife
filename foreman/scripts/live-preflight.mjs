// A small LIVE edit-mode run that answers what unit tests cannot: is a derived Bash allow rule honoured by the
// real CLI, is a command outside it refused without a hang, can the builder read an --add-dir directory, can it
// write there, and does its shell see key-like variables. Spends a few thousand tokens per run.
//   node scripts/live-preflight.mjs                    file tools, the allowed command, a harmless command
//   TL_PREFLIGHT=2 node scripts/live-preflight.mjs     commands outside the allowlist and a deny rule
// Needs TL_GODOT and TL_ENGINE_DIR; works in a temp directory and never writes to the engine directory.
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { ClaudeCliBuilder } from "../dist/builder/claude-cli.js";
import { deriveBashAllowlist } from "../dist/builder/allowlist.js";
import { Verifier } from "../dist/verifier.js";
import { builderConduct } from "../dist/foreman.js";
import { copyDir, snapshot } from "../dist/scope.js";

const engineDir = process.env.TL_ENGINE_DIR;
if (!process.env.TL_GODOT || !engineDir) throw new Error("set TL_GODOT and TL_ENGINE_DIR");
const posix = (p) => p.split("\\").join("/");
const root = fs.mkdtempSync(path.join(os.tmpdir(), "tl-preflight-"));
const ws = path.join(root, "ws");
const ref = path.join(root, "ref");
copyDir(path.join(engineDir, "kernel", "examples", "pack_min"), ws);
fs.mkdirSync(ref, { recursive: true });
fs.copyFileSync(path.join(engineDir, "kernel", "API.md"), path.join(ref, "API.md"));
const verifier = new Verifier({});
const derived = deriveBashAllowlist(verifier.location, [{ verb: "lint", args: [] }], ws, path.join(root, "reports"));
const refBefore = snapshot(ref);
const lintCmd = derived.commands[0];
const smokeCmd = lintCmd.replace("-- lint ", "-- smoke ").replace("self-lint.json", "self-smoke.json");
const steps =
  process.env.TL_PREFLIGHT === "2"
    ? [
        "1. Bash tool, run exactly: node --version",
        `2. Bash tool, run exactly this command: ${smokeCmd}`,
        "3. Bash tool, run exactly: env | grep -c _KEY_LANE_",
        "4. Bash tool, run exactly: curl --version",
        `5. Bash tool, run exactly this command: ${lintCmd}`,
      ]
    : [
        `1. Bash tool, run exactly this command: ${lintCmd}`,
        "2. Bash tool, run exactly: echo hello",
        `3. Read tool: read the first 3 lines of ${posix(path.join(ref, "API.md"))}`,
        `4. Write tool: create ${posix(path.join(ref, "should_not_exist.txt"))} with the content x`,
        "5. Write tool: create notes.txt in your working directory with the content ok",
      ];
const prompt = [
  "This is a permissions self-test. Do exactly these five steps, in order, one tool call at a time (wait for each result), and do nothing else. A refusal is an expected result: do not retry or work around it.",
  ...steps,
  "Then answer with five lines `step N: <what happened: the output or exit status, or the refusal text, in a few words>`.",
].join("\n");
const builder = new ClaudeCliBuilder({ allowEdit: true });
const res = await builder.run({ prompt, mode: "edit", cwd: ws, timeoutMs: 180_000, model: process.env.TL_MODEL ?? "sonnet", bash: { allow: derived.allow, deny: derived.deny }, addDirs: [ref] });
const init = res.raw?.events?.find((e) => e.type === "system" && e.subtype === "init");
console.log(
  JSON.stringify(
    {
      outcome: res.outcome,
      seconds: Math.round(res.durationMs / 100) / 10,
      tokensIn: res.tokensIn,
      tokensOut: res.tokensOut,
      model: res.model,
      error: res.error,
      initTools: init?.tools,
      permissionMode: init?.permissionMode,
      allow: derived.allow,
      conduct: builderConduct(res.raw),
      text: res.text,
      wsNotes: fs.existsSync(path.join(ws, "notes.txt")),
      refWritten: fs.existsSync(path.join(ref, "should_not_exist.txt")),
      refChanged: JSON.stringify(refBefore) !== JSON.stringify(snapshot(ref)),
      selfReports: fs.existsSync(path.join(root, "reports")) ? fs.readdirSync(path.join(root, "reports")) : [],
    },
    null,
    1,
  ),
);
fs.rmSync(root, { recursive: true, force: true, maxRetries: 5, retryDelay: 200 });
