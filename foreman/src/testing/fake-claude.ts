#!/usr/bin/env node
// A stand-in for the `claude` executable, for tests of the claude-cli adapter through the real spawn door
// (real process, real stdin, real argv, real kill). It speaks the dialect observed from Claude Code 2.1.322:
// `--version`, `auth status --json`, and `-p --output-format stream-json` with init and result events.
// It never touches the network. Point the adapter at the compiled file: bin = dist/testing/fake-claude.js.
//
// Environment:
//   FAKE_CLAUDE_SCRIPT  JSON file: { steps: [ { all?: string[] (substrings the prompt must contain), write?, text?,
//                       json?, tokensIn?, tokensOut?, hang?, isError?, stopReason? } ] }; first match wins
//   FAKE_CLAUDE_LOG     JSONL file: one line per -p call with argv, cwd, the prompt's sha1 and length, the content
//                       of the --settings file, and whether ANTHROPIC_API_KEY was present
//   FAKE_CLAUDE_AUTH    "none" makes `auth status` report loggedIn false
//   FAKE_CLAUDE_AUTHSOURCE  overrides apiKeySource in the init event
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";

interface Step {
  all?: string[];
  write?: Record<string, string>;
  text?: string;
  json?: unknown;
  tokensIn?: number;
  tokensOut?: number;
  hang?: boolean;
  isError?: boolean;
  stopReason?: string;
}

const argv = process.argv.slice(2);
const flag = (name: string): string | undefined => {
  const i = argv.indexOf(name);
  return i === -1 ? undefined : argv[i + 1];
};
const say = (o: object): void => {
  process.stdout.write(JSON.stringify(o) + "\n");
};
const keyPresent = typeof process.env["ANTHROPIC_API_KEY"] === "string" && process.env["ANTHROPIC_API_KEY"].length > 0;

if (argv[0] === "--version") {
  process.stdout.write("2.1.322 (Claude Code)\n");
} else if (argv[0] === "auth" && argv[1] === "status") {
  const out = process.env["FAKE_CLAUDE_AUTH"] === "none" ? { loggedIn: false } : keyPresent ? { loggedIn: true, authMethod: "api_key" } : { loggedIn: true, authMethod: "claude.ai", subscriptionType: "max" };
  process.stdout.write(JSON.stringify(out) + "\n");
  if (!out.loggedIn) process.exitCode = 1;
} else if (argv.includes("-p")) {
  const chunks: Buffer[] = [];
  process.stdin.on("data", (d: Buffer) => chunks.push(d));
  process.stdin.on("end", () => {
    const prompt = Buffer.concat(chunks).toString("utf8");
    const tools = (flag("--tools") ?? "default").split(",").filter((t) => t.length > 0);
    const schema = flag("--json-schema");
    const settingsFile = flag("--settings");
    let settings: unknown;
    try {
      if (settingsFile) settings = JSON.parse(fs.readFileSync(settingsFile, "utf8"));
    } catch {
      settings = "unreadable";
    }
    const logFile = process.env["FAKE_CLAUDE_LOG"];
    if (logFile) {
      fs.appendFileSync(
        logFile,
        JSON.stringify({ argv, cwd: process.cwd(), promptSha1: crypto.createHash("sha1").update(prompt).digest("hex"), promptLength: prompt.length, settings, keyPresent }) + "\n",
      );
    }
    const scriptFile = process.env["FAKE_CLAUDE_SCRIPT"];
    const steps = scriptFile ? ((JSON.parse(fs.readFileSync(scriptFile, "utf8")) as { steps: Step[] }).steps ?? []) : [];
    const step = steps.find((s) => (s.all ?? []).every((needle) => prompt.includes(needle))) ?? { text: "ok" };
    say({
      type: "system",
      subtype: "init",
      tools: schema ? [...tools, "StructuredOutput"] : tools,
      mcp_servers: [],
      model: flag("--model") ?? "claude-fake",
      permissionMode: flag("--permission-mode") ?? "default",
      apiKeySource: process.env["FAKE_CLAUDE_AUTHSOURCE"] ?? (keyPresent ? "ANTHROPIC_API_KEY" : "none"),
      claude_code_version: "2.1.322",
    });
    if (step.hang) {
      // A grandchild as well, so the caller's tree kill has a tree to kill.
      setInterval(() => {}, 1 << 30);
      return;
    }
    if (tools.includes("Write")) {
      for (const [rel, content] of Object.entries(step.write ?? {})) {
        const abs = path.resolve(process.cwd(), rel);
        fs.mkdirSync(path.dirname(abs), { recursive: true });
        fs.writeFileSync(abs, content);
      }
    }
    const text = step.text ?? (step.json !== undefined ? JSON.stringify(step.json) : "done");
    say({ type: "assistant", message: { role: "assistant", content: [{ type: "text", text }], stop_reason: null } });
    say({ type: "rate_limit_event", rate_limit_info: { status: "allowed", resetsAt: 1794352800, rateLimitType: "five_hour" } });
    say({
      type: "result",
      subtype: "success",
      is_error: step.isError === true,
      api_error_status: null,
      num_turns: schema ? 2 : 1,
      stop_reason: step.stopReason ?? (schema ? "tool_use" : "end_turn"),
      terminal_reason: "completed",
      result: text,
      ...(schema && step.json !== undefined ? { structured_output: step.json } : {}),
      total_cost_usd: 0,
      permission_denials: [],
      usage: { input_tokens: 2, cache_creation_input_tokens: step.tokensIn ?? 0, cache_read_input_tokens: 0, output_tokens: step.tokensOut ?? 0 },
    });
    process.exitCode = step.isError ? 1 : 0;
  });
} else {
  process.stderr.write("fake-claude: unsupported invocation\n");
  process.exitCode = 2;
}
