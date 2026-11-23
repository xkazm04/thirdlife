// The deterministic hockey simulation: skaters, puck, shots, checks, goals, rules. Fixed step 1/60 s, our own integrator,
// no Chaos, no Character Movement. Recipe: tools/skills/skating-physics.md. Port of the Godot hockey (docs/HOCKEY.md section 2).
//
// Units: metres, seconds, frames. Rink coordinates: x along the rink (Unreal X), z across (Unreal Y); 1 m = 100 Unreal units.
// Team 0 (game.teams[0]) defends the -x net and attacks +x; team 1 the other way round. Skater index = position in game.teams
// order, team 0's skaters first (contracts/events.md, "Who").
//
// The sim never touches the world, the event bus or actors: it queues FJamSimEvent per step and the game mode delivers them.
// Same config + seed + input sequence = same StateHash() every frame (the Determinism test).
#pragma once

#include "CoreMinimal.h"
#include "UObject/Object.h"
#include "JamCartridge.h"
#include "JamRandom.h"
#include "JamModifiers.h"
#include "JamRuleHooks.h"
#include "JamSim.generated.h"

JAMCORE_API DECLARE_LOG_CATEGORY_EXTERN(LogJamSim, Log, All);

// Lane A15's zone seam (Rules/JamZones.h, R-0019); that header includes this one, so only the names here.
class IJamZoneSource;

// One skater's controls for one simulation frame. Humans: latched from Enhanced Input at the step; bots: computed from sim state.
USTRUCT(BlueprintType)
struct JAMCORE_API FJamInput
{
	GENERATED_BODY()

	// Desired direction on the ice in rink coordinates (X = rink x, Y = rink z). Its length scales top speed and thrust:
	// humans are clamped to 1, bots to 1.5 (the AI brain multiplies in game.ai.speed_scale; the sim does not apply it again).
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Jam|Sim")
	FVector2D Move = FVector2D::ZeroVector;

	// Shoot pressed on this frame (edge, not hold): a tap shot at shot.speed, if reach, facing and cooldown allow it. Bots and scripts use it.
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Jam|Sim")
	bool bShoot = false;

	// C-0005 charged shot: shoot held (level). While held with the puck in reach the charge grows to shot.charge_frames_max; the shot fires on
	// release at shot.speed + charge * charge_speed_bonus. The human's game mode sends the level here and never the edge above.
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Jam|Sim")
	bool bShootHeld = false;

	// C-0005 pass (E / X) pressed on this frame (edge): a lead pass at skater.pass_speed to the best open teammate ahead of the puck.
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Jam|Sim")
	bool bPass = false;

	// Lane A77 (R-0036): pass held (level). While held with the puck in reach the pass charges to game.pass.saucer.half_frames; the pass fires on the
	// release: held half_frames or more it is a saucer (the puck lifts pass.saucer.lift_m, flies over a blade in the lane and lands before the receiver),
	// shorter it stays flat. The human's game mode sends the level here and never the edge above; bots hold it for half_frames. LOCKSTEP: flag bit 1024 (protocol 6).
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Jam|Sim")
	bool bPassHeld = false;

	// Check pressed on this frame (edge). Opens a 6-frame check window; only lands when game.skater.check_enabled.
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Jam|Sim")
	bool bCheck = false;

	// Brake held (skate stop). Optional; no default key binds it in M0.
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Jam|Sim")
	bool bBrake = false;

	// R-0013 stick aim: where the blade is held, as an offset direction from the skater in rink coordinates; |Stick| <= 1 is the fraction
	// of game.stick.reach_m. Zero = no aim: the blade sits ahead at half reach. Humans: mouse delta / right stick integrated by the game mode.
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Jam|Sim")
	FVector2D Stick = FVector2D::ZeroVector;

	// Poke check pressed this frame (edge): the blade takes the puck cleanly if it reaches it inside poke_window_frames; a poke next to an
	// opposing carrier that misses costs stumble_frames of control. During a faceoff countdown any press is an early move (loses the draw).
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Jam|Sim")
	bool bPoke = false;

	// Stick lift pressed this frame (edge): strips an opposing carrier within lift_range_m.
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Jam|Sim")
	bool bLift = false;

	// R-0029 point 4 (lane A39) deke pressed this frame (edge): the carried puck moves game.stick.deke.offset_m to the blade side within 6 frames and the
	// crease back commits for commit_frames; a second tap inside 30 frames does nothing. LOCKSTEP: a new input field; lane A38's FJamNetQuantInput must
	// carry it as a flag bit (the checklist line), else the two peers desync at the first deke.
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Jam|Sim")
	bool bDeke = false;

	// Lane A49 sprint held (level): +game.skater.sprint.bonus top speed and thrust while the skater moves and its stamina lasts (drain_frames of
	// sprint, refill_frames to full). Bots set it only with game.ai.sprint (lane A72). LOCKSTEP: a new input field; lane A38's FJamNetQuantInput must carry it as a flag bit.
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Jam|Sim")
	bool bSprint = false;

	// Lane A51 (R-0034): the spin move pressed this frame (edge): E / gamepad B. game.skater.spin: a full turn over spin.frames, the puck on the far side
	// of the body from the nearest opponent, speed x speed_mult, stamina_cost of the bar; refused with an empty bar or inside the cooldown.
	// LOCKSTEP: FJamNetQuantInput carries it as flag bit 512 (protocol 5).
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Jam|Sim")
	bool bSpin = false;

	// Lane A84 (R-0041 point 3): the held ability used this frame (edge): F / gamepad D-pad down. Does nothing unless the skater holds one of game.abilities[]
	// (a mode grant from the drop, or a pickup grant). LOCKSTEP: FJamNetQuantInput carries it as flag bit 2048 (protocol 7).
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Jam|Sim")
	bool bAbility = false;

	// Lane A184 (track F1, evolution 9; R-0064 points 1 and 5): the cross-check held (level): true on every frame the cross-check button is held while the
	// skater does not carry the puck (the controls lane maps LMB without the puck: the press itself still sends bLift, today's cross-check). With
	// game.contact.cross_hold on, a hold of UJamSim::CrossHoldTapFrames or more BRACES the skater (stick across the body): the first opponent his body meets
	// takes the cross-check with the momentum he brings; then the brace is spent until the button is released. Ignored with cross_hold off.
	// LOCKSTEP: FJamNetQuantInput carries it as flag bit 4096 (protocol 9), a held level.
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Jam|Sim")
	bool bCrossHold = false;
};

// (Named EJamSimPhase, not EJamPhase: lane A5's presentation enum EJamPhase lives in JamGame/HUDFeed.h.)
UENUM(BlueprintType)
enum class EJamSimPhase : uint8
{
	Playing,
	GoalPause,   // after a goal (or a foul): everyone brakes for goal_pause_frames, then the faceoff reset
	Over,        // a team won; frozen until Restart()
	Faceoff,     // R-0013: both centres at the dot, a countdown (GetFaceoffCountdown), then the drop; the puck is pinned at the dot
};

