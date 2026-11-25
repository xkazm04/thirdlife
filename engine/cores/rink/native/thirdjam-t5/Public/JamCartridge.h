// Cartridge loader (tj.cartridge/1). Mirrors schema/validate.mjs: same verdict, same JSON pointer first in every error
// (schema/README.md, "The rule for lane A1"). Applies schema/DEFAULTS.md after validation, then the `values` overrides.
// Units: metres, metres per second, frames (60 per second). Rink coordinates: x along the rink, z across.
#pragma once

#include "CoreMinimal.h"
#include "UObject/Object.h"
#include "JamRulesConfig.h"
#include "JamCartridge.generated.h"

JAMCORE_API DECLARE_LOG_CATEGORY_EXTERN(LogJamCartridge, Log, All);

USTRUCT(BlueprintType)
struct JAMCORE_API FJamObstacle
{
	GENERATED_BODY()
	// "box" (square, side = Size), "pillar" (circle, diameter = Size), "bumper" (circle, diameter = Size, puck restitution 1.6: C-0005 / A15)
	// or "goal_shield" (a wall Size metres wide and 0.3 m deep, centred at X, Z, standing across the rink: C-0005 / A15).
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") FName Kind;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double X = 0;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double Z = 0;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double Size = 1;
};

USTRUCT(BlueprintType)
struct JAMCORE_API FJamRinkConfig
{
	GENERATED_BODY()
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double LengthM = 120;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double WidthM = 60;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double CornerRadiusM = 5;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double BoardRestitution = 0.4;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double IceFriction = 0.015;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double GoalWidthM = 4;
	// R-0033 point 2 (lane A50): the height of the net opening; 0.61 is the operator's half-height net for a game without goalies (a real net is 1.22).
	// One number for the net frame, the netting, the goal triggers and the sim's goal test for a lifted puck (UJamSim::InGoal with a height).
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double GoalHeightM = 0.61;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") TArray<FJamObstacle> Obstacles;
	// game.rink.zones (C-0005, lane A15): painted areas that change play inside them. Absent = none.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") TArray<FJamZoneConfig> Zones;

	// Derived (DEFAULTS.md): goal line at length/2 - 4 from the centre.
	double GoalLineX() const { return LengthM * 0.5 - 4.0; }
};

USTRUCT(BlueprintType)
struct JAMCORE_API FJamSkaterConfig
{
	GENERATED_BODY()
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double Speed = 8;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double Accel = 12;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double TurnRate = 5;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double LateralGrip = 3;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double Mass = 80;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double GlideDrag = 0.147;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double BrakeDecel = 6;
	// R-0013: the body check is available in every cut (absent = true).
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") bool bCheckEnabled = true;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double CheckSpeedMin = 5;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") int32 KnockdownFrames = 90;
	// game.skater.visual (R-0001, R-0024): "toy" | "humanoid_b1" | "generated_b2" | "toy_skeletal"; absent = "toy_skeletal" (the Director, H11.7; "toy" stays a value).
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") FName Visual = TEXT("humanoid_b1");   // R-0030: the bake-off (lane A30) picked B's rebuilt scripted figure
	// C-0005 (lane A16): the pass button.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double PassSpeed = 14;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") int32 PassLeadFrames = 20;
	// game.skater.carry_speed_mult (lane A82, R-0041 point 6): the carrier's top speed and acceleration as a fraction of a free skater's; the carrier cannot sprint. 1 = off.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double CarrySpeedMult = 0.92;
	// game.skater.free_speed_mult (lane A185, track F2 evolution 9, R-0064 point 2): a skater without the puck has this much more top speed and thrust, in a
	// glide and in a sprint, bots and the human alike; the carrier is untouched (so it is slower against everyone by that much). 1 = the neutral value.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double FreeSpeedMult = 1.15;
	// game.skater.charge_dies_on_loss (lane A203, track K1 evolution 4; the Director's ruling on A199's ASK): a skater who stops being the carrier loses his held
	// shot's and pass's charges, and a held button charges nothing until pressed again (UJamSim::ClearChargeOnLoss). Absent = true; false = the neutral value (the game before).
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") bool bChargeDiesOnLoss = true;   // the Director, 17:01: ships on (JamBaseline::MakeNeutral sets false)
	// game.skater.breakaway (R-0029 point 4, lane A39): a carrier past centre ice with no opponent between it and the net gets this fraction more
	// top speed and acceleration for BreakawayFrames, once per possession (event breakaway). speed_bonus 0 = off.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double BreakawaySpeedBonus = 0.3;   // lane A194 (track F2 evolution 10): 0.2 -> 0.3 (0.92 x 1.3 = 1.196 > a free skater's 1.15); 0.2 = the neutral value
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") int32 BreakawayFrames = 60;
	// game.skater.sprint (lane A49): Shift / LT held adds bonus to top speed and thrust while the stamina lasts; it drains in drain_frames of sprint and
	// refills in refill_frames at rest. bonus 0 = off.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double SprintBonus = 0.15;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") int32 SprintDrainFrames = 180;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") int32 SprintRefillFrames = 360;
	// game.skater.sprint.carry_bonus (lane A93, R-0045 law 4): the puck carrier may sprint; its sprint adds this fraction on top of carry_speed_mult (0.92 x 1.08
	// of a free skater's speed), always under a free skater's sprint (the sim caps the product at CarrierSprintCap of 1 + bonus). 0 = the carrier cannot sprint (A82).
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double SprintCarryBonus = 0.08;
	// game.skater.reverse_brake_decel (lane A93, R-0045 law 3): move input against the velocity (more than 120 degrees from it) is a hard stop at this many
	// m/s^2 until the skater is still; then the input accelerates the other way. 0 = off (only Ctrl brakes, at brake_decel).
	// Lane A121 (track F2, evolution 2; R-0050 point 5): 26, the stop's grip (20 before, the neutral value). A stop-and-go begun a metre later still beats a
	// charging pro (docs/experiments/MOVEMENT-3.md): 11 m/s to still in 26 frames (33 before), 8 m/s in 19 (24 before).
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double ReverseBrakeDecel = 26;
	// game.skater.burst (lane A93, R-0045 law 3): the first-step burst. For frames after the speed was under 2 m/s, or after the move input turned more than
	// 60 degrees inside 10 frames, the acceleration is accel_mult times normal (top speed unchanged). frames 0 = off.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") int32 BurstFrames = 20;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double BurstAccelMult = 1.8;
	// game.skater.burst.own_stop (lane A121, track F2; docs/VISION.md law 3 "after a stop or a sharp cut"): true = the first step is earned. Being slow arms the
	// burst only after a stop of the skater's own (it braked on the way down, by reversing or with the brake button); a skater that merely stands (a defender
	// waiting, the faceoff, a skater getting up) starts at the normal acceleration. A sharp cut arms it as before. false = the neutral value (lane A93's rule:
	// any skater under 2 m/s has the burst), under which the burst helped the charging defender more than the carrier (MOVEMENT-2.md section 3).
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") bool bBurstOwnStop = true;
	// Not a cartridge key (lane A121 measured it as the other candidate, MOVEMENT-3.md): the carrier's own burst multiplier; 0 = accel_mult, as everyone's.
	// Bar.Movement.StopAndGoSweep sets it.
	double BurstCarryAccelMult = 0.0;
	// Lane A194 (track F2 evolution 10, a measurement's number, no key): the carrier's reverse brake at this multiple of reverse_brake_decel (1 = everyone's).
	double CarryReverseBrakeMult = 1.0;
	// Not a cartridge key (lane A163, the measurement's second arm; docs/experiments/MOVEMENT-7.md section 3): the take's first step. The frame a skater a
	// person steers wins the puck (the frame its take grace begins), its first-step burst runs this many frames. 0 = off. bBurstTakeBots: every skater's.
	int32 BurstTakeFrames = 0;
	bool bBurstTakeBots = false;
	// game.skater.burst.rest_frames (lane A128, track F2 evolution 3; the Director's ruling on lane A121's open question): a skater that starts from rest has
	// earned its first step. Slower than 1 m/s (UJamSim::BurstRestSpeed) for this many frames in a row (a faceoff, a get-up, a full stop), its burst is armed
	// while it stands and runs burst.frames from the frame it moves off. Never on a charge already under way. 0 = the neutral value (lane A121's rule: only a
	// stop or a cut of the skater's own).
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") int32 BurstRestFrames = 6;
	// Not cartridge keys (lane A128 measured them, MOVEMENT-4.md): the speed under which a rested skater's burst stays armed (1 = the rest speed itself) and
	// the length of the burst a rest arms (0 = burst.frames). Bar.Movement.StopAndGoSweep sets them.
	double BurstRestHoldMps = 1.0;
	int32 BurstRestBurstFrames = 0;
	// Not a cartridge key (lane A128, sweeps 1 and 2): true = the rest ends with the push-off (the first frame the skater thrusts), so the burst is the first
	// burst.frames of the push; false = the rest ends at the hold speed (a skater creeping under it keeps the burst armed).
	bool bBurstRestPushOff = true;
	// game.skater.burst.rest_kept_mps (lane A147, track F2 evolution 4): the first step a skater has earned by standing is not lost to what is not its own
	// doing. While it does not push and is slower than this, a rested skater keeps its rest and its armed burst (a bump that moves it, a shove); a skater
	// lying on the ice or held by a stumble counts its rest whatever it slides at (so it gets up with its first step); and turning on the spot is not the
	// push-off (the burst begins with the first frame of thrust). 0 = the neutral value: lane A128's rule as it was (the rest is lost at 1 m/s).
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double BurstRestKeptMps = 3.0;
	// R-0035 (lane A52): game.skater.goalie { reach_m, block_height_m }: a skater in the crease stance saves a loose shot under block_height_m that passes
	// within reach_m of it (the human included); a higher puck passes. reach_m 0 = no save by height (the body and the blade stop pucks as before).
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double GoalieReachM = 0.9;
	// Lane A207 (track P1, wave 2; docs/experiments/PASS-SHOT.md section 4): game.skater.goalie.read_mps / read_max_m: the crease skater reads a long shot. Past
	// UJamSim::GoalieReadDelayS (0.25 s) of the shot's flight his save reach grows by read_mps per second, to read_max_m more: the long shot that the doubled
	// speed brings to the net is a goalie's save, the quick one from the slot is not. 0 = the neutral value (reach_m whatever the flight).
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double GoalieReadMps = 2.5;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double GoalieReadMaxM = 1.0;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double GoalieBlockHeightM = 0.4;   // Director calibration 01:30 (R-0035): below the 0.61 bar, so a half-charged shot (0.45) clears the stance and stays under the bar; at 0.7 the stance saved everything the net could take and the novice stopped scoring in time
	// game.skater.spin (lane A51, R-0034): E / gamepad B. A full turn over frames, cooldown_frames before the next, speed x speed_mult while it runs,
	// stamina_cost of the sprint bar taken at the start (refused with an empty bar). frames 0 = off.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") int32 SpinFrames = 24;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") int32 SpinCooldownFrames = 90;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double SpinSpeedMult = 0.7;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double SpinStaminaCost = 0.25;
	// game.skater.spin.exposed_frames (lane A128, track F2 evolution 3): the spin's price. For the last exposed_frames frames of a spin the body has come round
	// and is no longer between: neither the body nor a sweep shields the carried puck from a stick (the take grace still does). Measured on the carry scene
	// (MOVEMENT-4.md): the spin with the cut from 6 m passes a pro 53 % with 5 (99.5 % with 0). 0 = the neutral value (the whole spin shields).
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") int32 SpinExposedTail = 5;
	// Not cartridge keys (lane A128's other candidates, measured in MOVEMENT-4.md section 4; Bar.Movement.StopAndGoSweep sets them): frames after a spin that
	// ran its length in which the puck stays exposed (FJamSkaterState::SpinRecoverLeft), the thrust during them (1 = normal), and the frames at the start of
	// the spin in which the body is not yet between. All off.
	int32 SpinRecoveryFrames = 0;
	double SpinRecoveryAccelMult = 1.0;
	int32 SpinExposedHead = 0;
};

