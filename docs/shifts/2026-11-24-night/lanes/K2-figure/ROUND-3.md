# K2 figure, round 3: the puck verbs, proven on ten figures of a real match segment (23 Nov 2026, 20:43 to 21:35)

Landed in this round: item 1 (hit-stop picks, the shown carrier and puck) and item 2 (the puck verbs). Item 3
(contact) is NOT landed: it is a translated draft outside the engine, never run. The Director allowed that order.

## What stands

- **The puck verbs** (`engine/rigs/skater/tl_rig_skater_puck.gd`, from the listing's entries PlayShoot, SetShotCharge,
  ChargeMix, PlayPass, PassHoldTick, SetPassCharge, PlayReceive, PlayCallForPass, PlayPoke, PlayLift, LiftPlay, ChkScan,
  PlayStickHit, PlayCut, PlayCut1, the two takes of SK2Tick, the lift and deke blocks of OnBusEvent): tap shot (the
  wrist take one call later), charged shot (the slap from where the wind-up stood), the wind-up pose itself
  (TwoWayBlend_1 against Shot_Slap at ChargeTime), tap and held pass (Pass_Snap from 0.0834 s, the Pass_Charge layer
  under it), receive, call for pass, poke and the short stumble after a MISSED one, the stick lift in three sizes by
  how fast the two close, the lifter's turn to where the lift landed (the mesh's own yaw, in over 3 calls, out over
  10), the carrier's reaction to a poke or a lift, the deke (it comes from thirdjam's event bus, not from the pawn).
- **The spin and the one-timer have no take in thirdjam**: the pawn turns the figure through the spin
  (SpinVisualYawDeg), and a one-timer reaches the figure as PlayShoot like any shot. Read from the source; both
  occur in the run and match.
- **The game mode's part around the pawns** (`engine/cores/rink/view/skater_show.gd`, by a fork of this lane):
  HitStopFramesFor, HitStopPick and the routing of HokejGameMode.cpp:1753-1775; FJamPuckShow (the shown carrier with
  its keep and settle, where the puck is drawn: on `puck_socket`, blended at a change of hands, the goal drop) and its
  calls by name (SetLookAtPuck(false) on the human, SetPassCharge, PlayReceive, PlayCallForPass); SetWindupTakes.
  thirdjam's own tests of these functions are ported with their expected values: 5 of 5 cases pass.
- **The verb gym** (`engine/cores/rink/view/verb_gym.tscn`): a match segment of the real core, five a side, bots
  playing at "pro", the human from a recorded raw hand (`verbs.stream.json`, 1,800 frames, seed 5: it chases the puck
  and plays each verb in turn). Every skater has a pawn and a figure. Replays to the same state hash every time
  (25c0b3ac41ee29f5).