USTRUCT(BlueprintType)
struct JAMCORE_API FJamSkaterState
{
	GENERATED_BODY()
	FJamSkaterState() { for (FVector2D& M : MoveHist) M = FVector2D::ZeroVector; }   // lane A110: the reflected MoveHist ring starts zeroed (was "= {}")

	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 Index = 0;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 Team = 0;
	// "player" | "chaser" | "support" | "back"
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") FName Role;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") bool bHuman = false;

	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") FVector2D Pos = FVector2D::ZeroVector;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") FVector2D Vel = FVector2D::ZeroVector;
	// Facing angle in radians in the rink plane: atan2(z, x). 0 faces +x. Equals the Unreal yaw (in radians).
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") double Yaw = 0;
	// Yaw change over the last frame in rad/s (sim sign: + = towards +z = Unreal yaw right).
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") double YawRate = 0;

	// Previous frame, for render interpolation.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") FVector2D PrevPos = FVector2D::ZeroVector;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") double PrevYaw = 0;

	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") FVector2D SpawnPos = FVector2D::ZeroVector;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") double SpawnYaw = 0;

	// First frame a shot is allowed again (cooldown).
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int64 ShotReadyFrame = 0;
	// Frames left of the check window (set to 6 when check is pressed; 12 for the human, lane A49's calibration).
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 CheckWindow = 0;
	// Lane A49 sprint stamina in ticks: full = drain_frames * refill_frames; a sprinting frame takes refill_frames, a resting frame gives drain_frames back.
	// Starts full; hashed only once it left full, so a match without a sprint hashes as before.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 Stamina = -1;
	// Read-out: the sprint applied this frame (lane A93: the carrier's too; the contact's stability reads it).
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") bool bSprinting = false;
	// Lane A93 (R-0045 law 3) read-outs, never hashed: a brake took speed off this frame at more than 1 m/s: Ctrl / L-stick click (brake_decel) or the move
	// input against the velocity (reverse_brake_decel); bReverseBraking = the second kind. For the figure's stop pose, spray and sound.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") bool bBraking = false;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") bool bReverseBraking = false;
	UPROPERTY() bool bReverseBrakeLast = false;   // last frame's bReverseBraking (counts ReverseBrakes once per stop); lane A110: reflected (Jam.Net.HashCoverage)
	// Lane A93 (R-0045 law 3): frames left of the first-step burst (acceleration x skater.burst.accel_mult). Full while the speed is under BurstSlowSpeed and on
	// the frame the move input turned more than 60 degrees inside BurstCutFrames; counts down otherwise. Hashed only while it runs (burst.frames 0 = never).
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 BurstLeft = 0;
	// Lane A121 (track F2; game.skater.burst.own_stop): this skater braked on its way down (the reverse brake or the brake button took speed off it) and has
	// not been back at BurstSlowSpeed since: being slow arms its burst. Never set with own_stop false. Hashed while set.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") bool bBurstEarned = false;
	// Lane A128 (track F2 evolution 3; game.skater.burst.rest_frames): frames in a row this skater has been slower than BurstRestSpeed, up to rest_frames;
	// at rest_frames its burst is armed (the standing start). 0 again once it is at the rest speed or faster. Stays 0 with rest_frames 0. Hashed while not 0.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 RestFrames = 0;
	// Lane A128: frames left of the recovery after a spin that ran its length (FJamSkaterConfig::SpinRecoveryFrames, code only and 0: a measured candidate
	// for the spin's price, MOVEMENT-4.md): the carried puck is exposed to a stick. Always 0 in a shipped game. Hashed while it runs.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 SpinRecoverLeft = 0;
	// Lane A121 (R-0049 point 2; game.stick.take_grace_frames): frames left in which this skater's carried puck cannot be poked or lifted: it has just won
	// the puck. Set when the puck comes to it from somebody else (UJamSim::TakeOwner), counts down while the puck is live, 0 the moment the puck is somebody
	// else's. Hashed while it runs.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 TakeGraceLeft = 0;
	// The move input's direction over the last BurstCutFrames frames (unit, or zero for a frame without input), a ring written at MoveHistAt. Burst only.
	// Lane A110: reflected, so the soak's field compare and Jam.Net.HashCoverage see them (every member of this struct is a UPROPERTY: the lint checks the layout).
	UPROPERTY() FVector2D MoveHist[10];
	UPROPERTY() int32 MoveHistAt = 0;
	// Match statistics (not hashed): frames this skater sprinted while carrying the puck; reverse brakes started.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 CarrySprintFrames = 0;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 ReverseBrakes = 0;
	// Frames left knocked down; 0 = standing.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 KnockFrames = 0;
	// Direction of the fall (rink x, z), unit; valid while KnockFrames > 0.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") FVector2D KnockDir = FVector2D(1, 0);

	// R-0013 stick. The blade on the ice (rink metres) this frame, from the stick aim.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") FVector2D BladePos = FVector2D::ZeroVector;
	// Frames left of the poke window (set to stick.poke_window_frames on a poke press).
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 PokeWindow = 0;
	// True on a frame with stick input (|Stick| > 0.05): only an aimed stick deflects a shot; a blade held by default receives passes but blocks nothing.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") bool bStickAimed = false;
	// True while the open poke window was armed next to an opposing carrier (a miss then stumbles).
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") bool bPokeArmed = false;
	// Frames of lost control after a mistimed poke; 0 = in control.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 StumbleFrames = 0;
	// Lane A152 (game.stick.miss_recovery_frames): frames left of the recovery after a missed poke: no poke, lift or check while above 0. Hashed while above 0.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 StickLockLeft = 0;
	// Frames left in the penalty box; 0 = on the ice.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 PenaltyFrames = 0;
	// First frame a poke / lift is allowed again.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int64 PokeReadyFrame = 0;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int64 LiftReadyFrame = 0;
	// Takes the draw at the current faceoff.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") bool bCentre = false;
	// The draw: -1 no input yet, -2 moved early (loses), otherwise the frame of this centre's first stick input after the drop.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int64 DrawFrame = -1;

	// C-0005 charge: frames shoot has been held with the puck in reach (0..shot.charge_frames_max); the visual winds up on it.
	// Lane A203: -1 = a press the loss of the puck made dead (game.skater.charge_dies_on_loss): nothing charges until the release; never below 0 with the key off.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 ChargeFrames = 0;
	// Charge 0..1 of the shot that left this frame (0 for a tap or a pass); PlayShoot(Charge) takes it.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") float LastShotCharge = 0.f;
	// Frames before this skater may deflect again (one deflection per contact).
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 DeflectCooldown = 0;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 Passes = 0;

	// R-0029 point 4 (lane A39): the three payoffs.
	// The frame a teammate's pass landed on this blade (-1 none); a shot within shot.one_timer.window_frames of it is a one-timer. Only kept while one-timers are on.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int64 PassReceivedFrame = -1;
	// Frames left of the breakaway burst (top speed and accel x (1 + speed_bonus)); the burst fires once per possession (bBreakawayUsed resets when the puck changes hands).
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 BreakawayFrames = 0;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") bool bBreakawayUsed = false;
	// Consecutive frames as the carrier (counted only while the burst is on): the burst needs BreakawayCarryFrames of carry, so a touch-and-shoot never bursts.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 CarryFrames = 0;
	// Frames left of the deke (the puck moves over the first DekeMoveFrames, the crease back stays committed for all of them); DekeSide +1 = towards +z, -1 = towards -z, 0 = none.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 DekeFrames = 0;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 DekeSide = 0;
	// First frame a deke is allowed again (a second tap inside DekeLockoutFrames does nothing).
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int64 DekeReadyFrame = 0;
	// Lane A51 (R-0034) stick handling. The sweep: frames left of the shield after the blade crossed fast with the puck (0 = none) and the side the puck
	// left as the sign of Cross(Forward, blade - body) (+1 or -1; 0 = none): a read-out since R-0044 was amended (lane A93): an opponent's poke or lift from either
	// side misses while the shield runs.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 SweepFrames = 0;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 SweepSide = 0;
	// The spin (game.skater.spin): frames left (0 = none), the whole length, the turn direction (+1 = the sim's yaw sense, to the right), the first frame
	// a spin is allowed again. The carried puck rides the far side of the body from the nearest opponent (BladePos follows it), a poke never reaches it,
	// a check landing mid-spin knocks the carrier down for SpinKnockdownMult of the normal frames. Hashed only while they left their default.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 SpinFrames = 0;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 SpinLength = 0;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 SpinDir = 1;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int64 SpinReadyFrame = 0;
	// Match statistics of the stick handling (not hashed, like Dekes).
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 Sweeps = 0;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 Spins = 0;
	// Lane A77 (R-0036): frames pass has been held with the puck in reach (0..pass.saucer.half_frames); saucers passed; the pass that left this frame was a saucer.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 PassChargeFrames = 0;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 Saucers = 0;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") bool bSaucerThisFrame = false;
	// Lane A46: frames left of the settle after a body reception (the carry assist holds the puck on the blade; 0 = none). Hashed only while it runs.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 SettleFrames = 0;
	// Match statistics of the payoffs; PassesReceived (lane A46) counts teammates' passes seated on this skater's blade (blade or body reception).
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 PassesReceived = 0;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 OneTimers = 0;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 Breakaways = 0;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 Dekes = 0;

	// One-frame flags for the visual (set during the step that just ran).
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") bool bShotThisFrame = false;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") bool bPassThisFrame = false;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") bool bCheckThisFrame = false;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") bool bPokeThisFrame = false;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") bool bLiftThisFrame = false;
	// R-0029 point 4 (lane A39) one-frame flags for the visual: the shot that left was a one-timer, the burst fired, a deke started.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") bool bOneTimerThisFrame = false;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") bool bBreakawayThisFrame = false;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") bool bDekeThisFrame = false;
	// Lane A51 (R-0034) one-frame flags: a sweep started (the blade crossed fast with the puck), a spin started.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") bool bSweepThisFrame = false;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") bool bSpinThisFrame = false;
	// C-0001 v3 one-frame results for the visual: a poke resolved (1 clean, -1 missed), the draw resolved (1 won, -1 lost), a foul was called on this skater,
	// the strength (speed / max) of the pass that left this frame; and the level: standing at the dot as a centre before the drop.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 PokeResult = 0;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 DrawResult = 0;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") bool bFoulThisFrame = false;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") float LastPassStrength = 0.f;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") bool bAtFaceoff = false;
	// Lane A45 (C-0001 v4, R-0031 point 1): read-outs for the visual's PlayHitReaction / PlayBoardHit / SetBoardPin / PlayStickHit. Never hashed, never read by the sim.
	// A skater-skater collision at BumpMinClosing (3 m/s) or more closing with no check landed this frame; BumpDir = the push on this skater (the other towards this one, unit).
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") bool bBumpThisFrame = false;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") FVector2D BumpDir = FVector2D(1, 0);
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int64 LastBumpFrame = -1000;
	// The skater `board` event (A33) fired for this skater this frame; BoardFrames = consecutive frames touching the boards (within BoardContactEpsM of them).
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") bool bBoardHitThisFrame = false;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 BoardFrames = 0;
	// BoardFrames >= BoardPinFrames (10) with a standing opponent within BoardPinRangeM (1.2 m, centre to centre); false while down or in the box.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") bool bBoardPinned = false;
	// This carrier lost the puck to an opponent's stick this frame: 1 a clean poke (ResolvePokes), 2 a lift (TryLift); 0 otherwise.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 StickHitResult = 0;
	// Lane A92 (R-0045 law 1) read-outs, never hashed, never read by the sim. ContactOutcome: the hit this skater took this frame from a pressed check or a
	// cross-check: 0 none, 1 bump, 2 stumble, 3 down (UJamSim::ContactBump..ContactDown); ContactRatio its impulse / stability. bCheckRefused: this skater pressed
	// check while carrying the puck (game.contact.carrier_can_hit false) and the press was refused: the HUD's cue. bRecoilThisFrame: its own hit made it stumble
	// (it ran into a skater more stable than itself). The counters are match statistics: hits taken by outcome, recoils, refused presses.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 ContactOutcome = 0;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") float ContactRatio = 0.f;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") bool bContactCross = false;   // that hit was a cross-check (the lift's body part), not a body check
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") bool bCheckRefused = false;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") bool bRecoilThisFrame = false;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 ContactBumps = 0;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 ContactStumbles = 0;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 ContactDowns = 0;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 ContactRecoils = 0;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 ChecksRefused = 0;
	// Lane A101 (track F1) read-outs, never hashed, never read by the sim. ContactBy: the skater whose hit ContactOutcome reports (-1 with none): the hit-stop,
	// the camera and the HUD find both ends of a stumble with it (a stumble emits no event that names its victim). bContactBoard: that hit landed within
	// UJamSim::ContactBoardRangeM of the boards and pushed into them, so the boards answered as a second body (game.contact.board_bonus above 1); the victim's
	// bBoardHitThisFrame and a `board` event (Kind skater, Strength = the check's) go out with it. ContactBoardHits counts them (a match statistic).
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 ContactBy = -1;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") bool bContactBoard = false;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 ContactBoardHits = 0;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int64 LastContactBoardFrame = -1000;   // the frame of the last such hit: its echo on the boards is not a second board hit
	// Lane A113 (track F1, R-0049 point 1): the release grace. GraceFrames: frames left in which a hit on this skater is a bump at most; set to
	// game.contact.release_grace_frames on the frame a knockdown ends, counted down every frame after, 0 = none. RULE STATE: ResolveContact and the brain read
	// it, StateHash() covers it while it is not 0 (so release_grace_frames 0 hashes as before). The rest are read-outs, never hashed, never read by a rule:
	// bContactGrace: the hit ContactOutcome reports this frame would have landed and the grace made it a bump (ContactGraced counts them on the victim).
	// The attacker's counters behind the HUD's contact line: ChecksSoft (its pressed body check resolved as a bump: TOO SOFT), ChecksGraced (it met a grace:
	// JUST GOT UP), ChecksMissed (its window ran out on nobody: MISSED).
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 GraceFrames = 0;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") bool bContactGrace = false;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 ContactGraced = 0;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 ChecksSoft = 0;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 ChecksGraced = 0;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 ChecksMissed = 0;
	// Lane A151 (track F1, evolution 5): the late press (contact.LatePressFrames; with 0 none of these is ever written). LateFrames: frames left in which this
	// HUMAN skater's check press still counts for the body contact it just had, with no check open, with opponent LateWho; LateDir = the push (this skater
	// towards LateWho), LateVelSelf / LateVelOther = the two velocities as the bodies met. RULE STATE: TryLatePress reads them, StateHash() covers them while
	// LateFrames is not 0 (so the neutral value hashes as before). ChecksLate is a read-out counter (presses the rule resolved), never hashed.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 LateFrames = 0;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 LateWho = -1;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") FVector2D LateDir = FVector2D::ZeroVector;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") FVector2D LateVelSelf = FVector2D::ZeroVector;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") FVector2D LateVelOther = FVector2D::ZeroVector;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 ChecksLate = 0;
	// Lane A157 (track F1, evolution 6) read-out, never hashed, never read by the sim: frames in which the push-out around a downed skater
	// (game.contact.downed_radius_m) turned this skater's course along the body (a match statistic; 0 for ever at the key's neutral value).
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 DownedPushFrames = 0;
	// Lane A157 (track F1, evolution 6): the check's cooldown and the lunge. RULE STATE, hashed in StateHash() while not 0 (so the keys' neutral values hash
	// as before): CheckReadyFrame, the first frame this skater's next check press is taken again (game.contact.check_cooldown_frames; 0 = never set);
	// LungeLeft, frames left of the lunge a pressed check began (game.contact.lunge_frames; 0 = none). Read-outs, never hashed, read by no rule:
	// ChecksCooling (presses the cooldown dropped), LungesMissed (lunges that ran out on nobody).
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int64 CheckReadyFrame = 0;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 LungeLeft = 0;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 ChecksCooling = 0;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 LungesMissed = 0;
	// Lane A165 (track F1, evolution 7) read-outs, never hashed, never read by the sim. bContactSlam: the hit ContactOutcome reports this frame was a board
	// slam (game.contact.board_slam_frames above 0: the victim felled within BoardSlamRangeM of the boards by a hit closing along their normal at
	// BoardSlamMinMps or more); bContactBoard and the `board` event go out with it. ContactSlams counts them on the victim (a match statistic).
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") bool bContactSlam = false;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 ContactSlams = 0;
	// Lane A177 (track F1, evolution 8): the take shield (game.contact.take_shield_frames). RULE STATE, hashed in StateHash() while not 0 (so the key's neutral
	// value hashes as before): TakeShieldLeft, frames left in which a hit that would fell this skater is capped at a stumble; set to take_shield_frames at
	// the end of the frame it wins the puck, counted down at the end of every frame after, 0 the moment the puck is somebody else's or nobody's. Read-outs,
	// never hashed, read by no rule: bContactShield (the hit ContactOutcome reports this frame would have felled it and the shield made it a stumble),
	// ContactShielded (a count on the victim).
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 TakeShieldLeft = 0;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") bool bContactShield = false;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 ContactShielded = 0;
	// Lane A184 (track F1, evolution 9): the held cross-check (game.contact.cross_hold) and the wind-ups (game.contact.check_windup_frames,
	// cross_windup_frames). RULE STATE, hashed in StateHash() behind tags while not at its default (so the keys' neutral values hash as before):
	// CrossHoldFrames, the frames FJamInput::bCrossHold has been held in a row while the skater could brace (0 = released); bCrossBraced, braced this frame
	// (read by the contact, the puck, the poke and the lift, the skating); bCrossSpent, the brace was spent on a body (or the skater was hit, went down or got
	// the puck) and stays spent until the button is released; CheckWindupLeft, frames until a pressed check's window opens; LiftWindupLeft, frames until a
	// pressed cross-check (the lift's swing) resolves. Read-outs, never hashed, read by no rule: CrossBraceFrames (frames braced, a match statistic),
	// CrossBraceHits (hits delivered out of the brace), bCrossBraceHit (this frame's hit on the victim came out of a brace), WindupFrames (the frames to
	// contact the figure is told on this frame's press: PlayCheckWindup / PlayCrossCheck by name; 0 = none).
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 CrossHoldFrames = 0;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") bool bCrossBraced = false;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") bool bCrossSpent = false;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 CheckWindupLeft = 0;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 LiftWindupLeft = 0;
	// Lane A192: since evolution 10 LiftWindupLeft counts down to the cross-check's deferred SHOVE (the strip is the press's): CrossTarget, the man it lands on;
	// bCrossTargetStickOnly, a stick-only shield had widened it at the press (from behind too). RULE STATE, hashed while LiftWindupLeft runs.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 CrossTarget = -1;
	// Lane A215 (game.contact.cross_live_frames): frames left of the pressed cross-check's live window after its wind-up (the shove not yet landed; CrossTarget
	// is the man tried first). 0 = none. Rule state: hashed while above 0.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 CrossLiveLeft = 0;
	// Lane A209 wave 3: RULE STATE, hashed when not 0: frames left of a buffered check press / cross-check press (UJamSim::StepPressBuffer).
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 CheckBufferLeft = 0;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 LiftBufferLeft = 0;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") bool bCrossTargetStickOnly = false;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 CrossBraceFrames = 0;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 CrossBraceHits = 0;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") bool bCrossBraceHit = false;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 CrossBraceTaken = 0;   // lane A192 read-out: braced hits taken (the HUD's contact line), read by no rule
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 WindupFrames = 0;
	// R-0029 point 3: the last frame this skater carried the puck (-1000 = never); a check within game.stick.foul_grace_frames of it is not a foul_no_puck.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int64 LastCarryFrame = -1000;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") bool bTouchingPuck = false;
	// Last toucher of the puck and the puck within shot reach.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") bool bHasPuck = false;

	// Match statistics (tests and tournaments read them).
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 Shots = 0;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 Touches = 0;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 Goals = 0;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") double DistanceM = 0;
	// Lane A84 (R-0041 point 3): the held ability. AbilitySlot indexes game.abilities[] (-1 = none held); AbilityCharges left (-1 = unlimited); usable from
	// AbilityReadyFrame (the cooldown); AbilityArmed is the kind waiting for the next shot / check / pass (NAME_None = nothing armed); ShieldFrames left of a
	// shield. Hashed only while they left their defaults, so a cartridge without abilities hashes as before.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 AbilitySlot = -1;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 AbilityCharges = -1;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int64 AbilityReadyFrame = 0;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") FName AbilityArmed;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 ShieldFrames = 0;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 AbilitiesUsed = 0;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") bool bAbilityThisFrame = false;

	FVector2D Forward() const { return FVector2D(FMath::Cos(Yaw), FMath::Sin(Yaw)); }
	bool IsDown() const { return KnockFrames > 0; }
	bool IsStumbling() const { return StumbleFrames > 0; }
	bool InBox() const { return PenaltyFrames > 0; }
	// Standing, in control, on the ice: may shoot, check, poke, lift.
	bool CanAct() const { return !IsDown() && !IsStumbling() && !InBox(); }
	// Lane A51: spinning right now.
	bool IsSpinning() const { return SpinFrames > 0; }
	// Lane A51: the figure's extra yaw during the spin, degrees (0 outside it): the full circle over SpinLength frames in SpinDir's sense; the sim's Yaw stays.
	double SpinVisualYawDeg() const { return (SpinFrames > 0 && SpinLength > 0) ? SpinDir * 360.0 * static_cast<double>(SpinLength - SpinFrames) / static_cast<double>(SpinLength) : 0.0; }
};