// game.stick (R-0013, lane A16): the mouse / right-stick aimed stick.
USTRUCT(BlueprintType)
struct JAMCORE_API FJamStickConfig
{
	GENERATED_BODY()
	// How far the blade reaches from the skater's edge at full aim, metres.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double ReachM = 1.2;   // R-0022 point 3 (1.6 before); lane A51 (R-0034): the range is 0.6..1.6; the brief's 1.1 halved the passes the regular player receives at pro (STICK.md section 6), so 1.2 stays
	// Frames after a poke press during which the blade reaching the puck takes it cleanly.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") int32 PokeWindowFrames = 8;
	// Centre-to-centre distance (beyond the two bodies) within which a stick lift strips the carrier.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double LiftRangeM = 1.0;
	// Lane A95 (B-to-A-0037): no clean lift and no cross-check shove on a carrier more than this many degrees off the attacker's facing; 180 = no cone.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double LiftConeDeg = 70.0;
	// Frames of lost control after a poke that was timed wrong next to a carrier (0 = no penalty, hockey.raw).
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") int32 StumbleFrames = 20;
	// Mouse delta to aim: 1 = 100 pixels move the blade one full reach.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double MouseSensitivity = 1.0;
	// R-0029 point 3: a check on a skater that carried the puck within this many frames is not a foul_no_puck (the puck just left it).
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") int32 FoulGraceFrames = 12;
	// game.stick.reception_m (lane A46, PAYOFFS.md section 6): a teammate's pass reaching the body within this radius at 6-14 m/s is seated on the blade
	// (4 frames of settle; the one-timer window opens); faster passes bounce off the body unless the blade meets them. 0 = blade reception only.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double ReceptionM = 0.9;
	// game.stick.deke (R-0029 point 4, lane A39): a deke tap (FJamInput::bDeke) moves the carried puck DekeOffsetM to the blade side within 6 frames and
	// commits the crease back for DekeCommitFrames; a shot inside that window aims at the post on the deke side. offset_m 0 = off.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double DekeOffsetM = 1.0;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") int32 DekeCommitFrames = 15;
	// game.stick.sweep (lane A51, R-0034): the carried puck follows the blade every frame; an aim that moves more than min_deg_per_frame counts as a
	// sweep and shields the puck for shield_frames from a poke on the side it left; a defending bot pokes at where the puck sat on the carrier's body
	// bot_react_frames ago (-1 = absent: by the difficulty profile, rookie 14, pro 8, all_star 5). shield_frames 0 = no shield.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double SweepMinDegPerFrame = 6.0;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") int32 SweepShieldFrames = 12;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") int32 SweepBotReactFrames = -1;
	// game.stick.carry_reach_mult (lane A93, R-0045 law 4): the puck's distance by pace. A carrier that is not sprinting holds its blade (and the puck on it) at
	// this fraction of the full distance from the body (0.75: 1.2 m of 1.6 m at full aim); sprinting it rides at the full distance. 1 = always full (A51).
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double CarryReachMult = 0.75;
	// game.stick.sweep.sprint_shield_mult (lane A93): a sprinting carrier's sweep shield lasts this fraction of shield_frames (0.5: 6 of 12). 1 = no difference.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double SweepSprintShieldMult = 0.5;
	// game.stick.body_shield (lane A102, track F2; docs/VISION.md law 3, docs/experiments/MOVEMENT-2.md): puck protection with the body, no button. While the
	// carrier's body is between a defender's stick and the puck (the defender within 2 m, the puck on the far side of the body, the carrier turned away from the
	// defender by more than 60 degrees) that defender's poke or lift does not take the puck. false = off (the neutral value: the game before the lane).
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") bool bBodyShield = true;
	// game.stick.passive_take (lane A102, R-0048): false (the default) = a carried puck is not taken by an unpressed blade or by a body's touch: it leaves its
	// carrier only by a shot, a pass, a poke, a lift, a check or stumble that loosens it, or the carrier's own release (R-0021's sentence, now the rule).
	// true = the neutral value (the game before the lane): an aimed opposing blade within 0.6 m deflects a carried puck moving faster than 6 m/s, and any
	// body's touch makes that skater the last toucher.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") bool bPassiveTake = false;
	// game.stick.take_grace_frames (lane A121, track F2; R-0049 point 2, B-to-A-0038 point 2): a skater that has just won the puck (a poke, a lift, a loose puck,
	// a pass, the draw: the puck came to it from somebody else) cannot be poked or lifted for this many frames; a body check still loosens it. 0 = off (the
	// neutral value: the game before the lane, where device B counted a stick takeaway 1.4 times a second).
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") int32 TakeGraceFrames = 30;
	// game.stick.poke_assist_deg (lane A152, track F2; R-0059 point 4, docs/experiments/MOVEMENT-6.md): the poke reaches. Inside the open window of a skater a
	// person steers (bHuman), a puck an opponent carries is taken when it is within the stick's full reach of the poker's body (what a perfectly aimed blade
	// could take, never further) and within this many degrees of the direction the blade is aimed in; the shields refuse it as before. Before, the blade
	// itself had to be within 0.35 m of the puck on one of the window's frames: an aim that trails a skating carrier by a tenth of a second missed.
	// 0 = off (the neutral value: the game before the lane). Bots keep the blade rule (their aim's lag is the level's lever).
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double PokeAssistDeg = 60.0;
	// game.stick.miss_recovery_frames (lane A152): a miss costs a recovery, not a fall. A person's poke (bHuman) that runs out next to an opposing carrier locks
	// its stick for this many frames (no poke, no lift, no check; it skates and steers) where it cost stumble_frames without control. 0 = the neutral value: the
	// stumble. A bot's miss stays the stumble: it is what the carrier's sweep and stop earn (with the recovery for bots too, all_star read -5.5 points on 600).
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") int32 MissRecoveryFrames = 20;
	// game.stick.stop_grace_frames (lane A163, track F2 evolution 6; docs/experiments/MOVEMENT-7.md): the stop tucks the puck. On the frame the reverse brake
	// of a carrier a person steers begins (law 3's stop: input against a velocity of UJamSim::StopGraceMinMps or more), its puck gets the take grace for this
	// many frames: no poke and no lift takes it. A body check still loosens it (law 1) and a sprinting carrier has to stop first (law 4). It is the take
	// grace's own state (FJamSkaterState::TakeGraceLeft), so the HUD's cue for the grace shows it. 0 = off (the neutral value: the game before the lane).
	// Needs take_grace_frames above 0 (one rule, one state). A bot's stop earns none (bStopGraceBots below is the measurement's arm).
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") int32 StopGraceFrames = 0;
	// game.stick.pickup (lane A208, track F0; R-0067 point 2, docs/experiments/POSSESSION.md): the loose puck is his who touches it. A puck nobody carries
	// (not one riding with a carrier: R-0048 holds, that one is taken only by a press) that crosses a standing skater's stick arc, pickup.arc_m from his body
	// centre within pickup.arc_deg either side of the blade's or the body's direction, is his: seated with his motion (an opponent's puck faster than
	// pickup.sting_mps stings off the blade instead: a loose rebound). pickup.body: the body stops a loose puck (swept, so no speed tunnels through it) and it
	// is his; faster than sting_mps it bounces off him. arc_m 0 and body false = the neutral value (the game before the lane: only a puck over 6 m/s at the
	// blade's 0.6 m disc, a pass at the body, or a body touch that pushed it).
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double PickupArcM = 1.5;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double PickupArcDeg = 60.0;
	// Lane A207 (wave 2c, the Director 02:57): game.stick.pickup.pass_arc_m / pass_arc_deg: an OPPONENT takes a pass in flight (Puck.PassFrames > 0) only with his
	// blade: within pass_arc_m of the blade point and inside pass_arc_deg of his stick's line from his body; his body still blocks it (UJamSim::BodyMeetsPuck). The
	// passer's mates keep the full arc and the catch. And a pass gets off the stick: no opponent's stick takes it in its first 6 frames (his body still blocks).
	// Ship 1.0 m / 60 degrees (0.7 / 35 let a pass by a man 1 m off the lane: Jam.Core.PassStaged.OpponentInLane). pass_arc_m 0 = the neutral value.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double PickupPassArcM = 1.0;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double PickupPassArcDeg = 60.0;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") bool bPickupBody = true;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double PickupStingMps = 18.0;
	// game.stick.pickup.body_catch_mps (lane A208): the body seats a loose puck (it stops at him and is his) only when it meets him slower than this (relative,
	// into the body); faster it bounces off him (e 0.3) as a loose rebound. The stick arc is not limited by it.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double PickupBodyCatchMps = 18.0;
	// game.stick.pickup.block_carried (lane A208): with pickup.body, another skater's CARRIED puck is pushed out of a body it meets (no pass-through; the carrier
	// keeps it in his reach, R-0048). false = a carried puck passes through other bodies as before (R-0048's skip).
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") bool bPickupBlockCarried = true;
	// game.stick.faceoff (lane A208, the eye's list 1 items 1 and 10; R-0068): the draw is a draw, not a hit. centre_gap_m: both centres stand at the dot
	// this far apart, facing (each on his own side); 0 = where the formation puts them (the neutral value: ten metres apart at five a side).
	// winner_shield_frames: the skater who wins the draw cannot be felled for this many frames (a hit that would fell him is a bump: the release grace's
	// own state, GraceFrames). no_hit_frames / no_hit_m: nobody's body check or stick lift is pressed inside no_hit_m of the dot for no_hit_frames after the
	// drop (refused as the carrier's is: bCheckRefused). 0 / 0 / 0 = the neutral value (the game before the lane).
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double FaceoffCentreGapM = 1.8;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") int32 FaceoffWinnerShieldFrames = 90;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") int32 FaceoffNoHitFrames = 45;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double FaceoffNoHitM = 6.0;
	// Not a cartridge key (lane A163): the measurement's arm. true = a bot carrier's stop earns the grace too.
	bool bStopGraceBots = false;
	// Not a cartridge key (lane A163, the measurement's third arm; MOVEMENT-7.md section 3): the pickup settles. The frame a skater a person steers becomes
	// the puck's new carrier (a loose puck picked up at speed, a take), the puck is seated on its blade for this many frames as a pass's reception is
	// (FJamSkaterState::SettleFrames: the carry assist holds it whatever its speed against the body). 0 = off: a puck met at more than 4 m/s against the
	// body is touched and slides on. bPickupSettleBots: every skater's.
	int32 PickupSettleFrames = 0;
	bool bPickupSettleBots = false;
	// Not a cartridge key (lane A152): the instrument. The scripted human (regular and good) presses a poke when it can land: its aim leads its own reaction, and
	// it does not press into a take grace or a body between. false = the press as it was (every measurement before the lane).
	bool bPlaytesterPokeRead = false;
	// Not a cartridge key (lane A152): a test seam. true = the poke as it was before the lane whatever the two keys and the switch above say (the blade rule,
	// the stumble, the old press). Jam.Core.Movement.PokeNeutral plays one seed with the keys at their neutral values and once more with the keys on and
	// this seam closed, and asserts the two hashes equal: the neutral values are the game before, with no pinned constant.
	bool bPokeRulesOff = false;
	// Not a cartridge key (lane A152): the measurement's arm. true = a bot's missed poke costs the recovery too, where it keeps the stumble.
	bool bMissRecoveryBots = false;
	// Not a cartridge key. R-0048 point 2: a teammate never takes a carried puck by touch, under either value of passive_take (a pass is a pass). true brings
	// back the teammate's touch of the game before lane A102, which the neutral-block tests need to replay older commits' matches hash for hash.
	bool bTeammateTouchTakes = false;
	// Not a cartridge key (lane A138, on lane A128's finding). The take grace covers the frame the puck is won in: ResolvePokes runs right after the puck
	// moved and the winner's grace is counted from the end of the frame, so an open poke window took a puck in the very frame its carrier had won it
	// (hockey.regular pro seed 2, frame 8488). true = a carrier that is not yet the take owner counts as inside its grace. false = lane A121's rule as it was.
	bool bTakeGraceSameFrame = true;
	// Not a cartridge key (lane A102 measured it and it bought nothing, MOVEMENT-2.md section 3): the carried puck's distance while the carrier brakes, as a
	// share of its distance by pace. 1 = no difference. Bar.Movement.StopAndGoSweep sets it.
	double BrakeReachMult = 1.0;
	// Not a cartridge key. R-0044 as amended (lane A93): the sweep's shield covers both sides of the body; true brings back the one-sided shield of main
	// 8f6b157 (only the side the puck left), which Jam.Core.MovementNeutral needs to replay that commit's matches hash for hash.
	bool bSweepShieldOneSided = false;
};

