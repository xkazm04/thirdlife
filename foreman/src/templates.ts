// N4 of 22 Nov (GAME-QUALITY.md v2 section 11): genre templates. The owner, 21 Nov: "there are hundreds of duel games
// (souls like, for honor duels) with well known game design paths we can mimic". Every core loop copies ONE proven
// design: the concept step names it (`concept.template`), the design step copies its move frames exactly (a verb's
// `move`), and the design step, the Planner and the builders read the template's research excerpt from docs/research,
// the relevant one only. Pure apart from reading the research files (a missing file gives a one-line note).
// N4 loop round 1 (22 Nov, 01:00): the owner's extension makes engine/packs/duel and engine/packs/hockey the reference
// games. A template now names its HOUSE GAME: the pack is the reference implementation, its README's rules are what the
// design step and the Planner copy, its files are what the builders read (every job's ref/packs/<pack>/ holds a copy),
// and its own data (the duel's data/moves.json) is the frame table the Foreman checks against: the house numbers are
// tuned on the kernel, so where they differ from the research, the house game wins.
// N2 of 23 Nov (round 5): the owner called both house games slop, and N1's teardowns showed why (the bodies, the
// timing, the scale, the camera, the puck). A house game is now a WORKING BASE for the API (its files show how the
// kernel is driven; the frame check and the house compare stay as a floor), NOT the quality bar until a person has
// accepted it. The bar is the template's `bar`: the reference game's numbers (docs/design/CASES.md) and the teardown's
// top ten as "do not copy" lines (docs/research/<kind>-teardown/TEARDOWN.md).
import fs from "node:fs";
import path from "node:path";
import { REPO_ROOT, stripBom } from "./paths.js";
import type { Concept, ConceptTemplate, DesignDoc, TemplateId } from "./room_wire.js";
import { RINK_ROUTE, coreBriefProblems, coreExcerpt, type CoreRoute } from "./coreroute.js"; // E3 of 24 Nov: a game on a core

/** One move of a template's frame table: the frames a verb that names it must carry (active absent = held, not checked). */
export interface TemplateMove {
  anticipation_f: number;
  active_f?: number;
  recovery_f: number;
  clip: string;
  kind: "attack" | "defence" | "other";
}

/** A tofu metric a template adds (GAME-QUALITY.md section 12): passes when min <= value <= max. */
export interface TemplateMetric {
  id: string;
  min?: number;
  max?: number;
  item: string;
}

export interface Template {
  id: Exclude<TemplateId, "own">;
  title: string;
  /** The sentence words that make this the template (a melee fight is a duel). */
  sentence: RegExp;
  reference: string;
  /** The research file, relative to the repository. */
  file: string;
  /** Headings ("## 2.", "### 6.3") of the file the design step and the Planner read; the builders read `builder`. */
  design: string[];
  builder: string[];
  /** What `concept.template.copies` must name, each with a pattern that finds it. */
  must: { what: string; re: RegExp }[];
  moves: Record<string, TemplateMove>;
  /** At least this many verbs name a move; one of them an attack and one a defence when > 0. */
  movesMin: number;
  metrics: TemplateMetric[];
  /** The recipe card that is the default for this template when the job offers it. */
  card?: string;
  /** N4 loop round 16: the moment kinds a look films first (a bot's `moments` keys or their prefixes), in order. */
  filmFirst?: string[];
  /** The house game: a working base on this engine (N4 loop round 1; N2 round 5: not the quality bar). */
  house?: House;
  /** N2 round 5: the quality bar: the reference game's numbers and the teardown's "do not copy" lines. */
  bar?: Bar;
  /**
   * E3 of 24 Nov: the game is a cartridge on this core over its base (coreroute.ts), never a hand-built simulation.
   * The design names the cartridge keys and skin fields it changes; the plan starts from the base; the looks run the
   * core's measured check beside the house game's.
   */
  core?: CoreRoute;
}

/** The quality bar of a template (docs/design/CASES.md, docs/research/<kind>-teardown/TEARDOWN.md). */
export interface Bar {
  /** The teardown that set the house game beside the reference games. */
  teardown: string;
  /** The reference game's numbers a design starts from (each with its source). */
  numbers: string[];
  /** The teardown's top ten: what the house game does that a design must NOT copy. */
  dont: string[];
  /**
   * N2 round 6 (the Director's ruling, 23 Nov): the slowest wind-up (anticipation_f) a copied move may carry, by move id.
   * A copied move carries at least the house game's wind-up and at most this; faster than the house game is refused.
   */
  maxAnticipation?: Record<string, number>;
}

/** A house game (engine/packs/<pack>): what to copy and where. */
export interface House {
  pack: string;
  game: string;
  /** README headings the design step and the Planner read whole. */
  readme: string[];
  /** The files a builder reads, with what each holds. */
  files: { file: string; role: string }[];
  /** The pack's own frame table (a moves.json in the shape of engine/packs/duel/data/moves.json), when it has one. */
  moves?: string;
  /** Rules of the house game a design must keep, each with a pattern over the brief's rules and controls text. */
  keeps?: { what: string; re: RegExp }[];
  /**
   * N4 loop round 6: the house game's own numbers a builder copies, read live from the pack (they move as the game is
   * tuned): what each is, and how to read it from the pack directory (undefined when the file or key is gone).
   */
  numbers?: { what: string; read: (packDir: string) => string | undefined }[];
}