USTRUCT(BlueprintType)
struct JAMCORE_API FJamPuckState
{
	GENERATED_BODY()
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") FVector2D Pos = FVector2D::ZeroVector;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") FVector2D Vel = FVector2D::ZeroVector;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") FVector2D PrevPos = FVector2D::ZeroVector;
	// R-0035 (lane A52): the puck's height above the ice (metres, the puck's centre line; 0 = on the ice) and its vertical speed (m/s, + = up). A shot's release
	// lifts it by the charge (game.shot.lift), gravity (game.puck.gravity_mps2) pulls it down, the ice bounces it (game.puck.ice_restitution) until the hop is
	// under 2 cm, a carried puck sits on the ice. Hashed like Pos and Vel once off the ice (a cut whose lift keys are all 0 hashes as before).
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") double Z = 0;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") double VZ = 0;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") double PrevZ = 0;
	// Skater index that touched or shot it last, -1 after a faceoff.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 LastTouch = -1;
	// Lane A208 (game.puck.net.own_wall): the last skater who CARRIED the puck (then shot, passed or cleared it: a stick's deliberate play); a touch, a
	// deflection or a block does not change it. Hashed while own_wall is on.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 LastPlayedBy = -1;
	// Total distance travelled this match.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") double PathM = 0;
	// Lane A84: a shotgun shot in flight (frames left, the shooter, its speed multiplier) and a slow puck (frames left, the passer or shooter, the speed share).
	// Zero frames = none; hashed only while one runs.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 ShotgunFrames = 0;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 ShotgunBy = -1;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") double ShotgunMul = 1;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 SlowFrames = 0;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 SlowBy = -1;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") double SlowMul = 1;
	// Lane A207 (track P1): a pass in flight: frames left (0 = none) and the passer. Set by TryPass only while game.pass.catch_m is on; any touch by another
	// skater, a shot or a placed puck ends it. A team-mate's blade within catch_m seats it (TryCatchPass). Hashed only while it runs.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 PassFrames = 0;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 PassBy = -1;
	// Lane A207 (wave 2): the man the pass was aimed at (-1: along the stick, any mate). Another team-mate lets the pass fly by while it is faster than
	// DeflectMinSpeed against him (PassFliesBy); hashed with PassFrames.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 PassTo = -1;
	// Lane A207 (wave 2b, game.shot.fade_m): the shot's added speed still on the puck (m/s; 0 = none). Set by TryShoot, faded with the distance travelled
	// (StepShotFade), ended by any touch, a pass or a placed puck. Hashed while not 0.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") double ShotExcess = 0;
};

// An event the step produced; the game mode hands it to UJamEventBus (converting Where to centimetres).
USTRUCT(BlueprintType)
struct JAMCORE_API FJamSimEvent
{
	GENERATED_BODY()
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") FName Name;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int32 Who = -1;
	// Rink metres (x, z).
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") FVector2D Where = FVector2D::ZeroVector;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") float Strength = 0.f;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") FName Kind = NAME_None;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") int64 Frame = 0;
	// Side channel for "announce" (C-0005): the rule's text for the scoreboard line. Empty for every other event.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") FString Text;
	// Lane A47 (B-to-A-0029): the contact normal (checker towards victim) for check and knockdown, the board normal into the rink for board; zero otherwise.
	// Rink axes (x, z), unit length. A read-out: nothing in the step reads it and events are not hashed.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") FVector2D Dir = FVector2D::ZeroVector;
	// Lane A143 (B-answer-0024 ask b): what a landed `check` did to the victim: `stumble` or `down`; NAME_None for every other event. A read-out, not hashed.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Sim") FName Outcome = NAME_None;
};

// Lane A132 (track F1): UJamSim::ShieldShoveTally (a count for tests and measurements, not state).
struct FJamShieldShoveTally
{
	int32 Presses = 0, AtArm = 0, Shoves = 0, FromBehind = 0, Bump = 0, Stumble = 0, Down = 0;
};

