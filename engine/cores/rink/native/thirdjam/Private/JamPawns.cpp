#include "JamPawns.h"
#include "Components/StaticMeshComponent.h"
#include "Engine/StaticMesh.h"
#include "Engine/World.h"
#include "Materials/MaterialInterface.h"
#include "Materials/MaterialInstanceDynamic.h"
#include "UObject/ConstructorHelpers.h"
#include "Components/SceneComponent.h"
#include "GameFramework/Actor.h"
#include "NiagaraFunctionLibrary.h"
#include "NiagaraComponent.h"
#include "NiagaraSystem.h"
#include "JamEventBus.h"
#include "Engine/GameInstance.h"
#include "HAL/IConsoleManager.h"
#include "Components/SkinnedMeshComponent.h"
#include "Components/SkeletalMeshComponent.h"
#include "Animation/AnimInstance.h"
#include "Animation/AnimMontage.h"
#include "Animation/AnimSequenceBase.h"

// Lane A80: a presentation-only read-out of the figure's lowest bones against the ice, for the knockdown strips (jam.vis.lowlog 1; off by default; the sim never sees it).
static TAutoConsoleVariable<int32> CVarJamVisLow(TEXT("jam.vis.lowlog"), 0,
	TEXT("1 = log JAMLOW per sim frame for every skater from its knockdown to 70 frames after the release: lowest bone and pelvis / hand / head / foot Z in cm above the pawn's ice plane, the montage. Lane A80 proof."));
namespace
{
	struct FJamLowTrack { int64 Start = -1; int64 Release = -1; float StandPelvis = 0.f; bool bHadDown = false; };
	TMap<const AJamSkater*, FJamLowTrack> GJamLow;

	void JamLowReadout(const AJamSkater* P, UObject* V, const FJamSkaterState& S, int64 Frame, bool bHeld)
	{
		if (CVarJamVisLow.GetValueOnGameThread() == 0) return;
		AActor* A = Cast<AActor>(V);
		if (!A) return;
		FJamLowTrack& T = GJamLow.FindOrAdd(P);
		const bool bDown = S.IsDown();
		if (bDown && !T.bHadDown) { T.bHadDown = true; T.Start = Frame; T.Release = -1; }
		if (!bDown && T.bHadDown && T.Release < 0) T.Release = Frame;
		const bool bActive = bDown || (T.Release >= 0 && Frame - T.Release <= 70);
		if (!bActive) { T.bHadDown = false; }
		if (!bActive && (Frame % 10) != 0) return;
		TArray<USkinnedMeshComponent*> Cs;
		A->GetComponents<USkinnedMeshComponent>(Cs);
		USkinnedMeshComponent* M = nullptr;
		for (USkinnedMeshComponent* C : Cs) if (C && C->GetNumBones() > 0 && (!M || C->GetNumBones() > M->GetNumBones())) M = C;
		if (!M) return;
		M->VisibilityBasedAnimTickOption = EVisibilityBasedAnimTickOption::AlwaysTickPoseAndRefreshBones;
		const float Ice = static_cast<float>(P->GetActorLocation().Z);
		float LowBody = 1e9f; FName LowBodyName;
		float Low = 1e9f, Pelvis = 1e9f, Hand = 1e9f, Head = 1e9f, Foot = 1e9f;
		FName LowName;
		for (int32 i = 0; i < M->GetNumBones(); ++i)
		{
			const FName N = M->GetBoneName(i);
			const float Z = static_cast<float>(M->GetBoneLocation(N, EBoneSpaces::WorldSpace).Z) - Ice;
			if (Z < Low) { Low = Z; LowName = N; }
			const FString L = N.ToString().ToLower();
			const bool bHelper = L.Contains(TEXT("socket")) || L.Contains(TEXT("ik")) || L.Contains(TEXT("root")) || L.Contains(TEXT("stick")) || L.Contains(TEXT("puck")) || L.Contains(TEXT("blade"));
			if (!bHelper && Z < LowBody) { LowBody = Z; LowBodyName = N; }
			if (L.Contains(TEXT("pelvis")) || L.Equals(TEXT("hips"))) Pelvis = FMath::Min(Pelvis, Z);
			else if (L.Contains(TEXT("hand")) && !L.Contains(TEXT("ik"))) Hand = FMath::Min(Hand, Z);
			else if (L.Contains(TEXT("head"))) Head = FMath::Min(Head, Z);
			else if (L.Contains(TEXT("foot"))) Foot = FMath::Min(Foot, Z);
		}
		if (!bActive) { if (Pelvis < 1e8f) T.StandPelvis = Pelvis; return; }
		FString Montage = TEXT("none");
		if (USkeletalMeshComponent* SK = Cast<USkeletalMeshComponent>(M))
			if (UAnimInstance* AI = SK->GetAnimInstance()) if (UAnimMontage* Mo = AI->GetCurrentActiveMontage())
			{
				Montage = Mo->GetName();
				if (Mo->SlotAnimTracks.Num() > 0 && Mo->SlotAnimTracks[0].AnimTrack.AnimSegments.Num() > 0)
					if (const UAnimSequenceBase* Seq = Mo->SlotAnimTracks[0].AnimTrack.AnimSegments[0].GetAnimReference()) Montage = Seq->GetName();
			}
		UE_LOG(LogJamSim, Log, TEXT("JAMLOW frame=%lld skater=%d human=%d down=%d held=%d rel=%lld low_cm=%.1f low=%s pelvis_cm=%.1f hand_cm=%.1f head_cm=%.1f foot_cm=%.1f stand_pelvis_cm=%.1f dir=(%.2f, %.2f) montage=%s"),
			Frame, S.Index, S.bHuman ? 1 : 0, bDown ? 1 : 0, bHeld ? 1 : 0, Frame - T.Start, LowBody, *LowBodyName.ToString(), Pelvis, Hand, Head, Foot, T.StandPelvis, S.KnockDir.X, S.KnockDir.Y, *Montage);
	}
}

namespace
{
	UStaticMesh* LoadShape(const TCHAR* Path) { return LoadObject<UStaticMesh>(nullptr, Path); }

	UStaticMeshComponent* MakePart(USceneComponent* Parent, const TCHAR* Name, const TCHAR* MeshPath, const FVector& Loc, const FRotator& Rot, const FVector& Scale)
	{
		UStaticMeshComponent* C = NewObject<UStaticMeshComponent>(Parent->GetOwner(), Name);
		C->SetStaticMesh(LoadShape(MeshPath));
		C->SetCollisionEnabled(ECollisionEnabled::NoCollision);
		C->SetGenerateOverlapEvents(false);
		C->SetupAttachment(Parent);
		C->SetRelativeLocation(Loc);
		C->SetRelativeRotation(Rot);
		C->SetRelativeScale3D(Scale);
		C->RegisterComponent();
		return C;
	}

	// Rink (x, z) metres -> Unreal centimetres on the ice.
	FVector Lerp2D(const FVector2D& A, const FVector2D& B, float Alpha, double HeightM)
	{
		return UJamSim::ToWorld(A + (B - A) * Alpha, HeightM);
	}
}

// Lane A73 (B-to-A-0036 point 4): the frames the figures, the puck and the presentation frame hold on a knockdown that involves the human. Presentation only:
// the sim steps every frame whatever this says; 0 turns the hit-stop off. The operator tastes it with jam.hitstop 0..6.
// Lane A168 flattened device B's puck disc (jam.puck.Post 0: world scale z 0.01) to hide the upright far-puck marker it carried. Lane A188 (R-0064 point
// 7): device B's push removed the marker from /JamAssets/Props/SM_PuckDisc (dev-b 46bdb717, on main), so the disc keeps its own scale; the cvar is gone.

static TAutoConsoleVariable<int32> CVarJamBoardBumpTake(TEXT("jam.board.BumpTake"), 0,
	TEXT("PlayBoardHit on a plain run into the boards (lane A210): 0 (default) only when the skater was checked into them or goes down; 1 = on every skater board event (package H34: the take throws the stick up on a bump)."), ECVF_Default);
// Lane A219 (track F3, R-0070, 15 Nov: "the player animation should reflect the crosscheck movement and that should be all"). Filmed in package H39: a
// cross-check is thrown INTO a man, so the two bodies meet within a frame or four of the press, the sim reports a collision (bBumpThisFrame, no stumble)
// and the pawn sent PlayHitReaction to the HITTER: device B's reaction take replaced his cross-check take (drill, press f1338, reaction f1339: no frame of
// the shove was drawn; the hand, press f391, reaction f395: the arms dropped two frames before the contact). 1 (default): a figure whose own check or
// cross-check take is running (from the press to OwnHitTakeFollowFrames after its wind-up), or who holds the brace, is not told PlayHitReaction for a
// mere collision; a stumble or a knockdown a hit caused goes out as before. 0 = package H39. Presentation only.
static TAutoConsoleVariable<int32> CVarJamVisHitTakeGuard(TEXT("jam.vis.HitTakeGuard"), 1,
	TEXT("Lane A219: 1 (default) a skater's own check or cross-check take (and the held brace) is not interrupted by PlayHitReaction for a mere collision; 0 = the reaction is always sent (package H39: it replaced the hitter's take)."));