USTRUCT(BlueprintType)
struct JAMCORE_API FJamPuckConfig
{
	GENERATED_BODY()
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double RadiusM = 0.12;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double MaxSpeed = 30;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double Drag = 0;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") FLinearColor Colour = FLinearColor(0.0056f, 0.0056f, 0.0056f, 1.f);
	// C-0005 (lane A16): 0..1 pull of a carried puck towards the stick; number of pucks on the ice (1..3).
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double CarryAssist = 0.6;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") int32 Count = 1;
	// R-0035 (lane A52): the lifted puck's gravity (m/s^2) and the bounce on the ice (a hop under 2 cm dies).
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double GravityMps2 = 9.81;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double IceRestitution = 0.3;
	// game.puck.net (lane A208; the eye's list 2 item 12 and A212's FAULT 01:17): own_wall: nobody scores on himself with his own play: a puck carried, or last
	// played (carried, then shot, passed or cleared) by the defending side does not enter that side's net: the goal mouth is a wall for it (it rebounds as off
	// the boards; a carried one stays at the line); an opponent's puck that touches a defender on the way still scores. mouth_only: a goal is a puck that
	// crossed the goal mouth (between the posts, from the front) on its path; a puck moved into the net's box any other way (a seat, a pull across a wall)
	// is put back where it was. false / false = the neutral value (the game before the lane).
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") bool bNetOwnWall = true;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") bool bNetMouthOnly = true;
};

