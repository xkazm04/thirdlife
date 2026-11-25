// Lane A2: see JamSimAdapter.h.
#include "JamSimAdapter.h"

#include "JamEventBus.h"
#include "JamSim.h"
#include "JamEffectSystem.h"
#include "JamRuleSystem.h"
#include "JamZones.h"
#include "JamPassFate.h"   // lane T5

#include <cstdlib>
#include <cstring>

namespace JamAI
{
	namespace SimAdapterLocal
	{
		ERole RoleOf(const FName& R)
		{
			static const FName Player(TEXT("player")), Support(TEXT("support")), Back(TEXT("back"));
			if (R == Player) { return ERole::Player; }
			if (R == Support) { return ERole::Support; }
			if (R == Back) { return ERole::Back; }
			return ERole::Chaser;
		}
		FVec2 V(const FVector2D& P) { return FVec2(P.X, P.Y); }
	}
	using namespace SimAdapterLocal;

	FJamMatchConfig ToMatchConfig(const FJamGameConfig& G)
	{
		FJamMatchConfig C;
		C.LengthM = G.Rink.LengthM;
		C.WidthM = G.Rink.WidthM;
		C.CornerRadiusM = G.Rink.CornerRadiusM;
		C.BoardRestitution = G.Rink.BoardRestitution;
		C.IceFriction = G.Rink.IceFriction;
		C.GoalWidthM = G.Rink.GoalWidthM;
		C.Speed = G.Skater.Speed;
		C.Accel = G.Skater.Accel;
		C.FreeSpeedMult = G.Skater.FreeSpeedMult;   // lane A193: the brain's planning (Params.FreeSpeedMult); the reference sim does not read it
		C.TurnRate = G.Skater.TurnRate;
		C.LateralGrip = G.Skater.LateralGrip;
		C.BrakeDecel = G.Skater.BrakeDecel;
		C.PuckRadiusM = G.Puck.RadiusM;
		C.PuckMaxSpeed = G.Puck.MaxSpeed;
		C.PuckDrag = G.Puck.Drag;
		C.ShotReachM = G.Shot.ReachM;
		C.ShotSpeed = G.Shot.Speed;
		C.AimConeDeg = G.Shot.bHasAimCone ? G.Shot.AimConeDeg : 0.0;
		C.ShotCooldownFrames = G.Shot.CooldownFrames;
		C.bTimer = G.Rules.Mode == FName(TEXT("timer"));
		C.ScoreToWin = G.Rules.ScoreToWin;
		C.TimerFrames = G.Rules.TimerFrames;
		C.GoalPauseFrames = G.Rules.GoalPauseFrames;
		C.AI.YieldMarginM = G.Ai.YieldMarginM;
		C.AI.YieldRadiusM = G.Ai.YieldRadiusM;
		C.AI.HoldRadiusM = G.Ai.HoldRadiusM;
		C.AI.SpeedScale = G.Ai.SpeedScale;
		C.AI.RedSkill = G.Ai.RedSkill;
		C.NumSkaters = 0;
		for (int32 T = 0; T < G.Teams.Num() && T < 2; ++T)
		{
			for (const FJamSkaterSpawn& Sp : G.Teams[T].Skaters)
			{
				if (C.NumSkaters < kMaxSkaters)
				{
					FJamMatchSkaterCfg& S = C.Skaters[C.NumSkaters++];
					S.Team = T;
					S.Role = RoleOf(Sp.Role);
					S.Spawn = FVec2(Sp.X, Sp.Z);
				}
			}
		}
		return C;
	}

	// ---- lane A41: the game mode's systems as one bundle ----

	void FJamSystems::BuildBeforeInit(UJamSim& Sim, const FJamGameConfig& G, IJamRuleHook* Hook)
	{
		Release();
		// Lane A15 (C-0005 seam B): the only IJamRuleHook, set before Init so the opening faceoff reaches it.
		Rules.Reset(NewObject<UJamRuleSystem>());
		Rules->Init(G);
		Sim.SetRuleHook(Hook);
		// R-0019: the sim reads ice factors, no_shoot and bumper zones from the zone system.
		Zones.Reset(NewObject<UJamZoneSystem>());
		Zones->Init(G);
		Sim.SetZoneSource(Zones.Get());
		EndMatchActions = EndPeriodActions = 0;
	}