static constexpr int32 OwnHitTakeFollowFrames = 10;   // device B's takes: the drive and the follow-through after the wind-up
// Lane A219, wave 2 (the Director, 15 Nov 12:07, on the final package's strips): PRESS AND HOLD IS ONE MOVEMENT. The sim throws the tap on the press and
// braces 10 to 13 frames later; the pawn called SetCrossCheckHold only then, so the stick went up for the tap (press + 2 to + 8), came DOWN, and rose again
// for the hold (full about 30 frames after the press); and device B's braking pose took the hold away whenever he braked.
//   jam.vis.HoldEarly 1 (default): while the button is still held (the sim's CrossHoldFrames > 0) the hold's pose is called from the frame the tap's
//     wind-up ends (+ jam.vis.HoldEarlyLead), without waiting for the sim's brace; it is dropped the frame the button is released, or HoldEarlyGiveUpFrames
//     after the press if the sim has not braced by then. Once the sim braces the pose simply stays. 0 = the sim's brace alone (package H40).
//   jam.vis.HoldOverBrake 1 (default): SetBraking(true) is not sent while the hold's pose is on (and is taken back when the pose comes on); it goes out
//     when the pose ends if he still brakes. 2 = the brake is sent and the hold is told again right after it. 0 = package H40.
// Presentation only: nothing here is read by the sim.
static TAutoConsoleVariable<int32> CVarJamVisHoldEarly(TEXT("jam.vis.HoldEarly"), 1,
	TEXT("Lane A219 (wave 2): 1 (default) a cross-check still held when its tap's wind-up ends goes straight into the hold's pose (SetCrossCheckHold is called then, not when the sim braces); 0 = on the sim's brace only (package H40: the stick dropped between the tap and the hold)."));
static TAutoConsoleVariable<int32> CVarJamVisHoldEarlyLead(TEXT("jam.vis.HoldEarlyLead"), 0,
	TEXT("Lane A219 (wave 2): frames after the end of the tap's wind-up at which the early hold is called (0 default; negative = before the contact frame)."));
static TAutoConsoleVariable<int32> CVarJamVisHoldOverBrake(TEXT("jam.vis.HoldOverBrake"), 1,
	TEXT("Lane A219 (wave 2): 1 (default) the braking pose is not sent while the hold's pose is on; 2 = it is sent and the hold is told again after it; 0 = package H40 (the braking pose replaced the hold)."));
static constexpr int32 HoldEarlyGiveUpFrames = 20;   // the sim braces 10 (a bot) to 13 (the human's buttons) frames after the press
// Lane A224 (track F3, B's H59.5: "take your bridge dip off the figure"): a miss is device B's own take. 1 (default): the hit layer sends PlayWhiff(Kind)
// on the frame the sim knows the hit met nobody, A's stick-to-front over it (SetAimRecover) and the dip stay off, a held cross-check released on nobody
// is a whiff too, and while the take runs nothing of A's cuts it (PlayHitReaction for a collision, SetBraking(true), PlayLift). 0 = the calls of main
// 94bb5b48 (the whiff and the 30-frame stick-to-front sent into the hold on the frame the sim braces; no whiff on a released hold). Presentation only.
static TAutoConsoleVariable<int32> CVarJamVisWhiffTake(TEXT("jam.vis.WhiffTake"), 1,
	TEXT("Lane A224: 1 (default) a miss is device B's whiff take (PlayWhiff on the sim's miss frame, a released hold on nobody too), kept from A's other calls while it runs, without A's stick-to-front; 0 = the calls of main 94bb5b48."));
bool AJamSkater::WhiffTakeOn() { return CVarJamVisWhiffTake.GetValueOnGameThread() != 0; }

static TAutoConsoleVariable<int32> CVarJamHitStop(TEXT("jam.hitstop"), 3,
	TEXT("Hit-stop frames (0..6, default 3) on a knockdown that involves the human: both figures, the puck, the camera and the HUD hold the hit frame while the sim runs on. 0 = off."));

int32 AJamSkater::HitStopFrames()
{
	return FMath::Clamp(CVarJamHitStop.GetValueOnGameThread(), 0, 6);
}

// Lane A101 (track F1): the hold reads the hit. At jam.hitstop 3: stumble 1 or 2, knockdown 2 to 6 by the ratio; a bump holds nothing.
// Lane A132 (track F1, evolution 4): the hit has a size. A knockdown holds 2 frames at down_ratio (1.0) and 6 at down_full_ratio (3.0) and above (5 before): the
// biggest hit in the game holds three times the smallest knockdown, as it lies two and a half times as long (60 to 150 frames).
int32 AJamSkater::HitStopFramesFor(int32 Outcome, float Ratio, const FJamContactConfig& K, int32 Base)
{
	if (Base <= 0) return 0;
	if (Outcome == UJamSim::ContactNone) return FMath::Clamp(Base, 0, 6);   // a knockdown the model did not resolve (contact.momentum false): as before
	double At3 = 0.0;
	if (Outcome == UJamSim::ContactStumble) At3 = static_cast<double>(Ratio) >= 0.5 * (K.BumpRatio + K.DownRatio) - 1e-6 ? 2.0 : 1.0;   // the read-out is a float: 0.7f is the middle
	else if (Outcome == UJamSim::ContactDown) At3 = FMath::Lerp(2.0, 6.0, FMath::Clamp((static_cast<double>(Ratio) - K.DownRatio) / FMath::Max(1e-6, K.DownFullRatio - K.DownRatio), 0.0, 1.0));
	else return 0;   // a bump
	return FMath::Clamp(FMath::RoundToInt32(At3 * Base / 3.0), 1, 6);
}

FJamHitStopPick AJamSkater::HitStopPick(const TArray<FJamSkaterState>& Sk, const TArray<FJamSimEvent>& Events, int32 Human, double BumpRatio)
{
	static const FName CauseCheck(TEXT("check")), KindStumble(TEXT("stumble")), KindBounce(TEXT("bounce"));
	FJamHitStopPick P;
	int32 LastChecker = -1;
	FName LastKind;
	for (const FJamSimEvent& E : Events) if (E.Name == JamEvents::Check) { LastChecker = E.Who; LastKind = E.Kind; }
	// The check event of one attacker: its strength (closing speed / skater.speed) and its kind.
	auto CheckOf = [&](int32 Who, float& Strength, FName& Kind)
	{
		for (const FJamSimEvent& E : Events) if (E.Name == JamEvents::Check && E.Who == Who) { Strength = E.Strength; Kind = E.Kind; return true; }
		return false;
	};
	// 1. A knockdown by a check: the one the human took, else the one it landed.
	for (const FJamSimEvent& E : Events)
	{
		if (E.Name != JamEvents::Knockdown || E.Kind != CauseCheck) continue;
		const bool bResolved = Sk.IsValidIndex(E.Who) && Sk[E.Who].ContactOutcome == UJamSim::ContactDown;
		const int32 Checker = bResolved && Sk[E.Who].ContactBy >= 0 ? Sk[E.Who].ContactBy : LastChecker;
		if (E.Who != Human && Checker != Human) continue;
		if (P.Victim == Human) continue;   // the human's own fall is already picked
		P.Victim = E.Who;
		P.Checker = Checker;
		P.Outcome = bResolved ? UJamSim::ContactDown : UJamSim::ContactNone;
		P.Ratio = bResolved ? Sk[E.Who].ContactRatio : 0.f;
		P.Strength = E.Strength;
		float Unused = 0.f;
		P.Kind = LastKind;
		CheckOf(Checker, Unused, P.Kind);
	}
	if (P.Victim >= 0) return P;
	// 2. A stumble (no event names its victim: the read-outs do): the one the human took, else the one it landed. Its strength is its check event's.
	for (int32 Pass = 0; Pass < 2 && P.Victim < 0; ++Pass)
	{
		for (const FJamSkaterState& S : Sk)
		{
			if (S.ContactOutcome != UJamSim::ContactStumble || (Pass == 0 ? S.Index != Human : S.ContactBy != Human)) continue;
			P.Victim = S.Index;
			P.Checker = S.ContactBy;
			P.Outcome = UJamSim::ContactStumble;
			P.Ratio = S.ContactRatio;
			FName Unused;
			CheckOf(S.ContactBy, P.Strength, Unused);
			P.Kind = KindStumble;
			break;
		}
	}
	if (P.Victim >= 0) return P;
	// 3. The human's own bounce: it ran into a skater more stable than itself and is the one who stumbles.
	if (Sk.IsValidIndex(Human) && Sk[Human].bRecoilThisFrame)
	{
		P.Victim = Human;
		for (const FJamSkaterState& S : Sk) if (S.ContactBy == Human) P.Checker = S.Index;   // the skater it bounced off
		P.Outcome = UJamSim::ContactStumble;
		P.Ratio = static_cast<float>(BumpRatio);
		FName Unused;
		CheckOf(Human, P.Strength, Unused);   // a bump emits no check event: 0 then
		P.Kind = KindBounce;
	}
	return P;
}

void AJamSkater::BeginHitStop(int32 Frames)
{
	if (Frames <= 0) return;
	HoldArmed = FMath::Clamp(Frames, 1, 6);
}

void AJamSkater::SetVisualTimeDilation(float Dilation)
{
	// The pawn's components (the toy figure, its Niagara) tick with the pawn's dilation; B's figure is an attached actor with a dilation of its own.
	CustomTimeDilation = Dilation;
	if (AActor* A = Cast<AActor>(VisualObject.Get())) A->CustomTimeDilation = Dilation;
}

// ---------- UJamPlaceholderVisual ----------

UJamPlaceholderVisual::UJamPlaceholderVisual()
{
	PrimaryComponentTick.bCanEverTick = false;
}