USTRUCT(BlueprintType)
struct JAMCORE_API FJamShotConfig
{
	GENERATED_BODY()
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double ReachM = 1.5;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double Speed = 18;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") int32 CooldownFrames = 24;
	// Absent = no aim assist (bHasAimCone false).
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") bool bHasAimCone = false;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double AimConeDeg = 0;
	// C-0005 (lane A16): charged shot (0 frames = off) and deflections off skaters.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") int32 ChargeFramesMax = 30;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double ChargeSpeedBonus = 8;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") bool bDeflect = true;
	// game.shot.one_timer (R-0029 point 4, lane A39): a shot released within OneTimerWindowFrames of receiving a teammate's pass gets the full
	// charge without the hold and aim_cone_deg + OneTimerConeBonusDeg of aim help; the shot event carries Kind one_timer. window_frames 0 = off.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") int32 OneTimerWindowFrames = 10;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double OneTimerConeBonusDeg = 8;
	// game.shot.lift (R-0035, lane A52): the height a shot arrives at over the goal line by its charge: a tap tap_m, a hold of half_frames half_m, the full
	// charge (charge_frames_max) full_m, linear between (UJamSim::LiftForCharge). All three at 0 = every shot on the ice (the old game).
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double LiftTapM = 0.0;   // R-0042 (lane A85): a tap stays on the ice (0.05 before: A52's solve made a tap from 10 m a 0.5 m lob that cleared every blade)
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double LiftHalfM = 0.45;
	// R-0044 (lane A91): the top shelf clearly under the bar: 0.47, by measurement. The bar's ring starts BarRingM + PostRadius = 0.10 m under its axis, at 0.51 m,
	// and it is tested one puck radius before the line, where a long shot (falling at the line) is still higher. At 0.6 (the Director's 01:40 calibration) every
	// full charge from 4 to 24 m rang the bar (A87's acceptance run, the one red verb of 18); at the ruling's 0.5 it scores from 3 to 14 m and rings from 15 to
	// 24 m; 0.49: 20 to 24; 0.48: 22 and 23; 0.47 scores from every metre of 3..30 at every hold (Jam.Core.LiftedShot prints the table and asserts it).
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double LiftFullM = 0.47;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") int32 LiftHalfFrames = 8;
	// game.shot.tap_frames (R-0044, lane A91): a hold of this many frames or fewer is a tap: charge 0 (no speed bonus, the tap's height: on the ice at tap_m 0).
	// A human's click is never zero frames long: a 40 ms click reads as 2 to 4 charge frames and arrived 9 to 20 cm up (A85, MECHANICS-3 section 2). The human
	// and the bots alike. 0 = off (every held frame charges, the game before R-0044).
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") int32 TapFrames = 4;
	// Lane A207 (track P1, the night of 14 Nov; the operator: "shoot speed should double"): game.shot.speed_scale multiplies the shot's speed (shot.speed and
	// the charge bonus) and the puck's speed cap (puck.max_speed) alike: 2 = a tap 36, a full charge 52 m/s. 1 = the neutral value (the game before the lane).
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double SpeedScale = 2.0;
	// Lane A207 (wave 2b; the eye: "a goal from 28 m, unpressed"): game.shot.fade_m: the shot's added speed (what speed_scale put on top of the 1x shot) fades
	// with the distance the puck travels, e^(-x / fade_m): off the stick the full 2x, full 2x for the first 8 m (UJamSim::ShotFadeFromM), then about 1.5x by 12 m and 1.0x by 30 m (fade_m 6; measured at pro: 25 and 12 left the long shot at 35-45 %). 0 = the neutral
	// value (no fade: 2x all the way).
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double FadeM = 6.0;
};

