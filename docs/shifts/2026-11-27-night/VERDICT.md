# Verdict: night of 27 Nov 2026, "a unique juice for each game" (03:00-08:00)

**The owner's ask (~00:10):** "lets use the night to give each game a unique juice. We will need to demonstrate
juicy/crazy ability to express we can compose any ide there: For example carts with ability to jump, Robots with
doublesledged hammer allowed to bash oponents, Basketball with crazy high jumps and dunks/blocks."

## In one paragraph
All six games got their crazy abilities, and Create made a version of every one. In **karts** and **biplane** the
editor alone made everything: jump, flip double jump, aerial hits, air bumps the bots use; loop, barrel roll, smoke
and shoot-downs. In **robots, basketball, shield wall and Arsenal** the editor made the ability, but the hand-built
copy reads far better on screen: wind-up rings, launches, banners, slow beats, bots that use it often. The difference
is the **juice a sentence does not ask for**. The editor builds exactly the words and no more, and it often leaves the
bots out. When basketball's hand-made juice went back to Create as ONE sentence, Create's v0.1.6 came out about as
juicy as the hand version. What made this possible tonight was **lane T's fix**. Before it, the balance gate refused the dunk and the
roll, bent the kill (a hidden "graze" rule) and threw the robot hammer away after 61 min and 14 M tokens. After it, the
same hammer was made in 31 min, and every later change went through as asked, with a plain-words note on the balance it
moved.