	void FJamSystems::BuildAfterInit(UJamSim& Sim, const FString& RawCartridgeJson)
	{
		// Lane A14 (C-0005): the effect system binds itself as the sim's modifier source and owns the pickups.
		Effects.Reset(NewObject<UJamEffectSystem>());
		EffectErrors.Reset();
		Effects->Init(&Sim, RawCartridgeJson, EffectErrors);
	}

	void FJamSystems::BeforeStep(const UJamSim& Sim)
	{
		if (!Rules.IsValid()) { return; }
		Rules->SetScore(0, Sim.GetScore(0));
		Rules->SetScore(1, Sim.GetScore(1));
	}

	void FJamSystems::AfterStep(const UJamSim& Sim)
	{
		if (Zones.IsValid()) { Zones->Update(Sim.GetFrame(), Sim.GetSkaters(), Sim.GetPuck()); }   // membership and zone events for this frame
		if (Effects.IsValid()) { Effects->Step(); }   // after the sim's frame and the zone update (its zone triggers read that list)
	}

	void FJamSystems::View(FJamAIWorld& W) const
	{
		if (!Zones.IsValid()) { return; }
		// lane A3 (R-0019): slow-ice circles (rects by half diagonal) and who stands in a no_shoot zone, as AHokejGameMode::GatherInputs adds them.
		W.NumSlowIce = 0;
		static const FName SlowIce(TEXT("slow_ice")), Rect(TEXT("rect"));
		for (const FJamZoneConfig& Z : Zones->GetZones())
		{
			if (Z.Kind != SlowIce || W.NumSlowIce >= FJamAIWorld::kMaxSlowIce) { continue; }
			W.SlowIceCentre[W.NumSlowIce] = FVec2(Z.X, Z.Z);
			W.SlowIceRadius[W.NumSlowIce] = Z.Shape == Rect ? 0.5 * FMath::Sqrt(Z.W * Z.W + Z.D * Z.D) : Z.R;
			++W.NumSlowIce;
		}
		for (int32 i = 0; i < W.NumSkaters; ++i)
		{
			FName ZoneId;
			W.Skaters[i].bNoShoot = Zones->BlocksShot(FVector2D(W.Skaters[i].Pos.X, W.Skaters[i].Pos.Y), ZoneId);
		}
	}

	void FJamSystems::OnRuleEvent(const FJamRuleEventIn& In, TArray<FJamRuleActionOut>& Out)
	{
		if (!Rules.IsValid()) { return; }
		const int32 Before = Out.Num();
		Rules->OnRuleEvent(In, Out);
		for (int32 i = Before; i < Out.Num(); ++i)
		{
			if (Out[i].Action == EJamRuleAction::EndMatch) { ++EndMatchActions; }
			else if (Out[i].Action == EJamRuleAction::EndPeriod) { ++EndPeriodActions; }
		}
	}

	uint64 FJamSystems::StateHash() const
	{
		if (!IsBuilt()) { return 0; }
		uint64 H = 14695981039346656037ull;
		const uint64 Parts[3] = { Rules->StateHash(), Zones->StateHash(), Effects->StateHash() };
		for (const uint64 V : Parts)
		{
			for (int32 i = 0; i < 8; ++i) { H ^= (V >> (i * 8)) & 0xFF; H *= 1099511628211ull; }
		}
		return H;
	}

	void FJamSystems::Release()
	{
		Effects.Reset();
		Zones.Reset();
		Rules.Reset();
		EffectErrors.Reset();
	}

	// ---- the adapter ----

	FJamSimAdapter::FJamSimAdapter(const FJamGameConfig& InGame)
		: Game(InGame)
	{
		Sim.Reset(NewObject<UJamSim>());
	}

	FJamSimAdapter::FJamSimAdapter(const UJamCartridge& Cart)
		: Game(Cart.Game), RawJson(Cart.RawJson), bWithSystems(true)
	{
		Sim.Reset(NewObject<UJamSim>());
	}

