# N1 feel-kit: the engine gives every fight mutual reactions, hit-stop, solid bodies and a camera that sees

Read `docs/shifts/2026-11-22-night/COMMON.md` first. Then read `docs/research/DUEL-PLAYBOOK.md` §2 and §6.3 in full:
they are your spec.
- **Worktree:** `C:/Users/kazda/kiro/third-life/.claude/worktrees/n22-kit`.
- **Route:** Opus director, Astra builds.
- **Land:** the API EARLY (target 23:30, then message the Director the final names); the rest by 06:00.
- **Selftest:** 710-719.

## Why
On the 21 Nov colosseum proof jobs the critic said, again and again: no hit-stop, the struck rival barely reacts, the
bodies merge at contact, and a pillar hides the rival. The owner: "Arena mutual reaction on attacks and collision is
almost non-existing." These are engine-level gaps. A pack in a revise round cannot fix them, so the kernel provides them.

## Work
1. **Hit-stop on both bodies.** `TLHit.impact(attacker, victim, frames)` freezes both bodies and their rigs for `frames`
   (the playbook: light 5, heavy 9, blocked x0.67, parry 10, cap about 20).
   - It is deterministic and counted in frames.
   - Physics and AI of the frozen pair hold; the rest of the world goes on.
   - Make its interaction with `TLHit.react`/`TLHit.down` (falls arm A, merged on main) explicit.
2. **Mutual reactions** as a small set of helpers covering DUEL-PLAYBOOK §6.3, built on L2's fight clips and arm A's
   directional hit clips. Add short reaction poses to the rig only where none exists.
   - blockstun with pushback;
   - the attacker's recoil bounce on a blocked heavy;
   - parried (the attacker's weapon knocked away, a long stun);
   - clash, where both rebound;
   - guard-broken;
   - wall-splat.
3. **Pushbox.** Bodies of one pack never overlap (playbook §2). Every frame they are pushed apart by half the penetration,
   in a fixed order; a stunned body does not push back. It is opt-in per body or per pack, so existing packs keep their
   hashes unless they opt in.
4. **Play camera occluder fade.** Scenery between the camera and its subject fades (dither or alpha through the style).
   This fixes "a pillar hides the rival" and "the camera is behind the arena wall". It is drawing only, with no hash effect.
5. **`TLBall.set_radius(r)`** for the hockey big puck (owner, 21 Nov 4a).

## Acceptance
- A kit lab pack, in `engine/kernel/examples/ex_feel_lab`, plays every contact of §6.3 between two figures. A bot asserts
  that BOTH fighters' states change on each contact, the playbook's own acceptance.
  - Leave a 15 s clip, judged in a window.
- The pushbox lab: two figures charging into each other never overlap, measured as the minimum centre distance.
- The occluder lab: a pillar between the camera and the subject fades. Leave stills before and after.
- No existing pack's hash moves (opt-in), shown by world 8/8 = alone and packs 74/74.
- Kernel selftest blocks touched: green.
- API.md has a K8 "feel kit" section.
- **Message the Director the moment the API names are final.** N2 and N3 build on them.