const readJsonKey = (packDir: string, file: string, key: string): string | undefined => {
  try {
    const v = (JSON.parse(stripBom(fs.readFileSync(path.join(packDir, ...file.split("/")), "utf8"))) as Record<string, unknown>)[key];
    return v === undefined ? undefined : JSON.stringify(v);
  } catch {
    return undefined;
  }
};
/** Some keys of one object of a JSON file, as JSON (undefined when the file or the object is gone). */
const readJsonKeys = (packDir: string, file: string, key: string, keys: string[]): string | undefined => {
  try {
    const v = (JSON.parse(stripBom(fs.readFileSync(path.join(packDir, ...file.split("/")), "utf8"))) as Record<string, unknown>)[key];
    if (v === null || typeof v !== "object") return undefined;
    return JSON.stringify(Object.fromEntries(keys.filter((k) => k in (v as object)).map((k) => [k, (v as Record<string, unknown>)[k]])));
  } catch {
    return undefined;
  }
};
const rivalBuilds = (packDir: string): string | undefined => {
  try {
    const r = (JSON.parse(stripBom(fs.readFileSync(path.join(packDir, "data", "rivals.json"), "utf8"))) as { rivals?: Record<string, { name?: string; scale?: number; arms?: string[]; colors?: Record<string, string> }> }).rivals;
    if (r === undefined) return undefined;
    return Object.values(r).map((v) => `${v.name ?? "?"} scale ${v.scale ?? 1} gear ${(v.arms ?? []).join("+")} top ${v.colors?.["top"] ?? "?"}`).join("; ");
  } catch {
    return undefined;
  }
};
const readConst = (packDir: string, file: string, name: string): string | undefined => {
  try {
    return new RegExp(`const ${name}\\s*(?::\\s*\\w+)?\\s*=\\s*([^\\s#]+)`).exec(fs.readFileSync(path.join(packDir, ...file.split("/")), "utf8"))?.[1];
  } catch {
    return undefined;
  }
};

