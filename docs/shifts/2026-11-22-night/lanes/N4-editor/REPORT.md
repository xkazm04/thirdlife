N4 editor-knowhow / editor-example: FINAL REPORT, shift 2026-11-22-night (19:07 to 07:45)
Worktree n22-editor. Opus solo. Nothing committed by me; the Director landed every round.

The editor now designs from proven genre templates, and since 01:00 it copies the two house games, not only the
research: engine/packs/duel and engine/packs/hockey are the reference implementations every editor game is built
against. Seventeen rounds landed or are landable. Every figure below was read on the real runner or from a real Opus call,
except where it says fake.

Nobody has played any of this by hand. The proofs are judged by the critic and by me from strips, not by the owner's
hand and eye.

=====================================================================================================================
PART A (19:07 to 20:10): the first brief
=====================================================================================================================
All acceptance items were met. Detail is in the earlier part of this file's history; in short:

- docs/GAME-QUALITY.md v2:
  - new sections: R1-R14, the anti-patterns, the 30-item checklist (each item [B]/[C]/[H] with who judges it), the genre
    templates and the tofu stage;
  - four new slop ids.
- foreman/src/templates.ts:
  - templates: duel, arcade_sport, own;
  - the sentence picks the template;
  - a verb's `move` must carry the table's frames exactly.
- foreman/src/tofu.ts:
  - TOFU CHECK line and metrics;
  - judged together with the critic;
  - a failing tofu stage holds the job like the quality loop.
- The critic adds an [H] line naming the items only a person can judge.
- `foreman quality retry` now records and prints the resume command instead of running the job.
- Real Opus rooms on "a fight in a colosseum", standard and crazy: both copy the duel exactly. See room-standard.json
  and room-crazy.json.

=====================================================================================================================
PART B (01:00 to 07:45): the loop. The editor copies the house games
=====================================================================================================================
Round by round. Each round's gap was named first, from the proofs or the owner's words, then built, then shown.

Round 1 (landed c4d3e95). Templates name their house game; the Planner timeout.
- Gap 1: the editor copied the research, not the tuned house games.
- Gap 2: the standard proof's Planner timed out at 10 minutes. It retyped the tables into every contract; my own run
  wrote 23,000-character contracts in 571 s.
- Built, house games:
  - each template names its house game, with README sections for the design step and the Planner and a file list for
    builders (the files are in every job's ref/packs/<pack>/);
  - copied moves are checked against engine/packs/duel/data/moves.json. N2's question answered: the frames match the
    playbook; poise, pushes, Wall hp, lock-on, parry-as-block-press, rally and camera differ, and GAME-QUALITY 11 says
    the house game wins;
  - a duel brief must keep lock-on and the shoulder camera. The crazy proof's review had caught "facing follows
    movement".
- Built, the critic's yardstick:
  - a house baseline per job (reports/house-<pack>.json);
  - a "yours vs the house game's" line at every quality check, which the Foreman calls a "look": it films the build
    and the critic judges it;
  - a house_game rubric item.
- Built, the Planner:
  - contracts NAME the house rows instead of retyping them;
  - a 20-minute Planner limit, `plan --timeout-ms`, and `--planner-timeout-ms` for re-plans;
  - card tests updated for card.duel.
- Evidence: a real Opus plan of the same design took 207 s and wrote 21.8k tokens (it had been 571 s and 58.7k). It
  took card.duel; the root contract was 8.3k characters, the others 0.7k-2k. The standard proof re-planned in 224 s.

Round 2 (landed 61fcb86). The critic sees the house game's own exchange.
- House strip: a drill bot gives the contact frame, one --strip capture is taken there, and the critic sees it last,
  labelled HOUSE GAME. Real: heavy_block, contact at frame 46.
- House figures are read from the real pilot's result. The verify report has no pack_state.
- arcade_sport now reads N3's hockey.
- skill_spread passes only from 0.25 to 0.95, over variants of the core verb. The crazy proof reported 1.0 by counting a
  bash as a variant of its light.

Round 3 (landed 564a3a0). The root builds a readable exchange.
- Gap: proof roots with bare-fisted twin bodies (recoloured_rivals), a wide camera, no HUD, and no parry or roll in any
  strip.
- Built:
  - tofu row verbs_used: every design verb pressed at least 3 times;
  - Planner rules: copy the house cameras, declare only views that frame the action, resource bars plus a hint line;
  - weapons (gen/arms.gd) and rival builds (rivals.json) from the first phase.
- Evidence: a real plan's root (9.2k characters) names all of these.

Round 4 (landed 6252c28). House figures compared only by matching definition.
- N2 and N3 now return `metrics`. Rows they define differently are skipped and named:
  - duel: skill_spread, skill_variants, contact_types;
  - hockey: idle_max_f, which is a dead-puck spell (606 frames), not an idle opponent.
- pressure_waves and lead_change_share now use the duel house game's definitions.
- Hockey house strip: filmed at a metrics.moments frame (real: poked at 523).
- Real duel pilot: pressure_waves 1, under its own bound of 2 (reported to N2).

Round 5 (landed c2584dd). Hook families.
- Gap: the standard broke the stone walls 4 times; crazy swapped souls on a parry 3 times.
- Built:
  - every concept step reads up to 4 earlier concepts of its sentence and mode;
  - a hook too close to one of them (hook-word overlap over 0.4) is sent back.
- Evidence: a real crazy room on a copy of the proof site chose a new family: "only the awning's moving shade refills
  your stamina" (room-crazy-r5.json).

Round 6 (landed a87924c). Builders get the house numbers, read live.
- Gap: -3's critic named the camera low behind the player, overlap, and passive_ai.
- Built: the builder excerpt carries the duel's data/tuning.json camera (retuned tonight by N2: angle 50, dist 4.3,
  up 2.8, fov 50), feel.gd PUSHBOX 0.45 m, and the 120-frame never-idle rule. Stale 4.6/2.6/2.6 text was removed.

