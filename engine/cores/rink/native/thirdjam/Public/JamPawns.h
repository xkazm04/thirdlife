// Render-only actors for the simulation: AJamSkater (a pawn that owns a sim index and drives its IJamSkaterVisual) and
// AJamPuck. Neither writes anything back into UJamSim; transforms are interpolated between the previous and the current
// sim frame with the accumulator alpha. UJamPlaceholderVisual is the M0 capsule + sphere + stick visual (lane A5's toy
// figure replaces it; contracts/skater-visual.md).
#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Pawn.h"
#include "Components/SceneComponent.h"
#include "JamSkaterVisual.h"
#include "JamSim.h"
#include "JamPawns.generated.h"

class UStaticMeshComponent;

// Lane A113 (track F1): the one hit of a sim frame the hit-stop holds on (AJamSkater::HitStopPick). Victim -1 = nothing that involves the human.
struct FJamHitStopPick
{
	int32 Victim = -1, Checker = -1;
	int32 Outcome = 0;      // UJamSim::ContactNone (a knockdown the momentum model did not resolve), ContactStumble (also the human's own bounce) or ContactDown
	float Ratio = 0.f;      // the victim's ContactRatio (the bounce: contact.bump_ratio)
	float Strength = 0.f;   // the hit's event strength: the knockdown's, or the check event's for a stumble
	FName Kind;             // the check event's kind for a knockdown (front, behind, side_l, side_r), "stumble" or "bounce"
};
class UMaterialInstanceDynamic;
class UNiagaraComponent;

UCLASS(ClassGroup = (Jam), meta = (BlueprintSpawnableComponent))
class JAMCORE_API UJamPlaceholderVisual : public USceneComponent, public IJamSkaterVisual
{
	GENERATED_BODY()

public:
	UJamPlaceholderVisual();
	virtual void OnRegister() override;

	virtual void SetTeam_Implementation(int32 TeamId, FLinearColor Colour) override;
	virtual void SetNumber_Implementation(int32 N) override {}
	virtual void UpdateMotion_Implementation(float Speed, float TurnRate, FRotator Facing) override;
	virtual void PlayShoot_Implementation(float Charge) override { SwingFrames = 10 + FMath::RoundToInt32(10.f * FMath::Clamp(Charge, 0.f, 1.f)); }
	virtual void PlayCheck_Implementation() override {}
	virtual void SetKnockedDown_Implementation(bool bDown, float DirX, float DirZ, int32 KnockdownFrames) override;
	virtual void SetHasPuck_Implementation(bool bHasPuck) override {}
	virtual void SetBoost_Implementation(FName Kind) override {}

private:
	UPROPERTY(Transient) TObjectPtr<UStaticMeshComponent> Body;
	UPROPERTY(Transient) TObjectPtr<UStaticMeshComponent> Head;
	UPROPERTY(Transient) TObjectPtr<UStaticMeshComponent> Stick;
	UPROPERTY(Transient) TObjectPtr<UMaterialInstanceDynamic> Mid;
	FLinearColor Colour = FLinearColor::White;
	int32 SwingFrames = 0;
	bool bDown = false;
	FVector2D DownDir = FVector2D(1, 0);
};

UCLASS()
class JAMCORE_API AJamSkater : public APawn
{
	GENERATED_BODY()

public:
	AJamSkater();

	// Sets the index, team and visual. VisualClass: a component class or an actor class implementing IJamSkaterVisual;
	// null or invalid falls back to UJamPlaceholderVisual.
	void InitSkater(int32 InSimIndex, int32 InTeam, const FLinearColor& Colour, int32 Number, UClass* VisualClass);

