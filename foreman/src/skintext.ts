// H1h of 25 Nov (lane G1's v0.1.11): when a change's sentences about the game's text (title, tagline, names, commentary)
// went to the skin's owner (coreowner.ts skinSplit), the package the change was routed to takes only the rest. The skin's
// part is a change request of the Foreman's that names the person's request by its seq and quotes the moved words; the
// log's fold reads it, so the package's change list (what its builder is asked) never carries the skin's words.
import { FOREMAN_NOTE } from "./conduct.js";

/** The start of the Foreman's change request for the skin's part of change request `seq`. */
export const skinPartHead = (seq: number): string => `${FOREMAN_NOTE}the game's text from change request ${seq}, `;

/** The skin's part of a change request, as its owner is asked for it. */
export const skinPartText = (seq: number, why: string, words: string): string => `${skinPartHead(seq)}${why}: "${words}"`;

/** The words of change request `c` that its package takes: without the part the Foreman sent to the skin's owner. */
export function ownWords(changes: readonly { text: string }[], c: { seq: number; text: string }): string {
  const part = changes.find((x) => x.text.startsWith(skinPartHead(c.seq)));
  if (part === undefined) return c.text;
  const words = part.text.slice(part.text.lastIndexOf(': "') + 3, -1);
  return words !== "" && c.text.includes(words) ? c.text.replace(words, "").replace(/\s+/g, " ").trim() : c.text;
}