export const TEMPLATES: Template[] = [
  {
    id: "duel",
    title: "a melee duel",
    sentence: /\b(fight|fighting|fighter|duel|sword|swords|gladiator|gladiators|colosseum|coliseum|boxing|boxer|knight|knights|samurai|brawl|brawler|fencing|melee)\b/i,
    reference: "Dark Souls / Sekiro / For Honor, as docs/research/DUEL-PLAYBOOK.md",
    file: "docs/research/DUEL-PLAYBOOK.md",
    design: ["## 1.", "## 2.", "## 3.", "## 4.", "## 5.", "## 6."],
    builder: ["## 2.", "## 6."],
    must: [
      { what: "the state machine (DUEL-PLAYBOOK 6.4)", re: /state machine|states?\b.*(windup|recovery|hitstun|blockstun)/i },
      { what: "the mutual reactions: every contact changes both fighters (DUEL-PLAYBOOK 2 and 6.3)", re: /mutual|both fighters|both bodies|contact (results|table)|every contact/i },
      { what: "the three rival archetypes by their defence (DUEL-PLAYBOOK 6.7: the Wall absorbs, the Duelist parries, the Dancer avoids)", re: /archetype|\bwall\b.*duelist|duelist|dancer|absorb.*parr|parr.*avoid/i },
    ],
    moves: {
      light: { anticipation_f: 18, active_f: 4, recovery_f: 16, clip: "strike", kind: "attack" },
      heavy: { anticipation_f: 32, active_f: 5, recovery_f: 28, clip: "strike_heavy", kind: "attack" },
      charged: { anticipation_f: 54, active_f: 6, recovery_f: 36, clip: "strike_heavy", kind: "attack" },
      bash: { anticipation_f: 14, active_f: 6, recovery_f: 24, clip: "body_check", kind: "attack" },
      block: { anticipation_f: 4, recovery_f: 6, clip: "block", kind: "defence" },
      parry: { anticipation_f: 1, active_f: 12, recovery_f: 20, clip: "block", kind: "defence" },
      roll: { anticipation_f: 3, active_f: 18, recovery_f: 15, clip: "roll", kind: "defence" },
      dodge: { anticipation_f: 2, active_f: 8, recovery_f: 12, clip: "dodge", kind: "defence" },
      taunt: { anticipation_f: 0, active_f: 0, recovery_f: 60, clip: "taunt", kind: "other" },
    },
    movesMin: 3,
    metrics: [
      { id: "contact_types", min: 3, item: "DUEL-PLAYBOOK 6.3: at least 3 kinds of contact met (hit, block, parry, bash, clash, whiff)" },
      { id: "one_sided_contacts", max: 0, item: "DUEL-PLAYBOOK acceptance: no contact leaves one fighter's state unchanged" },
    ],
    card: "card.duel",
    bar: {
      teardown: "docs/research/duel-teardown/TEARDOWN.md",
      maxAnticipation: { light: 30, heavy: 60 }, // For Honor: lights 400-500 ms (24-30 f), heavies 800-1000 ms (48-60 f)
      numbers: [
        "a rival's light winds up at least 24 frames of readable body, ideally 30; a heavy 48 to 60 (For Honor; CASES.md B18, B6)",
        "every dangerous rival action, chained follow-ups too, shows at least 20 frames of tell in the body: a person's reliable reaction (CASES.md B25)",
        "a parried heavy leaves the attacker open about 36 frames (a free light), a parried light about 54 (a free heavy) (For Honor, B17)",
        "a parry window of about 12 frames that shrinks when spammed (Sekiro, B20); roll i-frames about 28 with a punishable recovery (Elden Ring, B7)",
        "hit-stop on both bodies about 6 to 8 frames on a light, 12 to 16 on a heavy (Smash, Capcom; B27, B13)",
        "a rival attacks about every 2 to 3 seconds, with room between exchanges (B23); rounds of 45 to 90 seconds (our design call, test it by hand)",
        "two bars a fighter: vitality and posture (Sekiro, B21)",
        "the first rival waits until the player has blocked once, and cannot hurt him while he learns (our design call from For Honor's and Sekiro's tutorials; test it by hand)",
      ],
      dont: [
        "a wind-up that is a 3-frame pose of one generic clip stretched, with the intent written over the rival's head (HEAVY, BASH): the body tells, a colour on the weapon at most",
        "a tutorial that hits for real while it teaches and moves on when the player fails",
        "rounds over in 20 seconds (93 of 93 house rounds ended by a knockout at 18 to 24 s)",
        "threats that wind up in 12 frames (the house chains), under a person's reaction",
        "a dashboard: three bars a fighter, crowd meter, stars, rally, tags, cues, banners (big words mid-screen, apart from the score and the clock), a key strip, cause cards",
        "three rivals that are one fighter in three hats (one move set, three reaction speeds)",
        "toy figures with stick weapons and synthesised beeps; a light hit-stop (house 5 and 9)",
        "difficulty as a reaction dial with a cliff after the first rival",
        "a round that ends in a KO show and a cause card instead of a moment the player remembers",
        "loops that only add, judged by the lane that built them, never played by a person",
      ],
    },
    filmFirst: ["parr", "roll", "dodge", "down", "knock", "ko", "fall", "wall", "splat", "blocked_heavy", "heavy_block", "clash", "guard"],
    house: {
      pack: "duel",
      game: "game.duel",
      readme: ["## How to play", "## What you see", "## The rules", "## The rivals", "## Each rival reads by silhouette", "## What changed from the playbook"],
      files: [
        { file: "data/moves.json", role: "the frame table (6.2), the source of truth: windup / active / recovery, damage, stamina, poise, reach, arc, armour, and the [move frame, clip frame] map that stretches a fight clip over a readable wind-up" },
        { file: "data/contacts.json", role: "the contact table (6.3): hit-stop on both, the defender's stun and push, the attacker's recoil or rebound, the poise tiers, the pose each stun shows" },
        { file: "scripts/contact.gd", role: "the interaction matrix (6.5): which contact an active move makes against each defender state, and what it does to BOTH fighters" },
        { file: "scripts/feel.gd", role: "the one adapter over the kernel feel kit: TLHit.impact hit-stop on both, the six contact reactions, knockdown, pushbox, occluder fade, the rig clocks" },
        { file: "scripts/fighter.gd", role: "one fighter's state machine (6.4), the resources, the 8-frame buffer, the lock-on facing (the pack turns the body), the clip clocks" },
        { file: "scripts/brain.gd", role: "the rival's mind (6.6): sees only the player's animation react frames late, defends in its archetype's way, reads chains, never a string three times, a return window after each" },
        { file: "data/rivals.json", role: "the AI tiers and the three archetypes (Wall, Duelist, Dancer): hp, poise, defence weights, strings with fixed delays, phase 2" },
        { file: "scripts/show.gd", role: "HUD bars (health, stamina, posture), banners (PARRY!, WALL SPLAT!, mid-screen in big letters with an outline, never in the score line and never padded into a slab), cues, the three cameras" },
        { file: "gen/arms.gd", role: "the weapons (sword, rapier, mace, shield, twin blades) on the hand sockets and each rival's head and back gear (the Wall's bucket helm and pauldrons, the Duelist's plumed hat and cape, the Dancer's hood and ribbons) on the head and back sockets: a duel is fought with them from the first phase, and a rival reads by silhouette, never by colour" },
        { file: "tests/support/pilot.gd", role: "the bot that plays the player's side through a TLHand; tests/bot_contact_<type>.gd: one drill per contact, passing when BOTH fighters changed" },
      ],
      moves: "data/moves.json",
      keeps: [
        { what: "the lock-on: each fighter always faces his rival (the house game turns the body; facing never follows the walk), so the 120-degree guard holds while circling", re: /lock[- ]?on|always faces?|faces? (his|her|their|the) (rival|opponent|foe)|face each other/i },
        { what: "the camera over the shoulder, offset to the side, looking between the two fighters (its data/tuning.json `camera`, read below), over a ring wall low enough to see over", re: /shoulder|offset to the side|side[- ]on|between (the|both) fighters|between them/i },
      ],
      // Round 6: the three faults the critic named in the crazy proof -3 (a camera low behind the player, two bodies
      // pressed into one blob, both fighters frozen 55 frames) are numbers the house game already has.
      numbers: [
        { what: "the play camera (data/tuning.json `camera`, metres and degrees: raised and angled so both bodies show; never low behind the player)", read: (d) => readJsonKey(d, "data/tuning.json", "camera") },
        { what: "the pushbox per duellist at scale 1, in metres (scripts/feel.gd PUSHBOX, times the body radius / 0.3; TLHit.pushbox on both from the first frame): two bodies never read as one", read: (d) => readConst(d, "scripts/feel.gd", "PUSHBOX") },
        { what: "never idle (scripts/brain.gd last_action): a wind-up, an active or recovery frame, a roll, a dodge, a tell, a taunt, a block, a stun or closing in counts as acting; anything else past 120 frames is idle, so the mind presses, feints or repositions before that", read: () => "120 frames at most" },
        // Round 14: proofs -5 and -6 failed recoloured_rivals in their first look: the rival in the player's body with
        // another shirt. The house game's rivals differ in scale, arms and colours from the first round.
        { what: "the rival silhouettes (data/rivals.json `rivals`: scale, the hand weapons AND the head and back gear gen/arms.gd builds on the rig's head and back sockets, colours; the player is scale 1.0, a sword, his own hair): the first rival differs from the player in silhouette from the first phase (head gear, back gear, scale, weapon), never in colour alone. The sockets turn their axes (+X right, +Y back, +Z down): build the gear Y-up, face -Z, then turn it -90 degrees about X, as gen/arms.gd does", read: (d) => rivalBuilds(d) },
      ],
    },
  },
  {
    // E3 of 24-25 Nov: the owner, 24 Nov ~23:20: "although the hockey feel like thirdjam, ... game like this can be built
    // by user from the editor". A rink game is a cartridge on the rink core (thirdjam's sim and bots, compiled) over the
    // base engine/templates/rink_game (hokej made skinnable); the design changes data, never the simulation.
    id: "rink_sport",
    title: "a rink game with a puck on the rink core (a cartridge over thirdjam's match)",
    sentence: /\b(hockey|hokej|puck|rink|shinny|bandy|ringette)\b/i,
    reference: "thirdjam's match (the rink core) and its twelve mode cartridges, as engine/cores/rink and engine/packs/hokej",
    file: "engine/cores/rink/SNAPSHOT.md",
    design: [],
    builder: [],
    must: [
      { what: "thirdjam's match on the rink core, unchanged: its skating, puck, contact, bots, camera and keys (the core carries the feel)", re: /\bcore\b|thirdjam|unchanged|as it is/i },
      { what: "the cartridge keys the game changes (rink size, teams, rules, look) and the skin (title, team names, colours)", re: /cartridge|rink (size|length)|team size|a side|skin/i },
    ],
    moves: {},
    movesMin: 0,
    metrics: [],
    card: "card.rink_core",
    filmFirst: ["goal", "shot", "one_timer", "pass", "check", "hit"],
    house: {
      pack: "hokej",
      game: "game.hokej",
      readme: [],
      files: [
        { file: "scripts/main.gd", role: "the shell: opens the core with the cartridge data/match.json names (ctx.cores.open), steps it once a frame, returns ctx.cores.state()" },
        { file: "data/match.json", role: "which cartridge the match plays and the bots' level (rookie | pro | all_star)" },
        { file: "data/hockey.thirdlife.cartridge.json", role: "the Third Life cut: tj.cartridge/1 (rink, teams, skater, puck, shot, rules, look, camera); with data/hockey.thirdlife.rules.json beside it the core opens its rule-patched variant" },
        { file: "tests/bot_first_match.gd", role: "the player's first match through the keys at ROOKIE, to the final whistle" },
        { file: "tests/bot_match_hand.gd", role: "a whole match through the keys (a scripted hand): the FJamInput stream and the core hash per frame" },
      ],
    },
    core: RINK_ROUTE,
  },
  {
    id: "arcade_sport",
    title: "an arcade team sport with a ball or puck",
    sentence: /\b(hockey|football|soccer|basketball|handball|rugby|puck|ball game|lacrosse|polo)\b/i,
    reference: "NHL '94 / Rocket League / Buckland's Simple Soccer, as docs/research/HOCKEY-ARCADE.md",
    file: "docs/research/HOCKEY-ARCADE.md",
    design: ["## 0.", "## 1.", "## 5."],
    builder: ["## 0.", "## 5."],
    must: [
      { what: "possession as a state with readable loss causes (HOCKEY-ARCADE 5.1)", re: /possession|carr(y|ied|ier)/i },
      { what: "the utility AI for shoot, pass and carry (HOCKEY-ARCADE 5.3)", re: /utility|scored options|decid|vetoes/i },
      { what: "the roles re-sorted by time to the ball (HOCKEY-ARCADE 5.4)", re: /\broles?\b|first man|support/i },
    ],
    moves: {
      poke: { anticipation_f: 5, active_f: 7, recovery_f: 12, clip: "cross_check", kind: "attack" },
    },
    movesMin: 0,
    metrics: [
      { id: "possession_median_f", min: 240, max: 600, item: "HOCKEY-ARCADE 5.5: possession median 4-10 s (over 15 s glued, under 2 s random)" },
      // D3 of 22 Nov: hockey -2's tofu bot passed every row while every strip showed 3 to 6 skaters merged into one blob
      // at the boards (critic: fighters_overlap, feel 0.25). The house hockey's own measures (tests/metrics.gd crowd4 and
      // overlap_frames, pro regular seed 1: 1225 and 0 of 6598 live frames) are the spacing rows.
      { id: "scrum_share", max: 0.3, item: "spacing, no scrum: the share of live frames in which 4 or more field skaters (not goalies) stand within 5 m of the puck (the house hockey: 0.19)" },
      { id: "overlap_share", max: 0.02, item: "spacing, bodies apart: the share of live frames in which two upright field skaters' bodies overlap by more than 0.1 m (body radius from the contact scale; the house hockey: 0)" },
    ],
    filmFirst: ["one_timer", "poke", "check", "hit", "goal", "shot", "pass"],
    bar: {
      teardown: "docs/research/hockey-teardown/TEARDOWN.md",
      numbers: [
        "the size of the world: life-size skaters, a contact radius of 0.4 m, a rink of 90 x 45 m: 112 body widths long (a real rink is about 100) (thirdjam; CASES.md A9)",
        "speed in the player's units: a cruising skater about 12.65 m/s, about 7 of his own heights a second; the carrier x0.92 of a free skater; bots sprint by level (thirdjam)",
        "the puck slows on the ice: drag 0.5/s plus friction 0.147 m/s^2, so a 14 m/s pass stops after about 26 m (thirdjam)",
        "a pass is solved to ARRIVE at about 8 m/s where the receiver will be (a tap 14 m/s; held, it crosses a third of the rink), never a fixed launch speed (thirdjam)",
        "a shot snaps to the goal inside 8 degrees (16 on a one-timer) and is fast: a tap 36 m/s, full charge 52 (the owner's order in thirdjam)",
        "the camera bound to YOUR skater: behind and above, about 6 m back and 3.5 m up, a 4-frame lag, and an aim anchor so a still hand keeps its stick point; the HUD points at an off-screen puck (thirdjam, rulings R-0038, R-0064)",
        "teammates shoot and drive the net; every bot decides every frame with no reaction delay; a level is easy by clumsiness, never by absence (R-0067)",
        "one continuous match to three goals; hit-stop of about 3 frames, presentation only, only on a knockdown that involves you; nothing technical drawn at a hit (R-0069, R-0070)",
      ],
      dont: [
        "figures drawn 2.2x on a 60 x 30 m rink: 34 body widths, every play a scrum",
        "teammates who hold back (shoot only within 4 s of your own pass) so an idle hand loses a bot ladder",
        "a camera that follows the puck and zooms, so the stick moves when the hand does not",
        "a puck with no drag and passes at a fixed 18 or 23 m/s, patched by own-goal guards",
        "a game that keeps stopping: 36-second periods, whole-game freezes on hard hits, goal holds, replays",
        "figures that glitch (a statue goalie, sticks through boards, overlaps)",
        "hits that decide the game, drawn loudly with rings, bursts and punches",
        "bots that read the play 5-18 frames late, decide at 4 Hz and never sprint",
        "shots aimed exactly at a cursor through a moving camera",
        "a screen that stops explaining itself after the first key (no chevron, no radar, no off-screen marker)",
      ],
    },
    house: {
      pack: "hockey",
      game: "game.ice_hockey_three_against",
      // Refreshed 22 Nov 02:10 from main b024967 (N3: HOCKEY-ARCADE carry, poke, utility AI and roles landed).
      readme: ["## How to play", "## Puck, speed and the bots' decisions", "## Contact and skating"],
      files: [
        { file: "scripts/carry.gd", role: "the puck as a state (loose, carried, pass, shot) with readable loss causes; the carry spring to the blade, the dangle, the pickup by relative speed, the pass window, the one-timer" },
        { file: "scripts/poke.gd", role: "the poke: a 24-frame action live on frames 6-12, odds by angle, the anti ping-pong rule" },
        { file: "scripts/ai/brain.gd", role: "the bots decide every 15 frames (staggered, at once on events) from what anybody could see reaction frames ago" },
        { file: "scripts/ai/carrier.gd", role: "the carrier's utility scores: SHOOT, PASS to each mate, CARRY, PROTECT, DUMP, with vetoes (no risk to its own net)" },
        { file: "scripts/ai/roles.gd", role: "roles F1/F2/F3 and D1/D2/D3 by time to the puck, the support spot grid, the open mate's call" },
        { file: "scripts/ai/sense.gd", role: "perception with a reaction delay, aim and score noise by level" },
        { file: "scripts/skate.gd", role: "skating: cruise and sprint, the carrier slower (x0.88), turn rates, the reverse cut and first step" },
        { file: "scripts/hits.gd", role: "body contact: wind-up, impulse against stability, bump / stumble / down, the puck freed above a threshold" },
        { file: "scripts/keeper.gd", role: "the goalie: depth by the puck's distance, lateral speed under 4 m/s" },
        { file: "data/ai.json", role: "the utility weights, reaction frames, fresh-carrier delays" },
        { file: "tests/metrics.gd", role: "the five HOCKEY-ARCADE 5.5 metrics read from the state every frame (possession, passes, shots, turnovers by cause, zone share)" },
      ],
      // Round 7: the owner's three hockey words (21 Nov: "puck stickiness, players speed, ability AI to decide what to do,
      // when to pass and shoot"). The real arcade-sport room of 22 Nov copied the carry and the utility AI but wrote no
      // speed ratio at all: the brief must say the carrier is slower and the pass beats skating.
      keeps: [
        { what: "the speed ratios: the carrier is slower than a free skater (about x0.88) and a pass travels about twice skating speed, so passing beats carrying", re: /carrier[^.]{0,60}(slower|x\s?0\.\d|0\.\d+\s?x)|(slower|x\s?0\.\d)[^.]{0,40}carr|0\.88|pass(es)?[^.]{0,40}(beats?|faster than) (skating|carrying)/i },
        { what: "the possession rules: the puck sticks to the carrier's blade (a spring) and leaves only by a readable cause (a poke, a check, an intercepted pass, the carrier's own sprint-and-turn, a bobble)", re: /spring|stick(s|y)? to (the|his) blade|on the blade/i },
        { what: "the AI decides from scored options (shoot, pass, carry) every few frames with vetoes, never by chance alone", re: /utility|scor(e|es|ing) (shoot|SHOOT)|SHOOT, PASS|decid\w* every \d+/i },
        // D3 of 22 Nov: hockey -2's design chose "a low chase camera right behind your skater": the near skater covered every
        // exchange (camera_hides_exchange) and the critic could find neither the puck nor the controlled player.
        // N2 round 5: the teardown's third fault is a camera that follows the puck; thirdjam's, after the owner's rulings, is bound to you.
        { what: "the play camera bound to YOUR skater and raised: behind and above you (thirdjam: about 6 m back, 3.5 m up, a 4-frame lag) with an aim anchor, or a raised broadcast view looking down that keeps you in one place; never low behind the skater, never one that follows the puck and loses you (the house game's `follow` below is a working base, not the bar)", re: /behind and above|above and behind|bound to (you|your)|aim anchor|raised|broadcast|look(s|ing)? down|from above|overhead|top[- ]down|high (follow|camera)|50 ?(°|deg)/i },
        { what: "the puck and your skater readable at a glance: the puck drawn larger than life with a hot-coloured rim, and a ring under your skater (its data/tuning.json `look`, read below)", re: /ring under|green ring|(puck|it)[^.]{0,60}\b(rim|outline|larger|bigger|oversized|scaled)\b|\b(rim|outline)[^.]{0,30}puck/i },
      ],
      numbers: [
        { what: "the house game's skater (data/tuning.json `skater`: speed m/s, acceleration, turn rate rad/s, mass, body scale): its body_scale 2.2 is the teardown's first fault; take the size of the world from the bar", read: (d) => readJsonKey(d, "data/tuning.json", "skater") },
        { what: "skating and the carrier's handicap (data/tuning.json `skate`: free-skater and sprint multipliers, the carrier's sprint cap, acceleration and turn ratios)", read: (d) => readJsonKey(d, "data/tuning.json", "skate") },
        { what: "the carry, the stickiness (data/tuning.json `carry`: reach, blade, spring k, dangle, the loss rule)", read: (d) => readJsonKey(d, "data/tuning.json", "carry") },
        { what: "the shot (data/tuning.json `shoot`)", read: (d) => readJsonKey(d, "data/tuning.json", "shoot") },
        { what: "the house game's play camera (data/tuning.json `follow`: field of view, pitch in degrees looking down, distance and its widening, the lead in the attack direction, the pull toward your skater): how the camera API is driven; it follows the puck, which the teardown names as a fault, so bind it to your skater (the bar's camera line)", read: (d) => readJsonKey(d, "data/tuning.json", "follow") },
        { what: "the readable puck and rings (data/tuning.json `look`: puck_scale and puck_height_scale over the real puck, puck_rim in metres and its colour key, the carrier ring, the down ring)", read: (d) => readJsonKeys(d, "data/tuning.json", "look", ["puck_scale", "puck_height_scale", "puck_rim", "puck_rim_key", "ring_key", "carry_width", "carrier_ring", "carrier_ring_after_frames", "down_ring", "down_key"]) },
      ],
    },
  },
];