	// Lane A31 (B-to-A-0021): replaces the visual mid-match (a Director's Call changed game.look.tier and with it the figure class): the old
	// component or attached actor is destroyed, the new one created and the setup calls (SetTeam, SetNumber, SetHasPuck, SetBoost) repeated;
	// the per-frame state flags are cleared so the next ApplySimFrame re-sends knocked-down, puck and faceoff state. Same class: no-op, false.
	bool ResetVisual(const FLinearColor& Colour, int32 Number, UClass* VisualClass);
	UClass* GetVisualClass() const { return VisualObject ? VisualObject->GetClass() : nullptr; }

	// After every sim step: drives the visual (UpdateMotion every frame, one-shots on the frame they happen).
	void ApplySimFrame(const FJamSkaterState& S);

	// Every render frame: interpolated transform.
	void ApplyRender(const FJamSkaterState& S, float Alpha);
	// Lane A127 (track F3): where a boxed skater's figure is drawn (the rink's penalty box seat; ARinkActor sets it). Unset or false: the sim's place on the ice.
	static TFunction<bool(const AJamSkater&, FVector&, FRotator&)> BoxSeat;

	UFUNCTION(BlueprintPure, Category = "Jam|Skater") int32 GetSimIndex() const { return SimIndex; }
	UFUNCTION(BlueprintPure, Category = "Jam|Skater") int32 GetTeam() const { return Team; }
	// The object that implements IJamSkaterVisual (a component, or an attached actor).
	UFUNCTION(BlueprintPure, Category = "Jam|Skater") UObject* GetVisualObject() const { return VisualObject; }

	// Lane A49 (complaint 3, "the stick blinks back and forth"): the aim sent to the visual is smoothed and side-stable. The raw blade angle relative to the
	// facing wraps at +-180 when the aim points behind the skater (the mouse aim is held in rink space while the skater turns); clamped to the figure's +-70
	// holds that wrap is a flip from -70 to +70 every frame the facing jitters. SmoothAimDeg keeps the side the stick was on while the aim is behind (|raw| > 90),
	// only lets the side change through the front, clamps to AimClampDeg and slews at most AimSlewDegPerFrame per frame toward the target (a 6-frame approach).
	static constexpr float AimClampDeg = 70.f;
	static constexpr float AimSlewDegPerFrame = 15.f;
	static float SmoothAimDeg(float RawRelDeg, float Prev, int32& Side, bool& bInit);
	// Lane A210 (wave 4; device B's H55.6, the eye's EYE 4): a puck carried straight ahead is hidden behind the human's own hips at his camera (6 m behind,
	// 3.5 m up: the sight line to a puck 1.25 m ahead passes through his thighs). While HE carries, the figure's stick is never sent closer to his line than
	// the floor: FloorDeg on the backhand (the figure's right, -: its puck socket is then 75 cm out), ForehandK x FloorDeg on the forehand (left, +: 30
	// degrees put the socket only 48 cm out, 45 put it 70: measured, JAMPUCK socket lines). An aim inside the floor goes to the floor on the side it leans
	// to; it changes side only once the raw aim is past 0.4 of the floor on the other. The sim's blade and puck are not touched: only where the figure
	// holds the stick, and so where the carried puck is drawn. jam.puck.CarryAim: FloorDeg (30; 0 = off). Pure.
	// Since the ruling of 02:10 the two floors are their own numbers (jam.puck.CarryAim the backhand's, jam.puck.CarryAimFore the forehand's) and the
	// side inside them is the side the sim's puck is on (PuckSide), so the blade goes to the puck and not away from it; PuckSide 0: as before (the
	// side the stick is on, with the hysteresis).
	static float CarryAimDeg(float RawRelDeg, float PrevSentDeg, bool bCarrying, float FloorBackDeg, float FloorForeDeg, int32 PuckSide = 0);
	static float CarryAimFloorDeg();
	static float CarryAimForeFloorDeg();
	// Wave 4 (the eye's EYE 7: a whiff must look like a whiff): for Frames sim frames the figure's stick is sent to the front of the body (aim 0), whatever
	// the cursor says: after a cross-check that met nobody the stick comes back instead of staying out on the side it shoved to. Presentation only.
	void SetAimRecover(int32 Frames) { AimRecoverLeft = FMath::Max(AimRecoverLeft, Frames); }
	// The last aim and reach sent to the visual (tests, the JAMAIM proof line).
	float GetSentAimDeg() const { return SentAimDeg; }
	float GetSentReachM() const { return SentReachM; }
	void SetLogAim(bool bOn) { bLogAim = bOn; }

