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
import { ASK_OPS, expand, MAX_OPS, type Ask, type ModelOp } from "./world_edit_check.js";
import { LOOKS } from "./world_edit_rules.js";
import { render } from "./generate.js";

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
  ops: { type: "array", minItems: 1, uniqueItems: true, items: { enum: ASK_OPS } },
  blocks: { type: "array", items: { type: "array", minItems: 7, maxItems: 7, items: int } },
  ground: obj({ min: ints(2), rows: { type: "array", minItems: 1, items: { type: "array", minItems: 1, items: int } } }),
  refused: { type: "array", items: obj({ reason: words, runs: { type: "array", minItems: 1, items: ints(3) } }) },
  shapes: table, mats: table,
  paints: { type: "array", minItems: 1, items: words },
  parts: { type: "array", minItems: 1, items: obj({ kind: words, note: words }) },
  layers: { type: "object" },
  water: { type: "array", items: obj({ y: int, runs: { type: "array", minItems: 1, items: ints(3) } }) },
  zones: { type: "array", items: obj({ id: { type: "integer", minimum: 1 }, box: { type: "array", minItems: 2, maxItems: 2, items: ints(3) },
    look: { enum: LOOKS }, name: words }, ["name"]) },             // M6 (lane C): the file's shapes (rules_layer.gd `read_region`)
  rules: { type: "array", items: obj({ id: { type: "integer", minimum: 1 }, when: { type: "object" }, if: { type: "array", minItems: 1, items: { type: "object" } },
    do: { type: "array", minItems: 1, items: { type: "object" } } }, ["if"]) },
  rules_room: obj({ zones_left: { type: "integer", minimum: 0 }, rules_left: { type: "integer", minimum: 0 }, counters: { type: "array", items: words } }),
  caps: obj({ ops: { type: "integer", minimum: 1 }, blocks_left: { type: "integer", minimum: 0 } }),
}, ["refused", "paints", "parts", "layers", "water", "zones", "rules", "rules_room"]);

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

/** The ask's `water` (M5) as the prompt's "Water (measured)": per surface cell y, the columns it covers as boxes. */
export function waterFacts(water: Ask["water"]): string {
  if (!water?.length) return "none in the region";
  return water.map((w) => `surface in cell y ${w.y} (a block at y ${w.y} or lower in these columns stands in the water): ` +
    boxes(w.runs).join("; ")).join("\n");
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
    tables, ground, refused, blocks, water: waterFacts(ask.water),
    layers: ask.layers && Object.keys(ask.layers).length ? "Other layers in the region (as the Home reads them):\n" + JSON.stringify(ask.layers) : "",
    more_ops: moreOps(ask.ops),
    rules: rulesFacts(ask),
  };
}

/** M6 (lane C): the zones and rules section (prompts/world_edit_rules.md) with the ask's measured `zones`, `rules` and
 *  `rules_room`, only when the Home offers the zone op (its rules layer is built). */
export function rulesFacts(ask: Ask): string {
  if (!ask.ops.includes("zone")) return "";
  const room = ask.rules_room;
  const list = (l: Record<string, unknown>[] | undefined) => (l?.length ? "\n" + l.map((x) => JSON.stringify(x)).join("\n") : "none");
  return render(fs.readFileSync(path.join(PKG_ROOT, "prompts", "world_edit_rules.md"), "utf8"), {
    zones: list(ask.zones), rules: list(ask.rules),
    room: room ? `${room.zones_left} more zones, ${room.rules_left} more rules; counters in use: ${room.counters.length ? room.counters.join(", ") : "none"}` : "512 more zones, 512 more rules; counters in use: none",
  });
}

/** How to write the land, paint, put and lift ops (M2, M3) and pour, drain, path, unpath and plant (M5), each only when
 *  the Home offers it (its layer is built), with worked examples of a pond (land, then pour) and a path. */
function moreOps(kinds: string[]): string {
  const out: string[] = [];
  if (kinds.includes("land")) out.push(
    `- {"op":"land","verts":[[i,j,to_cm],...]} moves ground vertices on the 3 m lattice: vertex [i, j] is at world (3i, 3j);
  to_cm is its new absolute height in whole cm (the "ground" layer above gives today's cm). Shape terrain with a few
  smooth steps (a mound, a terrace, a bank), never one spike; at most 24 m from the ground's own height.`);
  if (kinds.includes("paint")) out.push(
    `- {"op":"paint","cells":[[i,j,"<from>","<to>"],...]} paints the 3 m ground cell [i, j] (world 3i..3i+3, 3j..3j+3):
  from is its paint now (the "paint" layer above; "valley" where it names none), to is a ground paint from the table.`);
  if (kinds.includes("put")) out.push(
    `- {"op":"put","at":[x,y,z],"part":"<kit part>","rot":r} stands a kit part from the table on the cell at (its base
  on the ground y of that column); add "params" only to change a part's size. {"op":"lift","at":[x,y,z]} takes one
  away (the "pieces" layer above lists them). Parts are the finishing touches: lamps, benches, fences, trees, signs.`);
  if (kinds.includes("pour")) out.push(
    `- {"op":"pour","at":[x,y,z]} fills a hollow with still water from that cell: the Home floods the 3 m cells round it
  up to just under the lowest rim. Dig the hollow first with land (lower the inner vertices, keep the rim), then pour
  into its lowest cell. A pour that would run into the river, a protected area or past 2,048 cells is refused.`);
  if (kinds.includes("drain")) out.push(
    `- {"op":"drain","cells":[[i,j,level_cm],...]} empties the player's water in 3 m cell [i, j]; level_cm is its level now.`);
  if (kinds.includes("path")) out.push(
    `- {"op":"path","id":n,"pts":[[x_cm,z_cm],...],"width_cm":w,"paint":"<p>"} lays a path draped on the ground through
  2-64 control points in world cm (x*100, z*100), each 100-4800 cm from the last; width_cm 150-800; paint one of dirt,
  sand, stone, rock_warm, grass_dry, plank; id a new number no path in the "paths" layer above has.` +
    (kinds.includes("unpath") ? ` {"op":"unpath",...} removes a path: write it whole, as that layer lists it.` : ""));
  if (kinds.includes("plant")) out.push(
    `- {"op":"plant","cells":[[i,j,"<from>","<to>"],...]} sets the growth of 3 m cell [i, j]: meadow, flowers, tall_grass,
  or valley (the ground's own); from is its growth now ("valley" where the "plants" layer names none). Trees and bushes
  are put ops of the parts tree and bush.`);
  if (!out.length) return "";
  const examples: string[] = [];
  if (kinds.includes("land") && kinds.includes("pour")) examples.push(
    `A pond on flat ground at y 10 (1000 cm) over the cells x 99..107, z 48..56: lower the 4 inner vertices, then pour.
{"op":"land","verts":[[34,17,850],[35,17,850],[34,18,850],[35,18,850]]}
{"op":"pour","at":[103,8,52]}`);
  if (kinds.includes("path")) examples.push(
    `A dirt path 2.5 m wide from a door at (102, 55) to a well at (120, 70), bending once:
{"op":"path","id":1,"pts":[[10250,5550],[11000,6400],[12050,7050]],"width_cm":250,"paint":"dirt"}`);
  return ["More operations the Home takes here:", ...out, ...(examples.length ? ["Worked examples:", ...examples] : [])].join("\n");
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