UCLASS(BlueprintType)
class JAMCORE_API UJamSim : public UObject
{
	GENERATED_BODY()

public:
	static constexpr double DT = 1.0 / 60.0;
	static constexpr int32 PuckSubsteps = 4;
	static constexpr double SkaterRadius = 0.4;
	// Lane A93 (R-0045 laws 3 and 4). The first-step burst: armed under this speed (m/s), or by a move input that turned more than 60 degrees (dot under
	// BurstCutDot) inside BurstCutFrames. The reverse brake: the move input more than 120 degrees from the velocity (dot under ReverseBrakeDot); a skater slower
	// than PivotSpeed whose facing is that far from the input turns on the spot instead of thrusting away from where it wants to go. The carrier's sprint:
	// carry_speed_mult x (1 + carry_bonus) never passes CarrierSprintCap of a free skater's 1 + sprint.bonus, whatever the cartridge says.
	static constexpr double BurstSlowSpeed = 2.0;
	static constexpr double BurstRestSpeed = 1.0;   // lane A128: slower than this is at rest (skater.burst.rest_frames)
	static constexpr int32 BurstCutFrames = 10;
	static constexpr double BurstCutDot = 0.5;
	static constexpr double ReverseBrakeDot = -0.5;
	static constexpr double PivotSpeed = 0.5;
	static constexpr double CarrierSprintCap = 0.97;
	static constexpr double NetDepth = 1.5;
	// R-0033 point 2 (lane A50): the net's height is the cartridge's game.rink.goal_height_m (FJamRinkConfig::GoalHeightM, 0.61 by default), no longer a constant.
	static constexpr double PostRadius = 0.05;
	static constexpr double ShotFrontDot = 0.5;      // must face within 60 degrees
	static constexpr int32 CheckWindowFrames = 6;
	// Lane A49 calibrations for the human's check (FEEL.md): a 12-frame window (0.2 s, a person's press is not frame-exact) and a check that lands from 2 m/s
	// of the human's own speed (the sim's rule needs the checker's speed along the contact, and the operator skates slowly into the carrier). Bots keep the cartridge's
	// check_speed_min and the 6-frame window, so the scripted Determinism baseline does not move.
	static constexpr int32 HumanCheckWindowFrames = 12;
	static constexpr double HumanCheckSpeedMinMs = 2.0;
	// The sprint stamina's full value for a config (ticks).
	int32 StaminaFull() const;
	static constexpr double FaceoffDropM = 0.5;      // the faceoff puck lands up to this far off the dot (seeded)
	// R-0013: the faceoff countdown, the draw window after the drop, the penalty box, the pause before a free faceoff after a foul.
	static constexpr int32 FaceoffCountdownFrames = 90;
	static constexpr int32 DrawWindowFrames = 30;
	static constexpr int32 BoxFrames = 300;          // the default of game.rules.penalty_frames (lane A72)
	static constexpr int32 FoulPauseFrames = 60;
	static constexpr double StopGraceMinMps = 6.0;   // lane A163 (game.stick.stop_grace_frames): the stop that earns the grace begins at this speed or more (a shuffle on the spot earns nothing)
	static constexpr double PokeTakeM = 0.35;        // blade-to-puck distance (beyond the puck radius) that takes the puck
	static constexpr double DeflectRangeM = 0.6;     // C-0005: a shot passing within this of a stick deflects
	static constexpr double DeflectKeep = 0.7;       // ... at 70 % of its speed
	static constexpr double DeflectMinSpeed = 6.0;   // slower pucks are just pushed
	static constexpr int32 PassCooldownFrames = 12;
	// Lane A207: a pass in flight lasts at most this many frames (3 s) and ends under PassCatchMinMps; the forgiving catch takes it above that speed.
	static constexpr int32 PassFlightFrames = 180;
	static constexpr double PassCatchMinMps = 1.0;
	// Lane A207 (wave 2b): a bot's pass goes to nobody nearer than this (unless BotUnderHit); the human's to nobody nearer than 2 m.
	static constexpr double BotPassMinM = 3.0;
	// Lane A207 (wave 2b): the shot's fade (game.shot.fade_m) starts this far from the shooter: the close shot stays 2x.
	static constexpr double ShotFadeFromM = 8.0;
	// Lane A207 (wave 2b): frames past the release cooldown in which the passer / shooter cannot take his own puck back (OwnPuckClears).
	static constexpr int32 OwnReleaseLockFrames = 8;
	// Lane A207 (wave 2b): a powered pass leaves at least this much faster than its passer along its line.
	static constexpr double PassExitRelMps = 6.0;
	// Lane A207 (wave 2): the crease skater's reaction before he reads a shot (game.skater.goalie.read_mps).
	static constexpr double GoalieReadDelayS = 0.35;
	static constexpr double CarryYawRateMax = 1.5707963; // rad/s (90 deg/s): carry assist off above it (C-0005)
	// R-0029 point 4 (lane A39): the deke moves the puck over this many frames, a second tap inside the lockout does nothing, the puck sits this far
	// ahead of the body while deked (so it stays inside shot reach at the full offset), the burst needs this clear corridor to the net (half-width, and
	// the crease depth the back may hold without counting as "between"), and the deke shot aims this far inside the post.
	static constexpr int32 DekeMoveFrames = 6;
	static constexpr int32 DekeLockoutFrames = 30;
	static constexpr double DekeAheadM = 0.8;
	static constexpr double BreakawayCorridorM = 4.0;
	static constexpr double BreakawayCreaseM = 6.0;
	static constexpr double BreakawayMinGoalM = 8.0;
	static constexpr int32 BreakawayCarryFrames = 30;
	static constexpr double DekePostInsetM = 0.6;
	// Lane A46 (PAYOFFS.md section 6): body reception. A teammate's puck reaching the body within stick.reception_m at up to this speed is seated on the blade,
	// held there for ReceptionSettleFrames of settle (a shot inside A39's window is a one-timer); a faster puck bounces off the body unless the blade meets it.
	static constexpr double BodyReceptionMaxSpeed = 14.0;
	static constexpr int32 ReceptionSettleFrames = 4;
	// Lane A208 (game.stick.pickup): the sting. An opposing puck faster than pickup.sting_mps rings off the blade keeping this share of its speed against him,
	// and off the body with this restitution (a loose rebound).
	static constexpr double PickupStingKeep = 0.4;
	static constexpr double PickupBodyBounce = 0.0;   // merged tree: 0 = the old body push for a hard puck (its normal motion taken out, it slides off him): at 0.3 a doubled shot glancing off the crease man went wide (Jam.Core.Payoffs.Deke)
	// Lane A208: a team-mate's puck rings off the blade only above sting_mps times this (a shot through a mate; no pass is that fast).
	static constexpr double PickupMateStingMult = 1.5;
	// Lane A208: a skater stripped by a poke or a lift cannot pick the puck up again for this many frames (it was taken, not dropped).
	static constexpr int32 PickupLostFrames = 15;
	// Lane A208 (wave 2): a team-mate's pass in flight is caught within this of his blade point (lane A207's pass.catch_m 1.2), not by the whole arc.
	static constexpr double PickupMateFlightM = 1.2;
	// Lane A208: shot_blocked Variant 1 counts an opponent's puck at this speed or more, heading inside the net it attacks, as a shot.
	static constexpr double ShotBlockMinMps = 12.0;
	// Lane A208 (the lock, R-0067 point 2): with game.stick.pickup on, the carried puck closes on the blade at least at this carry assist (1: 42 % of the
	// gap a substep, 88 % a frame; puck.carry_assist 0.6 closed 68 % a frame and lagged 15 cm and more through hard turns: 97 % of carry frames within 15 cm).
	static constexpr double PickupLockAssist = 0.0;   // READY 2: OFF (= puck.carry_assist). Measured: 1.0 -> 98.3 % of carry frames within 15 cm (from 97.0), 2.4 (on the blade every substep) -> the A201 late hand 89 % (bar 90), the deke payoff and a lockstep coverage test red: wave 3
	// R-0035 (lane A52): the lifted puck. The glass stops a puck under GlassHeightM at the boards (no game.rink.glass_height_m key exists: 2.4 m fixed, a real
	// rink's 2.4 m of glass over 1.2 m of boards); above it the puck is out of play (a free faceoff at the end it left, as after a foul). A puck whose centre is
	// within BarRingM + PostRadius of the crossbar's axis rings `post` and reflects; a puck under the bar by more scores, over it by more flies over the net
	// (its roof is closed). A hop smaller than BounceDeadM dies on the ice. A standing skater's body stops a puck under BodyHeightM (a skater's height; the
	// lift's apex is capped at LiftApexMaxM, so only the top of a lob clears a body); a skater in the crease stance
	// (within CreaseStanceM of its own goal centre, R-0033) saves a puck under game.skater.goalie.block_height_m within goalie.reach_m instead, the human included.
	static constexpr double GlassHeightM = 2.4;
	static constexpr double BarRingM = 0.05;
	static constexpr double BounceDeadM = 0.02;
	static constexpr double BodyHeightM = 1.8;
	// Lane A77 (R-0036): a puck this high or higher is over the blades: no deflection, no reception, no poke takes it (the body still stops it under BodyHeightM).
	static constexpr double BladeClearM = 0.2;
	// A saucer lands this share of the way to its aim point when the way is short; on a long way it flies the apex pass.saucer.lift_m allows and slides the rest.
	static constexpr double SaucerLandFrac = 0.75;
	// The saucer's receiver may have a blade in the lane: the opponent's body must stay this far off the line (the puck flies over the stick, not the body).
	// Lane A82 (R-0040 point 2): 0.9 (A77 measured 0.55 too tight for live bots: 3 of 4 saucers taken 8 cm up). Note: 0.9 is the flat pass's own refusal, so the
	// saucer's receiver set equals the flat pass's; what the saucer buys is the flight over a blade that would deflect the flat pass (MECHANICS-2.md section 3).
	static constexpr double SaucerLaneMinM = 0.9;
	// Lane A82 (R-0040 point 2): the saucer is airborne from this far along the lane (it leaves at 14 m/s and is 0.2 m up after 1.3 m); a blade nearer than this takes it.
	static constexpr double SaucerAirFromM = 1.5;
	static constexpr double CreaseStanceM = 3.0;
	static constexpr double LiftFlightMaxS = 2.0;
	static constexpr double LiftApexMaxM = 2.0;
	static constexpr double SaveReboundKeep = 0.45;   // Director 01:45: 0.3 left 15 of 131 faceoffs without a human touch (budget 13) once the 0.6 full charge put more shots into the pads; a livelier rebound is a chase
	// True when S stands in the crease stance's geometry (R-0033 / R-0035): within CreaseStanceM of its own goal centre, on the ice side of the goal line, able to act.
	bool InCreaseStance(const FJamSkaterState& S) const;
	// Lane A51 (R-0034): the spin. A check that lands mid-spin knocks the carrier down for this multiple of knockdown_frames (risk against reward);
	// the carried puck rides this far from the body centre on the far side from the nearest opponent (inside shot reach, outside the body).
	static constexpr double SpinKnockdownMult = 1.5;
	static constexpr double SpinPuckM = 0.7;
	// Lane A84 (R-0041 point 3): the abilities' fixed geometry. A shotgun knocks down every skater (not the shooter) within ShotgunPathM of the puck's path while
	// it flies (at most ShotgunFlightFrames, until another skater touches it or it slows under DeflectMinSpeed); a hip check pushes the victim HipCheckPushM
	// (the knocked-down glide halves the speed every 0.5 s: a push of v slides v / 2 metres).
	static constexpr double ShotgunPathM = 1.0;
	static constexpr int32 ShotgunFlightFrames = 120;
	static constexpr double HipCheckPushM = 3.0;

	// Lane A84: the ability a skater holds (nullptr = none) and the kind's resolved numbers (absent keys = the kind's defaults, ABILITIES.md).
	const FJamAbilityConfig* HeldAbility(int32 Skater) const;
	static int32 AbilityDefaultCooldown(FName Kind);
	static int32 AbilityDefaultDuration(FName Kind);
	static double AbilityDefaultMagnitude(FName Kind);
	// Lane A84: hands Skater the ability game.abilities[Slot] (a mode at the drop, a pickup on a take); emits `ability` with Strength 0. False for a bad slot.
	bool GrantAbility(int32 Skater, int32 Slot);
	// Lane A110 (track Q1): the online guest's seat plays as a human. The lobby's guest drives a skater the cartridge made a bot slot; SeatGuest marks it bHuman
	// (Restart keeps it), so it gets what the host's human gets: the mode's ability from the drop and a pickup's on a take, the human's check window, move
	// clamp and check-speed floor, and no seeded bot press at the draw (the opening draw's bot press of its team is withdrawn when it is the centre). Call it
	// on both peers at frame 0, before the first Step. False (and nothing changes) for a bad index, the cartridge's own human, or after frame 0.
	// Never called in single player: the Determinism baseline does not move.
	bool SeatGuest(int32 Skater);

	// Builds the match from a validated config: skaters at their spawns, puck at centre, score 0, phase Playing.
	// Queues the opening "faceoff" event. Returns false (and logs) if the config has no player.
	bool Init(const FJamGameConfig& InConfig, uint64 InSeed);

	// New match with the same config and seed (restart on R).
	void Restart();

	// Director's Call / Designer cut applied live (R-0003 3): takes the live-changeable tunables of NewConfig (skater, shot, puck,
	// ice friction, board restitution, goal pause, ai, pickups, look, camera) without resetting the match. Rink geometry
	// (length, width, corner, goal width, obstacles), teams, spawns and the rules mode/end condition never change mid-match;
	// returns the dotted names of the fields that were held back because they differ (empty = everything applied).
	TArray<FString> ApplyLiveConfig(const FJamGameConfig& NewConfig);

	// Timer mode: frames of play elapsed (timer_frames - frames left); 0 in first_to mode.
	int32 GetTimerElapsed() const { return Config.Rules.TimerFrames > 0 ? Config.Rules.TimerFrames - TimerLeft : 0; }

	// ---- C-0005 seam A: modifiers (JamModifiers.h). Lane A14's UJamEffectSystem is the only source. ----
	// None set = base values, bit-identical hashes. The sim collects once per Step, before integration.
	void SetModifierSource(IJamModifierSource* Source) { ModifierSource = Source; }
	IJamModifierSource* GetModifierSource() const { return ModifierSource; }
	// effective(stat, skater) = base * prod(Multiply) + sum(Add), clamped to the schema range; the base value when no modifier touches it.
	// Puck and rink stats (JamStats::IsGlobal) ignore Skater; pass -1 for them.
	double GetEffectiveStat(EJamStat Stat, int32 Skater) const;
	// The modifiers collected for the frame that last ran (ids are part of StateHash).
	const TArray<FJamActiveModifier>& GetActiveModifiers() const { return ActiveModifiers; }
	// ApplyModifier actions queued by rule hooks; the modifier source drains them (once per frame, before the next Step).
	void TakeModifierRequests(TArray<FJamRuleRequest>& Out) { Out.Append(ModifierRequests); ModifierRequests.Reset(); }

