// Pulling a JSON value out of a model's answer, and checking it against a schema. Shared by every adapter.
import { Ajv2020 } from "ajv/dist/2020.js";

export type Extracted = { ok: true; value: unknown } | { ok: false; looksCutOff: boolean; reason: string };

/** Extraction ladder: the whole text, then a fenced block, then the first balanced object or array. */
export function extractJson(text: string): Extracted {
  const t = text.trim();
  if (t.length === 0) return { ok: false, looksCutOff: false, reason: "empty answer" };
  try {
    return { ok: true, value: JSON.parse(t) };
  } catch {
    /* next rung */
  }
  const fence = /```(?:json)?\s*\n([\s\S]*?)\n```/i.exec(t);
  if (fence?.[1]) {
    try {
      return { ok: true, value: JSON.parse(fence[1]) };
    } catch {
      /* next rung */
    }
  }
  const start = t.search(/[[{]/);
  if (start === -1) return { ok: false, looksCutOff: false, reason: "no JSON value in the answer" };
  let depth = 0;
  let inStr = false;
  let esc = false;
  for (let i = start; i < t.length; i++) {
    const c = t[i];
    if (inStr) {
      if (esc) esc = false;
      else if (c === "\\") esc = true;
      else if (c === '"') inStr = false;
      continue;
    }
    if (c === '"') inStr = true;
    else if (c === "{" || c === "[") depth += 1;
    else if (c === "}" || c === "]") {
      depth -= 1;
      if (depth === 0) {
        try {
          return { ok: true, value: JSON.parse(t.slice(start, i + 1)) };
        } catch (e) {
          return { ok: false, looksCutOff: false, reason: `JSON does not parse: ${(e as Error).message}` };
        }
      }
    }
  }
  // Brackets never closed: the answer stops in the middle of a value.
  return { ok: false, looksCutOff: true, reason: "JSON value is not closed: the answer was cut off" };
}

const ajv = new Ajv2020({ allErrors: true, strict: false, allowUnionTypes: true });
const cache = new WeakMap<object, ReturnType<typeof ajv.compile>>();

/** Returns the list of violations; empty means valid. A schema that does not compile is itself a violation. */
export function schemaErrors(schema: object, value: unknown): string[] {
  let validate = cache.get(schema);
  if (!validate) {
    try {
      const { $id: _id, ...rest } = schema as { $id?: string };
      validate = ajv.compile(rest);
    } catch (e) {
      return [`schema does not compile: ${(e as Error).message}`];
    }
    cache.set(schema, validate);
  }
  if (validate(value)) return [];
  return (validate.errors ?? []).map((e) => {
    const extra =
      e.keyword === "additionalProperties"
        ? ` "${String((e.params as { additionalProperty?: string }).additionalProperty)}"`
        : "";
    return `${e.instancePath || "/"} ${e.message ?? "invalid"}${extra}`;
  });
}