// Lane A77 (R-0036): game.pass. The saucer pass: a pass held saucer.half_frames or more lifts saucer.lift_m at its apex, flies over a blade in the lane and lands
// before the receiver (UJamSim::ApplySaucerLift); a shorter hold or the edge is the flat pass. half_frames 0 or lift_m 0 = the saucer is off.
USTRUCT(BlueprintType)
struct JAMCORE_API FJamPassConfig
{
	GENERATED_BODY()
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") int32 SaucerHalfFrames = 8;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double SaucerLiftM = 0.35;
	// Lane A207 (track P1, docs/experiments/PASS-SHOT.md; the operator: "passes need to be able to be hold enough to cross 1/3 of arena length on max"):
	// game.pass.power { full_frames, reach_share, arrive_mps }: the human's held pass is its power. A hold of shot.tap_frames or fewer is the tap at
	// skater.pass_speed; longer, the speed grows evenly to the full speed at full_frames: the speed that carries reach_share of the rink's length and still moves
	// arrive_mps there (UJamSim::PassFullSpeed). A bot's or script's edge pass gets the speed that arrives at arrive_mps at its man. Under power the saucer is
	// the sim's (a blade in the flat lane), not the hold's. full_frames 0 = the neutral value (the pass before the lane: pass_speed always, the saucer by hold).
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") int32 PowerFullFrames = 30;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double PowerReachShare = 0.3333;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double PowerArriveMps = 8.0;
	// game.pass.aim.cone_deg: the human's pass goes to the team-mate nearest the stick's line inside this half-angle (led to where his blade will be); with
	// nobody inside it the pass goes along the stick. 0 = the neutral value (the sim's best open mate, whatever the stick points at; nobody open = no pass).
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double AimConeDeg = 25.0;
	// game.pass.catch_m: a pass in flight is seated on a team-mate's blade passing within this many metres of it at more than 1 m/s (UJamSim::TryCatchPass).
	// 0 = the neutral value (only the 0.6 m blade disc over 6 m/s and stick.reception_m's body reception).
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double CatchM = 1.2;
	// game.pass.clear_own_body: the passer's or shooter's own body does not stop the puck he just released while his cooldown runs (a pass to a mate on the
	// far side of his body bounced back onto his stick). false = the neutral value.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") bool bClearOwnBody = true;
};