void UJamPlaceholderVisual::OnRegister()
{
	Super::OnRegister();
	if (Body || !GetOwner()) return;
	// Capsule body 1.8 m, head 0.3 m, stick 1.5 m: engine basic shapes (1 m = 100 units, basic shapes are 100 cm).
	Body = MakePart(this, TEXT("PH_Body"), TEXT("/Engine/BasicShapes/Cylinder.Cylinder"), FVector(0, 0, 70), FRotator::ZeroRotator, FVector(0.6, 0.6, 1.4));
	Head = MakePart(this, TEXT("PH_Head"), TEXT("/Engine/BasicShapes/Sphere.Sphere"), FVector(0, 0, 160), FRotator::ZeroRotator, FVector(0.32));
	Stick = MakePart(this, TEXT("PH_Stick"), TEXT("/Engine/BasicShapes/Cylinder.Cylinder"), FVector(60, 25, 40), FRotator(-55, 0, 0), FVector(0.05, 0.05, 1.5));
	if (UMaterialInterface* Base = LoadObject<UMaterialInterface>(nullptr, TEXT("/Engine/BasicShapes/BasicShapeMaterial.BasicShapeMaterial")))
	{
		Mid = UMaterialInstanceDynamic::Create(Base, this);
		Body->SetMaterial(0, Mid);
		Mid->SetVectorParameterValue(TEXT("Color"), Colour);
	}
}

void UJamPlaceholderVisual::SetTeam_Implementation(int32 TeamId, FLinearColor InColour)
{
	Colour = InColour;
	if (Mid) Mid->SetVectorParameterValue(TEXT("Color"), Colour);
}

void UJamPlaceholderVisual::UpdateMotion_Implementation(float Speed, float TurnRate, FRotator Facing)
{
	if (bDown)
	{
		// Tip over towards the fall direction, in the pawn's local frame.
		const FVector WorldDir(DownDir.X, DownDir.Y, 0);
		const FVector Local = GetComponentTransform().InverseTransformVectorNoScale(WorldDir);
		const FVector Axis = FVector::CrossProduct(FVector::UpVector, Local).GetSafeNormal();
		SetRelativeRotation(FQuat(Axis.IsNearlyZero() ? FVector::RightVector : Axis, FMath::DegreesToRadians(80.f)).Rotator());
		return;
	}
	// Lean into turns (TurnRate + = left), capped.
	const float Lean = FMath::Clamp(2.5f * Speed * TurnRate, -35.f, 35.f);
	SetRelativeRotation(FRotator(0, 0, -Lean));
	if (Stick)
	{
		const float Swing = SwingFrames > 0 ? -40.f * (SwingFrames / 10.f) : 0.f;
		Stick->SetRelativeRotation(FRotator(-55, Swing, 0));
		if (SwingFrames > 0) --SwingFrames;
	}
}

void UJamPlaceholderVisual::SetKnockedDown_Implementation(bool bInDown, float DirX, float DirZ, int32 KnockdownFrames)
{
	bDown = bInDown;
	DownDir = FVector2D(DirX, DirZ);
	if (!bDown) SetRelativeRotation(FRotator::ZeroRotator);
}

// ---------- AJamSkater ----------

AJamSkater::AJamSkater()
{
	PrimaryActorTick.bCanEverTick = false;
	Root = CreateDefaultSubobject<USceneComponent>(TEXT("Root"));
	RootComponent = Root;
	Root->SetMobility(EComponentMobility::Movable);
	AutoPossessAI = EAutoPossessAI::Disabled;
}

UObject* AJamSkater::CreateVisual(UClass* VisualClass)
{
	UObject* Visual = nullptr;
	// A unique name each time: ResetVisual (lane A31) destroys the old component, which stays in memory until GC, so "SkaterVisual" alone would collide.
	const FName CompName = MakeUniqueObjectName(this, VisualClass ? VisualClass : UJamPlaceholderVisual::StaticClass(), TEXT("SkaterVisual"));
	if (VisualClass && VisualClass->ImplementsInterface(UJamSkaterVisual::StaticClass()))
	{
		if (VisualClass->IsChildOf(UActorComponent::StaticClass()))
		{
			UActorComponent* C = NewObject<UActorComponent>(this, VisualClass, CompName);
			if (USceneComponent* SC = Cast<USceneComponent>(C)) SC->SetupAttachment(Root);
			C->RegisterComponent();
			AddInstanceComponent(C);
			Visual = C;
		}
		else if (VisualClass->IsChildOf(AActor::StaticClass()))
		{
			FActorSpawnParameters P;
			P.Owner = this;
			P.SpawnCollisionHandlingOverride = ESpawnActorCollisionHandlingMethod::AlwaysSpawn;
			AActor* A = GetWorld()->SpawnActor<AActor>(VisualClass, GetActorTransform(), P);
			if (A) { A->AttachToComponent(Root, FAttachmentTransformRules::SnapToTargetNotIncludingScale); Visual = A; }
		}
	}
	if (!Visual)
	{
		if (VisualClass) UE_LOG(LogJamSim, Warning, TEXT("JAMSKATER visual class %s does not implement IJamSkaterVisual; using the placeholder"), *VisualClass->GetPathName());
		UJamPlaceholderVisual* C = NewObject<UJamPlaceholderVisual>(this, CompName);
		C->SetupAttachment(Root);
		C->RegisterComponent();
		AddInstanceComponent(C);
		Visual = C;
	}
	return Visual;
}

// Lane A235 (the walk of H45, W10): device B's figure (BP_SkaterVisual_TB1, _TB1_P3) carries a Niagara component SlideFx (NS_slide_trail) that its knockdown
// activates: the streak a downed man's slide leaves on the ice (grey on neon, soot on the day look). A mark at a hit (R-0069, R-0070): 0 (default) the figure's
// NS_slide_trail components are hidden in game when the figure is made (the figure's own Activate and SetVisibility leave that flag alone); 1 = before.
static TAutoConsoleVariable<int32> CVarJamFxSlideTrail(TEXT("jam.fx.SlideTrail"), 0,
	TEXT("Lane A235: 0 (default) the downed man's slide streak (the figure's NS_slide_trail component) is not drawn; 1 = before (drawn). Presentation only."), ECVF_Default);

int32 AJamSkater::HideSlideTrail(UObject* Visual)
{
	AActor* Figure = Cast<AActor>(Visual);
	if (!Figure || CVarJamFxSlideTrail.GetValueOnGameThread() != 0) return 0;
	int32 Hidden = 0;
	TInlineComponentArray<UNiagaraComponent*> Fx(Figure);
	for (UNiagaraComponent* C : Fx)
	{
		if (!C || !(IsSlideTrailAsset(C->GetAsset() ? C->GetAsset()->GetName() : FString()) || C->GetName().StartsWith(TEXT("SlideFx")))) continue;
		C->SetHiddenInGame(true);
		++Hidden;
	}
	if (Hidden > 0) UE_LOG(LogJamSim, Log, TEXT("JAMVIS slidetrail hidden=%d figure=%s (jam.fx.SlideTrail 0)"), Hidden, *Figure->GetClass()->GetName());
	return Hidden;
}

void AJamSkater::SetupVisual(UObject* Visual, const FLinearColor& Colour, int32 Number)
{
	// C-0001: SetTeam and SetNumber once at spawn (B-to-A-0021 point 2: no number is drawn until SetNumber is called), then the resting state.
	VisualObject = Visual;
	HideSlideTrail(Visual);   // lane A235 (jam.fx.SlideTrail)
	IJamSkaterVisual::Execute_SetTeam(Visual, Team, Colour);
	IJamSkaterVisual::Execute_SetNumber(Visual, FMath::Clamp(Number, 0, 99));
	IJamSkaterVisual::Execute_SetHasPuck(Visual, false);
	IJamSkaterVisual::Execute_SetBoost(Visual, NAME_None);
	bWasDown = false;
	bHadPuck = false;
	bWasAtFaceoff = false;
	bWasPinned = false;
	LastCharge = -1.f;   // lane A65: the first ApplySimFrame sends the charge (SetShotCharge goes only on change)
	LastAimDeg = 0.f;
	LastAimReach = 0.f;
}

int64 AJamSkater::SimFrameForLog() const
{
	if (const UGameInstance* GI = GetGameInstance())
	{
		if (const UJamEventBus* Bus = GI->GetSubsystem<UJamEventBus>()) return Bus->GetSimFrame();
	}
	return -1;
}

void AJamSkater::InitSkater(int32 InSimIndex, int32 InTeam, const FLinearColor& Colour, int32 Number, UClass* VisualClass)
{
	SimIndex = InSimIndex;
	Team = InTeam;
	SetupVisual(CreateVisual(VisualClass), Colour, Number);
}

bool AJamSkater::ResetVisual(const FLinearColor& Colour, int32 Number, UClass* VisualClass)
{
	if (VisualObject && VisualClass && VisualObject->GetClass() == VisualClass) return false;
	if (UActorComponent* OldC = Cast<UActorComponent>(VisualObject.Get()))
	{
		RemoveInstanceComponent(OldC);
		OldC->DestroyComponent();
	}
	else if (AActor* OldA = Cast<AActor>(VisualObject.Get()))
	{
		OldA->Destroy();
	}
	VisualObject = nullptr;
	SetupVisual(CreateVisual(VisualClass), Colour, Number);
	return true;
}

// Lane A125 (track F1): the by-name figure calls (JamPawns.h).
float JamCarryReachM();   // lane A210: jam.puck.CarryReach (defined with the cvar below)