## For your eye (15 min)
1. Start `C:/Users/kazda/kiro/third-life/dist/PLAY-LATEST.cmd` (the exe built tonight from main; the tag is in the
   window's corner).
2. Go to **Dungeons**. Your newest games come first, 5 a page, and A / D turn the pages. Each juiced game has an
   **(made in Create)** row and, where one exists, a **(juice by hand)** row. Play both of a game and compare.
3. Keys:
   - karts: Q to jump, Q again in the air to flip;
   - robots: F to hold and swing the hammer (by hand: hold longer for a bigger launch);
   - basketball: F to sky-jump, dunk and block;
   - biplane: E to loop, Shift to roll;
   - shield wall: F to charge, C to slam;
   - Arsenal: F to light the stick, hold shoot to wind up, let go.
4. In Create -> My games, a change now takes 800 characters. When your change moves the balance, the done screen says
   so in words instead of refusing.

## Lanes

### T, the tofu gate (Opus): landed, 3 rounds
- **T1** (main b7d453d9; JOB.md 6c75354c): a person's change is built as asked.
  - A balance figure the change moves (who wins, how close the rounds are, a hand check's wins) becomes a note:
    "built as you asked; the gulls side now wins 3 of 3 ... say 'make it fairer'".
  - A camera- or HUD-only change skips the balance check. A look-only change, and "make it fairer", keep it as a guard.
  - Rows the change did not touch still guard, as regressions.
  - The tofu bot and its pilot scripts are frozen after their first merge ("measure kept").
  - A rule nobody asked for must be a `RULE:` line, and it is listed on the what-changed card.
  - Proven on a real paid job: the shield copy, v0.1.5 and v0.1.6 "brutal and unfair on purpose".
- **T2** (main a7094a8c; JOB.md bd5d4b06):
  - a final-verification failure goes to the package that owns the test, not one a control run cleared;
  - a person's longer match gets 3x frames and a note ("matches now run longer");
  - a change that truly cannot be made ends with "change not finished" and the builder's reason, shown in Create.
  - Proven live: J2's exact hammer sentence promoted on a copy of its job.
- **T3** (main b1ee0b1d): Create's change box and first sentence take 800 characters, not 240.
- **Evidence:** merged trees: fast 5/5; foreman npm 460 tests, 453 pass, 0 fail, 7 skipped; create. 29/0. On main's tip:
  menu. 2/0, dungeon. 7/0.

### J5 karts (Opus): landed, all by the editor (v0.1.4-v0.1.7)
- Jump and flip double jump (46 min); aerial hits on the ball (61 min, bent by the old gate: it added a reversal rule);
  air bump with flip, stomp and whirl (38 min, a note instead of a refusal); bots that use the air bump (29 min).
- Bots per live minute, all five: 22.5 jumps, 8.7 aerials, about 1.8 air hits. No bot whirls against your jumps yet.
- Finding: the bots used the move only after a sentence said so. Should every new move tell the bots by default?
- Menu: "Bumper-kart football v0.1.7: jumps, aerials, air bumps (made in Create)".

### J2 robots (Opus): landed, editor v0.1.6 + by hand
- **Before T:** core built the whole hammer, then the gate refused it. Final verification then looped four times on a
  frame budget, routed to the wrong package, and the change was "NOT made" (61 min, 14 M tokens).
- **After T:** v0.1.6 in 31 min (1.4 M tokens): a real hammer with a charge. To a person it reads as a strong tackle.
- **By hand:**
  - the head glows red to white-hot, with a reach ring on the court;
  - launches of 3.7-5.4 m with spins and wall bounces;
  - BONK! / KA-BONK!!, the lens kick, and the camera follows you when you are launched;
  - a miss drives the head into the court;
  - bots swing 5-7 times a minute.
- Menu: v0.1.6 (Create) and "Robot soccer: sledgehammer (juice by hand)".

### J4 basketball "Sky Jam" (Opus): landed, editor v0.1.3-v0.1.5 (+J4b) + by hand
- **Dunk:** refused by the old gate; r9 passed by changing the test's hand (a bend). The bots under-use it.
- **Block:** first time. Bots only block near the rim.
- **On fire:** first time, on the fixed editor, with a note. Its tag overlaps the clock.
- **By hand:**
  - the whole court slows at the rim and the camera zooms in;
  - SLAM! and REJECTED! banners;
  - the dunker hangs on the rim;
  - bots dunk 1.7 a minute and block 2.7 a minute.
- **J4b, the night's clearest proof:** the hand layer went back as ONE 656-character sentence. Create's v0.1.6 (one
  builder round, 57 min to promotion) did every part: the court-wide slow beat, the camera push-in, mid-screen
  SLAM!/REJECTED!, the rim shake, bots dunking from the line and contesting. By eye it is about equal to the hand version.
  It is less clean in three ways: the banner sits on a tall black slab, the close-up half-crops the rim, and the ON FIRE
  tag no longer stays on screen. The Foreman also doubled the match length to keep a crew test passing, and said so in a
  note.
- Menu: v0.1.6 (Create) and "Half-court: Sky Jam (juice by hand)".

### J11 biplane (Opus): landed, all by the editor (v0.1.3, v0.1.4)
- Loop with REVERSED!; Star Fox barrel roll with DEFLECT! sparks; smoke, fire and SHOT DOWN! corkscrews.
- Before T the roll and the kill were refused, then bent (a graze rule, an edited test pilot). After T, the roll fix,
  the kill and the clean-up (graze rule out, your own smoke smaller, her pull-up every round) came out as asked, in one
  round each.
- The old test-pilot edit is still in the pack: the freeze stops new edits, it does not undo old ones.
- Menu: "Biplane duel v0.1.4 (made in Create)".

### J19 shield wall (Opus, started 05:10): landed, editor v0.1.5-v0.1.7 + by hand
- The editor took three sentences, with no refusal:
  1. it gave the rivals' moves to core only, so 4 of the 5 bots never used them;
  2. the charge's reach (1.15 m) was shorter than the gap between bodies (1.4 m), so it could never land;
  3. core found that cause itself, and the charge now floors two in a row.
- **By hand:**
  - red lane rings, a charge that bowls a line (BOWLED!);
  - a braced shield stops it dead (BRACED!), and the charger bounces back;
  - a 2.6 m leaping slam with a landing ring (SLAM!);
  - bots charge 6-15 and slam 4-11 times a minute.
- One pack test fails (`bot_call`): the captain is floored before his call fills. This is a behaviour change; the test
  is untouched.
- Menu: v0.1.7 (Create) and "Shield wall: charge and slam (juice by hand)".

### J1 Arsenal hockey (Opus, started 05:10): landed, editor v0.1.23 (rules) + by hand (look)
- **Editor round 1** was routed to the drawing package. Its builder wrote the exact rule change, said it was outside
  its scope, and v0.1.22 was promoted with only a puff. **Round 2** made the rules exactly (v0.1.23, 9.6 min).
- **By hand:** the stick on fire, a growing wind-up ring, the fireball and trail, METEOR!, a net bulge and glass rattle
  (too small to see from the follow camera), and a faceoff guard.
- **The rink core's bots cannot use the meteor or dive to block it** (a C++ core limit).
- Balance: you win 39 of 40 at pro with it, against 23 without. It is crazy on purpose.
- Menu: v0.1.23 (Create) and "Arsenal hockey: meteor slapshot (juice by hand)".

## The exe
- `dist/ThirdLife` is built from main 6522394 (tag "6522394 2026-11-27 06:24"). `export.sh check` PASSES: the same
  games and 4 dungeons hash the same as the editor binary, the village shows, W and Esc work, and Create starts an idea.
- `dist/PLAY-LATEST.cmd` starts it.
- All 10 new juiced packs (karts v0.1.7; robots v0.1.6 + hand; court v0.1.6 + hand; biplane v0.1.4; shield v0.1.7 +
  hand; Arsenal v0.1.23 + hand) ran 600 frames as dungeons inside this exe: 0 script errors, 0 engine errors each.

## Route scoreboard
| Lane | Route | Held? |
|---|---|---|
| T | Opus solo, real job each round | yes: 3 rounds landed and re-verified on main |
| J5, J11 | Opus as a person; editor only | yes: everything by the editor once T landed |
| J2, J4, J19, J1 | Opus as a person, editor first, hand fallback | yes: editor versions plus juicier hand versions |

At most 5 agents at once, except about 3 minutes with 6 at 05:10 (the Director's slip; the extra round was cancelled).
No Codex was used.

## Machine
- Free disk fell from 110 GB (00:10) to 5.4 GB (06:20). The cause is another project on this machine,
  `C:/Users/kazda/kiro/gtai-wt/` (n23-street, n25-yard builds writing 0.3-0.5 GB AVIs all night). It was not touched.
- The Director freed about 12 GB of its own:
  - the merged trees d25-hard-b and d26-browse;
  - its scratch copies of thirdjam and the repo.
- **The full tier was NOT RUN:** it was not safe on a disk under 16 GB that another process was filling. Tonight's code
  changed only foreman/ and engine/ui/create/, and its suites passed (above).

## Asks
1. **Bots and new moves:** should the Planner tell the bots to use, and react to, every new move by default? Karts,
   basketball and shield wall needed a second sentence.
2. **Juice a sentence does not name:** should the editor add a standard juice pass to every new ability (a wind-up
   tell, an impact word, a camera kick, a slow beat)? Or should Create offer it as a card choice ("make it juicy")?
3. **Old bends:** biplane's edited test pilot and karts' reversal rule are still in those packs. Clean them with one
   change each, or leave them?
4. **Rink core:** bots that use abilities, and a dive block. Is it worth a C++ lane?
5. **Shield wall `bot_call`:** accept it as a behaviour change, or have bots hold their big moves while a call charges?

## Next shift
- Lane T's queue:
  - a rivals sentence reaches every package that drives a bot (J19);
  - a play request that a drawing package hands off is carried to the cartridge (J1);
  - a new attack must land at least once in the Foreman's bot run (J19);
  - banners go mid-screen, not into the score line (J4);
  - show every "balance moved" line, not only the newest;
  - freeze hand tests too.
- Send the hand layers back as sentences, as J4b did, for robots, shield wall and Arsenal.
- Then a person's hands on the juiced games.
