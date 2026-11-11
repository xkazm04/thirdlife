// Checker registry: rules in devx/arch.rules.json name one of these. A checker is (io, rule) -> {findings, notes?}.
// finding = {file, line?, key, message}; `key` is what the baseline grandfathers.
import { moduleWalls, classPrefixes } from "./walls.mjs";
import { uidOrphans, sizeRatchet, scopeClaims } from "./hygiene.mjs";
import { verbsContract, schemaVersions } from "./contracts.mjs";
import { apiIndexFresh } from "./apiindex.mjs";
import { apiContract } from "./apicontract.mjs";

export const CHECKERS = { moduleWalls, classPrefixes, uidOrphans, sizeRatchet, scopeClaims, verbsContract, schemaVersions, apiIndexFresh, apiContract };