bool AJamSkater::CallFigure(UObject* Figure, FName Function, TConstArrayView<double> Args)
{
	UFunction* F = Figure ? Figure->FindFunction(Function) : nullptr;
	if (!F) return false;
	int32 N = 0;
	for (TFieldIterator<FProperty> It(F); It && It->HasAnyPropertyFlags(CPF_Parm); ++It)
	{
		if (It->HasAnyPropertyFlags(CPF_ReturnParm | CPF_OutParm) || !(CastField<FBoolProperty>(*It) || CastField<FNumericProperty>(*It))) return false;
		++N;
	}
	if (N != Args.Num()) return false;
	uint8* Params = static_cast<uint8*>(FMemory_Alloca(FMath::Max<int32>(F->ParmsSize, 1)));
	FMemory::Memzero(Params, F->ParmsSize);
	int32 I = 0;
	for (TFieldIterator<FProperty> It(F); It && It->HasAnyPropertyFlags(CPF_Parm); ++It)
	{
		It->InitializeValue_InContainer(Params);
		const double A = Args[I++];
		if (const FBoolProperty* B = CastField<FBoolProperty>(*It)) B->SetPropertyValue_InContainer(Params, A != 0.0);
		else if (const FNumericProperty* Num = CastField<FNumericProperty>(*It))
		{
			void* Value = Num->ContainerPtrToValuePtr<void>(Params);
			if (Num->IsFloatingPoint()) Num->SetFloatingPointPropertyValue(Value, A);
			else Num->SetIntPropertyValue(Value, static_cast<int64>(FMath::RoundToInt64(A)));
		}
	}
	Figure->ProcessEvent(F, Params);
	for (TFieldIterator<FProperty> It(F); It && It->HasAnyPropertyFlags(CPF_Parm); ++It) It->DestroyValue_InContainer(Params);
	return true;
}

int32 AJamSkater::StumbleFramesFor(const FJamSkaterState& S)
{
	if (S.IsDown() || S.StumbleFrames <= 0 || !S.bBumpThisFrame) return 0;
	return S.ContactOutcome == UJamSim::ContactStumble || S.bRecoilThisFrame ? S.StumbleFrames : 0;
}

float AJamSkater::BrakeDecelFor(double SpeedBefore, const FJamSkaterState& S)
{
	return S.bReverseBraking ? static_cast<float>(FMath::Max(0.0, SpeedBefore - S.Vel.Size()) / UJamSim::DT) : 0.f;
}