export const templateOf = (id: string | undefined): Template | undefined => TEMPLATES.find((t) => t.id === id);

/** E3 of 24 Nov: the core route of a concept's template (undefined for a hand-built game). */
export const coreRouteOf = (template: { id: string } | undefined): CoreRoute | undefined => templateOf(template?.id)?.core;

/** The engine the house games are read from (the repository's; a test passes its own). */
export const HOUSE_ENGINE = path.join(REPO_ROOT, "engine");

type HouseMovesFile = Record<string, { windup?: number; active?: number; recovery?: number; up?: number; from?: number; to?: number; whiff?: number; frames?: number; iframes?: [number, number]; clip?: string }>;

/**
 * The house game's frame table as template moves, read from its moves file (`undefined` without a house game or file).
 * Attacks are windup / active / recovery; block is up / held / the playbook's 6 down; the parry window f`from`-f`to`
 * is (from - 1) / (to - from + 1) / whiff; roll and dodge are i-frames start - 1 / their length / the frames after.
 */
export function houseMoves(t: Template, engine = HOUSE_ENGINE): Record<string, TemplateMove> | undefined {
  if (t.house?.moves === undefined) return undefined;
  const file = path.join(engine, "packs", t.house.pack, ...t.house.moves.split("/"));
  if (!fs.existsSync(file)) return undefined;
  let m: HouseMovesFile;
  try {
    m = JSON.parse(stripBom(fs.readFileSync(file, "utf8"))) as HouseMovesFile;
  } catch {
    return undefined;
  }
  const out: Record<string, TemplateMove> = {};
  for (const [id, base] of Object.entries(t.moves)) {
    const h = m[id];
    if (h === undefined) {
      out[id] = base;
      continue;
    }
    const clip = h.clip ?? base.clip;
    if (h.windup !== undefined && h.recovery !== undefined) out[id] = { ...base, anticipation_f: h.windup, ...(h.active !== undefined ? { active_f: h.active } : {}), recovery_f: h.recovery, clip };
    else if (id === "block" && h.up !== undefined) out[id] = { ...base, anticipation_f: h.up };
    else if (id === "parry" && h.from !== undefined && h.to !== undefined) out[id] = { ...base, anticipation_f: h.from - 1, active_f: h.to - h.from + 1, recovery_f: h.whiff ?? base.recovery_f };
    else if (h.iframes !== undefined && h.frames !== undefined) out[id] = { ...base, anticipation_f: h.iframes[0] - 1, active_f: h.iframes[1] - h.iframes[0] + 1, recovery_f: h.frames - h.iframes[1], clip };
    else if (h.frames !== undefined) out[id] = { ...base, anticipation_f: 0, active_f: 0, recovery_f: h.frames, clip };
    else out[id] = base;
  }
  return out;
}