	// ---- R-0019 zone seam (Rules/JamZones.h). Lane A15's UJamZoneSystem is the only source. None set = plain ice everywhere. ----
	// Ice under a skater scales its top speed (SpeedMul) and glide friction (FrictionMul); under the puck its friction; bumper zones throw the puck
	// back each substep (BumpPuck); a shot from inside a no_shoot zone is refused with event shot_blocked; pickups only where AllowsPickupAt says.
	void SetZoneSource(IJamZoneSource* Source) { ZoneSource = Source; }
	IJamZoneSource* GetZoneSource() const { return ZoneSource; }
	// For the pickup system (A14): true when no source is set, else the source's answer.
	bool AllowsPickupAt(const FVector2D& PosM) const;

	// ---- C-0005 seam B: rule hooks (JamRuleHooks.h). Lane A15's UJamRuleSystem is the only hook. ----
	// None set = no-op. Triggers fire inside Step (and OnFaceoff / OnPeriodStart inside Restart); actions apply in order in the same frame.
	void SetRuleHook(IJamRuleHook* Hook) { RuleHook = Hook; }
	IJamRuleHook* GetRuleHook() const { return RuleHook; }
	// The pickup system (A14) reports a take here: fires OnPickupTake (Who, Kind). The sim itself has no pickups.
	void NotifyPickupTaken(int32 Who, FName Kind);
	// SpawnPickup actions queued by rule hooks; the pickup system drains them.
	void TakePickupRequests(TArray<FJamRuleRequest>& Out) { Out.Append(PickupRequests); PickupRequests.Reset(); }
	// A tunable by its `values` key (skater_speed, shot_speed, ice_friction, ...) through the live-config path (R-0003 3); false for an unknown key.
	bool SetParam(FName Key, double Value);
	// Period (1-based): timer mode counts thirds of timer_frames (the TAKE card's rule); first_to mode advances only on an EndPeriod action.
	int32 GetPeriod() const { return Period; }
	// Grows by one every time ShrinkRink / GrowRink rebuilt the geometry at a faceoff (and when Restart restores it): the rink actor rebuilds when it changes.
	int32 GetRinkRevision() const { return RinkRevision; }
	bool AreNetsSwapped() const { return bNetsSwapped; }
	// Points a goal is worth for a team (SetScoreMultiplier); 1 by default.
	int32 GetScoreMultiplier(int32 Team) const { return (Team == 0 || Team == 1) ? ScoreMultiplier[Team] : 1; }

	// Advances exactly one frame (1/60 s). Inputs[i] drives skater i; missing entries are zero input.
	void Step(const TArray<FJamInput>& Inputs);

	// FNV-1a 64 over all integer-quantised state (1 mm, 1 mm/s, 1 mrad, counters, score, rng).
	uint64 StateHash() const;
	// Lane A104 (track Q1): the lockstep checkpoint's hash. StateHash() folded with the cross-frame state the rules read but StateHash() leaves out (so the
	// Determinism baseline and the neutral proofs pinned on StateHash() stay valid): LastCarryFrame (foul grace, lift, carrier-cannot-hit), last frame's
	// bSprinting (TryLift's cross-check reads it before StepSkater), last frame's bStickAimed (TryDeke reads it before StepStick), bPokeArmed (the miss stumble),
	// the burst's MoveHist ring, BotDrawFrame while the draw is open. Equal LockstepStateHash() = equal future for equal inputs. A field a lane adds that
	// persists across frames and is read by a rule goes into StateHash() (behind its default) or here.
	uint64 LockstepStateHash() const;
	FString StateHashHex() const { return FString::Printf(TEXT("%016llx"), static_cast<unsigned long long>(StateHash())); }

	// Events produced by the last Step (cleared at the start of every Step).
	const TArray<FJamSimEvent>& GetFrameEvents() const { return FrameEvents; }