Round 7 (landed 4a58f08). arcade_sport keeps the owner's hockey words.
- A real Opus hockey room copied puck stickiness (spring, dangle, pickup, anti ping-pong) and the AI's pass/shoot
  decisions (utility with vetoes, roles). It wrote no speed ratio.
- Built:
  - keeps for the speed ratios (carrier x0.88, pass beats skating), the puck on the blade, and scored AI decisions;
  - the keep check also reads the brief's ai text;
  - builders get the hockey tuning blocks live.
- Fixture: foreman/fixtures/room-hockey-22nov.json.

Round 8 (landed 944a2bd). Film the exchange.
- Gap: -3's look filmed two strips of 60 frames standing still (fixed 25/95 %).
- Built:
  - bots report `moments` (kind -> frames) and the look films them, variety first;
  - the first test keeps its 25 % frame for the art-pass compare;
  - the tofu contract asks for moments.

Round 9 (landed 69f1ae4). Contact strips.
- Gap: every proof critic said "no visible hit-stop" on cores that call TLHit.impact. A 6-frame freeze is one tile at
  5 frames apart.
- Built: a moment gets a 12x2 strip from 10 frames before it, and the house strip does too.
- Real: the house heavy_block holds still over 3 tiles.

Round 10 (landed f5c84b7). The critic tells a camera fault from overlap.
- Gap: the critics of -3 and -4 named fighters_overlap first in every round, but on the duel camera the near body
  simply covers the other; the side strips showed the bodies apart.
- Built:
  - fighters_overlap is judged on a side view;
  - new slop id camera_hides_exchange;
  - the critic checks the side strip of the same moment first.
- ENGINE-NEED to N1: the pushbox against a wall. A pinned defender lets the attacker walk in.

Round 11 (landed ba65ecf). The duel house strip comes from a real match moment.
- Uses N2's moments: the first parry, seed 1 at frame 2269.
- arcade_sport through a real Opus Planner: card.team_possession, the TOFU line with possession_median_f, and a root
  that says "copy ref/packs/hockey carry/skate/ai ...; keep their numbers; this contract lists only differences".

Round 12 (landed 6c14a49). The bot's figures are claims.
- The critic gets the tofu figures labelled as claims and writes "claim contradicted:" where a strip shows otherwise.
- Proof -6's critic did: "one_sided_contacts 1 understates what the frames show".

Round 13 (landed e27958d). A bug the proofs showed.
- -5 and -6 filmed the house duel's KO (its finish minus 60) instead of its parry: contactFrame read only
  metrics.moments, and the duel pilot puts moments at the result's top level.
- Fixed; tested on the real pilot result (parry at frame 2269).

Round 14 (landed b96491b). Rival silhouettes.
- Gap: -5 and -6 failed recoloured_rivals at their first look.
- Reference: duel round 9 gives each rival a silhouette on the rig's head and back sockets.
- Built:
  - builders get the house silhouettes read live from rivals.json (Wall: helm and pauldrons; Duelist: hat and cape;
    Dancer: hood);
  - the rule "differ in silhouette from the first phase, never in colour alone";
  - the socket-axis trap;
  - the README section joins the design and Planner excerpt.
- ENGINE-NEED: gear slots as rig API.

