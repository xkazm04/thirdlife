# JB-back sentences: the hand juice sent back to Create, one sentence per game

Each sentence names, in a person's words, the juice the hand version has and the newest editor version lacks
(found by playing both: clips and stills in this folder, the night PROOF docs). Create's change box takes 800 characters.

## Robot soccer (sledgehammer), on editor v0.1.6 (job copy `.tl/jobs/robot-soccer-3-v-20261125-1`)

768 characters:

> Make the hammer hit like Smash Bros: while I charge, the hammer head heats from cherry red to white-hot and a red ring on the ground shows its reach, swelling and pulsing faster as the charge fills. A robot I hit should fly high and long, up to a second in the air at full charge, spinning two or three times, keeping its speed, bouncing off the walls with sparks and bowling over whoever it lands on. Print BONK! where the blow lands, KA-BONK!! for a big one, and punch the camera in; when I am the one launched, the camera looks up and follows me. A miss drives the head into the ground in a cloud of dust. Bots should also smash loose balls at goal with the hammer, and a carrier who sees a hammer go up should pass the ball away. Add a hint: Hold F, let go: SMASH.

## Shield wall (charge, brace, slam), on editor v0.1.7 (job copy `.tl/jobs/shield-wall-3-v-20261125-1-jb`)

798 characters (written 10:37; held until the Director's fast-forward to T's routing fix):

> Make the charge and slam hit like Gang Beasts. A charger crouches behind his shield with a dust kick, and a lane of red rings lies ahead of the run. Everyone the charge hits flies up and back off the line with a full spin, BOWLED! over him, a crack, sparks and dust, and gets up slowly; the charge runs on to the next man. A raised shield facing it stops it dead with a big clang, gold sparks and BRACED!, and the charger bounces back wide open. The slam is a real leap, higher than a man for near a second, weapon cocked, the camera rising too; the red ring throbs as I fall, and the landing shows SLAM!, a dust ring and a shock wave throwing everyone in it out, a big shake. All bots charge and slam often, brace or sidestep a charge, and run out of the ring. Show F and C READY or counting down.

## Arsenal hockey (meteor slapshot), on editor v0.1.23 (job copy `.tl/jobs/three-against-three-hockey-20261125-1`)

