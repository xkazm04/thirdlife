// M4 (spark world-sandbox, 26 Nov 2026): `foreman world-edit --in ASK.json --out ANSWER.json`, the LLM command bar's
// call (contracts/BUILD.md "The LLM command bar"). The `place` pattern (place.ts): the exe writes a measured ask
// (tl.world-edit-ask/1: the sentence, the cursor, a region read round it, the ground, the refused columns, the tables),
// the model answers with ops, every problem of an answer is fed back (generate(), 2 attempts), and the answer is written
// atomically as tl.world-edit/1: {schema, ops, note, model, durationMs, tokensIn?, tokensOut?} or {schema, error}. The
// model may write boxes (`fill`, `clear`); world_edit_check.ts replays them on the region and expands them, so the
// answer file holds only the contract's ops. No job, no site directory: the exe logs the call itself
// (user://home/llm_calls.jsonl, which `tl ledger --home` reads).
import fs from "node:fs";
import path from "node:path";
import { randomUUID } from "node:crypto";
import { schemaErrors } from "./builder/json.js";
import type { Builder } from "./builder/types.js";
import { generate, type GenerateOptions } from "./designer.js";
import { UsageError } from "./cli_args.js";
import { PKG_ROOT } from "./paths.js";
import { expand, MAX_OPS, type Ask, type ModelOp } from "./world_edit_check.js";

const int = { type: "integer" }, words = { type: "string", pattern: "\\S" };
const ints = (n: number) => ({ type: "array", minItems: n, maxItems: n, items: int });
const obj = (properties: Record<string, object>, optional: string[] = []) => ({
  type: "object", properties, required: Object.keys(properties).filter((k) => !optional.includes(k)), additionalProperties: false,
});
const table = { type: "array", minItems: 1, items: obj({ id: { type: "integer", minimum: 1 }, name: words, note: words }) };
export const askSchema = obj({
  schema: { const: "tl.world-edit-ask/1" }, sentence: { type: "string", pattern: "\\S", maxLength: 400 },
  cursor: ints(3), facing: { type: "integer", minimum: 0, maximum: 3 },
  region: obj({ min: ints(3), max: ints(3) }),
  ops: { type: "array", minItems: 1, uniqueItems: true, items: { enum: ["place", "remove", "land", "paint", "put", "lift"] } },
  blocks: { type: "array", items: { type: "array", minItems: 7, maxItems: 7, items: int } },
  ground: obj({ min: ints(2), rows: { type: "array", minItems: 1, items: { type: "array", minItems: 1, items: int } } }),
  refused: { type: "array", items: obj({ reason: words, runs: { type: "array", minItems: 1, items: ints(3) } }) },
  shapes: table, mats: table,
  paints: { type: "array", minItems: 1, items: words },
  parts: { type: "array", minItems: 1, items: obj({ kind: words, note: words }) },
  layers: { type: "object" },
  caps: obj({ ops: { type: "integer", minimum: 1 }, blocks_left: { type: "integer", minimum: 0 } }),
}, ["refused", "paints", "parts", "layers"]);

export function readAsk(file: string): Ask {
  let value: unknown;
  try {
    value = JSON.parse(fs.readFileSync(file, "utf8"));
  } catch (e) { throw new UsageError("--in: " + (e as Error).message); }
  const problems = schemaErrors(askSchema, value);
  if (problems.length) throw new UsageError("--in: " + problems.join(", "));
  const ask = value as Ask, { min, max } = ask.region;
  if (min.some((v, i) => v > (max[i] as number))) throw new UsageError("--in: region.max is below region.min");
  if (ask.ground.rows.length !== max[2] - min[2] + 1 || ask.ground.rows.some((r) => r.length !== max[0] - min[0] + 1))
    throw new UsageError("--in: ground.rows must hold one row per z and one height per x of the region");
  if (ask.ground.min[0] !== min[0] || ask.ground.min[1] !== min[2]) throw new UsageError("--in: ground.min must be the region's [min x, min z]");
  return ask;
}

const FACING = ["north (-z)", "west (-x)", "south (+z)", "east (+x)"];

/** Runs [z, x0, x1] as rectangles: rows of the same x runs next to each other in z become one "x a..b, z c..d". */
export function boxes(runs: [number, number, number][]): string[] {
  const rows = new Map<number, string>();
  for (const [z, x0, x1] of runs) rows.set(z, (rows.has(z) ? rows.get(z) + "," : "") + `${x0}..${x1}`);
  const zs = [...rows.keys()].sort((a, b) => a - b), out: string[] = [];
  for (let i = 0; i < zs.length; ) {
    let j = i;
    while (j + 1 < zs.length && zs[j + 1] === (zs[j] as number) + 1 && rows.get(zs[j + 1] as number) === rows.get(zs[i] as number)) j++;
    const z = zs[i] === zs[j] ? `z ${zs[i]}` : `z ${zs[i]}..${zs[j]}`;
    for (const x of (rows.get(zs[i] as number) as string).split(",")) out.push(`x ${x}, ${z}`);
    i = j + 1;
  }
  return out;
}