Round 15 (landed 166a98d, docs only). GAME-QUALITY.md section 13: what the six proofs taught the editor.
- Each failure of the night is listed with the rule that now catches it.

Round 16 (landed 166a98d). The look films the template's signature contacts first.
- Gap: -5 and -6 showed no parry flash, roll or fall on film, although their bots pressed them.
- Built: templates name the moment kinds a look films first.
  - duel: parry, roll/dodge, fall, wall splat, blocked heavy, clash, guard break;
  - arcade sport: one-timer, poke, check.

Round 17 (landed 263b552). Each package's bot reports the moments of what its package adds.
- Gap: -5's greybox look filmed its rivals bot at frames 117 and 127, still fighting the opener. The look matched the
  core's pixels and showed neither the Duelist, the Dancer nor the echoes.
- Built: a Planner rule (each package's bot reports its addition's moments within its first 600 frames) and a line in
  GAME-QUALITY 13.

=====================================================================================================================
THE PROOF JOBS (site/fight-colosseum-20261122-*, the Director's runs). Two-line verdicts
=====================================================================================================================
-1 standard (round-0 prompts, re-planned after the round-1 timeout fix)
  Held on quality after round 2: feel 0.5, house_game 0.45. Swords and shields came in revise round 1; the bodies still
  press together. The design copies the duel; the build reads as one only on the side camera.
-2 crazy (round-0 prompts)
  Held after round 2: feel 0.35, no house strip. It calls the feel kit like the house game, but its strips showed no
  parry, roll or bash, no HUD, and a wide camera.
-3 crazy (round-3 prompts)
  The best colosseum build of the night: weapons, a distinct rival, feel 0.6, house_game 0.45-0.5. The tofu stage caught
  verbs_used 4/5 and skill_spread 0.219, and the build fixed both. The critic compared it with the house strip
  directly. Held after round 2 on overlap on the duel camera, a mace through the torso at idle, and two still strips.
-4 standard (round-3/4 prompts)
  Hook: a 5th wall family (it predates round 5). Held after round 2: feel 0.55, house_game 0.5; rivals distinct. A
  readable duel on the side camera, lost on its duel camera.
-5 crazy (round-11 foreman)
  New hook family: "every swing leaves a ghost that strikes again two seconds later". PASSED its blockout look at revise
  round 1, the first colosseum core of the night to clear the tofu stage and the critic: feel 0.75, house_game 0.7,
  slop clean, verbs_used 5/5, not short of the house game on any figure. The critic on a contact strip: "Tiles 6-10 hold
  still, which reads as a hit-stop. Then red snaps back with the head thrown up and the mace flung open." Still missing:
  a parry flash, a clear roll, a fall, and a Wall with a silhouette of its own. Phase 2 (echo_blows) merged at 05:32.
  Its greybox look (05:42, rivals and echoes) is NOT ok: fun_promise 0.15, house_game 0.4. The echoes never show as
  their own effect. The rivals bot was filmed at the opener, so no Duelist or Dancer is on screen (round 17). The rival
  is still the player's body.
  Revise round 1 (05:52): better, still NOT ok. Silhouette 0.8, fun_promise 0.45, house_game 0.5, feel 0.6.
  - The rivals now read by silhouette: the Wall in a box helm, the Duelist in a crested helm and cape, on the rivals
    bot's own frames.
  - The hit-stop holds over tiles 6-10.
  - Still wrong: the echo ribbons are opaque white bands covering a third of the frame; no Dancer; no fall; no parry
    flash; no HUD; camera_hides_exchange on the duel camera.
  Revise round 2 (06:01): slop clean, house_game 0.55, feel 0.6, fun_promise 0.35. The job is held on quality for the
  owner.
  - The critic: "the knight's raised mace is the wind-up, tiles 6-10 hold still as a hit-stop with gold sparks, and in
    tiles 11-12 the blue fighter's head snaps back and the hat flies off. This reads well."
  - The crazy hook (an echo that strikes again 2 s later) is never filmed striking. The echo ribbon hangs frozen, then
    fades.
  - Its house strip is still the KO (cached in the job before round 13), so that comparison is weak.
-6 standard (round-11 foreman)
  New hook family, the first standard tonight that is not a wall: "every parry knocks a piece of the rival's armour
  flying". Held after round 2: feel 0.45, house_game 0.45. Faults: hit_without_reaction at a sword thrust,
  recoloured_rivals, a shield held like a plank; the tofu stage failed lead_change_share 0.2 and one_sided_contacts 1.

=====================================================================================================================
WHAT THE EDITOR STILL GETS WRONG, against the owner's words
=====================================================================================================================
"Arena mutual reaction on attacks and collision is almost non-existing"
  The designs carry the mutual-reaction table word for word, and the cores call the kernel feel kit. No proof build
  reached the house game's readability: house_game sits at 0.45-0.5 and feel at 0.5-0.6. In the strips, the blocked
  heavy's slide-back and rebound are not visible the way they are in the house game. Builders copy the files, but not
  yet the result.

"well known game design paths we can mimic"
  Met on paper for the duel: template, frames, archetypes, house numbers. For hockey (arcade_sport) it is met on paper
  through one room and one plan; no hockey job has been built through the editor.

The gate itself
  - The tofu metrics are the bot's own claims. -3's bot reported idle 37 while its strips showed 55+ frames of both
    fighters standing still. The Foreman does not yet cross-check a metric against what it films.
  - Every proof is held at quality, for the owner.
    - Five of the six held at their first look (blockout) after 2 revise rounds.
    - -5, on the foreman with rounds 1-11, passed its tofu look and built two more phases, then held at greybox: its
      twist is never seen striking.
    - The loop now judges against the bar and can converge on the core, not yet on the twist.
  - The owner's hand is the bar, and no proof has been played by a person.

=====================================================================================================================
GATES (last round)
=====================================================================================================================
foreman: 290 tests, 284 pass, 0 fail, 6 skipped. The Director's merged main counts 5 skipped.
tl check --tier fast: PASS on all five steps.
- arch [12/12]
- assets [4/4]
- cards [3/3]
- devx.test [229/229]
- foreman.typecheck
The full tier is not mine: no kernel, kit, rig, style or seed change.

=====================================================================================================================
FILES
=====================================================================================================================
foreman/src (changed by the loop):
- templates.ts: house games, keeps, numbers, briefTemplateProblems
- house.ts: new. House bots, figures by definition, compare, contactFrame, strips
- quality.ts: house baseline, line and strip; house_game item; contact strips
- shots.ts: moments, pickMoments, CONTACT_STRIP
- tofu.ts: verbs_used, moments; definitions
- concepts.ts: earlier designs; earlierProblems
- room.ts
- designer.ts: Planner timeout, tofu verbs
- cli.ts: plan --timeout-ms and --planner-timeout-ms
- options.ts: plannerTimeoutMs
- foreman.ts: re-plan timeout, moments to shots

Tests:
- new: n4_house.test.ts, n4_numbers.test.ts, n4_moments.test.ts
- updated: cards.test.ts, designer_v2.test.ts, quality.test.ts, helpers.ts (fixturePlanTofu, designerSteps),
  editor_flags.test.ts, place_calls.test.ts, n4.test.ts

Fixtures: foreman/fixtures/room-hockey-22nov.json; job-paddle/fake-builder.json (verbs_used).

Prompts: planner.md (name, don't retype; cameras; bars; weapons; every verb), critic.md (contact strips).

Docs: docs/GAME-QUALITY.md, sections 6, 11, 12 and the new 13 (what the six proofs taught the editor).

Lane folder:
- PATCHES.md: items 1-13, the engine needs, the requests to N2 and N3
- STANDUP.md
- this REPORT.txt
- room-*.json, plan-*.json
- house strips: house-duel-strip-heavy_block-side-f31.jpg, house-duel-contact-strip-12x2-side-f36.jpg,
  house-duel-match-parried-12x2-side-f2259.jpg, house-hockey-strip-poked-chase-f508.jpg

=====================================================================================================================
QUESTIONS FOR THE DIRECTOR
=====================================================================================================================
1. PACK.md: name `metrics` and `moments` as the bot result's places for named figures and filmed frames. Both house
   games and the tofu stage use them.
2. ENGINE-NEEDs for N1:
   - when one body of a pushbox pair is pinned against a wall, push the free body the whole penetration;
   - rig gear slots (head, back, shoulders), oriented by the rig.
3. N3: an opponent-idle figure under idle_max_f, with dead_puck_max_f for the old figure. N2: pressure_waves 1 on the
   Wall, seed 1, is under the tofu bound of 2.

=====================================================================================================================
NEXT THREE THINGS
=====================================================================================================================
1. Cross-check the bot's claims against what was filmed. A strip with no body moving for 50 frames while idle_max_f
   reports under 120 is a finding: the critic gets both.
2. Give the build's revise round a pair to work from: the build's contact strip beside the house strip at the same
   contact kind, plus the diff of its contact numbers against data/contacts.json. Today the proofs stall at
   house_game 0.45-0.5 after 2 rounds.
3. Run one hockey job through the editor to a tofu look, and judge it against the owner's three hockey words in a
   window.