// Lane A92 (R-0045, docs/VISION.md law 1): game.contact, contact by momentum (UJamSim::StabilityOf, UJamSim::ResolveContact; docs/experiments/CONTACT.md).
// A pressed body check or a cross-check is an impulse (closing speed along the contact line + lunge or thrust, times the attacker's mass) against the victim's
// stability; the ratio decides bump, stumble or down. Neutral block: momentum false + carrier_can_hit true = the rule before the lane (same state hash).
USTRUCT(BlueprintType)
struct JAMCORE_API FJamContactConfig
{
	GENERATED_BODY()
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") bool bMomentum = true;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") bool bCarrierCanHit = false;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double LungeMps = 1.5;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double ThrustMps = 3.0;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double CrossReachM = 0.5;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double StabilityMps = 6.0;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double StandSpeedMps = 1.0;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double StandBrace = 1.5;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double SpeedStability = 0.85;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double SprintStability = 0.7;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double SpinStability = 0.8;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double UnseenStability = 0.8;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double BumpRatio = 0.4;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double LooseRatio = 0.7;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double DownRatio = 1.0;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double DownFullRatio = 3.0;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") int32 DownFramesMin = 60;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") int32 DownFramesMax = 150;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") int32 StaggerFrames = 16;
	// Lane A101 (track F1): the boards are a body. The impulse of a hit that pushes a victim within 1.5 m of the boards into them counts this much higher
	// (UJamSim::BoardFactor). 1 = the neutral value: no bonus, no board read-out, the game before the lane (same state hash).
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double BoardBonus = 1.25;
	// Lane A113 (track F1, R-0049 point 1): the release grace. For this many frames after a knockdown ends, a hit on the released skater is a bump at most and
	// the brain starts no check on it. 0 = the neutral value: no grace, the game before the lane (same state hash). 120 (R-0051): two seconds, the value at
	// which no figure went down again within 2 s of its release in the lane's ten matches (at 90 one did, 111 frames after).
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") int32 ReleaseGraceFrames = 120;
	// Lane A125 (track F1): the check finds its man. While a human skater's check window is open its velocity is turned (speed kept, none added) onto the
	// collision course with the nearest standing opponent whose body is within this many metres of its own and inside 60 degrees of where it is going or
	// facing (UJamSim::StepCheckReach). 0 = the neutral value: the press goes where the skater was going, the game before the lane (same state hash).
	// Ships at 0: at 1.0 the playtester's whiffs fall from 60 % to 51 % of its presses, not under the 40 % asked for (five whiffs in six are presses on a man it
	// is not closing on, which no bend of direction cures), and Jam.Bot.HumanHasSomethingToDo leaves its budget (docs/experiments/CONTACT-4.md section 6).
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double CheckReachM = 1.0;   // lane A209: on (1.0, the measured value); neutral 0
	// Lane A157 (track F1, evolution 6; B-to-A-0041 point 2; docs/experiments/CONTACT-7.md section 1): nobody stands in a man who is down. A downed skater
	// was an ordinary 0.4 m body circle: a skater on its feet stopped 0.8 m from its root (on the lying figure, which is longer than the circle), pushed it
	// along the ice and bounced off it. With this key above 0 a downed skater's body has THIS radius for every skater on its feet (roots kept
	// skater radius + downed_radius_m apart, never less than the two circles): the one on its feet alone gives way (at most UJamSim::DownedPushOutMps), the
	// speed it had into the body turns along it (it goes round), and the downed skater is neither moved nor given any speed. The puck sees the same 0.4 m
	// circle as before. Two downed skaters, and the hit that fells a skater, collide as before. 0 = the neutral value: the game before the lane (same state hash).
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double DownedRadiusM = 0.0;
	// Lane A157 (track F1, evolution 6; R-0060 point 4; CONTACT-7.md section 2): a check press has a cooldown. A press opened a window whenever it came, so
	// RMB every 12 frames kept the human's window open for ever: the hit needed no timing. For this many frames after a press that opened a window (or
	// resolved as a late press) the same skater's next check press is dropped: no window, no cue (read-out FJamSkaterState::ChecksCooling). Bots and the
	// human alike (the brain's own spacing is 30 frames, the scripted human's 30). 0 = the neutral value: every press opens a window (same state hash).
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") int32 CheckCooldownFrames = 0;
	// Lane A165 (track F1, evolution 7; CONTACT-8.md section 1): a mashed button lands nothing. The cooldown alone left the masher a window every
	// check_cooldown_frames (9.8 landed checks a pro match at 36 against 4.6 timed, lane A157). true = a check press INSIDE the cooldown starts the cooldown
	// again from that press: a button pressed faster than the cooldown opens one window and then none until the hand has rested a whole cooldown; a press
	// made after the cooldown never notices. Read only with check_cooldown_frames above 0. false = the neutral value: a dropped press costs nothing more.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") bool bCheckCooldownRestart = false;
	// Lane A165 (track F1, evolution 7; CONTACT-8.md section 2): the board slam as a play. EARNED: a hit that fells its victim (not an armed hip check) while
	// the victim's centre is within UJamSim::BoardSlamRangeM (1 m) of the boards and the attacker closes on it ALONG THE BOARDS' NORMAL at
	// UJamSim::BoardSlamMinMps (4 m/s) or more: driven into the wall, not along it. PAID: this many frames down on top (at skater.knockdown_frames 90; they
	// scale with it as the others do), the victim's board read-out and the `board` event of a board hit, and the read-outs bContactSlam / ContactSlams for the
	// glass, the sound and the HUD. 0 = the neutral value: no slam exists (same state hash).
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") int32 BoardSlamFrames = 0;
	// Lane A177 (track F1, evolution 8; REVIEW-3 item 2, MOVEMENT-7 section 4; CONTACT-9.md section 1): "I touched the puck and I was on the ice." Two in three
	// of the human's knockdowns at pro land inside half a second of his winning the puck (8 frames after it on average, at 16 m/s of closing): nothing a hand
	// answers. take_shield_frames: for this many frames after a skater WINS the puck (it comes to it from somebody else: UJamSim's TakeOwner, the take grace's
	// own clock; not a placed puck), a hit that would fell it is capped at a stumble: it keeps its feet, loses half its speed, its control for the stumble and
	// the puck (the stumble's own rules); the attacker pays as for any stumble. An armed hip check keeps its rule. 0 = the neutral value (same state hash).
	// take_shield_human_side: true = only for skaters of a side that has a human on it (the bots that win a puck against him are felled as before).
	// take_shield_stagger_max: the cap that scales (law 1 read on the stumble): above stagger_frames, a capped hit's stumble lasts from stagger_frames at
	// down_ratio to this many frames at down_full_ratio (the same line the frames down follow). 0 = the flat cap: every capped hit is stagger_frames.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") int32 TakeShieldFrames = 0;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") bool bTakeShieldHumanSide = false;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") int32 TakeShieldStaggerMax = 0;
	// Lane A184 (track F1, evolution 9; R-0064 points 1 and 5; docs/experiments/CONTACT-10.md): the held cross-check and the wind-ups.
	// cross_hold: FJamInput::bCrossHold held UJamSim::CrossHoldTapFrames or more braces the skater (stick across the body): the first opponent his body meets
	// while braced takes the cross-check by the momentum he brings (law 1's line by closing speed, the cross-check's thrust_mps on top, as a pressed
	// cross-check); then the brace is spent until the button is released. Its prices are UJamSim::CrossHold*: no poke, lift, reception or sprint, a little
	// top speed and turning, and a braced skater hit by a faster man is easier to fell. false = the neutral value: bCrossHold does nothing (same state hash).
	// check_windup_frames, cross_windup_frames: the hit has a beat the eye catches. A pressed body check opens its window this many frames after the press
	// (the cooldown and the figure's call stay on the press); a pressed cross-check (the lift's swing: its shove and its strip) resolves this many frames
	// after the press. The figure is told the frames on the press. 0 = the neutral value: the hit lands on the press's frame, as before (same state hash).
	// Ship ON (R-0064: the operator's order): cross_hold true (lane A184, CONTACT-10.md), the wind-ups 4 / 4 (lane A192, CONTACT-11.md: the staged tests, law 3's
	// drill and the acceptance drill wait the wind-up). JamBaseline::MakeNeutral gives back the game before the lanes (false, 0, 0: hash-identical).
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") bool bCrossHold = true;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") int32 CheckWindupFrames = 8;   // lane A209: the human's as the bots' (8); neutral of tonight 4
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") int32 CrossWindupFrames = 8;   // lane A209: 8; neutral of tonight 4
	// Lane A200 (track F1, evolution 11; docs/experiments/CONTACT-12.md): the bots' own wind-ups. bot_check_windup_frames, bot_cross_windup_frames: the same two
	// rules for a skater the sim does not seat as a human (FJamSkaterState::bHuman false: every bot of both sides; the online guest's seat is a human), so the
	// bots' wind-up can be longer than the human's, whose own press must not feel late. -1 = the shared value above (the neutral value: the same state hash;
	// JamBaseline::MakeNeutral sets it). Ship ON (the Director, 15:53, from CONTACT-12.md's table): the bots' body check 8 (133 ms, an eye's beat), their
	// cross-check 12; the human keeps 4 / 4. A cartridge that sets the key overrides it (0..12). CheckWindupFor / CrossWindupFor are the one place the sim,
	// the brain's adapter and the tests read them.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") int32 BotCheckWindupFrames = 8;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") int32 BotCrossWindupFrames = 12;
	int32 CheckWindupFor(bool bHuman) const { return (!bHuman && BotCheckWindupFrames >= 0) ? BotCheckWindupFrames : CheckWindupFrames; }
	int32 CrossWindupFor(bool bHuman) const { return (!bHuman && BotCrossWindupFrames >= 0) ? BotCrossWindupFrames : CrossWindupFrames; }
	// Lane A209 (track F1, the night; docs/experiments/CONTACT-13.md): a hit he aims lands. game.contact.check_pull_m (0 = off, the neutral value; ships
	// 1.0): while a HUMAN skater's pressed body check winds up, his root is drawn toward the man he pressed at (the nearest opponent on his feet inside
	// UJamSim::CheckReachConeDeg of his facing, his going or his stick's aim) so the bodies meet as the wind-up ends, at most check_pull_m over the wind-up
	// (his speed is not changed by it: the hit's size stays his momentum's); a meeting inside his wind-up is the hit; his pressed cross-check's man is
	// drawn to arm's length the same way. game.contact.cross_any_man (false = the neutral value; ships true): the human's pressed cross-check shoves the
	// man in front of him with or without the puck (without: the shove's momentum rule, as on a carrier; the strip stays the carrier's).
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double CheckPullM = 1.0;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") bool bCrossAnyMan = true;
	// Lane A215 (track F1, the night; the eye's list 2 item 4): game.contact.cross_live_frames (0 = the neutral value: the shove is tried on the one frame its
	// wind-up ends; ships 10): a pressed cross-check whose shove found nobody on that frame stays live this many frames more: the man it was aimed at, then
	// the first other opponent its stick meets inside the stick's reach (stick.lift_range_m) and the shove's cone, takes it (UJamSim::StepCrossLive). Every skater, bots and the human.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") int32 CrossLiveFrames = 10;
	// Lane A215 (the Director's ruling of 15 Nov 02:39): game.contact.cross_back_human (false = the neutral value: a cross-check from behind at a carrier is the
	// stick lift for everyone, A92 / R-0045; ships true): the HUMAN's pressed cross-check (a tap) that meets the back of a man who has or just had the puck is
	// a shove: a stumble, never a knockdown, and the puck comes off his blade as a lift's strip. Bots keep the law. UJamSim::LandCrossBack.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") bool bCrossBackHuman = true;
	bool bHoldResetAtFaceoff = true;   // lane A209: the faceoff resets the held cross-check's count (a fault fix; a rule, no key; seam hold_reset 0 = the old count)
	double BotCheckPullM = 0.0;   // lane A209 wave 3: the bots' body-check pull (UJamSim::CheckPullFor); a rule with no key yet (measurement seam bot_pull); 0 = off
	// Lane A157 (track F1, evolution 6; CONTACT-7.md section 3): the lunge as a motion. A pressed check was a window on an ordinary collision and its lunge
	// (lunge_mps) a number in the impulse: the body did nothing, a miss cost nothing. With lunge_frames above 0 a press that opens a window commits the body
	// for that many frames: lunge_step_mps is added to its velocity along its facing at once (and counts in the hit as real closing speed: the impulse's own
	// lunge_mps is reduced by it while the lunge runs, so a head-on hit is the hit it was), its turn rate is UJamSim::LungeSteerShare of normal and it cannot
	// brake by reversing. A lunge that ends in a body ends there. One that runs out on nobody is the miss: the skater loses UJamSim::LungeMissCost x
	// lunge_step_mps of its speed (the step and as much again). No second lunge starts inside one. Both 0 = the neutral value (same state hash).
	// The name game.contact.lunge_mps was taken (lane A92: the impulse's number), hence lunge_step_mps.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") int32 LungeFrames = 0;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double LungeStepMps = 0.0;
	// Not a cartridge key (lane A138, R-0050 point 2 is a rule; R-0053 point 5 asks every rule for its neutral). true = a shield refuses the stick and never the
	// shove (lane A125: the body shield and the take grace refuse the take only; where only they refuse it, the cross-check's shove is contact from any side).
	// false = the refusal of main before lane A125: whatever refuses the lift refuses the shove too, and a lift from behind is never a shove. JamBaseline.h sets it.
	bool bShieldShove = true;
	// Not a cartridge key yet (lane A138, R-0053 point 3; proposed key game.contact.shove_behind_match_mps). A shove from behind obeys the contact law it claims:
	// two skaters going the same way at a similar speed barely move each other, so a cross-check's own thrust (thrust_mps) lands on a back only as far as the
	// attacker is closing on it: thrust x clamp(closing speed / this, 0, 1). At matched speed the push in the back is a bump; closing at this speed or more it
	// is the whole thrust (and with the whistle on the from-behind foul it always was). 0 = the neutral value: the whole thrust from any side (lane A125).
	double ShoveBehindMatchMps = 3.0;
	// Not a rule of the game and not a cartridge key (lane A132, track F1): how the SCRIPTED human (FJamPlaytester, the instrument behind every measurement of
	// "the human") decides its body-check press. true = on the closing speed along the line between it and the carrier (the contact law's own number);
	// false = on its own speed along that line, as before the lane (five whiffs in six were presses on a carrier skating away at the same pace). It lives here
	// so that JamBaseline::MakeNeutral can name its neutral value (false): the pinned matches were played by the old press. No sim code reads it.
	bool bPlaytesterClosingPress = true;
	// Lane A151 (track F1, evolution 5; CONTACT-6.md section 2), the same kind of switch: the scripted human presses its check ON COURSE AND TIME. The trace:
	// its whole input arrives ReactionFrames late (6 for the regular player), and the press on "centres under 1.8 m, closing over 4 m/s" never asked whether
	// the course meets the body: on the frame the sim got a whiffed press the two were already separating. true = it presses when the straight course of
	// the two bodies brings them together (centres under two radii) inside the check window as it will be delivered: what a person does who presses for the
	// hit he sees coming. false = the press of lane A132 (or the older one, by bPlaytesterClosingPress). No sim code reads it. JamBaseline.h: false.
	bool bPlaytesterCoursePress = true;
	// Lane A151 (track F1, evolution 5; docs/experiments/CONTACT-6.md section 3; VISION law 1: "Stationary player can resist most of side tackles"). Not cartridge
	// keys yet (proposed: game.contact.stand_side_brace, game.contact.brace_exchange). StandSideBrace: the brace of a standing skater against a BODY hit from
	// the side (the push across its facing), in place of stand_brace there; it falls off linearly to stand_brace at the edge of the front arc (the push 60
	// degrees off head-on), so the front stays the weak side of a man who stands. 0 = the neutral value: the side takes stand_brace (at 1.5 a pressed side
	// hit closing at 9 m/s was ratio 1.17: down). 5: the same hit is ratio 0.35, a bump; from the side only a hit closing above 10.5 m/s stumbles him.
	// Not for the puck carrier (it keeps stand_brace, and the equal bounce below): law 3 is a gate, and a carrier that stops too late is not saved by standing.
	double StandSideBrace = 5.0;
	// Lane A151 (track F1, evolution 5; CONTACT-6.md section 2). Not a cartridge key yet (proposed: game.contact.late_press_frames). The late press: a check is
	// a window that must be open BEFORE the bodies meet; a hand that presses as it feels the contact is a frame or six late, the bounce has already parted
	// the two, and the press ran out on nobody (the trace: in 18 of 66 whiffs the bodies had met 1 to 6 frames before the press arrived). For this many frames
	// after a HUMAN skater's body met an opponent's with no check open, its check press resolves as that hit, on the velocities the two met with
	// (UJamSim::TryLatePress). A bot's press is its brain's and gets none (as the human's 12-frame window, lane A49). 0 = the neutral value: no such press.
	int32 LatePressFrames = 0;
	// bBraceExchange: the brace is mass in the bounce. The skater-to-skater exchange (UJamSim::CollideSkaters) was an equal-mass bounce whatever the contact
	// law had said: a standing skater who took a hit as a bump left it with 0.6 x the closing speed (5.4 m/s from a 9 m/s hit; lane A147 read 6.6). true = a
	// skater on its feet who stands braced against the push (UJamSim::BraceOf) weighs its brace in that exchange between opponents: at brace 5 it leaves a
	// 9 m/s side hit at 1.8 m/s (0.9 when the attacker recoiled first), and the one who ran into it stops. false = the neutral value: the equal bounce.
	bool bBraceExchange = true;
	// The neutral block (contact.momentum false, contact.carrier_can_hit true): the check rule of main before lane A92.
	void SetNeutral() { bMomentum = false; bCarrierCanHit = true; }
};