	const FJamGameConfig& GetConfig() const { return Config; }
	const TArray<FJamSkaterState>& GetSkaters() const { return Skaters; }
	const FJamPuckState& GetPuck() const { return Puck; }
	int64 GetFrame() const { return Frame; }
	EJamSimPhase GetPhase() const { return Phase; }
	int32 GetScore(int32 Team) const { return (Team == 0 || Team == 1) ? Score[Team] : 0; }
	// -1 while playing; the winning team when Over.
	int32 GetWinner() const { return Winner; }
	int32 GetHumanIndex() const { return HumanIndex; }
	int32 GetHumanTeam() const { return Skaters.IsValidIndex(HumanIndex) ? Skaters[HumanIndex].Team : 0; }
	// Frames left of the goal pause (0 while playing).
	int32 GetPauseFrames() const { return PauseFrames; }
	// R-0013: frames left of the faceoff countdown (0 outside the Faceoff phase); the HUD counts it down.
	int32 GetFaceoffCountdown() const { return Phase == EJamSimPhase::Faceoff ? FaceoffCountdown : 0; }
	// Where the current (or next) faceoff is taken, rink metres.
	FVector2D GetFaceoffDot() const { return FaceoffDot; }
	// True between the drop and the moment a centre won the puck.
	bool IsDrawOpen() const { return bDrawOpen; }
	// Lane A171: the frame of the last drop (-1 before the first): read by the marks' rule (JamCarrierMarks.h), which is quiet for a second after a draw.
	int64 GetDropFrame() const { return DropFrame; }
	// Lane A92 (R-0045, docs/VISION.md law 1, docs/experiments/CONTACT.md): contact by momentum. The kinds of hit and the three outcomes.
	enum class EContactKind : uint8 { Body, Cross };
	static constexpr int32 ContactNone = 0;
	static constexpr int32 ContactBump = 1;
	static constexpr int32 ContactStumble = 2;
	static constexpr int32 ContactDown = 3;
	// The stability an impulse must beat, in kg m/s: mass x game.contact.stability_mps, times: stand_brace when the skater stands or glides under stand_speed_mps
	// and sees the hit (a cross-check inside its front arc ignores the brace; a hit from behind finds it unbraced); else the loss with speed (1 at stand_speed_mps
	// to speed_stability at its top speed); sprint_stability while sprinting; spin_stability in a spin or at a full shot wind-up; unseen_stability from behind.
	// HitDir = the push, attacker towards victim (unit). The brain and the tests read it.
	double StabilityOf(const FJamSkaterState& S, const FVector2D& HitDir, EContactKind Kind) const;
	// Lane A151 (track F1): the brace alone, the factor StabilityOf multiplies in for a skater under stand_speed_mps: 1 against a hit it does not see or a
	// cross-check inside its front arc, stand_brace against the rest, and against a BODY hit from the side contact.StandSideBrace when that is set (falling
	// off to stand_brace at the edge of the front arc; never for the puck carrier, who keeps stand_brace). 1 for a skater at stand_speed_mps or faster.
	// CollideSkaters weighs it in the bounce (bBraceExchange; the carrier weighs 1).
	double BraceOf(const FJamSkaterState& S, const FVector2D& HitDir, EContactKind Kind) const;
	// Lane A151 (track F1): the late press (contact.LatePressFrames, 0 = off). S pressed its check: if S is a human whose body met an opponent's inside the
	// last LatePressFrames frames with no check open, and that man is still up, unshielded and within LatePressRangeM of touching, the press is that hit:
	// ResolveContact on the velocities the two met with, then the bounce of that meeting (a bump leaves today's velocities alone). True = resolved; no
	// window opens. False = nothing to resolve: the caller opens the window as before.
	bool TryLatePress(FJamSkaterState& S);
	// Lane A157 (track F1, evolution 6): the push-out around a downed skater (game.contact.downed_radius_m above 0; CollideSkaters calls it for a pair of
	// which exactly one is down, in place of the ordinary collision). Up, on its feet, is closer than Keep to Down's root: Up alone moves out along the line
	// between them: at once as far as the two body circles (lane A165: the body itself is hard, as in the ordinary collision), and from there to Keep at
	// DownedPushOutMps at most (a skater that was already inside when the other fell is eased out, not thrown); the speed Up had into the
	// body, measured against Down's own slide, is turned along the body: Up keeps at least DownedSlideShare of its speed, on the side it was already
	// passing (its facing decides a dead-centre course), so a skater steering into a downed man goes round him. Down's position and velocity are not
	// written. Deterministic: arithmetic on the two states, in CollideSkaters' pair order.
	void PushOutOfDowned(FJamSkaterState& Up, const FJamSkaterState& Down, double Keep);
	static constexpr double DownedPushOutMps = 6.0;
	static constexpr double DownedSlideShare = 0.8;
	// Lane A157 (track F1, evolution 6): the lunge as a motion (game.contact.lunge_frames, game.contact.lunge_step_mps). While a lunge runs the skater turns
	// at LungeSteerShare of its turn rate; a lunge that runs out on nobody costs LungeMissCost x lunge_step_mps of speed.
	static constexpr double LungeSteerShare = 0.25;
	static constexpr double LungeMissCost = 2.0;
	// Lane A184 (track F1, evolution 9; game.contact.cross_hold): the held cross-check. A hold shorter than CrossHoldTapFrames is a tap (today's cross-check,
	// sent by the press's bLift, unchanged); from that many frames held the skater is braced. Its prices (a commitment, not a shield): no poke, no lift, no
	// reception (the blade takes no pass and no loose puck) and no sprint while braced; top speed x CrossHoldSpeedShare and turn rate x CrossHoldTurnShare;
	// a braced skater hit by a man closing faster than he skates himself stands at CrossHoldExposed of his stability (the stick is across, not braced
	// against the hit). StepCrossHold runs it at the start of the skater's input step.
	static constexpr int32 CrossHoldTapFrames = 10;
	static constexpr double CrossHoldSpeedShare = 0.9;
	static constexpr double CrossHoldTurnShare = 0.7;
	static constexpr double CrossHoldExposed = 0.75;
	void StepCrossHold(FJamSkaterState& S, const FJamInput& In);
	// Lane A184: the lift's swing as TryLift ran it, after the press's cooldown (TryLift calls it at once, or StepWindups when cross_windup_frames runs out).
	void ResolveLift(FJamSkaterState& S);
	// Lane A192: the cross-check's shove at once (true) or deferred by cross_windup_frames (false), and its landing after the wind-up.
	bool CrossShove(FJamSkaterState& S, FJamSkaterState& O, const FVector2D& Dir, bool bStickOnly);
	void LandCrossShove(FJamSkaterState& S);
	bool TryCrossShove(FJamSkaterState& S, FJamSkaterState& O, bool bLive = false);   // lane A215: the deferred shove's tests on one man (bLive: the live window's reach, the stick's); true = resolved on him
	void StepCrossLive(FJamSkaterState& S);
	bool CrossBackHuman(const FJamSkaterState& S) const;   // lane A215: game.contact.cross_back_human for this skater
	void LandCrossBack(FJamSkaterState& S, FJamSkaterState& O, const FVector2D& Dir, bool bStrip);   // lane A215: the human's tap in a carrier's back: a stumble, the puck off his blade   // lane A215: game.contact.cross_live_frames, the stick out after the wind-up
	// Lane A184: the wind-ups' clocks (game.contact.check_windup_frames, cross_windup_frames), in the skater's input step: a check whose wind-up ends opens
	// its window (and its lunge) now; a cross-check whose wind-up ends swings now.
	void StepWindups(FJamSkaterState& S, bool bStickLocked);
	// Lane A184: open the pressed check's window (and the lunge): the press's own frame without a wind-up, the wind-up's last frame with one.
	void OpenCheckWindow(FJamSkaterState& S);
	// Lane A165 (track F1, evolution 7): the board slam (game.contact.board_slam_frames). Earned by a knockdown whose victim's centre is within
	// BoardSlamRangeM of the boards (0.6 m of ice between its body and them) with the attacker closing on it along the boards' outward normal at
	// BoardSlamMinMps or more. ResolveContact reads both.
	static constexpr double BoardSlamRangeM = 1.0;
	static constexpr double BoardSlamMinMps = 4.0;
	static constexpr double LatePressRangeM = 0.7;
	// The impulse a hit by Attacker on Victim along HitDir carries, in kg m/s: mass x max(0, closing speed along HitDir + lunge_mps (Body) or thrust_mps (Cross)).
	double ContactImpulse(const FJamSkaterState& Attacker, const FJamSkaterState& Victim, const FVector2D& HitDir, EContactKind Kind) const;
	// Lane A138 (R-0053 point 3): the cross-check's thrust as it lands: the whole thrust_mps, but on a back (the push along the victim's facing) only as far
	// as the attacker is closing (contact.ShoveBehindMatchMps; 0 = always whole).
	double CrossThrust(const FJamSkaterState& Attacker, const FJamSkaterState& Victim, const FVector2D& HitDir) const;
	// Lane A101 (track F1): the boards are a body. A victim whose centre is within ContactBoardRangeM of the boards cannot give way into them: the impulse of a
	// hit that pushes it there counts x BoardFactor = 1 + (game.contact.board_bonus - 1) x clamp(2 x dot(HitDir, the boards' outward normal), 0, 1): the full bonus
	// inside 60 degrees of straight in, none for a hit along the boards or away from them. 1 at board_bonus 1 (the neutral value). ResolveContact reads it.
	static constexpr double ContactBoardRangeM = 1.5;
	double BoardFactor(const FJamSkaterState& Victim, const FVector2D& HitDir) const;
	// Lane A125 (track F1, R-0050 point 2): the shield refuses the stick, never the shove. True for the two shields that refuse a cross-check's shove as they
	// refuse the lift (R-0040: the spin's body between, the sweep's window), and for nothing else: this is the ONLY shield test TryLift's shove reads. Every other
	// reason IsLiftShielded / IsPokeShielded gives, now or later (track F2's body shield game.stick.body_shield, its take grace game.stick.take_grace_frames),
	// refuses the puck's take only: TryLift then shoves from any side inside the cone and the lift takes nothing. A lane that adds a stick shield adds it to
	// IsPokeShielded and leaves this function alone.
	bool IsShoveShielded(const FJamSkaterState& Attacker, const FJamSkaterState& Carrier) const;
	// Test seam, not state and never hashed: TryLift takes the stick as refused (what IsLiftShielded answers for a body shield or a take grace on a tree that has
	// them), so a scene can force the shield predicate by hand on a tree without those keys. False in every game.
	bool bTestStickRefused = false;
	// Lane A132 (track F1): what the shove rule does in a match, counted by TryLift for tests and measurements. Not state, never hashed, read by no rule; [0] the
	// presses of a bot, [1] of a human. Presses: a lift pressed at an opposing carrier inside range and cone whose take only a stick-only shield refused (the body
	// shield, the take grace: not the spin, the sweep or the shield ability); AtArm: of those, the ones at arm's length (contact.cross_reach_m); Shoves: the ones
	// that resolved as a cross-check's shove (none with contact.bShieldShove false), FromBehind of them along the carrier's facing, and the outcome of each.
	FJamShieldShoveTally ShieldShoveTally[2];
	// Lane A125 (track F1): the check finds its man (game.contact.check_reach_m, 0 = off). While a HUMAN skater's check window is open, its velocity is turned
	// onto the collision course with the nearest standing opponent whose body is within check_reach_m of its own and inside CheckReachConeDeg of where it is
	// going or facing: the man's speed across the line between them is matched (up to CheckReachAcrossMax of the skater's speed), the rest of the skater's
	// speed goes along the line. The speed is kept, none is added; the position is never written. Stateless: the man is found again on every frame of the
	// window. The human's only, like its 12-frame window (lane A49): a bot's brain aims its own check, and with the bend the bots landed a quarter more hits
	// on the human (docs/experiments/CONTACT-4.md). CheckReachTarget = that opponent, -1 none (tests and the brain may read it).
	static constexpr double CheckReachConeDeg = 60.0;
	static constexpr double CheckReachAcrossMax = 0.866;   // sin 60: at least half of the speed still closes
	int32 CheckReachTarget(const FJamSkaterState& S) const;
	void StepCheckReach(FJamSkaterState& S);
	// Lane A209 (track F1, the night; game.contact.check_pull_m, cross_any_man; FJamContactConfig has the rule). StepCheckPull runs after StepCheckReach in the
	// skater's input step: during a human's body-check wind-up (and the window's first frames) it bends his velocity onto the collision course with his man
	// and draws his root toward him, spreading what his own closing will not cover over the wind-up's frames left (at most check_pull_m / the wind-up a
	// frame), so the bodies touch as it ends; during his cross-check's wind-up it draws him toward CrossTarget to half of cross_reach_m. Speed is never
	// added. PullTarget: the nearest opponent on his feet, out of the box, inside CheckReachConeDeg of S's facing, going or stick, gap at most MaxGap; -1 none.
	// PullsHuman: the rule applies to S (a human, the key on, momentum on). EndWindupOnContact: a body check that met its man inside the wind-up is spent.
	static constexpr double PullGoalGapM = -0.01;
	static constexpr double BracePullGapM = 0.5;
	// Lane A209 wave 3 (A210's wish): a meeting inside the human's wind-up counts from this many frames after the press (a contact on the press frame left
	// the figure no coil); an earlier touch is the ordinary collision and the pull brings them together again.
	static constexpr int32 PullMinMeetFrames = 0;   // wave 3: 3 measured: the human's body check inside 2.5 m fell 87.5 -> 71.2 % landed (the early touch's bounce kills the hit): off
	// Lane A209 wave 3: the press buffered. A pulled human's check pressed in the last PressBufferFrames of the stick's recovery, or his cross-check in the
	// last PressBufferFrames of the lift's 30-frame cooldown, is kept (FJamSkaterState::CheckBufferLeft / LiftBufferLeft) and fires on the first frame it
	// is taken again. StepPressBuffer runs on the skater's input before its step (Step's input loop, one line).
	static constexpr int32 PressBufferFrames = 8;
	void StepPressBuffer(FJamSkaterState& S, FJamInput& In);   // lane A209 wave 2: the braced human is drawn onto a man in front within this gap   // the bodies just overlap at the wind-up's end, so the meeting registers on that frame
	bool PullsHuman(const FJamSkaterState& S) const;
	// Lane A209 wave 3: the body check's pull for S: the human's check_pull_m (PullsHuman), a bot's FJamContactConfig::BotCheckPullM (a rule, no key yet:
	// the seam's bot_pull; 0 = off, as shipped); 0 = none. Only the body check's pull and its wind-up meeting read it for a bot.
	double CheckPullFor(const FJamSkaterState& S) const;
	static constexpr double BotPullMinMps = 4.0;   // lane A209 wave 3: a bot's pull only toward a man skating this fast or faster
	int32 PullTarget(const FJamSkaterState& S, double MaxGap) const;
	void StepCheckPull(FJamSkaterState& S);
	void EndWindupOnContact(FJamSkaterState& S);
	// Lane A209 wave 2: a pulled human's cross-check whose man's body meets his inside the wind-up lands then (CollideSkaters; the bounce would part them).
	bool CrossMeets(const FJamSkaterState& X, const FJamSkaterState& O) const;
	bool LandCrossOnMeeting(FJamSkaterState& X);
	double CrossPullFor(const FJamSkaterState& S) const;
	// Lane A209: the cross-check's cone for a pulled human: stick.lift_cone_deg of his facing OR of his stick's aim (the mouse); everyone else OutsideLiftCone.
	bool OutsideCrossCone(const FJamSkaterState& S, const FJamSkaterState& O) const;
	// The carrier cannot hit (game.contact.carrier_can_hit false): true when S carries the puck and no opponent carried it within stick.foul_grace_frames, so a
	// take off an opponent's stick in the same breath still finishes its hit (the mirror of R-0029 point 3, where the victim that just lost the puck still counts
	// as the carrier). The brain reads it.
	bool CarrierMayNotHit(const FJamSkaterState& S) const;
	// The skater carrying the puck right now (last toucher, standing and in control, puck within its reach), -1 when the puck is loose. The brain reads it.
	int32 CarrierIndex() const;
	// Lane A102 (R-0048): the carrier whose puck rides with it right now (the carry assist's own test: carried, not just shot or passed, moving with the
	// carrier or settling on its blade), -1 otherwise. With game.stick.passive_take false nobody else's blade or body takes that puck without a press.
	int32 RidingCarrier() const;
	// R-0042 (lane A85): the carrier's one reach for carrying, charging, shooting and passing: max(shot.reach_m, body radius + stick.reach_m) + 0.05.
	// Since A51 the carried puck lives at the blade (0.4 + stick.reach_m 1.2 = 1.6 m), beyond shot.reach_m 1.5, so every carrier test in the sim reads this
	// (CarrierIndex, StepCharge, StepPassCharge, TryShoot, TryPass, the deke's offset, the knockdown strip); the brain's copy is FJamAIWorld::CarrierReach().
	// Skater -1 = the base value (no modifier).
	double CarrierReachM(int32 Skater) const;
	// R-0029 point 4 (lane A39): true when Skater carries the puck past centre ice, skates at the net and no standing opponent stands in the corridor
	// between it and the crease (the rule of the breakaway burst). The brain and the tests read it.
	bool PastLastDefender(int32 Skater) const;
	// The sideways offset of a deked puck from the body line, rink metres (zero when the skater is not deking); DekeOffsetM clamped so the puck stays in reach.
	FVector2D DekeOffset(const FJamSkaterState& S) const;
	double EffectiveDekeOffsetM() const;
	// The goalie commit of the latest deke: frames left (0 none), the deker and the side (+1 = +z). It runs deke.commit_frames from the tap and, for a shot
	// released inside the deke window, until that puck has crossed the goal line: the brain's crease back follows the puck's old side (puck - (0, side * offset))
	// while it runs. Outlives the carry, so the brain reads it from here, not from the carrier.
	int32 GetDekeCommit(int32& OutSkater, int32& OutSide) const { OutSkater = DekeCommitSkater; OutSide = DekeCommitSide; return DekeCommitFrames; }
	// Tests: ends a running countdown at once with a loose puck at the dot and no draw (so a scripted scene starts in Playing).
	void SkipFaceoff();
	// Lane A51 (R-0034): true when Poker's poke cannot reach the puck Carrier holds: the carrier spins (the body is between), or a sweep shield runs and
	// the poker's blade is on the side the puck left. Tests and the brain read it.
	bool IsPokeShielded(const FJamSkaterState& Poker, const FJamSkaterState& Carrier) const;
	// Lane A82 (R-0040 point 1): the lift is shielded like the poke: a spinning carrier's body is between; a sweep shields the side the puck left for shield_frames.
	bool IsLiftShielded(const FJamSkaterState& Lifter, const FJamSkaterState& Carrier) const { return IsPokeShielded(Lifter, Carrier); }
	// Lane A121 (R-0049 point 2): Carrier has just won the puck (game.stick.take_grace_frames): no poke and no lift takes it. IsPokeShielded includes it. A
	// body check is never refused by it.
	// Lane A138: and the frame it won the puck in (the grace is counted from the end of that frame; a carrier that is not yet TakeOwner has just won it; a
	// placed puck's first carrier has not). stick.bTakeGraceSameFrame false = without that frame.
	bool InTakeGrace(const FJamSkaterState& Carrier) const
	{
		if (Config.Stick.TakeGraceFrames <= 0) return false;
		if (Carrier.TakeGraceLeft > 0) return true;
		return Config.Stick.bTakeGraceSameFrame && TakeOwner != Carrier.Index && TakeOwner != TakeOwnerPlaced && Puck.LastTouch == Carrier.Index;
	}
	// The skater that has carried since the puck last changed hands (-1 = nobody yet; TakeOwnerPlaced = a puck placed by SetPuck, whose first carrier did not
	// win it). The take grace starts when the puck comes to a skater that is not the owner.
	int32 GetTakeOwner() const { return TakeOwner; }
	static constexpr int32 TakeOwnerPlaced = -2;
	// Lane A102 (track F2): puck protection, no button (game.stick.body_shield). True when Carrier's body is between Poker's stick and the puck: Poker's body
	// within BodyShieldRangeM of Carrier's, the puck on the far side of Carrier's body from Poker (inside BodyShieldFarDeg of the line Poker -> Carrier carried on),
	// and Carrier turned: Poker is more than BodyShieldFrontDeg off its facing (a carrier that faces the defender shields nothing). IsPokeShielded includes it,
	// so the poke, the lift and the cross-check's shove are all refused, as for a spinning carrier. No state: nothing new in the hash.
	bool IsBodyShielded(const FJamSkaterState& Poker, const FJamSkaterState& Carrier) const;
	static constexpr double BodyShieldRangeM = 2.0;
	static constexpr double BodyShieldFarDeg = 60.0;
	static constexpr double BodyShieldFrontDeg = 60.0;
	bool OutsideLiftCone(const FJamSkaterState& Lifter, const FJamSkaterState& Victim) const;   // lane A95 (B-to-A-0037): stick.lift_cone_deg
	// Lane A51: the nearest standing opponent of S (-1 none).
	int32 NearestOpponent(const FJamSkaterState& S) const;
	// The teammate a pass from Skater would go to right now (the rule of TryPass) and the aim point; -1 when nobody is open. Scripts and the brain read it.
	// Lane A207: under game.pass.power the receiver is chosen with the powered flight (PickReceiverPowered); its flat set includes the auto-saucer's receivers
	// only when bSaucer asks for them, as before.
	int32 BestPass(int32 Skater, FVector2D& OutAim, bool bSaucer = false) const { return Skaters.IsValidIndex(Skater) ? (PassPowerOn() ? PickReceiverPowered(Skaters[Skater], OutAim, bSaucer) : PickReceiver(Skaters[Skater], OutAim, bSaucer)) : -1; }
	// Lane A207 (track P1, docs/experiments/PASS-SHOT.md): the pass's aim helper, for the sim and the brain alike. Where Passer's pass to Receiver must go so the
	// puck meets the receiver's blade where it will be (his velocity held, the puck's drag and the ice's friction solved), at Speed (<= 0: the speed that arrives
	// at pass.power.arrive_mps, between skater.pass_speed and PassFullSpeed()). OutSpeed = the release speed, OutArrive = its speed at him, OutFlightS = the flight.
	// False when the puck stops before it reaches him at that speed (OutAim is then where he will be when it stops). Pure: reads the state, changes nothing.
	bool AimPassAt(int32 Passer, int32 Receiver, double Speed, FVector2D& OutAim, double& OutSpeed, double& OutArrive, double& OutFlightS) const;
	// Lane A207: game.pass.power on (full_frames > 0); the full pass's speed on this rink; the held pass's speed after HoldFrames of hold.
	bool PassPowerOn() const { return Config.Pass.PowerFullFrames > 0; }
	double PassFullSpeed() const;
	double PassSpeedForHold(int32 HoldFrames) const;
	// Lane A207: the puck on the ice from speed V0: its speed after DistM metres (0 if it stops first), and the release speed that arrives at ArriveMps after DistM.
	double PuckSpeedAfter(double V0, double DistM) const;
	double PuckSpeedToArrive(double DistM, double ArriveMps) const;
	// Lane A207: for the power meter (the HUD): how far a pass released at V0 goes before it slows to pass.power.arrive_mps; and whom the human's pass held
	// HoldFrames with the blade towards StickDir would go to now (-1: nobody in the cone; OutAim then lies along the stick at that reach).
	double PassReachM(double V0) const;
	int32 HumanPassTarget(int32 Skater, const FVector2D& StickDir, int32 HoldFrames, FVector2D& OutAim) const;
	// Lane A207: game.shot.speed_scale (the shot's speed) and the puck's cap factor (never under 1: the cap never drops under puck.max_speed).
	double ShotSpeedScale() const { return FMath::Clamp(Config.Shot.SpeedScale, 0.25, 4.0); }
	double PuckCapScale() const { return FMath::Max(1.0, ShotSpeedScale()); }
	// Timer mode: frames left (0 when not in timer mode). In timer mode a tie at 0 plays on to the next goal.
	int32 GetTimerFrames() const { return TimerLeft; }
	bool IsOvertime() const { return bOvertime; }
	uint64 GetSeed() const { return Seed; }
	FJamRandom& GetRandom() { return Rng; }