	// C-0001 v3 / B-to-A-0014: the world position (cm) of the visual's puck_socket when it exposes one (a mesh socket on any of its components, or a scene
	// component named puck_socket); false when the visual has none. The game mode draws a carried puck there.
	bool GetPuckSocketWorld(FVector& Out) const;
	// Lane A210 (wave 4, R-0067 point 2): the carrier the screen shows. The game mode's FJamPuckShow decides it once per sim step from the sim's carrier of
	// record AFTER the step and tells every pawn before ApplySimFrame: 1 this skater, 0 not; -1 = not told (ApplySimFrame then reads the state's bHasPuck,
	// as before: the lobby, tests, jam.puck.Show 0). IsToldHasPuck: what the figure was last told (the probe).
	// PuckSide (the Director's ruling of 02:10: the drawn puck no more than 45 cm from the sim's): the side of his line the SIM's puck is on, in his own
	// frame: -1 his right (the backhand: a negative aim), +1 his left (the forehand), 0 not known: the carry floor sends the stick to THAT side.
	void SetShownCarrier(int32 State, int32 PuckSide = 0) { ShownCarrier = State; CarryPuckSide = PuckSide; }
	// The component GetPuckSocketWorld reads: a mesh that has the puck_socket socket (bOutIsSocket true: device B's figures) or a scene component named
	// puck_socket (the toy figure); null when the visual has neither.
	USceneComponent* FindPuckSocket(bool& bOutIsSocket) const;
	bool IsToldHasPuck() const { return bHadPuck; }

