# S1-bots: the sentences, written down before any job ran (27 Nov, 08:18)

Typed word for word the same on both arms, through `foreman change <job> "<sentence>"` with the `change` flags of
`engine/ui/flags/real.json` (claude-cli sonnet), as Create sends it. No word about bots, rivals or opponents.

Jobs (copied once from the night lanes' jobs into `d25-court/.tl/s1/base/`, then that copy copied per arm into
`<tree>/.tl/s1/jobs/`; arm A's off-switch run has its own copy in `d25-court/.tl/s1/jobs-off/`):
- karts `bumper-kart-football-3-20261125-1` at v0.1.7 (from d25-kart);
- half-court `half-court-3-v-20261125-1` at v0.1.6 (from d25-court);
- shield wall `shield-wall-3-v-20261125-1` at v0.1.7 (from d25-shield).

## 1. Karts: a spring boxing glove on F (free key: Space bump, Q jump, E whirl, Shift boost, R restart)
> Give the karts a spring boxing glove on F, like a cartoon: the glove winds back into the kart's nose with a loud ratchet for a moment, then shoots out on a long zigzag spring three kart lengths ahead and snaps back. A kart it hits is punched spinning across the deck with a POW!, sparks and a camera kick, and the ball it hits is blasted away hard. While the glove is out you can hardly steer, and it needs a few seconds to wind up again, so a miss costs you. A kart can hop over it with Q or swat it aside with the whirl.

## 2. Half-court: an NBA Jam shove on C (free key: Space shoot, Q pass, E screen, F dunk, Shift turbo, R rematch)
> Give it an NBA Jam shove on C: you plant your feet and draw both arms back for a moment, then shove whoever is in front of you so hard he flies three metres back, skids on his back with stars spinning over his head and drops the ball if he had it, with a WHAM!, a short freeze and the camera shaking. It works from the side or from behind too. After a shove you stand off balance for a moment and it needs a few seconds to come back, so a miss leaves you beaten. A player who sees the arms draw back can spin away with turbo.

## 3. Shield wall: a shield throw on G, Captain America style (free key: J/LMB attack, Space/RMB guard, E/K heavy, Shift evade, Q call, F rush, C slam, R restart)
> Give the fighters a shield throw on G, like Captain America: he draws the shield back across his chest for a moment, then hurls it spinning flat straight ahead with a whoosh; it knocks the first fighter it hits off his feet with a loud clang and sparks, a short freeze and a camera kick, then flies back to the thrower's hand along its path. A raised shield blocks it with a ring and sends it skidding back. While his shield is flying the thrower has no guard, and the throw needs a few seconds to come back, so a miss leaves him wide open.

## Arm B's second sentence (the one a person types when the bots do not use the move), word for word per game
- karts: "The rivals use the boxing glove too, and dodge it when they see it coming."
- half-court: "The rivals use the shove too, and dodge it when they see it coming."
- shield wall: "The rivals use the shield throw too, and dodge it when they see it coming."

It is sent only when the first sentence's version shows the bots not using the move (the measure below), as a person
would. If the bots already use and answer it after the first sentence, B needed one sentence.

## Arm A's off switch (once, on karts, its own job copy)
> (sentence 1, word for word) + " Only I can do it."

## Seeds and measures
- Seeds 1, 2, 3; 3600 frames (one live minute) each; one counting test per pack version that drives the player's kart /
  player / fighter with the pack's own perfect-hand code and counts, from the pack's published state and events:
  the bots' uses of the new move, per bot, per minute (spam = one bot using it more often than its cooldown allows, or
  more than about 1 in 3 of its chances), and the bots' answers to it (dodge, hop, swat, spin away, block) per minute.
- Same hash twice on seed 1, 0 script errors.
- Wall time from sending to promotion, tokens (builder_run events of the change), sentences typed to reach "bots use it".

## The bar for "bots use it" (added 09:00, after B shield v0.1.8's counts and before any arm A count)
A version reaches "bots use it" when, over seeds 1-3 of its counting hand: (a) at least 3 of the 5 bots start the move,
(b) the bots start it 2 or more times a live minute together, and (c) the bots answer it (a dodge, hop, swat, spin or
block counted from the pack's own events) at least once a live minute. Below it, arm B gets its second sentence.
The bar applies to both arms (09:52): an arm A version below it gets the same second sentence a person would type, word
for word as B's, so "sentences typed to reach bots use it" is counted the same way on both. (First needed on shield
wall, where A's v0.1.8 was below it too.)

## A third sentence (09:58), for a version still below the bar after the second, the same on both arms
- shield wall: "The others still almost never throw the shield. Every fighter, my mates and the rivals, throws it when a foe stands open a few steps away, and sidesteps or blocks a shield flying at him."
- (karts / half-court, if needed, the same shape with their move's words.)
- karts (11:27): "The others still almost never dodge the glove. Every kart, my mates and the rivals, hops over it or swats it aside with the whirl when they see it winding up at them."
- half-court, arm A (11:47): Create said 'change not finished' (newcomer hand under the card), so the person sends sentence 1 again, word for word (a retry, counted as a 2nd sentence).
- half-court (13:40): "The others still almost never shove. Every player, my mates and the rivals, shoves the man in front of him when it pays, and spins away with turbo when he sees the arms draw back."
