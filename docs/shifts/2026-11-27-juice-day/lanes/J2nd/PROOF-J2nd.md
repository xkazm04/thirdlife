# J2nd proof: a second crazy ability per game, through the fixed editor (juice day, 27 Nov 2026)

Tree `C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-kart` (branch d27-second, main ccf24701 with lane T's items
1-6). Job copies (plain recursive copies at 11:20, originals untouched) in
`C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-kart/.tl/jobs/j2nd/`:
- `bumper-kart-football-3-20261125-1` (newest v0.1.7, from this tree's own job);
- `biplane-duel-two-biplanes-20261125-1` (newest v0.1.4, from d25-biplane);
- `half-court-3-v-20261125-1` (newest v0.1.6, from d25-court).

Each change is sent as Create sends it: `engine/ui/foreman_run.mjs` + `foreman change <job copy> "<sentence>"` with the
`change` flags of `engine/ui/flags/real.json` (claude-cli sonnet, real and paid). Sentences word for word: `SENTENCES.md`.
Times are local (CET).

## Verdict (15:15)

All three games got a second crazy ability, **all by the editor, no hand build**. Each first sentence named the
ability, its juice and the rivals; each game then needed one or two follow-ups as a person would type them, after
watching it. J4b's lesson held twice more: when a follow-up NAMED the missing juice (karts: size, spin, freeze, word,
warning; court: twice as big, the catcher's jump), the next version read at a glance.

| Game | Ability (reference) | Versions (sentence -> version, time, tokens in / out) | Pick | Bots per minute (pick) | Headless (pick) | Clips |
|---|---|---|---|---|---|---|
| Bumper-kart football | Mario Kart red shell: item boxes, homing shell on F, tumble, SHELLED!, jump over or whirl to swat | 1 -> v0.1.8, 68 min, 3.79M / 41.6k: **shell NOT in the game** (items never wired; finding 2) / follow-up "switch it on, fix the sound" -> v0.1.9, 92 min, 3.86M / 28.9k / juice follow-up -> v0.1.10, 33 min, 1.49M / 15.8k | **v0.1.10** | mint 5.5-6.9 shells, 1.1-2.3 hits; mates 1.1-2.3 shells; jump dodges 1-3 (seeds 1-3) | 3600 f, 0 errors, f7b64a26 twice; newcomer 17/20, perfect 19/20 | `clips/j2nd_kart_v019_shells.mp4`, `clips/j2nd_kart_v0110_juiced_shells.mp4` |
| Biplane duel | Whaling harpoon on Q: closing red ring, cable, HOOKED!, whip and fling; roll dodges it (Just Cause tether, Battlefront tow cable) | 1 -> v0.1.5, 51 min, 3.38M / 33.5k (false "NOT made" note; finding 1) / "Vesper almost never" -> v0.1.6, 47 min, 1.94M / 15.5k (no felt change) / "she must make the chance" -> v0.1.7, 33 min, 0.87M / 8.6k / "still once or twice; HOOKED! big for me too" -> v0.1.8, 29 min, 1.11M / 9.7k | **v0.1.8** | Vesper 0.8-1.2 harpoons (was 0.2); my hand ~1 hook | 3600 f, 0 errors, cb37c372 twice; 18000 f x2, 0 errors | `clips/j2nd_biplane_v015_harpoon.mp4`, `clips/j2nd_biplane_v018_vesper_harpoon.mp4` |
| Half-court 3 v 3 | NBA Jam alley-oop off the glass on C: slow beat, push-in, mate slams, ALLEY-OOP!, STOLEN!, brick | 1 -> v0.1.7, 147 min (about 60 of them a phantom failure; finding 3), 4.32M / 37.3k / "the bots' never work; twice as big" -> v0.1.8, 74 min, 4.03M / 25.0k | **v0.1.8** | rival oops 0.9-1.0 landed (was 0 of 4); steals 0-0.6 | 3600 f, 0 errors, 60552975 twice; newcomer 11/20 (card 13), perfect 16/20 | `clips/j2nd_court_v017_alleyoop.mp4`, `clips/j2nd_court_v018_bots_oop_stolen.mp4` |

Total editor spend on this lane: 43 model calls (builders and the Planner), about 24.8M tokens in (most of them cache reads) and
216k out over 10 promotions.

**For the owner to play** (pack paths for the Director's menu rows; keys: karts F fire a shell, Q jump, E whirl;
biplane Q harpoon, Shift roll out of her ring; court C alley-oop with the ball):
- `C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-kart/.tl/jobs/j2nd/bumper-kart-football-3-20261125-1/promoted/game.bumper_kart_football_3@0.1.10`
  - "Bumper-kart football v0.1.10: red shells (made in Create, juice day)"
- `C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-kart/.tl/jobs/j2nd/biplane-duel-two-biplanes-20261125-1/promoted/game.biplane_duel_two_biplanes@0.1.8`
  - "Biplane duel v0.1.8: harpoon whip (made in Create, juice day)"
- `C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-kart/.tl/jobs/j2nd/half-court-3-v-20261125-1/promoted/game.half_court_3_v@0.1.8`
  - "Half-court v0.1.8: alley-oop off the glass (made in Create, juice day)"
- The in-between versions (karts v0.1.8 = v0.1.7's play; v0.1.9; biplane v0.1.5-v0.1.7; court v0.1.7) are in the same
  `promoted/` folders and need no rows.

Nobody has played these with real keys: every figure comes from scripted hands (the pack's own perfect/sharp hands plus
my counting tests in `.tl/j2nd/tests/`), and every "feels" line comes from film.

**Editor findings** (details below): 1 landcheck vs the frozen tofu bot loop, with a false "NOT made" note; 2 a
non-drawing package's NOT DONE hand-off never routed to the package that owns the file (core <-> items deadlock, a
version promoted with the ability unwired); 3 a Godot run that never started (at the second another job promoted) is
charged to a package, which then changed a rule to "fix" it, and that rule is not on the card; 4 the deadlock goes on
after a plain follow-up; 5 a person's answer ("let your check run longer") cannot be honoured because the check is
frozen; 6 a builder's process remark shown as an unmade part; 7 "RULE: none added" shown as an unasked rule.

## Juice sheets (written 11:25-11:40, before the first sentence)

### 1. Bumper-kart football: the red shell (Mario Kart items)
First ability (night): jump, flip double jump, aerials, air bump. This one is unlike it: an item you pick up and
throw, a ranged attack on the deck.
- **Key:** F (free in v0.1.7; Space bump, Q jump, E whirl, Shift boost).
- **Wind-up (anticipation):** three rainbow item boxes spin over the deck; driving or hopping through one gives a red
  shell that spins over the holder's tub, so every kart sees who holds one. Firing it: the shell drops to the planks in
  front of the nose, glowing.
- **Exaggeration, in numbers:** the shell skims at about 25 m/s (faster than any kart, cruise 12 / boost 18), homing on
  the nearest rival ahead; a hit throws the kart about 3 m up in a spinning tumble (two full turns), about 1.5 s out of
  play.
- **Impact:** BANG, sparks, hit-stop, camera kick, SHELLED! big mid-screen (lane T's rule: impact words mid-screen).
- **Bots with it and against it:** the mint karts grab boxes, fire at the nearest rival ahead; a kart that sees a shell
  coming jumps (Q) over it or whirls (E) to swat it.
- **Counterplay / cost:** jump over it (the night's jump finds a second use), whirl to swat it away; one shell at a
  time; boxes respawn after 8 s, so there is a race to the boxes.
- **Copies:** Mario Kart (item box, red shell homing, the hop-dodge), Rocket League Rumble (power-ups in a ball game).

### 2. Biplane duel: the harpoon whip (a whaling gun on a cable)
First ability (night): loop, barrel roll, smoke and shoot-downs. This one grabs the rival instead of out-flying her.
- **Key:** Q (free in v0.1.4; E loop, Shift roll, Space/F guns, C look back).
- **Wind-up:** with Vesper in front within about 60 m, a red ring closes around her for half a second (30 frames): she
  can see it coming and roll.
- **Exaggeration:** the harpoon flies on a cable and hooks her tail; the cable whips her round in a huge arc and flings
  her away tumbling and trailing smoke, out of control for about 2 s.
- **Impact:** CLANK, hit-stop, camera kick, HOOKED! mid-screen; a free shot window for the hooker.
- **Bots:** Vesper harpoons me when I fly in front of her; she rolls when my ring closes on her.
- **Counterplay / cost:** a barrel roll while the ring closes dodges it; a lot of energy and a long cooldown, so it is a
  decision, not spam.
- **Copies:** Just Cause (the grapple tether), Star Wars Battlefront's snowspeeder tow cable, Crimson Skies' one-key
  specials.

### 3. Half-court 3 v 3: the alley-oop off the glass (NBA Jam)
First ability (night): sky jump, dunk, block, on fire (a solo move). This one is a TEAM move: the ball goes to a mate in
the air.
- **Key:** C (free in v0.1.6; Space shoot, Q pass, E screen, F dunk, Shift turbo).
- **Wind-up:** an open teammate raises a glowing hand (he calls for it); the ball goes high off the backboard and the
  whole court slows for a beat while it hangs over the rim.
- **Exaggeration:** the catcher sky-jumps from wherever he is, catches it above the rim and slams it.
- **Impact:** ALLEY-OOP! mid-screen, a rim shake, the camera pushes in (the night's dunk camera).
- **Bots:** both teams throw alley-oops about once a minute; defenders leap to contest.
- **Counterplay / cost:** a defender near the catcher can snatch it off the glass (STOLEN!); a late catcher bricks it
  off the rim.
- **Copies:** NBA Jam (alley-oops off the glass), NBA Street (the off-the-backboard pass).

## Log (chronological across the three jobs; they ran side by side)

### Sends (all three dry starts checked within 2 minutes: the Planner answered, a builder runs)
- **Karts**, 11:24:25, log `.tl/jobs/_ui_logs/1795775065-j2nd-kart-change.log`, event 1295. The Planner (6 s) **added a
  new package `items`** ("a new pickup-and-weapon mechanic that no package's files cover") and asked core to wire it in
  (event 1303). items r1 running at 11:25:53.
- **Court**, 11:25:11, log `.tl/jobs/_ui_logs/1795775111-j2nd-court-change.log`, event 1323. The Planner named
  court_exchange (r13), and **lane T's fix shows at once**: "[foreman] the rivals' part of change request 1323, for the
  bots your files drive (scripts/crews/brain.gd)" went to crews_stakes as its own request (event 1326, r13 queued).
- **Biplane**, 11:25:57, log `.tl/jobs/_ui_logs/1795775157-j2nd-plane-change.log`, event 743. The Planner (4 s) named
  core ("a new move in the existing moves system, and core owns everything it touches ... including Vesper's
  counter-roll and her own harpoon"); core r24 running at 11:26:03.

### What the builders did in their first rounds (from the job events, 11:28-11:42)
- **Karts:** items r1 (2.2 min, 1.49M in / 17.9k out) built boxes, the held shell (it rises and pulses with a beep for a
  24-frame tell before a bot fires), the homing shell with a red trail, the tumble (3 m arc, 2 rolls, squash, dust),
  SHELLED! on a centre label, jump-over and whirl-swat, bots that fire, jump and whirl; "NEW MOVE: red_shell". Its
  hand-off ("NOT DONE: ... needs scripts/main.gd ... add "items" to the module list") went to core as the Planner's
  wire-in request (core r19). Core r20 found an unknown sound (`hit_steel`) and handed a one-line fix back to items.
  Said plainly by items: bots do not detour to boxes (they take one their route crosses), and the hit-stop is on the
  victim only.
- **Court:** court_exchange r13: `oop` on C, a lob off the glass scripted by `scripts/core/oop.gd`, the catcher uses the
  dunk's flight (slow beat, rim close-up, slam, hang), ALLEY-OOP! and STOLEN! on the centre banner (and the banner's
  blank-line padding, last night's "tall black slab", is gone), a new miss cause `brick`, a glowing orb over the open
  mate's hand; RULE lines: bots lob about once a minute per crew, rivals within 3 m of the rim contest a lob
  (0.35/0.5/0.65 by tier). crews_stakes r13 runs for the rivals' part.
- **Biplane:** core r24 (6.7 min): `harpoon` on Q, a red ring closing from 300 to 70 px over 30 frames, an 8-frame
  flight, CLANK + a 10-frame freeze + shake 0.3, HOOKED! big, a 42-frame whip through 200 degrees and a 78-frame
  tumble, fling at 32 m/s, smoke; Vesper's harpoon (2 % a frame while I am in front, at most every 15 s) and her roll
  off my ring (60 %). The rope and ring are drawn on the HUD layer. Balance note, not a refusal: "skill_spread now
  0.22, was 0.7".

### Two editor findings met by 11:58 (blocked-editor lines, for the Director and lane T)
1. **Biplane: two of T's rules in a loop.** The "new attack must land" check (`landcheck.ts`) asks core for
   `moves.harpoon` in "a bot test your acceptance runs". Core's acceptance runs only `tests/bot_tofu.gd`, which the
   "measure kept" freeze protects. Core r25 and r26 each put the count in the tofu bot, the Foreman undid the edit
   (events 761, 772), and the lands check failed again (757, 768). After 3 rounds the Foreman merged core r26 with the
   note (event 778): "part of your change was NOT made by core: the new move harpoon does not land in the Foreman's bot
   run (harpoon not counted) after 3 rounds ... Say it again (for example "the harpoon never hits anyone")". **But the
   harpoon does land:** my own counting test on core's workspace after r24 (3600 frames, seed 1, 0 script errors) saw
   `hooked:me 1` of 3 tries. The note tells a person their ability failed when only the measure could not count it.
   Evidence: `reports/core-r24-move-lands-s757.json`, `reports/core-r25-move-lands-s768.json` in the biplane copy.
2. **Karts: a hand-off from a non-drawing package does not come back.** Items r1 named `TLAudio.play("hit_steel")`,
   which is not an engine preset. Core (which wires items in) hit the script error in its bot run (frame 2890) and
   wrote the exact one-line fix for `scripts/items/items.gd` in r20, r21 and r22 ("NOT DONE: ... outside my scope").
   The Foreman never sent it to items: core r22 ended "no round passed ... the change was NOT made" (event 1356), and
   then the Foreman reopened core AGAIN for items' own hand-off (event 1357, core r23), which fails the same way
   (event 1365). T's fix routes a drawing package's NOT DONE to the cartridge owner; this hop (core -> items, the
   package that owns the broken file) is not covered. Evidence: events 1337, 1344, 1351, 1355-1361,
   `reports/core-r21-bot-s1348.json` (the script error).

## Biplane duel: the harpoon whip

### Change 1 -> v0.1.5 (sent 11:25:57, promoted 12:17:15: 51 min)
- Path: Planner 4 s -> core r24, r25, r26 (r25 and r26 only fought the lands check, see finding 1 above); the other
  four packages re-verified unchanged; promotion 6. **Cost: 4 model calls (the Planner included), 3.38M tokens in (3.13M cache reads),
  33.5k out.** Hands as the Foreman ran them: final checks V0-V4 ok.
- The done card's notes, as a person reads them: "part of your change was NOT made by core: the new move harpoon does
  not land" (false, see below); "balance moved ... how much the timing of the core move matters: now 0.22, was 0.7";
  three "unasked rule" lines (new events; Vesper's 2 %/frame harpoon at most every 15 s; only while her own mind flies).
- v0.1.5 = my film copy byte for byte except my test (`diff -rq`: only `pack.json` tests list and `tests/j2_harpoon.gd`).
- **Headless** (`tests/j2_harpoon.gd`: the pack's sharp pilot, E when tailed, Q when she sits in front within 55 m and
  15 degrees): seed 1, 3600 frames, **0 script errors, hash 676cd680 twice**; 18000 frames (5 min) seed 1, 0 errors,
  hash 34f7c149: **my harpoon 9 tries, 3 hooks (1.8 tries and 0.6 hooks a minute); Vesper 1 try, 1 hook (0.2 a
  minute)**; she rolled 32 times in 5 min (6.4 a minute) and deflected 6.
- **On film** (`clips/j2nd_biplane_v015_harpoon.mp4`, 16 s, two hooks; window, d3d12 movie writer, seed 1; stills
  `stills/biplane_v015_hook_sheet.jpg`, `stills/biplane_v015_cable_taut.jpg`, `stills/biplane_v015_whip_fling_sheet.jpg`):
  - a red ring closes round her blue plane; the cable snaps out as a yellow-white line between the two planes and
    HOOKED! fills the middle of the screen in red;
  - she is swung round my plane in a big arc and thrown off upside down, trailing black smoke puffs, and I come round
    behind her; in the second hook she is flung far across the sky with a long trail of smoke.
  - How it feels (from film, not my hands): it reads at a glance and it is funny, the best moment is the whip. The
    cable is thin (a HUD line) and the freeze is short; the camera stays behind me, so her tumble is small on screen.
  - Missing as a person sees it: Vesper almost never does it to me (once in 5 minutes).

### Follow-up -> (sent 12:19:32, log `.tl/jobs/_ui_logs/1795778372-j2nd-plane2-change.log`, event 813)
> Vesper almost never uses her harpoon ... count her hooks and mine in your own check so it stops saying that.
- Planner: core (r27), naming "the bot check that co[unts it]".

## Bumper-kart football: the red shell

### Change 1 -> v0.1.8, promoted with the shell NOT in the game (sent 11:24:25, promoted 12:33: 68 min)
- Path: Planner (6 s) added package `items`; items r1 merged (its own checks pass because it is not loaded: "while
  unwired it ends at frame 60 with ok true"); core r19-r22 (wire-in) and r23-r26 (items' hand-off) all failed on the one
  unknown sound and were thrown away (finding 2 above); the final checks passed on a pack whose core never loads items.
  **Cost: 12 model calls (the Planner included), 3.79M tokens in (3.00M cache reads), 41.6k out.**
- The done card, as a person reads it: "part of your change was NOT made by items: the new move red_shell was not seen
  to land ... Say it again", and the builder's "Untested: items.gd has never run in a match, because the core does not
  load it yet". So the card does tell a person, in the builder's words, but promotes a version anyway.
- **Measured:** v0.1.8 (`tests/j2_shell.gd`, 3600 frames, seed 1): 0 script errors, **hash f894a8bb, the same hash as
  v0.1.7** (last night's J5 figure): v0.1.8 plays exactly as v0.1.7. No `items` state, no box, no shell. Not filmed
  (nothing new to see).

### Follow-up (sent 12:33:51, log `.tl/jobs/_ui_logs/1795779229-j2nd-kart2-change.log`), a person who read the card
> I played v0.1.8 and there are no item boxes at all ... use hit_metal for the BANG ...
(Honest note: "I played" is the person's voice; I checked it by the hash above and by `scripts/main.gd`'s module list,
not with my own hands.)

### Editor findings 3 and 4 (12:45)
3. **A Godot run that never started is judged as the package's failure.** At 12:32:57-58 (the second the kart copy
   promoted v0.1.8), two Godot runs in the OTHER two jobs failed to start: court's final hand check seed 7
   (`reports/final-hand-perfect-seed7-s1417.verdict.json`: "the runner wrote no report file", 1.5 s, flags
   `stdout_not_json`, `report_missing`) and biplane's rival_season re-verify (events 839, 843: lint "the runner wrote
   no report file", 0.9 s). The court's hand check then read "19 of 20 runs finished; 19 of 19 won" as a FAILED card
   check and sent crews_stakes a repair round r14 (event 1432: "a second failure ends the job unpromoted"); biplane's
   rival_season got a round whose builder said "No change this round. The Verifier's crash ... did not happen in my
   runs" (event 846). Three jobs share one `engine/` here, as three Create jobs would on one machine. Likely cause (not
   proven): the promotion's engine work (import or class cache) racing other jobs' Godot starts. The Foreman should
   re-run a check that never started instead of charging a package for it.
4. **Karts: the deadlock goes on after a person's plain follow-up.** My follow-up named both fixes. The Planner sent
   it to core (r27) and also queued items r2 (event 1446), but items runs after core, and core cannot pass while
   items' sound is broken: core r27-r30 each wrote "NOT DONE ... needs scripts/items/items.gd" again. Items r2 waits.

## Half-court 3 v 3: the alley-oop off the glass

### Change 1 (sent 11:25:11): court_exchange r13 + crews_stakes r13 merged first time; final checks running at 12:30
- Path: Planner (5 s) -> court_exchange r13 (3.6 min) and, by lane T's fix, the rivals' part to crews_stakes r13 as its
  own request; both merged on their first round, no refusal, no bend. Then the final hand checks (see finding 3).
- **Measured on the merged pack** (`.tl/j2nd/film/court_c1`, the job's `pack/` after both merges, before the final
  checks; `tests/j2_oop.gd`: the pack's player hand, and with the ball it presses C about every 6 s of holding it):
  - seed 1, 3600 frames: **0 script errors, hash 705c52b6 twice**;
  - one whole match (14980 frames, 4.2 min, 0 errors, crew 21 - quarry 11): **my alley-oops 14 thrown, 9 caught and
    slammed by my mates, 5 bricked**; **rival bots 4 thrown, 4 bricked, 0 caught; my bot mates 0 thrown; 0 steals**
    (the rivals' contest rule exists, but no `oop_stolen` in the match). Per live minute: my oops 3.4 (my hand's
    choice), rival oops 0.96, rival oop dunks 0.
- **On film** (`clips/j2nd_court_v017_alleyoop.mp4`, 12 s, three cuts, window, seed 1; stills
  `stills/court_v017_alleyoop_sheet.jpg`, `stills/court_v017_alleyoop_slam.jpg`, `stills/court_v017_rival_brick_sheet.jpg`):
  - I lob from the top; the ball hangs at the glass, the camera pushes in on the rim, my yellow mate floats up from
    the side, high over the rim, and slams it; ALLEY-OOP! in cyan on a dark strip in the middle of the screen as the
    camera snaps back. It reads as a team play, and the hang above the rim is the picture.
  - Weaker than asked: the ALLEY-OOP! word is mid-size on a small slab, not big; the glowing hand of the open mate
    is too small to see from the play camera; the slow beat is the dunk's (fine).
  - The rivals' lob: the ball sails from the corner to the glass and nobody goes up: a brick every time.
   - **What the phantom failure cost (13:05):** crews_stakes r14 could not reproduce a failure, so it changed a game
     rule to make "that last run finish": sudden death now ends when a side has ADDED 2 points since the tie (event
     1435, merged: `data/crews.json` `crews.sudden_add`, `scripts/crews/mod.gd`, "goes beyond the seams the contract
     lists"). It cites the brief's own line, so it may be right, but nobody asked for it in this change and the run it
     "fixed" never started.

### Biplane follow-up 1 -> v0.1.6 (sent 12:19:32, promoted 13:06:16: 47 min)
- core r27 (one round): Vesper's `rival_rate` 0.02 -> 0.2 a frame, `rival_cooldown_f` 900 -> 2400 (40 s), her own cone
  32 degrees; an unasked RULE: she holds her bursts to save energy for the harpoon. Its edit to count hooks in the tofu
  bot was undone again ("measure kept", event 821); rival_season r3 then counted the harpoon in `tests/bot_season.gd`
  (a test it owns), and **the false "NOT made" note is gone** from v0.1.6's card. (rival_season r3 was itself the
  round that the phantom start failure opened, finding 3.) harvest_look r2 also re-ran.
- **Cost: 4 model calls (the Planner included), 1.94M tokens in (1.73M cache reads), 15.5k out.**
- v0.1.6 = my film copy `plane_r27` (diff: only my test). Headless 18000 frames seed 1: **0 script errors**, hash
  f841a320; **Vesper's harpoon: 1 try, 1 hook in 5 minutes, the same as v0.1.5**; mine 10 tries, 3 hooks. The builder
  said so itself: "below once a minute, because the bot's pilot rarely flies in front of her". A person chasing her
  is never in front of her, so a rate change alone does nothing they can feel.

### Biplane follow-up 2 (sent 13:07:06, log `.tl/jobs/_ui_logs/1795781226-j2nd-plane3-change.log`)
> v0.1.6 still plays the same ... She has to make the chance herself: when her harpoon is ready, she breaks off, swings
> round and comes at me head-on or pulls up under my nose ...

### Karts follow-up, what happened next (12:47-13:16)
- After core's four rounds failed (r27-r30), items r2 finally ran (event 1479): it fixed `hit_steel` -> `hit_metal`
  and merged. Core r31 then wired items in and its own bot passed, but the merge was refused on the whole pack's tofu bot
  (event 1514: "2 matches" finished, skill_spread 0).
- **Preview, core r31's workspace** (items wired, sound fixed; `tests/j2_shell.gd`, 3600 frames seed 1): 0 script
  errors, hash 43c1fce2; per live minute **mint karts 5.3 boxes and 5.3 shells fired, my mates 3.2 fired and 3.2 hits,
  mint 1.1 hits; my hand fired 1 and jumped over 2 shells (`jump_dodge`)**. The shell game works once it is switched on.
- Core r32 (7.3 min, 1.03M in) then asked the person (event 1518): "Should the pack's own test get through three
  matches quicker with wider goals (about 9 m each side of centre instead of 7), or with a shorter match (2 minutes
  instead of 3)?" Its note: a bot match scores 4-5 goals in 180 s, so the frozen tofu bot's 3 matches do not fit its
  36000 frames. The job paused.
- **My answer as the person** (13:15:35, `answer` then `resume`, as Create's door does; log
  `.tl/jobs/_ui_logs/1795781735-j2nd-kart-answer.log`): "Neither: keep the goals at 7 m and the match at 3 minutes,
  that is how I want it to feel, and the shells are meant to take karts out of play for a moment. Let your own check
  run longer instead of changing my game."
- 13:27: core r32 merged (`scripts/main.gd`, `data/tuning.json`, `README.md`): items is now loaded; its edit to the
  tofu bot was undone (event 1526: **finding 5, the person's answer "let your own check run longer" cannot be
  honoured**, because the check is a frozen measure), and its note says the match clock now counts live frames and
  drag/top speed went back to the contract's values. The whole-pack tofu bot passed this time.
- **Measured on the merged pack** (`.tl/j2nd/film/kart_r32`; `tests/j2_shell.gd` 3600 frames seed 1): **0 script
  errors, hash b1b63915 twice**. Per live minute (0.8 live min): **mint karts 7.5 boxes and 7.5 shells fired, 3.75
  hits; my mates 1.25 fired, 1.25 hits, 1.25 jumps over a shell; my hand 2.5 fired**. No whirl swat seen in this
  minute. Jumps and aerials stay (bots 27.5 jumps, 18.8 aerials a minute).
- **On film** (`clips/j2nd_kart_v019_shells.mp4`, 12 s, five cuts, window, seed 1; stills
  `stills/kart_v019_shelled.jpg`, `stills/kart_v019_box_fire_tumble_sheet.jpg`):
  - rainbow cubes float over the deck; a kart that holds a shell carries a small red disc; karts flip and tumble in
    the scrums (some are the night's air flips);
  - SHELLED! comes up mid-screen in plain white letters, mid-size;
  - How it feels as a person meets it: the shell game is busy and the bots clearly use it (mint fire every 8 s), but
    the hit itself is weak on screen: the shell is a small dot from the play camera, the hit kart rises a little
    rather than flying in a big spin, and the word is small. It is the J4b lesson again: the sentence named the juice,
    but "a few metres up in a spinning tumble" reads as small from this camera.

### Biplane follow-up 2 -> v0.1.7 (sent 13:07:06, promoted 13:40:19: 33 min)
- core r28 (one round): when her harpoon is ready Vesper's inputs are overridden to steer at a point ahead of and
  below me ("hunt"; not near the wall or the ground); a new double red ring closes round the screen centre with
  "HARPOON! ROLL" while she aims. Balance note: skill_spread 0.22 (was 0.34), lead_change_share 0.25 (was 0.67).
  **Cost: 2 model calls (the Planner included), 0.87M tokens in (0.79M cache reads), 8.6k out.**
- v0.1.7 = my film copy `plane_r28` (diff: only my test). Headless seed 1, 3600 frames: **0 script errors, hash
  464aebf0 twice**. 18000 frames: seed 1 **Vesper 2 tries, 1 hook** (me 14 tries, 5 hooks), hash 78b4d84f, 0 errors;
  seed 2 **Vesper 1 try, 0 hooks** (me 12 tries, 6 hooks), 0 errors. So **Vesper harpoons 0.2-0.4 times a minute
  against a sharp hand that chases her**: better than nothing, not the "about once a minute" I asked for twice.
  My own harpoon lands about 1 a minute (5-6 hooks in 5 min) and is the star of the game.

### Court change 1 -> v0.1.7 (sent 11:25:11, promoted 13:52:42: 147 min, of which about 60 min were the phantom
### hand-check failure and its repair round)
- **Cost: 4 model calls (the Planner included), 4.32M tokens in (4.03M cache reads), 37.3k out.**
- The done card lists two "unasked rule" lines (the bots' lob timer; the rivals' contest chance), and a false "part of
  your change was NOT made: court_exchange made what it could and says: Not done this round: `bot_tofu`, smoke and
  invariants were not rerun after the change" (**finding 6**: a builder's process remark is shown to a person as an
  unmade part of the game). **The sudden-death rule that crews_stakes r14 added (finding 3) is NOT on the card**: it
  was not written as a `RULE:` line, so a person never hears of it.
- v0.1.7 differs from my film copy `court_c1` only in crews_stakes r14's two files (sudden death). Headless v0.1.7,
  seed 1, 3600 frames: **0 script errors, hash 705c52b6 twice (the same hash as court_c1: sudden death starts only
  at a tie at 5:00)**, so the film and the whole-match figures above stand for v0.1.7.

### Court follow-up (sent 13:54:41, log `.tl/jobs/_ui_logs/1795784080-j2nd-court2-change.log`)
> My alley-oops work, but the bots' never do ... make ALLEY-OOP! twice as big ...
- **On film** (`clips/j2nd_biplane_v017_vesper_hooks_me.mp4`, 6 s, frames 11650-12010, seed 1; stills
  `stills/biplane_v017_harpoon_roll_warning.jpg`, `stills/biplane_v017_vesper_harpoon_flies.jpg`,
  `stills/biplane_v017_vesper_hook_sheet.jpg`): she swings round beside me, a big red ring closes in the middle of my
  screen with **HARPOON! ROLL** under it and a small ring on my own plane; her harpoon (a red ball on a black cable)
  flies from her nose; I am hooked and whipped round under her, with "HOOKED by Vesper! Roll when her red ring closes
  on you." on the hint line. The warning reads at once and gives a person a real decision (roll now). When she hooks
  me the HOOKED! word is only on the hint line, not big as mine is.
- My own harpoon is unchanged since v0.1.5 (`clips/j2nd_biplane_v015_harpoon.mp4` shows it).

### Karts follow-up 1 -> v0.1.9 (sent 12:33:51, promoted 14:05:31: 92 min, incl. a 1-min pause for my answer)
- **Cost: 10 model calls (the Planner included), 3.86M tokens in (3.30M cache reads), 28.9k out.** Path: core r27-r30 (failed, the
  deadlock), items r2 (the sound), core r31 (merge refused on the pack tofu), core r32 (question, my answer, merged),
  show r2 (the board clock follows core's live-frame clock), dependents re-verified, 40 hand matches.
- The card: "part of your change was NOT made by items; it went on to core, which made it" plus the builders' notes.
- v0.1.9 = my measured `kart_r32` plus show r2's clock (`scripts/show/show.gd`). Headless `tests/j2_shell.gd` 3600
  frames: seed 1 **0 script errors, hash b1b63915 twice** (the same as kart_r32); seeds 2 and 3: 0 errors. Per live
  minute over seeds 1-3: **mint karts fire 6.3-7.5 shells and hit 2.1-3.75; my mates fire 1.25-2.1 (hits up to
  1.25); dodges by a jump 1-4 (mint karts jump over shells in seed 3: 3.2 a minute); one swat (whirl) by a mate in
  seed 2.** The film above (core r32's pack) shows v0.1.9's play (same hash).

### Karts juice follow-up (sent 14:08:41, log `.tl/jobs/_ui_logs/1795784921-j2nd-kart3-change.log`): J4b's method
> The shells work ... but a hit is hard to see from the play camera. Make it big: the shell twice the size ... a red
> warning arrow over my kart while a shell is homing on me, so I can jump it in time.

### Court follow-up: what the builders made (court_exchange r14 merged 14:06, crews_stakes r15 merged 14:21)
- court_exchange r14 found the cause itself: "the catcher ran to the rim on foot ... and could not cover up to 8 m
  before the ball got there". Now the teammate nearest the rim sky-jumps as the ball leaves the hand and flies to the
  rim; my bot mates throw to me; contesting defenders drift toward the ball in the air (STOLEN! can happen, reach
  1.5 m); ALLEY-OOP! and STOLEN! on their own HUD layer at 120 pt ("about twice the old banner size"); the glowing hand
  radius 0.16 -> 0.42 m. The Foreman: "new move lands in the Foreman's bot run: alley_oop landed 5 of 7". crews_stakes
  r15 (the rivals' part, routed by T's fix): defenders within 4.8 m of the rim decide once per lob to leap (0.30/0.45/
  0.60 by tier), a `RULE:` line.
- **Measured on the merged pack** (`.tl/j2nd/film/court_c2`, `tests/j2_oop.gd`, one whole match, 11752 frames, seed 1):
  **0 script errors**, crew 21 - quarry 10. **Rival bots: 3 alley-oops thrown, 3 caught and slammed (was 4 thrown,
  0 caught). Mine: 9 thrown, 7 caught, 2 STOLEN! by rivals (was 0 steals).** My bot mates threw 0 (my hand keeps the
  ball when it has it; the mates had it 9 times). Per live minute: rival oops 0.9 landed, steals 0.6.
- **On film** (`clips/j2nd_court_v018_bots_oop_stolen.mp4`, 10 s, three cuts, seed 1; stills
  `stills/court_v018_alleyoop_big.jpg`, `stills/court_v018_stolen_sheet.jpg`, `stills/court_v018_rival_oop_sheet.jpg`):
  - my lob is snatched off the glass: **STOLEN!** big in cyan across the top of the court;
  - my next lob: my mate hangs above the rim and **ALLEY-OOP!** now fills a third of the screen width, black-outlined
    cyan, impossible to miss;
  - a rival throws from the wing, the camera pushes in on his mate rising over the rim, he slams it, ALLEY-OOP! again:
    the game answers the move now.
  - The glowing hand is still hard to pick out at play distance in my stills.

### Karts juice follow-up: what the builder made (items r3, merged about 14:20, first round)
- Routed to items in 6 s ("everything asked for here is specific to the homing red shell"). items r3: the shell 0.6 ->
  1.2 (1.56 m across in flight), the trail twice as wide and 40 frames long, a brighter red; the tumble in three parts
  (40 frames in the air, a 3 m arc and 2.5 rolls; 24 frames upside down; 20 frames rolling upright); smoke at the hit;
  a whole-deck freeze of 6 frames when I am the victim or the shooter ("which the contract's 'hit-stop on the victim
  only' did not have": said plainly); SHELLED! at 96 pt red with a dark outline on its own HUD layer; a red warning
  arrow over my kart while a shell homes on me. The glow is a halo disc, "a real light counted as a kit bypass in lint,
  so I removed it".
- **Measured on the merged pack** (`.tl/j2nd/film/kart_r3`, `tests/j2_shell.gd`, 3600 frames seed 1): 0 script errors,
  hash f7b64a26; per live minute mint 6.9 shells fired and 2.3 hits, mates 2.3 fired and 2.3 hits, dodges by a jump:
  mates 2.3, mint 1.1, my hand 1.1.
- **On film** (`clips/j2nd_kart_v0110_juiced_shells.mp4`, 9.6 s, three cuts, seed 1; stills
  `stills/kart_v0110_shelled.jpg`, `stills/kart_v0110_shelled_tumble_sheet.jpg`, `stills/kart_v0110_shell_streak_warning_sheet.jpg`,
  `stills/kart_v0110_my_shell_hits_sheet.jpg`):
  - at the kick-off a mint shell hits my kart in front of the ball: my tub goes up and over, upside down in the
    middle of the screen under a big red **SHELLED!**; it now reads at a glance;
  - a red shell with a long orange streak skims in from the corner toward a pack of karts; a red marker bobs over the
    target;
  - I fire, the shell streaks off and SHELLED! pops at the far end.
  - How it feels: this is the J4b result again: the second sentence that NAMED the juice (size, spin, freeze, word,
    warning) turned a busy-but-small hit into a moment. The victim far away is still small from the follow camera.

### Biplane follow-up 3 (sent 14:13:40): what the builder made (core r29, merged about 14:20, first round)
- Vesper's hunt and shot now run under every mind that flies her (before, only round 1's: the reason rounds 2-3 had
  almost none); her cooldown 40 s -> 30 s; a RULE: the longer she hunts, the wider her firing angle (32 -> 45 degrees
  over 15 s); HOOKED! big for both sides; the camera pulls back while I am whipped (`cam.request`).
- **Measured on the merged pack** (`.tl/j2nd/film/plane_r29`): seed 1, 3600 frames: **0 script errors, hash cb37c372
  twice**; 18000 frames: **seed 1 Vesper 6 tries, 1 hook** (me 16 tries, 7 hooks), 0 errors, hash fc38a913; **seed 2
  Vesper 4 tries, 0 hooks** (me 14, 4). So **Vesper now fires 0.8-1.2 times a minute, as asked**; the sharp hand
  rolls out of most of them (the counterplay works), so her hooks stay rare against a sharp player.

### Karts juice follow-up -> v0.1.10 (sent 14:08:41, promoted 14:41:17: 33 min) **<- the karts pick**
- items r3 only, first round, no refusal, no bend; dependents re-verified; 40 hand matches. **Cost: 2 model calls (the Planner included),
  1.49M tokens in (1.39M cache reads), 15.8k out.** Hands over 20 seeds (the Foreman's final checks): **newcomer 17 of
  20, perfect 19 of 20** (v0.1.9: 16 and 19; v0.1.7: 18 and 18). The newcomer hand never presses F, so this says the
  shells did not break the match for someone who ignores them, not how hard the shells are.
- v0.1.10 = my filmed `kart_r3` (diff: only `pack.json`'s tests list). Headless `tests/j2_shell.gd` 3600 frames: seed 1
  **0 script errors, hash f7b64a26 twice**; seeds 2 and 3: 0 errors (d6d0a355, 772de0e9). Per live minute over seeds
  1-3: **mint karts 5.5-6.9 shells fired, 1.1-2.3 hits; mates 1.1-2.3 fired; jump-dodges 1-3 a minute across karts;
  a whirl swat by a mate in seed 2.**

### Biplane follow-up 3 -> v0.1.8 (sent 14:13:40, promoted 14:43:08: 29 min) **<- the biplane pick**
- core r29 only, first round; dependents re-verified. **Cost: 2 model calls (the Planner included), 1.11M tokens in (1.03M cache reads),
  9.7k out.** One "unasked rule" on the card (her firing angle widens while she hunts).
- v0.1.8 = my measured `plane_r29` (diff: only `pack.json`'s tests list), so the figures above are v0.1.8's: **0 script
  errors, hash cb37c372 twice; Vesper 0.8-1.2 harpoons a minute; mine about 1 hook a minute.**
- **On film** (`clips/j2nd_biplane_v018_vesper_harpoon.mp4`, 8.3 s, two cuts, seed 1, frames 5436-5676 and
  10500-10800; stills `stills/biplane_v018_hooked_by_vesper.jpg`, `stills/biplane_v018_vesper_hooks_me_sheet.jpg`,
  `stills/biplane_v018_warning_escape_sheet.jpg`):
  - her ring and HARPOON! ROLL close on me and I climb out of it: the warning is a real decision;
  - later she gets me: the camera pulls back, a long cable runs from her blue plane to my orange one, **HOOKED!** big
    and red mid-screen, and I am swung round her and thrown off with smoke. Now the game does to me what I do to it.

### Court follow-up -> v0.1.8 (sent 13:54:41, promoted 15:08:13: 74 min) **<- the court pick**
- court_exchange r14 and crews_stakes r15, each first round; no refusal, no bend. **Cost: 3 model calls (the Planner included), 4.03M
  tokens in (3.84M cache reads), 25.0k out.** Hands over 20 seeds (the Foreman's final checks): **newcomer 11 of 20,
  perfect 16 of 20**; the card's note: "balance moved by your change: built as you asked; a newcomer player now wins 11
  of 20 (was 14 of 20). Say "make it fairer" to tune it" (the card's bound is 13). The card also shows "unasked rule:
  none added" as if it were a rule (**finding 7**, cosmetic: a builder's "RULE: none added" line is listed as an
  unasked rule).
- v0.1.8 = my measured `court_c2` (diff: only `pack.json`'s tests list). Headless seed 1, 3600 frames: **0 script
  errors, hash 60552975 twice**. Whole matches, 0 errors: seed 1 (11752 frames) rival oops 3 of 3 caught, mine 7 of 9
  with 2 STOLEN!; seed 2 (15003 frames, crew 21 - quarry 13) rival oops 4 of 4 caught, mine 11 of 11. **Rival bots
  land about 0.9-1.0 alley-oops a minute** (was 0); steals 0-0.6 a minute.

---

# Round 2 (Director's ask, 15:20): a newcomer's hands through the exe, one fix sentence per game, "make it fairer"

## How the newcomer played (method)
- **The exe** `C:/Users/kazda/kiro/third-life/dist/ThirdLife/ThirdLife.exe` (build 6522394) with `-- --dungeon=<pack>
  --seed=1`, the packs the owner has in his menu (`.tl/proof-games/j2_kart_shells`, `j2_biplane_harpoon`,
  `j2_court_alleyoop`), a window at 0,1440, `--write-movie` at 60 fps (it records 1920 x 1080), 4800 frames (80 s), the
  repo's window lock. Script: `.tl/j2nd/r2/execlip.sh`.
- **No real keyboard**: the exe's own instrument `TL_EXE_KEYS` presses and releases keys at physics frames (the same
  Input state a keyboard sets). The stream is a newcomer's, made by `.tl/j2nd/r2/keys.mjs` (seeded, open loop): he
  holds the obvious key (W), steers late in bursts of 15-80 frames, and presses the new key every 4-7 s whether or not
  it is the moment (karts F every 240-420 frames, Q now and then, sometimes twice; biplane Q every 300-450, Shift every
  400-700 not timed to her ring; court C every 200-360, shots held 18-40 frames). It does not react to the screen: that
  is the limit of an open-loop stream. The exact streams are saved beside each clip (`*.keys.txt`).
- **Closed loop, headless**, for numbers: the pack's own newcomer hand (`TLHand "newcomer"`, its reaction delays and
  misses) plus a person who has read the new key: `.tl/j2nd/tests/j2n_shell.gd`, `j2n_harpoon.gd`, `j2n_oop.gd`.
- All three exe runs: exit 0, 0 SCRIPT ERROR lines. Clips are 800 px wide, crf 32, 30 s.

## What a newcomer does not see or understand in the first 60 s
### Karts v0.1.10 (`r2/r2_kart_v0110_newcomer_exe_no_boxes.mp4`, `r2/r2_kart_newcomer_exe_80s_sheet.jpg`,
### `r2/r2_kart_newcomer_lesson_hint.jpg`)
- **He never meets a shell.** In 80 s there is not one rainbow box on the deck. The hint line says only "W drive, SHIFT
  boost, SPACE bump its side" the whole time.
- Why (read in the pack): items hides boxes and shells while `lesson_active()` (items r1's own note: "Hidden during
  lesson_active and far_loop_active"), and the core's lesson ends only when p1 spins mint_1. A newcomer who does not
  press Enter to skip the lesson and never spins mint_1 plays the WHOLE first match without the new ability.
- Headless proof: the newcomer hand, lesson on (`j2n_shell.gd`, seed 1): **3600 frames: 0 boxes, 0 shells; 10800
  frames (the whole first match, red won 3-0): 0 boxes, 0 shells, 0 warnings.** Every earlier figure of mine used a
  hand that skips the lesson, so this was hidden from round 1.
- The far shell victim and the warning arrow could not be judged by a newcomer: they never appear for him.
### Biplane v0.1.8 (`r2/r2_plane_v018_newcomer_exe.mp4`, `r2/r2_plane_newcomer_exe_80s_sheet.jpg`,
### `r2/r2_plane_newcomer_ring_from_far.jpg`, `r2/r2_plane_newcomer_lesson_alone.jpg`)
- **The first 40 s are a lesson with Vesper far away**: a small blue arrow at the edge of the screen. The hint "Harpoon:
  get Vesper in front of your nose, inside 60 m" never comes true; his Q presses meet "Harpoon needs 40 ENERGY".
- **When REAL FIGHT starts, three messages land in the same second**: REAL FIGHT, her big HARPOON! ROLL ring, and "W
  released while climbing: stall turn", while his energy bar reads EXHAUSTED, so he could not roll even if he
  understood. Her plane is a speck up in the corner when her ring closes on him.
- Then she sits behind him ("THEY WERE BEHIND YOU: roll or loop") and he is SHOT DOWN about 70 s in.
- Headless, newcomer hand (`j2n_harpoon.gd`, 18000 frames, seeds 1 and 2, 0 errors): **Vesper fires 7-8 harpoons in 5
  min (1.4-1.6 a minute) and the newcomer notices 1-2 of them; she hooks him 1 and 0 times** (the pilot's own constant
  rolls save him); his own harpoon lands 0 of 5 and 2 of 5; she wins the match both times.
### Court v0.1.8 (`r2/r2_court_v018_newcomer_exe.mp4`, `r2/r2_court_newcomer_exe_80s_sheet.jpg`,
### `r2/r2_court_newcomer_first_ball_no_c_hint.jpg`, `r2/r2_court_newcomer_rival_oop.jpg`)
- **Nothing tells him C exists.** In 80 s the hint line says HOLD E ON THE CHALK, SPACE: SWAT AS THEY RISE and CLEAR IT
  PAST THE ARC; never C. His open teammate's glowing hand is a few pale pixels at play distance (first still).
- He sees ALLEY-OOP! twice (bots' and his random C), big and clear; the rival oop's push-in shows the catcher over the
  rim, but nothing tells him he could jump to steal it.
- Headless, newcomer hand pressing C after 6 s with the ball (`j2n_oop.gd`, whole matches, seeds 1 and 2, 0 errors):
  he holds the ball rarely, so he throws 1 a match; **his bot mates throw 3 a match and all 3 are STOLEN by rivals**;
  rival oops land 4 of 4; he still wins 21-17 and 20-15 (the Foreman's newcomer check: 11 of 20).

## The fix sentences (one per game; court also "make it fairer")
- Karts, sent 15:27:47 (`.tl/jobs/_ui_logs/1795789667-j2nd-kart4-change.log`): boxes from the first kick-off lesson or
  not, the new keys in the lesson's hint line, a far-hit flash. Routed to items (r4).
- Biplane, sent 15:35:36 (`.tl/jobs/_ui_logs/1795790136-j2nd-plane5-change.log`): Vesper crosses in front of me once in
  the lesson; her first harpoon waits 10 s into the fight and never while I am too low to roll; one message at a time.
- Court, sent 15:42:09 (`.tl/jobs/_ui_logs/1795790528-j2nd-court3-change.log`): "C: ALLEY-OOP" over the open mate with
  a ring, a big pulsing glow, and "SPACE: JUMP TO STEAL IT" when rivals throw. **Then "make it fairer"** sent 15:42:41
  into the running Foreman's inbox (`.tl/jobs/_ui_logs/1795790561-j2nd-court4-change.log`).
- Small routing note: the Foreman split "When the rivals throw one, tell me in the hint line SPACE: JUMP TO STEAL IT"
  off as "the rivals' part ... for the bots your files drive" to crews_stakes (event 1640), though it is a hint line.

## Editor finding 8 (15:52): a rules change judged as "view or screen only"
- Biplane's newcomer sentence went to first_flight (event 990). Its builder wrote two `RULE:` lines that change play
  (in the lesson Vesper never rolls off my harpoon; after it her harpoon cooldown is held while my energy is below the
  roll's cost) and a 10 s hold on her first harpoon (event 994). The Foreman then said (event 1000): "balance not judged:
  a change to the view or the screen only; tests/bot_tofu.gd figures outside their bounds, not judged: skill_spread
  0.04 (bound 0.25 to 0.95); skill_variants 2 (bound 3 or more)". Lane T1's camera/HUD-only skip took a sentence that
  talks about messages as screen-only, and so a real balance move (skill_spread 0.04) went unjudged and unnoted to the
  person. Evidence: biplane copy events 994, 1000.

## Round 2 results: karts and biplane

### Karts newcomer fix -> v0.1.11 (sent 15:27:47, promoted 15:57:08: 29 min) **<- the new karts pick**
- items r4, first round. **Cost: 2 model calls, 1.12M tokens in (1.03M cache reads), 8.8k out.** Boxes and shells work
  from the first live frame, lesson or not; the lesson's hint line stages "Drive through a rainbow box" -> "F fires a
  red shell" -> "Q jumps over one"; a far hit (18 m or more from me) gets a red flash, a puff and a red ring over the
  victim. One unasked-rule line on the card (mint bots may fire at me during the lesson, "as the player asked").
- Hands over 20 seeds: **newcomer 16 of 20, perfect 19 of 20** (v0.1.10: 17 and 19).
- v0.1.11 = my film copy `kart_r4x` (no diff). Headless, the newcomer hand with the lesson on (`j2n_shell.gd`, 3600
  frames): seed 1 **0 script errors, hash 08fe071f twice**; **he picks up 2 boxes, fires 1, hits 1, is shelled once in
  his first minute** (v0.1.10: 0 of everything for the whole first match); seed 2: 1 box, 1 fired, shelled once.
- **The newcomer in the exe** (`r2/r2_kart_fix_newcomer_exe_a.mp4`, `r2/r2_kart_fix_newcomer_exe_b.mp4`, 30 s each;
  `r2/r2_kart_fix_newcomer_exe_80s_sheet.jpg`, `r2/r2_kart_fix_box_hint.jpg`, `r2/r2_kart_fix_shelled_sheet.jpg`):
  - at "GO!" the rainbow boxes stand on the deck on either side of the circle and the hint line says **Drive through a
    rainbow box**: a newcomer now knows what they are;
  - the mint karts' shells reach him and his mates: a red-and-white tub flips under a big red **SHELLED!** 40 s in, and
    twice more by 75 s;
  - my open-loop stream never drove through a box in 80 s (it steers blind), so the hint stays on "Drive through a
    rainbow box"; the far-hit flash was not seen in this window (he never fired). The closed-loop newcomer above did
    get boxes.

### Biplane newcomer fix -> v0.1.9 (sent 15:35:36, promoted 16:01:05: 26 min) **<- the new biplane pick**
- first_flight r? (one round), dependents re-verified. **Cost: 2 model calls, 1.46M tokens in (1.36M cache reads),
  16.0k out.** A new lesson step "cross": Vesper flies 30 m ahead of my nose, sweeping side to side, hint "Q: HARPOON
  her as she crosses your nose", and in the lesson she never rolls off it; her first harpoon waits 10 s into the real
  fight; she never fires while my energy is below a roll; REAL FIGHT and her warning pause the other hints. **See
  finding 8: the Foreman judged this "view or screen only" and did not judge skill_spread 0.04.**
- v0.1.9 = my film copy `plane_r5x` (no diff). Headless, the newcomer hand (`j2n_harpoon.gd`, 18000 frames): seed 1
  **0 script errors, hash 163f297c twice**; **he hooks Vesper in the lesson (frame 219; seed 2: frame 57)**, 2 hooks in
  5 min each seed (v0.1.8: 0 and 2); **she hooks him 3 and 4 times** (v0.1.8: 1 and 0) out of 7 and 5 tries: with the
  10 s wait and the energy guard her shots come when he can roll, but he notices her ring only 0-1 times, so they land
  more. She still wins both matches.
- **The newcomer in the exe** (`r2/r2_plane_fix_newcomer_exe.mp4`, 30 s; `r2/r2_plane_fix_lesson_cross_sheet.jpg`,
  `r2/r2_plane_fix_real_fight_alone.jpg`, `r2/r2_plane_fix_newcomer_exe_80s_sheet.jpg`):
  - 4 s in, Vesper's blue plane sweeps close across in front of him with "Q: HARPOON her as she crosses your nose":
    the harpoon finally has a target in the first minute (my blind stream pressed Q at the wrong moment and missed);
  - REAL FIGHT now stands alone on the screen (no ring, no stall hint at the same time);
  - he is still SHOT DOWN about 57 s in: a newcomer loses round 1 fast.

## Round 2 results: court

### Court newcomer fix + "make it fairer" (sent 15:42:09 and 15:42:41; both merged by 16:17)
- The newcomer sentence was split three ways: bodies_first_minute r3 (the cue, the glow), court_exchange r15 (the rival-
  oop hint in `scripts/main.gd`, plus a RULE: a plain Space swat near the rim now counts as a steal try), and the
  rivals' part to crews_stakes r16, which said "no change was needed in this package's scope" (event 1704).
  - bodies_first_minute r3: "C: ALLEY-OOP" at 46 pt in yellow over the catcher the core would pick, a pulsing yellow
    ring under his feet, every match; the glowing hand replaced by a pulsing ball of light (radius 0.55, 2.95 m up);
    in the lesson the line reads SPACE: JUMP TO STEAL IT while a rival lob is up.
- "Make it fairer" went to court_exchange (event 1664): tier 1 only, `bite` 0.7 -> 0.8, `read` 0.2 -> 0.12, `error_f`
  8 -> 10 (it says these move away from the contract's tier-1 figures and also change my own bot mates). Its builder:
  "I could not measure the newcomer win share; the newcomer hand test is not one of the commands I may run."
- **The Foreman's final hand check, newcomer over 20 seeds: 10 of 20** (v0.1.8: 11 of 20; the card asks 13). So "make
  it fairer" did not make it fairer by the Foreman's own measure; the builder tuned blind. (Outcome of the job: below.)
- My film copy `court_r3x` (the pack after all merges; the crews_stakes r16 "merge" event lists 7 files but the pack is
  byte for byte the same before and after it): headless seed 1, 3600 frames: **0 script errors, hash 56a19e33 twice**.
  Newcomer hand pressing C (`j2n_oop.gd`, whole matches): seed 1 21-19, **he catches 2 of his mates' alley-oops and
  slams them** (v0.1.8: 0), 1 stolen; seed 2 20-15, same events as v0.1.8 (3 mate oops, 3 stolen).
- **The newcomer in the exe** (`r2/r2_court_fix_newcomer_exe.mp4`, 30 s from 42 s; `r2/r2_court_fix_c_cue.jpg`,
  `r2/r2_court_fix_steal_hint.jpg`, `r2/r2_court_fix_newcomer_exe_80s_sheet.jpg`):
  - when a rival lobs, the hint line says **SPACE: JUMP TO STEAL IT**, and a STOLEN! follows a few seconds later;
  - **C: ALLEY-OOP** in yellow stands over the open mate, with a glowing ball over his head and a yellow ring at his
    feet: readable at play distance now;
  - but in this run the cue first shows at 72 s: a newcomer who rarely holds the ball free in the first minute still
    may not meet it in his first 60 s.
- 16:52 the final check failed the card: "hand check failed ... newcomer hand: 10 of 20 won (Wilson 95 % 30..70); the
  card asks at least 13. Sent back to crews_stakes" (event 1782), one repair round, "a second failure ends the job
  unpromoted". crews_stakes r17 (event 1786) made tier-1 rivals clumsier (shot error 18 -> 24 frames, guard gap 1.8 ->
  2.4 m, poke 0.14 -> 0.10, later drives, more hesitation; my mates swat more) and said: "The newcomer win share was
  measured on seed 1 only (one win). The seeds 1-20 count is unmeasured."

## Editor finding 9 (16:57): "make it fairer" is tuned blind
- Neither package that tuned the newcomer's odds could run the measure the Foreman judges them by: court_exchange r15
  "I could not measure the newcomer win share; the newcomer hand test is not one of the commands I may run" (event
  1673); crews_stakes r17 "measured on seed 1 only ... The seeds 1-20 count is unmeasured" (event 1786). The first try
  moved the newcomer from 11 to 10 of 20. A person's "make it fairer" costs a full final check (about 35 min) per guess.
  Evidence: court copy events 1673, 1782, 1786.
- **17:39 the court job FAILED** (event 1858): "hand check of card.team_possession failed, nothing promoted: newcomer:
  11 of 20 won ... the card asks at least 13. The change was NOT made. pack/ was put back to ... 0.1.8; the unpromoted
  files of the change are kept only in reports/change-not-made-s1858/pack/." **Cost of both sentences: 7 model calls,
  4.12M tokens in (3.74M cache reads), 29.8k out, 117 min.**
- **Editor finding 10:** my "make it fairer" was sent into the running Foreman's inbox while the newcomer fix ran, so
  the Foreman judged both as one change. When fairness failed its guard twice, the newcomer fix was thrown away with it:
  the cue, the glow ball and SPACE: JUMP TO STEAL IT (which worked, on film above) are not in any promoted version.
  A person in Create who adds "make it fairer" while another change runs loses both.
- The unpromoted pack `reports/change-not-made-s1858/pack` = my film copy `court_r3x` plus crews_stakes r17's tier-1
  tuning (`data/crews.json` only). Headless seed 1, 3600 frames: 0 script errors, hash 375a0941 twice. It is real Create
  output and playable, but the Foreman did not promote it.

## Item 25 watch (start failures while jobs ran side by side)
- Round 2 ran the three jobs side by side again (15:27-16:17), two promotions (karts 15:57:08, biplane 16:01:05) during
  court's checks, plus three exe windows and many headless runs of mine. **343 verdicts written in the copies since
  14:41: none with `report_missing` / `stdout_not_json`, and no `starved_stalls` lines since 14:40.** The only start
  failures today stay the two of 12:32:58 (biplane `harvest_look-r1-reverify-lint-s841`, 907 ms; court
  `final-hand-perfect-seed7-s1417`, 1494 ms), the second the karts copy promoted v0.1.8. One event, not reproduced.
