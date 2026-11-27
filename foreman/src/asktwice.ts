// H1d of 25 Nov (lane G1's change 3, events 288, 316, 324: `harbour` could not make a change and asked the person the same
// thing after every answer, three times, four builder runs, 13.5 min, 3.3 M tokens; the second and third questions were
// JSON). A package that asks again after the person has answered it in this change does not get to ask a third time:
//   - when the change's words are play on a core game and another package owns the cartridge, the change goes back to
//     routing: a change request for that package, carrying the person's request, the question and the answer;
//   - otherwise the person is told plainly that this package cannot make it, and the files merged before stay.
// Questions are a person's words: a JSON object in one is replaced by words (plainQuestion).
import type { JobEvent } from "./events.js";
import type { GateHost } from "./p10gate.js";
import type { CoreRoute } from "./coreroute.js";
import { coreChangeOwner } from "./coreowner.js";
import { FOREMAN_NOTE, clip } from "./conduct.js";

/** The start of the Foreman's note (after FOREMAN_NOTE) when a package asked again after an answer. */
export const ASKED_AGAIN = "asked again after your answer";

/** The person's last answer to `id` in this change, given before the builder run at `runAt`; undefined when none. */
export function answeredThisChange(events: readonly JobEvent[], id: string, runAt: number): { question: string; answer: string } | undefined {
  // only inside a change (a re-opened package): a first build's builder may ask what it needs, one question at a time
  const reopenAt = [...events].reverse().find((e) => e.type === "reopened" && e.package === id)?.seq;
  if (reopenAt === undefined) return undefined;
  let question: string | undefined;
  let last: { question: string; answer: string } | undefined;
  for (const e of events) {
    if (e.seq <= reopenAt || e.seq >= runAt) continue;
    if (e.type === "question" && e.package === id) question = e.text;
    if (e.type === "answer" && e.package === id && question !== undefined && e.by !== "foreman") last = { question, answer: e.text }; // D27b item 26: the Foreman's own answer is not the person's
  }
  return last;
}

/** A question in a person's words: a JSON object in it becomes "(the settings it names above)", backticks go. */
export function plainQuestion(q: string): string {
  return q.replace(/`?\{[^{}]*"[^{}]*\}`?/g, "(the settings it names above)").replace(/`([^`]+)`/g, "$1").replace(/\s+/g, " ").trim();
}

/**
 * The package asked again after an answer: route the change on, or say plainly it cannot be made here. Appends the
 * events; returns the words said to the person.
 */
export function askedAgain(h: Pick<GateHost, "s" | "append" | "pkg">, core: CoreRoute | undefined, id: string, round: number, question: string, before: { question: string; answer: string }): string {
  const request = (h.pkg(id).changes ?? []).at(-1) ?? "";
  const to = request !== "" ? coreChangeOwner(h.s.plan, core, id, request).owner : id;
  const qa = `It asked "${clip(plainQuestion(before.question), 300)}", you answered "${clip(before.answer, 200)}", and it asks again ("${clip(plainQuestion(question), 300)}")`;
  if (to !== id && h.s.packages[to] !== undefined) {
    const said = `${id} cannot make this change: ${qa}. The change goes to ${to}, which owns the game's settings, with your request and your answer; ${id} keeps the files it merged before.`;
    h.append({ type: "note", package: id, round, text: `${FOREMAN_NOTE}${ASKED_AGAIN}: ${said}` });
    h.append({ type: "package_state", package: id, state: "promoted", round, detail: clip(`re-opened, but it asked again after an answer; the change goes to ${to}; the files merged before stay in pack/`, 500) });
    h.append({ type: "change_requested", text: `${request}\n(${id} could not make it and asked: "${clip(plainQuestion(before.question), 400)}"; the person answered: "${clip(before.answer, 300)}")`, package: to });
    return said;
  }
  const said = `${id} cannot make this change: ${qa}. It is not asked a third time: the change was NOT made, and the files ${id} merged before stay. Say it again in other words, or name what matters most.`;
  h.append({ type: "note", package: id, round, text: `${FOREMAN_NOTE}${ASKED_AGAIN}: ${said}` });
  h.append({ type: "package_state", package: id, state: "promoted", round, detail: clip(`re-opened, but it asked again after an answer: the change was NOT made; the files merged before stay in pack/`, 500) });
  return said;
}
