import fs from "node:fs";
import path from "node:path";
import { randomUUID } from "node:crypto";
import { schemaErrors } from "./builder/json.js";
import type { Builder } from "./builder/types.js";
import { generate, type GenerateOptions } from "./designer.js";
import { UsageError } from "./cli_args.js";
import { PKG_ROOT, REPO_ROOT } from "./paths.js";

type Point = [number, number];
interface Ask {
  sentence: string;
  card?: string;
  answers: Record<string, string>;
  footprint: { size_m: Point; height_m: number; shape: string; stands?: boolean };
  radius: number;
  candidates?: { id: string; at: Point; score: number; facts: string[] }[];
  village: {
    plots: { id: string; label: string; kind: string; at: Point; r: number }[];
    road: Point[]; road_half_m: number; river?: { path: Point[]; half_m: number };
    bounds: [number, number, number, number];
  };
}
interface Proposal { candidate?: string; at: Point; yaw_deg: number; reason: string }

const num = { type: "number" }, positive = { type: "number", exclusiveMinimum: 0 };
const words = { type: "string", pattern: "\\S" };
const tuple = (n: number, items = num) => ({ type: "array", minItems: n, maxItems: n, items });
const point = tuple(2), line = { type: "array", minItems: 2, items: point };
const obj = (properties: Record<string, object>, optional: string[] = []) => ({
  type: "object", properties, required: Object.keys(properties).filter(k => !optional.includes(k)), additionalProperties: false,
});
const askSchema = obj({
  schema: { const: "tl.place-ask/1" }, sentence: words, card: { type: "string", pattern: "^card\\.[a-z][a-z0-9_]*$" },
  answers: { type: "object", propertyNames: { pattern: "^[a-z][a-z0-9_]*$" }, additionalProperties: { type: "string", pattern: "^[a-z0-9_]+$" } },
  footprint: obj({ size_m: tuple(2, positive), height_m: positive, shape: { enum: ["rink","pitch","court","track","slalom","course","arena","yard"] }, stands: { type: "boolean" } }, ["stands"]),
  radius: { type: "number", minimum: 12 },
  candidates: { type: "array", minItems: 1, maxItems: 12, items: obj({
    id: { type: "string", pattern: "^[A-Z]$" }, at: point, score: { type: "number", minimum: 0, maximum: 100 },
    facts: { type: "array", minItems: 1, items: words },
  }) },
  village: obj({ plots: { type: "array", items: obj({ id: words, label: words, kind: words, at: point, r: positive }) },
    road: line, road_half_m: positive, river: obj({ path: line, half_m: positive }), bounds: tuple(4) }, ["river"]),
}, ["card", "candidates"]);

function readAsk(file: string): Ask {
  let value: unknown;
  try {
    value = JSON.parse(fs.readFileSync(file, "utf8"), (_, v: unknown) => {
      if (typeof v === "number" && !Number.isFinite(v)) throw new Error("non-finite number");
      return v;
    });
  } catch (e) { throw new UsageError("--in: " + (e as Error).message); }
  const problems = schemaErrors(askSchema, value);
  if (problems.length) throw new UsageError("--in: " + problems.join(", "));
  const ask = value as Ask, [x0, z0, x1, z1] = ask.village.bounds;
  if (x0 >= x1 || z0 >= z1) throw new UsageError("--in: village.bounds must have positive width and depth");
  const ids = ask.candidates?.map(c => c.id) ?? [];
  if (new Set(ids).size !== ids.length) throw new UsageError("--in: candidate ids must be unique");
  return ask;
}

function playerWords(ask: Ask): string {
  const engine = process.env.TL_ENGINE_DIR || path.join(REPO_ROOT, "engine");
  const recipe = ask.card ? path.join(engine, "cards", ask.card.slice(5) + ".json") : path.join(engine, "ui/interview/none.json");
  type Question = { key: string; options: { id: string; say: string }[] };
  let questions: Question[] = [];
  if (fs.existsSync(recipe)) {
    const doc = JSON.parse(fs.readFileSync(recipe, "utf8"));
    questions = (doc.interview ?? doc).questions ?? [];
  }
  const answers = Object.entries(ask.answers).map(([key, id]) => {
    const option = questions.find(q => q.key === key)?.options.find(o => o.id === id);
    return key.replaceAll("_", " ") + " — " + (option?.say ?? id.replaceAll("_", " "));
  });
  return [ask.sentence, ...answers].join("\n");
}