/** The frame table the Foreman checks: the house game's when it can be read, else the research's. */
export const movesOf = (t: Template, engine = HOUSE_ENGINE): Record<string, TemplateMove> => houseMoves(t, engine) ?? t.moves;

/** Where the house game's frame table differs from the research's, one line per move ([] when they agree or no house table). */
export function houseFrameDiff(t: Template, engine = HOUSE_ENGINE): string[] {
  const h = houseMoves(t, engine);
  if (h === undefined) return [];
  const f = (m: TemplateMove): string => `${m.anticipation_f}/${m.active_f ?? "held"}/${m.recovery_f}`;
  return Object.entries(t.moves).filter(([id, m]) => h[id] !== undefined && f(h[id] as TemplateMove) !== f(m)).map(([id, m]) => `${id}: research ${f(m)}, house game ${f(h[id] as TemplateMove)}`);
}

/** The house game's README sections and the files to read, for the design step and the Planner ("design") or a builder ("builder"). */
export function houseExcerpt(t: Template, part: "design" | "builder", engine = HOUSE_ENGINE): string {
  const h = t.house;
  if (h === undefined) return "";
  const dir = path.join(engine, "packs", h.pack);
  if (!fs.existsSync(path.join(dir, "README.md"))) return "";
  const files = h.files.map((f) => `- engine/packs/${h.pack}/${f.file}: ${f.role}`);
  const keeps = (h.keeps ?? []).map((k) => `- keep ${k.what}`);
  const numbers = (h.numbers ?? []).map((n) => [n, n.read(dir)] as const).filter(([, v]) => v !== undefined).map(([n, v]) => `- ${n.what}: ${v}`);
  const head = `# The house game: engine/packs/${h.pack} (${h.game}), a working base on this engine, NOT the quality bar
It is a tracked game that runs this template on the kernel: read it for how the engine is driven (its files, calls,
data layout, the frame table the Foreman checks). The owner played it and called it slop (22 Nov), and no person has
accepted it since: its feel, timing, scale, camera and screen are a floor, not the bar. The bar is the reference below
("The bar"): where the reference's numbers and the house game's differ, the reference's win unless the design says why.${part === "builder" ? `
Your reference copy holds it whole: ref/packs/${h.pack}/ (read the files below before you write yours).` : ""}`;
  const body = part === "design" ? researchSections(`engine/packs/${h.pack}/README.md`, h.readme, path.dirname(engine)) : "";
  return [head, "", "The files that carry it:", ...files, ...(keeps.length > 0 ? ["", "What a design of this template keeps from it:", ...keeps] : []), ...(numbers.length > 0 ? ["", "The house game's numbers (read from the pack now; how it drives the engine, not the bar where the bar below differs):", ...numbers] : []), ...barLines(t), ...(body !== "" ? ["", body] : [])].join("\n") + "\n";
}