- **The oracle, now a whole match**: ten of thirdjam's own figures in Unreal, each under a plain AJamSkater (so that
  the Blueprint's own bus handler runs), given every call of the ten pawns frame by frame, with the bus events and the
  hit-stop's time dilation. **18,000 of 18,000 rows (1,800 frames x 10 skaters x 12 points) within 1 cm; the worst
  0.48 cm** (frame 1778, the human's puck socket). By skater, worst cm: 0.48, 0.01, 0.07, 0.09, 0.07, 0.03, 0.07,
  0.15, 0.10, 0.01.
- **What the run holds** (calls the figures got, the human / all ten): PlayShoot 4 / 5 (two charged), PlayPass 3 / 16
  (the human's three after a held charge: SetPassCharge on 37 frames), PlayReceive 2 / 8, PlayPoke 2 / 4 (one clean,
  one missed), PlayLift 2 / 5, PlayStickHit 2 / 3 (one poked, one lifted), deke 1, spin 2, SetShotCharge 52 / 61,
  hit-stops 5 (ten pairs of dilation calls). The puck is drawn on a blade on 912 of the 1,800 frames.
- **Defect tests over the run at parity** (the human's figure): blade under the ice 71 frames (worst 4.4 cm), a skate
  under the ice 616 of 1,299 skating frames (10.65 cm), a joint over 40 degrees a frame 72 frames (171.9: the stick
  bone at the slap's start), puck socket out of its band 1 frame, shaft against a leg 0, bone lengths 0. Counted on
  our mesh, as in round 2.
- **Gate:** block 812 (`rig.skater.verbs`, `rig.skater.verbs.oracle`, `rink.view.show`); 810 and 811 unchanged.

## What the oracle caught (each a thing I had wrong, or the oracle had)

1. **I read one select the wrong way round**: the short stumble follows a missed poke, not a clean one
   (`SelectInt(0, 1, bClean)` is 0 when clean). Ours played a stumble thirdjam's did not: 3.3 m at the puck socket.
2. **The hit-stop was not in the oracle at all** (the pawn's time dilation is not a call of the interface), and ours
   froze the figure outright. In Unreal the actor ticks on at 0.0001 of a tick while the world's clock runs on whole.
   Without it every figure that was ever in a hit-stop skated out of phase from then on (up to 35 cm at a foot).
3. **A take blends out one tick later than my arithmetic said** when its time left meets its blend-out time exactly
   (Lift: 0.4 s with 0.1 s out; Shot_Slap: 0.7 s with 0.2 s out). Unreal's tick delta in the fixed-rate session is the
   float BELOW 1/60, not the nearest one. With that one constant both cases and round 2's golden hold.
4. **Setting the dilation as an editor's edit killed the figure** (the Blueprint's components are rebuilt, the mesh
   loses its animation instance): 920 frames of a dead figure in one oracle run, caught by its own variable reads.
5. **A figure nobody renders drops its stick correction** (thirdjam's SK3Fix asks WasRecentlyRendered): the far
   skaters' blades jumped 1.5 cm as they left the follow camera. The oracle now sees every figure every tick, as the
   game's screen does. Ours keeps the correction always (round 2's deviation 2).

## What my eye rejects (looked at: four of the 18 verb sheets and two crops at full size; the film not)

1. thirdjam's figure wears its number (7, on the back patch) and felt; ours an empty patch and flat cel. Lane K7's.
2. In both figures nobody reacts to a hit: checks, hit reactions, stumbles and falls are left out of BOTH call
   lists (not ported), so a skater the sim has knocked down keeps skating in both pictures. The comparison is fair,
   the picture is not the game's.
3. In the missed poke (frames 372 to 378) the two bodies stand in each other. The sim's contact, in both.
4. The stick bone turns 172 degrees in one frame where the slap starts from a full wind-up (thirdjam's own; on a
   sheet of every third frame the stick is simply elsewhere).
5. Ours draws no puck in the gym's stills, thirdjam's oracle has none: "the puck on the blade" is a number here
   (912 frames drawn on a blade; the puck socket's height band), not a picture.
6. The sheets are 16 tiles wide at 300 px: fine for a pose, too small for a hand on a shaft.
In the four sheets and two crops (slap, held pass, lift, missed poke: about 60 pairs) no pair differs in pose.

## Deviations (this round's)

1. Unreal's tick delta is taken as the float below 1/60 (TICK_S), as measured in the oracle's fixed-rate session; in
   thirdjam's running game the delta is the display's and such boundaries fall either way.
2. thirdjam's event bus reaches the figure as `OnBusEvent(Event, bMe, WhereCm, Strength, Kind)` from the gym (the
   Blueprint binds the bus and asks its pawn for its index). Only lift and deke are ported; check and knockdown wait
   for the contact.
3. `set_rivals`: the other figures ChkScan reads are given to the figure (the Blueprint finds the actors).
4. SetTakeGrace and SetStickLock (LayerTick) are not ported: no caller in thirdjam's source at HEAD.
5. PlayCallForPass never fires on the real core: the mate is picked by UJamSim::HumanPassTarget, which the snapshot
   does not carry. The rule after the target is ported and tested with a stand-in.
6. The show object's own deviations (carrier reach from the cartridge, the puck's late tick, the goal drop on frames):
   in `skater_show.gd`'s header.
7. The hit-stop's dilation is recorded among the pawn's calls for the oracle (`set_time_dilation`), which thirdjam's
   interface does not have.

## Not ported yet

Contact: PlayCheck and its wind-up and cuts, the cross-check with hold, brace and whiff, PlayHitReaction, PlayStumble,
SetKnockedDown with falls, lie loops and get-ups, the board hit and pin, the whip, the bus's check and knockdown; of
the game mode: the whiff calls and the re-time of AJamHitRead (HitRead.cpp:754-841). Then abilities and weapons, dash,
dive, slide tackle, celebrations, the boost glow. (The goalie's stance is in since round 2.)
A translated draft of the contact exists (`.tl/scratch/contact/`, three files, 1,084 lines, with notes): by a fork,
from the listing, never run, not in the engine. Its notes say what the falls need that the figure lacks (looping
takes, a take's rate, the mesh's world yaw and shift, the rink's walls, the hold's layer, the whip's bone modifiers).

## Next (round 4)

1. Contact, from the draft, family by family against the same oracle (the run already holds 6 checks, 5 cross-checks,
   31 hit reactions, 7 knockdowns, 10 board pins, 1 stumble).
2. The whiff calls and the re-time of the hit read, or K1's word on who owns that model.
3. A puck in the gym's picture and in the oracle's, so that "on the blade" is seen.
