// H1g of 25 Nov (lane G4: the camera card kept with "keep the camera steady behind me like a TV game, no swinging"; the
// game's view slid after the player so the hoop crossed the frame within seconds, and only the critic's eye could say so).
// The runner now measures the active camera over every bot run (engine/kernel/runner/camyaw.gd: metrics
// camera_yaw_p90_dps, the degrees it turns in a second, and camera_move_p90_mps, the metres it travels in a second, p90
// over the run's one second windows). A person's note on a kept or chosen card that asks for a steady camera is checked
// against those figures by the Foreman itself; a camera over the bounds is a "person's note not kept" line, which makes
// the look NOT ok (quality.ts notesKept) whatever the critic scored.
import fs from "node:fs";
import type { JobEvent } from "./events.js";
import type { GateHost } from "./p10gate.js";
import { NOTE_NOT_KEPT } from "./phases.js";

/** A note that asks for a steady camera (with a word for the camera or the view in the note or on its card). */
export const STEADY = /\b(steady|still|stable|fixed|locked|no swing\w*|not swing\w*|stop\w* (moving|turning|swinging)|(doesn'?t|does not|never) (move|turn|swing)|tv game|broadcast)\b/i;
const CAMERA = /\b(camera|cam|view|shot|angle)\b/i;

/**
 * The bounds of "steady", in the runner's figures. A broadcast camera pans to keep play in frame: some turning, little
 * travel. Read from the figures of the house hockey's cameras (stated in REPORT H1g) and G4's sliding view.
 */
export const STEADY_YAW_DPS = 15;
export const STEADY_MOVE_MPS = 1.5;

interface CamFigure {
  test: string;
  yaw: number;
  move: number;
}

/** The newest passing bot run of each test that reports the camera figures. */
export function cameraFigures(h: Pick<GateHost, "dir">, events: readonly JobEvent[]): CamFigure[] {
  const by = new Map<string, CamFigure>();
  for (const e of events) {
    if (e.type !== "verify" || e.verb !== "bot" || !e.ok) continue;
    try {
      const r = JSON.parse(fs.readFileSync(h.dir(...e.report.split("/")), "utf8")) as { metrics?: Record<string, unknown>; bot?: { test?: unknown } };
      const yaw = r.metrics?.["camera_yaw_p90_dps"];
      const move = r.metrics?.["camera_move_p90_mps"];
      if (typeof r.bot?.test === "string" && typeof yaw === "number" && typeof move === "number") by.set(r.bot.test, { test: r.bot.test, yaw, move });
    } catch {
      /* unreadable: not a figure */
    }
  }
  return [...by.values()];
}

/** The person's steady-camera notes on kept or chosen cards. */
export function steadyNotes(s: Pick<GateHost["s"], "brief" | "reactions">): string[] {
  const out: string[] = [];
  for (const a of s.brief?.aspects ?? []) {
    const r = s.reactions[a.id];
    if (r === undefined || r.choice === "drop" || r.note === undefined) continue;
    if (STEADY.test(r.note) && (CAMERA.test(r.note) || CAMERA.test(`${a.title} ${a.line} ${a.id}`))) out.push(r.note);
  }
  return out;
}

/**
 * The lines for each steady-camera note the measured camera does not keep (the run that moves it most); [] when no
 * such note, no figure (a pack without a camera, or a runner before H1g), or the camera is within the bounds.
 */
export function cameraNotesMissed(h: Pick<GateHost, "dir" | "events" | "s">): string[] {
  const notes = steadyNotes(h.s);
  if (notes.length === 0) return [];
  const figs = cameraFigures(h, h.events);
  const worst = figs.filter((f) => f.yaw > STEADY_YAW_DPS || f.move > STEADY_MOVE_MPS).sort((a, b) => b.move / STEADY_MOVE_MPS + b.yaw / STEADY_YAW_DPS - (a.move / STEADY_MOVE_MPS + a.yaw / STEADY_YAW_DPS))[0];
  if (worst === undefined) return [];
  const what = [worst.yaw > STEADY_YAW_DPS ? `turns ${worst.yaw} degrees a second` : "", worst.move > STEADY_MOVE_MPS ? `travels ${worst.move} m a second` : ""].filter(Boolean).join(" and ");
  return notes.map((n) => `${NOTE_NOT_KEPT} "${n}": measured, the game's camera ${what} (p90 over ${worst.test}'s run, the runner's camera figures; steady is at most ${STEADY_YAW_DPS} degrees and ${STEADY_MOVE_MPS} m a second). Keep it still behind the play: no follow that slides with the player, no swing`);
}