743 characters (written 10:45; held until the Director's fast-forward to T's routing fix). The bots'
own meteor and a dive to block it are left out on purpose: the rink core gives bots no ability and has no dive verb
(C++; S4-core's spike), so a sentence cannot buy them.

> Make the meteor look and sound like one, NHL Hitz style, and call it METEOR everywhere, not cannon or shotgun. When I light it with F my stick blade burns with flame and sparks; while I hold shoot a ring of fire grows round me and pulses when full, with WINDING UP and the percent in the hint. On release: a white-hot flash, a boom, a camera kick and METEOR! over me; the puck becomes a fireball with a long fire trail, sparks and smoke. Every skater it floors gets a burst of fire, a clang and FLOORED! over him. A meteor goal makes the net bulge back a full metre and the glass shake hard enough to see, with fire and confetti in the mouth. Show METEOR BACK IN and the seconds. No meteor off a faceoff: F lights only a second after the drop.

### Robot soccer follow-up (the one allowed), on v0.1.7, sent 11:04:21

442 characters. What v0.1.7 still lacked when I played it: the reach ring shows only under my own robot
(`show.gd` draws it for robot 0), so a rival's swing does not announce itself; a bot's ordinary swing still flies its
victim 2.0-3.6 m high (v0.1.6: the same), against 3.7-5.4 m by hand; and the two hint lines print over each other.

> Two things are still missing: I cannot see a rival's swing coming, because the red reach ring shows only under me, so draw it under every robot that raises a hammer; and a quick swing still just hops the robot it hits, so even the smallest hit should launch it higher than its own height with a clear moment in the air, and a full charge much higher still. Also the two hint lines at the bottom print on top of each other; show one at a time.

### Arsenal follow-up (the one allowed), on v0.1.24, sent 12:02:44

392 characters. What v0.1.24 still lacked when I played it: a meteor off the faceoff drop that scores (frames 92 and
869, seed 1; harbour said NOT DONE and the hop went to the cartridge, which has no key for it); the corner plate still
says "F: SHOTGUN"; the net and the glass do not move (harbour: NOT DONE, the base's parts).

> Three things are still wrong. I can still light the meteor at a faceoff and score straight off the drop, so ignore my F key until a second after each drop. The plate in the corner still says SHOTGUN; call it METEOR there too. And on a meteor goal the net and the glass do not move at all: draw a net bag and glass panes of your own that bulge back and rattle big enough to see from my camera.

### Shield wall follow-up (the one allowed), on v0.1.8, sent 12:32:40

426 characters. What v0.1.8 still lacked when I played it and measured it: bots charge 4 / 3 / 6 times a minute (hand
14 / 15 / 6), and a charge floors 1-3 men a minute (hand 8-10); BRACED! almost never shows (0-3 charges into a shield a
minute; hand 3-6 braced); a bowled man rises 1.1 m, under his own height (hand 1.6 m with a full turn).

> The charge is still rare and rarely lands. Bots should charge an open line several times a minute each, and the charge should bowl over everyone within a step of its line, not only the man straight in front, throwing each one higher than his own head before he lands. Braces are so rare I never see BRACED!: a rival who sees a charge coming at him should turn his raised shield to it most of the time, and the rest step aside.

## Round 2 (Director's second round, 27 Nov afternoon)

### Shield wall braces, on v0.1.9 (job copy `.tl/jobs/shield-wall-3-v-20261125-1-jb`), sent 13:29:49

446 characters. Aim: the hand's 3-6 braced charges a minute and 8-10 men floored by a charge a minute (v0.1.9: braced
2 / 0 / 0, floored 3 / 7 / 1, from 12 / 11 / 6 charges a minute: most charges hit nobody).

> Most charges still hit nobody: in a minute the bots charge a dozen times but floor only a few men. A bot should only charge when rivals stand in the lane in front of him, aimed at them, so nearly every charge meets someone and bowls a line over. And let the brace happen: about a third of the men a charge runs into should be facing it with the shield up, so it stops dead with BRACED! and the charger bounces back open, a few times every minute.

### Robot soccer, on v0.1.8 (job copy `.tl/jobs/robot-soccer-3-v-20261125-1`), sent 13:57:13

439 characters. What v0.1.8 still lacks against the hand version by eye: my quick first swing prints KA-BONK!! where
the hand version prints BONK! (no small/big scale), the words are thin pale text drifting up (hand: fat yellow comic
letters at the spot), and the reach ring is a thin line (hand: a thick bright band).

> Two things still read weaker than in a real brawler. Every hit says KA-BONK!!, even a quick tap: keep KA-BONK!! for a big charged hit and BONK! for a small one, and print them as fat yellow comic letters with a dark outline that pop out where the blow lands and hang there for most of a second, instead of thin pale text drifting up. And the red reach ring is a thin line that is hard to see across the pitch: make it a thick, bright band.

## Round 3 (after T's items 7-16, tree at main d311514b, foreman rebuilt)

### Shield wall braces again, on v0.1.10, sent 14:35:36

476 characters. What a person sees in v0.1.10: BRACED! comes up 0 / 1 / 2 times a minute (counted from the word on
screen, `bot_braced_count.gd`); the men in a charge's lane keep fighting and are bowled.

> I still almost never see BRACED!: when the red lane rings appear in front of a charger, the men standing in that lane just keep fighting and get bowled over. They should see the rings, turn to face the charger and get the shield up before he arrives; about a third of them should make it in time, so the charge stops dead on the shield with BRACED!, a clang and gold sparks, and the charger bounces back wide open. I want to see that a few times every minute, from both sides.

### Arsenal net and glass, on v0.1.25, sent 14:36:14

456 characters. What v0.1.25 shows on a meteor goal: a solid white box behind the goal, glass that does not visibly
move, and a pale pane across the view when the camera is behind my own net.

> On a meteor goal the net bulges back as a solid white box, and from my camera I cannot see the glass move at all. Make it look like a real net of cords that the puck drives a metre back and that swings back after, and make the glass panes over that end bow out and wobble far enough to see from where I stand. And when the camera swings behind my own net a big pale glass pane lies across the view: the glass must never come between the camera and the ice.

## Round 4

### Arsenal glass wobble, on v0.1.26, sent 15:19:27

325 characters. v0.1.26 hides the panes whenever I am within 12 m of that end, which is always the case when I score.

> The glass wobble never shows: when I score a meteor I am always close to that end, and the glass is hidden then. After every meteor goal show the panes over that end bowing out and wobbling, however close I am, big enough to see from my camera; only hide a single pane while it actually stands between the camera and the ice.

### Shield wall: bowling and braces together, on v0.1.11, sent 15:19:27

495 characters. Aim: the hand's 7.0 bowled and 4.8 braced a minute (v0.1.11: 4.5 and 1.8). Built also for item 3: its
last sentence ("The bots should charge where ...") matches the Foreman's rivals' words and a doing verb, so the rivals'
part goes to crew; the per-man brace for Oda, Finn, Sable and Pip lives in crew's data, so core is expected to hand a
NOT DONE to crew in the same change. ("brace" is not in the Foreman's verb list, so the brace sentence itself is not
part of the rivals' copy.)

> Now the charge bowls fewer men than before; I want both at once. A charge should throw everyone standing within a step of its line, not only the man it runs into, so a line of men goes over like pins, while a man who turns his raised shield to it in time stops it dead with BRACED!. The bots should brace by character: Bram the big one nearly always, Oda often, Sable half the time, Finn rarely and Pip the dancer almost never. The bots should charge where two or three rivals stand in the lane.