USTRUCT(BlueprintType)
struct JAMCORE_API FJamRulesConfig
{
	GENERATED_BODY()
	// "first_to" | "timer"
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") FName Mode = TEXT("first_to");
	// 0 when absent (only read in first_to mode, where the validator requires it).
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") int32 ScoreToWin = 0;
	// 0 when absent (only read in timer mode, where the validator requires it).
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") int32 TimerFrames = 0;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") int32 GoalPauseFrames = 120;
	// R-0013: a check from behind or on a skater without the puck is a foul (free faceoff at the fouler's end, 300 frames in the box). Absent = true.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") bool bPenalties = true;
	// Lane A72 (ask A8): game.rules.penalty_frames, frames a hard foul sits in the box (60..600). Absent = 300 (UJamSim::BoxFrames).
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") int32 PenaltyFrames = 300;
	// game.rules.hooks (C-0005, lane A15) in file order, then the hooks ExpandVariants made from game.rules.variants (bFromVariant).
	// UJamRuleSystem evaluates them in id order. Absent = none.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") TArray<FJamRuleHookConfig> Hooks;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") FJamRuleVariantsConfig Variants;
};

USTRUCT(BlueprintType)
struct JAMCORE_API FJamSkaterSpawn
{
	GENERATED_BODY()
	// "player" | "chaser" | "support" | "back"
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") FName Role;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double X = 0;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double Z = 0;
};

