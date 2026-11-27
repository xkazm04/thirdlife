// D27b items 28 and 31 (lane T2-editor, juice day of 27 Nov; J2nd's court and biplane copies).
//   28: court_exchange r14 wrote "RULE: none added. The odds of the throw, the catch and the contest are as before"
//       (event 1525), and the v0.1.8 card listed it as "unasked rule: none added ...": a line that says no rule was
//       added is not a rule.
//   31: first_flight r? wrote two RULE: lines that change play (in the lesson Vesper never rolls off my harpoon; her
//       cooldown is held while my energy is below a roll) for a sentence about messages and the lesson (event 994); the
//       Foreman judged the change "view or screen only" (event 1000) and skill_spread 0.04 went unjudged and untold. A
//       builder's RULE: line makes the change a play change.
// No imports from the Foreman's other modules: boundlift.ts and fastchange.ts both read these.
import type { JobEvent } from "./events.js";

/** A builder line that says it added no rule ("RULE: none added", "RULE: none", "RULE: no new rule"). */
export const RULE_NONE = /^RULE:\s*(none\b|no (new |other |extra )?rules?\b|nothing (new )?added\b|n\/a\b)/i;

/** A builder's `RULE:` line that names a rule (list marks off; never "RULE: none"). */
export function isRuleLine(line: string): boolean {
  const l = line.replace(/^\s*[-*]\s*/, "").trim();
  return /^RULE:/i.test(l) && !RULE_NONE.test(l) && !/^RULE:\s*not (done|made|built)\b/i.test(l);
}

/** The builders' RULE: lines (their own notes, not the Foreman's) after event `since`. */
export function ruleLinesSince(events: readonly JobEvent[] | undefined, since: number): string[] {
  return (events ?? []).flatMap((e) => (e.type === "note" && e.seq > since && !e.text.startsWith("[foreman] ") ? e.text.split(/\r?\n/).map((l) => l.replace(/^\s*[-*]\s*/, "").trim()).filter(isRuleLine) : []));
}