void AJamSkater::ApplySimFrame(const FJamSkaterState& S)
{
	if (!VisualObject) return;
	UObject* V = VisualObject;
	// Lane A73: the hit-stop bookkeeping, one step per sim frame. The hit frame (HoldArmed) is applied in full below and its pose recorded; the next HoldTotal
	// frames are "held": edges and one-shots still go out, the continuous calls do not, the actor is drawn at the held pose; then CatchUpLeft frames blend back.
	const bool bHitFrame = HoldArmed > 0;
	if (bHitFrame)
	{
		HoldTotal = HoldArmed;
		HoldLeft = HoldArmed;
		HoldArmed = 0;
		CatchUpLeft = 0;
		HeldLoc = UJamSim::ToWorld(S.Pos, 0.0);
		HeldRot = FRotator(0.0, FMath::RadiansToDegrees(S.Yaw + FMath::DegreesToRadians(S.SpinVisualYawDeg())), 0.0);
		SetVisualTimeDilation(0.0001f);   // not 0: nothing downstream divides by a zero delta
	}
	else if (HoldLeft > 0)
	{
		if (--HoldLeft == 0)
		{
			SetVisualTimeDilation(1.f);
			CatchUpLeft = HoldTotal;
		}
	}
	else if (CatchUpLeft > 0)
	{
		--CatchUpLeft;
	}
	const bool bHeld = !bHitFrame && HoldLeft > 0;
	// B-to-A-0024 point 2 (lane A31): PlayShoot only for a shot; a pass is PlayPass alone (below), never a charge-0 shot in the same frame.
	if (S.bShotThisFrame) IJamSkaterVisual::Execute_PlayShoot(V, S.LastShotCharge);
	if (S.bCheckThisFrame) IJamSkaterVisual::Execute_PlayCheck(V);
	// Lane A184 (track F1, evolution 9; A-to-B-0027 point 1): by name (CallFigure), so the game runs before device B's figure has them and uses them after:
	// the frames from the press to the contact for the two takes, and the braced pose of the held cross-check.
	{
		static const FName NamePlayCheckWindup(TEXT("PlayCheckWindup")), NamePlayCrossCheck(TEXT("PlayCrossCheck")), NameSetCrossCheckHold(TEXT("SetCrossCheckHold"));
		if (S.bCheckThisFrame && S.WindupFrames > 0) CallFigure(V, NamePlayCheckWindup, { static_cast<double>(S.WindupFrames) });
		if (S.bLiftThisFrame)
		{
			const bool bSent = CallFigure(V, NamePlayCrossCheck, { static_cast<double>(S.WindupFrames) });
			if (S.bHuman) UE_LOG(LogJamSim, Log, TEXT("JAMVIS crosscheck frame=%lld skater=%d team=%d human=1 to_contact=%d call=%s"), SimFrameForLog(), S.Index, S.Team, S.WindupFrames, bSent ? TEXT("PlayCrossCheck") : TEXT("PlayLift"));
		}
		// Lane A219: the frames this figure's own hit take runs (the guard below keeps a collision's reaction off it).
		if ((S.bCheckThisFrame || S.bLiftThisFrame) && S.WindupFrames > 0) OwnHitTakeUntil = SimFrameForLog() + S.WindupFrames + OwnHitTakeFollowFrames;
		// Lane A219 (wave 2, jam.vis.HoldEarly): the hold's pose is wanted while the sim braces, and already from the end of the tap's wind-up while the
		// button is still held. bWasCrossBraced is the level SENT to the figure.
		// (The button's level reaches the sim up to three frames after the press, so the press is remembered and the window's end bounds it.)
		if (S.bLiftThisFrame && S.WindupFrames > 0) { HoldPressFrame = SimFrameForLog(); HoldPressWindup = S.WindupFrames; }
		const bool bHoldWanted = HoldPoseWanted(CVarJamVisHoldEarly.GetValueOnGameThread() != 0, S.bCrossBraced, S.CrossHoldFrames, S.IsDown(), SimFrameForLog(), HoldPressFrame,
			HoldPressWindup, CVarJamVisHoldEarlyLead.GetValueOnGameThread(), HoldEarlyGiveUpFrames);
		if (bHoldWanted != bWasCrossBraced)
		{
			bWasCrossBraced = bHoldWanted;
			const bool bSent = CallFigure(V, NameSetCrossCheckHold, { bWasCrossBraced ? 1.0 : 0.0 });
			if (S.bHuman) UE_LOG(LogJamSim, Log, TEXT("JAMVIS crosshold frame=%lld skater=%d team=%d human=1 on=%d speed=%.2f call=%s early=%d press=%lld"), SimFrameForLog(), S.Index, S.Team, bWasCrossBraced ? 1 : 0, S.Vel.Size(), bSent ? TEXT("SetCrossCheckHold") : TEXT("none"),
				bWasCrossBraced && !S.bCrossBraced ? 1 : 0, HoldPressFrame);
		}
		// Lane A224 (jam.vis.WhiffTake): a held cross-check let go on nobody swings through air: device B's cross-check whiff, after the hold's pose is off.
		if (WhiffTakeOn() && !S.bAtFaceoff && !S.InBox() && HoldReleasedOnNobody(bSimBracedLast, S.bCrossBraced, S.CrossHoldFrames, S.IsDown()) && SimFrameForLog() >= 0)
			HoldWhiffAt = SimFrameForLog() + HoldWhiffDelayFrames;
		if (S.bCheckThisFrame || S.bLiftThisFrame || S.bCrossBraced || S.IsDown() || S.InBox() || S.bAtFaceoff || !WhiffTakeOn())
		{
			if (HoldWhiffAt >= 0 && S.bHuman) UE_LOG(LogJamSim, Log, TEXT("JAMVIS whiff frame=%lld skater=%d team=%d human=1 kind=hold_release call=none (a new press or the play came first)"), SimFrameForLog(), S.Index, S.Team);
			HoldWhiffAt = -1;
		}
		else if (HoldWhiffAt >= 0 && SimFrameForLog() >= HoldWhiffAt)
		{
			HoldWhiffAt = -1;
			static const FName NamePlayWhiff(TEXT("PlayWhiff"));
			const bool bSent = CallFigure(V, NamePlayWhiff, { 1.0 });
			if (bSent) NoteWhiffTake(1);
			if (S.bHuman) UE_LOG(LogJamSim, Log, TEXT("JAMVIS whiff frame=%lld skater=%d team=%d human=1 kind=hold_release call=%s until=%lld"), SimFrameForLog(), S.Index, S.Team, bSent ? TEXT("PlayWhiff(1)") : TEXT("none"), WhiffTakeUntil);
		}
		bSimBracedLast = S.bCrossBraced;
	}
	if (S.IsDown() != bWasDown)
	{
		bWasDown = S.IsDown();
		// C-0001 v4: the down time rides along (KnockFrames is the whole knockdown on the frame it starts: StepSkater counts it down from the next step on).
		// Lane A73 sent KnockFrames - HoldTotal (the visual's clock stands still during the hit-stop). Lane A80 measured the get-up drifting one frame earlier per frame of
		// hold: B's montage freezes but its get-up still ends in world time, so the hold was counted twice. The Director (13:30): the unreduced KnockFrames go out.
		const int32 DownFrames = bWasDown ? FMath::Max(1, S.KnockFrames) : 0;
		IJamSkaterVisual::Execute_SetKnockedDown(V, bWasDown, static_cast<float>(S.KnockDir.X), static_cast<float>(S.KnockDir.Y), DownFrames);
		if (bWasDown)
		{
			UE_LOG(LogJamSim, Log, TEXT("JAMVIS knockdown frame=%lld skater=%d team=%d human=%d dir=(%.2f, %.2f) sim_frames=%d sent_frames=%d hitstop=%d"),
				SimFrameForLog(), S.Index, S.Team, S.bHuman ? 1 : 0, S.KnockDir.X, S.KnockDir.Y, S.KnockFrames, DownFrames, bHitFrame ? HoldTotal : 0);
		}
		else
		{
			UE_LOG(LogJamSim, Log, TEXT("JAMVIS getup frame=%lld skater=%d team=%d human=%d (SetKnockedDown false: the sim released the skater)"), SimFrameForLog(), S.Index, S.Team, S.bHuman ? 1 : 0);
		}
	}
	// Lane A45 (C-0001 v4, R-0031 point 1): B's four calls from the sim's read-outs (JamSim.h, never hashed). One JAMVIS line each, a few per minute, so B can read what was sent.
	if (S.bBumpThisFrame && !S.IsDown())
	{
		// Lane A125 (track F1): a stumble is told apart from a bump. The first frame of a stumble a hit caused goes out as PlayStumble(DirX, DirZ, Frames) on a
		// figure that has it (by name: CallFigure), with the frames the sim holds the skater without control; any other figure, and every bump, gets
		// PlayHitReaction as before. One JAMVIS stumble line either way (call = what was sent).
		const int32 StumbleFrames = StumbleFramesFor(S);
		static const FName NamePlayStumble(TEXT("PlayStumble"));
		const bool bStumbleSent = StumbleFrames > 0 && CallFigure(V, NamePlayStumble, { S.BumpDir.X, S.BumpDir.Y, static_cast<double>(StumbleFrames) });
		// Lane A219 (jam.vis.HitTakeGuard): a mere collision (no stumble) does not replace the take of his own check or cross-check, nor the held brace.
		const bool bOwnTake = OwnHitTakeKeeps(CVarJamVisHitTakeGuard.GetValueOnGameThread() != 0, StumbleFrames, SimFrameForLog(), OwnHitTakeUntil, bWasCrossBraced)
			|| (StumbleFrames <= 0 && WhiffTakeKeeps(WhiffTakeOn(), SimFrameForLog(), WhiffTakeUntil));   // lane A224: nor his whiff take
		if (!bStumbleSent && bOwnTake)
		{
			if (S.bHuman) UE_LOG(LogJamSim, Log, TEXT("JAMVIS hit frame=%lld skater=%d team=%d dir=(%.2f, %.2f) kept=own_take until=%lld braced=%d (PlayHitReaction NOT sent: his own check or cross-check take is running)"),
				SimFrameForLog(), S.Index, S.Team, S.BumpDir.X, S.BumpDir.Y, OwnHitTakeUntil, bWasCrossBraced ? 1 : 0);
		}
		else if (!bStumbleSent)
		{
		IJamSkaterVisual::Execute_PlayHitReaction(V, static_cast<float>(S.BumpDir.X), static_cast<float>(S.BumpDir.Y));
		UE_LOG(LogJamSim, Log, TEXT("JAMVIS hit frame=%lld skater=%d team=%d dir=(%.2f, %.2f) (PlayHitReaction: a collision at 3 m/s closing or more, no check landed)"),
			SimFrameForLog(), S.Index, S.Team, S.BumpDir.X, S.BumpDir.Y);
		}
		if (StumbleFrames > 0)
		{
			UE_LOG(LogJamSim, Log, TEXT("JAMVIS stumble frame=%lld skater=%d team=%d human=%d dir=(%.2f, %.2f) frames=%d by=%d ratio=%.2f recoil=%d call=%s (the first frame of a stumble by a hit)"),
				SimFrameForLog(), S.Index, S.Team, S.bHuman ? 1 : 0, S.BumpDir.X, S.BumpDir.Y, StumbleFrames, S.ContactBy, S.ContactRatio, S.bRecoilThisFrame ? 1 : 0,
				bStumbleSent ? TEXT("PlayStumble") : TEXT("PlayHitReaction"));
		}
	}
	// Lane A125 (track F1): the braking read-out, a level sent on the change: the sim's own reverse-brake condition (bReverseBraking), never the pawn's speed.
	// By name (CallFigure): a figure without SetBraking gets nothing. The JAMVIS line is the human's only (a bot reverses some 2,000 times a match).
	// The read-out is written by the skater's own step: a faceoff or a period break (no step) leaves the last value standing, so a skater the sim holds still
	// is not braking whatever the flag says.
	// Lane A219 (wave 2, jam.vis.HoldOverBrake): the level SENT is the sim's brake, held back while the hold's pose is on (mode 1). bWasBraking is the sent level.
	const int32 HoldOverBrake = CVarJamVisHoldOverBrake.GetValueOnGameThread();
	const bool bBrakingNow = BrakeLevelToSend(HoldOverBrake, S.bReverseBraking && !S.Vel.IsNearlyZero(), bWasCrossBraced)
		&& !WhiffTakeKeeps(WhiffTakeOn(), SimFrameForLog(), WhiffTakeUntil);   // lane A224: no braking pose over the whiff take
	if (bBrakingNow != bWasBraking)
	{
		bWasBraking = bBrakingNow;
		const float Decel = BrakeDecelFor(LastSimSpeed, S);
		static const FName NameSetBraking(TEXT("SetBraking"));
		const bool bBrakeSent = CallFigure(V, NameSetBraking, { bWasBraking ? 1.0 : 0.0, static_cast<double>(Decel) });
		// Mode 2: the brake goes out and the hold is told again over it.
		static const FName NameHoldAgain(TEXT("SetCrossCheckHold"));
		const bool bHoldAgain = HoldOverBrake == 2 && bWasCrossBraced && CallFigure(V, NameHoldAgain, { 1.0 });
		if (S.bHuman)
		{
			UE_LOG(LogJamSim, Log, TEXT("JAMVIS brake frame=%lld skater=%d team=%d human=1 on=%d decel=%.1f speed=%.2f call=%s hold_pose=%d hold_again=%d (SetBraking: the sim's reverse brake)"),
				SimFrameForLog(), S.Index, S.Team, bWasBraking ? 1 : 0, Decel, S.Vel.Size(), bBrakeSent ? TEXT("SetBraking") : TEXT("none"), bWasCrossBraced ? 1 : 0, bHoldAgain ? 1 : 0);
		}
	}
	LastSimSpeed = S.Vel.Size();
	if (S.bBoardHitThisFrame)
	{
		// Lane A210 (wave 4, the eye's EYE 12: a board bump throws his stick up): device B's board take plays only when he was CHECKED into the boards
		// (bContactBoard) or is going down; a plain run into them keeps the stick where it is. jam.board.BumpTake 1 = every board event (package H34).
		const bool bTake = CVarJamBoardBumpTake.GetValueOnGameThread() != 0 || S.bContactBoard || S.IsDown();
		if (bTake) IJamSkaterVisual::Execute_PlayBoardHit(V);
		// Lane A101: also on a landed check that pushed the skater into boards within 1.5 m (bContactBoard; the `board` event then carries the check's strength).
		UE_LOG(LogJamSim, Log, TEXT("JAMVIS board frame=%lld skater=%d team=%d checked=%d outcome=%d ratio=%.2f (PlayBoardHit: the skater board event: 4 m/s and up into the boards, or checked into them)"),
			SimFrameForLog(), S.Index, S.Team, S.bContactBoard ? 1 : 0, S.ContactOutcome, S.ContactRatio);
	}
	// Lane A113 (track F1): what became of the human's own check press when it did not land (the sim's counters behind the HUD's contact line), one JAMVIS line
	// when one grows: the headless read-out of JUST GOT UP / TOO SOFT / MISSED (the HUD does not run under -nullrhi; an acceptance row can read this line). A
	// restart sets the counters back: no line then. And one line for any skater whose hit the release grace made a bump.
	if (S.ChecksSoft != SeenSoft || S.ChecksMissed != SeenMissed || S.ChecksGraced != SeenGraced)
	{
		const TCHAR* Result = S.ChecksGraced > SeenGraced ? TEXT("just_got_up") : S.ChecksSoft > SeenSoft ? TEXT("too_soft") : S.ChecksMissed > SeenMissed ? TEXT("missed") : nullptr;
		if (Result && S.bHuman)
		{
			UE_LOG(LogJamSim, Log, TEXT("JAMVIS press frame=%lld skater=%d team=%d human=1 result=%s soft=%d missed=%d graced=%d (the human's check press did not land; the HUD's contact line)"),
				SimFrameForLog(), S.Index, S.Team, Result, S.ChecksSoft, S.ChecksMissed, S.ChecksGraced);
		}
		SeenSoft = S.ChecksSoft; SeenMissed = S.ChecksMissed; SeenGraced = S.ChecksGraced;
	}
	if (S.bContactGrace)
	{
		UE_LOG(LogJamSim, Log, TEXT("JAMVIS grace frame=%lld skater=%d team=%d human=%d by=%d ratio=%.2f grace_left=%d (a hit inside the release grace: a bump at most)"),
			SimFrameForLog(), S.Index, S.Team, S.bHuman ? 1 : 0, S.ContactBy, S.ContactRatio, S.GraceFrames);
	}
	// Lane A163 (track F2, evolution 6): the carrier's two states the player could not see, as the pawn sees them (read-outs of hashed state; nothing is
	// written back). C-0001 has no figure call for either (asked of device B in the lane's report); the HUD shows them (UJamHudWidget::UpdateCarrierCues),
	// and the HUD does not tick under -nullrhi, so these lines are the headless read-out. takegrace: one line when a skater's grace begins (every puck
	// won) and, for the human, when it ends; sticklock: a person's missed poke, on and off.
	if ((S.TakeGraceLeft > 0) != bWasTakeGrace)
	{
		bWasTakeGrace = S.TakeGraceLeft > 0;
		if (bWasTakeGrace || S.bHuman)
		{
			UE_LOG(LogJamSim, Log, TEXT("JAMVIS takegrace frame=%lld skater=%d team=%d human=%d on=%d frames=%d (game.stick.take_grace_frames: no stick takes this skater's puck; the HUD's ring under it turns yellow and closes)"),
				SimFrameForLog(), S.Index, S.Team, S.bHuman ? 1 : 0, bWasTakeGrace ? 1 : 0, S.TakeGraceLeft);
		}
	}
	if ((S.StickLockLeft > 0) != bWasStickLock)
	{
		bWasStickLock = S.StickLockLeft > 0;
		UE_LOG(LogJamSim, Log, TEXT("JAMVIS sticklock frame=%lld skater=%d team=%d human=%d on=%d frames=%d (game.stick.miss_recovery_frames: no poke, lift or check; the HUD's contact line says STICK LOCKED)"),
			SimFrameForLog(), S.Index, S.Team, S.bHuman ? 1 : 0, bWasStickLock ? 1 : 0, S.StickLockLeft);
	}
	if (S.bBoardPinned != bWasPinned)
	{
		bWasPinned = S.bBoardPinned;
		IJamSkaterVisual::Execute_SetBoardPin(V, bWasPinned);
		UE_LOG(LogJamSim, Log, TEXT("JAMVIS pin frame=%lld skater=%d team=%d on=%d board_frames=%d (SetBoardPin: 10 frames on the boards with an opponent within 1.2 m)"),
			SimFrameForLog(), S.Index, S.Team, bWasPinned ? 1 : 0, S.BoardFrames);
	}
	if (S.StickHitResult != 0)
	{
		IJamSkaterVisual::Execute_PlayStickHit(V, S.StickHitResult == 2);
		UE_LOG(LogJamSim, Log, TEXT("JAMVIS stickhit frame=%lld skater=%d team=%d lifted=%d (PlayStickHit: the carrier lost the puck to a clean %s)"),
			SimFrameForLog(), S.Index, S.Team, S.StickHitResult == 2 ? 1 : 0, S.StickHitResult == 2 ? TEXT("lift") : TEXT("poke"));
	}
	// Lane A210 (wave 4): the flag follows the carrier the screen shows when the game mode told it (SetShownCarrier), else the state's bHasPuck.
	const bool bHasPuckNow = ShownCarrier >= 0 ? ShownCarrier == 1 : S.bHasPuck;
	if (bHasPuckNow != bHadPuck)
	{
		bHadPuck = bHasPuckNow;
		IJamSkaterVisual::Execute_SetHasPuck(V, bHadPuck);
	}
	// Lane A73: while held, the continuous calls (UpdateMotion, SetStickAim, SetShotCharge) stay away: the figure keeps the hit frame's motion state.
	JamLowReadout(this, V, S, SimFrameForLog(), bHeld);   // lane A80: off unless jam.vis.lowlog 1
	if (bHeld)
	{
		if (S.PokeResult != 0) IJamSkaterVisual::Execute_PlayPoke(V, S.PokeResult > 0);
		if (S.bLiftThisFrame && !WhiffTakeKeeps(WhiffTakeOn(), SimFrameForLog(), WhiffTakeUntil)) IJamSkaterVisual::Execute_PlayLift(V);   // lane A224
		if (S.bPassThisFrame) IJamSkaterVisual::Execute_PlayPass(V, S.LastPassStrength);
		if (S.bAtFaceoff != bWasAtFaceoff) { bWasAtFaceoff = S.bAtFaceoff; IJamSkaterVisual::Execute_SetFaceoff(V, bWasAtFaceoff); }
		if (S.DrawResult != 0) IJamSkaterVisual::Execute_PlayFaceoffDraw(V, S.DrawResult > 0);
		if (S.bFoulThisFrame) IJamSkaterVisual::Execute_PlayFoulReaction(V);
		return;
	}
	// Contract: turn rate positive = turning left seen from above; the sim's yaw grows to the right (Unreal yaw).
	// Lane A51 (R-0034): the spin is a yaw turn of the visual over the spin's frames (FJamSkaterState::SpinVisualYawDeg) through the existing facing call;
	// the sim's own yaw keeps the body's line. The stick aim below is measured against the turned facing so the blade stays where the puck is.
	const double SpinDeg = S.SpinVisualYawDeg();
	const double VisualYaw = S.Yaw + FMath::DegreesToRadians(SpinDeg);
	IJamSkaterVisual::Execute_UpdateMotion(V, static_cast<float>(S.Vel.Size()), static_cast<float>(-S.YawRate - (S.SpinFrames > 0 && S.SpinLength > 0 ? S.SpinDir * 2.0 * UE_DOUBLE_PI / (S.SpinLength * UJamSim::DT) : 0.0)),
		FRotator(0.0, FMath::RadiansToDegrees(VisualYaw), 0.0));

	// C-0001 v3 (B-to-A-0014): the stick verbs. Aim: the blade relative to the facing, positive = left (the sim's yaw grows to the right).
	// Lane A49: smoothed and side-stable before it is sent (SmoothAimDeg); the reach follows with the same 6-frame approach.
	{
		const FVector2D D = S.BladePos - S.Pos;
		const double Rel = FMath::UnwindRadians(FMath::Atan2(D.Y, D.X) - VisualYaw);   // lane A51: against the spun facing
		const float AimDeg = static_cast<float>(-FMath::RadiansToDegrees(Rel));
		const float Reach = static_cast<float>(D.Size());
		LastAimDeg = AimDeg;
		LastAimReach = Reach;
		const float Prev = SentAimDeg;
		// Lane A210 (wave 4): the human's carried stick stays out of the zone his own hips hide (CarryAimDeg); the raw aim is logged and kept as it was.
		float AimForFigure = CarryAimDeg(AimDeg, SentAimDeg, S.bHuman && bHadPuck, CarryAimFloorDeg(), CarryAimForeFloorDeg(), CarryPuckSide);
		if (AimRecoverLeft > 0) { --AimRecoverLeft; if (!bHadPuck) AimForFigure = 0.f; }   // wave 4: after a whiff the stick comes back to the front
		SentAimDeg = SmoothAimDeg(AimForFigure, SentAimDeg, AimSide, bAimInit);
		// Lane A210 (the last wave): the reach sent while the human carries (jam.puck.CarryReach; 0 = the reach of the sim): the drawn puck in a gap of the HUD ring, not on a band.
		const float CarryReach = (S.bHuman && bHadPuck) ? JamCarryReachM() : 0.f;
		const float ReachForFigure = CarryReach > 0.f ? CarryReach : Reach;
		SentReachM = FMath::IsNearlyZero(SentReachM) ? ReachForFigure : SentReachM + (ReachForFigure - SentReachM) * 0.35f;
		if (bLogAim)
		{
			int64 Frame = -1;
			if (UGameInstance* GI = GetGameInstance()) if (const UJamEventBus* Bus = GI->GetSubsystem<UJamEventBus>()) Frame = Bus->GetSimFrame();
			UE_LOG(LogJamSim, Log, TEXT("JAMAIM frame=%lld raw=%.1f sent=%.1f d=%.1f side=%d reach=%.2f"), Frame, AimDeg, SentAimDeg, SentAimDeg - Prev, AimSide, SentReachM);
		}
		IJamSkaterVisual::Execute_SetStickAim(V, SentAimDeg, SentReachM);
	}
	{
		const int32 Max = 30;   // the visual gets 0..1; the sim's charge_frames_max is applied by LastShotCharge on release
		const float Charge = S.ChargeFrames > 0 ? FMath::Clamp(static_cast<float>(S.ChargeFrames) / static_cast<float>(Max), 0.f, 1.f) : 0.f;
		// Lane A65 (PROFILING.md offender 8): sent only when it changed (it was sent every frame, one Blueprint event per skater per frame for a value
		// that is 0 most of the match). SetupVisual sets LastCharge to -1 so a new or respawned visual gets the first value.
		if (Charge != LastCharge)
		{
			LastCharge = Charge;
			IJamSkaterVisual::Execute_SetShotCharge(V, Charge);
		}
	}
	if (S.PokeResult != 0) IJamSkaterVisual::Execute_PlayPoke(V, S.PokeResult > 0);
	if (S.bLiftThisFrame && !WhiffTakeKeeps(WhiffTakeOn(), SimFrameForLog(), WhiffTakeUntil)) IJamSkaterVisual::Execute_PlayLift(V);   // lane A224: not over the whiff take
	if (S.bPassThisFrame) IJamSkaterVisual::Execute_PlayPass(V, S.LastPassStrength);
	if (S.bAtFaceoff != bWasAtFaceoff)
	{
		bWasAtFaceoff = S.bAtFaceoff;
		IJamSkaterVisual::Execute_SetFaceoff(V, bWasAtFaceoff);
	}
	if (S.DrawResult != 0) IJamSkaterVisual::Execute_PlayFaceoffDraw(V, S.DrawResult > 0);
	if (S.bFoulThisFrame) IJamSkaterVisual::Execute_PlayFoulReaction(V);
}

