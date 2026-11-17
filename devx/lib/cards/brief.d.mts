// Types of brief.mjs for the Foreman (foreman/src/cards.ts imports the .mjs itself; this file only types it).
export interface Card {
  schema: string;
  id: string;
  version: string;
  title: string;
  summary: string;
  applies_when: string[];
  not_when?: string[];
  seed?: string;
  pack?: string;
  capabilities: string[];
  kit_parts: string[];
  swap_parts?: string[];
  api: string[];
  rules_keys: string[];
  data_files: { file: string; role: string }[];
  do: string[];
  dont: string[];
  bot: { template: string; plays_by: string; wins_when: string };
  acceptance: string[];
  variants?: { ask: string; change: string }[];
}
export function cardExample(card: Card): string;
export function cardBrief(card: Card): string;
export function cardBriefText(card: Card): string;
export function cardListLine(card: Card): string;