	// Geometry helpers (rink metres).
	// Signed distance to the boards: negative inside. OutNormal points outwards (towards the boards).
	double BoardDistance(const FVector2D& P, FVector2D& OutNormal) const;
	// x of the goal line a team attacks (+GL for team 0, -GL for team 1; the other way round after SwapNets); the goal mouth centre is (x, 0).
	double AttackGoalX(int32 Team) const;
	double GoalLineX() const { return Config.Rink.GoalLineX(); }
	// True when a puck centre at P is inside the goal volume of the net at +x (Side +1) or -x (Side -1). The two-argument form is the puck on the ice.
	// R-0033 point 2 (lane A50): with a height (metres above the ice, the puck's centre) the opening is game.rink.goal_height_m tall: a lifted puck at or
	// above the crossbar is no goal. R-0035 (lane A52): the step passes the puck's Z, so a lifted shot over the bar is no goal in play.
	bool InGoal(const FVector2D& P, int32 Side) const { return InGoal(P, Side, 0.0); }
	bool InGoal(const FVector2D& P, int32 Side, double HeightM) const;
	// R-0035 (lane A52): the height a shot of this charge (0..1 of shot.charge_frames_max) arrives at over the goal line: game.shot.lift's tap_m at 0, half_m at
	// half_frames, full_m at the full charge, linear between. The tests and the brain's shot choice read it.
	double LiftForCharge(float Charge) const;

	// Rink metres -> Unreal centimetres (the one conversion; Height in metres above the ice).
	static FVector ToWorld(const FVector2D& P, double HeightM = 0.0) { return FVector(P.X * 100.0, P.Y * 100.0, HeightM * 100.0); }