/** N2 round 5: the template's quality bar as lines ([] without one): the reference numbers and the "do not copy" list. */
export function barLines(t: Template | undefined): string[] {
  const b = t?.bar;
  if (b === undefined) return [];
  return ["", `# The bar: the reference games, not the house game (docs/design/CASES.md; ${b.teardown})`, "Start from these numbers (tune them by hand on the greybox):", ...b.numbers.map((x) => `- ${x}`), "", "Do NOT copy these from the house game (the teardown's top ten, each a reason the owner called it slop):", ...b.dont.map((x) => `- ${x}`)];
}

/** A brief's template problems: the design's copied moves, and what the house game keeps (in rules and controls). */
export function briefTemplateProblems(brief: { design?: DesignDoc; rules: string; controls: string; arena: string; ai?: string }, template: ConceptTemplate | undefined, engine = HOUSE_ENGINE): string[] {
  if (brief.design === undefined || template === undefined) return [];
  const core = coreRouteOf(template);
  return [...designTemplateProblems(brief.design, template), ...houseKeepProblems(`${brief.rules} ${brief.controls} ${brief.arena} ${brief.ai ?? ""} ${brief.design.feel.camera}`, template), ...(core !== undefined ? coreBriefProblems(brief.rules, core, engine) : [])];
}