static TAutoConsoleVariable<float> CVarJamPuckCarryReach(TEXT("jam.puck.CarryReach"), 1.6f,
	TEXT("The reach sent to the figure of the human while he carries, metres (lane A210, the last wave): 1.6 (default): the blade socket stands 1.62 to 1.64 m from his centre, outside the double ring of the HUD (1.1 m and 1.375 m): the carried puck clear of the ring in 12 of 12 straight-carrying stills of drill 21 (2 of 12 at the reach of the sim, where the socket is 1.22 to 1.26 m out and under the outer band; half under it in 6 of 12 at 1.45; the figure cannot bring it nearer than 1.05 m). The price: the drawn puck 85 to 98 cm from the puck of the sim on his carry frames (70 to 92 before). 0 = the reach of the sim (PUCK READY 2). Presentation only: the blade and the puck of the sim are not touched."), ECVF_Default);
float JamCarryReachM() { return FMath::Clamp(CVarJamPuckCarryReach.GetValueOnGameThread(), 0.f, 2.f); }
static TAutoConsoleVariable<float> CVarJamPuckCarryAimFore(TEXT("jam.puck.CarryAimFore"), 45.f,
	TEXT("The human's carried stick on the figure: the floor on the forehand (his left), in degrees (lane A210: 30 put the figure's puck socket only 48 cm out, 45 put it 70). 0 = no floor on that side."), ECVF_Default);
