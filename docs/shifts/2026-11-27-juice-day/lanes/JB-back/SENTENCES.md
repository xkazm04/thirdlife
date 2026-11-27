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