	// Debug/tests: place the puck (velocity in m/s); the four-argument form also sets its height and vertical speed (R-0035).
	void SetPuck(const FVector2D& Pos, const FVector2D& Vel);
	void SetPuck(const FVector2D& Pos, const FVector2D& Vel, double Z, double VZ);
	// Debug/tests: place a skater.
	void SetSkater(int32 Index, const FVector2D& Pos, const FVector2D& Vel, double Yaw);
	// Director (14 Nov, the H27 release): staging for drills. A skater a drill re-places is in a new scene: its release grace (lane A113) from the scene
	// before ends. The acceptance run fells its opponent with a check and stages the cross-check right after: inside the grace that hit is a bump by rule.
	void ClearReleaseGrace(int32 Index);

private:
	void FaceoffReset();
	void StepFaceoff(const TArray<FJamInput>& Inputs);
	void ResolveDraw(int32 Winner);
	void StepSkater(FJamSkaterState& S, const FJamInput& In);
	void StepStick(FJamSkaterState& S, const FJamInput& In);
	void TryPoke(FJamSkaterState& S);
	// Lane A152 (game.stick.poke_assist_deg): S's open poke reaches the puck its opponent Carrier carries (within the stick's reach and the aim's cone).
	bool PokeReaches(const FJamSkaterState& S, int32 Carrier) const;
	void TryLift(FJamSkaterState& S);
	void ResolvePokes();
	void CallFoul(FJamSkaterState& Fouler, const FJamSkaterState& Victim, const FVector2D& Contact, float Strength, FName Kind);
	FVector2D BoxPos(int32 Team) const;
	void CollideSkaterStatic(FJamSkaterState& S);
	void CollideSkaters();
	// Lane A92: one hit resolved by momentum (a pressed check at contact, or a cross-check): the outcome by impulse / stability, the stumble or the knockdown,
	// the loose puck, the speed that changes hands, the attacker's recoil, the check event and the foul. Returns ContactBump / ContactStumble / ContactDown.
	// Lane A209: MinOutcome (default ContactNone: as before) raises the outcome before the grace, the shield and the stumble rules read it (LandCrossShove: a pulled human's shove is a stumble at least).
	int32 ResolveContact(FJamSkaterState& Attacker, FJamSkaterState& Victim, const FVector2D& Dir, const FVector2D& Contact, EContactKind Kind, int32 MinOutcome = 0, int32 MaxOutcome = 3);   // lane A215: MaxOutcome (3 = ContactDown: none)
	void TryShoot(FJamSkaterState& S, float Charge);
	void StepCharge(FJamSkaterState& S, const FJamInput& In);
	// Lane A77 (R-0036): the held pass charges like the shot and fires on the release; a saucer when held pass.saucer.half_frames or more.
	void StepPassCharge(FJamSkaterState& S, const FJamInput& In);
	// Lane A203 (game.skater.charge_dies_on_loss): the carrier who loses the puck loses his held charges (-1: dead until the button is pressed again).
	void ClearChargeOnLoss(FJamSkaterState& S, const FJamInput& In);
	void TryPass(FJamSkaterState& S, bool bSaucer = false);
	// The saucer's flight: VZ so the puck lands SaucerLandFrac of the way to the aim (or at the apex pass.saucer.lift_m when the way is long), with the drag as ApplyShotLift solves it.
	void ApplySaucerLift(double DistM, double Speed);
	// R-0029 point 4 (lane A39): the deke tap, the burst decision (before the skater moves), and the window bookkeeping after the puck moved.
	void TryDeke(FJamSkaterState& S);
	void StepBreakaway(FJamSkaterState& S);
	void StepPayoffWindows(FJamSkaterState& S);
	// Lane A51 (R-0034): the spin tap, the spin's frame (speed scale, the puck on the far side) after the skater moved, the sweep shield's countdown.
	void TrySpin(FJamSkaterState& S);
	// Lane A84: F pressed: the held ability's use, its cooldown and charge; the shotgun puck's knockdowns per substep; the slow puck's clock after the puck moved.
	void TryAbility(FJamSkaterState& S);
	void StepShotgun(const FVector2D& Prev);
	void StepSlowPuck();
	void ApplySlowPuck(FJamSkaterState& S);
	void StepSpin(FJamSkaterState& S);
	void StepSweepShield(FJamSkaterState& S);
	FVector2D SpinPuckTarget(const FJamSkaterState& S) const;
	void ArmSweepShield(FJamSkaterState& S, int32 Side);
	// Lane A93 (R-0045 law 4): the sweep shield's length for S now: stick.sweep.shield_frames, times sweep.sprint_shield_mult while S sprints.
	int32 SweepShieldFramesFor(const FJamSkaterState& S) const;
	// The teammate a pass from S goes to, and where to aim (lead); -1 when nobody is open.
	int32 PickReceiver(const FJamSkaterState& S, FVector2D& OutAim, bool bSaucer = false) const;
	// Lane A207: PickReceiver's rule (the best open mate) with the powered flight and the blade-led aim (AimPassAt, speed solved); a mate the full pass cannot
	// reach alive is no receiver. And the human's pick: the mate nearest the line Dir inside pass.aim.cone_deg, at Speed (-1: nobody in the cone).
	int32 PickReceiverPowered(const FJamSkaterState& S, FVector2D& OutAim, bool bSaucer = false) const;
	int32 PickReceiverInCone(const FJamSkaterState& S, const FVector2D& Dir, double Speed, FVector2D& OutAim) const;
	// Lane A207: the nearest opponent to the segment From -> To (distance, and how far along the segment), for the flat pass's and the saucer's lane.
	double PassLane(int32 Team, const FVector2D& From, const FVector2D& To, double& OutAlong) const;
	// Lane A207: a pass in flight seated on a team-mate's blade within pass.catch_m (true = seated; StepPuck's per-skater loop calls it first).
	bool TryCatchPass(FJamSkaterState& S);
	// Lane A207 (game.pass.clear_own_body): S's own body lets by the puck S just released (his cooldown runs, the puck fast relative to him).
	bool OwnPuckClears(const FJamSkaterState& S) const;
	// Lane A207 (wave 2): a team-mate who is not the pass's man lets a pass in flight by (body, blade, catch) while it is faster than DeflectMinSpeed
	// against him: a pass aimed at the human is not taken by a mate standing in its lane. Under pass.catch_m only (PassTo is set only then).
	bool PassFliesBy(const FJamSkaterState& S) const;
	// Lane A207 (wave 2, game.skater.goalie.read_mps): the save reach a crease skater adds against the shot in flight at speed Sp.
	double GoalieReadExtraM(double Sp) const;
	// Lane A207 (wave 2b): fades the shot's added speed over the substep the puck just moved (Prev -> Pos).
	void StepShotFade(const FVector2D& Prev);
	// Lane A207 (wave 2b): an opponent within 2 m is closing on S (a bot about to be hit may still pass at 2 m).
	bool BotUnderHit(const FJamSkaterState& S) const;
	// Lane A207 (wave 2c, game.stick.pickup.pass_arc_m): an opponent takes a pass in flight only at his blade.
	bool OppPassBladeOnly(const FJamSkaterState& S) const;
	bool OppBladeMeetsPass(const FJamSkaterState& S, const FVector2D& At) const;
	// Lane A207: the powered pass's release (TryPass under game.pass.power): the receiver, the aim, the speed and the auto-saucer. HoldFrames < 0 = an edge pass.
	// StickIn = this frame's stick input (the blade moves after the pass in the step): the human's aim when |StickIn| > 0.05, else last frame's blade.
	void TryPassPowered(FJamSkaterState& S, int32 HoldFrames, bool bSaucer, const FVector2D& StickIn = FVector2D::ZeroVector);
	void StepPuck();
	// Lane A208 (track F0, R-0067 point 2: "the puck moves through them without locking"; game.stick.pickup, docs/experiments/POSSESSION.md): the loose puck is
	// his who touches it. LoosePickupOn: the rule is on (pickup.arc_m above 0 or pickup.body). MayPlayLoose: S may take a puck nobody carries now (stands, not
	// braced, the puck under the blades, the puck not his own and not riding with another carrier: R-0048's carried puck is taken only by a press).
	// TryLoosePickup: one substep's stick arc. Of every skater whose arc (pickup.arc_m from the body, pickup.arc_deg either side of the blade's or the body's
	// direction) the puck's path [From, now] crosses, the nearest takes it: caught (seated with his motion, his a frame later) or, an opponent's puck faster
	// than pickup.sting_mps, stung off the blade (a loose rebound). Returns the taker, -1 = none. BodyMeetsPuck: the body's own touch with the rule on: the
	// path swept against the body circle (no tunnelling at any speed), the puck stopped at him and his, or above sting_mps bounced off him.
	bool LoosePickupOn() const { return Config.Stick.PickupArcM > 0.0 || Config.Stick.bPickupBody; }
	bool MayPlayLoose(const FJamSkaterState& S) const;
	int32 TryLoosePickup(const FVector2D& From, double R);
	bool BodyMeetsPuck(FJamSkaterState& S, const FVector2D& From, double R);
	// Lane A218 (R-0069 point 2, game.stick.pickup.ring_m): for the HUMAN, a loose puck inside the ring drawn under him (or that his body skates through) is his
	// on that frame, whatever his stick points at and whatever button he holds. TryHumanRing: one substep's test for every human skater (the nearest takes it);
	// returns the taker, -1 = none. Exceptions kept: a puck riding with a carrier (R-0048), over the blades, during the draw, another's pass in flight (A207's
	// catch and pass arc), a puck faster than the sting against him, a stumbling carrier's puck in his reach, through a net's wall, a puck a press just took
	// from him while the presser is still near it (PickupLostFrames, his reach + HumanPressNearM; once the presser is away it is his). HumanReleaseLeaving: his own
	// release is kept from him only while it is still leaving him: opening, under HumanReleaseLockFrames since it left, and either inside its first
	// HumanReleaseGetOffFrames (it gets off his stick: a pass leaves only PassExitRelMps faster than him) or still faster than HumanReleaseFreeMps against him.
	// OwnPuckClears reads it for a puck inside his ring (outside it the lock is as before, so the carry assist never pulls back a pass that is on its way).
	// ring_m 0 = the neutral value (nothing here runs; OwnPuckClears as before).
	int32 TryHumanRing(const FVector2D& From, double R);
	bool HumanReleaseLeaving(const FJamSkaterState& S) const;
	bool HumanRingOn(const FJamSkaterState& S) const { return S.bHuman && Config.Stick.PickupRingM > 0.0; }
	static constexpr int32 HumanReleaseLockFrames = 20;
	static constexpr double HumanReleaseFreeMps = 6.0;
	static constexpr int32 HumanReleaseGetOffFrames = 8;
	static constexpr double HumanPressNearM = 1.5;   // beyond the presser's carry reach: how near he must be for the press's cooldown to keep the puck from the human
	// Lane A208: a net's wall (either net's sides or back) lies across the segment A-B: the arc never takes a puck through a net.
	bool NetBetween(const FVector2D& A, const FVector2D& B) const;
	// Lane A208 (pickup.body): another's carried puck inside S's body is pushed out of it; its carrier keeps it (R-0048).
	void BlockCarried(const FJamSkaterState& S, double R);
	// Lane A216 (A212's FAULT 02:08): the frame never ends with a carried puck inside another standing body (with pickup.body and pickup.block_carried).
	void CarriedOutOfBodies();
	// Lane A208 (contracts/events.md, R-0067 additions): the possess event at the frame's end, and shot_blocked Variant 1 from the pickup and the body.
	void EmitPossess();
	// Lane A208 (game.stick.faceoff): the centres at the dot (FaceoffReset), and the faceoff's no-hit time and place (a check or lift press refused).
	void PlaceFaceoffCentres();
	// Lane A208 (game.puck.net): the own goal mouth as a wall for the defending side's own play; the net's box entered only through the mouth.
	void OwnNetWall(int32 Side, const FVector2D& From, double R, double E);
	void NetBoxGuard(const FVector2D& From, double R);
	bool FaceoffNoHit(const FJamSkaterState& S) const;
	void EmitShotBlocked(const FJamSkaterState& S, double SpeedBefore);
	// Frame-local read-outs of the possess event (set and read inside one Step; not state, never hashed).
	double PossessSpeedAtTake = -1.0;
	double PossessFrameStartSpeed = 0.0;
	int32 PossessVariant = -1;
	int32 PossessTaker = -1;
	int32 PossessTouchAtStart = -1;
	// Lane A208 (game.stick.faceoff.no_hit_frames): the frame the no-hit time after a real drop ends (-1 = none; SkipFaceoff opens none). State: hashed.
	int64 FaceoffNoHitUntil = -1;
	// R-0035 (lane A52): the free puck's height. StepPuckVertical integrates gravity and the ice bounce for one substep and pins a carried puck to the ice;
	// ApplyShotLift gives the shot that just left its VZ for LiftForCharge(Charge) over the goal line; TryGoalieSave is the crease skater's save by height
	// (the saver's index, -1 = no save this substep); OutOfPlay sends a puck over the glass to a free faceoff. All in their own blocks, away from the stick.
	void StepPuckVertical(double H);
	void ApplyShotLift(const FJamSkaterState& S, const FVector2D& Aim, double Speed, float Charge);
	int32 TryGoalieSave(double R, double MaxSpeed);
	void OutOfPlay();
	bool CollidePuckSegment(const FVector2D& A, const FVector2D& B, const FVector2D& PrevPos, double R, double E);
	bool CollidePuckCircle(const FVector2D& C, double CR, double R, double E);
	bool CollidePuckBox(const FVector2D& Min, const FVector2D& Max, double R, double E);
	void ScoreGoal(int32 ScoringTeam);
	void Emit(FName Name, int32 Who, const FVector2D& Where, float Strength, FName Kind = NAME_None, const FVector2D& Dir = FVector2D::ZeroVector, FName Outcome = NAME_None);
	void KnockDown(int32 Victim, const FVector2D& Dir, float Strength, FName Cause);

	// C-0005 seams.
	double BaseStat(EJamStat Stat) const;
	void CollectModifiers();
	void ResolveStats();
	double Eff(EJamStat Stat, int32 Skater) const { return GetEffectiveStat(Stat, Skater); }
	void FireRule(EJamRuleTrigger Trigger, int32 Who, int32 Team, FName Kind, float Value);
	void ApplyRuleAction(const FJamRuleEventIn& In, const FJamRuleActionOut& A);
	void EndPeriodNow();
	void EndMatchNow(int32 Team);
	void UpdatePeriod();
	void ApplyPendingRink();

	// Lane A32 (B-to-A-0026 ask 3): the commentator's read-out events. CheckSave runs where a skater's blade or body is about to touch the puck
	// (before the touch changes the velocity); StepReadouts runs at the end of a Playing frame for breakaway, carry and the clock. None of the
	// state below is hashed: these events describe play, they never change it (C-0003).
	void CheckSave(const FJamSkaterState& Blocker);
	void StepReadouts();
	void ResetReadouts();

	UPROPERTY() FJamGameConfig Config;
	UPROPERTY() TArray<FJamSkaterState> Skaters;
	UPROPERTY() FJamPuckState Puck;
	UPROPERTY() TArray<FJamSimEvent> FrameEvents;

	FJamRandom Rng;
	uint64 Seed = 1;
	int64 Frame = 0;
	EJamSimPhase Phase = EJamSimPhase::Playing;
	int32 Score[2] = { 0, 0 };
	int32 Winner = -1;
	int32 HumanIndex = 0;
	int32 PauseFrames = 0;
	int32 TimerLeft = 0;
	bool bOvertime = false;
	int32 BoardEventCooldown = 0;

	// R-0029 point 4 (lane A39): the goalie commit of the latest deke (see GetDekeCommit).
	int32 DekeCommitFrames = 0;
	int32 DekeCommitSide = 0;
	int32 DekeCommitSkater = -1;
	// Lane A121 (R-0049 point 2): see GetTakeOwner. In StateHash only when game.stick.take_grace_frames is above 0.
	int32 TakeOwner = -1;

	// R-0013 faceoff and draw state.
	int32 FaceoffCountdown = 0;
	FVector2D FaceoffDot = FVector2D::ZeroVector;
	FVector2D PendingFaceoffDot = FVector2D::ZeroVector;
	int64 DropFrame = -1;
	bool bDrawOpen = false;
	int64 BotDrawFrame[2] = { -1, -1 };

	// C-0005 seam state. Everything here is at its default when no source / hook is set, and then adds nothing to the hash.
	IJamModifierSource* ModifierSource = nullptr;
	IJamRuleHook* RuleHook = nullptr;
	IJamZoneSource* ZoneSource = nullptr;
	TArray<FJamActiveModifier> ActiveModifiers;
	// (Skaters.Num() + 1) rows of EJamStat::Count doubles; the last row holds the puck and rink stats.
	TArray<double> EffStats;
	TArray<FJamRuleRequest> PickupRequests;
	TArray<FJamRuleRequest> ModifierRequests;
	int32 ScoreMultiplier[2] = { 1, 1 };
	int32 Period = 1;
	bool bNetsSwapped = false;
	double PendingRinkScale = 1.0;
	int32 RinkRevision = 0;
	int32 RuleDepth = 0;
	// The rink and spawns as Init saw them, so Restart() undoes ShrinkRink / GrowRink.
	FJamRinkConfig InitRink;
	TArray<FVector2D> InitSpawns;

	// Lane A32 read-out state (never hashed, see StepReadouts). The last shot in flight (for "save"), the current possession (for "carry"),
	// the rush already called (for "breakaway"), the take whose last ten seconds were called (for "clock"), the post event gap.
	int64 ShotFrame = -1000000;
	int32 ShotBy = -1;
	float ShotStrength = 0.f;
	int32 CarryIndex = -1;
	int64 CarryStartFrame = 0;
	FVector2D CarryStartPos = FVector2D::ZeroVector;
	FVector2D CarryPrevPuck = FVector2D::ZeroVector;
	double CarryDistM = 0.0;
	bool bCarryAnnounced = false;
	int32 BreakawayFor = -1;
	int32 ClockAnnouncedPeriod = 0;
	int32 PostEventCooldown = 0;
};
