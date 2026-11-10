// Live checks against the real `claude` CLI. EVERY CHECK EXCEPT `probe` SPENDS TOKENS on the logged-in account.
// Nothing here runs from `npm test`. Usage (after `npm run build`):
//   node scripts/live-check.mjs probe
//   node scripts/live-check.mjs generate      one-line prompt + tiny JSON schema
//   node scripts/live-check.mjs edit          one small file in an empty temp directory
//   node scripts/live-check.mjs edit-timeout  the same with a 1 s timeout (expects outcome "timeout")
//   node scripts/live-check.mjs designer      Designer call on the Phase 0 sentence
// Options: --model <alias> (default sonnet), --out <dir> (where the full envelopes are written; default a temp dir).
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { ClaudeCliBuilder } from "../dist/builder/claude-cli.js";
import { designBrief } from "../dist/designer.js";

const [what, ...rest] = process.argv.slice(2);
const opt = (name, dflt) => {
  const i = rest.indexOf(`--${name}`);
  return i === -1 ? dflt : rest[i + 1];
};
const model = opt("model", "sonnet");
const outDir = path.resolve(opt("out", undefined) ?? fs.mkdtempSync(path.join(os.tmpdir(), "tl-foreman-live-")));
fs.mkdirSync(outDir, { recursive: true });

const summary = (label, r) => {
  const init = r.raw?.events?.find?.((e) => e.type === "system" && e.subtype === "init");
  const result = [...(r.raw?.events ?? [])].reverse().find((e) => e.type === "result");
  const line = {
    check: label,
    ok: r.ok,
    outcome: r.outcome,
    seconds: Math.round(r.durationMs / 100) / 10,
    tokensIn: r.tokensIn,
    tokensOut: r.tokensOut,
    usage: result?.usage
      ? { input: result.usage.input_tokens, cacheCreate: result.usage.cache_creation_input_tokens, cacheRead: result.usage.cache_read_input_tokens, output: result.usage.output_tokens }
      : undefined,
    costUsdAsReported: result?.total_cost_usd,
    turns: result?.num_turns,
    stopReason: result?.stop_reason,
    model: r.model,
    apiKeySource: r.observed?.apiKeySource,
    billingObserved: r.observed?.billingMode,
    permissionMode: r.observed?.permissionMode,
    tools: r.observed?.tools,
    mcpServers: init?.mcp_servers?.length,
    structuredOutputField: result ? "structured_output" in result : undefined,
    permissionDenials: result?.permission_denials?.map?.((d) => d.tool_name),
    eventTypes: [...new Set((r.raw?.events ?? []).map((e) => `${e.type}${e.subtype ? "/" + e.subtype : ""}`))],
    noiseLines: r.raw?.noiseLines,
    exitCode: r.raw?.exitCode,
    error: r.error,
    text: typeof r.text === "string" ? r.text.slice(0, 600) : undefined,
    json: r.json,
    argv: r.raw?.argv,
  };
  fs.writeFileSync(path.join(outDir, `${label}.json`), JSON.stringify({ summary: line, raw: r.raw }, null, 1));
  console.log(JSON.stringify(line, null, 1));
  console.log(`full envelope: ${path.join(outDir, `${label}.json`)}`);
};

const builder = new ClaudeCliBuilder({ allowEdit: what === "edit" || what === "edit-timeout" });
const probe = await builder.probe();

if (what === "probe") {
  console.log(JSON.stringify(probe, null, 1));
} else if (!probe.ok) {
  console.log("probe failed, no live check run:", JSON.stringify(probe.notes));
  process.exitCode = 1;
} else if (what === "generate") {
  const schema = { type: "object", additionalProperties: false, required: ["capital"], properties: { capital: { type: "string" } } };
  const r = await builder.run({ prompt: 'Reply with one JSON object naming the capital of France, like {"capital": "<name>"}. No other text.', mode: "generate", cwd: "", schema, model, timeoutMs: 180_000 });
  summary("generate", r);
} else if (what === "edit" || what === "edit-timeout") {
  const ws = fs.mkdtempSync(path.join(os.tmpdir(), "tl-foreman-live-ws-"));
  const prompt =
    "Create a file named hello.txt in the current directory containing exactly this one line: hello from the foreman\n" +
    "Then, only if you have a tool that runs shell commands, run: echo shell-works > shell.txt\n" +
    "If you have no such tool, do not try anything else. Finally answer with one line: either SHELL_AVAILABLE or NO_SHELL.";
  const r = await builder.run({ prompt, mode: "edit", cwd: ws, model, timeoutMs: what === "edit" ? 240_000 : 1000 });
  summary(what, r);
  const files = fs.readdirSync(ws);
  console.log(JSON.stringify({ workspace: ws, files, hello: files.includes("hello.txt") ? fs.readFileSync(path.join(ws, "hello.txt"), "utf8") : null }));
  fs.rmSync(ws, { recursive: true, force: true });
} else if (what === "designer") {
  const res = await designBrief(builder, "a ball-and-paddle game in a walled court", { model, timeoutMs: 300_000, attempts: 1 });
  res.calls.forEach((c, i) => summary(`designer-a${i + 1}`, c.result));
  console.log(JSON.stringify({ accepted: res.ok, reason: res.ok ? undefined : res.reason, problems: res.calls.map((c) => c.problems), value: res.ok ? res.value : undefined }, null, 1));
} else {
  console.log("usage: node scripts/live-check.mjs probe|generate|edit|edit-timeout|designer [--model sonnet] [--out dir]");
  process.exitCode = 2;
}