USTRUCT(BlueprintType)
struct JAMCORE_API FJamTeamConfig
{
	GENERATED_BODY()
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") FString Id;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") FString ColourHex;
	// Linear colour converted once from ColourHex (R-0001 item 2: nobody else parses hex).
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") FLinearColor Colour = FLinearColor::White;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") TArray<FJamSkaterSpawn> Skaters;
};

USTRUCT(BlueprintType)
struct JAMCORE_API FJamAiConfig
{
	GENERATED_BODY()
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double YieldMarginM = 2;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double YieldRadiusM = 15;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double HoldRadiusM = 4.5;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double SpeedScale = 1;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double RedSkill = 1;
	// Lane A72 (asks A4, A5): game.ai.react_frames (0..60) and game.ai.body_check (0..1). Read by JamAI::ResolveDifficulty only when the key is written
	// (absent = the level's profile), so these defaults are never applied on their own.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") int32 ReactFrames = 0;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double BodyCheck = 1;
	// Lane A72 (ask A2): game.ai.sprint, the share of the time a bot sprints on a chase (0..1). Absent = 0.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double Sprint = 0;
};

USTRUCT(BlueprintType)
struct JAMCORE_API FJamPickupConfig
{
	GENERATED_BODY()
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") FName Kind;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") int32 SpawnEveryFrames = 600;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") int32 DurationFrames = 300;
	// Absent: 1.5 speed, 2 precision, 2 heavy_puck, 1.5 big_puck, 1 reverse_other (DEFAULTS.md).
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double Magnitude = 1;
};

// Lane A84 (R-0041 point 3, A81's ask A12): one entry of game.abilities[]: the human's special ability, used with F. Absent numbers are 0 here and the sim
// applies the kind's default (UJamSim::AbilityDefault*): cooldown 1200 frames, shield 360 and slow_puck 120 frames, magnitude 1.5 shotgun (shot speed),
// 1.5 hip_check (knockdown frames), 0.5 slow_puck (the puck's speed share), 1 shield (unused).
USTRUCT(BlueprintType)
struct JAMCORE_API FJamAbilityConfig
{
	GENERATED_BODY()
	// shotgun | hip_check | shield | slow_puck
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") FName Kind;
	// mode (held from the drop) | pickup (a boost take grants one of the pickup entries, held until its charges are spent)
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") FName Trigger;
	// 1..9; 0 = absent (a mode grant: unlimited; a pickup grant: 1)
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") int32 Charges = 0;
	// 60..3600; 0 = absent (the kind's default)
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") int32 CooldownFrames = 0;
	// 1..600; 0 = absent (the kind's default)
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") int32 DurationFrames = 0;
	// 0.1..4; 0 = absent (the kind's default)
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double Magnitude = 0;
};

USTRUCT(BlueprintType)
struct JAMCORE_API FJamLookConfig
{
	GENERATED_BODY()
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") FString Tier = TEXT("l2_night");
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") FLinearColor TrimColour = FLinearColor::White;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double FogDensity = 0;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") bool bWetIce = false;
	// look.trim_emissive (0..100): the board trim strips' Emissive. -1 = absent, the tier's default applies (ULookTierSwitcher::DefaultTrimEmissiveFor: 30, clay 12). B-to-A-0018.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double TrimEmissive = -1;
};

USTRUCT(BlueprintType)
struct JAMCORE_API FJamCameraConfig
{
	GENERATED_BODY()
	// "third_person" | "arena"
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") FName Mode = TEXT("third_person");
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double DistanceM = 6;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double HeightM = 3.5;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double LookAheadM = 5;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") int32 LagFrames = 4;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double FovDeg = 70;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") bool bRadar = true;
	// A40: the board clamp margin, the end-board height and the far-net lead (DEFAULTS.md).
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double BoardsMarginM = 0.8;
	// Lane A49: end_height_m 3 (was 5) and far_net_bias 0.2 (was 0.5): the lead and the lift fought the mouse aim and pushed the human out of the frame's middle third.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double EndHeightM = 3;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") double FarNetBias = 0.2;
};

// The hockey `game` object with every default applied and every `values` override folded in.
USTRUCT(BlueprintType)
struct JAMCORE_API FJamGameConfig
{
	GENERATED_BODY()
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") FJamRinkConfig Rink;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") FJamSkaterConfig Skater;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") FJamStickConfig Stick;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") FJamPuckConfig Puck;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") FJamShotConfig Shot;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") FJamPassConfig Pass;   // lane A77 (R-0036)
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") FJamContactConfig Contact;   // lane A92 (R-0045)
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") FJamRulesConfig Rules;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") TArray<FJamTeamConfig> Teams;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") FJamAiConfig Ai;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") TArray<FJamPickupConfig> Pickups;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") TArray<FJamAbilityConfig> Abilities;   // lane A84; empty = no ability (the default game)
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") FJamLookConfig Look;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") FJamCameraConfig Camera;
};

UCLASS(BlueprintType)
class JAMCORE_API UJamCartridge : public UObject
{
	GENERATED_BODY()

public:
	// Parses and validates; on success returns a new cartridge, on failure returns null and fills OutErrors
	// with sentences that start "at <JSON pointer>:" (same pointers as schema/validate.mjs).
	static UJamCartridge* LoadFromString(const FString& Json, TArray<FString>& OutErrors, UObject* Outer = nullptr);
	static UJamCartridge* LoadFromFile(const FString& Path, TArray<FString>& OutErrors, UObject* Outer = nullptr);

	// Validation only (no defaults, no object): the C++ mirror of validateCartridge().
	static bool Validate(const FString& Json, TArray<FString>& OutErrors);

	// "hockey.regular" -> <Content>/Cartridges/hockey.regular.cartridge.json; a path ending in .json is returned as is.
	static FString ResolveCartridgePath(const FString& NameOrPath);
	static FString GetCartridgeDir();

	// Converts "#RRGGBB" (sRGB) to a linear colour; false on a malformed string.
	static bool HexToLinear(const FString& Hex, FLinearColor& Out);

	// schema/README.md "Tunables": sets the game field a `values` key names (skater_speed, shot_speed, ice_friction, ...).
	// False when the key names no field. The same mapping the loader applies; the rule hook's SetParam (C-0005) rides it.
	static bool ApplyValueKey(FJamGameConfig& Config, const FString& Key, double Value);
	// Lane A118 (track S3): the range (schema/limits.json game_ranges) of the game field a hook's set_param may change; false when Param is not one of the
	// nine tunables. Both validators refuse a value outside it; UJamSim::SetParam clamps to it.
	static bool SetParamRange(const FString& Param, double& OutLo, double& OutHi);

	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") FString Id;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") FString Title;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") FString ThemeName;
	// Lane A81 (A67 ask A11): game.meta, the menu's words for a Director's choice; informational, never read by the sim. Empty when absent.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") FString MetaPitch;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") TArray<FString> MetaFacts;
	// 0..4294967295
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") int64 Seed = 1;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") FString SourcePath;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Cartridge") FJamGameConfig Game;
	// The raw text, kept so the Designer can diff and re-validate.
	UPROPERTY() FString RawJson;
};