	// Lane A73 (B-to-A-0036 point 4): the hit-stop. Presentation only: the sim never pauses and lockstep never sees it. The game mode calls BeginHitStop(N) before
	// the hit frame's ApplySimFrame; that frame is applied in full (SetKnockedDown, PlayCheck, the burst all start), then the figure holds the hit frame's pose for N
	// sim frames: no UpdateMotion / SetStickAim / SetShotCharge (the toy's curves stand still), CustomTimeDilation ~0 on the pawn and on a visual actor (B's montage
	// freezes), the one-shot and edge calls still go out so nothing is lost; then it catches up to the live pose over N more frames (a blend, no pop). The victim's
	// SetKnockedDown carries KnockFrames - N: the visual's own clock runs that many frames between the two calls, so B's get-up still ends on the release.
	void BeginHitStop(int32 Frames);
	bool IsHitStopped() const { return HoldLeft > 0; }
	// jam.hitstop (0..6, default 3): the frames the visuals hold on a knockdown that involves the human. 0 = off.
	static int32 HitStopFrames();
	// Lane A101 (track F1): the hold by the hit's outcome and ratio (UJamSim::ContactOutcome / ContactRatio), at jam.hitstop's default 3: a bump 0; a stumble 1,
	// 2 from the middle of the stumble band (bump_ratio..down_ratio); a knockdown 2 at down_ratio to 6 at down_full_ratio and above (lane A132: 5 before). Base = jam.hitstop scales it
	// (x Base / 3, a landed hit never under 1, never over 6; 0 = off). A knockdown the model did not resolve (Outcome 0: contact.momentum false) holds Base.
	static int32 HitStopFramesFor(int32 Outcome, float Ratio, const FJamContactConfig& Contact, int32 Base);
	// Lane A113 (track F1): which hit of this sim frame the hold is for, read from the frame's events and the skaters' read-outs. In order: a knockdown by a
	// check the human took, one it landed, a stumble it took, one it landed, its own bounce. A hit between two bots never hides one that involves the human
	// (the route used to read the frame's last knockdown first and hold nothing when that one was bot on bot). Both ends come from the victim's ContactBy
	// where the momentum model resolved the hit; the frame's last check event names the checker otherwise (contact.momentum false), as before.
	static FJamHitStopPick HitStopPick(const TArray<FJamSkaterState>& Skaters, const TArray<FJamSimEvent>& Events, int32 Human, double BumpRatio);
	// Lane A125 (track F1; proposed C-0001 v5, device B's asks under A-to-B-0021 point 3 and A-to-B-0023 ask 4): two calls made on the figure BY NAME, so a
	// figure that has no function of that name keeps compiling and nothing on the interface header moves:
	//   PlayStumble(DirX, DirZ, Frames)  one-shot on the first frame of a stumble a hit caused (the victim's, or the attacker's own bounce): the push as
	//                                    PlayHitReaction's, Frames = the frames the sim still holds the skater without control (StumbleFramesFor). A figure
	//                                    without it gets PlayHitReaction(DirX, DirZ) as before. A bump keeps PlayHitReaction.
	//   PlayCheckWindup(Frames)          lane A184: one-shot on a body-check press that has a wind-up (game.contact.check_windup_frames): the window opens
	//                                    Frames sim frames later (PlayCheck still plays on the press). A figure without it gets PlayCheck alone.
	//   PlayCrossCheck(Frames)           lane A184: one-shot on every cross-check press (the lift's swing), with the frames until it lands (0 = this frame;
	//                                    game.contact.cross_windup_frames). PlayLift still plays on the press. A figure without it gets PlayLift alone.
	//   SetCrossCheckHold(bOn)           lane A184: level, on the change: true while the sim holds the skater braced (FJamSkaterState::bCrossBraced, the held
	//                                    cross-check), false when the brace ends (released, spent on a body, the skater down). A figure without it gets nothing.
	//   SetBraking(bOn, Decel)           level, on the change: true on the frames the sim applies the reverse brake (FJamSkaterState::bReverseBraking, the sim's
	//                                    own condition), Decel = the speed the sim took off that frame, in m/s^2 (BrakeDecelFor); false, 0 when it ends. A
	//                                    figure without it gets nothing.
	// CallFigure: true when Figure has a function of that name whose parameters are exactly Args.Num() numbers or booleans; each is written by the parameter's
	// own type (bool, any integer, float or double: a Blueprint event's "float" is a double), then the function is called.
	static bool CallFigure(UObject* Figure, FName Function, TConstArrayView<double> Args);
	// Lane A235 (W10, jam.fx.SlideTrail 0): hides the figure's NS_slide_trail components; returns how many. Pure name test beside it.
	static int32 HideSlideTrail(UObject* Visual);
	static bool IsSlideTrailAsset(const FString& AssetName) { return AssetName.Equals(TEXT("NS_slide_trail"), ESearchCase::IgnoreCase); }
	// The frames for PlayStumble on this sim frame, 0 = no stumble began by a hit (a bump, a knockdown, a mistimed poke's own stumble: PlayPoke(false) has it).
	static int32 StumbleFramesFor(const FJamSkaterState& S);
	// The deceleration for SetBraking(true, ...): the sim speed lost since the frame before, per second; 0 when the sim does not reverse-brake this frame.
	static float BrakeDecelFor(double SpeedBefore, const FJamSkaterState& S);

private:
	void SetVisualTimeDilation(float Dilation);
	int32 HoldArmed = 0;       // frames asked for; the next ApplySimFrame is the hit frame
	int32 HoldLeft = 0;        // frames still held
	int32 HoldTotal = 0;
	int32 CatchUpLeft = 0;     // frames of the catch-up blend after the hold
	FVector HeldLoc = FVector::ZeroVector;
	FRotator HeldRot = FRotator::ZeroRotator;


private:
	UObject* CreateVisual(UClass* VisualClass);
	void SetupVisual(UObject* Visual, const FLinearColor& Colour, int32 Number);
	UPROPERTY(VisibleAnywhere, Category = "Jam|Skater") TObjectPtr<USceneComponent> Root;
	UPROPERTY(Transient) TObjectPtr<UObject> VisualObject;
	int32 SimIndex = -1;
	int32 Team = 0;
	bool bWasDown = false;
	bool bHadPuck = false;
	int32 ShownCarrier = -1;   // lane A210: see SetShownCarrier
	int32 CarryPuckSide = 0;
	int32 AimRecoverLeft = 0;  // lane A210: see SetAimRecover
	bool bWasAtFaceoff = false;
	bool bWasPinned = false;   // lane A45 (C-0001 v4): SetBoardPin level, sent on the change
	int32 SeenSoft = 0, SeenMissed = 0, SeenGraced = 0;   // lane A113: the sim's press counters at the last frame applied (the JAMVIS press line)
	bool bWasBraking = false;   // lane A125: SetBraking level, sent on the change
	bool bWasCrossBraced = false;   // lane A184: SetCrossCheckHold level, sent on the change
	// Lane A219 (jam.vis.HitTakeGuard): the last sim frame of this figure's own check or cross-check take (press + wind-up + follow-through); -1 none.
	int64 OwnHitTakeUntil = -1;
	int64 WhiffTakeUntil = -1;   // lane A224: the last sim frame of a whiff take device B plays (-1 none)
	bool bSimBracedLast = false;  // lane A224: the sim's bCrossBraced on the last frame applied
	int64 HoldWhiffAt = -1;       // lane A224: the sim frame the release's whiff is due (-1 none pending)
	// Lane A219, wave 2 (jam.vis.HoldEarly): the sim frame of the cross-check press whose button may still be held (-1 none) and that press's wind-up.
	int64 HoldPressFrame = -1;
	int32 HoldPressWindup = 0;
public:
	// Wave 2, pure, for the test. HoldPoseWanted: is the hold's pose (SetCrossCheckHold) on this frame? Always while the sim braces; with the early hold on
	// also from PressFrame + Windup + Lead while the button is still held (HoldFrames > 0) and he is up, until PressFrame + GiveUp if the sim never braces.
	static bool HoldPoseWanted(bool bEarly, bool bSimBraced, int32 HoldFrames, bool bDown, int64 Frame, int64 PressFrame, int32 Windup, int32 Lead, int32 GiveUp)
	{
		if (bSimBraced) return true;
		if (!bEarly || bDown || HoldFrames <= 0 || PressFrame < 0 || Frame < 0 || Windup <= 0) return false;
		return Frame >= PressFrame + Windup + Lead && Frame <= PressFrame + GiveUp;
	}
	// BrakeLevelToSend: the SetBraking level for this frame: the sim's, except that mode 1 holds the braking pose back while the hold's pose is on.
	static bool BrakeLevelToSend(int32 Mode, bool bSimBraking, bool bHoldPose) { return bSimBraking && !(Mode == 1 && bHoldPose); }
	// Pure, for the test: is PlayHitReaction for a collision kept off this figure? Only a mere collision (no stumble frames), only with the guard on, and
	// only while his own hit take runs (Frame <= TakeUntil) or he holds the brace.
	static bool OwnHitTakeKeeps(bool bGuard, int32 StumbleFrames, int64 Frame, int64 TakeUntil, bool bBraced) { return bGuard && StumbleFrames <= 0 && (bBraced || (TakeUntil >= 0 && Frame >= 0 && Frame <= TakeUntil)); }
	// Lane A224 (jam.vis.WhiffTake, 1 default; 0 = package of 94bb5b48): a miss is device B's take (PlayWhiff(Kind): 0 body check, 1 cross-check). The hit
	// layer (AJamHitRead) tells the pawn the frame it sent the whiff (NoteWhiffTake); while the take runs (WhiffTakeFrames(Kind) sim frames) no other call of
	// A's cuts it: no PlayHitReaction for a mere collision, no SetBraking(true), no PlayLift. A held cross-check released on nobody is a whiff too (sent
	// here). Presentation only.
	static bool WhiffTakeOn();
	static int32 WhiffTakeFrames(int32 Kind) { return Kind == 1 ? 16 : 25; }   // B: CrossCheck_Whiff frames 0-14; PlayCheckWhiff recovers in 25
	void NoteWhiffTake(int32 Kind) { const int64 F = SimFrameForLog(); if (F >= 0) WhiffTakeUntil = F + WhiffTakeFrames(Kind); }
	// Pure, for the test: is the whiff take still running on Frame? (the guard is on, a whiff was sent, Frame within its take)
	static bool WhiffTakeKeeps(bool bOn, int64 Frame, int64 Until) { return bOn && Until >= 0 && Frame >= 0 && Frame <= Until; }
	// Pure, for the test: a held cross-check released on nobody: the sim braced last frame, this frame the button is up (no hold frames), no brace, not
	// down, and the brace was not spent on a body (a braced hit drops bCrossBraced while the button is still down, so it never reaches this).
	static bool HoldReleasedOnNobody(bool bBracedLast, bool bBracedNow, int32 HoldFramesNow, bool bDown) { return bBracedLast && !bBracedNow && HoldFramesNow == 0 && !bDown; }
	// The release's whiff goes out HoldWhiffDelayFrames after the release, and not at all when a new press (a check or a cross-check) came in between:
	// film a-clay-hand f702/f703: a body check pressed one frame after the release was swallowed by the whiff take (device B's figure keeps a running
	// take over the check's wind-up), so the press he made wins.
	static constexpr int32 HoldWhiffDelayFrames = 3;
private:
	bool bWasTakeGrace = false, bWasStickLock = false;   // lane A163 (track F2): the take grace and the stick lock at the last frame applied (the JAMVIS takegrace / sticklock lines)
	double LastSimSpeed = 0.0;   // lane A125: the sim speed at the last frame applied (SetBraking's Decel)
	// Lane A45: the sim frame for the JAMVIS log lines (from the event bus; -1 without one). Log only, never feeds the pose.
	int64 SimFrameForLog() const;
	float LastCharge = 0.f;
	float LastAimDeg = 0.f;
	float LastAimReach = 0.f;
	// Lane A49 aim smoothing state.
	float SentAimDeg = 0.f;
	float SentReachM = 1.2f;
	int32 AimSide = 1;
	bool bAimInit = false;
	bool bLogAim = false;
};