/** The ask as the prompt's measured facts: tables, the region, the ground, the refused columns, the blocks there. */
export function facts(ask: Ask): Record<string, string> {
  const { min, max } = ask.region, g = ask.ground;
  const ground = [`x from ${min[0]} to ${max[0]} left to right; one row per z from ${min[2]} to ${max[2]}`,
    ...g.rows.map((r, j) => `z ${g.min[1] + j}: ${r.join(" ")}`)].join("\n");
  const refused = ask.refused?.length
    ? ask.refused.map((r) => `${r.reason}: ` + boxes(r.runs).join("; ")).join("\n")
    : "none: every column of the region may be built on";
  const names = new Map(ask.shapes.map((s) => [s.id, s.name])), mats = new Map(ask.mats.map((m) => [m.id, m.name]));
  const blocks = ask.blocks.length
    ? ask.blocks.map(([x, y, z, s, m, r, f]) => `${x},${y},${z} ${names.get(s as number) ?? s}(${s}) ${mats.get(m as number) ?? m}(${m}) rot ${r}${f ? " flip" : ""}`).join("\n")
    : "none: the region holds no blocks";
  const tables = [
    "Shapes (id name: what it is):", ...ask.shapes.map((s) => `${s.id} ${s.name}: ${s.note}`),
    "Materials (id name: what it looks like):", ...ask.mats.map((m) => `${m.id} ${m.name}: ${m.note}`),
    ...(ask.paints ? ["Ground paints (paint op): " + ask.paints.join(", ")] : []),
    ...(ask.parts ? ["Kit parts (put op):", ...ask.parts.map((p) => `${p.kind}: ${p.note}`)] : []),
  ].join("\n");
  const kinds = ask.ops.includes("place") ? [...ask.ops, "fill", "clear"] : ask.ops;
  return {
    sentence: ask.sentence.replace(/\s+/g, " ").trim(),
    cursor: `${ask.cursor.join(", ")} (the cell the player points at: "here"); the player looks ${FACING[ask.facing]}, so "in front" is that way`,
    region: `${min.join(", ")} to ${max.join(", ")} (inclusive). Every cell you touch must be inside it`,
    ops: kinds.join(", "),
    caps: `at most ${Math.min(MAX_OPS, ask.caps.ops)} operations after boxes are expanded; room for ${ask.caps.blocks_left} more blocks in the Home`,
    tables, ground, refused, blocks,
    layers: ask.layers && Object.keys(ask.layers).length ? "Other layers in the region (as the Home reads them):\n" + JSON.stringify(ask.layers) : "",
  };
}

export async function worldEditCommand(input: string | undefined, output: string | undefined, builderFor: () => Builder, opts: GenerateOptions): Promise<number> {
  if (!input || !output || path.resolve(input) === path.resolve(output)) throw new UsageError("world-edit needs distinct --in and --out files");
  const ask = readAsk(input);
  const read = (f: string) => fs.readFileSync(path.join(PKG_ROOT, "prompts", f), "utf8");
  const builder = builderFor(), schema = "tl.world-edit/1";
  let answer: Record<string, unknown>;
  try {
    const result = await generate<{ ops: ModelOp[]; note: string }>(builder, "world_edit", read("world_edit.md"), facts(ask),
      JSON.parse(read("world_edit.schema.json")), (value) => expand(ask, (value as { ops: ModelOp[] }).ops).problems, opts);
    if (result.ok) {
      const calls = result.calls.map((c) => c.result);
      const done = expand(ask, result.value.ops);
      answer = { schema, ops: done.ops, note: result.value.note.trim(), model: calls.at(-1)?.model ?? opts.model ?? builder.name,
        durationMs: calls.reduce((sum, c) => sum + c.durationMs, 0) };
      for (const k of ["tokensIn", "tokensOut"] as const) {
        if (calls.some((c) => c[k] !== undefined)) answer[k] = calls.reduce((sum, c) => sum + (c[k] ?? 0), 0);
      }
    } else answer = { schema, error: result.reason };
  } catch (e) { answer = { schema, error: (e as Error).message }; }
  const tmp = output + "." + randomUUID() + ".tmp";
  try {
    fs.writeFileSync(tmp, JSON.stringify(answer) + "\n");
    fs.renameSync(tmp, output);
  } finally { fs.rmSync(tmp, { force: true }); }
  return answer.error === undefined ? 0 : 1;
}