	FJamSimAdapter::~FJamSimAdapter()
	{
		// The sim keeps raw pointers to the hook, the zone source and the modifier source: clear them before the systems go.
		if (Sim.IsValid())
		{
			Sim->SetRuleHook(nullptr);
			Sim->SetZoneSource(nullptr);
			Sim->SetModifierSource(nullptr);
		}
		Systems.Release();
	}

	void FJamSimAdapter::Reset(const FJamMatchConfig& C, uint64_t Seed)
	{
		(void)C;   // the sim reads the full cartridge config; C is the runner's view of the same cartridge
		if (bWithSystems) { Systems.BuildBeforeInit(*Sim, Game, this); }
		Sim->Init(Game, Seed);
		if (bWithSystems) { Systems.BuildAfterInit(*Sim, RawJson); }
		if (PassFate) { PassFate->ResetMatch(); }   // lane T5: a new match, no pass in flight
	}

	void FJamSimAdapter::OnRuleEvent(const FJamRuleEventIn& In, TArray<FJamRuleActionOut>& Out)
	{
		Systems.OnRuleEvent(In, Out);
	}

	void FJamSimAdapter::BuildWorld(const UJamSim& S, FJamAIWorld& W)
	{
		const FJamGameConfig& G = S.GetConfig();
		W.Frame = S.GetFrame();
		W.bFrozen = S.GetPhase() != EJamSimPhase::Playing;
		W.PuckPos = V(S.GetPuck().Pos);
		W.PuckVel = V(S.GetPuck().Vel);
		W.PuckLastTouch = S.GetPuck().LastTouch;
		W.PuckPassFrames = S.GetPuck().PassFrames; W.PuckPassBy = S.GetPuck().PassBy;   // lane A206 (evolution 9, wave 2): A207's pass in flight, read by the brain
		W.PuckPassTo = S.GetPuck().PassTo;   // lane A206 (READY 5): the man the pass in flight is aimed at
		const TArray<FJamSkaterState>& Sk = S.GetSkaters();
		W.NumSkaters = FMath::Min(Sk.Num(), kMaxSkaters);
		W.PlayerIndex = S.GetHumanIndex();
		// Lane A129 (track Q1): a seated guest (UJamSim::SeatGuest, online only) is the brain's second human.
		W.GuestIndex = -1;
		for (const FJamSkaterState& K : S.GetSkaters()) if (K.bHuman && K.Index != W.PlayerIndex && K.Index < kMaxSkaters) { W.GuestIndex = K.Index; break; }
		W.HalfLength = G.Rink.LengthM * 0.5;
		W.HalfWidth = G.Rink.WidthM * 0.5;
		W.CornerRadius = G.Rink.CornerRadiusM;
		W.GoalX = S.GoalLineX();
		W.GoalHalfWidth = G.Rink.GoalWidthM * 0.5;
		W.ShotReach = G.Shot.ReachM;
		// R-0035 (lane A52): the net's height and the lift rule for the shooter's charge choice
		W.GoalHeightM = G.Rink.GoalHeightM;
		W.LiftTapM = G.Shot.LiftTapM;
		W.LiftHalfM = G.Shot.LiftHalfM;
		W.LiftFullM = G.Shot.LiftFullM;
		W.LiftHalfFrames = G.Shot.LiftHalfFrames;
		W.SaucerHalfFrames = G.Pass.SaucerHalfFrames;   // lane A77 (R-0036)
		W.ChargeFramesMax = G.Shot.ChargeFramesMax;
		W.bDrawOpen = S.IsDrawOpen();
		// R-0017: the pickups on the ice, from the sim's effect system (lane A14's UJamEffectSystem is the only IJamModifierSource
		// and binds itself with SetModifierSource), so every caller of BuildWorld sees them: game mode, tests, tournaments
		W.NumPickups = 0;
		if (const IJamModifierSource* Src = S.GetModifierSource())
		{
			const UJamEffectSystem* Fx = static_cast<const UJamEffectSystem*>(Src);
			if (Fx->GetSim() == &S)
			{
				for (const FJamPickupOnIce& P : Fx->GetPickups())
				{
					if (W.NumPickups >= FJamAIWorld::kMaxPickups) { break; }
					W.PickupKind[W.NumPickups] = P.PickupIndex;
					W.PickupPos[W.NumPickups] = FVec2(P.Pos.X, P.Pos.Y);
					++W.NumPickups;
				}
			}
		}
		W.bFaceoffPhase = S.GetPhase() == EJamSimPhase::Faceoff;
		W.FaceoffCountdown = S.GetFaceoffCountdown();
		// R-0017: stick facts and the carrier
		{
			// the same rule as UJamSim::CarrierIndex (private): the last toucher, able to act, with the puck within the carrier reach
			const int32 Lt = S.GetPuck().LastTouch;
			const TArray<FJamSkaterState>& All = S.GetSkaters();
			// Lane A86 (R-0042 point 1, R-0043 point 2): the brain sees the carrier at UJamSim::CarrierReachM, the sim's own rule. On shot.reach_m (A85 left it there) a human
			// who carries at the mouse's reach (0.4 + stick.reach_m = 1.6 m) was a loose puck to every bot: the rookie bots, which never poke a carrier, pounced on it
			// (the novice playtester with the mouse's stick: 56 % at rookie, 97 % with this rule; CURVE-4.md section 1). A66's cap on the bots' own blade stays (R-0044).
			// JAM_BRAIN_CARRIER=shot replays the old view (measurement only).
			static const bool bA86ShotReach = [] { const char* E = std::getenv("JAM_BRAIN_CARRIER"); return E && std::strcmp(E, "shot") == 0; }();
			const double BrainReach = (!bA86ShotReach && All.IsValidIndex(Lt)) ? S.CarrierReachM(Lt) : G.Shot.ReachM;
			W.Carrier = (All.IsValidIndex(Lt) && All[Lt].CanAct() && FVector2D::Distance(All[Lt].Pos, S.GetPuck().Pos) <= BrainReach) ? Lt : -1;
			// lane A46: whom the sim's pass would go to from the carrier right now (the brain passes to the human only when it is this teammate)
			W.CarrierBestPass = -1;
			if (W.Carrier >= 0) { FVector2D Aim; W.CarrierBestPass = S.BestPass(W.Carrier, Aim); }
			W.CarrierBestSaucer = -1;   // lane A77 (R-0036): whom a saucer would go to (a blade in the lane allowed)
			if (W.Carrier >= 0) { FVector2D Aim; W.CarrierBestSaucer = S.BestPass(W.Carrier, Aim, true); }
			// lane A94 (R-0045 law 2): the holder at the sim's own carrier reach (UJamSim::CarrierIndex: the blade's full length) and its best pass. Only the
			// hockey sense reads these (W.Carrier stays on shot.reach_m for every older decision, A85's note above).
			W.Holder = S.CarrierIndex();
			W.HolderBestPass = -1;
			if (W.Holder >= 0) { FVector2D Aim; W.HolderBestPass = S.BestPass(W.Holder, Aim); }
		}
		// Lane T5 (T5.b, pool P12): the loose puck's own path, once a frame for every bot (read only with FJamAIParams::PuckRead).
		W.NumPuckPath = 0;
		if (W.Holder < 0 && W.Carrier < 0 && S.GetPuck().Vel.SizeSquared() < 1e-4 && S.GetPuck().Z <= 0.0 && S.GetPuck().VZ == 0.0)
		{
			for (int32 k = 0; k < FJamAIWorld::kPuckPathN; ++k) { W.PuckPath[k] = W.PuckPos; }   // a still puck stays where it lies (no integration)
			W.NumPuckPath = FJamAIWorld::kPuckPathN;
		}
		else if (W.Holder < 0 && W.Carrier < 0)
		{
			FVector2D Path[FJamAIWorld::kPuckPathN];
			const int32 Np = S.ForecastGroundPuck(6 * (FJamAIWorld::kPuckPathN - 1), 6, Path, FJamAIWorld::kPuckPathN);
			if (Np == FJamAIWorld::kPuckPathN) { for (int32 k = 0; k < Np; ++k) { W.PuckPath[k] = V(Path[k]); } W.NumPuckPath = Np; }
		}
		// Lane T5 (T5.c): the human's hold: the mate his release would pick now (the power meter's own call, UJamSim::HumanPassTarget).
		W.PlayerLookTo = -1; W.PlayerLookAt = FVec2(); W.PlayerLookFrames = 0; W.bPlayerLookSolved = false;
		if (Sk.IsValidIndex(W.PlayerIndex) && Sk[W.PlayerIndex].PassChargeFrames > 0 && W.CarrierOrHolder() == W.PlayerIndex)
		{
			const FJamSkaterState& Hu = Sk[W.PlayerIndex];
			FVector2D Aim;
			W.PlayerLookTo = S.HumanPassTarget(Hu.Index, Hu.BladePos - Hu.Pos, Hu.PassChargeFrames, Aim);
			W.PlayerLookAt = V(Aim);
			W.PlayerLookFrames = Hu.PassChargeFrames;
			if (W.PlayerLookTo >= 0) { FVector2D A2; double V2 = 0, Ar2 = 0, Tf2 = 0; W.bPlayerLookSolved = S.AimPassAt(Hu.Index, W.PlayerLookTo, -1.0, A2, V2, Ar2, Tf2); }
		}
		W.SkaterRadius = UJamSim::SkaterRadius;
		W.StickReach = G.Stick.ReachM;
		W.LiftRange = G.Stick.LiftRangeM;
		W.LiftConeDeg = G.Stick.LiftConeDeg;   // lane A95 (B-to-A-0037)
		W.CheckWindupFrames = G.Contact.CheckWindupFrames;   // lane A184
		W.CrossWindupFrames = G.Contact.CrossWindupFrames;
		W.BotCheckWindupFrames = G.Contact.CheckWindupFor(false);   // lane A200: the bots' own (absent = the shared value)
		W.BotCrossWindupFrames = G.Contact.CrossWindupFor(false);
		W.ReverseBrakeDecel = G.Skater.ReverseBrakeDecel;   // lane A95: the movement verbs the playtester uses only when they exist
		W.BurstFrames = G.Skater.BurstFrames;
		W.SprintCarryBonus = G.Skater.SprintCarryBonus;
		W.SweepBotReactFrames = G.Stick.SweepBotReactFrames;   // lane A51
		// HOOK (lane A115 for track F2, lane A102): once game.stick.body_shield is in this tree, uncomment these two lines: the brain then reads the shield
		// (JamAI::BodyShields in JamAICore.cpp: no lift or poke into a shielding body, the bot goes round it). Until then W.bBodyShield stays false.
		W.bBodyShield = G.Stick.bBodyShield;   // wired at landing (Director): the rule is on main
		W.bShieldShove = G.Contact.bShieldShove && G.Contact.bMomentum && G.Contact.ThrustMps > 0.0 && G.Skater.bCheckEnabled;   // lane A138 (R-0053 point 3): the shove under a stick-only shield exists
		W.SpinExposedFrames = G.Skater.SpinFrames > 0 ? FMath::Max(0, G.Skater.SpinExposedTail) : 0;   // lane A138: the spin's exposed end (lane A128)
		W.BodyShieldRangeM = UJamSim::BodyShieldRangeM; W.BodyShieldFarDeg = UJamSim::BodyShieldFarDeg; W.BodyShieldFrontDeg = UJamSim::BodyShieldFrontDeg;   // wired at landing (Director): the rule is on main
		// R-0029 point 4 (lane A39): the goalie commit of the latest deke
		{
			int32 Deker = -1, Side = 0;
			W.DekeCommitFrames = S.GetDekeCommit(Deker, Side);
			W.DekeCommitSkater = W.DekeCommitFrames > 0 ? Deker : -1;
			W.DekeCommitOffset = W.DekeCommitFrames > 0 ? FVec2(0.0, Side * S.EffectiveDekeOffsetM()) : FVec2();
		}
		const int64 NextFrame = S.GetFrame() + 1;   // UJamSim::Step increments the frame before shots are tried
		for (int32 i = 0; i < W.NumSkaters; ++i)
		{
			const FJamSkaterState& K = Sk[i];
			FJamAISkater& O = W.Skaters[i];
			O.Pos = V(K.Pos);
			O.Vel = V(K.Vel);
			O.Facing = V(K.Forward());
			O.Blade = V(K.BladePos);   // lane T5 (T5.c)
			O.Spawn = V(K.SpawnPos);
			O.Team = K.Team;
			O.Role = RoleOf(K.Role);
			O.bHasPuck = K.bHasPuck;
			O.bDown = K.IsDown() || K.InBox();   // lane A105: a boxed skater is off the ice for every brain read (pressure, outlets, jobs), like one knocked down
			O.GraceFrames = K.GraceFrames;   // lane A113
			O.CheckWindupLeft = K.CheckWindupLeft;   // lane A200: the hit a person sees coming (the playtester's dodge reads it) and a braking carrier (the brain's lead)
			O.CrossWindupLeft = K.LiftWindupLeft;
			O.CrossTarget = K.LiftWindupLeft > 0 ? K.CrossTarget : -1;
			O.bBraking = K.bBraking;
			// HOOK (lane A115 for track F2, lane A121): once FJamSkaterState::TakeGraceLeft is in this tree, uncomment this line: the brain then presses no poke
			// or lift on a carrier inside its take grace and contains it instead (JamAI::StickCannotTake in JamAICore.cpp). Until then the field stays 0.
			O.TakeGraceFrames = K.TakeGraceLeft;   // wired at landing (Director): the rule is on main
			O.bCentre = K.bCentre;
			O.bCanPoke = K.CanAct() && NextFrame >= K.PokeReadyFrame && K.PokeWindow <= 0;
			O.bCanLift = K.CanAct() && NextFrame >= K.LiftReadyFrame;
			// R-0029 point 4 (lane A39): the payoff windows, as the sim will see them on the next step
			O.OneTimerFrames = (G.Shot.OneTimerWindowFrames > 0 && K.PassReceivedFrame >= 0)
				? FMath::Max(0, static_cast<int32>(G.Shot.OneTimerWindowFrames - (NextFrame - K.PassReceivedFrame) + 1)) : 0;
			O.bBreakaway = K.BreakawayFrames > 0;
			O.DekeFrames = K.DekeFrames;
			const int32 DekeTotal = FMath::Max(UJamSim::DekeMoveFrames, G.Stick.DekeCommitFrames);
			O.bDekeSettled = K.DekeFrames > 0 && (DekeTotal - K.DekeFrames) >= UJamSim::DekeMoveFrames;
			O.bCanDeke = K.CanAct() && G.Stick.DekeOffsetM > 0.0 && G.Stick.DekeCommitFrames > 0 && NextFrame >= K.DekeReadyFrame && K.DekeFrames == 0;
			const FVector2D Off = S.DekeOffset(K);
			O.DekeOffset = FVec2(Off.X, Off.Y);
			// Lane A51 (R-0034): the spin, as the sim will see a tap on the next step (TrySpin's gate; an unset stamina is a full bar)
			O.SpinFrames = K.SpinFrames;
			O.bCanSpin = K.CanAct() && G.Skater.SpinFrames > 0 && NextFrame >= K.SpinReadyFrame && K.SpinFrames == 0 && K.Stamina != 0;
			// the same gate as UJamSim::TryShoot
			const FVector2D To = S.GetPuck().Pos - K.Pos;
			const double D = To.Size();
			O.bCanShoot = !W.bFrozen && !K.IsDown() && NextFrame >= K.ShotReadyFrame && D <= S.CarrierReachM(K.Index)   // R-0042 (lane A85): TryShoot's reach
				&& (D < 0.05 || FVector2D::DotProduct(K.Forward(), To / D) >= UJamSim::ShotFrontDot);
		}
	}

