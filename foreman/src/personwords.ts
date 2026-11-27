// D27 lane T3, item 38 (lane J2b's Arsenal copy, events 1278-1285): the Foreman carried harbour's NOT DONE to the
// cartridge with the catalog's candidate rows, and the cartridge's pre-check read that whole Foreman text as the person's:
// one candidate row said "easier to land (Cage, Bruisers 2)", so unseenChange took it for "make it easier" and paused the
// job on "should the bots be weaker still?", which the person never asked. A question to the person comes only from the
// person's words: for a Foreman request (a hand-off, the rivals' part, the play part) the words judged are the person's
// own asks of the change in flight, never the Foreman's text around them. Pure.
import type { JobEvent } from "./events.js";
import { FOREMAN_NOTE } from "./conduct.js";
import { askedChange } from "./boundlift.js";

/**
 * The person's words behind a change request `text`: the text itself when it is the person's; for a Foreman request,
 * every ask of the person since the last promotion (askedChange); "" when there is none (a Foreman request outside a
 * person's change, which no question may come from).
 */
export function personWords(events: readonly JobEvent[] | undefined, text: string): string {
  if (!text.startsWith(FOREMAN_NOTE)) return text;
  return askedChange(events)?.text ?? "";
}
