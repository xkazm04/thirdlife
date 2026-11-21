# Arm A: authored directional clips (your route)

Worktree `.claude/worktrees/n21d-falls-a`. Selftest file `engine/tools/selftest.d/671-falls-a.sh`.

**The idea:** every reaction is a hand-authored pose function of time (RIGS.md: a clip is `fn(t) -> {Bone: euler
degrees, "_hips": metres}`), chosen by the direction of the blow in the victim's own frame. Deterministic by
construction; no physics at all. This is thirdjam's route, done better: real directional falls (not a stiff tip) and a
real get-up.

**Build:**
1. Flinches (react): `hit_front`, `hit_back`, `hit_left`, `hit_right` (a blow from the front throws the head and chest
   back; from his right throws him to his left; and so on). Upper-body clips (like `shoot`), so legs keep the gait or
   the skate. The SIZE scales with `strength` (0.3 a small, quick snap; 0.7 a big one that also bends the knees a
   little; at 0.4+ the TLBiped stumble also runs): for example a rig param (declared like `lean`) the clip multiplies,
   set before `play`. Snap in 3-4 frames, recover in about 12-20.
2. Falls (down): `fall_back` (hit from the front: knees buckle, he goes over backwards, lands on his back/buttocks, the
   arms fly forward-up then out), `fall_front` (hit from behind: he pitches forward, catches himself on hands, ends
   prone), `fall_side` (from either side: one clip mirrored by a param or two clips `fall_left`/`fall_right`; a buckle
   and a sideways topple onto the hip and shoulder). Harder hits fall faster (thirdjam: playback rate 0.85 + 0.3 x
   strength). They hold the last pose while he lies. The whole figure must go down, not just bend: use `_hips` to bring
   the pelvis to the floor, and keep every bone above the floor (no sinking).
3. Get-ups: `get_up_back` (from the back: sit up, roll to a knee, push up), `get_up_front` (from prone: hands push, knee
   under, stand); a side fall gets up through whichever of the two it ends nearest. Played when the rise starts, with
   its time scaled to the rise window (`get_up_frames`, 24 by default: fast, so make it read anyway: the key poses
   matter more than in-betweens).
4. The kernel side: `TLHit.react` / `TLHit.down` turn `from_dir` into the victim's frame (front / back / left / right by
   the larger component; for `down` with zero `from_dir`, see the shared spec) and play the matching clip, falling back
   to today's behaviour on a rig without these clips. `TLBiped` remembers which get-up to play when he rises.
5. Make the clips hold up in skate mode too (the hockey check in the lab, and the hockey game at scale 2.2 with the
   stick in the hand: the stick stays in `hand_r`).

Your own selftest cases (671): e.g. each clip's pose twice is equal; a front `down` ends with the head behind the hips
(in the victim's frame) and a back `down` with it in front; the get-up ends in the standing pose.
