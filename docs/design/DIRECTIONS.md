# Ten directions: how we build a game worth playing (23 Nov 2026)

**The owner, 23 Nov ~16:20, after playing the hockey behaviour pass** (verbatim): "Subjectively the game is the same garbage
as before. It is not even close to thirdjam, players are deformed, stick buggy flying everywhere and below surface. Speed
and sprint is not balanced as thirdjam, animations look unnatural and horrible, game basically unplaybale. I don't know
which directions to go at this point as we clearly still don't know how to build a minigame within this game. ... think
about 10 directions how to philosophically approach AAA game design even in this sandbox setup - and start executing all
directions done and you think the game is perfect." And, minutes later: "be aware, the pictures will not uncover core
problem which is the gameplay itself in speed and balancing of skill mechanisms to play the game".

## What went wrong, in one paragraph

Three times we changed parts and measured parts: code and constants (22 Nov), single-body step responses and bot event
rates (23 Nov), then 37 tuned rows. Each time the instruments improved and the game did not. A game's speed and the
balance of its skill mechanics are properties of the **whole system in play**: the body, the rink, the team size, the
camera, the controls, the puck, the bots, all at once. We kept our own system (a top-down camera, 2.2x toy figures on a
60 m rink, 3 v 3, rigid bodies under a general walking body) and tuned numbers inside it toward a game that is another
system (a chase camera behind a life-size skater on 90 m, 5 v 5, its own simulation). Nobody, the Director included,
looked at the two games side by side or played them the same way. That is the Director's failure before it is any lane's.

## The ten directions

1. **A game is one system: copy the whole before changing a part.** Where a proven reference exists, port it 1:1 first:
   units, arena, team size, simulation law, bots, camera, controls, figure. Parity is the floor we stand on; only from
   parity do we change one thing at a time and know what it did. For hockey the reference is thirdjam, whose source we own.
2. **Speed is a set of ratios, not a number.** Time to cross a zone against the time a hit winds up; a chaser's gain on
   a carrier against the reach of a poke; a pass's flight against a defender's closing time; a shot's flight against a
   reaction. Write the **tempo map** of the reference and hold ours to its ratios in the player's units.
3. **Every skill mechanic must matter, and must have an answer.** For each verb (sprint, stop, deke, shield, pass,
   one-timer, shot, charge, poke, check, cross-check, brace): its cost, its reward, its window, what beats it. The
   **mechanic matrix** is checked by ablation: take one verb away from a hand and count what it loses; give a hand only
   one verb and count what it wins. A verb whose loss costs nothing is dead; a verb that wins alone is broken.
4. **Skill must show.** The same game through hands of rising skill (idle, newcomer, regular, sharp, perfect; each with a
   person's limits: reaction time, aim error, presses a second) must spread results at every level, in the reference's
   proportions. A level is easy by the opponents' clumsiness, never by their absence.
5. **A hand in the loop, every round.** Not film and not a probe that reads the game's state: a playtester that plays
   through the real keys from what a player can perceive, with a person's limits, in both games, and says what a player
   would say: what it tried, what answered, the three worst things. Then the owner's hand, which alone passes a game.
6. **Character, camera, controls first, alone in a gym.** One skater, empty ice, the game's camera. Nothing else is
   built until moving alone is right against the reference, by the tempo map and by sight.
7. **The figure is a product of its own, and a visible defect is a failed test.** A skater made for skating (life size,
   gear, a stick held in two hands, the blade kept on the ice), animated from the simulation's own speed and lean. What the
   eye would reject is checked every frame by the machine: blade under the ice, a stick through its owner, a foot off
   the ice, a bone that changes length, a pose that pops.
8. **The game owns its simulation.** A deterministic law of its own for the bodies and the puck, as the reference has,
   instead of a general walking body and rigid bodies bent toward it. The engine draws, hears the keys and keeps
   determinism; where the engine fights the game, the game wins and the engine gains an API.
9. **One game, one mode, finished; a stair with exits.** Everything else is frozen. Gym, then the puck, then contact,
   then the bots, then the match, the arena and the screen, then sound; a step is left only when it stands against the
   reference. Subtract before adding: no ability, pickup or crazy mode until the plain game is good.
10. **The sandbox recipe: a few deep genre cores, many cartridges.** A minigame in Third Life is not physics improvised
    by a model for each idea. It is a **cartridge** (rules, arena, teams, toys, a layer of stat effects, skins) over a
    small number of cores that carry the quality (an arena team-sport core, a duel core, ...). Variety and the player's
    weapons, equipment and boosts live in the cartridge; feel and balance live in the core. "Robot soccer" is the test:
    the second cartridge on hockey's core.

## How the directions are executed (the stair)

| Step | What exists at its exit | Exit (all of) |
|---|---|---|
| 0 Reference | thirdjam runnable and instrumented here; its tempo map, mechanic matrix and hand ladder measured | numbers reproducible by one command |
| 1 Gym | our skater alone on thirdjam's rink under thirdjam's camera, on a ported simulation law | tempo rows equal; side-by-side film; visual tests green |
| 2 Puck | carry, pick-up, pass, shot, one-timer, the net | staged scenes equal the reference's own tests |
| 3 Contact | poke, check, cross-check, brace, knockdown and get-up, with their animations | frame timelines equal; visual tests green |
| 4 Bots | the reference's brain, 5 v 5, three levels | event rates and the hand ladder in the reference's proportions |
| 5 Match | rules, HUD, arena, sound, the first 30 seconds | mechanic matrix by ablation in the reference's proportions; a playtester's worst three are small |
| 6 Owner | the owner's hand | his word |
| 7 Surpass | one change at a time from parity; the stat layer and the first toys; robot soccer as a cartridge | each change shown against parity |

Until step 6 nothing else is built: no World work, no editor work, no other game.