/** Problems of a brief against its template's house game: the rules it must keep (rules and controls text). */
export function houseKeepProblems(text: string, template: ConceptTemplate | undefined): string[] {
  const t = templateOf(template?.id);
  return (t?.house?.keeps ?? []).filter((k) => !k.re.test(text)).map((k) => `the ${t?.id} house game (engine/packs/${t?.house?.pack}) keeps ${k.what}: say it in \`rules\`, \`controls\`, \`arena\`, \`ai\` or \`design.feel.camera\``);
}

/** The template a sentence calls for by its words (a fight is a duel), or undefined. */
export function templateForSentence(sentence: string): Template | undefined {
  return TEMPLATES.find((t) => t.sentence.test(sentence));
}

/** Sections of a research file by heading prefix ("## 2." takes the section to the next "## "; "### 6.3" to the next heading). */
export function researchSections(file: string, headings: string[], root = REPO_ROOT): string {
  const abs = path.join(root, ...file.split("/"));
  if (!fs.existsSync(abs)) return `(${file} was not found: copy the template from its reference games)`;
  const lines = stripBom(fs.readFileSync(abs, "utf8")).split(/\r?\n/);
  const out: string[] = [];
  for (const h of headings) {
    const level = h.startsWith("### ") ? 3 : 2;
    const at = lines.findIndex((l) => l.startsWith(h)); // "## What changed from the playbook" heads "..., and why"
    if (at < 0) continue;
    const stop = level === 3 ? /^#{2,3} / : /^## /;
    let end = lines.findIndex((l, i) => i > at && stop.test(l));
    if (end < 0) end = lines.length;
    out.push(lines.slice(at, end).join("\n").trim());
  }
  return out.join("\n\n");
}

/** The concept step's menu: each template, when it applies, what is copied, and its move ids. */
export function templatesMenuText(): string {
  const out: string[] = [];
  for (const t of TEMPLATES) {
    out.push(`- \`${t.id}\`: ${t.title}. Reference: ${t.reference}.${t.house ? ` House game (a working base on this engine, not the quality bar; the bar is the reference and its teardown): engine/packs/${t.house.pack} (${t.house.game}).` : ""}`);
    out.push(`  - copies (name each in \`copies\`): ${t.must.map((m) => m.what).join("; ")}.`);
    if (Object.keys(t.moves).length > 0) out.push(`  - its move table (a verb that copies a move names it as \`move\` and carries these frames; a wind-up may be slower, up to the bar${t.bar?.maxAnticipation ? ` (${Object.entries(t.bar.maxAnticipation).map(([k, x]) => `${k} up to ${x}`).join(", ")})` : ""}, never faster): ${movesLine(t)}.`);
  }
  out.push("- `own`: any other genre. Name a real, released game (or a family of them) as `reference`, and in `copies` the exact mechanics with their numbers where the source has them (Mario Kart's item roulette by race position; Celeste's 5-frame coyote time). Never a mood.");
  return out.join("\n");
}

// D3 of 22 Nov: the line said "poke 5/7/12 (`cross_check`)" and the first hockey job's concept wrote "Poke 5/7/12 as move
// cross_check"; the design step then named the clip as the move three times and the job failed. The id and the clip are
// now said by name.
const movesLine = (t: Template): string =>
  Object.entries(movesOf(t))
    .map(([id, m]) => `move "${id}" ${m.anticipation_f}/${m.active_f ?? "held"}/${m.recovery_f} (its clip \`${m.clip}\`, not a move id)`)
    .join(", ");