function ideaText(ask: Ask, words: string): string {
  const fp = ask.footprint;
  return [words, [fp.shape, fp.size_m.join(" × ") + " m", fp.height_m + " m high",
    ask.radius + " m ring", ...(fp.stands ? ["with stands"] : [])].join(", ")].join("\n");
}

export async function placeCommand(input: string | undefined, output: string | undefined, builderFor: () => Builder, opts: GenerateOptions): Promise<number> {
  if (!input || !output || path.resolve(input) === path.resolve(output)) throw new UsageError("place needs distinct --in and --out files");
  const ask = readAsk(input), village = ask.village;
  const lines = ["Plot | Kind | Centre (x,z) m | Radius m",
    ...village.plots.map(p => [p.label, p.kind, p.at.join(","), p.r].join(" | ")),
    "Bounds (x0,z0,x1,z1): " + village.bounds.join(","),
    "Road: " + JSON.stringify(village.road) + ", half width " + village.road_half_m + " m"];
  if (village.river) lines.push("River: " + JSON.stringify(village.river.path) + ", half width " + village.river.half_m + " m");
  const candidates = ask.candidates?.map(c => [c.id, c.at.join(","), c.score, c.facts.join(" · ")].join(" | "));
  const table = candidates ? ["Candidate | Centre (x,z) m | Score | Measured facts", ...candidates].join("\n") : "No measured candidates supplied.";
  const read = (f: string) => fs.readFileSync(path.join(PKG_ROOT, "prompts", f), "utf8");
  const builder = builderFor(), schema = "tl.place-answer/1";
  let answer: Record<string, unknown>;
  try {
    const words = playerWords(ask);
    const result = await generate<{ proposals: Proposal[] }>(builder, "placer", read("placer.md"),
      { idea: ideaText(ask, words), village: lines.join("\n"), candidates: table }, JSON.parse(read("place.schema.json")), value => {
        const proposals = (value as { proposals: Proposal[] }).proposals;
        const [x0, z0, x1, z1] = village.bounds;
        return proposals.flatMap(({ candidate, at: [x, z], reason }, i) => {
          if (candidate !== undefined) {
            const measured = ask.candidates?.find(c => c.id === candidate);
            if (!measured) return [`Unknown candidate ${candidate}. Use an id from the table.`];
            if (Math.hypot(x - measured.at[0], z - measured.at[1]) > 0.5) return [`Use the measured centre for candidate ${candidate}: ${measured.at.join(",")}.`];
            const numbers = (text: string) => (text.match(/-?\d+(?:\.\d+)?/g) ?? []).map(Number);
            const supplied = new Set(numbers([words, ...measured.facts, measured.score].join(" ")));
            if (numbers(reason).some(n => !supplied.has(n))) return [`Use only numbers from candidate ${candidate}'s facts or the player's answers.`];
          }
          if (!Number.isFinite(x) || !Number.isFinite(z) || x < x0 || x > x1 || z < z0 || z > z1) return ["Centre outside village bounds"];
          if (proposals.slice(0, i).some(p => Math.hypot(x - p.at[0], z - p.at[1]) < 5)) return ["Centres must be at least 5 m apart"];
          return [];
        });
      }, opts);
    if (result.ok) {
      const calls = result.calls.map(c => c.result);
      answer = { schema, proposals: result.value.proposals, adapter: builder.name, model: calls.at(-1)?.model ?? opts.model ?? builder.name,
        durationMs: calls.reduce((sum, c) => sum + c.durationMs, 0) };
      for (const k of ["tokensIn", "tokensOut"] as const) {
        if (calls.some(c => c[k] !== undefined)) answer[k] = calls.reduce((sum, c) => sum + (c[k] ?? 0), 0);
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