	void FJamSimAdapter::View(FJamAIWorld& W) const
	{
		BuildWorld(*Sim, W);
		W.FramesSinceDrop = (W.bDrawOpen && LastDropFrame >= 0) ? static_cast<int>(W.Frame - LastDropFrame) : -1;
		if (bWithSystems) { Systems.View(W); }   // lane A41: slow-ice circles and no_shoot flags, as the game mode adds them
	}

	FJamAIStepEvents FJamSimAdapter::Step(const FJamAIInput* In)
	{
		FJamAIStepEvents Ev;
		const TArray<FJamSkaterState>& Before = Sim->GetSkaters();
		// A touch is a change of the puck's last toucher (UJamSim's own Touches counts every contact start, which is
		// hundreds per match while dribbling).
		const int32 LastBefore = Sim->GetPuck().LastTouch;
		int32 Shots[kMaxSkaters] = {};
		const int32 N = FMath::Min(Before.Num(), kMaxSkaters);
		for (int32 i = 0; i < N; ++i)
		{
			Shots[i] = Before[i].Shots;
		}
		const int32 S0 = Sim->GetScore(0), S1 = Sim->GetScore(1);
		Inputs.SetNum(N);
		for (int32 i = 0; i < N; ++i)
		{
			FJamInput& I = Inputs[i];
			I.Move = FVector2D(In[i].Move.X, In[i].Move.Y);
			I.bShoot = In[i].bShoot;
			I.bShootHeld = In[i].bShootHeld;   // lane A34: the playtester's charged shot
			I.bCheck = In[i].bCheck;
			I.bBrake = In[i].bBrake;
			I.bPass = In[i].bPass;
			I.bPassHeld = In[i].bPassHeld;   // lane A77 (R-0036): the saucer hold
			I.Stick = FVector2D(In[i].Stick.X, In[i].Stick.Y);
			I.bPoke = In[i].bPoke;
			I.bLift = In[i].bLift;
			I.bDeke = In[i].bDeke;   // R-0029 point 4 (lane A39): the deke tap
			I.bSpin = In[i].bSpin;   // lane A51 (R-0034): the spin tap
			I.bSprint = In[i].bSprint;   // lane A72 (asks A2, A3): the bots' and the playtester's sprint
			I.bAbility = In[i].bAbility;   // lane A84 (R-0041 point 3): the playtester's F
			I.bCrossHold = In[i].bCrossHold;   // lane A184 (R-0064 point 1): the held cross-check
		}
		if (bWithSystems) { Systems.BeforeStep(*Sim); }   // lane A41: score mirror, sim step, zone update, effect step (the game mode's order)
		Sim->Step(Inputs);
		if (bWithSystems) { Systems.AfterStep(*Sim); }
		if (PassFate) { PassFate->Observe(*Sim); if (Sim->GetPhase() == EJamSimPhase::Over) { PassFate->Finish(*Sim); } }   // lane T5 (T5.a): reads only
		const TArray<FJamSkaterState>& After = Sim->GetSkaters();
		for (int32 i = 0; i < N; ++i)
		{
			if (After[i].Shots > Shots[i] && Ev.Shot < 0) { Ev.Shot = i; }
		}
		const int32 LastAfter = Sim->GetPuck().LastTouch;
		if (LastAfter >= 0 && LastAfter < N && LastAfter != LastBefore) { Ev.TouchMask |= 1u << LastAfter; }
		if (Sim->GetScore(0) > S0) { Ev.GoalTeam = 0; }
		else if (Sim->GetScore(1) > S1) { Ev.GoalTeam = 1; }
		for (const FJamSimEvent& E : Sim->GetFrameEvents())
		{
			// R-0013: a faceoff is now a drop followed by won / lost events; count the drop (or a kindless faceoff) once
			if (E.Name == JamEvents::Faceoff && (E.Kind == NAME_None || E.Kind == FName(TEXT("drop"))))
			{
				Ev.bFaceoff = true;
				LastDropFrame = Sim->GetFrame();
			}
		}
		return Ev;
	}

	bool FJamSimAdapter::IsOver() const { return Sim->GetPhase() == EJamSimPhase::Over; }
	int FJamSimAdapter::Winner() const { return Sim->GetWinner(); }
	int FJamSimAdapter::Score(int Team) const { return Sim->GetScore(Team); }
	uint64_t FJamSimAdapter::StateHash() const { return Sim->StateHash(); }

	double FJamSimAdapter::BoardDistance(const FVec2& P) const
	{
		FVector2D N;
		return Sim->BoardDistance(FVector2D(P.X, P.Y), N);
	}
}