UCLASS()
class JAMCORE_API AJamPuck : public AActor
{
	GENERATED_BODY()

public:
	AJamPuck();
	void InitPuck(double RadiusM, const FLinearColor& Colour);
	void ApplyRender(const FJamPuckState& P, float Alpha);
	// C-0001 v3: a carried puck drawn at the carrier visual's puck_socket (world cm; the puck keeps its own height above the ice).
	void ApplyRenderAt(const FVector& WorldCm);
	// Lane A210 (wave 4): the pieces FJamPuckShow draws with: where ApplyRender would put the puck (the sim's place, height included), a place given whole
	// (height too: a blend between the blade and the sim's place), the carried puck's height, and device B's optional User.Carried on the trail.
	FVector LiveRenderCm(const FJamPuckState& P, float Alpha) const;
	void ApplyRenderBlend(const FVector& WorldCm, float Alpha);
	double GetHalfHeightCm() const { return HalfHeightM * 100.0; }
	void SetTrailCarried(bool bCarried);
	// Lane A210 (wave 4): the carried puck stays on the blade THROUGH the frame's animation. The game mode places the puck before the figures' poses of
	// the frame are evaluated (the socket it reads carries last frame's pose), so a moving stick left the drawn puck a frame behind the blade. With a
	// follow set the puck ticks after the animation (TG_PostUpdateWork) and takes the socket's place again (x and y; its own height on the ice).
	// Comp null = no follow. bCorrect false = measure only (GetLastLagCm: how far the socket had moved from where the puck was placed; -1 = no follow).
	// AnchorCm / MaxOffCm (the ruling of 02:10): with MaxOffCm > 0 the puck is put no further than that from AnchorCm (where the sim has it this
	// frame) on the way to the socket: the drawn puck never strays more than that from the puck a stick can take.
	void SetFollow(USceneComponent* Comp, bool bIsSocket, bool bCorrect, const FVector& AnchorCm = FVector::ZeroVector, double MaxOffCm = 0.0);
	double GetLastLagCm() const { return LastLagCm; }
	virtual void Tick(float DeltaSeconds) override;