static TAutoConsoleVariable<float> CVarJamPuckCarryAim(TEXT("jam.puck.CarryAim"), 30.f,
	TEXT("The human's carried stick on the figure (lane A210): never closer than this many degrees to his line, so the stick and the puck show past his hips at his camera (a puck carried dead ahead is hidden behind him). The sim's blade and puck are untouched. 30 (default); 0 = off (package H34)."), ECVF_Default);

float AJamSkater::CarryAimFloorDeg() { return FMath::Clamp(CVarJamPuckCarryAim.GetValueOnGameThread(), 0.f, 60.f); }
float AJamSkater::CarryAimForeFloorDeg() { return FMath::Clamp(CVarJamPuckCarryAimFore.GetValueOnGameThread(), 0.f, 70.f); }

float AJamSkater::CarryAimDeg(float RawRelDeg, float PrevSentDeg, bool bCarrying, float FloorBackDeg, float FloorForeDeg, int32 PuckSide)
{
	const float Raw = FMath::UnwindDegrees(RawRelDeg);
	const float Fore = FMath::Max(FloorForeDeg, 0.f), Back = FMath::Max(FloorBackDeg, 0.f);
	if (!bCarrying || (Fore <= 0.f && Back <= 0.f)) return RawRelDeg;
	if (Raw >= Fore || Raw <= -Back || FMath::Abs(Raw) > 90.f) return RawRelDeg;
	// Inside the floors: the side the sim's puck is on; not known: the side the stick is on, until the raw aim is past 0.4 of the other floor.
	const bool bBackhand = PuckSide < 0 ? true : PuckSide > 0 ? false : PrevSentDeg < -1.f ? Raw < 0.4f * Fore : PrevSentDeg > 1.f ? Raw < -0.4f * Back : Raw < 0.f;
	return bBackhand ? -Back : Fore;
}

float AJamSkater::SmoothAimDeg(float RawRelDeg, float Prev, int32& Side, bool& bInit)
{
	const float Raw = FMath::UnwindDegrees(RawRelDeg);
	// The side changes only through the front: within 90 degrees of the facing the raw sign rules (with a 2 degree band that keeps the last side, so a
	// blade held straight ahead does not flap); behind, the stick stays on the side it was on, at the clamp.
	if (FMath::Abs(Raw) <= 90.f)
	{
		if (FMath::Abs(Raw) > 2.f) Side = Raw > 0.f ? 1 : -1;
	}
	if (Side == 0) Side = 1;
	const float Target = FMath::Abs(Raw) <= 90.f ? FMath::Clamp(Raw, -AimClampDeg, AimClampDeg) : (float)Side * AimClampDeg;
	if (!bInit)
	{
		bInit = true;
		return Target;
	}
	// A 6-frame approach (35 % of the gap per frame: within 10 % after 6 frames), never more than AimSlewDegPerFrame in one frame.
	const float Gap = Target - Prev;
	const float Step = FMath::Clamp(Gap * 0.35f, -AimSlewDegPerFrame, AimSlewDegPerFrame);
	return FMath::Abs(Gap) < 0.05f ? Target : Prev + Step;
}

// Lane A210 (wave 4): the one search both readers use (GetPuckSocketWorld, and the puck's follow after the animation).
USceneComponent* AJamSkater::FindPuckSocket(bool& bOutIsSocket) const
{
	bOutIsSocket = false;
	if (!VisualObject) return nullptr;
	TArray<USceneComponent*> Candidates;
	if (USceneComponent* SC = Cast<USceneComponent>(VisualObject))
	{
		Candidates.Add(SC);
		SC->GetChildrenComponents(true, Candidates);
	}
	else if (AActor* A = Cast<AActor>(VisualObject))
	{
		A->GetComponents<USceneComponent>(Candidates);
	}
	// A mesh socket first (B's figures), then a scene component named puck_socket (the toy figure).
	for (USceneComponent* C : Candidates) if (C && C->DoesSocketExist(JamSkaterSockets::Puck)) { bOutIsSocket = true; return C; }
	for (USceneComponent* C : Candidates) if (C && C->GetFName() == JamSkaterSockets::Puck) return C;
	return nullptr;
}

bool AJamSkater::GetPuckSocketWorld(FVector& Out) const
{
	bool bIsSocket = false;
	const USceneComponent* C = FindPuckSocket(bIsSocket);
	if (!C) return false;
	Out = bIsSocket ? C->GetSocketLocation(JamSkaterSockets::Puck) : C->GetComponentLocation();
	return true;
}

TFunction<bool(const AJamSkater&, FVector&, FRotator&)> AJamSkater::BoxSeat;   // lane A127 (track F3): set by ARinkActor

void AJamSkater::ApplyRender(const FJamSkaterState& S, float Alpha)
{
	FVector Loc = Lerp2D(S.PrevPos, S.Pos, Alpha, 0.0);
	const double DYaw = FMath::UnwindRadians(S.Yaw - S.PrevYaw);
	const double Yaw = S.PrevYaw + DYaw * Alpha + FMath::DegreesToRadians(S.SpinVisualYawDeg());   // lane A51 (R-0034): the spin's turn of the figure
	FRotator Rot(0.0, FMath::RadiansToDegrees(Yaw), 0.0);
	if (S.InBox() && BoxSeat) BoxSeat(*this, Loc, Rot);   // lane A127 (track F3): a boxed skater's figure stands in its penalty box (presentation only; the sim keeps BoxPos)
	// Lane A73: held = the hit frame's pose; catching up = a blend from it to the live pose over HoldTotal frames (w runs 0 -> 1, Alpha inside each frame).
	if (HoldLeft > 0)
	{
		SetActorLocationAndRotation(HeldLoc, HeldRot);
		return;
	}
	if (CatchUpLeft > 0 && HoldTotal > 0)
	{
		const float W = FMath::Clamp((static_cast<float>(HoldTotal - CatchUpLeft) + Alpha) / static_cast<float>(HoldTotal), 0.f, 1.f);
		SetActorLocationAndRotation(FMath::Lerp(HeldLoc, Loc, W), FQuat::Slerp(HeldRot.Quaternion(), Rot.Quaternion(), W).Rotator());
		return;
	}
	SetActorLocationAndRotation(Loc, Rot);
}

// ---------- AJamPuck ----------

AJamPuck::AJamPuck()
{
	// Lane A210 (wave 4): the puck ticks after the frame's animation, only to follow the carrier's blade (SetFollow); with no follow the tick does nothing.
	PrimaryActorTick.bCanEverTick = true;
	PrimaryActorTick.bStartWithTickEnabled = true;
	PrimaryActorTick.TickGroup = TG_PostUpdateWork;
	Mesh = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("Mesh"));
	RootComponent = Mesh;
	Mesh->SetMobility(EComponentMobility::Movable);
	Mesh->SetCollisionEnabled(ECollisionEnabled::NoCollision);
	static ConstructorHelpers::FObjectFinder<UStaticMesh> Cyl(TEXT("/Engine/BasicShapes/Cylinder.Cylinder"));
	if (Cyl.Succeeded()) Mesh->SetStaticMesh(Cyl.Object);
	// R-0002: the puck is outline-only in the painted-cel look (stencil 3).
	Mesh->SetRenderCustomDepth(true);
	Mesh->SetCustomDepthStencilValue(3);
}