/** The research excerpt of the concept's template for a reader ("" for `own` or a concept without a template). */
export function templateExcerpt(template: ConceptTemplate | undefined, part: "design" | "planner" | "builder", root = REPO_ROOT): string {
  const t = templateOf(template?.id);
  if (t === undefined) return "";
  if (t.core !== undefined) return coreExcerpt(t, t.core, part, root);
  const head =
    part !== "builder"
      ? `# The genre template: ${t.id} (${t.title}), copied from ${t.reference}\nThe core loop is copied from this, not invented: its state machine, its frame tables, its contact results and its rivals. Verbs that copy a move name it as \`move\` with these frames (a wind-up may be slower, up to the bar, never faster): ${movesLine(t)}. Only the hook and the twist are new.`
      : `# The genre template: ${t.id} (${t.title}), from ${t.file}\nThe design copies this proven design. Build its rules and tables as written; where your contract gives a number, the contract wins.`;
  // The Planner reads the research's implementable spec and the house game's rules (its prompt is long enough).
  const house = houseExcerpt(t, part === "builder" ? "builder" : "design", path.join(root, "engine"));
  return `${head}\n\n${researchSections(t.file, part === "design" ? t.design : t.builder, root)}\n${house !== "" ? `\n${house}` : ""}`;
}

/** The template lines of a concept, as the design step, the review and the Planner read them. */
export function templateLines(c: Concept): string[] {
  if (c.template === undefined) return [];
  return [`- genre template: ${c.template.id}, copied from ${c.template.reference}`, ...c.template.copies.map((x) => `  - copies: ${x}`)];
}

/**
 * Problems of a concept's template: it is there, a melee fight copies the duel (and a team ball game the arcade sport),
 * and its `copies` name what the template must copy. `own` needs a reference that is not one of the others' words.
 */
export function conceptTemplateProblems(c: Concept, sentence: string): string[] {
  const out: string[] = [];
  if (c.template === undefined) return ['the concept needs `template`: ONE proven genre template for the core loop ({"id": "duel" | "arcade_sport" | "own", "reference", "copies"})'];
  const wanted = templateForSentence(sentence);
  if (wanted !== undefined && c.template.id !== wanted.id) out.push(`the player's words ask for ${wanted.title}: the template is "${wanted.id}" (${wanted.reference}), not "${c.template.id}"; put the novelty in the hook, not in the core loop`);
  const t = templateOf(c.template.id);
  if (t === undefined) return out;
  const all = c.template.copies.join(" | ");
  for (const m of t.must) if (!m.re.test(all)) out.push(`concept template ${t.id}: \`copies\` must name ${m.what}`);
  return out;
}

/**
 * Problems of a design's verbs against the concept's template (GAME-QUALITY.md section 11): a `move` is a move of the
 * template, its frames are the table's exactly, and at least `movesMin` verbs copy a move, one attack and one defence.
 */
export function designTemplateProblems(d: DesignDoc, template: ConceptTemplate | undefined): string[] {
  const t = templateOf(template?.id);
  const out: string[] = [];
  if (t === undefined) {
    for (const v of d.verbs) if (v.move !== undefined && template?.id !== "own") out.push(`design verb "${v.id}" names move "${v.move}", but the concept has no genre template with moves`);
    return out;
  }
  const copied = d.verbs.filter((v) => v.move !== undefined);
  const table = movesOf(t);
  for (const v of copied) {
    const m = table[v.move as string];
    if (m === undefined) {
      const byClip = Object.entries(table).find(([, x]) => x.clip === v.move)?.[0];
      out.push(`design verb "${v.id}" names move "${v.move}", which is not in the ${t.id} move table (${Object.keys(t.moves).join(", ")})${byClip !== undefined ? `: "${v.move}" is the CLIP of move "${byClip}"; write "move": "${byClip}" (and fix the concept's words if they say otherwise)` : ""}`);
      continue;
    }
    const diff: string[] = [];
    // N2 round 6: a wind-up may be slower than the house game's, up to the bar's (the duel: light 30, heavy 60); never faster.
    const hi = Math.max(m.anticipation_f, t.bar?.maxAnticipation?.[v.move as string] ?? m.anticipation_f);
    if (v.anticipation_f < m.anticipation_f || v.anticipation_f > hi) diff.push(`anticipation_f ${v.anticipation_f} (the table: ${m.anticipation_f}${hi > m.anticipation_f ? ` to ${hi}: at least the house game's, at most the bar's` : ""})`);
    if (m.active_f !== undefined && v.active_f !== m.active_f) diff.push(`active_f ${v.active_f} (the table: ${m.active_f})`);
    if (v.recovery_f !== m.recovery_f) diff.push(`recovery_f ${v.recovery_f} (the table: ${m.recovery_f})`);
    if (diff.length > 0) out.push(`design verb "${v.id}" copies the ${t.id} move "${v.move}" but changes its frames: ${diff.join(", ")}. Copy the table, not a paraphrase`);
    if ((m.kind === "defence") !== (v.defensive === true) && m.kind !== "other") out.push(`design verb "${v.id}" copies the ${m.kind} move "${v.move}": mark it ${m.kind === "defence" ? '"defensive": true' : "not defensive"}`);
  }
  if (t.movesMin > 0) {
    if (copied.length < t.movesMin) out.push(`the ${t.id} template: at least ${t.movesMin} verbs copy a move of its table (name it as \`move\`), ${copied.length} do: ${movesLine(t)}`);
    const kinds = new Set(copied.map((v) => table[v.move as string]?.kind));
    if (!kinds.has("attack")) out.push(`the ${t.id} template: one verb copies an attack move (${Object.entries(t.moves).filter(([, m]) => m.kind === "attack").map(([id]) => id).join(", ")})`);
    if (!kinds.has("defence")) out.push(`the ${t.id} template: one verb copies a defence move (${Object.entries(t.moves).filter(([, m]) => m.kind === "defence").map(([id]) => id).join(", ")})`);
  }
  return out;
}
