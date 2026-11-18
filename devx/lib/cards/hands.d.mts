// Types of hands.mjs for the Foreman (foreman/src/handcheck.ts imports the .mjs itself; this file only types it).
export interface HandBound {
  wins_min?: number;
  wins_max?: number;
}
export function handTest(hand: string): string;
export function wilson(k: number, n: number): { lo: number; hi: number };
export function boundText(c: HandBound): string;
export function judgeHand(c: HandBound, seeds: number, completed: number, wins: number, unread?: number): { ok: boolean; why: string };