void AJamPuck::InitPuck(double RadiusM, const FLinearColor& Colour)
{
	// Basic cylinder: 100 cm across, 100 cm tall. Puck: 2r across, 0.08 m tall.
	HalfHeightM = 0.04;
	Mesh->SetRelativeScale3D(FVector(RadiusM * 2.0, RadiusM * 2.0, 0.08));
	if (UMaterialInterface* Look = LoadObject<UMaterialInterface>(nullptr, TEXT("/JamAssets/Look/MI_Toon_Puck.MI_Toon_Puck"), nullptr, LOAD_NoWarn | LOAD_Quiet))
	{
		Mesh->SetMaterial(0, Look); // R-0002: device B's instance when it exists
	}
	else if (UMaterialInterface* Base = LoadObject<UMaterialInterface>(nullptr, TEXT("/Engine/BasicShapes/BasicShapeMaterial.BasicShapeMaterial")))
	{
		UMaterialInstanceDynamic* Mid = UMaterialInstanceDynamic::Create(Base, this);
		Mid->SetVectorParameterValue(TEXT("Color"), Colour);
		Mesh->SetMaterial(0, Mid);
	}

	// R-0016 (B-to-A-0007): the puck kit. SM_PuckDisc under the puck, on the ice: no shadow, no dynamic indirect, stencil 0, no collision.
	// The puck mesh is a unit cylinder scaled to 2r x 2r x 0.08 m and centred 4 cm up, so parent-local z = -0.5 is the ice; the disc keeps its own scale.
	if (!Disc)
	{
		if (UStaticMesh* DiscMesh = LoadObject<UStaticMesh>(nullptr, TEXT("/JamAssets/Props/SM_PuckDisc.SM_PuckDisc"), nullptr, LOAD_NoWarn | LOAD_Quiet))
		{
			Disc = NewObject<UStaticMeshComponent>(this, TEXT("PuckDisc"));
			Disc->SetStaticMesh(DiscMesh);
			Disc->SetCollisionEnabled(ECollisionEnabled::NoCollision);
			Disc->SetGenerateOverlapEvents(false);
			Disc->CastShadow = false;
			Disc->bAffectDynamicIndirectLighting = false;
			Disc->SetRenderCustomDepth(false);
			Disc->SetCustomDepthStencilValue(0);
			Disc->SetUsingAbsoluteScale(true);
			Disc->SetupAttachment(Mesh);
			Disc->SetRelativeLocation(FVector(0.0, 0.0, -0.45));
			Disc->SetWorldScale3D(FVector::OneVector);
			Disc->RegisterComponent();
		}
		else
		{
			UE_LOG(LogJamSim, Log, TEXT("JAMPUCK /JamAssets/Props/SM_PuckDisc not found; the puck has no disc"));
		}
	}
	if (!Trail)
	{
		if (UNiagaraSystem* Sys = LoadObject<UNiagaraSystem>(nullptr, TEXT("/JamAssets/VFX/NS_puck_trail.NS_puck_trail"), nullptr, LOAD_NoWarn | LOAD_Quiet))
		{
			Trail = UNiagaraFunctionLibrary::SpawnSystemAttached(Sys, Mesh, NAME_None, FVector(0.0, 0.0, -0.5), FRotator::ZeroRotator, EAttachLocation::KeepRelativeOffset, false);
			if (Trail) { Trail->SetUsingAbsoluteScale(true); Trail->SetWorldScale3D(FVector::OneVector); }
		}
		else
		{
			UE_LOG(LogJamSim, Log, TEXT("JAMPUCK /JamAssets/VFX/NS_puck_trail not found; the puck has no trail"));
		}
	}
}

double AJamPuck::RenderHeightM(const FJamPuckState& P, float Alpha, double HalfHeight)
{
	// R-0035 (lane A52): the sim's height, interpolated between the previous and the current frame like the position; never below the ice.
	const double A = FMath::Clamp(static_cast<double>(Alpha), 0.0, 1.0);
	return HalfHeight + FMath::Max(0.0, P.PrevZ + (P.Z - P.PrevZ) * A);
}

void AJamPuck::ApplyRender(const FJamPuckState& P, float Alpha)
{
	// R-0035 (lane A52): the puck is drawn where the sim says, height included; the disc (the shadow) stays on the ice under it.
	Place(Lerp2D(P.PrevPos, P.Pos, Alpha, RenderHeightM(P, Alpha, HalfHeightM)), Alpha);
}

void AJamPuck::ApplyRenderAt(const FVector& WorldCm)
{
	Place(FVector(WorldCm.X, WorldCm.Y, HalfHeightM * 100.0), 1.f);
}

// Lane A210 (wave 4): see JamPawns.h.
FVector AJamPuck::LiveRenderCm(const FJamPuckState& P, float Alpha) const
{
	return Lerp2D(P.PrevPos, P.Pos, Alpha, RenderHeightM(P, Alpha, HalfHeightM));
}

void AJamPuck::ApplyRenderBlend(const FVector& WorldCm, float Alpha)
{
	Place(WorldCm, Alpha);
}

void AJamPuck::SetFollow(USceneComponent* Comp, bool bIsSocket, bool bCorrect, const FVector& AnchorCm, double MaxOffCm)
{
	FollowComp = Comp;
	bFollowIsSocket = bIsSocket;
	bFollowCorrect = bCorrect;
	FollowAnchor = AnchorCm;
	FollowMaxOffCm = MaxOffCm;
	if (!Comp) LastLagCm = -1.0;
}

void AJamPuck::Tick(float DeltaSeconds)
{
	Super::Tick(DeltaSeconds);
	const USceneComponent* C = FollowComp.Get();
	if (!C || HoldLeft > 0 || CatchUpLeft > 0) { LastLagCm = -1.0; return; }   // no follow, or the hit-stop holds the puck where the hit was
	const FVector Socket = bFollowIsSocket ? C->GetSocketLocation(JamSkaterSockets::Puck) : C->GetComponentLocation();
	LastLagCm = FVector::Dist2D(Socket, GetActorLocation());
	if (!bFollowCorrect) return;
	FVector Loc(Socket.X, Socket.Y, HalfHeightM * 100.0);
	if (FollowMaxOffCm > 0.0)   // no further than MaxOffCm from where the sim has it
	{
		const FVector2D Off(Socket.X - FollowAnchor.X, Socket.Y - FollowAnchor.Y);
		const FVector2D Capped = Off.GetClampedToMaxSize(FollowMaxOffCm);
		Loc.X = FollowAnchor.X + Capped.X; Loc.Y = FollowAnchor.Y + Capped.Y;
	}
	LastPlaced = Loc;
	SetActorLocation(Loc);
	PlaceDiscOnIce(Loc);
}

void AJamPuck::SetTrailCarried(bool bCarried)
{
	if (Trail) Trail->SetVariableFloat(FName(TEXT("User.Carried")), bCarried ? 1.f : 0.f);
}

void AJamPuck::BeginHitStop(int32 Frames)
{
	// Lane A73: hold where the puck was last drawn. Called on the hit frame before that frame's StepSimFrame, which counts one down.
	if (Frames <= 0) return;
	HoldTotal = FMath::Clamp(Frames, 1, 6);
	HoldLeft = HoldTotal + 1;
	CatchUpLeft = 0;
	HeldLoc = bEverPlaced ? LastPlaced : GetActorLocation();
	CustomTimeDilation = 0.0001f;
}

void AJamPuck::StepSimFrame()
{
	if (HoldLeft > 0)
	{
		if (--HoldLeft == 0) { CustomTimeDilation = 1.f; CatchUpLeft = HoldTotal; }
	}
	else if (CatchUpLeft > 0) --CatchUpLeft;
}

void AJamPuck::Place(const FVector& LiveCm, float Alpha)
{
	FVector Loc = LiveCm;
	if (HoldLeft > 0) Loc = HeldLoc;
	else if (CatchUpLeft > 0 && HoldTotal > 0)
	{
		const float W = FMath::Clamp((static_cast<float>(HoldTotal - CatchUpLeft) + Alpha) / static_cast<float>(HoldTotal), 0.f, 1.f);
		Loc = FMath::Lerp(HeldLoc, LiveCm, W);
	}
	LastPlaced = Loc;
	bEverPlaced = true;
	SetActorLocation(Loc);
	PlaceDiscOnIce(Loc);
}

void AJamPuck::PlaceDiscOnIce(const FVector& PuckCm)
{
	// The disc is attached under the puck mesh (parent-local z -0.45 of a 0.08 m tall unit cylinder = 3.6 cm under the centre, 0.4 cm over the ice when the
	// puck sits on it); with the puck in the air it is placed in world space at the same 0.4 cm over the ice.
	if (!Disc) return;
	Disc->SetWorldLocation(FVector(PuckCm.X, PuckCm.Y, (HalfHeightM - 0.45 * 0.08) * 100.0));
	// Lane A188: the disc at its own scale (B's mesh without the marker); one JAMPUCK line the first time it is placed.
	static bool bDiscLogged = false;   // once per process
	if (!bDiscLogged)
	{
		bDiscLogged = true;
		UE_LOG(LogJamSim, Log, TEXT("JAMPUCK disc scale=(%.2f,%.2f,%.2f) half_extent_cm=(%.1f,%.1f,%.1f) (lane A188: no flattening)"), Disc->GetComponentScale().X, Disc->GetComponentScale().Y,
			Disc->GetComponentScale().Z, Disc->Bounds.BoxExtent.X, Disc->Bounds.BoxExtent.Y, Disc->Bounds.BoxExtent.Z);
	}
}