	// R-0035 (lane A52): the drawn puck follows the sim's height (FJamPuckState::Z, interpolated like the position); lane A33's cosmetic pop (PopLiftM) is gone,
	// the shadow disc stays on the ice under it. Pure for tests: the drawn centre height in metres for a sim state and an interpolation alpha.
	static double RenderHeightM(const FJamPuckState& P, float Alpha, double HalfHeight);

	// Lane A73: the puck's part of the hit-stop: it holds where it was drawn on the hit frame for N sim frames, then blends to the live place over N more.
	// StepSimFrame is called by the game mode once per sim step (the puck has no ApplySimFrame of its own).
	void BeginHitStop(int32 Frames);
	void StepSimFrame();

private:
	// Lane A73: the one place the drawn location goes through (hold / catch-up applied).
	void Place(const FVector& LiveCm, float Alpha);
	int32 HoldLeft = 0, HoldTotal = 0, CatchUpLeft = 0;
	FVector HeldLoc = FVector::ZeroVector;
	FVector LastPlaced = FVector::ZeroVector;
	bool bEverPlaced = false;
	UPROPERTY(VisibleAnywhere, Category = "Jam|Puck") TObjectPtr<UStaticMeshComponent> Mesh;
	// R-0016: device B's puck kit. The disc lies on the ice under the puck; the trail follows it. Either may be absent (logged once, never an error).
	UPROPERTY(Transient) TObjectPtr<UStaticMeshComponent> Disc;
	// R-0035 (lane A52): the shadow disc on the ice under a (lifted) puck drawn at PuckCm.
	void PlaceDiscOnIce(const FVector& PuckCm);
	UPROPERTY(Transient) TObjectPtr<UNiagaraComponent> Trail;
	TWeakObjectPtr<USceneComponent> FollowComp;   // lane A210: see SetFollow
	bool bFollowIsSocket = false, bFollowCorrect = true;
	FVector FollowAnchor = FVector::ZeroVector;
	double FollowMaxOffCm = 0.0;
	double LastLagCm = -1.0;
	double HalfHeightM = 0.04;
};

// Lane A125 (track F1): a recording stand-in for a figure that implements the two by-name calls the way a Blueprint does (its "float" inputs are doubles), for
// Jam.Core.Contact.FigureCalls. Not a visual: it draws nothing and no game spawns it.
UCLASS()
class JAMCORE_API UJamFigureCallProbe : public UObject
{
	GENERATED_BODY()

public:
	UFUNCTION() void PlayStumble(double DirX, double DirZ, int32 Frames) { ++Stumbles; LastDirX = DirX; LastDirZ = DirZ; LastFrames = Frames; }
	UFUNCTION() void SetBraking(bool bOn, float Decel) { ++Brakes; bLastOn = bOn; LastDecel = Decel; }
	UFUNCTION() void PlayWrongShape(FName Kind) {}
	int32 Stumbles = 0, Brakes = 0, LastFrames = 0;
	double LastDirX = 0.0, LastDirZ = 0.0;
	bool bLastOn = false;
	float LastDecel = 0.f;
};
